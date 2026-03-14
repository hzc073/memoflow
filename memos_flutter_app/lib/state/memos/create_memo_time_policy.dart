import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';

DateTime? resolveCreateMemoFollowUpDisplayTime({
  required bool supportsCreateMemoTimestampsInCreateBody,
  required DateTime? createTime,
  required DateTime? displayTime,
}) {
  if (supportsCreateMemoTimestampsInCreateBody) {
    return null;
  }
  return (displayTime ?? createTime)?.toUtc();
}

bool shouldPreserveLocalCreateTime({
  required LocalMemo? localMemo,
  required int localSyncState,
  required Memo remoteMemo,
}) {
  if (localMemo == null || localSyncState != 0) {
    return false;
  }
  if (remoteMemo.displayTime != null) {
    return false;
  }
  if (localMemo.uid.trim() != remoteMemo.uid.trim()) {
    return false;
  }
  if (localMemo.contentFingerprint != remoteMemo.contentFingerprint) {
    return false;
  }
  if (localMemo.visibility != remoteMemo.visibility ||
      localMemo.pinned != remoteMemo.pinned ||
      localMemo.state != remoteMemo.state) {
    return false;
  }

  final localCreateMs = localMemo.createTime.toUtc().millisecondsSinceEpoch;
  final remoteCreateMs = remoteMemo.createTime.toUtc().millisecondsSinceEpoch;
  if (localCreateMs <= 0 || remoteCreateMs <= 0) {
    return false;
  }
  return localCreateMs != remoteCreateMs;
}
