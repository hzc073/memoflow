import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/uid.dart';
import '../logs/log_manager.dart';
import '../../state/system/database_provider.dart';
import '../db/app_database.dart';
import '../db/app_database_write_dao.dart';
import '../models/memo_collection.dart';

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  return CollectionsRepository(db: ref.watch(databaseProvider));
});

class CollectionsRepository {
  CollectionsRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<List<MemoCollection>> readAll() async {
    final sqlite = await _db.db;
    final rows = await sqlite.query(
      'memo_collections',
      orderBy:
          'pinned DESC, sort_order ASC, updated_time DESC, title COLLATE NOCASE ASC',
    );
    return rows.map(MemoCollection.fromDb).toList(growable: false);
  }

  Future<MemoCollection?> readById(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return null;
    final sqlite = await _db.db;
    final rows = await sqlite.query(
      'memo_collections',
      where: 'id = ?',
      whereArgs: <Object?>[trimmedId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MemoCollection.fromDb(rows.first);
  }

  Future<void> upsert(MemoCollection collection) async {
    final sqlite = await _db.db;
    final existing = await readById(collection.id);
    final effectiveSortOrder = existing != null || collection.sortOrder > 0
        ? collection.sortOrder
        : await _nextSortOrder(sqlite);
    final now = DateTime.now();
    final effective = collection.copyWith(
      sortOrder: effectiveSortOrder,
      updatedTime: now,
      createdTime: existing?.createdTime ?? collection.createdTime,
    );
    final row = _toRow(effective);
    if (existing == null) {
      await sqlite.insert('memo_collections', row);
    } else {
      await sqlite.update(
        'memo_collections',
        row,
        where: 'id = ?',
        whereArgs: <Object?>[effective.id],
      );
    }
    _db.notifyDataChanged();
    LogManager.instance.info(
      existing == null ? 'Collection created' : 'Collection updated',
      context: _collectionContext(
        effective,
        extra: <String, Object?>{
          'operation': existing == null ? 'create' : 'update',
        },
      ),
    );
  }

  Future<void> delete(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;
    final sqlite = await _db.db;
    final deletedCount = await sqlite.delete(
      'memo_collections',
      where: 'id = ?',
      whereArgs: <Object?>[trimmedId],
    );
    _db.notifyDataChanged();
    LogManager.instance.info(
      'Collection deleted',
      context: <String, Object?>{
        'collectionId': trimmedId,
        'deletedCount': deletedCount,
      },
    );
  }

  Future<void> archive(String id, bool archived) async {
    await _updateFlags(id, <String, Object?>{
      'archived': archived ? 1 : 0,
      'updated_time': _nowSec(),
    });
    LogManager.instance.info(
      archived ? 'Collection archived' : 'Collection restored',
      context: <String, Object?>{
        'collectionId': id.trim(),
        'archived': archived,
      },
    );
  }

  Future<void> pin(String id, bool pinned) async {
    await _updateFlags(id, <String, Object?>{
      'pinned': pinned ? 1 : 0,
      'updated_time': _nowSec(),
    });
    LogManager.instance.info(
      pinned ? 'Collection pinned' : 'Collection unpinned',
      context: <String, Object?>{'collectionId': id.trim(), 'pinned': pinned},
    );
  }

  Future<void> reorder(List<String> orderedIds) async {
    final normalized = orderedIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) return;
    final sqlite = await _db.db;
    final existingRows = await sqlite.query(
      'memo_collections',
      columns: const <String>['id'],
      orderBy:
          'pinned DESC, sort_order ASC, updated_time DESC, title COLLATE NOCASE ASC',
    );
    final existingIds = existingRows
        .map((row) => (row['id'] as String?)?.trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final seen = <String>{};
    final effectiveOrder = <String>[
      for (final id in normalized)
        if (seen.add(id)) id,
      for (final id in existingIds)
        if (seen.add(id)) id,
    ];
    if (effectiveOrder.isEmpty) return;
    final now = _nowSec();
    await AppDatabaseWriteDao.runTransaction<void>(sqlite, (txn) async {
      for (var index = 0; index < effectiveOrder.length; index++) {
        await txn.update(
          'memo_collections',
          <String, Object?>{'sort_order': index, 'updated_time': now},
          where: 'id = ?',
          whereArgs: <Object?>[effectiveOrder[index]],
        );
      }
    });
    _db.notifyDataChanged();
    LogManager.instance.info(
      'Collections reordered',
      context: <String, Object?>{
        'collectionCount': effectiveOrder.length,
        'orderedIds': effectiveOrder.take(10).toList(growable: false),
      },
    );
  }

  Future<void> addManualItems(
    String collectionId,
    List<String> memoUids,
  ) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) return;
    final normalizedMemoUids = memoUids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedMemoUids.isEmpty) return;

