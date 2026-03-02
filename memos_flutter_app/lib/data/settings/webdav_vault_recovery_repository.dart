import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebDavVaultRecoveryRepository {
  WebDavVaultRecoveryRepository(this._storage, {required String? accountKey})
      : _accountKey = accountKey;

  static const _kPrefix = 'webdav_vault_recovery_v1_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<String?> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return null;
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  Future<void> write(String recoveryCode) async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.write(key: storageKey, value: recoveryCode);
  }

  Future<void> clear() async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.delete(key: storageKey);
  }
}
