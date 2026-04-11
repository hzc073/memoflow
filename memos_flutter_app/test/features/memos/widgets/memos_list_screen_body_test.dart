import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/features/memos/home_quick_actions.dart';
import 'package:memos_flutter_app/features/memos/memos_list_screen_view_state.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_screen_body.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
  });

  testWidgets(
    'shows implied back button when route can pop and drawer is absent',
    (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _buildBodyScreen(drawerPanel: null),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-menu-button')), findsNothing);
    },
  );
}

Widget _buildBodyScreen({Widget? drawerPanel}) {
  final data = MemosListScreenBodyData(
    viewState: MemosListScreenViewState(
      query: MemosListScreenQueryState(
        searchQuery: '',
        resolvedTag: null,
        advancedFilters: AdvancedSearchFilters.empty,
        selectedShortcut: null,
        shortcutFilter: '',
        useShortcutFilter: false,
        selectedQuickSearchKind: null,
        useQuickSearch: false,
        useRemoteSearch: false,
        startTimeSec: null,
        endTimeSecExclusive: null,
        baseQuery: (
          searchQuery: '',
          state: 'NORMAL',
          tag: null,
          startTimeSec: null,
          endTimeSecExclusive: null,
          advancedFilters: AdvancedSearchFilters.empty,
          pageSize: 20,
        ),
        shortcutQuery: null,
        quickSearchQuery: null,
        sourceKind: MemosListMemoSourceKind.stream,
        queryKey: 'test',
        showSearchLanding: false,
        enableHomeSort: false,
      ),
      layout: const MemosListScreenLayoutState(
        showHeaderPillActions: false,
        listTopPadding: 0,
        listVisualOffset: 0,
        supportsDesktopSidePane: false,
        useDesktopSidePane: false,
        useInlineCompose: false,
        useWindowsDesktopHeader: false,
        headerToolbarHeight: kToolbarHeight,
        headerBottomHeight: 0,
        floatingCollapseTopPadding: 0,
        showComposeFab: false,
        backToTopBaseOffset: 0,
      ),
      guide: const MemosListScreenGuideState(
        canShowSearchShortcutGuide: false,
        canShowDesktopShortcutGuide: false,
        activeListGuideId: null,
      ),
      availableTemplates: const <MemoTemplate>[],
      recommendedTags: const <TagStat>[],
      activeTagStat: null,
      tagPresentationSignature: '',
    ),
    searching: false,
    showFilterTagChip: false,
    enableSearch: false,
    enableTitleMenu: false,
    screenshotModeEnabled: false,
    windowsHeaderSearchExpanded: false,
    desktopWindowMaximized: false,
    debugApiVersionText: '',
    activeListGuideId: null,
    activeListGuideMessage: null,
    memosLoading: false,
    memosError: null,
    visibleMemos: const [],
    showLoadMoreHint: false,
    loadMoreHintDisplayText: '',
    loadMoreHintTextColor: Colors.black,
    headerBackgroundColor: Colors.white,
    bottomInset: 0,
    showBackToTop: false,
    hapticsEnabled: false,
    floatingCollapseVisible: false,
    floatingCollapseScrolling: false,
    enableDrawerOpenDragGesture: true,
  );

  return MemosListScreenBody(
    scaffoldKey: GlobalKey<ScaffoldState>(),
    scrollController: ScrollController(),
    floatingCollapseViewportKey: GlobalKey(),
    listKey: GlobalKey<SliverAnimatedListState>(),
    data: data,
    drawerPanel: drawerPanel,
    titleChild: const Text('Title'),
    searchFieldChild: const SizedBox.shrink(),
    sortButton: null,
    resolvedTagChip: null,
    advancedFilterSliver: null,
    inlineComposeChild: null,
    inlineComposePadding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    expandDesktopBodyWidth: false,
    tagFilterBarChild: null,
    searchLandingChild: null,
    bootstrapOverlayChild: null,
    floatingActionButton: null,
    onRefresh: () async {},
    onScrollNotification: (_) => false,
    onPointerSignal: (PointerSignalEvent _) {},
    onCloseSearch: () {},
    onOpenSearch: () {},
    onToggleWindowsHeaderSearch: () {},
    onToggleQuickSearchKind: (_) {},
    onDismissGuide: () {},
    onCollapseFloatingMemo: () {},
    onScrollToTop: () {},
    quickActions: _buildQuickActions(),
    onMinimize: () {},
    onToggleMaximize: () {},
    onClose: () {},
    onEditTag: () async {},
    animatedItemBuilder: (_, _, _) => const SizedBox.shrink(),
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
