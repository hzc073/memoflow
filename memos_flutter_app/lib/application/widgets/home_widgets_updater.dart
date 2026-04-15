import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/theme_colors.dart';
import '../../core/url.dart';
import '../../data/db/app_database.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/device_preferences.dart';
import '../../data/models/resolved_app_settings.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../state/system/session_provider.dart';
import 'home_widget_service.dart';
import 'home_widget_snapshot_builder.dart';

class HomeWidgetsUpdater {
  static const Duration _forcedUpdateDebounce = Duration(milliseconds: 350);
  static const Duration _databaseChangeDebounce = Duration(seconds: 2);
  static const Duration _minimumUpdateInterval = Duration(seconds: 8);

  HomeWidgetsUpdater({
    required AppBootstrapAdapter bootstrapAdapter,
    required bool Function() isMounted,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _isMounted = isMounted;

  final AppBootstrapAdapter _bootstrapAdapter;
  final bool Function() _isMounted;

  Timer? _debounceTimer;
  StreamSubscription<void>? _dbChangesSubscription;
  bool _updating = false;
  bool _queued = false;
  bool _queuedForce = false;
  String? _cachedAvatarKey;
  Uint8List? _cachedAvatarBytes;
  DateTime? _lastCompletedUpdateAt;
  String? _appliedDailyReviewSignature;
  String? _appliedQuickInputSignature;
  String? _appliedCalendarSignature;

  bool get _supportsWidgets =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void bindDatabaseChanges(WidgetRef ref) {
    if (!_supportsWidgets || !_isMounted()) return;
    _dbChangesSubscription?.cancel();
    final database = _tryReadDatabase(ref, source: 'bindDatabaseChanges');
    if (database == null) return;
    _dbChangesSubscription = database.changes.listen((_) {
      if (!_isMounted()) return;
      scheduleUpdate(ref);
    });
  }

  void scheduleUpdate(WidgetRef ref, {bool force = false}) {
    if (!_supportsWidgets || !_isMounted()) return;
    _queuedForce = _queuedForce || force;
    _scheduleDeferredUpdate(
      ref,
      delay: _queuedForce ? _forcedUpdateDebounce : _databaseChangeDebounce,
    );
  }

  Future<void> updateIfNeeded(WidgetRef ref, {bool force = false}) async {
    if (!_supportsWidgets || !_isMounted()) return;
    if (_updating) {
      _queued = true;
      _queuedForce = _queuedForce || force;
      return;
    }
    if (!force) {
      final lastCompletedUpdateAt = _lastCompletedUpdateAt;
      if (lastCompletedUpdateAt != null) {
        final elapsed = DateTime.now().difference(lastCompletedUpdateAt);
        if (elapsed < _minimumUpdateInterval) {
          _scheduleDeferredUpdate(ref, delay: _minimumUpdateInterval - elapsed);
          return;
        }
      }
    }

    _updating = true;
    try {
      if (!_hasActiveWorkspace(ref)) {
        await _clearWidgets();
        return;
      }
      final memoRows = await _loadNormalMemoRows(ref);
      if (!_isMounted()) return;
      await _updateDailyReviewWidget(ref, rows: memoRows);
      await _updateQuickInputWidget(ref);
      await _updateCalendarWidget(ref, rows: memoRows);
    } catch (error, stackTrace) {
      debugPrint('[HomeWidgetsUpdater] update failed: $error');
      debugPrint('$stackTrace');
      // Ignore widget refresh failures to keep app startup resilient.
    } finally {
      _lastCompletedUpdateAt = DateTime.now();
      _updating = false;
      if (_isMounted() && _queued) {
        final nextForce = _queuedForce;
        _queued = false;
        _queuedForce = false;
        scheduleUpdate(ref, force: nextForce);
      }
    }
  }

  Future<List<Map<String, dynamic>>?> _loadNormalMemoRows(WidgetRef ref) async {
    final database = _tryReadDatabase(ref, source: '_loadNormalMemoRows');
    if (database == null) return null;
    return database.listMemos(state: 'NORMAL', limit: null);
  }

  Future<void> _updateDailyReviewWidget(
    WidgetRef ref, {
    List<Map<String, dynamic>>? rows,
  }) async {
    if (!_isMounted()) return;
    final prefs = _tryReadDevicePreferences(
      ref,
      source: '_updateDailyReviewWidget',
    );
    final session = _tryReadSession(ref, source: '_updateDailyReviewWidget');
    if (prefs == null) return;
    final memoRows =
        rows ??
        await _loadNormalMemoRows(ref) ??
        const <Map<String, dynamic>>[];
    if (!_isMounted()) return;
    final items = buildDailyReviewWidgetItems(
      memoRows,
      language: prefs.language,
      now: DateTime.now(),
    );
    final avatarBytes = await _resolveCurrentAvatarBytes(session);
    final localeTag = _localeTagForLanguage(prefs.language);
    final clearAvatar = _shouldClearAvatar(session);
    if (!_isMounted()) return;
    final signature = jsonEncode(<String, Object?>{
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'title': trByLanguageKey(
        language: prefs.language,
        key: 'legacy.msg_random_review',
      ),
      'fallbackBody': trByLanguageKey(
        language: prefs.language,
        key: 'legacy.msg_remember_moment_feel_warmth_life_take',
      ),
      'localeTag': localeTag,
      'clearAvatar': clearAvatar,
      'avatarKey': _avatarSignature(session),
    });
    if (_appliedDailyReviewSignature == signature) {
      return;
    }
    final result = await HomeWidgetService.updateDailyReviewWidget(
      items: items,
      title: trByLanguageKey(
        language: prefs.language,
        key: 'legacy.msg_random_review',
      ),
      fallbackBody: trByLanguageKey(
        language: prefs.language,
        key: 'legacy.msg_remember_moment_feel_warmth_life_take',
      ),
      avatarBytes: avatarBytes,
      clearAvatar: clearAvatar,
      localeTag: localeTag,
    );
    if (result) {
      _appliedDailyReviewSignature = signature;
    }
  }

  Future<void> _updateQuickInputWidget(WidgetRef ref) async {
    if (!_isMounted()) return;
    final prefs = _tryReadDevicePreferences(
      ref,
      source: '_updateQuickInputWidget',
    );
    if (prefs == null) return;
    final hint = trByLanguageKey(
      language: prefs.language,
      key: 'legacy.msg_what_s',
    );
    if (_appliedQuickInputSignature == hint) {
      return;
    }
    final result = await HomeWidgetService.updateQuickInputWidget(hint: hint);
    if (result) {
      _appliedQuickInputSignature = hint;
    }
  }

  Future<void> _updateCalendarWidget(
    WidgetRef ref, {
    List<Map<String, dynamic>>? rows,
  }) async {
    if (!_isMounted()) return;
    final prefs = _tryReadDevicePreferences(
      ref,
      source: '_updateCalendarWidget',
    );
    final resolvedSettings = _tryReadResolvedSettings(
      ref,
      source: '_updateCalendarWidget',
    );
    if (prefs == null || resolvedSettings == null) return;
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final memoRows =
        rows ??
        await _loadNormalMemoRows(ref) ??
        const <Map<String, dynamic>>[];
    if (!_isMounted()) return;
    final snapshot = buildCalendarWidgetSnapshot(
      month: month,
      rows: memoRows,
      language: prefs.language,
      themeColorArgb: themeColorSpec(
        resolvedSettings.resolvedThemeColor,
      ).primary.toARGB32(),
    );
    final signature = jsonEncode(snapshot.toJson());
    if (_appliedCalendarSignature == signature) {
      return;
    }
    final result = await HomeWidgetService.updateCalendarWidget(
      snapshot: snapshot,
    );
    if (result) {
      _appliedCalendarSignature = signature;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_dbChangesSubscription?.cancel());
  }

  bool _hasActiveWorkspace(WidgetRef ref) {
    final currentKey = _tryReadSession(
      ref,
      source: '_hasActiveWorkspace',
    )?.currentKey?.trim();
    if (currentKey != null && currentKey.isNotEmpty) {
      return true;
    }
    return _bootstrapAdapter.readCurrentLocalLibrary(ref) != null;
  }

  Future<void> _clearWidgets() async {
    _cachedAvatarKey = null;
    _cachedAvatarBytes = null;
    _appliedDailyReviewSignature = null;
    _appliedQuickInputSignature = null;
    _appliedCalendarSignature = null;
    await HomeWidgetService.clearHomeWidgets();
  }

  void _scheduleDeferredUpdate(WidgetRef ref, {required Duration delay}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (!_isMounted()) return;
      final nextForce = _queuedForce;
      _queuedForce = false;
      unawaited(updateIfNeeded(ref, force: nextForce));
    });
  }

