import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_target.dart';

Future<T?> showPlatformActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color? backgroundColor,
  Color? barrierColor,
  bool showDragHandle = true,
}) {
  final target = resolvePlatformTarget(context);
  if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: builder(context),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    showDragHandle: showDragHandle,
    builder: builder,
  );
}
