import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/app_motion_widgets.dart';
import 'package:memos_flutter_app/core/memoflow_palette.dart';
import 'package:memos_flutter_app/core/theme_colors.dart';
import 'package:memos_flutter_app/data/ai/ai_semantic_memo_search_service.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/features/memos/home_quick_actions.dart';
import 'package:memos_flutter_app/features/memos/memos_list_floating_collapse_controller.dart';
import 'package:memos_flutter_app/features/memos/memos_list_screen_view_state.dart';
import 'package:memos_flutter_app/features/memos/widgets/floating_collapse_button.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_floating_actions.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_macos_desktop_title_bar.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_search_widgets.dart';
import 'package:memos_flutter_app/features/memos/widgets/memos_list_screen_body.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    MemoFlowPalette.applyThemeColor(AppThemeColor.brickRed);
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

  testWidgets(
    'macOS titlebar shows quick action pills without duplicating header pills',
    (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(platform: TargetPlatform.macOS),
            home: _buildBodyScreen(
              data: _buildBodyData(
                visibleMemos: <LocalMemo>[_buildMemo('memo-1')],
                layout: _buildLayout(
                  showHeaderPillActions: true,
                  useMacosDesktopTitleBar: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MemosListMacosDesktopTitleBar), findsOneWidget);
      expect(find.byType(MemosListPillRow), findsOneWidget);
      expect(find.byIcon(Icons.minimize_rounded), findsNothing);
      expect(find.byIcon(Icons.crop_square_rounded), findsNothing);
      expect(find.byIcon(Icons.filter_none_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    },
  );

  testWidgets(
    'switches loading and empty placeholders through AnimatedSwitcher',
    (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: _buildBodyScreen(data: _buildBodyData(memosLoading: true)),
          ),
        ),
      );

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            locale: AppLocale.en.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: _buildBodyScreen(data: _buildBodyData()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No content yet'), findsOneWidget);
    },
  );

  testWidgets('overlay buttons react to listenable changes', (tester) async {
    MemoFlowPalette.applyThemeColor(AppThemeColor.cypressGreen);
    final showBackToTop = ValueNotifier<bool>(false);
    final floatingCollapse = ValueNotifier<MemosListFloatingCollapseState>(
      const MemosListFloatingCollapseState(memoUid: null, scrolling: false),
    );
    addTearDown(showBackToTop.dispose);
    addTearDown(floatingCollapse.dispose);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _buildBodyScreen(
            showBackToTopListenable: showBackToTop,
            floatingCollapseListenable: floatingCollapse,
          ),
        ),
      ),
    );

    var floatingButton = tester.widget<MemoFloatingCollapseButton>(
      find.byType(MemoFloatingCollapseButton),
    );
    expect(floatingButton.visible, isFalse);
    expect(find.byType(BackToTopButton), findsOneWidget);
    var backToTopButton = tester.widget<BackToTopButton>(
      find.byType(BackToTopButton),
    );
    expect(backToTopButton.visible, isFalse);

    showBackToTop.value = true;
    floatingCollapse.value = const MemosListFloatingCollapseState(
      memoUid: 'memo-1',
      scrolling: true,
    );
    await tester.pumpAndSettle();

    floatingButton = tester.widget<MemoFloatingCollapseButton>(
      find.byType(MemoFloatingCollapseButton),
    );
    expect(floatingButton.visible, isTrue);
    expect(floatingButton.scrolling, isTrue);
    expect(
      find.descendant(
        of: find.byType(MemoFloatingCollapseButton),
        matching: find.byIcon(Icons.unfold_less_rounded),
      ),
      findsOneWidget,
    );
    backToTopButton = tester.widget<BackToTopButton>(
      find.byType(BackToTopButton),
    );
    expect(backToTopButton.visible, isTrue);

    final collapseRectWithBackToTop = tester.getRect(
      find.byType(MemoFloatingCollapseButton),
    );
    final backToTopRect = tester.getRect(find.byType(BackToTopButton));
    expect(collapseRectWithBackToTop.bottom, lessThan(backToTopRect.top));
    expect(
      backToTopRect.top - collapseRectWithBackToTop.bottom,
      closeTo(12, 0.1),
    );
    final collapseDecoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(MemoFloatingCollapseButton),
                    matching: find.byType(Container),
                  ),
                )
                .decoration
            as BoxDecoration;
    final backToTopDecoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(BackToTopButton),
                    matching: find.byType(Container),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(collapseDecoration.color, MemoFlowPalette.primary);
    expect(collapseDecoration.color, backToTopDecoration.color);

    showBackToTop.value = false;
    await tester.pumpAndSettle();

    final collapseRectWithoutBackToTop = tester.getRect(
      find.byType(MemoFloatingCollapseButton),
    );
    expect(
      collapseRectWithoutBackToTop.top,
      closeTo(collapseRectWithBackToTop.top, 0.1),
    );
    backToTopButton = tester.widget<BackToTopButton>(
      find.byType(BackToTopButton),
    );
    expect(backToTopButton.visible, isFalse);
  });

  testWidgets('mobile touch scroll moves floating actions to active side', (
    tester,
  ) async {
    await _pumpBodyWithVisibleFloatingActions(
      tester,
      platform: TargetPlatform.android,
    );

    final initialRightRect = _collapseButtonRect(tester);
    expect(initialRightRect.right, closeTo(800 - 16, 0.1));

    await tester.dragFrom(const Offset(80, 420), const Offset(0, -80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final movingLeftRect = _collapseButtonRect(tester);
    expect(movingLeftRect.left, greaterThan(16));
    expect(movingLeftRect.left, lessThan(initialRightRect.left));

    await tester.pumpAndSettle();

    final settledLeftRect = _collapseButtonRect(tester);
    expect(settledLeftRect.left, closeTo(16, 0.1));

    await tester.dragFrom(const Offset(720, 420), const Offset(0, -80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final movingRightRect = _collapseButtonRect(tester);
    expect(movingRightRect.right, lessThan(800 - 16));
    expect(movingRightRect.right, greaterThan(settledLeftRect.right));

    await tester.pumpAndSettle();

    expect(_collapseButtonRect(tester).right, closeTo(800 - 16, 0.1));
  });

  testWidgets('reduced motion skips floating action side spring travel', (
    tester,
  ) async {
    await _pumpBodyWithVisibleFloatingActions(
      tester,
      platform: TargetPlatform.android,
      disableAnimations: true,
    );

    expect(_collapseButtonRect(tester).right, closeTo(800 - 16, 0.1));

    await tester.dragFrom(const Offset(80, 420), const Offset(0, -80));
    await tester.pump();

    expect(_collapseButtonRect(tester).left, closeTo(16, 0.1));

    await tester.pump(const Duration(milliseconds: 16));

    expect(_collapseButtonRect(tester).left, closeTo(16, 0.1));
  });

  testWidgets('mobile plain taps do not move floating actions', (tester) async {
    await _pumpBodyWithVisibleFloatingActions(
      tester,
      platform: TargetPlatform.android,
    );

    final initialRect = _collapseButtonRect(tester);

    await tester.tapAt(const Offset(80, 420));
    await tester.pumpAndSettle();

    expect(_collapseButtonRect(tester).left, closeTo(initialRect.left, 0.1));
    expect(_collapseButtonRect(tester).right, closeTo(initialRect.right, 0.1));
  });

  testWidgets('desktop scroll input keeps floating actions right aligned', (
    tester,
  ) async {
    await _pumpBodyWithVisibleFloatingActions(
      tester,
      platform: TargetPlatform.windows,
    );

    await tester.dragFrom(const Offset(80, 420), const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(_collapseButtonRect(tester).right, closeTo(800 - 16, 0.1));
  });

  testWidgets(
    'mobile drawer swipe over memo card opens drawer without activating card',
    (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();
      var tapCount = 0;
      var longPressCount = 0;

      await _pumpBodyWithDrawerSwipeTarget(
        tester,
        scaffoldKey: scaffoldKey,
        onTap: () => tapCount++,
        onLongPress: () => longPressCount++,
      );

      final memoCard = find.byKey(_drawerSwipeMemoCardKey);
      final pressScale = find.ancestor(
        of: memoCard,
        matching: find.byType(AnimatedScale),
      );

      expect(memoCard, findsOneWidget);
      expect(pressScale, findsOneWidget);
      expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);

      final gesture = await tester.startGesture(tester.getCenter(memoCard));
      await tester.pump();

      expect(tester.widget<AnimatedScale>(pressScale).scale, 0.97);

      await gesture.moveBy(const Offset(32, 0));
      await tester.pump();

      expect(tester.widget<AnimatedScale>(pressScale).scale, 1);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(scaffoldKey.currentState!.isDrawerOpen, isTrue);
      expect(tapCount, 0);
      expect(longPressCount, 0);
    },
  );

  testWidgets('active search keeps drawer swipe disabled over memo content', (
    tester,
  ) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await _pumpBodyWithDrawerSwipeTarget(
      tester,
      scaffoldKey: scaffoldKey,
      searching: true,
    );

    await _dragRightFromMemoCard(tester);

    expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
  });

  testWidgets('desktop side pane keeps drawer swipe disabled', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await _pumpBodyWithDrawerSwipeTarget(
      tester,
      scaffoldKey: scaffoldKey,
      platform: TargetPlatform.windows,
      useDesktopSidePane: true,
    );

    await _dragRightFromMemoCard(tester);

    expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
  });

  testWidgets('keyword empty state offers explicit AI search CTA', (
    tester,
  ) async {
    var aiSearchStarted = false;
    final aiSearchText = t.strings.legacy.msg_ai_search_use_ai_search;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _buildBodyScreen(
            data: _buildBodyData(
              searching: true,
              query: _buildQueryState(searchQuery: 'what to eat'),
            ),
            onStartAiSearch: () => aiSearchStarted = true,
          ),
        ),
      ),
    );

    expect(find.text(aiSearchText), findsOneWidget);

    await tester.tap(find.text(aiSearchText));
    expect(aiSearchStarted, isTrue);
  });

  testWidgets('keyword results show optional AI search action', (tester) async {
    var aiSearchStarted = false;
    final aiSearchText = t.strings.legacy.msg_ai_search_use_for_related_memos;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _buildBodyScreen(
            data: _buildBodyData(
              searching: true,
              query: _buildQueryState(searchQuery: 'what to eat'),
              visibleMemos: <LocalMemo>[_buildMemo('memo-1')],
            ),
            animatedItemBuilder: (_, index, _) => Text('memo item $index'),
            onStartAiSearch: () => aiSearchStarted = true,
          ),
        ),
      ),
    );

    expect(find.text(aiSearchText), findsOneWidget);

    await tester.tap(find.text(aiSearchText));
    expect(aiSearchStarted, isTrue);
  });

  testWidgets('AI empty state keeps keyword search recoverable', (
    tester,
  ) async {
    var aiSearchStopped = false;
    final noMatchesText = t.strings.legacy.msg_ai_search_no_matches;
    final backToKeywordText =
        t.strings.legacy.msg_ai_search_back_to_keyword_search;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _buildBodyScreen(
            data: _buildBodyData(
              searching: true,
              query: _buildQueryState(
                searchQuery: 'what to eat',
                useAiSearch: true,
              ),
            ),
            onStopAiSearch: () => aiSearchStopped = true,
          ),
        ),
      ),
    );

    expect(find.text(noMatchesText), findsOneWidget);
    expect(find.text(backToKeywordText), findsOneWidget);

    await tester.tap(find.text(backToKeywordText));
    expect(aiSearchStopped, isTrue);
  });

  testWidgets('AI results and configuration errors are labeled', (
    tester,
  ) async {
    final aiResultsText = t.strings.legacy.msg_ai_search_results_label;
    final keywordText = t.strings.legacy.msg_ai_search_keyword;
    final needsEmbeddingText =
        t.strings.legacy.msg_ai_search_needs_embedding_model;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _buildBodyScreen(
            data: _buildBodyData(
              searching: true,
              query: _buildQueryState(
                searchQuery: 'what to eat',
                useAiSearch: true,
              ),
              visibleMemos: <LocalMemo>[_buildMemo('memo-1')],
            ),
            animatedItemBuilder: (_, index, _) => Text('memo item $index'),
          ),
        ),
      ),
    );

    expect(find.text(aiResultsText), findsOneWidget);
    expect(find.text(keywordText), findsOneWidget);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _buildBodyScreen(
            data: _buildBodyData(
              searching: true,
              query: _buildQueryState(
                searchQuery: 'what to eat',
                useAiSearch: true,
              ),
              memosError: const AiSemanticMemoSearchConfigurationException(
                'missing embedding config',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(needsEmbeddingText), findsOneWidget);
  });

  testWidgets('AI search CTA follows active locale', (tester) async {
    LocaleSettings.setLocale(AppLocale.zhHans);
    final localizedAiSearchText = t.strings.legacy.msg_ai_search_use_ai_search;
    final englishAiSearchText =
        AppLocale.en.translations.strings.legacy.msg_ai_search_use_ai_search;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.zhHans.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _buildBodyScreen(
            data: _buildBodyData(
              searching: true,
              query: _buildQueryState(searchQuery: 'what to eat'),
            ),
          ),
        ),
      ),
    );

    expect(localizedAiSearchText, isNot(englishAiSearchText));
    expect(find.text(localizedAiSearchText), findsOneWidget);
    expect(find.text(englishAiSearchText), findsNothing);
  });

  test('AI search UI copy is not hard-coded in memo list UI', () {
    final source = [
      File('lib/features/memos/widgets/memos_list_screen_body.dart'),
      File('lib/features/memos/memos_list_screen.dart'),
    ].map((file) => file.readAsStringSync()).join('\n');
    final hardCodedPhrases = <String>[
      'AI search is looking for related memos',
      'Indexing, embedding, and ranking local notes for this query.',
      'AI search needs an embedding model',
      'AI search failed',
      'Configure an embedding model in AI settings, then try again.',
      'Back to keyword search',
      'No AI matches found',
      'Keyword search is still available for exact text matches.',
      'Try AI search to find semantically related memos.',
      'Use AI search',
      'AI semantic results',
      'Use AI search for related memos',
      'Build AI search index?',
      'AI search needs to index eligible memo chunks first.',
      'Estimated indexing tokens:',
      'Continue with AI search',
    ];

    for (final phrase in hardCodedPhrases) {
      expect(source, isNot(contains("'$phrase'")));
      expect(source, isNot(contains('"$phrase"')));
    }
  });
}

