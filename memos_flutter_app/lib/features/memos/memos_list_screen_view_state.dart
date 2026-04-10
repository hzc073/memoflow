import 'package:flutter/material.dart';

import '../../core/platform_layout.dart';
import '../../core/tag_colors.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/shortcut.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import '../../state/tags/tag_color_lookup.dart';

enum MemosListMemoSourceKind { stream, remoteSearch, quickSearch, shortcut }

@immutable
class MemosListScreenQueryState {
  const MemosListScreenQueryState({
    required this.searchQuery,
    required this.resolvedTag,
    required this.advancedFilters,
    required this.selectedShortcut,
    required this.shortcutFilter,
    required this.useShortcutFilter,
    required this.selectedQuickSearchKind,
    required this.useQuickSearch,
    required this.useRemoteSearch,
    required this.startTimeSec,
    required this.endTimeSecExclusive,
    required this.baseQuery,
    required this.shortcutQuery,
    required this.quickSearchQuery,
    required this.sourceKind,
    required this.queryKey,
    required this.showSearchLanding,
    required this.enableHomeSort,
  });

  final String searchQuery;
  final String? resolvedTag;
  final AdvancedSearchFilters advancedFilters;
  final Shortcut? selectedShortcut;
  final String shortcutFilter;
  final bool useShortcutFilter;
  final QuickSearchKind? selectedQuickSearchKind;
  final bool useQuickSearch;
  final bool useRemoteSearch;
  final int? startTimeSec;
  final int? endTimeSecExclusive;
  final MemosQuery baseQuery;
  final ShortcutMemosQuery? shortcutQuery;
  final QuickSearchMemosQuery? quickSearchQuery;
  final MemosListMemoSourceKind sourceKind;
  final String queryKey;
  final bool showSearchLanding;
  final bool enableHomeSort;
}

@immutable
class MemosListScreenLayoutState {
  const MemosListScreenLayoutState({
    required this.showHeaderPillActions,
    required this.listTopPadding,
    required this.listVisualOffset,
    required this.supportsDesktopSidePane,
    required this.useDesktopSidePane,
    required this.useInlineCompose,
    required this.useWindowsDesktopHeader,
    required this.headerToolbarHeight,
    required this.headerBottomHeight,
    required this.floatingCollapseTopPadding,
    required this.showComposeFab,
    required this.backToTopBaseOffset,
  });

  final bool showHeaderPillActions;
  final double listTopPadding;
  final double listVisualOffset;
  final bool supportsDesktopSidePane;
  final bool useDesktopSidePane;
  final bool useInlineCompose;
  final bool useWindowsDesktopHeader;
  final double headerToolbarHeight;
  final double headerBottomHeight;
  final double floatingCollapseTopPadding;
  final bool showComposeFab;
  final double backToTopBaseOffset;
}

@immutable
class MemosListScreenGuideState {
  const MemosListScreenGuideState({
    required this.canShowSearchShortcutGuide,
    required this.canShowDesktopShortcutGuide,
    required this.activeListGuideId,
  });

  final bool canShowSearchShortcutGuide;
  final bool canShowDesktopShortcutGuide;
  final SceneMicroGuideId? activeListGuideId;
}

@immutable
class MemosListScreenViewState {
  const MemosListScreenViewState({
    required this.query,
    required this.layout,
    required this.guide,
    required this.availableTemplates,
    required this.recommendedTags,
    required this.activeTagStat,
    required this.tagPresentationSignature,
  });

  final MemosListScreenQueryState query;
  final MemosListScreenLayoutState layout;
  final MemosListScreenGuideState guide;
  final List<MemoTemplate> availableTemplates;
  final List<TagStat> recommendedTags;
  final TagStat? activeTagStat;
  final String tagPresentationSignature;
}

