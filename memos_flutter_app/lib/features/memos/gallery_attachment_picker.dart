import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'gallery_attachment_original_picker.dart';
import 'windows_camera_capture_screen.dart';

enum PickedLocalAttachmentSource { gallery, camera }

class CameraAttachmentFileMissingException implements Exception {
  const CameraAttachmentFileMissingException();
}

@immutable
class PickedLocalAttachment {
  const PickedLocalAttachment({
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.source = PickedLocalAttachmentSource.gallery,
    this.skipCompression = false,
  });

  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final PickedLocalAttachmentSource source;
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
  return Platform.isAndroid;
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
  bool showOriginalToggle = false,
}) async {
  final originalPickResult = await pickGalleryAssetsWithOriginalToggle(
    context,
    maxAssets: maxAssets,
    showOriginalToggle: showOriginalToggle,
  );
  final assets = originalPickResult?.assets;
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
    final rawFile =
        await (shouldReadOriginalGalleryAssetFile(
              asset: asset,
              originalAssetIds: originalAssetIds,
            )
            ? asset.originFile
            : asset.file);
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
        source: PickedLocalAttachmentSource.gallery,
        skipCompression:
            asset.type == AssetType.image &&
            originalAssetIds.contains(asset.id),
      ),
    );
  }

  return GalleryAttachmentPickResult(
    attachments: attachments,
    skippedCount: skippedCount,
  );
}

@visibleForTesting
bool shouldReadOriginalGalleryAssetFile({
  required AssetEntity asset,
  required Set<String> originalAssetIds,
}) {
  return asset.type == AssetType.image && originalAssetIds.contains(asset.id);
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

Future<PickedLocalAttachment?> captureCameraAttachment({
  NavigatorState? navigator,
  required ImagePicker imagePicker,
  Future<XFile?> Function()? capturePhotoOverride,
}) async {
  final photo = capturePhotoOverride != null
      ? await capturePhotoOverride()
      : Platform.isWindows
      ? await WindowsCameraCaptureScreen.captureWithNavigator(
          navigator ??
              (throw StateError(
                'navigator required for Windows camera capture',
              )),
        )
      : await imagePicker.pickImage(source: ImageSource.camera);
  if (photo == null) {
    return null;
  }

  final path = photo.path.trim();
  if (path.isEmpty) {
    throw const CameraAttachmentFileMissingException();
  }

  final file = File(path);
  if (!file.existsSync()) {
    throw const CameraAttachmentFileMissingException();
  }

  final filename = path.split(Platform.pathSeparator).last;
  return buildPickedLocalAttachment(
    filePath: path,
    filename: filename,
    size: file.lengthSync(),
    source: PickedLocalAttachmentSource.camera,
  );
}

@visibleForTesting
PickedLocalAttachment buildPickedLocalAttachment({
  required String filePath,
  required String filename,
  required int size,
  PickedLocalAttachmentSource source = PickedLocalAttachmentSource.gallery,
  bool skipCompression = false,
}) {
  return PickedLocalAttachment(
    filePath: filePath,
    filename: filename,
    mimeType: guessLocalAttachmentMimeType(filename),
    size: size,
    source: source,
    skipCompression: skipCompression,
  );
}
