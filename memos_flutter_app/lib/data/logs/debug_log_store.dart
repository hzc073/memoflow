import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';

class DebugLogEntry {
  DebugLogEntry({
    required this.timestamp,
    required this.category,
    required this.label,
    this.detail,
    this.method,
    this.url,
    this.status,
    this.durationMs,
    this.requestHeaders,
    this.requestBody,
    this.responseHeaders,
    this.responseBody,
    this.error,
  });

  final DateTime timestamp;
  final String category;
  final String label;
  final String? detail;
  final String? method;
  final String? url;
  final int? status;
  final int? durationMs;
  final String? requestHeaders;
  final String? requestBody;
  final String? responseHeaders;
  final String? responseBody;
  final String? error;

  Map<String, dynamic> toJson() => {
    'time': timestamp.toIso8601String(),
    'category': category,
    'label': label,
    if (detail != null) 'detail': detail,
    if (method != null) 'method': method,
    if (url != null) 'url': url,
    if (status != null) 'status': status,
    if (durationMs != null) 'durationMs': durationMs,
    if (requestHeaders != null) 'requestHeaders': requestHeaders,
    if (requestBody != null) 'requestBody': requestBody,
    if (responseHeaders != null) 'responseHeaders': responseHeaders,
    if (responseBody != null) 'responseBody': responseBody,
    if (error != null) 'error': error,
  };

  static DebugLogEntry? fromJson(Map<String, dynamic> json) {
    final rawTime = json['time'];
    final category = json['category'];
    final label = json['label'];
    if (rawTime is! String || category is! String || label is! String) {
      return null;
    }
    final ts = DateTime.tryParse(rawTime);
    if (ts == null) return null;

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    return DebugLogEntry(
      timestamp: ts,
      category: category,
      label: label,
      detail: json['detail']?.toString(),
      method: json['method']?.toString(),
      url: json['url']?.toString(),
      status: parseInt(json['status']),
      durationMs: parseInt(json['durationMs']),
      requestHeaders: json['requestHeaders']?.toString(),
      requestBody: json['requestBody']?.toString(),
      responseHeaders: json['responseHeaders']?.toString(),
      responseBody: json['responseBody']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

class DebugLogStore {
  DebugLogStore({
    this.maxEntries = 2000,
    this.maxFileBytes = 10 * 1024 * 1024,
    this.fileName = 'debug_logs.jsonl',
    bool? enabled,
  }) : enabled = enabled ?? kDebugMode;

  final int maxEntries;
  final int maxFileBytes;
  final String fileName;
  bool enabled;

  int _appendCount = 0;
  Future<File>? _fileFuture;

  void setEnabled(bool value) {
    enabled = value;
  }

  Future<void> add(DebugLogEntry entry) async {
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

  Future<List<DebugLogEntry>> list({int limit = 200}) async {
    if (limit <= 0) return const [];
    try {
      final file = await _resolveFile();
      final exists = await file.exists();
      if (!exists) return const [];
      final lines = await file.readAsLines();
      final entries = <DebugLogEntry>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) {
            final entry = DebugLogEntry.fromJson(
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

  Future<void> clear() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
    } catch (_) {}
  }

  Future<File> _resolveFile() async {
    final cached = _fileFuture;
    if (cached != null) return cached;
    final dir = await resolveAppDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    final file = File(p.join(logDir.path, fileName));
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
