import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../share_clip_models.dart';

enum ShareNetworkRecordKind { request, ajax, fetch, resource }

@immutable
class ShareNetworkRecord {
  const ShareNetworkRecord({
    required this.kind,
    required this.url,
    this.method,
    this.mimeType,
    this.referer,
    this.headers,
    this.responseBody,
  });

  final ShareNetworkRecordKind kind;
  final String url;
  final String? method;
  final String? mimeType;
  final String? referer;
  final Map<String, String>? headers;
  final String? responseBody;
}

@immutable
class SharePageSnapshot {
  const SharePageSnapshot({
    required this.requestUrl,
    required this.finalUrl,
    required this.host,
    required this.bridgeData,
    this.networkRecords = const [],
    this.cookieHeader,
    this.userAgent,
  });

  final Uri requestUrl;
  final Uri finalUrl;
  final String host;
  final Map<String, dynamic> bridgeData;
  final List<ShareNetworkRecord> networkRecords;
  final String? cookieHeader;
  final String? userAgent;
}

@immutable
class SharePageParserResult {
  const SharePageParserResult({
    this.pageKind = SharePageKind.unknown,
    this.videoCandidates = const [],
    this.unsupportedVideoCandidates = const [],
    this.title,
    this.excerpt,
    this.contentHtml,
    this.textContent,
    this.siteName,
    this.sourceAvatarUrl,
    this.byline,
    this.authorAvatarUrl,
    this.leadImageUrl,
    this.parserTag,
  });

  final SharePageKind pageKind;
  final List<ShareVideoCandidate> videoCandidates;
  final List<ShareVideoCandidate> unsupportedVideoCandidates;
  final String? title;
  final String? excerpt;
  final String? contentHtml;
  final String? textContent;
  final String? siteName;
  final String? sourceAvatarUrl;
  final String? byline;
  final String? authorAvatarUrl;
  final String? leadImageUrl;
  final String? parserTag;
}

abstract class SharePageParser {
  bool canParse(SharePageSnapshot snapshot);

  SharePageParserResult parse(SharePageSnapshot snapshot);
}

SharePageParserResult mergeSharePageParserResults(
  Iterable<SharePageParserResult> results,
) {
  final list = results.toList(growable: false);
  final preferred = list.firstWhere(
    (item) => item.parserTag != null && item.parserTag != 'generic',
    orElse: () => const SharePageParserResult(),
  );
  final fallback = list.isEmpty ? const SharePageParserResult() : list.last;
  final mergedCandidates = mergeShareVideoCandidates(
    list.expand((item) => item.videoCandidates),
  );
  final mergedUnsupportedCandidates = mergeShareVideoCandidates(
    list.expand((item) => item.unsupportedVideoCandidates),
  );
  final resolvedPageKind = preferred.pageKind != SharePageKind.unknown
      ? preferred.pageKind
      : fallback.pageKind != SharePageKind.unknown
      ? fallback.pageKind
      : mergedCandidates.isNotEmpty || mergedUnsupportedCandidates.isNotEmpty
      ? SharePageKind.video
      : _hasArticleContent(
          _firstNonEmpty(list.map((item) => item.contentHtml)),
          _firstNonEmpty(list.map((item) => item.textContent)),
        )
      ? SharePageKind.article
      : SharePageKind.unknown;

  return SharePageParserResult(
    pageKind: resolvedPageKind,
    videoCandidates: mergedCandidates,
    unsupportedVideoCandidates: mergedUnsupportedCandidates,
    title: _firstNonEmpty(list.map((item) => item.title)),
    excerpt: _firstNonEmpty(list.map((item) => item.excerpt)),
    contentHtml: _firstNonEmpty(list.map((item) => item.contentHtml)),
    textContent: _firstNonEmpty(list.map((item) => item.textContent)),
    siteName: _firstNonEmpty(list.map((item) => item.siteName)),
    sourceAvatarUrl: _firstNonEmpty(list.map((item) => item.sourceAvatarUrl)),
    byline: _firstNonEmpty(list.map((item) => item.byline)),
    authorAvatarUrl: _firstNonEmpty(list.map((item) => item.authorAvatarUrl)),
    leadImageUrl: _firstNonEmpty(list.map((item) => item.leadImageUrl)),
    parserTag: preferred.parserTag ?? fallback.parserTag,
  );
}

List<ShareVideoCandidate> mergeShareVideoCandidates(
  Iterable<ShareVideoCandidate> candidates,
) {
  final merged = <String, ShareVideoCandidate>{};
  for (final candidate in candidates) {
    final key = candidate.dedupeKey;
    if (key.isEmpty) continue;
    final current = merged[key];
    if (current == null || compareShareVideoCandidate(candidate, current) < 0) {
      merged[key] = candidate;
    }
  }
  final list = merged.values.toList(growable: false);
  list.sort(compareShareVideoCandidate);
  return list;
}

