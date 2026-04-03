import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/queued_attachment_stager.dart';
import 'package:memos_flutter_app/application/quick_input/quick_input_service.dart';
import 'package:memos_flutter_app/core/memo_relations.dart';
import 'package:memos_flutter_app/data/api/memo_api_facade.dart';
import 'package:memos_flutter_app/data/api/memo_api_version.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/user_setting.dart';
import 'package:memos_flutter_app/state/memos/app_bootstrap_adapter_provider.dart';
import 'package:memos_flutter_app/state/memos/memos_providers.dart';
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

  Future<WidgetRef> pumpRef(
    WidgetTester tester, {
    required List<Override> overrides,
  }) async {
    WidgetRef? capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    if (capturedRef == null) {
      throw StateError('Failed to capture WidgetRef');
    }
    return capturedRef!;
  }

  testWidgets(
    'QuickInputService stages attachment payloads before placeholder and outbox writes',
    (tester) async {
      await tester.runAsync(() async {
        final dbName = uniqueDbName('quick_input_stages_attachments');
        final db = AppDatabase(dbName: dbName);
        final attachmentFile = await createAttachmentFile(
          'quick_input_staging',
        );
        final api = MemoApiFacade.authenticated(
          baseUrl: Uri.parse('https://example.com'),
          personalAccessToken: 'test-pat',
          version: MemoApiVersion.v023,
        );
        final ref = await pumpRef(
          tester,
          overrides: [
            databaseProvider.overrideWithValue(db),
            memosApiProvider.overrideWithValue(api),
          ],
        );
        final service = QuickInputService(
          bootstrapAdapter: _FakeBootstrapAdapter(db),
        );

        addTearDown(() async {
          await db.close();
          await deleteTestDatabase(dbName);
        });

        await service.submitQuickInput(
          ref,
          'quick input memo',
          attachmentPayloads: [
            {
              'uid': 'att-1',
              'file_path': attachmentFile.path,
              'filename': 'sample.png',
              'mime_type': 'image/png',
              'file_size': await attachmentFile.length(),
            },
          ],
        );

        final uploadOutbox = await db.listOutboxPendingByType(
          'upload_attachment',
        );
        expect(uploadOutbox, hasLength(1));
        final uploadPayload =
            jsonDecode(uploadOutbox.single['payload'] as String)
                as Map<String, dynamic>;
        final stagedPath = uploadPayload['file_path'] as String;
        expect(stagedPath, contains(QueuedAttachmentStager.managedRootDirName));

        final memoUid = uploadPayload['memo_uid'] as String;
        final row = await db.getMemoByUid(memoUid);
        expect(row, isNotNull);
        final attachments =
            jsonDecode(row!['attachments_json'] as String) as List<dynamic>;
        expect(attachments, hasLength(1));
        final attachment = attachments.single as Map<String, dynamic>;
        expect(attachment['externalLink'], Uri.file(stagedPath).toString());
        expect(
          attachment['externalLink'],
          contains(QueuedAttachmentStager.managedRootDirName),
        );
      });
    },
  );

  testWidgets('QuickInputService stores local relation snippets in cache', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final dbName = uniqueDbName('quick_input_relation_snippets');
      final db = AppDatabase(dbName: dbName);
      final api = MemoApiFacade.authenticated(
        baseUrl: Uri.parse('https://example.com'),
        personalAccessToken: 'test-pat',
        version: MemoApiVersion.v023,
      );
      final ref = await pumpRef(
        tester,
        overrides: [
          databaseProvider.overrideWithValue(db),
          memosApiProvider.overrideWithValue(api),
        ],
      );
      final service = QuickInputService(
        bootstrapAdapter: _FakeBootstrapAdapter(db),
      );

      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      await service.submitQuickInput(
        ref,
        'quick input memo [[memo-2]]',
        relations: const <Map<String, dynamic>>[
          {
            'relatedMemo': {'name': 'memos/memo-2', 'snippet': 'memo two'},
            'type': 'REFERENCE',
          },
        ],
      );

      final rows = await db.listMemos(limit: 10);
      expect(rows, hasLength(1));
      final memoUid = rows.single['uid'] as String;
      final relationsJson = await db.getMemoRelationsCacheJson(memoUid);
      final cachedRelations = decodeMemoRelationsJson(relationsJson ?? '');
      expect(cachedRelations, hasLength(1));
      expect(
        cachedRelations.single.memo.snippet,
        'quick input memo [[memo-2]]',
      );
      expect(cachedRelations.single.relatedMemo.name, 'memos/memo-2');
    });
  });
}

class _FakeBootstrapAdapter extends AppBootstrapAdapter {
  const _FakeBootstrapAdapter(this.db);

  final AppDatabase db;

  @override
  AppDatabase readDatabase(WidgetRef ref) => db;

  @override
  UserGeneralSetting? readUserGeneralSetting(WidgetRef ref) => null;

  @override
  Future<void> requestSync(WidgetRef ref, request) async {}
}
