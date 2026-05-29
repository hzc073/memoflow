import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/desktop/desktop_layout_policy.dart';
import '../../../core/desktop/desktop_surface_policy.dart';
import '../../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../../core/desktop/window_chrome_safe_area.dart';
import '../../../core/memoflow_palette.dart';
import '../app_drawer.dart';
import 'desktop_shell_models.dart';

typedef AppleMacosNavigationBuilder =
    Widget Function(AppDrawerViewMode viewMode, bool embedded);

class AppleMacosPageShell extends StatelessWidget {
  const AppleMacosPageShell({
    super.key,
    required this.navigationBuilder,
    required this.leadingTitle,
    required this.body,
    this.navigationContext =
        DesktopTitlebarNavigationContext.topLevelDestination,
    this.commandBar,
    this.center,
    this.trailing,
    this.secondaryPane,
    this.secondaryPaneVisible = false,
    this.secondaryPaneWidth = kWindowsDesktopSecondaryPaneDefaultWidth,
    this.secondaryPanePresentation =
        DesktopShellSecondaryPanePresentation.inline,
    this.secondaryPaneMotionSpec,
    this.onSecondaryPaneWidthChanged,
    this.modalSurface,
    this.modalSurfaceVisible = false,
    this.modalBarrierColor = const Color(0x66000000),
    this.modalBarrierBlurSigma = 14,
    this.modalSurfaceMotionSpec,
    this.backgroundColor,
  });

  final AppleMacosNavigationBuilder navigationBuilder;
  final Widget leadingTitle;
  final Widget body;
  final DesktopTitlebarNavigationContext navigationContext;
  final Widget? commandBar;
  final Widget? center;
  final Widget? trailing;
  final Widget? secondaryPane;
  final bool secondaryPaneVisible;
  final double secondaryPaneWidth;
  final DesktopShellSecondaryPanePresentation secondaryPanePresentation;
  final DesktopShellSecondaryPaneMotionSpec? secondaryPaneMotionSpec;
  final ValueChanged<double>? onSecondaryPaneWidthChanged;
  final Widget? modalSurface;
  final bool modalSurfaceVisible;
  final Color modalBarrierColor;
  final double modalBarrierBlurSigma;
  final DesktopShellModalSurfaceMotionSpec? modalSurfaceMotionSpec;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final layoutSpec = resolveDesktopLayoutPolicy(
      width,
      platform: TargetPlatform.macOS,
    );
    final useExpandedSidebar =
        layoutSpec.navMode == DesktopNavigationMode.expanded;
    final surfacePolicy = resolveDesktopSurfacePolicy(
      platform: TargetPlatform.macOS,
      layoutSpec: layoutSpec,
      secondaryPaneAvailable: secondaryPane != null,
      secondaryPaneVisible: secondaryPaneVisible,
      secondaryPaneWidth: secondaryPaneWidth,
      requestedSecondaryPanePresentation:
          secondaryPanePresentation.policyPresentation,
      secondaryPaneResizeRequested: onSecondaryPaneWidthChanged != null,
      modalSurfaceAvailable: modalSurface != null,
      modalSurfaceVisible: modalSurfaceVisible,
      modalBarrierColor: modalBarrierColor,
      modalBarrierBlurSigma: modalBarrierBlurSigma,
    );
    final navigationWidth = useExpandedSidebar
        ? kMemoFlowDesktopDrawerWidth
        : kWindowsDesktopRailWidth;
    final chromeInsets = resolveDesktopWindowChromeInsets(
      platform: TargetPlatform.macOS,
      contentExtendsIntoTitleBar: true,
    );
    final trafficLightSafeInset =
        chromeInsets.leading +
        resolveMacosTrafficLightCompensation(
          currentLeadingWidth: chromeInsets.leading,
        );
    final navigation = navigationBuilder(
      useExpandedSidebar
          ? AppDrawerViewMode.expandedSidebar
          : AppDrawerViewMode.rail,
      true,
    );
    final navigationMode = useExpandedSidebar
        ? DesktopTitlebarNavigationMode.expandedSidebar
        : DesktopTitlebarNavigationMode.rail;
    final showLeadingTitle = shouldRenderDesktopTitlebarLeadingTitle(
      platform: TargetPlatform.macOS,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
    );
    final showToolbarDivider = shouldRenderDesktopTopLevelToolbarDivider(
      platform: TargetPlatform.macOS,
      navigationMode: navigationMode,
      navigationContext: navigationContext,
    );
    final toolbar =
        commandBar ??
        _AppleMacosToolbar(
          leadingTitle: leadingTitle,
          showLeadingTitle: showLeadingTitle,
          showDivider: showToolbarDivider,
          titleBarHeight: chromeInsets.top,
          trafficLightSafeInset: trafficLightSafeInset,
          center: center,
          trailing: trailing,
        );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBackground =
        backgroundColor ??
        (isDark
            ? MemoFlowPalette.backgroundDark
            : MemoFlowPalette.backgroundLight);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return ColoredBox(
      key: const ValueKey<String>('apple-macos-page-shell'),
      color: resolvedBackground,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                toolbar,
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: navigationWidth,
                        child: Material(
                          type: MaterialType.transparency,
                          child: navigation,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: dividerColor,
                      ),
                      Expanded(
                        child: _AppleMacosContentArea(
                          body: body,
                          secondaryPane: secondaryPane,
                          secondaryPanePolicy: surfacePolicy.secondaryPane,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (surfacePolicy.modalSurface.visible && modalSurface != null)
              Positioned.fill(
                child: _AppleMacosModalSurface(
                  barrierColor: surfacePolicy.modalSurface.barrierColor,
                  child: modalSurface!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppleMacosToolbar extends StatelessWidget {
  const _AppleMacosToolbar({
    required this.leadingTitle,
    required this.showLeadingTitle,
    required this.showDivider,
    required this.titleBarHeight,
    required this.trafficLightSafeInset,
    required this.center,
    required this.trailing,
  });

  final Widget leadingTitle;
  final bool showLeadingTitle;
  final bool showDivider;
  final double titleBarHeight;
  final double trafficLightSafeInset;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return Material(
      color: backgroundColor,
      child: Container(
        key: const ValueKey<String>('apple-macos-toolbar'),
        height: titleBarHeight,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: showDivider
              ? Border(bottom: BorderSide(color: dividerColor))
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DragToMoveArea(child: SizedBox.expand()),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  SizedBox(width: trafficLightSafeInset),
                  if (showLeadingTitle) ...[
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DefaultTextStyle.merge(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          child: leadingTitle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: center ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [trailing ?? const SizedBox.shrink()],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleMacosContentArea extends StatelessWidget {
  const _AppleMacosContentArea({
    required this.body,
    required this.secondaryPane,
    required this.secondaryPanePolicy,
  });

  final Widget body;
  final Widget? secondaryPane;
  final DesktopSecondaryPanePolicy secondaryPanePolicy;

  @override
  Widget build(BuildContext context) {
    final inlineSecondaryPane =
        secondaryPanePolicy.visible &&
        secondaryPane != null &&
        secondaryPanePolicy.presentation == DesktopPanePresentation.inline;
    return Row(
      children: [
        Expanded(
          child: Material(type: MaterialType.transparency, child: body),
        ),
        if (inlineSecondaryPane)
          SizedBox(
            width: secondaryPanePolicy.width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: secondaryPane!,
              ),
            ),
          ),
      ],
    );
  }
}

class _AppleMacosModalSurface extends StatelessWidget {
  const _AppleMacosModalSurface({
    required this.barrierColor,
    required this.child,
  });

  final Color barrierColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: barrierColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
