import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/tags.dart';
import '../../data/models/local_memo.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';

enum MemosListSortOption { createAsc, createDesc, updateAsc, updateDesc }

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
    AdvancedSearchFilters initialAdvancedSearchFilters =
        AdvancedSearchFilters.empty,
    MemosListSortOption initialSortOption = MemosListSortOption.createDesc,
    bool initialSearching = false,
    bool initialWindowsHeaderSearchExpanded = false,
  }) : _searchController = searchController ?? TextEditingController(),
       _searchFocusNode = searchFocusNode ?? FocusNode(),
       _searching = initialSearching,
       _selectedShortcutId = initialShortcutId,
       _selectedQuickSearchKind = initialQuickSearchKind,
       _advancedSearchFilters = initialAdvancedSearchFilters.normalized(),
       _activeTagFilter = normalizeTag(initialTag),
       _sortOption = initialSortOption,
       _windowsHeaderSearchExpanded = initialWindowsHeaderSearchExpanded {
    _searchController.addListener(_handleSearchTextChanged);
  }

  final TextEditingController _searchController;
  final FocusNode _searchFocusNode;

  bool _searching;
  String? _selectedShortcutId;
  QuickSearchKind? _selectedQuickSearchKind;
  AdvancedSearchFilters _advancedSearchFilters;
  String? _activeTagFilter;
  MemosListSortOption _sortOption;
  bool _windowsHeaderSearchExpanded;

  TextEditingController get searchController => _searchController;
  FocusNode get searchFocusNode => _searchFocusNode;
  bool get searching => _searching;
  String? get selectedShortcutId => _selectedShortcutId;
  QuickSearchKind? get selectedQuickSearchKind => _selectedQuickSearchKind;
  AdvancedSearchFilters get advancedSearchFilters => _advancedSearchFilters;
  String? get activeTagFilter => _activeTagFilter;
  MemosListSortOption get sortOption => _sortOption;
  bool get windowsHeaderSearchExpanded => _windowsHeaderSearchExpanded;
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
    notifyListeners();
  }

  void clearSelectedShortcut() {
    if (_selectedShortcutId == null) return;
    _selectedShortcutId = null;
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

  void openWindowsHeaderSearch() {
    if (_windowsHeaderSearchExpanded) {
      _searchFocusNode.requestFocus();
      return;
    }
    _windowsHeaderSearchExpanded = true;
    notifyListeners();
    _searchFocusNode.requestFocus();
  }

  void closeWindowsHeaderSearch({bool clearQuery = true}) {
    if (!_windowsHeaderSearchExpanded) return;
    _searchFocusNode.unfocus();
    if (clearQuery) {
      _searchController.clear();
    }
    _windowsHeaderSearchExpanded = false;
    _selectedQuickSearchKind = null;
    if (clearQuery) {
      _advancedSearchFilters = AdvancedSearchFilters.empty;
    }
    notifyListeners();
  }

  void toggleWindowsHeaderSearch() {
    if (_windowsHeaderSearchExpanded) {
      closeWindowsHeaderSearch();
      return;
    }
    openWindowsHeaderSearch();
  }

  void closeSearch({required VoidCallback clearGlobalFocus}) {
    _searchFocusNode.unfocus();
    _searchController.clear();
    clearGlobalFocus();
    _searching = false;
    _windowsHeaderSearchExpanded = false;
    _selectedQuickSearchKind = null;
    _advancedSearchFilters = AdvancedSearchFilters.empty;
    notifyListeners();
  }

  void submitSearch(
    String query, {
    required void Function(String query) addHistory,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    addHistory(trimmed);
  }

  void applySearchQuery(
    String query, {
    required void Function(String query) addHistory,
  }) {
    final trimmed = query.trim();
    _searchController.text = trimmed;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    notifyListeners();
    submitSearch(trimmed, addHistory: addHistory);
  }

  void toggleQuickSearchKind(QuickSearchKind kind) {
    final next = _selectedQuickSearchKind == kind ? null : kind;
    if (_selectedQuickSearchKind == next) return;
    _selectedQuickSearchKind = next;
    notifyListeners();
  }

  void setSortOption(MemosListSortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    notifyListeners();
  }

  void focusSearchFromShortcut({
    required bool isWindowsDesktop,
    required VoidCallback onOpenSearch,
  }) {
    if (isWindowsDesktop && !_searching) {
      openWindowsHeaderSearch();
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
    notifyListeners();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchTextChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
