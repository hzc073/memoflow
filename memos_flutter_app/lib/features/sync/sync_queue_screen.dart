import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/sync/memo_sync_service.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/sync_error_presenter.dart';
import '../../application/sync/sync_feedback_presenter.dart';
import '../../core/top_toast.dart';
import '../../state/settings/memoflow_bridge_settings_provider.dart';
import '../../state/memos/sync_queue_controller.dart';
import '../../state/memos/sync_queue_models.dart';
import '../../state/memos/sync_queue_provider.dart';
import '../../state/system/logging_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/system/database_provider.dart';
import '../../data/models/local_memo.dart';
import '../../state/memos/memo_sync_constraints.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memos_list_screen.dart';
import '../../i18n/strings.g.dart';

final _bridgeBulkPushRunningProvider = StateProvider<bool>((ref) => false);

class SyncQueueScreen extends ConsumerWidget {
  const SyncQueueScreen({super.key});

  void _backToAllMemos(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.safePop();
      return;
    }
    _backToAllMemos(context);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SyncQueueItem item,
  ) async {
    final memoUid = item.memoUid?.trim();
    if (memoUid != null && memoUid.isNotEmpty) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.t.strings.legacy.msg_delete_sync_task),
              content: Text(
                context.t.strings.legacy.msg_only_delete_sync_task_memo_kept,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.t.strings.legacy.msg_cancel_2),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.t.strings.legacy.msg_delete_task),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      await ref.read(syncQueueControllerProvider).deleteItem(item);
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_delete_sync_task),
            content: Text(context.t.strings.legacy.msg_only_delete_sync_task),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_delete_task),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(syncQueueControllerProvider).deleteItem(item);
  }

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(syncQueueControllerProvider).requestSync();
    if (!context.mounted) return;
    if (result is SyncRunQueued) return;
    final syncStatus = ref.read(syncCoordinatorProvider).memos;
    if (syncStatus.running) return;
    final language = ref.read(appPreferencesProvider.select((p) => p.language));
    showSyncFeedback(
      overlayContext: context,
      messengerContext: context,
      language: language,
      succeeded: syncStatus.lastError == null,
    );
  }

  Future<void> _openMemo(
    BuildContext context,
    WidgetRef ref,
    SyncQueueItem item,
  ) async {
    final memoUid = item.memoUid?.trim();
    if (memoUid == null || memoUid.isEmpty) return;
    final row = await ref.read(databaseProvider).getMemoByUid(memoUid);
    if (!context.mounted) return;
    if (row == null) {
      showTopToast(
        context,
        context.tr(
          zh: '本地笔记不存在，无法打开',
          en: 'The local memo no longer exists.',
        ),
      );
      return;
    }
    final memo = LocalMemo.fromDb(row);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoDetailScreen(initialMemo: memo),
      ),
    );
  }

  Future<void> _retryItem(
    BuildContext context,
    WidgetRef ref,
    SyncQueueItem item,
  ) async {
    await ref.read(syncQueueControllerProvider).retryItem(item);
    if (!context.mounted) return;
    await _syncAll(context, ref);
  }

  Future<void> _pushAllToBridge(BuildContext context, WidgetRef ref) async {
    final tr = context.t.strings.legacy;
    final bridgeService = ref.read(memoBridgeServiceProvider);
    if (bridgeService == null) {
      showTopToast(context, tr.msg_bridge_local_mode_only);
      return;
    }

    final settings = ref.read(memoFlowBridgeSettingsProvider);
    if (!settings.enabled) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_enable_sync_bridge_first,
      );
      return;
    }
    if (!settings.isPaired) {
      showTopToast(context, tr.msg_bridge_need_pair_first);
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_sync_to_obsidian),
            content: Text(
              context.t.strings.legacy.msg_sync_to_obsidian_confirm,
            ),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_continue),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    if (ref.read(_bridgeBulkPushRunningProvider)) return;
    ref.read(_bridgeBulkPushRunningProvider.notifier).state = true;
    try {
      final result = await bridgeService.pushAllMemosToBridge(
        includeArchived: true,
      );
      if (!context.mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_sync_completed_summary(
          succeeded: result.succeeded,
          total: result.total,
          failed: result.failed,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_sync_failed_with_error(error: e),
      );
    } finally {
      if (context.mounted) {
        ref.read(_bridgeBulkPushRunningProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.5 : 0.6);
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;

    final activeQueueAsync = ref.watch(syncQueueItemsProvider);
    final attentionQueueAsync = ref.watch(syncQueueAttentionItemsProvider);
    final activeItems = activeQueueAsync.valueOrNull ?? const <SyncQueueItem>[];
    final attentionItems =
        attentionQueueAsync.valueOrNull ?? const <SyncQueueItem>[];
    final pendingCountAsync = ref.watch(syncQueuePendingCountProvider);
    final attentionCountAsync = ref.watch(syncQueueAttentionCountProvider);
    final pendingCount = pendingCountAsync.valueOrNull ?? activeItems.length;
    final attentionCount =
        attentionCountAsync.valueOrNull ?? attentionItems.length;
    final queueProgress = ref.watch(syncQueueProgressTrackerProvider).snapshot;
    final syncing =
        ref.watch(syncCoordinatorProvider).memos.running ||
        queueProgress.syncing;
    final bridgeBulkPushing = ref.watch(_bridgeBulkPushRunningProvider);
    final bridgeService = ref.watch(memoBridgeServiceProvider);
    final bridgeSettings = ref.watch(memoFlowBridgeSettingsProvider);
    final canPushToBridge =
        !syncing &&
        !bridgeBulkPushing &&
        bridgeService != null &&
        bridgeSettings.enabled &&
        bridgeSettings.isPaired;
    final syncSnapshot = ref.watch(syncStatusTrackerProvider).snapshot;
    int? firstPendingId;
    final itemIds = <int>{};
    for (final item in activeItems) {
      itemIds.add(item.id);
      firstPendingId ??= item.id;
    }
    final trackedOutboxId = queueProgress.currentOutboxId;
    final activeOutboxId = syncing
        ? (trackedOutboxId != null && itemIds.contains(trackedOutboxId)
              ? trackedOutboxId
              : firstPendingId)
        : null;

    final lastSuccess = syncSnapshot.lastSuccess;
    final lastSuccessLabel = lastSuccess == null
        ? context.t.strings.legacy.msg_no_record_yet
        : DateFormat('MM-dd HH:mm').format(lastSuccess);
    final queueLoading =
        (activeQueueAsync.isLoading && activeQueueAsync.valueOrNull == null) ||
        (attentionQueueAsync.isLoading &&
            attentionQueueAsync.valueOrNull == null);
    final queueError =
        activeQueueAsync.hasError
            ? activeQueueAsync.error
            : attentionQueueAsync.hasError
            ? attentionQueueAsync.error
            : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(context.t.strings.legacy.msg_sync_queue),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(context),
          ),
          actions: [
            IconButton(
              tooltip: context.t.strings.legacy.msg_sync,
              onPressed: (syncing || bridgeBulkPushing)
                  ? null
                  : () => _syncAll(context, ref),
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: queueLoading
            ? const Center(child: CircularProgressIndicator())
            : (queueError != null &&
                  activeItems.isEmpty &&
                  attentionItems.isEmpty)
            ? Center(
                child: Text(
                  context.t.strings.legacy.msg_failed_load_4(e: queueError),
                  style: TextStyle(color: textMuted),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _SyncSummaryCard(
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    border: border,
                    pendingCount: pendingCount,
                    attentionCount: attentionCount,
                    lastSuccessLabel: lastSuccessLabel,
                    syncing: syncing,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t.strings.legacy.msg_active_tasks,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activeItems.isEmpty)
                    _EmptyQueueCard(card: card, textMuted: textMuted)
                  else
                    ...activeItems.map((item) {
                      final title = _resolveItemTitle(context, item);
                      final subtitle = _resolveItemSubtitle(item);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SyncQueueItemCard(
                          item: item,
                          title: title,
                          subtitle: subtitle,
                          card: card,
                          border: border,
                          textMain: textMain,
                          textMuted: textMuted,
                          activeOutboxId: activeOutboxId,
                          activeProgress: queueProgress.currentProgress,
                          actionLabel: context.t.strings.legacy.msg_sync,
                          onDelete: () => _confirmDelete(context, ref, item),
                          onSync: (syncing || bridgeBulkPushing)
                              ? null
                              : () => _syncAll(context, ref),
                        ),
                      );
                    }),
                  if (attentionItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr(zh: '需处理', en: 'Needs attention'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...attentionItems.map((item) {
                      final title = _resolveItemTitle(context, item);
                      final subtitle = _resolveItemSubtitle(item);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SyncQueueItemCard(
                          item: item,
                          title: title,
                          subtitle: subtitle,
                          card: card,
                          border: border,
                          textMain: textMain,
                          textMuted: textMuted,
                          activeOutboxId: null,
                          activeProgress: null,
                          actionLabel: context.tr(zh: '重试', en: 'Retry'),
                          onDelete: () => _confirmDelete(context, ref, item),
                          onOpenMemo:
                              item.memoUid?.trim().isNotEmpty == true
                                  ? () => _openMemo(context, ref, item)
                                  : null,
                          onSync: (syncing || bridgeBulkPushing)
                              ? null
                              : () => _retryItem(context, ref, item),
                        ),
                      );
                    }),
                  ],
                ],
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canPushToBridge
                      ? () => _pushAllToBridge(context, ref)
                      : null,
                  icon: bridgeBulkPushing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    bridgeBulkPushing
                        ? context
                              .t
                              .strings
                              .legacy
                              .msg_sync_to_obsidian_in_progress
                        : context.t.strings.legacy.msg_sync_to_obsidian,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (activeItems.isEmpty || syncing || bridgeBulkPushing)
                      ? null
                      : () => _syncAll(context, ref),
                  icon: syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    syncing
                        ? context.t.strings.legacy.msg_syncing
                        : context.t.strings.legacy.msg_sync_all,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _resolveItemTitle(BuildContext context, SyncQueueItem item) {
  if (item.type == 'upload_attachment') {
    return item.filename?.trim().isNotEmpty == true
        ? item.filename!.trim()
        : _actionLabel(context, item.type);
  }
  if (item.preview != null && item.preview!.trim().isNotEmpty) {
    return item.preview!.trim();
  }
  if (item.filename != null && item.filename!.trim().isNotEmpty) {
    return item.filename!.trim();
  }
  return _actionLabel(context, item.type);
}

String? _resolveItemSubtitle(SyncQueueItem item) {
  if (item.type == 'upload_attachment') {
    return item.preview;
  }
  return null;
}

String _contentTooLongFailureText(BuildContext context, SyncQueueItem item) {
  final maxChars = tryParseRemoteMemoLengthLimit(item.lastError ?? '');
  if (maxChars != null) {
    return context.tr(
      zh:
          '\u5f53\u524d\u670d\u52a1\u5668\u9650\u5236\u4e3a $maxChars \u4e2a\u5b57\u7b26\uff0c\u8bf7\u5148\u8c03\u6574\u670d\u52a1\u7aef\u957f\u5ea6\u4e0a\u9650\u540e\u518d\u91cd\u8bd5\uff1b\u5982\u679c\u4f60\u65e0\u6cd5\u4fee\u6539\u670d\u52a1\u7aef\uff0c\u518d\u8003\u8651\u7f29\u77ed\u5185\u5bb9\u3002',
      en:
          'The current server limit is $maxChars characters. Increase the server memo length limit and retry. If you cannot change the server, shorten this memo and retry.',
    );
  }
  return context.tr(
    zh:
        '\u5f53\u524d\u670d\u52a1\u5668\u9650\u5236\u4e86\u5355\u6761\u7b14\u8bb0\u957f\u5ea6\uff0c\u8bf7\u5148\u8c03\u6574\u670d\u52a1\u7aef\u957f\u5ea6\u4e0a\u9650\u540e\u518d\u91cd\u8bd5\uff1b\u5982\u679c\u4f60\u65e0\u6cd5\u4fee\u6539\u670d\u52a1\u7aef\uff0c\u518d\u8003\u8651\u7f29\u77ed\u5185\u5bb9\u3002',
    en:
        'This server limits memo length. Increase the server memo length limit and retry. If you cannot change the server, shorten this memo and retry.',
  );
}

String? _friendlyFailureText(BuildContext context, SyncQueueItem item) {
  final failureCode = item.failureCode?.trim();
  if (failureCode != null && failureCode.isNotEmpty) {
    switch (failureCode) {
      case 'content_too_long':
        return _contentTooLongFailureText(context, item);
      case 'remote_missing_memo':
        return context.tr(
          zh: '服务器上已找不到这条笔记，请检查后重试或删除该任务',
          en: 'This memo no longer exists on the server. Check it, then retry or delete the task.',
        );
      case 'blocked_by_quarantined_memo_root':
        return context.tr(
          zh: '该任务依赖一条待处理的笔记同步任务',
          en: 'This task depends on a memo sync task that needs attention.',
        );
      case 'invalid_payload':
        return context.tr(
          zh: '同步任务数据已损坏，请删除后重新生成',
          en: 'This sync task payload is invalid. Delete it and recreate it.',
        );
      case 'legacy_error_migrated':
        return context.tr(
          zh: '旧版本失败任务已迁移到待处理区，请手动检查',
          en: 'This legacy failed task was migrated and needs manual review.',
        );
      case 'http_client_fatal':
        return context.tr(
          zh: '请求被服务器拒绝，请检查内容或状态后重试',
          en: 'The server rejected this request. Review the memo and retry.',
        );
      case 'unknown_non_retryable':
        return context.tr(
          zh: '该任务已多次失败，需手动处理',
          en: 'This task failed repeatedly and needs manual review.',
        );
    }
  }
  final raw = item.lastError?.trim();
  if (raw == null || raw.isEmpty) return null;
  return presentSyncErrorText(language: context.appLanguage, raw: raw);
}

String _actionLabel(BuildContext context, String type) {
  return switch (type) {
    'create_memo' => context.t.strings.legacy.msg_create_memo,
    'update_memo' => context.t.strings.legacy.msg_update_memo,
    'delete_memo' => context.t.strings.legacy.msg_delete_memo_2,
    'upload_attachment' => context.t.strings.legacy.msg_upload_attachment,
    'delete_attachment' => context.tr(
        zh: '\u5220\u9664\u9644\u4ef6',
        en: 'Delete attachment',
      ),
    _ => context.t.strings.legacy.msg_sync_task,
  };
}

class _SyncSummaryCard extends StatelessWidget {
  const _SyncSummaryCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.border,
    required this.pendingCount,
    required this.attentionCount,
    required this.lastSuccessLabel,
    required this.syncing,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final Color border;
  final int pendingCount;
  final int attentionCount;
  final String lastSuccessLabel;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusText = syncing
        ? MemoFlowPalette.primary
        : textMuted.withValues(alpha: 0.9);
    final statusLabel = syncing
        ? context.t.strings.legacy.msg_syncing_2
        : context.t.strings.legacy.msg_idle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.t.strings.legacy.msg_sync_overview,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
              const Spacer(),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: statusText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  value: '$pendingCount',
                  label: context.t.strings.legacy.msg_pending_2,
                  textMain: textMain,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryMetric(
                  value: '$attentionCount',
                  label: context.tr(zh: '需处理', en: 'Attention'),
                  textMain: textMain,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t.strings.legacy.msg_last_success,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lastSuccessLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.textMain,
    required this.textMuted,
  });

  final String value;
  final String label;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: textMuted.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyQueueCard extends StatelessWidget {
  const _EmptyQueueCard({required this.card, required this.textMuted});

  final Color card;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textMuted.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t.strings.legacy.msg_no_pending_sync_tasks,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncQueueItemCard extends StatelessWidget {
  const _SyncQueueItemCard({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.card,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.activeOutboxId,
    required this.activeProgress,
    required this.actionLabel,
    required this.onDelete,
    this.onOpenMemo,
    required this.onSync,
  });

  final SyncQueueItem item;
  final String title;
  final String? subtitle;
  final Color card;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final int? activeOutboxId;
  final double? activeProgress;
  final String actionLabel;
  final VoidCallback onDelete;
  final VoidCallback? onOpenMemo;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsAttention = item.needsAttention;
    final active = !needsAttention && activeOutboxId == item.id;
    final timeLabel = DateFormat('MM-dd HH:mm:ss.SSS').format(item.createdAt);
    final lastErrorText = _friendlyFailureText(context, item);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  color: Colors.black.withValues(alpha: 0.04),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusChip(
                state: item.state,
                attempts: item.attempts,
                textMuted: textMuted,
                active: active,
                progress: active ? activeProgress : null,
                retryAt: item.retryAt,
              ),
            ],
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
          ],
          if (needsAttention &&
              lastErrorText != null &&
              lastErrorText.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lastErrorText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MemoFlowPalette.primary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: textMuted),
              const SizedBox(width: 6),
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              const Spacer(),
              if (onOpenMemo != null)
                IconButton(
                  tooltip: context.tr(zh: '打开笔记', en: 'Open memo'),
                  onPressed: onOpenMemo,
                  icon: Icon(Icons.open_in_new, color: textMuted),
                ),
              IconButton(
                tooltip: context.t.strings.legacy.msg_delete,
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: textMuted),
              ),
              OutlinedButton(
                onPressed: onSync,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  side: BorderSide(
                    color: MemoFlowPalette.primary.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MemoFlowPalette.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.state,
    required this.attempts,
    required this.textMuted,
    required this.active,
    required this.progress,
    required this.retryAt,
  });

  final int state;
  final int attempts;
  final Color textMuted;
  final bool active;
  final double? progress;
  final DateTime? retryAt;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final failed = state == SyncQueueOutboxState.error;
    final quarantined = state == SyncQueueOutboxState.quarantined;
    final retrying = state == SyncQueueOutboxState.retry;
    if (failed || quarantined) {
      final failedLabel = attempts > 0
          ? context.tr(
              zh: '需处理($attempts)',
              en: 'Review ($attempts)',
            )
          : context.tr(zh: '需处理', en: 'Review');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MemoFlowPalette.primary.withValues(
            alpha: isDark ? 0.25 : 0.15,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          failedLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: MemoFlowPalette.primary,
          ),
        ),
      );
    }

    if (retrying && !active) {
      final now = DateTime.now();
      final waiting = retryAt != null && retryAt!.isAfter(now);
      final retryLabel = waiting
          ? context.t.strings.legacy.msg_retry
          : context.t.strings.legacy.msg_pending_2;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          retryLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: MemoFlowPalette.primary,
          ),
        ),
      );
    }

    final clamped = progress?.clamp(0.0, 1.0).toDouble();
    final indicatorValue = active ? clamped : 0.0;
    final label = active
        ? (clamped == null
              ? context.t.strings.legacy.msg_syncing_2
              : (clamped >= 1.0
                    ? context.t.strings.legacy.msg_done
                    : '${(clamped * 100).round()}%'))
        : context.t.strings.legacy.msg_pending_2;
    final baseBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final fill = MemoFlowPalette.primary.withValues(
      alpha: isDark ? 0.78 : 0.72,
    );
    final labelColor = active && clamped != null ? Colors.white : textMuted;

    return SizedBox(
      width: 86,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          alignment: Alignment.center,
          children: [
            LinearProgressIndicator(
              value: indicatorValue,
              minHeight: 22,
              backgroundColor: baseBg,
              valueColor: AlwaysStoppedAnimation<Color>(fill),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
