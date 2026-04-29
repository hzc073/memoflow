import 'dart:math' as math;

import '../../../data/models/image_compression_settings.dart';
import 'compression_models.dart';
import 'engines/compression_engine.dart';

class CompressionPlanBuilder {
  const CompressionPlanBuilder();

  static const int maxCompressibleBytes = 500 * 1024 * 1024;
  static const double longImageAspectRatioThreshold = 1.8;
  static const int longImagePixelThreshold = 2400;
  static const int minimumReadableShortEdge = 1080;
  static const double maximumLongImageShortEdgeShrink = 0.85;

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

    final originalDisplayWidth = sourceProbe.displayWidth!;
    final originalDisplayHeight = sourceProbe.displayHeight!;
    var outputDisplayWidth = originalDisplayWidth;
    var outputDisplayHeight = originalDisplayHeight;

    switch (settings.mode) {
      case ImageCompressionResizeMode.noResize:
        return null;
      case ImageCompressionResizeMode.dimensions:
        outputDisplayWidth = settings.width;
        outputDisplayHeight = settings.height;
      case ImageCompressionResizeMode.percentage:
        outputDisplayWidth = (originalDisplayWidth * settings.width / 100)
            .round();
        outputDisplayHeight = (originalDisplayHeight * settings.height / 100)
            .round();
      case ImageCompressionResizeMode.shortEdge:
      case ImageCompressionResizeMode.longEdge:
        final useWidth = settings.mode == ImageCompressionResizeMode.longEdge
            ? originalDisplayWidth >= originalDisplayHeight
            : originalDisplayWidth <= originalDisplayHeight;
        if (useWidth) {
          outputDisplayWidth = settings.edge;
          outputDisplayHeight = 0;
        } else {
          outputDisplayWidth = 0;
          outputDisplayHeight = settings.edge;
        }
      case ImageCompressionResizeMode.fixedWidth:
        outputDisplayWidth = settings.width;
        outputDisplayHeight = 0;
      case ImageCompressionResizeMode.fixedHeight:
        outputDisplayWidth = 0;
        outputDisplayHeight = settings.height;
    }

    if (settings.doNotEnlarge) {
      final wouldEnlargeWidth =
          outputDisplayWidth > 0 && outputDisplayWidth >= originalDisplayWidth;
      final wouldEnlargeHeight =
          outputDisplayHeight > 0 &&
          outputDisplayHeight >= originalDisplayHeight;
      if (wouldEnlargeWidth || wouldEnlargeHeight) {
        return _buildResizeTarget(
          sourceProbe: sourceProbe,
          displayWidth: originalDisplayWidth,
          displayHeight: originalDisplayHeight,
        );
      }
    }

    if (outputDisplayWidth == 0 && outputDisplayHeight > 0) {
      outputDisplayWidth =
          (originalDisplayWidth * outputDisplayHeight / originalDisplayHeight)
              .round();
    } else if (outputDisplayHeight == 0 && outputDisplayWidth > 0) {
      outputDisplayHeight =
          (originalDisplayHeight * outputDisplayWidth / originalDisplayWidth)
              .round();
    }

    final safeTarget = _protectReadableLongImage(
      originalDisplayWidth: originalDisplayWidth,
      originalDisplayHeight: originalDisplayHeight,
      targetDisplayWidth: math.max(1, outputDisplayWidth),
      targetDisplayHeight: math.max(1, outputDisplayHeight),
    );
    return _buildResizeTarget(
      sourceProbe: sourceProbe,
      displayWidth: safeTarget.width,
      displayHeight: safeTarget.height,
    );
  }

  CompressionResizeTarget _buildResizeTarget({
    required CompressionSourceProbe sourceProbe,
    required int displayWidth,
    required int displayHeight,
  }) {
    final swapsAxes = switch (sourceProbe.orientation) {
      5 || 6 || 7 || 8 => true,
      _ => false,
    };
    final encodedWidth = swapsAxes ? displayHeight : displayWidth;
    final encodedHeight = swapsAxes ? displayWidth : displayHeight;
    return CompressionResizeTarget(
      width: math.max(1, encodedWidth),
      height: math.max(1, encodedHeight),
      displayWidth: math.max(1, displayWidth),
      displayHeight: math.max(1, displayHeight),
    );
  }

  ({int width, int height}) _protectReadableLongImage({
    required int originalDisplayWidth,
    required int originalDisplayHeight,
    required int targetDisplayWidth,
    required int targetDisplayHeight,
  }) {
    final originalShort = math.min(originalDisplayWidth, originalDisplayHeight);
    final originalLong = math.max(originalDisplayWidth, originalDisplayHeight);
    if (originalShort <= 0) {
      return (width: targetDisplayWidth, height: targetDisplayHeight);
    }

    final aspectRatio = originalLong / originalShort;
    final isLongImage =
        originalLong >= longImagePixelThreshold &&
        aspectRatio >= longImageAspectRatioThreshold;
    if (!isLongImage) {
      return (width: targetDisplayWidth, height: targetDisplayHeight);
    }

    final targetShort = math.min(targetDisplayWidth, targetDisplayHeight);
    final minimumShortEdge = math.min(originalShort, minimumReadableShortEdge);
    final shrinksReadableEdgeTooFar =
        targetShort < minimumShortEdge ||
        targetShort < originalShort * maximumLongImageShortEdgeShrink;
    if (!shrinksReadableEdgeTooFar) {
      return (width: targetDisplayWidth, height: targetDisplayHeight);
    }

    return (width: originalDisplayWidth, height: originalDisplayHeight);
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
