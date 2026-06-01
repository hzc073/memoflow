import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const String _trayActionShow = 'show';
const String _trayActionOpenSettings = 'open_settings';
const String _trayActionNewMemo = 'new_memo';
const String _trayActionExit = 'exit';

typedef TrayActionHandler = FutureOr<void> Function();

class DesktopTrayController with TrayListener {
  DesktopTrayController._();

  static final DesktopTrayController instance = DesktopTrayController._();

  bool _initialized = false;
  TrayActionHandler? _onOpenSettings;
  TrayActionHandler? _onNewMemo;
  TrayActionHandler? _onExit;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  void configureActions({
    TrayActionHandler? onOpenSettings,
    TrayActionHandler? onNewMemo,
    TrayActionHandler? onExit,
  }) {
    _onOpenSettings = onOpenSettings;
    _onNewMemo = onNewMemo;
    _onExit = onExit;
  }

  Future<void> ensureInitialized() async {
    if (!supported || _initialized) return;
    trayManager.addListener(this);
    final iconPath = Platform.isWindows
        ? 'windows/runner/resources/app_icon.ico'
        : 'assets/images/tray_icon_macos.png';
    if (Platform.isMacOS) {
      await trayManager.setIcon(iconPath, isTemplate: true, iconSize: 18);
    } else {
      await trayManager.setIcon(iconPath);
    }
    await trayManager.setToolTip('MemoFlow');
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(key: _trayActionShow, label: '\u6253\u5f00 MemoFlow'),
          MenuItem(
            key: _trayActionOpenSettings,
            label: '\u6253\u5f00\u8bbe\u7f6e',
          ),
          MenuItem(key: _trayActionNewMemo, label: '\u65b0\u5efa Memo'),
          MenuItem.separator(),
          MenuItem(key: _trayActionExit, label: '\u9000\u51fa'),
        ],
      ),
    );
    _initialized = true;
  }

  Future<void> hideToTray() async {
    await hideToStatusArea();
  }

  Future<void> hideToStatusArea() async {
    if (!supported) return;
    await ensureInitialized();
    if (Platform.isWindows || Platform.isLinux) {
      await windowManager.setSkipTaskbar(true);
    }
    await windowManager.hide();
  }

  Future<void> showFromTray() async {
    await showFromStatusArea();
  }

  Future<void> showFromStatusArea() async {
    if (!supported) return;
    await ensureInitialized();
    if (Platform.isWindows || Platform.isLinux) {
      await windowManager.setSkipTaskbar(false);
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isMacOS) {
      unawaited(trayManager.popUpContextMenu());
      return;
    }
    unawaited(_toggleByTrayIcon());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _trayActionShow:
        unawaited(showFromStatusArea());
        return;
      case _trayActionOpenSettings:
        unawaited(_invokeWithForeground(_onOpenSettings));
        return;
      case _trayActionNewMemo:
        unawaited(_invokeWithForeground(_onNewMemo));
        return;
      case _trayActionExit:
        if (_onExit != null) {
          unawaited(Future.sync(() => _onExit?.call()));
        } else {
          unawaited(_exitFromTray());
        }
        return;
      default:
        return;
    }
  }

  Future<void> _invokeWithForeground(TrayActionHandler? action) async {
    await showFromStatusArea();
    await action?.call();
  }

  Future<void> _toggleByTrayIcon() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await hideToStatusArea();
      return;
    }
    await showFromStatusArea();
  }

  Future<void> _exitFromTray() async {
    if (Platform.isWindows || Platform.isLinux) {
      await windowManager.setSkipTaskbar(false);
    }
    if (Platform.isMacOS) {
      await windowManager.destroy();
      return;
    }
    await windowManager.close();
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
    _initialized = false;
  }
}
