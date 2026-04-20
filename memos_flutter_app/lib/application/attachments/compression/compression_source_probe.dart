import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'compression_models.dart';

class CompressionSourceProbeService {
  const CompressionSourceProbeService();

  Future<CompressionSourceProbe> probe({
    required String path,
    required String filename,
    required String mimeType,
  }) async {
    return compute(
      _probeImageSource,
      _ProbeRequest(path: path, filename: filename, mimeType: mimeType),
    );
  }
}

class _ProbeRequest {
  const _ProbeRequest({
    required this.path,
    required this.filename,
    required this.mimeType,
  });

  final String path;
  final String filename;
  final String mimeType;
}

CompressionSourceProbe _probeImageSource(_ProbeRequest request) {
  try {
    final file = File(request.path);
    if (!file.existsSync()) {
      return _fallbackProbe(request);
    }

    final bytes = file.readAsBytesSync();
    final mimeType = request.mimeType.trim();
    final decoder = img.findDecoderForData(bytes);
    final format = _detectFormat(
      bytes: bytes,
      filename: request.filename,
      mimeType: mimeType,
      decoder: decoder,
    );
    final decoded = decoder?.decode(Uint8List.fromList(bytes));
    final orientation = decoded?.exif.imageIfd.orientation ?? 1;
    final swapsAxes = switch (orientation) {
      5 || 6 || 7 || 8 => true,
      _ => false,
    };
    final width = decoded?.width;
    final height = decoded?.height;
    final displayWidth = swapsAxes ? height : width;
    final displayHeight = swapsAxes ? width : height;
    decoder?.startDecode(Uint8List.fromList(bytes));
    final numFrames = decoder?.numFrames() ?? 1;
    final hasAlpha =
        (decoded?.numChannels ?? 0) >= 4 ||
        format == CompressionImageFormat.png;
    final isAnimated =
        (format == CompressionImageFormat.gif ||
            format == CompressionImageFormat.webp) &&
        numFrames > 1;

    return CompressionSourceProbe(
      path: request.path,
      filename: request.filename,
      mimeType: mimeType,
      fileSize: file.lengthSync(),
      format: format,
      width: width,
      height: height,
      displayWidth: displayWidth,
      displayHeight: displayHeight,
      orientation: orientation,
      hasAlpha: hasAlpha,
      isAnimated: isAnimated,
      isImage: mimeType.toLowerCase().startsWith('image/'),
    );
  } catch (_) {
    return _fallbackProbe(request);
  }
}

CompressionSourceProbe _fallbackProbe(_ProbeRequest request) {
  final mimeType = request.mimeType.trim();
  final file = File(request.path);
  int fileSize = 0;
  try {
    if (file.existsSync()) {
      fileSize = file.lengthSync();
    }
  } catch (_) {}

  return CompressionSourceProbe(
    path: request.path,
    filename: request.filename,
    mimeType: mimeType,
    fileSize: fileSize,
    format: _formatFromMimeTypeOrName(mimeType, request.filename),
    width: null,
    height: null,
    displayWidth: null,
    displayHeight: null,
    orientation: 1,
    hasAlpha: false,
    isAnimated: false,
    isImage: mimeType.toLowerCase().startsWith('image/'),
  );
}

CompressionImageFormat _detectFormat({
  required List<int> bytes,
  required String filename,
  required String mimeType,
  required img.Decoder? decoder,
}) {
  if (decoder != null) {
    final runtime = decoder.runtimeType.toString();
    if (runtime.contains('Jpeg')) return CompressionImageFormat.jpeg;
    if (runtime.contains('Png')) return CompressionImageFormat.png;
    if (runtime.contains('WebP')) return CompressionImageFormat.webp;
    if (runtime.contains('Gif')) return CompressionImageFormat.gif;
    if (runtime.contains('Tiff')) return CompressionImageFormat.tiff;
    if (runtime.contains('Bmp')) return CompressionImageFormat.bmp;
  }
  return _formatFromMimeTypeOrName(mimeType, filename);
}

CompressionImageFormat _formatFromMimeTypeOrName(
  String mimeType,
  String filename,
) {
  final normalizedMime = mimeType.trim().toLowerCase();
  if (normalizedMime == 'image/jpeg') return CompressionImageFormat.jpeg;
  if (normalizedMime == 'image/png') return CompressionImageFormat.png;
  if (normalizedMime == 'image/webp') return CompressionImageFormat.webp;
  if (normalizedMime == 'image/tiff' || normalizedMime == 'image/tif') {
    return CompressionImageFormat.tiff;
  }
  if (normalizedMime == 'image/gif') return CompressionImageFormat.gif;
  if (normalizedMime == 'image/bmp') return CompressionImageFormat.bmp;
  if (normalizedMime == 'image/heic') return CompressionImageFormat.heic;
  if (normalizedMime == 'image/heif') return CompressionImageFormat.heif;

  final extension = p.extension(filename).trim().toLowerCase();
  return switch (extension) {
    '.jpg' || '.jpeg' => CompressionImageFormat.jpeg,
    '.png' => CompressionImageFormat.png,
    '.webp' => CompressionImageFormat.webp,
    '.tif' || '.tiff' => CompressionImageFormat.tiff,
    '.gif' => CompressionImageFormat.gif,
    '.bmp' => CompressionImageFormat.bmp,
    '.heic' => CompressionImageFormat.heic,
    '.heif' => CompressionImageFormat.heif,
    _ => CompressionImageFormat.unknown,
  };
}
