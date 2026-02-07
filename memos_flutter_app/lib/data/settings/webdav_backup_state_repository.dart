import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/webdav_backup_state.dart';

class WebDavBackupStateRepository {
  WebDavBackupStateRepository(this._storage, {required String? accountKey})
    : _accountKey = accountKey;

  static const _kPrefix = 'webdav_backup_state_v1_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<WebDavBackupState> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return WebDavBackupState.empty;
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return WebDavBackupState.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WebDavBackupState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return WebDavBackupState.empty;
  }

  Future<void> write(WebDavBackupState state) async {
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
