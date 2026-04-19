import 'package:flutter/foundation.dart';

import '../../data/models/memo_clip_card_metadata.dart';
import 'share_handler.dart';

enum ShareCaptureStatus { success, failure }

enum ShareCaptureFailure {
  unsupportedUrl,
  loadTimeout,
  webViewError,
  domUnavailable,
  parserEmpty,
  unknown,
}

enum ShareCaptureStage {
  loadingPage,
  waitingForDynamicContent,
  detectingMedia,
  parsingArticle,
  buildingPreview,
  downloadingVideo,
  compressingVideo,
}

enum ShareClipPhase { loading, success, failure, processingVideo, composing }

enum SharePageKind { article, video, unknown }

enum ShareVideoSource {
  parser,
  meta,
  dom,
  jsonLd,
  link,
  request,
  ajax,
  fetch,
  resource,
}

@immutable
class ShareVideoCandidate {
  const ShareVideoCandidate({
    required this.id,
    required this.url,
    required this.source,
    this.title,
    this.mimeType,
    this.thumbnailUrl,
    this.referer,
    this.headers,
    this.cookieUrl,
    this.isDirectDownloadable = false,
    this.priority = 0,
    this.parserTag,
    this.reason,
  });

  final String id;
  final String url;
  final String? title;
  final String? mimeType;
  final String? thumbnailUrl;
  final ShareVideoSource source;
  final String? referer;
  final Map<String, String>? headers;
  final String? cookieUrl;
  final bool isDirectDownloadable;
  final int priority;
  final String? parserTag;
  final String? reason;

  String get dedupeKey => normalizeShareVideoUrl(url);

  ShareVideoCandidate copyWith({
    String? id,
    String? url,
    String? title,
    String? mimeType,
    String? thumbnailUrl,
    ShareVideoSource? source,
    String? referer,
    Map<String, String>? headers,
    String? cookieUrl,
    bool? isDirectDownloadable,
    int? priority,
    String? parserTag,
    String? reason,
  }) {
    return ShareVideoCandidate(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      mimeType: mimeType ?? this.mimeType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      source: source ?? this.source,
      referer: referer ?? this.referer,
      headers: headers ?? this.headers,
      cookieUrl: cookieUrl ?? this.cookieUrl,
      isDirectDownloadable: isDirectDownloadable ?? this.isDirectDownloadable,
      priority: priority ?? this.priority,
      parserTag: parserTag ?? this.parserTag,
      reason: reason ?? this.reason,
    );
  }
}

@immutable
class ShareDeferredVideoAttachmentRequest {
  const ShareDeferredVideoAttachmentRequest({
    required this.captureResult,
    required this.candidate,
  });

  final ShareCaptureResult captureResult;
  final ShareVideoCandidate candidate;

  String get id => candidate.id;

  String get title =>
      normalizeShareText(candidate.title) ??
      normalizeShareText(captureResult.articleTitle) ??
      normalizeShareText(captureResult.pageTitle) ??
      captureResult.finalUrl.host;

  String? get thumbnailUrl =>
      normalizeShareText(candidate.thumbnailUrl) ??
      normalizeShareText(captureResult.leadImageUrl);
}

@immutable
class ShareDeferredInlineImageAttachmentRequest {
  const ShareDeferredInlineImageAttachmentRequest({
    required this.captureResult,
    required this.sourceUrl,
    required this.index,
  });

  final ShareCaptureResult captureResult;
  final String sourceUrl;
  final int index;

  String get id => 'inline-image-$index';
}

String normalizeShareVideoUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;
  if (uri.scheme == 'blob' || uri.scheme == 'data') {
    return trimmed;
  }
  final normalized = uri.replace(fragment: '');
  return normalized.toString();
}

