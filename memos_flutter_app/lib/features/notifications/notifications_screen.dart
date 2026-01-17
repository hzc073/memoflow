import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/notification_item.dart';
import '../../state/memos_providers.dart';
import '../../state/notifications_provider.dart';
import '../about/about_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';

enum _NotificationAction {
  markRead,
  delete,
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _backToAllMemos(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
          openDrawerOnStart: true,
        ),
      ),
      (route) => false,
    );
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    Navigator.of(context).pop();
    final route = switch (dest) {
      AppDrawerDestination.memos =>
        const MemosListScreen(title: 'MemoFlow', state: 'NORMAL', showDrawer: true, enableCompose: true),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => const MemosListScreen(title: '回收站', state: 'ARCHIVED', showDrawer: true),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
  }

  void _openTag(BuildContext context, String tag) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MemosListScreen(
          title: '#$tag',
          state: 'NORMAL',
          tag: tag,
          showDrawer: true,
          enableCompose: true,
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return WillPopScope(
      onWillPop: () async {
        _backToAllMemos(context);
        return false;
      },
      child: Scaffold(
        drawer: AppDrawer(
          selected: AppDrawerDestination.memos,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: AppBar(
          title: const Text('通知'),
          leading: IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _backToAllMemos(context),
          ),
        ),
        body: notificationsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('暂无通知'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                final _ = await ref.refresh(notificationsProvider.future);
              },
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final title = _typeLabel(item);
                  final meta = _metaText(item, dateFmt);

                  return ListTile(
                    leading: _NotificationBadge(
                      type: item.type,
                      isUnread: item.isUnread,
                      isDark: isDark,
                    ),
                    title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                    subtitle: Text(meta, style: TextStyle(color: textMuted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusPill(status: item.status, isUnread: item.isUnread, isDark: isDark),
                        const SizedBox(width: 6),
                        PopupMenuButton<_NotificationAction>(
                          tooltip: '操作',
                          onSelected: (action) => _handleAction(context, ref, item, action),
                          itemBuilder: (context) => [
                            if (item.isUnread)
                              const PopupMenuItem(
                                value: _NotificationAction.markRead,
                                child: Text('标为已读'),
                              ),
                            const PopupMenuItem(
                              value: _NotificationAction.delete,
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: item.isUnread ? () => _handleAction(context, ref, item, _NotificationAction.markRead) : null,
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
        ),
      ),
    );
  }

  String _metaText(AppNotification item, DateFormat dateFmt) {
    final parts = <String>[];
    if (item.sender.trim().isNotEmpty) {
      parts.add('来自 ${_shortUserName(item.sender)}');
    }
    parts.add(dateFmt.format(item.createTime.toLocal()));
    return parts.join(' · ');
  }

  String _shortUserName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.contains('/')) return trimmed;
    return trimmed.split('/').last;
  }

  String _typeLabel(AppNotification item) {
    final type = item.type.toUpperCase();
    return switch (type) {
      'MEMO_COMMENT' => '有新的评论',
      'VERSION_UPDATE' => '版本更新',
      _ => '通知',
    };
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
    _NotificationAction action,
  ) async {
    final api = ref.read(memosApiProvider);
    try {
      switch (action) {
        case _NotificationAction.markRead:
          await api.updateNotificationStatus(
            name: item.name,
            status: 'ARCHIVED',
            source: item.source,
          );
          break;
        case _NotificationAction.delete:
          await api.deleteNotification(
            name: item.name,
            source: item.source,
          );
          break;
      }
      ref.invalidate(notificationsProvider);
      if (!context.mounted) return;
      final message = action == _NotificationAction.markRead ? '已标为已读' : '已删除通知';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.isUnread, required this.isDark});

  final String status;
  final bool isUnread;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final base = isUnread ? MemoFlowPalette.primary : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);
    final label = isUnread ? '未读' : (status.isEmpty ? '已读' : '已读');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: base),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({
    required this.type,
    required this.isUnread,
    required this.isDark,
  });

  final String type;
  final bool isUnread;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final normalized = type.toUpperCase();
    final icon = switch (normalized) {
      'MEMO_COMMENT' => Icons.chat_bubble_outline,
      'VERSION_UPDATE' => Icons.system_update_alt,
      _ => Icons.notifications,
    };
    final color = isUnread ? MemoFlowPalette.primary : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isUnread ? 0.18 : 0.12),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
