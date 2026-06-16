import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/tags.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_sort_order.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';
import 'memos_list_desktop_presentation.dart';

enum MemosListSortOption { createAsc, createDesc, updateAsc, updateDesc }

extension MemosListSortOptionX on MemosListSortOption {
  MemoSortOrder toMemoSortOrder() {
    return switch (this) {
      MemosListSortOption.createAsc => MemoSortOrder.createAsc,
      MemosListSortOption.createDesc => MemoSortOrder.createDesc,
      MemosListSortOption.updateAsc => MemoSortOrder.updateAsc,
      MemosListSortOption.updateDesc => MemoSortOrder.updateDesc,
    };
  }
}

enum MemosListAdvancedSearchChipKind {
  createdDateRange,
  hasLocation,
  locationContains,
  hasAttachments,
  attachmentNameContains,
  attachmentType,
  hasRelations,
}

@immutable
class MemosListAdvancedSearchChipData {
  const MemosListAdvancedSearchChipData({
    required this.label,
    required this.kind,
  });

  final String label;
  final MemosListAdvancedSearchChipKind kind;
}

class MemosListHeaderController extends ChangeNotifier {
  MemosListHeaderController({
    TextEditingController? searchController,
    FocusNode? searchFocusNode,
    String? initialTag,
    String? initialShortcutId,
    QuickSearchKind? initialQuickSearchKind,
    bool initialAiSearchActive = false,
    AdvancedSearchFilters initialAdvancedSearchFilters =
        AdvancedSearchFilters.empty,
    MemosListSortOption initialSortOption = MemosListSortOption.createDesc,
    bool initialSearching = false,
    String? initialSubmittedSearchQuery,
    bool initialDesktopHeaderSearchExpanded = false,
  }) : _searchController = searchController ?? TextEditingController(),
       _ownsSearchController = searchController == null,
       _searchFocusNode = searchFocusNode ?? FocusNode(),
       _ownsSearchFocusNode = searchFocusNode == null,
       _searching = initialSearching,
       _submittedSearchQuery =
           (initialSubmittedSearchQuery ?? searchController?.text ?? '').trim(),
       _selectedShortcutId = initialShortcutId,
       _selectedQuickSearchKind = initialQuickSearchKind,
       _aiSearchActive = initialAiSearchActive,
       _advancedSearchFilters = initialAdvancedSearchFilters.normalized(),
       _activeTagFilter = normalizeTag(initialTag),
       _sortOption = initialSortOption,
       _desktopHeaderSearchExpanded = initialDesktopHeaderSearchExpanded {
    _searchController.addListener(_handleSearchTextChanged);
  }

  final TextEditingController _searchController;
  final bool _ownsSearchController;
  final FocusNode _searchFocusNode;
  final bool _ownsSearchFocusNode;

  bool _searching;
  String _submittedSearchQuery;
  String? _selectedShortcutId;
  QuickSearchKind? _selectedQuickSearchKind;
  bool _aiSearchActive;
  AdvancedSearchFilters _advancedSearchFilters;
  String? _activeTagFilter;
  MemosListSortOption _sortOption;
  bool _desktopHeaderSearchExpanded;

  TextEditingController get searchController => _searchController;
  FocusNode get searchFocusNode => _searchFocusNode;
  bool get searching => _searching;
  String get draftSearchQuery => _searchController.text;
  String get submittedSearchQuery => _submittedSearchQuery;
  String get normalizedDraftSearchQuery => _searchController.text.trim();
  String get normalizedSubmittedSearchQuery => _submittedSearchQuery.trim();
  bool get hasPendingSearchDraft {
    return normalizedDraftSearchQuery != normalizedSubmittedSearchQuery &&
        (normalizedDraftSearchQuery.isNotEmpty ||
            normalizedSubmittedSearchQuery.isNotEmpty);
  }

  bool get canSubmitSearch => normalizedDraftSearchQuery.isNotEmpty;
  String? get selectedShortcutId => _selectedShortcutId;
  QuickSearchKind? get selectedQuickSearchKind => _selectedQuickSearchKind;
  bool get aiSearchActive => _aiSearchActive;
  AdvancedSearchFilters get advancedSearchFilters => _advancedSearchFilters;
  String? get activeTagFilter => _activeTagFilter;
  MemosListSortOption get sortOption => _sortOption;
  MemoSortOrder get querySortOrder => _sortOption.toMemoSortOrder();
  bool get desktopHeaderSearchExpanded => _desktopHeaderSearchExpanded;
  bool get hasAdvancedSearchFilters => !_advancedSearchFilters.isEmpty;

