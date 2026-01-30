import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_localization.dart';
import '../core/hash.dart';
import '../core/theme_colors.dart';
import 'session_provider.dart';
import 'webdav_sync_trigger_provider.dart';

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
    customTheme: CustomThemeSettings.defaults,
    accountThemeColors: const {},
    accountCustomThemes: const {},
    showDrawerExplore: true,
    showDrawerDailyReview: true,
    showDrawerAiSummary: true,
    showDrawerResources: true,
    aiSummaryAllowPrivateMemos: false,
    supporterCrownEnabled: false,
    thirdPartyShareEnabled: true,
    lastSeenAppVersion: '',
    lastSeenAnnouncementVersion: '',
    lastSeenAnnouncementId: 0,
    lastSeenNoticeHash: '',
  );

  static AppPreferences defaultsForLanguage(AppLanguage language) {
    return AppPreferences.defaults.copyWith(language: language, hasSelectedLanguage: true);
  }

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
    required this.customTheme,
    required this.accountThemeColors,
    required this.accountCustomThemes,
    required this.showDrawerExplore,
    required this.showDrawerDailyReview,
    required this.showDrawerAiSummary,
    required this.showDrawerResources,
    required this.aiSummaryAllowPrivateMemos,
    required this.supporterCrownEnabled,
    required this.thirdPartyShareEnabled,
    required this.lastSeenAppVersion,
    required this.lastSeenAnnouncementVersion,
    required this.lastSeenAnnouncementId,
    required this.lastSeenNoticeHash,
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
  final CustomThemeSettings customTheme;
  final Map<String, AppThemeColor> accountThemeColors;
  final Map<String, CustomThemeSettings> accountCustomThemes;
  final bool showDrawerExplore;
  final bool showDrawerDailyReview;
  final bool showDrawerAiSummary;
  final bool showDrawerResources;
  final bool aiSummaryAllowPrivateMemos;
  final bool supporterCrownEnabled;
  final bool thirdPartyShareEnabled;
  final String lastSeenAppVersion;
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
        'customTheme': customTheme.toJson(),
        'accountThemeColors': accountThemeColors.map((key, value) => MapEntry(key, value.name)),
        'accountCustomThemes': accountCustomThemes.map((key, value) => MapEntry(key, value.toJson())),
        'showDrawerExplore': showDrawerExplore,
        'showDrawerDailyReview': showDrawerDailyReview,
        'showDrawerAiSummary': showDrawerAiSummary,
        'showDrawerResources': showDrawerResources,
        'aiSummaryAllowPrivateMemos': aiSummaryAllowPrivateMemos,
        'supporterCrownEnabled': supporterCrownEnabled,
        'thirdPartyShareEnabled': thirdPartyShareEnabled,
        'lastSeenAppVersion': lastSeenAppVersion,
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
            parsed[key] = CustomThemeSettings.fromJson(value.cast<String, dynamic>());
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

    final parsedFamily = parseFontFamily();
    final parsedFile = parseFontFile();
    final parsedCustomTheme = parseCustomTheme();
    final parsedAccountThemeColors = parseAccountThemeColors();
    final parsedAccountCustomThemes = parseAccountCustomThemes();

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
      customTheme: parsedCustomTheme,
      accountThemeColors: parsedAccountThemeColors,
      accountCustomThemes: parsedAccountCustomThemes,
      showDrawerExplore: parseBool('showDrawerExplore', AppPreferences.defaults.showDrawerExplore),
      showDrawerDailyReview: parseBool('showDrawerDailyReview', AppPreferences.defaults.showDrawerDailyReview),
      showDrawerAiSummary: parseBool('showDrawerAiSummary', AppPreferences.defaults.showDrawerAiSummary),
      showDrawerResources: parseBool('showDrawerResources', AppPreferences.defaults.showDrawerResources),
      aiSummaryAllowPrivateMemos:
          parseBool('aiSummaryAllowPrivateMemos', AppPreferences.defaults.aiSummaryAllowPrivateMemos),
      supporterCrownEnabled:
          parseBool('supporterCrownEnabled', AppPreferences.defaults.supporterCrownEnabled),
      thirdPartyShareEnabled:
          parseBool('thirdPartyShareEnabled', AppPreferences.defaults.thirdPartyShareEnabled),
      lastSeenAppVersion: parseLastSeenAppVersion(),
      lastSeenAnnouncementVersion: parseLastSeenAnnouncementVersion(),
      lastSeenAnnouncementId: parseLastSeenAnnouncementId(),
      lastSeenNoticeHash: parseLastSeenNoticeHash(),
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
    CustomThemeSettings? customTheme,
    Map<String, AppThemeColor>? accountThemeColors,
    Map<String, CustomThemeSettings>? accountCustomThemes,
    bool? showDrawerExplore,
    bool? showDrawerDailyReview,
    bool? showDrawerAiSummary,
    bool? showDrawerResources,
    bool? aiSummaryAllowPrivateMemos,
    bool? supporterCrownEnabled,
    bool? thirdPartyShareEnabled,
    String? lastSeenAppVersion,
    String? lastSeenAnnouncementVersion,
    int? lastSeenAnnouncementId,
    String? lastSeenNoticeHash,
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
      customTheme: customTheme ?? this.customTheme,
      accountThemeColors: accountThemeColors ?? this.accountThemeColors,
      accountCustomThemes: accountCustomThemes ?? this.accountCustomThemes,
      showDrawerExplore: showDrawerExplore ?? this.showDrawerExplore,
      showDrawerDailyReview: showDrawerDailyReview ?? this.showDrawerDailyReview,
      showDrawerAiSummary: showDrawerAiSummary ?? this.showDrawerAiSummary,
      showDrawerResources: showDrawerResources ?? this.showDrawerResources,
      aiSummaryAllowPrivateMemos: aiSummaryAllowPrivateMemos ?? this.aiSummaryAllowPrivateMemos,
      supporterCrownEnabled: supporterCrownEnabled ?? this.supporterCrownEnabled,
      thirdPartyShareEnabled: thirdPartyShareEnabled ?? this.thirdPartyShareEnabled,
      lastSeenAppVersion: lastSeenAppVersion ?? this.lastSeenAppVersion,
      lastSeenAnnouncementVersion: lastSeenAnnouncementVersion ?? this.lastSeenAnnouncementVersion,
      lastSeenAnnouncementId: lastSeenAnnouncementId ?? this.lastSeenAnnouncementId,
      lastSeenNoticeHash: lastSeenNoticeHash ?? this.lastSeenNoticeHash,
    );
  }
}

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((ref) {
  final accountKey = ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  return AppPreferencesRepository(ref.watch(secureStorageProvider), accountKey: accountKey);
});

