import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/memo.dart';
import 'package:memos_flutter_app/state/memos/create_memo_time_policy.dart';

void main() {
  test(
    'returns legacy follow-up display time when create body lacks timestamps',
    () {
      final createTime = DateTime.utc(2026, 3, 13, 18, 0);

      expect(
        resolveCreateMemoFollowUpDisplayTime(
          supportsCreateMemoTimestampsInCreateBody: false,
          createTime: createTime,
          displayTime: null,
        ),
        createTime,
      );
    },
  );

  test('skips follow-up display time when create body supports timestamps', () {
    expect(
      resolveCreateMemoFollowUpDisplayTime(
        supportsCreateMemoTimestampsInCreateBody: true,
        createTime: DateTime.utc(2026, 3, 13, 18, 0),
        displayTime: DateTime.utc(2026, 3, 13, 19, 0),
      ),
      isNull,
    );
  });

  Memo memoWithUid(String uid) {
    final now = DateTime.utc(2026, 3, 13, 22, 0);
    return Memo(
      name: 'memos/$uid',
      creator: 'users/test',
      content: 'memo',
      contentFingerprint: 'fp',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: now,
      updateTime: now,
      tags: const <String>[],
      attachments: const [],
    );
  }

  LocalMemo localMemoWithUid(
    String uid, {
    required DateTime createTime,
    String content = 'memo',
  }) {
    return LocalMemo(
      uid: uid,
      content: content,
      contentFingerprint: 'fp',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: createTime,
      updateTime: createTime,
      tags: const <String>[],
      attachments: const [],
      relationCount: 0,
      syncState: SyncState.synced,
      lastError: null,
    );
  }

  test('preserves local create time when remote lacks display time', () {
    final localMemo = localMemoWithUid(
      'memo-1',
      createTime: DateTime.utc(2026, 3, 13, 18, 0),
    );
    final remoteMemo = memoWithUid('memo-1');

    expect(
      shouldPreserveLocalCreateTime(
        localMemo: localMemo,
        localSyncState: 0,
        remoteMemo: remoteMemo,
      ),
      isTrue,
    );
  });

  test('does not preserve local create time when remote has display time', () {
    final localMemo = localMemoWithUid(
      'memo-1',
      createTime: DateTime.utc(2026, 3, 13, 18, 0),
    );
    final now = DateTime.utc(2026, 3, 13, 22, 0);
    final remoteMemo = Memo(
      name: 'memos/memo-1',
      creator: 'users/test',
      content: 'memo',
      contentFingerprint: 'fp',
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: now,
      updateTime: now,
      displayTime: DateTime.utc(2026, 3, 13, 18, 0),
      tags: const <String>[],
      attachments: const [],
    );

    expect(
      shouldPreserveLocalCreateTime(
        localMemo: localMemo,
        localSyncState: 0,
        remoteMemo: remoteMemo,
      ),
      isFalse,
    );
  });
}
