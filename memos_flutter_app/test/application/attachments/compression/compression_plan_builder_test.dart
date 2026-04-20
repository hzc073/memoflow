import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/compression/compression_models.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_plan_builder.dart';
import 'package:memos_flutter_app/application/attachments/compression/engines/compression_engine.dart';
import 'package:memos_flutter_app/data/models/image_compression_settings.dart';

class _FakeEngine implements CompressionEngine {
  const _FakeEngine({required this.available, this.requiresMatching = false});

  final bool available;
  final bool requiresMatching;

  @override
  String get engineId => 'fake_engine';

  @override
  String get libraryVersion => 'test';

  @override
  bool get isAvailable => available;

  @override
  bool get requiresMatchingInputFormat => requiresMatching;

  @override
  Future<CompressionEngineResult> compress(CompressionEngineRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> convert(CompressionConversionRequest request) {
    throw UnimplementedError();
  }

  @override
  bool supportsOutputFormat(CompressionImageFormat format) =>
      format == CompressionImageFormat.jpeg ||
      format == CompressionImageFormat.png ||
      format == CompressionImageFormat.webp ||
      format == CompressionImageFormat.tiff;
}

CompressionSourceProbe _probe({
  required CompressionImageFormat format,
  required int fileSize,
  int? width = 400,
  int? height = 200,
  int? displayWidth,
  int? displayHeight,
  bool isAnimated = false,
  bool isImage = true,
}) {
  return CompressionSourceProbe(
    path: '/tmp/source',
    filename: 'source.png',
    mimeType: 'image/png',
    fileSize: fileSize,
    format: format,
    width: width,
    height: height,
    displayWidth: displayWidth ?? width,
    displayHeight: displayHeight ?? height,
    orientation: 1,
    hasAlpha: format == CompressionImageFormat.png,
    isAnimated: isAnimated,
    isImage: isImage,
  );
}

void main() {
  group('CompressionPlanBuilder', () {
    const builder = CompressionPlanBuilder();
    const engine = _FakeEngine(available: true, requiresMatching: true);

    test('sameAsInput keeps supported source format', () {
      final plan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.png,
          fileSize: 512 * 1024,
        ),
        settings: ImageCompressionSettings.defaults,
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(plan.outputFormat, CompressionImageFormat.png);
      expect(plan.fallbackReason, isNull);
      expect(plan.requiresInputConversion, isFalse);
    });

    test('sameAsInput falls back for unsupported source formats', () {
      final plan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.heic,
          fileSize: 256 * 1024,
        ),
        settings: ImageCompressionSettings.defaults,
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(plan.outputFormat, isNull);
      expect(
        plan.fallbackReason,
        CompressionFallbackReason.unsupportedInputFormat,
      );
    });

    test('fixedWidth computes proportional height', () {
      final settings = ImageCompressionSettings.defaults.copyWith(
        resize: ImageCompressionSettings.defaults.resize.copyWith(
          enabled: true,
          mode: ImageCompressionResizeMode.fixedWidth,
          width: 100,
        ),
      );
      final plan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.jpeg,
          fileSize: 128 * 1024,
          width: 400,
          height: 200,
        ),
        settings: settings,
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(plan.resizeTarget, isNotNull);
      expect(plan.resizeTarget!.width, 100);
      expect(plan.resizeTarget!.height, 50);
      expect(plan.wasResized, isTrue);
    });

    test('doNotEnlarge keeps original dimensions when target is larger', () {
      final settings = ImageCompressionSettings.defaults.copyWith(
        resize: ImageCompressionSettings.defaults.resize.copyWith(
          enabled: true,
          mode: ImageCompressionResizeMode.longEdge,
          edge: 800,
          doNotEnlarge: true,
        ),
      );
      final plan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.jpeg,
          fileSize: 128 * 1024,
          width: 400,
          height: 200,
        ),
        settings: settings,
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(plan.resizeTarget, isNotNull);
      expect(plan.resizeTarget!.width, 400);
      expect(plan.resizeTarget!.height, 200);
      expect(plan.wasResized, isFalse);
    });

    test('size mode converts percentage and kb using source size rules', () {
      final percentagePlan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.jpeg,
          fileSize: 200 * 1024,
        ),
        settings: ImageCompressionSettings.defaults.copyWith(
          mode: ImageCompressionMode.size,
          sizeTarget: const ImageCompressionSizeTarget(
            value: 25,
            unit: ImageCompressionMaxOutputUnit.percentage,
          ),
        ),
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );
      final kbPlan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.jpeg,
          fileSize: 200 * 1024,
        ),
        settings: ImageCompressionSettings.defaults.copyWith(
          mode: ImageCompressionMode.size,
          sizeTarget: const ImageCompressionSizeTarget(
            value: 80,
            unit: ImageCompressionMaxOutputUnit.kb,
          ),
        ),
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(percentagePlan.maxOutputBytes, 50 * 1024);
      expect(kbPlan.maxOutputBytes, 80 * 1024);
    });

    test('file larger than 500MB falls back before compression', () {
      final plan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.jpeg,
          fileSize: 501 * 1024 * 1024,
        ),
        settings: ImageCompressionSettings.defaults,
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(plan.outputFormat, CompressionImageFormat.jpeg);
      expect(plan.resizeTarget, isNull);
      expect(plan.fallbackReason, CompressionFallbackReason.fileTooLarge);
    });

    test('animated images are marked unsupported', () {
      final plan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.gif,
          fileSize: 64 * 1024,
          isAnimated: true,
        ),
        settings: ImageCompressionSettings.defaults.copyWith(
          outputFormat: ImageCompressionOutputFormat.jpeg,
        ),
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(plan.outputFormat, CompressionImageFormat.jpeg);
      expect(plan.resizeTarget, isNull);
      expect(plan.fallbackReason, CompressionFallbackReason.animatedImage);
    });

    test('display dimensions honor EXIF rotation when resizing', () {
      final settings = ImageCompressionSettings.defaults.copyWith(
        resize: ImageCompressionSettings.defaults.resize.copyWith(
          enabled: true,
          mode: ImageCompressionResizeMode.fixedHeight,
          height: 150,
        ),
      );
      final plan = builder.build(
        sourceProbe: _probe(
          format: CompressionImageFormat.jpeg,
          fileSize: 256 * 1024,
          width: 300,
          height: 500,
          displayWidth: 500,
          displayHeight: 300,
        ),
        settings: settings,
        engine: engine,
        sourceSignature: 'sig',
        cacheKey: 'cache',
      );

      expect(plan.resizeTarget, isNotNull);
      expect(plan.resizeTarget!.height, 150);
      expect(plan.resizeTarget!.width, 250);
    });
  });
}
