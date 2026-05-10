import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/queued_attachment_stager.dart';
import 'package:memos_flutter_app/application/sync/compose_draft_transfer.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';

void main() {
  test('materializes text-only draft bundle without attachment root', () async {
    final supportDir = await Directory.systemTemp.createTemp(
      'compose_draft_transfer_test_',
    );
    addTearDown(() async {
      if (await supportDir.exists()) {
        await supportDir.delete(recursive: true);
      }
    });

    final bundle =
        ComposeDraftTransferBundle.fromDraftRecords(<ComposeDraftRecord>[
          ComposeDraftRecord(
            uid: 'draft-1',
            workspaceKey: 'ignored',
            snapshot: const ComposeDraftSnapshot(
              content: 'text only draft',
              visibility: 'PRIVATE',
            ),
            createdTime: DateTime.fromMillisecondsSinceEpoch(10, isUtc: true),
            updatedTime: DateTime.fromMillisecondsSinceEpoch(20, isUtc: true),
          ),
        ]);

    final drafts = await materializeComposeDraftTransferBundle(
      bundle: bundle,
      rootDirectory: null,
      workspaceKey: 'workspace-1',
      attachmentStager: QueuedAttachmentStager(
        resolveSupportDirectory: () async => supportDir,
      ),
    );

    expect(drafts, hasLength(1));
    expect(drafts.single.workspaceKey, 'workspace-1');
    expect(drafts.single.snapshot.content, 'text only draft');
    expect(drafts.single.snapshot.attachments, isEmpty);
  });

  test(
    'legacy note draft merges into existing drafts without deleting them',
    () {
      final existing = <ComposeDraftRecord>[
        ComposeDraftRecord(
          uid: 'draft-existing-a',
          workspaceKey: 'workspace-1',
          snapshot: const ComposeDraftSnapshot(
            content: 'existing A',
            visibility: 'PRIVATE',
          ),
          createdTime: DateTime.fromMillisecondsSinceEpoch(10, isUtc: true),
          updatedTime: DateTime.fromMillisecondsSinceEpoch(20, isUtc: true),
        ),
        ComposeDraftRecord(
          uid: 'draft-existing-b',
          workspaceKey: 'workspace-1',
          snapshot: const ComposeDraftSnapshot(
            content: 'existing B',
            visibility: 'PRIVATE',
          ),
          createdTime: DateTime.fromMillisecondsSinceEpoch(30, isUtc: true),
          updatedTime: DateTime.fromMillisecondsSinceEpoch(40, isUtc: true),
        ),
      ];
      final legacyBundle = ComposeDraftTransferBundle.fromLegacyNoteDraft(
        'legacy note draft',
      );

      expect(legacyBundle.mergeWithExistingOnRestore, isTrue);

      final merged = mergeComposeDraftRecords(
        existing: existing,
        incoming: <ComposeDraftRecord>[
          ComposeDraftRecord(
            uid: legacyBundle.drafts.single.uid,
            workspaceKey: 'ignored',
            snapshot: const ComposeDraftSnapshot(
              content: 'legacy note draft',
              visibility: 'PRIVATE',
            ),
            createdTime: DateTime.fromMillisecondsSinceEpoch(50, isUtc: true),
            updatedTime: DateTime.fromMillisecondsSinceEpoch(60, isUtc: true),
          ),
        ],
        workspaceKey: 'workspace-1',
      );

      expect(merged, hasLength(3));
      expect(
        merged.map((draft) => draft.uid),
        containsAll(<String>[
          'draft-existing-a',
          'draft-existing-b',
          'legacy_note_draft',
        ]),
      );
      expect(
        merged
            .firstWhere((draft) => draft.uid == 'legacy_note_draft')
            .snapshot
            .content,
        'legacy note draft',
      );
    },
  );

  test('edit draft metadata and existing attachments round-trip', () async {
    final supportDir = await Directory.systemTemp.createTemp(
      'compose_draft_transfer_edit_test_',
    );
    addTearDown(() async {
      if (await supportDir.exists()) {
        await supportDir.delete(recursive: true);
      }
    });
    const existingAttachment = Attachment(
      name: 'attachments/existing-1',
      filename: 'existing.png',
      type: 'image/png',
      size: 99,
      externalLink: 'https://example.com/existing.png',
      width: 320,
      height: 200,
      hash: 'hash-existing',
    );
    const pendingAttachment = ComposeDraftAttachment(
      uid: 'pending-1',
      filePath: '/tmp/source.txt',
      filename: 'source.txt',
      mimeType: 'text/plain',
      size: 11,
      skipCompression: true,
      sourceUrl: 'https://example.com/source.txt',
    );
    final targetUpdateTime = DateTime.utc(2025, 1, 2, 3, 4, 5);
    final record = ComposeDraftRecord(
      uid: 'edit-draft',
      workspaceKey: 'ignored',
      kind: ComposeDraftKind.editMemo,
      targetMemoUid: 'memo-1',
      targetMemoContentFingerprint: 'fingerprint-1',
      targetMemoUpdateTime: targetUpdateTime,
      snapshot: const ComposeDraftSnapshot(
        content: 'edit draft content',
        visibility: 'PROTECTED',
        relations: <Map<String, dynamic>>[
          <String, dynamic>{
            'relatedMemo': <String, dynamic>{'name': 'memos/memo-2'},
            'type': 'REFERENCE',
          },
        ],
        attachments: <ComposeDraftAttachment>[pendingAttachment],
        existingAttachments: <Attachment>[existingAttachment],
        location: MemoLocation(
          placeholder: 'Shanghai',
          latitude: 31.2304,
          longitude: 121.4737,
        ),
      ),
      createdTime: DateTime.fromMillisecondsSinceEpoch(10, isUtc: true),
      updatedTime: DateTime.fromMillisecondsSinceEpoch(20, isUtc: true),
    );

    final bundle = ComposeDraftTransferBundle.fromDraftRecords(
      <ComposeDraftRecord>[record],
    );
    final json = bundle.toJson();
    final decoded = ComposeDraftTransferBundle.fromJson(json);
    final decodedDraft = decoded.drafts.single;

    expect(decodedDraft.kind, ComposeDraftKind.editMemo);
    expect(decodedDraft.targetMemoUid, 'memo-1');
    expect(decodedDraft.targetMemoContentFingerprint, 'fingerprint-1');
    expect(decodedDraft.targetMemoUpdateTime, targetUpdateTime);
    expect(
      decodedDraft.existingAttachments.single.toJson(),
      existingAttachment.toJson(),
    );
    expect(decodedDraft.location?.placeholder, 'Shanghai');
    expect(decoded.draftAttachmentCount, 1);

    final attachmentPath = buildComposeDraftTransferAttachmentPath(
      draftUid: 'edit-draft',
      attachmentUid: 'pending-1',
      filename: 'source.txt',
    );
    final sourceFile = File(
      '${supportDir.path}${Platform.pathSeparator}${attachmentPath.replaceAll('/', Platform.pathSeparator)}',
    );
    await sourceFile.parent.create(recursive: true);
    await sourceFile.writeAsString('hello world', flush: true);

    final materialized = await materializeComposeDraftTransferBundle(
      bundle: decoded,
      rootDirectory: supportDir,
      workspaceKey: 'workspace-1',
      attachmentStager: QueuedAttachmentStager(
        resolveSupportDirectory: () async => supportDir,
      ),
    );

    final restored = materialized.single;
    expect(restored.workspaceKey, 'workspace-1');
    expect(restored.kind, ComposeDraftKind.editMemo);
    expect(restored.targetMemoUid, 'memo-1');
    expect(restored.targetMemoContentFingerprint, 'fingerprint-1');
    expect(restored.targetMemoUpdateTime, targetUpdateTime);
    expect(
      restored.snapshot.existingAttachments.single.toJson(),
      existingAttachment.toJson(),
    );
    expect(restored.snapshot.attachments.single.uid, 'pending-1');
    expect(restored.snapshot.attachments.single.skipCompression, isTrue);
    expect(
      restored.snapshot.attachments.single.sourceUrl,
      'https://example.com/source.txt',
    );
  });

  test('merge keeps one edit draft per target memo', () {
    final existing = <ComposeDraftRecord>[
      ComposeDraftRecord(
        uid: 'edit-old',
        workspaceKey: 'workspace-1',
        kind: ComposeDraftKind.editMemo,
        targetMemoUid: 'memo-1',
        snapshot: const ComposeDraftSnapshot(
          content: 'old edit',
          visibility: 'PRIVATE',
        ),
        createdTime: DateTime.fromMillisecondsSinceEpoch(10, isUtc: true),
        updatedTime: DateTime.fromMillisecondsSinceEpoch(20, isUtc: true),
      ),
    ];
    final incoming = <ComposeDraftRecord>[
      ComposeDraftRecord(
        uid: 'edit-new',
        workspaceKey: 'other',
        kind: ComposeDraftKind.editMemo,
        targetMemoUid: 'memo-1',
        snapshot: const ComposeDraftSnapshot(
          content: 'new edit',
          visibility: 'PUBLIC',
        ),
        createdTime: DateTime.fromMillisecondsSinceEpoch(30, isUtc: true),
        updatedTime: DateTime.fromMillisecondsSinceEpoch(40, isUtc: true),
      ),
    ];

    final merged = mergeComposeDraftRecords(
      existing: existing,
      incoming: incoming,
      workspaceKey: 'workspace-1',
    );

    expect(merged, hasLength(1));
    expect(merged.single.uid, 'edit-new');
    expect(merged.single.workspaceKey, 'workspace-1');
    expect(merged.single.snapshot.content, 'new edit');
  });
}
