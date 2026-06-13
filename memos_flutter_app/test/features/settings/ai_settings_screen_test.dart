// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/ai_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/ai_proxy_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/ai_provider_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/ai_service_detail_screen.dart';
import 'package:memos_flutter_app/features/settings/ai_service_model_screen.dart';
import 'package:memos_flutter_app/features/settings/ai_service_wizard_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/settings/ai_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';

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
    final normalized = AiSettingsMigration.normalize(next);
    state = normalized;
    await _repository.write(normalized);
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
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref, this._repository)
    : super(ref, _repository, onLoaded: () {}) {
    state = _repository._prefs;
  }

  final _MemoryAppPreferencesRepository _repository;
}

const _openAiService = AiServiceInstance(
  serviceId: 'svc_openai',
  templateId: aiTemplateOpenAi,
  adapterKind: AiProviderAdapterKind.openAiCompatible,
  displayName: 'OpenAI Main',
  enabled: true,
  baseUrl: 'https://api.openai.com',
  apiKey: 'sk-test',
  customHeaders: <String, String>{},
  models: <AiModelEntry>[
    AiModelEntry(
      modelId: 'mdl_openai',
      displayName: 'gpt-4o-mini',
      modelKey: 'gpt-4o-mini',
      capabilities: <AiCapability>[AiCapability.chat],
      source: AiModelSource.manual,
      enabled: true,
    ),
    AiModelEntry(
      modelId: 'mdl_embedding',
      displayName: 'text-embedding-3-small',
      modelKey: 'text-embedding-3-small',
      capabilities: <AiCapability>[AiCapability.embedding],
      source: AiModelSource.manual,
      enabled: true,
    ),
  ],
  lastValidatedAt: null,
  lastValidationStatus: AiValidationStatus.success,
  lastValidationMessage: null,
);

AiSettings _settingsWithOpenAiService({
  AiServiceInstance service = _openAiService,
  AiProxySettings proxySettings = AiProxySettings.defaults,
  List<AiTaskRouteBinding> taskRouteBindings = const <AiTaskRouteBinding>[],
}) {
  return AiSettings.defaultsFor(AppLanguage.en).copyWith(
    proxySettings: proxySettings,
    services: <AiServiceInstance>[service],
    taskRouteBindings: taskRouteBindings,
  );
}

Widget _buildAiSettingsTestApp({
  required _MemoryAppPreferencesRepository prefsRepository,
  required _MemoryAiSettingsRepository aiRepository,
  bool showBackButton = false,
  List<Override> overrides = const <Override>[],
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      appPreferencesProvider.overrideWith(
        (ref) => _TestAppPreferencesController(ref, prefsRepository),
      ),
      aiSettingsProvider.overrideWith(
        (ref) => _TestAiSettingsController(ref, aiRepository),
      ),
      ...overrides,
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home ?? AiSettingsScreen(showBackButton: showBackButton),
      ),
    ),
  );
}

class _SuccessValidationAdapter implements AiProviderAdapter {
  const _SuccessValidationAdapter();

  @override
  Future<AiServiceValidationResult> validateConfig(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) async {
    return const AiServiceValidationResult(
      status: AiValidationStatus.success,
      message: 'ok',
    );
  }

  @override
  Future<List<AiDiscoveredModel>> listModels(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AiChatCompletionResult> chatCompletion(
    AiChatCompletionRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<double>> embed(AiEmbeddingRequest request) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    debugPlatformTargetOverride = null;
  });

  tearDown(() {
    debugPlatformTargetOverride = null;
  });

