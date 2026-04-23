// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_models.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_repository.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/features/review/ai_analysis_preview_screen.dart';
import 'package:memos_flutter_app/features/review/ai_insight_history_shared.dart';
import 'package:memos_flutter_app/features/review/ai_insight_models.dart';
import 'package:memos_flutter_app/features/review/ai_insight_settings_sheet.dart';
import 'package:memos_flutter_app/features/review/ai_summary_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/review/ai_analysis_provider.dart';
import 'package:memos_flutter_app/state/settings/ai_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

import '../../test_support.dart';

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');

class _MemoryAiSettingsRepository extends AiSettingsRepository {
  _MemoryAiSettingsRepository(this._value)
    : super(const FlutterSecureStorage(), accountKey: 'test-account');

  AiSettings _value;

  @override
  Future<AiSettings> read({AppLanguage language = AppLanguage.en}) async =>
      _value;

  @override
  Future<void> write(AiSettings settings) async {
    _value = settings;
  }
}

class _TestAiSettingsController extends AiSettingsController {
  _TestAiSettingsController(Ref ref, this._repository)
    : super(ref, _repository);

  final _MemoryAiSettingsRepository _repository;

  @override
  Future<void> setAll(AiSettings next, {bool triggerSync = true}) async {
    state = next;
    await _repository.write(next);
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
  void setAiSummaryAllowPrivateMemos(bool value) {
    state = state.copyWith(aiSummaryAllowPrivateMemos: value);
    unawaited(_repository.write(state));
  }
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        AsyncValue.data(
          AppSessionState(
            accounts: [
              Account(
                key: 'users/1',
                baseUrl: Uri.parse('https://example.com'),
                personalAccessToken: 'token',
                user: const User(
                  name: 'users/1',
                  username: 'tester',
                  displayName: 'Tester',
                  avatarUrl: '',
                  description: '',
                ),
                instanceProfile: const InstanceProfile.empty(),
              ),
            ],
            currentKey: 'users/1',
          ),
        ),
      );

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }
}

class _FakeAiAnalysisRepository extends AiAnalysisRepository {
  _FakeAiAnalysisRepository({
    required this.historyEntries,
    Map<int, AiSavedAnalysisReport> reportsByTaskId = const {},
  }) : _reportsByTaskId = reportsByTaskId,
       super(AppDatabase(dbName: 'unused_ai_summary_test.db'));

  final List<AiSavedAnalysisHistoryEntry> historyEntries;
  final Map<int, AiSavedAnalysisReport> _reportsByTaskId;

