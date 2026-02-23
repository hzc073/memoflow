import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';
import '../../core/log_sanitizer.dart';

class NetworkLogEntry {
  NetworkLogEntry({
    required this.timestamp,
    required this.type,
    required this.method,
    required this.url,
    this.status,
    this.durationMs,
    this.headers,
    this.body,
    this.error,
    this.requestId,
  });

  final DateTime timestamp;
  final String type;
  final String method;
  final String url;
  final int? status;
  final int? durationMs;
  final Map<String, String>? headers;
  final String? body;
  final String? error;
  final String? requestId;

  Map<String, dynamic> toJson() => {
    'time': timestamp.toIso8601String(),
    'type': type,
    'method': method,
    'url': url,
    if (status != null) 'status': status,
    if (durationMs != null) 'durationMs': durationMs,
    if (headers != null) 'headers': headers,
    if (body != null) 'body': body,
    if (error != null) 'error': error,
    if (requestId != null) 'requestId': requestId,
  };

  static NetworkLogEntry? fromJson(Map<String, dynamic> json) {
    final rawTime = json['time'];
    final type = json['type'];
    final method = json['method'];
    final url = json['url'];
    if (type is! String || method is! String || url is! String) return null;
    final ts = rawTime is String ? DateTime.tryParse(rawTime) : null;
    if (ts == null) return null;

    Map<String, String>? headers;
    final headersRaw = json['headers'];
    if (headersRaw is Map) {
      headers = headersRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    return NetworkLogEntry(
      timestamp: ts,
      type: type,
      method: method,
      url: url,
      status: parseInt(json['status']),
      durationMs: parseInt(json['durationMs']),
      headers: headers,
      body: json['body']?.toString(),
      error: json['error']?.toString(),
      requestId: json['requestId']?.toString(),
    );
  }

  List<String> formatLines() {
    final statusText = status == null ? '' : ' $status';
    final durationText = durationMs == null ? '' : ' ${durationMs}ms';
    final head =
        '- [${timestamp.toIso8601String()}] ${type.toUpperCase()} $method $url$statusText'
        '${durationText.isNotEmpty ? ' ($durationText)' : ''}';
    final lines = <String>[head];

    if (headers != null && headers!.isNotEmpty) {
      lines.add('  headers: ${jsonEncode(headers)}');
    }

    final bodyText = _sanitizeLine(body);
    if (bodyText.isNotEmpty) {
      lines.add('  body: $bodyText');
    }

    final errorText = _sanitizeLine(error);
    if (errorText.isNotEmpty) {
      lines.add('  error: $errorText');
    }

    return lines;
  }

  static String _sanitizeLine(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final sanitized = LogSanitizer.stringify(LogSanitizer.sanitizeJson(raw));
    return sanitized.replaceAll('\n', ' ').trim();
  }
}

class NetworkLogStore {
  NetworkLogStore({this.maxEntries = 200, this.maxFileBytes = 1024 * 1024});

  final int maxEntries;
  final int maxFileBytes;
  bool enabled = false;

  int _appendCount = 0;
  Future<File>? _fileFuture;

  void setEnabled(bool value) {
    enabled = value;
  }

  Future<void> add(NetworkLogEntry entry) async {
    if (!enabled) return;
    try {
      final file = await _resolveFile();
      final line = jsonEncode(entry.toJson());
      await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
      _appendCount++;
      if (_appendCount % 20 == 0) {
        await _compactIfNeeded(file);
      }
    } catch (_) {}
  }

  Future<List<NetworkLogEntry>> list({int limit = 50}) async {
    if (limit <= 0) return const [];
    try {
      final file = await _resolveFile();
      final exists = await file.exists();
      if (!exists) return const [];
      final lines = await file.readAsLines();
      final entries = <NetworkLogEntry>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) {
            final entry = NetworkLogEntry.fromJson(
              decoded.cast<String, dynamic>(),
            );
            if (entry != null) entries.add(entry);
          }
        } catch (_) {}
      }
      if (entries.length <= limit) return entries;
      return entries.sublist(entries.length - limit);
    } catch (_) {
      return const [];
    }
  }

  Future<File> _resolveFile() async {
    final cached = _fileFuture;
    if (cached != null) return cached;
    final dir = await resolveAppDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    final file = File(p.join(logDir.path, 'network_logs.jsonl'));
    _fileFuture = Future.value(file);
    return file;
  }

  Future<void> _compactIfNeeded(File file) async {
    final stat = await file.stat();
    if (stat.size <= maxFileBytes) return;
    final lines = await file.readAsLines();
    if (lines.length <= maxEntries) return;
    final trimmed = lines.sublist(lines.length - maxEntries);
    await file.writeAsString('${trimmed.join('\n')}\n', flush: true);
  }
}
