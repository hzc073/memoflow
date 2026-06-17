import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_page.dart';
import '../media_preview/media_preview_launcher.dart';
import '../memos/memo_markdown.dart';
import '../memos/memo_video_grid.dart';
import 'share_capture_engine.dart';
import 'share_capture_inappwebview_engine.dart';
import 'share_clip_controller.dart';
import 'share_clip_models.dart';
import 'share_handler.dart';
import 'share_inline_image_download_service.dart';
import 'share_video_download_service.dart';

class ShareClipScreen extends StatefulWidget {
  const ShareClipScreen({
    super.key,
    required this.payload,
    this.engine,
    this.downloadService,
    this.inlineImageDownloadService,
    this.onComplete,
    this.onCancel,
    this.showGenericCancelAction = true,
    this.desktopNavigationMode,
    this.desktopNavigationContext,
    this.desktopWindowChromeSafeArea = false,
  });

  final SharePayload payload;
  final ShareCaptureEngine? engine;
  final ShareVideoDownloadService? downloadService;
  final ShareInlineImageDownloadService? inlineImageDownloadService;
  final ValueChanged<ShareComposeRequest>? onComplete;
  final VoidCallback? onCancel;
  final bool showGenericCancelAction;
  final DesktopTitlebarNavigationMode? desktopNavigationMode;
  final DesktopTitlebarNavigationContext? desktopNavigationContext;
  final bool desktopWindowChromeSafeArea;

  @override
  State<ShareClipScreen> createState() => _ShareClipScreenState();
}

