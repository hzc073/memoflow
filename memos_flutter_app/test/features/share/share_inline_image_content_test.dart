import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_inline_image_content.dart';

void main() {
  test('buildShareInlineSyncContent swaps local images for placeholders', () {
    const attachment = ShareAttachmentSeed(
      uid: 'att-1',
      filePath: '/tmp/article-image.jpg',
      filename: 'article-image.jpg',
      mimeType: 'image/jpeg',
      size: 123,
      shareInlineImage: true,
    );
    final localUrl = shareInlineLocalUrlFromPath(attachment.filePath);
    final content = '<p>hello</p><img src="$localUrl" alt="cover">';

    final result = buildShareInlineSyncContent(content, const [attachment]);

    expect(result, contains(buildShareInlineImagePlaceholder('att-1')));
    expect(result, isNot(contains(localUrl)));
  });

  test('replaceShareInlineLocalUrlWithRemote rewrites every occurrence', () {
    final localUrl = shareInlineLocalUrlFromPath('/tmp/article-image.jpg');
    final content = '<img src="$localUrl">\n![]($localUrl)';

    final result = replaceShareInlineLocalUrlWithRemote(
      content,
      localUrl: localUrl,
      remoteUrl: 'https://example.com/file/att-1.jpg',
    );

    expect(result, isNot(contains(localUrl)));
    expect(result, contains('https://example.com/file/att-1.jpg'));
  });

  test('replaceShareInlineImageUrl matches html-escaped remote urls', () {
    const remoteUrl =
        'https://mmbiz.qpic.cn/example/640?wx_fmt=jpeg&from=appmsg';
    const localUrl = 'file:///tmp/shared-inline-image.jpg';
    final content =
        '<img src="https://mmbiz.qpic.cn/example/640?wx_fmt=jpeg&amp;from=appmsg">';

    final result = replaceShareInlineImageUrl(
      content,
      fromUrl: remoteUrl,
      toUrl: localUrl,
    );

    expect(result, contains('src="$localUrl"'));
    expect(result, isNot(contains('wx_fmt=jpeg&amp;from=appmsg')));
  });

  test('contentContainsShareInlineImageUrl matches html-escaped urls', () {
    const remoteUrl =
        'https://mmbiz.qpic.cn/example/640?wx_fmt=jpeg&from=appmsg';
    const content =
        '<img src="https://mmbiz.qpic.cn/example/640?wx_fmt=jpeg&amp;from=appmsg">';

    expect(contentContainsShareInlineImageUrl(content, remoteUrl), isTrue);
  });

  test('removeShareInlineImageReferences drops html and markdown images', () {
    final localUrl = shareInlineLocalUrlFromPath('/tmp/article-image.jpg');
    final content =
        '<p>intro</p>\n<img src="$localUrl">\n![]($localUrl)\n<p>end</p>';

    final result = removeShareInlineImageReferences(
      content,
      localUrl: localUrl,
    );

    expect(result, contains('<p>intro</p>'));
    expect(result, contains('<p>end</p>'));
    expect(result, isNot(contains(localUrl)));
  });

  test('rewriteShareInlineImageUrlsForSyncContent rewrites html and markdown', () {
    final localUrl = shareInlineLocalUrlFromPath('/tmp/article-image.jpg');
    const remoteUrl = 'https://example.com/file/resources/att-1/article-image.jpg';
    final content =
        '<p>intro</p>\n<img src="$localUrl">\n![]($localUrl)\n<p>end</p>';

    final result = rewriteShareInlineImageUrlsForSyncContent(
      content,
      replacements: {localUrl: remoteUrl},
    );

    expect(result, contains(remoteUrl));
    expect(result, isNot(contains(localUrl)));
    expect(result, contains('<p>intro</p>'));
    expect(result, contains('<p>end</p>'));
  });

  test('rewriteShareInlineImageUrlsForSyncContent removes unresolved local refs', () {
    final localUrl = shareInlineLocalUrlFromPath('/tmp/article-image.jpg');
    final content =
        '<p>intro</p>\n<img src="$localUrl">\n![]($localUrl)\n<p>end</p>';

    final result = rewriteShareInlineImageUrlsForSyncContent(
      content,
      replacements: const <String, String>{},
      removeLocalUrls: {localUrl},
    );

    expect(result, contains('<p>intro</p>'));
    expect(result, contains('<p>end</p>'));
    expect(result, isNot(contains(localUrl)));
    expect(result, isNot(contains('<img')));
    expect(result, isNot(contains('![](')));
  });

  test('extractShareInlineLocalImageUrls finds html and markdown local urls', () {
    final localUrlOne = shareInlineLocalUrlFromPath('/tmp/article-image.jpg');
    final localUrlTwo = shareInlineLocalUrlFromPath('/tmp/article-image-2.jpg');
    final content =
        '<img src="$localUrlOne">\n![]($localUrlTwo)\n```md\n![]($localUrlOne)\n```';

    final urls = extractShareInlineLocalImageUrls(content);

    expect(urls, contains(localUrlOne));
    expect(urls, contains(localUrlTwo));
    expect(urls, hasLength(2));
  });

  test('resolveShareInlineAttachmentRemoteUrl repairs attachment file routes', () {
    final attachment = Attachment(
      name: 'resources/att-1',
      filename: 'sample.png',
      type: 'image/png',
      size: 42,
      externalLink: 'file:///tmp/sample.png',
    );

    final result = resolveShareInlineAttachmentRemoteUrl(attachment);

    expect(result, '/file/resources/att-1/sample.png');
  });

  test(
    'resolveShareInlineAttachmentRemoteUrl prefixes base url when provided',
    () {
      final attachment = Attachment(
        name: 'resources/att-1',
        filename: 'sample.png',
        type: 'image/png',
        size: 42,
        externalLink: '',
      );

      final result = resolveShareInlineAttachmentRemoteUrl(
        attachment,
        baseUrl: Uri.parse('http://192.168.13.13:45230'),
      );

      expect(
        result,
        'http://192.168.13.13:45230/file/resources/att-1/sample.png',
      );
    },
  );

  test('resolveShareInlineAttachmentRemoteUrl keeps remote external links', () {
    const remoteUrl = 'https://example.com/file/resources/att-1/sample.png';
    final attachment = Attachment(
      name: 'resources/att-1',
      filename: 'sample.png',
      type: 'image/png',
      size: 42,
      externalLink: remoteUrl,
    );

    final result = resolveShareInlineAttachmentRemoteUrl(attachment);

    expect(result, remoteUrl);
  });
}
