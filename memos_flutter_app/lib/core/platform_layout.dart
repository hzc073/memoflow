import 'package:flutter/foundation.dart';

const double kMemoFlowDesktopSidePaneBreakpoint = 1100;
const double kMemoFlowDesktopDrawerWidth = 320;
const double kMemoFlowDesktopContentMaxWidth = 980;
const double kMemoFlowDesktopMemoCardMaxWidth = 760;
const double kMemoFlowInlineComposeBreakpoint = 760;

bool isDesktopTargetPlatform([TargetPlatform? platform]) {
  final value = platform ?? defaultTargetPlatform;
  return value == TargetPlatform.windows ||
      value == TargetPlatform.macOS ||
      value == TargetPlatform.linux;
}

bool shouldUseDesktopSidePaneLayout(
  double width, {
  double breakpoint = kMemoFlowDesktopSidePaneBreakpoint,
}) {
  return isDesktopTargetPlatform() && width >= breakpoint;
}

bool shouldUseInlineComposeLayout(
  double width, {
  double breakpoint = kMemoFlowInlineComposeBreakpoint,
}) {
  // Enable for desktop and wide tablet-like layouts.
  return width >= breakpoint;
}
