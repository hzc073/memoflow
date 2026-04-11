import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';
import '../../core/hash.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/image_compression_settings.dart';
import 'dart_image_preprocessor.dart';
import 'flutter_image_preprocessor.dart';
import 'image_compress_plus_preprocessor.dart';
import 'image_preprocessor.dart';

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
    this.outputFormat,
    this.engine,
    this.fromCache = false,
    this.fallback = false,
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
  final ImageCompressionFormat? outputFormat;
  final String? engine;
  final bool fromCache;
  final bool fallback;
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
    ImagePreprocessor? windowsPreprocessor,
    ImagePreprocessor? flutterPreprocessor,
    ImagePreprocessor? dartPreprocessor,
    LogManager? logManager,
  }) : _loadSettings = loadSettings,
       _windowsPreprocessor =
           windowsPreprocessor ?? ImageCompressPlusPreprocessor(),
       _flutterPreprocessor = flutterPreprocessor ?? FlutterImagePreprocessor(),
       _dartPreprocessor = dartPreprocessor ?? DartImagePreprocessor(),
       _logManager = logManager ?? LogManager.instance;

  final ImageCompressionSettingsLoader _loadSettings;
  final ImagePreprocessor _windowsPreprocessor;
  final ImagePreprocessor _flutterPreprocessor;
  final ImagePreprocessor _dartPreprocessor;
  final LogManager _logManager;
  final Map<String, Future<AttachmentPreprocessResult>> _pending =
      <String, Future<AttachmentPreprocessResult>>{};
  Directory? _cacheDir;

  @override
  Future<AttachmentPreprocessResult> preprocess(
    AttachmentPreprocessRequest request,
  ) async {
    final settings = await _loadSettings();
    final normalizedPath = _normalizePath(request.filePath);
    final filename = request.filename.trim();
    final mimeType = request.mimeType.trim().isEmpty
        ? 'application/octet-stream'
        : request.mimeType.trim();
    final normalizedRequest = AttachmentPreprocessRequest(
      filePath: normalizedPath,
      filename: filename,
      mimeType: mimeType,
      skipCompression: request.skipCompression,
    );
    if (normalizedPath.isEmpty) {
      throw const FormatException('file_path missing');
    }
    final file = File(normalizedPath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', normalizedPath);
    }

    final size = await file.length();
    final isImage = _isImageMimeType(mimeType);
    if (!isImage || request.skipCompression || !settings.enabled) {
      final hash = isImage ? await _computeSha256(normalizedPath) : null;
      final dims = isImage ? await _readImageDimensions(normalizedPath) : null;
      return AttachmentPreprocessResult(
        filePath: normalizedPath,
        filename: filename,
        mimeType: mimeType,
        size: size,
        width: dims?.width,
        height: dims?.height,
        hash: hash,
        fromCache: false,
        fallback: false,
      );
    }

    final engine = _selectEngine();
    try {
      return await _processWithEngine(
        normalizedRequest,
        normalizedPath,
        size,
        settings,
        engine,
      );
    } on MissingPluginException {
      if (engine != _dartPreprocessor && _dartPreprocessor.isAvailable) {
        _logManager.warn(
          'AttachmentPreprocess: native_unavailable_fallback_dart',
          context: {'engine': engine.engine},
        );
        return _processWithEngine(
          normalizedRequest,
          normalizedPath,
          size,
          settings,
          _dartPreprocessor,
        );
      }
      rethrow;
    }
  }

  ImagePreprocessor _selectEngine() {
    if (_windowsPreprocessor.isAvailable) {
      return _windowsPreprocessor;
    }
    if (_flutterPreprocessor.isAvailable) {
      return _flutterPreprocessor;
    }
    return _dartPreprocessor;
  }

  Future<AttachmentPreprocessResult> _processWithEngine(
    AttachmentPreprocessRequest request,
    String normalizedPath,
    int originalSize,
    ImageCompressionSettings settings,
    ImagePreprocessor engine,
  ) async {
    final outputFormat = await _resolveOutputFormat(request, settings, engine);
    final sourceSig = await _computeSourceSig(normalizedPath, originalSize);
    final compressKey = _buildCompressKey(
      sourceSig: sourceSig,
      settings: settings,
      format: outputFormat,
      engine: engine.engine,
    );

    final pending = _pending[compressKey];
    if (pending != null) {
      return pending;
    }

    final task = _processInternal(
      request: request,
      normalizedPath: normalizedPath,
      originalSize: originalSize,
      settings: settings,
      engine: engine,
      outputFormat: outputFormat,
      sourceSig: sourceSig,
      compressKey: compressKey,
    );
    _pending[compressKey] = task;
    return task.whenComplete(() => _pending.remove(compressKey));
  }

  Future<AttachmentPreprocessResult> _processInternal({
    required AttachmentPreprocessRequest request,
    required String normalizedPath,
    required int originalSize,
    required ImageCompressionSettings settings,
    required ImagePreprocessor engine,
    required ImageCompressionFormat outputFormat,
    required String sourceSig,
    required String compressKey,
  }) async {
    final cacheDir = await _resolveCacheDir();
    final outputExt = _formatExtension(outputFormat);
    final outputPath = p.join(cacheDir.path, '$compressKey.$outputExt');
    final outputFilename = _replaceExtension(
      request.filename.trim(),
      outputExt,
    );
    final outputMimeType = _formatMimeType(outputFormat);

    final cached = await _loadCacheEntry(compressKey, cacheDir);
    if (cached != null) {
      if (cached.status == _CacheStatus.ok && File(outputPath).existsSync()) {
        _logManager.info(
          'AttachmentPreprocess: cache_hit',
          context: {'engine': engine.engine, 'format': outputFormat.name},
        );
        final size = cached.size ?? await File(outputPath).length();
        final hash = cached.hash ?? await _computeSha256(outputPath);
        final dims = cached.hasDimensions
            ? _ImageDimensions(cached.width!, cached.height!)
            : await _readImageDimensions(outputPath);
        return AttachmentPreprocessResult(
          filePath: outputPath,
          filename: outputFilename,
          mimeType: outputMimeType,
          size: size,
          width: dims?.width,
          height: dims?.height,
          hash: hash,
          sourceSig: sourceSig,
          compressKey: compressKey,
          outputFormat: outputFormat,
          engine: engine.engine,
          fromCache: true,
        );
      }
      if (cached.status == _CacheStatus.fallback ||
          cached.status == _CacheStatus.error) {
        _logManager.info(
          'AttachmentPreprocess: cache_fallback_hit',
          context: {
            'engine': engine.engine,
            'format': outputFormat.name,
            'reason': cached.error,
          },
        );
        final size = cached.size ?? originalSize;
        final hash = cached.hash ?? await _computeSha256(normalizedPath);
        final dims = cached.hasDimensions
            ? _ImageDimensions(cached.width!, cached.height!)
            : await _readImageDimensions(normalizedPath);
        return AttachmentPreprocessResult(
          filePath: normalizedPath,
          filename: request.filename.trim(),
          mimeType: request.mimeType.trim(),
          size: size,
          width: dims?.width,
          height: dims?.height,
          hash: hash,
          sourceSig: sourceSig,
          compressKey: compressKey,
          outputFormat: null,
          engine: engine.engine,
          fromCache: true,
          fallback: true,
        );
      }
    }

    _logManager.debug(
      'AttachmentPreprocess: cache_miss',
      context: {'engine': engine.engine, 'format': outputFormat.name},
    );

    try {
      final resizeTarget = await _resolveCompressionTarget(
        normalizedPath,
        settings.maxSide,
      );
      final result = await engine.compress(
        ImagePreprocessRequest(
          sourcePath: normalizedPath,
          targetPath: outputPath,
          maxSide: settings.maxSide,
          quality: settings.quality,
          format: outputFormat,
          targetWidth: resizeTarget?.width,
          targetHeight: resizeTarget?.height,
        ),
      );
      final outFile = File(result.outputPath);
      if (!outFile.existsSync()) {
        throw FileSystemException('Compression output missing', outputPath);
      }
      final size = await outFile.length();
      final hash = await _computeSha256(outFile.path);
      final dims = result.width != null && result.height != null
          ? _ImageDimensions(result.width!, result.height!)
          : await _readImageDimensions(outFile.path);
      await _storeCacheEntry(
        compressKey,
        cacheDir,
        _CacheEntry(
          status: _CacheStatus.ok,
          width: dims?.width,
          height: dims?.height,
          size: size,
          hash: hash,
          engine: engine.engine,
          format: outputFormat.name,
        ),
      );
      _logManager.info(
        'AttachmentPreprocess: success',
        context: {
          'engine': engine.engine,
          'format': outputFormat.name,
          'sourceSize': originalSize,
          'outputSize': size,
          'ratio': originalSize > 0
              ? (size / originalSize).toStringAsFixed(3)
              : '0',
        },
      );
      return AttachmentPreprocessResult(
        filePath: outFile.path,
        filename: outputFilename,
        mimeType: outputMimeType,
        size: size,
        width: dims?.width,
        height: dims?.height,
        hash: hash,
        sourceSig: sourceSig,
        compressKey: compressKey,
        outputFormat: outputFormat,
        engine: engine.engine,
        fromCache: false,
      );
    } on MissingPluginException {
      rethrow;
    } catch (e, st) {
      _logManager.warn(
        'AttachmentPreprocess: fallback',
        error: e,
        stackTrace: st,
        context: {'engine': engine.engine, 'format': outputFormat.name},
      );
      final hash = await _computeSha256(normalizedPath);
      final dims = await _readImageDimensions(normalizedPath);
      await _storeCacheEntry(
        compressKey,
        cacheDir,
        _CacheEntry(
          status: _CacheStatus.fallback,
          width: dims?.width,
          height: dims?.height,
          size: originalSize,
          hash: hash,
          engine: engine.engine,
          format: outputFormat.name,
          error: e.toString(),
        ),
      );
      return AttachmentPreprocessResult(
        filePath: normalizedPath,
        filename: request.filename.trim(),
        mimeType: request.mimeType.trim(),
        size: originalSize,
        width: dims?.width,
        height: dims?.height,
        hash: hash,
        sourceSig: sourceSig,
        compressKey: compressKey,
        outputFormat: null,
        engine: engine.engine,
        fromCache: false,
        fallback: true,
      );
    }
  }

  Future<ImageCompressionFormat> _resolveOutputFormat(
    AttachmentPreprocessRequest request,
    ImageCompressionSettings settings,
    ImagePreprocessor engine,
  ) async {
    var format = settings.format;
    if (format == ImageCompressionFormat.webp && !engine.supportsWebp) {
      _logManager.warn(
        'AttachmentPreprocess: webp_unsupported_fallback_jpeg',
        context: {'engine': engine.engine},
      );
      format = ImageCompressionFormat.jpeg;
    }
    if (format == ImageCompressionFormat.auto) {
      if (!engine.supportsWebp) return ImageCompressionFormat.jpeg;
      if (_isPngOrWebp(request.mimeType, request.filename)) {
        _logManager.debug(
          'AttachmentPreprocess: auto_prefers_webp_for_sharp_content',
          context: {'mimeType': request.mimeType},
        );
        return ImageCompressionFormat.webp;
      }
      return ImageCompressionFormat.jpeg;
    }
    return format;
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

  bool _isImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
  }

  bool _isPngOrWebp(String mimeType, String filename) {
    final lowerMime = mimeType.trim().toLowerCase();
    if (lowerMime == 'image/png' || lowerMime == 'image/webp') return true;
    final ext = p.extension(filename).toLowerCase();
    return ext == '.png' || ext == '.webp';
  }

  String _formatExtension(ImageCompressionFormat format) {
    return format == ImageCompressionFormat.webp ? 'webp' : 'jpg';
  }

  String _formatMimeType(ImageCompressionFormat format) {
    return format == ImageCompressionFormat.webp ? 'image/webp' : 'image/jpeg';
  }

  String _replaceExtension(String filename, String extension) {
    final base = p.basenameWithoutExtension(filename);
    final safeBase = base.trim().isEmpty ? 'image' : base.trim();
    return '$safeBase.$extension';
  }

  Future<String> _computeSourceSig(String path, int size) async {
    final file = File(path);
    final limit = min(size, 256 * 1024);
    final bytes = await file
        .openRead(0, limit)
        .fold<BytesBuilder>(
          BytesBuilder(),
          (builder, chunk) => builder..add(chunk),
        );
    final digest = sha256.convert(bytes.takeBytes()).toString();
    return '$digest:$size';
  }

  Future<String?> _computeSha256(String path) async {
    try {
      final digest = await sha256.bind(File(path).openRead()).first;
      return digest.toString();
    } catch (_) {
      return null;
    }
  }

  String _buildCompressKey({
    required String sourceSig,
    required ImageCompressionSettings settings,
    required ImageCompressionFormat format,
    required String engine,
  }) {
    final raw =
        'v2|$sourceSig|${settings.maxSide}|${settings.quality}|${format.name}|$engine';
    return fnv1a64Hex(raw);
  }

  Future<Directory> _resolveCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final root = await resolveAppSupportDirectory();
    final dir = Directory(p.join(root.path, 'image_preprocess_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<_CacheEntry?> _loadCacheEntry(String key, Directory cacheDir) async {
    final file = File(p.join(cacheDir.path, '$key.json'));
    if (!file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _CacheEntry.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeCacheEntry(
    String key,
    Directory cacheDir,
    _CacheEntry entry,
  ) async {
    final file = File(p.join(cacheDir.path, '$key.json'));
    try {
      await file.writeAsString(jsonEncode(entry.toJson()), flush: true);
    } catch (_) {}
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.status,
    this.width,
    this.height,
    this.size,
    this.hash,
    this.engine,
    this.format,
    this.error,
  });

  final _CacheStatus status;
  final int? width;
  final int? height;
  final int? size;
  final String? hash;
  final String? engine;
  final String? format;
  final String? error;

  bool get hasDimensions =>
      (width != null && width! > 0) && (height != null && height! > 0);

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'status': status.name,
    'width': width,
    'height': height,
    'size': size,
    'hash': hash,
    'engine': engine,
    'format': format,
    'error': error,
  };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    int? readInt(String key) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
    }

    String? readString(String key) {
      final raw = json[key];
      if (raw is String) {
        final trimmed = raw.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    _CacheStatus readStatus() {
      final raw = readString('status');
      if (raw == null) return _CacheStatus.error;
      return _CacheStatus.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => _CacheStatus.error,
      );
    }

    return _CacheEntry(
      status: readStatus(),
      width: readInt('width'),
      height: readInt('height'),
      size: readInt('size'),
      hash: readString('hash'),
      engine: readString('engine'),
      format: readString('format'),
      error: readString('error'),
    );
  }
}

