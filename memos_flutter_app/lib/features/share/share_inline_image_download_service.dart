import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';
import '../../core/uid.dart';
import '../../data/logs/log_manager.dart';
import 'share_clip_models.dart';
import 'share_inline_image_content.dart';

@immutable
class ShareInlineImageDownloadResult {
  const ShareInlineImageDownloadResult({
    required this.contentHtml,
    required this.attachmentSeeds,
  });

  final String? contentHtml;
  final List<ShareAttachmentSeed> attachmentSeeds;
}

@immutable
class ShareInlineImageHttpResponse {
  const ShareInlineImageHttpResponse({required this.bytes, this.mimeType});

  final List<int> bytes;
  final String? mimeType;
}

abstract class ShareInlineImageHttpClient {
  Future<ShareInlineImageHttpResponse> download(
    String url, {
    required Map<String, String> headers,
    void Function(int received, int total)? onProgress,
  });
}

class DioShareInlineImageHttpClient implements ShareInlineImageHttpClient {
  DioShareInlineImageHttpClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<ShareInlineImageHttpResponse> download(
    String url, {
    required Map<String, String> headers,
    void Function(int received, int total)? onProgress,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
        followRedirects: true,
      ),
      onReceiveProgress: onProgress,
    );
    final bytes = response.data ?? const <int>[];
    final mimeType = response.headers
        .value(Headers.contentTypeHeader)
        ?.split(';')
        .first
        .trim();
    return ShareInlineImageHttpResponse(bytes: bytes, mimeType: mimeType);
  }
}

class ShareInlineImageDownloadService {
  ShareInlineImageDownloadService({
    ShareInlineImageHttpClient? client,
    Future<Directory> Function()? resolveDirectory,
    Future<String?> Function(Uri scope)? readCookieHeader,
    Future<void> Function(Duration delay)? pause,
    this.requestInterval = const Duration(milliseconds: 850),
  }) : _client = client ?? DioShareInlineImageHttpClient(),
       _resolveDirectory = resolveDirectory ?? _defaultResolveDirectory,
       _readCookieHeader = readCookieHeader ?? _defaultReadCookieHeader,
       _pause = pause ?? _defaultPause;

  final ShareInlineImageHttpClient _client;
  final Future<Directory> Function() _resolveDirectory;
  final Future<String?> Function(Uri scope) _readCookieHeader;
  final Future<void> Function(Duration delay) _pause;
  final Duration requestInterval;

  Future<List<ShareDeferredInlineImageAttachmentRequest>>
  discoverDeferredInlineImageAttachments(ShareCaptureResult result) async {
    final rawHtml = normalizeShareText(result.contentHtml);
    if (rawHtml == null) {
      LogManager.instance.debug(
        'ShareInlineImage: discover_skipped',
        context: {
          'host': result.finalUrl.host,
          'reason': 'missing_content_html',
          'parserTag': result.siteParserTag,
        },
      );
      return const <ShareDeferredInlineImageAttachmentRequest>[];
    }

    final fragment = html_parser.parseFragment(rawHtml);
    final imageElements = fragment.querySelectorAll('img[src]');
    if (imageElements.isEmpty) {
      final dataSrcCount = fragment.querySelectorAll('img[data-src]').length;
      LogManager.instance.debug(
        'ShareInlineImage: discover_skipped',
        context: {
          'host': result.finalUrl.host,
          'reason': 'no_img_src',
          'imgDataSrcCount': dataSrcCount,
          'htmlLength': rawHtml.length,
          'parserTag': result.siteParserTag,
        },
      );
      return const <ShareDeferredInlineImageAttachmentRequest>[];
    }

    final uniqueSources = <String, Uri>{};
    var skippedMissingSrc = 0;
    var skippedUnresolvable = 0;
    for (final element in imageElements) {
      final src = normalizeShareText(element.attributes['src']);
      if (src == null) {
        skippedMissingSrc++;
        continue;
      }
      final resolved = _resolveImageUri(result.finalUrl, src);
      if (resolved == null) {
        skippedUnresolvable++;
        continue;
      }
      uniqueSources.putIfAbsent(_normalizedImageKey(resolved), () => resolved);
    }

    if (uniqueSources.isEmpty) {
      LogManager.instance.debug(
        'ShareInlineImage: discover_skipped',
        context: {
          'host': result.finalUrl.host,
          'reason': 'no_resolved_http_images',
          'imgSrcCount': imageElements.length,
          'skippedMissingSrc': skippedMissingSrc,
          'skippedUnresolvable': skippedUnresolvable,
          'parserTag': result.siteParserTag,
        },
      );
      return const <ShareDeferredInlineImageAttachmentRequest>[];
    }

    final requests = uniqueSources.values.indexed
        .map(
          (entry) => ShareDeferredInlineImageAttachmentRequest(
            captureResult: result,
            sourceUrl: entry.$2.toString(),
            index: entry.$1,
          ),
        )
        .toList(growable: false);
    LogManager.instance.debug(
      'ShareInlineImage: discover_result',
      context: {
        'host': result.finalUrl.host,
        'imgSrcCount': imageElements.length,
        'uniqueHttpImageCount': requests.length,
        'skippedMissingSrc': skippedMissingSrc,
        'skippedUnresolvable': skippedUnresolvable,
        'sampleUrls': requests
            .take(3)
            .map((item) => item.sourceUrl)
            .toList(growable: false),
        'parserTag': result.siteParserTag,
      },
    );
    return requests;
  }

