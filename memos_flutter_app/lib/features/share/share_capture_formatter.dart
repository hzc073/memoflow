import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../data/models/memo_clip_card_metadata.dart';
import 'share_clip_models.dart';
import 'share_handler.dart';
import 'share_inline_image_content.dart';

const Set<String> _blockedHtmlTags = {'script', 'style', 'noscript'};

const Set<String> _allowedHtmlTags = {
  'a',
  'blockquote',
  'br',
  'code',
  'del',
  'details',
  'em',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'img',
  'input',
  'li',
  'ol',
  'p',
  'pre',
  'summary',
  'span',
  'strong',
  'sub',
  'sup',
  'table',
  'tbody',
  'td',
  'th',
  'thead',
  'tr',
  'ul',
};

const Map<String, Set<String>> _allowedHtmlAttributes = {
  'a': {'href', 'title'},
  'img': {'src', 'alt', 'title', 'width', 'height'},
  'code': {'class'},
  'pre': {'class'},
  'span': {'class'},
  'li': {'class'},
  'ul': {'class'},
  'ol': {'class'},
  'p': {'class'},
  'details': {'open'},
  'input': {'type', 'checked', 'disabled'},
};

const Set<String> _voidHtmlTags = {'br', 'hr', 'img', 'input'};

ShareComposeRequest buildShareComposeRequestFromCapture({
  required ShareCaptureResult result,
  required SharePayload payload,
  List<String> attachmentPaths = const [],
  List<ShareAttachmentSeed> initialAttachmentSeeds = const [],
  String? contentHtmlOverride,
  String? userMessage,
}) {
  final text = buildShareCaptureMemoText(
    result: result,
    payload: payload,
    contentHtmlOverride: contentHtmlOverride,
    allowedLocalImageUrls: initialAttachmentSeeds
        .where((attachment) => attachment.shareInlineImage)
        .map((attachment) => shareInlineLocalUrlFromPath(attachment.filePath))
        .where((url) => url.isNotEmpty)
        .toSet(),
  );
  return ShareComposeRequest(
    text: text,
    selectionOffset: text.length,
    attachmentPaths: attachmentPaths,
    initialAttachmentSeeds: initialAttachmentSeeds,
    clipMetadataDraft: buildShareClipMetadataDraft(result: result),
    userMessage: userMessage,
  );
}

ShareComposeRequest buildLinkOnlyComposeRequest(SharePayload payload) {
  final draft = buildShareTextDraft(payload);
  return ShareComposeRequest(
    text: draft.text,
    selectionOffset: draft.selectionOffset,
  );
}

String buildLinkOnlyMemoText(
  SharePayload payload, {
  List<String> tags = const [],
}) {
  final text = buildLinkOnlyComposeRequest(payload).text.trimRight();
  final normalizedTags = tags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
  if (normalizedTags.isEmpty) return text;
  if (text.isEmpty) return normalizedTags.join(' ');
  return '$text\n\n${normalizedTags.join(' ')}';
}

String buildShareCaptureMemoText({
  required ShareCaptureResult result,
  required SharePayload payload,
  String? contentHtmlOverride,
  Set<String> allowedLocalImageUrls = const <String>{},
}) {
  if (result.pageKind == SharePageKind.video) {
    return _buildShareVideoMemoText(result: result, payload: payload);
  }

  final resolvedUrl = _resolveFinalUrl(result.finalUrl);
  final title = _resolveTitle(
    result: result,
    payload: payload,
    url: resolvedUrl,
  );
  final excerpt = _normalizeWhitespace(result.excerpt);
  final body = _buildMarkdownBody(
    result: result,
    baseUrl: resolvedUrl,
    contentHtmlOverride: contentHtmlOverride,
    allowedLocalImageUrls: allowedLocalImageUrls,
  );
  final articleBody = _resolveArticleBody(
    body: body,
    excerpt: excerpt,
    fallbackUrl: resolvedUrl,
  );
  final buffer = StringBuffer()..writeln('# $title');
  if (articleBody.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(articleBody);
  }
  buffer
    ..writeln()
    ..writeln(buildThirdPartyShareMemoMarker());
  return buffer.toString().trimRight();
}

ShareClipMetadataDraft? buildShareClipMetadataDraft({
  required ShareCaptureResult result,
}) {
  if (!result.isSuccess || result.pageKind != SharePageKind.article) {
    return null;
  }
  final resolvedUrl = _resolveFinalUrl(result.finalUrl);
  final sourceName =
      _normalizeWhitespace(result.siteName) ??
      _normalizeWhitespace(result.pageTitle) ??
      resolvedUrl.host;
  return ShareClipMetadataDraft(
    clipKind: MemoClipKind.article,
    platform: _resolveClipPlatform(result.siteParserTag, resolvedUrl),
    sourceName: sourceName,
    sourceAvatarUrl: _normalizeClipImageUrl(result.sourceAvatarUrl) ?? '',
    authorName: _sanitizeClipAuthorName(result.byline) ?? '',
    authorAvatarUrl: _normalizeClipImageUrl(result.authorAvatarUrl) ?? '',
    sourceUrl: resolvedUrl.toString(),
    leadImageUrl: _resolveClipLeadImageUrl(result, resolvedUrl) ?? '',
    parserTag: (result.siteParserTag ?? '').trim(),
  );
}

