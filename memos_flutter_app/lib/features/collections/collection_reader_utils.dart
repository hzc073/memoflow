import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as markdown;

import '../../data/models/collection_reader.dart';
import '../../data/models/local_memo.dart';
import '../memos/memo_image_src_normalizer.dart';
import '../memos/memo_markdown_preprocessor.dart';
import 'collection_reader_page_models.dart';

class CollectionReaderTocEntry {
  const CollectionReaderTocEntry({
    required this.memoUid,
    required this.memoIndex,
    required this.title,
    required this.subtitle,
  });

  final String memoUid;
  final int memoIndex;
  final String title;
  final String subtitle;
}

class CollectionReaderSearchResult {
  const CollectionReaderSearchResult({
    required this.memoUid,
    required this.memoIndex,
    required this.title,
    required this.excerpt,
    required this.matchCount,
    required this.firstMatchOffset,
  });

  final String memoUid;
  final int memoIndex;
  final String title;
  final String excerpt;
  final int matchCount;
  final int firstMatchOffset;
}

enum CollectionReaderContentBlockKind { text, spacer, image, video }

class CollectionReaderContentBlock {
  const CollectionReaderContentBlock.text({
    required this.text,
    required this.charStart,
    required this.charEnd,
    this.textRole = ReaderTextRole.body,
  }) : kind = CollectionReaderContentBlockKind.text,
       heightHint = null,
       sourceUrl = null;

  const CollectionReaderContentBlock.spacer({this.heightHint = 16})
    : kind = CollectionReaderContentBlockKind.spacer,
      textRole = ReaderTextRole.body,
      text = null,
      charStart = null,
      charEnd = null,
      sourceUrl = null;

  const CollectionReaderContentBlock.image({required this.sourceUrl, this.text})
    : kind = CollectionReaderContentBlockKind.image,
      textRole = ReaderTextRole.body,
      charStart = null,
      charEnd = null,
      heightHint = null;

  const CollectionReaderContentBlock.video({required this.sourceUrl, this.text})
    : kind = CollectionReaderContentBlockKind.video,
      textRole = ReaderTextRole.body,
      charStart = null,
      charEnd = null,
      heightHint = null;

  final CollectionReaderContentBlockKind kind;
  final String? text;
  final ReaderTextRole textRole;
  final int? charStart;
  final int? charEnd;
  final double? heightHint;
  final String? sourceUrl;
}

class CollectionReaderParsedContent {
  const CollectionReaderParsedContent({
    required this.text,
    required this.blocks,
  });

  final String text;
  final List<CollectionReaderContentBlock> blocks;
}

String buildCollectionReaderTocTitle(LocalMemo memo, int memoIndex) {
  return _buildCollectionReaderTocTitleFromParts(
    content: memo.content,
    effectiveDisplayTime: memo.effectiveDisplayTime,
    memoIndex: memoIndex,
  );
}

String _buildCollectionReaderTocTitleFromParts({
  required String content,
  required DateTime effectiveDisplayTime,
  required int memoIndex,
}) {
  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  final firstLine = lines.isEmpty ? '' : lines.first;
  if (firstLine.isNotEmpty) {
    return _truncateByRunes(firstLine, 32);
  }
  if (effectiveDisplayTime.millisecondsSinceEpoch > 0) {
    return DateFormat('yyyy-MM-dd HH:mm').format(effectiveDisplayTime);
  }
  return 'Memo ${memoIndex + 1}';
}

String buildCollectionReaderTocSubtitle(LocalMemo memo) {
  final displayTime = memo.effectiveDisplayTime.millisecondsSinceEpoch > 0
      ? memo.effectiveDisplayTime
      : memo.updateTime;
  return DateFormat('yyyy-MM-dd HH:mm').format(displayTime);
}

List<CollectionReaderTocEntry> buildCollectionReaderTocEntries(
  List<LocalMemo> items,
) {
  return List<CollectionReaderTocEntry>.generate(items.length, (index) {
    final memo = items[index];
    return CollectionReaderTocEntry(
      memoUid: memo.uid,
      memoIndex: index,
      title: buildCollectionReaderTocTitle(memo, index),
      subtitle: buildCollectionReaderTocSubtitle(memo),
    );
  }, growable: false);
}

String extractCollectionReaderContentText(LocalMemo memo) {
  return parseCollectionReaderContent(memo.content).text;
}

