import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/location_settings.dart';

class LocationSettingsRepository {
  LocationSettingsRepository(this._storage, {required this.accountKey});

  static const _kPrefix = 'location_settings_v1_';

  final FlutterSecureStorage _storage;
  final String accountKey;

  String get _storageKey => '$_kPrefix$accountKey';

  Future<LocationSettings> read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return LocationSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return LocationSettings.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return LocationSettings.defaults;
  }

  Future<void> write(LocationSettings settings) async {
    await _storage.write(key: _storageKey, value: jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }
}
