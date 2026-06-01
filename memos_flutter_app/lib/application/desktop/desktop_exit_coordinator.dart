import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/desktop_quick_input_channel.dart';
import '../../data/db/database_registry.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/system/logging_provider.dart';
import 'desktop_quick_input_controller.dart';
import 'desktop_tray_controller.dart';

typedef DesktopExitPrepareCallback = FutureOr<void> Function();
typedef DesktopSecondaryRouteCloseCallback = FutureOr<bool> Function();

enum DesktopCloseRequestAction {
  nativeClose,
  hideToTray,
  hideToMenuBar,
  fullExit,
  popSecondaryRoute,
}

class DesktopExitCoordinator with WindowListener {
  static const Duration _closeSubWindowsStepTimeout = Duration(seconds: 2);
  static const Duration _listSubWindowsTimeout = Duration(milliseconds: 400);
  static const Duration _subWindowExitSignalTimeout = Duration(
    milliseconds: 350,
  );
  static const Duration _subWindowCloseTimeout = Duration(milliseconds: 800);
  static const Duration _mainWindowTeardownDelay = Duration(milliseconds: 200);
  static const Duration _closeDatabasesTimeout = Duration(seconds: 2);
  static const Duration _forceExitFallbackTimeout = Duration(seconds: 3);
  static const Duration _exitLogFlushTimeout = Duration(milliseconds: 500);
  static const List<String> _exitStepOrder = <String>[
    'prepare_for_exit',
    'close_sub_windows',
    'unregister_hotkey',
    'dispose_tray',
    'close_databases',
    'disable_prevent_close',
    'close_main_window',
    'await_main_window_teardown',
  ];

  DesktopExitCoordinator._({
    required WidgetRef ref,
    required DesktopQuickInputController quickInputController,
    required Future<void> Function() closeDatabases,
    required Duration mainWindowTeardownDelay,
    required DesktopExitPrepareCallback? prepareForExit,
    required DesktopSecondaryRouteCloseCallback? closeSecondaryRoute,
  }) : _ref = ref,
       _quickInputController = quickInputController,
       _closeDatabases = closeDatabases,
       _mainWindowTeardownDelayOverride = mainWindowTeardownDelay,
       _prepareForExit = prepareForExit,
       _closeSecondaryRoute = closeSecondaryRoute;

  static DesktopExitCoordinator? _instance;

  final WidgetRef _ref;
  final DesktopQuickInputController _quickInputController;
  final Future<void> Function() _closeDatabases;
  final Duration _mainWindowTeardownDelayOverride;
  final DesktopExitPrepareCallback? _prepareForExit;
  final DesktopSecondaryRouteCloseCallback? _closeSecondaryRoute;
  bool _listenerAttached = false;
  bool _exiting = false;
  Completer<void>? _exitCompleter;
  Timer? _forceExitTimer;

  static DesktopExitCoordinator? get instance => _instance;
  static bool get isReady => _instance != null;