enum _CacheStatus { ok, fallback, error }

class _ImageDimensions {
  const _ImageDimensions(this.width, this.height);

  final int width;
  final int height;
}

Future<_ImageDimensions?> _readImageDimensions(String path) async {
  return _runIsolate(_decodeImageDimensions, path);
}

Future<_ImageDimensions?> _resolveCompressionTarget(
  String path,
  int maxSide,
) async {
  return _runIsolate(
    _decodeCompressionTarget,
    _CompressionTargetJob(path: path, maxSide: maxSide),
  );
}

_ImageDimensions? _decodeImageDimensions(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return _ImageDimensions(decoded.width, decoded.height);
  } catch (_) {
    return null;
  }
}

class _CompressionTargetJob {
  const _CompressionTargetJob({required this.path, required this.maxSide});

  final String path;
  final int maxSide;
}

_ImageDimensions? _decodeCompressionTarget(_CompressionTargetJob job) {
  try {
    final bytes = File(job.path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final orientation = decoded.exif.imageIfd.orientation;
    final swapsAxes = switch (orientation) {
      5 || 6 || 7 || 8 => true,
      _ => false,
    };
    final sourceWidth = swapsAxes ? decoded.height : decoded.width;
    final sourceHeight = swapsAxes ? decoded.width : decoded.height;
    final maxDim = max(sourceWidth, sourceHeight);
    if (maxDim <= job.maxSide || job.maxSide <= 0) {
      return _ImageDimensions(sourceWidth, sourceHeight);
    }
    final scale = job.maxSide / maxDim;
    return _ImageDimensions(
      (sourceWidth * scale).round().clamp(1, job.maxSide),
      (sourceHeight * scale).round().clamp(1, job.maxSide),
    );
  } catch (_) {
    return null;
  }
}

Future<T?> _runIsolate<T, P>(T? Function(P) fn, P param) async {
  if (kIsWeb) {
    return fn(param);
  }
  try {
    return compute(fn, param);
  } catch (_) {
    return fn(param);
  }
}