  Future<ShareAttachmentSeed?> downloadDeferredInlineImageAttachment(
    ShareDeferredInlineImageAttachmentRequest request, {
    void Function(double progress)? onProgress,
  }) async {
    final sourceUri = Uri.tryParse(request.sourceUrl);
    if (sourceUri == null) {
      LogManager.instance.warn(
        'ShareInlineImage: download_skipped',
        context: {
          'sourceUrl': request.sourceUrl,
          'reason': 'invalid_uri',
          'host': request.captureResult.finalUrl.host,
        },
      );
      return null;
    }

    final directory = await _resolveDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final headers = await _buildRequestHeaders(
      result: request.captureResult,
      imageUri: sourceUri,
    );
    final response = await _client.download(
      sourceUri.toString(),
      headers: headers,
      onProgress: (received, total) {
        if (onProgress == null || total <= 0) return;
        onProgress((received / total).clamp(0, 1));
      },
    );
    if (response.bytes.isEmpty) {
      LogManager.instance.warn(
        'ShareInlineImage: download_empty',
        context: {
          'sourceUrl': sourceUri.toString(),
          'host': request.captureResult.finalUrl.host,
          'parserTag': request.captureResult.siteParserTag,
        },
      );
      return null;
    }

    final fileName = _buildFileName(
      index: request.index,
      sourceUrl: sourceUri.toString(),
      mimeType: response.mimeType,
    );
    final filePath = p.join(
      directory.path,
      '${DateTime.now().millisecondsSinceEpoch}_${request.index}_$fileName',
    );
    final file = File(filePath);
    await file.writeAsBytes(response.bytes, flush: true);
    final size = await file.length();
    if (size <= 0) {
      try {
        await file.delete();
      } catch (_) {}
      LogManager.instance.warn(
        'ShareInlineImage: download_zero_size',
        context: {
          'sourceUrl': sourceUri.toString(),
          'filePath': filePath,
          'host': request.captureResult.finalUrl.host,
          'parserTag': request.captureResult.siteParserTag,
        },
      );
      return null;
    }

    LogManager.instance.debug(
      'ShareInlineImage: download_result',
      context: {
        'sourceUrl': sourceUri.toString(),
        'filePath': filePath,
        'size': size,
        'mimeType': normalizeShareText(response.mimeType) ?? 'image/jpeg',
        'host': request.captureResult.finalUrl.host,
        'parserTag': request.captureResult.siteParserTag,
      },
    );
    return ShareAttachmentSeed(
      uid: generateUid(),
      filePath: filePath,
      filename: p.basename(filePath),
      mimeType: normalizeShareText(response.mimeType) ?? 'image/jpeg',
      size: size,
      shareInlineImage: true,
      fromThirdPartyShare: true,
      sourceUrl: sourceUri.toString(),
    );
  }

