import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/webdav_sync_state_repository.dart';
import 'session_provider.dart';
import 'webdav_device_id_provider.dart';

final webDavSyncStateRepositoryProvider = Provider<WebDavSyncStateRepository>((
  ref,
) {
  final accountKey = ref.watch(webDavAccountKeyProvider);
  return WebDavSyncStateRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});
