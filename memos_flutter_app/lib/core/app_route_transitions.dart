import 'package:flutter/material.dart';

import 'app_motion.dart';

Route<T> buildFadeSlideRoute<T>({
  BuildContext? context,
  required WidgetBuilder builder,
  Offset beginOffset = AppMotion.horizontalEntryOffset,
  RouteSettings? settings,
  bool enabled = true,
  bool maintainState = true,
  bool fullscreenDialog = false,
}) {
  final transitionDuration = enabled && context != null
      ? AppMotion.effectiveDuration(context, AppMotion.route)
      : (enabled ? AppMotion.route : Duration.zero);
  final reverseTransitionDuration = enabled && context != null
      ? AppMotion.effectiveDuration(context, AppMotion.exit)
      : (enabled ? AppMotion.exit : Duration.zero);

  return PageRouteBuilder<T>(
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    pageBuilder: (routeContext, animation, secondaryAnimation) {
      return builder(routeContext);
    },
    transitionsBuilder: (routeContext, animation, secondaryAnimation, child) {
      if (transitionDuration == Duration.zero &&
          reverseTransitionDuration == Duration.zero) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.standardCurve,
        reverseCurve: AppMotion.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Route<T> buildDesktopSharedAxisRoute<T>({
  BuildContext? context,
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool enabled = true,
  bool maintainState = true,
  bool fullscreenDialog = false,
}) {
  final transitionDuration = enabled && context != null
      ? AppMotion.effectiveDuration(context, AppMotion.route)
      : (enabled ? AppMotion.route : Duration.zero);
  final reverseTransitionDuration = enabled && context != null
      ? AppMotion.effectiveDuration(context, AppMotion.desktopOverlayExit)
      : (enabled ? AppMotion.desktopOverlayExit : Duration.zero);

  return PageRouteBuilder<T>(
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    pageBuilder: (routeContext, animation, secondaryAnimation) {
      return builder(routeContext);
    },
    transitionsBuilder: (routeContext, animation, secondaryAnimation, child) {
      if (transitionDuration == Duration.zero &&
          reverseTransitionDuration == Duration.zero) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasizedEnterCurve,
        reverseCurve: AppMotion.emphasizedExitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

Route<T> buildDialogScaleRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color barrierColor = const Color(0x59000000),
  RouteSettings? settings,
}) {
  final transitionDuration = AppMotion.effectiveDuration(
    context,
    AppMotion.medium,
  );

  return RawDialogRoute<T>(
    settings: settings,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    pageBuilder: (routeContext, animation, secondaryAnimation) {
      return builder(routeContext);
    },
    transitionBuilder: (routeContext, animation, secondaryAnimation, child) {
      if (transitionDuration == Duration.zero) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.standardCurve,
        reverseCurve: AppMotion.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: AppMotion.entryScaleBegin,
            end: 1,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
