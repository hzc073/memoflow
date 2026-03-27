import '../../core/app_localization.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/theme_colors.dart';
import 'memo_toolbar_preferences.dart';

enum AppLanguage {
  system('legacy.app_language.system'),
  zhHans('legacy.app_language.zh_hans'),
  zhHantTw('legacy.app_language.zh_hant_tw'),
  en('legacy.app_language.en'),
  ja('legacy.app_language.ja'),
  de('legacy.app_language.de');

  const AppLanguage(this.labelKey);
  final String labelKey;

  String labelFor(AppLanguage current) {
    return trByLanguageKey(language: current, key: labelKey);
  }
}

enum AppThemeMode {
  system('legacy.app_theme.system'),
  light('legacy.app_theme.light'),
  dark('legacy.app_theme.dark');

  const AppThemeMode(this.labelKey);
  final String labelKey;

  String labelFor(AppLanguage current) {
    return trByLanguageKey(language: current, key: labelKey);
  }
}

enum AppFontSize {
  standard('legacy.app_font_size.standard'),
  large('legacy.app_font_size.large'),
  small('legacy.app_font_size.small');

  const AppFontSize(this.labelKey);
  final String labelKey;

  String labelFor(AppLanguage current) {
    return trByLanguageKey(language: current, key: labelKey);
  }
}

enum AppLineHeight {
  classic('legacy.app_line_height.classic'),
  compact('legacy.app_line_height.compact'),
  relaxed('legacy.app_line_height.relaxed');

  const AppLineHeight(this.labelKey);
  final String labelKey;

  String labelFor(AppLanguage current) {
    return trByLanguageKey(language: current, key: labelKey);
  }
}

enum LaunchAction {
  none('legacy.launch_action.none'),
  sync('legacy.launch_action.sync'),
  quickInput('legacy.launch_action.quick_input'),
  explore('legacy.msg_explore'),
  dailyReview('legacy.launch_action.daily_review');

  const LaunchAction(this.labelKey);
  final String labelKey;

  String labelFor(AppLanguage current) {
    return trByLanguageKey(language: current, key: labelKey);
  }
}

enum AppOnboardingMode { local, server }

class AppPreferences {
  static const Object _unset = Object();
  static final defaults = AppPreferences(
    language: AppLanguage.system,
    hasSelectedLanguage: false,
    onboardingMode: null,
    homeInitialLoadingOverlayShown: false,
    fontSize: AppFontSize.standard,
    lineHeight: AppLineHeight.classic,
    fontFamily: null,
    fontFile: null,
    collapseLongContent: true,
    collapseReferences: true,
    showEngagementInAllMemoDetails: false,
    launchAction: LaunchAction.none,
    autoSyncOnStartAndResume: true,
    quickInputAutoFocus: true,
    confirmExitOnBack: true,
    hapticsEnabled: true,
    useLegacyApi: true,
    networkLoggingEnabled: true,
    themeMode: AppThemeMode.system,
    themeColor: AppThemeColor.brickRed,
    customTheme: CustomThemeSettings.defaults,
    accountThemeColors: {},
    accountCustomThemes: {},
    showDrawerExplore: true,
    showDrawerDailyReview: true,
    showDrawerAiSummary: true,
    showDrawerResources: true,
    showDrawerArchive: true,
    aiSummaryAllowPrivateMemos: false,
    thirdPartyShareEnabled: false,
    windowsCloseToTray: true,
    memoToolbarPreferences: MemoToolbarPreferences.defaults,
    desktopShortcutBindings: desktopShortcutDefaultBindings,
    lastSeenAppVersion: '',
    skippedUpdateVersion: '',
    lastSeenAnnouncementVersion: '',
    lastSeenAnnouncementId: 0,
    lastSeenNoticeHash: '',
  );

  static AppPreferences defaultsForLanguage(AppLanguage language) {
    return AppPreferences.defaults.copyWith(
      language: language,
      hasSelectedLanguage: true,
      onboardingMode: null,
    );
  }

