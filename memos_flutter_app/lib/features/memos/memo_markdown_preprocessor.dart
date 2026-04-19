import '../../core/tags.dart';

final RegExp _markdownImagePattern = RegExp(
  r'!\[[^\]]*]\(([^)\s]+)(?:\s+"[^"]*")?\)',
);
final RegExp _codeFencePattern = RegExp(r'^\s*(```|~~~)');
final RegExp _fullHtmlDoctypeLinePattern = RegExp(
  r'^\s*<!doctype\s+html(?:\s[^>]*)?>\s*$',
  caseSensitive: false,
);
final RegExp _fullHtmlOpenTagLinePattern = RegExp(
  r'^\s*<html(?:\s|>)',
  caseSensitive: false,
);
final RegExp _fullHtmlCloseTagPattern = RegExp(
  r'</html\s*>',
  caseSensitive: false,
);

const String _zeroWidthSpace = '\u200B';
const String _memoBlankLineHtml =
    '<p class="memo-blank-line">$_zeroWidthSpace</p>';

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

String sanitizeMemoMarkdown(String text) {
  final emptyLink = RegExp(r'\[\s*\]\(([^)]*)\)');
  final stripped = text.replaceAllMapped(emptyLink, (match) {
    final start = match.start;
    if (start > 0 && text.codeUnitAt(start - 1) == 0x21) {
      return match.group(0) ?? '';
    }
    final url = match.group(1)?.trim();
    return url?.isNotEmpty == true ? url! : '';
  });
  final protectedHtml = _protectEmbeddedFullHtmlDocuments(stripped);
  final escapedTaskHeadings = _escapeEmptyTaskHeadings(protectedHtml);
  final preservedBlankLines = _preserveExplicitBlankLines(escapedTaskHeadings);
  return _normalizeFencedCodeBlocks(preservedBlankLines);
}

bool looksLikeFullHtmlDocument(String text) {
  final trimmed = text.trimLeft();
  return RegExp(
    r'^(?:<!doctype\s+html(?:\s[^>]*)?>\s*)?<html(?:\s|>)',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

String decorateMemoTagsForHtml(String text) {
  final lines = text.split('\n');
  int? firstLine;
  int? lastLine;
  for (var i = 0; i < lines.length; i++) {
    if (_isNonContentLine(lines[i])) continue;
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

String _preserveExplicitBlankLines(String text) {
  final lines = text.split('\n');
  if (lines.isEmpty) return text;

  final output = <String>[];
  var inFence = false;
  for (final line in lines) {
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      output.add(line);
      continue;
    }
    if (!inFence && line.trim().isEmpty) {
      output
        ..add('')
        ..add(_memoBlankLineHtml)
        ..add('');
      continue;
    }
    output.add(line);
  }

  return output.join('\n');
}

bool _isNonContentLine(String line) {
  final trimmed = line.trim();
  return trimmed.isEmpty || trimmed == _memoBlankLineHtml;
}

String _protectEmbeddedFullHtmlDocuments(String text) {
  final lines = text.split('\n');
  if (lines.isEmpty) return text;

  final output = <String>[];
  var index = 0;
  var inFence = false;

  while (index < lines.length) {
    final line = lines[index];
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      output.add(line);
      index++;
      continue;
    }

    if (!inFence && _isEmbeddedFullHtmlDocumentStart(lines, index)) {
      final end = _findEmbeddedFullHtmlDocumentEnd(lines, index);
      if (end >= index) {
        if (output.isNotEmpty && output.last.trim().isNotEmpty) {
          output.add('');
        }
        output.add('```html');
        output.addAll(lines.getRange(index, end + 1));
        output.add('```');
        if (end + 1 < lines.length && lines[end + 1].trim().isNotEmpty) {
          output.add('');
        }
        index = end + 1;
        continue;
      }
    }

    output.add(line);
    index++;
  }

  return output.join('\n');
}

bool _isEmbeddedFullHtmlDocumentStart(List<String> lines, int index) {
  final line = lines[index].trimLeft();
  if (_fullHtmlOpenTagLinePattern.hasMatch(line)) {
    return true;
  }
  if (!_fullHtmlDoctypeLinePattern.hasMatch(line)) {
    return false;
  }
  for (var i = index + 1; i < lines.length; i++) {
    final next = lines[i].trimLeft();
    if (next.isEmpty) continue;
    return _fullHtmlOpenTagLinePattern.hasMatch(next);
  }
  return false;
}

int _findEmbeddedFullHtmlDocumentEnd(List<String> lines, int start) {
  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    if (_fullHtmlCloseTagPattern.hasMatch(line)) {
      return i;
    }
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      return -1;
    }
  }
  return -1;
}

String _escapeEmptyTaskHeadings(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = RegExp(
      r'^(\s*[-*+]\s+\[(?: |x|X)\]\s*)(#{1,6})\s*$',
    ).firstMatch(lines[i]);
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

String _replaceTagsInLine(String line) {
  final matches = findInlineTagMatches(line);
  if (matches.isEmpty) return line;

  final buffer = StringBuffer();
  var last = 0;
  for (final match in matches) {
    buffer.write(line.substring(last, match.start));
    final escaped = _escapeHtmlAttribute(match.tag);
    buffer.write(
      '<span class="memotag" data-tag="$escaped">#${match.tag}</span>',
    );
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
