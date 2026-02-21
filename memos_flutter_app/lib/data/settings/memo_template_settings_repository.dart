import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/memo_template_settings.dart';

class MemoTemplateSettingsRepository {
  MemoTemplateSettingsRepository(this._storage, {required this.accountKey});

  static const _kPrefix = 'memo_template_settings_v1_';

  final FlutterSecureStorage _storage;
  final String accountKey;

  String get _storageKey => '$_kPrefix$accountKey';

  Future<MemoTemplateSettings> read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return MemoTemplateSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return MemoTemplateSettings.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return MemoTemplateSettings.defaults;
  }

  Future<void> write(MemoTemplateSettings settings) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(settings.toJson()),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }
}
