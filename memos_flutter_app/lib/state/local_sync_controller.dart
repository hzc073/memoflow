import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_stream/saf_stream.dart';

import '../core/app_localization.dart';
import '../data/db/app_database.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/local_library/local_library_fs.dart';
import '../data/local_library/local_library_markdown.dart';
import '../data/local_library/local_library_naming.dart';
import '../data/logs/log_manager.dart';
import '../data/logs/sync_queue_progress_tracker.dart';
import '../data/models/attachment.dart';
import '../data/models/local_memo.dart';
import '../data/models/memoflow_bridge_settings.dart';
import '../data/settings/memoflow_bridge_settings_repository.dart';
import '../data/logs/sync_status_tracker.dart';
import 'local_library_scanner.dart';
import 'preferences_provider.dart';
import 'sync_controller_base.dart';

class BridgeBulkPushResult {
  const BridgeBulkPushResult({
    required this.total,
    required this.succeeded,
    required this.failed,
  });

  final int total;
  final int succeeded;
  final int failed;
}

class LocalSyncController extends SyncControllerBase {
  static const int _bulkOutboxTaskLogHeadCount = 3;
  static const int _bulkOutboxTaskLogEvery = 250;
  static const int _outboxProgressLogEvery = 200;
  static const int _attachmentOutboxConcurrency = 3;
  static const int _attachmentOutboxBatchScanLimit = 400;
  static const Duration _slowOutboxTaskThreshold = Duration(seconds: 2);
  static const List<Duration> _retryBackoffSteps = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 40),
  ];

  LocalSyncController({
    required this.db,
    required this.fileSystem,
    required this.attachmentStore,
    required this.bridgeSettingsRepository,
    required this.syncStatusTracker,
    required this.syncQueueProgressTracker,
    required this.language,
  }) : super(const AsyncValue.data(null));

  final AppDatabase db;
  final LocalLibraryFileSystem fileSystem;
  final LocalAttachmentStore attachmentStore;
  final MemoFlowBridgeSettingsRepository bridgeSettingsRepository;
  final SyncStatusTracker syncStatusTracker;
  final SyncQueueProgressTracker syncQueueProgressTracker;
  final AppLanguage language;
  MemoFlowBridgeSettings _bridgeSettingsSnapshot =
      MemoFlowBridgeSettings.defaults;
  Timer? _retrySyncTimer;
  int _retryBackoffIndex = 0;
  int _syncRunSeq = 0;
  bool _rerunRequestedWhileLoading = false;
  bool _pendingScanRequested = false;
  bool _isDisposed = false;

  Future<BridgeBulkPushResult> pushAllMemosToBridge({
    bool includeArchived = true,
  }) async {
    final settings = await bridgeSettingsRepository.read();
    if (!settings.enabled) {
      throw StateError('MemoFlow Bridge is disabled');
    }
    if (!settings.isPaired) {
      throw StateError('MemoFlow Bridge is not paired');
    }

    final rows = await db.listMemosForExport(includeArchived: includeArchived);
    final memos = rows
        .map(LocalMemo.fromDb)
        .where((memo) => memo.uid.trim().isNotEmpty)
        .toList(growable: false);

    var succeeded = 0;
    var failed = 0;
    for (final memo in memos) {
      try {
        await _syncMemoToBridge(memo, settings: settings);
        succeeded += 1;
      } catch (_) {
        failed += 1;
      }
    }
    return BridgeBulkPushResult(
      total: memos.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  @override
  Future<void> syncNow() async {
    if (_isDisposed) return;
    final queueSnapshot = syncQueueProgressTracker.snapshot;
    final globalSyncing = queueSnapshot.syncing;
    if (state.isLoading || globalSyncing) {
      _pendingScanRequested = true;
      _rerunRequestedWhileLoading = true;
      LogManager.instance.debug(
        'LocalSync: sync_skipped_loading',
        context: <String, Object?>{
          'rerunRequested': true,
          'pendingScanRequested': true,
          'stateLoading': state.isLoading,
          'globalSyncing': globalSyncing,
          'currentOutboxId': queueSnapshot.currentOutboxId,
          'queueTotalTasks': queueSnapshot.totalTasks,
          'queueCompletedTasks': queueSnapshot.completedTasks,
        },
      );
      return;
    }
    final runId =
        'run_${DateTime.now().toUtc().millisecondsSinceEpoch}_${++_syncRunSeq}';
    final runWatch = Stopwatch()..start();
    _cancelRetrySyncTimer();
    _rerunRequestedWhileLoading = false;
    _pendingScanRequested = false;
    final totalPendingAtStart = await db.countOutboxPending();
    final retryableAtStart = await db.countOutboxRetryable();
    final failedAtStart = await db.countOutboxFailed();
    LogManager.instance.info(
      'LocalSync: sync_start',
      context: <String, Object?>{
        'runId': runId,
        'pendingAtStart': totalPendingAtStart,
        'retryableAtStart': retryableAtStart,
        'failedAtStart': failedAtStart,
        'retryBackoffIndex': _retryBackoffIndex,
        'retryTimerActive': _retrySyncTimer?.isActive ?? false,
      },
    );
    syncStatusTracker.markSyncStarted();
    await db.recoverOutboxRunningTasks();
    syncQueueProgressTracker.markSyncStarted(totalTasks: totalPendingAtStart);
    state = const AsyncValue.loading();
    final next = await AsyncValue.guard(() async {
      _bridgeSettingsSnapshot = await bridgeSettingsRepository.read();
      await fileSystem.ensureStructure();
      await _runSyncStage(
        runId: runId,
        stage: 'scan_pre_push',
        action: () => _scanIncremental(stage: 'pre_push'),
      );
      await _runSyncStage(
        runId: runId,
        stage: 'push_outbox',
        action: _processOutbox,
      );
      await _runSyncStage(
        runId: runId,
        stage: 'scan_reconcile',
        action: () => _scanIncremental(stage: 'pull_reconcile'),
      );
      await _runSyncStage(
        runId: runId,
        stage: 'write_index',
        action: _ensureIndex,
      );
    });
    state = next;
    runWatch.stop();
    final pendingAtEnd = await db.countOutboxPending();
    final retryableAtEnd = await db.countOutboxRetryable();
    final failedAtEnd = await db.countOutboxFailed();
    if (next.hasError) {
      syncStatusTracker.markSyncFailed(next.error!);
      LogManager.instance.warn(
        'LocalSync: sync_failed',
        error: next.error,
        stackTrace: next.stackTrace,
        context: <String, Object?>{
          'runId': runId,
          'elapsedMs': runWatch.elapsedMilliseconds,
          'pendingAtEnd': pendingAtEnd,
          'retryableAtEnd': retryableAtEnd,
          'failedAtEnd': failedAtEnd,
        },
      );
    } else {
      syncStatusTracker.markSyncSuccess();
      LogManager.instance.info(
        'LocalSync: sync_success',
        context: <String, Object?>{
          'runId': runId,
          'elapsedMs': runWatch.elapsedMilliseconds,
          'pendingAtEnd': pendingAtEnd,
          'retryableAtEnd': retryableAtEnd,
          'failedAtEnd': failedAtEnd,
        },
      );
    }
    syncQueueProgressTracker.markSyncFinished();

    if (!_isDisposed) {
      final hasRetryableOutbox = retryableAtEnd > 0;
      final syncFailed = next.hasError;
      if (!hasRetryableOutbox && !syncFailed) {
        _resetRetryState();
      } else {
        await _scheduleRetrySyncIfNeeded(
          hasPendingOutbox: hasRetryableOutbox,
          syncFailed: syncFailed,
        );
      }
    }

    if ((_pendingScanRequested || _rerunRequestedWhileLoading) &&
        !_isDisposed) {
      LogManager.instance.info(
        'LocalSync: rerun_requested_after_completion',
        context: <String, Object?>{
          'runId': runId,
          'pendingScanRequested': _pendingScanRequested,
          'rerunRequestedWhileLoading': _rerunRequestedWhileLoading,
        },
      );
      _pendingScanRequested = false;
      _rerunRequestedWhileLoading = false;
      unawaited(syncNow());
    }
  }

  Future<void> _ensureIndex() async {
    final content = _buildIndexContent();
    await fileSystem.writeIndex(content);
  }

  String _buildIndexContent() {
    final now = DateTime.now().toIso8601String();
    return ['# MemoFlow Local Library', '', '- Updated: $now', ''].join('\n');
  }

  Future<void> _scanIncremental({required String stage}) async {
    final scanner = LocalLibraryScanner(
      db: db,
      fileSystem: fileSystem,
      attachmentStore: attachmentStore,
      language: language,
    );
    LogManager.instance.debug(
      'LocalSync scan: start',
      context: <String, Object?>{'stage': stage},
    );
    await scanner.scanAndMergeIncremental(forceDisk: false);
    LogManager.instance.debug(
      'LocalSync scan: completed',
      context: <String, Object?>{'stage': stage},
    );
  }

  Future<void> _runSyncStage({
    required String runId,
    required String stage,
    required Future<void> Function() action,
  }) async {
    final watch = Stopwatch()..start();
    LogManager.instance.debug(
      'LocalSync: stage_start',
      context: <String, Object?>{'runId': runId, 'stage': stage},
    );
    try {
      await action();
      watch.stop();
      LogManager.instance.debug(
        'LocalSync: stage_done',
        context: <String, Object?>{
          'runId': runId,
          'stage': stage,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
    } catch (error, stackTrace) {
      watch.stop();
      LogManager.instance.warn(
        'LocalSync: stage_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'runId': runId,
          'stage': stage,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  Future<void> _processOutbox() async {
    final startedAt = DateTime.now();
    final pendingAtStart = await db.countOutboxPending();
    LogManager.instance.info(
      'LocalSync outbox: start',
      context: <String, Object?>{'pendingAtStart': pendingAtStart},
    );
    final counters = _OutboxCounters();
    String? stoppedOnType;
    String? blockedReason;
    while (true) {
      final headItems = await db.listOutboxPending(limit: 1);
      if (headItems.isEmpty) {
        LogManager.instance.info(
          'LocalSync outbox: summary',
          context: <String, Object?>{
            'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
            'pendingAtStart': pendingAtStart,
            'processed': counters.processedCount,
            'succeeded': counters.successCount,
            'failed': counters.failedCount,
            'blocked': false,
            if (stoppedOnType != null) 'stoppedOnType': stoppedOnType,
            if (counters.typeCounts.isNotEmpty)
              'typeCounts': counters.typeCounts,
          },
        );
        return;
      }

      final head = headItems.first;
      final headId = head['id'] as int?;
      final headType = head['type'] as String?;
      final headState =
          (head['state'] as int?) ?? AppDatabase.outboxStatePending;
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final retryAtRaw = head['retry_at'];
      final retryAtMs = switch (retryAtRaw) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v.trim()),
        _ => null,
      };
      if (headId == null || headType == null) {
        continue;
      }
      if (headState == AppDatabase.outboxStateError) {
        stoppedOnType = headType;
        blockedReason = 'error_head';
        break;
      }
      if (headState == AppDatabase.outboxStateRetry &&
          retryAtMs != null &&
          retryAtMs > nowMs) {
        stoppedOnType = headType;
        blockedReason = 'retry_waiting';
        break;
      }
      if (headState == AppDatabase.outboxStateRunning) {
        await db.recoverOutboxRunningTasks();
        continue;
      }

      if (_isAttachmentOutboxType(headType)) {
        final batchResult = await _processAttachmentOutboxBatch(
          nowMs: nowMs,
          counters: counters,
        );
        if (batchResult.started) {
          if (batchResult.shouldStop) {
            stoppedOnType = batchResult.stoppedOnType ?? headType;
            blockedReason = batchResult.blockedReason;
            break;
          }
          continue;
        }
      }

      final row = await db.claimOutboxTaskById(headId, nowMs: nowMs);
      if (row == null) continue;

      final taskResult = await _runClaimedOutboxTask(
        row: row,
        counters: counters,
      );
      if (taskResult.shouldStop) {
        stoppedOnType = taskResult.stoppedOnType;
        blockedReason = taskResult.blockedReason;
        break;
      }
    }

    LogManager.instance.info(
      'LocalSync outbox: summary',
      context: <String, Object?>{
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'pendingAtStart': pendingAtStart,
        'processed': counters.processedCount,
        'succeeded': counters.successCount,
        'failed': counters.failedCount,
        'blocked': true,
        if (blockedReason != null) 'blockedReason': blockedReason,
        if (stoppedOnType != null) 'stoppedOnType': stoppedOnType,
        if (counters.typeCounts.isNotEmpty) 'typeCounts': counters.typeCounts,
      },
    );
  }

  Future<_AttachmentOutboxBatchResult> _processAttachmentOutboxBatch({
    required int nowMs,
    required _OutboxCounters counters,
  }) async {
    final rows = await db.listOutboxPending(
      limit: _attachmentOutboxBatchScanLimit,
    );
    if (rows.isEmpty) {
      return _AttachmentOutboxBatchResult.notStarted();
    }

    final candidates = <_AttachmentOutboxCandidate>[];
    for (final row in rows) {
      final id = row['id'] as int?;
      final type = row['type'] as String?;
      final state = (row['state'] as int?) ?? AppDatabase.outboxStatePending;
      final retryAtMs = _parseRetryAtMs(row['retry_at']);
      if (id == null || type == null) {
        if (candidates.isNotEmpty) break;
        continue;
      }

      final isAttachmentType = _isAttachmentOutboxType(type);
      if (state == AppDatabase.outboxStateRunning) {
        if (candidates.isEmpty) {
          await db.recoverOutboxRunningTasks();
        }
        break;
      }
      if (state == AppDatabase.outboxStateError) {
        break;
      }
      if (state == AppDatabase.outboxStateRetry &&
          retryAtMs != null &&
          retryAtMs > nowMs) {
        break;
      }
      final isRunnableNow =
          state == AppDatabase.outboxStatePending ||
          state == AppDatabase.outboxStateRetry;
      if (!isRunnableNow) {
        if (candidates.isNotEmpty) break;
        continue;
      }

      if (candidates.isEmpty) {
        if (!isAttachmentType) {
          return _AttachmentOutboxBatchResult.notStarted();
        }
      } else if (!isAttachmentType) {
        break;
      }

      candidates.add(
        _AttachmentOutboxCandidate(
          id: id,
          memoUid: _extractMemoUidFromPayloadRaw(type, row['payload']),
        ),
      );
    }

    if (candidates.isEmpty) {
      return _AttachmentOutboxBatchResult.notStarted();
    }

    final groupsByMemoKey = <String, List<_AttachmentOutboxCandidate>>{};
    final groupOrder = <String>[];
    for (final candidate in candidates) {
      final rawMemoUid = candidate.memoUid?.trim() ?? '';
      final memoKey = rawMemoUid.isEmpty
          ? '__outbox_attachment_${candidate.id}'
          : rawMemoUid;
      final bucket = groupsByMemoKey.putIfAbsent(memoKey, () {
        groupOrder.add(memoKey);
        return <_AttachmentOutboxCandidate>[];
      });
      bucket.add(candidate);
    }
    final groups = groupOrder
        .map(
          (key) => groupsByMemoKey[key] ?? const <_AttachmentOutboxCandidate>[],
        )
        .where((group) => group.isNotEmpty)
        .toList(growable: false);
    if (groups.isEmpty) {
      return _AttachmentOutboxBatchResult.notStarted();
    }

    LogManager.instance.info(
      'LocalSync outbox: attachment_batch_start',
      context: <String, Object?>{
        'candidateCount': candidates.length,
        'groupCount': groups.length,
        'concurrency': _attachmentOutboxConcurrency,
      },
    );

    var blockedReason = null as String?;
    var stoppedOnType = null as String?;
    var groupsProcessed = 0;
    for (
      var index = 0;
      index < groups.length;
      index += _attachmentOutboxConcurrency
    ) {
      final end = index + _attachmentOutboxConcurrency < groups.length
          ? index + _attachmentOutboxConcurrency
          : groups.length;
      final chunk = groups.sublist(index, end);
      final results = await Future.wait(
        chunk.map(
          (group) =>
              _processAttachmentOutboxGroup(group: group, counters: counters),
        ),
      );
      groupsProcessed += chunk.length;
      for (final result in results) {
        if (result.shouldStop) {
          blockedReason ??= result.blockedReason;
          stoppedOnType ??= result.stoppedOnType;
        }
      }
      if (blockedReason != null) {
        break;
      }
    }

    LogManager.instance.info(
      'LocalSync outbox: attachment_batch_done',
      context: <String, Object?>{
        'candidateCount': candidates.length,
        'groupCount': groups.length,
        'groupsProcessed': groupsProcessed,
        if (blockedReason != null) 'blockedReason': blockedReason,
        if (stoppedOnType != null) 'stoppedOnType': stoppedOnType,
      },
    );

    return _AttachmentOutboxBatchResult(
      started: true,
      shouldStop: blockedReason != null,
      blockedReason: blockedReason,
      stoppedOnType: stoppedOnType,
    );
  }

  Future<_OutboxTaskRunResult> _processAttachmentOutboxGroup({
    required List<_AttachmentOutboxCandidate> group,
    required _OutboxCounters counters,
  }) async {
    for (final candidate in group) {
      final claimed = await db.claimOutboxTaskById(
        candidate.id,
        nowMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      if (claimed == null) {
        continue;
      }
      final result = await _runClaimedOutboxTask(
        row: claimed,
        counters: counters,
      );
      if (result.shouldStop) {
        return result;
      }
    }
    return _OutboxTaskRunResult.continueRun();
  }

  Future<_OutboxTaskRunResult> _runClaimedOutboxTask({
    required Map<String, dynamic> row,
    required _OutboxCounters counters,
  }) async {
    final id = row['id'] as int?;
    final type = row['type'] as String?;
    final payloadRaw = row['payload'] as String?;
    final attemptsSoFar = (row['attempts'] as int?) ?? 0;
    if (id == null || type == null || payloadRaw == null) {
      return _OutboxTaskRunResult.continueRun();
    }

    final processedOrdinal = counters.markTaskSeen(type);
    Map<String, dynamic> payload;
    try {
      payload = (jsonDecode(payloadRaw) as Map).cast<String, dynamic>();
    } catch (error) {
      await db.markOutboxError(id, error: 'Invalid payload: $error');
      counters.markFailure();
      LogManager.instance.warn(
        'LocalSync outbox: invalid_payload',
        error: error,
        context: <String, Object?>{'id': id, 'type': type},
      );
      _reportOutboxTaskProgress(counters: counters, currentType: type);
      return _OutboxTaskRunResult.stop(
        blockedReason: 'invalid_payload',
        stoppedOnType: type,
      );
    }

    final memoUid = _outboxMemoUid(type, payload);
    final shouldLogTaskDetail = _shouldLogOutboxTaskDetail(
      type: type,
      processedCount: processedOrdinal,
    );
    if (shouldLogTaskDetail) {
      LogManager.instance.debug(
        'LocalSync outbox: task_start',
        context: <String, Object?>{
          'id': id,
          'type': type,
          if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
        },
      );
    }

    var shouldStop = false;
    var blockedReason = null as String?;
    final isUploadTask = type == 'upload_attachment';
    final taskStartAt = DateTime.now();
    syncQueueProgressTracker.markTaskStarted(id);
    try {
      switch (type) {
        case 'create_memo':
          final memo = await _handleUpsertMemo(payload);
          final hasAttachments = payload['has_attachments'] as bool? ?? false;
          if (!hasAttachments && memo != null && memo.uid.isNotEmpty) {
            await db.updateMemoSyncState(memo.uid, syncState: 0);
            await _syncMemoToBridgeIfEnabled(memo);
          }
          await db.markOutboxDone(id);
          await db.deleteOutbox(id);
          break;
        case 'update_memo':
          final memo = await _handleUpsertMemo(payload);
          final hasPendingAttachments =
              payload['has_pending_attachments'] as bool? ?? false;
          if (!hasPendingAttachments && memo != null && memo.uid.isNotEmpty) {
            await db.updateMemoSyncState(memo.uid, syncState: 0);
            await _syncMemoToBridgeIfEnabled(memo);
          }
          await db.markOutboxDone(id);
          await db.deleteOutbox(id);
          break;
        case 'delete_memo':
          await _handleDeleteMemo(payload);
          await db.markOutboxDone(id);
          await db.deleteOutbox(id);
          break;
        case 'upload_attachment':
          final finalized = await _handleUploadAttachment(
            payload,
            currentOutboxId: id,
          );
          final memoUid = payload['memo_uid'] as String?;
          if (finalized && memoUid != null && memoUid.isNotEmpty) {
            await db.updateMemoSyncState(memoUid, syncState: 0);
            final memo = await _loadMemoByUid(memoUid);
            if (memo != null) {
              await _syncMemoToBridgeIfEnabled(memo);
            }
          }
          await db.markOutboxDone(id);
          await db.deleteOutbox(id);
          break;
        case 'delete_attachment':
          await _handleDeleteAttachment(payload);
          final memoUid = payload['memo_uid'] as String?;
          if (memoUid != null && memoUid.isNotEmpty) {
            await db.updateMemoSyncState(memoUid, syncState: 0);
            final memo = await _loadMemoByUid(memoUid);
            if (memo != null) {
              await _syncMemoToBridgeIfEnabled(memo);
            }
          }
          await db.markOutboxDone(id);
          await db.deleteOutbox(id);
          break;
        default:
          throw StateError('Unknown op type: $type');
      }
      counters.markSuccess();
      final elapsedMs = DateTime.now().difference(taskStartAt).inMilliseconds;
      final isSlowTask = elapsedMs >= _slowOutboxTaskThreshold.inMilliseconds;
      if (shouldLogTaskDetail || isSlowTask) {
        LogManager.instance.debug(
          'LocalSync outbox: task_done',
          context: <String, Object?>{
            'id': id,
            'type': type,
            if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
            'elapsedMs': elapsedMs,
            if (isSlowTask) 'slow': true,
          },
        );
      }
    } catch (error) {
      counters.markFailure();
      final elapsedMs = DateTime.now().difference(taskStartAt).inMilliseconds;
      final memoError = error.toString();
      final failedMemoUid = switch (type) {
        'create_memo' => payload['uid'] as String?,
        'update_memo' => payload['uid'] as String?,
        'upload_attachment' => payload['memo_uid'] as String?,
        'delete_attachment' => payload['memo_uid'] as String?,
        _ => null,
      };
      final transient = _isTransientOutboxError(error);
      if (transient) {
        final delay = _retryDelayForAttempt(attemptsSoFar);
        final retryAt =
            DateTime.now().toUtc().millisecondsSinceEpoch +
            delay.inMilliseconds;
        await db.markOutboxRetryScheduled(
          id,
          error: memoError,
          retryAtMs: retryAt,
        );
        blockedReason = 'retry_scheduled';
        if (failedMemoUid != null && failedMemoUid.isNotEmpty) {
          await db.updateMemoSyncState(failedMemoUid, syncState: 1);
        }
      } else {
        if (failedMemoUid != null && failedMemoUid.isNotEmpty) {
          await db.updateMemoSyncState(
            failedMemoUid,
            syncState: 2,
            lastError: trByLanguageKey(
              language: language,
              key: 'legacy.msg_local_sync_failed',
              params: {'type': type, 'memoError': memoError},
            ),
          );
        }
        await db.markOutboxError(id, error: memoError);
        blockedReason = 'error';
      }
      LogManager.instance.warn(
        'LocalSync outbox: task_failed',
        error: error,
        context: <String, Object?>{
          'id': id,
          'type': type,
          if (failedMemoUid != null && failedMemoUid.isNotEmpty)
            'memoUid': failedMemoUid,
          'transient': transient,
          'elapsedMs': elapsedMs,
        },
      );
      shouldStop = true;
    } finally {
      if (!shouldStop && isUploadTask) {
        await syncQueueProgressTracker.markTaskCompleted(outboxId: id);
      }
      syncQueueProgressTracker.clearCurrentTask(outboxId: id);
    }

    _reportOutboxTaskProgress(counters: counters, currentType: type);
    if (shouldStop) {
      return _OutboxTaskRunResult.stop(
        blockedReason: blockedReason ?? 'error',
        stoppedOnType: type,
      );
    }
    return _OutboxTaskRunResult.continueRun();
  }

  void _reportOutboxTaskProgress({
    required _OutboxCounters counters,
    required String currentType,
  }) {
    _maybeLogOutboxProgress(
      processedCount: counters.processedCount,
      successCount: counters.successCount,
      failedCount: counters.failedCount,
      typeCounts: counters.typeCounts,
      currentType: currentType,
    );
    syncQueueProgressTracker.updateCompletedTasks(counters.completedCount);
  }

  bool _isAttachmentOutboxType(String type) {
    return type == 'upload_attachment' || type == 'delete_attachment';
  }

  int? _parseRetryAtMs(Object? raw) {
    return switch (raw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
  }

  String? _extractMemoUidFromPayloadRaw(String type, Object? payloadRaw) {
    if (payloadRaw is! String || payloadRaw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) return null;
      final payload = decoded.cast<String, dynamic>();
      final uid = _outboxMemoUid(type, payload);
      final normalized = uid?.trim() ?? '';
      return normalized.isEmpty ? null : normalized;
    } catch (_) {
      return null;
    }
  }

  bool _shouldLogOutboxTaskDetail({
    required String type,
    required int processedCount,
  }) {
    if (!_isBulkOutboxTaskType(type)) {
      return true;
    }
    if (processedCount <= _bulkOutboxTaskLogHeadCount) {
      return true;
    }
    return processedCount % _bulkOutboxTaskLogEvery == 0;
  }

  bool _isBulkOutboxTaskType(String type) {
    return type == 'create_memo' || type == 'update_memo';
  }

  void _maybeLogOutboxProgress({
    required int processedCount,
    required int successCount,
    required int failedCount,
    required Map<String, int> typeCounts,
    required String currentType,
  }) {
    if (processedCount <= 0 || processedCount % _outboxProgressLogEvery != 0) {
      return;
    }
    LogManager.instance.info(
      'LocalSync outbox: progress',
      context: <String, Object?>{
        'processed': processedCount,
        'succeeded': successCount,
        'failed': failedCount,
        'currentType': currentType,
        if (typeCounts.isNotEmpty) 'typeCounts': typeCounts,
      },
    );
  }

  bool _isTransientOutboxError(Object error) {
    if (error is FileSystemException) {
      final fileErrorText = '${error.message} ${error.osError?.message ?? ''}'
          .toLowerCase();
      if (fileErrorText.contains('not found') ||
          fileErrorText.contains('no such file') ||
          fileErrorText.contains('cannot find the file')) {
        return false;
      }
      return true;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
    }
    final text = error.toString().toLowerCase();
    return text.contains('database is locked') ||
        text.contains('sqlite_error: 5') ||
        text.contains('resource busy') ||
        text.contains('temporarily unavailable') ||
        text.contains('timed out');
  }

  Duration _retryDelayForAttempt(int attemptsSoFar) {
    if (_retryBackoffSteps.isEmpty) {
      return const Duration(seconds: 5);
    }
    final normalizedAttempts = attemptsSoFar < 0 ? 0 : attemptsSoFar;
    final index = normalizedAttempts >= _retryBackoffSteps.length
        ? _retryBackoffSteps.length - 1
        : normalizedAttempts;
    return _retryBackoffSteps[index];
  }

  void _cancelRetrySyncTimer() {
    _retrySyncTimer?.cancel();
    _retrySyncTimer = null;
  }

  Duration _consumeRetryDelay() {
    final index = _retryBackoffIndex < 0
        ? 0
        : (_retryBackoffIndex >= _retryBackoffSteps.length
              ? _retryBackoffSteps.length - 1
              : _retryBackoffIndex);
    final delay = _retryBackoffSteps[index];
    if (_retryBackoffIndex < _retryBackoffSteps.length - 1) {
      _retryBackoffIndex++;
    }
    return delay;
  }

  void _resetRetryState() {
    _cancelRetrySyncTimer();
    _retryBackoffIndex = 0;
  }

  Future<void> _scheduleRetrySyncIfNeeded({
    required bool hasPendingOutbox,
    required bool syncFailed,
  }) async {
    if (_isDisposed) return;
    if (_retrySyncTimer?.isActive ?? false) return;
    if (!hasPendingOutbox && !syncFailed) {
      _resetRetryState();
      return;
    }
    final delay = _consumeRetryDelay();
    LogManager.instance.info(
      'LocalSync: retry_scheduled',
      context: <String, Object?>{
        'delayMs': delay.inMilliseconds,
        'hasPendingOutbox': hasPendingOutbox,
        'syncFailed': syncFailed,
        'retryBackoffIndex': _retryBackoffIndex,
      },
    );
    _retrySyncTimer = Timer(delay, () {
      _retrySyncTimer = null;
      if (_isDisposed) return;
      LogManager.instance.info(
        'LocalSync: retry_triggered',
        context: <String, Object?>{
          'delayMs': delay.inMilliseconds,
          'hasPendingOutbox': hasPendingOutbox,
          'syncFailed': syncFailed,
        },
      );
      unawaited(syncNow());
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelRetrySyncTimer();
    super.dispose();
  }

  String? _outboxMemoUid(String type, Map<String, dynamic> payload) {
    return switch (type) {
      'create_memo' ||
      'update_memo' ||
      'delete_memo' => payload['uid'] as String?,
      'upload_attachment' ||
      'delete_attachment' => payload['memo_uid'] as String?,
      _ => null,
    };
  }

  Future<LocalMemo?> _handleUpsertMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    if (uid == null || uid.trim().isEmpty) {
      throw const FormatException('memo uid missing');
    }
    return _writeMemoFromDb(uid.trim());
  }

  Future<LocalMemo> _writeMemoFromDb(String memoUid) async {
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    final markdown = buildLocalLibraryMarkdown(memo);
    await fileSystem.writeMemo(uid: memoUid, content: markdown);
    return memo;
  }

  Future<void> _handleDeleteMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    if (uid == null || uid.trim().isEmpty) {
      throw const FormatException('delete_memo missing uid');
    }
    await fileSystem.deleteMemo(uid.trim());
    await fileSystem.deleteAttachmentsDir(uid.trim());
    await attachmentStore.deleteMemoDir(uid.trim());
  }

  Future<bool> _handleUploadAttachment(
    Map<String, dynamic> payload, {
    required int currentOutboxId,
  }) async {
    final uid = payload['uid'] as String?;
    final memoUid = payload['memo_uid'] as String?;
    final filePath = payload['file_path'] as String?;
    final filename = payload['filename'] as String?;
    final mimeType =
        payload['mime_type'] as String? ?? 'application/octet-stream';
    if (uid == null ||
        uid.isEmpty ||
        memoUid == null ||
        memoUid.isEmpty ||
        filePath == null ||
        filename == null) {
      throw const FormatException('upload_attachment missing fields');
    }

    final archiveName = attachmentArchiveNameFromPayload(
      attachmentUid: uid,
      filename: filename,
    );
    final privatePath = await attachmentStore.resolveAttachmentPath(
      memoUid,
      archiveName,
    );
    await _copyToPrivate(filePath, privatePath);

    await fileSystem.writeAttachmentFromFile(
      memoUid: memoUid,
      filename: archiveName,
      srcPath: privatePath,
      mimeType: mimeType,
    );

    final size = File(privatePath).existsSync()
        ? File(privatePath).lengthSync()
        : 0;
    final attachment = Attachment(
      name: 'attachments/$uid',
      filename: filename,
      type: mimeType,
      size: size,
      externalLink: Uri.file(privatePath).toString(),
    );
    await _upsertAttachment(memoUid, attachment);

    return await _isLastPendingAttachmentUpload(memoUid, currentOutboxId);
  }

  Future<void> _handleDeleteAttachment(Map<String, dynamic> payload) async {
    final name =
        payload['attachment_name'] as String? ??
        payload['attachmentName'] as String? ??
        payload['name'] as String?;
    final memoUid = payload['memo_uid'] as String?;
    if (name == null ||
        name.trim().isEmpty ||
        memoUid == null ||
        memoUid.trim().isEmpty) {
      throw const FormatException('delete_attachment missing name');
    }
    final uid = _normalizeAttachmentUid(name);

    final row = await db.getMemoByUid(memoUid);
    if (row == null) return;
    final memo = LocalMemo.fromDb(row);
    final next = <Map<String, dynamic>>[];
    Attachment? removed;
    for (final attachment in memo.attachments) {
      if (attachment.uid == uid || attachment.name == name) {
        removed = attachment;
        continue;
      }
      next.add(attachment.toJson());
    }
    await db.updateMemoAttachmentsJson(
      memoUid,
      attachmentsJson: jsonEncode(next),
    );

    if (removed != null) {
      final archiveName = attachmentArchiveName(removed);
      await fileSystem.deleteAttachment(memoUid, archiveName);
      await attachmentStore.deleteAttachment(memoUid, archiveName);
    }
  }

  Future<void> _upsertAttachment(String memoUid, Attachment attachment) async {
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    final next = <Map<String, dynamic>>[];
    var replaced = false;
    for (final existing in memo.attachments) {
      if (existing.uid == attachment.uid) {
        next.add(attachment.toJson());
        replaced = true;
      } else {
        next.add(existing.toJson());
      }
    }
    if (!replaced) {
      next.add(attachment.toJson());
    }
    await db.updateMemoAttachmentsJson(
      memoUid,
      attachmentsJson: jsonEncode(next),
    );
  }

  Future<void> _copyToPrivate(String src, String destPath) async {
    final trimmed = src.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('file_path missing');
    }
    final resolved = trimmed.startsWith('file://')
        ? Uri.parse(trimmed).toFilePath()
        : trimmed;
    if (resolved == destPath) return;
    if (resolved.startsWith('content://')) {
      await SafStream().copyToLocalFile(resolved, destPath);
      return;
    }
    final file = File(resolved);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', resolved);
    }
    await file.copy(destPath);
  }

  Future<bool> _isLastPendingAttachmentUpload(
    String memoUid,
    int currentOutboxId,
  ) async {
    final rows = await db.listOutboxPendingByType('upload_attachment');
    for (final row in rows) {
      final id = row['id'];
      if (id is int && id == currentOutboxId) continue;
      final payload = row['payload'];
      if (payload is! String || payload.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final target = decoded['memo_uid'] as String?;
          if (target != null && target == memoUid) {
            return false;
          }
        }
      } catch (_) {}
    }
    return true;
  }

  String _normalizeAttachmentUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('attachments/')) {
      return trimmed.substring('attachments/'.length);
    }
    if (trimmed.startsWith('resources/')) {
      return trimmed.substring('resources/'.length);
    }
    return trimmed;
  }

  Future<LocalMemo?> _loadMemoByUid(String memoUid) async {
    final row = await db.getMemoByUid(memoUid.trim());
    if (row == null) return null;
    return LocalMemo.fromDb(row);
  }

  Future<void> _syncMemoToBridgeIfEnabled(LocalMemo memo) async {
    final settings = _bridgeSettingsSnapshot;
    if (!settings.enabled || !settings.isPaired) return;
    await _syncMemoToBridge(memo, settings: settings);
  }

  Future<void> _syncMemoToBridge(
    LocalMemo memo, {
    required MemoFlowBridgeSettings settings,
  }) async {
    final content = memo.content.trim();
    final formData = FormData.fromMap({
      'meta': jsonEncode({
        'uid': memo.uid,
        'content': content,
        'createdAt': memo.createTime.toUtc().toIso8601String(),
        'updatedAt': memo.updateTime.toUtc().toIso8601String(),
        'visibility': memo.visibility,
        'state': memo.state,
        'tags': memo.tags,
      }),
    });

    var fileIndex = 0;
    for (final attachment in memo.attachments) {
      final file = await _resolveBridgeAttachmentFile(
        memoUid: memo.uid,
        attachment: attachment,
      );
      if (file == null) continue;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      final filename = sanitizePathSegment(
        attachment.filename.trim().isEmpty
            ? (attachment.uid.trim().isEmpty ? 'attachment' : attachment.uid)
            : attachment.filename,
        fallback: 'attachment',
      );
      formData.files.add(
        MapEntry(
          'file$fileIndex',
          MultipartFile.fromBytes(bytes, filename: filename),
        ),
      );
      fileIndex++;
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://${settings.host}:${settings.port}',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final response = await dio.post(
      '/bridge/v1/memo/upload',
      data: formData,
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer ${settings.token}'},
      ),
    );

    final payload = _readBridgeResponseMap(response.data);
    final ok = payload['ok'];
    if (ok is bool && ok) return;
    final error = (payload['error'] as String?)?.trim();
    final message = (payload['message'] as String?)?.trim();
    final detail = [
      if (error?.isNotEmpty ?? false) error,
      if (message?.isNotEmpty ?? false) message,
    ].join(': ');
    if (detail.isNotEmpty) {
      throw StateError('Bridge sync failed - $detail');
    }
    throw StateError('Bridge sync failed');
  }

  Future<File?> _resolveBridgeAttachmentFile({
    required String memoUid,
    required Attachment attachment,
  }) async {
    final external = attachment.externalLink.trim();
    if (external.startsWith('file://')) {
      try {
        final path = Uri.parse(external).toFilePath();
        final file = File(path);
        if (file.existsSync()) return file;
      } catch (_) {}
    } else if (external.isNotEmpty &&
        !external.startsWith('content://') &&
        !external.startsWith('http://') &&
        !external.startsWith('https://')) {
      final file = File(external);
      if (file.existsSync()) return file;
    }

    final archiveName = attachmentArchiveName(attachment);
    final privatePath = await attachmentStore.resolveAttachmentPath(
      memoUid,
      archiveName,
    );
    final privateFile = File(privatePath);
    if (privateFile.existsSync()) return privateFile;
    return null;
  }

  Map<String, dynamic> _readBridgeResponseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    throw const FormatException('Bridge response is not JSON object');
  }
}

