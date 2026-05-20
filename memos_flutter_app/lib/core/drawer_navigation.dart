import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/desktop/desktop_settings_window.dart';
import 'app_motion.dart';
import 'app_route_transitions.dart';
import 'platform_layout.dart';

const Duration kDrawerCloseNavigationDelay = AppMotion.medium;

void closeDrawerThenPushReplacement(
  BuildContext context,
  Widget route, {
  Duration closeDelay = kDrawerCloseNavigationDelay,
  bool noAnimation = false,
}) {
  final navigator = Navigator.maybeOf(context);
  if (navigator == null || !navigator.mounted) return;

  final hasOverlayToPop = navigator.canPop();
  if (hasOverlayToPop) {
    navigator.pop();
  }

  Future<void> navigate() async {
    if (!context.mounted) return;
    if (route is DesktopSettingsWindowRouteIntent) {
      final result = await openDesktopSettingsWindow(feedbackContext: context);
      if (result.opened) return;
    }
    if (!context.mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(width);
    final isWindowsDesktop =
        defaultTargetPlatform == TargetPlatform.windows && useDesktopSidePane;
    final shouldSkipAnimation = noAnimation || useDesktopSidePane;
    final pageRoute = isWindowsDesktop
        ? buildDesktopSharedAxisRoute<void>(
            context: context,
            builder: (_) => route,
            enabled: !noAnimation,
          )
        : buildFadeSlideRoute<void>(
            context: context,
            builder: (_) => route,
            enabled: !shouldSkipAnimation,
          );
    Navigator.of(context).pushReplacement(pageRoute);
  }

  if (hasOverlayToPop && closeDelay > Duration.zero) {
    unawaited(Future<void>.delayed(closeDelay, navigate));
    return;
  }

  unawaited(navigate());
}
