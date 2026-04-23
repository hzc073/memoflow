import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../db/app_database_write_dao.dart';
import '../db/db_write_protocol.dart';
import '../db/desktop_db_write_gateway.dart';
import 'ai_analysis_models.dart';
import '../repositories/ai_settings_repository.dart';

class AiAnalysisRepository {
  AiAnalysisRepository(this._appDatabase, {DesktopDbWriteGateway? writeGateway})
    : _writeGateway = writeGateway;

  final AppDatabase _appDatabase;
  final DesktopDbWriteGateway? _writeGateway;
  late final AppDatabaseWriteDao _writeDao = AppDatabaseWriteDao(
    db: _appDatabase,
  );
  int _localWriteDepth = 0;

  Future<Database> get _db => _appDatabase.db;

  bool get _writeProxyEnabled => _writeGateway != null;

  Future<T> _runLocalWrite<T>(Future<T> Function() action) async {
    _localWriteDepth += 1;
    try {
      return await action();
    } finally {
      _localWriteDepth -= 1;
    }
  }

  Future<T> _dispatchWriteCommand<T>({
    required String operation,
    required Map<String, dynamic> payload,
    required T Function(Object? raw) decode,
  }) async {
    final gateway = _writeGateway;
    if (gateway == null) {
      throw StateError('Write gateway is not configured.');
    }
    final result = await gateway.execute<T>(
      workspaceKey: _appDatabase.workspaceKey,
      dbName: _appDatabase.dbName,
      commandType: aiAnalysisRepositoryWriteCommandType,
      operation: operation,
      payload: payload,
      localExecute: () =>
          _executeWriteOperationLocally(operation: operation, payload: payload),
      decode: decode,
    );
    if (gateway.isRemote) {
      _appDatabase.notifyDataChanged();
    }
    return result;
  }

  Future<Object?> executeWriteEnvelopeLocally(DbWriteEnvelope envelope) async {
    if (envelope.commandType != aiAnalysisRepositoryWriteCommandType) {
      throw UnsupportedError(
        'Unsupported AI analysis repository command type.',
      );
    }
    final gateway = _writeGateway;
    if (gateway is OwnerDesktopDbWriteGateway) {
      return gateway.executeEnvelope<Object?>(
        envelope: envelope,
        localExecute: () => _executeWriteOperationLocally(
          operation: envelope.operation,
          payload: envelope.payload,
        ),
        decode: (raw) => raw,
      );
    }
    return _executeWriteOperationLocally(
      operation: envelope.operation,
      payload: envelope.payload,
    );
  }

