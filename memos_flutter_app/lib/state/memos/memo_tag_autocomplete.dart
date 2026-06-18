import 'package:flutter/services.dart';

import '../../core/tags.dart';
import 'memos_providers.dart';

const int kEditorTagSuggestionLimit = 100;

class ActiveTagQuery {
  const ActiveTagQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

ActiveTagQuery? detectActiveTagQuery(
  TextEditingValue value, {
  TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
}) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final text = value.text;
  final caret = selection.extentOffset;
  if (caret < 0 || caret > text.length) return null;

  var tokenStart = caret - 1;
  while (tokenStart >= 0 && !_isTagBoundary(text[tokenStart])) {
    tokenStart--;
  }
  tokenStart += 1;
  if (tokenStart >= text.length || text[tokenStart] != '#') return null;
  if (tokenStart + 1 > caret) return null;

  final query = text.substring(tokenStart + 1, caret);
  if (query.contains('#')) return null;
  if (!_partialTagPattern.hasMatch(query)) return null;
  if (!_isTagQueryVisibleUnderPolicy(
    text: text,
    tokenStart: tokenStart,
    tokenEnd: caret,
    query: query,
    policy: policy,
  )) {
    return null;
  }
  return ActiveTagQuery(start: tokenStart, end: caret, query: query);
}

bool _isTagQueryVisibleUnderPolicy({
  required String text,
  required int tokenStart,
  required int tokenEnd,
  required String query,
  required TagRecognitionPolicy policy,
}) {
  final (lineIndex, lineStart) = _linePositionForOffset(text, tokenStart);
  final relativeStart = tokenStart - lineStart;
  final probeText = query.isEmpty
      ? text.replaceRange(tokenEnd, tokenEnd, 'x')
      : text;
  final relativeEnd = tokenEnd - lineStart + (query.isEmpty ? 1 : 0);
  for (final match in findContentTagMatches(probeText, policy: policy)) {
    if (match.lineIndex != lineIndex) continue;
    if (match.match.start == relativeStart && match.match.end == relativeEnd) {
      return true;
    }
  }
  return false;
}

(int lineIndex, int lineStart) _linePositionForOffset(String text, int offset) {
  var lineIndex = 0;
  var lineStart = 0;
  for (var i = 0; i < offset && i < text.length; i++) {
    if (text.codeUnitAt(i) != 0x0A) continue;
    lineIndex += 1;
    lineStart = i + 1;
  }
  return (lineIndex, lineStart);
}

List<TagStat> buildTagSuggestions(
  List<TagStat> tags, {
  required String query,
  int limit = kEditorTagSuggestionLimit,
}) {
  if (limit <= 0 || tags.isEmpty) return const <TagStat>[];
  final normalized = query.trim().toLowerCase();
  final ranked = <({TagStat stat, int score})>[];
  final seen = <String>{};

  for (final stat in tags) {
    final path = stat.path.trim();
    if (path.isEmpty || !seen.add(path)) continue;
    final leaf = path.split('/').last;
    final pathLower = path.toLowerCase();
    final leafLower = leaf.toLowerCase();

    int score;
    if (normalized.isEmpty) {
      score = 4;
    } else if (leafLower.startsWith(normalized)) {
      score = 0;
    } else if (pathLower.startsWith(normalized)) {
      score = 1;
    } else if (leafLower.contains(normalized)) {
      score = 2;
    } else if (pathLower.contains(normalized)) {
      score = 3;
    } else {
      continue;
    }

    ranked.add((stat: stat, score: score));
  }

  ranked.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    if (byScore != 0) return byScore;
    if (a.stat.pinned != b.stat.pinned) return a.stat.pinned ? -1 : 1;
    final byCount = b.stat.count.compareTo(a.stat.count);
    if (byCount != 0) return byCount;
    return a.stat.path.compareTo(b.stat.path);
  });

  return ranked.take(limit).map((entry) => entry.stat).toList(growable: false);
}

final RegExp _partialTagPattern = RegExp(
  r'^[\p{L}\p{N}\p{S}_/\-]*$',
  unicode: true,
);
final RegExp _tagBoundaryPattern = RegExp(
  "[\\s\\.,;:!\\?\\(\\)\\[\\]\\{\\}\"'`<>]",
);

bool _isTagBoundary(String char) => _tagBoundaryPattern.hasMatch(char);
