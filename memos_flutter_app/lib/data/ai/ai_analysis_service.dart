import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../../core/uid.dart';
import '../models/app_preferences.dart';
import '../models/content_fingerprint.dart';
import '../repositories/ai_settings_repository.dart';
import 'ai_analysis_models.dart';
import 'ai_analysis_repository.dart';
import 'ai_task_runtime.dart';

@visibleForTesting
bool looksLikeGeneratedAiSummaryMemo(String content) {
  final normalized = content.replaceAll('\r\n', '\n').trimLeft();
  if (normalized.isEmpty) {
    return false;
  }

  const headerMarkers = <String>[
    '# 本阶段回信',
    '# Letter Back',
    '# AI Summary Report',
    '# AI 洞察',
  ];
  for (final marker in headerMarkers) {
    if (normalized.startsWith(marker)) {
      return true;
    }
  }

  var signalCount = 0;
  const contentSignals = <String>[
    '这封回信参考了这些片段',
    'This letter drew on these note fragments',
    '关键洞察',
    'Key Insights',
    '情绪趋势:',
    'Mood Trend:',
  ];
  for (final signal in contentSignals) {
    if (normalized.contains(signal)) {
      signalCount += 1;
      if (signalCount >= 2) {
        return true;
      }
    }
  }
  return false;
}

