import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_bundle.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_codec.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_package_builder.dart';
import 'package:memos_flutter_app/data/local_library/local_library_fs.dart';
import 'package:memos_flutter_app/data/local_library/local_library_markdown.dart';
import 'package:memos_flutter_app/data/local_library/local_library_memo_sidecar.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/memo_clip_card_metadata.dart';

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
    'buildPackage zips memos at archive root with normalized separators',
    () async {
      final libraryDir = await support.createTempDir('memoflow_pkg_builder');
      final library = LocalLibrary(
        key: 'local_workspace',
        name: 'Local Workspace',
        rootPath: libraryDir.path,
      );
      final fs = LocalLibraryFileSystem(library);
      await fs.ensureStructure();

      final memo = LocalMemo(
        uid: 'memo-builder-test',
        content: 'builder content',
        contentFingerprint: computeContentFingerprint('builder content'),
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTime: DateTime.utc(2025, 1, 1),
        updateTime: DateTime.utc(2025, 1, 1),
        tags: const <String>[],
        attachments: const [],
        relationCount: 0,
        location: null,
        syncState: SyncState.synced,
        lastError: null,
      );
      await fs.writeMemo(
        uid: memo.uid,
        content: buildLocalLibraryMarkdown(memo),
      );
      await fs.writeMemoSidecar(
        uid: memo.uid,
        content: LocalLibraryMemoSidecar.fromMemo(
          memo: memo,
          hasRelations: false,
          relations: const [],
          attachments: const [],
          clipCard: MemoClipCardMetadata(
            memoUid: memo.uid,
            clipKind: MemoClipKind.article,
            platform: MemoClipPlatform.web,
            sourceName: 'Builder Source',
            sourceAvatarUrl: '',
            authorName: 'Builder Author',
            authorAvatarUrl: '',
            sourceUrl: 'https://example.com/builder',
            leadImageUrl: 'https://example.com/builder-cover.jpg',
            parserTag: 'generic',
            createdTime: memo.createTime,
            updatedTime: memo.updateTime,
          ),
        ).encodeJson(),
      );

      final builder = MemoFlowMigrationPackageBuilder(
        codec: const ConfigTransferCodec(),
        readConfigBundle: (_) async => const ConfigTransferBundle(),
      );

      File? packageFile;
      try {
        final result = await builder.buildPackage(
          sourceLibrary: library,
          includeMemos: true,
          configTypes: const {},
          senderDeviceName: 'Sender',
          senderPlatform: 'windows',
        );
        packageFile = result.packageFile;

        final input = InputFileStream(packageFile.path);
        try {
          final archive = ZipDecoder().decodeStream(input);
          final names = archive.files.map((file) => file.name).toList();
          expect(names, contains('memos/${memo.uid}.md'));
          expect(names, contains('memos/_meta/${memo.uid}.json'));
          expect(names.any((name) => name.contains('\\')), isFalse);
          expect(names.any((name) => name.startsWith('payload/')), isFalse);
          final sidecarFile = archive.files.singleWhere(
            (file) => file.name == 'memos/_meta/${memo.uid}.json',
          );
          final sidecarJson =
              jsonDecode(utf8.decode(sidecarFile.content as List<int>))
                  as Map<String, dynamic>;
          expect(sidecarJson['clipCard'], isA<Map<String, dynamic>>());
          expect(
            (sidecarJson['clipCard'] as Map<String, dynamic>)['sourceUrl'],
            'https://example.com/builder',
          );
        } finally {
          input.close();
        }
      } finally {
        if (packageFile != null && await packageFile.exists()) {
          await packageFile.delete();
        }
        if (await libraryDir.exists()) {
          await libraryDir.delete(recursive: true);
        }
      }
    },
  );
}
