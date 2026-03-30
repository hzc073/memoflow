import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_dependencies.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/logs/sync_queue_progress_tracker.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/data/models/memo_reminder.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/data/models/user_setting.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_backup_state.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/repositories/location_settings_repository.dart';
import 'package:memos_flutter_app/data/repositories/memo_template_settings_repository.dart';
import 'package:memos_flutter_app/data/repositories/scene_micro_guide_repository.dart';
import 'package:memos_flutter_app/data/repositories/webdav_backup_state_repository.dart';
import 'package:memos_flutter_app/features/memos/memos_list_screen.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_memo_card.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_list_providers.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/settings/location_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/memo_template_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/reminder_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/user_settings_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/logging_provider.dart';
import 'package:memos_flutter_app/state/system/reminder_providers.dart';
import 'package:memos_flutter_app/state/system/scene_micro_guide_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async {
          switch (call.method) {
            case 'isMaximized':
              return false;
            case 'isVisible':
              return true;
            case 'isMinimized':
              return false;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
  });

  testWidgets(
    'screen stays stable across memo stream append, mutate, and rebuild updates',
    (tester) async {
      final memosController = StreamController<List<LocalMemo>>.broadcast();
      addTearDown(memosController.close);

      await tester.pumpWidget(
        _buildHarness(memosStream: memosController.stream),
      );

      final firstMemo = _buildMemo(uid: 'memo-1', content: 'First memo');
      memosController.add(<LocalMemo>[firstMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsOneWidget);
      expect(tester.takeException(), isNull);

      final secondMemo = _buildMemo(uid: 'memo-2', content: 'Second memo');
      memosController.add(<LocalMemo>[firstMemo, secondMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final updatedFirstMemo = _buildMemo(
        uid: 'memo-1',
        content: 'First memo updated',
      );
      memosController.add(<LocalMemo>[updatedFirstMemo, secondMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      memosController.add(<LocalMemo>[secondMemo]);
      await _pumpScreenFrames(tester);

      expect(find.byType(MemoListCard), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Future<void> _pumpScreenFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 32));
}

Widget _buildHarness({required Stream<List<LocalMemo>> memosStream}) {
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(_MemorySecureStorage()),
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
      appPreferencesProvider.overrideWith(
        (ref) => _TestAppPreferencesController(ref),
      ),
      locationSettingsProvider.overrideWith(
        (ref) => _TestLocationSettingsController(ref),
      ),
      reminderSettingsProvider.overrideWith(
        (ref) => _TestReminderSettingsController(ref),
      ),
      memoTemplateSettingsProvider.overrideWith(
        (ref) => _TestMemoTemplateSettingsController(ref),
      ),
      sceneMicroGuideProvider.overrideWith(
        (ref) => _TestSceneMicroGuideController(),
      ),
      syncCoordinatorProvider.overrideWith((ref) => _TestSyncCoordinator()),
      memosStreamProvider.overrideWith((ref, query) => memosStream),
      shortcutsProvider.overrideWith((ref) async => const []),
      tagStatsProvider.overrideWith((ref) => Stream.value(const <TagStat>[])),
      tagColorLookupProvider.overrideWith((ref) => TagColorLookup(const [])),
      memoReminderMapProvider.overrideWith(
        (ref) => const <String, MemoReminder>{},
      ),
      currentLocalLibraryProvider.overrideWith((ref) => null),
      memosListOutboxStatusProvider.overrideWith(
        (ref) => Stream.value(const OutboxMemoStatus.empty()),
      ),
      memosListNormalMemoCountProvider.overrideWith((ref) => Stream.value(1)),
      userGeneralSettingProvider.overrideWith(
        (ref) async => const UserGeneralSetting(),
      ),
      syncQueueProgressTrackerProvider.overrideWith(
        (ref) => SyncQueueProgressTracker(),
      ),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(1280, 1800)),
          child: MemosListScreen(
            title: 'Memos',
            state: 'NORMAL',
            showDrawer: false,
            enableCompose: false,
            enableSearch: false,
            enableTitleMenu: false,
            showPillActions: false,
          ),
        ),
      ),
    ),
  );
}

LocalMemo _buildMemo({required String uid, required String content}) {
  final now = DateTime(2025, 1, 2, 3, 4, 5);
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: computeContentFingerprint(content),
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: now,
    updateTime: now,
    tags: const <String>[],
    attachments: const <Attachment>[],
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
  );
}

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

class _TestSessionController extends AppSessionController {
  _TestSessionController()
    : super(
        const AsyncValue.data(
          AppSessionState(accounts: [], currentKey: 'test-account'),
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
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentKey(String? key) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}
}

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository()
    : super(_MemorySecureStorage(), accountKey: null);

  @override
  Future<void> clear() async {}

