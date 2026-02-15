import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/log_sanitizer.dart';
import '../db/app_database.dart';
import '../models/account.dart';
import 'breadcrumb_store.dart';
import 'logger_service.dart';
import 'network_log_buffer.dart';
import 'network_log_store.dart';
import 'sync_status_tracker.dart';

class LogReportGenerator {
  LogReportGenerator({
    required AppDatabase db,
    required LoggerService loggerService,
    required BreadcrumbStore breadcrumbStore,
    required NetworkLogBuffer networkLogBuffer,
    required NetworkLogStore networkLogStore,
    required SyncStatusTracker syncStatusTracker,
    Account? currentAccount,
  })  : _db = db,
        _loggerService = loggerService,
        _breadcrumbStore = breadcrumbStore,
        _networkLogBuffer = networkLogBuffer,
        _networkLogStore = networkLogStore,
        _syncStatusTracker = syncStatusTracker,
        _currentAccount = currentAccount;

  final AppDatabase _db;
  final LoggerService _loggerService;
  final BreadcrumbStore _breadcrumbStore;
  final NetworkLogBuffer _networkLogBuffer;
  final NetworkLogStore _networkLogStore;
  final SyncStatusTracker _syncStatusTracker;
  final Account? _currentAccount;

  Future<String> buildReport({
    int breadcrumbLimit = 15,
    int networkLimit = 30,
    int errorLimit = 12,
    int outboxLimit = 10,
    int memoErrorLimit = 8,
    int networkStoreLimit = 80,
    bool includeErrors = true,
    bool includeOutbox = true,
    String? userNote,
  }) async {
    final now = DateTime.now();
    final reportTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now);
    final appLabel = await _loadAppLabel();
    final deviceLabel = await _loadDeviceLabel();
    final networkLabel = await _loadNetworkLabel();
    final serverLine = _formatServerLine(_currentAccount);
    final note = (userNote ?? '').trim();

    final sqlite = await _db.db;
    final totalMemos = await _count(sqlite, 'SELECT COUNT(*) FROM memos;');
    final pendingQueue = await _count(sqlite, 'SELECT COUNT(*) FROM outbox WHERE state IN (0,2);');
    final failedQueue = await _count(sqlite, 'SELECT COUNT(*) FROM outbox WHERE state = 2;');
    final outboxTypeCounts = await _loadOutboxTypeCounts(sqlite);
    final pendingOutboxItems = includeOutbox
        ? await _loadOutboxItems(sqlite, state: 0, limit: outboxLimit)
        : const <Map<String, dynamic>>[];
    final failedOutboxItems = includeOutbox
        ? await _loadOutboxItems(sqlite, state: 2, limit: outboxLimit)
        : const <Map<String, dynamic>>[];
    final memoSyncErrors = includeErrors
        ? await _loadMemoSyncErrors(sqlite, limit: memoErrorLimit)
        : const <Map<String, dynamic>>[];

    final lifecycle = LoggerService.formatLifecycle(_loggerService.lifecycleState);
    final syncLine = _formatSyncLine(_syncStatusTracker.snapshot);
    final syncErrorLine = _formatSyncErrorLine(_syncStatusTracker.snapshot);
    final pendingLine = _formatPendingQueue(pendingQueue);
    final outboxLine = _formatOutboxCounts(pendingQueue, failedQueue, outboxTypeCounts);

    final breadcrumbs = _breadcrumbStore.list(limit: breadcrumbLimit);
    final allNetworkLogs = _networkLogBuffer.listAll();
    final networkLogs = _tail(allNetworkLogs, networkLimit);
    final networkErrors = includeErrors
        ? _tail(_filterNetworkErrors(allNetworkLogs), errorLimit)
        : const <NetworkRequestLog>[];
    final networkStoreLogs = await _networkLogStore.list(limit: networkStoreLimit);
    final networkStoreErrors = includeErrors
        ? _tailStoreEntries(_filterStoreNetworkErrors(networkStoreLogs), errorLimit)
        : const <NetworkLogEntry>[];
    final networkStoreRecent = _tailStoreEntries(networkStoreLogs, networkStoreLimit);

