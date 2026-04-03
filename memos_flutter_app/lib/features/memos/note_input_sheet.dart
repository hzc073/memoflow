import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../core/app_localization.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/image_thumbnail_cache.dart';
import '../../core/markdown_editing.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../data/models/compose_draft.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/user_setting.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/attachments/queued_attachment_stager_provider.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import '../../state/settings/image_bed_settings_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/note_draft_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../../state/settings/user_settings_provider.dart';
import '../../state/memos/note_input_providers.dart';
import '../share/share_clip_models.dart';
import '../share/share_inline_image_content.dart';
import '../share/share_inline_image_download_service.dart';
import '../share/share_video_compression_service.dart';
import '../share/share_video_download_service.dart';
import 'attachment_gallery_screen.dart';
import 'attachment_video_screen.dart';
import 'compose_input_hint.dart';
import 'compose_toolbar_shared.dart';
import 'draft_box_screen.dart';
import 'gallery_attachment_picker.dart';
import 'memo_video_grid.dart';
import 'tag_autocomplete.dart';
import 'link_memo_sheet.dart';
import 'windows_camera_capture_screen.dart';
import '../voice/voice_record_screen.dart';
import '../location_picker/show_location_picker.dart';
import '../../i18n/strings.g.dart';

typedef _PendingAttachment = MemoComposerPendingAttachment;
typedef _LinkedMemo = MemoComposerLinkedMemo;

enum _DeferredShareVideoPhase {
  preparing,
  downloading,
  awaitingCompression,
  compressing,
  completed,
  removed,
}

enum _DeferredShareVideoFailure {
  downloadFailed,
  compressionFailed,
  compressionStillTooLarge,
}

class _DeferredShareVideoTask {
  _DeferredShareVideoTask({required this.request});

  final ShareDeferredVideoAttachmentRequest request;
  Map<String, String> headers = const <String, String>{};
  int? remoteSize;
  double progress = 0;
  _DeferredShareVideoPhase phase = _DeferredShareVideoPhase.preparing;
  bool cancelled = false;

  String get id => request.id;

  String get title => request.title;

  String? get thumbnailUrl => request.thumbnailUrl;

  bool get isPending =>
      !cancelled &&
      phase != _DeferredShareVideoPhase.completed &&
      phase != _DeferredShareVideoPhase.removed;

  bool get isRemovable => phase != _DeferredShareVideoPhase.completed;

  double get overallProgress {
    return switch (phase) {
      _DeferredShareVideoPhase.preparing => 0,
      _DeferredShareVideoPhase.downloading => progress.clamp(0, 1) * 0.72,
      _DeferredShareVideoPhase.awaitingCompression => 0.72,
      _DeferredShareVideoPhase.compressing =>
        0.72 + progress.clamp(0, 1) * 0.28,
      _DeferredShareVideoPhase.completed ||
      _DeferredShareVideoPhase.removed => 1,
    };
  }
}

class NoteInputSheet extends ConsumerStatefulWidget {
  const NoteInputSheet({
    super.key,
    this.initialText,
    this.initialSelection,
    this.initialAttachmentPaths = const [],
    this.initialAttachmentSeeds = const [],
    this.initialDeferredInlineImageAttachments = const [],
    this.initialDeferredVideoAttachments = const [],
    this.ignoreDraft = false,
    this.autoFocus = true,
    this.shareInlineImageDownloadService,
    this.shareVideoDownloadService,
    this.shareVideoCompressionService,
  });

  final String? initialText;
  final TextSelection? initialSelection;
  final List<String> initialAttachmentPaths;
  final List<ShareAttachmentSeed> initialAttachmentSeeds;
  final List<ShareDeferredInlineImageAttachmentRequest>
  initialDeferredInlineImageAttachments;
  final List<ShareDeferredVideoAttachmentRequest>
  initialDeferredVideoAttachments;
  final bool ignoreDraft;
  final bool autoFocus;
  final ShareInlineImageDownloadService? shareInlineImageDownloadService;
  final ShareVideoDownloadService? shareVideoDownloadService;
  final ShareVideoCompressionService? shareVideoCompressionService;

  static Future<void> show(
    BuildContext context, {
    String? initialText,
    TextSelection? initialSelection,
    List<String> initialAttachmentPaths = const [],
    List<ShareAttachmentSeed> initialAttachmentSeeds = const [],
    List<ShareDeferredInlineImageAttachmentRequest>
        initialDeferredInlineImageAttachments =
        const [],
    List<ShareDeferredVideoAttachmentRequest> initialDeferredVideoAttachments =
        const [],
    bool ignoreDraft = false,
    bool autoFocus = true,
    ShareInlineImageDownloadService? shareInlineImageDownloadService,
    ShareVideoDownloadService? shareVideoDownloadService,
    ShareVideoCompressionService? shareVideoCompressionService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.05),
      builder: (context) => NoteInputSheet(
        initialText: initialText,
        initialSelection: initialSelection,
        initialAttachmentPaths: initialAttachmentPaths,
        initialAttachmentSeeds: initialAttachmentSeeds,
        initialDeferredInlineImageAttachments:
            initialDeferredInlineImageAttachments,
        initialDeferredVideoAttachments: initialDeferredVideoAttachments,
        ignoreDraft: ignoreDraft,
        autoFocus: autoFocus,
        shareInlineImageDownloadService: shareInlineImageDownloadService,
        shareVideoDownloadService: shareVideoDownloadService,
        shareVideoCompressionService: shareVideoCompressionService,
      ),
    );
  }

  @override
  ConsumerState<NoteInputSheet> createState() => _NoteInputSheetState();
}