CollectionReaderParsedContent parseCollectionReaderContent(String sourceRaw) {
  final fragment = _parseCollectionReaderFragment(sourceRaw);
  if (fragment == null) {
    return const CollectionReaderParsedContent(
      text: '',
      blocks: <CollectionReaderContentBlock>[],
    );
  }

  final rawBlocks = <CollectionReaderContentBlock>[];
  _collectCollectionReaderContentBlocks(fragment.nodes, rawBlocks);

  final normalizedBlocks = <CollectionReaderContentBlock>[];
  final textBuffer = StringBuffer();
  var lastWasSpacer = false;
  for (final block in rawBlocks) {
    switch (block.kind) {
      case CollectionReaderContentBlockKind.spacer:
        if (normalizedBlocks.isEmpty ||
            normalizedBlocks.last.kind ==
                CollectionReaderContentBlockKind.spacer) {
          continue;
        }
        normalizedBlocks.add(block);
        lastWasSpacer = true;
        break;
      case CollectionReaderContentBlockKind.text:
        final text = block.text?.trim();
        if (text == null || text.isEmpty) {
          continue;
        }
        if (textBuffer.isNotEmpty) {
          textBuffer.write(lastWasSpacer ? '\n\n\n' : '\n\n');
        }
        final start = textBuffer.length;
        textBuffer.write(text);
        final end = textBuffer.length;
        normalizedBlocks.add(
          CollectionReaderContentBlock.text(
            text: text,
            charStart: start,
            charEnd: end,
            textRole: block.textRole,
          ),
        );
        lastWasSpacer = false;
        break;
      case CollectionReaderContentBlockKind.image:
        final sourceUrl = block.sourceUrl?.trim();
        if (sourceUrl == null || sourceUrl.isEmpty) {
          continue;
        }
        normalizedBlocks.add(
          CollectionReaderContentBlock.image(
            sourceUrl: sourceUrl,
            text: block.text?.trim(),
          ),
        );
        lastWasSpacer = false;
        break;
      case CollectionReaderContentBlockKind.video:
        final sourceUrl = block.sourceUrl?.trim();
        if (sourceUrl == null || sourceUrl.isEmpty) {
          continue;
        }
        normalizedBlocks.add(
          CollectionReaderContentBlock.video(
            sourceUrl: sourceUrl,
            text: block.text?.trim(),
          ),
        );
        lastWasSpacer = false;
        break;
    }
  }

  while (normalizedBlocks.isNotEmpty &&
      normalizedBlocks.last.kind == CollectionReaderContentBlockKind.spacer) {
    normalizedBlocks.removeLast();
  }

  return CollectionReaderParsedContent(
    text: textBuffer.toString(),
    blocks: List<CollectionReaderContentBlock>.unmodifiable(normalizedBlocks),
  );
}