    final buffer = StringBuffer()
      ..writeln('[REPORT HEAD]')
      ..writeln('Time: $reportTime')
      ..writeln('App: $appLabel')
      ..writeln('Device: $deviceLabel')
      ..writeln('Network: $networkLabel')
      ..writeln('User Note: ${note.isEmpty ? '-' : note}')
      ..writeln(serverLine)
      ..writeln('')
      ..writeln('[APP STATE SNAPSHOT]')
      ..writeln('Lifecycle: $lifecycle')
      ..writeln(syncLine)
      ..writeln(includeErrors ? syncErrorLine : 'Sync Error: (hidden by user)')
      ..writeln(pendingLine)
      ..writeln(includeOutbox ? outboxLine : 'Outbox: (hidden by user)')
      ..writeln('Local DB: $totalMemos memos')
      ..writeln('');

    if (includeOutbox) {
      buffer.writeln('[OUTBOX PENDING] (Last ${pendingOutboxItems.length})');
      if (pendingOutboxItems.isEmpty) {
        buffer.writeln('1. (none)');
      } else {
        for (var i = 0; i < pendingOutboxItems.length; i++) {
          buffer.writeln('${i + 1}. ${_formatOutboxItem(pendingOutboxItems[i])}');
        }
      }

      buffer
        ..writeln('')
        ..writeln('[OUTBOX FAILED] (Last ${failedOutboxItems.length})');

      if (failedOutboxItems.isEmpty) {
        buffer.writeln('1. (none)');
      } else {
        for (var i = 0; i < failedOutboxItems.length; i++) {
          buffer.writeln('${i + 1}. ${_formatOutboxItem(failedOutboxItems[i])}');
        }
      }
    }

    if (includeErrors) {
      buffer
        ..writeln('')
        ..writeln('[MEMO SYNC ERRORS] (Last ${memoSyncErrors.length})');

      if (memoSyncErrors.isEmpty) {
        buffer.writeln('1. (none)');
      } else {
        for (var i = 0; i < memoSyncErrors.length; i++) {
          buffer.writeln('${i + 1}. ${_formatMemoSyncError(memoSyncErrors[i])}');
        }
      }
    }

    buffer
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

