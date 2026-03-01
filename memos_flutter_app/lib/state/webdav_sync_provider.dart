import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/webdav_device_id_repository.dart';
import '../data/settings/webdav_sync_state_repository.dart';
import 'session_provider.dart';

final webDavSyncStateRepositoryProvider = Provider<WebDavSyncStateRepository>((
  ref,
) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return WebDavSyncStateRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final webDavDeviceIdRepositoryProvider = Provider<WebDavDeviceIdRepository>((
  ref,
) {
  return WebDavDeviceIdRepository(ref.watch(secureStorageProvider));
});
