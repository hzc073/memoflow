import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/memo_clip_card_metadata.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/features/share/share_task_window_codec.dart';

void main() {
  test('share payload round-trips through JSON-safe map', () {
    const payload = SharePayload(
      type: SharePayloadType.text,
      text: 'Title https://example.com/article',
      title: 'Title',
      paths: <String>['/tmp/a.png'],
    );

    final decoded = sharePayloadFromJson(sharePayloadToJson(payload));

    expect(decoded, isNotNull);
    expect(decoded!.type, payload.type);
    expect(decoded.handlingMode, SharePayloadHandlingMode.standardShare);
    expect(decoded.text, payload.text);
    expect(decoded.title, payload.title);
    expect(decoded.paths, payload.paths);
  });

  test('share payload preserves quick record mode through JSON-safe map', () {
    const payload = SharePayload(
      type: SharePayloadType.text,
      handlingMode: SharePayloadHandlingMode.quickRecord,
      text: 'Read https://example.com/article',
    );

    final decoded = sharePayloadFromJson(sharePayloadToJson(payload));

    expect(decoded, isNotNull);
    expect(decoded!.handlingMode, SharePayloadHandlingMode.quickRecord);
    expect(decoded.text, payload.text);
  });

  test('share compose request preserves capture and attachment fields', () {
    final captureResult = ShareCaptureResult.success(
      finalUrl: Uri.parse('https://example.com/article'),
      articleTitle: 'Article',
      siteName: 'Example',
      leadImageUrl: 'https://cdn.example.com/lead.jpg',
      contentHtml: '<p>Hello</p>',
      readabilitySucceeded: true,
      pageKind: SharePageKind.video,
      videoCandidates: const <ShareVideoCandidate>[
        ShareVideoCandidate(
          id: 'video-1',
          url: 'https://cdn.example.com/video.mp4',
          source: ShareVideoSource.parser,
          headers: <String, String>{'Referer': 'https://example.com'},
          isDirectDownloadable: true,
          priority: 7,
          parserTag: 'example',
        ),
      ],
      imageAttachmentUrls: const <String>['https://cdn.example.com/image.jpg'],
    );
    final request = ShareComposeRequest(
      text: '# Article\n\nHello',
      selectionOffset: 15,
      attachmentPaths: const <String>['/tmp/local.png'],
      initialAttachmentSeeds: const <ShareAttachmentSeed>[
        ShareAttachmentSeed(
          uid: 'seed-1',
          filePath: '/tmp/seed.png',
          filename: 'seed.png',
          mimeType: 'image/png',
          size: 123,
          skipCompression: true,
          shareInlineImage: true,
          fromThirdPartyShare: true,
          sourceUrl: 'https://example.com/seed.png',
        ),
      ],
      deferredInlineImageAttachments:
          <ShareDeferredInlineImageAttachmentRequest>[
            ShareDeferredInlineImageAttachmentRequest(
              captureResult: captureResult,
              sourceUrl: 'https://cdn.example.com/image.jpg',
              index: 1,
            ),
          ],
      deferredVideoAttachments: <ShareDeferredVideoAttachmentRequest>[
        ShareDeferredVideoAttachmentRequest(
          captureResult: captureResult,
          candidate: captureResult.videoCandidates.single,
        ),
      ],
      clipMetadataDraft: const ShareClipMetadataDraft(
        clipKind: MemoClipKind.article,
        platform: MemoClipPlatform.web,
        sourceName: 'Example',
        sourceUrl: 'https://example.com/article',
        leadImageUrl: 'https://cdn.example.com/lead.jpg',
        parserTag: 'example',
      ),
      userMessage: 'Saved',
      showLocalSaveSuccessToast: true,
    );

    final decoded = shareComposeRequestFromJson(
      shareComposeRequestToJson(request),
    );

    expect(decoded, isNotNull);
    expect(decoded!.text, request.text);
    expect(decoded.selectionOffset, request.selectionOffset);
    expect(decoded.attachmentPaths, request.attachmentPaths);
    expect(decoded.initialAttachmentSeeds.single.uid, 'seed-1');
    expect(
      decoded.initialAttachmentSeeds.single.sourceUrl,
      request.initialAttachmentSeeds.single.sourceUrl,
    );
    expect(decoded.deferredInlineImageAttachments.single.index, 1);
    expect(
      decoded.deferredInlineImageAttachments.single.captureResult.articleTitle,
      'Article',
    );
    expect(
      decoded.deferredVideoAttachments.single.candidate.headers,
      <String, String>{'Referer': 'https://example.com'},
    );
    expect(decoded.clipMetadataDraft!.sourceName, 'Example');
    expect(decoded.userMessage, 'Saved');
    expect(decoded.showLocalSaveSuccessToast, isTrue);
  });

  test('desktop share result and cancel payloads carry request id', () {
    final result = DesktopShareTaskResult(
      requestId: 'share-1',
      request: const ShareComposeRequest(text: 'body', selectionOffset: 4),
    );

    final decoded = DesktopShareTaskResult.fromArgs(result.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.requestId, 'share-1');
    expect(decoded.request.text, 'body');
    expect(
      desktopShareTaskCanceledRequestId(
        desktopShareTaskCanceledToJson('share-1'),
      ),
      'share-1',
    );
  });
}