class AiAnalysisService {
  AiAnalysisService({
    required AiAnalysisRepository repository,
    AiTaskRuntime? runtime,
    AiSettings Function()? readCurrentSettings,
    Dio? dio,
  }) : _repository = repository,
       _runtime = runtime,
       _readCurrentSettings = readCurrentSettings,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 60),
               sendTimeout: const Duration(seconds: 60),
               receiveTimeout: const Duration(seconds: 180),
             ),
           );

  static const _candidateChunkLimit = 3000;
  static const _topChunksPerIntent = 8;
  static const _maxMergedChunks = 20;
  static const _maxChunksPerMemo = 3;
  static const _maxRetrievalThreads = 2;
  static const _maxThreadSupportChunks = 6;
  static const _maxChunksPerMemoPerThread = 2;
  static const _minDistinctMemosPerThread = 3;
  static const _maxConsecutiveEmbeddingFailures = 5;
  static const _schemaVersion = 2;
  static const _maxNarrativeSections = 4;
  static const _analysisMaxOutputTokens = 2200;

  final AiAnalysisRepository _repository;
  final AiTaskRuntime? _runtime;
  final AiSettings Function()? _readCurrentSettings;
  final Dio _dio;

  Future<AiRetrievalPreviewPayload> buildEmotionMapPreview({
    required AppLanguage language,
    required AiSettings settings,
    required DateTimeRange range,
    bool includePublic = true,
    required bool includePrivate,
    bool includeProtected = false,
  }) async {
    final effectiveSettings = _currentSettings(settings);
    final startTimeSec = _rangeStart(range);
    final endTimeSecExclusive = _rangeEndExclusive(range);
    final embeddingProfile = _resolveEmbeddingProfile(effectiveSettings);
    final embeddingFailureGuard = _EmbeddingFailureGuard(language: language);

    if (embeddingProfile == null ||
        embeddingProfile.baseUrl.trim().isEmpty ||
        embeddingProfile.model.trim().isEmpty) {
      final memoRows = await _repository.listMemoRowsForAi(
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
      );
      final filtered = memoRows.where(
        (row) => _memoRowAllowed(
          row,
          includePublic: includePublic,
          includePrivate: includePrivate,
          includeProtected: includeProtected,
        ),
      );
      return AiRetrievalPreviewPayload(
        totalMatchingMemos: filtered.length,
        candidateChunks: 0,
        embeddingReady: 0,
        embeddingPending: 0,
        embeddingFailed: 0,
        isSampled: false,
        items: const <AiRetrievalPreviewItem>[],
      );
    }

    await _ensureIndexesForRange(
      language: language,
      settings: effectiveSettings,
      profile: embeddingProfile,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      failureGuard: embeddingFailureGuard,
    );

    final counts = await _repository.countCandidateChunkStatuses(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
      baseUrl: embeddingProfile.baseUrl,
      model: embeddingProfile.model,
    );
    final sampleRows = await _repository.listPreviewSampleChunks(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
      baseUrl: embeddingProfile.baseUrl,
      model: embeddingProfile.model,
      limit: 5,
    );

    final items = sampleRows
        .map((row) => _previewItemFromRow(row))
        .toList(growable: false);
    final candidateChunks = (counts['chunk_count'] as int?) ?? 0;
    return AiRetrievalPreviewPayload(
      totalMatchingMemos: (counts['memo_count'] as int?) ?? 0,
      candidateChunks: candidateChunks,
      embeddingReady: (counts['ready_count'] as int?) ?? 0,
      embeddingPending: (counts['pending_count'] as int?) ?? 0,
      embeddingFailed: (counts['failed_count'] as int?) ?? 0,
      isSampled: candidateChunks >= _candidateChunkLimit,
      items: items,
    );
  }

  Future<AiSavedAnalysisReport> generateEmotionMap({
    required AppLanguage language,
    required AiSettings settings,
    required DateTimeRange range,
    bool includePublic = true,
    required bool includePrivate,
    bool includeProtected = false,
    String promptTemplate = '',
    void Function(double progress)? onProgress,
  }) async {
    void reportProgress(double value) {
      final normalized = value.clamp(0.0, 1.0);
      onProgress?.call(normalized);
    }

    reportProgress(0.06);
    final effectiveSettings = _currentSettings(settings);
    final generationProfile = _resolveGenerationProfile(effectiveSettings);
    final embeddingProfile = _resolveEmbeddingProfile(effectiveSettings);
    final hasEmbeddingConfig =
        embeddingProfile != null &&
        embeddingProfile.baseUrl.trim().isNotEmpty &&
        embeddingProfile.model.trim().isNotEmpty;
    final embeddingFailureGuard = _EmbeddingFailureGuard(language: language);
    if (generationProfile == null ||
        generationProfile.baseUrl.trim().isEmpty ||
        generationProfile.model.trim().isEmpty) {
      throw StateError(
        _generationConfigurationError(
          language: language,
          hasEmbeddingConfig: hasEmbeddingConfig,
        ),
      );
    }

    final startTimeSec = _rangeStart(range);
    final endTimeSecExclusive = _rangeEndExclusive(range);
    reportProgress(0.18);
    if (hasEmbeddingConfig) {
      await _ensureIndexesForRange(
        language: language,
        settings: effectiveSettings,
        profile: embeddingProfile,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        failureGuard: embeddingFailureGuard,
      );
    }
    reportProgress(0.34);

    final taskUid = generateUid();
    final taskId = await _repository.createAnalysisTask(
      taskUid: taskUid,
      analysisType: AiAnalysisType.emotionMap,
      status: AiTaskStatus.draft,
      rangeStart: startTimeSec,
      rangeEndExclusive: endTimeSecExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
      promptTemplate: promptTemplate.trim(),
      generationProfileKey: generationProfile.profileKey,
      embeddingProfileKey: hasEmbeddingConfig
          ? embeddingProfile.profileKey
          : '',
      retrievalProfile: <String, dynamic>{
        'candidate_limit': _candidateChunkLimit,
        'top_per_intent': _topChunksPerIntent,
        'max_merged_chunks': _maxMergedChunks,
        'max_chunks_per_memo': _maxChunksPerMemo,
        'max_threads': _maxRetrievalThreads,
        'max_thread_support_chunks': _maxThreadSupportChunks,
        'max_chunks_per_memo_per_thread': _maxChunksPerMemoPerThread,
        'min_distinct_memos_per_thread': _minDistinctMemosPerThread,
        'threaded_retrieval': hasEmbeddingConfig,
        'retrieval_mode': hasEmbeddingConfig ? 'embedding' : 'direct',
        'degraded_without_embedding': !hasEmbeddingConfig,
        'include_public': includePublic,
        'include_private': includePrivate,
        'include_protected': includeProtected,
      },
    );

    try {
      reportProgress(0.42);
      await _repository.updateAnalysisTaskStatus(
        taskId,
        status: AiTaskStatus.queued,
      );
      await _repository.updateAnalysisTaskStatus(
        taskId,
        status: AiTaskStatus.retrieving,
      );
      final retrieval = hasEmbeddingConfig
          ? await _retrieveEmotionMapEvidence(
              language: language,
              settings: effectiveSettings,
              profile: embeddingProfile,
              startTimeSec: startTimeSec,
              endTimeSecExclusive: endTimeSecExclusive,
              includePublic: includePublic,
              includePrivate: includePrivate,
              includeProtected: includeProtected,
              failureGuard: embeddingFailureGuard,
            )
          : await _buildDirectEmotionMapEvidence(
              language: language,
              startTimeSec: startTimeSec,
              endTimeSecExclusive: endTimeSecExclusive,
              includePublic: includePublic,
              includePrivate: includePrivate,
              includeProtected: includeProtected,
            );
      reportProgress(0.68);
      if (retrieval.candidates.isEmpty) {
        throw StateError(
          trByLanguage(
            language: language,
            zh: '当前时间范围内没有可用于分析的证据片段。',
            en: 'No evidence chunks are available for this analysis range.',
          ),
        );
      }

      await _repository.updateAnalysisTaskStatus(
        taskId,
        status: AiTaskStatus.generating,
      );
      reportProgress(0.78);
      final structured = await _generateEmotionMapResult(
        language: language,
        settings: effectiveSettings,
        generationProfile: generationProfile,
        retrieval: retrieval,
        promptTemplate: promptTemplate,
        range: range,
      );
      reportProgress(0.92);
      await _repository.saveAnalysisResult(taskId: taskId, result: structured);
      await _repository.updateAnalysisTaskStatus(
        taskId,
        status: AiTaskStatus.completed,
        markCompleted: true,
      );
      reportProgress(1.0);
      return (await _repository.loadLatestAnalysisReport(
            analysisType: AiAnalysisType.emotionMap,
          )) ??
          AiSavedAnalysisReport(
            taskId: taskId,
            taskUid: taskUid,
            status: AiTaskStatus.completed,
            summary: structured.summary,
            sections: structured.sections,
            evidences: structured.evidences,
            followUpSuggestions: structured.followUpSuggestions,
            isStale: false,
          );
    } catch (error) {
      await _repository.updateAnalysisTaskStatus(
        taskId,
        status: AiTaskStatus.failed,
        errorText: error.toString(),
      );
      rethrow;
    }
  }

  String _generationConfigurationError({
    required AppLanguage language,
    required bool hasEmbeddingConfig,
  }) {
    if (!hasEmbeddingConfig) {
      return trByLanguage(
        language: language,
        zh: 'AI 还没有配置，请先配置可用的聊天模型。',
        en: 'AI is not configured yet. Please configure a working chat model first.',
      );
    }
    return trByLanguage(
      language: language,
      zh: '请先配置可用的聊天模型。',
      en: 'Please configure a generation model first.',
    );
  }

  Future<void> _ensureIndexesForRange({
    required AppLanguage language,
    required AiSettings settings,
    required AiEmbeddingProfile profile,
    required int startTimeSec,
    required int endTimeSecExclusive,
    _EmbeddingFailureGuard? failureGuard,
  }) async {
    final memoRows = await _repository.listMemoRowsForAi(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
    );
    for (final row in memoRows) {
      final memoUid = (row['uid'] as String?)?.trim() ?? '';
      if (memoUid.isEmpty) continue;
      if (looksLikeGeneratedAiSummaryMemo((row['content'] as String?) ?? '')) {
        await _repository.upsertMemoPolicy(memoUid: memoUid, allowAi: false);
        await _repository.invalidateActiveChunksForMemo(memoUid);
        continue;
      }
      final allowAi = ((row['allow_ai'] as int?) ?? 1) == 1;
      if (!allowAi) {
        await _repository.invalidateActiveChunksForMemo(memoUid);
        continue;
      }
      final memoContentHash = _computeMemoContentHash(row);
      final hasFreshIndex = await _repository.memoHasFreshIndex(
        memoUid: memoUid,
        memoContentHash: memoContentHash,
        baseUrl: profile.baseUrl,
        model: profile.model,
      );
      if (hasFreshIndex) continue;
      await _repository.enqueueIndexJob(
        memoUid: memoUid,
        reason: AiIndexJobReason.memoUpdated,
        memoContentHash: memoContentHash,
        embeddingProfileKey: profile.profileKey,
      );
    }
    await _processPendingIndexJobs(
      language: language,
      settings: settings,
      profile: profile,
      failureGuard: failureGuard,
    );
  }

  Future<void> _processPendingIndexJobs({
    required AppLanguage language,
    required AiSettings settings,
    required AiEmbeddingProfile profile,
    _EmbeddingFailureGuard? failureGuard,
  }) async {
    final jobs = await _repository.listPendingIndexJobs(
      embeddingProfileKey: profile.profileKey,
      limit: 200,
    );
    for (final job in jobs) {
      final jobId = (job['id'] as int?) ?? 0;
      final memoUid = (job['memo_uid'] as String?)?.trim() ?? '';
      if (jobId <= 0 || memoUid.isEmpty) continue;
      final attemptCount = ((job['attempt_count'] as int?) ?? 0) + 1;
      await _repository.updateIndexJobStatus(
        jobId,
        status: AiIndexJobStatus.running,
        attemptCount: attemptCount,
        markStarted: true,
      );
      try {
        await _rebuildMemoIndex(
          memoUid: memoUid,
          language: language,
          settings: settings,
          profile: profile,
          failureGuard: failureGuard,
        );
        await _repository.updateIndexJobStatus(
          jobId,
          status: AiIndexJobStatus.completed,
          attemptCount: attemptCount,
          markFinished: true,
        );
      } catch (error) {
        await _repository.updateIndexJobStatus(
          jobId,
          status: AiIndexJobStatus.failed,
          attemptCount: attemptCount,
          errorText: error.toString(),
          markFinished: true,
        );
        if (error is _EmbeddingFailureCutoffException ||
            error is _EmbeddingConfigurationChangedException) {
          rethrow;
        }
      }
    }
  }

  Future<void> _rebuildMemoIndex({
    required String memoUid,
    required AppLanguage language,
    required AiSettings settings,
    required AiEmbeddingProfile profile,
    _EmbeddingFailureGuard? failureGuard,
  }) async {
    final memoRow = await _repository.getMemoRowForAi(memoUid);
    if (memoRow == null) {
      await _repository.invalidateActiveChunksForMemo(memoUid);
      return;
    }
    final allowAi = ((memoRow['allow_ai'] as int?) ?? 1) == 1;
    final state =
        (memoRow['state'] as String?)?.trim().toUpperCase() ?? 'NORMAL';
    if (!allowAi ||
        state != 'NORMAL' ||
        looksLikeGeneratedAiSummaryMemo(
          (memoRow['content'] as String?) ?? '',
        )) {
      await _repository.invalidateActiveChunksForMemo(memoUid);
      return;
    }

    final chunks = _chunkMemo(memoRow);
    if (chunks.isEmpty) {
      await _repository.invalidateActiveChunksForMemo(memoUid);
      return;
    }

    final embeddingResults = <_EmbeddingBuildResult>[];
    Object? firstFailure;
    Object? fatalFailure;
    for (final chunk in chunks) {
      try {
        final vector = await _createEmbedding(
          language: language,
          settings: settings,
          profile: profile,
          input: chunk.content,
          failureGuard: failureGuard,
        );
        embeddingResults.add(
          _EmbeddingBuildResult(
            status: AiEmbeddingStatus.ready,
            vector: vector,
          ),
        );
      } catch (error) {
        firstFailure ??= error;
        embeddingResults.add(
          _EmbeddingBuildResult(
            status: AiEmbeddingStatus.failed,
            errorText: error.toString(),
          ),
        );
        if (error is _EmbeddingFailureCutoffException ||
            error is _EmbeddingConfigurationChangedException) {
          fatalFailure = error;
          break;
        }
      }
    }

    if (fatalFailure != null && embeddingResults.length < chunks.length) {
      final remainingCount = chunks.length - embeddingResults.length;
      for (var index = 0; index < remainingCount; index++) {
        embeddingResults.add(
          _EmbeddingBuildResult(
            status: AiEmbeddingStatus.failed,
            errorText: fatalFailure.toString(),
          ),
        );
      }
    }

    await _repository.invalidateActiveChunksForMemo(memoUid);
    final chunkIds = await _repository.insertActiveChunks(
      memoUid: memoUid,
      chunks: chunks,
    );
    for (
      var index = 0;
      index < math.min(chunkIds.length, embeddingResults.length);
      index++
    ) {
      final record = embeddingResults[index];
      await _repository.insertEmbeddingRecord(
        chunkId: chunkIds[index],
        profile: profile,
        status: record.status,
        vector: record.vector,
        errorText: record.errorText,
      );
    }
    if (fatalFailure != null) {
      throw fatalFailure;
    }
    if (firstFailure != null) {
      throw StateError(firstFailure.toString());
    }
  }

  Future<_RetrievalBundle> _retrieveEmotionMapEvidence({
    required AppLanguage language,
    required AiSettings settings,
    required AiEmbeddingProfile profile,
    required int startTimeSec,
    required int endTimeSecExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
    _EmbeddingFailureGuard? failureGuard,
  }) async {
    final rows = await _repository.listCandidateChunkRows(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
      baseUrl: profile.baseUrl,
      model: profile.model,
      limit: _candidateChunkLimit,
    );
    final candidates = rows
        .map(_candidateChunkFromRow)
        .where(
          (item) =>
              item.embeddingStatus == AiEmbeddingStatus.ready &&
              item.vector != null,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return const _RetrievalBundle(
        mode: 'embedding',
        candidates: <AiEvidenceCandidate>[],
        threads: <_RetrievalThreadBundle>[],
      );
    }

    final intents = _emotionMapIntents(language);
    final scoredByIntent = <String, List<_ScoredChunk>>{};
    for (final intent in intents) {
      final queryVector = await _createEmbedding(
        language: language,
        settings: settings,
        profile: profile,
        input: intent.query,
        failureGuard: failureGuard,
      );
      final scored =
          candidates
              .map(
                (item) => _ScoredChunk(
                  item: item,
                  score: _cosineSimilarity(queryVector, item.vector!),
                ),
              )
              .where((entry) => entry.score > 0)
              .toList(growable: false)
            ..sort((a, b) => b.score.compareTo(a.score));
      scoredByIntent[intent.sectionKey] = scored;
    }

    final rankedThemes =
        intents
            .map(
              (intent) => _RetrievalThemePlan(
                intent: intent,
                strength: _themeStrength(
                  scoredByIntent[intent.sectionKey] ?? const [],
                ),
              ),
            )
            .where((plan) => plan.strength > 0)
            .toList(growable: false)
          ..sort((a, b) => b.strength.compareTo(a.strength));

    final usedChunkIds = <int>{};
    final globalMemoCount = <String, int>{};
    final collected = <AiEvidenceCandidate>[];
    final threads = <_RetrievalThreadBundle>[];
    var evidenceCounter = 0;

    for (final plan in rankedThemes) {
      if (threads.length >= _maxRetrievalThreads ||
          collected.length >= _maxMergedChunks) {
        break;
      }
      final sectionKey = threads.isEmpty ? 'main_thread' : 'secondary_thread';
      final support = _selectThreadSupport(
        scoredEntries: scoredByIntent[plan.intent.sectionKey] ?? const [],
        usedChunkIds: usedChunkIds,
        globalMemoCount: globalMemoCount,
      );
      if (support.isEmpty) {
        continue;
      }

      final threadEvidences = <AiEvidenceCandidate>[];
      for (final entry in support) {
        if (collected.length >= _maxMergedChunks) {
          break;
        }
        evidenceCounter += 1;
        final evidence = AiEvidenceCandidate(
          evidenceKey: 'e$evidenceCounter',
          sectionKey: sectionKey,
          threadKey: sectionKey,
          sourceThemeKey: plan.intent.sectionKey,
          memoUid: entry.item.memoUid,
          chunkId: entry.item.chunkId,
          quoteText: entry.item.content,
          charStart: entry.item.charStart,
          charEnd: entry.item.charEnd,
          relevanceScore: entry.score,
          memoCreateTime: entry.item.memoCreateTime,
          memoVisibility: entry.item.memoVisibility,
        );
        usedChunkIds.add(entry.item.chunkId);
        globalMemoCount[entry.item.memoUid] =
            (globalMemoCount[entry.item.memoUid] ?? 0) + 1;
        threadEvidences.add(evidence);
        collected.add(evidence);
      }

      if (threadEvidences.isNotEmpty) {
        threads.add(
          _RetrievalThreadBundle(
            threadKey: sectionKey,
            sourceThemeKey: plan.intent.sectionKey,
            evidences: threadEvidences,
            strength: plan.strength,
          ),
        );
      }
    }

    return _RetrievalBundle(
      mode: 'embedding',
      candidates: collected,
      threads: threads,
    );
  }

  Future<_RetrievalBundle> _buildDirectEmotionMapEvidence({
    required AppLanguage language,
    required int startTimeSec,
    required int endTimeSecExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
  }) async {
    final rows = await _repository.listMemoRowsForAi(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
    );
    final filteredRows =
        rows
            .where(
              (row) => _memoRowAllowed(
                row,
                includePublic: includePublic,
                includePrivate: includePrivate,
                includeProtected: includeProtected,
              ),
            )
            .toList(growable: false)
          ..sort(
            (left, right) =>
                _memoSortTimestamp(right).compareTo(_memoSortTimestamp(left)),
          );

    final chunkRows =
        <({String memoUid, List<AiChunkDraft> chunks, List<int> chunkIds})>[];
    for (final row in filteredRows) {
      final memoUid = ((row['uid'] as String?) ?? '').trim();
      if (memoUid.isEmpty) {
        continue;
      }
      final chunks = _chunkMemo(row);
      if (chunks.isEmpty) {
        continue;
      }
      final chunkIds = await _repository.insertActiveChunks(
        memoUid: memoUid,
        chunks: chunks,
      );
      if (chunkIds.isEmpty) {
        continue;
      }
      chunkRows.add((memoUid: memoUid, chunks: chunks, chunkIds: chunkIds));
    }

    final candidates = <AiEvidenceCandidate>[];
    var evidenceCounter = 0;

    for (
      var round = 0;
      round < _maxChunksPerMemo && candidates.length < _maxMergedChunks;
      round++
    ) {
      for (var memoIndex = 0; memoIndex < chunkRows.length; memoIndex++) {
        if (candidates.length >= _maxMergedChunks) {
          break;
        }
        final chunkRow = chunkRows[memoIndex];
        if (chunkRow.chunks.length <= round) {
          continue;
        }
        final chunk = chunkRow.chunks[round];
        evidenceCounter += 1;
        candidates.add(
          AiEvidenceCandidate(
            evidenceKey: 'e$evidenceCounter',
            sectionKey: 'main_thread',
            threadKey: 'main_thread',
            threadHint: _directRetrievalThreadHint(language),
            sourceThemeKey: 'direct_reading',
            memoUid: chunkRow.memoUid,
            chunkId: chunkRow.chunkIds[round],
            quoteText: chunk.content,
            charStart: chunk.charStart,
            charEnd: chunk.charEnd,
            relevanceScore: _directRetrievalScore(
              memoIndex: memoIndex,
              round: round,
              contentLength: chunk.content.length,
            ),
            memoCreateTime: chunk.memoCreateTime,
            memoVisibility: chunk.memoVisibility,
          ),
        );
      }
    }

    if (candidates.isEmpty) {
      return const _RetrievalBundle(
        mode: 'direct',
        candidates: <AiEvidenceCandidate>[],
        threads: <_RetrievalThreadBundle>[],
      );
    }

    return _RetrievalBundle(
      mode: 'direct',
      candidates: candidates,
      threads: <_RetrievalThreadBundle>[
        _RetrievalThreadBundle(
          threadKey: 'main_thread',
          sourceThemeKey: 'direct_reading',
          evidences: candidates,
          strength: 1.0,
        ),
      ],
    );
  }

  Future<AiStructuredAnalysisResult> _generateEmotionMapResult({
    required AppLanguage language,
    required AiSettings settings,
    required AiGenerationProfile generationProfile,
    required _RetrievalBundle retrieval,
    required String promptTemplate,
    required DateTimeRange range,
  }) async {
    final candidates = retrieval.candidates;
    final candidateMap = <String, AiEvidenceCandidate>{
      for (final item in candidates) item.evidenceKey: item,
    };
    Object? lastError;
    String? previousOutput;
    for (var attempt = 0; attempt < 2; attempt++) {
      final rawResponse = await _callGenerationBackend(
        language: language,
        settings: settings,
        routeId: AiTaskRouteId.analysisReport,
        profile: generationProfile,
        systemPrompt: _buildSystemPrompt(language: language),
        userPrompt: _buildEmotionMapUserPrompt(
          language: language,
          settings: settings,
          retrieval: retrieval,
          promptTemplate: promptTemplate,
          range: range,
          attempt: attempt,
          previousOutput: previousOutput,
          previousError: lastError?.toString(),
        ),
      );
      previousOutput = rawResponse;
      try {
        final structured = _normalizeStructuredResult(
          rawResponseText: rawResponse,
          candidateMap: candidateMap,
        );
        final qualityFeedback = _emotionMapQualityFeedback(
          language: language,
          result: structured,
          candidateCount: candidates.length,
        );
        if (qualityFeedback != null && attempt == 0) {
          throw _NarrativeQualityIssue(qualityFeedback);
        }
        return structured;
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError(lastError.toString());
  }

  Future<String> _callGenerationBackend({
    required AppLanguage language,
    required AiSettings settings,
    required AiTaskRouteId routeId,
    required AiGenerationProfile profile,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final runtime = _runtime;
    if (runtime != null) {
      final runtimeRoute = runtime.resolveChatRoute(settings, routeId: routeId);
      if (runtimeRoute != null) {
        try {
          final result = await runtime.chatCompletion(
            settings: settings,
            routeId: routeId,
            systemPrompt: systemPrompt,
            temperature: 0.7,
            maxOutputTokens: _analysisMaxOutputTokens,
            messages: <AiChatMessage>[
              AiChatMessage(role: 'user', content: userPrompt),
            ],
          );
          final text = result.text.trim();
          if (text.isNotEmpty) {
            return text;
          }
          throw StateError(
            trByLanguage(
              language: language,
              zh: '生成接口返回为空。',
              en: 'Generation API returned empty content.',
            ),
          );
        } on UnsupportedError {
          final adapterKind = runtimeRoute.service.adapterKind;
          if (adapterKind != AiProviderAdapterKind.openAiCompatible &&
              adapterKind != AiProviderAdapterKind.anthropic) {
            rethrow;
          }
        }
      }
    }

    final normalizedBase = _normalizeBase(profile.baseUrl, ensureV1: true);
    if (profile.providerKind == AiProviderKind.anthropicCompatible) {
      final response = await _dio.post(
        _resolveEndpoint(normalizedBase, 'messages'),
        options: Options(
          headers: <String, Object?>{
            if (profile.apiKey.trim().isNotEmpty)
              'x-api-key': profile.apiKey.trim(),
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
        ),
        data: <String, Object?>{
          'model': profile.model,
          'max_tokens': _analysisMaxOutputTokens,
          'temperature': 0.7,
          'system': systemPrompt,
          'messages': [
            <String, Object?>{'role': 'user', 'content': userPrompt},
          ],
        },
      );
      final data = response.data;
      if (data is Map && data['content'] is List) {
        final buffer = StringBuffer();
        for (final item in data['content'] as List) {
          if (item is Map && item['text'] is String) {
            buffer.write(item['text']);
          }
        }
        final text = buffer.toString().trim();
        if (text.isNotEmpty) return text;
      }
      throw StateError(
        trByLanguage(
          language: language,
          zh: '生成接口返回为空。',
          en: 'Generation API returned empty content.',
        ),
      );
    }

    final response = await _dio.post(
      _resolveEndpoint(normalizedBase, 'chat/completions'),
      options: Options(
        headers: <String, Object?>{
          if (profile.apiKey.trim().isNotEmpty)
            'Authorization': 'Bearer ${profile.apiKey.trim()}',
          'Content-Type': 'application/json',
        },
      ),
      data: <String, Object?>{
        'model': profile.model,
        'max_tokens': _analysisMaxOutputTokens,
        'temperature': 0.7,
        'messages': [
          <String, Object?>{'role': 'system', 'content': systemPrompt},
          <String, Object?>{'role': 'user', 'content': userPrompt},
        ],
      },
    );
    final data = response.data;
    if (data is Map &&
        data['choices'] is List &&
        (data['choices'] as List).isNotEmpty) {
      final first = (data['choices'] as List).first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map && message['content'] is String) {
          return (message['content'] as String).trim();
        }
        if (first['text'] is String) {
          return (first['text'] as String).trim();
        }
      }
    }
    throw StateError(
      trByLanguage(
        language: language,
        zh: '生成接口返回为空。',
        en: 'Generation API returned empty content.',
      ),
    );
  }

  Future<Float32List> _createEmbedding({
    required AppLanguage language,
    required AiSettings settings,
    required AiEmbeddingProfile profile,
    required String input,
    _EmbeddingFailureGuard? failureGuard,
  }) async {
    final normalizedInput = input.trim();
    if (normalizedInput.isEmpty) {
      throw StateError('Empty embedding input');
    }
    final activeSettings = _currentSettings(settings);
    final activeProfile = _resolveEmbeddingProfile(activeSettings);
    if (activeProfile == null ||
        activeProfile.baseUrl.trim().isEmpty ||
        activeProfile.model.trim().isEmpty) {
      throw StateError(
        trByLanguage(
          language: language,
          zh: '请先配置可用的向量模型后再重试。',
          en: 'Please configure a working embedding model before trying again.',
        ),
      );
    }
    if (!_sameEmbeddingProfile(profile, activeProfile)) {
      throw _EmbeddingConfigurationChangedException(
        trByLanguage(
          language: language,
          zh: '检测到你刚刚修改了向量模型配置，本次分析已停止，避免继续混用旧向量。请重新开始分析。',
          en: 'Your embedding settings changed while analysis was running, so this run was stopped to avoid mixing old and new vectors. Please start the analysis again.',
        ),
      );
    }
    final runtime = _runtime;
    if (runtime != null) {
      final runtimeRoute = runtime.resolveEmbeddingRoute(activeSettings);
      if (runtimeRoute != null) {
        try {
          final vector = await runtime.embed(
            settings: activeSettings,
            input: normalizedInput,
          );
          if (vector.isNotEmpty) {
            failureGuard?.recordSuccess();
            return Float32List.fromList(vector);
          }
          throw StateError('Embedding API returned empty vector');
        } on UnsupportedError catch (error) {
          if (runtimeRoute.service.adapterKind !=
              AiProviderAdapterKind.openAiCompatible) {
            rethrow;
          }
          final cutoffError = failureGuard?.recordFailure(error);
          if (cutoffError != null) {
            throw cutoffError;
          }
        } catch (error) {
          final cutoffError = failureGuard?.recordFailure(error);
          if (cutoffError != null) {
            throw cutoffError;
          }
          rethrow;
        }
      }
    }
    try {
      final response = await _dio.post(
        _resolveEndpoint(
          _normalizeBase(activeProfile.baseUrl, ensureV1: true),
          'embeddings',
        ),
        options: Options(
          headers: <String, Object?>{
            if (activeProfile.apiKey.trim().isNotEmpty)
              'Authorization': 'Bearer ${activeProfile.apiKey.trim()}',
            'Content-Type': 'application/json',
          },
        ),
        data: <String, Object?>{
          'model': activeProfile.model,
          'input': normalizedInput,
        },
      );
      final data = response.data;
      if (data is Map &&
          data['data'] is List &&
          (data['data'] as List).isNotEmpty) {
        final first = (data['data'] as List).first;
        if (first is Map && first['embedding'] is List) {
          final raw = first['embedding'] as List;
          failureGuard?.recordSuccess();
          return Float32List.fromList(
            raw.map((item) => (item as num).toDouble()).toList(growable: false),
          );
        }
      }
      throw StateError('Embedding API returned empty vector');
    } catch (error) {
      if (error is _EmbeddingFailureCutoffException ||
          error is _EmbeddingConfigurationChangedException) {
        rethrow;
      }
      final cutoffError = failureGuard?.recordFailure(error);
      if (cutoffError != null) {
        throw cutoffError;
      }
      rethrow;
    }
  }

  AiStructuredAnalysisResult _normalizeStructuredResult({
    required String rawResponseText,
    required Map<String, AiEvidenceCandidate> candidateMap,
  }) {
    final decoded = _decodeJsonObject(rawResponseText);
    final analysisType = (decoded['analysis_type'] as String?)?.trim() ?? '';
    if (analysisType != 'emotion_map') {
      throw const FormatException('analysis_type must be emotion_map');
    }
    final schemaVersion = (decoded['schema_version'] as num?)?.toInt() ?? 1;
    final summary = ((decoded['summary'] as String?) ?? '').trim();
    if (summary.isEmpty) {
      throw const FormatException('summary missing');
    }
    final sectionsRaw = decoded['sections'];
    final followUpRaw = decoded['follow_up_suggestions'];
    final fallbackBody =
        ((decoded['body'] as String?) ??
                (decoded['letter'] as String?) ??
                (decoded['content'] as String?) ??
                '')
            .trim();

    final evidences = <AiAnalysisEvidenceData>[];
    final sections = <AiAnalysisSectionData>[];
    final rawSections = sectionsRaw is List
        ? sectionsRaw.whereType<Map>()
        : const <Map>[];
    for (final rawSection in rawSections) {
      if (sections.length >= _maxNarrativeSections) {
        break;
      }
      final title = ((rawSection['title'] as String?) ?? '').trim();
      final body = ((rawSection['body'] as String?) ?? '').trim();
      if (body.isEmpty) {
        continue;
      }
      final fallbackKey = switch (sections.length) {
        0 => 'main_thread',
        1 => 'secondary_thread',
        2 => 'leave_space',
        _ => 'section_${sections.length + 1}',
      };
      final sectionKey =
          ((rawSection['section_key'] as String?) ?? '').trim().isEmpty
          ? fallbackKey
          : ((rawSection['section_key'] as String?) ?? '').trim();
      final evidenceKeys =
          (rawSection['evidence_keys'] as List?)
              ?.whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .where(candidateMap.containsKey)
              .toSet()
              .toList(growable: false) ??
          const <String>[];
      sections.add(
        AiAnalysisSectionData(
          sectionKey: sectionKey,
          title: title,
          body: body,
          evidenceKeys: evidenceKeys,
        ),
      );
      for (final evidenceKey in evidenceKeys) {
        final candidate = candidateMap[evidenceKey];
        if (candidate == null) {
          continue;
        }
        evidences.add(
          AiAnalysisEvidenceData(
            evidenceKey: candidate.evidenceKey,
            sectionKey: sectionKey,
            memoUid: candidate.memoUid,
            chunkId: candidate.chunkId,
            quoteText: candidate.quoteText,
            charStart: candidate.charStart,
            charEnd: candidate.charEnd,
            relevanceScore: candidate.relevanceScore,
          ),
        );
      }
    }

    if (sections.isEmpty && fallbackBody.isNotEmpty) {
      sections.add(
        const AiAnalysisSectionData(
          sectionKey: 'main_thread',
          title: '',
          body: '',
          evidenceKeys: <String>[],
        ),
      );
      sections[0] = AiAnalysisSectionData(
        sectionKey: 'main_thread',
        title: '',
        body: fallbackBody,
        evidenceKeys: const <String>[],
      );
    }

    final suggestions = (followUpRaw is List)
        ? followUpRaw
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .take(6)
              .toList(growable: false)
        : const <String>[];

    return AiStructuredAnalysisResult(
      schemaVersion: schemaVersion <= 0 ? _schemaVersion : schemaVersion,
      analysisType: AiAnalysisType.emotionMap,
      summary: summary,
      sections: sections,
      evidences: _dedupeEvidences(evidences),
      followUpSuggestions: suggestions,
      rawResponseText: rawResponseText,
    );
  }

  List<AiAnalysisEvidenceData> _dedupeEvidences(
    List<AiAnalysisEvidenceData> items,
  ) {
    final seen = <String>{};
    final result = <AiAnalysisEvidenceData>[];
    for (final item in items) {
      final key = '${item.sectionKey}|${item.evidenceKey}';
      if (seen.add(key)) {
        result.add(item);
      }
    }
    return result;
  }

  String? _emotionMapQualityFeedback({
    required AppLanguage language,
    required AiStructuredAnalysisResult result,
    required int candidateCount,
  }) {
    final narrativeSections = result.sections
        .where((section) {
          final key = section.sectionKey.trim();
          return section.body.trim().isNotEmpty &&
              key != 'leave_space' &&
              key != 'closing';
        })
        .toList(growable: false);

    if (narrativeSections.isEmpty) {
      return trByLanguage(
        language: language,
        zh: '上一版正文太薄了。请至少展开一个完整主线，不要只有开场就结束。',
        en: 'The previous draft is too thin. Expand at least one full main thread instead of stopping after the opening.',
      );
    }

    final isEnglish = prefersEnglishFor(language);
    final summaryLength = _meaningfulCharCount(result.summary);
    final mainThreadLength = _meaningfulCharCount(narrativeSections.first.body);
    final secondaryThreadLength = narrativeSections.length >= 2
        ? _meaningfulCharCount(narrativeSections[1].body)
        : 0;
    final totalLength =
        summaryLength +
        narrativeSections.fold<int>(
          0,
          (sum, section) => sum + _meaningfulCharCount(section.body),
        );
    final referencedMemoCount = result.evidences
        .map((item) => item.memoUid.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .length;

    final minSummaryLength = isEnglish ? 140 : 60;
    final minMainThreadLength = isEnglish ? 220 : 95;
    final minSecondaryThreadLength = isEnglish ? 140 : 70;
    final minTotalLength = isEnglish ? 520 : 230;

    final issues = <String>[];
    if (summaryLength < minSummaryLength) {
      issues.add(
        trByLanguage(
          language: language,
          zh: '开场太短，像刚进入状态就停住了。',
          en: 'The opening is too short and stops before it settles in.',
        ),
      );
    }
    if (mainThreadLength < minMainThreadLength) {
      issues.add(
        trByLanguage(
          language: language,
          zh: '主线只点到名字，没有真正展开出层次。',
          en: 'The main thread names the idea but does not really unfold it.',
        ),
      );
    }
    if (narrativeSections.length >= 2 &&
        secondaryThreadLength < minSecondaryThreadLength) {
      issues.add(
        trByLanguage(
          language: language,
          zh: '第二条主题也需要至少写成一个完整段落，而不是轻轻带过。',
          en: 'The second thread also needs at least one complete paragraph instead of a brief mention.',
        ),
      );
    }
    if (candidateCount >= 6 && totalLength < minTotalLength) {
      issues.add(
        trByLanguage(
          language: language,
          zh: '素材已经够了，请把正文写得更完整一些，至少形成一封写完的回信。',
          en: 'There is enough material. Make the body feel complete, like a finished letter rather than a sketch.',
        ),
      );
    }
    if (candidateCount >= 6 &&
        referencedMemoCount > 0 &&
        referencedMemoCount < 2) {
      issues.add(
        trByLanguage(
          language: language,
          zh: '引用不要过度压在同一条笔记上。请让主线尽量落回多条原始笔记，而不是只围着一个片段打转。',
          en: 'Do not lean too heavily on a single memo. Let each thread draw from multiple original notes when the material allows it.',
        ),
      );
    }

    if (issues.isEmpty) {
      return null;
    }
    return issues.join(' ');
  }

  double _themeStrength(List<_ScoredChunk> scoredEntries) {
    if (scoredEntries.isEmpty) {
      return 0;
    }
    final uniqueMemoScores = <double>[];
    final seenMemos = <String>{};
    for (final entry in scoredEntries) {
      if (seenMemos.add(entry.item.memoUid)) {
        uniqueMemoScores.add(entry.score);
      }
      if (uniqueMemoScores.length >= 4) {
        break;
      }
    }
    if (uniqueMemoScores.isEmpty) {
      return 0;
    }
    const weights = <double>[1.0, 0.84, 0.7, 0.58];
    var strength = 0.0;
    for (var index = 0; index < uniqueMemoScores.length; index++) {
      strength += uniqueMemoScores[index] * weights[index];
    }
    strength += math.min(seenMemos.length, 4) * 0.02;
    return strength;
  }

  List<_ScoredChunk> _selectThreadSupport({
    required List<_ScoredChunk> scoredEntries,
    required Set<int> usedChunkIds,
    required Map<String, int> globalMemoCount,
  }) {
    final filtered = scoredEntries
        .where((entry) {
          if (usedChunkIds.contains(entry.item.chunkId)) {
            return false;
          }
          final memoCount = globalMemoCount[entry.item.memoUid] ?? 0;
          return memoCount < _maxChunksPerMemo;
        })
        .toList(growable: false);
    if (filtered.isEmpty) {
      return const <_ScoredChunk>[];
    }

    final perMemo = <String, List<_ScoredChunk>>{};
    for (final entry in filtered) {
      perMemo
          .putIfAbsent(entry.item.memoUid, () => <_ScoredChunk>[])
          .add(entry);
    }
    for (final list in perMemo.values) {
      list.sort((a, b) => b.score.compareTo(a.score));
    }

    final selected = <_ScoredChunk>[];
    final perThreadMemoCount = <String, int>{};
    final firstPass =
        perMemo.values.map((entries) => entries.first).toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    for (final entry in firstPass) {
      if (selected.length >= _maxThreadSupportChunks) {
        break;
      }
      selected.add(entry);
      perThreadMemoCount[entry.item.memoUid] = 1;
    }

    final remaining = <_ScoredChunk>[];
    for (final entries in perMemo.values) {
      if (entries.length <= 1) {
        continue;
      }
      remaining.addAll(entries.skip(1));
    }
    remaining.sort((a, b) => b.score.compareTo(a.score));

    for (final entry in remaining) {
      if (selected.length >= _maxThreadSupportChunks) {
        break;
      }
      final memoUid = entry.item.memoUid;
      final currentMemoCount = perThreadMemoCount[memoUid] ?? 0;
      if (currentMemoCount >= _maxChunksPerMemoPerThread) {
        continue;
      }
      final selectedMemoCount = selected
          .map((item) => item.item.memoUid)
          .toSet()
          .length;
      if (selectedMemoCount < _minDistinctMemosPerThread &&
          !perThreadMemoCount.containsKey(memoUid)) {
        selected.add(entry);
        perThreadMemoCount[memoUid] = currentMemoCount + 1;
        continue;
      }
      selected.add(entry);
      perThreadMemoCount[memoUid] = currentMemoCount + 1;
    }

    return selected;
  }

  int _meaningfulCharCount(String text) {
    return text.replaceAll(RegExp(r'\s+'), '').trim().length;
  }

  String _buildSystemPrompt({required AppLanguage language}) {
    return trByLanguage(
      language: language,
      zh: '你是一个只输出合法 JSON 的来信式阶段回顾助手。不要输出 Markdown，不要解释，不要输出代码块。只返回一个 JSON 对象。analysis_type 固定为 emotion_map。文字要像认真读完这些笔记后写给用户的一封回信：温和、克制、诚实、具体。不要写成分析报告，不要像心理测评，不要说教，也不要编造事实。正文里不要出现 evidence_key，也不要说“提供的证据”“无法识别”“提取失败”这类机器化表达。只能引用提供过的 evidence_key 作为溯源依据。',
      en: 'You are a reflective writing assistant that must output valid JSON only. No markdown, no explanations, and no code fences. Return exactly one JSON object with analysis_type set to emotion_map. The prose should read like a careful letter written after closely reading the notes: warm, restrained, honest, and concrete. Do not sound like a report, diagnosis, checklist, or coach. Do not invent facts. Never mention evidence_key values or phrases like “provided evidence”, “unable to identify”, or “extraction failed” in the prose. Only cite evidence_key values that were provided.',
    );
  }

  String _buildEmotionMapUserPrompt({
    required AppLanguage language,
    required AiSettings settings,
    required _RetrievalBundle retrieval,
    required String promptTemplate,
    required DateTimeRange range,
    required int attempt,
    String? previousOutput,
    String? previousError,
  }) {
    final candidates = retrieval.candidates;
    final localeText = prefersEnglishFor(language)
        ? 'English'
        : 'Simplified Chinese';
    final readingAngles = _emotionMapIntents(language)
        .map(
          (intent) => {'section_key': intent.sectionKey, 'goal': intent.query},
        )
        .toList(growable: false);
    final payload = <String, Object?>{
      'task': 'emotion_map_letter',
      'write_language': localeText,
      'retrieval_mode': retrieval.mode,
      'date_range': {
        'start': range.start.toIso8601String(),
        'end': range.end.toIso8601String(),
      },
      'user_profile': settings.userProfile.trim(),
      'custom_prompt_template': promptTemplate.trim(),
      if (retrieval.mode == 'direct')
        'retrieval_note': prefersEnglishFor(language)
            ? 'No embedding model is configured for this run. The evidence pack was selected directly from memo content in the chosen range, so stay conservative about hidden patterns and lean on what is clearly visible in the notes.'
            : '本次未配置向量模型，证据片段是直接从所选时间范围内的笔记内容中挑选出来的。请更保守地判断隐含模式，尽量依据笔记里清晰可见的内容来写。',
      'writing_goal': prefersEnglishFor(language)
          ? 'Write a restrained letter-like reply for this stretch of time, not an analysis report.'
          : '请把结果写成一封写给这段时间的回信，而不是分析报告。',
      'writing_rules': prefersEnglishFor(language)
          ? <String>[
              'Write in continuous paragraphs with a natural reading flow.',
              'Open by showing that you really read the notes.',
              'Let the body feel complete. When the notes are sufficient, the letter should usually reach three to five full paragraphs before any optional closing.',
              'Focus on one or two dominant threads only; do not spread attention evenly across every angle.',
              'Treat retrieval_threads as pre-grouped theme bundles: build around main_thread first, then use secondary_thread only if it genuinely adds depth.',
              'Within each chosen thread, notice the echoes across multiple original memos instead of leaning too heavily on a single dramatic note.',
              'Do not stop after naming a theme. For each chosen thread, unfold what you read, how it seems to move across this period, and why it stands out.',
              'Let the main thread breathe. It should usually be a fully developed paragraph or two, not a brief mention.',
              'If you include a second thread, give it at least one complete paragraph with its own texture.',
              'If some themes are under-supported, you may leave gentle space briefly, but do not force a dedicated section unless it really helps.',
              'Do not use report language, therapist jargon, or checklist-style advice.',
              'Keep the tone warm, restrained, specific, and grounded in the notes.',
              'Do not expose evidence_key values inside the prose.',
              'Whenever the evidence is clear enough, the main thread should carry one or two evidence_keys, and the second thread should carry at least one.',
              'Only add a light closing line if it feels natural; do not force a dedicated ending.',
            ]
          : <String>[
              '用连续段落来写，整体读感像一封认真写完的回信。',
              '开头先让人感觉到：你真的读过这些笔记。',
              '只抓住一到两个最重要的阶段主题展开，不要平均分配篇幅。',
              '如果某些主题线索不够，可以轻轻留一点空白，但不要为了留白而硬写一段。',
              '不要使用分析报告口吻、心理测评口吻或 checklist 式建议。',
              '整体语气要温和、克制、具体，并且始终落在笔记事实上。',
              '正文里不要直接暴露 evidence_key。',
              '只有在真的自然时再轻轻收一下，不要为了结尾而另写一段。',
            ],
      'section_roles': const <Map<String, String>>[
        {
          'section_key': 'main_thread',
          'purpose': 'the main thread you choose to expand',
        },
        {
          'section_key': 'secondary_thread',
          'purpose': 'an optional second thread if it truly matters',
        },
        {
          'section_key': 'leave_space',
          'purpose':
              'optional; only use if a brief note of uncertainty truly helps the reading',
        },
        {
          'section_key': 'closing',
          'purpose':
              'optional; only use if a natural soft ending appears on its own',
        },
      ],
      'quality_floor': const <String>[
        'The opening paragraph must feel complete, not like one short sentence that stops too early.',
        'The main_thread must be fully developed with concrete observations from the notes, not just named and dropped.',
        'If secondary_thread appears, it also needs one complete paragraph of its own.',
        'When the evidence pack is rich enough, the overall body should read like a finished letter rather than a sketch.',
      ],
      'reading_angles': readingAngles,
      'retrieval_threads': retrieval.threads
          .map((item) => item.toJson())
          .toList(growable: false),
      'evidence_pack': candidates
          .map((item) => item.toJson())
          .toList(growable: false),
      'required_output_schema': {
        'schema_version': 2,
        'analysis_type': 'emotion_map',
        'summary':
            'opening paragraph of the letter; give it enough room to set the tone, not just one short sentence',
        'sections': [
          {
            'section_key':
                'main_thread | secondary_thread | leave_space(optional) | closing(optional)',
            'title': 'short internal label, optional, never report-like',
            'body':
                'paragraph text in a letter voice; the main_thread should be fully developed instead of ending right after the theme appears',
            'evidence_keys': ['e1'],
            // optional; may be [] when no quote is reliable enough,
          },
        ],
        'follow_up_suggestions': ['optional string, may be empty'],
      },
    };
    final buffer = StringBuffer(jsonEncode(payload));
    if (attempt > 0) {
      buffer.writeln();
      buffer.writeln(
        trByLanguage(
          language: language,
          zh: '上一次输出不合法，请修正后重新输出合法 JSON。',
          en: 'Revise the previous draft using the feedback below, and return valid JSON only.',
        ),
      );
      if ((previousError ?? '').trim().isNotEmpty) {
        buffer.writeln('error: ${previousError!.trim()}');
      }
      if ((previousOutput ?? '').trim().isNotEmpty) {
        buffer.writeln('previous_output: ${previousOutput!.trim()}');
      }
    }
    return buffer.toString();
  }

  String _directRetrievalThreadHint(AppLanguage language) {
    return trByLanguage(
      language: language,
      zh: '直接阅读模式：当前没有向量检索，这些片段是从所选时间范围中按内容与时间顺序挑选出来的。',
      en: 'Direct reading mode: no embedding retrieval was available, so these fragments were selected directly from the chosen range.',
    );
  }

  double _directRetrievalScore({
    required int memoIndex,
    required int round,
    required int contentLength,
  }) {
    final recencyScore = math.max(0.12, 1.0 - (memoIndex * 0.08));
    final densityBonus = math.min(0.28, contentLength / 1000);
    final roundPenalty = round * 0.05;
    return math.max(0.1, recencyScore + densityBonus - roundPenalty);
  }

  int _memoSortTimestamp(Map<String, dynamic> row) {
    final updateTime = (row['update_time'] as int?) ?? 0;
    if (updateTime > 0) {
      return updateTime;
    }
    return (row['create_time'] as int?) ?? 0;
  }

  List<_IntentQuery> _emotionMapIntents(AppLanguage language) {
    return <_IntentQuery>[
      _IntentQuery(
        sectionKey: 'emotion_curve',
        query: trByLanguage(
          language: language,
          zh: '找出情绪高点、低点、波动与反复变化的片段。',
          en: 'Find passages showing emotional highs, lows, volatility, and repeated swings.',
        ),
      ),
      _IntentQuery(
        sectionKey: 'stress_trigger',
        query: trByLanguage(
          language: language,
          zh: '找出压力源、焦虑来源、持续消耗你的触发因素。',
          en: 'Find passages about stressors, anxiety sources, and draining triggers.',
        ),
      ),
      _IntentQuery(
        sectionKey: 'recovery_signal',
        query: trByLanguage(
          language: language,
          zh: '找出让你缓和、恢复、安定、重建秩序的因素。',
          en: 'Find passages about calming, recovery, stability, and restoring balance.',
        ),
      ),
      _IntentQuery(
        sectionKey: 'relationship_theme',
        query: trByLanguage(
          language: language,
          zh: '找出与情绪有关的人际关系、反复出现的人和互动主题。',
          en: 'Find passages about emotional relationship themes, recurring people, and interaction patterns.',
        ),
      ),
    ];
  }

  List<AiChunkDraft> _chunkMemo(Map<String, dynamic> memoRow) {
    final content = ((memoRow['content'] as String?) ?? '').trimRight();
    if (content.trim().isEmpty) return const <AiChunkDraft>[];
    if (looksLikeGeneratedAiSummaryMemo(content)) {
      return const <AiChunkDraft>[];
    }
    final memoUid = (memoRow['uid'] as String?) ?? '';
    if (memoUid.trim().isEmpty) return const <AiChunkDraft>[];
    final memoContentHash = _computeMemoContentHash(memoRow);
    final createTime = (memoRow['create_time'] as int?) ?? 0;
    final updateTime = (memoRow['update_time'] as int?) ?? 0;
    final visibility = (memoRow['visibility'] as String?)?.trim() ?? 'PRIVATE';

    final chunks = <AiChunkDraft>[];
    final paragraphPattern = RegExp(r'\n\s*\n');
    final matches = paragraphPattern
        .allMatches(content)
        .toList(growable: false);
    var cursor = 0;
    final spans = <_ContentSpan>[];
    for (final match in matches) {
      final end = match.start;
      if (end > cursor) {
        final text = content.substring(cursor, end).trim();
        if (_isChunkableText(text)) {
          spans.add(
            _ContentSpan(
              start: cursor,
              end: end,
              text: content.substring(cursor, end),
            ),
          );
        }
      }
      cursor = match.end;
    }
    if (cursor < content.length) {
      final text = content.substring(cursor).trim();
      if (_isChunkableText(text)) {
        spans.add(
          _ContentSpan(
            start: cursor,
            end: content.length,
            text: content.substring(cursor),
          ),
        );
      }
    }
    if (spans.isEmpty && _isChunkableText(content)) {
      spans.add(_ContentSpan(start: 0, end: content.length, text: content));
    }

    var chunkIndex = 0;
    var currentStart = -1;
    var currentEnd = -1;
    var buffer = StringBuffer();

    void pushChunk() {
      final text = buffer.toString().trim();
      if (text.isEmpty || currentStart < 0 || currentEnd <= currentStart) {
        return;
      }
      chunks.add(
        AiChunkDraft(
          chunkIndex: chunkIndex,
          content: text,
          contentHash: sha1.convert(utf8.encode(text)).toString(),
          memoContentHash: memoContentHash,
          charStart: currentStart,
          charEnd: currentEnd,
          tokenEstimate: (utf8.encode(text).length / 4).ceil(),
          memoCreateTime: createTime,
          memoUpdateTime: updateTime,
          memoVisibility: visibility,
        ),
      );
      chunkIndex += 1;
    }

    for (final span in spans) {
      final trimmed = span.text.trim();
      if (trimmed.length > 600) {
        pushChunk();
        buffer = StringBuffer();
        currentStart = -1;
        currentEnd = -1;
        var splitStart = 0;
        while (splitStart < trimmed.length) {
          final splitEnd = math.min(trimmed.length, splitStart + 500);
          final piece = trimmed.substring(splitStart, splitEnd).trim();
          if (piece.isNotEmpty) {
            chunks.add(
              AiChunkDraft(
                chunkIndex: chunkIndex,
                content: piece,
                contentHash: sha1.convert(utf8.encode(piece)).toString(),
                memoContentHash: memoContentHash,
                charStart: span.start + splitStart,
                charEnd: span.start + splitEnd,
                tokenEstimate: (utf8.encode(piece).length / 4).ceil(),
                memoCreateTime: createTime,
                memoUpdateTime: updateTime,
                memoVisibility: visibility,
              ),
            );
            chunkIndex += 1;
          }
          if (splitEnd >= trimmed.length) break;
          splitStart = math.max(0, splitEnd - 60);
        }
        continue;
      }

      final nextLength = buffer.isEmpty
          ? trimmed.length
          : buffer.length + 2 + trimmed.length;
      if (buffer.isNotEmpty && nextLength > 500) {
        pushChunk();
        final overlapStart = math.max(currentEnd - 60, 0);
        final overlapText = content.substring(overlapStart, currentEnd).trim();
        buffer = StringBuffer();
        if (overlapText.isNotEmpty) {
          buffer.write(overlapText);
          currentStart = overlapStart;
        } else {
          currentStart = -1;
          currentEnd = -1;
        }
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(trimmed);
      currentStart = currentStart < 0 ? span.start : currentStart;
      currentEnd = span.end;
    }
    pushChunk();
    return chunks;
  }

  bool _isChunkableText(String text) {
    final normalized = text
        .replaceAll(RegExp(r'#[^\s#]+'), '')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]*\)'), '')
        .replaceAll(
          RegExp(r'\[[^\]]*attachment[^\]]*\]', caseSensitive: false),
          '',
        )
        .trim();
    return normalized.isNotEmpty;
  }

  bool _memoRowAllowed(
    Map<String, dynamic> row, {
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
  }) {
    final allowAi = ((row['allow_ai'] as int?) ?? 1) == 1;
    final state = (row['state'] as String?)?.trim().toUpperCase() ?? 'NORMAL';
    final visibility =
        (row['visibility'] as String?)?.trim().toUpperCase() ?? 'PRIVATE';
    final content = ((row['content'] as String?) ?? '').trim();
    if (!allowAi || state != 'NORMAL' || content.isEmpty) return false;
    if (looksLikeGeneratedAiSummaryMemo(content)) return false;
    if (!includePublic && visibility == 'PUBLIC') return false;
    if (!includePrivate && visibility == 'PRIVATE') return false;
    if (!includeProtected && visibility == 'PROTECTED') return false;
    return true;
  }

  String _computeMemoContentHash(Map<String, dynamic> row) {
    final content = (row['content'] as String?) ?? '';
    final visibility = (row['visibility'] as String?) ?? '';
    return computeContentFingerprint('$visibility\n$content');
  }

  AiRetrievalPreviewItem _previewItemFromRow(Map<String, dynamic> row) {
    final createTime = (row['memo_create_time'] as int?) ?? 0;
    return AiRetrievalPreviewItem(
      memoUid: (row['memo_uid'] as String?) ?? '',
      chunkId: (row['id'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createTime * 1000,
        isUtc: true,
      ).toLocal(),
      visibility: (row['memo_visibility'] as String?) ?? 'PRIVATE',
      content: ((row['content'] as String?) ?? '').trim(),
      embeddingStatus: aiEmbeddingStatusFromStorage(
        (row['embedding_status'] as String?) ?? 'pending',
      ),
    );
  }

  _CandidateChunk _candidateChunkFromRow(Map<String, dynamic> row) {
    return _CandidateChunk(
      chunkId: (row['id'] as int?) ?? 0,
      memoUid: (row['memo_uid'] as String?) ?? '',
      content: ((row['content'] as String?) ?? '').trim(),
      charStart: (row['char_start'] as int?) ?? 0,
      charEnd: (row['char_end'] as int?) ?? 0,
      memoCreateTime: (row['memo_create_time'] as int?) ?? 0,
      memoVisibility: (row['memo_visibility'] as String?) ?? 'PRIVATE',
      embeddingStatus: aiEmbeddingStatusFromStorage(
        (row['embedding_status'] as String?) ?? 'pending',
      ),
      vector: decodeFloat32VectorBlob(row['vector_blob']),
    );
  }

  int _rangeStart(DateTimeRange range) {
    return DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        ).toUtc().millisecondsSinceEpoch ~/
        1000;
  }

  int _rangeEndExclusive(DateTimeRange range) {
    return DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        ).add(const Duration(days: 1)).toUtc().millisecondsSinceEpoch ~/
        1000;
  }

  AiSettings _currentSettings(AiSettings fallback) {
    return _readCurrentSettings?.call() ?? fallback;
  }

  AiGenerationProfile? _resolveGenerationProfile(AiSettings settings) {
    final routed = _runtime?.resolveGenerationProfile(
      settings,
      routeId: AiTaskRouteId.analysisReport,
    );
    if (routed != null &&
        routed.enabled &&
        routed.baseUrl.trim().isNotEmpty &&
        routed.model.trim().isNotEmpty) {
      return routed;
    }
    if (settings.selectedGenerationProfile.enabled) {
      return settings.selectedGenerationProfile;
    }
    return settings.generationProfiles
        .where((profile) => profile.enabled)
        ._firstOrNullValue;
  }

  AiEmbeddingProfile? _resolveEmbeddingProfile(AiSettings settings) {
    final routed = _runtime?.resolveEmbeddingProfile(settings);
    if (routed != null &&
        routed.enabled &&
        routed.baseUrl.trim().isNotEmpty &&
        routed.model.trim().isNotEmpty) {
      return routed;
    }
    final selected = settings.selectedEmbeddingProfile;
    if (selected != null && selected.enabled) return selected;
    return settings.embeddingProfiles
        .where((profile) => profile.enabled)
        ._firstOrNullValue;
  }

  bool _sameEmbeddingProfile(
    AiEmbeddingProfile expected,
    AiEmbeddingProfile current,
  ) {
    String normalize(String value) => value.trim();
    return normalize(expected.profileKey) == normalize(current.profileKey) &&
        normalize(expected.baseUrl) == normalize(current.baseUrl) &&
        normalize(expected.apiKey) == normalize(current.apiKey) &&
        normalize(expected.model).toLowerCase() ==
            normalize(current.model).toLowerCase();
  }

  double _cosineSimilarity(Float32List left, Float32List right) {
    if (left.length != right.length || left.isEmpty) return 0;
    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;
    for (var index = 0; index < left.length; index++) {
      final l = left[index];
      final r = right[index];
      dot += l * r;
      leftNorm += l * l;
      rightNorm += r * r;
    }
    if (leftNorm <= 0 || rightNorm <= 0) return 0;
    return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
  }

  Map<String, dynamic> _decodeJsonObject(String rawText) {
    final cleaned = rawText
        .trim()
        .replaceAll(RegExp(r'^```[a-zA-Z]*'), '')
        .replaceAll('```', '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('No JSON object found');
    }
    final decoded = jsonDecode(cleaned.substring(start, end + 1));
    if (decoded is! Map) {
      throw const FormatException('JSON root must be an object');
    }
    return decoded.cast<String, dynamic>();
  }

  String _normalizeBase(String baseUrl, {required bool ensureV1}) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.parse(trimmed);
    final segments = uri.pathSegments
        .where((item) => item.isNotEmpty)
        .toList(growable: true);
    if (ensureV1 && !segments.contains('v1')) {
      segments.add('v1');
    }
    return uri
        .replace(pathSegments: segments)
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  String _resolveEndpoint(String base, String path) {
    final normalizedBase = base.replaceAll(RegExp(r'/$'), '');
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$normalizedBase/$normalizedPath';
  }
}