String _buildShareVideoMemoText({
  required ShareCaptureResult result,
  required SharePayload payload,
}) {
  final resolvedUrl = _resolveFinalUrl(result.finalUrl);
  final title = _resolveTitle(
    result: result,
    payload: payload,
    url: resolvedUrl,
  );
  final excerpt = _normalizeWhitespace(result.excerpt);
  final buffer = StringBuffer()
    ..writeln('# $title')
    ..writeln();
  buffer.writeln(_buildMarkdownLink(title, resolvedUrl));
  if (excerpt != null) {
    buffer
      ..writeln()
      ..writeln('> $excerpt');
  }
  return buffer.toString().trimRight();
}

String _buildMarkdownLink(String label, Uri url) {
  return '[${_escapeMarkdownText(label)}](${url.toString()})';
}

String _resolveTitle({
  required ShareCaptureResult result,
  required SharePayload payload,
  required Uri url,
}) {
  return _normalizeWhitespace(result.articleTitle) ??
      _normalizeWhitespace(payload.title) ??
      _normalizeWhitespace(result.pageTitle) ??
      url.host;
}

MemoClipPlatform _resolveClipPlatform(String? parserTag, Uri url) {
  final normalizedParserTag = (parserTag ?? '').trim().toLowerCase();
  switch (normalizedParserTag) {
    case 'wechat':
      return MemoClipPlatform.wechat;
    case 'xiaohongshu':
      return MemoClipPlatform.xiaohongshu;
    case 'bilibili':
      return MemoClipPlatform.bilibili;
    case 'coolapk':
      return MemoClipPlatform.coolapk;
  }
  final host = url.host.toLowerCase();
  if (host == 'mp.weixin.qq.com' || host.endsWith('.mp.weixin.qq.com')) {
    return MemoClipPlatform.wechat;
  }
  if (host.contains('xiaohongshu.com') || host.contains('xhslink.com')) {
    return MemoClipPlatform.xiaohongshu;
  }
  if (host.contains('bilibili.com') || host.contains('b23.tv')) {
    return MemoClipPlatform.bilibili;
  }
  if (host == 'coolapk.com' || host.endsWith('.coolapk.com')) {
    return MemoClipPlatform.coolapk;
  }
  return MemoClipPlatform.web;
}

Uri _resolveFinalUrl(Uri url) {
  if (url.hasScheme && url.hasAuthority) return url;
  final normalized = Uri.tryParse(url.toString());
  if (normalized != null && normalized.hasScheme && normalized.hasAuthority) {
    return normalized;
  }
  return Uri.parse('https://${url.toString()}');
}

String _resolveArticleBody({
  required String? body,
  required String? excerpt,
  required Uri fallbackUrl,
}) {
  final normalizedBody = (body ?? '').trim();
  if (normalizedBody.isNotEmpty) {
    return normalizedBody;
  }
  final normalizedExcerpt = (excerpt ?? '').trim();
  if (normalizedExcerpt.isNotEmpty) {
    return normalizedExcerpt;
  }
  return fallbackUrl.toString();
}

String? _sanitizeClipAuthorName(String? value) {
  final normalized = _normalizeWhitespace(value);
  if (normalized == null) return null;
  if (_looksLikeClipTimestampLabel(normalized)) {
    return null;
  }
  return normalized;
}

String? _resolveClipLeadImageUrl(ShareCaptureResult result, Uri resolvedUrl) {
  final platform = _resolveClipPlatform(result.siteParserTag, resolvedUrl);
  if (platform == MemoClipPlatform.wechat) {
    return null;
  }
  return _normalizeClipImageUrl(result.leadImageUrl);
}

String? _normalizeClipImageUrl(String? value) {
  final normalized = _normalizeWhitespace(value);
  if (normalized == null) return null;
  final uri = Uri.tryParse(normalized);
  if (uri != null &&
      uri.scheme.toLowerCase() == 'http' &&
      uri.host.toLowerCase().endsWith('qpic.cn')) {
    return uri.replace(scheme: 'https').toString();
  }
  if (uri != null &&
      uri.scheme.toLowerCase() == 'http' &&
      uri.host.toLowerCase().endsWith('coolapk.com')) {
    return uri.replace(scheme: 'https').toString();
  }
  return normalized;
}

bool _looksLikeClipTimestampLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return false;
  return RegExp(
        r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?$',
      ).hasMatch(normalized) ||
      RegExp(r'^\d{1,2}\s*月\s*\d{1,2}\s*日').hasMatch(normalized) ||
      RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$').hasMatch(normalized);
}

