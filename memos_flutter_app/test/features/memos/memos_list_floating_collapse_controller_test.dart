import 'package:flutter/rendering.dart' show RenderProxyBox, ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart'
    show
        Axis,
        BuildContext,
        SingleChildRenderObjectWidget,
        SizedBox,
        ValueListenableBuilder;
import 'package:memos_flutter_app/features/memos/memos_list_floating_collapse_controller.dart';
import 'package:memos_flutter_app/features/memos/memos_list_viewport_coordinator.dart';

void main() {
  test('updateViewportMetrics keeps button hidden without candidates', () {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);

    controller.updateViewportMetrics(
      _metrics(pixels: 0, maxScrollExtent: 2000, viewport: 400),
    );

    expect(controller.value.visible, isFalse);
    expect(controller.value.memoUid, isNull);
  });

  test('single candidate follows current viewport distance rules', () {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);
    controller.upsertGeometry(
      'memo-1',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 2000,
        toggleTopOffset: 350,
        toggleBottomOffset: 390,
      ),
    );

    controller.updateViewportMetrics(
      _metrics(pixels: 0, maxScrollExtent: 3000, viewport: 400),
    );
    expect(controller.value.memoUid, isNull);

    controller.upsertGeometry(
      'memo-1',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 2000,
        toggleTopOffset: -300,
        toggleBottomOffset: -260,
      ),
    );
    controller.updateViewportMetrics(
      _metrics(pixels: 0, maxScrollExtent: 3000, viewport: 400),
    );
    expect(controller.value.memoUid, isNull);

    controller.upsertGeometry(
      'memo-1',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 2000,
        toggleTopOffset: -500,
        toggleBottomOffset: -460,
      ),
    );
    controller.updateViewportMetrics(
      _metrics(pixels: 0, maxScrollExtent: 3000, viewport: 400),
    );
    expect(controller.value.memoUid, 'memo-1');

    controller.upsertGeometry(
      'memo-1',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 2000,
        toggleTopOffset: 900,
        toggleBottomOffset: 940,
      ),
    );
    controller.updateViewportMetrics(
      _metrics(pixels: 0, maxScrollExtent: 3000, viewport: 400),
    );
    expect(controller.value.memoUid, 'memo-1');
  });

  test('multiple candidates choose the one with larger visible height', () {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);

    controller.upsertGeometry(
      'memo-1',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 850,
        toggleTopOffset: -500,
        toggleBottomOffset: -460,
      ),
    );
    controller.upsertGeometry(
      'memo-2',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 200,
        cardBottomOffset: 1800,
        toggleTopOffset: 1401,
        toggleBottomOffset: 1441,
      ),
    );

    controller.updateViewportMetrics(
      _metrics(pixels: 400, maxScrollExtent: 3000, viewport: 500),
    );
    expect(controller.value.memoUid, 'memo-2');
  });

  test('equal visible height keeps first registered candidate', () {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);

    controller.upsertGeometry(
      'memo-1',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 1000,
        toggleTopOffset: -500,
        toggleBottomOffset: -460,
      ),
    );
    controller.upsertGeometry(
      'memo-2',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 1000,
        toggleTopOffset: 900,
        toggleBottomOffset: 940,
      ),
    );

    controller.updateViewportMetrics(
      _metrics(pixels: 250, maxScrollExtent: 3000, viewport: 500),
    );
    expect(controller.value.memoUid, 'memo-1');
  });

  test('removeGeometry and pruneToVisibleMemoUids clear stale candidates', () {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);

    controller.upsertGeometry(
      'memo-1',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 0,
        cardBottomOffset: 1600,
        toggleTopOffset: -500,
        toggleBottomOffset: -460,
      ),
    );
    controller.upsertGeometry(
      'memo-2',
      const MemoFloatingCollapseGeometry(
        cardTopOffset: 100,
        cardBottomOffset: 900,
        toggleTopOffset: 1000,
        toggleBottomOffset: 1040,
      ),
    );
    controller.updateViewportMetrics(
      _metrics(pixels: 0, maxScrollExtent: 3000, viewport: 400),
    );
    expect(controller.value.memoUid, 'memo-1');

    controller.removeGeometry('memo-1');
    expect(controller.value.memoUid, 'memo-2');

    controller.pruneToVisibleMemoUids(<String>{'memo-3'});
    expect(controller.value.memoUid, isNull);
  });

  test('handleScrollEvent mirrors legacy scrolling semantics', () {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);
    final metrics = _metrics(pixels: 120, maxScrollExtent: 1000, viewport: 300);

    controller.handleScrollEvent(
      _event(MemosListViewportScrollEventKind.start, metrics: metrics),
    );
    expect(controller.value.scrolling, isTrue);

    controller.handleScrollEvent(
      _event(
        MemosListViewportScrollEventKind.user,
        metrics: metrics,
        userDirection: ScrollDirection.idle,
      ),
    );
    expect(controller.value.scrolling, isFalse);

    controller.handleScrollEvent(
      _event(MemosListViewportScrollEventKind.update, metrics: metrics),
    );
    expect(controller.value.scrolling, isTrue);

    controller.handleScrollEvent(
      _event(MemosListViewportScrollEventKind.end, metrics: metrics),
    );
    expect(controller.value.scrolling, isFalse);
  });

  testWidgets('handleScrollEvent defers notifications during layout', (
    tester,
  ) async {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);
    final metrics = _metrics(pixels: 120, maxScrollExtent: 1000, viewport: 300);
    var layoutActive = false;
    var listenerCalledDuringLayout = false;
    var listenerCalls = 0;
    controller.addListener(() {
      listenerCalls += 1;
      listenerCalledDuringLayout = listenerCalledDuringLayout || layoutActive;
    });

    await tester.pumpWidget(
      ValueListenableBuilder<MemosListFloatingCollapseState>(
        valueListenable: controller,
        builder: (context, state, _) {
          return _LayoutCallback(
            onLayout: () {
              layoutActive = true;
              controller.handleScrollEvent(
                _event(
                  MemosListViewportScrollEventKind.start,
                  metrics: metrics,
                ),
              );
              layoutActive = false;
            },
            child: SizedBox(width: state.scrolling ? 2 : 1, height: 1),
          );
        },
      ),
    );

    expect(tester.takeException(), isNull);
    expect(listenerCalledDuringLayout, isFalse);
    expect(listenerCalls, 1);
    expect(controller.value.scrolling, isTrue);

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout-phase scroll events coalesce to the latest state', (
    tester,
  ) async {
    final controller = MemosListFloatingCollapseController();
    addTearDown(controller.dispose);
    final metrics = _metrics(pixels: 120, maxScrollExtent: 1000, viewport: 300);
    var listenerCalls = 0;
    controller.addListener(() => listenerCalls += 1);

    await tester.pumpWidget(
      _LayoutCallback(
        onLayout: () {
          controller.handleScrollEvent(
            _event(MemosListViewportScrollEventKind.start, metrics: metrics),
          );
          controller.handleScrollEvent(
            _event(MemosListViewportScrollEventKind.end, metrics: metrics),
          );
        },
        child: const SizedBox(width: 1, height: 1),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(listenerCalls, 0);
    expect(controller.value.scrolling, isFalse);
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

class _LayoutCallback extends SingleChildRenderObjectWidget {
  const _LayoutCallback({required this.onLayout, super.child});

  final void Function() onLayout;

  @override
  _LayoutCallbackRenderBox createRenderObject(BuildContext context) {
    return _LayoutCallbackRenderBox(onLayout);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _LayoutCallbackRenderBox renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _LayoutCallbackRenderBox extends RenderProxyBox {
  _LayoutCallbackRenderBox(this.onLayout);

  void Function() onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
