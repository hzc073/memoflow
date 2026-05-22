import 'package:flutter/material.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';

class MemoDetailView extends StatelessWidget {
  const MemoDetailView({
    super.key,
    required this.backgroundColor,
    required this.child,
    this.embedded = false,
    this.embeddedHeader,
    this.title,
    this.actions,
    this.backgroundChild,
  });

  final Color backgroundColor;
  final Widget child;
  final bool embedded;
  final Widget? embeddedHeader;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? backgroundChild;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return ColoredBox(
        color: backgroundColor,
        child: Column(
          children: [
            if (embeddedHeader != null) embeddedHeader!,
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: resolveDesktopRouteAutomaticallyImplyLeading(
          context: context,
          automaticallyImplyLeading: true,
        ),
        title: title,
        actions: actions,
      ),
      body: Stack(
        children: [
          if (backgroundChild != null) Positioned.fill(child: backgroundChild!),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
