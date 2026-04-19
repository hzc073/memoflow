import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../share_clip_models.dart';

class WechatArticleContentCleanupResult {
  const WechatArticleContentCleanupResult({
    this.contentHtml,
    this.textContent,
    this.excerpt,
  });

  final String? contentHtml;
  final String? textContent;
  final String? excerpt;
}

WechatArticleContentCleanupResult cleanWechatArticleContent({
  required String? rawHtml,
  String? fallbackTextContent,
  String? fallbackExcerpt,
  String? articleTitle,
}) {
  final normalizedHtml = normalizeShareText(rawHtml);
  if (normalizedHtml == null) {
    final cleanedText = _normalizeText(fallbackTextContent);
    return WechatArticleContentCleanupResult(
      textContent: cleanedText,
      excerpt: _resolveExcerpt(cleanedText, fallbackExcerpt),
    );
  }

  var fragment = html_parser.parseFragment(normalizedHtml);
  final focusedHtml = _extractPreferredWechatArticleHtml(fragment);
  if (focusedHtml != null) {
    fragment = html_parser.parseFragment(focusedHtml);
  }
  _promoteWechatLazyImageSources(fragment);
  _removeBrokenWechatImageTextTails(fragment);
  _removeKnownWechatNoise(fragment);
  _unwrapRedundantInlineTags(fragment);
  _removeLeadingRepeatedWechatTitle(fragment, articleTitle);
  _trimWechatLeadingNoise(fragment);
  _trimWechatTrailingNoise(fragment);
  _removeEmptyElements(fragment);

  final cleanedHtml = normalizeShareText(
    fragment.nodes.map(_serializeNodeHtml).join(),
  );
  final cleanedText = _normalizeText(fragment.text);

  return WechatArticleContentCleanupResult(
    contentHtml: cleanedHtml,
    textContent: cleanedText,
    excerpt: _resolveExcerpt(cleanedText, fallbackExcerpt),
  );
}

const List<String> _wechatPreferredContentSelectors = [
  '#js_content',
  '.rich_media_content',
];

const List<String> _wechatNoiseSelectors = [
  'script',
  'style',
  'noscript',
  'iframe',
  'mp-common-profile',
  'qqmusic',
  '.js_ad_link',
  '.original_area_primary',
  '.reward_area',
  '.reward_qrcode_area',
  '.profile_container',
  '.wx_profile_card_inner',
  '.wx_profile_card',
  '.js_profile_container',
  '.js_profile_qrcode',
  '#js_tags',
  '#js_pc_qr_code',
  '#js_share_content',
  '#js_preview_reward_author',
  '#js_read_area3',
  '#js_more_article',
  '#js_article_card',
  '#js_follow_card',
  '#js_copyright_info',
  '#activity-name',
  '.rich_media_title',
  '#meta_content',
  '.rich_media_meta_list',
  '.rich_media_meta',
  '#publish_time',
  '#js_publish_time',
  '#js_tag_name',
  '#js_article_desc',
  '.rich_media_area_extra',
  '.rich_media_extra',
];

const Set<String> _inlineTagsToUnwrap = {'span', 'font'};
const Set<String> _voidOrMediaTags = {'br', 'hr', 'img'};
const Set<String> _wechatLazyImageAttributes = {
  'data-src',
  'data-lazy-src',
  'data-actualsrc',
  'data-original',
  'data-backsrc',
  'data-url',
  'data-imgsrc',
  'data-origin-src',
  'data-cover',
  '_src',
  'srcs',
};
final RegExp _wechatBrokenImageTailPattern = RegExp(
  r'''#imgIndex=\d+(?:[^<>\s"']*)?(?:\s+(?:alt|title)=["'][^"']*["'])?\s*>?''',
  caseSensitive: false,
);
const Set<String> _wechatPromoKeywords = {
  '点击小程序',
  '立即订阅',
  '拼团',
  '后台回复',
  '预约直播',
  '点亮',
  '在看',
  '分享',
  '星标',
  '教程',
};
const List<String> _wechatHardStopPhrases = [
  '点击小程序，立即订阅',
  '可直接参与拼团',
  '24小时内拼团不成功自动退款',
  '苹果用户后台回复',
  '点亮「在看」',
  '点亮“在看”',
  '「在看」+「分享」',
  '“在看”+“分享”',
  '作 者 /',
  '插 画 /',
  '运 营 /',
  '主 编 /',
  '⭐星标⭐',
  '我特意做了教程',
  '每一个「在看」我都当成喜欢',
  'end.',
  'p.s.',
];
const List<String> _wechatLeadingNoisePhrases = [
  '预约直播',
  '活出自己',
  '点击上方',
  '点击下方',
  '👇',
];

