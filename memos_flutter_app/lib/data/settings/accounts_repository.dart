import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/url.dart';
import '../models/account.dart';

class AccountsState {
  const AccountsState({required this.accounts, required this.currentKey});

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

  AccountsState copyWith({List<Account>? accounts, String? currentKey}) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      currentKey: currentKey ?? this.currentKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'currentKey': currentKey,
    'accounts': accounts.map((a) => a.toJson()).toList(growable: false),
  };

  factory AccountsState.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    final accounts = <Account>[];
    if (rawAccounts is List) {
      for (final item in rawAccounts) {
        if (item is Map) {
          accounts.add(Account.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return AccountsState(
      accounts: accounts,
      currentKey: json['currentKey'] as String?,
    );
  }
}

class AccountsRepository {
  AccountsRepository(this._storage);

  static const _kStateKey = 'accounts_state_v1';

  final FlutterSecureStorage _storage;

  Future<AccountsState> read() async {
    final raw = await _storage.read(key: _kStateKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AccountsState(accounts: [], currentKey: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AccountsState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return const AccountsState(accounts: [], currentKey: null);
  }

  Future<void> write(AccountsState state) async {
    final sanitizedAccounts = state.accounts
        .map(
          (a) => Account(
            key: a.key,
            baseUrl: sanitizeUserBaseUrl(a.baseUrl),
            personalAccessToken: a.personalAccessToken,
            user: a.user,
            instanceProfile: a.instanceProfile,
            useLegacyApiOverride: a.useLegacyApiOverride,
          ),
        )
        .toList(growable: false);
    final sanitized = state.copyWith(accounts: sanitizedAccounts);
    await _storage.write(
      key: _kStateKey,
      value: jsonEncode(sanitized.toJson()),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _kStateKey);
  }
}
