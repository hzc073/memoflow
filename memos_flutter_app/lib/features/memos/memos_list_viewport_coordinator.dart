import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../state/memos/memos_list_load_more_controller.dart';

const double _mobilePullLoadThreshold = 64;
const Duration _desktopWheelLoadDebounce = Duration(milliseconds: 220);
const double _scrollToTopMinSpeedPxPerSecond = 2600;
const double _scrollToTopMaxSpeedPxPerSecond = 14000;
const double _scrollToTopDistanceSpeedFactor = 90;
const Duration _scrollToTopTick = Duration(milliseconds: 16);
const double _scrollToTopTickSeconds = 0.016;
const Duration _scrollJumpLogDebounce = Duration(milliseconds: 700);
const Duration _pageNavigationDuration = Duration(milliseconds: 180);

@immutable
class MemosListViewportMetrics {
  const MemosListViewportMetrics({
    required this.pixels,
    required this.maxScrollExtent,
    required this.viewportDimension,
    required this.axis,
  });

  final double pixels;
  final double maxScrollExtent;
  final double viewportDimension;
  final Axis axis;
}

enum MemosListViewportScrollEventKind { start, update, overscroll, end, user }

@immutable
class MemosListViewportScrollEvent {
  const MemosListViewportScrollEvent({
    required this.kind,
    required this.metrics,
    required this.hasDragDetails,
    required this.overscroll,
    required this.userDirection,
  });

  final MemosListViewportScrollEventKind kind;
  final MemosListViewportMetrics metrics;
  final bool hasDragDetails;
  final double overscroll;
  final ScrollDirection? userDirection;
}

@immutable
class MemosListViewportScrollEffect {
  const MemosListViewportScrollEffect({
    required this.jumpedToTopUnexpectedly,
    required this.previousOffset,
  });

  final bool jumpedToTopUnexpectedly;
  final double previousOffset;
}

enum MemosListViewportLoadMoreEffectKind { none, triggered, skipped }

@immutable
class MemosListViewportLoadMoreEffect {
  const MemosListViewportLoadMoreEffect({
    required this.kind,
    required this.source,
    this.skipReason,
    this.requestId,
    this.fromPageSize,
    this.toPageSize,
  });

  const MemosListViewportLoadMoreEffect.none()
    : kind = MemosListViewportLoadMoreEffectKind.none,
      source = '',
      skipReason = null,
      requestId = null,
      fromPageSize = null,
      toPageSize = null;

  const MemosListViewportLoadMoreEffect.triggered({
    required this.source,
    required this.requestId,
    required this.fromPageSize,
    required this.toPageSize,
  }) : kind = MemosListViewportLoadMoreEffectKind.triggered,
       skipReason = null;

  const MemosListViewportLoadMoreEffect.skipped({
    required this.source,
    required this.skipReason,
  }) : kind = MemosListViewportLoadMoreEffectKind.skipped,
       requestId = null,
       fromPageSize = null,
       toPageSize = null;

  final MemosListViewportLoadMoreEffectKind kind;
  final String source;
  final String? skipReason;
  final int? requestId;
  final int? fromPageSize;
  final int? toPageSize;
}

abstract interface class MemosListViewportScrollAdapter {
  bool get hasClients;
  MemosListViewportMetrics get metrics;
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  });
  void jumpTo(double offset);
}

class MemosListViewportCoordinator extends ChangeNotifier {
  MemosListViewportCoordinator({
    required int initialPageSize,
    required int pageStep,
    DateTime Function()? now,
    Timer Function(Duration, void Function(Timer))? periodicTimerFactory,
  }) : _loadMoreController = MemosListLoadMoreController(
         initialPageSize: initialPageSize,
         pageStep: pageStep,
       ),
       _now = now ?? DateTime.now,
       _periodicTimerFactory = periodicTimerFactory ?? Timer.periodic;

