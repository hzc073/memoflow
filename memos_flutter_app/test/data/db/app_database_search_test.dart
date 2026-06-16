import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/db/memo_search_db_persistence.dart';
import 'package:memos_flutter_app/data/models/memo_clip_card_metadata.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/data/models/memo_sort_order.dart';

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
    'listMemos matches CJK middle substrings and literal LIKE text',
    () async {
      final dbName = uniqueDbName('memo_search_literal');
      final db = AppDatabase(dbName: dbName);
      final nowSec =
          DateTime.utc(2026, 4, 18, 3, 0).millisecondsSinceEpoch ~/ 1000;
      const phrase = '\u5728\u79e9\u5e8f\u4e2d\u5b89\u987f';

      await _insertMemo(
        db,
        uid: 'memo-cjk',
        content: phrase,
        createTimeSec: nowSec,
      );
      await _insertMemo(
        db,
        uid: 'memo-literal',
        content: 'value 100%_safe',
        createTimeSec: nowSec,
      );

      expect(
        (await db.listMemos(searchQuery: '\u5728')).map((row) => row['uid']),
        contains('memo-cjk'),
      );
      expect(
        (await db.listMemos(
          searchQuery: '\u79e9\u5e8f',
        )).map((row) => row['uid']),
        contains('memo-cjk'),
      );
      expect(
        (await db.listMemos(
          searchQuery: '  \u5728\u79e9\u5e8f  ',
        )).map((row) => row['uid']),
        contains('memo-cjk'),
      );
      expect(
        (await db.listMemos(searchQuery: 'missing')).map((row) => row['uid']),
        isNot(contains('memo-cjk')),
      );
      expect(
        (await db.listMemos(searchQuery: '%_')).map((row) => row['uid']),
        contains('memo-literal'),
      );

      await db.close();
      await deleteTestDatabase(dbName);
    },
  );

  test(
    'listMemos keeps state tag and date filters as additional constraints',
    () async {
      final dbName = uniqueDbName('memo_search_filters');
      final db = AppDatabase(dbName: dbName);
      final startSec =
          DateTime.utc(2026, 4, 18, 0, 0).millisecondsSinceEpoch ~/ 1000;
      const phrase = '\u5728\u79e9\u5e8f\u4e2d\u5b89\u987f';

      await _insertMemo(
        db,
        uid: 'memo-match',
        content: phrase,
        tags: const ['focus'],
        createTimeSec: startSec + 60,
      );
      await _insertMemo(
        db,
        uid: 'memo-archived',
        content: phrase,
        state: 'ARCHIVED',
        tags: const ['focus'],
        createTimeSec: startSec + 60,
      );
      await _insertMemo(
        db,
        uid: 'memo-other-tag',
        content: phrase,
        tags: const ['other'],
        createTimeSec: startSec + 60,
      );
      await _insertMemo(
        db,
        uid: 'memo-old',
        content: phrase,
        tags: const ['focus'],
        createTimeSec: startSec - 86400,
      );

      final rows = await db.listMemos(
        searchQuery: '\u79e9\u5e8f',
        state: 'NORMAL',
        tag: 'focus',
        startTimeSec: startSec,
        endTimeSecExclusive: startSec + 3600,
      );
      final uids = rows
          .map((row) => row['uid'])
          .whereType<String>()
          .toList(growable: false);

      expect(uids, contains('memo-match'));
      expect(uids, isNot(contains('memo-archived')));
      expect(uids, isNot(contains('memo-other-tag')));
      expect(uids, isNot(contains('memo-old')));

      await db.close();
      await deleteTestDatabase(dbName);
    },
  );

  test(
    'listMemos update desc uses update_time for first page candidates',
    () async {
      final dbName = uniqueDbName('memo_update_sort_first_page');
      final db = AppDatabase(dbName: dbName);
      final baseSec =
          DateTime.utc(2026, 6, 4, 1, 0).millisecondsSinceEpoch ~/ 1000;

      for (var i = 0; i < 5; i += 1) {
        await _insertMemo(
          db,
          uid: 'recent-create-$i',
          content: 'recent create $i',
          createTimeSec: baseSec + 100 + i,
          updateTimeSec: baseSec + 100 + i,
        );
      }
      await _insertMemo(
        db,
        uid: 'old-create-new-update',
        content: 'old create new update',
        createTimeSec: baseSec - 100000,
        updateTimeSec: baseSec + 1000,
      );

      final createRows = await db.listMemos(
        state: 'NORMAL',
        sortOrder: MemoSortOrder.createDesc,
        limit: 3,
      );
      expect(
        createRows.map((row) => row['uid']),
        isNot(contains('old-create-new-update')),
      );

      final updateRows = await db.listMemos(
        state: 'NORMAL',
        sortOrder: MemoSortOrder.updateDesc,
        limit: 3,
      );
      expect(updateRows.first['uid'], 'old-create-new-update');

      await db.close();
      await deleteTestDatabase(dbName);
    },
  );

  test('listMemos matches searchable clip metadata and tag text', () async {
    final dbName = uniqueDbName('memo_search_metadata');
    final db = AppDatabase(dbName: dbName);
    final now = DateTime.utc(2026, 4, 18, 9, 0).millisecondsSinceEpoch ~/ 1000;

    await _insertMemo(
      db,
      uid: 'memo-meta',
      content: 'plain body',
      tags: const ['focus-room'],
      createTimeSec: now,
    );
    await db.upsertMemoClipCard(
      MemoClipCardMetadata(
        memoUid: 'memo-meta',
        clipKind: MemoClipKind.article,
        platform: MemoClipPlatform.web,
        sourceName: 'Quiet Journal',
        sourceAvatarUrl: '',
        authorName: 'Ada',
        authorAvatarUrl: '',
        sourceUrl: 'https://journal.example.com/entry',
        leadImageUrl: '',
        parserTag: '',
        createdTime: DateTime.fromMillisecondsSinceEpoch(
          now * 1000,
          isUtc: true,
        ).toLocal(),
        updatedTime: DateTime.fromMillisecondsSinceEpoch(
          now * 1000,
          isUtc: true,
        ).toLocal(),
      ),
    );

    expect(
      (await db.listMemos(searchQuery: 'journal')).map((row) => row['uid']),
      contains('memo-meta'),
    );
    expect(
      (await db.listMemos(searchQuery: 'focus-room')).map((row) => row['uid']),
      contains('memo-meta'),
    );

    await db.close();
    await deleteTestDatabase(dbName);
  });

  test('listMemos bounds dirty fallback across backlog sizes', () async {
    final now = DateTime.utc(2026, 4, 18, 10, 0).millisecondsSinceEpoch ~/ 1000;

    for (final backlogSize in const <int>[0, 64, 500, 2000]) {
      final dbName = uniqueDbName('memo_search_dirty_backlog_$backlogSize');
      final db = AppDatabase(
        dbName: dbName,
        enableMemoSearchBackgroundMaintenance: false,
      );
      final sqlite = await db.db;
      await _insertDirtyMemoBacklog(
        sqlite,
        count: backlogSize,
        createTimeStartSec: now,
        needleIndex: backlogSize == 0 ? null : 0,
      );

      final initialRows = await db.listMemos(searchQuery: 'needle');
      final initialUids = initialRows.map((row) => row['uid']);

      if (backlogSize == 0) {
        expect(initialUids, isEmpty);
        expect(await _countTable(sqlite, 'memo_search_dirty'), 0);
        await db.close();
        await deleteTestDatabase(dbName);
        continue;
      }

      if (backlogSize <= MemoSearchDbPersistence.defaultDirtyFallbackLimit) {
        expect(initialUids, contains('memo-0000'));
      } else {
        expect(initialUids, isNot(contains('memo-0000')));
      }
      expect(await _countTable(sqlite, 'memo_search_dirty'), backlogSize);

      final processed = await db.drainMemoSearchDirtyEntries(limit: 64);
      final maintainedRows = await db.listMemos(searchQuery: 'needle');

      expect(processed, backlogSize < 64 ? backlogSize : 64);
      expect(maintainedRows.map((row) => row['uid']), contains('memo-0000'));
      expect(
        await _countTable(sqlite, 'memo_search_dirty'),
        backlogSize > 64 ? backlogSize - 64 : 0,
      );

      await db.close();
      await deleteTestDatabase(dbName);
    }
  });

  test(
    'dirty fallback keeps an edited memo searchable before maintenance',
    () async {
      final dbName = uniqueDbName('memo_search_incremental');
      final db = AppDatabase(
        dbName: dbName,
        enableMemoSearchBackgroundMaintenance: false,
      );
      final now =
          DateTime.utc(2026, 4, 18, 11, 0).millisecondsSinceEpoch ~/ 1000;

      await _insertMemo(
        db,
        uid: 'memo-a',
        content: 'alpha body',
        createTimeSec: now,
      );
      await _insertMemo(
        db,
        uid: 'memo-b',
        content: 'beta body',
        createTimeSec: now + 1,
      );

      final sqlite = await db.db;
      await db.drainMemoSearchDirtyEntries(limit: 64);
      expect(await _countTable(sqlite, 'memo_search_dirty'), 0);
      expect(await _countTable(sqlite, 'memo_search_documents'), 2);

      await db.upsertMemo(
        uid: 'memo-b',
        content: 'beta updated needle',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now + 1,
        updateTimeSec: now + 2,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 0,
        lastError: null,
      );

      expect(await _countTable(sqlite, 'memo_search_dirty'), 1);
      expect(
        (await db.listMemos(searchQuery: 'needle')).map((row) => row['uid']),
        contains('memo-b'),
      );
      expect(await _countTable(sqlite, 'memo_search_dirty'), 1);
      expect(await db.drainMemoSearchDirtyEntries(limit: 64), 1);
      expect(await _countTable(sqlite, 'memo_search_dirty'), 0);
      expect(await _countTable(sqlite, 'memo_search_documents'), 2);

      await db.close();
      await deleteTestDatabase(dbName);
    },
  );

  test('listMemos applies SQLite-owned advanced filter candidates', () async {
    final dbName = uniqueDbName('memo_search_sql_filters');
    final db = AppDatabase(
      dbName: dbName,
      enableMemoSearchBackgroundMaintenance: false,
    );
    final now = DateTime.utc(2026, 4, 18, 13, 0).millisecondsSinceEpoch ~/ 1000;

    await _insertMemo(
      db,
      uid: 'memo-match',
      content: 'needle with all sql filters',
      createTimeSec: now,
      attachments: const <Map<String, dynamic>>[
        <String, dynamic>{'filename': 'photo.jpg', 'type': 'image/jpeg'},
      ],
      location: const MemoLocation(
        placeholder: 'Shanghai',
        latitude: 31.2,
        longitude: 121.5,
      ),
      relationCount: 2,
    );
    await _insertMemo(
      db,
      uid: 'memo-no-location',
      content: 'needle without location',
      createTimeSec: now,
      attachments: const <Map<String, dynamic>>[
        <String, dynamic>{'filename': 'photo.jpg', 'type': 'image/jpeg'},
      ],
      relationCount: 2,
    );
    await _insertMemo(
      db,
      uid: 'memo-no-attachment',
      content: 'needle without attachment',
      createTimeSec: now,
      location: const MemoLocation(
        placeholder: 'Shanghai',
        latitude: 31.2,
        longitude: 121.5,
      ),
      relationCount: 2,
    );
    await _insertMemo(
      db,
      uid: 'memo-no-relation',
      content: 'needle without relation',
      createTimeSec: now,
      attachments: const <Map<String, dynamic>>[
        <String, dynamic>{'filename': 'photo.jpg', 'type': 'image/jpeg'},
      ],
      location: const MemoLocation(
        placeholder: 'Shanghai',
        latitude: 31.2,
        longitude: 121.5,
      ),
    );

    await db.drainMemoSearchDirtyEntries(limit: 64);

    final rows = await db.listMemos(
      searchQuery: 'needle',
      searchFilters: const MemoSearchDbFilters(
        hasLocation: true,
        hasAttachments: true,
        hasRelations: true,
      ),
    );

    expect(rows.map((row) => row['uid']), <String>['memo-match']);

    await db.close();
    await deleteTestDatabase(dbName);
  });

  test(
    'rebuildMemoSearchIndex restores searchability without changing memo',
    () async {
      final dbName = uniqueDbName('memo_search_rebuild_facade');
      final db = AppDatabase(dbName: dbName);
      final now =
          DateTime.utc(2026, 4, 18, 12, 0).millisecondsSinceEpoch ~/ 1000;

      await _insertMemo(
        db,
        uid: 'memo-search-repair',
        content: 'searchable repair needle',
        createTimeSec: now,
      );
      final sqlite = await db.db;
      await sqlite.delete('memo_search_substrings');
      await sqlite.delete('memo_search_documents');
      await sqlite.delete('memo_search_dirty');

      expect(
        (await db.listMemos(searchQuery: 'needle')).map((row) => row['uid']),
        isNot(contains('memo-search-repair')),
      );

      await db.rebuildMemoSearchIndex();

      final row = await db.getMemoByUid('memo-search-repair');
      expect(row?['content'], 'searchable repair needle');
      expect(
        (await db.listMemos(searchQuery: 'needle')).map((row) => row['uid']),
        contains('memo-search-repair'),
      );
      expect(await _countTable(sqlite, 'memo_search_dirty'), 0);
      expect(await _countTable(sqlite, 'memo_search_documents'), 1);

      await db.close();
      await deleteTestDatabase(dbName);
    },
  );
}

