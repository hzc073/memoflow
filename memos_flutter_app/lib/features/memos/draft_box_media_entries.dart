import 'dart:io';

import '../../data/models/compose_draft.dart';
import 'memo_image_grid.dart';
import 'memo_image_src_normalizer.dart';
import 'memo_media_grid.dart';
import 'memo_video_grid.dart';

List<MemoMediaEntry> buildDraftBoxMediaEntries(ComposeDraftSnapshot snapshot) {
  final entries = <MemoMediaEntry>[];
  final seen = <String>{};

  final inlineImageUrls = extractMemoImageUrls(snapshot.content);
  for (var index = 0; index < inlineImageUrls.length; index++) {
    final entry = _imageEntryFromInlineUrl(inlineImageUrls[index], index);
    if (entry == null) continue;
    final key = _mediaDedupKey(
      localPath: entry.localFile?.path,
      remotePath: entry.fullUrl ?? entry.previewUrl,
    );
    if (key == null || !seen.add(key)) continue;
    entries.add(MemoMediaEntry.image(entry));
  }

  for (final attachment in snapshot.attachments) {
    final mimeType = attachment.mimeType.trim().toLowerCase();
    if (mimeType.startsWith('image/')) {
      final entry = _imageEntryFromAttachment(attachment);
      if (entry == null) continue;
      final key = _mediaDedupKey(
        localPath: entry.localFile?.path,
        remotePath: entry.fullUrl ?? entry.previewUrl,
      );
      if (key == null || !seen.add(key)) continue;
      entries.add(MemoMediaEntry.image(entry));
      continue;
    }
    if (mimeType.startsWith('video/')) {
      final entry = _videoEntryFromAttachment(attachment);
      if (entry == null) continue;
      final key = _mediaDedupKey(
        localPath: entry.localFile?.path,
        remotePath: entry.videoUrl,
      );
      if (key == null || !seen.add(key)) continue;
      entries.add(MemoMediaEntry.video(entry));
    }
  }

  return entries;
}

int countDraftNonMediaAttachments(ComposeDraftSnapshot snapshot) {
  return snapshot.attachments.where((attachment) {
    final mimeType = attachment.mimeType.trim().toLowerCase();
    return !mimeType.startsWith('image/') && !mimeType.startsWith('video/');
  }).length;
}

MemoImageEntry? _imageEntryFromInlineUrl(String rawUrl, int index) {
  final normalized = normalizeMarkdownImageSrc(rawUrl).trim();
  if (normalized.isEmpty) return null;

  final localFile = _resolveLocalFile(normalized);
  if (localFile != null) {
    return MemoImageEntry(
      id: 'draft_inline_$index',
      title: _titleFromRawValue(normalized, fallback: 'image'),
      mimeType: 'image/*',
      localFile: localFile,
    );
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme) return null;
  return MemoImageEntry(
    id: 'draft_inline_$index',
    title: _titleFromRawValue(normalized, fallback: 'image'),
    mimeType: 'image/*',
    previewUrl: normalized,
    fullUrl: normalized,
  );
}

MemoImageEntry? _imageEntryFromAttachment(ComposeDraftAttachment attachment) {
  final localFile = _resolveLocalFile(attachment.filePath);
  final normalizedSourceUrl = attachment.sourceUrl == null
      ? null
      : normalizeMarkdownImageSrc(attachment.sourceUrl!).trim();
  if (localFile == null &&
      (normalizedSourceUrl == null || normalizedSourceUrl.isEmpty)) {
    return MemoImageEntry(
      id: attachment.uid,
      title: _attachmentTitle(attachment, fallback: 'image'),
      mimeType: attachment.mimeType.trim().isEmpty
          ? 'image/*'
          : attachment.mimeType.trim(),
      isAttachment: true,
    );
  }

  return MemoImageEntry(
    id: attachment.uid,
    title: _attachmentTitle(attachment, fallback: 'image'),
    mimeType: attachment.mimeType.trim().isEmpty
        ? 'image/*'
        : attachment.mimeType.trim(),
    localFile: localFile,
    previewUrl: normalizedSourceUrl?.isEmpty == true
        ? null
        : normalizedSourceUrl,
    fullUrl: normalizedSourceUrl?.isEmpty == true ? null : normalizedSourceUrl,
    isAttachment: true,
  );
}

MemoVideoEntry? _videoEntryFromAttachment(ComposeDraftAttachment attachment) {
  final localFile = _resolveLocalFile(attachment.filePath);
  final normalizedSourceUrl = attachment.sourceUrl == null
      ? null
      : normalizeMarkdownImageSrc(attachment.sourceUrl!).trim();
  if (localFile == null &&
      (normalizedSourceUrl == null || normalizedSourceUrl.isEmpty)) {
    return null;
  }

  return MemoVideoEntry(
    id: attachment.uid,
    title: _attachmentTitle(attachment, fallback: 'video'),
    mimeType: attachment.mimeType.trim().isEmpty
        ? 'video/*'
        : attachment.mimeType.trim(),
    size: attachment.size,
    localFile: localFile,
    videoUrl: normalizedSourceUrl?.isEmpty == true ? null : normalizedSourceUrl,
    thumbnailUrl: null,
    headers: null,
  );
}

File? _resolveLocalFile(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('file://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final file = File.fromUri(uri);
    return file.existsSync() ? file : null;
  }

  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed)) {
    final file = File(trimmed);
    return file.existsSync() ? file : null;
  }

  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) {
    return null;
  }

  final file = File(trimmed);
  return file.existsSync() ? file : null;
}

String? _mediaDedupKey({String? localPath, String? remotePath}) {
  final local = (localPath ?? '').trim();
  if (local.isNotEmpty) {
    final normalized = File(local).absolute.path.replaceAll('\\', '/');
    return 'local:${normalized.toLowerCase()}';
  }
  final remote = (remotePath ?? '').trim();
  if (remote.isNotEmpty) return 'remote:$remote';
  return null;
}

String _attachmentTitle(
  ComposeDraftAttachment attachment, {
  required String fallback,
}) {
  final filename = attachment.filename.trim();
  if (filename.isNotEmpty) return filename;
  return _titleFromRawValue(
    attachment.sourceUrl?.trim().isNotEmpty == true
        ? attachment.sourceUrl!
        : attachment.filePath,
    fallback: fallback,
  );
}

String _titleFromRawValue(String raw, {required String fallback}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  if (trimmed.startsWith('file://')) {
    final uri = Uri.tryParse(trimmed);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    return segment.isEmpty ? fallback : Uri.decodeComponent(segment);
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    final segment = uri.pathSegments.last.trim();
    if (segment.isNotEmpty) {
      return Uri.decodeComponent(segment);
    }
  }
  final path = trimmed.replaceAll('\\', '/');
  final segment = path.split('/').last.trim();
  return segment.isEmpty ? fallback : segment;
}