  @override
  Future<AppPreferences> read() async {
    return AppPreferences.defaultsForLanguage(AppLanguage.en);
  }

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
  }

  @override
  Future<void> write(AppPreferences prefs) async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref)
    : super(
        ref,
        _TestAppPreferencesRepository(),
        onLoaded: () {
          ref.read(appPreferencesLoadedProvider.notifier).state = true;
        },
      );
}

class _TestLocationSettingsController extends LocationSettingsController {
  _TestLocationSettingsController(Ref ref)
    : super(ref, _TestLocationSettingsRepository());
}

class _TestLocationSettingsRepository extends LocationSettingsRepository {
  _TestLocationSettingsRepository()
    : super(_MemorySecureStorage(), accountKey: 'test-account');

  @override
  Future<void> clear() async {}

  @override
  Future<LocationSettings> read() async => LocationSettings.defaults;

  @override
  Future<void> write(LocationSettings settings) async {}
}

class _TestReminderSettingsController extends ReminderSettingsController {
  _TestReminderSettingsController(Ref ref)
    : super(
        ref,
        _TestReminderSettingsRepository(),
        onLoaded: () {
          ref.read(reminderSettingsLoadedProvider.notifier).state = true;
        },
      );
}

class _TestReminderSettingsRepository extends ReminderSettingsRepository {
  _TestReminderSettingsRepository()
    : super(_MemorySecureStorage(), accountKey: null);

  @override
  Future<ReminderSettings?> read() async {
    return ReminderSettings.defaultsFor(AppLanguage.en);
  }

  @override
  Future<void> write(ReminderSettings settings) async {}
}

class _TestMemoTemplateSettingsController
    extends MemoTemplateSettingsController {
  _TestMemoTemplateSettingsController(Ref ref)
    : super(ref, _TestMemoTemplateSettingsRepository());
}

class _TestMemoTemplateSettingsRepository
    extends MemoTemplateSettingsRepository {
  _TestMemoTemplateSettingsRepository()
    : super(_MemorySecureStorage(), accountKey: 'test-account');

  @override
  Future<MemoTemplateSettings> read() async => MemoTemplateSettings.defaults;

  @override
  Future<void> write(MemoTemplateSettings settings) async {}

  @override
  Future<void> clear() async {}
}

class _TestSceneMicroGuideController extends SceneMicroGuideController {
  _TestSceneMicroGuideController()
    : super(SceneMicroGuideRepository(_MemorySecureStorage()));
}

class _TestSyncCoordinator extends SyncCoordinator {
  _TestSyncCoordinator()
    : super(
        SyncDependencies(
          webDavSyncService: _FakeWebDavSyncService(),
          webDavBackupService: _FakeWebDavBackupService(),
          webDavBackupStateRepository: _FakeWebDavBackupStateRepository(),
          readWebDavSettings: () => WebDavSettings.defaults,
          readCurrentAccountKey: () => null,
          readCurrentAccount: () => null,
          readCurrentLocalLibrary: () => null,
          readDatabase: () => throw UnsupportedError('unused in screen test'),
          runMemosSync: () async => const MemoSyncSuccess(),
        ),
      );
}

class _FakeWebDavSyncService implements WebDavSyncService {
  @override
  Future<WebDavSyncMeta?> cleanDeprecatedRemotePlainFiles({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return null;
  }

  @override
  Future<WebDavSyncMeta?> fetchRemoteMeta({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return null;
  }

  @override
  Future<WebDavSyncResult> syncNow({
    required WebDavSettings settings,
    required String? accountKey,
    Map<String, bool>? conflictResolutions,
  }) async {
    return const WebDavSyncSuccess();
  }

  @override
  Future<WebDavConnectionTestResult> testConnection({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    return const WebDavConnectionTestResult.success();
  }
}

class _FakeWebDavBackupService implements WebDavBackupService {
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
  Future<WebDavExportCleanupStatus> cleanPlainExport({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
  }) async {
    return WebDavExportCleanupStatus.notFound;
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
  Future<String?> setupBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return null;
  }

  @override
  Future<List<WebDavBackupSnapshotInfo>> listSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    return const <WebDavBackupSnapshotInfo>[];
  }

  @override
  Future<String> recoverBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    return '';
  }

  @override
  Future<WebDavRestoreResult> restorePlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return const WebDavRestoreSkipped();
  }

  @override
  Future<WebDavRestoreResult> restorePlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return const WebDavRestoreSkipped();
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
  }) async {
    return const WebDavRestoreSkipped();
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
  }) async {
    return const WebDavRestoreSkipped();
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
}

class _FakeWebDavBackupStateRepository implements WebDavBackupStateRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<WebDavBackupState> read() async => WebDavBackupState.empty;

  @override
  Future<void> write(WebDavBackupState state) async {}
}
