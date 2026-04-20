import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';
import '../../core/log_sanitizer.dart';
import 'debug_log_store.dart';
import 'log_manager.dart';
import 'network_log_store.dart';

const List<String> _aiExportLogPrefixes = <String>[
  'AI settings ',
  'AI adapter ',
];

List<String> extractAiExportLogLines(Iterable<String> lines) {
  return lines
      .where((line) => _aiExportLogPrefixes.any(line.contains))
      .toList(growable: false);
}

class LogBundleExporter {
  LogBundleExporter({
    required LogManager logManager,
    required DebugLogStore debugLogStore,
    required NetworkLogStore networkLogStore,
    required DebugLogStore webDavLogStore,
  }) : _logManager = logManager,
       _debugLogStore = debugLogStore,
       _networkLogStore = networkLogStore,
       _webDavLogStore = webDavLogStore;

  static const int maxReportLineChars = 4000;
  static const int maxLogLineChars = LogManager.maxLineChars;
  static const int maxJsonLineChars = 4000;
  static const int defaultLogManagerMaxLines = 500;
  static const int defaultLogManagerMaxBytes = 2 * 1024 * 1024;
  static const int defaultStoreMaxLines = 1000;
  static const int defaultStoreMaxBytes = 2 * 1024 * 1024;

  final LogManager _logManager;
  final DebugLogStore _debugLogStore;
  final NetworkLogStore _networkLogStore;
  final DebugLogStore _webDavLogStore;

  Future<File> exportBundle({
    required String exportId,
    required String reportText,
    required Directory outputDirectory,
    bool includeDebugStore = true,
    bool includeNetworkStore = false,
    bool includeWebDavStore = true,
    int logManagerMaxLines = defaultLogManagerMaxLines,
    int logManagerMaxBytes = defaultLogManagerMaxBytes,
    int storeMaxLines = defaultStoreMaxLines,
    int storeMaxBytes = defaultStoreMaxBytes,
  }) async {
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }

    final archive = Archive();
    final includedFiles = <String>[];
    final exportTime = DateTime.now().toUtc();
    DateTime? earliest;
    DateTime? latest;

    void updateRange(DateTime? value) {
      if (value == null) return;
      if (earliest == null || value.isBefore(earliest!)) earliest = value;
      if (latest == null || value.isAfter(latest!)) latest = value;
    }

    final reportLines = LineSplitter.split(reportText).toList();
    final sanitizedReport = reportLines
        .map((line) => _sanitizeTextLine(line, maxReportLineChars))
        .join('\n');
    _addTextFile(archive, 'report.txt', sanitizedReport, includedFiles);

    final logLines = await _logManager.readRecentLines(
      maxLines: logManagerMaxLines,
      maxBytes: logManagerMaxBytes,
    );
    for (final line in logLines) {
      updateRange(_parseLogManagerTimestamp(line));
    }
    final sanitizedLogLines = logLines
        .map((line) => _sanitizeTextLine(line, maxLogLineChars))
        .toList();
    _addTextFile(
      archive,
      'logmanager_raw.log',
      sanitizedLogLines.join('\n'),
      includedFiles,
    );

    final aiLogLines = extractAiExportLogLines(
      logLines,
    ).map((line) => _sanitizeTextLine(line, maxLogLineChars)).toList();
    if (aiLogLines.isNotEmpty) {
      _addTextFile(
        archive,
        'ai_settings.log',
        aiLogLines.join('\n'),
        includedFiles,
      );
    }

    final logDir = await _resolveLogsDirectory();
    if (includeDebugStore) {
      final debugFile = File(p.join(logDir.path, _debugLogStore.fileName));
      final added = await _addJsonlFile(
        archive,
        debugFile,
        _debugLogStore.fileName,
        includedFiles,
        maxLines: storeMaxLines,
        maxBytes: storeMaxBytes,
        onTimestamp: updateRange,
      );
      if (added) {
        updateRange(await _fileModified(debugFile));
      }
    }

    if (includeNetworkStore || _networkLogStore.enabled) {
      const networkFileName = 'network_logs.jsonl';
      final networkFile = File(p.join(logDir.path, networkFileName));
      final added = await _addJsonlFile(
        archive,
        networkFile,
        networkFileName,
        includedFiles,
        maxLines: storeMaxLines,
        maxBytes: storeMaxBytes,
        onTimestamp: updateRange,
      );
      if (added) {
        updateRange(await _fileModified(networkFile));
      }
    }

    if (includeWebDavStore) {
      final webdavFile = File(p.join(logDir.path, _webDavLogStore.fileName));
      final added = await _addJsonlFile(
        archive,
        webdavFile,
        _webDavLogStore.fileName,
        includedFiles,
        maxLines: storeMaxLines,
        maxBytes: storeMaxBytes,
        onTimestamp: updateRange,
      );
      if (added) {
        updateRange(await _fileModified(webdavFile));
      }
    }

    final appLabel = await _loadAppLabel();
    final deviceLabel = await _loadDeviceLabel();
    final networkLabel = await _loadNetworkLabel();
    const manifestName = 'manifest.json';
    final manifestFiles = [...includedFiles, manifestName];

