import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/ai_proxy_settings_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/settings/ai_settings_provider.dart';

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

Widget _buildTestApp(_MemoryAiSettingsRepository repository) {
  return ProviderScope(
    overrides: [
      aiSettingsProvider.overrideWith(
        (ref) => _TestAiSettingsController(ref, repository),
      ),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AiProxySettingsScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('AiProxySettingsScreen shows proxy test area with Google default', (
    tester,
  ) async {
    final repository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Proxy Test'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);
    final urlField = tester.widget<TextFormField>(find.byType(TextFormField).at(4));
    expect(urlField.controller?.text, 'https://www.google.com');
  });

  testWidgets('AiProxySettingsScreen clears an existing proxy configuration', (
    tester,
  ) async {
    final repository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en).copyWith(
        proxySettings: const AiProxySettings(
          protocol: AiProxyProtocol.http,
          host: 'proxy.example.com',
          port: 8080,
          username: 'demo',
          password: 'secret',
          bypassLocalAddresses: false,
        ),
      ),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(repository.value.proxySettings.isConfigured, isFalse);
    expect(repository.value.proxySettings.host, isEmpty);
    expect(repository.value.proxySettings.port, 0);
  });

  testWidgets('AiProxySettingsScreen validates host and port before saving', (
    tester,
  ) async {
    final repository = _MemoryAiSettingsRepository(
      AiSettings.defaultsFor(AppLanguage.en),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'proxy.example.com');
    await tester.enterText(find.byType(TextFormField).at(1), '70000');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(repository.value.proxySettings.isConfigured, isFalse);
    expect(repository.value.proxySettings.host, isEmpty);
    expect(repository.value.proxySettings.port, 0);
  });

  testWidgets(
    'AiProxySettingsScreen saves SOCKS5 settings and persists bypass toggle',
    (tester) async {
      final repository = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('HTTP').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SOCKS5').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'proxy.example.com');
      await tester.enterText(find.byType(TextFormField).at(1), '1080');
      await tester.enterText(find.byType(TextFormField).at(2), 'demo');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret');
      await tester.tap(
        find.widgetWithText(
          SwitchListTile,
          'Automatically bypass local/private addresses',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(repository.value.proxySettings.protocol, AiProxyProtocol.socks5);
      expect(repository.value.proxySettings.host, 'proxy.example.com');
      expect(repository.value.proxySettings.port, 1080);
      expect(repository.value.proxySettings.username, 'demo');
      expect(repository.value.proxySettings.password, 'secret');
      expect(repository.value.proxySettings.bypassLocalAddresses, isFalse);
    },
  );
}
