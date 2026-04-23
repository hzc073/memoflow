import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../core/tag_colors.dart';
import '../../core/tags.dart';
import '../ai/ai_analysis_models.dart';
import '../ai/ai_settings_models.dart';
import '../models/memo_clip_card_metadata.dart';
import '../models/memo_location.dart';
import '../models/tag.dart';
import '../models/tag_snapshot.dart';
import 'app_database.dart';

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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await sqlite.insert('ai_memo_policy', <String, Object?>{
      'memo_uid': trimmedUid,
      'allow_ai': allowAi ? 1 : 0,
      'updated_time': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await sqlite.insert('ai_index_jobs', <String, Object?>{
      'memo_uid': memoUid?.trim(),
      'reason': aiIndexJobReasonToStorage(reason),
      'memo_content_hash': memoContentHash,
      'embedding_profile_key': embeddingProfileKey,
      'status': aiIndexJobStatusToStorage(AiIndexJobStatus.queued),
      'attempt_count': 0,
      'priority': priority,
      'created_time': now,
    });
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final values = <String, Object?>{
      'status': aiIndexJobStatusToStorage(status),
      'error_text': errorText,
    };
    if (attemptCount != null) {
      values['attempt_count'] = attemptCount;
    }
    if (markStarted) {
      values['started_time'] = now;
    }
    if (markFinished) {
      values['finished_time'] = now;
    }
    await sqlite.update(
      'ai_index_jobs',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[jobId],
    );
    _db.notifyDataChanged();
  }

  Future<void> invalidateAiActiveChunksForMemo(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    final sqlite = await _db.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await sqlite.transaction((txn) async {
      final rows = await txn.query(
        'ai_chunks',
        columns: const ['id'],
        where: 'memo_uid = ? AND is_active = 1',
        whereArgs: <Object?>[trimmedUid],
      );
      final chunkIds = rows
          .map((row) => _readInt(row['id']))
          .whereType<int>()
          .toList(growable: false);
      await txn.update(
        'ai_chunks',
        <String, Object?>{
          'is_active': 0,
          'invalidated_time': now,
          'updated_time': now,
        },
        where: 'memo_uid = ? AND is_active = 1',
        whereArgs: <Object?>[trimmedUid],
      );
      if (chunkIds.isNotEmpty) {
        final placeholders = List.filled(chunkIds.length, '?').join(', ');
        await txn.rawUpdate(
          'UPDATE ai_embeddings SET status = ?, updated_time = ? WHERE chunk_id IN ($placeholders) AND status != ?',
          <Object?>[
            aiEmbeddingStatusToStorage(AiEmbeddingStatus.stale),
            now,
            ...chunkIds,
            aiEmbeddingStatusToStorage(AiEmbeddingStatus.stale),
          ],
        );
      }
      await txn.rawUpdate(
        '''
UPDATE ai_analysis_results
SET is_stale = 1,
    updated_time = ?
WHERE id IN (
  SELECT DISTINCT result_id
  FROM ai_analysis_evidences
  WHERE memo_uid = ?
);
''',
        <Object?>[now, trimmedUid],
      );
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final ids = <int>[];
    await sqlite.transaction((txn) async {
      for (final chunk in chunks) {
        final id = await txn.insert('ai_chunks', <String, Object?>{
          'memo_uid': trimmedUid,
          'chunk_index': chunk.chunkIndex,
          'content': chunk.content,
          'content_hash': chunk.contentHash,
          'memo_content_hash': chunk.memoContentHash,
          'char_start': chunk.charStart,
          'char_end': chunk.charEnd,
          'token_estimate': chunk.tokenEstimate,
          'memo_create_time': chunk.memoCreateTime,
          'memo_update_time': chunk.memoUpdateTime,
          'memo_visibility': chunk.memoVisibility,
          'is_active': 1,
          'created_time': now,
          'updated_time': now,
        });
        ids.add(id);
      }
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    Uint8List? vectorBlob;
    var dimensions = 0;
    if (vector != null && vector.isNotEmpty) {
      vectorBlob = vector.buffer.asUint8List(
        vector.offsetInBytes,
        vector.lengthInBytes,
      );
      dimensions = vector.length;
    }
    await sqlite.insert('ai_embeddings', <String, Object?>{
      'chunk_id': chunkId,
      'backend_kind': _backendKindToStorage(profile.backendKind),
      'provider_kind': _providerKindToStorage(profile.providerKind),
      'base_url': profile.baseUrl,
      'model': profile.model,
      'model_version': '',
      'dimensions': dimensions,
      'vector_blob': vectorBlob,
      'status': aiEmbeddingStatusToStorage(status),
      'error_text': errorText,
      'created_time': now,
      'updated_time': now,
    });
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await sqlite.insert('ai_analysis_tasks', <String, Object?>{
      'task_uid': taskUid,
      'analysis_type': aiAnalysisTypeToStorage(analysisType),
      'status': aiTaskStatusToStorage(status),
      'range_start': rangeStart,
      'range_end_exclusive': rangeEndExclusive,
      'include_public': includePublic ? 1 : 0,
      'include_private': includePrivate ? 1 : 0,
      'include_protected': includeProtected ? 1 : 0,
      'prompt_template': promptTemplate,
      'template_kind': aiAnalysisTemplateKindToStorage(templateKind),
      'template_id': templateId.trim(),
      'template_title_snapshot': templateTitleSnapshot.trim(),
      'template_icon_key_snapshot': templateIconKeySnapshot.trim(),
      'generation_profile_key': generationProfileKey,
      'embedding_profile_key': embeddingProfileKey,
      'retrieval_profile_json': jsonEncode(retrievalProfile),
      'mailbox_delivery_state': 'hidden',
      'mailbox_open_state': 'unread',
      'reply_animation_state': 'idle',
      'created_time': now,
      'updated_time': now,
    });
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await sqlite.update(
      'ai_analysis_tasks',
      <String, Object?>{
        'status': aiTaskStatusToStorage(status),
        'error_text': errorText,
        'updated_time': now,
        if (markCompleted) 'completed_time': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[taskId],
    );
    _db.notifyDataChanged();
  }

  Future<void> saveAiAnalysisResult({
    required int taskId,
    required AiStructuredAnalysisResult result,
  }) async {
    final sqlite = await _db.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await sqlite.transaction((txn) async {
      final resultId = await txn.insert(
        'ai_analysis_results',
        <String, Object?>{
          'task_id': taskId,
          'schema_version': result.schemaVersion,
          'analysis_type': aiAnalysisTypeToStorage(result.analysisType),
          'summary': result.summary,
          'follow_up_suggestions_json': jsonEncode(result.followUpSuggestions),
          'raw_response_text': result.rawResponseText,
          'normalized_result_json': result.normalizedResultJson,
          'is_stale': 0,
          'created_time': now,
          'updated_time': now,
        },
      );
      final sectionIdByKey = <String, int>{};
      for (var index = 0; index < result.sections.length; index++) {
        final section = result.sections[index];
        final sectionId = await txn
            .insert('ai_analysis_sections', <String, Object?>{
              'result_id': resultId,
              'section_key': section.sectionKey,
              'section_order': index,
              'title': section.title,
              'body': section.body,
              'created_time': now,
            });
        sectionIdByKey[section.sectionKey] = sectionId;
      }
      for (var index = 0; index < result.evidences.length; index++) {
        final evidence = result.evidences[index];
        final sectionId = sectionIdByKey[evidence.sectionKey];
        if (sectionId == null) continue;
        await txn.insert('ai_analysis_evidences', <String, Object?>{
          'result_id': resultId,
          'section_id': sectionId,
          'evidence_order': index,
          'memo_uid': evidence.memoUid,
          'chunk_id': evidence.chunkId,
          'quote_text': evidence.quoteText,
          'char_start': evidence.charStart,
          'char_end': evidence.charEnd,
          'relevance_score': evidence.relevanceScore,
          'created_time': now,
        });
      }
    });
    _db.notifyDataChanged();
  }

  Future<void> markAiResultsStaleForMemo(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    final sqlite = await _db.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await sqlite.rawUpdate(
      '''
UPDATE ai_analysis_results
SET is_stale = 1,
    updated_time = ?
WHERE id IN (
  SELECT DISTINCT result_id
  FROM ai_analysis_evidences
  WHERE memo_uid = ?
);
''',
      <Object?>[now, trimmedUid],
    );
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
    await sqlite.update(
      'memos',
      {'sync_state': syncState, 'last_error': lastError},
      where: 'uid = ?',
      whereArgs: [uid],
    );
    _db.notifyDataChanged();
  }

  Future<void> updateMemoAttachmentsJson(
    String uid, {
    required String attachmentsJson,
  }) async {
    final sqlite = await _db.db;
    await sqlite.update(
      'memos',
      {'attachments_json': attachmentsJson},
      where: 'uid = ?',
      whereArgs: [uid],
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

    final row = await _db.getMemoByUid(trimmedMemoUid);
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
    await updateMemoAttachmentsJson(
      trimmedMemoUid,
      attachmentsJson: jsonEncode(next),
    );
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
      await txn.delete('outbox', where: 'id = ?', whereArgs: [outboxId]);

      if (trimmedMemoUid.isNotEmpty && trimmedAttachmentUid.isNotEmpty) {
        await _removePendingAttachmentPlaceholder(
          txn,
          memoUid: trimmedMemoUid,
          attachmentUid: trimmedAttachmentUid,
        );
      }

      if (trimmedMemoUid.isEmpty) return;

      final hasMorePending = await _hasPendingOutboxTaskForMemo(
        txn,
        trimmedMemoUid,
      );
      await txn.update(
        'memos',
        <String, Object?>{
          'sync_state': hasMorePending ? 1 : 0,
          'last_error': null,
        },
        where: 'uid = ?',
        whereArgs: [trimmedMemoUid],
      );
    });

    _db.notifyDataChanged();
  }

  Future<void> upsertMemoRelationsCache(
    String memoUid, {
    required String relationsJson,
  }) async {
    final sqlite = await _db.db;
    await _upsertMemoRelationsCache(
      sqlite,
      memoUid,
      relationsJson: relationsJson,
    );
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoRelationsCache(String memoUid) async {
    final sqlite = await _db.db;
    await _deleteMemoRelationsCache(sqlite, memoUid);
    _db.notifyDataChanged();
  }

  Future<int> insertMemoVersion({
    required String memoUid,
    required int snapshotTime,
    required String summary,
    required String payloadJson,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) {
      throw const FormatException('memo_uid is required');
    }
    final sqlite = await _db.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await sqlite.insert('memo_versions', {
      'memo_uid': normalizedUid,
      'snapshot_time': snapshotTime,
      'summary': summary,
      'payload_json': payloadJson,
      'created_time': now,
    });
    _db.notifyDataChanged();
    return id;
  }

  Future<void> deleteMemoVersionById(int id) async {
    final sqlite = await _db.db;
    await sqlite.delete('memo_versions', where: 'id = ?', whereArgs: [id]);
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoVersionsByMemoUid(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.delete(
      'memo_versions',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
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
    await _upsertMemoDeleteTombstone(
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
    final normalizedUid = memoUid.trim();
    final normalizedLocalUrl = localUrl.trim();
    final normalizedSourceUrl = sourceUrl.trim();
    if (normalizedUid.isEmpty ||
        normalizedLocalUrl.isEmpty ||
        normalizedSourceUrl.isEmpty) {
      return;
    }
    final sqlite = await _db.db;
    await sqlite.insert('memo_inline_image_sources', {
      'memo_uid': normalizedUid,
      'local_url': normalizedLocalUrl,
      'source_url': normalizedSourceUrl,
      'updated_time': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoInlineImageSources(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.delete(
      'memo_inline_image_sources',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoDeleteTombstone(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.delete(
      'memo_delete_tombstones',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
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
    final changedCount = await _rewriteOutboxMemoUids(
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
      changedCount = await _rewriteOutboxMemoUids(
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
        await _deleteOutboxForMemo(txn, uid);
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
          await _deleteMemoRelationsCache(txn, uid);
          break;
        case 'set':
          final normalizedRelationsJson = (relationsJson ?? '').trim();
          if (normalizedRelationsJson.isNotEmpty) {
            await _upsertMemoRelationsCache(
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
      await _deleteOutboxForMemo(txn, normalizedMemoUid);
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
      await _upsertMemoDeleteTombstone(
        txn,
        memoUid: normalizedMemoUid,
        state: AppDatabase.memoDeleteTombstoneStatePendingRemoteDelete,
      );
      await _deleteOutboxForMemo(txn, normalizedMemoUid);

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
        await _enqueueOutboxBatch(
          txn,
          items: attachmentItems,
          createdTimeMs: now,
        );
      }

      await _deleteMemoByUid(txn, normalizedMemoUid);
      await _insertOutboxItem(
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final updated = await sqlite.update(
      'memo_reminders',
      {'mode': mode, 'times_json': timesJson, 'updated_time': now},
      where: 'memo_uid = ?',
      whereArgs: [memoUid],
    );
    if (updated == 0) {
      await sqlite.insert('memo_reminders', {
        'memo_uid': memoUid,
        'mode': mode,
        'times_json': timesJson,
        'created_time': now,
        'updated_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    }
    _db.notifyDataChanged();
  }

  Future<void> deleteMemoReminder(String memoUid) async {
    final sqlite = await _db.db;
    await sqlite.delete(
      'memo_reminders',
      where: 'memo_uid = ?',
      whereArgs: [memoUid],
    );
    _db.notifyDataChanged();
  }

  Future<void> upsertComposeDraftRow(Map<String, Object?> row) async {
    final sqlite = await _db.db;
    await sqlite.insert(
      'compose_drafts',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _db.notifyDataChanged();
  }

  Future<void> replaceComposeDraftRows({
    required String workspaceKey,
    required List<Map<String, Object?>> rows,
  }) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await txn.delete(
        'compose_drafts',
        where: 'workspace_key = ?',
        whereArgs: [workspaceKey],
      );
      for (final row in rows) {
        await txn.insert(
          'compose_drafts',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _db.notifyDataChanged();
  }

  Future<void> deleteComposeDraft(String uid) async {
    final sqlite = await _db.db;
    await sqlite.delete('compose_drafts', where: 'uid = ?', whereArgs: [uid]);
    _db.notifyDataChanged();
  }

  Future<void> deleteComposeDraftsByWorkspace(String workspaceKey) async {
    final sqlite = await _db.db;
    await sqlite.delete(
      'compose_drafts',
      where: 'workspace_key = ?',
      whereArgs: [workspaceKey],
    );
    _db.notifyDataChanged();
  }

  Future<void> upsertCollectionReaderProgressRow(
    Map<String, Object?> row,
  ) async {
    final sqlite = await _db.db;
    await sqlite.insert(
      'collection_read_progress',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCollectionReaderProgress(String collectionId) async {
    final sqlite = await _db.db;
    await sqlite.delete(
      'collection_read_progress',
      where: 'collection_id = ?',
      whereArgs: <Object?>[collectionId],
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
    final id = await sqlite.insert('recycle_bin_items', {
      'item_type': itemType,
      'memo_uid': memoUid.trim(),
      'summary': summary,
      'payload_json': payloadJson,
      'deleted_time': deletedTime,
      'expire_time': expireTime,
    });
    _db.notifyDataChanged();
    return id;
  }

  Future<void> deleteRecycleBinItemById(int id) async {
    final sqlite = await _db.db;
    await sqlite.delete('recycle_bin_items', where: 'id = ?', whereArgs: [id]);
    _db.notifyDataChanged();
  }

  Future<void> clearRecycleBinItems() async {
    final sqlite = await _db.db;
    await sqlite.delete('recycle_bin_items');
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await sqlite.insert('import_history', {
      'source': source,
      'file_md5': fileMd5,
      'file_name': fileName,
      'memo_count': memoCount,
      'attachment_count': attachmentCount,
      'failed_count': failedCount,
      'status': status,
      'created_time': now,
      'updated_time': now,
      'error': error,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    await sqlite.update(
      'import_history',
      {
        'status': status,
        'memo_count': memoCount,
        'attachment_count': attachmentCount,
        'failed_count': failedCount,
        'updated_time': DateTime.now().toUtc().millisecondsSinceEpoch,
        'error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _db.notifyDataChanged();
  }

  Future<int> enqueueOutbox({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final sqlite = await _db.db;
    final id = await _insertOutboxItem(
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
      await _enqueueOutboxBatch(
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
      final rows = await txn.query(
        'outbox',
        where:
            '(state = ? OR state = ?) AND (retry_at IS NULL OR retry_at <= ?)',
        whereArgs: [
          AppDatabase.outboxStatePending,
          AppDatabase.outboxStateRetry,
          now,
        ],
        orderBy: 'id ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final id = _readInt(rows.first['id']);
      if (id == null) return null;

      final updated = await txn.update(
        'outbox',
        {'state': AppDatabase.outboxStateRunning},
        where: 'id = ? AND (state = ? OR state = ?)',
        whereArgs: [
          id,
          AppDatabase.outboxStatePending,
          AppDatabase.outboxStateRetry,
        ],
      );
      if (updated <= 0) return null;

      final claimedRows = await txn.query(
        'outbox',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (claimedRows.isEmpty) return null;
      return Map<String, dynamic>.from(claimedRows.first);
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
      final updated = await txn.rawUpdate(
        '''
UPDATE outbox
SET state = ?
WHERE id = ?
  AND (
    state = ?
    OR (state = ? AND (retry_at IS NULL OR retry_at <= ?))
  );
''',
        [
          AppDatabase.outboxStateRunning,
          id,
          AppDatabase.outboxStatePending,
          AppDatabase.outboxStateRetry,
          now,
        ],
      );
      if (updated <= 0) return null;
      final rows = await txn.query(
        'outbox',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    });
    if (claimed != null) {
      _db.notifyDataChanged();
    }
    return claimed;
  }

  Future<int> recoverOutboxRunningTasks() async {
    final sqlite = await _db.db;
    final updated = await sqlite.rawUpdate(
      'UPDATE outbox SET state = ?, retry_at = NULL WHERE state = ?',
      [AppDatabase.outboxStatePending, AppDatabase.outboxStateRunning],
    );
    if (updated > 0) {
      _db.notifyDataChanged();
    }
    return updated;
  }

  Future<void> markOutboxDone(int id) async {
    final sqlite = await _db.db;
    await sqlite.rawUpdate(
      'UPDATE outbox SET state = ?, retry_at = NULL, last_error = NULL, failure_code = NULL, failure_kind = NULL, quarantined_at = NULL WHERE id = ?',
      [AppDatabase.outboxStateDone, id],
    );
    _db.notifyDataChanged();
  }

  Future<void> completeOutboxTask(int id) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE outbox SET state = ?, retry_at = NULL, last_error = NULL, failure_code = NULL, failure_kind = NULL, quarantined_at = NULL WHERE id = ?',
        [AppDatabase.outboxStateDone, id],
      );
      await txn.delete('outbox', where: 'id = ?', whereArgs: [id]);
    });
    _db.notifyDataChanged();
  }

  Future<void> markOutboxError(int id, {required String error}) async {
    final sqlite = await _db.db;
    await sqlite.rawUpdate(
      'UPDATE outbox SET state = ?, attempts = attempts + 1, retry_at = NULL, last_error = ?, failure_code = NULL, failure_kind = NULL, quarantined_at = NULL WHERE id = ?',
      [AppDatabase.outboxStateError, error, id],
    );
    _db.notifyDataChanged();
  }

  Future<void> markOutboxRetryScheduled(
    int id, {
    required String error,
    required int retryAtMs,
  }) async {
    final sqlite = await _db.db;
    await sqlite.rawUpdate(
      'UPDATE outbox SET state = ?, attempts = attempts + 1, retry_at = ?, last_error = ?, failure_code = NULL, failure_kind = ?, quarantined_at = NULL WHERE id = ?',
      [AppDatabase.outboxStateRetry, retryAtMs, error, 'retryable', id],
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
    if (incrementAttempts) {
      await sqlite.rawUpdate(
        'UPDATE outbox SET state = ?, attempts = attempts + 1, retry_at = NULL, last_error = ?, failure_code = ?, failure_kind = ?, quarantined_at = ? WHERE id = ?',
        [
          AppDatabase.outboxStateQuarantined,
          error,
          failureCode,
          failureKind,
          now,
          id,
        ],
      );
    } else {
      await sqlite.rawUpdate(
        'UPDATE outbox SET state = ?, retry_at = NULL, last_error = ?, failure_code = ?, failure_kind = ?, quarantined_at = ? WHERE id = ?',
        [
          AppDatabase.outboxStateQuarantined,
          error,
          failureCode,
          failureKind,
          now,
          id,
        ],
      );
    }
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
    final normalizedMemoUid = (memoUid ?? '').trim();
    final rows = await sqlite.query(
      'outbox',
      columns: const ['id', 'type', 'payload'],
      where: 'state IN (?, ?)',
      whereArgs: const [
        AppDatabase.outboxStateError,
        AppDatabase.outboxStateQuarantined,
      ],
      orderBy: 'id ASC',
    );

    final ids = <int>[];
    for (final row in rows) {
      final id = _readInt(row['id']);
      if (id == null) continue;
      if (normalizedMemoUid.isEmpty) {
        ids.add(id);
        continue;
      }
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (type is! String || payloadRaw is! String) continue;
      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final targetUid = _extractOutboxMemoUid(type, payload);
      if (targetUid == null || targetUid.trim() != normalizedMemoUid) {
        continue;
      }
      ids.add(id);
    }

    if (ids.isEmpty) return 0;
    for (final id in ids) {
      await sqlite.rawUpdate(
        'UPDATE outbox SET state = ?, retry_at = NULL, last_error = NULL, failure_code = NULL, failure_kind = NULL, quarantined_at = NULL WHERE id = ?',
        [AppDatabase.outboxStatePending, id],
      );
    }
    _db.notifyDataChanged();
    return ids.length;
  }

  Future<void> retryOutboxItem(int id) async {
    final sqlite = await _db.db;
    await sqlite.rawUpdate(
      'UPDATE outbox SET state = ?, retry_at = NULL, last_error = NULL, failure_code = NULL, failure_kind = NULL, quarantined_at = NULL WHERE id = ?',
      [AppDatabase.outboxStatePending, id],
    );
    _db.notifyDataChanged();
  }

  Future<void> deleteOutbox(int id) async {
    final sqlite = await _db.db;
    await sqlite.delete('outbox', where: 'id = ?', whereArgs: [id]);
    _db.notifyDataChanged();
  }

  Future<int> deleteOutboxItems(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final normalizedIds = ids.where((id) => id > 0).toList(growable: false);
    if (normalizedIds.isEmpty) return 0;
    final sqlite = await _db.db;
    final placeholders = List.filled(normalizedIds.length, '?').join(', ');
    final deleted = await sqlite.delete(
      'outbox',
      where: 'id IN ($placeholders)',
      whereArgs: normalizedIds,
    );
    if (deleted > 0) {
      _db.notifyDataChanged();
    }
    return deleted;
  }

  Future<void> deleteOutboxForMemo(String memoUid) async {
    final sqlite = await _db.db;
    final deleted = await _deleteOutboxForMemo(sqlite, memoUid);
    if (deleted > 0) {
      _db.notifyDataChanged();
    }
  }

  Future<void> clearOutbox() async {
    final sqlite = await _db.db;
    await sqlite.delete('outbox');
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
        final parent = await _loadTag(txn, parentId);
        if (parent == null) {
          throw StateError('Parent tag not found');
        }
      }
      await _ensureUniqueName(
        txn,
        name: normalizedName,
        parentId: parentId,
        excludeId: null,
      );
      final parentPath = parentId == null
          ? null
          : (await _loadTag(txn, parentId))?.path;
      if (parentId != null && (parentPath == null || parentPath.isEmpty)) {
        throw StateError('Parent tag not found');
      }
      final path = parentPath == null || parentPath.isEmpty
          ? normalizedName
          : '$parentPath/$normalizedName';
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final id = await txn.insert('tags', {
        'name': normalizedName,
        'parent_id': parentId,
        'path': path,
        'pinned': pinned ? 1 : 0,
        'color_hex': normalizedColor,
        'create_time': now,
        'update_time': now,
      });
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
      final current = await _loadTag(txn, id);
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

      await _assertNoCycle(txn, id, nextParentId);
      await _ensureUniqueName(
        txn,
        name: nextName,
        parentId: nextParentId,
        excludeId: id,
      );

      final parentPath = nextParentId == null
          ? null
          : (await _loadTag(txn, nextParentId))?.path;
      if (nextParentId != null && (parentPath == null || parentPath.isEmpty)) {
        throw StateError('Parent tag not found');
      }
      final newPath = parentPath == null || parentPath.isEmpty
          ? nextName
          : '$parentPath/$nextName';
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      if (newPath == current.path) {
        await txn.update(
          'tags',
          {
            'name': nextName,
            'parent_id': nextParentId,
            'pinned': nextPinned ? 1 : 0,
            'color_hex': nextColor,
            'update_time': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        final descendants = await txn.query(
          'tags',
          columns: const ['id', 'path', 'parent_id'],
          where: 'path = ? OR path LIKE ?',
          whereArgs: [current.path, '${current.path}/%'],
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
          final rows = await txn.query(
            'tags',
            columns: const ['id'],
            where: 'path = ?',
            whereArgs: [entry.value],
            limit: 1,
          );
          final existingId = rows.isNotEmpty
              ? (_readInt(rows.first['id']) ?? 0)
              : 0;
          if (existingId > 0 && !subtreeIds.contains(existingId)) {
            throw StateError('Tag path already exists');
          }
        }

        for (final row in descendants) {
          final tagId = _readInt(row['id']) ?? 0;
          final oldPath = row['path'] as String? ?? '';
          if (tagId <= 0 || oldPath.isEmpty) continue;
          await txn.insert('tag_aliases', {
            'tag_id': tagId,
            'alias': oldPath,
            'created_time': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        final newPathForTag = newPaths[id] ?? newPath;
        await txn.update(
          'tags',
          {
            'name': nextName,
            'parent_id': nextParentId,
            'path': newPathForTag,
            'pinned': nextPinned ? 1 : 0,
            'color_hex': nextColor,
            'update_time': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        for (final entry in newPaths.entries) {
          final tagId = entry.key;
          if (tagId == id) continue;
          await txn.update(
            'tags',
            {'path': entry.value, 'update_time': now},
            where: 'id = ?',
            whereArgs: [tagId],
          );
        }

        final memoUids = await _db.listMemoUidsByTagIds(
          txn,
          subtreeIds.toList(growable: false),
        );
        for (final memoUid in memoUids) {
          final paths = await _db.listTagPathsForMemo(txn, memoUid);
          await _db.updateMemoTagsText(txn, memoUid, paths);
        }
      }

      updated = (await _loadTag(txn, id)) ?? current;
    });
    _db.notifyDataChanged();
    return updated;
  }

  Future<void> deleteTag(int id) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      final current = await _loadTag(txn, id);
      if (current == null) return;
      final parentId = current.parentId;
      final parentPath = parentId == null
          ? ''
          : (await _loadTag(txn, parentId))?.path ?? '';

      final descendants = await txn.query(
        'tags',
        columns: const ['id', 'path', 'parent_id'],
        where: 'path LIKE ?',
        whereArgs: ['${current.path}/%'],
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
        final rows = await txn.query(
          'tags',
          columns: const ['id'],
          where: 'path = ?',
          whereArgs: [entry.value],
          limit: 1,
        );
        final existingId = rows.isNotEmpty
            ? (_readInt(rows.first['id']) ?? 0)
            : 0;
        if (existingId > 0 && !affectedIds.contains(existingId)) {
          throw StateError('Tag path already exists');
        }
      }

      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      for (final row in descendants) {
        final tagId = _readInt(row['id']) ?? 0;
        final oldPath = row['path'] as String? ?? '';
        if (tagId <= 0 || oldPath.isEmpty) continue;
        await txn.insert('tag_aliases', {
          'tag_id': tagId,
          'alias': oldPath,
          'created_time': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
        await txn.update(
          'tags',
          {
            'path': entry.value,
            'update_time': now,
            if (isDirectChild) 'parent_id': parentId,
          },
          where: 'id = ?',
          whereArgs: [tagId],
        );
      }

      final memoUids = await _db.listMemoUidsByTagIds(
        txn,
        affectedIds.toList(growable: false),
      );

      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);

      for (final memoUid in memoUids) {
        final paths = await _db.listTagPathsForMemo(txn, memoUid);
        await _db.updateMemoTagsText(txn, memoUid, paths);
      }
    });
    _db.notifyDataChanged();
  }

  Future<void> applyTagSnapshot(TagSnapshot snapshot) async {
    final sqlite = await _db.db;
    await sqlite.transaction((txn) async {
      final existingTagRows = await txn.query('tags', orderBy: 'id ASC');
      final existingAliasRows = await txn.query(
        'tag_aliases',
        orderBy: 'id ASC',
      );
      final existingTags = existingTagRows
          .map(TagEntity.fromDb)
          .toList(growable: false);
      final existingAliases = existingAliasRows
          .map(TagAliasRecord.fromDb)
          .toList(growable: false);
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

      await txn.delete('memo_tags');
      await txn.delete('tag_aliases');
      await txn.delete('tags');

      for (final tag in snapshot.tags) {
        await txn.insert('tags', {
          'id': tag.id,
          'name': tag.name,
          'parent_id': tag.parentId,
          'path': tag.path,
          'pinned': tag.pinned ? 1 : 0,
          'color_hex': tag.colorHex,
          'create_time': tag.createTimeSec,
          'update_time': tag.updateTimeSec,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final alias in snapshot.aliases) {
        await txn.insert('tag_aliases', {
          'tag_id': alias.tagId,
          'alias': alias.alias,
          'created_time': alias.createdTimeSec,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final memos = await txn.query('memos', columns: const ['uid', 'tags']);
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
          var entry = await _findResolvedTag(txn, tag);
          entry ??= await _restoreTagFromExisting(
            txn,
            tag,
            existingTagsByPath: existingTagsByPath,
            existingTagsById: existingTagsById,
            existingAliasesByPath: existingAliasesByPath,
          );
          if (entry == null) {
            final created = await _db.resolveTagPath(txn, tag);
            if (created != null) {
              entry = _ResolvedTagRef(id: created.id, path: created.path);
            }
          }
          if (entry == null) continue;
          final resolvedEntry = entry;
          resolved.putIfAbsent(resolvedEntry.path, () => resolvedEntry.id);
        }
        await _db.updateMemoTagsMapping(
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

  Future<_ResolvedTagRef?> _findResolvedTag(
    DatabaseExecutor txn,
    String rawTag,
  ) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final directRows = await txn.query(
      'tags',
      columns: const ['id', 'path'],
      where: 'path = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (directRows.isNotEmpty) {
      final row = directRows.first;
      final id = _readInt(row['id']) ?? 0;
      final path = row['path'] as String? ?? normalized;
      if (id > 0 && path.trim().isNotEmpty) {
        return _ResolvedTagRef(id: id, path: path);
      }
    }

    final aliasRows = await txn.query(
      'tag_aliases',
      columns: const ['tag_id'],
      where: 'alias = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (aliasRows.isEmpty) return null;
    final tagId = _readInt(aliasRows.first['tag_id']) ?? 0;
    if (tagId <= 0) return null;
    final tagRows = await txn.query(
      'tags',
      columns: const ['id', 'path'],
      where: 'id = ?',
      whereArgs: [tagId],
      limit: 1,
    );
    if (tagRows.isEmpty) return null;
    final row = tagRows.first;
    final path = row['path'] as String? ?? normalized;
    if (path.trim().isEmpty) return null;
    return _ResolvedTagRef(id: tagId, path: path);
  }

  Future<_ResolvedTagRef?> _restoreTagFromExisting(
    DatabaseExecutor txn,
    String rawTag, {
    required Map<String, TagEntity> existingTagsByPath,
    required Map<int, TagEntity> existingTagsById,
    required Map<String, List<TagAliasRecord>> existingAliasesByPath,
  }) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final existing = existingTagsByPath[normalized];
    if (existing == null) return null;

    final resolved = await _findResolvedTag(txn, normalized);
    if (resolved != null) return resolved;

    _ResolvedTagRef? restoredParent;
    final parentFromId = existing.parentId == null
        ? null
        : existingTagsById[existing.parentId!];
    if (parentFromId != null) {
      restoredParent = await _restoreTagFromExisting(
        txn,
        parentFromId.path,
        existingTagsByPath: existingTagsByPath,
        existingTagsById: existingTagsById,
        existingAliasesByPath: existingAliasesByPath,
      );
    } else {
      final slashIndex = existing.path.lastIndexOf('/');
      if (slashIndex > 0) {
        restoredParent = await _restoreTagFromExisting(
          txn,
          existing.path.substring(0, slashIndex),
          existingTagsByPath: existingTagsByPath,
          existingTagsById: existingTagsById,
          existingAliasesByPath: existingAliasesByPath,
        );
      }
    }

    await txn.insert('tags', {
      'name': existing.name,
      'parent_id': restoredParent?.id,
      'path': existing.path,
      'pinned': existing.pinned ? 1 : 0,
      'color_hex': existing.colorHex,
      'create_time': existing.createTimeSec,
      'update_time': existing.updateTimeSec,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final restored = await _findResolvedTag(txn, existing.path);
    if (restored == null) return null;

    final aliases =
        existingAliasesByPath[existing.path] ?? const <TagAliasRecord>[];
    for (final alias in aliases) {
      final normalizedAlias = normalizeTagPath(alias.alias);
      if (normalizedAlias.isEmpty || normalizedAlias == restored.path) continue;
      await txn.insert('tag_aliases', {
        'tag_id': restored.id,
        'alias': normalizedAlias,
        'created_time': alias.createdTimeSec,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return restored;
  }

  Future<TagEntity?> _loadTag(DatabaseExecutor txn, int id) async {
    if (id <= 0) return null;
    final rows = await txn.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TagEntity.fromDb(rows.first);
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

  Future<void> _ensureUniqueName(
    DatabaseExecutor txn, {
    required String name,
    required int? parentId,
    required int? excludeId,
  }) async {
    final rows = await txn.query(
      'tags',
      columns: const ['id'],
      where: parentId == null
          ? 'name = ? AND parent_id IS NULL'
          : 'name = ? AND parent_id = ?',
      whereArgs: parentId == null ? [name] : [name, parentId],
      limit: 1,
    );
    final existingId = rows.isNotEmpty ? (_readInt(rows.first['id']) ?? 0) : 0;
    if (existingId > 0 && existingId != excludeId) {
      throw StateError('Tag name already exists');
    }
  }

  Future<void> _assertNoCycle(
    DatabaseExecutor txn,
    int id,
    int? parentId,
  ) async {
    if (parentId == null) return;
    if (parentId == id) {
      throw StateError('Tag cannot be its own parent');
    }
    int? current = parentId;
    final visited = <int>{};
    while (current != null && visited.add(current)) {
      if (current == id) {
        throw StateError('Tag hierarchy cycle detected');
      }
      final rows = await txn.query(
        'tags',
        columns: const ['parent_id'],
        where: 'id = ?',
        whereArgs: [current],
        limit: 1,
      );
      if (rows.isEmpty) break;
      current = _readInt(rows.first['parent_id']);
    }
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Map<String, dynamic>? _decodeOutboxPayload(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  String? _extractOutboxMemoUid(String type, Map<String, dynamic> payload) {
    return switch (type) {
      'create_memo' ||
      'update_memo' ||
      'delete_memo' => payload['uid'] as String?,
      'upload_attachment' ||
      'delete_attachment' => payload['memo_uid'] as String?,
      _ => null,
    };
  }

  Future<void> _renameMemoUid(
    DatabaseExecutor executor, {
    required String oldUid,
    required String newUid,
  }) async {
    await executor.update(
      'memos',
      {'uid': newUid},
      where: 'uid = ?',
      whereArgs: [oldUid],
    );
    await executor.update(
      'memo_reminders',
      {'memo_uid': newUid},
      where: 'memo_uid = ?',
      whereArgs: [oldUid],
    );
    await executor.update(
      'attachments',
      {'memo_uid': newUid},
      where: 'memo_uid = ?',
      whereArgs: [oldUid],
    );
    await executor.update(
      'memo_relations_cache',
      {'memo_uid': newUid},
      where: 'memo_uid = ?',
      whereArgs: [oldUid],
    );
    await executor.update(
      'memo_versions',
      {'memo_uid': newUid},
      where: 'memo_uid = ?',
      whereArgs: [oldUid],
    );
    await executor.update(
      'recycle_bin_items',
      {'memo_uid': newUid},
      where: 'memo_uid = ?',
      whereArgs: [oldUid],
    );
    await executor.update(
      'memo_inline_image_sources',
      {'memo_uid': newUid},
      where: 'memo_uid = ?',
      whereArgs: [oldUid],
    );
  }

  Future<int> _rewriteOutboxMemoUids(
    DatabaseExecutor executor, {
    required String oldUid,
    required String newUid,
  }) async {
    var changedCount = 0;
    final rows = await executor.query(
      'outbox',
      columns: const ['id', 'type', 'payload'],
    );
    for (final row in rows) {
      final id = _readInt(row['id']);
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (id == null || type is! String || payloadRaw is! String) continue;

      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;

      var changed = false;
      switch (type) {
        case 'create_memo':
        case 'update_memo':
        case 'delete_memo':
          if (payload['uid'] == oldUid) {
            payload['uid'] = newUid;
            changed = true;
          }
          break;
        case 'upload_attachment':
        case 'delete_attachment':
          if (payload['memo_uid'] == oldUid) {
            payload['memo_uid'] = newUid;
            changed = true;
          }
          break;
      }
      if (!changed) continue;

      await executor.update(
        'outbox',
        {'payload': jsonEncode(payload)},
        where: 'id = ?',
        whereArgs: [id],
      );
      changedCount++;
    }
    return changedCount;
  }

  Future<bool> _hasPendingOutboxTaskForMemo(
    DatabaseExecutor executor,
    String memoUid, {
    Set<String>? types,
  }) async {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return false;
    final rows = await executor.query(
      'outbox',
      columns: const ['type', 'payload'],
      where: 'state IN (?, ?, ?, ?, ?)',
      whereArgs: const [
        AppDatabase.outboxStatePending,
        AppDatabase.outboxStateRunning,
        AppDatabase.outboxStateRetry,
        AppDatabase.outboxStateError,
        AppDatabase.outboxStateQuarantined,
      ],
    );

    for (final row in rows) {
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (type is! String || payloadRaw is! String) continue;
      if (types != null && !types.contains(type)) continue;
      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final targetUid = _extractOutboxMemoUid(type, payload);
      if (targetUid is String && targetUid.trim() == trimmed) {
        return true;
      }
    }

    return false;
  }

  Future<int> updatePendingCreateMemoContent({
    required String memoUid,
    required String content,
    String? visibility,
  }) async {
    final trimmedMemoUid = memoUid.trim();
    if (trimmedMemoUid.isEmpty) return 0;

    final sqlite = await _db.db;
    final rows = await sqlite.query(
      'outbox',
      columns: const ['id', 'payload'],
      where: 'type = ? AND state IN (?, ?, ?, ?, ?)',
      whereArgs: const [
        'create_memo',
        AppDatabase.outboxStatePending,
        AppDatabase.outboxStateRunning,
        AppDatabase.outboxStateRetry,
        AppDatabase.outboxStateError,
        AppDatabase.outboxStateQuarantined,
      ],
    );

    var updatedCount = 0;
    for (final row in rows) {
      final id = _readInt(row['id']);
      final payloadRaw = row['payload'];
      if (id == null || payloadRaw is! String) continue;

      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final payloadUid = (payload['uid'] as String? ?? '').trim();
      if (payloadUid != trimmedMemoUid) continue;

      var changed = false;
      if (payload['content'] != content) {
        payload['content'] = content;
        changed = true;
      }
      if (visibility != null && payload['visibility'] != visibility) {
        payload['visibility'] = visibility;
        changed = true;
      }
      if (!changed) continue;

      await sqlite.update(
        'outbox',
        {'payload': jsonEncode(payload)},
        where: 'id = ?',
        whereArgs: [id],
      );
      updatedCount++;
    }

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
    final rows = await executor.query(
      'memos',
      columns: const ['attachments_json'],
      where: 'uid = ?',
      whereArgs: [memoUid],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final raw = rows.first['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;

    final expectedNames = <String>{
      'attachments/$attachmentUid',
      'resources/$attachmentUid',
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

    await executor.update(
      'memos',
      <String, Object?>{'attachments_json': jsonEncode(next)},
      where: 'uid = ?',
      whereArgs: [memoUid],
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
    final attachmentsJson = jsonEncode(attachments);
    final locationPlaceholder = location?.placeholder;
    final locationLat = location?.latitude;
    final locationLng = location?.longitude;
    final normalizedDisplayTimeSec = _db.normalizeDisplayTimeSec(
      preserveDisplayTime ? null : displayTimeSec,
    );

    final normalizedTags = _normalizeMemoTags(tags);
    final resolved = <String, int>{};
    for (final raw in normalizedTags) {
      final resolvedTag = await _db.resolveTagPath(executor, raw);
      if (resolvedTag == null) continue;
      resolved.putIfAbsent(resolvedTag.path, () => resolvedTag.id);
    }
    final canonicalTags = resolved.keys.toList(growable: false);
    final tagsText = canonicalTags.join(' ');

    final before = await _db.loadMemoSnapshotPayload(executor, uid);
    final values = <String, Object?>{
      'content': content,
      'visibility': visibility,
      'pinned': pinned ? 1 : 0,
      'state': state,
      'create_time': createTimeSec,
      'update_time': updateTimeSec,
      'tags': tagsText,
      'attachments_json': attachmentsJson,
      'location_placeholder': locationPlaceholder,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'relation_count': relationCount,
      'sync_state': syncState,
      'last_error': lastError,
    };
    if (!preserveDisplayTime) {
      values['display_time'] = normalizedDisplayTimeSec;
    }
    final updated = await executor.update(
      'memos',
      values,
      where: 'uid = ?',
      whereArgs: [uid],
    );

    int rowId;
    if (updated == 0) {
      rowId = await executor.insert('memos', {
        'uid': uid,
        'content': content,
        'visibility': visibility,
        'pinned': pinned ? 1 : 0,
        'state': state,
        'create_time': createTimeSec,
        'display_time': normalizedDisplayTimeSec,
        'update_time': updateTimeSec,
        'tags': tagsText,
        'attachments_json': attachmentsJson,
        'location_placeholder': locationPlaceholder,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'relation_count': relationCount,
        'sync_state': syncState,
        'last_error': lastError,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    } else {
      final rows = await executor.query(
        'memos',
        columns: const ['id'],
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );
      rowId = rows.isEmpty ? 0 : (_readInt(rows.first['id']) ?? 0);
      if (rowId <= 0) {
        return;
      }
    }

    await _db.refreshMemoFtsEntryForMemo(
      executor,
      rowId: rowId,
      memoUid: uid,
      content: content,
      tags: tagsText,
    );

    await _db.updateMemoTagsMapping(
      executor,
      uid,
      resolved.values.toList(growable: false),
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

  Future<void> _upsertMemoRelationsCache(
    DatabaseExecutor executor,
    String memoUid, {
    required String relationsJson,
  }) async {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final updated = await executor.update(
      'memo_relations_cache',
      {'relations_json': relationsJson, 'updated_time': now},
      where: 'memo_uid = ?',
      whereArgs: [normalized],
    );
    if (updated == 0) {
      await executor.insert('memo_relations_cache', {
        'memo_uid': normalized,
        'relations_json': relationsJson,
        'updated_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    }
  }

  Future<void> _deleteMemoRelationsCache(
    DatabaseExecutor executor,
    String memoUid,
  ) async {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return;
    await executor.delete(
      'memo_relations_cache',
      where: 'memo_uid = ?',
      whereArgs: [normalized],
    );
  }

  Future<void> _upsertMemoDeleteTombstone(
    DatabaseExecutor executor, {
    required String memoUid,
    required String state,
    String? lastError,
    int? deletedTime,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final existing = await executor.query(
      'memo_delete_tombstones',
      columns: const ['deleted_time'],
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
      limit: 1,
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final deletedTimeValue = switch (existing.isEmpty
        ? null
        : existing.first['deleted_time']) {
      int value when deletedTime == null => value,
      num value when deletedTime == null => value.toInt(),
      String value when deletedTime == null =>
        int.tryParse(value.trim()) ?? now,
      _ => deletedTime ?? now,
    };
    await executor.insert('memo_delete_tombstones', {
      'memo_uid': normalizedUid,
      'state': state,
      'deleted_time': deletedTimeValue,
      'updated_time': now,
      'last_error': lastError,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _deleteMemoByUid(DatabaseExecutor executor, String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    final before = await _db.loadMemoSnapshotPayload(executor, normalizedUid);
    final rows = await executor.query(
      'memos',
      columns: const ['id'],
      where: 'uid = ?',
      whereArgs: [normalizedUid],
      limit: 1,
    );
    final rowId = rows.isEmpty ? null : _readInt(rows.first['id']);
    await executor.delete(
      'memos',
      where: 'uid = ?',
      whereArgs: [normalizedUid],
    );
    await executor.delete(
      'memo_relations_cache',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    await executor.delete(
      'memo_versions',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    if (rowId != null && rowId > 0) {
      await _db.deleteMemoFtsEntry(executor, rowId: rowId);
    }
    await _db.applyMemoCacheDeltaPayload(executor, before: before, after: null);
  }

  Future<void> _upsertMemoClipCard(
    DatabaseExecutor executor,
    MemoClipCardMetadata metadata,
  ) async {
    final memoUid = metadata.memoUid.trim();
    if (memoUid.isEmpty) return;

    await executor.insert(
      'memo_clip_cards',
      metadata.toDbRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final memoRows = await executor.query(
      'memos',
      columns: const ['id', 'content', 'tags'],
      where: 'uid = ?',
      whereArgs: [memoUid],
      limit: 1,
    );
    if (memoRows.isEmpty) return;
    final rowId = _readInt(memoRows.first['id']) ?? 0;
    if (rowId <= 0) return;
    await _db.refreshMemoFtsEntryForMemo(
      executor,
      rowId: rowId,
      memoUid: memoUid,
      content: (memoRows.first['content'] as String?) ?? '',
      tags: (memoRows.first['tags'] as String?) ?? '',
    );
  }

  Future<void> _deleteMemoClipCard(
    DatabaseExecutor executor,
    String memoUid,
  ) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;

    await executor.delete(
      'memo_clip_cards',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );

    final memoRows = await executor.query(
      'memos',
      columns: const ['id', 'content', 'tags'],
      where: 'uid = ?',
      whereArgs: [normalizedUid],
      limit: 1,
    );
    if (memoRows.isEmpty) return;
    final rowId = _readInt(memoRows.first['id']) ?? 0;
    if (rowId <= 0) return;
    await _db.refreshMemoFtsEntryForMemo(
      executor,
      rowId: rowId,
      memoUid: normalizedUid,
      content: (memoRows.first['content'] as String?) ?? '',
      tags: (memoRows.first['tags'] as String?) ?? '',
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

  Future<int> _enqueueOutboxBatch(
    DatabaseExecutor executor, {
    required List<Map<String, Object?>> items,
    required int createdTimeMs,
  }) async {
    var insertedCount = 0;
    for (final item in items) {
      final type = (item['type'] as String? ?? '').trim();
      final payload = item['payload'];
      if (type.isEmpty || payload is! Map) continue;
      await _insertOutboxItem(
        executor,
        type: type,
        payload: Map<Object?, Object?>.from(payload),
        createdTimeMs: createdTimeMs,
      );
      insertedCount++;
    }
    return insertedCount;
  }

  Future<int> _insertOutboxItem(
    DatabaseExecutor executor, {
    required String type,
    required Map<Object?, Object?> payload,
    required int createdTimeMs,
  }) {
    return executor.insert('outbox', {
      'type': type,
      'payload': jsonEncode(
        payload.map<String, Object?>(
          (mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue),
        ),
      ),
      'state': AppDatabase.outboxStatePending,
      'attempts': 0,
      'last_error': null,
      'failure_code': null,
      'failure_kind': null,
      'retry_at': null,
      'quarantined_at': null,
      'created_time': createdTimeMs,
    });
  }

  Future<int> _deleteOutboxForMemo(
    DatabaseExecutor executor,
    String memoUid,
  ) async {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return 0;

    final rows = await executor.query(
      'outbox',
      columns: const ['id', 'type', 'payload'],
      where: 'state IN (?, ?, ?, ?, ?)',
      whereArgs: const [
        AppDatabase.outboxStatePending,
        AppDatabase.outboxStateRunning,
        AppDatabase.outboxStateRetry,
        AppDatabase.outboxStateError,
        AppDatabase.outboxStateQuarantined,
      ],
    );
    final ids = <int>[];
    for (final row in rows) {
      final id = _readInt(row['id']);
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (id == null || type is! String || payloadRaw is! String) continue;
      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final target = _extractOutboxMemoUid(type, payload);
      if (target is String && target.trim() == trimmed) {
        ids.add(id);
      }
    }
    if (ids.isEmpty) return 0;
    for (final id in ids) {
      await executor.delete('outbox', where: 'id = ?', whereArgs: [id]);
    }
    return ids.length;
  }

  String _backendKindToStorage(AiBackendKind value) => switch (value) {
    AiBackendKind.remoteApi => 'remote_api',
    AiBackendKind.localApi => 'local_api',
  };

  String _providerKindToStorage(AiProviderKind value) => switch (value) {
    AiProviderKind.openAiCompatible => 'openai_compatible',
    AiProviderKind.anthropicCompatible => 'anthropic_compatible',
  };

  List<String> _normalizeMemoTags(List<String> tags) {
    if (tags.isEmpty) return const [];
    final normalized = <String>[];
    for (final raw in tags) {
      final value = normalizeTagPath(raw);
      if (value.isEmpty) continue;
      normalized.add(value);
    }
    return normalized;
  }
}

class _ResolvedTagRef {
  const _ResolvedTagRef({required this.id, required this.path});

  final int id;
  final String path;
}
