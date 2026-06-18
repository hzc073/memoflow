import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/tags.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_models.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_repository.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_service.dart';
import 'package:memos_flutter_app/data/ai/ai_memo_indexing.dart';
import 'package:memos_flutter_app/data/ai/ai_semantic_memo_search_service.dart';
import 'package:memos_flutter_app/data/ai/ai_task_runtime.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';

import '../../test_support.dart';

class _FakeAiAnalysisRepository implements AiAnalysisRepository {
  _FakeAiAnalysisRepository(this._memoRows);

  final List<Map<String, dynamic>> _memoRows;
  final List<Map<String, dynamic>> _jobs = <Map<String, dynamic>>[];
  int _nextJobId = 1;
  int _nextChunkId = 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  Future<List<Map<String, dynamic>>> listMemoRowsForAi({
    int? startTimeSec,
    int? endTimeSecExclusive,
    bool includeArchived = false,
  }) async {
    return _memoRows;
  }

  @override
  Future<bool> memoHasFreshIndex({
    required String memoUid,
    required String memoContentHash,
    required String baseUrl,
    required String model,
  }) async {
    return false;
  }

  @override
  Future<int> enqueueIndexJob({
    required String? memoUid,
    required AiIndexJobReason reason,
    required String memoContentHash,
    required String embeddingProfileKey,
    int priority = 100,
  }) async {
    final jobId = _nextJobId++;
    _jobs.add(<String, dynamic>{
      'id': jobId,
      'memo_uid': memoUid,
      'attempt_count': 0,
      'embedding_profile_key': embeddingProfileKey,
      'status': AiIndexJobStatus.queued,
    });
    return jobId;
  }

  @override
  Future<List<Map<String, dynamic>>> listPendingIndexJobs({
    required String embeddingProfileKey,
    int limit = 50,
  }) async {
    return _jobs
        .where(
          (job) =>
              job['embedding_profile_key'] == embeddingProfileKey &&
              (job['status'] == AiIndexJobStatus.queued ||
                  job['status'] == AiIndexJobStatus.failed),
        )
        .take(limit)
        .map((job) => Map<String, dynamic>.from(job))
        .toList(growable: false);
  }

  @override
  Future<void> updateIndexJobStatus(
    int jobId, {
    required AiIndexJobStatus status,
    int? attemptCount,
    String? errorText,
    bool markStarted = false,
    bool markFinished = false,
  }) async {
    final job = _jobs.firstWhere((item) => item['id'] == jobId);
    job['status'] = status;
    if (attemptCount != null) {
      job['attempt_count'] = attemptCount;
    }
    job['error_text'] = errorText;
  }

  @override
  Future<Map<String, dynamic>?> getMemoRowForAi(String memoUid) async {
    for (final row in _memoRows) {
      if (row['uid'] == memoUid) {
        return row;
      }
    }
    return null;
  }

  @override
  Future<void> invalidateActiveChunksForMemo(String memoUid) async {}

  @override
  Future<List<int>> insertActiveChunks({
    required String memoUid,
    required List<AiChunkDraft> chunks,
  }) async {
    return List<int>.generate(chunks.length, (_) => _nextChunkId++);
  }

  @override
  Future<void> insertEmbeddingRecord({
    required int chunkId,
    required AiEmbeddingProfile profile,
    required AiEmbeddingStatus status,
    Float32List? vector,
    String? errorText,
  }) async {}
}

class _FailingEmbeddingRuntime extends AiTaskRuntime {
  _FailingEmbeddingRuntime() : super(registry: AiProviderRegistry.defaults());

  int embedCalls = 0;

  @override
  AiResolvedTaskRoute? resolveEmbeddingRoute(AiSettings settings) {
    return AiRouteResolver.resolveTaskRoute(
      services: settings.services,
      bindings: settings.taskRouteBindings,
      routeId: AiTaskRouteId.embeddingRetrieval,
      capability: AiCapability.embedding,
    );
  }

  @override
  Future<List<double>> embed({
    required AiSettings settings,
    required String input,
  }) async {
    embedCalls += 1;
    throw StateError(
      'Unsupported model `qwen3-vl-embedding` for OpenAI compatibility mode.',
    );
  }
}

class _ChatOnlyRuntime extends AiTaskRuntime {
  _ChatOnlyRuntime() : super(registry: AiProviderRegistry.defaults());

