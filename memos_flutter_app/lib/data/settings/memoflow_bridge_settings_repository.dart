import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/memoflow_bridge_settings.dart';

class MemoFlowBridgeSettingsRepository {
  MemoFlowBridgeSettingsRepository(this._storage, {required String? accountKey})
    : _accountKey = accountKey;

  static const _kPrefix = 'memoflow_bridge_settings_v1_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<MemoFlowBridgeSettings> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return MemoFlowBridgeSettings.defaults;
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return MemoFlowBridgeSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return MemoFlowBridgeSettings.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return MemoFlowBridgeSettings.defaults;
  }

  Future<void> write(MemoFlowBridgeSettings settings) async {
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
