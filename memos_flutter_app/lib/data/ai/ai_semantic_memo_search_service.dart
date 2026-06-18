import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/tags.dart';
import '../models/local_memo.dart';
import 'ai_analysis_models.dart';
import 'ai_analysis_repository.dart';
import 'ai_memo_indexing.dart';
import 'ai_provider_adapter.dart';
import 'ai_task_runtime.dart';

typedef AiSemanticEmbeddingResolver =
    AiEmbeddingProfile? Function(AiSettings settings);
typedef AiSemanticTextEmbedder =
    Future<List<double>> Function(AiSettings settings, String input);

final class AiSemanticMemoSearchConfigurationException implements Exception {
  const AiSemanticMemoSearchConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class AiSemanticMemoSearchResult {
  const AiSemanticMemoSearchResult({
    required this.query,
    required this.profileKey,
    required this.readyChunkCount,
    required this.scoredChunkCount,
    required this.hits,
  });

  final String query;
  final String profileKey;
  final int readyChunkCount;
  final int scoredChunkCount;
  final List<AiSemanticMemoSearchHit> hits;

  bool get isEmpty => hits.isEmpty;
}

final class AiSemanticMemoSearchHit {
  const AiSemanticMemoSearchHit({
    required this.memo,
    required this.score,
    required this.bestChunkId,
    required this.bestChunkText,
    required this.matchingChunkCount,
  });

  final LocalMemo memo;
  final double score;
  final int bestChunkId;
  final String bestChunkText;
  final int matchingChunkCount;
}

final class AiSemanticMemoSearchIndexPreflight {
  const AiSemanticMemoSearchIndexPreflight({
    required this.profileKey,
    required this.profileDisplayName,
    required this.backendKind,
    required this.baseUrl,
    required this.model,
    required this.memoCount,
    required this.chunkCount,
    required this.estimatedTokenCount,
  });

  final String profileKey;
  final String profileDisplayName;
  final AiBackendKind backendKind;
  final String baseUrl;
  final String model;
  final int memoCount;
  final int chunkCount;
  final int estimatedTokenCount;

  bool get needsIndexing => estimatedTokenCount > 0 && chunkCount > 0;
  bool get usesRemoteBackend => backendKind == AiBackendKind.remoteApi;

  static const empty = AiSemanticMemoSearchIndexPreflight(
    profileKey: '',
    profileDisplayName: '',
    backendKind: AiBackendKind.remoteApi,
    baseUrl: '',
    model: '',
    memoCount: 0,
    chunkCount: 0,
    estimatedTokenCount: 0,
  );
}

final class AiSemanticMemoSearchService {
  AiSemanticMemoSearchService({
    required AiAnalysisRepository repository,
    AiTaskRuntime? runtime,
    AiSettings Function()? readCurrentSettings,
    TagRecognitionPolicy Function()? currentTagRecognitionPolicy,
    AiSemanticEmbeddingResolver? resolveEmbeddingProfile,
    AiSemanticTextEmbedder? embedText,
  }) : _repository = repository,
       _runtime = runtime,
       _readCurrentSettings = readCurrentSettings,
       _currentTagRecognitionPolicy =
           currentTagRecognitionPolicy ??
           (() => TagRecognitionPolicy.defaultPolicy),
       _resolveEmbeddingProfileOverride = resolveEmbeddingProfile,
       _embedTextOverride = embedText;

  static const _candidateChunkLimit = 3000;
  static const _indexJobLimit = 200;
  static const _maxHydratedMemoMultiplier = 3;
  static const _maxHydratedMemoLimit = 600;

  final AiAnalysisRepository _repository;
  final AiTaskRuntime? _runtime;
  final AiSettings Function()? _readCurrentSettings;
  final TagRecognitionPolicy Function() _currentTagRecognitionPolicy;
  final AiSemanticEmbeddingResolver? _resolveEmbeddingProfileOverride;
  final AiSemanticTextEmbedder? _embedTextOverride;

  Future<AiSemanticMemoSearchIndexPreflight> estimateIndexWorkForSearchScope({
    required AiSettings settings,
    required String query,
    required String state,
    required String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    bool includePublic = true,
    bool includePrivate = true,
    bool includeProtected = false,
  }) async {
    if (query.trim().isEmpty) return AiSemanticMemoSearchIndexPreflight.empty;

    final activeSettings = _currentSettings(settings);
    final profile = _resolveEmbeddingProfile(activeSettings);
    if (profile == null ||
        profile.baseUrl.trim().isEmpty ||
        profile.model.trim().isEmpty) {
      throw const AiSemanticMemoSearchConfigurationException(
        'Configure an embedding model before using AI search.',
      );
    }

    final estimate = await _estimateMissingIndexWork(
      profile: profile,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
    );
    return AiSemanticMemoSearchIndexPreflight(
      profileKey: profile.profileKey,
      profileDisplayName: profile.displayName,
      backendKind: profile.backendKind,
      baseUrl: profile.baseUrl,
      model: profile.model,
      memoCount: estimate.memoCount,
      chunkCount: estimate.chunkCount,
      estimatedTokenCount: estimate.estimatedTokenCount,
    );
  }

