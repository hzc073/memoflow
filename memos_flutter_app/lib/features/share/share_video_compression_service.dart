import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:native_video_compress/controller/native_video_compressor.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/debug_ephemeral_storage.dart';
import 'share_video_download_service.dart';

@immutable
class ShareVideoCompressionMetadata {
  const ShareVideoCompressionMetadata({
    required this.width,
    required this.height,
    required this.durationSeconds,
  });

  final int width;
  final int height;
  final double durationSeconds;
}

@immutable
class ShareVideoCompressionResult {
  const ShareVideoCompressionResult({
    required this.filePath,
    required this.fileSize,
    required this.wasCompressed,
  });

  final String filePath;
  final int fileSize;
  final bool wasCompressed;
}

abstract class ShareVideoCompressionClient {
  Future<String?> compress({
    required String inputPath,
    required int bitrate,
    int? width,
    int? height,
    required bool preserveResolution,
    ValueChanged<double>? onProgress,
  });
}

class NativeShareVideoCompressionClient implements ShareVideoCompressionClient {
  @override
  Future<String?> compress({
    required String inputPath,
    required int bitrate,
    int? width,
    int? height,
    required bool preserveResolution,
    ValueChanged<double>? onProgress,
  }) {
    return NativeVideoController.compressVideo(
      inputPath: inputPath,
      bitrate: bitrate,
      width: width,
      height: height,
      preserveResolution: preserveResolution,
      avoidLargerOutput: true,
      audioBitrate: 128000,
      onProgress: onProgress,
    );
  }
}

class ShareVideoCompressionService {
  ShareVideoCompressionService({
    ShareVideoCompressionClient? client,
    Future<Directory> Function()? resolveDirectory,
    Future<ShareVideoCompressionMetadata?> Function(File file)? metadataReader,
    bool Function()? isCompressionSupported,
  }) : _client = client ?? NativeShareVideoCompressionClient(),
       _resolveDirectory = resolveDirectory ?? _defaultResolveDirectory,
       _metadataReader = metadataReader ?? _readVideoMetadataDefault,
       _isCompressionSupported =
           isCompressionSupported ?? _defaultIsCompressionSupported;

  final ShareVideoCompressionClient _client;
  final Future<Directory> Function() _resolveDirectory;
  final Future<ShareVideoCompressionMetadata?> Function(File file)
  _metadataReader;
  final bool Function() _isCompressionSupported;

  Future<ShareVideoCompressionResult?> compressToFit({
    required String inputPath,
    int maxBytes = kShareVideoAttachmentLimitBytes,
    int targetBytes = kShareVideoCompressionTargetBytes,
    ValueChanged<double>? onProgress,
  }) async {
    final sourceFile = File(inputPath);
    if (!await sourceFile.exists()) return null;
    final sourceSize = await sourceFile.length();
    if (sourceSize <= maxBytes) {
      return ShareVideoCompressionResult(
        filePath: inputPath,
        fileSize: sourceSize,
        wasCompressed: false,
      );
    }
    if (!_isCompressionSupported()) {
      return null;
    }

    final metadata = await _metadataReader(sourceFile);
    if (metadata == null || metadata.durationSeconds <= 0) {
      return null;
    }

    final firstAttempt = await _compressRound(
      inputPath: inputPath,
      targetBytes: targetBytes,
      durationSeconds: metadata.durationSeconds,
      maxWidth: null,
      maxHeight: null,
      preserveResolution: true,
      onProgress: onProgress,
    );
    if (firstAttempt != null && firstAttempt.fileSize <= maxBytes) {
      return firstAttempt;
    }

    final longestSide = metadata.width >= metadata.height
        ? metadata.width
        : metadata.height;
    if (longestSide <= 1280) {
      return firstAttempt;
    }

    final resized = _resizeWithinBounds(metadata.width, metadata.height, 1280);
    return _compressRound(
      inputPath: inputPath,
      targetBytes: targetBytes,
      durationSeconds: metadata.durationSeconds,
      maxWidth: resized.$1,
      maxHeight: resized.$2,
      preserveResolution: false,
      onProgress: onProgress,
    );
  }

  Future<ShareVideoCompressionResult?> _compressRound({
    required String inputPath,
    required int targetBytes,
    required double durationSeconds,
    required int? maxWidth,
    required int? maxHeight,
    required bool preserveResolution,
    ValueChanged<double>? onProgress,
  }) async {
    final targetBitrate = _computeVideoBitrate(
      targetBytes: targetBytes,
      durationSeconds: durationSeconds,
    );
    final outputPath = await _client.compress(
      inputPath: inputPath,
      bitrate: targetBitrate,
      width: maxWidth,
      height: maxHeight,
      preserveResolution: preserveResolution,
      onProgress: onProgress,
    );
    if (outputPath == null) return null;
    final persistedPath = await _persistOutput(outputPath, inputPath);
    final file = File(persistedPath);
    if (!await file.exists()) return null;
    final size = await file.length();
    return ShareVideoCompressionResult(
      filePath: persistedPath,
      fileSize: size,
      wasCompressed: true,
    );
  }

  int _computeVideoBitrate({
    required int targetBytes,
    required double durationSeconds,
  }) {
    final totalBitrate = ((targetBytes * 8) / durationSeconds).floor();
    const audioBitrate = 128000;
    final available = totalBitrate - audioBitrate;
    return available.clamp(200000, 12000000);
  }

  Future<String> _persistOutput(String outputPath, String inputPath) async {
    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      return outputPath;
    }
    final directory = await _resolveDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final baseName = p.basenameWithoutExtension(inputPath);
    final targetPath = p.join(
      directory.path,
      '${baseName}_compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    return (await outputFile.copy(targetPath)).path;
  }

  static bool _defaultIsCompressionSupported() =>
      !kIsWeb && Platform.isAndroid;

  static Future<Directory> _defaultResolveDirectory() async {
    final root = await resolveAppSupportDirectory();
    return Directory(p.join(root.path, 'share_media_cache'));
  }

  static Future<ShareVideoCompressionMetadata?> _readVideoMetadataDefault(
    File file,
  ) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      final value = controller.value;
      return ShareVideoCompressionMetadata(
        width: value.size.width.round(),
        height: value.size.height.round(),
        durationSeconds: value.duration.inMilliseconds / 1000,
      );
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  (int, int) _resizeWithinBounds(int width, int height, int maxSide) {
    if (width <= maxSide && height <= maxSide) return (width, height);
    if (width >= height) {
      final ratio = maxSide / width;
      return (maxSide, (height * ratio).round());
    }
    final ratio = maxSide / height;
    return ((width * ratio).round(), maxSide);
  }
}


