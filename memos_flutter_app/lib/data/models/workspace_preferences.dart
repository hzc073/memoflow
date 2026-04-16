import 'dart:convert';

import '../../core/tag_list_mode.dart';
import '../../core/theme_colors.dart';
import 'app_preferences.dart';
import 'home_navigation_preferences.dart';
import 'memo_toolbar_preferences.dart';

class WorkspacePreferences {
  static const Object _unset = Object();

  static final WorkspacePreferences defaults = WorkspacePreferences(
    collapseLongContent: true,
    collapseReferences: true,
    showEngagementInAllMemoDetails: false,
    autoSyncOnStartAndResume: true,
    defaultUseLegacyApi: true,
    showDrawerExplore: true,
    showDrawerDailyReview: true,
    showDrawerAiSummary: true,
    showDrawerCollections: true,
    showDrawerResources: true,
    showDrawerArchive: true,
    tagListMode: TagListMode.all,
    homeQuickActionPrimary: HomeQuickAction.monthlyStats,
    homeQuickActionSecondary: HomeQuickAction.aiSummary,
    homeQuickActionTertiary: HomeQuickAction.dailyReview,
    homeNavigationPreferences: HomeNavigationPreferences.defaults,
    aiSummaryAllowPrivateMemos: false,
    memoToolbarPreferences: MemoToolbarPreferences.defaults,
    themeColorOverride: null,
    customThemeOverride: null,
  );

  const WorkspacePreferences({
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.showEngagementInAllMemoDetails,
    required this.autoSyncOnStartAndResume,
    required this.defaultUseLegacyApi,
    required this.showDrawerExplore,
    required this.showDrawerDailyReview,
    required this.showDrawerAiSummary,
    required this.showDrawerCollections,
    required this.showDrawerResources,
    required this.showDrawerArchive,
    required this.tagListMode,
    required this.homeQuickActionPrimary,
    required this.homeQuickActionSecondary,
    required this.homeQuickActionTertiary,
    required this.homeNavigationPreferences,
    required this.aiSummaryAllowPrivateMemos,
    required this.memoToolbarPreferences,
    required this.themeColorOverride,
    required this.customThemeOverride,
  });

  final bool collapseLongContent;
  final bool collapseReferences;
  final bool showEngagementInAllMemoDetails;
  final bool autoSyncOnStartAndResume;
  final bool defaultUseLegacyApi;
  final bool showDrawerExplore;
  final bool showDrawerDailyReview;
  final bool showDrawerAiSummary;
  final bool showDrawerCollections;
  final bool showDrawerResources;
  final bool showDrawerArchive;
  final TagListMode tagListMode;
  final HomeQuickAction homeQuickActionPrimary;
  final HomeQuickAction homeQuickActionSecondary;
  final HomeQuickAction homeQuickActionTertiary;
  final HomeNavigationPreferences homeNavigationPreferences;
  final bool aiSummaryAllowPrivateMemos;
  final MemoToolbarPreferences memoToolbarPreferences;
  final AppThemeColor? themeColorOverride;
  final CustomThemeSettings? customThemeOverride;

  Map<String, dynamic> toJson() => {
    'collapseLongContent': collapseLongContent,
    'collapseReferences': collapseReferences,
    'showEngagementInAllMemoDetails': showEngagementInAllMemoDetails,
    'autoSyncOnStartAndResume': autoSyncOnStartAndResume,
    'defaultUseLegacyApi': defaultUseLegacyApi,
    'showDrawerExplore': showDrawerExplore,
    'showDrawerDailyReview': showDrawerDailyReview,
    'showDrawerAiSummary': showDrawerAiSummary,
    'showDrawerCollections': showDrawerCollections,
    'showDrawerResources': showDrawerResources,
    'showDrawerArchive': showDrawerArchive,
    'tagListMode': tagListMode.name,
    'homeQuickActionPrimary': homeQuickActionPrimary.name,
    'homeQuickActionSecondary': homeQuickActionSecondary.name,
    'homeQuickActionTertiary': homeQuickActionTertiary.name,
    'homeNavigationPreferences': homeNavigationPreferences.toJson(),
    'aiSummaryAllowPrivateMemos': aiSummaryAllowPrivateMemos,
    'memoToolbarPreferences': memoToolbarPreferences.toJson(),
    'themeColorOverride': themeColorOverride?.name,
    'customThemeOverride': customThemeOverride?.toJson(),
  };