String? _buildMarkdownBody({
  required ShareCaptureResult result,
  required Uri baseUrl,
  String? contentHtmlOverride,
  Set<String> allowedLocalImageUrls = const <String>{},
}) {
  final explicitTextOnly =
      contentHtmlOverride != null && contentHtmlOverride.trim().isEmpty;
  final rawHtml = (contentHtmlOverride ?? result.contentHtml ?? '').trim();
  if (!explicitTextOnly && rawHtml.isNotEmpty) {
    return _sanitizeFragmentToMarkdown(
      rawHtml,
      baseUrl,
      normalizeWechatImageWidths: _shouldNormalizeWechatImageWidths(result),
      allowedLocalImageUrls: allowedLocalImageUrls,
    );
  }

  if (explicitTextOnly) {
    final htmlTextFallback = _buildHtmlTextFallback(result.contentHtml);
    if (htmlTextFallback != null) {
      return htmlTextFallback;
    }
  }

  final fallback = _buildTextFallback(result.textContent);
  if (fallback.isEmpty) return null;
  return fallback;
}

String? _buildHtmlTextFallback(String? rawHtml) {
  final normalizedHtml = (rawHtml ?? '').trim();
  if (normalizedHtml.isEmpty) {
    return null;
  }
  final fragment = html_parser.parseFragment(normalizedHtml);
  final blocks = _collectPlainTextBlocks(fragment.nodes);
  final text = _cleanupGeneratedMarkdown(blocks.join('\n\n'));
  return text.isEmpty ? null : text;
}

String? _sanitizeFragmentToMarkdown(
  String rawHtml,
  Uri baseUrl, {
  bool normalizeWechatImageWidths = false,
  Set<String> allowedLocalImageUrls = const <String>{},
}) {
  final fragment = html_parser.parseFragment(rawHtml);
  _absolutizeAttribute(
    fragment,
    tagName: 'a',
    attribute: 'href',
    baseUrl: baseUrl,
  );
  _absolutizeAttribute(
    fragment,
    tagName: 'img',
    attribute: 'src',
    baseUrl: baseUrl,
  );
  if (normalizeWechatImageWidths) {
    _normalizeWechatImageDisplayWidths(fragment);
  }
  final sanitized = _sanitizeFragmentToHtml(
    fragment,
    allowedLocalImageUrls: allowedLocalImageUrls,
  ).trim();
  if (sanitized.isEmpty) return null;
  final markdown = _convertSanitizedHtmlToMarkdown(sanitized);
  if (markdown.isEmpty) return null;
  return markdown;
}

bool _shouldNormalizeWechatImageWidths(ShareCaptureResult result) {
  final parserTag = (result.siteParserTag ?? '').trim().toLowerCase();
  if (parserTag == 'wechat' || parserTag == 'wechat-static') {
    return true;
  }
  final host = result.finalUrl.host.toLowerCase();
  return host == 'mp.weixin.qq.com' || host.endsWith('.mp.weixin.qq.com');
}

void _normalizeWechatImageDisplayWidths(dom.DocumentFragment fragment) {
  final measured = <(dom.Element, double)>[];
  var maxWidth = 0.0;

  for (final image in fragment.querySelectorAll('img')) {
    final width = _parseAbsoluteImageWidth(image.attributes['width']);
    if (width == null || width <= 0) {
      continue;
    }
    measured.add((image, width));
    if (width > maxWidth) {
      maxWidth = width;
    }
  }

  if (measured.isEmpty || maxWidth <= 0) {
    return;
  }

  for (final (image, width) in measured) {
    final percent = ((width / maxWidth) * 100).clamp(0.0, 100.0);
    image.attributes['width'] = percent >= 99.5
        ? '100%'
        : '${_formatImageHtmlLength(percent)}%';
    image.attributes.remove('height');
  }
}

double? _parseAbsoluteImageWidth(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.endsWith('%')) {
    return null;
  }
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)(px)?$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final parsed = double.tryParse(match.group(1)!);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

String _convertSanitizedHtmlToMarkdown(String sanitizedHtml) {
  final fragment = html_parser.parseFragment(sanitizedHtml);
  final blocks = _collectMarkdownBlocks(fragment.nodes);
  return _cleanupGeneratedMarkdown(blocks.join('\n\n'));
}

List<String> _collectPlainTextBlocks(List<dom.Node> nodes) {
  final blocks = <String>[];
  final inlineNodes = <dom.Node>[];

  void flushInlineNodes() {
    final text = _cleanupPlainText(_renderPlainTextInline(inlineNodes));
    inlineNodes.clear();
    if (text.isNotEmpty) {
      blocks.add(text);
    }
  }

  for (final node in nodes) {
    if (_isMarkdownBlockNode(node)) {
      flushInlineNodes();
      final block = _renderPlainTextBlock(node);
      if (block.isNotEmpty) {
        blocks.add(block);
      }
      continue;
    }
    inlineNodes.add(node);
  }

  flushInlineNodes();
  return blocks;
}

const Set<String> _markdownBlockTags = {
  'blockquote',
  'details',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'img',
  'li',
  'ol',
  'p',
  'pre',
  'summary',
  'table',
  'tbody',
  'thead',
  'tr',
  'ul',
};

