import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/platform_layout.dart';
import 'package:memos_flutter_app/data/models/memo_template_settings.dart';
import 'package:memos_flutter_app/data/models/shortcut.dart';
import 'package:memos_flutter_app/data/repositories/scene_micro_guide_repository.dart';
import 'package:memos_flutter_app/features/memos/memos_list_desktop_presentation.dart';
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
        Shortcut(
          name: 's1',
          id: 'shortcut-1',
          title: 'S1',
          filter: 'tag in []',
        ),
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
    expect(state.useAiSearch, isFalse);
    expect(state.canOfferAiSearch, isTrue);
    expect(state.baseQuery.pageSize, 40);
  });

  test('pending draft does not replace submitted provider query', () {
    final state = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      draftSearchQuery: 'alpha beta',
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

    expect(state.searchQuery, 'alpha');
    expect(state.draftSearchQuery, 'alpha beta');
    expect(state.hasPendingSearchDraft, isTrue);
    expect(state.sourceKind, MemosListMemoSourceKind.remoteSearch);
    expect(state.baseQuery.searchQuery, 'alpha');
    expect(state.canOfferAiSearch, isTrue);
    expect(state.showSearchLanding, isFalse);
  });

  test('AI search source is only used after explicit activation', () {
    final keywordState = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      aiSearchActive: false,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );
    final aiState = buildMemosListScreenQueryState(
      searchQuery: 'alpha',
      filterDay: null,
      state: 'NORMAL',
      pageSize: 40,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: null,
      selectedQuickSearchKind: null,
      aiSearchActive: true,
      resolvedTag: null,
      advancedFilters: AdvancedSearchFilters.empty,
      searching: true,
      showDrawer: true,
    );

    expect(keywordState.sourceKind, MemosListMemoSourceKind.remoteSearch);
    expect(keywordState.useRemoteSearch, isTrue);
    expect(keywordState.canOfferAiSearch, isTrue);
    expect(keywordState.aiSearchQuery, isNull);

    expect(aiState.sourceKind, MemosListMemoSourceKind.aiSearch);
    expect(aiState.useAiSearch, isTrue);
    expect(aiState.useRemoteSearch, isFalse);
    expect(aiState.canOfferAiSearch, isFalse);
    expect(aiState.aiSearchQuery?.searchQuery, 'alpha');
    expect(aiState.enableHomeSort, isFalse);
    expect(aiState.queryKey, isNot(keywordState.queryKey));
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
    final landingWithDraftState = buildMemosListScreenQueryState(
      searchQuery: '',
      draftSearchQuery: 'alpha',
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
    expect(landingWithDraftState.showSearchLanding, isTrue);
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
      desktopPresentation: resolveMemosListDesktopPresentation(
        screenWidth: 1280,
        showDrawer: true,
        platform: TargetPlatform.windows,
      ),
      state: 'NORMAL',
      showDrawer: true,
      showPillActions: true,
      showFilterTagChip: true,
      enableCompose: true,
      hidePrimaryComposeFab: false,
      searching: false,
    );

    expect(layoutState.supportsDesktopSidePane, isTrue);
    expect(layoutState.useDesktopSidePane, isTrue);
    expect(layoutState.useInlineCompose, isTrue);
    expect(layoutState.showComposeFab, isFalse);
    expect(layoutState.showHeaderPillActions, isTrue);
    expect(layoutState.headerToolbarHeight, 0);
    expect(layoutState.headerBottomHeight, 0);
  });

  test(
    'desktop presentation model resolves platform-neutral memo semantics',
    () {
      final windows = resolveMemosListDesktopPresentation(
        screenWidth: 1360,
        showDrawer: true,
        platform: TargetPlatform.windows,
      );
      final macos = resolveMemosListDesktopPresentation(
        screenWidth: 1280,
        showDrawer: true,
        platform: TargetPlatform.macOS,
      );

      expect(windows.layoutTier, DesktopLayoutTier.wide);
      expect(windows.navigationMode, DesktopNavigationMode.expanded);
      expect(
        windows.titlebarStrategy,
        MemosListDesktopTitlebarStrategy.windowsCommandBar,
      );
      expect(
        windows.searchPresentation,
        MemosListDesktopSearchPresentation.standard,
      );
      expect(
        windows.composePresentation,
        MemosListDesktopComposePresentation.desktopSurface,
      );
      expect(windows.previewPanePolicy.defaultMemoClickOpensPreview, isTrue);
      expect(windows.inlineComposeCapability.supported, isTrue);

      expect(macos.layoutTier, DesktopLayoutTier.expanded);
      expect(macos.navigationMode, DesktopNavigationMode.expanded);
      expect(
        macos.titlebarStrategy,
        MemosListDesktopTitlebarStrategy.macosToolbar,
      );
      expect(
        macos.searchPresentation,
        MemosListDesktopSearchPresentation.standard,
      );
      expect(
        macos.composePresentation,
        MemosListDesktopComposePresentation.desktopSurface,
      );
      expect(macos.previewPanePolicy.supportsPane, isTrue);
      expect(macos.previewPanePolicy.defaultMemoClickOpensPreview, isFalse);
    },
  );

  test('macOS layout moves home pills into titlebar chrome', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final queryState = buildMemosListScreenQueryState(
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
    final layoutState = buildMemosListScreenLayoutState(
      query: queryState,
      desktopPresentation: resolveMemosListDesktopPresentation(
        screenWidth: 1280,
        showDrawer: true,
        platform: TargetPlatform.macOS,
      ),
      state: 'NORMAL',
      showDrawer: true,
      showPillActions: true,
      showFilterTagChip: false,
      enableCompose: true,
      hidePrimaryComposeFab: false,
      searching: false,
    );

    expect(layoutState.useMacosDesktopTitleBar, isTrue);
    expect(layoutState.useWindowsDesktopHeader, isFalse);
    expect(layoutState.showHeaderPillActions, isTrue);
    expect(layoutState.headerToolbarHeight, 0);
    expect(layoutState.headerBottomHeight, 0);
    expect(layoutState.listTopPadding, 16);
    expect(layoutState.listVisualOffset, 0);
  });

  test(
    'macOS desktop preview layout follows shared expanded and wide tiers',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final queryState = buildMemosListScreenQueryState(
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

      MemosListScreenLayoutState layoutFor(double width) {
        return buildMemosListScreenLayoutState(
          query: queryState,
          desktopPresentation: resolveMemosListDesktopPresentation(
            screenWidth: width,
            showDrawer: true,
            platform: TargetPlatform.macOS,
          ),
          state: 'NORMAL',
          showDrawer: true,
          showPillActions: true,
          showFilterTagChip: false,
          enableCompose: true,
          hidePrimaryComposeFab: false,
          searching: false,
        );
      }

      final compact = layoutFor(1199);
      final expanded = layoutFor(1200);
      final expandedHigh = layoutFor(1359);
      final wide = layoutFor(1360);

      expect(compact.supportsDesktopSidePane, isTrue);
      expect(compact.supportsDesktopPreviewPane, isFalse);
      expect(compact.useDesktopPreviewPane, isFalse);

      expect(expanded.supportsDesktopSidePane, isTrue);
      expect(expanded.supportsDesktopPreviewPane, isTrue);
      expect(expanded.useDesktopPreviewPane, isFalse);

      expect(expandedHigh.supportsDesktopPreviewPane, isTrue);
      expect(expandedHigh.useDesktopPreviewPane, isFalse);

      expect(wide.supportsDesktopPreviewPane, isTrue);
      expect(wide.useDesktopPreviewPane, isTrue);
    },
  );

  test('windows wide layout enables desktop preview pane at 1360', () {
    final queryState = buildMemosListScreenQueryState(
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
    final layoutState = buildMemosListScreenLayoutState(
      query: queryState,
      desktopPresentation: resolveMemosListDesktopPresentation(
        screenWidth: 1360,
        showDrawer: true,
        platform: TargetPlatform.windows,
      ),
      state: 'NORMAL',
      showDrawer: true,
      showPillActions: true,
      showFilterTagChip: true,
      enableCompose: true,
      hidePrimaryComposeFab: false,
      searching: false,
    );

    expect(layoutState.supportsDesktopPreviewPane, isTrue);
    expect(layoutState.useDesktopPreviewPane, isTrue);
  });

  test(
    'windows expanded layout supports pane without default preview mode',
    () {
      final queryState = buildMemosListScreenQueryState(
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
      final layoutState = buildMemosListScreenLayoutState(
        query: queryState,
        desktopPresentation: resolveMemosListDesktopPresentation(
          screenWidth: 1280,
          showDrawer: true,
          platform: TargetPlatform.windows,
        ),
        state: 'NORMAL',
        showDrawer: true,
        showPillActions: true,
        showFilterTagChip: true,
        enableCompose: true,
        hidePrimaryComposeFab: false,
        searching: false,
      );

      expect(layoutState.supportsDesktopPreviewPane, isTrue);
      expect(layoutState.useDesktopPreviewPane, isFalse);
    },
  );

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

  test(
    'local filter chip can reserve header space without a tag route chip',
    () {
      final queryState = buildMemosListScreenQueryState(
        searchQuery: '',
        filterDay: DateTime(2026, 6, 7),
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
      final layoutState = buildMemosListScreenLayoutState(
        query: queryState,
        desktopPresentation: resolveMemosListDesktopPresentation(
          screenWidth: 720,
          showDrawer: true,
          platform: TargetPlatform.android,
        ),
        state: 'NORMAL',
        showDrawer: true,
        showPillActions: false,
        showFilterTagChip: false,
        hasFilterChip: true,
        enableCompose: true,
        hidePrimaryComposeFab: false,
        searching: false,
      );

      expect(layoutState.headerBottomHeight, 48);
    },
  );

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
      desktopPresentation: resolveMemosListDesktopPresentation(
        screenWidth: 720,
        showDrawer: true,
        platform: TargetPlatform.android,
      ),
      state: 'NORMAL',
      showDrawer: true,
      showPillActions: false,
      showFilterTagChip: true,
      enableCompose: true,
      hidePrimaryComposeFab: false,
      searching: false,
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
    expect(
      viewState.guide.activeListGuideId,
      SceneMicroGuideId.memoListGestures,
    );
  });
}
