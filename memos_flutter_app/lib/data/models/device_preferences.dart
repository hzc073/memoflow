import 'dart:convert';

import '../../core/desktop/shortcuts.dart';
import '../../core/theme_colors.dart';
import 'app_preferences.dart';
import 'collection_reader.dart';

class HomeInlineComposePanelLayoutPreference {
  const HomeInlineComposePanelLayoutPreference({
    required this.width,
    required this.editorHeight,
    required this.xRatio,
    required this.yRatio,
  });

  final double width;
  final double editorHeight;
  final double xRatio;
  final double yRatio;

  Map<String, dynamic> toJson() => {
    'width': width,
    'editorHeight': editorHeight,
    'xRatio': xRatio,
    'yRatio': yRatio,
  };

  static HomeInlineComposePanelLayoutPreference? tryFromJson(
    Map<String, dynamic> json,
  ) {
    double? parseDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      return null;
    }

    final width = parseDouble(json['width']);
    final editorHeight = parseDouble(json['editorHeight']);
    final xRatio = parseDouble(json['xRatio']);
    final yRatio = parseDouble(json['yRatio']);
    if (width == null ||
        editorHeight == null ||
        xRatio == null ||
        yRatio == null) {
      return null;
    }

    return HomeInlineComposePanelLayoutPreference(
      width: width,
      editorHeight: editorHeight,
      xRatio: xRatio.clamp(0, 1).toDouble(),
      yRatio: yRatio.clamp(0, 1).toDouble(),
    );
  }
}

class DevicePreferences {
  static const Object _unset = Object();

  static final defaults = DevicePreferences(
    language: AppLanguage.system,
    hasSelectedLanguage: false,
    onboardingMode: null,
    homeInitialLoadingOverlayShown: false,
    fontSize: AppFontSize.standard,
    lineHeight: AppLineHeight.classic,
    fontFamily: null,
    fontFile: null,
    confirmExitOnBack: true,
    hapticsEnabled: true,
    networkLoggingEnabled: true,
    themeMode: AppThemeMode.system,
    themeColor: AppThemeColor.brickRed,
    customTheme: CustomThemeSettings.defaults,
    launchAction: LaunchAction.none,
    quickInputAutoFocus: true,
    thirdPartyShareEnabled: false,
    windowsCloseToTray: true,
    desktopShortcutBindings: desktopShortcutDefaultBindings,
    lastSeenAppVersion: '',
    acceptedLegalDocumentsHash: '',
    acceptedLegalDocumentsAt: '',
    skippedUpdateVersion: '',
    lastSeenAnnouncementVersion: '',
    lastSeenAnnouncementId: 0,
    lastSeenNoticeHash: '',
    homeInlineComposePanelLayout: null,
    collectionReaderPreferences: CollectionReaderPreferences.defaults,
  );

  static DevicePreferences defaultsForLanguage(AppLanguage language) {
    return defaults.copyWith(
      language: language,
      hasSelectedLanguage: true,
      onboardingMode: null,
    );
  }

  const DevicePreferences({
    required this.language,
    required this.hasSelectedLanguage,
    required this.onboardingMode,
    required this.homeInitialLoadingOverlayShown,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.fontFile,
    required this.confirmExitOnBack,
    required this.hapticsEnabled,
    required this.networkLoggingEnabled,
    required this.themeMode,
    required this.themeColor,
    required this.customTheme,
    required this.launchAction,
    required this.quickInputAutoFocus,
    required this.thirdPartyShareEnabled,
    required this.windowsCloseToTray,
    required this.desktopShortcutBindings,
    required this.lastSeenAppVersion,
    required this.acceptedLegalDocumentsHash,
    required this.acceptedLegalDocumentsAt,
    required this.skippedUpdateVersion,
    required this.lastSeenAnnouncementVersion,
    required this.lastSeenAnnouncementId,
    required this.lastSeenNoticeHash,
    required this.homeInlineComposePanelLayout,
    required this.collectionReaderPreferences,
  });