List<String> _collectMarkdownBlocks(List<dom.Node> nodes) {
  final blocks = <String>[];
  final inlineNodes = <dom.Node>[];

  void flushInlineBuffer() {
    final text = _cleanupInlineMarkdown(_renderInlineMarkdown(inlineNodes));
    inlineNodes.clear();
    if (text.isNotEmpty) {
      blocks.add(text);
    }
  }

  for (final node in nodes) {
    if (_isMarkdownBlockNode(node)) {
      flushInlineBuffer();
      final block = _convertMarkdownBlock(node);
      if (block.isNotEmpty) {
        blocks.add(block);
      }
      continue;
    }
    inlineNodes.add(node);
  }

  flushInlineBuffer();
  return blocks;
}

bool _isMarkdownBlockNode(dom.Node node) {
  if (node is! dom.Element) return false;
  final tag = node.localName?.toLowerCase();
  return tag != null && _markdownBlockTags.contains(tag);
}

String _convertMarkdownBlock(dom.Node node) {
  if (node is dom.Text) {
    return _cleanupInlineMarkdown(_escapeMarkdownTextNode(node.text));
  }
  if (node is! dom.Element) {
    return _cleanupInlineMarkdown(_escapeMarkdownTextNode(node.text ?? ''));
  }

  final tag = node.localName?.toLowerCase();
  if (tag == null) return '';
  switch (tag) {
    case 'p':
      return _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      final level = int.tryParse(tag.substring(1)) ?? 1;
      final heading = _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
      if (heading.isEmpty) return '';
      return '${'#' * level} $heading';
    case 'blockquote':
      return _renderBlockquoteMarkdown(node);
    case 'ul':
      return _renderListMarkdown(node, ordered: false);
    case 'ol':
      return _renderListMarkdown(node, ordered: true);
    case 'pre':
      return _renderCodeBlockMarkdown(node);
    case 'img':
      return _renderImageMarkdown(node);
    case 'hr':
      return '---';
    case 'table':
      return _renderTableMarkdown(node);
    case 'details':
      return _collectMarkdownBlocks(node.nodes).join('\n\n').trim();
    case 'summary':
      final summary = _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
      return summary.isEmpty ? '' : '**$summary**';
    case 'li':
      return _renderListItemMarkdown(node, ordered: false, index: 1, depth: 0);
    case 'thead':
    case 'tbody':
    case 'tr':
      return _collectMarkdownBlocks(node.nodes).join('\n\n').trim();
  }

  return _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
}

String _renderInlineMarkdown(List<dom.Node> nodes) {
  final buffer = StringBuffer();
  for (var index = 0; index < nodes.length; index++) {
    buffer.write(
      _renderInlineMarkdownNode(nodes[index], siblings: nodes, index: index),
    );
  }
  return buffer.toString();
}

String _renderPlainTextInline(List<dom.Node> nodes) {
  final buffer = StringBuffer();
  for (final node in nodes) {
    buffer.write(_renderPlainTextInlineNode(node));
  }
  return buffer.toString();
}

String _renderInlineMarkdownNode(
  dom.Node node, {
  List<dom.Node>? siblings,
  int? index,
}) {
  if (node is dom.Text) {
    return _renderInlineTextNode(node.text, siblings: siblings, index: index);
  }
  if (node is! dom.Element) {
    return _renderInlineTextNode(
      node.text ?? '',
      siblings: siblings,
      index: index,
    );
  }

  final tag = node.localName?.toLowerCase();
  if (tag == null) return '';
  switch (tag) {
    case 'a':
      final href = node.attributes['href']?.trim();
      final label = _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
      if (href == null || href.isEmpty) return label;
      final resolvedLabel = label.isEmpty ? href : label;
      return '[${_escapeMarkdownText(resolvedLabel)}]($href)';
    case 'strong':
      final strong = _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
      return strong.isEmpty ? '' : '**$strong**';
    case 'em':
      final emphasis = _cleanupInlineMarkdown(
        _renderInlineMarkdown(node.nodes),
      );
      return emphasis.isEmpty ? '' : '*$emphasis*';
    case 'del':
      final deleted = _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
      return deleted.isEmpty ? '' : '~~$deleted~~';
    case 'code':
      return _wrapInlineCode(node.text);
    case 'img':
      return _renderImageMarkdown(node);
    case 'br':
      return '\\\n';
    case 'input':
      return _renderCheckboxMarkdown(node);
    case 'span':
    case 'sub':
    case 'sup':
      return _renderInlineMarkdown(node.nodes);
    case 'p':
      return _cleanupInlineMarkdown(_renderInlineMarkdown(node.nodes));
    default:
      return _renderInlineMarkdown(node.nodes);
  }
}

String _renderPlainTextBlock(dom.Node node) {
  if (node is dom.Text) {
    return _cleanupPlainText(node.text);
  }
  if (node is! dom.Element) {
    return _cleanupPlainText(node.text ?? '');
  }

  final tag = node.localName?.toLowerCase();
  if (tag == null) return '';
  switch (tag) {
    case 'img':
    case 'hr':
      return '';
    case 'ul':
      return _renderPlainTextList(node, ordered: false);
    case 'ol':
      return _renderPlainTextList(node, ordered: true);
    case 'li':
      return _renderPlainTextListItem(node, ordered: false, index: 1);
    case 'blockquote':
    case 'details':
    case 'thead':
    case 'tbody':
    case 'tr':
      return _cleanupGeneratedMarkdown(
        _collectPlainTextBlocks(node.nodes).join('\n\n'),
      );
    default:
      return _cleanupPlainText(_renderPlainTextInline(node.nodes));
  }
}

