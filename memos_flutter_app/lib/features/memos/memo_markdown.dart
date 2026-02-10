import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:highlight/highlight.dart' as hi;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_localization.dart';
import '../../i18n/strings.g.dart';

final RegExp _tagTokenPattern = RegExp(
  r'^#(?!#|\s)[\p{L}\p{N}\p{S}_/\-]{1,100}$',
  unicode: true,
);
final RegExp _tagInlinePattern = RegExp(
  r'#(?!#|\s)([\p{L}\p{N}\p{S}_/\-]{1,100})',
  unicode: true,
);
final RegExp _markdownImagePattern = RegExp(r'!\[[^\]]*]\(([^)\s]+)(?:\s+"[^"]*")?\)');
final RegExp _codeFencePattern = RegExp(r'^\s*(```|~~~)');
final RegExp _codeLanguagePattern = RegExp(r'language-([\w]+)', caseSensitive: false);
final RegExp _codeBlockHtmlPattern = RegExp(r'<pre><code([^>]*)>([\s\S]*?)</code></pre>');
final RegExp _longWordPattern = RegExp(r'[^\s]{30,}', unicode: true);

const String _zeroWidthSpace = '\u200B';
const int _longWordChunk = 20;

const String _mathInlineTag = 'memo-math-inline';
const String _mathBlockTag = 'memo-math-block';

const Set<String> _htmlBlockTags = {
  'p',
  'blockquote',
  'ul',
  'ol',
  'dl',
  'table',
  'pre',
  'hr',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  _mathBlockTag,
};

const Set<String> _blockedHtmlTags = {
  'script',
  'style',
};

const Set<String> _allowedHtmlTags = {
  'a',
  'blockquote',
  'br',
  'code',
  'del',
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
  _mathInlineTag,
  _mathBlockTag,
};

const Map<String, Set<String>> _allowedHtmlAttributes = {
  'a': {'href', 'title'},
  'img': {'src', 'alt', 'title', 'width', 'height'},
  'code': {'class'},
  'pre': {'class'},
  'span': {'class', 'data-tag'},
  'li': {'class'},
  'ul': {'class'},
  'ol': {'class'},
  'p': {'class'},
  'input': {'type', 'checked', 'disabled'},
};

final List<RegExp> _allowedClassPatterns = [
  RegExp(r'^memotag$'),
  RegExp(r'^memohighlight$'),
  RegExp(r'^task-list-item$'),
  RegExp(r'^contains-task-list$'),
  RegExp(r'^language-[\w-]+$'),
];

const double _defaultLineHeight = 1.4;

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

final _markdownHtmlCache = _LruCache<String, String>(capacity: 80);

const int _markdownImageMaxDecodePx = 2048;

String _insertSoftBreaks(String text) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(_longWordPattern, (match) {
    final value = match.group(0);
    if (value == null || value.length <= _longWordChunk) return value ?? '';
    final buffer = StringBuffer();
    var count = 0;
    for (final rune in value.runes) {
      buffer.writeCharCode(rune);
      count++;
      if (count >= _longWordChunk) {
        buffer.write(_zeroWidthSpace);
        count = 0;
      }
    }
    return buffer.toString();
  });
}

class _MemoMarkdownWidgetFactory extends WidgetFactory {
  @override
  InlineSpan? buildTextSpan({
    List<InlineSpan>? children,
    GestureRecognizer? recognizer,
    TextStyle? style,
    String? text,
  }) {
    final normalizedText = text == null ? null : _insertSoftBreaks(text);
    return super.buildTextSpan(
      children: children,
      recognizer: recognizer,
      style: style,
      text: normalizedText,
    );
  }
}

void invalidateMemoMarkdownCacheForUid(String memoUid) {
  final trimmed = memoUid.trim();
  if (trimmed.isEmpty) return;
  _markdownHtmlCache.removeWhere((key) => key.startsWith('$trimmed|'));
}

String normalizeMarkdownImageSrc(String value) => _normalizeImageSrc(value);

List<String> extractMarkdownImageUrls(String text) {
  if (text.trim().isEmpty) return const [];
  final urls = <String>[];
  var inFence = false;
  for (final line in text.split('\n')) {
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    for (final match in _markdownImagePattern.allMatches(line)) {
      var url = (match.group(1) ?? '').trim();
      if (url.startsWith('<') && url.endsWith('>') && url.length > 2) {
        url = url.substring(1, url.length - 1).trim();
      }
      url = normalizeMarkdownImageSrc(url);
      if (url.isEmpty) continue;
      urls.add(url);
    }
  }
  return urls;
}

String stripMarkdownImages(String text) {
  if (text.trim().isEmpty) return text;
  final lines = text.split('\n');
  final out = <String>[];
  var inFence = false;
  for (final line in lines) {
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      out.add(line);
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }
    if (line.trim().isEmpty) {
      out.add('');
      continue;
    }
    final cleaned = line.replaceAll(_markdownImagePattern, '').trimRight();
    if (cleaned.trim().isEmpty) continue;
    out.add(cleaned);
  }
  return out.join('\n');
}


typedef TaskToggleHandler = void Function(TaskToggleRequest request);

class TaskToggleRequest {
  const TaskToggleRequest({required this.taskIndex, required this.checked});

  final int taskIndex;
  final bool checked;
}

