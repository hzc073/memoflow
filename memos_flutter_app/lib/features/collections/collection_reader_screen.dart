import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/memo_collection.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collections_provider.dart';
import 'collection_reader_shell.dart';

class CollectionReaderScreen extends ConsumerWidget {
  const CollectionReaderScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsStrings = context.t.strings.collections;
    final collectionAsync = ref.watch(collectionByIdProvider(collectionId));
    final itemsAsync = ref.watch(collectionResolvedItemsProvider(collectionId));
    if (collectionAsync.isLoading || itemsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (collectionAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('${collectionAsync.error}')),
      );
    }
    if (itemsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('${itemsAsync.error}')),
      );
    }
    final collection =
        collectionAsync.valueOrNull ??
        MemoCollection.createSmart(id: '', title: '');
    final items = itemsAsync.valueOrNull ?? const [];
    if (items.isEmpty) {
      final title = collection.title.trim().isEmpty
          ? collectionsStrings.collection
          : collection.title;
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(collectionsStrings.emptyManualDetail)),
      );
    }
    return CollectionReaderShell(
      collectionId: collectionId,
      collectionTitle: collection.title.trim().isEmpty
          ? collectionsStrings.collection
          : collection.title,
      items: items,
    );
  }
}
