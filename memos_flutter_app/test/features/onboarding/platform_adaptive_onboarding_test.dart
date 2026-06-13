import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/application/sync/local_library_import_migration_service.dart';
import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/repositories/local_library_repository.dart';
import 'package:memos_flutter_app/features/auth/login_screen.dart';
import 'package:memos_flutter_app/features/onboarding/language_selection_screen.dart';
import 'package:memos_flutter_app/features/settings/local_mode_setup_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
  });

  tearDown(() {
    debugPlatformTargetOverride = null;
  });

  testWidgets('first setup keeps primary action bounded on desktop', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.macOS;

    await tester.pumpWidget(_buildLanguageSelectionApp());
    await tester.pumpAndSettle();

    final button = _buttonInside(
      const ValueKey<String>('onboarding.getStartedAction'),
    );

    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, lessThanOrEqualTo(260));
  });

  testWidgets('first setup renders language selector on iPhone', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_buildLanguageSelectionApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('onboarding.languageSelector')),
      findsOneWidget,
    );
  });

  testWidgets('first setup opens platform language picker on iPhone', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_buildLanguageSelectionApp());
    await tester.pumpAndSettle();

    final screenContext = tester.element(find.byType(LanguageSelectionScreen));
    final japaneseLabel = screenContext.t.strings.languages.ja;
    await tester.tap(
      find.byKey(const ValueKey<String>('onboarding.languageSelector')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('onboarding.languagePickerList')),
      findsOneWidget,
    );
    final japaneseOption = find.byKey(
      const ValueKey<String>('onboarding.languageOption.ja'),
    );
    expect(japaneseOption, findsOneWidget);

    await tester.tap(japaneseOption);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(japaneseOption, findsNothing);
    expect(find.text(japaneseLabel), findsOneWidget);
  });

  testWidgets('login keeps connect action bounded on regular desktop', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      _buildApp(
        child: const LoginScreen(),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final button = _buttonInside(const ValueKey<String>('login.connectAction'));

    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, lessThanOrEqualTo(280));
  });

  testWidgets('login titlebar avoids macOS traffic lights', (tester) async {
    await _setViewport(tester, const Size(1200, 900));
    debugPlatformTargetOverride = TargetPlatform.macOS;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _buildApp(
          child: const LoginScreen(),
          overrides: [
            appSessionProvider.overrideWith((ref) => _TestSessionController()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LoginScreen));
      final backLeft = tester
          .getTopLeft(find.byTooltip(context.t.strings.common.back))
          .dx;
      final titleLeft = tester
          .getTopLeft(find.text(context.t.strings.login.title))
          .dx;

      expect(backLeft, greaterThanOrEqualTo(kMacosTrafficLightReservedWidth));
      expect(titleLeft, greaterThan(kMacosTrafficLightReservedWidth));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('local workspace setup keeps mobile actions full width', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 780));
    debugPlatformTargetOverride = TargetPlatform.android;

    await tester.pumpWidget(
      _buildApp(
        child: const LocalModeSetupScreen(
          title: 'Add local library',
          confirmLabel: 'Confirm',
          cancelLabel: 'Cancel',
          initialName: 'Local Library',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final confirmButton = _buttonInside(
      const ValueKey<String>('localModeSetup.confirmAction'),
    );
    final cancelButton = _buttonInside(
      const ValueKey<String>('localModeSetup.cancelAction'),
    );

    expect(confirmButton, findsOneWidget);
    expect(cancelButton, findsOneWidget);
    expect(tester.getSize(confirmButton).width, 326);
    expect(tester.getSize(cancelButton).width, 326);
  });

  testWidgets('login in narrow desktop can scroll to primary action', (
    tester,
  ) async {
    await _setViewport(tester, const Size(420, 360));
    debugPlatformTargetOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      _buildApp(
        child: const LoginScreen(),
        overrides: [
          appSessionProvider.overrideWith((ref) => _TestSessionController()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LoginScreen));
    final actionLabel = context.t.strings.login.connect.action;
    final actionText = find.text(actionLabel);
    expect(actionText, findsOneWidget);
    expect(tester.getTopLeft(actionText).dy, greaterThan(360));

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final button = _buttonInside(const ValueKey<String>('login.connectAction'));
    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, 380);
    expect(tester.getTopLeft(actionText).dy, lessThan(360));
  });
}

Widget _buildLanguageSelectionApp({AppLanguage language = AppLanguage.en}) {
  return _buildApp(
    child: const LanguageSelectionScreen(),
    overrides: [
      devicePreferencesProvider.overrideWith(
        (ref) => _TestDevicePreferencesController(
          ref,
          DevicePreferences.defaultsForLanguage(
            language,
          ).copyWith(hasSelectedLanguage: false),
        ),
      ),
      localLibrariesProvider.overrideWith(
        (ref) => _TestLocalLibrariesController(ref),
      ),
      appSessionProvider.overrideWith((ref) => _TestSessionController()),
    ],
  );
}

Finder _buttonInside(ValueKey<String> key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.bySubtype<ButtonStyleButton>(),
  );
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _buildApp({required Widget child, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      syncCoordinatorProvider.overrideWith((ref) => _NoopSyncFacade()),
      ...overrides,
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      ),
    ),
  );
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
  _TestDevicePreferencesRepository(this._prefs)
    : super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _prefs;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<DevicePreferences> read() async => _prefs;

  @override
  Future<void> write(DevicePreferences prefs) async {
    _prefs = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(Ref ref, DevicePreferences initial)
    : super(
        ref,
        _TestDevicePreferencesRepository(initial),
        onLoaded: () =>
            ref.read(devicePreferencesLoadedProvider.notifier).state = true,
      ) {
    state = initial;
  }
}

class _TestLocalLibraryRepository extends LocalLibraryRepository {
  _TestLocalLibraryRepository()
    : _state = const LocalLibraryState(libraries: <LocalLibrary>[]),
      super(const FlutterSecureStorage());

  LocalLibraryState _state;

  @override
  Future<StorageReadResult<LocalLibraryState>> readWithStatus() async {
    return StorageReadResult.success(_state);
  }

  @override
  Future<LocalLibraryState> read() async => _state;

  @override
  Future<void> write(LocalLibraryState state) async {
    _state = state;
  }
}

class _TestLocalLibrariesController extends LocalLibrariesController {
  _TestLocalLibrariesController(Ref ref)
    : super(
        _TestLocalLibraryRepository(),
        ref,
        migrationService: LocalLibraryImportMigrationService(),
        onLoaded: () =>
            ref.read(localLibrariesLoadedProvider.notifier).state = true,
      );
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
