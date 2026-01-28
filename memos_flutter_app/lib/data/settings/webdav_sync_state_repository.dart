import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/webdav_sync_state.dart';

class WebDavSyncStateRepository {
  WebDavSyncStateRepository(this._storage, {required String? accountKey}) : _accountKey = accountKey;

  static const _kPrefix = 'webdav_sync_state_v1_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<WebDavSyncState> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return WebDavSyncState.empty;
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return WebDavSyncState.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WebDavSyncState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return WebDavSyncState.empty;
  }

  Future<void> write(WebDavSyncState state) async {
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
