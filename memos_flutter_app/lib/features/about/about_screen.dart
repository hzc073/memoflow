import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _backToAllMemos(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'memoflow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    context.safePop();
    final route = switch (dest) {
      AppDrawerDestination.memos =>
        const MemosListScreen(title: 'memoflow', state: 'NORMAL', showDrawer: true, enableCompose: true),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
          title: context.tr(zh: '回收站', en: 'Archive'),
          state: 'ARCHIVED',
          showDrawer: true,
        ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
  }

  void _openTag(BuildContext context, String tag) {
    context.safePop();
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
    context.safePop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        drawer: AppDrawer(
          selected: AppDrawerDestination.about,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: AppBar(title: Text(context.tr(zh: '关于', en: 'About'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('memoflow', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              context.tr(
                zh: '一个基于 Memos 后端的离线优先客户端。',
                en: 'An offline-first client for the Memos backend.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.tr(zh: '应用锁', en: 'App Lock')),
              subtitle: Text(context.tr(zh: '计划：进入应用前本地锁定', en: 'Plan: local lock before entering the app')),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(context.tr(zh: 'AI 总结', en: 'AI Summary')),
              subtitle: Text(
                context.tr(zh: '计划：按时间范围总结/年报', en: 'Plan: summary/yearly report for selected range'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: Text(context.tr(zh: '离线同步', en: 'Offline Sync')),
              subtitle: Text(
                context.tr(zh: '本地数据库 + 待同步队列，联网后按序同步', en: 'Local DB + outbox queue, sync in order when online'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
