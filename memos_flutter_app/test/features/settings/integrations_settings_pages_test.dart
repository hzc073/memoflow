import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/top_toast.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/user_setting.dart';
import 'package:memos_flutter_app/features/settings/api_plugins_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/features/settings/webhooks_settings_screen.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/user_settings_provider.dart';

import 'settings_test_harness.dart';

void main() {
  tearDown(() {
    dismissTopToast();
    debugPlatformTargetOverride = null;
  });

  testWidgets('API plugins page uses settings seams and keeps unsigned guard', (
    tester,
  ) async {
    var apiRead = false;

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const ApiPluginsScreen(),
        overrides: [
          memosApiProvider.overrideWith((ref) {
            apiRead = true;
            throw StateError('memosApiProvider should not be read');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsNWidgets(2));
    expect(find.byType(SettingsValueRow), findsOneWidget);
    expect(find.byType(SettingsAction), findsOneWidget);
    expect(find.byType(SettingsInfoRow), findsOneWidget);
    expect(find.text('API & Plugins'), findsOneWidget);
    expect(find.text('Create New Token'), findsOneWidget);
    expect(find.text('No tokens yet'), findsOneWidget);
    expect(apiRead, isFalse);

    await tester.tap(find.text('Create Token'));
    await tester.pump();

    expect(find.text('Please enter token name'), findsOneWidget);
    expect(apiRead, isFalse);

    expect(find.byType(SettingsDialogTextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'test token');
    await tester.tap(find.text('Create Token'));
    await tester.pump();

    expect(find.text('Not signed in'), findsOneWidget);
    expect(apiRead, isFalse);

    dismissTopToast();
    await tester.pump();
  });

  testWidgets('webhooks page uses settings seams for loaded rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const WebhooksSettingsScreen(),
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) => _TestDevicePreferencesController(ref),
          ),
          userWebhooksProvider.overrideWith(
            (ref) async => const [
              UserWebhook(
                name: 'users/1/webhooks/alpha',
                url: 'https://example.com/webhook',
                displayName: 'Deploy hook',
                createTime: null,
                updateTime: null,
                legacyId: null,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsSection), findsOneWidget);
    expect(find.text('Webhooks'), findsOneWidget);
    expect(find.text('Deploy hook'), findsOneWidget);
    expect(find.text('https://example.com/webhook'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('webhooks page uses settings seams for empty rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const WebhooksSettingsScreen(),
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) => _TestDevicePreferencesController(ref),
          ),
          userWebhooksProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsInfoRow), findsOneWidget);
    expect(find.text('No webhooks configured'), findsOneWidget);
  });

  testWidgets('webhooks page uses settings seams for error rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const WebhooksSettingsScreen(),
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) => _TestDevicePreferencesController(ref),
          ),
          userWebhooksProvider.overrideWith(
            (ref) async => throw StateError('load failed'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Failed to load'), findsOneWidget);
    expect(find.text('Failed to load. Please try again.'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
  });

  testWidgets('API plugin field seam renders on iOS', (tester) async {
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const ApiPluginsScreen(),
        overrides: [
          memosApiProvider.overrideWith((ref) {
            throw StateError('memosApiProvider should not be read');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsDialogTextField), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('webhooks editor form seam renders on iOS', (tester) async {
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const WebhooksSettingsScreen(),
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) => _TestDevicePreferencesController(ref),
          ),
          userWebhooksProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsFormDialog), findsOneWidget);
    expect(find.byType(SettingsDialogTextField), findsNWidgets(2));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository()
    : _prefs = DevicePreferences.defaultsForLanguage(AppLanguage.en),
      super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _prefs;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<DevicePreferences> read() async {
    return _prefs;
  }

  @override
  Future<void> write(DevicePreferences prefs) async {
    _prefs = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(Ref ref)
    : super(ref, _TestDevicePreferencesRepository());
}
