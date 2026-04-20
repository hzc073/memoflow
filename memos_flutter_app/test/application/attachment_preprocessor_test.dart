import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/attachment_preprocessor.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_cache_store.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_models.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_pipeline.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_plan_builder.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_source_probe.dart';
import 'package:memos_flutter_app/application/attachments/compression/engines/compression_engine.dart';
import 'package:memos_flutter_app/data/models/image_compression_settings.dart';

import '../test_support.dart';

class _FakeProbeService extends CompressionSourceProbeService {
  const _FakeProbeService(this._probe);

  final CompressionSourceProbe _probe;

  @override
  Future<CompressionSourceProbe> probe({
    required String path,
    required String filename,
    required String mimeType,
  }) async {
    return _probe;
  }
}

class _NoopEngine implements CompressionEngine {
  const _NoopEngine(this._engineId);

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

class _RecordingPipeline extends CompressionPipeline {
  _RecordingPipeline(this._result)
    : super(
        probeService: const CompressionSourceProbeService(),
        planBuilder: const CompressionPlanBuilder(),
        cacheStore: CompressionCacheStore(),
        primaryEngine: const _NoopEngine('primary'),
        fallbackEngine: const _NoopEngine('fallback'),
      );

  final CompressionPipelineResult _result;
  int calls = 0;
  CompressionPipelineRequest? lastRequest;

