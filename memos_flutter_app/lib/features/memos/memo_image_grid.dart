import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/image_thumbnail_cache.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../image_preview/image_preview_item.dart';
import '../image_preview/image_preview_launcher.dart';
import '../image_preview/image_preview_open_request.dart';
import '../image_preview/widgets/image_preview_tile.dart';
import 'attachment_gallery_screen.dart';
import 'memo_markdown.dart';

class MemoImageEntry {
  const MemoImageEntry({
    required this.id,
    required this.title,
    required this.mimeType,
    this.localFile,
    this.previewUrl,
    this.fullUrl,
    this.headers,
    this.isAttachment = false,
    this.width,
    this.height,
  });

  final String id;
  final String title;
  final String mimeType;
  final File? localFile;
  final String? previewUrl;
  final String? fullUrl;
  final Map<String, String>? headers;
  final bool isAttachment;
  final int? width;
  final int? height;

  AttachmentImageSource toGallerySource() {
    final url = (fullUrl ?? previewUrl ?? '').trim();
    return AttachmentImageSource(
      id: id,
      title: title,
      mimeType: mimeType,
      localFile: localFile,
      imageUrl: url.isEmpty ? null : url,
      headers: headers,
      width: width,
      height: height,
    );
  }

  ImagePreviewItem toImagePreviewItem() {
    return ImagePreviewItem(
      id: id,
      title: title,
      mimeType: mimeType,
      localFile: localFile,
      thumbnailUrl: previewUrl,
      fullUrl: fullUrl,
      headers: headers,
      width: width,
      height: height,
    );
  }
}