MemosListScreenQueryState buildMemosListScreenQueryState({
  required String searchQuery,
  required DateTime? filterDay,
  required String state,
  required int pageSize,
  required List<Shortcut> shortcuts,
  required String? selectedShortcutId,
  required QuickSearchKind? selectedQuickSearchKind,
  required String? resolvedTag,
  required AdvancedSearchFilters advancedFilters,
  required bool searching,
  required bool showDrawer,
}) {
  final dayRange = filterDay == null ? null : _dayRangeSeconds(filterDay);
  final normalizedFilters = advancedFilters.normalized();
  final selectedShortcut = _findShortcutById(shortcuts, selectedShortcutId);
  final shortcutFilter = selectedShortcut?.filter ?? '';
  final useShortcutFilter = shortcutFilter.trim().isNotEmpty;
  final useQuickSearch =
      !useShortcutFilter && selectedQuickSearchKind != null;
  final trimmedSearchQuery = searchQuery.trim();
  final useRemoteSearch =
      !useShortcutFilter && !useQuickSearch && trimmedSearchQuery.isNotEmpty;
  final sourceKind = useShortcutFilter
      ? MemosListMemoSourceKind.shortcut
      : useQuickSearch
      ? MemosListMemoSourceKind.quickSearch
      : useRemoteSearch
      ? MemosListMemoSourceKind.remoteSearch
      : MemosListMemoSourceKind.stream;
  final baseQuery = (
    searchQuery: searchQuery,
    state: state,
    tag: resolvedTag,
    startTimeSec: dayRange?.startSec,
    endTimeSecExclusive: dayRange?.endSecExclusive,
    advancedFilters: normalizedFilters,
    pageSize: pageSize,
  );
  final shortcutQuery = selectedShortcut == null
      ? null
      : (
          searchQuery: searchQuery,
          state: state,
          tag: resolvedTag,
          shortcutFilter: shortcutFilter,
          startTimeSec: dayRange?.startSec,
          endTimeSecExclusive: dayRange?.endSecExclusive,
          advancedFilters: normalizedFilters,
          pageSize: pageSize,
        );
  final quickSearchQuery = selectedQuickSearchKind == null
      ? null
      : (
          kind: selectedQuickSearchKind,
          searchQuery: searchQuery,
          state: state,
          tag: resolvedTag,
          startTimeSec: dayRange?.startSec,
          endTimeSecExclusive: dayRange?.endSecExclusive,
          advancedFilters: normalizedFilters,
          pageSize: pageSize,
        );
  final queryKey =
      '$state|${resolvedTag ?? ''}|$trimmedSearchQuery|${shortcutFilter.trim()}|'
      '${dayRange?.startSec ?? ''}|${dayRange?.endSecExclusive ?? ''}|${useShortcutFilter ? 1 : 0}|'
      '${selectedQuickSearchKind?.name ?? ''}|${useQuickSearch ? 1 : 0}|'
      '${useRemoteSearch ? 1 : 0}|${normalizedFilters.signature}';
  final showSearchLanding =
      searching &&
      trimmedSearchQuery.isEmpty &&
      !useQuickSearch &&
      normalizedFilters.isEmpty;
  final enableHomeSort =
      !searching && !useRemoteSearch && state == 'NORMAL' && showDrawer;

  return MemosListScreenQueryState(
    searchQuery: searchQuery,
    resolvedTag: resolvedTag,
    advancedFilters: normalizedFilters,
    selectedShortcut: selectedShortcut,
    shortcutFilter: shortcutFilter,
    useShortcutFilter: useShortcutFilter,
    selectedQuickSearchKind: selectedQuickSearchKind,
    useQuickSearch: useQuickSearch,
    useRemoteSearch: useRemoteSearch,
    startTimeSec: dayRange?.startSec,
    endTimeSecExclusive: dayRange?.endSecExclusive,
    baseQuery: baseQuery,
    shortcutQuery: shortcutQuery,
    quickSearchQuery: quickSearchQuery,
    sourceKind: sourceKind,
    queryKey: queryKey,
    showSearchLanding: showSearchLanding,
    enableHomeSort: enableHomeSort,
  );
}