  Future<Object?> _executeWriteOperationLocally({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    switch (operation) {
      case 'upsertMemoPolicy':
        await _runLocalWrite(
          () => upsertMemoPolicy(
            memoUid: _requiredString(payload, 'memoUid'),
            allowAi: _readBoolPayload(payload, 'allowAi'),
          ),
        );
        return null;
      case 'enqueueIndexJob':
        return _runLocalWrite(
          () => enqueueIndexJob(
            memoUid: payload['memoUid'] as String?,
            reason: aiIndexJobReasonFromStorage(
              payload['reason'] as String? ?? '',
            ),
            memoContentHash: payload['memoContentHash'] as String? ?? '',
            embeddingProfileKey:
                payload['embeddingProfileKey'] as String? ?? '',
            priority: _optionalInt(payload, 'priority') ?? 100,
          ),
        );
      case 'updateIndexJobStatus':
        await _runLocalWrite(
          () => updateIndexJobStatus(
            _requiredInt(payload, 'jobId'),
            status: aiIndexJobStatusFromStorage(
              payload['status'] as String? ?? '',
            ),
            attemptCount: _optionalInt(payload, 'attemptCount'),
            errorText: payload['errorText'] as String?,
            markStarted: _readBoolPayload(payload, 'markStarted'),
            markFinished: _readBoolPayload(payload, 'markFinished'),
          ),
        );
        return null;
      case 'invalidateActiveChunksForMemo':
        await _runLocalWrite(
          () => invalidateActiveChunksForMemo(
            _requiredString(payload, 'memoUid'),
          ),
        );
        return null;
      case 'insertActiveChunks':
        return _runLocalWrite(
          () => insertActiveChunks(
            memoUid: _requiredString(payload, 'memoUid'),
            chunks: _readChunkDraftListPayload(payload, 'chunks'),
          ),
        );
      case 'insertEmbeddingRecord':
        await _runLocalWrite(
          () => insertEmbeddingRecord(
            chunkId: _requiredInt(payload, 'chunkId'),
            profile: _readEmbeddingProfilePayload(payload, 'profile'),
            status: aiEmbeddingStatusFromStorage(
              payload['status'] as String? ?? '',
            ),
            vector: _readFloat32VectorPayload(payload, 'vector'),
            errorText: payload['errorText'] as String?,
          ),
        );
        return null;
      case 'createAnalysisTask':
        return _runLocalWrite(
          () => createAnalysisTask(
            taskUid: payload['taskUid'] as String? ?? '',
            analysisType: aiAnalysisTypeFromStorage(
              payload['analysisType'] as String? ?? '',
            ),
            status: aiTaskStatusFromStorage(payload['status'] as String? ?? ''),
            rangeStart: _requiredInt(payload, 'rangeStart'),
            rangeEndExclusive: _requiredInt(payload, 'rangeEndExclusive'),
            includePublic: _readBoolPayload(payload, 'includePublic'),
            includePrivate: _readBoolPayload(payload, 'includePrivate'),
            includeProtected: _readBoolPayload(payload, 'includeProtected'),
            promptTemplate: payload['promptTemplate'] as String? ?? '',
            templateKind: aiAnalysisTemplateKindFromStorage(
              payload['templateKind'] as String? ?? '',
            ),
            templateId: payload['templateId'] as String? ?? '',
            templateTitleSnapshot:
                payload['templateTitleSnapshot'] as String? ?? '',
            templateIconKeySnapshot:
                payload['templateIconKeySnapshot'] as String? ?? '',
            generationProfileKey:
                payload['generationProfileKey'] as String? ?? '',
            embeddingProfileKey:
                payload['embeddingProfileKey'] as String? ?? '',
            retrievalProfile: _readStringDynamicMapPayload(
              payload,
              'retrievalProfile',
            ),
          ),
        );
      case 'updateAnalysisTaskStatus':
        await _runLocalWrite(
          () => updateAnalysisTaskStatus(
            _requiredInt(payload, 'taskId'),
            status: aiTaskStatusFromStorage(payload['status'] as String? ?? ''),
            errorText: payload['errorText'] as String?,
            markCompleted: _readBoolPayload(payload, 'markCompleted'),
          ),
        );
        return null;
      case 'saveAnalysisResult':
        await _runLocalWrite(
          () => saveAnalysisResult(
            taskId: _requiredInt(payload, 'taskId'),
            result: _readStructuredAnalysisResultPayload(payload, 'result'),
          ),
        );
        return null;
      case 'markResultsStaleForMemo':
        await _runLocalWrite(
          () => markResultsStaleForMemo(_requiredString(payload, 'memoUid')),
        );
        return null;
      default:
        throw UnsupportedError(
          'Unsupported AI analysis repository operation: $operation',
        );
    }
  }

  Future<void> upsertMemoPolicy({
    required String memoUid,
    required bool allowAi,
  }) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertMemoPolicy',
        payload: <String, dynamic>{'memoUid': trimmedUid, 'allowAi': allowAi},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertAiMemoPolicy(memoUid: trimmedUid, allowAi: allowAi);
  }

  Future<bool> getMemoAllowAi(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return true;
    final db = await _db;
    final rows = await db.query(
      'ai_memo_policy',
      columns: const ['allow_ai'],
      where: 'memo_uid = ?',
      whereArgs: <Object?>[trimmedUid],
      limit: 1,
    );
    if (rows.isEmpty) return true;
    return ((rows.first['allow_ai'] as int?) ?? 1) == 1;
  }

