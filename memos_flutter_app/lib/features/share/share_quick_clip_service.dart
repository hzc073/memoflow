import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import '../../application/sync/sync_request.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/api/memos_api.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/memo_clip_card_metadata.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/quick_clip_recovery_job.dart';
import '../../state/memos/attachment_upload_size_limit_provider.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/memo_mutation_service.dart';
import '../../state/memos/quick_clip_recovery_mutation_service.dart';
import '../../state/memos/third_party_share_attachment_appender.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import 'share_capture_engine.dart';
import 'share_capture_formatter.dart';
import 'share_capture_inappwebview_engine.dart';
import 'share_clip_models.dart';
import 'share_handler.dart';
import 'share_inline_image_content.dart';
import 'share_inline_image_download_service.dart';
import 'share_quick_clip_media_classifier.dart';
import 'share_quick_clip_models.dart';
import 'share_video_attachment_preparer.dart';

const int _quickClipResolveMemoScanLimit = 40;

String buildQuickClipHiddenMarker(String memoUid) {
  final normalizedUid = memoUid.trim();
  if (normalizedUid.isEmpty) return '';
  return '<!-- memoflow_quick_clip:$normalizedUid -->';
}

String stripQuickClipHiddenMarker(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .replaceAll(RegExp(r'<!--\s*memoflow_quick_clip:[^>]+-->'), '')
      .trim();
}

bool isQuickClipPlaceholderContentMatch(
  String content, {
  required String placeholderMarker,
  required String placeholderLookupContent,
}) {
  final rowContent = content.trim();
  final normalizedMarker = placeholderMarker.trim();
  final normalizedLookupContent = placeholderLookupContent.trim();
  if (normalizedMarker.isNotEmpty && rowContent.contains(normalizedMarker)) {
    return true;
  }
  return normalizedLookupContent.isNotEmpty &&
      stripQuickClipHiddenMarker(rowContent) == normalizedLookupContent;
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
    final rowContent = (row['content'] as String? ?? '').trim();
    if (normalizedUid.isNotEmpty &&
        rowUid == normalizedUid &&
        isQuickClipPlaceholderContentMatch(
          rowContent,
          placeholderMarker: normalizedMarker,
          placeholderLookupContent: normalizedLookupContent,
        )) {
      return row;
    }
  }

  for (final row in rows) {
    final rowContent = (row['content'] as String? ?? '').trim();
    if (isQuickClipPlaceholderContentMatch(
      rowContent,
      placeholderMarker: normalizedMarker,
      placeholderLookupContent: normalizedLookupContent,
    )) {
      return row;
    }
  }

  return null;
}

String buildQuickClipPlaceholderContent({
  required ShareCaptureRequest request,
  required List<String> tags,
  required Locale locale,
}) {
  final buffer = StringBuffer()
    ..writeln('# ${_quickClipPlaceholderTitle(locale)}')
    ..writeln()
    ..writeln('${_quickClipLinkLabel(locale)}: ${request.url}')
    ..writeln()
    ..writeln(_quickClipProcessingLabel(locale));
  final tagLine = formatMemoTagZoneLine(tags);
  if (tagLine.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(tagLine);
  }
  return buffer.toString().trimRight();
}

String buildQuickClipFailureContent({
  required ShareCaptureRequest request,
  required List<String> tags,
  required Locale locale,
}) {
  final buffer = StringBuffer()
    ..writeln('# ${_quickClipFailureTitle(locale)}')
    ..writeln()
    ..writeln('${_quickClipLinkLabel(locale)}: ${request.url}')
    ..writeln()
    ..writeln(_quickClipFailureBody(locale));
  final tagLine = formatMemoTagZoneLine(tags);
  if (tagLine.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(tagLine);
  }
  return buffer.toString().trimRight();
}

String appendQuickClipHiddenMarker(String content, String marker) {
  final normalizedMarker = marker.trim();
  if (normalizedMarker.isEmpty) return content.trimRight();
  final normalizedContent = content.trimRight();
  if (normalizedContent.isEmpty) return normalizedMarker;
  return '$normalizedContent\n\n$normalizedMarker';
}

