import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/desktop_quick_input_channel.dart';
import '../../core/top_toast.dart';

abstract interface class DesktopSettingsWindowRouteIntent {}

enum DesktopSettingsWindowTarget {
  ai,
  aiProvider,
  quickPrompts,
  desktopShortcuts,
  templates,
  memoToolbar,
  location,
  imageBed,
  imageCompression,
  webDavBackup,
  importData,
  exportMemos,
  localNetworkMigration,
  desktopShortcutsOverview,
  selfRepair,
  exportDiagnostics,
  feedback,
  releaseNotes;

  static const String payloadKey = 'desktop_settings_target';

  String get payloadValue {
    return switch (this) {
      DesktopSettingsWindowTarget.ai => 'ai',
      DesktopSettingsWindowTarget.aiProvider => 'aiProvider',
      DesktopSettingsWindowTarget.quickPrompts => 'quickPrompts',
      DesktopSettingsWindowTarget.desktopShortcuts => 'desktopShortcuts',
      DesktopSettingsWindowTarget.templates => 'templates',
      DesktopSettingsWindowTarget.memoToolbar => 'memoToolbar',
      DesktopSettingsWindowTarget.location => 'location',
      DesktopSettingsWindowTarget.imageBed => 'imageBed',
      DesktopSettingsWindowTarget.imageCompression => 'imageCompression',
      DesktopSettingsWindowTarget.webDavBackup => 'webDavBackup',
      DesktopSettingsWindowTarget.importData => 'importData',
      DesktopSettingsWindowTarget.exportMemos => 'exportMemos',
      DesktopSettingsWindowTarget.localNetworkMigration =>
        'localNetworkMigration',
      DesktopSettingsWindowTarget.desktopShortcutsOverview =>
        'desktopShortcutsOverview',
      DesktopSettingsWindowTarget.selfRepair => 'selfRepair',
      DesktopSettingsWindowTarget.exportDiagnostics => 'exportDiagnostics',
      DesktopSettingsWindowTarget.feedback => 'feedback',
      DesktopSettingsWindowTarget.releaseNotes => 'releaseNotes',
    };
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{payloadKey: payloadValue};
  }

  static DesktopSettingsWindowTarget? fromPayload(Object? payload) {
    final value = switch (payload) {
      String raw => raw,
      Map<Object?, Object?> raw => raw[payloadKey],
      _ => null,
    };
    if (value is! String) return null;
    return switch (value) {
      'ai' => DesktopSettingsWindowTarget.ai,
      'aiProvider' => DesktopSettingsWindowTarget.aiProvider,
      'quickPrompts' => DesktopSettingsWindowTarget.quickPrompts,
      'desktopShortcuts' => DesktopSettingsWindowTarget.desktopShortcuts,
      'templates' => DesktopSettingsWindowTarget.templates,
      'memoToolbar' => DesktopSettingsWindowTarget.memoToolbar,
      'location' => DesktopSettingsWindowTarget.location,
      'imageBed' => DesktopSettingsWindowTarget.imageBed,
      'imageCompression' => DesktopSettingsWindowTarget.imageCompression,
      'webDavBackup' => DesktopSettingsWindowTarget.webDavBackup,
      'importData' => DesktopSettingsWindowTarget.importData,
      'exportMemos' => DesktopSettingsWindowTarget.exportMemos,
      'localNetworkMigration' =>
        DesktopSettingsWindowTarget.localNetworkMigration,
      'desktopShortcutsOverview' =>
        DesktopSettingsWindowTarget.desktopShortcutsOverview,
      'selfRepair' => DesktopSettingsWindowTarget.selfRepair,
      'exportDiagnostics' => DesktopSettingsWindowTarget.exportDiagnostics,
      'feedback' => DesktopSettingsWindowTarget.feedback,
      'releaseNotes' => DesktopSettingsWindowTarget.releaseNotes,
      _ => null,
    };
  }

  static DesktopSettingsWindowTarget? fromLaunchArgs(
    Map<String, dynamic> args,
  ) {
    return fromPayload(args[payloadKey]);
  }
}

typedef DesktopSettingsWindowVisibilityListener =
    void Function({required int windowId, required bool visible});

WindowController? _desktopSettingsWindow;
int? _desktopSettingsWindowId;
Future<DesktopSettingsWindowOpenResult>? _desktopSettingsWindowOpenTask;
Future<void>? _desktopSettingsWindowPrepareTask;
DesktopSettingsWindowVisibilityListener?
_desktopSettingsWindowVisibilityListener;

enum DesktopSettingsWindowOpenStatus { unsupported, opened, failed }

