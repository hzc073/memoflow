import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';
import '../../home/desktop/windows_desktop_command_bar.dart';
import '../home_quick_actions.dart';
import 'memos_list_search_widgets.dart';

class MemosListWindowsDesktopTitleBar extends StatelessWidget {
  const MemosListWindowsDesktopTitleBar({
    super.key,
    required this.isDark,
    required this.showPillActions,
    required this.enableHomeSort,
    required this.enableSearch,
    required this.screenshotModeEnabled,
    required this.desktopWindowMaximized,
    required this.debugApiVersionText,
    required this.titleChild,
    this.sortButton,
    required this.onOpenSearch,
    required this.quickActions,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    required this.searchTooltip,
    required this.minimizeTooltip,
    required this.maximizeTooltip,
    required this.restoreTooltip,
    required this.closeTooltip,
  });

  final bool isDark;
  final bool showPillActions;
  final bool enableHomeSort;
  final bool enableSearch;
  final bool screenshotModeEnabled;
  final bool desktopWindowMaximized;
  final String debugApiVersionText;
  final Widget titleChild;
  final Widget? sortButton;
  final VoidCallback onOpenSearch;
  final List<HomeQuickActionChipData> quickActions;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
  final String searchTooltip;
  final String minimizeTooltip;
  final String maximizeTooltip;
  final String restoreTooltip;
  final String closeTooltip;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return WindowsDesktopCommandBar(
      leading: Row(
        children: [
          IgnorePointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/splash/splash_logo.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.auto_stories_rounded,
                    size: 22,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: textColor, fontSize: 14),
              child: titleChild,
            ),
          ),
        ],
      ),
      center: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: showPillActions && quickActions.isNotEmpty
            ? MemosListPillRow(quickActions: quickActions)
            : const SizedBox.shrink(),
      ),
      trailing: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enableHomeSort && sortButton != null) sortButton!,
            if (enableSearch)
              IconButton(
                tooltip: searchTooltip,
                onPressed: onOpenSearch,
                icon: const Icon(Icons.search),
              ),
          ],
        ),
      ),
      debugBadgeText: kDebugMode && !screenshotModeEnabled
          ? debugApiVersionText
          : null,
      desktopWindowMaximized: desktopWindowMaximized,
      onMinimize: onMinimize,
      onToggleMaximize: onToggleMaximize,
      onClose: onClose,
      minimizeTooltip: minimizeTooltip,
      maximizeTooltip: maximizeTooltip,
      restoreTooltip: restoreTooltip,
      closeTooltip: closeTooltip,
    );
  }
}
