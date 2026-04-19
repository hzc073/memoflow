const int _maxTagLength = 100;
final RegExp _tagRuneRe = RegExp(r'[\p{L}\p{N}\p{S}]', unicode: true);
final RegExp _tagInlinePattern = RegExp(
  r'#(?!#|\s)([\p{L}\p{N}\p{S}_/\-]{1,100})',
  unicode: true,
);
final List<RegExp> _protectedInlineTagPatterns = <RegExp>[
  RegExp(r'!\[[^\]]*]\([^)\n]*\)'),
  RegExp(r'\[[^\]]*]\([^)\n]*\)'),
  RegExp(r'<(?:https?|ftp):[^>\s]+>', caseSensitive: false),
  RegExp(r'<(?:mailto|tel):[^>\s]+>', caseSensitive: false),
  RegExp(r'<[^>\n]+>'),
  RegExp(
    r'(?:(?:https?|ftp):\/\/|mailto:|tel:|www\.)[^\s<>()]+',
    caseSensitive: false,
  ),
];

class InlineTagMatch {
  const InlineTagMatch({
    required this.start,
    required this.end,
    required this.tag,
  });

  final int start;
  final int end;
  final String tag;
}

class _ProtectedRange {
  const _ProtectedRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int index) => index >= start && index < end;
}

bool _isValidTagRune(int rune) {
  if (rune == 0x5F || rune == 0x2D || rune == 0x2F) {
    return true;
  }
  return _tagRuneRe.hasMatch(String.fromCharCode(rune));
}

String normalizeTagPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final withoutHash = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  final parts = withoutHash.split('/');
  final normalizedParts = <String>[];
  for (final part in parts) {
    final normalized = _normalizeTagSegment(part);
    if (normalized.isEmpty) continue;
    normalizedParts.add(normalized);
  }
  if (normalizedParts.isEmpty) return '';
  return normalizedParts.join('/');
}

String _normalizeTagSegment(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final buffer = StringBuffer();
  for (final rune in trimmed.runes) {
    if (rune == 0x2F) continue; // slash is a path separator
    if (_isValidTagRune(rune)) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

List<String> extractTags(String content) {
  final tags = <String>{};
  if (content.isEmpty) return const [];

  final lines = content.split('\n');
  int? firstLine;
  int? lastLine;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    firstLine ??= i;
    lastLine = i;
  }
  if (firstLine == null || lastLine == null) return const [];

  _extractTagsFromLine(lines[firstLine], tags);
  if (lastLine != firstLine) {
    _extractTagsFromLine(lines[lastLine], tags);
  }

  final list = tags.toList(growable: false);
  list.sort();
  return list;
}

void _extractTagsFromLine(String line, Set<String> tags) {
  for (final match in findInlineTagMatches(line)) {
    if (match.tag.isEmpty) continue;
    tags.add(match.tag);
  }
}

List<InlineTagMatch> findInlineTagMatches(String line) {
  if (line.isEmpty) return const [];
  final rawMatches = _tagInlinePattern.allMatches(line).toList(growable: false);
  if (rawMatches.isEmpty) return const [];

  final protectedRanges = _collectProtectedRanges(line);
  final matches = <InlineTagMatch>[];
  for (final match in rawMatches) {
    final tag = match.group(1);
    if (tag == null || tag.isEmpty || tag.length > _maxTagLength) {
      continue;
    }
    if (_isIndexProtected(match.start, protectedRanges)) {
      continue;
    }
    final previousRune = _previousRuneBefore(line, match.start);
    if (_shouldSkipInlineTag(previousRune)) {
      continue;
    }
    matches.add(InlineTagMatch(start: match.start, end: match.end, tag: tag));
  }
  return matches;
}

bool _shouldSkipInlineTag(int? previousRune) {
  if (previousRune == null) return false;
  if (previousRune == 0x23 || previousRune == 0x5C) {
    return true;
  }
  return _isValidTagRune(previousRune);
}

int? _previousRuneBefore(String text, int index) {
  if (index <= 0) return null;
  final previousCodeUnit = text.codeUnitAt(index - 1);
  if (previousCodeUnit >= 0xDC00 && previousCodeUnit <= 0xDFFF && index >= 2) {
    final highSurrogate = text.codeUnitAt(index - 2);
    if (highSurrogate >= 0xD800 && highSurrogate <= 0xDBFF) {
      return 0x10000 +
          ((highSurrogate - 0xD800) << 10) +
          (previousCodeUnit - 0xDC00);
    }
  }
  return previousCodeUnit;
}

List<_ProtectedRange> _collectProtectedRanges(String line) {
  final ranges = <_ProtectedRange>[];
  for (final pattern in _protectedInlineTagPatterns) {
    for (final match in pattern.allMatches(line)) {
      if (match.start >= match.end) continue;
      ranges.add(_ProtectedRange(match.start, match.end));
    }
  }
  if (ranges.length < 2) return ranges;

  ranges.sort((left, right) => left.start.compareTo(right.start));
  final merged = <_ProtectedRange>[ranges.first];
  for (final range in ranges.skip(1)) {
    final last = merged.last;
    if (range.start <= last.end) {
      merged[merged.length - 1] = _ProtectedRange(
        last.start,
        range.end > last.end ? range.end : last.end,
      );
      continue;
    }
    merged.add(range);
  }
  return merged;
}

bool _isIndexProtected(int index, List<_ProtectedRange> ranges) {
  for (final range in ranges) {
    if (index < range.start) return false;
    if (range.contains(index)) return true;
  }
  return false;
}