class _ContentSpan {
  const _ContentSpan({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}

class _EmbeddingBuildResult {
  const _EmbeddingBuildResult({
    required this.status,
    this.vector,
    this.errorText,
  });

  final AiEmbeddingStatus status;
  final Float32List? vector;
  final String? errorText;
}

class _CandidateChunk {
  const _CandidateChunk({
    required this.chunkId,
    required this.memoUid,
    required this.content,
    required this.charStart,
    required this.charEnd,
    required this.memoCreateTime,
    required this.memoVisibility,
    required this.embeddingStatus,
    required this.vector,
  });

  final int chunkId;
  final String memoUid;
  final String content;
  final int charStart;
  final int charEnd;
  final int memoCreateTime;
  final String memoVisibility;
  final AiEmbeddingStatus embeddingStatus;
  final Float32List? vector;
}

class _ScoredChunk {
  const _ScoredChunk({required this.item, required this.score});

  final _CandidateChunk item;
  final double score;
}

class _RetrievalBundle {
  const _RetrievalBundle({
    required this.mode,
    required this.candidates,
    required this.threads,
  });

  final String mode;
  final List<AiEvidenceCandidate> candidates;
  final List<_RetrievalThreadBundle> threads;
}

class _IntentQuery {
  const _IntentQuery({required this.sectionKey, required this.query});

  final String sectionKey;
  final String query;
}

class _RetrievalThemePlan {
  const _RetrievalThemePlan({required this.intent, required this.strength});

  final _IntentQuery intent;
  final double strength;
}

class _RetrievalThreadBundle {
  const _RetrievalThreadBundle({
    required this.threadKey,
    required this.sourceThemeKey,
    required this.evidences,
    required this.strength,
  });

  final String threadKey;
  final String sourceThemeKey;
  final List<AiEvidenceCandidate> evidences;
  final double strength;

  Map<String, dynamic> toJson() => {
    'thread_key': threadKey,
    'source_theme_key': sourceThemeKey,
    'supporting_evidence_keys': evidences
        .map((item) => item.evidenceKey)
        .toList(growable: false),
    'supporting_memo_uids': evidences
        .map((item) => item.memoUid)
        .toSet()
        .toList(growable: false),
    'support_memo_count': evidences.map((item) => item.memoUid).toSet().length,
    'support_chunk_count': evidences.length,
    'strength': strength,
  };
}

class _NarrativeQualityIssue implements Exception {
  const _NarrativeQualityIssue(this.message);

  final String message;

  @override
  String toString() => message;
}

class _EmbeddingFailureGuard {
  _EmbeddingFailureGuard({required this.language});

  final AppLanguage language;
  int _consecutiveFailures = 0;

  void recordSuccess() {
    _consecutiveFailures = 0;
  }

  _EmbeddingFailureCutoffException? recordFailure(Object error) {
    _consecutiveFailures += 1;
    if (_consecutiveFailures <
        AiAnalysisService._maxConsecutiveEmbeddingFailures) {
      return null;
    }
    return _EmbeddingFailureCutoffException(
      trByLanguage(
        language: language,
        zh: '向量模型已经连续 5 次请求失败，我先帮你停下来了。请检查 embedding 模型、Base URL 和 API Key 是否正确，然后再试一次。',
        en: 'The embedding model failed 5 times in a row, so I stopped further requests. Please check the embedding model, base URL, and API key, then try again.',
      ),
    );
  }
}

class _EmbeddingFailureCutoffException implements Exception {
  const _EmbeddingFailureCutoffException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _EmbeddingConfigurationChangedException implements Exception {
  const _EmbeddingConfigurationChangedException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension _IterableFirstOrNullValue<T> on Iterable<T> {
  T? get _firstOrNullValue => isEmpty ? null : first;
}