MemosListScreenLayoutState buildMemosListScreenLayoutState({
  required MemosListScreenQueryState query,
  required String state,
  required bool showDrawer,
  required bool showPillActions,
  required bool showFilterTagChip,
  required bool enableCompose,
  required bool hidePrimaryComposeFab,
  required bool searching,
  required double screenWidth,
  required bool isWindowsDesktop,
}) {
  final showHeaderPillActions = showPillActions && state == 'NORMAL';
  final listTopPadding = showHeaderPillActions ? 0.0 : 16.0;
  final listVisualOffset = showHeaderPillActions ? 6.0 : 0.0;
  final supportsDesktopSidePane =
      showDrawer && shouldUseDesktopSidePaneLayout(screenWidth);
  final useDesktopSidePane = supportsDesktopSidePane;
  final useInlineCompose =
      enableCompose &&
      !hidePrimaryComposeFab &&
      !searching &&
      shouldUseInlineComposeLayout(screenWidth);
  final useWindowsDesktopHeader = isWindowsDesktop;
  final headerToolbarHeight = useWindowsDesktopHeader && !searching
      ? 0.0
      : kToolbarHeight;
  final headerBottomHeight = useWindowsDesktopHeader && !searching
      ? 0.0
      : searching
      ? (query.useShortcutFilter ? 0.0 : 46.0)
      : (showHeaderPillActions
            ? 46.0
            : (showFilterTagChip &&
                      (query.resolvedTag?.trim().isNotEmpty ?? false)
                  ? 48.0
                  : 0.0));
  final floatingCollapseTopPadding =
      headerToolbarHeight +
      headerBottomHeight +
      listTopPadding +
      listVisualOffset +
      10;
  final showComposeFab =
      enableCompose &&
      !hidePrimaryComposeFab &&
      !searching &&
      !useInlineCompose;
  final backToTopBaseOffset = showComposeFab ? 104.0 : 24.0;

  return MemosListScreenLayoutState(
    showHeaderPillActions: showHeaderPillActions,
    listTopPadding: listTopPadding,
    listVisualOffset: listVisualOffset,
    supportsDesktopSidePane: supportsDesktopSidePane,
    useDesktopSidePane: useDesktopSidePane,
    useInlineCompose: useInlineCompose,
    useWindowsDesktopHeader: useWindowsDesktopHeader,
    headerToolbarHeight: headerToolbarHeight,
    headerBottomHeight: headerBottomHeight,
    floatingCollapseTopPadding: floatingCollapseTopPadding,
    showComposeFab: showComposeFab,
    backToTopBaseOffset: backToTopBaseOffset,
  );
}

MemosListScreenGuideState buildMemosListScreenGuideState({
  required bool isAllMemos,
  required bool enableSearch,
  required bool enableTitleMenu,
  required bool searching,
  required bool sessionHasAccount,
  required bool desktopShortcutEnabled,
  required bool hasVisibleMemos,
  required SceneMicroGuideState guideState,
  required SceneMicroGuideId? presentedListGuideId,
}) {
  final canShowSearchShortcutGuide =
      isAllMemos &&
      enableSearch &&
      enableTitleMenu &&
      !searching &&
      sessionHasAccount;
  final canShowDesktopShortcutGuide =
      desktopShortcutEnabled && isAllMemos && !searching;
  final activeListGuideId = _resolveListRouteGuide(
    guideState: guideState,
    presentedListGuideId: presentedListGuideId,
    hasVisibleMemos: hasVisibleMemos,
    canShowSearchShortcutGuide: canShowSearchShortcutGuide,
    canShowDesktopShortcutGuide: canShowDesktopShortcutGuide,
    searching: searching,
  );
  return MemosListScreenGuideState(
    canShowSearchShortcutGuide: canShowSearchShortcutGuide,
    canShowDesktopShortcutGuide: canShowDesktopShortcutGuide,
    activeListGuideId: activeListGuideId,
  );
}