  testWidgets('AiSettingsScreen renders service overview and route entry', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        proxySettings: const AiProxySettings(
          protocol: AiProxyProtocol.http,
          host: 'proxy.example.com',
          port: 8080,
        ),
        services: const <AiServiceInstance>[
          AiServiceInstance(
            serviceId: 'svc_openai',
            templateId: aiTemplateOpenAi,
            adapterKind: AiProviderAdapterKind.openAiCompatible,
            displayName: 'OpenAI Main',
            enabled: true,
            baseUrl: 'https://api.openai.com',
            apiKey: 'sk-test',
            customHeaders: <String, String>{},
            models: <AiModelEntry>[
              AiModelEntry(
                modelId: 'mdl_openai',
                displayName: 'gpt-4o-mini',
                modelKey: 'gpt-4o-mini',
                capabilities: <AiCapability>[AiCapability.chat],
                source: AiModelSource.manual,
                enabled: true,
              ),
              AiModelEntry(
                modelId: 'mdl_embedding',
                displayName: 'text-embedding-3-small',
                modelKey: 'text-embedding-3-small',
                capabilities: <AiCapability>[AiCapability.embedding],
                source: AiModelSource.manual,
                enabled: true,
              ),
            ],
            lastValidatedAt: null,
            lastValidationStatus: AiValidationStatus.success,
            lastValidationMessage: null,
          ),
        ],
        taskRouteBindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.summary,
            serviceId: 'svc_openai',
            modelId: 'mdl_openai',
            capability: AiCapability.chat,
          ),
        ],
        embeddingProfiles: const <AiEmbeddingProfile>[
          AiEmbeddingProfile(
            profileKey: 'default_embedding',
            displayName: 'Default Embedding',
            backendKind: AiBackendKind.remoteApi,
            providerKind: AiProviderKind.openAiCompatible,
            baseUrl: 'https://api.openai.com',
            apiKey: 'sk-test',
            model: 'text-embedding-3-small',
            enabled: true,
          ),
        ],
        selectedEmbeddingProfileKey: 'default_embedding',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const AiSettingsScreen(showBackButton: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Service Overview'), findsNothing);
    expect(find.text('OpenAI Main'), findsOneWidget);
    expect(find.text('Proxy Settings'), findsOneWidget);
    expect(find.text('HTTP · proxy.example.com:8080'), findsOneWidget);
    expect(find.text('Default Usage'), findsNothing);
    expect(find.text('gpt-4o-mini'), findsWidgets);
    expect(find.text('text-embedding-3-small'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.byTooltip('Default service'), findsNothing);

    await tester.tap(find.text('OpenAI Main'));
    await tester.pumpAndSettle();

    expect(find.text('Service Details'), findsOneWidget);
  });

  testWidgets('AiSettingsScreen shows empty state when no service exists', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const AiSettingsScreen(showBackButton: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No AI services yet. Tap Add Service to get started.'),
      findsOneWidget,
    );
    expect(find.text('Add Service'), findsOneWidget);
    expect(find.text('Proxy Settings'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
  });

  testWidgets('desktop add service opens wizard in task surface', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.windows;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const AiSettingsScreen(showBackButton: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Service').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('platform-secondary-task-surface-dialog'),
      ),
      findsOneWidget,
    );
    expect(find.byType(AiServiceWizardScreen), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Add Service'), findsWidgets);
  });

  testWidgets('desktop service detail opens in task surface', (tester) async {
    debugPlatformTargetOverride = TargetPlatform.macOS;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      _settingsWithOpenAiService(),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenAI Main'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('platform-secondary-task-surface-dialog'),
      ),
      findsOneWidget,
    );
    expect(find.byType(AiServiceDetailScreen), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('mobile service detail keeps route presentation', (tester) async {
    debugPlatformTargetOverride = TargetPlatform.android;
    addTearDown(() => debugPlatformTargetOverride = null);

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      _settingsWithOpenAiService(),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenAI Main'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AiServiceDetailScreen), findsOneWidget);
    expect(find.text('Service Details'), findsOneWidget);
  });

  testWidgets('service detail confirms unsaved close and saves from prompt', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.macOS;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      _settingsWithOpenAiService(),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenAI Main'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'OpenAI Updated');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Save changes?'), findsOneWidget);

    await tester.tap(find.text('Continue editing'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsNothing);
    expect(find.byType(AiServiceDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and close'));
    await tester.pumpAndSettle();

    expect(find.byType(AiServiceDetailScreen), findsNothing);
    expect(find.text('OpenAI Updated'), findsOneWidget);
    final saved = await aiRepository.read();
    expect(saved.services.single.displayName, 'OpenAI Updated');
  });

  testWidgets('service detail connection check does not create dirty state', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.macOS;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      _settingsWithOpenAiService(),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
        overrides: [
          aiProviderRegistryProvider.overrideWith(
            (ref) => AiProviderRegistry(
              adapters: const <AiProviderAdapterKind, AiProviderAdapter>{
                AiProviderAdapterKind.openAiCompatible:
                    _SuccessValidationAdapter(),
              },
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenAI Main'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('Connection check succeeded.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Save changes?'), findsNothing);
    expect(find.byType(AiServiceDetailScreen), findsNothing);
    final saved = await aiRepository.read();
    expect(saved.services.single.lastValidationMessage, 'ok');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('service detail delete closes task and removes service', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.macOS;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      _settingsWithOpenAiService(),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenAI Main'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete Service'),
      420,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('ai-service-detail-scroll-view'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 8,
    );
    await tester.tap(
      find
          .ancestor(
            of: find.text('Delete Service'),
            matching: find.byType(InkWell),
          )
          .last,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(AiServiceDetailScreen), findsNothing);
    expect(find.text('OpenAI Main'), findsNothing);
    final saved = await aiRepository.read();
    expect(saved.services, isEmpty);
  });

  testWidgets('service detail proxy entry keeps existing nested route', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.macOS;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      _settingsWithOpenAiService(),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenAI Main'));
    await tester.pumpAndSettle();
    tester
        .widget<SettingsToggleRow>(
          find.widgetWithText(SettingsToggleRow, 'Use shared proxy'),
        )
        .onChanged!(true);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This service has proxy enabled, but shared proxy settings are incomplete.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open proxy settings'), findsOneWidget);

    await tester.ensureVisible(find.text('Open proxy settings'));
    tester
        .widget<SettingsAction>(
          find.widgetWithText(SettingsAction, 'Open proxy settings'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(AiProxySettingsScreen), findsOneWidget);
    expect(
      find.byType(AiServiceDetailScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('iOS model editor uses settings control seams', (tester) async {
    debugPlatformTargetOverride = TargetPlatform.iOS;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      _settingsWithOpenAiService(),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
        home: const AiServiceModelScreen(serviceId: 'svc_openai'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsActionPill), findsWidgets);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.text('Add Model').first);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsFormDialog), findsOneWidget);
    expect(find.byType(SettingsDialogTextField), findsWidgets);
    expect(find.byType(SettingsMultiChoiceList<AiCapability>), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('iOS legacy provider settings form uses settings seams', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.iOS;
    addTearDown(() => debugPlatformTargetOverride = null);
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(
      _buildAiSettingsTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
        home: const AiProviderSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsDialogTextField), findsWidgets);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('mobile add service keeps route presentation', (tester) async {
    debugPlatformTargetOverride = TargetPlatform.android;
    addTearDown(() => debugPlatformTargetOverride = null);

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const AiSettingsScreen(showBackButton: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Service').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AiServiceWizardScreen), findsOneWidget);
    expect(find.text('Add Service'), findsWidgets);
  });
}
