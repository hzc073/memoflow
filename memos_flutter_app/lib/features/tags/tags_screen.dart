import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagStatsProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        drawer: AppDrawer(
          selected: AppDrawerDestination.tags,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: AppBar(title: Text(context.tr(zh: '标签', en: 'Tags'))),
        body: tagsAsync.when(
          data: (tags) => tags.isEmpty
              ? Center(child: Text(context.tr(zh: '暂无标签', en: 'No tags yet')))
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
                              title: context.tr(zh: '标签', en: 'Tags'),
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
          error: (e, _) => Center(child: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
        ),
      ),
    );
  }
}
