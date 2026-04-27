import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum WindowsAdaptiveSurfaceKind { popover, dialog, largeDialog }

bool shouldUseWindowsAdaptiveSurface(BuildContext context) {
  return !kIsWeb && Theme.of(context).platform == TargetPlatform.windows;
}

Future<T?> showWindowsAdaptiveSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  WindowsAdaptiveSurfaceKind kind = WindowsAdaptiveSurfaceKind.dialog,
  double? maxWidth,
  double? maxHeightFactor,
  EdgeInsets insetPadding = const EdgeInsets.symmetric(
    horizontal: 32,
    vertical: 24,
  ),
  bool barrierDismissible = true,
  bool useRootNavigator = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  BuildContext? anchorContext,
  Alignment fallbackAlignment = Alignment.center,
  Offset popoverOffset = const Offset(0, 8),
}) {
  final resolvedMaxWidth =
      maxWidth ??
      switch (kind) {
        WindowsAdaptiveSurfaceKind.popover => 420.0,
        WindowsAdaptiveSurfaceKind.dialog => 640.0,
        WindowsAdaptiveSurfaceKind.largeDialog => 860.0,
      };
  final resolvedMaxHeightFactor =
      maxHeightFactor ??
      switch (kind) {
        WindowsAdaptiveSurfaceKind.popover => 0.72,
        WindowsAdaptiveSurfaceKind.dialog => 0.82,
        WindowsAdaptiveSurfaceKind.largeDialog => 0.88,
      };

  if (kind != WindowsAdaptiveSurfaceKind.popover) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (dialogContext) {
        return Dialog(
          key: const ValueKey<String>('windows-adaptive-surface-dialog'),
          insetPadding: insetPadding,
          backgroundColor:
              backgroundColor ?? Theme.of(dialogContext).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape:
              shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: resolvedMaxWidth,
              maxHeight:
                  MediaQuery.sizeOf(dialogContext).height *
                  resolvedMaxHeightFactor,
            ),
            child: builder(dialogContext),
          ),
        );
      },
    );
  }

  final anchorRect = _resolveAnchorRect(
    context: context,
    anchorContext: anchorContext,
    useRootNavigator: useRootNavigator,
  );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    useRootNavigator: useRootNavigator,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, _, _) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final maxHeight =
          MediaQuery.sizeOf(dialogContext).height * resolvedMaxHeightFactor;
      return Stack(
        children: [
          const Positioned.fill(child: SizedBox.expand()),
          CustomSingleChildLayout(
            delegate: _WindowsPopoverLayoutDelegate(
              anchorRect: anchorRect,
              maxWidth: resolvedMaxWidth,
              maxHeight: maxHeight,
              padding: insetPadding,
              fallbackAlignment: fallbackAlignment,
              offset: popoverOffset,
            ),
            child: Material(
              key: const ValueKey<String>('windows-adaptive-surface-popover'),
              color:
                  backgroundColor ??
                  Theme.of(dialogContext).colorScheme.surface,
              elevation: 18,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
              shape:
                  shape ??
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
              clipBehavior: Clip.antiAlias,
              child: builder(dialogContext),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Rect? _resolveAnchorRect({
  required BuildContext context,
  required BuildContext? anchorContext,
  required bool useRootNavigator,
}) {
  final resolvedAnchorContext = anchorContext;
  if (resolvedAnchorContext == null) {
    return null;
  }
  final anchorBox = resolvedAnchorContext.findRenderObject();
  final overlayBox =
      Navigator.of(
            context,
            rootNavigator: useRootNavigator,
          ).overlay?.context.findRenderObject()
          as RenderBox?;
  if (anchorBox is! RenderBox || overlayBox == null || !anchorBox.hasSize) {
    return null;
  }
  final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  return topLeft & anchorBox.size;
}

class _WindowsPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  const _WindowsPopoverLayoutDelegate({
    required this.anchorRect,
    required this.maxWidth,
    required this.maxHeight,
    required this.padding,
    required this.fallbackAlignment,
    required this.offset,
  });

  final Rect? anchorRect;
  final double maxWidth;
  final double maxHeight;
  final EdgeInsets padding;
  final Alignment fallbackAlignment;
  final Offset offset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final allowedWidth = _clampDouble(
      maxWidth,
      0,
      size.width - padding.horizontal,
    );
    final allowedHeight = _clampDouble(
      maxHeight,
      0,
      size.height - padding.vertical,
    );
    return BoxConstraints(maxWidth: allowedWidth, maxHeight: allowedHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minLeft = padding.left;
    final maxLeft = size.width - padding.right - childSize.width;
    final minTop = padding.top;
    final maxTop = size.height - padding.bottom - childSize.height;

    if (anchorRect == null) {
      final available = Offset(
        size.width - childSize.width,
        size.height - childSize.height,
      );
      final aligned = fallbackAlignment.alongOffset(available);
      return Offset(
        _clampDouble(aligned.dx, minLeft, maxLeft),
        _clampDouble(aligned.dy, minTop, maxTop),
      );
    }

    final left = _clampDouble(anchorRect!.left + offset.dx, minLeft, maxLeft);
    final belowTop = anchorRect!.bottom + offset.dy;
    final aboveTop = anchorRect!.top - childSize.height - offset.dy;
    final top = _clampDouble(
      belowTop <= maxTop || aboveTop < minTop ? belowTop : aboveTop,
      minTop,
      maxTop,
    );
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _WindowsPopoverLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        maxWidth != oldDelegate.maxWidth ||
        maxHeight != oldDelegate.maxHeight ||
        padding != oldDelegate.padding ||
        fallbackAlignment != oldDelegate.fallbackAlignment ||
        offset != oldDelegate.offset;
  }
}

double _clampDouble(double value, double min, double max) {
  if (max < min) return min;
  return value.clamp(min, max).toDouble();
}
