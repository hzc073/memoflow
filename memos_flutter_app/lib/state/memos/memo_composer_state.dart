import 'package:flutter/material.dart';

enum AttachmentProcessingStatus { staging, ready, failed }

class MemoComposerPendingAttachment {
  const MemoComposerPendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.skipCompression = false,
    this.shareInlineImage = false,
    this.fromThirdPartyShare = false,
    this.sourceUrl,
    this.processingStatus = AttachmentProcessingStatus.ready,
    this.processingError,
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
  final AttachmentProcessingStatus processingStatus;
  final String? processingError;

  bool get isReadyForSubmit =>
      processingStatus == AttachmentProcessingStatus.ready;

  bool get isProcessing =>
      processingStatus == AttachmentProcessingStatus.staging;

  bool get hasProcessingFailure =>
      processingStatus == AttachmentProcessingStatus.failed;

  MemoComposerPendingAttachment copyWith({
    String? uid,
    String? filePath,
    String? filename,
    String? mimeType,
    int? size,
    bool? skipCompression,
    bool? shareInlineImage,
    bool? fromThirdPartyShare,
    Object? sourceUrl = memoComposerStateNoChange,
    AttachmentProcessingStatus? processingStatus,
    Object? processingError = memoComposerStateNoChange,
  }) {
    return MemoComposerPendingAttachment(
      uid: uid ?? this.uid,
      filePath: filePath ?? this.filePath,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      skipCompression: skipCompression ?? this.skipCompression,
      shareInlineImage: shareInlineImage ?? this.shareInlineImage,
      fromThirdPartyShare: fromThirdPartyShare ?? this.fromThirdPartyShare,
      sourceUrl: identical(sourceUrl, memoComposerStateNoChange)
          ? this.sourceUrl
          : sourceUrl as String?,
      processingStatus: processingStatus ?? this.processingStatus,
      processingError: identical(processingError, memoComposerStateNoChange)
          ? this.processingError
          : processingError as String?,
    );
  }
}

class MemoComposerLinkedMemo {
  const MemoComposerLinkedMemo({required this.name, required this.label});

  final String name;
  final String label;

  Map<String, dynamic> toRelationJson() {
    return {
      'relatedMemo': {'name': name},
      'type': 'REFERENCE',
    };
  }
}

@immutable
class MemoComposerState {
  const MemoComposerState({
    this.pendingAttachments = const <MemoComposerPendingAttachment>[],
    this.linkedMemos = const <MemoComposerLinkedMemo>[],
    this.tagAutocompleteIndex = 0,
    this.tagAutocompleteToken,
    this.canUndo = false,
    this.canRedo = false,
  });

  final List<MemoComposerPendingAttachment> pendingAttachments;
  final List<MemoComposerLinkedMemo> linkedMemos;
  final int tagAutocompleteIndex;
  final String? tagAutocompleteToken;
  final bool canUndo;
  final bool canRedo;

  MemoComposerState copyWith({
    List<MemoComposerPendingAttachment>? pendingAttachments,
    List<MemoComposerLinkedMemo>? linkedMemos,
    int? tagAutocompleteIndex,
    Object? tagAutocompleteToken = memoComposerStateNoChange,
    bool? canUndo,
    bool? canRedo,
  }) {
    return MemoComposerState(
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
      linkedMemos: linkedMemos ?? this.linkedMemos,
      tagAutocompleteIndex: tagAutocompleteIndex ?? this.tagAutocompleteIndex,
      tagAutocompleteToken:
          identical(tagAutocompleteToken, memoComposerStateNoChange)
          ? this.tagAutocompleteToken
          : tagAutocompleteToken as String?,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }
}

const Object memoComposerStateNoChange = Object();
