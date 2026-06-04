import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_target.dart';

class PlatformListSectionStyle {
  const PlatformListSectionStyle({
    this.sectionColor,
    this.rowColor,
    this.borderColor,
    this.dividerColor,
    this.hoverColor,
    this.focusColor,
    this.pressedColor,
    this.selectedRowColor,
    this.cupertinoBackgroundColor,
    this.borderRadius,
    this.boxShadow,
  });

  final Color? sectionColor;
  final Color? rowColor;
  final Color? borderColor;
  final Color? dividerColor;
  final Color? hoverColor;
  final Color? focusColor;
  final Color? pressedColor;
  final Color? selectedRowColor;
  final Color? cupertinoBackgroundColor;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
}

class PlatformListSection extends StatelessWidget {
  const PlatformListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.padding,
    this.desktopBorderRadius = const BorderRadius.all(Radius.circular(8)),
    this.showDesktopDividers = true,
    this.style,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry desktopBorderRadius;
  final bool showDesktopDividers;
  final PlatformListSectionStyle? style;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      final borderRadius =
          style?.borderRadius ?? const BorderRadius.all(Radius.circular(10));
      return _PlatformListSectionStyleScope(
        style: style,
        child: CupertinoListSection.insetGrouped(
          header: header,
          footer: footer,
          margin: padding,
          backgroundColor:
              style?.cupertinoBackgroundColor ??
              CupertinoColors.systemGroupedBackground,
          decoration: style?.sectionColor == null
              ? null
              : BoxDecoration(
                  color: style!.sectionColor,
                  borderRadius: borderRadius,
                  border: style?.borderColor == null
                      ? null
                      : Border.all(color: style!.borderColor!),
                  boxShadow: style?.boxShadow,
                ),
          separatorColor: style?.dividerColor,
          children: children,
        ),
      );
    }

    final isDesktop =
        target == PlatformTarget.macOS ||
        target == PlatformTarget.windows ||
        target == PlatformTarget.linux;
    if (isDesktop) {
      final colorScheme = Theme.of(context).colorScheme;
      final borderRadius = style?.borderRadius ?? desktopBorderRadius;
      return _PlatformListSectionStyleScope(
        style: style,
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) _PlatformSectionLabel(child: header!),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: style?.sectionColor ?? colorScheme.surface,
                  border: Border.all(
                    color:
                        style?.borderColor ??
                        colorScheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                  borderRadius: borderRadius,
                  boxShadow: style?.boxShadow,
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Material(
                    color: Colors.transparent,
                    child: Column(children: _desktopChildren(context)),
                  ),
                ),
              ),
              if (footer != null) _PlatformSectionLabel(child: footer!),
            ],
          ),
        ),
      );
    }

    final shouldDecoratePlainMobile =
        style?.borderRadius != null || (style?.boxShadow?.isNotEmpty ?? false);
    if (shouldDecoratePlainMobile) {
      final colorScheme = Theme.of(context).colorScheme;
      final borderRadius =
          style?.borderRadius ?? const BorderRadius.all(Radius.circular(12));
      return _PlatformListSectionStyleScope(
        style: style,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: style?.sectionColor ?? colorScheme.surface,
              borderRadius: borderRadius,
              border: style?.borderColor == null
                  ? null
                  : Border.all(color: style!.borderColor!),
              boxShadow: style?.boxShadow,
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Material(
                color: Colors.transparent,
                child: Column(children: _decoratedChildren(context)),
              ),
            ),
          ),
        ),
      );
    }

    return _PlatformListSectionStyleScope(
      style: style,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) _PlatformSectionLabel(child: header!),
              ...children,
              if (footer != null) _PlatformSectionLabel(child: footer!),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _desktopChildren(BuildContext context) {
    if (!showDesktopDividers || children.length < 2) return children;

    return _decoratedChildren(context);
  }

  List<Widget> _decoratedChildren(BuildContext context) {
    if (!showDesktopDividers || children.length < 2) return children;

    final dividerColor =
        style?.dividerColor ??
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55);
    final separated = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) {
        separated.add(Divider(height: 1, thickness: 1, color: dividerColor));
      }
      separated.add(children[index]);
    }
    return separated;
  }
}

class PlatformListSectionRow extends StatelessWidget {
  const PlatformListSectionRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.contentPadding,
    this.onTap,
    this.danger = false,
    this.denseOnDesktop = true,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;
  final bool danger;
  final bool denseOnDesktop;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    final sectionStyle = _PlatformListSectionStyleScope.maybeOf(context);
    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      return CupertinoListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        backgroundColor: sectionStyle?.rowColor,
        backgroundColorActivated: sectionStyle?.pressedColor,
      );
    }

    final isDesktop =
        target == PlatformTarget.macOS ||
        target == PlatformTarget.windows ||
        target == PlatformTarget.linux;
    final compact = isDesktop && denseOnDesktop;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: compact,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      minLeadingWidth: compact ? 24 : null,
      minVerticalPadding: compact ? 8 : null,
      contentPadding:
          contentPadding ??
          (compact
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 0)
              : null),
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      textColor: danger ? colorScheme.error : null,
      iconColor: danger ? colorScheme.error : null,
      tileColor: sectionStyle?.rowColor,
      selectedTileColor: sectionStyle?.selectedRowColor,
      hoverColor: sectionStyle?.hoverColor,
      focusColor: sectionStyle?.focusColor,
      splashColor: sectionStyle?.pressedColor,
    );
  }
}

class _PlatformListSectionStyleScope extends InheritedWidget {
  const _PlatformListSectionStyleScope({
    required this.style,
    required super.child,
  });

  final PlatformListSectionStyle? style;

  static PlatformListSectionStyle? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PlatformListSectionStyleScope>()
        ?.style;
  }

  @override
  bool updateShouldNotify(_PlatformListSectionStyleScope oldWidget) {
    return style != oldWidget.style;
  }
}

class _PlatformSectionLabel extends StatelessWidget {
  const _PlatformSectionLabel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 6),
      child: DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        child: child,
      ),
    );
  }
}
