import '../../data/models/memo_clip_card_metadata.dart';
import 'share_clip_models.dart';
import 'share_handler.dart';

class DesktopShareTaskLaunchPayload {
  const DesktopShareTaskLaunchPayload({
    required this.requestId,
    required this.payload,
  });

  final String requestId;
  final SharePayload payload;

  static DesktopShareTaskLaunchPayload? fromArgs(Object? args) {
    final map = _stringMap(args);
    if (map == null) return null;
    final requestId = (map['requestId'] as String? ?? '').trim();
    final payload = sharePayloadFromJson(map['payload']);
    if (requestId.isEmpty || payload == null) return null;
    return DesktopShareTaskLaunchPayload(
      requestId: requestId,
      payload: payload,
    );
  }
}

class DesktopShareTaskResult {
  const DesktopShareTaskResult({
    required this.requestId,
    required this.request,
  });

  final String requestId;
  final ShareComposeRequest request;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'requestId': requestId,
      'request': shareComposeRequestToJson(request),
    };
  }

  static DesktopShareTaskResult? fromArgs(Object? args) {
    final map = _stringMap(args);
    if (map == null) return null;
    final requestId = (map['requestId'] as String? ?? '').trim();
    final request = shareComposeRequestFromJson(map['request']);
    if (requestId.isEmpty || request == null) return null;
    return DesktopShareTaskResult(requestId: requestId, request: request);
  }
}

Map<String, dynamic> desktopShareTaskCanceledToJson(String requestId) {
  return <String, dynamic>{'requestId': requestId};
}

String? desktopShareTaskCanceledRequestId(Object? args) {
  final map = _stringMap(args);
  return (map?['requestId'] as String?)?.trim();
}

Map<String, dynamic> sharePayloadToJson(SharePayload payload) {
  return <String, dynamic>{
    'type': payload.type.name,
    'handlingMode': payload.handlingMode.name,
    if (payload.text != null) 'text': payload.text,
    if (payload.title != null) 'title': payload.title,
    'paths': payload.paths,
  };
}

SharePayload? sharePayloadFromJson(Object? value) {
  final map = _stringMap(value);
  if (map == null) return null;
  return SharePayload.fromArgs(map);
}

Map<String, dynamic> shareComposeRequestToJson(ShareComposeRequest request) {
  return <String, dynamic>{
    'text': request.text,
    'selectionOffset': request.selectionOffset,
    'attachmentPaths': request.attachmentPaths,
    'initialAttachmentSeeds': request.initialAttachmentSeeds
        .map(_shareAttachmentSeedToJson)
        .toList(growable: false),
    'deferredInlineImageAttachments': request.deferredInlineImageAttachments
        .map(_shareDeferredInlineImageAttachmentToJson)
        .toList(growable: false),
    'deferredVideoAttachments': request.deferredVideoAttachments
        .map(_shareDeferredVideoAttachmentToJson)
        .toList(growable: false),
    if (request.clipMetadataDraft != null)
      'clipMetadataDraft': _shareClipMetadataDraftToJson(
        request.clipMetadataDraft!,
      ),
    if (request.userMessage != null) 'userMessage': request.userMessage,
    'showLocalSaveSuccessToast': request.showLocalSaveSuccessToast,
  };
}

ShareComposeRequest? shareComposeRequestFromJson(Object? value) {
  final map = _stringMap(value);
  if (map == null) return null;
  final text = map['text'];
  final offset = map['selectionOffset'];
  if (text is! String) return null;
  return ShareComposeRequest(
    text: text,
    selectionOffset: _intValue(offset),
    attachmentPaths: _stringList(map['attachmentPaths']),
    initialAttachmentSeeds: _mapList(
      map['initialAttachmentSeeds'],
      _shareAttachmentSeedFromJson,
    ),
    deferredInlineImageAttachments: _mapList(
      map['deferredInlineImageAttachments'],
      _shareDeferredInlineImageAttachmentFromJson,
    ),
    deferredVideoAttachments: _mapList(
      map['deferredVideoAttachments'],
      _shareDeferredVideoAttachmentFromJson,
    ),
    clipMetadataDraft: _shareClipMetadataDraftFromJson(
      map['clipMetadataDraft'],
    ),
    userMessage: map['userMessage'] as String?,
    showLocalSaveSuccessToast: map['showLocalSaveSuccessToast'] == true,
  );
}

Map<String, dynamic> _shareAttachmentSeedToJson(ShareAttachmentSeed seed) {
  return <String, dynamic>{
    'uid': seed.uid,
    'filePath': seed.filePath,
    'filename': seed.filename,
    'mimeType': seed.mimeType,
    'size': seed.size,
    'skipCompression': seed.skipCompression,
    'shareInlineImage': seed.shareInlineImage,
    'fromThirdPartyShare': seed.fromThirdPartyShare,
    if (seed.sourceUrl != null) 'sourceUrl': seed.sourceUrl,
  };
}

