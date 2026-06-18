import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../core/tag_colors.dart';
import '../../core/tags.dart';
import '../ai/ai_analysis_models.dart';
import '../ai/ai_settings_models.dart';
import '../models/memo_clip_card_metadata.dart';
import '../models/memo_location.dart';
import '../models/quick_clip_recovery_job.dart';
import '../models/tag.dart';
import '../models/tag_snapshot.dart';
import 'ai_db_persistence.dart';
import 'app_database.dart';
import 'collection_db_persistence.dart';
import 'compose_draft_db_persistence.dart';
import 'memo_auxiliary_db_persistence.dart';
import 'memo_core_db_persistence.dart';
import 'memo_lifecycle_db_persistence.dart';
import 'memo_query_db_persistence.dart';
import 'memo_search_db_persistence.dart';
import 'memo_tag_reconciler.dart';
import 'memo_write_db_persistence.dart';
import 'outbox_db_persistence.dart';
import 'quick_clip_recovery_db_persistence.dart';
import 'tag_db_persistence.dart';

class AppDatabaseWriteDao {
  AppDatabaseWriteDao({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  static const Object noParentChange = Object();

  static Future<T> runTransaction<T>(
    Database db,
    Future<T> Function(Transaction txn) action,
  ) {
    return db.transaction<T>(action);
  }

  Future<void> upsertAiMemoPolicy({
    required String memoUid,
    required bool allowAi,
  }) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    final sqlite = await _db.db;
    await AiDbPersistence.upsertMemoPolicy(
      sqlite,
      memoUid: trimmedUid,
      allowAi: allowAi,
    );
    _db.notifyDataChanged();
  }

  Future<int> enqueueAiIndexJob({
    required String? memoUid,
    required AiIndexJobReason reason,
    required String memoContentHash,
    required String embeddingProfileKey,
    int priority = 100,
  }) async {
    final sqlite = await _db.db;
    final id = await AiDbPersistence.enqueueIndexJob(
      sqlite,
      memoUid: memoUid,
      reason: reason,
      memoContentHash: memoContentHash,
      embeddingProfileKey: embeddingProfileKey,
      priority: priority,
    );
    _db.notifyDataChanged();
    return id;
  }

  Future<void> updateAiIndexJobStatus(
    int jobId, {
    required AiIndexJobStatus status,
    int? attemptCount,
    String? errorText,
    bool markStarted = false,
    bool markFinished = false,
  }) async {
    final sqlite = await _db.db;
    await AiDbPersistence.updateIndexJobStatus(
      sqlite,
      jobId,
      status: status,
      attemptCount: attemptCount,
      errorText: errorText,
      markStarted: markStarted,
      markFinished: markFinished,
    );
    _db.notifyDataChanged();
  }

  Future<void> invalidateAiActiveChunksForMemo(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await AiDbPersistence.invalidateActiveChunksForMemo(txn, trimmedUid);
    });
    _db.notifyDataChanged();
  }

  Future<List<int>> insertAiActiveChunks({
    required String memoUid,
    required List<AiChunkDraft> chunks,
  }) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty || chunks.isEmpty) return const <int>[];
    final sqlite = await _db.db;
    late List<int> ids;
    await sqlite.transaction((txn) async {
      ids = await AiDbPersistence.insertActiveChunks(
        txn,
        memoUid: trimmedUid,
        chunks: chunks,
      );
    });
    _db.notifyDataChanged();
    return ids;
  }

  Future<void> insertAiEmbeddingRecord({
    required int chunkId,
    required AiEmbeddingProfile profile,
    required AiEmbeddingStatus status,
    Float32List? vector,
    String? errorText,
  }) async {
    final sqlite = await _db.db;
    await AiDbPersistence.insertEmbeddingRecord(
      sqlite,
      chunkId: chunkId,
      profile: profile,
      status: status,
      vector: vector,
      errorText: errorText,
    );
    _db.notifyDataChanged();
  }

  Future<int> createAiAnalysisTask({
    required String taskUid,
    required AiAnalysisType analysisType,
    required AiTaskStatus status,
    required int rangeStart,
    required int rangeEndExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
    required String promptTemplate,
    AiAnalysisTemplateKind templateKind = AiAnalysisTemplateKind.legacy,
    String templateId = '',
    String templateTitleSnapshot = '',
    String templateIconKeySnapshot = '',
    required String generationProfileKey,
    required String embeddingProfileKey,
    required Map<String, dynamic> retrievalProfile,
  }) async {
    final sqlite = await _db.db;
    final id = await AiDbPersistence.createAnalysisTask(
      sqlite,
      taskUid: taskUid,
      analysisType: analysisType,
      status: status,
      rangeStart: rangeStart,
      rangeEndExclusive: rangeEndExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
      promptTemplate: promptTemplate,
      templateKind: templateKind,
      templateId: templateId,
      templateTitleSnapshot: templateTitleSnapshot,
      templateIconKeySnapshot: templateIconKeySnapshot,
      generationProfileKey: generationProfileKey,
      embeddingProfileKey: embeddingProfileKey,
      retrievalProfile: retrievalProfile,
    );
    _db.notifyDataChanged();
    return id;
  }

  Future<void> updateAiAnalysisTaskStatus(
    int taskId, {
    required AiTaskStatus status,
    String? errorText,
    bool markCompleted = false,
  }) async {
    final sqlite = await _db.db;
    await AiDbPersistence.updateAnalysisTaskStatus(
      sqlite,
      taskId,
      status: status,
      errorText: errorText,
      markCompleted: markCompleted,
    );
    _db.notifyDataChanged();
  }

  Future<void> saveAiAnalysisResult({
    required int taskId,
    required AiStructuredAnalysisResult result,
  }) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await AiDbPersistence.saveAnalysisResult(
        txn,
        taskId: taskId,
        result: result,
      );
    });
    _db.notifyDataChanged();
  }

  Future<void> markAiResultsStaleForMemo(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    final sqlite = await _db.db;
    await AiDbPersistence.markResultsStaleForMemo(sqlite, trimmedUid);
    _db.notifyDataChanged();
  }

  Future<void> upsertMemo({
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    required Object? displayTimeSec,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
  }) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await _upsertMemo(
        txn,
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        createTimeSec: createTimeSec,
        displayTimeSec: displayTimeSec,
        preserveDisplayTime: _db.isDisplayTimeUnspecified(displayTimeSec),
        updateTimeSec: updateTimeSec,
        tags: tags,
        attachments: attachments,
        location: location,
        relationCount: relationCount,
        syncState: syncState,
        lastError: lastError,
      );
    });
    _db.notifyDataChanged();
  }

  Future<void> updateMemoSyncState(
    String uid, {
    required int syncState,
    String? lastError,
  }) async {
    final sqlite = await _db.db;
    await MemoWriteDbPersistence.updateMemoSyncState(
      sqlite,
      uid,
      syncState: syncState,
      lastError: lastError,
    );
    _db.notifyDataChanged();
  }

  Future<void> updateMemoAttachmentsJson(
    String uid, {
    required String attachmentsJson,
  }) async {
    final sqlite = await _db.db;
    await MemoWriteDbPersistence.updateMemoAttachmentsJson(
      sqlite,
      uid,
      attachmentsJson: attachmentsJson,
    );
    _db.notifyDataChanged();
  }

  Future<void> removePendingAttachmentPlaceholder({
    required String memoUid,
    required String attachmentUid,
  }) async {
    final trimmedMemoUid = memoUid.trim();
    final trimmedAttachmentUid = attachmentUid.trim();
    if (trimmedMemoUid.isEmpty || trimmedAttachmentUid.isEmpty) {
      return;
    }

    final sqlite = await _db.db;
    final changed =
        await MemoWriteDbPersistence.removePendingAttachmentPlaceholder(
          sqlite,
          memoUid: trimmedMemoUid,
          attachmentUid: trimmedAttachmentUid,
        );
    if (!changed) return;
    _db.notifyDataChanged();
  }

  Future<void> discardMissingSourceUploadTask({
    required int outboxId,
    required String memoUid,
    required String attachmentUid,
  }) async {
    final trimmedMemoUid = memoUid.trim();
    final trimmedAttachmentUid = attachmentUid.trim();
    final sqlite = await _db.db;

    await sqlite.transaction((txn) async {
      await OutboxDbPersistence.deleteById(txn, outboxId);

      if (trimmedMemoUid.isNotEmpty && trimmedAttachmentUid.isNotEmpty) {
        await _removePendingAttachmentPlaceholder(
          txn,
          memoUid: trimmedMemoUid,
          attachmentUid: trimmedAttachmentUid,
        );
      }

      if (trimmedMemoUid.isEmpty) return;

      final hasMorePending = await OutboxDbPersistence.hasPendingTaskForMemo(
        txn,
        trimmedMemoUid,
      );
      await MemoWriteDbPersistence.updateMemoSyncState(
        txn,
        trimmedMemoUid,
        syncState: hasMorePending ? 1 : 0,
      );
    });

    _db.notifyDataChanged();
  }

  Future<void> upsertMemoRelationsCache(
    String memoUid, {
    required String relationsJson,
  }) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.upsertMemoRelationsCache(
      sqlite,
      memoUid,
      relationsJson: relationsJson,
    );
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoRelationsCache(String memoUid) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.deleteMemoRelationsCache(sqlite, memoUid);
    _db.notifyDataChanged();
  }

  Future<int> insertMemoVersion({
    required String memoUid,
    required int snapshotTime,
    required String summary,
    required String payloadJson,
  }) async {
    final sqlite = await _db.db;
    final id = await MemoLifecycleDbPersistence.insertMemoVersion(
      sqlite,
      memoUid: memoUid,
      snapshotTime: snapshotTime,
      summary: summary,
      payloadJson: payloadJson,
    );
    _db.notifyDataChanged();
    return id;
  }

  Future<void> deleteMemoVersionById(int id) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.deleteMemoVersionById(sqlite, id);
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoVersionsByMemoUid(String memoUid) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.deleteMemoVersionsByMemoUid(
      sqlite,
      memoUid,
    );
    _db.notifyDataChanged();
  }

  Future<void> upsertMemoDeleteTombstone({
    required String memoUid,
    required String state,
    String? lastError,
    int? deletedTime,
  }) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.upsertMemoDeleteTombstone(
      sqlite,
      memoUid: memoUid,
      state: state,
      lastError: lastError,
      deletedTime: deletedTime,
    );
    _db.notifyDataChanged();
  }

  Future<void> upsertMemoInlineImageSource({
    required String memoUid,
    required String localUrl,
    required String sourceUrl,
  }) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.upsertMemoInlineImageSource(
      sqlite,
      memoUid: memoUid,
      localUrl: localUrl,
      sourceUrl: sourceUrl,
    );
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoInlineImageSources(String memoUid) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.deleteMemoInlineImageSources(
      sqlite,
      memoUid,
    );
    _db.notifyDataChanged();
  }

  Future<void> rebuildMemoTagsFromContent({
    TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
  }) async {
    final sqlite = await _db.db;
    var lastId = 0;
    var changed = false;
    while (true) {
      final rows = await MemoQueryDbPersistence.listMemoTagBackfillRows(
        sqlite,
        afterId: lastId,
        limit: AppDatabase.maintenanceBatchSize,
      );
      if (rows.isEmpty) break;
      lastId = _readInt(rows.last['id']) ?? lastId;
      await sqlite.transaction((txn) async {
        for (final row in rows) {
          final uid = row['uid'];
          if (uid is! String || uid.trim().isEmpty) continue;
          final content = (row['content'] as String?) ?? '';
          final reconciled = await MemoTagReconciler.reconcile(
            txn,
            extractTags(content, policy: policy),
          );
          await TagDbPersistence.updateMemoTagsMapping(
            txn,
            uid,
            reconciled.tagIds,
          );
          await _db.updateMemoTagsText(txn, uid, reconciled.canonicalPaths);
          changed = true;
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    if (changed) {
      _db.notifyDataChanged();
    }
  }

  Future<int> pruneOrphanTags() async {
    final sqlite = await _db.db;
    late final int prunedCount;
    await sqlite.transaction((txn) async {
      prunedCount = await TagDbPersistence.pruneOrphanTags(txn);
    });
    if (prunedCount > 0) {
      _db.notifyDataChanged();
    }
    return prunedCount;
  }

  Future<void> deleteMemoDeleteTombstone(String memoUid) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.deleteMemoDeleteTombstone(sqlite, memoUid);
    _db.notifyDataChanged();
  }

  Future<void> renameMemoUid({
    required String oldUid,
    required String newUid,
  }) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await _renameMemoUid(txn, oldUid: oldUid, newUid: newUid);
    });
    _db.notifyDataChanged();
  }

  Future<int> rewriteOutboxMemoUids({
    required String oldUid,
    required String newUid,
  }) async {
    final sqlite = await _db.db;
    final changedCount = await OutboxDbPersistence.rewriteMemoUids(
      sqlite,
      oldUid: oldUid,
      newUid: newUid,
    );
    if (changedCount > 0) {
      _db.notifyDataChanged();
    }
    return changedCount;
  }

  Future<int> renameMemoUidAndRewriteOutboxMemoUids({
    required String oldUid,
    required String newUid,
  }) async {
    final sqlite = await _db.db;
    late int changedCount;
    await sqlite.transaction((txn) async {
      await _renameMemoUid(txn, oldUid: oldUid, newUid: newUid);
      changedCount = await OutboxDbPersistence.rewriteMemoUids(
        txn,
        oldUid: oldUid,
        newUid: newUid,
      );
    });
    _db.notifyDataChanged();
    return changedCount;
  }

  Future<void> deleteMemoByUid(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await _deleteMemoByUid(txn, normalizedUid);
    });
    _db.notifyDataChanged();
  }

  Future<void> replaceMemoFromLocalLibrary({
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    Object? displayTimeSec,
    bool displayTimeSpecified = false,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
    bool clearOutbox = false,
    String relationsMode = 'none',
    String? relationsJson,
  }) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      if (clearOutbox) {
        await OutboxDbPersistence.deleteForMemo(txn, uid);
      }

      await _upsertMemo(
        txn,
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        createTimeSec: createTimeSec,
        displayTimeSec: displayTimeSec,
        preserveDisplayTime: !displayTimeSpecified,
        updateTimeSec: updateTimeSec,
        tags: tags,
        attachments: attachments,
        location: location,
        relationCount: relationCount,
        syncState: syncState,
        lastError: lastError,
      );

      switch (relationsMode) {
        case 'clear':
          await MemoLifecycleDbPersistence.deleteMemoRelationsCache(txn, uid);
          break;
        case 'set':
          final normalizedRelationsJson = (relationsJson ?? '').trim();
          if (normalizedRelationsJson.isNotEmpty) {
            await MemoLifecycleDbPersistence.upsertMemoRelationsCache(
              txn,
              uid,
              relationsJson: normalizedRelationsJson,
            );
          }
          break;
        case 'none':
        default:
          break;
      }
    });
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoFromLocalLibrary({required String memoUid}) async {
    final normalizedMemoUid = memoUid.trim();
    if (normalizedMemoUid.isEmpty) return;

    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await OutboxDbPersistence.deleteForMemo(txn, normalizedMemoUid);
      await _deleteMemoByUid(txn, normalizedMemoUid);
    });
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoAfterRecycleBinMove({
    required String memoUid,
    required List<String> draftAttachmentNames,
  }) async {
    final normalizedMemoUid = memoUid.trim();
    if (normalizedMemoUid.isEmpty) return;

    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await MemoLifecycleDbPersistence.upsertMemoDeleteTombstone(
        txn,
        memoUid: normalizedMemoUid,
        state: AppDatabase.memoDeleteTombstoneStatePendingRemoteDelete,
      );
      await OutboxDbPersistence.deleteForMemo(txn, normalizedMemoUid);

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final attachmentItems = <Map<String, Object?>>[
        for (final attachmentName in draftAttachmentNames)
          if (attachmentName.trim().isNotEmpty)
            <String, Object?>{
              'type': 'delete_attachment',
              'payload': <String, Object?>{
                'attachment_name': attachmentName.trim(),
                'memo_uid': normalizedMemoUid,
              },
            },
      ];
      if (attachmentItems.isNotEmpty) {
        await OutboxDbPersistence.enqueueBatch(
          txn,
          items: attachmentItems,
          createdTimeMs: now,
        );
      }

      await _deleteMemoByUid(txn, normalizedMemoUid);
      await OutboxDbPersistence.insertItem(
        txn,
        type: 'delete_memo',
        payload: <String, Object?>{'uid': normalizedMemoUid, 'force': false},
        createdTimeMs: now,
      );
    });
    _db.notifyDataChanged();
  }

  Future<void> upsertMemoReminder({
    required String memoUid,
    required String mode,
    required String timesJson,
  }) async {
    final sqlite = await _db.db;
    await MemoAuxiliaryDbPersistence.upsertMemoReminder(
      sqlite,
      memoUid: memoUid,
      mode: mode,
      timesJson: timesJson,
    );
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoReminder(String memoUid) async {
    final sqlite = await _db.db;
    await MemoAuxiliaryDbPersistence.deleteMemoReminder(sqlite, memoUid);
    _db.notifyDataChanged();
  }

  Future<void> upsertComposeDraftRow(Map<String, Object?> row) async {
    final sqlite = await _db.db;
    await ComposeDraftDbPersistence.upsertRow(sqlite, row);
    _db.notifyDataChanged();
  }

  Future<void> replaceComposeDraftRows({
    required String workspaceKey,
    required List<Map<String, Object?>> rows,
  }) async {
    final sqlite = await _db.db;
    await sqlite.transaction(
      (txn) => ComposeDraftDbPersistence.replaceRowsInExecutor(
        txn,
        workspaceKey: workspaceKey,
        rows: rows,
      ),
    );
    _db.notifyDataChanged();
  }

  Future<void> deleteComposeDraft(String uid) async {
    final sqlite = await _db.db;
    await ComposeDraftDbPersistence.deleteRow(sqlite, uid);
    _db.notifyDataChanged();
  }

  Future<void> deleteComposeDraftsByWorkspace(String workspaceKey) async {
    final sqlite = await _db.db;
    await ComposeDraftDbPersistence.deleteRowsByWorkspace(sqlite, workspaceKey);
    _db.notifyDataChanged();
  }

  Future<void> upsertCollectionReaderProgressRow(
    Map<String, Object?> row,
  ) async {
    final sqlite = await _db.db;
    await CollectionDbPersistence.upsertReaderProgressRow(sqlite, row);
  }

  Future<void> deleteCollectionReaderProgress(String collectionId) async {
    final sqlite = await _db.db;
    await CollectionDbPersistence.deleteReaderProgress(sqlite, collectionId);
  }

  Future<void> upsertCollectionArticleFlowProgressRow(
    Map<String, Object?> row,
  ) async {
    final sqlite = await _db.db;
    await CollectionDbPersistence.upsertArticleFlowProgressRow(sqlite, row);
  }

  Future<void> deleteCollectionArticleFlowProgress(String collectionId) async {
    final sqlite = await _db.db;
    await CollectionDbPersistence.deleteArticleFlowProgress(
      sqlite,
      collectionId,
    );
  }

  Future<int> insertRecycleBinItem({
    required String itemType,
    required String memoUid,
    required String summary,
    required String payloadJson,
    required int deletedTime,
    required int expireTime,
  }) async {
    final sqlite = await _db.db;
    final id = await MemoLifecycleDbPersistence.insertRecycleBinItem(
      sqlite,
      itemType: itemType,
      memoUid: memoUid,
      summary: summary,
      payloadJson: payloadJson,
      deletedTime: deletedTime,
      expireTime: expireTime,
    );
    _db.notifyDataChanged();
    return id;
  }

  Future<void> deleteRecycleBinItemById(int id) async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.deleteRecycleBinItemById(sqlite, id);
    _db.notifyDataChanged();
  }

  Future<void> clearRecycleBinItems() async {
    final sqlite = await _db.db;
    await MemoLifecycleDbPersistence.clearRecycleBinItems(sqlite);
    _db.notifyDataChanged();
  }

  Future<int> upsertImportHistory({
    required String source,
    required String fileMd5,
    required String fileName,
    required int status,
    required int memoCount,
    required int attachmentCount,
    required int failedCount,
    String? error,
  }) async {
    final sqlite = await _db.db;
    final id = await MemoAuxiliaryDbPersistence.upsertImportHistory(
      sqlite,
      source: source,
      fileMd5: fileMd5,
      fileName: fileName,
      status: status,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      failedCount: failedCount,
      error: error,
    );
    _db.notifyDataChanged();
    return id;
  }

  Future<void> updateImportHistory({
    required int id,
    required int status,
    required int memoCount,
    required int attachmentCount,
    required int failedCount,
    String? error,
  }) async {
    final sqlite = await _db.db;
    await MemoAuxiliaryDbPersistence.updateImportHistory(
      sqlite,
      id: id,
      status: status,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      failedCount: failedCount,
      error: error,
    );
    _db.notifyDataChanged();
  }

  Future<int> enqueueOutbox({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final sqlite = await _db.db;
    final id = await OutboxDbPersistence.insertItem(
      sqlite,
      type: type,
      payload: payload,
      createdTimeMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _db.notifyDataChanged();
    return id;
  }

  Future<int> enqueueOutboxBatch({
    required List<Map<String, Object?>> items,
  }) async {
    if (items.isEmpty) return 0;
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await OutboxDbPersistence.enqueueBatch(
        txn,
        items: items,
        createdTimeMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    });
    _db.notifyDataChanged();
    return items.length;
  }

  Future<Map<String, dynamic>?> claimNextOutboxRunnable({int? nowMs}) async {
    final sqlite = await _db.db;
    final now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final claimed = await sqlite.transaction<Map<String, dynamic>?>((
      txn,
    ) async {
      return OutboxDbPersistence.claimNextRunnable(txn, nowMs: now);
    });
    if (claimed != null) {
      _db.notifyDataChanged();
    }
    return claimed;
  }

  Future<Map<String, dynamic>?> claimOutboxTaskById(
    int id, {
    int? nowMs,
  }) async {
    final sqlite = await _db.db;
    final now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final claimed = await sqlite.transaction<Map<String, dynamic>?>((
      txn,
    ) async {
      return OutboxDbPersistence.claimTaskById(txn, id, nowMs: now);
    });
    if (claimed != null) {
      _db.notifyDataChanged();
    }
    return claimed;
  }

  Future<int> recoverOutboxRunningTasks() async {
    final sqlite = await _db.db;
    final updated = await OutboxDbPersistence.recoverRunningTasks(sqlite);
    if (updated > 0) {
      _db.notifyDataChanged();
    }
    return updated;
  }

  Future<void> markOutboxDone(int id) async {
    final sqlite = await _db.db;
    await OutboxDbPersistence.markDone(sqlite, id);
    _db.notifyDataChanged();
  }

  Future<void> completeOutboxTask(int id) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await OutboxDbPersistence.completeTask(txn, id);
    });
    _db.notifyDataChanged();
  }

  Future<void> markOutboxError(int id, {required String error}) async {
    final sqlite = await _db.db;
    await OutboxDbPersistence.markError(sqlite, id, error: error);
    _db.notifyDataChanged();
  }

  Future<void> markOutboxRetryScheduled(
    int id, {
    required String error,
    required int retryAtMs,
  }) async {
    final sqlite = await _db.db;
    await OutboxDbPersistence.markRetryScheduled(
      sqlite,
      id,
      error: error,
      retryAtMs: retryAtMs,
    );
    _db.notifyDataChanged();
  }

  Future<void> markOutboxQuarantined(
    int id, {
    required String error,
    required String failureCode,
    required String failureKind,
    bool incrementAttempts = true,
  }) async {
    final sqlite = await _db.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await OutboxDbPersistence.markQuarantined(
      sqlite,
      id,
      error: error,
      failureCode: failureCode,
      failureKind: failureKind,
      quarantinedAtMs: now,
      incrementAttempts: incrementAttempts,
    );
    _db.notifyDataChanged();
  }

  Future<void> markOutboxRetryPending(int id, {required String error}) async {
    await markOutboxRetryScheduled(
      id,
      error: error,
      retryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  Future<int> retryOutboxErrors({String? memoUid}) async {
    final sqlite = await _db.db;
    final retried = await OutboxDbPersistence.retryErrors(
      sqlite,
      memoUid: memoUid,
    );
    if (retried > 0) {
      _db.notifyDataChanged();
    }
    return retried;
  }

  Future<void> retryOutboxItem(int id) async {
    final sqlite = await _db.db;
    await OutboxDbPersistence.retryItem(sqlite, id);
    _db.notifyDataChanged();
  }

  Future<void> deleteOutbox(int id) async {
    final sqlite = await _db.db;
    await OutboxDbPersistence.deleteById(sqlite, id);
    _db.notifyDataChanged();
  }

  Future<int> deleteOutboxItems(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final sqlite = await _db.db;
    final deleted = await OutboxDbPersistence.deleteItems(sqlite, ids);
    if (deleted > 0) {
      _db.notifyDataChanged();
    }
    return deleted;
  }

  Future<void> deleteOutboxForMemo(String memoUid) async {
    final sqlite = await _db.db;
    final deleted = await OutboxDbPersistence.deleteForMemo(sqlite, memoUid);
    if (deleted > 0) {
      _db.notifyDataChanged();
    }
  }

  Future<void> clearOutbox() async {
    final sqlite = await _db.db;
    await OutboxDbPersistence.clear(sqlite);
    _db.notifyDataChanged();
  }

  Future<TagEntity> createTag({
    required String name,
    int? parentId,
    bool pinned = false,
    String? colorHex,
  }) async {
    final normalizedName = _normalizeTagName(name);
    final normalizedColor = normalizeTagColorHex(colorHex);
    final sqlite = await _db.db;
    late TagEntity created;
    await sqlite.transaction((txn) async {
      if (parentId != null) {
        final parent = await TagDbPersistence.loadTag(txn, parentId);
        if (parent == null) {
          throw StateError('Parent tag not found');
        }
      }
      await TagDbPersistence.ensureUniqueName(
        txn,
        name: normalizedName,
        parentId: parentId,
        excludeId: null,
      );
      final parentPath = parentId == null
          ? null
          : (await TagDbPersistence.loadTag(txn, parentId))?.path;
      if (parentId != null && (parentPath == null || parentPath.isEmpty)) {
        throw StateError('Parent tag not found');
      }
      final path = parentPath == null || parentPath.isEmpty
          ? normalizedName
          : '$parentPath/$normalizedName';
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final id = await TagDbPersistence.insertTagRow(
        txn,
        name: normalizedName,
        parentId: parentId,
        path: path,
        pinned: pinned,
        colorHex: normalizedColor,
        createTimeSec: now,
        updateTimeSec: now,
      );
      created = TagEntity(
        id: id,
        name: normalizedName,
        path: path,
        parentId: parentId,
        pinned: pinned,
        colorHex: normalizedColor,
        createTimeSec: now,
        updateTimeSec: now,
      );
    });
    _db.notifyDataChanged();
    return created;
  }

  Future<TagEntity> updateTag({
    required int id,
    String? name,
    Object? parentId = noParentChange,
    bool? pinned,
    String? colorHex,
  }) async {
    final sqlite = await _db.db;
    late TagEntity updated;
    await sqlite.transaction((txn) async {
      final current = await TagDbPersistence.loadTag(txn, id);
      if (current == null) {
        throw StateError('Tag not found');
      }
      final nextName = name == null ? current.name : _normalizeTagName(name);
      final nextParentId = identical(parentId, noParentChange)
          ? current.parentId
          : parentId as int?;
      final nextPinned = pinned ?? current.pinned;
      final nextColor = colorHex == null
          ? current.colorHex
          : normalizeTagColorHex(colorHex);

      await TagDbPersistence.assertNoCycle(txn, id, nextParentId);
      await TagDbPersistence.ensureUniqueName(
        txn,
        name: nextName,
        parentId: nextParentId,
        excludeId: id,
      );

      final parentPath = nextParentId == null
          ? null
          : (await TagDbPersistence.loadTag(txn, nextParentId))?.path;
      if (nextParentId != null && (parentPath == null || parentPath.isEmpty)) {
        throw StateError('Parent tag not found');
      }
      final newPath = parentPath == null || parentPath.isEmpty
          ? nextName
          : '$parentPath/$nextName';
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      if (newPath == current.path) {
        await TagDbPersistence.updateTagValues(txn, id, {
          'name': nextName,
          'parent_id': nextParentId,
          'pinned': nextPinned ? 1 : 0,
          'color_hex': nextColor,
          'update_time': now,
        });
      } else {
        final descendants = await TagDbPersistence.listSubtreeRows(
          txn,
          current.path,
        );
        final subtreeIds = <int>{};
        final newPaths = <int, String>{};
        for (final row in descendants) {
          final tagId = _readInt(row['id']) ?? 0;
          final oldPath = row['path'] as String? ?? '';
          if (tagId <= 0 || oldPath.isEmpty) continue;
          subtreeIds.add(tagId);
          final suffix = oldPath == current.path
              ? ''
              : oldPath.substring(current.path.length);
          final updatedPath = '$newPath$suffix';
          newPaths[tagId] = updatedPath;
        }

        for (final entry in newPaths.entries) {
          final existingId = await TagDbPersistence.findTagIdByPath(
            txn,
            entry.value,
          );
          if (existingId > 0 && !subtreeIds.contains(existingId)) {
            throw StateError('Tag path already exists');
          }
        }

        for (final row in descendants) {
          final tagId = _readInt(row['id']) ?? 0;
          final oldPath = row['path'] as String? ?? '';
          if (tagId <= 0 || oldPath.isEmpty) continue;
          await TagDbPersistence.insertAliasRow(
            txn,
            tagId: tagId,
            alias: oldPath,
            createdTimeSec: now,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        final newPathForTag = newPaths[id] ?? newPath;
        await TagDbPersistence.updateTagValues(txn, id, {
          'name': nextName,
          'parent_id': nextParentId,
          'path': newPathForTag,
          'pinned': nextPinned ? 1 : 0,
          'color_hex': nextColor,
          'update_time': now,
        });

        for (final entry in newPaths.entries) {
          final tagId = entry.key;
          if (tagId == id) continue;
          await TagDbPersistence.updateTagValues(txn, tagId, {
            'path': entry.value,
            'update_time': now,
          });
        }

        final memoUids = await TagDbPersistence.listMemoUidsByTagIds(
          txn,
          subtreeIds.toList(growable: false),
        );
        for (final memoUid in memoUids) {
          final paths = await TagDbPersistence.listTagPathsForMemo(
            txn,
            memoUid,
          );
          await _db.updateMemoTagsText(txn, memoUid, paths);
        }
      }

      updated = (await TagDbPersistence.loadTag(txn, id)) ?? current;
    });
    _db.notifyDataChanged();
    return updated;
  }

  Future<void> deleteTag(int id) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      final current = await TagDbPersistence.loadTag(txn, id);
      if (current == null) return;
      final parentId = current.parentId;
      final parentPath = parentId == null
          ? ''
          : (await TagDbPersistence.loadTag(txn, parentId))?.path ?? '';

      final descendants = await TagDbPersistence.listDescendantRows(
        txn,
        current.path,
      );

      final affectedIds = <int>{id};
      final newPaths = <int, String>{};
      for (final row in descendants) {
        final tagId = _readInt(row['id']) ?? 0;
        final oldPath = row['path'] as String? ?? '';
        if (tagId <= 0 || oldPath.isEmpty) continue;
        affectedIds.add(tagId);
        final suffix = oldPath.substring(current.path.length + 1);
        final updatedPath = parentPath.isEmpty ? suffix : '$parentPath/$suffix';
        newPaths[tagId] = updatedPath;
      }

      for (final entry in newPaths.entries) {
        final existingId = await TagDbPersistence.findTagIdByPath(
          txn,
          entry.value,
        );
        if (existingId > 0 && !affectedIds.contains(existingId)) {
          throw StateError('Tag path already exists');
        }
      }

      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      for (final row in descendants) {
        final tagId = _readInt(row['id']) ?? 0;
        final oldPath = row['path'] as String? ?? '';
        if (tagId <= 0 || oldPath.isEmpty) continue;
        await TagDbPersistence.insertAliasRow(
          txn,
          tagId: tagId,
          alias: oldPath,
          createdTimeSec: now,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      final directChildren = <int>{};
      for (final row in descendants) {
        final tagId = _readInt(row['id']) ?? 0;
        final parent = _readInt(row['parent_id']) ?? 0;
        if (tagId > 0 && parent == id) {
          directChildren.add(tagId);
        }
      }
      for (final entry in newPaths.entries) {
        final tagId = entry.key;
        final isDirectChild = directChildren.contains(tagId);
        await TagDbPersistence.updateTagValues(txn, tagId, {
          'path': entry.value,
          'update_time': now,
          if (isDirectChild) 'parent_id': parentId,
        });
      }

      final memoUids = await TagDbPersistence.listMemoUidsByTagIds(
        txn,
        affectedIds.toList(growable: false),
      );

      await TagDbPersistence.deleteTagById(txn, id);

      for (final memoUid in memoUids) {
        final paths = await TagDbPersistence.listTagPathsForMemo(txn, memoUid);
        await _db.updateMemoTagsText(txn, memoUid, paths);
      }
    });
    _db.notifyDataChanged();
  }

  Future<void> applyTagSnapshot(TagSnapshot snapshot) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      final existingSnapshot = await TagDbPersistence.readSnapshot(txn);
      final existingTags = existingSnapshot.tags;
      final existingAliases = existingSnapshot.aliases;
      final existingTagsByPath = <String, TagEntity>{
        for (final tag in existingTags)
          if (tag.path.trim().isNotEmpty) tag.path: tag,
      };
      final existingTagsById = <int, TagEntity>{
        for (final tag in existingTags)
          if (tag.id > 0) tag.id: tag,
      };
      final existingAliasesByPath = <String, List<TagAliasRecord>>{};
      for (final alias in existingAliases) {
        final tag = existingTagsById[alias.tagId];
        if (tag == null || tag.path.trim().isEmpty) continue;
        existingAliasesByPath
            .putIfAbsent(tag.path, () => <TagAliasRecord>[])
            .add(alias);
      }

      await TagDbPersistence.deleteAllRowsForSnapshot(txn);

      for (final tag in snapshot.tags) {
        await TagDbPersistence.insertTagEntity(
          txn,
          tag,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final alias in snapshot.aliases) {
        await TagDbPersistence.insertAliasRecord(
          txn,
          alias,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      final memos = await MemoQueryDbPersistence.listMemoUidTagRows(txn);
      for (final row in memos) {
        final uid = row['uid'];
        if (uid is! String || uid.trim().isEmpty) continue;
        final tagsText = (row['tags'] as String?) ?? '';
        final tags = tagsText
            .split(' ')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(growable: false);
        final resolved = <String, int>{};
        for (final tag in tags) {
          var entry = await TagDbPersistence.findResolvedTag(txn, tag);
          entry ??= await TagDbPersistence.restoreTagFromExisting(
            txn,
            tag,
            existingTagsByPath: existingTagsByPath,
            existingTagsById: existingTagsById,
            existingAliasesByPath: existingAliasesByPath,
          );
          entry ??= await TagDbPersistence.resolvePath(txn, tag);
          if (entry == null) continue;
          final resolvedEntry = entry;
          resolved.putIfAbsent(resolvedEntry.path, () => resolvedEntry.id);
        }
        await TagDbPersistence.updateMemoTagsMapping(
          txn,
          uid,
          resolved.values.toList(growable: false),
        );
        await _db.updateMemoTagsText(
          txn,
          uid,
          resolved.keys.toList(growable: false),
        );
      }
    });
    _db.notifyDataChanged();
  }

  String _normalizeTagName(String raw) {
    final normalized = normalizeTagPath(raw);
    if (normalized.isEmpty) {
      throw StateError('Tag name is empty');
    }
    if (normalized.contains('/')) {
      throw StateError('Tag name cannot contain "/"');
    }
    return normalized;
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<void> _renameMemoUid(
    DatabaseExecutor executor, {
    required String oldUid,
    required String newUid,
  }) async {
    await MemoWriteDbPersistence.renameMemoUidRow(
      executor,
      oldUid: oldUid,
      newUid: newUid,
    );
    await MemoAuxiliaryDbPersistence.renameMemoReminderUid(
      executor,
      oldUid: oldUid,
      newUid: newUid,
    );
    await MemoCoreDbPersistence.renameAttachmentMemoUid(
      executor,
      oldUid: oldUid,
      newUid: newUid,
    );
    await MemoLifecycleDbPersistence.renameMemoUid(
      executor,
      oldUid: oldUid,
      newUid: newUid,
    );
  }

  Future<int> updatePendingCreateMemoContent({
    required String memoUid,
    required String content,
    String? visibility,
  }) async {
    final sqlite = await _db.db;
    final updatedCount =
        await OutboxDbPersistence.updatePendingCreateMemoContent(
          sqlite,
          memoUid: memoUid,
          content: content,
          visibility: visibility,
        );
    if (updatedCount > 0) {
      _db.notifyDataChanged();
    }
    return updatedCount;
  }

  Future<void> _removePendingAttachmentPlaceholder(
    DatabaseExecutor executor, {
    required String memoUid,
    required String attachmentUid,
  }) async {
    await MemoWriteDbPersistence.removePendingAttachmentPlaceholder(
      executor,
      memoUid: memoUid,
      attachmentUid: attachmentUid,
    );
  }

  Future<void> _upsertMemo(
    DatabaseExecutor executor, {
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    required Object? displayTimeSec,
    required bool preserveDisplayTime,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
  }) async {
    final locationPlaceholder = location?.placeholder;
    final locationLat = location?.latitude;
    final locationLng = location?.longitude;
    final normalizedDisplayTimeSec = _db.normalizeDisplayTimeSec(
      preserveDisplayTime ? null : displayTimeSec,
    );

    final reconciled = await MemoTagReconciler.reconcile(executor, tags);
    final canonicalTags = reconciled.canonicalPaths;
    final tagsText = reconciled.tagsText;

    final before = await _db.loadMemoSnapshotPayload(executor, uid);
    final rowId = await MemoWriteDbPersistence.upsertMemoRow(
      executor,
      MemoWriteRowDraft(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        createTimeSec: createTimeSec,
        displayTimeSec: normalizedDisplayTimeSec,
        preserveDisplayTime: preserveDisplayTime,
        updateTimeSec: updateTimeSec,
        tagsText: tagsText,
        attachments: attachments,
        locationPlaceholder: locationPlaceholder,
        locationLat: locationLat,
        locationLng: locationLng,
        relationCount: relationCount,
        syncState: syncState,
        lastError: lastError,
      ),
    );
    if (rowId <= 0) return;

    await MemoSearchDbPersistence.refreshFtsEntryForMemo(
      executor,
      rowId: rowId,
      memoUid: uid,
      content: content,
      tags: tagsText,
    );
    await MemoSearchDbPersistence.markDirty(
      executor,
      rowId: rowId,
      memoUid: uid,
    );

    await TagDbPersistence.updateMemoTagsMapping(
      executor,
      uid,
      reconciled.tagIds,
    );

    final after = _db.createMemoSnapshotPayload(
      state: state,
      createTimeSec: createTimeSec,
      content: content,
      tags: canonicalTags,
    );
    await _db.applyMemoCacheDeltaPayload(
      executor,
      before: before,
      after: after,
    );
  }

  Future<void> _deleteMemoByUid(DatabaseExecutor executor, String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    final before = await _db.loadMemoSnapshotPayload(executor, normalizedUid);
    final rowId = await MemoWriteDbPersistence.deleteMemoRowByUid(
      executor,
      normalizedUid,
    );
    await MemoLifecycleDbPersistence.deleteMemoLifecycleRowsForMemo(
      executor,
      normalizedUid,
    );
    if (rowId != null && rowId > 0) {
      await MemoSearchDbPersistence.deleteFtsEntry(executor, rowId: rowId);
      await MemoSearchDbPersistence.deleteIndexEntry(
        executor,
        rowId: rowId,
        memoUid: normalizedUid,
      );
    }
    await _db.applyMemoCacheDeltaPayload(executor, before: before, after: null);
  }

  Future<void> _upsertMemoClipCard(
    DatabaseExecutor executor,
    MemoClipCardMetadata metadata,
  ) async {
    final memoUid = metadata.memoUid.trim();
    if (memoUid.isEmpty) return;

    await MemoAuxiliaryDbPersistence.upsertMemoClipCard(executor, metadata);

    final memoRow = await MemoWriteDbPersistence.getMemoSearchRefreshRow(
      executor,
      memoUid,
    );
    if (memoRow == null) return;
    await MemoSearchDbPersistence.refreshFtsEntryForMemo(
      executor,
      rowId: memoRow.rowId,
      memoUid: memoUid,
      content: memoRow.content,
      tags: memoRow.tags,
    );
    await MemoSearchDbPersistence.markDirty(
      executor,
      rowId: memoRow.rowId,
      memoUid: memoUid,
    );
  }

  Future<void> _deleteMemoClipCard(
    DatabaseExecutor executor,
    String memoUid,
  ) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;

    await MemoAuxiliaryDbPersistence.deleteMemoClipCard(
      executor,
      normalizedUid,
    );

    final memoRow = await MemoWriteDbPersistence.getMemoSearchRefreshRow(
      executor,
      normalizedUid,
    );
    if (memoRow == null) return;
    await MemoSearchDbPersistence.refreshFtsEntryForMemo(
      executor,
      rowId: memoRow.rowId,
      memoUid: normalizedUid,
      content: memoRow.content,
      tags: memoRow.tags,
    );
    await MemoSearchDbPersistence.markDirty(
      executor,
      rowId: memoRow.rowId,
      memoUid: normalizedUid,
    );
  }

  Future<void> upsertMemoClipCard(MemoClipCardMetadata metadata) async {
    final trimmedMemoUid = metadata.memoUid.trim();
    if (trimmedMemoUid.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await _upsertMemoClipCard(txn, metadata);
    });
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoClipCard(String memoUid) async {
    final trimmedMemoUid = memoUid.trim();
    if (trimmedMemoUid.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await _deleteMemoClipCard(txn, trimmedMemoUid);
    });
    _db.notifyDataChanged();
  }

  Future<void> upsertQuickClipRecoveryJob(QuickClipRecoveryJob job) async {
    final sqlite = await _db.db;
    await QuickClipRecoveryDbPersistence.upsertJob(sqlite, job);
    _db.notifyDataChanged();
  }

  Future<int> markQuickClipRecoveryJobRunning({
    required String memoUid,
    required DateTime now,
    String? lastError,
  }) async {
    final sqlite = await _db.db;
    final updated = await QuickClipRecoveryDbPersistence.markRunning(
      sqlite,
      memoUid: memoUid,
      now: now,
      lastError: lastError,
    );
    if (updated > 0) {
      _db.notifyDataChanged();
    }
    return updated;
  }

  Future<int> markQuickClipRecoveryJobCompleted({
    required String memoUid,
    required DateTime now,
  }) async {
    final sqlite = await _db.db;
    final updated = await QuickClipRecoveryDbPersistence.markCompleted(
      sqlite,
      memoUid: memoUid,
      now: now,
    );
    if (updated > 0) {
      _db.notifyDataChanged();
    }
    return updated;
  }

  Future<int> markQuickClipRecoveryJobAbandoned({
    required String memoUid,
    required DateTime now,
    String? lastError,
  }) async {
    final sqlite = await _db.db;
    final updated = await QuickClipRecoveryDbPersistence.markAbandoned(
      sqlite,
      memoUid: memoUid,
      now: now,
      lastError: lastError,
    );
    if (updated > 0) {
      _db.notifyDataChanged();
    }
    return updated;
  }

  Future<int> markQuickClipRecoveryJobFailed({
    required String memoUid,
    required DateTime now,
    String? lastError,
  }) async {
    final sqlite = await _db.db;
    final updated = await QuickClipRecoveryDbPersistence.markFailed(
      sqlite,
      memoUid: memoUid,
      now: now,
      lastError: lastError,
    );
    if (updated > 0) {
      _db.notifyDataChanged();
    }
    return updated;
  }

  Future<int> deleteTerminalQuickClipRecoveryJobs({
    required DateTime completedBefore,
    int limit = 100,
  }) async {
    final sqlite = await _db.db;
    final deleted =
        await QuickClipRecoveryDbPersistence.deleteTerminalJobsOlderThan(
          sqlite,
          completedBefore: completedBefore,
          limit: limit,
        );
    if (deleted > 0) {
      _db.notifyDataChanged();
    }
    return deleted;
  }
}
