import 'dart:math' as math;

import '../../../data/models/image_compression_settings.dart';
import 'compression_models.dart';
import 'engines/compression_engine.dart';

class CompressionPlanBuilder {
  const CompressionPlanBuilder();

  static const int maxCompressibleBytes = 500 * 1024 * 1024;

  CompressionPlan build({
    required CompressionSourceProbe sourceProbe,
    required ImageCompressionSettings settings,
    required CompressionEngine engine,
    required String sourceSignature,
    required String cacheKey,
  }) {
    final outputFormat = _resolveOutputFormat(
      sourceProbe: sourceProbe,
      settings: settings,
      engine: engine,
    );
    final fallbackReason = _resolveFallbackReason(
      sourceProbe: sourceProbe,
      settings: settings,
      engine: engine,
      outputFormat: outputFormat,
    );
    final resizeTarget = fallbackReason == null
        ? _resolveResizeTarget(sourceProbe, settings.resize)
        : null;
    return CompressionPlan(
      sourceProbe: sourceProbe,
      settings: settings,
      outputFormat: outputFormat,
      engineId: engine.engineId,
      engineVersion: engine.libraryVersion,
      requiresInputConversion:
          fallbackReason == null &&
          outputFormat != null &&
          engine.requiresMatchingInputFormat &&
          sourceProbe.format != outputFormat,
      resizeTarget: resizeTarget,
      maxOutputBytes: settings.mode == ImageCompressionMode.size
          ? _resolveMaxOutputBytes(settings.sizeTarget, sourceProbe.fileSize)
          : null,
      sourceSignature: sourceSignature,
      cacheKey: cacheKey,
      fallbackReason: fallbackReason,
    );
  }

  CompressionImageFormat? _resolveOutputFormat({
    required CompressionSourceProbe sourceProbe,
    required ImageCompressionSettings settings,
    required CompressionEngine engine,
  }) {
    final requested = settings.outputFormat;
    if (requested == ImageCompressionOutputFormat.sameAsInput) {
      if (_isSupportedSourceOutput(sourceProbe.format) &&
          engine.supportsOutputFormat(sourceProbe.format)) {
        return sourceProbe.format;
      }
      return null;
    }

    final explicit = switch (requested) {
      ImageCompressionOutputFormat.sameAsInput => null,
      ImageCompressionOutputFormat.jpeg => CompressionImageFormat.jpeg,
      ImageCompressionOutputFormat.png => CompressionImageFormat.png,
      ImageCompressionOutputFormat.webp => CompressionImageFormat.webp,
      ImageCompressionOutputFormat.tiff => CompressionImageFormat.tiff,
    };
    if (explicit == null || !engine.supportsOutputFormat(explicit)) {
      return null;
    }
    return explicit;
  }

  CompressionFallbackReason? _resolveFallbackReason({
    required CompressionSourceProbe sourceProbe,
    required ImageCompressionSettings settings,
    required CompressionEngine engine,
    required CompressionImageFormat? outputFormat,
  }) {
    if (!sourceProbe.isImage) {
      return CompressionFallbackReason.invalidInput;
    }
    if (sourceProbe.fileSize > maxCompressibleBytes) {
      return CompressionFallbackReason.fileTooLarge;
    }
    if (sourceProbe.isAnimated) {
      return CompressionFallbackReason.animatedImage;
    }
    if (!_isCompressibleFormat(sourceProbe.format)) {
      return CompressionFallbackReason.unsupportedInputFormat;
    }
    if (!engine.isAvailable) {
      return CompressionFallbackReason.engineUnavailable;
    }
    if (outputFormat == null) {
      return settings.outputFormat == ImageCompressionOutputFormat.sameAsInput
          ? CompressionFallbackReason.unsupportedInputFormat
          : CompressionFallbackReason.unsupportedOutputFormat;
    }
    return null;
  }

  CompressionResizeTarget? _resolveResizeTarget(
    CompressionSourceProbe sourceProbe,
    ImageCompressionResizeSettings settings,
  ) {
    if (!settings.enabled ||
        settings.mode == ImageCompressionResizeMode.noResize ||
        sourceProbe.displayWidth == null ||
        sourceProbe.displayHeight == null) {
      return null;
    }

    final originalWidth = sourceProbe.displayWidth!;
    final originalHeight = sourceProbe.displayHeight!;
    var outputWidth = originalWidth;
    var outputHeight = originalHeight;

    switch (settings.mode) {
      case ImageCompressionResizeMode.noResize:
        return null;
      case ImageCompressionResizeMode.dimensions:
        outputWidth = settings.width;
        outputHeight = settings.height;
      case ImageCompressionResizeMode.percentage:
        outputWidth = (originalWidth * settings.width / 100).round();
        outputHeight = (originalHeight * settings.height / 100).round();
      case ImageCompressionResizeMode.shortEdge:
      case ImageCompressionResizeMode.longEdge:
        final useWidth = settings.mode == ImageCompressionResizeMode.longEdge
            ? originalWidth >= originalHeight
            : originalWidth <= originalHeight;
        if (useWidth) {
          outputWidth = settings.edge;
          outputHeight = 0;
        } else {
          outputWidth = 0;
          outputHeight = settings.edge;
        }
      case ImageCompressionResizeMode.fixedWidth:
        outputWidth = settings.width;
        outputHeight = 0;
      case ImageCompressionResizeMode.fixedHeight:
        outputWidth = 0;
        outputHeight = settings.height;
    }

    if (settings.doNotEnlarge) {
      final wouldEnlargeWidth = outputWidth > 0 && outputWidth >= originalWidth;
      final wouldEnlargeHeight =
          outputHeight > 0 && outputHeight >= originalHeight;
      if (wouldEnlargeWidth || wouldEnlargeHeight) {
        return CompressionResizeTarget(
          width: originalWidth,
          height: originalHeight,
        );
      }
    }

    if (outputWidth == 0 && outputHeight > 0) {
      outputWidth = (originalWidth * outputHeight / originalHeight).round();
    } else if (outputHeight == 0 && outputWidth > 0) {
      outputHeight = (originalHeight * outputWidth / originalWidth).round();
    }

    return CompressionResizeTarget(
      width: math.max(1, outputWidth),
      height: math.max(1, outputHeight),
    );
  }

  int _resolveMaxOutputBytes(
    ImageCompressionSizeTarget sizeTarget,
    int sourceSize,
  ) {
    if (sizeTarget.unit == ImageCompressionMaxOutputUnit.percentage) {
      return (sourceSize * sizeTarget.value / 100).floor();
    }
    final multiplier = switch (sizeTarget.unit) {
      ImageCompressionMaxOutputUnit.bytes => 1,
      ImageCompressionMaxOutputUnit.kb => 1024,
      ImageCompressionMaxOutputUnit.mb => 1024 * 1024,
      ImageCompressionMaxOutputUnit.percentage => 1,
    };
    return sizeTarget.value * multiplier;
  }

  bool _isSupportedSourceOutput(CompressionImageFormat format) =>
      format == CompressionImageFormat.jpeg ||
      format == CompressionImageFormat.png ||
      format == CompressionImageFormat.webp ||
      format == CompressionImageFormat.tiff;

  bool _isCompressibleFormat(CompressionImageFormat format) =>
      _isSupportedSourceOutput(format) ||
      format == CompressionImageFormat.gif ||
      format == CompressionImageFormat.bmp;
}
