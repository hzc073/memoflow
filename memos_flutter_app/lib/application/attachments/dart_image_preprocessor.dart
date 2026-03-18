import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../data/models/image_compression_settings.dart';
import 'image_preprocessor.dart';

class DartImagePreprocessor implements ImagePreprocessor {
  DartImagePreprocessor();

  @override
  String get engine => 'dart';

  @override
  bool get supportsWebp => false;

  @override
  bool get isAvailable => true;

  @override
  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request) async {
    final job = _DartImageJob(
      sourcePath: request.sourcePath,
      maxSide: request.maxSide,
      quality: request.quality,
      format: request.format.name,
    );
    final result = await compute(_runDartImageJob, job);
    if (result == null) {
      throw StateError('dart_image_preprocessor failed');
    }
    final outFile = File(request.targetPath);
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }
    await outFile.writeAsBytes(result.bytes, flush: true);
    return ImagePreprocessResult(
      outputPath: outFile.path,
      width: result.width,
      height: result.height,
    );
  }
}

class _DartImageJob {
  const _DartImageJob({
    required this.sourcePath,
    required this.maxSide,
    required this.quality,
    required this.format,
  });

  final String sourcePath;
  final int maxSide;
  final int quality;
  final String format;
}

class _DartImageJobResult {
  const _DartImageJobResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

_DartImageJobResult? _runDartImageJob(_DartImageJob job) {
  try {
    final bytes = File(job.sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = _resizeImage(decoded, job.maxSide);
    final encodedFormat = _resolveFormat(job.format);
    // image package doesn't support WebP encoding on all platforms.
    final encodedBytes = switch (encodedFormat) {
      ImageCompressionFormat.jpeg =>
        Uint8List.fromList(img.encodeJpg(resized, quality: job.quality)),
      ImageCompressionFormat.webp =>
        Uint8List.fromList(img.encodeJpg(resized, quality: job.quality)),
      ImageCompressionFormat.auto =>
        Uint8List.fromList(img.encodeJpg(resized, quality: job.quality)),
    };
    return _DartImageJobResult(
      bytes: encodedBytes,
      width: resized.width,
      height: resized.height,
    );
  } catch (_) {
    return null;
  }
}

img.Image _resizeImage(img.Image source, int maxSide) {
  final maxDim = max(source.width, source.height);
  if (maxDim <= maxSide || maxSide <= 0) {
    return source;
  }
  final scale = maxSide / maxDim;
  final targetWidth = (source.width * scale).round().clamp(1, maxSide);
  final targetHeight = (source.height * scale).round().clamp(1, maxSide);
  return img.copyResize(
    source,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );
}

ImageCompressionFormat _resolveFormat(String raw) {
  return ImageCompressionFormat.values.firstWhere(
    (format) => format.name == raw,
    orElse: () => ImageCompressionFormat.jpeg,
  );
}
