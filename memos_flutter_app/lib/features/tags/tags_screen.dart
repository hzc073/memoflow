import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drawer_navigation.dart';
import '../../state/memos_providers.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
import '../memos/recycle_bin_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_queue_screen.dart';
import 'tag_tree.dart';
import '../../i18n/strings.g.dart';

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
    final route = switch (dest) {
      AppDrawerDestination.memos => const MemosListScreen(
        title: 'MemoFlow',
        state: 'NORMAL',
        showDrawer: true,
        enableCompose: true,
      ),
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.explore => const ExploreScreen(),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
        title: context.t.strings.legacy.msg_archive,
        state: 'ARCHIVED',
        showDrawer: true,
      ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.recycleBin => const RecycleBinScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    closeDrawerThenPushReplacement(context, route);
  }

  void _openTag(BuildContext context, String tag) {
    closeDrawerThenPushReplacement(
      context,
      MemosListScreen(
        title: '#$tag',
        state: 'NORMAL',
        tag: tag,
        showDrawer: true,
        enableCompose: true,
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagStatsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
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
        appBar: AppBar(title: Text(context.t.strings.legacy.msg_tags)),
        body: tagsAsync.when(
          data: (tags) => tags.isEmpty
              ? Center(child: Text(context.t.strings.legacy.msg_no_tags_yet))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  children: [
                    TagTreeList(
                      nodes: buildTagTree(tags),
                      onSelect: (tag) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MemosListScreen(
                              title: context.t.strings.legacy.msg_tags,
                              state: 'NORMAL',
                              tag: tag,
                              showDrawer: true,
                            ),
                          ),
                        );
                      },
                      textMain: Theme.of(context).colorScheme.onSurface,
                      textMuted: Theme.of(context).colorScheme.onSurfaceVariant,
                      showCount: true,
                      initiallyExpanded: true,
                    ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(context.t.strings.legacy.msg_failed_load_4(e: e)),
          ),
        ),
      ),
    );
  }
}
