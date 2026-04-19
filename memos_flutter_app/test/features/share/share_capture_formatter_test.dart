import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/memo_clip_card_metadata.dart';
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
      expect(
        text,
        isNot(contains('[Article Title](https://example.com/posts/42)')),
      );
      expect(text, isNot(contains('> Short summary')));
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

    test('uses html paragraphs for text-only clipping fallback', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        articleTitle: 'Article Title',
        contentHtml:
            '<div><p>First paragraph.</p><p>Second paragraph.</p><p><img src="https://example.com/cover.png"></p><p>Third paragraph.</p></div>',
        textContent: 'First paragraph. Second paragraph. Third paragraph.',
      );

      final text = buildShareCaptureMemoText(
        result: result,
        payload: payload,
        contentHtmlOverride: '',
      );

      expect(
        text,
        contains('First paragraph.\n\nSecond paragraph.\n\nThird paragraph.'),
      );
      expect(text, isNot(contains('![](https://example.com/cover.png)')));
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
        pageKind: SharePageKind.article,
      );

      final request = buildShareComposeRequestFromCapture(
        result: result,
        payload: payload,
        initialAttachmentSeeds: const [seed],
        contentHtmlOverride: '<p>Hello</p><img src="$localUrl">',
      );

      expect(request.text, contains('![]($localUrl)'));
      expect(request.clipMetadataDraft, isNotNull);
      expect(
        request.clipMetadataDraft!.sourceUrl,
        'https://example.com/posts/42',
      );
    });

    test('preserves sized html images as html tags in memo body', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        articleTitle: 'Article Title',
        contentHtml:
            '<div><p>Intro</p><p><img src="/small.png" width="360" height="360"></p><p>Outro</p></div>',
        pageKind: SharePageKind.article,
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(
        text,
        contains(
          '<img src="https://example.com/small.png" width="360" height="360">',
        ),
      );
      expect(text, isNot(contains('![](https://example.com/small.png)')));
    });

    test('wechat memo body keeps relative image widths', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://mp.weixin.qq.com/s/example',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
        articleTitle: 'Article Title',
        contentHtml:
            '<div><p><img src="https://mmbiz.qpic.cn/small.png" width="360" height="360"></p><p><img src="https://mmbiz.qpic.cn/large.png" width="1080" height="1080"></p></div>',
        pageKind: SharePageKind.article,
        siteParserTag: 'wechat',
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(
        text,
        contains('<img src="https://mmbiz.qpic.cn/small.png" width="33.33%">'),
      );
      expect(
        text,
        contains('<img src="https://mmbiz.qpic.cn/large.png" width="100%">'),
      );
      expect(text, isNot(contains('height="360"')));
      expect(text, isNot(contains('height="1080"')));
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

    test('collapses spurious CJK whitespace from captured html', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://example.com/posts/42',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://example.com/posts/42'),
        articleTitle: 'Article Title',
        contentHtml:
            '<div><p>中&nbsp;&nbsp;&nbsp;&nbsp;文</p><p><span>排</span>\n<span>版</span></p><p>Hello <strong>world</strong></p></div>',
      );

      final text = buildShareCaptureMemoText(result: result, payload: payload);

      expect(text, contains('中文'));
      expect(text, contains('排版'));
      expect(text, contains('Hello **world**'));
      expect(text, isNot(contains('中 文')));
      expect(text, isNot(contains('排 版')));
    });

    test(
      'clip metadata draft keeps avatars and suppresses wechat cover image',
      () {
        const payload = SharePayload(
          type: SharePayloadType.text,
          text: 'https://mp.weixin.qq.com/s/example',
        );
        final result = ShareCaptureResult.success(
          finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
          articleTitle: 'Article Title',
          siteName: '\u4e2d\u56fd\u6c11\u5175',
          sourceAvatarUrl: 'http://mmbiz.qpic.cn/account-avatar.png',
          byline: '2026-04-14 01:41',
          authorAvatarUrl: 'http://mmbiz.qpic.cn/author-avatar.png',
          contentHtml: '<p>Hello</p><img src="https://mmbiz.qpic.cn/body.png">',
          leadImageUrl: 'http://mmbiz.qpic.cn/body.png',
          pageKind: SharePageKind.article,
          siteParserTag: 'wechat',
        );

        final request = buildShareComposeRequestFromCapture(
          result: result,
          payload: payload,
        );

        expect(request.clipMetadataDraft, isNotNull);
        expect(
          request.clipMetadataDraft!.sourceAvatarUrl,
          'https://mmbiz.qpic.cn/account-avatar.png',
        );
        expect(
          request.clipMetadataDraft!.authorAvatarUrl,
          'https://mmbiz.qpic.cn/author-avatar.png',
        );
        expect(request.clipMetadataDraft!.authorName, isEmpty);
        expect(request.clipMetadataDraft!.leadImageUrl, isEmpty);
      },
    );

    test('clip metadata draft maps coolapk platform and keeps site logo', () {
      const payload = SharePayload(
        type: SharePayloadType.text,
        text: 'https://www.coolapk.com/feed/71282288',
      );
      final result = ShareCaptureResult.success(
        finalUrl: Uri.parse('https://www.coolapk.com/feed/71282288'),
        articleTitle:
            '\u521a\u5237\u5230\u4e00\u4e2a\u6551\u4eba\u7684\u89c6\u9891... \u6765\u81ea \u7231\u559d\u56db\u5b63\u6625\u8336\u7684\u74dc\u76ae - \u9177\u5b89',
        siteName: '\u9177\u5b89',
        sourceAvatarUrl:
            'http://static.coolapk.com/static/web/v8/images/header-logo.png',
        byline: '\u7231\u559d\u56db\u5b63\u6625\u8336\u7684\u74dc\u76ae',
        authorAvatarUrl:
            'http://avatar.coolapk.com/data/008/71/30/32_avatar_middle.jpg?t=1622016648',
        contentHtml:
            '<div class="feed-message"><p>\u521a\u5237\u5230\u4e00\u4e2a\u6551\u4eba\u7684\u89c6\u9891\uff0c\u6211\u53ef\u5c31\u8981\u9a84\u50b2\u8d77\u6765\u4e86\u3002</p></div>',
        leadImageUrl: 'http://image.coolapk.com/feed/example.jpg',
        pageKind: SharePageKind.article,
        siteParserTag: 'coolapk',
      );

      final request = buildShareComposeRequestFromCapture(
        result: result,
        payload: payload,
      );

      expect(request.clipMetadataDraft, isNotNull);
      expect(request.clipMetadataDraft!.platform, MemoClipPlatform.coolapk);
      expect(
        request.clipMetadataDraft!.sourceAvatarUrl,
        'https://static.coolapk.com/static/web/v8/images/header-logo.png',
      );
      expect(
        request.clipMetadataDraft!.authorAvatarUrl,
        'https://avatar.coolapk.com/data/008/71/30/32_avatar_middle.jpg?t=1622016648',
      );
      expect(
        request.clipMetadataDraft!.leadImageUrl,
        'https://image.coolapk.com/feed/example.jpg',
      );
      expect(
        request.clipMetadataDraft!.authorName,
        '\u7231\u559d\u56db\u5b63\u6625\u8336\u7684\u74dc\u76ae',
      );
    });
  });

  test('buildLinkOnlyMemoText uses markdown link and appends tags', () {
    const payload = SharePayload(
      type: SharePayloadType.text,
      text: 'https://example.com/articles/1',
      title: 'Example article',
    );

    final text = buildLinkOnlyMemoText(
      payload,
      tags: const <String>['#clip', 'reading'],
    );

    expect(
      text,
      '[Example article](https://example.com/articles/1)\n\n#clip reading',
    );
  });
}