  final AppLanguage language;
  final bool hasSelectedLanguage;
  final AppOnboardingMode? onboardingMode;
  final bool homeInitialLoadingOverlayShown;
  final AppFontSize fontSize;
  final AppLineHeight lineHeight;
  final String? fontFamily;
  final String? fontFile;
  final bool confirmExitOnBack;
  final bool hapticsEnabled;
  final bool networkLoggingEnabled;
  final AppThemeMode themeMode;
  final AppThemeColor themeColor;
  final CustomThemeSettings customTheme;
  final LaunchAction launchAction;
  final bool quickInputAutoFocus;
  final bool thirdPartyShareEnabled;
  final bool windowsCloseToTray;
  final Map<DesktopShortcutAction, DesktopShortcutBinding>
  desktopShortcutBindings;
  final String lastSeenAppVersion;
  final String acceptedLegalDocumentsHash;
  final String acceptedLegalDocumentsAt;
  final String skippedUpdateVersion;
  final String lastSeenAnnouncementVersion;
  final int lastSeenAnnouncementId;
  final String lastSeenNoticeHash;
  final HomeInlineComposePanelLayoutPreference? homeInlineComposePanelLayout;
  final CollectionReaderPreferences collectionReaderPreferences;

  CollectionReaderMode get collectionReaderMode =>
      collectionReaderPreferences.mode;

  Map<String, dynamic> toJson() => {
    'language': language.name,
    'hasSelectedLanguage': hasSelectedLanguage,
    'onboardingMode': onboardingMode?.name,
    'homeInitialLoadingOverlayShown': homeInitialLoadingOverlayShown,
    'fontSize': fontSize.name,
    'lineHeight': lineHeight.name,
    'fontFamily': fontFamily,
    'fontFile': fontFile,
    'confirmExitOnBack': confirmExitOnBack,
    'hapticsEnabled': hapticsEnabled,
    'networkLoggingEnabled': networkLoggingEnabled,
    'themeMode': themeMode.name,
    'themeColor': themeColor.name,
    'customTheme': customTheme.toJson(),
    'launchAction': launchAction.name,
    'quickInputAutoFocus': quickInputAutoFocus,
    'thirdPartyShareEnabled': thirdPartyShareEnabled,
    'windowsCloseToTray': windowsCloseToTray,
    'desktopShortcutBindings': {
      for (final entry in desktopShortcutBindings.entries)
        entry.key.name: entry.value.toJson(),
    },
    'lastSeenAppVersion': lastSeenAppVersion,
    'acceptedLegalDocumentsHash': acceptedLegalDocumentsHash,
    'acceptedLegalDocumentsAt': acceptedLegalDocumentsAt,
    'skippedUpdateVersion': skippedUpdateVersion,
    'lastSeenAnnouncementVersion': lastSeenAnnouncementVersion,
    'lastSeenAnnouncementId': lastSeenAnnouncementId,
    'lastSeenNoticeHash': lastSeenNoticeHash,
    'homeInlineComposePanelLayout': homeInlineComposePanelLayout?.toJson(),
    'collectionReaderPreferences': collectionReaderPreferences.toJson(),
    'collectionReaderMode': collectionReaderPreferences.mode.name,
  };

