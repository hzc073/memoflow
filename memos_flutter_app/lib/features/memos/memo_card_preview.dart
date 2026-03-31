import '../../core/app_localization.dart';
import '../../data/models/app_preferences.dart';
import 'memo_task_list_service.dart';

const int kMemoCardPreviewMaxLines = 6;
const int kMemoCardPreviewMaxCompactRunes = 220;

final RegExp _markdownLinkPattern = RegExp(r'\[([^\]]*)\]\(([^)]+)\)');
final RegExp _whitespaceCollapsePattern = RegExp(r'\s+');

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
  if (!collapseReferences) return trimmed;

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
