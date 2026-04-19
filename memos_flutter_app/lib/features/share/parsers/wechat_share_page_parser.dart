import '../share_clip_models.dart';
import 'share_page_parser.dart';
import 'wechat_article_content_cleaner.dart';

class WechatSharePageParser implements SharePageParser {
  @override
  bool canParse(SharePageSnapshot snapshot) {
    final host = snapshot.host.toLowerCase();
    return host == 'mp.weixin.qq.com' || host.endsWith('.mp.weixin.qq.com');
  }

  @override
  SharePageParserResult parse(SharePageSnapshot snapshot) {
    final bridge = snapshot.bridgeData;
    final rawWechatHtml = bridge['wechatContentHtml']?.toString();
    final fallbackText =
        bridge['wechatTextContent']?.toString() ??
        bridge['textContent']?.toString();
    final cleaned = cleanWechatArticleContent(
      rawHtml: rawWechatHtml ?? bridge['contentHtml']?.toString(),
      fallbackTextContent: fallbackText,
      fallbackExcerpt: bridge['excerpt']?.toString(),
      articleTitle: bridge['articleTitle']?.toString(),
    );

    final contentHtml = normalizeShareText(cleaned.contentHtml);
    final textContent = normalizeShareText(cleaned.textContent);
    final excerpt = _resolveWechatExcerpt(
      normalizeShareText(cleaned.excerpt),
      textContent,
    );
    final pageKind =
        ((contentHtml ?? '').isNotEmpty || (textContent ?? '').length >= 80)
        ? SharePageKind.article
        : SharePageKind.unknown;

    return SharePageParserResult(
      pageKind: pageKind,
      title:
          normalizeShareText(bridge['articleTitle']?.toString()) ??
          normalizeShareText(bridge['pageTitle']?.toString()),
      excerpt: excerpt,
      contentHtml: contentHtml,
      textContent: textContent,
      siteName:
          normalizeShareText(bridge['wechatAccountName']?.toString()) ??
          normalizeShareText(bridge['siteName']?.toString()) ??
          '\u5fae\u4fe1\u516c\u4f17\u5e73\u53f0',
      sourceAvatarUrl: normalizeShareText(
        bridge['wechatAccountAvatar']?.toString(),
      ),
      byline:
          normalizeShareText(bridge['wechatAuthor']?.toString()) ??
          normalizeShareText(bridge['byline']?.toString()),
      authorAvatarUrl: normalizeShareText(
        bridge['wechatAuthorAvatar']?.toString(),
      ),
      leadImageUrl: normalizeShareText(bridge['leadImageUrl']?.toString()),
      parserTag: 'wechat',
    );
  }
}

String? _resolveWechatExcerpt(String? excerpt, String? textContent) {
  final normalizedExcerpt = normalizeShareText(excerpt);
  if (normalizedExcerpt == null) return null;
  final normalizedText = normalizeShareText(textContent);
  if (normalizedText == null) return normalizedExcerpt;

  final excerptFingerprint = _normalizeWechatCompareText(normalizedExcerpt);
  final textFingerprint = _normalizeWechatCompareText(normalizedText);
  if (excerptFingerprint.isEmpty || textFingerprint.isEmpty) {
    return normalizedExcerpt;
  }
  if (textFingerprint.startsWith(excerptFingerprint)) {
    return null;
  }
  if (excerptFingerprint.length >= 24 &&
      textFingerprint.contains(excerptFingerprint)) {
    return null;
  }
  return normalizedExcerpt;
}

String _normalizeWechatCompareText(String value) {
  return value.replaceAll(RegExp(r'\s+'), '');
}
