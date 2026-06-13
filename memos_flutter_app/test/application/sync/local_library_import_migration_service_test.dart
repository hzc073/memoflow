import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:memos_flutter_app/application/sync/local_library_import_migration_service.dart';
import 'package:memos_flutter_app/core/debug_ephemeral_storage.dart';
import 'package:memos_flutter_app/data/local_library/local_library_fs.dart';
import 'package:memos_flutter_app/data/local_library/local_library_markdown.dart';
import 'package:memos_flutter_app/data/local_library/local_library_paths.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';

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
    'migrates an external legacy library into managed private storage',
    () async {
      final sourceDir = await support.createTempDir('legacy_library');
      final sourceLibrary = LocalLibrary(
        key: 'legacy_workspace',
        name: 'Legacy Workspace',
        rootPath: sourceDir.path,
      );
      final sourceFs = LocalLibraryFileSystem(sourceLibrary);
      await sourceFs.ensureStructure();

      final uid = 'memo-legacy';
      final memo = LocalMemo(
        uid: uid,
        content: 'legacy memo content',
        contentFingerprint: computeContentFingerprint('legacy memo content'),
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTime: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        updateTime: DateTime.now().toUtc(),
        tags: const [],
        attachments: const [],
        relationCount: 0,
        location: null,
        syncState: SyncState.synced,
        lastError: null,
      );
      await sourceFs.writeMemo(
        uid: uid,
        content: buildLocalLibraryMarkdown(memo),
      );

      final attachmentSourceDir = await support.createTempDir(
        'legacy_attachment',
      );
      final attachmentSource = File(
        p.join(attachmentSourceDir.path, 'cover.png'),
      );
      await attachmentSource.writeAsBytes(const [1, 2, 3, 4, 5]);
      await sourceFs.writeAttachmentFromFile(
        memoUid: uid,
        filename: 'cover.png',
        srcPath: attachmentSource.path,
        mimeType: 'image/png',
      );

      final migrated = await LocalLibraryImportMigrationService()
          .migrateIfNeeded(sourceLibrary);
      final supportDir = await resolveAppSupportDirectory();
      final targetFs = LocalLibraryFileSystem(migrated);

      expect(migrated.storageKind, LocalLibraryStorageKind.managedPrivate);
      expect(migrated.treeUri, isNull);
      expect(migrated.rootPath, isNot(sourceDir.path));
      expect(p.isWithin(supportDir.path, migrated.rootPath!), isTrue);
      expect(
        await File(p.join(sourceDir.path, 'memos', '$uid.md')).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(sourceDir.path, 'attachments', uid, 'cover.png'),
        ).exists(),
        isTrue,
      );
      expect(
        await targetFs.readText('memos/$uid.md'),
        contains('legacy memo content'),
      );

      final attachments = await targetFs.listAttachments(uid);
      expect(attachments.length, 1);
      expect(attachments.single.name, 'cover.png');
      expect(attachments.single.length, 5);
    },
  );

  test('rebases managed private library with stale root path', () async {
    final oldContainer = await support.createTempDir('old_ios_container');
    final library = LocalLibrary(
      key: 'managed_workspace_rebase',
      name: 'Managed Workspace',
      storageKind: LocalLibraryStorageKind.managedPrivate,
      treeUri: 'content://legacy/tree',
      rootPath: p.join(oldContainer.path, 'Library', 'Application Support'),
    );

    final migrated = await LocalLibraryImportMigrationService().migrateIfNeeded(
      library,
    );
    final expectedPath = await resolveManagedWorkspacePath(
      'managed_workspace_rebase',
    );

    expect(migrated.storageKind, LocalLibraryStorageKind.managedPrivate);
    expect(migrated.treeUri, isNull);
    expect(migrated.rootPath, expectedPath);
    expect(migrated.updatedAt, isNotNull);

    final fs = LocalLibraryFileSystem(migrated);
    await fs.ensureStructure();

    expect(await Directory(p.join(expectedPath, 'memos')).exists(), isTrue);
    expect(
      await Directory(p.join(expectedPath, 'memos', '_meta')).exists(),
      isTrue,
    );
    expect(
      await Directory(p.join(expectedPath, 'attachments')).exists(),
      isTrue,
    );
    expect(
      await Directory(p.join(library.rootPath!, 'memos')).exists(),
      isFalse,
    );
  });
}
