import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/features/home/desktop/apple_macos_page_shell.dart';
import 'package:memos_flutter_app/features/home/desktop/desktop_shell_host.dart';

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

  testWidgets('expanded sidebar omits redundant top-level title', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(width: 1200));

    expect(find.byKey(const ValueKey('nav-expandedSidebar')), findsOneWidget);
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('secondary route context keeps meaningful toolbar title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        width: 1200,
        navigationContext: DesktopTitlebarNavigationContext.secondaryTask,
      ),
    );

    expect(find.byKey(const ValueKey('nav-expandedSidebar')), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('navigation area provides Material for ink widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        width: 1200,
        navigationChild: const InkWell(child: SizedBox(width: 24, height: 24)),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

Widget _buildHarness({
  required double width,
  DesktopTitlebarNavigationContext navigationContext =
      DesktopTitlebarNavigationContext.topLevelDestination,
  Widget? navigationChild,
}) {
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
            child: navigationChild,
          ),
          leadingTitle: const Text('Title'),
          navigationContext: navigationContext,
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
}
