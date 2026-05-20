import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/desktop/window_chrome_safe_area.dart';
import '../../../core/memoflow_palette.dart';
import '../home_quick_actions.dart';
import 'memos_list_search_widgets.dart';

const double kMemosListMacosTitleBarHeight = kMacosTitleBarHeight;
const double kMemosListMacosTrafficLightSafeInset =
    kMacosTrafficLightReservedWidth;
const Key kMemosListMacosTitleBarKey = ValueKey<String>(
  'memos-list-macos-titlebar',
);
const Key kMemosListMacosTrafficSafeInsetKey = ValueKey<String>(
  'memos-list-macos-traffic-safe-inset',
);

class MemosListMacosDesktopTitleBar extends StatelessWidget {
  const MemosListMacosDesktopTitleBar({
    super.key,
    required this.isDark,
    required this.searching,
    required this.showPillActions,
    required this.enableHomeSort,
    required this.enableSearch,
    required this.titleChild,
    required this.searchFieldChild,
    required this.quickActions,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.searchTooltip,
    required this.cancelTooltip,
    this.sortButton,
  });

  final bool isDark;
  final bool searching;
  final bool showPillActions;
  final bool enableHomeSort;
  final bool enableSearch;
  final Widget titleChild;
  final Widget searchFieldChild;
  final List<HomeQuickActionChipData> quickActions;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final String searchTooltip;
  final String cancelTooltip;
  final Widget? sortButton;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return Material(
      color: backgroundColor,
      child: Container(
        key: kMemosListMacosTitleBarKey,
        height: kMemosListMacosTitleBarHeight,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DragToMoveArea(child: SizedBox.expand()),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 680;
                  final hideSort = constraints.maxWidth < 520;
                  return Row(
                    children: [
                      const SizedBox(
                        key: kMemosListMacosTrafficSafeInsetKey,
                        width: kMemosListMacosTrafficLightSafeInset,
                      ),
                      if (searching)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: searchFieldChild,
                          ),
                        )
                      else ...[
                        if (!compact) ...[
                          Flexible(
                            flex: 2,
                            child: DefaultTextStyle.merge(
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              child: titleChild,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 5,
                          child: Align(
                            alignment: Alignment.center,
                            child: showPillActions && quickActions.isNotEmpty
                                ? ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 560,
                                    ),
                                    child: MemosListPillRow(
                                      quickActions: quickActions,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searching)
                            IconButton(
                              tooltip: cancelTooltip,
                              onPressed: onCloseSearch,
                              icon: const Icon(Icons.close),
                            )
                          else ...[
                            if (enableHomeSort &&
                                sortButton != null &&
                                !hideSort)
                              sortButton!,
                            if (enableSearch)
                              IconButton(
                                tooltip: searchTooltip,
                                onPressed: onOpenSearch,
                                icon: const Icon(Icons.search),
                              ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
