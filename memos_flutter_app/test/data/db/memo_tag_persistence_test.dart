import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/core/tags.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/state/maintenance/self_repair_mutation_service.dart';
import 'package:memos_flutter_app/state/tags/tag_repository.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test('memo creation keeps memo_tags and memos.tags in agreement', () async {
    final dbName = uniqueDbName('memo_tag_create_consistency');
    final db = AppDatabase(dbName: dbName);
    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await _upsertMemo(
      db,
      uid: 'memo-1',
      content: 'hello #alpha and #beta',
      tags: const ['alpha', 'beta'],
    );

    expect((await db.getMemoByUid('memo-1'))?['tags'], 'alpha beta');
    expect(await _memoTagPaths(db, 'memo-1'), const ['alpha', 'beta']);
  });

  test(
    'tag rename move and delete keep text, mapping, search, and stats aligned',
    () async {
      final dbName = uniqueDbName('memo_tag_hierarchy_consistency');
      final db = AppDatabase(dbName: dbName);
      final repository = TagRepository(db: db);
      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final topic = await repository.createTag(name: 'topic');
      await _upsertMemo(
        db,
        uid: 'memo-1',
        content: '#topic\n\ntracked',
        tags: const ['topic'],
      );

      final renamed = await repository.updateTag(id: topic.id, name: 'renamed');
      expect((await db.getMemoByUid('memo-1'))?['tags'], 'renamed');
      expect(await _memoTagPaths(db, 'memo-1'), const ['renamed']);
      expect(await _memoUidsForTag(db, 'renamed'), const ['memo-1']);
      expect(await _memoUidsForSearch(db, 'renamed'), const ['memo-1']);
      expect(await _tagStats(db), containsPair('renamed', 1));

      final parent = await repository.createTag(name: 'area');
      final moved = await repository.updateTag(
        id: renamed.id,
        parentId: parent.id,
      );
      expect(moved.path, 'area/renamed');
      expect((await db.getMemoByUid('memo-1'))?['tags'], 'area/renamed');
      expect(await _memoTagPaths(db, 'memo-1'), const ['area/renamed']);
      expect(await _memoUidsForTag(db, 'area/renamed'), const ['memo-1']);
      expect(await _memoUidsForSearch(db, 'area/renamed'), const ['memo-1']);
      expect(await _tagStats(db), containsPair('area/renamed', 1));

      await repository.deleteTag(moved.id);
      expect((await db.getMemoByUid('memo-1'))?['tags'], '');
      expect(await _memoTagPaths(db, 'memo-1'), isEmpty);
      expect(await _memoUidsForTag(db, 'area/renamed'), isEmpty);
      expect(await _memoUidsForSearch(db, 'area/renamed'), isEmpty);
      expect(await _tagStats(db), isNot(containsPair('area/renamed', 1)));
    },
  );

  test(
    'code-context false tags do not appear in tag stats or tag search data',
    () async {
      final dbName = uniqueDbName('memo_tag_code_context_consistency');
      final db = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await _upsertMemo(
        db,
        uid: 'memo-1',
        content: '#real\n\n```c\n#include <stdio.h>\n```\nafter',
        tags: const ['real'],
      );

      expect((await db.getMemoByUid('memo-1'))?['tags'], 'real');
      expect(await _memoTagPaths(db, 'memo-1'), const ['real']);
      expect(await _memoUidsForTag(db, 'include'), isEmpty);
      expect(await _ftsTagsForMemo(db, 'memo-1'), 'real');
      expect(await _tagStats(db), isNot(contains('include')));
      expect(await _tagStats(db), containsPair('real', 1));
    },
  );

  test(
    'explicit rebuild removes historical code false positives and keeps real tags',
    () async {
      final dbName = uniqueDbName('memo_tag_rebuild_from_content');
      final db = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await _upsertMemo(
        db,
        uid: 'memo-1',
        content: '#real\n\n```c\n#include <stdio.h>\n```\nafter',
        tags: const ['include', 'real'],
      );
      expect((await db.getMemoByUid('memo-1'))?['tags'], 'include real');
      expect(await _memoTagPaths(db, 'memo-1'), const ['include', 'real']);
      final includeTagId = await _tagIdByPath(db, 'include');
      expect(includeTagId, isNotNull);
      final sqlite = await db.db;
      await sqlite.insert('tag_aliases', {
        'tag_id': includeTagId!,
        'alias': 'legacy-include',
        'created_time': 1735689600,
      });

      await SelfRepairMutationService(db: db).repairTagsFromContent();

      expect((await db.getMemoByUid('memo-1'))?['tags'], 'real');
      expect(await _memoTagPaths(db, 'memo-1'), const ['real']);
      expect(await _memoUidsForTag(db, 'include'), isEmpty);
      expect(await _memoUidsForSearch(db, 'real'), const ['memo-1']);
      expect(await _ftsTagsForMemo(db, 'memo-1'), 'real');
      expect((await _tagStats(db)).containsKey('include'), isFalse);
      expect(await _tagIdByPath(db, 'include'), isNull);
      expect(await _tagAliasCountByTagId(db, includeTagId), 0);
      expect(await _tagStats(db), containsPair('real', 1));
    },
  );

  test(
    'explicit rebuild removes historical prose hash false positives',
    () async {
      final dbName = uniqueDbName('memo_tag_rebuild_removes_prose_hash');
      final db = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      const legacyTag = '\u8FD9\u662F\u6D4B\u8BD5\u6587\u672C';
      await _upsertMemo(
        db,
        uid: 'memo-1',
        content: '\u6D4B\u8BD5\u6587\u672C #$legacyTag',
        tags: const [legacyTag],
      );

      expect((await db.getMemoByUid('memo-1'))?['tags'], legacyTag);
      expect(await _memoTagPaths(db, 'memo-1'), const [legacyTag]);

      await SelfRepairMutationService(db: db).repairTagsFromContent();

      expect((await db.getMemoByUid('memo-1'))?['tags'], '');
      expect(await _memoTagPaths(db, 'memo-1'), isEmpty);
      expect(await _memoUidsForTag(db, legacyTag), isEmpty);
      expect(await _ftsTagsForMemo(db, 'memo-1'), '');
      expect(await _tagIdByPath(db, legacyTag), isNull);
      expect((await _tagStats(db)).containsKey(legacyTag), isFalse);
    },
  );

  test(
    'policy-aware rebuild keeps inline tags under compatible policy',
    () async {
      final dbName = uniqueDbName('memo_tag_rebuild_compatible_inline');
      final db = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await _upsertMemo(
        db,
        uid: 'memo-1',
        content: 'Today #life',
        tags: const <String>[],
      );

      await SelfRepairMutationService(
        db: db,
      ).repairTagsFromContent(policy: TagRecognitionPolicy.memosCompatible);

      expect((await db.getMemoByUid('memo-1'))?['tags'], 'life');
      expect(await _memoTagPaths(db, 'memo-1'), const ['life']);
      expect(await _memoUidsForTag(db, 'life'), const ['memo-1']);
      expect(await _ftsTagsForMemo(db, 'memo-1'), 'life');
      expect(await _tagStats(db), containsPair('life', 1));
    },
  );

  test(
    'policy-aware rebuild follows custom options and prunes rejected tags',
    () async {
      final dbName = uniqueDbName('memo_tag_rebuild_custom_options');
      final db = AppDatabase(dbName: dbName);
      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await _upsertMemo(
        db,
        uid: 'memo-1',
        content: 'Today #life Issue #123 #work/project',
        tags: const ['123', 'life', 'work/project'],
      );
      expect(await _tagIdByPath(db, '123'), isNotNull);
      expect(await _tagIdByPath(db, 'work/project'), isNotNull);

      final policy = TagRecognitionPolicy.custom(
        const TagRecognitionCustomOptions(
          inlineBodyTags: true,
          numericOnlyTags: false,
          hierarchicalTags: false,
        ),
      );
      await SelfRepairMutationService(
        db: db,
      ).repairTagsFromContent(policy: policy);

      expect((await db.getMemoByUid('memo-1'))?['tags'], 'life');
      expect(await _memoTagPaths(db, 'memo-1'), const ['life']);
      expect(await _memoUidsForTag(db, '123'), isEmpty);
      expect(await _memoUidsForTag(db, 'work/project'), isEmpty);
      expect(await _ftsTagsForMemo(db, 'memo-1'), 'life');
      expect(await _tagIdByPath(db, '123'), isNull);
      expect(await _tagIdByPath(db, 'work/project'), isNull);
      expect(await _tagStats(db), containsPair('life', 1));
      expect((await _tagStats(db)).containsKey('123'), isFalse);
    },
  );

  test('self repair recursively prunes hierarchical orphan tags', () async {
    final dbName = uniqueDbName('self_repair_prunes_orphan_tag_hierarchy');
    final db = AppDatabase(dbName: dbName);
    final repository = TagRepository(db: db);
    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final parent = await repository.createTag(name: 'area');
    final child = await repository.createTag(
      name: 'project',
      parentId: parent.id,
    );
    await repository.createTag(name: 'phase', parentId: child.id);

    expect(await _allTagPaths(db), const [
      'area',
      'area/project',
      'area/project/phase',
    ]);

    await SelfRepairMutationService(db: db).repairTagsFromContent();

    expect(await _allTagPaths(db), isEmpty);
    expect(await _tagStats(db), isEmpty);
  });

  test(
    'self repair preserves referenced tags while pruning unrelated orphans',
    () async {
      final dbName = uniqueDbName('self_repair_preserves_referenced_tags');
      final db = AppDatabase(dbName: dbName);
      final repository = TagRepository(db: db);
      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await _upsertMemo(
        db,
        uid: 'memo-1',
        content: '#keep\n\ntracked',
        tags: const ['keep'],
      );
      await repository.createTag(name: 'unused');

      expect(await _tagIdByPath(db, 'keep'), isNotNull);
      expect(await _tagIdByPath(db, 'unused'), isNotNull);

      await SelfRepairMutationService(db: db).repairTagsFromContent();

      expect((await db.getMemoByUid('memo-1'))?['tags'], 'keep');
      expect(await _memoTagPaths(db, 'memo-1'), const ['keep']);
      expect(await _memoUidsForSearch(db, 'keep'), const ['memo-1']);
      expect(await _ftsTagsForMemo(db, 'memo-1'), 'keep');
      expect(await _tagIdByPath(db, 'keep'), isNotNull);
      expect(await _tagIdByPath(db, 'unused'), isNull);
      expect(await _tagStats(db), containsPair('keep', 1));
      expect((await _tagStats(db)).containsKey('unused'), isFalse);
    },
  );

  test('self repair rebuilds stats cache from local memo data', () async {
    final dbName = uniqueDbName('self_repair_stats_cache_rebuild');
    final db = AppDatabase(dbName: dbName);
    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    const content = '#real\n\nhello';
    await _upsertMemo(
      db,
      uid: 'memo-1',
      content: content,
      tags: const ['real'],
    );
    final sqlite = await db.db;
    await sqlite.delete('stats_cache');
    await sqlite.delete('daily_counts_cache');
    await sqlite.delete('tag_stats_cache');

    expect(await db.getStatsCacheRow(), isNull);
    expect(await _tagStats(db), containsPair('real', 0));

    await SelfRepairMutationService(db: db).rebuildStatsCache();

    final stats = await db.getStatsCacheRow();
    expect(stats?['total_memos'], 1);
    expect(
      stats?['total_chars'],
      content.replaceAll(RegExp(r'\s+'), '').length,
    );
    expect(await _tagStats(db), containsPair('real', 1));
    expect(await db.listDailyCountRows(), isNotEmpty);
  });
}

