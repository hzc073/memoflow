import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:highlight/highlight.dart' as hi;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../core/image_formats.dart';
import '../../core/image_error_logger.dart';
import '../../core/log_sanitizer.dart';
import '../../core/memo_content_diagnostics.dart';
import '../../core/tags.dart';
import '../../core/url.dart';
import '../../data/logs/log_manager.dart';
import '../../i18n/strings.g.dart';
import '../../state/tags/tag_color_lookup.dart';
import 'memo_image_src_normalizer.dart';
import 'memo_render_pipeline.dart';

export 'memo_image_src_normalizer.dart';
export 'memo_task_list_service.dart';

final RegExp _codeLanguagePattern = RegExp(
  r'language-([\w]+)',
  caseSensitive: false,
);
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
  'details',
  _mathBlockTag,
};

const double _defaultLineHeight = 1.4;
final MemoRenderPipeline _memoRenderPipeline = MemoRenderPipeline();
final Set<String> _memoMarkdownDiagnosticLogKeys = <String>{};

const int _markdownImageMaxDecodePx = 2048;

({String url, Map<String, String>? headers})?
resolveMemoMarkdownRemoteImageRequest({
  required String rawSrc,
  Uri? baseUrl,
  String? authHeader,
  bool rebaseAbsoluteFileUrlForV024 = false,
  bool attachAuthForSameOriginAbsolute = false,
}) {
  final trimmed = normalizeMarkdownImageSrc(rawSrc);
  if (trimmed.isEmpty) return null;

  final parsed = Uri.tryParse(trimmed);
  final scheme = parsed?.scheme.toLowerCase() ?? '';
  if (scheme == 'file' || scheme == 'content') {
    return null;
  }

  final rawWasRelative = !isAbsoluteUrl(trimmed);
  var resolved = resolveMaybeRelativeUrl(baseUrl, trimmed);
  if (rebaseAbsoluteFileUrlForV024) {
    final rebased = rebaseAbsoluteFileUrlToBase(baseUrl, resolved);
    if (rebased != null && rebased.isNotEmpty) {
      resolved = rebased;
    }
  }

  final sameOriginAbsolute = isSameOriginWithBase(baseUrl, resolved);
  final shouldAttachAuth =
      (rawWasRelative && baseUrl != null) ||
      sameOriginAbsolute ||
      (attachAuthForSameOriginAbsolute && sameOriginAbsolute);
  final effectiveAuthHeader = authHeader?.trim() ?? '';
  final headers = shouldAttachAuth && effectiveAuthHeader.isNotEmpty
      ? <String, String>{'Authorization': effectiveAuthHeader}
      : null;

  return (url: resolved, headers: headers);
}

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
  _memoRenderPipeline.invalidateByMemoUid(memoUid);
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
    this.highlightQuery,
    this.textStyle,
    this.maxLines,
    this.normalizeHeadings = false,
    this.selectable = false,
    this.blockSpacing = 6,
    this.shrinkWrap = true,
    this.renderImages = true,
    this.tagColors,
    this.onToggleTask,
    this.baseUrl,
    this.authHeader,
    this.rebaseAbsoluteFileUrlForV024 = false,
    this.attachAuthForSameOriginAbsolute = false,
  });

  final String data;
  final String? cacheKey;
  final String? highlightQuery;
  final TextStyle? textStyle;
  final int? maxLines;
  final bool normalizeHeadings;
  final bool selectable;
  final double blockSpacing;
  final bool shrinkWrap;
  final bool renderImages;
  final TagColorLookup? tagColors;
  final TaskToggleHandler? onToggleTask;
  final Uri? baseUrl;
  final String? authHeader;
  final bool rebaseAbsoluteFileUrlForV024;
  final bool attachAuthForSameOriginAbsolute;

  @override
  Widget build(BuildContext context) {
    final artifact = _memoRenderPipeline.build(
      data: data,
      renderImages: renderImages,
      highlightQuery: highlightQuery,
      cacheKey: cacheKey,
    );
    final contentText = artifact.content;
    if (contentText.trim().isEmpty) return const SizedBox.shrink();
    _logMemoMarkdownDiagnostics(
      contentText,
      cacheKey: cacheKey,
      renderImages: renderImages,
      selectable: selectable,
      maxLines: maxLines,
      normalizeHeadings: normalizeHeadings,
    );

    final theme = Theme.of(context);
    final baseStyle =
        textStyle ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final fontSize = baseStyle.fontSize;
    final codeStyle = baseStyle.copyWith(
      fontFamily: 'monospace',
      fontSize: fontSize == null ? null : fontSize * 0.9,
    );
    final tagStyle = _MemoTagStyle.resolve(theme);
    final tagColorLookup = tagColors;
    final highlightStyle = _MemoHighlightStyle.resolve(theme);
    final inlineCodeBg =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final codeBlockBg =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final quoteColor = (baseStyle.color ?? theme.colorScheme.onSurface)
        .withValues(alpha: 0.7);
    final quoteBorder = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.35,
    );
    final tableBorder = theme.dividerColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.5,
    );
    final tableHeaderBg = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.7,
    );
    final tableCellBg = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.4 : 1.0,
    );
    final checkboxSize = (fontSize ?? 14) * 1.25;
    final checkboxTapSize = checkboxSize + 6;
    final checkboxColor = baseStyle.color ?? theme.colorScheme.onSurface;
    final imagePlaceholderBg =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final imagePlaceholderFg = (baseStyle.color ?? theme.colorScheme.onSurface)
        .withValues(alpha: 0.6);
    final spacingPx = blockSpacing > 0 ? _formatCssPx(blockSpacing) : null;
    final maxImageHeight = _resolveImageMaxHeight(context);
    final maxImageHeightPx = _formatCssPx(maxImageHeight);

    if (artifact.mode == MemoRenderMode.codeBlock) {
      Widget content = _buildHtmlCodeBlock(
        code: contentText,
        language: 'html',
        baseStyle: codeStyle,
        isDark: theme.brightness == Brightness.dark,
        background: codeBlockBg,
      );
      if (blockSpacing > 0) {
        content = Padding(
          padding: EdgeInsets.only(bottom: blockSpacing),
          child: content,
        );
      }

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
        child: Icon(Icons.broken_image_outlined, color: imagePlaceholderFg),
      );
    }

    void logImageError(String url, Object error, StackTrace? stackTrace) {
      logImageLoadError(
        scope: 'memo_markdown_html_img',
        source: url,
        error: error,
        stackTrace: stackTrace,
        extraContext: <String, Object?>{
          'renderImages': renderImages,
          'cacheKey': cacheKey,
        },
      );
      assert(() {
        final safeUrl = LogSanitizer.redactWithFingerprint(url, kind: 'source');
        final safeError = LogSanitizer.sanitizeText(error.toString());
        debugPrint('MemoMarkdown image failed: $safeUrl error=$safeError');
        return true;
      }());
    }

    final renderedHtml = tagColorLookup == null
        ? contentText
        : _rewriteMemoTagLabels(contentText, tagColorLookup);

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
        final header =
            row.parent?.localName == 'thead' ||
            cells.every((c) => c.localName == 'th');
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
              decoration: row.header
                  ? BoxDecoration(color: tableHeaderBg)
                  : BoxDecoration(color: tableCellBg),
              children: [
                for (var i = 0; i < maxColumns; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      i < row.cells.length ? row.cells[i].text.trim() : '',
                      style: baseStyle.copyWith(
                        fontWeight: row.header
                            ? FontWeight.w700
                            : baseStyle.fontWeight,
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
            : () => handler(
                TaskToggleRequest(taskIndex: currentIndex, checked: checked),
              );
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
            ? Padding(padding: const EdgeInsets.only(right: 6), child: hitBox)
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(4),
                    child: hitBox,
                  ),
                ),
              );
        return InlineCustomWidget(
          alignment: PlaceholderAlignment.middle,
          child: checkbox,
        );
      }
      if (localName == 'img') {
        final rawSrc = element.attributes['src'];
        if (rawSrc == null) return null;
        final src = normalizeMarkdownImageSrc(rawSrc);
        if (src.isEmpty) return null;
        if (!renderImages) {
          _logMemoMarkdownHtmlImageWhileDisabled(
            contentText,
            cacheKey: cacheKey,
            src: src,
          );
          return const SizedBox.shrink();
        }

        final uri = Uri.tryParse(src);
        final scheme = uri?.scheme.toLowerCase() ?? '';
        if (scheme.isNotEmpty &&
            scheme != 'http' &&
            scheme != 'https' &&
            scheme != 'file') {
          return null;
        }
        final localFile = scheme == 'file' && uri != null
            ? File.fromUri(uri)
            : null;
        final remoteImageRequest = localFile == null
            ? resolveMemoMarkdownRemoteImageRequest(
                rawSrc: src,
                baseUrl: baseUrl,
                authHeader: authHeader,
                rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
                attachAuthForSameOriginAbsolute:
                    attachAuthForSameOriginAbsolute,
              )
            : null;
        final resolvedRemoteSrc = remoteImageRequest?.url ?? src;
        final resolvedRemoteHeaders = remoteImageRequest?.headers;

        final widthAttr = _parseHtmlLength(element.attributes['width']);
        final heightAttr = _parseHtmlLength(element.attributes['height']);

        return InlineCustomWidget(
          alignment: PlaceholderAlignment.middle,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = _resolveImageMaxWidth(constraints, context);
              final maxHeight = maxImageHeight;
              final requestedWidth = _resolveHtmlLength(widthAttr, maxWidth);
              final requestedHeight = _resolveHtmlLength(heightAttr, maxHeight);
              double? targetWidth = requestedWidth;
              double? targetHeight = requestedHeight;

              if (targetWidth != null &&
                  targetWidth > 0 &&
                  targetHeight != null &&
                  targetHeight > 0) {
                final widthScale = maxWidth / targetWidth;
                final heightScale = maxHeight / targetHeight;
                final scale = [
                  1.0,
                  widthScale,
                  heightScale,
                ].reduce((a, b) => a < b ? a : b);
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
              final cacheWidth = _resolveCacheExtent(
                targetWidth ?? maxWidth,
                pixelRatio,
              );
              _logMemoMarkdownImageLayout(
                contentText,
                cacheKey: cacheKey,
                src: src,
                widthAttr: widthAttr,
                heightAttr: heightAttr,
                requestedWidth: requestedWidth,
                requestedHeight: requestedHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                cacheWidth: cacheWidth,
                isLocalFile: localFile != null,
              );

              final image = switch (localFile) {
                final File file when shouldUseSvgRenderer(url: file.path) =>
                  SvgPicture.file(
                    file,
                    width: targetWidth,
                    height: targetHeight,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => imagePlaceholder(),
                    errorBuilder: (_, svgError, svgStack) {
                      logImageError(file.path, svgError, svgStack);
                      return imageError();
                    },
                  ),
                final File file => Image.file(
                  file,
                  width: targetWidth,
                  height: targetHeight,
                  fit: BoxFit.contain,
                  cacheWidth: cacheWidth,
                  errorBuilder: (context, error, stackTrace) {
                    logImageError(file.path, error, stackTrace);
                    return imageError();
                  },
                ),
                _ => Image.network(
                  resolvedRemoteSrc,
                  width: targetWidth,
                  height: targetHeight,
                  fit: BoxFit.contain,
                  cacheWidth: cacheWidth,
                  headers: resolvedRemoteHeaders,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return imagePlaceholder();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    logImageError(resolvedRemoteSrc, error, stackTrace);
                    if (!shouldUseSvgRenderer(url: resolvedRemoteSrc)) {
                      return imageError();
                    }
                    return SvgPicture.network(
                      resolvedRemoteSrc,
                      width: targetWidth,
                      height: targetHeight,
                      fit: BoxFit.contain,
                      headers: resolvedRemoteHeaders,
                      placeholderBuilder: (_) => imagePlaceholder(),
                      errorBuilder: (_, svgError, svgStack) {
                        logImageError(resolvedRemoteSrc, svgError, svgStack);
                        return imageError();
                      },
                    );
                  },
                ),
              };

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
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
          final rawTag = element.attributes['data-tag'] ?? '';
          final canonicalTag =
              tagColorLookup?.resolveCanonicalPath(rawTag) ??
              normalizeTagPath(rawTag);
          final customColors =
              (tagColorLookup != null && canonicalTag.isNotEmpty)
              ? tagColorLookup.resolveChipColorsByPath(
                  canonicalTag,
                  surfaceColor: theme.colorScheme.surface,
                  isDark: theme.brightness == Brightness.dark,
                )
              : null;
          final background = customColors?.background ?? tagStyle.background;
          final textColor = customColors?.text ?? tagStyle.textColor;
          final borderColor = customColors?.border ?? tagStyle.borderColor;
          styles.addAll({
            'background-color': _cssColor(background),
            'color': _cssColor(textColor),
            'border': '1px solid ${_cssColor(borderColor)}',
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
            'color': _cssColor(highlightStyle.textColor),
            'border': '1px solid ${_cssColor(highlightStyle.borderColor)}',
            'border-radius': '3px',
            'padding': '0 3px',
            'font-weight': '700',
            'display': 'inline',
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
      final isBlankLineParagraph =
          localName == 'p' && element.classes.contains('memo-blank-line');
      if (isBlankLineParagraph) {
        styles['margin'] = '0';
      }
      if (localName == 'p' &&
          element.parent?.classes.contains('task-list-item') == true) {
        styles['display'] = 'inline';
        styles['margin'] = '0';
      }
      if (localName == 'li' && element.classes.contains('task-list-item')) {
        styles['list-style-type'] = 'none';
      }
      if ((localName == 'ul' || localName == 'ol') &&
          element.classes.contains('contains-task-list')) {
        styles.addAll({'list-style-type': 'none', 'padding-left': '0'});
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
        final isTaskParagraph =
            localName == 'p' &&
            element.parent?.classes.contains('task-list-item') == true;
        if (!isTaskParagraph && !isBlankLineParagraph) {
          styles['margin'] = '0 0 $spacingPx 0';
        }
      }
      return styles.isEmpty ? null : styles;
    }

    final renderMode = shrinkWrap
        ? RenderMode.column
        : const ListViewMode(shrinkWrap: false);
    Widget content = HtmlWidget(
      renderedHtml,
      factoryBuilder: () => _MemoMarkdownWidgetFactory(),
      renderMode: renderMode,
      textStyle: baseStyle,
      customWidgetBuilder: customWidgetBuilder,
      customStylesBuilder: customStylesBuilder,
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null) return true;
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_unable_open_browser_install_browser_app,
              ),
            ),
          );
        }
        return true;
      },
    );

    final effectiveMaxLines = maxLines;
    if (effectiveMaxLines != null && effectiveMaxLines > 0) {
      final fontSize = baseStyle.fontSize ?? 14;
      final lineHeight = baseStyle.height ?? _defaultLineHeight;
      final maxHeight = fontSize * lineHeight * effectiveMaxLines;
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

void _logMemoMarkdownDiagnostics(
  String content, {
  required String? cacheKey,
  required bool renderImages,
  required bool selectable,
  required int? maxLines,
  required bool normalizeHeadings,
}) {
  if (!shouldLogMemoContentDiagnostics(content)) {
    return;
  }
  final key = cacheKey?.trim().isNotEmpty == true
      ? 'memo_md:${cacheKey!.trim()}'
      : 'memo_md:${LogSanitizer.fingerprint(content)}';
  if (!_memoMarkdownDiagnosticLogKeys.add(key)) {
    return;
  }
  if (_memoMarkdownDiagnosticLogKeys.length > 240) {
    _memoMarkdownDiagnosticLogKeys.remove(_memoMarkdownDiagnosticLogKeys.first);
  }
  LogManager.instance.info(
    'MemoMarkdown diagnostics',
    context: <String, Object?>{
      ...buildMemoContentDiagnostics(content, cacheKey: cacheKey),
      'renderImages': renderImages,
      'selectable': selectable,
      'maxLines': maxLines,
      'normalizeHeadings': normalizeHeadings,
    },
  );
}

void _logMemoMarkdownHtmlImageWhileDisabled(
  String content, {
  required String? cacheKey,
  required String src,
}) {
  final key = [
    'memo_md_html_img_disabled',
    cacheKey?.trim().isNotEmpty == true
        ? cacheKey!.trim()
        : LogSanitizer.fingerprint(content),
    LogSanitizer.fingerprint(src),
  ].join('|');
  if (!_memoMarkdownDiagnosticLogKeys.add(key)) {
    return;
  }
  if (_memoMarkdownDiagnosticLogKeys.length > 240) {
    _memoMarkdownDiagnosticLogKeys.remove(_memoMarkdownDiagnosticLogKeys.first);
  }
  LogManager.instance.info(
    'MemoMarkdown html image skipped while images disabled',
    context: <String, Object?>{
      ...buildMemoContentDiagnostics(content, cacheKey: cacheKey),
      'sourceFingerprint': LogSanitizer.redactWithFingerprint(
        src,
        kind: 'source',
      ),
    },
  );
}

void _logMemoMarkdownImageLayout(
  String content, {
  required String? cacheKey,
  required String src,
  required _HtmlLength? widthAttr,
  required _HtmlLength? heightAttr,
  required double? requestedWidth,
  required double? requestedHeight,
  required double? targetWidth,
  required double? targetHeight,
  required double maxWidth,
  required double maxHeight,
  required int? cacheWidth,
  required bool isLocalFile,
}) {
  final requestedWidthChanged =
      requestedWidth != null &&
      targetWidth != null &&
      (requestedWidth - targetWidth).abs() >= 0.5;
  final requestedHeightChanged =
      requestedHeight != null &&
      targetHeight != null &&
      (requestedHeight - targetHeight).abs() >= 0.5;
  final hasExplicitDimensions = widthAttr != null || heightAttr != null;
  final targetUsesImplicitMaxWidth =
      isLocalFile &&
      !hasExplicitDimensions &&
      targetWidth == null &&
      maxWidth > 0;
  if (!hasExplicitDimensions &&
      !requestedWidthChanged &&
      !requestedHeightChanged &&
      !targetUsesImplicitMaxWidth) {
    return;
  }

  final key = [
    'memo_md_img_layout',
    cacheKey?.trim().isNotEmpty == true
        ? cacheKey!.trim()
        : LogSanitizer.fingerprint(content),
    LogSanitizer.fingerprint(src),
    widthAttr?.value.toString(),
    widthAttr?.isPercent.toString(),
    heightAttr?.value.toString(),
    heightAttr?.isPercent.toString(),
    targetWidth?.round().toString(),
    targetHeight?.round().toString(),
    maxWidth.round().toString(),
    maxHeight.round().toString(),
    isLocalFile.toString(),
  ].join('|');
  if (!_memoMarkdownDiagnosticLogKeys.add(key)) {
    return;
  }
  if (_memoMarkdownDiagnosticLogKeys.length > 240) {
    _memoMarkdownDiagnosticLogKeys.remove(_memoMarkdownDiagnosticLogKeys.first);
  }
  LogManager.instance.debug(
    'MemoMarkdown image layout',
    context: <String, Object?>{
      'cacheKeyFingerprint': cacheKey?.trim().isNotEmpty == true
          ? LogSanitizer.redactWithFingerprint(cacheKey!, kind: 'memo_md_key')
          : null,
      'sourceFingerprint': LogSanitizer.redactWithFingerprint(
        src,
        kind: 'source',
      ),
      'isLocalFile': isLocalFile,
      'widthAttrValue': widthAttr?.value,
      'widthAttrIsPercent': widthAttr?.isPercent,
      'heightAttrValue': heightAttr?.value,
      'heightAttrIsPercent': heightAttr?.isPercent,
      'requestedWidth': requestedWidth,
      'requestedHeight': requestedHeight,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'cacheWidth': cacheWidth,
      'clampedByWidth': requestedWidthChanged,
      'clampedByHeight': requestedHeightChanged,
      'usesImplicitMaxWidth': targetUsesImplicitMaxWidth,
    },
  );
}

String _rewriteMemoTagLabels(String html, TagColorLookup lookup) {
  final fragment = html_parser.parseFragment(html);
  var changed = false;
  for (final element in fragment.querySelectorAll('span.memotag')) {
    final rawTag = element.attributes['data-tag'] ?? element.text;
    final canonicalPath = lookup.resolveCanonicalPath(rawTag);
    if (canonicalPath.isEmpty) continue;
    final canonicalLabel = '#$canonicalPath';
    if (element.attributes['data-tag'] != canonicalPath) {
      element.attributes['data-tag'] = canonicalPath;
      changed = true;
    }
    if (element.text != canonicalLabel) {
      element.text = canonicalLabel;
      changed = true;
    }
  }
  return changed ? fragment.outerHtml : html;
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

String? _extractCodeLanguage(dom.Element? codeElement) {
  if (codeElement == null) return null;
  final classAttr = codeElement.attributes['class'] ?? '';
  final match = _codeLanguagePattern.firstMatch(classAttr);
  final language = match?.group(1);
  if (language == null || language.isEmpty) return null;
  return language;
}

class _HtmlLength {
  const _HtmlLength({required this.value, required this.isPercent});

  final double value;
  final bool isPercent;
}

_HtmlLength? _parseHtmlLength(String? value) {
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
  return _HtmlLength(value: parsed, isPercent: unit == '%');
}

double? _resolveHtmlLength(_HtmlLength? value, double maxExtent) {
  if (value == null) return null;
  if (!value.isPercent) return value.value;
  final percent = value.value.clamp(0.0, 100.0);
  return maxExtent * (percent / 100.0);
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
  return pixels > _markdownImageMaxDecodePx
      ? _markdownImageMaxDecodePx
      : pixels;
}

double _resolveImageMaxHeight(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  if (screenHeight <= 0) return 360;
  final suggested = (screenHeight * 0.45).clamp(300.0, 400.0);
  final maxAllowed = screenHeight * 0.5;
  return suggested > maxAllowed ? maxAllowed : suggested;
}

bool _isHeadingTag(String tag) {
  if (tag.length != 2 || tag[0] != 'h') return false;
  final unit = tag.codeUnitAt(1);
  return unit >= 0x31 && unit <= 0x36;
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
    required this.textColor,
    required this.borderColor,
  });

  final Color background;
  final Color textColor;
  final Color borderColor;

  static _MemoHighlightStyle resolve(ThemeData theme) {
    const fluorescentYellow = Color(0xFFFFFF00);
    return _MemoHighlightStyle(
      background: fluorescentYellow,
      textColor: Colors.black,
      borderColor: fluorescentYellow,
    );
  }
}

