import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/db/database_registry.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await DatabaseRegistry.closeAll();
    await support.dispose();
  });

  test('acquire reuses one shared AppDatabase per dbName', () async {
    final dbName = uniqueDbName('database_registry_shared');
    var createCount = 0;

    final first = DatabaseRegistry.acquire(
      dbName,
      create: () {
        createCount += 1;
        return AppDatabase(dbName: dbName);
      },
    );
    final second = DatabaseRegistry.acquire(
      dbName,
      create: () {
        createCount += 1;
        return AppDatabase(dbName: dbName);
      },
    );

    expect(identical(first, second), isTrue);
    expect(createCount, 1);

    await first.upsertMemo(
      uid: 'memo-shared-db',
      content: 'shared content',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTimeSec: 1735689600,
      updateTimeSec: 1735689600,
      tags: const <String>[],
      attachments: const <Map<String, Object?>>[],
      relationCount: 0,
      location: null,
      syncState: 0,
      lastError: null,
    );

    final row = await second.getMemoByUid('memo-shared-db');
    expect(row?['content'], 'shared content');

    DatabaseRegistry.release(dbName);
    DatabaseRegistry.release(dbName);
  });

  test(
    'closeAll disposes shared database and next acquire creates new one',
    () async {
      final dbName = uniqueDbName('database_registry_close_all');
      final first = DatabaseRegistry.acquire(
        dbName,
        create: () => AppDatabase(dbName: dbName),
      );

      await first.db;
      await DatabaseRegistry.closeAll();

      final second = DatabaseRegistry.acquire(
        dbName,
        create: () => AppDatabase(dbName: dbName),
      );

      expect(identical(first, second), isFalse);

      DatabaseRegistry.release(dbName);
      await DatabaseRegistry.closeAll();
    },
  );
}
