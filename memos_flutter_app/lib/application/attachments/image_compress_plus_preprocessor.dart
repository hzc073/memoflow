import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_compress_plus_platform_interface/image_compress_plus_platform_interface.dart';

import '../../data/models/image_compression_settings.dart';
import 'image_preprocessor.dart';

class ImageCompressPlusPreprocessor implements ImagePreprocessor {
  ImageCompressPlusPreprocessor();

  static bool _pluginAvailable = true;

  @override
  String get engine => 'image_compress_plus';

  @override
  bool get supportsWebp => true;

  @override
  bool get isAvailable {
    if (!_pluginAvailable) return false;
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  @override
  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request) async {
    final target = File(request.targetPath);
    final minWidth = request.targetWidth ?? request.maxSide;
    final minHeight = request.targetHeight ?? request.maxSide;
    if (!target.parent.existsSync()) {
      target.parent.createSync(recursive: true);
    }

    try {
      final source = File(request.sourcePath);
      final inputBytes = await source.readAsBytes();
      final outputBytes = await ImageCompressPlusPlatform.instance
          .compressWithList(
        Uint8List.fromList(inputBytes),
        quality: request.quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: _resolveFormat(request.format),
      );
      if (outputBytes.isEmpty) {
        throw StateError('image_compress_plus returned empty bytes');
      }
      await target.writeAsBytes(outputBytes, flush: true);
      return ImagePreprocessResult(outputPath: target.path);
    } on MissingPluginException {
      _pluginAvailable = false;
      rethrow;
    }
  }

  CompressFormat _resolveFormat(ImageCompressionFormat format) {
    return switch (format) {
      ImageCompressionFormat.jpeg => CompressFormat.jpeg,
      ImageCompressionFormat.webp => CompressFormat.webp,
      ImageCompressionFormat.auto => CompressFormat.jpeg,
    };
  }
}
