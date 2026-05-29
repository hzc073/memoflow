import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/home/app_drawer.dart';
import 'package:memos_flutter_app/features/home/desktop/desktop_shell_host.dart';
import 'package:memos_flutter_app/features/home/desktop/windows_desktop_page_shell.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windowManagerChannel = MethodChannel('window_manager');

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (call) async {
          switch (call.method) {
            case 'isMaximized':
              return false;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, null);
  });

  testWidgets('shows overlay navigation on narrow windows after menu tap', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(width: 900));

    expect(find.byKey(const ValueKey('drawer-menu-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-overlayPanel')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('drawer-menu-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nav-overlayPanel')), findsOneWidget);
  });

  testWidgets('shows rail on compact windows', (tester) async {
    await tester.pumpWidget(_buildHarness(width: 1100));

    expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-menu-button')), findsNothing);
  });

  testWidgets('shows expanded sidebar on wide windows', (tester) async {
    await tester.pumpWidget(_buildHarness(width: 1400));

    expect(find.byKey(const ValueKey('nav-expandedSidebar')), findsOneWidget);
  });

  testWidgets('shows centered modal surface when provided', (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        width: 1400,
        modalSurface: const ColoredBox(
          key: ValueKey<String>('test-modal-surface'),
          color: Colors.red,
        ),
        modalSurfaceVisible: true,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('windows-desktop-modal-backdrop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('test-modal-surface')),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows resizable Windows secondary pane when callback is provided',
    (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          width: 1400,
          secondaryPane: const SizedBox(
            key: ValueKey<String>('test-secondary-pane'),
          ),
          secondaryPaneVisible: true,
          onSecondaryPaneWidthChanged: (_) {},
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('test-secondary-pane')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('windows-desktop-secondary-pane-resizer'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('close button requests the shared close command', (tester) async {
    var closeRequestCount = 0;
    await tester.pumpWidget(
      _buildHarness(
        width: 1400,
        showWindowControls: true,
        onRequestCloseWindow: () async {
          closeRequestCount += 1;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();

    expect(closeRequestCount, 1);
  });

  testWidgets('desktop shell host delegates macOS to apple shell', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDesktopHostHarness(TargetPlatform.macOS));

    expect(
      find.byKey(const ValueKey<String>('apple-macos-page-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('apple-macos-toolbar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nav-expandedSidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-menu-button')), findsNothing);
  });

  testWidgets(
    'macOS shell renders inline secondary pane without Windows resizer',
    (tester) async {
      await tester.pumpWidget(
        _buildDesktopHostHarness(
          TargetPlatform.macOS,
          secondaryPane: const SizedBox(
            key: ValueKey<String>('test-macos-secondary-pane'),
          ),
          secondaryPaneVisible: true,
          onSecondaryPaneWidthChanged: (_) {},
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('test-macos-secondary-pane')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('windows-desktop-secondary-pane-resizer'),
        ),
        findsNothing,
      );
    },
  );
}

Widget _buildHarness({
  required double width,
  Widget? modalSurface,
  bool modalSurfaceVisible = false,
  Widget? secondaryPane,
  bool secondaryPaneVisible = false,
  ValueChanged<double>? onSecondaryPaneWidthChanged,
  bool showWindowControls = false,
  WindowsDesktopCloseCommand? onRequestCloseWindow,
}) {
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 900)),
          child: WindowsDesktopPageShell(
            navigationBuilder: (viewMode, embedded) => Container(
              key: ValueKey('nav-${viewMode.name}'),
              color: Colors.blue,
            ),
            leadingTitle: const Text('Title'),
            body: const SizedBox.expand(),
            secondaryPane: secondaryPane,
            secondaryPaneVisible: secondaryPaneVisible,
            onSecondaryPaneWidthChanged: onSecondaryPaneWidthChanged,
            modalSurface: modalSurface,
            modalSurfaceVisible: modalSurfaceVisible,
            showWindowControls: showWindowControls,
            onRequestCloseWindow: onRequestCloseWindow,
          ),
        ),
      ),
    ),
  );
}

Widget _buildDesktopHostHarness(
  TargetPlatform platform, {
  Widget? secondaryPane,
  bool secondaryPaneVisible = false,
  ValueChanged<double>? onSecondaryPaneWidthChanged,
}) {
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 900)),
          child: DesktopShellHost(
            navigationBuilder: _testNavigationBuilder,
            leadingTitle: const Text('Title'),
            body: const SizedBox.expand(),
            secondaryPane: secondaryPane,
            secondaryPaneVisible: secondaryPaneVisible,
            onSecondaryPaneWidthChanged: onSecondaryPaneWidthChanged,
            showWindowControls: false,
          ),
        ),
      ),
    ),
  );
}

Widget _testNavigationBuilder(AppDrawerViewMode viewMode, bool embedded) {
  return Container(key: ValueKey('nav-${viewMode.name}'), color: Colors.blue);
}