class _ShareClipScreenState extends State<ShareClipScreen> {
  late final ShareClipController _controller;
  late final ShareVideoDownloadService _downloadService;
  final Map<String, Future<ShareVideoProbeResult>> _probeFutures =
      <String, Future<ShareVideoProbeResult>>{};
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _downloadService = widget.downloadService ?? ShareVideoDownloadService();
    _controller = ShareClipController(
      payload: widget.payload,
      engine: widget.engine ?? ShareCaptureInAppWebViewEngine(),
      inlineImageDownloadService: widget.inlineImageDownloadService,
    );
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final state = _controller.state;
        final result = state.result;
        final autoComposeRequest = state.autoComposeRequest;
        if (autoComposeRequest != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final request = _controller.takeAutoComposeRequest();
            if (request == null) return;
            final resolvedRequest =
                result?.isVideoPage == true &&
                    !(result?.hasDirectVideoCandidates ?? false)
                ? request.copyWith(
                    userMessage:
                        context.t.strings.shareClip.fallbackParseFailed,
                  )
                : request;
            _complete(resolvedRequest);
          });
        }
        final domain =
            result?.finalUrl.host ??
            buildShareCaptureRequest(widget.payload)?.url.host ??
            '';
        final title = _resolveTitle(result);
        final isVideoPage = result?.isVideoPage ?? false;
        return PlatformPage(
          title: Text(context.t.strings.legacy.msg_preview),
          actions: widget.showGenericCancelAction
              ? [
                  TextButton(
                    onPressed: state.phase == ShareClipPhase.composing
                        ? null
                        : _cancel,
                    child: Text(context.t.strings.common.cancel),
                  ),
                ]
              : const <Widget>[],
          desktopNavigationMode: widget.desktopNavigationMode,
          desktopNavigationContext: widget.desktopNavigationContext,
          desktopWindowChromeSafeArea: widget.desktopWindowChromeSafeArea,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _HeaderCard(
                    title: title,
                    domain: domain,
                    subtitle: _buildSubtitle(state, context),
                    badge: isVideoPage
                        ? context.t.strings.shareClip.videoDetected
                        : null,
                  ),
                ),
                Expanded(
                  child: switch (state.phase) {
                    ShareClipPhase.loading ||
                    ShareClipPhase.composing ||
                    ShareClipPhase.processingVideo => _LoadingBody(
                      stage: state.stage,
                      message: state.processingMessage,
                      progress:
                          state.stage == ShareCaptureStage.downloadingVideo
                          ? state.downloadProgress
                          : state.stage == ShareCaptureStage.compressingVideo
                          ? state.compressionProgress
                          : null,
                    ),
                    ShareClipPhase.success =>
                      isVideoPage
                          ? _VideoSuccessBody(
                              result: result!,
                              onDownload: _handleVideoDownload,
                              onPreview: _openVideoPreview,
                              probeCandidate: _probeCandidate,
                            )
                          : _SuccessBody(
                              previewText:
                                  state.previewText ??
                                  state.linkOnlyRequest.text,
                            ),
                    ShareClipPhase.failure => _FailureBody(
                      message: _buildFailureMessage(result, context),
                      excerpt: result?.excerpt,
                    ),
                  },
                ),
                _ActionBar(
                  phase: state.phase,
                  isVideoPage: isVideoPage,
                  onSaveMemo:
                      state.phase == ShareClipPhase.success && !isVideoPage
                      ? () => unawaited(_handleSaveMemo())
                      : null,
                  onUseLinkOnly: state.phase == ShareClipPhase.composing
                      ? null
                      : () => _complete(_controller.useLinkOnly()),
                  onRetry:
                      state.phase == ShareClipPhase.loading ||
                          state.phase == ShareClipPhase.composing ||
                          state.phase == ShareClipPhase.processingVideo
                      ? null
                      : _controller.retry,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _complete(ShareComposeRequest request) {
    if (_completed) return;
    final callback = widget.onComplete;
    if (callback != null) {
      callback(request);
      return;
    }
    _completed = true;
    Navigator.of(context).pop(request);
  }

  void _cancel() {
    if (_completed) return;
    final callback = widget.onCancel;
    if (callback != null) {
      callback();
      return;
    }
    _completed = true;
    Navigator.of(context).pop();
  }

  Future<void> _handleVideoDownload(ShareVideoCandidate candidate) async {
    final request = _controller.attachVideo(candidate);
    if (!mounted) return;
    if (request == null) return;
    _complete(request);
  }

  Future<void> _handleSaveMemo() async {
    final request = await _controller.saveArticle();
    if (!mounted || request == null) return;
    _complete(request);
  }

  Future<ShareVideoProbeResult> _probeCandidate(
    ShareCaptureResult result,
    ShareVideoCandidate candidate,
  ) {
    return _probeFutures.putIfAbsent(
      candidate.id,
      () => _downloadService.probe(result: result, candidate: candidate),
    );
  }

  Future<void> _openVideoPreview(
    ShareCaptureResult result,
    ShareVideoCandidate candidate,
  ) async {
    final probe = await _probeCandidate(result, candidate);
    if (!mounted) return;
    await MediaPreviewLauncher.openVideo(
      context,
      MemoVideoEntry(
        id: candidate.id,
        title: candidate.title ?? _resolveTitle(result),
        mimeType: 'video/*',
        size: probe.contentLength ?? 0,
        videoUrl: candidate.url,
        thumbnailUrl: candidate.thumbnailUrl ?? result.leadImageUrl,
        headers: probe.headers,
      ),
    );
  }

  String _resolveTitle(ShareCaptureResult? result) {
    return result?.articleTitle ??
        result?.pageTitle ??
        widget.payload.title ??
        buildShareCaptureRequest(widget.payload)?.url.host ??
        '';
  }

  String _buildSubtitle(ShareClipViewState state, BuildContext context) {
    if (state.phase == ShareClipPhase.processingVideo &&
        state.processingMessage != null) {
      return state.processingMessage!;
    }
    return switch (state.phase) {
      ShareClipPhase.loading => _stageLabel(state.stage, context),
      ShareClipPhase.composing => context.t.strings.common.save,
      ShareClipPhase.processingVideo => _stageLabel(state.stage, context),
      ShareClipPhase.success => context.t.strings.legacy.msg_preview,
      ShareClipPhase.failure => _buildFailureMessage(state.result, context),
    };
  }

  String _buildFailureMessage(
    ShareCaptureResult? result,
    BuildContext context,
  ) {
    return switch (result?.failure) {
      ShareCaptureFailure.unsupportedUrl =>
        context.t.strings.shareClip.failureUnsupportedUrl,
      ShareCaptureFailure.loadTimeout =>
        context.t.strings.shareClip.failureLoadTimeout,
      ShareCaptureFailure.webViewError =>
        context.t.strings.shareClip.failureWebView,
      ShareCaptureFailure.domUnavailable =>
        context.t.strings.shareClip.failureDom,
      ShareCaptureFailure.parserEmpty =>
        context.t.strings.shareClip.failureParserEmpty,
      ShareCaptureFailure.unknown ||
      null => context.t.strings.shareClip.failureUnknown,
    };
  }

  String _stageLabel(ShareCaptureStage stage, BuildContext context) {
    return switch (stage) {
      ShareCaptureStage.loadingPage =>
        context.t.strings.shareClip.stageLoadingPage,
      ShareCaptureStage.waitingForDynamicContent =>
        context.t.strings.shareClip.stageWaitingContent,
      ShareCaptureStage.detectingMedia =>
        context.t.strings.shareClip.stageDetectingMedia,
      ShareCaptureStage.parsingArticle =>
        context.t.strings.shareClip.stageParsingArticle,
      ShareCaptureStage.buildingPreview =>
        context.t.strings.shareClip.stageBuildingPreview,
      ShareCaptureStage.downloadingVideo =>
        context.t.strings.shareClip.stageDownloadingVideo,
      ShareCaptureStage.compressingVideo =>
        context.t.strings.shareClip.stageCompressingVideo,
    };
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.domain,
    required this.subtitle,
    this.badge,
  });

  final String title;
  final String domain;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title.isEmpty ? domain : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            if (domain.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                domain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.stage, this.message, this.progress});

  final ShareCaptureStage stage;
  final String? message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final label = message ?? _defaultStageLabel(context, stage);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(value: progress),
            ),
            const SizedBox(height: 16),
            Text(context.t.strings.legacy.msg_loading),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Text('${(progress! * 100).round()}%'),
            ],
          ],
        ),
      ),
    );
  }

  String _defaultStageLabel(BuildContext context, ShareCaptureStage stage) {
    return switch (stage) {
      ShareCaptureStage.loadingPage =>
        context.t.strings.shareClip.stageLoadingPage,
      ShareCaptureStage.waitingForDynamicContent =>
        context.t.strings.shareClip.stageWaitingContent,
      ShareCaptureStage.detectingMedia =>
        context.t.strings.shareClip.stageDetectingMedia,
      ShareCaptureStage.parsingArticle =>
        context.t.strings.shareClip.stageParsingArticle,
      ShareCaptureStage.buildingPreview =>
        context.t.strings.shareClip.stageBuildingPreview,
      ShareCaptureStage.downloadingVideo =>
        context.t.strings.shareClip.stageDownloadingVideo,
      ShareCaptureStage.compressingVideo =>
        context.t.strings.shareClip.stageCompressingVideo,
    };
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.previewText});

  final String previewText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: MemoMarkdown(data: previewText),
    );
  }
}

