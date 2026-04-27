import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

export 'windows_desktop_workspace_shell.dart'
    show
        WindowsDesktopModalSurfaceMotionSpec,
        WindowsDesktopSecondaryPaneMotionSpec,
        WindowsDesktopSecondaryPanePresentation;

import '../../../core/platform_layout.dart';
import '../app_drawer.dart';
import '../app_drawer_menu_button.dart';
import '../../../i18n/strings.g.dart';
import 'windows_desktop_command_bar.dart';
import 'windows_desktop_workspace_shell.dart';

typedef WindowsDesktopNavigationBuilder =
    Widget Function(AppDrawerViewMode viewMode, bool embedded);

class WindowsDesktopPageShell extends StatefulWidget {
  const WindowsDesktopPageShell({
    super.key,
    required this.navigationBuilder,
    required this.leadingTitle,
    required this.body,
    this.commandBar,
    this.center,
    this.trailing,
    this.secondaryPane,
    this.secondaryPaneVisible = false,
    this.secondaryPaneWidth = kWindowsDesktopSecondaryPaneDefaultWidth,
    this.secondaryPanePresentation =
        WindowsDesktopSecondaryPanePresentation.inline,
    this.secondaryPaneMotionSpec,
    this.onSecondaryPaneWidthChanged,
    this.modalSurface,
    this.modalSurfaceVisible = false,
    this.modalBarrierColor = const Color(0x66000000),
    this.modalBarrierBlurSigma = 14,
    this.modalSurfaceMotionSpec,
    this.backgroundColor,
    this.showWindowControls = true,
  });

  final WindowsDesktopNavigationBuilder navigationBuilder;
  final Widget leadingTitle;
  final Widget body;
  final Widget? commandBar;
  final Widget? center;
  final Widget? trailing;
  final Widget? secondaryPane;
  final bool secondaryPaneVisible;
  final double secondaryPaneWidth;
  final WindowsDesktopSecondaryPanePresentation secondaryPanePresentation;
  final WindowsDesktopSecondaryPaneMotionSpec? secondaryPaneMotionSpec;
  final ValueChanged<double>? onSecondaryPaneWidthChanged;
  final Widget? modalSurface;
  final bool modalSurfaceVisible;
  final Color modalBarrierColor;
  final double modalBarrierBlurSigma;
  final WindowsDesktopModalSurfaceMotionSpec? modalSurfaceMotionSpec;
  final Color? backgroundColor;
  final bool showWindowControls;

  @override
  State<WindowsDesktopPageShell> createState() =>
      _WindowsDesktopPageShellState();
}

class _WindowsDesktopPageShellState extends State<WindowsDesktopPageShell> {
  bool _overlayNavigationVisible = false;
  bool _desktopWindowMaximized = false;
  bool _syncedWindowState = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedWindowState) {
      return;
    }
    _syncedWindowState = true;
    unawaited(_syncWindowState());
  }

  Future<void> _syncWindowState() async {
    if (kIsWeb || !widget.showWindowControls) {
      return;
    }
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.windows) {
      return;
    }
    final maximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    if (kIsWeb || !widget.showWindowControls) {
      return;
    }
    if (_desktopWindowMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    if (!mounted) return;
    final maximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = maximized);
  }

  Future<void> _minimize() async {
    if (kIsWeb || !widget.showWindowControls) {
      return;
    }
    await windowManager.minimize();
  }

  Future<void> _closeWindow() async {
    if (kIsWeb || !widget.showWindowControls) {
      return;
    }
    await windowManager.close();
  }

  void _toggleOverlayNavigation() {
    setState(() => _overlayNavigationVisible = !_overlayNavigationVisible);
  }

  void _closeOverlayNavigation() {
    if (!_overlayNavigationVisible) return;
    setState(() => _overlayNavigationVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final layoutSpec = resolveWindowsDesktopLayout(
      MediaQuery.sizeOf(context).width,
      platform: platform,
    );
    final textColor = Theme.of(context).colorScheme.onSurface;
    final backgroundColor =
        widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    final navigation = switch (layoutSpec.navMode) {
      WindowsDesktopNavMode.overlay => const SizedBox.shrink(),
      WindowsDesktopNavMode.rail => widget.navigationBuilder(
        AppDrawerViewMode.rail,
        true,
      ),
      WindowsDesktopNavMode.expanded => widget.navigationBuilder(
        AppDrawerViewMode.expandedSidebar,
        true,
      ),
    };

    final overlayNavigation =
        layoutSpec.navMode == WindowsDesktopNavMode.overlay &&
            _overlayNavigationVisible
        ? Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeOverlayNavigation,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.16),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: widget.navigationBuilder(
                  AppDrawerViewMode.overlayPanel,
                  true,
                ),
              ),
            ],
          )
        : null;

    final resolvedCommandBar =
        widget.commandBar ??
        WindowsDesktopCommandBar(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (layoutSpec.navMode == WindowsDesktopNavMode.overlay) ...[
                AppDrawerMenuButton(
                  tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                  iconColor: textColor,
                  badgeBorderColor: backgroundColor,
                  onPressed: _toggleOverlayNavigation,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: widget.leadingTitle),
            ],
          ),
          center: widget.center ?? const SizedBox.shrink(),
          trailing: widget.trailing ?? const SizedBox.shrink(),
          desktopWindowMaximized: _desktopWindowMaximized,
          showWindowControls: widget.showWindowControls,
          onMinimize: () => unawaited(_minimize()),
          onToggleMaximize: () => unawaited(_toggleMaximize()),
          onClose: () => unawaited(_closeWindow()),
          minimizeTooltip: context.t.strings.legacy.msg_minimize,
          maximizeTooltip: context.t.strings.legacy.msg_maximize,
          restoreTooltip: context.t.strings.legacy.msg_restore_window,
          closeTooltip: context.t.strings.legacy.msg_close,
        );

    return WindowsDesktopWorkspaceShell(
      layoutSpec: layoutSpec,
      navigation: navigation,
      commandBar: resolvedCommandBar,
      body: widget.body,
      overlayNavigation: overlayNavigation,
      secondaryPane: widget.secondaryPane,
      secondaryPaneVisible: widget.secondaryPaneVisible,
      secondaryPaneWidth: widget.secondaryPaneWidth,
      secondaryPanePresentation: widget.secondaryPanePresentation,
      secondaryPaneMotionSpec: widget.secondaryPaneMotionSpec,
      onSecondaryPaneWidthChanged: widget.onSecondaryPaneWidthChanged,
      modalSurface: widget.modalSurface,
      modalSurfaceVisible: widget.modalSurfaceVisible,
      modalBarrierColor: widget.modalBarrierColor,
      modalBarrierBlurSigma: widget.modalBarrierBlurSigma,
      modalSurfaceMotionSpec: widget.modalSurfaceMotionSpec,
    );
  }
}