String? _extractPreferredWechatArticleHtml(dom.DocumentFragment fragment) {
  for (final selector in _wechatPreferredContentSelectors) {
    final candidate = fragment.querySelector(selector);
    final html = candidate?.innerHtml.trim() ?? '';
    if (html.isNotEmpty) {
      return html;
    }
  }
  return null;
}

void _promoteWechatLazyImageSources(dom.DocumentFragment fragment) {
  for (final image in fragment.querySelectorAll('img')) {
    final dimensions = _resolveWechatImageDimensions(image);
    if (dimensions.width != null) {
      image.attributes['width'] = dimensions.width!;
    }
    if (dimensions.height != null) {
      image.attributes['height'] = dimensions.height!;
    }
    final resolved = _resolveWechatImageSource(image);
    if (resolved != null) {
      image.attributes['src'] = resolved;
    }
    for (final attribute in _wechatLazyImageAttributes) {
      image.attributes.remove(attribute);
    }
  }
}

class _WechatImageDimensions {
  const _WechatImageDimensions({this.width, this.height});

  final String? width;
  final String? height;
}

_WechatImageDimensions _resolveWechatImageDimensions(dom.Element image) {
  final width =
      _normalizeWechatHtmlLength(image.attributes['width']) ??
      _normalizeWechatNumericLength(image.attributes['data-width']) ??
      _normalizeWechatNumericLength(image.attributes['data-w']);
  final explicitHeight = _normalizeWechatHtmlLength(image.attributes['height']);
  final dataHeight = _normalizeWechatNumericLength(
    image.attributes['data-height'],
  );
  var height = explicitHeight ?? dataHeight;
  if (height == null && width != null && !width.endsWith('%')) {
    final ratio = _parseWechatPositiveDouble(image.attributes['data-ratio']);
    final widthValue = double.tryParse(width);
    if (ratio != null && widthValue != null && widthValue > 0) {
      height = _formatWechatLength(widthValue * ratio);
    }
  }
  return _WechatImageDimensions(width: width, height: height);
}

String? _normalizeWechatHtmlLength(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)(%|px)?$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) return null;
  final parsed = double.tryParse(match.group(1)!);
  if (parsed == null || parsed <= 0) return null;
  final unit = (match.group(2) ?? '').toLowerCase();
  final normalized = _formatWechatLength(parsed);
  return unit == '%' ? '$normalized%' : normalized;
}

String? _normalizeWechatNumericLength(String? value) {
  final parsed = _parseWechatPositiveDouble(value);
  if (parsed == null) return null;
  return _formatWechatLength(parsed);
}