  factory DevicePreferences.fromJson(Map<String, dynamic> json) {
    final legacy = AppPreferences.fromJson({
      'language': json['language'],
      'hasSelectedLanguage': json['hasSelectedLanguage'],
      'onboardingMode': json['onboardingMode'],
      'homeInitialLoadingOverlayShown': json['homeInitialLoadingOverlayShown'],
      'fontSize': json['fontSize'],
      'lineHeight': json['lineHeight'],
      'fontFamily': json['fontFamily'],
      'fontFile': json['fontFile'],
      'confirmExitOnBack': json['confirmExitOnBack'],
      'hapticsEnabled': json['hapticsEnabled'],
      'networkLoggingEnabled': json['networkLoggingEnabled'],
      'themeMode': json['themeMode'],
      'themeColor': json['themeColor'],
      'customTheme': json['customTheme'],
      'launchAction': json['launchAction'],
      'quickInputAutoFocus': json['quickInputAutoFocus'],
      'thirdPartyShareEnabled': json['thirdPartyShareEnabled'],
      'windowsCloseToTray': json['windowsCloseToTray'],
      'desktopShortcutBindings': json['desktopShortcutBindings'],
      'lastSeenAppVersion': json['lastSeenAppVersion'],
      'acceptedLegalDocumentsHash': json['acceptedLegalDocumentsHash'],
      'acceptedLegalDocumentsAt': json['acceptedLegalDocumentsAt'],
      'skippedUpdateVersion': json['skippedUpdateVersion'],
      'lastSeenAnnouncementVersion': json['lastSeenAnnouncementVersion'],
      'lastSeenAnnouncementId': json['lastSeenAnnouncementId'],
      'lastSeenNoticeHash': json['lastSeenNoticeHash'],
    });
    final layoutRaw = json['homeInlineComposePanelLayout'];
    final readerPreferencesRaw = json['collectionReaderPreferences'];
    final readerModeRaw = json['collectionReaderMode'];
    return DevicePreferences.fromLegacy(legacy).copyWith(
      homeInlineComposePanelLayout: layoutRaw is Map
          ? HomeInlineComposePanelLayoutPreference.tryFromJson(
              layoutRaw.cast<String, dynamic>(),
            )
          : null,
      collectionReaderPreferences: () {
        if (readerPreferencesRaw is Map) {
          return CollectionReaderPreferences.fromJson(
            readerPreferencesRaw.cast<String, dynamic>(),
          );
        }
        final rawName = (readerModeRaw as String? ?? '').trim();
        for (final mode in CollectionReaderMode.values) {
          if (mode.name == rawName) {
            return CollectionReaderPreferences.defaults.copyWith(mode: mode);
          }
        }
        return DevicePreferences.defaults.collectionReaderPreferences;
      }(),
    );
  }

  factory DevicePreferences.fromLegacy(AppPreferences legacy) {
    return DevicePreferences(
      language: legacy.language,
      hasSelectedLanguage: legacy.hasSelectedLanguage,
      onboardingMode: legacy.onboardingMode,
      homeInitialLoadingOverlayShown: legacy.homeInitialLoadingOverlayShown,
      fontSize: legacy.fontSize,
      lineHeight: legacy.lineHeight,
      fontFamily: legacy.fontFamily,
      fontFile: legacy.fontFile,
      confirmExitOnBack: legacy.confirmExitOnBack,
      hapticsEnabled: legacy.hapticsEnabled,
      networkLoggingEnabled: legacy.networkLoggingEnabled,
      themeMode: legacy.themeMode,
      themeColor: legacy.themeColor,
      customTheme: legacy.customTheme,
      launchAction: legacy.launchAction,
      quickInputAutoFocus: legacy.quickInputAutoFocus,
      thirdPartyShareEnabled: legacy.thirdPartyShareEnabled,
      windowsCloseToTray: legacy.windowsCloseToTray,
      desktopShortcutBindings: legacy.desktopShortcutBindings,
      lastSeenAppVersion: legacy.lastSeenAppVersion,
      acceptedLegalDocumentsHash: legacy.acceptedLegalDocumentsHash,
      acceptedLegalDocumentsAt: legacy.acceptedLegalDocumentsAt,
      skippedUpdateVersion: legacy.skippedUpdateVersion,
      lastSeenAnnouncementVersion: legacy.lastSeenAnnouncementVersion,
      lastSeenAnnouncementId: legacy.lastSeenAnnouncementId,
      lastSeenNoticeHash: legacy.lastSeenNoticeHash,
      homeInlineComposePanelLayout: null,
      collectionReaderPreferences:
          DevicePreferences.defaults.collectionReaderPreferences,
    );
  }

