import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/share_inline_image_content.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../data/models/memo_location.dart';
import '../../features/share/share_clip_models.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import 'memo_composer_state.dart';
import 'memo_mutation_service.dart';
import 'third_party_share_attachment_appender.dart';

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

@immutable
class NoteInputSubmitDraft {
  const NoteInputSubmitDraft({
    required this.content,
    required this.visibility,
    required this.location,
    required this.relations,
    required this.pendingAttachments,
    required this.deferredInlineImageRequests,
    this.clipMetadataDraft,
  });

  final String content;
  final String visibility;
  final MemoLocation? location;
  final List<Map<String, dynamic>> relations;
  final List<MemoComposerPendingAttachment> pendingAttachments;
  final List<ShareDeferredInlineImageAttachmentRequest>
  deferredInlineImageRequests;
  final ShareClipMetadataDraft? clipMetadataDraft;

  List<MemoComposerPendingAttachment> referencedPendingAttachments() {
    return filterNoteInputPendingAttachmentsForContent(
      content: content,
      pendingAttachments: pendingAttachments,
    );
  }

  bool get hasReferencedPendingAttachments {
    return referencedPendingAttachments().isNotEmpty;
  }
}

@immutable
class PreparedNoteInputSubmitDraft {
  const PreparedNoteInputSubmitDraft({
    required this.memoUid,
    required this.now,
    required this.content,
    required this.syncContent,
    required this.visibility,
    required this.tags,
    required this.attachments,
    required this.location,
    required this.hasAttachments,
    required this.relations,
    required this.pendingUploads,
    required this.deferredInlineImageRequests,
    this.clipMetadataDraft,
  });

  final String memoUid;
  final DateTime now;
  final String content;
  final String syncContent;
  final String visibility;
  final List<String> tags;
  final List<Map<String, dynamic>> attachments;
  final MemoLocation? location;
  final bool hasAttachments;
  final List<Map<String, dynamic>> relations;
  final List<NoteInputPendingAttachment> pendingUploads;
  final List<ShareDeferredInlineImageAttachmentRequest>
  deferredInlineImageRequests;
  final ShareClipMetadataDraft? clipMetadataDraft;
}

@immutable
class NoteInputSubmitResult {
  const NoteInputSubmitResult({
    required this.memoUid,
    required this.attachments,
    required this.pendingUploads,
    required this.deferredInlineImageRequests,
  });

  final String memoUid;
  final List<Map<String, dynamic>> attachments;
  final List<NoteInputPendingAttachment> pendingUploads;
  final List<ShareDeferredInlineImageAttachmentRequest>
  deferredInlineImageRequests;
}

typedef NoteInputSubmitSyncRequester = Future<void> Function();
typedef NoteInputSubmitInfoLogger =
    void Function(String message, {Map<String, Object?>? context});
typedef NoteInputSubmitWarnLogger =
    void Function(
      String message, {
      Object? error,
      StackTrace? stackTrace,
      Map<String, Object?>? context,
    });

class NoteInputSubmitCoordinator {
  NoteInputSubmitCoordinator({
    required NoteInputController controller,
    NoteInputSubmitSyncRequester? requestSync,
    NoteInputSubmitInfoLogger? logInfo,
    NoteInputSubmitWarnLogger? logWarn,
    String Function()? uidFactory,
    DateTime Function()? now,
    TagRecognitionPolicy Function()? currentTagRecognitionPolicy,
  }) : _controller = controller,
       _requestSync = requestSync,
       _logInfo = logInfo,
       _logWarn = logWarn,
       _uidFactory = uidFactory ?? generateUid,
       _now = now ?? DateTime.now,
       _currentTagRecognitionPolicy =
           currentTagRecognitionPolicy ??
           (() => TagRecognitionPolicy.defaultPolicy);

  final NoteInputController _controller;
  final NoteInputSubmitSyncRequester? _requestSync;
  final NoteInputSubmitInfoLogger? _logInfo;
  final NoteInputSubmitWarnLogger? _logWarn;
  final String Function() _uidFactory;
  final DateTime Function() _now;
  final TagRecognitionPolicy Function() _currentTagRecognitionPolicy;

  Future<NoteInputSubmitResult> submit(
    NoteInputSubmitDraft draft, {
    bool logShareSaveFlow = false,
  }) async {
    final prepared = prepareNoteInputSubmitDraft(
      draft,
      memoUid: _uidFactory(),
      now: _now(),
      tagRecognitionPolicy: _currentTagRecognitionPolicy(),
    );

    await _controller.createMemo(
      uid: prepared.memoUid,
      content: prepared.content,
      syncContent: prepared.syncContent,
      visibility: prepared.visibility,
      now: prepared.now,
      tags: prepared.tags,
      attachments: prepared.attachments,
      location: prepared.location,
      hasAttachments: prepared.hasAttachments,
      relations: prepared.relations,
      pendingAttachments: prepared.pendingUploads,
      clipMetadataDraft: prepared.clipMetadataDraft,
    );

    if (logShareSaveFlow) {
      _logInfo?.call(
        'ShareCompose: local_save_committed',
        context: <String, Object?>{
          'memoUid': prepared.memoUid,
          'attachmentCount': prepared.attachments.length,
          'pendingUploadCount': prepared.pendingUploads.length,
          'deferredInlineImageCount':
              prepared.deferredInlineImageRequests.length,
        },
      );
    }

    unawaited(
      _requestSyncBestEffort(
        memoUid: prepared.memoUid,
        logShareSaveFlow: logShareSaveFlow,
      ),
    );

    return NoteInputSubmitResult(
      memoUid: prepared.memoUid,
      attachments: prepared.attachments,
      pendingUploads: prepared.pendingUploads,
      deferredInlineImageRequests: prepared.deferredInlineImageRequests,
    );
  }

