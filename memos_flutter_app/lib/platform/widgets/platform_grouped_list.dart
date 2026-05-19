import 'package:flutter/cupertino.dart';

import '../platform_target.dart';

class PlatformGroupedList extends StatelessWidget {
  const PlatformGroupedList({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      return CupertinoListSection.insetGrouped(
        margin: padding,
        children: children,
      );
    }
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}
