import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../../core/desktop/window_chrome_safe_area.dart';
import '../../../core/platform_layout.dart'
    show
        kWindowsDesktopRailWidth,
        kWindowsDesktopSecondaryPaneDefaultWidth,
        kWindowsDesktopSidebarWidth;
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
    final useExpandedSidebar = width >= 1040;
    final navigationWidth = useExpandedSidebar
        ? kWindowsDesktopSidebarWidth
        : kWindowsDesktopRailWidth;
    final chromeInsets = resolveDesktopWindowChromeInsets(
      platform: TargetPlatform.macOS,
      contentExtendsIntoTitleBar: true,
    );
    final navigationChromeInset = chromeInsets.top;
    final toolbarChromeInset = resolveMacosTrafficLightCompensation(
      currentLeadingWidth: navigationWidth,
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
    final toolbar =
        commandBar ??
        _AppleMacosToolbar(
          leadingTitle: leadingTitle,
          showLeadingTitle: showLeadingTitle,
          center: center,
          trailing: trailing,
          leadingChromeInset: toolbarChromeInset,
        );
    final resolvedBackground =
        backgroundColor ??
        CupertinoColors.systemBackground.resolveFrom(context);
    final borderColor = CupertinoColors.separator.resolveFrom(context);

    return ColoredBox(
      key: const ValueKey<String>('apple-macos-page-shell'),
      color: resolvedBackground,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGroupedBackground.resolveFrom(
                      context,
                    ),
                    border: Border(right: BorderSide(color: borderColor)),
                  ),
                  child: SizedBox(
                    width: navigationWidth,
                    child: Padding(
                      padding: EdgeInsets.only(top: navigationChromeInset),
                      child: Material(
                        type: MaterialType.transparency,
                        child: navigation,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground.resolveFrom(
                            context,
                          ),
                          border: Border(
                            bottom: BorderSide(color: borderColor),
                          ),
                        ),
                        child: toolbar,
                      ),
                      Expanded(
                        child: _AppleMacosContentArea(
                          body: body,
                          secondaryPane: secondaryPane,
                          secondaryPaneVisible: secondaryPaneVisible,
                          secondaryPaneWidth: secondaryPaneWidth,
                          secondaryPanePresentation: secondaryPanePresentation,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (modalSurfaceVisible && modalSurface != null)
              Positioned.fill(
                child: _AppleMacosModalSurface(
                  barrierColor: modalBarrierColor,
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
    required this.center,
    required this.trailing,
    required this.leadingChromeInset,
  });

  final Widget leadingTitle;
  final bool showLeadingTitle;
  final Widget? center;
  final Widget? trailing;
  final double leadingChromeInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('apple-macos-toolbar'),
      height: 52,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: 16 + leadingChromeInset,
          end: 16,
        ),
        child: NavigationToolbar(
          leading: DefaultTextStyle.merge(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            child: showLeadingTitle ? leadingTitle : const SizedBox.shrink(),
          ),
          middle: center,
          trailing: trailing,
        ),
      ),
    );
  }
}

class _AppleMacosContentArea extends StatelessWidget {
  const _AppleMacosContentArea({
    required this.body,
    required this.secondaryPane,
    required this.secondaryPaneVisible,
    required this.secondaryPaneWidth,
    required this.secondaryPanePresentation,
  });

  final Widget body;
  final Widget? secondaryPane;
  final bool secondaryPaneVisible;
  final double secondaryPaneWidth;
  final DesktopShellSecondaryPanePresentation secondaryPanePresentation;

  @override
  Widget build(BuildContext context) {
    final inlineSecondaryPane =
        secondaryPaneVisible &&
        secondaryPane != null &&
        secondaryPanePresentation ==
            DesktopShellSecondaryPanePresentation.inline;
    return Row(
      children: [
        Expanded(
          child: Material(type: MaterialType.transparency, child: body),
        ),
        if (inlineSecondaryPane)
          SizedBox(
            width: secondaryPaneWidth,
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