Future<void> _insertMemo(
  AppDatabase db, {
  required String uid,
  required String content,
  required int createTimeSec,
  int? updateTimeSec,
  String state = 'NORMAL',
  List<String> tags = const <String>[],
  List<Map<String, dynamic>> attachments = const <Map<String, dynamic>>[],
  MemoLocation? location,
  int relationCount = 0,
}) {
  return db.upsertMemo(
    uid: uid,
    content: content,
    visibility: 'PRIVATE',
    pinned: false,
    state: state,
    createTimeSec: createTimeSec,
    updateTimeSec: updateTimeSec ?? createTimeSec,
    tags: tags,
    attachments: attachments,
    location: location,
    relationCount: relationCount,
    syncState: 0,
    lastError: null,
  );
}

Future<int> _countTable(Database sqlite, String table) async {
  final rows = await sqlite.rawQuery('SELECT COUNT(*) AS c FROM $table;');
  final value = rows.first['c'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

Future<void> _insertDirtyMemoBacklog(
  Database sqlite, {
  required int count,
  required int createTimeStartSec,
  required int? needleIndex,
}) async {
  if (count <= 0) return;
  await sqlite.transaction((txn) async {
    final batch = txn.batch();
    final updatedMs = DateTime.utc(2026, 4, 18, 10).millisecondsSinceEpoch;
    for (var index = 0; index < count; index += 1) {
      final uid = 'memo-${index.toString().padLeft(4, '0')}';
      batch.insert('memos', <String, Object?>{
        'uid': uid,
        'content': index == needleIndex ? 'oldest needle body' : 'body $index',
        'visibility': 'PRIVATE',
        'pinned': 0,
        'state': 'NORMAL',
        'create_time': createTimeStartSec + index,
        'display_time': createTimeStartSec + index,
        'update_time': createTimeStartSec + index,
        'tags': '',
        'attachments_json': '[]',
        'location_placeholder': null,
        'location_lat': null,
        'location_lng': null,
        'relation_count': 0,
        'sync_state': 0,
        'last_error': null,
      });
      batch.insert('memo_search_dirty', <String, Object?>{
        'memo_uid': uid,
        'memo_row_id': index + 1,
        'updated_time': updatedMs + index,
      });
    }
    await batch.commit(noResult: true);
  });
}
