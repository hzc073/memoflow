import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_relation.dart';
import '../../data/models/memo_location.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import 'create_memo_outbox_enqueue.dart';
import 'create_memo_outbox_payload.dart';
import '../system/database_provider.dart';
import 'memo_timeline_provider.dart';
import 'memos_providers.dart';

class MemoEditorPendingAttachment {
  const MemoEditorPendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.skipCompression = false,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final bool skipCompression;
}

class MemoEditorController {
  MemoEditorController(this._ref);

  final Ref _ref;

  Future<List<MemoRelation>> listMemoRelationsAll({
    required String memoUid,
  }) async {
    final api = _ref.read(memosApiProvider);
    final items = <MemoRelation>[];
    String? pageToken;
    do {
      final (relations, nextToken) = await api.listMemoRelations(
        memoUid: memoUid,
        pageSize: 200,
        pageToken: pageToken,
      );
      items.addAll(relations);
      pageToken = nextToken.trim().isEmpty ? null : nextToken;
    } while (pageToken != null);
    return items;
  }

  Future<void> saveMemo({
    required LocalMemo? existing,
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required DateTime createTime,
    required DateTime now,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required bool locationChanged,
    required int relationCount,
    required bool hasPrimaryChanges,
    required List<Attachment> attachmentsToDelete,
    required bool includeRelations,
    required List<Map<String, dynamic>> relations,
    required bool shouldSyncAttachments,
    required bool hasPendingAttachments,
    required List<MemoEditorPendingAttachment> pendingAttachments,
  }) async {
    final db = _ref.read(databaseProvider);
    final timelineService = _ref.read(memoTimelineServiceProvider);
    final queuedAttachmentStager = _ref.read(queuedAttachmentStagerProvider);

    if (existing != null && hasPrimaryChanges) {
      await timelineService.captureMemoVersion(existing);
    }
    if (existing != null && attachmentsToDelete.isNotEmpty) {
      for (final attachment in attachmentsToDelete) {
        final index = existing.attachments.indexWhere(
          (candidate) =>
              candidate.name == attachment.name ||
              candidate.uid == attachment.uid,
        );
        await timelineService.moveAttachmentToRecycleBin(
          memo: existing,
          attachment: attachment,
          index: index < 0 ? 0 : index,
        );
      }
    }
    final attachmentPayloads = existing == null
        ? await queuedAttachmentStager.stageUploadPayloads(
            pendingAttachments
                .map(
                  (attachment) => <String, dynamic>{
                    'uid': attachment.uid,
                    'memo_uid': uid,
                    'file_path': attachment.filePath,
                    'filename': attachment.filename,
                    'mime_type': attachment.mimeType,
                    'file_size': attachment.size,
                    'skip_compression': attachment.skipCompression,
                  },
                )
                .toList(growable: false),
            scopeKey: uid,
          )
        : const <Map<String, dynamic>>[];
    final localAttachments = existing == null
        ? mergePendingAttachmentPlaceholders(
            attachments: attachments,
            pendingAttachments: attachmentPayloads,
          )
        : attachments;

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTimeSec: createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: localAttachments,
      location: location,
      relationCount: relationCount,
      syncState: 1,
      lastError: null,
    );

    if (existing == null) {
      await enqueueCreateMemoWithAttachmentUploads(
        read: _ref.read,
        db: db,
        createPayload: buildCreateMemoOutboxPayload(
          uid: uid,
          content: content,
          visibility: visibility,
          pinned: pinned,
          createTimeSec: createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
          hasAttachments: localAttachments.isNotEmpty,
          location: location,
          relations: includeRelations ? relations : const [],
        ),
        attachmentPayloads: attachmentPayloads,
      );
    } else {
      final allowed = await guardMemoContentForCurrentSyncTarget(
        read: _ref.read,
        db: db,
        memoUid: uid,
        content: content,
      );
      if (allowed) {
        await db.enqueueOutbox(
          type: 'update_memo',
          payload: {
            'uid': uid,
            'content': content,
            'visibility': visibility,
            'pinned': pinned,
            if (locationChanged) 'location': location?.toJson(),
            if (includeRelations) 'relations': relations,
            if (shouldSyncAttachments) 'sync_attachments': true,
            if (hasPendingAttachments) 'has_pending_attachments': true,
          },
        );
      }
    }

    if (existing != null) {
      for (final attachment in pendingAttachments) {
        final stagedPayload = await queuedAttachmentStager.stageUploadPayload({
          'uid': attachment.uid,
          'memo_uid': uid,
          'file_path': attachment.filePath,
          'filename': attachment.filename,
          'mime_type': attachment.mimeType,
          'file_size': attachment.size,
          'skip_compression': attachment.skipCompression,
        }, scopeKey: uid);
        await db.enqueueOutbox(
          type: 'upload_attachment',
          payload: stagedPayload,
        );
      }
    }
    if (hasPendingAttachments) {
      for (final attachment in attachmentsToDelete) {
        final name = attachment.name.isNotEmpty
            ? attachment.name
            : attachment.uid;
        if (name.isEmpty) continue;
        await db.enqueueOutbox(
          type: 'delete_attachment',
          payload: {'attachment_name': name, 'memo_uid': uid},
        );
      }
    }
  }
}
