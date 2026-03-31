import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_floating_actions.dart';

void main() {
  testWidgets('tap triggers onPressed only', (tester) async {
    var tapCount = 0;
    var longPressStartCount = 0;
    var longPressEndCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MemoFlowFab(
              onPressed: () => tapCount++,
              onLongPressStart: (_) async => longPressStartCount++,
              onLongPressEnd: (_) => longPressEndCount++,
              hapticsEnabled: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MemoFlowFab));
    await tester.pump();

    expect(tapCount, 1);
    expect(longPressStartCount, 0);
    expect(longPressEndCount, 0);
  });

  testWidgets('long press triggers voice gesture only', (tester) async {
    var tapCount = 0;
    var longPressStartCount = 0;
    var longPressEndCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MemoFlowFab(
              onPressed: () => tapCount++,
              onLongPressStart: (_) async => longPressStartCount++,
              onLongPressEnd: (_) => longPressEndCount++,
              hapticsEnabled: false,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MemoFlowFab)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(tapCount, 0);
    expect(longPressStartCount, 1);
    expect(longPressEndCount, 1);
  });
}
