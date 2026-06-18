import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/memoflow_palette.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/core/system_fonts.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/settings/preferences_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/desktop_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/system/system_fonts_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    PackageInfo.setMockInitialValues(
      appName: 'MemoFlow',
      packageName: 'dev.memoflow.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  tearDown(() {
    debugPlatformTargetOverride = null;
  });

  testWidgets('settings center is bounded and uses settings rows on desktop', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.macOS;

    await tester.pumpWidget(_buildApp(child: const SettingsScreen()));
    await tester.pumpAndSettle();

    final bounded = find.byKey(
      const ValueKey<String>('settings.boundedContent'),
    );

    expect(bounded, findsOneWidget);
    expect(tester.getSize(bounded).width, lessThanOrEqualTo(760));
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(SettingsNavigationRow), findsWidgets);
  });

  testWidgets('desktop settings shows shared and Windows sections on Windows', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.windows;

    await tester.pumpWidget(_buildApp(child: const DesktopSettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Desktop settings'), findsWidgets);
    expect(find.text('Shortcut settings'), findsOneWidget);
    expect(find.text('Configure desktop shortcuts'), findsOneWidget);
    expect(find.text('Windows'), findsOneWidget);
    expect(find.text('Minimize to tray when closing window'), findsOneWidget);
    expect(find.text('macOS'), findsNothing);
    expect(
      find.text('Keep running in menu bar when closing window'),
      findsNothing,
    );
  });

  testWidgets('desktop settings shows shared and macOS sections on macOS', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.macOS;

    await tester.pumpWidget(_buildApp(child: const DesktopSettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Shortcut settings'), findsOneWidget);
    expect(find.text('Configure desktop shortcuts'), findsOneWidget);
    expect(find.text('Windows'), findsNothing);
    expect(find.text('Minimize to tray when closing window'), findsNothing);
    expect(find.text('macOS'), findsOneWidget);
    expect(
      find.text('Keep running in menu bar when closing window'),
      findsOneWidget,
    );
    expect(find.textContaining('Use Quit to exit the app'), findsOneWidget);
  });

  testWidgets('desktop settings hides platform lifecycle rows on mobile', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_buildApp(child: const DesktopSettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Shortcut settings'), findsNothing);
    expect(find.text('Windows'), findsNothing);
    expect(find.text('macOS'), findsNothing);
    expect(find.text('Minimize to tray when closing window'), findsNothing);
    expect(
      find.text('Keep running in menu bar when closing window'),
      findsNothing,
    );
  });

  testWidgets(
    'main settings shows desktop entry on macOS and hides it on Linux',
    (tester) async {
      await _setViewport(tester, const Size(1200, 900));
      debugPlatformTargetOverride = TargetPlatform.macOS;

      await tester.pumpWidget(_buildApp(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Desktop settings'), findsOneWidget);

      debugPlatformTargetOverride = TargetPlatform.linux;
      await tester.pumpWidget(_buildApp(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Desktop settings'), findsNothing);
    },
  );

  testWidgets('preferences keeps settings-owned rows on iPhone', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      _buildApp(child: const PreferencesSettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoListSection), findsNothing);
    expect(find.byType(CupertinoListTile), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CupertinoSwitch), findsWidgets);
  });

  testWidgets('preferences iPhone dark top chrome uses settings background', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      _buildApp(
        child: const PreferencesSettingsScreen(),
        theme: ThemeData.dark(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CupertinoPageScaffold>(find.byType(CupertinoPageScaffold))
          .backgroundColor,
      MemoFlowPalette.backgroundDark,
    );
    expect(
      tester
          .widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar))
          .backgroundColor,
      MemoFlowPalette.backgroundDark,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar))
          .backgroundColor,
      MemoFlowPalette.backgroundDark,
    );
  });

  testWidgets('preferences value rows stay bounded under large iPhone text', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      _buildApp(
        child: const PreferencesSettingsScreen(),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2.4),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CupertinoListTile), findsNothing);
    expect(find.byType(ListTile), findsNothing);

    final valueText = tester.widget<Text>(find.text('Standard'));
    expect(valueText.maxLines, 1);
    expect(valueText.overflow, TextOverflow.ellipsis);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
  });

  testWidgets(
    'preferences value rows keep settings-owned trailing on Android',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      debugPlatformTargetOverride = TargetPlatform.android;

      await tester.pumpWidget(
        _buildApp(child: const PreferencesSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoListTile), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    },
  );

  testWidgets('preferences enum choices use desktop picker dialog', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      _buildApp(child: const PreferencesSettingsScreen()),
    );
    await tester.pumpAndSettle();

    final fontSize = find.text('Font Size').first;
    await tester.tap(fontSize);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Large'), findsOneWidget);
  });

  testWidgets('preferences font entry is system-default only on iPhone', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      _buildApp(
        child: const PreferencesSettingsScreen(),
        devicePreferences: DevicePreferences.defaultsForLanguage(
          AppLanguage.en,
        ).copyWith(fontFamily: 'Inter', fontFile: 'fonts/Inter.ttf'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Default'), findsOneWidget);
    expect(find.text('Inter'), findsNothing);

    await tester.tap(find.text('Font').first);
    await tester.pumpAndSettle();

    expect(find.text('No system fonts found'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('preferences font picker remains available on desktop', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      _buildApp(
        child: const PreferencesSettingsScreen(),
        devicePreferences: DevicePreferences.defaultsForLanguage(
          AppLanguage.en,
        ).copyWith(fontFamily: 'Inter', fontFile: 'C:/Windows/Fonts/inter.ttf'),
        systemFonts: const [
          SystemFontInfo(
            family: 'Inter',
            displayName: 'Inter',
            filePath: 'C:/Windows/Fonts/inter.ttf',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inter'), findsOneWidget);

    await tester.tap(find.text('Font').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('System Default'), findsOneWidget);
    expect(find.text('Inter'), findsWidgets);
  });

  test('settings public shell stays free of commercial branching terms', () {
    const files = [
      'lib/features/settings/settings_screen.dart',
      'lib/features/settings/support_memoflow_screen.dart',
      'lib/features/settings/support_memoflow_policy.dart',
      'lib/features/settings/preferences_settings_screen.dart',
    ];
    const blocked = [
      'AccessDecision.source',
      'StoreKit',
      'subscription',
      'entitlement',
      'receipt',
      'paywall',
      'productId',
      'price',
      'purchase',
      'restore',
      'transaction',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      for (final term in blocked) {
        expect(
          source,
          isNot(contains(term)),
          reason: '$path must not contain $term',
        );
      }
    }
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _buildApp({
  required Widget child,
  DevicePreferences? devicePreferences,
  List<SystemFontInfo> systemFonts = const [],
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
}) {
  final home = mediaQueryData == null
      ? child
      : MediaQuery(data: mediaQueryData, child: child);

  return ProviderScope(
    overrides: [
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      devicePreferencesProvider.overrideWith(
        (ref) => _TestDevicePreferencesController(
          ref,
          _TestDevicePreferencesRepository(devicePreferences),
        ),
      ),
      currentWorkspacePreferencesProvider.overrideWith(
        (ref) => _TestWorkspacePreferencesController(
          ref,
          _TestWorkspacePreferencesRepository(),
        ),
      ),
      systemFontsProvider.overrideWith((ref) async => systemFonts),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: theme,
        home: home,
      ),
    ),
  );
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
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

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository(DevicePreferences? initialPreferences)
    : _prefs =
          initialPreferences ??
          DevicePreferences.defaultsForLanguage(AppLanguage.en),
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

class _TestWorkspacePreferencesRepository
    extends WorkspacePreferencesRepository {
  _TestWorkspacePreferencesRepository()
    : _prefs = WorkspacePreferences.defaults,
      super(
        PreferencesMigrationService(const FlutterSecureStorage()),
        workspaceKey: 'test-workspace',
      );

  WorkspacePreferences _prefs;

  @override
  Future<StorageReadResult<WorkspacePreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<WorkspacePreferences> read() async {
    return _prefs;
  }

  @override
  Future<void> write(WorkspacePreferences prefs) async {
    _prefs = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(super.ref, super.repo);
}

class _TestWorkspacePreferencesController
    extends WorkspacePreferencesController {
  _TestWorkspacePreferencesController(super.ref, super.repo);
}
