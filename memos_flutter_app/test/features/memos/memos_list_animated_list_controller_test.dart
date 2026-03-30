import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/features/memos/memos_list_animated_list_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keyFor reuses key for the same uid', () {
    final controller = MemosListAnimatedListController();
    addTearDown(controller.dispose);

    final first = controller.keyFor('memo-1');
    final second = controller.keyFor('memo-1');

    expect(identical(first, second), isTrue);
  });

  test('syncMemoCardKeys clears keys for removed memos', () {
    final controller = MemosListAnimatedListController();
    addTearDown(controller.dispose);
    final keptKey = controller.keyFor('memo-keep');
    final removedKey = controller.keyFor('memo-drop');

    controller.syncMemoCardKeys(<LocalMemo>[_buildMemo(uid: 'memo-keep')]);

    expect(identical(controller.keyFor('memo-keep'), keptKey), isTrue);
    expect(identical(controller.keyFor('memo-drop'), removedKey), isFalse);
  });

  test('syncAnimatedMemos uses append fast path for same signature prefix', () {
    final controller = MemosListAnimatedListController();
    addTearDown(controller.dispose);
    final memo1 = _buildMemo(uid: 'memo-1', content: 'one');
    final memo2 = _buildMemo(uid: 'memo-2', content: 'two');

    controller.syncAnimatedMemos(
      <LocalMemo>[memo1],
      'sig',
      logEvent: (_, _) {},
      logVisibleDecrease:
          ({
            required beforeLength,
            required afterLength,
            required signatureChanged,
            required listChanged,
            required fromSignature,
            required toSignature,
            required removedSample,
          }) {},
      metrics: null,
      schedulePostFrame: (callback) => callback(),
    );
    final keyAfterInitialSync = controller.listKey;
    var scheduled = 0;

    controller.syncAnimatedMemos(
      <LocalMemo>[memo1, memo2],
      'sig',
      logEvent: (_, _) {},
      logVisibleDecrease:
          ({
            required beforeLength,
            required afterLength,
            required signatureChanged,
            required listChanged,
            required fromSignature,
            required toSignature,
            required removedSample,
          }) {},
      metrics: null,
      schedulePostFrame: (callback) {
        scheduled++;
        callback();
      },
    );

    expect(identical(controller.listKey, keyAfterInitialSync), isTrue);
    expect(scheduled, 1);
    expect(controller.animatedMemos.map((memo) => memo.uid), <String>[
      'memo-1',
      'memo-2',
    ]);
  });

  test('syncAnimatedMemos rebuilds list key when signature changes', () {
    final controller = MemosListAnimatedListController();
    addTearDown(controller.dispose);
    final memo = _buildMemo(uid: 'memo-1');

    controller.syncAnimatedMemos(
      <LocalMemo>[memo],
      'sig-a',
      logEvent: (_, _) {},
      logVisibleDecrease:
          ({
            required beforeLength,
            required afterLength,
            required signatureChanged,
            required listChanged,
            required fromSignature,
            required toSignature,
            required removedSample,
          }) {},
      metrics: null,
      schedulePostFrame: (_) {},
    );
    final originalKey = controller.listKey;

    controller.syncAnimatedMemos(
      <LocalMemo>[memo],
      'sig-b',
      logEvent: (_, _) {},
      logVisibleDecrease:
          ({
            required beforeLength,
            required afterLength,
            required signatureChanged,
            required listChanged,
            required fromSignature,
            required toSignature,
            required removedSample,
          }) {},
      metrics: null,
      schedulePostFrame: (_) {},
    );

    expect(identical(controller.listKey, originalKey), isFalse);
  });

  test('syncAnimatedMemos updates memo data when uid list stays stable', () {
    final controller = MemosListAnimatedListController();
    addTearDown(controller.dispose);
    final before = _buildMemo(uid: 'memo-1', content: 'before');
    final after = _buildMemo(uid: 'memo-1', content: 'after');

    controller.syncAnimatedMemos(
      <LocalMemo>[before],
      'sig',
      logEvent: (_, _) {},
      logVisibleDecrease:
          ({
            required beforeLength,
            required afterLength,
            required signatureChanged,
            required listChanged,
            required fromSignature,
            required toSignature,
            required removedSample,
          }) {},
      metrics: null,
      schedulePostFrame: (_) {},
    );

    controller.syncAnimatedMemos(
      <LocalMemo>[after],
      'sig',
      logEvent: (_, _) {},
      logVisibleDecrease:
          ({
            required beforeLength,
            required afterLength,
            required signatureChanged,
            required listChanged,
            required fromSignature,
            required toSignature,
            required removedSample,
          }) {},
      metrics: null,
      schedulePostFrame: (_) {},
    );

    expect(controller.animatedMemos.single.content, 'after');
  });

  test('removeMemoWithAnimation tracks removed uid', () {
    final controller = MemosListAnimatedListController();
    addTearDown(controller.dispose);
    final memo = _buildMemo(uid: 'memo-1');
    controller.syncAnimatedMemos(
      <LocalMemo>[memo],
      'sig',
      logEvent: (_, _) {},
      logVisibleDecrease:
          ({
            required beforeLength,
            required afterLength,
            required signatureChanged,
            required listChanged,
            required fromSignature,
            required toSignature,
            required removedSample,
          }) {},
      metrics: null,
      schedulePostFrame: (_) {},
    );

    controller.removeMemoWithAnimation(
      memo,
      builder: (_, _) => const SizedBox.shrink(),
    );

    expect(controller.pendingRemovedUids, contains('memo-1'));
    expect(controller.animatedMemos, isEmpty);
  });
}

LocalMemo _buildMemo({required String uid, String content = 'memo'}) {
  return LocalMemo(
    uid: uid,
    content: content,
    contentFingerprint: computeContentFingerprint(content),
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: DateTime.utc(2025, 1, 1),
    updateTime: DateTime.utc(2025, 1, 1, 1),
    tags: const <String>['tag'],
    attachments: const <Attachment>[],
    relationCount: 0,
    syncState: SyncState.synced,
    lastError: null,
  );
}
