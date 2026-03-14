import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/state/memos/create_memo_outbox_payload.dart';
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
}
