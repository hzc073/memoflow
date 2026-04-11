import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../data/models/image_compression_settings.dart';
import 'image_preprocessor.dart';

class FlutterImagePreprocessor implements ImagePreprocessor {
  FlutterImagePreprocessor();

  static bool _pluginAvailable = true;

  @override
  String get engine => 'flutter';

  @override
  bool get supportsWebp => true;

  @override
  bool get isAvailable {
    if (!_pluginAvailable) return false;
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request) async {
    final format = _resolveFormat(request.format);
    final target = File(request.targetPath);
    final minWidth = request.targetWidth ?? request.maxSide;
    final minHeight = request.targetHeight ?? request.maxSide;
    if (!target.parent.existsSync()) {
      target.parent.createSync(recursive: true);
    }

    try {
      final file = await FlutterImageCompress.compressAndGetFile(
        request.sourcePath,
        request.targetPath,
        quality: request.quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: format,
      );
      if (file == null) {
        throw StateError('flutter_image_compress returned null');
      }
      return ImagePreprocessResult(outputPath: file.path);
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
