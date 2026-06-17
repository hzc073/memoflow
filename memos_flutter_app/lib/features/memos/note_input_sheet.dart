import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/attachments/queued_attachment_stager.dart';
import '../../core/app_localization.dart';
import '../../core/attachment_mime_type.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/image_thumbnail_cache.dart';
import '../../core/markdown_editing.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/compose_draft.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/user_setting.dart';
import '../../platform/platform_target.dart';
import '../../platform/widgets/platform_action_sheet.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../state/memos/attachment_upload_size_limit_provider.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/memos/note_input_draft_session.dart';
import '../../state/attachments/queued_attachment_stager_provider.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/note_draft_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../../state/settings/user_settings_provider.dart';
import '../../state/memos/note_input_providers.dart';
import '../image_preview/image_preview_item.dart';
import '../image_preview/image_preview_launcher.dart';
import '../image_preview/image_preview_open_request.dart';
import '../image_preview/widgets/image_preview_tile.dart';
import '../media_preview/media_preview_launcher.dart';
import '../share/share_clip_models.dart';
import '../share/share_deferred_inline_image_coordinator.dart';
import '../share/share_deferred_video_coordinator.dart';
import '../share/share_inline_image_content.dart';
import '../share/share_inline_image_download_service.dart';
import '../share/share_video_attachment_preparer.dart';
import '../share/share_video_compression_service.dart';
import '../share/share_video_download_service.dart';
import '../share/share_video_limit_messages.dart';
import '../settings/location_settings_navigation.dart';
import 'attachment_gallery_screen.dart';
import 'compose_input_hint.dart';
import 'compose_toolbar_shared.dart';
import 'draft_box_screen.dart';
import 'gallery_attachment_picker.dart';
import 'memo_image_preview_adapters.dart';
import 'memo_video_grid.dart';
import 'tag_autocomplete.dart';
import 'link_memo_sheet.dart';
import 'widgets/note_input_attachment_preview.dart';
import 'widgets/note_input_compact_widgets.dart';
import 'widgets/note_input_fullscreen_compose.dart';
import '../voice/voice_record_screen.dart';
import '../location_picker/show_location_picker.dart';
import '../../i18n/strings.g.dart';
import 'android_memo_keyboard_resume_controller.dart';

typedef _PendingAttachment = MemoComposerPendingAttachment;
typedef _LinkedMemo = MemoComposerLinkedMemo;

ImageThumbnailCacheTarget resolveNoteInputPendingImageThumbnailCacheTarget({
  required double tileSize,
  required double devicePixelRatio,
}) {
  return resolveAspectSafeThumbnailCacheTarget(
    tileWidth: tileSize,
    tileHeight: tileSize,
    devicePixelRatio: devicePixelRatio,
  );
}

enum _NoteInputSheetPresentationMode { compact, fullscreen }

typedef NoteInputDraftBoxHomeUtilityOpener =
    bool Function(String? activeDraftId);

class NoteInputSheet extends ConsumerStatefulWidget {
  const NoteInputSheet({
    super.key,
    this.initialText,
    this.initialSelection,
    this.initialAttachmentPaths = const [],
    this.initialAttachmentSeeds = const [],
    this.initialClipMetadataDraft,
    this.initialDeferredInlineImageAttachments = const [],
    this.initialDeferredVideoAttachments = const [],
    this.initialDraftUid,
    this.ignoreDraft = false,
    this.autoFocus = true,
    this.showLocalSaveSuccessToast = false,
    this.shareInlineImageDownloadService,
    this.shareVideoDownloadService,
    this.shareVideoCompressionService,
    this.onOpenDraftBoxInHomeUtility,
  });

  final String? initialText;
  final TextSelection? initialSelection;
  final List<String> initialAttachmentPaths;
  final List<ShareAttachmentSeed> initialAttachmentSeeds;
  final ShareClipMetadataDraft? initialClipMetadataDraft;
  final List<ShareDeferredInlineImageAttachmentRequest>
  initialDeferredInlineImageAttachments;
  final List<ShareDeferredVideoAttachmentRequest>
  initialDeferredVideoAttachments;
  final String? initialDraftUid;
  final bool ignoreDraft;
  final bool autoFocus;
  final bool showLocalSaveSuccessToast;
  final ShareInlineImageDownloadService? shareInlineImageDownloadService;
  final ShareVideoDownloadService? shareVideoDownloadService;
  final ShareVideoCompressionService? shareVideoCompressionService;
  final NoteInputDraftBoxHomeUtilityOpener? onOpenDraftBoxInHomeUtility;

  static Future<void> show(
    BuildContext context, {
    String? initialText,
    TextSelection? initialSelection,
    List<String> initialAttachmentPaths = const [],
    List<ShareAttachmentSeed> initialAttachmentSeeds = const [],
    ShareClipMetadataDraft? initialClipMetadataDraft,
    List<ShareDeferredInlineImageAttachmentRequest>
        initialDeferredInlineImageAttachments =
        const [],
    List<ShareDeferredVideoAttachmentRequest> initialDeferredVideoAttachments =
        const [],
    String? initialDraftUid,
    bool ignoreDraft = false,
    bool autoFocus = true,
    bool showLocalSaveSuccessToast = false,
    ShareInlineImageDownloadService? shareInlineImageDownloadService,
    ShareVideoDownloadService? shareVideoDownloadService,
    ShareVideoCompressionService? shareVideoCompressionService,
    NoteInputDraftBoxHomeUtilityOpener? onOpenDraftBoxInHomeUtility,
  }) {
    return showPlatformActionSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.05),
      showDragHandle: false,
      builder: (context) => NoteInputSheet(
        initialText: initialText,
        initialSelection: initialSelection,
        initialAttachmentPaths: initialAttachmentPaths,
        initialAttachmentSeeds: initialAttachmentSeeds,
        initialClipMetadataDraft: initialClipMetadataDraft,
        initialDeferredInlineImageAttachments:
            initialDeferredInlineImageAttachments,
        initialDeferredVideoAttachments: initialDeferredVideoAttachments,
        initialDraftUid: initialDraftUid,
        ignoreDraft: ignoreDraft,
        autoFocus: autoFocus,
        showLocalSaveSuccessToast: showLocalSaveSuccessToast,
        shareInlineImageDownloadService: shareInlineImageDownloadService,
        shareVideoDownloadService: shareVideoDownloadService,
        shareVideoCompressionService: shareVideoCompressionService,
        onOpenDraftBoxInHomeUtility: onOpenDraftBoxInHomeUtility,
      ),
    );
  }

  @override
  ConsumerState<NoteInputSheet> createState() => _NoteInputSheetState();
}

class _NoteInputSheetState extends ConsumerState<NoteInputSheet> {
  static const _fullscreenExpandButtonKey = ValueKey<String>(
    'note-input-fullscreen-expand-button',
  );
  static const _fullscreenCollapseButtonKey = ValueKey<String>(
    'note-input-fullscreen-collapse-button',
  );
  static const _fullscreenCloseButtonKey = ValueKey<String>(
    'note-input-fullscreen-close-button',
  );
  static const _fullscreenTopToolbarKey = ValueKey<String>(
    'note-input-fullscreen-top-toolbar-row',
  );
  static const _fullscreenBottomToolbarKey = ValueKey<String>(
    'note-input-fullscreen-bottom-toolbar-row',
  );
  static const _fullscreenSendButtonKey = ValueKey<String>(
    'note-input-fullscreen-send-button',
  );

  late final MemoComposerController _composer;
  late final FocusNode _editorFocusNode;
  late final AndroidMemoKeyboardResumeController _keyboardResumeController;
  TextEditingController get _controller => _composer.textController;
  final _editorFieldKey = GlobalKey();
  var _busy = false;
  Timer? _draftTimer;
  var _didSeedInitialAttachments = false;
  var _didSeedInitialDeferredInlineImages = false;
  var _didSeedInitialDeferredVideos = false;
  List<TagStat> _tagStatsCache = const [];
  ComposeDraftRepository? _composeDraftRepository;
  NoteDraftRepository? _noteDraftRepository;
  late final NoteDraftController _noteDraftController;
  late final ShareInlineImageDownloadService _shareInlineImageDownloadService;
  late final ShareDeferredInlineImageCoordinator
  _deferredInlineImageCoordinator;
  late final ShareVideoDownloadService _shareVideoDownloadService;
  late final ShareVideoCompressionService _shareVideoCompressionService;
  late final ShareVideoAttachmentPreparer _shareVideoAttachmentPreparer;
  late final ShareDeferredVideoCoordinator _deferredVideoCoordinator;
  final List<ShareDeferredInlineImageAttachmentRequest>
  _deferredInlineImageRequests = [];
  final Map<String, String> _thirdPartyShareInlineSourceByLocalUrl = {};
  List<_LinkedMemo> get _linkedMemos => _composer.linkedMemos;
  List<_PendingAttachment> get _pendingAttachments =>
      _composer.pendingAttachments;
  List<ShareDeferredVideoTask> get _visibleDeferredShareVideoTasks =>
      _deferredVideoCoordinator.visibleTasks;
  bool get _hasPendingDeferredShareVideoTasks =>
      _deferredVideoCoordinator.hasPendingTasks;
  var _submittingDeferredInlineImages = false;
  var _deferredInlineImageTotal = 0;
  var _deferredInlineImageCompleted = 0;
  var _deferredInlineImageActiveProgress = 0.0;
  Future<void>? _deferredInlineImagePrefetchFuture;
  double? get _deferredShareVideoProgress {
    return _deferredVideoCoordinator.progress;
  }

  double? get _deferredInlineImageProgress {
    if (!_submittingDeferredInlineImages || _deferredInlineImageTotal <= 0) {
      return null;
    }
    return ((_deferredInlineImageCompleted +
                _deferredInlineImageActiveProgress.clamp(0, 1)) /
            _deferredInlineImageTotal)
        .clamp(0, 1);
  }

