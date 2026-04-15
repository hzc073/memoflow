import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/storage_read.dart';
import '../../core/theme_colors.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/collection_reader.dart';
import '../../data/models/device_preferences.dart';
import '../sync/sync_coordinator_provider.dart';
import '../system/storage_error_provider.dart';
import 'preferences_migration_service.dart';

final devicePreferencesRepositoryProvider =
    Provider<DevicePreferencesRepository>((ref) {
      return DevicePreferencesRepository(
        ref.watch(preferencesMigrationServiceProvider),
      );
    });

final devicePreferencesLoadedProvider = StateProvider<bool>((ref) => false);

final devicePreferencesProvider =
    StateNotifierProvider<DevicePreferencesController, DevicePreferences>((
      ref,
    ) {
      final loadedState = ref.read(devicePreferencesLoadedProvider.notifier);
      Future.microtask(() => loadedState.state = false);
      return DevicePreferencesController(
        ref,
        ref.watch(devicePreferencesRepositoryProvider),
        onLoaded: () => loadedState.state = true,
      );
    });

class DevicePreferencesController extends StateNotifier<DevicePreferences> {
  DevicePreferencesController(
    this._ref,
    this._repo, {
    void Function()? onLoaded,
  }) : _onLoaded = onLoaded,
       super(DevicePreferences.defaults) {
    _queuedState = state;
    unawaited(_loadFromStorage());
  }

  final Ref _ref;
  final DevicePreferencesRepository _repo;
  final void Function()? _onLoaded;
  Future<void> _writeChain = Future<void>.value();
  late DevicePreferences _queuedState;
  bool _deferringWritesForLegalConsent = false;
  bool _hasDeferredWrite = false;
  bool _deferredWriteRequiresSync = false;

