import 'package:flutter/material.dart';

import '../../data/models/local_memo.dart';
import '../../i18n/strings.g.dart';
import 'memo_task_list_service.dart';
import 'memos_list_mutation_coordinator.dart';
import 'widgets/memos_list_memo_card.dart';

class MemosListMemoActionDelegate {
  MemosListMemoActionDelegate({
    required BuildContext Function() contextResolver,
    required MemosListMutationCoordinator mutationCoordinator,
    required Future<void> Function(String memoUid) onRetryOpenSyncQueue,
    required Future<bool> Function(LocalMemo memo) confirmDelete,
    required void Function(LocalMemo memo) removeMemoWithAnimation,
    required void Function(String memoUid) invalidateMemoRenderCache,
    required void Function(String memoUid) invalidateMemoMarkdownCache,
    required Future<void> Function(LocalMemo memo) openEditor,
    required Future<void> Function(LocalMemo memo) openHistory,
    required Future<void> Function(LocalMemo memo) openReminder,
    required Future<void> Function(String toastMessage) handleRestoreSuccess,
    required void Function(String message) showTopToast,
    required void Function(String message) showSnackBar,
  }) : _contextResolver = contextResolver,
       _mutationCoordinator = mutationCoordinator,
       _onRetryOpenSyncQueue = onRetryOpenSyncQueue,
       _confirmDelete = confirmDelete,
       _removeMemoWithAnimation = removeMemoWithAnimation,
       _invalidateMemoRenderCache = invalidateMemoRenderCache,
       _invalidateMemoMarkdownCache = invalidateMemoMarkdownCache,
       _openEditor = openEditor,
       _openHistory = openHistory,
       _openReminder = openReminder,
       _handleRestoreSuccess = handleRestoreSuccess,
       _showTopToast = showTopToast,
       _showSnackBar = showSnackBar;

  final BuildContext Function() _contextResolver;
  final MemosListMutationCoordinator _mutationCoordinator;
  final Future<void> Function(String memoUid) _onRetryOpenSyncQueue;
  final Future<bool> Function(LocalMemo memo) _confirmDelete;
  final void Function(LocalMemo memo) _removeMemoWithAnimation;
  final void Function(String memoUid) _invalidateMemoRenderCache;
  final void Function(String memoUid) _invalidateMemoMarkdownCache;
  final Future<void> Function(LocalMemo memo) _openEditor;
  final Future<void> Function(LocalMemo memo) _openHistory;
  final Future<void> Function(LocalMemo memo) _openReminder;
  final Future<void> Function(String toastMessage) _handleRestoreSuccess;
  final void Function(String message) _showTopToast;
  final void Function(String message) _showSnackBar;

  Future<void> retryFailedMemoSync(String memoUid) async {
    final result = await _mutationCoordinator.retryFailedMemoSync(memoUid);
    final context = _contextResolver();
    if (!context.mounted) return;
    switch (result.kind) {
      case MemosListRetryFailedSyncResultKind.retryStarted:
        _showTopToast(context.t.strings.legacy.msg_retry_started);
        return;
      case MemosListRetryFailedSyncResultKind.openSyncQueue:
      case MemosListRetryFailedSyncResultKind.failed:
        await _onRetryOpenSyncQueue(memoUid);
        return;
    }
  }

  Future<void> handleMemoSyncStatusTap(
    MemoSyncStatus status,
    String memoUid,
  ) async {
    switch (status) {
      case MemoSyncStatus.failed:
        await retryFailedMemoSync(memoUid);
        return;
      case MemoSyncStatus.pending:
      case MemoSyncStatus.none:
        await _onRetryOpenSyncQueue(memoUid);
        return;
    }
  }

  Future<MemosListMutationResult> updateMemo(
    LocalMemo memo, {
    bool? pinned,
    String? state,
    bool triggerSync = true,
  }) {
    return _mutationCoordinator.updateMemo(
      memo,
      pinned: pinned,
      state: state,
      triggerSync: triggerSync,
    );
  }

  Future<MemosListMutationResult> updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
    bool triggerSync = true,
  }) {
    return _mutationCoordinator.updateMemoContent(
      memo,
      content,
      preserveUpdateTime: preserveUpdateTime,
      triggerSync: triggerSync,
    );
  }

  Future<void> toggleMemoCheckbox(
    LocalMemo memo,
    int index, {
    required bool skipQuotedLines,
  }) async {
    final updated = toggleCheckbox(
      memo.content,
      index,
      skipQuotedLines: skipQuotedLines,
    );
    if (updated == memo.content) return;
    _invalidateMemoRenderCache(memo.uid);
    _invalidateMemoMarkdownCache(memo.uid);
    await updateMemoContent(
      memo,
      updated,
      preserveUpdateTime: true,
      triggerSync: false,
    );
  }

  Future<void> deleteMemo(LocalMemo memo) async {
    final confirmed = await _confirmDelete(memo);
    if (!confirmed) return;

    final result = await _mutationCoordinator.deleteMemo(
      memo,
      onMovedToRecycleBin: () => _removeMemoWithAnimation(memo),
    );
    final context = _contextResolver();
    if (!context.mounted) return;
    switch (result.kind) {
      case MemosListMutationResultKind.handled:
      case MemosListMutationResultKind.noop:
        return;
      case MemosListMutationResultKind.failed:
        final error = result.error ?? '';
        _showSnackBar(context.t.strings.legacy.msg_delete_failed(e: error));
        return;
    }
  }

  Future<void> restoreMemo(LocalMemo memo) async {
    final result = await updateMemo(memo, state: 'NORMAL');
    final context = _contextResolver();
    if (!context.mounted) return;
    switch (result.kind) {
      case MemosListMutationResultKind.handled:
        await _handleRestoreSuccess(context.t.strings.legacy.msg_restored);
        return;
      case MemosListMutationResultKind.noop:
        return;
      case MemosListMutationResultKind.failed:
        final error = result.error ?? '';
        _showSnackBar(context.t.strings.legacy.msg_restore_failed(e: error));
        return;
    }
  }

  Future<void> archiveMemo(LocalMemo memo) async {
    final result = await updateMemo(memo, state: 'ARCHIVED');
    final context = _contextResolver();
    if (!context.mounted) return;
    switch (result.kind) {
      case MemosListMutationResultKind.handled:
        _removeMemoWithAnimation(memo);
        _showTopToast(context.t.strings.legacy.msg_archived);
        return;
      case MemosListMutationResultKind.noop:
        return;
      case MemosListMutationResultKind.failed:
        final error = result.error ?? '';
        _showSnackBar(context.t.strings.legacy.msg_archive_failed(e: error));
        return;
    }
  }

  Future<void> handleMemoAction(LocalMemo memo, MemoCardAction action) async {
    switch (action) {
      case MemoCardAction.togglePinned:
        await updateMemo(memo, pinned: !memo.pinned);
        return;
      case MemoCardAction.edit:
        await _openEditor(memo);
        return;
      case MemoCardAction.history:
        await _openHistory(memo);
        return;
      case MemoCardAction.reminder:
        await _openReminder(memo);
        return;
      case MemoCardAction.archive:
        await archiveMemo(memo);
        return;
      case MemoCardAction.restore:
        await restoreMemo(memo);
        return;
      case MemoCardAction.delete:
        await deleteMemo(memo);
        return;
    }
  }
}
