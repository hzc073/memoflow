import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/features/memos/home_quick_actions.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_macos_desktop_title_bar.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_search_widgets.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
  });

  testWidgets('shows quick action pills while preserving traffic-light inset', (
    tester,
  ) async {
    var pillTapCount = 0;
    var searchTapCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        width: 900,
        child: _buildTitleBar(
          quickActions: _buildQuickActions(onPressed: () => pillTapCount++),
          onOpenSearch: () => searchTapCount++,
        ),
      ),
    );

    expect(find.byType(MemosListPillRow), findsOneWidget);
    expect(find.text('MemoFlow'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(kMemosListMacosTrafficSafeInsetKey)).width,
      kMemosListMacosTrafficLightSafeInset,
    );
    expect(find.byIcon(Icons.minimize_rounded), findsNothing);
    expect(find.byIcon(Icons.crop_square_rounded), findsNothing);
    expect(find.byIcon(Icons.filter_none_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.tap(find.text('Monthly stats'));
    await tester.tap(find.byIcon(Icons.search));

    expect(pillTapCount, 1);
    expect(searchTapCount, 1);
  });

  testWidgets('searching state moves the search field into the titlebar', (
    tester,
  ) async {
    var closeSearchCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        width: 900,
        child: _buildTitleBar(
          searching: true,
          onCloseSearch: () => closeSearchCount++,
        ),
      ),
    );

    expect(find.byKey(const Key('macos-search-field')), findsOneWidget);
    expect(find.byType(MemosListPillRow), findsNothing);

    await tester.tap(find.byIcon(Icons.close));

    expect(closeSearchCount, 1);
  });

  testWidgets('compact widths prioritize pill actions over title text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(width: 520, child: _buildTitleBar()));

    expect(find.byType(MemosListPillRow), findsOneWidget);
    expect(find.text('MemoFlow'), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}

Widget _buildHarness({required double width, required Widget child}) {
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

Widget _buildTitleBar({
  bool searching = false,
  List<HomeQuickActionChipData>? quickActions,
  VoidCallback? onOpenSearch,
  VoidCallback? onCloseSearch,
}) {
  return MemosListMacosDesktopTitleBar(
    isDark: false,
    searching: searching,
    showPillActions: true,
    enableHomeSort: true,
    enableSearch: true,
    titleChild: const Text('MemoFlow'),
    searchFieldChild: const SizedBox(key: Key('macos-search-field')),
    quickActions: quickActions ?? _buildQuickActions(),
    onOpenSearch: onOpenSearch ?? () {},
    onCloseSearch: onCloseSearch ?? () {},
    searchTooltip: 'Search',
    cancelTooltip: 'Cancel',
    sortButton: const Icon(Icons.sort),
  );
}

List<HomeQuickActionChipData> _buildQuickActions({VoidCallback? onPressed}) {
  return [
    HomeQuickActionChipData(
      action: HomeQuickAction.monthlyStats,
      icon: Icons.insights,
      label: 'Monthly stats',
      iconColor: Colors.blue,
      onPressed: onPressed ?? () {},
    ),
    HomeQuickActionChipData(
      action: HomeQuickAction.aiSummary,
      icon: Icons.auto_awesome,
      label: 'AI Summary',
      iconColor: Colors.purple,
      onPressed: () {},
    ),
    HomeQuickActionChipData(
      action: HomeQuickAction.dailyReview,
      icon: Icons.explore,
      label: 'Random Review',
      iconColor: Colors.orange,
      onPressed: () {},
    ),
  ];
}