ShareAttachmentSeed? _shareAttachmentSeedFromJson(Object? value) {
  final map = _stringMap(value);
  if (map == null) return null;
  final uid = map['uid'];
  final filePath = map['filePath'];
  final filename = map['filename'];
  final mimeType = map['mimeType'];
  if (uid is! String ||
      filePath is! String ||
      filename is! String ||
      mimeType is! String) {
    return null;
  }
  return ShareAttachmentSeed(
    uid: uid,
    filePath: filePath,
    filename: filename,
    mimeType: mimeType,
    size: _intValue(map['size']),
    skipCompression: map['skipCompression'] == true,
    shareInlineImage: map['shareInlineImage'] == true,
    fromThirdPartyShare: map['fromThirdPartyShare'] == true,
    sourceUrl: map['sourceUrl'] as String?,
  );
}

Map<String, dynamic> _shareClipMetadataDraftToJson(
  ShareClipMetadataDraft draft,
) {
  return <String, dynamic>{
    'clipKind': memoClipKindValue(draft.clipKind),
    'platform': memoClipPlatformValue(draft.platform),
    'sourceName': draft.sourceName,
    'sourceAvatarUrl': draft.sourceAvatarUrl,
    'authorName': draft.authorName,
    'authorAvatarUrl': draft.authorAvatarUrl,
    'sourceUrl': draft.sourceUrl,
    'leadImageUrl': draft.leadImageUrl,
    'parserTag': draft.parserTag,
  };
}

ShareClipMetadataDraft? _shareClipMetadataDraftFromJson(Object? value) {
  final map = _stringMap(value);
  if (map == null) return null;
  return ShareClipMetadataDraft(
    clipKind: memoClipKindFromValue(map['clipKind'] as String?),
    platform: memoClipPlatformFromValue(map['platform'] as String?),
    sourceName: map['sourceName'] as String? ?? '',
    sourceAvatarUrl: map['sourceAvatarUrl'] as String? ?? '',
    authorName: map['authorName'] as String? ?? '',
    authorAvatarUrl: map['authorAvatarUrl'] as String? ?? '',
    sourceUrl: map['sourceUrl'] as String? ?? '',
    leadImageUrl: map['leadImageUrl'] as String? ?? '',
    parserTag: map['parserTag'] as String? ?? '',
  );
}

Map<String, dynamic> _shareDeferredInlineImageAttachmentToJson(
  ShareDeferredInlineImageAttachmentRequest request,
) {
  return <String, dynamic>{
    'captureResult': _shareCaptureResultToJson(request.captureResult),
    'sourceUrl': request.sourceUrl,
    'index': request.index,
  };
}

ShareDeferredInlineImageAttachmentRequest?
_shareDeferredInlineImageAttachmentFromJson(Object? value) {
  final map = _stringMap(value);
  if (map == null) return null;
  final result = _shareCaptureResultFromJson(map['captureResult']);
  final sourceUrl = map['sourceUrl'];
  if (result == null || sourceUrl is! String) return null;
  return ShareDeferredInlineImageAttachmentRequest(
    captureResult: result,
    sourceUrl: sourceUrl,
    index: _intValue(map['index']),
  );
}

Map<String, dynamic> _shareDeferredVideoAttachmentToJson(
  ShareDeferredVideoAttachmentRequest request,
) {
  return <String, dynamic>{
    'captureResult': _shareCaptureResultToJson(request.captureResult),
    'candidate': _shareVideoCandidateToJson(request.candidate),
  };
}

ShareDeferredVideoAttachmentRequest? _shareDeferredVideoAttachmentFromJson(
  Object? value,
) {
  final map = _stringMap(value);
  if (map == null) return null;
  final result = _shareCaptureResultFromJson(map['captureResult']);
  final candidate = _shareVideoCandidateFromJson(map['candidate']);
  if (result == null || candidate == null) return null;
  return ShareDeferredVideoAttachmentRequest(
    captureResult: result,
    candidate: candidate,
  );
}

Map<String, dynamic> _shareCaptureResultToJson(ShareCaptureResult result) {
  return <String, dynamic>{
    'status': result.status.name,
    'finalUrl': result.finalUrl.toString(),
    if (result.pageTitle != null) 'pageTitle': result.pageTitle,
    if (result.articleTitle != null) 'articleTitle': result.articleTitle,
    if (result.siteName != null) 'siteName': result.siteName,
    if (result.sourceAvatarUrl != null)
      'sourceAvatarUrl': result.sourceAvatarUrl,
    if (result.byline != null) 'byline': result.byline,
    if (result.authorAvatarUrl != null)
      'authorAvatarUrl': result.authorAvatarUrl,
    if (result.excerpt != null) 'excerpt': result.excerpt,
    if (result.contentHtml != null) 'contentHtml': result.contentHtml,
    if (result.textContent != null) 'textContent': result.textContent,
    if (result.leadImageUrl != null) 'leadImageUrl': result.leadImageUrl,
    'length': result.length,
    'readabilitySucceeded': result.readabilitySucceeded,
    'pageKind': result.pageKind.name,
    'videoCandidates': result.videoCandidates
        .map(_shareVideoCandidateToJson)
        .toList(growable: false),
    'unsupportedVideoCandidates': result.unsupportedVideoCandidates
        .map(_shareVideoCandidateToJson)
        .toList(growable: false),
    'imageAttachmentUrls': result.imageAttachmentUrls,
    if (result.siteParserTag != null) 'siteParserTag': result.siteParserTag,
    if (result.pageUserAgent != null) 'pageUserAgent': result.pageUserAgent,
    if (result.failure != null) 'failure': result.failure!.name,
    if (result.failureMessage != null) 'failureMessage': result.failureMessage,
  };
}