  int chatCalls = 0;
  int embedCalls = 0;

  @override
  Future<AiChatCompletionResult> chatCompletion({
    required AiSettings settings,
    required AiTaskRouteId routeId,
    required List<AiChatMessage> messages,
    String? systemPrompt,
    double? temperature,
    int? maxOutputTokens,
  }) async {
    chatCalls += 1;
    return AiChatCompletionResult(
      text: jsonEncode(<String, Object?>{
        'schema_version': 2,
        'analysis_type': 'emotion_map',
        'summary':
            'Across this stretch of notes, you sound like someone carrying a steady amount of pressure while still trying to make room for recovery. The pattern is not chaos as much as repetition: stress rises, you notice it, and then you try to restore balance with small deliberate actions.',
        'sections': <Map<String, Object?>>[
          <String, Object?>{
            'section_key': 'main_thread',
            'title': 'pressure and recovery loop',
            'body':
                'The strongest thread is the way pressure keeps returning in practical, ordinary forms, while you keep responding with equally practical attempts to settle yourself again. The notes do not read like one dramatic collapse. They read like repeated friction, followed by repeated acts of repair: walking, slowing down, naming what feels heavy, and trying to regain a sense of footing. That rhythm matters because it shows strain, but it also shows persistence and self-observation instead of numbness.',
            'evidence_keys': <String>['e1'],
          },
        ],
        'follow_up_suggestions': <String>[
          'Keep noticing which small routines reliably help you recover.',
        ],
      }),
      raw: null,
    );
  }

  @override
  Future<List<double>> embed({
    required AiSettings settings,
    required String input,
  }) async {
    embedCalls += 1;
    throw StateError('Embedding should not be called in chat-only mode.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('looksLikeGeneratedAiSummaryMemo detects saved letter memos', () {
    expect(
      AiMemoIndexing.looksLikeGeneratedAiSummaryMemo(
        '# Letter Back\n2026-02-01 — 2026-03-12\n\nThis letter drew on these note fragments:\n- "A quoted line"',
      ),
      isTrue,
    );
    expect(
      AiMemoIndexing.looksLikeGeneratedAiSummaryMemo(
        'Met a friend for coffee and took a long walk today.',
      ),
      isFalse,
    );
  });

  test('buildEmotionMapPreview ignores saved AI letter memos', () async {
    final now = DateTime.utc(2026, 3, 11);
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;
    final repository = _FakeAiAnalysisRepository(<Map<String, dynamic>>[
      <String, dynamic>{
        'uid': 'memo_note',
        'content':
            'Met a friend for coffee and felt much calmer after the walk.',
        'visibility': 'PRIVATE',
        'allow_ai': 1,
        'state': 'NORMAL',
        'create_time': timestamp,
        'update_time': timestamp,
      },
      <String, dynamic>{
        'uid': 'memo_ai_letter',
        'content':
            '# Letter Back\n2026-02-01 — 2026-03-11\n\nThis letter drew on these note fragments:\n- "A quoted line"',
        'visibility': 'PRIVATE',
        'allow_ai': 1,
        'state': 'NORMAL',
        'create_time': timestamp,
        'update_time': timestamp,
      },
    ]);
    final service = AiAnalysisService(repository: repository);

    final payload = await service.buildEmotionMapPreview(
      language: AppLanguage.en,
      settings: AiSettings.defaultsFor(AppLanguage.en),
      range: DateTimeRange(start: now, end: now),
      includePrivate: true,
    );

    expect(payload.totalMatchingMemos, 1);
  });

