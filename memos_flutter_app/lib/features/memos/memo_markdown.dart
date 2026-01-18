import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

final RegExp _tagTokenPattern = RegExp(
  r'^#(?!#|\s)[\p{L}\p{N}\p{S}_/\-]{1,100}$',
  unicode: true,
);

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
    this.textStyle,
    this.selectable = false,
    this.blockSpacing = 6,
    this.shrinkWrap = true,
    this.onToggleTask,
  });

  final String data;
  final TextStyle? textStyle;
  final bool selectable;
  final double blockSpacing;
  final bool shrinkWrap;
  final TaskToggleHandler? onToggleTask;

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeTagSpacing(data);
    final sanitized = _sanitizeMarkdown(normalized);
    final trimmed = sanitized.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final baseStyle = textStyle ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final fontSize = baseStyle.fontSize;
    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: baseStyle,
      blockSpacing: blockSpacing,
      code: baseStyle.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.cardTheme.color,
        fontSize: fontSize == null ? null : fontSize * 0.9,
      ),
      blockquote: baseStyle.copyWith(
        color: baseStyle.color?.withValues(alpha: 0.7),
      ),
      listBullet: baseStyle,
    );
    var taskIndex = 0;

    Widget buildCheckbox(bool checked) {
      final handler = onToggleTask;
      final currentIndex = taskIndex++;
      final onTap = handler == null
          ? null
          : () => handler(TaskToggleRequest(taskIndex: currentIndex, checked: checked));
      final icon = Icon(
        checked ? Icons.check_box : Icons.check_box_outline_blank,
        size: styleSheet.checkbox?.fontSize,
        color: styleSheet.checkbox?.color,
      );
      final child = onTap == null
          ? icon
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: icon,
            );
      return Padding(
        padding: styleSheet.listBulletPadding ?? EdgeInsets.zero,
        child: child,
      );
    }

    return MarkdownBody(
      data: trimmed,
      selectable: selectable,
      styleSheet: styleSheet,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [_MemoHighlightInlineSyntax(), _MemoTagInlineSyntax()],
      checkboxBuilder: buildCheckbox,
      builders: {
        'memohighlight': _MemoHighlightBuilder(_MemoHighlightStyle.resolve(theme)),
        'memotag': _MemoTagBuilder(_MemoTagStyle.resolve(theme)),
      },
      shrinkWrap: shrinkWrap,
      softLineBreak: true,
    );
  }
}

String _sanitizeMarkdown(String text) {
  // Avoid empty markdown links that can leave the inline stack open in flutter_markdown.
  final emptyLink = RegExp(r'\[\s*\]\(([^)]*)\)');
  final stripped = text.replaceAllMapped(emptyLink, (match) {
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

class _MemoHighlightInlineSyntax extends md.InlineSyntax {
  _MemoHighlightInlineSyntax() : super(r'==([^\n]+?)==', startCharacter: 0x3D);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match.group(1);
    if (text == null || text.trim().isEmpty) return false;
    parser.addNode(md.Element.text('memohighlight', text));
    return true;
  }
}

class _MemoTagInlineSyntax extends md.InlineSyntax {
  _MemoTagInlineSyntax() : super(r'#', startCharacter: 0x23);

  static final RegExp _pattern = RegExp(
    r'#(?!#|\s)([\p{L}\p{N}\p{S}_/\-]{1,100})',
    unicode: true,
  );

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;
    if (parser.source.codeUnitAt(startMatchPos) != 0x23) return false;
    if (startMatchPos > 0 && parser.source.codeUnitAt(startMatchPos - 1) == 0x23) {
      return false;
    }
    final match = _pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;
    parser.writeText();
    if (onMatch(parser, match)) {
      parser.consume(match.group(0)!.length);
    }
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tag = match.group(1);
    if (tag == null || tag.isEmpty) return false;
    parser.addNode(md.Element.text('memotag', tag));
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

class _MemoTagBuilder extends MarkdownElementBuilder {
  _MemoTagBuilder(this.style);

  final _MemoTagStyle style;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tag = element.textContent;
    if (tag.isEmpty) return null;

    final baseStyle = preferredStyle ?? parentStyle ?? DefaultTextStyle.of(context).style;
    final textStyle = baseStyle.copyWith(
      color: style.textColor,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
    final fontSize = textStyle.fontSize;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: style.borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Text(
            '#$tag',
            style: fontSize == null ? textStyle : textStyle.copyWith(fontSize: fontSize * 0.95),
          ),
        ),
      ),
    );
  }
}

class _MemoHighlightBuilder extends MarkdownElementBuilder {
  _MemoHighlightBuilder(this.style);

  final _MemoHighlightStyle style;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    if (text.isEmpty) return null;

    final baseStyle = preferredStyle ?? parentStyle ?? DefaultTextStyle.of(context).style;
    final textStyle = baseStyle.copyWith(height: 1.2);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: style.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(text, style: textStyle),
      ),
    );
  }
}
