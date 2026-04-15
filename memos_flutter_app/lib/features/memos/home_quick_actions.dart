import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/app_preferences.dart';
import '../../i18n/strings.g.dart';

const List<HomeQuickAction> kHomeQuickActionCandidateOrder = [
  HomeQuickAction.none,
  HomeQuickAction.collections,
  HomeQuickAction.explore,
  HomeQuickAction.dailyReview,
  HomeQuickAction.aiSummary,
  HomeQuickAction.monthlyStats,
  HomeQuickAction.notifications,
  HomeQuickAction.resources,
  HomeQuickAction.archived,
];

const List<HomeQuickAction> kHomeQuickActionSlotDefaults = [
  HomeQuickAction.monthlyStats,
  HomeQuickAction.aiSummary,
  HomeQuickAction.dailyReview,
];

const List<HomeQuickAction> kHomeQuickActionFillOrder = [
  HomeQuickAction.monthlyStats,
  HomeQuickAction.collections,
  HomeQuickAction.aiSummary,
  HomeQuickAction.dailyReview,
  HomeQuickAction.explore,
  HomeQuickAction.notifications,
  HomeQuickAction.resources,
  HomeQuickAction.archived,
];

class HomeQuickActionChipData {
  const HomeQuickActionChipData({
    required this.action,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onPressed,
  });

  final HomeQuickAction action;
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onPressed;
}

bool isHomeQuickActionAvailable(
  HomeQuickAction action, {
  required bool hasAccount,
}) {
  return switch (action) {
    HomeQuickAction.none => true,
    HomeQuickAction.explore || HomeQuickAction.notifications => hasAccount,
    HomeQuickAction.monthlyStats ||
    HomeQuickAction.collections ||
    HomeQuickAction.aiSummary ||
    HomeQuickAction.dailyReview ||
    HomeQuickAction.resources ||
    HomeQuickAction.archived => true,
  };
}

List<HomeQuickAction> resolveHomeQuickActions({
  required HomeQuickAction rawPrimary,
  required HomeQuickAction rawSecondary,
  required HomeQuickAction rawTertiary,
  required bool hasAccount,
}) {
  final rawActions = [rawPrimary, rawSecondary, rawTertiary];
  final resolved = <HomeQuickAction>[];

  for (var index = 0; index < rawActions.length; index++) {
    final rawAction = rawActions[index];
    if (rawAction == HomeQuickAction.none) {
      resolved.add(HomeQuickAction.none);
      continue;
    }

    if (isHomeQuickActionAvailable(rawAction, hasAccount: hasAccount) &&
        !resolved.contains(rawAction)) {
      resolved.add(rawAction);
      continue;
    }

    final fallback = kHomeQuickActionSlotDefaults[index];
    if (isHomeQuickActionAvailable(fallback, hasAccount: hasAccount) &&
        !resolved.contains(fallback)) {
      resolved.add(fallback);
      continue;
    }

    final fillAction = kHomeQuickActionFillOrder.firstWhere(
      (action) =>
          isHomeQuickActionAvailable(action, hasAccount: hasAccount) &&
          !resolved.contains(action),
    );
    resolved.add(fillAction);
  }

  return List<HomeQuickAction>.unmodifiable(resolved);
}

List<HomeQuickAction> buildVisibleHomeQuickActions({required bool hasAccount}) {
  return [
    for (final action in kHomeQuickActionCandidateOrder)
      if (isHomeQuickActionAvailable(action, hasAccount: hasAccount)) action,
  ];
}

bool isHomeQuickActionUsedByOtherSlot({
  required HomeQuickAction action,
  required List<HomeQuickAction> selectedActions,
  required int editingIndex,
}) {
  if (action == HomeQuickAction.none) return false;
  for (var index = 0; index < selectedActions.length; index++) {
    if (index == editingIndex) continue;
    if (selectedActions[index] == action) return true;
  }

  return false;
}

String homeQuickActionLabel(BuildContext context, HomeQuickAction action) {
  return switch (action) {
    HomeQuickAction.none => context.t.strings.legacy.msg_none,
    HomeQuickAction.monthlyStats => context.t.strings.legacy.msg_monthly_stats,
    HomeQuickAction.collections => context.t.strings.collections.drawerLabel,
    HomeQuickAction.aiSummary => context.t.strings.legacy.msg_ai_summary,
    HomeQuickAction.dailyReview => context.t.strings.legacy.msg_random_review,
    HomeQuickAction.explore => context.t.strings.legacy.msg_explore,
    HomeQuickAction.notifications => context.t.strings.legacy.msg_notifications,
    HomeQuickAction.resources => context.t.strings.legacy.msg_attachments,
    HomeQuickAction.archived => context.t.strings.legacy.msg_archive,
  };
}

IconData homeQuickActionIcon(HomeQuickAction action) {
  return switch (action) {
    HomeQuickAction.none => Icons.visibility_off_outlined,
    HomeQuickAction.monthlyStats => Icons.insights,
    HomeQuickAction.collections => Icons.auto_stories_rounded,
    HomeQuickAction.aiSummary => Icons.auto_awesome,
    HomeQuickAction.dailyReview => Icons.explore,
    HomeQuickAction.explore => Icons.public,
    HomeQuickAction.notifications => Icons.notifications_none,
    HomeQuickAction.resources => Icons.attach_file,
    HomeQuickAction.archived => Icons.archive,
  };
}

Color homeQuickActionIconColor(HomeQuickAction action, {required bool isDark}) {
  return switch (action) {
    HomeQuickAction.none =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
    HomeQuickAction.monthlyStats =>
      isDark ? const Color(0xFFFF8A7A) : const Color(0xFFCC5C4C),
    HomeQuickAction.collections =>
      isDark ? const Color(0xFF8EC5FF) : const Color(0xFF2563EB),
    HomeQuickAction.aiSummary =>
      isDark ? MemoFlowPalette.aiChipBlueDark : MemoFlowPalette.aiChipBlueLight,
    HomeQuickAction.dailyReview =>
      isDark
          ? MemoFlowPalette.reviewChipOrangeDark
          : MemoFlowPalette.reviewChipOrangeLight,
    HomeQuickAction.explore =>
      isDark ? const Color(0xFF63D5CF) : const Color(0xFF2F9E9A),
    HomeQuickAction.notifications =>
      isDark ? const Color(0xFFF6B349) : const Color(0xFFD97706),
    HomeQuickAction.resources =>
      isDark ? const Color(0xFF59C98E) : const Color(0xFF2F855A),
    HomeQuickAction.archived =>
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C5ACF),
  };
}

HomeQuickActionChipData buildHomeQuickActionChipData({
  required BuildContext context,
  required HomeQuickAction action,
  required bool isDark,
  required VoidCallback onPressed,
}) {
  return HomeQuickActionChipData(
    action: action,
    icon: homeQuickActionIcon(action),
    label: homeQuickActionLabel(context, action),
    iconColor: homeQuickActionIconColor(action, isDark: isDark),
    onPressed: onPressed,
  );
}
