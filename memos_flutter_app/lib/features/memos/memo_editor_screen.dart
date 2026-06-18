// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/attachments/queued_attachment_stager.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../core/app_localization.dart';
import '../../core/attachment_mime_type.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/desktop/window_chrome_safe_area.dart';
import '../../core/image_thumbnail_cache.dart';
import '../../core/markdown_editing.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/scene_micro_guide_widgets.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/attachment.dart';
import '../../data/models/compose_draft.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../platform/platform_target.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_page.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../state/attachments/queued_attachment_stager_provider.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/memo_editor_draft_provider.dart';
import '../../state/memos/memo_editor_draft_session.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/memos/memo_editor_providers.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/memos/note_input_draft_session.dart';
import '../../state/system/session_provider.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../image_preview/image_preview_item.dart';
import '../image_preview/image_preview_launcher.dart';
import '../image_preview/image_preview_open_request.dart';
import '../image_preview/widgets/image_preview_tile.dart';
import '../settings/location_settings_navigation.dart';
import 'attachment_gallery_screen.dart';
import 'compose_toolbar_shared.dart';
import 'gallery_attachment_picker.dart';
import 'link_memo_sheet.dart';
import 'memo_compose_surface.dart';
import 'memo_video_grid.dart';
import 'tag_autocomplete.dart';
import 'widgets/attachment_processing_overlay.dart';
import 'widgets/memo_compose_fullscreen_surface.dart';
import '../location_picker/show_location_picker.dart';
import '../../i18n/strings.g.dart';
import 'android_memo_keyboard_resume_controller.dart';

typedef _PendingAttachment = MemoComposerPendingAttachment;
typedef _LinkedMemo = MemoComposerLinkedMemo;

enum MemoEditorPresentation {
  page,
  embeddedPane,
  desktopModal,
  desktopFullscreen,
}

class MemoEditorScreen extends ConsumerStatefulWidget {
  const MemoEditorScreen({
    super.key,
    this.existing,
    this.initialText,
    this.initialEditDraft,
    this.initialCreateDraft,
    this.initialAttachmentPaths = const [],
    this.ignoreDraft = false,
    this.autoFocus = true,
    this.onSaved,
    this.onCloseRequested,
    this.onToggleFullscreen,
    this.presentation = MemoEditorPresentation.page,
  });

  final LocalMemo? existing;
  final String? initialText;
  final ComposeDraftRecord? initialEditDraft;
  final ComposeDraftRecord? initialCreateDraft;
  final List<String> initialAttachmentPaths;
  final bool ignoreDraft;
  final bool autoFocus;
  final VoidCallback? onSaved;
  final VoidCallback? onCloseRequested;
  final VoidCallback? onToggleFullscreen;
  final MemoEditorPresentation presentation;

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

enum _TodoShortcutAction { checkbox, codeBlock }

enum _EditorCloseDecision { continueEditing, discard, addToDraftBox }

enum _MemoEditorPagePresentationMode { normal, fullscreen }

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  late final MemoComposerController _composer;
  late final MemoEditorDraftRepository _draftRepository;
  static const _editDraftSessionHelper = MemoEditorDraftSessionHelper();
  static const _createDraftSessionHelper = NoteInputDraftSessionHelper();
  late final TextEditingController _contentController;
  late final FocusNode _editorFocusNode;
  late final AndroidMemoKeyboardResumeController _keyboardResumeController;
  final _editorFieldKey = GlobalKey();
  final _tagMenuKey = GlobalKey();
  final _templateMenuKey = GlobalKey();
  final _todoMenuKey = GlobalKey();
  final _visibilityMenuKey = GlobalKey();
  List<_LinkedMemo> get _linkedMemos => _composer.linkedMemos;
  final _existingAttachments = <Attachment>[];
  late final Set<String> _initialAttachmentKeys;
  List<_PendingAttachment> get _pendingAttachments =>
      _composer.pendingAttachments;
  final _attachmentsToDelete = <Attachment>[];
  static const String _newDraftMemoUid = '__memo_editor_new__';
  static const _pageFullscreenExpandButtonKey = ValueKey<String>(
    'memo-editor-page-fullscreen-button',
  );
  static const _pageFullscreenCollapseButtonKey = ValueKey<String>(
    'memo-editor-fullscreen-collapse-button',
  );
  static const _pageFullscreenCloseButtonKey = ValueKey<String>(
    'memo-editor-fullscreen-close-button',
  );
  static const _pageFullscreenTopToolbarKey = ValueKey<String>(
    'memo-editor-fullscreen-top-toolbar-row',
  );
  static const _pageFullscreenBottomToolbarKey = ValueKey<String>(
    'memo-editor-fullscreen-bottom-toolbar-row',
  );
  static const _pageFullscreenSaveButtonKey = ValueKey<String>(
    'memo-editor-fullscreen-save-button',
  );
  static const _pageFullscreenTextFieldKey = ValueKey<String>(
    'memo-editor-fullscreen-text-field',
  );

  final _imagePicker = ImagePicker();
  final _templateRenderer = MemoTemplateRenderer();
  final _pickedImages = <XFile>[];
  List<TagStat> _tagStatsCache = const [];
  Timer? _draftTimer;
  bool _relationsLoaded = false;
  bool _didSeedInitialAttachmentPaths = false;
  bool _relationsLoading = false;
  bool _relationsDirty = false;
  bool _skipDraftPersistOnDispose = false;
  bool _openedFromVisibleEditDraft = false;
  String? _activeVisibleEditDraftUid;
  String? _activeVisibleCreateDraftUid;
  Future<void>? _relationsLoadFuture;
  late String _visibility;
  late bool _pinned;
  var _saving = false;
  bool _allowRoutePop = false;
  var _pagePresentationMode = _MemoEditorPagePresentationMode.normal;
  MemoLocation? _location;
  MemoLocation? _initialLocation;
  final _locating = false;
  int get _tagAutocompleteIndex => _composer.tagAutocompleteIndex;

  bool get _isDesktopModalPresentation =>
      widget.presentation == MemoEditorPresentation.desktopModal;

  bool get _isPagePresentation =>
      widget.presentation == MemoEditorPresentation.page;

  bool get _isPageFullscreenCompose =>
      _isPagePresentation &&
      _pagePresentationMode == _MemoEditorPagePresentationMode.fullscreen;

  bool get _isDesktopFullscreenPresentation =>
      widget.presentation == MemoEditorPresentation.desktopFullscreen;

  bool get _isEmbeddedPresentation =>
      widget.presentation == MemoEditorPresentation.embeddedPane;

  bool get _supportsDesktopSurfaceChrome =>
      _isDesktopModalPresentation || _isDesktopFullscreenPresentation;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _draftRepository = ref.read(memoEditorDraftRepositoryProvider);
    _composer = MemoComposerController(
      initialText: existing?.content ?? (widget.initialText ?? ''),
    );
    _contentController = _composer.textController;
    _editorFocusNode = FocusNode(onKeyEvent: _handleTagAutocompleteKeyEvent);
    _keyboardResumeController = AndroidMemoKeyboardResumeController(
      focusNode: _editorFocusNode,
      isSurfaceEligible: () => mounted && !_saving,
      isRouteCurrent: _isKeyboardResumeRouteCurrent,
      isKeyboardVisible: _isKeyboardVisibleForResume,
    );
    _contentController.addListener(_handleContentChanged);
    _contentController.addListener(_scheduleDraftSave);
    _loadTagStats();
    _existingAttachments.addAll(existing?.attachments ?? const []);
    _initialAttachmentKeys = _existingAttachments
        .map(_attachmentKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    _visibility = existing?.visibility ?? 'PRIVATE';
    _pinned = existing?.pinned ?? false;
    _location = existing?.location;
    _initialLocation = existing?.location;
    if (existing != null && _restoreInitialEditDraft(existing)) {
      // The visible draft carries the relation state to save later.
    } else if (existing == null && _restoreInitialCreateDraft()) {
      // The visible draft carries the create state to save later.
    } else if (existing != null) {
      _loadExistingRelations();
    }
    if (!widget.ignoreDraft &&
        widget.initialEditDraft == null &&
        widget.initialCreateDraft == null) {
      unawaited(_restoreEditorDraftIfNeeded());
    }
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _editorFocusNode.requestFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_seedInitialAttachmentPathsIfNeeded());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _contentController.removeListener(_handleContentChanged);
    _contentController.removeListener(_scheduleDraftSave);
    if (!_skipDraftPersistOnDispose) {
      unawaited(_persistEditorDraftNow());
    }
    _keyboardResumeController.dispose();
    _editorFocusNode.dispose();
    _composer.dispose();
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

