import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../core/app_localization.dart';
import '../../core/memo_clip_markdown.dart';
import '../../core/memoflow_palette.dart';
import '../../core/pointer_double_tap_listener.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/top_toast.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/attachment.dart';
import '../../data/models/content_fingerprint.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_clip_card_metadata.dart';
import '../../platform/platform_icons.dart';
import '../../platform/platform_route.dart';
import '../../platform/platform_target.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform_capabilities/ios_mobile_feature_readiness.dart';
import '../../state/memos/memo_detail_providers.dart';
import '../../state/memos/memo_clip_card_providers.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/settings/resolved_preferences_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../../state/system/session_provider.dart';
import '../image_preview/image_preview_item.dart';
import '../image_preview/image_preview_launcher.dart';
import '../image_preview/image_preview_open_request.dart';
import '../share/share_inline_image_content.dart';
import '../collections/add_to_collection_sheet.dart';
import '../reminders/memo_reminder_editor_screen.dart';
import 'attachment_gallery_screen.dart';
import 'memo_card_action.dart';
import 'memo_editor_screen.dart';
import 'memo_detail_view.dart';
import 'memo_image_grid.dart';
import 'memo_image_preview_adapters.dart';
import 'memo_inline_image_rendering_policy.dart';
import 'memo_inline_image_sources.dart';
import 'memo_inline_image_syntax.dart';
import 'memo_media_grid.dart';
import 'memo_markdown.dart';
import 'memo_render_pipeline.dart';
import 'memo_hero_flight.dart';
import 'memo_time_adjustment_sheet.dart';
import 'memo_versions_screen.dart';
import 'memos_list_screen.dart';
import 'memo_video_grid.dart';
import 'widgets/memo_clip_card_header.dart';
import 'widgets/memo_detail_action_menu.dart';
import 'widgets/memo_engagement_surface.dart';
import 'widgets/memo_reader_content.dart';
import '../../i18n/strings.g.dart';

const Key memoDetailActionMenuRegionKey = ValueKey<String>(
  'memo-detail-action-menu-region',
);
const Key memoDetailBoundedDocumentKey = ValueKey<String>(
  'memo-detail-bounded-document',
);
const double _memoDetailDesktopMaxReadWidth = 820;

String memoDetailMarkdownCacheKey(
  LocalMemo memo, {
  required bool renderImages,
  TagRecognitionPolicy tagRecognitionPolicy =
      TagRecognitionPolicy.defaultPolicy,
  MemoInlineImageSyntax? imageSyntax,
  bool stripClipTitle = false,
  String localInlineImageFingerprint = '',
}) {
  final resolvedImageSyntax = resolveMemoInlineImageSyntax(
    renderImages: renderImages,
    imageSyntax: imageSyntax,
  );
  final renderFlag = renderImages ? 1 : 0;
  final stripFlag = stripClipTitle ? 1 : 0;
  return 'detail|${memo.uid}|${memo.contentFingerprint}|renderImages=$renderFlag|imageSyntax=${resolvedImageSyntax.cacheToken}|tagPolicy=${tagRecognitionPolicy.cacheToken}|clip=$stripFlag|localInline=$localInlineImageFingerprint|highlight=';
}

String buildMemoDocumentMarkdownCacheKey(
  LocalMemo memo, {
  required bool renderImages,
  TagRecognitionPolicy tagRecognitionPolicy =
      TagRecognitionPolicy.defaultPolicy,
  MemoInlineImageSyntax? imageSyntax,
  bool stripClipTitle = false,
  String localInlineImageFingerprint = '',
}) {
  return memoDetailMarkdownCacheKey(
    memo,
    renderImages: renderImages,
    tagRecognitionPolicy: tagRecognitionPolicy,
    imageSyntax: imageSyntax,
    stripClipTitle: stripClipTitle,
    localInlineImageFingerprint: localInlineImageFingerprint,
  );
}

class MemoDocumentResolvedData {
  const MemoDocumentResolvedData({
    required this.memo,
    required this.displayContentText,
    required this.markdownArtifact,
    required this.markdownCacheKey,
    required this.clipCard,
    required this.clipParts,
    required this.imageEntries,
    required this.videoEntries,
    required this.mediaEntries,
    required this.imagePreviewItems,
    required this.inlineImageSourcePolicy,
    required this.nonImageAttachments,
    required this.memoErrorText,
    required this.baseUrl,
    required this.authHeader,
    required this.rebaseAbsoluteFileUrlForV024,
    required this.attachAuthForSameOriginAbsolute,
    required this.richContentEnabled,
    required this.effectiveRenderInlineImages,
    required this.inlineImageSyntax,
    required this.tagRecognitionPolicy,
  });

  final LocalMemo memo;
  final String displayContentText;
  final MemoRenderArtifact markdownArtifact;
  final String markdownCacheKey;
  final MemoClipCardMetadata? clipCard;
  final MemoClipMarkdownParts? clipParts;
  final List<MemoImageEntry> imageEntries;
  final List<MemoVideoEntry> videoEntries;
  final List<MemoMediaEntry> mediaEntries;
  final List<ImagePreviewItem> imagePreviewItems;
  final MemoInlineImageSourcePolicy inlineImageSourcePolicy;
  final List<Attachment> nonImageAttachments;
  final String? memoErrorText;
  final Uri? baseUrl;
  final String? authHeader;
  final bool rebaseAbsoluteFileUrlForV024;
  final bool attachAuthForSameOriginAbsolute;
  final bool richContentEnabled;
  final bool effectiveRenderInlineImages;
  final MemoInlineImageSyntax inlineImageSyntax;
  final TagRecognitionPolicy tagRecognitionPolicy;
}