class MemoMarkdown extends StatelessWidget {
  const MemoMarkdown({
    super.key,
    required this.data,
    this.cacheKey,
    this.textStyle,
    this.maxLines,
    this.normalizeHeadings = false,
    this.selectable = false,
    this.blockSpacing = 6,
    this.shrinkWrap = true,
    this.renderImages = true,
    this.onToggleTask,
  });

  final String data;
  final String? cacheKey;
  final TextStyle? textStyle;
  final int? maxLines;
  final bool normalizeHeadings;
  final bool selectable;
  final double blockSpacing;
  final bool shrinkWrap;
  final bool renderImages;
  final TaskToggleHandler? onToggleTask;

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeTagSpacing(data);
    var sanitized = _sanitizeMarkdown(normalized);
    if (!renderImages) {
      sanitized = stripMarkdownImages(sanitized);
    }
    final trimmed = sanitized.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final tagged = _decorateTagsForHtml(trimmed);

    final theme = Theme.of(context);
    final baseStyle = textStyle ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final fontSize = baseStyle.fontSize;
    final codeStyle = baseStyle.copyWith(
      fontFamily: 'monospace',
      fontSize: fontSize == null ? null : fontSize * 0.9,
    );
    final tagStyle = _MemoTagStyle.resolve(theme);
    final highlightStyle = _MemoHighlightStyle.resolve(theme);
    final inlineCodeBg = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final codeBlockBg = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final quoteColor = (baseStyle.color ?? theme.colorScheme.onSurface).withValues(alpha: 0.7);
    final quoteBorder = theme.colorScheme.primary.withValues(alpha: theme.brightness == Brightness.dark ? 0.45 : 0.35);
    final tableBorder = theme.dividerColor.withValues(alpha: theme.brightness == Brightness.dark ? 0.35 : 0.5);
    final tableHeaderBg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final tableCellBg = theme.colorScheme.surface.withValues(alpha: theme.brightness == Brightness.dark ? 0.4 : 1.0);
    final checkboxSize = (fontSize ?? 14) * 1.25;
    final checkboxTapSize = checkboxSize + 6;
    final checkboxColor = baseStyle.color ?? theme.colorScheme.onSurface;
    final imagePlaceholderBg = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final imagePlaceholderFg = (baseStyle.color ?? theme.colorScheme.onSurface).withValues(alpha: 0.6);
    final spacingPx = blockSpacing > 0 ? _formatCssPx(blockSpacing) : null;
    final maxImageHeight = _resolveImageMaxHeight(context);
    final maxImageHeightPx = _formatCssPx(maxImageHeight);

