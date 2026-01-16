class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.inProgress,
    required this.lastSuccess,
    required this.lastFailure,
    required this.lastError,
  });

  final bool inProgress;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;
  final String? lastError;

  SyncStatusSnapshot copyWith({
    bool? inProgress,
    DateTime? lastSuccess,
    DateTime? lastFailure,
    String? lastError,
  }) {
    return SyncStatusSnapshot(
      inProgress: inProgress ?? this.inProgress,
      lastSuccess: lastSuccess ?? this.lastSuccess,
      lastFailure: lastFailure ?? this.lastFailure,
      lastError: lastError ?? this.lastError,
    );
  }
}

class SyncStatusTracker {
  SyncStatusSnapshot _snapshot = const SyncStatusSnapshot(
    inProgress: false,
    lastSuccess: null,
    lastFailure: null,
    lastError: null,
  );

  SyncStatusSnapshot get snapshot => _snapshot;

  void markSyncStarted() {
    _snapshot = _snapshot.copyWith(inProgress: true);
  }

  void markSyncSuccess() {
    _snapshot = _snapshot.copyWith(
      inProgress: false,
      lastSuccess: DateTime.now(),
      lastError: null,
    );
  }

  void markSyncFailed(Object error) {
    _snapshot = _snapshot.copyWith(
      inProgress: false,
      lastFailure: DateTime.now(),
      lastError: error.toString().trim(),
    );
  }
}