MemoDocumentResolvedData buildMemoDocumentResolvedData({
  required LocalMemo memo,
  required AppLanguage appLanguage,
  required MemoClipCardMetadata? clipCard,
  required Uri? baseUrl,
  required String? authHeader,
  required bool rebaseAbsoluteFileUrlForV024,
  required bool attachAuthForSameOriginAbsolute,
  required bool richContentEnabled,
  TagRecognitionPolicy tagRecognitionPolicy =
      TagRecognitionPolicy.defaultPolicy,
}) {
  final clipParts = clipCard == null
      ? null
      : parseMemoClipMarkdown(memo.content);
  final renderInlineImages = contentHasThirdPartyShareMarker(memo.content);
  final displayContentText = clipCard == null
      ? memo.content
      : stripMemoClipTitle(
          memo.content,
        ).replaceAll(buildThirdPartyShareMemoMarker(), '').trimRight();
  final requestedInlineImageSyntax = renderInlineImages
      ? MemoInlineImageSyntax.markdownAndHtml
      : MemoInlineImageSyntax.markdownOnly;
  final inlineImagePolicy = buildMemoInlineImageRenderPolicy(
    content: displayContentText,
    attachments: memo.attachments,
    enabled: richContentEnabled,
    syntax: requestedInlineImageSyntax,
  );
  final inlineImageSyntax = inlineImagePolicy.syntax;
  final effectiveRenderInlineImages = inlineImagePolicy.rendersImages;
  final imageEntries = !richContentEnabled
      ? const <MemoImageEntry>[]
      : collectMemoImageEntries(
          content: displayContentText,
          attachments: memo.attachments,
          baseUrl: baseUrl,
          authHeader: authHeader,
          rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        );
  final videoEntries = !richContentEnabled
      ? const <MemoVideoEntry>[]
      : collectMemoVideoEntries(
          attachments: memo.attachments,
          baseUrl: baseUrl,
          authHeader: authHeader,
          rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        );
  final mediaEntries = !richContentEnabled
      ? const <MemoMediaEntry>[]
      : effectiveRenderInlineImages
      ? memoTrailingMediaEntriesForInlineBody(
          buildMemoMediaEntries(images: imageEntries, videos: videoEntries),
        )
      : buildMemoMediaEntries(images: imageEntries, videos: videoEntries);
  final imagePreviewItems = !richContentEnabled
      ? const <ImagePreviewItem>[]
      : collectMemoDocumentImagePreviewItems(
          content: displayContentText,
          attachments: memo.attachments,
          baseUrl: baseUrl,
          authHeader: authHeader,
          rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        );
  final inlineImageSourcePolicy = inlineImagePolicy.localSourcePolicy;
  final nonImageAttachments = memo.attachments
      .where(
        (attachment) =>
            !attachment.type.startsWith('image/') &&
            !attachment.type.startsWith('video/'),
      )
      .toList(growable: false);
  final memoErrorText =
      (memo.lastError == null || memo.lastError!.trim().isEmpty)
      ? null
      : presentSyncErrorText(
          language: appLanguage,
          raw: memo.lastError!.trim(),
        );
  final markdownCacheKey = buildMemoDocumentMarkdownCacheKey(
    memo,
    renderImages: effectiveRenderInlineImages,
    tagRecognitionPolicy: tagRecognitionPolicy,
    imageSyntax: inlineImageSyntax,
    stripClipTitle: clipCard != null,
    localInlineImageFingerprint: inlineImageSourcePolicy.fingerprint,
  );

  return MemoDocumentResolvedData(
    memo: memo,
    displayContentText: displayContentText,
    markdownArtifact: buildMemoRenderArtifact(
      data: displayContentText,
      renderImages: effectiveRenderInlineImages,
      tagRecognitionPolicy: tagRecognitionPolicy,
      imageSyntax: inlineImageSyntax,
      cacheKey: markdownCacheKey,
      allowedLocalImageUrls: inlineImageSourcePolicy.allowedLocalImageUrls,
    ),
    markdownCacheKey: markdownCacheKey,
    clipCard: clipCard,
    clipParts: clipParts,
    imageEntries: imageEntries,
    videoEntries: videoEntries,
    mediaEntries: mediaEntries,
    imagePreviewItems: imagePreviewItems,
    inlineImageSourcePolicy: inlineImageSourcePolicy,
    nonImageAttachments: nonImageAttachments,
    memoErrorText: memoErrorText,
    baseUrl: baseUrl,
    authHeader: authHeader,
    rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
    attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    richContentEnabled: richContentEnabled,
    effectiveRenderInlineImages: effectiveRenderInlineImages,
    inlineImageSyntax: inlineImageSyntax,
    tagRecognitionPolicy: tagRecognitionPolicy,
  );
}

class MemoDocumentAudioHandle {
  const MemoDocumentAudioHandle({
    required this.isPlayingForUrl,
    this.playerStateStream,
    this.onTogglePlayAudio,
  });

  final bool Function(String url) isPlayingForUrl;
  final Stream<PlayerState>? playerStateStream;
  final Future<void> Function(String url, {Map<String, String>? headers})?
  onTogglePlayAudio;
}

class MemoDetailScreen extends ConsumerStatefulWidget {
  const MemoDetailScreen({
    super.key,
    required this.initialMemo,
    this.readOnly = false,
    this.supportsMemoEngagement = true,
    this.richContentEnabled = true,
    this.heroTag,
    this.embedded = false,
    this.embeddedHeader,
    this.showDocumentMetadata = true,
    this.showSupplementarySections = true,
    this.scrollController,
    this.onRequestEditExisting,
  });

  final LocalMemo initialMemo;
  final bool readOnly;
  final bool supportsMemoEngagement;
  final bool richContentEnabled;
  final Object? heroTag;
  final bool embedded;
  final Widget? embeddedHeader;
  final bool showDocumentMetadata;
  final bool showSupplementarySections;
  final ScrollController? scrollController;
  final Future<void> Function(LocalMemo memo)? onRequestEditExisting;

  @override
  ConsumerState<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends ConsumerState<MemoDetailScreen> {
  final _player = AudioPlayer();
  final _ownedScrollController = ScrollController();

  LocalMemo? _memo;
  String? _currentAudioUrl;
  Animation<double>? _routeAnimation;
  bool _routeSettled = false;
  MemoDocumentResolvedData? _resolvedData;
  String? _preparedDeferredContentKey;
  String? _pendingDeferredContentKey;

  Object get _heroTag =>
      widget.heroTag ?? memoHeroTagForMemo(_memo ?? widget.initialMemo);

  ScrollController get _scrollController =>
      widget.scrollController ?? _ownedScrollController;

  bool get _includeReminderAction => resolveIosMobileFeatureReadiness(
    featureId: IosMobileFeatureId.memoReminders,
  ).canRun;

  @override
  void initState() {
    super.initState();
    _memo = widget.initialMemo;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (!identical(_routeAnimation, routeAnimation)) {
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatusChanged);
      _routeAnimation = routeAnimation;
      _routeAnimation?.addStatusListener(_handleRouteAnimationStatusChanged);
    }
    _routeSettled =
        routeAnimation == null ||
        routeAnimation.status == AnimationStatus.completed;
  }