    Widget imagePlaceholder() {
      return Container(
        color: imagePlaceholderBg,
        alignment: Alignment.center,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: imagePlaceholderFg,
          ),
        ),
      );
    }

    Widget imageError() {
      return Container(
        color: imagePlaceholderBg,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: imagePlaceholderFg,
        ),
      );
    }

    void logImageError(String url, Object error) {
      assert(() {
        debugPrint('MemoMarkdown image failed: $url error=$error');
        return true;
      }());
    }

    final cacheKey = this.cacheKey;
    final cachedHtml = cacheKey == null ? null : _markdownHtmlCache.get(cacheKey);
    final html = cachedHtml ?? _buildMemoHtml(tagged);
    if (cacheKey != null && cachedHtml == null) {
      _markdownHtmlCache.set(cacheKey, html);
    }

    var taskIndex = 0;
    Widget? buildTableWidget(dom.Element element) {
      final rows = element.querySelectorAll('tr');
      if (rows.isEmpty) return null;

      final parsedRows = <({List<dom.Element> cells, bool header})>[];
      var maxColumns = 0;

      for (final row in rows) {
        final cells = row.children
            .where((c) => c.localName == 'th' || c.localName == 'td')
            .toList(growable: false);
        if (cells.isEmpty) continue;
        final header = row.parent?.localName == 'thead' || cells.every((c) => c.localName == 'th');
        if (cells.length > maxColumns) {
          maxColumns = cells.length;
        }
        parsedRows.add((cells: cells, header: header));
      }

      if (parsedRows.isEmpty || maxColumns == 0) return null;

      final table = Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(color: tableBorder, width: 1),
        columnWidths: {
          for (var i = 0; i < maxColumns; i++) i: const FlexColumnWidth(),
        },
        children: [
          for (final row in parsedRows)
            TableRow(
              decoration: row.header ? BoxDecoration(color: tableHeaderBg) : BoxDecoration(color: tableCellBg),
              children: [
                for (var i = 0; i < maxColumns; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      i < row.cells.length ? row.cells[i].text.trim() : '',
                      style: baseStyle.copyWith(
                        fontWeight: row.header ? FontWeight.w700 : baseStyle.fontWeight,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      );

      final wrapped = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320),
          child: table,
        ),
      );

      if (blockSpacing <= 0) return wrapped;
      return Padding(
        padding: EdgeInsets.only(bottom: blockSpacing),
        child: wrapped,
      );
    }

    Widget? customWidgetBuilder(dom.Element element) {
      final localName = element.localName;
      if (localName == _mathInlineTag || localName == _mathBlockTag) {
        final tex = element.text.trim();
        if (tex.isEmpty) return const SizedBox.shrink();
        final isBlock = localName == _mathBlockTag;
        final fontSize = baseStyle.fontSize ?? 14;
        final mathWidget = Math.tex(
          tex,
          mathStyle: isBlock ? MathStyle.display : MathStyle.text,
          textStyle: baseStyle.copyWith(
            fontSize: isBlock ? fontSize * 1.05 : fontSize,
          ),
        );
        if (!isBlock) {
          return InlineCustomWidget(
            alignment: PlaceholderAlignment.middle,
            child: mathWidget,
          );
        }
        final blockChild = Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: mathWidget,
          ),
        );
        if (blockSpacing <= 0) return blockChild;
        return Padding(
          padding: EdgeInsets.only(bottom: blockSpacing),
          child: blockChild,
        );
      }
      if (localName == 'input') {
        final type = element.attributes['type']?.toLowerCase();
        if (type != 'checkbox') return null;
        final checked = element.attributes.containsKey('checked');
        final handler = onToggleTask;
        final currentIndex = taskIndex++;
        final onTap = handler == null
            ? null
            : () => handler(TaskToggleRequest(taskIndex: currentIndex, checked: checked));
        final icon = Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: checkboxSize,
          color: checkboxColor,
        );
        final hitBox = SizedBox.square(
          dimension: checkboxTapSize,
          child: Center(child: icon),
        );
        final checkbox = onTap == null
            ? Padding(
                padding: const EdgeInsets.only(right: 6),
                child: hitBox,
              )
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(4),
                  child: hitBox,
                ),
              );
        return InlineCustomWidget(
          alignment: PlaceholderAlignment.middle,
          child: checkbox,
        );
      }
      if (localName == 'img') {
        if (!renderImages) {
          return const InlineCustomWidget(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox.shrink(),
          );
        }
        final rawSrc = element.attributes['src'];
        if (rawSrc == null) return null;
        final src = _normalizeImageSrc(rawSrc);
        if (src.isEmpty) return null;

        final uri = Uri.tryParse(src);
        final scheme = uri?.scheme.toLowerCase() ?? '';
        if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
          return null;
        }

        final widthAttr = _parseHtmlDimension(element.attributes['width']);
        final heightAttr = _parseHtmlDimension(element.attributes['height']);

        return InlineCustomWidget(
          alignment: PlaceholderAlignment.middle,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = _resolveImageMaxWidth(constraints, context);
              final maxHeight = maxImageHeight;
              double? targetWidth = widthAttr;
              double? targetHeight = heightAttr;

              if (targetWidth != null && targetWidth > 0 && targetHeight != null && targetHeight > 0) {
                final widthScale = maxWidth / targetWidth;
                final heightScale = maxHeight / targetHeight;
                final scale = [1.0, widthScale, heightScale].reduce((a, b) => a < b ? a : b);
                targetWidth = targetWidth * scale;
                targetHeight = targetHeight * scale;
              } else {
                if (targetWidth != null && targetWidth > 0) {
                  if (targetWidth > maxWidth) targetWidth = maxWidth;
                } else {
                  targetWidth = null;
                }
                if (targetHeight != null && targetHeight > 0) {
                  if (targetHeight > maxHeight) targetHeight = maxHeight;
                } else {
                  targetHeight = null;
                }
              }

              final pixelRatio = MediaQuery.of(context).devicePixelRatio;
              final cacheWidth = _resolveCacheExtent(targetWidth ?? maxWidth, pixelRatio);

              final image = Image.network(
                src,
                width: targetWidth,
                height: targetHeight,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return imagePlaceholder();
                },
                errorBuilder: (context, error, stackTrace) {
                  logImageError(src, error);
                  return imageError();
                },
              );

              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: image,
                ),
              );
            },
          ),
        );
      }
      if (localName == 'pre') {
        final codeElement = element.querySelector('code');
        final code = _trimTrailingNewline(codeElement?.text ?? element.text);
        if (code.trim().isEmpty) return null;
        final language = _extractCodeLanguage(codeElement);
        return _buildHtmlCodeBlock(
          code: code,
          language: language,
          baseStyle: codeStyle,
          isDark: theme.brightness == Brightness.dark,
          background: codeBlockBg,
        );
      }
      if (localName == 'table') {
        return buildTableWidget(element);
      }
      return null;
    }

    Map<String, String>? customStylesBuilder(dom.Element element) {
      final localName = element.localName;
      if (localName == null) return null;
      final styles = <String, String>{};
      if (localName == 'span') {
        if (element.classes.contains('memotag')) {
          styles.addAll({
            'background-color': _cssColor(tagStyle.background),
            'color': _cssColor(tagStyle.textColor),
            'border': '1px solid ${_cssColor(tagStyle.borderColor)}',
            'border-radius': '999px',
            'padding': '2px 10px',
            'font-weight': '600',
            'display': 'inline-block',
            'line-height': '1.2',
            'font-size': '0.92em',
            'vertical-align': 'middle',
          });
        } else if (element.classes.contains('memohighlight')) {
          styles.addAll({
            'background-color': _cssColor(highlightStyle.background),
            'border': '1px solid ${_cssColor(highlightStyle.borderColor)}',
            'border-radius': '4px',
            'padding': '1px 4px',
            'display': 'inline-block',
          });
        }
      }
      if (localName == 'code' && element.parent?.localName != 'pre') {
        styles.addAll({
          'font-family': 'monospace',
          'background-color': _cssColor(inlineCodeBg),
          'padding': '0 3px',
          'border-radius': '4px',
          'font-size': '0.95em',
        });
      }
      if (localName == 'blockquote') {
        styles['color'] = _cssColor(quoteColor);
        styles['border-left'] = '3px solid ${_cssColor(quoteBorder)}';
        styles['padding-left'] = '10px';
      }
      if (localName == 'p' && element.parent?.classes.contains('task-list-item') == true) {
        styles['display'] = 'inline';
        styles['margin'] = '0';
      }
      if (localName == 'li' && element.classes.contains('task-list-item')) {
        styles['list-style-type'] = 'none';
      }
      if ((localName == 'ul' || localName == 'ol') && element.classes.contains('contains-task-list')) {
        styles.addAll({
          'list-style-type': 'none',
          'padding-left': '0',
        });
      }
      if (localName == 'img') {
        if (renderImages) {
          styles.addAll({
            'max-width': '100%',
            'max-height': maxImageHeightPx,
            'height': 'auto',
          });
        }
      }
      if (normalizeHeadings && _isHeadingTag(localName)) {
        styles['font-size'] = '1em';
        styles['font-weight'] = '700';
      }
      if (spacingPx != null && _htmlBlockTags.contains(localName)) {
        final isTaskParagraph = localName == 'p' && element.parent?.classes.contains('task-list-item') == true;
        if (!isTaskParagraph) {
          styles['margin'] = '0 0 $spacingPx 0';
        }
      }
      return styles.isEmpty ? null : styles;
    }

    final renderMode = shrinkWrap ? RenderMode.column : const ListViewMode(shrinkWrap: false);
    Widget content = HtmlWidget(
      html,
      factoryBuilder: () => _MemoMarkdownWidgetFactory(),
      renderMode: renderMode,
      textStyle: baseStyle,
      customWidgetBuilder: customWidgetBuilder,
      customStylesBuilder: customStylesBuilder,
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null) return true;
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.strings.legacy.msg_unable_open_browser_install_browser_app,
              ),
            ),
          );
        }
        return true;
      },
    );

    final maxLines = this.maxLines;
    if (maxLines != null && maxLines > 0) {
      final fontSize = baseStyle.fontSize ?? 14;
      final lineHeight = baseStyle.height ?? _defaultLineHeight;
      final maxHeight = fontSize * lineHeight * maxLines;
      content = ClipRect(
        child: SizedBox(
          height: maxHeight,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: 0,
            maxHeight: double.infinity,
            child: content,
          ),
        ),
      );
    }

    if (!selectable) return content;
    return SelectionArea(child: content);
  }
}

