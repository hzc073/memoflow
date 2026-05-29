import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/app_motion.dart';
import '../../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../../core/memoflow_palette.dart';
import '../../../core/platform_layout.dart';
import '../../../core/scene_micro_guide_widgets.dart';
import '../../../data/ai/ai_semantic_memo_search_service.dart';
import '../../../data/models/local_memo.dart';
import '../../../data/repositories/scene_micro_guide_repository.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/memos/memos_providers.dart';
import '../../home/app_drawer.dart';
import '../../home/app_drawer_menu_button.dart';
import '../../home/desktop/desktop_shell_host.dart';
import '../home_quick_actions.dart';
import '../memos_list_floating_collapse_controller.dart';
import '../memos_list_screen_view_state.dart';
import 'floating_collapse_button.dart';
import 'memos_list_desktop_split_layout.dart';
import 'memos_list_floating_actions.dart';
import 'memos_list_macos_desktop_title_bar.dart';
import 'memos_list_search_widgets.dart';
import 'memos_list_windows_desktop_title_bar.dart';

typedef MemosListAnimatedItemBuilder =
    Widget Function(
      BuildContext context,
      int index,
      Animation<double> animation,
    );

typedef DesktopDrawerPanelBuilder =
    Widget Function(AppDrawerViewMode viewMode, bool embedded);

const DesktopShellSecondaryPaneMotionSpec _desktopMemoPreviewPaneMotionSpec =
    DesktopShellSecondaryPaneMotionSpec(
      resizeDuration: AppMotion.desktopPreviewPaneResize,
      surfaceEnterDuration: AppMotion.desktopPreviewPaneEnter,
      surfaceExitDuration: AppMotion.desktopPreviewPaneExit,
      resizeCurve: AppMotion.desktopPreviewResizeCurve,
      surfaceEnterCurve: AppMotion.desktopPreviewRevealCurve,
      surfaceExitCurve: AppMotion.desktopPreviewSwapCurve,
      surfaceEntryOffset: Offset(0.012, 0),
      surfaceEntryScale: 0.992,
    );

const double _memoListFloatingActionGap = 12;
const double _memoListFloatingActionHorizontalInset = 16;
const SpringDescription _memoListFloatingActionSideSpring = SpringDescription(
  mass: 1,
  stiffness: 480,
  damping: 36,
);
const Tolerance _memoListFloatingActionSideTolerance = Tolerance(
  distance: 0.00001,
  velocity: 0.0001,
);
const double _memoListFloatingActionTravelScaleDelta = 0.025;
const double _memoListFloatingActionTravelOpacityDelta = 0.04;
const double _memoListDrawerQuickOpenDistance = 28;
const double _memoListDrawerQuickOpenDirectionRatio = 1.35;

enum _MemoListFloatingActionSide { left, right }

bool _usesNativeMobilePlatform(BuildContext context) {
  if (kIsWeb) return false;
  return switch (Theme.of(context).platform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };
}

extension _MemoListFloatingActionSideLayout on _MemoListFloatingActionSide {
  double get springValue {
    return switch (this) {
      _MemoListFloatingActionSide.left => 0,
      _MemoListFloatingActionSide.right => 1,
    };
  }

  CrossAxisAlignment get crossAxisAlignment {
    return switch (this) {
      _MemoListFloatingActionSide.left => CrossAxisAlignment.start,
      _MemoListFloatingActionSide.right => CrossAxisAlignment.end,
    };
  }
}

typedef _MemoListBodyBuilder =
    Widget Function(
      BuildContext context,
      _MemoListFloatingActionSide side,
      NotificationListenerCallback<ScrollNotification> onScrollNotification,
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
    required this.desktopHeaderSearchExpanded,
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
    required this.hapticsEnabled,
    required this.desktopPreviewVisible,
    required this.enableDrawerOpenDragGesture,
  });

  final MemosListScreenViewState viewState;
  final bool searching;
  final bool showFilterTagChip;
  final bool enableSearch;
  final bool enableTitleMenu;
  final bool screenshotModeEnabled;
  final bool desktopHeaderSearchExpanded;
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
  final bool hapticsEnabled;
  final bool desktopPreviewVisible;
  final bool enableDrawerOpenDragGesture;
}

class _MemoListFloatingActionSideScope extends StatefulWidget {
  const _MemoListFloatingActionSideScope({
    required this.viewportKey,
    required this.onScrollNotification,
    required this.builder,
  });

