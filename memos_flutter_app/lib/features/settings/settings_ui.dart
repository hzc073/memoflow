import 'package:flutter/cupertino.dart' hide RefreshCallback;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/memoflow_palette.dart';
import '../../platform/platform_experience.dart';
import '../../platform/platform_icons.dart';
import '../../platform/widgets/platform_adaptive_layout.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_list_section.dart';
import '../../platform/widgets/platform_page.dart';
import '../../platform/widgets/platform_picker.dart';
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
    required this.navigationRowMinHeight,
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
  final double navigationRowMinHeight;
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
      sectionSpacing: isPhone ? 12 : 12,
      shortcutSpacing: isPhone ? 12 : 12,
      shortcutTileHeight: isPhone ? 80 : 72,
      navigationRowMinHeight: isPhone ? 48 : 56,
      profilePadding: EdgeInsets.all(isPhone ? 16 : 14),
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
    return _SettingsHomeDensityScope(
      navigationRowMinHeight: tokens.homeHierarchy.navigationRowMinHeight,
      child: PlatformListSection(
        padding: EdgeInsets.zero,
        header: header,
        footer: footer,
        desktopBorderRadius: BorderRadius.circular(
          tokens.homeHierarchy.sectionRadius,
        ),
        style: tokens.homeListSectionStyle,
        children: children,
      ),
    );
  }
}

class _SettingsHomeDensityScope extends InheritedWidget {
  const _SettingsHomeDensityScope({
    required this.navigationRowMinHeight,
    required super.child,
  });

  final double navigationRowMinHeight;

  static _SettingsHomeDensityScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SettingsHomeDensityScope>();
  }

  @override
  bool updateShouldNotify(_SettingsHomeDensityScope oldWidget) {
    return navigationRowMinHeight != oldWidget.navigationRowMinHeight;
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
        additionalInfo: _SettingsRowValueText(
          value,
          maxWidth: maxTrailingWidth,
        ),
        trailing: Icon(icon, size: 18, color: tokens.textMuted),
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
    final homeDensity = _SettingsHomeDensityScope.maybeOf(context);
    final isSingleLine = description == null;
    final maxTrailingWidth = MediaQuery.sizeOf(context).width * 0.42;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        leading: leading,
        title: SettingsRowTitle(label),
        subtitle: description == null
            ? null
            : SettingsRowDescription(description!),
        additionalInfo: value == null
            ? null
            : _SettingsRowValueText(value!, maxWidth: maxTrailingWidth),
        trailing: Icon(trailingIcon, size: 18, color: tokens.textMuted),
        onTap: enabled ? onTap : null,
        mobileMinTileHeight: isSingleLine
            ? homeDensity?.navigationRowMinHeight
            : null,
        denseOnDesktop: description == null,
      ),
    );
  }
}

class _SettingsRowValueText extends StatelessWidget {
  const _SettingsRowValueText(this.value, {required this.maxWidth});

  final String value;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textMuted),
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
    final rowTap =
        onTap ?? (onChanged == null ? null : () => onChanged!(!value));
    return PlatformListSectionRow(
      title: SettingsRowTitle(label),
      subtitle: description == null
          ? null
          : SettingsRowDescription(description!),
      trailing: PlatformSwitch(value: value, onChanged: onChanged),
      onTap: rowTap,
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
    final selectedLabel = labelFor(value);
    final maxValueWidth = (MediaQuery.sizeOf(context).width * 0.32)
        .clamp(96.0, 140.0)
        .toDouble();
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        title: SettingsRowTitle(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        additionalInfo: _SettingsMenuValueLabel(
          label: selectedLabel,
          color: tokens.textMuted,
          maxWidth: maxValueWidth,
        ),
        trailing: Icon(Icons.chevron_right, size: 18, color: tokens.textMuted),
        onTap: enabled ? () => _showPicker(context) : null,
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showSettingsSingleChoicePicker<T>(
      context: context,
      title: label,
      value: value,
      options: [
        for (final option in values)
          SettingsChoiceOption<T>(value: option, label: labelFor(option)),
      ],
    );
    if (selected != null) onChanged(selected);
  }
}

class _SettingsMenuValueLabel extends StatelessWidget {
  const _SettingsMenuValueLabel({
    required this.label,
    required this.color,
    required this.maxWidth,
  });