final appPreferencesLoadedProvider = StateProvider<bool>((ref) => false);

final appPreferencesProvider = StateNotifierProvider<AppPreferencesController, AppPreferences>((ref) {
  final loadedState = ref.read(appPreferencesLoadedProvider.notifier);
  Future.microtask(() => loadedState.state = false);
  return AppPreferencesController(
    ref,
    ref.watch(appPreferencesRepositoryProvider),
    onLoaded: () => loadedState.state = true,
  );
});

class AppPreferencesController extends StateNotifier<AppPreferences> {
  AppPreferencesController(
    this._ref,
    this._repo, {
    void Function()? onLoaded,
  })  : _onLoaded = onLoaded,
        super(AppPreferences.defaults) {
    unawaited(_loadFromStorage());
  }

  final Ref _ref;
  final AppPreferencesRepository _repo;
  final void Function()? _onLoaded;
  Future<void> _writeChain = Future<void>.value();

  Future<void> _loadFromStorage() async {
    final systemLanguage = appLanguageFromLocale(WidgetsBinding.instance.platformDispatcher.locale);
    final stored = await _repo.read(systemLanguage: systemLanguage);
    state = stored;
    _onLoaded?.call();
  }

  void _setAndPersist(AppPreferences next, {bool triggerSync = true}) {
    state = next;
    // Serialize writes to avoid out-of-order persistence overwriting newer prefs.
    _writeChain = _writeChain.then((_) => _repo.write(next));
    if (triggerSync) {
      _ref.read(webDavSyncTriggerProvider.notifier).bump();
    }
  }

