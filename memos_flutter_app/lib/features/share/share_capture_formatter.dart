import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

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
  final siteLabel = _resolveSiteLabel(result: result, url: resolvedUrl);
  final excerpt = _normalizeWhitespace(result.excerpt);
  final body = _buildMarkdownBody(
    result: result,
    baseUrl: resolvedUrl,
    contentHtmlOverride: contentHtmlOverride,
    allowedLocalImageUrls: allowedLocalImageUrls,
  );
  final buffer = StringBuffer()
    ..writeln('# $title')
    ..writeln();
  final linkLabel = title.isNotEmpty ? title : siteLabel;
  buffer.writeln(_buildMarkdownLink(linkLabel, resolvedUrl));
  if (excerpt != null) {
    buffer
      ..writeln()
      ..writeln('> $excerpt');
  }
  if (body != null) {
    buffer
      ..writeln()
      ..writeln(body);
  }
  buffer
    ..writeln()
    ..writeln(buildThirdPartyShareMemoMarker());
  return buffer.toString().trimRight();
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

String _resolveSiteLabel({
  required ShareCaptureResult result,
  required Uri url,
}) {
  return _normalizeWhitespace(result.siteName) ?? url.host;
}

Uri _resolveFinalUrl(Uri url) {
  if (url.hasScheme && url.hasAuthority) return url;
  final normalized = Uri.tryParse(url.toString());
  if (normalized != null && normalized.hasScheme && normalized.hasAuthority) {
    return normalized;
  }
  return Uri.parse('https://${url.toString()}');
}

String? _buildMarkdownBody({
  required ShareCaptureResult result,
  required Uri baseUrl,
  String? contentHtmlOverride,
  Set<String> allowedLocalImageUrls = const <String>{},
}) {
  final rawHtml = (contentHtmlOverride ?? result.contentHtml ?? '').trim();
  if (rawHtml.isNotEmpty) {
    return _sanitizeFragmentToMarkdown(
      rawHtml,
      baseUrl,
      allowedLocalImageUrls: allowedLocalImageUrls,
    );
  }

  final fallback = _buildTextFallback(result.textContent);
  if (fallback.isEmpty) return null;
  return fallback;
}

String? _sanitizeFragmentToMarkdown(
  String rawHtml,
  Uri baseUrl, {
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
  final sanitized = _sanitizeFragmentToHtml(
    fragment,
    allowedLocalImageUrls: allowedLocalImageUrls,
  ).trim();
  if (sanitized.isEmpty) return null;
  final markdown = _convertSanitizedHtmlToMarkdown(sanitized);
  if (markdown.isEmpty) return null;
  return markdown;
}

String _convertSanitizedHtmlToMarkdown(String sanitizedHtml) {
  final fragment = html_parser.parseFragment(sanitizedHtml);
  final blocks = _collectMarkdownBlocks(fragment.nodes);
  return _cleanupGeneratedMarkdown(blocks.join('\n\n'));
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
  final inlineBuffer = StringBuffer();

  void flushInlineBuffer() {
    final text = _cleanupInlineMarkdown(inlineBuffer.toString());
    inlineBuffer.clear();
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
    inlineBuffer.write(_renderInlineMarkdownNode(node));
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
  for (final node in nodes) {
    buffer.write(_renderInlineMarkdownNode(node));
  }
  return buffer.toString();
}

String _renderInlineMarkdownNode(dom.Node node) {
  if (node is dom.Text) {
    return _escapeMarkdownTextNode(node.text);
  }
  if (node is! dom.Element) {
    return _escapeMarkdownTextNode(node.text ?? '');
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
  final alt = _escapeMarkdownText(
    (element.attributes['alt'] ?? element.attributes['title'] ?? '').trim(),
  );
  final title = (element.attributes['title'] ?? '').trim();
  if (title.isEmpty) {
    return '![$alt]($src)';
  }
  return '![$alt]($src "${title.replaceAll('"', r'\"')}")';
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

String _cleanupInlineMarkdown(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r' *\\\n *'), '\\\n')
      .trim();
}

String _cleanupGeneratedMarkdown(String text) {
  return text
      .replaceAll('\r\n', '\n')
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
