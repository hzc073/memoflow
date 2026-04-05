// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../core/scene_micro_guide_widgets.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../state/settings/location_settings_provider.dart';
import '../../state/attachments/queued_attachment_stager_provider.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memo_editor_draft_provider.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/memos/memo_editor_providers.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/system/session_provider.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import 'attachment_gallery_screen.dart';
import 'compose_toolbar_shared.dart';
import 'gallery_attachment_picker.dart';
import 'link_memo_sheet.dart';
import 'memo_video_grid.dart';
import 'tag_autocomplete.dart';
import '../location_picker/show_location_picker.dart';
import '../../i18n/strings.g.dart';

typedef _PendingAttachment = MemoComposerPendingAttachment;
typedef _LinkedMemo = MemoComposerLinkedMemo;

class MemoEditorScreen extends ConsumerStatefulWidget {
  const MemoEditorScreen({super.key, this.existing});

  final LocalMemo? existing;

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

enum _TodoShortcutAction { checkbox, codeBlock }

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  late final MemoComposerController _composer;
  late final TextEditingController _contentController;
  late final FocusNode _editorFocusNode;
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
  final _imagePicker = ImagePicker();
  final _templateRenderer = MemoTemplateRenderer();
  final _pickedImages = <XFile>[];
  List<TagStat> _tagStatsCache = const [];
  Timer? _draftTimer;
  bool _relationsLoaded = false;
  bool _relationsLoading = false;
  bool _relationsDirty = false;
  bool _skipDraftPersistOnDispose = false;
  Future<void>? _relationsLoadFuture;
  late String _visibility;
  late bool _pinned;
  var _saving = false;
  MemoLocation? _location;
  MemoLocation? _initialLocation;
  final _locating = false;
  int get _tagAutocompleteIndex => _composer.tagAutocompleteIndex;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _composer = MemoComposerController(initialText: existing?.content ?? '');
    _contentController = _composer.textController;
    _editorFocusNode = FocusNode();
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
    if (existing != null) {
      _loadExistingRelations();
      unawaited(_restoreEditorDraftIfNeeded());
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _contentController.removeListener(_handleContentChanged);
    _contentController.removeListener(_scheduleDraftSave);
    if (!_skipDraftPersistOnDispose) {
      unawaited(_persistEditorDraftNow());
    }
    _editorFocusNode.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _handleContentChanged() {
    if (!mounted) return;
    _syncTagAutocompleteState();
    setState(() {});
  }

  void _syncTagAutocompleteState() {
    final activeQuery = detectActiveTagQuery(_contentController.value);
    if (activeQuery != null) {
      _markSceneGuideSeen(SceneMicroGuideId.memoEditorTagAutocomplete);
    }
    _composer.syncTagAutocompleteState(
      tagStats: _currentTagStats(),
      hasFocus: _editorFocusNode.hasFocus,
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

  String? get _draftMemoUid {
    final uid = widget.existing?.uid.trim() ?? '';
    if (uid.isEmpty) return null;
    return uid;
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistEditorDraftNow());
    });
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
              ? _guessMimeType(path.split(Platform.pathSeparator).last)
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
    if (existing == null || memoUid == null) return;

    try {
      final repo = ref.read(memoEditorDraftRepositoryProvider);
      final raw = await repo.read(memoUid: memoUid);
      if (!mounted) return;

      final payload = _decodeEditorDraftPayload(raw);
      if (payload == null) return;
      // If user has started editing in this session, don't overwrite edits.
      if (!_isEditorBaseState(existing)) return;

      final restoredContent = (payload['content'] as String?) ?? '';
      final restoredVisibility =
          (payload['visibility'] as String?)?.trim().isNotEmpty == true
          ? (payload['visibility'] as String).trim()
          : existing.visibility;
      MemoLocation? restoredLocation = existing.location;
      if (payload.containsKey('location')) {
        final restoredLocationRaw = payload['location'];
        if (restoredLocationRaw is Map) {
          try {
            restoredLocation = MemoLocation.fromJson(
              restoredLocationRaw.cast<String, dynamic>(),
            );
          } catch (_) {
            restoredLocation = existing.location;
          }
        } else {
          restoredLocation = null;
        }
      } else {
        restoredLocation = existing.location;
      }
      final restoredExistingAttachments = _decodeDraftExistingAttachments(
        payload['existing_attachments'],
        fallback: existing.attachments,
      );
      final restoredPendingAttachments = await _stagePendingAttachments(
        _decodeDraftPendingAttachments(payload['pending_attachments']),
      );

      final hasDiff =
          restoredContent != existing.content ||
          restoredVisibility != existing.visibility ||
          !_sameLocation(restoredLocation, existing.location) ||
          !_sameStringSet(
            _attachmentKeySet(restoredExistingAttachments),
            _attachmentKeySet(existing.attachments),
          ) ||
          restoredPendingAttachments.isNotEmpty;

      if (!hasDiff) {
        await repo.clear(memoUid: memoUid);
        return;
      }

      final shouldRestore =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(dialogContext.t.strings.legacy.msg_restore_backup),
              actions: [
                TextButton(
                  onPressed: () => dialogContext.safePop(false),
                  child: Text(dialogContext.t.strings.legacy.msg_cancel_2),
                ),
                FilledButton(
                  onPressed: () => dialogContext.safePop(true),
                  child: Text(dialogContext.t.strings.legacy.msg_restore),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted || !shouldRestore) {
        return;
      }

      final restoredExistingKeys = _attachmentKeySet(
        restoredExistingAttachments,
      );
      final deleted = existing.attachments
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
    if (existing == null || memoUid == null) return;

    final repo = ref.read(memoEditorDraftRepositoryProvider);
    if (!_hasUnsavedEditorState(existing)) {
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
    await ref.read(memoEditorDraftRepositoryProvider).clear(memoUid: memoUid);
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
      final tags = extractTags(content);
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

      if (!mounted) return;
      context.safePop();
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
    _composer.startTagAutocomplete(requestFocus: _editorFocusNode.requestFocus);
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
    if (_saving || _locating) return;
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

  bool _sameLocation(MemoLocation? a, MemoLocation? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.placeholder.trim() != b.placeholder.trim()) return false;
    if ((a.latitude - b.latitude).abs() > 1e-6) return false;
    if ((a.longitude - b.longitude).abs() > 1e-6) return false;
    return true;
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
    if (_saving) return;
    try {
      final compressionSettings = await ref
          .read(imageCompressionSettingsRepositoryProvider)
          .read();
      if (!mounted) return;
      final result = await pickGalleryAttachments(
        context,
        showOriginalToggle: compressionSettings.enabled,
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final attachment = await captureCameraAttachment(
        navigator: Navigator.of(context),
        imagePicker: _imagePicker,
      );
      if (!mounted || attachment == null) return;
      final stagedAttachments = await _stagePendingAttachments([
        _PendingAttachment(
          uid: generateUid(),
          filePath: attachment.filePath,
          filename: attachment.filename,
          mimeType: attachment.mimeType,
          size: attachment.size,
          skipCompression: attachment.skipCompression,
        ),
      ]);
      if (!mounted || stagedAttachments.isEmpty) return;
      setState(() {
        _composer.addPendingAttachments(stagedAttachments);
        _pickedImages.add(XFile(stagedAttachments.first.filePath));
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

  List<AttachmentImageSource> _editorImageSources(
    Uri? baseUrl,
    String? authHeader,
  ) {
    final sources = <AttachmentImageSource>[];
    for (final attachment in _existingAttachments) {
      if (!_isImageMimeType(attachment.type)) continue;
      final localFile = _localExistingAttachmentFile(attachment);
      final fullUrl = _existingAttachmentUrl(
        attachment,
        thumbnail: false,
        baseUrl: baseUrl,
      );
      sources.add(
        AttachmentImageSource(
          id: _existingSourceId(attachment),
          title: attachment.filename,
          mimeType: attachment.type,
          localFile: localFile,
          imageUrl: fullUrl.isNotEmpty ? fullUrl : null,
          headers: authHeader == null ? null : {'Authorization': authHeader},
        ),
      );
    }

    for (final attachment in _pendingAttachments) {
      if (!_isImageMimeType(attachment.mimeType)) continue;
      final file = _resolvePendingAttachmentFile(attachment);
      if (file == null) continue;
      sources.add(
        AttachmentImageSource(
          id: _pendingSourceId(attachment.uid),
          title: attachment.filename,
          mimeType: attachment.mimeType,
          localFile: file,
        ),
      );
    }
    return sources;
  }

  Future<void> _openAttachmentViewer(
    String sourceId, {
    required Uri? baseUrl,
    required String? authHeader,
  }) async {
    final sources = _editorImageSources(baseUrl, authHeader);
    final index = sources.indexWhere((source) => source.id == sourceId);
    if (index < 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentGalleryScreen(
          images: sources,
          initialIndex: index,
          onReplace: _replaceEditedAttachment,
          enableDownload: true,
        ),
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
      content = Image.file(
        localFile,
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
    } else if (isImage && thumbUrl.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: thumbUrl,
        httpHeaders: authHeader == null ? null : {'Authorization': authHeader},
        fit: BoxFit.cover,
        placeholder: (context, _) => _attachmentFallback(
          iconColor: iconColor,
          surfaceColor: surfaceColor,
          isImage: true,
        ),
        errorWidget: (context, url, error) => _attachmentFallback(
          iconColor: iconColor,
          surfaceColor: surfaceColor,
          isImage: true,
        ),
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

  @override
  Widget build(BuildContext context) {
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
      appPreferencesProvider.select((p) => p.memoToolbarPreferences),
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
    final activeTagQuery = detectActiveTagQuery(_contentController.value);
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
    final tagAutocompleteGuideMessage =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS
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

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          existing == null
              ? context.t.strings.legacy.msg_memo_2
              : context.t.strings.legacy.msg_edit_memo,
        ),
        actions: [
          IconButton(
            tooltip: context.t.strings.legacy.msg_save,
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MemoFlowPalette.primary,
                    ),
                  )
                : Icon(Icons.check_rounded, color: MemoFlowPalette.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
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
                                          onKeyEvent:
                                              _handleTagAutocompleteKeyEvent,
                                          child: TextField(
                                            controller: _contentController,
                                            focusNode: _editorFocusNode,
                                            enabled: !_saving,
                                            inputFormatters: const [
                                              SmartEnterTextInputFormatter(),
                                            ],
                                            keyboardType:
                                                TextInputType.multiline,
                                            maxLines: null,
                                            expands: true,
                                            style: editorTextStyle,
                                            decoration: InputDecoration(
                                              hintText: context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_write_something_supports_tag_tasks_x,
                                              hintStyle: TextStyle(
                                                color: hintColor,
                                              ),
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
                                            value: _contentController.value,
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: chipText,
                                      ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                              avatar: Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: chipText,
                              ),
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
                            GestureDetector(
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
                                        color: MemoFlowPalette.primary
                                            .withValues(
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