class DesktopSettingsWindowOpenResult {
  const DesktopSettingsWindowOpenResult._(this.status, {this.error});

  const DesktopSettingsWindowOpenResult.unsupported()
    : this._(DesktopSettingsWindowOpenStatus.unsupported);

  const DesktopSettingsWindowOpenResult.opened()
    : this._(DesktopSettingsWindowOpenStatus.opened);

  factory DesktopSettingsWindowOpenResult.failed(Object error) {
    return DesktopSettingsWindowOpenResult._(
      DesktopSettingsWindowOpenStatus.failed,
      error: error,
    );
  }

  final DesktopSettingsWindowOpenStatus status;
  final Object? error;

  bool get opened => status == DesktopSettingsWindowOpenStatus.opened;
  bool get shouldFallback => status != DesktopSettingsWindowOpenStatus.opened;
}

void setDesktopSettingsWindowVisibilityListener(
  DesktopSettingsWindowVisibilityListener? listener,
) {
  _desktopSettingsWindowVisibilityListener = listener;
}

void _notifyDesktopSettingsWindowVisibility({
  required int windowId,
  required bool visible,
}) {
  final listener = _desktopSettingsWindowVisibilityListener;
  if (listener == null || windowId <= 0) return;
  listener(windowId: windowId, visible: visible);
}

bool supportsDesktopSettingsWindow() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

Future<DesktopSettingsWindowOpenResult> openDesktopSettingsWindow({
  BuildContext? feedbackContext,
  DesktopSettingsWindowTarget? target,
}) {
  if (!supportsDesktopSettingsWindow()) {
    return Future.value(const DesktopSettingsWindowOpenResult.unsupported());
  }
  final pending = _desktopSettingsWindowOpenTask;
  if (pending != null) {
    if (target == null) return pending;
    return _routeDesktopSettingsTargetAfterOpen(
      pending,
      target: target,
      feedbackContext: feedbackContext,
    );
  }

  final task = _openDesktopSettingsWindow(
    feedbackContext: feedbackContext,
    target: target,
  );
  _desktopSettingsWindowOpenTask = task;
  return task.whenComplete(() {
    if (identical(_desktopSettingsWindowOpenTask, task)) {
      _desktopSettingsWindowOpenTask = null;
    }
  });
}

Future<DesktopSettingsWindowOpenResult> _openDesktopSettingsWindow({
  BuildContext? feedbackContext,
  DesktopSettingsWindowTarget? target,
}) async {
  try {
    var window = await _ensureDesktopSettingsWindowReady(target: target);
    try {
      return await _showAndVerifyDesktopSettingsWindow(window, target: target);
    } catch (_) {
      _notifyDesktopSettingsWindowVisibility(
        windowId: window.windowId,
        visible: false,
      );
      _desktopSettingsWindow = null;
      _desktopSettingsWindowId = null;
      window = await _ensureDesktopSettingsWindowReady(target: target);
      return await _showAndVerifyDesktopSettingsWindow(window, target: target);
    }
  } catch (error) {
    final context = feedbackContext;
    if (context != null && context.mounted) {
      showTopToast(context, 'Failed to open settings: $error');
    }
    return DesktopSettingsWindowOpenResult.failed(error);
  }
}

Future<DesktopSettingsWindowOpenResult> _showAndVerifyDesktopSettingsWindow(
  WindowController window, {
  DesktopSettingsWindowTarget? target,
}) async {
  await _withSettingsWindowTimeout(window.show());
  _notifyDesktopSettingsWindowVisibility(
    windowId: window.windowId,
    visible: true,
  );
  await _focusDesktopSettingsWindow(window.windowId);
  final responsive = await _isDesktopSettingsWindowResponsive(window.windowId);
  if (!responsive) {
    throw StateError('Desktop settings window is unresponsive');
  }
  await _refreshDesktopSettingsWindowSession(window.windowId);
  final targetToOpen = target;
  if (targetToOpen != null) {
    await _routeDesktopSettingsWindowTarget(window.windowId, targetToOpen);
  }
  return const DesktopSettingsWindowOpenResult.opened();
}