dom.DocumentFragment? _parseCollectionReaderFragment(String sourceRaw) {
  final source = sourceRaw.trim();
  if (source.isEmpty) {
    return null;
  }
  if (looksLikeFullHtmlDocument(source)) {
    final document = html_parser.parse(source);
    return html_parser.parseFragment(document.body?.innerHtml ?? source);
  }
  final sanitized = sanitizeMemoMarkdown(sourceRaw).trim();
  if (sanitized.isEmpty) {
    return null;
  }
  final tagged = decorateMemoTagsForHtml(sanitized);
  final html = markdown.markdownToHtml(
    tagged,
    extensionSet: markdown.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  return html_parser.parseFragment(html);
}

void _collectCollectionReaderContentBlocks(
  List<dom.Node> nodes,
  List<CollectionReaderContentBlock> output,
) {
  final inlineBuffer = StringBuffer();

  void flushInlineBuffer() {
    final text = _normalizeCollectionReaderTextBlock(inlineBuffer.toString());
    inlineBuffer.clear();
    if (text.isEmpty) {
      return;
    }
    output.add(
      CollectionReaderContentBlock.text(
        text: text,
        charStart: 0,
        charEnd: text.length,
      ),
    );
  }

  for (final node in nodes) {
    if (node is dom.Text) {
      inlineBuffer.write(node.text);
      continue;
    }
    if (node is! dom.Element) {
      continue;
    }
    if (_isReaderBlankLineElement(node)) {
      flushInlineBuffer();
      output.add(const CollectionReaderContentBlock.spacer(heightHint: 20));
      continue;
    }
    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'img') {
      flushInlineBuffer();
      final src = normalizeMarkdownImageSrc(
        (node.attributes['src'] ?? '').trim(),
      );
      if (src.isNotEmpty) {
        output.add(
          CollectionReaderContentBlock.image(
            sourceUrl: src,
            text: _normalizeCollectionReaderTextBlock(
              (node.attributes['alt'] ?? node.attributes['title'] ?? '').trim(),
            ),
          ),
        );
      }
      continue;
    }
    if (tag == 'video' || tag == 'source') {
      flushInlineBuffer();
      final src = _resolveCollectionReaderVideoSourceUrl(node);
      if (src != null) {
        output.add(
          CollectionReaderContentBlock.video(
            sourceUrl: src,
            text: _resolveCollectionReaderVideoLabel(node),
          ),
        );
      }
      continue;
    }
    if (tag == 'br') {
      inlineBuffer.writeln();
      continue;
    }
    if (tag == 'hr') {
      flushInlineBuffer();
      output.add(const CollectionReaderContentBlock.spacer(heightHint: 24));
      continue;
    }
    if (tag == 'table') {
      flushInlineBuffer();
      _appendReaderTableBlocks(node, output);
      continue;
    }
    if (tag == 'blockquote') {
      flushInlineBuffer();
      final text = _extractCollectionReaderElementText(
        node,
        preserveWhitespace: false,
        role: ReaderTextRole.quote,
      );
      if (text.isNotEmpty) {
        output.add(
          CollectionReaderContentBlock.text(
            text: text,
            charStart: 0,
            charEnd: text.length,
            textRole: ReaderTextRole.quote,
          ),
        );
      }
      output.add(const CollectionReaderContentBlock.spacer());
      continue;
    }
    if (tag == 'pre' || tag == 'code') {
      flushInlineBuffer();
      final text = _extractCollectionReaderElementText(
        node,
        preserveWhitespace: true,
        role: ReaderTextRole.code,
      );
      if (text.isNotEmpty) {
        output.add(
          CollectionReaderContentBlock.text(
            text: text,
            charStart: 0,
            charEnd: text.length,
            textRole: ReaderTextRole.code,
          ),
        );
      }
      output.add(const CollectionReaderContentBlock.spacer(heightHint: 18));
      continue;
    }
    if (_containsReaderStandaloneBlocks(node)) {
      flushInlineBuffer();
      _collectCollectionReaderContentBlocks(node.nodes, output);
      if (_shouldReaderElementInsertSpacer(tag) &&
          output.isNotEmpty &&
          output.last.kind != CollectionReaderContentBlockKind.spacer) {
        output.add(const CollectionReaderContentBlock.spacer());
      }
      continue;
    }
    if (_isStandaloneReaderTextBlockTag(tag)) {
      flushInlineBuffer();
      final text = _extractCollectionReaderElementText(
        node,
        preserveWhitespace: tag == 'pre' || tag == 'code',
        role: _resolveReaderTextRoleForElement(node),
      );
      if (text.isNotEmpty) {
        output.add(
          CollectionReaderContentBlock.text(
            text: text,
            charStart: 0,
            charEnd: text.length,
            textRole: _resolveReaderTextRoleForElement(node),
          ),
        );
      }
      continue;
    }
    inlineBuffer.write(_extractCollectionReaderInlineText(node));
  }

  flushInlineBuffer();
}

bool _isStandaloneReaderTextBlockTag(String tag) {
  return const <String>{
    'p',
    'div',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  }.contains(tag);
}

bool _containsReaderStandaloneBlocks(dom.Element node) {
  for (final child in node.nodes) {
    if (child is! dom.Element) {
      continue;
    }
    final tag = child.localName?.toLowerCase() ?? '';
    if (_isReaderBlankLineElement(child) ||
        _isStandaloneReaderTextBlockTag(tag) ||
        tag == 'img' ||
        tag == 'video' ||
        tag == 'source') {
      return true;
    }
  }
  return false;
}

bool _shouldReaderElementInsertSpacer(String tag) {
  return const <String>{
    'p',
    'div',
    'blockquote',
    'pre',
    'code',
    'ul',
    'ol',
    'table',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  }.contains(tag);
}

bool _isReaderBlankLineElement(dom.Element element) {
  final tag = element.localName?.toLowerCase() ?? '';
  if (tag != 'p') {
    return false;
  }
  return element.classes.contains('memo-blank-line');
}