  test(
    'buildEmotionMapPreview stops after five consecutive embedding failures',
    () async {
      final runtime = _FailingEmbeddingRuntime();
      final now = DateTime.utc(2026, 3, 11);
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;
      final memoRows = List<Map<String, dynamic>>.generate(
        10,
        (index) => <String, dynamic>{
          'uid': 'memo_$index',
          'content': 'Memo content $index',
          'visibility': 'PRIVATE',
          'allow_ai': 1,
          'state': 'NORMAL',
          'create_time': timestamp,
          'update_time': timestamp,
        },
      );
      final repository = _FakeAiAnalysisRepository(memoRows);
      const embeddingService = AiServiceInstance(
        serviceId: 'svc_embed',
        templateId: aiTemplateCustomOpenAi,
        adapterKind: AiProviderAdapterKind.openAiCompatible,
        displayName: 'Embedding Service',
        enabled: true,
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        apiKey: 'test-key',
        customHeaders: <String, String>{},
        models: <AiModelEntry>[
          AiModelEntry(
            modelId: 'mdl_embed',
            displayName: 'qwen3-vl-embedding',
            modelKey: 'qwen3-vl-embedding',
            capabilities: <AiCapability>[AiCapability.embedding],
            source: AiModelSource.manual,
            enabled: true,
          ),
        ],
        lastValidatedAt: null,
        lastValidationStatus: AiValidationStatus.unknown,
        lastValidationMessage: null,
      );
      final settings = AiSettings.defaultsFor(AppLanguage.en).copyWith(
        services: const <AiServiceInstance>[embeddingService],
        taskRouteBindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.embeddingRetrieval,
            serviceId: 'svc_embed',
            modelId: 'mdl_embed',
            capability: AiCapability.embedding,
          ),
        ],
        generationProfiles: const <AiGenerationProfile>[
          AiGenerationProfile.unconfigured,
        ],
        selectedGenerationProfileKey: '',
        embeddingProfiles: const <AiEmbeddingProfile>[
          AiEmbeddingProfile(
            profileKey: 'embed_profile',
            displayName: 'Embedding Service',
            backendKind: AiBackendKind.remoteApi,
            providerKind: AiProviderKind.openAiCompatible,
            baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
            apiKey: 'test-key',
            model: 'qwen3-vl-embedding',
            enabled: true,
          ),
        ],
        selectedEmbeddingProfileKey: 'embed_profile',
      );
      final service = AiAnalysisService(
        repository: repository,
        runtime: runtime,
      );

      final future = service.buildEmotionMapPreview(
        language: AppLanguage.en,
        settings: settings,
        range: DateTimeRange(start: now, end: now),
        includePrivate: true,
      );

