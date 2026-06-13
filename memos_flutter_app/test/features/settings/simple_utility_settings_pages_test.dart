import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/top_toast.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/data/repositories/memo_template_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/features/settings/template_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/widgets_screen.dart';
import 'package:memos_flutter_app/state/settings/memo_template_settings_provider.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'settings_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'MemoFlow',
      packageName: 'dev.memoflow.test',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
      installerStore: null,
    );
  });

  tearDown(() {
    dismissTopToast();
    debugPlatformTargetOverride = null;
  });

  testWidgets('template settings page uses settings seams and opens dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const TemplateSettingsScreen(),
        overrides: [
          memoTemplateSettingsProvider.overrideWith(
            (ref) => _TestMemoTemplateSettingsController(
              ref,
              MemoTemplateSettings(
                enabled: true,
                templates: const [
                  MemoTemplate(
                    id: 'daily',
                    name: 'Daily note',
                    content: 'Today I noticed {{date}}',
                  ),
                ],
                variables: MemoTemplateVariableSettings.defaults.copyWith(
                  weatherEnabled: true,
                  weatherCity: 'Beijing',
                ),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsToggleCard), findsOneWidget);
    expect(find.byType(SettingsSection), findsNWidgets(2));
    expect(find.byType(SettingsNavigationRow), findsNWidgets(2));
    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Daily note'), findsOneWidget);
    expect(find.text('Today I noticed {{date}}'), findsOneWidget);
    expect(find.text('Template variables'), findsOneWidget);
    expect(find.text('Weather variables: Beijing'), findsOneWidget);

    await tester.tap(find.text('Available variable docs'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Date/time variables follow the formats in Variable settings; weather variables depend on AMap weather configuration.',
      ),
      findsOneWidget,
    );
    expect(find.text('{{date}}'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('template dialogs use settings form seams on iOS', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const TemplateSettingsScreen(),
        overrides: [
          memoTemplateSettingsProvider.overrideWith(
            (ref) => _TestMemoTemplateSettingsController(
              ref,
              MemoTemplateSettings(
                enabled: true,
                templates: const [
                  MemoTemplate(
                    id: 'daily',
                    name: 'Daily note',
                    content: 'Today I noticed {{date}}',
                  ),
                ],
                variables: MemoTemplateVariableSettings.defaults.copyWith(
                  weatherEnabled: true,
                  weatherCity: 'Beijing',
                ),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Available variable docs'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsFormDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.widgetWithText(SettingsDialogAction, 'Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Template variables'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsFormDialog), findsOneWidget);
    expect(find.byType(SettingsDialogTextField), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'widgets page uses settings seams and keeps unsupported add toast',
    (tester) async {
      await tester.pumpWidget(
        buildSettingsTestApp(home: const WidgetsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(SettingsSection), findsNWidgets(3));
      expect(find.byType(SettingsAction), findsNWidgets(3));
      expect(find.text('Widgets'), findsOneWidget);
      expect(find.text('Random Review'), findsWidgets);
      expect(find.text('Quick Input'), findsOneWidget);
      expect(find.text('Activity Heatmap'), findsOneWidget);
      expect(find.text('MemoFlow | v1.2.3'), findsOneWidget);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await tester.tap(find.text('Add to Home Screen').first);
      debugDefaultTargetPlatformOverride = null;
      await tester.pump();

      expect(
        find.text('One-tap add not supported. Add it from the widget picker'),
        findsOneWidget,
      );
      dismissTopToast();
    },
  );
}

class _TestMemoTemplateSettingsController
    extends MemoTemplateSettingsController {
  _TestMemoTemplateSettingsController(Ref ref, MemoTemplateSettings settings)
    : super(ref, _TestMemoTemplateSettingsRepository(settings)) {
    state = settings;
  }
}

class _TestMemoTemplateSettingsRepository
    extends MemoTemplateSettingsRepository {
  _TestMemoTemplateSettingsRepository(this._settings)
    : super(const FlutterSecureStorage(), accountKey: 'test-account');

  final MemoTemplateSettings _settings;

  @override
  Future<MemoTemplateSettings> read() async => _settings;

  @override
  Future<void> write(MemoTemplateSettings settings) async {}

  @override
  Future<void> clear() async {}
}