  Future<List<Map<String, dynamic>>> listMemoRowsForAi({
    int? startTimeSec,
    int? endTimeSecExclusive,
    bool includeArchived = false,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];
    if (!includeArchived) {
      whereClauses.add("m.state = 'NORMAL'");
    }
    if (startTimeSec != null) {
      whereClauses.add('m.create_time >= ?');
      whereArgs.add(startTimeSec);
    }
    if (endTimeSecExclusive != null) {
      whereClauses.add('m.create_time < ?');
      whereArgs.add(endTimeSecExclusive);
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    return db.rawQuery('''
SELECT m.*, COALESCE(p.allow_ai, 1) AS allow_ai
FROM memos m
LEFT JOIN ai_memo_policy p ON p.memo_uid = m.uid
$whereSql
ORDER BY m.create_time DESC, m.id DESC;
''', whereArgs);
  }

  Future<Map<String, dynamic>?> getMemoRowForAi(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return null;
    final db = await _db;
    final rows = await db.rawQuery(
      '''
SELECT m.*, COALESCE(p.allow_ai, 1) AS allow_ai
FROM memos m
LEFT JOIN ai_memo_policy p ON p.memo_uid = m.uid
WHERE m.uid = ?
LIMIT 1;
''',
      <Object?>[trimmedUid],
    );
    return _firstOrNull(rows);
  }

  Future<int> enqueueIndexJob({
    required String? memoUid,
    required AiIndexJobReason reason,
    required String memoContentHash,
    required String embeddingProfileKey,
    int priority = 100,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'enqueueIndexJob',
        payload: <String, dynamic>{
          'memoUid': memoUid?.trim(),
          'reason': aiIndexJobReasonToStorage(reason),
          'memoContentHash': memoContentHash,
          'embeddingProfileKey': embeddingProfileKey,
          'priority': priority,
        },
        decode: (raw) => _readInt(raw) ?? 0,
      );
    }
    return _writeDao.enqueueAiIndexJob(
      memoUid: memoUid,
      reason: reason,
      memoContentHash: memoContentHash,
      embeddingProfileKey: embeddingProfileKey,
      priority: priority,
    );
  }

  Future<List<Map<String, dynamic>>> listPendingIndexJobs({
    required String embeddingProfileKey,
    int limit = 50,
  }) async {
    final db = await _db;
    return db.query(
      'ai_index_jobs',
      where: 'embedding_profile_key = ? AND status IN (?, ?)',
      whereArgs: <Object?>[
        embeddingProfileKey,
        aiIndexJobStatusToStorage(AiIndexJobStatus.queued),
        aiIndexJobStatusToStorage(AiIndexJobStatus.failed),
      ],
      orderBy: 'priority ASC, created_time ASC, id ASC',
      limit: limit,
    );
  }

  Future<void> updateIndexJobStatus(
    int jobId, {
    required AiIndexJobStatus status,
    int? attemptCount,
    String? errorText,
    bool markStarted = false,
    bool markFinished = false,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'updateIndexJobStatus',
        payload: <String, dynamic>{
          'jobId': jobId,
          'status': aiIndexJobStatusToStorage(status),
          'attemptCount': attemptCount,
          'errorText': errorText,
          'markStarted': markStarted,
          'markFinished': markFinished,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.updateAiIndexJobStatus(
      jobId,
      status: status,
      attemptCount: attemptCount,
      errorText: errorText,
      markStarted: markStarted,
      markFinished: markFinished,
    );
  }

  Future<void> invalidateActiveChunksForMemo(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'invalidateActiveChunksForMemo',
        payload: <String, dynamic>{'memoUid': trimmedUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.invalidateAiActiveChunksForMemo(trimmedUid);
  }

  Future<List<Map<String, dynamic>>> listActiveChunkRowsForMemo(
    String memoUid,
  ) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return const <Map<String, dynamic>>[];
    final db = await _db;
    return db.query(
      'ai_chunks',
      where: 'memo_uid = ? AND is_active = 1',
      whereArgs: <Object?>[trimmedUid],
      orderBy: 'chunk_index ASC, id ASC',
    );
  }

  Future<bool> memoHasFreshIndex({
    required String memoUid,
    required String memoContentHash,
    required String baseUrl,
    required String model,
  }) async {
    final activeRows = await listActiveChunkRowsForMemo(memoUid);
    if (activeRows.isEmpty) return false;
    for (final row in activeRows) {
      if (((row['memo_content_hash'] as String?) ?? '') != memoContentHash) {
        return false;
      }
    }
    final db = await _db;
    for (final row in activeRows) {
      final chunkId = row['id'] as int?;
      if (chunkId == null) return false;
      final embeddings = await db.query(
        'ai_embeddings',
        columns: const ['status'],
        where: 'chunk_id = ? AND base_url = ? AND model = ?',
        whereArgs: <Object?>[chunkId, baseUrl, model],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (embeddings.isEmpty) return false;
      final status = aiEmbeddingStatusFromStorage(
        (embeddings.first['status'] as String?) ?? 'failed',
      );
      if (status != AiEmbeddingStatus.ready) return false;
    }
    return true;
  }

  Future<List<int>> insertActiveChunks({
    required String memoUid,
    required List<AiChunkDraft> chunks,
  }) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty || chunks.isEmpty) return const <int>[];
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<List<int>>(
        operation: 'insertActiveChunks',
        payload: <String, dynamic>{
          'memoUid': trimmedUid,
          'chunks': chunks.map(_serializeChunkDraft).toList(growable: false),
        },
        decode: (raw) => _readIntList(raw),
      );
    }
    return _writeDao.insertAiActiveChunks(memoUid: trimmedUid, chunks: chunks);
  }