      await expectLater(
        future,
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('failed 5 times in a row'),
          ),
        ),
      );
      expect(runtime.embedCalls, 5);
    },
  );

  test(
    'generateEmotionMap falls back to direct reading without embedding',
    () async {
      final support = await initializeTestSupport();
      final db = AppDatabase(
        dbName:
            'ai_analysis_direct_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final repository = AiAnalysisRepository(db);
      final runtime = _ChatOnlyRuntime();
      final now = DateTime.utc(2026, 3, 11);
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;

      addTearDown(() async {
        await db.close();
        await support.dispose();
      });

      await db.upsertMemo(
        uid: 'memo_direct_1',
        content:
            'Felt pulled in too many directions today, but a long walk helped me slow down and hear myself think again. I still felt the pressure, yet it no longer owned the whole evening.',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: timestamp,
        updateTimeSec: timestamp,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 0,
      );

      const generationService = AiServiceInstance(
        serviceId: 'svc_chat',
        templateId: aiTemplateCustomOpenAi,
        adapterKind: AiProviderAdapterKind.openAiCompatible,
        displayName: 'Chat Service',
        enabled: true,
        baseUrl: 'https://example.com/v1',
        apiKey: 'test-key',
        customHeaders: <String, String>{},
        models: <AiModelEntry>[
          AiModelEntry(
            modelId: 'mdl_chat',
            displayName: 'Chat Model',
            modelKey: 'chat-model',
            capabilities: <AiCapability>[AiCapability.chat],
            source: AiModelSource.manual,
            enabled: true,
          ),
        ],
        lastValidatedAt: null,
        lastValidationStatus: AiValidationStatus.unknown,
        lastValidationMessage: null,
      );

      final settings = AiSettings.defaultsFor(AppLanguage.en).copyWith(
        services: const <AiServiceInstance>[generationService],
        taskRouteBindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.analysisReport,
            serviceId: 'svc_chat',
            modelId: 'mdl_chat',
            capability: AiCapability.chat,
          ),
        ],
      );

      final service = AiAnalysisService(
        repository: repository,
        runtime: runtime,
      );
      final report = await service.generateEmotionMap(
        language: AppLanguage.en,
        settings: settings,
        range: DateTimeRange(start: now, end: now),
        includePrivate: true,
        promptTemplate: 'Focus on recurring pressure and recovery.',
      );

      expect(report.summary, isNotEmpty);
      expect(report.sections, isNotEmpty);
      expect(runtime.chatCalls, 1);
      expect(runtime.embedCalls, 0);
    },
  );

  test(
    'semantic memo search ranks matching chunks and respects result limit',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_rank',
      );
      addTearDown(harness.dispose);

      await harness.insertMemo(
        uid: 'memo-chicken',
        content:
            '#food\n\nDinner idea: dapanji big plate chicken with potatoes.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 3, 2),
      );
      await harness.insertMemo(
        uid: 'memo-breakfast',
        content: '#food\n\nBreakfast was congee, eggs, and warm soy milk.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 3, 3),
      );
      await harness.insertMemo(
        uid: 'memo-deadline',
        content: 'The project deadline moved after the planning meeting.',
        tags: const <String>['work'],
        createTimeSec: _utcSec(2026, 3, 4),
      );

      final result = await harness.semanticService.search(
        settings: _semanticSearchSettings,
        query: 'what to eat',
        state: 'NORMAL',
        tag: 'food',
        startTimeSec: _utcSec(2026, 3, 1),
        endTimeSecExclusive: _utcSec(2026, 3, 5),
        limit: 1,
      );

      expect(result.readyChunkCount, greaterThan(0));
      expect(result.scoredChunkCount, greaterThan(0));
      expect(result.hits.map((hit) => hit.memo.uid), <String>['memo-chicken']);
      expect(result.hits.single.score, greaterThan(0.99));
    },
  );

  test(
    'semantic memo search reports missing embedding configuration',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_missing_config',
      );
      addTearDown(harness.dispose);

      await expectLater(
        harness.semanticService.search(
          settings: AiSettings.defaultsFor(AppLanguage.en),
          query: 'what to eat',
          state: 'NORMAL',
          tag: null,
        ),
        throwsA(isA<AiSemanticMemoSearchConfigurationException>()),
      );
    },
  );

  test('semantic memo search tag filter follows recognition policy', () async {
    final harness = await _SemanticSearchHarness.create(
      dbNamePrefix: 'semantic_search_tag_policy',
    );
    addTearDown(harness.dispose);

    await harness.insertMemo(
      uid: 'memo-inline-life',
      content: 'Dinner idea: noodles #life',
      tags: const <String>['life'],
      createTimeSec: _utcSec(2026, 3, 2),
    );

    final strictService = harness.buildSemanticService(
      embedText: (_, input) async => _semanticVector(input),
      currentTagRecognitionPolicy: () => TagRecognitionPolicy.memoflowStrict,
    );
    final strict = await strictService.search(
      settings: _semanticSearchSettings,
      query: 'what to eat',
      state: 'NORMAL',
      tag: 'life',
    );
    expect(strict.hits, isEmpty);

    final compatibleService = harness.buildSemanticService(
      embedText: (_, input) async => _semanticVector(input),
      currentTagRecognitionPolicy: () => TagRecognitionPolicy.memosCompatible,
    );
    final compatible = await compatibleService.search(
      settings: _semanticSearchSettings,
      query: 'what to eat',
      state: 'NORMAL',
      tag: 'life',
    );
    expect(
      compatible.hits.map((hit) => hit.memo.uid),
      contains('memo-inline-life'),
    );
  });

  test(
    'semantic memo search tag filter follows custom recognition policy',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_custom_tag_policy',
      );
      addTearDown(harness.dispose);

      await harness.insertMemo(
        uid: 'memo-inline-custom',
        content: 'Dinner idea: noodles #life',
        tags: const <String>['life'],
        createTimeSec: _utcSec(2026, 3, 2),
      );

      final customService = harness.buildSemanticService(
        embedText: (_, input) async => _semanticVector(input),
        currentTagRecognitionPolicy: () => TagRecognitionPolicy.custom(
          const TagRecognitionCustomOptions(inlineBodyTags: false),
        ),
      );
      final result = await customService.search(
        settings: _semanticSearchSettings,
        query: 'what to eat',
        state: 'NORMAL',
        tag: 'life',
      );

      expect(result.hits, isEmpty);
    },
  );

  test(
    'semantic memo search preflight estimates first index work without writes',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_preflight_first_index',
      );
      addTearDown(harness.dispose);

      await harness.insertMemo(
        uid: 'memo-chicken',
        content: 'Dinner idea: dapanji big plate chicken with potatoes.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 3, 2),
      );

      var embedCalls = 0;
      final service = harness.buildSemanticService(
        embedText: (_, input) async {
          embedCalls += 1;
          return _semanticVector(input);
        },
      );

      final preflight = await service.estimateIndexWorkForSearchScope(
        settings: _semanticSearchSettings,
        query: 'what to eat',
        state: 'NORMAL',
        tag: null,
      );

      expect(preflight.needsIndexing, isTrue);
      expect(preflight.usesRemoteBackend, isTrue);
      expect(preflight.memoCount, 1);
      expect(preflight.chunkCount, greaterThan(0));
      expect(preflight.estimatedTokenCount, greaterThan(0));
      expect(preflight.profileKey, 'test-embedding');
      expect(preflight.model, 'test-embedding-model');
      expect(embedCalls, 0);
      expect(
        await harness.repository.listPendingIndexJobs(
          embeddingProfileKey: 'test-embedding',
        ),
        isEmpty,
      );
      expect(
        await harness.repository.listSemanticSearchCandidateChunkRows(
          includePublic: true,
          includePrivate: true,
          includeProtected: false,
          baseUrl: _semanticEmbeddingProfile.baseUrl,
          model: _semanticEmbeddingProfile.model,
        ),
        isEmpty,
      );
    },
  );

  test('semantic memo search preflight skips fresh indexes', () async {
    final harness = await _SemanticSearchHarness.create(
      dbNamePrefix: 'semantic_search_preflight_fresh',
    );
    addTearDown(harness.dispose);

    await harness.insertMemo(
      uid: 'memo-chicken',
      content: 'Dinner idea: dapanji big plate chicken with potatoes.',
      tags: const <String>['food'],
      createTimeSec: _utcSec(2026, 3, 2),
    );
    final result = await harness.semanticService.search(
      settings: _semanticSearchSettings,
      query: 'what to eat',
      state: 'NORMAL',
      tag: null,
    );
    expect(result.hits, isNotEmpty);

    final preflight = await harness.semanticService
        .estimateIndexWorkForSearchScope(
          settings: _semanticSearchSettings,
          query: 'what to eat',
          state: 'NORMAL',
          tag: null,
        );

    expect(preflight.needsIndexing, isFalse);
    expect(preflight.memoCount, 0);
    expect(preflight.chunkCount, 0);
    expect(preflight.estimatedTokenCount, 0);
  });

  test('semantic memo search preflight detects stale indexes', () async {
    final harness = await _SemanticSearchHarness.create(
      dbNamePrefix: 'semantic_search_preflight_stale',
    );
    addTearDown(harness.dispose);

    await harness.insertMemo(
      uid: 'memo-chicken',
      content: 'Dinner idea: dapanji big plate chicken with potatoes.',
      tags: const <String>['food'],
      createTimeSec: _utcSec(2026, 3, 2),
    );
    final result = await harness.semanticService.search(
      settings: _semanticSearchSettings,
      query: 'what to eat',
      state: 'NORMAL',
      tag: null,
    );
    expect(result.hits, isNotEmpty);
    await harness.insertMemo(
      uid: 'memo-chicken',
      content: 'Updated dinner idea: dapanji big plate chicken with noodles.',
      tags: const <String>['food'],
      createTimeSec: _utcSec(2026, 3, 2),
    );

    final preflight = await harness.semanticService
        .estimateIndexWorkForSearchScope(
          settings: _semanticSearchSettings,
          query: 'what to eat',
          state: 'NORMAL',
          tag: null,
        );

    expect(preflight.needsIndexing, isTrue);
    expect(preflight.memoCount, 1);
    expect(preflight.chunkCount, greaterThan(0));
    expect(preflight.estimatedTokenCount, greaterThan(0));
  });

  test(
    'semantic memo search preflight excludes policy and visibility misses',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_preflight_filters',
      );
      addTearDown(harness.dispose);

      await harness.insertMemo(
        uid: 'memo-policy-blocked',
        content: 'Dinner idea: dapanji big plate chicken with potatoes.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 3, 2),
      );
      await harness.repository.upsertMemoPolicy(
        memoUid: 'memo-policy-blocked',
        allowAi: false,
      );
      await harness.insertMemo(
        uid: 'memo-public',
        content: 'Breakfast was congee, eggs, and warm soy milk.',
        tags: const <String>['food'],
        visibility: 'PUBLIC',
        createTimeSec: _utcSec(2026, 3, 3),
      );
      await harness.insertMemo(
        uid: 'memo-protected',
        content: 'Dinner idea: chicken noodles.',
        tags: const <String>['food'],
        visibility: 'PROTECTED',
        createTimeSec: _utcSec(2026, 3, 4),
      );

      final preflight = await harness.semanticService
          .estimateIndexWorkForSearchScope(
            settings: _semanticSearchSettings,
            query: 'what to eat',
            state: 'NORMAL',
            tag: null,
            includePublic: false,
            includePrivate: true,
            includeProtected: false,
          );

      expect(preflight.needsIndexing, isFalse);
      expect(preflight.memoCount, 0);
      expect(preflight.chunkCount, 0);
      expect(preflight.estimatedTokenCount, 0);
    },
  );

  test(
    'semantic memo search preflight reports missing embedding configuration',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_preflight_missing_config',
      );
      addTearDown(harness.dispose);

      await expectLater(
        harness.semanticService.estimateIndexWorkForSearchScope(
          settings: AiSettings.defaultsFor(AppLanguage.en),
          query: 'what to eat',
          state: 'NORMAL',
          tag: null,
        ),
        throwsA(isA<AiSemanticMemoSearchConfigurationException>()),
      );
    },
  );

  test(
    'semantic memo search propagates query embedding provider errors',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_provider_error',
      );
      addTearDown(harness.dispose);

      await harness.insertMemo(
        uid: 'memo-chicken',
        content: 'Dinner idea: dapanji big plate chicken with potatoes.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 3, 2),
      );

      final warmResult = await harness.semanticService.search(
        settings: _semanticSearchSettings,
        query: 'what to eat',
        state: 'NORMAL',
        tag: null,
        limit: 10,
      );
      expect(warmResult.hits, isNotEmpty);

      final failingService = harness.buildSemanticService(
        embedText: (_, input) async {
          if (input == 'what to eat') {
            throw StateError('embedding provider unavailable');
          }
          return _semanticVector(input);
        },
      );

      await expectLater(
        failingService.search(
          settings: _semanticSearchSettings,
          query: 'what to eat',
          state: 'NORMAL',
          tag: null,
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('embedding provider unavailable'),
          ),
        ),
      );
    },
  );

  test(
    'semantic memo search returns empty results when vectors do not match',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_no_match',
      );
      addTearDown(harness.dispose);

      await harness.insertMemo(
        uid: 'memo-workout',
        content: 'Workout notes: interval running and stretching.',
        tags: const <String>['health'],
        createTimeSec: _utcSec(2026, 3, 2),
      );

      final result = await harness.semanticService.search(
        settings: _semanticSearchSettings,
        query: 'what to eat',
        state: 'NORMAL',
        tag: null,
      );

      expect(result.readyChunkCount, greaterThan(0));
      expect(result.scoredChunkCount, 0);
      expect(result.hits, isEmpty);
    },
  );

  test(
    'semantic memo search excludes policy-blocked, archived, tag, and date misses',
    () async {
      final harness = await _SemanticSearchHarness.create(
        dbNamePrefix: 'semantic_search_filters',
      );
      addTearDown(harness.dispose);

      await harness.insertMemo(
        uid: 'memo-eligible',
        content:
            '#food\n\nDinner idea: dapanji big plate chicken with potatoes.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 3, 2),
        relationCount: 1,
      );
      await harness.insertMemo(
        uid: 'memo-policy-blocked',
        content: '#food\n\nBreakfast was congee, eggs, and warm soy milk.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 3, 2),
      );
      await harness.repository.upsertMemoPolicy(
        memoUid: 'memo-policy-blocked',
        allowAi: false,
      );
      await harness.insertMemo(
        uid: 'memo-archived',
        content: '#food\n\nDinner idea: chicken noodles.',
        tags: const <String>['food'],
        state: 'ARCHIVED',
        createTimeSec: _utcSec(2026, 3, 2),
      );
      await harness.insertMemo(
        uid: 'memo-wrong-tag',
        content: 'Dinner idea: chicken soup.',
        tags: const <String>['travel'],
        createTimeSec: _utcSec(2026, 3, 2),
      );
      await harness.insertMemo(
        uid: 'memo-out-of-range',
        content: '#food\n\nDinner idea: chicken sandwich.',
        tags: const <String>['food'],
        createTimeSec: _utcSec(2026, 2, 20),
      );

      final result = await harness.semanticService.search(
        settings: _semanticSearchSettings,
        query: 'what to eat',
        state: 'NORMAL',
        tag: 'food',
        startTimeSec: _utcSec(2026, 3, 1),
        endTimeSecExclusive: _utcSec(2026, 3, 5),
        limit: 20,
      );

      expect(result.hits.map((hit) => hit.memo.uid), <String>['memo-eligible']);
    },
  );
}

