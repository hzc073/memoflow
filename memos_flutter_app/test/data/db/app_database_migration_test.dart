import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:memos_flutter_app/core/debug_ephemeral_storage.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test(
    'upgrade from v13 to v17 keeps memo data and creates new support tables',
    () async {
      final dbName = uniqueDbName('app_database_v13_to_v15');

      addTearDown(() async {
        await AppDatabase.deleteDatabaseFile(dbName: dbName);
      });

      final dbDir = await resolveDatabasesDirectoryPath();
      final path = p.join(dbDir, dbName);

      final legacyDb = await openDatabase(
        path,
        version: 13,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE IF NOT EXISTS memos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT NOT NULL UNIQUE,
  content TEXT NOT NULL,
  visibility TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0,
  state TEXT NOT NULL DEFAULT 'NORMAL',
  create_time INTEGER NOT NULL,
  update_time INTEGER NOT NULL,
  tags TEXT NOT NULL DEFAULT '',
  attachments_json TEXT NOT NULL DEFAULT '[]',
  location_placeholder TEXT,
  location_lat REAL,
  location_lng REAL,
  relation_count INTEGER NOT NULL DEFAULT 0,
  sync_state INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);
''');
          await db.insert('memos', <String, Object?>{
            'uid': 'memo-001',
            'content': 'legacy memo content',
            'visibility': 'PRIVATE',
            'pinned': 0,
            'state': 'NORMAL',
            'create_time': 1735689600,
            'update_time': 1735689600,
            'tags': 'legacy',
            'attachments_json': '[]',
            'relation_count': 0,
            'sync_state': 0,
          });
        },
      );
      await legacyDb.close();

      final appDb = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await appDb.close();
      });

      final upgradedDb = await appDb.db;

      final memos = await upgradedDb.query(
        'memos',
        columns: const <String>['uid', 'content'],
        where: 'uid = ?',
        whereArgs: const <Object?>['memo-001'],
      );
      expect(memos, hasLength(1));
      expect(memos.single['content'], 'legacy memo content');

      final columns = await upgradedDb.rawQuery(
        'PRAGMA table_info("ai_analysis_tasks");',
      );
      final includePublicColumns = columns
          .where((row) => row['name'] == 'include_public')
          .toList();

      expect(includePublicColumns, hasLength(1));

      final tombstoneColumns = await upgradedDb.rawQuery(
        'PRAGMA table_info("memo_delete_tombstones");',
      );
      expect(tombstoneColumns.any((row) => row['name'] == 'memo_uid'), isTrue);
      expect(tombstoneColumns.any((row) => row['name'] == 'state'), isTrue);

      final inlineSourceColumns = await upgradedDb.rawQuery(
        'PRAGMA table_info("memo_inline_image_sources");',
      );
      expect(
        inlineSourceColumns.any((row) => row['name'] == 'memo_uid'),
        isTrue,
      );
      expect(
        inlineSourceColumns.any((row) => row['name'] == 'local_url'),
        isTrue,
      );
      expect(
        inlineSourceColumns.any((row) => row['name'] == 'source_url'),
        isTrue,
      );
    },
  );

  test(
    'open recovers when legacy memos_fts delete fails with missing module error',
    () async {
      final dbName = uniqueDbName('app_database_broken_fts_recovery');

      addTearDown(() async {
        await AppDatabase.deleteDatabaseFile(dbName: dbName);
      });

      final dbDir = await resolveDatabasesDirectoryPath();
      final path = p.join(dbDir, dbName);

      final legacyDb = await openDatabase(
        path,
        version: 13,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE IF NOT EXISTS memos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT NOT NULL UNIQUE,
  content TEXT NOT NULL,
  visibility TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0,
  state TEXT NOT NULL DEFAULT 'NORMAL',
  create_time INTEGER NOT NULL,
  update_time INTEGER NOT NULL,
  tags TEXT NOT NULL DEFAULT '',
  attachments_json TEXT NOT NULL DEFAULT '[]',
  location_placeholder TEXT,
  location_lat REAL,
  location_lng REAL,
  relation_count INTEGER NOT NULL DEFAULT 0,
  sync_state INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);
''');
          await db.insert('memos', <String, Object?>{
            'uid': 'memo-broken-fts',
            'content': 'legacy memo content',
            'visibility': 'PRIVATE',
            'pinned': 0,
            'state': 'NORMAL',
            'create_time': 1735689600,
            'update_time': 1735689600,
            'tags': 'legacy broken',
            'attachments_json': '[]',
            'relation_count': 0,
            'sync_state': 0,
          });
          await db.execute('''
CREATE TABLE IF NOT EXISTS memos_fts (
  content TEXT NOT NULL DEFAULT '',
  tags TEXT NOT NULL DEFAULT ''
);
''');
          await db.execute('''
CREATE TRIGGER broken_memos_fts_delete
BEFORE DELETE ON memos_fts
BEGIN
  SELECT RAISE(ABORT, 'no such module: fts5');
END;
''');
        },
      );
      await legacyDb.close();

      final appDb = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await appDb.close();
      });

      final upgradedDb = await appDb.db;

      final memos = await upgradedDb.query(
        'memos',
        columns: const <String>['uid', 'content'],
        where: 'uid = ?',
        whereArgs: const <Object?>['memo-broken-fts'],
      );
      expect(memos, hasLength(1));
      expect(memos.single['content'], 'legacy memo content');

      final ftsRows = await upgradedDb.rawQuery(
        'SELECT rowid, content, tags FROM memos_fts ORDER BY rowid ASC;',
      );
      expect(ftsRows, hasLength(1));
      expect(ftsRows.single['content'], 'legacy memo content');
      expect(ftsRows.single['tags'], 'legacy broken');
    },
  );

  test('closing one wrapper does not invalidate another wrapper', () async {
    final dbName = uniqueDbName('app_database_independent_handles');

    addTearDown(() async {
      await AppDatabase.deleteDatabaseFile(dbName: dbName);
    });

    final first = AppDatabase(dbName: dbName);
    final second = AppDatabase(dbName: dbName);

    addTearDown(() async {
      await first.close();
      await second.close();
    });

    await first.upsertMemo(
      uid: 'memo-shared-handle',
      content: 'content from first handle',
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

    expect(await second.getMemoByUid('memo-shared-handle'), isNotNull);

    await first.close();

    final row = await second.getMemoByUid('memo-shared-handle');
    expect(row, isNotNull);
    expect(row?['content'], 'content from first handle');

    await second.countOutboxPending();
  });

  test('concurrent db getter reuses one opening handle per wrapper', () async {
    final dbName = uniqueDbName('app_database_single_open_race');
    final appDb = AppDatabase(dbName: dbName);

    addTearDown(() async {
      await appDb.close();
      await AppDatabase.deleteDatabaseFile(dbName: dbName);
    });

    final results = await Future.wait<Database>(<Future<Database>>[
      appDb.db,
      appDb.db,
      appDb.db,
      appDb.db,
    ]);

    final first = results.first;
    expect(results.every((db) => identical(db, first)), isTrue);

    await appDb.upsertMemo(
      uid: 'memo-open-race',
      content: 'opened once',
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

    final row = await appDb.getMemoByUid('memo-open-race');
    expect(row?['content'], 'opened once');
  });
}
