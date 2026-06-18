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
import 'package:memos_flutter_app/core/tags.dart';
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
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/workspace_preferences_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

void main() {
  test('setHomeNavigationMode persists selected mode', () async {
    final repository = _TestWorkspacePreferencesRepository();
    final container = _buildContainer(repository: repository, hasAccount: true);
    addTearDown(container.dispose);

    final notifier = container.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    await notifier.reloadFromStorage();

    notifier.setHomeNavigationMode(HomeNavigationMode.bottomBar);
    await notifier.waitForPendingWrites();

    final prefs = container.read(currentWorkspacePreferencesProvider);
    expect(prefs.homeNavigationPreferences.mode, HomeNavigationMode.bottomBar);
    expect(
      repository.stored.homeNavigationPreferences.mode,
      HomeNavigationMode.bottomBar,
    );
  });

  test('setHomeNavigationSlots sanitizes duplicate destinations', () async {
    final repository = _TestWorkspacePreferencesRepository();
    final container = _buildContainer(repository: repository, hasAccount: true);
    addTearDown(container.dispose);

    final notifier = container.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    await notifier.reloadFromStorage();

    notifier.setHomeNavigationSlots(
      leftPrimary: HomeRootDestination.memos,
      leftSecondary: HomeRootDestination.memos,
      rightPrimary: HomeRootDestination.settings,
      rightSecondary: HomeRootDestination.settings,
    );
    await notifier.waitForPendingWrites();

    final navigationPrefs = container
        .read(currentWorkspacePreferencesProvider)
        .homeNavigationPreferences;
    expect(navigationPrefs.leftPrimary, HomeRootDestination.memos);
    expect(navigationPrefs.leftSecondary, HomeRootDestination.collections);
    expect(navigationPrefs.rightPrimary, HomeRootDestination.settings);
    expect(navigationPrefs.rightSecondary, HomeRootDestination.dailyReview);
  });

  test('setHomeNavigationSlots filters unavailable destinations', () async {
    final repository = _TestWorkspacePreferencesRepository();
    final container = _buildContainer(
      repository: repository,
      hasAccount: false,
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    await notifier.reloadFromStorage();

    notifier.setHomeNavigationSlots(
      leftPrimary: HomeRootDestination.explore,
      leftSecondary: HomeRootDestination.none,
      rightPrimary: HomeRootDestination.none,
      rightSecondary: HomeRootDestination.none,
    );
    await notifier.waitForPendingWrites();

    final navigationPrefs = container
        .read(currentWorkspacePreferencesProvider)
        .homeNavigationPreferences;
    expect(navigationPrefs.leftPrimary, HomeRootDestination.memos);
    expect(navigationPrefs.leftSecondary, HomeRootDestination.none);
    expect(navigationPrefs.rightPrimary, HomeRootDestination.none);
    expect(navigationPrefs.rightSecondary, HomeRootDestination.none);
  });

  test('setHomeNavigationSlots keeps one visible outer slot', () async {
    final repository = _TestWorkspacePreferencesRepository();
    final container = _buildContainer(repository: repository, hasAccount: true);
    addTearDown(container.dispose);

    final notifier = container.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    await notifier.reloadFromStorage();

    notifier.setHomeNavigationSlots(
      leftPrimary: HomeRootDestination.none,
      leftSecondary: HomeRootDestination.none,
      rightPrimary: HomeRootDestination.none,
      rightSecondary: HomeRootDestination.none,
    );
    await notifier.waitForPendingWrites();

    final navigationPrefs = container
        .read(currentWorkspacePreferencesProvider)
        .homeNavigationPreferences;
    expect(navigationPrefs.leftPrimary, HomeRootDestination.memos);
    expect(navigationPrefs.leftSecondary, HomeRootDestination.none);
    expect(navigationPrefs.rightPrimary, HomeRootDestination.none);
    expect(navigationPrefs.rightSecondary, HomeRootDestination.none);
  });

  test('setShowDrawerDraftBox persists drawer visibility preference', () async {
    final repository = _TestWorkspacePreferencesRepository();
    final container = _buildContainer(repository: repository, hasAccount: true);
    addTearDown(container.dispose);

    final notifier = container.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    await notifier.reloadFromStorage();

    notifier.setShowDrawerDraftBox(false);
    await notifier.waitForPendingWrites();

    expect(
      container.read(currentWorkspacePreferencesProvider).showDrawerDraftBox,
      isFalse,
    );
    expect(repository.stored.showDrawerDraftBox, isFalse);
  });

  test('setTagRecognitionPolicy persists workspace policy', () async {
    final repository = _TestWorkspacePreferencesRepository();
    final container = _buildContainer(repository: repository, hasAccount: true);
    addTearDown(container.dispose);

    final notifier = container.read(
      currentWorkspacePreferencesProvider.notifier,
    );
    await notifier.reloadFromStorage();

    final policy = TagRecognitionPolicy.custom(
      const TagRecognitionCustomOptions(
        inlineBodyTags: true,
        numericOnlyTags: false,
        remoteTagHandling: RemoteTagHandling.mergeRemote,
      ),
    );
    notifier.setTagRecognitionPolicy(policy);
    await notifier.waitForPendingWrites();

    expect(
      container.read(currentWorkspacePreferencesProvider).tagRecognitionPolicy,
      policy,
    );
    expect(repository.stored.tagRecognitionPolicy, policy);
  });
}

ProviderContainer _buildContainer({
  required _TestWorkspacePreferencesRepository repository,
  required bool hasAccount,
}) {
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
  _TestWorkspacePreferencesRepository({WorkspacePreferences? initial})
    : stored = initial ?? WorkspacePreferences.defaults,
      super(
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
