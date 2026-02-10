import 'package:flutter/material.dart';

const Duration kDrawerCloseNavigationDelay = Duration(milliseconds: 220);

void closeDrawerThenPushReplacement(
  BuildContext context,
  Widget route, {
  Duration closeDelay = kDrawerCloseNavigationDelay,
}) {
  final navigator = Navigator.maybeOf(context);
  if (navigator == null || !navigator.mounted) return;

  final hasOverlayToPop = navigator.canPop();
  if (hasOverlayToPop) {
    navigator.pop();
  }

  void navigate() {
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => route),
    );
  }

  if (hasOverlayToPop && closeDelay > Duration.zero) {
    Future<void>.delayed(closeDelay, navigate);
    return;
  }

  navigate();
}
