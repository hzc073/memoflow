import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';

bool shouldShowFloatingCollapseForOffsets({
  required double viewportTop,
  required double viewportBottom,
  required double toggleTop,
  required double toggleBottom,
}) {
  if (toggleBottom > viewportTop && toggleTop < viewportBottom) return false;

  final graceDistance = viewportBottom - viewportTop;
  if (graceDistance <= 0) return true;

  if (toggleTop >= viewportBottom) {
    final distanceBelow = toggleTop - viewportBottom;
    return distanceBelow > graceDistance;
  }

  if (toggleBottom <= viewportTop) {
    final distanceAbove = viewportTop - toggleBottom;
    return distanceAbove > graceDistance;
  }

  return false;
}

bool shouldShowFloatingCollapseForToggle({
  required Rect viewportRect,
  required Rect toggleRect,
}) {
  return shouldShowFloatingCollapseForOffsets(
    viewportTop: viewportRect.top,
    viewportBottom: viewportRect.bottom,
    toggleTop: toggleRect.top,
    toggleBottom: toggleRect.bottom,
  );
}

class MemoFloatingCollapseButton extends StatelessWidget {
  const MemoFloatingCollapseButton({
    super.key,
    required this.visible,
    required this.scrolling,
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.only(top: 12, right: 16),
  });

  final bool visible;
  final bool scrolling;
  final String label;
  final VoidCallback onPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xF02F2725)
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = MemoFlowPalette.primary.withValues(
      alpha: isDark ? 0.28 : 0.18,
    );
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.24 : 0.08);
    final foreground = MemoFlowPalette.primary;

    return IgnorePointer(
      ignoring: !visible,
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.topRight,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(0.15, -0.08),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity: visible ? (scrolling ? 0.34 : 0.96) : 0,
                child: Material(
                  color: background,
                  elevation: scrolling ? 0 : 3,
                  shadowColor: shadowColor,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onPressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.expand_less_rounded,
                            size: 16,
                            color: foreground,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
