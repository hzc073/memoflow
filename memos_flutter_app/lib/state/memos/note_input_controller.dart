import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/memo_location.dart';
import '../database_provider.dart';

class NoteInputPendingAttachment {
  const NoteInputPendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}

class NoteInputController {
  NoteInputController(this._ref);

  final Ref _ref;

  Future<void> createMemo({
    required String uid,
    required String content,
    required String visibility,
    required DateTime now,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required bool hasAttachments,
    required List<Map<String, dynamic>> relations,
    required List<NoteInputPendingAttachment> pendingAttachments,
  }) async {
    final db = _ref.read(databaseProvider);

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: attachments,
      location: location,
      relationCount: 0,
      syncState: 1,
    );

    await db.enqueueOutbox(
      type: 'create_memo',
      payload: {
        'uid': uid,
        'content': content,
        'visibility': visibility,
        'pinned': false,
        'has_attachments': hasAttachments,
        if (location != null) 'location': location.toJson(),
        if (relations.isNotEmpty) 'relations': relations,
      },
    );

    for (final attachment in pendingAttachments) {
      await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': attachment.uid,
          'memo_uid': uid,
          'file_path': attachment.filePath,
          'filename': attachment.filename,
          'mime_type': attachment.mimeType,
          'file_size': attachment.size,
        },
      );
    }
  }
}
