import 'dart:io';

import '../../data/models/attachment.dart';
import '../../state/memos/memo_composer_state.dart';
import '../image_preview/image_preview_item.dart';
import 'memo_image_grid.dart';

ImagePreviewItem pendingAttachmentToImagePreviewItem(
  MemoComposerPendingAttachment attachment, {
  required String sourceId,
  File? localFile,
}) {
  final resolvedLocalFile =
      localFile ??
      (attachment.filePath.trim().isEmpty
          ? null
          : File(attachment.filePath.trim()));
  return ImagePreviewItem(
    id: sourceId,
    title: attachment.filename,
    mimeType: attachment.mimeType,
    localFile: resolvedLocalFile,
  );
}

ImagePreviewItem? attachmentToImagePreviewItem(
  Attachment attachment,
  Uri? baseUrl,
  String? authHeader, {
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  final entry = memoImageEntryFromAttachment(
    attachment,
    baseUrl,
    authHeader,
    rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
    attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
  );
  return entry?.toImagePreviewItem();
}

ImagePreviewItem memoImageEntryToImagePreviewItem(MemoImageEntry entry) {
  return entry.toImagePreviewItem();
}

List<ImagePreviewItem> collectMemoDocumentImagePreviewItems({
  required String content,
  required List<Attachment> attachments,
  required Uri? baseUrl,
  required String? authHeader,
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  return collectMemoImageEntries(
    content: content,
    attachments: attachments,
    baseUrl: baseUrl,
    authHeader: authHeader,
    rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
    attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
  ).map((entry) => entry.toImagePreviewItem()).toList(growable: false);
}
