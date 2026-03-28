import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/debug_ephemeral_storage.dart';
import '../../core/tags.dart';
import '../models/memo_location.dart';

class AppDatabase {
  AppDatabase({String dbName = 'memos_app.db'}) : _dbName = dbName;

  final String _dbName;
  static const _dbVersion = 17;
  static const int outboxStatePending = 0;
  static const int outboxStateRunning = 1;
  static const int outboxStateRetry = 2;
  static const int outboxStateError = 3;
  static const int outboxStateDone = 4;
  static const String memoDeleteTombstoneStatePendingRemoteDelete =
      'pending_remote_delete';
  static const String memoDeleteTombstoneStateLocalOnly = 'local_only';
  static const int _maintenanceBatchSize = 300;

  Database? _db;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<Database> _open() async {
    final basePath = await resolveDatabasesDirectoryPath();
    final path = p.join(basePath, _dbName);

    Future<Database> open() {
      return openDatabase(
        path,
        // Keep each AppDatabase wrapper on its own SQLite connection.
        // On desktop we can have multiple Flutter engines/provider containers
        // (for example the main app and a settings subwindow) opening the same
        // DB path at once. With sqflite's shared single-instance connection,
        // disposing one wrapper can close the other wrapper's live handle and
        // surface "bad parameter or other API misuse" on the next query.
        singleInstance: false,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          // Native sqflite backends (Android/iOS) treat these PRAGMAs as
          // query-style statements, so use rawQuery for cross-platform safety.
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          final busyTimeoutMs = Platform.isWindows ? 10000 : 5000;
          await db.rawQuery('PRAGMA busy_timeout = $busyTimeoutMs;');
        },
        onCreate: (db, _) async {
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

          await _ensureTagTables(db);

          await db.execute('''
CREATE TABLE IF NOT EXISTS memo_reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  memo_uid TEXT NOT NULL UNIQUE,
  mode TEXT NOT NULL,
  times_json TEXT NOT NULL,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  FOREIGN KEY (memo_uid) REFERENCES memos(uid) ON DELETE CASCADE ON UPDATE CASCADE
);
''');

          await db.execute('''
CREATE TABLE IF NOT EXISTS attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT NOT NULL UNIQUE,
  memo_uid TEXT,
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size INTEGER NOT NULL,
  external_link TEXT,
  create_time INTEGER NOT NULL,
  local_path TEXT,
  downloaded INTEGER NOT NULL DEFAULT 0,
  pending_upload INTEGER NOT NULL DEFAULT 0
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

          await db.execute('''
CREATE TABLE IF NOT EXISTS import_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,
  file_md5 TEXT NOT NULL,
  file_name TEXT NOT NULL,
  memo_count INTEGER NOT NULL DEFAULT 0,
  attachment_count INTEGER NOT NULL DEFAULT 0,
  failed_count INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  error TEXT,
  UNIQUE(source, file_md5)
);
''');

          await db.execute('''
CREATE TABLE IF NOT EXISTS memo_relations_cache (
  memo_uid TEXT NOT NULL PRIMARY KEY,
  relations_json TEXT NOT NULL DEFAULT '[]',
  updated_time INTEGER NOT NULL
);
''');

          await db.execute('''
CREATE TABLE IF NOT EXISTS memo_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  memo_uid TEXT NOT NULL,
  snapshot_time INTEGER NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  payload_json TEXT NOT NULL DEFAULT '{}',
  created_time INTEGER NOT NULL
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_memo_versions_memo_time ON memo_versions(memo_uid, snapshot_time DESC);',
          );

          await db.execute('''
CREATE TABLE IF NOT EXISTS recycle_bin_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_type TEXT NOT NULL,
  memo_uid TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL DEFAULT '',
  payload_json TEXT NOT NULL DEFAULT '{}',
  deleted_time INTEGER NOT NULL,
  expire_time INTEGER NOT NULL
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_recycle_bin_items_deleted_time ON recycle_bin_items(deleted_time DESC);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_recycle_bin_items_expire_time ON recycle_bin_items(expire_time ASC);',
          );
          await db.execute('''
CREATE TABLE IF NOT EXISTS memo_delete_tombstones (
  memo_uid TEXT NOT NULL PRIMARY KEY,
  state TEXT NOT NULL,
  deleted_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  last_error TEXT
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_memo_delete_tombstones_state_updated ON memo_delete_tombstones(state, updated_time DESC);',
          );
          await db.execute('''
CREATE TABLE IF NOT EXISTS memo_inline_image_sources (
  memo_uid TEXT NOT NULL,
  local_url TEXT NOT NULL,
  source_url TEXT NOT NULL,
  updated_time INTEGER NOT NULL,
  PRIMARY KEY (memo_uid, local_url)
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_memo_inline_image_sources_memo ON memo_inline_image_sources(memo_uid, updated_time DESC);',
          );

          await _ensureAiTables(db);

          await _ensureStatsCache(db, rebuild: true);
          await _ensureFts(db, rebuild: true);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            await _recreateFts(db);
          }
          if (oldVersion < 4) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS import_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,
  file_md5 TEXT NOT NULL,
  file_name TEXT NOT NULL,
  memo_count INTEGER NOT NULL DEFAULT 0,
  attachment_count INTEGER NOT NULL DEFAULT 0,
  failed_count INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  error TEXT,
  UNIQUE(source, file_md5)
);
''');
          }
          if (oldVersion < 5) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS memo_reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  memo_uid TEXT NOT NULL UNIQUE,
  mode TEXT NOT NULL,
  times_json TEXT NOT NULL,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  FOREIGN KEY (memo_uid) REFERENCES memos(uid) ON DELETE CASCADE ON UPDATE CASCADE
);
''');
          }
          if (oldVersion < 6) {
            await db.execute(
              'ALTER TABLE memos ADD COLUMN relation_count INTEGER NOT NULL DEFAULT 0;',
            );
          }
          if (oldVersion < 7) {
            await db.execute(
              'ALTER TABLE memos ADD COLUMN location_placeholder TEXT;',
            );
            await db.execute('ALTER TABLE memos ADD COLUMN location_lat REAL;');
            await db.execute('ALTER TABLE memos ADD COLUMN location_lng REAL;');
          }
          if (oldVersion < 8) {
            await _ensureStatsCache(db, rebuild: true);
          }
          if (oldVersion < 9) {
            await _normalizeStoredTags(db);
            await _ensureStatsCache(db, rebuild: true);
          }
          if (oldVersion < 10) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS memo_relations_cache (
  memo_uid TEXT NOT NULL PRIMARY KEY,
  relations_json TEXT NOT NULL DEFAULT '[]',
  updated_time INTEGER NOT NULL
);
''');
          }
          if (oldVersion < 11) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS memo_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  memo_uid TEXT NOT NULL,
  snapshot_time INTEGER NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  payload_json TEXT NOT NULL DEFAULT '{}',
  created_time INTEGER NOT NULL
);
''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_memo_versions_memo_time ON memo_versions(memo_uid, snapshot_time DESC);',
            );
            await db.execute('''
CREATE TABLE IF NOT EXISTS recycle_bin_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_type TEXT NOT NULL,
  memo_uid TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL DEFAULT '',
  payload_json TEXT NOT NULL DEFAULT '{}',
  deleted_time INTEGER NOT NULL,
  expire_time INTEGER NOT NULL
);
''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_recycle_bin_items_deleted_time ON recycle_bin_items(deleted_time DESC);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_recycle_bin_items_expire_time ON recycle_bin_items(expire_time ASC);',
            );
          }
          if (oldVersion < 12) {
            await db.execute('ALTER TABLE outbox ADD COLUMN retry_at INTEGER;');
            // Legacy states: 0=pending, 2=error. Map to new state machine.
            await db.execute(
              'UPDATE outbox SET state = $outboxStateError WHERE state = 2;',
            );
            await db.execute(
              'UPDATE outbox SET state = $outboxStatePending WHERE state = 1;',
            );
            await db.execute(
              'UPDATE outbox SET state = $outboxStatePending WHERE state NOT IN ($outboxStatePending, $outboxStateRetry, $outboxStateError, $outboxStateDone);',
            );
          }
          if (oldVersion < 13) {
            await _ensureTagTables(db);
            await _normalizeStoredTags(db);
            await _backfillTagsFromMemos(db);
            await _ensureStatsCache(db, rebuild: true);
          }
          if (oldVersion < 14) {
            await _ensureAiTables(db);
          }
          if (oldVersion < 15) {
            await _ensureColumnExists(
              db,
              table: 'ai_analysis_tasks',
              column: 'include_public',
              definition: 'include_public INTEGER NOT NULL DEFAULT 1',
            );
          }
          if (oldVersion < 16) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS memo_delete_tombstones (
  memo_uid TEXT NOT NULL PRIMARY KEY,
  state TEXT NOT NULL,
  deleted_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  last_error TEXT
);
''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_memo_delete_tombstones_state_updated ON memo_delete_tombstones(state, updated_time DESC);',
            );
          }
          if (oldVersion < 17) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS memo_inline_image_sources (
  memo_uid TEXT NOT NULL,
  local_url TEXT NOT NULL,
  source_url TEXT NOT NULL,
  updated_time INTEGER NOT NULL,
  PRIMARY KEY (memo_uid, local_url)
);
''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_memo_inline_image_sources_memo ON memo_inline_image_sources(memo_uid, updated_time DESC);',
            );
          }
        },
        onOpen: (db) async {
          await _ensureStatsCache(db);
          await _ensureFts(db);
        },
      );
    }

    try {
      return await open();
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (msg.contains('unrecognized parameter') &&
          msg.contains('content_rowid')) {
        // The DB was created by an older buggy build and is not openable.
        // Reset the DB so the app can recover without manual uninstall/clear-data.
        await deleteDatabase(path);
        try {
          // Best-effort cleanup for stray files in some environments.
          await File('$path-wal').delete();
        } catch (_) {}
        try {
          await File('$path-shm').delete();
        } catch (_) {}
        return open();
      }
      rethrow;
    }
  }

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }

  static Future<void> deleteDatabaseFile({required String dbName}) async {
    final basePath = await resolveDatabasesDirectoryPath();
    final path = p.join(basePath, dbName);

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await deleteDatabase(path);
        break;
      } catch (_) {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }

    // Best-effort cleanup for stray files in some environments.
    try {
      await File('$path-wal').delete();
    } catch (_) {}
    try {
      await File('$path-shm').delete();
    } catch (_) {}
  }

  void _notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  void notifyDataChanged() {
    _notifyChanged();
  }

  static List<String> _normalizeTags(List<String> tags) {
    if (tags.isEmpty) return const [];
    final list = <String>[];
    for (final raw in tags) {
      final normalized = normalizeTagPath(raw);
      if (normalized.isEmpty) continue;
      list.add(normalized);
    }
    return list;
  }

  static String _normalizeTagsText(String tagsText) {
    if (tagsText.trim().isEmpty) return '';
    final normalized = <String>{};
    for (final part in tagsText.split(' ')) {
      final normalizedPart = normalizeTagPath(part);
      if (normalizedPart.isEmpty) continue;
      normalized.add(normalizedPart);
    }
    if (normalized.isEmpty) return '';
    final list = normalized.toList(growable: false)..sort();
    return list.join(' ');
  }

  static Future<void> _normalizeStoredTags(Database db) async {
    var lastId = 0;
    while (true) {
      final rows = await db.query(
        'memos',
        columns: const ['id', 'uid', 'tags'],
        where: 'id > ?',
        whereArgs: [lastId],
        orderBy: 'id ASC',
        limit: _maintenanceBatchSize,
      );
      if (rows.isEmpty) return;
      lastId = _readInt(rows.last['id']) ?? lastId;
      final updates = <({int id, String tags})>[];
      for (final row in rows) {
        final uid = row['uid'];
        if (uid is! String || uid.trim().isEmpty) continue;
        final tagsText = (row['tags'] as String?) ?? '';
        final normalized = _normalizeTagsText(tagsText);
        if (normalized == tagsText) continue;
        final id = _readInt(row['id']) ?? 0;
        if (id <= 0) continue;
        updates.add((id: id, tags: normalized));
      }
      if (updates.isNotEmpty) {
        await db.transaction((txn) async {
          for (final update in updates) {
            await txn.update(
              'memos',
              {'tags': update.tags},
              where: 'id = ?',
              whereArgs: [update.id],
            );
          }
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  static List<String> _splitTagsText(String tagsText) {
    if (tagsText.trim().isEmpty) return const [];
    return tagsText
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
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

  Future<ResolvedTag?> resolveTagPath(DatabaseExecutor txn, String rawTag) {
    return _resolveTagPath(txn, rawTag);
  }

  Future<void> updateMemoTagsMapping(
    DatabaseExecutor txn,
    String memoUid,
    List<int> tagIds,
  ) async {
    await _updateMemoTagsMapping(txn, memoUid, tagIds);
  }

  Future<List<String>> listMemoUidsByTagId(
    DatabaseExecutor txn,
    int tagId,
  ) async {
    return listMemoUidsByTagIds(txn, [tagId]);
  }

  Future<List<String>> listMemoUidsByTagIds(
    DatabaseExecutor txn,
    List<int> tagIds,
  ) async {
    if (tagIds.isEmpty) return const [];
    final placeholders = List.filled(tagIds.length, '?').join(', ');
    final rows = await txn.rawQuery(
      'SELECT DISTINCT memo_uid FROM memo_tags WHERE tag_id IN ($placeholders);',
      tagIds,
    );
    final result = <String>[];
    for (final row in rows) {
      final uid = row['memo_uid'];
      if (uid is String && uid.trim().isNotEmpty) {
        result.add(uid);
      }
    }
    return result;
  }

  Future<List<String>> listTagPathsForMemo(
    DatabaseExecutor txn,
    String memoUid,
  ) async {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return const [];
    final rows = await txn.rawQuery(
      '''
SELECT t.path
FROM memo_tags mt
JOIN tags t ON t.id = mt.tag_id
WHERE mt.memo_uid = ?;
''',
      [normalized],
    );
    final paths = <String>[];
    for (final row in rows) {
      final path = row['path'];
      if (path is String && path.trim().isNotEmpty) {
        paths.add(path.trim());
      }
    }
    paths.sort();
    return paths;
  }

  Future<void> updateMemoTagsText(
    DatabaseExecutor txn,
    String memoUid,
    List<String> tags,
  ) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final normalizedTags = _normalizeTags(tags);
    final deduped = <String>[];
    final seen = <String>{};
    for (final tag in normalizedTags) {
      if (seen.add(tag)) deduped.add(tag);
    }
    final tagsText = deduped.join(' ');
    final before = await _fetchMemoSnapshot(txn, normalizedUid);
    if (before == null) return;
    await txn.update(
      'memos',
      {'tags': tagsText},
      where: 'uid = ?',
      whereArgs: [normalizedUid],
    );
    final rows = await txn.query(
      'memos',
      columns: const ['id'],
      where: 'uid = ?',
      whereArgs: [normalizedUid],
      limit: 1,
    );
    final rowId = _readInt(rows.firstOrNull?['id']) ?? 0;
    if (rowId > 0) {
      await _replaceMemoFtsEntry(
        txn,
        rowId: rowId,
        content: before.content,
        tags: tagsText,
      );
    }
    final after = _MemoSnapshot(
      state: before.state,
      createTimeSec: before.createTimeSec,
      content: before.content,
      tags: deduped,
    );
    await _applyMemoCacheDelta(txn, before: before, after: after);
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

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static Future<int?> _queryMinCreateTime(DatabaseExecutor txn) async {
    final rows = await txn.rawQuery(
      'SELECT MIN(create_time) AS min_time FROM memos;',
    );
    if (rows.isEmpty) return null;
    return _readInt(rows.first['min_time']);
  }

  static Future<int?> _resolveMinCreateTime(
    DatabaseExecutor txn, {
    required int? currentMin,
    required _MemoSnapshot? before,
    required _MemoSnapshot? after,
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
      nextMin = await _queryMinCreateTime(txn);
    }
    return nextMin;
  }

  static Future<void> _ensureStatsCacheRow(DatabaseExecutor txn) async {
    final rows = await txn.query(
      'stats_cache',
      columns: const ['id'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await txn.insert('stats_cache', {
      'id': 1,
      'total_memos': 0,
      'archived_memos': 0,
      'total_chars': 0,
      'min_create_time': null,
      'updated_time': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _bumpDailyCount(
    DatabaseExecutor txn,
    String dayKey,
    int delta,
  ) async {
    if (dayKey.trim().isEmpty || delta == 0) return;
    final rows = await txn.query(
      'daily_counts_cache',
      columns: const ['memo_count'],
      where: 'day = ?',
      whereArgs: [dayKey],
      limit: 1,
    );
    final current = _readInt(rows.firstOrNull?['memo_count']) ?? 0;
    final next = current + delta;
    if (next <= 0) {
      await txn.delete(
        'daily_counts_cache',
        where: 'day = ?',
        whereArgs: [dayKey],
      );
      return;
    }
    if (rows.isEmpty) {
      await txn.insert('daily_counts_cache', {
        'day': dayKey,
        'memo_count': next,
      });
      return;
    }
    await txn.update(
      'daily_counts_cache',
      {'memo_count': next},
      where: 'day = ?',
      whereArgs: [dayKey],
    );
  }

  static Future<void> _bumpTagCount(
    DatabaseExecutor txn,
    String tag,
    int delta,
  ) async {
    final key = tag.trim();
    if (key.isEmpty || delta == 0) return;
    final rows = await txn.query(
      'tag_stats_cache',
      columns: const ['memo_count'],
      where: 'tag = ?',
      whereArgs: [key],
      limit: 1,
    );
    final current = _readInt(rows.firstOrNull?['memo_count']) ?? 0;
    final next = current + delta;
    if (next <= 0) {
      await txn.delete('tag_stats_cache', where: 'tag = ?', whereArgs: [key]);
      return;
    }
    if (rows.isEmpty) {
      await txn.insert('tag_stats_cache', {'tag': key, 'memo_count': next});
      return;
    }
    await txn.update(
      'tag_stats_cache',
      {'memo_count': next},
      where: 'tag = ?',
      whereArgs: [key],
    );
  }

  Future<_MemoSnapshot?> _fetchMemoSnapshot(
    DatabaseExecutor txn,
    String uid,
  ) async {
    final rows = await txn.query(
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
    return _MemoSnapshot(
      state: state,
      createTimeSec: createTimeSec,
      content: content,
      tags: _splitTagsText(tagsText),
    );
  }

  Future<void> _applyMemoCacheDelta(
    DatabaseExecutor txn, {
    required _MemoSnapshot? before,
    required _MemoSnapshot? after,
  }) async {
    if (before == null && after == null) return;

    await _ensureStatsCacheRow(txn);
    final statsRows = await txn.query(
      'stats_cache',
      columns: const ['min_create_time'],
      where: 'id = 1',
      limit: 1,
    );
    final currentMin = _readInt(statsRows.firstOrNull?['min_create_time']);

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
        await _bumpDailyCount(txn, oldDayKey, -1);
      }
      if (newDayKey != null) {
        await _bumpDailyCount(txn, newDayKey, 1);
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
          await _bumpTagCount(txn, tag, delta);
        }
      }
    }

    final nextMin = await _resolveMinCreateTime(
      txn,
      currentMin: currentMin,
      before: before,
      after: after,
    );
    if (deltaTotal != 0 ||
        deltaArchived != 0 ||
        deltaChars != 0 ||
        nextMin != currentMin) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await txn.rawUpdate(
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

  Future<void> upsertMemo({
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
  }) async {
    final db = await this.db;
    final attachmentsJson = jsonEncode(attachments);
    final locationPlaceholder = location?.placeholder;
    final locationLat = location?.latitude;
    final locationLng = location?.longitude;

    await db.transaction((txn) async {
      final normalizedTags = _normalizeTags(tags);
      final resolved = <String, int>{};
      for (final raw in normalizedTags) {
        final resolvedTag = await resolveTagPath(txn, raw);
        if (resolvedTag == null) continue;
        resolved.putIfAbsent(resolvedTag.path, () => resolvedTag.id);
      }
      final canonicalTags = resolved.keys.toList(growable: false);
      final tagsText = canonicalTags.join(' ');

      final before = await _fetchMemoSnapshot(txn, uid);
      final updated = await txn.update(
        'memos',
        {
          'content': content,
          'visibility': visibility,
          'pinned': pinned ? 1 : 0,
          'state': state,
          'create_time': createTimeSec,
          'update_time': updateTimeSec,
          'tags': tagsText,
          'attachments_json': attachmentsJson,
          'location_placeholder': locationPlaceholder,
          'location_lat': locationLat,
          'location_lng': locationLng,
          'relation_count': relationCount,
          'sync_state': syncState,
          'last_error': lastError,
        },
        where: 'uid = ?',
        whereArgs: [uid],
      );

      int rowId;
      if (updated == 0) {
        rowId = await txn.insert('memos', {
          'uid': uid,
          'content': content,
          'visibility': visibility,
          'pinned': pinned ? 1 : 0,
          'state': state,
          'create_time': createTimeSec,
          'update_time': updateTimeSec,
          'tags': tagsText,
          'attachments_json': attachmentsJson,
          'location_placeholder': locationPlaceholder,
          'location_lat': locationLat,
          'location_lng': locationLng,
          'relation_count': relationCount,
          'sync_state': syncState,
          'last_error': lastError,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      } else {
        final rows = await txn.query(
          'memos',
          columns: const ['id'],
          where: 'uid = ?',
          whereArgs: [uid],
          limit: 1,
        );
        rowId = (rows.firstOrNull?['id'] as int?) ?? 0;
        if (rowId <= 0) return;
      }

      await _replaceMemoFtsEntry(
        txn,
        rowId: rowId,
        content: content,
        tags: tagsText,
      );

      await updateMemoTagsMapping(
        txn,
        uid,
        resolved.values.toList(growable: false),
      );

      final after = _MemoSnapshot(
        state: state,
        createTimeSec: createTimeSec,
        content: content,
        tags: canonicalTags,
      );
      await _applyMemoCacheDelta(txn, before: before, after: after);
    });
    _notifyChanged();
  }

  Future<void> updateMemoSyncState(
    String uid, {
    required int syncState,
    String? lastError,
  }) async {
    final db = await this.db;
    await db.update(
      'memos',
      {'sync_state': syncState, 'last_error': lastError},
      where: 'uid = ?',
      whereArgs: [uid],
    );
    _notifyChanged();
  }

  Future<void> updateMemoAttachmentsJson(
    String uid, {
    required String attachmentsJson,
  }) async {
    final db = await this.db;
    await db.update(
      'memos',
      {'attachments_json': attachmentsJson},
      where: 'uid = ?',
      whereArgs: [uid],
    );
    _notifyChanged();
  }

  Future<void> removePendingAttachmentPlaceholder({
    required String memoUid,
    required String attachmentUid,
  }) async {
    final trimmedMemoUid = memoUid.trim();
    final trimmedAttachmentUid = attachmentUid.trim();
    if (trimmedMemoUid.isEmpty || trimmedAttachmentUid.isEmpty) return;

    final row = await getMemoByUid(trimmedMemoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;

    final expectedNames = <String>{
      'attachments/$trimmedAttachmentUid',
      'resources/$trimmedAttachmentUid',
    };
    var changed = false;
    final next = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final name = (map['name'] as String?)?.trim() ?? '';
      if (expectedNames.contains(name)) {
        changed = true;
        continue;
      }
      next.add(map);
    }
    if (!changed) return;
    await updateMemoAttachmentsJson(
      trimmedMemoUid,
      attachmentsJson: jsonEncode(next),
    );
  }

  Future<String?> getMemoRelationsCacheJson(String memoUid) async {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return null;
    final db = await this.db;
    final rows = await db.query(
      'memo_relations_cache',
      columns: const ['relations_json'],
      where: 'memo_uid = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['relations_json'];
    return raw is String ? raw : null;
  }

  Future<void> upsertMemoRelationsCache(
    String memoUid, {
    required String relationsJson,
  }) async {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return;
    final db = await this.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final updated = await db.update(
      'memo_relations_cache',
      {'relations_json': relationsJson, 'updated_time': now},
      where: 'memo_uid = ?',
      whereArgs: [normalized],
    );
    if (updated == 0) {
      await db.insert('memo_relations_cache', {
        'memo_uid': normalized,
        'relations_json': relationsJson,
        'updated_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    }
    _notifyChanged();
  }

  Future<void> deleteMemoRelationsCache(String memoUid) async {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return;
    final db = await this.db;
    await db.delete(
      'memo_relations_cache',
      where: 'memo_uid = ?',
      whereArgs: [normalized],
    );
    _notifyChanged();
  }

  Future<int> insertMemoVersion({
    required String memoUid,
    required int snapshotTime,
    required String summary,
    required String payloadJson,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) {
      throw const FormatException('memo_uid is required');
    }
    final db = await this.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await db.insert('memo_versions', {
      'memo_uid': normalizedUid,
      'snapshot_time': snapshotTime,
      'summary': summary,
      'payload_json': payloadJson,
      'created_time': now,
    });
    _notifyChanged();
    return id;
  }

  Future<List<Map<String, dynamic>>> listMemoVersionsByUid(
    String memoUid, {
    int? limit,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return const [];
    final db = await this.db;
    return db.query(
      'memo_versions',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
      orderBy: 'snapshot_time DESC, id DESC',
      limit: (limit != null && limit > 0) ? limit : null,
    );
  }

  Future<List<int>> listMemoVersionIdsExceedLimit(
    String memoUid, {
    required int keep,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return const [];
    if (keep < 0) return const [];
    final db = await this.db;
    final rows = await db.query(
      'memo_versions',
      columns: const ['id'],
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
      orderBy: 'snapshot_time DESC, id DESC',
      offset: keep,
    );
    final ids = <int>[];
    for (final row in rows) {
      final id = row['id'];
      if (id is int) {
        ids.add(id);
      } else if (id is num) {
        ids.add(id.toInt());
      } else if (id is String) {
        final parsed = int.tryParse(id.trim());
        if (parsed != null) ids.add(parsed);
      }
    }
    return ids;
  }

  Future<Map<String, dynamic>?> getMemoVersionById(int id) async {
    final db = await this.db;
    final rows = await db.query(
      'memo_versions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> deleteMemoVersionById(int id) async {
    final db = await this.db;
    await db.delete('memo_versions', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<void> deleteMemoVersionsByMemoUid(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final db = await this.db;
    await db.delete(
      'memo_versions',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    _notifyChanged();
  }

  Future<int> insertRecycleBinItem({
    required String itemType,
    required String memoUid,
    required String summary,
    required String payloadJson,
    required int deletedTime,
    required int expireTime,
  }) async {
    final db = await this.db;
    final id = await db.insert('recycle_bin_items', {
      'item_type': itemType,
      'memo_uid': memoUid.trim(),
      'summary': summary,
      'payload_json': payloadJson,
      'deleted_time': deletedTime,
      'expire_time': expireTime,
    });
    _notifyChanged();
    return id;
  }

  Future<Set<String>> listRecycleBinMemoUids() async {
    final db = await this.db;
    final rows = await db.query(
      'recycle_bin_items',
      columns: const ['memo_uid'],
      where: 'item_type = ? AND memo_uid <> ?',
      whereArgs: const ['memo', ''],
    );
    final uids = <String>{};
    for (final row in rows) {
      final raw = row['memo_uid'];
      final uid = raw is String ? raw.trim() : '';
      if (uid.isNotEmpty) {
        uids.add(uid);
      }
    }
    return uids;
  }

  Future<bool> hasRecycleBinMemoItem(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return false;
    final db = await this.db;
    final rows = await db.query(
      'recycle_bin_items',
      columns: const ['id'],
      where: 'item_type = ? AND memo_uid = ?',
      whereArgs: ['memo', normalizedUid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsertMemoDeleteTombstone({
    required String memoUid,
    required String state,
    String? lastError,
    int? deletedTime,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final db = await this.db;
    final existing = await db.query(
      'memo_delete_tombstones',
      columns: const ['deleted_time'],
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
      limit: 1,
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final deletedTimeValue = switch (existing.firstOrNull?['deleted_time']) {
      int value when deletedTime == null => value,
      num value when deletedTime == null => value.toInt(),
      String value when deletedTime == null =>
        int.tryParse(value.trim()) ?? now,
      _ => deletedTime ?? now,
    };
    await db.insert('memo_delete_tombstones', {
      'memo_uid': normalizedUid,
      'state': state,
      'deleted_time': deletedTimeValue,
      'updated_time': now,
      'last_error': lastError,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged();
  }

  Future<Map<String, dynamic>?> getMemoDeleteTombstone(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return null;
    final db = await this.db;
    final rows = await db.query(
      'memo_delete_tombstones',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<String?> getMemoDeleteTombstoneState(String memoUid) async {
    final row = await getMemoDeleteTombstone(memoUid);
    final state = row?['state'];
    return state is String && state.trim().isNotEmpty ? state.trim() : null;
  }

  Future<Set<String>> listMemoDeleteTombstoneUids() async {
    final db = await this.db;
    final rows = await db.query(
      'memo_delete_tombstones',
      columns: const ['memo_uid'],
    );
    final uids = <String>{};
    for (final row in rows) {
      final raw = row['memo_uid'];
      final uid = raw is String ? raw.trim() : '';
      if (uid.isNotEmpty) {
        uids.add(uid);
      }
    }
    return uids;
  }

  Future<bool> hasMemoDeleteMarker(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return false;
    final tombstoneState = await getMemoDeleteTombstoneState(normalizedUid);
    if (tombstoneState != null) return true;
    return hasRecycleBinMemoItem(normalizedUid);
  }

  Future<Set<String>> listMemoDeleteMarkerUids() async {
    final tombstones = await listMemoDeleteTombstoneUids();
    final recycleBin = await listRecycleBinMemoUids();
    return <String>{...tombstones, ...recycleBin};
  }

  Future<void> upsertMemoInlineImageSource({
    required String memoUid,
    required String localUrl,
    required String sourceUrl,
  }) async {
    final normalizedUid = memoUid.trim();
    final normalizedLocalUrl = localUrl.trim();
    final normalizedSourceUrl = sourceUrl.trim();
    if (normalizedUid.isEmpty ||
        normalizedLocalUrl.isEmpty ||
        normalizedSourceUrl.isEmpty) {
      return;
    }
    final db = await this.db;
    await db.insert('memo_inline_image_sources', {
      'memo_uid': normalizedUid,
      'local_url': normalizedLocalUrl,
      'source_url': normalizedSourceUrl,
      'updated_time': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged();
  }

  Future<Map<String, String>> listMemoInlineImageSources(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return const <String, String>{};
    final db = await this.db;
    final rows = await db.query(
      'memo_inline_image_sources',
      columns: const ['local_url', 'source_url'],
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
      orderBy: 'updated_time DESC',
    );
    final mappings = <String, String>{};
    for (final row in rows) {
      final localUrl = (row['local_url'] as String? ?? '').trim();
      final sourceUrl = (row['source_url'] as String? ?? '').trim();
      if (localUrl.isEmpty || sourceUrl.isEmpty) continue;
      mappings.putIfAbsent(localUrl, () => sourceUrl);
    }
    return mappings;
  }

  Future<void> deleteMemoInlineImageSources(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final db = await this.db;
    await db.delete(
      'memo_inline_image_sources',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    _notifyChanged();
  }

  Future<void> deleteMemoDeleteTombstone(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final db = await this.db;
    await db.delete(
      'memo_delete_tombstones',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    _notifyChanged();
  }

  Future<List<Map<String, dynamic>>> listRecycleBinItems() async {
    final db = await this.db;
    return db.query('recycle_bin_items', orderBy: 'deleted_time DESC, id DESC');
  }

  Future<Map<String, dynamic>?> getRecycleBinItemById(int id) async {
    final db = await this.db;
    final rows = await db.query(
      'recycle_bin_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<int>> listExpiredRecycleBinItemIds({required int nowMs}) async {
    final db = await this.db;
    final rows = await db.query(
      'recycle_bin_items',
      columns: const ['id'],
      where: 'expire_time <= ?',
      whereArgs: [nowMs],
      orderBy: 'expire_time ASC, id ASC',
    );
    final ids = <int>[];
    for (final row in rows) {
      final id = row['id'];
      if (id is int) {
        ids.add(id);
      } else if (id is num) {
        ids.add(id.toInt());
      } else if (id is String) {
        final parsed = int.tryParse(id.trim());
        if (parsed != null) ids.add(parsed);
      }
    }
    return ids;
  }

  Future<void> deleteRecycleBinItemById(int id) async {
    final db = await this.db;
    await db.delete('recycle_bin_items', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<void> clearRecycleBinItems() async {
    final db = await this.db;
    await db.delete('recycle_bin_items');
    _notifyChanged();
  }

  Future<void> renameMemoUid({
    required String oldUid,
    required String newUid,
  }) async {
    final db = await this.db;
    await db.transaction((txn) async {
      await txn.update(
        'memos',
        {'uid': newUid},
        where: 'uid = ?',
        whereArgs: [oldUid],
      );
      await txn.update(
        'memo_reminders',
        {'memo_uid': newUid},
        where: 'memo_uid = ?',
        whereArgs: [oldUid],
      );
      await txn.update(
        'attachments',
        {'memo_uid': newUid},
        where: 'memo_uid = ?',
        whereArgs: [oldUid],
      );
      await txn.update(
        'memo_relations_cache',
        {'memo_uid': newUid},
        where: 'memo_uid = ?',
        whereArgs: [oldUid],
      );
      await txn.update(
        'memo_versions',
        {'memo_uid': newUid},
        where: 'memo_uid = ?',
        whereArgs: [oldUid],
      );
      await txn.update(
        'recycle_bin_items',
        {'memo_uid': newUid},
        where: 'memo_uid = ?',
        whereArgs: [oldUid],
      );
      await txn.update(
        'memo_inline_image_sources',
        {'memo_uid': newUid},
        where: 'memo_uid = ?',
        whereArgs: [oldUid],
      );
    });
    _notifyChanged();
  }

  Future<int> rewriteOutboxMemoUids({
    required String oldUid,
    required String newUid,
  }) async {
    final db = await this.db;
    var changedCount = 0;
    final rows = await db.query(
      'outbox',
      columns: const ['id', 'type', 'payload'],
    );
    for (final row in rows) {
      final id = row['id'];
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (id is! int || type is! String || payloadRaw is! String) continue;

      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is! Map) continue;
        payload = decoded.cast<String, dynamic>();
      } catch (_) {
        continue;
      }

      var changed = false;
      switch (type) {
        case 'create_memo':
        case 'update_memo':
        case 'delete_memo':
          if (payload['uid'] == oldUid) {
            payload['uid'] = newUid;
            changed = true;
          }
          break;
        case 'upload_attachment':
        case 'delete_attachment':
          if (payload['memo_uid'] == oldUid) {
            payload['memo_uid'] = newUid;
            changed = true;
          }
          break;
      }
      if (!changed) continue;

      await db.update(
        'outbox',
        {'payload': jsonEncode(payload)},
        where: 'id = ?',
        whereArgs: [id],
      );
      changedCount++;
    }
    if (changedCount > 0) {
      _notifyChanged();
    }
    return changedCount;
  }

  Future<Map<String, dynamic>?> getMemoByUid(String uid) async {
    final db = await this.db;
    final rows = await db.query(
      'memos',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> enqueueOutbox({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final db = await this.db;
    final id = await db.insert('outbox', {
      'type': type,
      'payload': jsonEncode(payload),
      'state': outboxStatePending,
      'attempts': 0,
      'last_error': null,
      'retry_at': null,
      'created_time': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
    _notifyChanged();
    return id;
  }

  Future<List<Map<String, dynamic>>> listOutboxPending({int limit = 50}) async {
    final db = await this.db;
    return db.query(
      'outbox',
      where: 'state IN (?, ?, ?, ?)',
      whereArgs: const [
        outboxStatePending,
        outboxStateRunning,
        outboxStateRetry,
        outboxStateError,
      ],
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<int> countOutboxPending() async {
    final db = await this.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM outbox WHERE state IN ($outboxStatePending, $outboxStateRunning, $outboxStateRetry, $outboxStateError)',
    );
    if (rows.isEmpty) return 0;
    final raw = rows.first['count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  Future<int> countOutboxRetryable() async {
    final db = await this.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM outbox WHERE state IN ($outboxStatePending, $outboxStateRunning, $outboxStateRetry)',
    );
    if (rows.isEmpty) return 0;
    final raw = rows.first['count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  Future<int> countOutboxFailed() async {
    final db = await this.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM outbox WHERE state = $outboxStateError',
    );
    if (rows.isEmpty) return 0;
    final raw = rows.first['count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  Future<int> countMemos() async {
    final db = await this.db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM memos');
    if (rows.isEmpty) return 0;
    final raw = rows.first['count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  Future<List<Map<String, dynamic>>> listOutboxPendingByType(
    String type,
  ) async {
    final db = await this.db;
    return db.query(
      'outbox',
      columns: const ['id', 'payload'],
      where: 'state IN (?, ?, ?, ?) AND type = ?',
      whereArgs: [
        outboxStatePending,
        outboxStateRunning,
        outboxStateRetry,
        outboxStateError,
        type,
      ],
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, dynamic>?> claimNextOutboxRunnable({int? nowMs}) async {
    final db = await this.db;
    final now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final claimed = await db.transaction<Map<String, dynamic>?>((txn) async {
      final rows = await txn.query(
        'outbox',
        where:
            '(state = ? OR state = ?) AND (retry_at IS NULL OR retry_at <= ?)',
        whereArgs: [outboxStatePending, outboxStateRetry, now],
        orderBy: 'id ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final id = rows.first['id'];
      if (id is! int) return null;

      final updated = await txn.update(
        'outbox',
        {'state': outboxStateRunning},
        where: 'id = ? AND (state = ? OR state = ?)',
        whereArgs: [id, outboxStatePending, outboxStateRetry],
      );
      if (updated <= 0) return null;

      final claimedRows = await txn.query(
        'outbox',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (claimedRows.isEmpty) return null;
      return claimedRows.first;
    });
    if (claimed != null) {
      _notifyChanged();
    }
    return claimed;
  }

  Future<Map<String, dynamic>?> claimOutboxTaskById(
    int id, {
    int? nowMs,
  }) async {
    final db = await this.db;
    final now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final claimed = await db.transaction<Map<String, dynamic>?>((txn) async {
      final updated = await txn.rawUpdate(
        '''
UPDATE outbox
SET state = ?
WHERE id = ?
  AND (
    state = ?
    OR (state = ? AND (retry_at IS NULL OR retry_at <= ?))
  );
''',
        [outboxStateRunning, id, outboxStatePending, outboxStateRetry, now],
      );
      if (updated <= 0) return null;
      final rows = await txn.query(
        'outbox',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first;
    });
    if (claimed != null) {
      _notifyChanged();
    }
    return claimed;
  }

  Future<int> recoverOutboxRunningTasks() async {
    final db = await this.db;
    final updated = await db.rawUpdate(
      'UPDATE outbox SET state = ?, retry_at = NULL WHERE state = ?',
      [outboxStatePending, outboxStateRunning],
    );
    if (updated > 0) {
      _notifyChanged();
    }
    return updated;
  }

  Future<void> markOutboxDone(int id) async {
    final db = await this.db;
    await db.rawUpdate(
      'UPDATE outbox SET state = ?, retry_at = NULL, last_error = NULL WHERE id = ?',
      [outboxStateDone, id],
    );
    _notifyChanged();
  }

  Future<void> markOutboxError(int id, {required String error}) async {
    final db = await this.db;
    await db.rawUpdate(
      'UPDATE outbox SET state = ?, attempts = attempts + 1, retry_at = NULL, last_error = ? WHERE id = ?',
      [outboxStateError, error, id],
    );
    _notifyChanged();
  }

  Future<void> markOutboxRetryScheduled(
    int id, {
    required String error,
    required int retryAtMs,
  }) async {
    final db = await this.db;
    await db.rawUpdate(
      'UPDATE outbox SET state = ?, attempts = attempts + 1, retry_at = ?, last_error = ? WHERE id = ?',
      [outboxStateRetry, retryAtMs, error, id],
    );
    _notifyChanged();
  }

  Future<void> markOutboxRetryPending(int id, {required String error}) async {
    await markOutboxRetryScheduled(
      id,
      error: error,
      retryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  Future<int> retryOutboxErrors({String? memoUid}) async {
    final db = await this.db;
    final normalizedMemoUid = (memoUid ?? '').trim();
    final rows = await db.query(
      'outbox',
      columns: const ['id', 'type', 'payload'],
      where: 'state = ?',
      whereArgs: const [outboxStateError],
      orderBy: 'id ASC',
    );

    final ids = <int>[];
    for (final row in rows) {
      final id = row['id'];
      if (id is! int) continue;
      if (normalizedMemoUid.isEmpty) {
        ids.add(id);
        continue;
      }
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (type is! String || payloadRaw is! String) continue;
      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final targetUid = _extractOutboxMemoUid(type, payload);
      if (targetUid == null || targetUid.trim() != normalizedMemoUid) {
        continue;
      }
      ids.add(id);
    }

    if (ids.isEmpty) return 0;
    for (final id in ids) {
      await db.rawUpdate(
        'UPDATE outbox SET state = ?, retry_at = NULL, last_error = NULL WHERE id = ?',
        [outboxStatePending, id],
      );
    }
    _notifyChanged();
    return ids.length;
  }

  Future<void> deleteOutbox(int id) async {
    final db = await this.db;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<bool> hasPendingOutboxTaskForMemo(
    String memoUid, {
    Set<String>? types,
  }) async {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return false;
    final db = await this.db;
    final rows = await db.query(
      'outbox',
      columns: const ['type', 'payload'],
      where: 'state IN (?, ?, ?, ?)',
      whereArgs: const [
        outboxStatePending,
        outboxStateRunning,
        outboxStateRetry,
        outboxStateError,
      ],
    );

    for (final row in rows) {
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (type is! String || payloadRaw is! String) continue;
      if (types != null && !types.contains(type)) continue;
      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final targetUid = _extractOutboxMemoUid(type, payload);
      if (targetUid is String && targetUid.trim() == trimmed) {
        return true;
      }
    }

    return false;
  }

  Future<void> deleteOutboxForMemo(String memoUid) async {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return;
    final db = await this.db;
    final rows = await db.query(
      'outbox',
      columns: const ['id', 'type', 'payload'],
      where: 'state IN (?, ?, ?, ?)',
      whereArgs: const [
        outboxStatePending,
        outboxStateRunning,
        outboxStateRetry,
        outboxStateError,
      ],
    );
    final ids = <int>[];
    for (final row in rows) {
      final id = row['id'];
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (id is! int || type is! String || payloadRaw is! String) continue;
      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final target = _extractOutboxMemoUid(type, payload);
      if (target is String && target.trim() == trimmed) {
        ids.add(id);
      }
    }
    if (ids.isEmpty) return;
    for (final id in ids) {
      await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
    }
    _notifyChanged();
  }

  Future<void> clearOutbox() async {
    final db = await this.db;
    await db.delete('outbox');
    _notifyChanged();
  }

  Future<Map<String, dynamic>?> getImportHistory({
    required String source,
    required String fileMd5,
  }) async {
    final db = await this.db;
    final rows = await db.query(
      'import_history',
      where: 'source = ? AND file_md5 = ?',
      whereArgs: [source, fileMd5],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> upsertImportHistory({
    required String source,
    required String fileMd5,
    required String fileName,
    required int status,
    required int memoCount,
    required int attachmentCount,
    required int failedCount,
    String? error,
  }) async {
    final db = await this.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = await db.insert('import_history', {
      'source': source,
      'file_md5': fileMd5,
      'file_name': fileName,
      'memo_count': memoCount,
      'attachment_count': attachmentCount,
      'failed_count': failedCount,
      'status': status,
      'created_time': now,
      'updated_time': now,
      'error': error,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged();
    return id;
  }

  Future<void> updateImportHistory({
    required int id,
    required int status,
    required int memoCount,
    required int attachmentCount,
    required int failedCount,
    String? error,
  }) async {
    final db = await this.db;
    await db.update(
      'import_history',
      {
        'status': status,
        'memo_count': memoCount,
        'attachment_count': attachmentCount,
        'failed_count': failedCount,
        'updated_time': DateTime.now().toUtc().millisecondsSinceEpoch,
        'error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  Future<void> deleteMemoByUid(String uid) async {
    final db = await this.db;
    await db.transaction((txn) async {
      final before = await _fetchMemoSnapshot(txn, uid);
      final rows = await txn.query(
        'memos',
        columns: const ['id'],
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );
      final rowId = rows.firstOrNull?['id'] as int?;
      await txn.delete('memos', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete(
        'memo_relations_cache',
        where: 'memo_uid = ?',
        whereArgs: [uid],
      );
      await txn.delete(
        'memo_versions',
        where: 'memo_uid = ?',
        whereArgs: [uid],
      );
      if (rowId != null) {
        await _deleteMemoFtsEntry(txn, rowId: rowId);
      }
      await _applyMemoCacheDelta(txn, before: before, after: null);
    });
    _notifyChanged();
  }

  Future<Map<String, dynamic>?> getMemoReminderByUid(String memoUid) async {
    final db = await this.db;
    final rows = await db.query(
      'memo_reminders',
      where: 'memo_uid = ?',
      whereArgs: [memoUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> listMemoReminders() async {
    final db = await this.db;
    return db.query('memo_reminders', orderBy: 'updated_time DESC');
  }

  Stream<List<Map<String, dynamic>>> watchMemoReminders() async* {
    yield await listMemoReminders();
    await for (final _ in changes) {
      yield await listMemoReminders();
    }
  }

  Future<void> upsertMemoReminder({
    required String memoUid,
    required String mode,
    required String timesJson,
  }) async {
    final db = await this.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final updated = await db.update(
      'memo_reminders',
      {'mode': mode, 'times_json': timesJson, 'updated_time': now},
      where: 'memo_uid = ?',
      whereArgs: [memoUid],
    );
    if (updated == 0) {
      await db.insert('memo_reminders', {
        'memo_uid': memoUid,
        'mode': mode,
        'times_json': timesJson,
        'created_time': now,
        'updated_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    }
    _notifyChanged();
  }

  Future<void> deleteMemoReminder(String memoUid) async {
    final db = await this.db;
    await db.delete(
      'memo_reminders',
      where: 'memo_uid = ?',
      whereArgs: [memoUid],
    );
    _notifyChanged();
  }

  Future<List<String>> listTagStrings({String? state}) async {
    final db = await this.db;
    final normalizedState = (state ?? '').trim();
    final rows = await db.query(
      'memos',
      columns: const ['tags'],
      where: normalizedState.isEmpty ? null : 'state = ?',
      whereArgs: normalizedState.isEmpty ? null : [normalizedState],
    );
    return rows
        .map((r) => (r['tags'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listMemoAttachmentRows({
    String? state,
  }) async {
    final db = await this.db;
    final normalizedState = (state ?? '').trim();
    return db.query(
      'memos',
      columns: const ['uid', 'update_time', 'attachments_json'],
      where: [
        if (normalizedState.isNotEmpty) 'state = ?',
        "attachments_json <> '[]'",
      ].join(' AND '),
      whereArgs: [if (normalizedState.isNotEmpty) normalizedState],
      orderBy: 'update_time DESC',
      limit: 2000,
    );
  }

  Future<List<Map<String, dynamic>>> listMemos({
    String? searchQuery,
    String? state,
    String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    int? limit = 100,
  }) async {
    final db = await this.db;
    final trimmedTag = (tag ?? '').trim();
    final withoutHash = trimmedTag.startsWith('#')
        ? trimmedTag.substring(1)
        : trimmedTag;
    final normalizedTag = withoutHash.toLowerCase();
    final normalizedState = (state ?? '').trim();
    final normalizedSearch = (searchQuery ?? '').trim();
    final normalizedLimit = (limit != null && limit > 0) ? limit : null;

    final baseWhereClauses = <String>[];
    final baseWhereArgs = <Object?>[];
    if (normalizedState.isNotEmpty) {
      baseWhereClauses.add('state = ?');
      baseWhereArgs.add(normalizedState);
    }
    if (normalizedTag.isNotEmpty) {
      baseWhereClauses.add("(' ' || tags || ' ') LIKE ?");
      baseWhereArgs.add('% $normalizedTag %');
    }
    if (startTimeSec != null) {
      baseWhereClauses.add('create_time >= ?');
      baseWhereArgs.add(startTimeSec);
    }
    if (endTimeSecExclusive != null) {
      baseWhereClauses.add('create_time < ?');
      baseWhereArgs.add(endTimeSecExclusive);
    }

    Future<List<Map<String, dynamic>>> listBase() {
      return db.query(
        'memos',
        where: baseWhereClauses.isEmpty ? null : baseWhereClauses.join(' AND '),
        whereArgs: baseWhereArgs.isEmpty ? null : baseWhereArgs,
        orderBy: 'pinned DESC, create_time DESC',
        limit: normalizedLimit,
      );
    }

    if (normalizedSearch.isEmpty) {
      return listBase();
    }

    final q = _toFtsQuery(normalizedSearch);
    if (q.trim().isEmpty) {
      return listBase();
    }
    final whereClauses = <String>['memos_fts MATCH ?'];
    final whereArgs = <Object?>[q];
    if (normalizedState.isNotEmpty) {
      whereClauses.add('m.state = ?');
      whereArgs.add(normalizedState);
    }
    if (normalizedTag.isNotEmpty) {
      whereClauses.add("(' ' || m.tags || ' ') LIKE ?");
      whereArgs.add('% $normalizedTag %');
    }
    if (startTimeSec != null) {
      whereClauses.add('m.create_time >= ?');
      whereArgs.add(startTimeSec);
    }
    if (endTimeSecExclusive != null) {
      whereClauses.add('m.create_time < ?');
      whereArgs.add(endTimeSecExclusive);
    }
    final sqlLimitClause = normalizedLimit == null ? '' : '\nLIMIT ?';
    if (normalizedLimit != null) {
      whereArgs.add(normalizedLimit);
    }

    try {
      return await db.rawQuery('''
SELECT m.*
FROM memos m
JOIN memos_fts ON memos_fts.rowid = m.id
WHERE ${whereClauses.join(' AND ')}
ORDER BY m.pinned DESC, m.create_time DESC
$sqlLimitClause;
''', whereArgs);
    } on DatabaseException {
      final like = '%$normalizedSearch%';
      final fallbackClauses = <String>[
        ...baseWhereClauses,
        '(content LIKE ? OR tags LIKE ?)',
      ];
      final fallbackArgs = <Object?>[...baseWhereArgs, like, like];
      return db.query(
        'memos',
        where: fallbackClauses.join(' AND '),
        whereArgs: fallbackArgs,
        orderBy: 'pinned DESC, create_time DESC',
        limit: normalizedLimit,
      );
    }
  }

  Future<List<Map<String, dynamic>>> listMemoUidSyncStates({
    String? state,
  }) async {
    final db = await this.db;
    final normalizedState = (state ?? '').trim();
    return db.query(
      'memos',
      columns: const ['uid', 'sync_state', 'visibility'],
      where: normalizedState.isEmpty ? null : 'state = ?',
      whereArgs: normalizedState.isEmpty ? null : [normalizedState],
    );
  }

  static Map<String, dynamic>? _decodeOutboxPayload(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static String? _extractOutboxMemoUid(
    String type,
    Map<String, dynamic> payload,
  ) {
    return switch (type) {
      'create_memo' ||
      'update_memo' ||
      'delete_memo' => payload['uid'] as String?,
      'upload_attachment' ||
      'delete_attachment' => payload['memo_uid'] as String?,
      _ => null,
    };
  }

  Future<Set<String>> listPendingOutboxMemoUids() async {
    final db = await this.db;
    final rows = await db.query(
      'outbox',
      columns: const ['type', 'payload'],
      where: 'state IN (?, ?, ?, ?)',
      whereArgs: const [
        outboxStatePending,
        outboxStateRunning,
        outboxStateRetry,
        outboxStateError,
      ],
    );

    final uids = <String>{};
    for (final row in rows) {
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (type is! String || payloadRaw is! String) continue;
      final payload = _decodeOutboxPayload(payloadRaw);
      if (payload == null) continue;
      final uid = _extractOutboxMemoUid(type, payload);
      if (uid is String && uid.trim().isNotEmpty) {
        uids.add(uid.trim());
      }
    }
    return uids;
  }

  Future<List<Map<String, dynamic>>> listMemosForExport({
    int? startTimeSec,
    int? endTimeSecExclusive,
    bool includeArchived = false,
  }) async {
    final db = await this.db;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (!includeArchived) {
      whereClauses.add("state = 'NORMAL'");
    }
    if (startTimeSec != null) {
      whereClauses.add('create_time >= ?');
      whereArgs.add(startTimeSec);
    }
    if (endTimeSecExclusive != null) {
      whereClauses.add('create_time < ?');
      whereArgs.add(endTimeSecExclusive);
    }

    return db.query(
      'memos',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'create_time ASC',
      limit: 20000,
    );
  }

  Stream<List<Map<String, dynamic>>> watchMemos({
    String? searchQuery,
    String? state,
    String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    int? limit = 100,
  }) async* {
    yield await listMemos(
      searchQuery: searchQuery,
      state: state,
      tag: tag,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      limit: limit,
    );
    await for (final _ in changes) {
      yield await listMemos(
        searchQuery: searchQuery,
        state: state,
        tag: tag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        limit: limit,
      );
    }
  }

  Future<void> rebuildStatsCache() async {
    final db = await this.db;
    await _rebuildStatsCache(db);
    _notifyChanged();
  }

  static Future<void> _ensureTagTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  parent_id INTEGER,
  path TEXT NOT NULL UNIQUE,
  pinned INTEGER NOT NULL DEFAULT 0,
  color_hex TEXT,
  create_time INTEGER NOT NULL,
  update_time INTEGER NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE SET NULL ON UPDATE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags(parent_id);',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_tags_parent_name ON tags(parent_id, name);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS tag_aliases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tag_id INTEGER NOT NULL,
  alias TEXT NOT NULL UNIQUE,
  created_time INTEGER NOT NULL,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE ON UPDATE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tag_aliases_tag_id ON tag_aliases(tag_id);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS memo_tags (
  memo_uid TEXT NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (memo_uid, tag_id),
  FOREIGN KEY (memo_uid) REFERENCES memos(uid) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE ON UPDATE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memo_tags_tag_id ON memo_tags(tag_id);',
    );
  }

  static Future<ResolvedTag?> _resolveTagPath(
    DatabaseExecutor txn,
    String rawTag,
  ) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final directRows = await txn.query(
      'tags',
      columns: const ['id', 'path'],
      where: 'path = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (directRows.isNotEmpty) {
      final row = directRows.first;
      final id = _readInt(row['id']) ?? 0;
      final path = row['path'] as String? ?? normalized;
      if (id > 0) return ResolvedTag(id: id, path: path);
    }

    final aliasRows = await txn.query(
      'tag_aliases',
      columns: const ['tag_id'],
      where: 'alias = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (aliasRows.isNotEmpty) {
      final tagId = _readInt(aliasRows.first['tag_id']);
      if (tagId != null && tagId > 0) {
        final tagRows = await txn.query(
          'tags',
          columns: const ['id', 'path'],
          where: 'id = ?',
          whereArgs: [tagId],
          limit: 1,
        );
        if (tagRows.isNotEmpty) {
          final row = tagRows.first;
          final path = row['path'] as String? ?? normalized;
          return ResolvedTag(id: tagId, path: path);
        }
      }
    }

    final parts = normalized
        .split('/')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    int? parentId;
    var path = '';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    for (final part in parts) {
      final name = part.trim();
      if (name.isEmpty) continue;
      final rows = await txn.query(
        'tags',
        columns: const ['id', 'path'],
        where: parentId == null
            ? 'name = ? AND parent_id IS NULL'
            : 'name = ? AND parent_id = ?',
        whereArgs: parentId == null ? [name] : [name, parentId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        parentId = _readInt(row['id']);
        path = row['path'] as String? ?? path;
        continue;
      }

      path = path.isEmpty ? name : '$path/$name';
      final insertedId = await txn.insert('tags', {
        'name': name,
        'parent_id': parentId,
        'path': path,
        'pinned': 0,
        'color_hex': null,
        'create_time': now,
        'update_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (insertedId == 0) {
        final existing = await txn.query(
          'tags',
          columns: const ['id', 'path'],
          where: parentId == null
              ? 'name = ? AND parent_id IS NULL'
              : 'name = ? AND parent_id = ?',
          whereArgs: parentId == null ? [name] : [name, parentId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final row = existing.first;
          parentId = _readInt(row['id']);
          path = row['path'] as String? ?? path;
          continue;
        }
      }
      parentId = insertedId;
    }

    if (parentId == null || path.isEmpty) return null;
    return ResolvedTag(id: parentId, path: path);
  }

  static Future<void> _updateMemoTagsMapping(
    DatabaseExecutor txn,
    String memoUid,
    List<int> tagIds,
  ) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    await txn.delete(
      'memo_tags',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    if (tagIds.isEmpty) return;
    final batch = txn.batch();
    final seen = <int>{};
    for (final id in tagIds) {
      if (id <= 0 || !seen.add(id)) continue;
      batch.insert('memo_tags', {
        'memo_uid': normalizedUid,
        'tag_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _backfillTagsFromMemos(Database db) async {
    var lastId = 0;
    while (true) {
      final rows = await db.query(
        'memos',
        columns: const ['id', 'uid', 'content', 'tags'],
        where: 'id > ?',
        whereArgs: [lastId],
        orderBy: 'id ASC',
        limit: _maintenanceBatchSize,
      );
      if (rows.isEmpty) return;
      lastId = _readInt(rows.last['id']) ?? lastId;
      await db.transaction((txn) async {
        for (final row in rows) {
          final uid = row['uid'];
          if (uid is! String || uid.trim().isEmpty) continue;
          final tagsText = (row['tags'] as String?) ?? '';
          final tags = _splitTagsText(tagsText);
          final resolved = <String, int>{};
          for (final tag in tags) {
            final entry = await _resolveTagPath(txn, tag);
            if (entry == null) continue;
            resolved[entry.path] = entry.id;
          }
          final canonicalTags = resolved.keys.toList(growable: false)..sort();
          await _updateMemoTagsMapping(
            txn,
            uid,
            resolved.values.toList(growable: false),
          );
          final updatedTagsText = canonicalTags.join(' ');
          if (updatedTagsText != tagsText) {
            await txn.update(
              'memos',
              {'tags': updatedTagsText},
              where: 'uid = ?',
              whereArgs: [uid],
            );
          }
          final rowId = _readInt(row['id']) ?? 0;
          if (rowId > 0) {
            await _replaceMemoFtsEntry(
              txn,
              rowId: rowId,
              content: (row['content'] as String?) ?? '',
              tags: updatedTagsText,
            );
          }
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  static Future<void> _ensureStatsCache(
    Database db, {
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
      await _rebuildStatsCache(db);
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
        await _rebuildStatsCache(db);
      }
    } catch (_) {
      await _rebuildStatsCache(db);
    }
  }

  static Future<void> _rebuildStatsCache(Database db) async {
    await db.transaction((txn) async {
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
        limit: _maintenanceBatchSize,
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
    await db.transaction((txn) async {
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

  static Future<void> _recreateFts(Database db) async {
    await db.execute('DROP TRIGGER IF EXISTS memos_ai;');
    await db.execute('DROP TRIGGER IF EXISTS memos_ad;');
    await db.execute('DROP TRIGGER IF EXISTS memos_au;');
    await db.execute('DROP TABLE IF EXISTS memos_fts;');
    await _ensureFts(db, rebuild: true);
  }

  static Future<void> _ensureFts(Database db, {bool rebuild = false}) async {
    // Ensure legacy triggers from previous versions are removed.
    await db.execute('DROP TRIGGER IF EXISTS memos_ai;');
    await db.execute('DROP TRIGGER IF EXISTS memos_ad;');
    await db.execute('DROP TRIGGER IF EXISTS memos_au;');
    await _dropLegacyFtsTriggers(db);

    // Prefer FTS5; fallback to FTS4; if both are unavailable, use a plain table
    // so writes keep working and search can gracefully fallback to LIKE.
    try {
      await _ensureFtsTable(db);
    } on DatabaseException catch (e) {
      if (await _recoverBrokenFtsModule(db, e)) {
        return;
      }
      rethrow;
    }

    if (rebuild) {
      try {
        await _backfillFts(db);
      } on DatabaseException catch (e) {
        if (await _recoverBrokenFtsModule(db, e)) {
          return;
        }
        rethrow;
      }
    } else {
      try {
        final counts = await db.rawQuery('''
SELECT
  (SELECT COUNT(*) FROM memos) AS memos_count,
  (SELECT COUNT(*) FROM memos_fts) AS fts_count;
''');
        final memosCount = (counts.firstOrNull?['memos_count'] as int?) ?? 0;
        final ftsCount = (counts.firstOrNull?['fts_count'] as int?) ?? 0;
        if (memosCount > 0 && ftsCount == 0) {
          await _backfillFts(db);
        }
      } on DatabaseException catch (e) {
        if (await _recoverBrokenFtsModule(db, e)) {
          return;
        }
      } catch (_) {}
    }
  }

  static bool _isMissingFtsModuleError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('no such module') &&
        (message.contains('fts5') || message.contains('fts4'));
  }

  static Future<bool> _recoverBrokenFtsModule(
    Database db,
    DatabaseException error,
  ) async {
    if (!_isMissingFtsModuleError(error)) {
      return false;
    }

    await _resetBrokenFtsSchema(db);

    try {
      await _ensureFtsTable(db);
      await _backfillFts(db);
      return true;
    } on DatabaseException catch (rebuildError) {
      if (_isMissingFtsModuleError(rebuildError)) {
        await _forceDropBrokenFtsSchema(db);
        try {
          await _ensureFtsTable(db);
          await _backfillFts(db);
          return true;
        } on DatabaseException catch (forcedRebuildError) {
          if (_isMissingFtsModuleError(forcedRebuildError)) {
            return true;
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  static Future<void> _resetBrokenFtsSchema(Database db) async {
    try {
      await db.execute('DROP TABLE IF EXISTS memos_fts;');
    } on DatabaseException catch (dropError) {
      if (!_isMissingFtsModuleError(dropError)) {
        rethrow;
      }
      await _forceDropBrokenFtsSchema(db);
    }
  }

  static Future<void> _forceDropBrokenFtsSchema(Database db) async {
    final schemaVersionRows = await db.rawQuery('PRAGMA schema_version;');
    final schemaVersion =
        (schemaVersionRows.firstOrNull?['schema_version'] as int?) ?? 0;

    await db.rawQuery('PRAGMA writable_schema = 1;');
    try {
      await db.rawDelete(
        "DELETE FROM sqlite_master WHERE name = ? OR name LIKE ?;",
        ['memos_fts', 'memos_fts_%'],
      );
    } finally {
      await db.rawQuery('PRAGMA writable_schema = 0;');
    }

    await db.rawQuery('PRAGMA schema_version = ${schemaVersion + 1};');
  }

  static Future<void> _ensureFtsTable(Database db) async {
    Future<bool> tryCreateVirtual(String module) async {
      try {
        await db.execute('''
CREATE VIRTUAL TABLE IF NOT EXISTS memos_fts USING $module(
  content,
  tags
);
''');
        return true;
      } on DatabaseException catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('no such module') || msg.contains(module)) {
          return false;
        }
        rethrow;
      }
    }

    if (await tryCreateVirtual('fts5')) return;
    if (await tryCreateVirtual('fts4')) return;

    await db.execute('''
CREATE TABLE IF NOT EXISTS memos_fts (
  content TEXT NOT NULL DEFAULT '',
  tags TEXT NOT NULL DEFAULT ''
);
''');
  }

  static Future<void> _backfillFts(Database db) async {
    await db.execute('DELETE FROM memos_fts;');
    final rows = await db.query(
      'memos',
      columns: const ['id', 'content', 'tags'],
    );
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) continue;
      await _replaceMemoFtsEntry(
        db,
        rowId: id,
        content: (row['content'] as String?) ?? '',
        tags: (row['tags'] as String?) ?? '',
      );
    }
  }

  static Future<void> _replaceMemoFtsEntry(
    DatabaseExecutor executor, {
    required int rowId,
    required String content,
    required String tags,
  }) async {
    try {
      await executor.insert('memos_fts', {
        'rowid': rowId,
        'content': content,
        'tags': tags,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on DatabaseException catch (e) {
      if (_isMissingFtsModuleError(e)) {
        return;
      }
      rethrow;
    }
  }

  static Future<void> _deleteMemoFtsEntry(
    DatabaseExecutor executor, {
    required int rowId,
  }) async {
    try {
      await executor.delete(
        'memos_fts',
        where: 'rowid = ?',
        whereArgs: [rowId],
      );
    } on DatabaseException catch (e) {
      if (_isMissingFtsModuleError(e)) {
        return;
      }
      rethrow;
    }
  }

  static String _toFtsQuery(String raw) {
    final tokens = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) {
          var s = t.replaceAll('"', '""');
          while (s.startsWith('#')) {
            s = s.substring(1);
          }
          return s;
        })
        .where((t) => t.isNotEmpty);

    return tokens.map((t) => '$t*').join(' ');
  }

  static Future<void> _dropLegacyFtsTriggers(Database db) async {
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' AND sql LIKE '%memos_fts%';",
      );
      for (final row in rows) {
        final name = row['name'];
        if (name is! String || name.trim().isEmpty) continue;
        await db.execute('DROP TRIGGER IF EXISTS ${_quoteIdentifier(name)};');
      }
    } catch (_) {}
  }

  static String _quoteIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    return '"$escaped"';
  }

  static Future<bool> _tableHasColumn(
    Database db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery(
      'PRAGMA table_info(${_quoteIdentifier(table)});',
    );
    return rows.any((row) => row['name'] == column);
  }

  static Future<void> _ensureColumnExists(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    if (await _tableHasColumn(db, table, column)) {
      return;
    }
    await db.execute(
      'ALTER TABLE ${_quoteIdentifier(table)} ADD COLUMN $definition;',
    );
  }

  static Future<void> _ensureAiTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_memo_policy (
  memo_uid TEXT PRIMARY KEY,
  allow_ai INTEGER NOT NULL DEFAULT 1,
  updated_time INTEGER NOT NULL,
  FOREIGN KEY (memo_uid) REFERENCES memos(uid) ON DELETE CASCADE ON UPDATE CASCADE
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  memo_uid TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  content TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  memo_content_hash TEXT NOT NULL,
  char_start INTEGER NOT NULL,
  char_end INTEGER NOT NULL,
  token_estimate INTEGER NOT NULL,
  memo_create_time INTEGER NOT NULL,
  memo_update_time INTEGER NOT NULL,
  memo_visibility TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  invalidated_time INTEGER,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  FOREIGN KEY (memo_uid) REFERENCES memos(uid) ON DELETE CASCADE ON UPDATE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_chunks_memo_active_idx ON ai_chunks(memo_uid, is_active, chunk_index);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_chunks_time_active ON ai_chunks(memo_create_time DESC, is_active);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_chunks_content_hash ON ai_chunks(content_hash);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_embeddings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chunk_id INTEGER NOT NULL,
  backend_kind TEXT NOT NULL,
  provider_kind TEXT NOT NULL,
  base_url TEXT NOT NULL,
  model TEXT NOT NULL,
  model_version TEXT NOT NULL DEFAULT '',
  dimensions INTEGER NOT NULL,
  vector_blob BLOB,
  status TEXT NOT NULL,
  error_text TEXT,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  FOREIGN KEY (chunk_id) REFERENCES ai_chunks(id) ON DELETE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_embeddings_chunk_status ON ai_embeddings(chunk_id, status);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_embeddings_model_status ON ai_embeddings(model, status);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_embeddings_profile ON ai_embeddings(base_url, model, chunk_id);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_index_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  memo_uid TEXT,
  reason TEXT NOT NULL,
  memo_content_hash TEXT NOT NULL DEFAULT '',
  embedding_profile_key TEXT NOT NULL,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  priority INTEGER NOT NULL DEFAULT 100,
  retry_at INTEGER,
  error_text TEXT,
  created_time INTEGER NOT NULL,
  started_time INTEGER,
  finished_time INTEGER
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_index_jobs_status_priority ON ai_index_jobs(status, priority, created_time);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_index_jobs_memo_profile_hash ON ai_index_jobs(memo_uid, embedding_profile_key, memo_content_hash);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_analysis_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_uid TEXT NOT NULL UNIQUE,
  analysis_type TEXT NOT NULL,
  status TEXT NOT NULL,
  range_start INTEGER NOT NULL,
  range_end_exclusive INTEGER NOT NULL,
  include_public INTEGER NOT NULL DEFAULT 1,
  include_private INTEGER NOT NULL DEFAULT 0,
  include_protected INTEGER NOT NULL DEFAULT 0,
  prompt_template TEXT NOT NULL,
  generation_profile_key TEXT NOT NULL,
  embedding_profile_key TEXT NOT NULL,
  retrieval_profile_json TEXT NOT NULL,
  error_text TEXT,
  mailbox_delivery_state TEXT NOT NULL DEFAULT 'hidden',
  mailbox_open_state TEXT NOT NULL DEFAULT 'unread',
  reply_animation_state TEXT NOT NULL DEFAULT 'idle',
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  completed_time INTEGER
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_tasks_status_time ON ai_analysis_tasks(status, created_time DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_tasks_type_time ON ai_analysis_tasks(analysis_type, created_time DESC);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_analysis_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL UNIQUE,
  schema_version INTEGER NOT NULL,
  analysis_type TEXT NOT NULL,
  summary TEXT NOT NULL,
  follow_up_suggestions_json TEXT NOT NULL,
  raw_response_text TEXT NOT NULL DEFAULT '',
  normalized_result_json TEXT NOT NULL,
  is_stale INTEGER NOT NULL DEFAULT 0,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  FOREIGN KEY (task_id) REFERENCES ai_analysis_tasks(id) ON DELETE CASCADE
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_analysis_sections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  result_id INTEGER NOT NULL,
  section_key TEXT NOT NULL,
  section_order INTEGER NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_time INTEGER NOT NULL,
  FOREIGN KEY (result_id) REFERENCES ai_analysis_results(id) ON DELETE CASCADE,
  UNIQUE(result_id, section_key)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_sections_result_order ON ai_analysis_sections(result_id, section_order);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS ai_analysis_evidences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  result_id INTEGER NOT NULL,
  section_id INTEGER NOT NULL,
  evidence_order INTEGER NOT NULL,
  memo_uid TEXT NOT NULL,
  chunk_id INTEGER NOT NULL,
  quote_text TEXT NOT NULL,
  char_start INTEGER NOT NULL,
  char_end INTEGER NOT NULL,
  relevance_score REAL NOT NULL,
  created_time INTEGER NOT NULL,
  FOREIGN KEY (result_id) REFERENCES ai_analysis_results(id) ON DELETE CASCADE,
  FOREIGN KEY (section_id) REFERENCES ai_analysis_sections(id) ON DELETE CASCADE,
  FOREIGN KEY (chunk_id) REFERENCES ai_chunks(id) ON DELETE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_evidences_result_section_order ON ai_analysis_evidences(result_id, section_id, evidence_order);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_evidences_memo_uid ON ai_analysis_evidences(memo_uid);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_analysis_evidences_chunk_id ON ai_analysis_evidences(chunk_id);',
    );
  }
}

class _MemoSnapshot {
  const _MemoSnapshot({
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

class ResolvedTag {
  const ResolvedTag({required this.id, required this.path});

  final int id;
  final String path;
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