  @override
  void didUpdateWidget(covariant MemoDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final memoChanged =
        oldWidget.initialMemo.uid != widget.initialMemo.uid ||
        oldWidget.initialMemo.contentFingerprint !=
            widget.initialMemo.contentFingerprint ||
        oldWidget.initialMemo.updateTime != widget.initialMemo.updateTime;
    if (memoChanged) {
      setState(() => _setMemo(widget.initialMemo));
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatusChanged);
    _ownedScrollController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _handleRouteAnimationStatusChanged(AnimationStatus status) {
    final settled = status == AnimationStatus.completed;
    if (_routeSettled == settled) return;
    if (!mounted) {
      _routeSettled = settled;
      return;
    }
    setState(() {
      _routeSettled = settled;
      if (!settled) {
        _pendingDeferredContentKey = null;
      }
    });
  }

  void _setMemo(LocalMemo memo) {
    _memo = memo;
    _currentAudioUrl = null;
    _resolvedData = null;
    _preparedDeferredContentKey = null;
    _pendingDeferredContentKey = null;
  }

  String _buildDeferredContentKey({
    required LocalMemo memo,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
    required TagRecognitionPolicy tagRecognitionPolicy,
  }) {
    return '${memo.uid}|'
        '${memo.contentFingerprint}|'
        '${memo.updateTime.microsecondsSinceEpoch}|'
        '${memo.attachments.length}|'
        '${baseUrl?.toString() ?? ''}|'
        '${authHeader ?? ''}|'
        '${rebaseAbsoluteFileUrlForV024 ? 1 : 0}|'
        '${attachAuthForSameOriginAbsolute ? 1 : 0}|'
        '${tagRecognitionPolicy.cacheToken}';
  }

  MemoDocumentResolvedData _buildDeferredDetailContent({
    required LocalMemo memo,
    required AppLanguage appLanguage,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
    required TagRecognitionPolicy tagRecognitionPolicy,
  }) {
    return buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: appLanguage,
      clipCard: ref.read(memoClipCardByUidProvider(memo.uid)),
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
      richContentEnabled: widget.richContentEnabled,
      tagRecognitionPolicy: tagRecognitionPolicy,
    );
  }