class _NoteInputSheetState extends ConsumerState<NoteInputSheet> {
  late final MemoComposerController _composer;
  late final FocusNode _editorFocusNode;
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
  late final ShareVideoDownloadService _shareVideoDownloadService;
  late final ShareVideoCompressionService _shareVideoCompressionService;
  final List<ShareDeferredInlineImageAttachmentRequest>
  _deferredInlineImageRequests = [];
  final Map<String, String> _thirdPartyShareInlineSourceByLocalUrl = {};
  final List<_DeferredShareVideoTask> _deferredShareVideoTasks = [];
  List<_LinkedMemo> get _linkedMemos => _composer.linkedMemos;
  List<_PendingAttachment> get _pendingAttachments =>
      _composer.pendingAttachments;
  List<_DeferredShareVideoTask> get _visibleDeferredShareVideoTasks =>
      _deferredShareVideoTasks
          .where((task) => task.phase != _DeferredShareVideoPhase.removed)
          .toList(growable: false);
  bool get _hasPendingDeferredShareVideoTasks =>
      _deferredShareVideoTasks.any((task) => task.isPending);
  var _submittingDeferredInlineImages = false;
  var _deferredInlineImageTotal = 0;
  var _deferredInlineImageCompleted = 0;
  var _deferredInlineImageActiveProgress = 0.0;
  Future<void>? _deferredInlineImagePrefetchFuture;
  double? get _deferredShareVideoProgress {
    final active = _deferredShareVideoTasks
        .where((task) => task.isPending)
        .toList(growable: false);
    if (active.isEmpty) return null;
    final total = active.fold<double>(
      0,
      (sum, task) => sum + task.overallProgress,
    );
    return (total / active.length).clamp(0, 1);
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

  final _tagMenuKey = GlobalKey();
  final _templateMenuKey = GlobalKey();
  final _todoMenuKey = GlobalKey();
  final _visibilityMenuKey = GlobalKey();
  final _imagePicker = ImagePicker();
  final _templateRenderer = MemoTemplateRenderer();
  final _pickedImages = <XFile>[];
  String? _activeDraftId;
  String _visibility = 'PRIVATE';
  bool _visibilityTouched = false;
  MemoLocation? _location;
  final _locating = false;
  int get _tagAutocompleteIndex => _composer.tagAutocompleteIndex;
  ProviderSubscription<AsyncValue<UserGeneralSetting>>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _noteDraftController = ref.read(noteDraftProvider.notifier);
    _shareInlineImageDownloadService =
        widget.shareInlineImageDownloadService ??
        ShareInlineImageDownloadService();
    _shareVideoDownloadService =
        widget.shareVideoDownloadService ?? ShareVideoDownloadService();
    _shareVideoCompressionService =
        widget.shareVideoCompressionService ?? ShareVideoCompressionService();
    _composer = MemoComposerController(
      initialText: widget.initialText ?? '',
      initialSelection: widget.initialSelection,
    );
    _editorFocusNode = FocusNode();
    _controller.addListener(_handleContentChanged);
    _controller.addListener(_scheduleDraftSave);
    _applyDefaultVisibility(ref.read(userGeneralSettingProvider));
    _loadTagStats();
    unawaited(_seedInitialAttachments());
    unawaited(_seedInitialDeferredInlineImages());
    unawaited(_seedInitialDeferredShareVideos());
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
    _composer.dispose();
    _editorFocusNode.dispose();
    super.dispose();
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
    final snapshot = _buildCurrentDraftSnapshot();
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

  ComposeDraftSnapshot _buildCurrentDraftSnapshot() {
    return ComposeDraftSnapshot(
      content: _controller.text,
      visibility: _normalizedVisibility(),
      relations: _linkedMemos
          .map((memo) => memo.toRelationJson())
          .toList(growable: false),
      attachments: _pendingAttachments
          .map(ComposeDraftAttachment.fromPendingAttachment)
          .toList(growable: false),
      location: _location,
    );
  }

  void _restoreComposeDraft(ComposeDraftRecord draft) {
    final snapshot = draft.snapshot;
    final linkedMemos = _linkedMemosFromRelations(snapshot.relations);
    final pendingAttachments = snapshot.attachments
        .map((attachment) => attachment.toPendingAttachment())
        .toList(growable: false);
    final pickedImages = pendingAttachments
        .where((attachment) => _isImageMimeType(attachment.mimeType))
        .map((attachment) => XFile(attachment.filePath))
        .toList(growable: false);
    final inlineSourceMap = <String, String>{};
    for (final attachment in snapshot.attachments) {
      final sourceUrl = attachment.sourceUrl?.trim();
      if (!attachment.shareInlineImage ||
          sourceUrl == null ||
          sourceUrl.isEmpty) {
        continue;
      }
      final localUrl = shareInlineLocalUrlFromPath(attachment.filePath);
      if (localUrl.isNotEmpty) {
        inlineSourceMap[localUrl] = sourceUrl;
      }
    }

    _activeDraftId = draft.uid;
    _visibility = snapshot.visibility.trim().isEmpty
        ? _resolvedDefaultVisibility()
        : snapshot.visibility.trim();
    _visibilityTouched = true;
    _location = snapshot.location;
    _thirdPartyShareInlineSourceByLocalUrl
      ..clear()
      ..addAll(inlineSourceMap);
    _pickedImages
      ..clear()
      ..addAll(pickedImages);
    _composer.replaceText(snapshot.content, clearHistory: true);
    _composer.setLinkedMemos(linkedMemos);
    _composer.setPendingAttachments(pendingAttachments);
    if (mounted) {
      setState(() {});
    }
  }

  List<_LinkedMemo> _linkedMemosFromRelations(
    List<Map<String, dynamic>> relations,
  ) {
    final linked = <_LinkedMemo>[];
    final seenNames = <String>{};
    for (final relation in relations) {
      final relatedMemoRaw = relation['relatedMemo'];
      if (relatedMemoRaw is! Map) continue;
      final name = (relatedMemoRaw['name'] as String? ?? '').trim();
      if (name.isEmpty || !seenNames.add(name)) continue;
      final label = name.startsWith('memos/') ? name.substring(6) : name;
      linked.add(_LinkedMemo(name: name, label: label));
    }
    return linked;
  }

  void _clearCurrentComposeState() {
    _activeDraftId = null;
    _location = null;
    _visibilityTouched = false;
    _visibility = _resolvedDefaultVisibility();
    _thirdPartyShareInlineSourceByLocalUrl.clear();
    _pickedImages.clear();
    _deferredInlineImageRequests.clear();
    _deferredShareVideoTasks.clear();
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
      final mimeType = _guessMimeType(filename);
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

    final tasks = requests
        .map((request) => _DeferredShareVideoTask(request: request))
        .toList(growable: false);
    if (!mounted) return;
    setState(() => _deferredShareVideoTasks.addAll(tasks));
    for (final task in tasks) {
      unawaited(_processDeferredShareVideo(task.id));
    }
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

    if (mounted) {
      setState(() {
        _submittingDeferredInlineImages = true;
        _deferredInlineImageTotal = requests.length;
        _deferredInlineImageCompleted = 0;
        _deferredInlineImageActiveProgress = 0;
      });
    } else {
      _submittingDeferredInlineImages = true;
      _deferredInlineImageTotal = requests.length;
      _deferredInlineImageCompleted = 0;
      _deferredInlineImageActiveProgress = 0;
    }

    try {
      for (final request in requests) {
        if (!mounted) return;

        if (!contentContainsShareInlineImageUrl(
          _controller.text,
          request.sourceUrl,
        )) {
          setState(() {
            _removeDeferredInlineImageRequest(request);
            _deferredInlineImageCompleted += 1;
            _deferredInlineImageActiveProgress = 0;
          });
          continue;
        }

        ShareAttachmentSeed? seed;
        try {
          seed = await _shareInlineImageDownloadService
              .downloadDeferredInlineImageAttachment(
                request,
                onProgress: (progress) {
                  if (!mounted) return;
                  setState(() {
                    _deferredInlineImageActiveProgress = progress.clamp(0, 1);
                  });
                },
              );
          if (seed != null) {
            final applied = await _applyPrefetchedDeferredInlineImage(
              request: request,
              seed: seed,
            );
            if (!applied) {
              await _cleanupShareVideoFile(seed.filePath);
            }
          }
        } catch (_) {
          if (seed != null) {
            await _cleanupShareVideoFile(seed.filePath);
          }
        } finally {
          if (mounted) {
            setState(() {
              _deferredInlineImageCompleted += 1;
              _deferredInlineImageActiveProgress = 0;
            });
          } else {
            _deferredInlineImageCompleted += 1;
            _deferredInlineImageActiveProgress = 0;
          }
        }
      }
    } finally {
      _deferredInlineImagePrefetchFuture = null;
      if (mounted) {
        setState(() {
          _submittingDeferredInlineImages = false;
          _deferredInlineImageTotal = 0;
          _deferredInlineImageCompleted = 0;
          _deferredInlineImageActiveProgress = 0;
        });
      } else {
        _submittingDeferredInlineImages = false;
        _deferredInlineImageTotal = 0;
        _deferredInlineImageCompleted = 0;
        _deferredInlineImageActiveProgress = 0;
      }
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

  _DeferredShareVideoTask? _findDeferredShareVideoTask(String id) {
    for (final task in _deferredShareVideoTasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> _processDeferredShareVideo(String id) async {
    final task = _findDeferredShareVideoTask(id);
    if (task == null || task.cancelled) return;

    String? downloadedPath;
    String? compressedPath;
    try {
      final probe = await _shareVideoDownloadService.probe(
        result: task.request.captureResult,
        candidate: task.request.candidate,
      );
      final stillActive = _findDeferredShareVideoTask(id);
      if (!mounted || stillActive == null || stillActive.cancelled) {
        return;
      }
      setState(() {
        stillActive.headers = probe.headers;
        stillActive.remoteSize = probe.contentLength;
        stillActive.phase = _DeferredShareVideoPhase.downloading;
        stillActive.progress = 0;
      });

      final download = await _shareVideoDownloadService.download(
        result: task.request.captureResult,
        candidate: task.request.candidate,
        onProgress: (progress) {
          final activeTask = _findDeferredShareVideoTask(id);
          if (!mounted || activeTask == null || activeTask.cancelled) return;
          setState(() {
            activeTask.phase = _DeferredShareVideoPhase.downloading;
            activeTask.progress = progress.clamp(0, 1);
          });
        },
      );
      downloadedPath = download.filePath;

      final activeTask = _findDeferredShareVideoTask(id);
      if (!mounted || activeTask == null || activeTask.cancelled) {
        await _cleanupShareVideoFile(downloadedPath);
        return;
      }

      var resolvedPath = download.filePath;
      var resolvedSize = download.fileSize;
      if (resolvedSize > kShareVideoAttachmentLimitBytes) {
        setState(() {
          activeTask.phase = _DeferredShareVideoPhase.awaitingCompression;
          activeTask.progress = 1;
        });
        final shouldCompress = await _confirmDeferredVideoCompression(
          resolvedSize,
        );
        final compressionTask = _findDeferredShareVideoTask(id);
        if (!mounted || compressionTask == null || compressionTask.cancelled) {
          await _cleanupShareVideoFile(downloadedPath);
          return;
        }
        if (!shouldCompress) {
          await _cleanupShareVideoFile(downloadedPath);
          await _removeDeferredShareVideoTask(id);
          return;
        }

        setState(() {
          compressionTask.phase = _DeferredShareVideoPhase.compressing;
          compressionTask.progress = 0;
        });
        final compression = await _shareVideoCompressionService.compressToFit(
          inputPath: download.filePath,
          onProgress: (progress) {
            final nextTask = _findDeferredShareVideoTask(id);
            if (!mounted || nextTask == null || nextTask.cancelled) return;
            setState(() {
              nextTask.phase = _DeferredShareVideoPhase.compressing;
              nextTask.progress = progress.clamp(0, 1);
            });
          },
        );
        if (compression == null) {
          await _cleanupShareVideoFile(downloadedPath);
          await _removeDeferredShareVideoTask(id);
          _showDeferredVideoFailure(
            _DeferredShareVideoFailure.compressionFailed,
          );
          return;
        }
        compressedPath = compression.filePath;
        resolvedPath = compression.filePath;
        resolvedSize = compression.fileSize;
        if (compression.wasCompressed && compressedPath != downloadedPath) {
          await _cleanupShareVideoFile(downloadedPath);
          downloadedPath = null;
        }
        if (resolvedSize > kShareVideoAttachmentLimitBytes) {
          await _cleanupShareVideoFile(resolvedPath);
          await _removeDeferredShareVideoTask(id);
          _showDeferredVideoFailure(
            _DeferredShareVideoFailure.compressionStillTooLarge,
          );
          return;
        }
      }

      final completionTask = _findDeferredShareVideoTask(id);
      if (!mounted || completionTask == null || completionTask.cancelled) {
        await _cleanupShareVideoFile(resolvedPath);
        return;
      }

      final filename = resolvedPath.split(Platform.pathSeparator).last;
      final mimeType = _guessMimeType(filename);
      final stagedAttachment = await _stagePendingAttachment(
        _PendingAttachment(
          uid: generateUid(),
          filePath: resolvedPath,
          filename: filename,
          mimeType: mimeType,
          size: resolvedSize,
        ),
      );
      setState(() {
        completionTask.phase = _DeferredShareVideoPhase.completed;
        completionTask.progress = 1;
        _composer.addPendingAttachments([stagedAttachment]);
        completionTask.phase = _DeferredShareVideoPhase.removed;
      });
    } catch (_) {
      final failedTask = _findDeferredShareVideoTask(id);
      await _cleanupShareVideoFile(compressedPath);
      await _cleanupShareVideoFile(downloadedPath);
      await _removeDeferredShareVideoTask(id);
      if (failedTask?.cancelled == true) {
        return;
      }
      _showDeferredVideoFailure(_DeferredShareVideoFailure.downloadFailed);
    }
  }

  Future<void> _removeDeferredShareVideoTask(String id) async {
    final task = _findDeferredShareVideoTask(id);
    if (task == null) return;
    if (!mounted) {
      task.cancelled = true;
      task.phase = _DeferredShareVideoPhase.removed;
      return;
    }
    setState(() {
      task.cancelled = true;
      task.phase = _DeferredShareVideoPhase.removed;
    });
  }

  Future<void> _cleanupShareVideoFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<bool> _confirmDeferredVideoCompression(int fileSize) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t.strings.shareClip.fileTooLargeTitle),
          content: Text(
            context.t.strings.shareClip.fileTooLargeBody(
              size: _formatFileSize(fileSize),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t.strings.common.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.t.strings.shareClip.compressAndSave),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showDeferredVideoFailure(_DeferredShareVideoFailure failure) {
    if (!mounted) return;
    showTopToast(context, _deferredVideoFailureMessage(failure));
  }

  String _deferredVideoFailureMessage(_DeferredShareVideoFailure failure) {
    return switch (failure) {
      _DeferredShareVideoFailure.downloadFailed =>
        context.t.strings.shareClip.fallbackDownloadFailed,
      _DeferredShareVideoFailure.compressionFailed =>
        context.t.strings.shareClip.fallbackCompressionFailed,
      _DeferredShareVideoFailure.compressionStillTooLarge =>
        context.t.strings.shareClip.fallbackCompressionStillTooLarge,
    };
  }

  Future<void> _openDeferredVideoPreview(_DeferredShareVideoTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentVideoScreen(
          title: task.title,
          videoUrl: task.request.candidate.url,
          thumbnailUrl: task.thumbnailUrl,
          headers: task.headers,
          cacheId: task.id,
          cacheSize: task.remoteSize ?? 0,
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
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
    );
  }

  Future<List<_PendingAttachment>> _stagePendingAttachments(
    Iterable<_PendingAttachment> attachments,
  ) async {
    final staged = <_PendingAttachment>[];
    for (final attachment in attachments) {
      staged.add(await _stagePendingAttachment(attachment));
    }
    return staged;
  }

  Future<void> _addPendingAttachmentsStaged(
    Iterable<_PendingAttachment> attachments,
  ) async {
    final staged = await _stagePendingAttachments(attachments);
    if (!mounted || staged.isEmpty) return;
    setState(() {
      _composer.addPendingAttachments(staged);
    });
    _scheduleDraftSave();
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
    final selectedDraftId = await DraftBoxScreen.show(
      context,
      activeDraftId: _activeDraftId,
    );
    if (!mounted) return;

    if (selectedDraftId != null && selectedDraftId.trim().isNotEmpty) {
      final selectedDraft = await ref
          .read(composeDraftRepositoryProvider)
          .getByUid(selectedDraftId);
      if (!mounted || selectedDraft == null) return;
      _restoreComposeDraft(selectedDraft);
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
      ref.read(appPreferencesProvider).desktopShortcutBindings,
    );
    bool matches(DesktopShortcutAction action) {
      return matchesDesktopShortcut(
        event: event,
        pressedKeys: pressed,
        binding: bindings[action]!,
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
          lineBreak: Platform.isWindows ? '\r\n' : '\n',
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
    if (!Platform.isWindows) return;
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
    if (!Platform.isWindows) return false;
    final message = error.toString().toLowerCase();
    return message.contains('permission') ||
        message.contains('access denied') ||
        message.contains('cameraaccessdenied') ||
        message.contains('privacy');
  }

  bool _isWindowsNoCameraError(Object error) {
    if (!Platform.isWindows) return false;
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

  Widget _buildComposeToolbar({
    required BuildContext context,
    required bool isDark,
    required MemoToolbarPreferences preferences,
    required List<MemoTemplate> availableTemplates,
    required String visibilityLabel,
    required IconData visibilityIcon,
    required Color visibilityColor,
  }) {
    final actions = <MemoComposeToolbarActionSpec>[
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

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot == -1 ? '' : lower.substring(dot + 1);
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      '7z' => 'application/x-7z-compressed',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'log' => 'text/plain',
      _ => 'application/octet-stream',
    };
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
    try {
      final compressionSettings = await ref
          .read(imageCompressionSettingsRepositoryProvider)
          .read();
      if (!mounted) return;
      final result = await pickGalleryAttachments(
        context,
        enableOriginalToggle: compressionSettings.enabled,
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
        String path = (file.path ?? '').trim();
        if (path.isEmpty) {
          final stream = file.readStream;
          final bytes = file.bytes;
          if (stream == null && bytes == null) {
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
        }

        if (path.trim().isEmpty) {
          missingPathCount++;
          continue;
        }

        final handle = File(path);
        if (!handle.existsSync()) {
          missingPathCount++;
          continue;
        }
        final size = handle.lengthSync();
        final filename = file.name.trim().isNotEmpty
            ? file.name.trim()
            : path.split(Platform.pathSeparator).last;
        final mimeType = _guessMimeType(filename);
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
    final mimeType = _guessMimeType(filename);
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final navigator = Navigator.of(context);
      final photo = Platform.isWindows
          ? await WindowsCameraCaptureScreen.captureWithNavigator(navigator)
          : await _imagePicker.pickImage(source: ImageSource.camera);
      if (!mounted || photo == null) return;

      final path = photo.path;
      if (path.trim().isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_camera_file_missing),
          ),
        );
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_camera_file_missing),
          ),
        );
        return;
      }

      final size = await file.length();
      if (!mounted) return;

      final filename = path.split(Platform.pathSeparator).last;
      final mimeType = _guessMimeType(filename);
      if (!mounted) return;
      final stagedAttachments = await _stagePendingAttachments([
        _PendingAttachment(
          uid: generateUid(),
          filePath: path,
          filename: filename,
          mimeType: mimeType,
          size: size,
        ),
      ]);
      if (!mounted || stagedAttachments.isEmpty) return;
      setState(() {
        _composer.addPendingAttachments(stagedAttachments);
        _pickedImages.add(XFile(stagedAttachments.first.filePath));
      });
      showTopToast(
        context,
        context.t.strings.legacy.msg_added_photo_attachment,
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

  bool _isImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
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

  List<
    ({AttachmentImageSource source, _PendingAttachment attachment, File file})
  >
  _pendingImageSources() {
    final items =
        <
          ({
            AttachmentImageSource source,
            _PendingAttachment attachment,
            File file,
          })
        >[];
    for (final attachment in _pendingAttachments) {
      if (!_isImageMimeType(attachment.mimeType)) continue;
      final file = _resolvePendingAttachmentFile(attachment);
      if (file == null) continue;
      items.add((
        source: AttachmentImageSource(
          id: _pendingSourceId(attachment.uid),
          title: attachment.filename,
          mimeType: attachment.mimeType,
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
    final sources = items.map((item) => item.source).toList(growable: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentGalleryScreen(
          images: sources,
          initialIndex: index,
          onReplace: _replacePendingAttachment,
          enableDownload: true,
        ),
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
    if (_pendingAttachments.isEmpty && deferredTasks.isEmpty) {
      return const SizedBox.shrink();
    }
    const tileSize = 62.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: tileSize,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < deferredTasks.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _buildDeferredVideoTile(
                  deferredTasks[i],
                  isDark: isDark,
                  size: tileSize,
                ),
              ],
              for (var i = 0; i < _pendingAttachments.length; i++) ...[
                if (i > 0 || deferredTasks.isNotEmpty)
                  const SizedBox(width: 10),
                _buildAttachmentTile(
                  _pendingAttachments[i],
                  isDark: isDark,
                  size: tileSize,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPendingVideoPreview(_PendingAttachment attachment) async {
    final file = _resolvePendingAttachmentFile(attachment);
    if (file == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentVideoScreen(
          title: attachment.filename,
          localFile: file,
          cacheId: attachment.uid,
          cacheSize: attachment.size,
        ),
      ),
    );
  }

  Widget _buildDeferredVideoTile(
    _DeferredShareVideoTask task, {
    required bool isDark,
    required double size,
  }) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final surfaceColor = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final removeBg = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.5);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.12);
    final thumbnailUrl = task.thumbnailUrl?.trim() ?? '';

    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl.isNotEmpty)
              Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                headers: task.headers,
                errorBuilder: (context, error, stackTrace) {
                  return _attachmentFallback(
                    iconColor: Colors.white,
                    surfaceColor: surfaceColor,
                    isImage: false,
                    isVideo: true,
                  );
                },
              )
            else
              _attachmentFallback(
                iconColor: Colors.white,
                surfaceColor: surfaceColor,
                isImage: false,
                isVideo: true,
              ),
            Container(color: Colors.black.withValues(alpha: 0.26)),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: task.overallProgress,
                  strokeWidth: 2.2,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openDeferredVideoPreview(task),
          child: tile,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: (_busy || !task.isRemovable)
                ? null
                : () => unawaited(_removeDeferredShareVideoTask(task.id)),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: removeBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
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
    final isImage = _isImageMimeType(attachment.mimeType);
    final isVideo = _isVideoMimeType(attachment.mimeType);
    final file = _resolvePendingAttachmentFile(attachment);
    final cacheExtent = resolveThumbnailCacheExtent(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );

    Widget content;
    if (isImage && file != null) {
      content = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheExtent,
        cacheHeight: cacheExtent,
        errorBuilder: (context, error, stackTrace) {
          return _attachmentFallback(
            iconColor: iconColor,
            surfaceColor: surfaceColor,
            isImage: true,
          );
        },
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
      content = _attachmentFallback(
        iconColor: iconColor,
        surfaceColor: surfaceColor,
        isImage: isImage,
        isVideo: isVideo,
      );
    }

    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: content),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: (isImage && file != null)
              ? () => _openAttachmentViewer(attachment)
              : (isVideo && file != null)
              ? () => _openPendingVideoPreview(attachment)
              : null,
          child: tile,
        ),
        if (attachment.skipCompression && isImage)
          Positioned(
            left: 4,
            bottom: 4,
            child: IgnorePointer(child: _buildOriginalBadge()),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _busy
                ? null
                : () => _removePendingAttachment(attachment.uid),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: removeBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attachmentFallback({
    required Color iconColor,
    required Color surfaceColor,
    required bool isImage,
    bool isVideo = false,
  }) {
    return Container(
      color: surfaceColor,
      alignment: Alignment.center,
      child: Icon(
        isImage
            ? Icons.image_outlined
            : (isVideo
                  ? Icons.videocam_outlined
                  : Icons.insert_drive_file_outlined),
        size: 22,
        color: iconColor,
      ),
    );
  }

  Widget _buildOriginalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.t.strings.legacy.msg_original_image,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
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
    var content = _controller.text.trimRight();
    var relations = _linkedMemos
        .map((m) => m.toRelationJson())
        .toList(growable: false);
    var pendingAttachments = List<_PendingAttachment>.from(_pendingAttachments)
      ..removeWhere(
        (attachment) =>
            attachment.shareInlineImage &&
            !contentContainsShareInlineLocalUrl(content, attachment.filePath),
      );
    var hasAttachments = pendingAttachments.isNotEmpty;
    if (content.trim().isEmpty && !hasAttachments) {
      if (relations.isNotEmpty) {
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

    setState(() => _busy = true);
    try {
      final prefetchFuture = _deferredInlineImagePrefetchFuture;
      if (prefetchFuture != null) {
        await prefetchFuture;
      }

      content = _controller.text.trimRight();
      relations = _linkedMemos
          .map((m) => m.toRelationJson())
          .toList(growable: false);
      pendingAttachments = List<_PendingAttachment>.from(_pendingAttachments)
        ..removeWhere(
          (attachment) =>
              attachment.shareInlineImage &&
              !contentContainsShareInlineLocalUrl(content, attachment.filePath),
        );
      final deferredInlineImageRequests =
          List<ShareDeferredInlineImageAttachmentRequest>.from(
            _deferredInlineImageRequests,
          )..removeWhere(
            (request) =>
                !contentContainsShareInlineImageUrl(content, request.sourceUrl),
          );
      pendingAttachments.sort(
        (left, right) =>
            switch ((left.shareInlineImage, right.shareInlineImage)) {
              (true, false) => 1,
              (false, true) => -1,
              _ => 0,
            },
      );
      hasAttachments = pendingAttachments.isNotEmpty;

      final now = DateTime.now();
      final uid = generateUid();
      final tags = extractTags(content);
      final visibility = _normalizedVisibility();
      final imageBedEnabled = ref.read(imageBedSettingsProvider).enabled;
      final hasThirdPartyShareInlineImages = pendingAttachments.any(
        (attachment) =>
            attachment.shareInlineImage && attachment.fromThirdPartyShare,
      );
      var syncContent = content;
      if (!imageBedEnabled && hasThirdPartyShareInlineImages) {
        for (final entry in _thirdPartyShareInlineSourceByLocalUrl.entries) {
          syncContent = replaceShareInlineLocalUrlWithRemote(
            syncContent,
            localUrl: entry.key,
            remoteUrl: entry.value,
          );
        }
      }
      syncContent = buildShareInlineSyncContent(
        syncContent,
        pendingAttachments.map(
          (attachment) => ShareAttachmentSeed(
            uid: attachment.uid,
            filePath: attachment.filePath,
            filename: attachment.filename,
            mimeType: attachment.mimeType,
            size: attachment.size,
            skipCompression: attachment.skipCompression,
            shareInlineImage: attachment.shareInlineImage,
            fromThirdPartyShare: attachment.fromThirdPartyShare,
            sourceUrl: attachment.sourceUrl,
          ),
        ),
      );

      final attachments = pendingAttachments
          .map((p) {
            final rawPath = p.filePath.trim();
            final externalLink = rawPath.isEmpty
                ? ''
                : rawPath.startsWith('content://')
                ? rawPath
                : Uri.file(rawPath).toString();
            return Attachment(
              name: 'attachments/${p.uid}',
              filename: p.filename,
              type: p.mimeType,
              size: p.size,
              externalLink: externalLink,
            ).toJson();
          })
          .toList(growable: false);
      final pendingUploads = pendingAttachments
          .map(
            (attachment) => NoteInputPendingAttachment(
              uid: attachment.uid,
              filePath: attachment.filePath,
              filename: attachment.filename,
              mimeType: attachment.mimeType,
              size: attachment.size,
              skipCompression: attachment.skipCompression,
              shareInlineImage: attachment.shareInlineImage,
              fromThirdPartyShare: attachment.fromThirdPartyShare,
              sourceUrl: attachment.sourceUrl,
            ),
          )
          .toList(growable: false);

      await ref
          .read(noteInputControllerProvider)
          .createMemo(
            uid: uid,
            content: content,
            syncContent: syncContent,
            visibility: visibility,
            now: now,
            tags: tags,
            attachments: attachments,
            location: _location,
            hasAttachments: hasAttachments,
            relations: relations,
            pendingAttachments: pendingUploads,
          );

      await _processDeferredInlineImagesAfterSubmit(
        memoUid: uid,
        requests: deferredInlineImageRequests,
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
        final keepPaths = pendingUploads
            .map((attachment) => attachment.filePath.trim())
            .where((path) => path.isNotEmpty)
            .toSet();
        await ref
            .read(composeDraftRepositoryProvider)
            .deleteDraft(submittedDraftId, keepPaths: keepPaths);
      }

      if (!mounted) return;
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

  Future<void> _processDeferredInlineImagesAfterSubmit({
    required String memoUid,
    required List<ShareDeferredInlineImageAttachmentRequest> requests,
  }) async {
    if (requests.isEmpty) return;
    if (mounted) {
      setState(() {
        _submittingDeferredInlineImages = true;
        _deferredInlineImageTotal = requests.length;
        _deferredInlineImageCompleted = 0;
        _deferredInlineImageActiveProgress = 0;
      });
    } else {
      _submittingDeferredInlineImages = true;
      _deferredInlineImageTotal = requests.length;
      _deferredInlineImageCompleted = 0;
      _deferredInlineImageActiveProgress = 0;
    }

    try {
      for (final request in requests) {
        ShareAttachmentSeed? seed;
        try {
          seed = await _shareInlineImageDownloadService
              .downloadDeferredInlineImageAttachment(
                request,
                onProgress: (progress) {
                  if (!mounted) return;
                  setState(() {
                    _deferredInlineImageActiveProgress = progress.clamp(0, 1);
                  });
                },
              );
          if (seed != null) {
            await ref
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
                    shareInlineImage: true,
                    fromThirdPartyShare: true,
                    sourceUrl: request.sourceUrl,
                  ),
                );
          }
        } catch (_) {
          if (seed != null) {
            await _cleanupShareVideoFile(seed.filePath);
          }
        } finally {
          if (mounted) {
            setState(() {
              _deferredInlineImageCompleted += 1;
              _deferredInlineImageActiveProgress = 0;
            });
          } else {
            _deferredInlineImageCompleted += 1;
            _deferredInlineImageActiveProgress = 0;
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _submittingDeferredInlineImages = false;
          _deferredInlineImageTotal = 0;
          _deferredInlineImageCompleted = 0;
          _deferredInlineImageActiveProgress = 0;
        });
      } else {
        _submittingDeferredInlineImages = false;
        _deferredInlineImageTotal = 0;
        _deferredInlineImageCompleted = 0;
        _deferredInlineImageActiveProgress = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _composeDraftRepository = ref.watch(composeDraftRepositoryProvider);
    _noteDraftRepository = ref.watch(noteDraftRepositoryProvider);
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
      appPreferencesProvider.select((p) => p.memoToolbarPreferences),
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
          _deferredShareVideoTasks.isNotEmpty,
    );
    final editorHintText = shouldShowDraftHint
        ? context.t.strings.legacy.msg_draft_box_pending_hint(
            count: pendingDraftCount,
          )
        : context.t.strings.legacy.msg_write_thoughts;

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
                              const SizedBox(height: 10),
                              Container(
                                width: 40,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                                child: TextField(
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
                              if (_linkedMemos.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    8,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: _linkedMemos
                                        .map(
                                          (memo) => InputChip(
                                            label: Text(
                                              memo.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: chipText,
                                              ),
                                            ),
                                            backgroundColor: chipBg,
                                            deleteIconColor: chipDelete,
                                            onDeleted: _busy
                                                ? null
                                                : () => _removeLinkedMemo(
                                                    memo.name,
                                                  ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ),
                              if (_locating)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.t.strings.legacy.msg_locating,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: chipText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_location != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    8,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InputChip(
                                      avatar: Icon(
                                        Icons.place_outlined,
                                        size: 16,
                                        color: chipText,
                                      ),
                                      label: Text(
                                        _location!.displayText(
                                          fractionDigits: 6,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: chipText,
                                        ),
                                      ),
                                      backgroundColor: chipBg,
                                      deleteIconColor: chipDelete,
                                      onPressed: _busy
                                          ? null
                                          : () => unawaited(_requestLocation()),
                                      onDeleted: _busy ? null : _clearLocation,
                                    ),
                                  ),
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
                                    Builder(
                                      builder: (context) {
                                        final deferredProgress =
                                            _deferredInlineImageProgress ??
                                            _deferredShareVideoProgress;
                                        final buttonEnabled =
                                            !_busy &&
                                            !_hasPendingDeferredShareVideoTasks;
                                        final buttonColor = buttonEnabled
                                            ? MemoFlowPalette.primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest;
                                        final buttonShadowColor = buttonEnabled
                                            ? MemoFlowPalette.primary
                                                  .withValues(
                                                    alpha: isDark ? 0.3 : 0.4,
                                                  )
                                            : Colors.black.withValues(
                                                alpha: isDark ? 0.18 : 0.1,
                                              );

                                        return GestureDetector(
                                          onTap: buttonEnabled
                                              ? _submitOrVoice
                                              : null,
                                          child: AnimatedScale(
                                            duration: const Duration(
                                              milliseconds: 120,
                                            ),
                                            scale: _busy ? 0.98 : 1.0,
                                            child: SizedBox(
                                              width: 64,
                                              height: 64,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  if (deferredProgress != null)
                                                    SizedBox(
                                                      width: 64,
                                                      height: 64,
                                                      child:
                                                          CircularProgressIndicator(
                                                            value:
                                                                deferredProgress,
                                                            strokeWidth: 3,
                                                            color:
                                                                MemoFlowPalette
                                                                    .primary,
                                                            backgroundColor:
                                                                MemoFlowPalette
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.18,
                                                                    ),
                                                          ),
                                                    ),
                                                  Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      color: buttonColor,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color:
                                                              buttonShadowColor,
                                                          blurRadius: 16,
                                                          offset: const Offset(
                                                            0,
                                                            8,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Center(
                                                      child: _busy
                                                          ? const SizedBox.square(
                                                              dimension: 22,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            )
                                                          : ValueListenableBuilder<
                                                              TextEditingValue
                                                            >(
                                                              valueListenable:
                                                                  _controller,
                                                              builder: (context, value, _) {
                                                                final hasText =
                                                                    value.text
                                                                        .trim()
                                                                        .isNotEmpty;
                                                                final hasAttachments =
                                                                    _pendingAttachments
                                                                        .isNotEmpty ||
                                                                    _deferredInlineImageRequests
                                                                        .isNotEmpty ||
                                                                    _visibleDeferredShareVideoTasks
                                                                        .isNotEmpty;
                                                                final showSend =
                                                                    hasText ||
                                                                    hasAttachments;
                                                                return AnimatedSwitcher(
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            160,
                                                                      ),
                                                                  transitionBuilder:
                                                                      (
                                                                        child,
                                                                        animation,
                                                                      ) {
                                                                        return ScaleTransition(
                                                                          scale:
                                                                              animation,
                                                                          child:
                                                                              child,
                                                                        );
                                                                      },
                                                                  child: Icon(
                                                                    showSend
                                                                        ? Icons
                                                                              .send_rounded
                                                                        : Icons
                                                                              .graphic_eq,
                                                                    key:
                                                                        ValueKey<
                                                                          bool
                                                                        >(
                                                                          showSend,
                                                                        ),
                                                                    color: Colors
                                                                        .white,
                                                                    size:
                                                                        showSend
                                                                        ? 24
                                                                        : 28,
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  width: 130,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
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
