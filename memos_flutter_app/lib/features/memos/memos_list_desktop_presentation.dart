import 'package:flutter/foundation.dart';

import '../../core/platform_layout.dart';

enum MemosListDesktopTitlebarStrategy { none, windowsCommandBar, macosToolbar }

enum MemosListDesktopSearchPresentation { standard, header }

enum MemosListDesktopComposePresentation { sheet, desktopSurface }

enum MemosListDesktopPreviewPaneActivation { unsupported, manual, automatic }

@immutable
class MemosListDesktopPreviewPanePolicy {
  const MemosListDesktopPreviewPanePolicy({
    required this.activation,
    required this.supportsPane,
  });

  const MemosListDesktopPreviewPanePolicy.unsupported()
    : activation = MemosListDesktopPreviewPaneActivation.unsupported,
      supportsPane = false;

  final MemosListDesktopPreviewPaneActivation activation;
  final bool supportsPane;

  bool get defaultMemoClickOpensPreview =>
      activation == MemosListDesktopPreviewPaneActivation.automatic;
}

@immutable
class MemosListInlineComposeCapability {
  const MemosListInlineComposeCapability({
    required this.supported,
    required this.supportsResize,
  });

  const MemosListInlineComposeCapability.unsupported()
    : supported = false,
      supportsResize = false;

  final bool supported;
  final bool supportsResize;
}

@immutable
class MemosListDesktopPresentation {
  const MemosListDesktopPresentation({
    required this.platform,
    required this.layoutTier,
    required this.navigationMode,
    required this.supportsSidePane,
    required this.titlebarStrategy,
    required this.previewPanePolicy,
    required this.searchPresentation,
    required this.composePresentation,
    required this.inlineComposeCapability,
  });

  factory MemosListDesktopPresentation.fallback({
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return MemosListDesktopPresentation(
      platform: platform,
      layoutTier: DesktopLayoutTier.narrow,
      navigationMode: DesktopNavigationMode.overlay,
      supportsSidePane: false,
      titlebarStrategy: MemosListDesktopTitlebarStrategy.none,
      previewPanePolicy: const MemosListDesktopPreviewPanePolicy.unsupported(),
      searchPresentation: MemosListDesktopSearchPresentation.standard,
      composePresentation: MemosListDesktopComposePresentation.sheet,
      inlineComposeCapability:
          const MemosListInlineComposeCapability.unsupported(),
    );
  }

  final TargetPlatform platform;
  final DesktopLayoutTier layoutTier;
  final DesktopNavigationMode navigationMode;
  final bool supportsSidePane;
  final MemosListDesktopTitlebarStrategy titlebarStrategy;
  final MemosListDesktopPreviewPanePolicy previewPanePolicy;
  final MemosListDesktopSearchPresentation searchPresentation;
  final MemosListDesktopComposePresentation composePresentation;
  final MemosListInlineComposeCapability inlineComposeCapability;

  bool get usesWindowsDesktopHeader =>
      titlebarStrategy == MemosListDesktopTitlebarStrategy.windowsCommandBar;

  bool get usesMacosDesktopTitleBar =>
      titlebarStrategy == MemosListDesktopTitlebarStrategy.macosToolbar;

  bool get usesDesktopHeaderSearch =>
      searchPresentation == MemosListDesktopSearchPresentation.header;

  bool get usesDesktopComposeSurface =>
      composePresentation == MemosListDesktopComposePresentation.desktopSurface;
}

MemosListDesktopPresentation resolveMemosListDesktopPresentation({
  required double screenWidth,
  required bool showDrawer,
  TargetPlatform? platform,
}) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final isWindows = resolvedPlatform == TargetPlatform.windows;
  final isMacos = resolvedPlatform == TargetPlatform.macOS;
  final isAdaptedDesktop = isWindows || isMacos;
  if (!isAdaptedDesktop) {
    return MemosListDesktopPresentation.fallback(platform: resolvedPlatform);
  }

  final layoutSpec = resolveDesktopLayoutPolicy(
    screenWidth,
    platform: resolvedPlatform,
  );
  final memoListLayout = resolveDesktopMemoListLayout(
    screenWidth,
    platform: resolvedPlatform,
  );
  final supportsSidePane =
      showDrawer && screenWidth >= kMemoFlowDesktopSidePaneBreakpoint;
  final supportsPreviewPane =
      supportsSidePane && memoListLayout.supportsPreviewPane;
  final previewActivation = supportsPreviewPane
      ? (memoListLayout.defaultMemoClickOpensPreview
            ? MemosListDesktopPreviewPaneActivation.automatic
            : MemosListDesktopPreviewPaneActivation.manual)
      : MemosListDesktopPreviewPaneActivation.unsupported;

  return MemosListDesktopPresentation(
    platform: resolvedPlatform,
    layoutTier: layoutSpec.tier,
    navigationMode: layoutSpec.navMode,
    supportsSidePane: supportsSidePane,
    titlebarStrategy: isWindows
        ? MemosListDesktopTitlebarStrategy.windowsCommandBar
        : (showDrawer
              ? MemosListDesktopTitlebarStrategy.macosToolbar
              : MemosListDesktopTitlebarStrategy.none),
    previewPanePolicy: MemosListDesktopPreviewPanePolicy(
      activation: previewActivation,
      supportsPane: supportsPreviewPane,
    ),
    searchPresentation: MemosListDesktopSearchPresentation.standard,
    composePresentation: isWindows || isMacos
        ? MemosListDesktopComposePresentation.desktopSurface
        : MemosListDesktopComposePresentation.sheet,
    inlineComposeCapability: MemosListInlineComposeCapability(
      supported: shouldUseInlineComposeLayout(screenWidth),
      supportsResize: true,
    ),
  );
}