  static DesktopExitCoordinator init({
    required WidgetRef ref,
    required DesktopQuickInputController quickInputController,
    Future<void> Function()? closeDatabases,
    Duration mainWindowTeardownDelay = _mainWindowTeardownDelay,
    DesktopExitPrepareCallback? prepareForExit,
    DesktopSecondaryRouteCloseCallback? closeSecondaryRoute,
  }) {
    _instance = DesktopExitCoordinator._(
      ref: ref,
      quickInputController: quickInputController,
      closeDatabases: closeDatabases ?? DatabaseRegistry.closeAll,
      mainWindowTeardownDelay: mainWindowTeardownDelay,
      prepareForExit: prepareForExit,
      closeSecondaryRoute: closeSecondaryRoute,
    );
    return _instance!;
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  @visibleForTesting
  static List<String> debugExitStepOrder() =>
      List<String>.unmodifiable(_exitStepOrder);

  @visibleForTesting
  static String debugMainWindowTerminationAction() => 'close';

  @visibleForTesting
  static String debugCloseRequestAction({
    required bool isWindows,
    required bool closeToTray,
    required bool traySupported,
  }) {
    return _resolveCloseRequestAction(
      isWindows: isWindows,
      closeToTray: closeToTray,
      traySupported: traySupported,
    ).name;
  }

  @visibleForTesting
  static String debugMacosCloseRequestAction({
    required bool hasSecondaryRoute,
    required bool closeToMenuBar,
    required bool statusIconSupported,
  }) {
    return _resolveMacosCloseRequestAction(
      hasSecondaryRoute: hasSecondaryRoute,
      closeToMenuBar: closeToMenuBar,
      statusIconSupported: statusIconSupported,
    ).name;
  }

  @visibleForTesting
  static Future<bool> debugInvokeSecondaryRouteCloseCallback(
    DesktopSecondaryRouteCloseCallback? closeSecondaryRoute,
  ) {
    return _invokeSecondaryRouteCloseCallback(closeSecondaryRoute);
  }

  @visibleForTesting
  Future<void> debugPerformExit({String? reason, bool force = false}) {
    return _performExit(reason: reason, force: force);
  }

  static Future<void> requestClose({String? source}) async {
    final instance = _instance;
    if (instance == null) return;
    await instance._requestClose(source: source);
  }

  static Future<void> requestExit({String? reason, bool force = false}) async {
    final instance = _instance;
    if (instance == null) return;
    await instance._requestExit(reason: reason, force: force);
  }

  static Future<void> activateMainWindow() async {
    final instance = _instance;
    if (instance == null) return;
    await instance._activateMainWindow();
  }

  Future<void> attachWindowListener() async {
    if (_listenerAttached ||
        kIsWeb ||
        (!Platform.isWindows && !Platform.isMacOS)) {
      return;
    }
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    _listenerAttached = true;
  }

  Future<void> dispose() async {
    _cancelForceExitFallback();
    if (_listenerAttached) {
      windowManager.removeListener(this);
      _listenerAttached = false;
    }
  }

  @override
  void onWindowClose() {
    if (_exiting) return;
    unawaited(_requestClose(source: 'window_close'));
  }

  Future<void> _requestClose({String? source}) async {
    if (kIsWeb) {
      return;
    }
    if (Platform.isMacOS) {
      if (_exiting) return;
      if (await _maybeCloseSecondaryRoute()) {
        return;
      }
      final closeToMenuBar = _ref.read(
        devicePreferencesProvider.select((p) => p.macosCloseToMenuBar),
      );
      final action = _resolveMacosCloseRequestAction(
        hasSecondaryRoute: false,
        closeToMenuBar: closeToMenuBar,
        statusIconSupported: DesktopTrayController.instance.supported,
      );
      if (action == DesktopCloseRequestAction.hideToMenuBar) {
        try {
          await DesktopTrayController.instance.hideToStatusArea();
          return;
        } catch (_) {}
      }
      await _requestExit(reason: source ?? 'close', force: false);
      return;
    }
    if (!Platform.isWindows) {
      await windowManager.close();
      return;
    }
    if (_exiting) return;
    final closeToTray = _ref.read(
      devicePreferencesProvider.select((p) => p.windowsCloseToTray),
    );
    final action = _resolveCloseRequestAction(
      isWindows: true,
      closeToTray: closeToTray,
      traySupported: DesktopTrayController.instance.supported,
    );
    await _logExitInfo(
      'Desktop close requested',
      context: {
        'source': source ?? 'unknown',
        'closeToTray': closeToTray,
        'traySupported': DesktopTrayController.instance.supported,
        'action': action.name,
      },
    );
    if (action == DesktopCloseRequestAction.hideToTray) {
      try {
        await DesktopTrayController.instance.hideToTray();
        return;
      } catch (error, stackTrace) {
        await _logExitWarn(
          'Hide to tray failed. Falling back to exit.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    await _requestExit(reason: source ?? 'close', force: false);
  }

  Future<bool> _maybeCloseSecondaryRoute() async {
    return _invokeSecondaryRouteCloseCallback(_closeSecondaryRoute);
  }

  static Future<bool> _invokeSecondaryRouteCloseCallback(
    DesktopSecondaryRouteCloseCallback? closeSecondaryRoute,
  ) async {
    if (closeSecondaryRoute == null) return false;
    try {
      return await Future<bool>.sync(closeSecondaryRoute);
    } catch (_) {
      return true;
    }
  }

  Future<void> _requestExit({String? reason, bool force = false}) async {
    if (_exiting) {
      await _exitCompleter?.future;
      return;
    }
    _exiting = true;
    final completer = Completer<void>();
    _exitCompleter = completer;
    _armForceExitFallback();
    unawaited(
      _performExit(reason: reason, force: force).whenComplete(() {
        if (!completer.isCompleted) completer.complete();
      }),
    );
    await completer.future;
  }

  Future<void> _performExit({String? reason, bool force = false}) async {
    await _logExitInfo(
      'Desktop exit requested',
      context: {'reason': reason ?? 'unknown', 'force': force},
    );
    await _runExitStep(_exitStepOrder[0], _prepareForFullExit);
    await _runExitStep(
      _exitStepOrder[1],
      _closeSubWindows,
      timeout: _closeSubWindowsStepTimeout,
    );
    await _runExitStep(
      _exitStepOrder[2],
      () => _quickInputController.unregisterHotKey(),
    );
    await _runExitStep(
      _exitStepOrder[3],
      () => DesktopTrayController.instance.dispose(),
    );
    await _runExitStep(
      _exitStepOrder[4],
      _closeDatabases,
      timeout: _closeDatabasesTimeout,
    );
    await _runExitStep(
      _exitStepOrder[5],
      () => windowManager.setPreventClose(false),
    );
    await _runExitStep(_exitStepOrder[6], _terminateMainWindowForExit);
    await _runExitStep(
      _exitStepOrder[7],
      () => Future<void>.delayed(_mainWindowTeardownDelayOverride),
    );
    await _logExitInfo(
      'Desktop exit Dart lifecycle completed',
      context: {'reason': reason ?? 'unknown', 'force': force},
    );
  }

  static DesktopCloseRequestAction _resolveCloseRequestAction({
    required bool isWindows,
    required bool closeToTray,
    required bool traySupported,
  }) {
    if (!isWindows) return DesktopCloseRequestAction.nativeClose;
    if (closeToTray && traySupported) {
      return DesktopCloseRequestAction.hideToTray;
    }
    return DesktopCloseRequestAction.fullExit;
  }

  static DesktopCloseRequestAction _resolveMacosCloseRequestAction({
    required bool hasSecondaryRoute,
    required bool closeToMenuBar,
    required bool statusIconSupported,
  }) {
    if (hasSecondaryRoute) return DesktopCloseRequestAction.popSecondaryRoute;
    if (closeToMenuBar && statusIconSupported) {
      return DesktopCloseRequestAction.hideToMenuBar;
    }
    return DesktopCloseRequestAction.fullExit;
  }

  Future<void> _prepareForFullExit() async {
    final prepareForExit = _prepareForExit;
    if (prepareForExit == null) return;
    await Future<void>.sync(prepareForExit);
  }

  Future<void> _closeSubWindows() async {
    List<int> ids = const <int>[];
    try {
      ids = await DesktopMultiWindow.getAllSubWindowIds().timeout(
        _listSubWindowsTimeout,
        onTimeout: () => const <int>[],
      );
    } catch (_) {}
    final closeTasks = <Future<void>>[];
    for (final id in ids) {
      if (id <= 0) continue;
      closeTasks.add(_closeSubWindow(id));
    }
    if (closeTasks.isEmpty) return;
    await Future.wait(closeTasks);
  }

  Future<void> _closeSubWindow(int id) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        id,
        desktopSubWindowExitMethod,
        null,
      ).timeout(_subWindowExitSignalTimeout);
    } catch (_) {}

    try {
      await WindowController.fromWindowId(
        id,
      ).close().timeout(_subWindowCloseTimeout);
    } catch (_) {}
  }

  Future<void> _activateMainWindow() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      } else {
        await windowManager.show();
      }
      await windowManager.focus();
    } catch (_) {}
    try {
      await DesktopTrayController.instance.showFromTray();
    } catch (_) {}
  }

  Future<void> _terminateMainWindowForExit() async {
    if (!kIsWeb && Platform.isMacOS) {
      await windowManager.destroy();
      return;
    }
    await windowManager.close();
  }

  void _armForceExitFallback() {
    _forceExitTimer?.cancel();
    _forceExitTimer = Timer(_forceExitFallbackTimeout, () {
      if (!_exiting) return;
      unawaited(
        _logExitWarn(
          'Desktop force-exit fallback triggered',
        ).whenComplete(() => exit(0)),
      );
    });
  }

  void _cancelForceExitFallback() {
    _forceExitTimer?.cancel();
    _forceExitTimer = null;
  }

  Future<bool> _runExitStep(
    String name,
    Future<void> Function() action, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final stopwatch = Stopwatch()..start();
    await _logExitInfo(
      'Desktop exit step started',
      context: {'step': name, 'timeoutMs': timeout.inMilliseconds},
    );
    try {
      await action().timeout(timeout);
      stopwatch.stop();
      await _logExitInfo(
        'Desktop exit step completed',
        context: {'step': name, 'elapsedMs': stopwatch.elapsedMilliseconds},
      );
      return true;
    } catch (error, stackTrace) {
      stopwatch.stop();
      await _logExitWarn(
        'Desktop exit step failed',
        error: error,
        stackTrace: stackTrace,
        context: {'step': name, 'elapsedMs': stopwatch.elapsedMilliseconds},
      );
      return false;
    }
  }

  Future<void> _logExitInfo(
    String message, {
    Map<String, Object?>? context,
  }) async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final logManager = _ref.read(logManagerProvider);
      logManager.info(message, context: context);
      await logManager.flush(timeout: _exitLogFlushTimeout);
    } catch (_) {}
  }

  Future<void> _logExitWarn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final logManager = _ref.read(logManagerProvider);
      logManager.warn(
        message,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );
      await logManager.flush(timeout: _exitLogFlushTimeout);
    } catch (_) {}
  }
}