String appendTagsToQuickClipCapturedContent(String content, List<String> tags) {
  final tagLine = formatMemoTagZoneLine(tags);
  if (tagLine.isEmpty) return content.trimRight();
  final normalizedContent = content.trimRight();
  const marker = '<!-- memoflow-third-party-share -->';
  if (normalizedContent.endsWith(marker)) {
    final body = normalizedContent
        .substring(0, normalizedContent.length - marker.length)
        .trimRight();
    return '$body\n\n$tagLine\n\n$marker';
  }
  return '$normalizedContent\n\n$tagLine';
}

String _quickClipPlaceholderTitle(Locale locale) {
  return _quickClipIsZh(locale) ? '\u526a\u85cf\u4e2d\u2026' : 'Clipping...';
}

String _quickClipProcessingLabel(Locale locale) {
  return _quickClipIsZh(locale)
      ? '\u6b63\u5728\u63d0\u53d6\u94fe\u63a5\u5185\u5bb9\uff0c\u8bf7\u7a0d\u5019\u3002'
      : 'Extracting content...';
}

String _quickClipFailureTitle(Locale locale) {
  return _quickClipIsZh(locale)
      ? '\u5df2\u4fdd\u5b58\u94fe\u63a5'
      : 'Link saved';
}

String _quickClipFailureBody(Locale locale) {
  return _quickClipIsZh(locale)
      ? '\u5185\u5bb9\u89e3\u6790\u5931\u8d25\uff0c\u5f53\u524d\u5df2\u5148\u4fdd\u5b58\u539f\u59cb\u94fe\u63a5\u3002'
      : 'Content parsing failed, so the original link was saved.';
}

String _quickClipLinkLabel(Locale locale) {
  return _quickClipIsZh(locale) ? '\u539f\u59cb\u94fe\u63a5' : 'Original link';
}

bool _quickClipIsZh(Locale locale) {
  return locale.languageCode.toLowerCase().startsWith('zh');
}

class ShareQuickClipService {
  static const Duration _captureTimeout = Duration(seconds: 40);

  ShareQuickClipService({
    required WidgetRef ref,
    required AppBootstrapAdapter bootstrapAdapter,
    ShareCaptureEngine? engine,
    ShareInlineImageDownloadService? inlineImageDownloadService,
    ShareVideoAttachmentPreparer? videoAttachmentPreparer,
  }) : _ref = ref,
       _bootstrapAdapter = bootstrapAdapter,
       _engine = engine ?? ShareCaptureInAppWebViewEngine(),
       _inlineImageDownloadService =
           inlineImageDownloadService ?? ShareInlineImageDownloadService(),
       _videoAttachmentPreparer =
           videoAttachmentPreparer ?? ShareVideoAttachmentPreparer();

