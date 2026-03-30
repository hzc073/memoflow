import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/state/memos/memo_timeline_provider.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test('captureMemoVersion retries busy memo version inserts', () async {
    final db = _BusyMemoVersionDb(busyFailuresBeforeSuccess: 2);
    final service = MemoTimelineService(
      db: db,
      account: null,
      triggerSync: () async {},
      waitForRetry: (_) async {},
    );

    await service.captureMemoVersion(_sampleMemo());

    expect(db.insertCalls, 3);
    expect(db.successfulInsertCount, 1);
  });

  test(
    'captureMemoVersion skips version write after repeated busy errors',
    () async {
      final db = _BusyMemoVersionDb(busyFailuresBeforeSuccess: 99);
      final service = MemoTimelineService(
        db: db,
        account: null,
        triggerSync: () async {},
        waitForRetry: (_) async {},
      );

      await service.captureMemoVersion(_sampleMemo());

      expect(db.insertCalls, 3);
      expect(db.successfulInsertCount, 0);
    },
  );
}

class _BusyMemoVersionDb extends AppDatabase {
  _BusyMemoVersionDb({required this.busyFailuresBeforeSuccess});

  int busyFailuresBeforeSuccess;
  int insertCalls = 0;
  int successfulInsertCount = 0;

  @override
  Future<int> insertMemoVersion({
    required String memoUid,
    required int snapshotTime,
    required String summary,
    required String payloadJson,
  }) async {
    insertCalls += 1;
    if (busyFailuresBeforeSuccess > 0) {
      busyFailuresBeforeSuccess -= 1;
      throw Exception(
        "DatabaseException(database is locked (code 5 SQLITE_BUSY)) sql 'INSERT INTO memo_versions ...'",
      );
    }
    successfulInsertCount += 1;
    return successfulInsertCount;
  }

  @override
  Future<List<int>> listMemoVersionIdsExceedLimit(
    String memoUid, {
    required int keep,
  }) async {
    return const <int>[];
  }
}

LocalMemo _sampleMemo() {
  final now = DateTime.utc(2025, 1, 1);
  return LocalMemo(
    uid: 'memo-version-1',
    content: 'hello world',
    contentFingerprint: 'fingerprint',
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: now,
    updateTime: now,
    tags: const <String>[],
    attachments: const [],
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
  );
}
