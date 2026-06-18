import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/debug_ephemeral_storage.dart';
import '../../core/memo_search_document_builder.dart';
import '../../core/tags.dart';
import 'db_write_protocol.dart';
import 'desktop_db_write_gateway.dart';
import 'ai_db_persistence.dart';
import 'app_database_write_dao.dart';
import 'collection_db_persistence.dart';
import 'compose_draft_db_persistence.dart';
import 'memo_auxiliary_db_persistence.dart';
import 'memo_core_db_persistence.dart';
import 'memo_lifecycle_db_persistence.dart';
import 'memo_query_db_persistence.dart';
import 'memo_search_db_persistence.dart';
import 'memo_write_db_persistence.dart';
import 'outbox_db_persistence.dart';
import 'quick_clip_recovery_db_persistence.dart';
import 'rss_db_persistence.dart';
import 'stats_cache_db_persistence.dart';
import 'tag_db_persistence.dart';
import '../models/memo_clip_card_metadata.dart';
import '../models/memo_location.dart';
import '../models/memo_sort_order.dart';
import '../models/quick_clip_recovery_job.dart';

export 'tag_db_persistence.dart' show ResolvedTag;
export 'memo_search_db_persistence.dart' show MemoSearchDbFilters;

class AppDatabase {
  AppDatabase({
    String dbName = 'memos_app.db',
    String? workspaceKey,
    DesktopDbWriteGateway? writeGateway,
    bool enableMemoSearchBackgroundMaintenance = true,
  }) : _dbName = dbName,
       _workspaceKey = workspaceKey ?? dbName,
       _writeGateway = writeGateway,
       _enableMemoSearchBackgroundMaintenance =
           enableMemoSearchBackgroundMaintenance;

  final String _dbName;
  final String _workspaceKey;
  final DesktopDbWriteGateway? _writeGateway;
  final bool _enableMemoSearchBackgroundMaintenance;
  late final AppDatabaseWriteDao _writeDao = AppDatabaseWriteDao(db: this);
  static const Object _displayTimeUnspecified = Object();
  static const _dbVersion = 32;
  static const int outboxStatePending = 0;
  static const int outboxStateRunning = 1;
  static const int outboxStateRetry = 2;
  static const int outboxStateError = 3;
  static const int outboxStateDone = 4;
  static const int outboxStateQuarantined = 5;
  static const String memoDeleteTombstoneStatePendingRemoteDelete =
      'pending_remote_delete';
  static const String memoDeleteTombstoneStateLocalOnly = 'local_only';
  static const int _maintenanceBatchSize = 300;
  static const int maintenanceBatchSize = _maintenanceBatchSize;
  static const int _memoSearchDrainBatchSize = 64;

  Database? _db;
  Future<Database>? _openingDb;
  final _changes = StreamController<void>.broadcast();
  Timer? _memoSearchMaintenanceTimer;
  bool _memoSearchMaintenanceRunning = false;
  int _localWriteDepth = 0;

