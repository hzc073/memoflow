import '../../data/models/image_compression_settings.dart';

class ImagePreprocessRequest {
  const ImagePreprocessRequest({
    required this.sourcePath,
    required this.targetPath,
    required this.maxSide,
    required this.quality,
    required this.format,
    this.targetWidth,
    this.targetHeight,
  });

  final String sourcePath;
  final String targetPath;
  final int maxSide;
  final int quality;
  final ImageCompressionFormat format;
  final int? targetWidth;
  final int? targetHeight;
}

class ImagePreprocessResult {
  const ImagePreprocessResult({
    required this.outputPath,
    this.width,
    this.height,
  });

  final String outputPath;
  final int? width;
  final int? height;
}

abstract class ImagePreprocessor {
  String get engine;
  bool get supportsWebp;
  bool get isAvailable;

  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request);
}
