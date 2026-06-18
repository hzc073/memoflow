import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/core/tags.dart';
import 'package:memos_flutter_app/core/theme_colors.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/settings/preferences_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';

import 'settings_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom theme dialog opens immediately when motion is disabled', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(disableAnimations: true),
              child: child!,
            );
          },
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      CustomThemeDialog.show(
                        context: context,
                        initial: CustomThemeSettings.defaults,
                      );
                    },
                    child: const Text('Open custom theme'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open custom theme'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomThemeDialog), findsOneWidget);
  });

  testWidgets('tag recognition row opens help and recompute can be skipped', (
    tester,
  ) async {
    final harness = await _pumpPreferences(tester);
    final strings = t.strings.settings.preferences.tagRecognition;

    await tester.ensureVisible(find.text(strings.title));
    await tester.pumpAndSettle();
    expect(find.text(strings.title), findsOneWidget);
    expect(find.text(strings.strict), findsOneWidget);

    await tester.tap(find.byTooltip(strings.helpTitle));
    await tester.pumpAndSettle();

    expect(find.text(strings.helpTitle), findsWidgets);
    expect(find.text(strings.helpMessage), findsOneWidget);
    await tester.tap(find.text(t.strings.legacy.msg_ok));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(strings.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.compatible).last);
    await tester.pumpAndSettle();

    expect(find.text(strings.recomputeTitle), findsOneWidget);
    await tester.tap(find.text(strings.recomputeSkip));
    await tester.pumpAndSettle();

    expect(
      harness.workspaceRepository.stored.tagRecognitionPolicy,
      TagRecognitionPolicy.memosCompatible,
    );
  });

  testWidgets(
    'enum picker uses unified single-choice sheet and persists value',
    (tester) async {
      final harness = await _pumpPreferences(tester);
      final strings = t.strings.settings.preferences;

      await tester.ensureVisible(find.text(strings.lineHeight));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.lineHeight));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsContentHeader), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SettingsSingleChoiceRow<AppLineHeight> &&
              widget.option.value == AppLineHeight.compact,
        ),
        findsOneWidget,
      );
      expect(
        find.text(AppLineHeight.compact.labelFor(AppLanguage.en)),
        findsOneWidget,
      );

      await tester.tap(
        find.text(AppLineHeight.compact.labelFor(AppLanguage.en)),
      );
      await tester.pumpAndSettle();

      expect(harness.deviceRepository.stored.lineHeight, AppLineHeight.compact);
      expect(
        find.text(AppLineHeight.compact.labelFor(AppLanguage.en)),
        findsOneWidget,
      );
    },
  );

  testWidgets('launch action enum picker keeps sync hidden', (tester) async {
    await _pumpPreferences(tester);
    final strings = t.strings.settings.preferences;

    await tester.ensureVisible(find.text(strings.launchAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.launchAction));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsContentHeader), findsOneWidget);
    expect(find.text(LaunchAction.sync.labelFor(AppLanguage.en)), findsNothing);
    expect(find.text(LaunchAction.none.labelFor(AppLanguage.en)), findsWidgets);
    expect(
      find.text(LaunchAction.quickInput.labelFor(AppLanguage.en)),
      findsOneWidget,
    );
    expect(
      find.text(LaunchAction.dailyReview.labelFor(AppLanguage.en)),
      findsOneWidget,
    );
    expect(
      find.text(LaunchAction.explore.labelFor(AppLanguage.en)),
      findsOneWidget,
    );
  });

  testWidgets('tag recognition row is disabled while rebuilding tag data', (
    tester,
  ) async {
    await _pumpPreferences(
      tester,
      settle: false,
      overrides: [
        tagRecognitionRecomputeInProgressProvider.overrideWith((ref) => true),
      ],
    );
    final strings = t.strings.settings.preferences.tagRecognition;

    await tester.ensureVisible(find.text(strings.title));
    await tester.pump();

    expect(find.text(strings.recomputeInProgress), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text(strings.title));
    await tester.pump();

    expect(find.text(strings.compatible), findsNothing);
    expect(find.text(strings.custom), findsNothing);
  });

  testWidgets('custom tag recognition options open help dialogs', (
    tester,
  ) async {
    await _pumpPreferences(tester);
    final strings = t.strings.settings.preferences.tagRecognition;

    await tester.ensureVisible(find.text(strings.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.custom).last);
    await tester.pumpAndSettle();

    expect(find.text(strings.customTitle), findsOneWidget);
    expect(find.text(strings.customIntro), findsOneWidget);
    expect(strings.customIntro, contains('rendering'));
    expect(strings.customIntro, contains('autocomplete'));
    expect(strings.customIntro, contains('search'));
    expect(strings.customIntro, contains('local repair'));
    expect(strings.customIntro, contains('rebuild tag data'));

    final options = <({String label, String tip})>[
      (label: strings.strictFirstLine, tip: strings.strictFirstLineTip),
      (label: strings.strictLastLine, tip: strings.strictLastLineTip),
      (label: strings.strictAnyLine, tip: strings.strictAnyLineTip),
      (label: strings.inlineBodyTags, tip: strings.inlineBodyTagsTip),
      (label: strings.numericOnlyTags, tip: strings.numericOnlyTagsTip),
      (label: strings.hierarchicalTags, tip: strings.hierarchicalTagsTip),
      (label: strings.emojiAndSymbolTags, tip: strings.emojiAndSymbolTagsTip),
      (label: strings.mergeRemoteTags, tip: strings.mergeRemoteTagsTip),
    ];

    for (var index = 0; index < options.length; index += 1) {
      final option = options[index];
      await tester.ensureVisible(find.text(option.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(option.label));
      await tester.pumpAndSettle();

      expect(find.text(option.label), findsWidgets);
      expect(find.text(option.tip), findsOneWidget);

      await tester.tap(find.text(t.strings.legacy.msg_ok));
      await tester.pumpAndSettle();
    }
  });
}

