import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:memos_flutter_app/application/attachments/attachment_preprocessor.dart';
import 'package:memos_flutter_app/application/attachments/dart_image_preprocessor.dart';
import 'package:memos_flutter_app/application/attachments/image_preprocessor.dart';
import 'package:memos_flutter_app/data/models/image_compression_settings.dart';

import '../test_support.dart';

class _FailingPreprocessor implements ImagePreprocessor {
  int calls = 0;

  @override
  String get engine => 'dart';

  @override
  bool get supportsWebp => true;

  @override
  bool get isAvailable => true;

  @override
  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request) async {
    calls += 1;
    throw StateError('boom');
  }
}

class _CopyingPreprocessor implements ImagePreprocessor {
  _CopyingPreprocessor({this.name = 'copy', this.available = true});

  final String name;
  final bool available;

  @override
  String get engine => name;

  @override
  bool get supportsWebp => true;

  @override
  bool get isAvailable => available;

  @override
  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request) async {
    final target = File(request.targetPath);
    await target.parent.create(recursive: true);
    await File(request.sourcePath).copy(target.path);
    return ImagePreprocessResult(outputPath: target.path);
  }
}

class _RecordingPreprocessor extends _CopyingPreprocessor {
  _RecordingPreprocessor({super.name = 'recording'});

  ImagePreprocessRequest? lastRequest;

  @override
  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request) async {
    lastRequest = request;
    return super.compress(request);
  }
}

class _MissingPluginPreprocessor implements ImagePreprocessor {
  _MissingPluginPreprocessor(this.name);

  final String name;
  int calls = 0;

  @override
  String get engine => name;

  @override
  bool get supportsWebp => true;

  @override
  bool get isAvailable => true;

  @override
  Future<ImagePreprocessResult> compress(ImagePreprocessRequest request) async {
    calls += 1;
    throw MissingPluginException('missing $name');
  }
}

Future<File> _writeTestImage(
  TestSupport support, {
  required String name,
  required ImageCompressionFormat format,
  bool withAlpha = false,
  int width = 16,
  int height = 16,
}) async {
  final dir = await support.createTempDir('img');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  final image = img.Image(width: width, height: height);
  image.clear(img.ColorRgba8(10, 20, 30, 255));
  if (withAlpha) {
    image.setPixelRgba(0, 0, 10, 20, 30, 100);
  }
  final bytes = switch (format) {
    ImageCompressionFormat.webp => img.encodePng(image),
    ImageCompressionFormat.jpeg => img.encodeJpg(image, quality: 90),
    ImageCompressionFormat.auto => img.encodePng(image),
  };
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  return file;
}

