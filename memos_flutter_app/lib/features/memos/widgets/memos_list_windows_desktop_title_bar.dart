import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/app_motion_widgets.dart';
import '../../../core/memoflow_palette.dart';
import '../../home/desktop/windows_desktop_command_bar.dart';
import '../home_quick_actions.dart';
import 'memos_list_search_widgets.dart';

class MemosListWindowsDesktopTitleBar extends StatelessWidget {
  const MemosListWindowsDesktopTitleBar({
    super.key,
    required this.isDark,
    required this.showPillActions,
    required this.windowsHeaderSearchExpanded,
    required this.enableHomeSort,
    required this.enableSearch,
    required this.screenshotModeEnabled,
    required this.desktopWindowMaximized,
    required this.debugApiVersionText,
    required this.titleChild,
    required this.searchFieldChild,
    this.sortButton,
    required this.onToggleSearch,
    required this.quickActions,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    required this.searchTooltip,
    required this.cancelTooltip,
    required this.minimizeTooltip,
    required this.maximizeTooltip,
    required this.restoreTooltip,
    required this.closeTooltip,
  });

  final bool isDark;
  final bool showPillActions;
  final bool windowsHeaderSearchExpanded;
  final bool enableHomeSort;
  final bool enableSearch;
  final bool screenshotModeEnabled;
  final bool desktopWindowMaximized;
  final String debugApiVersionText;
  final Widget titleChild;
  final Widget searchFieldChild;
  final Widget? sortButton;
  final VoidCallback onToggleSearch;
  final List<HomeQuickActionChipData> quickActions;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
  final String searchTooltip;
  final String cancelTooltip;
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
        child: AppSharedAxisSwitcher(
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 200),
          axis: Axis.horizontal,
          offset: 0.024,
          scaleBegin: 0.985,
          animateSize: true,
          child: KeyedSubtree(
            key: ValueKey<String>(
              windowsHeaderSearchExpanded
                  ? 'windows-desktop-search'
                  : (showPillActions && quickActions.isNotEmpty
                        ? 'windows-desktop-quick-actions'
                        : 'windows-desktop-center-empty'),
            ),
            child: windowsHeaderSearchExpanded
                ? searchFieldChild
                : (showPillActions && quickActions.isNotEmpty
                      ? MemosListPillRow(quickActions: quickActions)
                      : const SizedBox.shrink()),
          ),
        ),
      ),
      trailing: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enableHomeSort && sortButton != null) ...[
              sortButton!,
              const SizedBox(width: 2),
            ],
            if (enableSearch)
              IconButton(
                tooltip: windowsHeaderSearchExpanded
                    ? cancelTooltip
                    : searchTooltip,
                onPressed: onToggleSearch,
                icon: Icon(
                  windowsHeaderSearchExpanded ? Icons.close : Icons.search,
                ),
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