const _semanticEmbeddingProfile = AiEmbeddingProfile(
  profileKey: 'test-embedding',
  displayName: 'Test Embedding',
  backendKind: AiBackendKind.remoteApi,
  providerKind: AiProviderKind.openAiCompatible,
  baseUrl: 'https://example.com/v1',
  apiKey: 'test-key',
  model: 'test-embedding-model',
  enabled: true,
);

final _semanticSearchSettings = AiSettings.defaultsFor(AppLanguage.en).copyWith(
  embeddingProfiles: const <AiEmbeddingProfile>[_semanticEmbeddingProfile],
  selectedEmbeddingProfileKey: 'test-embedding',
);

class _SemanticSearchHarness {
  _SemanticSearchHarness({
    required this.support,
    required this.dbName,
    required this.db,
    required this.repository,
  }) : semanticService = AiSemanticMemoSearchService(
         repository: repository,
         embedText: (_, input) async => _semanticVector(input),
       );

  final TestSupport support;
  final String dbName;
  final AppDatabase db;
  final AiAnalysisRepository repository;
  final AiSemanticMemoSearchService semanticService;

  static Future<_SemanticSearchHarness> create({
    required String dbNamePrefix,
  }) async {
    final support = await initializeTestSupport();
    final dbName = uniqueDbName(dbNamePrefix);
    final db = AppDatabase(dbName: dbName);
    await db.db;
    return _SemanticSearchHarness(
      support: support,
      dbName: dbName,
      db: db,
      repository: AiAnalysisRepository(db),
    );
  }

