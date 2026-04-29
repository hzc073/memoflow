import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:memos_flutter_app/application/attachments/compression/compression_cache_store.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_executor.dart';
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

class _SlowValidOutputEngine implements CompressionEngine {
  _SlowValidOutputEngine(this.release);

  final Completer<void> release;
  int compressCalls = 0;

  @override
  String get engineId => 'slow_valid_engine';

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
    await release.future;
    final output = File(request.outputPath);
    await output.parent.create(recursive: true);
    final width = request.resizeTarget?.displayWidth ?? 64;
    final height = request.resizeTarget?.displayHeight ?? 32;
    final image = img.Image(width: width, height: height);
    await output.writeAsBytes(
      Uint8List.fromList(img.encodePng(image)),
      flush: true,
    );
    return CompressionEngineResult(
      outputPath: output.path,
      width: width,
      height: height,
    );
  }

  @override
  Future<void> convert(CompressionConversionRequest request) async {
    throw StateError('convert should not be called');
  }

  @override
  bool supportsOutputFormat(CompressionImageFormat format) => true;
}

class _BadAspectOutputEngine implements CompressionEngine {
  int compressCalls = 0;

  @override
  String get engineId => 'bad_aspect_engine';

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
    final image = img.Image(width: 100, height: 100);
    await output.writeAsBytes(
      Uint8List.fromList(img.encodePng(image)),
      flush: true,
    );
    return CompressionEngineResult(
      outputPath: output.path,
      width: 100,
      height: 100,
    );
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

    test('safe long-edge policy keeps long screenshots readable', () async {
      final file = await _writePng(
        support,
        name: 'long_screenshot.png',
        width: 720,
        height: 2400,
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
          edge: 1200,
        ),
      );

      final result = await pipeline.process(
        CompressionPipelineRequest(
          path: file.path,
          filename: 'long_screenshot.png',
          mimeType: 'image/png',
          settings: settings,
        ),
      );

      final decoded = img.decodeImage(
        await File(result.filePath).readAsBytes(),
      );
      expect(result.fallback, isFalse);
      expect(result.wasResized, isFalse);
      expect(result.width, 720);
      expect(result.height, 2400);
      expect(decoded, isNotNull);
      expect(decoded!.width, 720);
      expect(decoded.height, 2400);
    });

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

    test('coalesces equivalent in-flight compression requests', () async {
      final file = await _writePng(
        support,
        name: 'sample.png',
        width: 64,
        height: 32,
      );
      final release = Completer<void>();
      final slowEngine = _SlowValidOutputEngine(release);
      final pipeline = _buildPipeline(
        primaryEngine: slowEngine,
        fallbackEngine: DartFallbackCompressionEngine(),
      );
      final settings = ImageCompressionSettings.defaults.copyWith(
        skipIfBigger: false,
        outputFormat: ImageCompressionOutputFormat.sameAsInput,
      );
      final request = CompressionPipelineRequest(
        path: file.path,
        filename: 'sample.png',
        mimeType: 'image/png',
        settings: settings,
      );

      final first = pipeline.process(request);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final second = pipeline.process(request);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(slowEngine.compressCalls, 1);
      release.complete();

      final firstResult = await first;
      final secondResult = await second;

      expect(slowEngine.compressCalls, 1);
      expect(secondResult.filePath, firstResult.filePath);
      expect(firstResult.fromCache, isFalse);
      expect(secondResult.fromCache, isFalse);
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

    test('unsafe output aspect ratio falls back to original file', () async {
      final file = await _writePng(
        support,
        name: 'sample.png',
        width: 200,
        height: 100,
      );
      final badAspectEngine = _BadAspectOutputEngine();
      final pipeline = _buildPipeline(
        primaryEngine: badAspectEngine,
        fallbackEngine: DartFallbackCompressionEngine(),
      );
      final settings = ImageCompressionSettings.defaults.copyWith(
        skipIfBigger: false,
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

      expect(badAspectEngine.compressCalls, 1);
      expect(result.fallback, isTrue);
      expect(result.filePath, file.path);
      expect(
        result.fallbackReason,
        CompressionFallbackReason.aspectRatioMismatch,
      );
    });
  });

  group('BoundedCompressionExecutor', () {
    test('limits concurrent jobs', () async {
      final executor = BoundedCompressionExecutor(maxConcurrentJobs: 2);
      var running = 0;
      var maxRunning = 0;

      await Future.wait(
        List<Future<int>>.generate(5, (index) {
          return executor.run<int>(
            work: () async {
              running += 1;
              if (running > maxRunning) {
                maxRunning = running;
              }
              await Future<void>.delayed(const Duration(milliseconds: 20));
              running -= 1;
              return index;
            },
          );
        }),
      );

      expect(maxRunning, 2);
    });

    test('coalesces in-flight jobs by key', () async {
      final executor = BoundedCompressionExecutor(maxConcurrentJobs: 2);
      final completer = Completer<int>();
      var calls = 0;

      final first = executor.run<int>(
        key: 'same-job',
        work: () async {
          calls += 1;
          return completer.future;
        },
      );
      final second = executor.run<int>(
        key: 'same-job',
        work: () async {
          calls += 1;
          return 2;
        },
      );

      completer.complete(1);

      expect(await first, 1);
      expect(await second, 1);
      expect(calls, 1);
    });
  });
}