String _renderPlainTextInlineNode(dom.Node node) {
  if (node is dom.Text) {
    return node.text;
  }
  if (node is! dom.Element) {
    return node.text ?? '';
  }

  final tag = node.localName?.toLowerCase();
  if (tag == null) return '';
  switch (tag) {
    case 'br':
      return '\n';
    case 'img':
    case 'hr':
    case 'input':
      return '';
    case 'div':
    case 'section':
    case 'article':
      return _collectPlainTextBlocks(node.nodes).join('\n\n');
    default:
      return _renderPlainTextInline(node.nodes);
  }
}

String _renderPlainTextList(dom.Element list, {required bool ordered}) {
  final lines = <String>[];
  var index = 1;
  for (final child in list.children) {
    if (child.localName?.toLowerCase() != 'li') continue;
    final item = _renderPlainTextListItem(
      child,
      ordered: ordered,
      index: index,
    );
    if (item.isNotEmpty) {
      lines.add(item);
    }
    index++;
  }
  return lines.join('\n');
}

String _renderPlainTextListItem(
  dom.Element item, {
  required bool ordered,
  required int index,
}) {
  final text = _cleanupPlainText(_renderPlainTextInline(item.nodes));
  if (text.isEmpty) {
    return '';
  }
  final marker = ordered ? '$index. ' : '- ';
  return '$marker$text';
}

String _renderBlockquoteMarkdown(dom.Element element) {
  final content = _cleanupGeneratedMarkdown(
    _collectMarkdownBlocks(element.nodes).join('\n\n'),
  );
  if (content.isEmpty) return '';
  return content
      .split('\n')
      .map((line) => line.isEmpty ? '>' : '> $line')
      .join('\n');
}

String _renderListMarkdown(
  dom.Element list, {
  required bool ordered,
  int depth = 0,
}) {
  final lines = <String>[];
  var index = 1;
  for (final child in list.children) {
    if (child.localName?.toLowerCase() != 'li') continue;
    final item = _renderListItemMarkdown(
      child,
      ordered: ordered,
      index: index,
      depth: depth,
    );
    if (item.isNotEmpty) {
      lines.add(item);
    }
    index++;
  }
  return lines.join('\n');
}

String _renderListItemMarkdown(
  dom.Element item, {
  required bool ordered,
  required int index,
  required int depth,
}) {
  final inlineNodes = <dom.Node>[];
  final nestedLists = <dom.Element>[];
  for (final child in item.nodes) {
    final tag = child is dom.Element ? child.localName?.toLowerCase() : null;
    if (tag == 'ul' || tag == 'ol') {
      nestedLists.add(child as dom.Element);
      continue;
    }
    if (tag == 'p') {
      inlineNodes.addAll((child as dom.Element).nodes);
      inlineNodes.add(dom.Text(' '));
      continue;
    }
    inlineNodes.add(child);
  }

  final inline = _cleanupInlineMarkdown(
    _renderInlineMarkdown(inlineNodes).replaceAll('\\\n', ' '),
  );
  final marker = ordered ? '$index.' : '-';
  final indent = '  ' * depth;
  final lines = <String>[];
  lines.add(inline.isEmpty ? '$indent$marker' : '$indent$marker $inline');

  for (final nested in nestedLists) {
    final nestedMarkdown = _renderListMarkdown(
      nested,
      ordered: nested.localName?.toLowerCase() == 'ol',
      depth: depth + 1,
    );
    if (nestedMarkdown.isNotEmpty) {
      lines.add(nestedMarkdown);
    }
  }
  return lines.join('\n');
}

String _renderCodeBlockMarkdown(dom.Element element) {
  final language = _resolveCodeLanguage(element);
  final code = element.text.replaceAll('\r\n', '\n').trimRight();
  if (code.isEmpty) return '';
  return _wrapFencedCodeBlock(code, language: language);
}

String _resolveCodeLanguage(dom.Element element) {
  final classValue =
      element.attributes['class'] ??
      element.querySelector('code')?.attributes['class'] ??
      '';
  for (final token in classValue.split(RegExp(r'\s+'))) {
    final normalized = token.trim();
    if (normalized.startsWith('language-') && normalized.length > 9) {
      return normalized.substring(9);
    }
    if (normalized.startsWith('lang-') && normalized.length > 5) {
      return normalized.substring(5);
    }
  }
  return '';
}

String _wrapFencedCodeBlock(String code, {String language = ''}) {
  var fenceLength = 3;
  for (final match in RegExp(r'`+').allMatches(code)) {
    final length = match.group(0)?.length ?? 0;
    if (length >= fenceLength) {
      fenceLength = length + 1;
    }
  }
  final fence = '`' * fenceLength;
  final languageSuffix = language.trim();
  return '$fence$languageSuffix\n$code\n$fence';
}

