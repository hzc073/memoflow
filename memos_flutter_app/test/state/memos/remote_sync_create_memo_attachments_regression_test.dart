import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/attachment_preprocessor.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/data/api/memo_api_facade.dart';
import 'package:memos_flutter_app/data/api/memo_api_version.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/logs/sync_queue_progress_tracker.dart';
import 'package:memos_flutter_app/data/logs/sync_status_tracker.dart';
import 'package:memos_flutter_app/data/models/image_bed_settings.dart';
import 'package:memos_flutter_app/data/repositories/image_bed_settings_repository.dart';
import 'package:memos_flutter_app/features/share/share_inline_image_content.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/memos/note_input_providers.dart';
import 'package:memos_flutter_app/state/memos/sync_queue_controller.dart';
import 'package:memos_flutter_app/state/memos/sync_queue_models.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test(
    'RemoteSyncController keeps memo pending for update_memo when attachment tasks remain',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName('remote_sync_update_waits_for_attachment');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-1',
        content: 'memo updated before upload',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: const [
          {
            'name': 'attachments/att-1',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': 'file:///tmp/sample.png',
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.enqueueOutbox(
        type: 'update_memo',
        payload: {
          'uid': 'memo-1',
          'content': 'memo updated before upload',
          'visibility': 'PRIVATE',
          'pinned': false,
        },
      );
      final uploadOutboxId = await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': 'att-1',
          'memo_uid': 'memo-1',
          'file_path': '/tmp/sample.png',
          'filename': 'sample.png',
          'mime_type': 'image/png',
          'file_size': 42,
        },
      );
      final sqlite = await db.db;
      await sqlite.rawUpdate('UPDATE outbox SET state = ? WHERE id = ?', [
        AppDatabase.outboxStateError,
        uploadOutboxId,
      ]);

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccessWithAttention>());
      final row = await db.getMemoByUid('memo-1');
      expect(row?['sync_state'], 1);
    },
  );

  test(
    'RemoteSyncController keeps memo pending when later attachment tasks remain',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName(
        'remote_sync_create_waits_for_attachment_tasks',
      );
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-1',
        content: 'memo waiting for upload retry',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: const [
          {
            'name': 'attachments/att-1',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': 'file:///tmp/sample.png',
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-1',
          'content': 'memo waiting for upload retry',
          'visibility': 'PRIVATE',
          'pinned': false,
          'has_attachments': true,
          'create_time': 1773424800,
          'display_time': 1773424800,
        },
      );
      final uploadOutboxId = await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': 'att-1',
          'memo_uid': 'memo-1',
          'file_path': '/tmp/sample.png',
          'filename': 'sample.png',
          'mime_type': 'image/png',
          'file_size': 42,
        },
      );
      final sqlite = await db.db;
      await sqlite.rawUpdate('UPDATE outbox SET state = ? WHERE id = ?', [
        AppDatabase.outboxStateError,
        uploadOutboxId,
      ]);

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccessWithAttention>());
      final row = await db.getMemoByUid('memo-1');
      expect(row?['sync_state'], 1);
    },
  );

  test(
    'RemoteSyncController does not prune memo after deleting failed create_memo task',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName(
        'remote_sync_keeps_local_only_memo_after_queue_delete',
      );
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final now = DateTime.utc(2026, 4, 2, 3, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-local-only',
        content: 'memo stays local',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 2,
        lastError: 'content too long (max 8192 characters)',
      );
      final outboxId = await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-local-only',
          'content': 'memo stays local',
          'visibility': 'PRIVATE',
          'pinned': false,
        },
      );

      await container
          .read(syncQueueControllerProvider)
          .deleteItem(
            SyncQueueItem(
              id: outboxId,
              type: 'create_memo',
              state: SyncQueueOutboxState.error,
              attempts: 1,
              createdAt: now,
              preview: 'memo stays local',
              filename: null,
              lastError: 'content too long (max 8192 characters)',
              memoUid: 'memo-local-only',
              attachmentUid: null,
              retryAt: null,
              failureCode: 'content_too_long',
            ),
          );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      final row = await db.getMemoByUid('memo-local-only');
      expect(row, isNotNull);
      expect(isLocalOnlySyncPausedError(row?['last_error'] as String?), isTrue);
      expect(row?['sync_state'], isNot(0));
    },
  );

  test(
    'RemoteSyncController keeps memo pending until queued create_memo runs',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName(
        'remote_sync_create_stays_pending_until_create_task_runs',
      );
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final tempDir = await support.createTempDir(
        'remote_sync_pending_until_create_task_runs',
      );
      final attachmentFile = File(
        '${tempDir.path}${Platform.pathSeparator}sample.png',
      );
      await attachmentFile.writeAsBytes(const <int>[
        137,
        80,
        78,
        71,
        1,
        2,
        3,
        4,
      ]);

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-1',
        content: 'memo still waiting for create',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: [
          {
            'name': 'attachments/att-1',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': await attachmentFile.length(),
            'externalLink': Uri.file(attachmentFile.path).toString(),
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': 'att-1',
          'memo_uid': 'memo-1',
          'file_path': attachmentFile.path,
          'filename': 'sample.png',
          'mime_type': 'image/png',
          'file_size': await attachmentFile.length(),
        },
      );
      final createOutboxId = await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-1',
          'content': 'memo still waiting for create',
          'visibility': 'PRIVATE',
          'pinned': false,
          'has_attachments': true,
          'create_time': 1773424800,
          'display_time': 1773424800,
        },
      );
      final sqlite = await db.db;
      final retryAt = DateTime.now().toUtc().add(const Duration(hours: 1));
      await sqlite
          .rawUpdate('UPDATE outbox SET state = ?, retry_at = ? WHERE id = ?', [
            AppDatabase.outboxStateRetry,
            retryAt.millisecondsSinceEpoch,
            createOutboxId,
          ]);

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncFailure>());
      final row = await db.getMemoByUid('memo-1');
      expect(row?['sync_state'], 1);
      expect(
        server.requests.where(
          (request) =>
              request.method == 'POST' && request.path == '/api/v1/resources',
        ),
        hasLength(1),
      );
      expect(
        server.requests.where(
          (request) =>
              request.method == 'POST' && request.path == '/api/v1/memos',
        ),
        isEmpty,
      );
    },
  );

  test(
    'RemoteSyncController quarantines missing update_memo and continues unrelated tasks',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start(
        missingMemoIds: const {'memo-missing'},
      );
      final dbName = uniqueDbName(
        'remote_sync_quarantines_missing_update_and_continues',
      );
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-missing',
        content: 'bad memo content',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.enqueueOutbox(
        type: 'update_memo',
        payload: {
          'uid': 'memo-missing',
          'content': 'bad memo content',
          'visibility': 'PRIVATE',
          'pinned': false,
        },
      );

      await db.upsertMemo(
        uid: 'memo-good',
        content: 'plain memo',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-good',
          'content': 'plain memo',
          'visibility': 'PRIVATE',
          'pinned': false,
          'has_attachments': false,
          'create_time': 1773424800,
          'display_time': 1773424800,
        },
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccessWithAttention>());
      final attention = (result as MemoSyncSuccessWithAttention).attention;
      expect(attention?.failureCode, 'remote_missing_memo');
      expect(attention?.memoUid, 'memo-missing');
      expect(attention?.outboxId, isNotNull);
      expect(await db.countOutboxPending(), 0);
      expect(await db.countOutboxQuarantined(), 1);

      final missingRow = await db.getMemoByUid('memo-missing');
      final goodRow = await db.getMemoByUid('memo-good');
      expect(missingRow?['sync_state'], 2);
      expect(goodRow?['sync_state'], 0);

      expect(
        server.requests.where(
          (request) =>
              request.method == 'PATCH' &&
              request.path == '/api/v1/memos/memo-missing',
        ),
        hasLength(1),
      );
      expect(
        server.requests.where(
          (request) =>
              request.method == 'POST' && request.path == '/api/v1/memos',
        ),
        hasLength(1),
      );
      expect(
        server.requests
            .where(
              (request) =>
                  request.method == 'POST' && request.path == '/api/v1/memos',
            )
            .single
            .queryParameters['memoId'],
        'memo-good',
      );
    },
  );

  test(
    'RemoteSyncController still reports attention when quarantined tasks already exist',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName('remote_sync_existing_attention_survives');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.enqueueOutbox(
        type: 'update_memo',
        payload: {
          'uid': 'memo-existing-attention',
          'content': 'stale content',
          'visibility': 'PRIVATE',
          'pinned': false,
        },
      );
      final sqlite = await db.db;
      await sqlite.rawUpdate(
        'UPDATE outbox SET state = ?, last_error = ?, failure_code = ?, failure_kind = ?, quarantined_at = ? WHERE type = ?',
        [
          AppDatabase.outboxStateQuarantined,
          'content too long (max 8192 characters)',
          'content_too_long',
          'fatal_immediate',
          DateTime.now().toUtc().millisecondsSinceEpoch,
          'update_memo',
        ],
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccessWithAttention>());
      final attention = (result as MemoSyncSuccessWithAttention).attention;
      expect(attention?.failureCode, 'content_too_long');
      expect(attention?.outboxId, isNotNull);
      expect(await db.countOutboxAttention(), 1);
    },
  );

  test(
    'RemoteSyncController discards missing upload_attachment and continues later queue items',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName('remote_sync_discards_missing_upload');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final missingDir = await support.createTempDir(
        'remote_sync_missing_source',
      );
      final missingPath =
          '${missingDir.path}${Platform.pathSeparator}missing.png';

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-bad',
        content: 'memo with missing upload',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: const [
          {
            'name': 'attachments/att-missing',
            'filename': 'missing.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': 'file:///missing.png',
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': 'att-missing',
          'memo_uid': 'memo-bad',
          'file_path': missingPath,
          'filename': 'missing.png',
          'mime_type': 'image/png',
          'file_size': 42,
        },
      );

      await db.upsertMemo(
        uid: 'memo-plain',
        content: 'plain memo',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-plain',
          'content': 'plain memo',
          'visibility': 'PRIVATE',
          'pinned': false,
          'has_attachments': false,
          'create_time': 1773424800,
          'display_time': 1773424800,
        },
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      expect(await db.countOutboxPending(), 0);

      final badRow = await db.getMemoByUid('memo-bad');
      final plainRow = await db.getMemoByUid('memo-plain');
      expect(badRow?['sync_state'], 0);
      expect(plainRow?['sync_state'], 0);
      expect(jsonDecode(badRow?['attachments_json'] as String), isEmpty);

      expect(
        server.requests.where(
          (request) =>
              request.method == 'POST' && request.path == '/api/v1/resources',
        ),
        isEmpty,
      );
      expect(
        server.requests.where(
          (request) =>
              request.method == 'POST' && request.path == '/api/v1/memos',
        ),
        hasLength(1),
      );
      expect(
        server.requests
            .where(
              (request) =>
                  request.method == 'POST' && request.path == '/api/v1/memos',
            )
            .single
            .queryParameters['memoId'],
        'memo-plain',
      );
    },
  );

  test(
    'RemoteSyncController uploads resources before create_memo and embeds them for 0.23',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName('remote_sync_create_with_resources_v023');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          memosApiProvider.overrideWithValue(api),
        ],
      );
      final noteInputController = container.read(noteInputControllerProvider);
      final tempDir = await support.createTempDir('remote_sync_create_v023');
      final attachmentFile = File(
        '${tempDir.path}${Platform.pathSeparator}sample.png',
      );
      await attachmentFile.writeAsBytes(const <int>[
        137,
        80,
        78,
        71,
        1,
        2,
        3,
        4,
      ]);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await noteInputController.createMemo(
        uid: 'memo-1',
        content: 'memo with image',
        visibility: 'PRIVATE',
        now: DateTime.utc(2026, 3, 13, 18, 0),
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        hasAttachments: true,
        relations: const <Map<String, dynamic>>[],
        pendingAttachments: [
          NoteInputPendingAttachment(
            uid: 'att-1',
            filePath: attachmentFile.path,
            filename: 'sample.png',
            mimeType: 'image/png',
            size: await attachmentFile.length(),
          ),
        ],
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      expect(await db.countOutboxPending(), 0);
      final row = await db.getMemoByUid('memo-1');
      expect(row?['sync_state'], 0);

      final uploadIndex = server.requests.indexWhere(
        (request) =>
            request.method == 'POST' && request.path == '/api/v1/resources',
      );
      final createIndex = server.requests.indexWhere(
        (request) =>
            request.method == 'POST' && request.path == '/api/v1/memos',
      );
      expect(uploadIndex, greaterThanOrEqualTo(0));
      expect(createIndex, greaterThan(uploadIndex));

      final uploadRequest = server.requests[uploadIndex];
      final createRequest = server.requests[createIndex];
      expect(uploadRequest.queryParameters['resourceId'], 'att-1');
      expect(uploadRequest.jsonBody?['memo'], isNull);
      expect(createRequest.queryParameters['memoId'], 'memo-1');
      expect(createRequest.jsonBody?['resources'], [
        {'name': 'resources/att-1'},
      ]);
    },
  );

  test(
    'RemoteSyncController rebinds uploaded resources after create_memo 409 on 0.23',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start(
        conflictOnCreate: true,
      );
      final dbName = uniqueDbName(
        'remote_sync_rebind_resources_after_409_v023',
      );
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          memosApiProvider.overrideWithValue(api),
        ],
      );
      final noteInputController = container.read(noteInputControllerProvider);
      final tempDir = await support.createTempDir(
        'remote_sync_create_409_v023',
      );
      final attachmentFile = File(
        '${tempDir.path}${Platform.pathSeparator}sample.png',
      );
      await attachmentFile.writeAsBytes(const <int>[
        137,
        80,
        78,
        71,
        1,
        2,
        3,
        4,
      ]);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await noteInputController.createMemo(
        uid: 'memo-1',
        content: 'memo with image',
        visibility: 'PRIVATE',
        now: DateTime.utc(2026, 3, 13, 18, 0),
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        hasAttachments: true,
        relations: const <Map<String, dynamic>>[],
        pendingAttachments: [
          NoteInputPendingAttachment(
            uid: 'att-1',
            filePath: attachmentFile.path,
            filename: 'sample.png',
            mimeType: 'image/png',
            size: await attachmentFile.length(),
          ),
        ],
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      expect(await db.countOutboxPending(), 0);
      final row = await db.getMemoByUid('memo-1');
      expect(row?['sync_state'], 0);

      final uploadIndex = server.requests.indexWhere(
        (request) =>
            request.method == 'POST' && request.path == '/api/v1/resources',
      );
      final createIndex = server.requests.indexWhere(
        (request) =>
            request.method == 'POST' && request.path == '/api/v1/memos',
      );
      final rebindIndex = server.requests.indexWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.path == '/api/v1/memos/memo-1/resources',
      );
      expect(uploadIndex, greaterThanOrEqualTo(0));
      expect(createIndex, greaterThan(uploadIndex));
      expect(rebindIndex, greaterThan(createIndex));
      expect(server.createdMemo?['resources'], [
        {'name': 'resources/att-1'},
      ]);
    },
  );

  test(
    'RemoteSyncController rewrites update_memo local inline image urls to source urls when no remote attachment url exists',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName('remote_sync_update_rewrites_local_inline');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final localUrl = shareInlineLocalUrlFromPath(
        '${Directory.systemTemp.path}${Platform.pathSeparator}shared-inline-source.png',
      );
      const sourceUrl = 'https://example.com/source-inline-image.png';
      final content = '<p>intro</p><img src="$localUrl">\n![]($localUrl)';

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-1',
        content: content,
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: [
          {
            'name': 'att-1',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': localUrl,
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.upsertMemoInlineImageSource(
        memoUid: 'memo-1',
        localUrl: localUrl,
        sourceUrl: sourceUrl,
      );
      await db.enqueueOutbox(
        type: 'update_memo',
        payload: {
          'uid': 'memo-1',
          'content': content,
          'visibility': 'PRIVATE',
          'pinned': false,
        },
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      final patchRequest = server.requests.singleWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.path == '/api/v1/memos/memo-1',
      );
      final rewrittenContent = patchRequest.jsonBody?['content'] as String? ?? '';
      expect(rewrittenContent, contains(sourceUrl));
      expect(rewrittenContent, isNot(contains(localUrl)));
    },
  );

  test(
    'RemoteSyncController prefers remote attachment urls over source urls for create_memo',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName('remote_sync_create_prefers_remote_inline');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final localUrl = shareInlineLocalUrlFromPath(
        '${Directory.systemTemp.path}${Platform.pathSeparator}shared-inline-remote.png',
      );
      const sourceUrl = 'https://example.com/source-inline-image.png';
      final remoteUrl = '${server.baseUrl}/file/resources/att-1/sample.png';
      final content = '<p>intro</p><img src="$localUrl">';

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-1',
        content: content,
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: [
          {
            'name': 'resources/att-1',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': localUrl,
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.upsertMemoInlineImageSource(
        memoUid: 'memo-1',
        localUrl: localUrl,
        sourceUrl: sourceUrl,
      );
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-1',
          'content': content,
          'visibility': 'PRIVATE',
          'pinned': false,
          'has_attachments': true,
          'create_time': 1773424800,
          'display_time': 1773424800,
        },
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        serverBaseUrl: server.baseUrl,
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      final createRequest = server.requests.singleWhere(
        (request) =>
            request.method == 'POST' && request.path == '/api/v1/memos',
      );
      final rewrittenContent = createRequest.jsonBody?['content'] as String? ?? '';
      expect(rewrittenContent, contains(remoteUrl));
      expect(rewrittenContent, isNot(contains(sourceUrl)));
      expect(rewrittenContent, isNot(contains(localUrl)));
    },
  );

  test(
    'RemoteSyncController rewrites syncCurrentLocalMemoContent after inline upload',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName('remote_sync_inline_upload_rewrites_sync_current');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v024,
      );
      final tempDir = await support.createTempDir(
        'remote_sync_inline_upload_rewrites_sync_current',
      );
      final stagedFile = File(
        '${tempDir.path}${Platform.pathSeparator}uploaded-sample.png',
      );
      await stagedFile.writeAsBytes(const <int>[137, 80, 78, 71, 1, 2, 3, 4]);
      final contentLocalUrl = shareInlineLocalUrlFromPath(
        '${tempDir.path}${Platform.pathSeparator}content-only.png',
      );
      final payloadLocalUrl = shareInlineLocalUrlFromPath(stagedFile.path);
      const sourceUrl = 'https://example.com/source-inline-image.png';
      final content = '<p>intro</p><img src="$contentLocalUrl">';

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-1',
        content: content,
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1773424800,
        updateTimeSec: 1773424800,
        tags: const <String>[],
        attachments: [
          {
            'name': 'attachments/att-1',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': contentLocalUrl,
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      await db.upsertMemoInlineImageSource(
        memoUid: 'memo-1',
        localUrl: contentLocalUrl,
        sourceUrl: sourceUrl,
      );
      await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': 'att-1',
          'memo_uid': 'memo-1',
          'file_path': stagedFile.path,
          'filename': 'sample.png',
          'mime_type': 'image/png',
          'file_size': await stagedFile.length(),
          'share_inline_image': true,
          'share_inline_local_url': payloadLocalUrl,
        },
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        serverBaseUrl: server.baseUrl,
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      final patchRequest = server.requests.lastWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.path == '/api/v1/memos/memo-1',
      );
      final rewrittenContent = patchRequest.jsonBody?['content'] as String? ?? '';
      expect(rewrittenContent, contains(sourceUrl));
      expect(rewrittenContent, isNot(contains(contentLocalUrl)));
      expect(rewrittenContent, isNot(contains(payloadLocalUrl)));
    },
  );

  test(
    'RemoteSyncController still runs delete_attachment with memo tombstone',
    () async {
      final server = await _RemoteSyncAttachmentRegressionServer.start();
      final dbName = uniqueDbName(
        'remote_sync_delete_attachment_with_tombstone',
      );
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: server.baseUrl,
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );

      addTearDown(() async {
        await db.close();
        await server.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemoDeleteTombstone(
        memoUid: 'memo-1',
        state: AppDatabase.memoDeleteTombstoneStatePendingRemoteDelete,
      );
      await db.enqueueOutbox(
        type: 'delete_attachment',
        payload: {'attachment_name': 'resources/att-1', 'memo_uid': 'memo-1'},
      );
      await db.enqueueOutbox(
        type: 'delete_memo',
        payload: {'uid': 'memo-1', 'force': false},
      );

      final controller = RemoteSyncController(
        db: db,
        api: api,
        currentUserName: 'users/1',
        syncStatusTracker: SyncStatusTracker(),
        syncQueueProgressTracker: SyncQueueProgressTracker(),
        imageBedRepository: _FakeImageBedSettingsRepository(),
        attachmentPreprocessor: _PassThroughAttachmentPreprocessor(),
      );
      addTearDown(controller.dispose);

      final result = await HttpOverrides.runWithHttpOverrides(
        () => controller.syncNow(),
        _PassthroughHttpOverrides(),
      );

      expect(result, isA<MemoSyncSuccess>());
      final deleteAttachmentIndex = server.requests.indexWhere(
        (request) =>
            request.method == 'DELETE' &&
            request.path == '/api/v1/resources/att-1',
      );
      final deleteMemoIndex = server.requests.indexWhere(
        (request) =>
            request.method == 'DELETE' &&
            request.path == '/api/v1/memos/memo-1',
      );
      expect(deleteAttachmentIndex, greaterThanOrEqualTo(0));
      expect(deleteMemoIndex, greaterThan(deleteAttachmentIndex));
    },
  );
}

