// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/core/desktop/shortcuts.dart';
import 'package:memos_flutter_app/core/desktop_db_write_channel.dart';
import 'package:memos_flutter_app/core/desktop_quick_input_channel.dart';
import 'package:memos_flutter_app/core/desktop_runtime_role.dart';
import 'package:memos_flutter_app/core/desktop_sync_channel.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/application/desktop/desktop_settings_window.dart';
import 'package:memos_flutter_app/application/sync/local_library_import_migration_service.dart';
import 'package:memos_flutter_app/application/sync/desktop_remote_sync_facade.dart';
import 'package:memos_flutter_app/application/sync/sync_coordinator.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_request.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/application/sync/webdav_backup_service.dart';
import 'package:memos_flutter_app/application/sync/webdav_sync_service.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/logs/webdav_backup_progress_tracker.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/models/webdav_backup.dart';
import 'package:memos_flutter_app/data/models/webdav_export_status.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/models/webdav_sync_meta.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/data/repositories/local_library_repository.dart';
import 'package:memos_flutter_app/features/review/ai_insight_prompt_editor_screen.dart';
import 'package:memos_flutter_app/features/settings/ai_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/desktop_shortcuts_overview_screen.dart';
import 'package:memos_flutter_app/features/settings/desktop_shortcuts_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/desktop_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/desktop_settings_window_app.dart';
import 'package:memos_flutter_app/features/settings/feedback_screen.dart';
import 'package:memos_flutter_app/features/settings/location_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/memo_toolbar_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/self_repair_screen.dart';
import 'package:memos_flutter_app/features/settings/support_memoflow_screen.dart';
import 'package:memos_flutter_app/state/settings/ai_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/sync/sync_coordinator_provider.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';
import 'package:memos_flutter_app/state/webdav/webdav_backup_provider.dart';

import '../../test_support.dart';

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');
const MethodChannel _multiWindowChannel = MethodChannel(
  'mixin.one/flutter_multi_window',
);
const MethodChannel _multiWindowEventChannel = MethodChannel(
  'mixin.one/flutter_multi_window_channel',
);

class _TestSessionController extends AppSessionController {
  _TestSessionController({
    AppSessionState initialState = const AppSessionState(
      accounts: [],
      currentKey: null,
    ),
    this.reloadState,
  }) : super(AsyncValue.data(initialState));

  int reloadCalls = 0;
  AppSessionState? reloadState;

  static Account account({required String key, required String username}) {
    return Account(
      key: key,
      baseUrl: Uri.parse('https://example.com'),
      personalAccessToken: 'token-$key',
      user: User(
        name: username,
        username: username,
        displayName: username,
        avatarUrl: '',
        description: '',
      ),
      instanceProfile: const InstanceProfile.empty(),
      serverVersionOverride: '0.26.0',
    );
  }

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
  Future<void> setCurrentKey(String? key) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      AppSessionState(accounts: current.accounts, currentKey: key),
    );
  }

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  Future<void> reloadFromStorage() async {
    reloadCalls += 1;
    if (reloadState != null) {
      state = AsyncValue.data(reloadState!);
    }
  }

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

class _TestLocalLibraryRepository extends LocalLibraryRepository {
  _TestLocalLibraryRepository({LocalLibraryState? initialState})
    : _state = initialState ?? const LocalLibraryState(libraries: []),
      super(const FlutterSecureStorage());

  LocalLibraryState _state;
  int readCalls = 0;

  void setState(LocalLibraryState state) {
    _state = state;
  }

  @override
  Future<StorageReadResult<LocalLibraryState>> readWithStatus() async {
    readCalls += 1;
    return StorageReadResult.success(_state);
  }

  @override
  Future<LocalLibraryState> read() async {
    readCalls += 1;
    return _state;
  }

  @override
  Future<void> write(LocalLibraryState state) async {
    _state = state;
  }

  @override
  Future<void> clear() async {
    _state = const LocalLibraryState(libraries: []);
  }
}

class _NoopLocalLibraryImportMigrationService
    extends LocalLibraryImportMigrationService {
  @override
  Future<LocalLibrary> migrateIfNeeded(LocalLibrary library) async => library;
}

class _MemoryAiSettingsRepository extends AiSettingsRepository {
  _MemoryAiSettingsRepository(this._value)
    : super(const FlutterSecureStorage(), accountKey: 'test-account');