  const AppPreferences({
    required this.language,
    required this.hasSelectedLanguage,
    required this.onboardingMode,
    required this.homeInitialLoadingOverlayShown,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.fontFile,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.showEngagementInAllMemoDetails,
    required this.launchAction,
    required this.autoSyncOnStartAndResume,
    required this.quickInputAutoFocus,
    required this.confirmExitOnBack,
    required this.hapticsEnabled,
    required this.useLegacyApi,
    required this.networkLoggingEnabled,
    required this.themeMode,
    required this.themeColor,
    required this.customTheme,
    required this.accountThemeColors,
    required this.accountCustomThemes,
    required this.showDrawerExplore,
    required this.showDrawerDailyReview,
    required this.showDrawerAiSummary,
    required this.showDrawerResources,
    required this.showDrawerArchive,
    required this.aiSummaryAllowPrivateMemos,
    required this.thirdPartyShareEnabled,
    required this.windowsCloseToTray,
    required this.memoToolbarPreferences,
    required this.desktopShortcutBindings,
    required this.lastSeenAppVersion,
    required this.skippedUpdateVersion,
    required this.lastSeenAnnouncementVersion,
    required this.lastSeenAnnouncementId,
    required this.lastSeenNoticeHash,
  });

  final AppLanguage language;
  final bool hasSelectedLanguage;
  final AppOnboardingMode? onboardingMode;
  final bool homeInitialLoadingOverlayShown;
  final AppFontSize fontSize;
  final AppLineHeight lineHeight;
  final String? fontFamily;
  final String? fontFile;
  final bool collapseLongContent;
  final bool collapseReferences;
  final bool showEngagementInAllMemoDetails;
  final LaunchAction launchAction;
  final bool autoSyncOnStartAndResume;
  final bool quickInputAutoFocus;
  final bool confirmExitOnBack;
  final bool hapticsEnabled;
  final bool useLegacyApi;
  final bool networkLoggingEnabled;
  final AppThemeMode themeMode;
  final AppThemeColor themeColor;
  final CustomThemeSettings customTheme;
  final Map<String, AppThemeColor> accountThemeColors;
  final Map<String, CustomThemeSettings> accountCustomThemes;
  final bool showDrawerExplore;
  final bool showDrawerDailyReview;
  final bool showDrawerAiSummary;
  final bool showDrawerResources;
  final bool showDrawerArchive;
  final bool aiSummaryAllowPrivateMemos;
  final bool thirdPartyShareEnabled;
  final bool windowsCloseToTray;
  final MemoToolbarPreferences memoToolbarPreferences;
  final Map<DesktopShortcutAction, DesktopShortcutBinding>
  desktopShortcutBindings;
  final String lastSeenAppVersion;
  final String skippedUpdateVersion;
  final String lastSeenAnnouncementVersion;
  final int lastSeenAnnouncementId;
  final String lastSeenNoticeHash;

  AppThemeColor resolveThemeColor(String? accountKey) {
    if (accountKey != null) {
      final stored = accountThemeColors[accountKey];
      if (stored != null) return stored;
    }
    return themeColor;
  }

  CustomThemeSettings resolveCustomTheme(String? accountKey) {
    if (accountKey != null) {
      final stored = accountCustomThemes[accountKey];
      if (stored != null) return stored;
    }
    return customTheme;
  }