Future<void> _upsertMemo(
  AppDatabase db, {
  required String uid,
  required String content,
  required List<String> tags,
}) {
  const nowSec = 1735689600;
  return db.upsertMemo(
    uid: uid,
    content: content,
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTimeSec: nowSec,
    updateTimeSec: nowSec,
    tags: tags,
    attachments: const <Map<String, dynamic>>[],
    location: null,
    relationCount: 0,
    syncState: 0,
    lastError: null,
  );
}

Future<List<String>> _memoTagPaths(AppDatabase db, String memoUid) async {
  final sqlite = await db.db;
  final rows = await sqlite.rawQuery(
    '''
SELECT t.path
FROM memo_tags mt
JOIN tags t ON t.id = mt.tag_id
WHERE mt.memo_uid = ?
ORDER BY t.path ASC;
''',
    [memoUid],
  );
  return rows.map((row) => row['path'] as String).toList(growable: false);
}

Future<List<String>> _memoUidsForTag(AppDatabase db, String tag) async {
  final rows = await db.listMemos(tag: tag, state: 'NORMAL');
  return rows.map((row) => row['uid'] as String).toList(growable: false);
}

Future<List<String>> _memoUidsForSearch(AppDatabase db, String query) async {
  final rows = await db.listMemos(searchQuery: query, state: 'NORMAL');
  return rows.map((row) => row['uid'] as String).toList(growable: false);
}