  final String label;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class SettingsChoiceOption<T> {
  const SettingsChoiceOption({
    this.key,
    required this.value,
    required this.label,
    this.description,
    this.disabledDescription,
    this.icon,
    this.enabled = true,
  });

  final Key? key;
  final T value;
  final String label;
  final String? description;
  final String? disabledDescription;
  final IconData? icon;
  final bool enabled;
}

Future<T?> showSettingsSingleChoicePicker<T>({
  required BuildContext context,
  required String title,
  required T? value,
  required List<SettingsChoiceOption<T>> options,
  double maxWidth = 420,
  double maxHeightFactor = 0.72,
}) {
  return showPlatformPicker<T>(
    context: context,
    desktopMaxWidth: maxWidth,
    builder: (pickerContext) {
      final tokens = settingsPageTokens(pickerContext);
      final maxHeight =
          MediaQuery.sizeOf(pickerContext).height *
          maxHeightFactor.clamp(0.2, 1.0).toDouble();
      return SafeArea(
        child: ColoredBox(
          color: tokens.background,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: SettingsContentHeader(title: title, prominent: true),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: SettingsSection(
                      children: [
                        SettingsSingleChoiceList<T>(
                          value: value,
                          options: options,
                          onChanged: (selected) =>
                              Navigator.of(pickerContext).pop(selected),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class SettingsOptionChoiceRow<T> extends StatelessWidget {
  const SettingsOptionChoiceRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.description,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<SettingsChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? description;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final optionGroup = SettingsOptionChipGroup<T>(
      value: value,
      options: options,
      enabled: enabled,
      onChanged: onChanged,
    );
    final subtitle = description == null
        ? Padding(padding: const EdgeInsets.only(top: 8), child: optionGroup)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsRowDescription(description!),
              const SizedBox(height: 8),
              optionGroup,
            ],
          );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        title: SettingsRowTitle(label),
        subtitle: subtitle,
        denseOnDesktop: false,
      ),
    );
  }
}

class SettingsOptionChipGroup<T> extends StatelessWidget {
  const SettingsOptionChipGroup({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final T value;
  final List<SettingsChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final experience = resolvePlatformExperience(context);
    final useCupertino =
        experience.visualFamily == PlatformVisualFamily.cupertinoMobile;
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final option in options)
          _SettingsChoiceChip<T>(
            key: option.key,
            option: option,
            selected: option.value == value,
            enabled: enabled && option.enabled,
            useCupertino: useCupertino,
            onSelected: onChanged,
          ),
      ],
    );
  }
}

class SettingsSingleChoiceList<T> extends StatelessWidget {
  const SettingsSingleChoiceList({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final T? value;
  final List<SettingsChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          SettingsSingleChoiceRow<T>(
            option: option,
            selected: option.value == value,
            enabled: enabled && option.enabled,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class SettingsSingleChoiceRow<T> extends StatelessWidget {
  const SettingsSingleChoiceRow({
    super.key,
    required this.option,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final SettingsChoiceOption<T> option;
  final bool selected;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final description = option.enabled
        ? option.description
        : option.disabledDescription ?? option.description;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        leading: option.icon == null
            ? null
            : Icon(
                option.icon,
                size: 20,
                color: settingsPageTokens(context).textMuted,
              ),
        title: SettingsRowTitle(option.label),
        subtitle: description == null
            ? null
            : SettingsRowDescription(description),
        trailing: _SettingsSelectionMark(selected: selected),
        onTap: enabled ? () => onChanged(option.value) : null,
        denseOnDesktop: description == null,
      ),
    );
  }
}

class SettingsMultiChoiceList<T> extends StatelessWidget {
  const SettingsMultiChoiceList({
    super.key,
    required this.values,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final Set<T> values;
  final List<SettingsChoiceOption<T>> options;
  final ValueChanged<Set<T>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          SettingsMultiChoiceRow<T>(
            option: option,
            selected: values.contains(option.value),
            enabled: enabled && option.enabled,
            onChanged: (selected) {
              final next = Set<T>.of(values);
              if (selected) {
                next.add(option.value);
              } else {
                next.remove(option.value);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class SettingsMultiChoiceRow<T> extends StatelessWidget {
  const SettingsMultiChoiceRow({
    super.key,
    required this.option,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final SettingsChoiceOption<T> option;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final description = option.enabled
        ? option.description
        : option.disabledDescription ?? option.description;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PlatformListSectionRow(
        leading: option.icon == null
            ? null
            : Icon(
                option.icon,
                size: 20,
                color: settingsPageTokens(context).textMuted,
              ),
        title: SettingsRowTitle(option.label),
        subtitle: description == null
            ? null
            : SettingsRowDescription(description),
        trailing: _SettingsSelectionMark(selected: selected, boxed: true),
        onTap: enabled ? () => onChanged(!selected) : null,
        denseOnDesktop: description == null,
      ),
    );
  }
}

class _SettingsChoiceChip<T> extends StatelessWidget {
  const _SettingsChoiceChip({
    super.key,
    required this.option,
    required this.selected,
    required this.enabled,
    required this.useCupertino,
    required this.onSelected,
  });

  final SettingsChoiceOption<T> option;
  final bool selected;
  final bool enabled;
  final bool useCupertino;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    if (useCupertino) {
      return _SettingsCupertinoChoicePill(
        label: option.label,
        icon: option.icon,
        selected: selected,
        enabled: enabled,
        onTap: enabled ? () => onSelected(option.value) : null,
      );
    }

    return ChoiceChip(
      label: Text(option.label),
      avatar: option.icon == null ? null : Icon(option.icon, size: 18),
      selected: selected,
      onSelected: enabled ? (_) => onSelected(option.value) : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class SettingsRemovableChip extends StatelessWidget {
  const SettingsRemovableChip({
    super.key,
    required this.label,
    required this.onDeleted,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor,
    this.deleteTooltip,
  });

  final String label;
  final VoidCallback? onDeleted;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? foregroundColor;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final foreground = foregroundColor ?? tokens.textMain;
    final border = borderColor ?? tokens.valueBorder;
    final background = backgroundColor ?? tokens.valueSurface;
    final deleteButton = Semantics(
      button: true,
      label: deleteTooltip,
      enabled: onDeleted != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDeleted,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
          child: Icon(Icons.close_rounded, size: 16, color: foreground),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 8, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
            ),
            deleteTooltip == null
                ? deleteButton
                : Tooltip(message: deleteTooltip!, child: deleteButton),
          ],
        ),
      ),
    );
  }
}

class SettingsActionPill extends StatelessWidget {
  const SettingsActionPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = selected ? primary : tokens.textMain;
    final borderColor = selected
        ? primary.withValues(alpha: 0.62)
        : tokens.valueBorder;
    final background = selected
        ? primary.withValues(alpha: tokens.isDark ? 0.18 : 0.1)
        : tokens.valueSurface;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled && onPressed != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final iconWidth = icon == null ? 0.0 : 22.0;
                final maxLabelWidth = constraints.hasBoundedWidth
                    ? (constraints.maxWidth - iconWidth)
                          .clamp(48.0, constraints.maxWidth)
                          .toDouble()
                    : 360.0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxLabelWidth),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCupertinoChoicePill extends StatelessWidget {
  const _SettingsCupertinoChoicePill({
    required this.label,
    required this.selected,
    required this.enabled,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final foreground = selected ? primary : tokens.textMain;
    final borderColor = selected
        ? primary.withValues(alpha: 0.58)
        : tokens.valueBorder;
    final background = selected
        ? primary.withValues(alpha: tokens.isDark ? 0.18 : 0.1)
        : tokens.valueSurface;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground.withValues(alpha: enabled ? 1 : 0.62),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSelectionMark extends StatelessWidget {
  const _SettingsSelectionMark({required this.selected, this.boxed = false});

  final bool selected;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : tokens.textMuted.withValues(alpha: 0.62);
    final icon = boxed
        ? selected
              ? Icons.check_box
              : Icons.check_box_outline_blank
        : selected
        ? CupertinoIcons.check_mark
        : Icons.radio_button_unchecked;
    return Icon(icon, size: boxed ? 20 : 18, color: color);
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
        constraints: const BoxConstraints.tightFor(width: 26, height: 30),
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
        title: SettingsRowTitle(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 34),
                  child: Text(
                    valueLabel,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: tokens.textMain,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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

enum SettingsFeedbackKind { info, success, warning, error }

class SettingsFeedbackRow extends StatelessWidget {
  const SettingsFeedbackRow({
    super.key,
    required this.message,
    this.title,
    this.kind = SettingsFeedbackKind.info,
  });

  final String message;
  final String? title;
  final SettingsFeedbackKind kind;

  @override
  Widget build(BuildContext context) {
    final data = _settingsFeedbackData(context, kind);
    return PlatformListSectionRow(
      leading: Icon(data.icon, size: 18, color: data.color),
      title: title == null
          ? SettingsRowDescription(message)
          : SettingsRowTitle(title!, color: data.color),
      subtitle: title == null ? null : SettingsRowDescription(message),
      denseOnDesktop: title == null,
    );
  }
}

class SettingsProgressRow extends StatelessWidget {
  const SettingsProgressRow({
    super.key,
    required this.label,
    this.description,
    this.value,
  });

  final String label;
  final String? description;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final progressValue = value?.clamp(0, 1).toDouble();
    final valueLabel = progressValue == null
        ? null
        : '${(progressValue * 100).round()}%';
    return PlatformListSectionRow(
      leading: SizedBox.square(
        dimension: 20,
        child: PlatformProgress(value: progressValue),
      ),
      title: SettingsRowTitle(label),
      subtitle: description == null
          ? null
          : SettingsRowDescription(description!),
      additionalInfo: valueLabel == null
          ? null
          : _SettingsRowValueText(valueLabel, maxWidth: 56),
      denseOnDesktop: description == null,
    );
  }
}

class _SettingsFeedbackData {
  const _SettingsFeedbackData({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_SettingsFeedbackData _settingsFeedbackData(
  BuildContext context,
  SettingsFeedbackKind kind,
) {
  final tokens = settingsPageTokens(context);
  final colorScheme = Theme.of(context).colorScheme;
  return switch (kind) {
    SettingsFeedbackKind.info => _SettingsFeedbackData(
      icon: Icons.info_outline,
      color: colorScheme.primary,
    ),
    SettingsFeedbackKind.success => _SettingsFeedbackData(
      icon: Icons.check_circle_outline,
      color: tokens.isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
    ),
    SettingsFeedbackKind.warning => _SettingsFeedbackData(
      icon: Icons.warning_amber_outlined,
      color: tokens.isDark ? const Color(0xFFFFD54F) : const Color(0xFFF9A825),
    ),
    SettingsFeedbackKind.error => _SettingsFeedbackData(
      icon: Icons.error_outline,
      color: colorScheme.error,
    ),
  };
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

class SettingsFormDialog extends StatelessWidget {
  const SettingsFormDialog({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.maxWidth = 480,
    this.maxHeightFactor = 0.86,
  });

  final Widget title;
  final List<Widget> children;
  final List<Widget> actions;
  final double maxWidth;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final media = MediaQuery.of(context);
    final maxHeight =
        media.size.height * maxHeightFactor.clamp(0.2, 1.0).toDouble();
    final isAppleMobile =
        resolvePlatformExperience(context).visualFamily ==
        PlatformVisualFamily.cupertinoMobile;
    final borderRadius = BorderRadius.circular(isAppleMobile ? 18 : 28);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: tokens.textMain,
      fontSize: 14,
      height: 1.35,
      decoration: TextDecoration.none,
    );
    final surface = DefaultTextStyle.merge(
      style:
          bodyStyle ??
          TextStyle(
            color: tokens.textMain,
            fontSize: 14,
            height: 1.35,
            decoration: TextDecoration.none,
          ),
      child: IconTheme.merge(
        data: IconThemeData(color: tokens.textMuted),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.sectionBackground,
              border: Border.all(color: tokens.border),
              borderRadius: borderRadius,
              boxShadow: [
                if (!isAppleMobile)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
                    child: DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: tokens.textMain,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                      child: title,
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    Divider(height: 1, color: tokens.divider),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: _SettingsFormDialogActions(
                        appleMobile: isAppleMobile,
                        actions: actions,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding:
          media.viewInsets +
          const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: isAppleMobile
            ? surface
            : Material(type: MaterialType.transparency, child: surface),
      ),
    );
  }
}

class _SettingsFormDialogActions extends StatelessWidget {
  const _SettingsFormDialogActions({
    required this.appleMobile,
    required this.actions,
  });

  final bool appleMobile;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (appleMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            actions[index],
          ],
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }
}

class SettingsDialogAction extends StatelessWidget {
  const SettingsDialogAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PlatformPrimaryActionVariant.text,
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
      desktopMinWidth: 96,
      desktopMaxWidth: 220,
      expandOnNarrowDesktop: false,
      child: label,
    );
  }
}

class SettingsDialogTextField extends StatelessWidget {
  const SettingsDialogTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.inputFormatters,
    this.keyboardType,
    this.focusNode,
    this.textInputAction,
    this.enabled = true,
    this.obscureText = false,
    this.suffixIcon,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final colorScheme = Theme.of(context).colorScheme;
    final error = errorText?.trim();
    final helper = helperText?.trim();
    final borderColor = error != null && error.isNotEmpty
        ? colorScheme.error
        : tokens.valueBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tokens.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        PlatformTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: enabled,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textMain),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            counterText: '',
            filled: true,
            fillColor: tokens.valueSurface,
            hintStyle: TextStyle(color: tokens.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
          ),
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(error, style: TextStyle(fontSize: 12, color: colorScheme.error)),
        ] else if (helper != null && helper.isNotEmpty) ...[
          const SizedBox(height: 5),
          SettingsRowDescription(helper),
        ],
      ],
    );
  }
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
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? tokens.textMain,
        decoration: TextDecoration.none,
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
      style: TextStyle(
        fontSize: 12,
        color: tokens.textMuted,
        height: 1.3,
        decoration: TextDecoration.none,
      ),
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

Future<bool> showSettingsConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showPlatformAlertDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: [
      PlatformDialogAction<bool>(value: false, label: cancelLabel),
      PlatformDialogAction<bool>(
        value: true,
        label: confirmLabel,
        isDefault: !destructive,
        isDestructive: destructive,
      ),
    ],
  );
  return result ?? false;
}
