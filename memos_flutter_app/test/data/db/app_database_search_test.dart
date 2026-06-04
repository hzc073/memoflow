import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/memo_clip_card_metadata.dart';
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

  test(
    'listMemos returns still-dirty matches beyond the drain batch and keeps backlog incremental',
    () async {
      final dbName = uniqueDbName('memo_search_dirty_backlog');
      final db = AppDatabase(dbName: dbName);
      final now =
          DateTime.utc(2026, 4, 18, 10, 0).millisecondsSinceEpoch ~/ 1000;

      for (var index = 0; index < 70; index += 1) {
        final id = index.toString().padLeft(3, '0');
        final content = index == 69 ? 'tail needle body' : 'body $id';
        await _insertMemo(
          db,
          uid: 'memo-$id',
          content: content,
          createTimeSec: now + index,
        );
      }

      final rows = await db.listMemos(searchQuery: 'needle');
      final sqlite = await db.db;
      final dirtyCount = await _countTable(sqlite, 'memo_search_dirty');

      expect(rows.map((row) => row['uid']), contains('memo-069'));
      expect(dirtyCount, greaterThan(0));
      expect(dirtyCount, lessThan(70));

      await db.close();
      await deleteTestDatabase(dbName);
    },
  );

  test('listMemos rebuilds only the touched memo after an edit', () async {
    final dbName = uniqueDbName('memo_search_incremental');
    final db = AppDatabase(dbName: dbName);
    final now = DateTime.utc(2026, 4, 18, 11, 0).millisecondsSinceEpoch ~/ 1000;

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

    await db.listMemos(searchQuery: 'body');
    final sqlite = await db.db;
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
    expect(await _countTable(sqlite, 'memo_search_dirty'), 0);
    expect(await _countTable(sqlite, 'memo_search_documents'), 2);

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
    attachments: const <Map<String, dynamic>>[],
    location: null,
    relationCount: 0,
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
