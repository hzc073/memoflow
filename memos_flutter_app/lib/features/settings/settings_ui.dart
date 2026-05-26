import 'package:flutter/material.dart';

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
    required this.textMain,
    required this.textMuted,
    required this.isDark,
  });

  final Color background;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final bool isDark;
}

SettingsPageTokens settingsPageTokens(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textMain = isDark
      ? MemoFlowPalette.textDark
      : MemoFlowPalette.textLight;
  return SettingsPageTokens(
    background: isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight,
    card: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
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
    this.showBackButton = true,
    this.contentKey,
    this.desktopMaxWidth = 760,
    this.tabletMaxWidth = 680,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 20),
  });

  final Widget title;
  final List<Widget> children;
  final bool showBackButton;
  final Key? contentKey;
  final double desktopMaxWidth;
  final double tabletMaxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
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
      body: Stack(
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
          ListView(
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
          ),
        ],
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PlatformListSection(padding: EdgeInsets.zero, children: children);
  }
}

class SettingsTitleWithHelp extends StatelessWidget {
  const SettingsTitleWithHelp({
    super.key,
    required this.label,
    required this.tooltip,
  });

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        _SettingsHelpTooltip(message: tooltip),
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
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final maxTrailingWidth = MediaQuery.sizeOf(context).width * 0.42;
    return PlatformListSectionRow(
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
      onTap: onTap,
    );
  }
}

class SettingsNavigationRow extends StatelessWidget {
  const SettingsNavigationRow({
    super.key,
    required this.label,
    this.value,
    this.leading,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return PlatformListSectionRow(
      leading: leading,
      title: SettingsRowTitle(label),
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
          Icon(Icons.chevron_right, size: 18, color: tokens.textMuted),
        ],
      ),
      onTap: onTap,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 6 : 8),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
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

class _SettingsHelpTooltip extends StatefulWidget {
  const _SettingsHelpTooltip({required this.message});

  final String message;

  @override
  State<_SettingsHelpTooltip> createState() => _SettingsHelpTooltipState();
}

class _SettingsHelpTooltipState extends State<_SettingsHelpTooltip> {
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
                _SettingsHelpTooltip(message: tooltip),
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
          return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.hovered)) {
          return Theme.of(context).colorScheme.primary.withValues(alpha: 0.04);
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
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: isDesktop ? 0.5 : 0.7),
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
        if (states.contains(WidgetState.pressed)) {
          return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.hovered)) {
          return Theme.of(context).colorScheme.primary.withValues(alpha: 0.04);
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
  const SettingsRowTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textMain),
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
