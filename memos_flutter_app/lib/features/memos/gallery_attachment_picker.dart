import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../application/attachments/compression/compression_source_probe.dart';
import '../../data/logs/log_manager.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import 'gallery_attachment_original_picker.dart';
import 'windows_camera_capture_screen.dart';

const CompressionSourceProbeService _galleryAttachmentProbeService =
    CompressionSourceProbeService();

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
  required ImageCompressionUiPolicy compressionPolicy,
  ImagePicker? imagePicker,
  Future<List<XFile>> Function()? pickMultipleMediaOverride,
  Future<bool?> Function()? confirmUploadOriginalOverride,
}) async {
  LogManager.instance.debug(
    'GalleryAttachmentPicker: start',
    context: {
      'maxAssets': maxAssets,
      'compressionEnabled': compressionPolicy.enabled,
      'useSystemPhotoPicker': compressionPolicy.useSystemPhotoPicker,
      'showOriginalToggle': compressionPolicy.showOriginalToggle,
      'promptOriginalBeforePick':
          compressionPolicy.shouldPromptOriginalBeforePick,
    },
  );
  if (compressionPolicy.useSystemPhotoPicker) {
    var uploadOriginalImages = false;
    if (compressionPolicy.shouldPromptOriginalBeforePick) {
      final legacyStrings = context.t.strings.legacy;
      final navigator = Navigator.of(context);
      final selection = confirmUploadOriginalOverride != null
          ? await confirmUploadOriginalOverride()
          : await promptForSystemPickerOriginalUpload(
              navigator: navigator,
              title: legacyStrings.msg_original_image,
              description:
                  legacyStrings.msg_gallery_system_picker_original_desc,
              switchLabel:
                  legacyStrings.msg_gallery_system_picker_original_switch,
              cancelLabel: legacyStrings.msg_cancel,
              continueLabel: legacyStrings.msg_continue,
            );
      if (selection == null) {
        return null;
      }
      uploadOriginalImages = selection;
    }
    final files = pickMultipleMediaOverride != null
        ? await pickMultipleMediaOverride()
        : await (imagePicker ?? ImagePicker()).pickMultipleMedia(
            limit: maxAssets,
            requestFullMetadata: false,
          );
    if (files.isEmpty) {
      return null;
    }
    LogManager.instance.debug(
      'GalleryAttachmentPicker: system_picker_result',
      context: {
        'selectedCount': files.length,
        'uploadOriginalImages': uploadOriginalImages,
      },
    );
    return buildGalleryAttachmentPickResultFromSystemPickerFiles(
      files: files,
      uploadOriginalImages: uploadOriginalImages,
    );
  }

  return _pickGalleryAttachmentsWithAssetPicker(
    context,
    maxAssets: maxAssets,
    showOriginalToggle: compressionPolicy.showOriginalToggle,
  );
}

Future<GalleryAttachmentPickResult?> _pickGalleryAttachmentsWithAssetPicker(
  BuildContext context, {
  required int maxAssets,
  required bool showOriginalToggle,
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
  LogManager.instance.debug(
    'GalleryAttachmentPicker: asset_picker_result',
    context: {
      'selectedCount': assets.length,
      'originalAssetCount': originalAssetIds.length,
      'showOriginalToggle': showOriginalToggle,
    },
  );

  final attachments = <PickedLocalAttachment>[];
  var skippedCount = 0;
  for (final asset in assets) {
    final useOriginalFile = shouldReadOriginalGalleryAssetFile(
      asset: asset,
      originalAssetIds: originalAssetIds,
    );
    final rawFile = await (useOriginalFile ? asset.originFile : asset.file);
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
    unawaited(
      _logPickedLocalAttachment(
        'GalleryAttachmentPicker: asset_attachment_ready',
        attachments.last,
        context: {
          'assetId': asset.id,
          'assetType': asset.type.name,
          'usedOriginalAssetFile': useOriginalFile,
          'assetMarkedOriginal': originalAssetIds.contains(asset.id),
        },
      ),
    );
  }

  return GalleryAttachmentPickResult(
    attachments: attachments,
    skippedCount: skippedCount,
  );
}

Future<bool?> promptForSystemPickerOriginalUpload({
  required NavigatorState navigator,
  required String title,
  required String description,
  required String switchLabel,
  required String cancelLabel,
  required String continueLabel,
}) async {
  var uploadOriginalImages = false;
  return showDialog<bool>(
    context: navigator.context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: uploadOriginalImages,
                  contentPadding: EdgeInsets.zero,
                  title: Text(switchLabel),
                  onChanged: (value) {
                    setState(() {
                      uploadOriginalImages = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(cancelLabel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(uploadOriginalImages),
                child: Text(continueLabel),
              ),
            ],
          );
        },
      );
    },
  );
}

