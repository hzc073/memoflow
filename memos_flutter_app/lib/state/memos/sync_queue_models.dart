import '../../data/db/app_database.dart';

class SyncQueueOutboxState {
  const SyncQueueOutboxState._();

  static const int pending = AppDatabase.outboxStatePending;
  static const int running = AppDatabase.outboxStateRunning;
  static const int retry = AppDatabase.outboxStateRetry;
  static const int error = AppDatabase.outboxStateError;
}

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.type,
    required this.state,
    required this.attempts,
    required this.createdAt,
    required this.preview,
    required this.filename,
    required this.lastError,
    required this.memoUid,
    required this.attachmentUid,
    required this.retryAt,
  });

  final int id;
  final String type;
  final int state;
  final int attempts;
  final DateTime createdAt;
  final String? preview;
  final String? filename;
  final String? lastError;
  final String? memoUid;
  final String? attachmentUid;
  final DateTime? retryAt;

  bool get isFailed => state == SyncQueueOutboxState.error;
  bool get isRetrying => state == SyncQueueOutboxState.retry;
}