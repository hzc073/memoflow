import 'package:sqflite/sqflite.dart';

final class CollectionDbPersistence {
  const CollectionDbPersistence._();

  static Future<void> ensureTables(Database db) async {
    await ensureCollectionTables(db);
    await ensureReaderProgressTable(db);
  }

  static Future<void> ensureCollectionTables(Database db) async {
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
    await db.execute('''
CREATE TABLE IF NOT EXISTS memo_collection_items (
  collection_id TEXT NOT NULL,
  memo_uid TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_time INTEGER NOT NULL,
  updated_time INTEGER NOT NULL,
  PRIMARY KEY (collection_id, memo_uid),
  FOREIGN KEY (collection_id) REFERENCES memo_collections(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (memo_uid) REFERENCES memos(uid) ON DELETE CASCADE ON UPDATE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memo_collections_archived_pinned_order ON memo_collections(archived, pinned DESC, sort_order ASC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memo_collections_updated_time ON memo_collections(updated_time DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memo_collection_items_collection_order ON memo_collection_items(collection_id, sort_order ASC, created_time ASC);',
    );
  }

  static Future<void> ensureReaderProgressTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS collection_read_progress (
  collection_id TEXT NOT NULL PRIMARY KEY,
  reader_mode TEXT NOT NULL,
  page_animation TEXT NOT NULL DEFAULT 'simulation',
  current_memo_uid TEXT,
  current_memo_index INTEGER NOT NULL DEFAULT 0,
  current_chapter_page_index INTEGER NOT NULL DEFAULT 0,
  list_scroll_offset REAL NOT NULL DEFAULT 0,
  current_match_char_offset INTEGER,
  updated_time INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_collection_read_progress_updated ON collection_read_progress(updated_time DESC);',
    );
  }

  static Future<void> ensureReaderProgressPageColumns(Database db) async {
    await _ensureColumnExists(
      db,
      table: 'collection_read_progress',
      column: 'page_animation',
      definition: "page_animation TEXT NOT NULL DEFAULT 'simulation'",
    );
    await _ensureColumnExists(
      db,
      table: 'collection_read_progress',
      column: 'current_chapter_page_index',
      definition: 'current_chapter_page_index INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumnExists(
      db,
      table: 'collection_read_progress',
      column: 'current_match_char_offset',
      definition: 'current_match_char_offset INTEGER',
    );
  }

  static Future<Map<String, dynamic>?> getReaderProgressRow(
    DatabaseExecutor executor,
    String collectionId,
  ) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) {
      return null;
    }
    final rows = await executor.query(
      'collection_read_progress',
      where: 'collection_id = ?',
      whereArgs: <Object?>[normalizedCollectionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  static Future<void> upsertReaderProgressRow(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    await executor.insert(
      'collection_read_progress',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteReaderProgress(
    DatabaseExecutor executor,
    String collectionId,
  ) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) {
      return;
    }
    await executor.delete(
      'collection_read_progress',
      where: 'collection_id = ?',
      whereArgs: <Object?>[normalizedCollectionId],
    );
  }

  static Future<void> _ensureColumnExists(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final rows = await db.rawQuery(
      'PRAGMA table_info(${_quoteIdentifier(table)});',
    );
    if (rows.any((row) => row['name'] == column)) {
      return;
    }
    await db.execute(
      'ALTER TABLE ${_quoteIdentifier(table)} ADD COLUMN $definition;',
    );
  }

  static String _quoteIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    return '"$escaped"';
  }
}
