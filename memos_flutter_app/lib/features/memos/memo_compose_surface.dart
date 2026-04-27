import 'dart:math' as math;

import 'package:flutter/material.dart';

class MemoComposeSurface extends StatelessWidget {
  const MemoComposeSurface({
    super.key,
    required this.backgroundColor,
    required this.cardColor,
    required this.borderColor,
    required this.child,
    this.embedded = false,
    this.embeddedHeader,
    this.header,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.surfacePadding,
    this.cardPadding = EdgeInsets.zero,
    this.borderRadius = 16,
    this.maxCardWidth,
    this.contentMaxWidth,
    this.showShadow = false,
    this.centerContentColumn = false,
    this.boxShadow,
  });

  final Color backgroundColor;
  final Color cardColor;
  final Color borderColor;
  final Widget child;
  final bool embedded;
  final Widget? embeddedHeader;
  final Widget? header;
  final EdgeInsetsGeometry bodyPadding;
  final EdgeInsetsGeometry? surfacePadding;
  final EdgeInsetsGeometry cardPadding;
  final double borderRadius;
  final double? maxCardWidth;
  final double? contentMaxWidth;
  final bool showShadow;
  final bool centerContentColumn;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final resolvedSurfacePadding = surfacePadding ?? bodyPadding;
    final resolvedShadows = boxShadow ?? _buildShadow(context);
    final card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: resolvedShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildCardBody(),
    );

    if (embedded) {
      return ColoredBox(
        color: backgroundColor,
        child: Column(
          children: [
            if (embeddedHeader != null) embeddedHeader!,
            Expanded(
              child: Padding(
                padding: resolvedSurfacePadding,
                child: _buildCardViewport(card),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: resolvedSurfacePadding,
        child: Column(children: [Expanded(child: _buildCardViewport(card))]),
      ),
    );
  }

  Widget _buildCardViewport(Widget card) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = maxCardWidth == null
            ? constraints.maxWidth
            : math.min(maxCardWidth!, constraints.maxWidth);
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: resolvedWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: card,
          ),
        );
      },
    );
  }

  Widget _buildCardBody() {
    final constrainedChild = _buildConstrainedContent();
    if (header == null) {
      return constrainedChild;
    }
    return Column(
      children: [
        header!,
        Expanded(child: constrainedChild),
      ],
    );
  }

  Widget _buildConstrainedContent() {
    final paddedChild = Padding(padding: cardPadding, child: child);
    if (!centerContentColumn && contentMaxWidth == null) {
      return paddedChild;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = contentMaxWidth == null
            ? constraints.maxWidth
            : math.min(contentMaxWidth!, constraints.maxWidth);
        final alignedChild = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: constraints.hasBoundedHeight
                ? SizedBox(height: constraints.maxHeight, child: paddedChild)
                : paddedChild,
          ),
        );
        return centerContentColumn ? alignedChild : paddedChild;
      },
    );
  }

  List<BoxShadow> _buildShadow(BuildContext context) {
    if (!showShadow) return const <BoxShadow>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.1),
        blurRadius: isDark ? 40 : 28,
        spreadRadius: isDark ? 0 : -4,
        offset: const Offset(0, 18),
      ),
    ];
  }
}
