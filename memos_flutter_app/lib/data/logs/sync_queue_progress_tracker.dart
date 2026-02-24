import 'package:flutter/foundation.dart';

class SyncQueueProgressSnapshot {
  const SyncQueueProgressSnapshot({
    required this.syncing,
    required this.currentOutboxId,
    required this.currentProgress,
    required this.totalTasks,
    required this.completedTasks,
  });

  static const idle = SyncQueueProgressSnapshot(
    syncing: false,
    currentOutboxId: null,
    currentProgress: null,
    totalTasks: 0,
    completedTasks: 0,
  );

  final bool syncing;
  final int? currentOutboxId;
  final double? currentProgress;
  final int totalTasks;
  final int completedTasks;

  double? get overallProgress {
    if (!syncing) return null;
    if (totalTasks <= 0) return null;
    final safeTotal = totalTasks <= 0 ? 1 : totalTasks;
    final safeCompleted = completedTasks < 0
        ? 0
        : (completedTasks > safeTotal ? safeTotal : completedTasks);
    final current = currentProgress == null
        ? 0.0
        : currentProgress!.clamp(0.0, 0.99).toDouble();
    return ((safeCompleted + current) / safeTotal).clamp(0.0, 1.0).toDouble();
  }
}

class SyncQueueProgressTracker extends ChangeNotifier {
  SyncQueueProgressSnapshot _snapshot = SyncQueueProgressSnapshot.idle;

  SyncQueueProgressSnapshot get snapshot => _snapshot;

  void markSyncStarted({required int totalTasks, int completedTasks = 0}) {
    final safeTotal = totalTasks < 0 ? 0 : totalTasks;
    final safeCompleted = completedTasks < 0 ? 0 : completedTasks;
    _setSnapshot(
      SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: _snapshot.currentOutboxId,
        currentProgress: _snapshot.currentProgress,
        totalTasks: safeTotal,
        completedTasks: safeCompleted > safeTotal ? safeTotal : safeCompleted,
      ),
    );
  }

  void markTaskStarted(int outboxId) {
    _setSnapshot(
      SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: outboxId,
        currentProgress: null,
        totalTasks: _snapshot.totalTasks,
        completedTasks: _snapshot.completedTasks,
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
        totalTasks: _snapshot.totalTasks,
        completedTasks: _snapshot.completedTasks,
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
        totalTasks: _snapshot.totalTasks,
        completedTasks: _snapshot.completedTasks,
      ),
    );
    if (hold > Duration.zero) {
      await Future<void>.delayed(hold);
    }
  }

  void clearCurrentTask({required int outboxId}) {
    if (_snapshot.currentOutboxId != outboxId) return;
    _setSnapshot(
      SyncQueueProgressSnapshot(
        syncing: true,
        currentOutboxId: null,
        currentProgress: null,
        totalTasks: _snapshot.totalTasks,
        completedTasks: _snapshot.completedTasks,
      ),
    );
  }

  void updateCompletedTasks(int completedTasks) {
    final safeCompleted = completedTasks < 0 ? 0 : completedTasks;
    final safeTotal = _snapshot.totalTasks < safeCompleted
        ? safeCompleted
        : _snapshot.totalTasks;
    _setSnapshot(
      SyncQueueProgressSnapshot(
        syncing: _snapshot.syncing,
        currentOutboxId: _snapshot.currentOutboxId,
        currentProgress: _snapshot.currentProgress,
        totalTasks: safeTotal,
        completedTasks: safeCompleted,
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
        prev.currentProgress == next.currentProgress &&
        prev.totalTasks == next.totalTasks &&
        prev.completedTasks == next.completedTasks;
    if (unchanged) return;
    _snapshot = next;
    notifyListeners();
  }
}
