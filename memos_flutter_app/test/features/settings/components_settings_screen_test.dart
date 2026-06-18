import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/settings/components_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/platform/widgets/platform_dialog.dart';

void main() {
  void setTargetPlatform(TargetPlatform platform) {
    debugPlatformTargetOverride = platform;
    addTearDown(() {
      debugPlatformTargetOverride = null;
    });
  }

  Widget buildTestApp() {
    LocaleSettings.setLocale(AppLocale.en);
    return TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: ThirdPartyShareCopyrightDialog()),
      ),
    );
  }

  testWidgets(
    'requires five-second wait before acknowledging third-party share notice',
    (tester) async {
      await tester.pumpWidget(buildTestApp());

      final acknowledgementRowFinder = find.byType(
        SettingsMultiChoiceRow<String>,
      );
      final enableButtonFinder = find.widgetWithText(FilledButton, 'Enable');

      var acknowledgementRow = tester.widget<SettingsMultiChoiceRow<String>>(
        acknowledgementRowFinder,
      );
      var enableButton = tester.widget<FilledButton>(enableButtonFinder);

      expect(
        find.text('I understand (5s before it can be checked)'),
        findsOneWidget,
      );
      expect(acknowledgementRow.enabled, isFalse);
      expect(enableButton.onPressed, isNull);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      acknowledgementRow = tester.widget<SettingsMultiChoiceRow<String>>(
        acknowledgementRowFinder,
      );
      expect(find.text('I understand'), findsOneWidget);
      expect(acknowledgementRow.enabled, isTrue);

      await tester.ensureVisible(acknowledgementRowFinder);
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();

      enableButton = tester.widget<FilledButton>(enableButtonFinder);
      expect(enableButton.onPressed, isNotNull);
    },
  );

  testWidgets('third-party share acknowledgement dialog works on iOS', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);
    LocaleSettings.setLocale(AppLocale.en);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showPlatformDialog<bool>(
                  context: context,
                  builder: (_) => const ThirdPartyShareCopyrightDialog(),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(SettingsMultiChoiceRow<String>), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    final acknowledgementRowFinder = find.byType(
      SettingsMultiChoiceRow<String>,
    );
    await tester.ensureVisible(acknowledgementRowFinder);
    await tester.tap(acknowledgementRowFinder);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test('components screen uses shared settings UI seam', () {
    final source = File(
      'lib/features/settings/components_settings_screen.dart',
    ).readAsStringSync();
    final settingsUiSource = File(
      'lib/features/settings/settings_ui.dart',
    ).readAsStringSync();

    expect(source, contains('SettingsPage('));
    expect(source, contains('title: Text('));
    expect(source, contains('SettingsHelpButton('));
    expect(source, contains('_componentsStatusTooltip('));
    expect(source, contains('SettingsFeatureModule('));
    expect(source, contains('SettingsFeatureStatus'));
    expect(source, contains('IosMobileFeatureId.memoReminders'));
    expect(source, contains('IosMobileFeatureId.thirdPartyShareIntake'));
    expect(source, contains('IosMobileFeatureId.imageCompression'));
    expect(source, contains('IosMobileFeatureId.locationPicker'));
    expect(source, contains('readiness.canRun'));
    expect(source, contains('_configuredStatus('));
    expect(settingsUiSource, contains('enum SettingsFeatureStatus'));
    expect(settingsUiSource, contains('_SettingsFeatureStatusIndicator'));
    expect(settingsUiSource, contains('const SizedBox(width: 10)'));
    expect(
      settingsUiSource,
      contains('const EdgeInsets.symmetric(horizontal: 5)'),
    );
    expect(settingsUiSource, isNot(contains('flex: 3')));
    expect(source, isNot(contains('SettingsSection(')));
    expect(source, isNot(contains('SettingsToggleCard(')));
    expect(source, isNot(contains('class _ToggleCard')));
    expect(source, isNot(contains('return Scaffold(')));
    expect(source, isNot(contains('Switch(')));
    expect(source, isNot(contains('MemoFlowPalette.')));
  });
}
