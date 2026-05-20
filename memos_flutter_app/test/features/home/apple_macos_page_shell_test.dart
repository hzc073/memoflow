import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/features/home/desktop/apple_macos_page_shell.dart';

void main() {
  testWidgets('rail layout keeps toolbar title outside traffic-light area', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(width: 900));

    expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
    final titleLeft = tester.getTopLeft(find.text('Title')).dx;

    expect(titleLeft, greaterThanOrEqualTo(kMacosTrafficLightReservedWidth));
  });

  testWidgets('expanded sidebar moves navigation below titlebar chrome', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(width: 1200));

    final navigationTop = tester.getTopLeft(
      find.byKey(const ValueKey('nav-expandedSidebar')),
    );

    expect(navigationTop.dy, kMacosTitleBarHeight);
  });
}

Widget _buildHarness({required double width}) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.macOS),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: AppleMacosPageShell(
          navigationBuilder: (viewMode, embedded) => Container(
            key: ValueKey('nav-${viewMode.name}'),
            color: Colors.blue,
          ),
          leadingTitle: const Text('Title'),
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
}
