import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Axis;

import 'memos_list_viewport_coordinator.dart';
import 'widgets/floating_collapse_button.dart';

@immutable
class MemoFloatingCollapseGeometry {
  const MemoFloatingCollapseGeometry({
    required this.cardTopOffset,
    required this.cardBottomOffset,
    required this.toggleTopOffset,
    required this.toggleBottomOffset,
  });

  final double cardTopOffset;
  final double cardBottomOffset;
  final double toggleTopOffset;
  final double toggleBottomOffset;

  bool isCloseTo(MemoFloatingCollapseGeometry other, {double tolerance = 0.5}) {
    return (cardTopOffset - other.cardTopOffset).abs() <= tolerance &&
        (cardBottomOffset - other.cardBottomOffset).abs() <= tolerance &&
        (toggleTopOffset - other.toggleTopOffset).abs() <= tolerance &&
        (toggleBottomOffset - other.toggleBottomOffset).abs() <= tolerance;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoFloatingCollapseGeometry &&
        other.cardTopOffset == cardTopOffset &&
        other.cardBottomOffset == cardBottomOffset &&
        other.toggleTopOffset == toggleTopOffset &&
        other.toggleBottomOffset == toggleBottomOffset;
  }

  @override
  int get hashCode => Object.hash(
    cardTopOffset,
    cardBottomOffset,
    toggleTopOffset,
    toggleBottomOffset,
  );
}

@immutable
class MemosListFloatingCollapseState {
  const MemosListFloatingCollapseState({
    required this.memoUid,
    required this.scrolling,
  });

  final String? memoUid;
  final bool scrolling;

  bool get visible => memoUid != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemosListFloatingCollapseState &&
        other.memoUid == memoUid &&
        other.scrolling == scrolling;
  }

  @override
  int get hashCode => Object.hash(memoUid, scrolling);
}

class MemosListFloatingCollapseController
    extends ValueNotifier<MemosListFloatingCollapseState> {
  MemosListFloatingCollapseController()
    : super(
        const MemosListFloatingCollapseState(memoUid: null, scrolling: false),
      );

  final LinkedHashMap<String, MemoFloatingCollapseGeometry> _geometriesByUid =
      LinkedHashMap<String, MemoFloatingCollapseGeometry>();

  MemosListViewportMetrics? _lastMetrics;
  MemosListFloatingCollapseState? _pendingValue;
  bool _pendingValueFlushScheduled = false;
  bool _disposed = false;

  void updateViewportMetrics(MemosListViewportMetrics metrics) {
    _lastMetrics = metrics;
    _updateMemoUid(_resolveMemoUid(metrics));
  }

  void handleScrollEvent(MemosListViewportScrollEvent event) {
    if (event.metrics.axis != Axis.vertical) return;

    final nextScrolling = switch (event.kind) {
      MemosListViewportScrollEventKind.start ||
      MemosListViewportScrollEventKind.update ||
      MemosListViewportScrollEventKind.overscroll => true,
      MemosListViewportScrollEventKind.user =>
        event.userDirection != ScrollDirection.idle,
      MemosListViewportScrollEventKind.end => false,
    };

    final current = _effectiveValue;
    if (nextScrolling == current.scrolling) return;
    _setValue(
      MemosListFloatingCollapseState(
        memoUid: current.memoUid,
        scrolling: nextScrolling,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingValue = null;
    super.dispose();
  }

  MemosListFloatingCollapseState get _effectiveValue => _pendingValue ?? value;

  void _setValue(MemosListFloatingCollapseState next) {
    if (_disposed) return;
    final current = _effectiveValue;
    if (next == current) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _pendingValue = next;
      _schedulePendingValueFlush();
      return;
    }
    _pendingValue = null;
    value = next;
  }

  void _schedulePendingValueFlush() {
    if (_pendingValueFlushScheduled) return;
    _pendingValueFlushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pendingValueFlushScheduled = false;
      if (_disposed) {
        _pendingValue = null;
        return;
      }
      final pending = _pendingValue;
      _pendingValue = null;
      if (pending == null || pending == value) return;
      value = pending;
    });
  }

  void upsertGeometry(String memoUid, MemoFloatingCollapseGeometry geometry) {
    final previous = _geometriesByUid[memoUid];
    if (previous == geometry) return;
    _geometriesByUid[memoUid] = geometry;
    _updateMemoUid(_resolveMemoUid(_lastMetrics));
  }

  void removeGeometry(String memoUid) {
    if (_geometriesByUid.remove(memoUid) == null) return;
    _updateMemoUid(_resolveMemoUid(_lastMetrics));
  }

  void pruneToVisibleMemoUids(Set<String> visibleUids) {
    var removed = false;
    final staleUids = _geometriesByUid.keys
        .where((memoUid) => !visibleUids.contains(memoUid))
        .toList(growable: false);
    for (final memoUid in staleUids) {
      removed = _geometriesByUid.remove(memoUid) != null || removed;
    }
    if (!removed) return;
    _updateMemoUid(_resolveMemoUid(_lastMetrics));
  }

  String? _resolveMemoUid(MemosListViewportMetrics? metrics) {
    if (metrics == null || metrics.axis != Axis.vertical) return null;
    if (_geometriesByUid.isEmpty) return null;

    final viewportTop = metrics.pixels;
    final viewportBottom = metrics.pixels + metrics.viewportDimension;
    _FloatingCollapseCandidate? nextCandidate;

    for (final entry in _geometriesByUid.entries) {
      final geometry = entry.value;
      final visibleHeight = math.max(
        0.0,
        math.min(geometry.cardBottomOffset, viewportBottom) -
            math.max(geometry.cardTopOffset, viewportTop),
      );
      if (visibleHeight <= 0) continue;
      if (!shouldShowFloatingCollapseForOffsets(
        viewportTop: viewportTop,
        viewportBottom: viewportBottom,
        toggleTop: geometry.toggleTopOffset,
        toggleBottom: geometry.toggleBottomOffset,
      )) {
        continue;
      }
      if (nextCandidate == null ||
          visibleHeight > nextCandidate.visibleHeight) {
        nextCandidate = _FloatingCollapseCandidate(
          memoUid: entry.key,
          visibleHeight: visibleHeight,
        );
      }
    }

    return nextCandidate?.memoUid;
  }

  void _updateMemoUid(String? memoUid) {
    final current = _effectiveValue;
    if (memoUid == current.memoUid) return;
    _setValue(
      MemosListFloatingCollapseState(
        memoUid: memoUid,
        scrolling: current.scrolling,
      ),
    );
  }
}

class _FloatingCollapseCandidate {
  const _FloatingCollapseCandidate({
    required this.memoUid,
    required this.visibleHeight,
  });

  final String memoUid;
  final double visibleHeight;
}