  Future<ShareInlineImageDownloadResult> prepare(
    ShareCaptureResult result,
  ) async {
    final rawHtml = normalizeShareText(result.contentHtml);
    if (rawHtml == null) {
      return const ShareInlineImageDownloadResult(
        contentHtml: null,
        attachmentSeeds: <ShareAttachmentSeed>[],
      );
    }

    final fragment = html_parser.parseFragment(rawHtml);
    final imageElements = fragment.querySelectorAll('img[src]');
    if (imageElements.isEmpty) {
      return ShareInlineImageDownloadResult(
        contentHtml: rawHtml,
        attachmentSeeds: const <ShareAttachmentSeed>[],
      );
    }

    final requests = await discoverDeferredInlineImageAttachments(result);
    if (requests.isEmpty) {
      return ShareInlineImageDownloadResult(
        contentHtml: rawHtml,
        attachmentSeeds: const <ShareAttachmentSeed>[],
      );
    }

    final downloaded = <String, ShareAttachmentSeed>{};
    var requestIndex = 0;
    for (final request in requests) {
      if (requestIndex > 0 && requestInterval > Duration.zero) {
        await _pause(requestInterval);
      }
      requestIndex++;
      try {
        final seed = await downloadDeferredInlineImageAttachment(request);
        if (seed == null) {
          continue;
        }
        downloaded[_normalizedImageKey(Uri.parse(request.sourceUrl))] = seed;
      } catch (_) {
        continue;
      }
    }

    if (downloaded.isEmpty) {
      return ShareInlineImageDownloadResult(
        contentHtml: rawHtml,
        attachmentSeeds: const <ShareAttachmentSeed>[],
      );
    }

    for (final element in imageElements) {
      final src = normalizeShareText(element.attributes['src']);
      if (src == null) continue;
      final resolved = _resolveImageUri(result.finalUrl, src);
      if (resolved == null) continue;
      final seed = downloaded[_normalizedImageKey(resolved)];
      if (seed == null) continue;
      element.attributes['src'] = shareInlineLocalUrlFromPath(seed.filePath);
    }

    return ShareInlineImageDownloadResult(
      contentHtml: _fragmentToHtml(fragment),
      attachmentSeeds: downloaded.values.toList(growable: false),
    );
  }

  Future<Map<String, String>> _buildRequestHeaders({
    required ShareCaptureResult result,
    required Uri imageUri,
  }) async {
    final headers = <String, String>{
      'Referer': result.finalUrl.toString(),
      'Accept':
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      if (normalizeShareText(result.pageUserAgent) != null)
        'User-Agent': result.pageUserAgent!,
    };
    final cookieHeader = await _readCookieHeader(imageUri);
    if (normalizeShareText(cookieHeader) != null) {
      headers['Cookie'] = cookieHeader!;
    }
    return headers;
  }

  Uri? _resolveImageUri(Uri baseUrl, String raw) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    final resolved = parsed.hasScheme ? parsed : baseUrl.resolveUri(parsed);
    final scheme = resolved.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return resolved.replace(fragment: '');
  }

  String _normalizedImageKey(Uri uri) => uri.toString();

  String _buildFileName({
    required int index,
    required String sourceUrl,
    String? mimeType,
  }) {
    final raw = buildShareInlineImageFilename(
      index: index,
      sourceUrl: sourceUrl,
      mimeType: mimeType,
    );
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  String _fragmentToHtml(dom.DocumentFragment fragment) {
    return fragment.nodes
        .map(
          (node) => switch (node) {
            dom.Element element => element.outerHtml,
            dom.Text text => text.text,
            _ => node.text ?? '',
          },
        )
        .join();
  }

  static Future<Directory> _defaultResolveDirectory() async {
    final root = await resolveAppSupportDirectory();
    return Directory(p.join(root.path, 'share_media_cache', 'inline_images'));
  }

  static Future<String?> _defaultReadCookieHeader(Uri scope) async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(scope.toString()),
      );
      if (cookies.isEmpty) return null;
      return cookies
          .map((item) => '${item.name}=${item.value ?? ''}')
          .join('; ');
    } catch (_) {
      return null;
    }
  }

  static Future<void> _defaultPause(Duration delay) {
    return Future<void>.delayed(delay);
  }
}
