import 'dart:io';

import 'package:path/path.dart' as p;

class ImagePreviewItem {
  const ImagePreviewItem({
    required this.id,
    required this.title,
    required this.mimeType,
    this.localFile,
    this.thumbnailUrl,
    this.fullUrl,
    this.headers,
    this.width,
    this.height,
  });

  final String id;
  final String title;
  final String mimeType;
  final File? localFile;
  final String? thumbnailUrl;
  final String? fullUrl;
  final Map<String, String>? headers;
  final int? width;
  final int? height;

  String? get resolvedTileUrl {
    final thumbnail = thumbnailUrl?.trim();
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return thumbnail;
    }
    final full = fullUrl?.trim();
    if (full != null && full.isNotEmpty) {
      return full;
    }
    return null;
  }

  String? get resolvedGalleryUrl {
    final full = fullUrl?.trim();
    if (full != null && full.isNotEmpty) {
      return full;
    }
    final thumbnail = thumbnailUrl?.trim();
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return thumbnail;
    }
    return null;
  }

  bool get hasRenderableSource =>
      localFile != null || resolvedTileUrl != null || resolvedGalleryUrl != null;
}

int findImagePreviewItemIndex({
  required List<ImagePreviewItem> items,
  String? localPath,
  Iterable<String> urlCandidates = const <String>[],
}) {
  final normalizedLocalPath = _normalizeLocalPath(localPath);
  final normalizedUrls = urlCandidates
      .map((candidate) => candidate.trim())
      .where((candidate) => candidate.isNotEmpty)
      .toSet();
  for (var index = 0; index < items.length; index++) {
    final item = items[index];
    final itemLocalPath = _normalizeLocalPath(item.localFile?.path);
    if (normalizedLocalPath != null &&
        itemLocalPath != null &&
        itemLocalPath == normalizedLocalPath) {
      return index;
    }
    final itemUrls = <String>{
      if (item.thumbnailUrl?.trim().isNotEmpty == true) item.thumbnailUrl!.trim(),
      if (item.fullUrl?.trim().isNotEmpty == true) item.fullUrl!.trim(),
    };
    if (itemUrls.any(normalizedUrls.contains)) {
      return index;
    }
  }
  return -1;
}

String? _normalizeLocalPath(String? rawPath) {
  final trimmed = rawPath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final normalized = p.normalize(trimmed);
  if (Platform.isWindows) {
    return normalized.toLowerCase();
  }
  return normalized;
}