int compareShareVideoCandidate(
  ShareVideoCandidate left,
  ShareVideoCandidate right,
) {
  final directComparison = (right.isDirectDownloadable ? 1 : 0).compareTo(
    left.isDirectDownloadable ? 1 : 0,
  );
  if (directComparison != 0) return directComparison;

  final parserComparison =
      ((right.parserTag != null && right.parserTag != 'generic') ? 1 : 0)
          .compareTo(
            (left.parserTag != null && left.parserTag != 'generic') ? 1 : 0,
          );
  if (parserComparison != 0) return parserComparison;

  final mimeComparison = (right.mimeType == null ? 0 : 1).compareTo(
    left.mimeType == null ? 0 : 1,
  );
  if (mimeComparison != 0) return mimeComparison;

  final sourceComparison = _sourcePriority(
    left.source,
  ).compareTo(_sourcePriority(right.source));
  if (sourceComparison != 0) return sourceComparison;

  final priorityComparison = right.priority.compareTo(left.priority);
  if (priorityComparison != 0) return priorityComparison;

  final urlLengthComparison = left.url.length.compareTo(right.url.length);
  if (urlLengthComparison != 0) return urlLengthComparison;

  return left.url.compareTo(right.url);
}

int _sourcePriority(ShareVideoSource source) {
  return switch (source) {
    ShareVideoSource.parser => 0,
    ShareVideoSource.jsonLd => 1,
    ShareVideoSource.meta => 2,
    ShareVideoSource.dom => 3,
    ShareVideoSource.link => 4,
    ShareVideoSource.ajax => 5,
    ShareVideoSource.fetch => 6,
    ShareVideoSource.request => 7,
    ShareVideoSource.resource => 8,
  };
}

bool isDirectVideoUrl(String url, {String? mimeType}) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return false;
  if (parsed.scheme != 'http' && parsed.scheme != 'https') return false;
  final lowerMime = (mimeType ?? '').toLowerCase();
  if (lowerMime.startsWith('video/')) return true;
  final lowerUrl = url.toLowerCase();
  return const [
    '.mp4',
    '.webm',
    '.mov',
    '.m4v',
    '.mkv',
    '.avi',
  ].any(lowerUrl.contains);
}

bool isUnsupportedStreamUrl(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return false;
  final lowerUrl = url.toLowerCase();
  if (parsed.scheme == 'blob' || parsed.scheme == 'data') return true;
  return lowerUrl.contains('.m3u8') ||
      lowerUrl.contains('.m3u') ||
      lowerUrl.contains('.mpd');
}

ShareVideoSource shareVideoSourceFromLabel(String? label) {
  switch ((label ?? '').trim().toLowerCase()) {
    case 'meta':
      return ShareVideoSource.meta;
    case 'jsonld':
    case 'json-ld':
      return ShareVideoSource.jsonLd;
    case 'link':
      return ShareVideoSource.link;
    case 'request':
      return ShareVideoSource.request;
    case 'ajax':
      return ShareVideoSource.ajax;
    case 'fetch':
      return ShareVideoSource.fetch;
    case 'resource':
      return ShareVideoSource.resource;
    case 'parser':
      return ShareVideoSource.parser;
    case 'dom':
    default:
      return ShareVideoSource.dom;
  }
}

String? firstStringAtPaths(Object? root, List<List<Object>> paths) {
  for (final path in paths) {
    final value = valueAtPath(root, path);
    final normalized = normalizeShareText(value?.toString());
    if (normalized != null) return normalized;
  }
  return null;
}

Object? valueAtPath(Object? root, List<Object> path) {
  Object? current = root;
  for (final segment in path) {
    if (current is Map) {
      current = current[segment];
      continue;
    }
    if (current is List && segment is int) {
      if (segment < 0 || segment >= current.length) return null;
      current = current[segment];
      continue;
    }
    return null;
  }
  return current;
}

Iterable<Object?> deepValuesForKey(Object? root, Set<String> keys) sync* {
  if (root is Map) {
    for (final entry in root.entries) {
      final key = entry.key.toString();
      if (keys.contains(key)) {
        yield entry.value;
      }
      yield* deepValuesForKey(entry.value, keys);
    }
    return;
  }
  if (root is List) {
    for (final value in root) {
      yield* deepValuesForKey(value, keys);
    }
  }
}

Iterable<Map<String, dynamic>> deepMaps(Object? root) sync* {
  if (root is Map<String, dynamic>) {
    yield root;
    for (final value in root.values) {
      yield* deepMaps(value);
    }
    return;
  }
  if (root is Map) {
    final normalized = <String, dynamic>{};
    for (final entry in root.entries) {
      normalized[entry.key.toString()] = entry.value;
    }
    yield normalized;
    for (final value in normalized.values) {
      yield* deepMaps(value);
    }
    return;
  }
  if (root is List) {
    for (final item in root) {
      yield* deepMaps(item);
    }
  }
}

Map<String, dynamic>? tryDecodeJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  if (raw is String) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
  }
  return null;
}

List<dynamic> asDynamicList(Object? raw) {
  if (raw is List) return raw;
  return const [];
}

String? fileNameFromUrl(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return null;
  final segment = parsed.pathSegments.isEmpty ? '' : parsed.pathSegments.last;
  return normalizeShareText(segment);
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final normalized = normalizeShareText(value);
    if (normalized != null) return normalized;
  }
  return null;
}

bool _hasArticleContent(String? contentHtml, String? textContent) {
  if ((contentHtml ?? '').trim().isNotEmpty) return true;
  return (textContent ?? '').trim().length >= 80;
}
