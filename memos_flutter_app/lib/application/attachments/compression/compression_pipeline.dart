import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../data/logs/log_manager.dart';
import '../../../data/models/image_compression_settings.dart';
import 'compression_cache_store.dart';
import 'compression_models.dart';
import 'compression_plan_builder.dart';
import 'compression_source_probe.dart';
import 'conversion/intermediate_conversion.dart';
import 'engines/compression_engine.dart';

class CompressionPipelineRequest {
  const CompressionPipelineRequest({
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.settings,
  });

  final String path;
  final String filename;
  final String mimeType;
  final ImageCompressionSettings settings;
}

class CompressionPipelineResult {
  const CompressionPipelineResult({
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.width,
    required this.height,
    required this.hash,
    required this.sourceSignature,
    required this.cacheKey,
    required this.sourceFormat,
    required this.effectiveOutputFormat,
    required this.engineId,
    required this.engineVersion,
    required this.fromCache,
    required this.fallback,
    required this.wasConverted,
    required this.wasResized,
    required this.fallbackReason,
  });

  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final int? width;
  final int? height;
  final String? hash;
  final String sourceSignature;
  final String cacheKey;
  final CompressionImageFormat sourceFormat;
  final CompressionImageFormat? effectiveOutputFormat;
  final String engineId;
  final String engineVersion;
  final bool fromCache;
  final bool fallback;
  final bool wasConverted;
  final bool wasResized;
  final CompressionFallbackReason? fallbackReason;
}

class CompressionPipeline {
  CompressionPipeline({
    required CompressionSourceProbeService probeService,
    required CompressionPlanBuilder planBuilder,
    required CompressionCacheStore cacheStore,
    required CompressionEngine primaryEngine,
    required CompressionEngine fallbackEngine,
    LogManager? logManager,
  }) : _probeService = probeService,
       _planBuilder = planBuilder,
       _cacheStore = cacheStore,
       _primaryEngine = primaryEngine,
       _fallbackEngine = fallbackEngine,
       _conversionService = IntermediateConversionService(cacheStore),
       _logManager = logManager ?? LogManager.instance;

  static const String pipelineVersion = 'caesium_pipeline_v2';

  final CompressionSourceProbeService _probeService;
  final CompressionPlanBuilder _planBuilder;
  final CompressionCacheStore _cacheStore;
  final CompressionEngine _primaryEngine;
  final CompressionEngine _fallbackEngine;
  final IntermediateConversionService _conversionService;
  final LogManager _logManager;
  final CompressionJobKeyFactory _jobKeyFactory =
      const CompressionJobKeyFactory();

