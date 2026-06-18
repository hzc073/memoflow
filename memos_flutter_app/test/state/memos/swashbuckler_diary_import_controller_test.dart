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
import 'package:memos_flutter_app/state/memos/swashbuckler_diary_import_controller.dart';

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
    return const SwashbucklerDiaryImportController().importArchive(
      db: db,
      language: AppLanguage.en,
      account: account,
      importScopeKey: importScopeKey,
      filePath: file.path,
      onProgress: (_) {},
      isCancelled: () => false,
    );
  }

  test('imports SwashbucklerDiary JSON export zip with resources', () async {
    final dbName = uniqueDbName('swashbuckler_json_import');
    final db = AppDatabase(dbName: dbName);
    final account = buildAccount('json-import');
    final archive = await createZipFile('swashbuckler_json', {
      '2025-03-04.json': utf8.encode(
        jsonEncode({
          'title': 'My Diary',
          'content':
              '#travel #trip\n\nTrip notes\n![cover](appdata/Image/trip.png)\n[voice](appdata/Audio/trip.m4a)',
          'mood': 'Happy',
          'weather': 'Sunny',
          'location': 'Paris',
          'top': true,
          'tags': [
            {'name': 'travel'},
          ],
          'resources': [
            {'resourceUri': 'appdata/Image/trip.png'},
            {'resourceUri': 'appdata/Audio/trip.m4a'},
          ],
          'createTime': '2025-03-04T01:02:03Z',
          'updateTime': '2025-03-05T04:05:06Z',
        }),
      ),
      'version.json': utf8.encode(
        jsonEncode({'version': '1.7.0', 'fileSuffix': '.json'}),
      ),
      'appdata/Image/trip.png': const <int>[137, 80, 78, 71, 1, 2, 3, 4],
      'appdata/Audio/trip.m4a': const <int>[0, 1, 2, 3, 4, 5, 6, 7],
    });

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final result = await importArchive(
      db: db,
      account: account,
      file: archive,
      importScopeKey: 'workspace-json-import',
    );

    expect(result.memoCount, 1);
    expect(result.attachmentCount, 2);
    expect(result.failedCount, 0);
    expect(result.newTags, containsAll(<String>['travel', 'trip']));

    final memos = await db.listMemos(limit: 10);
    expect(memos, hasLength(1));

    final memo = memos.single;
    expect(memo['content'] as String, contains('My Diary'));
    expect(memo['content'] as String, contains('Mood: Happy'));
    expect(memo['content'] as String, contains('Weather: Sunny'));
    expect(memo['content'] as String, contains('Location: Paris'));
    expect(memo['content'] as String, contains('Trip notes'));
    expect(
      memo['content'] as String,
      isNot(contains('appdata/Image/trip.png')),
    );
    expect(memo['pinned'], 1);
    expect(
      memo['create_time'],
      DateTime.parse('2025-03-04T01:02:03Z').millisecondsSinceEpoch ~/ 1000,
    );

    final attachmentRows = await db.listMemoAttachmentRows(state: 'NORMAL');
    expect(attachmentRows, hasLength(1));
    final attachments =
        jsonDecode(attachmentRows.single['attachments_json'] as String)
            as List<dynamic>;
    expect(attachments, hasLength(2));

    expect(await db.listOutboxPendingByType('upload_attachment'), hasLength(2));
    expect(await db.listOutboxPendingByType('create_memo'), hasLength(1));
  });

  test('imports suffixed SwashbucklerDiary TXT export zip', () async {
    final dbName = uniqueDbName('swashbuckler_txt_import');
    final db = AppDatabase(dbName: dbName);
    final account = buildAccount('txt-import');
    final archive = await createZipFile('swashbuckler_txt', {
      '20250304112233(2).txt': utf8.encode(
        '#retro\n\nPlain export\n\n![photo](appdata/Image/photo.jpg)',
      ),
      'appdata/Image/photo.jpg': const <int>[255, 216, 255, 224, 0, 16, 74, 70],
    });

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final result = await importArchive(
      db: db,
      account: account,
      file: archive,
      importScopeKey: 'workspace-txt-import',
    );

    expect(result.memoCount, 1);
    expect(result.attachmentCount, 1);
    expect(result.failedCount, 0);
    expect(result.newTags, contains('retro'));

    final memos = await db.listMemos(limit: 10);
    expect(memos, hasLength(1));
    final memo = memos.single;
    expect(memo['content'] as String, '#retro\n\nPlain export');
    expect(
      memo['create_time'],
      DateTime(2025, 3, 4, 11, 22, 33).millisecondsSinceEpoch ~/ 1000,
    );

    final attachmentRows = await db.listMemoAttachmentRows(state: 'NORMAL');
    expect(attachmentRows, hasLength(1));
    final attachments =
        jsonDecode(attachmentRows.single['attachments_json'] as String)
            as List<dynamic>;
    expect(attachments, hasLength(1));
  });

  test(
    'imports markdown front matter without leaking metadata into content',
    () async {
      final dbName = uniqueDbName('swashbuckler_frontmatter_import');
      final db = AppDatabase(dbName: dbName);
      final account = buildAccount('frontmatter-import');
      final archive = await createZipFile('swashbuckler_frontmatter', {
        '20260408200753(2).md': utf8.encode(
          '---\n'
          'uid: demo-uid\n'
          'created: 2026-03-23T22:57:50.000Z\n'
          'updated: 2026-03-23T23:04:38.000Z\n'
          'visibility: PRIVATE\n'
          'pinned: true\n'
          'state: NORMAL\n'
          '---\n'
          '# Front matter memo\n\n'
          '![](appdata/Image/frontmatter.jpg)\n\n'
          '正文内容',
        ),
        'appdata/Image/frontmatter.jpg': const <int>[255, 216, 255, 224, 0, 16],
      });

      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final result = await importArchive(
        db: db,
        account: account,
        file: archive,
        importScopeKey: 'workspace-frontmatter-import',
      );

      expect(result.memoCount, 1);
      expect(result.attachmentCount, 1);

      final memos = await db.listMemos(limit: 10);
      expect(memos, hasLength(1));
      final memo = memos.single;
      expect(memo['content'] as String, '# Front matter memo\n\n正文内容');
      expect(memo['content'] as String, isNot(contains('uid: demo-uid')));
      expect(
        memo['create_time'],
        DateTime.parse('2026-03-23T22:57:50.000Z').millisecondsSinceEpoch ~/
            1000,
      );
      expect(
        memo['update_time'],
        DateTime.parse('2026-03-23T23:04:38.000Z').millisecondsSinceEpoch ~/
            1000,
      );
      expect(memo['pinned'], 1);
    },
  );
}
