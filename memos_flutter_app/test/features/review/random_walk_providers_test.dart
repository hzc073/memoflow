import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_models.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_repository.dart';
import 'package:memos_flutter_app/data/api/memos_api.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/features/review/random_walk_models.dart';
import 'package:memos_flutter_app/features/review/random_walk_providers.dart';
import 'package:memos_flutter_app/state/review/ai_analysis_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  group('collectExploreRandomWalkEntries', () {
    test('includes creatorRef and creatorFallback for explore memos', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        if (request.uri.path != '/api/v1/memos') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'memos': [
              {
                'name': 'memos/explore-1',
                'creator': 'users/alice',
                'content': 'Explore memo',
                'visibility': 'PUBLIC',
                'pinned': false,
                'state': 'NORMAL',
                'createTime': DateTime.utc(2024, 1, 1, 8).toIso8601String(),
                'updateTime': DateTime.utc(2024, 1, 1, 8).toIso8601String(),
                'tags': <String>[],
                'attachments': <Object>[],
              },
            ],
            'nextPageToken': '',
          }),
        );
        await request.response.close();
      });

      final baseUrl = Uri.parse('http://127.0.0.1:${server.port}/');
      final api = MemosApi.unauthenticated(
        baseUrl,
        instanceProfile: InstanceProfile(
          version: '0.26.1',
          mode: 'prod',
          instanceUrl: baseUrl.toString(),
          owner: 'tester',
        ),
      );

      final entries = await collectExploreRandomWalkEntries(
        api: api,
        query: RandomWalkQuery(
          source: RandomWalkSourceScope.exploreMemos,
          selectedTagKeys: const [],
          dateStartSec: null,
          dateEndSecExclusive: null,
          sampleLimit: 10,
          sampleSeed: 7,
        ),
        tagColors: TagColorLookup(const []),
        includeProtected: false,
      );

      expect(entries, hasLength(1));
      expect(entries.single.memoOrigin, RandomWalkMemoOrigin.explore);
      expect(entries.single.creatorRef, 'users/alice');
      expect(entries.single.creatorFallback, 'alice');
    });
  });

  group('randomWalkDeckProvider aiHistory', () {
    test('hydrates fullBodyText from the saved analysis report', () async {
      final historyEntry = AiSavedAnalysisHistoryEntry(
        taskId: 42,
        taskUid: 'task-42',
        status: AiTaskStatus.completed,
        summary: 'Short summary',
        promptTemplate: 'Prompt',
        rangeStart: 0,
        rangeEndExclusive: 0,
        includePublic: true,
        includePrivate: true,
        includeProtected: false,
        createdTime: DateTime.utc(2024, 1, 2, 18).millisecondsSinceEpoch,
        isStale: false,
      );
      final report = AiSavedAnalysisReport(
        taskId: 42,
        taskUid: 'task-42',
        status: AiTaskStatus.completed,
        summary: 'Short summary',
        sections: const [
          AiAnalysisSectionData(
            sectionKey: 'pattern',
            title: 'Pattern',
            body: 'Narrative detail',
            evidenceKeys: ['e1'],
          ),
          AiAnalysisSectionData(
            sectionKey: 'closing',
            title: 'Closing',
            body: 'Closing thought',
            evidenceKeys: [],
          ),
        ],
        evidences: const [
          AiAnalysisEvidenceData(
            evidenceKey: 'e1',
            sectionKey: 'pattern',
            memoUid: 'memo-1',
            chunkId: 1,
            quoteText: 'A memorable quote',
            charStart: 0,
            charEnd: 16,
            relevanceScore: 0.85,
          ),
        ],
        followUpSuggestions: const ['Fallback close'],
        isStale: false,
      );
      final prefsRepo = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );
      final container = ProviderContainer(
        overrides: [
          aiAnalysisRepositoryProvider.overrideWithValue(
            _FakeAiAnalysisRepository(
              history: [historyEntry],
              reportsByTaskId: {42: report},
            ),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepo),
          ),
        ],
      );
      addTearDown(container.dispose);

      final entries = await container.read(
        randomWalkDeckProvider(
          RandomWalkQuery(
            source: RandomWalkSourceScope.aiHistory,
            selectedTagKeys: const [],
            dateStartSec: null,
            dateEndSecExclusive: null,
            sampleLimit: 10,
            sampleSeed: 11,
          ),
        ).future,
      );

      expect(entries, hasLength(1));
      expect(entries.single.fullBodyText, isNot('Short summary'));
      expect(entries.single.fullBodyText, contains('Narrative detail'));
      expect(entries.single.fullBodyText, contains('Closing thought'));
      expect(entries.single.fullBodyText, contains('A memorable quote'));
    });
  });
}

class _FakeAiAnalysisRepository extends AiAnalysisRepository {
  _FakeAiAnalysisRepository({
    required this.history,
    required this.reportsByTaskId,
  }) : super(AppDatabase(dbName: 'random_walk_provider_test.db'));

  final List<AiSavedAnalysisHistoryEntry> history;
  final Map<int, AiSavedAnalysisReport> reportsByTaskId;

  @override
  Future<List<AiSavedAnalysisHistoryEntry>> listAnalysisReportHistory({
    required AiAnalysisType analysisType,
    int? limit = 50,
  }) async {
    if (limit == null || limit >= history.length) {
      return history;
    }
    return history.take(limit).toList(growable: false);
  }

  @override
  Future<AiSavedAnalysisReport?> loadAnalysisReportByTaskId(int taskId) async {
    return reportsByTaskId[taskId];
  }
}

class _MemoryAppPreferencesRepository extends AppPreferencesRepository {
  _MemoryAppPreferencesRepository(this._prefs)
    : super(const FlutterSecureStorage(), accountKey: null);

  AppPreferences _prefs;

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<AppPreferences> read() async => _prefs;

  @override
  Future<void> write(AppPreferences prefs) async {
    _prefs = prefs;
  }

  @override
  Future<void> clear() async {
    _prefs = AppPreferences.defaultsForLanguage(AppLanguage.en);
  }
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref, this._repository)
    : super(
        ref,
        _repository,
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      ) {
    state = _repository._prefs;
  }

  final _MemoryAppPreferencesRepository _repository;

  @override
  Future<void> reloadFromStorage() async {
    state = _repository._prefs;
  }
}
