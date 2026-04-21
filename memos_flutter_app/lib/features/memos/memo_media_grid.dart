import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/image_thumbnail_cache.dart';
import '../image_preview/image_preview_launcher.dart';
import '../image_preview/image_preview_open_request.dart';
import '../image_preview/widgets/image_preview_tile.dart';
import 'attachment_gallery_screen.dart';
import 'attachment_video_screen.dart';
import 'memo_image_grid.dart';
import 'memo_video_grid.dart';

enum MemoMediaTapBehavior { imagePreview, mixedGallery, videoScreen }

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

MemoMediaTapBehavior resolveMemoMediaTapBehavior({
  required List<MemoMediaEntry> entries,
  required int mediaIndex,
  required int visibleCount,
}) {
  if (entries.isEmpty || mediaIndex < 0 || mediaIndex >= entries.length) {
    return MemoMediaTapBehavior.imagePreview;
  }
  final effectiveVisibleCount = math.min(
    entries.length,
    math.max(0, visibleCount),
  );
  final overflow = entries.length - effectiveVisibleCount;
  final isLastVisibleTile =
      effectiveVisibleCount > 0 && mediaIndex == effectiveVisibleCount - 1;
  if (overflow > 0 && isLastVisibleTile) {
    return MemoMediaTapBehavior.mixedGallery;
  }

  final target = entries[mediaIndex];
  if (target.isVideo) {
    return MemoMediaTapBehavior.videoScreen;
  }
  if (entries.any((entry) => entry.isVideo)) {
    return MemoMediaTapBehavior.mixedGallery;
  }
  return MemoMediaTapBehavior.imagePreview;
}

class MemoMediaGrid extends StatelessWidget {
  const MemoMediaGrid({
    super.key,
    required this.entries,
    this.columns = 3,
    this.maxCount,
    this.maxHeight,
    this.preserveSquareTilesWhenHeightLimited = false,
    this.radius = 10,
    this.spacing = 8,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    this.onReplace,
    this.enableDownload = true,
    this.enablePreviewOnTap = true,
  });

  final List<MemoMediaEntry> entries;
  final int columns;
  final int? maxCount;
  final double? maxHeight;
  final bool preserveSquareTilesWhenHeightLimited;
  final double radius;
  final double spacing;
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;
  final Future<void> Function(EditedImageResult result)? onReplace;
  final bool enableDownload;
  final bool enablePreviewOnTap;

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

    final previewItems = entries
        .where((entry) => entry.isImage)
        .map((entry) => entry.image!.toImagePreviewItem())
        .toList(growable: false);

    void openMixedGallery(int mediaIndex) {
      if (!enablePreviewOnTap) return;
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

    void openImagePreview(int mediaIndex) {
      if (!enablePreviewOnTap) return;
      if (previewItems.isEmpty) return;
      final target = entries[mediaIndex];
      if (!target.isImage) return;
      final selectedImage = target.image!;
      final imageIndex = previewItems.indexWhere(
        (item) => item.id == selectedImage.id,
      );
      if (imageIndex < 0) return;
      unawaited(
        ImagePreviewLauncher.open(
          context,
          ImagePreviewOpenRequest(
            items: previewItems,
            initialIndex: imageIndex,
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

    void openVideo(MemoVideoEntry entry) {
      if (!enablePreviewOnTap) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentVideoScreen(
            title: entry.title,
            localFile: entry.localFile,
            videoUrl: entry.videoUrl,
            thumbnailUrl: entry.thumbnailUrl,
            headers: entry.headers,
            cacheId: entry.id,
            cacheSize: entry.size,
          ),
        ),
      );
    }

    Widget buildImageTile(
      MemoImageEntry entry,
      int index, {
      int? cacheWidth,
      int? cacheHeight,
      required MemoMediaTapBehavior tapBehavior,
    }) {
      return GestureDetector(
        onTap: () => tapBehavior == MemoMediaTapBehavior.mixedGallery
            ? openMixedGallery(index)
            : openImagePreview(index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ImagePreviewTile(
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
            logScope: 'memo_media_grid',
          ),
        ),
      );
    }

    Widget buildVideoTile(
      MemoVideoEntry entry,
      int index, {
      required MemoMediaTapBehavior tapBehavior,
    }) {
      return GestureDetector(
        onTap: () => tapBehavior == MemoMediaTapBehavior.mixedGallery
            ? openMixedGallery(index)
            : openVideo(entry),
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

    Widget buildTile(
      MemoMediaEntry entry,
      int index, {
      int? cacheWidth,
      int? cacheHeight,
    }) {
      final tapBehavior = resolveMemoMediaTapBehavior(
        entries: entries,
        mediaIndex: index,
        visibleCount: visibleCount,
      );
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
          ? buildVideoTile(entry.video!, index, tapBehavior: tapBehavior)
          : buildImageTile(
              entry.image!,
              index,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              tapBehavior: tapBehavior,
            );

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
        final availableWidth = math.max(0.0, maxWidth - totalSpacing);
        final unconstrainedTileWidth = availableWidth / columns;
        var tileWidth = unconstrainedTileWidth;
        var tileHeight = unconstrainedTileWidth;

        if (maxHeight != null && visibleCount > 0) {
          final rows = (visibleCount / columns).ceil();
          final available = maxHeight! - spacing * (rows - 1);
          if (available > 0) {
            final target = available / rows;
            if (target.isFinite && target > 0 && target < tileHeight) {
              if (preserveSquareTilesWhenHeightLimited) {
                tileWidth = target;
                tileHeight = target;
              } else {
                tileHeight = target;
              }
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
        Widget grid = GridView.builder(
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

        if (preserveSquareTilesWhenHeightLimited &&
            tileWidth > 0 &&
            tileWidth < unconstrainedTileWidth) {
          final gridWidth = tileWidth * columns + totalSpacing;
          grid = Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: gridWidth, child: grid),
          );
        }

        return grid;
      },
    );
  }
}