String _sanitizeMarkdown(String text) {
  // Avoid empty markdown links that can leave the inline stack open.
  final emptyLink = RegExp(r'\[\s*\]\(([^)]*)\)');
  final stripped = text.replaceAllMapped(emptyLink, (match) {
    final start = match.start;
    if (start > 0 && text.codeUnitAt(start - 1) == 0x21) {
      return match.group(0) ?? '';
    }
    final url = match.group(1)?.trim();
    return url?.isNotEmpty == true ? url! : '';
  });
  return _normalizeFencedCodeBlocks(_escapeEmptyTaskHeadings(stripped));
}

String _escapeEmptyTaskHeadings(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = RegExp(r'^(\s*[-*+]\s+\[(?: |x|X)\]\s*)(#{1,6})\s*$').firstMatch(lines[i]);
    if (match == null) continue;
    final prefix = match.group(1) ?? '';
    final hashes = match.group(2) ?? '';
    final escaped = List.filled(hashes.length, r'\#').join();
    lines[i] = '$prefix$escaped';
  }
  return lines.join('\n');
}

String _normalizeFencedCodeBlocks(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;
    var index = 0;
    while (index < line.length) {
      final codeUnit = line.codeUnitAt(index);
      if (codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x3000) {
        index++;
        continue;
      }
      break;
    }
    if (index == 0) continue;
    final trimmed = line.substring(index);
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      final indent = index > 3 ? 3 : index;
      lines[i] = '${''.padLeft(indent)}$trimmed';
    }
  }
  return lines.join('\n');
}

String _normalizeTagSpacing(String text) {
  final lines = text.split('\n');
  var idx = 0;
  while (idx < lines.length && lines[idx].trim().isEmpty) {
    idx++;
  }

  var tagEnd = idx;
  while (tagEnd < lines.length && _isTagOnlyLine(lines[tagEnd])) {
    tagEnd++;
  }

  if (tagEnd == idx) return text;

  var blankEnd = tagEnd;
  while (blankEnd < lines.length && lines[blankEnd].trim().isEmpty) {
    blankEnd++;
  }
  if (blankEnd == tagEnd || blankEnd >= lines.length) return text;

  final normalized = <String>[
    ...lines.take(tagEnd),
    '',
    ...lines.skip(blankEnd),
  ];
  return normalized.join('\n');
}

bool _isTagOnlyLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  final parts = trimmed.split(RegExp(r'\s+'));
  for (final part in parts) {
    if (!_tagTokenPattern.hasMatch(part)) return false;
  }
  return true;
}

String _decorateTagsForHtml(String text) {
  final lines = text.split('\n');
  int? firstLine;
  int? lastLine;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    firstLine ??= i;
    lastLine = i;
  }
  if (firstLine == null || lastLine == null) return text;

  lines[firstLine] = _replaceTagsInLine(lines[firstLine]);
  if (lastLine != firstLine) {
    lines[lastLine] = _replaceTagsInLine(lines[lastLine]);
  }

  return lines.join('\n');
}

