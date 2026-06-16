import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/features/memos/memos_list_desktop_presentation.dart';
import 'package:memos_flutter_app/features/memos/memos_list_header_controller.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  test('syncExternalTag preserves incoming tag path case', () {
    final controller = MemosListHeaderController(initialTag: '#Old');
    addTearDown(controller.dispose);

    controller.syncExternalTag('  #Work / Sub  ');

    expect(controller.activeTagFilter, 'Work/Sub');
  });

  test('toggleQuickSearchKind clears repeated selection', () {
    final controller = MemosListHeaderController();
    addTearDown(controller.dispose);

    controller.toggleQuickSearchKind(QuickSearchKind.attachments);
    expect(controller.selectedQuickSearchKind, QuickSearchKind.attachments);

    controller.toggleQuickSearchKind(QuickSearchKind.attachments);
    expect(controller.selectedQuickSearchKind, isNull);
  });

  test('AI search activation is explicit and clears on query mode changes', () {
    final controller = MemosListHeaderController(
      initialQuickSearchKind: QuickSearchKind.links,
    );
    addTearDown(controller.dispose);

    controller.submitSearch('what to eat', addHistory: (_) {});
    controller.startAiSearch();

    expect(controller.aiSearchActive, isTrue);
    expect(controller.selectedQuickSearchKind, isNull);

    controller.toggleQuickSearchKind(QuickSearchKind.voice);
    expect(controller.aiSearchActive, isFalse);

    controller.startAiSearch();
    expect(controller.aiSearchActive, isTrue);

    controller.searchController.text = 'what to cook';
    expect(controller.aiSearchActive, isFalse);

    controller.startAiSearch();
    expect(controller.aiSearchActive, isTrue);
  });

  test('closeDesktopHeaderSearch clears query quick search and filters', () {
    final controller = MemosListHeaderController(
      initialAdvancedSearchFilters: const AdvancedSearchFilters(
        locationContains: 'Paris',
      ),
      initialQuickSearchKind: QuickSearchKind.voice,
      initialDesktopHeaderSearchExpanded: true,
    );
    addTearDown(controller.dispose);
    controller.submitSearch('memo', addHistory: (_) {});

    controller.closeDesktopHeaderSearch();

    expect(controller.desktopHeaderSearchExpanded, isFalse);
    expect(controller.searchController.text, isEmpty);
    expect(controller.submittedSearchQuery, isEmpty);
    expect(controller.selectedQuickSearchKind, isNull);
    expect(controller.advancedSearchFilters, AdvancedSearchFilters.empty);
  });

  test('focusSearchFromShortcut uses semantic desktop header presentation', () {
    final controller = MemosListHeaderController();
    addTearDown(controller.dispose);
    var openSearchCount = 0;

    controller.focusSearchFromShortcut(
      searchPresentation: MemosListDesktopSearchPresentation.header,
      onOpenSearch: () => openSearchCount++,
    );

    expect(controller.desktopHeaderSearchExpanded, isTrue);
    expect(openSearchCount, 0);

    controller.closeDesktopHeaderSearch();
    controller.focusSearchFromShortcut(
      searchPresentation: MemosListDesktopSearchPresentation.standard,
      onOpenSearch: () => openSearchCount++,
    );

    expect(openSearchCount, 1);
  });

  test('applySearchQuery trims text and records search history', () {
    final controller = MemosListHeaderController();
    addTearDown(controller.dispose);
    String? addedQuery;

    controller.applySearchQuery(
      '  alpha beta  ',
      addHistory: (query) => addedQuery = query,
    );

    expect(controller.searchController.text, 'alpha beta');
    expect(controller.submittedSearchQuery, 'alpha beta');
    expect(
      controller.searchController.selection.baseOffset,
      'alpha beta'.length,
    );
    expect(addedQuery, 'alpha beta');
  });

  test('typing updates draft without changing submitted query', () {
    final controller = MemosListHeaderController();
    addTearDown(controller.dispose);
    final history = <String>[];

    controller.submitSearch('  alpha  ', addHistory: history.add);
    controller.searchController.text = 'alpha beta';

    expect(controller.draftSearchQuery, 'alpha beta');
    expect(controller.submittedSearchQuery, 'alpha');
    expect(controller.hasPendingSearchDraft, isTrue);
    expect(history, <String>['alpha']);
  });

  test('clearing draft resets submitted query to unsearched state', () {
    final controller = MemosListHeaderController();
    addTearDown(controller.dispose);

    controller.submitSearch('alpha', addHistory: (_) {});
    controller.startAiSearch();
    expect(controller.submittedSearchQuery, 'alpha');
    expect(controller.aiSearchActive, isTrue);

    controller.searchController.clear();

    expect(controller.draftSearchQuery, isEmpty);
    expect(controller.submittedSearchQuery, isEmpty);
    expect(controller.aiSearchActive, isFalse);
    expect(controller.hasPendingSearchDraft, isFalse);
  });

  test('closeSearch clears draft submitted query modes and filters', () {
    final controller = MemosListHeaderController(
      initialAdvancedSearchFilters: const AdvancedSearchFilters(
        attachmentNameContains: 'voice',
      ),
      initialQuickSearchKind: QuickSearchKind.attachments,
      initialSearching: true,
    );
    addTearDown(controller.dispose);

    controller.submitSearch('memo', addHistory: (_) {});
    controller.startAiSearch();

    controller.closeSearch(clearGlobalFocus: () {});

    expect(controller.searching, isFalse);
    expect(controller.draftSearchQuery, isEmpty);
    expect(controller.submittedSearchQuery, isEmpty);
    expect(controller.selectedQuickSearchKind, isNull);
    expect(controller.aiSearchActive, isFalse);
    expect(controller.advancedSearchFilters, AdvancedSearchFilters.empty);
  });

  test('applyHomeSort keeps pinned memos first and sorts by option', () {
    final controller = MemosListHeaderController(
      initialSortOption: MemosListSortOption.updateAsc,
    );
    addTearDown(controller.dispose);
    final pinned = _buildMemo(
      uid: 'memo-pinned',
      pinned: true,
      createTime: DateTime.utc(2025, 1, 3),
      updateTime: DateTime.utc(2025, 1, 3, 1),
    );
    final oldest = _buildMemo(
      uid: 'memo-oldest',
      createTime: DateTime.utc(2025, 1, 1),
      updateTime: DateTime.utc(2025, 1, 1, 1),
    );
    final newest = _buildMemo(
      uid: 'memo-newest',
      createTime: DateTime.utc(2025, 1, 2),
      updateTime: DateTime.utc(2025, 1, 2, 1),
    );

    final sorted = controller.applyHomeSort(<LocalMemo>[
      newest,
      oldest,
      pinned,
    ]);

    expect(sorted.map((memo) => memo.uid), <String>[
      'memo-pinned',
      'memo-oldest',
      'memo-newest',
    ]);
  });

  test('removeSingleAdvancedFilter only clears requested filter', () {
    final controller = MemosListHeaderController(
      initialAdvancedSearchFilters: AdvancedSearchFilters(
        hasLocation: SearchToggleFilter.yes,
        locationContains: 'Paris',
        hasAttachments: SearchToggleFilter.yes,
        attachmentNameContains: 'voice',
      ),
    );
    addTearDown(controller.dispose);

    controller.removeSingleAdvancedFilter(
      MemosListAdvancedSearchChipKind.locationContains,
    );

    expect(controller.advancedSearchFilters.locationContains, isEmpty);
    expect(controller.advancedSearchFilters.attachmentNameContains, 'voice');
    expect(
      controller.advancedSearchFilters.hasAttachments,
      SearchToggleFilter.yes,
    );
  });

  test('dispose does not own injected controller and focus node', () {
    final searchController = TextEditingController(text: 'memo');
    final focusNode = FocusNode();
    final controller = MemosListHeaderController(
      searchController: searchController,
      searchFocusNode: focusNode,
    );

    controller.dispose();

    expect(() => searchController.text = 'after dispose', returnsNormally);
    expect(() => focusNode.addListener(() {}), returnsNormally);

    focusNode.dispose();
    searchController.dispose();
  });
}

LocalMemo _buildMemo({
  required String uid,
  bool pinned = false,
  DateTime? createTime,
  DateTime? updateTime,
}) {
  const content = 'memo content';
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: computeContentFingerprint(content),
    visibility: 'PRIVATE',
    pinned: pinned,
    state: 'NORMAL',
    createTime: createTime ?? DateTime.utc(2025, 1, 1),
    updateTime: updateTime ?? DateTime.utc(2025, 1, 1, 1),
    tags: const <String>[],
    attachments: const <Attachment>[],
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
  );
}
