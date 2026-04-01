import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/logs/log_manager.dart';
import '../system/database_provider.dart';
import 'sync_queue_models.dart';

const _syncQueueDisplayLimit = 200;

final syncQueueItemsProvider = StreamProvider<List<SyncQueueItem>>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);
  var lastItems = const <SyncQueueItem>[];

  Future<List<SyncQueueItem>> load() async {
    final items = await _watchQueueItems(
      db: db,
      loadRows: () => db.listOutboxPending(limit: _syncQueueDisplayLimit),
      lockedLogKey: 'SyncQueue: list_pending_skipped_database_locked',
      fallbackItems: lastItems,
    );
    lastItems = items;
    return items;
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final syncQueueAttentionItemsProvider = StreamProvider<List<SyncQueueItem>>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);
  var lastItems = const <SyncQueueItem>[];

  Future<List<SyncQueueItem>> load() async {
    final items = await _watchQueueItems(
      db: db,
      loadRows: () => db.listOutboxAttention(limit: _syncQueueDisplayLimit),
      lockedLogKey: 'SyncQueue: list_attention_skipped_database_locked',
      fallbackItems: lastItems,
    );
    lastItems = items;
    return items;
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final syncQueuePendingCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  var lastCount = 0;

  Future<int> load() async {
    try {
      final count = await db.countOutboxPending();
      lastCount = count;
      return count;
    } catch (e, st) {
      if (_isDatabaseLockedError(e)) {
        LogManager.instance.warn(
          'SyncQueue: count_pending_skipped_database_locked',
          error: e,
          stackTrace: st,
        );
        return lastCount;
      }
      rethrow;
    }
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final syncQueueAttentionCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  var lastCount = 0;

  Future<int> load() async {
    try {
      final count = await db.countOutboxAttention();
      lastCount = count;
      return count;
    } catch (e, st) {
      if (_isDatabaseLockedError(e)) {
        LogManager.instance.warn(
          'SyncQueue: count_attention_skipped_database_locked',
          error: e,
          stackTrace: st,
        );
        return lastCount;
      }
      rethrow;
    }
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final syncQueueQuarantinedCountProvider = syncQueueAttentionCountProvider;

bool _isDatabaseLockedError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('database is locked') ||
      text.contains('sqlite_error: 5');
}

Future<List<SyncQueueItem>> _watchQueueItems({
  required AppDatabase db,
  required Future<List<Map<String, dynamic>>> Function() loadRows,
  required String lockedLogKey,
  required List<SyncQueueItem> fallbackItems,
}) async {
  try {
    final rows = await loadRows();
    final items = <SyncQueueItem>[];
    for (final row in rows) {
      final item = await _buildQueueItem(db, row);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  } catch (e, st) {
    if (_isDatabaseLockedError(e)) {
      LogManager.instance.warn(lockedLogKey, error: e, stackTrace: st);
      return fallbackItems;
    }
    rethrow;
  }
}

Future<SyncQueueItem?> _buildQueueItem(
  AppDatabase db,
  Map<String, dynamic> row,
) async {
  final id = row['id'];
  final type = row['type'];
  if (id is! int || type is! String) return null;

  final state = row['state'] as int? ?? 0;
  final attempts = row['attempts'] as int? ?? 0;
  final createdRaw = switch (state) {
    SyncQueueOutboxState.error || SyncQueueOutboxState.quarantined =>
      _parseEpochMs(row['quarantined_at']) ??
          _parseEpochMs(row['created_time']) ??
          0,
    _ => _parseEpochMs(row['created_time']) ?? 0,
  };
  final createdAt = createdRaw > 0
      ? DateTime.fromMillisecondsSinceEpoch(
          createdRaw > 10000000000 ? createdRaw : createdRaw * 1000,
          isUtc: true,
        ).toLocal()
      : DateTime.now();
  final retryAtRaw = row['retry_at'];
  final retryAtMs = switch (retryAtRaw) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v.trim()),
    _ => null,
  };
  final retryAt = retryAtMs == null || retryAtMs <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          retryAtMs > 10000000000 ? retryAtMs : retryAtMs * 1000,
          isUtc: true,
        ).toLocal();
  final lastError = row['last_error'] as String?;
  final failureCode = row['failure_code'] as String?;

  final payload = _decodePayload(row['payload']);
  final memoUid = _extractMemoUid(type, payload);
  final attachmentUid = _extractAttachmentUid(type, payload);
  var content = payload['content'];
  if (content is! String || content.trim().isEmpty) {
    if (memoUid != null && memoUid.trim().isNotEmpty) {
      final memoRow = await db.getMemoByUid(memoUid);
      final memoContent = memoRow?['content'];
      if (memoContent is String && memoContent.trim().isNotEmpty) {
        content = memoContent;
      }
    }
  }

  final preview = _firstNonEmptyLine(content is String ? content : null);
  final filename = payload['filename'] as String?;

  return SyncQueueItem(
    id: id,
    type: type,
    state: state,
    attempts: attempts,
    createdAt: createdAt,
    preview: preview,
    filename: filename,
    lastError: lastError,
    memoUid: memoUid,
    attachmentUid: attachmentUid,
    retryAt: retryAt,
    failureCode: failureCode,
  );
}

Map<String, dynamic> _decodePayload(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {}
  return const {};
}

String? _extractMemoUid(String type, Map<String, dynamic> payload) {
  return switch (type) {
    'create_memo' ||
    'update_memo' ||
    'delete_memo' => payload['uid'] as String?,
    'upload_attachment' ||
    'delete_attachment' => payload['memo_uid'] as String?,
    _ => null,
  };
}

String? _extractAttachmentUid(String type, Map<String, dynamic> payload) {
  return switch (type) {
    'upload_attachment' => payload['uid'] as String?,
    _ => null,
  };
}

int? _parseEpochMs(Object? raw) {
  return switch (raw) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value.trim()),
    _ => null,
  };
}

String? _firstNonEmptyLine(String? raw) {
  if (raw == null) return null;
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
