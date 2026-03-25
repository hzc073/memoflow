import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../core/app_localization.dart';
import '../../core/location_launcher.dart';
import '../../core/memoflow_palette.dart';
import '../../core/pointer_double_tap_listener.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/top_toast.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../core/image_error_logger.dart';
import '../../data/models/attachment.dart';
import '../../data/models/content_fingerprint.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/reaction.dart';
import '../../data/models/user.dart';
import '../../state/memos/memo_detail_providers.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../../state/system/session_provider.dart';
import '../../state/settings/location_settings_provider.dart';
import '../share/share_inline_image_content.dart';
import 'attachment_gallery_screen.dart';
import 'memo_editor_screen.dart';
import 'memo_image_grid.dart';
import 'memo_media_grid.dart';
import 'memo_markdown.dart';
import 'memo_location_line.dart';
import 'memo_hero_flight.dart';
import 'memo_versions_screen.dart';
import 'memos_list_screen.dart';
import 'memo_video_grid.dart';
import 'widgets/floating_collapse_button.dart';
import '../../i18n/strings.g.dart';

String memoDetailMarkdownCacheKey(
  LocalMemo memo, {
  required bool renderImages,
}) {
  final renderFlag = renderImages ? 1 : 0;
  return 'detail|${memo.uid}|${memo.contentFingerprint}|renderImages=$renderFlag|highlight=';
}

const _likeReactionType = '❤️';

