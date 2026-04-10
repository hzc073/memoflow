import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/memoflow_palette.dart';
import '../home_quick_actions.dart';
import 'memos_list_search_widgets.dart';
import 'memos_list_title_menu.dart';

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
    final barBg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DragToMoveArea(child: SizedBox.expand()),
          Row(
            children: [
              SizedBox(
                width: 260,
                child: Row(
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: windowsHeaderSearchExpanded
                          ? searchFieldChild
                          : (showPillActions && quickActions.isNotEmpty
                                ? MemosListPillRow(quickActions: quickActions)
                                : const SizedBox.shrink()),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
              if (kDebugMode && !screenshotModeEnabled) ...[
                IgnorePointer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MemoFlowPalette.primary.withValues(
                          alpha: isDark ? 0.24 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.45 : 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        debugApiVersionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MemoFlowPalette.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              DesktopWindowIconButton(
                tooltip: minimizeTooltip,
                onPressed: onMinimize,
                icon: Icons.minimize_rounded,
              ),
              DesktopWindowIconButton(
                tooltip: desktopWindowMaximized
                    ? restoreTooltip
                    : maximizeTooltip,
                onPressed: onToggleMaximize,
                icon: desktopWindowMaximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
              ),
              DesktopWindowIconButton(
                tooltip: closeTooltip,
                onPressed: onClose,
                icon: Icons.close_rounded,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
