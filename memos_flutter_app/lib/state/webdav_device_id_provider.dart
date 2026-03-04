import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/webdav_device_id_repository.dart';
import 'session_provider.dart';

final webDavDeviceIdRepositoryProvider = Provider<WebDavDeviceIdRepository>((
  ref,
) {
  return WebDavDeviceIdRepository(ref.watch(secureStorageProvider));
});

final webDavDeviceIdProvider =
    StateNotifierProvider<_WebDavDeviceIdController, String?>((ref) {
      return _WebDavDeviceIdController(
        ref.watch(webDavDeviceIdRepositoryProvider),
      );
    });

final webDavAccountKeyProvider = Provider<String?>((ref) {
  final key =
      ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  if (key != null && key.trim().isNotEmpty) {
    return key.trim();
  }
  final deviceId = ref.watch(webDavDeviceIdProvider);
  if (deviceId == null || deviceId.trim().isEmpty) return null;
  return deviceId.trim();
});

class _WebDavDeviceIdController extends StateNotifier<String?> {
  _WebDavDeviceIdController(this._repo) : super(null) {
    unawaited(_load());
  }

  final WebDavDeviceIdRepository _repo;

  Future<void> _load() async {
    final id = await _repo.readOrCreate();
    if (!mounted) return;
    state = id;
  }
}
