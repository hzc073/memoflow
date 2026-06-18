import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_location.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/system/logging_provider.dart';
import 'memos_list_inline_compose_coordinator.dart';

typedef MemosListMutationRead = T Function<T>(ProviderListenable<T> provider);

abstract interface class MemosListMutationRepositoryAdapter {
  Future<void> createQuickInputMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
  });

  Future<void> createInlineComposeMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required List<Map<String, dynamic>> relations,
    required List<MemoComposerPendingAttachment> pendingAttachments,
  });

  Future<void> updateMemo(LocalMemo memo, {bool? pinned, String? state});

  Future<void> adjustMemoTime({
    required LocalMemo memo,
    required DateTime selectedTime,
  });

  Future<void> updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
  });

  Future<void> deleteMemo(LocalMemo memo, {VoidCallback? onMovedToRecycleBin});

  Future<int> retryOutboxErrors({required String memoUid});
}

class RiverpodMemosListMutationRepositoryAdapter
    implements MemosListMutationRepositoryAdapter {
  RiverpodMemosListMutationRepositoryAdapter({
    required MemosListMutationRead read,
  }) : _read = read;

  final MemosListMutationRead _read;

  @override
  Future<void> createQuickInputMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
  }) {
    return _read(memosListControllerProvider).createQuickInputMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      nowSec: nowSec,
      tags: tags,
    );
  }

  @override
  Future<void> createInlineComposeMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required List<Map<String, dynamic>> relations,
    required List<MemoComposerPendingAttachment> pendingAttachments,
  }) {
    return _read(memosListControllerProvider).createInlineComposeMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      nowSec: nowSec,
      tags: tags,
      attachments: attachments,
      location: location,
      relations: relations,
      pendingAttachments: pendingAttachments,
    );
  }

  @override
  Future<void> updateMemo(LocalMemo memo, {bool? pinned, String? state}) {
    return _read(
      memosListControllerProvider,
    ).updateMemo(memo, pinned: pinned, state: state);
  }

  @override
  Future<void> adjustMemoTime({
    required LocalMemo memo,
    required DateTime selectedTime,
  }) {
    return _read(
      memosListControllerProvider,
    ).adjustMemoTime(memo: memo, selectedTime: selectedTime);
  }

  @override
  Future<void> updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
  }) {
    return _read(
      memosListControllerProvider,
    ).updateMemoContent(memo, content, preserveUpdateTime: preserveUpdateTime);
  }

  @override
  Future<void> deleteMemo(LocalMemo memo, {VoidCallback? onMovedToRecycleBin}) {
    return _read(
      memosListControllerProvider,
    ).deleteMemo(memo, onMovedToRecycleBin: onMovedToRecycleBin);
  }

  @override
  Future<int> retryOutboxErrors({required String memoUid}) {
    return _read(
      memosListControllerProvider,
    ).retryOutboxErrors(memoUid: memoUid);
  }
}

abstract interface class MemosListMutationSyncAdapter {
  Future<void> requestMemosSync();
}

class RiverpodMemosListMutationSyncAdapter
    implements MemosListMutationSyncAdapter {
  RiverpodMemosListMutationSyncAdapter({required MemosListMutationRead read})
    : _read = read;

  final MemosListMutationRead _read;

  @override
  Future<void> requestMemosSync() async {
    await _read(syncCoordinatorProvider.notifier).requestSync(
      const SyncRequest(
        kind: SyncRequestKind.memos,
        reason: SyncRequestReason.manual,
      ),
    );
  }
}

enum MemosListMutationResultKind { handled, noop, failed }

@immutable
class MemosListMutationResult {
  const MemosListMutationResult({required this.kind, this.error});

  const MemosListMutationResult.handled()
    : kind = MemosListMutationResultKind.handled,
      error = null;

  const MemosListMutationResult.noop()
    : kind = MemosListMutationResultKind.noop,
      error = null;

  const MemosListMutationResult.failed(Object this.error)
    : kind = MemosListMutationResultKind.failed;

  final MemosListMutationResultKind kind;
  final Object? error;
}

enum MemosListRetryFailedSyncResultKind { retryStarted, openSyncQueue, failed }

@immutable
class MemosListRetryFailedSyncResult {
  const MemosListRetryFailedSyncResult({
    required this.kind,
    this.retriedCount,
    this.error,
  });

  const MemosListRetryFailedSyncResult.retryStarted({
    required this.retriedCount,
  }) : kind = MemosListRetryFailedSyncResultKind.retryStarted,
       error = null;

  const MemosListRetryFailedSyncResult.openSyncQueue()
    : kind = MemosListRetryFailedSyncResultKind.openSyncQueue,
      retriedCount = null,
      error = null;

  const MemosListRetryFailedSyncResult.failed(Object this.error)
    : kind = MemosListRetryFailedSyncResultKind.failed,
      retriedCount = null;

  final MemosListRetryFailedSyncResultKind kind;
  final int? retriedCount;
  final Object? error;
}

