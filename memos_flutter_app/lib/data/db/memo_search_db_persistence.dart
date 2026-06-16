import 'package:sqflite/sqflite.dart';

import '../../core/memo_search_document_builder.dart';
import '../../core/memo_search_matcher.dart';
import '../models/memo_sort_order.dart';
import 'app_database_write_dao.dart';

final class MemoSearchDbFilters {
  const MemoSearchDbFilters({
    this.createdStartTimeSec,
    this.createdEndTimeSecExclusive,
    this.hasLocation,
    this.hasAttachments,
    this.hasRelations,
  });

  static const empty = MemoSearchDbFilters();

  final int? createdStartTimeSec;
  final int? createdEndTimeSecExclusive;
  final bool? hasLocation;
  final bool? hasAttachments;
  final bool? hasRelations;

  bool get isEmpty =>
      createdStartTimeSec == null &&
      createdEndTimeSecExclusive == null &&
      hasLocation == null &&
      hasAttachments == null &&
      hasRelations == null;
}

final class MemoSearchDbPersistence {
  const MemoSearchDbPersistence._();

  static const int defaultDirtyFallbackLimit = 64;

  static Future<List<Map<String, dynamic>>> listRows(
    Database db, {
    String? searchQuery,
    String? state,
    String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    MemoSortOrder sortOrder = MemoSortOrder.createDesc,
    int? limit = 100,
    int dirtyFallbackLimit = defaultDirtyFallbackLimit,
    MemoSearchDbFilters filters = MemoSearchDbFilters.empty,
  }) async {
    final trimmedTag = (tag ?? '').trim();
    final withoutHash = trimmedTag.startsWith('#')
        ? trimmedTag.substring(1)
        : trimmedTag;
    final normalizedTag = withoutHash.toLowerCase();
    final normalizedState = (state ?? '').trim();
    final normalizedSearch = MemoSearchMatcher.normalizeQuery(searchQuery);
    final normalizedLimit = (limit != null && limit > 0) ? limit : null;
    final orderBy = _orderBy(sortOrder);
    final aliasedOrderBy = _orderBy(sortOrder, alias: 'm');

    final baseWhereClauses = <String>[];
    final baseWhereArgs = <Object?>[];
    _appendBaseMemoWhere(
      baseWhereClauses,
      baseWhereArgs,
      normalizedState: normalizedState,
      normalizedTag: normalizedTag,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
    );
    _appendFilterWhere(baseWhereClauses, baseWhereArgs, filters: filters);

    Future<List<Map<String, dynamic>>> listBase() {
      return db.query(
        'memos',
        where: baseWhereClauses.isEmpty ? null : baseWhereClauses.join(' AND '),
        whereArgs: baseWhereArgs.isEmpty ? null : baseWhereArgs,
        orderBy: orderBy,
        limit: normalizedLimit,
      );
    }

    if (normalizedSearch.isEmpty) {
      return listBase();
    }

    final like = MemoSearchMatcher.toSqlLikePattern(normalizedSearch);
    final literalSearchClauses = <String>[];
    final literalSearchArgs = <Object?>[];
    _appendBaseMemoWhere(
      literalSearchClauses,
      literalSearchArgs,
      alias: 'm',
      normalizedState: normalizedState,
      normalizedTag: normalizedTag,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
    );
    _appendFilterWhere(
      literalSearchClauses,
      literalSearchArgs,
      alias: 'm',
      filters: filters,
    );
    literalSearchClauses.add('''
(
  m.content LIKE ? ESCAPE '\\'
  OR m.tags LIKE ? ESCAPE '\\'
  OR COALESCE(c.source_name, '') LIKE ? ESCAPE '\\'
  OR COALESCE(c.author_name, '') LIKE ? ESCAPE '\\'
  OR COALESCE(c.source_url, '') LIKE ? ESCAPE '\\'
)
''');

    Future<List<Map<String, dynamic>>> listByLiteralSearch() {
      final args = <Object?>[
        ...literalSearchArgs,
        like,
        like,
        like,
        like,
        like,
      ];
      final limitClause = normalizedLimit == null ? '' : '\nLIMIT ?';
      if (normalizedLimit != null) {
        args.add(normalizedLimit);
      }
      return db.rawQuery('''
SELECT DISTINCT m.*
FROM memos m
LEFT JOIN memo_clip_cards c ON c.memo_uid = m.uid
WHERE ${literalSearchClauses.join(' AND ')}
ORDER BY $aliasedOrderBy
$limitClause;
''', args);
    }

    try {
      final dirtyRows = await _listDirtyRows(
        db,
        normalizedState: normalizedState,
        normalizedTag: normalizedTag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        filters: filters,
        sortOrder: sortOrder,
        limit: dirtyFallbackLimit,
      );
      final dirtyMatched = <Map<String, dynamic>>[];
      for (final row in dirtyRows) {
        final document = MemoSearchDocumentBuilder.buildCanonical(
          content: (row['content'] as String?) ?? '',
          tagsText: (row['tags'] as String?) ?? '',
          sourceName: (row['source_name'] as String?) ?? '',
          authorName: (row['author_name'] as String?) ?? '',
          sourceUrl: (row['source_url'] as String?) ?? '',
        );
        if (!MemoSearchMatcher.matchesText(
          text: document,
          query: normalizedSearch,
        )) {
          continue;
        }
        dirtyMatched.add(
          Map<String, dynamic>.from(row)
            ..remove('source_name')
            ..remove('author_name')
            ..remove('source_url'),
        );
      }

      final grams = _buildQueryGrams(normalizedSearch);
      if (grams.isEmpty) {
        return _mergeRows(
          primary: dirtyMatched,
          secondary: await listByLiteralSearch(),
          limit: normalizedLimit,
          sortOrder: sortOrder,
        );
      }

      final gramPlaceholders = List.filled(grams.length, '?').join(', ');
      final indexedLike = MemoSearchMatcher.toSqlLikePattern(
        normalizedSearch.toLowerCase(),
      );
      final cleanWhereClauses = <String>[];
      final cleanMemoWhereArgs = <Object?>[];
      _appendBaseMemoWhere(
        cleanWhereClauses,
        cleanMemoWhereArgs,
        alias: 'm',
        normalizedState: normalizedState,
        normalizedTag: normalizedTag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
      );
      _appendFilterWhere(
        cleanWhereClauses,
        cleanMemoWhereArgs,
        alias: 'm',
        filters: filters,
      );
      cleanWhereClauses.add("sd.document LIKE ? ESCAPE '\\'");
      final cleanWhereArgs = <Object?>[
        ...grams,
        grams.length,
        ...cleanMemoWhereArgs,
        indexedLike,
      ];
      final cleanRows = await db.rawQuery('''
WITH candidate_rows AS (
  SELECT s.memo_row_id
  FROM memo_search_substrings s
  LEFT JOIN memo_search_dirty d ON d.memo_row_id = s.memo_row_id
  WHERE d.memo_row_id IS NULL
    AND s.gram IN ($gramPlaceholders)
  GROUP BY s.memo_row_id
  HAVING COUNT(DISTINCT s.gram) = ?
)
SELECT DISTINCT m.*
FROM candidate_rows cr
JOIN memos m ON m.id = cr.memo_row_id
JOIN memo_search_documents sd ON sd.memo_row_id = m.id
WHERE ${cleanWhereClauses.join(' AND ')}
ORDER BY $aliasedOrderBy;
''', cleanWhereArgs);
      return _mergeRows(
        primary: dirtyMatched,
        secondary: cleanRows,
        limit: normalizedLimit,
        sortOrder: sortOrder,
      );
    } on DatabaseException {
      return listByLiteralSearch();
    }
  }

