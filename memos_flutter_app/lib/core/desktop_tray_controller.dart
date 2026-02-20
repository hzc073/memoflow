import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const String _trayActionShow = 'show';
const String _trayActionHide = 'hide';
const String _trayActionExit = 'exit';

class DesktopTrayController with TrayListener {
  DesktopTrayController._();

  static final DesktopTrayController instance = DesktopTrayController._();

  bool _initialized = false;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> ensureInitialized() async {
    if (!supported || _initialized) return;
    trayManager.addListener(this);
    final iconPath = Platform.isWindows
        ? 'windows/runner/resources/app_icon.ico'
        : 'assets/images/default_avatar.webp';
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('MemoFlow');
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(key: _trayActionShow, label: '显示 MemoFlow'),
          MenuItem(key: _trayActionHide, label: '隐藏到托盘'),
          MenuItem.separator(),
          MenuItem(key: _trayActionExit, label: '退出'),
        ],
      ),
    );
    _initialized = true;
  }

  Future<void> hideToTray() async {
    if (!supported) return;
    await ensureInitialized();
    if (Platform.isWindows || Platform.isLinux) {
      await windowManager.setSkipTaskbar(true);
    }
    await windowManager.hide();
  }

  Future<void> showFromTray() async {
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
    unawaited(_toggleByTrayIcon());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _trayActionShow:
        unawaited(showFromTray());
        return;
      case _trayActionHide:
        unawaited(hideToTray());
        return;
      case _trayActionExit:
        unawaited(windowManager.close());
        return;
      default:
        return;
    }
  }

  Future<void> _toggleByTrayIcon() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await hideToTray();
      return;
    }
    await showFromTray();
  }
}
