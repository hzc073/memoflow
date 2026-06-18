import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/share_video_compression_service.dart';
import 'package:memos_flutter_app/platform_capabilities/ios_mobile_feature_readiness.dart';

void main() {
  group('ShareVideoCompressionService', () {
    test('compresses oversized file to target', () async {
      final tempDir = await Directory.systemTemp.createTemp('share-compress');
      addTearDown(() => tempDir.delete(recursive: true));
      final input = File('${tempDir.path}/input.mp4');
      await input.writeAsBytes(Uint8List.fromList(List<int>.filled(40, 1)));
      final client = _FakeCompressionClient([25]);
      final service = ShareVideoCompressionService(
        client: client,
        resolveDirectory: () async => tempDir,
        metadataReader: (_) async => const ShareVideoCompressionMetadata(
          width: 1920,
          height: 1080,
          durationSeconds: 10,
        ),
        isCompressionSupported: () => true,
      );

      final result = await service.compressToFit(
        inputPath: input.path,
        maxBytes: 30,
        targetBytes: 29,
      );

      expect(result, isNotNull);
      expect(result!.wasCompressed, isTrue);
      expect(result.fileSize, lessThanOrEqualTo(30));
    });

    test(
      'returns second-round result when first round still too large',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('share-compress');
        addTearDown(() => tempDir.delete(recursive: true));
        final input = File('${tempDir.path}/input.mp4');
        await input.writeAsBytes(Uint8List.fromList(List<int>.filled(40, 1)));
        final client = _FakeCompressionClient([35, 28]);
        final service = ShareVideoCompressionService(
          client: client,
          resolveDirectory: () async => tempDir,
          metadataReader: (_) async => const ShareVideoCompressionMetadata(
            width: 1920,
            height: 1080,
            durationSeconds: 10,
          ),
          isCompressionSupported: () => true,
        );

        final result = await service.compressToFit(
          inputPath: input.path,
          maxBytes: 30,
          targetBytes: 29,
        );

        expect(client.callCount, 2);
        expect(result, isNotNull);
        expect(result!.fileSize, 28);
      },
    );

    test('platform support includes iOS mobile', () {
      expect(
        isShareVideoCompressionSupportedOnPlatform(
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
        isTrue,
      );
      expect(
        isShareVideoCompressionSupportedOnPlatform(
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        isTrue,
      );
      expect(
        isShareVideoCompressionSupportedOnPlatform(
          platform: TargetPlatform.windows,
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('platform support follows iOS video compression readiness', () {
      expect(
        isShareVideoCompressionSupportedOnPlatform(
          platform: TargetPlatform.iOS,
          isWeb: false,
          readinessInputs: const IosMobileFeatureReadinessInputs(
            isIosMobile: true,
            shareVideoCompressionAvailable: false,
          ),
        ),
        isFalse,
      );
    });
  });
}

class _FakeCompressionClient implements ShareVideoCompressionClient {
  _FakeCompressionClient(this.outputSizes);

  final List<int> outputSizes;
  int callCount = 0;

  @override
  Future<String?> compress({
    required String inputPath,
    required int bitrate,
    int? width,
    int? height,
    required bool preserveResolution,
    void Function(double progress)? onProgress,
  }) async {
    final dir = Directory.systemTemp;
    final size = outputSizes[callCount.clamp(0, outputSizes.length - 1)];
    callCount += 1;
    final file = File('${dir.path}/compressed_$callCount.mp4');
    await file.writeAsBytes(Uint8List.fromList(List<int>.filled(size, 1)));
    onProgress?.call(1);
    return file.path;
  }
}
