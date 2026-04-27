import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/memoflow_palette.dart';
import '../../../core/platform_layout.dart';

enum WindowsDesktopSecondaryPanePresentation { inline, overlay }

@immutable
class WindowsDesktopSecondaryPaneMotionSpec {
  const WindowsDesktopSecondaryPaneMotionSpec({
    required this.resizeDuration,
    required this.surfaceEnterDuration,
    required this.surfaceExitDuration,
    required this.resizeCurve,
    required this.surfaceEnterCurve,
    required this.surfaceExitCurve,
    required this.surfaceEntryOffset,
    required this.surfaceEntryScale,
  });

  static const WindowsDesktopSecondaryPaneMotionSpec standard =
      WindowsDesktopSecondaryPaneMotionSpec(
        resizeDuration: AppMotion.desktopContent,
        surfaceEnterDuration: AppMotion.desktopContent,
        surfaceExitDuration: AppMotion.desktopOverlayExit,
        resizeCurve: AppMotion.standardCurve,
        surfaceEnterCurve: AppMotion.emphasizedEnterCurve,
        surfaceExitCurve: AppMotion.emphasizedExitCurve,
        surfaceEntryOffset: AppMotion.windowsPaneEntryOffset,
        surfaceEntryScale: 0.985,
      );

  final Duration resizeDuration;
  final Duration surfaceEnterDuration;
  final Duration surfaceExitDuration;
  final Curve resizeCurve;
  final Curve surfaceEnterCurve;
  final Curve surfaceExitCurve;
  final Offset surfaceEntryOffset;
  final double surfaceEntryScale;
}

@immutable
class WindowsDesktopModalSurfaceMotionSpec {
  const WindowsDesktopModalSurfaceMotionSpec({
    required this.backdropEnterDuration,
    required this.backdropExitDuration,
    required this.surfaceEnterDuration,
    required this.surfaceExitDuration,
    required this.backdropCurve,
    required this.surfaceEnterCurve,
    required this.surfaceExitCurve,
    required this.surfaceEntryOffset,
    required this.surfaceEntryScale,
  });

  static const WindowsDesktopModalSurfaceMotionSpec standard =
      WindowsDesktopModalSurfaceMotionSpec(
        backdropEnterDuration: AppMotion.desktopEditorBackdropEnter,
        backdropExitDuration: AppMotion.desktopEditorBackdropExit,
        surfaceEnterDuration: AppMotion.desktopEditorModalEnter,
        surfaceExitDuration: AppMotion.desktopEditorModalExit,
        backdropCurve: AppMotion.standardCurve,
        surfaceEnterCurve: AppMotion.emphasizedEnterCurve,
        surfaceExitCurve: AppMotion.emphasizedExitCurve,
        surfaceEntryOffset: Offset(0, 0.015),
        surfaceEntryScale: 0.985,
      );

  final Duration backdropEnterDuration;
  final Duration backdropExitDuration;
  final Duration surfaceEnterDuration;
  final Duration surfaceExitDuration;
  final Curve backdropCurve;
  final Curve surfaceEnterCurve;
  final Curve surfaceExitCurve;
  final Offset surfaceEntryOffset;
  final double surfaceEntryScale;
}

class WindowsDesktopWorkspaceShell extends StatefulWidget {
  const WindowsDesktopWorkspaceShell({
    super.key,
    required this.layoutSpec,
    required this.navigation,
    required this.commandBar,
    required this.body,
    this.overlayNavigation,
    this.secondaryPane,
    this.secondaryPaneVisible = false,
    this.secondaryPaneWidth = kWindowsDesktopSecondaryPaneDefaultWidth,
    this.secondaryPanePresentation =
        WindowsDesktopSecondaryPanePresentation.inline,
    this.secondaryPaneMotionSpec,
    this.onSecondaryPaneWidthChanged,
    this.modalSurface,
    this.modalSurfaceVisible = false,
    this.modalBarrierColor = const Color(0x66000000),
    this.modalBarrierBlurSigma = 14,
    this.modalSurfaceMotionSpec,
  });