  final GlobalKey viewportKey;
  final NotificationListenerCallback<ScrollNotification> onScrollNotification;
  final _MemoListBodyBuilder builder;

  @override
  State<_MemoListFloatingActionSideScope> createState() =>
      _MemoListFloatingActionSideScopeState();
}

class _MemoListFloatingActionSideScopeState
    extends State<_MemoListFloatingActionSideScope> {
  var _side = _MemoListFloatingActionSide.right;
  _MemoListFloatingActionSide? _pendingDragSide;

  bool _handleScrollNotification(ScrollNotification notification) {
    _handleAdaptiveSideScrollNotification(notification);
    return widget.onScrollNotification(notification);
  }

  void _handleAdaptiveSideScrollNotification(ScrollNotification notification) {
    if (!_usesMobileAdaptiveSide(context)) {
      _pendingDragSide = null;
      return;
    }
    if (notification is ScrollStartNotification) {
      _pendingDragSide = _sideForGlobalPosition(
        notification.dragDetails?.globalPosition,
      );
      return;
    }
    if (notification is ScrollUpdateNotification) {
      _commitPendingDragSide(notification.dragDetails?.globalPosition);
      return;
    }
    if (notification is OverscrollNotification) {
      _commitPendingDragSide(notification.dragDetails?.globalPosition);
      return;
    }
    if (notification is ScrollEndNotification) {
      _pendingDragSide = null;
    }
  }

  void _commitPendingDragSide(Offset? fallbackGlobalPosition) {
    final nextSide =
        _pendingDragSide ?? _sideForGlobalPosition(fallbackGlobalPosition);
    _pendingDragSide = null;
    if (nextSide == null || nextSide == _side) return;
    setState(() => _side = nextSide);
  }

  _MemoListFloatingActionSide? _sideForGlobalPosition(Offset? globalPosition) {
    if (globalPosition == null) return null;

    final viewportContext = widget.viewportKey.currentContext;
    final renderObject = viewportContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final localPosition = renderObject.globalToLocal(globalPosition);
    final midpoint = renderObject.size.width / 2;
    if (localPosition.dx == midpoint) return null;
    return localPosition.dx < midpoint
        ? _MemoListFloatingActionSide.left
        : _MemoListFloatingActionSide.right;
  }

  bool _usesMobileAdaptiveSide(BuildContext context) {
    return _usesNativeMobilePlatform(context);
  }

  _MemoListFloatingActionSide _resolvedSide(BuildContext context) {
    return _usesMobileAdaptiveSide(context)
        ? _side
        : _MemoListFloatingActionSide.right;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _resolvedSide(context),
      _handleScrollNotification,
    );
  }
}

class _MemoListResponsiveDrawerOpenDrag extends StatefulWidget {
  const _MemoListResponsiveDrawerOpenDrag({
    required this.enabled,
    required this.scaffoldKey,
    required this.child,
  });

  final bool enabled;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget child;

  @override
  State<_MemoListResponsiveDrawerOpenDrag> createState() =>
      _MemoListResponsiveDrawerOpenDragState();
}

class _MemoListResponsiveDrawerOpenDragState
    extends State<_MemoListResponsiveDrawerOpenDrag> {
  int? _activePointer;
  Offset? _downPosition;
  bool _openQueuedForPointer = false;

  void _clearPointer() {
    _activePointer = null;
    _downPosition = null;
    _openQueuedForPointer = false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _activePointer = event.pointer;
    _downPosition = event.position;
    _openQueuedForPointer = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.enabled || _openQueuedForPointer) return;
    if (_activePointer != event.pointer) return;

    final downPosition = _downPosition;
    if (downPosition == null) return;

    final delta = event.position - downPosition;
    if (delta.dx < _memoListDrawerQuickOpenDistance) return;
    if (delta.dx < delta.dy.abs() * _memoListDrawerQuickOpenDirectionRatio) {
      return;
    }

    _openQueuedForPointer = true;
    _scheduleOpenDrawer();
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    if (_activePointer != event.pointer) return;
    if (event is PointerUpEvent && _openQueuedForPointer) {
      _scheduleOpenDrawer();
    }
    _clearPointer();
  }

  void _scheduleOpenDrawer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) return;
      final scaffoldState = widget.scaffoldKey.currentState;
      if (scaffoldState == null || scaffoldState.isDrawerOpen) return;
      scaffoldState.openDrawer();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUpOrCancel,
      onPointerCancel: _handlePointerUpOrCancel,
      child: widget.child,
    );
  }
}