  AppPreferences toLegacyAppPreferences() {
    return AppPreferences.defaults.copyWith(
      language: language,
      hasSelectedLanguage: hasSelectedLanguage,
      onboardingMode: onboardingMode,
      homeInitialLoadingOverlayShown: homeInitialLoadingOverlayShown,
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
      fontFile: fontFile,
      confirmExitOnBack: confirmExitOnBack,
      hapticsEnabled: hapticsEnabled,
      networkLoggingEnabled: networkLoggingEnabled,
      themeMode: themeMode,
      themeColor: themeColor,
      customTheme: customTheme,
      launchAction: launchAction,
      quickInputAutoFocus: quickInputAutoFocus,
      thirdPartyShareEnabled: thirdPartyShareEnabled,
      windowsCloseToTray: windowsCloseToTray,
      desktopShortcutBindings: desktopShortcutBindings,
      lastSeenAppVersion: lastSeenAppVersion,
      acceptedLegalDocumentsHash: acceptedLegalDocumentsHash,
      acceptedLegalDocumentsAt: acceptedLegalDocumentsAt,
      skippedUpdateVersion: skippedUpdateVersion,
      lastSeenAnnouncementVersion: lastSeenAnnouncementVersion,
      lastSeenAnnouncementId: lastSeenAnnouncementId,
      lastSeenNoticeHash: lastSeenNoticeHash,
    );
  }

  DevicePreferences copyWith({
    AppLanguage? language,
    bool? hasSelectedLanguage,
    Object? onboardingMode = _unset,
    bool? homeInitialLoadingOverlayShown,
    AppFontSize? fontSize,
    AppLineHeight? lineHeight,
    Object? fontFamily = _unset,
    Object? fontFile = _unset,
    bool? confirmExitOnBack,
    bool? hapticsEnabled,
    bool? networkLoggingEnabled,
    AppThemeMode? themeMode,
    AppThemeColor? themeColor,
    CustomThemeSettings? customTheme,
    LaunchAction? launchAction,
    bool? quickInputAutoFocus,
    bool? thirdPartyShareEnabled,
    bool? windowsCloseToTray,
    Map<DesktopShortcutAction, DesktopShortcutBinding>? desktopShortcutBindings,
    String? lastSeenAppVersion,
    String? acceptedLegalDocumentsHash,
    String? acceptedLegalDocumentsAt,
    String? skippedUpdateVersion,
    String? lastSeenAnnouncementVersion,
    int? lastSeenAnnouncementId,
    String? lastSeenNoticeHash,
    Object? homeInlineComposePanelLayout = _unset,
    CollectionReaderPreferences? collectionReaderPreferences,
    CollectionReaderMode? collectionReaderMode,
  }) {
    return DevicePreferences(
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
      confirmExitOnBack: confirmExitOnBack ?? this.confirmExitOnBack,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      networkLoggingEnabled:
          networkLoggingEnabled ?? this.networkLoggingEnabled,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      customTheme: customTheme ?? this.customTheme,
      launchAction: launchAction ?? this.launchAction,
      quickInputAutoFocus: quickInputAutoFocus ?? this.quickInputAutoFocus,
      thirdPartyShareEnabled:
          thirdPartyShareEnabled ?? this.thirdPartyShareEnabled,
      windowsCloseToTray: windowsCloseToTray ?? this.windowsCloseToTray,
      desktopShortcutBindings:
          desktopShortcutBindings ?? this.desktopShortcutBindings,
      lastSeenAppVersion: lastSeenAppVersion ?? this.lastSeenAppVersion,
      acceptedLegalDocumentsHash:
          acceptedLegalDocumentsHash ?? this.acceptedLegalDocumentsHash,
      acceptedLegalDocumentsAt:
          acceptedLegalDocumentsAt ?? this.acceptedLegalDocumentsAt,
      skippedUpdateVersion: skippedUpdateVersion ?? this.skippedUpdateVersion,
      lastSeenAnnouncementVersion:
          lastSeenAnnouncementVersion ?? this.lastSeenAnnouncementVersion,
      lastSeenAnnouncementId:
          lastSeenAnnouncementId ?? this.lastSeenAnnouncementId,
      lastSeenNoticeHash: lastSeenNoticeHash ?? this.lastSeenNoticeHash,
      homeInlineComposePanelLayout:
          identical(homeInlineComposePanelLayout, _unset)
          ? this.homeInlineComposePanelLayout
          : homeInlineComposePanelLayout
                as HomeInlineComposePanelLayoutPreference?,
      collectionReaderPreferences:
          collectionReaderPreferences ??
          (collectionReaderMode == null
              ? this.collectionReaderPreferences
              : this.collectionReaderPreferences.copyWith(
                  mode: collectionReaderMode,
                )),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DevicePreferences &&
        jsonEncode(toJson()) == jsonEncode(other.toJson());
  }

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}
