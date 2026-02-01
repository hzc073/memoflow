import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/memo_location.dart';

class AppDatabase {
  AppDatabase({String dbName = 'memos_app.db'}) : _dbName = dbName;

  final String _dbName;
  static const _dbVersion = 8;

  Database? _db;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<Database> _open() async {
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);

    Future<Database> open() {
      return openDatabase(
        path,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
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
            await db.execute('ALTER TABLE memos ADD COLUMN relation_count INTEGER NOT NULL DEFAULT 0;');
          }
          if (oldVersion < 7) {
            await db.execute('ALTER TABLE memos ADD COLUMN location_placeholder TEXT;');
            await db.execute('ALTER TABLE memos ADD COLUMN location_lat REAL;');
            await db.execute('ALTER TABLE memos ADD COLUMN location_lng REAL;');
          }
          if (oldVersion < 8) {
            await _ensureStatsCache(db, rebuild: true);
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
      if (msg.contains('unrecognized parameter') && msg.contains('content_rowid')) {
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
    final basePath = await getDatabasesPath();
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

  static List<String> _normalizeTags(List<String> tags) {
    if (tags.isEmpty) return const [];
    final list = <String>[];
    for (final raw in tags) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      list.add(t);
    }
    return list;
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
    final rows = await txn.rawQuery('SELECT MIN(create_time) AS min_time FROM memos;');
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
    await txn.insert(
      'stats_cache',
      {
        'id': 1,
        'total_memos': 0,
        'archived_memos': 0,
        'total_chars': 0,
        'min_create_time': null,
        'updated_time': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      await txn.delete('daily_counts_cache', where: 'day = ?', whereArgs: [dayKey]);
      return;
    }
    if (rows.isEmpty) {
      await txn.insert('daily_counts_cache', {'day': dayKey, 'memo_count': next});
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

  Future<_MemoSnapshot?> _fetchMemoSnapshot(DatabaseExecutor txn, String uid) async {
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

    final oldChars = oldIsNormal && before != null ? _countChars(before.content) : 0;
    final newChars = newIsNormal && after != null ? _countChars(after.content) : 0;
    final deltaChars = newChars - oldChars;

    final oldDayKey = oldIsNormal && before != null ? _localDayKeyFromUtcSec(before.createTimeSec) : null;
    final newDayKey = newIsNormal && after != null ? _localDayKeyFromUtcSec(after.createTimeSec) : null;
    if (!(oldIsNormal && newIsNormal && oldDayKey == newDayKey)) {
      if (oldDayKey != null) {
        await _bumpDailyCount(txn, oldDayKey, -1);
      }
      if (newDayKey != null) {
        await _bumpDailyCount(txn, newDayKey, 1);
      }
    }

    final oldTagCounts = oldIsNormal && before != null ? _countTags(before.tags) : const <String, int>{};
    final newTagCounts = newIsNormal && after != null ? _countTags(after.tags) : const <String, int>{};
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
    if (deltaTotal != 0 || deltaArchived != 0 || deltaChars != 0 || nextMin != currentMin) {
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
    final normalizedTags = _normalizeTags(tags);
    final tagsText = normalizedTags.join(' ');
    final attachmentsJson = jsonEncode(attachments);
    final locationPlaceholder = location?.placeholder;
    final locationLat = location?.latitude;
    final locationLng = location?.longitude;

    await db.transaction((txn) async {
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
        rowId = await txn.insert(
          'memos',
          {
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
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        final rows = await txn.query('memos', columns: const ['id'], where: 'uid = ?', whereArgs: [uid], limit: 1);
        rowId = (rows.firstOrNull?['id'] as int?) ?? 0;
        if (rowId <= 0) return;
      }

      await txn.insert(
        'memos_fts',
        {
          'rowid': rowId,
          'content': content,
          'tags': tagsText,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final after = _MemoSnapshot(
        state: state,
        createTimeSec: createTimeSec,
        content: content,
        tags: normalizedTags,
      );
      await _applyMemoCacheDelta(txn, before: before, after: after);
    });
    _notifyChanged();
  }

  Future<void> updateMemoSyncState(String uid, {required int syncState, String? lastError}) async {
    final db = await this.db;
    await db.update(
      'memos',
      {
        'sync_state': syncState,
        'last_error': lastError,
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
    _notifyChanged();
  }

  Future<void> updateMemoAttachmentsJson(String uid, {required String attachmentsJson}) async {
    final db = await this.db;
    await db.update(
      'memos',
      {'attachments_json': attachmentsJson},
      where: 'uid = ?',
      whereArgs: [uid],
    );
    _notifyChanged();
  }

  Future<void> renameMemoUid({required String oldUid, required String newUid}) async {
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
    });
    _notifyChanged();
  }

  Future<void> rewriteOutboxMemoUids({required String oldUid, required String newUid}) async {
    final db = await this.db;
    final rows = await db.query('outbox', columns: const ['id', 'type', 'payload']);
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
    }
    _notifyChanged();
  }

  Future<Map<String, dynamic>?> getMemoByUid(String uid) async {
    final db = await this.db;
    final rows = await db.query('memos', where: 'uid = ?', whereArgs: [uid], limit: 1);
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
      'state': 0,
      'attempts': 0,
      'created_time': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
    _notifyChanged();
    return id;
  }

  Future<List<Map<String, dynamic>>> listOutboxPending({int limit = 50}) async {
    final db = await this.db;
    return db.query(
      'outbox',
      where: 'state IN (0, 2)',
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> listOutboxPendingByType(String type) async {
    final db = await this.db;
    return db.query(
      'outbox',
      columns: const ['id', 'payload'],
      where: 'state IN (0, 2) AND type = ?',
      whereArgs: [type],
      orderBy: 'id ASC',
    );
  }

  Future<void> markOutboxError(int id, {required String error}) async {
    final db = await this.db;
    await db.rawUpdate(
      'UPDATE outbox SET state = 2, attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
    _notifyChanged();
  }

  Future<void> deleteOutbox(int id) async {
    final db = await this.db;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
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
    final id = await db.insert(
      'import_history',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      final rows = await txn.query('memos', columns: const ['id'], where: 'uid = ?', whereArgs: [uid], limit: 1);
      final rowId = rows.firstOrNull?['id'] as int?;
      await txn.delete('memos', where: 'uid = ?', whereArgs: [uid]);
      if (rowId != null) {
        await txn.delete('memos_fts', where: 'rowid = ?', whereArgs: [rowId]);
      }
      await _applyMemoCacheDelta(txn, before: before, after: null);
    });
    _notifyChanged();
  }

  Future<Map<String, dynamic>?> getMemoReminderByUid(String memoUid) async {
    final db = await this.db;
    final rows = await db.query('memo_reminders', where: 'memo_uid = ?', whereArgs: [memoUid], limit: 1);
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
      {
        'mode': mode,
        'times_json': timesJson,
        'updated_time': now,
      },
      where: 'memo_uid = ?',
      whereArgs: [memoUid],
    );
    if (updated == 0) {
      await db.insert(
        'memo_reminders',
        {
          'memo_uid': memoUid,
          'mode': mode,
          'times_json': timesJson,
          'created_time': now,
          'updated_time': now,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    _notifyChanged();
  }

  Future<void> deleteMemoReminder(String memoUid) async {
    final db = await this.db;
    await db.delete('memo_reminders', where: 'memo_uid = ?', whereArgs: [memoUid]);
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

  Future<List<Map<String, dynamic>>> listMemoAttachmentRows({String? state}) async {
    final db = await this.db;
    final normalizedState = (state ?? '').trim();
    return db.query(
      'memos',
      columns: const ['uid', 'update_time', 'attachments_json'],
      where: [
        if (normalizedState.isNotEmpty) 'state = ?',
        "attachments_json <> '[]'",
      ].join(' AND '),
      whereArgs: [
        if (normalizedState.isNotEmpty) normalizedState,
      ],
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
    int limit = 100,
  }) async {
    final db = await this.db;
    final normalizedTag = (tag ?? '').trim();
    final normalizedState = (state ?? '').trim();
    final normalizedSearch = (searchQuery ?? '').trim();

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
        limit: limit,
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
    whereArgs.add(limit);

    try {
      return await db.rawQuery(
        '''
SELECT m.*
FROM memos m
JOIN memos_fts ON memos_fts.rowid = m.id
WHERE ${whereClauses.join(' AND ')}
ORDER BY m.pinned DESC, m.create_time DESC
LIMIT ?;
''',
        whereArgs,
      );
    } on DatabaseException {
      final like = '%$normalizedSearch%';
      final fallbackClauses = <String>[
        ...baseWhereClauses,
        '(content LIKE ? OR tags LIKE ?)',
      ];
      final fallbackArgs = <Object?>[
        ...baseWhereArgs,
        like,
        like,
      ];
      return db.query(
        'memos',
        where: fallbackClauses.join(' AND '),
        whereArgs: fallbackArgs,
        orderBy: 'pinned DESC, create_time DESC',
        limit: limit,
      );
    }
  }

  Future<List<Map<String, dynamic>>> listMemoUidSyncStates({String? state}) async {
    final db = await this.db;
    final normalizedState = (state ?? '').trim();
    return db.query(
      'memos',
      columns: const ['uid', 'sync_state'],
      where: normalizedState.isEmpty ? null : 'state = ?',
      whereArgs: normalizedState.isEmpty ? null : [normalizedState],
    );
  }

  Future<Set<String>> listPendingOutboxMemoUids() async {
    final db = await this.db;
    final rows = await db.query(
      'outbox',
      columns: const ['type', 'payload'],
      where: 'state IN (0, 2)',
    );

    final uids = <String>{};
    for (final row in rows) {
      final type = row['type'];
      final payloadRaw = row['payload'];
      if (type is! String || payloadRaw is! String) continue;
      Map<String, dynamic>? payload;
      try {
        payload = (jsonDecode(payloadRaw) as Map).cast<String, dynamic>();
      } catch (_) {
        continue;
      }
      final uid = switch (type) {
        'create_memo' || 'update_memo' || 'delete_memo' => payload['uid'],
        'upload_attachment' => payload['memo_uid'],
        _ => null,
      };
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
    int limit = 100,
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

  static Future<void> _ensureStatsCache(Database db, {bool rebuild = false}) async {
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

      final rows = await txn.query(
        'memos',
        columns: const ['state', 'create_time', 'content', 'tags'],
      );

      var totalMemos = 0;
      var archivedMemos = 0;
      var totalChars = 0;
      int? minCreateTime;
      final dailyCounts = <String, int>{};
      final tagCounts = <String, int>{};

      for (final row in rows) {
        final state = (row['state'] as String?) ?? 'NORMAL';
        final createTimeSec = row['create_time'] as int? ?? 0;
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

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await txn.insert(
        'stats_cache',
        {
          'id': 1,
          'total_memos': totalMemos,
          'archived_memos': archivedMemos,
          'total_chars': totalChars,
          'min_create_time': minCreateTime,
          'updated_time': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (dailyCounts.isNotEmpty || tagCounts.isNotEmpty) {
        final batch = txn.batch();
        dailyCounts.forEach((day, count) {
          batch.insert(
            'daily_counts_cache',
            {'day': day, 'memo_count': count},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        });
        tagCounts.forEach((tag, count) {
          batch.insert(
            'tag_stats_cache',
            {'tag': tag, 'memo_count': count},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
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

    // Create contentless FTS for maximum compatibility across SQLite builds.
    await db.execute('''
CREATE VIRTUAL TABLE IF NOT EXISTS memos_fts USING fts4(
  content,
  tags
);
''');

    if (rebuild) {
      await _backfillFts(db);
    } else {
      // Best-effort self-heal: if FTS is empty but memos exist, backfill.
      try {
        final counts = await db.rawQuery(
          '''
SELECT
  (SELECT COUNT(*) FROM memos) AS memos_count,
  (SELECT COUNT(*) FROM memos_fts) AS fts_count;
''',
        );
        final memosCount = (counts.firstOrNull?['memos_count'] as int?) ?? 0;
        final ftsCount = (counts.firstOrNull?['fts_count'] as int?) ?? 0;
        if (memosCount > 0 && ftsCount == 0) {
          await _backfillFts(db);
        }
      } catch (_) {}
    }
  }

  static Future<void> _backfillFts(Database db) async {
    await db.execute('DELETE FROM memos_fts;');
    final rows = await db.query('memos', columns: const ['id', 'content', 'tags']);
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) continue;
      await db.insert(
        'memos_fts',
        {
          'rowid': id,
          'content': (row['content'] as String?) ?? '',
          'tags': (row['tags'] as String?) ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
