import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/data/models/shortcut.dart';
import 'package:memos_flutter_app/data/repositories/scene_micro_guide_repository.dart';
import 'package:memos_flutter_app/features/memos/memos_list_screen_view_state.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/system/scene_micro_guide_provider.dart';
import 'package:memos_flutter_app/state/tags/tag_color_lookup.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('shortcut source has highest priority', () {
    final state = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[
        Shortcut(name: 's1', id: 'shortcut-1', title: 'S1', filter: 'tag in []'),
      ],
      selectedShortcutId: 'shortcut-1',
      selectedQuickSearchKind: QuickSearchKind.voice,
      resolvedTag: 'work',
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );

    expect(state.sourceKind, MemosListMemoSourceKind.shortcut);
    expect(state.useShortcutFilter, isTrue);
    expect(state.useQuickSearch, isFalse);
    expect(state.useRemoteSearch, isFalse);
    expect(state.shortcutQuery, isNotNull);
    expect(state.quickSearchQuery, isNotNull);
  });

  test('quick search source wins when no shortcut filter', () {
    final state = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: QuickSearchKind.links,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );

    expect(state.sourceKind, MemosListMemoSourceKind.quickSearch);
    expect(state.useShortcutFilter, isFalse);
    expect(state.useQuickSearch, isTrue);
    expect(state.useRemoteSearch, isFalse);
    expect(state.quickSearchQuery, isNotNull);
    expect(state.quickSearchQuery!.kind, QuickSearchKind.links);
  });

  test('remote search source is used for non-empty search query', () {
    final state = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: false,
      showDrawer: true,
    );

    expect(state.sourceKind, MemosListMemoSourceKind.remoteSearch);
    expect(state.useRemoteSearch, isTrue);
    expect(state.baseQuery.pageSize, 40);
  });

  test('stream source is used when no higher-priority query mode applies', () {
    final state = buildMemosListScreenQueryState(
      searchQuery: '   ',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: false,
      showDrawer: true,
    );

    expect(state.sourceKind, MemosListMemoSourceKind.stream);
    expect(state.useShortcutFilter, isFalse);
    expect(state.useQuickSearch, isFalse);
    expect(state.useRemoteSearch, isFalse);
  });

  test('query key changes with advanced filters and day range', () {
    final baseState = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: 'work',
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );
    final nextState = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: DateTime(2024, 3, 4),
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: 'work',
      advancedFilters: AdvancedSearchFilters(
        hasAttachments: SearchToggleFilter.yes,
        createdDateRange: DateTimeRange(
          start: DateTime(2024, 3, 1),
          end: DateTime(2024, 3, 2),
        ),
      ),
      searching: true,
      showDrawer: true,
    );

    expect(baseState.queryKey, isNot(nextState.queryKey));
    expect(nextState.startTimeSec, isNotNull);
    expect(nextState.endTimeSecExclusive, isNotNull);
  });

  test('showSearchLanding only appears for empty interactive search', () {
    final landingState = buildMemosListScreenQueryState(
      searchQuery: '   ',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );
    final noLandingState = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );

    expect(landingState.showSearchLanding, isTrue);
    expect(noLandingState.showSearchLanding, isFalse);
  });

  test('enableHomeSort follows search, remote, state and drawer flags', () {
    final enabled = buildMemosListScreenQueryState(
      searchQuery: '',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: false,
      showDrawer: true,
    );
    final disabledBySearch = buildMemosListScreenQueryState(
      searchQuery: '',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );
    final disabledByRemote = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: false,
      showDrawer: true,
    );
    final disabledByState = buildMemosListScreenQueryState(
      searchQuery: '',
      filterDay: null,
      state: 'ARCHIVED',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: false,
      showDrawer: true,
    );

    expect(enabled.enableHomeSort, isTrue);
    expect(disabledBySearch.enableHomeSort, isFalse);
    expect(disabledByRemote.enableHomeSort, isFalse);
    expect(disabledByState.enableHomeSort, isFalse);
  });

  test('layout state derives desktop pane, inline compose and fab flags', () {
    final queryState = buildMemosListScreenQueryState(
      searchQuery: '',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: 'work',
      advancedFilters: AdvancedSearchFilters.empty,
      searching: false,
      showDrawer: true,
    );
    final layoutState = buildMemosListScreenLayoutState(
      query: queryState,
      state: 'NORMAL',
      showDrawer: true,
      showPillActions: true,
      showFilterTagChip: true,
      enableCompose: true,
      hidePrimaryComposeFab: false,
      searching: false,
      screenWidth: 1280,
      isWindowsDesktop: true,
    );

    expect(layoutState.supportsDesktopSidePane, isTrue);
    expect(layoutState.useDesktopSidePane, isTrue);
    expect(layoutState.useInlineCompose, isTrue);
    expect(layoutState.showComposeFab, isFalse);
    expect(layoutState.showHeaderPillActions, isTrue);
    expect(layoutState.headerToolbarHeight, 0);
    expect(layoutState.headerBottomHeight, 0);
  });

  test('guide state follows candidate order and visibility rules', () {
    final guideState = buildMemosListScreenGuideState(
      isAllMemos: true,
      enableSearch: true,
      enableTitleMenu: true,
      searching: false,
      sessionHasAccount: true,
      desktopShortcutEnabled: true,
      hasVisibleMemos: true,
      guideState: const SceneMicroGuideState(
        loaded: true,
        seen: <SceneMicroGuideId>{},
      ),
      presentedListGuideId: null,
    );

    expect(guideState.canShowSearchShortcutGuide, isTrue);
    expect(guideState.canShowDesktopShortcutGuide, isTrue);
    expect(
      guideState.activeListGuideId,
      SceneMicroGuideId.desktopGlobalShortcuts,
    );
  });

  test('view state aggregates templates, recommended tags and active tag', () {
    final queryState = buildMemosListScreenQueryState(
      searchQuery: '',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      resolvedTag: 'beta',
      advancedFilters: AdvancedSearchFilters.empty,
      searching: false,
      showDrawer: true,
    );
    final layoutState = buildMemosListScreenLayoutState(
      query: queryState,
      state: 'NORMAL',
      showDrawer: true,
      showPillActions: false,
      showFilterTagChip: true,
      enableCompose: true,
      hidePrimaryComposeFab: false,
      searching: false,
      screenWidth: 720,
      isWindowsDesktop: false,
    );
    final guideState = buildMemosListScreenGuideState(
      isAllMemos: true,
      enableSearch: true,
      enableTitleMenu: true,
      searching: false,
      sessionHasAccount: true,
      desktopShortcutEnabled: false,
      hasVisibleMemos: true,
      guideState: const SceneMicroGuideState(
        loaded: true,
        seen: <SceneMicroGuideId>{
          SceneMicroGuideId.desktopGlobalShortcuts,
          SceneMicroGuideId.memoListSearchAndShortcuts,
        },
      ),
      presentedListGuideId: null,
    );
    final templates = const <MemoTemplate>[
      MemoTemplate(id: 't1', name: 'Daily', content: 'daily content'),
    ];
    final tagStats = const <TagStat>[
      TagStat(tag: 'alpha', path: 'alpha', count: 3),
      TagStat(
        tag: 'beta',
        path: 'beta',
        count: 1,
        pinned: true,
        tagId: 9,
        colorHex: '#FF0000',
      ),
      TagStat(tag: 'gamma', path: 'gamma', count: 5),
    ];
    final viewState = buildMemosListScreenViewState(
      query: queryState,
      layout: layoutState,
      guide: guideState,
      tagStats: tagStats,
      tagColorLookup: TagColorLookup(tagStats),
      templateSettings: MemoTemplateSettings(
        enabled: true,
        templates: templates,
        variables: MemoTemplateVariableSettings.defaults,
      ),
    );

    expect(viewState.availableTemplates, templates);
    expect(viewState.recommendedTags.first.tag, 'beta');
    expect(viewState.recommendedTags[1].tag, 'gamma');
    expect(viewState.activeTagStat?.tag, 'beta');
    expect(viewState.tagPresentationSignature, contains('beta|'));
    expect(viewState.guide.activeListGuideId, SceneMicroGuideId.memoListGestures);
  });
}