  DevicePreferences? _tryReadDevicePreferences(
    WidgetRef ref, {
    required String source,
  }) {
    try {
      return _bootstrapAdapter.readDevicePreferences(ref);
    } catch (error) {
      debugPrint(
        '[HomeWidgetsUpdater] skip $source device preferences: $error',
      );
      return null;
    }
  }

  ResolvedAppSettings? _tryReadResolvedSettings(
    WidgetRef ref, {
    required String source,
  }) {
    try {
      return _bootstrapAdapter.readResolvedAppSettings(ref);
    } catch (error) {
      debugPrint('[HomeWidgetsUpdater] skip $source resolved settings: $error');
      return null;
    }
  }

  AppSessionState? _tryReadSession(WidgetRef ref, {required String source}) {
    try {
      return _bootstrapAdapter.readSession(ref);
    } catch (error) {
      debugPrint('[HomeWidgetsUpdater] skip $source session: $error');
      return null;
    }
  }

  AppDatabase? _tryReadDatabase(WidgetRef ref, {required String source}) {
    try {
      return _bootstrapAdapter.readDatabase(ref);
    } catch (error) {
      debugPrint('[HomeWidgetsUpdater] skip $source database: $error');
      return null;
    }
  }

  Future<Uint8List?> _resolveCurrentAvatarBytes(
    AppSessionState? session,
  ) async {
    final account = session?.currentAccount;
    if (account == null) {
      _cachedAvatarKey = null;
      _cachedAvatarBytes = null;
      return null;
    }

    final rawAvatarUrl = account.user.avatarUrl.trim();
    if (rawAvatarUrl.isEmpty) {
      _cachedAvatarKey = null;
      _cachedAvatarBytes = null;
      return null;
    }

    final resolvedUrl = resolveMaybeRelativeUrl(account.baseUrl, rawAvatarUrl);
    if (resolvedUrl.trim().isEmpty) return null;

    final cacheKey = '${account.key}|$resolvedUrl';
    if (_cachedAvatarKey == cacheKey && _cachedAvatarBytes != null) {
      return _cachedAvatarBytes;
    }

    final inlineBytes = tryDecodeDataUri(resolvedUrl);
    if (inlineBytes != null && inlineBytes.isNotEmpty) {
      _cachedAvatarKey = cacheKey;
      _cachedAvatarBytes = inlineBytes;
      return inlineBytes;
    }

    try {
      final headers = <String, dynamic>{};
      final token = account.personalAccessToken.trim();
      if (token.isNotEmpty &&
          _shouldAttachAvatarAuth(
            baseUrl: account.baseUrl,
            resolvedUrl: resolvedUrl,
          )) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: headers.isEmpty ? null : headers,
        ),
      ).get<List<int>>(resolvedUrl);
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      _cachedAvatarKey = cacheKey;
      _cachedAvatarBytes = bytes;
      return bytes;
    } catch (error) {
      debugPrint('[HomeWidgetsUpdater] avatar fetch failed: $error');
      return null;
    }
  }

  bool _shouldClearAvatar(AppSessionState? session) {
    final account = session?.currentAccount;
    if (account == null) return true;
    return account.user.avatarUrl.trim().isEmpty;
  }

  String _avatarSignature(AppSessionState? session) {
    final account = session?.currentAccount;
    if (account == null) return 'none';
    final rawAvatarUrl = account.user.avatarUrl.trim();
    if (rawAvatarUrl.isEmpty) return '${account.key}|none';
    return '${account.key}|${resolveMaybeRelativeUrl(account.baseUrl, rawAvatarUrl)}';
  }

  bool _shouldAttachAvatarAuth({
    required Uri baseUrl,
    required String resolvedUrl,
  }) {
    final resolved = Uri.tryParse(resolvedUrl);
    if (resolved == null) return false;
    if (!resolved.hasScheme) return true;
    final basePort = baseUrl.hasPort
        ? baseUrl.port
        : _defaultPortForScheme(baseUrl.scheme);
    final resolvedPort = resolved.hasPort
        ? resolved.port
        : _defaultPortForScheme(resolved.scheme);
    return resolved.scheme == baseUrl.scheme &&
        resolved.host == baseUrl.host &&
        resolvedPort == basePort;
  }

  int? _defaultPortForScheme(String scheme) {
    return switch (scheme) {
      'http' => 80,
      'https' => 443,
      _ => null,
    };
  }

  String _localeTagForLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zhHans => 'zh-Hans',
      AppLanguage.zhHantTw => 'zh-Hant-TW',
      AppLanguage.ja => 'ja',
      AppLanguage.de => 'de',
      AppLanguage.system => appLocaleForLanguage(language).languageCode,
      _ => 'en',
    };
  }
}
