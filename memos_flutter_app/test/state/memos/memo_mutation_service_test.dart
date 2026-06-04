import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/state/memos/memo_mutation_service.dart';
import 'package:memos_flutter_app/state/memos/memo_timeline_provider.dart';
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

  test('createQuickInputMemo writes memo and create outbox', () async {
    final dbName = uniqueDbName('memo_mutation_quick_input');
    final db = AppDatabase(dbName: dbName);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await container
        .read(memoMutationServiceProvider)
        .createQuickInputMemo(
          uid: 'memo-quick',
          content: 'hello #quick',
          visibility: 'PRIVATE',
          nowSec: 1735689600,
          tags: const ['quick'],
        );

    final row = await db.getMemoByUid('memo-quick');
    expect(row, isNotNull);
    expect(row!['content'], 'hello #quick');

    final pending = await db.listOutboxPending(limit: 10);
    expect(pending, hasLength(1));
    expect(pending.single['type'], 'create_memo');
    final payload =
        jsonDecode(pending.single['payload'] as String) as Map<String, dynamic>;
    expect(payload['uid'], 'memo-quick');
    expect(payload['content'], 'hello #quick');
  });

  test(
    'updateMemoContent captures version and enqueues remote update',
    () async {
      final dbName = uniqueDbName('memo_mutation_update_content');
      final db = AppDatabase(dbName: dbName);
      final timelineService = MemoTimelineService(
        db: db,
        account: null,
        triggerSync: () async {},
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          memoTimelineServiceProvider.overrideWithValue(timelineService),
        ],
      );

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-update',
        content: 'old content',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1735689600,
        updateTimeSec: 1735689600,
        tags: const ['old'],
        attachments: const [],
        location: null,
        relationCount: 0,
        syncState: 1,
      );
      final before = LocalMemo.fromDb((await db.getMemoByUid('memo-update'))!);

      await container
          .read(memoMutationServiceProvider)
          .updateMemoContent(before, 'new content #fresh');

      final after = await db.getMemoByUid('memo-update');
      expect(after, isNotNull);
      expect(after!['content'], 'new content #fresh');
      expect(after['tags'], contains('fresh'));

      final versions = await db.listMemoVersionsByUid('memo-update');
      expect(versions, hasLength(1));
      expect(versions.single['summary'], contains('old content'));

      final pending = await db.listOutboxPending(limit: 10);
      expect(pending, hasLength(1));
      expect(pending.single['type'], 'update_memo');
      final payload =
          jsonDecode(pending.single['payload'] as String)
              as Map<String, dynamic>;
      expect(payload['uid'], 'memo-update');
      expect(payload['content'], 'new content #fresh');
      expect(payload['update_time'], isA<int>());
    },
  );

  test(
    'preserveUpdateTime content updates do not enqueue update_time',
    () async {
      final dbName = uniqueDbName('memo_mutation_preserve_update_time');
      final db = AppDatabase(dbName: dbName);
      final timelineService = MemoTimelineService(
        db: db,
        account: null,
        triggerSync: () async {},
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          memoTimelineServiceProvider.overrideWithValue(timelineService),
        ],
      );

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-preserve',
        content: 'old task text',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1735689600,
        updateTimeSec: 1735689600,
        tags: const [],
        attachments: const [],
        location: null,
        relationCount: 0,
        syncState: 1,
      );
      final before = LocalMemo.fromDb(
        (await db.getMemoByUid('memo-preserve'))!,
      );

      await container
          .read(memoMutationServiceProvider)
          .updateMemoContent(before, 'new task text', preserveUpdateTime: true);

      final after = LocalMemo.fromDb((await db.getMemoByUid('memo-preserve'))!);
      expect(after.updateTime, before.updateTime);

      final pending = await db.listOutboxPending(limit: 10);
      expect(pending, hasLength(1));
      final payload =
          jsonDecode(pending.single['payload'] as String)
              as Map<String, dynamic>;
      expect(payload['uid'], 'memo-preserve');
      expect(payload.containsKey('update_time'), isFalse);
      expect(payload.containsKey('updateTime'), isFalse);
    },
  );

  test(
    'updateMemoContent refreshes pending create payload instead of enqueuing update',
    () async {
      final dbName = uniqueDbName('memo_mutation_update_pending_create');
      final db = AppDatabase(dbName: dbName);
      final timelineService = MemoTimelineService(
        db: db,
        account: null,
        triggerSync: () async {},
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          memoTimelineServiceProvider.overrideWithValue(timelineService),
        ],
      );

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-create-pending',
        content: '剪藏中...',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1735689600,
        updateTimeSec: 1735689600,
        tags: const ['clipping'],
        attachments: const [],
        location: null,
        relationCount: 0,
        syncState: 1,
      );
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': 'memo-create-pending',
          'content': '剪藏中...',
          'visibility': 'PRIVATE',
          'pinned': false,
          'create_time': 1735689600,
          'display_time': 1735689600,
        },
      );
      final before = LocalMemo.fromDb(
        (await db.getMemoByUid('memo-create-pending'))!,
      );

      await container
          .read(memoMutationServiceProvider)
          .updateMemoContent(before, '# 标题\n\n正文内容');

      final pending = await db.listOutboxPending(limit: 10);
      expect(pending, hasLength(1));
      expect(pending.single['type'], 'create_memo');
      final payload =
          jsonDecode(pending.single['payload'] as String)
              as Map<String, dynamic>;
      expect(payload['uid'], 'memo-create-pending');
      expect(payload['content'], '# 标题\n\n正文内容');
    },
  );
}
