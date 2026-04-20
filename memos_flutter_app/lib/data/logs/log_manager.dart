import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';
import '../../core/log_sanitizer.dart';

enum LogLevel { debug, info, warn, error }

extension LogLevelLabel on LogLevel {
  String get label => switch (this) {
    LogLevel.debug => 'DEBUG',
    LogLevel.info => 'INFO',
    LogLevel.warn => 'WARN',
    LogLevel.error => 'ERROR',
  };
}

class LogManager {
  LogManager._();

  static final LogManager instance = LogManager._();

  static const int defaultMaxFileBytes = 2 * 1024 * 1024;
  static const int defaultRetentionDays = 7;
  static const String logFilePrefix = 'app_log_';
  static const int maxSubsystemChars = 40;
  static const int maxMessageChars = 800;
  static const int maxContextChars = 2000;
  static const int maxErrorChars = 1200;
  static const int maxStackChars = 2000;
  static const int maxLineChars = 6000;
  static const int _preInitBufferLimit = 200;

  final Duration _retention = const Duration(days: defaultRetentionDays);
  final int _maxFileBytes = defaultMaxFileBytes;

  Directory? _logDir;
  String? _currentDate;
  int _currentIndex = 0;
  bool _initialized = false;
  Future<void> _writeQueue = Future.value();
  final List<String> _preInitBuffer = <String>[];

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _resolveLogDir();
    await _cleanupOldLogs();
    _flushPreInitBuffer();
    await _logDeviceContext();
  }

  Future<void> clearAll() async {
    await init();
    _writeQueue = _writeQueue.then((_) async {
      final dir = await _resolveLogDir();
      await for (final entry in dir.list()) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);
        if (!name.startsWith(logFilePrefix)) continue;
        try {
          await entry.delete();
        } catch (_) {}
      }
      _currentDate = null;
      _currentIndex = 0;
    });
    await _writeQueue;
  }

  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    log(
      LogLevel.debug,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    log(
      LogLevel.info,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    log(
      LogLevel.warn,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final line = _formatLogLine(
      level,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );

    if (kDebugMode || kProfileMode) {
      debugPrint(line);
    }
    if (!_initialized) {
      _bufferPreInitLine(line);
      return;
    }
    _enqueueWrite(line);
  }

  Future<List<String>> readRecentLines({
    int maxLines = 500,
    int maxBytes = 2 * 1024 * 1024,
  }) async {
    if (maxLines <= 0 || maxBytes <= 0) return const [];
    final dir = await _resolveLogDir();
    final files = await _listLogFiles(dir);
    if (files.isEmpty) return const [];

    var remainingLines = maxLines;
    var remainingBytes = maxBytes;
    final collected = <String>[];

    for (final file in files) {
      if (remainingLines <= 0 || remainingBytes <= 0) break;
      final result = await _readTailLines(
        file,
        maxLines: remainingLines,
        maxBytes: remainingBytes,
      );
      if (result.lines.isEmpty) continue;
      collected.insertAll(0, result.lines);
      remainingLines -= result.lines.length;
      remainingBytes -= result.bytesRead;
    }

    return collected;
  }

  String _formatLogLine(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final now = DateTime.now().toUtc();
    final parts = _splitSubsystemEvent(message);
    var subsystem = _sanitizeLine(parts.subsystem, escapeNewlines: true);
    var event = _sanitizeLine(parts.event, escapeNewlines: true);
    if (subsystem.isEmpty) subsystem = 'App';
    if (event.isEmpty) event = '-';

    subsystem = _truncateField(subsystem, maxSubsystemChars);
    event = _truncateField(event, maxMessageChars);

    final safeContext = context == null
        ? null
        : LogSanitizer.sanitizeJson(context);
    String? contextText;
    if (safeContext != null) {
      contextText = _stringifyJson(safeContext);
      contextText = _truncateField(contextText, maxContextChars);
      if (contextText.trim().isEmpty) {
        contextText = null;
      }
    }

    String? errorText;
    if (error != null) {
      errorText = _sanitizeLine(error.toString(), escapeNewlines: true);
      if (errorText.trim().isEmpty) {
        errorText = null;
      } else {
        errorText = _truncateField(errorText, maxErrorChars);
      }
    }

    StackTrace? trace = stackTrace;
    if (trace == null && level == LogLevel.error) {
      trace = StackTrace.current;
    }
    String? stackText;
    if (trace != null) {
      stackText = _sanitizeLine(trace.toString(), escapeNewlines: true);
      if (stackText.trim().isEmpty) {
        stackText = null;
      } else {
        stackText = _truncateField(stackText, maxStackChars);
      }
    }

    final buffer = StringBuffer()
      ..write('[${now.toIso8601String()}] ${level.label} $subsystem: $event');

    if (contextText != null) {
      buffer.write(' | ctx=$contextText');
    }
    if (errorText != null) {
      buffer.write(' | error=$errorText');
    }
    if (stackText != null) {
      buffer.write(' | stack=$stackText');
    }

    return _truncateLineTotal(buffer.toString());
  }

  _LogMessageParts _splitSubsystemEvent(String message) {
    final raw = message.trim();
    if (raw.isEmpty) return const _LogMessageParts('App', '');
    final idx = raw.indexOf(':');
    if (idx > 0) {
      final candidate = raw.substring(0, idx).trim();
      final rest = raw.substring(idx + 1).trim();
      if (rest.isNotEmpty && _isValidSubsystem(candidate)) {
        return _LogMessageParts(candidate, rest);
      }
    }
    return _LogMessageParts('App', raw);
  }

  bool _isValidSubsystem(String value) {
    if (value.isEmpty) return false;
    if (value.length > maxSubsystemChars) return false;
    if (value.contains('://')) return false;
    if (value.contains('/')) return false;
    return true;
  }

  String _sanitizeLine(String raw, {required bool escapeNewlines}) {
    var sanitized = LogSanitizer.sanitizeText(raw);
    if (escapeNewlines) {
      sanitized = sanitized.replaceAll('\n', r'\n');
    }
    return sanitized.trim();
  }

  String _truncateField(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    final marker =
        '...(truncated to $maxLength chars, original ${value.length})';
    final available = maxLength - marker.length;
    if (available <= 0) return marker;
    return '${value.substring(0, available)}$marker';
  }

  String _truncateLineTotal(String line) {
    if (line.length <= maxLineChars) return line;
    final marker =
        '...(truncated to $maxLineChars chars, original ${line.length})';
    final available = maxLineChars - marker.length;
    if (available <= 0) return marker;
    return '${line.substring(0, available)}$marker';
  }

  String _stringifyJson(Object? value) {
    if (value == null) return '';
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  Future<List<File>> _listLogFiles(Directory dir) async {
    final entries = await dir.list().where((e) => e is File).toList();
    final files = <File>[];
    for (final entry in entries) {
      final file = entry as File;
      final name = p.basename(file.path);
      if (!name.startsWith(logFilePrefix)) continue;
      files.add(file);
    }
    if (files.isEmpty) return const <File>[];
    final meta = await Future.wait(
      files.map((file) async => MapEntry(file, await file.stat())),
    );
    meta.sort((a, b) => b.value.modified.compareTo(a.value.modified));
    return meta.map((entry) => entry.key).toList(growable: false);
  }

  Future<_TailReadResult> _readTailLines(
    File file, {
    required int maxLines,
    required int maxBytes,
  }) async {
    if (maxLines <= 0 || maxBytes <= 0) {
      return const _TailReadResult([], 0);
    }
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final length = await raf.length();
      if (length <= 0) return const _TailReadResult([], 0);
      var position = length;
      const chunkSize = 4096;
      final chunks = <String>[];
      var bytesRead = 0;
      var newlineCount = 0;
      while (position > 0 && bytesRead < maxBytes && newlineCount <= maxLines) {
        final readSize = math.min(chunkSize, position);
        position -= readSize;
        await raf.setPosition(position);
        final chunk = await raf.read(readSize);
        bytesRead += chunk.length;
        final chunkText = utf8.decode(chunk, allowMalformed: true);
        newlineCount += _countNewlines(chunkText);
        chunks.add(chunkText);
        if (newlineCount >= maxLines + 1) break;
      }

      var combined = chunks.reversed.join();
      var lines = combined.split(RegExp(r'\r?\n'));
      if (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines = lines.sublist(0, lines.length - 1);
      }
      if (lines.length > maxLines) {
        lines = lines.sublist(lines.length - maxLines);
      }
      return _TailReadResult(lines, bytesRead);
    } catch (_) {
      return const _TailReadResult([], 0);
    } finally {
      await raf?.close();
    }
  }

  int _countNewlines(String text) {
    var count = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 10) {
        count++;
      }
    }
    return count;
  }

  Future<File?> exportLogs() async {
    final dir = await _resolveLogDir();
    final entries = await dir.list().where((e) => e is File).toList();
    if (entries.isEmpty) return null;

    final archive = Archive();
    for (final entry in entries) {
      final file = entry as File;
      final name = p.basename(file.path);
      try {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      } catch (_) {}
    }

    if (archive.isEmpty) return null;
    final zipData = ZipEncoder().encode(archive);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final outPath = p.join(dir.path, 'MemoFlow_logs_$timestamp.zip');
    final outFile = File(outPath);
    await outFile.writeAsBytes(zipData, flush: true);
    return outFile;
  }

  Future<void> _logDeviceContext() async {
    final app = await _loadAppLabel();
    final device = await _loadDeviceLabel();
    final network = await _loadNetworkLabel();
    info(
      'Logger initialized',
      context: {
        'app': app,
        'device': device,
        'network': network,
        'mode': kDebugMode ? 'debug' : (kReleaseMode ? 'release' : 'profile'),
      },
    );
  }

  Future<Directory> _resolveLogDir() async {
    final cached = _logDir;
    if (cached != null) return cached;
    final dir = await resolveAppDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logDir = logDir;
    return logDir;
  }

  void _enqueueWrite(String line) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _resolveLogFile();
        await file.writeAsString(
          '$line\n',
          mode: FileMode.append,
          flush: false,
        );
      } catch (_) {}
    });
  }

  void _bufferPreInitLine(String line) {
    if (_preInitBuffer.length >= _preInitBufferLimit) {
      _preInitBuffer.removeAt(0);
    }
    _preInitBuffer.add(line);
  }

  void _flushPreInitBuffer() {
    if (_preInitBuffer.isEmpty) return;
    final pending = List<String>.from(_preInitBuffer);
    _preInitBuffer.clear();
    for (final line in pending) {
      _enqueueWrite(line);
    }
  }

  Future<File> _resolveLogFile() async {
    final dir = await _resolveLogDir();
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    if (_currentDate != today) {
      _currentDate = today;
      _currentIndex = 0;
    }

    File file;
    while (true) {
      file = File(_buildFilePath(dir, today, _currentIndex));
      final exists = await file.exists();
      if (!exists) return file;
      final stat = await file.stat();
      if (stat.size < _maxFileBytes) return file;
      _currentIndex++;
    }
  }

  String _buildFilePath(Directory dir, String date, int index) {
    final suffix = index <= 0 ? '' : '_$index';
    return p.join(dir.path, '$logFilePrefix$date$suffix.log');
  }

  Future<void> _cleanupOldLogs() async {
    final dir = await _resolveLogDir();
    final threshold = DateTime.now().subtract(_retention);
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (!name.startsWith(logFilePrefix)) continue;
      try {
        final stat = await entry.stat();
        if (stat.modified.isBefore(threshold)) {
          await entry.delete();
        }
      } catch (_) {}
    }
  }

  Future<String> _loadAppLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final build = info.buildNumber.trim();
      if (version.isEmpty && build.isEmpty) return 'MemoFlow';
      if (build.isEmpty) return 'MemoFlow v$version';
      return 'MemoFlow v$version (Build $build)';
    } catch (_) {
      return 'MemoFlow';
    }
  }

  Future<String> _loadDeviceLabel() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final data = await info.androidInfo;
        final release = data.version.release.trim();
        final model = data.model.trim();
        final os = release.isNotEmpty ? 'Android $release' : 'Android';
        return model.isNotEmpty ? '$os ($model)' : os;
      }
      if (Platform.isMacOS) {
        final data = await info.macOsInfo;
        final version = data.osRelease.trim();
        final model = data.model.trim();
        final os = version.isNotEmpty ? 'macOS $version' : 'macOS';
        return model.isNotEmpty ? '$os ($model)' : os;
      }
      if (Platform.isWindows) {
        final data = await info.windowsInfo;
        final version = data.displayVersion.trim();
        final os = version.isNotEmpty ? 'Windows $version' : 'Windows';
        return os;
      }
      if (Platform.isLinux) {
        final data = await info.linuxInfo;
        final version = data.version?.trim() ?? '';
        final os = version.isNotEmpty ? 'Linux $version' : 'Linux';
        return os;
      }
    } catch (_) {}
    final fallback = Platform.operatingSystemVersion
        .replaceAll('\n', ' ')
        .trim();
    return fallback.isEmpty ? Platform.operatingSystem : fallback;
  }

  Future<String> _loadNetworkLabel() async {
    try {
      final results = await _readConnectivityResults();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return 'None';
      }
      if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
      if (results.contains(ConnectivityResult.mobile)) return 'Mobile';
      if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
      if (results.contains(ConnectivityResult.vpn)) return 'VPN';
      if (results.contains(ConnectivityResult.bluetooth)) return 'Bluetooth';
      if (results.contains(ConnectivityResult.other)) return 'Other';
    } catch (_) {}
    return 'Unknown';
  }

  Future<List<ConnectivityResult>> _readConnectivityResults() async {
    final dynamic raw = await Connectivity().checkConnectivity();
    if (raw is List<ConnectivityResult>) return raw;
    if (raw is ConnectivityResult) return [raw];
    return const [];
  }
}

class _LogMessageParts {
  const _LogMessageParts(this.subsystem, this.event);

  final String subsystem;
  final String event;
}

class _TailReadResult {
  const _TailReadResult(this.lines, this.bytesRead);

  final List<String> lines;
  final int bytesRead;
}
