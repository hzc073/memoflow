import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;

import 'memo_html_sanitizer.dart';
import 'memo_markdown_preprocessor.dart';
import 'memo_task_list_service.dart';

const String _mathInlineTag = 'memo-math-inline';
const String _mathBlockTag = 'memo-math-block';

final RegExp _codeBlockHtmlPattern = RegExp(
  r'<pre><code([^>]*)>([\s\S]*?)</code></pre>',
);

enum MemoRenderMode { html, codeBlock }

class MemoRenderArtifact {
  const MemoRenderArtifact({required this.mode, required this.content});

  final MemoRenderMode mode;
  final String content;
}

class MemoRenderPipeline {
  MemoRenderPipeline();

  final _cache = _LruCache<String, String>(capacity: 80);

  MemoRenderArtifact build({
    required String data,
    required bool renderImages,
    String? highlightQuery,
    String? cacheKey,
  }) {
    final filteredData = stripTaskListToggleHint(data);
    final rawTrimmed = filteredData.trim();
    if (rawTrimmed.isEmpty) {
      return const MemoRenderArtifact(mode: MemoRenderMode.html, content: '');
    }

    if (looksLikeFullHtmlDocument(rawTrimmed)) {
      return MemoRenderArtifact(
        mode: MemoRenderMode.codeBlock,
        content: rawTrimmed.replaceAll('\r\n', '\n'),
      );
    }

    var sanitized = sanitizeMemoMarkdown(filteredData);
    if (!renderImages) {
      sanitized = stripMarkdownImages(sanitized);
    }

    final trimmed = sanitized.trim();
    if (trimmed.isEmpty) {
      return const MemoRenderArtifact(mode: MemoRenderMode.html, content: '');
    }
    final tagged = decorateMemoTagsForHtml(trimmed);

    final cachedHtml = cacheKey == null ? null : _cache.get(cacheKey);
    final html =
        cachedHtml ?? _buildMemoHtml(tagged, highlightQuery: highlightQuery);
    if (cacheKey != null && cachedHtml == null) {
      _cache.set(cacheKey, html);
    }

    return MemoRenderArtifact(mode: MemoRenderMode.html, content: html);
  }

  void invalidateByMemoUid(String memoUid) {
    final trimmed = memoUid.trim();
    if (trimmed.isEmpty) return;
    _cache.removeWhere((key) => key.startsWith('$trimmed|'));
  }
}

class _LruCache<K, V> {
  _LruCache({required int capacity}) : _capacity = capacity;

  final int _capacity;
  final _map = <K, V>{};

  V? get(K key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  void set(K key, V value) {
    if (_capacity <= 0) return;
    _map.remove(key);
    _map[key] = value;
    if (_map.length > _capacity) {
      _map.remove(_map.keys.first);
    }
  }

  void removeWhere(bool Function(K key) test) {
    final keys = _map.keys.where(test).toList(growable: false);
    for (final key in keys) {
      _map.remove(key);
    }
  }
}

String _buildMemoHtml(String text, {String? highlightQuery}) {
  final rawHtml = _renderMarkdownToHtml(text);
  final escapedCodeBlocks = _escapeCodeBlocks(rawHtml);
  final sanitized = sanitizeMemoHtml(escapedCodeBlocks);
  return _applySearchHighlights(sanitized, highlightQuery: highlightQuery);
}

String _applySearchHighlights(String html, {String? highlightQuery}) {
  final terms = _extractHighlightTerms(highlightQuery);
  if (terms.isEmpty) return html;

  final pattern = terms.map(RegExp.escape).join('|');
  final matcher = RegExp(pattern, caseSensitive: false, unicode: true);
  final fragment = html_parser.parseFragment(html);
  _decorateTextHighlights(fragment, matcher, inIgnoredSubtree: false);
  return fragment.outerHtml;
}

List<String> _extractHighlightTerms(String? query) {
  if (query == null) return const [];

  final parts = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return const [];

  final normalizedSeen = <String>{};
  final unique = <String>[];
  for (final part in parts) {
    final normalized = part.toLowerCase();
    if (!normalizedSeen.add(normalized)) continue;
    unique.add(part);
  }
  unique.sort((a, b) => b.runes.length.compareTo(a.runes.length));
  return unique;
}

void _decorateTextHighlights(
  dom.Node node,
  RegExp matcher, {
  required bool inIgnoredSubtree,
}) {
  if (node is dom.Text) {
    if (inIgnoredSubtree) return;

    final parent = node.parent;
    if (parent == null) return;

    final text = node.text;
    if (text.trim().isEmpty) return;

    final matches = matcher.allMatches(text).toList(growable: false);
    if (matches.isEmpty) return;

    final replacements = <dom.Node>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.end <= cursor) continue;
      if (match.start > cursor) {
        replacements.add(dom.Text(text.substring(cursor, match.start)));
      }
      final span = dom.Element.tag('span')
        ..attributes['class'] = 'memohighlight'
        ..append(dom.Text(text.substring(match.start, match.end)));
      replacements.add(span);
      cursor = match.end;
    }
    if (cursor < text.length) {
      replacements.add(dom.Text(text.substring(cursor)));
    }
    if (replacements.isEmpty) return;

