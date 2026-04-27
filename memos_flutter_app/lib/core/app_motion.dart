import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration route = Duration(milliseconds: 260);
  static const Duration exit = Duration(milliseconds: 180);
  static const Duration desktopContent = Duration(milliseconds: 280);
  static const Duration desktopPreviewSwap = Duration(milliseconds: 300);
  static const Duration desktopOverlayEnter = Duration(milliseconds: 260);
  static const Duration desktopOverlayExit = Duration(milliseconds: 200);
  static const Duration desktopPreviewPaneEnter = Duration(milliseconds: 760);
  static const Duration desktopPreviewPaneResize = Duration(milliseconds: 680);
  static const Duration desktopPreviewPaneExit = Duration(milliseconds: 180);
  static const Duration desktopPreviewInitialLoaderMin = Duration(
    milliseconds: 760,
  );
  static const Duration desktopPreviewSwapLoaderMin = Duration(
    milliseconds: 140,
  );
  static const Duration desktopPreviewContentReveal = Duration(
    milliseconds: 160,
  );
  static const Duration desktopPreviewLoaderPulse = Duration(milliseconds: 900);
  static const Duration desktopPressDown = Duration(milliseconds: 90);
  static const Duration desktopPressUp = Duration(milliseconds: 170);
  static const Duration windowsHover = Duration(milliseconds: 120);
  static const Duration windowsSelection = Duration(milliseconds: 140);
  static const Duration windowsPane = Duration(milliseconds: 180);
  static const Duration windowsDialog = Duration(milliseconds: 160);
  static const Duration desktopEditorBackdropEnter = Duration(
    milliseconds: 160,
  );
  static const Duration desktopEditorBackdropExit = Duration(milliseconds: 140);
  static const Duration desktopEditorModalEnter = Duration(milliseconds: 220);
  static const Duration desktopEditorModalExit = Duration(milliseconds: 180);
  static const Duration desktopEditorFullscreenMorph = Duration(
    milliseconds: 240,
  );

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedEnterCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve emphasizedExitCurve = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve desktopPreviewRevealCurve = Cubic(0.18, 0.72, 0.22, 1.0);
  static const Curve desktopPreviewResizeCurve = Cubic(0.16, 0.74, 0.2, 1.0);
  static const Curve desktopPreviewSwapCurve = Cubic(0.26, 0.82, 0.24, 1.0);

  static const Offset verticalEntryOffset = Offset(0, 0.02);
  static const Offset horizontalEntryOffset = Offset(0.02, 0);
  static const double entryScaleBegin = 0.96;
  static const Offset windowsPaneEntryOffset = Offset(0.02, 0);
  static const double windowsDialogScaleBegin = 0.98;

  static bool isEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return true;
    return !(mediaQuery.disableAnimations || mediaQuery.accessibleNavigation);
  }

  static Duration effectiveDuration(BuildContext context, Duration duration) {
    return isEnabled(context) ? duration : Duration.zero;
  }
}
