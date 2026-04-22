import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import '../../application/sync/sync_request.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/memo_clip_card_metadata.dart';
import '../../data/models/local_memo.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/memo_mutation_service.dart';
import '../../state/memos/note_input_providers.dart';
import 'share_capture_engine.dart';
import 'share_capture_formatter.dart';
import 'share_capture_inappwebview_engine.dart';
import 'share_clip_models.dart';
import 'share_handler.dart';
import 'share_inline_image_content.dart';
import 'share_inline_image_download_service.dart';
import 'share_quick_clip_models.dart';

const int _quickClipResolveMemoScanLimit = 40;

String buildQuickClipHiddenMarker(String memoUid) {
  final normalizedUid = memoUid.trim();
  if (normalizedUid.isEmpty) return '';
  return '<!-- memoflow_quick_clip:$normalizedUid -->';
}

Map<String, dynamic>? findQuickClipPlaceholderMemoRow(
  List<Map<String, dynamic>> rows, {
  required String memoUid,
  required String placeholderMarker,
  required String placeholderLookupContent,
}) {
  final normalizedUid = memoUid.trim();
  final normalizedMarker = placeholderMarker.trim();
  final normalizedLookupContent = placeholderLookupContent.trim();

  for (final row in rows) {
    final rowUid = (row['uid'] as String? ?? '').trim();
    if (normalizedUid.isNotEmpty && rowUid == normalizedUid) {
      return row;
    }
  }

  for (final row in rows) {
    final rowContent = (row['content'] as String? ?? '').trim();
    if (normalizedMarker.isNotEmpty && rowContent.contains(normalizedMarker)) {
      return row;
    }
    if (normalizedLookupContent.isNotEmpty &&
        _stripQuickClipHiddenMarker(rowContent) == normalizedLookupContent) {
      return row;
    }
  }

  return null;
}

String _stripQuickClipHiddenMarker(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .replaceAll(RegExp(r'<!--\s*memoflow_quick_clip:[^>]+-->'), '')
      .trim();
}

class ShareQuickClipService {
  static const Duration _captureTimeout = Duration(seconds: 40);

  ShareQuickClipService({
    required WidgetRef ref,
    required AppBootstrapAdapter bootstrapAdapter,
    ShareCaptureEngine? engine,
    ShareInlineImageDownloadService? inlineImageDownloadService,
  }) : _ref = ref,
       _bootstrapAdapter = bootstrapAdapter,
       _engine = engine ?? ShareCaptureInAppWebViewEngine(),
       _inlineImageDownloadService =
           inlineImageDownloadService ?? ShareInlineImageDownloadService();

  final WidgetRef _ref;
  final AppBootstrapAdapter _bootstrapAdapter;
  final ShareCaptureEngine _engine;
  final ShareInlineImageDownloadService _inlineImageDownloadService;

