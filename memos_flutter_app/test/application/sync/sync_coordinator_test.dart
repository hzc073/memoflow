import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_dependencies.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/logs/debug_log_store.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_backup_state.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_password_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_state_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_settings_repository.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_controller_base.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/webdav/webdav_backup_provider.dart';
import 'package:memos_flutter_app/state/webdav/webdav_settings_provider.dart';

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

  @override
  Future<WebDavConnectionTestResult> testConnection({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return const WebDavConnectionTestResult.success();
  }
}

class FakeWebDavBackupService implements WebDavBackupService {
  FakeWebDavBackupService(
    this.calls, {
    this.result = const WebDavBackupSuccess(),
    Completer<WebDavBackupResult>? wait,
  }) : _wait = wait;

  final List<String> calls;
  WebDavBackupResult result;
  final Completer<WebDavBackupResult>? _wait;
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
    final waiter = _wait;
    if (waiter != null) return waiter.future;
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
  String resolveEffectiveServerVersionForAccount({required Account account}) {
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
  List<DebugLogEntry>? webDavLogs,
}) {
  final session = FakeAppSessionController(
    const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
  );
  final settingsRepo = FakeWebDavSettingsRepository(
    webDavSettings ?? WebDavSettings.defaults.copyWith(enabled: true),
  );
  final backupStateRepo = FakeWebDavBackupStateRepository();
  final backupPasswordRepo = FakeWebDavBackupPasswordRepository();
  const localLibrary = LocalLibrary(
    key: 'local',
    name: 'Local',
    rootPath: 'c:\\tmp',
  );
  return ProviderContainer(
    overrides: [
      appSessionProvider.overrideWith((ref) => session),
      databaseProvider.overrideWithValue(db),
      currentLocalLibraryProvider.overrideWithValue(localLibrary),
      syncControllerProvider.overrideWith((ref) => syncController),
      webDavSettingsRepositoryProvider.overrideWithValue(settingsRepo),
      webDavBackupStateRepositoryProvider.overrideWithValue(backupStateRepo),
      webDavBackupPasswordRepositoryProvider.overrideWithValue(
        backupPasswordRepo,
      ),
      syncCoordinatorProvider.overrideWith(
        (ref) => SyncCoordinator(
          SyncDependencies(
            webDavSyncService: webDavSyncService,
            webDavBackupService: webDavBackupService,
            webDavBackupStateRepository: backupStateRepo,
            readWebDavSettings: () => settingsRepo.settings,
            readCurrentAccountKey: () => session.state.valueOrNull?.currentKey,
            readCurrentAccount: () => session.state.valueOrNull?.currentAccount,
            readCurrentLocalLibrary: () => localLibrary,
            readDatabase: () => db,
            runMemosSync: syncController.syncNow,
            logWriter: webDavLogs?.add,
          ),
        ),
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
      final syncController = FakeSyncController(result: MemoSyncFailure(error));
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
        container
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
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
        container
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.auto,
              ),
            ),
      );
      async.flushMicrotasks();

      unawaited(
        container
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavBackup,
                reason: SyncRequestReason.auto,
              ),
            ),
      );
      unawaited(
        container
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.manual,
              ),
            ),
      );
      unawaited(
        container
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
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
      expect(calls.where((c) => c == 'webdavSync').length, 1);

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
        container
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
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

  test('logs why settings sync does not queue memo backup', () async {
    final logs = <DebugLogEntry>[];
    final coordinator = SyncCoordinator(
      SyncDependencies(
        webDavSyncService: FakeWebDavSyncService(<String>[]),
        webDavBackupService: FakeWebDavBackupService(<String>[]),
        webDavBackupStateRepository: FakeWebDavBackupStateRepository(),
        readWebDavSettings: () => WebDavSettings.defaults.copyWith(
          enabled: true,
          autoSyncAllowed: true,
          backupEnabled: true,
          serverUrl: 'https://example.com',
          username: 'user',
          password: 'pass',
          backupSchedule: WebDavBackupSchedule.manual,
        ),
        readCurrentAccountKey: () => 'account-1',
        readCurrentAccount: () => null,
        readCurrentLocalLibrary: () => const LocalLibrary(
          key: 'local',
          name: 'Local',
          rootPath: 'c:\\tmp',
        ),
        readDatabase: () => FakeAppDatabase(retryableCount: 0),
        runMemosSync: () async => const MemoSyncSuccess(),
        logWriter: logs.add,
      ),
    );

    final result = await coordinator.requestSync(
      const SyncRequest(
        kind: SyncRequestKind.webDavSync,
        reason: SyncRequestReason.settings,
      ),
    );

    expect(result, isA<SyncRunQueued>());
    final target = logs
        .where((entry) => entry.label == 'Backup not queued')
        .toList();
    expect(target, hasLength(1));
    expect(target.single.detail, contains('settings_sync_only'));
    expect(target.single.detail, contains('schedule=manual'));
  });

  test('logs manual schedule when auto backup is skipped', () {
    fakeAsync((async) {
      final logs = <DebugLogEntry>[];
      final calls = <String>[];
      final syncController = FakeSyncController();
      final db = FakeAppDatabase(retryableCount: 0);
      final container = _buildContainer(
        syncController: syncController,
        db: db,
        webDavSyncService: FakeWebDavSyncService(calls),
        webDavBackupService: FakeWebDavBackupService(calls),
        webDavSettings: WebDavSettings.defaults.copyWith(
          enabled: true,
          autoSyncAllowed: true,
          backupEnabled: true,
          serverUrl: 'https://example.com',
          username: 'user',
          password: 'pass',
          backupSchedule: WebDavBackupSchedule.manual,
        ),
        webDavLogs: logs,
      );

      unawaited(
        container
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.all,
                reason: SyncRequestReason.auto,
              ),
            ),
      );
      async.flushMicrotasks();

      expect(
        logs.any(
          (entry) =>
              entry.label == 'Backup not queued' &&
              entry.detail == 'schedule=manual reason=auto',
        ),
        isTrue,
      );

      container.dispose();
    });
  });

  test('logs manual webdav sync request lifecycle', () async {
    final logs = <DebugLogEntry>[];
    final coordinator = SyncCoordinator(
      SyncDependencies(
        webDavSyncService: FakeWebDavSyncService(<String>[]),
        webDavBackupService: FakeWebDavBackupService(<String>[]),
        webDavBackupStateRepository: FakeWebDavBackupStateRepository(),
        readWebDavSettings: () => WebDavSettings.defaults.copyWith(
          enabled: true,
          serverUrl: 'https://example.com',
          username: 'user',
          password: 'pass',
        ),
        readCurrentAccountKey: () => 'account-1',
        readCurrentAccount: () => null,
        readCurrentLocalLibrary: () => const LocalLibrary(
          key: 'local',
          name: 'Local',
          rootPath: 'c:\\tmp',
        ),
        readDatabase: () => FakeAppDatabase(retryableCount: 0),
        runMemosSync: () async => const MemoSyncSuccess(),
        logWriter: logs.add,
      ),
    );

    final result = await coordinator.requestSync(
      const SyncRequest(
        kind: SyncRequestKind.webDavSync,
        reason: SyncRequestReason.manual,
      ),
    );

    expect(result, isA<SyncRunStarted>());
    expect(logs.map((entry) => entry.label), contains('Request received'));
    expect(logs.map((entry) => entry.label), contains('Request queued'));
    expect(
      logs.map((entry) => entry.label),
      contains('Coordinator sync started'),
    );
    expect(
      logs.map((entry) => entry.label),
      contains('Coordinator sync completed'),
    );
  });

  test('ignores backup completion after coordinator dispose', () async {
    final calls = <String>[];
    final backupCompleter = Completer<WebDavBackupResult>();
    final container = _buildContainer(
      syncController: FakeSyncController(),
      db: FakeAppDatabase(retryableCount: 0),
      webDavSyncService: FakeWebDavSyncService(calls),
      webDavBackupService: FakeWebDavBackupService(
        calls,
        wait: backupCompleter,
      ),
    );

    final future = container
        .read(syncCoordinatorProvider.notifier)
        .requestSync(
          const SyncRequest(
            kind: SyncRequestKind.webDavBackup,
            reason: SyncRequestReason.manual,
          ),
        );

    await Future<void>.delayed(Duration.zero);
    container.dispose();
    backupCompleter.complete(
      WebDavBackupFailure(
        const SyncError(code: SyncErrorCode.server, retryable: true),
      ),
    );

    expect(await future, isA<SyncRunSkipped>());
  });

  test('skips memos sync when context is not ready', () async {
    final calls = <String>[];
    var memosCalls = 0;
    final coordinator = SyncCoordinator(
      SyncDependencies(
        webDavSyncService: FakeWebDavSyncService(calls),
        webDavBackupService: FakeWebDavBackupService(calls),
        webDavBackupStateRepository: FakeWebDavBackupStateRepository(),
        readWebDavSettings: () => WebDavSettings.defaults,
        readCurrentAccountKey: () => null,
        readCurrentAccount: () => null,
        readCurrentLocalLibrary: () => null,
        readDatabase: () => throw StateError('Not authenticated'),
        runMemosSync: () async {
          memosCalls += 1;
          return const MemoSyncSuccess();
        },
      ),
    );

    final result = await coordinator.requestSync(
      const SyncRequest(
        kind: SyncRequestKind.memos,
        reason: SyncRequestReason.manual,
      ),
    );

    expect(result, isA<SyncRunSkipped>());
    expect((result as SyncRunSkipped).reason?.message, 'context_not_ready');
    expect(memosCalls, 0);
  });

  test('clears stale memo attention after failure and skip', () async {
    final calls = <String>[];
    final attention = SyncAttentionInfo(
      outboxId: 42,
      failureCode: 'content_too_long',
      memoUid: 'memo-1',
      message: 'too long',
      occurredAt: DateTime.utc(2026, 3, 13, 18, 0),
    );
    final error = SyncError(
      code: SyncErrorCode.server,
      retryable: false,
      message: 'sync failed',
    );
    MemoSyncResult currentResult = MemoSyncSuccessWithAttention(attention);

    final coordinator = SyncCoordinator(
      SyncDependencies(
        webDavSyncService: FakeWebDavSyncService(calls),
        webDavBackupService: FakeWebDavBackupService(calls),
        webDavBackupStateRepository: FakeWebDavBackupStateRepository(),
        readWebDavSettings: () => WebDavSettings.defaults,
        readCurrentAccountKey: () => null,
        readCurrentAccount: () => null,
        readCurrentLocalLibrary: () => const LocalLibrary(
          key: 'local',
          name: 'Local',
          rootPath: 'c:\\tmp',
        ),
        readDatabase: () => FakeAppDatabase(retryableCount: 0),
        runMemosSync: () async => currentResult,
      ),
    );

    final first = await coordinator.requestSync(
      const SyncRequest(
        kind: SyncRequestKind.memos,
        reason: SyncRequestReason.manual,
      ),
    );
    expect(first, isA<SyncRunStarted>());
    expect(coordinator.state.memos.attention?.outboxId, 42);

    currentResult = MemoSyncFailure(error);
    final second = await coordinator.requestSync(
      const SyncRequest(
        kind: SyncRequestKind.memos,
        reason: SyncRequestReason.manual,
      ),
    );
    expect(second, isA<SyncRunFailure>());
    expect(coordinator.state.memos.attention, isNull);

    currentResult = const MemoSyncSkipped();
    final third = await coordinator.requestSync(
      const SyncRequest(
        kind: SyncRequestKind.memos,
        reason: SyncRequestReason.manual,
      ),
    );
    expect(third, isA<SyncRunSkipped>());
    expect(coordinator.state.memos.attention, isNull);
  });

  test('skips all sync when context is not ready', () async {
    final calls = <String>[];
    final coordinator = SyncCoordinator(
      SyncDependencies(
        webDavSyncService: FakeWebDavSyncService(calls),
        webDavBackupService: FakeWebDavBackupService(calls),
        webDavBackupStateRepository: FakeWebDavBackupStateRepository(),
        readWebDavSettings: () => WebDavSettings.defaults,
        readCurrentAccountKey: () => null,
        readCurrentAccount: () => null,
        readCurrentLocalLibrary: () => null,
        readDatabase: () => throw StateError('Not authenticated'),
        runMemosSync: () async => const MemoSyncSuccess(),
      ),
    );

    final result = await coordinator.requestSync(
      const SyncRequest(
        kind: SyncRequestKind.all,
        reason: SyncRequestReason.auto,
      ),
    );

    expect(result, isA<SyncRunSkipped>());
    expect((result as SyncRunSkipped).reason?.message, 'context_not_ready');
    expect(calls, isEmpty);
  });
}