    final manifest = <String, Object?>{
      'exportId': exportId,
      'generatedAt': exportTime.toIso8601String(),
      'app': appLabel,
      'device': deviceLabel,
      'network': networkLabel,
      'timeRange': {
        'start': earliest?.toIso8601String(),
        'end': latest?.toIso8601String(),
      },
      'includedFiles': manifestFiles,
      'truncation': {
        'report': {'maxLineChars': maxReportLineChars},
        'logManager': {
          'maxLines': logManagerMaxLines,
          'maxBytes': logManagerMaxBytes,
          'maxLineChars': maxLogLineChars,
        },
        'stores': {
          'maxLines': storeMaxLines,
          'maxBytes': storeMaxBytes,
          'maxLineChars': maxJsonLineChars,
        },
      },
      'sanitization': {
        'redacts': [
          'authorization',
          'cookie',
          'set-cookie',
          'token',
          'secret',
          'password',
          'personalAccessToken',
          'pat',
          'apiKey',
          'auth',
          'signature',
          'sig',
          'key',
        ],
        'queryParams': [
          'token',
          'access_token',
          'refresh_token',
          'api_key',
          'apikey',
          'personalAccessToken',
          'pat',
          'auth',
          'signature',
          'sig',
          'key',
          'password',
          'secret',
        ],
        'note':
            'Sanitized via LogSanitizer before sinks and re-sanitized on export.',
      },
    };

    _addTextFile(archive, manifestName, _encodeJson(manifest), includedFiles);

    final zipData = ZipEncoder().encode(archive);
    final bundlePath = p.join(
      outputDirectory.path,
      'MemoFlow_log_bundle_$exportId.zip',
    );
    final outFile = File(bundlePath);
    await outFile.writeAsBytes(zipData, flush: true);
    return outFile;
  }

  void _addTextFile(
    Archive archive,
    String name,
    String content,
    List<String> included,
  ) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
    included.add(name);
  }

  Future<bool> _addJsonlFile(
    Archive archive,
    File file,
    String name,
    List<String> included, {
    required int maxLines,
    required int maxBytes,
    required void Function(DateTime?) onTimestamp,
  }) async {
    if (!await file.exists()) return false;
    final result = await _readTailLines(file, maxLines, maxBytes);
    if (result.lines.isEmpty) return false;
    final sanitizedLines = <String>[];
    for (final line in result.lines) {
      final sanitized = _sanitizeJsonLine(line, maxJsonLineChars, onTimestamp);
      if (sanitized.isEmpty) continue;
      sanitizedLines.add(sanitized);
    }
    if (sanitizedLines.isEmpty) return false;
    _addTextFile(archive, name, sanitizedLines.join('\n'), included);
    return true;
  }

  static String sanitizeTextLineForExport(String raw, {int? maxLength}) {
    var sanitized = LogSanitizer.sanitizeText(raw);
    sanitized = sanitized.replaceAll('\n', r'\n').trimRight();
    return _truncateFieldStatic(sanitized, maxLength ?? maxLogLineChars);
  }

  static String sanitizeJsonLineForExport(
    String raw, {
    int? maxLength,
    void Function(DateTime?)? onTimestamp,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final timeValue = decoded['time'];
        if (timeValue is String) {
          onTimestamp?.call(DateTime.tryParse(timeValue));
        }
      }
      final sanitized = LogSanitizer.sanitizeJson(decoded);
      final text = _encodeJsonStatic(sanitized);
      return _truncateFieldStatic(text, maxLength ?? maxJsonLineChars);
    } catch (_) {
      return sanitizeTextLineForExport(
        trimmed,
        maxLength: maxLength ?? maxJsonLineChars,
      );
    }
  }

  String _sanitizeTextLine(String raw, int maxLength) {
    return sanitizeTextLineForExport(raw, maxLength: maxLength);
  }

  String _sanitizeJsonLine(
    String raw,
    int maxLength,
    void Function(DateTime?) onTimestamp,
  ) {
    return sanitizeJsonLineForExport(
      raw,
      maxLength: maxLength,
      onTimestamp: onTimestamp,
    );
  }

  String _encodeJson(Object? value) {
    return _encodeJsonStatic(value);
  }

  static String _truncateFieldStatic(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    final marker =
        '...(truncated to $maxLength chars, original ${value.length})';
    final available = maxLength - marker.length;
    if (available <= 0) return marker;
    return '${value.substring(0, available)}$marker';
  }

  static String _encodeJsonStatic(Object? value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  Future<_TailLinesResult> _readTailLines(
    File file,
    int maxLines,
    int maxBytes,
  ) async {
    if (maxLines <= 0 || maxBytes <= 0) {
      return const _TailLinesResult([], 0);
    }
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final length = await raf.length();
      if (length <= 0) return const _TailLinesResult([], 0);
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
      return _TailLinesResult(lines, bytesRead);
    } catch (_) {
      return const _TailLinesResult([], 0);
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

  DateTime? _parseLogManagerTimestamp(String line) {
    final match = RegExp(r'^\[([^\]]+)]').firstMatch(line);
    if (match == null) return null;
    return DateTime.tryParse(match.group(1) ?? '');
  }

  Future<Directory> _resolveLogsDirectory() async {
    final dir = await resolveAppDocumentsDirectory();
    final logsDir = Directory(p.join(dir.path, 'logs'));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  Future<DateTime?> _fileModified(File file) async {
    try {
      final stat = await file.stat();
      return stat.modified.toUtc();
    } catch (_) {
      return null;
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

class _TailLinesResult {
  const _TailLinesResult(this.lines, this.bytesRead);

  final List<String> lines;
  final int bytesRead;
}
