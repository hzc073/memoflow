import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../core/storage_read.dart';
import '../../core/debug_ephemeral_storage.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/hash.dart';
import '../../core/theme_colors.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/device_preferences.dart';
import '../../data/models/memo_toolbar_preferences.dart';
import '../../data/models/resolved_app_settings.dart';
import '../../data/models/workspace_preferences.dart';
import '../../data/logs/log_manager.dart';
import '../system/session_provider.dart';
import '../system/storage_error_provider.dart';
import 'device_preferences_provider.dart';
import 'resolved_preferences_provider.dart';
import 'workspace_preferences_provider.dart';

export '../../data/models/app_preferences.dart';

/// Legacy repository kept for backward-compatible storage reads and writes.
///
/// New runtime code should use the split device/workspace repositories instead.
final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((
  ref,
) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return AppPreferencesRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final appPreferencesLoadedProvider = StateProvider<bool>((ref) => false);

@Deprecated(
  'Legacy compatibility bridge only. Use devicePreferencesProvider, '
  'currentWorkspacePreferencesProvider, or resolvedAppSettingsProvider.',
)
final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesController, AppPreferences>((ref) {
      final loadedState = ref.read(appPreferencesLoadedProvider.notifier);
      Future.microtask(() => loadedState.state = false);
      final controller = AppPreferencesController.bridge(
        ref,
        onLoaded: (loaded) => loadedState.state = loaded,
      );
      ref.listen<ResolvedAppSettings>(resolvedAppSettingsProvider, (
        prev,
        next,
      ) {
        controller.syncFromProviders(resolvedSettings: next);
      });
      ref.listen<bool>(devicePreferencesLoadedProvider, (prev, next) {
        controller.syncLoadedState(devicePreferencesLoaded: next);
      });
      ref.listen<bool>(workspacePreferencesLoadedProvider, (prev, next) {
        controller.syncLoadedState(workspacePreferencesLoaded: next);
      });
      return controller;
    });

class AppPreferencesController extends StateNotifier<AppPreferences> {
  AppPreferencesController(this._ref, this._repo, {void Function()? onLoaded})
    : _legacyOnLoaded = onLoaded,
      _bridgeOnLoaded = null,
      _bridgeMode = false,
      super(AppPreferences.defaults) {
    unawaited(_loadFromStorage());
  }

  AppPreferencesController.bridge(
    this._ref, {
    void Function(bool loaded)? onLoaded,
  }) : _repo = null,
       _legacyOnLoaded = null,
       _bridgeOnLoaded = onLoaded,
       _bridgeMode = true,
       super(_composeLegacyPreferences(_ref)) {
    _bridgeDevicePreferencesLoaded = _ref.read(devicePreferencesLoadedProvider);
    _bridgeWorkspacePreferencesLoaded = _ref.read(
      workspacePreferencesLoadedProvider,
    );
    Future.microtask(() {
      if (!mounted) return;
      syncFromProviders();
      syncLoadedState();
    });
  }

  final Ref _ref;
  final AppPreferencesRepository? _repo;
  final void Function()? _legacyOnLoaded;
  final void Function(bool loaded)? _bridgeOnLoaded;
  final bool _bridgeMode;
  bool _bridgeDevicePreferencesLoaded = false;
  bool _bridgeWorkspacePreferencesLoaded = false;
  Future<void> _writeChain = Future<void>.value();

  static AppPreferences _composeLegacyPreferences(Ref ref) {
    return ref.read(resolvedAppSettingsProvider).toLegacyAppPreferences();
  }

  bool get _combinedLoaded =>
      _bridgeDevicePreferencesLoaded && _bridgeWorkspacePreferencesLoaded;

  void syncFromProviders({ResolvedAppSettings? resolvedSettings}) {
    if (!_bridgeMode || !mounted) return;
    final ResolvedAppSettings effectiveResolvedSettings =
        resolvedSettings ?? _ref.read(resolvedAppSettingsProvider);
    state = effectiveResolvedSettings.toLegacyAppPreferences();
    _bridgeOnLoaded?.call(_combinedLoaded);
  }

  void syncLoadedState({
    bool? devicePreferencesLoaded,
    bool? workspacePreferencesLoaded,
  }) {
    if (!_bridgeMode) return;
    if (devicePreferencesLoaded != null) {
      _bridgeDevicePreferencesLoaded = devicePreferencesLoaded;
    }
    if (workspacePreferencesLoaded != null) {
      _bridgeWorkspacePreferencesLoaded = workspacePreferencesLoaded;
    }
    _bridgeOnLoaded?.call(_combinedLoaded);
  }

  Future<void> reloadFromStorage() async {
    if (_bridgeMode) {
      await _ref.read(devicePreferencesProvider.notifier).reloadFromStorage();
      await _ref
          .read(currentWorkspacePreferencesProvider.notifier)
          .reloadFromStorage();
      if (mounted) {
        syncLoadedState(
          devicePreferencesLoaded: _ref.read(devicePreferencesLoadedProvider),
          workspacePreferencesLoaded: _ref.read(
            workspacePreferencesLoadedProvider,
          ),
        );
        syncFromProviders();
      }
      return;
    }
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    if (_bridgeMode) {
      syncFromProviders();
      syncLoadedState();
      return;
    }
    if (kDebugMode) {
      LogManager.instance.info('Prefs: load_start');
    }
    final stateBeforeLoad = state;
    try {
      final result = await _repo!.readWithStatus();
      if (!mounted) return;
      if (!identical(state, stateBeforeLoad)) {
        return;
      }
      if (result.isError) {
        final error = StorageLoadError(
          source: 'preferences',
          error: result.error!,
          stackTrace: result.stackTrace ?? StackTrace.current,
        );
        LogManager.instance.error(
          'Failed to load app preferences.',
          error: error.error,
          stackTrace: error.stackTrace,
        );
        _ref.read(legacyAppPreferencesStorageErrorProvider.notifier).state =
            error;
        return;
      }
      _ref.read(legacyAppPreferencesStorageErrorProvider.notifier).state = null;
      final stored =
          result.data ??
          AppPreferences.defaults.copyWith(
            language: AppLanguage.system,
            hasSelectedLanguage: false,
          );
      state = stored;
      if (kDebugMode) {
        LogManager.instance.info(
          'Prefs: load_complete',
          context: <String, Object?>{
            'language': stored.language.name,
            'hasSelectedLanguage': stored.hasSelectedLanguage,
            'onboardingMode': stored.onboardingMode?.name,
            'homeInitialLoadingOverlayShown':
                stored.homeInitialLoadingOverlayShown,
          },
        );
      }
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'Failed to load app preferences.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      if (!identical(state, stateBeforeLoad)) {
        return;
      }
      _ref
          .read(legacyAppPreferencesStorageErrorProvider.notifier)
          .state = StorageLoadError(
        source: 'preferences',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    } finally {
      if (mounted) {
        _legacyOnLoaded?.call();
      }
    }
  }

  void _setAndPersist(AppPreferences next, {bool triggerSync = true}) {
    final previous = state;
    state = next;
    if (kDebugMode) {
      final onboardingChanged =
          previous.language != next.language ||
          previous.hasSelectedLanguage != next.hasSelectedLanguage ||
          previous.onboardingMode != next.onboardingMode ||
          previous.homeInitialLoadingOverlayShown !=
              next.homeInitialLoadingOverlayShown;
      if (onboardingChanged) {
        LogManager.instance.info(
          'Prefs: onboarding_state_changed',
          context: <String, Object?>{
            'previousLanguage': previous.language.name,
            'nextLanguage': next.language.name,
            'previousHasSelectedLanguage': previous.hasSelectedLanguage,
            'nextHasSelectedLanguage': next.hasSelectedLanguage,
            'previousOnboardingMode': previous.onboardingMode?.name,
            'nextOnboardingMode': next.onboardingMode?.name,
            'triggerSync': triggerSync,
          },
        );
      }
    }
    // Serialize writes to avoid out-of-order persistence overwriting newer prefs.
    _writeChain = _writeChain.then((_) async {
      try {
        if (_bridgeMode) {
          final workspaceKey = _ref.read(currentWorkspaceKeyProvider);
          final deviceNext = DevicePreferences.fromLegacy(next);
          final workspaceNext = WorkspacePreferences.fromLegacy(
            next,
            workspaceKey: workspaceKey,
          );
          await _ref
              .read(devicePreferencesProvider.notifier)
              .setAll(deviceNext, triggerSync: false);
          await _ref
              .read(currentWorkspacePreferencesProvider.notifier)
              .setAll(workspaceNext, triggerSync: false);
          if (mounted) {
            syncFromProviders();
          }
        } else {
          await _repo!.write(next);
        }
      } catch (error, stackTrace) {
        LogManager.instance.warn(
          'Failed to persist app preferences.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    if (triggerSync) {
      unawaited(
        _ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.settings,
              ),
            ),
      );
    }
  }

  Future<void> waitForPendingWrites() => _writeChain;

  Future<void> setAll(AppPreferences next, {bool triggerSync = true}) async =>
      _setAndPersist(next, triggerSync: triggerSync);

  void setLanguage(AppLanguage v) =>
      _setAndPersist(state.copyWith(language: v));
  void setHasSelectedLanguage(bool v) =>
      _setAndPersist(state.copyWith(hasSelectedLanguage: v));
  void setHomeInitialLoadingOverlayShown(bool v) =>
      _setAndPersist(state.copyWith(homeInitialLoadingOverlayShown: v));
  void setFontSize(AppFontSize v) =>
      _setAndPersist(state.copyWith(fontSize: v));
  void setLineHeight(AppLineHeight v) =>
      _setAndPersist(state.copyWith(lineHeight: v));
  void setFontFamily({String? family, String? filePath}) {
    _setAndPersist(state.copyWith(fontFamily: family, fontFile: filePath));
  }

  void setCollapseLongContent(bool v) =>
      _setAndPersist(state.copyWith(collapseLongContent: v));
  void setCollapseReferences(bool v) =>
      _setAndPersist(state.copyWith(collapseReferences: v));
  void setShowEngagementInAllMemoDetails(bool v) =>
      _setAndPersist(state.copyWith(showEngagementInAllMemoDetails: v));
  void setLaunchAction(LaunchAction v) =>
      _setAndPersist(state.copyWith(launchAction: v));
  void setAutoSyncOnStartAndResume(bool v) =>
      _setAndPersist(state.copyWith(autoSyncOnStartAndResume: v));
  void setQuickInputAutoFocus(bool v) =>
      _setAndPersist(state.copyWith(quickInputAutoFocus: v));
  void setConfirmExitOnBack(bool v) =>
      _setAndPersist(state.copyWith(confirmExitOnBack: v));
  void setHapticsEnabled(bool v) =>
      _setAndPersist(state.copyWith(hapticsEnabled: v));
  void setUseLegacyApi(bool v) =>
      _setAndPersist(state.copyWith(useLegacyApi: v));
  void setNetworkLoggingEnabled(bool v) =>
      _setAndPersist(state.copyWith(networkLoggingEnabled: v));
  void setThemeMode(AppThemeMode v) =>
      _setAndPersist(state.copyWith(themeMode: v));
  void setThemeColor(AppThemeColor v) =>
      setThemeColorForAccount(accountKey: null, color: v);
  void setThemeColorForAccount({
    required String? accountKey,
    required AppThemeColor color,
  }) {
    if (accountKey == null || accountKey.trim().isEmpty) {
      _setAndPersist(state.copyWith(themeColor: color));
      return;
    }
    final next = Map<String, AppThemeColor>.from(state.accountThemeColors);
    next[accountKey] = color;
    _setAndPersist(state.copyWith(accountThemeColors: next));
  }

  void setCustomThemeForAccount({
    required String? accountKey,
    required CustomThemeSettings settings,
  }) {
    if (accountKey == null || accountKey.trim().isEmpty) {
      _setAndPersist(state.copyWith(customTheme: settings));
      return;
    }
    final next = Map<String, CustomThemeSettings>.from(
      state.accountCustomThemes,
    );
    next[accountKey] = settings;
    _setAndPersist(state.copyWith(accountCustomThemes: next));
  }

  void ensureAccountThemeDefaults(String accountKey) {
    if (_bridgeMode) return;
    final key = accountKey.trim();
    if (key.isEmpty) return;
    final hasThemeColor = state.accountThemeColors.containsKey(key);
    final hasCustomTheme = state.accountCustomThemes.containsKey(key);
    if (hasThemeColor && hasCustomTheme) return;
    final nextThemeColors = Map<String, AppThemeColor>.from(
      state.accountThemeColors,
    );
    final nextCustomThemes = Map<String, CustomThemeSettings>.from(
      state.accountCustomThemes,
    );
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

  void setShowDrawerExplore(bool v) =>
      _setAndPersist(state.copyWith(showDrawerExplore: v));
  void setShowDrawerDailyReview(bool v) =>
      _setAndPersist(state.copyWith(showDrawerDailyReview: v));
  void setShowDrawerAiSummary(bool v) =>
      _setAndPersist(state.copyWith(showDrawerAiSummary: v));
  void setShowDrawerResources(bool v) =>
      _setAndPersist(state.copyWith(showDrawerResources: v));
  void setShowDrawerArchive(bool v) =>
      _setAndPersist(state.copyWith(showDrawerArchive: v));
  void setHomeQuickActions({
    required HomeQuickAction primary,
    required HomeQuickAction secondary,
    required HomeQuickAction tertiary,
  }) => _setAndPersist(
    state.copyWith(
      homeQuickActionPrimary: primary,
      homeQuickActionSecondary: secondary,
      homeQuickActionTertiary: tertiary,
    ),
  );
  void setMemoToolbarPreferences(MemoToolbarPreferences v) =>
      _setAndPersist(state.copyWith(memoToolbarPreferences: v));
  void resetMemoToolbarPreferences() => _setAndPersist(
    state.copyWith(memoToolbarPreferences: MemoToolbarPreferences.defaults),
  );
  void setAiSummaryAllowPrivateMemos(bool v) =>
      _setAndPersist(state.copyWith(aiSummaryAllowPrivateMemos: v));
  void setThirdPartyShareEnabled(bool v) =>
      _setAndPersist(state.copyWith(thirdPartyShareEnabled: v));
  void setWindowsCloseToTray(bool v) =>
      _setAndPersist(state.copyWith(windowsCloseToTray: v));
  void setDesktopShortcutBinding({
    required DesktopShortcutAction action,
    required DesktopShortcutBinding binding,
  }) {
    final next = Map<DesktopShortcutAction, DesktopShortcutBinding>.from(
      state.desktopShortcutBindings,
    );
    next[action] = binding;
    _setAndPersist(state.copyWith(desktopShortcutBindings: next));
  }

  void resetDesktopShortcutBindings() {
    _setAndPersist(
      state.copyWith(desktopShortcutBindings: desktopShortcutDefaultBindings),
    );
  }

  void setLastSeenAppVersion(String v) =>
      _setAndPersist(state.copyWith(lastSeenAppVersion: v), triggerSync: false);
  void acceptLegalDocuments({
    required String hash,
    required String appVersion,
  }) {
    _setAndPersist(
      state.copyWith(
        acceptedLegalDocumentsHash: hash,
        acceptedLegalDocumentsAt: DateTime.now().toUtc().toIso8601String(),
        lastSeenAppVersion: appVersion,
      ),
      triggerSync: false,
    );
  }

  void setSkippedUpdateVersion(String version) {
    _setAndPersist(
      state.copyWith(skippedUpdateVersion: version),
      triggerSync: false,
    );
  }

  void setLastSeenAnnouncement({
    required String version,
    required int announcementId,
  }) {
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
  AppPreferencesRepository(this._storage, {required String? accountKey})
    : _accountKey = accountKey;

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

  Future<StorageReadResult<String?>> _storageReadWithStatus(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.trim().isEmpty) {
        return StorageReadResult.empty();
      }
      return StorageReadResult.success(raw);
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'Secure storage read failed in preferences repository.',
        error: error,
        stackTrace: stackTrace,
        context: {'key': key},
      );
      return StorageReadResult.failure(cause: error, stackTrace: stackTrace);
    }
  }

  Future<void> _safeStorageWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'Secure storage write failed in preferences repository.',
        error: error,
        stackTrace: stackTrace,
        context: {'key': key},
      );
    }
  }

  Future<void> _safeStorageDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'Secure storage delete failed in preferences repository.',
        error: error,
        stackTrace: stackTrace,
        context: {'key': key},
      );
    }
  }

  Future<File?> _fallbackFileForKey(String key) async {
    try {
      final dir = await resolveAppSupportDirectory();
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

  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    final storageKey = _storageKey;
    if (storageKey == null) {
      final deviceResult = await _readDeviceWithStatus();
      if (deviceResult.isError) {
        return StorageReadResult.failure(
          cause: deviceResult.error!,
          stackTrace: deviceResult.stackTrace ?? StackTrace.current,
        );
      }
      final device = deviceResult.data ?? await _readFallback(_kDeviceKey);
      if (device != null) {
        await _safeStorageWrite(_kDeviceKey, jsonEncode(device.toJson()));
        await _writeFallback(_kDeviceKey, device);
      }
      return StorageReadResult.success(device ?? _defaultsForFirstRun());
    }

    final deviceResult = await _readDeviceWithStatus();
    if (deviceResult.isError) {
      return StorageReadResult.failure(
        cause: deviceResult.error!,
        stackTrace: deviceResult.stackTrace ?? StackTrace.current,
      );
    }
    final device = deviceResult.data ?? await _readFallback(_kDeviceKey);
    if (device != null) {
      await _safeStorageWrite(_kDeviceKey, jsonEncode(device.toJson()));
      await _writeFallback(_kDeviceKey, device);
    }

    final rawResult = await _storageReadWithStatus(storageKey);
    if (rawResult.isError) {
      return StorageReadResult.failure(
        cause: rawResult.error!,
        stackTrace: rawResult.stackTrace ?? StackTrace.current,
      );
    }
    if (rawResult.isEmpty) {
      final legacyResult = await _readLegacyWithStatus();
      if (legacyResult.isError) {
        return StorageReadResult.failure(
          cause: legacyResult.error!,
          stackTrace: legacyResult.stackTrace ?? StackTrace.current,
        );
      }
      final legacy = legacyResult.data;
      if (legacy != null) {
        var normalized = _normalizeLegacyForAccount(legacy);
        if (device != null) {
          normalized = normalized.copyWith(useLegacyApi: device.useLegacyApi);
        }
        final resolved = _inheritDeviceOnboarding(normalized, device);
        await write(resolved);
        return StorageReadResult.success(resolved);
      }
      if (device != null) {
        await write(device);
        return StorageReadResult.success(device);
      }
      final fallback = await _readFallback(storageKey);
      if (fallback != null) {
        await write(fallback);
        return StorageReadResult.success(fallback);
      }
      return StorageReadResult.success(_defaultsForFirstRun());
    }
    try {
      final decoded = jsonDecode(rawResult.data!);
      if (decoded is Map) {
        final parsed = AppPreferences.fromJson(decoded.cast<String, dynamic>());
        final resolved = _inheritDeviceOnboarding(parsed, device);
        if (resolved != parsed) {
          await write(resolved);
          return StorageReadResult.success(resolved);
        }
        await _syncDeviceOnboarding(parsed);
        return StorageReadResult.success(parsed);
      }
    } catch (_) {
      // Fall through to fallback file.
    }
    final fallback = await _readFallback(storageKey);
    if (fallback != null) {
      final resolved = _inheritDeviceOnboarding(fallback, device);
      await write(resolved);
      return StorageReadResult.success(resolved);
    }
    return StorageReadResult.success(_defaultsForFirstRun());
  }

  Future<AppPreferences> read() async {
    final result = await readWithStatus();
    return result.data ?? _defaultsForFirstRun();
  }

  AppPreferences _defaultsForFirstRun() {
    return AppPreferences.defaults.copyWith(
      language: AppLanguage.system,
      hasSelectedLanguage: false,
    );
  }

  Future<void> write(AppPreferences prefs) async {
    final storageKey = _storageKey;
    if (storageKey == null) {
      await _safeStorageWrite(_kDeviceKey, jsonEncode(prefs.toJson()));
      await _writeFallback(_kDeviceKey, prefs);
      return;
    }
    await _safeStorageWrite(storageKey, jsonEncode(prefs.toJson()));
    await _writeFallback(storageKey, prefs);
    await _syncDeviceOnboarding(prefs);
  }

  Future<void> clear() async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _safeStorageDelete(storageKey);
    await _deleteFallback(storageKey);
  }

  Future<StorageReadResult<AppPreferences?>> _readDeviceWithStatus() async {
    final raw = await _storageReadWithStatus(_kDeviceKey);
    if (raw.isError) {
      return StorageReadResult.failure(
        cause: raw.error!,
        stackTrace: raw.stackTrace ?? StackTrace.current,
      );
    }
    if (raw.isEmpty) return StorageReadResult.success(null);
    try {
      final decoded = jsonDecode(raw.data!);
      if (decoded is Map) {
        return StorageReadResult.success(
          AppPreferences.fromJson(decoded.cast<String, dynamic>()),
        );
      }
    } catch (_) {}
    return StorageReadResult.failure(
      cause: const FormatException('Invalid device preferences'),
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageReadResult<AppPreferences?>> _readLegacyWithStatus() async {
    final raw = await _storageReadWithStatus(_kLegacyKey);
    if (raw.isError) {
      return StorageReadResult.failure(
        cause: raw.error!,
        stackTrace: raw.stackTrace ?? StackTrace.current,
      );
    }
    if (raw.isEmpty) return StorageReadResult.success(null);
    try {
      final decoded = jsonDecode(raw.data!);
      if (decoded is Map) {
        return StorageReadResult.success(
          AppPreferences.fromJson(decoded.cast<String, dynamic>()),
        );
      }
    } catch (_) {}
    return StorageReadResult.failure(
      cause: const FormatException('Invalid legacy preferences'),
      stackTrace: StackTrace.current,
    );
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

  AppPreferences _inheritDeviceOnboarding(
    AppPreferences prefs,
    AppPreferences? device,
  ) {
    if (device == null) return prefs;
    if (!prefs.hasSelectedLanguage && device.hasSelectedLanguage) {
      return prefs.copyWith(
        language: device.language,
        hasSelectedLanguage: true,
      );
    }
    return prefs;
  }

  Future<void> _syncDeviceOnboarding(AppPreferences prefs) async {
    final device = await _readDevice() ?? await _readFallback(_kDeviceKey);
    final nextHasSelected = prefs.hasSelectedLanguage;
    final nextLanguage = prefs.hasSelectedLanguage
        ? prefs.language
        : device?.language;
    if (device != null &&
        device.hasSelectedLanguage == nextHasSelected &&
        device.language == nextLanguage) {
      return;
    }
    final base =
        device ?? AppPreferences.defaults.copyWith(language: prefs.language);
    final next = base.copyWith(
      language: nextLanguage ?? prefs.language,
      hasSelectedLanguage: nextHasSelected,
    );
    await _safeStorageWrite(_kDeviceKey, jsonEncode(next.toJson()));
    await _writeFallback(_kDeviceKey, next);
  }

  Future<AppPreferences?> _readDevice() async {
    final result = await _readDeviceWithStatus();
    if (result.isError) {
      return null;
    }
    return result.data;
  }
}