class _VideoSuccessBody extends StatelessWidget {
  const _VideoSuccessBody({
    required this.result,
    required this.onDownload,
    required this.onPreview,
    required this.probeCandidate,
  });

  final ShareCaptureResult result;
  final Future<void> Function(ShareVideoCandidate candidate) onDownload;
  final Future<void> Function(
    ShareCaptureResult result,
    ShareVideoCandidate candidate,
  )
  onPreview;
  final Future<ShareVideoProbeResult> Function(
    ShareCaptureResult result,
    ShareVideoCandidate candidate,
  )
  probeCandidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if ((result.excerpt ?? '').trim().isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(result.excerpt!, style: theme.textTheme.bodyMedium),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          context.t.strings.shareClip.originalLinkLabel,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        SelectableText(result.finalUrl.toString()),
        const SizedBox(height: 16),
        Text(
          context.t.strings.shareClip.videoCandidatesTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        ...result.videoCandidates.map(
          (candidate) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VideoCandidateTile(
              result: result,
              candidate: candidate,
              actionLabel: context.t.strings.shareClip.downloadAndAttach,
              sourceLabel: _videoSourceLabel(context, candidate),
              statusLabel: context.t.strings.shareClip.directLinkLabel,
              probeFuture: probeCandidate(result, candidate),
              onPreview: () => onPreview(result, candidate),
              onPressed: () => onDownload(candidate),
            ),
          ),
        ),
        ...result.unsupportedVideoCandidates.map(
          (candidate) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VideoCandidateTile(
              result: result,
              candidate: candidate,
              actionLabel: context.t.strings.shareClip.notSupportedLabel,
              sourceLabel: _videoSourceLabel(context, candidate),
              statusLabel: _unsupportedReasonLabel(context, candidate.reason),
              probeFuture: null,
              onPreview: null,
              onPressed: null,
            ),
          ),
        ),
      ],
    );
  }

  String _videoSourceLabel(
    BuildContext context,
    ShareVideoCandidate candidate,
  ) {
    if (candidate.parserTag == 'bilibili') {
      return 'Bilibili';
    }
    if (candidate.parserTag == 'xiaohongshu') {
      return context.t.strings.shareClip.xiaohongshuLabel;
    }
    return switch (candidate.source) {
      ShareVideoSource.meta => 'Meta',
      ShareVideoSource.dom => 'DOM',
      ShareVideoSource.jsonLd => 'JSON-LD',
      ShareVideoSource.link => 'Link',
      ShareVideoSource.request => 'Request',
      ShareVideoSource.ajax => 'XHR',
      ShareVideoSource.fetch => 'Fetch',
      ShareVideoSource.resource => 'Resource',
      ShareVideoSource.parser => 'Parser',
    };
  }

  String _unsupportedReasonLabel(BuildContext context, String? reason) {
    return switch (reason) {
      'separate_dash_not_supported' =>
        context.t.strings.shareClip.unsupportedDash,
      'stream_only_not_supported' =>
        context.t.strings.shareClip.unsupportedStream,
      _ => context.t.strings.shareClip.notSupportedLabel,
    };
  }
}

