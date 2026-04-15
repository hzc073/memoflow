import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/local_memo.dart';
import '../../data/models/memo_collection.dart';
import '../../data/repositories/collections_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collection_resolver.dart';
import '../../state/collections/collections_provider.dart';
import 'collection_ui.dart';

class ManualCollectionManageScreen extends ConsumerStatefulWidget {
  const ManualCollectionManageScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<ManualCollectionManageScreen> createState() =>
      _ManualCollectionManageScreenState();
}

class _ManualCollectionManageScreenState
    extends ConsumerState<ManualCollectionManageScreen> {
  Future<void> _openAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _ManualCollectionAddMemosSheet(collectionId: widget.collectionId),
    );
  }

  Future<void> _removeMemo(String memoUid) async {
    await ref.read(collectionsRepositoryProvider).removeManualItem(
      widget.collectionId,
      <String>[memoUid],
    );
  }

  Future<void> _reorder(
    List<LocalMemo> items,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = items.map((item) => item.uid).toList(growable: true);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await ref
        .read(collectionsRepositoryProvider)
        .reorderManualItems(widget.collectionId, reordered);
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.t.strings.collections;
    final collectionAsync = ref.watch(
      collectionByIdProvider(widget.collectionId),
    );
    final manualItemUidsAsync = ref.watch(
      collectionManualItemUidsProvider(widget.collectionId),
    );
    final candidateMemosAsync = ref.watch(collectionCandidateMemosProvider);

    return Scaffold(
      appBar: AppBar(
        title: collectionAsync.when(
          data: (collection) =>
              Text(collection?.title ?? collections.manageItems),
          error: (_, _) => Text(collections.manageItems),
          loading: () => Text(collections.manageItems),
        ),
        actions: [
          IconButton(
            tooltip: collections.addMemos,
            onPressed: _openAddSheet,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
        ],
      ),
      body: switch ((
        collectionAsync,
        manualItemUidsAsync,
        candidateMemosAsync,
      )) {
        (
          AsyncData<MemoCollection?> collectionValue,
          AsyncData<List<String>> manualItemUidsValue,
          AsyncData<List<LocalMemo>> candidateMemosValue,
        ) =>
          _buildLoaded(
            collectionValue.value,
            resolveManualCollectionItemsInStoredOrder(
              candidateMemosValue.value,
              manualItemUidsValue.value,
            ),
          ),
        (AsyncError(error: final error, stackTrace: _), _, _) =>
          CollectionErrorView(
            title: collections.unableToLoadCollection,
            message: '$error',
          ),
        (_, AsyncError(error: final error, stackTrace: _), _) =>
          CollectionErrorView(
            title: collections.unableToLoadCollectionItems,
            message: '$error',
          ),
        (_, _, AsyncError(error: final error, stackTrace: _)) =>
          CollectionErrorView(
            title: collections.unableToLoadCollectionItems,
            message: '$error',
          ),
        _ => CollectionLoadingView(label: collections.loadingCollection),
      },
    );
  }

  Widget _buildLoaded(MemoCollection? collection, List<LocalMemo> items) {
    final collections = context.t.strings.collections;
    if (collection == null || collection.type != MemoCollectionType.manual) {
      return CollectionStatusView(
        icon: Icons.auto_stories_outlined,
        title: collections.manualCollectionNotFoundTitle,
        description: collections.manualCollectionNotFoundDescription,
      );
    }
    if (items.isEmpty) {
      return CollectionStatusView(
        icon: Icons.playlist_add_check_rounded,
        title: collections.manualCollectionEmptyTitle,
        description: collections.manualCollectionEmptyDescription,
        action: FilledButton.icon(
          onPressed: _openAddSheet,
          icon: const Icon(Icons.add),
          label: Text(collections.addMemos),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) => _reorder(items, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final memo = items[index];
        final content = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        final preview = content.isEmpty
            ? context.t.strings.legacy.msg_empty_content
            : content;
        return Card(
          key: ValueKey<String>(memo.uid),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              memo.tags.take(3).map((tag) => '#$tag').join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: collections.remove,
                  onPressed: () => _removeMemo(memo.uid),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                const Icon(Icons.drag_handle_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ManualCollectionAddMemosSheet extends ConsumerStatefulWidget {
  const _ManualCollectionAddMemosSheet({required this.collectionId});

  final String collectionId;

  @override
  ConsumerState<_ManualCollectionAddMemosSheet> createState() =>
      _ManualCollectionAddMemosSheetState();
}

class _ManualCollectionAddMemosSheetState
    extends ConsumerState<_ManualCollectionAddMemosSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedMemoUids = <String>{};
  bool _submitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedMemoUids.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .addManualItems(widget.collectionId, _selectedMemoUids.toList());
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.t.strings.collections;
    final itemsAsync = ref.watch(
      collectionResolvedItemsProvider(widget.collectionId),
    );
    final candidatesAsync = ref.watch(collectionCandidateMemosProvider);
    final query = _searchController.text.trim().toLowerCase();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    collections.addMemos,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selectedMemoUids.isEmpty || _submitting
                      ? null
                      : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    collections.addSelected(count: _selectedMemoUids.length),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: collections.searchMemos,
              ),
            ),
            const SizedBox(height: 16),
            switch ((itemsAsync, candidatesAsync)) {
              (
                AsyncData<List<LocalMemo>> currentItems,
                AsyncData<List<LocalMemo>> candidates,
              ) =>
                _buildCandidateList(
                  currentItems.value,
                  candidates.value,
                  query,
                ),
              (AsyncError(error: final error, stackTrace: _), _) =>
                CollectionErrorView(
                  title: collections.unableToLoadCurrentItems,
                  message: '$error',
                  centered: false,
                  compact: true,
                ),
              (_, AsyncError(error: final error, stackTrace: _)) =>
                CollectionErrorView(
                  title: collections.unableToLoadMemos,
                  message: '$error',
                  centered: false,
                  compact: true,
                ),
              _ => CollectionLoadingView(
                label: collections.loadingMemos,
                centered: false,
                compact: true,
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateList(
    List<LocalMemo> currentItems,
    List<LocalMemo> candidates,
    String query,
  ) {
    final currentUids = currentItems.map((item) => item.uid).toSet();
    final filtered = candidates
        .where((memo) {
          if (currentUids.contains(memo.uid)) return false;
          if (query.isEmpty) return true;
          if (memo.content.toLowerCase().contains(query)) return true;
          for (final tag in memo.tags) {
            if (tag.toLowerCase().contains(query)) return true;
          }
          return false;
        })
        .toList(growable: false);

    if (filtered.isEmpty) {
      return CollectionStatusView(
        icon: Icons.search_off_rounded,
        title: context.t.strings.collections.noMemosAvailableTitle,
        description: context.t.strings.collections.noMemosAvailableDescription,
        centered: false,
        compact: true,
      );
    }

    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final memo = filtered[index];
          final content = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
          final preview = content.isEmpty
              ? context.t.strings.legacy.msg_empty_content
              : content;
          final selected = _selectedMemoUids.contains(memo.uid);
          return CheckboxListTile(
            value: selected,
            contentPadding: EdgeInsets.zero,
            title: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              memo.tags.take(3).map((tag) => '#$tag').join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedMemoUids.add(memo.uid);
                } else {
                  _selectedMemoUids.remove(memo.uid);
                }
              });
            },
          );
        },
      ),
    );
  }
}
