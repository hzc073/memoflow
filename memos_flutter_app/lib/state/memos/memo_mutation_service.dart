import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memo_relations.dart';
import '../../core/tags.dart';
import '../../application/sync/sync_error.dart';
import '../../data/db/app_database.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_clip_card_metadata.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_relation.dart';
import '../../features/share/share_clip_models.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import '../system/database_provider.dart';
import '../system/reminder_scheduler.dart';
import 'create_memo_outbox_enqueue.dart';
import 'create_memo_outbox_payload.dart';
import 'memo_composer_state.dart';
import 'memo_sync_constraints.dart';
import 'memo_timeline_provider.dart';

final memoMutationServiceProvider = Provider<MemoMutationService>((ref) {
  return MemoMutationService(ref: ref, db: ref.watch(databaseProvider));
});

class MemoMutationService {
  MemoMutationService({required Ref ref, required this.db}) : _ref = ref;

  final Ref _ref;
  final AppDatabase db;

  Future<void> createQuickInputMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
  }) async {
    final db = this.db;
    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: nowSec,
      updateTimeSec: nowSec,
      tags: tags,
      attachments: const <Map<String, dynamic>>[],
      location: null,
      relationCount: 0,
      syncState: 1,
    );

    final allowed = await guardMemoContentForCurrentSyncTarget(
      read: _ref.read,
      db: db,
      memoUid: uid,
      content: content,
    );
    if (!allowed) return;
    await db.enqueueOutbox(
      type: 'create_memo',
      payload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        createTimeSec: nowSec,
        hasAttachments: false,
      ),
    );
  }

  Future<void> upsertMemoClipCardMetadata(MemoClipCardMetadata metadata) {
    return db.upsertMemoClipCard(metadata);
  }

  Future<int> retryOutboxErrors({required String memoUid}) async {
    return db.retryOutboxErrors(memoUid: memoUid);
  }

  Future<void> retryOutboxItem({required int outboxId}) async {
    await db.retryOutboxItem(outboxId);
  }

  Future<void> deleteMemoAfterRecycleBinMove(LocalMemo memo) async {
    final memoUid = memo.uid.trim();
    if (memoUid.isEmpty) return;

    final db = this.db;
    final shouldCleanupCreateDraftAttachments = await db
        .hasPendingOutboxTaskForMemo(memoUid, types: const {'create_memo'});
    final draftAttachmentNames = shouldCleanupCreateDraftAttachments
        ? memo.attachments
              .map((attachment) => attachment.name.trim())
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    await db.deleteMemoAfterRecycleBinMove(
      memoUid: memoUid,
      draftAttachmentNames: draftAttachmentNames,
    );
    await _ref.read(reminderSchedulerProvider).rescheduleAll();
  }

  Future<void> deleteMemoSyncTasksPreservingLocalOnly({
    required String memoUid,
    Map<String, dynamic>? existingRow,
  }) async {
    final db = this.db;
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    await db.deleteOutboxForMemo(normalizedUid);
    await _preserveMemoAsLocalOnly(db, normalizedUid, existingRow: existingRow);
  }

  Future<void> deleteSyncQueueItem({
    required int outboxId,
    String? memoUid,
    String? attachmentUid,
    bool keepDeleteTombstoneLocalOnly = false,
  }) async {
    final db = this.db;
    final normalizedUid = memoUid?.trim();
    if (normalizedUid != null &&
        normalizedUid.isNotEmpty &&
        keepDeleteTombstoneLocalOnly) {
      await db.upsertMemoDeleteTombstone(
        memoUid: normalizedUid,
        state: AppDatabase.memoDeleteTombstoneStateLocalOnly,
      );
    }

    await db.deleteOutbox(outboxId);

    final normalizedAttachmentUid = attachmentUid?.trim();
    if (normalizedUid != null &&
        normalizedUid.isNotEmpty &&
        normalizedAttachmentUid != null &&
        normalizedAttachmentUid.isNotEmpty) {
      await db.removePendingAttachmentPlaceholder(
        memoUid: normalizedUid,
        attachmentUid: normalizedAttachmentUid,
      );
    }

    if (normalizedUid != null && normalizedUid.isNotEmpty) {
      await _clearMemoSyncErrorIfIdle(db, normalizedUid);
    }
  }

  Future<bool> rebuildMemoSyncQueue({
    required LocalMemo memo,
    required List<int> attentionIds,
    required bool hasActiveItems,
    required String rootType,
    required List<Map<String, dynamic>> uploadPayloads,
    required List<Map<String, dynamic>> deletePayloads,
    required List<Map<String, dynamic>> relations,
    required bool shouldSyncAttachments,
  }) async {
    final db = this.db;

    if (hasActiveItems) {
      await db.deleteOutboxItems(attentionIds);
      await db.updateMemoSyncState(memo.uid, syncState: 1, lastError: null);
      return true;
    }

    if (rootType == 'create_memo') {
      await enqueueCreateMemoWithAttachmentUploads(
        read: _ref.read,
        createPayload: buildCreateMemoOutboxPayload(
          uid: memo.uid,
          content: memo.content,
          visibility: memo.visibility,
          pinned: memo.pinned,
          createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
          displayTimeSec: memo.displayTime == null
              ? null
              : memo.displayTime!.toUtc().millisecondsSinceEpoch ~/ 1000,
          hasAttachments: memo.attachments.isNotEmpty,
          location: memo.location,
          relations: relations,
        ),
        attachmentPayloads: uploadPayloads,
        enqueueOutboxBatch: (items) => db.enqueueOutboxBatch(items: items),
      );
      if (deletePayloads.isNotEmpty) {
        await db.enqueueOutboxBatch(
          items: deletePayloads
              .map(
                (payload) => <String, Object?>{
                  'type': 'delete_attachment',
                  'payload': payload,
                },
              )
              .toList(growable: false),
        );
      }
    } else {
      final outboxItems = <Map<String, Object?>>[
        <String, Object?>{
          'type': 'update_memo',
          'payload': <String, Object?>{
            'uid': memo.uid,
            'content': memo.content,
            'visibility': memo.visibility,
            'pinned': memo.pinned,
            if (memo.state.trim().isNotEmpty && memo.state != 'NORMAL')
              'state': memo.state,
            if (memo.location != null) 'location': memo.location!.toJson(),
            if (relations.isNotEmpty) 'relations': relations,
            if (shouldSyncAttachments) 'sync_attachments': true,
            if (uploadPayloads.isNotEmpty) 'has_pending_attachments': true,
          },
        },
        ...uploadPayloads.map(
          (payload) => <String, Object?>{
            'type': 'upload_attachment',
            'payload': payload,
          },
        ),
        ...deletePayloads.map(
          (payload) => <String, Object?>{
            'type': 'delete_attachment',
            'payload': payload,
          },
        ),
      ];
      await db.enqueueOutboxBatch(items: outboxItems);
    }

    await db.deleteOutboxItems(attentionIds);
    await db.updateMemoSyncState(memo.uid, syncState: 1, lastError: null);
    return true;
  }

  Future<void> createInlineComposeMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required List<Map<String, dynamic>> relations,
    required List<MemoComposerPendingAttachment> pendingAttachments,
  }) async {
    final db = this.db;
    final attachmentPayloads = pendingAttachments
        .map(
          (attachment) => <String, dynamic>{
            'uid': attachment.uid,
            'memo_uid': uid,
            'file_path': attachment.filePath,
            'filename': attachment.filename,
            'mime_type': attachment.mimeType,
            'file_size': attachment.size,
          },
        )
        .toList(growable: false);
    final localAttachments = mergePendingAttachmentPlaceholders(
      attachments: attachments,
      pendingAttachments: attachmentPayloads,
    );
    final cachedRelations = mergeOutgoingReferenceRelations(
      memoUid: uid,
      existingRelations: const [],
      nextRelations: relations,
      memoSnippet: content,
    );
    final relationCount = countReferenceRelations(
      memoUid: uid,
      relations: cachedRelations,
    );

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: nowSec,
      updateTimeSec: nowSec,
      tags: tags,
      attachments: localAttachments,
      location: location,
      relationCount: relationCount,
      syncState: 1,
    );
    if (cachedRelations.isEmpty) {
      await db.deleteMemoRelationsCache(uid);
    } else {
      await db.upsertMemoRelationsCache(
        uid,
        relationsJson: encodeMemoRelationsJson(cachedRelations),
      );
    }

    final hasAttachments = pendingAttachments.isNotEmpty;
    await enqueueCreateMemoWithAttachmentUploads(
      read: _ref.read,
      createPayload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        createTimeSec: nowSec,
        hasAttachments: hasAttachments,
        location: location,
        relations: relations,
      ),
      attachmentPayloads: attachmentPayloads,
      enqueueOutboxBatch: (items) => db.enqueueOutboxBatch(items: items),
    );
  }

  Future<void> createNoteInputMemo({
    required String uid,
    required String content,
    String? syncContent,
    required String visibility,
    required DateTime now,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required bool hasAttachments,
    required List<Map<String, dynamic>> relations,
    required List<Map<String, dynamic>> attachmentPayloads,
    List<Map<String, String>> inlineImageSourceMappings =
        const <Map<String, String>>[],
    ShareClipMetadataDraft? clipMetadataDraft,
  }) async {
    final db = this.db;
    final localAttachments = mergePendingAttachmentPlaceholders(
      attachments: attachments,
      pendingAttachments: attachmentPayloads,
    );
    final cachedRelations = mergeOutgoingReferenceRelations(
      memoUid: uid,
      existingRelations: const [],
      nextRelations: relations,
      memoSnippet: content,
    );
    final relationCount = countReferenceRelations(
      memoUid: uid,
      relations: cachedRelations,
    );

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: localAttachments,
      location: location,
      relationCount: relationCount,
      syncState: 1,
    );
    if (cachedRelations.isEmpty) {
      await db.deleteMemoRelationsCache(uid);
    } else {
      await db.upsertMemoRelationsCache(
        uid,
        relationsJson: encodeMemoRelationsJson(cachedRelations),
      );
    }

    for (final mapping in inlineImageSourceMappings) {
      final localUrl = (mapping['localUrl'] ?? '').trim();
      final sourceUrl = (mapping['sourceUrl'] ?? '').trim();
      if (localUrl.isEmpty || sourceUrl.isEmpty) continue;
      await db.upsertMemoInlineImageSource(
        memoUid: uid,
        localUrl: localUrl,
        sourceUrl: sourceUrl,
      );
    }

    if (clipMetadataDraft != null) {
      await db.upsertMemoClipCard(
        clipMetadataDraft.toMemoClipCardMetadata(memoUid: uid, now: now),
      );
    }

    await enqueueCreateMemoWithAttachmentUploads(
      read: _ref.read,
      createPayload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: syncContent ?? content,
        visibility: visibility,
        pinned: false,
        createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        hasAttachments: hasAttachments,
        location: location,
        relations: relations,
      ),
      attachmentPayloads: attachmentPayloads,
      enqueueOutboxBatch: (items) => db.enqueueOutboxBatch(items: items),
    );
  }

  Future<void> updateMemo(LocalMemo memo, {bool? pinned, String? state}) async {
    final now = DateTime.now();
    final db = this.db;
    final syncPolicy = resolveMemoSyncMutationPolicy(
      currentLastError: memo.lastError,
    );

    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: pinned ?? memo.pinned,
      state: state ?? memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: memo.attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: syncPolicy.syncState,
      lastError: syncPolicy.lastError,
    );

    if (!syncPolicy.allowRemoteSync) return;
    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        if (pinned != null) 'pinned': pinned,
        if (state != null) 'state': state,
      },
    );
  }

  Future<void> updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
  }) async {
    if (content == memo.content) return;
    final updateTime = preserveUpdateTime ? memo.updateTime : DateTime.now();
    final db = this.db;
    final timelineService = _ref.read(memoTimelineServiceProvider);
    final tags = extractTags(content);
    final syncPolicy = resolveMemoSyncMutationPolicy(
      currentLastError: memo.lastError,
    );

    await timelineService.captureMemoVersion(memo);

    await db.upsertMemo(
      uid: memo.uid,
      content: content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: memo.attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: syncPolicy.syncState,
      lastError: syncPolicy.lastError,
    );

    final allowed =
        syncPolicy.allowRemoteSync &&
        await guardMemoContentForCurrentSyncTarget(
          read: _ref.read,
          db: db,
          memoUid: memo.uid,
          content: content,
        );
    if (!allowed) return;

    final updatedPendingCreateCount = await db.updatePendingCreateMemoContent(
      memoUid: memo.uid,
      content: content,
      visibility: memo.visibility,
    );
    if (updatedPendingCreateCount > 0) {
      return;
    }

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': content,
        'visibility': memo.visibility,
      },
    );
  }

  Future<void> updateMemoContentForTaskToggle({
    required LocalMemo memo,
    required String content,
    required DateTime updateTime,
    required List<String> tags,
  }) async {
    final db = this.db;
    final timelineService = _ref.read(memoTimelineServiceProvider);
    final syncPolicy = resolveMemoSyncMutationPolicy(
      currentLastError: memo.lastError,
    );

    await timelineService.captureMemoVersion(memo);
    await db.upsertMemo(
      uid: memo.uid,
      content: content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: memo.attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: syncPolicy.syncState,
      lastError: syncPolicy.lastError,
    );

    final allowed =
        syncPolicy.allowRemoteSync &&
        await guardMemoContentForCurrentSyncTarget(
          read: _ref.read,
          db: db,
          memoUid: memo.uid,
          content: content,
        );
    if (!allowed) return;
    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': content,
        'visibility': memo.visibility,
        'pinned': memo.pinned,
      },
    );
  }

  Future<void> replaceMemoAttachment({
    required LocalMemo memo,
    required Attachment oldAttachment,
    required List<Attachment> updatedAttachments,
    required int index,
    required String newUid,
    required String filePath,
    required String filename,
    required String mimeType,
    required int size,
    required DateTime now,
  }) async {
    final db = this.db;
    final timelineService = _ref.read(memoTimelineServiceProvider);
    final queuedAttachmentStager = _ref.read(queuedAttachmentStagerProvider);
    final syncPolicy = resolveMemoSyncMutationPolicy(
      currentLastError: memo.lastError,
    );
    final stagedPayload = await queuedAttachmentStager.stageUploadPayload({
      'uid': newUid,
      'memo_uid': memo.uid,
      'file_path': filePath,
      'filename': filename,
      'mime_type': mimeType,
      'file_size': size,
    }, scopeKey: memo.uid);
    final stagedFilePath = (stagedPayload['file_path'] as String? ?? '').trim();
    final stagedFilename = (stagedPayload['filename'] as String? ?? '').trim();
    final stagedMimeType =
        (stagedPayload['mime_type'] as String? ?? 'application/octet-stream')
            .trim();
    final stagedSize = switch (stagedPayload['file_size']) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? size,
      _ => size,
    };
    final stagedAttachments = <Attachment>[...updatedAttachments];
    stagedAttachments[index] = Attachment(
      name: 'attachments/$newUid',
      filename: stagedFilename.isEmpty ? filename : stagedFilename,
      type: stagedMimeType,
      size: stagedSize,
      externalLink: Uri.file(stagedFilePath).toString(),
    );

    await timelineService.captureMemoVersion(memo);
    await timelineService.moveAttachmentToRecycleBin(
      memo: memo,
      attachment: oldAttachment,
      index: index,
    );
    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: stagedAttachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: syncPolicy.syncState,
      lastError: syncPolicy.lastError,
    );

    final allowed =
        syncPolicy.allowRemoteSync &&
        await guardMemoContentForCurrentSyncTarget(
          read: _ref.read,
          db: db,
          memoUid: memo.uid,
          content: memo.content,
        );
    if (!allowed) return;
    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': memo.content,
        'visibility': memo.visibility,
        'pinned': memo.pinned,
        'sync_attachments': true,
        'has_pending_attachments': true,
      },
    );
    await db.enqueueOutbox(type: 'upload_attachment', payload: stagedPayload);
    final oldName = oldAttachment.name.isNotEmpty
        ? oldAttachment.name
        : oldAttachment.uid;
    if (oldName.isNotEmpty) {
      await db.enqueueOutbox(
        type: 'delete_attachment',
        payload: {'attachment_name': oldName, 'memo_uid': memo.uid},
      );
    }
  }

  Future<void> saveEditedMemo({
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
    required List<MemoComposerPendingAttachment> pendingAttachments,
  }) async {
    final db = this.db;
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
    final syncPolicy = resolveMemoSyncMutationPolicy(
      currentLastError: existing?.lastError,
    );
    List<MemoRelation>? cachedRelations;
    var nextRelationCount = relationCount;
    if (includeRelations) {
      final existingRelationsJson = await db.getMemoRelationsCacheJson(uid);
      cachedRelations = mergeOutgoingReferenceRelations(
        memoUid: uid,
        existingRelations: existingRelationsJson == null
            ? const <MemoRelation>[]
            : decodeMemoRelationsJson(existingRelationsJson),
        nextRelations: relations,
        memoSnippet: content,
      );
      nextRelationCount = countReferenceRelations(
        memoUid: uid,
        relations: cachedRelations,
      );
    }

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
      relationCount: nextRelationCount,
      syncState: syncPolicy.syncState,
      lastError: syncPolicy.lastError,
    );
    if (includeRelations) {
      if (cachedRelations!.isEmpty) {
        await db.deleteMemoRelationsCache(uid);
      } else {
        await db.upsertMemoRelationsCache(
          uid,
          relationsJson: encodeMemoRelationsJson(cachedRelations),
        );
      }
    }

    if (existing == null) {
      await enqueueCreateMemoWithAttachmentUploads(
        read: _ref.read,
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
        enqueueOutboxBatch: (items) => db.enqueueOutboxBatch(items: items),
      );
    } else {
      final allowed =
          syncPolicy.allowRemoteSync &&
          await guardMemoContentForCurrentSyncTarget(
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

    if (existing != null && syncPolicy.allowRemoteSync) {
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
    if (hasPendingAttachments && syncPolicy.allowRemoteSync) {
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

  Future<void> appendDeferredThirdPartyShareInlineImage({
    required LocalMemo memo,
    required String updatedContent,
    required List<Map<String, dynamic>> updatedAttachments,
    required String localUrl,
    required String normalizedSourceUrl,
    required Map<String, dynamic> stagedUploadPayload,
  }) async {
    final contentChanged = updatedContent != memo.content;
    final attachmentsChanged =
        updatedAttachments.length != memo.attachments.length;
    if (!contentChanged && !attachmentsChanged) return;
    final db = this.db;
    final now = DateTime.now().toUtc();
    final syncPolicy = resolveMemoSyncMutationPolicy(
      currentLastError: memo.lastError,
    );

    await db.upsertMemo(
      uid: memo.uid,
      content: updatedContent,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: extractTags(updatedContent),
      attachments: updatedAttachments,
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: syncPolicy.syncState,
      lastError: syncPolicy.lastError,
    );

    if (normalizedSourceUrl.isNotEmpty && localUrl.trim().isNotEmpty) {
      await db.upsertMemoInlineImageSource(
        memoUid: memo.uid,
        localUrl: localUrl.trim(),
        sourceUrl: normalizedSourceUrl,
      );
    }

    final allowed =
        syncPolicy.allowRemoteSync &&
        await guardMemoContentForCurrentSyncTarget(
          read: _ref.read,
          db: db,
          memoUid: memo.uid,
          content: updatedContent,
        );
    if (!allowed) return;
    await db.enqueueOutboxBatch(
      items: [
        <String, Object?>{
          'type': 'update_memo',
          'payload': <String, Object?>{
            'uid': memo.uid,
            'content': updatedContent,
            'visibility': memo.visibility,
            'pinned': memo.pinned,
            'has_pending_attachments': true,
          },
        },
        <String, Object?>{
          'type': 'upload_attachment',
          'payload': stagedUploadPayload,
        },
      ],
    );
  }

  Future<void> cacheRemoteMemoForOpen({
    required Memo remoteMemo,
    required String fallbackUid,
  }) async {
    final remoteUid = remoteMemo.uid.isNotEmpty ? remoteMemo.uid : fallbackUid;
    final db = this.db;
    await db.upsertMemo(
      uid: remoteUid,
      content: remoteMemo.content,
      visibility: remoteMemo.visibility,
      pinned: remoteMemo.pinned,
      state: remoteMemo.state,
      createTimeSec:
          remoteMemo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec:
          remoteMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: remoteMemo.tags,
      attachments: remoteMemo.attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: remoteMemo.location,
      relationCount: countReferenceRelations(
        memoUid: remoteUid,
        relations: remoteMemo.relations,
      ),
      syncState: 0,
    );
  }

  Future<void> _clearMemoSyncErrorIfIdle(AppDatabase db, String memoUid) async {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return;
    final pending = await db.listPendingOutboxMemoUids();
    if (pending.contains(trimmed)) return;
    final row = await db.getMemoByUid(trimmed);
    final currentLastError = row?['last_error'] as String?;
    if (isLocalOnlySyncPausedError(currentLastError)) {
      await _preserveMemoAsLocalOnly(db, trimmed, existingRow: row);
      return;
    }
    await db.updateMemoSyncState(trimmed, syncState: 0, lastError: null);
  }

  Future<void> _preserveMemoAsLocalOnly(
    AppDatabase db,
    String memoUid, {
    Map<String, dynamic>? existingRow,
  }) async {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return;
    final row = existingRow ?? await db.getMemoByUid(trimmed);
    if (row == null) return;
    final currentLastError = row['last_error'] as String?;
    await db.updateMemoSyncState(
      trimmed,
      syncState: SyncState.error.index,
      lastError: markLocalOnlySyncPausedError(currentLastError),
    );
  }
}
