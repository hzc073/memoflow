import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/desktop/desktop_titlebar_navigation_policy.dart';
import 'package:memos_flutter_app/core/desktop/window_chrome_safe_area.dart';
import 'package:memos_flutter_app/platform/platform_route.dart';
import 'package:memos_flutter_app/platform/platform_scroll_behavior.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/platform/widgets/platform_action_sheet.dart';
import 'package:memos_flutter_app/platform/widgets/platform_adaptive_layout.dart';
import 'package:memos_flutter_app/platform/widgets/platform_controls.dart';
import 'package:memos_flutter_app/platform/widgets/platform_dialog.dart';
import 'package:memos_flutter_app/platform/widgets/platform_grouped_list.dart';
import 'package:memos_flutter_app/platform/widgets/platform_list_section.dart';
import 'package:memos_flutter_app/platform/widgets/platform_page.dart';
import 'package:memos_flutter_app/platform/widgets/platform_picker.dart';
import 'package:memos_flutter_app/platform/widgets/platform_primary_action.dart';

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
    expect(
      tester
          .widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar))
          .transitionBetweenRoutes,
      isFalse,
    );

    final bodyTextStyle = DefaultTextStyle.of(
      tester.element(find.text('Body')),
    ).style;
    expect(bodyTextStyle.fontSize, 14);
    expect(bodyTextStyle.decoration, TextDecoration.none);
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

  testWidgets('macOS secondary pages keep app-level back affordance', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.macOS);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlatformPage(
                      title: const Text('Details'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {},
                      ),
                      body: const Text('Body'),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(
      debugDesktopRouteDismissalControlPolicy(
        platform: TargetPlatform.macOS,
        navigationContext: DesktopTitlebarNavigationContext.secondaryTask,
      ),
      'visible',
    );
  });

  testWidgets('macOS expanded sidebar top-level page omits title and leading', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.macOS);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformPage(
          desktopNavigationMode: DesktopTitlebarNavigationMode.expandedSidebar,
          desktopNavigationContext:
              DesktopTitlebarNavigationContext.topLevelDestination,
          title: const Text('Top Level'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {},
          ),
          actions: const [Icon(Icons.search)],
          body: const Text('Body'),
        ),
      ),
    );

    expect(find.text('Top Level'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(tester.getSize(find.byType(AppBar)).height, kMacosTitleBarHeight);
  });

  testWidgets('macOS expanded sidebar top-level page keeps titlebar spacer', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.macOS);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformPage(
          desktopNavigationMode: DesktopTitlebarNavigationMode.expandedSidebar,
          desktopNavigationContext:
              DesktopTitlebarNavigationContext.topLevelDestination,
          title: const Text('Top Level'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {},
          ),
          body: const Text('Body'),
        ),
      ),
    );

    expect(find.text('Top Level'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.getSize(find.byType(AppBar)).height, kMacosTitleBarHeight);
  });

  testWidgets(
    'macOS desktop chrome safe area keeps title outside traffic lights',
    (tester) async {
      setTargetPlatform(TargetPlatform.macOS);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlatformPage(
            title: Text('Task Title'),
            body: Text('Body'),
            desktopWindowChromeSafeArea: true,
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Task Title')).dx,
        greaterThanOrEqualTo(kMacosTrafficLightReservedWidth),
      );
    },
  );

  testWidgets(
    'non-macOS desktop chrome safe area keeps default title spacing',
    (tester) async {
      setTargetPlatform(TargetPlatform.windows);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlatformPage(
            title: Text('Task Title'),
            body: Text('Body'),
            desktopWindowChromeSafeArea: true,
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Task Title')).dx,
        lessThan(kMacosTrafficLightReservedWidth),
      );
    },
  );

  test('macOS expanded sidebar top-level page omits toolbar divider', () {
    expect(
      shouldRenderDesktopTopLevelToolbarDivider(
        platform: TargetPlatform.macOS,
        navigationMode: DesktopTitlebarNavigationMode.expandedSidebar,
        navigationContext: DesktopTitlebarNavigationContext.topLevelDestination,
      ),
      isFalse,
    );
    expect(
      shouldRenderDesktopTopLevelToolbarDivider(
        platform: TargetPlatform.macOS,
        navigationMode: DesktopTitlebarNavigationMode.hidden,
        navigationContext: DesktopTitlebarNavigationContext.topLevelDestination,
      ),
      isTrue,
    );
    expect(
      shouldRenderDesktopTopLevelToolbarDivider(
        platform: TargetPlatform.macOS,
        navigationMode: DesktopTitlebarNavigationMode.expandedSidebar,
        navigationContext: DesktopTitlebarNavigationContext.secondaryTask,
      ),
      isTrue,
    );
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

  testWidgets('text field renders cupertino input on apple mobile', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    final controller = TextEditingController(text: 'Local Library');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Center(
            child: SizedBox(
              width: 240,
              child: PlatformTextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Repository name',
                  suffixIcon: Icon(Icons.edit),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Local Library'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'Renamed');
    expect(controller.text, 'Renamed');
  });

  testWidgets('text field keeps material input outside apple mobile', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.android);

    final controller = TextEditingController(text: 'Local Library');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: PlatformTextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Repository name'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(find.text('Local Library'), findsOneWidget);
  });

  testWidgets('list section uses cupertino grouped rows on apple mobile', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: PlatformListSection(
            header: Text('General'),
            children: [
              PlatformListSectionRow(title: Text('Language')),
              PlatformListSectionRow(title: Text('Theme')),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CupertinoListSection), findsOneWidget);
    expect(find.byType(CupertinoListTile), findsNWidgets(2));
  });

  testWidgets('list section uses dense rows on desktop', (tester) async {
    setTargetPlatform(TargetPlatform.windows);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformListSection(
          header: const Text('General'),
          children: [
            PlatformListSectionRow(title: const Text('Language'), onTap: () {}),
            PlatformListSectionRow(title: const Text('Theme'), onTap: () {}),
          ],
        ),
      ),
    );

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(rows, hasLength(2));
    expect(rows.every((row) => row.dense == true), isTrue);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('list section keeps material mobile rows touch sized', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.android);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformListSection(
          children: [
            PlatformListSectionRow(title: const Text('Language'), onTap: () {}),
          ],
        ),
      ),
    );

    final row = tester.widget<ListTile>(find.byType(ListTile));
    expect(row.dense, isFalse);
    expect(row.visualDensity, VisualDensity.standard);
  });

  testWidgets('list section can apply semantic mobile row min height', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.android);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformListSection(
          children: [
            PlatformListSectionRow(
              title: const Text('Language'),
              mobileMinTileHeight: 48,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final row = tester.widget<ListTile>(find.byType(ListTile));
    expect(row.dense, isFalse);
    expect(row.visualDensity, VisualDensity.standard);
    expect(row.minTileHeight, 48);
  });

  testWidgets(
    'semantic mobile row min height does not override desktop dense',
    (tester) async {
      setTargetPlatform(TargetPlatform.windows);

      await tester.pumpWidget(
        MaterialApp(
          home: PlatformListSection(
            children: [
              PlatformListSectionRow(
                title: const Text('Language'),
                mobileMinTileHeight: 48,
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      final row = tester.widget<ListTile>(find.byType(ListTile));
      expect(row.dense, isTrue);
      expect(row.minTileHeight, isNull);
    },
  );

  testWidgets('bounded content limits regular desktop width', (tester) async {
    setTargetPlatform(TargetPlatform.macOS);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1200,
            child: PlatformBoundedContent(
              desktopMaxWidth: 640,
              child: SizedBox.expand(key: ValueKey<String>('bounded-child')),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey<String>('bounded-child'))).width,
      640,
    );
  });

  testWidgets('bounded content keeps mobile full width', (tester) async {
    setTargetPlatform(TargetPlatform.android);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 390,
            child: PlatformBoundedContent(
              desktopMaxWidth: 640,
              child: SizedBox.expand(key: ValueKey<String>('bounded-child')),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey<String>('bounded-child'))).width,
      390,
    );
  });

  testWidgets('master detail shows secondary pane on wide desktop', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.windows);
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1200,
            height: 600,
            child: PlatformMasterDetail(
              breakpoint: 1000,
              detailWidth: 360,
              master: SizedBox(key: ValueKey<String>('master')),
              detail: SizedBox(key: ValueKey<String>('detail')),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('master')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('detail')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('detail'))).width,
      360,
    );
  });

  testWidgets('master detail collapses on mobile', (tester) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1200,
            height: 600,
            child: PlatformMasterDetail(
              master: SizedBox(key: ValueKey<String>('master')),
              detail: SizedBox(key: ValueKey<String>('detail')),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('master')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('detail')), findsNothing);
  });

  testWidgets('primary action uses cupertino button across mobile width', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 390,
            child: PlatformPrimaryAction(
              onPressed: () {},
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CupertinoButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.getSize(find.byType(CupertinoButton)).width, 390);
  });

  testWidgets('primary action stays bounded on regular desktop', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.macOS);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 800,
            child: PlatformPrimaryAction(
              onPressed: () {},
              child: const SizedBox(width: 1000, child: Text('Continue')),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(FilledButton)).width,
      lessThanOrEqualTo(320),
    );
  });

  testWidgets('primary action keeps narrow desktop fallback full width', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.windows);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            child: PlatformPrimaryAction(
              onPressed: () {},
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(FilledButton)).width, 360);
  });

  testWidgets('platform alert dialog uses cupertino on apple mobile', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showPlatformAlertDialog<bool>(
              context: context,
              title: 'Delete memo',
              message: 'This cannot be undone.',
              actions: const [
                PlatformDialogAction<bool>(value: false, label: 'Cancel'),
                PlatformDialogAction<bool>(
                  value: true,
                  label: 'Delete',
                  isDefault: true,
                  isDestructive: true,
                ),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('platform alert dialog uses material fallback on desktop', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.windows);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlatformAlertDialog<bool>(
              context: context,
              title: 'Delete memo',
              message: 'This cannot be undone.',
              actions: const [
                PlatformDialogAction<bool>(value: false, label: 'Cancel'),
                PlatformDialogAction<bool>(
                  value: true,
                  label: 'Delete',
                  isDefault: true,
                  isDestructive: true,
                ),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('platform action sheet uses cupertino modal popup on iOS', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.iOS);

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showPlatformActionSheet<void>(
              context: context,
              builder: (_) => const Text('Apple action'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Apple action'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('platform action sheet uses bounded dialog on desktop', (
    tester,
  ) async {
    setTargetPlatform(TargetPlatform.windows);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlatformActionSheet<void>(
              context: context,
              builder: (_) => const Text('Desktop action'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Desktop action'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('platform picker uses bounded dialog on desktop', (tester) async {
    setTargetPlatform(TargetPlatform.macOS);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlatformPicker<void>(
              context: context,
              builder: (_) => const Text('Desktop picker'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Desktop picker'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
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
