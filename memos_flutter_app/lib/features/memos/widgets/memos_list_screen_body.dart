import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';
import '../../../core/platform_layout.dart';
import '../../../core/scene_micro_guide_widgets.dart';
import '../../../data/models/local_memo.dart';
import '../../../data/repositories/scene_micro_guide_repository.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/memos/memos_providers.dart';
import '../../home/app_drawer_menu_button.dart';
import '../memos_list_screen_view_state.dart';
import 'floating_collapse_button.dart';
import 'memos_list_floating_actions.dart';
import 'memos_list_search_widgets.dart';
import 'memos_list_windows_desktop_title_bar.dart';

typedef MemosListAnimatedItemBuilder =
    Widget Function(
      BuildContext context,
      int index,
      Animation<double> animation,
    );

@immutable
class MemosListScreenBodyData {
  const MemosListScreenBodyData({
    required this.viewState,
    required this.searching,
    required this.showFilterTagChip,
    required this.enableSearch,
    required this.enableTitleMenu,
    required this.screenshotModeEnabled,
    required this.windowsHeaderSearchExpanded,
    required this.desktopWindowMaximized,
    required this.debugApiVersionText,
    required this.activeListGuideId,
    required this.activeListGuideMessage,
    required this.memosLoading,
    required this.memosError,
    required this.visibleMemos,
    required this.showLoadMoreHint,
    required this.loadMoreHintDisplayText,
    required this.loadMoreHintTextColor,
    required this.headerBackgroundColor,
    required this.bottomInset,
    required this.showBackToTop,
    required this.hapticsEnabled,
    required this.floatingCollapseVisible,
    required this.floatingCollapseScrolling,
  });

  final MemosListScreenViewState viewState;
  final bool searching;
  final bool showFilterTagChip;
  final bool enableSearch;
  final bool enableTitleMenu;
  final bool screenshotModeEnabled;
  final bool windowsHeaderSearchExpanded;
  final bool desktopWindowMaximized;
  final String debugApiVersionText;
  final SceneMicroGuideId? activeListGuideId;
  final String? activeListGuideMessage;
  final bool memosLoading;
  final Object? memosError;
  final List<LocalMemo> visibleMemos;
  final bool showLoadMoreHint;
  final String loadMoreHintDisplayText;
  final Color loadMoreHintTextColor;
  final Color headerBackgroundColor;
  final double bottomInset;
  final bool showBackToTop;
  final bool hapticsEnabled;
  final bool floatingCollapseVisible;
  final bool floatingCollapseScrolling;
}

