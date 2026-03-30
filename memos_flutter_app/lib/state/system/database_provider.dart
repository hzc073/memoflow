import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hash.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_registry.dart';
import 'session_provider.dart';

String databaseNameForAccountKey(String accountKey) {
  return 'memos_app_${fnv1a64Hex(accountKey)}.db';
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  if (accountKey == null) {
    throw StateError('Not authenticated');
  }

  final dbName = databaseNameForAccountKey(accountKey);
  final db = DatabaseRegistry.acquire(dbName);
  ref.onDispose(() {
    DatabaseRegistry.release(dbName);
  });
  return db;
});