  void _scheduleDeferredDetailContentPreparation({
    required LocalMemo memo,
    required AppLanguage appLanguage,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
    required TagRecognitionPolicy tagRecognitionPolicy,
  }) {
    if (!_routeSettled) return;
    final key = _buildDeferredContentKey(
      memo: memo,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
      tagRecognitionPolicy: tagRecognitionPolicy,
    );
    if (_preparedDeferredContentKey == key) return;
    if (_pendingDeferredContentKey == key) return;
    _pendingDeferredContentKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_routeSettled) return;
      if (_pendingDeferredContentKey != key) return;
      final content = _buildDeferredDetailContent(
        memo: memo,
        appLanguage: appLanguage,
        baseUrl: baseUrl,
        authHeader: authHeader,
        rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
        attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        tagRecognitionPolicy: tagRecognitionPolicy,
      );
      if (!mounted || _pendingDeferredContentKey != key) return;
      setState(() {
        _pendingDeferredContentKey = null;
        _preparedDeferredContentKey = key;
        _resolvedData = content;
      });
    });
  }

  Future<void> _reload() async {
    final uid = _memo?.uid ?? widget.initialMemo.uid;
    final memo = await ref
        .read(memoDetailControllerProvider)
        .loadMemoByUid(uid);
    if (memo == null) return;
    if (!mounted) return;
    setState(() => _setMemo(memo));
  }

  bool _isArchivedMemo() {
    return (_memo?.state ?? widget.initialMemo.state) == 'ARCHIVED';
  }

  Future<void> _togglePinned() async {
    if (widget.readOnly || _isArchivedMemo()) return;
    final memo = _memo;
    if (memo == null) return;
    await _updateLocalAndEnqueue(memo: memo, pinned: !memo.pinned);
    await _reload();
  }

  Future<void> _copyMemoContent() async {
    final memo = _memo;
    if (memo == null) return;
    await Clipboard.setData(ClipboardData(text: memo.content));
    if (!mounted) return;
    showTopToast(
      context,
      context.t.strings.legacy.msg_memo_copied,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _openMemoReminder() async {
    if (widget.readOnly || _isArchivedMemo()) return;
    final memo = _memo;
    if (memo == null) return;
    final readiness = resolveIosMobileFeatureReadiness(
      featureId: IosMobileFeatureId.memoReminders,
    );
    if (!readiness.canRun) {
      final message =
          readiness.manualFallbackDescription ??
          readiness.nativeRequirement ??
          context.t.strings.legacy.msg_reminder;
      showTopToast(context, message);
      return;
    }
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoReminderEditorScreen(memo: memo),
      ),
    );
  }

  Future<void> _openAddToCollection() async {
    if (widget.readOnly || _isArchivedMemo()) return;
    final memo = _memo;
    if (memo == null) return;
    await showAddMemoToCollectionSheet(context: context, ref: ref, memo: memo);
  }

  Future<void> _toggleArchived() async {
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;
    final wasArchived = memo.state == 'ARCHIVED';
    final next = wasArchived ? 'NORMAL' : 'ARCHIVED';
    try {
      await _updateLocalAndEnqueue(memo: memo, state: next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_action_failed(e: e)),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (wasArchived) {
      final message = context.t.strings.legacy.msg_restored;
      Navigator.of(context).pushAndRemoveUntil(
        buildPlatformPageRoute<void>(
          context: context,
          builder: (_) => MemosListScreen(
            title: 'MemoFlow',
            state: 'NORMAL',
            showDrawer: true,
            enableCompose: true,
            toastMessage: message,
          ),
        ),
        (route) => false,
      );
    } else {
      context.safePop();
    }
  }

  Future<void> _handleDetailAction(MemoCardAction action) async {
    switch (action) {
      case MemoCardAction.copy:
        await _copyMemoContent();
        return;
      case MemoCardAction.togglePinned:
        await _togglePinned();
        return;
      case MemoCardAction.edit:
        await _edit();
        return;
      case MemoCardAction.adjustTime:
        await _adjustMemoTime();
        return;
      case MemoCardAction.history:
        await _openVersionHistory();
        return;
      case MemoCardAction.reminder:
        await _openMemoReminder();
        return;
      case MemoCardAction.addToCollection:
        await _openAddToCollection();
        return;
      case MemoCardAction.archive:
      case MemoCardAction.restore:
        await _toggleArchived();
        return;
      case MemoCardAction.delete:
        await _delete();
        return;
    }
  }

  Future<void> _showDetailActionMenu(LongPressStartDetails details) async {
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;
    final action = await showMemoDetailActionPopover(
      context: context,
      memo: memo,
      readOnly: widget.readOnly,
      globalPosition: details.globalPosition,
      includeReminder: _includeReminderAction,
    );
    if (!mounted || action == null) return;
    await _handleDetailAction(action);
  }

  Future<void> _showDetailActionMenuFromPosition(Offset globalPosition) async {
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;
    final action = await showMemoDetailActionPopover(
      context: context,
      memo: memo,
      readOnly: widget.readOnly,
      globalPosition: globalPosition,
      includeReminder: _includeReminderAction,
    );
    if (!mounted || action == null) return;
    await _handleDetailAction(action);
  }

  Future<void> _showDetailActionMenuFromAnchor(
    BuildContext anchorContext,
  ) async {
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;
    final action = await showMemoDetailActionPopover(
      context: context,
      memo: memo,
      readOnly: widget.readOnly,
      anchorContext: anchorContext,
      includeReminder: _includeReminderAction,
    );
    if (!mounted || action == null) return;
    await _handleDetailAction(action);
  }

  Future<void> _edit() async {
    if (widget.readOnly || _isArchivedMemo()) return;
    final memo = _memo;
    if (memo == null) return;
    final onRequestEditExisting = widget.onRequestEditExisting;
    if (onRequestEditExisting != null) {
      await onRequestEditExisting(memo);
      ref.invalidate(memoRelationsProvider(memo.uid));
      await _reload();
      return;
    }
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoEditorScreen(existing: memo),
      ),
    );
    ref.invalidate(memoRelationsProvider(memo.uid));
    await _reload();
  }

  Future<void> _adjustMemoTime() async {
    if (widget.readOnly || _isArchivedMemo()) return;
    final memo = _memo;
    if (memo == null) return;
    final selectedTime = await showMemoTimeAdjustmentSheet(
      context: context,
      memo: memo,
    );
    if (!mounted || selectedTime == null) return;
    try {
      await ref
          .read(memoDetailControllerProvider)
          .adjustMemoTime(memo: memo, selectedTime: selectedTime);
      unawaited(
        ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            ),
      );
      if (!mounted) return;
      showTopToast(context, memoTimeAdjustmentSavedLabel(context));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.memoTimeAdjustment.failed(error: e)),
        ),
      );
    }
  }

  Future<void> _openVersionHistory() async {
    final memo = _memo;
    if (memo == null) return;
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoVersionsScreen(memoUid: memo.uid),
      ),
    );
    await _reload();
  }

  Future<void> _delete() async {
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;

    final confirmed =
        await showPlatformAlertDialog<bool>(
          context: context,
          title: context.t.strings.legacy.msg_delete_memo,
          message: context
              .t
              .strings
              .legacy
              .msg_removed_locally_now_deleted_server_when,
          actions: [
            PlatformDialogAction<bool>(
              value: false,
              label: context.t.strings.legacy.msg_cancel_2,
            ),
            PlatformDialogAction<bool>(
              value: true,
              label: context.t.strings.legacy.msg_delete,
              isDefault: true,
              isDestructive: true,
            ),
          ],
        ) ??
        false;
    if (!confirmed) return;

    final controller = ref.read(memoDetailControllerProvider);
    try {
      await controller.deleteMemo(memo);
      unawaited(
        ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_delete_failed(e: e)),
        ),
      );
      return;
    }

    if (!mounted) return;
    context.safePop();
  }

  Future<void> _updateLocalAndEnqueue({
    required LocalMemo memo,
    bool? pinned,
    String? state,
  }) async {
    await ref
        .read(memoDetailControllerProvider)
        .updateLocalAndEnqueue(memo: memo, pinned: pinned, state: state);
    unawaited(
      ref
          .read(syncCoordinatorProvider.notifier)
          .requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.manual,
            ),
          ),
    );
  }

  Future<void> _toggleTask(
    TaskToggleRequest request, {
    required bool skipReferenceLines,
  }) async {
    final memo = _memo;
    if (memo == null) return;
    if (_isArchivedMemo()) return;
    final updated = const MemoTaskListService().toggle(
      memo.content,
      request.taskIndex,
      options: TaskListOptions(
        skipQuotedLines: skipReferenceLines,
        includeOrderedMarkers: true,
      ),
    );
    if (updated == memo.content) return;

    final updateTime = memo.updateTime;
    final tagRecognitionPolicy = ref
        .read(currentWorkspacePreferencesProvider)
        .tagRecognitionPolicy;
    final tags = extractTags(updated, policy: tagRecognitionPolicy);

    try {
      await ref
          .read(memoDetailControllerProvider)
          .updateMemoContentForTaskToggle(
            memo: memo,
            content: updated,
            updateTime: updateTime,
            tags: tags,
          );

      if (!mounted) return;
      setState(() {
        _setMemo(
          LocalMemo(
            uid: memo.uid,
            content: updated,
            contentFingerprint: computeContentFingerprint(updated),
            visibility: memo.visibility,
            pinned: memo.pinned,
            state: memo.state,
            createTime: memo.createTime,
            updateTime: updateTime,
            tags: tags,
            attachments: memo.attachments,
            relationCount: memo.relationCount,
            location: memo.location,
            syncState: SyncState.pending,
            lastError: null,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_update_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _replaceMemoAttachment(EditedImageResult result) async {
    final memo = _memo;
    if (memo == null) return;
    final index = memo.attachments.indexWhere(
      (a) => a.name == result.sourceId || a.uid == result.sourceId,
    );
    if (index < 0) return;
    final oldAttachment = memo.attachments[index];
    final newUid = generateUid();
    final newAttachment = Attachment(
      name: 'attachments/$newUid',
      filename: result.filename,
      type: result.mimeType,
      size: result.size,
      externalLink: Uri.file(result.filePath).toString(),
    );
    final updatedAttachments = [...memo.attachments];
    updatedAttachments[index] = newAttachment;

    final controller = ref.read(memoDetailControllerProvider);
    try {
      final now = DateTime.now();
      await controller.replaceMemoAttachment(
        memo: memo,
        oldAttachment: oldAttachment,
        updatedAttachments: updatedAttachments,
        index: index,
        newUid: newUid,
        filePath: result.filePath,
        filename: result.filename,
        mimeType: result.mimeType,
        size: result.size,
        now: now,
      );

      unawaited(
        ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            ),
      );

      if (!mounted) return;
      setState(() {
        _setMemo(
          LocalMemo(
            uid: memo.uid,
            content: memo.content,
            contentFingerprint: memo.contentFingerprint,
            visibility: memo.visibility,
            pinned: memo.pinned,
            state: memo.state,
            createTime: memo.createTime,
            updateTime: now,
            tags: memo.tags,
            attachments: updatedAttachments,
            relationCount: memo.relationCount,
            location: memo.location,
            syncState: SyncState.pending,
            lastError: null,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
        ),
      );
    }
  }

  Future<void> _togglePlayAudio(
    String url, {
    Map<String, String>? headers,
  }) async {
    if (_currentAudioUrl == url) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    setState(() => _currentAudioUrl = url);
    try {
      await _player.setUrl(url, headers: headers);
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_playback_failed_2(e: e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final memo = _memo;
    final appLanguage = context.appLanguage;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((prefs) => prefs.hapticsEnabled),
    );
    final collapseReferences = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (prefs) => prefs.collapseReferences,
      ),
    );
    final tagRecognitionPolicy = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (prefs) => prefs.tagRecognitionPolicy,
      ),
    );
    final effectiveShowMemoEngagement = ref.watch(
      resolvedAppSettingsProvider.select(
        (settings) => settings.effectiveShowMemoEngagement,
      ),
    );
    final shouldShowEngagement =
        widget.supportsMemoEngagement && effectiveShowMemoEngagement;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    void maybeHaptic() {
      if (!hapticsEnabled) return;
      HapticFeedback.selectionClick();
    }

    if (memo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isArchived = memo.state == 'ARCHIVED';
    final canEditAttachments = !widget.readOnly && !isArchived;
    final onDoubleTapEdit = widget.readOnly || isArchived
        ? null
        : () {
            maybeHaptic();
            unawaited(_edit());
          };
    final richContentEnabled = widget.richContentEnabled;
    final deferredContentKey = _buildDeferredContentKey(
      memo: memo,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
      tagRecognitionPolicy: tagRecognitionPolicy,
    );
    if (_routeSettled && richContentEnabled) {
      _scheduleDeferredDetailContentPreparation(
        memo: memo,
        appLanguage: appLanguage,
        baseUrl: baseUrl,
        authHeader: authHeader,
        rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
        attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        tagRecognitionPolicy: tagRecognitionPolicy,
      );
    }
    final deferredContent =
        richContentEnabled && _preparedDeferredContentKey == deferredContentKey
        ? _resolvedData
        : null;
    final immediateResolvedData = buildMemoDocumentResolvedData(
      memo: memo,
      appLanguage: appLanguage,
      clipCard: ref.watch(memoClipCardByUidProvider(memo.uid)),
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
      richContentEnabled: richContentEnabled && _routeSettled,
      tagRecognitionPolicy: tagRecognitionPolicy,
    );
    final resolvedData = deferredContent ?? immediateResolvedData;
    final canToggleTasks = !widget.readOnly && !isArchived;
    final header = MemoDocumentPrimaryContent(
      resolvedData: resolvedData,
      readOnly: widget.readOnly,
      isArchived: isArchived,
      hapticsEnabled: hapticsEnabled,
      markdownSelectable: _routeSettled,
      showMetadata: widget.showDocumentMetadata,
      onDoubleTapEdit: onDoubleTapEdit,
      onTimeTap: widget.readOnly || isArchived ? null : _adjustMemoTime,
      onReplaceAttachment: canEditAttachments ? _replaceMemoAttachment : null,
      onToggleTask: canToggleTasks
          ? (request) {
              maybeHaptic();
              unawaited(
                _toggleTask(request, skipReferenceLines: collapseReferences),
              );
            }
          : null,
    );

    final detailContent = MemoDocumentBody(
      resolvedData: resolvedData,
      header: header,
      scrollController: _scrollController,
      showSupplementarySections:
          widget.showSupplementarySections && _routeSettled,
      shouldShowEngagement: shouldShowEngagement,
      boundDesktopReadWidth: !widget.embedded,
      onLongPressStart: widget.readOnly
          ? null
          : (details) {
              maybeHaptic();
              unawaited(_showDetailActionMenu(details));
            },
      onSecondaryTapDown: widget.readOnly
          ? null
          : (details) {
              maybeHaptic();
              unawaited(
                _showDetailActionMenuFromPosition(details.globalPosition),
              );
            },
      audioHandle: MemoDocumentAudioHandle(
        isPlayingForUrl: (url) => _player.playing && _currentAudioUrl == url,
        playerStateStream: _player.playerStateStream,
        onTogglePlayAudio: _togglePlayAudio,
      ),
    );

    final target = resolvePlatformTarget(context);
    final usePlatformActionMenu =
        target == PlatformTarget.iPhone ||
        target == PlatformTarget.iPad ||
        target == PlatformTarget.macOS;
    final detailActions = widget.readOnly
        ? null
        : usePlatformActionMenu
        ? [
            Builder(
              builder: (buttonContext) => IconButton(
                key: memoDetailActionMenuRegionKey,
                tooltip: context.t.strings.legacy.msg_more,
                onPressed: () {
                  maybeHaptic();
                  unawaited(_showDetailActionMenuFromAnchor(buttonContext));
                },
                icon: Icon(PlatformIcons.more),
              ),
            ),
          ]
        : [
            if (!isArchived)
              IconButton(
                tooltip: context.t.strings.legacy.msg_edit,
                onPressed: () {
                  maybeHaptic();
                  unawaited(_edit());
                },
                icon: const Icon(Icons.edit),
              ),
            IconButton(
              tooltip: context.t.strings.settings.preferences.history,
              onPressed: () {
                maybeHaptic();
                unawaited(_openVersionHistory());
              },
              icon: const Icon(Icons.history),
            ),
            if (!isArchived)
              IconButton(
                tooltip: memo.pinned
                    ? context.t.strings.legacy.msg_unpin
                    : context.t.strings.legacy.msg_pin,
                onPressed: () {
                  maybeHaptic();
                  unawaited(_togglePinned());
                },
                icon: Icon(
                  memo.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
              ),
            if (!isArchived)
              IconButton(
                tooltip: context.t.strings.collections.addToCollection,
                onPressed: () {
                  maybeHaptic();
                  unawaited(_openAddToCollection());
                },
                icon: const Icon(Icons.library_add_rounded),
              ),
            IconButton(
              tooltip: isArchived
                  ? context.t.strings.legacy.msg_restore
                  : context.t.strings.legacy.msg_archive,
              onPressed: () {
                maybeHaptic();
                unawaited(_toggleArchived());
              },
              icon: Icon(isArchived ? Icons.unarchive : Icons.archive),
            ),
            IconButton(
              tooltip: context.t.strings.legacy.msg_delete,
              onPressed: () {
                maybeHaptic();
                unawaited(_delete());
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ];

    return MemoDetailView(
      backgroundColor: cardColor,
      embedded: widget.embedded,
      embeddedHeader: widget.embeddedHeader,
      title: Text(
        isArchived
            ? context.t.strings.legacy.msg_archived
            : context.t.strings.legacy.msg_memo,
      ),
      actions: detailActions,
      backgroundChild: Hero(
        tag: _heroTag,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        flightShuttleBuilder: memoHeroFlightShuttleBuilder(
          isPinned: memo.pinned,
        ),
        child: RepaintBoundary(child: Container(color: cardColor)),
      ),
      child: detailContent,
    );
  }
}

class MemoDocumentBody extends StatelessWidget {
  const MemoDocumentBody({
    super.key,
    required this.scrollController,
    required this.header,
    required this.showSupplementarySections,
    required this.shouldShowEngagement,
    required this.resolvedData,
    this.audioHandle,
    this.onLongPressStart,
    this.onSecondaryTapDown,
    this.boundDesktopReadWidth = false,
  });

  final ScrollController scrollController;
  final Widget header;
  final bool showSupplementarySections;
  final bool shouldShowEngagement;
  final MemoDocumentResolvedData resolvedData;
  final MemoDocumentAudioHandle? audioHandle;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool boundDesktopReadWidth;

  @override
  Widget build(BuildContext context) {
    final memo = resolvedData.memo;
    final nonImageAttachments = resolvedData.nonImageAttachments;
    final baseUrl = resolvedData.baseUrl;
    final authHeader = resolvedData.authHeader;
    String resolveAttachmentUrl(
      Uri baseUrl,
      Attachment attachment, {
      required bool thumbnail,
    }) {
      final external = attachment.externalLink.trim();
      if (external.isNotEmpty) {
        final isRelative = !isAbsoluteUrl(external);
        final resolved = resolveMaybeRelativeUrl(baseUrl, external);
        return (thumbnail && isRelative)
            ? appendThumbnailParam(resolved)
            : resolved;
      }
      final url = joinBaseUrl(
        baseUrl,
        'file/${attachment.name}/${attachment.filename}',
      );
      return thumbnail ? appendThumbnailParam(url) : url;
    }

    final document = _MemoDocumentReadWidth(
      enabled: boundDesktopReadWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (showSupplementarySections && shouldShowEngagement)
            MemoEngagementSurface(
              memoUid: memo.uid,
              memoVisibility: memo.visibility,
            ),
          if (showSupplementarySections)
            _MemoRelationsSection(memoUid: memo.uid),
          if (showSupplementarySections && nonImageAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.t.strings.legacy.msg_attachments,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final attachment in nonImageAttachments)
                  Builder(
                    builder: (context) {
                      final isAudio = attachment.type.startsWith('audio');
                      final fullUrl = (baseUrl == null)
                          ? ''
                          : resolveAttachmentUrl(
                              baseUrl,
                              attachment,
                              thumbnail: false,
                            );

                      if (isAudio && baseUrl != null && fullUrl.isNotEmpty) {
                        final handle = audioHandle;
                        final stream = handle?.playerStateStream;
                        final togglePlayAudio = handle?.onTogglePlayAudio;
                        if (stream == null) {
                          return ListTile(
                            leading: const Icon(Icons.play_arrow),
                            title: Text(attachment.filename),
                            subtitle: Text(attachment.type),
                            onTap: togglePlayAudio == null
                                ? null
                                : () => togglePlayAudio(
                                    fullUrl,
                                    headers: authHeader == null
                                        ? null
                                        : {'Authorization': authHeader},
                                  ),
                          );
                        }
                        return StreamBuilder<PlayerState>(
                          stream: stream,
                          builder: (context, snap) {
                            final playing =
                                handle?.isPlayingForUrl(fullUrl) ?? false;
                            return ListTile(
                              leading: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                              ),
                              title: Text(attachment.filename),
                              subtitle: Text(attachment.type),
                              onTap: togglePlayAudio == null
                                  ? null
                                  : () => togglePlayAudio(
                                      fullUrl,
                                      headers: authHeader == null
                                          ? null
                                          : {'Authorization': authHeader},
                                    ),
                            );
                          },
                        );
                      }

                      return ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(attachment.filename),
                        subtitle: Text(attachment.type),
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    final body = ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [document],
    );
    if (onLongPressStart == null && onSecondaryTapDown == null) return body;
    return GestureDetector(
      key: memoDetailActionMenuRegionKey,
      behavior: HitTestBehavior.translucent,
      onLongPressStart: onLongPressStart,
      onSecondaryTapDown: onSecondaryTapDown,
      child: body,
    );
  }
}

class _MemoDocumentReadWidth extends StatelessWidget {
  const _MemoDocumentReadWidth({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final target = resolvePlatformTarget(context);
    final isDesktop =
        target == PlatformTarget.macOS ||
        target == PlatformTarget.windows ||
        target == PlatformTarget.linux;
    if (!isDesktop) return child;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        key: memoDetailBoundedDocumentKey,
        constraints: const BoxConstraints(
          maxWidth: _memoDetailDesktopMaxReadWidth,
        ),
        child: child,
      ),
    );
  }
}

class MemoDocumentPrimaryContent extends ConsumerWidget {
  const MemoDocumentPrimaryContent({
    super.key,
    required this.resolvedData,
    this.readOnly = true,
    this.isArchived = false,
    this.hapticsEnabled = false,
    this.markdownSelectable = true,
    this.showMetadata = true,
    this.mediaMaxHeightFactor = 0.4,
    this.onDoubleTapEdit,
    this.onTimeTap,
    this.onToggleTask,
    this.onReplaceAttachment,
  });

  final MemoDocumentResolvedData resolvedData;
  final bool readOnly;
  final bool isArchived;
  final bool hapticsEnabled;
  final bool markdownSelectable;
  final bool showMetadata;
  final double mediaMaxHeightFactor;
  final VoidCallback? onDoubleTapEdit;
  final VoidCallback? onTimeTap;
  final TaskToggleHandler? onToggleTask;
  final Future<void> Function(EditedImageResult result)? onReplaceAttachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memo = resolvedData.memo;
    final clipCard = resolvedData.clipCard;
    final clipParts = resolvedData.clipParts;
    final imageEntries = resolvedData.imageEntries;
    final mediaEntries = resolvedData.mediaEntries;
    final collapseLongContent = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (prefs) => prefs.collapseLongContent,
      ),
    );
    final contentStyle = Theme.of(context).textTheme.bodyLarge;
    final canEditAttachments = !readOnly && !isArchived;
    final allowImageEdit =
        resolvedData.richContentEnabled &&
        canEditAttachments &&
        onReplaceAttachment != null &&
        imageEntries.any((entry) => entry.isAttachment) &&
        !imageEntries.any((entry) => !entry.isAttachment);
    final tagColors = ref.watch(tagColorLookupProvider);

    final contentWidget = _CollapsibleText(
      text: resolvedData.displayContentText,
      collapseEnabled: collapseLongContent,
      initiallyExpanded: true,
      style: contentStyle,
      hapticsEnabled: hapticsEnabled,
      markdownCacheKey: resolvedData.markdownCacheKey,
      markdownArtifact: resolvedData.markdownArtifact,
      markdownSelectable: markdownSelectable && resolvedData.richContentEnabled,
      renderImages: resolvedData.effectiveRenderInlineImages,
      imageSyntax: resolvedData.inlineImageSyntax,
      tagRecognitionPolicy: resolvedData.tagRecognitionPolicy,
      baseUrl: resolvedData.baseUrl,
      authHeader: resolvedData.authHeader,
      rebaseAbsoluteFileUrlForV024: resolvedData.rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute:
          resolvedData.attachAuthForSameOriginAbsolute,
      tagColors: tagColors,
      imagePreviewItems: resolvedData.imagePreviewItems,
      allowedLocalImageUrls:
          resolvedData.inlineImageSourcePolicy.allowedLocalImageUrls,
      onOpenImagePreview: (request) =>
          ImagePreviewLauncher.open(context, request),
      onToggleTask: onToggleTask,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (clipCard != null) ...[
          MemoClipReadonlyHeader(
            metadata: clipCard,
            title: clipParts?.title,
            showRemoteImages: resolvedData.richContentEnabled,
            onSourceTap: clipCard.sourceUrl.trim().isEmpty
                ? null
                : () async {
                    final uri = Uri.tryParse(clipCard.sourceUrl.trim());
                    if (uri == null) return;
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
          ),
          const SizedBox(height: 16),
        ],
        MemoReaderContent(
          memo: memo,
          padding: EdgeInsets.zero,
          contentTextStyle: contentStyle,
          metaTextStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          showMetadata: showMetadata,
          mediaMaxHeightFactor: mediaMaxHeightFactor,
          mediaMaxCount: 9,
          contentOverride: contentWidget,
          mediaEntriesOverride: mediaEntries,
          nonMediaAttachmentsOverride: resolvedData.nonImageAttachments,
          showAttachmentsSection: false,
          onTimeTap: onTimeTap,
          onReplaceAttachment: allowImageEdit ? onReplaceAttachment : null,
        ),
        if (mediaEntries.isNotEmpty) const SizedBox(height: 12),
        if (resolvedData.memoErrorText != null &&
            resolvedData.memoErrorText!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  resolvedData.memoErrorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        unawaited(
                          ref
                              .read(syncCoordinatorProvider.notifier)
                              .requestSync(
                                const SyncRequest(
                                  kind: SyncRequestKind.memos,
                                  reason: SyncRequestReason.manual,
                                ),
                              ),
                        );
                        showTopToast(
                          context,
                          context.t.strings.legacy.msg_retry_started,
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(context.t.strings.legacy.msg_retry_sync),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: resolvedData.memoErrorText!),
                        );
                        if (!context.mounted) return;
                        showTopToast(
                          context,
                          context.t.strings.legacy.msg_error_copied,
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(context.t.strings.legacy.msg_copy),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return PointerDoubleTapListener(
      key: const ValueKey('memo-detail-edit-hit-area'),
      behavior: HitTestBehavior.translucent,
      onDoubleTap: onDoubleTapEdit,
      child: content,
    );
  }
}

class _MemoRelationsSection extends ConsumerWidget {
  const _MemoRelationsSection({required this.memoUid});

  final String memoUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationsAsync = ref.watch(memoRelationsProvider(memoUid));
    return relationsAsync.when(
      data: (relations) {
        if (relations.isEmpty) return const SizedBox.shrink();

        final currentName = 'memos/$memoUid';
        final referencing = <_RelationLinkItem>[];
        final referencedBy = <_RelationLinkItem>[];
        final seenReferencing = <String>{};
        final seenReferencedBy = <String>{};

        for (final relation in relations) {
          final type = relation.type.trim().toUpperCase();
          if (type != 'REFERENCE') {
            continue;
          }
          final memoName = relation.memo.name.trim();
          final relatedName = relation.relatedMemo.name.trim();

          if (memoName == currentName && relatedName.isNotEmpty) {
            if (seenReferencing.add(relatedName)) {
              referencing.add(
                _RelationLinkItem(
                  name: relatedName,
                  snippet: relation.relatedMemo.snippet,
                ),
              );
            }
            continue;
          }
          if (relatedName == currentName && memoName.isNotEmpty) {
            if (seenReferencedBy.add(memoName)) {
              referencedBy.add(
                _RelationLinkItem(
                  name: memoName,
                  snippet: relation.memo.snippet,
                ),
              );
            }
          }
        }

        if (referencing.isEmpty && referencedBy.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final borderColor = isDark
            ? MemoFlowPalette.borderDark
            : MemoFlowPalette.borderLight;
        final bg = isDark
            ? MemoFlowPalette.audioSurfaceDark
            : MemoFlowPalette.audioSurfaceLight;
        final textMain = isDark
            ? MemoFlowPalette.textDark
            : MemoFlowPalette.textLight;
        final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
        final chipBg = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06);
        final total = referencing.length + referencedBy.length;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, size: 16, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    context.t.strings.legacy.msg_links,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (referencing.isNotEmpty)
                _RelationGroup(
                  title: context.t.strings.legacy.msg_references,
                  items: referencing,
                  isDark: isDark,
                  borderColor: borderColor,
                  bg: bg,
                  textMain: textMain,
                  textMuted: textMuted,
                  chipBg: chipBg,
                  onTap: (item) => _openMemo(context, ref, item.name),
                ),
              if (referencing.isNotEmpty && referencedBy.isNotEmpty)
                const SizedBox(height: 10),
              if (referencedBy.isNotEmpty)
                _RelationGroup(
                  title: context.t.strings.legacy.msg_referenced,
                  items: referencedBy,
                  isDark: isDark,
                  borderColor: borderColor,
                  bg: bg,
                  textMain: textMain,
                  textMuted: textMuted,
                  chipBg: chipBg,
                  onTap: (item) => _openMemo(context, ref, item.name),
                ),
            ],
          ),
        );
      },
      loading: () => _buildLoading(context),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final bg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 14, color: textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.t.strings.legacy.msg_loading_links,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMemo(
    BuildContext context,
    WidgetRef ref,
    String rawName,
  ) async {
    final uid = _normalizeMemoUid(rawName);
    if (uid.isEmpty || uid == memoUid) return;

    LocalMemo? memo;
    try {
      memo = await ref
          .read(memoDetailControllerProvider)
          .resolveMemoForOpen(uid: uid);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_load_4(e: e)),
        ),
      );
      return;
    }

    if (memo == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_memo_not_found_locally),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoDetailScreen(initialMemo: memo!),
      ),
    );
  }

  String _normalizeMemoUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('memos/')) return trimmed.substring('memos/'.length);
    return trimmed;
  }
}

