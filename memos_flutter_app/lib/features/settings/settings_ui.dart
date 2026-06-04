import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/memoflow_palette.dart';
import '../../platform/platform_experience.dart';
import '../../platform/platform_icons.dart';
import '../../platform/widgets/platform_adaptive_layout.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_list_section.dart';
import '../../platform/widgets/platform_page.dart';
import '../../platform/widgets/platform_primary_action.dart';

class SettingsPageTokens {
  const SettingsPageTokens({
    required this.background,
    required this.card,
    required this.sectionBackground,
    required this.rowBackground,
    required this.valueSurface,
    required this.valueBorder,
    required this.border,
    required this.divider,
    required this.rowHover,
    required this.rowPressed,
    required this.rowSelected,
    required this.homeHierarchy,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
  });

  final Color background;
  final Color card;
  final Color sectionBackground;
  final Color rowBackground;
  final Color valueSurface;
  final Color valueBorder;
  final Color border;
  final Color divider;
  final Color rowHover;
  final Color rowPressed;
  final Color rowSelected;
  final SettingsHomeHierarchyTokens homeHierarchy;
  final Color textMain;
  final Color textMuted;
  final bool isDark;

  PlatformListSectionStyle get listSectionStyle {
    return PlatformListSectionStyle(
      sectionColor: sectionBackground,
      rowColor: rowBackground,
      borderColor: border,
      dividerColor: divider,
      hoverColor: rowHover,
      focusColor: rowHover,
      pressedColor: rowPressed,
      selectedRowColor: rowSelected,
      cupertinoBackgroundColor: background,
    );
  }

  PlatformListSectionStyle get homeListSectionStyle {
    final home = homeHierarchy;
    return PlatformListSectionStyle(
      sectionColor: home.cardBackground,
      rowColor: home.cardBackground,
      borderColor: home.border,
      dividerColor: home.divider,
      hoverColor: rowHover,
      focusColor: rowHover,
      pressedColor: rowPressed,
      selectedRowColor: rowSelected,
      cupertinoBackgroundColor: background,
      borderRadius: BorderRadius.circular(home.sectionRadius),
      boxShadow: home.sectionShadow,
    );
  }
}

class SettingsHomeHierarchyTokens {
  const SettingsHomeHierarchyTokens({
    required this.usesLayeredCards,
    required this.cardBackground,
    required this.border,
    required this.divider,
    required this.shadowColor,
    required this.cardElevation,
    required this.profileRadius,
    required this.sectionRadius,
    required this.shortcutRadius,
    required this.sectionSpacing,
    required this.shortcutSpacing,
    required this.shortcutTileHeight,
    required this.profilePadding,
  });

  final bool usesLayeredCards;
  final Color cardBackground;
  final Color border;
  final Color divider;
  final Color shadowColor;
  final double cardElevation;
  final double profileRadius;
  final double sectionRadius;
  final double shortcutRadius;
  final double sectionSpacing;
  final double shortcutSpacing;
  final double shortcutTileHeight;
  final EdgeInsetsGeometry profilePadding;

  List<BoxShadow> get sectionShadow {
    if (!usesLayeredCards || cardElevation <= 0) return const [];
    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: 24,
        spreadRadius: -10,
        offset: const Offset(0, 14),
      ),
    ];
  }
}

