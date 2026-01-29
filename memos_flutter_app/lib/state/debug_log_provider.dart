import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/logs/debug_log_store.dart';

final debugLogStoreProvider = Provider<DebugLogStore>((ref) {
  return DebugLogStore();
});
