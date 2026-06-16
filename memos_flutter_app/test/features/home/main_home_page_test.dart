import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:memos_flutter_app/application/legal/legal_consent_policy.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/auth/login_screen.dart';
import 'package:memos_flutter_app/features/home/main_home_page.dart';
import 'package:memos_flutter_app/features/onboarding/language_selection_screen.dart';
import 'package:memos_flutter_app/features/startup/startup_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'MemoFlow',
      packageName: 'com.example.memoflow',
      version: MemoFlowLegalConsentPolicy.requiredSinceAppVersion,
      buildNumber: '27',
      buildSignature: '',
    );
  });

  Widget buildTestApp({
    DevicePreferences? devicePrefs,
    WorkspacePreferences? workspacePrefs,
    bool disableAnimations = false,
  }) {
    LocaleSettings.setLocale(AppLocale.en);
    return ProviderScope(
      overrides: [
        appSessionProvider.overrideWith((ref) => _TestSessionController()),
        devicePreferencesProvider.overrideWith(
          (ref) => _TestDevicePreferencesController(
            ref,
            initial:
                devicePrefs ??
                DevicePreferences.defaultsForLanguage(AppLanguage.en).copyWith(
                  onboardingMode: AppOnboardingMode.server,
                  lastSeenAppVersion:
                      MemoFlowLegalConsentPolicy.requiredSinceAppVersion,
                ),
          ),
        ),
        currentWorkspacePreferencesProvider.overrideWith(
          (ref) => _TestWorkspacePreferencesController(
            ref,
            initial: workspacePrefs ?? WorkspacePreferences.defaults,
          ),
        ),
        currentLocalLibraryProvider.overrideWith((ref) => null),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          builder: disableAnimations
              ? (context, child) {
                  final mediaQuery = MediaQuery.of(context);
                  return MediaQuery(
                    data: mediaQuery.copyWith(disableAnimations: true),
                    child: child!,
                  );
                }
              : null,
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const MainHomePage(),
        ),
      ),
    );
  }

  testWidgets(
    'workspace preference updates do not route back to language selection',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      final loginFinder = find.byType(LoginScreen, skipOffstage: false);
      final languageFinder = find.byType(
        LanguageSelectionScreen,
        skipOffstage: false,
      );
      expect(loginFinder, findsOneWidget);
      expect(languageFinder, findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainHomePage)),
      );
      final current = container.read(currentWorkspacePreferencesProvider);
      await container
          .read(currentWorkspacePreferencesProvider.notifier)
          .setAll(
            current.copyWith(
              homeQuickActionPrimary: HomeQuickAction.explore,
              homeQuickActionSecondary: HomeQuickAction.resources,
              homeQuickActionTertiary: HomeQuickAction.archived,
            ),
            triggerSync: false,
          );

      await tester.pumpAndSettle();

      expect(
        container.read(devicePreferencesProvider).hasSelectedLanguage,
        isTrue,
      );
      expect(loginFinder, findsOneWidget);
      expect(languageFinder, findsNothing);
    },
  );

  testWidgets('reduced motion reaches login without startup hold', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(disableAnimations: true));
    await tester.pump();
    final settledPumpCount = await tester.pumpAndSettle();

    expect(settledPumpCount, lessThan(10));
    expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);
    expect(
      find.byType(LanguageSelectionScreen, skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('english startup does not wait a fixed three seconds', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(StartupScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('startup slogan decision stays locked while preferences load', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'zh',
      'CN',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(
      tester.widget<StartupScreen>(find.byType(StartupScreen)).showSlogan,
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 500));

    final startupScreens = tester.widgetList<StartupScreen>(
      find.byType(StartupScreen),
    );
    expect(startupScreens, isNotEmpty);
    expect(
      startupScreens.map((screen) => screen.showSlogan),
      everyElement(isTrue),
    );
  });
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(
          AppSessionState(accounts: <Account>[], currentKey: null),
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

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository(this._stored)
    : super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _stored;

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
    Ref ref, {
    required DevicePreferences initial,
  }) : super(
         ref,
         _TestDevicePreferencesRepository(initial),
         onLoaded: () {
           ref.read(devicePreferencesLoadedProvider.notifier).state = true;
         },
       ) {
    state = initial;
  }
}

class _TestWorkspacePreferencesRepository
    extends WorkspacePreferencesRepository {
  _TestWorkspacePreferencesRepository(this._stored)
    : super(
        PreferencesMigrationService(const FlutterSecureStorage()),
        workspaceKey: 'test-workspace',
      );

  WorkspacePreferences _stored;

  @override
  Future<StorageReadResult<WorkspacePreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<WorkspacePreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(WorkspacePreferences prefs) async {
    _stored = prefs;
  }
}

class _TestWorkspacePreferencesController
    extends WorkspacePreferencesController {
  _TestWorkspacePreferencesController(
    Ref ref, {
    required WorkspacePreferences initial,
  }) : super(
         ref,
         _TestWorkspacePreferencesRepository(initial),
         onLoaded: () {
           ref.read(workspacePreferencesLoadedProvider.notifier).state = true;
         },
       ) {
    state = initial;
  }
}