SettingsPageTokens settingsPageTokens(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final experience = resolvePlatformExperience(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isPhone = experience.formFactor == PlatformFormFactor.phone;
  final textMain = isDark
      ? MemoFlowPalette.textDark
      : MemoFlowPalette.textLight;
  final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
  final border = isDark
      ? MemoFlowPalette.borderDark
      : MemoFlowPalette.borderLight;
  final neutralOverlay = isDark ? Colors.white : Colors.black;
  final homeBorder = border.withValues(alpha: isDark ? 0.72 : 0.5);
  final homeDivider = border.withValues(alpha: isDark ? 0.55 : 0.48);
  final homeShadowColor = isDark
      ? Colors.transparent
      : Colors.black.withValues(alpha: 0.08);
  return SettingsPageTokens(
    background: isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight,
    card: card,
    sectionBackground: card,
    rowBackground: card,
    valueSurface: colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.34 : 0.48,
    ),
    valueBorder: border.withValues(alpha: isDark ? 0.72 : 0.86),
    border: border.withValues(alpha: isDark ? 0.82 : 0.92),
    divider: border.withValues(alpha: isDark ? 0.7 : 0.78),
    rowHover: neutralOverlay.withValues(alpha: isDark ? 0.06 : 0.035),
    rowPressed: colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
    rowSelected: colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.1),
    homeHierarchy: SettingsHomeHierarchyTokens(
      usesLayeredCards: isPhone,
      cardBackground: card,
      border: homeBorder,
      divider: homeDivider,
      shadowColor: homeShadowColor,
      cardElevation: isPhone && !isDark ? 6 : 0,
      profileRadius: isPhone ? 24 : 8,
      sectionRadius: isPhone ? 22 : 8,
      shortcutRadius: isPhone ? 20 : 8,
      sectionSpacing: isPhone ? 16 : 12,
      shortcutSpacing: isPhone ? 12 : 12,
      shortcutTileHeight: isPhone ? 92 : 72,
      profilePadding: EdgeInsets.all(isPhone ? 18 : 14),
    ),
    textMain: textMain,
    textMuted: textMain.withValues(alpha: isDark ? 0.55 : 0.6),
    isDark: isDark,
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.showBackButton = true,
    this.contentKey,
    this.desktopMaxWidth = 760,
    this.tabletMaxWidth = 680,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 20),
    this.onRefresh,
  });

  final Widget title;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool showBackButton;
  final Key? contentKey;
  final double desktopMaxWidth;
  final double tabletMaxWidth;
  final EdgeInsetsGeometry padding;
  final RefreshCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final content = ListView(
      children: [
        PlatformBoundedContent(
          desktopMaxWidth: desktopMaxWidth,
          tabletMaxWidth: tabletMaxWidth,
          padding: padding,
          child: Column(
            key: contentKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );

    final bodyContent = onRefresh == null
        ? content
        : RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: onRefresh!,
            child: content,
          );

    return PlatformPage(
      backgroundColor: tokens.background,
      leading: showBackButton
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(PlatformIcons.back),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: title,
      actions: actions,
      body: ListTileTheme.merge(
        tileColor: tokens.rowBackground,
        selectedTileColor: tokens.rowSelected,
        iconColor: tokens.textMuted,
        textColor: tokens.textMain,
        child: Stack(
          children: [
            if (tokens.isDark)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0B0B0B),
                        tokens.background,
                        tokens.background,
                      ],
                    ),
                  ),
                ),
              ),
            bodyContent,
          ],
        ),
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return PlatformListSection(
      padding: EdgeInsets.zero,
      header: header,
      footer: footer,
      style: tokens.listSectionStyle,
      children: children,
    );
  }
}

class SettingsHomeSection extends StatelessWidget {
  const SettingsHomeSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return PlatformListSection(
      padding: EdgeInsets.zero,
      header: header,
      footer: footer,
      desktopBorderRadius: BorderRadius.circular(
        tokens.homeHierarchy.sectionRadius,
      ),
      style: tokens.homeListSectionStyle,
      children: children,
    );
  }
}

class SettingsContentHeader extends StatelessWidget {
  const SettingsContentHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.textAlign,
    this.maxTitleLines = 1,
    this.prominent = false,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final TextAlign? textAlign;
  final int maxTitleLines;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final baseStyle = prominent
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleSmall;
    final titleStyle = baseStyle?.copyWith(
      color: tokens.textMain,
      fontWeight: FontWeight.w700,
    );
    final titleWidget = Text(
      title,
      maxLines: maxTitleLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: titleStyle,
    );

    final header = trailing == null
        ? titleWidget
        : Row(
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 12),
              trailing!,
            ],
          );

    final resolvedDescription = description?.trim();
    if (resolvedDescription == null || resolvedDescription.isEmpty) {
      return header;
    }

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 6),
        SettingsRowDescription(resolvedDescription),
      ],
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.textAlign,
  });

  final String title;
  final String? caption;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );

    final resolvedCaption = caption?.trim();
    if (resolvedCaption == null || resolvedCaption.isEmpty) {
      return titleWidget;
    }

    return Row(
      children: [
        Expanded(child: titleWidget),
        const SizedBox(width: 12),
        Text(
          resolvedCaption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ],
    );
  }
}

