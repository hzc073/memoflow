import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/compose_draft_transfer.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_bundle.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_codec.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_models.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';

void main() {
  test('encode fails when draft attachment file is missing', () {
    final codec = const ConfigTransferCodec();
    final bundle = ConfigTransferBundle(
      draftBox: ComposeDraftTransferBundle.fromDraftRecords(
        <ComposeDraftRecord>[
          ComposeDraftRecord(
            uid: 'draft-1',
            workspaceKey: 'workspace-1',
            snapshot: const ComposeDraftSnapshot(
              content: 'draft with missing attachment',
              visibility: 'PRIVATE',
              attachments: <ComposeDraftAttachment>[
                ComposeDraftAttachment(
                  uid: 'attachment-1',
                  filePath: 'Z:/definitely-missing/attachment.txt',
                  filename: 'attachment.txt',
                  mimeType: 'text/plain',
                  size: 10,
                ),
              ],
            ),
            createdTime: DateTime.fromMillisecondsSinceEpoch(10, isUtc: true),
            updatedTime: DateTime.fromMillisecondsSinceEpoch(20, isUtc: true),
          ),
        ],
      ),
    );

    expect(
      () => codec.encode(
        bundle,
        configTypes: const <MemoFlowMigrationConfigType>{
          MemoFlowMigrationConfigType.draftBox,
        },
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
