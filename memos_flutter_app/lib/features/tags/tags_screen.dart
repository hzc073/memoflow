import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/memos_providers.dart';
import '../about/about_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagStatsProvider);

    return WillPopScope(
      onWillPop: () async {
        _backToAllMemos(context);
        return false;
      },
      child: Scaffold(
      drawer: AppDrawer(
        selected: AppDrawerDestination.tags,
        onSelect: (d) => _navigate(context, d),
        onSelectTag: (t) => _openTag(context, t),
        onOpenNotifications: () => _openNotifications(context),
      ),
      appBar: AppBar(title: const Text('标签')),
      body: tagsAsync.when(
        data: (tags) => tags.isEmpty
            ? const Center(child: Text('暂无标签'))
            : ListView.separated(
                itemBuilder: (context, index) {
                  final t = tags[index];
                  return ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text('#${t.tag}'),
                    trailing: Text('${t.count}'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MemosListScreen(
                            title: '标签',
                            state: 'NORMAL',
                            tag: t.tag,
                            showDrawer: true,
                          ),
                        ),
                      );
                    },
                  );
                },
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemCount: tags.length,
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    ));
  }
}