  Map<String, dynamic> toJson() => {
    'language': language.name,
    'hasSelectedLanguage': hasSelectedLanguage,
    'onboardingMode': onboardingMode?.name,
    'homeInitialLoadingOverlayShown': homeInitialLoadingOverlayShown,
    'fontSize': fontSize.name,
    'lineHeight': lineHeight.name,
    'fontFamily': fontFamily,
    'fontFile': fontFile,
    'collapseLongContent': collapseLongContent,
    'collapseReferences': collapseReferences,
    'showEngagementInAllMemoDetails': showEngagementInAllMemoDetails,
    'launchAction': launchAction.name,
    'autoSyncOnStartAndResume': autoSyncOnStartAndResume,
    'quickInputAutoFocus': quickInputAutoFocus,
    'confirmExitOnBack': confirmExitOnBack,
    'hapticsEnabled': hapticsEnabled,
    'useLegacyApi': useLegacyApi,
    'networkLoggingEnabled': networkLoggingEnabled,
    'themeMode': themeMode.name,
    'themeColor': themeColor.name,
    'customTheme': customTheme.toJson(),
    'accountThemeColors': accountThemeColors.map(
      (key, value) => MapEntry(key, value.name),
    ),
    'accountCustomThemes': accountCustomThemes.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'showDrawerExplore': showDrawerExplore,
    'showDrawerDailyReview': showDrawerDailyReview,
    'showDrawerAiSummary': showDrawerAiSummary,
    'showDrawerResources': showDrawerResources,
    'showDrawerArchive': showDrawerArchive,
    'aiSummaryAllowPrivateMemos': aiSummaryAllowPrivateMemos,
    'thirdPartyShareEnabled': thirdPartyShareEnabled,
    'windowsCloseToTray': windowsCloseToTray,
    'memoToolbarPreferences': memoToolbarPreferences.toJson(),
    'desktopShortcutBindings': desktopShortcutBindingsToStorage(
      desktopShortcutBindings,
    ),
    'lastSeenAppVersion': lastSeenAppVersion,
    'skippedUpdateVersion': skippedUpdateVersion,
    'lastSeenAnnouncementVersion': lastSeenAnnouncementVersion,
    'lastSeenAnnouncementId': lastSeenAnnouncementId,
    'lastSeenNoticeHash': lastSeenNoticeHash,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    AppLanguage parseLanguage() {
      final raw = json['language'];
      if (raw is String) {
        return AppLanguage.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppPreferences.defaults.language,
        );
      }
      return AppPreferences.defaults.language;
    }

    bool parseHasSelectedLanguage() {
      if (!json.containsKey('hasSelectedLanguage')) return true;
      final raw = json['hasSelectedLanguage'];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return true;
    }

    bool parseHomeInitialLoadingOverlayShown() {
      if (!json.containsKey('homeInitialLoadingOverlayShown')) {
        // Legacy users already passed first-run home loading in prior versions.
        return parseHasSelectedLanguage();
      }
      final raw = json['homeInitialLoadingOverlayShown'];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return parseHasSelectedLanguage();
    }

    AppOnboardingMode? parseOnboardingMode() {
      final raw = json['onboardingMode'];
      if (raw is String) {
        for (final mode in AppOnboardingMode.values) {
          if (mode.name == raw) return mode;
        }
      }
      return null;
    }