String _wrapInlineCode(String raw) {
  final code = raw.replaceAll('\n', ' ');
  if (code.isEmpty) return '';
  var fenceLength = 1;
  for (final match in RegExp(r'`+').allMatches(code)) {
    final length = match.group(0)?.length ?? 0;
    if (length >= fenceLength) {
      fenceLength = length + 1;
    }
  }
  final fence = '`' * fenceLength;
  final padded = code.startsWith('`') || code.endsWith('`') ? ' $code ' : code;
  return '$fence$padded$fence';
}

String _renderImageMarkdown(dom.Element element) {
  final src = element.attributes['src']?.trim();
  if (src == null || src.isEmpty) return '';
  final altText =
      (element.attributes['alt'] ?? element.attributes['title'] ?? '').trim();
  final title = (element.attributes['title'] ?? '').trim();
  final width = _normalizeImageHtmlLength(element.attributes['width']);
  final height = _normalizeImageHtmlLength(element.attributes['height']);
  if (width != null || height != null) {
    final attributes = <String>[
      'src="${_escapeHtmlAttribute(src)}"',
      if (altText.isNotEmpty) 'alt="${_escapeHtmlAttribute(altText)}"',
      if (title.isNotEmpty) 'title="${_escapeHtmlAttribute(title)}"',
      if (width != null) 'width="${_escapeHtmlAttribute(width)}"',
      if (height != null) 'height="${_escapeHtmlAttribute(height)}"',
    ].join(' ');
    return '<img $attributes>';
  }
  final alt = _escapeMarkdownText(altText);
  if (title.isEmpty) {
    return '![$alt]($src)';
  }
  return '![$alt]($src "${title.replaceAll('"', r'\"')}")';
}

String? _normalizeImageHtmlLength(String? value) {
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
  final normalized = _formatImageHtmlLength(parsed);
  return unit == '%' ? '$normalized%' : normalized;
}

String _formatImageHtmlLength(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.01) {
    return rounded.toInt().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

String _renderCheckboxMarkdown(dom.Element element) {
  final checked = element.attributes.containsKey('checked');
  return checked ? '[x]' : '[ ]';
}

String _renderTableMarkdown(dom.Element table) {
  final rows = <List<String>>[];
  final headerFlags = <bool>[];
  for (final row in table.querySelectorAll('tr')) {
    final cells = <String>[];
    var hasHeader = false;
    for (final cell in row.children) {
      final tag = cell.localName?.toLowerCase();
      if (tag != 'th' && tag != 'td') continue;
      if (tag == 'th') hasHeader = true;
      final text = _cleanupInlineMarkdown(
        _renderInlineMarkdown(cell.nodes),
      ).replaceAll('|', r'\|').replaceAll('\n', '<br>');
      cells.add(text);
    }
    if (cells.isEmpty) continue;
    rows.add(cells);
    headerFlags.add(hasHeader);
  }
  if (rows.isEmpty) return '';

  var columnCount = 0;
  for (final row in rows) {
    if (row.length > columnCount) {
      columnCount = row.length;
    }
  }
  if (columnCount == 0) return '';
  for (final row in rows) {
    while (row.length < columnCount) {
      row.add('');
    }
  }

  final headerIndex = headerFlags.indexWhere((flag) => flag);
  final header = headerIndex >= 0
      ? rows.removeAt(headerIndex)
      : rows.removeAt(0);
  if (headerIndex >= 0) {
    headerFlags.removeAt(headerIndex);
  }
  final separator = List.filled(columnCount, '---');
  final lines = <String>[
    _formatMarkdownTableRow(header),
    _formatMarkdownTableRow(separator),
  ];
  for (final row in rows) {
    lines.add(_formatMarkdownTableRow(row));
  }
  return lines.join('\n');
}

String _formatMarkdownTableRow(List<String> cells) {
  return '| ${cells.join(' | ')} |';
}

final RegExp _inlineWhitespacePattern = RegExp(
  r'[ \t\n\r\f\v\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]+',
);
final RegExp _cjkSeparatedBySpacePattern = RegExp(
  r'([\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af])\s+([\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af])',
);
final RegExp _cjkBeforeOpeningPunctuationSpacePattern = RegExp(
  r'([\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af])\s+([（［｛〈《「『【〔〖〘〚])',
);
final RegExp _openingPunctuationBeforeCjkSpacePattern = RegExp(
  r'([（［｛〈《「『【〔〖〘〚])\s+([\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af])',
);
final RegExp _cjkBeforeClosingPunctuationSpacePattern = RegExp(
  r'([\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af])\s+([）］｝〉》」』】〕〗〙〛、，。．！？：；·])',
);
final RegExp _closingPunctuationBeforeCjkSpacePattern = RegExp(
  r'([）］｝〉》」』】〕〗〙〛、，。．！？：；·])\s+([\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af])',
);

String _cleanupInlineMarkdown(String text) {
  const softBreakPlaceholder = '__MEMOFLOW_SOFT_BREAK__';
  final normalized = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r' *\\\n *'), softBreakPlaceholder)
      .replaceAll(_inlineWhitespacePattern, ' ');
  final compacted = _compactCjkInlineSpacing(normalized).trim();
  return compacted.replaceAll(softBreakPlaceholder, '\\\n');
}