  @override
  Future<List<AiSavedAnalysisHistoryEntry>> listAnalysisReportHistory({
    required AiAnalysisType analysisType,
    int? limit = 50,
  }) async {
    final items = historyEntries
        .where((entry) => analysisType == AiAnalysisType.emotionMap)
        .toList(growable: false);
    if (limit == null || limit <= 0 || items.length <= limit) {
      return items;
    }
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<AiSavedAnalysisReport?> loadAnalysisReportByTaskId(int taskId) async {
    return _reportsByTaskId[taskId];
  }
}

Widget _buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
  bool scaffoldBody = false,
}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: scaffoldBody ? Scaffold(body: child) : child,
      ),
    ),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 40,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async {
          switch (call.method) {
            case 'isMaximized':
              return false;
            case 'isVisible':
              return true;
            case 'isMinimized':
              return false;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
  });

  testWidgets('renders all insight cards and opens the settings sheet', (
    tester,
  ) async {
    final dbName = uniqueDbName('ai_summary_screen');
    final db = AppDatabase(dbName: dbName);
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(
        AppLanguage.en,
      ).copyWith(aiSummaryAllowPrivateMemos: true),
    );

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const AiSummaryScreen(),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
          databaseProvider.overrideWithValue(db),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AI Insight Studio'), findsNWidgets(2));
    expect(find.text('Letter Back'), findsOneWidget);

    await tester.tap(find.text('Letter Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AI Analysis Settings'), findsOneWidget);

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start Analysis'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets(
    'shows custom templates and toggles default template visibility',
    (tester) async {
      final dbName = uniqueDbName('ai_summary_custom_templates');
      final db = AppDatabase(dbName: dbName);
      final aiRepository = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en).copyWith(
          customInsightTemplates: const <AiCustomInsightTemplate>[
            AiCustomInsightTemplate(
              templateId: 'tpl_weekly',
              title: 'Weekly Lens',
              description: 'Focus on recurring weekly patterns.',
              promptTemplate: 'Analyze the last week with care.',
              iconKey: 'star',
            ),
          ],
        ),
      );
      final prefsRepository = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );

      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await tester.pumpWidget(
        _buildTestApp(
          child: const AiSummaryScreen(),
          overrides: [
            appSessionProvider.overrideWith((ref) => _TestSessionController()),
            databaseProvider.overrideWithValue(db),
            aiSettingsProvider.overrideWith(
              (ref) => _TestAiSettingsController(ref, aiRepository),
            ),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref, prefsRepository),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Default Templates'), findsOneWidget);
      expect(find.text('Custom Templates'), findsOneWidget);
      expect(find.text('Weekly Lens'), findsOneWidget);
      expect(find.byKey(const Key('aiSummaryToggleDefaultTemplatesButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('aiSummaryToggleDefaultTemplatesButton')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Show default templates'), findsOneWidget);
      expect(find.text('Letter Back'), findsNothing);
    },
  );

  testWidgets('deletes a custom template from the overflow menu', (
    tester,
  ) async {
    final dbName = uniqueDbName('ai_summary_delete_custom_template');
    final db = AppDatabase(dbName: dbName);
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        customInsightTemplates: const <AiCustomInsightTemplate>[
          AiCustomInsightTemplate(
            templateId: 'tpl_delete_me',
            title: 'Delete Me',
            description: 'Temporary custom template.',
            promptTemplate: 'Delete test prompt.',
            iconKey: 'star',
          ),
        ],
      ),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const AiSummaryScreen(),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
          databaseProvider.overrideWithValue(db),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Delete Me'), findsOneWidget);

    final popupMenuState = tester.state<PopupMenuButtonState<String>>(
      find.byType(PopupMenuButton<String>),
    );
    popupMenuState.showButtonMenu();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsNothing);
    expect(find.text('No custom templates yet'), findsOneWidget);
  });

  testWidgets('disables new template button at the 10 template limit', (
    tester,
  ) async {
    final dbName = uniqueDbName('ai_summary_custom_template_limit');
    final db = AppDatabase(dbName: dbName);
    final templates = List<AiCustomInsightTemplate>.generate(
      AiSettings.maxCustomInsightTemplateCount,
      (index) => AiCustomInsightTemplate(
        templateId: 'tpl_$index',
        title: 'Template $index',
        description: 'Description $index',
        promptTemplate: 'Prompt $index',
        iconKey: 'star',
      ),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        customInsightTemplates: templates,
      ),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const AiSummaryScreen(),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
          databaseProvider.overrideWithValue(db),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final newTemplateButton = tester.widget<FilledButton>(
      find.byKey(const Key('aiSummaryAddCustomTemplateButton')),
    );
    expect(newTemplateButton.onPressed, isNull);
    expect(
      find.text(
        '${AiSettings.maxCustomInsightTemplateCount}/${AiSettings.maxCustomInsightTemplateCount}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('history button opens saved insight history', (tester) async {
    final dbName = uniqueDbName('ai_summary_history');
    final db = AppDatabase(dbName: dbName);
    final fakeHistoryRepository = _FakeAiAnalysisRepository(
      historyEntries: const <AiSavedAnalysisHistoryEntry>[
        AiSavedAnalysisHistoryEntry(
          taskId: 1,
          taskUid: 'task-history-1',
          status: AiTaskStatus.completed,
          summary: 'A saved thought about the week.',
          promptTemplate: 'Reflect on the week with care.',
          rangeStart: 1772323200,
          rangeEndExclusive: 1772928000,
          includePublic: true,
          includePrivate: true,
          includeProtected: false,
          createdTime: 1773014400000,
          isStale: false,
        ),
      ],
    );

    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const AiSummaryScreen(),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
          databaseProvider.overrideWithValue(db),
          aiAnalysisRepositoryProvider.overrideWithValue(fakeHistoryRepository),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntilFound(tester, find.text('AI Insight Studio'));
    await _pumpUntilFound(tester, find.byTooltip('History'));

    await tester.tap(find.byTooltip('History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntilFound(tester, find.text('Insight History'));
    await _pumpUntilFound(tester, find.text('A saved thought about the week.'));

    expect(find.text('Insight History'), findsAtLeastNWidgets(1));
    expect(find.text('A saved thought about the week.'), findsOneWidget);
  });

  testWidgets('prompt editor save keeps Start Analysis enabled in the sheet', (
    tester,
  ) async {
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        generationProfiles: const <AiGenerationProfile>[
          AiGenerationProfile(
            profileKey: 'default_generation',
            displayName: 'Default Generation',
            backendKind: AiBackendKind.remoteApi,
            providerKind: AiProviderKind.openAiCompatible,
            baseUrl: 'https://example.com',
            apiKey: 'key',
            model: 'gpt-4o-mini',
            modelOptions: <String>['gpt-4o-mini'],
            enabled: true,
          ),
        ],
        selectedGenerationProfileKey: 'default_generation',
        embeddingProfiles: const <AiEmbeddingProfile>[
          AiEmbeddingProfile(
            profileKey: 'default_embedding',
            displayName: 'Default Embedding',
            backendKind: AiBackendKind.remoteApi,
            providerKind: AiProviderKind.openAiCompatible,
            baseUrl: 'https://example.com',
            apiKey: 'key',
            model: 'text-embedding-3-small',
            enabled: true,
          ),
        ],
        selectedEmbeddingProfileKey: 'default_embedding',
      ),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );

    await tester.pumpWidget(
      _buildTestApp(
        child: AiInsightSettingsSheet(
          definition: visibleAiInsightDefinitions.first,
        ),
        scaffoldBody: true,
        overrides: [
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    FilledButton startButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start Analysis'),
    );

    expect(startButton().onPressed, isNotNull);

    await tester.ensureVisible(find.text('Edit Prompt Template'));
    await tester.tap(find.text('Edit Prompt Template'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Find the most important unresolved tension.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(startButton().onPressed, isNotNull);
  });

  testWidgets('local AI providers without API keys can start analysis', (
    tester,
  ) async {
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        services: const <AiServiceInstance>[
          AiServiceInstance(
            serviceId: 'svc_local',
            templateId: aiTemplateOllama,
            adapterKind: AiProviderAdapterKind.ollama,
            displayName: 'Local Ollama',
            enabled: true,
            baseUrl: 'http://127.0.0.1:11434',
            apiKey: '',
            customHeaders: <String, String>{},
            models: <AiModelEntry>[
              AiModelEntry(
                modelId: 'mdl_chat',
                displayName: 'llama3.1',
                modelKey: 'llama3.1',
                capabilities: <AiCapability>[AiCapability.chat],
                source: AiModelSource.manual,
                enabled: true,
              ),
              AiModelEntry(
                modelId: 'mdl_embed',
                displayName: 'bge-m3',
                modelKey: 'bge-m3',
                capabilities: <AiCapability>[AiCapability.embedding],
                source: AiModelSource.manual,
                enabled: true,
              ),
            ],
            lastValidatedAt: null,
            lastValidationStatus: AiValidationStatus.unknown,
            lastValidationMessage: null,
          ),
        ],
        taskRouteBindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.analysisReport,
            serviceId: 'svc_local',
            modelId: 'mdl_chat',
            capability: AiCapability.chat,
          ),
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.embeddingRetrieval,
            serviceId: 'svc_local',
            modelId: 'mdl_embed',
            capability: AiCapability.embedding,
          ),
        ],
      ),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );

    await tester.pumpWidget(
      _buildTestApp(
        child: AiInsightSettingsSheet(
          definition: visibleAiInsightDefinitions.first,
        ),
        scaffoldBody: true,
        overrides: [
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start Analysis'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('custom range picker refreshes preview payload', (tester) async {
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        insightPromptTemplates: const <String, String>{
          'emotion_map': 'Focus on recent shifts.',
        },
      ),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final pickedRange = DateTimeRange(
      start: DateTime(2026, 2, 1),
      end: DateTime(2026, 2, 10),
    );

    await tester.pumpWidget(
      _buildTestApp(
        child: AiInsightSettingsSheet(
          definition: visibleAiInsightDefinitions.first,
          customRangePicker: (context, currentRange) async => pickedRange,
        ),
        scaffoldBody: true,
        overrides: [
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom range'));
    await tester.pumpAndSettle();

    expect(find.text('2026.02.01 - 2026.02.10'), findsOneWidget);
  });

  testWidgets('preview screen shows note counts and truncation notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: AiAnalysisPreviewScreen(
          definition: visibleAiInsightDefinitions.first,
          allowPublic: true,
          allowPrivate: true,
          allowProtected: false,
          rangeLabel: '2026.03.01 - 2026.03.07',
          payload: AiAnalysisPreviewPayload(
            totalMatchingMemos: 3,
            candidateChunks: 2,
            embeddingReady: 1,
            embeddingPending: 1,
            embeddingFailed: 0,
            isSampled: true,
            items: <AiPreviewMemoItem>[
              AiPreviewMemoItem(
                memoUid: 'memo-1',
                chunkId: 1,
                createdAt: DateTime(2026, 3, 6),
                content: 'First note',
                visibility: 'PRIVATE',
                embeddingStatus: AiEmbeddingStatus.ready,
              ),
              AiPreviewMemoItem(
                memoUid: 'memo-2',
                chunkId: 2,
                createdAt: DateTime(2026, 3, 7),
                content: 'Second note',
                visibility: 'PRIVATE',
                embeddingStatus: AiEmbeddingStatus.pending,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Retrieval Preview'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('First note'), findsOneWidget);
    expect(find.text('Second note'), findsOneWidget);
  });

  testWidgets('analysis can start with chat model only', (tester) async {
    final dbName = uniqueDbName('ai_summary_chat_only');
    final db = AppDatabase(dbName: dbName);
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
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        services: const <AiServiceInstance>[generationService],
        taskRouteBindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.analysisReport,
            serviceId: 'svc_chat',
            modelId: 'mdl_chat',
            capability: AiCapability.chat,
          ),
        ],
      ),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(
        AppLanguage.en,
      ).copyWith(aiSummaryAllowPrivateMemos: true),
    );

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const AiSummaryScreen(),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
          databaseProvider.overrideWithValue(db),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Letter Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('analysis accuracy may be lower'), findsWidgets);

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start Analysis'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('initial history selection opens the report view directly', (
    tester,
  ) async {
    final dbName = uniqueDbName('ai_summary_initial_history');
    final db = AppDatabase(dbName: dbName);
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    const report = AiSavedAnalysisReport(
      taskId: 42,
      taskUid: 'task-initial-history',
      status: AiTaskStatus.completed,
      summary: 'Saved summary from history.',
      sections: <AiAnalysisSectionData>[
        AiAnalysisSectionData(
          sectionKey: 'main',
          title: 'Overview',
          body: 'This is loaded straight into the report view.',
          evidenceKeys: <String>[],
        ),
      ],
      evidences: <AiAnalysisEvidenceData>[],
      followUpSuggestions: <String>['Keep going'],
      isStale: false,
    );

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: AiSummaryScreen(
          initialHistorySelection: AiInsightHistorySelection(
            report: report,
            rangeStart: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch ~/ 1000,
            rangeEndExclusive:
                DateTime.utc(2026, 3, 8).millisecondsSinceEpoch ~/ 1000,
            insightId: AiInsightId.emotionMap,
            titleOverride: 'History Entry',
          ),
        ),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
          databaseProvider.overrideWithValue(db),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('History Entry'), findsWidgets);
    expect(find.text('Saved summary from history.'), findsOneWidget);
    expect(
      find.text('This is loaded straight into the report view.'),
      findsOneWidget,
    );
  });
}
