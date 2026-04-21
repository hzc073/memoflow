import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../data/logs/log_manager.dart';
import '../../data/models/image_compression_settings.dart';
import 'compression/compression_models.dart';
import 'compression/compression_pipeline.dart';
import 'compression/compression_plan_builder.dart';
import 'compression/compression_source_probe.dart';
import 'compression/compression_cache_store.dart';
import 'compression/engines/caesium_ffi_engine.dart';
import 'compression/engines/dart_fallback_engine.dart';

class AttachmentPreprocessRequest {
  const AttachmentPreprocessRequest({
    required this.filePath,
    required this.filename,
    required this.mimeType,
    this.skipCompression = false,
  });

  final String filePath;
  final String filename;
  final String mimeType;
  final bool skipCompression;
}

class AttachmentPreprocessResult {
  const AttachmentPreprocessResult({
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.width,
    this.height,
    this.hash,
    this.sourceSig,
    this.compressKey,
    this.sourceFormat,
    this.effectiveOutputFormat,
    this.engine,
    this.engineVersion,
    this.sourceSize,
    this.sourceWidth,
    this.sourceHeight,
    this.sourceDisplayWidth,
    this.sourceDisplayHeight,
    this.sourceOrientation,
    this.sizeDelta,
    this.widthDelta,
    this.heightDelta,
    this.widthScale,
    this.heightScale,
    this.fromCache = false,
    this.fallback = false,
    this.wasConverted = false,
    this.wasResized = false,
    this.fallbackReason,
  });

  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final int? width;
  final int? height;
  final String? hash;
  final String? sourceSig;
  final String? compressKey;
  final CompressionImageFormat? sourceFormat;
  final CompressionImageFormat? effectiveOutputFormat;
  final String? engine;
  final String? engineVersion;
  final int? sourceSize;
  final int? sourceWidth;
  final int? sourceHeight;
  final int? sourceDisplayWidth;
  final int? sourceDisplayHeight;
  final int? sourceOrientation;
  final int? sizeDelta;
  final int? widthDelta;
  final int? heightDelta;
  final double? widthScale;
  final double? heightScale;
  final bool fromCache;
  final bool fallback;
  final bool wasConverted;
  final bool wasResized;
  final CompressionFallbackReason? fallbackReason;
}

Map<String, Object?> buildAttachmentPreprocessResultLogContext(
  AttachmentPreprocessResult result,
) {
  return {
    'sourceFileSize': result.sourceSize,
    'sourceRawWidth': result.sourceWidth,
    'sourceRawHeight': result.sourceHeight,
    'sourceDisplayWidth': result.sourceDisplayWidth,
    'sourceDisplayHeight': result.sourceDisplayHeight,
    'sourceOrientation': result.sourceOrientation,
    'processedSize': result.size,
    'processedWidth': result.width,
    'processedHeight': result.height,
    'sizeDelta': result.sizeDelta,
    'widthDelta': result.widthDelta,
    'heightDelta': result.heightDelta,
    'widthScale': result.widthScale,
    'heightScale': result.heightScale,
  };
}

abstract class AttachmentPreprocessor {
  Future<AttachmentPreprocessResult> preprocess(
    AttachmentPreprocessRequest request,
  );
}

typedef ImageCompressionSettingsLoader =
    Future<ImageCompressionSettings> Function();

class DefaultAttachmentPreprocessor implements AttachmentPreprocessor {
  DefaultAttachmentPreprocessor({
    required ImageCompressionSettingsLoader loadSettings,
    CompressionPipeline? pipeline,
    CompressionSourceProbeService? probeService,
    LogManager? logManager,
  }) : _loadSettings = loadSettings,
       _probeService = probeService ?? const CompressionSourceProbeService(),
       _logManager = logManager ?? LogManager.instance,
       _pipeline =
           pipeline ??
           CompressionPipeline(
             probeService:
                 probeService ?? const CompressionSourceProbeService(),
             planBuilder: const CompressionPlanBuilder(),
             cacheStore: CompressionCacheStore(),
             primaryEngine: CaesiumFfiCompressionEngine(),
             fallbackEngine: DartFallbackCompressionEngine(),
             logManager: logManager ?? LogManager.instance,
           );

