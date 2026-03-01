import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync/sync_types.dart';

abstract class SyncControllerBase extends StateNotifier<AsyncValue<void>> {
  SyncControllerBase(super.state);

  Future<MemoSyncResult> syncNow();
}
