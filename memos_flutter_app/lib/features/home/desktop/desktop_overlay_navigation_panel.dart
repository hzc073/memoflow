import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';
import '../../../core/platform_layout.dart';
import '../app_drawer_model.dart';
import 'desktop_navigation_sidebar.dart';

class DesktopOverlayNavigationPanel extends StatelessWidget {
  const DesktopOverlayNavigationPanel({super.key, required this.model});

  final AppDrawerModel model;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: const ValueKey<String>('desktop-overlay-navigation-panel'),
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: kWindowsDesktopSidebarWidth,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? MemoFlowPalette.cardDark
                : MemoFlowPalette.backgroundLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: DesktopNavigationSidebar(model: model),
        ),
      ),
    );
  }
}
