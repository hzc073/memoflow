import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_backup_state.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/settings/webdav_backup_password_repository.dart';
import 'package:memos_flutter_app/data/settings/webdav_backup_state_repository.dart';
import 'package:memos_flutter_app/data/settings/webdav_settings_repository.dart';
import 'package:memos_flutter_app/state/database_provider.dart';
import 'package:memos_flutter_app/state/local_library_provider.dart';
import 'package:memos_flutter_app/state/memos_providers.dart';
import 'package:memos_flutter_app/state/session_provider.dart';
import 'package:memos_flutter_app/state/sync_controller_base.dart';
import 'package:memos_flutter_app/state/webdav_backup_provider.dart';
import 'package:memos_flutter_app/state/webdav_settings_provider.dart';

class FakeAppDatabase extends AppDatabase {
  FakeAppDatabase({required this.retryableCount}) : super(dbName: 'fake.db');

  int retryableCount;

  @override
  Future<int> countOutboxRetryable() async => retryableCount;
}

class FakeSyncController extends SyncControllerBase {
  FakeSyncController({MemoSyncResult? result, Completer<MemoSyncResult>? wait})
    : _result = result ?? const MemoSyncSuccess(),
      _wait = wait,
      super(const AsyncValue.data(null));

  final MemoSyncResult _result;
  final Completer<MemoSyncResult>? _wait;
  int callCount = 0;

  @override
  Future<MemoSyncResult> syncNow() {
    callCount += 1;
    final waiter = _wait;
    if (waiter != null) return waiter.future;
    return Future.value(_result);
  }
}

class FakeWebDavSyncService implements WebDavSyncService {
  FakeWebDavSyncService(this.calls, {this.result = const WebDavSyncSuccess()});

  final List<String> calls;
  WebDavSyncResult result;
  int callCount = 0;

  @override
  Future<WebDavSyncResult> syncNow({
    required WebDavSettings settings,
    required String? accountKey,
    Map<String, bool>? conflictResolutions,
  }) async {
    callCount += 1;
    calls.add('webdavSync');
    return result;
  }

  @override
  Future<WebDavSyncMeta?> fetchRemoteMeta({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return null;
  }

  @override
  Future<WebDavSyncMeta?> cleanDeprecatedRemotePlainFiles({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return null;
  }
}

class FakeWebDavBackupService implements WebDavBackupService {
  FakeWebDavBackupService(this.calls, {this.result = const WebDavBackupSuccess()});

  final List<String> calls;
  WebDavBackupResult result;
  int callCount = 0;
  String? lastPassword;
  WebDavBackupExportIssueHandler? lastIssueHandler;

  @override
  Future<WebDavBackupResult> backupNow({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    String? password,
    bool manual = true,
    Uri? attachmentBaseUrl,
    String? attachmentAuthHeader,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) async {
    callCount += 1;
    calls.add('webdavBackup');
    lastPassword = password;
    lastIssueHandler = onExportIssue;
    return result;
  }

  @override
  Future<SyncError?> verifyBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
    bool deep = false,
  }) async {
    return null;
  }

  @override
  Future<WebDavExportStatus> fetchExportStatus({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
  }) async {
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
  Future<WebDavExportCleanupStatus> cleanPlainExport({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
  }) async {
    return WebDavExportCleanupStatus.notFound;
  }

  @override
  Future<String?> setupBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> recoverBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WebDavBackupSnapshotInfo>> listSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WebDavRestoreResult> restoreSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WebDavRestoreResult> restorePlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WebDavRestoreResult> restoreSnapshotToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WebDavRestoreResult> restorePlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) {
    throw UnimplementedError();
  }
}

class FakeWebDavBackupStateRepository implements WebDavBackupStateRepository {
  WebDavBackupState state = WebDavBackupState.empty;

  @override
  Future<WebDavBackupState> read() async => state;

  @override
  Future<void> write(WebDavBackupState state) async {
    this.state = state;
  }

  @override
  Future<void> clear() async {
    state = WebDavBackupState.empty;
  }
}

class FakeWebDavBackupPasswordRepository
    implements WebDavBackupPasswordRepository {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String password) async {
    stored = password;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

class FakeWebDavSettingsRepository implements WebDavSettingsRepository {
  FakeWebDavSettingsRepository(this.settings);

  WebDavSettings settings;

  @override
  Future<WebDavSettings> read() async => settings;

  @override
  Future<void> write(WebDavSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<void> clear() async {
    settings = WebDavSettings.defaults;
  }
}

class FakeAppSessionController extends AppSessionController {
  FakeAppSessionController(super.state);

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setCurrentKey(String? key) {
    throw UnimplementedError();
  }

  @override
  Future<void> switchAccount(String accountKey) {
    throw UnimplementedError();
  }

  @override
  Future<void> switchWorkspace(String workspaceKey) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeAccount(String accountKey) {
    throw UnimplementedError();
  }

  @override
  Future<void> reloadFromStorage() {
    throw UnimplementedError();
  }

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) {
    throw UnimplementedError();
  }

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) {
    throw UnimplementedError();
  }

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) {
    throw UnimplementedError();
  }