String _replaceTagsInLine(String line) {
  final matches = _tagInlinePattern.allMatches(line);
  if (matches.isEmpty) return line;

  final buffer = StringBuffer();
  var last = 0;
  for (final match in matches) {
    buffer.write(line.substring(last, match.start));
    final tag = match.group(1);
    if (tag == null || tag.isEmpty) {
      buffer.write(match.group(0));
    } else {
      final escaped = _escapeHtmlAttribute(tag);
      buffer.write('<span class="memotag" data-tag="$escaped">#$tag</span>');
    }
    last = match.end;
  }
  buffer.write(line.substring(last));
  return buffer.toString();
}

String _escapeHtmlAttribute(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _buildMemoHtml(String text) {
  final rawHtml = _renderMarkdownToHtml(text);
  final sanitized = _sanitizeHtml(rawHtml);
  return _escapeCodeBlocks(sanitized);
}

String _sanitizeHtml(String html) {
  final fragment = html_parser.parseFragment(html);
  _sanitizeDomNode(fragment);
  return fragment.outerHtml;
}

void _sanitizeDomNode(dom.Node node) {
  final children = node.nodes.toList(growable: false);
  for (final child in children) {
    if (child is dom.Element) {
      _sanitizeElement(child);
      continue;
    }
    if (child.nodeType == dom.Node.COMMENT_NODE) {
      child.remove();
    }
  }
}

void _sanitizeElement(dom.Element element) {
  final tag = element.localName;
  if (tag == null) {
    element.remove();
    return;
  }
  if (_blockedHtmlTags.contains(tag)) {
    element.remove();
    return;
  }
  if (!_allowedHtmlTags.contains(tag)) {
    _unwrapElement(element);
    return;
  }
  if (!_sanitizeAttributes(element, tag)) {
    return;
  }
  _sanitizeDomNode(element);
}

bool _sanitizeAttributes(dom.Element element, String tag) {
  final allowedAttrs = _allowedHtmlAttributes[tag] ?? const <String>{};
  final attributes = Map<String, String>.from(element.attributes);
  element.attributes.clear();
  for (final entry in attributes.entries) {
    if (!allowedAttrs.contains(entry.key)) continue;
    element.attributes[entry.key] = entry.value;
  }

  if (element.attributes.containsKey('class')) {
    final filtered = _filterClasses(element.attributes['class']);
    if (filtered == null) {
      element.attributes.remove('class');
    } else {
      element.attributes['class'] = filtered;
    }
  }

  if (tag == 'a') {
    final href = _sanitizeUrl(element.attributes['href'], allowRelative: true, allowMailto: true);
    if (href == null) {
      _unwrapElement(element);
      return false;
    }
    element.attributes['href'] = href;
  }

  if (tag == 'img') {
    final src = _sanitizeUrl(element.attributes['src'], allowRelative: true, allowMailto: false);
    if (src == null) {
      element.remove();
      return false;
    }
    element.attributes['src'] = src;
  }

  if (tag == 'input') {
    final type = element.attributes['type']?.toLowerCase();
    if (type != 'checkbox') {
      element.remove();
      return false;
    }
  }

  return true;
}

String? _filterClasses(String? value) {
  if (value == null) return null;
  final classes = value
      .split(RegExp(r'\s+'))
      .where((c) => c.isNotEmpty && _isAllowedClass(c))
      .toList(growable: false);
  if (classes.isEmpty) return null;
  return classes.join(' ');
}

bool _isAllowedClass(String value) {
  for (final pattern in _allowedClassPatterns) {
    if (pattern.hasMatch(value)) return true;
  }
  return false;
}

String? _sanitizeUrl(
  String? url, {
  required bool allowRelative,
  required bool allowMailto,
}) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.hasScheme) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') return trimmed;
    if (allowMailto && scheme == 'mailto') return trimmed;
    return null;
  }
  if (!allowRelative) return null;
  return trimmed;
}

void _unwrapElement(dom.Element element) {
  final parent = element.parent;
  if (parent == null) {
    element.remove();
    return;
  }
  final index = parent.nodes.indexOf(element);
  final children = element.nodes.toList(growable: false);
  element.remove();
  if (children.isNotEmpty) {
    parent.nodes.insertAll(index, children);
    for (final child in children) {
      _sanitizeDomNode(child);
    }
  }
}

String _renderMarkdownToHtml(String text) {
  return md.markdownToHtml(
    text,
    extensionSet: md.ExtensionSet.gitHubFlavored,
    blockSyntaxes: const [
      _MathBlockSyntax(),
      _MathBracketBlockSyntax(),
    ],
    inlineSyntaxes: [
      _MathInlineSyntax(),
      _MathParenInlineSyntax(),
      _HtmlSoftLineBreakSyntax(),
      _HtmlHighlightInlineSyntax(),
    ],
    encodeHtml: false,
  );
}

Widget _buildHtmlCodeBlock({
  required String code,
  String? language,
  required TextStyle baseStyle,
  required bool isDark,
  required Color background,
}) {
  return _MemoCodeBlock(
    code: code,
    language: language,
    baseStyle: baseStyle,
    isDark: isDark,
    background: background,
  );
}