const _drawerSwipeMemoCardKey = ValueKey<String>('drawer-swipe-memo-card');

Future<void> _pumpBodyWithDrawerSwipeTarget(
  WidgetTester tester, {
  required GlobalKey<ScaffoldState> scaffoldKey,
  TargetPlatform platform = TargetPlatform.android,
  bool searching = false,
  bool useDesktopSidePane = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1000);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          locale: AppLocale.en.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(platform: platform),
          home: _buildBodyScreen(
            scaffoldKey: scaffoldKey,
            drawerPanel: const Drawer(
              child: Center(child: Text('drawer content')),
            ),
            data: _buildBodyData(
              searching: searching,
              visibleMemos: <LocalMemo>[_buildMemo('memo-1')],
              layout: _buildLayout(useDesktopSidePane: useDesktopSidePane),
            ),
            animatedItemBuilder: (_, _, _) => _buildDrawerSwipeMemoCard(
              onTap: onTap,
              onLongPress: onLongPress,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dragRightFromMemoCard(WidgetTester tester) async {
  final memoCard = find.byKey(_drawerSwipeMemoCardKey);
  expect(memoCard, findsOneWidget);

  final gesture = await tester.startGesture(tester.getCenter(memoCard));
  await gesture.moveBy(const Offset(32, 0));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Widget _buildDrawerSwipeMemoCard({
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppPressScale(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: _drawerSwipeMemoCardKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: const SizedBox(
            height: 160,
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('memo card content'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildBodyScreen({
  GlobalKey<ScaffoldState>? scaffoldKey,
  Widget? drawerPanel,
  MemosListScreenBodyData? data,
  MemosListAnimatedItemBuilder? animatedItemBuilder,
  ValueListenable<bool>? showBackToTopListenable,
  ValueListenable<MemosListFloatingCollapseState>? floatingCollapseListenable,
  VoidCallback? onStartAiSearch,
  VoidCallback? onStopAiSearch,
}) {
  final resolvedData = data ?? _buildBodyData();
  final resolvedShowBackToTopListenable =
      showBackToTopListenable ?? ValueNotifier<bool>(false);
  final resolvedFloatingCollapseListenable =
      floatingCollapseListenable ??
      ValueNotifier<MemosListFloatingCollapseState>(
        const MemosListFloatingCollapseState(memoUid: null, scrolling: false),
      );

  return MemosListScreenBody(
    scaffoldKey: scaffoldKey ?? GlobalKey<ScaffoldState>(),
    scrollController: ScrollController(),
    floatingCollapseViewportKey: GlobalKey(),
    listKey: GlobalKey<SliverAnimatedListState>(),
    data: resolvedData,
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
    desktopPreviewPane: null,
    desktopEditorModalSurface: null,
    desktopEditorModalVisible: false,
    desktopPreviewPaneWidth: 420,
    onDesktopPreviewPaneWidthChanged: null,
    floatingActionButton: null,
    onRefresh: () async {},
    onScrollNotification: (_) => false,
    onPointerSignal: (PointerSignalEvent _) {},
    showBackToTopListenable: resolvedShowBackToTopListenable,
    floatingCollapseListenable: resolvedFloatingCollapseListenable,
    onCloseSearch: () {},
    onOpenSearch: () {},
    onStartAiSearch: onStartAiSearch ?? () {},
    onStopAiSearch: onStopAiSearch ?? () {},
    onToggleWindowsHeaderSearch: () {},
    onToggleQuickSearchKind: (_) {},
    onDismissGuide: () {},
    onViewportLayoutChanged: () {},
    onCollapseFloatingMemo: () {},
    onScrollToTop: () {},
    quickActions: _buildQuickActions(),
    onMinimize: () {},
    onToggleMaximize: () {},
    onClose: () {},
    onEditTag: () async {},
    animatedItemBuilder:
        animatedItemBuilder ?? (_, _, _) => const SizedBox.shrink(),
  );
}

Future<void> _pumpBodyWithVisibleFloatingActions(
  WidgetTester tester, {
  required TargetPlatform platform,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1000);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final showBackToTop = ValueNotifier<bool>(true);
  final floatingCollapse = ValueNotifier<MemosListFloatingCollapseState>(
    const MemosListFloatingCollapseState(memoUid: 'memo-1', scrolling: false),
  );
  addTearDown(showBackToTop.dispose);
  addTearDown(floatingCollapse.dispose);

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(platform: platform),
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              disableAnimations: disableAnimations,
              accessibleNavigation: accessibleNavigation,
            ),
            child: child!,
          );
        },
        home: _buildBodyScreen(
          showBackToTopListenable: showBackToTop,
          floatingCollapseListenable: floatingCollapse,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _collapseButtonRect(WidgetTester tester) {
  return tester.getRect(find.byType(MemoFloatingCollapseButton));
}

MemosListScreenBodyData _buildBodyData({
  bool memosLoading = false,
  Object? memosError,
  List<LocalMemo> visibleMemos = const <LocalMemo>[],
  bool searching = false,
  MemosListScreenQueryState? query,
  MemosListScreenLayoutState? layout,
}) {
  final resolvedQuery = query ?? _buildQueryState();
  return MemosListScreenBodyData(
    viewState: MemosListScreenViewState(
      query: resolvedQuery,
      layout: layout ?? _buildLayout(),
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
    searching: searching,
    showFilterTagChip: false,
    enableSearch: false,
    enableTitleMenu: false,
    screenshotModeEnabled: false,
    windowsHeaderSearchExpanded: false,
    desktopWindowMaximized: false,
    debugApiVersionText: '',
    activeListGuideId: null,
    activeListGuideMessage: null,
    memosLoading: memosLoading,
    memosError: memosError,
    visibleMemos: visibleMemos,
    showLoadMoreHint: false,
    loadMoreHintDisplayText: '',
    loadMoreHintTextColor: Colors.black,
    headerBackgroundColor: Colors.white,
    bottomInset: 0,
    hapticsEnabled: false,
    desktopPreviewVisible: false,
    enableDrawerOpenDragGesture: true,
  );
}

MemosListScreenLayoutState _buildLayout({
  bool showHeaderPillActions = false,
  bool useDesktopSidePane = false,
  bool useWindowsDesktopHeader = false,
  bool useMacosDesktopTitleBar = false,
}) {
  return MemosListScreenLayoutState(
    showHeaderPillActions: showHeaderPillActions,
    listTopPadding: 0,
    listVisualOffset: 0,
    supportsDesktopSidePane: useDesktopSidePane,
    useDesktopSidePane: useDesktopSidePane,
    supportsDesktopPreviewPane: false,
    useDesktopPreviewPane: false,
    useInlineCompose: false,
    useWindowsDesktopHeader: useWindowsDesktopHeader,
    useMacosDesktopTitleBar: useMacosDesktopTitleBar,
    headerToolbarHeight: kToolbarHeight,
    headerBottomHeight: 0,
    floatingCollapseTopPadding: 0,
    showComposeFab: false,
    backToTopBaseOffset: 0,
  );
}

MemosListScreenQueryState _buildQueryState({
  String searchQuery = '',
  bool useAiSearch = false,
}) {
  final baseQuery = (
    searchQuery: searchQuery,
    state: 'NORMAL',
    tag: null,
    startTimeSec: null,
    endTimeSecExclusive: null,
    advancedFilters: AdvancedSearchFilters.empty,
    pageSize: 20,
  );
  final aiQuery = (
    searchQuery: searchQuery,
    state: 'NORMAL',
    tag: null,
    startTimeSec: null,
    endTimeSecExclusive: null,
    advancedFilters: AdvancedSearchFilters.empty,
    pageSize: 20,
  );
  return MemosListScreenQueryState(
    searchQuery: searchQuery,
    resolvedTag: null,
    advancedFilters: AdvancedSearchFilters.empty,
    selectedShortcut: null,
    shortcutFilter: '',
    useShortcutFilter: false,
    selectedQuickSearchKind: null,
    useQuickSearch: false,
    useAiSearch: useAiSearch,
    useRemoteSearch: searchQuery.trim().isNotEmpty && !useAiSearch,
    startTimeSec: null,
    endTimeSecExclusive: null,
    baseQuery: baseQuery,
    shortcutQuery: null,
    quickSearchQuery: null,
    aiSearchQuery: useAiSearch ? aiQuery : null,
    sourceKind: useAiSearch
        ? MemosListMemoSourceKind.aiSearch
        : searchQuery.trim().isNotEmpty
        ? MemosListMemoSourceKind.remoteSearch
        : MemosListMemoSourceKind.stream,
    queryKey: 'test-${useAiSearch ? 'ai' : 'keyword'}-$searchQuery',
    showSearchLanding: false,
    enableHomeSort: false,
  );
}

LocalMemo _buildMemo(String uid) {
  const content = 'memo content';
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: computeContentFingerprint(content),
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: DateTime.utc(2026, 3, 1),
    updateTime: DateTime.utc(2026, 3, 1, 1),
    tags: const <String>[],
    attachments: const <Attachment>[],
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
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