  @override
  Future<CompressionPipelineResult> process(
    CompressionPipelineRequest request,
  ) async {
    calls += 1;
    lastRequest = request;
    return _result;
  }
}

Future<File> _writeTempFile(
  TestSupport support, {
  required String name,
  required List<int> bytes,
}) async {
  final dir = await support.createTempDir('preprocessor');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

CompressionSourceProbe _probeForImage(
  File file, {
  required String filename,
  required String mimeType,
}) {
  return CompressionSourceProbe(
    path: file.path,
    filename: filename,
    mimeType: mimeType,
    fileSize: file.lengthSync(),
    format: CompressionImageFormat.png,
    width: 48,
    height: 32,
    displayWidth: 48,
    displayHeight: 32,
    orientation: 1,
    hasAlpha: false,
    isAnimated: false,
    isImage: true,
  );
}

void main() {
  group('DefaultAttachmentPreprocessor', () {
    late TestSupport support;

    setUp(() async {
      support = await initializeTestSupport();
    });

    tearDown(() async {
      await support.dispose();
    });

    test(
      'skipCompression bypasses pipeline and normalizes file uri path',
      () async {
        final file = await _writeTempFile(
          support,
          name: 'sample.png',
          bytes: Uint8List.fromList(List<int>.generate(32, (index) => index)),
        );
        final probe = _probeForImage(
          file,
          filename: 'sample.png',
          mimeType: 'image/png',
        );
        final pipeline = _RecordingPipeline(
          const CompressionPipelineResult(
            filePath: '/unused/out.jpg',
            filename: 'unused.jpg',
            mimeType: 'image/jpeg',
            size: 10,
            width: 10,
            height: 10,
            hash: 'unused',
            sourceSignature: 'unused-sig',
            cacheKey: 'unused-key',
            sourceFormat: CompressionImageFormat.png,
            effectiveOutputFormat: CompressionImageFormat.jpeg,
            engineId: 'unused',
            engineVersion: 'unused',
            fromCache: false,
            fallback: false,
            wasConverted: true,
            wasResized: true,
            fallbackReason: null,
          ),
        );
        final preprocessor = DefaultAttachmentPreprocessor(
          loadSettings: () async => ImageCompressionSettings.defaults,
          probeService: _FakeProbeService(probe),
          pipeline: pipeline,
        );

        final result = await preprocessor.preprocess(
          AttachmentPreprocessRequest(
            filePath: Uri.file(file.path).toString(),
            filename: 'sample.png',
            mimeType: 'image/png',
            skipCompression: true,
          ),
        );

        expect(result.filePath, file.path);
        expect(result.filename, 'sample.png');
        expect(result.mimeType, 'image/png');
        expect(result.size, file.lengthSync());
        expect(result.width, 48);
        expect(result.height, 32);
        expect(result.sourceFormat, CompressionImageFormat.png);
        expect(result.hash, isNotNull);
        expect(result.fallback, isFalse);
        expect(result.fromCache, isFalse);
        expect(result.engine, isNull);
        expect(pipeline.calls, 0);
      },
    );

    test(
      'non-image files passthrough without hashing or pipeline work',
      () async {
        final file = await _writeTempFile(
          support,
          name: 'sample.txt',
          bytes: 'hello world'.codeUnits,
        );
        final probe = CompressionSourceProbe(
          path: file.path,
          filename: 'sample.txt',
          mimeType: 'text/plain',
          fileSize: file.lengthSync(),
          format: CompressionImageFormat.unknown,
          width: null,
          height: null,
          displayWidth: null,
          displayHeight: null,
          orientation: 1,
          hasAlpha: false,
          isAnimated: false,
          isImage: false,
        );
        final pipeline = _RecordingPipeline(
          const CompressionPipelineResult(
            filePath: '/unused',
            filename: 'unused',
            mimeType: 'application/octet-stream',
            size: 0,
            width: null,
            height: null,
            hash: null,
            sourceSignature: 'unused',
            cacheKey: 'unused',
            sourceFormat: CompressionImageFormat.unknown,
            effectiveOutputFormat: null,
            engineId: 'unused',
            engineVersion: 'unused',
            fromCache: false,
            fallback: false,
            wasConverted: false,
            wasResized: false,
            fallbackReason: null,
          ),
        );
        final preprocessor = DefaultAttachmentPreprocessor(
          loadSettings: () async => ImageCompressionSettings.defaults,
          probeService: _FakeProbeService(probe),
          pipeline: pipeline,
        );

        final result = await preprocessor.preprocess(
          AttachmentPreprocessRequest(
            filePath: file.path,
            filename: 'sample.txt',
            mimeType: 'text/plain',
          ),
        );

        expect(result.filePath, file.path);
        expect(result.filename, 'sample.txt');
        expect(result.mimeType, 'text/plain');
        expect(result.size, file.lengthSync());
        expect(result.hash, isNull);
        expect(result.sourceFormat, CompressionImageFormat.unknown);
        expect(pipeline.calls, 0);
      },
    );

    test('maps pipeline result fields to attachment result', () async {
      final file = await _writeTempFile(
        support,
        name: 'sample.png',
        bytes: const [1, 2, 3, 4],
      );
      final pipeline = _RecordingPipeline(
        const CompressionPipelineResult(
          filePath: '/cache/sample.jpg',
          filename: 'sample.jpg',
          mimeType: 'image/jpeg',
          size: 1234,
          width: 64,
          height: 32,
          hash: 'hash123',
          sourceSignature: 'sig123',
          cacheKey: 'cache123',
          sourceFormat: CompressionImageFormat.png,
          effectiveOutputFormat: CompressionImageFormat.jpeg,
          engineId: 'dart_fallback',
          engineVersion: 'image_package',
          fromCache: true,
          fallback: false,
          wasConverted: true,
          wasResized: true,
          fallbackReason: null,
        ),
      );
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings.defaults,
        probeService: _FakeProbeService(
          _probeForImage(file, filename: 'sample.png', mimeType: 'image/png'),
        ),
        pipeline: pipeline,
      );

      final result = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      expect(pipeline.calls, 1);
      expect(pipeline.lastRequest, isNotNull);
      expect(pipeline.lastRequest!.path, file.path);
      expect(pipeline.lastRequest!.filename, 'sample.png');
      expect(pipeline.lastRequest!.mimeType, 'image/png');
      expect(result.filePath, '/cache/sample.jpg');
      expect(result.filename, 'sample.jpg');
      expect(result.mimeType, 'image/jpeg');
      expect(result.size, 1234);
      expect(result.width, 64);
      expect(result.height, 32);
      expect(result.hash, 'hash123');
      expect(result.sourceSig, 'sig123');
      expect(result.compressKey, 'cache123');
      expect(result.sourceFormat, CompressionImageFormat.png);
      expect(result.effectiveOutputFormat, CompressionImageFormat.jpeg);
      expect(result.engine, 'dart_fallback');
      expect(result.engineVersion, 'image_package');
      expect(result.fromCache, isTrue);
      expect(result.fallback, isFalse);
      expect(result.wasConverted, isTrue);
      expect(result.wasResized, isTrue);
      expect(result.fallbackReason, isNull);
    });
  });
}