Future<String> _sha256File(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

void main() {
  group('AttachmentPreprocessor', () {
    late TestSupport support;

    setUp(() async {
      support = await initializeTestSupport();
    });

    tearDown(() async {
      await support.dispose();
    });

    test('cache hit avoids recompress', () async {
      final file = await _writeTestImage(
        support,
        name: 'sample.png',
        format: ImageCompressionFormat.auto,
      );
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings(
          schemaVersion: 1,
          enabled: true,
          maxSide: 64,
          quality: 80,
          format: ImageCompressionFormat.jpeg,
        ),
        windowsPreprocessor: _CopyingPreprocessor(
          name: 'windows',
          available: false,
        ),
        flutterPreprocessor: _CopyingPreprocessor(
          name: 'flutter',
          available: false,
        ),
        dartPreprocessor: DartImagePreprocessor(),
      );

      final first = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );
      final second = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(second.filePath, first.filePath);
    });

    test('fallback cached on failure', () async {
      final file = await _writeTestImage(
        support,
        name: 'sample.png',
        format: ImageCompressionFormat.auto,
      );
      final failing = _FailingPreprocessor();
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings(
          schemaVersion: 1,
          enabled: true,
          maxSide: 64,
          quality: 80,
          format: ImageCompressionFormat.jpeg,
        ),
        windowsPreprocessor: _CopyingPreprocessor(
          name: 'windows',
          available: false,
        ),
        flutterPreprocessor: _CopyingPreprocessor(
          name: 'flutter',
          available: false,
        ),
        dartPreprocessor: failing,
      );

      final first = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );
      final second = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      expect(first.fallback, isTrue);
      expect(second.fromCache, isTrue);
      expect(failing.calls, 1);
    });

    test('auto format keeps png-like content on webp', () async {
      final jpgFile = await _writeTestImage(
        support,
        name: 'sample.jpg',
        format: ImageCompressionFormat.jpeg,
      );
      final pngFile = await _writeTestImage(
        support,
        name: 'sample.png',
        format: ImageCompressionFormat.auto,
      );
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings(
          schemaVersion: 1,
          enabled: true,
          maxSide: 64,
          quality: 80,
          format: ImageCompressionFormat.auto,
        ),
        windowsPreprocessor: _CopyingPreprocessor(
          name: 'windows',
          available: false,
        ),
        flutterPreprocessor: _CopyingPreprocessor(),
      );

      final jpgResult = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: jpgFile.path,
          filename: 'sample.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      final pngResult = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: pngFile.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      expect(jpgResult.mimeType, 'image/jpeg');
      expect(pngResult.mimeType, 'image/webp');
      expect(pngResult.filename, endsWith('.webp'));
    });

    test('native preprocessors receive proportional resize targets', () async {
      final file = await _writeTestImage(
        support,
        name: 'tall.png',
        format: ImageCompressionFormat.auto,
        width: 100,
        height: 300,
      );
      final recorder = _RecordingPreprocessor(name: 'flutter');
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings(
          schemaVersion: 1,
          enabled: true,
          maxSide: 75,
          quality: 80,
          format: ImageCompressionFormat.jpeg,
        ),
        windowsPreprocessor: _CopyingPreprocessor(
          name: 'windows',
          available: false,
        ),
        flutterPreprocessor: recorder,
        dartPreprocessor: _CopyingPreprocessor(
          name: 'dart',
          available: false,
        ),
      );

      await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'tall.png',
          mimeType: 'image/png',
        ),
      );

      expect(recorder.lastRequest, isNotNull);
      expect(recorder.lastRequest!.targetWidth, 25);
      expect(recorder.lastRequest!.targetHeight, 75);
    });

    test('sha256 matches final output', () async {
      final file = await _writeTestImage(
        support,
        name: 'sample.png',
        format: ImageCompressionFormat.auto,
        withAlpha: true,
      );
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings(
          schemaVersion: 1,
          enabled: true,
          maxSide: 64,
          quality: 80,
          format: ImageCompressionFormat.jpeg,
        ),
        windowsPreprocessor: _CopyingPreprocessor(
          name: 'windows',
          available: false,
        ),
        flutterPreprocessor: _CopyingPreprocessor(
          name: 'flutter',
          available: false,
        ),
        dartPreprocessor: DartImagePreprocessor(),
      );

      final result = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      final expected = await _sha256File(result.filePath);
      expect(result.hash, expected);
    });

    test('windows preprocessor is preferred when available', () async {
      final file = await _writeTestImage(
        support,
        name: 'sample.png',
        format: ImageCompressionFormat.auto,
      );
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings(
          schemaVersion: 1,
          enabled: true,
          maxSide: 64,
          quality: 80,
          format: ImageCompressionFormat.jpeg,
        ),
        windowsPreprocessor: _CopyingPreprocessor(name: 'windows'),
        flutterPreprocessor: _CopyingPreprocessor(name: 'flutter'),
        dartPreprocessor: _CopyingPreprocessor(name: 'dart'),
      );

      final result = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      expect(result.engine, 'windows');
      expect(result.fallback, isFalse);
    });

    test('missing native plugin falls back to dart engine', () async {
      final file = await _writeTestImage(
        support,
        name: 'sample.png',
        format: ImageCompressionFormat.auto,
      );
      final missing = _MissingPluginPreprocessor('windows');
      final preprocessor = DefaultAttachmentPreprocessor(
        loadSettings: () async => ImageCompressionSettings(
          schemaVersion: 1,
          enabled: true,
          maxSide: 64,
          quality: 80,
          format: ImageCompressionFormat.jpeg,
        ),
        windowsPreprocessor: missing,
        flutterPreprocessor: _CopyingPreprocessor(
          name: 'flutter',
          available: false,
        ),
        dartPreprocessor: _CopyingPreprocessor(name: 'dart'),
      );

      final result = await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: file.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      expect(missing.calls, 1);
      expect(result.engine, 'dart');
      expect(result.fallback, isFalse);
    });

    test(
      'skipCompression keeps original image while preserving metadata',
      () async {
        final file = await _writeTestImage(
          support,
          name: 'sample.png',
          format: ImageCompressionFormat.auto,
        );
        final preprocessor = DefaultAttachmentPreprocessor(
          loadSettings: () async => ImageCompressionSettings(
            schemaVersion: 1,
            enabled: true,
            maxSide: 64,
            quality: 80,
            format: ImageCompressionFormat.jpeg,
          ),
          windowsPreprocessor: _CopyingPreprocessor(name: 'windows'),
          flutterPreprocessor: _CopyingPreprocessor(name: 'flutter'),
          dartPreprocessor: _CopyingPreprocessor(name: 'dart'),
        );

        final expectedHash = await _sha256File(file.path);
        final result = await preprocessor.preprocess(
          AttachmentPreprocessRequest(
            filePath: file.path,
            filename: 'sample.png',
            mimeType: 'image/png',
            skipCompression: true,
          ),
        );

        expect(result.filePath, file.path);
        expect(result.filename, 'sample.png');
        expect(result.mimeType, 'image/png');
        expect(result.size, await file.length());
        expect(result.width, 16);
        expect(result.height, 16);
        expect(result.hash, expectedHash);
        expect(result.engine, isNull);
        expect(result.fallback, isFalse);
        expect(result.fromCache, isFalse);
      },
    );

    test(
      'skipCompression on non-image keeps existing passthrough behavior',
      () async {
        final dir = await support.createTempDir('attachment');
        final file = File('${dir.path}${Platform.pathSeparator}sample.txt');
        await file.writeAsString('hello world', flush: true);
        final preprocessor = DefaultAttachmentPreprocessor(
          loadSettings: () async => ImageCompressionSettings(
            schemaVersion: 1,
            enabled: true,
            maxSide: 64,
            quality: 80,
            format: ImageCompressionFormat.jpeg,
          ),
          windowsPreprocessor: _CopyingPreprocessor(name: 'windows'),
          flutterPreprocessor: _CopyingPreprocessor(name: 'flutter'),
          dartPreprocessor: _CopyingPreprocessor(name: 'dart'),
        );

        final result = await preprocessor.preprocess(
          AttachmentPreprocessRequest(
            filePath: file.path,
            filename: 'sample.txt',
            mimeType: 'text/plain',
            skipCompression: true,
          ),
        );

        expect(result.filePath, file.path);
        expect(result.filename, 'sample.txt');
        expect(result.mimeType, 'text/plain');
        expect(result.size, await file.length());
        expect(result.width, isNull);
        expect(result.height, isNull);
        expect(result.hash, isNull);
        expect(result.engine, isNull);
      },
    );
  });
}