  final ImageCompressionSettingsLoader _loadSettings;
  final CompressionSourceProbeService _probeService;
  final LogManager _logManager;
  final CompressionPipeline _pipeline;

  @override
  Future<AttachmentPreprocessResult> preprocess(
    AttachmentPreprocessRequest request,
  ) async {
    final settings = await _loadSettings();
    final normalizedPath = _normalizePath(request.filePath);
    if (normalizedPath.isEmpty) {
      throw const FormatException('file_path missing');
    }
    final file = File(normalizedPath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', normalizedPath);
    }

    final filename = request.filename.trim().isEmpty
        ? normalizedPath.split(Platform.pathSeparator).last
        : request.filename.trim();
    final mimeType = request.mimeType.trim().isEmpty
        ? 'application/octet-stream'
        : request.mimeType.trim();
    final probe = await _probeService.probe(
      path: normalizedPath,
      filename: filename,
      mimeType: mimeType,
    );
    final sourceDisplayWidth = probe.displayWidth ?? probe.width;
    final sourceDisplayHeight = probe.displayHeight ?? probe.height;
    _logManager.debug(
      'AttachmentPreprocess: input_probe',
      context: {
        'filePath': normalizedPath,
        'filename': filename,
        'mimeType': mimeType,
        'skipCompression': request.skipCompression,
        ..._settingsLogContext(settings),
        ..._probeLogContext(probe),
      },
    );

    if (!probe.isImage || request.skipCompression || !settings.enabled) {
      final bypassReason = !probe.isImage
          ? 'not_image'
          : request.skipCompression
          ? 'skip_compression'
          : 'compression_disabled';
      _logManager.debug(
        'AttachmentPreprocess: bypass',
        context: {
          'reason': bypassReason,
          'filePath': normalizedPath,
          'filename': filename,
          'mimeType': mimeType,
          ..._probeLogContext(probe),
        },
      );
      final bypassResult = AttachmentPreprocessResult(
        filePath: normalizedPath,
        filename: filename,
        mimeType: mimeType,
        size: probe.fileSize,
        width: sourceDisplayWidth,
        height: sourceDisplayHeight,
        hash: probe.isImage ? await _computeSha256(normalizedPath) : null,
        sourceFormat: probe.format,
        sourceSize: probe.fileSize,
        sourceWidth: probe.width,
        sourceHeight: probe.height,
        sourceDisplayWidth: sourceDisplayWidth,
        sourceDisplayHeight: sourceDisplayHeight,
        sourceOrientation: probe.orientation,
        sizeDelta: 0,
        widthDelta: _delta(sourceDisplayWidth, sourceDisplayWidth),
        heightDelta: _delta(sourceDisplayHeight, sourceDisplayHeight),
        widthScale: _scale(sourceDisplayWidth, sourceDisplayWidth),
        heightScale: _scale(sourceDisplayHeight, sourceDisplayHeight),
        fromCache: false,
        fallback: false,
      );
      _logManager.info(
        'AttachmentPreprocess: bypass_result',
        context: {
          'reason': bypassReason,
          'filePath': normalizedPath,
          'filename': filename,
          'mimeType': mimeType,
          'resizeEnabled': settings.resize.enabled,
          'resizeMode': settings.resize.mode.name,
          ...buildAttachmentPreprocessResultLogContext(bypassResult),
        },
      );
      return bypassResult;
    }

    final result = await _pipeline.process(
      CompressionPipelineRequest(
        path: normalizedPath,
        filename: filename,
        mimeType: mimeType,
        settings: settings,
      ),
    );
    final outputResult = AttachmentPreprocessResult(
      filePath: result.filePath,
      filename: result.filename,
      mimeType: result.mimeType,
      size: result.size,
      width: result.width,
      height: result.height,
      hash: result.hash,
      sourceSig: result.sourceSignature,
      compressKey: result.cacheKey,
      sourceFormat: result.sourceFormat,
      effectiveOutputFormat: result.effectiveOutputFormat,
      engine: result.engineId,
      engineVersion: result.engineVersion,
      sourceSize: probe.fileSize,
      sourceWidth: probe.width,
      sourceHeight: probe.height,
      sourceDisplayWidth: sourceDisplayWidth,
      sourceDisplayHeight: sourceDisplayHeight,
      sourceOrientation: probe.orientation,
      sizeDelta: result.size - probe.fileSize,
      widthDelta: _delta(sourceDisplayWidth, result.width),
      heightDelta: _delta(sourceDisplayHeight, result.height),
      widthScale: _scale(sourceDisplayWidth, result.width),
      heightScale: _scale(sourceDisplayHeight, result.height),
      fromCache: result.fromCache,
      fallback: result.fallback,
      wasConverted: result.wasConverted,
      wasResized: result.wasResized,
      fallbackReason: result.fallbackReason,
    );
    _logManager.info(
      'AttachmentPreprocess: output',
      context: {
        'inputPath': normalizedPath,
        'outputPath': result.filePath,
        'filename': result.filename,
        'mimeType': result.mimeType,
        'compressionMode': settings.mode.name,
        'resizeEnabled': settings.resize.enabled,
        'resizeMode': settings.resize.mode.name,
        'engine': result.engineId,
        'engineVersion': result.engineVersion,
        'fallback': result.fallback,
        'fromCache': result.fromCache,
        'wasConverted': result.wasConverted,
        'wasResized': result.wasResized,
        'fallbackReason': result.fallbackReason?.name,
        'outputFormat': result.effectiveOutputFormat?.name,
        ...buildAttachmentPreprocessResultLogContext(outputResult),
      },
    );
    return outputResult;
  }