    for (final replacement in replacements) {
      parent.insertBefore(replacement, node);
    }
    node.remove();
    return;
  }

  var ignore = inIgnoredSubtree;
  if (node is dom.Element) {
    final localName = node.localName ?? '';
    final classList = (node.attributes['class'] ?? '')
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toSet();
    ignore =
        ignore ||
        localName == 'pre' ||
        localName == 'code' ||
        classList.contains('memotag') ||
        classList.contains('memohighlight');
  }
  if (ignore) return;

  final children = node.nodes.toList(growable: false);
  for (final child in children) {
    _decorateTextHighlights(child, matcher, inIgnoredSubtree: ignore);
  }
}

String _renderMarkdownToHtml(String text) {
  final inlineSyntaxes = <md.InlineSyntax>[
    _MathInlineSyntax(),
    _MathParenInlineSyntax(),
    _HtmlSoftLineBreakSyntax(),
    _HtmlHighlightInlineSyntax(),
  ];

  return md.markdownToHtml(
    text,
    extensionSet: md.ExtensionSet.gitHubFlavored,
    blockSyntaxes: const [_MathBlockSyntax(), _MathBracketBlockSyntax()],
    inlineSyntaxes: inlineSyntaxes,
    encodeHtml: false,
  );
}

String _escapeCodeBlocks(String html) {
  return html.replaceAllMapped(_codeBlockHtmlPattern, (match) {
    final attrs = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    return '<pre><code$attrs>${_escapeHtmlText(content)}</code></pre>';
  });
}

String _escapeHtmlText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

class _HtmlSoftLineBreakSyntax extends md.InlineSyntax {
  _HtmlSoftLineBreakSyntax() : super(r'\n', startCharacter: 0x0A);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}

class _HtmlHighlightInlineSyntax extends md.InlineSyntax {
  _HtmlHighlightInlineSyntax() : super(r'==([^\n]+?)==', startCharacter: 0x3D);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match.group(1);
    if (text == null || text.trim().isEmpty) return false;
    final element = md.Element('span', [md.Text(text)]);
    element.attributes['class'] = 'memohighlight';
    parser.addNode(element);
    return true;
  }
}

class _MathInlineSyntax extends md.InlineSyntax {
  _MathInlineSyntax()
    : super(r'\$(?!\s)([^\n\$]+?)\$(?!\s)', startCharacter: 0x24);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final start = match.start;
    if (start > 0 && parser.source.codeUnitAt(start - 1) == 0x5C) {
      return false;
    }
    final content = match.group(1);
    if (content == null || content.trim().isEmpty) return false;
    parser.addNode(md.Element(_mathInlineTag, [md.Text(content)]));
    return true;
  }
}

class _MathParenInlineSyntax extends md.InlineSyntax {
  _MathParenInlineSyntax() : super(r'\\\((.+?)\\\)', startCharacter: 0x5C);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match.group(1);
    if (content == null || content.trim().isEmpty) return false;
    parser.addNode(md.Element(_mathInlineTag, [md.Text(content)]));
    return true;
  }
}

class _MathBlockSyntax extends md.BlockSyntax {
  const _MathBlockSyntax();

  static final RegExp _singleLine = RegExp(r'^\s*\$\$(.+?)\$\$\s*$');
  static final RegExp _open = RegExp(r'^\s*\$\$');
  static final RegExp _close = RegExp(r'^\s*\$\$\s*$');

  @override
  RegExp get pattern => _open;

  @override
  md.Node? parse(md.BlockParser parser) {
    final line = parser.current.content;
    final singleMatch = _singleLine.firstMatch(line);
    if (singleMatch != null) {
      parser.advance();
      final content = singleMatch.group(1)?.trim() ?? '';
      return md.Element(_mathBlockTag, [md.Text(content)]);
    }

    parser.advance();
    final buffer = StringBuffer();
    while (!parser.isDone) {
      final current = parser.current.content;
      if (_close.hasMatch(current)) {
        parser.advance();
        break;
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(current);
      parser.advance();
    }
    final content = buffer.toString().trim();
    return md.Element(_mathBlockTag, [md.Text(content)]);
  }
}

class _MathBracketBlockSyntax extends md.BlockSyntax {
  const _MathBracketBlockSyntax();

  static final RegExp _singleLine = RegExp(r'^\s*\\\[(.+?)\\\]\s*$');
  static final RegExp _open = RegExp(r'^\s*\\\[');
  static final RegExp _close = RegExp(r'^\s*\\\]\s*$');

  @override
  RegExp get pattern => _open;

  @override
  md.Node? parse(md.BlockParser parser) {
    final line = parser.current.content;
    final singleMatch = _singleLine.firstMatch(line);
    if (singleMatch != null) {
      parser.advance();
      final content = singleMatch.group(1)?.trim() ?? '';
      return md.Element(_mathBlockTag, [md.Text(content)]);
    }

    parser.advance();
    final buffer = StringBuffer();
    while (!parser.isDone) {
      final current = parser.current.content;
      if (_close.hasMatch(current)) {
        parser.advance();
        break;
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(current);
      parser.advance();
    }
    final content = buffer.toString().trim();
    return md.Element(_mathBlockTag, [md.Text(content)]);
  }
}