class _OutboxCounters {
  int _processedCount = 0;
  int _successCount = 0;
  int _failedCount = 0;
  final Map<String, int> _typeCounts = <String, int>{};

  int get processedCount => _processedCount;
  int get successCount => _successCount;
  int get failedCount => _failedCount;
  int get completedCount => _successCount + _failedCount;
  Map<String, int> get typeCounts => _typeCounts;

  int markTaskSeen(String type) {
    _processedCount++;
    _typeCounts[type] = (_typeCounts[type] ?? 0) + 1;
    return _processedCount;
  }

  void markSuccess() {
    _successCount++;
  }

  void markFailure() {
    _failedCount++;
  }
}

class _OutboxTaskRunResult {
  const _OutboxTaskRunResult.continueRun()
    : shouldStop = false,
      blockedReason = null,
      stoppedOnType = null;

  const _OutboxTaskRunResult.stop({
    required this.blockedReason,
    required this.stoppedOnType,
  }) : shouldStop = true,
       assert(blockedReason != null),
       assert(stoppedOnType != null);

  final bool shouldStop;
  final String? blockedReason;
  final String? stoppedOnType;
}

class _AttachmentOutboxBatchResult {
  const _AttachmentOutboxBatchResult({
    required this.started,
    required this.shouldStop,
    this.blockedReason,
    this.stoppedOnType,
  });

  const _AttachmentOutboxBatchResult.notStarted()
    : started = false,
      shouldStop = false,
      blockedReason = null,
      stoppedOnType = null;

  final bool started;
  final bool shouldStop;
  final String? blockedReason;
  final String? stoppedOnType;
}

class _AttachmentOutboxCandidate {
  const _AttachmentOutboxCandidate({required this.id, required this.memoUid});

  final int id;
  final String? memoUid;
}
