import 'package:flutter/material.dart';

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
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
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
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _backToAllMemos(context);
        return false;
      },
      child: Scaffold(
      drawer: AppDrawer(
        selected: AppDrawerDestination.about,
        onSelect: (d) => _navigate(context, d),
        onSelectTag: (t) => _openTag(context, t),
        onOpenNotifications: () => _openNotifications(context),
      ),
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('MemoFlow', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '一个面向 Memos 后端的离线优先客户端。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('密码锁'),
            subtitle: Text('计划：进入 App 前的本地锁'),
          ),
          const ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('AI 总结'),
            subtitle: Text('计划：选择范围后生成总结/年终报告'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('离线同步'),
            subtitle: Text('本地库 + Outbox 队列，联网后按顺序同步'),
          ),
        ],
      ),
    ),
    );
  }
}