  Future<void> start({
    required SharePayload payload,
    required ShareQuickClipSubmission submission,
    required Locale locale,
  }) async {
    final request = buildShareCaptureRequest(payload);
    if (request == null) return;
    LogManager.instance.info(
      'ShareQuickClip: start',
      context: {
        'url': request.url.toString(),
        'host': request.url.host,
        'textOnly': submission.textOnly,
        'titleAndLinkOnly': submission.titleAndLinkOnly,
        'tagCount': submission.tags.length,
      },
    );

    final uid = generateUid();
    final now = DateTime.now();
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final visibility = _resolveVisibility();
    if (submission.titleAndLinkOnly) {
      final content = buildLinkOnlyMemoText(payload, tags: submission.tags);
      await _ref
          .read(memoMutationServiceProvider)
          .createInlineComposeMemo(
            uid: uid,
            content: content,
            visibility: visibility,
            nowSec: nowSec,
            tags: extractTags(content),
            attachments: const <Map<String, dynamic>>[],
            location: null,
            relations: const <Map<String, dynamic>>[],
            pendingAttachments: const <MemoComposerPendingAttachment>[],
          );
      LogManager.instance.info(
        'ShareQuickClip: title_link_saved',
        context: {
          'memoUid': uid,
          'host': request.url.host,
          'contentLength': content.length,
        },
      );
      LogManager.instance.info(
        'ShareQuickClip: local_save_committed',
        context: {
          'memoUid': uid,
          'host': request.url.host,
          'mode': 'title_and_link_only',
          'contentLength': content.length,
        },
      );
      unawaited(
        _requestMemoSyncBestEffort(
          memoUid: uid,
          host: request.url.host,
          trigger: 'title_and_link_only',
        ),
      );
      return;
    }

    final placeholderMarker = buildQuickClipHiddenMarker(uid);
    final placeholderLookupContent = _buildPlaceholderContent(
      request: request,
      tags: submission.tags,
      locale: locale,
    );
    final placeholderContent = _appendHiddenMarker(
      placeholderLookupContent,
      placeholderMarker,
    );

    await _ref
        .read(memoMutationServiceProvider)
        .createInlineComposeMemo(
          uid: uid,
          content: placeholderContent,
          visibility: visibility,
          nowSec: nowSec,
          tags: extractTags(placeholderContent),
          attachments: const <Map<String, dynamic>>[],
          location: null,
          relations: const <Map<String, dynamic>>[],
          pendingAttachments: const <MemoComposerPendingAttachment>[],
        );
    LogManager.instance.info(
      'ShareQuickClip: placeholder_created',
      context: {
        'memoUid': uid,
        'host': request.url.host,
        'contentLength': placeholderContent.length,
      },
    );
    LogManager.instance.info(
      'ShareQuickClip: local_save_committed',
      context: {
        'memoUid': uid,
        'host': request.url.host,
        'mode': 'placeholder',
        'contentLength': placeholderContent.length,
      },
    );

    unawaited(
      _captureAndUpdate(
        memoUid: uid,
        payload: payload,
        request: request,
        submission: submission,
        locale: locale,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      ),
    );
  }

