import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/api/memos_api.dart';
import '../data/models/account.dart';
import '../data/models/instance_profile.dart';
import '../data/settings/accounts_repository.dart';
import '../core/url.dart';

class AppSessionState {
  const AppSessionState({
    required this.accounts,
    required this.currentKey,
  });

  final List<Account> accounts;
  final String? currentKey;

  Account? get currentAccount {
    final key = currentKey;
    if (key == null) return null;
    for (final a in accounts) {
      if (a.key == key) return a;
    }
    return null;
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(secureStorageProvider));
});

final appSessionProvider = StateNotifierProvider<AppSessionController, AsyncValue<AppSessionState>>((ref) {
  return AppSessionNotifier(ref.watch(accountsRepositoryProvider));
});

abstract class AppSessionController extends StateNotifier<AsyncValue<AppSessionState>> {
  AppSessionController(super.state);

  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
  });

  Future<void> switchAccount(String accountKey);

  Future<void> removeAccount(String accountKey);
}

class AppSessionNotifier extends AppSessionController {
  AppSessionNotifier(this._accountsRepository) : super(const AsyncValue.loading()) {
    _loadFromStorage();
  }

  final AccountsRepository _accountsRepository;

  Future<void> _loadFromStorage() async {
    final stored = await _accountsRepository.read();
    state = AsyncValue.data(AppSessionState(accounts: stored.accounts, currentKey: stored.currentKey));
  }

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
  }) async {
    // Keep the previous state while connecting so the login form doesn't reset.
    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      InstanceProfile instanceProfile;
      try {
        instanceProfile = await MemosApi.unauthenticated(baseUrl).getInstanceProfile();
      } catch (_) {
        instanceProfile = const InstanceProfile.empty();
      }

      final user = await MemosApi.authenticated(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
      ).getCurrentUser();

      final normalizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
      final accountKey = '${canonicalBaseUrlString(normalizedBaseUrl)}|${user.name}';

      final current = state.valueOrNull ?? const AppSessionState(accounts: [], currentKey: null);
      final accounts = [...current.accounts];
      final account = Account(
        key: accountKey,
        baseUrl: normalizedBaseUrl,
        personalAccessToken: personalAccessToken,
        user: user,
        instanceProfile: instanceProfile,
      );
      final existingIndex = accounts.indexWhere((a) => a.key == accountKey);
      if (existingIndex >= 0) {
        accounts[existingIndex] = account;
      } else {
        accounts.add(account);
      }

      await _accountsRepository.write(AccountsState(accounts: accounts, currentKey: accountKey));
      return AppSessionState(accounts: accounts, currentKey: accountKey);
    });
  }

  @override
  Future<void> switchAccount(String accountKey) async {
    final current = state.valueOrNull ?? const AppSessionState(accounts: [], currentKey: null);
    if (!current.accounts.any((a) => a.key == accountKey)) return;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(AccountsState(accounts: current.accounts, currentKey: accountKey));
      return AppSessionState(accounts: current.accounts, currentKey: accountKey);
    });
  }

  @override
  Future<void> removeAccount(String accountKey) async {
    final current = state.valueOrNull ?? const AppSessionState(accounts: [], currentKey: null);
    final accounts = current.accounts.where((a) => a.key != accountKey).toList(growable: false);
    final nextKey = current.currentKey == accountKey ? (accounts.firstOrNull?.key) : current.currentKey;

    state = const AsyncValue<AppSessionState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _accountsRepository.write(AccountsState(accounts: accounts, currentKey: nextKey));
      return AppSessionState(accounts: accounts, currentKey: nextKey);
    });
  }
}

extension _FirstOrNullAccountExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
