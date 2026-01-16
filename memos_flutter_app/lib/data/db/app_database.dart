import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({String dbName = 'memos_app.db'}) : _dbName = dbName;

  final String _dbName;
  static const _dbVersion = 3;

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
  sync_state INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
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

          await _ensureFts(db, rebuild: true);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            await _recreateFts(db);
          }
        },
        onOpen: (db) async {
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
    required int syncState,
    String? lastError,
  }) async {
    final db = await this.db;
    final tagsText = tags.join(' ');
    final attachmentsJson = jsonEncode(attachments);

    await db.transaction((txn) async {
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
      'created_time': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
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

  Future<void> deleteMemoByUid(String uid) async {
    final db = await this.db;
    await db.transaction((txn) async {
      final rows = await txn.query('memos', columns: const ['id'], where: 'uid = ?', whereArgs: [uid], limit: 1);
      final rowId = rows.firstOrNull?['id'] as int?;
      await txn.delete('memos', where: 'uid = ?', whereArgs: [uid]);
      if (rowId != null) {
        await txn.delete('memos_fts', where: 'rowid = ?', whereArgs: [rowId]);
      }
    });
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
    int limit = 100,
  }) async {
    final db = await this.db;
    final normalizedTag = (tag ?? '').trim();
    final normalizedState = (state ?? '').trim();

    if (searchQuery == null || searchQuery.trim().isEmpty) {
      final whereClauses = <String>[];
      final whereArgs = <Object?>[];
      if (normalizedState.isNotEmpty) {
        whereClauses.add('state = ?');
        whereArgs.add(normalizedState);
      }
      if (normalizedTag.isNotEmpty) {
        whereClauses.add("(' ' || tags || ' ') LIKE ?");
        whereArgs.add('% $normalizedTag %');
      }
      return db.query(
        'memos',
        where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'pinned DESC, update_time DESC',
        limit: limit,
      );
    }

    final q = _toFtsQuery(searchQuery);
    final whereClauses = <String>['f MATCH ?'];
    final whereArgs = <Object?>[q];
    if (normalizedState.isNotEmpty) {
      whereClauses.add('m.state = ?');
      whereArgs.add(normalizedState);
    }
    if (normalizedTag.isNotEmpty) {
      whereClauses.add("(' ' || m.tags || ' ') LIKE ?");
      whereArgs.add('% $normalizedTag %');
    }
    whereArgs.add(limit);

    return db.rawQuery(
      '''
SELECT m.*
FROM memos m
JOIN memos_fts f ON f.rowid = m.id
WHERE ${whereClauses.join(' AND ')}
ORDER BY m.pinned DESC, m.update_time DESC
LIMIT ?;
''',
      whereArgs,
    );
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
    int limit = 100,
  }) async* {
    yield await listMemos(searchQuery: searchQuery, state: state, tag: tag, limit: limit);
    await for (final _ in changes) {
      yield await listMemos(searchQuery: searchQuery, state: state, tag: tag, limit: limit);
    }
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

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
