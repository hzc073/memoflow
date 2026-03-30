import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/desktop_quick_input_channel.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/data/repositories/local_library_repository.dart';
import 'package:memos_flutter_app/features/settings/desktop_settings_window_app.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

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

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async {
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

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_multiWindowEventChannel, null);
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
}