  Future<T> _enqueueWriteTask<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _writeChain = _writeChain.then((_) async {
      try {
        final result = await task();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    return completer.future;
  }

  Future<void> reloadFromStorage() async {
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final stateBeforeLoad = state;
    try {
      final result = await _repo.readWithStatus();
      if (!mounted) return;
      if (!identical(state, stateBeforeLoad)) return;
      if (result.isError) {
        final error = StorageLoadError(
          source: 'device_preferences',
          error: result.error!,
          stackTrace: result.stackTrace ?? StackTrace.current,
        );
        LogManager.instance.error(
          'Failed to load device preferences.',
          error: error.error,
          stackTrace: error.stackTrace,
        );
        _ref.read(devicePreferencesStorageErrorProvider.notifier).state = error;
        return;
      }
      _ref.read(devicePreferencesStorageErrorProvider.notifier).state = null;
      state = result.data ?? DevicePreferences.defaults;
      _queuedState = state;
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'Failed to load device preferences.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      if (!identical(state, stateBeforeLoad)) return;
      _ref
          .read(devicePreferencesStorageErrorProvider.notifier)
          .state = StorageLoadError(
        source: 'device_preferences',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    } finally {
      if (mounted) {
        _onLoaded?.call();
      }
    }
  }

  void _requestSyncIfNeeded(bool triggerSync) {
    if (!triggerSync) {
      return;
    }
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

  void _queueBestEffortWrite(
    DevicePreferences next, {
    bool triggerSync = true,
  }) {
    _writeChain = _writeChain.then((_) async {
      try {
        await _repo.write(next);
      } catch (error, stackTrace) {
        LogManager.instance.warn(
          'Failed to persist device preferences.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    _requestSyncIfNeeded(triggerSync);
  }

  void _setAndPersist(DevicePreferences next, {bool triggerSync = true}) {
    _queuedState = next;
    if (_deferringWritesForLegalConsent) {
      _hasDeferredWrite = true;
      _deferredWriteRequiresSync = _deferredWriteRequiresSync || triggerSync;
      return;
    }
    state = next;
    _queueBestEffortWrite(next, triggerSync: triggerSync);
  }

  void _flushDeferredWriteIfNeeded() {
    if (!_hasDeferredWrite) {
      return;
    }
    final next = _queuedState;
    final triggerSync = _deferredWriteRequiresSync;
    _hasDeferredWrite = false;
    _deferredWriteRequiresSync = false;
    _queueBestEffortWrite(next, triggerSync: triggerSync);
  }

  void _clearDeferredWriteFlags() {
    _hasDeferredWrite = false;
    _deferredWriteRequiresSync = false;
  }

  Future<void> waitForPendingWrites() => _writeChain;

  Future<void> setAll(
    DevicePreferences next, {
    bool triggerSync = true,
  }) async => _setAndPersist(next, triggerSync: triggerSync);

  void setLanguage(AppLanguage value) =>
      _setAndPersist(_queuedState.copyWith(language: value));
  void setHasSelectedLanguage(bool value) =>
      _setAndPersist(_queuedState.copyWith(hasSelectedLanguage: value));
  void setOnboardingMode(AppOnboardingMode? value) =>
      _setAndPersist(_queuedState.copyWith(onboardingMode: value));
  void setHomeInitialLoadingOverlayShown(bool value) => _setAndPersist(
    _queuedState.copyWith(homeInitialLoadingOverlayShown: value),
  );
  void setFontSize(AppFontSize value) =>
      _setAndPersist(_queuedState.copyWith(fontSize: value));
  void setLineHeight(AppLineHeight value) =>
      _setAndPersist(_queuedState.copyWith(lineHeight: value));
  void setFontFamily({String? family, String? filePath}) => _setAndPersist(
    _queuedState.copyWith(fontFamily: family, fontFile: filePath),
  );
  void setConfirmExitOnBack(bool value) =>
      _setAndPersist(_queuedState.copyWith(confirmExitOnBack: value));
  void setHapticsEnabled(bool value) =>
      _setAndPersist(_queuedState.copyWith(hapticsEnabled: value));
  void setNetworkLoggingEnabled(bool value) =>
      _setAndPersist(_queuedState.copyWith(networkLoggingEnabled: value));
  void setThemeMode(AppThemeMode value) =>
      _setAndPersist(_queuedState.copyWith(themeMode: value));
  void setThemeColor(AppThemeColor value) =>
      _setAndPersist(_queuedState.copyWith(themeColor: value));
  void setCustomTheme(CustomThemeSettings value) =>
      _setAndPersist(_queuedState.copyWith(customTheme: value));
  void setLaunchAction(LaunchAction value) =>
      _setAndPersist(_queuedState.copyWith(launchAction: value));
  void setQuickInputAutoFocus(bool value) =>
      _setAndPersist(_queuedState.copyWith(quickInputAutoFocus: value));
  void setThirdPartyShareEnabled(bool value) =>
      _setAndPersist(_queuedState.copyWith(thirdPartyShareEnabled: value));
  void setWindowsCloseToTray(bool value) =>
      _setAndPersist(_queuedState.copyWith(windowsCloseToTray: value));
  void setDesktopShortcutBinding({
    required DesktopShortcutAction action,
    required DesktopShortcutBinding binding,
  }) {
    final next = Map<DesktopShortcutAction, DesktopShortcutBinding>.from(
      _queuedState.desktopShortcutBindings,
    );
    next[action] = binding;
    _setAndPersist(_queuedState.copyWith(desktopShortcutBindings: next));
  }

  void setHomeInlineComposePanelLayout(
    HomeInlineComposePanelLayoutPreference? value,
  ) {
    _setAndPersist(_queuedState.copyWith(homeInlineComposePanelLayout: value));
  }

  void setCollectionReaderMode(CollectionReaderMode value) {
    _setAndPersist(
      _queuedState.copyWith(collectionReaderMode: value),
      triggerSync: false,
    );
  }

  void setCollectionReaderPageAnimation(CollectionReaderPageAnimation value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(pageAnimation: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderThemePreset(CollectionReaderThemePreset value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(themePreset: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderBrightnessMode(
    CollectionReaderBrightnessMode value,
  ) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(brightnessMode: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderBrightness(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(brightness: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderTextScale(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(textScale: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderLineSpacing(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(lineSpacing: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderPagePadding(EdgeInsets value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(pagePadding: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderAutoPageSeconds(int value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(autoPageSeconds: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderFontFamily({String? family, String? filePath}) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(readerFontFamily: family, readerFontFile: filePath),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderFontWeightMode(
    CollectionReaderFontWeightMode value,
  ) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(fontWeightMode: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderLetterSpacing(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(letterSpacing: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderParagraphSpacing(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(paragraphSpacing: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderParagraphIndentChars(int value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(paragraphIndentChars: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderTitleMode(CollectionReaderTitleMode value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(titleMode: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderTitleScale(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(titleScale: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderTitleTopSpacing(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(titleTopSpacing: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderTitleBottomSpacing(double value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(titleBottomSpacing: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderHeaderPadding(EdgeInsets value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(headerPadding: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderFooterPadding(EdgeInsets value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(footerPadding: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderShowHeaderLine(bool value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(showHeaderLine: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderShowFooterLine(bool value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(showFooterLine: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderTipLayout(CollectionReaderTipLayout value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(tipLayout: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderBackgroundConfig(
    CollectionReaderBackgroundConfig value,
  ) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(backgroundConfig: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderDisplayConfig(CollectionReaderDisplayConfig value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(displayConfig: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderInputConfig(CollectionReaderInputConfig value) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(inputConfig: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderTapRegionConfig(
    CollectionReaderTapRegionConfig value,
  ) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(tapRegionConfig: value),
      ),
      triggerSync: false,
    );
  }

  void setCollectionReaderSavedStyleCards(
    List<CollectionReaderStyleCard> value,
  ) {
    _setAndPersist(
      _queuedState.copyWith(
        collectionReaderPreferences: _queuedState.collectionReaderPreferences
            .copyWith(savedStyleCards: List<CollectionReaderStyleCard>.unmodifiable(value)),
      ),
      triggerSync: false,
    );
  }

  void resetDesktopShortcutBindings() {
    _setAndPersist(
      _queuedState.copyWith(
        desktopShortcutBindings: desktopShortcutDefaultBindings,
      ),
    );
  }

  void setLastSeenAppVersion(String value) => _setAndPersist(
    _queuedState.copyWith(lastSeenAppVersion: value),
    triggerSync: false,
  );
  Future<void> acceptLegalDocuments({
    required String hash,
    required String appVersion,
  }) async {
    final trimmedHash = hash.trim();
    final previousState = state;
    final next = _queuedState.copyWith(
      acceptedLegalDocumentsHash: trimmedHash,
      acceptedLegalDocumentsAt: DateTime.now().toUtc().toIso8601String(),
      lastSeenAppVersion: appVersion,
    );
    _queuedState = next;
    _deferringWritesForLegalConsent = true;
    try {
      await _enqueueWriteTask(() async {
        await _repo.write(next);
        final saved = await _repo.read();
        if (saved.acceptedLegalDocumentsHash.trim() != trimmedHash) {
          throw StateError('Failed to persist legal consent.');
        }
      });
    } catch (_) {
      _deferringWritesForLegalConsent = false;
      _clearDeferredWriteFlags();
      _queuedState = previousState;
      if (mounted) {
        state = previousState;
      }
      try {
        await _repo.write(previousState);
      } catch (error, stackTrace) {
        LogManager.instance.warn(
          'Failed to restore device preferences after legal consent failure.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
    _deferringWritesForLegalConsent = false;
    if (!mounted) {
      _clearDeferredWriteFlags();
      return;
    }
    state = _queuedState;
    _flushDeferredWriteIfNeeded();
  }

  void setSkippedUpdateVersion(String value) => _setAndPersist(
    _queuedState.copyWith(skippedUpdateVersion: value),
    triggerSync: false,
  );
  void setLastSeenAnnouncement({
    required String version,
    required int announcementId,
  }) {
    _setAndPersist(
      _queuedState.copyWith(
        lastSeenAnnouncementVersion: version,
        lastSeenAnnouncementId: announcementId,
      ),
      triggerSync: false,
    );
  }

  void setLastSeenNoticeHash(String value) {
    _setAndPersist(
      _queuedState.copyWith(lastSeenNoticeHash: value),
      triggerSync: false,
    );
  }
}

class DevicePreferencesRepository {
  DevicePreferencesRepository(this._migrationService);

  final PreferencesMigrationService _migrationService;

  Future<StorageReadResult<DevicePreferences>> readWithStatus() =>
      _migrationService.readDeviceWithStatus();

  Future<DevicePreferences> read() => _migrationService.readDevice();

  Future<void> write(DevicePreferences prefs) =>
      _migrationService.writeDevice(prefs);
}
