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
  final bool fromCache;
  final bool fallback;
  final bool wasConverted;
  final bool wasResized;
  final CompressionFallbackReason? fallbackReason;
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

    if (!probe.isImage || request.skipCompression || !settings.enabled) {
      return AttachmentPreprocessResult(
        filePath: normalizedPath,
        filename: filename,
        mimeType: mimeType,
        size: probe.fileSize,
        width: probe.displayWidth ?? probe.width,
        height: probe.displayHeight ?? probe.height,
        hash: probe.isImage ? await _computeSha256(normalizedPath) : null,
        sourceFormat: probe.format,
        fromCache: false,
        fallback: false,
      );
    }

    final result = await _pipeline.process(
      CompressionPipelineRequest(
        path: normalizedPath,
        filename: filename,
        mimeType: mimeType,
        settings: settings,
      ),
    );
    _logManager.debug(
      'AttachmentPreprocess: pipeline_result',
      context: {
        'engine': result.engineId,
        'fallback': result.fallback,
        'fromCache': result.fromCache,
        'outputFormat': result.effectiveOutputFormat?.name,
      },
    );
    return AttachmentPreprocessResult(
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
      fromCache: result.fromCache,
      fallback: result.fallback,
      wasConverted: result.wasConverted,
      wasResized: result.wasResized,
      fallbackReason: result.fallbackReason,
    );
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
}