class _VideoCandidateTile extends StatelessWidget {
  const _VideoCandidateTile({
    required this.result,
    required this.candidate,
    required this.actionLabel,
    required this.sourceLabel,
    required this.statusLabel,
    required this.probeFuture,
    required this.onPreview,
    required this.onPressed,
  });

  final ShareCaptureResult result;
  final ShareVideoCandidate candidate;
  final String actionLabel;
  final String sourceLabel;
  final String statusLabel;
  final Future<ShareVideoProbeResult>? probeFuture;
  final VoidCallback? onPreview;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        candidate.title ??
        result.articleTitle ??
        result.pageTitle ??
        result.finalUrl.host;
    final thumbnailUrl = candidate.thumbnailUrl ?? result.leadImageUrl;

    return FutureBuilder<ShareVideoProbeResult>(
      future: probeFuture,
      builder: (context, snapshot) {
        final probe = snapshot.data;
        final headers = probe?.headers ?? const <String, String>{};
        final sizeLabel =
            probe?.contentLength != null && probe!.contentLength! > 0
            ? _formatBytes(probe.contentLength!)
            : null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if ((thumbnailUrl ?? '').trim().isNotEmpty)
                          Image.network(
                            thumbnailUrl!,
                            fit: BoxFit.cover,
                            headers: headers,
                            errorBuilder: (context, error, stackTrace) {
                              return _VideoPreviewPlaceholder(
                                enabled: onPreview != null,
                              );
                            },
                          )
                        else
                          _VideoPreviewPlaceholder(enabled: onPreview != null),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.08),
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                        if (onPreview != null)
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              size: 54,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _VideoMetaChip(label: sourceLabel),
                    _VideoMetaChip(label: statusLabel),
                    if (sizeLabel != null) _VideoMetaChip(label: sizeLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onPreview != null) ...[
                      OutlinedButton.icon(
                        onPressed: onPreview,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(context.t.strings.legacy.msg_preview),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton(
                      onPressed: onPressed,
                      child: Text(actionLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoMetaChip extends StatelessWidget {
  const _VideoMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

class _VideoPreviewPlaceholder extends StatelessWidget {
  const _VideoPreviewPlaceholder({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainerLow,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          enabled ? Icons.smart_display_rounded : Icons.videocam_off_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message, this.excerpt});

  final String message;
  final String? excerpt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 40),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (excerpt != null && excerpt!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                excerpt!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.phase,
    required this.isVideoPage,
    required this.onSaveMemo,
    required this.onUseLinkOnly,
    required this.onRetry,
  });

  final ShareClipPhase phase;
  final bool isVideoPage;
  final VoidCallback? onSaveMemo;
  final VoidCallback? onUseLinkOnly;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (phase == ShareClipPhase.success && !isVideoPage)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSaveMemo,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(context.t.strings.legacy.msg_save_memo),
                ),
              ),
            if (phase == ShareClipPhase.success && !isVideoPage)
              const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onUseLinkOnly,
                child: Text(context.t.strings.shareClip.linkOnlyLabel),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.t.strings.legacy.msg_retry),
            ),
          ],
        ),
      ),
    );
  }
}