class MemosListMutationCoordinator extends ChangeNotifier {
  MemosListMutationCoordinator({
    required MemosListMutationRead read,
    MemosListMutationRepositoryAdapter? repositoryOverride,
    MemosListMutationSyncAdapter? syncOverride,
    DateTime Function()? now,
    String Function()? uidFactory,
  }) : _read = read,
       _repository =
           repositoryOverride ??
           RiverpodMemosListMutationRepositoryAdapter(read: read),
       _sync = syncOverride ?? RiverpodMemosListMutationSyncAdapter(read: read),
       _now = now ?? DateTime.now,
       _uidFactory = uidFactory ?? generateUid;

  final MemosListMutationRead _read;
  final MemosListMutationRepositoryAdapter _repository;
  final MemosListMutationSyncAdapter _sync;
  final DateTime Function() _now;
  final String Function() _uidFactory;

  bool _inlineComposeSubmitting = false;
  bool _desktopQuickInputSubmitting = false;
  bool _disposed = false;

  bool get inlineComposeSubmitting => _inlineComposeSubmitting;
  bool get desktopQuickInputSubmitting => _desktopQuickInputSubmitting;

  Future<MemosListMutationResult> submitQuickInput({
    required String rawContent,
    required String visibility,
  }) async {
    if (_disposed || _desktopQuickInputSubmitting) {
      return const MemosListMutationResult.noop();
    }

    final content = rawContent.trimRight();
    if (content.trim().isEmpty) {
      return const MemosListMutationResult.noop();
    }

    _desktopQuickInputSubmitting = true;
    _notifyChanged();
    try {
      final now = _now();
      final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      final uid = _uidFactory();
      final tagRecognitionPolicy = _read(
        currentWorkspacePreferencesProvider,
      ).tagRecognitionPolicy;
      final tags = extractTags(content, policy: tagRecognitionPolicy);
      await _repository.createQuickInputMemo(
        uid: uid,
        content: content,
        visibility: visibility,
        nowSec: nowSec,
        tags: tags,
      );
      unawaited(
        _requestMemosSyncFollowUp(
          operation: 'quick_input',
          context: <String, Object?>{
            'uid': uid,
            'visibility': visibility,
            'contentLength': content.length,
            'tagCount': tags.length,
          },
        ),
      );
      return const MemosListMutationResult.handled();
    } catch (error, stackTrace) {
      _logMutationError(
        'quick_input_submit_failed',
        error,
        stackTrace,
        context: <String, Object?>{
          'visibility': visibility,
          'rawLength': rawContent.length,
        },
      );
      return MemosListMutationResult.failed(error);
    } finally {
      _desktopQuickInputSubmitting = false;
      _notifyChanged();
    }
  }

  Future<MemosListMutationResult> submitInlineCompose(
    InlineComposeSubmissionDraft draft,
  ) async {
    if (_disposed || _inlineComposeSubmitting) {
      return const MemosListMutationResult.noop();
    }

    _inlineComposeSubmitting = true;
    _notifyChanged();
    try {
      final now = _now();
      final uid = _uidFactory();
      final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      await _repository.createInlineComposeMemo(
        uid: uid,
        content: draft.content,
        visibility: draft.visibility,
        nowSec: nowSec,
        tags: draft.tags,
        attachments: draft.attachmentsPayload,
        location: draft.location,
        relations: draft.relations,
        pendingAttachments: draft.pendingAttachments,
      );
      unawaited(
        _requestMemosSyncFollowUp(
          operation: 'inline_compose',
          context: <String, Object?>{
            'uid': uid,
            'visibility': draft.visibility,
            'contentLength': draft.content.length,
            'tagCount': draft.tags.length,
            'attachmentCount': draft.pendingAttachments.length,
            'relationCount': draft.relations.length,
            'hasLocation': draft.location != null,
          },
        ),
      );
      return const MemosListMutationResult.handled();
    } catch (error, stackTrace) {
      _logMutationError(
        'inline_compose_submit_failed',
        error,
        stackTrace,
        context: <String, Object?>{
          'contentLength': draft.content.length,
          'visibility': draft.visibility,
          'tagCount': draft.tags.length,
          'attachmentCount': draft.pendingAttachments.length,
          'relationCount': draft.relations.length,
        },
      );
      return MemosListMutationResult.failed(error);
    } finally {
      _inlineComposeSubmitting = false;
      _notifyChanged();
    }
  }

  Future<MemosListMutationResult> updateMemo(
    LocalMemo memo, {
    bool? pinned,
    String? state,
    bool triggerSync = true,
  }) async {
    if (_disposed) {
      return const MemosListMutationResult.noop();
    }
    if (pinned == null && state == null) {
      return const MemosListMutationResult.noop();
    }

    try {
      await _repository.updateMemo(memo, pinned: pinned, state: state);
      if (triggerSync) {
        unawaited(
          _requestMemosSyncFollowUp(
            operation: 'update_memo',
            context: <String, Object?>{
              'memoUid': memo.uid,
              'pinned': pinned,
              'state': state,
            },
          ),
        );
      }
      return const MemosListMutationResult.handled();
    } catch (error, stackTrace) {
      _logMutationError(
        'update_memo_failed',
        error,
        stackTrace,
        context: <String, Object?>{
          'memoUid': memo.uid,
          'pinned': pinned,
          'state': state,
          'triggerSync': triggerSync,
        },
      );
      return MemosListMutationResult.failed(error);
    }
  }