MemosListScreenViewState buildMemosListScreenViewState({
  required MemosListScreenQueryState query,
  required MemosListScreenLayoutState layout,
  required MemosListScreenGuideState guide,
  required List<TagStat> tagStats,
  required TagColorLookup tagColorLookup,
  required MemoTemplateSettings templateSettings,
}) {
  final availableTemplates = templateSettings.enabled
      ? templateSettings.templates
      : const <MemoTemplate>[];
  final recommendedTags = [...tagStats]
    ..sort((left, right) {
      if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
      return right.count.compareTo(left.count);
    });
  final resolvedTag = query.resolvedTag;
  final activeTagStat = (resolvedTag ?? '').trim().isEmpty
      ? null
      : tagColorLookup.resolveTag(resolvedTag!.trim());
  final tagPresentationSignature = buildMemosListTagPresentationSignature(
    tagStats,
  );

  return MemosListScreenViewState(
    query: query,
    layout: layout,
    guide: guide,
    availableTemplates: availableTemplates,
    recommendedTags: recommendedTags,
    activeTagStat: activeTagStat,
    tagPresentationSignature: tagPresentationSignature,
  );
}

String buildMemosListTagPresentationSignature(List<TagStat> tagStats) {
  return tagStats
      .map(
        (tag) =>
            '${tag.path}|${tag.parentId ?? ''}|${tag.pinned ? 1 : 0}|${normalizeTagColorHex(tag.colorHex) ?? ''}',
      )
      .join(',');
}

Shortcut? _findShortcutById(List<Shortcut> shortcuts, String? selectedShortcutId) {
  final id = selectedShortcutId;
  if (id == null || id.isEmpty) return null;
  for (final shortcut in shortcuts) {
    if (shortcut.shortcutId == id) return shortcut;
  }
  return null;
}

bool _isListGuideEligible(
  SceneMicroGuideId id, {
  required SceneMicroGuideState guideState,
  required bool hasVisibleMemos,
  required bool canShowSearchShortcutGuide,
  required bool canShowDesktopShortcutGuide,
  required bool searching,
}) {
  if (!guideState.loaded || guideState.isSeen(id)) return false;
  switch (id) {
    case SceneMicroGuideId.desktopGlobalShortcuts:
      return canShowDesktopShortcutGuide;
    case SceneMicroGuideId.memoListSearchAndShortcuts:
      return canShowSearchShortcutGuide;
    case SceneMicroGuideId.memoListGestures:
      return !searching && hasVisibleMemos;
    case SceneMicroGuideId.memoEditorTagAutocomplete:
    case SceneMicroGuideId.attachmentGalleryControls:
      return false;
  }
}

SceneMicroGuideId? _resolveListRouteGuide({
  required SceneMicroGuideState guideState,
  required SceneMicroGuideId? presentedListGuideId,
  required bool hasVisibleMemos,
  required bool canShowSearchShortcutGuide,
  required bool canShowDesktopShortcutGuide,
  required bool searching,
}) {
  final presented = presentedListGuideId;
  if (presented != null) {
    return _isListGuideEligible(
          presented,
          guideState: guideState,
          hasVisibleMemos: hasVisibleMemos,
          canShowSearchShortcutGuide: canShowSearchShortcutGuide,
          canShowDesktopShortcutGuide: canShowDesktopShortcutGuide,
          searching: searching,
        )
        ? presented
        : null;
  }

  final candidates = <SceneMicroGuideId>[
    SceneMicroGuideId.desktopGlobalShortcuts,
    SceneMicroGuideId.memoListSearchAndShortcuts,
    SceneMicroGuideId.memoListGestures,
  ];
  for (final candidate in candidates) {
    if (_isListGuideEligible(
      candidate,
      guideState: guideState,
      hasVisibleMemos: hasVisibleMemos,
      canShowSearchShortcutGuide: canShowSearchShortcutGuide,
      canShowDesktopShortcutGuide: canShowDesktopShortcutGuide,
      searching: searching,
    )) {
      return candidate;
    }
  }
  return null;
}

({int startSec, int endSecExclusive}) _dayRangeSeconds(DateTime day) {
  final localDay = DateTime(day.year, day.month, day.day);
  final nextDay = localDay.add(const Duration(days: 1));
  return (
    startSec: localDay.toUtc().millisecondsSinceEpoch ~/ 1000,
    endSecExclusive: nextDay.toUtc().millisecondsSinceEpoch ~/ 1000,
  );
}