Future<WindowController> _ensureDesktopSettingsWindowReady({
  DesktopSettingsWindowTarget? target,
}) async {
  await _refreshDesktopSettingsWindowReference();
  final existing = _desktopSettingsWindow;
  if (existing != null) return existing;

  final pending = _desktopSettingsWindowPrepareTask;
  if (pending != null) {
    await pending;
    await _refreshDesktopSettingsWindowReference();
    final prepared = _desktopSettingsWindow;
    if (prepared != null) return prepared;
  }

  final completer = Completer<void>();
  _desktopSettingsWindowPrepareTask = completer.future;
  try {
    await _refreshDesktopSettingsWindowReference();
    final refreshed = _desktopSettingsWindow;
    if (refreshed != null) return refreshed;

    final window = await DesktopMultiWindow.createWindow(
      jsonEncode(<String, dynamic>{
        desktopWindowTypeKey: desktopWindowTypeSettings,
        if (target != null) ...target.toJson(),
      }),
    );
    _desktopSettingsWindow = window;
    _desktopSettingsWindowId = window.windowId;
    await window.setTitle('MemoFlow Settings');
    final frame = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => const Offset(0, 0) & Size(960, 760),
      _ => const Offset(0, 0) & Size(1260, 820),
    };
    await window.setFrame(frame);
    await window.center();
    return window;
  } finally {
    completer.complete();
    if (identical(_desktopSettingsWindowPrepareTask, completer.future)) {
      _desktopSettingsWindowPrepareTask = null;
    }
  }
}

Future<DesktopSettingsWindowOpenResult> _routeDesktopSettingsTargetAfterOpen(
  Future<DesktopSettingsWindowOpenResult> pending, {
  required DesktopSettingsWindowTarget target,
  BuildContext? feedbackContext,
}) async {
  final result = await pending;
  if (!result.opened) return result;
  final windowId = _desktopSettingsWindowId;
  if (windowId == null) {
    final error = StateError(
      'Desktop settings window target requested without a window id',
    );
    final context = feedbackContext;
    if (context != null && context.mounted) {
      showTopToast(context, 'Failed to open settings: $error');
    }
    return DesktopSettingsWindowOpenResult.failed(error);
  }
  try {
    await _routeDesktopSettingsWindowTarget(windowId, target);
    return result;
  } catch (error) {
    final context = feedbackContext;
    if (context != null && context.mounted) {
      showTopToast(context, 'Failed to open settings: $error');
    }
    return DesktopSettingsWindowOpenResult.failed(error);
  }
}

Future<void> _routeDesktopSettingsWindowTarget(
  int windowId,
  DesktopSettingsWindowTarget target,
) async {
  final result = await _withSettingsWindowTimeout(
    DesktopMultiWindow.invokeMethod(
      windowId,
      desktopSettingsOpenTargetMethod,
      target.toJson(),
    ),
  );
  if (result != true) {
    throw StateError(
      'Desktop settings window target was not accepted: ${target.payloadValue}',
    );
  }
}

Future<void> _refreshDesktopSettingsWindowReference() async {
  final trackedId = _desktopSettingsWindowId;
  if (trackedId == null) {
    _desktopSettingsWindow = null;
    return;
  }
  try {
    final ids = await DesktopMultiWindow.getAllSubWindowIds();
    if (!ids.contains(trackedId)) {
      _notifyDesktopSettingsWindowVisibility(
        windowId: trackedId,
        visible: false,
      );
      _desktopSettingsWindow = null;
      _desktopSettingsWindowId = null;
      return;
    }
    _desktopSettingsWindow ??= WindowController.fromWindowId(trackedId);
  } catch (_) {
    _notifyDesktopSettingsWindowVisibility(windowId: trackedId, visible: false);
    _desktopSettingsWindow = null;
    _desktopSettingsWindowId = null;
  }
}

Future<void> _focusDesktopSettingsWindow(int windowId) async {
  try {
    await _withSettingsWindowTimeout(
      DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsFocusMethod,
        null,
      ),
    );
  } catch (_) {}
}

Future<void> _refreshDesktopSettingsWindowSession(int windowId) async {
  try {
    await _withSettingsWindowTimeout(
      DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsRefreshSessionMethod,
        null,
      ),
    );
  } catch (_) {}
}

Future<bool> _isDesktopSettingsWindowResponsive(int windowId) async {
  try {
    final result = await _withSettingsWindowTimeout(
      DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsPingMethod,
        null,
      ),
    );
    return result == null || result == true;
  } catch (_) {
    return false;
  }
}

Future<T> _withSettingsWindowTimeout<T>(Future<T> future) {
  return future.timeout(const Duration(seconds: 3));
}

Future<void> requestMainWindowReopenOnboardingIfSupported() async {
  if (!supportsDesktopSettingsWindow()) return;
  try {
    await DesktopMultiWindow.invokeMethod(
      0,
      desktopSettingsReopenOnboardingMethod,
      null,
    );
  } catch (_) {}
}
