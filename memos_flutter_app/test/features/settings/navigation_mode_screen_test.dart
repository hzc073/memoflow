import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/home_navigation_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/models/workspace_preferences.dart';
import 'package:memos_flutter_app/features/settings/bottom_navigation_mode_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/navigation_mode_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setTargetPlatform(TargetPlatform platform) {
    debugPlatformTargetOverride = platform;
    addTearDown(() {
      debugPlatformTargetOverride = null;
    });
  }

  testWidgets('bottom navigation selection and detail settings are separated', (
    tester,
  ) async {
    final container = _buildContainer(
      initial: WorkspacePreferences.defaults,
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsNothing);

    await tester.tap(
      find.byKey(NavigationModeScreen.bottomSettingsKey),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationModeSettingsScreen), findsNothing);
    expect(
      container
          .read(currentWorkspacePreferencesProvider)
          .homeNavigationPreferences
          .mode,
      HomeNavigationMode.classic,
    );

    await tester.tap(find.byKey(NavigationModeScreen.bottomSelectKey));
    await tester.pumpAndSettle();

    expect(
      container
          .read(currentWorkspacePreferencesProvider)
          .homeNavigationPreferences
          .mode,
      HomeNavigationMode.bottomBar,
    );
    expect(find.text('Preview'), findsNothing);

    await tester.tap(find.byKey(NavigationModeScreen.bottomSettingsKey));
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationModeSettingsScreen), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Left Slot 1'), findsOneWidget);
    expect(find.text('Center Action'), findsOneWidget);
  });

  testWidgets('updates slot selection and keeps center action fixed', (
    tester,
  ) async {
    final container = _buildContainer(
      initial: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(container, home: const BottomNavigationModeSettingsScreen()),
    );
    await tester.pumpAndSettle();

    final rightSlotTwoRow = find
        .ancestor(of: find.text('Right Slot 2'), matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(rightSlotTwoRow);
    await tester.pumpAndSettle();
    await tester.tap(rightSlotTwoRow, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsSingleChoiceRow<HomeRootDestination> &&
            widget.option.value == HomeRootDestination.collections,
      ),
      findsOneWidget,
    );

    final archivedTile = find.byWidgetPredicate(
      (widget) =>
          widget is SettingsSingleChoiceRow<HomeRootDestination> &&
          widget.option.value == HomeRootDestination.archived,
    );
    await tester.ensureVisible(archivedTile);
    await tester.tap(archivedTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      container
          .read(currentWorkspacePreferencesProvider)
          .homeNavigationPreferences
          .rightSecondary,
      HomeRootDestination.archived,
    );

    await tester.tap(find.text('Center Action'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('hides unavailable entries in bottom navigation settings', (
    tester,
  ) async {
    final container = _buildContainer(
      initial: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: false,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(container, home: const BottomNavigationModeSettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Left Slot 1'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsSingleChoiceRow<HomeRootDestination> &&
            widget.option.value == HomeRootDestination.explore,
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsSingleChoiceRow<HomeRootDestination> &&
            widget.option.value == HomeRootDestination.collections,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsSingleChoiceRow<HomeRootDestination> &&
            widget.option.value == HomeRootDestination.draftBox,
      ),
      findsOneWidget,
    );
  });

  testWidgets('disables destinations already used by other slots', (
    tester,
  ) async {
    final container = _buildContainer(
      initial: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(container, home: const BottomNavigationModeSettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Left Slot 1'));
    await tester.pumpAndSettle();

    final exploreTile = tester
        .widget<SettingsSingleChoiceRow<HomeRootDestination>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SettingsSingleChoiceRow<HomeRootDestination> &&
                widget.option.value == HomeRootDestination.explore,
          ),
        );
    expect(exploreTile.enabled, isFalse);
  });

  testWidgets('bottom navigation destination picker works on iOS', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);
    final container = _buildContainer(
      initial: WorkspacePreferences.defaults.copyWith(
        homeNavigationPreferences: HomeNavigationPreferences.defaults.copyWith(
          mode: HomeNavigationMode.bottomBar,
        ),
      ),
      hasAccount: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(container, home: const BottomNavigationModeSettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Left Slot 1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byType(SettingsSingleChoiceRow<HomeRootDestination>),
      findsWidgets,
    );

    final noneRow = find.byWidgetPredicate(
      (widget) =>
          widget is SettingsSingleChoiceRow<HomeRootDestination> &&
          widget.option.value == HomeRootDestination.none,
    );
    await tester.ensureVisible(noneRow);
    await tester.tap(noneRow);
    await tester.pumpAndSettle();

    expect(
      container
          .read(currentWorkspacePreferencesProvider)
          .homeNavigationPreferences
          .leftPrimary,
      HomeRootDestination.none,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _buildApp(
  ProviderContainer container, {
  Widget home = const NavigationModeScreen(),
}) {
  LocaleSettings.setLocale(AppLocale.en);
  return UncontrolledProviderScope(
    container: container,
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

ProviderContainer _buildContainer({
  required WorkspacePreferences initial,
  required bool hasAccount,
}) {
  final repository = _TestWorkspacePreferencesRepository(initial);
  return ProviderContainer(
    overrides: [
      workspacePreferencesRepositoryProvider.overrideWithValue(repository),
      appSessionProvider.overrideWith(
        (ref) => _TestSessionController(hasAccount: hasAccount),
      ),
      syncCoordinatorProvider.overrideWith((ref) => _NoopSyncFacade()),
    ],
  );
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

class _TestSessionController extends AppSessionController {
  _TestSessionController({required bool hasAccount})
    : super(
        AsyncValue.data(
          AppSessionState(
            accounts: hasAccount ? [_testAccount] : const <Account>[],
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

class _NoopSyncFacade extends DesktopSyncFacade {
  _NoopSyncFacade() : super(SyncCoordinatorState.initial);

  @override
  void applyRemoteStateSnapshot(SyncCoordinatorState next) {
    state = next;
  }

  @override
  Future<WebDavExportCleanupStatus> cleanWebDavPlainExport() async {
    return WebDavExportCleanupStatus.notFound;
  }

  @override
  Future<WebDavSyncMeta?> cleanWebDavDeprecatedPlainFiles() async {
    return null;
  }

  @override
  Future<WebDavExportStatus> fetchWebDavExportStatus() async {
    return const WebDavExportStatus(
      webDavConfigured: false,
      encSignature: null,
      plainSignature: null,
      plainDetected: false,
      plainDeprecated: false,
      plainDetectedAt: null,
      plainRemindAfter: null,
      lastExportSuccessAt: null,
      lastUploadSuccessAt: null,
    );
  }

  @override
  Future<WebDavSyncMeta?> fetchWebDavSyncMeta() async {
    return null;
  }

  @override
  Future<List<WebDavBackupSnapshotInfo>> listWebDavBackupSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return const <WebDavBackupSnapshotInfo>[];
  }

  @override
  Future<String> recoverWebDavBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    return '';
  }

  @override
  Future<SyncRunResult> requestSync(SyncRequest request) async {
    return const SyncRunStarted();
  }

  @override
  Future<SyncRunResult> requestWebDavBackup({
    required SyncRequestReason reason,
    String? password,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) async {
    return const SyncRunStarted();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavPlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<WebDavRestoreResult> restoreWebDavSnapshotToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigRestorePromptHandler? onConfigRestorePrompt,
  }) async {
    return const WebDavRestoreSuccess();
  }

  @override
  Future<void> resolveLocalScanConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> resolveWebDavConflicts(Map<String, bool> resolutions) async {}

  @override
  Future<void> retryPending() async {}

  @override
  Future<WebDavConnectionTestResult> testWebDavConnection({
    required WebDavSettings settings,
  }) async {
    return const WebDavConnectionTestResult.success();
  }

  @override
  Future<SyncError?> verifyWebDavBackup({
    required String password,
    required bool deep,
  }) async {
    return null;
  }
}

const _testAccountKey = 'account-1';
final _testAccount = Account(
  key: _testAccountKey,
  baseUrl: Uri.parse('https://example.com'),
  personalAccessToken: 'token',
  user: User.empty(),
  instanceProfile: InstanceProfile.empty(),
);
