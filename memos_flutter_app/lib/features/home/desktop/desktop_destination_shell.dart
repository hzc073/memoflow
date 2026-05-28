import 'package:flutter/material.dart';

import '../../../core/platform_layout.dart'
    show kWindowsDesktopSecondaryPaneDefaultWidth;
import '../app_drawer.dart';
import 'desktop_shell_host.dart';

export 'desktop_shell_host.dart'
    show
        DesktopShellModalSurfaceMotionSpec,
        DesktopShellSecondaryPaneMotionSpec,
        DesktopShellSecondaryPanePresentation,
        DesktopTitlebarNavigationContext,
        DesktopTitlebarNavigationMode,
        resolveDesktopTopLevelLeading,
        resolveDesktopTopLevelTitle,
        resolveDesktopTopLevelToolbarHeight,
        shouldOmitDesktopTopLevelChrome,
        shouldRenderDesktopTopLevelToolbarDivider;

class DesktopDestinationDismissalIntent {
  const DesktopDestinationDismissalIntent({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
}

class DesktopDestinationShell extends StatelessWidget {
  const DesktopDestinationShell({
    super.key,
    required this.selectedDestination,
    required this.onSelectDestination,
    required this.title,
    required this.body,
    required this.fallback,
    this.onSelectTag,
    this.onOpenNotifications,
    this.actions = const <Widget>[],
    this.trailing,
    this.center,
    this.commandBar,
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
    this.navigationContext =
        DesktopTitlebarNavigationContext.topLevelDestination,
    this.dismissalIntent,
  });

  final AppDrawerDestination selectedDestination;
  final ValueChanged<AppDrawerDestination> onSelectDestination;
  final ValueChanged<String>? onSelectTag;
  final VoidCallback? onOpenNotifications;
  final Widget title;
  final Widget body;
  final Widget fallback;
  final List<Widget> actions;
  final Widget? trailing;
  final Widget? center;
  final Widget? commandBar;
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
  final DesktopTitlebarNavigationContext navigationContext;
  final DesktopDestinationDismissalIntent? dismissalIntent;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.windows &&
        platform != TargetPlatform.macOS) {
      return fallback;
    }

    return DesktopShellHost(
      backgroundColor: backgroundColor,
      navigationBuilder: (viewMode, embedded) => AppDrawer(
        selected: selectedDestination,
        onSelect: onSelectDestination,
        onSelectTag: onSelectTag,
        onOpenNotifications: onOpenNotifications,
        embedded: embedded,
        viewMode: viewMode,
      ),
      leadingTitle: _DesktopDestinationLeadingTitle(
        title: title,
        dismissalIntent: dismissalIntent,
      ),
      commandBar: commandBar,
      center: center,
      trailing: _resolveTrailing(),
      body: body,
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
      showWindowControls: showWindowControls,
      navigationContext: navigationContext,
    );
  }

  Widget? _resolveTrailing() {
    final explicitTrailing = trailing;
    if (explicitTrailing != null) {
      return explicitTrailing;
    }
    if (actions.isEmpty) {
      return null;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}

class _DesktopDestinationLeadingTitle extends StatelessWidget {
  const _DesktopDestinationLeadingTitle({
    required this.title,
    required this.dismissalIntent,
  });

  final Widget title;
  final DesktopDestinationDismissalIntent? dismissalIntent;

  @override
  Widget build(BuildContext context) {
    final intent = dismissalIntent;
    if (intent == null) {
      return title;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: intent.tooltip,
          icon: Icon(intent.icon),
          onPressed: intent.onPressed,
        ),
        const SizedBox(width: 4),
        Flexible(child: title),
      ],
    );
  }
}