class _RelationLinkItem {
  const _RelationLinkItem({required this.name, required this.snippet});

  final String name;
  final String snippet;
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({
    required this.title,
    required this.items,
    required this.isDark,
    required this.borderColor,
    required this.bg,
    required this.textMain,
    required this.textMuted,
    required this.chipBg,
    required this.onTap,
  });

  final String title;
  final List<_RelationLinkItem> items;
  final bool isDark;
  final Color borderColor;
  final Color bg;
  final Color textMain;
  final Color textMuted;
  final Color chipBg;
  final ValueChanged<_RelationLinkItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 14, color: textMuted),
              const SizedBox(width: 6),
              Text(
                '$title (${items.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _shortMemoId(item.name),
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _relationSnippet(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: textMain),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, size: 16, color: textMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _relationSnippet(_RelationLinkItem item) {
    final snippet = item.snippet.trim();
    if (snippet.isNotEmpty) return snippet;
    final name = item.name.trim();
    if (name.isNotEmpty) return name;
    return '';
  }

  static String _shortMemoId(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '--';
    final raw = trimmed.startsWith('memos/')
        ? trimmed.substring('memos/'.length)
        : trimmed;
    return raw.length <= 6 ? raw : raw.substring(0, 6);
  }
}

class _CollapsibleText extends StatefulWidget {
  const _CollapsibleText({
    required this.text,
    required this.collapseEnabled,
    required this.style,
    required this.hapticsEnabled,
    this.initiallyExpanded = false,
    this.markdownCacheKey,
    this.markdownArtifact,
    this.markdownSelectable = true,
    this.renderImages = false,
    this.tagRecognitionPolicy = TagRecognitionPolicy.defaultPolicy,
    this.imageSyntax,
    this.baseUrl,
    this.authHeader,
    this.rebaseAbsoluteFileUrlForV024 = false,
    this.attachAuthForSameOriginAbsolute = false,
    this.tagColors,
    this.imagePreviewItems,
    this.allowedLocalImageUrls = const <String>{},
    this.onOpenImagePreview,
    this.onToggleTask,
  });