Future<String> _ftsTagsForMemo(AppDatabase db, String memoUid) async {
  final sqlite = await db.db;
  final memoRows = await sqlite.query(
    'memos',
    columns: const ['id'],
    where: 'uid = ?',
    whereArgs: [memoUid],
    limit: 1,
  );
  final rowId = memoRows.single['id'] as int;
  final ftsRows = await sqlite.query(
    'memos_fts',
    columns: const ['tags'],
    where: 'rowid = ?',
    whereArgs: [rowId],
    limit: 1,
  );
  return (ftsRows.single['tags'] as String?) ?? '';
}

Future<Map<String, int>> _tagStats(AppDatabase db) async {
  final rows = await db.listTagStatsRows();
  return <String, int>{
    for (final row in rows)
      if ((row['path'] ?? row['tag']) case final String path)
        path: switch (row['memo_count']) {
          int value => value,
          num value => value.toInt(),
          final value => int.tryParse(value.toString()) ?? 0,
        },
  };
}

Future<int?> _tagIdByPath(AppDatabase db, String path) async {
  final sqlite = await db.db;
  final rows = await sqlite.query(
    'tags',
    columns: const ['id'],
    where: 'path = ?',
    whereArgs: [path],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  final id = rows.single['id'];
  if (id is int) return id;
  if (id is num) return id.toInt();
  if (id is String) return int.tryParse(id.trim());
  return null;
}

Future<List<String>> _allTagPaths(AppDatabase db) async {
  final sqlite = await db.db;
  final rows = await sqlite.query(
    'tags',
    columns: const ['path'],
    orderBy: 'path ASC',
  );
  return rows
      .map((row) => row['path'])
      .whereType<String>()
      .toList(growable: false);
}

Future<int> _tagAliasCountByTagId(AppDatabase db, int tagId) async {
  final sqlite = await db.db;
  final rows = await sqlite.rawQuery(
    'SELECT COUNT(*) AS count FROM tag_aliases WHERE tag_id = ?;',
    [tagId],
  );
  final count = rows.single['count'];
  if (count is int) return count;
  if (count is num) return count.toInt();
  if (count is String) return int.tryParse(count.trim()) ?? 0;
  return 0;
}