  Future<void> _requestSyncBestEffort({
    required String memoUid,
    required bool logShareSaveFlow,
  }) async {
    final requestSync = _requestSync;
    if (requestSync == null) return;

    if (logShareSaveFlow) {
      _logInfo?.call(
        'ShareCompose: background_sync_requested',
        context: <String, Object?>{'memoUid': memoUid},
      );
    }

    try {
      await requestSync();
    } catch (error, stackTrace) {
      if (!logShareSaveFlow) return;
      _logWarn?.call(
        'ShareCompose: background_sync_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'memoUid': memoUid},
      );
    }
  }
}

PreparedNoteInputSubmitDraft prepareNoteInputSubmitDraft(
  NoteInputSubmitDraft draft, {
  required String memoUid,
  required DateTime now,
  TagRecognitionPolicy tagRecognitionPolicy =
      TagRecognitionPolicy.defaultPolicy,
}) {
  final content = draft.content.trimRight();
  final pendingAttachments =
      filterNoteInputPendingAttachmentsForContent(
        content: content,
        pendingAttachments: draft.pendingAttachments,
      )..sort((left, right) {
        return switch ((left.shareInlineImage, right.shareInlineImage)) {
          (true, false) => 1,
          (false, true) => -1,
          _ => 0,
        };
      });
  final deferredInlineImageRequests =
      filterNoteInputDeferredInlineImageRequestsForContent(
        content: content,
        requests: draft.deferredInlineImageRequests,
      );
  final attachments = pendingAttachments
      .map(noteInputAttachmentJsonFromPendingAttachment)
      .toList(growable: false);
  final pendingUploads = pendingAttachments
      .map(noteInputPendingUploadFromComposerAttachment)
      .toList(growable: false);

  return PreparedNoteInputSubmitDraft(
    memoUid: memoUid,
    now: now,
    content: content,
    syncContent: content,
    visibility: draft.visibility,
    tags: extractTags(content, policy: tagRecognitionPolicy),
    attachments: attachments,
    location: draft.location,
    hasAttachments: pendingUploads.isNotEmpty,
    relations: draft.relations,
    pendingUploads: pendingUploads,
    deferredInlineImageRequests: deferredInlineImageRequests,
    clipMetadataDraft: draft.clipMetadataDraft,
  );
}

List<MemoComposerPendingAttachment>
filterNoteInputPendingAttachmentsForContent({
  required String content,
  required Iterable<MemoComposerPendingAttachment> pendingAttachments,
}) {
  return pendingAttachments
      .where(
        (attachment) =>
            !attachment.shareInlineImage ||
            contentContainsShareInlineLocalUrl(content, attachment.filePath),
      )
      .toList(growable: true);
}

List<ShareDeferredInlineImageAttachmentRequest>
filterNoteInputDeferredInlineImageRequestsForContent({
  required String content,
  required Iterable<ShareDeferredInlineImageAttachmentRequest> requests,
}) {
  return requests
      .where(
        (request) =>
            contentContainsShareInlineImageUrl(content, request.sourceUrl),
      )
      .toList(growable: false);
}

Map<String, dynamic> noteInputAttachmentJsonFromPendingAttachment(
  MemoComposerPendingAttachment attachment,
) {
  final rawPath = attachment.filePath.trim();
  final externalLink = rawPath.isEmpty
      ? ''
      : rawPath.startsWith('content://')
      ? rawPath
      : Uri.file(rawPath).toString();
  return Attachment(
    name: 'attachments/${attachment.uid}',
    filename: attachment.filename,
    type: attachment.mimeType,
    size: attachment.size,
    externalLink: externalLink,
  ).toJson();
}

NoteInputPendingAttachment noteInputPendingUploadFromComposerAttachment(
  MemoComposerPendingAttachment attachment,
) {
  return NoteInputPendingAttachment(
    uid: attachment.uid,
    filePath: attachment.filePath,
    filename: attachment.filename,
    mimeType: attachment.mimeType,
    size: attachment.size,
    skipCompression: attachment.skipCompression,
    shareInlineImage: attachment.shareInlineImage,
    fromThirdPartyShare: attachment.fromThirdPartyShare,
    sourceUrl: attachment.sourceUrl,
  );
}

NoteInputPendingAttachment noteInputPendingUploadFromShareAttachmentSeed(
  ShareAttachmentSeed seed, {
  required String sourceUrl,
}) {
  return NoteInputPendingAttachment(
    uid: seed.uid,
    filePath: seed.filePath,
    filename: seed.filename,
    mimeType: seed.mimeType,
    size: seed.size,
    skipCompression: seed.skipCompression,
    shareInlineImage: true,
    fromThirdPartyShare: true,
    sourceUrl: sourceUrl,
  );
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
    await _ref
        .read(thirdPartyShareAttachmentAppenderProvider)
        .append(
          ThirdPartyShareAttachmentAppendRequest(
            memoUid: memoUid,
            attachmentUid: attachment.uid,
            filePath: attachment.filePath,
            filename: attachment.filename,
            mimeType: attachment.mimeType,
            size: attachment.size,
            kind: ThirdPartyShareAttachmentKind.inlineImage,
            skipCompression: attachment.skipCompression,
            shareInlineImage: attachment.shareInlineImage,
            fromThirdPartyShare: attachment.fromThirdPartyShare,
            sourceUrl: attachment.sourceUrl,
            replaceSourceUrl: sourceUrl,
          ),
        );
  }
}