  Future<AiSemanticMemoSearchResult> search({
    required AiSettings settings,
    required String query,
    required String state,
    required String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    int limit = 200,
    bool includePublic = true,
    bool includePrivate = true,
    bool includeProtected = false,
  }) async {
    final normalizedQuery = query.trim();
    final pageLimit = limit > 0 ? limit : 200;
    if (normalizedQuery.isEmpty) {
      return AiSemanticMemoSearchResult(
        query: normalizedQuery,
        profileKey: '',
        readyChunkCount: 0,
        scoredChunkCount: 0,
        hits: const <AiSemanticMemoSearchHit>[],
      );
    }

    final activeSettings = _currentSettings(settings);
    final profile = _resolveEmbeddingProfile(activeSettings);
    if (profile == null ||
        profile.baseUrl.trim().isEmpty ||
        profile.model.trim().isEmpty) {
      throw const AiSemanticMemoSearchConfigurationException(
        'Configure an embedding model before using AI search.',
      );
    }

    await _ensureIndexesForSearchScope(
      settings: activeSettings,
      profile: profile,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includePublic: includePublic,
      includePrivate: includePrivate,
      includeProtected: includeProtected,
    );

    final rows = await _repository.listSemanticSearchCandidateChunkRows(
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
        .map(AiMemoIndexing.candidateChunkFromRow)
        .where(
          (item) =>
              item.embeddingStatus == AiEmbeddingStatus.ready &&
              item.vector != null &&
              item.memoUid.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return AiSemanticMemoSearchResult(
        query: normalizedQuery,
        profileKey: profile.profileKey,
        readyChunkCount: 0,
        scoredChunkCount: 0,
        hits: const <AiSemanticMemoSearchHit>[],
      );
    }

    final queryVector = Float32List.fromList(
      await _embed(activeSettings, normalizedQuery),
    );
    final scored =
        candidates
            .map(
              (item) => _ScoredSemanticChunk(
                item: item,
                score: AiMemoIndexing.cosineSimilarity(
                  queryVector,
                  item.vector!,
                ),
              ),
            )
            .where((entry) => entry.score > 0)
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));
    if (scored.isEmpty) {
      return AiSemanticMemoSearchResult(
        query: normalizedQuery,
        profileKey: profile.profileKey,
        readyChunkCount: candidates.length,
        scoredChunkCount: 0,
        hits: const <AiSemanticMemoSearchHit>[],
      );
    }

    final grouped = _rankMemoGroups(scored);
    final hydrateLimit = math.min(
      _maxHydratedMemoLimit,
      math.max(pageLimit * _maxHydratedMemoMultiplier, pageLimit + 60),
    );
    final selectedGroups = grouped.take(hydrateLimit).toList(growable: false);
    final memoRows = await _repository.listMemoRowsByUids(
      selectedGroups.map((item) => item.memoUid),
    );
    final rowByUid = <String, Map<String, dynamic>>{
      for (final row in memoRows) ((row['uid'] as String?) ?? '').trim(): row,
    };

    final hits = <AiSemanticMemoSearchHit>[];
    for (final group in selectedGroups) {
      final row = rowByUid[group.memoUid];
      if (row == null) continue;
      final memo = LocalMemo.fromDb(row);
      if (!_memoMatchesSearchScope(
        memo,
        state: state,
        tag: tag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
      )) {
        continue;
      }
      hits.add(
        AiSemanticMemoSearchHit(
          memo: memo,
          score: group.score,
          bestChunkId: group.bestChunk.chunkId,
          bestChunkText: group.bestChunk.content,
          matchingChunkCount: group.matchingChunkCount,
        ),
      );
      if (hits.length >= pageLimit) break;
    }

    return AiSemanticMemoSearchResult(
      query: normalizedQuery,
      profileKey: profile.profileKey,
      readyChunkCount: candidates.length,
      scoredChunkCount: scored.length,
      hits: hits,
    );
  }

