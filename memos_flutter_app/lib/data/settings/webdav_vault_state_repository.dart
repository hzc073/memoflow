import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebDavVaultState {
  const WebDavVaultState({required this.recoveryVerified});

  final bool recoveryVerified;

  static const defaults = WebDavVaultState(recoveryVerified: false);

  Map<String, dynamic> toJson() => {
        'recoveryVerified': recoveryVerified,
      };

  factory WebDavVaultState.fromJson(Map<String, dynamic> json) {
    final raw = json['recoveryVerified'];
    final verified = raw is bool ? raw : raw is num ? raw != 0 : false;
    return WebDavVaultState(recoveryVerified: verified);
  }
}

class WebDavVaultStateRepository {
  WebDavVaultStateRepository(this._storage, {required String? accountKey})
      : _accountKey = accountKey;

  static const _kPrefix = 'webdav_vault_state_v1_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<WebDavVaultState> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return WebDavVaultState.defaults;
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return WebDavVaultState.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WebDavVaultState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return WebDavVaultState.defaults;
  }

  Future<void> write(WebDavVaultState state) async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.write(key: storageKey, value: jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.delete(key: storageKey);
  }
}
