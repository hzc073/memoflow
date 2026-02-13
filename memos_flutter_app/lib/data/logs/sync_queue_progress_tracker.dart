import 'package:flutter/foundation.dart';

class SyncQueueProgressSnapshot {
  const SyncQueueProgressSnapshot({
    required this.syncing,
    required this.currentOutboxId,
    required this.currentProgress,
  });

  static const idle = SyncQueueProgressSnapshot(
    syncing: false,
    currentOutboxId: null,
    currentProgress: null,
  );

  final bool syncing;
  final int? currentOutboxId;
  final double? currentProgress;
}

class SyncQueueProgressTracker extends ChangeNotifier {
  SyncQueueProgressSnapshot _snapshot = SyncQueueProgressSnapshot.idle;

  SyncQueueProgressSnapshot get snapshot => _snapshot;

  void markSyncStarted() {
    _setSnapshot(
      const SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: null,
        currentProgress: null,
      ),
    );
  }

  void markTaskStarted(int outboxId) {
    _setSnapshot(
      SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: outboxId,
        currentProgress: null,
      ),
    );
  }

  void updateCurrentTaskProgress({
    required int outboxId,
    required int sentBytes,
    required int totalBytes,
  }) {
    if (_snapshot.currentOutboxId != outboxId || totalBytes <= 0) return;
    final rawProgress = sentBytes / totalBytes;
    final progress = rawProgress >= 1.0
        ? 0.99
        : rawProgress.clamp(0.0, 0.99).toDouble();
    _setSnapshot(
      SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: outboxId,
        currentProgress: progress,
      ),
    );
  }

  Future<void> markTaskCompleted({
    required int outboxId,
    Duration hold = const Duration(milliseconds: 120),
  }) async {
    if (_snapshot.currentOutboxId != outboxId) return;
    _setSnapshot(
      SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: outboxId,
        currentProgress: 1.0,
      ),
    );
    if (hold > Duration.zero) {
      await Future<void>.delayed(hold);
    }
  }

  void clearCurrentTask({required int outboxId}) {
    if (_snapshot.currentOutboxId != outboxId) return;
    _setSnapshot(
      const SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: null,
        currentProgress: null,
      ),
    );
  }

  void markSyncFinished() {
    _setSnapshot(SyncQueueProgressSnapshot.idle);
  }

  void _setSnapshot(SyncQueueProgressSnapshot next) {
    final prev = _snapshot;
    final unchanged =
        prev.syncing == next.syncing &&
        prev.currentOutboxId == next.currentOutboxId &&
        prev.currentProgress == next.currentProgress;
    if (unchanged) return;
    _snapshot = next;
    notifyListeners();
  }
}