String _extractCollectionReaderInlineText(dom.Node node) {
  final buffer = StringBuffer();

  void visit(dom.Node current) {
    if (current is dom.Text) {
      buffer.write(current.text);
      return;
    }
    if (current is! dom.Element) {
      return;
    }
    if (_isReaderBlankLineElement(current)) {
      buffer.writeln();
      buffer.writeln();
      return;
    }
    final tag = current.localName?.toLowerCase() ?? '';
    if (tag == 'br') {
      buffer.writeln();
      return;
    }
    for (final child in current.nodes) {
      visit(child);
    }
  }

  visit(node);
  return _normalizeCollectionReaderTextBlock(buffer.toString());
}

String? _resolveCollectionReaderVideoSourceUrl(dom.Element element) {
  final directSource = normalizeMarkdownImageSrc(
    (element.attributes['src'] ?? '').trim(),
  );
  if (directSource.isNotEmpty) {
    return directSource;
  }

  final sourceElement = element.querySelector('source[src]');
  if (sourceElement == null) {
    return null;
  }

  final nestedSource = normalizeMarkdownImageSrc(
    (sourceElement.attributes['src'] ?? '').trim(),
  );
  return nestedSource.isEmpty ? null : nestedSource;
}

String? _resolveCollectionReaderVideoLabel(dom.Element element) {
  final title = _normalizeCollectionReaderTextBlock(
    (element.attributes['title'] ??
            element.attributes['aria-label'] ??
            element.attributes['data-title'] ??
            '')
        .trim(),
  );
  if (title.isNotEmpty) {
    return title;
  }

  final fallbackText = _normalizeCollectionReaderTextBlock(element.text);
  return fallbackText.isEmpty ? null : fallbackText;
}

ReaderTextRole _resolveReaderTextRoleForElement(dom.Element element) {
  final tag = element.localName?.toLowerCase() ?? '';
  if (tag == 'li') {
    return ReaderTextRole.listItem;
  }
  if (tag == 'h1' ||
      tag == 'h2' ||
      tag == 'h3' ||
      tag == 'h4' ||
      tag == 'h5' ||
      tag == 'h6') {
    return ReaderTextRole.heading;
  }
  return ReaderTextRole.body;
}

String _decorateReaderTextForRole(
  String text, {
  required ReaderTextRole role,
  required dom.Element element,
}) {
  if (text.isEmpty) {
    return text;
  }
  switch (role) {
    case ReaderTextRole.listItem:
      final parentTag = element.parent?.localName?.toLowerCase() ?? '';
      if (parentTag == 'ol') {
        final items =
            element.parent?.children
                .where((child) => child.localName?.toLowerCase() == 'li')
                .toList(growable: false) ??
            const <dom.Element>[];
        final index = items.indexOf(element);
        final prefix = index >= 0 ? '${index + 1}. ' : '- ';
        return _prefixReaderLines(text, prefix);
      }
      return _prefixReaderLines(text, '- ');
    case ReaderTextRole.quote:
      return _prefixReaderLines(text, '> ');
    case ReaderTextRole.body:
    case ReaderTextRole.heading:
    case ReaderTextRole.code:
    case ReaderTextRole.tableRow:
      return text;
  }
}

String _prefixReaderLines(String text, String prefix) {
  return text
      .split('\n')
      .map((line) => line.trim().isEmpty ? prefix.trimRight() : '$prefix$line')
      .join('\n');
}

void _appendReaderTableBlocks(
  dom.Element table,
  List<CollectionReaderContentBlock> output,
) {
  final rows = table.querySelectorAll('tr');
  if (rows.isEmpty) {
    return;
  }
  for (final row in rows) {
    final cells = row.children
        .where(
          (cell) =>
              cell.localName?.toLowerCase() == 'td' ||
              cell.localName?.toLowerCase() == 'th',
        )
        .toList(growable: false);
    if (cells.isEmpty) {
      continue;
    }
    final text = cells
        .map(
          (cell) => _extractCollectionReaderElementText(
            cell,
            preserveWhitespace: false,
            role: ReaderTextRole.tableRow,
          ),
        )
        .where((cellText) => cellText.isNotEmpty)
        .join(' | ');
    if (text.isEmpty) {
      continue;
    }
    output.add(
      CollectionReaderContentBlock.text(
        text: text,
        charStart: 0,
        charEnd: text.length,
        textRole: ReaderTextRole.tableRow,
      ),
    );
  }
  if (output.isNotEmpty &&
      output.last.kind != CollectionReaderContentBlockKind.spacer) {
    output.add(const CollectionReaderContentBlock.spacer(heightHint: 18));
  }
}

