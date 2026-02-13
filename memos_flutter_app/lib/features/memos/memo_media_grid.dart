import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/image_formats.dart';
import '../../core/image_error_logger.dart';
import 'attachment_gallery_screen.dart';
import 'attachment_video_screen.dart';
import 'memo_image_grid.dart';
import 'memo_video_grid.dart';

class MemoMediaEntry {
  const MemoMediaEntry.image(this.image) : video = null;
  const MemoMediaEntry.video(this.video) : image = null;

  final MemoImageEntry? image;
  final MemoVideoEntry? video;

  bool get isVideo => video != null;
  bool get isImage => image != null;
}

List<MemoMediaEntry> buildMemoMediaEntries({
  required List<MemoImageEntry> images,
  required List<MemoVideoEntry> videos,
}) {
  final entries = <MemoMediaEntry>[];
  for (final image in images) {
    entries.add(MemoMediaEntry.image(image));
  }
  for (final video in videos) {
    entries.add(MemoMediaEntry.video(video));
  }
  return entries;
}

class MemoMediaGrid extends StatelessWidget {
  const MemoMediaGrid({
    super.key,
    required this.entries,
    this.columns = 3,
    this.maxCount,
    this.maxHeight,
    this.radius = 10,
    this.spacing = 8,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    this.onReplace,
    this.enableDownload = true,
  });

  final List<MemoMediaEntry> entries;
  final int columns;
  final int? maxCount;
  final double? maxHeight;
  final double radius;
  final double spacing;
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;
  final Future<void> Function(EditedImageResult result)? onReplace;
  final bool enableDownload;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final total = entries.length;
    final visibleCount = maxCount == null ? total : math.min(maxCount!, total);
    final overflow = total - visibleCount;
    final visible = entries.take(visibleCount).toList(growable: false);

    final galleryItems = entries
        .map(
          (entry) => entry.isVideo
              ? AttachmentGalleryItem.video(entry.video!)
              : AttachmentGalleryItem.image(entry.image!.toGallerySource()),
        )
        .toList(growable: false);

    void openGallery(int mediaIndex) {
      if (galleryItems.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentGalleryScreen(
            images: const [],
            items: galleryItems,
            initialIndex: mediaIndex,
            onReplace: onReplace,
            enableDownload: enableDownload,
          ),
        ),
      );
    }

    void openVideo(MemoVideoEntry entry) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentVideoScreen(
            title: entry.title,
            localFile: entry.localFile,
            videoUrl: entry.videoUrl,
            headers: entry.headers,
            cacheId: entry.id,
            cacheSize: entry.size,
          ),
        ),
      );
    }

    Widget placeholder(IconData icon) {
      return Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: textColor.withValues(alpha: 0.45)),
      );
    }

    Widget buildImageTile(MemoImageEntry entry, int index) {
      final file = entry.localFile;
      final url = (entry.previewUrl ?? entry.fullUrl ?? '').trim();
      Widget image;
      if (file != null) {
        final isSvg = shouldUseSvgRenderer(
          url: file.path,
          mimeType: entry.mimeType,
        );
        if (isSvg) {
          image = SvgPicture.file(
            file,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => placeholder(Icons.image_outlined),
            errorBuilder: (context, error, stackTrace) {
              logImageLoadError(
                scope: 'memo_media_grid_local_svg',
                source: file.path,
                error: error,
                stackTrace: stackTrace,
                extraContext: <String, Object?>{
                  'entryId': entry.id,
                  'mimeType': entry.mimeType,
                },
              );
              return placeholder(Icons.broken_image_outlined);
            },
          );
        } else {
          image = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              logImageLoadError(
                scope: 'memo_media_grid_local',
                source: file.path,
                error: error,
                stackTrace: stackTrace,
                extraContext: <String, Object?>{
                  'entryId': entry.id,
                  'mimeType': entry.mimeType,
                },
              );
              return placeholder(Icons.broken_image_outlined);
            },
          );
        }
      } else if (url.isNotEmpty) {
        final isSvg = shouldUseSvgRenderer(url: url, mimeType: entry.mimeType);
        if (isSvg) {
          image = SvgPicture.network(
            url,
            headers: entry.headers,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => placeholder(Icons.image_outlined),
            errorBuilder: (context, error, stackTrace) {
              logImageLoadError(
                scope: 'memo_media_grid_network_svg',
                source: url,
                error: error,
                stackTrace: stackTrace,
                extraContext: <String, Object?>{
                  'entryId': entry.id,
                  'mimeType': entry.mimeType,
                  'hasAuthHeader':
                      entry.headers?['Authorization']?.trim().isNotEmpty ?? false,
                },
              );
              return placeholder(Icons.broken_image_outlined);
            },
          );
        } else {
          image = CachedNetworkImage(
            imageUrl: url,
            httpHeaders: entry.headers,
            fit: BoxFit.cover,
            placeholder: (context, _) => placeholder(Icons.image_outlined),
            errorWidget: (context, _, error) {
              logImageLoadError(
                scope: 'memo_media_grid_network',
                source: url,
                error: error,
                extraContext: <String, Object?>{
                  'entryId': entry.id,
                  'mimeType': entry.mimeType,
                  'hasAuthHeader':
                      entry.headers?['Authorization']?.trim().isNotEmpty ?? false,
                },
              );
              return placeholder(Icons.broken_image_outlined);
            },
          );
        }
      } else {
        image = placeholder(Icons.image_outlined);
      }

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
            child: image,
          ),
        ),
      );
    }

    Widget buildVideoTile(MemoVideoEntry entry, int index) {
      return GestureDetector(
        onTap: () => openVideo(entry),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
            ),
            child: AttachmentVideoThumbnail(
              key: ValueKey<String>(memoVideoThumbnailWidgetKey(entry)),
              entry: entry,
              borderRadius: radius,
            ),
          ),
        ),
      );
    }

    Widget buildTile(MemoMediaEntry entry, int index) {
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

      final content = entry.isVideo
          ? buildVideoTile(entry.video!, index)
          : buildImageTile(entry.image!, index);

      if (overlay == null) return content;

      return Stack(fit: StackFit.expand, children: [content, overlay]);
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
