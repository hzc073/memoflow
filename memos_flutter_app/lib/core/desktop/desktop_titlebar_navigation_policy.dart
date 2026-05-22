import 'package:flutter/material.dart';

import 'window_chrome_safe_area.dart';

enum DesktopTitlebarNavigationMode { expandedSidebar, rail, overlay, hidden }

enum DesktopTitlebarNavigationContext { topLevelDestination, secondaryTask }

DesktopTitlebarNavigationContext resolveDesktopTitlebarNavigationContext(
  BuildContext context,
) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isFirst) {
    return DesktopTitlebarNavigationContext.secondaryTask;
  }
  return DesktopTitlebarNavigationContext.topLevelDestination;
}

bool shouldRenderDesktopTitlebarLeadingTitle({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  if (platform == TargetPlatform.macOS &&
      navigationContext ==
          DesktopTitlebarNavigationContext.topLevelDestination &&
      navigationMode == DesktopTitlebarNavigationMode.expandedSidebar) {
    return false;
  }
  return true;
}

bool shouldOmitDesktopRouteDismissalControl({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  return platform == TargetPlatform.macOS &&
      navigationContext == DesktopTitlebarNavigationContext.secondaryTask;
}

bool shouldOmitDesktopRouteDismissalControlForContext(BuildContext context) {
  return shouldOmitDesktopRouteDismissalControl(
    platform: Theme.of(context).platform,
    navigationContext: resolveDesktopTitlebarNavigationContext(context),
  );
}

Widget? resolveDesktopRouteDismissalLeading({
  required BuildContext context,
  required Widget? leading,
}) {
  return shouldOmitDesktopRouteDismissalControlForContext(context)
      ? null
      : leading;
}

bool resolveDesktopRouteAutomaticallyImplyLeading({
  required BuildContext context,
  required bool automaticallyImplyLeading,
}) {
  return shouldOmitDesktopRouteDismissalControlForContext(context)
      ? false
      : automaticallyImplyLeading;
}

bool shouldOmitDesktopTopLevelChrome({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  return platform == TargetPlatform.macOS &&
      navigationMode == DesktopTitlebarNavigationMode.expandedSidebar &&
      navigationContext == DesktopTitlebarNavigationContext.topLevelDestination;
}

bool shouldRenderDesktopTopLevelToolbarDivider({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  return !shouldOmitDesktopTopLevelChrome(
    platform: platform,
    navigationMode: navigationMode,
    navigationContext: navigationContext,
  );
}

Widget? resolveDesktopTopLevelTitle({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
  required Widget? title,
}) {
  return shouldOmitDesktopTopLevelChrome(
        platform: platform,
        navigationMode: navigationMode,
        navigationContext: navigationContext,
      )
      ? null
      : title;
}

Widget? resolveDesktopTopLevelLeading({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
  required Widget? leading,
}) {
  return shouldOmitDesktopTopLevelChrome(
        platform: platform,
        navigationMode: navigationMode,
        navigationContext: navigationContext,
      )
      ? null
      : leading;
}

double? resolveDesktopTopLevelToolbarHeight({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  return shouldOmitDesktopTopLevelChrome(
        platform: platform,
        navigationMode: navigationMode,
        navigationContext: navigationContext,
      )
      ? kMacosTitleBarHeight
      : null;
}

@visibleForTesting
String debugDesktopTitlebarLeadingTitlePolicy({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  return shouldRenderDesktopTitlebarLeadingTitle(
        platform: platform,
        navigationMode: navigationMode,
        navigationContext: navigationContext,
      )
      ? 'visible'
      : 'hidden';
}

@visibleForTesting
String debugDesktopRouteDismissalControlPolicy({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  return shouldOmitDesktopRouteDismissalControl(
        platform: platform,
        navigationContext: navigationContext,
      )
      ? 'omitted'
      : 'visible';
}

@visibleForTesting
String debugDesktopTopLevelChromePolicy({
  required TargetPlatform platform,
  required DesktopTitlebarNavigationMode navigationMode,
  required DesktopTitlebarNavigationContext navigationContext,
}) {
  return shouldOmitDesktopTopLevelChrome(
        platform: platform,
        navigationMode: navigationMode,
        navigationContext: navigationContext,
      )
      ? 'omitted'
      : 'visible';
}