class _MemoListFloatingActionSideSpringTransition extends StatefulWidget {
  const _MemoListFloatingActionSideSpringTransition({
    required this.side,
    required this.child,
  });

  final _MemoListFloatingActionSide side;
  final Widget child;

  @override
  State<_MemoListFloatingActionSideSpringTransition> createState() =>
      _MemoListFloatingActionSideSpringTransitionState();
}

class _MemoListFloatingActionSideSpringTransitionState
    extends State<_MemoListFloatingActionSideSpringTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double get _targetValue => widget.side.springValue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.side.springValue,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.isEnabled(context)) {
      _jumpToTarget();
    }
  }

  @override
  void didUpdateWidget(
    covariant _MemoListFloatingActionSideSpringTransition oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.side != widget.side) {
      _animateToTarget();
      return;
    }
    if (!AppMotion.isEnabled(context) && _controller.value != _targetValue) {
      _jumpToTarget();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateToTarget() {
    if (!AppMotion.isEnabled(context)) {
      _jumpToTarget();
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        _memoListFloatingActionSideSpring,
        _controller.value,
        _targetValue,
        _controller.velocity,
        tolerance: _memoListFloatingActionSideTolerance,
      ),
    );
  }

  void _jumpToTarget() {
    _controller.stop();
    _controller.value = _targetValue;
  }

  @override
  Widget build(BuildContext context) {
    final motionEnabled = AppMotion.isEnabled(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = motionEnabled ? _controller.value : _targetValue;
        final sideDistance = (value - _targetValue).abs().clamp(0.0, 1.0);
        final velocitySoftness = motionEnabled
            ? (_controller.velocity.abs() / 6).clamp(0.0, 1.0)
            : 0.0;
        final travelSoftness = (sideDistance + velocitySoftness * 0.08)
            .clamp(0.0, 1.0)
            .toDouble();
        final scale =
            1 - travelSoftness * _memoListFloatingActionTravelScaleDelta;
        final opacity =
            1 - travelSoftness * _memoListFloatingActionTravelOpacityDelta;

        return Align(
          alignment: Alignment(value * 2 - 1, 1),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
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
    required this.inlineComposePadding,
    required this.expandDesktopBodyWidth,
    required this.tagFilterBarChild,
    required this.searchLandingChild,
    required this.bootstrapOverlayChild,
    this.desktopPrimaryContentOverride,
    required this.desktopPreviewPane,
    required this.desktopEditorModalSurface,
    required this.desktopEditorModalVisible,
    required this.desktopPreviewPaneWidth,
    this.onDesktopPreviewPaneWidthChanged,
    required this.floatingActionButton,
    required this.onRefresh,
    required this.onScrollNotification,
    required this.onPointerSignal,
    required this.showBackToTopListenable,
    required this.floatingCollapseListenable,
    required this.onCloseSearch,
    required this.onOpenSearch,
    required this.onToggleDesktopHeaderSearch,
    required this.onToggleQuickSearchKind,
    required this.onStartAiSearch,
    required this.onStopAiSearch,
    required this.onDismissGuide,
    required this.onViewportLayoutChanged,
    required this.onCollapseFloatingMemo,
    required this.onScrollToTop,
    required this.quickActions,
    this.desktopDrawerPanelBuilder,
    this.desktopTrailingActions = const <Widget>[],
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
  final EdgeInsets inlineComposePadding;
  final bool expandDesktopBodyWidth;
  final Widget? tagFilterBarChild;
  final Widget? searchLandingChild;
  final Widget? bootstrapOverlayChild;
  final Widget? desktopPrimaryContentOverride;
  final Widget? desktopPreviewPane;
  final Widget? desktopEditorModalSurface;
  final bool desktopEditorModalVisible;
  final double desktopPreviewPaneWidth;
  final ValueChanged<double>? onDesktopPreviewPaneWidthChanged;
  final Widget? floatingActionButton;
  final RefreshCallback onRefresh;
  final NotificationListenerCallback<ScrollNotification> onScrollNotification;
  final void Function(PointerSignalEvent event) onPointerSignal;
  final ValueListenable<bool> showBackToTopListenable;
  final ValueListenable<MemosListFloatingCollapseState>
  floatingCollapseListenable;
  final VoidCallback onCloseSearch;
  final VoidCallback onOpenSearch;
  final VoidCallback onToggleDesktopHeaderSearch;
  final ValueChanged<QuickSearchKind> onToggleQuickSearchKind;
  final VoidCallback onStartAiSearch;
  final VoidCallback onStopAiSearch;
  final VoidCallback onDismissGuide;
  final VoidCallback onViewportLayoutChanged;
  final VoidCallback onCollapseFloatingMemo;
  final VoidCallback onScrollToTop;
  final List<HomeQuickActionChipData> quickActions;
  final DesktopDrawerPanelBuilder? desktopDrawerPanelBuilder;
  final List<Widget> desktopTrailingActions;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
  final Future<void> Function() onEditTag;
  final MemosListAnimatedItemBuilder animatedItemBuilder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useWindowsDesktopHeader =
        data.viewState.layout.useWindowsDesktopHeader;
    final useMacosDesktopTitleBar =
        data.viewState.layout.useMacosDesktopTitleBar;
    final desktopPrimaryContentOverridden =
        desktopPrimaryContentOverride != null;
    final useExternalDesktopTitleBar =
        useWindowsDesktopHeader || useMacosDesktopTitleBar;
    final showHeaderPillActionsInScroll =
        data.viewState.layout.showHeaderPillActions &&
        !useMacosDesktopTitleBar &&
        !desktopPrimaryContentOverridden;
    final statusTransitionDuration = AppMotion.effectiveDuration(
      context,
      AppMotion.medium,
    );
    final query = data.viewState.query;
    final statusChild = data.viewState.query.showSearchLanding
        ? null
        : data.memosError != null
        ? _buildErrorStatus(context, data.memosError!, query.useAiSearch)
        : (data.memosLoading && data.visibleMemos.isEmpty)
        ? _buildLoadingStatus(context, query.useAiSearch)
        : (data.visibleMemos.isEmpty)
        ? _buildEmptyStatus(context, data)
        : null;
    final statusKey = data.viewState.query.showSearchLanding
        ? null
        : data.memosError != null
        ? (query.useAiSearch ? 'ai-error' : 'error')
        : (data.memosLoading && data.visibleMemos.isEmpty)
        ? (query.useAiSearch ? 'ai-loading' : 'loading')
        : (data.visibleMemos.isEmpty)
        ? (query.useAiSearch ? 'ai-empty' : 'empty')
        : null;
    final memoListBody =
        desktopPrimaryContentOverride ??
        _MemoListFloatingActionSideScope(
          viewportKey: floatingCollapseViewportKey,
          onScrollNotification: onScrollNotification,
          builder: (context, floatingActionSide, handleScrollNotification) {
            return NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                onViewportLayoutChanged();
                return false;
              },
              child: SizeChangedLayoutNotifier(
                child: Stack(
                  key: floatingCollapseViewportKey,
                  children: [
                    RefreshIndicator(
                      onRefresh: onRefresh,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: handleScrollNotification,
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
                                toolbarHeight: useExternalDesktopTitleBar
                                    ? 0
                                    : kToolbarHeight,
                                titleSpacing: useExternalDesktopTitleBar
                                    ? 0
                                    : NavigationToolbar.kMiddleSpacing,
                                automaticallyImplyLeading:
                                    !useExternalDesktopTitleBar &&
                                    !data.searching &&
                                    drawerPanel == null,
                                leading: useExternalDesktopTitleBar
                                    ? null
                                    : (data.searching
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.arrow_back_ios_new,
                                              ),
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
                                                        Theme.of(context)
                                                            .appBarTheme
                                                            .iconTheme
                                                            ?.color ??
                                                        IconTheme.of(
                                                          context,
                                                        ).color ??
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                    badgeBorderColor: data
                                                        .headerBackgroundColor,
                                                  )
                                                : null)),
                                title: useExternalDesktopTitleBar
                                    ? null
                                    : (data.searching
                                          ? searchFieldChild
                                          : titleChild),
                                actions: useExternalDesktopTitleBar
                                    ? null
                                    : [
                                        if (!data.searching &&
                                            data
                                                    .viewState
                                                    .activeTagStat
                                                    ?.tagId !=
                                                null)
                                          IconButton(
                                            tooltip: context
                                                .t
                                                .strings
                                                .legacy
                                                .msg_edit_tag,
                                            onPressed: () async => onEditTag(),
                                            icon: const Icon(Icons.edit),
                                          ),
                                        if (data.enableSearch) ...[
                                          if (!data.searching &&
                                              data
                                                  .viewState
                                                  .query
                                                  .enableHomeSort &&
                                              sortButton != null)
                                            sortButton!,
                                          if (!data.searching &&
                                              !data
                                                  .viewState
                                                  .layout
                                                  .useWindowsDesktopHeader)
                                            IconButton(
                                              tooltip: context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_search,
                                              onPressed: onOpenSearch,
                                              icon: const Icon(Icons.search),
                                            ),
                                          if (data.searching)
                                            TextButton(
                                              onPressed: onCloseSearch,
                                              child: Text(
                                                context
                                                    .t
                                                    .strings
                                                    .legacy
                                                    .msg_cancel_2,
                                                style: TextStyle(
                                                  color:
                                                      MemoFlowPalette.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                bottom:
                                    useWindowsDesktopHeader && !data.searching
                                    ? null
                                    : data.searching
                                    ? (data.viewState.query.useShortcutFilter
                                          ? null
                                          : PreferredSize(
                                              preferredSize:
                                                  const Size.fromHeight(46),
                                              child: Align(
                                                alignment: Alignment.bottomLeft,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
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
                                                    onSelectKind:
                                                        onToggleQuickSearchKind,
                                                  ),
                                                ),
                                              ),
                                            ))
                                    : (showHeaderPillActionsInScroll &&
                                              quickActions.isNotEmpty
                                          ? PreferredSize(
                                              preferredSize:
                                                  const Size.fromHeight(46),
                                              child: Align(
                                                alignment: Alignment.bottomLeft,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        16,
                                                        0,
                                                        16,
                                                        0,
                                                      ),
                                                  child: MemosListPillRow(
                                                    quickActions: quickActions,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : (data.showFilterTagChip &&
                                                    resolvedTagChip != null
                                                ? PreferredSize(
                                                    preferredSize:
                                                        const Size.fromHeight(
                                                          48,
                                                        ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            16,
                                                            0,
                                                            16,
                                                            10,
                                                          ),
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerLeft,
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
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      10,
                                      16,
                                      0,
                                    ),
                                    child: SceneMicroGuideBanner(
                                      message: data.activeListGuideMessage!,
                                      onDismiss: onDismissGuide,
                                    ),
                                  ),
                                ),
                              if (!desktopPrimaryContentOverridden &&
                                  inlineComposeChild != null)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: inlineComposePadding,
                                    child: inlineComposeChild!,
                                  ),
                                ),
                              if (!desktopPrimaryContentOverridden &&
                                  tagFilterBarChild != null &&
                                  data.viewState.recommendedTags.isNotEmpty &&
                                  !data.searching)
                                SliverToBoxAdapter(child: tagFilterBarChild),
                              if (!desktopPrimaryContentOverridden &&
                                  advancedFilterSliver != null)
                                advancedFilterSliver!,
                              if (data.memosLoading &&
                                  data.visibleMemos.isNotEmpty)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                                ),
                              if (statusChild != null)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AnimatedSwitcher(
                                    duration: statusTransitionDuration,
                                    switchInCurve: AppMotion.standardCurve,
                                    switchOutCurve: AppMotion.exitCurve,
                                    transitionBuilder: (child, animation) {
                                      if (statusTransitionDuration ==
                                          Duration.zero) {
                                        return child;
                                      }
                                      final curved = CurvedAnimation(
                                        parent: animation,
                                        curve: AppMotion.standardCurve,
                                        reverseCurve: AppMotion.exitCurve,
                                      );
                                      return FadeTransition(
                                        opacity: curved,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin:
                                                AppMotion.verticalEntryOffset,
                                            end: Offset.zero,
                                          ).animate(curved),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: KeyedSubtree(
                                      key: ValueKey<String>(statusKey!),
                                      child: statusChild,
                                    ),
                                  ),
                                )
                              else if (data.viewState.query.showSearchLanding)
                                SliverToBoxAdapter(child: searchLandingChild)
                              else ...[
                                if (data.viewState.query.useAiSearch &&
                                    data.visibleMemos.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildAiResultsLabel(context),
                                  ),
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
                                if (data.viewState.query.canOfferAiSearch &&
                                    data.visibleMemos.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildAiSearchBottomAction(context),
                                  ),
                              ],
                              if (data.showLoadMoreHint)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      140,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 420,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            data.loadMoreHintDisplayText,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.2,
                                                  color: data
                                                      .loadMoreHintTextColor,
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
                    Positioned(
                      left: _memoListFloatingActionHorizontalInset,
                      right: _memoListFloatingActionHorizontalInset,
                      bottom:
                          data.viewState.layout.backToTopBaseOffset +
                          data.bottomInset,
                      child: ValueListenableBuilder<MemosListFloatingCollapseState>(
                        valueListenable: floatingCollapseListenable,
                        builder: (context, floatingCollapseState, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: showBackToTopListenable,
                            builder: (context, showBackToTop, _) {
                              return _MemoListFloatingActionSideSpringTransition(
                                side: floatingActionSide,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      floatingActionSide.crossAxisAlignment,
                                  children: [
                                    MemoFloatingCollapseButton(
                                      visible: floatingCollapseState.visible,
                                      scrolling:
                                          floatingCollapseState.scrolling,
                                      label:
                                          context.t.strings.legacy.msg_collapse,
                                      onPressed: onCollapseFloatingMemo,
                                    ),
                                    const SizedBox(
                                      height: _memoListFloatingActionGap,
                                    ),
                                    BackToTopButton(
                                      visible: showBackToTop,
                                      hapticsEnabled: data.hapticsEnabled,
                                      onPressed: onScrollToTop,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (bootstrapOverlayChild != null)
                      Positioned.fill(child: bootstrapOverlayChild!),
                  ],
                ),
              ),
            );
          },
        );

    final desktopPresentation = data.viewState.layout.desktopPresentation;
    final isWindowsDesktop = desktopPresentation.usesWindowsDesktopHeader;
    final isMacosDesktop = desktopPresentation.usesMacosDesktopTitleBar;
    final showDesktopPreview =
        !desktopPrimaryContentOverridden &&
        data.viewState.layout.supportsDesktopPreviewPane &&
        data.desktopPreviewVisible &&
        desktopPreviewPane != null;
    final desktopBodyContent = Padding(
      padding: expandDesktopBodyWidth
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: expandDesktopBodyWidth
            ? memoListBody
            : ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kMemoFlowDesktopContentMaxWidth,
                ),
                child: memoListBody,
              ),
      ),
    );

    final bodyContent = () {
      if (!data.viewState.layout.useDesktopSidePane || drawerPanel == null) {
        return memoListBody;
      }
      return MemosListDesktopSplitLayout(
        drawerPanel: drawerPanel!,
        body: desktopBodyContent,
        previewPane: desktopPreviewPane,
        previewVisible: showDesktopPreview,
        previewPaneWidth: kMemoFlowDesktopPreviewPaneWidth,
      );
    }();

    final macosNavigationMode = data.viewState.layout.useDesktopSidePane
        ? DesktopTitlebarNavigationMode.expandedSidebar
        : desktopDrawerPanelBuilder != null
        ? DesktopTitlebarNavigationMode.rail
        : DesktopTitlebarNavigationMode.hidden;
    final macosNavigationContext = resolveDesktopTitlebarNavigationContext(
      context,
    );

    if ((isWindowsDesktop || isMacosDesktop) &&
        desktopDrawerPanelBuilder != null) {
      final macosCommandBar = isMacosDesktop
          ? MemosListMacosDesktopTitleBar(
              isDark: isDark,
              searching: data.searching,
              showPillActions:
                  data.viewState.layout.showHeaderPillActions &&
                  !desktopPrimaryContentOverridden,
              enableHomeSort:
                  data.viewState.query.enableHomeSort &&
                  !desktopPrimaryContentOverridden,
              enableSearch:
                  data.enableSearch && !desktopPrimaryContentOverridden,
              showLeadingTitle: shouldRenderDesktopTitlebarLeadingTitle(
                platform: TargetPlatform.macOS,
                navigationMode: macosNavigationMode,
                navigationContext: macosNavigationContext,
              ),
              showDivider: shouldRenderDesktopTopLevelToolbarDivider(
                platform: TargetPlatform.macOS,
                navigationMode: macosNavigationMode,
                navigationContext: macosNavigationContext,
              ),
              titleChild: data.enableTitleMenu
                  ? titleChild
                  : IgnorePointer(child: titleChild),
              searchFieldChild: desktopPrimaryContentOverridden
                  ? const SizedBox.shrink()
                  : searchFieldChild,
              sortButton: desktopPrimaryContentOverridden ? null : sortButton,
              quickActions: desktopPrimaryContentOverridden
                  ? const <HomeQuickActionChipData>[]
                  : quickActions,
              onOpenSearch: onOpenSearch,
              onCloseSearch: onCloseSearch,
              searchTooltip: context.t.strings.legacy.msg_search,
              cancelTooltip: context.t.strings.legacy.msg_cancel_2,
            )
          : null;
      return DesktopShellHost(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        navigationBuilder: desktopDrawerPanelBuilder!,
        leadingTitle: data.enableTitleMenu
            ? titleChild
            : IgnorePointer(child: titleChild),
        commandBar: macosCommandBar,
        center: isMacosDesktop || desktopPrimaryContentOverridden
            ? null
            : searchFieldChild,
        trailing: isMacosDesktop
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: desktopTrailingActions,
              ),
        body: desktopBodyContent,
        secondaryPane: desktopPreviewPane,
        secondaryPaneVisible: showDesktopPreview,
        secondaryPaneWidth: desktopPreviewPaneWidth,
        secondaryPaneMotionSpec: _desktopMemoPreviewPaneMotionSpec,
        onSecondaryPaneWidthChanged: onDesktopPreviewPaneWidthChanged,
        modalSurface: desktopEditorModalSurface,
        modalSurfaceVisible: desktopEditorModalVisible,
      );
    }

    final drawerOpenDragEnabled =
        data.enableDrawerOpenDragGesture &&
        !data.viewState.layout.useDesktopSidePane &&
        !data.searching;
    final scaffoldBody = useWindowsDesktopHeader && !data.searching
        ? Column(
            children: [
              MemosListWindowsDesktopTitleBar(
                isDark: isDark,
                showPillActions:
                    data.viewState.layout.showHeaderPillActions &&
                    !desktopPrimaryContentOverridden,
                windowsHeaderSearchExpanded: data.desktopHeaderSearchExpanded,
                enableHomeSort:
                    data.viewState.query.enableHomeSort &&
                    !desktopPrimaryContentOverridden,
                enableSearch:
                    data.enableSearch && !desktopPrimaryContentOverridden,
                screenshotModeEnabled: data.screenshotModeEnabled,
                desktopWindowMaximized: data.desktopWindowMaximized,
                debugApiVersionText: data.debugApiVersionText,
                titleChild: data.enableTitleMenu
                    ? titleChild
                    : IgnorePointer(child: titleChild),
                searchFieldChild: desktopPrimaryContentOverridden
                    ? const SizedBox.shrink()
                    : searchFieldChild,
                sortButton: desktopPrimaryContentOverridden ? null : sortButton,
                onToggleSearch: onToggleDesktopHeaderSearch,
                quickActions: desktopPrimaryContentOverridden
                    ? const <HomeQuickActionChipData>[]
                    : quickActions,
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
        : useMacosDesktopTitleBar
        ? Column(
            children: [
              MemosListMacosDesktopTitleBar(
                isDark: isDark,
                searching: data.searching,
                showPillActions:
                    data.viewState.layout.showHeaderPillActions &&
                    !desktopPrimaryContentOverridden,
                enableHomeSort:
                    data.viewState.query.enableHomeSort &&
                    !desktopPrimaryContentOverridden,
                enableSearch:
                    data.enableSearch && !desktopPrimaryContentOverridden,
                showLeadingTitle: shouldRenderDesktopTitlebarLeadingTitle(
                  platform: TargetPlatform.macOS,
                  navigationMode: macosNavigationMode,
                  navigationContext: macosNavigationContext,
                ),
                showDivider: shouldRenderDesktopTopLevelToolbarDivider(
                  platform: TargetPlatform.macOS,
                  navigationMode: macosNavigationMode,
                  navigationContext: macosNavigationContext,
                ),
                titleChild: data.enableTitleMenu
                    ? titleChild
                    : IgnorePointer(child: titleChild),
                searchFieldChild: desktopPrimaryContentOverridden
                    ? const SizedBox.shrink()
                    : searchFieldChild,
                navigationButton:
                    drawerPanel != null &&
                        !data.viewState.layout.useDesktopSidePane &&
                        !data.searching
                    ? AppDrawerMenuButton(
                        tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                        iconColor:
                            Theme.of(context).appBarTheme.iconTheme?.color ??
                            IconTheme.of(context).color ??
                            Theme.of(context).colorScheme.onSurface,
                        badgeBorderColor: data.headerBackgroundColor,
                      )
                    : null,
                sortButton: desktopPrimaryContentOverridden ? null : sortButton,
                quickActions: desktopPrimaryContentOverridden
                    ? const <HomeQuickActionChipData>[]
                    : quickActions,
                onOpenSearch: onOpenSearch,
                onCloseSearch: onCloseSearch,
                searchTooltip: context.t.strings.legacy.msg_search,
                cancelTooltip: context.t.strings.legacy.msg_cancel_2,
              ),
              Expanded(child: bodyContent),
            ],
          )
        : bodyContent;

    return Scaffold(
      key: scaffoldKey,
      drawer: data.viewState.layout.useDesktopSidePane ? null : drawerPanel,
      drawerEnableOpenDragGesture: drawerOpenDragEnabled,
      drawerEdgeDragWidth: drawerOpenDragEnabled
          ? MediaQuery.sizeOf(context).width
          : null,
      body: _MemoListResponsiveDrawerOpenDrag(
        enabled:
            drawerOpenDragEnabled &&
            drawerPanel != null &&
            _usesNativeMobilePlatform(context),
        scaffoldKey: scaffoldKey,
        child: scaffoldBody,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: desktopPrimaryContentOverridden
          ? null
          : floatingActionButton,
    );
  }

  Widget _buildLoadingStatus(BuildContext context, bool aiSearchActive) {
    if (!aiSearchActive) {
      return const Center(child: CircularProgressIndicator());
    }
    final legacy = context.t.strings.legacy;
    return _buildStatusCard(
      context,
      icon: Icons.auto_awesome_outlined,
      title: legacy.msg_ai_search_loading_title,
      message: legacy.msg_ai_search_loading_message,
      action: const CircularProgressIndicator(),
    );
  }

  Widget _buildErrorStatus(
    BuildContext context,
    Object error,
    bool aiSearchActive,
  ) {
    if (!aiSearchActive) {
      return Center(
        child: Text(
          context.t.strings.legacy.msg_failed_load_3(memosError: error),
        ),
      );
    }
    final needsConfig = error is AiSemanticMemoSearchConfigurationException;
    final legacy = context.t.strings.legacy;
    return _buildStatusCard(
      context,
      icon: needsConfig ? Icons.tune_outlined : Icons.error_outline,
      title: needsConfig
          ? legacy.msg_ai_search_needs_embedding_model
          : legacy.msg_ai_search_failed,
      message: needsConfig
          ? legacy.msg_ai_search_configure_embedding_model
          : error.toString(),
      action: OutlinedButton.icon(
        onPressed: onStopAiSearch,
        icon: const Icon(Icons.search, size: 18),
        label: Text(legacy.msg_ai_search_back_to_keyword_search),
      ),
    );
  }

  Widget _buildEmptyStatus(
    BuildContext context,
    MemosListScreenBodyData bodyData,
  ) {
    final query = bodyData.viewState.query;
    final legacy = context.t.strings.legacy;
    if (query.useAiSearch) {
      return _buildStatusCard(
        context,
        icon: Icons.auto_awesome_outlined,
        title: legacy.msg_ai_search_no_matches,
        message: legacy.msg_ai_search_keyword_available,
        action: OutlinedButton.icon(
          onPressed: onStopAiSearch,
          icon: const Icon(Icons.search, size: 18),
          label: Text(legacy.msg_ai_search_back_to_keyword_search),
        ),
      );
    }
    if (query.canOfferAiSearch) {
      return _buildStatusCard(
        context,
        icon: Icons.search_off_outlined,
        title: legacy.msg_no_results_found,
        message: legacy.msg_ai_search_try_related_memos,
        action: FilledButton.icon(
          onPressed: onStartAiSearch,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(legacy.msg_ai_search_use_ai_search),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 140),
      child: Center(
        child: Text(
          bodyData.searching
              ? context.t.strings.legacy.msg_no_results_found
              : context.t.strings.legacy.msg_no_content_yet,
        ),
      ),
    );
  }

  Widget _buildAiResultsLabel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t.strings.legacy.msg_ai_search_results_label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onStopAiSearch,
                child: Text(context.t.strings.legacy.msg_ai_search_keyword),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiSearchBottomAction(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onStartAiSearch,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(
            context.t.strings.legacy.msg_ai_search_use_for_related_memos,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 116, left: 24, right: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: colorScheme.primary),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
