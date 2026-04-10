import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/features/memos/home_quick_actions.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_search_widgets.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_windows_desktop_title_bar.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows pill actions by default when search is collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(child: _buildTitleBar()));

    expect(find.byType(MemosListPillRow), findsOneWidget);
    expect(find.byKey(const Key('search-field')), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('shows search field and toggles search callback when expanded', (
    tester,
  ) async {
    var toggleCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        child: _buildTitleBar(
          windowsHeaderSearchExpanded: true,
          onToggleSearch: () => toggleCount++,
        ),
      ),
    );

    expect(find.byType(MemosListPillRow), findsNothing);
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    expect(toggleCount, 1);
  });

  testWidgets('hides pill actions when no quick actions are configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(child: _buildTitleBar(quickActions: const [])),
    );

    expect(find.byType(MemosListPillRow), findsNothing);
    expect(find.byKey(const Key('search-field')), findsNothing);
  });

  testWidgets('shows sort button only when home sort is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(child: _buildTitleBar(enableHomeSort: true)),
    );

    expect(find.byKey(const Key('sort-button')), findsOneWidget);

    await tester.pumpWidget(
      _buildHarness(child: _buildTitleBar(enableHomeSort: false)),
    );

    expect(find.byKey(const Key('sort-button')), findsNothing);
  });

  testWidgets(
    'window control buttons call callbacks and maximize icon reflects state',
    (tester) async {
      var minimizeCount = 0;
      var maximizeCount = 0;
      var closeCount = 0;

      await tester.pumpWidget(
        _buildHarness(
          child: _buildTitleBar(
            onMinimize: () => minimizeCount++,
            onToggleMaximize: () => maximizeCount++,
            onClose: () => closeCount++,
          ),
        ),
      );

      expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.minimize_rounded));
      await tester.tap(find.byIcon(Icons.crop_square_rounded));
      await tester.tap(find.byIcon(Icons.close_rounded));

      expect(minimizeCount, 1);
      expect(maximizeCount, 1);
      expect(closeCount, 1);

      await tester.pumpWidget(
        _buildHarness(child: _buildTitleBar(desktopWindowMaximized: true)),
      );

      expect(find.byIcon(Icons.filter_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.crop_square_rounded), findsNothing);
    },
  );

  testWidgets('debug badge hides in screenshot mode', (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: _buildTitleBar(
          screenshotModeEnabled: false,
          debugApiVersionText: 'API v0.24',
        ),
      ),
    );

    expect(find.text('API v0.24'), findsOneWidget);

    await tester.pumpWidget(
      _buildHarness(
        child: _buildTitleBar(
          screenshotModeEnabled: true,
          debugApiVersionText: 'API v0.24',
        ),
      ),
    );

    expect(find.text('API v0.24'), findsNothing);
  });
}

Widget _buildHarness({required Widget child}) {
  LocaleSettings.setLocale(AppLocale.en);
  return TranslationProvider(
    child: MaterialApp(
      locale: AppLocale.en.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: child),
    ),
  );
}

Widget _buildTitleBar({
  bool showPillActions = true,
  bool windowsHeaderSearchExpanded = false,
  bool enableHomeSort = true,
  bool enableSearch = true,
  bool screenshotModeEnabled = false,
  bool desktopWindowMaximized = false,
  String debugApiVersionText = 'API v0.24',
  List<HomeQuickActionChipData>? quickActions,
  VoidCallback? onToggleSearch,
  VoidCallback? onMinimize,
  VoidCallback? onToggleMaximize,
  VoidCallback? onClose,
}) {
  return MemosListWindowsDesktopTitleBar(
    isDark: false,
    showPillActions: showPillActions,
    windowsHeaderSearchExpanded: windowsHeaderSearchExpanded,
    enableHomeSort: enableHomeSort,
    enableSearch: enableSearch,
    screenshotModeEnabled: screenshotModeEnabled,
    desktopWindowMaximized: desktopWindowMaximized,
    debugApiVersionText: debugApiVersionText,
    titleChild: const Text('MemoFlow'),
    searchFieldChild: const SizedBox(key: Key('search-field')),
    sortButton: const SizedBox(key: Key('sort-button')),
    onToggleSearch: onToggleSearch ?? () {},
    quickActions: quickActions ?? _buildQuickActions(),
    onMinimize: onMinimize ?? () {},
    onToggleMaximize: onToggleMaximize ?? () {},
    onClose: onClose ?? () {},
    searchTooltip: 'Search',
    cancelTooltip: 'Cancel',
    minimizeTooltip: 'Minimize',
    maximizeTooltip: 'Maximize',
    restoreTooltip: 'Restore',
    closeTooltip: 'Close',
  );
}

List<HomeQuickActionChipData> _buildQuickActions() {
  return [
    HomeQuickActionChipData(
      action: HomeQuickAction.monthlyStats,
      icon: Icons.insights,
      label: 'Monthly stats',
      iconColor: Colors.blue,
      onPressed: () {},
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
