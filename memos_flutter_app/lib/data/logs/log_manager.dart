import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/log_sanitizer.dart';

enum LogLevel {
  debug,
  info,
  warn,
  error,
}

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

  final Duration _retention = const Duration(days: defaultRetentionDays);
  final int _maxFileBytes = defaultMaxFileBytes;

  Directory? _logDir;
  String? _currentDate;
  int _currentIndex = 0;
  bool _initialized = false;
  Future<void> _writeQueue = Future.value();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _resolveLogDir();
    await _cleanupOldLogs();
    await _logDeviceContext();
  }

  void debug(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? context}) {
    log(LogLevel.debug, message, error: error, stackTrace: stackTrace, context: context);
  }

  void info(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? context}) {
    log(LogLevel.info, message, error: error, stackTrace: stackTrace, context: context);
  }

  void warn(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? context}) {
    log(LogLevel.warn, message, error: error, stackTrace: stackTrace, context: context);
  }

  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? context}) {
    log(LogLevel.error, message, error: error, stackTrace: stackTrace, context: context);
  }

  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    if (!_initialized) {
      unawaited(init());
    }

    final now = DateTime.now().toUtc();
    final safeMessage = LogSanitizer.sanitizeText(message);
    final safeError = error == null ? null : LogSanitizer.sanitizeText(error.toString());
    final safeContext = context == null ? null : LogSanitizer.sanitizeJson(context);
    final safeContextText = safeContext == null ? null : LogSanitizer.stringify(safeContext, maxLength: 1000);

    final buffer = StringBuffer()
      ..write('[${now.toIso8601String()}] ${level.label} $safeMessage');

    if (safeError != null && safeError.trim().isNotEmpty) {
      buffer.write(' | error=$safeError');
    }
    if (safeContextText != null && safeContextText.trim().isNotEmpty) {
      buffer.write(' | ctx=$safeContextText');
    }

    if (level == LogLevel.error) {
      final trace = stackTrace ?? StackTrace.current;
      buffer
        ..write('\n')
        ..write(trace.toString());
    }

    final line = buffer.toString();
    if (kDebugMode) {
      debugPrint(line);
      return;
    }
    if (kReleaseMode) {
      _enqueueWrite(line);
    }
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
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    _logDir = logDir;
    return logDir;
  }

  void _enqueueWrite(String line) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _resolveLogFile();
        await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
      } catch (_) {}
    });
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
      if (Platform.isIOS) {
        final data = await info.iosInfo;
        final version = data.systemVersion.trim();
        final model = data.utsname.machine.trim();
        final os = version.isNotEmpty ? 'iOS $version' : 'iOS';
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
    final fallback = Platform.operatingSystemVersion.replaceAll('\n', ' ').trim();
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