double? _parseWechatPositiveDouble(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

String _formatWechatLength(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.01) {
    return rounded.toInt().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

String? _resolveWechatImageSource(dom.Element image) {
  final candidates = <String?>[
    image.attributes['data-src'],
    image.attributes['data-lazy-src'],
    image.attributes['data-actualsrc'],
    image.attributes['data-original'],
    image.attributes['data-backsrc'],
    image.attributes['data-url'],
    image.attributes['data-imgsrc'],
    image.attributes['data-origin-src'],
    image.attributes['data-cover'],
    image.attributes['_src'],
    image.attributes['srcs'],
    image.attributes['src'],
  ];
  String? fallback;
  for (final value in candidates) {
    final normalized = normalizeShareText(value);
    if (normalized == null) continue;
    final sanitized = _sanitizeWechatImageUrl(normalized);
    fallback ??= sanitized;
    if (!normalized.toLowerCase().startsWith('data:')) {
      return sanitized;
    }
  }
  return fallback;
}

String _sanitizeWechatImageUrl(String raw) {
  var sanitized = _decodeWechatHtmlEntities(raw.trim());
  sanitized = sanitized.replaceAll(
    RegExp(r'#imgIndex=\d+.*$', caseSensitive: false),
    '',
  );
  for (final marker in const ['<', '>', '"', "'", ' ']) {
    final index = sanitized.indexOf(marker);
    if (index > 0) {
      sanitized = sanitized.substring(0, index);
    }
  }
  final uri = Uri.tryParse(sanitized);
  if (uri != null && uri.fragment.toLowerCase().startsWith('imgindex=')) {
    sanitized = uri.replace(fragment: '').toString();
  }
  final reparsed = Uri.tryParse(sanitized);
  if (reparsed != null &&
      reparsed.scheme.toLowerCase() == 'http' &&
      reparsed.host.toLowerCase().endsWith('qpic.cn')) {
    sanitized = reparsed.replace(scheme: 'https').toString();
  }
  return sanitized.replaceAll(
    RegExp(r'#imgIndex=\d+$', caseSensitive: false),
    '',
  );
}

String _decodeWechatHtmlEntities(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

void _removeBrokenWechatImageTextTails(dom.Node root) {
  for (final child in root.nodes.toList(growable: false)) {
    _removeBrokenWechatImageTextTails(child);
  }

  if (root is! dom.Text) return;
  final original = root.text;
  final cleaned = original.replaceAll(_wechatBrokenImageTailPattern, '');
  if (cleaned == original) return;
  if (_normalizeText(cleaned) == null) {
    root.remove();
    return;
  }
  root.text = cleaned;
}

void _removeKnownWechatNoise(dom.DocumentFragment fragment) {
  for (final selector in _wechatNoiseSelectors) {
    for (final element
        in fragment.querySelectorAll(selector).toList(growable: false)) {
      element.remove();
    }
  }

  for (final element
      in fragment.querySelectorAll('*').toList(growable: false)) {
    final style = (element.attributes['style'] ?? '').toLowerCase();
    final ariaHidden = (element.attributes['aria-hidden'] ?? '').toLowerCase();
    if (style.contains('display:none') ||
        style.contains('visibility:hidden') ||
        ariaHidden == 'true') {
      element.remove();
    }
  }
}

void _unwrapRedundantInlineTags(dom.Node root) {
  for (final child in root.nodes.toList(growable: false)) {
    _unwrapRedundantInlineTags(child);
  }

  if (root is! dom.Element) return;
  final tag = root.localName?.toLowerCase();
  if (tag == null || !_inlineTagsToUnwrap.contains(tag)) return;
  if (root.attributes.isNotEmpty) return;

  final replacement = dom.DocumentFragment();
  root.reparentChildren(replacement);
  root.replaceWith(replacement);
}

void _removeLeadingRepeatedWechatTitle(
  dom.DocumentFragment fragment,
  String? articleTitle,
) {
  final normalizedTitle = _normalizeCompareText(articleTitle);
  if (normalizedTitle == null) {
    return;
  }

  final parent = _effectiveTrimParent(fragment);
  final nodes = parent.nodes
      .where(_containsMeaningfulContent)
      .toList(growable: false);
  if (nodes.isEmpty) {
    return;
  }

  final firstNode = nodes.first;
  final firstNodeText = _normalizeCompareText(_normalizedNodeText(firstNode));
  if (firstNodeText == normalizedTitle) {
    firstNode.remove();
  }
}

void _trimWechatLeadingNoise(dom.DocumentFragment fragment) {
  final parent = _effectiveTrimParent(fragment);
  final nodes = parent.nodes.toList(growable: false);
  for (final node in nodes) {
    if (!_shouldTrimLeadingNode(node)) break;
    node.remove();
  }
}

void _trimWechatTrailingNoise(dom.DocumentFragment fragment) {
  final parent = _effectiveTrimParent(fragment);
  final nodes = parent.nodes
      .where(_containsMeaningfulContent)
      .toList(growable: false);
  if (nodes.isEmpty) return;

  for (var index = 0; index < nodes.length; index++) {
    final text = _normalizedNodeText(nodes[index]);
    if (_shouldHardStopAt(text)) {
      for (
        var removalIndex = index;
        removalIndex < nodes.length;
        removalIndex++
      ) {
        nodes[removalIndex].remove();
      }
      return;
    }
  }

  for (var index = nodes.length - 1; index >= 0; index--) {
    if (!_shouldTrimTrailingNode(nodes[index])) break;
    nodes[index].remove();
  }
}

dom.Node _effectiveTrimParent(dom.DocumentFragment fragment) {
  dom.Node current = fragment;
  while (current.nodes.length == 1) {
    final child = current.nodes.first;
    if (child is! dom.Element) break;
    final tag = child.localName?.toLowerCase();
    if (tag != 'div' && tag != 'section' && tag != 'article') break;
    current = child;
  }
  return current;
}

bool _shouldTrimLeadingNode(dom.Node node) {
  final text = _normalizedNodeText(node);
  if (text.isEmpty) {
    return _isMostlyDecorativeMedia(node);
  }
  if (text.length > 72) return false;
  return _wechatLeadingNoisePhrases.any(text.contains) ||
      (_containsPromoKeyword(text) && text.contains('👇'));
}

bool _shouldTrimTrailingNode(dom.Node node) {
  final text = _normalizedNodeText(node);
  if (text.isEmpty) {
    return _isMostlyDecorativeMedia(node);
  }
  if (_shouldHardStopAt(text)) return true;
  if (text.length > 120) return false;
  return _containsPromoKeyword(text);
}

bool _shouldHardStopAt(String text) {
  if (text.isEmpty) return false;
  return _wechatHardStopPhrases.any(text.contains) ||
      (text.contains('在看') && text.contains('分享')) ||
      (text.contains('作者') && text.contains('主编'));
}

bool _containsPromoKeyword(String text) {
  var matches = 0;
  for (final keyword in _wechatPromoKeywords) {
    if (text.contains(keyword)) {
      matches++;
      if (matches >= 2) return true;
    }
  }
  return false;
}

bool _containsMeaningfulContent(dom.Node node) {
  if (_normalizedNodeText(node).isNotEmpty) return true;
  return node is dom.Element && node.querySelector('img') != null;
}

bool _isMostlyDecorativeMedia(dom.Node node) {
  if (node is! dom.Element) return false;
  final text = _normalizedNodeText(
    node,
  ).replaceAll('👇', '').replaceAll('↑', '').replaceAll('↓', '').trim();
  return text.isEmpty && node.querySelector('img') != null;
}

void _removeEmptyElements(dom.Node root) {
  for (final child in root.nodes.toList(growable: false)) {
    _removeEmptyElements(child);
  }

  if (root is! dom.Element) return;
  final tag = root.localName?.toLowerCase();
  if (tag == null || _voidOrMediaTags.contains(tag)) return;
  if (root.querySelector('img') != null) return;
  if (_normalizedNodeText(root).isEmpty) {
    root.remove();
  }
}

String? _resolveExcerpt(String? cleanedText, String? fallbackExcerpt) {
  final excerpt = normalizeShareText(fallbackExcerpt);
  if (excerpt != null) return excerpt;
  if (cleanedText == null) return null;
  if (cleanedText.length <= 140) return cleanedText;
  return '${cleanedText.substring(0, 140).trimRight()}...';
}

String _normalizedNodeText(dom.Node node) => _normalizeText(node.text) ?? '';

String _serializeNodeHtml(dom.Node node) {
  if (node is dom.Element) return node.outerHtml;
  if (node is dom.DocumentFragment) return node.outerHtml;
  return node.text ?? '';
}

String? _normalizeCompareText(String? value) {
  final normalized = _normalizeText(value);
  if (normalized == null) return null;
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _normalizeText(String? value) {
  if (value == null) return null;
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}
