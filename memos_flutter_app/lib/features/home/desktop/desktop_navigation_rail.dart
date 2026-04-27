import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_motion_widgets.dart';
import '../../../core/memoflow_palette.dart';
import '../../../core/platform_layout.dart';
import '../app_drawer_model.dart';

class DesktopNavigationRail extends StatelessWidget {
  const DesktopNavigationRail({
    super.key,
    required this.model,
    this.tagsPanelBuilder,
  });

  final AppDrawerModel model;
  final WidgetBuilder? tagsPanelBuilder;

  Future<void> _showTagsPanel(BuildContext context) {
    final builder = tagsPanelBuilder;
    if (builder == null) {
      return Future<void>.value();
    }

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).maybePop(),
                child: const SizedBox.expand(),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  kWindowsDesktopRailWidth + 12,
                  8,
                  12,
                  8,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: builder(dialogContext),
                ),
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
              begin: const Offset(-0.02, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final iconColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return SizedBox(
      width: kWindowsDesktopRailWidth,
      child: ColoredBox(
        key: const ValueKey<String>('desktop-navigation-rail'),
        color: background,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ...model.destinations.map((item) {
                      final opensTagsPanel =
                          item.id == 'tags' && tagsPanelBuilder != null;
                      return _RailButton(
                        buttonKey: ValueKey<String>(
                          'desktop-navigation-rail-button-${item.id}',
                        ),
                        tooltip: item.tooltip ?? item.label,
                        icon: item.icon,
                        selected: item.selected,
                        showBadge: item.showBadge,
                        iconColor: iconColor,
                        hoverColor: hoverColor,
                        onTap: opensTagsPanel
                            ? () => _showTagsPanel(context)
                            : item.onTap,
                      );
                    }),
                  ],
                ),
              ),
              if (model.quickActions.isNotEmpty) ...[
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 8),
                ...model.quickActions.map(
                  (item) => _RailButton(
                    tooltip: item.tooltip,
                    icon: item.icon,
                    selected: false,
                    showBadge: item.showBadge,
                    iconColor: item.iconColor ?? iconColor,
                    hoverColor: hoverColor,
                    onTap: item.onTap,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.showBadge,
    required this.iconColor,
    required this.hoverColor,
    required this.onTap,
  });

  final Key? buttonKey;
  final String tooltip;
  final IconData icon;
  final bool selected;
  final bool showBadge;
  final Color iconColor;
  final Color hoverColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: AppPressScale(
            child: AnimatedContainer(
              duration: AppMotion.effectiveDuration(
                context,
                selected ? AppMotion.windowsSelection : AppMotion.windowsHover,
              ),
              curve: AppMotion.emphasizedEnterCurve,
              decoration: BoxDecoration(
                color: selected
                    ? MemoFlowPalette.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                          color: MemoFlowPalette.primary.withValues(
                            alpha: 0.16,
                          ),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Material(
                key: buttonKey,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  hoverColor: selected ? null : hoverColor,
                  onTap: onTap,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            icon,
                            size: 20,
                            color: selected
                                ? MemoFlowPalette.primary
                                : iconColor,
                          ),
                        ),
                        if (showBadge)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: MemoFlowPalette.primary,
                                shape: BoxShape.circle,
                              ),
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
    );
  }
}
