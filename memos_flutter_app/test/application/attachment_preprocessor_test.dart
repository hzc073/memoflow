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
}) async {
  final dir = await support.createTempDir('img');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  final image = img.Image(width: 16, height: 16);
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

    test('auto alpha detection only for png/webp', () async {
      var alphaChecks = 0;
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
        alphaDetector: (path) async {
          alphaChecks += 1;
          return false;
        },
      );

      await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: jpgFile.path,
          filename: 'sample.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      await preprocessor.preprocess(
        AttachmentPreprocessRequest(
          filePath: pngFile.path,
          filename: 'sample.png',
          mimeType: 'image/png',
        ),
      );

      expect(alphaChecks, 1);
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
  });
}