  void _applyDeferredInlineImageProgress(
    ShareDeferredInlineImageProgress progress,
  ) {
    void apply() {
      _submittingDeferredInlineImages = progress.active;
      _deferredInlineImageTotal = progress.total;
      _deferredInlineImageCompleted = progress.completed;
      _deferredInlineImageActiveProgress = progress.activeProgress;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  final _tagMenuKey = GlobalKey();
  final _templateMenuKey = GlobalKey();
  final _todoMenuKey = GlobalKey();
  final _visibilityMenuKey = GlobalKey();
  final _imagePicker = ImagePicker();
  final _templateRenderer = MemoTemplateRenderer();
  final _draftSession = const NoteInputDraftSessionHelper();
  final _pickedImages = <XFile>[];
  String? _activeDraftId;
  String _visibility = 'PRIVATE';
  bool _visibilityTouched = false;
  MemoLocation? _location;
  final _locating = false;
  var _presentationMode = _NoteInputSheetPresentationMode.compact;
  int get _tagAutocompleteIndex => _composer.tagAutocompleteIndex;
  ProviderSubscription<AsyncValue<UserGeneralSetting>>? _settingsSubscription;

  bool get _isFullscreenCompose =>
      _presentationMode == _NoteInputSheetPresentationMode.fullscreen;

  @override
  void initState() {
    super.initState();
    _noteDraftController = ref.read(noteDraftProvider.notifier);
    _shareInlineImageDownloadService =
        widget.shareInlineImageDownloadService ??
        ShareInlineImageDownloadService();
    _deferredInlineImageCoordinator = ShareDeferredInlineImageCoordinator(
      downloadService: _shareInlineImageDownloadService,
      cleanupFile: _cleanupShareVideoFile,
      onProgressChanged: _applyDeferredInlineImageProgress,
      isCancelled: () => !mounted,
    );
    _shareVideoDownloadService =
        widget.shareVideoDownloadService ?? ShareVideoDownloadService();
    _shareVideoCompressionService =
        widget.shareVideoCompressionService ?? ShareVideoCompressionService();
    _shareVideoAttachmentPreparer = ShareVideoAttachmentPreparer(
      downloadService: _shareVideoDownloadService,
      compressionService: _shareVideoCompressionService,
    );
    _deferredVideoCoordinator = ShareDeferredVideoCoordinator(
      resolveUploadSizeLimit: () =>
          ref.read(attachmentUploadSizeLimitResolverProvider).resolve(),
      confirmCompression: _confirmDeferredVideoCompression,
      admitPreparedAttachment: _admitPreparedDeferredVideoAttachment,
      preparer: _shareVideoAttachmentPreparer,
      cleanupFile: _cleanupShareVideoFile,
      onFailure: _showDeferredVideoFailureEvent,
      onChanged: _handleDeferredVideoCoordinatorChanged,
    );
    _composer = MemoComposerController(
      initialText: widget.initialText ?? '',
      initialSelection: widget.initialSelection,
    );
    _editorFocusNode = FocusNode();
    _keyboardResumeController = AndroidMemoKeyboardResumeController(
      focusNode: _editorFocusNode,
      isSurfaceEligible: () => mounted && !_busy,
      isRouteCurrent: _isKeyboardResumeRouteCurrent,
      isKeyboardVisible: _isKeyboardVisibleForResume,
    );
    _controller.addListener(_handleContentChanged);
    _controller.addListener(_scheduleDraftSave);
    _applyDefaultVisibility(ref.read(userGeneralSettingProvider));
    _loadTagStats();
    unawaited(_seedInitialAttachments());
    unawaited(_seedInitialDeferredInlineImages());
    unawaited(_seedInitialDeferredShareVideos());
    unawaited(_restoreInitialDraft());
    _settingsSubscription = ref.listenManual<AsyncValue<UserGeneralSetting>>(
      userGeneralSettingProvider,
      (prev, next) {
        _applyDefaultVisibility(next);
      },
    );
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.addHandler(_handleDesktopEditorShortcuts);
    }
  }

  @override
  void dispose() {
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.removeHandler(_handleDesktopEditorShortcuts);
    }
    _draftTimer?.cancel();
    _settingsSubscription?.close();
    _controller.removeListener(_handleContentChanged);
    _controller.removeListener(_scheduleDraftSave);
    // Defer provider mutation to avoid updating Riverpod state during unmount.
    unawaited(Future<void>(() => _saveCurrentDraft(triggerSync: false)));
    _keyboardResumeController.dispose();
    _composer.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  bool _isKeyboardResumeRouteCurrent() {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  bool _isKeyboardVisibleForResume() {
    if (!mounted) return false;
    final mediaQuery = MediaQuery.maybeOf(context);
    return (mediaQuery?.viewInsets.bottom ?? 0) > 0;
  }

  void _applyDefaultVisibility(AsyncValue<UserGeneralSetting> value) {
    if (_visibilityTouched) return;
    final settings = value.valueOrNull;
    if (settings == null) return;
    final visibility = (settings.memoVisibility ?? '').trim();
    if (visibility.isEmpty || visibility == _visibility) return;
    if (!mounted) {
      _visibility = visibility;
      return;
    }
    setState(() => _visibility = visibility);
  }

  Future<String?> _saveCurrentDraft({bool triggerSync = true}) async {
    if (widget.ignoreDraft) return null;
    final snapshot = _draftSession.buildSnapshot(
      content: _controller.text,
      visibility: _normalizedVisibility(),
      linkedMemos: _linkedMemos,
      pendingAttachments: _pendingAttachments,
      location: _location,
    );
    final repository = _composeDraftRepository;
    if (repository == null) return null;
    final nextDraftId = await repository.saveSnapshot(
      draftUid: _activeDraftId,
      snapshot: snapshot,
    );
    _activeDraftId = nextDraftId;
    await _persistLegacyNoteDraft(_controller.text, triggerSync: triggerSync);
    return nextDraftId;
  }

  Future<void> _persistLegacyNoteDraft(
    String text, {
    required bool triggerSync,
  }) async {
    if (mounted) {
      await _noteDraftController.setDraft(text, triggerSync: triggerSync);
      return;
    }
    final repository = _noteDraftRepository;
    if (repository == null) return;
    if (text.trim().isEmpty) {
      await repository.clear();
      return;
    }
    await repository.write(text);
  }

  void _restoreComposeDraft(ComposeDraftRecord draft) {
    final restored = _draftSession.restoreState(
      draft,
      defaultVisibility: _resolvedDefaultVisibility(),
    );
    _activeDraftId = restored.draftUid;
    _visibility = restored.visibility;
    _visibilityTouched = true;
    _location = restored.location;
    _thirdPartyShareInlineSourceByLocalUrl
      ..clear()
      ..addAll(restored.inlineSourceByLocalUrl);
    _pickedImages
      ..clear()
      ..addAll(restored.pickedImagePaths.map(XFile.new));
    _composer.replaceText(restored.content, clearHistory: true);
    _composer.setLinkedMemos(restored.linkedMemos);
    _composer.setPendingAttachments(restored.pendingAttachments);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _restoreInitialDraft() async {
    if (widget.ignoreDraft) return;
    final draftUid = widget.initialDraftUid?.trim();
    if (draftUid == null || draftUid.isEmpty) return;
    try {
      final draft = await ref
          .read(composeDraftRepositoryProvider)
          .getByUid(draftUid);
      if (!mounted || draft == null) return;
      _restoreComposeDraft(draft);
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'Failed to restore initial compose draft.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'draftUid': draftUid},
      );
    }
  }

  void _clearCurrentComposeState() {
    _activeDraftId = null;
    _location = null;
    _visibilityTouched = false;
    _visibility = _resolvedDefaultVisibility();
    _thirdPartyShareInlineSourceByLocalUrl.clear();
    _pickedImages.clear();
    _deferredInlineImageRequests.clear();
    _deferredVideoCoordinator.clear();
    _composer.replaceText('', clearHistory: true);
    _composer.clearPendingAttachments();
    _composer.clearLinkedMemos();
    unawaited(_noteDraftController.clear());
    if (mounted) {
      setState(() {});
    }
  }

  String _resolvedDefaultVisibility() {
    final settings = ref.read(userGeneralSettingProvider).valueOrNull;
    final value = (settings?.memoVisibility ?? '').trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  Future<void> _seedInitialAttachments() async {
    if (_didSeedInitialAttachments) return;
    _didSeedInitialAttachments = true;
    final paths = widget.initialAttachmentPaths;
    final seeds = widget.initialAttachmentSeeds;
    if (paths.isEmpty && seeds.isEmpty) return;

    final added = <_PendingAttachment>[];
    for (final seed in seeds) {
      final path = seed.filePath.trim();
      if (path.isEmpty) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      final actualSize = file.lengthSync();
      added.add(
        _PendingAttachment(
          uid: seed.uid,
          filePath: path,
          filename: seed.filename,
          mimeType: seed.mimeType,
          size: actualSize > 0 ? actualSize : seed.size,
          skipCompression: seed.skipCompression,
          shareInlineImage: seed.shareInlineImage,
          fromThirdPartyShare: seed.fromThirdPartyShare,
          sourceUrl: seed.sourceUrl,
        ),
      );
    }
    for (final raw in paths) {
      final path = raw.trim();
      if (path.isEmpty) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      final size = file.lengthSync();
      final filename = path.split(Platform.pathSeparator).last;
      final mimeType = guessAttachmentMimeType(filename);
      added.add(
        _PendingAttachment(
          uid: generateUid(),
          filePath: path,
          filename: filename,
          mimeType: mimeType,
          size: size,
        ),
      );
    }

    if (!mounted || added.isEmpty) return;
    await _addPendingAttachmentsStaged(added);
  }

  Future<void> _seedInitialDeferredShareVideos() async {
    if (_didSeedInitialDeferredVideos) return;
    _didSeedInitialDeferredVideos = true;
    final requests = widget.initialDeferredVideoAttachments;
    if (requests.isEmpty) return;

    if (!mounted) return;
    _deferredVideoCoordinator.addRequests(requests);
  }

  Future<void> _seedInitialDeferredInlineImages() async {
    if (_didSeedInitialDeferredInlineImages) return;
    _didSeedInitialDeferredInlineImages = true;
    final requests = widget.initialDeferredInlineImageAttachments;
    if (requests.isEmpty || !mounted) return;
    setState(() {
      _deferredInlineImageRequests.addAll(requests);
    });
    final future = _deferredInlineImagePrefetchFuture ??=
        _prefetchDeferredInlineImagesInComposer();
    unawaited(future);
  }

  Future<void> _prefetchDeferredInlineImagesInComposer() async {
    final requests = List<ShareDeferredInlineImageAttachmentRequest>.from(
      _deferredInlineImageRequests,
    );
    if (requests.isEmpty) {
      _deferredInlineImagePrefetchFuture = null;
      return;
    }

    try {
      await _deferredInlineImageCoordinator.processRequests(
        requests: requests,
        shouldProcess: (request) {
          if (!mounted) return false;
          return contentContainsShareInlineImageUrl(
            _controller.text,
            request.sourceUrl,
          );
        },
        onSkipped: (request) {
          if (mounted) {
            setState(() {
              _removeDeferredInlineImageRequest(request);
            });
          } else {
            _removeDeferredInlineImageRequest(request);
          }
        },
        handleSeed: (request, seed) =>
            _applyPrefetchedDeferredInlineImage(request: request, seed: seed),
      );
    } finally {
      _deferredInlineImagePrefetchFuture = null;
    }
  }

  Future<bool> _applyPrefetchedDeferredInlineImage({
    required ShareDeferredInlineImageAttachmentRequest request,
    required ShareAttachmentSeed seed,
  }) async {
    if (!mounted) return false;
    if (!contentContainsShareInlineImageUrl(
      _controller.text,
      request.sourceUrl,
    )) {
      setState(() {
        _removeDeferredInlineImageRequest(request);
      });
      return false;
    }

    final stagedAttachment = await _stagePendingAttachment(
      _PendingAttachment(
        uid: seed.uid,
        filePath: seed.filePath,
        filename: seed.filename,
        mimeType: seed.mimeType,
        size: seed.size,
        skipCompression: seed.skipCompression,
        shareInlineImage: true,
        fromThirdPartyShare: true,
        sourceUrl: request.sourceUrl,
      ),
    );
    final localUrl = shareInlineLocalUrlFromPath(stagedAttachment.filePath);
    if (localUrl.isEmpty) {
      setState(() {
        _removeDeferredInlineImageRequest(request);
      });
      return false;
    }

    final nextText = replaceShareInlineImageUrl(
      _controller.text,
      fromUrl: request.sourceUrl,
      toUrl: localUrl,
    );
    if (nextText == _controller.text) {
      setState(() {
        _removeDeferredInlineImageRequest(request);
      });
      return false;
    }

    setState(() {
      _thirdPartyShareInlineSourceByLocalUrl[localUrl] = request.sourceUrl;
      _composer.addPendingAttachments([stagedAttachment]);
      final caret = _controller.selection.extentOffset
          .clamp(0, nextText.length)
          .toInt();
      _controller.value = _controller.value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: caret),
        composing: TextRange.empty,
      );
      _removeDeferredInlineImageRequest(request);
    });
    return true;
  }

  void _removeDeferredInlineImageRequest(
    ShareDeferredInlineImageAttachmentRequest request,
  ) {
    _deferredInlineImageRequests.removeWhere(
      (item) => item.id == request.id && item.sourceUrl == request.sourceUrl,
    );
  }

  void _handleDeferredVideoCoordinatorChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _admitPreparedDeferredVideoAttachment(
    SharePreparedVideoAttachment prepared,
  ) async {
    if (!mounted) {
      await _cleanupShareVideoFile(prepared.filePath);
      return;
    }
    final stagedAttachment = await _stagePendingAttachment(
      _PendingAttachment(
        uid: generateUid(),
        filePath: prepared.filePath,
        filename: prepared.filename,
        mimeType: prepared.mimeType,
        size: prepared.size,
      ),
    );
    if (!mounted) {
      await _cleanupShareVideoFile(stagedAttachment.filePath);
      return;
    }
    setState(() {
      _composer.addPendingAttachments([stagedAttachment]);
    });
  }

  void _showDeferredVideoFailureEvent(ShareDeferredVideoFailureEvent event) {
    _showDeferredVideoFailure(
      event.failure,
      uploadSizeLimitBytes: event.uploadSizeLimitBytes,
    );
  }

  Future<void> _cleanupShareVideoFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<bool> _confirmDeferredVideoCompression(
    int fileSize,
    int maxBytes,
  ) async {
    final result = await showPlatformAlertDialog<bool>(
      context: context,
      title: shareVideoAttachmentTooLargeTitle(context.t, maxBytes),
      message: shareVideoAttachmentTooLargeBody(
        context.t,
        fileSizeBytes: fileSize,
        maxBytes: maxBytes,
      ),
      actions: [
        PlatformDialogAction<bool>(
          value: false,
          label: context.t.strings.common.cancel,
        ),
        PlatformDialogAction<bool>(
          value: true,
          label: context.t.strings.shareClip.compressAndSave,
          isDefault: true,
        ),
      ],
    );
    return result ?? false;
  }

  void _showDeferredVideoFailure(
    ShareDeferredVideoFailure failure, {
    int? uploadSizeLimitBytes,
  }) {
    if (!mounted) return;
    showTopToast(
      context,
      _deferredVideoFailureMessage(
        failure,
        uploadSizeLimitBytes: uploadSizeLimitBytes,
      ),
    );
  }

  String _deferredVideoFailureMessage(
    ShareDeferredVideoFailure failure, {
    int? uploadSizeLimitBytes,
  }) {
    return switch (failure) {
      ShareDeferredVideoFailure.downloadFailed =>
        context.t.strings.shareClip.fallbackDownloadFailed,
      ShareDeferredVideoFailure.compressionFailed =>
        context.t.strings.shareClip.fallbackCompressionFailed,
      ShareDeferredVideoFailure.compressionStillTooLarge =>
        shareVideoAttachmentStillTooLargeMessage(
          context.t,
          maxBytes: uploadSizeLimitBytes,
        ),
    };
  }

  Future<void> _openDeferredVideoPreview(ShareDeferredVideoTask task) async {
    await MediaPreviewLauncher.openVideo(
      context,
      MemoVideoEntry(
        id: task.id,
        title: task.title,
        mimeType: 'video/*',
        size: task.remoteSize ?? 0,
        videoUrl: task.request.candidate.url,
        thumbnailUrl: task.thumbnailUrl,
        headers: task.headers,
      ),
    );
  }

  Future<_PendingAttachment> _stagePendingAttachment(
    _PendingAttachment attachment,
  ) async {
    final staged = await ref
        .read(queuedAttachmentStagerProvider)
        .stageDraftAttachment(
          uid: attachment.uid,
          filePath: attachment.filePath,
          filename: attachment.filename,
          mimeType: attachment.mimeType,
          size: attachment.size,
          scopeKey: 'note_input_draft',
        );
    return attachment.copyWith(
      filePath: staged.filePath,
      filename: staged.filename,
      mimeType: staged.mimeType,
      size: staged.size,
      processingStatus: AttachmentProcessingStatus.ready,
      processingError: null,
    );
  }

  Future<List<_PendingAttachment>> _stagePendingAttachments(
    Iterable<_PendingAttachment> attachments,
  ) async {
    final pending = attachments.toList(growable: false);
    if (pending.isEmpty) return <_PendingAttachment>[];
    final staged = await ref
        .read(queuedAttachmentStagerProvider)
        .stageDraftAttachments(
          pending
              .map(
                (attachment) => DraftAttachmentStageRequest(
                  uid: attachment.uid,
                  filePath: attachment.filePath,
                  filename: attachment.filename,
                  mimeType: attachment.mimeType,
                  size: attachment.size,
                  scopeKey: 'note_input_draft',
                ),
              )
              .toList(growable: false),
        );
    return [
      for (var i = 0; i < pending.length; i++)
        pending[i].copyWith(
          filePath: staged[i].filePath,
          filename: staged[i].filename,
          mimeType: staged[i].mimeType,
          size: staged[i].size,
          processingStatus: AttachmentProcessingStatus.ready,
          processingError: null,
        ),
    ];
  }

  Future<void> _addPendingAttachmentsStaged(
    Iterable<_PendingAttachment> attachments,
  ) async {
    final pending = attachments.toList(growable: false);
    if (!mounted || pending.isEmpty) return;
    final admitted = pending
        .map(
          (attachment) => attachment.copyWith(
            processingStatus: AttachmentProcessingStatus.staging,
            processingError: null,
          ),
        )
        .toList(growable: false);
    setState(() {
      _composer.addPendingAttachments(admitted);
    });
    _scheduleDraftSave();
    unawaited(_stageAndReplacePendingAttachments(admitted));
  }

  Future<void> _stageAndReplacePendingAttachments(
    List<_PendingAttachment> attachments,
  ) async {
    try {
      final staged = await _stagePendingAttachments(attachments);
      if (!mounted) return;
      setState(() {
        for (final attachment in staged) {
          _composer.replacePendingAttachment(attachment.uid, attachment);
        }
      });
      _scheduleDraftSave();
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'NoteInput: stage_pending_attachments_failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        for (final attachment in attachments) {
          _composer.updatePendingAttachment(
            attachment.uid,
            (current) => current.copyWith(
              processingStatus: AttachmentProcessingStatus.failed,
              processingError: error.toString(),
            ),
          );
        }
      });
      _scheduleDraftSave();
    }
  }

  bool _ensurePendingAttachmentsReady() {
    final unready = _composer.unreadyPendingAttachments;
    if (unready.isEmpty) return true;
    final hasFailures = unready.any(
      (attachment) => attachment.hasProcessingFailure,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasFailures
              ? context.t.strings.legacy.msg_save_failed_check_content_retry
              : context.t.strings.legacy.msg_processing(
                  processed: _composer.readyPendingAttachmentCount,
                  total: _composer.pendingAttachments.length,
                ),
        ),
      ),
    );
    return false;
  }

  void _scheduleDraftSave() {
    if (widget.ignoreDraft) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveCurrentDraft());
    });
  }

  Future<void> _loadTagStats() async {
    try {
      final tags = await ref.read(tagStatsProvider.future);
      if (!mounted) return;
      setState(() => _tagStatsCache = tags);
    } catch (_) {}
  }

  void _undo() {
    if (!_composer.canUndo) return;
    _composer.undo();
    setState(() {});
  }

  void _redo() {
    if (!_composer.canRedo) return;
    _composer.redo();
    setState(() {});
  }

  Future<void> _openVisibilityMenuFromKey(GlobalKey key) async {
    if (_busy) return;
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    await _openVisibilityMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    );
  }

  Future<void> _openVisibilityMenu(RelativeRect position) async {
    if (_busy) return;
    final selection = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'PRIVATE',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_private_2),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'PROTECTED',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_protected),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'PUBLIC',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_public),
            ],
          ),
        ),
      ],
    );
    if (!mounted || selection == null) return;
    setState(() {
      _visibility = selection;
      _visibilityTouched = true;
    });
    _scheduleDraftSave();
  }

  String _normalizedVisibility() {
    final value = _visibility.trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  (String label, IconData icon, Color color) _resolveVisibilityStyle(
    BuildContext context,
    String raw,
  ) {
    switch (raw.trim().toUpperCase()) {
      case 'PUBLIC':
        return (
          context.t.strings.legacy.msg_public,
          Icons.public,
          const Color(0xFF3B8C52),
        );
      case 'PROTECTED':
        return (
          context.t.strings.legacy.msg_protected,
          Icons.verified_user,
          const Color(0xFFB26A2B),
        );
      default:
        return (
          context.t.strings.legacy.msg_private_2,
          Icons.lock,
          const Color(0xFF7C7C7C),
        );
    }
  }

  Future<void> _closeWithDraft() async {
    if (_busy) return;
    _draftTimer?.cancel();
    await _saveCurrentDraft();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  bool get _hasDraftBoxBlockingTasks {
    return _deferredInlineImageRequests.isNotEmpty ||
        _hasPendingDeferredShareVideoTasks ||
        _deferredInlineImagePrefetchFuture != null;
  }

  Future<void> _openDraftBox() async {
    if (_busy) return;
    if (_hasDraftBoxBlockingTasks) {
      showTopToast(
        context,
        context.tr(
          zh: '请等待附件准备完成，或先移除未完成的附件',
          en: 'Wait for attachments to finish preparing, or remove them first.',
        ),
      );
      return;
    }

    final currentDraftId = await _saveCurrentDraft();
    if (!mounted) return;
    if (widget.onOpenDraftBoxInHomeUtility?.call(_activeDraftId) ?? false) {
      await Navigator.of(context).maybePop();
      return;
    }
    final selection = await DraftBoxScreen.show(
      context,
      activeDraftId: _activeDraftId,
    );
    if (!mounted) return;

    if (selection != null && selection.isCreateMemoDraft) {
      final selectedDraft = await ref
          .read(composeDraftRepositoryProvider)
          .getByUid(selection.draftUid);
      if (!mounted || selectedDraft == null) return;
      _restoreComposeDraft(selectedDraft);
      return;
    }
    if (selection != null && selection.isEditMemoDraft) {
      showTopToast(
        context,
        context.tr(
          zh: '请从草稿箱页面打开编辑草稿',
          en: 'Open edit drafts from the Draft Box page.',
        ),
      );
      return;
    }

    if (currentDraftId != null && currentDraftId.isNotEmpty) {
      final existing = await ref
          .read(composeDraftRepositoryProvider)
          .getByUidWithoutLegacyImport(currentDraftId);
      if (!mounted) return;
      if (existing == null) {
        _clearCurrentComposeState();
      }
    }
  }

  void _insertText(String text, {int? caretOffset}) {
    _composer.insertText(text, caretOffset: caretOffset);
  }

  void _toggleBold() {
    _composer.toggleBold();
  }

  void _toggleUnderline() {
    _composer.toggleUnderline();
  }

  void _toggleHighlight() {
    _composer.toggleHighlight();
  }

  bool _handleDesktopEditorShortcuts(KeyEvent event) {
    if (!mounted || !isDesktopShortcutEnabled()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (!_editorFocusNode.hasFocus || _busy || event is! KeyDownEvent) {
      return false;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final bindings = normalizeDesktopShortcutBindings(
      ref.read(devicePreferencesProvider).desktopShortcutBindings,
    );
    bool matches(DesktopShortcutAction action) {
      return matchesDesktopShortcutAction(
        event: event,
        pressedKeys: pressed,
        bindings: bindings,
        action: action,
      );
    }

    final primaryPressed = isPrimaryShortcutModifierPressed(pressed);
    final shiftPressed = isShiftModifierPressed(pressed);
    final altPressed = isAltModifierPressed(pressed);
    final key = event.logicalKey;
    if (matches(DesktopShortcutAction.publishMemo) ||
        (!primaryPressed &&
            shiftPressed &&
            !altPressed &&
            key == LogicalKeyboardKey.enter)) {
      unawaited(_submitOrVoice());
      return true;
    }
    if (matches(DesktopShortcutAction.bold)) {
      _toggleBold();
      return true;
    }
    if (matches(DesktopShortcutAction.underline)) {
      _toggleUnderline();
      return true;
    }
    if (matches(DesktopShortcutAction.highlight)) {
      _toggleHighlight();
      return true;
    }
    if (matches(DesktopShortcutAction.unorderedList)) {
      _composer.toggleUnorderedList();
      return true;
    }
    if (matches(DesktopShortcutAction.orderedList)) {
      _composer.toggleOrderedList();
      return true;
    }
    if (matches(DesktopShortcutAction.undo)) {
      _undo();
      return true;
    }
    if (matches(DesktopShortcutAction.redo)) {
      _redo();
      return true;
    }
    return false;
  }

  void _handleContentChanged() {
    if (!mounted) return;
    _syncTagAutocompleteState();
    setState(() {});
  }

  void _syncTagAutocompleteState() {
    _composer.syncTagAutocompleteState(
      tagStats: _currentTagStats(),
      hasFocus: _editorFocusNode.hasFocus,
    );
  }

  void _dismissTagAutocompleteForExternalPicker() {
    if (_editorFocusNode.hasFocus) {
      _editorFocusNode.unfocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
    }
    _composer.syncTagAutocompleteState(
      tagStats: _currentTagStats(),
      hasFocus: false,
    );
  }

  List<TagStat> _currentTagStats() {
    return ref.read(tagStatsProvider).valueOrNull ?? _tagStatsCache;
  }

  KeyEventResult _handleTagAutocompleteKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    final result = _composer.handleTagAutocompleteKeyEvent(
      event,
      tagStats: _currentTagStats(),
      hasFocus: _editorFocusNode.hasFocus,
      requestFocus: _editorFocusNode.requestFocus,
    );
    if (result == KeyEventResult.handled) {
      setState(() {});
      return result;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final primaryPressed = isPrimaryShortcutModifierPressed(pressed);
    final shiftPressed = isShiftModifierPressed(pressed);
    final altPressed = isAltModifierPressed(pressed);
    final key = event.logicalKey;
    if (event is KeyDownEvent &&
        !primaryPressed &&
        !shiftPressed &&
        !altPressed &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        _composer.applyDesktopSmartEnter(
          lineBreak: isWindowsPlatform() ? '\r\n' : '\n',
        )) {
      setState(() {});
      return KeyEventResult.handled;
    }
    return result;
  }

  void _startTagAutocomplete() {
    if (_busy) return;
    _composer.startTagAutocomplete(requestFocus: _editorFocusNode.requestFocus);
    setState(() {});
  }

  void _applyTagSuggestion(ActiveTagQuery query, TagStat tag) {
    _composer.applyTagSuggestion(
      query,
      tag,
      requestFocus: _editorFocusNode.requestFocus,
    );
    setState(() {});
  }

  Future<void> _openTemplateMenuFromKey(
    GlobalKey key,
    List<MemoTemplate> templates,
  ) async {
    if (_busy) return;
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    await _openTemplateMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      templates,
    );
  }

  Future<void> _openTemplateMenu(
    RelativeRect position,
    List<MemoTemplate> templates,
  ) async {
    if (_busy) return;
    final items = templates.isEmpty
        ? <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              enabled: false,
              child: Text(context.t.strings.legacy.msg_no_templates_yet),
            ),
          ]
        : templates
              .map(
                (template) => PopupMenuItem<String>(
                  value: template.id,
                  child: Text(template.name),
                ),
              )
              .toList(growable: false);

    final selectedId = await showMenu<String>(
      context: context,
      position: position,
      items: items,
    );
    if (!mounted || selectedId == null) return;
    MemoTemplate? selected;
    for (final item in templates) {
      if (item.id == selectedId) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;
    await _applyTemplateToComposer(selected);
  }

  Future<void> _applyTemplateToComposer(MemoTemplate template) async {
    final templateSettings = ref.read(memoTemplateSettingsProvider);
    final locationSettings = ref.read(locationSettingsProvider);
    final rendered = await _templateRenderer.render(
      templateContent: template.content,
      variableSettings: templateSettings.variables,
      locationSettings: locationSettings,
    );
    if (!mounted) return;
    _composer.applyTemplateContent(rendered);
  }

  Future<void> _openTodoShortcutMenu(RelativeRect position) async {
    if (_busy) return;
    final action = await showMenu<MemoComposeTodoShortcutAction>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.checkbox,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_box_outlined, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_checkbox),
            ],
          ),
        ),
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.codeBlock,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.code, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_code_block),
            ],
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case MemoComposeTodoShortcutAction.checkbox:
        _composer.insertTaskCheckbox();
        break;
      case MemoComposeTodoShortcutAction.codeBlock:
        _composer.insertCodeBlock();
        break;
    }
  }

  Future<void> _openTodoShortcutMenuFromKey(GlobalKey key) async {
    if (_busy) return;
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    await _openTodoShortcutMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    );
  }

  Future<void> _openWindowsCameraSettings() async {
    if (!isWindowsPlatform()) return;
    try {
      await Process.start('cmd', <String>[
        '/c',
        'start',
        '',
        'ms-settings:privacy-webcam',
      ]);
    } catch (_) {}
  }

  bool _isWindowsCameraPermissionError(Object error) {
    if (!isWindowsPlatform()) return false;
    final message = error.toString().toLowerCase();
    return message.contains('permission') ||
        message.contains('access denied') ||
        message.contains('cameraaccessdenied') ||
        message.contains('privacy');
  }

  bool _isWindowsNoCameraError(Object error) {
    if (!isWindowsPlatform()) return false;
    final message = error.toString().toLowerCase();
    return message.contains('no camera') ||
        message.contains('no available camera') ||
        message.contains('no device') ||
        message.contains('camera_not_found') ||
        message.contains('camera not found') ||
        message.contains('capture device') ||
        message.contains('cameradelegate') ||
        message.contains('no capture devices') ||
        message.contains('unavailable');
  }

  Future<void> _requestLocation() async {
    if (_busy || _locating) return;
    final next = await showLocationPickerSheetOrDialog(
      context: context,
      ref: ref,
      openLocationSettings: openLocationSettingsSurface,
      initialLocation: _location,
    );
    if (!mounted || next == null) return;
    setState(() => _location = next);
    _scheduleDraftSave();
    showTopToast(
      context,
      context.t.strings.legacy.msg_location_updated(
        next_displayText_fractionDigits_6: next.displayText(fractionDigits: 6),
      ),
      duration: const Duration(seconds: 2),
    );
  }

  void _clearLocation() {
    if (_location == null) return;
    setState(() => _location = null);
    _scheduleDraftSave();
  }

  void _requestEditorFocusAfterLayout({
    required _NoteInputSheetPresentationMode expectedMode,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_presentationMode != expectedMode) return;
      _editorFocusNode.requestFocus();
    });
  }

  void _enterFullscreenCompose() {
    if (_busy || _isFullscreenCompose) return;
    if (_editorFocusNode.hasFocus) {
      _editorFocusNode.unfocus();
    }
    setState(() {
      _presentationMode = _NoteInputSheetPresentationMode.fullscreen;
    });
    _requestEditorFocusAfterLayout(
      expectedMode: _NoteInputSheetPresentationMode.fullscreen,
    );
  }

  void _collapseFullscreenCompose() {
    if (_busy || !_isFullscreenCompose) return;
    if (_editorFocusNode.hasFocus) {
      _editorFocusNode.unfocus();
    }
    setState(() {
      _presentationMode = _NoteInputSheetPresentationMode.compact;
    });
    _requestEditorFocusAfterLayout(
      expectedMode: _NoteInputSheetPresentationMode.compact,
    );
  }

  List<MemoComposeToolbarActionSpec> _buildComposeToolbarActions({
    required MemoToolbarPreferences preferences,
    required List<MemoTemplate> availableTemplates,
  }) {
    return <MemoComposeToolbarActionSpec>[
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.bold,
        enabled: !_busy,
        onPressed: _toggleBold,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.italic,
        enabled: !_busy,
        onPressed: _composer.toggleItalic,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.strikethrough,
        enabled: !_busy,
        onPressed: _composer.toggleStrikethrough,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.inlineCode,
        enabled: !_busy,
        onPressed: _composer.toggleInlineCode,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.list,
        enabled: !_busy,
        onPressed: _composer.toggleUnorderedList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.orderedList,
        enabled: !_busy,
        onPressed: _composer.toggleOrderedList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.taskList,
        enabled: !_busy,
        onPressed: _composer.toggleTaskList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.quote,
        enabled: !_busy,
        onPressed: _composer.toggleQuote,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading1,
        enabled: !_busy,
        onPressed: _composer.toggleHeading1,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading2,
        enabled: !_busy,
        onPressed: _composer.toggleHeading2,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading3,
        enabled: !_busy,
        onPressed: _composer.toggleHeading3,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.underline,
        enabled: !_busy,
        onPressed: _toggleUnderline,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.highlight,
        enabled: !_busy,
        onPressed: _toggleHighlight,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.divider,
        enabled: !_busy,
        onPressed: _composer.insertDivider,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.codeBlock,
        enabled: !_busy,
        onPressed: _composer.insertCodeBlock,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.inlineMath,
        enabled: !_busy,
        onPressed: _composer.insertInlineMath,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.blockMath,
        enabled: !_busy,
        onPressed: _composer.insertBlockMath,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.table,
        enabled: !_busy,
        onPressed: _composer.insertTableTemplate,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.cutParagraph,
        enabled: !_busy,
        onPressed: () => unawaited(_composer.cutCurrentParagraphs()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.undo,
        enabled: !_busy && _composer.canUndo,
        onPressed: _undo,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.redo,
        enabled: !_busy && _composer.canRedo,
        onPressed: _redo,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.tag,
        buttonKey: _tagMenuKey,
        enabled: !_busy,
        onPressed: _startTagAutocomplete,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.template,
        buttonKey: _templateMenuKey,
        enabled: !_busy,
        onPressed: () => unawaited(
          _openTemplateMenuFromKey(_templateMenuKey, availableTemplates),
        ),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.attachment,
        enabled: !_busy,
        onPressed: () => unawaited(_pickAttachments()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.gallery,
        enabled: !_busy,
        onPressed: () => unawaited(_handleGalleryToolbarPressed()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.todo,
        buttonKey: _todoMenuKey,
        enabled: !_busy,
        onPressed: () => unawaited(_openTodoShortcutMenuFromKey(_todoMenuKey)),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.link,
        enabled: !_busy,
        onPressed: () => unawaited(_openLinkMemoSheet()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.camera,
        enabled: !_busy,
        onPressed: () => unawaited(_capturePhoto()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.location,
        icon: _locating ? Icons.my_location : null,
        enabled: !_busy && !_locating,
        onPressed: () => unawaited(_requestLocation()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.draftBox,
        enabled: !_busy,
        onPressed: () => unawaited(_openDraftBox()),
      ),
      ...preferences.customButtons.map(
        (button) => MemoComposeToolbarActionSpec.custom(
          button: button,
          enabled: !_busy,
          onPressed: () => _insertText(button.insertContent),
        ),
      ),
    ];
  }

  Widget _buildComposeToolbar({
    required BuildContext context,
    required bool isDark,
    required MemoToolbarPreferences preferences,
    required List<MemoTemplate> availableTemplates,
    required String visibilityLabel,
    required IconData visibilityIcon,
    required Color visibilityColor,
  }) {
    final actions = _buildComposeToolbarActions(
      preferences: preferences,
      availableTemplates: availableTemplates,
    );

    return MemoComposeToolbar(
      isDark: isDark,
      preferences: preferences,
      actions: actions,
      visibilityMessage: context.t.strings.legacy.msg_visibility_2(
        visibilityLabel: visibilityLabel,
      ),
      visibilityIcon: visibilityIcon,
      visibilityColor: visibilityColor,
      visibilityButtonKey: _visibilityMenuKey,
      onVisibilityPressed: _busy
          ? null
          : () => unawaited(_openVisibilityMenuFromKey(_visibilityMenuKey)),
    );
  }

  Future<void> _openLinkMemoSheet() async {
    if (_busy) return;
    final selection = await LinkMemoSheet.show(
      context,
      existingNames: _linkedMemoNames,
    );
    if (!mounted || selection == null) return;
    _addLinkedMemo(selection);
  }

  Future<void> _handleGalleryToolbarPressed() async {
    if (!isMemoGalleryToolbarSupportedPlatform) {
      showTopToast(context, context.t.strings.legacy.msg_gallery_mobile_only);
      return;
    }
    await _pickGalleryAttachments();
  }

  Future<void> _pickGalleryAttachments() async {
    if (_busy) return;
    _dismissTagAutocompleteForExternalPicker();
    try {
      final compressionPolicy = ref.read(imageCompressionUiPolicyProvider);
      if (!mounted) return;
      final result = await pickGalleryAttachments(
        context,
        compressionPolicy: compressionPolicy,
      );
      if (!mounted || result == null) return;
      if (result.attachments.isEmpty) {
        final msg = result.skippedCount > 0
            ? context.t.strings.legacy.msg_files_unavailable_from_picker
            : context.t.strings.legacy.msg_no_files_selected;
        showTopToast(context, msg);
        return;
      }

      await _addPendingAttachmentsStaged(
        result.attachments
            .map(
              (attachment) => _PendingAttachment(
                uid: generateUid(),
                filePath: attachment.filePath,
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                size: attachment.size,
                skipCompression: attachment.skipCompression,
              ),
            )
            .toList(growable: false),
      );
      if (!mounted) return;
      final skipped = [
        if (result.skippedCount > 0)
          context.t.strings.legacy.msg_unavailable_file_count(
            count: result.skippedCount,
          ),
      ];
      final summary = skipped.isEmpty
          ? context.t.strings.legacy.msg_added_files(
              count: result.attachments.length,
            )
          : context.t.strings.legacy.msg_added_files_with_skipped(
              count: result.attachments.length,
              details: skipped.join(', '),
            );
      showTopToast(context, summary);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_file_selection_failed(error: e),
          ),
        ),
      );
    }
  }

  Future<void> _pickAttachments() async {
    if (_busy) return;
    _dismissTagAutocompleteForExternalPicker();
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withReadStream: true,
      );
      if (!mounted) return;
      final files = result?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;

      final added = <_PendingAttachment>[];
      var missingPathCount = 0;
      Directory? tempDir;
      for (final file in files) {
        final pickerPath = (file.path ?? '').trim();
        String path = pickerPath;
        var usedTemporaryFile = false;
        if (path.isEmpty) {
          final stream = file.readStream;
          final bytes = file.bytes;
          if (stream == null && bytes == null) {
            LogManager.instance.debug(
              'NoteInputSheet: file_picker_missing_path',
              context: {
                'pickerName': file.name,
                'pickerPath': pickerPath,
                'hasReadStream': false,
                'hasBytes': false,
              },
            );
            missingPathCount++;
            continue;
          }
          tempDir ??= await getTemporaryDirectory();
          final name = file.name.trim().isNotEmpty
              ? file.name.trim()
              : 'attachment_${generateUid()}';
          final tempFile = File(
            '${tempDir.path}${Platform.pathSeparator}${generateUid()}_$name',
          );
          if (bytes != null) {
            await tempFile.writeAsBytes(bytes, flush: true);
          } else if (stream != null) {
            final sink = tempFile.openWrite();
            await sink.addStream(stream);
            await sink.close();
          }
          path = tempFile.path;
          usedTemporaryFile = true;
        }

        if (path.trim().isEmpty) {
          LogManager.instance.debug(
            'NoteInputSheet: file_picker_empty_resolved_path',
            context: {
              'pickerName': file.name,
              'pickerPath': pickerPath,
              'usedTemporaryFile': usedTemporaryFile,
            },
          );
          missingPathCount++;
          continue;
        }

        final handle = File(path);
        if (!handle.existsSync()) {
          LogManager.instance.debug(
            'NoteInputSheet: file_picker_missing_file',
            context: {
              'pickerName': file.name,
              'pickerPath': pickerPath,
              'resolvedPath': path,
              'usedTemporaryFile': usedTemporaryFile,
            },
          );
          missingPathCount++;
          continue;
        }
        final size = handle.lengthSync();
        final filename = file.name.trim().isNotEmpty
            ? file.name.trim()
            : path.split(Platform.pathSeparator).last;
        final mimeType = guessAttachmentMimeType(filename);
        LogManager.instance.debug(
          'NoteInputSheet: file_picker_attachment_ready',
          context: {
            'pickerName': file.name,
            'pickerPath': pickerPath,
            'resolvedPath': path,
            'usedTemporaryFile': usedTemporaryFile,
            'hasReadStream': file.readStream != null,
            'hasBytes': file.bytes != null,
            'size': size,
            'mimeType': mimeType,
          },
        );
        added.add(
          _PendingAttachment(
            uid: generateUid(),
            filePath: path,
            filename: filename,
            mimeType: mimeType,
            size: size,
          ),
        );
      }
      LogManager.instance.debug(
        'NoteInputSheet: file_picker_summary',
        context: {
          'selectedCount': files.length,
          'addedCount': added.length,
          'missingPathCount': missingPathCount,
        },
      );

      if (!mounted) return;
      if (added.isEmpty) {
        final msg = missingPathCount > 0
            ? context.t.strings.legacy.msg_files_unavailable_from_picker
            : context.t.strings.legacy.msg_no_files_selected;
        showTopToast(context, msg);
        return;
      }

      await _addPendingAttachmentsStaged(added);
      if (!mounted) return;
      final skipped = [
        if (missingPathCount > 0)
          context.t.strings.legacy.msg_unavailable_file_count(
            count: missingPathCount,
          ),
      ];
      final summary = skipped.isEmpty
          ? context.t.strings.legacy.msg_added_files(count: added.length)
          : context.t.strings.legacy.msg_added_files_with_skipped(
              count: added.length,
              details: skipped.join(', '),
            );
      showTopToast(context, summary);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_file_selection_failed(error: e),
          ),
        ),
      );
    }
  }

  Future<void> _addVoiceAttachment(VoiceRecordResult result) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = result.filePath.trim();
    if (path.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_recording_path_missing),
        ),
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_recording_file_not_found_2,
          ),
        ),
      );
      return;
    }

    final size = result.size > 0 ? result.size : file.lengthSync();

    final filename = result.fileName.trim().isNotEmpty
        ? result.fileName.trim()
        : path.split(Platform.pathSeparator).last;
    final mimeType = guessAttachmentMimeType(filename);
    if (!mounted) return;
    await _addPendingAttachmentsStaged([
      _PendingAttachment(
        uid: generateUid(),
        filePath: path,
        filename: filename,
        mimeType: mimeType,
        size: size,
      ),
    ]);
    if (!mounted) return;
    showTopToast(context, context.t.strings.legacy.msg_added_voice_attachment);
  }

  Future<void> _capturePhoto() async {
    if (_busy) return;
    _dismissTagAutocompleteForExternalPicker();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final attachment = await captureCameraAttachment(
        navigator: Navigator.of(context),
        imagePicker: _imagePicker,
      );
      if (!mounted || attachment == null) return;
      final pendingAttachment = _PendingAttachment(
        uid: generateUid(),
        filePath: attachment.filePath,
        filename: attachment.filename,
        mimeType: attachment.mimeType,
        size: attachment.size,
        skipCompression: attachment.skipCompression,
      );
      await _addPendingAttachmentsStaged([pendingAttachment]);
      if (!mounted) return;
      setState(() {
        _pickedImages.add(XFile(pendingAttachment.filePath));
      });
      showTopToast(
        context,
        context.t.strings.legacy.msg_added_photo_attachment,
      );
    } on CameraAttachmentFileMissingException {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_camera_file_missing),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (_isWindowsNoCameraError(e)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_no_camera_detected),
          ),
        );
        return;
      }
      if (_isWindowsCameraPermissionError(e)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_camera_permission_denied_windows,
            ),
            action: SnackBarAction(
              label: context.t.strings.legacy.msg_settings,
              onPressed: () {
                unawaited(_openWindowsCameraSettings());
              },
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_camera_failed(error: e)),
        ),
      );
    }
  }

  void _removePendingAttachment(String uid) {
    final index = _pendingAttachments.indexWhere((a) => a.uid == uid);
    if (index < 0) return;
    final removed = _pendingAttachments[index];
    final localUrl = removed.shareInlineImage
        ? shareInlineLocalUrlFromPath(removed.filePath)
        : '';
    setState(() {
      if (localUrl.isNotEmpty) {
        _thirdPartyShareInlineSourceByLocalUrl.remove(localUrl);
        final nextText = removeShareInlineImageReferences(
          _controller.text,
          localUrl: localUrl,
        );
        if (nextText != _controller.text) {
          final caret = _controller.selection.extentOffset
              .clamp(0, nextText.length)
              .toInt();
          _controller.value = _controller.value.copyWith(
            text: nextText,
            selection: TextSelection.collapsed(offset: caret),
            composing: TextRange.empty,
          );
        }
      }
      _composer.removePendingAttachment(uid);
      _pickedImages.removeWhere((x) => x.path == removed.filePath);
    });
    _scheduleDraftSave();
    unawaited(
      ref
          .read(queuedAttachmentStagerProvider)
          .deleteManagedFile(removed.filePath),
    );
  }

  bool _isVideoMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('video');
  }

  File? _resolvePendingAttachmentFile(_PendingAttachment attachment) {
    final path = attachment.filePath.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String _pendingSourceId(String uid) => 'pending:$uid';

  List<({ImagePreviewItem item, _PendingAttachment attachment, File file})>
  _pendingImageSources() {
    final items =
        <({ImagePreviewItem item, _PendingAttachment attachment, File file})>[];
    for (final attachment in _pendingAttachments) {
      if (!isImageMimeType(attachment.mimeType)) continue;
      final file = _resolvePendingAttachmentFile(attachment);
      if (file == null) continue;
      items.add((
        item: pendingAttachmentToImagePreviewItem(
          attachment,
          sourceId: _pendingSourceId(attachment.uid),
          localFile: file,
        ),
        attachment: attachment,
        file: file,
      ));
    }
    return items;
  }

  Future<void> _openAttachmentViewer(_PendingAttachment attachment) async {
    final items = _pendingImageSources();
    if (items.isEmpty) return;
    final index = items.indexWhere(
      (item) => item.attachment.uid == attachment.uid,
    );
    if (index < 0) return;
    final previewItems = items.map((item) => item.item).toList(growable: false);
    await ImagePreviewLauncher.open(
      context,
      ImagePreviewOpenRequest(
        items: previewItems,
        initialIndex: index,
        onReplace: (result) => _replacePendingAttachment(
          EditedImageResult(
            sourceId: result.sourceId,
            filePath: result.filePath,
            filename: result.filename,
            mimeType: result.mimeType,
            size: result.size,
          ),
        ),
        enableDownload: true,
      ),
    );
  }

  Future<void> _replacePendingAttachment(EditedImageResult result) async {
    final id = result.sourceId;
    if (!id.startsWith('pending:')) return;
    final uid = id.substring('pending:'.length);
    final index = _pendingAttachments.indexWhere((a) => a.uid == uid);
    if (index < 0) return;
    final existing = _pendingAttachments[index];
    final stagedReplacement = await _stagePendingAttachment(
      _PendingAttachment(
        uid: uid,
        filePath: result.filePath,
        filename: result.filename,
        mimeType: result.mimeType,
        size: result.size,
        skipCompression: existing.skipCompression,
        shareInlineImage: existing.shareInlineImage,
        fromThirdPartyShare: existing.fromThirdPartyShare,
        sourceUrl: existing.sourceUrl,
      ),
    );
    setState(() {
      if (existing.shareInlineImage) {
        final oldLocalUrl = shareInlineLocalUrlFromPath(existing.filePath);
        final newLocalUrl = shareInlineLocalUrlFromPath(
          stagedReplacement.filePath,
        );
        final sourceUrl = _thirdPartyShareInlineSourceByLocalUrl.remove(
          oldLocalUrl,
        );
        if (sourceUrl != null && newLocalUrl.isNotEmpty) {
          _thirdPartyShareInlineSourceByLocalUrl[newLocalUrl] = sourceUrl;
        }
        final nextText = replaceShareInlineLocalUrlWithRemote(
          _controller.text,
          localUrl: oldLocalUrl,
          remoteUrl: newLocalUrl,
        );
        if (nextText != _controller.text) {
          final caret = _controller.selection.extentOffset
              .clamp(0, nextText.length)
              .toInt();
          _controller.value = _controller.value.copyWith(
            text: nextText,
            selection: TextSelection.collapsed(offset: caret),
            composing: TextRange.empty,
          );
        }
      }
      _composer.replacePendingAttachment(uid, stagedReplacement);
    });
    _scheduleDraftSave();
    if (existing.filePath != stagedReplacement.filePath) {
      unawaited(
        ref
            .read(queuedAttachmentStagerProvider)
            .deleteManagedFile(existing.filePath),
      );
    }
  }

  Widget _buildAttachmentPreview(bool isDark) {
    final deferredTasks = _visibleDeferredShareVideoTasks;
    const tileSize = 62.0;
    return NoteInputAttachmentPreviewStrip(
      tileSize: tileSize,
      deferredTiles: [
        for (final task in deferredTasks)
          _buildDeferredVideoTile(task, isDark: isDark, size: tileSize),
      ],
      pendingTiles: [
        for (final attachment in _pendingAttachments)
          _buildAttachmentTile(attachment, isDark: isDark, size: tileSize),
      ],
    );
  }

  Future<void> _openPendingVideoPreview(_PendingAttachment attachment) async {
    final file = _resolvePendingAttachmentFile(attachment);
    if (file == null) return;
    await MediaPreviewLauncher.openVideo(
      context,
      MemoVideoEntry(
        id: attachment.uid,
        title: attachment.filename,
        mimeType: attachment.mimeType,
        size: attachment.size,
        localFile: file,
      ),
    );
  }

  Widget _buildDeferredVideoTile(
    ShareDeferredVideoTask task, {
    required bool isDark,
    required double size,
  }) {
    final thumbnailUrl = task.thumbnailUrl?.trim() ?? '';
    return NoteInputDeferredVideoTile(
      isDark: isDark,
      size: size,
      thumbnailUrl: thumbnailUrl,
      headers: task.headers,
      progress: task.overallProgress,
      busy: _busy,
      isRemovable: task.isRemovable,
      onOpen: () => _openDeferredVideoPreview(task),
      onRemove: () => unawaited(_deferredVideoCoordinator.removeTask(task.id)),
    );
  }

  Widget _buildAttachmentTile(
    _PendingAttachment attachment, {
    required bool isDark,
    required double size,
  }) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final surfaceColor = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final iconColor =
        (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
            .withValues(alpha: 0.6);
    final removeBg = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.5);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.12);
    final tileBorderColor = borderColor.withValues(alpha: 0.7);
    final isImage = isImageMimeType(attachment.mimeType);
    final isVideo = _isVideoMimeType(attachment.mimeType);
    final file = _resolvePendingAttachmentFile(attachment);
    final cacheTarget = resolveNoteInputPendingImageThumbnailCacheTarget(
      tileSize: size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );

    Widget content;
    if (isImage && file != null) {
      content = ImagePreviewTile(
        item: pendingAttachmentToImagePreviewItem(
          attachment,
          sourceId: _pendingSourceId(attachment.uid),
          localFile: file,
        ),
        width: double.infinity,
        height: double.infinity,
        borderRadius: 14,
        backgroundColor: surfaceColor,
        borderColor: tileBorderColor,
        placeholderColor: surfaceColor,
        iconColor: iconColor,
        cacheWidth: cacheTarget.width,
        cacheHeight: cacheTarget.height,
        logScope: 'note_input_pending_tile',
      );
    } else if (isVideo && file != null) {
      final entry = MemoVideoEntry(
        id: attachment.uid,
        title: attachment.filename.isNotEmpty ? attachment.filename : 'video',
        mimeType: attachment.mimeType,
        size: attachment.size,
        localFile: file,
        videoUrl: null,
        headers: null,
      );
      content = AttachmentVideoThumbnail(
        entry: entry,
        width: size,
        height: size,
        borderRadius: 14,
        fit: BoxFit.cover,
        showPlayIcon: false,
      );
    } else {
      content = NoteInputAttachmentFallback(
        iconColor: iconColor,
        surfaceColor: surfaceColor,
        isImage: isImage,
        isVideo: isVideo,
      );
    }

    return NoteInputPendingAttachmentTile(
      isImage: isImage,
      isVideo: isVideo,
      hasFile: file != null,
      skipCompression: attachment.skipCompression,
      isReadyForSubmit: attachment.isReadyForSubmit,
      processingStatus: attachment.processingStatus,
      busy: _busy,
      size: size,
      surfaceColor: surfaceColor,
      tileBorderColor: tileBorderColor,
      shadowColor: shadowColor,
      removeBg: removeBg,
      content: content,
      originalBadgeLabel: context.t.strings.legacy.msg_original_image,
      onOpenImage: () => _openAttachmentViewer(attachment),
      onOpenVideo: () => _openPendingVideoPreview(attachment),
      onRemove: () => _removePendingAttachment(attachment.uid),
    );
  }

  Set<String> get _linkedMemoNames => _linkedMemos.map((m) => m.name).toSet();

  void _addLinkedMemo(Memo memo) {
    final name = memo.name.trim();
    if (name.isEmpty) return;
    if (_linkedMemos.any((m) => m.name == name)) return;
    final label = _linkedMemoLabel(memo);
    setState(() {
      _composer.addLinkedMemo(_LinkedMemo(name: name, label: label));
    });
    _scheduleDraftSave();
  }

  void _removeLinkedMemo(String name) {
    setState(() {
      _composer.removeLinkedMemo(name);
    });
    _scheduleDraftSave();
  }

  String _linkedMemoLabel(Memo memo) {
    final raw = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isNotEmpty) {
      return _truncateLabel(raw);
    }
    final name = memo.name.trim();
    if (name.isNotEmpty) {
      return _truncateLabel(
        name.startsWith('memos/') ? name.substring('memos/'.length) : name,
      );
    }
    return _truncateLabel(memo.uid);
  }

  String _truncateLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  Future<void> _submitOrVoice() async {
    if (_busy) return;
    if (_hasPendingDeferredShareVideoTasks) return;
    var draft = _buildSubmitDraft();
    if (draft.content.trim().isEmpty &&
        !draft.hasReferencedPendingAttachments) {
      if (draft.relations.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_enter_content_before_creating_link,
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final result = await VoiceRecordScreen.showOverlay(
        context,
        autoStart: true,
        startLocked: true,
        mode: VoiceRecordMode.quickFabCompose,
      );
      if (!mounted || result == null) return;
      await _addVoiceAttachment(result);
      return;
    }
    if (!_ensurePendingAttachmentsReady()) return;

    setState(() => _busy = true);
    try {
      final prefetchFuture = _deferredInlineImagePrefetchFuture;
      if (prefetchFuture != null) {
        await prefetchFuture;
      }

      draft = _buildSubmitDraft();
      if (!_ensurePendingAttachmentsReady()) return;

      final result = await ref
          .read(noteInputSubmitCoordinatorProvider)
          .submit(draft, logShareSaveFlow: widget.showLocalSaveSuccessToast);

      await _processDeferredInlineImagesAfterSubmit(
        memoUid: result.memoUid,
        requests: result.deferredInlineImageRequests,
      );

      final submittedDraftId = _activeDraftId;
      _draftTimer?.cancel();
      _composer.replaceText('', clearHistory: true);
      _composer.clearLinkedMemos();
      _composer.clearPendingAttachments();
      _deferredInlineImageRequests.clear();
      _pickedImages.clear();
      await ref.read(noteDraftProvider.notifier).clear();
      _activeDraftId = null;
      if (submittedDraftId != null && submittedDraftId.isNotEmpty) {
        final keepPaths = _draftSession.keepPathsForSubmittedDraft(
          result.pendingUploads.map((attachment) => attachment.filePath),
        );
        await ref
            .read(composeDraftRepositoryProvider)
            .deleteDraft(submittedDraftId, keepPaths: keepPaths);
      }

      if (!mounted) return;
      if (widget.showLocalSaveSuccessToast) {
        showTopToast(
          context,
          context.t.strings.shareClip.localSavedPendingSync,
        );
      }
      context.safePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_create_failed_2(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  NoteInputSubmitDraft _buildSubmitDraft() {
    return NoteInputSubmitDraft(
      content: _controller.text.trimRight(),
      visibility: _normalizedVisibility(),
      location: _location,
      relations: _linkedMemos
          .map((memo) => memo.toRelationJson())
          .toList(growable: false),
      pendingAttachments: List<_PendingAttachment>.from(_pendingAttachments),
      deferredInlineImageRequests:
          List<ShareDeferredInlineImageAttachmentRequest>.from(
            _deferredInlineImageRequests,
          ),
      clipMetadataDraft: widget.initialClipMetadataDraft,
    );
  }

  Future<void> _processDeferredInlineImagesAfterSubmit({
    required String memoUid,
    required List<ShareDeferredInlineImageAttachmentRequest> requests,
  }) async {
    if (requests.isEmpty) return;
    await _deferredInlineImageCoordinator.processRequests(
      requests: requests,
      shouldProcess: (_) => true,
      handleSeed: (request, seed) async {
        await ref
            .read(noteInputControllerProvider)
            .appendDeferredThirdPartyShareInlineImage(
              memoUid: memoUid,
              sourceUrl: request.sourceUrl,
              attachment: noteInputPendingUploadFromShareAttachmentSeed(
                seed,
                sourceUrl: request.sourceUrl,
              ),
            );
        return true;
      },
    );
  }

  Widget _buildFullscreenCompose({
    required bool isDark,
    required Color sheetColor,
    required Color chipBg,
    required Color chipText,
    required Color chipDelete,
    required String visibilityLabel,
    required IconData visibilityIcon,
    required Color visibilityColor,
    required List<TagStat> tagSuggestions,
    required int highlightedTagSuggestionIndex,
    required TagColorLookup tagColorLookup,
    required ActiveTagQuery? activeTagQuery,
    required TextStyle editorTextStyle,
    required MemoToolbarPreferences toolbarPreferences,
    required List<MemoTemplate> availableTemplates,
    required String editorHintText,
  }) {
    final toolbarActions = _buildComposeToolbarActions(
      preferences: toolbarPreferences,
      availableTemplates: availableTemplates,
    );
    return NoteInputFullscreenCompose(
      isDark: isDark,
      sheetColor: sheetColor,
      chipBg: chipBg,
      chipText: chipText,
      chipDelete: chipDelete,
      visibilityLabel: visibilityLabel,
      visibilityIcon: visibilityIcon,
      visibilityColor: visibilityColor,
      tagSuggestions: tagSuggestions,
      highlightedTagSuggestionIndex: highlightedTagSuggestionIndex,
      tagColorLookup: tagColorLookup,
      activeTagQuery: activeTagQuery,
      editorTextStyle: editorTextStyle,
      toolbarPreferences: toolbarPreferences,
      toolbarActions: toolbarActions,
      editorHintText: editorHintText,
      attachmentPreview: _buildAttachmentPreview(isDark),
      linkedMemos: _linkedMemos,
      location: _location,
      locating: _locating,
      busy: _busy,
      controller: _controller,
      editorFocusNode: _editorFocusNode,
      editorFieldKey: _editorFieldKey,
      autoFocus: widget.autoFocus,
      deferredProgress:
          _deferredInlineImageProgress ?? _deferredShareVideoProgress,
      hasPendingDeferredShareVideoTasks: _hasPendingDeferredShareVideoTasks,
      hasAttachmentsForSend:
          _pendingAttachments.isNotEmpty ||
          _deferredInlineImageRequests.isNotEmpty ||
          _visibleDeferredShareVideoTasks.isNotEmpty,
      expandCollapseKey: _fullscreenCollapseButtonKey,
      closeKey: _fullscreenCloseButtonKey,
      topToolbarKey: _fullscreenTopToolbarKey,
      bottomToolbarKey: _fullscreenBottomToolbarKey,
      sendButtonKey: _fullscreenSendButtonKey,
      visibilityButtonKey: _visibilityMenuKey,
      onCollapse: _collapseFullscreenCompose,
      onClose: () => unawaited(_closeWithDraft()),
      onVisibilityPressed: () =>
          unawaited(_openVisibilityMenuFromKey(_visibilityMenuKey)),
      onSubmitOrVoice: _submitOrVoice,
      onRemoveLinkedMemo: _removeLinkedMemo,
      onRequestLocation: () => unawaited(_requestLocation()),
      onClearLocation: _clearLocation,
      onTagHighlight: (index) {
        if (_tagAutocompleteIndex == index) return;
        setState(() {
          _composer.setTagAutocompleteIndex(index);
        });
      },
      onTagSelect: _applyTagSuggestion,
      onEditorKeyEvent: _handleTagAutocompleteKeyEvent,
    );
  }

  @override
  Widget build(BuildContext context) {
    _composeDraftRepository = ref.watch(composeDraftRepositoryProvider);
    _noteDraftRepository = ref.watch(noteDraftRepositoryProvider);
    _keyboardResumeController.updateKeyboardVisibility();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : MemoFlowPalette.audioSurfaceLight;
    final chipText = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final chipDelete = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.grey.shade500;
    final (visibilityLabel, visibilityIcon, visibilityColor) =
        _resolveVisibilityStyle(context, _visibility);
    final tagStats = ref.watch(tagStatsProvider).valueOrNull ?? _tagStatsCache;
    final activeTagQuery = detectActiveTagQuery(_controller.value);
    final tagColorLookup = ref.watch(tagColorLookupProvider);
    final tagSuggestions = activeTagQuery == null
        ? const <TagStat>[]
        : buildTagSuggestions(tagStats, query: activeTagQuery.query);
    final highlightedTagSuggestionIndex = tagSuggestions.isEmpty
        ? 0
        : _tagAutocompleteIndex.clamp(0, tagSuggestions.length - 1).toInt();
    final editorTextStyle = TextStyle(
      fontSize: 17,
      height: 1.35,
      color: textColor,
    );
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
    final toolbarPreferences = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (p) => p.memoToolbarPreferences,
      ),
    );
    final pendingDraftCount = ref.watch(composeDraftCountProvider);
    final availableTemplates = templateSettings.enabled
        ? templateSettings.templates
        : const <MemoTemplate>[];
    final shouldShowDraftHint = shouldShowComposeDraftHint(
      enableDraftHint: !widget.ignoreDraft,
      pendingDraftCount: pendingDraftCount,
      hasCurrentComposeContent:
          _controller.text.trim().isNotEmpty ||
          _pendingAttachments.isNotEmpty ||
          _linkedMemos.isNotEmpty ||
          _location != null ||
          _deferredInlineImageRequests.isNotEmpty ||
          _visibleDeferredShareVideoTasks.isNotEmpty,
    );
    final editorHintText = shouldShowDraftHint
        ? context.t.strings.legacy.msg_draft_box_pending_hint(
            count: pendingDraftCount,
          )
        : context.t.strings.legacy.msg_write_thoughts;

    if (_isFullscreenCompose) {
      return _buildFullscreenCompose(
        isDark: isDark,
        sheetColor: sheetColor,
        chipBg: chipBg,
        chipText: chipText,
        chipDelete: chipDelete,
        visibilityLabel: visibilityLabel,
        visibilityIcon: visibilityIcon,
        visibilityColor: visibilityColor,
        tagSuggestions: tagSuggestions,
        highlightedTagSuggestionIndex: highlightedTagSuggestionIndex,
        tagColorLookup: tagColorLookup,
        activeTagQuery: activeTagQuery,
        editorTextStyle: editorTextStyle,
        toolbarPreferences: toolbarPreferences,
        availableTemplates: availableTemplates,
        editorHintText: editorHintText,
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isDark ? 4 : 2,
          sigmaY: isDark ? 4 : 2,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeWithDraft,
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sheetColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          border: isDark
                              ? Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.5 : 0.12,
                              ),
                              blurRadius: 40,
                              offset: const Offset(0, -10),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NoteInputCompactHeader(
                                isDark: isDark,
                                busy: _busy,
                                expandButtonKey: _fullscreenExpandButtonKey,
                                onExpand: _enterFullscreenCompose,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 160,
                                    maxHeight: 340,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildAttachmentPreview(isDark),
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            KeyedSubtree(
                                              key: _editorFieldKey,
                                              child: Focus(
                                                canRequestFocus: false,
                                                onKeyEvent:
                                                    _handleTagAutocompleteKeyEvent,
                                                child: PlatformTextField(
                                                  controller: _controller,
                                                  focusNode: _editorFocusNode,
                                                  autofocus: widget.autoFocus,
                                                  inputFormatters: const [
                                                    SmartEnterTextInputFormatter(),
                                                  ],
                                                  maxLines: null,
                                                  keyboardType:
                                                      TextInputType.multiline,
                                                  style: editorTextStyle,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    border: InputBorder.none,
                                                    hintText: editorHintText,
                                                    hintStyle: TextStyle(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF666666,
                                                            )
                                                          : Colors
                                                                .grey
                                                                .shade500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_editorFocusNode.hasFocus &&
                                                activeTagQuery != null &&
                                                tagSuggestions.isNotEmpty)
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: TagAutocompleteOverlay(
                                                    editorKey: _editorFieldKey,
                                                    focusNode: _editorFocusNode,
                                                    value: _controller.value,
                                                    textStyle: editorTextStyle,
                                                    tags: tagSuggestions,
                                                    tagColors: tagColorLookup,
                                                    highlightedIndex:
                                                        highlightedTagSuggestionIndex,
                                                    onHighlight: (index) {
                                                      if (_tagAutocompleteIndex ==
                                                          index) {
                                                        return;
                                                      }
                                                      setState(() {
                                                        _composer
                                                            .setTagAutocompleteIndex(
                                                              index,
                                                            );
                                                      });
                                                    },
                                                    onSelect: (tag) =>
                                                        _applyTagSuggestion(
                                                          activeTagQuery,
                                                          tag,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              NoteInputLinkedMemoChips(
                                linkedMemos: _linkedMemos,
                                chipBg: chipBg,
                                chipText: chipText,
                                chipDelete: chipDelete,
                                busy: _busy,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  8,
                                ),
                                onRemove: _removeLinkedMemo,
                              ),
                              NoteInputLocationState(
                                location: _location,
                                locating: _locating,
                                chipBg: chipBg,
                                chipText: chipText,
                                chipDelete: chipDelete,
                                busy: _busy,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  8,
                                ),
                                onRequestLocation: () =>
                                    unawaited(_requestLocation()),
                                onClearLocation: _clearLocation,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  18,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildComposeToolbar(
                                        context: context,
                                        isDark: isDark,
                                        preferences: toolbarPreferences,
                                        availableTemplates: availableTemplates,
                                        visibilityLabel: visibilityLabel,
                                        visibilityIcon: visibilityIcon,
                                        visibilityColor: visibilityColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    NoteInputCompactSendButton(
                                      isDark: isDark,
                                      busy: _busy,
                                      deferredProgress:
                                          _deferredInlineImageProgress ??
                                          _deferredShareVideoProgress,
                                      hasPendingDeferredShareVideoTasks:
                                          _hasPendingDeferredShareVideoTasks,
                                      hasAttachmentsForSend:
                                          _pendingAttachments.isNotEmpty ||
                                          _deferredInlineImageRequests
                                              .isNotEmpty ||
                                          _visibleDeferredShareVideoTasks
                                              .isNotEmpty,
                                      controller: _controller,
                                      onPressed: _submitOrVoice,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
