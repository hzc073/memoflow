import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/features/memos/memos_list_header_controller.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';

void main() {
  test('syncExternalTag normalizes incoming tag path', () {
    final controller = MemosListHeaderController(initialTag: '#Old');
    addTearDown(controller.dispose);

    controller.syncExternalTag('  #Work / Sub  ');

    expect(controller.activeTagFilter, 'work/sub');
  });

  test('toggleQuickSearchKind clears repeated selection', () {
    final controller = MemosListHeaderController();
    addTearDown(controller.dispose);

    controller.toggleQuickSearchKind(QuickSearchKind.attachments);
    expect(controller.selectedQuickSearchKind, QuickSearchKind.attachments);

    controller.toggleQuickSearchKind(QuickSearchKind.attachments);
    expect(controller.selectedQuickSearchKind, isNull);
  });

  test('closeWindowsHeaderSearch clears query quick search and filters', () {
    final controller = MemosListHeaderController(
      initialAdvancedSearchFilters: const AdvancedSearchFilters(
        locationContains: 'Paris',
      ),
      initialQuickSearchKind: QuickSearchKind.voice,
      initialWindowsHeaderSearchExpanded: true,
    );
    addTearDown(controller.dispose);
    controller.searchController.text = 'memo';

    controller.closeWindowsHeaderSearch();

    expect(controller.windowsHeaderSearchExpanded, isFalse);
    expect(controller.searchController.text, isEmpty);
    expect(controller.selectedQuickSearchKind, isNull);
    expect(controller.advancedSearchFilters, AdvancedSearchFilters.empty);
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
    expect(
      controller.searchController.selection.baseOffset,
      'alpha beta'.length,
    );
    expect(addedQuery, 'alpha beta');
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
