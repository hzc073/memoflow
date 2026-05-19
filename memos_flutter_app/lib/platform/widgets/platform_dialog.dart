import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_target.dart';

Future<T?> showPlatformDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
}) {
  final target = resolvePlatformTarget(context);
  if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    builder: builder,
  );
}
