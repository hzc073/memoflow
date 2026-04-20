import '../../../../data/models/image_compression_settings.dart';
import '../compression_models.dart';

class CompressionEngineRequest {
  const CompressionEngineRequest({
    required this.sourcePath,
    required this.outputPath,
    required this.inputFormat,
    required this.outputFormat,
    required this.settings,
    this.resizeTarget,
    this.maxOutputBytes,
  });

  final String sourcePath;
  final String outputPath;
  final CompressionImageFormat inputFormat;
  final CompressionImageFormat outputFormat;
  final ImageCompressionSettings settings;
  final CompressionResizeTarget? resizeTarget;
  final int? maxOutputBytes;
}

class CompressionEngineResult {
  const CompressionEngineResult({
    required this.outputPath,
    this.width,
    this.height,
  });

  final String outputPath;
  final int? width;
  final int? height;
}

class CompressionConversionRequest {
  const CompressionConversionRequest({
    required this.sourcePath,
    required this.outputPath,
    required this.inputFormat,
    required this.outputFormat,
    required this.keepMetadata,
    this.resizeTarget,
  });

  final String sourcePath;
  final String outputPath;
  final CompressionImageFormat inputFormat;
  final CompressionImageFormat outputFormat;
  final bool keepMetadata;
  final CompressionResizeTarget? resizeTarget;
}

abstract class CompressionEngine {
  String get engineId;
  String get libraryVersion;
  bool get isAvailable;
  bool get requiresMatchingInputFormat;
  bool supportsOutputFormat(CompressionImageFormat format);

  Future<CompressionEngineResult> compress(CompressionEngineRequest request);

  Future<void> convert(CompressionConversionRequest request);
}