String _cssColor(Color color) {
  int toChannel(double value) => (value * 255).round().clamp(0, 255);

  final r = toChannel(color.r);
  final g = toChannel(color.g);
  final b = toChannel(color.b);
  final alpha = color.a.clamp(0.0, 1.0);

  if (alpha >= 1.0) {
    return '#'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
  final opacity = alpha.clamp(0.0, 1.0).toStringAsFixed(2);
  return 'rgba($r, $g, $b, $opacity)';
}

String _formatCssPx(double value) {
  final rounded = value.roundToDouble();
  if (rounded == value) {
    return '${value.toInt()}px';
  }
  return '${value.toStringAsFixed(2)}px';
}

String _trimTrailingNewline(String value) {
  if (value.endsWith('\r\n')) {
    return value.substring(0, value.length - 2);
  }
  if (value.endsWith('\n')) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

String _escapeHtmlText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _escapeCodeBlocks(String html) {
  return html.replaceAllMapped(_codeBlockHtmlPattern, (match) {
    final attrs = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    return '<pre><code$attrs>${_escapeHtmlText(content)}</code></pre>';
  });
}

String? _extractCodeLanguage(dom.Element? codeElement) {
  if (codeElement == null) return null;
  final classAttr = codeElement.attributes['class'] ?? '';
  final match = _codeLanguagePattern.firstMatch(classAttr);
  final language = match?.group(1);
  if (language == null || language.isEmpty) return null;
  return language;
}

String _normalizeImageSrc(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  return trimmed;
}

double? _parseHtmlDimension(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^\d+(?:\.\d+)?').firstMatch(trimmed);
  if (match == null) return null;
  return double.tryParse(match.group(0)!);
}

double _resolveImageMaxWidth(BoxConstraints constraints, BuildContext context) {
  final maxWidth = constraints.maxWidth;
  if (maxWidth.isFinite && maxWidth > 0) return maxWidth;
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth > 0) return screenWidth;
  return 320;
}

int? _resolveCacheExtent(double logicalExtent, double devicePixelRatio) {
  if (logicalExtent <= 0) return null;
  final pixels = (logicalExtent * devicePixelRatio).round();
  if (pixels <= 0) return null;
  return pixels > _markdownImageMaxDecodePx ? _markdownImageMaxDecodePx : pixels;
}

double _resolveImageMaxHeight(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  if (screenHeight <= 0) return 360;
  final suggested = (screenHeight * 0.45).clamp(300.0, 400.0);
  final maxAllowed = screenHeight * 0.5;
  return suggested > maxAllowed ? maxAllowed : suggested;
}

class TaskStats {
  const TaskStats({required this.total, required this.checked});

  final int total;
  final int checked;
}

TaskStats countTaskStats(String content, {bool skipQuotedLines = false}) {
  final fenceRegex = RegExp(r'^\s*(```|~~~)');
  final taskRegex = RegExp(r'^\s*[-*+]\s+\[( |x|X)\]');

  var inFence = false;
  var total = 0;
  var checked = 0;

  for (final line in content.split('\n')) {
    if (fenceRegex.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    // Ignore task markers inside fenced code blocks or filtered quote lines.
    if (inFence) continue;
    if (skipQuotedLines && line.trimLeft().startsWith('>')) continue;

    final match = taskRegex.firstMatch(line);
    if (match == null) continue;
    total++;
    final mark = match.group(1) ?? '';
    if (mark.toLowerCase() == 'x') {
      checked++;
    }
  }

  return TaskStats(total: total, checked: checked);
}

double calculateProgress(String content, {bool skipQuotedLines = false}) {
  final stats = countTaskStats(content, skipQuotedLines: skipQuotedLines);
  if (stats.total == 0) return 0.0;
  return stats.checked / stats.total;
}

String toggleCheckbox(String rawContent, int checkboxIndex, {bool skipQuotedLines = false}) {
  final fenceRegex = RegExp(r'^\s*(```|~~~)');
  final taskRegex = RegExp(r'^(\s*[-*+]\s+)\[( |x|X)\]');

  var inFence = false;
  var index = 0;
  var offset = 0;
  final lines = rawContent.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (fenceRegex.hasMatch(line)) {
      inFence = !inFence;
      offset += line.length + (i == lines.length - 1 ? 0 : 1);
      continue;
    }

    final skipLine = inFence || (skipQuotedLines && line.trimLeft().startsWith('>'));
    if (!skipLine) {
      final match = taskRegex.firstMatch(line);
      if (match != null) {
        // Count only task markers in visible, non-code lines to match UI order.
        if (index == checkboxIndex) {
          final leading = match.group(1)!;
          final mark = match.group(2) ?? ' ';
          final newMark = mark.toLowerCase() == 'x' ? ' ' : 'x';
          // Mark position: offset + leading + '['.
          final markOffset = offset + match.start + leading.length + 1;
          return rawContent.replaceRange(markOffset, markOffset + 1, newMark);
        }
        index++;
      }
    }

    offset += line.length + (i == lines.length - 1 ? 0 : 1);
  }

  return rawContent;
}

bool _isHeadingTag(String tag) {
  if (tag.length != 2 || tag[0] != 'h') return false;
  final unit = tag.codeUnitAt(1);
  return unit >= 0x31 && unit <= 0x36;
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


class _MemoTagStyle {
  const _MemoTagStyle({
    required this.background,
    required this.textColor,
    required this.borderColor,
  });

  final Color background;
  final Color textColor;
  final Color borderColor;

  static _MemoTagStyle resolve(ThemeData theme) {
    final background = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onPrimary;
    final borderColor = background.withValues(alpha: 0.7);
    return _MemoTagStyle(
      background: background,
      textColor: textColor,
      borderColor: borderColor,
    );
  }
}

class _MemoHighlightStyle {
  const _MemoHighlightStyle({
    required this.background,
    required this.borderColor,
  });

  final Color background;
  final Color borderColor;

  static _MemoHighlightStyle resolve(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.colorScheme.primary;
    return _MemoHighlightStyle(
      background: base.withValues(alpha: isDark ? 0.35 : 0.18),
      borderColor: base.withValues(alpha: isDark ? 0.55 : 0.35),
    );
  }
}

class MemoCodeHighlighter {
  MemoCodeHighlighter({
    required this.baseStyle,
    required this.isDark,
  });

  final TextStyle baseStyle;
  final bool isDark;

  static final RegExp _commentPattern = RegExp(
    r'(?:\/\/.*?$)|(?:\/\*[\s\S]*?\*\/)|(?:#.*?$)',
    multiLine: true,
  );
  static final RegExp _stringPattern = RegExp(
    "(?:'''[\\s\\S]*?'''|\\\"\\\"\\\"[\\s\\S]*?\\\"\\\"\\\"|'(?:\\\\.|[^'\\\\])*'|\\\"(?:\\\\.|[^\\\"\\\\])*\\\")",
  );
  static final RegExp _annotationPattern = RegExp(r'@\w+');
  static final RegExp _keywordPattern = RegExp(
    r'\b(?:abstract|as|assert|async|await|break|case|catch|class|const|continue|default|defer|do|else|enum|export|extends|'
    r'extension|external|false|final|finally|for|function|get|if|implements|import|in|interface|is|late|library|mixin|new|null|'
    r'operator|part|private|protected|public|required|return|sealed|set|static|super|switch|sync|this|throw|true|try|typedef|'
    r'var|void|while|with|yield)\b',
  );
  static final RegExp _numberPattern = RegExp(r'\b\d+(?:\.\d+)?\b');

  TextSpan format(String source) {
    if (source.isEmpty) return const TextSpan(text: '');

    final commentColor = isDark ? const Color(0xFF7C8895) : const Color(0xFF6A737D);
    final stringColor = isDark ? const Color(0xFF98C379) : const Color(0xFF22863A);
    final keywordColor = isDark ? const Color(0xFF7AA2F7) : const Color(0xFF005CC5);
    final numberColor = isDark ? const Color(0xFFD19A66) : const Color(0xFFB45500);
    final annotationColor = isDark ? const Color(0xFF56B6C2) : const Color(0xFF22863A);

    final rules = <_CodeHighlightRule>[
      _CodeHighlightRule(_commentPattern, baseStyle.copyWith(color: commentColor, fontStyle: FontStyle.italic)),
      _CodeHighlightRule(_stringPattern, baseStyle.copyWith(color: stringColor)),
      _CodeHighlightRule(_annotationPattern, baseStyle.copyWith(color: annotationColor)),
      _CodeHighlightRule(_keywordPattern, baseStyle.copyWith(color: keywordColor, fontWeight: FontWeight.w600)),
      _CodeHighlightRule(_numberPattern, baseStyle.copyWith(color: numberColor)),
    ];

    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var index = 0;

    void flushBuffer() {
      if (buffer.length == 0) return;
      spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
      buffer.clear();
    }

    while (index < source.length) {
      _CodeHighlightRule? matchedRule;
      Match? match;
      for (final rule in rules) {
        final candidate = rule.pattern.matchAsPrefix(source, index);
        if (candidate == null) continue;
        matchedRule = rule;
        match = candidate;
        break;
      }

      if (match == null || matchedRule == null) {
        buffer.write(source[index]);
        index += 1;
        continue;
      }

      flushBuffer();
      spans.add(TextSpan(text: match.group(0), style: matchedRule.style));
      index = match.end;
    }

    flushBuffer();
    return TextSpan(style: baseStyle, children: spans);
  }
}

class _CodeHighlightRule {
  const _CodeHighlightRule(this.pattern, this.style);

  final RegExp pattern;
  final TextStyle style;
}

class _MemoCodeBlock extends StatefulWidget {
  const _MemoCodeBlock({
    required this.code,
    required this.language,
    required this.baseStyle,
    required this.isDark,
    required this.background,
  });

  final String code;
  final String? language;
  final TextStyle baseStyle;
  final bool isDark;
  final Color background;

  @override
  State<_MemoCodeBlock> createState() => _MemoCodeBlockState();
}

class _MemoCodeBlockState extends State<_MemoCodeBlock> {
  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.baseStyle.color ?? theme.colorScheme.onSurface;
    final labelStyle = widget.baseStyle.copyWith(
      fontSize: (widget.baseStyle.fontSize ?? 14) * 0.72,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: baseColor.withValues(alpha: 0.6),
    );
    final label = widget.language == null ? '' : widget.language!.toUpperCase();
    final iconColor = _copied ? theme.colorScheme.primary : labelStyle.color;
    final icon = _copied ? Icons.check_rounded : Icons.copy_rounded;
    final highlightSpan = _buildHighlightedSpan(
      code: widget.code,
      baseStyle: widget.baseStyle,
      isDark: widget.isDark,
      language: widget.language,
    );

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: labelStyle),
                ),
                InkWell(
                  onTap: _handleCopy,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: RichText(
                text: highlightSpan,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MathInlineSyntax extends md.InlineSyntax {
  _MathInlineSyntax() : super(r'\$(?!\s)([^\n\$]+?)\$(?!\s)', startCharacter: 0x24);

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

TextSpan _buildHighlightedSpan({
  required String code,
  required TextStyle baseStyle,
  required bool isDark,
  String? language,
}) {
  final normalized = language?.trim();
  if (normalized == null || normalized.isEmpty) {
    return TextSpan(text: code, style: baseStyle);
  }

  final result = hi.highlight.parse(code, language: normalized.toLowerCase());
  final theme = _MemoCodeHighlightTheme.resolve(isDark: isDark);
  final children = _buildHighlightSpans(result.nodes ?? const <hi.Node>[], baseStyle, theme);
  return TextSpan(style: baseStyle, children: children);
}

List<TextSpan> _buildHighlightSpans(
  List<hi.Node> nodes,
  TextStyle parentStyle,
  _MemoCodeHighlightTheme theme,
) {
  final spans = <TextSpan>[];
  for (final node in nodes) {
    final style = _resolveHighlightStyle(node.className, parentStyle, theme);
    if (node.value != null) {
      spans.add(TextSpan(text: node.value, style: style));
    } else if (node.children != null) {
      spans.add(TextSpan(
        style: style,
        children: _buildHighlightSpans(node.children!, style, theme),
      ));
    }
  }
  return spans;
}

TextStyle _resolveHighlightStyle(
  String? className,
  TextStyle parentStyle,
  _MemoCodeHighlightTheme theme,
) {
  if (className == null || className.isEmpty) return parentStyle;
  var style = parentStyle;
  for (final part in className.split(RegExp(r'\s+'))) {
    for (var token in part.split('.')) {
      if (token.startsWith('hljs-')) {
        token = token.substring(5);
      }
      final mapped = theme.styles[token];
      if (mapped != null) {
        style = style.merge(mapped);
      }
    }
  }
  return style;
}

class _MemoCodeHighlightTheme {
  const _MemoCodeHighlightTheme(this.styles);

  final Map<String, TextStyle> styles;

  static _MemoCodeHighlightTheme resolve({required bool isDark}) {
    final commentColor = isDark ? const Color(0xFF7C8895) : const Color(0xFF6A737D);
    final stringColor = isDark ? const Color(0xFF98C379) : const Color(0xFF22863A);
    final keywordColor = isDark ? const Color(0xFF7AA2F7) : const Color(0xFF005CC5);
    final numberColor = isDark ? const Color(0xFFD19A66) : const Color(0xFFB45500);
    final titleColor = isDark ? const Color(0xFFC678DD) : const Color(0xFF6F42C1);
    final attributeColor = isDark ? const Color(0xFFE5C07B) : const Color(0xFFE36209);
    final tagColor = stringColor;
    final metaColor = isDark ? const Color(0xFFC9D1D9) : const Color(0xFF24292E);
    final additionColor = isDark ? const Color(0xFF2EA043) : const Color(0xFF22863A);
    final deletionColor = isDark ? const Color(0xFFF85149) : const Color(0xFFCB2431);

    return _MemoCodeHighlightTheme({
      'comment': TextStyle(color: commentColor, fontStyle: FontStyle.italic),
      'quote': TextStyle(color: commentColor, fontStyle: FontStyle.italic),
      'string': TextStyle(color: stringColor),
      'regexp': TextStyle(color: stringColor),
      'template-string': TextStyle(color: stringColor),
      'keyword': TextStyle(color: keywordColor, fontWeight: FontWeight.w600),
      'built_in': TextStyle(color: keywordColor),
      'literal': TextStyle(color: keywordColor),
      'type': TextStyle(color: keywordColor),
      'selector-tag': TextStyle(color: tagColor),
      'tag': TextStyle(color: tagColor),
      'name': TextStyle(color: tagColor),
      'number': TextStyle(color: numberColor),
      'symbol': TextStyle(color: numberColor),
      'bullet': TextStyle(color: numberColor),
      'attr': TextStyle(color: attributeColor),
      'attribute': TextStyle(color: attributeColor),
      'property': TextStyle(color: attributeColor),
      'params': TextStyle(color: attributeColor),
      'variable': TextStyle(color: attributeColor),
      'selector-attr': TextStyle(color: attributeColor),
      'selector-class': TextStyle(color: attributeColor),
      'selector-id': TextStyle(color: attributeColor),
      'selector-pseudo': TextStyle(color: attributeColor),
      'title': TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      'function': TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      'class': TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      'section': TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      'meta': TextStyle(color: metaColor),
      'operator': TextStyle(color: metaColor),
      'punctuation': TextStyle(color: metaColor),
      'subst': TextStyle(color: metaColor),
      'meta-keyword': TextStyle(color: keywordColor, fontWeight: FontWeight.w600),
      'meta-string': TextStyle(color: stringColor),
      'addition': TextStyle(color: additionColor),
      'deletion': TextStyle(color: deletionColor),
    });
  }
}
