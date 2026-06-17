import 'dart:io';

import '../image_preview/image_preview_edit_result.dart';
import '../image_preview/image_preview_item.dart';
import '../image_preview/image_preview_open_request.dart';
import '../memos/attachment_gallery_screen.dart';
import '../memos/memo_video_grid.dart';

enum DesktopMediaPreviewItemKind { image, video }

class DesktopMediaPreviewItem {
  const DesktopMediaPreviewItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.mimeType,
    this.localPath,
    this.imageUrl,
    this.thumbnailUrl,
    this.videoUrl,
    this.headers,
    this.width,
    this.height,
    this.size,
  });

  factory DesktopMediaPreviewItem.fromImagePreviewItem(ImagePreviewItem item) {
    return DesktopMediaPreviewItem(
      kind: DesktopMediaPreviewItemKind.image,
      id: item.id,
      title: item.title,
      mimeType: item.mimeType,
      localPath: item.localFile?.path,
      imageUrl: item.fullUrl,
      thumbnailUrl: item.thumbnailUrl,
      headers: item.headers,
      width: item.width,
      height: item.height,
    );
  }

  factory DesktopMediaPreviewItem.fromAttachmentImageSource(
    AttachmentImageSource source,
  ) {
    return DesktopMediaPreviewItem(
      kind: DesktopMediaPreviewItemKind.image,
      id: source.id,
      title: source.title,
      mimeType: source.mimeType,
      localPath: source.localFile?.path,
      imageUrl: source.imageUrl,
      headers: source.headers,
      width: source.width,
      height: source.height,
    );
  }

  factory DesktopMediaPreviewItem.fromVideoEntry(MemoVideoEntry entry) {
    return DesktopMediaPreviewItem(
      kind: DesktopMediaPreviewItemKind.video,
      id: entry.id,
      title: entry.title,
      mimeType: entry.mimeType,
      localPath: entry.localFile?.path,
      thumbnailUrl: entry.thumbnailUrl,
      videoUrl: entry.videoUrl,
      headers: entry.headers,
      size: entry.size,
    );
  }

  factory DesktopMediaPreviewItem.fromAttachmentGalleryItem(
    AttachmentGalleryItem item,
  ) {
    if (item.isVideo) {
      return DesktopMediaPreviewItem.fromVideoEntry(item.video!);
    }
    return DesktopMediaPreviewItem.fromAttachmentImageSource(item.image!);
  }

  factory DesktopMediaPreviewItem.fromJson(Map<String, dynamic> json) {
    return DesktopMediaPreviewItem(
      kind: _itemKindFromJson(json['kind']),
      id: _stringValue(json['id']),
      title: _stringValue(json['title']),
      mimeType: _stringValue(json['mimeType']),
      localPath: _nullableStringValue(json['localPath']),
      imageUrl: _nullableStringValue(json['imageUrl']),
      thumbnailUrl: _nullableStringValue(json['thumbnailUrl']),
      videoUrl: _nullableStringValue(json['videoUrl']),
      headers: _stringMapValue(json['headers']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      size: _intValue(json['size']),
    );
  }

  final DesktopMediaPreviewItemKind kind;
  final String id;
  final String title;
  final String mimeType;
  final String? localPath;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? videoUrl;
  final Map<String, String>? headers;
  final int? width;
  final int? height;
  final int? size;

  bool get isImage => kind == DesktopMediaPreviewItemKind.image;
  bool get isVideo => kind == DesktopMediaPreviewItemKind.video;

  bool get hasAvailableSource {
    final local = localPath?.trim();
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return true;
    }
    if (isVideo) {
      return _hasText(videoUrl);
    }
    return _hasText(imageUrl) || _hasText(thumbnailUrl);
  }

  ImagePreviewItem toImagePreviewItem() {
    return ImagePreviewItem(
      id: id,
      title: title,
      mimeType: mimeType,
      localFile: _fileFromPath(localPath),
      thumbnailUrl: thumbnailUrl,
      fullUrl: imageUrl,
      headers: headers,
      width: width,
      height: height,
    );
  }

  AttachmentGalleryItem toAttachmentGalleryItem() {
    if (isVideo) {
      return AttachmentGalleryItem.video(toVideoEntry());
    }
    return AttachmentGalleryItem.image(toAttachmentImageSource());
  }

  AttachmentImageSource toAttachmentImageSource() {
    return AttachmentImageSource(
      id: id,
      title: title,
      mimeType: mimeType,
      localFile: _fileFromPath(localPath),
      imageUrl: imageUrl ?? thumbnailUrl,
      headers: headers,
      width: width,
      height: height,
    );
  }

  MemoVideoEntry toVideoEntry() {
    return MemoVideoEntry(
      id: id,
      title: title,
      mimeType: mimeType,
      size: size ?? 0,
      localFile: _fileFromPath(localPath),
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      headers: headers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'id': id,
      'title': title,
      'mimeType': mimeType,
      if (_hasText(localPath)) 'localPath': localPath,
      if (_hasText(imageUrl)) 'imageUrl': imageUrl,
      if (_hasText(thumbnailUrl)) 'thumbnailUrl': thumbnailUrl,
      if (_hasText(videoUrl)) 'videoUrl': videoUrl,
      if (headers != null && headers!.isNotEmpty) 'headers': headers,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (size != null) 'size': size,
    };
  }
}

