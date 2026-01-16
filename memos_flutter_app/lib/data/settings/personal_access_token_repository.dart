import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PersonalAccessTokenRepository {
  PersonalAccessTokenRepository(this._storage);

  static const _kPrefix = 'pat_vault_v1|';

  final FlutterSecureStorage _storage;

  String _accountKey(String accountKey) => '$_kPrefix$accountKey';

  Future<Map<String, String>> readAll({required String accountKey}) async {
    final raw = await _storage.read(key: _accountKey(accountKey));
    if (raw == null || raw.trim().isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final out = <String, String>{};
        for (final entry in decoded.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is String && key.trim().isNotEmpty && value.trim().isNotEmpty) {
            out[key] = value;
          }
        }
        return out;
      }
    } catch (_) {}
    return const {};
  }

  Future<String?> readTokenValue({required String accountKey, required String tokenName}) async {
    final map = await readAll(accountKey: accountKey);
    return map[tokenName];
  }

  Future<void> saveTokenValue({
    required String accountKey,
    required String tokenName,
    required String tokenValue,
  }) async {
    final trimmedName = tokenName.trim();
    final trimmedValue = tokenValue.trim();
    if (trimmedName.isEmpty || trimmedValue.isEmpty) return;

    final map = await readAll(accountKey: accountKey);
    final next = {...map, trimmedName: trimmedValue};
    await _storage.write(key: _accountKey(accountKey), value: jsonEncode(next));
  }

  Future<void> deleteForAccount({required String accountKey}) async {
    await _storage.delete(key: _accountKey(accountKey));
  }
}