  Future<_IndexWorkEstimate> _estimateMissingIndexWork({
    required AiEmbeddingProfile profile,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
  }) async {
    final memoRows = await _repository.listMemoRowsForAi(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
    );
    var memoCount = 0;
    var chunkCount = 0;
    var estimatedTokenCount = 0;
    for (final row in memoRows) {
      final memoUid = (row['uid'] as String?)?.trim() ?? '';
      if (memoUid.isEmpty) continue;
      final allowed = AiMemoIndexing.memoRowAllowed(
        row,
        includePublic: includePublic,
        includePrivate: includePrivate,
        includeProtected: includeProtected,
        generatedSummaryDetector:
            AiMemoIndexing.looksLikeGeneratedAiSummaryMemo,
      );
      if (!allowed) continue;
      final memoContentHash = AiMemoIndexing.computeMemoContentHash(row);
      final fresh = await _repository.memoHasFreshIndex(
        memoUid: memoUid,
        memoContentHash: memoContentHash,
        baseUrl: profile.baseUrl,
        model: profile.model,
      );
      if (fresh) continue;
      final chunks = AiMemoIndexing.chunkMemo(row);
      if (chunks.isEmpty) continue;
      memoCount += 1;
      chunkCount += chunks.length;
      for (final chunk in chunks) {
        estimatedTokenCount += chunk.tokenEstimate;
      }
    }
    return _IndexWorkEstimate(
      memoCount: memoCount,
      chunkCount: chunkCount,
      estimatedTokenCount: estimatedTokenCount,
    );
  }

  Future<void> _ensureIndexesForSearchScope({
    required AiSettings settings,
    required AiEmbeddingProfile profile,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required bool includePublic,
    required bool includePrivate,
    required bool includeProtected,
  }) async {
    final memoRows = await _repository.listMemoRowsForAi(
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
    );
    for (final row in memoRows) {
      final memoUid = (row['uid'] as String?)?.trim() ?? '';
      if (memoUid.isEmpty) continue;
      final content = (row['content'] as String?) ?? '';
      if (AiMemoIndexing.looksLikeGeneratedAiSummaryMemo(content)) {
        await _repository.upsertMemoPolicy(memoUid: memoUid, allowAi: false);
        await _repository.invalidateActiveChunksForMemo(memoUid);
        continue;
      }
      final allowed = AiMemoIndexing.memoRowAllowed(
        row,
        includePublic: includePublic,
        includePrivate: includePrivate,
        includeProtected: includeProtected,
        generatedSummaryDetector:
            AiMemoIndexing.looksLikeGeneratedAiSummaryMemo,
      );
      if (!allowed) {
        await _repository.invalidateActiveChunksForMemo(memoUid);
        continue;
      }
      final memoContentHash = AiMemoIndexing.computeMemoContentHash(row);
      final fresh = await _repository.memoHasFreshIndex(
        memoUid: memoUid,
        memoContentHash: memoContentHash,
        baseUrl: profile.baseUrl,
        model: profile.model,
      );
      if (fresh) continue;
      await _repository.enqueueIndexJob(
        memoUid: memoUid,
        reason: AiIndexJobReason.memoUpdated,
        memoContentHash: memoContentHash,
        embeddingProfileKey: profile.profileKey,
      );
    }

    await _processPendingIndexJobs(settings: settings, profile: profile);
  }

