import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_target.dart';

enum PlatformPrimaryActionVariant { filled, tonal, outlined, text, destructive }

class PlatformPrimaryAction extends StatelessWidget {
  const PlatformPrimaryAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = PlatformPrimaryActionVariant.filled,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.desktopAlignment = AlignmentDirectional.centerEnd,
    this.desktopMinWidth = 112,
    this.desktopMaxWidth = 320,
    this.narrowDesktopBreakpoint = 520,
    this.expandOnMobile = true,
    this.expandOnNarrowDesktop = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final PlatformPrimaryActionVariant variant;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final AlignmentGeometry desktopAlignment;
  final double desktopMinWidth;
  final double desktopMaxWidth;
  final double narrowDesktopBreakpoint;
  final bool expandOnMobile;
  final bool expandOnNarrowDesktop;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    final isDesktop =
        target == PlatformTarget.macOS ||
        target == PlatformTarget.windows ||
        target == PlatformTarget.linux;
    final button = _buildButton(context, target);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final shouldExpand =
            (!isDesktop && expandOnMobile) ||
            (isDesktop &&
                expandOnNarrowDesktop &&
                hasBoundedWidth &&
                constraints.maxWidth < narrowDesktopBreakpoint);

        if (shouldExpand && hasBoundedWidth) {
          return SizedBox(width: double.infinity, child: button);
        }

        if (!isDesktop) {
          return button;
        }

        final resolvedMaxWidth = math.max(desktopMinWidth, desktopMaxWidth);
        final maxWidth = hasBoundedWidth
            ? math.min(resolvedMaxWidth, constraints.maxWidth)
            : resolvedMaxWidth;
        final minWidth = math.min(desktopMinWidth, maxWidth);

        return Align(
          alignment: desktopAlignment,
          widthFactor: hasBoundedWidth ? null : 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
            child: button,
          ),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, PlatformTarget target) {
    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      return _buildCupertinoButton(context);
    }
    return _buildMaterialButton(context);
  }

  Widget _buildCupertinoButton(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    final red = CupertinoDynamicColor.resolve(
      CupertinoColors.systemRed,
      context,
    );
    final foreground = switch (variant) {
      PlatformPrimaryActionVariant.filled => CupertinoColors.white,
      PlatformPrimaryActionVariant.tonal ||
      PlatformPrimaryActionVariant.outlined ||
      PlatformPrimaryActionVariant.text => primary,
      PlatformPrimaryActionVariant.destructive => red,
    };
    final background = switch (variant) {
      PlatformPrimaryActionVariant.filled => primary,
      PlatformPrimaryActionVariant.tonal => primary.withValues(alpha: 0.14),
      PlatformPrimaryActionVariant.outlined ||
      PlatformPrimaryActionVariant.text ||
      PlatformPrimaryActionVariant.destructive => null,
    };
    final borderColor = variant == PlatformPrimaryActionVariant.outlined
        ? primary.withValues(alpha: onPressed == null ? 0.35 : 0.7)
        : null;
    final borderRadius = BorderRadius.circular(10);
    final button = CupertinoButton(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      borderRadius: borderRadius,
      color: background,
      disabledColor: CupertinoDynamicColor.resolve(
        CupertinoColors.quaternarySystemFill,
        context,
      ),
      child: DefaultTextStyle.merge(
        textAlign: TextAlign.center,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground, size: 18),
          child: _buttonContent(),
        ),
      ),
    );

    if (borderColor == null) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      child: button,
    );
  }

  Widget _buttonContent() {
    final buttonIcon = icon;
    if (buttonIcon == null) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = constraints.hasBoundedWidth
            ? Flexible(child: child)
            : child;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [buttonIcon, const SizedBox(width: 8), label],
        );
      },
    );
  }

  Widget _buildMaterialButton(BuildContext context) {
    final effectiveStyle = _materialStyle(context);
    return switch (variant) {
      PlatformPrimaryActionVariant.filled =>
        icon == null
            ? FilledButton(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                child: child,
              )
            : FilledButton.icon(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                icon: icon!,
                label: child,
              ),
      PlatformPrimaryActionVariant.tonal =>
        icon == null
            ? FilledButton.tonal(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                child: child,
              )
            : FilledButton.tonalIcon(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                icon: icon!,
                label: child,
              ),
      PlatformPrimaryActionVariant.outlined =>
        icon == null
            ? OutlinedButton(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                child: child,
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                icon: icon!,
                label: child,
              ),
      PlatformPrimaryActionVariant.text =>
        icon == null
            ? TextButton(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                child: child,
              )
            : TextButton.icon(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                icon: icon!,
                label: child,
              ),
      PlatformPrimaryActionVariant.destructive =>
        icon == null
            ? FilledButton(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                child: child,
              )
            : FilledButton.icon(
                onPressed: onPressed,
                style: effectiveStyle,
                focusNode: focusNode,
                autofocus: autofocus,
                icon: icon!,
                label: child,
              ),
    };
  }

  ButtonStyle? _materialStyle(BuildContext context) {
    if (variant != PlatformPrimaryActionVariant.destructive) return style;
    final colorScheme = Theme.of(context).colorScheme;
    final destructiveStyle = FilledButton.styleFrom(
      backgroundColor: colorScheme.error,
      foregroundColor: colorScheme.onError,
    );
    return style == null ? destructiveStyle : destructiveStyle.merge(style);
  }
}