  final String text;
  final bool collapseEnabled;
  final TextStyle? style;
  final bool hapticsEnabled;
  final bool initiallyExpanded;
  final String? markdownCacheKey;
  final MemoRenderArtifact? markdownArtifact;
  final bool markdownSelectable;
  final bool renderImages;
  final TagRecognitionPolicy tagRecognitionPolicy;
  final MemoInlineImageSyntax? imageSyntax;
  final Uri? baseUrl;
  final String? authHeader;
  final bool rebaseAbsoluteFileUrlForV024;
  final bool attachAuthForSameOriginAbsolute;
  final TagColorLookup? tagColors;
  final List<ImagePreviewItem>? imagePreviewItems;
  final Set<String> allowedLocalImageUrls;
  final Future<void> Function(ImagePreviewOpenRequest request)?
  onOpenImagePreview;
  final ValueChanged<TaskToggleRequest>? onToggleTask;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _collapsedLines = 14;
  static const _collapsedRunes = 420;

  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  bool _isLong(String text) {
    final lines = text.split('\n');
    if (lines.length > _collapsedLines) return true;
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    return compact.runes.length > _collapsedRunes;
  }

  String _collapseText(String text) {
    var result = text;
    var truncated = false;
    final lines = result.split('\n');
    if (lines.length > _collapsedLines) {
      result = lines.take(_collapsedLines).join('\n');
      truncated = true;
    }

    final compact = result.replaceAll(RegExp(r'\s+'), '');
    if (compact.runes.length > _collapsedRunes) {
      result = String.fromCharCodes(result.runes.take(_collapsedRunes));
      truncated = true;
    }

    if (truncated) {
      result = result.trimRight();
      result = result.endsWith('...') ? result : '$result...';
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final text = stripTaskListToggleHint(widget.text).trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final shouldCollapse = widget.collapseEnabled && _isLong(text);
    final showCollapsed = shouldCollapse && !_expanded;
    final displayText = showCollapsed ? _collapseText(text) : text;
    final effectiveImageSyntax = showCollapsed
        ? MemoInlineImageSyntax.none
        : resolveMemoInlineImageSyntax(
            renderImages: widget.renderImages,
            imageSyntax: widget.imageSyntax,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemoMarkdown(
          cacheKey: widget.markdownCacheKey,
          artifact: showCollapsed ? null : widget.markdownArtifact,
          data: displayText,
          textStyle: widget.style,
          selectable: widget.markdownSelectable && !showCollapsed,
          blockSpacing: 8,
          renderImages: effectiveImageSyntax.rendersImages,
          tagRecognitionPolicy: widget.tagRecognitionPolicy,
          imageSyntax: effectiveImageSyntax,
          baseUrl: widget.baseUrl,
          authHeader: widget.authHeader,
          rebaseAbsoluteFileUrlForV024: widget.rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute:
              widget.attachAuthForSameOriginAbsolute,
          tagColors: widget.tagColors,
          imagePreviewItems: widget.imagePreviewItems,
          allowedLocalImageUrls: widget.allowedLocalImageUrls,
          onOpenImagePreview: widget.onOpenImagePreview,
          onToggleTask: showCollapsed ? null : widget.onToggleTask,
        ),
        if (shouldCollapse)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                if (widget.hapticsEnabled) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _expanded = !_expanded);
              },
              child: Text(
                _expanded
                    ? context.t.strings.legacy.msg_collapse
                    : context.t.strings.legacy.msg_expand,
              ),
            ),
          ),
      ],
    );
  }
}
