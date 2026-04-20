import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:memos_flutter_app/application/attachments/compression/compression_cache_store.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_models.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_pipeline.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_plan_builder.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_source_probe.dart';
import 'package:memos_flutter_app/application/attachments/compression/engines/compression_engine.dart';
import 'package:memos_flutter_app/application/attachments/compression/engines/dart_fallback_engine.dart';
import 'package:memos_flutter_app/data/models/image_compression_settings.dart';

import '../../../test_support.dart';

class _UnavailableEngine implements CompressionEngine {
  const _UnavailableEngine(this._engineId);

  final String _engineId;

  @override
  String get engineId => _engineId;

  @override
  String get libraryVersion => 'test';

  @override
  bool get isAvailable => false;

  @override
  bool get requiresMatchingInputFormat => false;

  @override
  Future<CompressionEngineResult> compress(CompressionEngineRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> convert(CompressionConversionRequest request) {
    throw UnimplementedError();
  }

  @override
  bool supportsOutputFormat(CompressionImageFormat format) => false;
}

class _FailingEngine implements CompressionEngine {
  int compressCalls = 0;

  @override
  String get engineId => 'failing_engine';

  @override
  String get libraryVersion => 'test';

  @override
  bool get isAvailable => true;

  @override
  bool get requiresMatchingInputFormat => false;

  @override
  Future<CompressionEngineResult> compress(
    CompressionEngineRequest request,
  ) async {
    compressCalls += 1;
    throw StateError('boom');
  }

  @override
  Future<void> convert(CompressionConversionRequest request) async {
    throw StateError('convert should not be called');
  }

  @override
  bool supportsOutputFormat(CompressionImageFormat format) => true;
}

class _BiggerOutputEngine implements CompressionEngine {
  _BiggerOutputEngine(this.sourceSize);

  final int sourceSize;
  int compressCalls = 0;

  @override
  String get engineId => 'bigger_output_engine';

  @override
  String get libraryVersion => 'test';

  @override
  bool get isAvailable => true;

  @override
  bool get requiresMatchingInputFormat => false;

  @override
  Future<CompressionEngineResult> compress(
    CompressionEngineRequest request,
  ) async {
    compressCalls += 1;
    final output = File(request.outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(
      Uint8List.fromList(List<int>.filled(sourceSize + 64, 7)),
      flush: true,
    );
    return CompressionEngineResult(outputPath: output.path);
  }

  @override
  Future<void> convert(CompressionConversionRequest request) async {
    throw StateError('convert should not be called');
  }

  @override
  bool supportsOutputFormat(CompressionImageFormat format) => true;
}

Future<File> _writePng(
  TestSupport support, {
  required String name,
  required int width,
  required int height,
}) async {
  final dir = await support.createTempDir('compression');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        (x * 17) % 255,
        (y * 29) % 255,
        ((x + y) * 13) % 255,
        255,
      );
    }
  }
  await file.writeAsBytes(
    Uint8List.fromList(img.encodePng(image, level: 2)),
    flush: true,
  );
  return file;
}

CompressionPipeline _buildPipeline({
  required CompressionEngine primaryEngine,
  required CompressionEngine fallbackEngine,
}) {
  return CompressionPipeline(
    probeService: const CompressionSourceProbeService(),
    planBuilder: const CompressionPlanBuilder(),
    cacheStore: CompressionCacheStore(),
    primaryEngine: primaryEngine,
    fallbackEngine: fallbackEngine,
  );
}

