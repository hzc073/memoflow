import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum PlatformTarget { android, iPhone, iPad, macOS, windows, linux, web }

@visibleForTesting
TargetPlatform? debugPlatformTargetOverride;

TargetPlatform get _resolvedTargetPlatform {
  return debugPlatformTargetOverride ?? defaultTargetPlatform;
}

bool isApplePlatform([TargetPlatform? platform]) {
  final resolved = platform ?? _resolvedTargetPlatform;
  return resolved == TargetPlatform.iOS || resolved == TargetPlatform.macOS;
}

bool isAppleDesktopPlatform([TargetPlatform? platform]) {
  final resolved = platform ?? _resolvedTargetPlatform;
  return resolved == TargetPlatform.macOS;
}

bool isAppleMobilePlatform([TargetPlatform? platform]) {
  final resolved = platform ?? _resolvedTargetPlatform;
  return resolved == TargetPlatform.iOS;
}

bool isDesktopPlatform([TargetPlatform? platform]) {
  final resolved = platform ?? _resolvedTargetPlatform;
  return resolved == TargetPlatform.macOS ||
      resolved == TargetPlatform.windows ||
      resolved == TargetPlatform.linux;
}

bool isWindowsPlatform([TargetPlatform? platform]) {
  final resolved = platform ?? _resolvedTargetPlatform;
  return resolved == TargetPlatform.windows;
}

bool isLinuxPlatform([TargetPlatform? platform]) {
  final resolved = platform ?? _resolvedTargetPlatform;
  return resolved == TargetPlatform.linux;
}

bool isTabletAppleLayout(BuildContext context) {
  if (kIsWeb) return false;
  if (_resolvedTargetPlatform != TargetPlatform.iOS) return false;
  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  return shortestSide >= 600;
}

PlatformTarget resolvePlatformTarget(BuildContext context) {
  if (kIsWeb) return PlatformTarget.web;
  final platform = _resolvedTargetPlatform;
  return switch (platform) {
    TargetPlatform.android => PlatformTarget.android,
    TargetPlatform.iOS =>
      isTabletAppleLayout(context)
          ? PlatformTarget.iPad
          : PlatformTarget.iPhone,
    TargetPlatform.macOS => PlatformTarget.macOS,
    TargetPlatform.windows => PlatformTarget.windows,
    TargetPlatform.linux => PlatformTarget.linux,
    TargetPlatform.fuchsia => PlatformTarget.android,
  };
}

bool isAppleTabletTarget(BuildContext context) {
  return resolvePlatformTarget(context) == PlatformTarget.iPad;
}
