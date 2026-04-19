import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/local_library/local_library_memo_sidecar.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/data/models/memo_clip_card_metadata.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/data/models/memo_relation.dart';

void main() {
  test('sidecar round trips lossless memo metadata', () {
    final memo = LocalMemo(
      uid: 'memo-1',
      content: 'hello [[memo-2]]',
      contentFingerprint: computeContentFingerprint('hello [[memo-2]]'),
      visibility: 'PRIVATE',
      pinned: true,
      state: 'NORMAL',
      createTime: DateTime.utc(2026, 1, 1, 8),
      displayTime: DateTime.utc(2026, 1, 2, 9),
      updateTime: DateTime.utc(2026, 1, 3, 10),
      tags: const <String>['tag-a'],
      attachments: const <Attachment>[
        Attachment(
          name: 'attachments/att-1',
          filename: 'photo.jpg',
          type: 'image/jpeg',
          size: 12,
          externalLink: 'file:///tmp/photo.jpg',
        ),
      ],
      relationCount: 1,
      location: const MemoLocation(
        placeholder: 'Shanghai',
        latitude: 31.2304,
        longitude: 121.4737,
      ),
      syncState: SyncState.synced,
      lastError: null,
    );
    final sidecar = LocalLibraryMemoSidecar.fromMemo(
      memo: memo,
      hasRelations: true,
      relations: const <MemoRelation>[
        MemoRelation(
          memo: MemoRelationMemo(name: 'memos/memo-1', snippet: 'hello'),
          relatedMemo: MemoRelationMemo(name: 'memos/memo-2', snippet: 'world'),
          type: 'REFERENCE',
        ),
      ],
      attachments: const <LocalLibraryAttachmentExportMeta>[
        LocalLibraryAttachmentExportMeta(
          archiveName: 'att-1_photo.jpg',
          uid: 'att-1',
          name: 'attachments/att-1',
          filename: 'photo.jpg',
          type: 'image/jpeg',
          size: 12,
          externalLink: 'file:///tmp/photo.jpg',
        ),
      ],
    );

    final decoded = LocalLibraryMemoSidecar.tryParse(sidecar.encodeJson());

    expect(decoded, isNotNull);
    expect(decoded!.memoUid, memo.uid);
    expect(decoded.contentFingerprint, memo.contentFingerprint);
    expect(decoded.hasDisplayTime, isTrue);
    expect(decoded.displayTime, DateTime.utc(2026, 1, 2, 9));
    expect(decoded.hasLocation, isTrue);
    expect(decoded.location?.placeholder, 'Shanghai');
    expect(decoded.hasRelations, isTrue);
    expect(decoded.relationCount, 1);
    expect(decoded.relationsAreComplete, isTrue);
    expect(decoded.relations, hasLength(1));
    expect(decoded.relations.single.relatedMemo.name, 'memos/memo-2');
    expect(decoded.hasAttachments, isTrue);
    expect(decoded.attachments.single.archiveName, 'att-1_photo.jpg');
  });

  test('sidecar round trips clip card metadata', () {
    final memo = LocalMemo(
      uid: 'memo-clip',
      content: '# 标题\n\n正文',
      contentFingerprint: computeContentFingerprint('# 标题\n\n正文'),
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: DateTime.utc(2026, 4, 18, 2),
      displayTime: null,
      updateTime: DateTime.utc(2026, 4, 18, 3),
      tags: const <String>[],
      attachments: const <Attachment>[],
      relationCount: 0,
      location: null,
      syncState: SyncState.synced,
      lastError: null,
    );

    final sidecar = LocalLibraryMemoSidecar.fromMemo(
      memo: memo,
      hasRelations: false,
      relations: const <MemoRelation>[],
      attachments: const <LocalLibraryAttachmentExportMeta>[],
      clipCard: MemoClipCardMetadata(
        memoUid: memo.uid,
        clipKind: MemoClipKind.article,
        platform: MemoClipPlatform.wechat,
        sourceName: '中国民兵',
        sourceAvatarUrl: '',
        authorName: '编辑部',
        authorAvatarUrl: '',
        sourceUrl: 'https://mp.weixin.qq.com/s/example',
        leadImageUrl: 'https://example.com/cover.jpg',
        parserTag: 'wechat',
        createdTime: memo.createTime,
        updatedTime: memo.updateTime,
      ),
    );

    final decoded = LocalLibraryMemoSidecar.tryParse(sidecar.encodeJson());

    expect(decoded, isNotNull);
    expect(decoded!.hasClipCard, isTrue);
    expect(decoded.clipCard, isNotNull);
    expect(decoded.clipCard!.platform, MemoClipPlatform.wechat);
    expect(decoded.clipCard!.sourceName, '中国民兵');
    expect(decoded.clipCard!.authorName, '编辑部');
    expect(decoded.clipCard!.sourceUrl, 'https://mp.weixin.qq.com/s/example');
  });

  test('sidecar preserves missing versus null and empty semantics', () {
    final missing = LocalLibraryMemoSidecar.tryParse(
      '{"schemaVersion":1,"memoUid":"memo-1","contentFingerprint":"fp"}',
    );
    final explicit = LocalLibraryMemoSidecar.tryParse(
      '{"schemaVersion":1,"memoUid":"memo-1","contentFingerprint":"fp","displayTime":null,"location":null,"relations":[],"attachments":[]}',
    );

    expect(missing, isNotNull);
    expect(missing!.hasDisplayTime, isFalse);
    expect(missing.hasLocation, isFalse);
    expect(missing.hasRelations, isFalse);
    expect(missing.hasRelationMetadata, isFalse);
    expect(missing.hasAttachments, isFalse);

    expect(explicit, isNotNull);
    expect(explicit!.hasDisplayTime, isTrue);
    expect(explicit.displayTime, isNull);
    expect(explicit.hasLocation, isTrue);
    expect(explicit.location, isNull);
    expect(explicit.hasRelations, isTrue);
    expect(explicit.relationsAreComplete, isTrue);
    expect(explicit.relations, isEmpty);
    expect(explicit.hasAttachments, isTrue);
    expect(explicit.attachments, isEmpty);
  });

  test('sidecar can omit attachment metadata while keeping other fields', () {
    final memo = LocalMemo(
      uid: 'memo-2',
      content: 'hello',
      contentFingerprint: computeContentFingerprint('hello'),
      visibility: 'PRIVATE',
      pinned: false,
      state: 'NORMAL',
      createTime: DateTime.utc(2026, 5, 1, 8),
      updateTime: DateTime.utc(2026, 5, 1, 9),
      tags: const <String>[],
      attachments: const <Attachment>[],
      relationCount: 0,
      location: null,
      syncState: SyncState.synced,
      lastError: null,
    );

    final sidecar = LocalLibraryMemoSidecar.fromMemo(
      memo: memo,
      hasRelations: true,
      relations: const <MemoRelation>[],
      attachments: const <LocalLibraryAttachmentExportMeta>[],
      hasAttachments: false,
    );

    final decoded = LocalLibraryMemoSidecar.tryParse(sidecar.encodeJson());

    expect(decoded, isNotNull);
    expect(decoded!.hasRelations, isTrue);
    expect(decoded.relations, isEmpty);
    expect(decoded.relationCount, 0);
    expect(decoded.relationsAreComplete, isTrue);
    expect(decoded.hasAttachments, isFalse);
    expect(decoded.attachments, isEmpty);
  });

  test('sidecar can preserve incomplete relation metadata', () {
    final sidecar = LocalLibraryMemoSidecar.tryParse(
      '{"schemaVersion":1,"memoUid":"memo-3","contentFingerprint":"fp","relations":[],"relationCount":2,"relationsComplete":false}',
    );

    expect(sidecar, isNotNull);
    expect(sidecar!.hasRelationMetadata, isTrue);
    expect(sidecar.relations, isEmpty);
    expect(sidecar.relationCount, 2);
    expect(sidecar.relationsAreComplete, isFalse);
    expect(sidecar.resolveRelationCount(), 2);
  });
}
