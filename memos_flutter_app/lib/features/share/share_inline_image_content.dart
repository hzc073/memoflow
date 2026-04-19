import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/url.dart';
import '../../data/models/attachment.dart';
import 'share_clip_models.dart';

const String _thirdPartyShareMemoMarker = '<!-- memoflow-third-party-share -->';
final RegExp _shareInlineMarkdownImagePattern = RegExp(
  r'!\[[^\]]*]\(([^)\s]+)(?:\s+"[^"]*")?\)',
);
final RegExp _shareInlineCodeFencePattern = RegExp(r'^\s*(```|~~~)');
final RegExp _shareInlineHtmlImagePattern = RegExp(
  r'''<img\b[^>]*\bsrc=("|')(.*?)\1[^>]*>''',
  caseSensitive: false,
  dotAll: true,
);

String shareInlineLocalUrlFromPath(String filePath) {
  final trimmed = filePath.trim();
  if (trimmed.isEmpty) return '';
  return Uri.file(trimmed).toString();
}

String buildThirdPartyShareMemoMarker() => _thirdPartyShareMemoMarker;

bool contentHasThirdPartyShareMarker(String content) {
  return content.contains(_thirdPartyShareMemoMarker);
}

String buildShareInlineImagePlaceholder(String uid) {
  return '<!-- memoflow-share-inline:$uid -->';
}

String buildShareInlineSyncContent(
  String content,
  Iterable<ShareAttachmentSeed> attachments,
) {
  var next = content;
  for (final attachment in attachments) {
    if (!attachment.shareInlineImage) continue;
    final localUrl = shareInlineLocalUrlFromPath(attachment.filePath);
    if (localUrl.isEmpty) continue;
    final placeholder = buildShareInlineImagePlaceholder(attachment.uid);
    next = _replaceHtmlImageTag(next, localUrl, placeholder);
    next = _replaceMarkdownImage(next, localUrl, placeholder);
  }
  return next;
}

String replaceShareInlineLocalUrlWithRemote(
  String content, {
  required String localUrl,
  required String remoteUrl,
}) {
  if (localUrl.trim().isEmpty || remoteUrl.trim().isEmpty) {
    return content;
  }
  return replaceShareInlineImageUrl(
    content,
    fromUrl: localUrl,
    toUrl: remoteUrl,
  );
}

String replaceShareInlineImageUrl(
  String content, {
  required String fromUrl,
  required String toUrl,
}) {
  if (fromUrl.trim().isEmpty || toUrl.trim().isEmpty) {
    return content;
  }
  var next = content;
  final rawFromUrl = fromUrl.trim();
  final rawToUrl = toUrl.trim();
  final escapedToUrl = _escapeHtmlAttribute(rawToUrl);
  for (final variant in _shareInlineImageUrlVariants(rawFromUrl)) {
    next = next.replaceAll(
      variant,
      variant == rawFromUrl ? rawToUrl : escapedToUrl,
    );
  }
  return next;
}

bool contentContainsShareInlineImageUrl(String content, String url) {
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) return false;
  for (final variant in _shareInlineImageUrlVariants(trimmedUrl)) {
    if (content.contains(variant)) {
      return true;
    }
  }
  return false;
}

String removeShareInlineImageReferences(
  String content, {
  required String localUrl,
}) {
  if (localUrl.trim().isEmpty) return content;
  var next = _replaceHtmlImageTag(content, localUrl, '');
  next = _replaceMarkdownImage(next, localUrl, '');
  return _cleanupBlankLines(next);
}

bool contentContainsShareInlineLocalUrl(String content, String filePath) {
  final localUrl = shareInlineLocalUrlFromPath(filePath);
  if (localUrl.isEmpty) return false;
  return content.contains(localUrl);
}

