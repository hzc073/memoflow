import 'dart:math' as math;

import 'package:flutter/material.dart';

class ImagePreviewDesktopFrame extends StatelessWidget {
  const ImagePreviewDesktopFrame({
    super.key,
    required this.child,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final Widget child;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final edgeWidth = math.max(
                  96.0,
                  math.min(180.0, constraints.maxWidth * 0.24),
                );
                return Row(
                  children: [
                    SizedBox(
                      width: edgeWidth,
                      child: _ImagePreviewDesktopHotspot(
                        alignment: Alignment.centerLeft,
                        icon: Icons.chevron_left_rounded,
                        enabled: canGoPrevious,
                        onTap: onPrevious,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: edgeWidth,
                      child: _ImagePreviewDesktopHotspot(
                        alignment: Alignment.centerRight,
                        icon: Icons.chevron_right_rounded,
                        enabled: canGoNext,
                        onTap: onNext,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePreviewDesktopHotspot extends StatefulWidget {
  const _ImagePreviewDesktopHotspot({
    required this.alignment,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final Alignment alignment;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ImagePreviewDesktopHotspot> createState() =>
      _ImagePreviewDesktopHotspotState();
}

class _ImagePreviewDesktopHotspotState
    extends State<_ImagePreviewDesktopHotspot> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final leadingEdge = widget.alignment == Alignment.centerLeft;
    final buttonOpacity = widget.enabled ? (_hovered ? 1.0 : 0.34) : 0.0;
    final edgeOpacity = widget.enabled ? (_hovered ? 0.22 : 0.0) : 0.0;
    final slideOffset = _hovered
        ? Offset.zero
        : Offset(leadingEdge ? -0.08 : 0.08, 0);

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (widget.enabled) {
          _setHovered(true);
        }
      },
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.enabled ? widget.onTap : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                opacity: edgeOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: leadingEdge
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: leadingEdge
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.58),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: widget.alignment,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: slideOffset,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  scale: _hovered ? 1.0 : 0.94,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: buttonOpacity,
                    child: IgnorePointer(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: _hovered ? 0.52 : 0.34,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: _hovered ? 0.24 : 0.1,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _hovered ? 0.22 : 0.08,
                              ),
                              blurRadius: _hovered ? 18 : 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white.withValues(
                            alpha: _hovered ? 1.0 : 0.86,
                          ),
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
