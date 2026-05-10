import 'package:sqflite/sqflite.dart';

import '../../core/tags.dart';
import '../models/tag.dart';
import '../models/tag_snapshot.dart';

final class TagDbPersistence {
  const TagDbPersistence._();

  static const Object keepParentId = Object();

  static Future<void> ensureTables(Database db) async {
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

  static Future<List<TagEntity>> listTags(DatabaseExecutor executor) async {
    final rows = await executor.query('tags', orderBy: 'path ASC');
    return rows.map(TagEntity.fromDb).toList(growable: false);
  }

  static Future<TagEntity?> getTagByPath(
    DatabaseExecutor executor,
    String path,
  ) async {
    final normalized = normalizeTagPath(path);
    if (normalized.isEmpty) return null;
    final rows = await executor.query(
      'tags',
      where: 'path = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TagEntity.fromDb(rows.first);
  }

  static Future<TagSnapshot> readSnapshot(DatabaseExecutor executor) async {
    final tagRows = await executor.query('tags', orderBy: 'id ASC');
    final aliasRows = await executor.query('tag_aliases', orderBy: 'id ASC');
    final tags = tagRows.map(TagEntity.fromDb).toList(growable: false);
    final aliases = aliasRows
        .map(TagAliasRecord.fromDb)
        .toList(growable: false);
    return TagSnapshot(tags: tags, aliases: aliases);
  }

  static Future<ResolvedTag?> resolvePath(
    DatabaseExecutor executor,
    String rawTag,
  ) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final direct = await findResolvedTag(executor, normalized);
    if (direct != null) return direct;

    final parts = normalized
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return null;

    int? parentId;
    var path = '';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    for (final part in parts) {
      final name = part.trim();
      if (name.isEmpty) continue;
      final rows = await executor.query(
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
      final insertedId = await insertTagRow(
        executor,
        name: name,
        parentId: parentId,
        path: path,
        pinned: false,
        colorHex: null,
        createTimeSec: now,
        updateTimeSec: now,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (insertedId == 0) {
        final existing = await executor.query(
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

  static Future<ResolvedTag?> findResolvedTag(
    DatabaseExecutor executor,
    String rawTag,
  ) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final directRows = await executor.query(
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
      if (id > 0 && path.trim().isNotEmpty) {
        return ResolvedTag(id: id, path: path);
      }
    }

    final aliasRows = await executor.query(
      'tag_aliases',
      columns: const ['tag_id'],
      where: 'alias = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (aliasRows.isEmpty) return null;
    final tagId = _readInt(aliasRows.first['tag_id']) ?? 0;
    if (tagId <= 0) return null;
    final tagRows = await executor.query(
      'tags',
      columns: const ['id', 'path'],
      where: 'id = ?',
      whereArgs: [tagId],
      limit: 1,
    );
    if (tagRows.isEmpty) return null;
    final row = tagRows.first;
    final path = row['path'] as String? ?? normalized;
    if (path.trim().isEmpty) return null;
    return ResolvedTag(id: tagId, path: path);
  }

  static Future<ResolvedTag?> restoreTagFromExisting(
    DatabaseExecutor executor,
    String rawTag, {
    required Map<String, TagEntity> existingTagsByPath,
    required Map<int, TagEntity> existingTagsById,
    required Map<String, List<TagAliasRecord>> existingAliasesByPath,
  }) async {
    final normalized = normalizeTagPath(rawTag);
    if (normalized.isEmpty) return null;

    final existing = existingTagsByPath[normalized];
    if (existing == null) return null;

    final resolved = await findResolvedTag(executor, normalized);
    if (resolved != null) return resolved;

    ResolvedTag? restoredParent;
    final parentFromId = existing.parentId == null
        ? null
        : existingTagsById[existing.parentId!];
    if (parentFromId != null) {
      restoredParent = await restoreTagFromExisting(
        executor,
        parentFromId.path,
        existingTagsByPath: existingTagsByPath,
        existingTagsById: existingTagsById,
        existingAliasesByPath: existingAliasesByPath,
      );
    } else {
      final slashIndex = existing.path.lastIndexOf('/');
      if (slashIndex > 0) {
        restoredParent = await restoreTagFromExisting(
          executor,
          existing.path.substring(0, slashIndex),
          existingTagsByPath: existingTagsByPath,
          existingTagsById: existingTagsById,
          existingAliasesByPath: existingAliasesByPath,
        );
      }
    }

    await insertTagEntity(
      executor,
      existing,
      parentIdOverride: restoredParent?.id,
      preserveId: false,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final restored = await findResolvedTag(executor, existing.path);
    if (restored == null) return null;

    final aliases =
        existingAliasesByPath[existing.path] ?? const <TagAliasRecord>[];
    for (final alias in aliases) {
      final normalizedAlias = normalizeTagPath(alias.alias);
      if (normalizedAlias.isEmpty || normalizedAlias == restored.path) {
        continue;
      }
      await insertAliasRow(
        executor,
        tagId: restored.id,
        alias: normalizedAlias,
        createdTimeSec: alias.createdTimeSec,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return restored;
  }

  static Future<void> updateMemoTagsMapping(
    DatabaseExecutor executor,
    String memoUid,
    List<int> tagIds,
  ) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    await executor.delete(
      'memo_tags',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
    if (tagIds.isEmpty) return;
    final batch = executor.batch();
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

  static Future<List<String>> listMemoUidsByTagId(
    DatabaseExecutor executor,
    int tagId,
  ) {
    return listMemoUidsByTagIds(executor, [tagId]);
  }

  static Future<List<String>> listMemoUidsByTagIds(
    DatabaseExecutor executor,
    List<int> tagIds,
  ) async {
    if (tagIds.isEmpty) return const [];
    final placeholders = List.filled(tagIds.length, '?').join(', ');
    final rows = await executor.rawQuery(
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

  static Future<List<String>> listTagPathsForMemo(
    DatabaseExecutor executor,
    String memoUid,
  ) async {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return const [];
    final rows = await executor.rawQuery(
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

  static Future<TagEntity?> loadTag(DatabaseExecutor executor, int id) async {
    if (id <= 0) return null;
    final rows = await executor.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TagEntity.fromDb(rows.first);
  }

  static Future<void> ensureUniqueName(
    DatabaseExecutor executor, {
    required String name,
    required int? parentId,
    required int? excludeId,
  }) async {
    final rows = await executor.query(
      'tags',
      columns: const ['id'],
      where: parentId == null
          ? 'name = ? AND parent_id IS NULL'
          : 'name = ? AND parent_id = ?',
      whereArgs: parentId == null ? [name] : [name, parentId],
      limit: 1,
    );
    final existingId = rows.isNotEmpty ? (_readInt(rows.first['id']) ?? 0) : 0;
    if (existingId > 0 && existingId != excludeId) {
      throw StateError('Tag name already exists');
    }
  }

  static Future<void> assertNoCycle(
    DatabaseExecutor executor,
    int id,
    int? parentId,
  ) async {
    if (parentId == null) return;
    if (parentId == id) {
      throw StateError('Tag cannot be its own parent');
    }
    int? current = parentId;
    final visited = <int>{};
    while (current != null && visited.add(current)) {
      if (current == id) {
        throw StateError('Tag hierarchy cycle detected');
      }
      final rows = await executor.query(
        'tags',
        columns: const ['parent_id'],
        where: 'id = ?',
        whereArgs: [current],
        limit: 1,
      );
      if (rows.isEmpty) break;
      current = _readInt(rows.first['parent_id']);
    }
  }

  static Future<int> insertTagRow(
    DatabaseExecutor executor, {
    int? id,
    required String name,
    required int? parentId,
    required String path,
    required bool pinned,
    required String? colorHex,
    required int createTimeSec,
    required int updateTimeSec,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return executor.insert('tags', {
      if (id != null) 'id': id,
      'name': name,
      'parent_id': parentId,
      'path': path,
      'pinned': pinned ? 1 : 0,
      'color_hex': colorHex,
      'create_time': createTimeSec,
      'update_time': updateTimeSec,
    }, conflictAlgorithm: conflictAlgorithm);
  }

  static Future<int> insertTagEntity(
    DatabaseExecutor executor,
    TagEntity tag, {
    Object? parentIdOverride = keepParentId,
    bool preserveId = true,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final parentId = identical(parentIdOverride, keepParentId)
        ? tag.parentId
        : parentIdOverride as int?;
    return insertTagRow(
      executor,
      id: preserveId && tag.id > 0 ? tag.id : null,
      name: tag.name,
      parentId: parentId,
      path: tag.path,
      pinned: tag.pinned,
      colorHex: tag.colorHex,
      createTimeSec: tag.createTimeSec,
      updateTimeSec: tag.updateTimeSec,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  static Future<void> insertAliasRow(
    DatabaseExecutor executor, {
    required int tagId,
    required String alias,
    required int createdTimeSec,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    await executor.insert('tag_aliases', {
      'tag_id': tagId,
      'alias': alias,
      'created_time': createdTimeSec,
    }, conflictAlgorithm: conflictAlgorithm);
  }

  static Future<void> insertAliasRecord(
    DatabaseExecutor executor,
    TagAliasRecord alias, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return insertAliasRow(
      executor,
      tagId: alias.tagId,
      alias: alias.alias,
      createdTimeSec: alias.createdTimeSec,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  static Future<void> updateTagValues(
    DatabaseExecutor executor,
    int id,
    Map<String, Object?> values,
  ) async {
    if (id <= 0 || values.isEmpty) return;
    await executor.update('tags', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> listSubtreeRows(
    DatabaseExecutor executor,
    String path,
  ) {
    return executor.query(
      'tags',
      columns: const ['id', 'path', 'parent_id'],
      where: 'path = ? OR path LIKE ?',
      whereArgs: [path, '$path/%'],
    );
  }

  static Future<List<Map<String, dynamic>>> listDescendantRows(
    DatabaseExecutor executor,
    String path,
  ) {
    return executor.query(
      'tags',
      columns: const ['id', 'path', 'parent_id'],
      where: 'path LIKE ?',
      whereArgs: ['$path/%'],
    );
  }

  static Future<int> findTagIdByPath(
    DatabaseExecutor executor,
    String path,
  ) async {
    final rows = await executor.query(
      'tags',
      columns: const ['id'],
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return rows.isNotEmpty ? (_readInt(rows.first['id']) ?? 0) : 0;
  }

  static Future<void> deleteAllRowsForSnapshot(
    DatabaseExecutor executor,
  ) async {
    await executor.delete('memo_tags');
    await executor.delete('tag_aliases');
    await executor.delete('tags');
  }

  static Future<void> deleteTagById(DatabaseExecutor executor, int id) async {
    await executor.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  static int? readInt(Object? value) => _readInt(value);

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class ResolvedTag {
  const ResolvedTag({required this.id, required this.path});

  final int id;
  final String path;
}
