import '../share_clip_models.dart';
import 'share_page_parser.dart';

class CoolapkSharePageParser implements SharePageParser {
  @override
  bool canParse(SharePageSnapshot snapshot) {
    final host = snapshot.host.toLowerCase();
    return host == 'coolapk.com' || host.endsWith('.coolapk.com');
  }

  @override
  SharePageParserResult parse(SharePageSnapshot snapshot) {
    final bridge = snapshot.bridgeData;
    final contentHtml =
        normalizeShareText(bridge['coolapkContentHtml']?.toString()) ??
        normalizeShareText(bridge['contentHtml']?.toString());
    final textContent =
        normalizeShareText(bridge['coolapkTextContent']?.toString()) ??
        normalizeShareText(bridge['textContent']?.toString());
    final pageKind =
        ((contentHtml ?? '').isNotEmpty || (textContent ?? '').length >= 80)
        ? SharePageKind.article
        : SharePageKind.unknown;

    return SharePageParserResult(
      pageKind: pageKind,
      title:
          normalizeShareText(bridge['articleTitle']?.toString()) ??
          normalizeShareText(bridge['pageTitle']?.toString()),
      excerpt: normalizeShareText(bridge['excerpt']?.toString()),
      contentHtml: contentHtml,
      textContent: textContent,
      siteName:
          normalizeShareText(bridge['coolapkSiteName']?.toString()) ??
          normalizeShareText(bridge['siteName']?.toString()) ??
          '\u9177\u5b89',
      sourceAvatarUrl:
          normalizeShareText(bridge['coolapkSiteIconUrl']?.toString()) ??
          normalizeShareText(bridge['siteIconUrl']?.toString()),
      byline:
          normalizeShareText(bridge['coolapkAuthor']?.toString()) ??
          normalizeShareText(bridge['byline']?.toString()),
      authorAvatarUrl: normalizeShareText(
        bridge['coolapkAuthorAvatar']?.toString(),
      ),
      leadImageUrl:
          normalizeShareText(bridge['coolapkLeadImageUrl']?.toString()) ??
          normalizeShareText(bridge['leadImageUrl']?.toString()),
      parserTag: 'coolapk',
    );
  }
}