String _cleanupGeneratedMarkdown(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _cleanupPlainText(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _escapeMarkdownTextNode(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('*', r'\*')
      .replaceAll('_', r'\_')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]')
      .replaceAll('`', r'\`');
}

String _renderInlineTextNode(
  String value, {
  List<dom.Node>? siblings,
  int? index,
}) {
  final normalized = _normalizeInlineText(value);
  if (normalized.isEmpty) {
    return '';
  }
  if (!_isWhitespaceOnlyInlineText(value)) {
    return _escapeMarkdownTextNode(normalized);
  }
  if (siblings == null || index == null) {
    return ' ';
  }
  final previousChar = _neighborInlineBoundaryChar(
    siblings,
    startIndex: index - 1,
    step: -1,
  );
  final nextChar = _neighborInlineBoundaryChar(
    siblings,
    startIndex: index + 1,
    step: 1,
  );
  if (previousChar == null || nextChar == null) {
    return '';
  }
  return _shouldPreserveInlineSeparator(previousChar, nextChar) ? ' ' : '';
}

String _normalizeInlineText(String value) {
  return value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(_inlineWhitespacePattern, ' ');
}

bool _isWhitespaceOnlyInlineText(String value) {
  return _normalizeInlineText(value).trim().isEmpty;
}

String? _neighborInlineBoundaryChar(
  List<dom.Node> siblings, {
  required int startIndex,
  required int step,
}) {
  for (
    var index = startIndex;
    index >= 0 && index < siblings.length;
    index += step
  ) {
    final text = _meaningfulInlineText(siblings[index]);
    if (text.isEmpty) {
      continue;
    }
    return step < 0 ? _lastRuneAsString(text) : _firstRuneAsString(text);
  }
  return null;
}

String _meaningfulInlineText(dom.Node node) {
  if (node is dom.Element) {
    final tag = node.localName?.toLowerCase();
    if (tag == 'br' || tag == 'img' || tag == 'input') {
      return '';
    }
  }
  return _normalizeInlineText(node.text ?? '').trim();
}

bool _shouldPreserveInlineSeparator(String previousChar, String nextChar) {
  if ((_isCjkCharacter(previousChar) && _isCjkCharacter(nextChar)) ||
      (_isCjkCharacter(previousChar) &&
          _isOpeningInlinePunctuation(nextChar)) ||
      (_isClosingInlinePunctuation(previousChar) &&
          _isCjkCharacter(nextChar)) ||
      _isOpeningInlinePunctuation(previousChar) ||
      _isClosingInlinePunctuation(nextChar)) {
    return false;
  }
  return true;
}

bool _isCjkCharacter(String value) {
  final rune = value.runes.first;
  return (rune >= 0x3040 && rune <= 0x30FF) ||
      (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0xAC00 && rune <= 0xD7AF);
}

bool _isOpeningInlinePunctuation(String value) {
  return const {
    '（',
    '［',
    '｛',
    '〈',
    '《',
    '「',
    '『',
    '【',
    '〔',
    '〖',
    '〘',
    '〚',
  }.contains(value);
}

bool _isClosingInlinePunctuation(String value) {
  return const {
    '）',
    '］',
    '｝',
    '〉',
    '》',
    '」',
    '』',
    '】',
    '〕',
    '〗',
    '〙',
    '〛',
    '、',
    '，',
    '。',
    '．',
    '！',
    '？',
    '：',
    '；',
    '·',
  }.contains(value);
}

String _compactCjkInlineSpacing(String value) {
  var compacted = value;
  while (true) {
    final next = compacted
        .replaceAllMapped(
          _cjkSeparatedBySpacePattern,
          (match) => '${match.group(1)}${match.group(2)}',
        )
        .replaceAllMapped(
          _cjkBeforeOpeningPunctuationSpacePattern,
          (match) => '${match.group(1)}${match.group(2)}',
        )
        .replaceAllMapped(
          _openingPunctuationBeforeCjkSpacePattern,
          (match) => '${match.group(1)}${match.group(2)}',
        )
        .replaceAllMapped(
          _cjkBeforeClosingPunctuationSpacePattern,
          (match) => '${match.group(1)}${match.group(2)}',
        )
        .replaceAllMapped(
          _closingPunctuationBeforeCjkSpacePattern,
          (match) => '${match.group(1)}${match.group(2)}',
        );
    if (next == compacted) {
      return next;
    }
    compacted = next;
  }
}

String _firstRuneAsString(String value) {
  return String.fromCharCode(value.runes.first);
}

String _lastRuneAsString(String value) {
  return String.fromCharCode(value.runes.last);
}

String _sanitizeFragmentToHtml(
  dom.DocumentFragment fragment, {
  Set<String> allowedLocalImageUrls = const <String>{},
}) {
  return fragment.nodes
      .map(
        (node) => _sanitizeNodeToHtml(
          node,
          allowedLocalImageUrls: allowedLocalImageUrls,
        ),
      )
      .join();
}

String _sanitizeNodeToHtml(
  dom.Node node, {
  Set<String> allowedLocalImageUrls = const <String>{},
}) {
  if (node.nodeType == dom.Node.COMMENT_NODE) {
    return '';
  }
  if (node is dom.Text) {
    return node.text;
  }
  if (node is! dom.Element) {
    return node.text ?? '';
  }
  final tag = node.localName;
  if (tag == null || _blockedHtmlTags.contains(tag)) {
    return '';
  }
  if (!_allowedHtmlTags.contains(tag)) {
    return node.nodes
        .map(
          (child) => _sanitizeNodeToHtml(
            child,
            allowedLocalImageUrls: allowedLocalImageUrls,
          ),
        )
        .join();
  }
  final attributes = _sanitizeAttributeMap(
    node,
    tag,
    allowedLocalImageUrls: allowedLocalImageUrls,
  );
  if (attributes == null) {
    return tag == 'img' || tag == 'input'
        ? ''
        : node.nodes
              .map(
                (child) => _sanitizeNodeToHtml(
                  child,
                  allowedLocalImageUrls: allowedLocalImageUrls,
                ),
              )
              .join();
  }
  final renderedAttributes = attributes.entries
      .map((entry) => ' ${entry.key}="${_escapeHtmlAttribute(entry.value)}"')
      .join();
  if (_voidHtmlTags.contains(tag)) {
    return '<$tag$renderedAttributes>';
  }
  final children = node.nodes
      .map(
        (child) => _sanitizeNodeToHtml(
          child,
          allowedLocalImageUrls: allowedLocalImageUrls,
        ),
      )
      .join();
  return '<$tag$renderedAttributes>$children</$tag>';
}

Map<String, String>? _sanitizeAttributeMap(
  dom.Element element,
  String tag, {
  Set<String> allowedLocalImageUrls = const <String>{},
}) {
  final allowedAttributes = _allowedHtmlAttributes[tag] ?? const <String>{};
  final originalAttributes = Map<String, String>.from(element.attributes);
  final sanitizedAttributes = <String, String>{};
  for (final entry in originalAttributes.entries) {
    if (!allowedAttributes.contains(entry.key)) continue;
    sanitizedAttributes[entry.key] = entry.value;
  }

  if (tag == 'a') {
    final href = _sanitizeUrl(sanitizedAttributes['href'], allowMailto: true);
    if (href == null) {
      return null;
    }
    sanitizedAttributes['href'] = href;
  }

  if (tag == 'img') {
    final src = _sanitizeUrl(
      sanitizedAttributes['src'],
      allowFile: true,
      allowedFileUrls: allowedLocalImageUrls,
    );
    if (src == null) {
      return null;
    }
    sanitizedAttributes['src'] = src;
  }

  if (tag == 'input') {
    final type = sanitizedAttributes['type']?.toLowerCase();
    if (type != 'checkbox') {
      return null;
    }
    sanitizedAttributes['type'] = type!;
  }

  return sanitizedAttributes;
}

String? _sanitizeUrl(
  String? value, {
  bool allowMailto = false,
  bool allowFile = false,
  Set<String> allowedFileUrls = const <String>{},
}) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.hasScheme) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') return trimmed;
    if (allowMailto && scheme == 'mailto') return trimmed;
    if (allowFile && scheme == 'file' && allowedFileUrls.contains(trimmed)) {
      return trimmed;
    }
    return null;
  }
  return trimmed;
}