void main() {
  group('CompressionPipeline', () {
    late TestSupport support;

    setUp(() async {
      support = await initializeTestSupport();
    });

    tearDown(() async {
      await support.dispose();
    });

    test(
      'uses fallback engine when primary is unavailable and caches result',
      () async {
        final file = await _writePng(
          support,
          name: 'sample.png',
          width: 240,
          height: 160,
        );
        final pipeline = _buildPipeline(
          primaryEngine: const _UnavailableEngine('ffi'),
          fallbackEngine: DartFallbackCompressionEngine(),
        );
        final settings = ImageCompressionSettings.defaults.copyWith(
          skipIfBigger: false,
          outputFormat: ImageCompressionOutputFormat.jpeg,
          resize: ImageCompressionSettings.defaults.resize.copyWith(
            enabled: true,
            mode: ImageCompressionResizeMode.longEdge,
            edge: 80,
          ),
        );

        final first = await pipeline.process(
          CompressionPipelineRequest(
            path: file.path,
            filename: 'sample.png',
            mimeType: 'image/png',
            settings: settings,
          ),
        );
        final second = await pipeline.process(
          CompressionPipelineRequest(
            path: file.path,
            filename: 'sample.png',
            mimeType: 'image/png',
            settings: settings,
          ),
        );

        expect(first.fallback, isFalse);
        expect(first.fromCache, isFalse);
        expect(first.engineId, 'dart_fallback');
        expect(first.effectiveOutputFormat, CompressionImageFormat.jpeg);
        expect(first.wasConverted, isTrue);
        expect(first.wasResized, isTrue);
        expect(File(first.filePath).existsSync(), isTrue);

        expect(second.fallback, isFalse);
        expect(second.fromCache, isTrue);
        expect(second.filePath, first.filePath);
        expect(second.engineId, 'dart_fallback');
        expect(second.effectiveOutputFormat, CompressionImageFormat.jpeg);
      },
    );

    test(
      'disabling resize keeps output dimensions unchanged for regular and screenshot sizes',
      () async {
        final cases = <({String name, int width, int height})>[
          (name: 'sample.png', width: 240, height: 160),
          (name: 'iphone_13_screenshot.png', width: 1170, height: 2532),
          (name: 'iphone_15_pro_max_screenshot.png', width: 1290, height: 2796),
          (name: 'android_fhd_screenshot.png', width: 1080, height: 2400),
          (name: 'android_qhd_screenshot.png', width: 1440, height: 3120),
          (name: 'ipad_screenshot.png', width: 1668, height: 2388),
        ];

        final pipeline = _buildPipeline(
          primaryEngine: const _UnavailableEngine('ffi'),
          fallbackEngine: DartFallbackCompressionEngine(),
        );
        final settings = ImageCompressionSettings.defaults.copyWith(
          skipIfBigger: false,
          outputFormat: ImageCompressionOutputFormat.jpeg,
          resize: ImageCompressionSettings.defaults.resize.copyWith(
            enabled: false,
            mode: ImageCompressionResizeMode.longEdge,
            edge: 80,
          ),
        );

        for (final testCase in cases) {
          final file = await _writePng(
            support,
            name: testCase.name,
            width: testCase.width,
            height: testCase.height,
          );

          final result = await pipeline.process(
            CompressionPipelineRequest(
              path: file.path,
              filename: testCase.name,
              mimeType: 'image/png',
              settings: settings,
            ),
          );

          final outputBytes = await File(result.filePath).readAsBytes();
          final decoded = img.decodeImage(outputBytes);

          expect(result.fallback, isFalse, reason: testCase.name);
          expect(result.fromCache, isFalse, reason: testCase.name);
          expect(result.engineId, 'dart_fallback', reason: testCase.name);
          expect(
            result.effectiveOutputFormat,
            CompressionImageFormat.jpeg,
            reason: testCase.name,
          );
          expect(result.wasConverted, isTrue, reason: testCase.name);
          expect(result.wasResized, isFalse, reason: testCase.name);
          expect(result.width, testCase.width, reason: testCase.name);
          expect(result.height, testCase.height, reason: testCase.name);
          expect(decoded, isNotNull, reason: testCase.name);
          expect(decoded!.width, testCase.width, reason: testCase.name);
          expect(decoded.height, testCase.height, reason: testCase.name);
        }
      },
    );

    test('caches fallback results when compression throws', () async {
      final file = await _writePng(
        support,
        name: 'sample.png',
        width: 120,
        height: 80,
      );
      final failingEngine = _FailingEngine();
      final pipeline = _buildPipeline(
        primaryEngine: failingEngine,
        fallbackEngine: DartFallbackCompressionEngine(),
      );
      final settings = ImageCompressionSettings.defaults.copyWith(
        skipIfBigger: false,
        outputFormat: ImageCompressionOutputFormat.jpeg,
      );

      final first = await pipeline.process(
        CompressionPipelineRequest(
          path: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          settings: settings,
        ),
      );
      final second = await pipeline.process(
        CompressionPipelineRequest(
          path: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          settings: settings,
        ),
      );

      expect(failingEngine.compressCalls, 1);
      expect(first.fallback, isTrue);
      expect(first.fromCache, isFalse);
      expect(first.filePath, file.path);
      expect(first.engineId, 'failing_engine');
      expect(first.fallbackReason, CompressionFallbackReason.compressionFailed);

      expect(second.fallback, isTrue);
      expect(second.fromCache, isTrue);
      expect(second.filePath, file.path);
      expect(second.engineId, 'failing_engine');
      expect(
        second.fallbackReason,
        CompressionFallbackReason.compressionFailed,
      );
    });

    test('skipIfBigger falls back to original file', () async {
      final file = await _writePng(
        support,
        name: 'sample.png',
        width: 64,
        height: 64,
      );
      final biggerOutputEngine = _BiggerOutputEngine(file.lengthSync());
      final pipeline = _buildPipeline(
        primaryEngine: biggerOutputEngine,
        fallbackEngine: DartFallbackCompressionEngine(),
      );
      final settings = ImageCompressionSettings.defaults.copyWith(
        outputFormat: ImageCompressionOutputFormat.sameAsInput,
      );

      final result = await pipeline.process(
        CompressionPipelineRequest(
          path: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          settings: settings,
        ),
      );

      expect(biggerOutputEngine.compressCalls, 1);
      expect(result.fallback, isTrue);
      expect(result.fromCache, isFalse);
      expect(result.filePath, file.path);
      expect(
        result.fallbackReason,
        CompressionFallbackReason.outputBiggerThanInput,
      );
      expect(result.effectiveOutputFormat, isNull);
    });
  });
}
