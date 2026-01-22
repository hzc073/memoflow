import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/theme_colors.dart';
import 'session_provider.dart';

enum AppLanguage {
  zhHans('简体中文', 'Chinese (Simplified)'),
  en('English', 'English');

  const AppLanguage(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String labelFor(AppLanguage current) => current == AppLanguage.en ? labelEn : labelZh;
}

enum AppThemeMode {
  system('系统', 'System'),
  light('浅色', 'Light'),
  dark('深色', 'Dark');

  const AppThemeMode(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String labelFor(AppLanguage current) => current == AppLanguage.en ? labelEn : labelZh;
}

enum AppFontSize {
  standard('标准', 'Standard'),
  large('大', 'Large'),
  small('小', 'Small');

  const AppFontSize(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String labelFor(AppLanguage current) => current == AppLanguage.en ? labelEn : labelZh;
}

enum AppLineHeight {
  classic('经典', 'Classic'),
  compact('紧凑', 'Compact'),
  relaxed('舒适', 'Relaxed');

  const AppLineHeight(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String labelFor(AppLanguage current) => current == AppLanguage.en ? labelEn : labelZh;
}

enum LaunchAction {
  none('无', 'None'),
  sync('同步', 'Sync'),
  dailyReview('随机漫步', 'Random Review');

  const LaunchAction(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String labelFor(AppLanguage current) => current == AppLanguage.en ? labelEn : labelZh;
}

class AppPreferences {
  static const Object _unset = Object();
  static const defaults = AppPreferences(
    language: AppLanguage.zhHans,
    hasSelectedLanguage: false,
    fontSize: AppFontSize.standard,
    lineHeight: AppLineHeight.classic,
    fontFamily: null,
    fontFile: null,
    collapseLongContent: true,
    collapseReferences: true,
    launchAction: LaunchAction.none,
    hapticsEnabled: true,
    useLegacyApi: true,
    networkLoggingEnabled: true,
    themeMode: AppThemeMode.system,
    themeColor: AppThemeColor.brickRed,
    showDrawerExplore: true,
    showDrawerDailyReview: true,
    showDrawerAiSummary: true,
    showDrawerResources: true,
  );

  const AppPreferences({
    required this.language,
    required this.hasSelectedLanguage,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.fontFile,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.launchAction,
    required this.hapticsEnabled,
    required this.useLegacyApi,
    required this.networkLoggingEnabled,
    required this.themeMode,
    required this.themeColor,
    required this.showDrawerExplore,
    required this.showDrawerDailyReview,
    required this.showDrawerAiSummary,
    required this.showDrawerResources,
  });

  final AppLanguage language;
  final bool hasSelectedLanguage;
  final AppFontSize fontSize;
  final AppLineHeight lineHeight;
  final String? fontFamily;
  final String? fontFile;
  final bool collapseLongContent;
  final bool collapseReferences;
  final LaunchAction launchAction;
  final bool hapticsEnabled;
  final bool useLegacyApi;
  final bool networkLoggingEnabled;
  final AppThemeMode themeMode;
  final AppThemeColor themeColor;
  final bool showDrawerExplore;
  final bool showDrawerDailyReview;
  final bool showDrawerAiSummary;
  final bool showDrawerResources;

  Map<String, dynamic> toJson() => {
        'language': language.name,
        'hasSelectedLanguage': hasSelectedLanguage,
        'fontSize': fontSize.name,
        'lineHeight': lineHeight.name,
        'fontFamily': fontFamily,
        'fontFile': fontFile,
        'collapseLongContent': collapseLongContent,
        'collapseReferences': collapseReferences,
        'launchAction': launchAction.name,
        'hapticsEnabled': hapticsEnabled,
        'useLegacyApi': useLegacyApi,
        'networkLoggingEnabled': networkLoggingEnabled,
        'themeMode': themeMode.name,
        'themeColor': themeColor.name,
        'showDrawerExplore': showDrawerExplore,
        'showDrawerDailyReview': showDrawerDailyReview,
        'showDrawerAiSummary': showDrawerAiSummary,
        'showDrawerResources': showDrawerResources,
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

    bool parseBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    final parsedFamily = parseFontFamily();
    final parsedFile = parseFontFile();

    return AppPreferences(
      language: parseLanguage(),
      hasSelectedLanguage: parseHasSelectedLanguage(),
      fontSize: parseFontSize(),
      lineHeight: parseLineHeight(),
      fontFamily: parsedFamily,
      fontFile: parsedFamily == null ? null : parsedFile,
      collapseLongContent: parseBool('collapseLongContent', AppPreferences.defaults.collapseLongContent),
      collapseReferences: parseBool('collapseReferences', AppPreferences.defaults.collapseReferences),
      launchAction: parseLaunchAction(),
      hapticsEnabled: parseBool('hapticsEnabled', AppPreferences.defaults.hapticsEnabled),
      useLegacyApi: parseBool('useLegacyApi', AppPreferences.defaults.useLegacyApi),
      networkLoggingEnabled:
          parseBool('networkLoggingEnabled', AppPreferences.defaults.networkLoggingEnabled),
      themeMode: parseThemeMode(),
      themeColor: parseThemeColor(),
      showDrawerExplore: parseBool('showDrawerExplore', AppPreferences.defaults.showDrawerExplore),
      showDrawerDailyReview: parseBool('showDrawerDailyReview', AppPreferences.defaults.showDrawerDailyReview),
      showDrawerAiSummary: parseBool('showDrawerAiSummary', AppPreferences.defaults.showDrawerAiSummary),
      showDrawerResources: parseBool('showDrawerResources', AppPreferences.defaults.showDrawerResources),
    );
  }

