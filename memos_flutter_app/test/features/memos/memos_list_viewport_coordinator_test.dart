import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/memos_list_viewport_coordinator.dart';

void main() {
  test('syncQueryKey resets pagination state', () {
    final coordinator = MemosListViewportCoordinator(
      initialPageSize: 200,
      pageStep: 100,
    );
    addTearDown(coordinator.dispose);
    coordinator.updateSnapshot(
      hasProviderValue: true,
      resultCount: 200,
      providerLoading: false,
      showSearchLanding: false,
    );

    final triggerEffect = coordinator.handleDesktopWheel(
      deltaY: 24,
      touchPullEnabled: false,
      metrics: _metrics(pixels: 990, maxScrollExtent: 1000, viewport: 200),
    );

    expect(triggerEffect.kind, MemosListViewportLoadMoreEffectKind.triggered);
    expect(coordinator.pageSize, 300);
    expect(coordinator.loadingMore, isTrue);
    expect(coordinator.activeLoadMoreRequestId, isNotNull);

    final changed = coordinator.syncQueryKey(
      'query|state',
      previousVisibleCount: 200,
    );

    expect(changed, isTrue);
    expect(coordinator.paginationKey, 'query|state');
    expect(coordinator.pageSize, 200);
    expect(coordinator.loadingMore, isFalse);
    expect(coordinator.reachedEnd, isFalse);
    expect(coordinator.activeLoadMoreRequestId, isNull);
    expect(coordinator.activeLoadMoreSource, isNull);
    expect(coordinator.mobileBottomPullDistance, 0);
    expect(coordinator.mobileBottomPullArmed, isFalse);
  });

  test('handleScroll toggles back-to-top and throttles jump detection', () {
    var now = DateTime(2025, 1, 1, 0, 0, 0);
    final coordinator = MemosListViewportCoordinator(
      initialPageSize: 200,
      pageStep: 100,
      now: () => now,
    );
    addTearDown(coordinator.dispose);

    coordinator.handleScroll(
      _metrics(pixels: 450, maxScrollExtent: 1000, viewport: 200),
    );
    expect(coordinator.showBackToTop, isTrue);

    now = now.add(const Duration(milliseconds: 100));
    final jumpEffect = coordinator.handleScroll(
      _metrics(pixels: 0, maxScrollExtent: 1000, viewport: 200),
    );
    expect(jumpEffect.jumpedToTopUnexpectedly, isTrue);
    expect(jumpEffect.previousOffset, 450);
    expect(coordinator.showBackToTop, isFalse);

    now = now.add(const Duration(milliseconds: 100));
    coordinator.handleScroll(
      _metrics(pixels: 450, maxScrollExtent: 1000, viewport: 200),
    );
    now = now.add(const Duration(milliseconds: 100));
    final throttledEffect = coordinator.handleScroll(
      _metrics(pixels: 0, maxScrollExtent: 1000, viewport: 200),
    );
    expect(throttledEffect.jumpedToTopUnexpectedly, isFalse);
  });

  test('mobile pull overscroll arms and triggers load more on release', () {
    final coordinator = MemosListViewportCoordinator(
      initialPageSize: 200,
      pageStep: 100,
    );
    addTearDown(coordinator.dispose);
    coordinator.updateSnapshot(
      hasProviderValue: true,
      resultCount: 200,
      providerLoading: false,
      showSearchLanding: false,
    );

    coordinator.handleLoadMoreScrollEvent(
      _event(
        MemosListViewportScrollEventKind.overscroll,
        metrics: _metrics(pixels: 1000, maxScrollExtent: 1000, viewport: 200),
        hasDragDetails: true,
        overscroll: 36,
      ),
      touchPullEnabled: true,
    );
    coordinator.handleLoadMoreScrollEvent(
      _event(
        MemosListViewportScrollEventKind.overscroll,
        metrics: _metrics(pixels: 1000, maxScrollExtent: 1000, viewport: 200),
        hasDragDetails: true,
        overscroll: 40,
      ),
      touchPullEnabled: true,
    );

    expect(coordinator.mobileBottomPullArmed, isTrue);
    final effect = coordinator.handleLoadMoreScrollEvent(
      _event(
        MemosListViewportScrollEventKind.end,
        metrics: _metrics(pixels: 1000, maxScrollExtent: 1000, viewport: 200),
      ),
      touchPullEnabled: true,
    );

    expect(effect.kind, MemosListViewportLoadMoreEffectKind.triggered);
    expect(effect.source, 'mobile_pull_release');
    expect(coordinator.loadingMore, isTrue);
    expect(coordinator.mobileBottomPullDistance, 0);
    expect(coordinator.mobileBottomPullArmed, isFalse);
  });

  test('mobile pull release returns skipped when load more is blocked', () {
    final coordinator = MemosListViewportCoordinator(
      initialPageSize: 200,
      pageStep: 100,
    );
    addTearDown(coordinator.dispose);
    coordinator.updateSnapshot(
      hasProviderValue: true,
      resultCount: 200,
      providerLoading: false,
      showSearchLanding: false,
    );

    coordinator.handleLoadMoreScrollEvent(
      _event(
        MemosListViewportScrollEventKind.overscroll,
        metrics: _metrics(pixels: 1000, maxScrollExtent: 1000, viewport: 200),
        hasDragDetails: true,
        overscroll: 80,
      ),
      touchPullEnabled: true,
    );
    coordinator.updateSnapshot(
      hasProviderValue: true,
      resultCount: 200,
      providerLoading: false,
      showSearchLanding: true,
    );

    final effect = coordinator.handleLoadMoreScrollEvent(
      _event(
        MemosListViewportScrollEventKind.end,
        metrics: _metrics(pixels: 1000, maxScrollExtent: 1000, viewport: 200),
      ),
      touchPullEnabled: true,
    );

    expect(effect.kind, MemosListViewportLoadMoreEffectKind.skipped);
    expect(effect.skipReason, 'search_landing');
    expect(coordinator.loadingMore, isFalse);
  });

  test(
    'desktop wheel triggers near bottom and debounces repeated requests',
    () {
      var now = DateTime(2025, 1, 1, 0, 0, 0);
      final coordinator = MemosListViewportCoordinator(
        initialPageSize: 200,
        pageStep: 100,
        now: () => now,
      );
      addTearDown(coordinator.dispose);
      coordinator.updateSnapshot(
        hasProviderValue: true,
        resultCount: 200,
        providerLoading: false,
        showSearchLanding: false,
      );

      final upwardEffect = coordinator.handleDesktopWheel(
        deltaY: -8,
        touchPullEnabled: false,
        metrics: _metrics(pixels: 990, maxScrollExtent: 1000, viewport: 200),
      );
      expect(upwardEffect.kind, MemosListViewportLoadMoreEffectKind.none);

      final firstEffect = coordinator.handleDesktopWheel(
        deltaY: 18,
        touchPullEnabled: false,
        metrics: _metrics(pixels: 990, maxScrollExtent: 1000, viewport: 200),
      );
      final secondEffect = coordinator.handleDesktopWheel(
        deltaY: 18,
        touchPullEnabled: false,
        metrics: _metrics(pixels: 990, maxScrollExtent: 1000, viewport: 200),
      );

      expect(firstEffect.kind, MemosListViewportLoadMoreEffectKind.triggered);
      expect(secondEffect.kind, MemosListViewportLoadMoreEffectKind.skipped);
      expect(secondEffect.skipReason, 'debounced');
      now = now.add(const Duration(milliseconds: 300));
    },
  );

  test(
    'page navigation shortcut respects focus and only down near bottom loads more',
    () {
      final coordinator = MemosListViewportCoordinator(
        initialPageSize: 200,
        pageStep: 100,
      );
      addTearDown(coordinator.dispose);
      coordinator.updateSnapshot(
        hasProviderValue: true,
        resultCount: 200,
        providerLoading: false,
        showSearchLanding: false,
      );
      final adapter = _FakeScrollAdapter(
        metricsValue: _metrics(
          pixels: 100,
          maxScrollExtent: 1000,
          viewport: 400,
        ),
      );

      final focusedEffect = coordinator.handlePageNavigationShortcut(
        down: true,
        searchFocused: true,
        source: 'shortcut_next_page',
        scrollAdapter: adapter,
      );
      expect(focusedEffect.kind, MemosListViewportLoadMoreEffectKind.none);
      expect(adapter.animateTargets, isEmpty);

      final upEffect = coordinator.handlePageNavigationShortcut(
        down: false,
        searchFocused: false,
        source: 'shortcut_previous_page',
        scrollAdapter: adapter,
      );
      expect(upEffect.kind, MemosListViewportLoadMoreEffectKind.none);
      expect(adapter.animateTargets.single, 0);

      adapter.metricsValue = _metrics(
        pixels: 900,
        maxScrollExtent: 1000,
        viewport: 400,
      );
      final downEffect = coordinator.handlePageNavigationShortcut(
        down: true,
        searchFocused: false,
        source: 'shortcut_next_page',
        scrollAdapter: adapter,
      );

      expect(downEffect.kind, MemosListViewportLoadMoreEffectKind.triggered);
      expect(downEffect.source, 'shortcut_next_page_near_bottom');
      expect(adapter.animateTargets.last, 1000);
    },
  );

  test('floating collapse scrolling state follows scroll events', () {
    final coordinator = MemosListViewportCoordinator(
      initialPageSize: 200,
      pageStep: 100,
    );
    addTearDown(coordinator.dispose);
    final metrics = _metrics(pixels: 120, maxScrollExtent: 1000, viewport: 300);

    coordinator.handleFloatingCollapseScrollEvent(
      _event(MemosListViewportScrollEventKind.start, metrics: metrics),
    );
    expect(coordinator.floatingCollapseScrolling, isTrue);

    coordinator.handleFloatingCollapseScrollEvent(
      _event(
        MemosListViewportScrollEventKind.user,
        metrics: metrics,
        userDirection: ScrollDirection.idle,
      ),
    );
    expect(coordinator.floatingCollapseScrolling, isFalse);

    coordinator.handleFloatingCollapseScrollEvent(
      _event(MemosListViewportScrollEventKind.update, metrics: metrics),
    );
    expect(coordinator.floatingCollapseScrolling, isTrue);

    coordinator.handleFloatingCollapseScrollEvent(
      _event(MemosListViewportScrollEventKind.end, metrics: metrics),
    );
    expect(coordinator.floatingCollapseScrolling, isFalse);
  });

  test(
    'floating collapse recompute is debounced to one post-frame callback',
    () {
      final coordinator = MemosListViewportCoordinator(
        initialPageSize: 200,
        pageStep: 100,
      );
      addTearDown(coordinator.dispose);
      final callbacks = <VoidCallback>[];
      var scheduleCount = 0;

      final first = coordinator.requestFloatingCollapseRecompute(
        schedulePostFrame: (callback) {
          scheduleCount++;
          callbacks.add(callback);
        },
        resolveMemoUid: () => 'memo-1',
      );
      final second = coordinator.requestFloatingCollapseRecompute(
        schedulePostFrame: (callback) {
          scheduleCount++;
          callbacks.add(callback);
        },
        resolveMemoUid: () => 'memo-2',
      );

      expect(first, isTrue);
      expect(second, isFalse);
      expect(scheduleCount, 1);
      expect(coordinator.floatingCollapseMemoUid, isNull);

      callbacks.single();

      expect(coordinator.floatingCollapseMemoUid, 'memo-1');
    },
  );

  test('scrollToTop animates by timer-driven jumps until top', () {
    fakeAsync((async) {
      final coordinator = MemosListViewportCoordinator(
        initialPageSize: 200,
        pageStep: 100,
        periodicTimerFactory: (duration, callback) =>
            Timer.periodic(duration, callback),
      );
      final adapter = _FakeScrollAdapter(
        metricsValue: _metrics(
          pixels: 800,
          maxScrollExtent: 1000,
          viewport: 300,
        ),
      );

      coordinator.scrollToTop(adapter);
      expect(coordinator.scrollToTopAnimating, isTrue);

      async.elapse(const Duration(seconds: 1));

      expect(adapter.jumpTargets, isNotEmpty);
      expect(adapter.metricsValue.pixels, 0);
      expect(coordinator.scrollToTopAnimating, isFalse);
      coordinator.dispose();
    });
  });

  test('dispose stops active scroll-to-top timer', () {
    fakeAsync((async) {
      final coordinator = MemosListViewportCoordinator(
        initialPageSize: 200,
        pageStep: 100,
        periodicTimerFactory: (duration, callback) =>
            Timer.periodic(duration, callback),
      );
      final adapter = _FakeScrollAdapter(
        metricsValue: _metrics(
          pixels: 800,
          maxScrollExtent: 1000,
          viewport: 300,
        ),
      );

      coordinator.scrollToTop(adapter);
      coordinator.dispose();
      final jumpCountBefore = adapter.jumpTargets.length;

      async.elapse(const Duration(seconds: 1));

      expect(adapter.jumpTargets.length, jumpCountBefore);
    });
  });
}