  final MemosListLoadMoreController _loadMoreController;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function(Timer)) _periodicTimerFactory;

  bool _showBackToTop = false;
  bool _floatingCollapseScrolling = false;
  bool _floatingCollapseRecomputeScheduled = false;
  String? _floatingCollapseMemoUid;
  bool _scrollToTopAnimating = false;
  Timer? _scrollToTopTimer;
  double _lastObservedScrollOffset = 0;
  DateTime? _lastScrollJumpLogAt;
  bool _disposed = false;

  int get pageSize => _loadMoreController.pageSize;
  bool get reachedEnd => _loadMoreController.reachedEnd;
  bool get loadingMore => _loadMoreController.loadingMore;
  String get paginationKey => _loadMoreController.paginationKey;
  int get lastResultCount => _loadMoreController.lastResultCount;
  int get currentResultCount => _loadMoreController.currentResultCount;
  bool get currentLoading => _loadMoreController.currentLoading;
  bool get currentShowSearchLanding =>
      _loadMoreController.currentShowSearchLanding;
  double get mobileBottomPullDistance =>
      _loadMoreController.mobileBottomPullDistance;
  bool get mobileBottomPullArmed => _loadMoreController.mobileBottomPullArmed;
  int? get activeLoadMoreRequestId =>
      _loadMoreController.activeLoadMoreRequestId;
  String? get activeLoadMoreSource => _loadMoreController.activeLoadMoreSource;
  bool get showBackToTop => _showBackToTop;
  bool get floatingCollapseScrolling => _floatingCollapseScrolling;
  String? get floatingCollapseMemoUid => _floatingCollapseMemoUid;
  bool get scrollToTopAnimating => _scrollToTopAnimating;

  bool syncQueryKey(String queryKey, {required int previousVisibleCount}) {
    return _loadMoreController.syncQueryKey(
      queryKey,
      previousVisibleCount: previousVisibleCount,
    );
  }

  void updateSnapshot({
    required bool hasProviderValue,
    required int resultCount,
    required bool providerLoading,
    required bool showSearchLanding,
  }) {
    _loadMoreController.updateSnapshot(
      hasProviderValue: hasProviderValue,
      resultCount: resultCount,
      providerLoading: providerLoading,
      showSearchLanding: showSearchLanding,
    );
  }

  MemosListViewportScrollEffect handleScroll(MemosListViewportMetrics metrics) {
    final previousOffset = _lastObservedScrollOffset;
    _lastObservedScrollOffset = metrics.pixels;

    var jumpedToTopUnexpectedly =
        previousOffset > (metrics.viewportDimension * 0.8) &&
        metrics.pixels <= 4 &&
        (previousOffset - metrics.pixels) > (metrics.viewportDimension * 0.8);
    if (jumpedToTopUnexpectedly) {
      final now = _now();
      final lastAt = _lastScrollJumpLogAt;
      if (lastAt == null || now.difference(lastAt) > _scrollJumpLogDebounce) {
        _lastScrollJumpLogAt = now;
      } else {
        jumpedToTopUnexpectedly = false;
      }
    }

    final nextShowBackToTop = metrics.pixels >= (metrics.viewportDimension * 2);
    if (nextShowBackToTop != _showBackToTop) {
      _showBackToTop = nextShowBackToTop;
      _notifyChanged();
    }

    return MemosListViewportScrollEffect(
      jumpedToTopUnexpectedly: jumpedToTopUnexpectedly,
      previousOffset: previousOffset,
    );
  }

  bool requestFloatingCollapseRecompute({
    required void Function(VoidCallback callback) schedulePostFrame,
    required String? Function() resolveMemoUid,
  }) {
    if (_disposed || _floatingCollapseRecomputeScheduled) return false;
    _floatingCollapseRecomputeScheduled = true;
    schedulePostFrame(() {
      _floatingCollapseRecomputeScheduled = false;
      if (_disposed) return;
      final nextMemoUid = resolveMemoUid();
      if (nextMemoUid == _floatingCollapseMemoUid) return;
      _floatingCollapseMemoUid = nextMemoUid;
      _notifyChanged();
    });
    return true;
  }

  void handleFloatingCollapseScrollEvent(MemosListViewportScrollEvent event) {
    if (event.metrics.axis != Axis.vertical) return;

    final nextValue = switch (event.kind) {
      MemosListViewportScrollEventKind.start ||
      MemosListViewportScrollEventKind.update ||
      MemosListViewportScrollEventKind.overscroll => true,
      MemosListViewportScrollEventKind.user =>
        event.userDirection != ScrollDirection.idle,
      MemosListViewportScrollEventKind.end => false,
    };
    if (nextValue == _floatingCollapseScrolling) return;
    _floatingCollapseScrolling = nextValue;
    _notifyChanged();
  }

  MemosListViewportLoadMoreEffect handleLoadMoreScrollEvent(
    MemosListViewportScrollEvent event, {
    required bool touchPullEnabled,
  }) {
    if (!touchPullEnabled) return const MemosListViewportLoadMoreEffect.none();
    if (event.metrics.axis != Axis.vertical) {
      return const MemosListViewportLoadMoreEffect.none();
    }
    if (_scrollToTopAnimating) {
      return const MemosListViewportLoadMoreEffect.none();
    }

    switch (event.kind) {
      case MemosListViewportScrollEventKind.update:
        final canArmPullLoad =
            !_loadMoreController.currentShowSearchLanding &&
            !_loadMoreController.currentLoading &&
            !_loadMoreController.loadingMore &&
            !_loadMoreController.reachedEnd;
        if (!canArmPullLoad) {
          _resetTouchPullIfNeeded();
          return const MemosListViewportLoadMoreEffect.none();
        }
        if (!event.hasDragDetails) {
          return const MemosListViewportLoadMoreEffect.none();
        }
        final nearBottom =
            event.metrics.pixels >= (event.metrics.maxScrollExtent - 1);
        if (!nearBottom) {
          _resetTouchPullIfNeeded();
        }
        return const MemosListViewportLoadMoreEffect.none();
      case MemosListViewportScrollEventKind.overscroll:
        final canArmPullLoad =
            !_loadMoreController.currentShowSearchLanding &&
            !_loadMoreController.currentLoading &&
            !_loadMoreController.loadingMore &&
            !_loadMoreController.reachedEnd;
        if (!canArmPullLoad) {
          _resetTouchPullIfNeeded();
          return const MemosListViewportLoadMoreEffect.none();
        }
        if (!event.hasDragDetails) {
          return const MemosListViewportLoadMoreEffect.none();
        }
        final atBottom =
            event.metrics.maxScrollExtent > 0 &&
            event.metrics.pixels >= (event.metrics.maxScrollExtent - 1);
        if (!atBottom || event.overscroll <= 0) {
          return const MemosListViewportLoadMoreEffect.none();
        }
        final previousDistance = mobileBottomPullDistance;
        final previousArmed = mobileBottomPullArmed;
        _loadMoreController.updateTouchPullDistance(
          previousDistance + event.overscroll,
          threshold: _mobilePullLoadThreshold,
        );
        if (previousDistance != mobileBottomPullDistance ||
            previousArmed != mobileBottomPullArmed) {
          _notifyChanged();
        }
        return const MemosListViewportLoadMoreEffect.none();
      case MemosListViewportScrollEventKind.end:
        final hadPullState =
            mobileBottomPullDistance > 0 || mobileBottomPullArmed;
        final armed = _loadMoreController.consumeTouchPullArm();
        if (hadPullState) {
          _notifyChanged();
        }
        if (!armed) {
          return const MemosListViewportLoadMoreEffect.none();
        }
        return _loadMoreFromActionWithSource('mobile_pull_release');
      case MemosListViewportScrollEventKind.start:
      case MemosListViewportScrollEventKind.user:
        return const MemosListViewportLoadMoreEffect.none();
    }
  }

  MemosListViewportLoadMoreEffect handleDesktopWheel({
    required double deltaY,
    required bool touchPullEnabled,
    required MemosListViewportMetrics? metrics,
  }) {
    if (touchPullEnabled || _scrollToTopAnimating || deltaY <= 0) {
      return const MemosListViewportLoadMoreEffect.none();
    }
    if (metrics == null || metrics.axis != Axis.vertical) {
      return const MemosListViewportLoadMoreEffect.none();
    }
    if (metrics.maxScrollExtent <= 0) {
      return const MemosListViewportLoadMoreEffect.none();
    }
    final nearBottom =
        metrics.pixels >=
        (metrics.maxScrollExtent - metrics.viewportDimension * 0.08);
    if (!nearBottom) {
      return const MemosListViewportLoadMoreEffect.none();
    }

    if (_loadMoreController.shouldThrottleDesktopWheel(
      _now(),
      _desktopWheelLoadDebounce,
    )) {
      return const MemosListViewportLoadMoreEffect.skipped(
        source: 'desktop_wheel',
        skipReason: 'debounced',
      );
    }
    return _loadMoreFromActionWithSource('desktop_wheel');
  }

  MemosListViewportLoadMoreEffect handlePageNavigationShortcut({
    required bool down,
    required bool searchFocused,
    required String source,
    required MemosListViewportScrollAdapter scrollAdapter,
  }) {
    if (searchFocused) return const MemosListViewportLoadMoreEffect.none();

    final metrics = scrollAdapter.hasClients ? scrollAdapter.metrics : null;
    if (metrics != null) {
      final step = metrics.viewportDimension * 0.9;
      final rawTarget = down ? metrics.pixels + step : metrics.pixels - step;
      final target = rawTarget.clamp(0.0, metrics.maxScrollExtent);
      if ((target - metrics.pixels).abs() >= 1) {
        unawaited(
          scrollAdapter.animateTo(
            target,
            duration: _pageNavigationDuration,
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }

    if (!down) {
      return const MemosListViewportLoadMoreEffect.none();
    }
    if (metrics == null) {
      return _loadMoreFromActionWithSource('${source}_no_clients');
    }
    final nearBottom =
        metrics.maxScrollExtent <= 0 ||
        metrics.pixels >=
            (metrics.maxScrollExtent - metrics.viewportDimension * 0.35);
    if (nearBottom) {
      return _loadMoreFromActionWithSource('${source}_near_bottom');
    }
    return const MemosListViewportLoadMoreEffect.none();
  }

  Future<void> scrollToTop(MemosListViewportScrollAdapter scrollAdapter) async {
    if (!scrollAdapter.hasClients || _scrollToTopAnimating) return;
    _setScrollToTopAnimating(true);
    _scrollToTopTimer?.cancel();
    _scrollToTopTimer = _periodicTimerFactory(_scrollToTopTick, (_) {
      if (_disposed || !scrollAdapter.hasClients) {
        _stopScrollToTopFlow(scrollAdapter);
        return;
      }
      final position = scrollAdapter.metrics;
      final current = position.pixels;
      if (current <= 0.5) {
        _stopScrollToTopFlow(scrollAdapter, snapToTop: true);
        return;
      }

      final speed = _scrollToTopSpeedForDistance(current);
      final delta = speed * _scrollToTopTickSeconds;
      final target = (current - delta).clamp(0.0, position.maxScrollExtent);
      if ((current - target).abs() < 0.001) return;
      try {
        scrollAdapter.jumpTo(target);
      } catch (_) {
        _stopScrollToTopFlow(scrollAdapter);
        return;
      }
      if (target <= 0.5) {
        _stopScrollToTopFlow(scrollAdapter, snapToTop: true);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollToTopTimer?.cancel();
    _scrollToTopTimer = null;
    super.dispose();
  }

  void _notifyChanged() {
    if (_disposed) return;
    notifyListeners();
  }

  void _resetTouchPullIfNeeded() {
    if (mobileBottomPullDistance == 0 && !mobileBottomPullArmed) return;
    _loadMoreController.resetTouchPull();
    _notifyChanged();
  }

  MemosListViewportLoadMoreEffect _loadMoreFromActionWithSource(String source) {
    if (_scrollToTopAnimating) {
      return MemosListViewportLoadMoreEffect.skipped(
        source: source,
        skipReason: 'scroll_to_top_animating',
      );
    }
    if (!_loadMoreController.canLoadMore()) {
      return MemosListViewportLoadMoreEffect.skipped(
        source: source,
        skipReason: _loadMoreController.describeBlockReason(),
      );
    }

    _loadMoreController.resetTouchPull();
    final previousPageSize = _loadMoreController.pageSize;
    final requestId = _loadMoreController.beginLoadMore(source: source);
    _notifyChanged();
    return MemosListViewportLoadMoreEffect.triggered(
      source: source,
      requestId: requestId,
      fromPageSize: previousPageSize,
      toPageSize: _loadMoreController.pageSize,
    );
  }

  void _setScrollToTopAnimating(bool value) {
    if (_scrollToTopAnimating == value) return;
    _scrollToTopAnimating = value;
    _notifyChanged();
  }

  void _stopScrollToTopFlow(
    MemosListViewportScrollAdapter scrollAdapter, {
    bool snapToTop = false,
  }) {
    _scrollToTopTimer?.cancel();
    _scrollToTopTimer = null;
    final wasAnimating = _scrollToTopAnimating;
    _scrollToTopAnimating = false;
    if (snapToTop && scrollAdapter.hasClients) {
      try {
        scrollAdapter.jumpTo(0);
      } catch (_) {}
    }
    if (wasAnimating) {
      _notifyChanged();
    }
  }

  double _scrollToTopSpeedForDistance(double distanceToTopPx) {
    final safeDistance = distanceToTopPx.isFinite
        ? math.max(0.0, distanceToTopPx)
        : 0.0;
    final speed =
        _scrollToTopMinSpeedPxPerSecond +
        math.sqrt(safeDistance) * _scrollToTopDistanceSpeedFactor;
    return math.min(speed, _scrollToTopMaxSpeedPxPerSecond);
  }
}