  Future<void> _processPendingIndexJobs({
    required AiSettings settings,
    required AiEmbeddingProfile profile,
  }) async {
    final jobs = await _repository.listPendingIndexJobs(
      embeddingProfileKey: profile.profileKey,
      limit: _indexJobLimit,
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
          settings: settings,
          profile: profile,
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
      }
    }
  }

  Future<void> _rebuildMemoIndex({
    required String memoUid,
    required AiSettings settings,
    required AiEmbeddingProfile profile,
  }) async {
    final memoRow = await _repository.getMemoRowForAi(memoUid);
    if (memoRow == null ||
        !AiMemoIndexing.memoRowAllowed(
          memoRow,
          includePublic: true,
          includePrivate: true,
          includeProtected: true,
          generatedSummaryDetector:
              AiMemoIndexing.looksLikeGeneratedAiSummaryMemo,
        ) ||
        AiMemoIndexing.looksLikeGeneratedAiSummaryMemo(
          (memoRow['content'] as String?) ?? '',
        )) {
      await _repository.invalidateActiveChunksForMemo(memoUid);
      return;
    }

    final chunks = AiMemoIndexing.chunkMemo(memoRow);
    if (chunks.isEmpty) {
      await _repository.invalidateActiveChunksForMemo(memoUid);
      return;
    }

    final embeddingResults = <_EmbeddingBuildResult>[];
    for (final chunk in chunks) {
      try {
        embeddingResults.add(
          _EmbeddingBuildResult(
            status: AiEmbeddingStatus.ready,
            vector: Float32List.fromList(await _embed(settings, chunk.content)),
          ),
        );
      } catch (error) {
        embeddingResults.add(
          _EmbeddingBuildResult(
            status: AiEmbeddingStatus.failed,
            errorText: error.toString(),
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
  }

  List<_MemoSemanticGroup> _rankMemoGroups(List<_ScoredSemanticChunk> scored) {
    final groups = <String, _MutableMemoSemanticGroup>{};
    for (final entry in scored) {
      final memoUid = entry.item.memoUid.trim();
      if (memoUid.isEmpty) continue;
      final group = groups.putIfAbsent(
        memoUid,
        () => _MutableMemoSemanticGroup(memoUid: memoUid),
      );
      group.add(entry);
    }
    final ranked = groups.values.map((item) => item.toRanked()).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  bool _memoMatchesSearchScope(
    LocalMemo memo, {
    required String state,
    required String? tag,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
  }) {
    final normalizedState = state.trim();
    if (normalizedState.isNotEmpty && memo.state != normalizedState) {
      return false;
    }
    final normalizedTag = normalizeTagPath(tag ?? '');
    if (normalizedTag.isNotEmpty) {
      final tags = deriveVisibleMemoTags(
        content: memo.content,
        remoteTags: memo.tags,
        policy: _currentTagRecognitionPolicy(),
      ).toSet();
      if (!tags.contains(normalizedTag)) return false;
    }
    final displaySec =
        memo.effectiveDisplayTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (startTimeSec != null && displaySec < startTimeSec) return false;
    if (endTimeSecExclusive != null && displaySec >= endTimeSecExclusive) {
      return false;
    }
    return true;
  }

  AiSettings _currentSettings(AiSettings fallback) {
    return _readCurrentSettings?.call() ?? fallback;
  }

  AiEmbeddingProfile? _resolveEmbeddingProfile(AiSettings settings) {
    final override = _resolveEmbeddingProfileOverride;
    if (override != null) return override(settings);
    final routed = _runtime?.resolveEmbeddingProfile(settings);
    if (routed != null &&
        routed.enabled &&
        routed.baseUrl.trim().isNotEmpty &&
        routed.model.trim().isNotEmpty) {
      return routed;
    }
    final selected = settings.selectedEmbeddingProfile;
    if (selected != null && selected.enabled) return selected;
    for (final profile in settings.embeddingProfiles) {
      if (profile.enabled) return profile;
    }
    return null;
  }

  Future<List<double>> _embed(AiSettings settings, String input) async {
    final override = _embedTextOverride;
    if (override != null) return override(settings, input);
    final runtime = _runtime;
    if (runtime == null || runtime.resolveEmbeddingRoute(settings) == null) {
      throw const AiSemanticMemoSearchConfigurationException(
        'Configure an embedding model before using AI search.',
      );
    }
    return runtime.embed(settings: settings, input: input);
  }
}

final class _IndexWorkEstimate {
  const _IndexWorkEstimate({
    required this.memoCount,
    required this.chunkCount,
    required this.estimatedTokenCount,
  });

  final int memoCount;
  final int chunkCount;
  final int estimatedTokenCount;
}

final class _ScoredSemanticChunk {
  const _ScoredSemanticChunk({required this.item, required this.score});

  final AiMemoEmbeddingChunk item;
  final double score;
}

final class _MutableMemoSemanticGroup {
  _MutableMemoSemanticGroup({required this.memoUid});

  final String memoUid;
  AiMemoEmbeddingChunk? bestChunk;
  double bestScore = 0;
  int matchingChunkCount = 0;

  void add(_ScoredSemanticChunk entry) {
    matchingChunkCount += 1;
    if (entry.score > bestScore || bestChunk == null) {
      bestScore = entry.score;
      bestChunk = entry.item;
    }
  }

  _MemoSemanticGroup toRanked() {
    final chunk = bestChunk;
    if (chunk == null) {
      throw StateError('Semantic group has no chunk.');
    }
    final densityBonus = math.min(
      0.06,
      math.max(0, matchingChunkCount - 1) * 0.015,
    );
    return _MemoSemanticGroup(
      memoUid: memoUid,
      score: bestScore + densityBonus,
      bestChunk: chunk,
      matchingChunkCount: matchingChunkCount,
    );
  }
}

final class _MemoSemanticGroup {
  const _MemoSemanticGroup({
    required this.memoUid,
    required this.score,
    required this.bestChunk,
    required this.matchingChunkCount,
  });

  final String memoUid;
  final double score;
  final AiMemoEmbeddingChunk bestChunk;
  final int matchingChunkCount;
}

final class _EmbeddingBuildResult {
  const _EmbeddingBuildResult({
    required this.status,
    this.vector,
    this.errorText,
  });

  final AiEmbeddingStatus status;
  final Float32List? vector;
  final String? errorText;
}
