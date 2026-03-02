import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/sync_coordinator_provider.dart';
import '../../state/memo_sync_service.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/sync_feedback.dart';
import '../../core/top_toast.dart';
import '../../state/memoflow_bridge_settings_provider.dart';
import '../../state/memos/sync_queue_controller.dart';
import '../../state/memos/sync_queue_models.dart';
import '../../state/memos/sync_queue_provider.dart';
import '../../state/logging_provider.dart';
import '../../state/preferences_provider.dart';
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
      showTopToast(context, '请先启用同步桥。');
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
            title: const Text('同步到 Obsidian'),
            content: const Text(
              '将当前本地库中的全部 memo（含附件）一次性同步到已配对的 Obsidian，是否继续？',
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
        '同步完成：成功 ${result.succeeded}/${result.total}，失败 ${result.failed}。',
      );
    } catch (e) {
      if (!context.mounted) return;
      showTopToast(context, '同步失败：$e');
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

    final queueAsync = ref.watch(syncQueueItemsProvider);
    final items = queueAsync.valueOrNull ?? const <SyncQueueItem>[];
    final pendingCountAsync = ref.watch(syncQueuePendingCountProvider);
    final failedCount = items
        .where((item) => item.isFailed)
        .length;
    final activeCount = pendingCountAsync.valueOrNull ?? items.length;
    final pendingCount = (activeCount - failedCount) < 0
        ? 0
        : (activeCount - failedCount);
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
    for (final item in items) {
      itemIds.add(item.id);
      if (firstPendingId == null && !item.isFailed) {
        firstPendingId = item.id;
      }
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
        body: queueAsync.when(
          data: (_) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _SyncSummaryCard(
                  card: card,
                  textMain: textMain,
                  textMuted: textMuted,
                  border: border,
                  pendingCount: pendingCount,
                  failedCount: failedCount,
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
                if (items.isEmpty)
                  _EmptyQueueCard(card: card, textMuted: textMuted)
                else
                  ...items.map((item) {
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
                        onDelete: () => _confirmDelete(context, ref, item),
                        onSync: (syncing || bridgeBulkPushing)
                            ? null
                            : () => item.isFailed
                                  ? _retryItem(context, ref, item)
                                  : _syncAll(context, ref),
                      ),
                    );
                  }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              context.t.strings.legacy.msg_failed_load_4(e: e),
              style: TextStyle(color: textMuted),
            ),
          ),
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
                    bridgeBulkPushing ? '同步到 Obsidian 中...' : '同步到 Obsidian',
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
                  onPressed: (items.isEmpty || syncing || bridgeBulkPushing)
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

String _actionLabel(BuildContext context, String type) {
  return switch (type) {
    'create_memo' => context.t.strings.legacy.msg_create_memo,
    'update_memo' => context.t.strings.legacy.msg_update_memo,
    'delete_memo' => context.t.strings.legacy.msg_delete_memo_2,
    'upload_attachment' => context.t.strings.legacy.msg_upload_attachment,
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
    required this.failedCount,
    required this.lastSuccessLabel,
    required this.syncing,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final Color border;
  final int pendingCount;
  final int failedCount;
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
                  value: '$failedCount',
                  label: context.t.strings.legacy.msg_failed,
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
    required this.onDelete,
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
  final VoidCallback onDelete;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final failed = item.isFailed;
    final active = !failed && activeOutboxId == item.id;
    final timeLabel = DateFormat('MM-dd HH:mm:ss.SSS').format(item.createdAt);
    final lastErrorText = item.lastError == null
        ? null
        : presentSyncErrorText(
            language: context.appLanguage,
            raw: item.lastError!.trim(),
          );

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
          if (failed &&
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
                  context.t.strings.legacy.msg_sync,
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
    final retrying = state == SyncQueueOutboxState.retry;
    if (failed) {
      final failedLabel = attempts > 0
          ? context.t.strings.legacy.msg_failed_2(attempts: attempts)
          : context.t.strings.legacy.msg_failed;
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