List<MemoImageEntry> collectMemoImageEntries({
  required String content,
  required List<Attachment> attachments,
  required Uri? baseUrl,
  required String? authHeader,
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  final entries = <MemoImageEntry>[];
  final seen = <String>{};

  final contentImageUrls = extractMemoImageUrls(content);
  for (var i = 0; i < contentImageUrls.length; i++) {
    final entry = _entryFromContentUrl(
      rawUrl: contentImageUrls[i],
      index: i,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    if (entry == null) continue;
    final key =
        (entry.localFile?.path ?? entry.fullUrl ?? entry.previewUrl ?? '')
            .trim();
    if (key.isEmpty || !seen.add(key)) continue;
    entries.add(entry);
  }

  for (final attachment in attachments) {
    final type = attachment.type.trim().toLowerCase();
    if (!type.startsWith('image')) continue;
    final entry = _entryFromAttachment(
      attachment,
      baseUrl,
      authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    if (entry == null) continue;
    final key =
        (entry.localFile?.path ?? entry.fullUrl ?? entry.previewUrl ?? '')
            .trim();
    if (key.isEmpty || !seen.add(key)) continue;
    entries.add(entry);
  }

  return entries;
}

MemoImageEntry? memoImageEntryFromAttachment(
  Attachment attachment,
  Uri? baseUrl,
  String? authHeader, {
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  return _entryFromAttachment(
    attachment,
    baseUrl,
    authHeader,
    rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
    attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
  );
}

MemoImageEntry? _entryFromContentUrl({
  required String rawUrl,
  required int index,
  required Uri? baseUrl,
  required String? authHeader,
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  final normalized = normalizeMarkdownImageSrc(rawUrl).trim();
  if (normalized.isEmpty) return null;

  final localFile = _resolveLocalFile(normalized);
  if (localFile != null) {
    return MemoImageEntry(
      id: 'inline_$index',
      title: _titleFromUrl(normalized),
      mimeType: 'image/*',
      localFile: localFile,
      isAttachment: false,
    );
  }

  final resolved = _resolveRemoteImageDisplay(
    rawUrl: normalized,
    baseUrl: baseUrl,
    authHeader: authHeader,
    rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
    attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
  );
  if (resolved == null) return null;
  return MemoImageEntry(
    id: 'inline_$index',
    title: _titleFromUrl(normalized),
    mimeType: 'image/*',
    previewUrl: resolved.previewUrl,
    fullUrl: resolved.fullUrl,
    headers: resolved.headers,
    isAttachment: false,
  );
}

MemoImageEntry? _entryFromAttachment(
  Attachment attachment,
  Uri? baseUrl,
  String? authHeader, {
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  final external = attachment.externalLink.trim();
  final localFile = _resolveLocalFile(external);
  final mimeType = attachment.type.trim().isEmpty
      ? 'image/*'
      : attachment.type.trim();
  final title = attachment.filename.trim().isNotEmpty
      ? attachment.filename.trim()
      : attachment.uid;

  if (localFile != null) {
    return MemoImageEntry(
      id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
      title: title.isEmpty ? 'image' : title,
      mimeType: mimeType,
      localFile: localFile,
      previewUrl: null,
      fullUrl: null,
      headers: null,
      isAttachment: true,
      width: attachment.width,
      height: attachment.height,
    );
  }

  if (external.isNotEmpty) {
    final resolved = _resolveRemoteImageDisplay(
      rawUrl: external,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    if (resolved == null) return null;
    return MemoImageEntry(
      id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
      title: title.isEmpty ? _titleFromUrl(external) : title,
      mimeType: mimeType,
      previewUrl: resolved.previewUrl,
      fullUrl: resolved.fullUrl,
      headers: resolved.headers,
      isAttachment: true,
      width: attachment.width,
      height: attachment.height,
    );
  }

  if (baseUrl == null) return null;
  final name = attachment.name.trim();
  final filename = attachment.filename.trim();
  if (name.isEmpty || filename.isEmpty) return null;
  final fullUrl = joinBaseUrl(baseUrl, 'file/$name/$filename');
  final previewUrl = appendThumbnailParam(fullUrl);
  final headers = (authHeader == null || authHeader.trim().isEmpty)
      ? null
      : {'Authorization': authHeader.trim()};
  return MemoImageEntry(
    id: name,
    title: title.isEmpty ? filename : title,
    mimeType: mimeType,
    previewUrl: previewUrl,
    fullUrl: fullUrl,
    headers: headers,
    isAttachment: true,
    width: attachment.width,
    height: attachment.height,
  );
}

({String fullUrl, String previewUrl, Map<String, String>? headers})?
_resolveRemoteImageDisplay({
  required String rawUrl,
  required Uri? baseUrl,
  required String? authHeader,
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  final rawWasRelative = !isAbsoluteUrl(trimmed);
  var resolved = resolveMaybeRelativeUrl(baseUrl, trimmed);
  if (rebaseAbsoluteFileUrlForV024) {
    final rebased = rebaseAbsoluteFileUrlToBase(baseUrl, resolved);
    if (rebased != null && rebased.isNotEmpty) {
      resolved = rebased;
    }
  }

  final sameOriginAbsolute = isSameOriginWithBase(baseUrl, resolved);
  final shouldAttachAuth =
      rawWasRelative ||
      sameOriginAbsolute ||
      (attachAuthForSameOriginAbsolute && sameOriginAbsolute);
  final headers =
      (shouldAttachAuth && authHeader != null && authHeader.trim().isNotEmpty)
      ? {'Authorization': authHeader.trim()}
      : null;

  final previewUrl = _shouldUseThumbnailPreview(resolved)
      ? appendThumbnailParam(resolved)
      : resolved;

  return (fullUrl: resolved, previewUrl: previewUrl, headers: headers);
}

bool _shouldUseThumbnailPreview(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return false;
  final path = parsed.path;
  return path.startsWith('/file/') ||
      path.startsWith('file/') ||
      path.contains('/o/r/') ||
      path.startsWith('o/r/');
}

File? _resolveLocalFile(String externalLink) {
  if (!externalLink.startsWith('file://')) return null;
  final uri = Uri.tryParse(externalLink);
  if (uri == null) return null;
  String path;
  try {
    path = uri.toFilePath();
  } catch (_) {
    return null;
  }
  if (path.trim().isEmpty) return null;
  return File(path);
}

String _titleFromUrl(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return 'image';
  final segments = parsed.pathSegments;
  if (segments.isEmpty) return 'image';
  final last = segments.last.trim();
  return last.isEmpty ? 'image' : last;
}

class MemoImageGrid extends StatelessWidget {
  const MemoImageGrid({
    super.key,
    required this.images,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    this.columns = 3,
    this.maxCount,
    this.maxHeight,
    this.radius = 10,
    this.spacing = 8,
    this.onReplace,
    this.enableDownload = true,
  });

  final List<MemoImageEntry> images;
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;
  final int columns;
  final int? maxCount;
  final double? maxHeight;
  final double radius;
  final double spacing;
  final Future<void> Function(EditedImageResult result)? onReplace;
  final bool enableDownload;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final total = images.length;
    final visibleCount = maxCount == null ? total : math.min(maxCount!, total);
    final overflow = total - visibleCount;
    final visible = images.take(visibleCount).toList(growable: false);
    final previewItems = images
        .map((entry) => entry.toImagePreviewItem())
        .toList(growable: false);

    void openGallery(int index) {
      if (previewItems.isEmpty) return;
      unawaited(
        ImagePreviewLauncher.open(
          context,
          ImagePreviewOpenRequest(
            items: previewItems,
            initialIndex: index,
            onReplace: onReplace == null
                ? null
                : (result) => onReplace!.call(
                    EditedImageResult(
                      sourceId: result.sourceId,
                      filePath: result.filePath,
                      filename: result.filename,
                      mimeType: result.mimeType,
                      size: result.size,
                    ),
                  ),
            enableDownload: enableDownload,
          ),
        ),
      );
    }

    Widget buildTile(
      MemoImageEntry entry,
      int index, {
      int? cacheWidth,
      int? cacheHeight,
    }) {
      final overlay = (overflow > 0 && index == visibleCount - 1)
          ? Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : null;

      return GestureDetector(
        onTap: () => openGallery(index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImagePreviewTile(
                item: entry.toImagePreviewItem(),
                width: double.infinity,
                height: double.infinity,
                borderRadius: radius,
                backgroundColor: backgroundColor,
                borderColor: borderColor,
                placeholderColor: Colors.transparent,
                iconColor: textColor.withValues(alpha: 0.45),
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                logScope: 'memo_image_grid',
              ),
              if (overlay != null) overlay,
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawWidth = constraints.maxWidth;
        final maxWidth = rawWidth.isFinite && rawWidth > 0
            ? rawWidth
            : MediaQuery.of(context).size.width;
        final totalSpacing = spacing * (columns - 1);
        final tileWidth = (maxWidth - totalSpacing) / columns;
        var tileHeight = tileWidth;

        if (maxHeight != null && visibleCount > 0) {
          final rows = (visibleCount / columns).ceil();
          final available = maxHeight! - spacing * (rows - 1);
          if (available > 0) {
            final target = available / rows;
            if (target.isFinite && target > 0 && target < tileHeight) {
              tileHeight = target;
            }
          }
        }

        final aspectRatio = tileWidth > 0 && tileHeight > 0
            ? tileWidth / tileHeight
            : 1.0;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = resolveThumbnailCacheExtent(
          tileWidth,
          devicePixelRatio,
        );
        final cacheHeight = resolveThumbnailCacheExtent(
          tileHeight,
          devicePixelRatio,
        );
        return GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) => buildTile(
            visible[index],
            index,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
          ),
        );
      },
    );
  }
}
