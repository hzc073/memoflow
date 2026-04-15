import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_collection.dart';
import '../../data/repositories/collections_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collections_provider.dart';
import 'collection_ui.dart';
import 'collection_editor_screen.dart';

Future<void> showAddMemoToCollectionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required LocalMemo memo,
}) async {
  final action = await showModalBottomSheet<_AddToCollectionAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddMemoToCollectionSheet(memo: memo),
  );
  if (!context.mounted) return;
  if (action == _AddToCollectionAction.added) {
    showTopToast(
      context,
      context.tr(zh: '已加入合集', en: 'Added to collection'),
    );
    return;
  }
  if (action != _AddToCollectionAction.createManual) {
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<MemoCollection>(
      builder: (_) => CollectionEditorScreen(
        initialType: MemoCollectionType.manual,
        initialManualMemoUids: <String>[memo.uid],
      ),
    ),
  );
}

enum _AddToCollectionAction { createManual, added }

class _AddMemoToCollectionSheet extends ConsumerStatefulWidget {
  const _AddMemoToCollectionSheet({required this.memo});

  final LocalMemo memo;

  @override
  ConsumerState<_AddMemoToCollectionSheet> createState() =>
      _AddMemoToCollectionSheetState();
}

class _AddMemoToCollectionSheetState
    extends ConsumerState<_AddMemoToCollectionSheet> {
  final Set<String> _busyCollectionIds = <String>{};

  Future<void> _toggleMembership(ManualCollectionMembershipItem item) async {
    final collectionId = item.collection.id;
    if (_busyCollectionIds.contains(collectionId)) return;
    final wasAdded = !item.containsMemo;
    var didCloseSheet = false;
    setState(() => _busyCollectionIds.add(collectionId));
    try {
      final repository = ref.read(collectionsRepositoryProvider);
      if (item.containsMemo) {
        await repository.removeManualItem(collectionId, <String>[
          widget.memo.uid,
        ]);
      } else {
        await repository.addManualItems(collectionId, <String>[
          widget.memo.uid,
        ]);
      }
      if (mounted && wasAdded) {
        didCloseSheet = true;
        Navigator.of(context).pop(_AddToCollectionAction.added);
        return;
      }
    } finally {
      if (mounted && !didCloseSheet) {
        setState(() => _busyCollectionIds.remove(collectionId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.t.strings.collections;
    final membershipsAsync = ref.watch(
      manualCollectionMembershipsProvider(widget.memo.uid),
    );
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
                    collections.addToCollection,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_AddToCollectionAction.createManual),
                  icon: const Icon(Icons.add),
                  label: Text(collections.newManual),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.memo.content.replaceAll(RegExp(r'\s+'), ' ').trim().isEmpty
                  ? context.t.strings.legacy.msg_empty_content
                  : widget.memo.content.replaceAll(RegExp(r'\s+'), ' ').trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            membershipsAsync.when(
              data: (items) {
                final visibleItems = items
                    .where((item) => !item.collection.archived)
                    .toList(growable: false);
                if (visibleItems.isEmpty) {
                  return CollectionStatusView(
                    icon: Icons.collections_bookmark_outlined,
                    title: collections.noManualCollectionsTitle,
                    description: collections.noManualCollectionsDescription,
                    centered: false,
                    compact: true,
                  );
                }
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final busy = _busyCollectionIds.contains(
                        item.collection.id,
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.collection.title),
                        subtitle: Text(
                          collections.memosCount(count: item.itemCount),
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                item.containsMemo
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                              ),
                        onTap: () => _toggleMembership(item),
                      );
                    },
                  ),
                );
              },
              error: (error, _) => CollectionErrorView(
                title: collections.unableToLoadCollections,
                message: '$error',
                centered: false,
                compact: true,
              ),
              loading: () => CollectionLoadingView(
                label: collections.loadingCollections,
                centered: false,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
