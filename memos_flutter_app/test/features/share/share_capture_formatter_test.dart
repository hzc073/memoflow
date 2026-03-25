import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/share_capture_formatter.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/features/share/share_inline_image_content.dart';

void main() {
  group('buildShareCaptureMemoText', () {
    test('prefers article title and absolutizes links and images', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
        title: 'Shared Title',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        pageTitle: 'Page Title',
        articleTitle: 'Article Title',
        siteName: 'Example',
        excerpt: 'Short summary',
        contentHtml:
            '<div><h2>Body</h2><a href="/about">About</a><img src="/cover.png"></div>',
        readabilitySucceeded: true,
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, startsWith('# Article Title'));
      expect(text, contains('[Article Title](https://example.com/posts/42)'));
      expect(text, contains('> Short summary'));
      expect(text, contains('## Body'));
      expect(text, contains('[About](https://example.com/about)'));
      expect(text, contains('![](https://example.com/cover.png)'));
      expect(text, contains(buildThirdPartyShareMemoMarker()));
      expect(text.toLowerCase(), isNot(contains('<html')));
      expect(text.toLowerCase(), isNot(contains('<body')));
      expect(text.toLowerCase(), isNot(contains('<p')));
      expect(text.toLowerCase(), isNot(contains('<span')));
    });

    test('omits excerpt block when excerpt is absent', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        siteName: 'Example',
        contentHtml: '<p>Hello</p>',
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, isNot(contains('> ')));
    });

    test('uses compact memo body for video pages', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/videos/42',
        title: 'Shared Video',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/videos/42'),
        articleTitle: 'Video Title',
        excerpt: 'Video summary',
        textContent: 'Long body that should not be included in full.',
        pageKind: SharePageKind.video,
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, contains('# Video Title'));
      expect(text, contains('[Video Title](https://example.com/videos/42)'));
      expect(text, contains('> Video summary'));
      expect(text, isNot(contains('<p>Long body')));
    });
    test('falls back to text paragraphs when html content is absent', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        textContent:
            'First paragraph.\n\nSecond paragraph.\n\nThird paragraph.',
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(
        text,
        contains('First paragraph.\n\nSecond paragraph.\n\nThird paragraph.'),
      );
    });

    test('keeps allowed local file image urls in sanitized fragment', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      const seed = ShareAttachmentSeed(
        uid: 'att-1',
        filePath: '/tmp/article-image.jpg',
        filename: 'article-image.jpg',
        mimeType: 'image/jpeg',
        size: 1,
        shareInlineImage: true,
      );
      final localUrl = shareInlineLocalUrlFromPath(seed.filePath);
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        articleTitle: 'Article Title',
        contentHtml: '<p>Hello</p>',
      );

      final request = buildShareComposeRequestFromCapture(
        result: result,
        payload: payload,
        initialAttachmentSeeds: const [seed],
        contentHtmlOverride: '<p>Hello</p><img src="$localUrl">',
      );

      expect(request.text, contains('![]($localUrl)'));
    });

    test('converts nested span paragraph and list html into markdown', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        articleTitle: 'Article Title',
        contentHtml:
            '<div><p><span>Hello </span><strong><span>World</span></strong></p><ul><li><p>Item 1</p></li><li><span>Item 2</span></li></ul></div>',
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, contains('Hello **World**'));
      expect(text, contains('- Item 1'));
      expect(text, contains('- Item 2'));
      expect(text.toLowerCase(), isNot(contains('<span')));
      expect(text.toLowerCase(), isNot(contains('<p')));
      expect(text.toLowerCase(), isNot(contains('<li')));
    });
  });
}