  static String? normalizeTag(String? raw) {
    final normalized = normalizeTagPath(raw ?? '');
    if (normalized.isEmpty) return null;
    return normalized;
  }

  void syncExternalTag(String? tag) {
    final normalized = normalizeTag(tag);
    if (_activeTagFilter == normalized) return;
    _activeTagFilter = normalized;
    notifyListeners();
  }

  void selectTagFilter(String? tag) {
    final normalized = normalizeTag(tag);
    if (_activeTagFilter == normalized) return;
    _activeTagFilter = normalized;
    notifyListeners();
  }

  void selectShortcut(String? shortcutId, {bool clearQuickSearch = true}) {
    if (_selectedShortcutId == shortcutId &&
        (!clearQuickSearch || _selectedQuickSearchKind == null)) {
      return;
    }
    _selectedShortcutId = shortcutId;
    if (clearQuickSearch) {
      _selectedQuickSearchKind = null;
    }
    _aiSearchActive = false;
    notifyListeners();
  }

  void clearSelectedShortcut() {
    if (_selectedShortcutId == null) return;
    _selectedShortcutId = null;
    _aiSearchActive = false;
    notifyListeners();
  }

  void setAdvancedSearchFilters(AdvancedSearchFilters filters) {
    final normalized = filters.normalized();
    if (_advancedSearchFilters == normalized) return;
    _advancedSearchFilters = normalized;
    notifyListeners();
  }

  void clearAdvancedSearchFilters() {
    if (_advancedSearchFilters.isEmpty) return;
    _advancedSearchFilters = AdvancedSearchFilters.empty;
    notifyListeners();
  }

  void removeSingleAdvancedFilter(MemosListAdvancedSearchChipKind kind) {
    final next = switch (kind) {
      MemosListAdvancedSearchChipKind.createdDateRange =>
        _advancedSearchFilters.copyWith(createdDateRange: null),
      MemosListAdvancedSearchChipKind.hasLocation =>
        _advancedSearchFilters.copyWith(hasLocation: SearchToggleFilter.any),
      MemosListAdvancedSearchChipKind.locationContains =>
        _advancedSearchFilters.copyWith(locationContains: ''),
      MemosListAdvancedSearchChipKind.hasAttachments =>
        _advancedSearchFilters.copyWith(hasAttachments: SearchToggleFilter.any),
      MemosListAdvancedSearchChipKind.attachmentNameContains =>
        _advancedSearchFilters.copyWith(attachmentNameContains: ''),
      MemosListAdvancedSearchChipKind.attachmentType =>
        _advancedSearchFilters.copyWith(attachmentType: null),
      MemosListAdvancedSearchChipKind.hasRelations =>
        _advancedSearchFilters.copyWith(hasRelations: SearchToggleFilter.any),
    };
    setAdvancedSearchFilters(next);
  }

  void openSearch() {
    if (_searching) return;
    _searching = true;
    notifyListeners();
  }

  void openDesktopHeaderSearch() {
    if (_desktopHeaderSearchExpanded) {
      _searchFocusNode.requestFocus();
      return;
    }
    _desktopHeaderSearchExpanded = true;
    notifyListeners();
    _searchFocusNode.requestFocus();
  }

  void closeDesktopHeaderSearch({bool clearQuery = true}) {
    if (!_desktopHeaderSearchExpanded) return;
    _searchFocusNode.unfocus();
    if (clearQuery) {
      _setDraftSearchText('');
      _submittedSearchQuery = '';
    }
    _desktopHeaderSearchExpanded = false;
    _selectedQuickSearchKind = null;
    _aiSearchActive = false;
    if (clearQuery) {
      _advancedSearchFilters = AdvancedSearchFilters.empty;
    }
    notifyListeners();
  }

  void toggleDesktopHeaderSearch() {
    if (_desktopHeaderSearchExpanded) {
      closeDesktopHeaderSearch();
      return;
    }
    openDesktopHeaderSearch();
  }