  Future<CompressionPipelineResult> process(
    CompressionPipelineRequest request,
  ) async {
    final sourceProbe = await _probeService.probe(
      path: request.path,
      filename: request.filename,
      mimeType: request.mimeType,
    );
    final engine = _primaryEngine.isAvailable
        ? _primaryEngine
        : _fallbackEngine;
    final sourceSignature = await _computeSourceSignature(
      request.path,
      sourceProbe.fileSize,
    );
    var plan = _planBuilder.build(
      sourceProbe: sourceProbe,
      settings: request.settings,
      engine: engine,
      sourceSignature: sourceSignature,
      cacheKey: 'pending',
    );
    final cacheKey = _jobKeyFactory.build(
      pipelineVersion: pipelineVersion,
      libraryVersion: engine.libraryVersion,
      sourceSignature: sourceSignature,
      settings: request.settings,
      outputFormat: plan.outputFormat,
      engineId: engine.engineId,
    );
    plan = plan.copyWith(cacheKey: cacheKey);
    _logManager.debug(
      'CompressionPipeline: plan',
      context: {
        'engine': plan.engineId,
        'engineVersion': plan.engineVersion,
        'sourceFormat': sourceProbe.format.name,
        'sourceSize': sourceProbe.fileSize,
        'sourceWidth': sourceProbe.width,
        'sourceHeight': sourceProbe.height,
        'sourceDisplayWidth': sourceProbe.displayWidth,
        'sourceDisplayHeight': sourceProbe.displayHeight,
        'sourceOrientation': sourceProbe.orientation,
        'outputFormat': plan.outputFormat?.name,
        'requiresInputConversion': plan.requiresInputConversion,
        'resizeTargetWidth': plan.resizeTarget?.width,
        'resizeTargetHeight': plan.resizeTarget?.height,
        'maxOutputBytes': plan.maxOutputBytes,
        'shouldPassthrough': plan.shouldPassthrough,
        'fallbackReason': plan.fallbackReason?.name,
        'cacheKey': plan.cacheKey,
        ..._resizeSettingsLogContext(plan),
        ..._dimensionDeltaContext(
          sourceWidth: sourceProbe.displayWidth ?? sourceProbe.width,
          sourceHeight: sourceProbe.displayHeight ?? sourceProbe.height,
          outputWidth: plan.resizeTarget?.width,
          outputHeight: plan.resizeTarget?.height,
        ),
      },
    );

    final cacheHit = await _cacheStore.read(plan.cacheKey, plan.outputFormat);
    if (cacheHit != null) {
      final cached = await _resolveCachedResult(
        request: request,
        sourceProbe: sourceProbe,
        plan: plan,
        cacheHit: cacheHit,
      );
      if (cached != null) {
        _logManager.debug(
          'CompressionPipeline: cache_hit',
          context: {
            'engine': plan.engineId,
            'outputFormat': cached.effectiveOutputFormat?.name,
            'sourceSize': sourceProbe.fileSize,
            'outputSize': cached.size,
            'outputWidth': cached.width,
            'outputHeight': cached.height,
            'fallback': cached.fallback,
            'wasResized': cached.wasResized,
            'fallbackReason': cached.fallbackReason?.name,
            ..._resizeSettingsLogContext(plan),
            ..._dimensionDeltaContext(
              sourceWidth: sourceProbe.displayWidth ?? sourceProbe.width,
              sourceHeight: sourceProbe.displayHeight ?? sourceProbe.height,
              outputWidth: cached.width,
              outputHeight: cached.height,
            ),
          },
        );
        return cached;
      }
    }

    if (plan.shouldPassthrough) {
      _logManager.debug(
        'CompressionPipeline: passthrough',
        context: {
          'engine': plan.engineId,
          'sourceFormat': sourceProbe.format.name,
          'sourceSize': sourceProbe.fileSize,
          'sourceWidth': sourceProbe.displayWidth ?? sourceProbe.width,
          'sourceHeight': sourceProbe.displayHeight ?? sourceProbe.height,
          'resizeTargetWidth': plan.resizeTarget?.width,
          'resizeTargetHeight': plan.resizeTarget?.height,
          'fallbackReason': plan.fallbackReason?.name,
          ..._resizeSettingsLogContext(plan),
          ..._dimensionDeltaContext(
            sourceWidth: sourceProbe.displayWidth ?? sourceProbe.width,
            sourceHeight: sourceProbe.displayHeight ?? sourceProbe.height,
            outputWidth: sourceProbe.displayWidth ?? sourceProbe.width,
            outputHeight: sourceProbe.displayHeight ?? sourceProbe.height,
          ),
        },
      );
      final passthrough = await _buildFallbackResult(
        request: request,
        sourceProbe: sourceProbe,
        plan: plan,
        fromCache: false,
      );
      await _cacheStore.writeManifest(
        plan.cacheKey,
        CompressionCacheManifest(
          status: _statusForFallbackReason(plan.fallbackReason),
          engine: plan.engineId,
          libraryVersion: plan.engineVersion,
          mode: request.settings.mode,
          sourceFormat: sourceProbe.format,
          outputFormat: null,
          size: passthrough.size,
          width: passthrough.width,
          height: passthrough.height,
          hash: passthrough.hash,
          fallbackReason: plan.fallbackReason,
        ),
      );
      return passthrough;
    }

    final outputPath = await _cacheStore.resolveOutputPath(
      plan.cacheKey,
      plan.outputFormat!,
    );
    Future<void> Function()? cleanup;
    try {
      final converted = await _conversionService.prepare(
        plan: plan,
        engine: engine,
      );
      cleanup = converted.cleanup;
      final compressRequest = CompressionEngineRequest(
        sourcePath: converted.sourcePath,
        outputPath: outputPath,
        inputFormat: plan.requiresInputConversion
            ? plan.outputFormat!
            : sourceProbe.format,
        outputFormat: plan.outputFormat!,
        settings: request.settings,
        resizeTarget: plan.resizeTarget,
        maxOutputBytes: plan.maxOutputBytes,
      );
      await engine.compress(compressRequest);
      final outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        throw FileSystemException('Compression output missing', outputPath);
      }

      final size = await outputFile.length();
      if (request.settings.skipIfBigger && size >= sourceProbe.fileSize) {
        if (outputFile.existsSync()) {
          await outputFile.delete();
        }
        final fallbackPlan = plan.copyWith(
          fallbackReason: CompressionFallbackReason.outputBiggerThanInput,
        );
        final fallback = await _buildFallbackResult(
          request: request,
          sourceProbe: sourceProbe,
          plan: fallbackPlan,
          fromCache: false,
        );
        await _cacheStore.writeManifest(
          plan.cacheKey,
          CompressionCacheManifest(
            status: CompressionCacheStatus.fallback,
            engine: plan.engineId,
            libraryVersion: plan.engineVersion,
            mode: request.settings.mode,
            sourceFormat: sourceProbe.format,
            outputFormat: null,
            size: fallback.size,
            width: fallback.width,
            height: fallback.height,
            hash: fallback.hash,
            fallbackReason: CompressionFallbackReason.outputBiggerThanInput,
          ),
        );
        return fallback;
      }

      final hash = await _computeSha256(outputPath);
      final filename = _replaceFilenameExtension(
        request.filename,
        _cacheStore.extensionForFormat(plan.outputFormat!),
      );
      final result = CompressionPipelineResult(
        filePath: outputPath,
        filename: filename,
        mimeType: _mimeTypeFor(plan.outputFormat!),
        size: size,
        width:
            plan.resizeTarget?.width ??
            sourceProbe.displayWidth ??
            sourceProbe.width,
        height:
            plan.resizeTarget?.height ??
            sourceProbe.displayHeight ??
            sourceProbe.height,
        hash: hash,
        sourceSignature: sourceSignature,
        cacheKey: plan.cacheKey,
        sourceFormat: sourceProbe.format,
        effectiveOutputFormat: plan.outputFormat,
        engineId: plan.engineId,
        engineVersion: plan.engineVersion,
        fromCache: false,
        fallback: false,
        wasConverted: plan.wasConverted,
        wasResized: plan.wasResized,
        fallbackReason: null,
      );
      await _cacheStore.writeManifest(
        plan.cacheKey,
        CompressionCacheManifest(
          status: CompressionCacheStatus.ok,
          engine: plan.engineId,
          libraryVersion: plan.engineVersion,
          mode: request.settings.mode,
          sourceFormat: sourceProbe.format,
          outputFormat: plan.outputFormat,
          size: size,
          width: result.width,
          height: result.height,
          hash: hash,
          fallbackReason: null,
        ),
      );
      _logManager.info(
        'CompressionPipeline: success',
        context: {
          'engine': plan.engineId,
          'outputFormat': plan.outputFormat?.name,
          'sourceSize': sourceProbe.fileSize,
          'sourceWidth': sourceProbe.displayWidth ?? sourceProbe.width,
          'sourceHeight': sourceProbe.displayHeight ?? sourceProbe.height,
          'outputSize': size,
          'outputWidth': result.width,
          'outputHeight': result.height,
          'wasResized': plan.wasResized,
          'resizeTargetWidth': plan.resizeTarget?.width,
          'resizeTargetHeight': plan.resizeTarget?.height,
          ..._resizeSettingsLogContext(plan),
          ..._dimensionDeltaContext(
            sourceWidth: sourceProbe.displayWidth ?? sourceProbe.width,
            sourceHeight: sourceProbe.displayHeight ?? sourceProbe.height,
            outputWidth: result.width,
            outputHeight: result.height,
          ),
        },
      );
      return result;
    } catch (e, st) {
      _logManager.warn(
        'CompressionPipeline: fallback',
        error: e,
        stackTrace: st,
        context: {
          'engine': plan.engineId,
          'outputFormat': plan.outputFormat?.name,
          'sourceSize': sourceProbe.fileSize,
          'sourceWidth': sourceProbe.displayWidth ?? sourceProbe.width,
          'sourceHeight': sourceProbe.displayHeight ?? sourceProbe.height,
          'resizeTargetWidth': plan.resizeTarget?.width,
          'resizeTargetHeight': plan.resizeTarget?.height,
          ..._resizeSettingsLogContext(plan),
          ..._dimensionDeltaContext(
            sourceWidth: sourceProbe.displayWidth ?? sourceProbe.width,
            sourceHeight: sourceProbe.displayHeight ?? sourceProbe.height,
            outputWidth: plan.resizeTarget?.width,
            outputHeight: plan.resizeTarget?.height,
          ),
        },
      );
      final fallbackPlan = plan.copyWith(
        fallbackReason: plan.requiresInputConversion
            ? CompressionFallbackReason.conversionFailed
            : CompressionFallbackReason.compressionFailed,
      );
      final fallback = await _buildFallbackResult(
        request: request,
        sourceProbe: sourceProbe,
        plan: fallbackPlan,
        fromCache: false,
      );
      await _cacheStore.writeManifest(
        plan.cacheKey,
        CompressionCacheManifest(
          status: CompressionCacheStatus.fallback,
          engine: plan.engineId,
          libraryVersion: plan.engineVersion,
          mode: request.settings.mode,
          sourceFormat: sourceProbe.format,
          outputFormat: null,
          size: fallback.size,
          width: fallback.width,
          height: fallback.height,
          hash: fallback.hash,
          fallbackReason: fallbackPlan.fallbackReason,
        ),
      );
      return fallback;
    } finally {
      if (cleanup != null) {
        await cleanup();
      }
    }
  }

  Future<CompressionPipelineResult?> _resolveCachedResult({
    required CompressionPipelineRequest request,
    required CompressionSourceProbe sourceProbe,
    required CompressionPlan plan,
    required CompressionCacheHit cacheHit,
  }) async {
    final manifest = cacheHit.manifest;
    if (manifest.status == CompressionCacheStatus.ok &&
        cacheHit.outputPath.isNotEmpty &&
        File(cacheHit.outputPath).existsSync()) {
      final outputFile = File(cacheHit.outputPath);
      final size = manifest.size ?? await outputFile.length();
      return CompressionPipelineResult(
        filePath: outputFile.path,
        filename: _replaceFilenameExtension(
          request.filename,
          _cacheStore.extensionForFormat(plan.outputFormat!),
        ),
        mimeType: _mimeTypeFor(plan.outputFormat!),
        size: size,
        width: manifest.width,
        height: manifest.height,
        hash: manifest.hash ?? await _computeSha256(outputFile.path),
        sourceSignature: plan.sourceSignature,
        cacheKey: plan.cacheKey,
        sourceFormat: sourceProbe.format,
        effectiveOutputFormat: manifest.outputFormat,
        engineId: plan.engineId,
        engineVersion: plan.engineVersion,
        fromCache: true,
        fallback: false,
        wasConverted: plan.wasConverted,
        wasResized: plan.wasResized,
        fallbackReason: null,
      );
    }

    if (manifest.status != CompressionCacheStatus.ok) {
      return _buildFallbackResult(
        request: request,
        sourceProbe: sourceProbe,
        plan: plan.copyWith(fallbackReason: manifest.fallbackReason),
        fromCache: true,
      );
    }
    return null;
  }

  Future<CompressionPipelineResult> _buildFallbackResult({
    required CompressionPipelineRequest request,
    required CompressionSourceProbe sourceProbe,
    required CompressionPlan plan,
    required bool fromCache,
  }) async {
    return CompressionPipelineResult(
      filePath: request.path,
      filename: request.filename,
      mimeType: request.mimeType,
      size: sourceProbe.fileSize,
      width: sourceProbe.displayWidth ?? sourceProbe.width,
      height: sourceProbe.displayHeight ?? sourceProbe.height,
      hash: await _computeSha256(request.path),
      sourceSignature: plan.sourceSignature,
      cacheKey: plan.cacheKey,
      sourceFormat: sourceProbe.format,
      effectiveOutputFormat: null,
      engineId: plan.engineId,
      engineVersion: plan.engineVersion,
      fromCache: fromCache,
      fallback: true,
      wasConverted: false,
      wasResized: false,
      fallbackReason: plan.fallbackReason,
    );
  }

  CompressionCacheStatus _statusForFallbackReason(
    CompressionFallbackReason? reason,
  ) {
    return switch (reason) {
      CompressionFallbackReason.unsupportedInputFormat ||
      CompressionFallbackReason.unsupportedOutputFormat ||
      CompressionFallbackReason.animatedImage =>
        CompressionCacheStatus.unsupported,
      _ => CompressionCacheStatus.fallback,
    };
  }

  Map<String, Object?> _resizeSettingsLogContext(CompressionPlan plan) {
    final resize = plan.settings.resize;
    final sourceWidth = plan.sourceProbe.displayWidth ?? plan.sourceProbe.width;
    final sourceHeight =
        plan.sourceProbe.displayHeight ?? plan.sourceProbe.height;
    return {
      'resizeEnabled': resize.enabled,
      'resizeMode': resize.mode.name,
      'resizeSettingWidth': resize.width,
      'resizeSettingHeight': resize.height,
      'resizeSettingEdge': resize.edge,
      'resizeDoNotEnlarge': resize.doNotEnlarge,
      'resizeWillChangeDimensions':
          plan.resizeTarget != null &&
          !plan.resizeTarget!.sameAs(sourceWidth, sourceHeight),
    };
  }

  Map<String, Object?> _dimensionDeltaContext({
    required int? sourceWidth,
    required int? sourceHeight,
    required int? outputWidth,
    required int? outputHeight,
  }) {
    double? scale(int? source, int? target) {
      if (source == null || target == null || source <= 0) return null;
      return double.parse((target / source).toStringAsFixed(3));
    }

    return {
      'widthDelta': (sourceWidth != null && outputWidth != null)
          ? outputWidth - sourceWidth
          : null,
      'heightDelta': (sourceHeight != null && outputHeight != null)
          ? outputHeight - sourceHeight
          : null,
      'widthScale': scale(sourceWidth, outputWidth),
      'heightScale': scale(sourceHeight, outputHeight),
    };
  }

  String _replaceFilenameExtension(String filename, String extension) {
    final base = p.basenameWithoutExtension(filename).trim();
    final resolvedBase = base.isEmpty ? 'image' : base;
    return '$resolvedBase.$extension';
  }

  String _mimeTypeFor(CompressionImageFormat format) {
    return switch (format) {
      CompressionImageFormat.jpeg => 'image/jpeg',
      CompressionImageFormat.png => 'image/png',
      CompressionImageFormat.webp => 'image/webp',
      CompressionImageFormat.tiff => 'image/tiff',
      CompressionImageFormat.gif => 'image/gif',
      CompressionImageFormat.bmp => 'image/bmp',
      CompressionImageFormat.heic => 'image/heic',
      CompressionImageFormat.heif => 'image/heif',
      CompressionImageFormat.unknown => 'application/octet-stream',
    };
  }

  Future<String> _computeSourceSignature(String path, int size) async {
    final limit = math.min(size, 256 * 1024);
    final digest = await sha256.bind(File(path).openRead(0, limit)).first;
    return '${digest.toString()}:$size';
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
