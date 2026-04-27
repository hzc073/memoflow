import 'package:flutter/material.dart';

class AppDrawerDestinationItem {
  const AppDrawerDestinationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.showBadge = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;
  final bool showBadge;
}

class AppDrawerQuickActionItem {
  const AppDrawerQuickActionItem({
    required this.id,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.showBadge = false,
  });

  final String id;
  final String label;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool showBadge;
}

class AppDrawerTagItem {
  const AppDrawerTagItem({
    required this.label,
    required this.path,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String path;
  final int count;
  final bool selected;
  final VoidCallback onTap;
}

class AppDrawerStatItem {
  const AppDrawerStatItem({required this.value, required this.label});

  final String value;
  final String label;
}

class AppDrawerStatsModel {
  const AppDrawerStatsModel({this.items = const <AppDrawerStatItem>[]});

  final List<AppDrawerStatItem> items;
}

class AppDrawerModel {
  const AppDrawerModel({
    required this.title,
    required this.selected,
    required this.selectedTagPath,
    required this.destinations,
    required this.quickActions,
    required this.tags,
    required this.stats,
    required this.versionText,
    required this.hasUnreadNotifications,
    required this.isLocalLibraryMode,
  });

  final String title;
  final String selected;
  final String? selectedTagPath;
  final List<AppDrawerDestinationItem> destinations;
  final List<AppDrawerQuickActionItem> quickActions;
  final List<AppDrawerTagItem> tags;
  final AppDrawerStatsModel stats;
  final String versionText;
  final bool hasUnreadNotifications;
  final bool isLocalLibraryMode;
}