  String _normalizePath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('file://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) return uri.toFilePath();
    }
    return trimmed;
  }

  Future<String?> _computeSha256(String path) async {
    try {
      final digest = await sha256.bind(File(path).openRead()).first;
      return digest.toString();
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _settingsLogContext(ImageCompressionSettings settings) {
    return {
      'compressionEnabled': settings.enabled,
      'compressionMode': settings.mode.name,
      'outputFormatSetting': settings.outputFormat.name,
      'lossless': settings.lossless,
      'keepMetadata': settings.keepMetadata,
      'skipIfBigger': settings.skipIfBigger,
      'resizeEnabled': settings.resize.enabled,
      'resizeMode': settings.resize.mode.name,
      'resizeWidth': settings.resize.width,
      'resizeHeight': settings.resize.height,
      'resizeEdge': settings.resize.edge,
      'resizeDoNotEnlarge': settings.resize.doNotEnlarge,
    };
  }

  Map<String, Object?> _probeLogContext(CompressionSourceProbe probe) {
    return {
      'sourceFormat': probe.format.name,
      'sourceSize': probe.fileSize,
      'sourceWidth': probe.width,
      'sourceHeight': probe.height,
      'sourceDisplayWidth': probe.displayWidth,
      'sourceDisplayHeight': probe.displayHeight,
      'sourceOrientation': probe.orientation,
      'sourceAnimated': probe.isAnimated,
      'sourceHasAlpha': probe.hasAlpha,
      'sourceIsImage': probe.isImage,
    };
  }

  int? _delta(int? source, int? target) {
    if (source == null || target == null) return null;
    return target - source;
  }

  double? _scale(int? source, int? target) {
    if (source == null || target == null || source <= 0) return null;
    return double.parse((target / source).toStringAsFixed(3));
  }
}
