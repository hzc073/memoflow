import 'sync_error.dart';

sealed class MemoSyncResult {
  const MemoSyncResult();
}

class MemoSyncSuccess extends MemoSyncResult {
  const MemoSyncSuccess();
}

class MemoSyncSkipped extends MemoSyncResult {
  const MemoSyncSkipped({this.reason});

  final SyncError? reason;
}

class MemoSyncFailure extends MemoSyncResult {
  const MemoSyncFailure(this.error);

  final SyncError error;
}

sealed class WebDavSyncResult {
  const WebDavSyncResult();
}

class WebDavSyncSuccess extends WebDavSyncResult {
  const WebDavSyncSuccess();
}

class WebDavSyncSkipped extends WebDavSyncResult {
  const WebDavSyncSkipped({this.reason});

  final SyncError? reason;
}

class WebDavSyncConflict extends WebDavSyncResult {
  const WebDavSyncConflict(this.conflicts);

  final List<String> conflicts;
}

class WebDavSyncFailure extends WebDavSyncResult {
  const WebDavSyncFailure(this.error);

  final SyncError error;
}

sealed class WebDavBackupResult {
  const WebDavBackupResult();
}

class WebDavBackupSuccess extends WebDavBackupResult {
  const WebDavBackupSuccess();
}

class WebDavBackupSkipped extends WebDavBackupResult {
  const WebDavBackupSkipped({this.reason});

  final SyncError? reason;
}

class WebDavBackupMissingPassword extends WebDavBackupResult {
  const WebDavBackupMissingPassword();
}

class WebDavBackupFailure extends WebDavBackupResult {
  const WebDavBackupFailure(this.error);

  final SyncError error;
}

sealed class WebDavRestoreResult {
  const WebDavRestoreResult();
}

class WebDavRestoreSuccess extends WebDavRestoreResult {
  const WebDavRestoreSuccess();
}

class WebDavRestoreSkipped extends WebDavRestoreResult {
  const WebDavRestoreSkipped({this.reason});

  final SyncError? reason;
}

class WebDavRestoreConflict extends WebDavRestoreResult {
  const WebDavRestoreConflict(this.conflicts);

  final List<LocalScanConflict> conflicts;
}

class WebDavRestoreFailure extends WebDavRestoreResult {
  const WebDavRestoreFailure(this.error);

  final SyncError error;
}

class LocalScanConflict {
  const LocalScanConflict({
    required this.memoUid,
    required this.isDeletion,
  });

  final String memoUid;
  final bool isDeletion;
}

sealed class LocalScanResult {
  const LocalScanResult();
}

class LocalScanSuccess extends LocalScanResult {
  const LocalScanSuccess();
}

class LocalScanConflictResult extends LocalScanResult {
  const LocalScanConflictResult(this.conflicts);

  final List<LocalScanConflict> conflicts;
}

class LocalScanFailure extends LocalScanResult {
  const LocalScanFailure(this.error);

  final SyncError error;
}

class SyncFlowStatus {
  const SyncFlowStatus({
    required this.running,
    required this.lastSuccessAt,
    required this.lastError,
    required this.hasPendingConflict,
  });

  final bool running;
  final DateTime? lastSuccessAt;
  final SyncError? lastError;
  final bool hasPendingConflict;

  SyncFlowStatus copyWith({
    bool? running,
    DateTime? lastSuccessAt,
    SyncError? lastError,
    bool? hasPendingConflict,
  }) {
    return SyncFlowStatus(
      running: running ?? this.running,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: lastError,
      hasPendingConflict: hasPendingConflict ?? this.hasPendingConflict,
    );
  }

  static const idle = SyncFlowStatus(
    running: false,
    lastSuccessAt: null,
    lastError: null,
    hasPendingConflict: false,
  );
}

sealed class SyncRunResult {
  const SyncRunResult();
}

class SyncRunStarted extends SyncRunResult {
  const SyncRunStarted();
}

class SyncRunQueued extends SyncRunResult {
  const SyncRunQueued();
}

class SyncRunSkipped extends SyncRunResult {
  const SyncRunSkipped({this.reason});

  final SyncError? reason;
}

class SyncRunFailure extends SyncRunResult {
  const SyncRunFailure(this.error);

  final SyncError error;
}

class SyncRunConflict extends SyncRunResult {
  const SyncRunConflict(this.conflicts);

  final List<String> conflicts;
}