  AiSettings _value;

  @override
  Future<AiSettings> read({AppLanguage language = AppLanguage.en}) async {
    return _value;
  }

  @override
  Future<void> write(AiSettings settings) async {
    _value = settings;
  }
}

class _TestAppPreferencesRepository extends AppPreferencesRepository {
  _TestAppPreferencesRepository()
    : super(const FlutterSecureStorage(), accountKey: null);

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(
      AppPreferences.defaultsForLanguage(AppLanguage.en),
    );
  }

  @override
  Future<AppPreferences> read() async {
    return AppPreferences.defaultsForLanguage(AppLanguage.en);
  }

  @override
  Future<void> write(AppPreferences prefs) async {}

  @override
  Future<void> clear() async {}
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

class _TestNotifyingDatabase extends AppDatabase {
  _TestNotifyingDatabase({required this.dbNameForTest})
    : super(dbName: dbNameForTest, workspaceKey: dbNameForTest);

  final String dbNameForTest;
  int notifyCalls = 0;

  @override
  void notifyDataChanged() {
    notifyCalls += 1;
    super.notifyDataChanged();
  }
}

Future<dynamic> _dispatchIncomingMultiWindowMethod(
  String method, {
  int fromWindowId = 0,
  dynamic arguments,
}) async {
  final completer = Completer<ByteData?>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _multiWindowEventChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, <String, dynamic>{
            'fromWindowId': fromWindowId,
            'arguments': arguments,
          }),
        ),
        completer.complete,
      );
  final result = await completer.future;
  if (result == null) return null;
  return const StandardMethodCodec().decodeEnvelope(result);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final windowManagerCalls = <String>[];
  late TestSupport support;

  setUp(() async {
    support = await initializeTestSupport();
    windowManagerCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async {
          windowManagerCalls.add(call.method);
          switch (call.method) {
            case 'ensureInitialized':
            case 'setAsFrameless':
            case 'setHasShadow':
            case 'setBackgroundColor':
            case 'focus':
            case 'restore':
            case 'show':
            case 'hide':
            case 'close':
              return null;
            case 'isVisible':
              return true;
            case 'isMinimized':
              return false;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowChannel, (call) async {
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          if (call.method == 'desktop.quickInput.ping') {
            throw PlatformException(
              code: 'boom',
              message: 'main window unavailable',
            );
          }
          return true;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, null);
    await support.dispose();
  });

  testWidgets(
    'shows retryable main-window error state without reloading local session',
    (tester) async {
      final sessionController = _TestSessionController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.text(
          'Main window unavailable. Please reopen settings from the main window.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(sessionController.reloadCalls, 0);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(sessionController.reloadCalls, 0);
      expect(
        find.text(
          'Main window unavailable. Please reopen settings from the main window.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sub-window visibility and focus avoid window_manager visibility probe',
    (tester) async {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        await _dispatchIncomingMultiWindowMethod(
          desktopSubWindowIsVisibleMethod,
        ),
        isTrue,
      );
      await _dispatchIncomingMultiWindowMethod(desktopSettingsFocusMethod);
      await tester.pump();

      expect(windowManagerCalls, isNot(contains('isVisible')));
    },
  );

  testWidgets('sub-window exit reports invisible before closing', (
    tester,
  ) async {
    final sessionController = _TestSessionController();
    final visibilityPayloads = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
              return true;
            case 'desktop.subWindow.visibility':
              final args = call.arguments;
              if (args is Map) {
                visibilityPayloads.add(Map<Object?, Object?>.from(args));
              }
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return <String, dynamic>{
                'currentKey': null,
                'hasCurrentAccount': false,
                'hasLocalLibrary': false,
              };
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    visibilityPayloads.clear();

    final accepted = await _dispatchIncomingMultiWindowMethod(
      desktopSubWindowExitMethod,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(accepted, isTrue);
    expect(
      visibilityPayloads,
      contains(
        allOf(
          containsPair('targetWindowId', 0),
          containsPair('arguments', containsPair('visible', false)),
        ),
      ),
    );
  });

  testWidgets('macOS settings title avoids native traffic lights', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final titleLeft = tester.getTopLeft(find.text('Settings').first).dx;

      expect(titleLeft, greaterThan(kMacosTrafficLightReservedWidth));
      expect(find.byIcon(Icons.close), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('macOS settings window exposes desktop pane and shared route', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.devices_outlined), findsOneWidget);
      expect(find.text('Desktop settings'), findsOneWidget);

      await tester.tap(find.text('Desktop settings'));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopSettingsScreen), findsOneWidget);
      expect(find.text('Shortcut settings'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('macOS settings window opens support page public fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('Support MemoFlow'), findsOneWidget);
      expect(find.text('Import / Export'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);

      final supportTop = tester.getTopLeft(find.text('Support MemoFlow')).dy;
      final importExportTop = tester
          .getTopLeft(find.text('Import / Export'))
          .dy;
      final aboutTop = tester.getTopLeft(find.text('About')).dy;
      expect(supportTop, lessThan(importExportTop));
      expect(importExportTop, lessThan(aboutTop));

      await tester.tap(find.text('Support MemoFlow'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('supportMemoFlow.publicAppreciationSection'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('supportMemoFlow.openSupportLink')),
        findsNothing,
      );
      expect(find.text('Purchase'), findsNothing);
      expect(find.text('Restore purchase'), findsNothing);
      expect(find.text('MemoFlow Pro'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows settings target opens support page public fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        DesktopSettingsWindowTarget.fromPayload(
          DesktopSettingsWindowTarget.supportMemoFlow.toJson(),
        ),
        DesktopSettingsWindowTarget.supportMemoFlow,
      );
      expect(find.text('Support MemoFlow'), findsOneWidget);

      final accepted = await _dispatchIncomingMultiWindowMethod(
        desktopSettingsOpenTargetMethod,
        arguments: DesktopSettingsWindowTarget.supportMemoFlow.toJson(),
      );
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
      expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('supportMemoFlow.publicAppreciationSection'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('supportMemoFlow.openSupportLink')),
        findsNothing,
      );
      expect(find.text('Purchase'), findsNothing);
      expect(find.text('Restore purchase'), findsNothing);
      expect(find.text('MemoFlow Pro'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Linux settings window hides desktop pane and shortcut target', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(
            windowId: 7,
            initialTarget: DesktopSettingsWindowTarget.desktopShortcuts,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.devices_outlined), findsNothing);
      expect(find.text('Desktop settings'), findsNothing);
      expect(find.byType(DesktopSettingsScreen), findsNothing);
      expect(find.byType(DesktopShortcutsSettingsScreen), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('initial AI target opens the AI settings pane', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      final aiRepo = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
            aiSettingsRepositoryProvider.overrideWith((ref) => aiRepo),
          ],
          child: const DesktopSettingsWindowApp(
            windowId: 7,
            initialTarget: DesktopSettingsWindowTarget.ai,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AiSettingsScreen), findsOneWidget);
      expect(find.text('AI Settings'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('runtime AI target switches an existing settings window pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      final aiRepo = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
            aiSettingsRepositoryProvider.overrideWith((ref) => aiRepo),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AiSettingsScreen), findsNothing);
      expect(find.text('Account & Security'), findsWidgets);

      final accepted = await _dispatchIncomingMultiWindowMethod(
        desktopSettingsOpenTargetMethod,
        arguments: DesktopSettingsWindowTarget.ai.toJson(),
      );
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
      expect(find.byType(AiSettingsScreen), findsOneWidget);
      expect(find.text('AI Settings'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('quick prompts target opens persistent custom template editor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      final aiRepo = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
            aiSettingsRepositoryProvider.overrideWith((ref) => aiRepo),
          ],
          child: const DesktopSettingsWindowApp(
            windowId: 7,
            initialTarget: DesktopSettingsWindowTarget.quickPrompts,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      final screen = tester.widget<AiInsightPromptEditorScreen>(
        find.byType(AiInsightPromptEditorScreen),
      );
      expect(screen.customTemplateMode, isTrue);
      expect(screen.templateId, isNull);
      expect(find.text('New Custom Template'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('initial nested target opens inside the owning settings pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(
            windowId: 7,
            initialTarget: DesktopSettingsWindowTarget.location,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(LocationSettingsScreen), findsOneWidget);
      expect(find.text('Components'), findsWidgets);
      expect(tester.getTopLeft(find.text('Location').last).dy, greaterThan(46));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('runtime nested target resets unrelated pane navigation', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Components').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Image Bed').first);
      await tester.pumpAndSettle();

      expect(find.text('Image Bed'), findsWidgets);

      final accepted = await _dispatchIncomingMultiWindowMethod(
        desktopSettingsOpenTargetMethod,
        arguments: DesktopSettingsWindowTarget.memoToolbar.toJson(),
      );
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
      expect(find.byType(MemoToolbarSettingsScreen), findsOneWidget);
      expect(find.text('Image Bed'), findsNothing);
      expect(find.text('Preferences'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('owner-surface pane root target opens feedback pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(
            windowId: 7,
            initialTarget: DesktopSettingsWindowTarget.feedback,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(FeedbackScreen), findsOneWidget);
      expect(find.byType(SelfRepairScreen), findsNothing);
      expect(find.text('Help & Diagnostics'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('owner-surface nested target opens inside feedback pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(
            windowId: 7,
            initialTarget: DesktopSettingsWindowTarget.selfRepair,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(SelfRepairScreen), findsOneWidget);
      expect(find.text('Help & Diagnostics'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop shortcuts overview target uses current bindings', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(
            windowId: 7,
            initialTarget: DesktopSettingsWindowTarget.desktopShortcutsOverview,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      final screen = tester.widget<DesktopShortcutsOverviewScreen>(
        find.byType(DesktopShortcutsOverviewScreen),
      );
      final expected = normalizeDesktopShortcutBindings(
        DevicePreferences.defaults.desktopShortcutBindings,
      );

      expect(screen.bindings.keys, containsAll(expected.keys));
      expect(
        screen.bindings[DesktopShortcutAction.search]?.keyId,
        expected[DesktopShortcutAction.search]?.keyId,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('macOS nested settings detail stays inside content pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final sessionController = _TestSessionController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
            switch (call.method) {
              case 'desktop.quickInput.ping':
              case 'desktop.settings.ping':
              case 'desktop.subWindow.visibility':
                return true;
              case 'desktop.main.getWorkspaceSnapshot':
                return <String, dynamic>{
                  'currentKey': null,
                  'hasCurrentAccount': false,
                  'hasLocalLibrary': false,
                };
            }
            return true;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSessionProvider.overrideWith((ref) => sessionController),
            appPreferencesProvider.overrideWith(
              (ref) => _TestAppPreferencesController(ref),
            ),
          ],
          child: const DesktopSettingsWindowApp(windowId: 7),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Components').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Image Bed').first);
      await tester.pumpAndSettle();

      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);
      expect(find.text('Image Bed'), findsWidgets);
      expect(
        tester.getTopLeft(find.text('Image Bed').last).dy,
        greaterThan(46),
      );

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Components'), findsWidgets);
      expect(find.text('Image Bed'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('refreshSession resets nested settings route to home pane', (
    tester,
  ) async {
    final sessionController = _TestSessionController();
    final localLibraryRepo = _TestLocalLibraryRepository();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
            case 'desktop.subWindow.visibility':
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return <String, dynamic>{
                'currentKey': null,
                'hasCurrentAccount': false,
                'hasLocalLibrary': false,
              };
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          localLibraryRepositoryProvider.overrideWith(
            (ref) => localLibraryRepo,
          ),
          localLibraryImportMigrationServiceProvider.overrideWith(
            (ref) => _NoopLocalLibraryImportMigrationService(),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Components').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Image Bed').first);
    await tester.pumpAndSettle();

    expect(find.text('Image Bed'), findsWidgets);

    await _dispatchIncomingMultiWindowMethod(
      desktopSettingsRefreshSessionMethod,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Image Bed'), findsNothing);
    expect(find.text('Account & Security'), findsWidgets);
  });

  testWidgets('refreshSession reloads local workspace state before redraw', (
    tester,
  ) async {
    final oldAccount = _TestSessionController.account(
      key: 'users/old',
      username: 'old',
    );
    final newAccount = _TestSessionController.account(
      key: 'users/new',
      username: 'new',
    );
    final sessionController = _TestSessionController(
      initialState: AppSessionState(
        accounts: [oldAccount],
        currentKey: oldAccount.key,
      ),
      reloadState: AppSessionState(
        accounts: [newAccount],
        currentKey: newAccount.key,
      ),
    );
    final localLibraryRepo = _TestLocalLibraryRepository(
      initialState: const LocalLibraryState(
        libraries: [
          LocalLibrary(
            key: 'old-library',
            name: 'Old Library',
            storageKind: LocalLibraryStorageKind.managedPrivate,
            rootPath: 'C:/old',
          ),
        ],
      ),
    );
    var snapshot = <String, dynamic>{
      'currentKey': oldAccount.key,
      'hasCurrentAccount': true,
      'hasLocalLibrary': false,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
            case 'desktop.subWindow.visibility':
            case 'desktop.main.reloadWorkspace':
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return snapshot;
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          localLibraryRepositoryProvider.overrideWith(
            (ref) => localLibraryRepo,
          ),
          localLibraryImportMigrationServiceProvider.overrideWith(
            (ref) => _NoopLocalLibraryImportMigrationService(),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    localLibraryRepo.setState(
      const LocalLibraryState(
        libraries: [
          LocalLibrary(
            key: 'new-library',
            name: 'New Library',
            storageKind: LocalLibraryStorageKind.managedPrivate,
            rootPath: 'C:/new',
          ),
        ],
      ),
    );
    snapshot = <String, dynamic>{
      'currentKey': newAccount.key,
      'hasCurrentAccount': true,
      'hasLocalLibrary': false,
    };

    await _dispatchIncomingMultiWindowMethod(
      desktopSettingsRefreshSessionMethod,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopSettingsWindowApp)),
      listen: false,
    );
    expect(sessionController.reloadCalls, 1);
    expect(localLibraryRepo.readCalls, greaterThanOrEqualTo(2));
    expect(
      container.read(appSessionProvider).valueOrNull?.currentKey,
      newAccount.key,
    );
    expect(container.read(localLibrariesProvider).map((e) => e.key), [
      'new-library',
    ]);
    expect(
      container.read(desktopSettingsWorkspaceSnapshotProvider)?.currentKey,
      newAccount.key,
    );
  });

  testWidgets('local workspace switch updates desktop snapshot immediately', (
    tester,
  ) async {
    final account = _TestSessionController.account(
      key: 'users/active',
      username: 'active',
    );
    final sessionController = _TestSessionController(
      initialState: AppSessionState(
        accounts: [account],
        currentKey: account.key,
      ),
    );
    final localLibraryRepo = _TestLocalLibraryRepository(
      initialState: const LocalLibraryState(
        libraries: [
          LocalLibrary(
            key: 'local-workspace',
            name: 'Local Workspace',
            storageKind: LocalLibraryStorageKind.managedPrivate,
            rootPath: 'C:/workspace',
          ),
        ],
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
            case 'desktop.subWindow.visibility':
            case 'desktop.main.reloadWorkspace':
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return <String, dynamic>{
                'currentKey': account.key,
                'hasCurrentAccount': true,
                'hasLocalLibrary': false,
              };
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          localLibraryRepositoryProvider.overrideWith(
            (ref) => localLibraryRepo,
          ),
          localLibraryImportMigrationServiceProvider.overrideWith(
            (ref) => _NoopLocalLibraryImportMigrationService(),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await sessionController.setCurrentKey('local-workspace');
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopSettingsWindowApp)),
      listen: false,
    );
    final snapshot = container.read(desktopSettingsWorkspaceSnapshotProvider);
    expect(snapshot?.currentKey, 'local-workspace');
    expect(snapshot?.hasLocalLibrary, isTrue);
  });

  testWidgets('desktop db changed event invalidates local database listeners', (
    tester,
  ) async {
    final account = _TestSessionController.account(
      key: 'users/demo',
      username: 'demo',
    );
    final sessionController = _TestSessionController(
      initialState: AppSessionState(
        accounts: [account],
        currentKey: account.key,
      ),
    );
    final db = _TestNotifyingDatabase(
      dbNameForTest: databaseNameForAccountKey(account.key),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
            case 'desktop.subWindow.visibility':
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return <String, dynamic>{
                'currentKey': account.key,
                'hasCurrentAccount': true,
                'hasLocalLibrary': false,
              };
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith((ref) => sessionController),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
          databaseProvider.overrideWithValue(db),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _dispatchIncomingMultiWindowMethod(
      desktopDbChangedMethod,
      arguments: <String, dynamic>{
        'workspaceKey': account.key,
        'dbName': databaseNameForAccountKey(account.key),
        'changeId': 'test-change',
        'category': 'app_database.upsertMemo',
        'originWindowId': 0,
      },
    );
    await tester.pump();

    expect(db.notifyCalls, 1);
  });

  testWidgets('desktop sync events update mirrored state and progress', (
    tester,
  ) async {
    final account = _TestSessionController.account(
      key: 'users/sync',
      username: 'sync',
    );
    final sessionController = _TestSessionController(
      initialState: AppSessionState(
        accounts: [account],
        currentKey: account.key,
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
            case 'desktop.subWindow.visibility':
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return <String, dynamic>{
                'currentKey': account.key,
                'hasCurrentAccount': true,
                'hasLocalLibrary': false,
              };
            case desktopSyncStateSnapshotMethod:
              return desktopSyncRpcSuccess(
                SyncCoordinatorState.initial.toJson(),
              );
            case desktopSyncProgressSnapshotMethod:
              return desktopSyncRpcSuccess(
                WebDavBackupProgressSnapshot.idle.toJson(),
              );
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          desktopRuntimeRoleProvider.overrideWith(
            (ref) => DesktopRuntimeRole.desktopSettings,
          ),
          desktopWindowIdProvider.overrideWith((ref) => 7),
          appSessionProvider.overrideWith((ref) => sessionController),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _dispatchIncomingMultiWindowMethod(
      desktopSyncStateChangedMethod,
      arguments: <String, dynamic>{
        'workspaceKey': account.key,
        'state': SyncCoordinatorState(
          memos: SyncFlowStatus.idle,
          webDavSync: const SyncFlowStatus(
            running: true,
            lastSuccessAt: null,
            lastError: null,
            hasPendingConflict: true,
            attention: null,
          ),
          webDavBackup: SyncFlowStatus.idle,
          localScan: SyncFlowStatus.idle,
          webDavLastBackupAt: null,
          webDavRestoring: false,
          pendingWebDavConflicts: const <String>['memo-1'],
          pendingLocalScanConflicts: const <LocalScanConflict>[],
        ).toJson(),
      },
    );
    await _dispatchIncomingMultiWindowMethod(
      desktopSyncProgressChangedMethod,
      arguments: <String, dynamic>{
        'workspaceKey': account.key,
        'progress': const WebDavBackupProgressSnapshot(
          running: true,
          paused: true,
          operation: WebDavBackupProgressOperation.backup,
          stage: WebDavBackupProgressStage.uploading,
          completed: 2,
          total: 5,
          currentPath: 'backup/memo-1.md',
          itemGroup: WebDavBackupProgressItemGroup.memo,
        ).toJson(),
      },
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopSettingsWindowApp)),
      listen: false,
    );
    expect(container.read(syncCoordinatorProvider).webDavSync.running, isTrue);
    expect(container.read(syncCoordinatorProvider).pendingWebDavConflicts, [
      'memo-1',
    ]);
    final snapshot = container
        .read(webDavBackupProgressTrackerProvider)
        .snapshot;
    expect(snapshot.running, isTrue);
    expect(snapshot.paused, isTrue);
    expect(snapshot.completed, 2);
    expect(snapshot.total, 5);
  });

  testWidgets('desktop backup export prompt is forwarded to remote facade', (
    tester,
  ) async {
    final account = _TestSessionController.account(
      key: 'users/prompt',
      username: 'prompt',
    );
    final sessionController = _TestSessionController(
      initialState: AppSessionState(
        accounts: [account],
        currentKey: account.key,
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
            case 'desktop.subWindow.visibility':
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return <String, dynamic>{
                'currentKey': account.key,
                'hasCurrentAccount': true,
                'hasLocalLibrary': false,
              };
            case desktopSyncStateSnapshotMethod:
              return desktopSyncRpcSuccess(
                SyncCoordinatorState.initial.toJson(),
              );
            case desktopSyncProgressSnapshotMethod:
              return desktopSyncRpcSuccess(
                WebDavBackupProgressSnapshot.idle.toJson(),
              );
            case desktopSyncRequestMethod:
              return desktopSyncRpcSuccess(
                syncRunResultToJson(const SyncRunStarted()),
              );
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          desktopRuntimeRoleProvider.overrideWith(
            (ref) => DesktopRuntimeRole.desktopSettings,
          ),
          desktopWindowIdProvider.overrideWith((ref) => 7),
          appSessionProvider.overrideWith((ref) => sessionController),
          syncCoordinatorProvider.overrideWith((ref) => _PromptSyncFacade()),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final raw = await _dispatchIncomingMultiWindowMethod(
      desktopSyncPromptBackupExportIssueMethod,
      arguments: <String, dynamic>{
        'workspaceKey': account.key,
        'requestId': 'prompt-request-1',
        'sessionId': 'prompt-session-1',
        'issue': serializeWebDavBackupExportIssue(
          const WebDavBackupExportIssue(
            kind: WebDavBackupExportIssueKind.memo,
            memoUid: 'memo-42',
            error: 'export failed',
          ),
        ),
      },
    );
    await tester.pump();

    expect(raw, isA<Map>());
    final resolution = deserializeWebDavBackupExportPromptResponse(
      raw,
      expectedMetadata: const DesktopSyncPromptMetadata(
        requestId: 'prompt-request-1',
        sessionId: 'prompt-session-1',
      ),
    );
    expect(resolution.action, WebDavBackupExportAction.skip);
    expect(resolution.applyToRemainingFailures, isTrue);
  });

  testWidgets('desktop backup config restore prompt is forwarded to facade', (
    tester,
  ) async {
    final account = _TestSessionController.account(
      key: 'users/config',
      username: 'config',
    );
    final sessionController = _TestSessionController(
      initialState: AppSessionState(
        accounts: [account],
        currentKey: account.key,
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, (call) async {
          switch (call.method) {
            case 'desktop.quickInput.ping':
            case 'desktop.settings.ping':
            case 'desktop.subWindow.visibility':
              return true;
            case 'desktop.main.getWorkspaceSnapshot':
              return <String, dynamic>{
                'currentKey': account.key,
                'hasCurrentAccount': true,
                'hasLocalLibrary': false,
              };
            case desktopSyncStateSnapshotMethod:
              return desktopSyncRpcSuccess(
                SyncCoordinatorState.initial.toJson(),
              );
            case desktopSyncProgressSnapshotMethod:
              return desktopSyncRpcSuccess(
                WebDavBackupProgressSnapshot.idle.toJson(),
              );
          }
          return true;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          desktopRuntimeRoleProvider.overrideWith(
            (ref) => DesktopRuntimeRole.desktopSettings,
          ),
          desktopWindowIdProvider.overrideWith((ref) => 7),
          appSessionProvider.overrideWith((ref) => sessionController),
          syncCoordinatorProvider.overrideWith((ref) => _PromptSyncFacade()),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref),
          ),
        ],
        child: const DesktopSettingsWindowApp(windowId: 7),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final raw = await _dispatchIncomingMultiWindowMethod(
      desktopSyncPromptBackupConfigRestoreMethod,
      arguments: <String, dynamic>{
        'workspaceKey': account.key,
        'requestId': 'prompt-request-2',
        'sessionId': 'prompt-session-2',
        'configTypes': <String>[
          WebDavBackupConfigType.aiSettings.name,
          WebDavBackupConfigType.webdavSettings.name,
        ],
      },
    );
    await tester.pump();

    expect(raw, isA<Map>());
    final selected = deserializeWebDavBackupConfigPromptResponse(
      raw,
      expectedMetadata: const DesktopSyncPromptMetadata(
        requestId: 'prompt-request-2',
        sessionId: 'prompt-session-2',
      ),
    );
    expect(
      selected.map((item) => item.name),
      containsAll(<String>[
        WebDavBackupConfigType.aiSettings.name,
        WebDavBackupConfigType.webdavSettings.name,
      ]),
    );
  });
}

class _PromptSyncFacade extends DesktopSyncFacade {
  _PromptSyncFacade() : super(SyncCoordinatorState.initial);

  @override
  Future<WebDavBackupExportResolution> handleBackupExportIssuePrompt(
    WebDavBackupExportIssue issue,
  ) async {
    return const WebDavBackupExportResolution(
      action: WebDavBackupExportAction.skip,
      applyToRemainingFailures: true,
    );
  }

  @override
  Future<Set<WebDavBackupConfigType>> handleBackupConfigRestorePrompt(
    Set<WebDavBackupConfigType> candidates,
  ) async {
    return candidates;
  }

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
