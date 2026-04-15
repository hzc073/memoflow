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

  test(
    'upgrade from v18 to v19 migrates blocked outbox chains to quarantined',
    () async {
      final dbName = uniqueDbName('app_database_v18_to_v19_outbox_quarantine');

      addTearDown(() async {
        await AppDatabase.deleteDatabaseFile(dbName: dbName);
      });

      final dbDir = await resolveDatabasesDirectoryPath();
      final path = p.join(dbDir, dbName);

      final legacyDb = await openDatabase(
        path,
        version: 18,
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
          await db.execute('''
CREATE TABLE IF NOT EXISTS outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  payload TEXT NOT NULL,
  state INTEGER NOT NULL DEFAULT 0,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  retry_at INTEGER,
  created_time INTEGER NOT NULL
);
''');
          await db.insert('outbox', <String, Object?>{
            'type': 'update_memo',
            'payload': '{"uid":"memo-1","content":"legacy"}',
            'state': AppDatabase.outboxStateError,
            'attempts': 1,
            'last_error': 'HTTP 404 | memo not found',
            'retry_at': null,
            'created_time': 1773424800000,
          });
          await db.insert('outbox', <String, Object?>{
            'type': 'upload_attachment',
            'payload':
                '{"uid":"att-1","memo_uid":"memo-1","file_path":"C:/tmp/a.png","filename":"a.png","mime_type":"image/png"}',
            'state': AppDatabase.outboxStatePending,
            'attempts': 0,
            'last_error': null,
            'retry_at': null,
            'created_time': 1773424801000,
          });
          await db.insert('outbox', <String, Object?>{
            'type': 'create_memo',
            'payload':
                '{"uid":"memo-2","content":"independent","visibility":"PRIVATE","pinned":false}',
            'state': AppDatabase.outboxStatePending,
            'attempts': 0,
            'last_error': null,
            'retry_at': null,
            'created_time': 1773424802000,
          });
        },
      );
      await legacyDb.close();

      final appDb = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await appDb.close();
      });

      final upgradedDb = await appDb.db;
      final columns = await upgradedDb.rawQuery('PRAGMA table_info("outbox");');
      expect(columns.any((row) => row['name'] == 'failure_code'), isTrue);
      expect(columns.any((row) => row['name'] == 'failure_kind'), isTrue);
      expect(columns.any((row) => row['name'] == 'quarantined_at'), isTrue);

      final rows = await upgradedDb.query(
        'outbox',
        columns: const [
          'type',
          'state',
          'failure_code',
          'failure_kind',
          'quarantined_at',
        ],
        orderBy: 'id ASC',
      );
      expect(rows, hasLength(3));

      expect(rows[0]['type'], 'update_memo');
      expect(rows[0]['state'], AppDatabase.outboxStateQuarantined);
      expect(rows[0]['failure_code'], 'legacy_error_migrated');
      expect(rows[0]['failure_kind'], 'fatal_immediate');
      expect(rows[0]['quarantined_at'], isNotNull);

      expect(rows[1]['type'], 'upload_attachment');
      expect(rows[1]['state'], AppDatabase.outboxStateQuarantined);
      expect(rows[1]['failure_code'], 'blocked_by_quarantined_memo_root');
      expect(rows[1]['failure_kind'], 'fatal_immediate');
      expect(rows[1]['quarantined_at'], isNotNull);

      expect(rows[2]['type'], 'create_memo');
      expect(rows[2]['state'], AppDatabase.outboxStatePending);
      expect(rows[2]['failure_code'], isNull);
      expect(rows[2]['failure_kind'], isNull);
    },
  );

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

  test('upgrade to v20 backfills display_time from create_time', () async {
    final dbName = uniqueDbName('app_database_v19_display_time_backfill');

    addTearDown(() async {
      await AppDatabase.deleteDatabaseFile(dbName: dbName);
    });

    final dbDir = await resolveDatabasesDirectoryPath();
    final path = p.join(dbDir, dbName);

    final legacyDb = await openDatabase(
      path,
      version: 19,
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
          'uid': 'memo-display',
          'content': 'legacy memo',
          'visibility': 'PRIVATE',
          'pinned': 0,
          'state': 'NORMAL',
          'create_time': 1735689600,
          'update_time': 1735689700,
          'tags': '',
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
    final columns = await upgradedDb.rawQuery('PRAGMA table_info("memos");');
    expect(columns.any((row) => row['name'] == 'display_time'), isTrue);

    final rows = await upgradedDb.query(
      'memos',
      columns: const <String>['uid', 'create_time', 'display_time'],
      where: 'uid = ?',
      whereArgs: const <Object?>['memo-display'],
    );
    expect(rows, hasLength(1));
    expect(rows.single['create_time'], 1735689600);
    expect(rows.single['display_time'], 1735689600);
  });

  test('upsertMemo preserves display_time when omitted on update', () async {
    final dbName = uniqueDbName('app_database_preserve_display_time');
    final appDb = AppDatabase(dbName: dbName);

    addTearDown(() async {
      await appDb.close();
      await AppDatabase.deleteDatabaseFile(dbName: dbName);
    });

    await appDb.upsertMemo(
      uid: 'memo-1',
      content: 'original',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTimeSec: 1735689600,
      displayTimeSec: 1735776000,
      updateTimeSec: 1735689600,
      tags: const <String>[],
      attachments: const <Map<String, dynamic>>[],
      location: null,
      syncState: 0,
    );

    await appDb.upsertMemo(
      uid: 'memo-1',
      content: 'updated',
      visibility: 'PRIVATE',
      pinned: true,
      state: 'NORMAL',
      createTimeSec: 1735689600,
      updateTimeSec: 1735862400,
      tags: const <String>['tag-a'],
      attachments: const <Map<String, dynamic>>[],
      location: null,
      syncState: 1,
    );

    final upgradedDb = await appDb.db;
    final rows = await upgradedDb.query(
      'memos',
      columns: const <String>['uid', 'display_time', 'pinned', 'sync_state'],
      where: 'uid = ?',
      whereArgs: const <Object?>['memo-1'],
    );

    expect(rows, hasLength(1));
    expect(rows.single['display_time'], 1735776000);
    expect(rows.single['pinned'], 1);
    expect(rows.single['sync_state'], 1);
  });

  test('upgrade to v21 creates memo_collections table', () async {
    final dbName = uniqueDbName('app_database_v20_collections');

    addTearDown(() async {
      await AppDatabase.deleteDatabaseFile(dbName: dbName);
    });

    final dbDir = await resolveDatabasesDirectoryPath();
    final path = p.join(dbDir, dbName);

    final legacyDb = await openDatabase(
      path,
      version: 20,
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
  display_time INTEGER,
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
      },
    );
    await legacyDb.close();

    final appDb = AppDatabase(dbName: dbName);
    addTearDown(() async {
      await appDb.close();
    });

    final upgradedDb = await appDb.db;
    final columns = await upgradedDb.rawQuery(
      'PRAGMA table_info("memo_collections");',
    );

    expect(columns.any((row) => row['name'] == 'id'), isTrue);
    expect(columns.any((row) => row['name'] == 'rules_json'), isTrue);
    expect(columns.any((row) => row['name'] == 'cover_json'), isTrue);
    expect(columns.any((row) => row['name'] == 'view_json'), isTrue);
  });

  test('upgrade to v22 creates memo_collection_items table', () async {
    final dbName = uniqueDbName('app_database_v21_collection_items');

    addTearDown(() async {
      await AppDatabase.deleteDatabaseFile(dbName: dbName);
    });

    final dbDir = await resolveDatabasesDirectoryPath();
    final path = p.join(dbDir, dbName);

    final legacyDb = await openDatabase(
      path,
      version: 21,
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
  display_time INTEGER,
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
        await db.execute('''
CREATE TABLE IF NOT EXISTS memo_collections (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL,
  icon_key TEXT NOT NULL DEFAULT '',
  accent_color_hex TEXT,
  rules_json TEXT NOT NULL DEFAULT '{}',
  cover_json TEXT NOT NULL DEFAULT '{}',
  view_json TEXT NOT NULL DEFAULT '{}',
  pinned INTEGER NOT NULL DEFAULT 0,
  archived INTEGER NOT NULL DEFAULT 0,
  hide_when_empty INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL
);
''');
      },
    );
    await legacyDb.close();

    final appDb = AppDatabase(dbName: dbName);
    addTearDown(() async {
      await appDb.close();
    });

    final upgradedDb = await appDb.db;
    final columns = await upgradedDb.rawQuery(
      'PRAGMA table_info("memo_collection_items");',
    );

    expect(columns.any((row) => row['name'] == 'collection_id'), isTrue);
    expect(columns.any((row) => row['name'] == 'memo_uid'), isTrue);
    expect(columns.any((row) => row['name'] == 'sort_order'), isTrue);
    expect(columns.any((row) => row['name'] == 'created_time'), isTrue);
    expect(columns.any((row) => row['name'] == 'updated_time'), isTrue);
  });

  test(
    'upgrade from v23 to v24 upgrades collection reader progress table',
    () async {
      final dbName = uniqueDbName('app_database_v23_to_v24_reader_progress');

      addTearDown(() async {
        await AppDatabase.deleteDatabaseFile(dbName: dbName);
      });

      final dbDir = await resolveDatabasesDirectoryPath();
      final path = p.join(dbDir, dbName);

      final legacyDb = await openDatabase(
        path,
        version: 23,
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
            'uid': 'memo-v22',
            'content': 'legacy memo',
            'visibility': 'PRIVATE',
            'pinned': 0,
            'state': 'NORMAL',
            'create_time': 1775001600,
            'update_time': 1775001600,
            'tags': '',
            'attachments_json': '[]',
            'relation_count': 0,
            'sync_state': 0,
          });
          await db.execute('''
CREATE TABLE IF NOT EXISTS collection_read_progress (
  collection_id TEXT NOT NULL PRIMARY KEY,
  reader_mode TEXT NOT NULL,
  current_memo_uid TEXT,
  current_memo_index INTEGER NOT NULL DEFAULT 0,
  list_scroll_offset REAL NOT NULL DEFAULT 0,
  inner_scroll_offset REAL NOT NULL DEFAULT 0,
  updated_time INTEGER NOT NULL
);
''');
        },
      );
      await legacyDb.close();

      final appDb = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await appDb.close();
      });

    final upgradedDb = await appDb.db;
    final columns = await upgradedDb.rawQuery(
      'PRAGMA table_info("collection_read_progress");',
    );

      expect(columns.any((row) => row['name'] == 'collection_id'), isTrue);
      expect(columns.any((row) => row['name'] == 'reader_mode'), isTrue);
      expect(columns.any((row) => row['name'] == 'page_animation'), isTrue);
      expect(columns.any((row) => row['name'] == 'current_memo_uid'), isTrue);
      expect(columns.any((row) => row['name'] == 'current_memo_index'), isTrue);
      expect(
        columns.any((row) => row['name'] == 'current_chapter_page_index'),
        isTrue,
      );
      expect(columns.any((row) => row['name'] == 'list_scroll_offset'), isTrue);
      expect(
        columns.any((row) => row['name'] == 'current_match_char_offset'),
        isTrue,
      );
      expect(columns.any((row) => row['name'] == 'updated_time'), isTrue);
    },
  );
}
