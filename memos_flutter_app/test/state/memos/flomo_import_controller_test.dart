import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/user.dart';
import 'package:memos_flutter_app/state/memos/flomo_import_controller.dart';
import 'package:memos_flutter_app/state/memos/flomo_import_models.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  Account buildAccount(String key) {
    return Account(
      key: key,
      baseUrl: Uri.parse('https://example.com'),
      personalAccessToken: '',
      user: const User.empty(),
      instanceProfile: const InstanceProfile.empty(),
      serverVersionOverride: '0.26.1',
    );
  }

  Future<File> createZipFile(
    String prefix,
    Map<String, List<int>> entries,
  ) async {
    final dir = await support.createTempDir(prefix);
    final archive = Archive();
    entries.forEach((path, bytes) {
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    });
    final encoded = ZipEncoder().encode(archive);
    expect(encoded, isNotNull);
    final file = File(p.join(dir.path, '$prefix.zip'));
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  Future<ImportResult> importFlomo({
    required AppDatabase db,
    required Account account,
    required File file,
    required String importScopeKey,
  }) {
    return const FlomoImportController().importFlomo(
      db: db,
      language: AppLanguage.en,
      account: account,
      importScopeKey: importScopeKey,
      filePath: file.path,
      onProgress: (_) {},
      isCancelled: () => false,
    );
  }

  Future<ImportResult> importMemoFlowMarkdown({
    required AppDatabase db,
    required Account account,
    required File file,
    required String importScopeKey,
  }) {
    return const FlomoImportController().importMemoFlowMarkdown(
      db: db,
      language: AppLanguage.en,
      account: account,
      importScopeKey: importScopeKey,
      filePath: file.path,
      onProgress: (_) {},
      isCancelled: () => false,
    );
  }

  test('imports valid MemoFlow Markdown export zip', () async {
    final dbName = uniqueDbName('memoflow_markdown_import');
    final db = AppDatabase(dbName: dbName);
    final account = buildAccount('memoflow-markdown-import');
    final archive = await createZipFile('memoflow_markdown', {
      'index.md': utf8.encode('# Export index'),
      'memos/memo-001.md': utf8.encode(
        '---\n'
        'uid: memo-001\n'
        'created: 2026-03-23T22:57:50.000Z\n'
        'updated: 2026-03-24T01:02:03.000Z\n'
        'visibility: PRIVATE\n'
        'pinned: true\n'
        'state: NORMAL\n'
        'tags: export flow\n'
        '---\n'
        '# Flow memo #flow\n\n'
        'MemoFlow body',
      ),
      'memos/_meta/memo-001.json': utf8.encode(
        jsonEncode({
          'schemaVersion': 2,
          'memoUid': 'memo-001',
          'contentFingerprint': 'fingerprint',
          'attachments': [
            {
              'archiveName': 'image.png',
              'uid': 'att-001',
              'name': 'attachments/att-001',
              'filename': 'image.png',
              'type': 'image/png',
              'size': 8,
              'externalLink': '',
            },
          ],
        }),
      ),
      'attachments/memo-001/image.png': const <int>[
        137,
        80,
        78,
        71,
        1,
        2,
        3,
        4,
      ],
    });

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final result = await importMemoFlowMarkdown(
      db: db,
      account: account,
      file: archive,
      importScopeKey: 'workspace-memoflow-markdown',
    );

    expect(result.memoCount, 1);
    expect(result.attachmentCount, 1);
    expect(result.failedCount, 0);
    expect(result.newTags, containsAll(<String>['export', 'flow']));

    final memos = await db.listMemos(limit: 10);
    expect(memos, hasLength(1));
    final memo = memos.single;
    expect(memo['uid'], 'memo-001');
    expect(memo['content'] as String, '# Flow memo #flow\n\nMemoFlow body');
    expect(memo['content'] as String, isNot(contains('uid: memo-001')));
    expect(memo['pinned'], 1);
    expect(
      memo['create_time'],
      DateTime.parse('2026-03-23T22:57:50.000Z').millisecondsSinceEpoch ~/ 1000,
    );

    final attachmentRows = await db.listMemoAttachmentRows(state: 'NORMAL');
    expect(attachmentRows, hasLength(1));
    final attachments =
        jsonDecode(attachmentRows.single['attachments_json'] as String)
            as List<dynamic>;
    expect(attachments, hasLength(1));
    expect(
      (attachments.single as Map<String, dynamic>)['filename'],
      'image.png',
    );
  });

  test(
    'rejects MemoFlow Markdown zip without memos markdown and no HTML error',
    () async {
      final dbName = uniqueDbName('memoflow_markdown_index_only');
      final db = AppDatabase(dbName: dbName);
      final account = buildAccount('memoflow-index-only');
      final archive = await createZipFile('memoflow_index_only', {
        'index.md': utf8.encode('# Index only'),
        'assets/photo.png': const <int>[137, 80, 78, 71],
      });

      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await expectLater(
        () => importMemoFlowMarkdown(
          db: db,
          account: account,
          file: archive,
          importScopeKey: 'workspace-memoflow-index-only',
        ),
        throwsA(
          isA<ImportException>()
              .having((e) => e.message, 'message', contains('Markdown memos'))
              .having((e) => e.message, 'message', isNot(contains('HTML'))),
        ),
      );
    },
  );

  test('keeps Flomo HTML zip import behavior', () async {
    final dbName = uniqueDbName('flomo_html_zip_import');
    final db = AppDatabase(dbName: dbName);
    final account = buildAccount('flomo-html-zip-import');
    final archive = await createZipFile('flomo_html_zip', {
      'flomo/export.html': utf8.encode(
        '<html><body>'
        '<div class="memo">'
        '<div class="time">2026-03-23 22:57:50</div>'
        '<div class="content"><p>Flomo body</p><p>#flomo</p></div>'
        '</div>'
        '</body></html>',
      ),
    });

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final result = await importFlomo(
      db: db,
      account: account,
      file: archive,
      importScopeKey: 'workspace-flomo-html-zip',
    );

    expect(result.memoCount, 1);
    expect(result.attachmentCount, 0);
    expect(result.failedCount, 0);
    expect(result.newTags, contains('flomo'));

    final memos = await db.listMemos(limit: 10);
    expect(memos, hasLength(1));
    expect(memos.single['content'], 'Flomo body\n\n#flomo');
    expect(
      memos.single['create_time'],
      DateTime(2026, 3, 23, 22, 57, 50).millisecondsSinceEpoch ~/ 1000,
    );
  });
}