String? normalizeShareText(String? value) {
  if (value == null) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

@immutable
class ShareClipMetadataDraft {
  const ShareClipMetadataDraft({
    required this.clipKind,
    required this.platform,
    required this.sourceName,
    this.sourceAvatarUrl = '',
    this.authorName = '',
    this.authorAvatarUrl = '',
    required this.sourceUrl,
    this.leadImageUrl = '',
    this.parserTag = '',
  });

  final MemoClipKind clipKind;
  final MemoClipPlatform platform;
  final String sourceName;
  final String sourceAvatarUrl;
  final String authorName;
  final String authorAvatarUrl;
  final String sourceUrl;
  final String leadImageUrl;
  final String parserTag;

  MemoClipCardMetadata toMemoClipCardMetadata({
    required String memoUid,
    required DateTime now,
  }) {
    return MemoClipCardMetadata(
      memoUid: memoUid,
      clipKind: clipKind,
      platform: platform,
      sourceName: sourceName.trim(),
      sourceAvatarUrl: sourceAvatarUrl.trim(),
      authorName: authorName.trim(),
      authorAvatarUrl: authorAvatarUrl.trim(),
      sourceUrl: sourceUrl.trim(),
      leadImageUrl: leadImageUrl.trim(),
      parserTag: parserTag.trim(),
      createdTime: now,
      updatedTime: now,
    );
  }
}

@immutable
class ShareCaptureRequest {
  const ShareCaptureRequest({
    required this.payload,
    required this.url,
    required this.sharedTitle,
    required this.sharedText,
  });

  final SharePayload payload;
  final Uri url;
  final String? sharedTitle;
  final String sharedText;
}

@immutable
class ShareCaptureResult {
  const ShareCaptureResult({
    required this.status,
    required this.finalUrl,
    this.pageTitle,
    this.articleTitle,
    this.siteName,
    this.sourceAvatarUrl,
    this.byline,
    this.authorAvatarUrl,
    this.excerpt,
    this.contentHtml,
    this.textContent,
    this.leadImageUrl,
    this.length = 0,
    this.readabilitySucceeded = false,
    this.pageKind = SharePageKind.unknown,
    this.videoCandidates = const [],
    this.unsupportedVideoCandidates = const [],
    this.siteParserTag,
    this.pageUserAgent,
    this.failure,
    this.failureMessage,
  });

  const ShareCaptureResult.success({
    required Uri finalUrl,
    String? pageTitle,
    String? articleTitle,
    String? siteName,
    String? sourceAvatarUrl,
    String? byline,
    String? authorAvatarUrl,
    String? excerpt,
    String? contentHtml,
    String? textContent,
    String? leadImageUrl,
    int length = 0,
    bool readabilitySucceeded = false,
    SharePageKind pageKind = SharePageKind.unknown,
    List<ShareVideoCandidate> videoCandidates = const [],
    List<ShareVideoCandidate> unsupportedVideoCandidates = const [],
    String? siteParserTag,
    String? pageUserAgent,
  }) : this(
         status: ShareCaptureStatus.success,
         finalUrl: finalUrl,
         pageTitle: pageTitle,
         articleTitle: articleTitle,
         siteName: siteName,
         sourceAvatarUrl: sourceAvatarUrl,
         byline: byline,
         authorAvatarUrl: authorAvatarUrl,
         excerpt: excerpt,
         contentHtml: contentHtml,
         textContent: textContent,
         leadImageUrl: leadImageUrl,
         length: length,
         readabilitySucceeded: readabilitySucceeded,
         pageKind: pageKind,
         videoCandidates: videoCandidates,
         unsupportedVideoCandidates: unsupportedVideoCandidates,
         siteParserTag: siteParserTag,
         pageUserAgent: pageUserAgent,
       );

  const ShareCaptureResult.failure({
    required Uri finalUrl,
    required ShareCaptureFailure failure,
    String? failureMessage,
    String? pageTitle,
    String? articleTitle,
    String? siteName,
    String? sourceAvatarUrl,
    String? excerpt,
    String? textContent,
    SharePageKind pageKind = SharePageKind.unknown,
    List<ShareVideoCandidate> videoCandidates = const [],
    List<ShareVideoCandidate> unsupportedVideoCandidates = const [],
    String? siteParserTag,
    String? pageUserAgent,
  }) : this(
         status: ShareCaptureStatus.failure,
         finalUrl: finalUrl,
         failure: failure,
         failureMessage: failureMessage,
         pageTitle: pageTitle,
         articleTitle: articleTitle,
         siteName: siteName,
         sourceAvatarUrl: sourceAvatarUrl,
         excerpt: excerpt,
         textContent: textContent,
         pageKind: pageKind,
         videoCandidates: videoCandidates,
         unsupportedVideoCandidates: unsupportedVideoCandidates,
         siteParserTag: siteParserTag,
         pageUserAgent: pageUserAgent,
       );

  final ShareCaptureStatus status;
  final Uri finalUrl;
  final String? pageTitle;
  final String? articleTitle;
  final String? siteName;
  final String? sourceAvatarUrl;
  final String? byline;
  final String? authorAvatarUrl;
  final String? excerpt;
  final String? contentHtml;
  final String? textContent;
  final String? leadImageUrl;
  final int length;
  final bool readabilitySucceeded;
  final SharePageKind pageKind;
  final List<ShareVideoCandidate> videoCandidates;
  final List<ShareVideoCandidate> unsupportedVideoCandidates;
  final String? siteParserTag;
  final String? pageUserAgent;
  final ShareCaptureFailure? failure;
  final String? failureMessage;

  bool get isSuccess => status == ShareCaptureStatus.success;

  bool get hasHtmlContent => (contentHtml ?? '').trim().isNotEmpty;

  bool get hasTextContent => (textContent ?? '').trim().isNotEmpty;

  bool get hasDirectVideoCandidates => videoCandidates.isNotEmpty;

  bool get hasAnyVideoCandidates =>
      videoCandidates.isNotEmpty || unsupportedVideoCandidates.isNotEmpty;

  bool get isVideoPage => pageKind == SharePageKind.video;
}

@immutable
class ShareComposeRequest {
  const ShareComposeRequest({
    required this.text,
    required this.selectionOffset,
    this.attachmentPaths = const [],
    this.initialAttachmentSeeds = const [],
    this.deferredInlineImageAttachments = const [],
    this.deferredVideoAttachments = const [],
    this.clipMetadataDraft,
    this.userMessage,
  });

  final String text;
  final int selectionOffset;
  final List<String> attachmentPaths;
  final List<ShareAttachmentSeed> initialAttachmentSeeds;
  final List<ShareDeferredInlineImageAttachmentRequest>
  deferredInlineImageAttachments;
  final List<ShareDeferredVideoAttachmentRequest> deferredVideoAttachments;
  final ShareClipMetadataDraft? clipMetadataDraft;
  final String? userMessage;

  ShareComposeRequest copyWith({
    String? text,
    int? selectionOffset,
    List<String>? attachmentPaths,
    List<ShareAttachmentSeed>? initialAttachmentSeeds,
    List<ShareDeferredInlineImageAttachmentRequest>?
    deferredInlineImageAttachments,
    List<ShareDeferredVideoAttachmentRequest>? deferredVideoAttachments,
    ShareClipMetadataDraft? clipMetadataDraft,
    String? userMessage,
  }) {
    return ShareComposeRequest(
      text: text ?? this.text,
      selectionOffset: selectionOffset ?? this.selectionOffset,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      initialAttachmentSeeds:
          initialAttachmentSeeds ?? this.initialAttachmentSeeds,
      deferredInlineImageAttachments:
          deferredInlineImageAttachments ?? this.deferredInlineImageAttachments,
      deferredVideoAttachments:
          deferredVideoAttachments ?? this.deferredVideoAttachments,
      clipMetadataDraft: clipMetadataDraft ?? this.clipMetadataDraft,
      userMessage: userMessage ?? this.userMessage,
    );
  }
}

@immutable
class ShareAttachmentSeed {
  const ShareAttachmentSeed({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
    this.skipCompression = false,
    this.shareInlineImage = false,
    this.fromThirdPartyShare = false,
    this.sourceUrl,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
  final bool skipCompression;
  final bool shareInlineImage;
  final bool fromThirdPartyShare;
  final String? sourceUrl;
}

@immutable
class ShareClipViewState {
  const ShareClipViewState({
    required this.phase,
    required this.stage,
    required this.linkOnlyRequest,
    this.result,
    this.previewText,
    this.processingMessage,
    this.activeVideoId,
    this.downloadProgress,
    this.compressionProgress,
    this.autoComposeRequest,
  });

  const ShareClipViewState.loading({
    required ShareComposeRequest linkOnlyRequest,
    ShareCaptureStage stage = ShareCaptureStage.loadingPage,
  }) : this(
         phase: ShareClipPhase.loading,
         stage: stage,
         linkOnlyRequest: linkOnlyRequest,
       );

  final ShareClipPhase phase;
  final ShareCaptureStage stage;
  final ShareComposeRequest linkOnlyRequest;
  final ShareCaptureResult? result;
  final String? previewText;
  final String? processingMessage;
  final String? activeVideoId;
  final double? downloadProgress;
  final double? compressionProgress;
  final ShareComposeRequest? autoComposeRequest;

  ShareClipViewState copyWith({
    ShareClipPhase? phase,
    ShareCaptureStage? stage,
    ShareComposeRequest? linkOnlyRequest,
    ShareCaptureResult? result,
    String? previewText,
    String? processingMessage,
    String? activeVideoId,
    double? downloadProgress,
    double? compressionProgress,
    ShareComposeRequest? autoComposeRequest,
    bool clearResult = false,
    bool clearPreviewText = false,
    bool clearProcessingMessage = false,
    bool clearActiveVideoId = false,
    bool clearDownloadProgress = false,
    bool clearCompressionProgress = false,
    bool clearAutoComposeRequest = false,
  }) {
    return ShareClipViewState(
      phase: phase ?? this.phase,
      stage: stage ?? this.stage,
      linkOnlyRequest: linkOnlyRequest ?? this.linkOnlyRequest,
      result: clearResult ? null : (result ?? this.result),
      previewText: clearPreviewText ? null : (previewText ?? this.previewText),
      processingMessage: clearProcessingMessage
          ? null
          : (processingMessage ?? this.processingMessage),
      activeVideoId: clearActiveVideoId
          ? null
          : (activeVideoId ?? this.activeVideoId),
      downloadProgress: clearDownloadProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      compressionProgress: clearCompressionProgress
          ? null
          : (compressionProgress ?? this.compressionProgress),
      autoComposeRequest: clearAutoComposeRequest
          ? null
          : (autoComposeRequest ?? this.autoComposeRequest),
    );
  }
}

ShareCaptureRequest? buildShareCaptureRequest(SharePayload payload) {
  final sharedText = (payload.text ?? '').trim();
  final rawUrl = extractShareUrl(sharedText);
  if (rawUrl == null) return null;
  final url = Uri.tryParse(rawUrl);
  if (url == null) return null;
  return ShareCaptureRequest(
    payload: payload,
    url: url,
    sharedTitle: payload.title,
    sharedText: sharedText,
  );
}