  Future<MemosListMutationResult> adjustMemoTime({
    required LocalMemo memo,
    required DateTime selectedTime,
    bool triggerSync = true,
  }) async {
    if (_disposed) {
      return const MemosListMutationResult.noop();
    }

    final selectedTimeSec = selectedTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    try {
      await _repository.adjustMemoTime(memo: memo, selectedTime: selectedTime);
      if (triggerSync) {
        unawaited(
          _requestMemosSyncFollowUp(
            operation: 'adjust_memo_time',
            context: <String, Object?>{
              'memoUid': memo.uid,
              'selectedTimeSec': selectedTimeSec,
            },
          ),
        );
      }
      return const MemosListMutationResult.handled();
    } catch (error, stackTrace) {
      _logMutationError(
        'adjust_memo_time_failed',
        error,
        stackTrace,
        context: <String, Object?>{
          'memoUid': memo.uid,
          'selectedTimeSec': selectedTimeSec,
          'triggerSync': triggerSync,
        },
      );
      return MemosListMutationResult.failed(error);
    }
  }

  Future<MemosListMutationResult> updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
    bool triggerSync = true,
  }) async {
    if (_disposed) {
      return const MemosListMutationResult.noop();
    }
    if (content == memo.content) {
      return const MemosListMutationResult.noop();
    }

    try {
      await _repository.updateMemoContent(
        memo,
        content,
        preserveUpdateTime: preserveUpdateTime,
      );
      if (triggerSync) {
        unawaited(
          _requestMemosSyncFollowUp(
            operation: 'update_memo_content',
            context: <String, Object?>{
              'memoUid': memo.uid,
              'contentLength': content.length,
              'preserveUpdateTime': preserveUpdateTime,
            },
          ),
        );
      }
      return const MemosListMutationResult.handled();
    } catch (error, stackTrace) {
      _logMutationError(
        'update_memo_content_failed',
        error,
        stackTrace,
        context: <String, Object?>{
          'memoUid': memo.uid,
          'contentLength': content.length,
          'preserveUpdateTime': preserveUpdateTime,
          'triggerSync': triggerSync,
        },
      );
      return MemosListMutationResult.failed(error);
    }
  }

  Future<MemosListMutationResult> deleteMemo(
    LocalMemo memo, {
    VoidCallback? onMovedToRecycleBin,
  }) async {
    if (_disposed) {
      return const MemosListMutationResult.noop();
    }

    try {
      await _repository.deleteMemo(
        memo,
        onMovedToRecycleBin: onMovedToRecycleBin,
      );
      unawaited(
        _requestMemosSyncFollowUp(
          operation: 'delete_memo',
          context: <String, Object?>{'memoUid': memo.uid},
        ),
      );
      return const MemosListMutationResult.handled();
    } catch (error, stackTrace) {
      _logMutationError(
        'delete_memo_failed',
        error,
        stackTrace,
        context: <String, Object?>{'memoUid': memo.uid},
      );
      return MemosListMutationResult.failed(error);
    }
  }

  Future<MemosListRetryFailedSyncResult> retryFailedMemoSync(
    String memoUid,
  ) async {
    if (_disposed) {
      return const MemosListRetryFailedSyncResult.openSyncQueue();
    }

    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) {
      return const MemosListRetryFailedSyncResult.openSyncQueue();
    }

    try {
      final retried = await _repository.retryOutboxErrors(
        memoUid: normalizedUid,
      );
      if (retried <= 0) {
        return const MemosListRetryFailedSyncResult.openSyncQueue();
      }
      unawaited(
        _requestMemosSyncFollowUp(
          operation: 'retry_failed_sync',
          context: <String, Object?>{
            'memoUid': normalizedUid,
            'retriedCount': retried,
          },
        ),
      );
      return MemosListRetryFailedSyncResult.retryStarted(retriedCount: retried);
    } catch (error, stackTrace) {
      _logMutationError(
        'retry_failed_sync_failed',
        error,
        stackTrace,
        context: <String, Object?>{'memoUid': normalizedUid},
      );
      return MemosListRetryFailedSyncResult.failed(error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _requestMemosSyncFollowUp({
    required String operation,
    Map<String, Object?>? context,
  }) async {
    try {
      await _sync.requestMemosSync();
    } catch (error, stackTrace) {
      _read(logManagerProvider).warn(
        'Memos mutation sync follow-up failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': operation,
          if (context != null) ...context,
        },
      );
    }
  }

  void _logMutationError(
    String message,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?>? context,
  }) {
    _read(logManagerProvider).error(
      'Memos mutation: $message',
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void _notifyChanged() {
    if (_disposed) return;
    notifyListeners();
  }
}
