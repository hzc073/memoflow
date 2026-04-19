import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/share/parsers/bilibili_share_page_parser.dart';
import 'package:memos_flutter_app/features/share/parsers/coolapk_share_page_parser.dart';
import 'package:memos_flutter_app/features/share/parsers/generic_share_page_parser.dart';
import 'package:memos_flutter_app/features/share/parsers/share_page_parser.dart';
import 'package:memos_flutter_app/features/share/parsers/wechat_share_page_parser.dart';
import 'package:memos_flutter_app/features/share/parsers/xiaohongshu_share_page_parser.dart';
import 'package:memos_flutter_app/features/share/share_clip_models.dart';
import 'package:memos_flutter_app/features/share/share_handler.dart';
import 'package:memos_flutter_app/features/share/wechat_static_capture_strategy.dart';

class _FakeShareStaticHtmlHttpClient implements ShareStaticHtmlHttpClient {
  _FakeShareStaticHtmlHttpClient({
    required this.body,
    required this.finalUrl,
    required this.userAgent,
  });

  final String body;
  final Uri finalUrl;
  final String userAgent;

  @override
  Future<ShareStaticHtmlHttpResponse> get(
    Uri url, {
    required Map<String, String> headers,
  }) async {
    return ShareStaticHtmlHttpResponse(
      body: body,
      finalUrl: finalUrl,
      userAgent: userAgent,
    );
  }
}

