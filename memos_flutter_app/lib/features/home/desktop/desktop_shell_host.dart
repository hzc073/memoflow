import 'package:flutter/material.dart';

import '../../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../../core/platform_layout.dart';
import '../app_drawer.dart';
import 'apple_macos_page_shell.dart';
import 'desktop_shell_models.dart';
import 'windows_desktop_page_shell.dart';
export 'desktop_shell_models.dart'
    show
        DesktopShellModalSurfaceMotionSpec,
        DesktopShellSecondaryPaneMotionSpec,
        DesktopShellSecondaryPanePresentation;
export '../../../core/desktop/desktop_titlebar_navigation_policy.dart'
    show
        DesktopTitlebarNavigationContext,
        DesktopTitlebarNavigationMode,
        resolveDesktopTopLevelLeading,
        resolveDesktopTopLevelTitle,
        resolveDesktopTopLevelToolbarHeight,
        resolveDesktopRouteAutomaticallyImplyLeading,
        resolveDesktopRouteDismissalLeading,
        shouldOmitDesktopTopLevelChrome,
        shouldRenderDesktopTopLevelToolbarDivider;

typedef DesktopShellNavigationBuilder =
    Widget Function(AppDrawerViewMode viewMode, bool embedded);

class DesktopShellHost extends StatelessWidget {
  const DesktopShellHost({
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
        DesktopShellSecondaryPanePresentation.inline,
    this.secondaryPaneMotionSpec,
    this.onSecondaryPaneWidthChanged,
    this.modalSurface,
    this.modalSurfaceVisible = false,
    this.modalBarrierColor = const Color(0x66000000),
    this.modalBarrierBlurSigma = 14,
    this.modalSurfaceMotionSpec,
    this.backgroundColor,
    this.showWindowControls = true,
    this.navigationContext,
  });

  final DesktopShellNavigationBuilder navigationBuilder;
  final Widget leadingTitle;
  final Widget body;
  final Widget? commandBar;
  final Widget? center;
  final Widget? trailing;
  final Widget? secondaryPane;
  final bool secondaryPaneVisible;
  final double secondaryPaneWidth;
  final DesktopShellSecondaryPanePresentation secondaryPanePresentation;
  final DesktopShellSecondaryPaneMotionSpec? secondaryPaneMotionSpec;
  final ValueChanged<double>? onSecondaryPaneWidthChanged;
  final Widget? modalSurface;
  final bool modalSurfaceVisible;
  final Color modalBarrierColor;
  final double modalBarrierBlurSigma;
  final DesktopShellModalSurfaceMotionSpec? modalSurfaceMotionSpec;
  final Color? backgroundColor;
  final bool showWindowControls;
  final DesktopTitlebarNavigationContext? navigationContext;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.macOS) {
      return AppleMacosPageShell(
        navigationBuilder: navigationBuilder,
        leadingTitle: leadingTitle,
        body: body,
        navigationContext:
            navigationContext ??
            resolveDesktopTitlebarNavigationContext(context),
        commandBar: commandBar,
        center: center,
        trailing: trailing,
        secondaryPane: secondaryPane,
        secondaryPaneVisible: secondaryPaneVisible,
        secondaryPaneWidth: secondaryPaneWidth,
        secondaryPanePresentation: secondaryPanePresentation,
        secondaryPaneMotionSpec: secondaryPaneMotionSpec,
        onSecondaryPaneWidthChanged: onSecondaryPaneWidthChanged,
        modalSurface: modalSurface,
        modalSurfaceVisible: modalSurfaceVisible,
        modalBarrierColor: modalBarrierColor,
        modalBarrierBlurSigma: modalBarrierBlurSigma,
        modalSurfaceMotionSpec: modalSurfaceMotionSpec,
        backgroundColor: backgroundColor,
      );
    }

    return WindowsDesktopPageShell(
      navigationBuilder: navigationBuilder,
      leadingTitle: leadingTitle,
      body: body,
      commandBar: commandBar,
      center: center,
      trailing: trailing,
      secondaryPane: secondaryPane,
      secondaryPaneVisible: secondaryPaneVisible,
      secondaryPaneWidth: secondaryPaneWidth,
      secondaryPanePresentation: secondaryPanePresentation,
      secondaryPaneMotionSpec: secondaryPaneMotionSpec,
      onSecondaryPaneWidthChanged: onSecondaryPaneWidthChanged,
      modalSurface: modalSurface,
      modalSurfaceVisible: modalSurfaceVisible,
      modalBarrierColor: modalBarrierColor,
      modalBarrierBlurSigma: modalBarrierBlurSigma,
      modalSurfaceMotionSpec: modalSurfaceMotionSpec,
      backgroundColor: backgroundColor,
      showWindowControls: showWindowControls,
    );
  }
}
