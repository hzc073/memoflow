import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_provider.dart';

enum AppLanguage {
  zhHans('简体中文'),
  en('English');

  const AppLanguage(this.label);
  final String label;
}

enum AppFontSize {
  standard('标准'),
  large('大'),
  small('小');

  const AppFontSize(this.label);
  final String label;
}

enum AppLineHeight {
  classic('经典'),
  compact('紧凑'),
  relaxed('舒适');

  const AppLineHeight(this.label);
  final String label;
}

enum LaunchAction {
  none('无'),
  sync('同步'),
  dailyReview('随机漫步');

  const LaunchAction(this.label);
  final String label;
}

class AppPreferences {
  static const defaults = AppPreferences(
    language: AppLanguage.zhHans,
    fontSize: AppFontSize.standard,
    lineHeight: AppLineHeight.classic,
    useSystemFont: false,
    collapseLongContent: true,
    collapseReferences: true,
    uploadOriginalImage: false,
    launchAction: LaunchAction.none,
    hapticsEnabled: true,
    useLegacyApi: false,
    networkLoggingEnabled: true,
  );

  const AppPreferences({
    required this.language,
    required this.fontSize,
    required this.lineHeight,
    required this.useSystemFont,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.uploadOriginalImage,
    required this.launchAction,
    required this.hapticsEnabled,
    required this.useLegacyApi,
    required this.networkLoggingEnabled,
  });

  final AppLanguage language;
  final AppFontSize fontSize;
  final AppLineHeight lineHeight;
  final bool useSystemFont;
  final bool collapseLongContent;
  final bool collapseReferences;
  final bool uploadOriginalImage;
  final LaunchAction launchAction;
  final bool hapticsEnabled;
  final bool useLegacyApi;
  final bool networkLoggingEnabled;

  Map<String, dynamic> toJson() => {
        'language': language.name,
        'fontSize': fontSize.name,
        'lineHeight': lineHeight.name,
        'useSystemFont': useSystemFont,
        'collapseLongContent': collapseLongContent,
        'collapseReferences': collapseReferences,
        'uploadOriginalImage': uploadOriginalImage,
        'launchAction': launchAction.name,
        'hapticsEnabled': hapticsEnabled,
        'useLegacyApi': useLegacyApi,
        'networkLoggingEnabled': networkLoggingEnabled,
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

    return AppPreferences(
      language: parseLanguage(),
      fontSize: parseFontSize(),
      lineHeight: parseLineHeight(),
      useSystemFont: parseBool('useSystemFont', AppPreferences.defaults.useSystemFont),
      collapseLongContent: parseBool('collapseLongContent', AppPreferences.defaults.collapseLongContent),
      collapseReferences: parseBool('collapseReferences', AppPreferences.defaults.collapseReferences),
      uploadOriginalImage: parseBool('uploadOriginalImage', AppPreferences.defaults.uploadOriginalImage),
      launchAction: parseLaunchAction(),
      hapticsEnabled: parseBool('hapticsEnabled', AppPreferences.defaults.hapticsEnabled),
      useLegacyApi: parseBool('useLegacyApi', AppPreferences.defaults.useLegacyApi),
      networkLoggingEnabled:
          parseBool('networkLoggingEnabled', AppPreferences.defaults.networkLoggingEnabled),
    );
  }

  AppPreferences copyWith({
    AppLanguage? language,
    AppFontSize? fontSize,
    AppLineHeight? lineHeight,
    bool? useSystemFont,
    bool? collapseLongContent,
    bool? collapseReferences,
    bool? uploadOriginalImage,
    LaunchAction? launchAction,
    bool? hapticsEnabled,
    bool? useLegacyApi,
    bool? networkLoggingEnabled,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      useSystemFont: useSystemFont ?? this.useSystemFont,
      collapseLongContent: collapseLongContent ?? this.collapseLongContent,
      collapseReferences: collapseReferences ?? this.collapseReferences,
      uploadOriginalImage: uploadOriginalImage ?? this.uploadOriginalImage,
      launchAction: launchAction ?? this.launchAction,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      useLegacyApi: useLegacyApi ?? this.useLegacyApi,
      networkLoggingEnabled: networkLoggingEnabled ?? this.networkLoggingEnabled,
    );
  }
}

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((ref) {
  return AppPreferencesRepository(ref.watch(secureStorageProvider));
});

final appPreferencesProvider = StateNotifierProvider<AppPreferencesController, AppPreferences>((ref) {
  return AppPreferencesController(ref.watch(appPreferencesRepositoryProvider));
});

class AppPreferencesController extends StateNotifier<AppPreferences> {
  AppPreferencesController(this._repo) : super(AppPreferences.defaults) {
    unawaited(_loadFromStorage());
  }

  final AppPreferencesRepository _repo;

  Future<void> _loadFromStorage() async {
    final stored = await _repo.read();
    state = stored;
  }

  void _setAndPersist(AppPreferences next) {
    state = next;
    unawaited(_repo.write(next));
  }

  void setLanguage(AppLanguage v) => _setAndPersist(state.copyWith(language: v));
  void setFontSize(AppFontSize v) => _setAndPersist(state.copyWith(fontSize: v));
  void setLineHeight(AppLineHeight v) => _setAndPersist(state.copyWith(lineHeight: v));
  void setUseSystemFont(bool v) => _setAndPersist(state.copyWith(useSystemFont: v));
  void setCollapseLongContent(bool v) => _setAndPersist(state.copyWith(collapseLongContent: v));
  void setCollapseReferences(bool v) => _setAndPersist(state.copyWith(collapseReferences: v));
  void setUploadOriginalImage(bool v) => _setAndPersist(state.copyWith(uploadOriginalImage: v));
  void setLaunchAction(LaunchAction v) => _setAndPersist(state.copyWith(launchAction: v));
  void setHapticsEnabled(bool v) => _setAndPersist(state.copyWith(hapticsEnabled: v));
  void setUseLegacyApi(bool v) => _setAndPersist(state.copyWith(useLegacyApi: v));
  void setNetworkLoggingEnabled(bool v) => _setAndPersist(state.copyWith(networkLoggingEnabled: v));
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