String rewriteShareInlineImageUrlsForSyncContent(
  String content, {
  required Map<String, String> replacements,
  Set<String> removeLocalUrls = const <String>{},
}) {
  if (content.trim().isEmpty) return content;

  var next = content;
  final replacementEntries = replacements.entries
      .where((entry) => entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
      .toList(growable: false)
    ..sort((left, right) => right.key.length.compareTo(left.key.length));
  for (final entry in replacementEntries) {
    next = replaceShareInlineImageUrl(
      next,
      fromUrl: entry.key,
      toUrl: entry.value,
    );
  }

  final removalList = removeLocalUrls
      .where((url) => url.trim().isNotEmpty && !replacements.containsKey(url))
      .toList(growable: false)
    ..sort((left, right) => right.length.compareTo(left.length));
  for (final localUrl in removalList) {
    next = removeShareInlineImageReferences(next, localUrl: localUrl);
  }

  return _cleanupBlankLines(next);
}

List<String> extractShareInlineLocalImageUrls(String content) {
  if (content.trim().isEmpty) return const <String>[];

  final urls = <String>{};
  final htmlBuffer = StringBuffer();
  var inFence = false;
  for (final line in content.split('\n')) {
    if (_shareInlineCodeFencePattern.hasMatch(line.trimLeft())) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    for (final match in _shareInlineMarkdownImagePattern.allMatches(line)) {
      var url = (match.group(1) ?? '').trim();
      if (url.startsWith('<') && url.endsWith('>') && url.length > 2) {
        url = url.substring(1, url.length - 1).trim();
      }
      if (_isShareInlineLocalLikeUrl(url)) {
        urls.add(url);
      }
    }

    htmlBuffer.writeln(line);
  }

  final htmlContent = htmlBuffer.toString();
  for (final match in _shareInlineHtmlImagePattern.allMatches(htmlContent)) {
    final url = (match.group(2) ?? '').trim();
    if (_isShareInlineLocalLikeUrl(url)) {
      urls.add(url);
    }
  }

  return urls.toList(growable: false);
}

String? resolveShareInlineAttachmentRemoteUrl(
  Attachment attachment, {
  Uri? baseUrl,
}) {
  final externalLink = attachment.externalLink.trim();
  final filename = attachment.filename.trim();
  if (externalLink.isNotEmpty && !_isShareInlineLocalLikeUrl(externalLink)) {
    final parsed = Uri.tryParse(externalLink);
    String candidate = externalLink;
    if (parsed != null && filename.isNotEmpty) {
      final segments = parsed.pathSegments;
      if (segments.length == 3 &&
          segments[0] == 'file' &&
          (segments[1] == 'resources' || segments[1] == 'attachments')) {
        final repaired = parsed
            .replace(pathSegments: [...segments, filename])
            .toString();
        if (externalLink.startsWith('/') && !repaired.startsWith('/')) {
          candidate = '/$repaired';
        } else {
          candidate = repaired;
        }
      }
    }
    return baseUrl == null ? candidate : resolveMaybeRelativeUrl(baseUrl, candidate);
  }

  final name = attachment.name.trim();
  if (name.isEmpty) return null;
  if (!name.startsWith('resources/') && !name.startsWith('attachments/')) {
    return null;
  }
  final relativePath = filename.isNotEmpty ? '/file/$name/$filename' : '/file/$name';
  if (baseUrl == null) {
    return relativePath;
  }
  return resolveMaybeRelativeUrl(baseUrl, relativePath);
}

String buildShareInlineImageFilename({
  required int index,
  required String sourceUrl,
  String? mimeType,
}) {
  final parsed = Uri.tryParse(sourceUrl);
  final rawName = parsed?.pathSegments.isNotEmpty == true
      ? parsed!.pathSegments.last
      : 'shared-inline-image';
  final ext = _resolveImageExtension(sourceUrl, mimeType);
  final baseName = p.basenameWithoutExtension(rawName).trim();
  final safeBase = baseName.isEmpty
      ? 'shared_inline_image_${index + 1}'
      : baseName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return '$safeBase$ext';
}

String _replaceHtmlImageTag(
  String content,
  String localUrl,
  String replacement,
) {
  final escaped = RegExp.escape(localUrl);
  final pattern = RegExp(
    '<img\\b[^>]*\\bsrc=("|\')$escaped\\1[^>]*>',
    caseSensitive: false,
  );
  return content.replaceAll(pattern, replacement);
}

String _replaceMarkdownImage(
  String content,
  String localUrl,
  String replacement,
) {
  final escaped = RegExp.escape(localUrl);
  final pattern = RegExp(
    '!\\[[^\\]]*\\]\\(<?$escaped>?(?:\\s+"[^"]*")?\\)',
    caseSensitive: false,
  );
  return content.replaceAll(pattern, replacement);
}

String _cleanupBlankLines(String content) {
  return content
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .trimRight();
}

bool _isShareInlineLocalLikeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  final scheme = uri?.scheme.toLowerCase() ?? '';
  return scheme == 'file' || scheme == 'content';
}

Iterable<String> _shareInlineImageUrlVariants(String url) sync* {
  final variants = <String>{};
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;
  variants.add(trimmed);
  variants.add(_escapeHtmlAttribute(trimmed));
  for (final variant in variants) {
    if (variant.isNotEmpty) {
      yield variant;
    }
  }
}

String _escapeHtmlAttribute(String value) {
  return const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
}

String _resolveImageExtension(String sourceUrl, String? mimeType) {
  final parsed = Uri.tryParse(sourceUrl);
  final path = parsed?.path.toLowerCase() ?? sourceUrl.toLowerCase();
  for (final ext in const ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
    if (path.contains(ext)) return ext;
  }
  final wxFormat = parsed?.queryParameters['wx_fmt']?.trim().toLowerCase();
  switch (wxFormat) {
    case 'jpeg':
    case 'jpg':
      return '.jpg';
    case 'png':
      return '.png';
    case 'webp':
      return '.webp';
    case 'gif':
      return '.gif';
  }
  final normalizedMime = (mimeType ?? '').trim().toLowerCase();
  if (normalizedMime.contains('png')) return '.png';
  if (normalizedMime.contains('webp')) return '.webp';
  if (normalizedMime.contains('gif')) return '.gif';
  return '.jpg';
}
