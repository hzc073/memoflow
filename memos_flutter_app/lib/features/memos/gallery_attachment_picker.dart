import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'gallery_attachment_picker_constants.dart';
import 'gallery_attachment_original_picker.dart';

@immutable
class PickedLocalAttachment {
  const PickedLocalAttachment({
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.skipCompression = false,
  });

  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final bool skipCompression;
}

@immutable
class GalleryAttachmentPickResult {
  const GalleryAttachmentPickResult({
    required this.attachments,
    required this.skippedCount,
  });

  final List<PickedLocalAttachment> attachments;
  final int skippedCount;
}

bool get isMemoGalleryToolbarSupportedPlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

String guessLocalAttachmentMimeType(String filename) {
  final lower = filename.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot == -1 ? '' : lower.substring(dot + 1);
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'wav' => 'audio/wav',
    'flac' => 'audio/flac',
    'ogg' => 'audio/ogg',
    'opus' => 'audio/opus',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    'avi' => 'video/x-msvideo',
    'pdf' => 'application/pdf',
    'zip' => 'application/zip',
    'rar' => 'application/vnd.rar',
    '7z' => 'application/x-7z-compressed',
    'txt' => 'text/plain',
    'md' => 'text/markdown',
    'json' => 'application/json',
    'csv' => 'text/csv',
    'log' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

Future<GalleryAttachmentPickResult?> pickGalleryAttachments(
  BuildContext context, {
  int maxAssets = 100,
  bool enableOriginalToggle = false,
}) async {
  OriginalToggleGalleryAssetPickResult? originalPickResult;
  List<AssetEntity>? assets;
  if (enableOriginalToggle) {
    originalPickResult = await pickGalleryAssetsWithOriginalToggle(
      context,
      maxAssets: maxAssets,
    );
    assets = originalPickResult?.assets;
  } else {
    final themeColor = Theme.of(context).colorScheme.primary;
    assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        requestType: RequestType.common,
        maxAssets: maxAssets,
        themeColor: themeColor,
        previewThumbnailSize: memoGalleryPreviewThumbnailSize,
      ),
    );
  }
  if (assets == null || assets.isEmpty) {
    return null;
  }

  final originalAssetIds = normalizeGalleryOriginalAssetIds(
    selectedAssets: assets,
    originalAssetIds: originalPickResult?.originalAssetIds ?? const <String>{},
  );

  final attachments = <PickedLocalAttachment>[];
  var skippedCount = 0;
  for (final asset in assets) {
    final rawFile = await asset.file;
    final path = rawFile?.path.trim() ?? '';
    if (path.isEmpty) {
      skippedCount++;
      continue;
    }

    final file = File(path);
    if (!file.existsSync()) {
      skippedCount++;
      continue;
    }

    final filename = (asset.title ?? '').trim().isNotEmpty
        ? asset.title!.trim()
        : path.split(Platform.pathSeparator).last;
    attachments.add(
      buildPickedLocalAttachment(
        filePath: path,
        filename: filename,
        size: await file.length(),
        assetType: asset.type,
        assetId: asset.id,
        originalAssetIds: originalAssetIds,
      ),
    );
  }

  return GalleryAttachmentPickResult(
    attachments: attachments,
    skippedCount: skippedCount,
  );
}

@visibleForTesting
Set<String> normalizeGalleryOriginalAssetIds({
  required Iterable<AssetEntity> selectedAssets,
  required Iterable<String> originalAssetIds,
}) {
  final selectedImageIds = selectedAssets
      .where((asset) => asset.type == AssetType.image)
      .map((asset) => asset.id)
      .toSet();
  return originalAssetIds.where(selectedImageIds.contains).toSet();
}

@visibleForTesting
PickedLocalAttachment buildPickedLocalAttachment({
  required String filePath,
  required String filename,
  required int size,
  required AssetType assetType,
  required String assetId,
  required Set<String> originalAssetIds,
}) {
  return PickedLocalAttachment(
    filePath: filePath,
    filename: filename,
    mimeType: guessLocalAttachmentMimeType(filename),
    size: size,
    skipCompression:
        assetType == AssetType.image && originalAssetIds.contains(assetId),
  );
}
