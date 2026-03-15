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
    'upgrade from v13 to v15 keeps memo data and avoids duplicate column migration',
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
    },
  );
}
