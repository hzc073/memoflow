import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_target.dart';

class PlatformPage extends StatelessWidget {
  const PlatformPage({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions,
    this.bottomBar,
    this.drawer,
    this.drawerEnableOpenDragGesture = true,
    this.sidebar,
    this.toolbar,
    this.safeArea = true,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
  });

  final Widget body;
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? drawer;
  final bool drawerEnableOpenDragGesture;
  final Widget? sidebar;
  final Widget? toolbar;
  final bool safeArea;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    final bodyWidget = safeArea ? SafeArea(child: body) : body;

    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        navigationBar:
            title == null && leading == null && (actions?.isEmpty ?? true)
            ? null
            : CupertinoNavigationBar(
                middle: title,
                leading: leading,
                trailing: actions == null
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ),
        child: Column(
          children: [
            if (toolbar != null) toolbar!,
            Expanded(child: bodyWidget),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: title == null && leading == null && (actions?.isEmpty ?? true)
          ? null
          : AppBar(title: title, leading: leading, actions: actions),
      drawer: drawer,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      body: Column(
        children: [
          if (toolbar != null) toolbar!,
          Expanded(
            child: Row(
              children: [
                if (sidebar != null) sidebar!,
                Expanded(child: bodyWidget),
              ],
            ),
          ),
          if (bottomBar != null) bottomBar!,
        ],
      ),
    );
  }
}
