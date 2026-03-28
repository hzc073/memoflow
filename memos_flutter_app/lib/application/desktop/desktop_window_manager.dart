import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop_quick_input_channel.dart';
import 'desktop_workspace_snapshot.dart';
import 'desktop_settings_window.dart';
import '../../core/desktop/shortcuts.dart';
import 'desktop_tray_controller.dart';
import 'desktop_exit_coordinator.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../state/settings/ai_settings_provider.dart';
import '../../state/settings/preferences_provider.dart';
import 'desktop_quick_input_controller.dart';

typedef DesktopQuickInputLauncher =
    Future<void> Function({required bool autoFocus});

class DesktopWindowManager {
  DesktopWindowManager({
    required AppBootstrapAdapter bootstrapAdapter,
    required WidgetRef ref,
    required GlobalKey<NavigatorState> navigatorKey,
    required DesktopQuickInputController quickInputController,
    required DesktopQuickInputLauncher openQuickInput,
    required bool Function() isMounted,
    required VoidCallback onVisibilityChanged,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _ref = ref,
       _navigatorKey = navigatorKey,
       _quickInputController = quickInputController,
       _openQuickInput = openQuickInput,
       _isMounted = isMounted,
       _onVisibilityChanged = onVisibilityChanged;

  final AppBootstrapAdapter _bootstrapAdapter;
  final WidgetRef _ref;
  final GlobalKey<NavigatorState> _navigatorKey;
  final DesktopQuickInputController _quickInputController;
  final DesktopQuickInputLauncher _openQuickInput;
  final bool Function() _isMounted;
  final VoidCallback _onVisibilityChanged;

  final Set<int> _desktopVisibleSubWindowIds = <int>{};
  bool _desktopSubWindowsPrewarmScheduled = false;
  bool _desktopSubWindowVisibilitySyncInProgress = false;
  bool _desktopSubWindowVisibilitySyncQueued = false;
  bool _desktopSubWindowVisibilitySyncScheduled = false;
  DateTime? _lastDesktopSubWindowVisibilitySyncAt;
  int? _desktopQuickInputWindowId;

  static const Duration _desktopSubWindowVisibilitySyncDebounce = Duration(
    milliseconds: 360,
  );

  void configureTrayActions() {
    if (!DesktopTrayController.instance.supported) return;
    DesktopTrayController.instance.configureActions(
      onOpenSettings: _handleOpenSettingsFromTray,
      onNewMemo: _handleCreateMemoFromTray,
      onExit: () => DesktopExitCoordinator.requestExit(reason: 'tray_exit'),
    );
  }

  void bindMethodHandler() {
    if (kIsWeb) return;
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
  }

  void unbindMethodHandler() {
    if (kIsWeb) return;
    DesktopMultiWindow.setMethodHandler(null);
  }

  void updateQuickInputWindowId(int? windowId) {
    _desktopQuickInputWindowId = windowId;
  }

  bool get shouldBlurMainWindow {
    if (_desktopVisibleSubWindowIds.isEmpty || kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  void setSubWindowVisibility({required int windowId, required bool visible}) {
    if (windowId <= 0) return;
    final changed = visible
        ? _desktopVisibleSubWindowIds.add(windowId)
        : _desktopVisibleSubWindowIds.remove(windowId);
    if (!changed || !_isMounted()) return;
    _onVisibilityChanged();
  }

  void scheduleVisibilitySync({bool force = false}) {
    if (kIsWeb || _desktopVisibleSubWindowIds.isEmpty) return;
    if (!force) {
      final last = _lastDesktopSubWindowVisibilitySyncAt;
      if (last != null &&
          DateTime.now().difference(last) <
              _desktopSubWindowVisibilitySyncDebounce) {
        return;
      }
    }
    if (_desktopSubWindowVisibilitySyncScheduled) return;
    _desktopSubWindowVisibilitySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopSubWindowVisibilitySyncScheduled = false;
      unawaited(_syncDesktopSubWindowVisibility());
    });
  }

  Future<void> focusVisibleSubWindow() async {
    if (!shouldBlurMainWindow || _desktopVisibleSubWindowIds.isEmpty) {
      return;
    }
    final candidateIds = _desktopVisibleSubWindowIds.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    for (final id in candidateIds) {
      final focused = await _focusDesktopSubWindowById(id);
      if (focused) return;
      setSubWindowVisibility(windowId: id, visible: false);
    }
  }

  void schedulePrewarm() {
    if (!isDesktopShortcutEnabled() || _desktopSubWindowsPrewarmScheduled) {
      return;
    }
    _desktopSubWindowsPrewarmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prewarmDesktopSubWindows());
    });
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int fromWindowId) async {
    if (!_isMounted()) return null;
    if (_isQuickInputMethod(call.method)) {
      return _quickInputController.handleMethodCall(call, fromWindowId);
    }
    switch (call.method) {
      case desktopSubWindowVisibilityMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final visible = _parseDesktopSubWindowVisibleFlag(
          map == null ? null : map['visible'],
        );
        setSubWindowVisibility(
          windowId: fromWindowId,
          visible: visible ?? true,
        );
        return true;
      case desktopSettingsReopenOnboardingMethod:
        try {
          await _bootstrapAdapter.reloadSessionFromStorage(_ref);
        } catch (_) {}
        try {
          await _bootstrapAdapter.reloadLocalLibrariesFromStorage(_ref);
        } catch (_) {}
        final session = _bootstrapAdapter.readSession(_ref);
        if (session?.currentAccount == null && session?.currentKey != null) {
          try {
            await _bootstrapAdapter.setCurrentSessionKey(_ref, null);
          } catch (_) {}
        }
        _bootstrapAdapter.setHasSelectedLanguage(_ref, false);
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil('/', (route) => false);
        }
        return true;
      case desktopMainReloadWorkspaceMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final hasKey = map != null && map.containsKey('currentKey');
        final rawKey = map == null ? null : map['currentKey'];
        final log = _bootstrapAdapter.readLogManager(_ref);
        var setKeyOk = true;
        var reloadOk = true;
        var keyEmpty = false;
        var keyInvalidType = false;
        if (hasKey) {
          if (rawKey == null) {
            keyEmpty = true;
            try {
              await _bootstrapAdapter.setCurrentSessionKey(_ref, null);
            } catch (error, stackTrace) {
              setKeyOk = false;
              log.error(
                'Desktop workspace reload failed to clear session key',
                error: error,
                stackTrace: stackTrace,
              );
            }
          } else if (rawKey is String) {
            final nextKey = rawKey.trim();
            keyEmpty = nextKey.isEmpty;
            try {
              await _bootstrapAdapter.setCurrentSessionKey(
                _ref,
                nextKey.isEmpty ? null : nextKey,
              );
            } catch (error, stackTrace) {
              setKeyOk = false;
              log.error(
                'Desktop workspace reload failed to set session key',
                error: error,
                stackTrace: stackTrace,
              );
            }
          } else {
            keyInvalidType = true;
            setKeyOk = false;
            log.warn(
              'Desktop workspace reload ignored non-string currentKey',
              context: <String, Object?>{'type': rawKey.runtimeType.toString()},
            );
          }
        }
        try {
          await _bootstrapAdapter.reloadLocalLibrariesFromStorage(_ref);
        } catch (error, stackTrace) {
          reloadOk = false;
          log.error(
            'Desktop workspace reload failed to refresh libraries',
            error: error,
            stackTrace: stackTrace,
          );
        }
        log.info(
          'Desktop workspace reload handled',
          context: <String, Object?>{
            'hasKey': hasKey,
            'keyEmpty': keyEmpty,
            'keyInvalidType': keyInvalidType,
            'setKeyOk': setKeyOk,
            'reloadOk': reloadOk,
          },
        );
        return reloadOk && (!hasKey || setKeyOk);
      case desktopMainReloadAiSettingsMethod:
        final log = _bootstrapAdapter.readLogManager(_ref);
        try {
          if (!_isMounted()) return false;
          await _ref.read(aiSettingsProvider.notifier).reloadFromStorage();
          if (!_isMounted()) return false;
          log.info('Desktop AI settings reload handled');
          return true;
        } catch (error, stackTrace) {
          log.error(
            'Desktop AI settings reload failed',
            error: error,
            stackTrace: stackTrace,
          );
          return false;
        }
      case desktopMainReloadPreferencesMethod:
        final log = _bootstrapAdapter.readLogManager(_ref);
        try {
          await _ref.read(appPreferencesProvider.notifier).reloadFromStorage();
          final quickInputWindowId = _desktopQuickInputWindowId;
          if (quickInputWindowId != null && quickInputWindowId > 0) {
            try {
              await DesktopMultiWindow.invokeMethod(
                quickInputWindowId,
                desktopMainReloadPreferencesMethod,
                null,
              );
            } catch (_) {}
          }
          log.info('Desktop preferences reload handled');
          return true;
        } catch (error, stackTrace) {
          log.error(
            'Desktop preferences reload failed',
            error: error,
            stackTrace: stackTrace,
          );
          return false;
        }
      case desktopHomeShowLoadingOverlayMethod:
        _bootstrapAdapter.forceHomeLoadingOverlay(_ref);
        return true;
      case desktopMainGetWorkspaceSnapshotMethod:
        final session = _bootstrapAdapter.readSession(_ref);
        final localLibrary = _bootstrapAdapter.readCurrentLocalLibrary(_ref);
        return DesktopWorkspaceSnapshot(
          currentKey: session?.currentKey,
          hasCurrentAccount: session?.currentAccount != null,
          hasLocalLibrary: localLibrary != null,
        ).toJson();
      default:
        return null;
    }
  }

  bool _isQuickInputMethod(String method) {
    return method == desktopQuickInputSubmitMethod ||
        method == desktopQuickInputPlaceholderMethod ||
        method == desktopQuickInputPickLinkMemoMethod ||
        method == desktopQuickInputListTagsMethod ||
        method == desktopQuickInputPingMethod ||
        method == desktopQuickInputClosedMethod;
  }

  bool? _parseDesktopSubWindowVisibleFlag(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  Future<void> _syncDesktopSubWindowVisibility() async {
    if (kIsWeb || _desktopVisibleSubWindowIds.isEmpty) return;
    if (_desktopSubWindowVisibilitySyncInProgress) {
      _desktopSubWindowVisibilitySyncQueued = true;
      return;
    }
    _desktopSubWindowVisibilitySyncInProgress = true;
    _lastDesktopSubWindowVisibilitySyncAt = DateTime.now();
    try {
      final trackedIds = _desktopVisibleSubWindowIds.toSet();
      final nextVisibleIds = <int>{};
      Set<int>? existingIds;
      try {
        existingIds = (await DesktopMultiWindow.getAllSubWindowIds())
            .where((id) => id > 0)
            .toSet();
      } catch (_) {}

      for (final id in trackedIds) {
        if (existingIds != null && !existingIds.contains(id)) {
          continue;
        }
        final visible = await _queryDesktopSubWindowVisible(id);
        if (visible == true) {
          nextVisibleIds.add(id);
          continue;
        }
        if (visible == null && await _isDesktopSubWindowResponsive(id)) {
          nextVisibleIds.add(id);
        }
      }

      if (!_isMounted() ||
          setEquals(nextVisibleIds, _desktopVisibleSubWindowIds)) {
        return;
      }
      _desktopVisibleSubWindowIds
        ..clear()
        ..addAll(nextVisibleIds);
      _onVisibilityChanged();
    } finally {
      _desktopSubWindowVisibilitySyncInProgress = false;
      if (_desktopSubWindowVisibilitySyncQueued) {
        _desktopSubWindowVisibilitySyncQueued = false;
        unawaited(_syncDesktopSubWindowVisibility());
      }
    }
  }

  Future<bool?> _queryDesktopSubWindowVisible(int windowId) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSubWindowIsVisibleMethod,
        null,
      );
      return _parseDesktopSubWindowVisibleFlag(result);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isDesktopSubWindowResponsive(int windowId) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsPingMethod,
        null,
      );
      if (result == null || result == true) {
        return true;
      }
    } catch (_) {}
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputPingMethod,
        null,
      );
      return result == null || result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _focusDesktopSubWindowById(int windowId) async {
    try {
      await WindowController.fromWindowId(windowId).show();
    } catch (_) {}

    if (_desktopQuickInputWindowId == windowId) {
      try {
        await DesktopMultiWindow.invokeMethod(
          windowId,
          desktopQuickInputFocusMethod,
          null,
        );
        return true;
      } catch (_) {}
      try {
        await DesktopMultiWindow.invokeMethod(
          windowId,
          desktopSettingsFocusMethod,
          null,
        );
        return true;
      } catch (_) {}
      return false;
    }

    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsFocusMethod,
        null,
      );
      return true;
    } catch (_) {}
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputFocusMethod,
        null,
      );
      return true;
    } catch (_) {}
    return false;
  }

  Future<void> _prewarmDesktopSubWindows() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!_isMounted() || !isDesktopShortcutEnabled()) return;
    bindMethodHandler();
    try {
      await _quickInputController.prewarm();
    } catch (error, stackTrace) {
      _bootstrapAdapter
          .readLogManager(_ref)
          .warn(
            'Desktop sub-window prewarm failed',
            error: error,
            stackTrace: stackTrace,
          );
    }
    prewarmDesktopSettingsWindowIfSupported();
  }

  Future<void> _handleOpenSettingsFromTray() async {
    if (!_isMounted()) return;
    final context = _resolveDesktopUiContext();
    openDesktopSettingsWindowIfSupported(feedbackContext: context);
  }

  Future<void> _handleCreateMemoFromTray() async {
    if (!_isMounted()) return;
    if (isDesktopShortcutEnabled()) {
      await _quickInputController.handleHotKey();
      return;
    }
    unawaited(
      _openQuickInput(autoFocus: AppPreferences.defaults.quickInputAutoFocus),
    );
  }

  BuildContext? _resolveDesktopUiContext() {
    final direct = _navigatorKey.currentContext;
    if (direct != null && direct.mounted) return direct;
    final overlay = _navigatorKey.currentState?.overlay?.context;
    if (overlay != null && overlay.mounted) return overlay;
    return null;
  }
}
