import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/home/app_drawer.dart';
import 'package:memos_flutter_app/features/home/desktop/desktop_shell_host.dart';
import 'package:memos_flutter_app/features/home/desktop/windows_desktop_page_shell.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
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
}

Widget _buildHarness({
  required double width,
  Widget? modalSurface,
  bool modalSurfaceVisible = false,
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
            modalSurface: modalSurface,
            modalSurfaceVisible: modalSurfaceVisible,
            showWindowControls: false,
          ),
        ),
      ),
    ),
  );
}

Widget _buildDesktopHostHarness(TargetPlatform platform) {
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(1200, 900)),
          child: DesktopShellHost(
            navigationBuilder: _testNavigationBuilder,
            leadingTitle: Text('Title'),
            body: SizedBox.expand(),
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