Rect? _globalRectForKey(GlobalKey key) {
  final context = key.currentContext;
  if (context == null) return null;
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

class _MemoDetailDeferredContent {
  const _MemoDetailDeferredContent({
    required this.imageEntries,
    required this.videoEntries,
    required this.mediaEntries,
    required this.nonImageAttachments,
  });

  final List<MemoImageEntry> imageEntries;
  final List<MemoVideoEntry> videoEntries;
  final List<MemoMediaEntry> mediaEntries;
  final List<Attachment> nonImageAttachments;
}

class MemoDetailScreen extends ConsumerStatefulWidget {
  const MemoDetailScreen({
    super.key,
    required this.initialMemo,
    this.readOnly = false,
    this.showEngagement = false,
  });

  final LocalMemo initialMemo;
  final bool readOnly;
  final bool showEngagement;

  @override
  ConsumerState<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends ConsumerState<MemoDetailScreen> {
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final _player = AudioPlayer();
  final _scrollController = ScrollController();
  final _floatingCollapseViewportKey = GlobalKey();
  final _collapsibleTextKey = GlobalKey<_CollapsibleTextState>();

  LocalMemo? _memo;
  String? _currentAudioUrl;
  Animation<double>? _routeAnimation;
  bool _routeSettled = false;
  bool _floatingCollapseVisible = false;
  bool _floatingCollapseScrolling = false;
  bool _floatingCollapseRecomputeScheduled = false;
  _MemoDetailDeferredContent? _deferredContent;
  String? _preparedDeferredContentKey;
  String? _pendingDeferredContentKey;

  @override
  void initState() {
    super.initState();
    _memo = widget.initialMemo;
    _scrollController.addListener(_scheduleFloatingCollapseRecompute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleFloatingCollapseRecompute();
    });
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
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatusChanged);
    _scrollController.dispose();
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
    _floatingCollapseVisible = false;
    _deferredContent = null;
    _preparedDeferredContentKey = null;
    _pendingDeferredContentKey = null;
    _scheduleFloatingCollapseRecompute();
  }

  void _scheduleFloatingCollapseRecompute() {
    if (_floatingCollapseRecomputeScheduled) return;
    _floatingCollapseRecomputeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _floatingCollapseRecomputeScheduled = false;
      if (!mounted) return;
      _recomputeFloatingCollapseVisibility();
    });
  }

  void _recomputeFloatingCollapseVisibility() {
    final viewportRect = _globalRectForKey(_floatingCollapseViewportKey);
    final shouldShow =
        viewportRect != null &&
        (_collapsibleTextKey.currentState?.shouldShowFloatingCollapse(
              viewportRect,
            ) ??
            false);
    if (shouldShow == _floatingCollapseVisible) return;
    setState(() => _floatingCollapseVisible = shouldShow);
  }

  void _setFloatingCollapseScrolling(bool value) {
    if (_floatingCollapseScrolling == value || !mounted) return;
    setState(() => _floatingCollapseScrolling = value);
  }

  bool _handleFloatingCollapseScrollNotification(
    ScrollNotification notification,
  ) {
    if (notification.metrics.axis == Axis.vertical) {
      if (notification is ScrollStartNotification ||
          notification is ScrollUpdateNotification ||
          notification is OverscrollNotification) {
        _setFloatingCollapseScrolling(true);
      } else if (notification is UserScrollNotification) {
        _setFloatingCollapseScrolling(
          notification.direction != ScrollDirection.idle,
        );
      } else if (notification is ScrollEndNotification) {
        _setFloatingCollapseScrolling(false);
      }
      _scheduleFloatingCollapseRecompute();
    }
    return false;
  }

  void _collapseMemoContentFromFloatingButton() {
    _collapsibleTextKey.currentState?.collapseFromFloating();
    _scheduleFloatingCollapseRecompute();
  }

  String _buildDeferredContentKey({
    required LocalMemo memo,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
  }) {
    return '${memo.uid}|'
        '${memo.contentFingerprint}|'
        '${memo.updateTime.microsecondsSinceEpoch}|'
        '${memo.attachments.length}|'
        '${baseUrl?.toString() ?? ''}|'
        '${authHeader ?? ''}|'
        '${rebaseAbsoluteFileUrlForV024 ? 1 : 0}|'
        '${attachAuthForSameOriginAbsolute ? 1 : 0}';
  }

  _MemoDetailDeferredContent _buildDeferredDetailContent({
    required LocalMemo memo,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
  }) {
    final imageEntries = collectMemoImageEntries(
      content: memo.content,
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    final videoEntries = collectMemoVideoEntries(
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    return _MemoDetailDeferredContent(
      imageEntries: imageEntries,
      videoEntries: videoEntries,
      mediaEntries: buildMemoMediaEntries(
        images: imageEntries,
        videos: videoEntries,
      ),
      nonImageAttachments: memo.attachments
          .where(
            (attachment) =>
                !attachment.type.startsWith('image/') &&
                !attachment.type.startsWith('video/'),
          )
          .toList(growable: false),
    );
  }

  void _scheduleDeferredDetailContentPreparation({
    required LocalMemo memo,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
  }) {
    if (!_routeSettled) return;
    final key = _buildDeferredContentKey(
      memo: memo,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    if (_preparedDeferredContentKey == key) return;
    if (_pendingDeferredContentKey == key) return;
    _pendingDeferredContentKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_routeSettled) return;
      if (_pendingDeferredContentKey != key) return;
      final content = _buildDeferredDetailContent(
        memo: memo,
        baseUrl: baseUrl,
        authHeader: authHeader,
        rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
        attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
      );
      if (!mounted || _pendingDeferredContentKey != key) return;
      setState(() {
        _pendingDeferredContentKey = null;
        _preparedDeferredContentKey = key;
        _deferredContent = content;
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
        MaterialPageRoute<void>(
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

  Future<void> _edit() async {
    if (widget.readOnly || _isArchivedMemo()) return;
    final memo = _memo;
    if (memo == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MemoEditorScreen(existing: memo)),
    );
    ref.invalidate(memoRelationsProvider(memo.uid));
    await _reload();
  }

  Future<void> _openVersionHistory() async {
    final memo = _memo;
    if (memo == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
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
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_delete_memo),
            content: Text(
              context
                  .t
                  .strings
                  .legacy
                  .msg_removed_locally_now_deleted_server_when,
            ),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_delete),
              ),
            ],
          ),
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
    final tags = extractTags(updated);

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

  String _attachmentUrl(Uri baseUrl, Attachment a, {required bool thumbnail}) {
    final external = a.externalLink.trim();
    if (external.isNotEmpty) {
      final isRelative = !isAbsoluteUrl(external);
      final resolved = resolveMaybeRelativeUrl(baseUrl, external);
      return (thumbnail && isRelative)
          ? appendThumbnailParam(resolved)
          : resolved;
    }
    final url = joinBaseUrl(baseUrl, 'file/${a.name}/${a.filename}');
    return thumbnail ? appendThumbnailParam(url) : url;
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
    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    final shouldShowEngagement =
        widget.showEngagement || prefs.showEngagementInAllMemoDetails;
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
    final deferredContentKey = _buildDeferredContentKey(
      memo: memo,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    if (_routeSettled) {
      _scheduleDeferredDetailContentPreparation(
        memo: memo,
        baseUrl: baseUrl,
        authHeader: authHeader,
        rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
        attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
      );
    }
    final deferredContent = _preparedDeferredContentKey == deferredContentKey
        ? _deferredContent
        : null;
    final renderInlineImages = contentHasThirdPartyShareMarker(memo.content);
    final imageEntries =
        deferredContent?.imageEntries ?? const <MemoImageEntry>[];
    final videoEntries =
        deferredContent?.videoEntries ?? const <MemoVideoEntry>[];
    final mediaEntries = renderInlineImages
        ? buildMemoMediaEntries(
            images: imageEntries
                .where((entry) => entry.isAttachment)
                .toList(growable: false),
            videos: videoEntries,
          )
        : (deferredContent?.mediaEntries ?? const <MemoMediaEntry>[]);
    final allowImageEdit =
        canEditAttachments &&
        imageEntries.any((entry) => entry.isAttachment) &&
        !imageEntries.any((entry) => !entry.isAttachment);
    final nonImageAttachments =
        deferredContent?.nonImageAttachments ?? const <Attachment>[];
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final imageBg = isDark
        ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6)
        : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final contentStyle = Theme.of(context).textTheme.bodyLarge;
    final canToggleTasks = !widget.readOnly && !isArchived;
    final tagColors = ref.watch(tagColorLookupProvider);

    final contentWidget = _CollapsibleText(
      key: _collapsibleTextKey,
      text: memo.content,
      collapseEnabled: prefs.collapseLongContent,
      initiallyExpanded: true,
      style: contentStyle,
      hapticsEnabled: hapticsEnabled,
      markdownCacheKey: memoDetailMarkdownCacheKey(
        memo,
        renderImages: renderInlineImages,
      ),
      markdownSelectable: _routeSettled,
      renderImages: renderInlineImages,
      tagColors: tagColors,
      onToggleTask: canToggleTasks
          ? (request) {
              maybeHaptic();
              unawaited(
                _toggleTask(
                  request,
                  skipReferenceLines: prefs.collapseReferences,
                ),
              );
            }
          : null,
      onFloatingStateChanged: _scheduleFloatingCollapseRecompute,
    );
    _scheduleFloatingCollapseRecompute();

    final memoErrorText =
        (memo.lastError == null || memo.lastError!.trim().isEmpty)
        ? null
        : presentSyncErrorText(
            language: context.appLanguage,
            raw: memo.lastError!.trim(),
          );
    final displayTime = memo.createTime.millisecondsSinceEpoch > 0
        ? memo.createTime
        : memo.updateTime;
    final header = PointerDoubleTapListener(
      key: const ValueKey('memo-detail-edit-hit-area'),
      behavior: HitTestBehavior.translucent,
      onDoubleTap: onDoubleTapEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateFmt.format(displayTime),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (memo.location != null) ...[
            const SizedBox(height: 6),
            MemoLocationLine(
              location: memo.location!,
              textColor: Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: () => openMemoLocation(
                context,
                memo.location!,
                memoUid: memo.uid,
                provider: ref.read(locationSettingsProvider).provider,
              ),
              fontSize: 12,
            ),
          ],
          const SizedBox(height: 8),
          contentWidget,
          const SizedBox(height: 12),
          if (mediaEntries.isNotEmpty) ...[
            MemoMediaGrid(
              entries: mediaEntries,
              columns: 3,
              maxCount: 9,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
              preserveSquareTilesWhenHeightLimited: Platform.isWindows,
              borderColor: borderColor.withValues(alpha: 0.65),
              backgroundColor: imageBg,
              textColor: textMain,
              radius: 12,
              spacing: 8,
              onReplace: allowImageEdit ? _replaceMemoAttachment : null,
              enableDownload: true,
            ),
            const SizedBox(height: 12),
          ],
          if (memoErrorText != null && memoErrorText.trim().isNotEmpty) ...[
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
                    memoErrorText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          maybeHaptic();
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
                          maybeHaptic();
                          await Clipboard.setData(
                            ClipboardData(text: memoErrorText),
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
      ),
    );

    return Scaffold(
      backgroundColor: cardColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isArchived
              ? context.t.strings.legacy.msg_archived
              : context.t.strings.legacy.msg_memo,
        ),
        actions: widget.readOnly
            ? null
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
              ],
      ),
      body: Stack(
        key: _floatingCollapseViewportKey,
        children: [
          Positioned.fill(
            child: Hero(
              tag: memo.uid,
              createRectTween: (begin, end) =>
                  MaterialRectArcTween(begin: begin, end: end),
              flightShuttleBuilder: memoHeroFlightShuttleBuilder(
                isPinned: memo.pinned,
              ),
              child: RepaintBoundary(child: Container(color: cardColor)),
            ),
          ),
          SafeArea(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleFloatingCollapseScrollNotification,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  header,
                  if (_routeSettled && shouldShowEngagement)
                    _MemoEngagementSection(
                      memoUid: memo.uid,
                      memoVisibility: memo.visibility,
                    ),
                  if (_routeSettled) _MemoRelationsSection(memoUid: memo.uid),
                  if (_routeSettled && nonImageAttachments.isNotEmpty) ...[
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
                              final isAudio = attachment.type.startsWith(
                                'audio',
                              );
                              final fullUrl = (baseUrl == null)
                                  ? ''
                                  : _attachmentUrl(
                                      baseUrl,
                                      attachment,
                                      thumbnail: false,
                                    );

                              if (isAudio &&
                                  baseUrl != null &&
                                  fullUrl.isNotEmpty) {
                                return StreamBuilder<PlayerState>(
                                  stream: _player.playerStateStream,
                                  builder: (context, snap) {
                                    final playing =
                                        _player.playing &&
                                        _currentAudioUrl == fullUrl;
                                    return ListTile(
                                      leading: Icon(
                                        playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                      title: Text(attachment.filename),
                                      subtitle: Text(attachment.type),
                                      onTap: () => _togglePlayAudio(
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
            ),
          ),
          Positioned.fill(
            child: MemoFloatingCollapseButton(
              visible: _floatingCollapseVisible,
              scrolling: _floatingCollapseScrolling,
              label: context.t.strings.legacy.msg_collapse,
              onPressed: _collapseMemoContentFromFloatingButton,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoEngagementSection extends ConsumerStatefulWidget {
  const _MemoEngagementSection({
    required this.memoUid,
    required this.memoVisibility,
  });

  final String memoUid;
  final String memoVisibility;

  @override
  ConsumerState<_MemoEngagementSection> createState() =>
      _MemoEngagementSectionState();
}

class _MemoEngagementSectionState
    extends ConsumerState<_MemoEngagementSection> {
  final _creatorCache = <String, User>{};
  final _creatorFetching = <String>{};
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();

  List<Reaction> _reactions = [];
  List<Memo> _comments = [];
  int _reactionTotal = 0;
  int _commentTotal = 0;
  bool _reactionsLoading = false;
  bool _commentsLoading = false;
  bool _reactionUpdating = false;
  bool _commenting = false;
  bool _commentSending = false;
  String? _reactionsError;
  String? _commentsError;
  String? _replyingCommentCreator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEngagement();
    });
  }

  @override
  void didUpdateWidget(covariant _MemoEngagementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoUid == widget.memoUid) return;
    _reactions = [];
    _comments = [];
    _reactionTotal = 0;
    _commentTotal = 0;
    _reactionUpdating = false;
    _commenting = false;
    _commentSending = false;
    _replyingCommentCreator = null;
    _commentController.clear();
    _reactionsError = null;
    _commentsError = null;
    _creatorCache.clear();
    _creatorFetching.clear();
    _loadEngagement();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _loadEngagement() {
    final uid = widget.memoUid.trim();
    if (uid.isEmpty) return;
    unawaited(_loadReactions(uid));
    unawaited(_loadComments(uid));
  }

  Future<void> _loadReactions(String uid) async {
    if (_reactionsLoading) return;
    setState(() {
      _reactionsLoading = true;
      _reactionsError = null;
    });
    try {
      final result = await ref
          .read(memoDetailControllerProvider)
          .listMemoReactions(memoUid: uid, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _reactions = result.reactions;
        _reactionTotal = _countLikeCreators(result.reactions);
      });
      unawaited(_prefetchCreators(result.reactions.map((r) => r.creator)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _reactionsError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _reactionsLoading = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    final uid = widget.memoUid.trim();
    if (uid.isEmpty || _reactionUpdating) return;
    final currentUser =
        ref
            .read(appSessionProvider)
            .valueOrNull
            ?.currentAccount
            ?.user
            .name
            .trim() ??
        '';
    if (currentUser.isEmpty) return;

    setState(() => _reactionUpdating = true);
    final reactions = List<Reaction>.from(_reactions);
    final mine = reactions
        .where(
          (reaction) =>
              _isLikeReaction(reaction) &&
              reaction.creator.trim() == currentUser,
        )
        .toList(growable: false);

    try {
      final api = ref.read(memosApiProvider);
      if (mine.isNotEmpty) {
        final updated = reactions
            .where((reaction) => !mine.contains(reaction))
            .toList(growable: false);
        _updateReactions(updated);
        for (final reaction in mine) {
          await api.deleteMemoReaction(reaction: reaction);
        }
      } else {
        final optimistic = Reaction(
          name: '',
          creator: currentUser,
          contentId: 'memos/$uid',
          reactionType: _likeReactionType,
        );
        final updated = [...reactions, optimistic];
        _updateReactions(updated);
        final created = await api.upsertMemoReaction(
          memoUid: uid,
          reactionType: _likeReactionType,
        );
        if (!mounted) return;
        final currentList = List<Reaction>.from(_reactions);
        final index = currentList.indexWhere(
          (reaction) =>
              reaction.creator.trim() == currentUser &&
              _isLikeReaction(reaction) &&
              reaction.name.trim().isEmpty,
        );
        if (index >= 0) {
          currentList[index] = created;
        } else {
          currentList.add(created);
        }
        _updateReactions(currentList);
      }
    } catch (e) {
      if (!mounted) return;
      _updateReactions(reactions);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_react(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _reactionUpdating = false);
      }
    }
  }

  Future<void> _loadComments(String uid) async {
    if (_commentsLoading) return;
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final result = await ref
          .read(memoDetailControllerProvider)
          .listMemoComments(memoUid: uid, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _comments = result.memos;
        _commentTotal = result.totalSize;
      });
      unawaited(_prefetchCreators(result.memos.map((m) => m.creator)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentsError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _commentsLoading = false);
      }
    }
  }

  void _toggleCommentComposer() {
    setState(() {
      _commenting = !_commenting;
      if (!_commenting) {
        _replyingCommentCreator = null;
        _commentController.clear();
      }
    });
    if (_commenting) {
      _commentFocusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _replyToComment(Memo comment) {
    setState(() {
      _commenting = true;
      _replyingCommentCreator = comment.creator;
    });
    _commentController.clear();
    _commentFocusNode.requestFocus();
  }

  void _exitCommentEditing() {
    if (_replyingCommentCreator == null) return;
    setState(() {
      _commenting = false;
      _replyingCommentCreator = null;
      _commentController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  String _commentHint() {
    final replyCreator = _replyingCommentCreator?.trim() ?? '';
    if (replyCreator.isNotEmpty) {
      final creator = _creatorCache[replyCreator];
      final name = _creatorDisplayName(creator, replyCreator, context);
      if (name.isNotEmpty) {
        return context.t.strings.legacy.msg_reply_2(name: name);
      }
    }
    return context.t.strings.legacy.msg_write_comment;
  }

  Future<void> _submitComment() async {
    final uid = widget.memoUid.trim();
    if (uid.isEmpty) return;
    final content = _commentController.text.trim();
    if (content.isEmpty || _commentSending) return;

    setState(() => _commentSending = true);
    try {
      final visibility = widget.memoVisibility.trim().isNotEmpty
          ? widget.memoVisibility.trim()
          : 'PUBLIC';
      final created = await ref
          .read(memoDetailControllerProvider)
          .createMemoComment(
            memoUid: uid,
            content: content,
            visibility: visibility,
          );
      if (!mounted) return;
      setState(() {
        _comments = [created, ..._comments];
        _commentTotal = _commentTotal > 0
            ? _commentTotal + 1
            : _comments.length;
        _commentController.clear();
        _replyingCommentCreator = null;
      });
      unawaited(_prefetchCreators([created.creator]));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_comment(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _commentSending = false);
      }
    }
  }

  Widget _buildCommentComposer({
    required Color textMain,
    required Color textMuted,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    final inputBg = isDark
        ? MemoFlowPalette.backgroundDark
        : const Color(0xFFF7F5F1);
    return TapRegion(
      onTapOutside: _replyingCommentCreator == null
          ? null
          : (_) => _exitCommentEditing(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                  style: TextStyle(color: textMain),
                  decoration: InputDecoration(
                    hintText: _commentHint(),
                    hintStyle: TextStyle(
                      color: textMuted.withValues(alpha: 0.7),
                    ),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: MemoFlowPalette.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _commentSending ? null : _submitComment,
                style: TextButton.styleFrom(
                  foregroundColor: MemoFlowPalette.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  context.t.strings.legacy.msg_send,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _prefetchCreators(Iterable<String> creators) async {
    final updates = <String, User>{};
    for (final creator in creators) {
      final normalized = creator.trim();
      if (normalized.isEmpty) continue;
      if (_creatorCache.containsKey(normalized) ||
          _creatorFetching.contains(normalized)) {
        continue;
      }
      _creatorFetching.add(normalized);
      try {
        final user = await ref
            .read(memoDetailControllerProvider)
            .fetchUser(name: normalized);
        if (user != null) {
          updates[normalized] = user;
        }
      } finally {
        _creatorFetching.remove(normalized);
      }
    }
    if (!mounted) return;
    if (updates.isNotEmpty) {
      setState(() => _creatorCache.addAll(updates));
    }
  }

  String _creatorDisplayName(
    User? creator,
    String fallback,
    BuildContext context,
  ) {
    final display = creator?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = creator?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final trimmed = fallback.trim();
    if (trimmed.startsWith('users/')) {
      return '${context.t.strings.legacy.msg_user} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.t.strings.legacy.msg_unknown : trimmed;
  }

  String _creatorInitial(User? creator, String fallback, BuildContext context) {
    final display = _creatorDisplayName(creator, fallback, context);
    if (display.isEmpty) return '?';
    return display.characters.first.toUpperCase();
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (baseUrl == null) return trimmed;
    return joinBaseUrl(baseUrl, trimmed);
  }

  static List<Reaction> _uniqueReactions(List<Reaction> reactions) {
    final seen = <String>{};
    final unique = <Reaction>[];
    for (final reaction in reactions) {
      final creator = reaction.creator.trim();
      if (creator.isEmpty) continue;
      if (seen.add(creator)) {
        unique.add(reaction);
      }
    }
    return unique;
  }

  bool _isLikeReaction(Reaction reaction) {
    final type = reaction.reactionType.trim();
    return type == _likeReactionType || type == 'HEART';
  }

  int _countLikeCreators(Iterable<Reaction> reactions) {
    final creators = <String>{};
    for (final reaction in reactions) {
      if (!_isLikeReaction(reaction)) continue;
      final creator = reaction.creator.trim();
      if (creator.isEmpty) continue;
      creators.add(creator);
    }
    return creators.length;
  }

  List<Reaction> _likeReactions() {
    return _reactions.where(_isLikeReaction).toList(growable: false);
  }

  bool _hasMyLike(String currentUser) {
    if (currentUser.isEmpty) return false;
    return _reactions.any(
      (reaction) =>
          _isLikeReaction(reaction) && reaction.creator.trim() == currentUser,
    );
  }

  List<({String reactionType, int count})> _otherReactionSummaries() {
    if (_reactions.isEmpty) return const [];
    final creatorsByType = <String, Set<String>>{};
    final anonymousCounts = <String, int>{};
    for (final reaction in _reactions) {
      if (_isLikeReaction(reaction)) continue;
      final type = reaction.reactionType.trim();
      if (type.isEmpty) continue;
      final creator = reaction.creator.trim();
      if (creator.isEmpty) {
        anonymousCounts[type] = (anonymousCounts[type] ?? 0) + 1;
        continue;
      }
      creatorsByType.putIfAbsent(type, () => <String>{}).add(creator);
    }

    final summaries = <({String reactionType, int count})>[];
    for (final entry in creatorsByType.entries) {
      summaries.add((reactionType: entry.key, count: entry.value.length));
    }
    for (final entry in anonymousCounts.entries) {
      final index = summaries.indexWhere(
        (summary) => summary.reactionType == entry.key,
      );
      if (index >= 0) {
        final current = summaries[index];
        summaries[index] = (
          reactionType: current.reactionType,
          count: current.count + entry.value,
        );
      } else {
        summaries.add((reactionType: entry.key, count: entry.value));
      }
    }
    summaries.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) return countCompare;
      return a.reactionType.compareTo(b.reactionType);
    });
    return summaries;
  }

  void _updateReactions(List<Reaction> reactions) {
    setState(() {
      _reactions = reactions;
      _reactionTotal = _countLikeCreators(reactions);
    });
  }

  String _remainingPeopleLabel(BuildContext context, int count) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'zh' => '\u7b49 $count \u4eba',
      'ja' => '\u307b\u304b$count\u4eba',
      'de' => 'und $count weitere',
      _ => 'and $count more',
    };
  }

  void _showLikersSheet({required Color textMuted, required Uri? baseUrl}) {
    final likers = _uniqueReactions(_likeReactions());
    if (likers.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    '${sheetContext.t.strings.legacy.msg_like_2} $_reactionTotal',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: likers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final reaction = likers[index];
                      final creator = reaction.creator;
                      final user = _creatorCache[creator];
                      final displayName = _creatorDisplayName(
                        user,
                        creator,
                        context,
                      );
                      return Row(
                        children: [
                          _buildAvatar(
                            creator: user,
                            fallback: creator,
                            textMuted: textMuted,
                            baseUrl: baseUrl,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              displayName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _commentSnippet(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isImageAttachment(Attachment attachment) {
    final type = attachment.type.trim().toLowerCase();
    return type.startsWith('image');
  }

  String _resolveCommentAttachmentUrl(
    Uri? baseUrl,
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
    if (baseUrl == null) return '';
    final url = joinBaseUrl(
      baseUrl,
      'file/${attachment.name}/${attachment.filename}',
    );
    return thumbnail ? appendThumbnailParam(url) : url;
  }

  List<AttachmentImageSource> _buildCommentSources({
    required List<Attachment> attachments,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    return attachments
        .map((attachment) {
          final fullUrl = _resolveCommentAttachmentUrl(
            baseUrl,
            attachment,
            thumbnail: false,
          );
          return AttachmentImageSource(
            id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
            title: attachment.filename,
            mimeType: attachment.type,
            localFile: null,
            imageUrl: fullUrl.isNotEmpty ? fullUrl : null,
            headers: authHeader == null ? null : {'Authorization': authHeader},
          );
        })
        .toList(growable: false);
  }

  Widget _buildCommentItem({
    required Memo comment,
    required Color textMain,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final images = comment.attachments
        .where(_isImageAttachment)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 12, color: textMain),
            children: [
              TextSpan(
                text:
                    '${_creatorDisplayName(_creatorCache[comment.creator], comment.creator, context)}: ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MemoFlowPalette.primary,
                ),
              ),
              TextSpan(
                text: _commentSnippet(comment.content),
                style: TextStyle(color: textMain),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < images.length; i++)
                _buildCommentImage(
                  attachment: images[i],
                  attachments: images,
                  index: i,
                  baseUrl: baseUrl,
                  authHeader: authHeader,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCommentImage({
    required Attachment attachment,
    required List<Attachment> attachments,
    required int index,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final thumbUrl = _resolveCommentAttachmentUrl(
      baseUrl,
      attachment,
      thumbnail: true,
    );
    final fullUrl = _resolveCommentAttachmentUrl(
      baseUrl,
      attachment,
      thumbnail: false,
    );
    final displayUrl = thumbUrl.isNotEmpty ? thumbUrl : fullUrl;
    if (displayUrl.isEmpty) return const SizedBox.shrink();
    final viewUrl = fullUrl.isNotEmpty ? fullUrl : displayUrl;
    final sources = _buildCommentSources(
      attachments: attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
    );

    return GestureDetector(
      onTap: viewUrl.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AttachmentGalleryScreen(
                    images: sources,
                    initialIndex: index,
                    enableDownload: true,
                  ),
                ),
              );
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: displayUrl,
          httpHeaders: authHeader == null
              ? null
              : {'Authorization': authHeader},
          width: 110,
          height: 80,
          fit: BoxFit.cover,
          placeholder: (context, _) => const SizedBox(
            width: 110,
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, _, error) {
            logImageLoadError(
              scope: 'memo_detail_comment_image',
              source: displayUrl,
              error: error,
              extraContext: <String, Object?>{
                'attachmentName': attachment.name,
                'attachmentType': attachment.type,
                'hasAuthHeader': authHeader?.trim().isNotEmpty ?? false,
              },
            );
            return const SizedBox(
              width: 110,
              height: 80,
              child: Icon(Icons.broken_image),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required User? creator,
    required String fallback,
    required Color textMuted,
    required Uri? baseUrl,
    double size = 28,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
      alignment: Alignment.center,
      child: Text(
        _creatorInitial(creator, fallback, context),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: textMuted,
        ),
      ),
    );

    final avatarUrl = _resolveAvatarUrl(creator?.avatarUrl ?? '', baseUrl);
    if (avatarUrl.isEmpty) return fallbackWidget;
    if (avatarUrl.startsWith('data:')) {
      final bytes = tryDecodeDataUri(avatarUrl);
      if (bytes == null) return fallbackWidget;
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) {
            logImageLoadError(
              scope: 'memo_detail_avatar_data_uri',
              source: avatarUrl,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'userName': creator?.name,
                'avatarKind': 'data_uri',
              },
            );
            return fallbackWidget;
          },
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallbackWidget,
        errorWidget: (context, _, error) {
          logImageLoadError(
            scope: 'memo_detail_avatar_network',
            source: avatarUrl,
            error: error,
            extraContext: <String, Object?>{
              'userName': creator?.name,
              'avatarKind': 'network',
            },
          );
          return fallbackWidget;
        },
      ),
    );
  }

  Widget _buildReactionsRow({required Color textMuted, required Uri? baseUrl}) {
    if (_reactionsLoading && _reactions.isEmpty) {
      return Row(
        children: [
          Icon(Icons.favorite, size: 16, color: MemoFlowPalette.primary),
          const SizedBox(width: 8),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    if (_reactionsError != null && _reactions.isEmpty) {
      return Text(
        context.t.strings.legacy.msg_failed_load_2,
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    final likeReactions = _likeReactions();
    final reactionSummaries = _otherReactionSummaries();
    if (likeReactions.isEmpty && reactionSummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = _reactionTotal > 0
        ? _reactionTotal
        : _countLikeCreators(likeReactions);
    final unique = _uniqueReactions(likeReactions);
    final shown = unique.take(8).toList(growable: false);
    final remaining = total - shown.length;
    const avatarSize = 28.0;
    const overlap = 18.0;
    final width = shown.isEmpty
        ? 0.0
        : avatarSize + ((shown.length - 1) * overlap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 16, color: MemoFlowPalette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showLikersSheet(
                        textMuted: textMuted,
                        baseUrl: baseUrl,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            if (shown.isNotEmpty) ...[
                              SizedBox(
                                height: avatarSize,
                                width: width,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (var i = 0; i < shown.length; i++)
                                      Positioned(
                                        left: i * overlap,
                                        child: _buildAvatar(
                                          creator:
                                              _creatorCache[shown[i].creator],
                                          fallback: shown[i].creator,
                                          textMuted: textMuted,
                                          baseUrl: baseUrl,
                                          size: avatarSize,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            if (remaining > 0) ...[
                              if (shown.isNotEmpty) const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _remainingPeopleLabel(context, remaining),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                            ] else if (shown.isEmpty)
                              Expanded(
                                child: Text(
                                  total.toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (reactionSummaries.isNotEmpty) ...[
          if (total > 0) const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final summary in reactionSummaries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${summary.reactionType} ${summary.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsList({
    required Color textMain,
    required Color textMuted,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    if (_commentsLoading && _comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_commentsError != null && _comments.isEmpty) {
      return Text(
        context.t.strings.legacy.msg_failed_load_2,
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    if (_comments.isEmpty) {
      return Text(
        context.t.strings.legacy.msg_no_comments_yet,
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _comments.length; i++) ...[
          GestureDetector(
            onTap: () => _replyToComment(_comments[i]),
            child: _buildCommentItem(
              comment: _comments[i],
              textMain: textMain,
              baseUrl: baseUrl,
              authHeader: authHeader,
            ),
          ),
          if (i != _comments.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
    final cardBg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final authHeader = (account?.personalAccessToken ?? '').isEmpty
        ? null
        : 'Bearer ${account!.personalAccessToken}';
    final reactionCount = _reactionTotal > 0
        ? _reactionTotal
        : _countLikeCreators(_reactions);
    final commentCount = _commentTotal > 0 ? _commentTotal : _comments.length;
    final currentUser = account?.user.name.trim() ?? '';
    final hasOwnLike = _hasMyLike(currentUser);
    final hasOwnComment =
        currentUser.isNotEmpty &&
        _comments.any((comment) => comment.creator.trim() == currentUser);
    final commentActive = _commenting || hasOwnComment;
    final otherReactionSummaries = _otherReactionSummaries();
    final showReactionSummary =
        (_reactionsLoading && _reactions.isEmpty) ||
        (_reactionsError != null && _reactions.isEmpty) ||
        reactionCount > 0 ||
        otherReactionSummaries.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EngagementAction(
                icon: hasOwnLike ? Icons.favorite : Icons.favorite_border,
                label: context.t.strings.legacy.msg_like_2,
                count: reactionCount,
                color: hasOwnLike ? MemoFlowPalette.primary : textMuted,
                onTap: _reactionUpdating ? null : _toggleLike,
              ),
              const SizedBox(width: 18),
              _EngagementAction(
                icon: commentActive
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                label: context.t.strings.legacy.msg_comment,
                count: commentCount,
                color: commentActive ? MemoFlowPalette.primary : textMuted,
                onTap: _toggleCommentComposer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showReactionSummary) ...[
                  _buildReactionsRow(textMuted: textMuted, baseUrl: baseUrl),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: borderColor.withValues(alpha: 0.6)),
                  const SizedBox(height: 10),
                ],
                _buildCommentsList(
                  textMain: textMain,
                  textMuted: textMuted,
                  baseUrl: baseUrl,
                  authHeader: authHeader,
                ),
              ],
            ),
          ),
          if (_commenting)
            _buildCommentComposer(
              textMain: textMain,
              textMuted: textMuted,
              cardBg: cardBg,
              borderColor: borderColor,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _EngagementAction extends StatelessWidget {
  const _EngagementAction({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
      ),
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
            Text(
              context.t.strings.legacy.msg_loading_links,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
            const Spacer(),
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
      MaterialPageRoute<void>(
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
    super.key,
    required this.text,
    required this.collapseEnabled,
    required this.style,
    required this.hapticsEnabled,
    this.initiallyExpanded = false,
    this.markdownCacheKey,
    this.markdownSelectable = true,
    this.renderImages = false,
    this.tagColors,
    this.onToggleTask,
    this.onFloatingStateChanged,
  });

  final String text;
  final bool collapseEnabled;
  final TextStyle? style;
  final bool hapticsEnabled;
  final bool initiallyExpanded;
  final String? markdownCacheKey;
  final bool markdownSelectable;
  final bool renderImages;
  final TagColorLookup? tagColors;
  final ValueChanged<TaskToggleRequest>? onToggleTask;
  final VoidCallback? onFloatingStateChanged;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _collapsedLines = 14;
  static const _collapsedRunes = 420;

  late bool _expanded;
  final _contentKey = GlobalKey();
  final _toggleButtonKey = GlobalKey();
  bool _shouldCollapse = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _notifyFloatingStateChanged() {
    widget.onFloatingStateChanged?.call();
  }

  void collapseFromFloating() {
    if (!_expanded) return;
    if (widget.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    setState(() => _expanded = false);
    _notifyFloatingStateChanged();
  }

  bool shouldShowFloatingCollapse(Rect viewportRect) {
    if (!_expanded || !_shouldCollapse) return false;
    final contentRect = _globalRectForKey(_contentKey);
    final toggleRect = _globalRectForKey(_toggleButtonKey);
    if (contentRect == null || toggleRect == null) return false;
    final visibleHeight = math.max(
      0,
      math.min(contentRect.bottom, viewportRect.bottom) -
          math.max(contentRect.top, viewportRect.top),
    );
    if (visibleHeight <= 0) return false;
    return shouldShowFloatingCollapseForToggle(
      viewportRect: viewportRect,
      toggleRect: toggleRect,
    );
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
    _shouldCollapse = shouldCollapse;
    final showCollapsed = shouldCollapse && !_expanded;
    final displayText = showCollapsed ? _collapseText(text) : text;

    return Column(
      key: _contentKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemoMarkdown(
          cacheKey: widget.markdownCacheKey,
          data: displayText,
          textStyle: widget.style,
          selectable: widget.markdownSelectable && !showCollapsed,
          blockSpacing: 8,
          renderImages: widget.renderImages && !showCollapsed,
          tagColors: widget.tagColors,
          onToggleTask: showCollapsed ? null : widget.onToggleTask,
        ),
        if (shouldCollapse)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: _toggleButtonKey,
              onPressed: () {
                if (widget.hapticsEnabled) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _expanded = !_expanded);
                _notifyFloatingStateChanged();
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
