import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/local_memo.dart';
import '../../data/models/memo_collection.dart';
import '../../data/repositories/collections_repository.dart';
import '../system/database_provider.dart';
import '../tags/tag_color_lookup.dart';
import 'collection_resolver.dart';

class ManualCollectionMembershipItem {
  const ManualCollectionMembershipItem({
    required this.collection,
    required this.itemCount,
    required this.containsMemo,
  });

  final MemoCollection collection;
  final int itemCount;
  final bool containsMemo;
}

final collectionCandidateMemosProvider = StreamProvider<List<LocalMemo>>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);

  Future<List<LocalMemo>> load() async {
    final rows = await db.listMemos(state: 'NORMAL', limit: null);
    return rows.map(LocalMemo.fromDb).toList(growable: false);
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final collectionsProvider = StreamProvider<List<MemoCollection>>((ref) async* {
  final db = ref.watch(databaseProvider);
  final repository = ref.watch(collectionsRepositoryProvider);

  Future<List<MemoCollection>> load() => repository.readAll();

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final collectionManualItemUidsProvider =
    StreamProvider.family<List<String>, String>((ref, collectionId) async* {
      final db = ref.watch(databaseProvider);
      final repository = ref.watch(collectionsRepositoryProvider);

      Future<List<String>> load() =>
          repository.readManualItemUids(collectionId);

      yield await load();
      await for (final _ in db.changes) {
        yield await load();
      }
    });

final collectionByIdProvider =
    Provider.family<AsyncValue<MemoCollection?>, String>((ref, collectionId) {
      final collectionsAsync = ref.watch(collectionsProvider);
      if (collectionsAsync.isLoading && !collectionsAsync.hasValue) {
        return const AsyncValue.loading();
      }
      if (collectionsAsync.hasError) {
        return AsyncValue.error(
          collectionsAsync.error!,
          collectionsAsync.stackTrace ?? StackTrace.current,
        );
      }
      final items = collectionsAsync.valueOrNull ?? const <MemoCollection>[];
      for (final item in items) {
        if (item.id == collectionId) {
          return AsyncValue.data(item);
        }
      }
      return const AsyncValue.data(null);
    });

final collectionResolvedItemsProvider =
    Provider.family<AsyncValue<List<LocalMemo>>, String>((ref, collectionId) {
      final collectionAsync = ref.watch(collectionByIdProvider(collectionId));
      final memosAsync = ref.watch(collectionCandidateMemosProvider);
      final collection = collectionAsync.valueOrNull;
      final manualUidsAsync = collection?.type == MemoCollectionType.manual
          ? ref.watch(collectionManualItemUidsProvider(collectionId))
          : const AsyncValue.data(<String>[]);

      if (collectionAsync.isLoading ||
          memosAsync.isLoading ||
          manualUidsAsync.isLoading) {
        if (!collectionAsync.hasValue || !memosAsync.hasValue) {
          return const AsyncValue.loading();
        }
        if (collection?.type == MemoCollectionType.manual &&
            !manualUidsAsync.hasValue) {
          return const AsyncValue.loading();
        }
      }
      if (collectionAsync.hasError) {
        return AsyncValue.error(
          collectionAsync.error!,
          collectionAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (memosAsync.hasError) {
        return AsyncValue.error(
          memosAsync.error!,
          memosAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (manualUidsAsync.hasError) {
        return AsyncValue.error(
          manualUidsAsync.error!,
          manualUidsAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (collection == null) {
        return const AsyncValue.data(<LocalMemo>[]);
      }
      final memos = memosAsync.valueOrNull ?? const <LocalMemo>[];
      final tagLookup = ref.watch(tagColorLookupProvider);
      final manualMemoUids = manualUidsAsync.valueOrNull ?? const <String>[];
      return AsyncValue.data(
        resolveCollectionItems(
          collection,
          memos,
          manualMemoUids: manualMemoUids,
          resolveCanonicalTagPath: tagLookup.resolveCanonicalPath,
        ),
      );
    });

final collectionPreviewProvider =
    Provider.family<AsyncValue<MemoCollectionPreview>, String>((
      ref,
      collectionId,
    ) {
      final collectionAsync = ref.watch(collectionByIdProvider(collectionId));
      final itemsAsync = ref.watch(
        collectionResolvedItemsProvider(collectionId),
      );
      if (collectionAsync.isLoading || itemsAsync.isLoading) {
        if (!collectionAsync.hasValue || !itemsAsync.hasValue) {
          return const AsyncValue.loading();
        }
      }
      if (collectionAsync.hasError) {
        return AsyncValue.error(
          collectionAsync.error!,
          collectionAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (itemsAsync.hasError) {
        return AsyncValue.error(
          itemsAsync.error!,
          itemsAsync.stackTrace ?? StackTrace.current,
        );
      }
      final collection = collectionAsync.valueOrNull;
      if (collection == null) {
        return AsyncValue.data(
          buildCollectionPreview(
            MemoCollection.createSmart(id: '', title: ''),
            const <LocalMemo>[],
          ),
        );
      }
      final items = itemsAsync.valueOrNull ?? const <LocalMemo>[];
      final tagLookup = ref.watch(tagColorLookupProvider);
      return AsyncValue.data(
        buildCollectionPreview(
          collection,
          items,
          resolveTagColorHexByPath: tagLookup.resolveEffectiveHexByPath,
        ),
      );
    });

final collectionsDashboardProvider =
    Provider<AsyncValue<List<MemoCollectionDashboardItem>>>((ref) {
      final collectionsAsync = ref.watch(collectionsProvider);
      final memosAsync = ref.watch(collectionCandidateMemosProvider);
      if (collectionsAsync.isLoading || memosAsync.isLoading) {
        if (!collectionsAsync.hasValue || !memosAsync.hasValue) {
          return const AsyncValue.loading();
        }
      }
      if (collectionsAsync.hasError) {
        return AsyncValue.error(
          collectionsAsync.error!,
          collectionsAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (memosAsync.hasError) {
        return AsyncValue.error(
          memosAsync.error!,
          memosAsync.stackTrace ?? StackTrace.current,
        );
      }

      final collections =
          collectionsAsync.valueOrNull ?? const <MemoCollection>[];
      final memos = memosAsync.valueOrNull ?? const <LocalMemo>[];
      final tagLookup = ref.watch(tagColorLookupProvider);
      final dashboard = <MemoCollectionDashboardItem>[];
      for (final collection in collections) {
        final manualUidsAsync = collection.type == MemoCollectionType.manual
            ? ref.watch(collectionManualItemUidsProvider(collection.id))
            : const AsyncValue.data(<String>[]);
        if (manualUidsAsync.isLoading && !manualUidsAsync.hasValue) {
          return const AsyncValue.loading();
        }
        if (manualUidsAsync.hasError) {
          return AsyncValue.error(
            manualUidsAsync.error!,
            manualUidsAsync.stackTrace ?? StackTrace.current,
          );
        }
        final manualMemoUids = manualUidsAsync.valueOrNull ?? const <String>[];
        final items = resolveCollectionItems(
          collection,
          memos,
          manualMemoUids: manualMemoUids,
          resolveCanonicalTagPath: tagLookup.resolveCanonicalPath,
        );
        final preview = buildCollectionPreview(
          collection,
          items,
          resolveTagColorHexByPath: tagLookup.resolveEffectiveHexByPath,
        );
        dashboard.add(
          MemoCollectionDashboardItem(
            collection: collection,
            preview: preview,
            items: items,
          ),
        );
      }
      return AsyncValue.data(dashboard);
    });

final manualCollectionMembershipsProvider =
    Provider.family<AsyncValue<List<ManualCollectionMembershipItem>>, String>((
      ref,
      memoUid,
    ) {
      final normalizedMemoUid = memoUid.trim();
      final collectionsAsync = ref.watch(collectionsProvider);
      if (collectionsAsync.isLoading && !collectionsAsync.hasValue) {
        return const AsyncValue.loading();
      }
      if (collectionsAsync.hasError) {
        return AsyncValue.error(
          collectionsAsync.error!,
          collectionsAsync.stackTrace ?? StackTrace.current,
        );
      }
      final collections =
          (collectionsAsync.valueOrNull ?? const <MemoCollection>[])
              .where((item) => item.type == MemoCollectionType.manual)
              .toList(growable: false);
      final memberships = <ManualCollectionMembershipItem>[];
      for (final collection in collections) {
        final manualUidsAsync = ref.watch(
          collectionManualItemUidsProvider(collection.id),
        );
        if (manualUidsAsync.isLoading && !manualUidsAsync.hasValue) {
          return const AsyncValue.loading();
        }
        if (manualUidsAsync.hasError) {
          return AsyncValue.error(
            manualUidsAsync.error!,
            manualUidsAsync.stackTrace ?? StackTrace.current,
          );
        }
        final itemUids = manualUidsAsync.valueOrNull ?? const <String>[];
        memberships.add(
          ManualCollectionMembershipItem(
            collection: collection,
            itemCount: itemUids.length,
            containsMemo:
                normalizedMemoUid.isNotEmpty &&
                itemUids.contains(normalizedMemoUid),
          ),
        );
      }
      return AsyncValue.data(memberships);
    });