  final WindowsDesktopLayoutSpec layoutSpec;
  final Widget navigation;
  final Widget commandBar;
  final Widget body;
  final Widget? overlayNavigation;
  final Widget? secondaryPane;
  final bool secondaryPaneVisible;
  final double secondaryPaneWidth;
  final WindowsDesktopSecondaryPanePresentation secondaryPanePresentation;
  final WindowsDesktopSecondaryPaneMotionSpec? secondaryPaneMotionSpec;
  final ValueChanged<double>? onSecondaryPaneWidthChanged;
  final Widget? modalSurface;
  final bool modalSurfaceVisible;
  final Color modalBarrierColor;
  final double modalBarrierBlurSigma;
  final WindowsDesktopModalSurfaceMotionSpec? modalSurfaceMotionSpec;

  @override
  State<WindowsDesktopWorkspaceShell> createState() =>
      _WindowsDesktopWorkspaceShellState();
}

class _WindowsDesktopWorkspaceShellState
    extends State<WindowsDesktopWorkspaceShell> {
  bool _draggingSecondaryPane = false;

  void _setDraggingSecondaryPane(bool value) {
    if (_draggingSecondaryPane == value) return;
    setState(() => _draggingSecondaryPane = value);
  }

  void _handleSecondaryPaneDragUpdate(DragUpdateDetails details) {
    final callback = widget.onSecondaryPaneWidthChanged;
    if (callback == null) return;
    final nextWidth = (widget.secondaryPaneWidth - details.delta.dx)
        .clamp(
          kWindowsDesktopSecondaryPaneMinWidth,
          kWindowsDesktopSecondaryPaneMaxWidth,
        )
        .toDouble();
    callback(nextWidth);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final background = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final resolvedPaneWidth = widget.secondaryPaneWidth
        .clamp(
          kWindowsDesktopSecondaryPaneMinWidth,
          kWindowsDesktopSecondaryPaneMaxWidth,
        )
        .toDouble();
    final showPinnedNavigation =
        widget.layoutSpec.navMode != WindowsDesktopNavMode.overlay;
    final showSecondaryPane =
        widget.layoutSpec.supportsSecondaryPane &&
        widget.secondaryPaneVisible &&
        widget.secondaryPane != null;
    final motionSpec =
        widget.secondaryPaneMotionSpec ??
        WindowsDesktopSecondaryPaneMotionSpec.standard;
    final resizeDuration = _draggingSecondaryPane
        ? Duration.zero
        : AppMotion.effectiveDuration(
            context,
            showSecondaryPane
                ? motionSpec.resizeDuration
                : motionSpec.surfaceExitDuration,
          );
    final surfaceDuration = _draggingSecondaryPane
        ? Duration.zero
        : AppMotion.effectiveDuration(
            context,
            showSecondaryPane
                ? motionSpec.surfaceEnterDuration
                : motionSpec.surfaceExitDuration,
          );
    final surfaceCurve = showSecondaryPane
        ? motionSpec.surfaceEnterCurve
        : motionSpec.surfaceExitCurve;
    final showSecondaryPaneResizer =
        showSecondaryPane && widget.onSecondaryPaneWidthChanged != null;
    final useOverlaySecondaryPane =
        widget.secondaryPanePresentation ==
        WindowsDesktopSecondaryPanePresentation.overlay;
    final modalMotionSpec =
        widget.modalSurfaceMotionSpec ??
        WindowsDesktopModalSurfaceMotionSpec.standard;
    final modalBackdropDuration = AppMotion.effectiveDuration(
      context,
      widget.modalSurfaceVisible
          ? modalMotionSpec.backdropEnterDuration
          : modalMotionSpec.backdropExitDuration,
    );
    final modalSurfaceDuration = AppMotion.effectiveDuration(
      context,
      widget.modalSurfaceVisible
          ? modalMotionSpec.surfaceEnterDuration
          : modalMotionSpec.surfaceExitDuration,
    );

    Widget buildSecondaryPaneSurface({required bool overlayMode}) {
      final child = widget.secondaryPane ?? const SizedBox.shrink();
      final hiddenOffset = overlayMode
          ? const Offset(1, 0)
          : motionSpec.surfaceEntryOffset;

      return IgnorePointer(
        ignoring: !showSecondaryPane,
        child: AnimatedOpacity(
          duration: surfaceDuration,
          curve: surfaceCurve,
          opacity: showSecondaryPane ? 1 : 0,
          child: AnimatedSlide(
            duration: surfaceDuration,
            curve: surfaceCurve,
            offset: showSecondaryPane ? Offset.zero : hiddenOffset,
            child: AnimatedScale(
              duration: surfaceDuration,
              curve: surfaceCurve,
              scale: showSecondaryPane ? 1 : motionSpec.surfaceEntryScale,
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  if (overlayMode)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: dividerColor),
                    ),
                  if (showSecondaryPaneResizer)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 12,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          key: const ValueKey<String>(
                            'windows-desktop-secondary-pane-resizer',
                          ),
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: (_) =>
                              _setDraggingSecondaryPane(true),
                          onHorizontalDragUpdate:
                              _handleSecondaryPaneDragUpdate,
                          onHorizontalDragEnd: (_) =>
                              _setDraggingSecondaryPane(false),
                          onHorizontalDragCancel: () =>
                              _setDraggingSecondaryPane(false),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 1,
                              color: dividerColor.withValues(
                                alpha: isDark ? 0.55 : 0.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final mainContent = Row(
      children: [
        if (showPinnedNavigation) ...[
          widget.navigation,
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
        ],
        Expanded(child: widget.body),
        if (!useOverlaySecondaryPane) ...[
          AnimatedContainer(
            duration: resizeDuration,
            curve: motionSpec.resizeCurve,
            width: showSecondaryPane ? 1 : 0,
            child: ColoredBox(color: dividerColor),
          ),
          AnimatedContainer(
            duration: resizeDuration,
            curve: motionSpec.resizeCurve,
            width: showSecondaryPane ? resolvedPaneWidth : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: resolvedPaneWidth,
                maxWidth: resolvedPaneWidth,
                child: SizedBox(
                  width: resolvedPaneWidth,
                  child: buildSecondaryPaneSurface(overlayMode: false),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final content = useOverlaySecondaryPane && widget.secondaryPane != null
        ? Stack(
            children: [
              Positioned.fill(child: mainContent),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: resolvedPaneWidth,
                  child: buildSecondaryPaneSurface(overlayMode: true),
                ),
              ),
            ],
          )
        : mainContent;

    final workspaceContent = Column(
      children: [
        widget.commandBar,
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: content),
              if (widget.layoutSpec.navMode == WindowsDesktopNavMode.overlay &&
                  widget.overlayNavigation != null)
                Positioned.fill(child: widget.overlayNavigation!),
            ],
          ),
        ),
      ],
    );

    final modalSurfaceChild = widget.modalSurface == null
        ? const SizedBox(
            key: ValueKey<String>('windows-desktop-modal-surface-empty'),
          )
        : KeyedSubtree(
            key: const ValueKey<String>('windows-desktop-modal-surface'),
            child: widget.modalSurface!,
          );

    return Material(
      key: const ValueKey<String>('windows-desktop-workspace-shell'),
      color: background,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: widget.modalSurfaceVisible,
              child: workspaceContent,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !widget.modalSurfaceVisible,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        end: widget.modalSurfaceVisible
                            ? widget.modalBarrierBlurSigma
                            : 0,
                      ),
                      duration: modalBackdropDuration,
                      curve: modalMotionSpec.backdropCurve,
                      builder: (context, sigma, child) {
                        return BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: sigma,
                            sigmaY: sigma,
                          ),
                          child: child,
                        );
                      },
                      child: AnimatedOpacity(
                        key: const ValueKey<String>(
                          'windows-desktop-modal-backdrop',
                        ),
                        duration: modalBackdropDuration,
                        curve: modalMotionSpec.backdropCurve,
                        opacity: widget.modalSurfaceVisible ? 1 : 0,
                        child: ColoredBox(color: widget.modalBarrierColor),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: modalSurfaceDuration,
                      reverseDuration: modalSurfaceDuration,
                      switchInCurve: modalMotionSpec.surfaceEnterCurve,
                      switchOutCurve: modalMotionSpec.surfaceExitCurve,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: modalMotionSpec.surfaceEnterCurve,
                          reverseCurve: modalMotionSpec.surfaceExitCurve,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: modalMotionSpec.surfaceEntryOffset,
                              end: Offset.zero,
                            ).animate(curved),
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: modalMotionSpec.surfaceEntryScale,
                                end: 1,
                              ).animate(curved),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: modalSurfaceChild,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
