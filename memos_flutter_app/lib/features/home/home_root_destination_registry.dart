import 'package:flutter/material.dart';

import '../../data/models/home_navigation_preferences.dart';
import '../../i18n/strings.g.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import 'home_navigation_host.dart';

typedef DebugHomeRootScreenBuilder =
    Widget? Function({
      required BuildContext context,
      required HomeRootDestination destination,
      required HomeScreenPresentation presentation,
      required HomeEmbeddedNavigationHost? navigationHost,
    });

class HomeRootDestinationDefinition {
  const HomeRootDestinationDefinition({
    required this.destination,
    required this.drawerDestination,
    required this.icon,
    required this.labelBuilder,
  });

  final HomeRootDestination destination;
  final AppDrawerDestination drawerDestination;
  final IconData icon;
  final String Function(BuildContext context) labelBuilder;
}

const List<HomeRootDestinationDefinition> kHomeRootDestinationDefinitions = [
  HomeRootDestinationDefinition(
    destination: HomeRootDestination.memos,
    drawerDestination: AppDrawerDestination.memos,
    icon: Icons.notes_rounded,
    labelBuilder: _allMemosLabel,
  ),
  HomeRootDestinationDefinition(
    destination: HomeRootDestination.explore,
    drawerDestination: AppDrawerDestination.explore,
    icon: Icons.public,
    labelBuilder: _exploreLabel,
  ),
  HomeRootDestinationDefinition(
    destination: HomeRootDestination.dailyReview,
    drawerDestination: AppDrawerDestination.dailyReview,
    icon: Icons.explore,
    labelBuilder: _dailyReviewLabel,
  ),
  HomeRootDestinationDefinition(
    destination: HomeRootDestination.settings,
    drawerDestination: AppDrawerDestination.settings,
    icon: Icons.settings_outlined,
    labelBuilder: _settingsLabel,
  ),
  HomeRootDestinationDefinition(
    destination: HomeRootDestination.aiSummary,
    drawerDestination: AppDrawerDestination.aiSummary,
    icon: Icons.auto_awesome,
    labelBuilder: _aiSummaryLabel,
  ),
  HomeRootDestinationDefinition(
    destination: HomeRootDestination.resources,
    drawerDestination: AppDrawerDestination.resources,
    icon: Icons.attach_file,
    labelBuilder: _attachmentsLabel,
  ),
  HomeRootDestinationDefinition(
    destination: HomeRootDestination.archived,
    drawerDestination: AppDrawerDestination.archived,
    icon: Icons.archive_outlined,
    labelBuilder: _archiveLabel,
  ),
];

DebugHomeRootScreenBuilder? debugHomeRootScreenBuilderOverride;

HomeRootDestinationDefinition? homeRootDestinationDefinition(
  HomeRootDestination destination,
) {
  for (final definition in kHomeRootDestinationDefinitions) {
    if (definition.destination == destination) {
      return definition;
    }
  }
  return null;
}

HomeRootDestination? homeRootDestinationFromDrawerDestination(
  AppDrawerDestination destination,
) {
  for (final definition in kHomeRootDestinationDefinitions) {
    if (definition.drawerDestination == destination) {
      return definition.destination;
    }
  }
  return null;
}

Widget buildHomeRootScreen({
  required BuildContext context,
  required HomeRootDestination destination,
  required HomeScreenPresentation presentation,
  required HomeEmbeddedNavigationHost? navigationHost,
}) {
  final debugBuilder = debugHomeRootScreenBuilderOverride;
  if (debugBuilder != null) {
    final debugWidget = debugBuilder(
      context: context,
      destination: destination,
      presentation: presentation,
      navigationHost: navigationHost,
    );
    if (debugWidget != null) {
      return debugWidget;
    }
  }

  switch (destination) {
    case HomeRootDestination.none:
      return const SizedBox.shrink();
    case HomeRootDestination.memos:
      return MemosListScreen(
        title: 'MemoFlow',
        state: 'NORMAL',
        showDrawer: true,
        enableCompose: true,
        enableDesktopResizableHomeInlineCompose: true,
        presentation: presentation,
        embeddedNavigationHost: navigationHost,
        hidePrimaryComposeFab:
            presentation == HomeScreenPresentation.embeddedBottomNav,
      );
    case HomeRootDestination.explore:
      return ExploreScreen(
        presentation: presentation,
        embeddedNavigationHost: navigationHost,
      );
    case HomeRootDestination.dailyReview:
      return DailyReviewScreen(
        presentation: presentation,
        embeddedNavigationHost: navigationHost,
      );
    case HomeRootDestination.settings:
      return SettingsScreen(
        presentation: presentation,
        embeddedNavigationHost: navigationHost,
      );
    case HomeRootDestination.aiSummary:
      return AiSummaryScreen(
        presentation: presentation,
        embeddedNavigationHost: navigationHost,
      );
    case HomeRootDestination.resources:
      return ResourcesScreen(
        presentation: presentation,
        embeddedNavigationHost: navigationHost,
      );
    case HomeRootDestination.archived:
      return MemosListScreen(
        title: context.t.strings.legacy.msg_archive,
        state: 'ARCHIVED',
        showDrawer: true,
        presentation: presentation,
        embeddedNavigationHost: navigationHost,
        hidePrimaryComposeFab:
            presentation == HomeScreenPresentation.embeddedBottomNav,
        enableDrawerOpenDragGesture:
            presentation != HomeScreenPresentation.embeddedBottomNav,
      );
  }
}

String _allMemosLabel(BuildContext context) =>
    context.t.strings.legacy.msg_memos;

String _exploreLabel(BuildContext context) =>
    context.t.strings.legacy.msg_explore;

String _dailyReviewLabel(BuildContext context) =>
    context.t.strings.legacy.msg_random_review;

String _settingsLabel(BuildContext context) =>
    context.t.strings.legacy.msg_settings;

String _aiSummaryLabel(BuildContext context) =>
    context.t.strings.legacy.msg_ai_summary;

String _attachmentsLabel(BuildContext context) =>
    context.t.strings.legacy.msg_attachments;

String _archiveLabel(BuildContext context) =>
    context.t.strings.legacy.msg_archive;
