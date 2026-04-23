import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_dependencies.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/webdav_backup_state.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/logs/webdav_backup_progress_tracker.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_password_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_state_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/webdav_sync_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/webdav/webdav_backup_provider.dart';
import 'package:memos_flutter_app/state/webdav/webdav_settings_provider.dart';

class FakeWebDavSyncService implements WebDavSyncService {
  FakeWebDavSyncService(this.conflicts);

  final List<String> conflicts;
  int callCount = 0;

  @override
  Future<WebDavSyncResult> syncNow({
    required WebDavSettings settings,
    required String? accountKey,
    Map<String, bool>? conflictResolutions,
  }) async {
    callCount += 1;
    if (conflictResolutions == null) {
      return WebDavSyncConflict(conflicts);
    }
    return const WebDavSyncSuccess();
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
  int callCount = 0;

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
    return const WebDavBackupSuccess();
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

class FakeWebDavSettingsController extends StateNotifier<WebDavSettings>
    implements WebDavSettingsController {
  FakeWebDavSettingsController(super.settings);

  @override
  void setEnabled(bool value) => state = state.copyWith(enabled: value);

  @override
  void setAutoSyncAllowed(bool value) =>
      state = state.copyWith(autoSyncAllowed: value);

  @override
  void setServerUrl(String value) => state = state.copyWith(serverUrl: value);

  @override
  void setUsername(String value) => state = state.copyWith(username: value);

  @override
  void setPassword(String value) => state = state.copyWith(password: value);

  @override
  void setAuthMode(WebDavAuthMode mode) =>
      state = state.copyWith(authMode: mode);

  @override
  void setIgnoreTlsErrors(bool value) =>
      state = state.copyWith(ignoreTlsErrors: value);

  @override
  void setRootPath(String value) => state = state.copyWith(rootPath: value);

  @override
  void setVaultEnabled(bool value) =>
      state = state.copyWith(vaultEnabled: value);

  @override
  void setRememberVaultPassword(bool value) =>
      state = state.copyWith(rememberVaultPassword: value);

  @override
  void setVaultKeepPlainCache(bool value) =>
      state = state.copyWith(vaultKeepPlainCache: value);

  @override
  void setBackupEnabled(bool value) =>
      state = state.copyWith(backupEnabled: value);

  @override
  void setBackupConfigScope(WebDavBackupConfigScope scope) =>
      state = state.copyWith(backupConfigScope: scope);

  @override
  void setBackupContentMemos(bool value) =>
      state = state.copyWith(backupContentMemos: value);

  @override
  void setBackupEncryptionMode(WebDavBackupEncryptionMode mode) =>
      state = state.copyWith(backupEncryptionMode: mode);

  @override
  void setBackupSchedule(WebDavBackupSchedule schedule) =>
      state = state.copyWith(backupSchedule: schedule);

  @override
  void setBackupRetentionCount(int value) =>
      state = state.copyWith(backupRetentionCount: value);

  @override
  void setRememberBackupPassword(bool value) =>
      state = state.copyWith(rememberBackupPassword: value);

  @override
  void setBackupExportEncrypted(bool value) =>
      state = state.copyWith(backupExportEncrypted: value);

  @override
  void setBackupMirrorLocation({String? treeUri, String? rootPath}) {
    state = state.copyWith(
      backupMirrorTreeUri: treeUri ?? state.backupMirrorTreeUri,
      backupMirrorRootPath: rootPath ?? state.backupMirrorRootPath,
    );
  }

  @override
  void setAll(WebDavSettings settings) {
    state = settings;
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

class RecordingSyncCoordinator extends SyncCoordinator {
  RecordingSyncCoordinator(super.deps);

  Map<String, bool>? lastWebDavResolutions;

  @override
  Future<void> resolveWebDavConflicts(Map<String, bool> resolutions) async {
    lastWebDavResolutions = Map<String, bool>.from(resolutions);
    await super.resolveWebDavConflicts(resolutions);
  }
}

class _RecordingPageRouteObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) {
      super.didPop(route, previousRoute);
      return;
    }
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

Future<AppDatabase> _pumpWebDavScreen(
  WidgetTester tester, {
  required WebDavSettings settings,
  required NavigatorObserver observer,
  FakeWebDavBackupPasswordRepository? passwordRepository,
  LocalLibrary? localLibrary,
}) async {
  final webDavSyncService = FakeWebDavSyncService(const <String>[]);
  final webDavBackupService = FakeWebDavBackupService();
  final backupStateRepo = FakeWebDavBackupStateRepository();
  final sessionController = FakeAppSessionController(
    const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
  );
  final settingsController = FakeWebDavSettingsController(settings);
  final progressTracker = WebDavBackupProgressTracker();
  final db = AppDatabase(
    dbName: 'webdav_exit_guard_${DateTime.now().microsecondsSinceEpoch}.db',
  );

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          webDavSettingsProvider.overrideWith((ref) => settingsController),
          webDavSettingsRepositoryProvider.overrideWithValue(
            FakeWebDavSettingsRepository(settings),
          ),
          webDavBackupPasswordRepositoryProvider.overrideWithValue(
            passwordRepository ?? FakeWebDavBackupPasswordRepository(),
          ),
          webDavBackupProgressTrackerProvider.overrideWith(
            (ref) => progressTracker,
          ),
          webDavBackupStateRepositoryProvider.overrideWithValue(
            backupStateRepo,
          ),
          currentLocalLibraryProvider.overrideWithValue(localLibrary),
          appSessionProvider.overrideWith((ref) => sessionController),
          syncCoordinatorProvider.overrideWith((ref) {
            return RecordingSyncCoordinator(
              SyncDependencies(
                webDavSyncService: webDavSyncService,
                webDavBackupService: webDavBackupService,
                webDavBackupStateRepository: backupStateRepo,
                readWebDavSettings: () => settingsController.state,
                readCurrentAccountKey: () =>
                    sessionController.state.valueOrNull?.currentKey,
                readCurrentAccount: () =>
                    sessionController.state.valueOrNull?.currentAccount,
                readCurrentLocalLibrary: () => localLibrary,
                readDatabase: () => db,
                runMemosSync: () async => const MemoSyncSuccess(),
              ),
            );
          }),
        ],
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          navigatorObservers: [observer],
          home: const WebDavSyncScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testWidgets('top-right action runs manual sync and resolves conflicts', (
    WidgetTester tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final conflicts = <String>['preferences.json'];
    final webDavSyncService = FakeWebDavSyncService(conflicts);
    final webDavBackupService = FakeWebDavBackupService();
    RecordingSyncCoordinator? coordinator;
    final backupStateRepo = FakeWebDavBackupStateRepository();
    final sessionController = FakeAppSessionController(
      const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
    );
    final db = AppDatabase(dbName: 'webdav_conflict_flow_test.db');
    const localLibrary = LocalLibrary(
      key: 'local',
      name: 'Local',
      rootPath: 'c:\\tmp',
    );

    final settings = WebDavSettings.defaults.copyWith(
      enabled: true,
      serverUrl: 'https://example.com',
      username: 'user',
      password: 'pass',
      backupEncryptionMode: WebDavBackupEncryptionMode.plain,
    );
    final settingsController = FakeWebDavSettingsController(settings);
    final progressTracker = WebDavBackupProgressTracker();

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            webDavSettingsProvider.overrideWith((ref) => settingsController),
            webDavSettingsRepositoryProvider.overrideWithValue(
              FakeWebDavSettingsRepository(settings),
            ),
            webDavBackupPasswordRepositoryProvider.overrideWithValue(
              FakeWebDavBackupPasswordRepository(),
            ),
            webDavBackupProgressTrackerProvider.overrideWith(
              (ref) => progressTracker,
            ),
            webDavBackupStateRepositoryProvider.overrideWithValue(
              backupStateRepo,
            ),
            currentLocalLibraryProvider.overrideWithValue(localLibrary),
            appSessionProvider.overrideWith((ref) => sessionController),
            syncCoordinatorProvider.overrideWith((ref) {
              coordinator = RecordingSyncCoordinator(
                SyncDependencies(
                  webDavSyncService: webDavSyncService,
                  webDavBackupService: webDavBackupService,
                  webDavBackupStateRepository: backupStateRepo,
                  readWebDavSettings: () => settingsController.state,
                  readCurrentAccountKey: () =>
                      sessionController.state.valueOrNull?.currentKey,
                  readCurrentAccount: () =>
                      sessionController.state.valueOrNull?.currentAccount,
                  readCurrentLocalLibrary: () => localLibrary,
                  readDatabase: () => db,
                  runMemosSync: () async => const MemoSyncSuccess(),
                ),
              );
              return coordinator!;
            }),
          ],
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const WebDavSyncScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.strings.legacy.msg_sync));
    await tester.pumpAndSettle();

    expect(find.text('Settings backup conflicts'), findsOneWidget);

    await tester.tap(find.text(t.strings.legacy.msg_apply));
    await tester.pumpAndSettle();

    expect(webDavBackupService.callCount, 0);
    expect(webDavSyncService.callCount, 2);
    expect(coordinator?.lastWebDavResolutions, {'preferences.json': true});
    expect(settingsController.state.autoSyncAllowed, isTrue);

    await db.close();
  });

  testWidgets('plain backup shows encrypted-only security hint', (
    WidgetTester tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final webDavSyncService = FakeWebDavSyncService(const <String>[]);
    final webDavBackupService = FakeWebDavBackupService();
    RecordingSyncCoordinator? coordinator;
    final backupStateRepo = FakeWebDavBackupStateRepository();
    final sessionController = FakeAppSessionController(
      const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
    );
    final db = AppDatabase(dbName: 'webdav_plain_hint_test.db');

    final settings = WebDavSettings.defaults.copyWith(
      enabled: true,
      serverUrl: 'https://example.com',
      username: 'user',
      password: 'pass',
      backupSchedule: WebDavBackupSchedule.manual,
      backupEncryptionMode: WebDavBackupEncryptionMode.plain,
    );
    final settingsController = FakeWebDavSettingsController(settings);
    final progressTracker = WebDavBackupProgressTracker();

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            webDavSettingsProvider.overrideWith((ref) => settingsController),
            webDavSettingsRepositoryProvider.overrideWithValue(
              FakeWebDavSettingsRepository(settings),
            ),
            webDavBackupPasswordRepositoryProvider.overrideWithValue(
              FakeWebDavBackupPasswordRepository(),
            ),
            webDavBackupProgressTrackerProvider.overrideWith(
              (ref) => progressTracker,
            ),
            webDavBackupStateRepositoryProvider.overrideWithValue(
              backupStateRepo,
            ),
            currentLocalLibraryProvider.overrideWithValue(null),
            appSessionProvider.overrideWith((ref) => sessionController),
            syncCoordinatorProvider.overrideWith((ref) {
              coordinator = RecordingSyncCoordinator(
                SyncDependencies(
                  webDavSyncService: webDavSyncService,
                  webDavBackupService: webDavBackupService,
                  webDavBackupStateRepository: backupStateRepo,
                  readWebDavSettings: () => settingsController.state,
                  readCurrentAccountKey: () =>
                      sessionController.state.valueOrNull?.currentKey,
                  readCurrentAccount: () =>
                      sessionController.state.valueOrNull?.currentAccount,
                  readCurrentLocalLibrary: () => null,
                  readDatabase: () => db,
                  runMemosSync: () async => const MemoSyncSuccess(),
                ),
              );
              return coordinator!;
            }),
          ],
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const WebDavSyncScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Config sync only'), findsNothing);
    expect(find.text('Available for encrypted backup only'), findsOneWidget);

    await db.close();
  });

  testWidgets(
    'connection screen shows test connection action and success message',
    (WidgetTester tester) async {
      LocaleSettings.setLocale(AppLocale.en);
      final webDavSyncService = FakeWebDavSyncService(const <String>[]);
      final webDavBackupService = FakeWebDavBackupService();
      RecordingSyncCoordinator? coordinator;
      final backupStateRepo = FakeWebDavBackupStateRepository();
      final sessionController = FakeAppSessionController(
        const AsyncValue.data(AppSessionState(accounts: [], currentKey: null)),
      );
      final db = AppDatabase(dbName: 'webdav_connection_button_test.db');

      final settings = WebDavSettings.defaults.copyWith(
        enabled: true,
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
      );
      final settingsController = FakeWebDavSettingsController(settings);
      final progressTracker = WebDavBackupProgressTracker();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              webDavSettingsProvider.overrideWith((ref) => settingsController),
              webDavSettingsRepositoryProvider.overrideWithValue(
                FakeWebDavSettingsRepository(settings),
              ),
              webDavBackupPasswordRepositoryProvider.overrideWithValue(
                FakeWebDavBackupPasswordRepository(),
              ),
              webDavBackupProgressTrackerProvider.overrideWith(
                (ref) => progressTracker,
              ),
              webDavBackupStateRepositoryProvider.overrideWithValue(
                backupStateRepo,
              ),
              currentLocalLibraryProvider.overrideWithValue(null),
              appSessionProvider.overrideWith((ref) => sessionController),
              syncCoordinatorProvider.overrideWith((ref) {
                coordinator = RecordingSyncCoordinator(
                  SyncDependencies(
                    webDavSyncService: webDavSyncService,
                    webDavBackupService: webDavBackupService,
                    webDavBackupStateRepository: backupStateRepo,
                    readWebDavSettings: () => settingsController.state,
                    readCurrentAccountKey: () =>
                        sessionController.state.valueOrNull?.currentKey,
                    readCurrentAccount: () =>
                        sessionController.state.valueOrNull?.currentAccount,
                    readCurrentLocalLibrary: () => null,
                    readDatabase: () => db,
                    runMemosSync: () async => const MemoSyncSuccess(),
                  ),
                );
                return coordinator!;
              }),
            ],
            child: MaterialApp(
              locale: AppLocale.en.flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const WebDavSyncScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text(t.strings.legacy.msg_server_connection));
      await tester.pumpAndSettle();

      final testConnectionButton = find.byTooltip('Test connection');
      expect(testConnectionButton, findsOneWidget);
      await tester.tap(testConnectionButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Connection test passed. WebDAV is reachable and writable.'),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await db.close();
    },
  );

  testWidgets('backup settings abandon and confirm closes the screen', (
    WidgetTester tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final observer = _RecordingPageRouteObserver();
    final settings = WebDavSettings.defaults.copyWith(
      enabled: true,
      serverUrl: 'https://example.com',
      username: 'user',
      password: 'pass',
      backupEncryptionMode: WebDavBackupEncryptionMode.encrypted,
    );
    final db = await _pumpWebDavScreen(
      tester,
      settings: settings,
      observer: observer,
    );

    await tester.tap(find.text('Backup strategy settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.strings.legacy.msg_back));
    await tester.pumpAndSettle();

    expect(find.text('Backup password missing'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Abandon'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, t.strings.legacy.msg_confirm),
    );
    await tester.pumpAndSettle();

    expect(observer.popCount, 1);
    expect(find.text('Backup password missing'), findsNothing);
    expect(find.text(t.strings.legacy.msg_backup_settings), findsNothing);
    expect(find.text('Backup strategy settings'), findsOneWidget);

    await db.close();
  });

  testWidgets('plain backup settings close directly without prompt', (
    WidgetTester tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final observer = _RecordingPageRouteObserver();
    final settings = WebDavSettings.defaults.copyWith(
      enabled: true,
      serverUrl: 'https://example.com',
      username: 'user',
      password: 'pass',
      backupEncryptionMode: WebDavBackupEncryptionMode.plain,
    );
    final db = await _pumpWebDavScreen(
      tester,
      settings: settings,
      observer: observer,
    );

    await tester.tap(find.text('Backup strategy settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.strings.legacy.msg_back));
    await tester.pumpAndSettle();

    expect(observer.popCount, 1);
    expect(find.text('Backup password missing'), findsNothing);
    expect(find.text('Backup strategy settings'), findsOneWidget);

    await db.close();
  });
}
