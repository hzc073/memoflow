import 'package:flutter/material.dart';

import 'platform_layout.dart';

const Duration kDrawerCloseNavigationDelay = Duration(milliseconds: 220);

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

  void navigate() {
    if (!context.mounted) return;
    final shouldSkipAnimation =
        noAnimation ||
        shouldUseDesktopSidePaneLayout(MediaQuery.sizeOf(context).width);
    final pageRoute = shouldSkipAnimation
        ? PageRouteBuilder<void>(
            pageBuilder: (_, animation, secondaryAnimation) => route,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          )
        : MaterialPageRoute<void>(builder: (_) => route);
    Navigator.of(context).pushReplacement(pageRoute);
  }

  if (hasOverlayToPop && closeDelay > Duration.zero) {
    Future<void>.delayed(closeDelay, navigate);
    return;
  }

  navigate();
}
