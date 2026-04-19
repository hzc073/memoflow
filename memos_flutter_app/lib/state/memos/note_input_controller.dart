import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_location.dart';
import '../../features/share/share_clip_models.dart';
import '../../features/share/share_inline_image_content.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import 'memo_mutation_service.dart';
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
    ShareClipMetadataDraft? clipMetadataDraft,
  }) async {
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
    final inlineImageSourceMappings = <Map<String, String>>[];
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
        inlineImageSourceMappings.add(<String, String>{
          'localUrl': localUrl,
          'sourceUrl': sourceUrl,
        });
      }
    }

    await _ref
        .read(memoMutationServiceProvider)
        .createNoteInputMemo(
          uid: uid,
          content: content,
          syncContent: syncContent,
          visibility: visibility,
          now: now,
          tags: tags,
          attachments: attachments,
          location: location,
          hasAttachments: hasAttachments,
          relations: relations,
          attachmentPayloads: attachmentPayloads,
          inlineImageSourceMappings: inlineImageSourceMappings,
          clipMetadataDraft: clipMetadataDraft,
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
    final originalLocalUrl = shareInlineLocalUrlFromPath(attachment.filePath);
    final normalizedSourceUrl =
        stagedAttachment.sourceUrl?.trim() ?? sourceUrl.trim();
    var updatedContent = replaceShareInlineImageUrl(
      memo.content,
      fromUrl: sourceUrl,
      toUrl: localUrl,
    );
    if (originalLocalUrl.isNotEmpty && originalLocalUrl != localUrl) {
      updatedContent = replaceShareInlineImageUrl(
        updatedContent,
        fromUrl: originalLocalUrl,
        toUrl: localUrl,
      );
    }
    final contentAlreadyContainsLocalUrl = contentContainsShareInlineImageUrl(
      updatedContent,
      localUrl,
    );
    final attachmentAlreadyExists = memo.attachments.any(
      (item) => item.externalLink.trim() == localUrl,
    );
    if (attachmentAlreadyExists) {
      return;
    }
    if (updatedContent == memo.content && !contentAlreadyContainsLocalUrl) {
      return;
    }
    final nextContent = updatedContent == memo.content
        ? memo.content
        : updatedContent;

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
    await _ref
        .read(memoMutationServiceProvider)
        .appendDeferredThirdPartyShareInlineImage(
          memo: memo,
          updatedContent: nextContent,
          updatedAttachments: updatedAttachments,
          localUrl: localUrl,
          normalizedSourceUrl: normalizedSourceUrl,
          stagedUploadPayload: stagedPayload,
        );
  }
}