  String _resolveVisibility() {
    final settings = _bootstrapAdapter.readUserGeneralSetting(_ref);
    final value = (settings?.memoVisibility ?? '').trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  Future<void> _captureAndUpdate({
    required String memoUid,
    required SharePayload payload,
    required ShareCaptureRequest request,
    required ShareQuickClipSubmission submission,
    required Locale locale,
    required String placeholderMarker,
    required String placeholderLookupContent,
  }) async {
    try {
      LogManager.instance.info(
        'ShareQuickClip: capture_start',
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
      final result = await _engine
          .capture(
            request,
            onStageChanged: (stage) {
              LogManager.instance.debug(
                'ShareQuickClip: capture_stage',
                context: {
                  'memoUid': memoUid,
                  'host': request.url.host,
                  'stage': stage.name,
                },
              );
            },
          )
          .timeout(_captureTimeout);
      LogManager.instance.info(
        'ShareQuickClip: capture_result',
        context: {
          'memoUid': memoUid,
          'host': request.url.host,
          'success': result.isSuccess,
          'failure': result.failure?.name,
          'parserTag': result.siteParserTag,
          'pageKind': result.pageKind.name,
          'textLength': result.textContent?.length ?? 0,
          'htmlLength': result.contentHtml?.length ?? 0,
          ..._buildInlineImageCaptureDiagnostics(result),
        },
      );
      final clipMetadataDraft = result.isSuccess
          ? buildShareClipMetadataDraft(result: result)
          : null;
      var preparedInlineImageHtmlOverride = result.contentHtml;
      var preparedInlineImageSeeds = const <ShareAttachmentSeed>[];
      if (result.isSuccess && !submission.textOnly) {
        try {
          final prepared = await _inlineImageDownloadService.prepare(result);
          preparedInlineImageHtmlOverride = prepared.contentHtml;
          preparedInlineImageSeeds = prepared.attachmentSeeds;
          LogManager.instance.info(
            'ShareQuickClip: inline_images_prepared',
            context: {
              'memoUid': memoUid,
              'host': request.url.host,
              'preparedCount': preparedInlineImageSeeds.length,
            },
          );
        } catch (error, stackTrace) {
          LogManager.instance.warn(
            'ShareQuickClip: inline_images_prepare_failed',
            error: error,
            stackTrace: stackTrace,
            context: {'memoUid': memoUid, 'host': request.url.host},
          );
        }
      }
      final nextContent = result.isSuccess
          ? _buildCapturedContent(
              payload: payload,
              result: result,
              submission: submission,
              contentHtmlOverride: preparedInlineImageHtmlOverride,
              preparedInlineImageSeeds: preparedInlineImageSeeds,
            )
          : _buildFailureContent(
              request: request,
              tags: submission.tags,
              locale: locale,
            );
      final resolvedMemoUid = await _updateMemoContent(
        memoUid,
        nextContent,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      );
      if (resolvedMemoUid == null) {
        LogManager.instance.warn(
          'ShareQuickClip: memo_update_skipped',
          context: {
            'requestedMemoUid': memoUid,
            'host': request.url.host,
            'contentLength': nextContent.length,
            'success': result.isSuccess,
          },
        );
        return;
      }
      if (clipMetadataDraft != null) {
        await _upsertClipMetadata(
          memoUid: resolvedMemoUid,
          metadata: clipMetadataDraft.toMemoClipCardMetadata(
            memoUid: resolvedMemoUid,
            now: DateTime.now(),
          ),
        );
      }
      var appendedInlineImages = 0;
      if (result.isSuccess) {
        appendedInlineImages = preparedInlineImageSeeds.isNotEmpty
            ? await _appendPreparedInlineImages(
                memoUid: resolvedMemoUid,
                attachmentSeeds: preparedInlineImageSeeds,
              )
            : await _appendDeferredInlineImages(
                memoUid: resolvedMemoUid,
                result: result,
              );
      }
      LogManager.instance.info(
        'ShareQuickClip: memo_updated',
        context: {
          'memoUid': resolvedMemoUid,
          'requestedMemoUid': memoUid,
          'host': request.url.host,
          'contentLength': nextContent.length,
          'success': result.isSuccess,
          'appendedInlineImages': appendedInlineImages,
        },
      );
      unawaited(
        _requestMemoSyncBestEffort(
          memoUid: resolvedMemoUid,
          requestedMemoUid: memoUid,
          host: request.url.host,
          trigger: 'capture_update',
          extraContext: {'appendedInlineImages': appendedInlineImages},
        ),
      );
    } on TimeoutException catch (error, stackTrace) {
      LogManager.instance.warn(
        'ShareQuickClip: capture_timeout',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
      await _replaceWithFailureContent(
        memoUid: memoUid,
        request: request,
        tags: submission.tags,
        locale: locale,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      );
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'ShareQuickClip: capture_failed',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
      await _replaceWithFailureContent(
        memoUid: memoUid,
        request: request,
        tags: submission.tags,
        locale: locale,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      );
    }
  }

  Future<void> _requestMemoSyncBestEffort({
    required String memoUid,
    String? requestedMemoUid,
    String? host,
    required String trigger,
    Map<String, Object?> extraContext = const <String, Object?>{},
  }) async {
    final context = <String, Object?>{
      'memoUid': memoUid,
      'trigger': trigger,
      if (requestedMemoUid != null && requestedMemoUid.isNotEmpty)
        'requestedMemoUid': requestedMemoUid,
      if (host != null && host.isNotEmpty) 'host': host,
      ...extraContext,
    };
    LogManager.instance.info(
      'ShareQuickClip: background_sync_requested',
      context: context,
    );
    try {
      await _bootstrapAdapter.requestSync(
        _ref,
        const SyncRequest(
          kind: SyncRequestKind.memos,
          reason: SyncRequestReason.manual,
        ),
      );
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'ShareQuickClip: background_sync_failed',
        error: error,
        stackTrace: stackTrace,
        context: context,
      );
    }
  }

  Future<String?> _updateMemoContent(
    String memoUid,
    String content, {
    required String placeholderMarker,
    required String placeholderLookupContent,
  }) async {
    final memo = await _resolveMemoForUpdate(
      memoUid,
      placeholderMarker: placeholderMarker,
      placeholderLookupContent: placeholderLookupContent,
    );
    if (memo == null) {
      LogManager.instance.warn(
        'ShareQuickClip: memo_missing_for_update',
        context: {
          'memoUid': memoUid,
          'contentLength': content.length,
          'placeholderLookupContentLength': placeholderLookupContent.length,
        },
      );
      return null;
    }
    await _ref
        .read(memoMutationServiceProvider)
        .updateMemoContent(memo, content);
    return memo.uid;
  }

  Future<int> _appendDeferredInlineImages({
    required String memoUid,
    required ShareCaptureResult result,
  }) async {
    final requests = await _inlineImageDownloadService
        .discoverDeferredInlineImageAttachments(result);
    if (requests.isEmpty) {
      return 0;
    }

    LogManager.instance.info(
      'ShareQuickClip: inline_images_discovered',
      context: {
        'memoUid': memoUid,
        'count': requests.length,
        'sampleUrls': requests
            .take(3)
            .map((item) => item.sourceUrl)
            .toList(growable: false),
      },
    );

    var appended = 0;
    for (final request in requests) {
      try {
        LogManager.instance.debug(
          'ShareQuickClip: inline_image_download_start',
          context: {'memoUid': memoUid, 'sourceUrl': request.sourceUrl},
        );
        final seed = await _inlineImageDownloadService
            .downloadDeferredInlineImageAttachment(request);
        if (seed == null) {
          LogManager.instance.warn(
            'ShareQuickClip: inline_image_download_skipped',
            context: {'memoUid': memoUid, 'sourceUrl': request.sourceUrl},
          );
          continue;
        }
        await _ref
            .read(noteInputControllerProvider)
            .appendDeferredThirdPartyShareInlineImage(
              memoUid: memoUid,
              sourceUrl: request.sourceUrl,
              attachment: NoteInputPendingAttachment(
                uid: seed.uid,
                filePath: seed.filePath,
                filename: seed.filename,
                mimeType: seed.mimeType,
                size: seed.size,
                shareInlineImage: seed.shareInlineImage,
                fromThirdPartyShare: seed.fromThirdPartyShare,
                sourceUrl: seed.sourceUrl,
              ),
            );
        appended++;
        LogManager.instance.debug(
          'ShareQuickClip: inline_image_appended',
          context: {
            'memoUid': memoUid,
            'sourceUrl': request.sourceUrl,
            'attachmentUid': seed.uid,
            'filename': seed.filename,
            'size': seed.size,
          },
        );
      } catch (error, stackTrace) {
        LogManager.instance.warn(
          'ShareQuickClip: inline_image_append_failed',
          error: error,
          stackTrace: stackTrace,
          context: {'memoUid': memoUid, 'sourceUrl': request.sourceUrl},
        );
      }
    }

    return appended;
  }

  Map<String, Object?> _buildInlineImageCaptureDiagnostics(
    ShareCaptureResult result,
  ) {
    final rawHtml = normalizeShareText(result.contentHtml);
    if (rawHtml == null) {
      return const <String, Object?>{
        'htmlImgSrcCount': 0,
        'htmlImgDataSrcCount': 0,
      };
    }
    final fragment = html_parser.parseFragment(rawHtml);
    final imgSrcNodes = fragment.querySelectorAll('img[src]');
    final imgDataSrcNodes = fragment.querySelectorAll('img[data-src]');
    return <String, Object?>{
      'htmlImgSrcCount': imgSrcNodes.length,
      'htmlImgDataSrcCount': imgDataSrcNodes.length,
      'htmlImgSample': imgSrcNodes
          .take(3)
          .map((node) => node.attributes['src'] ?? '')
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
    };
  }

  Future<LocalMemo?> _resolveMemoForUpdate(
    String memoUid, {
    required String placeholderMarker,
    required String placeholderLookupContent,
  }) async {
    final db = _bootstrapAdapter.readDatabase(_ref);
    final directRow = await db.getMemoByUid(memoUid);
    if (directRow != null) {
      return LocalMemo.fromDb(directRow);
    }

    final recentRows = await db.listMemos(
      limit: _quickClipResolveMemoScanLimit,
    );
    final resolvedRow = findQuickClipPlaceholderMemoRow(
      recentRows,
      memoUid: memoUid,
      placeholderMarker: placeholderMarker,
      placeholderLookupContent: placeholderLookupContent,
    );
    if (resolvedRow == null) {
      return null;
    }

    final resolvedMemo = LocalMemo.fromDb(resolvedRow);
    if (resolvedMemo.uid.trim() != memoUid.trim()) {
      LogManager.instance.info(
        'ShareQuickClip: memo_resolved_for_update',
        context: {
          'requestedMemoUid': memoUid,
          'resolvedMemoUid': resolvedMemo.uid,
        },
      );
    }
    return resolvedMemo;
  }

  Future<void> _replaceWithFailureContent({
    required String memoUid,
    required ShareCaptureRequest request,
    required List<String> tags,
    required Locale locale,
    required String placeholderMarker,
    required String placeholderLookupContent,
  }) async {
    final content = _buildFailureContent(
      request: request,
      tags: tags,
      locale: locale,
    );
    try {
      final resolvedMemoUid = await _updateMemoContent(
        memoUid,
        content,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      );
      if (resolvedMemoUid == null) {
        LogManager.instance.warn(
          'ShareQuickClip: fallback_skipped',
          context: {'requestedMemoUid': memoUid, 'host': request.url.host},
        );
        return;
      }
      unawaited(
        _requestMemoSyncBestEffort(
          memoUid: resolvedMemoUid,
          requestedMemoUid: memoUid,
          host: request.url.host,
          trigger: 'fallback_content',
        ),
      );
      LogManager.instance.info(
        'ShareQuickClip: fallback_saved',
        context: {
          'memoUid': resolvedMemoUid,
          'requestedMemoUid': memoUid,
          'host': request.url.host,
          'contentLength': content.length,
        },
      );
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'ShareQuickClip: fallback_save_failed',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
    }
  }

  String _buildPlaceholderContent({
    required ShareCaptureRequest request,
    required List<String> tags,
    required Locale locale,
  }) {
    final buffer = StringBuffer()
      ..writeln('# ${_placeholderTitle(locale)}')
      ..writeln()
      ..writeln('${_linkLabel(locale)}: ${request.url}')
      ..writeln()
      ..writeln(_processingLabel(locale));
    if (tags.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(tags.join(' '));
    }
    return buffer.toString().trimRight();
  }

  String _buildFailureContent({
    required ShareCaptureRequest request,
    required List<String> tags,
    required Locale locale,
  }) {
    final buffer = StringBuffer()
      ..writeln('# ${_failureTitle(locale)}')
      ..writeln()
      ..writeln('${_linkLabel(locale)}: ${request.url}')
      ..writeln()
      ..writeln(_failureBody(locale));
    if (tags.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(tags.join(' '));
    }
    return buffer.toString().trimRight();
  }

  String _buildCapturedContent({
    required SharePayload payload,
    required ShareCaptureResult result,
    required ShareQuickClipSubmission submission,
    String? contentHtmlOverride,
    List<ShareAttachmentSeed> preparedInlineImageSeeds = const [],
  }) {
    final base = buildShareCaptureMemoText(
      result: result,
      payload: payload,
      contentHtmlOverride: submission.textOnly ? '' : contentHtmlOverride,
      allowedLocalImageUrls: preparedInlineImageSeeds
          .where((attachment) => attachment.shareInlineImage)
          .map((attachment) => shareInlineLocalUrlFromPath(attachment.filePath))
          .where((url) => url.isNotEmpty)
          .toSet(),
    );
    if (submission.tags.isEmpty) return base;
    return _appendTagsToCapturedContent(base, submission.tags);
  }

  Future<int> _appendPreparedInlineImages({
    required String memoUid,
    required List<ShareAttachmentSeed> attachmentSeeds,
  }) async {
    if (attachmentSeeds.isEmpty) {
      return 0;
    }

    var appended = 0;
    for (final seed in attachmentSeeds) {
      final sourceUrl = normalizeShareText(seed.sourceUrl);
      if (sourceUrl == null) {
        continue;
      }
      try {
        await _ref
            .read(noteInputControllerProvider)
            .appendDeferredThirdPartyShareInlineImage(
              memoUid: memoUid,
              sourceUrl: sourceUrl,
              attachment: NoteInputPendingAttachment(
                uid: seed.uid,
                filePath: seed.filePath,
                filename: seed.filename,
                mimeType: seed.mimeType,
                size: seed.size,
                shareInlineImage: seed.shareInlineImage,
                fromThirdPartyShare: seed.fromThirdPartyShare,
                sourceUrl: seed.sourceUrl,
              ),
            );
        appended++;
      } catch (error, stackTrace) {
        LogManager.instance.warn(
          'ShareQuickClip: prepared_inline_image_append_failed',
          error: error,
          stackTrace: stackTrace,
          context: {'memoUid': memoUid, 'sourceUrl': sourceUrl},
        );
      }
    }
    return appended;
  }

  String _appendHiddenMarker(String content, String marker) {
    final normalizedMarker = marker.trim();
    if (normalizedMarker.isEmpty) return content.trimRight();
    final normalizedContent = content.trimRight();
    if (normalizedContent.isEmpty) return normalizedMarker;
    return '$normalizedContent\n\n$normalizedMarker';
  }

  String _appendTagsToCapturedContent(String content, List<String> tags) {
    final normalizedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    if (normalizedTags.isEmpty) return content.trimRight();
    final normalizedContent = content.trimRight();
    const marker = '<!-- memoflow-third-party-share -->';
    if (normalizedContent.endsWith(marker)) {
      final body = normalizedContent
          .substring(0, normalizedContent.length - marker.length)
          .trimRight();
      return '$body\n\n${normalizedTags.join(' ')}\n\n$marker';
    }
    return '$normalizedContent\n\n${normalizedTags.join(' ')}';
  }

  Future<void> _upsertClipMetadata({
    required String memoUid,
    required MemoClipCardMetadata metadata,
  }) async {
    await _ref
        .read(memoMutationServiceProvider)
        .upsertMemoClipCardMetadata(
          metadata.copyWith(memoUid: memoUid, updatedTime: DateTime.now()),
        );
  }

  String _placeholderTitle(Locale locale) {
    return _isZh(locale) ? '\u526a\u85cf\u4e2d\u2026' : 'Clipping...';
  }

  String _processingLabel(Locale locale) {
    return _isZh(locale)
        ? '\u6b63\u5728\u63d0\u53d6\u94fe\u63a5\u5185\u5bb9\uff0c\u8bf7\u7a0d\u5019\u3002'
        : 'Extracting content...';
  }

  String _failureTitle(Locale locale) {
    return _isZh(locale) ? '\u5df2\u4fdd\u5b58\u94fe\u63a5' : 'Link saved';
  }

  String _failureBody(Locale locale) {
    return _isZh(locale)
        ? '\u5185\u5bb9\u89e3\u6790\u5931\u8d25\uff0c\u5f53\u524d\u5df2\u5148\u4fdd\u5b58\u539f\u59cb\u94fe\u63a5\u3002'
        : 'Content parsing failed, so the original link was saved.';
  }

  String _linkLabel(Locale locale) {
    return _isZh(locale) ? '\u539f\u59cb\u94fe\u63a5' : 'Original link';
  }

  bool _isZh(Locale locale) {
    return locale.languageCode.toLowerCase().startsWith('zh');
  }
}