    if (includeErrors) {
      buffer
        ..writeln('')
        ..writeln('[NETWORK ERRORS] (Last ${networkErrors.length})');

      if (networkErrors.isEmpty) {
        buffer
          ..writeln('------------------------------------------------')
          ..writeln('1. [--] (no errors)');
      } else {
        _appendNetworkEntries(buffer, networkErrors);
      }

      buffer
        ..writeln('')
        ..writeln('[NETWORK STORE ERRORS] (Last ${networkStoreErrors.length})');

      if (networkStoreErrors.isEmpty) {
        buffer
          ..writeln('------------------------------------------------')
          ..writeln('1. [--] (no errors)');
      } else {
        _appendStoreNetworkEntries(buffer, networkStoreErrors);
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

    _appendNetworkEntries(buffer, networkLogs);

    buffer
      ..writeln('')
      ..writeln('[NETWORK STORE LOGS] (Last ${networkStoreRecent.length})');

    if (networkStoreRecent.isEmpty) {
      buffer
        ..writeln('------------------------------------------------')
        ..writeln('1. [--] (no requests)');
      return buffer.toString();
    }

    _appendStoreNetworkEntries(buffer, networkStoreRecent);

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

  String _formatServerLine(Account? account) {
    if (account == null) return 'Server: -';
    final baseUrl = account.baseUrl.toString().trim();
    final profile = account.instanceProfile;
    final instanceUrl = profile.instanceUrl.trim();
    final label = baseUrl.isNotEmpty
        ? LogSanitizer.maskUrl(baseUrl)
        : (instanceUrl.isNotEmpty ? LogSanitizer.maskUrl(instanceUrl) : '-');

    final parts = <String>[];
    final version = profile.version.trim();
    if (version.isNotEmpty) parts.add('version=$version');
    final mode = profile.mode.trim();
    if (mode.isNotEmpty) parts.add('mode=$mode');
    if (instanceUrl.isNotEmpty) parts.add('instanceUrl=${LogSanitizer.maskUrl(instanceUrl)}');
    final owner = profile.owner.trim();
    if (owner.isNotEmpty) parts.add('owner=${LogSanitizer.maskUserLabel(owner)}');

    if (parts.isEmpty) return 'Server: $label';
    return 'Server: $label (${parts.join(', ')})';
  }

  String _formatSyncErrorLine(SyncStatusSnapshot snapshot) {
    if (snapshot.lastFailure == null && (snapshot.lastError?.trim().isEmpty ?? true)) {
      return 'Sync Error: -';
    }
    final failureTime = snapshot.lastFailure == null
        ? '-'
        : DateFormat('h:mm a').format(snapshot.lastFailure!);
    final error = (snapshot.lastError ?? '').trim();
    if (error.isEmpty) {
      return 'Sync Error: (Last failure: $failureTime)';
    }
    return 'Sync Error: ${LogSanitizer.sanitizeText(error)} (Last failure: $failureTime)';
  }

  String _formatOutboxCounts(
    int pendingQueue,
    int failedQueue,
    Map<String, _OutboxCounts> counts,
  ) {
    if (pendingQueue == 0 && failedQueue == 0) {
      return 'Outbox: pending=0 failed=0';
    }
    final parts = <String>[];
    final keys = counts.keys.toList()..sort();
    for (final key in keys) {
      final entry = counts[key]!;
      parts.add('$key(pending=${entry.pending}, failed=${entry.failed})');
    }
    final detail = parts.isEmpty ? '' : ' | ${parts.join('; ')}';
    return 'Outbox: pending=$pendingQueue failed=$failedQueue$detail';
  }

  void _appendNetworkEntries(StringBuffer buffer, List<NetworkRequestLog> entries) {
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
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
  }

  Future<Map<String, _OutboxCounts>> _loadOutboxTypeCounts(DatabaseExecutor sqlite) async {
    final rows = await sqlite.rawQuery('''
SELECT type, state, COUNT(*) AS count
FROM outbox
WHERE state IN (0, 2)
GROUP BY type, state;
''');
    final out = <String, _OutboxCounts>{};
    for (final row in rows) {
      final type = (row['type'] as String?)?.trim();
      final state = _readInt(row['state']);
      final count = _readInt(row['count']);
      if (type == null || type.isEmpty || count == null || count <= 0 || state == null) {
        continue;
      }
      final entry = out.putIfAbsent(type, () => _OutboxCounts());
      if (state == 2) {
        entry.failed += count;
      } else {
        entry.pending += count;
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _loadOutboxItems(
    DatabaseExecutor sqlite, {
    required int state,
    required int limit,
  }) async {
    if (limit <= 0) return const [];
    final rows = await sqlite.query(
      'outbox',
      where: 'state = ?',
      whereArgs: [state],
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map((row) => row.map((key, value) => MapEntry(key, value))).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadMemoSyncErrors(
    DatabaseExecutor sqlite, {
    required int limit,
  }) async {
    if (limit <= 0) return const [];
    final rows = await sqlite.query(
      'memos',
      columns: const ['uid', 'last_error', 'update_time'],
      where: 'sync_state = 2',
      orderBy: 'update_time DESC',
      limit: limit,
    );
    return rows.map((row) => row.map((key, value) => MapEntry(key, value))).toList(growable: false);
  }

  String _formatOutboxItem(Map<String, dynamic> row) {
    final id = row['id'];
    final type = (row['type'] as String?)?.trim() ?? 'unknown';
    final attempts = _readInt(row['attempts']) ?? 0;
    final created = _formatEpochMs(row['created_time']);
    final lastError = LogSanitizer.sanitizeText((row['last_error'] as String?) ?? '').trim();
    final payloadSummary = _summarizeOutboxPayload(type, row['payload']);
    final parts = <String>[
      '#$id',
      type,
      'attempts=$attempts',
      'at=$created',
    ];
    if (payloadSummary.isNotEmpty) {
      parts.add(payloadSummary);
    }
    if (lastError.isNotEmpty) {
      parts.add('error=$lastError');
    }
    return parts.join(' | ');
  }

  String _formatMemoSyncError(Map<String, dynamic> row) {
    final uid = (row['uid'] as String?)?.trim() ?? '';
    final updated = _formatEpochSec(row['update_time']);
    final lastError = LogSanitizer.sanitizeText((row['last_error'] as String?) ?? '').trim();
    if (lastError.isEmpty) {
      return 'uid=$uid at=$updated';
    }
    return 'uid=$uid at=$updated | error=$lastError';
  }

  String _summarizeOutboxPayload(String type, Object? payloadRaw) {
    final payload = _decodePayload(payloadRaw);
    if (payload == null) return '';
    switch (type) {
      case 'upload_attachment':
        return _summarizeUploadAttachmentPayload(payload);
      case 'create_memo':
        return _summarizeCreateMemoPayload(payload);
      case 'update_memo':
        return _summarizeUpdateMemoPayload(payload);
      case 'delete_memo':
        return _summarizeDeleteMemoPayload(payload);
      default:
        final sanitized = LogSanitizer.sanitizeJson(payload);
        return LogSanitizer.stringify(sanitized, maxLength: 200);
    }
  }

  Map<String, dynamic>? _decodePayload(Object? raw) {
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return null;
  }

  String _summarizeUploadAttachmentPayload(Map<String, dynamic> payload) {
    final memoUid = _readString(payload['memo_uid']);
    final uid = _readString(payload['uid']);
    final filename = _readString(payload['filename']);
    final mimeType = _readString(payload['mime_type']);
    final size = _readInt(payload['file_size']);
    final parts = <String>[];
    if (memoUid.isNotEmpty) parts.add('memo=$memoUid');
    if (uid.isNotEmpty) parts.add('uid=$uid');
    if (filename.isNotEmpty) parts.add('file=${LogSanitizer.sanitizeText(filename)}');
    if (mimeType.isNotEmpty) parts.add('mime=${LogSanitizer.sanitizeText(mimeType)}');
    if (size != null && size > 0) parts.add('size=${_formatBytes(size)}');
    return parts.join(', ');
  }

  String _summarizeCreateMemoPayload(Map<String, dynamic> payload) {
    final uid = _readString(payload['uid']);
    final visibility = _readString(payload['visibility']);
    final pinned = _readBool(payload['pinned']);
    final hasAttachments = _readBool(payload['has_attachments']);
    final relations = payload['relations'] is List ? (payload['relations'] as List).length : null;
    final contentLength = payload['content'] is String ? (payload['content'] as String).length : null;
    final location = _summarizeLocationPayload(payload);
    final parts = <String>[];
    if (uid.isNotEmpty) parts.add('uid=$uid');
    if (visibility.isNotEmpty) parts.add('vis=$visibility');
    if (pinned != null) parts.add('pinned=$pinned');
    if (hasAttachments != null) parts.add('attachments=$hasAttachments');
    if (contentLength != null) parts.add('content_len=$contentLength');
    if (relations != null) parts.add('relations=$relations');
    if (location != null) parts.add('location=$location');
    return parts.join(', ');
  }

  String _summarizeUpdateMemoPayload(Map<String, dynamic> payload) {
    final uid = _readString(payload['uid']);
    final fields = <String>[];
    for (final key in const [
      'content',
      'visibility',
      'pinned',
      'state',
      'display_time',
      'displayTime',
      'relations',
      'location',
    ]) {
      if (payload.containsKey(key)) {
        fields.add(key);
      }
    }
    final parts = <String>[];
    if (uid.isNotEmpty) parts.add('uid=$uid');
    if (fields.isNotEmpty) parts.add('fields=${fields.join('/')}');
    final contentLength = payload['content'] is String ? (payload['content'] as String).length : null;
    if (contentLength != null) parts.add('content_len=$contentLength');
    final location = _summarizeLocationPayload(payload);
    if (location != null) parts.add('location=$location');
    return parts.join(', ');
  }

  String? _summarizeLocationPayload(Map<String, dynamic> payload) {
    if (!payload.containsKey('location')) return null;
    final raw = payload['location'];
    if (raw == null) return 'null';
    if (raw is! Map) return 'invalid';
    final json = raw.cast<String, dynamic>();
    final fp = LogSanitizer.locationFingerprint(
      latitude: json['latitude'],
      longitude: json['longitude'],
      locationName: _readString(json['placeholder']),
    );
    if (fp.isEmpty) return 'present';
    return 'present;loc_fp=$fp';
  }

  String _summarizeDeleteMemoPayload(Map<String, dynamic> payload) {
    final uid = _readString(payload['uid']);
    final force = _readBool(payload['force']);
    if (force == null) return uid.isEmpty ? '' : 'uid=$uid';
    return 'uid=$uid, force=$force';
  }

  String _formatEpochMs(dynamic value) {
    final ms = _readInt(value);
    if (ms == null || ms <= 0) return '-';
    final time = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return DateFormat('HH:mm:ss').format(time);
  }

  String _formatEpochSec(dynamic value) {
    final seconds = _readInt(value);
    if (seconds == null || seconds <= 0) return '-';
    final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).toLocal();
    return DateFormat('HH:mm:ss').format(time);
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }

  String _readString(dynamic value) {
    if (value is String) return value.trim();
    if (value == null) return '';
    return value.toString().trim();
  }

  String _formatBytes(int size) {
    if (size < 1024) return '${size}B';
    final kb = size / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)}MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)}GB';
  }

  List<NetworkRequestLog> _filterNetworkErrors(List<NetworkRequestLog> entries) {
    final out = <NetworkRequestLog>[];
    for (final entry in entries) {
      final status = entry.statusCode;
      final hasError = entry.errorMessage != null && entry.errorMessage!.trim().isNotEmpty;
      if (status == null || status >= 400 || hasError) {
        out.add(entry);
      }
    }
    return out;
  }

  List<NetworkLogEntry> _filterStoreNetworkErrors(List<NetworkLogEntry> entries) {
    final out = <NetworkLogEntry>[];
    for (final entry in entries) {
      final status = entry.status;
      final hasError = entry.error != null && entry.error!.trim().isNotEmpty;
      if (entry.type == 'error' || status == null || status >= 400 || hasError) {
        out.add(entry);
      }
    }
    return out;
  }

  List<NetworkRequestLog> _tail(List<NetworkRequestLog> entries, int limit) {
    if (limit <= 0 || entries.isEmpty) return const [];
    final start = entries.length > limit ? entries.length - limit : 0;
    return List<NetworkRequestLog>.unmodifiable(entries.sublist(start));
  }

  List<NetworkLogEntry> _tailStoreEntries(List<NetworkLogEntry> entries, int limit) {
    if (limit <= 0 || entries.isEmpty) return const [];
    final start = entries.length > limit ? entries.length - limit : 0;
    return List<NetworkLogEntry>.unmodifiable(entries.sublist(start));
  }

  void _appendStoreNetworkEntries(StringBuffer buffer, List<NetworkLogEntry> entries) {
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final statusLabel = entry.status?.toString() ?? '-';
      final durationLabel = entry.durationMs == null ? '?ms' : '${entry.durationMs}ms';
      buffer.writeln('------------------------------------------------');
      buffer.writeln(
        '${i + 1}. [${entry.type.toUpperCase()}] ${entry.method} ${entry.url} '
        '(status=$statusLabel, $durationLabel)',
      );
      final requestId = entry.requestId?.trim() ?? '';
      if (requestId.isNotEmpty) {
        buffer.writeln('   RequestId: $requestId');
      }
      final headers = entry.headers;
      if (headers != null && headers.isNotEmpty) {
        buffer.writeln(
          '   Headers: ${LogSanitizer.stringify(LogSanitizer.sanitizeJson(headers), maxLength: 800)}',
        );
      }
      final body = entry.body;
      if (body != null && body.trim().isNotEmpty) {
        buffer.writeln('   Body: $body');
      }
      final error = entry.error;
      if (error != null && error.trim().isNotEmpty) {
        buffer.writeln('   Error: $error');
      }
    }
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

class _OutboxCounts {
  int pending = 0;
  int failed = 0;
}
