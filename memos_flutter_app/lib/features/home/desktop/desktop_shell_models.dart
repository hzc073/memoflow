import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/desktop/desktop_surface_policy.dart';

enum DesktopShellSecondaryPanePresentation { inline, overlay }

extension DesktopShellSecondaryPanePresentationPolicy
    on DesktopShellSecondaryPanePresentation {
  DesktopPanePresentation get policyPresentation {
    return switch (this) {
      DesktopShellSecondaryPanePresentation.inline =>
        DesktopPanePresentation.inline,
      DesktopShellSecondaryPanePresentation.overlay =>
        DesktopPanePresentation.overlay,
    };
  }
}

@immutable
class DesktopShellSecondaryPaneMotionSpec {
  const DesktopShellSecondaryPaneMotionSpec({
    required this.resizeDuration,
    required this.surfaceEnterDuration,
    required this.surfaceExitDuration,
    required this.resizeCurve,
    required this.surfaceEnterCurve,
    required this.surfaceExitCurve,
    required this.surfaceEntryOffset,
    required this.surfaceEntryScale,
  });

  static const DesktopShellSecondaryPaneMotionSpec standard =
      DesktopShellSecondaryPaneMotionSpec(
        resizeDuration: AppMotion.desktopContent,
        surfaceEnterDuration: AppMotion.desktopContent,
        surfaceExitDuration: AppMotion.desktopOverlayExit,
        resizeCurve: AppMotion.standardCurve,
        surfaceEnterCurve: AppMotion.emphasizedEnterCurve,
        surfaceExitCurve: AppMotion.emphasizedExitCurve,
        surfaceEntryOffset: AppMotion.windowsPaneEntryOffset,
        surfaceEntryScale: 0.985,
      );

  final Duration resizeDuration;
  final Duration surfaceEnterDuration;
  final Duration surfaceExitDuration;
  final Curve resizeCurve;
  final Curve surfaceEnterCurve;
  final Curve surfaceExitCurve;
  final Offset surfaceEntryOffset;
  final double surfaceEntryScale;
}

@immutable
class DesktopShellModalSurfaceMotionSpec {
  const DesktopShellModalSurfaceMotionSpec({
    required this.backdropEnterDuration,
    required this.backdropExitDuration,
    required this.surfaceEnterDuration,
    required this.surfaceExitDuration,
    required this.backdropCurve,
    required this.surfaceEnterCurve,
    required this.surfaceExitCurve,
    required this.surfaceEntryOffset,
    required this.surfaceEntryScale,
  });

  static const DesktopShellModalSurfaceMotionSpec standard =
      DesktopShellModalSurfaceMotionSpec(
        backdropEnterDuration: AppMotion.desktopEditorBackdropEnter,
        backdropExitDuration: AppMotion.desktopEditorBackdropExit,
        surfaceEnterDuration: AppMotion.desktopEditorModalEnter,
        surfaceExitDuration: AppMotion.desktopEditorModalExit,
        backdropCurve: AppMotion.standardCurve,
        surfaceEnterCurve: AppMotion.emphasizedEnterCurve,
        surfaceExitCurve: AppMotion.emphasizedExitCurve,
        surfaceEntryOffset: Offset(0, 0.015),
        surfaceEntryScale: 0.985,
      );

  final Duration backdropEnterDuration;
  final Duration backdropExitDuration;
  final Duration surfaceEnterDuration;
  final Duration surfaceExitDuration;
  final Curve backdropCurve;
  final Curve surfaceEnterCurve;
  final Curve surfaceExitCurve;
  final Offset surfaceEntryOffset;
  final double surfaceEntryScale;
}