class DesktopMediaPreviewRequest {
  const DesktopMediaPreviewRequest({
    required this.requestId,
    required this.items,
    required this.initialIndex,
    this.enableDownload = true,
    this.albumName = 'MemoFlow',
    this.allowReplaceResult = false,
    this.source = 'unknown',
  });

  factory DesktopMediaPreviewRequest.fromImagePreviewOpenRequest(
    ImagePreviewOpenRequest request, {
    String source = 'image_preview',
  }) {
    return DesktopMediaPreviewRequest(
      requestId: _newRequestId(),
      items: request.items
          .map(DesktopMediaPreviewItem.fromImagePreviewItem)
          .toList(growable: false),
      initialIndex: request.initialIndex,
      enableDownload: request.enableDownload,
      albumName: request.albumName,
      allowReplaceResult: request.onReplace != null,
      source: source,
    );
  }

  factory DesktopMediaPreviewRequest.fromAttachmentGallery({
    required List<AttachmentGalleryItem> items,
    required int initialIndex,
    required bool enableDownload,
    required String albumName,
    required bool allowReplaceResult,
    String source = 'attachment_gallery',
  }) {
    return DesktopMediaPreviewRequest(
      requestId: _newRequestId(),
      items: items
          .map(DesktopMediaPreviewItem.fromAttachmentGalleryItem)
          .toList(growable: false),
      initialIndex: initialIndex,
      enableDownload: enableDownload,
      albumName: albumName,
      allowReplaceResult: allowReplaceResult,
      source: source,
    );
  }

  factory DesktopMediaPreviewRequest.fromVideoEntry(
    MemoVideoEntry entry, {
    String source = 'video',
  }) {
    return DesktopMediaPreviewRequest(
      requestId: _newRequestId(),
      items: <DesktopMediaPreviewItem>[
        DesktopMediaPreviewItem.fromVideoEntry(entry),
      ],
      initialIndex: 0,
      enableDownload: false,
      allowReplaceResult: false,
      source: source,
    );
  }

