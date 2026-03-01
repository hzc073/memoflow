enum SyncRequestKind {
  memos,
  webDavSync,
  webDavBackup,
  localScan,
  all,
}

enum SyncRequestReason {
  manual,
  launch,
  resume,
  settings,
  auto,
}

class SyncRequest {
  const SyncRequest({
    required this.kind,
    required this.reason,
    this.refreshCurrentUserBeforeSync = false,
    this.showFeedbackToast = false,
    this.forceWidgetUpdate = false,
  });

  final SyncRequestKind kind;
  final SyncRequestReason reason;
  final bool refreshCurrentUserBeforeSync;
  final bool showFeedbackToast;
  final bool forceWidgetUpdate;
}