class MemoCodeHighlighter {
  MemoCodeHighlighter({required this.baseStyle, required this.isDark});

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

    final commentColor = isDark
        ? const Color(0xFF7C8895)
        : const Color(0xFF6A737D);
    final stringColor = isDark
        ? const Color(0xFF98C379)
        : const Color(0xFF22863A);
    final keywordColor = isDark
        ? const Color(0xFF7AA2F7)
        : const Color(0xFF005CC5);
    final numberColor = isDark
        ? const Color(0xFFD19A66)
        : const Color(0xFFB45500);
    final annotationColor = isDark
        ? const Color(0xFF56B6C2)
        : const Color(0xFF22863A);

    final rules = <_CodeHighlightRule>[
      _CodeHighlightRule(
        _commentPattern,
        baseStyle.copyWith(color: commentColor, fontStyle: FontStyle.italic),
      ),
      _CodeHighlightRule(
        _stringPattern,
        baseStyle.copyWith(color: stringColor),
      ),
      _CodeHighlightRule(
        _annotationPattern,
        baseStyle.copyWith(color: annotationColor),
      ),
      _CodeHighlightRule(
        _keywordPattern,
        baseStyle.copyWith(color: keywordColor, fontWeight: FontWeight.w600),
      ),
      _CodeHighlightRule(
        _numberPattern,
        baseStyle.copyWith(color: numberColor),
      ),
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
                Expanded(child: Text(label, style: labelStyle)),
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
              child: RichText(text: highlightSpan, softWrap: false),
            ),
          ],
        ),
      ),
    );
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
  final children = _buildHighlightSpans(
    result.nodes ?? const <hi.Node>[],
    baseStyle,
    theme,
  );
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
      spans.add(
        TextSpan(
          style: style,
          children: _buildHighlightSpans(node.children!, style, theme),
        ),
      );
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
    final commentColor = isDark
        ? const Color(0xFF7C8895)
        : const Color(0xFF6A737D);
    final stringColor = isDark
        ? const Color(0xFF98C379)
        : const Color(0xFF22863A);
    final keywordColor = isDark
        ? const Color(0xFF7AA2F7)
        : const Color(0xFF005CC5);
    final numberColor = isDark
        ? const Color(0xFFD19A66)
        : const Color(0xFFB45500);
    final titleColor = isDark
        ? const Color(0xFFC678DD)
        : const Color(0xFF6F42C1);
    final attributeColor = isDark
        ? const Color(0xFFE5C07B)
        : const Color(0xFFE36209);
    final tagColor = stringColor;
    final metaColor = isDark
        ? const Color(0xFFC9D1D9)
        : const Color(0xFF24292E);
    final additionColor = isDark
        ? const Color(0xFF2EA043)
        : const Color(0xFF22863A);
    final deletionColor = isDark
        ? const Color(0xFFF85149)
        : const Color(0xFFCB2431);

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
      'meta-keyword': TextStyle(
        color: keywordColor,
        fontWeight: FontWeight.w600,
      ),
      'meta-string': TextStyle(color: stringColor),
      'addition': TextStyle(color: additionColor),
      'deletion': TextStyle(color: deletionColor),
    });
  }
}