  Future<void> setAll(AppPreferences next, {bool triggerSync = true}) async =>
      _setAndPersist(next, triggerSync: triggerSync);

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
  void setThemeColor(AppThemeColor v) => setThemeColorForAccount(accountKey: null, color: v);
  void setThemeColorForAccount({required String? accountKey, required AppThemeColor color}) {
    if (accountKey == null || accountKey.trim().isEmpty) {
      _setAndPersist(state.copyWith(themeColor: color));
      return;
    }
    final next = Map<String, AppThemeColor>.from(state.accountThemeColors);
    next[accountKey] = color;
    _setAndPersist(state.copyWith(accountThemeColors: next));
  }
  void setCustomThemeForAccount({required String? accountKey, required CustomThemeSettings settings}) {
    if (accountKey == null || accountKey.trim().isEmpty) {
      _setAndPersist(state.copyWith(customTheme: settings));
      return;
    }
    final next = Map<String, CustomThemeSettings>.from(state.accountCustomThemes);
    next[accountKey] = settings;
    _setAndPersist(state.copyWith(accountCustomThemes: next));
  }
  void ensureAccountThemeDefaults(String accountKey) {
    final key = accountKey.trim();
    if (key.isEmpty) return;
    final hasThemeColor = state.accountThemeColors.containsKey(key);
    final hasCustomTheme = state.accountCustomThemes.containsKey(key);
    if (hasThemeColor && hasCustomTheme) return;
    final nextThemeColors = Map<String, AppThemeColor>.from(state.accountThemeColors);
    final nextCustomThemes = Map<String, CustomThemeSettings>.from(state.accountCustomThemes);
    if (!hasThemeColor) {
      nextThemeColors[key] = state.themeColor;
    }
    if (!hasCustomTheme) {
      nextCustomThemes[key] = state.customTheme;
    }
    _setAndPersist(
      state.copyWith(
        accountThemeColors: nextThemeColors,
        accountCustomThemes: nextCustomThemes,
      ),
    );
  }
  void setShowDrawerExplore(bool v) => _setAndPersist(state.copyWith(showDrawerExplore: v));
  void setShowDrawerDailyReview(bool v) => _setAndPersist(state.copyWith(showDrawerDailyReview: v));
  void setShowDrawerAiSummary(bool v) => _setAndPersist(state.copyWith(showDrawerAiSummary: v));
  void setShowDrawerResources(bool v) => _setAndPersist(state.copyWith(showDrawerResources: v));
  void setAiSummaryAllowPrivateMemos(bool v) =>
      _setAndPersist(state.copyWith(aiSummaryAllowPrivateMemos: v));
  void setSupporterCrownEnabled(bool v) => _setAndPersist(state.copyWith(supporterCrownEnabled: v));
  void setThirdPartyShareEnabled(bool v) => _setAndPersist(state.copyWith(thirdPartyShareEnabled: v));
  void setLastSeenAppVersion(String v) =>
      _setAndPersist(state.copyWith(lastSeenAppVersion: v), triggerSync: false);
  void setLastSeenAnnouncement({required String version, required int announcementId}) {
    _setAndPersist(
      state.copyWith(
        lastSeenAnnouncementVersion: version,
        lastSeenAnnouncementId: announcementId,
      ),
      triggerSync: false,
    );
  }

  void setLastSeenNoticeHash(String hash) {
    _setAndPersist(
      state.copyWith(lastSeenNoticeHash: hash),
      triggerSync: false,
    );
  }
}

