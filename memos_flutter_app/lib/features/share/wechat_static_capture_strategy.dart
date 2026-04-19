import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'parsers/share_page_parser.dart';
import 'parsers/wechat_share_page_parser.dart';
import 'share_clip_models.dart';

const String _wechatStaticUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

@immutable
class ShareStaticHtmlHttpResponse {
  const ShareStaticHtmlHttpResponse({
    required this.body,
    required this.finalUrl,
    required this.userAgent,
  });

  final String body;
  final Uri finalUrl;
  final String userAgent;
}

abstract class ShareStaticHtmlHttpClient {
  Future<ShareStaticHtmlHttpResponse> get(
    Uri url, {
    required Map<String, String> headers,
  });
}

class DioShareStaticHtmlHttpClient implements ShareStaticHtmlHttpClient {
  DioShareStaticHtmlHttpClient({Dio? dio}) : _dio = dio ?? Dio();

  static const _connectTimeout = Duration(seconds: 8);
  static const _receiveTimeout = Duration(seconds: 8);

  final Dio _dio;

  @override
  Future<ShareStaticHtmlHttpResponse> get(
    Uri url, {
    required Map<String, String> headers,
  }) async {
    final response = await _dio.get<List<int>>(
      url.toString(),
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
        followRedirects: true,
        sendTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    final body = _decodeBody(
      response.data ?? const <int>[],
      contentType: response.headers.value(Headers.contentTypeHeader),
    );
    return ShareStaticHtmlHttpResponse(
      body: body,
      finalUrl: response.realUri,
      userAgent: headers['User-Agent'] ?? _wechatStaticUserAgent,
    );
  }

  String _decodeBody(List<int> bytes, {String? contentType}) {
    if (bytes.isEmpty) {
      return '';
    }
    final charset = _extractCharset(contentType);
    final normalizedCharset = charset?.toLowerCase() ?? '';
    if (normalizedCharset.isEmpty ||
        normalizedCharset == 'utf-8' ||
        normalizedCharset == 'utf8') {
      return utf8.decode(bytes, allowMalformed: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String? _extractCharset(String? contentType) {
    if (contentType == null) return null;
    final match = RegExp(
      r"""charset\s*=\s*["']?([^;"']+)""",
      caseSensitive: false,
    ).firstMatch(contentType);
    return normalizeShareText(match?.group(1));
  }
}

class WechatStaticCaptureStrategy {
  WechatStaticCaptureStrategy({ShareStaticHtmlHttpClient? client})
    : _client = client ?? DioShareStaticHtmlHttpClient();

  final ShareStaticHtmlHttpClient _client;

  bool canCapture(Uri url) => isWechatMpUrl(url);

  Future<ShareCaptureResult?> capture(ShareCaptureRequest request) async {
    try {
      if (!canCapture(request.url)) {
        return null;
      }

      final response = await _client.get(
        request.url,
        headers: _buildWechatHeaders(),
      );
      final bridgeData = extractWechatStaticBridgeData(
        html: response.body,
        finalUrl: response.finalUrl,
        userAgent: response.userAgent,
      );
      if (bridgeData == null) {
        return null;
      }

      final snapshot = SharePageSnapshot(
        requestUrl: request.url,
        finalUrl: response.finalUrl,
        host: response.finalUrl.host.toLowerCase(),
        bridgeData: bridgeData,
        userAgent: response.userAgent,
      );
      final parsed = WechatSharePageParser().parse(snapshot);
      final contentHtml =
          normalizeShareText(parsed.contentHtml) ??
          normalizeShareText(bridgeData['wechatContentHtml']?.toString()) ??
          normalizeShareText(bridgeData['contentHtml']?.toString());
      final textContent =
          normalizeShareText(parsed.textContent) ??
          normalizeShareText(bridgeData['wechatTextContent']?.toString()) ??
          normalizeShareText(bridgeData['textContent']?.toString());
      final hasArticleContent =
          (contentHtml ?? '').isNotEmpty || (textContent ?? '').length >= 80;
      if (!hasArticleContent) {
        return null;
      }

      return ShareCaptureResult.success(
        finalUrl: response.finalUrl,
        pageTitle: normalizeShareText(bridgeData['pageTitle']?.toString()),
        articleTitle:
            normalizeShareText(parsed.title) ??
            normalizeShareText(bridgeData['articleTitle']?.toString()),
        siteName:
            normalizeShareText(parsed.siteName) ??
            normalizeShareText(bridgeData['siteName']?.toString()),
        sourceAvatarUrl:
            normalizeShareText(parsed.sourceAvatarUrl) ??
            normalizeShareText(bridgeData['wechatAccountAvatar']?.toString()),
        byline:
            normalizeShareText(parsed.byline) ??
            normalizeShareText(bridgeData['wechatAuthor']?.toString()),
        authorAvatarUrl:
            normalizeShareText(parsed.authorAvatarUrl) ??
            normalizeShareText(bridgeData['wechatAuthorAvatar']?.toString()),
        excerpt:
            normalizeShareText(parsed.excerpt) ??
            normalizeShareText(bridgeData['excerpt']?.toString()),
        contentHtml: contentHtml,
        textContent: textContent,
        leadImageUrl:
            normalizeShareText(parsed.leadImageUrl) ??
            normalizeShareText(bridgeData['leadImageUrl']?.toString()),
        length: textContent?.length ?? 0,
        readabilitySucceeded: false,
        pageKind: parsed.pageKind,
        siteParserTag: 'wechat-static',
        pageUserAgent: response.userAgent,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _buildWechatHeaders() {
    return const <String, String>{
      'User-Agent': _wechatStaticUserAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
          'image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.7',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Referer': 'https://mp.weixin.qq.com/',
      'Upgrade-Insecure-Requests': '1',
    };
  }
}

bool isWechatMpUrl(Uri url) {
  final host = url.host.toLowerCase();
  return host == 'mp.weixin.qq.com' || host.endsWith('.mp.weixin.qq.com');
}

@visibleForTesting
Map<String, dynamic>? extractWechatStaticBridgeData({
  required String html,
  required Uri finalUrl,
  required String userAgent,
}) {
  if (!isWechatMpUrl(finalUrl)) {
    return null;
  }

  final document = html_parser.parse(html);
  final documentTitle = normalizeShareText(document.querySelector('title')?.text);
  final contentRoot = _selectWechatContentRoot(document);
  if (contentRoot == null) {
    return null;
  }

  final articleTitle =
      _readText(document, const [
        '#activity-name',
        'h1.rich_media_title',
      ]) ??
      _readMeta(document, const [
        'meta[property="og:title"]',
        'meta[name="twitter:title"]',
      ]) ??
      documentTitle;

  final siteName =
      _readText(document, const [
        '#js_name',
        '.rich_media_meta_nickname',
        '#profileBt',
        '#js_wx_follow_nickname_small_font',
      ]) ??
      _readMeta(document, const [
        'meta[property="og:site_name"]',
      ]) ??
      _readScriptString(html, const ['nickname']) ??
      '\u5fae\u4fe1\u516c\u4f17\u53f7';

  final authorName =
      _readText(document, const [
        '#js_author_name',
        '.meta_content#js_author_name',
        '.rich_media_meta_link[rel="author"]',
      ]) ??
      _readScriptString(html, const ['author']);

  final leadImageUrl = _sanitizeWechatImageUrl(
    _readMeta(document, const [
      'meta[property="og:image"]',
      'meta[name="twitter:image"]',
    ]),
    baseUrl: finalUrl,
  );
  final accountAvatar = _sanitizeWechatImageUrl(
    _readImageUrl(
          document,
          const [
            '.profile_container .profile_avatar img',
            '.profile_container .profile_meta_hd img',
            '.wx_profile_card_inner .profile_avatar img',
            '.wx_profile_card_inner .profile_meta_hd img',
            '.account_nickname_inner img',
          ],
        ) ??
        _readScriptString(
          html,
          const [
            'round_head_img',
            'hd_head_img',
            'ori_head_img_url',
            'msg_cdn_url',
          ],
        ),
    baseUrl: finalUrl,
  );
  final authorAvatar = _sanitizeWechatImageUrl(
    _readImageUrl(
          document,
          const [
            '#js_author_avatar img',
            '.rich_media_meta.author img',
            '.rich_media_meta_link[rel="author"] img',
            '.author_avatar img',
          ],
        ) ??
        _readScriptString(
          html,
          const ['author_head_img', 'authorHeadImg', 'authorAvatar'],
        ),
    baseUrl: finalUrl,
  );
  final excerpt = _readMeta(document, const [
    'meta[name="description"]',
    'meta[property="og:description"]',
    'meta[name="twitter:description"]',
  ]);
  final pageTitle = documentTitle ?? articleTitle;
  final rawContentHtml = normalizeShareText(contentRoot.outerHtml);
  final textContent = normalizeShareText(contentRoot.text);
  if ((rawContentHtml ?? '').isEmpty && (textContent ?? '').length < 80) {
    return null;
  }

  return <String, dynamic>{
    'finalUrl': finalUrl.toString(),
    'pageTitle': pageTitle,
    'articleTitle': articleTitle,
    'siteName': siteName,
    'excerpt': excerpt,
    'contentHtml': rawContentHtml,
    'textContent': textContent,
    'wechatContentHtml': rawContentHtml,
    'wechatTextContent': textContent,
    'wechatAccountName': siteName,
    'wechatAuthor': authorName,
    'wechatAccountAvatar': accountAvatar,
    'wechatAuthorAvatar': authorAvatar,
    'leadImageUrl': leadImageUrl,
    'length': textContent?.length ?? 0,
    'readabilitySucceeded': false,
    'pageUserAgent': userAgent,
  };
}

dom.Element? _selectWechatContentRoot(dom.Document document) {
  final candidates = <dom.Element>[
    ...document.querySelectorAll('#js_content'),
    ...document.querySelectorAll('.rich_media_content'),
    ...document.querySelectorAll('#img-content'),
    ...document.querySelectorAll('.rich_media_area_primary_inner'),
    ...document.querySelectorAll('.rich_media_wrp'),
  ];
  if (candidates.isEmpty) {
    return null;
  }

  dom.Element? best;
  var bestScore = -1;
  final seen = <dom.Element>{};
  for (final candidate in candidates) {
    if (!seen.add(candidate)) {
      continue;
    }
    final score = _scoreWechatContentRoot(candidate);
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

int _scoreWechatContentRoot(dom.Element element) {
  final textLength = (normalizeShareText(element.text) ?? '').length;
  final htmlLength = element.outerHtml.length;
  final imageCount = element.querySelectorAll('img').length;
  final lazyImageCount = element.querySelectorAll(
    'img[data-src],img[data-lazy-src],img[data-actualsrc],img[data-original],'
    'img[data-backsrc],img[data-url],img[data-imgsrc],img[data-origin-src],'
    'img[_src],img[srcs]',
  ).length;
  final paragraphCount = element.querySelectorAll('p').length;

  return imageCount * 20000 +
      lazyImageCount * 12000 +
      paragraphCount * 300 +
      textLength +
      (htmlLength ~/ 10);
}

String? _readMeta(dom.Document document, List<String> selectors) {
  for (final selector in selectors) {
    final value = normalizeShareText(
      document.querySelector(selector)?.attributes['content'],
    );
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _readText(dom.Document document, List<String> selectors) {
  for (final selector in selectors) {
    final value = normalizeShareText(document.querySelector(selector)?.text);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _readImageUrl(dom.Document document, List<String> selectors) {
  for (final selector in selectors) {
    final element = document.querySelector(selector);
    if (element == null) {
      continue;
    }
    final candidates = <String?>[
      element.attributes['data-headimg'],
      element.attributes['data-src'],
      element.attributes['data-lazy-src'],
      element.attributes['data-actualsrc'],
      element.attributes['data-original'],
      element.attributes['data-backsrc'],
      element.attributes['data-url'],
      element.attributes['data-imgsrc'],
      element.attributes['data-origin-src'],
      element.attributes['data-cover'],
      element.attributes['_src'],
      element.attributes['srcs'],
      element.attributes['src'],
    ];
    for (final candidate in candidates) {
      final normalized = normalizeShareText(candidate);
      if (normalized != null) {
        return normalized;
      }
    }
  }
  return null;
}

String? _readScriptString(String html, List<String> keys) {
  for (final key in keys) {
    final patterns = <RegExp>[
      RegExp(
        '(?:var|let|const)\\s+${RegExp.escape(key)}\\s*=\\s*("([^"\\\\]|\\\\.)*"|\'([^\'\\\\]|\\\\.)*\')',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        '${RegExp.escape(key)}\\s*:\\s*("([^"\\\\]|\\\\.)*"|\'([^\'\\\\]|\\\\.)*\')',
        caseSensitive: false,
        dotAll: true,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final literal = match?.group(1);
      final decoded = _decodeJavaScriptStringLiteral(literal);
      if (decoded != null) {
        return decoded;
      }
    }
  }
  return null;
}

String? _decodeJavaScriptStringLiteral(String? literal) {
  final normalizedLiteral = normalizeShareText(literal);
  if (normalizedLiteral == null || normalizedLiteral.length < 2) {
    return null;
  }
  final quote = normalizedLiteral[0];
  if ((quote != '"' && quote != '\'') ||
      normalizedLiteral[normalizedLiteral.length - 1] != quote) {
    return null;
  }
  if (quote == '"') {
    try {
      return normalizeShareText(jsonDecode(normalizedLiteral) as String?);
    } catch (_) {
      return null;
    }
  }

  final inner = normalizedLiteral
      .substring(1, normalizedLiteral.length - 1)
      .replaceAll('\\\\', '\\')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAllMapped(
        RegExp(r'\\x([0-9a-fA-F]{2})'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4})'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      );
  return normalizeShareText(inner);
}

String? _sanitizeWechatImageUrl(String? raw, {required Uri baseUrl}) {
  final normalized = normalizeShareText(raw);
  if (normalized == null) {
    return null;
  }

  final absolute = _resolveAbsoluteUrl(baseUrl, normalized);
  if (absolute == null) {
    return null;
  }

  var sanitized = absolute
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'#imgIndex=\d+.*$', caseSensitive: false), '');

  for (final marker in const ['<', '>', '"', "'", ' ']) {
    final index = sanitized.indexOf(marker);
    if (index > 0) {
      sanitized = sanitized.substring(0, index);
    }
  }

  final parsed = Uri.tryParse(sanitized);
  if (parsed != null &&
      parsed.scheme.toLowerCase() == 'http' &&
      parsed.host.toLowerCase().endsWith('qpic.cn')) {
    sanitized = (parsed.fragment.isEmpty
            ? parsed.replace(scheme: 'https')
            : parsed.replace(scheme: 'https', fragment: ''))
        .toString();
  } else if (parsed != null &&
      parsed.fragment.toLowerCase().startsWith('imgindex=')) {
    sanitized = parsed.replace(fragment: '').toString();
  }
  if (sanitized.endsWith('#')) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }

  return normalizeShareText(sanitized);
}

String? _resolveAbsoluteUrl(Uri baseUrl, String raw) {
  final parsed = Uri.tryParse(raw);
  if (parsed == null) {
    return null;
  }
  final resolved = parsed.hasScheme ? parsed : baseUrl.resolveUri(parsed);
  final scheme = resolved.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  return resolved.toString();
}
