import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/queued_attachment_stager.dart';
import 'package:memos_flutter_app/application/sync/sync_error.dart';
import 'package:memos_flutter_app/core/memo_relations.dart';
import 'package:memos_flutter_app/data/api/memo_api_facade.dart';
import 'package:memos_flutter_app/data/api/memo_api_version.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/features/share/share_inline_image_content.dart';
import 'package:memos_flutter_app/state/memos/create_memo_outbox_payload.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
import 'package:memos_flutter_app/state/memos/note_input_providers.dart';
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

  Future<File> createAttachmentFile(String prefix) async {
    final dir = await support.createTempDir(prefix);
    final file = File('${dir.path}${Platform.pathSeparator}sample.png');
    await file.writeAsBytes(const <int>[137, 80, 78, 71, 1, 2, 3, 4]);
    return file;
  }

  bool isManagedPath(String path) {
    return path.contains(QueuedAttachmentStager.managedRootDirName);
  }

  test('buildCreateMemoOutboxPayload preserves local create time', () {
    final payload = buildCreateMemoOutboxPayload(
      uid: 'memo-1',
      content: 'hello',
      visibility: 'PRIVATE',
      pinned: false,
      createTimeSec: 1710352800,
      hasAttachments: true,
      location: const MemoLocation(
        placeholder: 'home',
        latitude: 1.23,
        longitude: 4.56,
      ),
      relations: const [
        {'relatedMemoId': 'memo-2', 'type': 'REFERENCE'},
      ],
    );

    expect(payload['create_time'], 1710352800);
    expect(payload['display_time'], 1710352800);
    expect(payload['has_attachments'], isTrue);
    expect(payload['location'], isA<Map<String, dynamic>>());
    expect(payload['relations'], isA<List<dynamic>>());
  });

  test('buildCreateMemoOutboxPayload preserves explicit display time', () {
    final payload = buildCreateMemoOutboxPayload(
      uid: 'memo-2',
      content: 'hello',
      visibility: 'PRIVATE',
      pinned: false,
      createTimeSec: 1710352800,
      displayTimeSec: 1710439200,
      hasAttachments: false,
    );

    expect(payload['create_time'], 1710352800);
    expect(payload['display_time'], 1710439200);
  });

  test('NoteInputController enqueues create_memo with create_time', () async {
    final dbName = uniqueDbName('note_input_display_time');
    final db = AppDatabase(dbName: dbName);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final controller = container.read(noteInputControllerProvider);
    final now = DateTime.utc(2026, 3, 13, 18, 0);

    addTearDown(() async {
      container.dispose();
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await controller.createMemo(
      uid: 'memo-1',
      content: 'offline memo',
      visibility: 'PRIVATE',
      now: now,
      tags: const <String>[],
      attachments: const <Map<String, dynamic>>[],
      location: null,
      hasAttachments: false,
      relations: const <Map<String, dynamic>>[],
      pendingAttachments: const [],
    );

    final outbox = await db.listOutboxPendingByType('create_memo');
    expect(outbox, hasLength(1));

    final payload =
        jsonDecode(outbox.single['payload'] as String) as Map<String, dynamic>;
    expect(payload['uid'], 'memo-1');
    expect(payload['create_time'], now.millisecondsSinceEpoch ~/ 1000);
    expect(payload['display_time'], now.millisecondsSinceEpoch ~/ 1000);
  });

  test('NoteInputController stores local relations in cache', () async {
    final dbName = uniqueDbName('note_input_relations_cache');
    final db = AppDatabase(dbName: dbName);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final controller = container.read(noteInputControllerProvider);
    final now = DateTime.utc(2026, 3, 13, 18, 0);

    addTearDown(() async {
      container.dispose();
      await db.close();
      await deleteTestDatabase(dbName);
    });

    await controller.createMemo(
      uid: 'memo-1',
      content: 'offline memo [[memo-2]]',
      visibility: 'PRIVATE',
      now: now,
      tags: const <String>[],
      attachments: const <Map<String, dynamic>>[],
      location: null,
      hasAttachments: false,
      relations: const <Map<String, dynamic>>[
        {
          'relatedMemo': {'name': 'memos/memo-2', 'snippet': 'memo two'},
          'type': 'REFERENCE',
        },
      ],
      pendingAttachments: const [],
    );

    final row = await db.getMemoByUid('memo-1');
    expect(row, isNotNull);
    expect(row?['relation_count'], 1);

    final relationsJson = await db.getMemoRelationsCacheJson('memo-1');
    final cachedRelations = decodeMemoRelationsJson(relationsJson ?? '');
    expect(cachedRelations, hasLength(1));
    expect(cachedRelations.single.memo.name, 'memos/memo-1');
    expect(cachedRelations.single.memo.snippet, 'offline memo [[memo-2]]');
    expect(cachedRelations.single.relatedMemo.name, 'memos/memo-2');
  });

  test(
    'NoteInputController uses syncContent for create_memo payload',
    () async {
      final dbName = uniqueDbName('note_input_sync_content');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);
      final now = DateTime.utc(2026, 3, 13, 18, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      await controller.createMemo(
        uid: 'memo-1',
        content: 'local-content',
        syncContent: 'remote-content',
        visibility: 'PRIVATE',
        now: now,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        hasAttachments: false,
        relations: const <Map<String, dynamic>>[],
        pendingAttachments: const [],
      );

      final row = await db.getMemoByUid('memo-1');
      expect(row, isNotNull);
      expect(row!['content'], 'local-content');

      final outbox = await db.listOutboxPendingByType('create_memo');
      final payload =
          jsonDecode(outbox.single['payload'] as String)
              as Map<String, dynamic>;
      expect(payload['content'], 'remote-content');
    },
  );

  test(
    'NoteInputController enqueues upload_attachment with skip_compression',
    () async {
      final dbName = uniqueDbName('note_input_skip_compression');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);
      final now = DateTime.utc(2026, 3, 13, 18, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_skip_compression',
      );

      await controller.createMemo(
        uid: 'memo-1',
        content: 'offline memo',
        visibility: 'PRIVATE',
        now: now,
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
            skipCompression: true,
          ),
        ],
      );

      final outbox = await db.listOutboxPendingByType('upload_attachment');
      expect(outbox, hasLength(1));

      final payload =
          jsonDecode(outbox.single['payload'] as String)
              as Map<String, dynamic>;
      expect(payload['uid'], 'att-1');
      expect(payload['memo_uid'], 'memo-1');
      expect(payload['skip_compression'], isTrue);
      expect(payload['file_path'], isA<String>());
      expect(isManagedPath(payload['file_path'] as String), isTrue);
      expect(payload['file_size'], await attachmentFile.length());
    },
  );

  test(
    'NoteInputController enqueues attachments before create_memo on 0.23+',
    () async {
      final dbName = uniqueDbName('note_input_uploads_before_create_v023');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: Uri.parse('https://example.com'),
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          memosApiProvider.overrideWithValue(api),
        ],
      );
      final controller = container.read(noteInputControllerProvider);
      final now = DateTime.utc(2026, 3, 13, 18, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_uploads_before_create_v023',
      );

      await controller.createMemo(
        uid: 'memo-1',
        content: 'offline memo',
        visibility: 'PRIVATE',
        now: now,
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

      final outbox = await db.listOutboxPending(limit: 10);
      expect(outbox.map((row) => row['type']).toList(growable: false), [
        'upload_attachment',
        'create_memo',
      ]);
    },
  );

  test(
    'NoteInputController keeps create_memo before attachments on 0.22',
    () async {
      final dbName = uniqueDbName('note_input_create_before_upload_v022');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: Uri.parse('https://example.com'),
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v022,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          memosApiProvider.overrideWithValue(api),
        ],
      );
      final controller = container.read(noteInputControllerProvider);
      final now = DateTime.utc(2026, 3, 13, 18, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_create_before_upload_v022',
      );

      await controller.createMemo(
        uid: 'memo-1',
        content: 'offline memo',
        visibility: 'PRIVATE',
        now: now,
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

      final outbox = await db.listOutboxPending(limit: 10);
      expect(outbox.map((row) => row['type']).toList(growable: false), [
        'create_memo',
        'upload_attachment',
      ]);
    },
  );

  test(
    'NoteInputController marks share inline image attachment payload',
    () async {
      final dbName = uniqueDbName('note_input_share_inline_payload');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);
      final now = DateTime.utc(2026, 3, 13, 18, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_share_inline_payload',
      );

      await controller.createMemo(
        uid: 'memo-1',
        content: 'offline memo',
        visibility: 'PRIVATE',
        now: now,
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
            shareInlineImage: true,
            fromThirdPartyShare: true,
          ),
        ],
      );

      final outbox = await db.listOutboxPendingByType('upload_attachment');
      final payload =
          jsonDecode(outbox.single['payload'] as String)
              as Map<String, dynamic>;
      expect(payload['share_inline_image'], isTrue);
      expect(payload['from_third_party_share'], isTrue);
      expect(isManagedPath(payload['file_path'] as String), isTrue);
      expect(
        payload['share_inline_local_url'],
        Uri.file(payload['file_path'] as String).toString(),
      );
    },
  );

  test(
    'NoteInputController stores third-party inline image source mapping',
    () async {
      final dbName = uniqueDbName('note_input_inline_image_source_mapping');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);
      final now = DateTime.utc(2026, 3, 13, 18, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_inline_image_source_mapping',
      );
      final localUrl = Uri.file(attachmentFile.path).toString();

      await controller.createMemo(
        uid: 'memo-1',
        content: "<img src=\"$localUrl\">",
        visibility: 'PRIVATE',
        now: now,
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
            shareInlineImage: true,
            fromThirdPartyShare: true,
            sourceUrl: 'https://example.com/sample.png',
          ),
        ],
      );

      final sources = await db.listMemoInlineImageSources('memo-1');
      expect(sources, hasLength(1));
      expect(sources.values.single, 'https://example.com/sample.png');
      expect(
        isManagedPath(Uri.parse(sources.keys.single).toFilePath()),
        isTrue,
      );
    },
  );

  test(
    'appendDeferredThirdPartyShareInlineImage enqueues attachment-aware outbox items',
    () async {
      final dbName = uniqueDbName('note_input_append_inline_image_outbox');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_append_inline_image_outbox',
      );

      await db.upsertMemo(
        uid: 'memo-1',
        content: '<img src="https://example.com/sample.png">',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1,
        updateTimeSec: 1,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );

      await controller.appendDeferredThirdPartyShareInlineImage(
        memoUid: 'memo-1',
        sourceUrl: 'https://example.com/sample.png',
        attachment: NoteInputPendingAttachment(
          uid: 'att-1',
          filePath: attachmentFile.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          size: await attachmentFile.length(),
          shareInlineImage: true,
          fromThirdPartyShare: true,
          sourceUrl: 'https://example.com/sample.png',
        ),
      );

      final outbox = await db.listOutboxByMemoUid('memo-1');
      expect(outbox, hasLength(2));
      expect(
        outbox.map((row) => row['type']).toList(growable: false),
        <Object?>['update_memo', 'upload_attachment'],
      );

      final updatePayload =
          jsonDecode(outbox.first['payload'] as String) as Map<String, dynamic>;
      final uploadPayload =
          jsonDecode(outbox.last['payload'] as String) as Map<String, dynamic>;

      expect(updatePayload['uid'], 'memo-1');
      expect(updatePayload['has_pending_attachments'], isTrue);
      expect(uploadPayload['memo_uid'], 'memo-1');
      expect(uploadPayload['uid'], 'att-1');
    },
  );

  test(
    'appendDeferredThirdPartyShareInlineImage stores source mapping',
    () async {
      final dbName = uniqueDbName('note_input_append_inline_image_source');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_append_inline_image_source',
      );

      await db.upsertMemo(
        uid: 'memo-1',
        content: '<img src="https://example.com/sample.png">',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1,
        updateTimeSec: 1,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );

      await controller.appendDeferredThirdPartyShareInlineImage(
        memoUid: 'memo-1',
        sourceUrl: 'https://example.com/sample.png',
        attachment: NoteInputPendingAttachment(
          uid: 'att-1',
          filePath: attachmentFile.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          size: await attachmentFile.length(),
          shareInlineImage: true,
          fromThirdPartyShare: true,
          sourceUrl: 'https://example.com/sample.png',
        ),
      );

      final sources = await db.listMemoInlineImageSources('memo-1');
      expect(sources, hasLength(1));
      expect(sources.values.single, 'https://example.com/sample.png');
      expect(
        isManagedPath(Uri.parse(sources.keys.single).toFilePath()),
        isTrue,
      );
    },
  );

  test(
    'appendDeferredThirdPartyShareInlineImage stages already-downloaded local urls into upload queue',
    () async {
      final dbName = uniqueDbName('note_input_append_downloaded_local_url');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });
      final attachmentFile = await createAttachmentFile(
        'note_input_append_downloaded_local_url',
      );
      final originalLocalUrl = shareInlineLocalUrlFromPath(attachmentFile.path);

      await db.upsertMemo(
        uid: 'memo-1',
        content: '<img src="$originalLocalUrl">',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: 1,
        updateTimeSec: 1,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
        lastError: null,
      );

      await controller.appendDeferredThirdPartyShareInlineImage(
        memoUid: 'memo-1',
        sourceUrl: 'https://example.com/sample.png',
        attachment: NoteInputPendingAttachment(
          uid: 'att-1',
          filePath: attachmentFile.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          size: await attachmentFile.length(),
          shareInlineImage: true,
          fromThirdPartyShare: true,
          sourceUrl: 'https://example.com/sample.png',
        ),
      );

      final row = await db.getMemoByUid('memo-1');
      expect(row, isNotNull);
      final updatedContent = row?['content'] as String? ?? '';
      expect(updatedContent, isNot(contains(originalLocalUrl)));

      final attachmentsJson = jsonDecode(
        row?['attachments_json'] as String? ?? '[]',
      ) as List<dynamic>;
      expect(attachmentsJson, hasLength(1));
      final stagedLocalUrl =
          attachmentsJson.single['externalLink'] as String? ?? '';
      expect(stagedLocalUrl, isNotEmpty);
      expect(stagedLocalUrl, isNot(originalLocalUrl));
      expect(updatedContent, contains(stagedLocalUrl));

      final outbox = await db.listOutboxByMemoUid('memo-1');
      expect(outbox, hasLength(2));
      expect(
        outbox.map((row) => row['type']).toList(growable: false),
        <Object?>['update_memo', 'upload_attachment'],
      );

      final sources = await db.listMemoInlineImageSources('memo-1');
      expect(sources[stagedLocalUrl], 'https://example.com/sample.png');
    },
  );

  test(
    'appendDeferredThirdPartyShareInlineImage keeps local-only paused memo out of sync queue',
    () async {
      final dbName = uniqueDbName('note_input_append_local_only_paused');
      final db = AppDatabase(dbName: dbName);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(noteInputControllerProvider);
      final attachmentFile = await createAttachmentFile(
        'note_input_append_local_only_paused',
      );
      const sourceUrl = 'https://example.com/sample.png';
      final now = DateTime.utc(2026, 4, 2, 3, 0);

      addTearDown(() async {
        container.dispose();
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await db.upsertMemo(
        uid: 'memo-local-only-inline',
        content: '<img src="$sourceUrl">',
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
        lastError: markLocalOnlySyncPausedError(
          'memo stays local after create failure',
        ),
      );

      await controller.appendDeferredThirdPartyShareInlineImage(
        memoUid: 'memo-local-only-inline',
        sourceUrl: sourceUrl,
        attachment: NoteInputPendingAttachment(
          uid: 'att-local-only-inline',
          filePath: attachmentFile.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          size: await attachmentFile.length(),
          shareInlineImage: true,
          fromThirdPartyShare: true,
          sourceUrl: sourceUrl,
        ),
      );

      final row = await db.getMemoByUid('memo-local-only-inline');
      expect(row, isNotNull);
      expect(row?['sync_state'], 2);
      expect(isLocalOnlySyncPausedError(row?['last_error'] as String?), isTrue);
      expect(row?['content'] as String, isNot(contains(sourceUrl)));
      expect(
        jsonDecode(row?['attachments_json'] as String) as List<dynamic>,
        hasLength(1),
      );
      expect(await db.listOutboxByMemoUid('memo-local-only-inline'), isEmpty);
    },
  );
}
