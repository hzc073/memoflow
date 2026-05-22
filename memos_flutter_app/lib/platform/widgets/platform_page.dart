import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../platform_target.dart';

class PlatformPage extends StatelessWidget {
  const PlatformPage({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions,
    this.bottomBar,
    this.drawer,
    this.drawerEnableOpenDragGesture = true,
    this.sidebar,
    this.toolbar,
    this.safeArea = true,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.desktopNavigationMode,
    this.desktopNavigationContext,
  });

  final Widget body;
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? drawer;
  final bool drawerEnableOpenDragGesture;
  final Widget? sidebar;
  final Widget? toolbar;
  final bool safeArea;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final DesktopTitlebarNavigationMode? desktopNavigationMode;
  final DesktopTitlebarNavigationContext? desktopNavigationContext;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    final bodyWidget = safeArea ? SafeArea(child: body) : body;

    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        navigationBar:
            title == null && leading == null && (actions?.isEmpty ?? true)
            ? null
            : CupertinoNavigationBar(
                middle: title,
                leading: leading,
                trailing: actions == null
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ),
        child: Column(
          children: [
            if (toolbar != null) toolbar!,
            Expanded(child: bodyWidget),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      );
    }

    final navigationContext =
        desktopNavigationContext ??
        resolveDesktopTitlebarNavigationContext(context);
    final navigationMode =
        desktopNavigationMode ?? DesktopTitlebarNavigationMode.hidden;
    final platform = target == PlatformTarget.macOS
        ? TargetPlatform.macOS
        : Theme.of(context).platform;
    final effectiveTitle = resolveDesktopTopLevelTitle(
      platform: platform,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
      title: title,
    );
    final topLevelChromeOmitted = shouldOmitDesktopTopLevelChrome(
      platform: platform,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
    );
    final omitRouteDismissalControl =
        target == PlatformTarget.macOS &&
        shouldOmitDesktopRouteDismissalControl(
          platform: TargetPlatform.macOS,
          navigationContext: navigationContext,
        );
    final effectiveLeading = omitRouteDismissalControl || topLevelChromeOmitted
        ? null
        : leading;
    final automaticallyImplyLeading =
        !omitRouteDismissalControl && !topLevelChromeOmitted;
    final effectiveToolbarHeight = resolveDesktopTopLevelToolbarHeight(
      platform: platform,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar:
          !topLevelChromeOmitted &&
              effectiveTitle == null &&
              effectiveLeading == null &&
              (actions?.isEmpty ?? true)
          ? null
          : AppBar(
              toolbarHeight: effectiveToolbarHeight,
              title: effectiveTitle,
              leading: effectiveLeading,
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: actions,
            ),
      drawer: drawer,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      body: Column(
        children: [
          if (toolbar != null) toolbar!,
          Expanded(
            child: Row(
              children: [
                if (sidebar != null) sidebar!,
                Expanded(child: bodyWidget),
              ],
            ),
          ),
          if (bottomBar != null) bottomBar!,
        ],
      ),
    );
  }
}
