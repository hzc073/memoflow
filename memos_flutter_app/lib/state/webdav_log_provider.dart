import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/logs/debug_log_store.dart';

final webDavLogStoreProvider = Provider<DebugLogStore>((ref) {
  final store = DebugLogStore(
    maxEntries: 1000,
    maxFileBytes: 2 * 1024 * 1024,
    fileName: 'webdav_logs.jsonl',
    enabled: true,
  );
  return store;
});
