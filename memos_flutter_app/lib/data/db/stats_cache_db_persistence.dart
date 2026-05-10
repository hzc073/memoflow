import 'package:sqflite/sqflite.dart';

import '../../core/memo_search_document_builder.dart';

typedef StatsCacheTransactionRunner =
    Future<T> Function<T>(
      Database db,
      Future<T> Function(Transaction txn) action,
    );

final class StatsCacheMemoSnapshot {
  const StatsCacheMemoSnapshot({
    required this.state,
    required this.createTimeSec,
    required this.content,
    required this.tags,
  });

  final String state;
  final int createTimeSec;
  final String content;
  final List<String> tags;
}

final class StatsCacheDbPersistence {
  const StatsCacheDbPersistence._();

  static Future<void> ensureTables(
    Database db, {
    required StatsCacheTransactionRunner runTransaction,
    required int maintenanceBatchSize,
    bool rebuild = false,
  }) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS stats_cache (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  total_memos INTEGER NOT NULL DEFAULT 0,
  archived_memos INTEGER NOT NULL DEFAULT 0,
  total_chars INTEGER NOT NULL DEFAULT 0,
  min_create_time INTEGER,
  updated_time INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS daily_counts_cache (
  day TEXT PRIMARY KEY,
  memo_count INTEGER NOT NULL DEFAULT 0
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS tag_stats_cache (
  tag TEXT PRIMARY KEY,
  memo_count INTEGER NOT NULL DEFAULT 0
);
''');

    if (rebuild) {
      await rebuildStatsCache(
        db,
        runTransaction: runTransaction,
        maintenanceBatchSize: maintenanceBatchSize,
      );
      return;
    }

    try {
      final rows = await db.query(
        'stats_cache',
        columns: const ['id'],
        where: 'id = 1',
        limit: 1,
      );
      if (rows.isEmpty) {
        await rebuildStatsCache(
          db,
          runTransaction: runTransaction,
          maintenanceBatchSize: maintenanceBatchSize,
        );
      }
    } catch (_) {
      await rebuildStatsCache(
        db,
        runTransaction: runTransaction,
        maintenanceBatchSize: maintenanceBatchSize,
      );
    }
  }

  static Future<Map<String, dynamic>?> getStatsCacheRow(
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(
      'stats_cache',
      columns: const [
        'total_memos',
        'archived_memos',
        'total_chars',
        'min_create_time',
      ],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<List<Map<String, dynamic>>> listDailyCountRows(
    DatabaseExecutor executor,
  ) {
    return executor.query(
      'daily_counts_cache',
      columns: const ['day', 'memo_count'],
    );
  }

  static Future<List<Map<String, dynamic>>> listTagStatsRows(
    DatabaseExecutor executor,
  ) async {
    try {
      final rows = await executor.rawQuery('''
SELECT t.id, t.parent_id, t.path, t.pinned, t.color_hex,
       COALESCE(ts.memo_count, 0) AS memo_count,
       MAX(m.update_time) AS last_used_time
FROM tags t
LEFT JOIN tag_stats_cache ts ON ts.tag = t.path
LEFT JOIN memo_tags mt ON mt.tag_id = t.id
LEFT JOIN memos m ON m.uid = mt.memo_uid AND m.state = 'NORMAL'
GROUP BY t.id, t.parent_id, t.path, t.pinned, t.color_hex, ts.memo_count;
''');
      final seenPaths = <String>{};
      for (final row in rows) {
        final path = row['path'];
        if (path is String && path.trim().isNotEmpty) {
          seenPaths.add(path.trim());
        }
      }

      final cacheRows = await executor.query(
        'tag_stats_cache',
        columns: const ['tag', 'memo_count'],
      );
      if (cacheRows.isEmpty) return rows;

      final combined = List<Map<String, dynamic>>.of(rows);
      for (final row in cacheRows) {
        final tag = row['tag'];
        if (tag is! String || tag.trim().isEmpty) continue;
        final trimmed = tag.trim();
        if (seenPaths.contains(trimmed)) continue;
        combined.add(row);
      }
      return combined;
    } catch (_) {
      return executor.query(
        'tag_stats_cache',
        columns: const ['tag', 'memo_count'],
      );
    }
  }

  static Future<StatsCacheMemoSnapshot?> fetchMemoSnapshot(
    DatabaseExecutor executor,
    String uid,
  ) async {
    final rows = await executor.query(
      'memos',
      columns: const ['state', 'create_time', 'content', 'tags'],
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final state = (row['state'] as String?) ?? 'NORMAL';
    final createTimeSec = _readInt(row['create_time']) ?? 0;
    final content = (row['content'] as String?) ?? '';
    final tagsText = (row['tags'] as String?) ?? '';
    return StatsCacheMemoSnapshot(
      state: state,
      createTimeSec: createTimeSec,
      content: content,
      tags: _splitTagsText(tagsText),
    );
  }

  static Map<String, dynamic>? memoSnapshotToPayload(
    StatsCacheMemoSnapshot? snapshot,
  ) {
    if (snapshot == null) return null;
    return <String, dynamic>{
      'state': snapshot.state,
      'createTimeSec': snapshot.createTimeSec,
      'content': snapshot.content,
      'tags': snapshot.tags,
    };
  }

  static StatsCacheMemoSnapshot? memoSnapshotFromPayload(
    Map<String, dynamic>? payload,
  ) {
    if (payload == null) return null;
    final rawTags = payload['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final entry in rawTags) {
        if (entry is String && entry.trim().isNotEmpty) {
          tags.add(entry.trim());
        }
      }
    }
    return StatsCacheMemoSnapshot(
      state: (payload['state'] as String?) ?? '',
      createTimeSec: _readInt(payload['createTimeSec']) ?? 0,
      content: (payload['content'] as String?) ?? '',
      tags: tags,
    );
  }

  static Map<String, dynamic> createMemoSnapshotPayload({
    required String state,
    required int createTimeSec,
    required String content,
    required List<String> tags,
  }) {
    return memoSnapshotToPayload(
          StatsCacheMemoSnapshot(
            state: state,
            createTimeSec: createTimeSec,
            content: content,
            tags: tags,
          ),
        ) ??
        const <String, dynamic>{};
  }

  static Future<void> applyMemoCacheDelta(
    DatabaseExecutor executor, {
    required StatsCacheMemoSnapshot? before,
    required StatsCacheMemoSnapshot? after,
  }) async {
    if (before == null && after == null) return;

    await _ensureStatsCacheRow(executor);
    final statsRows = await executor.query(
      'stats_cache',
      columns: const ['min_create_time'],
      where: 'id = 1',
      limit: 1,
    );
    final currentMin = statsRows.isEmpty
        ? null
        : _readInt(statsRows.first['min_create_time']);

    final oldState = before?.state ?? '';
    final newState = after?.state ?? '';
    final oldIsNormal = oldState == 'NORMAL';
    final newIsNormal = newState == 'NORMAL';
    final oldIsArchived = oldState == 'ARCHIVED';
    final newIsArchived = newState == 'ARCHIVED';

    final deltaTotal = (newIsNormal ? 1 : 0) - (oldIsNormal ? 1 : 0);
    final deltaArchived = (newIsArchived ? 1 : 0) - (oldIsArchived ? 1 : 0);

    final oldChars = oldIsNormal && before != null
        ? _countChars(before.content)
        : 0;
    final newChars = newIsNormal && after != null
        ? _countChars(after.content)
        : 0;
    final deltaChars = newChars - oldChars;

    final oldDayKey = oldIsNormal && before != null
        ? _localDayKeyFromUtcSec(before.createTimeSec)
        : null;
    final newDayKey = newIsNormal && after != null
        ? _localDayKeyFromUtcSec(after.createTimeSec)
        : null;
    if (!(oldIsNormal && newIsNormal && oldDayKey == newDayKey)) {
      if (oldDayKey != null) {
        await _bumpDailyCount(executor, oldDayKey, -1);
      }
      if (newDayKey != null) {
        await _bumpDailyCount(executor, newDayKey, 1);
      }
    }

    final oldTagCounts = oldIsNormal && before != null
        ? _countTags(before.tags)
        : const <String, int>{};
    final newTagCounts = newIsNormal && after != null
        ? _countTags(after.tags)
        : const <String, int>{};
    if (oldTagCounts.isNotEmpty || newTagCounts.isNotEmpty) {
      final allTags = <String>{...oldTagCounts.keys, ...newTagCounts.keys};
      for (final tag in allTags) {
        final delta = (newTagCounts[tag] ?? 0) - (oldTagCounts[tag] ?? 0);
        if (delta != 0) {
          await _bumpTagCount(executor, tag, delta);
        }
      }
    }

    final nextMin = await _resolveMinCreateTime(
      executor,
      currentMin: currentMin,
      before: before,
      after: after,
    );
    if (deltaTotal != 0 ||
        deltaArchived != 0 ||
        deltaChars != 0 ||
        nextMin != currentMin) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await executor.rawUpdate(
        '''
UPDATE stats_cache
SET total_memos = total_memos + ?,
    archived_memos = archived_memos + ?,
    total_chars = total_chars + ?,
    min_create_time = ?,
    updated_time = ?
WHERE id = 1;
''',
        [deltaTotal, deltaArchived, deltaChars, nextMin, now],
      );
    }
  }

  static Future<void> rebuildStatsCache(
    Database db, {
    required StatsCacheTransactionRunner runTransaction,
    required int maintenanceBatchSize,
  }) async {
    await runTransaction<void>(db, (txn) async {
      await txn.delete('stats_cache');
      await txn.delete('daily_counts_cache');
      await txn.delete('tag_stats_cache');
    });

    var totalMemos = 0;
    var archivedMemos = 0;
    var totalChars = 0;
    int? minCreateTime;
    final dailyCounts = <String, int>{};
    final tagCounts = <String, int>{};

    var lastId = 0;
    while (true) {
      final rows = await db.query(
        'memos',
        columns: const ['id', 'state', 'create_time', 'content', 'tags'],
        where: 'id > ?',
        whereArgs: [lastId],
        orderBy: 'id ASC',
        limit: maintenanceBatchSize,
      );
      if (rows.isEmpty) break;
      lastId = _readInt(rows.last['id']) ?? lastId;
      for (final row in rows) {
        final state = (row['state'] as String?) ?? 'NORMAL';
        final createTimeSec = _readInt(row['create_time']) ?? 0;
        final content = (row['content'] as String?) ?? '';
        final tagsText = (row['tags'] as String?) ?? '';

        if (createTimeSec > 0) {
          if (minCreateTime == null || createTimeSec < minCreateTime) {
            minCreateTime = createTimeSec;
          }
        }

        if (state == 'ARCHIVED') {
          archivedMemos++;
          continue;
        }
        if (state != 'NORMAL') {
          continue;
        }

        totalMemos++;
        totalChars += _countChars(content);

        final dayKey = _localDayKeyFromUtcSec(createTimeSec);
        if (dayKey != null) {
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
        }

        for (final tag in _splitTagsText(tagsText)) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await runTransaction<void>(db, (txn) async {
      await txn.insert('stats_cache', {
        'id': 1,
        'total_memos': totalMemos,
        'archived_memos': archivedMemos,
        'total_chars': totalChars,
        'min_create_time': minCreateTime,
        'updated_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (dailyCounts.isNotEmpty || tagCounts.isNotEmpty) {
        final batch = txn.batch();
        dailyCounts.forEach((day, count) {
          batch.insert('daily_counts_cache', {
            'day': day,
            'memo_count': count,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
        tagCounts.forEach((tag, count) {
          batch.insert('tag_stats_cache', {
            'tag': tag,
            'memo_count': count,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
        await batch.commit(noResult: true);
      }
    });
  }

  static Future<void> _ensureStatsCacheRow(DatabaseExecutor executor) async {
    final rows = await executor.query(
      'stats_cache',
      columns: const ['id'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await executor.insert('stats_cache', {
      'id': 1,
      'total_memos': 0,
      'archived_memos': 0,
      'total_chars': 0,
      'min_create_time': null,
      'updated_time': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _bumpDailyCount(
    DatabaseExecutor executor,
    String dayKey,
    int delta,
  ) async {
    if (dayKey.trim().isEmpty || delta == 0) return;
    final rows = await executor.query(
      'daily_counts_cache',
      columns: const ['memo_count'],
      where: 'day = ?',
      whereArgs: [dayKey],
      limit: 1,
    );
    final current = rows.isEmpty
        ? 0
        : (_readInt(rows.first['memo_count']) ?? 0);
    final next = current + delta;
    if (next <= 0) {
      await executor.delete(
        'daily_counts_cache',
        where: 'day = ?',
        whereArgs: [dayKey],
      );
      return;
    }
    if (rows.isEmpty) {
      await executor.insert('daily_counts_cache', {
        'day': dayKey,
        'memo_count': next,
      });
      return;
    }
    await executor.update(
      'daily_counts_cache',
      {'memo_count': next},
      where: 'day = ?',
      whereArgs: [dayKey],
    );
  }

  static Future<void> _bumpTagCount(
    DatabaseExecutor executor,
    String tag,
    int delta,
  ) async {
    final key = tag.trim();
    if (key.isEmpty || delta == 0) return;
    final rows = await executor.query(
      'tag_stats_cache',
      columns: const ['memo_count'],
      where: 'tag = ?',
      whereArgs: [key],
      limit: 1,
    );
    final current = rows.isEmpty
        ? 0
        : (_readInt(rows.first['memo_count']) ?? 0);
    final next = current + delta;
    if (next <= 0) {
      await executor.delete(
        'tag_stats_cache',
        where: 'tag = ?',
        whereArgs: [key],
      );
      return;
    }
    if (rows.isEmpty) {
      await executor.insert('tag_stats_cache', {
        'tag': key,
        'memo_count': next,
      });
      return;
    }
    await executor.update(
      'tag_stats_cache',
      {'memo_count': next},
      where: 'tag = ?',
      whereArgs: [key],
    );
  }

  static Future<int?> _queryMinCreateTime(DatabaseExecutor executor) async {
    final rows = await executor.rawQuery(
      'SELECT MIN(create_time) AS min_time FROM memos;',
    );
    if (rows.isEmpty) return null;
    return _readInt(rows.first['min_time']);
  }

  static Future<int?> _resolveMinCreateTime(
    DatabaseExecutor executor, {
    required int? currentMin,
    required StatsCacheMemoSnapshot? before,
    required StatsCacheMemoSnapshot? after,
  }) async {
    var nextMin = currentMin;
    final beforeTime = before?.createTimeSec;
    final afterTime = after?.createTimeSec;

    if (afterTime != null && afterTime > 0) {
      if (nextMin == null || afterTime < nextMin) {
        nextMin = afterTime;
      }
    }

    final removedMin =
        beforeTime != null &&
        currentMin != null &&
        beforeTime == currentMin &&
        (afterTime == null || afterTime > currentMin);
    if (removedMin) {
      nextMin = await _queryMinCreateTime(executor);
    }
    return nextMin;
  }

  static int _countChars(String content) {
    if (content.isEmpty) return 0;
    return content.replaceAll(RegExp(r'\s+'), '').runes.length;
  }

  static String? _localDayKeyFromUtcSec(int createTimeSec) {
    if (createTimeSec <= 0) return null;
    final dtLocal = DateTime.fromMillisecondsSinceEpoch(
      createTimeSec * 1000,
      isUtc: true,
    ).toLocal();
    final y = dtLocal.year.toString().padLeft(4, '0');
    final m = dtLocal.month.toString().padLeft(2, '0');
    final d = dtLocal.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static List<String> _splitTagsText(String tagsText) {
    return MemoSearchDocumentBuilder.splitTagsText(tagsText);
  }

  static Map<String, int> _countTags(List<String> tags) {
    if (tags.isEmpty) return const {};
    final counts = <String, int>{};
    for (final tag in tags) {
      final key = tag.trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
