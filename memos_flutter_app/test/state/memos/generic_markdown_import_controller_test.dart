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
import 'package:memos_flutter_app/state/memos/flomo_import_models.dart';
import 'package:memos_flutter_app/state/memos/generic_markdown_import_controller.dart';

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

  Future<ImportResult> importArchive({
    required AppDatabase db,
    required Account account,
    required File file,
    required String importScopeKey,
  }) {
    return const GenericMarkdownImportController().importArchive(
      db: db,
      language: AppLanguage.en,
      account: account,
      importScopeKey: importScopeKey,
      filePath: file.path,
      onProgress: (_) {},
      isCancelled: () => false,
    );
  }

  test(
    'imports multiple markdown files and skips excluded directories',
    () async {
      final dbName = uniqueDbName('generic_markdown_multi_import');
      final db = AppDatabase(dbName: dbName);
      final account = buildAccount('generic-multi-import');
      final archive = await createZipFile('generic_markdown_multi', {
        'index.md': utf8.encode('# Home\n\nRoot body\n\n#root'),
        'README.md': utf8.encode('Read me body'),
        'note.md': utf8.encode('Plain note'),
        'folder/another.md': utf8.encode('Another body\n\n#inside'),
        'assets/ignored.md': utf8.encode('Asset markdown should not import'),
        '.obsidian/config.md': utf8.encode('Obsidian config'),
        '.git/info.md': utf8.encode('Git info'),
        '__MACOSX/meta.md': utf8.encode('Mac metadata'),
        '.hidden/note.md': utf8.encode('Hidden note'),
      });

      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final result = await importArchive(
        db: db,
        account: account,
        file: archive,
        importScopeKey: 'workspace-generic-multi-import',
      );

      expect(result.memoCount, 4);
      expect(result.attachmentCount, 0);
      expect(result.failedCount, 0);
      expect(result.newTags, containsAll(<String>['inside', 'root']));
      expect(result.newTags, isNot(contains('folder')));

      final memos = await db.listMemos(limit: 20);
      final contents = memos.map((row) => row['content'] as String).toList();

      expect(contents, contains('# Home\n\nRoot body\n\n#root'));
      expect(contents, contains('Read me body'));
      expect(contents, contains('Plain note'));
      expect(contents, contains('Another body\n\n#inside'));
      expect(
        contents.join('\n'),
        isNot(contains('Asset markdown should not import')),
      );
      expect(contents.join('\n'), isNot(contains('Obsidian config')));
      expect(contents.join('\n'), isNot(contains('Git info')));
      expect(contents.join('\n'), isNot(contains('Mac metadata')));
      expect(contents.join('\n'), isNot(contains('Hidden note')));
    },
  );

  test('applies front matter and imports only referenced assets', () async {
    final dbName = uniqueDbName('generic_markdown_frontmatter_assets');
    final db = AppDatabase(dbName: dbName);
    final account = buildAccount('generic-frontmatter-assets');
    final archive = await createZipFile('generic_markdown_assets', {
      'note.md': utf8.encode(
        '---\n'
        'created: 2026-03-23T22:57:50.000Z\n'
        'updated: 2026-03-24T01:02:03.000Z\n'
        'tags: [alpha, beta]\n'
        'pinned: true\n'
        'visibility: PUBLIC\n'
        '---\n'
        '#alpha #beta\n\n'
        '# Asset memo #inline\n\n'
        '![photo](assets/photo.png)\n\n'
        '[document](assets/doc.pdf)\n\n'
        '<img src="assets/inline.jpg">\n\n'
        '<video src="assets/movie.mp4"></video>\n\n'
        '<audio src="https://example.com/audio.mp3"></audio>\n\n'
        '[missing](assets/missing.pdf)',
      ),
      'assets/photo.png': const <int>[137, 80, 78, 71, 1, 2, 3, 4],
      'assets/doc.pdf': utf8.encode('%PDF-1.4'),
      'assets/inline.jpg': const <int>[255, 216, 255, 224],
      'assets/movie.mp4': const <int>[0, 0, 0, 24, 102, 116, 121, 112],
      'assets/unused.pdf': utf8.encode('%PDF-unused'),
    });

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final result = await importArchive(
      db: db,
      account: account,
      file: archive,
      importScopeKey: 'workspace-generic-frontmatter-assets',
    );

    expect(result.memoCount, 1);
    expect(result.attachmentCount, 4);
    expect(result.failedCount, 0);
    expect(result.newTags, containsAll(<String>['alpha', 'beta']));

    final memos = await db.listMemos(limit: 10);
    expect(memos, hasLength(1));
    final memo = memos.single;
    final content = memo['content'] as String;

    expect(content, contains('# Asset memo #inline'));
    expect(content, contains('document'));
    expect(content, contains('https://example.com/audio.mp3'));
    expect(content, contains('[missing](assets/missing.pdf)'));
    expect(content, isNot(contains('created: 2026-03-23')));
    expect(content, isNot(contains('assets/photo.png')));
    expect(content, isNot(contains('assets/doc.pdf')));
    expect(content, isNot(contains('assets/inline.jpg')));
    expect(content, isNot(contains('assets/movie.mp4')));
    expect(memo['visibility'], 'PUBLIC');
    expect(memo['pinned'], 1);
    expect(
      memo['create_time'],
      DateTime.parse('2026-03-23T22:57:50.000Z').millisecondsSinceEpoch ~/ 1000,
    );
    expect(
      memo['update_time'],
      DateTime.parse('2026-03-24T01:02:03.000Z').millisecondsSinceEpoch ~/ 1000,
    );

    final attachmentRows = await db.listMemoAttachmentRows(state: 'NORMAL');
    expect(attachmentRows, hasLength(1));
    final attachments =
        jsonDecode(attachmentRows.single['attachments_json'] as String)
            as List<dynamic>;
    final filenames = attachments
        .map((item) => (item as Map<String, dynamic>)['filename'] as String)
        .toSet();
    expect(
      filenames,
      containsAll(<String>['photo.png', 'doc.pdf', 'inline.jpg', 'movie.mp4']),
    );
    expect(filenames, isNot(contains('unused.pdf')));
  });

  test('keeps local markdown note links out of attachments', () async {
    final dbName = uniqueDbName('generic_markdown_note_links');
    final db = AppDatabase(dbName: dbName);
    final account = buildAccount('generic-note-links');
    final archive = await createZipFile('generic_markdown_note_links', {
      'note.md': utf8.encode(
        'See [Other](other.md) and ![photo](assets/photo.png).',
      ),
      'other.md': utf8.encode('Other note body'),
      'assets/photo.png': const <int>[137, 80, 78, 71, 1, 2, 3, 4],
    });

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final result = await importArchive(
      db: db,
      account: account,
      file: archive,
      importScopeKey: 'workspace-generic-note-links',
    );

    expect(result.memoCount, 2);
    expect(result.attachmentCount, 1);
    expect(result.failedCount, 0);

    final memos = await db.listMemos(limit: 10);
    final contents = memos.map((row) => row['content'] as String).toList();
    final linkedMemoContent = contents.singleWhere(
      (content) => content.contains('See [Other]'),
    );
    expect(linkedMemoContent, contains('[Other](other.md)'));
    expect(linkedMemoContent, isNot(contains('assets/photo.png')));
    expect(contents, contains('Other note body'));

    final attachmentRows = await db.listMemoAttachmentRows(state: 'NORMAL');
    expect(attachmentRows, hasLength(1));
    final attachments =
        jsonDecode(attachmentRows.single['attachments_json'] as String)
            as List<dynamic>;
    final filenames = attachments
        .map((item) => (item as Map<String, dynamic>)['filename'] as String)
        .toSet();
    expect(filenames, contains('photo.png'));
    expect(filenames, isNot(contains('other.md')));
  });
}
