import 'dart:convert';

import '../../../core/hash.dart';
import '../../../data/models/image_compression_settings.dart';

enum CompressionImageFormat {
  jpeg,
  png,
  webp,
  tiff,
  gif,
  bmp,
  heic,
  heif,
  unknown,
}

enum CompressionFallbackReason {
  fileTooLarge,
  unsupportedInputFormat,
  unsupportedOutputFormat,
  animatedImage,
  engineUnavailable,
  compressionFailed,
  outputBiggerThanInput,
  conversionFailed,
  invalidInput,
}

enum CompressionCacheStatus { ok, fallback, unsupported, error }

class CompressionSourceProbe {
  const CompressionSourceProbe({
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.format,
    required this.width,
    required this.height,
    required this.displayWidth,
    required this.displayHeight,
    required this.orientation,
    required this.hasAlpha,
    required this.isAnimated,
    required this.isImage,
  });

  final String path;
  final String filename;
  final String mimeType;
  final int fileSize;
  final CompressionImageFormat format;
  final int? width;
  final int? height;
  final int? displayWidth;
  final int? displayHeight;
  final int orientation;
  final bool hasAlpha;
  final bool isAnimated;
  final bool isImage;
}

class CompressionResizeTarget {
  const CompressionResizeTarget({required this.width, required this.height});

  final int width;
  final int height;

  bool sameAs(int? sourceWidth, int? sourceHeight) =>
      sourceWidth == width && sourceHeight == height;
}

class CompressionPlan {
  const CompressionPlan({
    required this.sourceProbe,
    required this.settings,
    required this.outputFormat,
    required this.engineId,
    required this.engineVersion,
    required this.requiresInputConversion,
    required this.resizeTarget,
    required this.maxOutputBytes,
    required this.sourceSignature,
    required this.cacheKey,
    required this.fallbackReason,
  });

  final CompressionSourceProbe sourceProbe;
  final ImageCompressionSettings settings;
  final CompressionImageFormat? outputFormat;
  final String engineId;
  final String engineVersion;
  final bool requiresInputConversion;
  final CompressionResizeTarget? resizeTarget;
  final int? maxOutputBytes;
  final String sourceSignature;
  final String cacheKey;
  final CompressionFallbackReason? fallbackReason;

  bool get shouldPassthrough => fallbackReason != null || outputFormat == null;

  bool get wasConverted =>
      outputFormat != null && sourceProbe.format != outputFormat;

  bool get wasResized =>
      resizeTarget != null &&
      !resizeTarget!.sameAs(
        sourceProbe.displayWidth ?? sourceProbe.width,
        sourceProbe.displayHeight ?? sourceProbe.height,
      );

  CompressionPlan copyWith({
    CompressionImageFormat? outputFormat,
    String? engineId,
    String? engineVersion,
    bool? requiresInputConversion,
    CompressionResizeTarget? resizeTarget,
    int? maxOutputBytes,
    String? sourceSignature,
    String? cacheKey,
    CompressionFallbackReason? fallbackReason,
    bool clearFallbackReason = false,
  }) {
    return CompressionPlan(
      sourceProbe: sourceProbe,
      settings: settings,
      outputFormat: outputFormat ?? this.outputFormat,
      engineId: engineId ?? this.engineId,
      engineVersion: engineVersion ?? this.engineVersion,
      requiresInputConversion:
          requiresInputConversion ?? this.requiresInputConversion,
      resizeTarget: resizeTarget ?? this.resizeTarget,
      maxOutputBytes: maxOutputBytes ?? this.maxOutputBytes,
      sourceSignature: sourceSignature ?? this.sourceSignature,
      cacheKey: cacheKey ?? this.cacheKey,
      fallbackReason: clearFallbackReason
          ? null
          : fallbackReason ?? this.fallbackReason,
    );
  }
}

class CompressionCacheManifest {
  const CompressionCacheManifest({
    required this.status,
    required this.engine,
    required this.libraryVersion,
    required this.mode,
    required this.sourceFormat,
    required this.outputFormat,
    required this.size,
    required this.width,
    required this.height,
    required this.hash,
    required this.fallbackReason,
  });

  final CompressionCacheStatus status;
  final String engine;
  final String libraryVersion;
  final ImageCompressionMode mode;
  final CompressionImageFormat sourceFormat;
  final CompressionImageFormat? outputFormat;
  final int? size;
  final int? width;
  final int? height;
  final String? hash;
  final CompressionFallbackReason? fallbackReason;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'status': status.name,
    'engine': engine,
    'libraryVersion': libraryVersion,
    'mode': mode.name,
    'sourceFormat': sourceFormat.name,
    'outputFormat': outputFormat?.name,
    'size': size,
    'width': width,
    'height': height,
    'hash': hash,
    'fallbackReason': fallbackReason?.name,
  };

  factory CompressionCacheManifest.fromJson(Map<String, dynamic> json) {
    return CompressionCacheManifest(
      status: _readEnum(
        raw: json['status'],
        values: CompressionCacheStatus.values,
        fallback: CompressionCacheStatus.error,
      ),
      engine: (json['engine'] as String? ?? '').trim(),
      libraryVersion: (json['libraryVersion'] as String? ?? '').trim(),
      mode: _readEnum(
        raw: json['mode'],
        values: ImageCompressionMode.values,
        fallback: ImageCompressionMode.quality,
      ),
      sourceFormat: _readEnum(
        raw: json['sourceFormat'],
        values: CompressionImageFormat.values,
        fallback: CompressionImageFormat.unknown,
      ),
      outputFormat: _readNullableEnum(
        raw: json['outputFormat'],
        values: CompressionImageFormat.values,
      ),
      size: _readInt(json['size']),
      width: _readInt(json['width']),
      height: _readInt(json['height']),
      hash: (json['hash'] as String?)?.trim(),
      fallbackReason: _readNullableEnum(
        raw: json['fallbackReason'],
        values: CompressionFallbackReason.values,
      ),
    );
  }
}

class CompressionCacheHit {
  const CompressionCacheHit({required this.outputPath, required this.manifest});

  final String outputPath;
  final CompressionCacheManifest manifest;
}

class CompressionJobKeyFactory {
  const CompressionJobKeyFactory();

  String build({
    required String pipelineVersion,
    required String libraryVersion,
    required String sourceSignature,
    required ImageCompressionSettings settings,
    required CompressionImageFormat? outputFormat,
    required String engineId,
  }) {
    final raw = jsonEncode({
      'pipelineVersion': pipelineVersion,
      'libraryVersion': libraryVersion,
      'sourceSignature': sourceSignature,
      'settings': settings.toJson(),
      'outputFormat': outputFormat?.name,
      'engineId': engineId,
    });
    return fnv1a64Hex(raw);
  }
}

T _readEnum<T extends Enum>({
  required Object? raw,
  required List<T> values,
  required T fallback,
}) {
  if (raw is String) {
    final normalized = raw.trim();
    for (final value in values) {
      if (value.name == normalized) {
        return value;
      }
    }
  }
  return fallback;
}

T? _readNullableEnum<T extends Enum>({
  required Object? raw,
  required List<T> values,
}) {
  if (raw is! String) return null;
  final normalized = raw.trim();
  if (normalized.isEmpty) return null;
  for (final value in values) {
    if (value.name == normalized) {
      return value;
    }
  }
  return null;
}

int? _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}