String _escapeHtmlAttribute(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

void _absolutizeAttribute(
  dom.DocumentFragment fragment, {
  required String tagName,
  required String attribute,
  required Uri baseUrl,
}) {
  for (final element in fragment.querySelectorAll('$tagName[$attribute]')) {
    final rawValue = element.attributes[attribute]?.trim();
    if (rawValue == null || rawValue.isEmpty) continue;
    final parsed = Uri.tryParse(rawValue);
    if (parsed == null) continue;
    final resolved = parsed.hasScheme ? parsed : baseUrl.resolveUri(parsed);
    element.attributes[attribute] = resolved.toString();
  }
}

String _buildTextFallback(String? value) {
  final text = value?.replaceAll('\r\n', '\n').trim() ?? '';
  if (text.isEmpty) return '';
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((item) => _normalizeWhitespace(item.replaceAll('\n', ' ')))
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .take(8)
      .toList(growable: false);
  if (paragraphs.isEmpty) return '';

  final output = <String>[];
  var consumedChars = 0;
  for (final paragraph in paragraphs) {
    if (consumedChars >= 4000) break;
    final available = 4000 - consumedChars;
    final clipped = paragraph.length <= available
        ? paragraph
        : '${paragraph.substring(0, available).trimRight()}...';
    if (clipped.isEmpty) continue;
    output.add(clipped);
    consumedChars += clipped.length;
  }
  return output.join('\n\n').trim();
}

String _escapeMarkdownText(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');
}

String? _normalizeWhitespace(String? value) {
  if (value == null) return null;
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}