Future<_PreferencesHarness> _pumpPreferences(
  WidgetTester tester, {
  WorkspacePreferences? workspacePreferences,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  LocaleSettings.setLocale(AppLocale.en);
  final workspaceRepository = _TestWorkspacePreferencesRepository(
    workspacePreferences ?? WorkspacePreferences.defaults,
  );
  final deviceRepository = _TestDevicePreferencesRepository(
    DevicePreferences.defaultsForLanguage(AppLanguage.en),
  );
  await tester.pumpWidget(
    buildSettingsTestApp(
      home: const PreferencesSettingsScreen(showBackButton: false),
      overrides: [
        devicePreferencesProvider.overrideWith(
          (ref) => _TestDevicePreferencesController(ref, deviceRepository),
        ),
        currentWorkspacePreferencesProvider.overrideWith(
          (ref) =>
              _TestWorkspacePreferencesController(ref, workspaceRepository),
        ),
        ...overrides,
      ],
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return _PreferencesHarness(
    deviceRepository: deviceRepository,
    workspaceRepository: workspaceRepository,
  );
}

class _PreferencesHarness {
  const _PreferencesHarness({
    required this.deviceRepository,
    required this.workspaceRepository,
  });

  final _TestDevicePreferencesRepository deviceRepository;
  final _TestWorkspacePreferencesRepository workspaceRepository;
}

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository(this._stored)
    : super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _stored;
  DevicePreferences get stored => _stored;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<DevicePreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(DevicePreferences prefs) async {
    _stored = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(
    Ref ref,
    _TestDevicePreferencesRepository repository,
  ) : super(ref, repository) {
    state = repository._stored;
  }
}

class _TestWorkspacePreferencesRepository
    extends WorkspacePreferencesRepository {
  _TestWorkspacePreferencesRepository(this.stored)
    : super(
        PreferencesMigrationService(const FlutterSecureStorage()),
        workspaceKey: 'test-workspace',
      );

  WorkspacePreferences stored;

  @override
  Future<StorageReadResult<WorkspacePreferences>> readWithStatus() async {
    return StorageReadResult.success(stored);
  }

  @override
  Future<WorkspacePreferences> read() async {
    return stored;
  }

  @override
  Future<void> write(WorkspacePreferences prefs) async {
    stored = prefs;
  }
}

class _TestWorkspacePreferencesController
    extends WorkspacePreferencesController {
  _TestWorkspacePreferencesController(
    Ref ref,
    _TestWorkspacePreferencesRepository repository,
  ) : super(ref, repository) {
    state = repository.stored;
  }
}
