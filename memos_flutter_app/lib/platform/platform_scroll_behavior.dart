import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'platform_target.dart';

class PlatformAppScrollBehavior extends MaterialScrollBehavior {
  const PlatformAppScrollBehavior();

  static const Set<PointerDeviceKind> appDragDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };

  @override
  Set<PointerDeviceKind> get dragDevices => appDragDevices;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final target = resolvePlatformTarget(context);
    return switch (target) {
      PlatformTarget.iPhone || PlatformTarget.iPad || PlatformTarget.macOS =>
        const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      PlatformTarget.android ||
      PlatformTarget.windows ||
      PlatformTarget.linux ||
      PlatformTarget.web => super.getScrollPhysics(context),
    };
  }
}