class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.chevron_right,
    this.description,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? description;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final maxTrailingWidth = MediaQuery.sizeOf(context).width * 0.42;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        title: SettingsRowTitle(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTrailingWidth),
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 18, color: tokens.textMuted),
          ],
        ),
        onTap: enabled ? onTap : null,
        subtitle: description == null
            ? null
            : SettingsRowDescription(description!),
        denseOnDesktop: description == null,
      ),
    );
  }
}

class SettingsNavigationRow extends StatelessWidget {
  const SettingsNavigationRow({
    super.key,
    required this.label,
    this.value,
    this.description,
    this.leading,
    this.trailingIcon = Icons.chevron_right,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final String? value;
  final String? description;
  final Widget? leading;
  final IconData trailingIcon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        leading: leading,
        title: SettingsRowTitle(label),
        subtitle: description == null
            ? null
            : SettingsRowDescription(description!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              Flexible(
                child: Text(
                  value!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(trailingIcon, size: 18, color: tokens.textMuted),
          ],
        ),
        onTap: enabled ? onTap : null,
        denseOnDesktop: description == null,
      ),
    );
  }
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return PlatformListSectionRow(
      title: SettingsRowDescription(description),
      denseOnDesktop: false,
    );
  }
}

class SettingsProfileSummary extends StatelessWidget {
  const SettingsProfileSummary({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return PlatformListSectionRow(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        child: Icon(icon, color: tokens.textMuted),
      ),
      title: SettingsRowTitle(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null || subtitle!.trim().isEmpty
          ? null
          : SettingsRowDescription(subtitle!),
      denseOnDesktop: false,
    );
  }
}

class SettingsSelectableItemRow extends StatelessWidget {
  const SettingsSelectableItemRow({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.editTooltip,
    this.deleteTooltip,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? editTooltip;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final actions = <Widget>[
      if (onEdit != null)
        IconButton(
          tooltip: editTooltip,
          icon: Icon(Icons.edit_outlined, color: tokens.textMuted),
          onPressed: onEdit,
        ),
      if (onDelete != null)
        IconButton(
          tooltip: deleteTooltip,
          icon: Icon(Icons.delete_outline, color: tokens.textMuted),
          onPressed: onDelete,
        ),
    ];

    return PlatformListSectionRow(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 20,
        color: tokens.textMuted,
      ),
      title: SettingsRowTitle(title),
      subtitle: SettingsRowDescription(subtitle),
      trailing: actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
      onTap: onTap,
      denseOnDesktop: false,
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.onTap,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PlatformListSectionRow(
      title: SettingsRowTitle(label),
      subtitle: description == null
          ? null
          : SettingsRowDescription(description!),
      trailing: PlatformSwitch(value: value, onChanged: onChanged),
      onTap: onTap,
      denseOnDesktop: description == null,
    );
  }
}

class SettingsToggleCard extends StatelessWidget {
  const SettingsToggleCard({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.onTap,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsToggleRow(
      label: label,
      description: description,
      value: value,
      onChanged: onChanged,
      onTap: onTap,
    );
  }
}

class SettingsInputRow extends StatelessWidget {
  const SettingsInputRow({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.hint,
    this.fieldLabel,
    this.suffixIcon,
    this.inputFormatters,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onEditingComplete,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? fieldLabel;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        title: SettingsRowTitle(label),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: PlatformTextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            obscureText: obscureText,
            minLines: minLines,
            maxLines: maxLines,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textMain,
            ),
            decoration: InputDecoration(
              labelText: fieldLabel,
              hintText: hint,
              suffixIcon: suffixIcon,
              hintStyle: TextStyle(color: tokens.textMuted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        denseOnDesktop: false,
      ),
    );
  }
}

class SettingsMenuRow<T> extends StatelessWidget {
  const SettingsMenuRow({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        title: SettingsRowTitle(label),
        trailing: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: [
              for (final option in values)
                DropdownMenuItem<T>(
                  value: option,
                  child: Text(labelFor(option)),
                ),
            ],
            onChanged: enabled
                ? (next) {
                    if (next != null) onChanged(next);
                  }
                : null,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textMain,
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsStepperRow extends StatelessWidget {
  const SettingsStepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    this.unit = '',
    this.enabled = true,
  });

  final String label;
  final int value;
  final String unit;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final valueLabel = unit.isEmpty ? '$value' : '$value$unit';

    Widget buildButton(IconData icon, VoidCallback onPressed) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        iconSize: 16,
        color: tokens.textMuted,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        title: SettingsRowTitle(label),
        trailing: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.valueSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.valueBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildButton(Icons.remove, onDecrease),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44),
                  child: Text(
                    valueLabel,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textMain,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                buildButton(Icons.add, onIncrease),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsWarningRow extends StatelessWidget {
  const SettingsWarningRow({super.key, required this.message, this.iconColor});

  final String message;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PlatformListSectionRow(
      leading: Icon(
        Icons.info_outline,
        size: 18,
        color: iconColor ?? colorScheme.primary,
      ),
      title: SettingsRowDescription(message),
      denseOnDesktop: false,
    );
  }
}

class SettingsHomeProfileEntry extends StatelessWidget {
  const SettingsHomeProfileEntry({
    super.key,
    required this.avatar,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final Widget avatar;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final home = tokens.homeHierarchy;
    return Material(
      color: home.cardBackground,
      elevation: home.cardElevation,
      shadowColor: home.shadowColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(home.profileRadius),
        side: BorderSide(color: home.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: home.profilePadding,
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsRowTitle(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsHomeShortcutTile extends StatelessWidget {
  const SettingsHomeShortcutTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final home = tokens.homeHierarchy;
    return Material(
      color: home.cardBackground,
      elevation: home.cardElevation,
      shadowColor: home.shadowColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(home.shortcutRadius),
        side: BorderSide(color: home.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: home.shortcutTileHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: home.usesLayeredCards ? 26 : 22,
                color: tokens.textMuted,
              ),
              SizedBox(height: home.usesLayeredCards ? 8 : 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.textMain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SettingsFeatureStatus {
  notConfigured,
  disabledConfigured,
  error,
  permissionMissing,
  enabledHealthy,
  working,
}

class SettingsFeatureModule extends StatelessWidget {
  const SettingsFeatureModule({
    super.key,
    required this.title,
    required this.tooltip,
    required this.status,
    required this.value,
    required this.onChanged,
    this.onOpen,
  });

  final String title;
  final String tooltip;
  final SettingsFeatureStatus status;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final experience = resolvePlatformExperience(context);
    final isDesktop = experience.formFactor == PlatformFormFactor.desktop;
    final radius = BorderRadius.circular(isDesktop ? 10 : 14);
    final tokens = settingsPageTokens(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 6 : 8),
      child: Material(
        color: tokens.rowBackground,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SettingsFeatureOpenArea(
                  label: title,
                  tooltip: tooltip,
                  status: status,
                  onOpen: onOpen,
                  isDesktop: isDesktop,
                ),
              ),
              _SettingsFeatureDivider(isDesktop: isDesktop),
              _SettingsFeatureSwitchArea(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsHelpButton extends StatefulWidget {
  const SettingsHelpButton({super.key, required this.message});

  final String message;

  @override
  State<SettingsHelpButton> createState() => _SettingsHelpButtonState();
}

class _SettingsHelpButtonState extends State<SettingsHelpButton> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      showDuration: const Duration(seconds: 5),
      waitDuration: const Duration(milliseconds: 350),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        padding: EdgeInsets.zero,
        iconSize: 16,
        color: tokens.textMuted,
        onPressed: () => _tooltipKey.currentState?.ensureTooltipVisible(),
        icon: const Icon(Icons.help_outline),
      ),
    );
  }
}

class _SettingsFeatureOpenArea extends StatelessWidget {
  const _SettingsFeatureOpenArea({
    required this.label,
    required this.tooltip,
    required this.status,
    required this.onOpen,
    required this.isDesktop,
  });

  final String label;
  final String tooltip;
  final SettingsFeatureStatus status;
  final VoidCallback? onOpen;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final child = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        14,
        isDesktop ? 8 : 11,
        10,
        isDesktop ? 8 : 11,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SettingsHelpButton(message: tooltip),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SettingsFeatureStatusIndicator(status: status),
        ],
      ),
    );

    if (onOpen == null) return child;

    return InkWell(
      onTap: onOpen,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return tokens.rowPressed;
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.rowHover;
        }
        return null;
      }),
      child: child,
    );
  }
}

class _SettingsFeatureDivider extends StatelessWidget {
  const _SettingsFeatureDivider({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: tokens.divider.withValues(alpha: isDesktop ? 0.9 : 1),
    );
  }
}

class _SettingsFeatureSwitchArea extends StatelessWidget {
  const _SettingsFeatureSwitchArea({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final switchWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Center(
        child: IgnorePointer(
          child: PlatformSwitch(value: value, onChanged: onChanged),
        ),
      ),
    );
    return InkWell(
      onTap: () => onChanged(!value),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        final tokens = settingsPageTokens(context);
        if (states.contains(WidgetState.pressed)) {
          return tokens.rowPressed;
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.rowHover;
        }
        return null;
      }),
      child: switchWidget,
    );
  }
}

class _SettingsFeatureStatusIndicator extends StatefulWidget {
  const _SettingsFeatureStatusIndicator({required this.status});

