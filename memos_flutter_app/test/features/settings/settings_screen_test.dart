// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/access_boundary/access_boundary.dart';
import 'package:memos_flutter_app/access_boundary/access_decision.dart';
import 'package:memos_flutter_app/access_boundary/app_capability.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/home_navigation_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/home/home_entry_screen.dart';
import 'package:memos_flutter_app/features/home/home_navigation_host.dart';
import 'package:memos_flutter_app/features/settings/customize_home_shortcuts_screen.dart';
import 'package:memos_flutter_app/features/settings/laboratory_screen.dart';
import 'package:memos_flutter_app/features/settings/navigation_mode_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/module_boundary/settings_entry_contribution.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle_provider.dart';
import 'package:memos_flutter_app/state/memos/sync_queue_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/notifications_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HomeEntryScreen.debugClassicScreenBuilderOverride = null;
    HomeEntryScreen.debugBottomNavShellBuilderOverride = null;
  });

  tearDown(() {
    HomeEntryScreen.debugClassicScreenBuilderOverride = null;
    HomeEntryScreen.debugBottomNavShellBuilderOverride = null;
  });

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'MemoFlow',
      packageName: 'dev.memoflow.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  Widget buildTestApp({
    PrivateExtensionBundle? bundle,
    Widget home = const SettingsScreen(),
    List<Override> overrides = const [],
  }) {
    LocaleSettings.setLocale(AppLocale.en);
    return ProviderScope(
      overrides: [
        appSessionProvider.overrideWith((ref) => _TestSessionController()),
        appPreferencesProvider.overrideWith(
          (ref) => _TestAppPreferencesController(ref),
        ),
        currentWorkspacePreferencesProvider.overrideWith(
          (ref) => _TestWorkspacePreferencesController(ref),
        ),
        currentLocalLibraryProvider.overrideWith((ref) => null),
        if (bundle != null)
          privateExtensionBundleProvider.overrideWithValue(bundle),
        ...overrides,
      ],
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
  }

  testWidgets('keeps donation entry and removes crown UI by default', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final donationFinder = find.byIcon(Icons.bolt_outlined);
    await tester.scrollUntilVisible(
      donationFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(donationFinder, findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    expect(find.text('Private Entry'), findsNothing);
  });

  testWidgets(
    'renders bundle supplied settings entries without capability checks',
    (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestApp(
          bundle: _FakePrivateExtensionBundle(onTap: () => tapped = true),
        ),
      );
      await tester.pumpAndSettle();

      final donationFinder = find.byIcon(Icons.bolt_outlined);
      await tester.scrollUntilVisible(
        donationFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Private Entry'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(donationFinder, findsOneWidget);
      expect(find.text('Private Entry'), findsOneWidget);
      expect(find.text('Bundle supplied entry'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);

      await tester.tap(find.text('Private Entry'));
      await tester.pump();

      expect(tapped, isTrue);
    },
  );

  testWidgets('customize quick entries screen shows three slots', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(home: const CustomizeHomeShortcutsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Entry 1'), findsOneWidget);
    expect(find.text('Quick Entry 2'), findsOneWidget);
    expect(find.text('Quick Entry 3'), findsOneWidget);
  });

  testWidgets(
    'customize quick entries shows local-only candidates and disables used actions',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(home: const CustomizeHomeShortcutsScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Entry 1'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Explore'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadioListTile<HomeQuickAction>,
        ),
        findsWidgets,
      );
      final dialogFinder = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialogFinder, matching: find.text('AI Summary')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.text('Collections')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.text('Random Review')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: dialogFinder, matching: find.text('AI Summary')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Attachments'));
      await tester.pumpAndSettle();

      expect(find.text('Attachments'), findsOneWidget);
    },
  );

  testWidgets('customize quick entries exposes Explore for signed-in users', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: const CustomizeHomeShortcutsScreen(),
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => _TestSessionController(hasAccount: true),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(
              ref,
              initial: AppPreferences.defaultsForLanguage(AppLanguage.en),
            ),
          ),
          currentWorkspacePreferencesProvider.overrideWith(
            (ref) => _TestWorkspacePreferencesController(
              ref,
              initial: WorkspacePreferences.defaults,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick Entry 1'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(AlertDialog);
    expect(dialogFinder, findsOneWidget);
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Explore')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Collections')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RadioListTile<HomeQuickAction>,
      ),
      findsWidgets,
    );

    await tester.tap(
      find.descendant(of: dialogFinder, matching: find.text('Explore')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('laboratory screen exposes navigation mode entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(home: const LaboratoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Navigation Mode'), findsOneWidget);

    await tester.tap(find.text('Navigation Mode'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationModeScreen), findsOneWidget);
  });

  testWidgets('embedded settings uses drawer menu instead of close button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        home: SettingsScreen(
          presentation: HomeScreenPresentation.embeddedBottomNav,
          embeddedNavigationHost: _TestEmbeddedNavigationHost(),
        ),
        overrides: [
          unreadNotificationCountProvider.overrideWith((ref) => 0),
          syncQueuePendingCountProvider.overrideWith(
            (ref) => Stream<int>.value(0),
          ),
          syncQueueAttentionCountProvider.overrideWith(
            (ref) => Stream<int>.value(0),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('drawer-menu-button')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets(
    'standalone settings close returns to home entry respecting bottom nav mode',
    (tester) async {
      HomeEntryScreen.debugClassicScreenBuilderOverride = (_) =>
          const Text('classic-home');
      HomeEntryScreen.debugBottomNavShellBuilderOverride = (_) =>
          const Text('bottom-nav-home');

      await tester.pumpWidget(
        buildTestApp(
          home: const SettingsScreen(),
          overrides: [
            currentWorkspacePreferencesProvider.overrideWith(
              (ref) => _TestWorkspacePreferencesController(
                ref,
                initial: WorkspacePreferences.defaults.copyWith(
                  homeNavigationPreferences: HomeNavigationPreferences.defaults
                      .copyWith(mode: HomeNavigationMode.bottomBar),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('bottom-nav-home'), findsOneWidget);
      expect(find.text('classic-home'), findsNothing);
    },
  );
}

class _FakePrivateExtensionBundle implements PrivateExtensionBundle {
  _FakePrivateExtensionBundle({required this.onTap});

  final VoidCallback onTap;

  @override
  AccessBoundary get diagnosticsAccessBoundary =>
      const _DisabledAccessBoundary();

  @override
  Future<void> onAppReady(WidgetRef ref) async {}

  @override
  List<SettingsEntryContribution> settingsEntries(
    BuildContext context,
    WidgetRef ref,
  ) {
    return [
      SettingsEntryContribution(
        id: 'private-entry',
        order: 10,
        icon: Icons.extension,
        titleBuilder: (_) => 'Private Entry',
        subtitleBuilder: (_) => 'Bundle supplied entry',
        onTap: onTap,
      ),
    ];
  }
}

class _DisabledAccessBoundary implements AccessBoundary {
  const _DisabledAccessBoundary();

  @override
  AccessDecision decisionFor(AppCapability capability) {
    return const AccessDecision.disabled('test');
  }
}

class _TestSessionController extends AppSessionController {
  _TestSessionController({bool hasAccount = false})
    : super(
        AsyncValue.data(
          AppSessionState(
            accounts: hasAccount ? [_testAccount] : const [],
            currentKey: hasAccount ? _testAccountKey : null,
          ),
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

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository(this._stored)
    : super(const FlutterSecureStorage(), accountKey: null);

  AppPreferences _stored;

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(_stored);
  }

  @override
  Future<AppPreferences> read() async {
    return _stored;
  }

  @override
  Future<void> write(AppPreferences prefs) async {
    _stored = prefs;
  }

  @override
  Future<void> clear() async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref, {AppPreferences? initial})
    : super(
        ref,
        _TestAppPreferencesRepository(
          initial ?? AppPreferences.defaultsForLanguage(AppLanguage.en),
        ),
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      ) {
    state = initial ?? AppPreferences.defaultsForLanguage(AppLanguage.en);
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
  _TestWorkspacePreferencesController(Ref ref, {WorkspacePreferences? initial})
    : super(
        ref,
        _TestWorkspacePreferencesRepository(
          initial ?? WorkspacePreferences.defaults,
        ),
        onLoaded: () {
          ref.read(workspacePreferencesLoadedProvider.notifier).state = true;
        },
      ) {
    state = initial ?? WorkspacePreferences.defaults;
  }
}

class _TestEmbeddedNavigationHost implements HomeEmbeddedNavigationHost {
  @override
  void handleBackToPrimaryDestination(BuildContext context) {}

  @override
  void handleDrawerDestination(BuildContext context, destination) {}

  @override
  void handleDrawerTag(BuildContext context, String tag) {}

  @override
  void handleOpenNotifications(BuildContext context) {}

  @override
  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  ) {}

  @override
  void clearGlobalSwipeExclusionRects(HomeRootDestination destination) {}
}

const _testAccountKey = 'account-1';
final _testAccount = Account(
  key: _testAccountKey,
  baseUrl: Uri.parse('https://example.com'),
  personalAccessToken: 'token',
  user: User.empty(),
  instanceProfile: InstanceProfile.empty(),
);
