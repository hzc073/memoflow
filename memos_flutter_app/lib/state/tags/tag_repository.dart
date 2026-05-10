import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/app_database_write_dao.dart';
import '../../data/db/db_write_protocol.dart';
import '../../data/db/desktop_db_write_gateway.dart';
import '../../data/db/tag_db_persistence.dart';
import '../../data/models/tag.dart';
import '../../data/models/tag_snapshot.dart';
import '../system/database_provider.dart';

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(
    db: ref.watch(databaseProvider),
    writeGateway: ref.watch(desktopDbWriteGatewayProvider),
  );
});

class TagRepository {
  TagRepository({
    required AppDatabase db,
    DesktopDbWriteGateway? writeGateway,
    AppDatabaseWriteDao? writeDao,
  }) : _db = db,
       _writeGateway = writeGateway,
       _writeDao = writeDao ?? AppDatabaseWriteDao(db: db);

  final AppDatabase _db;
  final DesktopDbWriteGateway? _writeGateway;
  final AppDatabaseWriteDao _writeDao;
  static const Object _unsetParent = Object();
  int _localWriteDepth = 0;

  Future<List<TagEntity>> listTags() async {
    final sqlite = await _db.db;
    return TagDbPersistence.listTags(sqlite);
  }

  Future<TagEntity?> getTagByPath(String path) async {
    final sqlite = await _db.db;
    return TagDbPersistence.getTagByPath(sqlite, path);
  }

  bool get _writeProxyEnabled => _writeGateway != null;

  Future<T> _runLocalWrite<T>(Future<T> Function() action) async {
    _localWriteDepth += 1;
    try {
      return await action();
    } finally {
      _localWriteDepth -= 1;
    }
  }

  Future<T> _dispatchWriteCommand<T>({
    required String operation,
    required Map<String, dynamic> payload,
    required T Function(Object? raw) decode,
  }) async {
    final gateway = _writeGateway;
    if (gateway == null) {
      throw StateError('Write gateway is not configured.');
    }
    final result = await gateway.execute<T>(
      workspaceKey: _db.workspaceKey,
      dbName: _db.dbName,
      commandType: tagRepositoryWriteCommandType,
      operation: operation,
      payload: payload,
      localExecute: () =>
          _executeWriteOperationLocally(operation: operation, payload: payload),
      decode: decode,
    );
    if (gateway.isRemote) {
      _db.notifyDataChanged();
    }
    return result;
  }

  Future<Object?> executeWriteEnvelopeLocally(DbWriteEnvelope envelope) async {
    if (envelope.commandType != tagRepositoryWriteCommandType) {
      throw UnsupportedError('Unsupported tag repository command type.');
    }
    final gateway = _writeGateway;
    if (gateway is OwnerDesktopDbWriteGateway) {
      return gateway.executeEnvelope<Object?>(
        envelope: envelope,
        localExecute: () => _executeWriteOperationLocally(
          operation: envelope.operation,
          payload: envelope.payload,
        ),
        decode: (raw) => raw,
      );
    }
    return _executeWriteOperationLocally(
      operation: envelope.operation,
      payload: envelope.payload,
    );
  }

  Future<Object?> _executeWriteOperationLocally({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    switch (operation) {
      case 'createTag':
        return _runLocalWrite(
          () => createTag(
            name: payload['name'] as String? ?? '',
            parentId: _readInt(payload['parentId']),
            pinned: payload['pinned'] == true,
            colorHex: payload['colorHex'] as String?,
          ),
        ).then((value) => value.toJson());
      case 'updateTag':
        final hasParent = payload.containsKey('parentId');
        return _runLocalWrite(
          () => updateTag(
            id: _readInt(payload['id']) ?? 0,
            name: payload['name'] as String?,
            parentId: hasParent ? _readInt(payload['parentId']) : _unsetParent,
            pinned: payload.containsKey('pinned')
                ? payload['pinned'] == true
                : null,
            colorHex: payload['colorHex'] as String?,
          ),
        ).then((value) => value.toJson());
      case 'deleteTag':
        await _runLocalWrite(() => deleteTag(_readInt(payload['id']) ?? 0));
        return null;
      case 'applySnapshot':
        final rawSnapshot = payload['snapshot'];
        if (rawSnapshot is! Map) {
          throw const FormatException('Missing tag snapshot payload.');
        }
        await _runLocalWrite(
          () => applySnapshot(
            TagSnapshot.fromJson(
              Map<Object?, Object?>.from(rawSnapshot).map<String, dynamic>(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          ),
        );
        return null;
      default:
        throw UnsupportedError(
          'Unsupported tag repository operation: $operation',
        );
    }
  }

  Future<TagEntity> createTag({
    required String name,
    int? parentId,
    bool pinned = false,
    String? colorHex,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      final raw = await _dispatchWriteCommand<Map<String, dynamic>>(
        operation: 'createTag',
        payload: <String, dynamic>{
          'name': name,
          'parentId': parentId,
          'pinned': pinned,
          'colorHex': colorHex,
        },
        decode: (raw) => Map<Object?, Object?>.from(
          raw as Map,
        ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value)),
      );
      return TagEntity.fromJson(raw);
    }
    return _writeDao.createTag(
      name: name,
      parentId: parentId,
      pinned: pinned,
      colorHex: colorHex,
    );
  }

  Future<TagEntity> updateTag({
    required int id,
    String? name,
    Object? parentId = _unsetParent,
    bool? pinned,
    String? colorHex,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      final payload = <String, dynamic>{'id': id};
      if (name != null) payload['name'] = name;
      if (parentId != _unsetParent) payload['parentId'] = parentId as int?;
      if (pinned != null) payload['pinned'] = pinned;
      if (colorHex != null) payload['colorHex'] = colorHex;
      final raw = await _dispatchWriteCommand<Map<String, dynamic>>(
        operation: 'updateTag',
        payload: payload,
        decode: (raw) => Map<Object?, Object?>.from(
          raw as Map,
        ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value)),
      );
      return TagEntity.fromJson(raw);
    }
    return _writeDao.updateTag(
      id: id,
      name: name,
      parentId: identical(parentId, _unsetParent)
          ? AppDatabaseWriteDao.noParentChange
          : parentId,
      pinned: pinned,
      colorHex: colorHex,
    );
  }

  Future<void> deleteTag(int id) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteTag',
        payload: <String, dynamic>{'id': id},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteTag(id);
  }

  Future<TagSnapshot> readSnapshot() async {
    final sqlite = await _db.db;
    return TagDbPersistence.readSnapshot(sqlite);
  }

  Future<void> applySnapshot(TagSnapshot snapshot) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'applySnapshot',
        payload: <String, dynamic>{'snapshot': snapshot.toJson()},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.applyTagSnapshot(snapshot);
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
