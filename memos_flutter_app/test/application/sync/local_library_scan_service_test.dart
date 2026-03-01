import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/local_library_scan_service.dart';
import 'package:memos_flutter_app/application/sync/sync_types.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/local_library/local_attachment_store.dart';
import 'package:memos_flutter_app/data/local_library/local_library_fs.dart';
import 'package:memos_flutter_app/data/local_library/local_library_markdown.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';

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
    await fs.writeMemo(
      uid: uid,
      content: buildLocalLibraryMarkdown(diskMemo),
    );

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
    await fs.writeMemo(
      uid: uid,
      content: buildLocalLibraryMarkdown(diskMemo),
    );

    final service = LocalLibraryScanService(
      db: db,
      fileSystem: fs,
      attachmentStore: LocalAttachmentStore(),
    );

    final result = await service.scanAndMerge(
      conflictDecisions: {uid: true},
    );

    expect(result, isA<LocalScanSuccess>());
    final row = await db.getMemoByUid(uid);
    expect(row?['content'], 'disk content updated');
    expect(row?['sync_state'], 0);

    await db.close();
    await deleteTestDatabase(dbName);
    await Directory(libraryDir.path).delete(recursive: true);
  });
}
