import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../core/app_localization.dart';
import '../../data/models/app_preferences.dart';
import 'memo_task_list_service.dart';

const int kMemoCardPreviewMaxLines = 6;
const int kMemoCardPreviewMaxCompactRunes = 220;

final RegExp _markdownImagePattern = RegExp(
  r'!\[[^\]]*]\(([^)\s]+)(?:\s+"[^"]*")?\)',
);
final RegExp _markdownLinkPattern = RegExp(r'\[([^\]]*)\]\(([^)]+)\)');
final RegExp _markdownHeadingPattern = RegExp(
  r'^\s{0,3}#{1,6}\s+',
  multiLine: true,
);
final RegExp _markdownBlockquotePattern = RegExp(r'^\s*>\s?', multiLine: true);
final RegExp _markdownTaskPattern = RegExp(
  r'^(\s*(?:[-*+]|\d+\.)?\s*)\[( |x|X)\]\s+',
  multiLine: true,
);
final RegExp _markdownInlineCodePattern = RegExp(r'`([^`\n]+)`');
final RegExp _whitespaceCollapsePattern = RegExp(r'\s+');
final RegExp _multipleBlankLinesPattern = RegExp(r'\n{3,}');

const Set<String> _previewBlockTags = <String>{
  'address',
  'article',
  'aside',
  'blockquote',
  'div',
  'dl',
  'fieldset',
  'figcaption',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'tr',
  'ul',
};

const Set<String> _previewSkippedTags = <String>{
  'audio',
  'canvas',
  'embed',
  'figure',
  'iframe',
  'img',
  'object',
  'picture',
  'script',
  'source',
  'style',
  'svg',
  'video',
};

class MemoCardPreviewResult {
  const MemoCardPreviewResult({required this.text, required this.truncated});

  final String text;
  final bool truncated;
}

String buildMemoCardPreviewText(
  String content, {
  required bool collapseReferences,
  required AppLanguage language,
}) {
  final trimmed = stripTaskListToggleHint(content).trim();
  if (trimmed.isEmpty) return '';

  final previewSource = collapseReferences
      ? _collapseQuotedPreviewLines(trimmed, language: language)
      : trimmed;
  return _normalizeMemoCardPreviewText(previewSource);
}

String _collapseQuotedPreviewLines(
  String trimmed, {
  required AppLanguage language,
}) {
  final lines = trimmed.split('\n');
  final keep = <String>[];
  var quoteLines = 0;
  for (final line in lines) {
    if (line.trimLeft().startsWith('>')) {
      quoteLines++;
      continue;
    }
    keep.add(line);
  }

  final main = keep.join('\n').trim();
  if (quoteLines == 0) return main;
  if (main.isEmpty) {
    final cleaned = lines
        .map((line) => line.replaceFirst(RegExp(r'^\s*>\s?'), ''))
        .join('\n')
        .trim();
    return cleaned.isEmpty ? trimmed : cleaned;
  }
  return '$main\n\n${trByLanguageKey(language: language, key: 'legacy.msg_quoted_lines', params: {'quoteLines': quoteLines})}';
}

String _normalizeMemoCardPreviewText(String text) {
  var normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (normalized.isEmpty) return '';

  normalized = normalized.replaceAllMapped(_markdownImagePattern, (_) => '');
  normalized = normalized.replaceAllMapped(_markdownLinkPattern, (match) {
    final label = match.group(1)?.trim() ?? '';
    if (label.isNotEmpty) {
      return label;
    }
    return match.group(2)?.trim() ?? '';
  });

  if (normalized.contains('<') || normalized.contains('&')) {
    final buffer = StringBuffer();
    final fragment = html_parser.parseFragment(normalized);
    for (final node in fragment.nodes) {
      _writePreviewNodeText(buffer, node);
    }
    normalized = buffer.toString();
  }

  normalized = normalized.replaceAllMapped(
    _markdownInlineCodePattern,
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAll(_markdownHeadingPattern, '');
  normalized = normalized.replaceAll(_markdownBlockquotePattern, '');
  normalized = normalized.replaceAllMapped(_markdownTaskPattern, (match) {
    final checked = (match.group(2) ?? '').toLowerCase() == 'x';
    return checked ? '☑ ' : '☐ ';
  });
  normalized = normalized.replaceAll('\u00A0', ' ');

  final lines = normalized
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trimRight())
      .toList(growable: false);

  normalized = lines.join('\n');
  normalized = normalized.replaceAll(_multipleBlankLinesPattern, '\n\n').trim();
  return normalized;
}

