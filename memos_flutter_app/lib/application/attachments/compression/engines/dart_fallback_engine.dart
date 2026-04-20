import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../../data/models/image_compression_settings.dart';
import '../compression_models.dart';
import 'compression_engine.dart';

class DartFallbackCompressionEngine implements CompressionEngine {
  DartFallbackCompressionEngine();

  @override
  String get engineId => 'dart_fallback';

  @override
  String get libraryVersion => 'image_package';

  @override
  bool get isAvailable => true;

  @override
  bool get requiresMatchingInputFormat => false;

  @override
  bool supportsOutputFormat(CompressionImageFormat format) =>
      format == CompressionImageFormat.jpeg ||
      format == CompressionImageFormat.png ||
      format == CompressionImageFormat.tiff;

  @override
  Future<CompressionEngineResult> compress(
    CompressionEngineRequest request,
  ) async {
    final result = await compute(
      _runFallbackCompression,
      _FallbackJob.fromRequest(request),
    );
    if (result == null) {
      throw StateError('dart fallback compression failed');
    }
    final output = File(request.outputPath);
    if (!output.parent.existsSync()) {
      output.parent.createSync(recursive: true);
    }
    await output.writeAsBytes(result.bytes, flush: true);
    return CompressionEngineResult(
      outputPath: output.path,
      width: result.width,
      height: result.height,
    );
  }

  @override
  Future<void> convert(CompressionConversionRequest request) async {
    final job = _FallbackJob(
      sourcePath: request.sourcePath,
      outputFormat: request.outputFormat.name,
      mode: ImageCompressionMode.quality.name,
      jpegQuality: JpegCompressionSettings.defaults.quality,
      pngOptimizationLevel: PngCompressionSettings.defaults.optimizationLevel,
      resizeWidth: request.resizeTarget?.width,
      resizeHeight: request.resizeTarget?.height,
    );
    final result = await compute(_runFallbackCompression, job);
    if (result == null) {
      throw StateError('dart fallback conversion failed');
    }
    final output = File(request.outputPath);
    if (!output.parent.existsSync()) {
      output.parent.createSync(recursive: true);
    }
    await output.writeAsBytes(result.bytes, flush: true);
  }
}

class _FallbackJob {
  const _FallbackJob({
    required this.sourcePath,
    required this.outputFormat,
    required this.mode,
    required this.jpegQuality,
    required this.pngOptimizationLevel,
    this.resizeWidth,
    this.resizeHeight,
    this.maxOutputBytes,
  });

  factory _FallbackJob.fromRequest(CompressionEngineRequest request) {
    return _FallbackJob(
      sourcePath: request.sourcePath,
      outputFormat: request.outputFormat.name,
      mode: request.settings.mode.name,
      jpegQuality: request.settings.jpeg.quality,
      pngOptimizationLevel: request.settings.png.optimizationLevel,
      resizeWidth: request.resizeTarget?.width,
      resizeHeight: request.resizeTarget?.height,
      maxOutputBytes: request.maxOutputBytes,
    );
  }

  final String sourcePath;
  final String outputFormat;
  final String mode;
  final int jpegQuality;
  final int pngOptimizationLevel;
  final int? resizeWidth;
  final int? resizeHeight;
  final int? maxOutputBytes;
}

class _FallbackCompressionResult {
  const _FallbackCompressionResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

_FallbackCompressionResult? _runFallbackCompression(_FallbackJob job) {
  try {
    final source = File(job.sourcePath);
    if (!source.existsSync()) {
      return null;
    }
    final bytes = source.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }
    final normalized = img.bakeOrientation(decoded);
    final resized = _resize(
      normalized,
      width: job.resizeWidth,
      height: job.resizeHeight,
    );

    final format = CompressionImageFormat.values.firstWhere(
      (value) => value.name == job.outputFormat,
      orElse: () => CompressionImageFormat.unknown,
    );
    final mode = ImageCompressionMode.values.firstWhere(
      (value) => value.name == job.mode,
      orElse: () => ImageCompressionMode.quality,
    );

    final encoded = switch (mode) {
      ImageCompressionMode.quality => _encode(
        resized,
        format: format,
        jpegQuality: job.jpegQuality,
        pngOptimizationLevel: job.pngOptimizationLevel,
      ),
      ImageCompressionMode.size => _encodeToSize(
        resized,
        format: format,
        targetBytes: job.maxOutputBytes,
        jpegQuality: job.jpegQuality,
        pngOptimizationLevel: job.pngOptimizationLevel,
      ),
    };
    if (encoded == null) {
      return null;
    }
    return _FallbackCompressionResult(
      bytes: encoded,
      width: resized.width,
      height: resized.height,
    );
  } catch (_) {
    return null;
  }
}

img.Image _resize(
  img.Image image, {
  required int? width,
  required int? height,
}) {
  if (width == null || height == null) {
    return image;
  }
  if (width == image.width && height == image.height) {
    return image;
  }
  return img.copyResize(
    image,
    width: width,
    height: height,
    interpolation: img.Interpolation.cubic,
  );
}

Uint8List? _encode(
  img.Image image, {
  required CompressionImageFormat format,
  required int jpegQuality,
  required int pngOptimizationLevel,
}) {
  return switch (format) {
    CompressionImageFormat.jpeg => Uint8List.fromList(
      img.encodeJpg(image, quality: jpegQuality),
    ),
    CompressionImageFormat.png => Uint8List.fromList(
      img.encodePng(image, level: pngOptimizationLevel),
    ),
    CompressionImageFormat.tiff => Uint8List.fromList(img.encodeTiff(image)),
    CompressionImageFormat.webp => null,
    _ => null,
  };
}

Uint8List? _encodeToSize(
  img.Image image, {
  required CompressionImageFormat format,
  required int? targetBytes,
  required int jpegQuality,
  required int pngOptimizationLevel,
}) {
  if (targetBytes == null || targetBytes <= 0) {
    return _encode(
      image,
      format: format,
      jpegQuality: jpegQuality,
      pngOptimizationLevel: pngOptimizationLevel,
    );
  }

  if (format == CompressionImageFormat.jpeg) {
    Uint8List? bestFit;
    var low = 1;
    var high = jpegQuality.clamp(1, 100);
    while (low <= high) {
      final mid = ((low + high) / 2).floor();
      final candidate = Uint8List.fromList(img.encodeJpg(image, quality: mid));
      if (candidate.lengthInBytes <= targetBytes) {
        bestFit = candidate;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return bestFit ??
        Uint8List.fromList(img.encodeJpg(image, quality: high.clamp(1, 100)));
  }

  return _encode(
    image,
    format: format,
    jpegQuality: jpegQuality,
    pngOptimizationLevel: pngOptimizationLevel,
  );
}
