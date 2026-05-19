import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/platform/platform_route.dart';
import 'package:memos_flutter_app/platform/platform_scroll_behavior.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/platform/widgets/platform_controls.dart';
import 'package:memos_flutter_app/platform/widgets/platform_grouped_list.dart';
import 'package:memos_flutter_app/platform/widgets/platform_page.dart';

void main() {
  void setTargetPlatform(TargetPlatform platform) {
    debugPlatformTargetOverride = platform;
    addTearDown(() {
      debugPlatformTargetOverride = null;
    });
  }

  tearDownAll(() {
    debugPlatformTargetOverride = null;
  });

  testWidgets('resolves apple tablet and phone targets', (tester) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(500, 800)),
          child: SizedBox.expand(),
        ),
      ),
    );
    expect(
      resolvePlatformTarget(tester.element(find.byType(SizedBox))),
      PlatformTarget.iPhone,
    );

    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(820, 1180)),
          child: SizedBox.expand(),
        ),
      ),
    );
    expect(
      resolvePlatformTarget(tester.element(find.byType(SizedBox))),
      PlatformTarget.iPad,
    );
  });

  testWidgets('builds apple navigation chrome when on iOS', (tester) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: PlatformPage(title: Text('Title'), body: Text('Body')),
        ),
      ),
    );

    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('builds material fallback on desktop', (tester) async {
    setTargetPlatform(TargetPlatform.windows);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformPage(
          title: const Text('Title'),
          body: const Text('Body'),
        ),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('platform route selects cupertino on apple mobile', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) {
            final route = buildPlatformPageRoute<void>(
              context: context,
              builder: (_) => const SizedBox(),
            );
            expect(route, isA<CupertinoPageRoute<void>>());
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('grouped list uses cupertino section on apple mobile', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: PlatformGroupedList(children: [Text('One'), Text('Two')]),
        ),
      ),
    );

    expect(find.byType(CupertinoListSection), findsOneWidget);
  });

  testWidgets('adaptive switch renders on apple mobile', (tester) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      CupertinoApp(home: PlatformSwitch(value: true, onChanged: (_) {})),
    );

    expect(find.byType(CupertinoSwitch), findsOneWidget);
  });

  testWidgets(
    'app scroll behavior uses apple bounce physics on apple targets',
    (tester) async {
      setTargetPlatform(TargetPlatform.iOS);

      await tester.pumpWidget(
        const CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: SizedBox.expand(),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));

      expect(
        const PlatformAppScrollBehavior().getScrollPhysics(context),
        isA<BouncingScrollPhysics>(),
      );
    },
  );
}
