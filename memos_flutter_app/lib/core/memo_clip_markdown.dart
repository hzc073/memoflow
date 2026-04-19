import 'package:flutter/foundation.dart';

@immutable
class MemoClipMarkdownParts {
  const MemoClipMarkdownParts({
    required this.title,
    required this.body,
    required this.hasExplicitTitle,
  });

  final String? title;
  final String body;
  final bool hasExplicitTitle;
}

MemoClipMarkdownParts parseMemoClipMarkdown(String content) {
  final normalized = content.replaceAll('\r\n', '\n').trimRight();
  if (normalized.isEmpty) {
    return const MemoClipMarkdownParts(
      title: null,
      body: '',
      hasExplicitTitle: false,
    );
  }

  final lines = normalized.split('\n');
  var firstNonEmptyIndex = -1;
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].trim().isNotEmpty) {
      firstNonEmptyIndex = index;
      break;
    }
  }

  if (firstNonEmptyIndex == -1) {
    return const MemoClipMarkdownParts(
      title: null,
      body: '',
      hasExplicitTitle: false,
    );
  }

  final match = RegExp(
    r'^\s{0,3}#{1,6}\s+(.+?)\s*$',
    multiLine: false,
  ).firstMatch(lines[firstNonEmptyIndex]);
  if (match == null) {
    return MemoClipMarkdownParts(
      title: null,
      body: normalized,
      hasExplicitTitle: false,
    );
  }

  final rawTitle = (match.group(1) ?? '').trim();
  if (rawTitle.isEmpty) {
    return MemoClipMarkdownParts(
      title: null,
      body: normalized,
      hasExplicitTitle: false,
    );
  }

  final bodyLines = List<String>.from(lines)..removeAt(firstNonEmptyIndex);
  if (firstNonEmptyIndex < bodyLines.length &&
      bodyLines[firstNonEmptyIndex].trim().isEmpty) {
    bodyLines.removeAt(firstNonEmptyIndex);
  }

  return MemoClipMarkdownParts(
    title: rawTitle,
    body: bodyLines.join('\n').trimRight(),
    hasExplicitTitle: true,
  );
}

String? extractMemoClipTitle(String content) {
  return parseMemoClipMarkdown(content).title;
}

String stripMemoClipTitle(String content) {
  return parseMemoClipMarkdown(content).body;
}