  static Future<String> buildDocumentForMemo(
    DatabaseExecutor executor, {
    required String memoUid,
    required String content,
  }) async {
    final clipRow = await getClipCardByUid(executor, memoUid);
    return MemoSearchDocumentBuilder.build(
      content: content,
      sourceName: (clipRow?['source_name'] as String? ?? '').trim(),
      authorName: (clipRow?['author_name'] as String? ?? '').trim(),
      sourceUrl: (clipRow?['source_url'] as String? ?? '').trim(),
    );
  }

  static Future<String> buildCanonicalDocumentForMemo(
    DatabaseExecutor executor, {
    required String memoUid,
    required String content,
    required String tags,
  }) async {
    final clipRow = await getClipCardByUid(executor, memoUid);
    return MemoSearchDocumentBuilder.buildCanonical(
      content: content,
      tagsText: tags,
      sourceName: (clipRow?['source_name'] as String? ?? '').trim(),
      authorName: (clipRow?['author_name'] as String? ?? '').trim(),
      sourceUrl: (clipRow?['source_url'] as String? ?? '').trim(),
    );
  }

  static Future<Map<String, dynamic>?> getClipCardByUid(
    DatabaseExecutor executor,
    String memoUid,
  ) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return null;
    final rows = await executor.query(
      'memo_clip_cards',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<void> recreateFts(Database db) async {
    await db.execute('DROP TRIGGER IF EXISTS memos_ai;');
    await db.execute('DROP TRIGGER IF EXISTS memos_ad;');
    await db.execute('DROP TRIGGER IF EXISTS memos_au;');
    await db.execute('DROP TABLE IF EXISTS memos_fts;');
    await ensureFts(db, rebuild: true);
  }

  static Future<void> ensureFts(Database db, {bool rebuild = false}) async {
    await db.execute('DROP TRIGGER IF EXISTS memos_ai;');
    await db.execute('DROP TRIGGER IF EXISTS memos_ad;');
    await db.execute('DROP TRIGGER IF EXISTS memos_au;');
    await _dropLegacyFtsTriggers(db);

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

  static Future<void> replaceFtsEntry(
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

  static Future<void> refreshFtsEntryForMemo(
    DatabaseExecutor executor, {
    required int rowId,
    required String memoUid,
    required String content,
    required String tags,
  }) async {
    final searchDocument = await buildDocumentForMemo(
      executor,
      memoUid: memoUid,
      content: content,
    );
    await replaceFtsEntry(
      executor,
      rowId: rowId,
      content: searchDocument,
      tags: tags,
    );
  }

  static Future<void> deleteFtsEntry(
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

  static Future<void> ensureIndex(Database db, {bool rebuild = false}) async {
    await _ensureIndexTables(db);
    if (rebuild) {
      await AppDatabaseWriteDao.runTransaction(db, (txn) async {
        await txn.delete('memo_search_substrings');
        await txn.delete('memo_search_documents');
        await txn.delete('memo_search_dirty');
      });
      await _enqueueAllMemos(db, replace: true);
      return;
    }
    try {
      final rows = await db.rawQuery('''
SELECT
  (SELECT COUNT(*) FROM memos) AS memos_count,
  (SELECT COUNT(*) FROM memo_search_documents) AS documents_count,
  (SELECT COUNT(*) FROM memo_search_dirty) AS dirty_count;
''');
      final memosCount = (rows.firstOrNull?['memos_count'] as int?) ?? 0;
      final documentsCount =
          (rows.firstOrNull?['documents_count'] as int?) ?? 0;
      final dirtyCount = (rows.firstOrNull?['dirty_count'] as int?) ?? 0;
      if (memosCount > 0 && documentsCount == 0 && dirtyCount == 0) {
        await _enqueueAllMemos(db);
      }
    } on DatabaseException {
      return;
    }
  }

  static Future<void> markDirty(
    DatabaseExecutor executor, {
    required int rowId,
    required String memoUid,
  }) async {
    final normalizedUid = memoUid.trim();
    if (rowId <= 0 || normalizedUid.isEmpty) return;
    await executor.insert('memo_search_dirty', {
      'memo_uid': normalizedUid,
      'memo_row_id': rowId,
      'updated_time': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> replaceIndexEntry(
    DatabaseExecutor executor, {
    required int rowId,
    required String memoUid,
    required String document,
  }) async {
    final normalizedUid = memoUid.trim();
    if (rowId <= 0 || normalizedUid.isEmpty) return;
    final normalizedDocument = document.trim().toLowerCase();
    await executor.delete(
      'memo_search_substrings',
      where: 'memo_row_id = ?',
      whereArgs: [rowId],
    );
    await executor.insert('memo_search_documents', {
      'memo_row_id': rowId,
      'memo_uid': normalizedUid,
      'document': normalizedDocument,
      'updated_time': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final grams = _buildIndexGrams(normalizedDocument);
    for (final gram in grams) {
      await executor.insert('memo_search_substrings', {
        'gram': gram,
        'memo_row_id': rowId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> deleteIndexEntry(
    DatabaseExecutor executor, {
    required int rowId,
    required String memoUid,
  }) async {
    if (rowId > 0) {
      await executor.delete(
        'memo_search_substrings',
        where: 'memo_row_id = ?',
        whereArgs: [rowId],
      );
      await executor.delete(
        'memo_search_documents',
        where: 'memo_row_id = ?',
        whereArgs: [rowId],
      );
    }
    await _deleteDirtyEntry(executor, memoUid: memoUid);
  }

  static Future<int> drainDirtyEntries(
    Database db, {
    required int limit,
  }) async {
    if (limit <= 0) return 0;
    final dirtyRows = await db.query(
      'memo_search_dirty',
      columns: const ['memo_uid', 'memo_row_id'],
      orderBy: 'updated_time ASC, memo_uid ASC',
      limit: limit,
    );
    if (dirtyRows.isEmpty) return 0;
    var processed = 0;
    await AppDatabaseWriteDao.runTransaction(db, (txn) async {
      for (final dirtyRow in dirtyRows) {
        final memoUid = (dirtyRow['memo_uid'] as String? ?? '').trim();
        if (memoUid.isEmpty) continue;
        final rowIdHint = _readInt(dirtyRow['memo_row_id']) ?? 0;
        final memoRows = await txn.rawQuery(
          '''
SELECT
  m.id,
  m.uid,
  m.content,
  m.tags,
  c.source_name,
  c.author_name,
  c.source_url
FROM memos m
LEFT JOIN memo_clip_cards c ON c.memo_uid = m.uid
WHERE m.uid = ?
LIMIT 1;
''',
          [memoUid],
        );
        if (memoRows.isEmpty) {
          await deleteIndexEntry(txn, rowId: rowIdHint, memoUid: memoUid);
          processed += 1;
          continue;
        }
        final memoRow = memoRows.first;
        final rowId = _readInt(memoRow['id']) ?? rowIdHint;
        if (rowId <= 0) {
          await _deleteDirtyEntry(txn, memoUid: memoUid);
          processed += 1;
          continue;
        }
        final document = MemoSearchDocumentBuilder.buildCanonical(
          content: (memoRow['content'] as String?) ?? '',
          tagsText: (memoRow['tags'] as String?) ?? '',
          sourceName: (memoRow['source_name'] as String?) ?? '',
          authorName: (memoRow['author_name'] as String?) ?? '',
          sourceUrl: (memoRow['source_url'] as String?) ?? '',
        );
        await replaceIndexEntry(
          txn,
          rowId: rowId,
          memoUid: memoUid,
          document: document,
        );
        await _deleteDirtyEntry(txn, memoUid: memoUid);
        processed += 1;
      }
    });
    return processed;
  }

  static Future<bool> hasDirtyEntries(DatabaseExecutor executor) async {
    final rows = await executor.query(
      'memo_search_dirty',
      columns: const ['memo_uid'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<void> _ensureIndexTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS memo_search_documents (
  memo_row_id INTEGER PRIMARY KEY,
  memo_uid TEXT NOT NULL UNIQUE,
  document TEXT NOT NULL DEFAULT '',
  updated_time INTEGER NOT NULL,
  FOREIGN KEY (memo_row_id) REFERENCES memos(id) ON DELETE CASCADE ON UPDATE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memo_search_documents_uid ON memo_search_documents(memo_uid);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS memo_search_substrings (
  gram TEXT NOT NULL,
  memo_row_id INTEGER NOT NULL,
  PRIMARY KEY (gram, memo_row_id),
  FOREIGN KEY (memo_row_id) REFERENCES memos(id) ON DELETE CASCADE ON UPDATE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memo_search_substrings_row ON memo_search_substrings(memo_row_id);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS memo_search_dirty (
  memo_uid TEXT PRIMARY KEY,
  memo_row_id INTEGER,
  updated_time INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memo_search_dirty_row ON memo_search_dirty(memo_row_id);',
    );
  }

  static Future<void> _enqueueAllMemos(
    Database db, {
    bool replace = false,
  }) async {
    final rows = await db.query('memos', columns: const ['id', 'uid']);
    if (rows.isEmpty) return;
    await AppDatabaseWriteDao.runTransaction(db, (txn) async {
      if (replace) {
        await txn.delete('memo_search_dirty');
      }
      for (final row in rows) {
        final rowId = _readInt(row['id']) ?? 0;
        final uid = (row['uid'] as String? ?? '').trim();
        if (rowId <= 0 || uid.isEmpty) continue;
        await markDirty(txn, rowId: rowId, memoUid: uid);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> _listDirtyRows(
    Database db, {
    required String normalizedState,
    required String normalizedTag,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required MemoSearchDbFilters filters,
    required MemoSortOrder sortOrder,
    required int limit,
  }) async {
    if (limit <= 0) return const <Map<String, dynamic>>[];
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];
    _appendBaseMemoWhere(
      whereClauses,
      whereArgs,
      alias: 'm',
      normalizedState: normalizedState,
      normalizedTag: normalizedTag,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
    );
    _appendFilterWhere(whereClauses, whereArgs, alias: 'm', filters: filters);
    final whereClause = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final orderBy = _orderBy(sortOrder, alias: 'm');
    return db.rawQuery(
      '''
SELECT DISTINCT
  m.*,
  c.source_name,
  c.author_name,
  c.source_url
FROM memo_search_dirty d
JOIN memos m ON m.uid = d.memo_uid
LEFT JOIN memo_clip_cards c ON c.memo_uid = m.uid
$whereClause
ORDER BY $orderBy
LIMIT ?;
''',
      <Object?>[...whereArgs, limit],
    );
  }

  static void _appendBaseMemoWhere(
    List<String> clauses,
    List<Object?> args, {
    String alias = '',
    required String normalizedState,
    required String normalizedTag,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
  }) {
    final prefix = _columnPrefix(alias);
    if (normalizedState.isNotEmpty) {
      clauses.add('${prefix}state = ?');
      args.add(normalizedState);
    }
    if (normalizedTag.isNotEmpty) {
      clauses.add("(' ' || ${prefix}tags || ' ') LIKE ?");
      args.add('% $normalizedTag %');
    }
    if (startTimeSec != null) {
      clauses.add('COALESCE(${prefix}display_time, ${prefix}create_time) >= ?');
      args.add(startTimeSec);
    }
    if (endTimeSecExclusive != null) {
      clauses.add('COALESCE(${prefix}display_time, ${prefix}create_time) < ?');
      args.add(endTimeSecExclusive);
    }
  }

  static void _appendFilterWhere(
    List<String> clauses,
    List<Object?> args, {
    String alias = '',
    required MemoSearchDbFilters filters,
  }) {
    if (filters.isEmpty) return;
    final prefix = _columnPrefix(alias);
    final createdStart = filters.createdStartTimeSec;
    if (createdStart != null) {
      clauses.add('${prefix}create_time >= ?');
      args.add(createdStart);
    }
    final createdEndExclusive = filters.createdEndTimeSecExclusive;
    if (createdEndExclusive != null) {
      clauses.add('${prefix}create_time < ?');
      args.add(createdEndExclusive);
    }

    final hasLocation = filters.hasLocation;
    if (hasLocation != null) {
      clauses.add(
        hasLocation
            ? '(${prefix}location_lat IS NOT NULL AND ${prefix}location_lng IS NOT NULL)'
            : '(${prefix}location_lat IS NULL OR ${prefix}location_lng IS NULL)',
      );
    }

    final hasAttachments = filters.hasAttachments;
    if (hasAttachments != null) {
      final expression = "TRIM(COALESCE(${prefix}attachments_json, '[]'))";
      clauses.add(
        hasAttachments
            ? "$expression NOT IN ('', '[]')"
            : "$expression IN ('', '[]')",
      );
    }

    final hasRelations = filters.hasRelations;
    if (hasRelations != null) {
      clauses.add(
        hasRelations
            ? '${prefix}relation_count > 0'
            : '${prefix}relation_count <= 0',
      );
    }
  }

  static String _columnPrefix(String alias) {
    final trimmed = alias.trim();
    return trimmed.isEmpty ? '' : '$trimmed.';
  }

  static List<Map<String, dynamic>> _mergeRows({
    required Iterable<Map<String, dynamic>> primary,
    required Iterable<Map<String, dynamic>> secondary,
    required int? limit,
    required MemoSortOrder sortOrder,
  }) {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addRow(Map<String, dynamic> row) {
      final uid = (row['uid'] as String? ?? '').trim();
      final id = _readInt(row['id']) ?? 0;
      final key = uid.isNotEmpty ? uid : 'row:$id';
      if (!seen.add(key)) return;
      merged.add(row);
    }

    for (final row in primary) {
      addRow(row);
    }
    for (final row in secondary) {
      addRow(Map<String, dynamic>.from(row));
    }
    merged.sort((a, b) => _compareRows(a, b, sortOrder));
    if (limit != null && limit > 0 && merged.length > limit) {
      return merged.take(limit).toList(growable: false);
    }
    return merged;
  }

  static int _compareRows(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    MemoSortOrder sortOrder,
  ) {
    final aPinned = (_readInt(a['pinned']) ?? 0) != 0;
    final bPinned = (_readInt(b['pinned']) ?? 0) != 0;
    if (aPinned != bPinned) {
      return aPinned ? -1 : 1;
    }
    final primaryCompare = switch (sortOrder) {
      MemoSortOrder.createAsc => _compareTime(
        _rowCreateDisplayTime(a),
        _rowCreateDisplayTime(b),
        ascending: true,
      ),
      MemoSortOrder.createDesc => _compareTime(
        _rowCreateDisplayTime(a),
        _rowCreateDisplayTime(b),
        ascending: false,
      ),
      MemoSortOrder.updateAsc => _compareTime(
        _readInt(a['update_time']) ?? 0,
        _readInt(b['update_time']) ?? 0,
        ascending: true,
      ),
      MemoSortOrder.updateDesc => _compareTime(
        _readInt(a['update_time']) ?? 0,
        _readInt(b['update_time']) ?? 0,
        ascending: false,
      ),
    };
    if (primaryCompare != 0) return primaryCompare;

    final fallbackCompare = _compareTime(
      _rowCreateDisplayTime(a),
      _rowCreateDisplayTime(b),
      ascending: false,
    );
    if (fallbackCompare != 0) return fallbackCompare;

    final uidCompare = ((a['uid'] as String?) ?? '').compareTo(
      (b['uid'] as String?) ?? '',
    );
    if (uidCompare != 0) return uidCompare;
    return (_readInt(a['id']) ?? 0).compareTo(_readInt(b['id']) ?? 0);
  }

  static int _rowCreateDisplayTime(Map<String, dynamic> row) {
    final displayTime = _readInt(row['display_time']);
    if (displayTime != null) return displayTime;
    return _readInt(row['create_time']) ?? 0;
  }

  static int _compareTime(int a, int b, {required bool ascending}) {
    if (a == b) return 0;
    return ascending ? a.compareTo(b) : b.compareTo(a);
  }

  static String _orderBy(MemoSortOrder sortOrder, {String? alias}) {
    final prefix = alias == null || alias.trim().isEmpty
        ? ''
        : '${alias.trim()}.';
    final createExpr = 'COALESCE(${prefix}display_time, ${prefix}create_time)';
    return switch (sortOrder) {
      MemoSortOrder.createAsc =>
        '${prefix}pinned DESC, $createExpr ASC, ${prefix}uid ASC',
      MemoSortOrder.createDesc =>
        '${prefix}pinned DESC, $createExpr DESC, ${prefix}uid ASC',
      MemoSortOrder.updateAsc =>
        '${prefix}pinned DESC, ${prefix}update_time ASC, $createExpr DESC, ${prefix}uid ASC',
      MemoSortOrder.updateDesc =>
        '${prefix}pinned DESC, ${prefix}update_time DESC, $createExpr DESC, ${prefix}uid ASC',
    };
  }

  static Set<String> _buildIndexGrams(String document) {
    final normalized = document.trim().toLowerCase();
    if (normalized.isEmpty) return const <String>{};
    final chars = normalized.runes
        .map(String.fromCharCode)
        .toList(growable: false);
    final grams = <String>{};
    for (final char in chars) {
      grams.add(char);
    }
    for (var i = 0; i < chars.length - 1; i += 1) {
      grams.add('${chars[i]}${chars[i + 1]}');
    }
    return grams;
  }

  static List<String> _buildQueryGrams(String query) {
    final normalized = MemoSearchMatcher.normalizeQuery(query).toLowerCase();
    if (normalized.isEmpty) return const <String>[];
    final chars = normalized.runes
        .map(String.fromCharCode)
        .toList(growable: false);
    if (chars.length == 1) {
      return <String>[chars.first];
    }
    final grams = <String>{};
    for (var i = 0; i < chars.length - 1; i += 1) {
      grams.add('${chars[i]}${chars[i + 1]}');
    }
    return grams.toList(growable: false);
  }

  static Future<void> _deleteDirtyEntry(
    DatabaseExecutor executor, {
    required String memoUid,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    await executor.delete(
      'memo_search_dirty',
      where: 'memo_uid = ?',
      whereArgs: [normalizedUid],
    );
  }

  static Future<void> _backfillFts(Database db) async {
    await db.execute('DELETE FROM memos_fts;');
    final rows = await db.rawQuery('''
SELECT
  m.id,
  m.content,
  m.tags,
  c.source_name,
  c.author_name,
  c.source_url
FROM memos m
LEFT JOIN memo_clip_cards c ON c.memo_uid = m.uid;
''');
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) continue;
      final document = MemoSearchDocumentBuilder.build(
        content: (row['content'] as String?) ?? '',
        sourceName: (row['source_name'] as String?) ?? '',
        authorName: (row['author_name'] as String?) ?? '',
        sourceUrl: (row['source_url'] as String?) ?? '',
      );
      await replaceFtsEntry(
        db,
        rowId: id,
        content: document,
        tags: (row['tags'] as String?) ?? '',
      );
    }
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

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _quoteIdentifier(String identifier) {
    final escaped = identifier.replaceAll('"', '""');
    return '"$escaped"';
  }
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
