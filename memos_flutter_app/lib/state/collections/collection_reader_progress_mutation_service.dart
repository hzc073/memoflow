import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/models/collection_reader.dart';
import '../system/database_provider.dart';

final collectionReaderProgressMutationServiceProvider =
    Provider<CollectionReaderProgressMutationService>((ref) {
      return CollectionReaderProgressMutationService(
        db: ref.watch(databaseProvider),
      );
    });

class CollectionReaderProgressMutationService {
  const CollectionReaderProgressMutationService({required this.db});

  final AppDatabase db;

  Future<void> save(CollectionReaderProgress progress) {
    return db.upsertCollectionReaderProgressRow(progress.toRow());
  }

  Future<void> clear(String collectionId) {
    return db.deleteCollectionReaderProgress(collectionId);
  }
}
