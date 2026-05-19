import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_target.dart';

Future<T?> showPlatformActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final target = resolvePlatformTarget(context);
  if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
    return showCupertinoModalPopup<T>(context: context, builder: builder);
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: builder,
  );
}