class _PassthroughHttpOverrides extends HttpOverrides {}

class _PassThroughAttachmentPreprocessor implements AttachmentPreprocessor {
  @override
  Future<AttachmentPreprocessResult> preprocess(
    AttachmentPreprocessRequest request,
  ) async {
    final file = File(request.filePath);
    return AttachmentPreprocessResult(
      filePath: request.filePath,
      filename: request.filename,
      mimeType: request.mimeType,
      size: await file.length(),
    );
  }
}

class _FakeImageBedSettingsRepository extends ImageBedSettingsRepository {
  _FakeImageBedSettingsRepository()
    : super(const FlutterSecureStorage(), accountKey: 'test-account');

  @override
  Future<ImageBedSettings> read() async => ImageBedSettings.defaults;
}

class _CapturedRegressionRequest {
  const _CapturedRegressionRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.jsonBody,
  });

  final String method;
  final String path;
  final Map<String, String> queryParameters;
  final Map<String, dynamic>? jsonBody;
}

class _RemoteSyncAttachmentRegressionServer {
  _RemoteSyncAttachmentRegressionServer._(
    this._server, {
    required this.conflictOnCreate,
    required this.missingMemoIds,
  });

  final HttpServer _server;
  final bool conflictOnCreate;
  final Set<String> missingMemoIds;
  final List<_CapturedRegressionRequest> requests =
      <_CapturedRegressionRequest>[];
  Map<String, dynamic>? _createdMemo;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');
  Map<String, dynamic>? get createdMemo =>
      _createdMemo == null ? null : Map<String, dynamic>.from(_createdMemo!);

