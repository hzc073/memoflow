import '../../../core/theme_colors.dart';
import '../../../data/models/app_preferences.dart';
import '../../../data/models/memo_toolbar_preferences.dart';

class AppPreferencesTransferPayload {
  const AppPreferencesTransferPayload({
    required this.language,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.fontFile,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.showEngagementInAllMemoDetails,
    required this.confirmExitOnBack,
    required this.hapticsEnabled,
    required this.themeMode,
    required this.themeColor,
    required this.customTheme,
    required this.showDrawerExplore,
    required this.showDrawerDailyReview,
    required this.showDrawerAiSummary,
    required this.showDrawerResources,
    required this.showDrawerArchive,
    required this.aiSummaryAllowPrivateMemos,
    required this.memoToolbarPreferences,
  });

  final AppLanguage language;
  final AppFontSize fontSize;
  final AppLineHeight lineHeight;
  final String? fontFamily;
  final String? fontFile;
  final bool collapseLongContent;
  final bool collapseReferences;
  final bool showEngagementInAllMemoDetails;
  final bool confirmExitOnBack;
  final bool hapticsEnabled;
  final AppThemeMode themeMode;
  final AppThemeColor themeColor;
  final CustomThemeSettings customTheme;
  final bool showDrawerExplore;
  final bool showDrawerDailyReview;
  final bool showDrawerAiSummary;
  final bool showDrawerResources;
  final bool showDrawerArchive;
  final bool aiSummaryAllowPrivateMemos;
  final MemoToolbarPreferences memoToolbarPreferences;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'language': language.name,
    'fontSize': fontSize.name,
    'lineHeight': lineHeight.name,
    'fontFamily': fontFamily,
    'fontFile': fontFile,
    'collapseLongContent': collapseLongContent,
    'collapseReferences': collapseReferences,
    'showEngagementInAllMemoDetails': showEngagementInAllMemoDetails,
    'confirmExitOnBack': confirmExitOnBack,
    'hapticsEnabled': hapticsEnabled,
    'themeMode': themeMode.name,
    'themeColor': themeColor.name,
    'customTheme': customTheme.toJson(),
    'showDrawerExplore': showDrawerExplore,
    'showDrawerDailyReview': showDrawerDailyReview,
    'showDrawerAiSummary': showDrawerAiSummary,
    'showDrawerResources': showDrawerResources,
    'showDrawerArchive': showDrawerArchive,
    'aiSummaryAllowPrivateMemos': aiSummaryAllowPrivateMemos,
    'memoToolbarPreferences': memoToolbarPreferences.toJson(),
  };

  factory AppPreferencesTransferPayload.fromJson(Map<String, dynamic> json) {
    T resolveEnum<T extends Enum>(List<T> values, String key, T fallback) {
      final raw = json[key];
      if (raw is! String) return fallback;
      return values.firstWhere(
        (value) => value.name == raw,
        orElse: () => fallback,
      );
    }

    final rawTheme = json['customTheme'];
    final rawToolbar = json['memoToolbarPreferences'];
    return AppPreferencesTransferPayload(
      language: resolveEnum(
        AppLanguage.values,
        'language',
        AppPreferences.defaults.language,
      ),
      fontSize: resolveEnum(
        AppFontSize.values,
        'fontSize',
        AppPreferences.defaults.fontSize,
      ),
      lineHeight: resolveEnum(
        AppLineHeight.values,
        'lineHeight',
        AppPreferences.defaults.lineHeight,
      ),
      fontFamily: json['fontFamily'] as String?,
      fontFile: json['fontFile'] as String?,
      collapseLongContent:
          (json['collapseLongContent'] as bool?) ??
          AppPreferences.defaults.collapseLongContent,
      collapseReferences:
          (json['collapseReferences'] as bool?) ??
          AppPreferences.defaults.collapseReferences,
      showEngagementInAllMemoDetails:
          (json['showEngagementInAllMemoDetails'] as bool?) ??
          AppPreferences.defaults.showEngagementInAllMemoDetails,
      confirmExitOnBack:
          (json['confirmExitOnBack'] as bool?) ??
          AppPreferences.defaults.confirmExitOnBack,
      hapticsEnabled:
          (json['hapticsEnabled'] as bool?) ??
          AppPreferences.defaults.hapticsEnabled,
      themeMode: resolveEnum(
        AppThemeMode.values,
        'themeMode',
        AppPreferences.defaults.themeMode,
      ),
      themeColor: resolveEnum(
        AppThemeColor.values,
        'themeColor',
        AppPreferences.defaults.themeColor,
      ),
      customTheme: rawTheme is Map
          ? CustomThemeSettings.fromJson(rawTheme.cast<String, dynamic>())
          : AppPreferences.defaults.customTheme,
      showDrawerExplore:
          (json['showDrawerExplore'] as bool?) ??
          AppPreferences.defaults.showDrawerExplore,
      showDrawerDailyReview:
          (json['showDrawerDailyReview'] as bool?) ??
          AppPreferences.defaults.showDrawerDailyReview,
      showDrawerAiSummary:
          (json['showDrawerAiSummary'] as bool?) ??
          AppPreferences.defaults.showDrawerAiSummary,
      showDrawerResources:
          (json['showDrawerResources'] as bool?) ??
          AppPreferences.defaults.showDrawerResources,
      showDrawerArchive:
          (json['showDrawerArchive'] as bool?) ??
          AppPreferences.defaults.showDrawerArchive,
      aiSummaryAllowPrivateMemos:
          (json['aiSummaryAllowPrivateMemos'] as bool?) ??
          AppPreferences.defaults.aiSummaryAllowPrivateMemos,
      memoToolbarPreferences: rawToolbar is Map
          ? MemoToolbarPreferences.fromJson(rawToolbar.cast<String, dynamic>())
          : AppPreferences.defaults.memoToolbarPreferences,
    );
  }
}

