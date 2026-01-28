import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/uid.dart';

class WebDavDeviceIdRepository {
  WebDavDeviceIdRepository(this._storage);

  static const _kKey = 'webdav_device_id_v1';

  final FlutterSecureStorage _storage;

  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: _kKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final id = 'device_${generateUid(length: 24)}';
    await _storage.write(key: _kKey, value: id);
    return id;
  }
}