  AppPreferences copyWith({
    AppLanguage? language,
    bool? hasSelectedLanguage,
    AppFontSize? fontSize,
    AppLineHeight? lineHeight,
    Object? fontFamily = _unset,
    Object? fontFile = _unset,
    bool? collapseLongContent,
    bool? collapseReferences,
    LaunchAction? launchAction,
    bool? hapticsEnabled,
    bool? useLegacyApi,
    bool? networkLoggingEnabled,
    AppThemeMode? themeMode,
    AppThemeColor? themeColor,
    bool? showDrawerExplore,
    bool? showDrawerDailyReview,
    bool? showDrawerAiSummary,
    bool? showDrawerResources,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      hasSelectedLanguage: hasSelectedLanguage ?? this.hasSelectedLanguage,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: identical(fontFamily, _unset) ? this.fontFamily : fontFamily as String?,
      fontFile: identical(fontFile, _unset) ? this.fontFile : fontFile as String?,
      collapseLongContent: collapseLongContent ?? this.collapseLongContent,
      collapseReferences: collapseReferences ?? this.collapseReferences,
      launchAction: launchAction ?? this.launchAction,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      useLegacyApi: useLegacyApi ?? this.useLegacyApi,
      networkLoggingEnabled: networkLoggingEnabled ?? this.networkLoggingEnabled,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      showDrawerExplore: showDrawerExplore ?? this.showDrawerExplore,
      showDrawerDailyReview: showDrawerDailyReview ?? this.showDrawerDailyReview,
      showDrawerAiSummary: showDrawerAiSummary ?? this.showDrawerAiSummary,
      showDrawerResources: showDrawerResources ?? this.showDrawerResources,
    );
  }
}

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((ref) {
  return AppPreferencesRepository(ref.watch(secureStorageProvider));
});

final appPreferencesLoadedProvider = StateProvider<bool>((ref) => false);

final appPreferencesProvider = StateNotifierProvider<AppPreferencesController, AppPreferences>((ref) {
  final loadedState = ref.read(appPreferencesLoadedProvider.notifier);
  return AppPreferencesController(
    ref.watch(appPreferencesRepositoryProvider),
    onLoaded: () => loadedState.state = true,
  );
});

class AppPreferencesController extends StateNotifier<AppPreferences> {
  AppPreferencesController(
    this._repo, {
    void Function()? onLoaded,
  })  : _onLoaded = onLoaded,
        super(AppPreferences.defaults) {
    unawaited(_loadFromStorage());
  }

  final AppPreferencesRepository _repo;
  final void Function()? _onLoaded;

  Future<void> _loadFromStorage() async {
    final stored = await _repo.read();
    state = stored;
    _onLoaded?.call();
  }

  void _setAndPersist(AppPreferences next) {
    state = next;
    unawaited(_repo.write(next));
  }

  void setLanguage(AppLanguage v) => _setAndPersist(state.copyWith(language: v));
  void setHasSelectedLanguage(bool v) => _setAndPersist(state.copyWith(hasSelectedLanguage: v));
  void setFontSize(AppFontSize v) => _setAndPersist(state.copyWith(fontSize: v));
  void setLineHeight(AppLineHeight v) => _setAndPersist(state.copyWith(lineHeight: v));
  void setFontFamily({String? family, String? filePath}) {
    _setAndPersist(state.copyWith(fontFamily: family, fontFile: filePath));
  }
  void setCollapseLongContent(bool v) => _setAndPersist(state.copyWith(collapseLongContent: v));
  void setCollapseReferences(bool v) => _setAndPersist(state.copyWith(collapseReferences: v));
  void setLaunchAction(LaunchAction v) => _setAndPersist(state.copyWith(launchAction: v));
  void setHapticsEnabled(bool v) => _setAndPersist(state.copyWith(hapticsEnabled: v));
  void setUseLegacyApi(bool v) => _setAndPersist(state.copyWith(useLegacyApi: v));
  void setNetworkLoggingEnabled(bool v) => _setAndPersist(state.copyWith(networkLoggingEnabled: v));
  void setThemeMode(AppThemeMode v) => _setAndPersist(state.copyWith(themeMode: v));
  void setThemeColor(AppThemeColor v) => _setAndPersist(state.copyWith(themeColor: v));
  void setShowDrawerExplore(bool v) => _setAndPersist(state.copyWith(showDrawerExplore: v));
  void setShowDrawerDailyReview(bool v) => _setAndPersist(state.copyWith(showDrawerDailyReview: v));
  void setShowDrawerAiSummary(bool v) => _setAndPersist(state.copyWith(showDrawerAiSummary: v));
  void setShowDrawerResources(bool v) => _setAndPersist(state.copyWith(showDrawerResources: v));
}

class AppPreferencesRepository {
  AppPreferencesRepository(this._storage);

  static const _kStateKey = 'app_preferences_v1';

  final FlutterSecureStorage _storage;

  Future<AppPreferences> read() async {
    final raw = await _storage.read(key: _kStateKey);
    if (raw == null || raw.trim().isEmpty) {
      return AppPreferences.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppPreferences.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return AppPreferences.defaults;
  }

  Future<void> write(AppPreferences prefs) async {
    await _storage.write(key: _kStateKey, value: jsonEncode(prefs.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _kStateKey);
  }
}

