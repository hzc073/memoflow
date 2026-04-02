import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tags.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_location.dart';
import '../../features/share/share_inline_image_content.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import 'create_memo_outbox_enqueue.dart';
import 'create_memo_outbox_payload.dart';
import 'memo_sync_constraints.dart';
import '../system/database_provider.dart';

class NoteInputPendingAttachment {
  const NoteInputPendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.skipCompression = false,
    this.shareInlineImage = false,
    this.fromThirdPartyShare = false,
    this.sourceUrl,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final bool skipCompression;
  final bool shareInlineImage;
  final bool fromThirdPartyShare;
  final String? sourceUrl;
}

class NoteInputController {
  NoteInputController(this._ref);

  final Ref _ref;

  Future<void> createMemo({
    required String uid,
    required String content,
    String? syncContent,
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
    final queuedAttachmentStager = _ref.read(queuedAttachmentStagerProvider);

    final attachmentPayloads = await queuedAttachmentStager.stageUploadPayloads(
      pendingAttachments
          .map(
            (attachment) => <String, dynamic>{
              'uid': attachment.uid,
              'memo_uid': uid,
              'file_path': attachment.filePath,
              'filename': attachment.filename,
              'mime_type': attachment.mimeType,
              'file_size': attachment.size,
              'skip_compression': attachment.skipCompression,
              'share_inline_image': attachment.shareInlineImage,
              'from_third_party_share': attachment.fromThirdPartyShare,
              if (attachment.shareInlineImage)
                'share_inline_local_url': Uri.file(
                  attachment.filePath,
                ).toString(),
            },
          )
          .toList(growable: false),
      scopeKey: uid,
    );
    final localAttachments = mergePendingAttachmentPlaceholders(
      attachments: attachments,
      pendingAttachments: attachmentPayloads,
    );

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: localAttachments,
      location: location,
      relationCount: 0,
      syncState: 1,
    );

    for (final payload in attachmentPayloads) {
      NoteInputPendingAttachment? matchedAttachment;
      for (final attachment in pendingAttachments) {
        if (attachment.uid == payload['uid']) {
          matchedAttachment = attachment;
          break;
        }
      }
      final sourceUrl = matchedAttachment?.sourceUrl?.trim();
      final shareInlineImage = payload['share_inline_image'] == true;
      final fromThirdPartyShare = payload['from_third_party_share'] == true;
      final localUrl = (payload['share_inline_local_url'] as String? ?? '')
          .trim();
      if (shareInlineImage &&
          fromThirdPartyShare &&
          sourceUrl != null &&
          sourceUrl.isNotEmpty &&
          localUrl.isNotEmpty) {
        await db.upsertMemoInlineImageSource(
          memoUid: uid,
          localUrl: localUrl,
          sourceUrl: sourceUrl,
        );
      }
    }

    await enqueueCreateMemoWithAttachmentUploads(
      read: _ref.read,
      db: db,
      createPayload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: syncContent ?? content,
        visibility: visibility,
        pinned: false,
        createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        hasAttachments: hasAttachments,
        location: location,
        relations: relations,
      ),
      attachmentPayloads: attachmentPayloads,
    );
  }

  Future<void> appendDeferredThirdPartyShareInlineImage({
    required String memoUid,
    required String sourceUrl,
    required NoteInputPendingAttachment attachment,
  }) async {
    final db = _ref.read(databaseProvider);
    final queuedAttachmentStager = _ref.read(queuedAttachmentStagerProvider);
    final stagedAttachmentData = await queuedAttachmentStager
        .stageDraftAttachment(
          uid: attachment.uid,
          filePath: attachment.filePath,
          filename: attachment.filename,
          mimeType: attachment.mimeType,
          size: attachment.size,
          scopeKey: memoUid,
        );
    final stagedAttachment = NoteInputPendingAttachment(
      uid: attachment.uid,
      filePath: stagedAttachmentData.filePath,
      filename: stagedAttachmentData.filename,
      mimeType: stagedAttachmentData.mimeType,
      size: stagedAttachmentData.size,
      skipCompression: attachment.skipCompression,
      shareInlineImage: attachment.shareInlineImage,
      fromThirdPartyShare: attachment.fromThirdPartyShare,
      sourceUrl: attachment.sourceUrl,
    );
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }

    final memo = LocalMemo.fromDb(row);
    final localUrl = Uri.file(stagedAttachment.filePath).toString();
    final normalizedSourceUrl =
        stagedAttachment.sourceUrl?.trim() ?? sourceUrl.trim();
    final updatedContent = replaceShareInlineImageUrl(
      memo.content,
      fromUrl: sourceUrl,
      toUrl: localUrl,
    );
    if (updatedContent == memo.content) {
      return;
    }

    final updatedAttachments = <Map<String, dynamic>>[
      ...memo.attachments.map((item) => item.toJson()),
      Attachment(
        name: 'attachments/${stagedAttachment.uid}',
        filename: stagedAttachment.filename,
        type: stagedAttachment.mimeType,
        size: stagedAttachment.size,
        externalLink: localUrl,
      ).toJson(),
    ];
    final now = DateTime.now().toUtc();
    final syncPolicy = resolveMemoSyncMutationPolicy(
      currentLastError: memo.lastError,
    );

    await db.upsertMemo(
      uid: memo.uid,
      content: updatedContent,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: extractTags(updatedContent),
      attachments: updatedAttachments,
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: syncPolicy.syncState,
      lastError: syncPolicy.lastError,
    );

    if (normalizedSourceUrl.isNotEmpty) {
      await db.upsertMemoInlineImageSource(
        memoUid: memo.uid,
        localUrl: localUrl,
        sourceUrl: normalizedSourceUrl,
      );
    }

    final allowed =
        syncPolicy.allowRemoteSync &&
        await guardMemoContentForCurrentSyncTarget(
          read: _ref.read,
          db: db,
          memoUid: memo.uid,
          content: updatedContent,
        );
    if (allowed) {
      await db.enqueueOutbox(
        type: 'update_memo',
        payload: {
          'uid': memo.uid,
          'content': updatedContent,
          'visibility': memo.visibility,
          'pinned': memo.pinned,
        },
      );
      final stagedPayload = await queuedAttachmentStager.stageUploadPayload({
        'uid': stagedAttachment.uid,
        'memo_uid': memo.uid,
        'file_path': stagedAttachment.filePath,
        'filename': stagedAttachment.filename,
        'mime_type': stagedAttachment.mimeType,
        'file_size': stagedAttachment.size,
        'skip_compression': stagedAttachment.skipCompression,
        'share_inline_image': true,
        'from_third_party_share': true,
        'share_inline_local_url': localUrl,
      }, scopeKey: memo.uid);
      await db.enqueueOutbox(type: 'upload_attachment', payload: stagedPayload);
    }
  }
}