  AiSemanticMemoSearchService buildSemanticService({
    required AiSemanticTextEmbedder embedText,
    TagRecognitionPolicy Function()? currentTagRecognitionPolicy,
  }) {
    return AiSemanticMemoSearchService(
      repository: repository,
      embedText: embedText,
      currentTagRecognitionPolicy: currentTagRecognitionPolicy,
    );
  }

  Future<void> insertMemo({
    required String uid,
    required String content,
    required List<String> tags,
    required int createTimeSec,
    String visibility = 'PRIVATE',
    String state = 'NORMAL',
    int relationCount = 0,
    MemoLocation? location,
  }) {
    return db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: state,
      createTimeSec: createTimeSec,
      updateTimeSec: createTimeSec,
      tags: tags,
      attachments: const <Map<String, dynamic>>[],
      location: location,
      relationCount: relationCount,
      syncState: 0,
    );
  }

  Future<void> dispose() async {
    await db.close();
    await deleteTestDatabase(dbName);
    await support.dispose();
  }
}

List<double> _semanticVector(String input) {
  final normalized = input.toLowerCase();
  if (normalized.contains('what to eat') || normalized.contains('eat')) {
    return const <double>[1, 0, 0];
  }
  if (normalized.contains('dapanji') ||
      normalized.contains('big plate chicken')) {
    return const <double>[1, 0, 0];
  }
  if (normalized.contains('breakfast') || normalized.contains('congee')) {
    return const <double>[0.8, 0.2, 0];
  }
  if (normalized.contains('dinner') ||
      normalized.contains('chicken') ||
      normalized.contains('noodles')) {
    return const <double>[0.75, 0.25, 0];
  }
  if (normalized.contains('deadline') || normalized.contains('meeting')) {
    return const <double>[0, 1, 0];
  }
  return const <double>[0, 0, 1];
}

int _utcSec(int year, int month, int day) {
  return DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ 1000;
}