  void closeSearch({required VoidCallback clearGlobalFocus}) {
    _searchFocusNode.unfocus();
    _setDraftSearchText('');
    clearGlobalFocus();
    _searching = false;
    _submittedSearchQuery = '';
    _desktopHeaderSearchExpanded = false;
    _selectedQuickSearchKind = null;
    _aiSearchActive = false;
    _advancedSearchFilters = AdvancedSearchFilters.empty;
    notifyListeners();
  }

  void submitSearch(
    String query, {
    required void Function(String query) addHistory,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    var changed = _setDraftSearchText(trimmed);
    if (_submittedSearchQuery != trimmed) {
      _submittedSearchQuery = trimmed;
      changed = true;
    }
    if (_aiSearchActive) {
      _aiSearchActive = false;
      changed = true;
    }
    addHistory(trimmed);
    if (changed) {
      notifyListeners();
    }
  }

  void applySearchQuery(
    String query, {
    required void Function(String query) addHistory,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    submitSearch(trimmed, addHistory: addHistory);
  }

  void toggleQuickSearchKind(QuickSearchKind kind) {
    final next = _selectedQuickSearchKind == kind ? null : kind;
    if (_selectedQuickSearchKind == next) return;
    _selectedQuickSearchKind = next;
    _aiSearchActive = false;
    notifyListeners();
  }

  void startAiSearch() {
    final trimmed = _submittedSearchQuery.trim();
    if (trimmed.isEmpty || _aiSearchActive) return;
    _aiSearchActive = true;
    _selectedQuickSearchKind = null;
    notifyListeners();
  }

  void stopAiSearch() {
    if (!_aiSearchActive) return;
    _aiSearchActive = false;
    notifyListeners();
  }

  void setSortOption(MemosListSortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    notifyListeners();
  }

  void focusSearchFromShortcut({
    required MemosListDesktopSearchPresentation searchPresentation,
    required VoidCallback onOpenSearch,
  }) {
    if (searchPresentation == MemosListDesktopSearchPresentation.header &&
        !_searching) {
      openDesktopHeaderSearch();
      return;
    }
    onOpenSearch();
  }

  String localizedToggleFilterLabel(
    BuildContext context,
    SearchToggleFilter value,
  ) {
    return switch (value) {
      SearchToggleFilter.any => context.t.strings.legacy.msg_any,
      SearchToggleFilter.yes => context.t.strings.legacy.msg_yes,
      SearchToggleFilter.no => context.t.strings.legacy.msg_no,
    };
  }

  String sortOptionLabel(BuildContext context, MemosListSortOption option) {
    return switch (option) {
      MemosListSortOption.createAsc =>
        context.t.strings.legacy.msg_created_time_2,
      MemosListSortOption.createDesc =>
        context.t.strings.legacy.msg_created_time,
      MemosListSortOption.updateAsc =>
        context.t.strings.legacy.msg_updated_time_2,
      MemosListSortOption.updateDesc =>
        context.t.strings.legacy.msg_updated_time,
    };
  }

  int compareMemos(LocalMemo a, LocalMemo b) {
    if (a.pinned != b.pinned) {
      return a.pinned ? -1 : 1;
    }

    int primary;
    switch (_sortOption) {
      case MemosListSortOption.createAsc:
        primary = a.createTime.compareTo(b.createTime);
        break;
      case MemosListSortOption.createDesc:
        primary = b.createTime.compareTo(a.createTime);
        break;
      case MemosListSortOption.updateAsc:
        primary = a.updateTime.compareTo(b.updateTime);
        break;
      case MemosListSortOption.updateDesc:
        primary = b.updateTime.compareTo(a.updateTime);
        break;
    }
    if (primary != 0) return primary;

    final fallback = b.createTime.compareTo(a.createTime);
    if (fallback != 0) return fallback;
    return a.uid.compareTo(b.uid);
  }

  List<LocalMemo> applyHomeSort(List<LocalMemo> memos) {
    if (memos.length < 2) return memos;
    final sorted = List<LocalMemo>.from(memos);
    sorted.sort(compareMemos);
    return sorted;
  }

  List<MemosListAdvancedSearchChipData> buildActiveAdvancedSearchChipData(
    BuildContext context, {
    required DateFormat dayDateFormat,
  }) {
    final filters = _advancedSearchFilters.normalized();
    if (filters.isEmpty) {
      return const <MemosListAdvancedSearchChipData>[];
    }

    final chips = <MemosListAdvancedSearchChipData>[];
    final createdDateRange = filters.createdDateRange;
    if (createdDateRange != null) {
      chips.add(
        MemosListAdvancedSearchChipData(
          label:
              '${context.t.strings.legacy.msg_date_range_2}: ${dayDateFormat.format(createdDateRange.start)} - ${dayDateFormat.format(createdDateRange.end)}',
          kind: MemosListAdvancedSearchChipKind.createdDateRange,
        ),
      );
    }
    if (filters.hasLocation != SearchToggleFilter.any &&
        (filters.hasLocation == SearchToggleFilter.no ||
            filters.locationContains.isEmpty)) {
      chips.add(
        MemosListAdvancedSearchChipData(
          label:
              '${context.t.strings.legacy.msg_location_2}: ${localizedToggleFilterLabel(context, filters.hasLocation)}',
          kind: MemosListAdvancedSearchChipKind.hasLocation,
        ),
      );
    }
    if (filters.locationContains.isNotEmpty) {
      chips.add(
        MemosListAdvancedSearchChipData(
          label:
              '${context.t.strings.legacy.msg_location_contains}: ${filters.locationContains}',
          kind: MemosListAdvancedSearchChipKind.locationContains,
        ),
      );
    }
    if (filters.hasAttachments != SearchToggleFilter.any &&
        (filters.hasAttachments == SearchToggleFilter.no ||
            (filters.attachmentNameContains.isEmpty &&
                filters.attachmentType == null))) {
      chips.add(
        MemosListAdvancedSearchChipData(
          label:
              '${context.t.strings.legacy.msg_attachments}: ${localizedToggleFilterLabel(context, filters.hasAttachments)}',
          kind: MemosListAdvancedSearchChipKind.hasAttachments,
        ),
      );
    }
    if (filters.attachmentNameContains.isNotEmpty) {
      chips.add(
        MemosListAdvancedSearchChipData(
          label:
              '${context.t.strings.legacy.msg_attachment_name_contains}: ${filters.attachmentNameContains}',
          kind: MemosListAdvancedSearchChipKind.attachmentNameContains,
        ),
      );
    }
    if (filters.attachmentType != null) {
      final typeLabel = switch (filters.attachmentType!) {
        AdvancedAttachmentType.image => context.t.strings.legacy.msg_image,
        AdvancedAttachmentType.audio => context.t.strings.legacy.msg_audio,
        AdvancedAttachmentType.document =>
          context.t.strings.legacy.msg_document,
        AdvancedAttachmentType.other => context.t.strings.legacy.msg_other,
      };
      chips.add(
        MemosListAdvancedSearchChipData(
          label: '${context.t.strings.legacy.msg_attachment_type}: $typeLabel',
          kind: MemosListAdvancedSearchChipKind.attachmentType,
        ),
      );
    }
    if (filters.hasRelations != SearchToggleFilter.any) {
      chips.add(
        MemosListAdvancedSearchChipData(
          label:
              '${context.t.strings.legacy.msg_linked_memos}: ${localizedToggleFilterLabel(context, filters.hasRelations)}',
          kind: MemosListAdvancedSearchChipKind.hasRelations,
        ),
      );
    }
    return chips;
  }

  void _handleSearchTextChanged() {
    var changed = false;
    if (normalizedDraftSearchQuery.isEmpty &&
        _submittedSearchQuery.isNotEmpty) {
      _submittedSearchQuery = '';
      changed = true;
    }
    if (_aiSearchActive) {
      _aiSearchActive = false;
      changed = true;
    }
    if (changed) {
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  bool _setDraftSearchText(String text) {
    final selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    if (_searchController.text == text) {
      if (_searchController.selection != selection) {
        _searchController.selection = selection;
      }
      return false;
    }
    _searchController.removeListener(_handleSearchTextChanged);
    _searchController.value = TextEditingValue(
      text: text,
      selection: selection,
    );
    _searchController.addListener(_handleSearchTextChanged);
    return true;
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchTextChanged);
    if (_ownsSearchFocusNode) {
      _searchFocusNode.dispose();
    }
    if (_ownsSearchController) {
      _searchController.dispose();
    }
    super.dispose();
  }
}
