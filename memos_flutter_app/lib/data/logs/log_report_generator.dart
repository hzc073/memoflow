import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import 'breadcrumb_store.dart';
import 'logger_service.dart';
import 'network_log_buffer.dart';
import 'sync_status_tracker.dart';

class LogReportGenerator {
  LogReportGenerator({
    required AppDatabase db,
    required LoggerService loggerService,
    required BreadcrumbStore breadcrumbStore,
    required NetworkLogBuffer networkLogBuffer,
    required SyncStatusTracker syncStatusTracker,
  })  : _db = db,
        _loggerService = loggerService,
        _breadcrumbStore = breadcrumbStore,
        _networkLogBuffer = networkLogBuffer,
        _syncStatusTracker = syncStatusTracker;

  final AppDatabase _db;
  final LoggerService _loggerService;
  final BreadcrumbStore _breadcrumbStore;
  final NetworkLogBuffer _networkLogBuffer;
  final SyncStatusTracker _syncStatusTracker;

  Future<String> buildReport({
    int breadcrumbLimit = 15,
    int networkLimit = 10,
  }) async {
    final now = DateTime.now();
    final reportTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now);
    final appLabel = await _loadAppLabel();
    final deviceLabel = await _loadDeviceLabel();
    final networkLabel = await _loadNetworkLabel();

    final sqlite = await _db.db;
    final totalMemos = await _count(sqlite, 'SELECT COUNT(*) FROM memos;');
    final pendingQueue = await _count(sqlite, 'SELECT COUNT(*) FROM outbox WHERE state IN (0,2);');

    final lifecycle = LoggerService.formatLifecycle(_loggerService.lifecycleState);
    final syncLine = _formatSyncLine(_syncStatusTracker.snapshot);
    final pendingLine = _formatPendingQueue(pendingQueue);

    final breadcrumbs = _breadcrumbStore.list(limit: breadcrumbLimit);
    final networkLogs = _networkLogBuffer.list(limit: networkLimit);

    final buffer = StringBuffer()
      ..writeln('[REPORT HEAD]')
      ..writeln('Time: $reportTime')
      ..writeln('App: $appLabel')
      ..writeln('Device: $deviceLabel')
      ..writeln('Network: $networkLabel')
      ..writeln('')
      ..writeln('[APP STATE SNAPSHOT]')
      ..writeln('Lifecycle: $lifecycle')
      ..writeln(syncLine)
      ..writeln(pendingLine)
      ..writeln('Local DB: $totalMemos memos')
      ..writeln('')
      ..writeln('[USER BREADCRUMBS] (Last ${breadcrumbs.length})');

    if (breadcrumbs.isEmpty) {
      buffer.writeln('1. ${_formatBreadcrumbTime(now)} - (none)');
    } else {
      for (var i = 0; i < breadcrumbs.length; i++) {
        final entry = breadcrumbs[i];
        buffer.writeln('${i + 1}. ${_formatBreadcrumbTime(entry.timestamp)} - ${entry.message}');
      }
    }

    buffer
      ..writeln('')
      ..writeln('[NETWORK LOGS] (Last ${networkLogs.length})');

    if (networkLogs.isEmpty) {
      buffer
        ..writeln('------------------------------------------------')
        ..writeln('1. [--] (no requests)');
      return buffer.toString();
    }

    for (var i = 0; i < networkLogs.length; i++) {
      final entry = networkLogs[i];
      buffer.writeln('------------------------------------------------');
      buffer.writeln('${i + 1}. [${entry.method}] ${entry.path} (${_statusLabel(entry)}) - ${_latencyLabel(entry)}');

      final query = entry.query;
      if (query != null && query.trim().isNotEmpty) {
        buffer.writeln('   Query: $query');
      }

      final payload = entry.requestBody;
      if (payload != null && payload.trim().isNotEmpty) {
        buffer.writeln('   Payload: $payload');
      }

      final paginationLine = _formatPaginationLine(entry);
      if (paginationLine != null) {
        buffer.writeln(paginationLine);
      }

      final responseBody = entry.responseBody;
      if (responseBody != null && responseBody.trim().isNotEmpty) {
        buffer.writeln('   Response: $responseBody');
      }

      final errorMessage = entry.errorMessage;
      if (errorMessage != null && errorMessage.trim().isNotEmpty) {
        buffer.writeln('   Error: $errorMessage');
      }
    }