String _extractCollectionReaderElementText(
  dom.Element element, {
  required bool preserveWhitespace,
  required ReaderTextRole role,
}) {
  final buffer = StringBuffer();

  void visit(dom.Node node, {required bool preserve}) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is! dom.Element) {
      return;
    }
    if (_isReaderBlankLineElement(node)) {
      buffer.writeln();
      buffer.writeln();
      return;
    }
    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'br') {
      buffer.writeln();
      return;
    }
    if (tag == 'img') {
      return;
    }
    final nextPreserve = preserve || tag == 'pre' || tag == 'code';
    for (final child in node.nodes) {
      visit(child, preserve: nextPreserve);
    }
    if (!nextPreserve &&
        const <String>{'p', 'div', 'blockquote', 'tr'}.contains(tag) &&
        !buffer.toString().endsWith('\n')) {
      buffer.writeln();
    }
  }

  visit(element, preserve: preserveWhitespace);
  final normalized = _normalizeCollectionReaderTextBlock(
    buffer.toString(),
    preserveWhitespace: preserveWhitespace,
  );
  final decorated = _decorateReaderTextForRole(
    normalized,
    role: role,
    element: element,
  );
  return preserveWhitespace
      ? decorated.trimRight()
      : _normalizeCollectionReaderTextBlock(decorated);
}

String _normalizeCollectionReaderTextBlock(
  String raw, {
  bool preserveWhitespace = false,
}) {
  final normalizedLineEndings = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00A0', ' ');
  if (preserveWhitespace) {
    return normalizedLineEndings.trimRight();
  }
  final lines = normalizedLineEndings.split('\n');
  final cleanedLines = <String>[];
  var lastLineWasBlank = false;
  for (final line in lines) {
    final cleaned = line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (cleaned.isEmpty) {
      if (!lastLineWasBlank && cleanedLines.isNotEmpty) {
        cleanedLines.add('');
      }
      lastLineWasBlank = true;
      continue;
    }
    cleanedLines.add(cleaned);
    lastLineWasBlank = false;
  }
  while (cleanedLines.isNotEmpty && cleanedLines.first.isEmpty) {
    cleanedLines.removeAt(0);
  }
  while (cleanedLines.isNotEmpty && cleanedLines.last.isEmpty) {
    cleanedLines.removeLast();
  }
  return cleanedLines.join('\n');
}

List<CollectionReaderSearchResult> buildCollectionReaderSearchResults({
  required List<LocalMemo> items,
  required String query,
}) {
  return _buildCollectionReaderSearchResultsFromRawItems(
    items: List<_ReaderSearchMemo>.generate(items.length, (index) {
      final memo = items[index];
      return _ReaderSearchMemo(
        uid: memo.uid,
        content: memo.content,
        effectiveDisplayTime: memo.effectiveDisplayTime,
        updateTime: memo.updateTime,
      );
    }, growable: false),
    query: query,
  );
}

Future<List<CollectionReaderSearchResult>>
buildCollectionReaderSearchResultsAsync({
  required List<LocalMemo> items,
  required String query,
}) {
  final payload = <String, Object?>{
    'query': query,
    'items': List<Map<String, Object?>>.generate(items.length, (index) {
      final memo = items[index];
      return <String, Object?>{
        'uid': memo.uid,
        'content': memo.content,
        'effectiveDisplayTime':
            memo.effectiveDisplayTime.millisecondsSinceEpoch,
        'updateTime': memo.updateTime.millisecondsSinceEpoch,
      };
    }, growable: false),
  };
  return compute(_buildCollectionReaderSearchResultsFromPayload, payload);
}

List<CollectionReaderSearchResult>
_buildCollectionReaderSearchResultsFromPayload(Map<String, Object?> payload) {
  final query = (payload['query'] as String? ?? '').trim();
  final rawItems = (payload['items'] as List<Object?>? ?? const <Object?>[])
      .whereType<Map<Object?, Object?>>()
      .toList(growable: false);
  final items = List<_ReaderSearchMemo>.generate(rawItems.length, (index) {
    final item = rawItems[index];
    return _ReaderSearchMemo(
      uid: (item['uid'] as String? ?? '').trim(),
      content: (item['content'] as String? ?? ''),
      effectiveDisplayTime: DateTime.fromMillisecondsSinceEpoch(
        _readSearchInt(item['effectiveDisplayTime']),
      ),
      updateTime: DateTime.fromMillisecondsSinceEpoch(
        _readSearchInt(item['updateTime']),
      ),
    );
  }, growable: false);
  return _buildCollectionReaderSearchResultsFromRawItems(
    items: items,
    query: query,
  );
}