  final WidgetRef _ref;
  final AppBootstrapAdapter _bootstrapAdapter;
  final ShareCaptureEngine _engine;
  final ShareInlineImageDownloadService _inlineImageDownloadService;
  final ShareVideoAttachmentPreparer _videoAttachmentPreparer;

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
    final tagRecognitionPolicy = _ref
        .read(currentWorkspacePreferencesProvider)
        .tagRecognitionPolicy;
    if (submission.titleAndLinkOnly) {
      final content = buildLinkOnlyMemoText(payload, tags: submission.tags);
      await _ref
          .read(memoMutationServiceProvider)
          .createInlineComposeMemo(
            uid: uid,
            content: content,
            visibility: visibility,
            nowSec: nowSec,
            tags: extractTags(content, policy: tagRecognitionPolicy),
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
          tags: extractTags(placeholderContent, policy: tagRecognitionPolicy),
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

    await _persistRecoveryJob(
      memoUid: uid,
      payload: payload,
      request: request,
      submission: submission,
      locale: locale,
      placeholderMarker: placeholderMarker,
      placeholderLookupContent: placeholderLookupContent,
    );

    final reserved = ShareQuickClipRecoveryService._reserveMemoUid(uid);
    if (!reserved) {
      LogManager.instance.warn(
        'ShareQuickClip: capture_deduped',
        context: {'memoUid': uid, 'host': request.url.host},
      );
      return;
    }
    unawaited(
      _captureAndUpdate(
        memoUid: uid,
        payload: payload,
        request: request,
        submission: submission,
        locale: locale,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
        reservationHeld: true,
      ),
    );
  }

  Future<void> _persistRecoveryJob({
    required String memoUid,
    required SharePayload payload,
    required ShareCaptureRequest request,
    required ShareQuickClipSubmission submission,
    required Locale locale,
    required String placeholderMarker,
    required String placeholderLookupContent,
  }) async {
    final job = QuickClipRecoveryJob.pending(
      memoUid: memoUid,
      sourceUrl: request.url.toString(),
      payloadType: payload.type.name,
      payloadText: payload.text ?? '',
      payloadTitle: payload.title,
      payloadPaths: payload.paths,
      textOnly: submission.textOnly,
      titleAndLinkOnly: submission.titleAndLinkOnly,
      tags: submission.tags,
      localeLanguageCode: locale.languageCode,
      placeholderMarker: placeholderMarker,
      placeholderLookupContent: placeholderLookupContent,
    );
    try {
      await _ref.read(quickClipRecoveryMutationServiceProvider).upsertJob(job);
      LogManager.instance.info(
        'ShareQuickClip: recovery_job_created',
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'ShareQuickClip: recovery_job_create_failed',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
    }
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
    bool reservationHeld = false,
    String? recoveryTrigger,
  }) async {
    final reservedHere = reservationHeld
        ? false
        : ShareQuickClipRecoveryService._reserveMemoUid(memoUid);
    if (!reservationHeld && !reservedHere) {
      LogManager.instance.info(
        'ShareQuickClip: capture_skip_in_flight',
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
      return;
    }
    try {
      LogManager.instance.info(
        'ShareQuickClip: capture_start',
        context: {
          'memoUid': memoUid,
          'host': request.url.host,
          if (recoveryTrigger != null) 'recoveryTrigger': recoveryTrigger,
        },
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
        await _markRecoveryJobAbandoned(
          memoUid: memoUid,
          reason: 'placeholder_not_safe_or_missing',
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
      var appendedVideos = 0;
      if (result.isSuccess && !submission.textOnly) {
        final mediaClassification = classifyQuickClipMedia(result);
        LogManager.instance.debug(
          'ShareQuickClip: media_classified',
          context: {
            'memoUid': resolvedMemoUid,
            'parserTag': result.siteParserTag,
            'pageKind': result.pageKind.name,
            'path': mediaClassification.path.name,
            'videoCandidateId': mediaClassification.videoCandidate?.id,
          },
        );
        if (mediaClassification.path == ShareQuickClipMediaPath.video &&
            mediaClassification.videoCandidate != null) {
          appendedVideos = await _appendQuickClipVideo(
            memoUid: resolvedMemoUid,
            result: result,
            candidate: mediaClassification.videoCandidate!,
          );
        } else {
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
          'appendedVideos': appendedVideos,
        },
      );
      await _markRecoveryJobCompleted(memoUid: memoUid);
      if (recoveryTrigger != null) {
        LogManager.instance.info(
          result.isSuccess
              ? 'ShareQuickClipRecovery: retry_success'
              : 'ShareQuickClipRecovery: fallback_saved',
          context: {
            'memoUid': resolvedMemoUid,
            'requestedMemoUid': memoUid,
            'host': request.url.host,
            'trigger': recoveryTrigger,
            'success': result.isSuccess,
          },
        );
      }
      unawaited(
        _requestMemoSyncBestEffort(
          memoUid: resolvedMemoUid,
          requestedMemoUid: memoUid,
          host: request.url.host,
          trigger: 'capture_update',
          extraContext: {
            'appendedInlineImages': appendedInlineImages,
            'appendedVideos': appendedVideos,
          },
        ),
      );
    } on TimeoutException catch (error, stackTrace) {
      LogManager.instance.warn(
        'ShareQuickClip: capture_timeout',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
      final resolvedMemoUid = await _replaceWithFailureContent(
        memoUid: memoUid,
        request: request,
        tags: submission.tags,
        locale: locale,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      );
      if (resolvedMemoUid == null) {
        await _markRecoveryJobAbandoned(
          memoUid: memoUid,
          reason: 'fallback_skipped_after_timeout',
        );
      } else {
        await _markRecoveryJobCompleted(memoUid: memoUid);
        if (recoveryTrigger != null) {
          LogManager.instance.info(
            'ShareQuickClipRecovery: fallback_saved',
            context: {
              'memoUid': resolvedMemoUid,
              'requestedMemoUid': memoUid,
              'host': request.url.host,
              'trigger': recoveryTrigger,
              'reason': 'timeout',
            },
          );
        }
      }
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'ShareQuickClip: capture_failed',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
      final resolvedMemoUid = await _replaceWithFailureContent(
        memoUid: memoUid,
        request: request,
        tags: submission.tags,
        locale: locale,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      );
      if (resolvedMemoUid == null) {
        await _markRecoveryJobAbandoned(
          memoUid: memoUid,
          reason: 'fallback_skipped_after_error',
        );
      } else {
        await _markRecoveryJobCompleted(memoUid: memoUid);
        if (recoveryTrigger != null) {
          LogManager.instance.info(
            'ShareQuickClipRecovery: fallback_saved',
            context: {
              'memoUid': resolvedMemoUid,
              'requestedMemoUid': memoUid,
              'host': request.url.host,
              'trigger': recoveryTrigger,
              'reason': 'error',
            },
          );
        }
      }
    } finally {
      if (reservationHeld || reservedHere) {
        ShareQuickClipRecoveryService._releaseMemoUid(memoUid);
      }
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

  Future<void> _markRecoveryJobCompleted({required String memoUid}) async {
    try {
      await _ref
          .read(quickClipRecoveryMutationServiceProvider)
          .markCompleted(memoUid: memoUid, now: DateTime.now());
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'ShareQuickClip: recovery_job_complete_failed',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid},
      );
    }
  }

  Future<void> _markRecoveryJobAbandoned({
    required String memoUid,
    required String reason,
  }) async {
    try {
      await _ref
          .read(quickClipRecoveryMutationServiceProvider)
          .markAbandoned(
            memoUid: memoUid,
            now: DateTime.now(),
            lastError: reason,
          );
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'ShareQuickClip: recovery_job_abandon_failed',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'reason': reason},
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
        final appendResult = await _ref
            .read(thirdPartyShareAttachmentAppenderProvider)
            .append(
              ThirdPartyShareAttachmentAppendRequest(
                memoUid: memoUid,
                attachmentUid: seed.uid,
                filePath: seed.filePath,
                filename: seed.filename,
                mimeType: seed.mimeType,
                size: seed.size,
                kind: seed.shareInlineImage
                    ? ThirdPartyShareAttachmentKind.inlineImage
                    : ThirdPartyShareAttachmentKind.attachment,
                skipCompression: seed.skipCompression,
                shareInlineImage: seed.shareInlineImage,
                fromThirdPartyShare: seed.fromThirdPartyShare,
                sourceUrl: seed.sourceUrl,
                replaceSourceUrl: request.sourceUrl,
              ),
            );
        if (appendResult.appended) {
          appended++;
        }
        LogManager.instance.debug(
          'ShareQuickClip: inline_image_appended',
          context: {
            'memoUid': memoUid,
            'sourceUrl': request.sourceUrl,
            'attachmentUid': seed.uid,
            'filename': seed.filename,
            'size': seed.size,
            'status': appendResult.status.name,
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

  Future<int> _appendQuickClipVideo({
    required String memoUid,
    required ShareCaptureResult result,
    required ShareVideoCandidate candidate,
  }) async {
    try {
      final uploadSizeLimit = await _ref
          .read(attachmentUploadSizeLimitResolverProvider)
          .resolve();
      LogManager.instance.info(
        'ShareQuickClip: video_prepare_start',
        context: {
          'memoUid': memoUid,
          'candidateId': candidate.id,
          'candidateUrl': candidate.url,
          ..._uploadSizeLimitLogContext(uploadSizeLimit),
        },
      );
      final prepared = await _videoAttachmentPreparer.prepare(
        result: result,
        candidate: candidate,
        uploadSizeLimit: uploadSizeLimit,
      );
      final appendResult = await _ref
          .read(thirdPartyShareAttachmentAppenderProvider)
          .append(
            ThirdPartyShareAttachmentAppendRequest(
              memoUid: memoUid,
              attachmentUid: generateUid(),
              filePath: prepared.filePath,
              filename: prepared.filename,
              mimeType: prepared.mimeType,
              size: prepared.size,
              kind: ThirdPartyShareAttachmentKind.video,
              fromThirdPartyShare: true,
            ),
          );
      LogManager.instance.info(
        'ShareQuickClip: video_append_result',
        context: {
          'memoUid': memoUid,
          'candidateId': candidate.id,
          'filename': prepared.filename,
          'size': prepared.size,
          'wasCompressed': prepared.wasCompressed,
          'status': appendResult.status.name,
        },
      );
      return appendResult.appended ? 1 : 0;
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'ShareQuickClip: video_append_failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'memoUid': memoUid,
          'candidateId': candidate.id,
          'candidateUrl': candidate.url,
        },
      );
      return 0;
    }
  }

  Map<String, Object?> _uploadSizeLimitLogContext(
    AttachmentUploadSizeLimit limit,
  ) {
    if (limit.isKnown) {
      return {
        'uploadLimitKnown': true,
        'uploadLimitBytes': limit.bytes,
        'uploadLimitSource': limit.source?.name,
      };
    }
    return {
      'uploadLimitKnown': false,
      'uploadLimitUnknownReason': limit.unknownReason?.name,
    };
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
      final content = directRow['content'] as String? ?? '';
      if (!isQuickClipPlaceholderContentMatch(
        content,
        placeholderMarker: placeholderMarker,
        placeholderLookupContent: placeholderLookupContent,
      )) {
        LogManager.instance.warn(
          'ShareQuickClip: memo_update_skipped_user_edited',
          context: {'memoUid': memoUid},
        );
        return null;
      }
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

  Future<String?> _replaceWithFailureContent({
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
        return null;
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
      return resolvedMemoUid;
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'ShareQuickClip: fallback_save_failed',
        error: error,
        stackTrace: stackTrace,
        context: {'memoUid': memoUid, 'host': request.url.host},
      );
      return null;
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
    final tagLine = formatMemoTagZoneLine(tags);
    if (tagLine.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(tagLine);
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
    final tagLine = formatMemoTagZoneLine(tags);
    if (tagLine.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(tagLine);
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
        final appendResult = await _ref
            .read(thirdPartyShareAttachmentAppenderProvider)
            .append(
              ThirdPartyShareAttachmentAppendRequest(
                memoUid: memoUid,
                attachmentUid: seed.uid,
                filePath: seed.filePath,
                filename: seed.filename,
                mimeType: seed.mimeType,
                size: seed.size,
                kind: seed.shareInlineImage
                    ? ThirdPartyShareAttachmentKind.inlineImage
                    : ThirdPartyShareAttachmentKind.attachment,
                skipCompression: seed.skipCompression,
                shareInlineImage: seed.shareInlineImage,
                fromThirdPartyShare: seed.fromThirdPartyShare,
                sourceUrl: seed.sourceUrl,
                replaceSourceUrl: sourceUrl,
              ),
            );
        if (appendResult.appended) {
          appended++;
        }
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
    final tagLine = formatMemoTagZoneLine(tags);
    if (tagLine.isEmpty) return content.trimRight();
    final normalizedContent = content.trimRight();
    const marker = '<!-- memoflow-third-party-share -->';
    if (normalizedContent.endsWith(marker)) {
      final body = normalizedContent
          .substring(0, normalizedContent.length - marker.length)
          .trimRight();
      return '$body\n\n$tagLine\n\n$marker';
    }
    return '$normalizedContent\n\n$tagLine';
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

class ShareQuickClipRecoveryService {
  ShareQuickClipRecoveryService({
    required WidgetRef ref,
    required AppBootstrapAdapter bootstrapAdapter,
    ShareCaptureEngine? engine,
    ShareInlineImageDownloadService? inlineImageDownloadService,
    ShareVideoAttachmentPreparer? videoAttachmentPreparer,
    this.staleThreshold = const Duration(minutes: 10),
    this.terminalCleanupRetention = const Duration(days: 7),
    this.maxRecoveryAttempts = 1,
  }) : _ref = ref,
       _bootstrapAdapter = bootstrapAdapter,
       _engine = engine,
       _inlineImageDownloadService = inlineImageDownloadService,
       _videoAttachmentPreparer = videoAttachmentPreparer;

  static const int defaultJobLimit = 8;

  static final Set<String> _inFlightMemoUids = <String>{};
  static bool _scanInFlight = false;

  final WidgetRef _ref;
  final AppBootstrapAdapter _bootstrapAdapter;
  final ShareCaptureEngine? _engine;
  final ShareInlineImageDownloadService? _inlineImageDownloadService;
  final ShareVideoAttachmentPreparer? _videoAttachmentPreparer;
  final Duration staleThreshold;
  final Duration terminalCleanupRetention;
  final int maxRecoveryAttempts;

  Future<void> recoverPending({
    String trigger = 'manual',
    int limit = defaultJobLimit,
  }) async {
    if (_scanInFlight) {
      LogManager.instance.debug(
        'ShareQuickClipRecovery: scan_deduped',
        context: {'trigger': trigger},
      );
      return;
    }

    _scanInFlight = true;
    try {
      late final QuickClipRecoveryMutationService recoveryStore;
      try {
        recoveryStore = _ref.read(quickClipRecoveryMutationServiceProvider);
      } catch (error, stackTrace) {
        LogManager.instance.debug(
          'ShareQuickClipRecovery: scan_skipped',
          error: error,
          stackTrace: stackTrace,
          context: {'trigger': trigger, 'reason': 'database_unavailable'},
        );
        return;
      }

      final jobs = await recoveryStore.listRecoverableJobs(limit: limit);
      if (jobs.isEmpty) {
        LogManager.instance.debug(
          'ShareQuickClipRecovery: scan_empty',
          context: {'trigger': trigger},
        );
        return;
      }

      LogManager.instance.info(
        'ShareQuickClipRecovery: scan_start',
        context: {'trigger': trigger, 'jobCount': jobs.length},
      );
      for (final job in jobs) {
        if (!_reserveMemoUid(job.memoUid)) {
          LogManager.instance.debug(
            'ShareQuickClipRecovery: job_deduped',
            context: {'memoUid': job.memoUid, 'trigger': trigger},
          );
          continue;
        }
        try {
          await _recoverJob(
            job,
            recoveryStore: recoveryStore,
            trigger: trigger,
            now: DateTime.now(),
          );
        } finally {
          _releaseMemoUid(job.memoUid);
        }
      }

      await recoveryStore.deleteTerminalJobs(
        completedBefore: DateTime.now().subtract(terminalCleanupRetention),
        limit: 50,
      );
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'ShareQuickClipRecovery: unexpected_failure',
        error: error,
        stackTrace: stackTrace,
        context: {'trigger': trigger},
      );
    } finally {
      _scanInFlight = false;
    }
  }

  Future<void> _recoverJob(
    QuickClipRecoveryJob job, {
    required QuickClipRecoveryMutationService recoveryStore,
    required String trigger,
    required DateTime now,
  }) async {
    if (job.isTerminal) return;
    if (job.titleAndLinkOnly) {
      await recoveryStore.markAbandoned(
        memoUid: job.memoUid,
        now: now,
        lastError: 'unexpected_title_and_link_only_job',
      );
      LogManager.instance.warn(
        'ShareQuickClipRecovery: malformed_job',
        context: {
          'memoUid': job.memoUid,
          'trigger': trigger,
          'reason': 'title_and_link_only',
        },
      );
      return;
    }

    final payload = _payloadFromJob(job);
    final request = _requestFromJob(job, payload);
    if (request == null) {
      await recoveryStore.markFailed(
        memoUid: job.memoUid,
        now: now,
        lastError: 'malformed_job',
      );
      LogManager.instance.warn(
        'ShareQuickClipRecovery: malformed_job',
        context: {
          'memoUid': job.memoUid,
          'trigger': trigger,
          'sourceUrl': job.sourceUrl,
        },
      );
      return;
    }

    final placeholderState = await _readPlaceholderState(job);
    switch (placeholderState) {
      case _QuickClipRecoveryPlaceholderState.safe:
        break;
      case _QuickClipRecoveryPlaceholderState.userEdited:
        await recoveryStore.markAbandoned(
          memoUid: job.memoUid,
          now: now,
          lastError: 'placeholder_user_edited',
        );
        LogManager.instance.info(
          'ShareQuickClipRecovery: user_edited_placeholder_skipped',
          context: {'memoUid': job.memoUid, 'trigger': trigger},
        );
        return;
      case _QuickClipRecoveryPlaceholderState.missing:
        await recoveryStore.markAbandoned(
          memoUid: job.memoUid,
          now: now,
          lastError: 'placeholder_missing',
        );
        LogManager.instance.info(
          'ShareQuickClipRecovery: memo_missing',
          context: {'memoUid': job.memoUid, 'trigger': trigger},
        );
        return;
    }

    final age = now.difference(job.createdTime);
    if (age >= staleThreshold) {
      await _saveFallback(
        job,
        request: request,
        recoveryStore: recoveryStore,
        trigger: trigger,
        reason: 'expired',
      );
      return;
    }

    if (job.attemptCount >= maxRecoveryAttempts) {
      await _saveFallback(
        job,
        request: request,
        recoveryStore: recoveryStore,
        trigger: trigger,
        reason: 'retry_exhausted',
      );
      return;
    }

    final updated = await recoveryStore.markRunning(
      memoUid: job.memoUid,
      now: now,
    );
    if (updated == 0) {
      LogManager.instance.debug(
        'ShareQuickClipRecovery: job_claim_skipped',
        context: {'memoUid': job.memoUid, 'trigger': trigger},
      );
      return;
    }

    final service = _buildQuickClipService();
    await service._captureAndUpdate(
      memoUid: job.memoUid,
      payload: payload,
      request: request,
      submission: ShareQuickClipSubmission(
        tags: job.tags,
        textOnly: job.textOnly,
        titleAndLinkOnly: false,
      ),
      locale: _localeFromJob(job),
      placeholderMarker: job.placeholderMarker,
      placeholderLookupContent: job.placeholderLookupContent,
      reservationHeld: true,
      recoveryTrigger: trigger,
    );
  }

  Future<void> _saveFallback(
    QuickClipRecoveryJob job, {
    required ShareCaptureRequest request,
    required QuickClipRecoveryMutationService recoveryStore,
    required String trigger,
    required String reason,
  }) async {
    final service = _buildQuickClipService();
    final resolvedMemoUid = await service._replaceWithFailureContent(
      memoUid: job.memoUid,
      request: request,
      tags: job.tags,
      locale: _localeFromJob(job),
      placeholderMarker: job.placeholderMarker,
      placeholderLookupContent: job.placeholderLookupContent,
    );
    if (resolvedMemoUid == null) {
      await recoveryStore.markAbandoned(
        memoUid: job.memoUid,
        now: DateTime.now(),
        lastError: 'fallback_skipped_$reason',
      );
      LogManager.instance.info(
        'ShareQuickClipRecovery: fallback_skipped',
        context: {'memoUid': job.memoUid, 'trigger': trigger, 'reason': reason},
      );
      return;
    }

    await recoveryStore.markCompleted(
      memoUid: job.memoUid,
      now: DateTime.now(),
    );
    LogManager.instance.info(
      'ShareQuickClipRecovery: fallback_saved',
      context: {
        'memoUid': resolvedMemoUid,
        'requestedMemoUid': job.memoUid,
        'trigger': trigger,
        'reason': reason,
      },
    );
  }

  Future<_QuickClipRecoveryPlaceholderState> _readPlaceholderState(
    QuickClipRecoveryJob job,
  ) async {
    final db = _bootstrapAdapter.readDatabase(_ref);
    final directRow = await db.getMemoByUid(job.memoUid);
    if (directRow != null) {
      final content = directRow['content'] as String? ?? '';
      return isQuickClipPlaceholderContentMatch(
            content,
            placeholderMarker: job.placeholderMarker,
            placeholderLookupContent: job.placeholderLookupContent,
          )
          ? _QuickClipRecoveryPlaceholderState.safe
          : _QuickClipRecoveryPlaceholderState.userEdited;
    }

    final recentRows = await db.listMemos(
      limit: _quickClipResolveMemoScanLimit,
    );
    final resolved = findQuickClipPlaceholderMemoRow(
      recentRows,
      memoUid: job.memoUid,
      placeholderMarker: job.placeholderMarker,
      placeholderLookupContent: job.placeholderLookupContent,
    );
    return resolved == null
        ? _QuickClipRecoveryPlaceholderState.missing
        : _QuickClipRecoveryPlaceholderState.safe;
  }

  ShareQuickClipService _buildQuickClipService() {
    return ShareQuickClipService(
      ref: _ref,
      bootstrapAdapter: _bootstrapAdapter,
      engine: _engine,
      inlineImageDownloadService: _inlineImageDownloadService,
      videoAttachmentPreparer: _videoAttachmentPreparer,
    );
  }

  SharePayload _payloadFromJob(QuickClipRecoveryJob job) {
    final type = switch (job.payloadType.trim().toLowerCase()) {
      'images' || 'image' => SharePayloadType.images,
      _ => SharePayloadType.text,
    };
    final payloadText = job.payloadText.trim().isEmpty
        ? job.sourceUrl
        : job.payloadText;
    return SharePayload(
      type: type,
      text: payloadText,
      title: job.payloadTitle,
      paths: job.payloadPaths,
    );
  }

  ShareCaptureRequest? _requestFromJob(
    QuickClipRecoveryJob job,
    SharePayload payload,
  ) {
    final request = buildShareCaptureRequest(payload);
    if (request != null) return request;
    final uri = Uri.tryParse(job.sourceUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return ShareCaptureRequest(
      payload: payload,
      url: uri,
      sharedTitle: job.payloadTitle,
      sharedText: payload.text ?? job.sourceUrl,
    );
  }

  Locale _localeFromJob(QuickClipRecoveryJob job) {
    final raw = job.localeLanguageCode.trim();
    if (raw.isEmpty) return const Locale('en');
    final languageCode = raw.split(RegExp(r'[-_]')).first.trim();
    if (languageCode.isEmpty) return const Locale('en');
    return Locale(languageCode);
  }

  static bool _reserveMemoUid(String memoUid) {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return false;
    return _inFlightMemoUids.add(normalized);
  }

  static void _releaseMemoUid(String memoUid) {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) return;
    _inFlightMemoUids.remove(normalized);
  }
}

enum _QuickClipRecoveryPlaceholderState { safe, userEdited, missing }
