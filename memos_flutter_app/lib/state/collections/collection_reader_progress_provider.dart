import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/models/collection_reader.dart';
import '../system/database_provider.dart';
import 'collection_reader_progress_mutation_service.dart';

final collectionReaderProgressRepositoryProvider =
    Provider<CollectionReaderProgressRepository>((ref) {
      return CollectionReaderProgressRepository(
        database: ref.watch(databaseProvider),
        mutations: ref.watch(collectionReaderProgressMutationServiceProvider),
      );
    });

class CollectionReaderProgressRepository {
  CollectionReaderProgressRepository({
    required AppDatabase database,
    CollectionReaderProgressMutationService? mutations,
  }) : _database = database,
       _mutations = mutations ?? CollectionReaderProgressMutationService(db: database);

  final AppDatabase _database;
  final CollectionReaderProgressMutationService _mutations;

  Future<CollectionReaderProgress?> load(String collectionId) async {
    final row = await _database.getCollectionReaderProgressRow(collectionId);
    if (row == null) {
      return null;
    }
    return CollectionReaderProgress.fromRow(row);
  }

  Future<void> save(CollectionReaderProgress progress) {
    return _mutations.save(progress);
  }

  Future<void> clear(String collectionId) {
    return _mutations.clear(collectionId);
  }
}