  void _requestEditorFocusAfterLayout({
    required _MemoEditorPagePresentationMode expectedMode,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isPagePresentation) return;
      if (_pagePresentationMode != expectedMode) return;
      _editorFocusNode.requestFocus();
    });
  }

  void _enterPageFullscreenCompose() {
    if (_saving || !_isPagePresentation || _isPageFullscreenCompose) return;
    if (_editorFocusNode.hasFocus) {
      _editorFocusNode.unfocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
    }
    setState(() {
      _pagePresentationMode = _MemoEditorPagePresentationMode.fullscreen;
    });
    _requestEditorFocusAfterLayout(
      expectedMode: _MemoEditorPagePresentationMode.fullscreen,
    );
  }

  void _collapsePageFullscreenCompose() {
    if (_saving || !_isPageFullscreenCompose) return;
    if (_editorFocusNode.hasFocus) {
      _editorFocusNode.unfocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
    }
    setState(() {
      _pagePresentationMode = _MemoEditorPagePresentationMode.normal;
    });
    _requestEditorFocusAfterLayout(
      expectedMode: _MemoEditorPagePresentationMode.normal,
    );
  }

  void _handleContentChanged() {
    if (!mounted) return;
    _syncTagAutocompleteState();
    setState(() {});
  }

  void _syncTagAutocompleteState() {
    final tagRecognitionPolicy = ref
        .read(currentWorkspacePreferencesProvider)
        .tagRecognitionPolicy;
    final activeQuery = detectActiveTagQuery(
      _contentController.value,
      policy: tagRecognitionPolicy,
    );
    if (activeQuery != null) {
      _markSceneGuideSeen(SceneMicroGuideId.memoEditorTagAutocomplete);
    }
    _composer.syncTagAutocompleteState(
      tagStats: _currentTagStats(),
      hasFocus: _editorFocusNode.hasFocus,
      policy: tagRecognitionPolicy,
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
      policy: ref
          .read(currentWorkspacePreferencesProvider)
          .tagRecognitionPolicy,
    );
  }

  List<TagStat> _currentTagStats() {
    return ref.read(tagStatsProvider).valueOrNull ?? _tagStatsCache;
  }

  void _markSceneGuideSeen(SceneMicroGuideId id) {
    unawaited(ref.read(sceneMicroGuideProvider.notifier).markSeen(id));
  }

  KeyEventResult _handleTagAutocompleteKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    final keyboard = HardwareKeyboard.instance;
    final controlPressed = keyboard.isControlPressed;
    final metaPressed = keyboard.isMetaPressed;
    final shiftPressed = keyboard.isShiftPressed;
    final altPressed = keyboard.isAltPressed;
    final key = event.logicalKey;
    if (event is KeyDownEvent && isDesktopShortcutEnabled()) {
      final bindings = ref
          .read(devicePreferencesProvider)
          .desktopShortcutBindings;
      if (matchesDesktopShortcutAction(
        event: event,
        pressedKeys: HardwareKeyboard.instance.logicalKeysPressed,
        bindings: bindings,
        action: DesktopShortcutAction.publishMemo,
      )) {
        unawaited(_save());
        return KeyEventResult.handled;
      }
    }

    final result = _composer.handleTagAutocompleteKeyEvent(
      event,
      tagStats: _currentTagStats(),
      hasFocus: _editorFocusNode.hasFocus,
      policy: ref
          .read(currentWorkspacePreferencesProvider)
          .tagRecognitionPolicy,
      requestFocus: _editorFocusNode.requestFocus,
    );
    if (result == KeyEventResult.handled) {
      setState(() {});
      return result;
    }

    if (event is KeyDownEvent && key == LogicalKeyboardKey.escape) {
      if (_isPageFullscreenCompose) {
        _collapsePageFullscreenCompose();
        return KeyEventResult.handled;
      }
      if (_isDesktopFullscreenPresentation) {
        widget.onToggleFullscreen?.call();
        return KeyEventResult.handled;
      }
      if (_supportsDesktopSurfaceChrome) {
        unawaited(_requestCloseEditor());
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent &&
        !controlPressed &&
        !metaPressed &&
        !altPressed &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      final lineBreak = isWindowsPlatform() ? '\r\n' : '\n';
      if (!shiftPressed &&
          _composer.applyDesktopSmartEnter(lineBreak: lineBreak)) {
        setState(() {});
        return KeyEventResult.handled;
      }
      if (_supportsDesktopSurfaceChrome) {
        _composer.insertText(lineBreak);
        setState(() {});
        return KeyEventResult.handled;
      }
    }
    return result;
  }

  String? get _draftMemoUid {
    final existingUid = widget.existing?.uid.trim() ?? '';
    if (existingUid.isNotEmpty) return existingUid;
    return _newDraftMemoUid;
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistEditorDraftNow());
    });
  }

  bool _restoreInitialEditDraft(LocalMemo existing) {
    final draft = widget.initialEditDraft;
    if (draft == null || !draft.isEditMemoDraft) return false;
    final restored = _editDraftSessionHelper.restoreEditDraft(
      draft,
      targetMemo: existing,
    );
    _activeVisibleEditDraftUid = restored.draftUid;
    _openedFromVisibleEditDraft = true;
    _contentController.value = _contentController.value.copyWith(
      text: restored.content,
      selection: TextSelection.collapsed(offset: restored.content.length),
      composing: TextRange.empty,
    );
    _visibility = restored.visibility;
    _location = restored.location;
    _existingAttachments
      ..clear()
      ..addAll(restored.existingAttachments);
    _composer.setPendingAttachments(restored.pendingAttachments);
    _composer.setLinkedMemos(restored.linkedMemos);
    _attachmentsToDelete
      ..clear()
      ..addAll(restored.attachmentsToDelete);
    _relationsLoaded = true;
    _relationsDirty = true;
    _composer.clearHistory();
    return true;
  }

  bool _restoreInitialCreateDraft() {
    final draft = widget.initialCreateDraft;
    if (draft == null || !draft.isCreateMemoDraft) return false;
    final restored = _createDraftSessionHelper.restoreState(
      draft,
      defaultVisibility: _visibility,
    );
    _activeVisibleCreateDraftUid = restored.draftUid;
    _contentController.value = _contentController.value.copyWith(
      text: restored.content,
      selection: TextSelection.collapsed(offset: restored.content.length),
      composing: TextRange.empty,
    );
    _visibility = restored.visibility;
    _location = restored.location;
    _composer.setPendingAttachments(restored.pendingAttachments);
    _composer.setLinkedMemos(restored.linkedMemos);
    _pickedImages
      ..clear()
      ..addAll(restored.pickedImagePaths.map(XFile.new));
    _relationsLoaded = true;
    _relationsDirty = restored.linkedMemos.isNotEmpty;
    _composer.clearHistory();
    return true;
  }

  String _attachmentKey(Attachment attachment) {
    final name = attachment.name.trim();
    if (name.isNotEmpty) return 'name:$name';
    final uid = attachment.uid.trim();
    if (uid.isNotEmpty) return 'uid:$uid';
    return [
      'file',
      attachment.filename.trim(),
      attachment.type.trim(),
      attachment.size.toString(),
      attachment.externalLink.trim(),
    ].join('|');
  }

  Set<String> _attachmentKeySet(Iterable<Attachment> attachments) {
    return attachments
        .map(_attachmentKey)
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  bool _sameStringSet(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    for (final value in left) {
      if (!right.contains(value)) return false;
    }
    return true;
  }

  bool _isNewEditorBaseState() {
    return _contentController.text.trim().isEmpty &&
        _visibility == 'PRIVATE' &&
        _location == null &&
        _existingAttachments.isEmpty &&
        _pendingAttachments.isEmpty;
  }

  bool _isEditorBaseState(LocalMemo existing) {
    if (_contentController.text != existing.content) return false;
    if (_visibility != existing.visibility) return false;
    if (!_sameLocation(_location, existing.location)) return false;
    if (_pendingAttachments.isNotEmpty) return false;
    final currentKeys = _attachmentKeySet(_existingAttachments);
    final baseKeys = _attachmentKeySet(existing.attachments);
    if (!_sameStringSet(currentKeys, baseKeys)) return false;
    return true;
  }

  bool _hasUnsavedEditorState(LocalMemo existing) {
    if (_contentController.text != existing.content) return true;
    if (_visibility != existing.visibility) return true;
    if (!_sameLocation(_location, existing.location)) return true;
    final currentKeys = _attachmentKeySet(_existingAttachments);
    final baseKeys = _attachmentKeySet(existing.attachments);
    if (!_sameStringSet(currentKeys, baseKeys)) return true;
    if (_pendingAttachments.isNotEmpty) return true;
    return false;
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Future<void> _seedInitialAttachmentPathsIfNeeded() async {
    if (_didSeedInitialAttachmentPaths) return;
    _didSeedInitialAttachmentPaths = true;
    if (widget.existing != null) return;
    final paths = widget.initialAttachmentPaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) return;

    final pending = <_PendingAttachment>[];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final filename = file.uri.pathSegments.isEmpty
          ? path.split(Platform.pathSeparator).last
          : file.uri.pathSegments.last;
      pending.add(
        _PendingAttachment(
          uid: generateUid(),
          filePath: path,
          filename: filename,
          mimeType: guessAttachmentMimeType(filename),
          size: file.lengthSync(),
        ),
      );
    }
    if (pending.isEmpty) return;

    await _addPendingAttachmentsStaged(pending);
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
          scopeKey: _draftMemoUid ?? 'memo_editor_draft',
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
                  scopeKey: _draftMemoUid ?? 'memo_editor_draft',
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
        'MemoEditor: stage_pending_attachments_failed',
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

  Map<String, dynamic>? _decodeEditorDraftPayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {
      // Legacy format: plain text content only.
      return <String, dynamic>{'schema': 0, 'content': raw};
    }
    return null;
  }

  List<Attachment> _decodeDraftExistingAttachments(
    dynamic raw, {
    required List<Attachment> fallback,
  }) {
    if (raw is! List) return fallback;
    final restored = <Attachment>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        restored.add(Attachment.fromJson(item.cast<String, dynamic>()));
      } catch (_) {}
    }
    return restored;
  }

  List<_PendingAttachment> _decodeDraftPendingAttachments(dynamic raw) {
    if (raw is! List) return const [];
    final restored = <_PendingAttachment>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final path =
          (map['file_path'] as String?)?.trim() ??
          (map['filePath'] as String?)?.trim() ??
          '';
      if (path.isEmpty) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      final uid = (map['uid'] as String?)?.trim();
      final filename = (map['filename'] as String?)?.trim();
      final mimeType = (map['mime_type'] as String?)?.trim();
      restored.add(
        _PendingAttachment(
          uid: (uid == null || uid.isEmpty) ? generateUid() : uid,
          filePath: path,
          filename: (filename == null || filename.isEmpty)
              ? path.split(Platform.pathSeparator).last
              : filename,
          mimeType: (mimeType == null || mimeType.isEmpty)
              ? guessAttachmentMimeType(path.split(Platform.pathSeparator).last)
              : mimeType,
          size: _readInt(map['size']),
          skipCompression: map['skip_compression'] == true,
        ),
      );
    }
    return restored;
  }

  Map<String, dynamic> _pendingAttachmentToJson(_PendingAttachment attachment) {
    return <String, dynamic>{
      'uid': attachment.uid,
      'file_path': attachment.filePath,
      'filename': attachment.filename,
      'mime_type': attachment.mimeType,
      'size': attachment.size,
      'skip_compression': attachment.skipCompression,
    };
  }

  Future<void> _restoreEditorDraftIfNeeded() async {
    final existing = widget.existing;
    final memoUid = _draftMemoUid;
    if (memoUid == null) return;

    try {
      final repo = _draftRepository;
      final raw = await repo.read(memoUid: memoUid);
      if (!mounted) return;

      final payload = _decodeEditorDraftPayload(raw);
      if (payload == null) return;
      if (existing != null) {
        if (!_isEditorBaseState(existing)) return;
      } else if (!_isNewEditorBaseState()) {
        return;
      }

      final restoredContent = (payload['content'] as String?) ?? '';
      final restoredVisibility =
          (payload['visibility'] as String?)?.trim().isNotEmpty == true
          ? (payload['visibility'] as String).trim()
          : (existing?.visibility ?? 'PRIVATE');
      MemoLocation? restoredLocation = existing?.location;
      if (payload.containsKey('location')) {
        final restoredLocationRaw = payload['location'];
        if (restoredLocationRaw is Map) {
          try {
            restoredLocation = MemoLocation.fromJson(
              restoredLocationRaw.cast<String, dynamic>(),
            );
          } catch (_) {
            restoredLocation = existing?.location;
          }
        } else {
          restoredLocation = null;
        }
      }
      final restoredExistingAttachments = _decodeDraftExistingAttachments(
        payload['existing_attachments'],
        fallback: existing?.attachments ?? const <Attachment>[],
      );
      final restoredPendingAttachments = await _stagePendingAttachments(
        _decodeDraftPendingAttachments(payload['pending_attachments']),
      );

      final hasDiff = existing != null
          ? restoredContent != existing.content ||
                restoredVisibility != existing.visibility ||
                !_sameLocation(restoredLocation, existing.location) ||
                !_sameStringSet(
                  _attachmentKeySet(restoredExistingAttachments),
                  _attachmentKeySet(existing.attachments),
                ) ||
                restoredPendingAttachments.isNotEmpty
          : restoredContent.trim().isNotEmpty ||
                restoredVisibility != 'PRIVATE' ||
                restoredLocation != null ||
                restoredExistingAttachments.isNotEmpty ||
                restoredPendingAttachments.isNotEmpty;

      if (!hasDiff) {
        await repo.clear(memoUid: memoUid);
        return;
      }

      final shouldRestore =
          await showPlatformAlertDialog<bool>(
            context: context,
            title: context.t.strings.legacy.msg_restore_backup,
            actions: [
              PlatformDialogAction<bool>(
                value: false,
                label: context.t.strings.legacy.msg_cancel_2,
              ),
              PlatformDialogAction<bool>(
                value: true,
                label: context.t.strings.legacy.msg_restore,
                isDefault: true,
              ),
            ],
          ) ??
          false;
      if (!mounted || !shouldRestore) {
        return;
      }

      final restoredExistingKeys = _attachmentKeySet(
        restoredExistingAttachments,
      );
      final deleted = (existing?.attachments ?? const <Attachment>[])
          .where(
            (attachment) =>
                !restoredExistingKeys.contains(_attachmentKey(attachment)),
          )
          .toList(growable: false);

      _contentController.value = _contentController.value.copyWith(
        text: restoredContent,
        selection: TextSelection.collapsed(offset: restoredContent.length),
        composing: TextRange.empty,
      );
      setState(() {
        _visibility = restoredVisibility;
        _location = restoredLocation;
        _existingAttachments
          ..clear()
          ..addAll(restoredExistingAttachments);
        _composer.setPendingAttachments(restoredPendingAttachments);
        _attachmentsToDelete
          ..clear()
          ..addAll(deleted);
        _pickedImages.clear();
        _composer.clearHistory();
      });
      showTopToast(context, context.t.strings.legacy.msg_restored);
    } catch (_) {}
  }

  Future<void> _persistEditorDraftNow() async {
    final existing = widget.existing;
    final memoUid = _draftMemoUid;
    if (memoUid == null) return;

    final repo = _draftRepository;
    final hasUnsavedEditorState = existing != null
        ? _hasUnsavedEditorState(existing)
        : _contentController.text.trim().isNotEmpty ||
              _visibility != 'PRIVATE' ||
              _location != null ||
              _existingAttachments.isNotEmpty ||
              _pendingAttachments.isNotEmpty;
    if (!hasUnsavedEditorState) {
      await repo.clear(memoUid: memoUid);
      return;
    }

    final payload = <String, dynamic>{
      'schema': 1,
      'content': _contentController.text,
      'visibility': _visibility,
      'location': _location?.toJson(),
      'existing_attachments': _existingAttachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      'pending_attachments': _pendingAttachments
          .map(_pendingAttachmentToJson)
          .toList(growable: false),
    };
    await repo.write(memoUid: memoUid, text: jsonEncode(payload));
  }

  Future<void> _clearEditorDraft() async {
    final memoUid = _draftMemoUid;
    if (memoUid == null) return;
    await _draftRepository.clear(memoUid: memoUid);
  }

  Future<void> _requestCloseEditor() async {
    if (_saving) return;
    final existing = widget.existing;
    if (existing == null || !_hasUnsavedEditorState(existing)) {
      _performCloseEditor();
      return;
    }

    final decision = await _showUnsavedEditCloseDialog();
    if (!mounted || decision == null) return;
    switch (decision) {
      case _EditorCloseDecision.continueEditing:
        return;
      case _EditorCloseDecision.discard:
        await _discardEditorChangesAndClose();
        return;
      case _EditorCloseDecision.addToDraftBox:
        await _saveVisibleEditDraftAndClose(existing);
        return;
    }
  }

  Future<_EditorCloseDecision?> _showUnsavedEditCloseDialog() {
    return showPlatformAlertDialog<_EditorCloseDecision>(
      context: context,
      title: context.tr(zh: '保存编辑草稿？', en: 'Save edit draft?'),
      message: context.tr(
        zh: '这条笔记有未保存的修改。你可以继续编辑、放弃修改，或加入草稿箱稍后继续。',
        en: 'This memo has unsaved changes. Continue editing, discard them, or add the edit to Draft Box.',
      ),
      actions: [
        PlatformDialogAction<_EditorCloseDecision>(
          value: _EditorCloseDecision.continueEditing,
          label: context.tr(zh: '继续编辑', en: 'Continue editing'),
        ),
        PlatformDialogAction<_EditorCloseDecision>(
          value: _EditorCloseDecision.discard,
          label: context.tr(zh: '放弃修改', en: 'Discard changes'),
          isDestructive: true,
        ),
        PlatformDialogAction<_EditorCloseDecision>(
          value: _EditorCloseDecision.addToDraftBox,
          label: context.tr(zh: '加入草稿箱', en: 'Add to Draft Box'),
          isDefault: true,
        ),
      ],
    );
  }

  Future<void> _saveVisibleEditDraftAndClose(LocalMemo existing) async {
    if (!_relationsLoaded && !_relationsDirty) {
      await _loadExistingRelations();
    }
    if (!mounted) return;
    final snapshot = _editDraftSessionHelper.buildEditDraftSnapshot(
      content: _contentController.text,
      visibility: _visibility,
      linkedMemos: List<_LinkedMemo>.from(_linkedMemos),
      existingAttachments: List<Attachment>.from(_existingAttachments),
      pendingAttachments: List<_PendingAttachment>.from(_pendingAttachments),
      location: _location,
    );
    final draftUid = await ref
        .read(composeDraftRepositoryProvider)
        .saveEditDraft(
          targetMemoUid: existing.uid,
          snapshot: snapshot,
          targetMemoContentFingerprint: existing.contentFingerprint,
          targetMemoUpdateTime: existing.updateTime,
        );
    _activeVisibleEditDraftUid = draftUid ?? _activeVisibleEditDraftUid;
    _skipDraftPersistOnDispose = true;
    _draftTimer?.cancel();
    try {
      await _clearEditorDraft();
    } catch (_) {}
    if (!mounted) return;
    _performCloseEditor();
  }

  Future<void> _discardEditorChangesAndClose() async {
    _skipDraftPersistOnDispose = true;
    _draftTimer?.cancel();
    if (_openedFromVisibleEditDraft) {
      try {
        await _deleteActiveVisibleEditDraft();
      } catch (_) {}
    }
    try {
      await _clearEditorDraft();
    } catch (_) {}
    if (!mounted) return;
    _performCloseEditor();
  }

  Future<void> _deleteActiveVisibleEditDraft({
    Set<String> keepPaths = const <String>{},
  }) async {
    final repository = ref.read(composeDraftRepositoryProvider);
    final draftUid = _activeVisibleEditDraftUid?.trim();
    if (draftUid != null && draftUid.isNotEmpty) {
      await repository.deleteDraft(draftUid, keepPaths: keepPaths);
      return;
    }
    final targetUid = widget.existing?.uid.trim() ?? '';
    if (targetUid.isNotEmpty) {
      await repository.deleteEditDraftForMemo(targetUid);
    }
  }

  Future<void> _deleteActiveVisibleCreateDraft({
    Set<String> keepPaths = const <String>{},
  }) async {
    final draftUid = _activeVisibleCreateDraftUid?.trim();
    if (draftUid == null || draftUid.isEmpty) return;
    await ref
        .read(composeDraftRepositoryProvider)
        .deleteDraft(draftUid, keepPaths: keepPaths);
  }

  void _performCloseEditor() {
    _draftTimer?.cancel();
    final onCloseRequested = widget.onCloseRequested;
    if (onCloseRequested != null) {
      onCloseRequested();
      return;
    }
    if (!mounted) return;
    if (!_allowRoutePop) {
      setState(() => _allowRoutePop = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.safePop();
    });
  }

  Future<void> _loadTagStats() async {
    try {
      final tags = await ref.read(tagStatsProvider.future);
      if (!mounted) return;
      setState(() => _tagStatsCache = tags);
    } catch (_) {}
  }

  Future<void> _loadExistingRelations({bool force = false}) async {
    final existing = widget.existing;
    if (existing == null) return;
    if (_relationsLoaded && !force) return;
    final inFlight = _relationsLoadFuture;
    if (inFlight != null) return inFlight;

    final future = _loadExistingRelationsInternal(existing.uid);
    _relationsLoadFuture = future;
    return future;
  }

  Future<void> _loadExistingRelationsInternal(String memoUid) async {
    _relationsLoading = true;
    if (mounted) {
      setState(() {});
    }

    try {
      final uid = memoUid.trim();
      if (uid.isEmpty) {
        _relationsLoaded = true;
        return;
      }

      final controller = ref.read(memoEditorControllerProvider);
      final memoName = 'memos/$uid';
      final items = await controller.listMemoRelationsAll(memoUid: uid);

      final linked = <_LinkedMemo>[];
      final seen = <String>{};
      for (final relation in items) {
        if (relation.type.trim().toUpperCase() != 'REFERENCE') continue;
        if (relation.memo.name.trim() != memoName) continue;
        final relatedName = relation.relatedMemo.name.trim();
        if (relatedName.isEmpty || relatedName == memoName) continue;
        if (!seen.add(relatedName)) continue;
        final label = _linkedMemoLabelFromRelation(
          relatedName,
          relation.relatedMemo.snippet,
        );
        linked.add(_LinkedMemo(name: relatedName, label: label));
      }

      if (!mounted) return;
      setState(() {
        _composer.setLinkedMemos(linked);
        _relationsLoaded = true;
        _relationsDirty = false;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      _relationsLoading = false;
      _relationsLoadFuture = null;
      if (mounted) {
        setState(() {});
      }
    }
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

  Future<void> _save() async {
    if (_saving) return;
    final content = _contentController.text.trimRight();
    final existing = widget.existing;
    final location = _location;
    final locationChanged = !_sameLocation(_initialLocation, location);
    final existingAttachments = List<Attachment>.from(_existingAttachments);
    final pendingAttachments = List<_PendingAttachment>.from(
      _pendingAttachments,
    );
    final hasPendingAttachments = pendingAttachments.isNotEmpty;
    final shouldSyncAttachments = _shouldSyncAttachments(
      existingAttachments: existingAttachments,
      hasPendingAttachments: hasPendingAttachments,
    );
    final hasPrimaryChanges =
        existing != null &&
        (content != existing.content ||
            _visibility != existing.visibility ||
            _pinned != existing.pinned ||
            locationChanged ||
            shouldSyncAttachments);
    final hasAttachments =
        existingAttachments.isNotEmpty || pendingAttachments.isNotEmpty;
    if (content.trim().isEmpty && !hasAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_content_cannot_empty),
        ),
      );
      return;
    }
    if (!_ensurePendingAttachmentsReady()) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final uid = existing?.uid ?? generateUid();
      final createTime = existing?.createTime ?? now;
      final state = existing?.state ?? 'NORMAL';
      final relations = _linkedMemos
          .map((m) => m.toRelationJson())
          .toList(growable: false);
      final includeRelations =
          _relationsDirty && (existing != null || relations.isNotEmpty);
      final attachments = [
        ...existingAttachments.map((a) => a.toJson()),
        ...pendingAttachments.map((p) {
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
        }),
      ];
      final tagRecognitionPolicy = ref
          .read(currentWorkspacePreferencesProvider)
          .tagRecognitionPolicy;
      final tags = extractTags(content, policy: tagRecognitionPolicy);
      final pendingUploads = pendingAttachments
          .map(
            (attachment) => MemoEditorPendingAttachment(
              uid: attachment.uid,
              filePath: attachment.filePath,
              filename: attachment.filename,
              mimeType: attachment.mimeType,
              size: attachment.size,
              skipCompression: attachment.skipCompression,
            ),
          )
          .toList(growable: false);

      await ref
          .read(memoEditorControllerProvider)
          .saveMemo(
            existing: existing,
            uid: uid,
            content: content,
            visibility: _visibility,
            pinned: _pinned,
            state: state,
            createTime: createTime,
            now: now,
            tags: tags,
            attachments: attachments,
            location: location,
            locationChanged: locationChanged,
            relationCount: existing?.relationCount ?? 0,
            hasPrimaryChanges: hasPrimaryChanges,
            attachmentsToDelete: _attachmentsToDelete,
            includeRelations: includeRelations,
            relations: relations,
            shouldSyncAttachments: shouldSyncAttachments,
            hasPendingAttachments: hasPendingAttachments,
            pendingAttachments: pendingUploads,
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

      _composer.clearPendingAttachments();
      _pickedImages.clear();
      _attachmentsToDelete.clear();
      _clearLinkedMemos();
      _skipDraftPersistOnDispose = true;
      try {
        await _clearEditorDraft();
      } catch (_) {}
      if (_openedFromVisibleEditDraft) {
        try {
          await _deleteActiveVisibleEditDraft(
            keepPaths: pendingAttachments
                .map((attachment) => attachment.filePath.trim())
                .where((path) => path.isNotEmpty)
                .toSet(),
          );
        } catch (_) {}
      }
      if (existing == null) {
        try {
          await _deleteActiveVisibleCreateDraft(
            keepPaths: pendingAttachments
                .map((attachment) => attachment.filePath.trim())
                .where((path) => path.isNotEmpty)
                .toSet(),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        onSaved();
        return;
      }
      _performCloseEditor();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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

  void _startTagAutocomplete() {
    if (_saving) return;
    _markSceneGuideSeen(SceneMicroGuideId.memoEditorTagAutocomplete);
    _composer.startTagAutocomplete(
      policy: ref
          .read(currentWorkspacePreferencesProvider)
          .tagRecognitionPolicy,
      requestFocus: _editorFocusNode.requestFocus,
    );
    setState(() {});
  }

  void _applyTagSuggestion(ActiveTagQuery query, TagStat tag) {
    _markSceneGuideSeen(SceneMicroGuideId.memoEditorTagAutocomplete);
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
    if (_saving) return;
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
    if (_saving) return;
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
    await _applyTemplate(selected);
  }

  Future<void> _applyTemplate(MemoTemplate template) async {
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

  Future<void> _openTodoShortcutMenuFromKey(GlobalKey key) async {
    if (_saving) return;
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

  Future<void> _openTodoShortcutMenu(RelativeRect position) async {
    if (_saving) return;
    final action = await showMenu<_TodoShortcutAction>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: _TodoShortcutAction.checkbox,
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
          value: _TodoShortcutAction.codeBlock,
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
      case _TodoShortcutAction.checkbox:
        _composer.insertTaskCheckbox();
        break;
      case _TodoShortcutAction.codeBlock:
        _composer.insertCodeBlock();
        break;
    }
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
    if (_saving || _locating) return;
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

  bool _sameLocation(MemoLocation? a, MemoLocation? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.placeholder.trim() != b.placeholder.trim()) return false;
    if ((a.latitude - b.latitude).abs() > 1e-6) return false;
    if ((a.longitude - b.longitude).abs() > 1e-6) return false;
    return true;
  }

  List<MemoComposeToolbarActionSpec> _buildComposeToolbarActions({
    required MemoToolbarPreferences preferences,
    required List<MemoTemplate> availableTemplates,
  }) {
    final actions = <MemoComposeToolbarActionSpec>[
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.bold,
        enabled: !_saving,
        onPressed: _toggleBold,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.italic,
        enabled: !_saving,
        onPressed: _composer.toggleItalic,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.strikethrough,
        enabled: !_saving,
        onPressed: _composer.toggleStrikethrough,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.inlineCode,
        enabled: !_saving,
        onPressed: _composer.toggleInlineCode,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.list,
        enabled: !_saving,
        onPressed: _composer.toggleUnorderedList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.orderedList,
        enabled: !_saving,
        onPressed: _composer.toggleOrderedList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.taskList,
        enabled: !_saving,
        onPressed: _composer.toggleTaskList,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.quote,
        enabled: !_saving,
        onPressed: _composer.toggleQuote,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading1,
        enabled: !_saving,
        onPressed: _composer.toggleHeading1,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading2,
        enabled: !_saving,
        onPressed: _composer.toggleHeading2,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.heading3,
        enabled: !_saving,
        onPressed: _composer.toggleHeading3,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.underline,
        enabled: !_saving,
        onPressed: _toggleUnderline,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.highlight,
        enabled: !_saving,
        onPressed: _composer.toggleHighlight,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.divider,
        enabled: !_saving,
        onPressed: _composer.insertDivider,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.codeBlock,
        enabled: !_saving,
        onPressed: _composer.insertCodeBlock,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.inlineMath,
        enabled: !_saving,
        onPressed: _composer.insertInlineMath,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.blockMath,
        enabled: !_saving,
        onPressed: _composer.insertBlockMath,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.table,
        enabled: !_saving,
        onPressed: _composer.insertTableTemplate,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.cutParagraph,
        enabled: !_saving,
        onPressed: () => unawaited(_composer.cutCurrentParagraphs()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.undo,
        enabled: !_saving && _composer.canUndo,
        onPressed: _undo,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.redo,
        enabled: !_saving && _composer.canRedo,
        onPressed: _redo,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.tag,
        buttonKey: _tagMenuKey,
        enabled: !_saving,
        onPressed: _startTagAutocomplete,
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.template,
        buttonKey: _templateMenuKey,
        enabled: !_saving,
        onPressed: () => unawaited(
          _openTemplateMenuFromKey(_templateMenuKey, availableTemplates),
        ),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.attachment,
        enabled: !_saving,
        onPressed: () => unawaited(_pickAttachments()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.gallery,
        enabled: !_saving,
        onPressed: () => unawaited(_handleGalleryToolbarPressed()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.todo,
        buttonKey: _todoMenuKey,
        enabled: !_saving,
        onPressed: () => unawaited(_openTodoShortcutMenuFromKey(_todoMenuKey)),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.link,
        enabled: !_saving,
        onPressed: () => unawaited(_openLinkMemoSheet()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.camera,
        enabled: !_saving,
        onPressed: () => unawaited(_capturePhoto()),
      ),
      MemoComposeToolbarActionSpec.builtin(
        id: MemoToolbarActionId.location,
        icon: _locating ? Icons.my_location : null,
        enabled: !_saving && !_locating,
        onPressed: () => unawaited(_requestLocation()),
      ),
      ...preferences.customButtons.map(
        (button) => MemoComposeToolbarActionSpec.custom(
          button: button,
          enabled: !_saving,
          onPressed: () => _insertText(button.insertContent),
        ),
      ),
    ];

    return actions;
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
      onVisibilityPressed: _saving ? null : _openVisibilityMenuFromKey,
    );
  }

  Future<void> _openLinkMemoSheet() async {
    if (_saving) return;
    if (_relationsLoading) {
      showTopToast(context, context.t.strings.legacy.msg_loading_references);
      return;
    }
    if (widget.existing != null && !_relationsLoaded) {
      await _loadExistingRelations();
      if (!_relationsLoaded) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_failed_load_references),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
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
    if (_saving) return;
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
        result.attachments.map(
          (attachment) => _PendingAttachment(
            uid: generateUid(),
            filePath: attachment.filePath,
            filename: attachment.filename,
            mimeType: attachment.mimeType,
            size: attachment.size,
            skipCompression: attachment.skipCompression,
          ),
        ),
      );
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
      _scheduleDraftSave();
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
    if (_saving) return;
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
              'MemoEditor: file_picker_missing_path',
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
            'MemoEditor: file_picker_empty_resolved_path',
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
            'MemoEditor: file_picker_missing_file',
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
          'MemoEditor: file_picker_attachment_ready',
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
        'MemoEditor: file_picker_summary',
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
      _scheduleDraftSave();
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

  Future<void> _capturePhoto() async {
    if (_saving) return;
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
      _scheduleDraftSave();
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
    setState(() {
      _composer.removePendingAttachment(uid);
      _pickedImages.removeWhere((x) => x.path == removed.filePath);
    });
    unawaited(
      ref
          .read(queuedAttachmentStagerProvider)
          .deleteManagedFile(removed.filePath),
    );
    _scheduleDraftSave();
  }

  void _queueDeletedAttachment(Attachment attachment) {
    final key = _attachmentKey(attachment);
    if (key.isEmpty) return;
    final exists = _attachmentsToDelete.any(
      (item) => _attachmentKey(item) == key,
    );
    if (exists) return;
    _attachmentsToDelete.add(attachment);
  }

  void _removeExistingAttachment(Attachment attachment) {
    if (_saving) return;
    final key = _attachmentKey(attachment);
    if (key.isEmpty) return;
    setState(() {
      _existingAttachments.removeWhere((item) => _attachmentKey(item) == key);
      _queueDeletedAttachment(attachment);
    });
    _scheduleDraftSave();
  }

  bool _shouldSyncAttachments({
    required List<Attachment> existingAttachments,
    required bool hasPendingAttachments,
  }) {
    if (hasPendingAttachments) return true;
    final currentNames = existingAttachments
        .map(_attachmentKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    return !_sameStringSet(currentNames, _initialAttachmentKeys);
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

  String _existingAttachmentUrl(
    Attachment attachment, {
    required bool thumbnail,
    required Uri? baseUrl,
  }) {
    final raw = attachment.externalLink.trim();
    if (raw.isNotEmpty &&
        !raw.startsWith('file://') &&
        !raw.startsWith('content://')) {
      final isRelative = !isAbsoluteUrl(raw);
      final resolved = resolveMaybeRelativeUrl(baseUrl, raw);
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

  File? _localExistingAttachmentFile(Attachment attachment) {
    final raw = attachment.externalLink.trim();
    if (!raw.startsWith('file://')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final path = uri.toFilePath();
    if (path.trim().isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String _pendingSourceId(String uid) => 'pending:$uid';
  String _existingSourceId(Attachment attachment) =>
      'existing:${attachment.name.isNotEmpty ? attachment.name : attachment.uid}';

  List<ImagePreviewItem> _editorImagePreviewItems(
    Uri? baseUrl,
    String? authHeader,
  ) {
    final items = <ImagePreviewItem>[];
    for (final attachment in _existingAttachments) {
      if (!_isImageMimeType(attachment.type)) continue;
      final localFile = _localExistingAttachmentFile(attachment);
      final fullUrl = _existingAttachmentUrl(
        attachment,
        thumbnail: false,
        baseUrl: baseUrl,
      );
      items.add(
        ImagePreviewItem(
          id: _existingSourceId(attachment),
          title: attachment.filename,
          mimeType: attachment.type,
          localFile: localFile,
          fullUrl: fullUrl.isNotEmpty ? fullUrl : null,
          headers: authHeader == null ? null : {'Authorization': authHeader},
          width: attachment.width,
          height: attachment.height,
        ),
      );
    }

    for (final attachment in _pendingAttachments) {
      if (!_isImageMimeType(attachment.mimeType)) continue;
      final file = _resolvePendingAttachmentFile(attachment);
      if (file == null) continue;
      items.add(
        ImagePreviewItem(
          id: _pendingSourceId(attachment.uid),
          title: attachment.filename,
          mimeType: attachment.mimeType,
          localFile: file,
        ),
      );
    }
    return items;
  }

  Future<void> _openAttachmentViewer(
    String sourceId, {
    required Uri? baseUrl,
    required String? authHeader,
  }) async {
    final items = _editorImagePreviewItems(baseUrl, authHeader);
    final index = items.indexWhere((item) => item.id == sourceId);
    if (index < 0) return;
    await ImagePreviewLauncher.open(
      context,
      ImagePreviewOpenRequest(
        items: items,
        initialIndex: index,
        onReplace: (result) => _replaceEditedAttachment(
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

  Future<void> _replaceEditedAttachment(EditedImageResult result) async {
    final id = result.sourceId;
    if (id.startsWith('pending:')) {
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
        ),
      );
      setState(() {
        _composer.replacePendingAttachment(uid, stagedReplacement);
      });
      if (existing.filePath != stagedReplacement.filePath) {
        unawaited(
          ref
              .read(queuedAttachmentStagerProvider)
              .deleteManagedFile(existing.filePath),
        );
      }
      _scheduleDraftSave();
      return;
    }

    if (!id.startsWith('existing:')) return;
    final name = id.substring('existing:'.length);
    final index = _existingAttachments.indexWhere(
      (a) => a.name == name || a.uid == name,
    );
    if (index < 0) return;
    final removed = _existingAttachments[index];
    final newUid = generateUid();
    final stagedReplacement = await _stagePendingAttachment(
      _PendingAttachment(
        uid: newUid,
        filePath: result.filePath,
        filename: result.filename,
        mimeType: result.mimeType,
        size: result.size,
        skipCompression: false,
      ),
    );
    setState(() {
      _existingAttachments.removeAt(index);
      _queueDeletedAttachment(removed);
      _composer.addPendingAttachments([stagedReplacement]);
    });
    _scheduleDraftSave();
  }

  Widget _buildAttachmentPreview(
    bool isDark,
    Uri? baseUrl,
    String? authHeader,
    bool rebaseAbsoluteFileUrlForV024,
    bool attachAuthForSameOriginAbsolute,
  ) {
    if (_pendingAttachments.isEmpty && _existingAttachments.isEmpty) {
      return const SizedBox.shrink();
    }
    const tileSize = 62.0;
    final tiles = <Widget>[];
    for (final attachment in _existingAttachments) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(width: 10));
      tiles.add(
        _buildExistingAttachmentTile(
          attachment,
          isDark: isDark,
          size: tileSize,
          baseUrl: baseUrl,
          authHeader: authHeader,
          rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        ),
      );
    }
    for (final attachment in _pendingAttachments) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(width: 10));
      tiles.add(
        _buildAttachmentTile(
          attachment,
          isDark: isDark,
          size: tileSize,
          baseUrl: baseUrl,
          authHeader: authHeader,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: tileSize,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: tiles),
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(
    _PendingAttachment attachment, {
    required bool isDark,
    required double size,
    required Uri? baseUrl,
    required String? authHeader,
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
    final tileRadius = BorderRadius.circular(14);
    final isImage = _isImageMimeType(attachment.mimeType);
    final isVideo = _isVideoMimeType(attachment.mimeType);
    final file = _resolvePendingAttachmentFile(attachment);
    final cacheExtent = resolveThumbnailCacheExtent(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );

    Widget content;
    if (isImage && file != null) {
      content = ImagePreviewTile(
        item: ImagePreviewItem(
          id: _pendingSourceId(attachment.uid),
          title: attachment.filename,
          mimeType: attachment.mimeType,
          localFile: file,
        ),
        width: double.infinity,
        height: double.infinity,
        borderRadius: 14,
        backgroundColor: surfaceColor,
        borderColor: tileBorderColor,
        placeholderColor: surfaceColor,
        iconColor: iconColor,
        cacheWidth: cacheExtent,
        cacheHeight: cacheExtent,
        logScope: 'memo_editor_pending_tile',
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

    final tile = isImage && file != null
        ? SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: tileRadius,
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: tileRadius,
                child: Stack(fit: StackFit.expand, children: [content]),
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: tileRadius,
              border: Border.all(color: tileBorderColor),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(borderRadius: tileRadius, child: content),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: (isImage && file != null)
              ? () => _openAttachmentViewer(
                  _pendingSourceId(attachment.uid),
                  baseUrl: baseUrl,
                  authHeader: authHeader,
                )
              : null,
          child: tile,
        ),
        if (attachment.skipCompression && isImage)
          Positioned(
            left: 4,
            bottom: 4,
            child: IgnorePointer(child: _buildOriginalBadge()),
          ),
        if (!attachment.isReadyForSubmit)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: tileRadius,
              child: AttachmentProcessingOverlay(
                status: attachment.processingStatus,
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _saving
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

  Widget _buildExistingAttachmentTile(
    Attachment attachment, {
    required bool isDark,
    required double size,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
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
    final tileRadius = BorderRadius.circular(14);
    final isImage = _isImageMimeType(attachment.type);
    final isVideo = _isVideoMimeType(attachment.type);
    final localFile = _localExistingAttachmentFile(attachment);
    final thumbUrl = _existingAttachmentUrl(
      attachment,
      thumbnail: true,
      baseUrl: baseUrl,
    );
    final cacheExtent = resolveThumbnailCacheExtent(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );
    final videoEntry = isVideo
        ? memoVideoEntryFromAttachment(
            attachment,
            baseUrl,
            authHeader,
            rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
            attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
          )
        : null;

    Widget content;
    if (isImage && localFile != null) {
      content = ImagePreviewTile(
        item: ImagePreviewItem(
          id: _existingSourceId(attachment),
          title: attachment.filename,
          mimeType: attachment.type,
          localFile: localFile,
          width: attachment.width,
          height: attachment.height,
        ),
        width: double.infinity,
        height: double.infinity,
        borderRadius: 14,
        backgroundColor: surfaceColor,
        borderColor: tileBorderColor,
        placeholderColor: surfaceColor,
        iconColor: iconColor,
        cacheWidth: cacheExtent,
        cacheHeight: cacheExtent,
        logScope: 'memo_editor_existing_tile',
      );
    } else if (isImage && thumbUrl.isNotEmpty) {
      content = ImagePreviewTile(
        item: ImagePreviewItem(
          id: _existingSourceId(attachment),
          title: attachment.filename,
          mimeType: attachment.type,
          thumbnailUrl: thumbUrl,
          fullUrl:
              _existingAttachmentUrl(
                attachment,
                thumbnail: false,
                baseUrl: baseUrl,
              ).trim().isEmpty
              ? null
              : _existingAttachmentUrl(
                  attachment,
                  thumbnail: false,
                  baseUrl: baseUrl,
                ),
          headers: authHeader == null ? null : {'Authorization': authHeader},
          width: attachment.width,
          height: attachment.height,
        ),
        width: double.infinity,
        height: double.infinity,
        borderRadius: 14,
        backgroundColor: surfaceColor,
        borderColor: tileBorderColor,
        placeholderColor: surfaceColor,
        iconColor: iconColor,
        logScope: 'memo_editor_existing_tile',
      );
    } else if (videoEntry != null) {
      content = AttachmentVideoThumbnail(
        entry: videoEntry,
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

    final tile = isImage
        ? SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: tileRadius,
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: tileRadius,
                child: Stack(fit: StackFit.expand, children: [content]),
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: tileRadius,
              border: Border.all(color: tileBorderColor),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: isImage
              ? () => _openAttachmentViewer(
                  _existingSourceId(attachment),
                  baseUrl: baseUrl,
                  authHeader: authHeader,
                )
              : null,
          child: tile,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _saving ? null : () => _removeExistingAttachment(attachment),
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

  Set<String> get _linkedMemoNames => _linkedMemos.map((m) => m.name).toSet();

  void _clearLocation() {
    if (_saving) return;
    if (_location == null) return;
    setState(() => _location = null);
    _scheduleDraftSave();
  }

  void _addLinkedMemo(Memo memo) {
    final name = memo.name.trim();
    if (name.isEmpty) return;
    if (_linkedMemos.any((m) => m.name == name)) return;
    final label = _linkedMemoLabel(memo);
    setState(() {
      _composer.addLinkedMemo(_LinkedMemo(name: name, label: label));
      _relationsDirty = true;
    });
  }

  void _removeLinkedMemo(String name) {
    final before = _linkedMemos.length;
    setState(() {
      _composer.removeLinkedMemo(name);
      if (_linkedMemos.length != before) {
        _relationsDirty = true;
      }
    });
  }

  void _clearLinkedMemos() {
    if (_linkedMemos.isEmpty) return;
    setState(() {
      _composer.clearLinkedMemos();
    });
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

  String _linkedMemoLabelFromRelation(String relatedName, String snippet) {
    final trimmedSnippet = snippet.trim();
    if (trimmedSnippet.isNotEmpty) {
      return _truncateLabel(trimmedSnippet);
    }
    final name = relatedName.trim();
    if (name.isNotEmpty) {
      return _truncateLabel(
        name.startsWith('memos/') ? name.substring('memos/'.length) : name,
      );
    }
    return _truncateLabel(relatedName);
  }

  String _truncateLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  Future<void> _openVisibilityMenuFromKey() async {
    if (_saving) return;
    final target = _visibilityMenuKey.currentContext;
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
    if (_saving) return;
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
    setState(() => _visibility = selection);
    _scheduleDraftSave();
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

  List<Widget> _buildFullscreenMetadataChildren({
    required BuildContext context,
    required bool isDark,
    required Color chipBg,
    required Color chipText,
    required Color chipDelete,
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
    required bool showTagAutocompleteGuide,
    required String tagAutocompleteGuideMessage,
  }) {
    final children = <Widget>[
      _buildAttachmentPreview(
        isDark,
        baseUrl,
        authHeader,
        rebaseAbsoluteFileUrlForV024,
        attachAuthForSameOriginAbsolute,
      ),
      if (showTagAutocompleteGuide) ...[
        SceneMicroGuideBanner(
          message: tagAutocompleteGuideMessage,
          onDismiss: () =>
              _markSceneGuideSeen(SceneMicroGuideId.memoEditorTagAutocomplete),
        ),
        const SizedBox(height: 12),
      ],
      if (_linkedMemos.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _linkedMemos
                .map(
                  (memo) => InputChip(
                    label: Text(
                      memo.label,
                      style: TextStyle(fontSize: 12, color: chipText),
                    ),
                    backgroundColor: chipBg,
                    deleteIconColor: chipDelete,
                    onDeleted: _saving
                        ? null
                        : () => _removeLinkedMemo(memo.name),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      if (_locating)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                context.t.strings.legacy.msg_locating,
                style: TextStyle(fontSize: 12, color: chipText),
              ),
            ],
          ),
        ),
      if (_location != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              avatar: Icon(Icons.place_outlined, size: 16, color: chipText),
              label: Text(
                _location!.displayText(fractionDigits: 6),
                style: TextStyle(fontSize: 12, color: chipText),
              ),
              backgroundColor: chipBg,
              deleteIconColor: chipDelete,
              onPressed: _saving ? null : _requestLocation,
              onDeleted: _saving ? null : _clearLocation,
            ),
          ),
        ),
    ];
    return children;
  }

  Widget _buildFullscreenEditorTextField({
    required bool isDark,
    required TextStyle editorTextStyle,
    required String editorHintText,
    required ActiveTagQuery? activeTagQuery,
    required List<TagStat> tagSuggestions,
    required TagColorLookup tagColorLookup,
    required int highlightedTagSuggestionIndex,
    required ValueChanged<int> onTagHighlight,
    required void Function(ActiveTagQuery query, TagStat tag) onTagSelect,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: KeyedSubtree(
            key: _editorFieldKey,
            child: Focus(
              canRequestFocus: false,
              child: PlatformTextField(
                key: _pageFullscreenTextFieldKey,
                controller: _contentController,
                focusNode: _editorFocusNode,
                autofocus: widget.autoFocus,
                enabled: !_saving,
                inputFormatters: const [SmartEnterTextInputFormatter()],
                keyboardType: TextInputType.multiline,
                maxLines: null,
                expands: true,
                style: editorTextStyle,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: editorHintText,
                  hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF666666)
                        : Colors.grey.shade500,
                  ),
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
                value: _contentController.value,
                textStyle: editorTextStyle,
                tags: tagSuggestions,
                tagColors: tagColorLookup,
                highlightedIndex: highlightedTagSuggestionIndex,
                onHighlight: onTagHighlight,
                onSelect: (tag) => onTagSelect(activeTagQuery, tag),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullscreenEditorSaveButton() {
    final buttonEnabled = !_saving;
    final buttonColor = buttonEnabled
        ? MemoFlowPalette.primary
        : Theme.of(context).colorScheme.outline;
    return Tooltip(
      message: context.t.strings.legacy.msg_save,
      child: InkResponse(
        key: _pageFullscreenSaveButtonKey,
        onTap: buttonEnabled ? _save : null,
        radius: 17,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_saving)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MemoFlowPalette.primary,
                  ),
                )
              else
                Icon(Icons.check_rounded, size: 18, color: buttonColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenEditorCompose({
    required bool isDark,
    required Color background,
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
    required Uri? baseUrl,
    required String? authHeader,
    required bool rebaseAbsoluteFileUrlForV024,
    required bool attachAuthForSameOriginAbsolute,
    required bool showTagAutocompleteGuide,
    required String tagAutocompleteGuideMessage,
  }) {
    final toolbarActions = _buildComposeToolbarActions(
      preferences: toolbarPreferences,
      availableTemplates: availableTemplates,
    );

    return Scaffold(
      backgroundColor: background,
      body: MemoComposeFullscreenSurface(
        isDark: isDark,
        sheetColor: sheetColor,
        toolbarPreferences: toolbarPreferences,
        toolbarActions: toolbarActions,
        metadataChildren: _buildFullscreenMetadataChildren(
          context: context,
          isDark: isDark,
          chipBg: chipBg,
          chipText: chipText,
          chipDelete: chipDelete,
          baseUrl: baseUrl,
          authHeader: authHeader,
          rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
          attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
          showTagAutocompleteGuide: showTagAutocompleteGuide,
          tagAutocompleteGuideMessage: tagAutocompleteGuideMessage,
        ),
        editor: _buildFullscreenEditorTextField(
          isDark: isDark,
          editorTextStyle: editorTextStyle,
          editorHintText: editorHintText,
          activeTagQuery: activeTagQuery,
          tagSuggestions: tagSuggestions,
          tagColorLookup: tagColorLookup,
          highlightedTagSuggestionIndex: highlightedTagSuggestionIndex,
          onTagHighlight: (index) {
            if (_tagAutocompleteIndex == index) return;
            setState(() {
              _composer.setTagAutocompleteIndex(index);
            });
          },
          onTagSelect: (query, tag) => _applyTagSuggestion(query, tag),
        ),
        primaryAction: _buildFullscreenEditorSaveButton(),
        expandCollapseKey: _pageFullscreenCollapseButtonKey,
        closeKey: _pageFullscreenCloseButtonKey,
        topToolbarKey: _pageFullscreenTopToolbarKey,
        bottomToolbarKey: _pageFullscreenBottomToolbarKey,
        visibilityButtonKey: _visibilityMenuKey,
        visibilityLabel: visibilityLabel,
        visibilityIcon: visibilityIcon,
        visibilityColor: visibilityColor,
        busy: _saving,
        onCollapse: _collapsePageFullscreenCompose,
        onClose: () => unawaited(_requestCloseEditor()),
        onVisibilityPressed: () => unawaited(_openVisibilityMenuFromKey()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _keyboardResumeController.updateKeyboardVisibility();
    final existing = widget.existing;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final hintColor = isDark ? const Color(0xFF666666) : Colors.grey.shade500;
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
    final toolbarPreferences = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (p) => p.memoToolbarPreferences,
      ),
    );
    final tagRecognitionPolicy = ref.watch(
      currentWorkspacePreferencesProvider.select((p) => p.tagRecognitionPolicy),
    );
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
    final authHeader = token.isEmpty ? null : 'Bearer $token';
    final tagStats = ref.watch(tagStatsProvider).valueOrNull ?? _tagStatsCache;
    final activeTagQuery = detectActiveTagQuery(
      _contentController.value,
      policy: tagRecognitionPolicy,
    );
    final tagColorLookup = ref.watch(tagColorLookupProvider);
    final tagSuggestions = activeTagQuery == null
        ? const <TagStat>[]
        : buildTagSuggestions(tagStats, query: activeTagQuery.query);
    final sceneGuideState = ref.watch(sceneMicroGuideProvider);
    final showTagAutocompleteGuide =
        sceneGuideState.loaded &&
        !sceneGuideState.isSeen(SceneMicroGuideId.memoEditorTagAutocomplete) &&
        _editorFocusNode.hasFocus &&
        tagStats.isNotEmpty;
    final tagAutocompleteGuideMessage = isDesktopPlatform()
        ? context
              .t
              .strings
              .legacy
              .msg_scene_micro_guide_editor_tag_autocomplete_desktop
        : context
              .t
              .strings
              .legacy
              .msg_scene_micro_guide_editor_tag_autocomplete_mobile;
    final highlightedTagSuggestionIndex = tagSuggestions.isEmpty
        ? 0
        : _tagAutocompleteIndex.clamp(0, tagSuggestions.length - 1).toInt();
    final editorTextStyle = TextStyle(
      fontSize: 16,
      height: 1.35,
      color: textColor,
    );
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
    final availableTemplates = templateSettings.enabled
        ? templateSettings.templates
        : const <MemoTemplate>[];
    final mediaSize = MediaQuery.sizeOf(context);
    final modalHorizontalInset = mediaSize.width >= 1400 ? 40.0 : 24.0;
    final modalVerticalInset = mediaSize.height >= 900 ? 28.0 : 20.0;
    final titleText = existing == null
        ? context.t.strings.legacy.msg_memo_2
        : context.t.strings.legacy.msg_edit_memo;
    final editorHintText =
        context.t.strings.legacy.msg_write_something_supports_tag_tasks_x;

    if (_isPageFullscreenCompose) {
      final fullscreenEditor = _buildFullscreenEditorCompose(
        isDark: isDark,
        background: background,
        sheetColor: cardColor,
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
        baseUrl: baseUrl,
        authHeader: authHeader,
        rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
        attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
        showTagAutocompleteGuide: showTagAutocompleteGuide,
        tagAutocompleteGuideMessage: tagAutocompleteGuideMessage,
      );
      return PopScope(
        canPop: _allowRoutePop,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          unawaited(_requestCloseEditor());
        },
        child: fullscreenEditor,
      );
    }

    final pageFullscreenAction = IconButton(
      key: _pageFullscreenExpandButtonKey,
      tooltip: context.t.strings.legacy.msg_maximize,
      onPressed: _saving ? null : _enterPageFullscreenCompose,
      icon: Icon(Icons.fullscreen_rounded, color: MemoFlowPalette.primary),
    );
    final composeContent = Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAttachmentPreview(
                  isDark,
                  baseUrl,
                  authHeader,
                  rebaseAbsoluteFileUrlForV024,
                  attachAuthForSameOriginAbsolute,
                ),
                if (showTagAutocompleteGuide) ...[
                  SceneMicroGuideBanner(
                    message: tagAutocompleteGuideMessage,
                    onDismiss: () => _markSceneGuideSeen(
                      SceneMicroGuideId.memoEditorTagAutocomplete,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: KeyedSubtree(
                          key: _editorFieldKey,
                          child: Focus(
                            canRequestFocus: false,
                            child: PlatformTextField(
                              controller: _contentController,
                              focusNode: _editorFocusNode,
                              autofocus: widget.autoFocus,
                              enabled: !_saving,
                              inputFormatters: const [
                                SmartEnterTextInputFormatter(),
                              ],
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                              expands: true,
                              style: editorTextStyle,
                              decoration: InputDecoration(
                                hintText: editorHintText,
                                hintStyle: TextStyle(color: hintColor),
                                border: InputBorder.none,
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
                              value: _contentController.value,
                              textStyle: editorTextStyle,
                              tags: tagSuggestions,
                              tagColors: tagColorLookup,
                              highlightedIndex: highlightedTagSuggestionIndex,
                              onHighlight: (index) {
                                if (_tagAutocompleteIndex == index) {
                                  return;
                                }
                                setState(() {
                                  _composer.setTagAutocompleteIndex(index);
                                });
                              },
                              onSelect: (tag) =>
                                  _applyTagSuggestion(activeTagQuery, tag),
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
        Divider(height: 1, color: borderColor),
        if (_linkedMemos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _linkedMemos
                  .map(
                    (memo) => InputChip(
                      label: Text(
                        memo.label,
                        style: TextStyle(fontSize: 12, color: chipText),
                      ),
                      backgroundColor: chipBg,
                      deleteIconColor: chipDelete,
                      onDeleted: _saving
                          ? null
                          : () => _removeLinkedMemo(memo.name),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        if (_locating)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  context.t.strings.legacy.msg_locating,
                  style: TextStyle(fontSize: 12, color: chipText),
                ),
              ],
            ),
          ),
        if (_location != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: Icon(Icons.place_outlined, size: 16, color: chipText),
                label: Text(
                  _location!.displayText(fractionDigits: 6),
                  style: TextStyle(fontSize: 12, color: chipText),
                ),
                backgroundColor: chipBg,
                deleteIconColor: chipDelete,
                onPressed: _saving ? null : _requestLocation,
                onDeleted: _saving ? null : _clearLocation,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
              Tooltip(
                message: context.t.strings.legacy.msg_save,
                child: GestureDetector(
                  key: const ValueKey<String>('memo-editor-bottom-save-button'),
                  onTap: _saving ? null : _save,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: _saving ? 0.98 : 1.0,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: MemoFlowPalette.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: MemoFlowPalette.primary.withValues(
                              alpha: isDark ? 0.3 : 0.4,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final embeddedHeader =
        !_isEmbeddedPresentation || widget.onCloseRequested == null
        ? null
        : Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: background,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titleText,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: context.t.strings.legacy.msg_close,
                  onPressed: _saving
                      ? null
                      : () => unawaited(_requestCloseEditor()),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          );
    final desktopChromeInsets =
        _isDesktopFullscreenPresentation &&
            defaultTargetPlatform == TargetPlatform.macOS
        ? resolveDesktopWindowChromeInsets(
            platform: defaultTargetPlatform,
            contentExtendsIntoTitleBar: true,
          )
        : const DesktopWindowChromeInsets.none();
    final desktopHeaderTitle = Expanded(
      child: Text(
        titleText,
        key: const ValueKey<String>('memo-editor-desktop-title'),
        style: Theme.of(context).textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final desktopHeaderFullscreenButton = IconButton(
      key: const ValueKey<String>('memo-editor-fullscreen-toggle'),
      tooltip: _isDesktopFullscreenPresentation
          ? context.t.strings.legacy.msg_restore_window
          : context.t.strings.legacy.msg_maximize,
      onPressed: widget.onToggleFullscreen,
      icon: Icon(
        _isDesktopFullscreenPresentation
            ? Icons.fullscreen_exit_rounded
            : Icons.fullscreen_rounded,
      ),
    );
    final desktopHeaderCloseButton = IconButton(
      key: const ValueKey<String>('memo-editor-close-button'),
      tooltip: context.t.strings.legacy.msg_close,
      onPressed: _saving ? null : () => unawaited(_requestCloseEditor()),
      icon: const Icon(Icons.close_rounded),
    );
    final desktopHeaderChildren = defaultTargetPlatform == TargetPlatform.macOS
        ? <Widget>[
            desktopHeaderCloseButton,
            const SizedBox(width: 4),
            desktopHeaderTitle,
            desktopHeaderFullscreenButton,
          ]
        : <Widget>[
            desktopHeaderTitle,
            desktopHeaderFullscreenButton,
            desktopHeaderCloseButton,
          ];
    final desktopHeader = !_supportsDesktopSurfaceChrome
        ? null
        : Container(
            key: const ValueKey<String>('memo-editor-desktop-header'),
            height: 56 + desktopChromeInsets.top,
            padding: EdgeInsetsDirectional.only(
              start: 16 + desktopChromeInsets.leading,
              top: 8 + desktopChromeInsets.top,
              end: 8 + desktopChromeInsets.trailing,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(children: desktopHeaderChildren),
          );
    final composeSurface = MemoComposeSurface(
      backgroundColor: background,
      cardColor: cardColor,
      borderColor: borderColor,
      embedded: _isEmbeddedPresentation,
      embeddedHeader: embeddedHeader,
      header: desktopHeader,
      surfacePadding: _isDesktopFullscreenPresentation
          ? EdgeInsets.zero
          : _supportsDesktopSurfaceChrome
          ? EdgeInsets.fromLTRB(
              modalHorizontalInset,
              modalVerticalInset,
              modalHorizontalInset,
              modalVerticalInset,
            )
          : null,
      maxCardWidth: _isDesktopModalPresentation ? 1040 : null,
      contentMaxWidth: _supportsDesktopSurfaceChrome ? 920 : null,
      borderRadius: _isDesktopFullscreenPresentation
          ? 0
          : (_supportsDesktopSurfaceChrome ? 24 : 16),
      showShadow: _isDesktopModalPresentation,
      centerContentColumn: _supportsDesktopSurfaceChrome,
      child: composeContent,
    );
    final wrappedComposeSurface = _supportsDesktopSurfaceChrome
        ? CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_isDesktopFullscreenPresentation) {
                  widget.onToggleFullscreen?.call();
                  return;
                }
                unawaited(_requestCloseEditor());
              },
            },
            child: composeSurface,
          )
        : composeSurface;

    if (_isEmbeddedPresentation || _supportsDesktopSurfaceChrome) {
      return wrappedComposeSurface;
    }

    final page = PlatformPage(
      safeArea: false,
      backgroundColor: background,
      title: Text(titleText),
      actions: [pageFullscreenAction],
      body: wrappedComposeSurface,
    );
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_requestCloseEditor());
      },
      child: page,
    );
  }
}
