import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
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

  test('retry rebuilds remote missing memo as create_memo', () async {
    final dbName = uniqueDbName('sync_queue_retry_remote_missing');
    final db = AppDatabase(dbName: dbName);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final controller = container.read(syncQueueControllerProvider);
    final now = DateTime.utc(2026, 3, 13, 18, 0);

    addTearDown(() async {
      container.dispose();
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await db.upsertMemo(
      uid: 'memo-remote-missing',
      content: 'memo content',
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
      lastError: 'memo not found on remote server',
    );
    final outboxId = await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': 'memo-remote-missing',
        'content': 'memo content',
        'visibility': 'PRIVATE',
        'pinned': false,
      },
    );
    await db.markOutboxQuarantined(
      outboxId,
      error: 'memo not found',
      failureCode: 'remote_missing_memo',
      failureKind: 'fatal_immediate',
    );

    await controller.retryItem(
      SyncQueueItem(
        id: outboxId,
        type: 'update_memo',
        state: SyncQueueOutboxState.quarantined,
        attempts: 1,
        createdAt: now,
        preview: 'memo content',
        filename: null,
        lastError: 'memo not found',
        memoUid: 'memo-remote-missing',
        attachmentUid: null,
        retryAt: null,
        failureCode: 'remote_missing_memo',
      ),
    );

    final rows = await db.listOutboxByMemoUid('memo-remote-missing');

    expect(rows, hasLength(1));
    expect(rows.single['type'], 'create_memo');
    expect(rows.single['state'], AppDatabase.outboxStatePending);
    final payload = jsonDecode(rows.single['payload'] as String) as Map;
    expect(payload['uid'], 'memo-remote-missing');
    expect(payload['content'], 'memo content');
  });

  test('retry falls back to requeue when memo cannot be rebuilt', () async {
    final dbName = uniqueDbName('sync_queue_retry_missing_local_memo');
    final db = AppDatabase(dbName: dbName);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final controller = container.read(syncQueueControllerProvider);
    final now = DateTime.utc(2026, 3, 13, 18, 0);

    addTearDown(() async {
      container.dispose();
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final outboxId = await db.enqueueOutbox(
      type: 'delete_memo',
      payload: {'uid': 'memo-deleted-locally', 'force': false},
    );
    await db.markOutboxQuarantined(
      outboxId,
      error: 'request rejected',
      failureCode: 'http_client_fatal',
      failureKind: 'fatal_immediate',
    );

    await controller.retryItem(
      SyncQueueItem(
        id: outboxId,
        type: 'delete_memo',
        state: SyncQueueOutboxState.quarantined,
        attempts: 1,
        createdAt: now,
        preview: null,
        filename: null,
        lastError: 'request rejected',
        memoUid: 'memo-deleted-locally',
        attachmentUid: null,
        retryAt: null,
        failureCode: 'http_client_fatal',
      ),
    );

    final rows = await db.listOutboxByMemoUid('memo-deleted-locally');

    expect(rows, hasLength(1));
    expect(rows.single['type'], 'delete_memo');
    expect(rows.single['state'], AppDatabase.outboxStatePending);
    expect(rows.single['failure_code'], isNull);
  });

  test('retry rebuild keeps delete_attachment tasks for local memo', () async {
    final dbName = uniqueDbName('sync_queue_retry_keeps_delete_attachment');
    final db = AppDatabase(dbName: dbName);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final controller = container.read(syncQueueControllerProvider);
    final now = DateTime.utc(2026, 3, 13, 18, 0);

    addTearDown(() async {
      container.dispose();
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await db.upsertMemo(
      uid: 'memo-delete-attachment',
      content: 'memo content',
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
      lastError: 'attachment delete failed',
    );
    final outboxId = await db.enqueueOutbox(
      type: 'delete_attachment',
      payload: {
        'attachment_name': 'resources/att-old',
        'memo_uid': 'memo-delete-attachment',
      },
    );
    await db.markOutboxQuarantined(
      outboxId,
      error: 'server rejected delete',
      failureCode: 'http_client_fatal',
      failureKind: 'fatal_immediate',
    );

    await controller.retryItem(
      SyncQueueItem(
        id: outboxId,
        type: 'delete_attachment',
        state: SyncQueueOutboxState.quarantined,
        attempts: 1,
        createdAt: now,
        preview: null,
        filename: null,
        lastError: 'server rejected delete',
        memoUid: 'memo-delete-attachment',
        attachmentUid: null,
        retryAt: null,
        failureCode: 'http_client_fatal',
      ),
    );

    final rows = await db.listOutboxByMemoUid('memo-delete-attachment');

    expect(rows, hasLength(2));
    expect(
      rows.map((row) => row['type']),
      containsAll(<String>['update_memo', 'delete_attachment']),
    );

    final deleteRow = rows.firstWhere(
      (row) => row['type'] == 'delete_attachment',
    );
    expect(deleteRow['state'], AppDatabase.outboxStatePending);
    expect(deleteRow['failure_code'], isNull);
    final deletePayload = jsonDecode(deleteRow['payload'] as String) as Map;
    expect(deletePayload['attachment_name'], 'resources/att-old');
  });

  test('deleteItem keeps failed create_memo as local-only memo', () async {
    final dbName = uniqueDbName('sync_queue_delete_local_only_create_memo');
    final db = AppDatabase(dbName: dbName);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final controller = container.read(syncQueueControllerProvider);
    final now = DateTime.utc(2026, 4, 2, 3, 0);

    addTearDown(() async {
      container.dispose();
      await db.close();
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

    await controller.deleteItem(
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

    final row = await db.getMemoByUid('memo-local-only');
    expect(row, isNotNull);
    expect(row?['sync_state'], 2);
    expect(isLocalOnlySyncPausedError(row?['last_error'] as String?), isTrue);
    expect(await db.listOutboxByMemoUid('memo-local-only'), isEmpty);
  });

  test(
    'deleteItem marks active create_memo as local-only error instead of pending',
    () async {
      final dbName = uniqueDbName('sync_queue_delete_active_local_only_create');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(syncQueueControllerProvider);
      final now = DateTime.utc(2026, 4, 2, 3, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-active-local-only',
        content: 'memo becomes local only',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );
      final outboxId = await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-active-local-only',
          'content': 'memo becomes local only',
          'visibility': 'PRIVATE',
          'pinned': false,
        },
      );

      await controller.deleteItem(
        SyncQueueItem(
          id: outboxId,
          type: 'create_memo',
          state: SyncQueueOutboxState.pending,
          attempts: 0,
          createdAt: now,
          preview: 'memo becomes local only',
          filename: null,
          lastError: null,
          memoUid: 'memo-active-local-only',
          attachmentUid: null,
          retryAt: null,
          failureCode: null,
        ),
      );

      final row = await db.getMemoByUid('memo-active-local-only');
      expect(row, isNotNull);
      expect(row?['sync_state'], 2);
      expect(isLocalOnlySyncPausedError(row?['last_error'] as String?), isTrue);
      expect(await db.listOutboxByMemoUid('memo-active-local-only'), isEmpty);
    },
  );

  test(
    'deleteItem clears sibling upload tasks for local-only create_memo',
    () async {
      final dbName = uniqueDbName(
        'sync_queue_delete_local_only_create_memo_attachments',
      );
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(syncQueueControllerProvider);
      final now = DateTime.utc(2026, 4, 2, 3, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-local-only-attachments',
        content: 'memo keeps local attachments',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[
          {
            'name': 'attachments/att-local-only',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': 'file:///tmp/sample.png',
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 2,
        lastError: 'content too long (max 8192 characters)',
      );
      final createOutboxId = await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-local-only-attachments',
          'content': 'memo keeps local attachments',
          'visibility': 'PRIVATE',
          'pinned': false,
        },
      );
      await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': 'att-local-only',
          'memo_uid': 'memo-local-only-attachments',
          'file_path': '/tmp/sample.png',
          'filename': 'sample.png',
          'mime_type': 'image/png',
          'file_size': 42,
        },
      );

      await controller.deleteItem(
        SyncQueueItem(
          id: createOutboxId,
          type: 'create_memo',
          state: SyncQueueOutboxState.error,
          attempts: 1,
          createdAt: now,
          preview: 'memo keeps local attachments',
          filename: null,
          lastError: 'content too long (max 8192 characters)',
          memoUid: 'memo-local-only-attachments',
          attachmentUid: null,
          retryAt: null,
          failureCode: 'content_too_long',
        ),
      );

      final row = await db.getMemoByUid('memo-local-only-attachments');
      expect(row, isNotNull);
      expect(row?['sync_state'], 2);
      expect(isLocalOnlySyncPausedError(row?['last_error'] as String?), isTrue);
      expect(
        jsonDecode(row?['attachments_json'] as String) as List,
        hasLength(1),
      );
      expect(
        await db.listOutboxByMemoUid('memo-local-only-attachments'),
        isEmpty,
      );
    },
  );

  test(
    'deleteItem keeps attachment placeholder for local-only upload',
    () async {
      final dbName = uniqueDbName(
        'sync_queue_delete_local_only_upload_attachment',
      );
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(syncQueueControllerProvider);
      final now = DateTime.utc(2026, 4, 2, 3, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-local-only-upload',
        content: 'memo keeps pending upload locally',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[
          {
            'name': 'attachments/att-local-only-upload',
            'filename': 'sample.png',
            'type': 'image/png',
            'size': 42,
            'externalLink': 'file:///tmp/sample.png',
          },
        ],
        location: null,
        relationCount: 0,
        syncState: 2,
        lastError: markLocalOnlySyncPausedError(
          'attachment upload paused for local-only memo',
        ),
      );
      final uploadOutboxId = await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': 'att-local-only-upload',
          'memo_uid': 'memo-local-only-upload',
          'file_path': '/tmp/sample.png',
          'filename': 'sample.png',
          'mime_type': 'image/png',
          'file_size': 42,
        },
      );

      await controller.deleteItem(
        SyncQueueItem(
          id: uploadOutboxId,
          type: 'upload_attachment',
          state: SyncQueueOutboxState.error,
          attempts: 1,
          createdAt: now,
          preview: 'memo keeps pending upload locally',
          filename: 'sample.png',
          lastError: 'file missing',
          memoUid: 'memo-local-only-upload',
          attachmentUid: 'att-local-only-upload',
          retryAt: null,
          failureCode: 'file_not_found',
        ),
      );

      final row = await db.getMemoByUid('memo-local-only-upload');
      expect(row, isNotNull);
      expect(isLocalOnlySyncPausedError(row?['last_error'] as String?), isTrue);
      expect(
        jsonDecode(row?['attachments_json'] as String) as List,
        hasLength(1),
      );
      expect(await db.listOutboxByMemoUid('memo-local-only-upload'), isEmpty);
    },
  );
}