void main() {
  group('share page parsers', () {
    test('generic parser detects article page', () {
      final parser = GenericSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://example.com/post/1'),
        finalUrl: Uri.parse('https://example.com/post/1'),
        host: 'example.com',
        bridgeData: const {
          'articleTitle': 'Example Article',
          'excerpt': 'Summary',
          'contentHtml': '<p>Hello world</p>',
          'textContent':
              'Hello world Hello world Hello world Hello world Hello world',
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.article);
      expect(result.videoCandidates, isEmpty);
      expect(result.title, 'Example Article');
    });

    test('generic parser detects direct video candidate', () {
      final parser = GenericSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://example.com/video'),
        finalUrl: Uri.parse('https://example.com/video'),
        host: 'example.com',
        bridgeData: const {
          'pageTitle': 'Video Page',
          'rawVideoHints': [
            {
              'url': 'https://cdn.example.com/video.mp4',
              'source': 'meta',
              'mimeType': 'video/mp4',
            },
          ],
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.video);
      expect(result.videoCandidates, hasLength(1));
      expect(result.videoCandidates.first.isDirectDownloadable, isTrue);
    });

    test('coolapk parser extracts site logo and author metadata', () {
      final parser = CoolapkSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://www.coolapk.com/feed/71282288'),
        finalUrl: Uri.parse('https://www.coolapk.com/feed/71282288'),
        host: 'www.coolapk.com',
        bridgeData: const {
          'pageTitle':
              '\u521a\u5237\u5230\u4e00\u4e2a\u6551\u4eba\u7684\u89c6\u9891... \u6765\u81ea \u7231\u559d\u56db\u5b63\u6625\u8336\u7684\u74dc\u76ae - \u9177\u5b89',
          'excerpt':
              '\u521a\u5237\u5230\u4e00\u4e2a\u6551\u4eba\u7684\u89c6\u9891\uff0c\u6211\u53ef\u5c31\u8981\u9a84\u50b2\u8d77\u6765\u4e86\u3002',
          'coolapkContentHtml':
              '<div class="feed-message"><p>\u521a\u5237\u5230\u4e00\u4e2a\u6551\u4eba\u7684\u89c6\u9891\uff0c\u6211\u53ef\u5c31\u8981\u9a84\u50b2\u8d77\u6765\u4e86\u3002</p></div><div class="message-image-group"><img src="https://image.coolapk.com/feed/example.jpg"></div>',
          'coolapkTextContent':
              '\u521a\u5237\u5230\u4e00\u4e2a\u6551\u4eba\u7684\u89c6\u9891\uff0c\u6211\u53ef\u5c31\u8981\u9a84\u50b2\u8d77\u6765\u4e86\u3002\u665a\u4e0a\u5728\u82cf\u5dde\u7684\u957f\u6865\u4e0a\u9762\uff0c\u5e95\u4e0b\u5c31\u662f\u5927\u8fd0\u6cb3\uff0c\u6211\u628a\u4e00\u4f4d\u8981\u8df3\u6cb3\u7684\u5973\u5b69\u7ed9\u4e00\u628a\u62fd\u4e0b\u6765\u4e86\u3002',
          'coolapkSiteName': '\u9177\u5b89',
          'coolapkSiteIconUrl':
              'https://static.coolapk.com/static/web/v8/images/header-logo.png',
          'coolapkAuthor':
              '\u7231\u559d\u56db\u5b63\u6625\u8336\u7684\u74dc\u76ae',
          'coolapkAuthorAvatar':
              'http://avatar.coolapk.com/data/008/71/30/32_avatar_middle.jpg?t=1622016648',
          'coolapkLeadImageUrl': 'https://image.coolapk.com/feed/example.jpg',
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.article);
      expect(result.siteName, '\u9177\u5b89');
      expect(
        result.sourceAvatarUrl,
        'https://static.coolapk.com/static/web/v8/images/header-logo.png',
      );
      expect(
        result.byline,
        '\u7231\u559d\u56db\u5b63\u6625\u8336\u7684\u74dc\u76ae',
      );
      expect(
        result.authorAvatarUrl,
        'http://avatar.coolapk.com/data/008/71/30/32_avatar_middle.jpg?t=1622016648',
      );
      expect(result.leadImageUrl, 'https://image.coolapk.com/feed/example.jpg');
      expect(result.parserTag, 'coolapk');
    });

    test('bilibili parser detects video from playinfo', () {
      final parser = BilibiliSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://www.bilibili.com/video/BV1xx'),
        finalUrl: Uri.parse('https://www.bilibili.com/video/BV1xx'),
        host: 'www.bilibili.com',
        bridgeData: const {
          'windowStates': {
            '__playinfo__': {
              'data': {
                'durl': [
                  {'url': 'https://upos-sz-mirror.bilivideo.com/example.mp4'},
                ],
              },
            },
            '__INITIAL_STATE__': {
              'videoData': {
                'title': 'Bilibili Video',
                'desc': 'Bilibili description',
              },
            },
          },
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.video);
      expect(result.videoCandidates, isNotEmpty);
      expect(result.title, 'Bilibili Video');
    });

    test('xiaohongshu parser detects video note', () {
      final parser = XiaohongshuSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://www.xiaohongshu.com/explore/123'),
        finalUrl: Uri.parse('https://www.xiaohongshu.com/explore/123'),
        host: 'www.xiaohongshu.com',
        bridgeData: const {
          'windowStates': {
            '__INITIAL_STATE__': {
              'note': {
                'title': 'XHS Video',
                'desc': 'XHS description',
                'noteType': 'video',
                'masterUrl': 'https://sns-video-bd.xhscdn.com/example.mp4',
              },
            },
          },
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.video);
      expect(result.videoCandidates, isNotEmpty);
      expect(result.title, 'XHS Video');
    });

    test(
      'wechat parser prefers official account html and suppresses duplicate excerpt',
      () {
        final parser = WechatSharePageParser();
        final snapshot = SharePageSnapshot(
          requestUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
          finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
          host: 'mp.weixin.qq.com',
          bridgeData: const {
            'articleTitle':
                '\u4e2d\u56fd\u6d77\u8b66\u8230\u8247\u7f16\u961f\u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5de1\u822a',
            'excerpt':
                '\u4e2d\u56fd\u6d77\u8b66\u8230\u8247\u7f16\u961f4\u670814\u65e5\u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5de1\u822a4\u670814\u65e5\uff0c\u4e2d\u56fd\u6d77\u8b662308\u8230\u8247\u7f16\u961f\u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5185\u5de1\u822a\u3002',
            'wechatAccountName': '\u4e2d\u56fd\u6c11\u5175',
            'wechatAccountAvatar': 'http://mmbiz.qpic.cn/account-avatar.png',
            'wechatAuthor': '\u738b\u661f\u60f3',
            'wechatAuthorAvatar': 'http://mmbiz.qpic.cn/author-avatar.png',
            'wechatContentHtml':
                '<div><p><strong><span>\u9884\u7ea6\u76f4\u64ad</span></strong></p><p>\u4e2d\u56fd\u6d77\u8b66\u8230\u8247\u7f16\u961f4\u670814\u65e5</p><p>\u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5de1\u822a</p><p><img data-src="https://mmbiz.qpic.cn/body.jpg"></p><p>4\u670814\u65e5\uff0c\u4e2d\u56fd\u6d77\u8b662308\u8230\u8247\u7f16\u961f\u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5185\u5de1\u822a\u3002</p><p>\u8fd9\u662f\u4e2d\u56fd\u6d77\u8b66\u4f9d\u6cd5\u5f00\u5c55\u7684\u7ef4\u6743\u5de1\u822a\u6d3b\u52a8\u3002</p><p>\u70b9\u51fb\u5c0f\u7a0b\u5e8f\uff0c\u7acb\u5373\u8ba2\u9605</p></div>',
            'wechatTextContent':
                '\u9884\u7ea6\u76f4\u64ad \u4e2d\u56fd\u6d77\u8b66\u8230\u8247\u7f16\u961f4\u670814\u65e5 \u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5de1\u822a 4\u670814\u65e5\uff0c\u4e2d\u56fd\u6d77\u8b662308\u8230\u8247\u7f16\u961f\u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5185\u5de1\u822a\u3002 \u8fd9\u662f\u4e2d\u56fd\u6d77\u8b66\u4f9d\u6cd5\u5f00\u5c55\u7684\u7ef4\u6743\u5de1\u822a\u6d3b\u52a8\u3002 \u70b9\u51fb\u5c0f\u7a0b\u5e8f\uff0c\u7acb\u5373\u8ba2\u9605',
          },
        );

        final result = parser.parse(snapshot);

        expect(result.pageKind, SharePageKind.article);
        expect(result.parserTag, 'wechat');
        expect(
          result.title,
          '\u4e2d\u56fd\u6d77\u8b66\u8230\u8247\u7f16\u961f\u5728\u6211\u9493\u9c7c\u5c9b\u9886\u6d77\u5de1\u822a',
        );
        expect(result.siteName, '\u4e2d\u56fd\u6c11\u5175');
        expect(
          result.sourceAvatarUrl,
          'http://mmbiz.qpic.cn/account-avatar.png',
        );
        expect(result.byline, '\u738b\u661f\u60f3');
        expect(
          result.authorAvatarUrl,
          'http://mmbiz.qpic.cn/author-avatar.png',
        );
        expect(result.excerpt, isNull);
        expect(
          result.contentHtml,
          contains(
            '\u4e2d\u56fd\u6d77\u8b66\u8230\u8247\u7f16\u961f4\u670814\u65e5',
          ),
        );
        expect(
          result.contentHtml,
          contains(
            '\u8fd9\u662f\u4e2d\u56fd\u6d77\u8b66\u4f9d\u6cd5\u5f00\u5c55\u7684\u7ef4\u6743\u5de1\u822a\u6d3b\u52a8',
          ),
        );
        expect(
          result.contentHtml,
          contains('src="https://mmbiz.qpic.cn/body.jpg"'),
        );
        expect(result.contentHtml, isNot(contains('imgIndex=')));
        expect(result.contentHtml, isNot(contains('\u9884\u7ea6\u76f4\u64ad')));
        expect(
          result.contentHtml,
          isNot(contains('\u70b9\u51fb\u5c0f\u7a0b\u5e8f')),
        );
        expect(
          result.textContent,
          contains(
            '\u4e2d\u56fd\u6d77\u8b66\u8230\u8247\u7f16\u961f4\u670814\u65e5',
          ),
        );
        expect(result.textContent, isNot(contains('\u7acb\u5373\u8ba2\u9605')));
      },
    );

    test(
      'wechat parser focuses inner article root and drops repeated title noise',
      () {
        final parser = WechatSharePageParser();
        final snapshot = SharePageSnapshot(
          requestUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
          finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
          host: 'mp.weixin.qq.com',
          bridgeData: const {
            'articleTitle': '\u793a\u4f8b\u6807\u9898',
            'wechatContentHtml':
                '<div id="img-content"><h1 id="activity-name">\u793a\u4f8b\u6807\u9898</h1><div id="meta_content"><span>\u4e2d\u56fd\u6c11\u5175</span><span>2026\u5e744\u670814\u65e5 01:41</span><a>\u53bb\u9605\u8bfb\u5728\u5c0f\u8bf4\u9605\u8bfb\u5668\u4e2d\u6c89\u6d78\u9605\u8bfb</a></div><div id="js_content" class="rich_media_content"><p>\u793a\u4f8b\u6807\u9898</p><p>\u6b63\u6587\u9996\u6bb5\u3002</p><p>\u7b2c\u4e8c\u6bb5\u3002</p></div><div class="rich_media_area_extra"><p>\u9884\u7ea6\u65f6\u6807\u7b7e\u4e0d\u53ef\u70b9</p></div></div>',
            'wechatTextContent':
                '\u793a\u4f8b\u6807\u9898 \u4e2d\u56fd\u6c11\u5175 2026\u5e744\u670814\u65e5 01:41 \u53bb\u9605\u8bfb\u5728\u5c0f\u8bf4\u9605\u8bfb\u5668\u4e2d\u6c89\u6d78\u9605\u8bfb \u793a\u4f8b\u6807\u9898 \u6b63\u6587\u9996\u6bb5\u3002 \u7b2c\u4e8c\u6bb5\u3002 \u9884\u7ea6\u65f6\u6807\u7b7e\u4e0d\u53ef\u70b9',
          },
        );

        final result = parser.parse(snapshot);

        expect(result.pageKind, SharePageKind.article);
        expect(result.contentHtml, contains('\u6b63\u6587\u9996\u6bb5\u3002'));
        expect(result.contentHtml, contains('\u7b2c\u4e8c\u6bb5\u3002'));
        expect(result.contentHtml, isNot(contains('\u793a\u4f8b\u6807\u9898')));
        expect(
          result.contentHtml,
          isNot(
            contains(
              '\u53bb\u9605\u8bfb\u5728\u5c0f\u8bf4\u9605\u8bfb\u5668\u4e2d\u6c89\u6d78\u9605\u8bfb',
            ),
          ),
        );
        expect(
          result.contentHtml,
          isNot(contains('\u9884\u7ea6\u65f6\u6807\u7b7e\u4e0d\u53ef\u70b9')),
        );
        expect(result.textContent, contains('\u6b63\u6587\u9996\u6bb5\u3002'));
        expect(result.textContent, contains('\u7b2c\u4e8c\u6bb5\u3002'));
        expect(result.textContent, isNot(contains('\u793a\u4f8b\u6807\u9898')));
      },
    );

    test('wechat parser removes malformed image tail fragments', () {
      final parser = WechatSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
        finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
        host: 'mp.weixin.qq.com',
        bridgeData: const {
          'articleTitle': 'Article',
          'wechatContentHtml':
              '<div><p>Paragraph A.</p><p><img data-src="http://mmbiz.qpic.cn/body.jpg?wx_fmt=png&amp;from=appmsg#imgIndex=3&lt;span class=&quot;bad&quot;&gt;"></p>#imgIndex=3" alt="\u56fe\u7247"><p>Paragraph B.</p></div>',
          'wechatTextContent': 'Paragraph A. Paragraph B.',
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.article);
      expect(result.contentHtml, contains('Paragraph A.'));
      expect(result.contentHtml, contains('Paragraph B.'));
      expect(
        result.contentHtml,
        contains(
          'src="https://mmbiz.qpic.cn/body.jpg?wx_fmt=png&amp;from=appmsg"',
        ),
      );
      expect(result.contentHtml, isNot(contains('imgIndex=')));
      expect(result.contentHtml, isNot(contains('span class=')));
      expect(result.textContent, isNot(contains('imgIndex')));
    });

    test('wechat parser promotes alternative image attributes to src', () {
      final parser = WechatSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
        finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
        host: 'mp.weixin.qq.com',
        bridgeData: const {
          'articleTitle': 'Article',
          'wechatContentHtml':
              '<div><p>Paragraph A.</p><p><img data-url="http://mmbiz.qpic.cn/body.jpg?wx_fmt=png&amp;from=appmsg#imgIndex=2"></p><p>Paragraph B.</p></div>',
          'wechatTextContent': 'Paragraph A. Paragraph B.',
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.article);
      expect(result.contentHtml, contains('Paragraph A.'));
      expect(result.contentHtml, contains('Paragraph B.'));
      expect(
        result.contentHtml,
        contains(
          'src="https://mmbiz.qpic.cn/body.jpg?wx_fmt=png&amp;from=appmsg"',
        ),
      );
      expect(result.contentHtml, isNot(contains('data-url=')));
      expect(result.contentHtml, isNot(contains('imgIndex=')));
    });

    test('wechat parser preserves image display dimensions from data attrs', () {
      final parser = WechatSharePageParser();
      final snapshot = SharePageSnapshot(
        requestUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
        finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
        host: 'mp.weixin.qq.com',
        bridgeData: const {
          'articleTitle': 'Article',
          'wechatContentHtml':
              '<div><p>Paragraph A.</p><p><img data-src="https://mmbiz.qpic.cn/small.jpg" data-w="360" data-ratio="1"></p><p>Paragraph B.</p><p><img data-src="https://mmbiz.qpic.cn/large.jpg" data-w="1080" data-ratio="1"></p><p>Paragraph C with enough text to make the parser treat this as article content.</p></div>',
          'wechatTextContent':
              'Paragraph A. Paragraph B. Paragraph C with enough text to make the parser treat this as article content.',
        },
      );

      final result = parser.parse(snapshot);

      expect(result.pageKind, SharePageKind.article);
      expect(
        result.contentHtml,
        contains('src="https://mmbiz.qpic.cn/small.jpg"'),
      );
      expect(result.contentHtml, contains('width="360"'));
      expect(result.contentHtml, contains('height="360"'));
      expect(
        result.contentHtml,
        contains('src="https://mmbiz.qpic.cn/large.jpg"'),
      );
      expect(result.contentHtml, contains('width="1080"'));
      expect(result.contentHtml, contains('height="1080"'));
    });

    test('wechat static strategy captures article from server html', () async {
      const html = '''
<!doctype html>
<html>
  <head>
    <title>示例页面标题</title>
    <meta property="og:title" content="示例标题" />
    <meta name="description" content="文章摘要" />
    <meta property="og:image" content="http://mmbiz.qpic.cn/cover.jpg?wx_fmt=png" />
  </head>
  <body>
    <div id="img-content">
      <h1 id="activity-name">示例标题</h1>
      <div id="meta_content">
        <span id="js_name">中国民兵</span>
        <span id="js_author_name">作者甲</span>
      </div>
      <div id="js_content" class="rich_media_content">
        <p>第一段。</p>
        <p>
          <img
            data-src="http://mmbiz.qpic.cn/body.jpg?wx_fmt=png&amp;from=appmsg#imgIndex=1"
          />
        </p>
        <p>第二段。</p>
      </div>
    </div>
  </body>
</html>
''';
      final strategy = WechatStaticCaptureStrategy(
        client: _FakeShareStaticHtmlHttpClient(
          body: html,
          finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
          userAgent: 'test-agent',
        ),
      );

      final result = await strategy.capture(
        ShareCaptureRequest(
          payload: const SharePayload(
            type: SharePayloadType.text,
            text: 'https://mp.weixin.qq.com/s/example',
            title: '示例标题',
          ),
          url: Uri.parse('https://mp.weixin.qq.com/s/example'),
          sharedTitle: '示例标题',
          sharedText: 'https://mp.weixin.qq.com/s/example',
        ),
      );

      expect(result, isNotNull);
      expect(result!.isSuccess, isTrue);
      expect(result.pageKind, SharePageKind.article);
      expect(result.siteParserTag, 'wechat-static');
      expect(result.articleTitle, '示例标题');
      expect(result.siteName, '中国民兵');
      expect(result.byline, '作者甲');
      expect(result.contentHtml, contains('第一段。'));
      expect(result.contentHtml, contains('第二段。'));
      expect(
        result.contentHtml,
        contains(
          'src="https://mmbiz.qpic.cn/body.jpg?wx_fmt=png&amp;from=appmsg"',
        ),
      );
      expect(result.textContent, contains('第一段。'));
      expect(result.textContent, contains('第二段。'));
      expect(result.leadImageUrl, 'https://mmbiz.qpic.cn/cover.jpg?wx_fmt=png');
    });

    test('wechat static strategy skips html without article root', () async {
      final strategy = WechatStaticCaptureStrategy(
        client: _FakeShareStaticHtmlHttpClient(
          body: '<html><body><p>环境异常，请稍后重试</p></body></html>',
          finalUrl: Uri.parse('https://mp.weixin.qq.com/s/example'),
          userAgent: 'test-agent',
        ),
      );

      final result = await strategy.capture(
        ShareCaptureRequest(
          payload: const SharePayload(
            type: SharePayloadType.text,
            text: 'https://mp.weixin.qq.com/s/example',
          ),
          url: Uri.parse('https://mp.weixin.qq.com/s/example'),
          sharedTitle: null,
          sharedText: 'https://mp.weixin.qq.com/s/example',
        ),
      );

      expect(result, isNull);
    });
  });
}