  Stream<void> get changes => _changes.stream;
  String get dbName => _dbName;
  String get workspaceKey => _workspaceKey;

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
          // Native sqflite backends on Android treat these PRAGMAs as
          // query-style statements, so use rawQuery for cross-platform safety.
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          final busyTimeoutMs = Platform.isWindows ? 10000 : 5000;
          await db.rawQuery('PRAGMA busy_timeout = $busyTimeoutMs;');
        },
        onCreate: (db, _) async {
          await MemoCoreDbPersistence.ensureMemoTable(db);

          await TagDbPersistence.ensureTables(db);

          await MemoAuxiliaryDbPersistence.ensureMemoReminderTable(db);
          await MemoAuxiliaryDbPersistence.ensureMemoClipCardsTable(db);
          await QuickClipRecoveryDbPersistence.ensureTable(db);

          await MemoCoreDbPersistence.ensureAttachmentTable(db);

          await OutboxDbPersistence.ensureTable(db);

          await MemoAuxiliaryDbPersistence.ensureImportHistoryTable(db);

          await MemoLifecycleDbPersistence.ensureTables(db);
          await ComposeDraftDbPersistence.ensureTable(db);

          await CollectionDbPersistence.ensureTables(db);
          await RssDbPersistence.ensureTables(db);
          await AiDbPersistence.ensureTables(db);

          await _ensureStatsPersistenceTables(db, rebuild: true);
          await MemoSearchDbPersistence.ensureFts(db, rebuild: true);
          await MemoSearchDbPersistence.ensureIndex(db, rebuild: true);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            await MemoSearchDbPersistence.recreateFts(db);
          }
          if (oldVersion < 4) {
            await MemoAuxiliaryDbPersistence.ensureImportHistoryTable(db);
          }
          if (oldVersion < 5) {
            await MemoAuxiliaryDbPersistence.ensureMemoReminderTable(db);
          }
          if (oldVersion < 6) {
            await MemoCoreDbPersistence.ensureRelationCountColumn(db);
          }
          if (oldVersion < 7) {
            await MemoCoreDbPersistence.ensureLocationColumns(db);
          }
          if (oldVersion < 8) {
            await _ensureStatsPersistenceTables(db, rebuild: true);
          }
          if (oldVersion < 9) {
            await _normalizeStoredTags(db);
            await _ensureStatsPersistenceTables(db, rebuild: true);
          }
          if (oldVersion < 10) {
            await MemoLifecycleDbPersistence.ensureMemoRelationsCacheTable(db);
          }
          if (oldVersion < 11) {
            await MemoLifecycleDbPersistence.ensureMemoVersionsTable(db);
            await MemoLifecycleDbPersistence.ensureRecycleBinTable(db);
          }
          if (oldVersion < 12) {
            await OutboxDbPersistence.ensureRetryColumnAndNormalizeLegacyStates(
              db,
            );
          }
          if (oldVersion < 13) {
            await TagDbPersistence.ensureTables(db);
            await _normalizeStoredTags(db);
            await _backfillTagsFromMemos(db);
            await _ensureStatsPersistenceTables(db, rebuild: true);
          }
          if (oldVersion < 14) {
            await AiDbPersistence.ensureTables(db);
          }
          if (oldVersion < 15) {
            await AiDbPersistence.ensureAnalysisTaskIncludePublicColumn(db);
          }
          if (oldVersion < 16) {
            await MemoLifecycleDbPersistence.ensureMemoDeleteTombstoneTable(db);
          }
          if (oldVersion < 17) {
            await MemoLifecycleDbPersistence.ensureMemoInlineImageSourceTable(
              db,
            );
          }
          if (oldVersion < 18) {
            await ComposeDraftDbPersistence.ensureTable(db);
          }
          if (oldVersion < 19) {
            await OutboxDbPersistence.ensureFailureMetadataColumns(db);
            await OutboxDbPersistence.migrateLegacyErrorChains(db);
          }
          if (oldVersion < 20) {
            await MemoCoreDbPersistence.ensureDisplayTimeColumnAndBackfill(db);
          }
          if (oldVersion < 21) {
            await CollectionDbPersistence.ensureCollectionTables(db);
          }
          if (oldVersion < 22) {
            await CollectionDbPersistence.ensureCollectionTables(db);
          }
          if (oldVersion < 23) {
            await CollectionDbPersistence.ensureReaderProgressTable(db);
          }
          if (oldVersion < 24) {
            await CollectionDbPersistence.ensureReaderProgressTable(db);
            await CollectionDbPersistence.ensureReaderProgressPageColumns(db);
          }
          if (oldVersion < 25) {
            await MemoAuxiliaryDbPersistence.ensureMemoClipCardsTable(db);
          }
          if (oldVersion < 26) {
            await AiDbPersistence.ensureTables(db);
            await AiDbPersistence.ensureAnalysisTaskTemplateColumns(db);
          }
          if (oldVersion < 27) {
            await MemoSearchDbPersistence.ensureIndex(db, rebuild: true);
          }
          if (oldVersion < 28) {
            await ComposeDraftDbPersistence.ensureEditDraftColumns(db);
          }
          if (oldVersion < 29) {
            await QuickClipRecoveryDbPersistence.ensureTable(db);
          }
          if (oldVersion < 30) {
            await RssDbPersistence.ensureTables(db);
          }
          if (oldVersion < 31) {
            await RssDbPersistence.ensureTables(db);
          }
          if (oldVersion < 32) {
            await CollectionDbPersistence.ensureArticleFlowProgressTable(db);
          }
        },
        onOpen: (db) async {
          await MemoAuxiliaryDbPersistence.ensureMemoClipCardsTable(db);
          await QuickClipRecoveryDbPersistence.ensureTable(db);
          await CollectionDbPersistence.ensureArticleFlowProgressTable(db);
          await RssDbPersistence.ensureTables(db);
          await _ensureStatsPersistenceTables(db);
          await MemoSearchDbPersistence.ensureFts(db);
          await MemoSearchDbPersistence.ensureIndex(db);
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
    final opening = _openingDb;
    if (opening != null) return opening;

    final future = _open().then((opened) {
      _db = opened;
      return opened;
    });
    _openingDb = future;
    future.whenComplete(() {
      if (identical(_openingDb, future)) {
        _openingDb = null;
      }
    });
    return future;
  }

  Future<void> close() async {
    _memoSearchMaintenanceTimer?.cancel();
    _memoSearchMaintenanceTimer = null;
    final existing = _db;
    if (existing != null) {
      await existing.close();
    } else {
      final opening = _openingDb;
      if (opening != null) {
        try {
          final opened = await opening;
          await opened.close();
        } catch (_) {}
      }
    }
    _db = null;
    _openingDb = null;
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
    bool notifyChangedAfterRemote = true,
  }) async {
    final gateway = _writeGateway;
    if (gateway == null) {
      throw StateError('Write gateway is not configured.');
    }
    final result = await gateway.execute<T>(
      workspaceKey: _workspaceKey,
      dbName: _dbName,
      commandType: appDatabaseWriteCommandType,
      operation: operation,
      payload: payload,
      localExecute: () =>
          _executeWriteOperationLocally(operation: operation, payload: payload),
      decode: decode,
    );
    if (gateway.isRemote && notifyChangedAfterRemote) {
      _notifyChanged();
    }
    return result;
  }

  Future<Object?> executeWriteEnvelopeLocally(DbWriteEnvelope envelope) async {
    if (envelope.commandType != appDatabaseWriteCommandType) {
      throw UnsupportedError('Unsupported app database command type.');
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
      case 'upsertMemo':
        await _runLocalWrite(
          () => upsertMemo(
            uid: _requiredString(payload, 'uid'),
            content: payload['content'] as String? ?? '',
            visibility: payload['visibility'] as String? ?? 'PRIVATE',
            pinned: _readBoolPayload(payload, 'pinned'),
            state: payload['state'] as String? ?? 'NORMAL',
            createTimeSec: _requiredInt(payload, 'createTimeSec'),
            displayTimeSec: payload['preserveDisplayTime'] == true
                ? _displayTimeUnspecified
                : payload['displayTimeSec'],
            updateTimeSec: _requiredInt(payload, 'updateTimeSec'),
            tags: _readStringListPayload(payload, 'tags'),
            attachments: _readMapListPayload(payload, 'attachments'),
            location: _readMemoLocationPayload(payload, 'location'),
            relationCount: _optionalInt(payload, 'relationCount') ?? 0,
            syncState: _requiredInt(payload, 'syncState'),
            lastError: payload['lastError'] as String?,
          ),
        );
        return null;
      case 'updateMemoSyncState':
        await _runLocalWrite(
          () => updateMemoSyncState(
            _requiredString(payload, 'uid'),
            syncState: _requiredInt(payload, 'syncState'),
            lastError: payload['lastError'] as String?,
          ),
        );
        return null;
      case 'updateMemoAttachmentsJson':
        await _runLocalWrite(
          () => updateMemoAttachmentsJson(
            _requiredString(payload, 'uid'),
            attachmentsJson: payload['attachmentsJson'] as String? ?? '[]',
          ),
        );
        return null;
      case 'removePendingAttachmentPlaceholder':
        await _runLocalWrite(
          () => removePendingAttachmentPlaceholder(
            memoUid: _requiredString(payload, 'memoUid'),
            attachmentUid: _requiredString(payload, 'attachmentUid'),
          ),
        );
        return null;
      case 'upsertMemoRelationsCache':
        await _runLocalWrite(
          () => upsertMemoRelationsCache(
            _requiredString(payload, 'memoUid'),
            relationsJson: payload['relationsJson'] as String? ?? '{}',
          ),
        );
        return null;
      case 'deleteMemoRelationsCache':
        await _runLocalWrite(
          () => deleteMemoRelationsCache(_requiredString(payload, 'memoUid')),
        );
        return null;
      case 'insertMemoVersion':
        return _runLocalWrite(
          () => insertMemoVersion(
            memoUid: _requiredString(payload, 'memoUid'),
            snapshotTime: _requiredInt(payload, 'snapshotTime'),
            summary: payload['summary'] as String? ?? '',
            payloadJson: payload['payloadJson'] as String? ?? '{}',
          ),
        );
      case 'deleteMemoVersionById':
        await _runLocalWrite(
          () => deleteMemoVersionById(_requiredInt(payload, 'id')),
        );
        return null;
      case 'deleteMemoVersionsByMemoUid':
        await _runLocalWrite(
          () =>
              deleteMemoVersionsByMemoUid(_requiredString(payload, 'memoUid')),
        );
        return null;
      case 'insertRecycleBinItem':
        return _runLocalWrite(
          () => insertRecycleBinItem(
            itemType: payload['itemType'] as String? ?? '',
            memoUid: _requiredString(payload, 'memoUid'),
            summary: payload['summary'] as String? ?? '',
            payloadJson: payload['payloadJson'] as String? ?? '{}',
            deletedTime: _requiredInt(payload, 'deletedTime'),
            expireTime: _requiredInt(payload, 'expireTime'),
          ),
        );
      case 'upsertMemoDeleteTombstone':
        await _runLocalWrite(
          () => upsertMemoDeleteTombstone(
            memoUid: _requiredString(payload, 'memoUid'),
            state:
                payload['state'] as String? ??
                memoDeleteTombstoneStateLocalOnly,
            lastError: payload['lastError'] as String?,
            deletedTime: _optionalInt(payload, 'deletedTime'),
          ),
        );
        return null;
      case 'upsertMemoInlineImageSource':
        await _runLocalWrite(
          () => upsertMemoInlineImageSource(
            memoUid: _requiredString(payload, 'memoUid'),
            localUrl: payload['localUrl'] as String? ?? '',
            sourceUrl: payload['sourceUrl'] as String? ?? '',
          ),
        );
        return null;
      case 'deleteMemoInlineImageSources':
        await _runLocalWrite(
          () =>
              deleteMemoInlineImageSources(_requiredString(payload, 'memoUid')),
        );
        return null;
      case 'rebuildMemoTagsFromContent':
        await _runLocalWrite(
          () => rebuildMemoTagsFromContent(
            policy: TagRecognitionPolicy.fromStorage(
              payload['tagRecognitionPolicy'],
            ),
          ),
        );
        return null;
      case 'pruneOrphanTags':
        return _runLocalWrite(pruneOrphanTags);
      case 'rebuildMemoSearchIndex':
        await _runLocalWrite(rebuildMemoSearchIndex);
        return null;
      case 'drainMemoSearchDirtyEntries':
        return _runLocalWrite(
          () => drainMemoSearchDirtyEntries(
            limit: _optionalInt(payload, 'limit') ?? _memoSearchDrainBatchSize,
          ),
        );
      case 'deleteMemoDeleteTombstone':
        await _runLocalWrite(
          () => deleteMemoDeleteTombstone(_requiredString(payload, 'memoUid')),
        );
        return null;
      case 'replaceMemoFromLocalLibrary':
        await _runLocalWrite(
          () => replaceMemoFromLocalLibrary(
            uid: _requiredString(payload, 'uid'),
            content: payload['content'] as String? ?? '',
            visibility: payload['visibility'] as String? ?? 'PRIVATE',
            pinned: _readBoolPayload(payload, 'pinned'),
            state: payload['state'] as String? ?? 'NORMAL',
            createTimeSec: _requiredInt(payload, 'createTimeSec'),
            displayTimeSec: payload['displayTimeSec'],
            displayTimeSpecified:
                payload['displayTimeSpecified'] == null ||
                payload['displayTimeSpecified'] == true,
            updateTimeSec: _requiredInt(payload, 'updateTimeSec'),
            tags: _readStringListPayload(payload, 'tags'),
            attachments: _readMapListPayload(payload, 'attachments'),
            location: _readMemoLocationPayload(payload, 'location'),
            relationCount: _optionalInt(payload, 'relationCount') ?? 0,
            syncState: _requiredInt(payload, 'syncState'),
            lastError: payload['lastError'] as String?,
            clearOutbox: _readBoolPayload(payload, 'clearOutbox'),
            relationsMode: payload['relationsMode'] as String? ?? 'none',
            relationsJson: payload['relationsJson'] as String?,
          ),
        );
        return null;
      case 'deleteMemoFromLocalLibrary':
        await _runLocalWrite(
          () => deleteMemoFromLocalLibrary(
            memoUid: _requiredString(payload, 'memoUid'),
          ),
        );
        return null;
      case 'deleteMemoAfterRecycleBinMove':
        await _runLocalWrite(
          () => deleteMemoAfterRecycleBinMove(
            memoUid: _requiredString(payload, 'memoUid'),
            draftAttachmentNames: _readStringListPayload(
              payload,
              'draftAttachmentNames',
            ),
          ),
        );
        return null;
      case 'renameMemoUidAndRewriteOutboxMemoUids':
        return _runLocalWrite(
          () => renameMemoUidAndRewriteOutboxMemoUids(
            oldUid: _requiredString(payload, 'oldUid'),
            newUid: _requiredString(payload, 'newUid'),
          ),
        );
      case 'deleteRecycleBinItemById':
        await _runLocalWrite(
          () => deleteRecycleBinItemById(_requiredInt(payload, 'id')),
        );
        return null;
      case 'clearRecycleBinItems':
        await _runLocalWrite(clearRecycleBinItems);
        return null;
      case 'renameMemoUid':
        await _runLocalWrite(
          () => renameMemoUid(
            oldUid: _requiredString(payload, 'oldUid'),
            newUid: _requiredString(payload, 'newUid'),
          ),
        );
        return null;
      case 'rewriteOutboxMemoUids':
        return _runLocalWrite(
          () => rewriteOutboxMemoUids(
            oldUid: _requiredString(payload, 'oldUid'),
            newUid: _requiredString(payload, 'newUid'),
          ),
        );
      case 'enqueueOutbox':
        return _runLocalWrite(
          () => enqueueOutbox(
            type: payload['type'] as String? ?? '',
            payload: _readObjectMapPayload(
              payload,
              'payload',
            ).cast<String, dynamic>(),
          ),
        );
      case 'enqueueOutboxBatch':
        return _runLocalWrite(
          () => enqueueOutboxBatch(
            items: _readObjectMapListPayload(payload, 'items'),
          ),
        );
      case 'claimNextOutboxRunnable':
        return _runLocalWrite(
          () => claimNextOutboxRunnable(nowMs: _optionalInt(payload, 'nowMs')),
        );
      case 'claimOutboxTaskById':
        return _runLocalWrite(
          () => claimOutboxTaskById(
            _requiredInt(payload, 'id'),
            nowMs: _optionalInt(payload, 'nowMs'),
          ),
        );
      case 'recoverOutboxRunningTasks':
        return _runLocalWrite(recoverOutboxRunningTasks);
      case 'markOutboxDone':
        await _runLocalWrite(() => markOutboxDone(_requiredInt(payload, 'id')));
        return null;
      case 'completeOutboxTask':
        await _runLocalWrite(
          () => completeOutboxTask(_requiredInt(payload, 'id')),
        );
        return null;
      case 'markOutboxError':
        await _runLocalWrite(
          () => markOutboxError(
            _requiredInt(payload, 'id'),
            error: payload['error'] as String? ?? '',
          ),
        );
        return null;
      case 'markOutboxRetryScheduled':
        await _runLocalWrite(
          () => markOutboxRetryScheduled(
            _requiredInt(payload, 'id'),
            error: payload['error'] as String? ?? '',
            retryAtMs: _requiredInt(payload, 'retryAtMs'),
          ),
        );
        return null;
      case 'markOutboxQuarantined':
        await _runLocalWrite(
          () => markOutboxQuarantined(
            _requiredInt(payload, 'id'),
            error: payload['error'] as String? ?? '',
            failureCode: payload['failureCode'] as String? ?? '',
            failureKind: payload['failureKind'] as String? ?? '',
            incrementAttempts:
                payload['incrementAttempts'] == null ||
                payload['incrementAttempts'] == true,
          ),
        );
        return null;
      case 'markOutboxRetryPending':
        await _runLocalWrite(
          () => markOutboxRetryPending(
            _requiredInt(payload, 'id'),
            error: payload['error'] as String? ?? '',
          ),
        );
        return null;
      case 'retryOutboxErrors':
        return _runLocalWrite(
          () => retryOutboxErrors(memoUid: payload['memoUid'] as String?),
        );
      case 'retryOutboxItem':
        await _runLocalWrite(
          () => retryOutboxItem(_requiredInt(payload, 'id')),
        );
        return null;
      case 'deleteOutbox':
        await _runLocalWrite(() => deleteOutbox(_requiredInt(payload, 'id')));
        return null;
      case 'deleteOutboxItems':
        return _runLocalWrite(
          () => deleteOutboxItems(_readIntListPayload(payload, 'ids')),
        );
      case 'discardMissingSourceUploadTask':
        await _runLocalWrite(
          () => discardMissingSourceUploadTask(
            outboxId: _requiredInt(payload, 'outboxId'),
            memoUid: payload['memoUid'] as String? ?? '',
            attachmentUid: payload['attachmentUid'] as String? ?? '',
          ),
        );
        return null;
      case 'deleteOutboxForMemo':
        await _runLocalWrite(
          () => deleteOutboxForMemo(_requiredString(payload, 'memoUid')),
        );
        return null;
      case 'updatePendingCreateMemoContent':
        return _runLocalWrite(
          () => updatePendingCreateMemoContent(
            memoUid: _requiredString(payload, 'memoUid'),
            content: _requiredString(payload, 'content'),
            visibility: payload['visibility'] as String?,
          ),
        );
      case 'clearOutbox':
        await _runLocalWrite(clearOutbox);
        return null;
      case 'upsertImportHistory':
        return _runLocalWrite(
          () => upsertImportHistory(
            source: payload['source'] as String? ?? '',
            fileMd5: payload['fileMd5'] as String? ?? '',
            fileName: payload['fileName'] as String? ?? '',
            status: _requiredInt(payload, 'status'),
            memoCount: _requiredInt(payload, 'memoCount'),
            attachmentCount: _requiredInt(payload, 'attachmentCount'),
            failedCount: _requiredInt(payload, 'failedCount'),
            error: payload['error'] as String?,
          ),
        );
      case 'updateImportHistory':
        await _runLocalWrite(
          () => updateImportHistory(
            id: _requiredInt(payload, 'id'),
            status: _requiredInt(payload, 'status'),
            memoCount: _requiredInt(payload, 'memoCount'),
            attachmentCount: _requiredInt(payload, 'attachmentCount'),
            failedCount: _requiredInt(payload, 'failedCount'),
            error: payload['error'] as String?,
          ),
        );
        return null;
      case 'deleteMemoByUid':
        await _runLocalWrite(
          () => deleteMemoByUid(_requiredString(payload, 'uid')),
        );
        return null;
      case 'upsertMemoClipCard':
        await _runLocalWrite(
          () => upsertMemoClipCard(
            MemoClipCardMetadata.fromDb(
              _readObjectMapPayload(
                payload,
                'row',
              ).map<String, dynamic>((key, value) => MapEntry(key, value)),
            ),
          ),
        );
        return null;
      case 'deleteMemoClipCard':
        await _runLocalWrite(
          () => deleteMemoClipCard(_requiredString(payload, 'memoUid')),
        );
        return null;
      case 'upsertQuickClipRecoveryJob':
        await _runLocalWrite(
          () => upsertQuickClipRecoveryJob(
            QuickClipRecoveryJob.fromDb(
              _readObjectMapPayload(
                payload,
                'row',
              ).map<String, dynamic>((key, value) => MapEntry(key, value)),
            ),
          ),
        );
        return null;
      case 'markQuickClipRecoveryJobRunning':
        return _runLocalWrite(
          () => markQuickClipRecoveryJobRunning(
            memoUid: _requiredString(payload, 'memoUid'),
            now: _readDateTimePayload(payload, 'nowMs'),
            lastError: payload['lastError'] as String?,
          ),
        );
      case 'markQuickClipRecoveryJobCompleted':
        return _runLocalWrite(
          () => markQuickClipRecoveryJobCompleted(
            memoUid: _requiredString(payload, 'memoUid'),
            now: _readDateTimePayload(payload, 'nowMs'),
          ),
        );
      case 'markQuickClipRecoveryJobAbandoned':
        return _runLocalWrite(
          () => markQuickClipRecoveryJobAbandoned(
            memoUid: _requiredString(payload, 'memoUid'),
            now: _readDateTimePayload(payload, 'nowMs'),
            lastError: payload['lastError'] as String?,
          ),
        );
      case 'markQuickClipRecoveryJobFailed':
        return _runLocalWrite(
          () => markQuickClipRecoveryJobFailed(
            memoUid: _requiredString(payload, 'memoUid'),
            now: _readDateTimePayload(payload, 'nowMs'),
            lastError: payload['lastError'] as String?,
          ),
        );
      case 'deleteTerminalQuickClipRecoveryJobs':
        return _runLocalWrite(
          () => deleteTerminalQuickClipRecoveryJobs(
            completedBefore: _readDateTimePayload(payload, 'completedBeforeMs'),
            limit: _optionalInt(payload, 'limit') ?? 100,
          ),
        );
      case 'upsertMemoReminder':
        await _runLocalWrite(
          () => upsertMemoReminder(
            memoUid: _requiredString(payload, 'memoUid'),
            mode: payload['mode'] as String? ?? '',
            timesJson: payload['timesJson'] as String? ?? '[]',
          ),
        );
        return null;
      case 'deleteMemoReminder':
        await _runLocalWrite(
          () => deleteMemoReminder(_requiredString(payload, 'memoUid')),
        );
        return null;
      case 'upsertComposeDraftRow':
        await _runLocalWrite(
          () => upsertComposeDraftRow(_readObjectMapPayload(payload, 'row')),
        );
        return null;
      case 'replaceComposeDraftRows':
        await _runLocalWrite(
          () => replaceComposeDraftRows(
            workspaceKey: _requiredString(payload, 'workspaceKey'),
            rows: _readObjectMapListPayload(payload, 'rows'),
          ),
        );
        return null;
      case 'deleteComposeDraft':
        await _runLocalWrite(
          () => deleteComposeDraft(_requiredString(payload, 'uid')),
        );
        return null;
      case 'deleteComposeDraftsByWorkspace':
        await _runLocalWrite(
          () => deleteComposeDraftsByWorkspace(
            _requiredString(payload, 'workspaceKey'),
          ),
        );
        return null;
      case 'upsertCollectionReaderProgressRow':
        await _runLocalWrite(
          () => upsertCollectionReaderProgressRow(
            _readObjectMapPayload(payload, 'row'),
          ),
        );
        return null;
      case 'deleteCollectionReaderProgress':
        await _runLocalWrite(
          () => deleteCollectionReaderProgress(
            _requiredString(payload, 'collectionId'),
          ),
        );
        return null;
      case 'upsertCollectionArticleFlowProgressRow':
        await _runLocalWrite(
          () => upsertCollectionArticleFlowProgressRow(
            _readObjectMapPayload(payload, 'row'),
          ),
        );
        return null;
      case 'deleteCollectionArticleFlowProgress':
        await _runLocalWrite(
          () => deleteCollectionArticleFlowProgress(
            _requiredString(payload, 'collectionId'),
          ),
        );
        return null;
      case 'rebuildStatsCache':
        await _runLocalWrite(rebuildStatsCache);
        return null;
      default:
        throw UnsupportedError(
          'Unsupported AppDatabase write operation: $operation',
        );
    }
  }

  static int _requiredInt(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw StateError('Missing integer payload: $key');
  }

  static int? _optionalInt(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static DateTime _readDateTimePayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    final ms = _optionalInt(payload, key);
    if (ms == null || ms <= 0) {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  static String _requiredString(Map<String, dynamic> payload, String key) {
    final value = (payload[key] as String? ?? '').trim();
    if (value.isEmpty) {
      throw StateError('Missing string payload: $key');
    }
    return value;
  }

  static bool _readBoolPayload(Map<String, dynamic> payload, String key) {
    return payload[key] == true;
  }

  static List<String> _readStringListPayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! List) return const <String>[];
    return value
        .map((item) => (item as String? ?? '').trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<int> _readIntListPayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! List) return const <int>[];
    return value
        .map((item) {
          if (item is int) return item;
          if (item is num) return item.toInt();
          return null;
        })
        .whereType<int>()
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _readMapListPayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(
          (item) => Map<Object?, Object?>.from(item).map<String, dynamic>(
            (mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, Object?> _readObjectMapPayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! Map) return const <String, Object?>{};
    return Map<Object?, Object?>.from(value).map<String, Object?>(
      (mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue),
    );
  }

  static List<Map<String, Object?>> _readObjectMapListPayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! List) return const <Map<String, Object?>>[];
    return value
        .whereType<Map>()
        .map(
          (item) => Map<Object?, Object?>.from(item).map<String, Object?>(
            (mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue),
          ),
        )
        .toList(growable: false);
  }

  static MemoLocation? _readMemoLocationPayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! Map) return null;
    return MemoLocation.fromJson(
      Map<Object?, Object?>.from(value).map<String, dynamic>(
        (mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue),
      ),
    );
  }

  static int _decodeIntResult(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static Map<String, dynamic>? _decodeMapResult(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<Object?, Object?>.from(
        raw,
      ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  void _notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  void notifyDataChanged() {
    _notifyChanged();
    _scheduleMemoSearchMaintenance();
  }

  void _scheduleMemoSearchMaintenance({
    Duration delay = const Duration(milliseconds: 80),
  }) {
    if (!_enableMemoSearchBackgroundMaintenance ||
        _changes.isClosed ||
        _memoSearchMaintenanceTimer != null ||
        _memoSearchMaintenanceRunning) {
      return;
    }
    _memoSearchMaintenanceTimer = Timer(delay, () {
      _memoSearchMaintenanceTimer = null;
      unawaited(_runScheduledMemoSearchMaintenance());
    });
  }

  Future<void> _runScheduledMemoSearchMaintenance() async {
    if (_changes.isClosed || _memoSearchMaintenanceRunning) return;
    _memoSearchMaintenanceRunning = true;
    var hasMore = false;
    try {
      final processed = await drainMemoSearchDirtyEntries(
        limit: _memoSearchDrainBatchSize,
      );
      if (processed > 0 && !_changes.isClosed) {
        final sqlite = await db;
        hasMore = await MemoSearchDbPersistence.hasDirtyEntries(sqlite);
      }
    } catch (_) {
      hasMore = false;
    } finally {
      _memoSearchMaintenanceRunning = false;
    }
    if (hasMore && !_changes.isClosed) {
      _scheduleMemoSearchMaintenance(delay: const Duration(milliseconds: 20));
    }
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
      final rows = await MemoQueryDbPersistence.listMemoTagNormalizationRows(
        db,
        afterId: lastId,
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
        await AppDatabaseWriteDao.runTransaction<void>(db, (txn) async {
          for (final update in updates) {
            await MemoWriteDbPersistence.updateMemoTagsTextById(
              txn,
              update.id,
              tagsText: update.tags,
            );
          }
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  static List<String> _splitTagsText(String tagsText) {
    return MemoSearchDocumentBuilder.splitTagsText(tagsText);
  }

  bool isDisplayTimeUnspecified(Object? value) {
    return identical(value, _displayTimeUnspecified);
  }

  int? normalizeDisplayTimeSec(Object? displayTimeSec) {
    return switch (displayTimeSec) {
      int value => value,
      num value => value.toInt(),
      null || _displayTimeUnspecified => null,
      _ => throw ArgumentError.value(
        displayTimeSec,
        'displayTimeSec',
        'must be an int, num, null, or omitted',
      ),
    };
  }

  static Future<void> _ensureStatsPersistenceTables(
    Database db, {
    bool rebuild = false,
  }) {
    return StatsCacheDbPersistence.ensureTables(
      db,
      runTransaction: AppDatabaseWriteDao.runTransaction,
      maintenanceBatchSize: _maintenanceBatchSize,
      rebuild: rebuild,
    );
  }

  Future<ResolvedTag?> resolveTagPath(DatabaseExecutor txn, String rawTag) {
    return TagDbPersistence.resolvePath(txn, rawTag);
  }

  Future<void> updateMemoTagsMapping(
    DatabaseExecutor txn,
    String memoUid,
    List<int> tagIds,
  ) async {
    await TagDbPersistence.updateMemoTagsMapping(txn, memoUid, tagIds);
  }

  Future<List<String>> listMemoUidsByTagId(
    DatabaseExecutor txn,
    int tagId,
  ) async {
    return TagDbPersistence.listMemoUidsByTagId(txn, tagId);
  }

  Future<List<String>> listMemoUidsByTagIds(
    DatabaseExecutor txn,
    List<int> tagIds,
  ) async {
    return TagDbPersistence.listMemoUidsByTagIds(txn, tagIds);
  }

  Future<List<String>> listTagPathsForMemo(
    DatabaseExecutor txn,
    String memoUid,
  ) async {
    return TagDbPersistence.listTagPathsForMemo(txn, memoUid);
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
    final before = await StatsCacheDbPersistence.fetchMemoSnapshot(
      txn,
      normalizedUid,
    );
    if (before == null) return;
    await MemoWriteDbPersistence.updateMemoTagsTextByUid(
      txn,
      normalizedUid,
      tagsText: tagsText,
    );
    final rowId =
        await MemoQueryDbPersistence.getMemoIdByUid(txn, normalizedUid) ?? 0;
    if (rowId > 0) {
      await MemoSearchDbPersistence.refreshFtsEntryForMemo(
        txn,
        rowId: rowId,
        memoUid: normalizedUid,
        content: before.content,
        tags: tagsText,
      );
      await MemoSearchDbPersistence.markDirty(
        txn,
        rowId: rowId,
        memoUid: normalizedUid,
      );
    }
    final after = StatsCacheMemoSnapshot(
      state: before.state,
      createTimeSec: before.createTimeSec,
      content: before.content,
      tags: deduped,
    );
    await StatsCacheDbPersistence.applyMemoCacheDelta(
      txn,
      before: before,
      after: after,
    );
  }

  Future<Map<String, dynamic>?> loadMemoSnapshotPayload(
    DatabaseExecutor txn,
    String uid,
  ) async {
    return StatsCacheDbPersistence.memoSnapshotToPayload(
      await StatsCacheDbPersistence.fetchMemoSnapshot(txn, uid),
    );
  }

  Map<String, dynamic> createMemoSnapshotPayload({
    required String state,
    required int createTimeSec,
    required String content,
    required List<String> tags,
  }) {
    return StatsCacheDbPersistence.createMemoSnapshotPayload(
      state: state,
      createTimeSec: createTimeSec,
      content: content,
      tags: tags,
    );
  }

  Future<void> applyMemoCacheDeltaPayload(
    DatabaseExecutor txn, {
    required Map<String, dynamic>? before,
    required Map<String, dynamic>? after,
  }) async {
    await StatsCacheDbPersistence.applyMemoCacheDelta(
      txn,
      before: StatsCacheDbPersistence.memoSnapshotFromPayload(before),
      after: StatsCacheDbPersistence.memoSnapshotFromPayload(after),
    );
  }

  Future<Map<String, dynamic>?> getStatsCacheRow() async {
    final sqlite = await db;
    return StatsCacheDbPersistence.getStatsCacheRow(sqlite);
  }

  Future<List<Map<String, dynamic>>> listDailyCountRows() async {
    final sqlite = await db;
    return StatsCacheDbPersistence.listDailyCountRows(sqlite);
  }

  Future<List<Map<String, dynamic>>> listTagStatsRows() async {
    final sqlite = await db;
    return StatsCacheDbPersistence.listTagStatsRows(sqlite);
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<void> upsertMemo({
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    Object? displayTimeSec = _displayTimeUnspecified,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertMemo',
        payload: <String, dynamic>{
          'uid': uid,
          'content': content,
          'visibility': visibility,
          'pinned': pinned,
          'state': state,
          'createTimeSec': createTimeSec,
          'displayTimeSec': identical(displayTimeSec, _displayTimeUnspecified)
              ? null
              : displayTimeSec,
          'preserveDisplayTime': identical(
            displayTimeSec,
            _displayTimeUnspecified,
          ),
          'updateTimeSec': updateTimeSec,
          'tags': tags,
          'attachments': attachments,
          'location': location?.toJson(),
          'relationCount': relationCount,
          'syncState': syncState,
          'lastError': lastError,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTimeSec: createTimeSec,
      displayTimeSec: displayTimeSec,
      updateTimeSec: updateTimeSec,
      tags: tags,
      attachments: attachments,
      location: location,
      relationCount: relationCount,
      syncState: syncState,
      lastError: lastError,
    );
  }

  Future<void> updateMemoSyncState(
    String uid, {
    required int syncState,
    String? lastError,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'updateMemoSyncState',
        payload: <String, dynamic>{
          'uid': uid,
          'syncState': syncState,
          'lastError': lastError,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.updateMemoSyncState(
      uid,
      syncState: syncState,
      lastError: lastError,
    );
  }

  Future<void> updateMemoAttachmentsJson(
    String uid, {
    required String attachmentsJson,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'updateMemoAttachmentsJson',
        payload: <String, dynamic>{
          'uid': uid,
          'attachmentsJson': attachmentsJson,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.updateMemoAttachmentsJson(
      uid,
      attachmentsJson: attachmentsJson,
    );
  }

  Future<void> removePendingAttachmentPlaceholder({
    required String memoUid,
    required String attachmentUid,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'removePendingAttachmentPlaceholder',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'attachmentUid': attachmentUid,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.removePendingAttachmentPlaceholder(
      memoUid: memoUid,
      attachmentUid: attachmentUid,
    );
  }

  Future<String?> getMemoRelationsCacheJson(String memoUid) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.getMemoRelationsCacheJson(db, memoUid);
  }

  Future<void> upsertMemoRelationsCache(
    String memoUid, {
    required String relationsJson,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertMemoRelationsCache',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'relationsJson': relationsJson,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertMemoRelationsCache(
      memoUid,
      relationsJson: relationsJson,
    );
  }

  Future<void> deleteMemoRelationsCache(String memoUid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoRelationsCache',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoRelationsCache(memoUid);
  }

  Future<int> insertMemoVersion({
    required String memoUid,
    required int snapshotTime,
    required String summary,
    required String payloadJson,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'insertMemoVersion',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'snapshotTime': snapshotTime,
          'summary': summary,
          'payloadJson': payloadJson,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.insertMemoVersion(
      memoUid: memoUid,
      snapshotTime: snapshotTime,
      summary: summary,
      payloadJson: payloadJson,
    );
  }

  Future<List<Map<String, dynamic>>> listMemoVersionsByUid(
    String memoUid, {
    int? limit,
  }) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.listMemoVersionsByUid(
      db,
      memoUid,
      limit: limit,
    );
  }

  Future<List<int>> listMemoVersionIdsExceedLimit(
    String memoUid, {
    required int keep,
  }) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.listMemoVersionIdsExceedLimit(
      db,
      memoUid,
      keep: keep,
    );
  }

  Future<Map<String, dynamic>?> getMemoVersionById(int id) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.getMemoVersionById(db, id);
  }

  Future<void> deleteMemoVersionById(int id) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoVersionById',
        payload: <String, dynamic>{'id': id},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoVersionById(id);
  }

  Future<void> deleteMemoVersionsByMemoUid(String memoUid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoVersionsByMemoUid',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoVersionsByMemoUid(memoUid);
  }

  Future<int> insertRecycleBinItem({
    required String itemType,
    required String memoUid,
    required String summary,
    required String payloadJson,
    required int deletedTime,
    required int expireTime,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'insertRecycleBinItem',
        payload: <String, dynamic>{
          'itemType': itemType,
          'memoUid': memoUid,
          'summary': summary,
          'payloadJson': payloadJson,
          'deletedTime': deletedTime,
          'expireTime': expireTime,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.insertRecycleBinItem(
      itemType: itemType,
      memoUid: memoUid,
      summary: summary,
      payloadJson: payloadJson,
      deletedTime: deletedTime,
      expireTime: expireTime,
    );
  }

  Future<Set<String>> listRecycleBinMemoUids() async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.listRecycleBinMemoUids(db);
  }

  Future<bool> hasRecycleBinMemoItem(String memoUid) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.hasRecycleBinMemoItem(db, memoUid);
  }

  Future<void> upsertMemoDeleteTombstone({
    required String memoUid,
    required String state,
    String? lastError,
    int? deletedTime,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertMemoDeleteTombstone',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'state': state,
          'lastError': lastError,
          'deletedTime': deletedTime,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertMemoDeleteTombstone(
      memoUid: memoUid,
      state: state,
      lastError: lastError,
      deletedTime: deletedTime,
    );
  }

  Future<Map<String, dynamic>?> getMemoDeleteTombstone(String memoUid) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.getMemoDeleteTombstone(db, memoUid);
  }

  Future<String?> getMemoDeleteTombstoneState(String memoUid) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.getMemoDeleteTombstoneState(db, memoUid);
  }

  Future<Set<String>> listMemoDeleteTombstoneUids() async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.listMemoDeleteTombstoneUids(db);
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
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertMemoInlineImageSource',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'localUrl': localUrl,
          'sourceUrl': sourceUrl,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertMemoInlineImageSource(
      memoUid: memoUid,
      localUrl: localUrl,
      sourceUrl: sourceUrl,
    );
  }

  Future<Map<String, String>> listMemoInlineImageSources(String memoUid) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.listMemoInlineImageSources(db, memoUid);
  }

  Future<void> deleteMemoInlineImageSources(String memoUid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoInlineImageSources',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoInlineImageSources(memoUid);
  }

  Future<void> rebuildMemoTagsFromContent({
    TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'rebuildMemoTagsFromContent',
        payload: <String, dynamic>{'tagRecognitionPolicy': policy.toJson()},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.rebuildMemoTagsFromContent(policy: policy);
  }

  Future<int> pruneOrphanTags() async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'pruneOrphanTags',
        payload: const <String, dynamic>{},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.pruneOrphanTags();
  }

  Future<void> rebuildMemoSearchIndex() async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'rebuildMemoSearchIndex',
        payload: const <String, dynamic>{},
        decode: (_) {},
      );
      return;
    }
    final db = await this.db;
    await MemoSearchDbPersistence.ensureFts(db, rebuild: true);
    await MemoSearchDbPersistence.ensureIndex(db, rebuild: true);
    while (true) {
      await MemoSearchDbPersistence.drainDirtyEntries(
        db,
        limit: _memoSearchDrainBatchSize,
      );
      final remaining = await db.query(
        'memo_search_dirty',
        columns: const ['memo_uid'],
        limit: 1,
      );
      if (remaining.isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    _notifyChanged();
  }

  Future<int> drainMemoSearchDirtyEntries({
    int limit = _memoSearchDrainBatchSize,
  }) async {
    final normalizedLimit = limit > 0 ? limit : _memoSearchDrainBatchSize;
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'drainMemoSearchDirtyEntries',
        payload: <String, dynamic>{'limit': normalizedLimit},
        decode: _decodeIntResult,
      );
    }
    final db = await this.db;
    final processed = await MemoSearchDbPersistence.drainDirtyEntries(
      db,
      limit: normalizedLimit,
    );
    if (processed > 0) {
      _notifyChanged();
    }
    return processed;
  }

  Future<void> deleteMemoDeleteTombstone(String memoUid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoDeleteTombstone',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoDeleteTombstone(memoUid);
  }

  Future<void> replaceMemoFromLocalLibrary({
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    Object? displayTimeSec,
    bool displayTimeSpecified = false,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
    bool clearOutbox = false,
    String relationsMode = 'none',
    String? relationsJson,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'replaceMemoFromLocalLibrary',
        payload: <String, dynamic>{
          'uid': uid,
          'content': content,
          'visibility': visibility,
          'pinned': pinned,
          'state': state,
          'createTimeSec': createTimeSec,
          'displayTimeSec': displayTimeSec,
          'displayTimeSpecified': displayTimeSpecified,
          'updateTimeSec': updateTimeSec,
          'tags': tags,
          'attachments': attachments,
          if (location != null) 'location': location.toJson(),
          'relationCount': relationCount,
          'syncState': syncState,
          'lastError': lastError,
          'clearOutbox': clearOutbox,
          'relationsMode': relationsMode,
          'relationsJson': relationsJson,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.replaceMemoFromLocalLibrary(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTimeSec: createTimeSec,
      displayTimeSec: displayTimeSec,
      displayTimeSpecified: displayTimeSpecified,
      updateTimeSec: updateTimeSec,
      tags: tags,
      attachments: attachments,
      location: location,
      relationCount: relationCount,
      syncState: syncState,
      lastError: lastError,
      clearOutbox: clearOutbox,
      relationsMode: relationsMode,
      relationsJson: relationsJson,
    );
  }

  Future<void> deleteMemoFromLocalLibrary({required String memoUid}) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoFromLocalLibrary',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoFromLocalLibrary(memoUid: memoUid);
  }

  Future<void> deleteMemoAfterRecycleBinMove({
    required String memoUid,
    required List<String> draftAttachmentNames,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoAfterRecycleBinMove',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'draftAttachmentNames': draftAttachmentNames,
        },
        decode: (_) {},
      );
      return;
    }

    final normalizedMemoUid = memoUid.trim();
    if (normalizedMemoUid.isEmpty) return;
    await _writeDao.deleteMemoAfterRecycleBinMove(
      memoUid: normalizedMemoUid,
      draftAttachmentNames: draftAttachmentNames,
    );
  }

  Future<List<Map<String, dynamic>>> listRecycleBinItems() async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.listRecycleBinItems(db);
  }

  Future<Map<String, dynamic>?> getRecycleBinItemById(int id) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.getRecycleBinItemById(db, id);
  }

  Future<List<int>> listExpiredRecycleBinItemIds({required int nowMs}) async {
    final db = await this.db;
    return MemoLifecycleDbPersistence.listExpiredRecycleBinItemIds(
      db,
      nowMs: nowMs,
    );
  }

  Future<void> deleteRecycleBinItemById(int id) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteRecycleBinItemById',
        payload: <String, dynamic>{'id': id},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteRecycleBinItemById(id);
  }

  Future<void> clearRecycleBinItems() async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'clearRecycleBinItems',
        payload: const <String, dynamic>{},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.clearRecycleBinItems();
  }

  Future<void> renameMemoUid({
    required String oldUid,
    required String newUid,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'renameMemoUid',
        payload: <String, dynamic>{'oldUid': oldUid, 'newUid': newUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.renameMemoUid(oldUid: oldUid, newUid: newUid);
  }

  Future<int> renameMemoUidAndRewriteOutboxMemoUids({
    required String oldUid,
    required String newUid,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'renameMemoUidAndRewriteOutboxMemoUids',
        payload: <String, dynamic>{'oldUid': oldUid, 'newUid': newUid},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.renameMemoUidAndRewriteOutboxMemoUids(
      oldUid: oldUid,
      newUid: newUid,
    );
  }

  Future<int> rewriteOutboxMemoUids({
    required String oldUid,
    required String newUid,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'rewriteOutboxMemoUids',
        payload: <String, dynamic>{'oldUid': oldUid, 'newUid': newUid},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.rewriteOutboxMemoUids(oldUid: oldUid, newUid: newUid);
  }

  Future<Map<String, dynamic>?> getMemoByUid(String uid) async {
    final db = await this.db;
    return MemoQueryDbPersistence.getMemoByUid(db, uid);
  }

  Future<Map<String, dynamic>?> getMemoClipCardByUid(String memoUid) async {
    final db = await this.db;
    return MemoAuxiliaryDbPersistence.getMemoClipCardByUid(db, memoUid);
  }

  Future<List<Map<String, dynamic>>> listMemoClipCards() async {
    final db = await this.db;
    return MemoAuxiliaryDbPersistence.listMemoClipCards(db);
  }

  Stream<List<Map<String, dynamic>>> watchMemoClipCards() async* {
    yield await listMemoClipCards();
    await for (final _ in changes) {
      yield await listMemoClipCards();
    }
  }

  Future<int> enqueueOutbox({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'enqueueOutbox',
        payload: <String, dynamic>{'type': type, 'payload': payload},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.enqueueOutbox(type: type, payload: payload);
  }

  Future<int> enqueueOutboxBatch({
    required List<Map<String, Object?>> items,
  }) async {
    if (items.isEmpty) return 0;
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'enqueueOutboxBatch',
        payload: <String, dynamic>{'items': items},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.enqueueOutboxBatch(items: items);
  }

  Future<List<Map<String, dynamic>>> listOutboxPending({int limit = 50}) async {
    final db = await this.db;
    return OutboxDbPersistence.listPending(db, limit: limit);
  }

  Future<List<Map<String, dynamic>>> listOutboxQuarantined({
    int limit = 50,
  }) async {
    return listOutboxAttention(limit: limit);
  }

  Future<List<Map<String, dynamic>>> listOutboxAttention({
    int limit = 50,
  }) async {
    final db = await this.db;
    return OutboxDbPersistence.listAttention(db, limit: limit);
  }

  Future<int> countOutboxAttention() async {
    final db = await this.db;
    return OutboxDbPersistence.countAttention(db);
  }

  Future<Map<String, dynamic>?> getLatestOutboxAttention() async {
    final rows = await listOutboxAttention(limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> countOutboxPending() async {
    final db = await this.db;
    return OutboxDbPersistence.countPending(db);
  }

  Future<int> countOutboxRetryable() async {
    final db = await this.db;
    return OutboxDbPersistence.countRetryable(db);
  }

  Future<int> countOutboxFailed() async {
    final db = await this.db;
    return OutboxDbPersistence.countFailed(db);
  }

  Future<int> countOutboxQuarantined() async {
    final db = await this.db;
    return OutboxDbPersistence.countQuarantined(db);
  }

  Future<int> countMemos() async {
    final db = await this.db;
    return MemoCoreDbPersistence.countMemos(db);
  }

  Future<List<Map<String, dynamic>>> listOutboxPendingByType(
    String type,
  ) async {
    final db = await this.db;
    return OutboxDbPersistence.listPendingByType(db, type);
  }

  Future<List<Map<String, dynamic>>> listOutboxByMemoUid(
    String memoUid, {
    Set<String>? types,
    Set<int>? states,
  }) async {
    final db = await this.db;
    return OutboxDbPersistence.listByMemoUid(
      db,
      memoUid,
      types: types,
      states: states,
    );
  }

  Future<Map<String, dynamic>?> claimNextOutboxRunnable({int? nowMs}) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<Map<String, dynamic>?>(
        operation: 'claimNextOutboxRunnable',
        payload: <String, dynamic>{'nowMs': nowMs},
        decode: _decodeMapResult,
      );
    }
    return _writeDao.claimNextOutboxRunnable(nowMs: nowMs);
  }

  Future<Map<String, dynamic>?> claimOutboxTaskById(
    int id, {
    int? nowMs,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<Map<String, dynamic>?>(
        operation: 'claimOutboxTaskById',
        payload: <String, dynamic>{'id': id, 'nowMs': nowMs},
        decode: _decodeMapResult,
      );
    }
    return _writeDao.claimOutboxTaskById(id, nowMs: nowMs);
  }

  Future<int> recoverOutboxRunningTasks() async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'recoverOutboxRunningTasks',
        payload: const <String, dynamic>{},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.recoverOutboxRunningTasks();
  }

  Future<void> markOutboxDone(int id) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'markOutboxDone',
        payload: <String, dynamic>{'id': id},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.markOutboxDone(id);
  }

  Future<void> completeOutboxTask(int id) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'completeOutboxTask',
        payload: <String, dynamic>{'id': id},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.completeOutboxTask(id);
  }

  Future<void> markOutboxError(int id, {required String error}) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'markOutboxError',
        payload: <String, dynamic>{'id': id, 'error': error},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.markOutboxError(id, error: error);
  }

  Future<void> markOutboxRetryScheduled(
    int id, {
    required String error,
    required int retryAtMs,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'markOutboxRetryScheduled',
        payload: <String, dynamic>{
          'id': id,
          'error': error,
          'retryAtMs': retryAtMs,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.markOutboxRetryScheduled(
      id,
      error: error,
      retryAtMs: retryAtMs,
    );
  }

  Future<void> markOutboxQuarantined(
    int id, {
    required String error,
    required String failureCode,
    required String failureKind,
    bool incrementAttempts = true,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'markOutboxQuarantined',
        payload: <String, dynamic>{
          'id': id,
          'error': error,
          'failureCode': failureCode,
          'failureKind': failureKind,
          'incrementAttempts': incrementAttempts,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.markOutboxQuarantined(
      id,
      error: error,
      failureCode: failureCode,
      failureKind: failureKind,
      incrementAttempts: incrementAttempts,
    );
  }

  Future<void> markOutboxRetryPending(int id, {required String error}) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'markOutboxRetryPending',
        payload: <String, dynamic>{'id': id, 'error': error},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.markOutboxRetryPending(id, error: error);
  }

  Future<int> retryOutboxErrors({String? memoUid}) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'retryOutboxErrors',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.retryOutboxErrors(memoUid: memoUid);
  }

  Future<void> retryOutboxItem(int id) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'retryOutboxItem',
        payload: <String, dynamic>{'id': id},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.retryOutboxItem(id);
  }

  Future<void> deleteOutbox(int id) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteOutbox',
        payload: <String, dynamic>{'id': id},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteOutbox(id);
  }

  Future<int> deleteOutboxItems(List<int> ids) async {
    if (ids.isEmpty) return 0;
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'deleteOutboxItems',
        payload: <String, dynamic>{'ids': ids},
        decode: _decodeIntResult,
      );
    }
    return _writeDao.deleteOutboxItems(ids);
  }

  Future<void> discardMissingSourceUploadTask({
    required int outboxId,
    required String memoUid,
    required String attachmentUid,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'discardMissingSourceUploadTask',
        payload: <String, dynamic>{
          'outboxId': outboxId,
          'memoUid': memoUid,
          'attachmentUid': attachmentUid,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.discardMissingSourceUploadTask(
      outboxId: outboxId,
      memoUid: memoUid,
      attachmentUid: attachmentUid,
    );
  }

  Future<bool> hasPendingOutboxTaskForMemo(
    String memoUid, {
    Set<String>? types,
  }) async {
    final db = await this.db;
    return OutboxDbPersistence.hasPendingTaskForMemo(db, memoUid, types: types);
  }

  Future<void> deleteOutboxForMemo(String memoUid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteOutboxForMemo',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteOutboxForMemo(memoUid);
  }

  Future<int> updatePendingCreateMemoContent({
    required String memoUid,
    required String content,
    String? visibility,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'updatePendingCreateMemoContent',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'content': content,
          if (visibility != null) 'visibility': visibility,
        },
        decode: (result) => result is int ? result : 0,
      );
    }
    return _writeDao.updatePendingCreateMemoContent(
      memoUid: memoUid,
      content: content,
      visibility: visibility,
    );
  }

  Future<void> clearOutbox() async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'clearOutbox',
        payload: const <String, dynamic>{},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.clearOutbox();
  }

  Future<Map<String, dynamic>?> getImportHistory({
    required String source,
    required String fileMd5,
  }) async {
    final db = await this.db;
    return MemoAuxiliaryDbPersistence.getImportHistory(
      db,
      source: source,
      fileMd5: fileMd5,
    );
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
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'upsertImportHistory',
        payload: <String, dynamic>{
          'source': source,
          'fileMd5': fileMd5,
          'fileName': fileName,
          'status': status,
          'memoCount': memoCount,
          'attachmentCount': attachmentCount,
          'failedCount': failedCount,
          'error': error,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.upsertImportHistory(
      source: source,
      fileMd5: fileMd5,
      fileName: fileName,
      status: status,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      failedCount: failedCount,
      error: error,
    );
  }

  Future<void> updateImportHistory({
    required int id,
    required int status,
    required int memoCount,
    required int attachmentCount,
    required int failedCount,
    String? error,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'updateImportHistory',
        payload: <String, dynamic>{
          'id': id,
          'status': status,
          'memoCount': memoCount,
          'attachmentCount': attachmentCount,
          'failedCount': failedCount,
          'error': error,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.updateImportHistory(
      id: id,
      status: status,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      failedCount: failedCount,
      error: error,
    );
  }

  Future<void> deleteMemoByUid(String uid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoByUid',
        payload: <String, dynamic>{'uid': uid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoByUid(uid);
  }

  Future<void> upsertMemoClipCard(MemoClipCardMetadata metadata) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertMemoClipCard',
        payload: <String, dynamic>{'row': metadata.toDbRow()},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertMemoClipCard(metadata);
  }

  Future<void> deleteMemoClipCard(String memoUid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoClipCard',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoClipCard(memoUid);
  }

  Future<QuickClipRecoveryJob?> getQuickClipRecoveryJobByMemoUid(
    String memoUid,
  ) async {
    final db = await this.db;
    return QuickClipRecoveryDbPersistence.getJobByMemoUid(db, memoUid);
  }

  Future<List<QuickClipRecoveryJob>> listRecoverableQuickClipRecoveryJobs({
    int limit = 20,
  }) async {
    final db = await this.db;
    return QuickClipRecoveryDbPersistence.listRecoverableJobs(db, limit: limit);
  }

  Future<List<QuickClipRecoveryJob>> listStaleQuickClipRecoveryJobs({
    required DateTime staleBefore,
    int limit = 20,
  }) async {
    final db = await this.db;
    return QuickClipRecoveryDbPersistence.listStaleJobs(
      db,
      staleBefore: staleBefore,
      limit: limit,
    );
  }

  Future<void> upsertQuickClipRecoveryJob(QuickClipRecoveryJob job) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertQuickClipRecoveryJob',
        payload: <String, dynamic>{'row': job.toDbRow()},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertQuickClipRecoveryJob(job);
  }

  Future<int> markQuickClipRecoveryJobRunning({
    required String memoUid,
    required DateTime now,
    String? lastError,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'markQuickClipRecoveryJobRunning',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'nowMs': now.toUtc().millisecondsSinceEpoch,
          'lastError': lastError,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.markQuickClipRecoveryJobRunning(
      memoUid: memoUid,
      now: now,
      lastError: lastError,
    );
  }

  Future<int> markQuickClipRecoveryJobCompleted({
    required String memoUid,
    required DateTime now,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'markQuickClipRecoveryJobCompleted',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'nowMs': now.toUtc().millisecondsSinceEpoch,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.markQuickClipRecoveryJobCompleted(
      memoUid: memoUid,
      now: now,
    );
  }

  Future<int> markQuickClipRecoveryJobAbandoned({
    required String memoUid,
    required DateTime now,
    String? lastError,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'markQuickClipRecoveryJobAbandoned',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'nowMs': now.toUtc().millisecondsSinceEpoch,
          'lastError': lastError,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.markQuickClipRecoveryJobAbandoned(
      memoUid: memoUid,
      now: now,
      lastError: lastError,
    );
  }

  Future<int> markQuickClipRecoveryJobFailed({
    required String memoUid,
    required DateTime now,
    String? lastError,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'markQuickClipRecoveryJobFailed',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'nowMs': now.toUtc().millisecondsSinceEpoch,
          'lastError': lastError,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.markQuickClipRecoveryJobFailed(
      memoUid: memoUid,
      now: now,
      lastError: lastError,
    );
  }

  Future<int> deleteTerminalQuickClipRecoveryJobs({
    required DateTime completedBefore,
    int limit = 100,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      return _dispatchWriteCommand<int>(
        operation: 'deleteTerminalQuickClipRecoveryJobs',
        payload: <String, dynamic>{
          'completedBeforeMs': completedBefore.toUtc().millisecondsSinceEpoch,
          'limit': limit,
        },
        decode: _decodeIntResult,
      );
    }
    return _writeDao.deleteTerminalQuickClipRecoveryJobs(
      completedBefore: completedBefore,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getMemoReminderByUid(String memoUid) async {
    final db = await this.db;
    return MemoAuxiliaryDbPersistence.getMemoReminderByUid(db, memoUid);
  }

  Future<List<Map<String, dynamic>>> listMemoReminders() async {
    final db = await this.db;
    return MemoAuxiliaryDbPersistence.listMemoReminders(db);
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
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertMemoReminder',
        payload: <String, dynamic>{
          'memoUid': memoUid,
          'mode': mode,
          'timesJson': timesJson,
        },
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertMemoReminder(
      memoUid: memoUid,
      mode: mode,
      timesJson: timesJson,
    );
  }

  Future<void> deleteMemoReminder(String memoUid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteMemoReminder',
        payload: <String, dynamic>{'memoUid': memoUid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteMemoReminder(memoUid);
  }

  Future<List<Map<String, dynamic>>> listComposeDraftRows({
    required String workspaceKey,
    int? limit,
  }) async {
    final db = await this.db;
    return ComposeDraftDbPersistence.listRows(
      db,
      workspaceKey: workspaceKey,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getComposeDraftRow({
    required String uid,
    String? workspaceKey,
  }) async {
    final db = await this.db;
    return ComposeDraftDbPersistence.getRow(
      db,
      uid: uid,
      workspaceKey: workspaceKey,
    );
  }

  Future<Map<String, dynamic>?> getComposeEditDraftRowForMemo({
    required String workspaceKey,
    required String targetMemoUid,
  }) async {
    final db = await this.db;
    return ComposeDraftDbPersistence.getEditDraftRowForMemo(
      db,
      workspaceKey: workspaceKey,
      targetMemoUid: targetMemoUid,
    );
  }

  Future<Map<String, dynamic>?> getLatestComposeDraftRow({
    required String workspaceKey,
  }) async {
    final db = await this.db;
    return ComposeDraftDbPersistence.getLatestRow(
      db,
      workspaceKey: workspaceKey,
    );
  }

  Future<void> upsertComposeDraftRow(Map<String, Object?> row) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertComposeDraftRow',
        payload: <String, dynamic>{'row': row},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.upsertComposeDraftRow(row);
  }

  Future<void> replaceComposeDraftRows({
    required String workspaceKey,
    required List<Map<String, Object?>> rows,
  }) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'replaceComposeDraftRows',
        payload: <String, dynamic>{'workspaceKey': workspaceKey, 'rows': rows},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.replaceComposeDraftRows(
      workspaceKey: workspaceKey,
      rows: rows,
    );
  }

  Future<void> deleteComposeDraft(String uid) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteComposeDraft',
        payload: <String, dynamic>{'uid': uid},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteComposeDraft(uid);
  }

  Future<void> deleteComposeDraftsByWorkspace(String workspaceKey) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteComposeDraftsByWorkspace',
        payload: <String, dynamic>{'workspaceKey': workspaceKey},
        decode: (_) {},
      );
      return;
    }
    await _writeDao.deleteComposeDraftsByWorkspace(workspaceKey);
  }

  Future<Map<String, dynamic>?> getCollectionReaderProgressRow(
    String collectionId,
  ) async {
    final db = await this.db;
    return CollectionDbPersistence.getReaderProgressRow(db, collectionId);
  }

  Future<void> upsertCollectionReaderProgressRow(
    Map<String, Object?> row,
  ) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertCollectionReaderProgressRow',
        payload: <String, dynamic>{'row': row},
        decode: (_) {},
        notifyChangedAfterRemote: false,
      );
      return;
    }
    await _writeDao.upsertCollectionReaderProgressRow(row);
  }

  Future<void> deleteCollectionReaderProgress(String collectionId) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) {
      return;
    }
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteCollectionReaderProgress',
        payload: <String, dynamic>{'collectionId': normalizedCollectionId},
        decode: (_) {},
        notifyChangedAfterRemote: false,
      );
      return;
    }
    await _writeDao.deleteCollectionReaderProgress(normalizedCollectionId);
  }

  Future<Map<String, dynamic>?> getCollectionArticleFlowProgressRow(
    String collectionId,
  ) async {
    final db = await this.db;
    return CollectionDbPersistence.getArticleFlowProgressRow(db, collectionId);
  }

  Future<void> upsertCollectionArticleFlowProgressRow(
    Map<String, Object?> row,
  ) async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'upsertCollectionArticleFlowProgressRow',
        payload: <String, dynamic>{'row': row},
        decode: (_) {},
        notifyChangedAfterRemote: false,
      );
      return;
    }
    await _writeDao.upsertCollectionArticleFlowProgressRow(row);
  }

  Future<void> deleteCollectionArticleFlowProgress(String collectionId) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) {
      return;
    }
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'deleteCollectionArticleFlowProgress',
        payload: <String, dynamic>{'collectionId': normalizedCollectionId},
        decode: (_) {},
        notifyChangedAfterRemote: false,
      );
      return;
    }
    await _writeDao.deleteCollectionArticleFlowProgress(normalizedCollectionId);
  }

  Future<List<String>> listTagStrings({String? state}) async {
    final db = await this.db;
    return MemoQueryDbPersistence.listTagStrings(db, state: state);
  }

  Future<List<Map<String, dynamic>>> listMemoAttachmentRows({
    String? state,
  }) async {
    final db = await this.db;
    return MemoQueryDbPersistence.listMemoAttachmentRows(db, state: state);
  }

  Future<List<Map<String, dynamic>>> listMemoStorageSummaryRows({
    String? state,
  }) async {
    final db = await this.db;
    return MemoQueryDbPersistence.listMemoStorageSummaryRows(db, state: state);
  }

  Future<List<Map<String, dynamic>>> listMemos({
    String? searchQuery,
    String? state,
    String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    MemoSortOrder sortOrder = MemoSortOrder.createDesc,
    int? limit = 100,
    MemoSearchDbFilters searchFilters = MemoSearchDbFilters.empty,
  }) async {
    final db = await this.db;
    return MemoSearchDbPersistence.listRows(
      db,
      searchQuery: searchQuery,
      state: state,
      tag: tag,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      sortOrder: sortOrder,
      limit: limit,
      dirtyFallbackLimit: MemoSearchDbPersistence.defaultDirtyFallbackLimit,
      filters: searchFilters,
    );
  }

  Future<List<Map<String, dynamic>>> listMemoUidSyncStates({
    String? state,
  }) async {
    final db = await this.db;
    return MemoQueryDbPersistence.listMemoUidSyncStates(db, state: state);
  }

  Future<Set<String>> listPendingOutboxMemoUids() async {
    final db = await this.db;
    return OutboxDbPersistence.listPendingMemoUids(db);
  }

  Future<List<Map<String, dynamic>>> listMemosForExport({
    int? startTimeSec,
    int? endTimeSecExclusive,
    bool includeArchived = false,
  }) async {
    final db = await this.db;
    return MemoQueryDbPersistence.listMemosForExport(
      db,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includeArchived: includeArchived,
    );
  }

  Future<List<Map<String, dynamic>>> listMemosForLosslessExport({
    int? startTimeSec,
    int? endTimeSecExclusive,
    bool includeArchived = false,
  }) async {
    final db = await this.db;
    return MemoQueryDbPersistence.listMemosForLosslessExport(
      db,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      includeArchived: includeArchived,
    );
  }

  Stream<List<Map<String, dynamic>>> watchMemos({
    String? searchQuery,
    String? state,
    String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    MemoSortOrder sortOrder = MemoSortOrder.createDesc,
    int? limit = 100,
    MemoSearchDbFilters searchFilters = MemoSearchDbFilters.empty,
  }) async* {
    yield await listMemos(
      searchQuery: searchQuery,
      state: state,
      tag: tag,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      sortOrder: sortOrder,
      limit: limit,
      searchFilters: searchFilters,
    );
    await for (final _ in changes) {
      yield await listMemos(
        searchQuery: searchQuery,
        state: state,
        tag: tag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        sortOrder: sortOrder,
        limit: limit,
        searchFilters: searchFilters,
      );
    }
  }

  Future<void> rebuildStatsCache() async {
    if (_writeProxyEnabled && _localWriteDepth == 0) {
      await _dispatchWriteCommand<void>(
        operation: 'rebuildStatsCache',
        payload: const <String, dynamic>{},
        decode: (_) {},
      );
      return;
    }
    final db = await this.db;
    await StatsCacheDbPersistence.rebuildStatsCache(
      db,
      runTransaction: AppDatabaseWriteDao.runTransaction,
      maintenanceBatchSize: _maintenanceBatchSize,
    );
    _notifyChanged();
  }

  static Future<void> _backfillTagsFromMemos(Database db) async {
    var lastId = 0;
    while (true) {
      final rows = await MemoQueryDbPersistence.listMemoTagBackfillRows(
        db,
        afterId: lastId,
        limit: _maintenanceBatchSize,
      );
      if (rows.isEmpty) return;
      lastId = _readInt(rows.last['id']) ?? lastId;
      await AppDatabaseWriteDao.runTransaction<void>(db, (txn) async {
        for (final row in rows) {
          final uid = row['uid'];
          if (uid is! String || uid.trim().isEmpty) continue;
          final tagsText = (row['tags'] as String?) ?? '';
          final tags = _splitTagsText(tagsText);
          final resolved = <String, int>{};
          for (final tag in tags) {
            final entry = await TagDbPersistence.resolvePath(txn, tag);
            if (entry == null) continue;
            resolved[entry.path] = entry.id;
          }
          final canonicalTags = resolved.keys.toList(growable: false)..sort();
          await TagDbPersistence.updateMemoTagsMapping(
            txn,
            uid,
            resolved.values.toList(growable: false),
          );
          final updatedTagsText = canonicalTags.join(' ');
          if (updatedTagsText != tagsText) {
            await MemoWriteDbPersistence.updateMemoTagsTextByUid(
              txn,
              uid,
              tagsText: updatedTagsText,
            );
          }
          final rowId = _readInt(row['id']) ?? 0;
          if (rowId > 0) {
            final searchDocument =
                await MemoSearchDbPersistence.buildDocumentForMemo(
                  txn,
                  memoUid: uid,
                  content: (row['content'] as String?) ?? '',
                );
            await MemoSearchDbPersistence.replaceFtsEntry(
              txn,
              rowId: rowId,
              content: searchDocument,
              tags: updatedTagsText,
            );
          }
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }
}
