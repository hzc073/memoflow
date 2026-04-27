import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_motion_widgets.dart';
import '../../../core/memoflow_palette.dart';
import '../../../core/platform_layout.dart';
import '../app_drawer_model.dart';

class DesktopNavigationSidebar extends StatelessWidget {
  const DesktopNavigationSidebar({
    super.key,
    required this.model,
    this.child,
    this.backgroundColor,
  });

  final AppDrawerModel model;
  final Widget? child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final content = child ?? _DesktopNavigationSidebarContent(model: model);
    final background =
        backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? MemoFlowPalette.backgroundDark
            : MemoFlowPalette.backgroundLight);
    final wrapped = ColoredBox(
      key: const ValueKey<String>('desktop-navigation-sidebar'),
      color: background,
      child: content,
    );
    return SizedBox(width: kWindowsDesktopSidebarWidth, child: wrapped);
  }
}

class _DesktopNavigationSidebarContent extends StatelessWidget {
  const _DesktopNavigationSidebarContent({required this.model});

  final AppDrawerModel model;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.65);
    final hover = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textMain,
              ),
            ),
            if (model.quickActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: model.quickActions
                    .map((item) {
                      return Tooltip(
                        message: item.tooltip,
                        child: AppPressScale(
                          scaleDown: 0.95,
                          child: InkWell(
                            onTap: item.onTap,
                            borderRadius: BorderRadius.circular(10),
                            hoverColor: hover,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: Icon(
                                      item.icon,
                                      size: 18,
                                      color: item.iconColor ?? textMuted,
                                    ),
                                  ),
                                  if (item.showBadge)
                                    Positioned(
                                      right: 6,
                                      top: 6,
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
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            if (model.stats.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: model.stats.items
                    .map((item) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.value,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                            ),
                          ),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textMuted,
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ...model.destinations.map(
                    (item) => _SidebarDestinationButton(
                      item: item,
                      hoverColor: hover,
                      textMain: textMain,
                    ),
                  ),
                  if (model.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...model.tags
                        .take(8)
                        .map(
                          (tag) => ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(
                              tag.label,
                              style: TextStyle(color: textMain),
                            ),
                            trailing: Text(
                              tag.count.toString(),
                              style: TextStyle(color: textMuted),
                            ),
                            selected: tag.selected,
                            onTap: tag.onTap,
                          ),
                        ),
                  ],
                ],
              ),
            ),
            if (model.versionText.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  model.versionText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDestinationButton extends StatelessWidget {
  const _SidebarDestinationButton({
    required this.item,
    required this.hoverColor,
    required this.textMain,
  });

  final AppDrawerDestinationItem item;
  final Color hoverColor;
  final Color textMain;

  @override
  Widget build(BuildContext context) {
    final background = item.selected
        ? MemoFlowPalette.primary
        : Colors.transparent;
    final foreground = item.selected ? Colors.white : textMain;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AppPressScale(
        child: AnimatedContainer(
          duration: AppMotion.effectiveDuration(
            context,
            item.selected ? AppMotion.windowsSelection : AppMotion.windowsHover,
          ),
          curve: AppMotion.emphasizedEnterCurve,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            boxShadow: item.selected
                ? [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: MemoFlowPalette.primary.withValues(alpha: 0.18),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              hoverColor: item.selected ? null : hoverColor,
              onTap: item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(item.icon, color: foreground, size: 22),
                        if (item.showBadge)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: item.selected
                                    ? Colors.white
                                    : MemoFlowPalette.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: foreground,
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
    );
  }
}
