import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/desktop_quick_input_channel.dart';
import '../../core/top_toast.dart';

abstract interface class DesktopSettingsWindowRouteIntent {}

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
}) {
  if (!supportsDesktopSettingsWindow()) {
    return Future.value(const DesktopSettingsWindowOpenResult.unsupported());
  }
  final pending = _desktopSettingsWindowOpenTask;
  if (pending != null) return pending;

  final task = _openDesktopSettingsWindow(feedbackContext: feedbackContext);
  _desktopSettingsWindowOpenTask = task;
  return task.whenComplete(() {
    if (identical(_desktopSettingsWindowOpenTask, task)) {
      _desktopSettingsWindowOpenTask = null;
    }
  });
}

Future<DesktopSettingsWindowOpenResult> _openDesktopSettingsWindow({
  BuildContext? feedbackContext,
}) async {
  try {
    var window = await _ensureDesktopSettingsWindowReady();
    try {
      return await _showAndVerifyDesktopSettingsWindow(window);
    } catch (_) {
      _notifyDesktopSettingsWindowVisibility(
        windowId: window.windowId,
        visible: false,
      );
      _desktopSettingsWindow = null;
      _desktopSettingsWindowId = null;
      window = await _ensureDesktopSettingsWindowReady();
      return await _showAndVerifyDesktopSettingsWindow(window);
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
  WindowController window,
) async {
  await _withSettingsWindowTimeout(window.show());
  _notifyDesktopSettingsWindowVisibility(
    windowId: window.windowId,
    visible: true,
  );
  await _refreshDesktopSettingsWindowSession(window.windowId);
  await _focusDesktopSettingsWindow(window.windowId);
  final responsive = await _isDesktopSettingsWindowResponsive(window.windowId);
  if (!responsive) {
    throw StateError('Desktop settings window is unresponsive');
  }
  return const DesktopSettingsWindowOpenResult.opened();
}

Future<WindowController> _ensureDesktopSettingsWindowReady() async {
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
