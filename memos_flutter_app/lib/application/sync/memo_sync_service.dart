import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/local_sync_controller.dart';
import '../../state/memos_providers.dart'
    show RemoteSyncController, syncControllerProvider;

/// Application-facing memo sync runners.
typedef LocalMemoSyncRunner = LocalSyncController;
typedef RemoteMemoSyncRunner = RemoteSyncController;

class MemoBridgeService {
  MemoBridgeService(this._controller);

  final LocalSyncController _controller;

  Future<BridgeBulkPushResult> pushAllMemosToBridge({
    bool includeArchived = true,
  }) {
    return _controller.pushAllMemosToBridge(includeArchived: includeArchived);
  }
}

final memoBridgeServiceProvider = Provider<MemoBridgeService?>((ref) {
  final controller = ref.read(syncControllerProvider.notifier);
  if (controller is LocalSyncController) {
    return MemoBridgeService(controller);
  }
  return null;
});
