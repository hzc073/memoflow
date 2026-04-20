import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/models/image_compression_settings.dart';

void main() {
  group('ImageCompressionSettings', () {
    test('defaults match V2 Caesium-style settings', () {
      final defaults = ImageCompressionSettings.defaults;

      expect(
        defaults.schemaVersion,
        ImageCompressionSettings.currentSchemaVersion,
      );
      expect(defaults.enabled, isTrue);
      expect(defaults.mode, ImageCompressionMode.quality);
      expect(defaults.outputFormat, ImageCompressionOutputFormat.sameAsInput);
      expect(defaults.lossless, isFalse);
      expect(defaults.keepMetadata, isFalse);
      expect(defaults.skipIfBigger, isTrue);
      expect(defaults.resize.enabled, isFalse);
      expect(defaults.resize.mode, ImageCompressionResizeMode.longEdge);
      expect(defaults.resize.edge, 1920);
      expect(defaults.resize.doNotEnlarge, isTrue);
      expect(defaults.jpeg.quality, 80);
      expect(defaults.jpeg.chromaSubsampling, JpegChromaSubsampling.auto);
      expect(defaults.jpeg.progressive, isTrue);
      expect(defaults.png.quality, 80);
      expect(defaults.png.optimizationLevel, 3);
      expect(defaults.webp.quality, 60);
      expect(defaults.tiff.method, TiffCompressionMethod.lzw);
      expect(defaults.tiff.deflatePreset, TiffDeflatePreset.balanced);
      expect(defaults.sizeTarget.value, 80);
      expect(
        defaults.sizeTarget.unit,
        ImageCompressionMaxOutputUnit.percentage,
      );
    });

    test('toJson and fromJson round-trip nested V2 values', () {
      final original = ImageCompressionSettings.defaults.copyWith(
        enabled: false,
        mode: ImageCompressionMode.size,
        outputFormat: ImageCompressionOutputFormat.webp,
        lossless: true,
        keepMetadata: true,
        skipIfBigger: false,
        resize: ImageCompressionSettings.defaults.resize.copyWith(
          enabled: true,
          mode: ImageCompressionResizeMode.fixedHeight,
          width: 1111,
          height: 777,
          edge: 555,
          doNotEnlarge: false,
        ),
        jpeg: ImageCompressionSettings.defaults.jpeg.copyWith(
          quality: 72,
          chromaSubsampling: JpegChromaSubsampling.chroma422,
          progressive: false,
        ),
        png: ImageCompressionSettings.defaults.png.copyWith(
          quality: 61,
          optimizationLevel: 6,
        ),
        webp: ImageCompressionSettings.defaults.webp.copyWith(quality: 44),
        tiff: ImageCompressionSettings.defaults.tiff.copyWith(
          method: TiffCompressionMethod.deflate,
          deflatePreset: TiffDeflatePreset.best,
        ),
        sizeTarget: const ImageCompressionSizeTarget(
          value: 256,
          unit: ImageCompressionMaxOutputUnit.kb,
        ),
      );

      final decoded = ImageCompressionSettings.fromJson(original.toJson());

      expect(decoded.toJson(), original.toJson());
    });

    test('invalid enums fall back to defaults', () {
      final decoded = ImageCompressionSettings.fromJson({
        'schemaVersion': 2,
        'enabled': true,
        'mode': '???',
        'outputFormat': '???',
        'lossless': true,
        'keepMetadata': true,
        'skipIfBigger': false,
        'resize': {
          'enabled': true,
          'mode': '???',
          'width': 123,
          'height': 456,
          'edge': 789,
          'doNotEnlarge': false,
        },
        'jpeg': {
          'quality': 70,
          'chromaSubsampling': '???',
          'progressive': false,
        },
        'png': {'quality': 55, 'optimizationLevel': 5},
        'webp': {'quality': 52},
        'tiff': {'method': '???', 'deflatePreset': '???'},
        'sizeTarget': {'value': 10, 'unit': '???'},
      });

      expect(decoded.mode, ImageCompressionSettings.defaults.mode);
      expect(
        decoded.outputFormat,
        ImageCompressionSettings.defaults.outputFormat,
      );
      expect(
        decoded.resize.mode,
        ImageCompressionSettings.defaults.resize.mode,
      );
      expect(
        decoded.jpeg.chromaSubsampling,
        ImageCompressionSettings.defaults.jpeg.chromaSubsampling,
      );
      expect(
        decoded.tiff.method,
        ImageCompressionSettings.defaults.tiff.method,
      );
      expect(
        decoded.tiff.deflatePreset,
        ImageCompressionSettings.defaults.tiff.deflatePreset,
      );
      expect(
        decoded.sizeTarget.unit,
        ImageCompressionSettings.defaults.sizeTarget.unit,
      );
    });

    test('legacy V1 payload maps into V2 structure', () {
      final decoded = ImageCompressionSettings.fromJson({
        'schemaVersion': 1,
        'enabled': true,
        'maxSide': 1024,
        'quality': 67,
        'format': 'jpeg',
      });

      expect(
        decoded.schemaVersion,
        ImageCompressionSettings.currentSchemaVersion,
      );
      expect(decoded.enabled, isTrue);
      expect(decoded.outputFormat, ImageCompressionOutputFormat.jpeg);
      expect(decoded.resize.edge, 1024);
      expect(decoded.jpeg.quality, 67);
      expect(decoded.png.quality, 67);
      expect(decoded.webp.quality, 67);
    });
  });
}
