import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../data/db/app_database.dart';
import '../database_provider.dart';
import '../sync_coordinator_provider.dart';
import 'sync_queue_models.dart';

final syncQueueControllerProvider = Provider<SyncQueueController>((ref) {
  return SyncQueueController(ref);
});

class SyncQueueController {
  SyncQueueController(this._ref);

  final Ref _ref;

  Future<void> deleteItem(SyncQueueItem item) async {
    final db = _ref.read(databaseProvider);
    final memoUid = item.memoUid?.trim();
    if (memoUid != null && memoUid.isNotEmpty) {
      await db.deleteOutbox(item.id);
      if (item.type == 'upload_attachment' && item.attachmentUid != null) {
        await _removePendingAttachmentFromMemo(
          db,
          memoUid: memoUid,
          attachmentUid: item.attachmentUid!,
        );
      }
      await _clearMemoSyncErrorIfIdle(db, memoUid);
      return;
    }

    await db.deleteOutbox(item.id);
  }

  Future<void> retryItem(SyncQueueItem item) async {
    final db = _ref.read(databaseProvider);
    final memoUid = item.memoUid?.trim();
    if (memoUid != null && memoUid.isNotEmpty) {
      await db.retryOutboxErrors(memoUid: memoUid);
      return;
    }
    await db.retryOutboxErrors();
  }

  Future<SyncRunResult> requestSync() async {
    return _ref.read(syncCoordinatorProvider.notifier).requestSync(
          const SyncRequest(
            kind: SyncRequestKind.memos,
            reason: SyncRequestReason.manual,
          ),
        );
  }

  Future<void> _removePendingAttachmentFromMemo(
    AppDatabase db, {
    required String memoUid,
    required String attachmentUid,
  }) async {
    final trimmedMemoUid = memoUid.trim();
    final trimmedAttachmentUid = attachmentUid.trim();
    if (trimmedMemoUid.isEmpty || trimmedAttachmentUid.isEmpty) return;

    final row = await db.getMemoByUid(trimmedMemoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;

    final expectedNames = <String>{
      'attachments/$trimmedAttachmentUid',
      'resources/$trimmedAttachmentUid',
    };

    var changed = false;
    final next = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final name = (map['name'] as String?)?.trim() ?? '';
      if (expectedNames.contains(name)) {
        changed = true;
        continue;
      }
      next.add(map);
    }

    if (!changed) return;
    await db.updateMemoAttachmentsJson(
      trimmedMemoUid,
      attachmentsJson: jsonEncode(next),
    );
  }

  Future<void> _clearMemoSyncErrorIfIdle(
    AppDatabase db,
    String memoUid,
  ) async {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return;
    final pending = await db.listPendingOutboxMemoUids();
    if (pending.contains(trimmed)) return;
    await db.updateMemoSyncState(trimmed, syncState: 0, lastError: null);
  }
}
