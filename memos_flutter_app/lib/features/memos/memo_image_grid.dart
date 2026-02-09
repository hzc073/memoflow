import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/url.dart';
import '../../data/models/attachment.dart';
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
  });

  final String id;
  final String title;
  final String mimeType;
  final File? localFile;
  final String? previewUrl;
  final String? fullUrl;
  final Map<String, String>? headers;
  final bool isAttachment;

  AttachmentImageSource toGallerySource() {
    final url = (fullUrl ?? previewUrl ?? '').trim();
    return AttachmentImageSource(
      id: id,
      title: title,
      mimeType: mimeType,
      localFile: localFile,
      imageUrl: url.isEmpty ? null : url,
      headers: headers,
    );
  }
}

List<MemoImageEntry> collectMemoImageEntries({
  required String content,
  required List<Attachment> attachments,
  required Uri? baseUrl,
  required String? authHeader,
}) {
  final entries = <MemoImageEntry>[];
  final seen = <String>{};

  final markdownUrls = extractMarkdownImageUrls(content);
  for (var i = 0; i < markdownUrls.length; i++) {
    final url = normalizeMarkdownImageSrc(markdownUrls[i]).trim();
    if (url.isEmpty || !seen.add(url)) continue;
    entries.add(
      MemoImageEntry(
        id: 'md_$i',
        title: _titleFromUrl(url),
        mimeType: 'image/*',
        previewUrl: url,
        fullUrl: url,
        isAttachment: false,
      ),
    );
  }

  for (final attachment in attachments) {
    final type = attachment.type.trim().toLowerCase();
    if (!type.startsWith('image')) continue;
    final entry = _entryFromAttachment(attachment, baseUrl, authHeader);
    if (entry == null) continue;
    final key = (entry.localFile?.path ?? entry.fullUrl ?? entry.previewUrl ?? '').trim();
    if (key.isEmpty || !seen.add(key)) continue;
    entries.add(entry);
  }

  return entries;
}

MemoImageEntry? _entryFromAttachment(Attachment attachment, Uri? baseUrl, String? authHeader) {
  final external = attachment.externalLink.trim();
  final localFile = _resolveLocalFile(external);
  final mimeType = attachment.type.trim().isEmpty ? 'image/*' : attachment.type.trim();
  final title = attachment.filename.trim().isNotEmpty ? attachment.filename.trim() : attachment.uid;

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
    );
  }

  if (external.isNotEmpty) {
    final isAbsolute = isAbsoluteUrl(external);
    final resolved = resolveMaybeRelativeUrl(baseUrl, external);
    final previewUrl = isAbsolute ? resolved : appendThumbnailParam(resolved);
    final headers = (!isAbsolute && authHeader != null && authHeader.trim().isNotEmpty)
        ? {'Authorization': authHeader.trim()}
        : null;
    return MemoImageEntry(
      id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
      title: title.isEmpty ? _titleFromUrl(external) : title,
      mimeType: mimeType,
      previewUrl: previewUrl,
      fullUrl: resolved,
      headers: headers,
      isAttachment: true,
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
  );
}

File? _resolveLocalFile(String externalLink) {
  if (!externalLink.startsWith('file://')) return null;
  final uri = Uri.tryParse(externalLink);
  if (uri == null) return null;
  final path = uri.toFilePath();
  if (path.trim().isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return file;
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
    final gallerySources = images.map((e) => e.toGallerySource()).toList(growable: false);

    Widget placeholder(IconData icon) {
      return Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: textColor.withValues(alpha: 0.45)),
      );
    }

    void openGallery(int index) {
      if (gallerySources.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentGalleryScreen(
            images: gallerySources,
            initialIndex: index,
            onReplace: onReplace,
            enableDownload: enableDownload,
          ),
        ),
      );
    }

    Widget buildTile(MemoImageEntry entry, int index) {
      final file = entry.localFile;
      final url = (entry.previewUrl ?? entry.fullUrl ?? '').trim();
      Widget image;
      if (file != null) {
        image = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder(Icons.broken_image_outlined),
        );
      } else if (url.isNotEmpty) {
        image = CachedNetworkImage(
          imageUrl: url,
          httpHeaders: entry.headers,
          fit: BoxFit.cover,
          placeholder: (context, _) => placeholder(Icons.image_outlined),
          errorWidget: (context, _, _) => placeholder(Icons.broken_image_outlined),
        );
      } else {
        image = placeholder(Icons.image_outlined);
      }

      final overlay = (overflow > 0 && index == visibleCount - 1)
          ? Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Text(
                '+$overflow',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            )
          : null;

      return GestureDetector(
        onTap: () => openGallery(index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (overlay != null) overlay,
              ],
            ),
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

        final aspectRatio = tileWidth > 0 && tileHeight > 0 ? tileWidth / tileHeight : 1.0;
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
          itemBuilder: (context, index) => buildTile(visible[index], index),
        );
      },
    );
  }
}