    final sqlite = await _db.db;
    final existing = await readManualItemUids(normalizedCollectionId);
    final existingSet = existing.toSet();
    final pending = normalizedMemoUids
        .where((item) => !existingSet.contains(item))
        .toList(growable: false);
    if (pending.isEmpty) return;

    final now = _nowSec();
    final startOrder = existing.length;
    await AppDatabaseWriteDao.runTransaction<void>(sqlite, (txn) async {
      for (var index = 0; index < pending.length; index++) {
        await txn.insert('memo_collection_items', <String, Object?>{
          'collection_id': normalizedCollectionId,
          'memo_uid': pending[index],
          'sort_order': startOrder + index,
          'created_time': now,
          'updated_time': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    await _touchCollection(normalizedCollectionId);
    LogManager.instance.info(
      'Manual collection items added',
      context: <String, Object?>{
        'collectionId': normalizedCollectionId,
        'addedCount': pending.length,
        'memoUids': pending.take(10).toList(growable: false),
      },
    );
  }

  Future<void> removeManualItem(
    String collectionId,
    List<String> memoUids,
  ) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) return;
    final normalizedMemoUids = memoUids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalizedMemoUids.isEmpty) return;

    final sqlite = await _db.db;
    final placeholders = List<String>.filled(normalizedMemoUids.length, '?');
    final deletedCount = await sqlite.delete(
      'memo_collection_items',
      where: 'collection_id = ? AND memo_uid IN (${placeholders.join(', ')})',
      whereArgs: <Object?>[normalizedCollectionId, ...normalizedMemoUids],
    );
    await _normalizeManualItemSortOrder(
      sqlite,
      normalizedCollectionId,
      notify: false,
    );
    await _touchCollection(normalizedCollectionId);
    LogManager.instance.info(
      'Manual collection items removed',
      context: <String, Object?>{
        'collectionId': normalizedCollectionId,
        'requestedCount': normalizedMemoUids.length,
        'removedCount': deletedCount,
        'memoUids': normalizedMemoUids.take(10).toList(growable: false),
      },
    );
  }

  Future<List<String>> readManualItemUids(String collectionId) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) return const <String>[];
    final sqlite = await _db.db;
    final rows = await sqlite.query(
      'memo_collection_items',
      columns: const <String>['memo_uid'],
      where: 'collection_id = ?',
      whereArgs: <Object?>[normalizedCollectionId],
      orderBy: 'sort_order ASC, created_time ASC',
    );
    return rows
        .map((row) => (row['memo_uid'] as String?) ?? '')
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> reorderManualItems(
    String collectionId,
    List<String> memoUids,
  ) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) return;
    final normalizedMemoUids = memoUids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalizedMemoUids.isEmpty) return;

    final sqlite = await _db.db;
    final existing = await readManualItemUids(normalizedCollectionId);
    if (existing.isEmpty) return;
    final remainder = existing
        .where((item) => !normalizedMemoUids.contains(item))
        .toList(growable: false);
    final ordered = <String>[...normalizedMemoUids, ...remainder];
    final now = _nowSec();
    await AppDatabaseWriteDao.runTransaction<void>(sqlite, (txn) async {
      for (var index = 0; index < ordered.length; index++) {
        await txn.update(
          'memo_collection_items',
          <String, Object?>{'sort_order': index, 'updated_time': now},
          where: 'collection_id = ? AND memo_uid = ?',
          whereArgs: <Object?>[normalizedCollectionId, ordered[index]],
        );
      }
    });
    await _touchCollection(normalizedCollectionId);
    LogManager.instance.info(
      'Manual collection items reordered',
      context: <String, Object?>{
        'collectionId': normalizedCollectionId,
        'orderedCount': ordered.length,
        'orderedMemoUids': ordered.take(10).toList(growable: false),
      },
    );
  }

  Future<MemoCollection> duplicate(MemoCollection source) async {
    final now = DateTime.now();
    final copy = source.copyWith(
      id: generateUid(length: 16),
      title: _copyTitle(source.title),
      pinned: false,
      archived: false,
      sortOrder: 0,
      createdTime: now,
      updatedTime: now,
    );
    await upsert(copy);
    if (source.type == MemoCollectionType.manual) {
      final memoUids = await readManualItemUids(source.id);
      await addManualItems(copy.id, memoUids);
    }
    LogManager.instance.info(
      'Collection duplicated',
      context: <String, Object?>{
        'sourceCollectionId': source.id,
        'sourceType': source.type.name,
        'copyCollectionId': copy.id,
        'copyTitle': copy.title,
      },
    );
    return copy;
  }

  Future<void> _updateFlags(String id, Map<String, Object?> values) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;
    final sqlite = await _db.db;
    await sqlite.update(
      'memo_collections',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[trimmedId],
    );
    _db.notifyDataChanged();
  }

  Future<void> _touchCollection(String collectionId) async {
    await _updateFlags(collectionId, <String, Object?>{
      'updated_time': _nowSec(),
    });
  }

  Future<void> _normalizeManualItemSortOrder(
    Database sqlite,
    String collectionId, {
    bool notify = true,
  }) async {
    final rows = await sqlite.query(
      'memo_collection_items',
      columns: const <String>['memo_uid'],
      where: 'collection_id = ?',
      whereArgs: <Object?>[collectionId],
      orderBy: 'sort_order ASC, created_time ASC',
    );
    final now = _nowSec();
    await AppDatabaseWriteDao.runTransaction<void>(sqlite, (txn) async {
      for (var index = 0; index < rows.length; index++) {
        final memoUid = (rows[index]['memo_uid'] as String?) ?? '';
        if (memoUid.trim().isEmpty) continue;
        await txn.update(
          'memo_collection_items',
          <String, Object?>{'sort_order': index, 'updated_time': now},
          where: 'collection_id = ? AND memo_uid = ?',
          whereArgs: <Object?>[collectionId, memoUid],
        );
      }
    });
    if (notify) {
      _db.notifyDataChanged();
    }
  }

  Future<int> _nextSortOrder(Database sqlite) async {
    final rows = await sqlite.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) AS max_sort_order FROM memo_collections;',
    );
    final raw = rows.isEmpty ? null : rows.first['max_sort_order'];
    if (raw is int) return raw + 1;
    if (raw is num) return raw.toInt() + 1;
    return 0;
  }

  Map<String, Object?> _toRow(MemoCollection collection) {
    return <String, Object?>{
      'id': collection.id,
      'title': collection.title.trim(),
      'description': collection.description.trim(),
      'type': collection.type.name,
      'icon_key': collection.iconKey.trim().isEmpty
          ? MemoCollection.defaultIconKey
          : collection.iconKey.trim(),
      'accent_color_hex': collection.accentColorHex,
      'rules_json': jsonEncode(collection.rules.toJson()),
      'cover_json': jsonEncode(collection.cover.toJson()),
      'view_json': jsonEncode(collection.view.toJson()),
      'pinned': collection.pinned ? 1 : 0,
      'archived': collection.archived ? 1 : 0,
      'hide_when_empty': collection.hideWhenEmpty ? 1 : 0,
      'sort_order': collection.sortOrder,
      'created_time':
          collection.createdTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      'updated_time':
          collection.updatedTime.toUtc().millisecondsSinceEpoch ~/ 1000,
    };
  }

  int _nowSec() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  String _copyTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'Copy';
    return '$trimmed Copy';
  }

  Map<String, Object?> _collectionContext(
    MemoCollection collection, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return <String, Object?>{
      'collectionId': collection.id,
      'title': collection.title,
      'type': collection.type.name,
      'pinned': collection.pinned,
      'archived': collection.archived,
      'sortOrder': collection.sortOrder,
      ...extra,
    };
  }
}
