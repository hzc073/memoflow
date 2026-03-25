import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/pointer_double_tap_listener.dart';

void main() {
  testWidgets('fires callback when primary pointer double taps', (
    tester,
  ) async {
    var triggerCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PointerDoubleTapListener(
              onDoubleTap: () => triggerCount++,
              child: Container(
                key: const ValueKey('double-tap-target'),
                width: 120,
                height: 120,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byKey(const ValueKey('double-tap-target'));
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(target);
    await tester.pump();

    expect(triggerCount, 1);
  });

  testWidgets('does not fire when taps are too far apart in position', (
    tester,
  ) async {
    var triggerCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PointerDoubleTapListener(
              onDoubleTap: () => triggerCount++,
              child: Container(
                key: const ValueKey('double-tap-target'),
                width: 240,
                height: 120,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byKey(const ValueKey('double-tap-target'));
    final rect = tester.getRect(target);
    await tester.tapAt(rect.centerLeft + const Offset(24, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(rect.centerRight - const Offset(24, 0));
    await tester.pump();

    expect(triggerCount, 0);
  });
}
