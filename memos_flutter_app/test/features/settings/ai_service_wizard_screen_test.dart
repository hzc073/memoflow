import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/ai_service_wizard_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/settings/ai_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';

class _MemoryAiSettingsRepository extends AiSettingsRepository {
  _MemoryAiSettingsRepository(this.value)
    : super(const FlutterSecureStorage(), accountKey: 'test-account');

  AiSettings value;

  @override
  Future<AiSettings> read({AppLanguage language = AppLanguage.en}) async =>
      value;

  @override
  Future<void> write(AiSettings settings) async {
    value = settings;
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

Widget _buildTestApp({
  required _MemoryAppPreferencesRepository prefsRepository,
  required _MemoryAiSettingsRepository aiRepository,
}) {
  return ProviderScope(
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
        home: const AiServiceWizardScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('AiServiceWizardScreen renders unified provider picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(
      _buildTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cloud'), findsNothing);
    expect(find.text('Local'), findsNothing);
    expect(find.text('Custom'), findsNothing);
    expect(find.text('OpenAI'), findsWidgets);
    expect(find.text('Ollama'), findsOneWidget);
    expect(find.text('AiHubMix'), findsOneWidget);
    expect(find.text('GitHub Models'), findsOneWidget);
    expect(find.text('Add Custom Model'), findsOneWidget);
  });

  testWidgets('AiServiceWizardScreen renders expanded provider catalog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefsRepository = _MemoryAppPreferencesRepository(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
    final aiRepository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(
      _buildTestApp(
        prefsRepository: prefsRepository,
        aiRepository: aiRepository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CherryIN'), findsOneWidget);
    expect(find.text('OpenVINO Model Server'), findsOneWidget);
    expect(find.text('Perplexity'), findsOneWidget);
    expect(find.text('Hugging Face'), findsOneWidget);
    expect(find.text('VoyageAI'), findsOneWidget);
    expect(find.text('Cerebras'), findsOneWidget);
  });

  testWidgets(
    'AiServiceWizardScreen shows proxy warning and opens proxy settings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1120, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefsRepository = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );
      final aiRepository = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );

      await tester.pumpWidget(
        _buildTestApp(
          prefsRepository: prefsRepository,
          aiRepository: aiRepository,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('OpenAI').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next').last);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Next').last,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Use shared proxy'), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Use shared proxy'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This service has proxy enabled, but shared proxy settings are incomplete.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open proxy settings'), findsOneWidget);

      await tester.tap(find.text('Open proxy settings'));
      await tester.pumpAndSettle();

      expect(find.text('Proxy Settings'), findsOneWidget);
    },
  );
}
