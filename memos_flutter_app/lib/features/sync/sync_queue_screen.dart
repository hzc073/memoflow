import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/db/app_database.dart';
import '../../state/database_provider.dart';
import '../../state/logging_provider.dart';
import '../../state/memos_providers.dart';
import '../memos/memos_list_screen.dart';
import '../../i18n/strings.g.dart';

final _syncQueueProvider = StreamProvider<List<_SyncQueueItem>>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<List<_SyncQueueItem>> load() async {
    final rows = await db.listOutboxPending(limit: 200);
    final items = <_SyncQueueItem>[];
    for (final row in rows) {
      final item = await _buildQueueItem(db, row);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

class _SyncQueueItem {
  const _SyncQueueItem({
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
}

Future<_SyncQueueItem?> _buildQueueItem(
  AppDatabase db,
  Map<String, dynamic> row,
) async {
  final id = row['id'];
  final type = row['type'];
  if (id is! int || type is! String) return null;

  final state = row['state'] as int? ?? 0;
  final attempts = row['attempts'] as int? ?? 0;
  final createdRaw = row['created_time'] as int? ?? 0;
  final createdAt = createdRaw > 0
      ? DateTime.fromMillisecondsSinceEpoch(
          createdRaw > 10000000000 ? createdRaw : createdRaw * 1000,
          isUtc: true,
        ).toLocal()
      : DateTime.now();
  final lastError = row['last_error'] as String?;

  final payload = _decodePayload(row['payload']);
  final memoUid = _extractMemoUid(type, payload);
  final attachmentUid = _extractAttachmentUid(type, payload);
  var content = payload['content'];
  if (content is! String || content.trim().isEmpty) {
    if (memoUid != null && memoUid.trim().isNotEmpty) {
      final memoRow = await db.getMemoByUid(memoUid);
      final memoContent = memoRow?['content'];
      if (memoContent is String && memoContent.trim().isNotEmpty) {
        content = memoContent;
      }
    }
  }

  final preview = _firstNonEmptyLine(content is String ? content : null);
  final filename = payload['filename'] as String?;

  return _SyncQueueItem(
    id: id,
    type: type,
    state: state,
    attempts: attempts,
    createdAt: createdAt,
    preview: preview,
    filename: filename,
    lastError: lastError,
    memoUid: memoUid,
    attachmentUid: attachmentUid,
  );
}

Map<String, dynamic> _decodePayload(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {}
  return const {};
}

String? _extractMemoUid(String type, Map<String, dynamic> payload) {
  return switch (type) {
    'create_memo' ||
    'update_memo' ||
    'delete_memo' => payload['uid'] as String?,
    'upload_attachment' => payload['memo_uid'] as String?,
    _ => null,
  };
}

String? _extractAttachmentUid(String type, Map<String, dynamic> payload) {
  return switch (type) {
    'upload_attachment' => payload['uid'] as String?,
    _ => null,
  };
}

String? _firstNonEmptyLine(String? raw) {
  if (raw == null) return null;
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

Future<void> _removePendingAttachmentFromMemo(
  AppDatabase db, {
  required String memoUid,
  required String attachmentUid,
}) async {
  final trimmedMemoUid = memoUid.trim();
  final trimmedAttachmentUid = attachmentUid.trim();
  if (trimmedMemoUid.isEmpty || trimmedAttachmentUid.isEmpty) return;

  final row = await db.getMemoByUid(trimmedMemoUid);
  final raw = row?['attachments_json'];
  if (raw is! String || raw.trim().isEmpty) return;

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return;
  }
  if (decoded is! List) return;

  final expectedNames = <String>{
    'attachments/$trimmedAttachmentUid',
    'resources/$trimmedAttachmentUid',
  };

  var changed = false;
  final next = <Map<String, dynamic>>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final map = item.cast<String, dynamic>();
    final name = (map['name'] as String?)?.trim() ?? '';
    if (expectedNames.contains(name)) {
      changed = true;
      continue;
    }
    next.add(map);
  }

  if (!changed) return;
  await db.updateMemoAttachmentsJson(
    trimmedMemoUid,
    attachmentsJson: jsonEncode(next),
  );
}

Future<void> _clearMemoSyncErrorIfIdle(AppDatabase db, String memoUid) async {
  final trimmed = memoUid.trim();
  if (trimmed.isEmpty) return;
  final pending = await db.listPendingOutboxMemoUids();
  if (pending.contains(trimmed)) return;
  await db.updateMemoSyncState(trimmed, syncState: 0, lastError: null);
}

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
    _SyncQueueItem item,
  ) async {
    final db = ref.read(databaseProvider);
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
      await db.deleteOutbox(item.id);
      if (item.type == 'upload_attachment' && item.attachmentUid != null) {
        await _removePendingAttachmentFromMemo(
          db,
          memoUid: memoUid,
          attachmentUid: item.attachmentUid!,
        );
      }
      await _clearMemoSyncErrorIfIdle(db, memoUid);
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
    await db.deleteOutbox(item.id);
  }

  Future<void> _syncAll(WidgetRef ref) async {
    await ref.read(syncControllerProvider.notifier).syncNow();
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

    final queueAsync = ref.watch(_syncQueueProvider);
    final items = queueAsync.valueOrNull ?? const <_SyncQueueItem>[];
    final failedCount = items.where((item) => item.state == 2).length;
    final queueProgress = ref.watch(syncQueueProgressTrackerProvider).snapshot;
    final syncing =
        ref.watch(syncControllerProvider).isLoading || queueProgress.syncing;
    final syncSnapshot = ref.watch(syncStatusTrackerProvider).snapshot;
    int? firstPendingId;
    final itemIds = <int>{};
    for (final item in items) {
      itemIds.add(item.id);
      if (firstPendingId == null && item.state != 2) {
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
              onPressed: syncing ? null : () => _syncAll(ref),
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
                  pendingCount: items.length,
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
                        onSync: syncing ? null : () => _syncAll(ref),
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
          child: FilledButton.icon(
            onPressed: (items.isEmpty || syncing) ? null : () => _syncAll(ref),
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
      ),
    );
  }
}

String _resolveItemTitle(BuildContext context, _SyncQueueItem item) {
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

String? _resolveItemSubtitle(_SyncQueueItem item) {
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
    final statusBg = syncing
        ? MemoFlowPalette.primary.withValues(alpha: isDark ? 0.2 : 0.12)
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04));
    final statusText = syncing ? MemoFlowPalette.primary : textMuted;
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusText,
                  ),
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

  final _SyncQueueItem item;
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
    final failed = item.state == 2;
    final active = !failed && activeOutboxId == item.id;
    final timeLabel = DateFormat('MM-dd HH:mm:ss.SSS').format(item.createdAt);

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
                failed: failed,
                attempts: item.attempts,
                textMuted: textMuted,
                active: active,
                progress: active ? activeProgress : null,
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
              item.lastError != null &&
              item.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.lastError!,
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
    required this.failed,
    required this.attempts,
    required this.textMuted,
    required this.active,
    required this.progress,
  });

  final bool failed;
  final int attempts;
  final Color textMuted;
  final bool active;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    final clamped = progress?.clamp(0.0, 1.0).toDouble();
    final indicatorValue = active ? clamped : 0.0;
    final label = active
        ? (clamped == null
              ? context.t.strings.legacy.msg_syncing_2
              : '${(clamped * 100).round()}%')
        : '0%';
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