ShareCaptureResult? _shareCaptureResultFromJson(Object? value) {
  final map = _stringMap(value);
  if (map == null) return null;
  final finalUrl = Uri.tryParse(map['finalUrl'] as String? ?? '');
  if (finalUrl == null) return null;
  return ShareCaptureResult(
    status: _enumByName(
      ShareCaptureStatus.values,
      map['status'] as String?,
      ShareCaptureStatus.failure,
    ),
    finalUrl: finalUrl,
    pageTitle: map['pageTitle'] as String?,
    articleTitle: map['articleTitle'] as String?,
    siteName: map['siteName'] as String?,
    sourceAvatarUrl: map['sourceAvatarUrl'] as String?,
    byline: map['byline'] as String?,
    authorAvatarUrl: map['authorAvatarUrl'] as String?,
    excerpt: map['excerpt'] as String?,
    contentHtml: map['contentHtml'] as String?,
    textContent: map['textContent'] as String?,
    leadImageUrl: map['leadImageUrl'] as String?,
    length: _intValue(map['length']),
    readabilitySucceeded: map['readabilitySucceeded'] == true,
    pageKind: _enumByName(
      SharePageKind.values,
      map['pageKind'] as String?,
      SharePageKind.unknown,
    ),
    videoCandidates: _mapList(
      map['videoCandidates'],
      _shareVideoCandidateFromJson,
    ),
    unsupportedVideoCandidates: _mapList(
      map['unsupportedVideoCandidates'],
      _shareVideoCandidateFromJson,
    ),
    imageAttachmentUrls: _stringList(map['imageAttachmentUrls']),
    siteParserTag: map['siteParserTag'] as String?,
    pageUserAgent: map['pageUserAgent'] as String?,
    failure: _nullableEnumByName(
      ShareCaptureFailure.values,
      map['failure'] as String?,
    ),
    failureMessage: map['failureMessage'] as String?,
  );
}

Map<String, dynamic> _shareVideoCandidateToJson(ShareVideoCandidate candidate) {
  return <String, dynamic>{
    'id': candidate.id,
    'url': candidate.url,
    if (candidate.title != null) 'title': candidate.title,
    if (candidate.mimeType != null) 'mimeType': candidate.mimeType,
    if (candidate.thumbnailUrl != null) 'thumbnailUrl': candidate.thumbnailUrl,
    'source': candidate.source.name,
    if (candidate.referer != null) 'referer': candidate.referer,
    if (candidate.headers != null) 'headers': candidate.headers,
    if (candidate.cookieUrl != null) 'cookieUrl': candidate.cookieUrl,
    'isDirectDownloadable': candidate.isDirectDownloadable,
    'priority': candidate.priority,
    if (candidate.parserTag != null) 'parserTag': candidate.parserTag,
    if (candidate.reason != null) 'reason': candidate.reason,
  };
}

ShareVideoCandidate? _shareVideoCandidateFromJson(Object? value) {
  final map = _stringMap(value);
  if (map == null) return null;
  final id = map['id'];
  final url = map['url'];
  if (id is! String || url is! String) return null;
  return ShareVideoCandidate(
    id: id,
    url: url,
    title: map['title'] as String?,
    mimeType: map['mimeType'] as String?,
    thumbnailUrl: map['thumbnailUrl'] as String?,
    source: _enumByName(
      ShareVideoSource.values,
      map['source'] as String?,
      ShareVideoSource.parser,
    ),
    referer: map['referer'] as String?,
    headers: _stringStringMap(map['headers']),
    cookieUrl: map['cookieUrl'] as String?,
    isDirectDownloadable: map['isDirectDownloadable'] == true,
    priority: _intValue(map['priority']),
    parserTag: map['parserTag'] as String?,
    reason: map['reason'] as String?,
  );
}

Map<String, dynamic>? _stringMap(Object? value) {
  if (value is! Map) return null;
  return Map<Object?, Object?>.from(
    value,
  ).map<String, dynamic>((key, item) => MapEntry(key.toString(), item));
}

Map<String, String>? _stringStringMap(Object? value) {
  if (value is! Map) return null;
  return Map<Object?, Object?>.from(value).map<String, String>(
    (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}

List<T> _mapList<T>(Object? value, T? Function(Object? value) decode) {
  if (value is! List) return <T>[];
  final items = <T>[];
  for (final item in value) {
    final decoded = decode(item);
    if (decoded != null) items.add(decoded);
  }
  return items;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  return _nullableEnumByName(values, name) ?? fallback;
}

T? _nullableEnumByName<T extends Enum>(List<T> values, String? name) {
  final normalized = (name ?? '').trim();
  if (normalized.isEmpty) return null;
  for (final value in values) {
    if (value.name == normalized) return value;
  }
  return null;
}