    return buffer.toString();
  }

  Future<int> _count(DatabaseExecutor sqlite, String sql) async {
    final rows = await sqlite.rawQuery(sql);
    final v = rows.firstOrNull?.values.first;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
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
        return 'None (Disconnected)';
      }
      if (results.contains(ConnectivityResult.wifi)) {
        return 'WiFi (Connected)';
      }
      if (results.contains(ConnectivityResult.mobile)) {
        return 'Mobile (Connected)';
      }
      if (results.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet (Connected)';
      }
      if (results.contains(ConnectivityResult.vpn)) {
        return 'VPN (Connected)';
      }
      if (results.contains(ConnectivityResult.bluetooth)) {
        return 'Bluetooth (Connected)';
      }
      if (results.contains(ConnectivityResult.other)) {
        return 'Other (Connected)';
      }
    } catch (_) {}
    return 'Unknown';
  }

  Future<List<ConnectivityResult>> _readConnectivityResults() async {
    final dynamic raw = await Connectivity().checkConnectivity();
    if (raw is List<ConnectivityResult>) return raw;
    if (raw is ConnectivityResult) return [raw];
    return const [];
  }

  String _formatSyncLine(SyncStatusSnapshot snapshot) {
    final lastSuccess = snapshot.lastSuccess;
    final lastSuccessText =
        lastSuccess == null ? '-' : DateFormat('h:mm a').format(lastSuccess);
    if (snapshot.inProgress) {
      return 'Sync Manager: Syncing (Last success: $lastSuccessText)';
    }
    return 'Sync Manager: Idle (Last success: $lastSuccessText)';
  }

  String _formatPendingQueue(int count) {
    final suffix = count > 0 ? ' (Waiting for upload)' : '';
    return 'Pending Queue: $count tasks$suffix <--- CRITICAL INFO';
  }

  String _formatBreadcrumbTime(DateTime time) {
    return DateFormat('HH:mm:ss').format(time);
  }

  String _statusLabel(NetworkRequestLog entry) {
    final code = entry.statusCode;
    if (code == null) return 'Error';
    final reason = (entry.statusMessage ?? _reasonPhrases[code] ?? '').trim();
    if (reason.isEmpty) return '$code';
    return '$code $reason';
  }

  String _latencyLabel(NetworkRequestLog entry) {
    final duration = entry.durationMs;
    if (duration == null) return '?ms';
    return '${duration}ms';
  }

  String? _formatPaginationLine(NetworkRequestLog entry) {
    final hasAny = entry.pageSize != null ||
        entry.pageToken != null ||
        entry.nextPageToken != null ||
        entry.memosCount != null;
    if (!hasAny) return null;
    final pageSize = entry.pageSize?.toString() ?? '-';
    final pageToken = _formatToken(entry.pageToken);
    final nextToken = _formatToken(entry.nextPageToken);
    final memosCount = entry.memosCount?.toString() ?? '-';
    return '   Pagination: pageSize=$pageSize, pageToken=$pageToken, nextPageToken=$nextToken, memosCount=$memosCount';
  }

  String _formatToken(String? value) {
    if (value == null) return '-';
    if (value.isEmpty) return '""';
    return value;
  }

  static const Map<int, String> _reasonPhrases = {
    200: 'OK',
    201: 'Created',
    202: 'Accepted',
    204: 'No Content',
    400: 'Bad Request',
    401: 'Unauthorized',
    403: 'Forbidden',
    404: 'Not Found',
    409: 'Conflict',
    413: 'Payload Too Large',
    429: 'Too Many Requests',
    500: 'Server Error',
    502: 'Bad Gateway',
    503: 'Service Unavailable',
    504: 'Gateway Timeout',
  };
}

extension _FirstOrNullLogExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
