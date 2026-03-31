import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/queued_attachment_stager.dart';
import 'package:memos_flutter_app/application/sync/compose_draft_transfer.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';

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
}
