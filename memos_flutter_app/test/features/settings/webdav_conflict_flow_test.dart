import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/webdav_backup_state.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/settings/webdav_backup_password_repository.dart';
import 'package:memos_flutter_app/data/settings/webdav_backup_state_repository.dart';
import 'package:memos_flutter_app/data/settings/webdav_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/webdav_sync_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/local_library_provider.dart';
import 'package:memos_flutter_app/state/session_provider.dart';
import 'package:memos_flutter_app/state/webdav_backup_provider.dart';
import 'package:memos_flutter_app/state/webdav_settings_provider.dart';

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
}

class FakeWebDavBackupService implements WebDavBackupService {
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
  FakeWebDavSettingsController(WebDavSettings settings) : super(settings);

  @override
  void setEnabled(bool value) => state = state.copyWith(enabled: value);

  @override
  void setServerUrl(String value) => state = state.copyWith(serverUrl: value);

  @override
  void setUsername(String value) => state = state.copyWith(username: value);

  @override
  void setPassword(String value) => state = state.copyWith(password: value);

  @override
  void setAuthMode(WebDavAuthMode mode) => state = state.copyWith(authMode: mode);

  @override
  void setIgnoreTlsErrors(bool value) =>
      state = state.copyWith(ignoreTlsErrors: value);

  @override
  void setRootPath(String value) => state = state.copyWith(rootPath: value);

  @override
  void setVaultEnabled(bool value) => state = state.copyWith(vaultEnabled: value);

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

class RecordingSyncCoordinator extends SyncCoordinator {
  RecordingSyncCoordinator(
    super.ref,
    super.webDavSyncService,
    super.webDavBackupService,
  );

  Map<String, bool>? lastWebDavResolutions;

  @override
  Future<void> resolveWebDavConflicts(Map<String, bool> resolutions) async {
    lastWebDavResolutions = Map<String, bool>.from(resolutions);
    await super.resolveWebDavConflicts(resolutions);
  }
}

void main() {
  testWidgets('webdav sync conflict flow uses coordinator resolution', (
    WidgetTester tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    final conflicts = <String>['preferences.json'];
    final webDavSyncService = FakeWebDavSyncService(conflicts);
    final webDavBackupService = FakeWebDavBackupService();
    RecordingSyncCoordinator? coordinator;

    final settings = WebDavSettings.defaults.copyWith(
      enabled: true,
      serverUrl: 'https://example.com',
      username: 'user',
      password: 'pass',
    );
    final settingsController = FakeWebDavSettingsController(settings);

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
            webDavBackupStateRepositoryProvider.overrideWithValue(
              FakeWebDavBackupStateRepository(),
            ),
            currentLocalLibraryProvider.overrideWithValue(null),
            appSessionProvider.overrideWith(
              (ref) => FakeAppSessionController(
                const AsyncValue.data(
                  AppSessionState(accounts: [], currentKey: null),
                ),
              ),
            ),
            syncCoordinatorProvider.overrideWith((ref) {
              coordinator = RecordingSyncCoordinator(
                ref,
                webDavSyncService,
                webDavBackupService,
              );
              return coordinator!;
            }),
          ],
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates:
                GlobalMaterialLocalizations.delegates,
            home: const WebDavSyncScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sync));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text(t.strings.legacy.msg_use_remote));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.strings.legacy.msg_apply));
    await tester.pumpAndSettle();

    expect(
      coordinator?.lastWebDavResolutions,
      equals(const {'preferences.json': false}),
    );
  });
}