  factory DesktopMediaPreviewRequest.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => DesktopMediaPreviewItem.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
        : const <DesktopMediaPreviewItem>[];
    return DesktopMediaPreviewRequest(
      requestId: _stringValue(json['requestId']),
      items: items,
      initialIndex: _intValue(json['initialIndex']) ?? 0,
      enableDownload: json['enableDownload'] != false,
      albumName: _stringValue(json['albumName'], fallback: 'MemoFlow'),
      allowReplaceResult: json['allowReplaceResult'] == true,
      source: _stringValue(json['source'], fallback: 'unknown'),
    );
  }

  static DesktopMediaPreviewRequest? fromLaunchArgs(
    Map<String, dynamic> launchArgs,
  ) {
    final payload = launchArgs['payload'];
    if (payload is! Map) return null;
    return DesktopMediaPreviewRequest.fromJson(payload.cast<String, dynamic>());
  }

  final String requestId;
  final List<DesktopMediaPreviewItem> items;
  final int initialIndex;
  final bool enableDownload;
  final String albumName;
  final bool allowReplaceResult;
  final String source;

  bool get isImageOnly => items.every((item) => item.isImage);
  bool get isSingleVideo => items.length == 1 && items.single.isVideo;

  int get safeInitialIndex {
    if (items.isEmpty) return 0;
    return initialIndex.clamp(0, items.length - 1);
  }

  DesktopMediaPreviewRequest? retainAvailableItems() {
    final currentId = items.isEmpty ? null : items[safeInitialIndex].id;
    final available = items
        .where((item) => item.hasAvailableSource)
        .toList(growable: false);
    if (available.isEmpty) return null;
    final nextIndex = currentId == null
        ? 0
        : available.indexWhere((item) => item.id == currentId);
    return DesktopMediaPreviewRequest(
      requestId: requestId,
      items: available,
      initialIndex: nextIndex < 0 ? 0 : nextIndex,
      enableDownload: enableDownload,
      albumName: albumName,
      allowReplaceResult: allowReplaceResult,
      source: source,
    );
  }

  ImagePreviewOpenRequest toImagePreviewOpenRequest({
    Future<void> Function(ImagePreviewEditResult result)? onReplace,
  }) {
    return ImagePreviewOpenRequest(
      items: items
          .map((item) => item.toImagePreviewItem())
          .toList(growable: false),
      initialIndex: safeInitialIndex,
      onReplace: onReplace,
      enableDownload: enableDownload,
      albumName: albumName,
    );
  }

  List<AttachmentGalleryItem> toAttachmentGalleryItems() {
    return items
        .map((item) => item.toAttachmentGalleryItem())
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'requestId': requestId,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'initialIndex': initialIndex,
      'enableDownload': enableDownload,
      'albumName': albumName,
      'allowReplaceResult': allowReplaceResult,
      'source': source,
    };
  }
}

enum DesktopMediaPreviewResultKind { replace }

class DesktopMediaPreviewResult {
  const DesktopMediaPreviewResult({
    required this.kind,
    required this.requestId,
    required this.sourceId,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  factory DesktopMediaPreviewResult.replace({
    required String requestId,
    required ImagePreviewEditResult result,
  }) {
    return DesktopMediaPreviewResult(
      kind: DesktopMediaPreviewResultKind.replace,
      requestId: requestId,
      sourceId: result.sourceId,
      filePath: result.filePath,
      filename: result.filename,
      mimeType: result.mimeType,
      size: result.size,
    );
  }

  factory DesktopMediaPreviewResult.fromJson(Map<String, dynamic> json) {
    return DesktopMediaPreviewResult(
      kind: _resultKindFromJson(json['kind']),
      requestId: _stringValue(json['requestId']),
      sourceId: _stringValue(json['sourceId']),
      filePath: _stringValue(json['filePath']),
      filename: _stringValue(json['filename']),
      mimeType: _stringValue(json['mimeType']),
      size: _intValue(json['size']) ?? 0,
    );
  }

  final DesktopMediaPreviewResultKind kind;
  final String requestId;
  final String sourceId;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;

  ImagePreviewEditResult toImagePreviewEditResult() {
    return ImagePreviewEditResult(
      sourceId: sourceId,
      filePath: filePath,
      filename: filename,
      mimeType: mimeType,
      size: size,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'requestId': requestId,
      'sourceId': sourceId,
      'filePath': filePath,
      'filename': filename,
      'mimeType': mimeType,
      'size': size,
    };
  }
}

DesktopMediaPreviewItemKind _itemKindFromJson(Object? raw) {
  final name = raw is String ? raw : '';
  return DesktopMediaPreviewItemKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => DesktopMediaPreviewItemKind.image,
  );
}

DesktopMediaPreviewResultKind _resultKindFromJson(Object? raw) {
  final name = raw is String ? raw : '';
  return DesktopMediaPreviewResultKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => DesktopMediaPreviewResultKind.replace,
  );
}

String _stringValue(Object? raw, {String fallback = ''}) {
  if (raw is String) return raw;
  return fallback;
}

String? _nullableStringValue(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : raw;
}

int? _intValue(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

Map<String, String>? _stringMapValue(Object? raw) {
  if (raw is! Map) return null;
  final result = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is String && value is String) {
      result[key] = value;
    }
  }
  return result.isEmpty ? null : result;
}

File? _fileFromPath(String? rawPath) {
  final path = rawPath?.trim();
  if (path == null || path.isEmpty) return null;
  return File(path);
}

bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;

String _newRequestId() => DateTime.now().microsecondsSinceEpoch.toString();
