import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration route = Duration(milliseconds: 260);
  static const Duration exit = Duration(milliseconds: 180);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  static const Offset verticalEntryOffset = Offset(0, 0.02);
  static const Offset horizontalEntryOffset = Offset(0.02, 0);
  static const double entryScaleBegin = 0.96;

  static bool isEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return true;
    return !(mediaQuery.disableAnimations || mediaQuery.accessibleNavigation);
  }

  static Duration effectiveDuration(BuildContext context, Duration duration) {
    return isEnabled(context) ? duration : Duration.zero;
  }
}