@visibleForTesting
GalleryAttachmentPickResult
buildGalleryAttachmentPickResultFromSystemPickerFiles({
  required Iterable<XFile> files,
  required bool uploadOriginalImages,
}) {
  final attachments = <PickedLocalAttachment>[];
  var skippedCount = 0;
  for (final pickedFile in files) {
    final path = pickedFile.path.trim();
    if (path.isEmpty) {
      skippedCount++;
      continue;
    }

    final file = File(path);
    if (!file.existsSync()) {
      skippedCount++;
      continue;
    }

    final filename = path.split(Platform.pathSeparator).last;
    final mimeType = guessLocalAttachmentMimeType(filename);
    attachments.add(
      buildPickedLocalAttachment(
        filePath: path,
        filename: filename,
        size: file.lengthSync(),
        source: PickedLocalAttachmentSource.gallery,
        skipCompression: shouldSkipCompressionForSystemPickedFile(
          mimeType: mimeType,
          uploadOriginalImages: uploadOriginalImages,
        ),
      ),
    );
    unawaited(
      _logPickedLocalAttachment(
        'GalleryAttachmentPicker: system_attachment_ready',
        attachments.last,
        context: {'uploadOriginalImages': uploadOriginalImages},
      ),
    );
  }

  return GalleryAttachmentPickResult(
    attachments: attachments,
    skippedCount: skippedCount,
  );
}

@visibleForTesting
bool shouldSkipCompressionForSystemPickedFile({
  required String mimeType,
  required bool uploadOriginalImages,
}) {
  return uploadOriginalImages && mimeType.startsWith('image/');
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
  final attachment = buildPickedLocalAttachment(
    filePath: path,
    filename: filename,
    size: file.lengthSync(),
    source: PickedLocalAttachmentSource.camera,
  );
  unawaited(
    _logPickedLocalAttachment(
      'GalleryAttachmentPicker: camera_attachment_ready',
      attachment,
    ),
  );
  return attachment;
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

Future<void> _logPickedLocalAttachment(
  String event,
  PickedLocalAttachment attachment, {
  Map<String, Object?> context = const <String, Object?>{},
}) async {
  try {
    final fileContext = await _buildAttachmentLogContext(
      filePath: attachment.filePath,
      filename: attachment.filename,
      mimeType: attachment.mimeType,
    );
    LogManager.instance.debug(
      event,
      context: {
        ...fileContext,
        'attachmentSource': attachment.source.name,
        'skipCompression': attachment.skipCompression,
        ...context,
      },
    );
  } catch (error, stackTrace) {
    LogManager.instance.warn(
      'GalleryAttachmentPicker: attachment_log_failed',
      error: error,
      stackTrace: stackTrace,
      context: {
        'filePath': attachment.filePath,
        'filename': attachment.filename,
        'mimeType': attachment.mimeType,
      },
    );
  }
}

Future<Map<String, Object?>> _buildAttachmentLogContext({
  required String filePath,
  required String filename,
  required String mimeType,
}) async {
  final normalizedPath = _normalizeAttachmentPath(filePath);
  final file = File(normalizedPath);
  final exists = normalizedPath.isNotEmpty && await file.exists();
  final context = <String, Object?>{
    'filePath': normalizedPath,
    'filename': filename,
    'mimeType': mimeType,
    'exists': exists,
    'isContentUri': normalizedPath.startsWith('content://'),
  };
  if (!exists) {
    return context;
  }
  context['fileSize'] = await file.length();
  if (!mimeType.toLowerCase().startsWith('image/')) {
    return context;
  }
  final probe = await _galleryAttachmentProbeService.probe(
    path: normalizedPath,
    filename: filename,
    mimeType: mimeType,
  );
  context.addAll({
    'imageFormat': probe.format.name,
    'rawWidth': probe.width,
    'rawHeight': probe.height,
    'displayWidth': probe.displayWidth,
    'displayHeight': probe.displayHeight,
    'orientation': probe.orientation,
    'isAnimated': probe.isAnimated,
  });
  return context;
}

String _normalizeAttachmentPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('file://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      try {
        return uri.toFilePath();
      } catch (_) {}
    }
  }
  return trimmed;
}