  factory WorkspacePreferences.fromJson(Map<String, dynamic> json) {
    final legacy = AppPreferences.fromJson({
      'collapseLongContent': json['collapseLongContent'],
      'collapseReferences': json['collapseReferences'],
      'showEngagementInAllMemoDetails': json['showEngagementInAllMemoDetails'],
      'autoSyncOnStartAndResume': json['autoSyncOnStartAndResume'],
      'useLegacyApi': json['defaultUseLegacyApi'],
      'showDrawerExplore': json['showDrawerExplore'],
      'showDrawerDailyReview': json['showDrawerDailyReview'],
      'showDrawerAiSummary': json['showDrawerAiSummary'],
      'showDrawerCollections': json['showDrawerCollections'],
      'showDrawerResources': json['showDrawerResources'],
      'showDrawerArchive': json['showDrawerArchive'],
      'homeQuickActionPrimary': json['homeQuickActionPrimary'],
      'homeQuickActionSecondary': json['homeQuickActionSecondary'],
      'homeQuickActionTertiary': json['homeQuickActionTertiary'],
      'aiSummaryAllowPrivateMemos': json['aiSummaryAllowPrivateMemos'],
      'memoToolbarPreferences': json['memoToolbarPreferences'],
    });
    final themeColorOverride = () {
      final raw = json['themeColorOverride'];
      if (raw is! String) return null;
      for (final value in AppThemeColor.values) {
        if (value.name == raw) return value;
      }
      return null;
    }();
    final customThemeOverride = () {
      final raw = json['customThemeOverride'];
      if (raw is! Map) return null;
      return CustomThemeSettings.fromJson(raw.cast<String, dynamic>());
    }();
    final homeNavigationPreferences = () {
      final raw = json['homeNavigationPreferences'];
      if (raw is! Map) return HomeNavigationPreferences.defaults;
      return HomeNavigationPreferences.fromJson(raw.cast<String, dynamic>());
    }();
    final tagListMode = TagListMode.fromStorage(json['tagListMode']);
    return WorkspacePreferences.fromLegacy(
      legacy,
      tagListMode: tagListMode,
      themeColorOverride: themeColorOverride,
      customThemeOverride: customThemeOverride,
      homeNavigationPreferences: homeNavigationPreferences,
    );
  }

  factory WorkspacePreferences.fromLegacy(
    AppPreferences legacy, {
    String? workspaceKey,
    TagListMode tagListMode = TagListMode.all,
    AppThemeColor? themeColorOverride,
    CustomThemeSettings? customThemeOverride,
    HomeNavigationPreferences? homeNavigationPreferences,
  }) {
    final key = workspaceKey?.trim();
    final normalizedKey = key == null || key.isEmpty ? null : key;
    return WorkspacePreferences(
      collapseLongContent: legacy.collapseLongContent,
      collapseReferences: legacy.collapseReferences,
      showEngagementInAllMemoDetails: legacy.showEngagementInAllMemoDetails,
      autoSyncOnStartAndResume: legacy.autoSyncOnStartAndResume,
      defaultUseLegacyApi: legacy.useLegacyApi,
      showDrawerExplore: legacy.showDrawerExplore,
      showDrawerDailyReview: legacy.showDrawerDailyReview,
      showDrawerAiSummary: legacy.showDrawerAiSummary,
      showDrawerCollections:
          WorkspacePreferences.defaults.showDrawerCollections,
      showDrawerResources: legacy.showDrawerResources,
      showDrawerArchive: legacy.showDrawerArchive,
      tagListMode: tagListMode,
      homeQuickActionPrimary: legacy.homeQuickActionPrimary,
      homeQuickActionSecondary: legacy.homeQuickActionSecondary,
      homeQuickActionTertiary: legacy.homeQuickActionTertiary,
      homeNavigationPreferences:
          homeNavigationPreferences ?? HomeNavigationPreferences.defaults,
      aiSummaryAllowPrivateMemos: legacy.aiSummaryAllowPrivateMemos,
      memoToolbarPreferences: legacy.memoToolbarPreferences,
      themeColorOverride:
          themeColorOverride ??
          (normalizedKey == null
              ? null
              : legacy.accountThemeColors[normalizedKey]),
      customThemeOverride:
          customThemeOverride ??
          (normalizedKey == null
              ? null
              : legacy.accountCustomThemes[normalizedKey]),
    );
  }

