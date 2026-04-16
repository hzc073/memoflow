import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/desktop_runtime_role.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/repositories/accounts_repository.dart';
import 'package:memos_flutter_app/data/repositories/windows_locked_secure_storage.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

class _FakeAccountsRepository extends AccountsRepository {
  _FakeAccountsRepository({
    required AccountsState initialState,
    this.failingWrites = 0,
  }) : _persisted = initialState,
       super(const FlutterSecureStorage());

  AccountsState _persisted;
  int failingWrites;
  int writeAttempts = 0;

  AccountsState get persisted => _persisted;

  @override
  Future<StorageReadResult<AccountsState>> readWithStatus() async {
    return StorageReadResult.success(_persisted);
  }

  @override
  Future<AccountsState> read() async => _persisted;

  @override
  Future<void> write(AccountsState state) async {
    writeAttempts += 1;
    if (failingWrites > 0) {
      failingWrites -= 1;
      throw StateError('simulated write failure');
    }
    _persisted = state;
  }
}

Future<void> _settleProviderLoads() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Account _buildAccount({required String key}) {
  return Account(
    key: key,
    baseUrl: Uri.parse('http://127.0.0.1:5230'),
    personalAccessToken: 'token',
    user: const User(
      name: 'users/1',
      username: 'tester',
      displayName: 'Tester',
      avatarUrl: '',
      description: '',
    ),
    instanceProfile: const InstanceProfile.empty(),
    useLegacyApiOverride: false,
    serverVersionOverride: '0.24.0',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'switchWorkspace retries persisting current workspace after a failed write',
    () async {
      final repository = _FakeAccountsRepository(
        initialState: const AccountsState(accounts: [], currentKey: null),
        failingWrites: 1,
      );
      final container = ProviderContainer(
        overrides: [
          accountsRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(appSessionProvider);
      await _settleProviderLoads();

      final controller = container.read(appSessionProvider.notifier);

      await controller.switchWorkspace('local-workspace');
      expect(
        container.read(appSessionProvider).valueOrNull?.currentKey,
        'local-workspace',
      );
      expect(repository.writeAttempts, 1);
      expect(repository.persisted.currentKey, isNull);

      await controller.switchWorkspace('local-workspace');
      expect(repository.writeAttempts, 2);
      expect(repository.persisted.currentKey, 'local-workspace');
    },
  );

  test(
    'setCurrentKey restores persisted accounts before writing a new key',
    () async {
      final repository = _FakeAccountsRepository(
        initialState: const AccountsState(accounts: [], currentKey: null),
      );
      final container = ProviderContainer(
        overrides: [
          accountsRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(appSessionProvider);
      await _settleProviderLoads();

      final account = _buildAccount(key: 'http://127.0.0.1:5230|users/1');
      repository._persisted = AccountsState(
        accounts: [account],
        currentKey: account.key,
      );

      final controller = container.read(appSessionProvider.notifier);
      await controller.setCurrentKey(account.key);

      final state = container.read(appSessionProvider).valueOrNull;
      expect(state?.accounts, hasLength(1));
      expect(state?.currentAccount?.key, account.key);
      expect(repository.persisted.accounts, hasLength(1));
      expect(repository.persisted.currentKey, account.key);
    },
  );

  test(
    'switchWorkspace preserves persisted accounts when memory is stale',
    () async {
      final repository = _FakeAccountsRepository(
        initialState: const AccountsState(accounts: [], currentKey: null),
      );
      final container = ProviderContainer(
        overrides: [
          accountsRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(appSessionProvider);
      await _settleProviderLoads();

      final account = _buildAccount(key: 'http://127.0.0.1:5230|users/1');
      repository._persisted = AccountsState(
        accounts: [account],
        currentKey: account.key,
      );

      final controller = container.read(appSessionProvider.notifier);
      await controller.switchWorkspace('local-workspace');

      final state = container.read(appSessionProvider).valueOrNull;
      expect(state?.accounts, hasLength(1));
      expect(state?.currentKey, 'local-workspace');
      expect(repository.persisted.accounts, hasLength(1));
      expect(repository.persisted.currentKey, 'local-workspace');
    },
  );

  test('secureStorageProvider defaults to main-app Windows role', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final storage = container.read(secureStorageProvider);

    expect(storage, isA<WindowsLockedQueuedFlutterSecureStorage>());
    expect(
      (storage as WindowsLockedQueuedFlutterSecureStorage).runtimeRole,
      DesktopRuntimeRole.mainApp,
    );
  });

  for (final role in DesktopRuntimeRole.values) {
    test(
      'secureStorageProvider keeps Windows lock wrapper for ${role.name}',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final container = ProviderContainer(
          overrides: [desktopRuntimeRoleProvider.overrideWith((ref) => role)],
        );
        addTearDown(container.dispose);

        final storage = container.read(secureStorageProvider);

        expect(storage, isA<WindowsLockedQueuedFlutterSecureStorage>());
        expect(
          (storage as WindowsLockedQueuedFlutterSecureStorage).runtimeRole,
          role,
        );
      },
    );
  }
}
