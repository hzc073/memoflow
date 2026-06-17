import 'package:flutter/material.dart';

import '../../platform/platform_route.dart';
import '../image_preview/image_preview_open_request.dart';
import '../image_preview/widgets/image_preview_gallery_screen.dart';
import '../memos/attachment_gallery_screen.dart';
import '../memos/attachment_video_screen.dart';
import '../memos/memo_video_grid.dart';
import 'desktop_media_preview_request.dart';
import 'desktop_media_preview_window.dart';

class MediaPreviewLauncher {
  const MediaPreviewLauncher._();

  static Future<void> openImagePreview(
    BuildContext context,
    ImagePreviewOpenRequest request,
  ) async {
    if (request.items.isEmpty) {
      return;
    }
    final usesDesktopSurface = isDesktopMediaPreviewSurfacePlatform();
    if (usesDesktopSurface && request.onReplace == null) {
      final desktopRequest =
          DesktopMediaPreviewRequest.fromImagePreviewOpenRequest(request);
      final opened = await _tryOpenDesktopWindow(desktopRequest);
      if (opened) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context, rootNavigator: true).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => ImagePreviewGalleryScreen(
          request: request,
          immersiveDesktopChrome: usesDesktopSurface,
          showViewerCloseButton: usesDesktopSurface,
        ),
      ),
    );
  }

  static Future<void> openAttachmentGallery(
    BuildContext context, {
    required List<AttachmentImageSource> images,
    required int initialIndex,
    List<AttachmentGalleryItem>? items,
    Future<void> Function(EditedImageResult result)? onReplace,
    bool enableDownload = true,
    String albumName = 'MemoFlow',
  }) async {
    final effectiveItems =
        items ??
        images.map(AttachmentGalleryItem.image).toList(growable: false);
    if (effectiveItems.isEmpty) {
      return;
    }
    final usesDesktopSurface = isDesktopMediaPreviewSurfacePlatform();
    if (usesDesktopSurface && onReplace == null) {
      final desktopRequest = DesktopMediaPreviewRequest.fromAttachmentGallery(
        items: effectiveItems,
        initialIndex: initialIndex,
        enableDownload: enableDownload,
        albumName: albumName,
        allowReplaceResult: false,
      );
      final opened = await _tryOpenDesktopWindow(desktopRequest);
      if (opened) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentGalleryScreen(
          images: images,
          items: items,
          initialIndex: initialIndex,
          onReplace: onReplace,
          enableDownload: enableDownload,
          albumName: albumName,
          immersiveDesktopChrome: usesDesktopSurface,
          showViewerCloseButton: usesDesktopSurface,
        ),
      ),
    );
  }

  static Future<void> openVideo(
    BuildContext context,
    MemoVideoEntry entry,
  ) async {
    final usesDesktopSurface = isDesktopMediaPreviewSurfacePlatform();
    if (usesDesktopSurface) {
      final desktopRequest = DesktopMediaPreviewRequest.fromVideoEntry(entry);
      final opened = await _tryOpenDesktopWindow(desktopRequest);
      if (opened) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentVideoScreen(
          title: entry.title,
          localFile: entry.localFile,
          videoUrl: entry.videoUrl,
          thumbnailUrl: entry.thumbnailUrl,
          headers: entry.headers,
          cacheId: entry.id,
          cacheSize: entry.size,
          immersiveDesktopChrome: usesDesktopSurface,
          showViewerCloseButton: usesDesktopSurface,
        ),
      ),
    );
  }

  static Future<bool> _tryOpenDesktopWindow(
    DesktopMediaPreviewRequest request,
  ) async {
    final availableRequest = request.retainAvailableItems();
    if (availableRequest == null) {
      return false;
    }
    final result = await openDesktopMediaPreviewWindow(
      request: availableRequest,
    );
    return result.opened;
  }
}
