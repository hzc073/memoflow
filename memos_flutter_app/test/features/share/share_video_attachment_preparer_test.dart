import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/api/memos_api.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_video_attachment_preparer.dart';
import 'package:memos_flutter_app/features/share/share_video_compression_service.dart';
import 'package:memos_flutter_app/features/share/share_video_download_service.dart';
import 'package:memos_flutter_app/features/share/share_video_limit_messages.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test('video upload limit messages use known non-default backend limit', () {
    final translations = AppLocale.en.translations;
    final maxBytes = 96 * 1024 * 1024;
    final fileSizeBytes = 120 * 1024 * 1024;

    final title = shareVideoAttachmentTooLargeTitle(translations, maxBytes);
    final body = shareVideoAttachmentTooLargeBody(
      translations,
      fileSizeBytes: fileSizeBytes,
      maxBytes: maxBytes,
    );
    final failure = shareVideoAttachmentStillTooLargeMessage(
      translations,
      maxBytes: maxBytes,
    );

    expect(title, 'Video is larger than 96.0 MB');
    expect(
      body,
      'This video is 120.0 MB, which exceeds the server attachment limit of 96.0 MB.',
    );
    expect(
      failure,
      'Compressed video is still larger than 96.0 MB, so the app saved the link only.',
    );
    expect('$title\n$body\n$failure', isNot(contains('30 MB')));
  });

  test(
    'unknown still-too-large limit falls back to generic compression failure',
    () {
      final translations = AppLocale.en.translations;

      expect(
        shareVideoAttachmentStillTooLargeMessage(translations, maxBytes: null),
        'Video compression failed, so the app saved the link only.',
      );
    },
  );

  test(
    'unknown upload limit does not trigger hard 30 MiB compression',
    () async {
      final dir = await support.createTempDir('video_preparer_unknown_limit');
      final file = File('${dir.path}/large.mp4');
      await file.writeAsString('video');
      final downloadService = _FakeDownloadService(
        result: ShareVideoDownloadResult(
          filePath: file.path,
          fileSize: 60 * 1024 * 1024,
          headers: const <String, String>{},
        ),
      );
      final compressionService = _FakeCompressionService();
      final preparer = ShareVideoAttachmentPreparer(
        downloadService: downloadService,
        compressionService: compressionService,
      );

      final prepared = await preparer.prepare(
        result: _captureResult(),
        candidate: _candidate(),
        uploadSizeLimit: const AttachmentUploadSizeLimit.unknown(
          AttachmentUploadSizeLimitUnknownReason.requestFailed,
        ),
      );

      expect(prepared.size, 60 * 1024 * 1024);
      expect(compressionService.callCount, 0);
    },
  );

  test(
    'known upload limit derives compression target from backend limit',
    () async {
      final dir = await support.createTempDir('video_preparer_known_limit');
      final input = File('${dir.path}/large.mp4');
      final output = File('${dir.path}/compressed.mp4');
      await input.writeAsString('video');
      await output.writeAsString('compressed');
      final downloadService = _FakeDownloadService(
        result: ShareVideoDownloadResult(
          filePath: input.path,
          fileSize: 80 * 1024 * 1024,
          headers: const <String, String>{},
        ),
      );
      final compressionService = _FakeCompressionService(
        result: ShareVideoCompressionResult(
          filePath: output.path,
          fileSize: 47 * 1024 * 1024,
          wasCompressed: true,
        ),
      );
      final preparer = ShareVideoAttachmentPreparer(
        downloadService: downloadService,
        compressionService: compressionService,
      );

      final prepared = await preparer.prepare(
        result: _captureResult(),
        candidate: _candidate(),
        uploadSizeLimit: const AttachmentUploadSizeLimit.known(
          bytes: 50 * 1024 * 1024,
          source: AttachmentUploadSizeLimitSource.instanceStorageSetting,
        ),
      );

      expect(prepared.filePath, output.path);
      expect(prepared.wasCompressed, isTrue);
      expect(compressionService.callCount, 1);
      expect(compressionService.lastMaxBytes, 50 * 1024 * 1024);
      expect(
        compressionService.lastTargetBytes,
        shareVideoCompressionTargetBytesForLimit(50 * 1024 * 1024),
      );
    },
  );
}

ShareCaptureResult _captureResult() {
  return ShareCaptureResult.success(
    finalUrl: Uri.parse('https://www.xiaohongshu.com/explore/video'),
    pageKind: SharePageKind.video,
    siteParserTag: 'xiaohongshu',
  );
}

ShareVideoCandidate _candidate() {
  return const ShareVideoCandidate(
    id: 'h264',
    url: 'https://sns-video.xhscdn.com/h264.mp4',
    source: ShareVideoSource.parser,
    isDirectDownloadable: true,
  );
}

class _FakeDownloadService extends ShareVideoDownloadService {
  _FakeDownloadService({required this.result}) : super();

  final ShareVideoDownloadResult result;

  @override
  Future<ShareVideoProbeResult> probe({
    required ShareCaptureResult result,
    required ShareVideoCandidate candidate,
  }) async {
    return ShareVideoProbeResult(
      headers: this.result.headers,
      contentLength: this.result.fileSize,
      mimeType: 'video/mp4',
    );
  }

  @override
  Future<ShareVideoDownloadResult> download({
    required ShareCaptureResult result,
    required ShareVideoCandidate candidate,
    ValueChanged<double>? onProgress,
  }) async {
    return this.result;
  }
}

class _FakeCompressionService extends ShareVideoCompressionService {
  _FakeCompressionService({this.result}) : super();

  final ShareVideoCompressionResult? result;
  int callCount = 0;
  int? lastMaxBytes;
  int? lastTargetBytes;

  @override
  Future<ShareVideoCompressionResult?> compressToFit({
    required String inputPath,
    int maxBytes = kShareVideoAttachmentLimitBytes,
    int targetBytes = kShareVideoCompressionTargetBytes,
    ValueChanged<double>? onProgress,
  }) async {
    callCount++;
    lastMaxBytes = maxBytes;
    lastTargetBytes = targetBytes;
    return result;
  }
}