  final SettingsFeatureStatus status;

  @override
  State<_SettingsFeatureStatusIndicator> createState() =>
      _SettingsFeatureStatusIndicatorState();
}

class _SettingsFeatureStatusIndicatorState
    extends State<_SettingsFeatureStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      lowerBound: 0.35,
      upperBound: 1,
    );
    if (widget.status == SettingsFeatureStatus.working) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(_SettingsFeatureStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == SettingsFeatureStatus.working) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _statusData(context, widget.status);
    return Semantics(
      label: data.label,
      child: FadeTransition(
        opacity: _controller,
        child: Icon(data.icon, size: 14, color: data.color),
      ),
    );
  }
}

class _SettingsFeatureStatusData {
  const _SettingsFeatureStatusData({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

_SettingsFeatureStatusData _statusData(
  BuildContext context,
  SettingsFeatureStatus status,
) {
  final tokens = settingsPageTokens(context);
  final colorScheme = Theme.of(context).colorScheme;
  final muted = tokens.textMuted.withValues(alpha: 0.75);
  return switch (status) {
    SettingsFeatureStatus.notConfigured => _SettingsFeatureStatusData(
      icon: Icons.radio_button_unchecked,
      color: muted,
      label: 'Not configured',
    ),
    SettingsFeatureStatus.disabledConfigured => _SettingsFeatureStatusData(
      icon: Icons.circle,
      color: muted,
      label: 'Configured but disabled',
    ),
    SettingsFeatureStatus.error => _SettingsFeatureStatusData(
      icon: Icons.circle,
      color: colorScheme.error,
      label: 'Error',
    ),
    SettingsFeatureStatus.permissionMissing => _SettingsFeatureStatusData(
      icon: Icons.circle,
      color: tokens.isDark ? const Color(0xFFFFD54F) : const Color(0xFFF9A825),
      label: 'Permission missing',
    ),
    SettingsFeatureStatus.enabledHealthy => _SettingsFeatureStatusData(
      icon: Icons.circle,
      color: tokens.isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
      label: 'Enabled',
    ),
    SettingsFeatureStatus.working => _SettingsFeatureStatusData(
      icon: Icons.circle,
      color: tokens.isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
      label: 'Working',
    ),
  };
}

class SettingsRowTitle extends StatelessWidget {
  const SettingsRowTitle(
    this.label, {
    super.key,
    this.color,
    this.maxLines,
    this.overflow,
  });

  final String label;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Text(
      label,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: color ?? tokens.textMain,
      ),
    );
  }
}

class SettingsRowDescription extends StatelessWidget {
  const SettingsRowDescription(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Text(
      label,
      style: TextStyle(fontSize: 12, color: tokens.textMuted, height: 1.3),
    );
  }
}

class SettingsAction extends StatelessWidget {
  const SettingsAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PlatformPrimaryActionVariant.filled,
  });

  final Widget label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final PlatformPrimaryActionVariant variant;

  @override
  Widget build(BuildContext context) {
    return PlatformPrimaryAction(
      onPressed: onPressed,
      icon: icon,
      variant: variant,
      child: label,
    );
  }
}
