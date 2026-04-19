import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'parsers/bilibili_share_page_parser.dart';
import 'parsers/coolapk_share_page_parser.dart';
import 'parsers/generic_share_page_parser.dart';
import 'parsers/share_page_parser.dart';
import 'parsers/wechat_share_page_parser.dart';
import 'parsers/xiaohongshu_share_page_parser.dart';
import 'share_capture_engine.dart';
import 'share_clip_models.dart';
import 'wechat_static_capture_strategy.dart';

class ShareCaptureInAppWebViewEngine implements ShareCaptureEngine {
  ShareCaptureInAppWebViewEngine({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle,
      _wechatStaticCaptureStrategy = WechatStaticCaptureStrategy();

  static const _readabilityAssetPath = 'third_party/readability/Readability.js';
  static const _bridgeAssetPath = 'assets/share/share_capture_bridge.js';
  static const _pageLoadTimeout = Duration(seconds: 12);
  static const _dynamicWaitWindow = Duration(milliseconds: 2500);
  static const _dynamicPollInterval = Duration(milliseconds: 300);
  static const _domReadTimeout = Duration(seconds: 2);
  static const _captureScriptTimeout = Duration(seconds: 10);
  static const _maxNetworkRecords = 200;

  final AssetBundle _assetBundle;
  final WechatStaticCaptureStrategy _wechatStaticCaptureStrategy;

  @override
  Future<ShareCaptureResult> capture(
    ShareCaptureRequest request, {
    void Function(ShareCaptureStage stage)? onStageChanged,
  }) async {
    if (!_isSupportedUrl(request.url)) {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.unsupportedUrl,
        failureMessage: 'Only http and https URLs are supported.',
      );
    }

    onStageChanged?.call(ShareCaptureStage.loadingPage);
    final staticResult = await _wechatStaticCaptureStrategy.capture(request);
    if (staticResult != null) {
      onStageChanged?.call(ShareCaptureStage.buildingPreview);
      return staticResult;
    }

    final readabilitySource = await _assetBundle.loadString(
      _readabilityAssetPath,
    );
    final bridgeSource = await _assetBundle.loadString(_bridgeAssetPath);

    HeadlessInAppWebView? headlessWebView;
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageReadyCompleter = Completer<void>();
    final networkRecords = <ShareNetworkRecord>[];
    String? webViewError;

    void addNetworkRecord(ShareNetworkRecord record) {
      if (networkRecords.length >= _maxNetworkRecords) return;
      if (normalizeShareText(record.url) == null) return;
      networkRecords.add(record);
    }

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(request.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useOnLoadResource: true,
          useShouldInterceptAjaxRequest: true,
          useShouldInterceptFetchRequest: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        onWebViewCreated: (controller) {
          if (!controllerCompleter.isCompleted) {
            controllerCompleter.complete(controller);
          }
        },
        onLoadStop: (controller, url) {
          if (!pageReadyCompleter.isCompleted) {
            pageReadyCompleter.complete();
          }
        },
        onReceivedError: (controller, requestInfo, error) {
          if (requestInfo.isForMainFrame ?? true) {
            webViewError = error.description;
            if (!pageReadyCompleter.isCompleted) {
              pageReadyCompleter.complete();
            }
          }
        },
        shouldInterceptRequest: (controller, requestInfo) async {
          addNetworkRecord(
            ShareNetworkRecord(
              kind: ShareNetworkRecordKind.request,
              url: requestInfo.url.toString(),
              method: normalizeShareText(requestInfo.method),
              referer: requestInfo.headers?['Referer'],
              headers: requestInfo.headers,
            ),
          );
          return null;
        },
        shouldInterceptAjaxRequest: (controller, ajaxRequest) async {
          addNetworkRecord(
            ShareNetworkRecord(
              kind: ShareNetworkRecordKind.ajax,
              url: ajaxRequest.url?.toString() ?? '',
              method: normalizeShareText(ajaxRequest.method),
              referer: normalizeShareText(
                ajaxRequest.headers?.getHeaders()['Referer']?.toString(),
              ),
              headers: ajaxRequest.headers?.getHeaders().map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            ),
          );
          return ajaxRequest;
        },
        onAjaxReadyStateChange: (controller, ajaxRequest) async {
          if (ajaxRequest.readyState == AjaxRequestReadyState.DONE) {
            addNetworkRecord(
              ShareNetworkRecord(
                kind: ShareNetworkRecordKind.ajax,
                url: ajaxRequest.url?.toString() ?? '',
                method: normalizeShareText(ajaxRequest.method),
                referer: normalizeShareText(
                  ajaxRequest.headers?.getHeaders()['Referer']?.toString(),
                ),
                headers: ajaxRequest.headers?.getHeaders().map(
                  (key, value) => MapEntry(key, value.toString()),
                ),
                responseBody: _serializeResponseBody(ajaxRequest.response),
              ),
            );
          }
          return AjaxRequestAction.PROCEED;
        },
        shouldInterceptFetchRequest: (controller, fetchRequest) async {
          addNetworkRecord(
            ShareNetworkRecord(
              kind: ShareNetworkRecordKind.fetch,
              url: fetchRequest.url?.toString() ?? '',
              method: normalizeShareText(fetchRequest.method),
              referer: normalizeShareText(fetchRequest.referrer),
              headers: fetchRequest.headers?.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            ),
          );
          return fetchRequest;
        },
        onLoadResource: (controller, resource) {
          addNetworkRecord(
            ShareNetworkRecord(
              kind: ShareNetworkRecordKind.resource,
              url: resource.url?.toString() ?? '',
              mimeType: normalizeShareText(resource.initiatorType),
            ),
          );
        },
      );

      await headlessWebView.run();
      final controller = await controllerCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      await pageReadyCompleter.future.timeout(_pageLoadTimeout);
      if (webViewError != null) {
        return ShareCaptureResult.failure(
          finalUrl: request.url,
          failure: ShareCaptureFailure.webViewError,
          failureMessage: webViewError,
        );
      }

      onStageChanged?.call(ShareCaptureStage.waitingForDynamicContent);
      await _waitForDynamicContent(controller);

      onStageChanged?.call(ShareCaptureStage.detectingMedia);
      final rawResult = await controller
          .evaluateJavascript(
            source: _buildCaptureScript(
              readabilitySource: readabilitySource,
              bridgeSource: bridgeSource,
            ),
          )
          .timeout(_captureScriptTimeout);

      onStageChanged?.call(ShareCaptureStage.buildingPreview);
      return _parseCaptureResult(request, rawResult, networkRecords);
    } on TimeoutException {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.loadTimeout,
        failureMessage: 'Timed out while loading the shared page.',
      );
    } catch (error) {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.unknown,
        failureMessage: error.toString(),
      );
    } finally {
      if (headlessWebView != null) {
        await headlessWebView.dispose();
      }
    }
  }

  bool _isSupportedUrl(Uri url) {
    return url.scheme == 'http' || url.scheme == 'https';
  }

  Future<void> _waitForDynamicContent(InAppWebViewController controller) async {
    final deadline = DateTime.now().add(_dynamicWaitWindow);
    _DomMetrics? previousMetrics;
    var stableSamples = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_dynamicPollInterval);
      final metrics = await _readDomMetrics(controller);
      if (metrics == null) continue;
      if (previousMetrics != null &&
          metrics.isStableComparedTo(previousMetrics)) {
        stableSamples += 1;
        if (stableSamples >= 2) return;
      } else {
        stableSamples = 0;
      }
      previousMetrics = metrics;
    }
  }

  Future<_DomMetrics?> _readDomMetrics(
    InAppWebViewController controller,
  ) async {
    try {
      final raw = await controller
          .evaluateJavascript(
            source: '''
(() => {
  const body = document.body || document.documentElement;
  return JSON.stringify({
    textLength: body && body.innerText ? body.innerText.length : 0,
    nodeCount: document.getElementsByTagName('*').length
  });
})()
''',
          )
          .timeout(_domReadTimeout);
      if (raw is! String || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return _DomMetrics(
        textLength: (decoded['textLength'] as num?)?.toInt() ?? 0,
        nodeCount: (decoded['nodeCount'] as num?)?.toInt() ?? 0,
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _buildCaptureScript({
    required String readabilitySource,
    required String bridgeSource,
  }) {
    return '''
(() => {
  const module = undefined;
  const exports = undefined;
  $readabilitySource
  $bridgeSource
  return JSON.stringify(memoflowCapture());
})()
''';
  }

  ShareCaptureResult _parseCaptureResult(
    ShareCaptureRequest request,
    dynamic rawResult,
    List<ShareNetworkRecord> networkRecords,
  ) {
    final decoded = _decodeJsonMap(rawResult);
    if (decoded == null) {
      return ShareCaptureResult.failure(
        finalUrl: request.url,
        failure: ShareCaptureFailure.domUnavailable,
        failureMessage: 'Failed to read page DOM from WebView.',
      );
    }

    final finalUrl =
        Uri.tryParse(decoded['finalUrl']?.toString() ?? '') ?? request.url;
    final genericParser = GenericSharePageParser();
    final specializedParsers = <SharePageParser>[
      BilibiliSharePageParser(),
      CoolapkSharePageParser(),
      WechatSharePageParser(),
      XiaohongshuSharePageParser(),
    ];
    final snapshot = SharePageSnapshot(
      requestUrl: request.url,
      finalUrl: finalUrl,
      host: finalUrl.host.toLowerCase(),
      bridgeData: decoded,
      networkRecords: networkRecords,
      userAgent: normalizeShareText(decoded['pageUserAgent']?.toString()),
    );
    final parserResults = <SharePageParserResult>[];
    for (final parser in specializedParsers) {
      if (parser.canParse(snapshot)) {
        parserResults.add(parser.parse(snapshot));
      }
    }
    parserResults.add(genericParser.parse(snapshot));
    final merged = mergeSharePageParserResults(parserResults);

    final contentHtml =
        normalizeShareText(merged.contentHtml) ??
        normalizeShareText(decoded['contentHtml']?.toString());
    final textContent =
        normalizeShareText(merged.textContent) ??
        normalizeShareText(decoded['textContent']?.toString());
    final readabilitySucceeded = decoded['readabilitySucceeded'] == true;
    final length =
        (decoded['length'] as num?)?.toInt() ?? textContent?.length ?? 0;
    final failureMessage = normalizeShareText(decoded['error']?.toString());

    final resolvedPageKind = merged.pageKind != SharePageKind.unknown
        ? merged.pageKind
        : ((contentHtml ?? '').isNotEmpty || (textContent ?? '').length >= 80)
        ? SharePageKind.article
        : SharePageKind.unknown;

    if (resolvedPageKind != SharePageKind.video &&
        (contentHtml == null || contentHtml.isEmpty) &&
        (textContent == null || textContent.length < 80)) {
      return ShareCaptureResult.failure(
        finalUrl: finalUrl,
        failure: ShareCaptureFailure.parserEmpty,
        failureMessage:
            failureMessage ??
            'Could not extract readable content from the shared page.',
        pageTitle: normalizeShareText(decoded['pageTitle']?.toString()),
        articleTitle:
            normalizeShareText(merged.title) ??
            normalizeShareText(decoded['articleTitle']?.toString()),
        siteName:
            normalizeShareText(merged.siteName) ??
            normalizeShareText(decoded['siteName']?.toString()),
        sourceAvatarUrl:
            normalizeShareText(merged.sourceAvatarUrl) ??
            normalizeShareText(decoded['wechatAccountAvatar']?.toString()),
        excerpt:
            normalizeShareText(merged.excerpt) ??
            normalizeShareText(decoded['excerpt']?.toString()),
        textContent: textContent,
        pageKind: resolvedPageKind,
        videoCandidates: merged.videoCandidates,
        unsupportedVideoCandidates: merged.unsupportedVideoCandidates,
        siteParserTag: merged.parserTag,
        pageUserAgent: snapshot.userAgent,
      );
    }

    return ShareCaptureResult.success(
      finalUrl: finalUrl,
      pageTitle: normalizeShareText(decoded['pageTitle']?.toString()),
      articleTitle:
          normalizeShareText(merged.title) ??
          normalizeShareText(decoded['articleTitle']?.toString()),
      siteName:
          normalizeShareText(merged.siteName) ??
          normalizeShareText(decoded['siteName']?.toString()),
      sourceAvatarUrl:
          normalizeShareText(merged.sourceAvatarUrl) ??
          normalizeShareText(decoded['wechatAccountAvatar']?.toString()),
      byline:
          normalizeShareText(merged.byline) ??
          normalizeShareText(decoded['byline']?.toString()),
      authorAvatarUrl:
          normalizeShareText(merged.authorAvatarUrl) ??
          normalizeShareText(decoded['wechatAuthorAvatar']?.toString()),
      excerpt:
          normalizeShareText(merged.excerpt) ??
          normalizeShareText(decoded['excerpt']?.toString()),
      contentHtml: contentHtml,
      textContent: textContent,
      leadImageUrl:
          normalizeShareText(merged.leadImageUrl) ??
          normalizeShareText(decoded['leadImageUrl']?.toString()),
      length: length,
      readabilitySucceeded: readabilitySucceeded,
      pageKind: resolvedPageKind,
      videoCandidates: merged.videoCandidates,
      unsupportedVideoCandidates: merged.unsupportedVideoCandidates,
      siteParserTag: merged.parserTag,
      pageUserAgent: snapshot.userAgent,
    );
  }

  String? _serializeResponseBody(Object? value) {
    if (value == null) return null;
    try {
      if (value is String) {
        return value.length <= 12000 ? value : value.substring(0, 12000);
      }
      final encoded = jsonEncode(value);
      return encoded.length <= 12000 ? encoded : encoded.substring(0, 12000);
    } catch (_) {
      return value.toString();
    }
  }

  Map<String, dynamic>? _decodeJsonMap(dynamic rawResult) {
    if (rawResult is Map<String, dynamic>) return rawResult;
    if (rawResult is Map) {
      return rawResult.map((key, value) => MapEntry(key.toString(), value));
    }
    if (rawResult is String && rawResult.isNotEmpty) {
      final decoded = jsonDecode(rawResult);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return null;
  }
}

class _DomMetrics {
  const _DomMetrics({required this.textLength, required this.nodeCount});

  final int textLength;
  final int nodeCount;

  bool isStableComparedTo(_DomMetrics other) {
    final textDelta = (textLength - other.textLength).abs();
    final nodeDelta = (nodeCount - other.nodeCount).abs();
    return textDelta <= 40 && nodeDelta <= 4;
  }
}
