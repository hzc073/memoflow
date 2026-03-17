import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/ai_settings_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
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

void main() {
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
}