MemosListViewportMetrics _metrics({
  required double pixels,
  required double maxScrollExtent,
  required double viewport,
  Axis axis = Axis.vertical,
}) {
  return MemosListViewportMetrics(
    pixels: pixels,
    maxScrollExtent: maxScrollExtent,
    viewportDimension: viewport,
    axis: axis,
  );
}

MemosListViewportScrollEvent _event(
  MemosListViewportScrollEventKind kind, {
  required MemosListViewportMetrics metrics,
  bool hasDragDetails = false,
  double overscroll = 0,
  ScrollDirection? userDirection,
}) {
  return MemosListViewportScrollEvent(
    kind: kind,
    metrics: metrics,
    hasDragDetails: hasDragDetails,
    overscroll: overscroll,
    userDirection: userDirection,
  );
}

class _FakeScrollAdapter implements MemosListViewportScrollAdapter {
  _FakeScrollAdapter({required this.metricsValue});

  bool hasClientsValue = true;
  MemosListViewportMetrics metricsValue;
  final List<double> animateTargets = <double>[];
  final List<double> jumpTargets = <double>[];

  @override
  bool get hasClients => hasClientsValue;

  @override
  MemosListViewportMetrics get metrics => metricsValue;

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) async {
    animateTargets.add(offset);
    metricsValue = _metrics(
      pixels: offset,
      maxScrollExtent: metricsValue.maxScrollExtent,
      viewport: metricsValue.viewportDimension,
      axis: metricsValue.axis,
    );
  }

  @override
  void jumpTo(double offset) {
    jumpTargets.add(offset);
    metricsValue = _metrics(
      pixels: offset,
      maxScrollExtent: metricsValue.maxScrollExtent,
      viewport: metricsValue.viewportDimension,
      axis: metricsValue.axis,
    );
  }
}
