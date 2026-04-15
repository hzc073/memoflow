import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../about/about_screen.dart';
import '../collections/collections_screen.dart';
import '../explore/explore_screen.dart';
import '../memos/memos_list_screen.dart';
import '../memos/recycle_bin_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../tags/tags_screen.dart';
import 'app_drawer.dart';
import 'home_navigation_host.dart';

Widget buildDrawerDestinationScreen({
  required BuildContext context,
  required AppDrawerDestination destination,
  HomeScreenPresentation presentation = HomeScreenPresentation.standalone,
  HomeEmbeddedNavigationHost? navigationHost,
}) {
  return switch (destination) {
    AppDrawerDestination.memos => MemosListScreen(
      title: 'MemoFlow',
      state: 'NORMAL',
      showDrawer: true,
      enableCompose: true,
      presentation: presentation,
      embeddedNavigationHost: navigationHost,
      hidePrimaryComposeFab:
          presentation == HomeScreenPresentation.embeddedBottomNav,
    ),
    AppDrawerDestination.syncQueue => const SyncQueueScreen(),
    AppDrawerDestination.explore => ExploreScreen(
      presentation: presentation,
      embeddedNavigationHost: navigationHost,
    ),
    AppDrawerDestination.dailyReview => DailyReviewScreen(
      presentation: presentation,
      embeddedNavigationHost: navigationHost,
    ),
    AppDrawerDestination.aiSummary => AiSummaryScreen(
      presentation: presentation,
      embeddedNavigationHost: navigationHost,
    ),
    AppDrawerDestination.archived => MemosListScreen(
      title: context.t.strings.legacy.msg_archive,
      state: 'ARCHIVED',
      showDrawer: true,
      enableCompose: false,
      presentation: presentation,
      embeddedNavigationHost: navigationHost,
    ),
    AppDrawerDestination.collections => CollectionsScreen(
      embeddedNavigationHost: navigationHost,
    ),
    AppDrawerDestination.tags => const TagsScreen(),
    AppDrawerDestination.resources => ResourcesScreen(
      presentation: presentation,
      embeddedNavigationHost: navigationHost,
    ),
    AppDrawerDestination.recycleBin => const RecycleBinScreen(),
    AppDrawerDestination.stats => const StatsScreen(),
    AppDrawerDestination.settings => SettingsScreen(
      presentation: presentation,
      embeddedNavigationHost: navigationHost,
    ),
    AppDrawerDestination.about => const AboutScreen(),
  };
}