class MigrationPreferencesFilter {
  const MigrationPreferencesFilter();

  AppPreferencesTransferPayload extractTransferable(AppPreferences source) {
    return AppPreferencesTransferPayload(
      language: source.language,
      fontSize: source.fontSize,
      lineHeight: source.lineHeight,
      fontFamily: source.fontFamily,
      fontFile: source.fontFile,
      collapseLongContent: source.collapseLongContent,
      collapseReferences: source.collapseReferences,
      showEngagementInAllMemoDetails: source.showEngagementInAllMemoDetails,
      confirmExitOnBack: source.confirmExitOnBack,
      hapticsEnabled: source.hapticsEnabled,
      themeMode: source.themeMode,
      themeColor: source.themeColor,
      customTheme: source.customTheme,
      showDrawerExplore: source.showDrawerExplore,
      showDrawerDailyReview: source.showDrawerDailyReview,
      showDrawerAiSummary: source.showDrawerAiSummary,
      showDrawerResources: source.showDrawerResources,
      showDrawerArchive: source.showDrawerArchive,
      aiSummaryAllowPrivateMemos: source.aiSummaryAllowPrivateMemos,
      memoToolbarPreferences: source.memoToolbarPreferences,
    );
  }

  AppPreferences mergeTransferable(
    AppPreferences current,
    AppPreferencesTransferPayload incoming,
  ) {
    return current.copyWith(
      language: incoming.language,
      fontSize: incoming.fontSize,
      lineHeight: incoming.lineHeight,
      fontFamily: incoming.fontFamily,
      fontFile: incoming.fontFile,
      collapseLongContent: incoming.collapseLongContent,
      collapseReferences: incoming.collapseReferences,
      showEngagementInAllMemoDetails: incoming.showEngagementInAllMemoDetails,
      confirmExitOnBack: incoming.confirmExitOnBack,
      hapticsEnabled: incoming.hapticsEnabled,
      themeMode: incoming.themeMode,
      themeColor: incoming.themeColor,
      customTheme: incoming.customTheme,
      showDrawerExplore: incoming.showDrawerExplore,
      showDrawerDailyReview: incoming.showDrawerDailyReview,
      showDrawerAiSummary: incoming.showDrawerAiSummary,
      showDrawerResources: incoming.showDrawerResources,
      showDrawerArchive: incoming.showDrawerArchive,
      aiSummaryAllowPrivateMemos: incoming.aiSummaryAllowPrivateMemos,
      memoToolbarPreferences: incoming.memoToolbarPreferences,
    );
  }
}
