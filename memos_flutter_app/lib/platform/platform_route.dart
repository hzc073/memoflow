import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'platform_target.dart';

Route<T> buildPlatformPageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  final target = resolvePlatformTarget(context);
  if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState,
  );
}