  static Future<_RemoteSyncAttachmentRegressionServer> start({
    bool conflictOnCreate = false,
    Set<String> missingMemoIds = const <String>{},
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _RemoteSyncAttachmentRegressionServer._(
      server,
      conflictOnCreate: conflictOnCreate,
      missingMemoIds: missingMemoIds,
    );
    server.listen(harness._handleRequest);
    return harness;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final bodyText = await utf8.decoder.bind(request).join();
    Map<String, dynamic>? jsonBody;
    if (bodyText.trim().isNotEmpty) {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map) {
        jsonBody = decoded.cast<String, dynamic>();
      }
    }

    requests.add(
      _CapturedRegressionRequest(
        method: request.method,
        path: request.uri.path,
        queryParameters: request.uri.queryParameters,
        jsonBody: jsonBody,
      ),
    );

    if (request.method == 'POST' && request.uri.path == '/api/v1/resources') {
      final resourceId =
          request.uri.queryParameters['resourceId'] ?? 'generated';
      final filename = (jsonBody?['filename'] as String?) ?? 'sample.png';
      final type = (jsonBody?['type'] as String?) ?? 'application/octet-stream';
      await _writeJson(request.response, <String, Object?>{
        'name': 'resources/$resourceId',
        'filename': filename,
        'type': type,
        'size': 8,
        'externalLink':
            'http://127.0.0.1:${_server.port}/file/resources/$resourceId/$filename',
      });
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/api/v1/memos') {
      final memoId = request.uri.queryParameters['memoId'] ?? 'generated-memo';
      if (conflictOnCreate) {
        _createdMemo ??= _buildMemo(
          memoId: memoId,
          content: 'existing memo content',
          resources: const <Object>[],
        );
        await _writeJson(request.response, <String, Object?>{
          'message': 'memo already exists',
        }, statusCode: HttpStatus.conflict);
        return;
      }

      _createdMemo = _buildMemo(
        memoId: memoId,
        content: (jsonBody?['content'] as String?) ?? '',
        resources: jsonBody?['resources'] ?? const <Object>[],
        visibility: (jsonBody?['visibility'] as String?) ?? 'PRIVATE',
        pinned: (jsonBody?['pinned'] as bool?) ?? false,
      );
      await _writeJson(request.response, _createdMemo!);
      return;
    }

    if (request.method == 'PATCH' &&
        RegExp(r'^/api/v1/memos/[^/]+/resources$').hasMatch(request.uri.path)) {
      final memoId = request.uri.pathSegments[3];
      _createdMemo ??= _buildMemo(memoId: memoId);
      _createdMemo!['resources'] =
          jsonBody?['resources'] as List<dynamic>? ?? const <Object>[];
      await _writeJson(request.response, _createdMemo!);
      return;
    }

    if (request.method == 'PATCH' &&
        RegExp(r'^/api/v1/memos/[^/]+$').hasMatch(request.uri.path)) {
      final memoId = request.uri.pathSegments[3];
      if (missingMemoIds.contains(memoId)) {
        await _writeJson(request.response, <String, Object?>{
          'code': 5,
          'message': 'memo not found',
          'details': const <Object>[],
        }, statusCode: HttpStatus.notFound);
        return;
      }
      _createdMemo ??= _buildMemo(memoId: memoId);
      if (jsonBody != null) {
        for (final entry in jsonBody.entries) {
          _createdMemo![entry.key] = entry.value;
        }
      }
      await _writeJson(request.response, _createdMemo!);
      return;
    }

    if (request.method == 'DELETE' &&
        RegExp(r'^/api/v1/resources/[^/]+$').hasMatch(request.uri.path)) {
      await _writeJson(request.response, <String, Object?>{'ok': true});
      return;
    }

    if (request.method == 'DELETE' &&
        RegExp(r'^/api/v1/memos/[^/]+$').hasMatch(request.uri.path)) {
      await _writeJson(request.response, <String, Object?>{'ok': true});
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/api/v1/memos') {
      final state = (request.uri.queryParameters['state'] ?? '')
          .trim()
          .toUpperCase();
      final filter = (request.uri.queryParameters['filter'] ?? '').trim();
      final wantsArchived = state == 'ARCHIVED' || filter.contains('ARCHIVED');
      await _writeJson(request.response, <String, Object?>{
        'memos': wantsArchived || _createdMemo == null
            ? const <Object>[]
            : <Object>[_createdMemo!],
        'nextPageToken': '',
      });
      return;
    }

    await _writeJson(request.response, <String, Object?>{
      'error': 'Unhandled test route',
      'method': request.method,
      'path': request.uri.path,
    }, statusCode: HttpStatus.notFound);
  }

  Map<String, dynamic> _buildMemo({
    required String memoId,
    String content = '',
    Object resources = const <Object>[],
    String visibility = 'PRIVATE',
    bool pinned = false,
  }) {
    return <String, dynamic>{
      'name': 'memos/$memoId',
      'creator': 'users/1',
      'content': content,
      'visibility': visibility,
      'pinned': pinned,
      'state': 'NORMAL',
      'createTime': '2026-03-13T18:00:00Z',
      'updateTime': '2026-03-13T18:00:00Z',
      'tags': const <String>[],
      'resources': resources,
    };
  }
}

Future<void> _writeJson(
  HttpResponse response,
  Object payload, {
  int statusCode = HttpStatus.ok,
}) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(payload));
  await response.close();
}
