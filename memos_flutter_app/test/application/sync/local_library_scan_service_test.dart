import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/local_library_scan_service.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/core/memo_relations.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/local_library/local_attachment_store.dart';
import 'package:memos_flutter_app/data/local_library/local_library_fs.dart';
import 'package:memos_flutter_app/data/local_library/local_library_markdown.dart';
import 'package:memos_flutter_app/data/local_library/local_library_memo_sidecar.dart';
import 'package:memos_flutter_app/data/local_library/local_library_paths.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/data/models/memo_relation.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test('detects conflicts without decisions', () async {
    final dbName = uniqueDbName('local_scan_conflict');
    final db = AppDatabase(dbName: dbName);
    final libraryDir = await support.createTempDir('library');
    final library = LocalLibrary(
      key: 'local',
      name: 'Local',
      rootPath: libraryDir.path,
    );
    final fs = LocalLibraryFileSystem(library);
    await fs.ensureStructure();

    final uid = 'memo-1';
    final created = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final updated = created;
    await db.upsertMemo(
      uid: uid,
      content: 'db content',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTimeSec: created.millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: updated.millisecondsSinceEpoch ~/ 1000,
      tags: const [],
      attachments: const [],
      location: null,
      relationCount: 0,
      syncState: 1,
      lastError: null,
    );

    final diskMemo = LocalMemo(
      uid: uid,
      content: 'disk content',
      contentFingerprint: computeContentFingerprint('disk content'),
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: created,
      updateTime: DateTime.now().toUtc(),
      tags: const [],
      attachments: const [],
      relationCount: 0,
      location: null,
      syncState: SyncState.synced,
      lastError: null,
    );
    await fs.writeMemo(uid: uid, content: buildLocalLibraryMarkdown(diskMemo));

    final service = LocalLibraryScanService(
      db: db,
      fileSystem: fs,
      attachmentStore: LocalAttachmentStore(),
    );

    final result = await service.scanAndMerge();

    expect(result, isA<LocalScanConflictResult>());
    final conflicts = (result as LocalScanConflictResult).conflicts;
    expect(conflicts.any((c) => c.memoUid == uid && !c.isDeletion), isTrue);

    await db.close();
    await deleteTestDatabase(dbName);
    await Directory(libraryDir.path).delete(recursive: true);
  });

  test('applies conflict decisions to update db', () async {
    final dbName = uniqueDbName('local_scan_apply');
    final db = AppDatabase(dbName: dbName);
    final libraryDir = await support.createTempDir('library');
    final library = LocalLibrary(
      key: 'local',
      name: 'Local',
      rootPath: libraryDir.path,
    );
    final fs = LocalLibraryFileSystem(library);
    await fs.ensureStructure();

    final uid = 'memo-2';
    final created = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final updated = created;
    await db.upsertMemo(
      uid: uid,
      content: 'db content',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTimeSec: created.millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: updated.millisecondsSinceEpoch ~/ 1000,
      tags: const [],
      attachments: const [],
      location: null,
      relationCount: 0,
      syncState: 1,
      lastError: null,
    );

    final diskMemo = LocalMemo(
      uid: uid,
      content: 'disk content updated',
      contentFingerprint: computeContentFingerprint('disk content updated'),
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: created,
      updateTime: DateTime.now().toUtc(),
      tags: const [],
      attachments: const [],
      relationCount: 0,
      location: null,
      syncState: SyncState.synced,
      lastError: null,
    );
    await fs.writeMemo(uid: uid, content: buildLocalLibraryMarkdown(diskMemo));

    final service = LocalLibraryScanService(
      db: db,
      fileSystem: fs,
      attachmentStore: LocalAttachmentStore(),
    );

    final result = await service.scanAndMerge(conflictDecisions: {uid: true});

    expect(result, isA<LocalScanSuccess>());
    final row = await db.getMemoByUid(uid);
    expect(row?['content'], 'disk content updated');
    expect(row?['sync_state'], 0);

    await db.close();
    await deleteTestDatabase(dbName);
    await Directory(libraryDir.path).delete(recursive: true);
  });

  test('scans memos from a managed private workspace', () async {
    final dbName = uniqueDbName('local_scan_managed_private');
    final db = AppDatabase(dbName: dbName);
    final library = LocalLibrary(
      key: 'managed_private_workspace',
      name: 'Managed Private Workspace',
      storageKind: LocalLibraryStorageKind.managedPrivate,
      rootPath: await resolveManagedWorkspacePath('managed_private_workspace'),
    );
    final fs = LocalLibraryFileSystem(library);
    await fs.ensureStructure();

    final uid = 'memo-managed-private';
    final created = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final diskMemo = LocalMemo(
      uid: uid,
      content: 'managed private content',
      contentFingerprint: computeContentFingerprint('managed private content'),
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: created,
      updateTime: DateTime.now().toUtc(),
      tags: const [],
      attachments: const [],
      relationCount: 0,
      location: null,
      syncState: SyncState.synced,
      lastError: null,
    );
    await fs.writeMemo(uid: uid, content: buildLocalLibraryMarkdown(diskMemo));

    final service = LocalLibraryScanService(
      db: db,
      fileSystem: fs,
      attachmentStore: LocalAttachmentStore(),
    );

    final result = await service.scanAndMerge(forceDisk: true);

    expect(result, isA<LocalScanSuccess>());
    final row = await db.getMemoByUid(uid);
    expect(row?['content'], 'managed private content');
    expect(row?['sync_state'], 0);

    await db.close();
    await deleteTestDatabase(dbName);
  });

  test('imports sidecar display time, location and relations', () async {
    final dbName = uniqueDbName('local_scan_sidecar_import');
    final db = AppDatabase(dbName: dbName);
    final libraryDir = await support.createTempDir('library');
    final library = LocalLibrary(
      key: 'local',
      name: 'Local',
      rootPath: libraryDir.path,
    );
    final fs = LocalLibraryFileSystem(library);
    await fs.ensureStructure();

    final uid = 'memo-sidecar';
    final created = DateTime.utc(2026, 1, 1, 8);
    final displayTime = DateTime.utc(2026, 1, 2, 9);
    final updated = DateTime.utc(2026, 1, 3, 10);
    final diskMemo = LocalMemo(
      uid: uid,
      content: 'disk content [[memo-2]]',
      contentFingerprint: computeContentFingerprint('disk content [[memo-2]]'),
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: created,
      displayTime: displayTime,
      updateTime: updated,
      tags: const <String>['tag-a'],
      attachments: const [],
      relationCount: 1,
      location: const MemoLocation(
        placeholder: 'Beijing',
        latitude: 39.9042,
        longitude: 116.4074,
      ),
      syncState: SyncState.synced,
      lastError: null,
    );
    await fs.writeMemo(uid: uid, content: buildLocalLibraryMarkdown(diskMemo));
    await fs.writeMemoSidecar(
      uid: uid,
      content: LocalLibraryMemoSidecar.fromMemo(
        memo: diskMemo,
        hasRelations: true,
        relations: const <MemoRelation>[
          MemoRelation(
            memo: MemoRelationMemo(
              name: 'memos/memo-sidecar',
              snippet: 'disk content',
            ),
            relatedMemo: MemoRelationMemo(
              name: 'memos/memo-2',
              snippet: 'memo two',
            ),
            type: 'REFERENCE',
          ),
        ],
        attachments: const <LocalLibraryAttachmentExportMeta>[],
      ).encodeJson(),
    );

    final service = LocalLibraryScanService(
      db: db,
      fileSystem: fs,
      attachmentStore: LocalAttachmentStore(),
    );

    final result = await service.scanAndMerge(forceDisk: true);

    expect(result, isA<LocalScanSuccess>());
    final row = await db.getMemoByUid(uid);
    expect(row?['display_time'], displayTime.millisecondsSinceEpoch ~/ 1000);
    expect(row?['location_placeholder'], 'Beijing');
    expect(row?['relation_count'], 1);
    final relationsJson = await db.getMemoRelationsCacheJson(uid);
    expect(
      decodeMemoRelationsJson(relationsJson ?? '').single.relatedMemo.name,
      'memos/memo-2',
    );

    await db.close();
    await deleteTestDatabase(dbName);
    await Directory(libraryDir.path).delete(recursive: true);
  });

  test(
    'preserves existing structured fields when sidecar is missing',
    () async {
      final dbName = uniqueDbName('local_scan_sidecar_preserve');
      final db = AppDatabase(dbName: dbName);
      final libraryDir = await support.createTempDir('library');
      final library = LocalLibrary(
        key: 'local',
        name: 'Local',
        rootPath: libraryDir.path,
      );
      final fs = LocalLibraryFileSystem(library);
      await fs.ensureStructure();

      final uid = 'memo-preserve';
      final created = DateTime.utc(2026, 2, 1, 8);
      final displayTime = DateTime.utc(2026, 2, 2, 9);
      final updated = DateTime.utc(2026, 2, 3, 10);
      await db.upsertMemo(
        uid: uid,
        content: 'db content',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: created.millisecondsSinceEpoch ~/ 1000,
        displayTimeSec: displayTime.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: created.millisecondsSinceEpoch ~/ 1000,
        tags: const [],
        attachments: const [],
        location: const MemoLocation(
          placeholder: 'Shanghai',
          latitude: 31.2304,
          longitude: 121.4737,
        ),
        relationCount: 1,
        syncState: 0,
        lastError: null,
      );
      await db.upsertMemoRelationsCache(
        uid,
        relationsJson: encodeMemoRelationsJson(const <MemoRelation>[
          MemoRelation(
            memo: MemoRelationMemo(
              name: 'memos/memo-preserve',
              snippet: 'db content',
            ),
            relatedMemo: MemoRelationMemo(
              name: 'memos/memo-3',
              snippet: 'memo three',
            ),
            type: 'REFERENCE',
          ),
        ]),
      );

      final diskMemo = LocalMemo(
        uid: uid,
        content: 'disk content updated',
        contentFingerprint: computeContentFingerprint('disk content updated'),
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTime: created,
        updateTime: updated,
        tags: const [],
        attachments: const [],
        relationCount: 0,
        location: null,
        syncState: SyncState.synced,
        lastError: null,
      );
      await fs.writeMemo(
        uid: uid,
        content: buildLocalLibraryMarkdown(diskMemo),
      );

      final service = LocalLibraryScanService(
        db: db,
        fileSystem: fs,
        attachmentStore: LocalAttachmentStore(),
      );

      final result = await service.scanAndMerge(forceDisk: true);

      expect(result, isA<LocalScanSuccess>());
      final row = await db.getMemoByUid(uid);
      expect(row?['content'], 'disk content updated');
      expect(row?['display_time'], displayTime.millisecondsSinceEpoch ~/ 1000);
      expect(row?['location_placeholder'], 'Shanghai');
      expect(row?['relation_count'], 1);
      final relationsJson = await db.getMemoRelationsCacheJson(uid);
      expect(
        decodeMemoRelationsJson(relationsJson ?? '').single.relatedMemo.name,
        'memos/memo-3',
      );

      await db.close();
      await deleteTestDatabase(dbName);
      await Directory(libraryDir.path).delete(recursive: true);
    },
  );

  test(
    'explicit empty relations in sidecar clear stale relation cache',
    () async {
      final dbName = uniqueDbName('local_scan_sidecar_clear_relations');
      final db = AppDatabase(dbName: dbName);
      final libraryDir = await support.createTempDir('library');
      final library = LocalLibrary(
        key: 'local',
        name: 'Local',
        rootPath: libraryDir.path,
      );
      final fs = LocalLibraryFileSystem(library);
      await fs.ensureStructure();

      final uid = 'memo-clear-relations';
      final created = DateTime.utc(2026, 4, 1, 8);
      final updated = DateTime.utc(2026, 4, 1, 9);

      await db.upsertMemo(
        uid: uid,
        content: 'db content [[memo-3]]',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: created.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: created.millisecondsSinceEpoch ~/ 1000,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 1,
        syncState: 0,
      );
      await db.upsertMemoRelationsCache(
        uid,
        relationsJson: encodeMemoRelationsJson(const <MemoRelation>[
          MemoRelation(
            memo: MemoRelationMemo(
              name: 'memos/memo-clear-relations',
              snippet: 'db content',
            ),
            relatedMemo: MemoRelationMemo(
              name: 'memos/memo-3',
              snippet: 'memo three',
            ),
            type: 'REFERENCE',
          ),
        ]),
      );

      final diskMemo = LocalMemo(
        uid: uid,
        content: 'disk content updated',
        contentFingerprint: computeContentFingerprint('disk content updated'),
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTime: created,
        updateTime: updated,
        tags: const <String>[],
        attachments: const <Attachment>[],
        relationCount: 0,
        location: null,
        syncState: SyncState.synced,
        lastError: null,
      );
      await fs.writeMemo(
        uid: uid,
        content: buildLocalLibraryMarkdown(diskMemo),
      );
      await fs.writeMemoSidecar(
        uid: uid,
        content: LocalLibraryMemoSidecar.fromMemo(
          memo: diskMemo,
          hasRelations: true,
          relations: const <MemoRelation>[],
          attachments: const <LocalLibraryAttachmentExportMeta>[],
        ).encodeJson(),
      );

      final service = LocalLibraryScanService(
        db: db,
        fileSystem: fs,
        attachmentStore: LocalAttachmentStore(),
      );

      final result = await service.scanAndMerge(forceDisk: true);

      expect(result, isA<LocalScanSuccess>());
      final row = await db.getMemoByUid(uid);
      expect(row?['relation_count'], 0);
      final relationsJson = await db.getMemoRelationsCacheJson(uid);
      expect(decodeMemoRelationsJson(relationsJson ?? ''), isEmpty);

      await db.close();
      await deleteTestDatabase(dbName);
      await Directory(libraryDir.path).delete(recursive: true);
    },
  );

  test(
    'incomplete sidecar relation metadata preserves cached relations and count',
    () async {
      final dbName = uniqueDbName('local_scan_sidecar_incomplete_relations');
      final db = AppDatabase(dbName: dbName);
      final libraryDir = await support.createTempDir('library');
      final library = LocalLibrary(
        key: 'local',
        name: 'Local',
        rootPath: libraryDir.path,
      );
      final fs = LocalLibraryFileSystem(library);
      await fs.ensureStructure();

      final uid = 'memo-incomplete-relations';
      final created = DateTime.utc(2026, 4, 2, 8);
      final updated = DateTime.utc(2026, 4, 2, 9);

      await db.upsertMemo(
        uid: uid,
        content: 'db content [[memo-3]]',
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: created.millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: created.millisecondsSinceEpoch ~/ 1000,
        tags: const <String>[],
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 1,
        syncState: 0,
      );
      await db.upsertMemoRelationsCache(
        uid,
        relationsJson: encodeMemoRelationsJson(const <MemoRelation>[
          MemoRelation(
            memo: MemoRelationMemo(
              name: 'memos/memo-incomplete-relations',
              snippet: 'db content',
            ),
            relatedMemo: MemoRelationMemo(
              name: 'memos/memo-3',
              snippet: 'memo three',
            ),
            type: 'REFERENCE',
          ),
        ]),
      );

      final diskMemo = LocalMemo(
        uid: uid,
        content: 'disk content updated',
        contentFingerprint: computeContentFingerprint('disk content updated'),
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTime: created,
        updateTime: updated,
        tags: const <String>[],
        attachments: const <Attachment>[],
        relationCount: 2,
        location: null,
        syncState: SyncState.synced,
        lastError: null,
      );
      await fs.writeMemo(
        uid: uid,
        content: buildLocalLibraryMarkdown(diskMemo),
      );
      await fs.writeMemoSidecar(
        uid: uid,
        content: LocalLibraryMemoSidecar(
          schemaVersion: localLibraryMemoSidecarSchemaVersion,
          memoUid: uid,
          contentFingerprint: diskMemo.contentFingerprint,
          relations: const <MemoRelation>[],
          relationCount: 2,
          relationsComplete: false,
          hasRelations: true,
        ).encodeJson(),
      );

      final service = LocalLibraryScanService(
        db: db,
        fileSystem: fs,
        attachmentStore: LocalAttachmentStore(),
      );

      final result = await service.scanAndMerge(forceDisk: true);

      expect(result, isA<LocalScanSuccess>());
      final row = await db.getMemoByUid(uid);
      expect(row?['relation_count'], 2);
      final relationsJson = await db.getMemoRelationsCacheJson(uid);
      final cachedRelations = decodeMemoRelationsJson(relationsJson ?? '');
      expect(cachedRelations, hasLength(1));
      expect(cachedRelations.single.relatedMemo.name, 'memos/memo-3');

      await db.close();
      await deleteTestDatabase(dbName);
      await Directory(libraryDir.path).delete(recursive: true);
    },
  );
}