  AppPreferences toLegacyAppPreferences({required String? workspaceKey}) {
    final normalizedKey = workspaceKey?.trim();
    final hasKey = normalizedKey != null && normalizedKey.isNotEmpty;
    return AppPreferences.defaults.copyWith(
      collapseLongContent: collapseLongContent,
      collapseReferences: collapseReferences,
      showEngagementInAllMemoDetails: showEngagementInAllMemoDetails,
      autoSyncOnStartAndResume: autoSyncOnStartAndResume,
      useLegacyApi: defaultUseLegacyApi,
      showDrawerExplore: showDrawerExplore,
      showDrawerDailyReview: showDrawerDailyReview,
      showDrawerAiSummary: showDrawerAiSummary,
      showDrawerResources: showDrawerResources,
      showDrawerArchive: showDrawerArchive,
      homeQuickActionPrimary: homeQuickActionPrimary,
      homeQuickActionSecondary: homeQuickActionSecondary,
      homeQuickActionTertiary: homeQuickActionTertiary,
      aiSummaryAllowPrivateMemos: aiSummaryAllowPrivateMemos,
      memoToolbarPreferences: memoToolbarPreferences,
      accountThemeColors: hasKey && themeColorOverride != null
          ? {normalizedKey: themeColorOverride!}
          : const {},
      accountCustomThemes: hasKey && customThemeOverride != null
          ? {normalizedKey: customThemeOverride!}
          : const {},
    );
  }

  WorkspacePreferences copyWith({
    bool? collapseLongContent,
    bool? collapseReferences,
    bool? showEngagementInAllMemoDetails,
    bool? autoSyncOnStartAndResume,
    bool? defaultUseLegacyApi,
    bool? showDrawerExplore,
    bool? showDrawerDailyReview,
    bool? showDrawerAiSummary,
    bool? showDrawerCollections,
    bool? showDrawerResources,
    bool? showDrawerArchive,
    TagListMode? tagListMode,
    HomeQuickAction? homeQuickActionPrimary,
    HomeQuickAction? homeQuickActionSecondary,
    HomeQuickAction? homeQuickActionTertiary,
    HomeNavigationPreferences? homeNavigationPreferences,
    bool? aiSummaryAllowPrivateMemos,
    MemoToolbarPreferences? memoToolbarPreferences,
    Object? themeColorOverride = _unset,
    Object? customThemeOverride = _unset,
  }) {
    return WorkspacePreferences(
      collapseLongContent: collapseLongContent ?? this.collapseLongContent,
      collapseReferences: collapseReferences ?? this.collapseReferences,
      showEngagementInAllMemoDetails:
          showEngagementInAllMemoDetails ?? this.showEngagementInAllMemoDetails,
      autoSyncOnStartAndResume:
          autoSyncOnStartAndResume ?? this.autoSyncOnStartAndResume,
      defaultUseLegacyApi: defaultUseLegacyApi ?? this.defaultUseLegacyApi,
      showDrawerExplore: showDrawerExplore ?? this.showDrawerExplore,
      showDrawerDailyReview:
          showDrawerDailyReview ?? this.showDrawerDailyReview,
      showDrawerAiSummary: showDrawerAiSummary ?? this.showDrawerAiSummary,
      showDrawerCollections:
          showDrawerCollections ?? this.showDrawerCollections,
      showDrawerResources: showDrawerResources ?? this.showDrawerResources,
      showDrawerArchive: showDrawerArchive ?? this.showDrawerArchive,
      tagListMode: tagListMode ?? this.tagListMode,
      homeQuickActionPrimary:
          homeQuickActionPrimary ?? this.homeQuickActionPrimary,
      homeQuickActionSecondary:
          homeQuickActionSecondary ?? this.homeQuickActionSecondary,
      homeQuickActionTertiary:
          homeQuickActionTertiary ?? this.homeQuickActionTertiary,
      homeNavigationPreferences:
          homeNavigationPreferences ?? this.homeNavigationPreferences,
      aiSummaryAllowPrivateMemos:
          aiSummaryAllowPrivateMemos ?? this.aiSummaryAllowPrivateMemos,
      memoToolbarPreferences:
          memoToolbarPreferences ?? this.memoToolbarPreferences,
      themeColorOverride: identical(themeColorOverride, _unset)
          ? this.themeColorOverride
          : themeColorOverride as AppThemeColor?,
      customThemeOverride: identical(customThemeOverride, _unset)
          ? this.customThemeOverride
          : customThemeOverride as CustomThemeSettings?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspacePreferences &&
        jsonEncode(toJson()) == jsonEncode(other.toJson());
  }

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}