  @override
  String resolveEffectiveServerVersionForAccount({
    required Account account,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) {
    throw UnimplementedError();
  }

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) {
    throw UnimplementedError();
  }

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() {
    throw UnimplementedError();
  }
}

ProviderContainer _buildContainer({
  required FakeSyncController syncController,
  required FakeAppDatabase db,
  required FakeWebDavSyncService webDavSyncService,
  required FakeWebDavBackupService webDavBackupService,
  WebDavSettings? webDavSettings,
}) {
  final session = FakeAppSessionController(
    const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
  );
  final settingsRepo = FakeWebDavSettingsRepository(
    webDavSettings ?? WebDavSettings.defaults.copyWith(enabled: true),
  );
  return ProviderContainer(
    overrides: [
      appSessionProvider.overrideWith((ref) => session),
      databaseProvider.overrideWithValue(db),
      currentLocalLibraryProvider.overrideWithValue(
        const LocalLibrary(key: 'local', name: 'Local', rootPath: 'c:\\tmp'),
      ),
      syncControllerProvider.overrideWith((ref) => syncController),
      webDavSettingsRepositoryProvider.overrideWithValue(settingsRepo),
      webDavBackupStateRepositoryProvider.overrideWithValue(
        FakeWebDavBackupStateRepository(),
      ),
      webDavBackupPasswordRepositoryProvider.overrideWithValue(
        FakeWebDavBackupPasswordRepository(),
      ),
      syncCoordinatorProvider.overrideWith(
        (ref) => SyncCoordinator(ref, webDavSyncService, webDavBackupService),
      ),
    ],
  );
}

void main() {
  test('schedules memos retry with backoff', () {
    fakeAsync((async) {
      final error = SyncError(
        code: SyncErrorCode.network,
        retryable: true,
        message: 'fail',
      );
      final syncController = FakeSyncController(
        result: MemoSyncFailure(error),
      );
      final db = FakeAppDatabase(retryableCount: 1);
      final calls = <String>[];
      final webDavSyncService = FakeWebDavSyncService(calls);
      final webDavBackupService = FakeWebDavBackupService(calls);
      final container = _buildContainer(
        syncController: syncController,
        db: db,
        webDavSyncService: webDavSyncService,
        webDavBackupService: webDavBackupService,
      );

      unawaited(
        container.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            ),
      );
      async.flushMicrotasks();

      expect(syncController.callCount, 1);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(syncController.callCount, 1);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(syncController.callCount, 2);

      container.dispose();
    });
  });

  test('dedupes requests and prioritizes manual', () {
    fakeAsync((async) {
      final calls = <String>[];
      final memosCompleter = Completer<MemoSyncResult>();
      final syncController = FakeSyncController(wait: memosCompleter);
      final db = FakeAppDatabase(retryableCount: 0);
      final webDavSyncService = FakeWebDavSyncService(calls);
      final webDavBackupService = FakeWebDavBackupService(calls);
      final container = _buildContainer(
        syncController: syncController,
        db: db,
        webDavSyncService: webDavSyncService,
        webDavBackupService: webDavBackupService,
      );

      unawaited(
        container.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.auto,
              ),
            ),
      );
      async.flushMicrotasks();

      unawaited(
        container.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavBackup,
                reason: SyncRequestReason.auto,
              ),
            ),
      );
      unawaited(
        container.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.manual,
              ),
            ),
      );
      unawaited(
        container.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.settings,
              ),
            ),
      );
      async.flushMicrotasks();

      expect(webDavSyncService.callCount, 0);
      expect(webDavBackupService.callCount, 0);

      memosCompleter.complete(const MemoSyncSuccess());
      async.flushMicrotasks();

      expect(calls.isNotEmpty, isTrue);
      expect(calls.first, 'webdavSync');
      expect(
        calls.where((c) => c == 'webdavSync').length,
        1,
      );

      container.dispose();
    });
  });

  test('does not schedule backup when backupEnabled is false', () {
    fakeAsync((async) {
      final calls = <String>[];
      final syncController = FakeSyncController();
      final db = FakeAppDatabase(retryableCount: 0);
      final webDavSyncService = FakeWebDavSyncService(calls);
      final webDavBackupService = FakeWebDavBackupService(calls);
      final container = _buildContainer(
        syncController: syncController,
        db: db,
        webDavSyncService: webDavSyncService,
        webDavBackupService: webDavBackupService,
        webDavSettings: WebDavSettings.defaults.copyWith(
          enabled: true,
          backupEnabled: false,
        ),
      );

      unawaited(
        container.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.all,
                reason: SyncRequestReason.auto,
              ),
            ),
      );
      async.flushMicrotasks();

      expect(webDavBackupService.callCount, 0);

      container.dispose();
    });
  });
}