List<CollectionReaderSearchResult>
_buildCollectionReaderSearchResultsFromRawItems({
  required List<_ReaderSearchMemo> items,
  required String query,
}) {
  final normalizedQuery = query.trim();
  if (normalizedQuery.isEmpty) {
    return const <CollectionReaderSearchResult>[];
  }
  final lowerQuery = normalizedQuery.toLowerCase();
  final results = <CollectionReaderSearchResult>[];
  for (var index = 0; index < items.length; index += 1) {
    final memo = items[index];
    final excerptSource = parseCollectionReaderContent(memo.content).text;
    final lowerContent = excerptSource.toLowerCase();
    final matches = lowerQuery.allMatches(lowerContent).toList(growable: false);
    if (matches.isEmpty) {
      continue;
    }
    results.add(
      CollectionReaderSearchResult(
        memoUid: memo.uid,
        memoIndex: index,
        title: _buildCollectionReaderTocTitleFromParts(
          content: memo.content,
          effectiveDisplayTime: memo.effectiveDisplayTime,
          memoIndex: index,
        ),
        excerpt: _buildSearchExcerpt(excerptSource, matches.first.start),
        matchCount: matches.length,
        firstMatchOffset: matches.first.start,
      ),
    );
  }
  return results;
}

int resolveCollectionReaderRestoreIndex({
  required List<LocalMemo> items,
  CollectionReaderProgress? progress,
}) {
  if (items.isEmpty) {
    return 0;
  }
  final targetUid = progress?.currentMemoUid?.trim();
  if (targetUid != null && targetUid.isNotEmpty) {
    for (var index = 0; index < items.length; index += 1) {
      if (items[index].uid == targetUid) {
        return index;
      }
    }
  }
  final fallbackIndex = progress?.currentMemoIndex ?? 0;
  if (fallbackIndex < 0 || fallbackIndex >= items.length) {
    return 0;
  }
  return fallbackIndex;
}

CollectionReaderProgress normalizeCollectionReaderProgress({
  required String collectionId,
  required List<LocalMemo> items,
  required CollectionReaderPreferences fallbackPreferences,
  CollectionReaderProgress? progress,
}) {
  final normalizedIndex = resolveCollectionReaderRestoreIndex(
    items: items,
    progress: progress,
  );
  final normalizedMemoUid = items.isEmpty ? null : items[normalizedIndex].uid;
  final source = progress;
  return CollectionReaderProgress(
    collectionId: collectionId,
    readerMode: source?.readerMode ?? fallbackPreferences.mode,
    pageAnimation: source?.pageAnimation ?? fallbackPreferences.pageAnimation,
    currentMemoUid: normalizedMemoUid,
    currentMemoIndex: normalizedIndex,
    currentChapterPageIndex: source?.currentChapterPageIndex ?? 0,
    listScrollOffset: source?.listScrollOffset ?? 0,
    currentMatchCharOffset: source?.currentMatchCharOffset,
    updatedAt: source?.updatedAt ?? DateTime.now(),
  );
}

String _buildSearchExcerpt(String content, int matchStart) {
  const radius = 48;
  if (content.trim().isEmpty) {
    return '';
  }
  final safeStart = matchStart.clamp(0, content.length);
  final start = (safeStart - radius).clamp(0, content.length);
  final end = (safeStart + radius).clamp(0, content.length);
  final prefix = start > 0 ? '\u2026' : '';
  final suffix = end < content.length ? '\u2026' : '';
  final normalizedSlice = content
      .substring(start, end)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '$prefix$normalizedSlice$suffix';
}

String _truncateByRunes(String text, int maxRunes) {
  final runes = text.runes.toList(growable: false);
  if (runes.length <= maxRunes) {
    return text;
  }
  return '${String.fromCharCodes(runes.take(maxRunes)).trimRight()}\u2026';
}

class _ReaderSearchMemo {
  const _ReaderSearchMemo({
    required this.uid,
    required this.content,
    required this.effectiveDisplayTime,
    required this.updateTime,
  });

  final String uid;
  final String content;
  final DateTime effectiveDisplayTime;
  final DateTime updateTime;
}

int _readSearchInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}