class MemosListScreenBody extends StatelessWidget {
  const MemosListScreenBody({
    super.key,
    required this.scaffoldKey,
    required this.scrollController,
    required this.floatingCollapseViewportKey,
    required this.listKey,
    required this.data,
    required this.drawerPanel,
    required this.titleChild,
    required this.searchFieldChild,
    required this.sortButton,
    required this.resolvedTagChip,
    required this.advancedFilterSliver,
    required this.inlineComposeChild,
    required this.tagFilterBarChild,
    required this.searchLandingChild,
    required this.bootstrapOverlayChild,
    required this.floatingActionButton,
    required this.onRefresh,
    required this.onScrollNotification,
    required this.onPointerSignal,
    required this.onCloseSearch,
    required this.onOpenSearch,
    required this.onToggleWindowsHeaderSearch,
    required this.onToggleQuickSearchKind,
    required this.onDismissGuide,
    required this.onCollapseFloatingMemo,
    required this.onScrollToTop,
    required this.onWeeklyInsights,
    required this.onAiSummary,
    required this.onDailyReview,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    required this.onEditTag,
    required this.animatedItemBuilder,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final ScrollController scrollController;
  final GlobalKey floatingCollapseViewportKey;
  final GlobalKey<SliverAnimatedListState> listKey;
  final MemosListScreenBodyData data;
  final Widget? drawerPanel;
  final Widget titleChild;
  final Widget searchFieldChild;
  final Widget? sortButton;
  final Widget? resolvedTagChip;
  final Widget? advancedFilterSliver;
  final Widget? inlineComposeChild;
  final Widget? tagFilterBarChild;
  final Widget? searchLandingChild;
  final Widget? bootstrapOverlayChild;
  final Widget? floatingActionButton;
  final RefreshCallback onRefresh;
  final NotificationListenerCallback<ScrollNotification> onScrollNotification;
  final void Function(PointerSignalEvent event) onPointerSignal;
  final VoidCallback onCloseSearch;
  final VoidCallback onOpenSearch;
  final VoidCallback onToggleWindowsHeaderSearch;
  final ValueChanged<QuickSearchKind> onToggleQuickSearchKind;
  final VoidCallback onDismissGuide;
  final VoidCallback onCollapseFloatingMemo;
  final VoidCallback onScrollToTop;
  final VoidCallback onWeeklyInsights;
  final VoidCallback onAiSummary;
  final VoidCallback onDailyReview;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
  final Future<void> Function() onEditTag;
  final MemosListAnimatedItemBuilder animatedItemBuilder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memoListBody = Stack(
      key: floatingCollapseViewportKey,
      children: [
        RefreshIndicator(
          onRefresh: onRefresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: onScrollNotification,
            child: Listener(
              onPointerSignal: onPointerSignal,
              child: CustomScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: data.headerBackgroundColor,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    toolbarHeight:
                        data.viewState.layout.useWindowsDesktopHeader &&
                            !data.searching
                        ? 0
                        : kToolbarHeight,
                    titleSpacing:
                        data.viewState.layout.useWindowsDesktopHeader &&
                            !data.searching
                        ? 0
                        : NavigationToolbar.kMiddleSpacing,
                    automaticallyImplyLeading:
                        !data.viewState.layout.useWindowsDesktopHeader &&
                        !data.searching &&
                        drawerPanel == null,
                    leading: data.viewState.layout.useWindowsDesktopHeader
                        ? null
                        : (data.searching
                              ? IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new),
                                  onPressed: onCloseSearch,
                                )
                              : (drawerPanel != null &&
                                        !data
                                            .viewState
                                            .layout
                                            .useDesktopSidePane
                                    ? AppDrawerMenuButton(
                                        tooltip: context
                                            .t
                                            .strings
                                            .legacy
                                            .msg_toggle_sidebar,
                                        iconColor:
                                            Theme.of(
                                              context,
                                            ).appBarTheme.iconTheme?.color ??
                                            IconTheme.of(context).color ??
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                        badgeBorderColor:
                                            data.headerBackgroundColor,
                                      )
                                    : null)),
                    title:
                        data.viewState.layout.useWindowsDesktopHeader &&
                            !data.searching
                        ? null
                        : (data.searching ? searchFieldChild : titleChild),
                    actions:
                        data.viewState.layout.useWindowsDesktopHeader &&
                            !data.searching
                        ? null
                        : [
                            if (!data.searching &&
                                data.viewState.activeTagStat?.tagId != null)
                              IconButton(
                                tooltip: context.t.strings.legacy.msg_edit_tag,
                                onPressed: () async => onEditTag(),
                                icon: const Icon(Icons.edit),
                              ),
                            if (data.enableSearch) ...[
                              if (!data.searching &&
                                  data.viewState.query.enableHomeSort &&
                                  sortButton != null)
                                sortButton!,
                              if (!data.searching &&
                                  !data
                                      .viewState
                                      .layout
                                      .useWindowsDesktopHeader)
                                IconButton(
                                  tooltip: context.t.strings.legacy.msg_search,
                                  onPressed: onOpenSearch,
                                  icon: const Icon(Icons.search),
                                ),
                              if (data.searching)
                                TextButton(
                                  onPressed: onCloseSearch,
                                  child: Text(
                                    context.t.strings.legacy.msg_cancel_2,
                                    style: TextStyle(
                                      color: MemoFlowPalette.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                    bottom:
                        data.viewState.layout.useWindowsDesktopHeader &&
                            !data.searching
                        ? null
                        : data.searching
                        ? (data.viewState.query.useShortcutFilter
                              ? null
                              : PreferredSize(
                                  preferredSize: const Size.fromHeight(46),
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        8,
                                      ),
                                      child: MemosListSearchQuickFilterBar(
                                        selectedKind: data
                                            .viewState
                                            .query
                                            .selectedQuickSearchKind,
                                        onSelectKind: onToggleQuickSearchKind,
                                      ),
                                    ),
                                  ),
                                ))
                        : (data.viewState.layout.showHeaderPillActions
                              ? PreferredSize(
                                  preferredSize: const Size.fromHeight(46),
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        0,
                                      ),
                                      child: MemosListPillRow(
                                        onWeeklyInsights: onWeeklyInsights,
                                        onAiSummary: onAiSummary,
                                        onDailyReview: onDailyReview,
                                      ),
                                    ),
                                  ),
                                )
                              : (data.showFilterTagChip &&
                                        resolvedTagChip != null
                                    ? PreferredSize(
                                        preferredSize: const Size.fromHeight(
                                          48,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            10,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: resolvedTagChip!,
                                          ),
                                        ),
                                      )
                                    : null)),
                  ),
                  if (data.activeListGuideId != null &&
                      data.activeListGuideMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: SceneMicroGuideBanner(
                          message: data.activeListGuideMessage!,
                          onDismiss: onDismissGuide,
                        ),
                      ),
                    ),
                  if (inlineComposeChild != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: inlineComposeChild!,
                      ),
                    ),
                  if (tagFilterBarChild != null &&
                      data.viewState.recommendedTags.isNotEmpty &&
                      !data.searching)
                    SliverToBoxAdapter(child: tagFilterBarChild),
                  if (advancedFilterSliver != null) advancedFilterSliver!,
                  if (data.memosLoading && data.visibleMemos.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                  if (data.memosError != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          context.t.strings.legacy.msg_failed_load_3(
                            memosError: data.memosError ?? '',
                          ),
                        ),
                      ),
                    )
                  else if (data.viewState.query.showSearchLanding)
                    SliverToBoxAdapter(child: searchLandingChild)
                  else if (data.memosLoading && data.visibleMemos.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (data.visibleMemos.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 140),
                        child: Center(
                          child: Text(
                            data.searching
                                ? context.t.strings.legacy.msg_no_results_found
                                : context.t.strings.legacy.msg_no_content_yet,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        data.viewState.layout.listTopPadding +
                            data.viewState.layout.listVisualOffset,
                        16,
                        data.showLoadMoreHint ? 20 : 140,
                      ),
                      sliver: SliverAnimatedList(
                        key: listKey,
                        initialItemCount: data.visibleMemos.length,
                        itemBuilder: animatedItemBuilder,
                      ),
                    ),
                  if (data.showLoadMoreHint)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                data.loadMoreHintDisplayText,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                      color: data.loadMoreHintTextColor,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: MemoFloatingCollapseButton(
            visible: data.floatingCollapseVisible,
            scrolling: data.floatingCollapseScrolling,
            label: context.t.strings.legacy.msg_collapse,
            onPressed: onCollapseFloatingMemo,
            padding: EdgeInsets.only(
              top: data.viewState.layout.floatingCollapseTopPadding,
              right: 16,
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: data.viewState.layout.backToTopBaseOffset + data.bottomInset,
          child: BackToTopButton(
            visible: data.showBackToTop,
            hapticsEnabled: data.hapticsEnabled,
            onPressed: onScrollToTop,
          ),
        ),
        if (bootstrapOverlayChild != null)
          Positioned.fill(child: bootstrapOverlayChild!),
      ],
    );

    final bodyContent = () {
      if (!data.viewState.layout.useDesktopSidePane || drawerPanel == null) {
        return memoListBody;
      }
      final dividerColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08);
      final desktopContent = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kMemoFlowDesktopContentMaxWidth,
            ),
            child: memoListBody,
          ),
        ),
      );
      return Row(
        children: [
          SizedBox(width: kMemoFlowDesktopDrawerWidth, child: drawerPanel),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          Expanded(child: desktopContent),
        ],
      );
    }();

    final scaffoldBody =
        data.viewState.layout.useWindowsDesktopHeader && !data.searching
        ? Column(
            children: [
              MemosListWindowsDesktopTitleBar(
                isDark: isDark,
                showPillActions: data.viewState.layout.showHeaderPillActions,
                windowsHeaderSearchExpanded: data.windowsHeaderSearchExpanded,
                enableHomeSort: data.viewState.query.enableHomeSort,
                enableSearch: data.enableSearch,
                screenshotModeEnabled: data.screenshotModeEnabled,
                desktopWindowMaximized: data.desktopWindowMaximized,
                debugApiVersionText: data.debugApiVersionText,
                titleChild: data.enableTitleMenu
                    ? titleChild
                    : IgnorePointer(child: titleChild),
                searchFieldChild: searchFieldChild,
                sortButton: sortButton,
                onToggleSearch: onToggleWindowsHeaderSearch,
                onWeeklyInsights: onWeeklyInsights,
                onAiSummary: onAiSummary,
                onDailyReview: onDailyReview,
                onMinimize: onMinimize,
                onToggleMaximize: onToggleMaximize,
                onClose: onClose,
                searchTooltip: context.t.strings.legacy.msg_search,
                cancelTooltip: context.t.strings.legacy.msg_cancel_2,
                minimizeTooltip: context.t.strings.legacy.msg_minimize,
                maximizeTooltip: context.t.strings.legacy.msg_maximize,
                restoreTooltip: context.t.strings.legacy.msg_restore_window,
                closeTooltip: context.t.strings.legacy.msg_close,
              ),
              Expanded(child: bodyContent),
            ],
          )
        : bodyContent;

    return Scaffold(
      key: scaffoldKey,
      drawer: data.viewState.layout.useDesktopSidePane ? null : drawerPanel,
      drawerEnableOpenDragGesture:
          !data.viewState.layout.useDesktopSidePane && !data.searching,
      drawerEdgeDragWidth:
          !data.viewState.layout.useDesktopSidePane && !data.searching
          ? MediaQuery.sizeOf(context).width
          : null,
      body: scaffoldBody,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: floatingActionButton,
    );
  }
}