    AppFontSize parseFontSize() {
      final raw = json['fontSize'];
      if (raw is String) {
        return AppFontSize.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppPreferences.defaults.fontSize,
        );
      }
      return AppPreferences.defaults.fontSize;
    }

    AppThemeMode parseThemeMode() {
      final raw = json['themeMode'];
      if (raw is String) {
        return AppThemeMode.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppPreferences.defaults.themeMode,
        );
      }
      return AppPreferences.defaults.themeMode;
    }

    AppThemeColor parseThemeColor() {
      final raw = json['themeColor'];
      if (raw is String) {
        return AppThemeColor.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppPreferences.defaults.themeColor,
        );
      }
      return AppPreferences.defaults.themeColor;
    }

    CustomThemeSettings parseCustomTheme() {
      final raw = json['customTheme'];
      if (raw is Map) {
        return CustomThemeSettings.fromJson(raw.cast<String, dynamic>());
      }
      return AppPreferences.defaults.customTheme;
    }

    Map<String, AppThemeColor> parseAccountThemeColors() {
      final raw = json['accountThemeColors'];
      if (raw is Map) {
        final parsed = <String, AppThemeColor>{};
        raw.forEach((key, value) {
          if (key is String && value is String) {
            final color = AppThemeColor.values.firstWhere(
              (e) => e.name == value,
              orElse: () => AppPreferences.defaults.themeColor,
            );
            parsed[key] = color;
          }
        });
        return parsed;
      }
      return const {};
    }

    Map<String, CustomThemeSettings> parseAccountCustomThemes() {
      final raw = json['accountCustomThemes'];
      if (raw is Map) {
        final parsed = <String, CustomThemeSettings>{};
        raw.forEach((key, value) {
          if (key is String && value is Map) {
            parsed[key] = CustomThemeSettings.fromJson(
              value.cast<String, dynamic>(),
            );
          }
        });
        return parsed;
      }
      return const {};
    }

    AppLineHeight parseLineHeight() {
      final raw = json['lineHeight'];
      if (raw is String) {
        return AppLineHeight.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppPreferences.defaults.lineHeight,
        );
      }
      return AppPreferences.defaults.lineHeight;
    }

    String? parseFontFamily() {
      const legacyMap = <String, String?>{
        'system': null,
        'misans': 'MiSans',
        'harmony': 'HarmonyOS Sans',
        'pingfang': 'PingFang SC',
        'yahei': 'Microsoft YaHei',
        'noto': 'Noto Sans SC',
      };
      final raw = json['fontFamily'];
      if (raw is String) {
        final normalized = raw.trim();
        if (normalized.isEmpty) return null;
        if (legacyMap.containsKey(normalized)) return legacyMap[normalized];
        return normalized;
      }
      final legacy = json['useSystemFont'];
      if (legacy is bool && legacy) {
        return null;
      }
      return null;
    }

    String? parseFontFile() {
      final raw = json['fontFile'];
      if (raw is String) {
        final trimmed = raw.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    LaunchAction parseLaunchAction() {
      final raw = json['launchAction'];
      if (raw is String) {
        return LaunchAction.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppPreferences.defaults.launchAction,
        );
      }
      return AppPreferences.defaults.launchAction;
    }

    bool parseAutoSyncOnStartAndResume(LaunchAction parsedLaunchAction) {
      final raw = json['autoSyncOnStartAndResume'];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      // Backward compatibility: legacy "launchAction=sync" users should keep
      // auto-sync behavior after launch-action decoupling.
      if (parsedLaunchAction == LaunchAction.sync) return true;
      return AppPreferences.defaults.autoSyncOnStartAndResume;
    }

    bool parseBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    String parseLastSeenAppVersion() {
      final raw = json['lastSeenAppVersion'];
      if (raw is String) return raw;
      return '';
    }

    String parseLastSeenAnnouncementVersion() {
      final raw = json['lastSeenAnnouncementVersion'];
      if (raw is String) return raw;
      return '';
    }

    String parseSkippedUpdateVersion() {
      final raw = json['skippedUpdateVersion'];
      if (raw is String) return raw;
      return '';
    }

    String parseLastSeenNoticeHash() {
      final raw = json['lastSeenNoticeHash'];
      if (raw is String) return raw;
      return '';
    }

    int parseLastSeenAnnouncementId() {
      final raw = json['lastSeenAnnouncementId'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    }

    Map<DesktopShortcutAction, DesktopShortcutBinding>
    parseDesktopShortcutBindings() {
      return desktopShortcutBindingsFromStorage(
        json['desktopShortcutBindings'],
      );
    }

    MemoToolbarPreferences parseMemoToolbarPreferences() {
      return MemoToolbarPreferences.fromJson(json['memoToolbarPreferences']);
    }

    final parsedFamily = parseFontFamily();
    final parsedFile = parseFontFile();
    final parsedCustomTheme = parseCustomTheme();
    final parsedAccountThemeColors = parseAccountThemeColors();
    final parsedAccountCustomThemes = parseAccountCustomThemes();
    final parsedMemoToolbarPreferences = parseMemoToolbarPreferences();
    final parsedDesktopShortcutBindings = parseDesktopShortcutBindings();
    final parsedLaunchAction = parseLaunchAction();
    final normalizedLaunchAction = parsedLaunchAction == LaunchAction.sync
        ? LaunchAction.none
        : parsedLaunchAction;
    final parsedAutoSyncOnStartAndResume = parseAutoSyncOnStartAndResume(
      parsedLaunchAction,
    );

    return AppPreferences(
      language: parseLanguage(),
      hasSelectedLanguage: parseHasSelectedLanguage(),
      onboardingMode: parseOnboardingMode(),
      homeInitialLoadingOverlayShown: parseHomeInitialLoadingOverlayShown(),
      fontSize: parseFontSize(),
      lineHeight: parseLineHeight(),
      fontFamily: parsedFamily,
      fontFile: parsedFamily == null ? null : parsedFile,
      collapseLongContent: parseBool(
        'collapseLongContent',
        AppPreferences.defaults.collapseLongContent,
      ),
      collapseReferences: parseBool(
        'collapseReferences',
        AppPreferences.defaults.collapseReferences,
      ),
      showEngagementInAllMemoDetails: parseBool(
        'showEngagementInAllMemoDetails',
        AppPreferences.defaults.showEngagementInAllMemoDetails,
      ),
      launchAction: normalizedLaunchAction,
      autoSyncOnStartAndResume: parsedAutoSyncOnStartAndResume,
      quickInputAutoFocus: parseBool(
        'quickInputAutoFocus',
        AppPreferences.defaults.quickInputAutoFocus,
      ),
      confirmExitOnBack: parseBool(
        'confirmExitOnBack',
        AppPreferences.defaults.confirmExitOnBack,
      ),
      hapticsEnabled: parseBool(
        'hapticsEnabled',
        AppPreferences.defaults.hapticsEnabled,
      ),
      useLegacyApi: parseBool(
        'useLegacyApi',
        AppPreferences.defaults.useLegacyApi,
      ),
      networkLoggingEnabled: parseBool(
        'networkLoggingEnabled',
        AppPreferences.defaults.networkLoggingEnabled,
      ),
      themeMode: parseThemeMode(),
      themeColor: parseThemeColor(),
      customTheme: parsedCustomTheme,
      accountThemeColors: parsedAccountThemeColors,
      accountCustomThemes: parsedAccountCustomThemes,
      showDrawerExplore: parseBool(
        'showDrawerExplore',
        AppPreferences.defaults.showDrawerExplore,
      ),
      showDrawerDailyReview: parseBool(
        'showDrawerDailyReview',
        AppPreferences.defaults.showDrawerDailyReview,
      ),
      showDrawerAiSummary: parseBool(
        'showDrawerAiSummary',
        AppPreferences.defaults.showDrawerAiSummary,
      ),
      showDrawerResources: parseBool(
        'showDrawerResources',
        AppPreferences.defaults.showDrawerResources,
      ),
      showDrawerArchive: parseBool(
        'showDrawerArchive',
        AppPreferences.defaults.showDrawerArchive,
      ),
      aiSummaryAllowPrivateMemos: parseBool(
        'aiSummaryAllowPrivateMemos',
        AppPreferences.defaults.aiSummaryAllowPrivateMemos,
      ),
      thirdPartyShareEnabled: parseBool(
        'thirdPartyShareEnabled',
        AppPreferences.defaults.thirdPartyShareEnabled,
      ),
      windowsCloseToTray: parseBool(
        'windowsCloseToTray',
        AppPreferences.defaults.windowsCloseToTray,
      ),
      memoToolbarPreferences: parsedMemoToolbarPreferences,
      desktopShortcutBindings: parsedDesktopShortcutBindings,
      lastSeenAppVersion: parseLastSeenAppVersion(),
      skippedUpdateVersion: parseSkippedUpdateVersion(),
      lastSeenAnnouncementVersion: parseLastSeenAnnouncementVersion(),
      lastSeenAnnouncementId: parseLastSeenAnnouncementId(),
      lastSeenNoticeHash: parseLastSeenNoticeHash(),
    );
  }

  AppPreferences copyWith({
    AppLanguage? language,
    bool? hasSelectedLanguage,
    Object? onboardingMode = _unset,
    bool? homeInitialLoadingOverlayShown,
    AppFontSize? fontSize,
    AppLineHeight? lineHeight,
    Object? fontFamily = _unset,
    Object? fontFile = _unset,
    bool? collapseLongContent,
    bool? collapseReferences,
    bool? showEngagementInAllMemoDetails,
    LaunchAction? launchAction,
    bool? autoSyncOnStartAndResume,
    bool? quickInputAutoFocus,
    bool? confirmExitOnBack,
    bool? hapticsEnabled,
    bool? useLegacyApi,
    bool? networkLoggingEnabled,
    AppThemeMode? themeMode,
    AppThemeColor? themeColor,
    CustomThemeSettings? customTheme,
    Map<String, AppThemeColor>? accountThemeColors,
    Map<String, CustomThemeSettings>? accountCustomThemes,
    bool? showDrawerExplore,
    bool? showDrawerDailyReview,
    bool? showDrawerAiSummary,
    bool? showDrawerResources,
    bool? showDrawerArchive,
    bool? aiSummaryAllowPrivateMemos,
    bool? thirdPartyShareEnabled,
    bool? windowsCloseToTray,
    MemoToolbarPreferences? memoToolbarPreferences,
    Map<DesktopShortcutAction, DesktopShortcutBinding>? desktopShortcutBindings,
    String? lastSeenAppVersion,
    String? skippedUpdateVersion,
    String? lastSeenAnnouncementVersion,
    int? lastSeenAnnouncementId,
    String? lastSeenNoticeHash,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      hasSelectedLanguage: hasSelectedLanguage ?? this.hasSelectedLanguage,
      onboardingMode: identical(onboardingMode, _unset)
          ? this.onboardingMode
          : onboardingMode as AppOnboardingMode?,
      homeInitialLoadingOverlayShown:
          homeInitialLoadingOverlayShown ?? this.homeInitialLoadingOverlayShown,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      fontFile: identical(fontFile, _unset)
          ? this.fontFile
          : fontFile as String?,
      collapseLongContent: collapseLongContent ?? this.collapseLongContent,
      collapseReferences: collapseReferences ?? this.collapseReferences,
      showEngagementInAllMemoDetails:
          showEngagementInAllMemoDetails ?? this.showEngagementInAllMemoDetails,
      launchAction: launchAction ?? this.launchAction,
      autoSyncOnStartAndResume:
          autoSyncOnStartAndResume ?? this.autoSyncOnStartAndResume,
      quickInputAutoFocus: quickInputAutoFocus ?? this.quickInputAutoFocus,
      confirmExitOnBack: confirmExitOnBack ?? this.confirmExitOnBack,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      useLegacyApi: useLegacyApi ?? this.useLegacyApi,
      networkLoggingEnabled:
          networkLoggingEnabled ?? this.networkLoggingEnabled,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      customTheme: customTheme ?? this.customTheme,
      accountThemeColors: accountThemeColors ?? this.accountThemeColors,
      accountCustomThemes: accountCustomThemes ?? this.accountCustomThemes,
      showDrawerExplore: showDrawerExplore ?? this.showDrawerExplore,
      showDrawerDailyReview:
          showDrawerDailyReview ?? this.showDrawerDailyReview,
      showDrawerAiSummary: showDrawerAiSummary ?? this.showDrawerAiSummary,
      showDrawerResources: showDrawerResources ?? this.showDrawerResources,
      showDrawerArchive: showDrawerArchive ?? this.showDrawerArchive,
      aiSummaryAllowPrivateMemos:
          aiSummaryAllowPrivateMemos ?? this.aiSummaryAllowPrivateMemos,
      thirdPartyShareEnabled:
          thirdPartyShareEnabled ?? this.thirdPartyShareEnabled,
      windowsCloseToTray: windowsCloseToTray ?? this.windowsCloseToTray,
      memoToolbarPreferences:
          memoToolbarPreferences ?? this.memoToolbarPreferences,
      desktopShortcutBindings:
          desktopShortcutBindings ?? this.desktopShortcutBindings,
      lastSeenAppVersion: lastSeenAppVersion ?? this.lastSeenAppVersion,
      skippedUpdateVersion: skippedUpdateVersion ?? this.skippedUpdateVersion,
      lastSeenAnnouncementVersion:
          lastSeenAnnouncementVersion ?? this.lastSeenAnnouncementVersion,
      lastSeenAnnouncementId:
          lastSeenAnnouncementId ?? this.lastSeenAnnouncementId,
      lastSeenNoticeHash: lastSeenNoticeHash ?? this.lastSeenNoticeHash,
    );
  }
}