  Future<void> insertEmbeddingRecord({
    required int chunkId,
    required AiEmbeddingProfile profile,
    required AiEmbeddingStatus status,
    Float32List? vector,
    String? errorText,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'insertEmbeddingRecord',
        payload: <String, dynamic>{
          'chunkId': chunkId,
          'profile': profile.toJson(),
          'status': aiEmbeddingStatusToStorage(status),
          'vector': vector
              ?.map((value) => value.toDouble())
              .toList(growable: false),
          'errorText': errorText,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.insertAiEmbeddingRecord(
      chunkId: chunkId,
      profile: profile,
      status: status,
      vector: vector,
      errorText: errorText,
    );
  }

  Future<Map<String, dynamic>> countCandidateChunkStatuses({
    required int startTimeSec,
    required int endTimeSecExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
    required String baseUrl,
    required String model,
  }) async {
    final db = await _db;
    final visibilityClauses = <String>[];
    if (!includePublic) {
      visibilityClauses.add("c.memo_visibility != 'PUBLIC'");
    }
    if (!includePrivate) {
      visibilityClauses.add("c.memo_visibility != 'PRIVATE'");
    }
    if (!includeProtected) {
      visibilityClauses.add("c.memo_visibility != 'PROTECTED'");
    }
    final visibilitySql = visibilityClauses.isEmpty
        ? ''
        : 'AND ${visibilityClauses.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
SELECT
  COUNT(DISTINCT c.memo_uid) AS memo_count,
  COUNT(*) AS chunk_count,
  SUM(CASE WHEN e.status = 'ready' THEN 1 ELSE 0 END) AS ready_count,
  SUM(CASE WHEN e.status = 'pending' THEN 1 ELSE 0 END) AS pending_count,
  SUM(CASE WHEN e.status = 'failed' THEN 1 ELSE 0 END) AS failed_count
FROM ai_chunks c
LEFT JOIN ai_memo_policy p ON p.memo_uid = c.memo_uid
LEFT JOIN ai_embeddings e
  ON e.chunk_id = c.id
 AND e.base_url = ?
 AND e.model = ?
WHERE c.is_active = 1
  AND c.memo_create_time >= ?
  AND c.memo_create_time < ?
  AND COALESCE(p.allow_ai, 1) = 1
  $visibilitySql;
''',
      <Object?>[baseUrl, model, startTimeSec, endTimeSecExclusive],
    );
    return _firstOrNull(rows) ?? const <String, Object?>{};
  }

  Future<List<Map<String, dynamic>>> listCandidateChunkRows({
    required int startTimeSec,
    required int endTimeSecExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
    required String baseUrl,
    required String model,
    int limit = 3000,
  }) async {
    final db = await _db;
    final whereClauses = <String>[
      'c.is_active = 1',
      'c.memo_create_time >= ?',
      'c.memo_create_time < ?',
      'COALESCE(p.allow_ai, 1) = 1',
    ];
    final args = <Object?>[startTimeSec, endTimeSecExclusive];
    if (!includePublic) {
      whereClauses.add("c.memo_visibility != 'PUBLIC'");
    }
    if (!includePrivate) {
      whereClauses.add("c.memo_visibility != 'PRIVATE'");
    }
    if (!includeProtected) {
      whereClauses.add("c.memo_visibility != 'PROTECTED'");
    }
    final rows = await db.rawQuery(
      '''
SELECT
  c.*, 
  e.id AS embedding_id,
  e.status AS embedding_status,
  e.vector_blob,
  e.dimensions,
  e.error_text
FROM ai_chunks c
LEFT JOIN ai_memo_policy p ON p.memo_uid = c.memo_uid
LEFT JOIN ai_embeddings e
  ON e.chunk_id = c.id
 AND e.base_url = ?
 AND e.model = ?
WHERE ${whereClauses.join(' AND ')}
ORDER BY c.memo_create_time DESC, c.chunk_index ASC
LIMIT ?;
''',
      <Object?>[baseUrl, model, ...args, limit],
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> listPreviewSampleChunks({
    required int startTimeSec,
    required int endTimeSecExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
    required String baseUrl,
    required String model,
    int limit = 5,
  }) async {
    final rows = await listCandidateChunkRows(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
      baseUrl: baseUrl,
      model: model,
      limit: limit,
    );
    return rows;
  }

  Future<int> createAnalysisTask({
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
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'createAnalysisTask',
        payload: <String, dynamic>{
          'taskUid': taskUid,
          'analysisType': aiAnalysisTypeToStorage(analysisType),
          'status': aiTaskStatusToStorage(status),
          'rangeStart': rangeStart,
          'rangeEndExclusive': rangeEndExclusive,
          'includePublic': includePublic,
          'includePrivate': includePrivate,
          'includeProtected': includeProtected,
          'promptTemplate': promptTemplate,
          'templateKind': aiAnalysisTemplateKindToStorage(templateKind),
          'templateId': templateId,
          'templateTitleSnapshot': templateTitleSnapshot,
          'templateIconKeySnapshot': templateIconKeySnapshot,
          'generationProfileKey': generationProfileKey,
          'embeddingProfileKey': embeddingProfileKey,
          'retrievalProfile': retrievalProfile,
        },
        decode: (raw) => _readInt(raw) ?? 0,
      );
    }
    return _writeDao.createAiAnalysisTask(
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
  }

  Future<void> updateAnalysisTaskStatus(
    int taskId, {
    required AiTaskStatus status,
    String? errorText,
    bool markCompleted = false,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'updateAnalysisTaskStatus',
        payload: <String, dynamic>{
          'taskId': taskId,
          'status': aiTaskStatusToStorage(status),
          'errorText': errorText,
          'markCompleted': markCompleted,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.updateAiAnalysisTaskStatus(
      taskId,
      status: status,
      errorText: errorText,
      markCompleted: markCompleted,
    );
  }

  Future<void> saveAnalysisResult({
    required int taskId,
    required AiStructuredAnalysisResult result,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'saveAnalysisResult',
        payload: <String, dynamic>{
          'taskId': taskId,
          'result': _serializeStructuredAnalysisResult(result),
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.saveAiAnalysisResult(taskId: taskId, result: result);
  }

  Future<void> markResultsStaleForMemo(String memoUid) async {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'markResultsStaleForMemo',
        payload: <String, dynamic>{'memoUid': trimmedUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.markAiResultsStaleForMemo(trimmedUid);
  }

  Future<AiSavedAnalysisReport?> loadLatestAnalysisReport({
    required AiAnalysisType analysisType,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
SELECT
  t.id AS task_id,
  t.task_uid,
  t.status,
  r.id AS result_id,
  r.summary,
  r.follow_up_suggestions_json,
  r.is_stale
FROM ai_analysis_tasks t
JOIN ai_analysis_results r ON r.task_id = t.id
WHERE t.analysis_type = ?
ORDER BY t.created_time DESC
LIMIT 1;
''',
      <Object?>[aiAnalysisTypeToStorage(analysisType)],
    );
    final taskRow = _firstOrNull(rows);
    if (taskRow == null) return null;
    return _hydrateAnalysisReportFromJoinedRow(taskRow);
  }

  Future<List<AiSavedAnalysisHistoryEntry>> listAnalysisReportHistory({
    required AiAnalysisType analysisType,
    int? limit = 50,
  }) async {
    final db = await _db;
    final sql = StringBuffer('''
SELECT
  t.id AS task_id,
  t.task_uid,
  t.status,
  t.range_start,
  t.range_end_exclusive,
  t.include_public,
  t.include_private,
  t.include_protected,
  t.prompt_template,
  t.template_kind,
  t.template_id,
  t.template_title_snapshot,
  t.template_icon_key_snapshot,
  t.created_time,
  r.summary,
  r.is_stale
FROM ai_analysis_tasks t
JOIN ai_analysis_results r ON r.task_id = t.id
WHERE t.analysis_type = ?
ORDER BY t.created_time DESC
''');
    final args = <Object?>[aiAnalysisTypeToStorage(analysisType)];
    if (limit != null && limit > 0) {
      sql.write('LIMIT ?;\n');
      args.add(limit);
    } else {
      sql.write(';\n');
    }
    final rows = await db.rawQuery(sql.toString(), args);
    return rows
        .map(
          (row) => AiSavedAnalysisHistoryEntry(
            taskId: (row['task_id'] as int?) ?? 0,
            taskUid: (row['task_uid'] as String?) ?? '',
            status: aiTaskStatusFromStorage(
              (row['status'] as String?) ?? 'failed',
            ),
            summary: (row['summary'] as String?) ?? '',
            promptTemplate: (row['prompt_template'] as String?) ?? '',
            rangeStart: (row['range_start'] as int?) ?? 0,
            rangeEndExclusive: (row['range_end_exclusive'] as int?) ?? 0,
            includePublic: ((row['include_public'] as int?) ?? 1) == 1,
            includePrivate: ((row['include_private'] as int?) ?? 0) == 1,
            includeProtected: ((row['include_protected'] as int?) ?? 0) == 1,
            createdTime: (row['created_time'] as int?) ?? 0,
            isStale: ((row['is_stale'] as int?) ?? 0) == 1,
            templateKind: aiAnalysisTemplateKindFromStorage(
              (row['template_kind'] as String?) ?? '',
            ),
            templateId: (row['template_id'] as String?) ?? '',
            templateTitleSnapshot:
                (row['template_title_snapshot'] as String?) ?? '',
            templateIconKeySnapshot:
                (row['template_icon_key_snapshot'] as String?) ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<AiSavedAnalysisReport?> loadAnalysisReportByTaskId(int taskId) async {
    if (taskId <= 0) return null;
    final db = await _db;
    final rows = await db.rawQuery(
      '''
SELECT
  t.id AS task_id,
  t.task_uid,
  t.status,
  r.id AS result_id,
  r.summary,
  r.follow_up_suggestions_json,
  r.is_stale
FROM ai_analysis_tasks t
JOIN ai_analysis_results r ON r.task_id = t.id
WHERE t.id = ?
LIMIT 1;
''',
      <Object?>[taskId],
    );
    final taskRow = _firstOrNull(rows);
    if (taskRow == null) return null;
    return _hydrateAnalysisReportFromJoinedRow(taskRow);
  }

  Future<AiSavedAnalysisReport> _hydrateAnalysisReportFromJoinedRow(
    Map<String, Object?> taskRow,
  ) async {
    final db = await _db;
    final taskId = (taskRow['task_id'] as int?) ?? 0;
    final resultId = (taskRow['result_id'] as int?) ?? 0;
    final sectionRows = await db.query(
      'ai_analysis_sections',
      where: 'result_id = ?',
      whereArgs: <Object?>[resultId],
      orderBy: 'section_order ASC, id ASC',
    );
    final evidenceRows = await db.query(
      'ai_analysis_evidences',
      where: 'result_id = ?',
      whereArgs: <Object?>[resultId],
      orderBy: 'section_id ASC, evidence_order ASC, id ASC',
    );
    final sectionIdToKey = <int, String>{
      for (final row in sectionRows)
        ((row['id'] as int?) ?? 0): ((row['section_key'] as String?) ?? ''),
    };
    final sections = sectionRows
        .map((row) {
          final sectionId = (row['id'] as int?) ?? 0;
          final relatedKeys = evidenceRows
              .where(
                (evidence) =>
                    ((evidence['section_id'] as int?) ?? 0) == sectionId,
              )
              .map((evidence) => 'e${(evidence['id'] as int?) ?? 0}')
              .toList(growable: false);
          return AiAnalysisSectionData(
            sectionKey: (row['section_key'] as String?) ?? '',
            title: (row['title'] as String?) ?? '',
            body: (row['body'] as String?) ?? '',
            evidenceKeys: relatedKeys,
          );
        })
        .toList(growable: false);
    final evidences = <AiAnalysisEvidenceData>[];
    for (final row in evidenceRows) {
      evidences.add(
        AiAnalysisEvidenceData(
          evidenceKey: 'e${(row['id'] as int?) ?? 0}',
          sectionKey: sectionIdToKey[(row['section_id'] as int?) ?? 0] ?? '',
          memoUid: (row['memo_uid'] as String?) ?? '',
          chunkId: (row['chunk_id'] as int?) ?? 0,
          quoteText: (row['quote_text'] as String?) ?? '',
          charStart: (row['char_start'] as int?) ?? 0,
          charEnd: (row['char_end'] as int?) ?? 0,
          relevanceScore: ((row['relevance_score'] as num?) ?? 0).toDouble(),
        ),
      );
    }
    final suggestionsJson =
        (taskRow['follow_up_suggestions_json'] as String?) ?? '[]';
    List<String> suggestions = const <String>[];
    try {
      final decoded = jsonDecode(suggestionsJson);
      if (decoded is List) {
        suggestions = decoded
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
    return AiSavedAnalysisReport(
      taskId: taskId,
      taskUid: (taskRow['task_uid'] as String?) ?? '',
      status: aiTaskStatusFromStorage(
        (taskRow['status'] as String?) ?? 'failed',
      ),
      summary: (taskRow['summary'] as String?) ?? '',
      sections: sections,
      evidences: evidences,
      followUpSuggestions: suggestions,
      isStale: ((taskRow['is_stale'] as int?) ?? 0) == 1,
    );
  }
}

AiAnalysisType aiAnalysisTypeFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'emotion_map' => AiAnalysisType.emotionMap,
    _ => AiAnalysisType.emotionMap,
  };
}

T? _firstOrNull<T>(Iterable<T> values) {
  if (values.isEmpty) return null;
  return values.first;
}

Map<String, dynamic> _serializeChunkDraft(AiChunkDraft chunk) =>
    <String, dynamic>{
      'chunkIndex': chunk.chunkIndex,
      'content': chunk.content,
      'contentHash': chunk.contentHash,
      'memoContentHash': chunk.memoContentHash,
      'charStart': chunk.charStart,
      'charEnd': chunk.charEnd,
      'tokenEstimate': chunk.tokenEstimate,
      'memoCreateTime': chunk.memoCreateTime,
      'memoUpdateTime': chunk.memoUpdateTime,
      'memoVisibility': chunk.memoVisibility,
    };

Map<String, dynamic> _serializeStructuredAnalysisResult(
  AiStructuredAnalysisResult result,
) => <String, dynamic>{
  'schemaVersion': result.schemaVersion,
  'analysisType': aiAnalysisTypeToStorage(result.analysisType),
  'summary': result.summary,
  'sections': result.sections
      .map((item) => item.toJson())
      .toList(growable: false),
  'evidences': result.evidences
      .map((item) => item.toJson())
      .toList(growable: false),
  'followUpSuggestions': result.followUpSuggestions,
  'rawResponseText': result.rawResponseText,
};

AiStructuredAnalysisResult _readStructuredAnalysisResultPayload(
  Map<String, dynamic> payload,
  String key,
) {
  final raw = payload[key];
  if (raw is! Map) {
    throw FormatException('Missing $key payload.');
  }
  final map = Map<Object?, Object?>.from(raw).map<String, dynamic>(
    (entryKey, value) => MapEntry(entryKey.toString(), value),
  );
  final sections = _readMapListValue(map['sections'])
      .map(
        (item) => AiAnalysisSectionData(
          sectionKey: item['section_key'] as String? ?? '',
          title: item['title'] as String? ?? '',
          body: item['body'] as String? ?? '',
          evidenceKeys: _readStringListValue(item['evidence_keys']),
        ),
      )
      .toList(growable: false);
  final evidences = _readMapListValue(map['evidences'])
      .map(
        (item) => AiAnalysisEvidenceData(
          evidenceKey: item['evidence_key'] as String? ?? '',
          sectionKey: item['section_key'] as String? ?? '',
          memoUid: item['memo_uid'] as String? ?? '',
          chunkId: _readInt(item['chunk_id']) ?? 0,
          quoteText: item['quote_text'] as String? ?? '',
          charStart: _readInt(item['char_start']) ?? 0,
          charEnd: _readInt(item['char_end']) ?? 0,
          relevanceScore: _readDouble(item['relevance_score']) ?? 0,
        ),
      )
      .toList(growable: false);
  return AiStructuredAnalysisResult(
    schemaVersion: _readInt(map['schemaVersion']) ?? 0,
    analysisType: aiAnalysisTypeFromStorage(
      map['analysisType'] as String? ?? '',
    ),
    summary: map['summary'] as String? ?? '',
    sections: sections,
    evidences: evidences,
    followUpSuggestions: _readStringListValue(map['followUpSuggestions']),
    rawResponseText: map['rawResponseText'] as String? ?? '',
  );
}

AiEmbeddingProfile _readEmbeddingProfilePayload(
  Map<String, dynamic> payload,
  String key,
) {
  final raw = payload[key];
  if (raw is! Map) {
    throw FormatException('Missing $key payload.');
  }
  return AiEmbeddingProfile.fromJson(
    Map<Object?, Object?>.from(raw).map<String, dynamic>(
      (entryKey, value) => MapEntry(entryKey.toString(), value),
    ),
  );
}

List<AiChunkDraft> _readChunkDraftListPayload(
  Map<String, dynamic> payload,
  String key,
) {
  final raw = payload[key];
  if (raw is! List) return const <AiChunkDraft>[];
  final result = <AiChunkDraft>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<Object?, Object?>.from(item).map<String, dynamic>(
      (entryKey, value) => MapEntry(entryKey.toString(), value),
    );
    result.add(
      AiChunkDraft(
        chunkIndex: _readInt(map['chunkIndex']) ?? 0,
        content: map['content'] as String? ?? '',
        contentHash: map['contentHash'] as String? ?? '',
        memoContentHash: map['memoContentHash'] as String? ?? '',
        charStart: _readInt(map['charStart']) ?? 0,
        charEnd: _readInt(map['charEnd']) ?? 0,
        tokenEstimate: _readInt(map['tokenEstimate']) ?? 0,
        memoCreateTime: _readInt(map['memoCreateTime']) ?? 0,
        memoUpdateTime: _readInt(map['memoUpdateTime']) ?? 0,
        memoVisibility: map['memoVisibility'] as String? ?? '',
      ),
    );
  }
  return result;
}

Map<String, dynamic> _readStringDynamicMapPayload(
  Map<String, dynamic> payload,
  String key,
) {
  final raw = payload[key];
  if (raw is! Map) return const <String, dynamic>{};
  return Map<Object?, Object?>.from(raw).map<String, dynamic>(
    (entryKey, value) => MapEntry(entryKey.toString(), value),
  );
}

Float32List? _readFloat32VectorPayload(
  Map<String, dynamic> payload,
  String key,
) {
  final raw = payload[key];
  if (raw is! List || raw.isEmpty) return null;
  final values = raw
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  if (values.isEmpty) return null;
  return Float32List.fromList(values);
}

List<int> _readIntList(Object? raw) {
  if (raw is! List) return const <int>[];
  return raw.map(_readInt).whereType<int>().toList(growable: false);
}

List<String> _readStringListValue(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<Map<String, dynamic>> _readMapListValue(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  final result = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    result.add(
      Map<Object?, Object?>.from(item).map<String, dynamic>(
        (entryKey, value) => MapEntry(entryKey.toString(), value),
      ),
    );
  }
  return result;
}

String _requiredString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  throw FormatException('Missing or invalid $key.');
}

int _requiredInt(Map<String, dynamic> payload, String key) {
  final value = _readInt(payload[key]);
  if (value != null) return value;
  throw FormatException('Missing or invalid $key.');
}

int? _optionalInt(Map<String, dynamic> payload, String key) {
  return _readInt(payload[key]);
}

bool _readBoolPayload(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return false;
}

int? _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

double? _readDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}