class AppPreferencesRepository {
  AppPreferencesRepository(this._storage, {required String? accountKey}) : _accountKey = accountKey;

  static const _kStatePrefix = 'app_preferences_v2_';
  static const _kDeviceKey = 'app_preferences_device_v1';
  static const _kLegacyKey = 'app_preferences_v1';
  static const _kFallbackFilePrefix = 'memoflow_prefs_';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kStatePrefix$key';
  }

  Future<File?> _fallbackFileForKey(String key) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final safe = fnv1a64Hex(key);
      return File('${dir.path}/$_kFallbackFilePrefix$safe.json');
    } catch (_) {
      return null;
    }
  }

  Future<AppPreferences?> _readFallback(String key) async {
    final file = await _fallbackFileForKey(key);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppPreferences.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeFallback(String key, AppPreferences prefs) async {
    final file = await _fallbackFileForKey(key);
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(prefs.toJson()));
    } catch (_) {}
  }

  Future<void> _deleteFallback(String key) async {
    final file = await _fallbackFileForKey(key);
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<AppPreferences> read({required AppLanguage systemLanguage}) async {
    final storageKey = _storageKey;
    if (storageKey == null) {
      final device = await _readDevice() ?? await _readFallback(_kDeviceKey);
      if (device != null) {
        await _storage.write(key: _kDeviceKey, value: jsonEncode(device.toJson()));
        await _writeFallback(_kDeviceKey, device);
      }
      return device ?? AppPreferences.defaultsForLanguage(systemLanguage);
    }

    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      final legacy = await _readLegacy();
      final device = await _readDevice() ?? await _readFallback(_kDeviceKey);
      if (device != null) {
        await _storage.write(key: _kDeviceKey, value: jsonEncode(device.toJson()));
        await _writeFallback(_kDeviceKey, device);
      }
      if (legacy != null) {
        var normalized = _normalizeLegacyForAccount(legacy);
        if (device != null) {
          normalized = normalized.copyWith(useLegacyApi: device.useLegacyApi);
        }
        await write(normalized);
        return normalized;
      }
      if (device != null) {
        await write(device);
        return device;
      }
      final fallback = await _readFallback(storageKey);
      if (fallback != null) {
        await write(fallback);
        return fallback;
      }
      return AppPreferences.defaultsForLanguage(systemLanguage);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppPreferences.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // Fall through to fallback file.
    }
    final fallback = await _readFallback(storageKey);
    if (fallback != null) {
      await write(fallback);
      return fallback;
    }
    return AppPreferences.defaultsForLanguage(systemLanguage);
  }

  Future<void> write(AppPreferences prefs) async {
    final storageKey = _storageKey;
    if (storageKey == null) {
      await _storage.write(key: _kDeviceKey, value: jsonEncode(prefs.toJson()));
      await _writeFallback(_kDeviceKey, prefs);
      return;
    }
    await _storage.write(key: storageKey, value: jsonEncode(prefs.toJson()));
    await _writeFallback(storageKey, prefs);
  }

  Future<void> clear() async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.delete(key: storageKey);
    await _deleteFallback(storageKey);
  }

  Future<AppPreferences?> _readDevice() async {
    final raw = await _storage.read(key: _kDeviceKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppPreferences.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  Future<AppPreferences?> _readLegacy() async {
    final raw = await _storage.read(key: _kLegacyKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppPreferences.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  AppPreferences _normalizeLegacyForAccount(AppPreferences prefs) {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return prefs;
    final themeColor = prefs.accountThemeColors[key] ?? prefs.themeColor;
    final customTheme = prefs.accountCustomThemes[key] ?? prefs.customTheme;
    return prefs.copyWith(
      themeColor: themeColor,
      customTheme: customTheme,
      accountThemeColors: {key: themeColor},
      accountCustomThemes: {key: customTheme},
    );
  }
}

