import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/hash.dart';
import '../data/db/app_database.dart';
import 'session_provider.dart';

String databaseNameForAccountKey(String accountKey) {
  return 'memos_app_${fnv1a64Hex(accountKey)}.db';
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }

  final dbName = databaseNameForAccountKey(account.key);
  final db = AppDatabase(dbName: dbName);
  ref.onDispose(db.close);
  return db;
});