void _writePreviewNodeText(StringBuffer buffer, dom.Node node) {
  if (node is dom.Text) {
    buffer.write(node.text);
    return;
  }
  if (node is! dom.Element) return;

  final localName = node.localName?.toLowerCase();
  if (localName == null) return;
  if (_previewSkippedTags.contains(localName)) return;
  if (localName == 'br') {
    _appendPreviewNewline(buffer);
    return;
  }

  final isBlock = _previewBlockTags.contains(localName);
  if (isBlock && buffer.isNotEmpty && !_bufferEndsWithNewline(buffer)) {
    _appendPreviewNewline(buffer);
  }
  if (localName == 'li') {
    buffer.write('• ');
  }

  final hasHrefText =
      localName == 'a' &&
      node.text.trim().isEmpty &&
      (node.attributes['href']?.trim().isNotEmpty ?? false);
  if (hasHrefText) {
    buffer.write(node.attributes['href']!.trim());
  } else {
    for (final child in node.nodes) {
      _writePreviewNodeText(buffer, child);
    }
  }

  if (isBlock && buffer.isNotEmpty && !_bufferEndsWithNewline(buffer)) {
    _appendPreviewNewline(buffer);
  }
}

void _appendPreviewNewline(StringBuffer buffer) {
  if (_bufferEndsWithNewline(buffer)) return;
  buffer.write('\n');
}

bool _bufferEndsWithNewline(StringBuffer buffer) {
  final value = buffer.toString();
  return value.endsWith('\n');
}

MemoCardPreviewResult truncateMemoCardPreview(
  String text, {
  required bool collapseLongContent,
}) {
  if (!collapseLongContent) {
    return MemoCardPreviewResult(text: text, truncated: false);
  }

  var result = text;
  var truncated = false;
  final lines = result.split('\n');
  if (lines.length > kMemoCardPreviewMaxLines) {
    result = lines.take(kMemoCardPreviewMaxLines).join('\n');
    truncated = true;
  }

  final truncatedText = _truncatePreviewText(
    result,
    kMemoCardPreviewMaxCompactRunes,
  );
  if (truncatedText != result) {
    result = truncatedText;
    truncated = true;
  }

  if (truncated) {
    result = result.trimRight();
    result = result.endsWith('...') ? result : '$result...';
  }
  return MemoCardPreviewResult(text: result, truncated: truncated);
}

int _compactRuneCount(String text) {
  if (text.isEmpty) return 0;
  final compact = text.replaceAll(_whitespaceCollapsePattern, '');
  return compact.runes.length;
}

bool _isWhitespaceRune(int rune) {
  switch (rune) {
    case 0x09:
    case 0x0A:
    case 0x0B:
    case 0x0C:
    case 0x0D:
    case 0x20:
      return true;
    default:
      return String.fromCharCode(rune).trim().isEmpty;
  }
}

int _cutIndexByCompactRunes(String text, int maxCompactRunes) {
  if (text.isEmpty || maxCompactRunes <= 0) return 0;
  var count = 0;
  final iterator = RuneIterator(text);
  while (iterator.moveNext()) {
    final rune = iterator.current;
    if (!_isWhitespaceRune(rune)) {
      count++;
      if (count >= maxCompactRunes) {
        return iterator.rawIndex + iterator.currentSize;
      }
    }
  }
  return text.length;
}

String _truncatePreviewText(String text, int maxCompactRunes) {
  var count = 0;
  var index = 0;

  for (final match in _markdownLinkPattern.allMatches(text)) {
    final prefix = text.substring(index, match.start);
    final prefixCount = _compactRuneCount(prefix);
    if (count + prefixCount >= maxCompactRunes) {
      final remaining = maxCompactRunes - count;
      final cutOffset = _cutIndexByCompactRunes(prefix, remaining);
      return text.substring(0, index + cutOffset);
    }
    count += prefixCount;

    final label = match.group(1) ?? '';
    final labelCount = _compactRuneCount(label);
    if (count + labelCount >= maxCompactRunes) {
      if (count >= maxCompactRunes) {
        return text.substring(0, match.start);
      }
      return text.substring(0, match.end);
    }
    count += labelCount;
    index = match.end;
  }

  final tail = text.substring(index);
  final tailCount = _compactRuneCount(tail);
  if (count + tailCount >= maxCompactRunes) {
    final remaining = maxCompactRunes - count;
    final cutOffset = _cutIndexByCompactRunes(tail, remaining);
    return text.substring(0, index + cutOffset);
  }

  return text;
}
