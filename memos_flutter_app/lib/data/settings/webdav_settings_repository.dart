import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/webdav_settings.dart';

class WebDavSettingsRepository {
  WebDavSettingsRepository(this._storage, {required String? accountKey}) : _accountKey = accountKey;

  static const _kPrefix = 'webdav_settings_v1_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<WebDavSettings> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return WebDavSettings.defaults;
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return WebDavSettings.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WebDavSettings.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return WebDavSettings.defaults;
  }

  Future<void> write(WebDavSettings settings) async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.write(key: storageKey, value: jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.delete(key: storageKey);
  }
}
