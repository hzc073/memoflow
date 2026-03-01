import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/sync/sync_coordinator.dart';
import '../../application/sync/sync_request.dart';
import '../../core/app_localization.dart';
import '../../core/markdown_editing.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/location/location_geocoder.dart';
import '../../data/location/device_location_service.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_relation.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/location_settings.dart';
import '../../state/database_provider.dart';
import '../../state/location_settings_provider.dart';
import '../../state/logging_provider.dart';
import '../../state/memo_editor_draft_provider.dart';
import '../../state/memo_template_settings_provider.dart';
import '../../state/memo_timeline_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/network_log_provider.dart';
import '../../state/session_provider.dart';
import 'attachment_gallery_screen.dart';
import 'link_memo_sheet.dart';
import 'memo_video_grid.dart';
import 'windows_camera_capture_screen.dart';
import '../settings/location_settings_screen.dart';
import '../../i18n/strings.g.dart';

class MemoEditorScreen extends ConsumerStatefulWidget {
  const MemoEditorScreen({super.key, this.existing});

  final LocalMemo? existing;

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

enum _TodoShortcutAction { checkbox, codeBlock }

class _PendingAttachment {
  const _PendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}

class _LinkedMemo {
  const _LinkedMemo({required this.name, required this.label});

  final String name;
  final String label;

  Map<String, dynamic> toRelationJson() {
    return {
      'relatedMemo': {'name': name},
      'type': 'REFERENCE',
    };
  }
}

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  late final TextEditingController _contentController;
  late final SmartEnterController _smartEnterController;
  final _tagMenuKey = GlobalKey();
  final _templateMenuKey = GlobalKey();
  final _todoMenuKey = GlobalKey();
  final _visibilityMenuKey = GlobalKey();
  final _linkedMemos = <_LinkedMemo>[];
  final _existingAttachments = <Attachment>[];
  late final Set<String> _initialAttachmentKeys;
  final _pendingAttachments = <_PendingAttachment>[];
  final _attachmentsToDelete = <Attachment>[];
  final _undoStack = <TextEditingValue>[];
  final _redoStack = <TextEditingValue>[];
  final _imagePicker = ImagePicker();
  final _templateRenderer = MemoTemplateRenderer();
  final _pickedImages = <XFile>[];
  List<TagStat> _tagStatsCache = const [];
  TextEditingValue _lastValue = const TextEditingValue();
  Timer? _draftTimer;
  var _isApplyingHistory = false;
  bool _isMoreToolbarOpen = false;
  bool _relationsLoaded = false;
  bool _relationsLoading = false;
  bool _relationsDirty = false;
  bool _skipDraftPersistOnDispose = false;
  Future<void>? _relationsLoadFuture;
  static const _maxHistory = 100;
  late String _visibility;
  late bool _pinned;
  var _saving = false;
  MemoLocation? _location;
  MemoLocation? _initialLocation;
  var _locating = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _contentController = TextEditingController(text: existing?.content ?? '');
    _smartEnterController = SmartEnterController(_contentController);
    _lastValue = _contentController.value;
    _contentController.addListener(_handleContentChanged);
    _contentController.addListener(_trackHistory);
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
    _contentController.removeListener(_trackHistory);
    _contentController.removeListener(_scheduleDraftSave);
    if (!_skipDraftPersistOnDispose) {
      unawaited(_persistEditorDraftNow());
    }
    _smartEnterController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleContentChanged() {
    if (!mounted) return;
    setState(() {});
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
      final restoredPendingAttachments = _decodeDraftPendingAttachments(
        payload['pending_attachments'],
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
        _pendingAttachments
          ..clear()
          ..addAll(restoredPendingAttachments);
        _attachmentsToDelete
          ..clear()
          ..addAll(deleted);
        _pickedImages.clear();
        _undoStack.clear();
        _redoStack.clear();
        _lastValue = _contentController.value;
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

      final api = ref.read(memosApiProvider);
      final memoName = 'memos/$uid';
      final items = <MemoRelation>[];
      String? pageToken;
      do {
        final (relations, nextToken) = await api.listMemoRelations(
          memoUid: uid,
          pageSize: 200,
          pageToken: pageToken,
        );
        items.addAll(relations);
        pageToken = nextToken.trim().isEmpty ? null : nextToken;
      } while (pageToken != null);

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
        _linkedMemos
          ..clear()
          ..addAll(linked);
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

  void _trackHistory() {
    if (_isApplyingHistory) return;
    final value = _contentController.value;
    if (value.text == _lastValue.text &&
        value.selection == _lastValue.selection) {
      return;
    }
    _undoStack.add(_lastValue);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _lastValue = value;
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _isApplyingHistory = true;
    final current = _contentController.value;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    _contentController.value = previous;
    _lastValue = previous;
    _isApplyingHistory = false;
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _isApplyingHistory = true;
    final current = _contentController.value;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    _contentController.value = next;
    _lastValue = next;
    _isApplyingHistory = false;
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

      final db = ref.read(databaseProvider);
      final timelineService = ref.read(memoTimelineServiceProvider);
      if (existing != null && hasPrimaryChanges) {
        await timelineService.captureMemoVersion(existing);
      }
      if (existing != null && _attachmentsToDelete.isNotEmpty) {
        for (final attachment in _attachmentsToDelete) {
          final index = existing.attachments.indexWhere(
            (candidate) =>
                candidate.name == attachment.name ||
                candidate.uid == attachment.uid,
          );
          await timelineService.moveAttachmentToRecycleBin(
            memo: existing,
            attachment: attachment,
            index: index < 0 ? 0 : index,
          );
        }
      }
      await db.upsertMemo(
        uid: uid,
        content: content,
        visibility: _visibility,
        pinned: _pinned,
        state: state,
        createTimeSec: createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: tags,
        attachments: attachments,
        location: location,
        relationCount: existing?.relationCount ?? 0,
        syncState: 1,
        lastError: null,
      );

      if (existing == null) {
        await db.enqueueOutbox(
          type: 'create_memo',
          payload: {
            'uid': uid,
            'content': content,
            'visibility': _visibility,
            'pinned': _pinned,
            'has_attachments': attachments.isNotEmpty,
            if (location != null) 'location': location.toJson(),
            if (includeRelations) 'relations': relations,
          },
        );
      } else {
        await db.enqueueOutbox(
          type: 'update_memo',
          payload: {
            'uid': uid,
            'content': content,
            'visibility': _visibility,
            'pinned': _pinned,
            if (locationChanged) 'location': location?.toJson(),
            if (includeRelations) 'relations': relations,
            if (shouldSyncAttachments) 'sync_attachments': true,
            if (hasPendingAttachments) 'has_pending_attachments': true,
          },
        );
      }

      for (final attachment in pendingAttachments) {
        await db.enqueueOutbox(
          type: 'upload_attachment',
          payload: {
            'uid': attachment.uid,
            'memo_uid': uid,
            'file_path': attachment.filePath,
            'filename': attachment.filename,
            'mime_type': attachment.mimeType,
          },
        );
      }
      if (hasPendingAttachments) {
        for (final attachment in _attachmentsToDelete) {
          final name = attachment.name.isNotEmpty
              ? attachment.name
              : attachment.uid;
          if (name.isEmpty) continue;
          await db.enqueueOutbox(
            type: 'delete_attachment',
            payload: {'attachment_name': name, 'memo_uid': uid},
          );
        }
      }

      unawaited(
        ref.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            ),
      );

      _pendingAttachments.clear();
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
    final value = _contentController.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final newText = value.text.replaceRange(start, end, text);
    final caret = start + (caretOffset ?? text.length);
    _contentController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
  }

  void _replaceText(String text) {
    _contentController.value = _contentController.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  void _toggleBold() {
    final value = _contentController.value;
    final sel = value.selection;
    if (!sel.isValid || sel.isCollapsed) {
      _insertText('****', caretOffset: 2);
      return;
    }
    final selected = value.text.substring(sel.start, sel.end);
    final wrapped = '**$selected**';
    _contentController.value = value.copyWith(
      text: value.text.replaceRange(sel.start, sel.end, wrapped),
      selection: TextSelection(
        baseOffset: sel.start,
        extentOffset: sel.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _toggleUnderline() {
    final value = _contentController.value;
    final sel = value.selection;
    const prefix = '<u>';
    const suffix = '</u>';
    if (!sel.isValid || sel.isCollapsed) {
      _insertText('$prefix$suffix', caretOffset: prefix.length);
      return;
    }
    final selected = value.text.substring(sel.start, sel.end);
    final wrapped = '$prefix$selected$suffix';
    _contentController.value = value.copyWith(
      text: value.text.replaceRange(sel.start, sel.end, wrapped),
      selection: TextSelection(
        baseOffset: sel.start,
        extentOffset: sel.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  Future<void> _openTagMenuFromKey(GlobalKey key, List<TagStat> tags) async {
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
    await _openTagMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      tags,
    );
  }

  Future<void> _openTagMenu(RelativeRect position, List<TagStat> tags) async {
    if (_saving) return;
    final items = tags.isEmpty
        ? [
            const PopupMenuItem<String>(
              enabled: false,
              child: Text('No tags yet'),
            ),
          ]
        : tags
              .map(
                (stat) => PopupMenuItem<String>(
                  value: stat.tag,
                  child: Text('#${stat.tag}'),
                ),
              )
              .toList(growable: false);

    final selection = await showMenu<String>(
      context: context,
      position: position,
      items: items,
    );
    if (!mounted || selection == null) return;
    final normalized = selection.startsWith('#')
        ? selection.substring(1)
        : selection;
    if (normalized.isEmpty) return;
    _insertText('$normalized ');
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
        ? const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(enabled: false, child: Text('暂无模板')),
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
    _replaceText(rendered);
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
      items: const [
        PopupMenuItem(
          value: _TodoShortcutAction.checkbox,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_box_outlined, size: 18),
              SizedBox(width: 8),
              Text('Checkbox'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TodoShortcutAction.codeBlock,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code, size: 18),
              SizedBox(width: 8),
              Text('Code block'),
            ],
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _TodoShortcutAction.checkbox:
        _insertText('- [ ] ');
        break;
      case _TodoShortcutAction.codeBlock:
        _insertText('```\n\n```', caretOffset: 4);
        break;
    }
  }

  void _toggleMoreToolbar() {
    if (_saving) return;
    setState(() => _isMoreToolbarOpen = !_isMoreToolbarOpen);
  }

  void _closeMoreToolbar() {
    if (!_isMoreToolbarOpen) return;
    setState(() => _isMoreToolbarOpen = false);
  }

  Future<void> _openLocationSettings() async {
    if (_saving) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LocationSettingsScreen()),
    );
  }

  Future<LocationSettings> _resolveLocationSettings() async {
    final current = ref.read(locationSettingsProvider);
    if (current.enabled) return current;
    final stored = await ref.read(locationSettingsRepositoryProvider).read();
    if (!mounted) return stored;
    await ref
        .read(locationSettingsProvider.notifier)
        .setAll(stored, triggerSync: false);
    return stored;
  }

  bool _isWindowsLocationSettingsActionable(Object error) {
    if (!Platform.isWindows || error is! LocationException) return false;
    return error.code == 'permission_denied' ||
        error.code == 'permission_denied_forever' ||
        error.code == 'service_disabled';
  }

  void _showLocationError(Object error) {
    final messenger = ScaffoldMessenger.of(context);
    final message = _locationErrorText(error);
    if (!_isWindowsLocationSettingsActionable(error)) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('$message. Enable location access in Windows settings.'),
        action: SnackBarAction(
          label: context.t.strings.legacy.msg_settings,
          onPressed: () {
            unawaited(DeviceLocationService().openSystemLocationSettings());
          },
        ),
      ),
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
    if (_saving || _locating) return;
    if (Platform.isWindows) {
      setState(() => _locating = true);
      try {
        final position = await DeviceLocationService().getCurrentPosition();
        final settings = await _resolveLocationSettings();
        String placeholder = '';
        if (settings.enabled) {
          final geocoder = LocationGeocoder(
            logStore: ref.read(networkLogStoreProvider),
            logBuffer: ref.read(networkLogBufferProvider),
            logManager: ref.read(logManagerProvider),
          );
          placeholder =
              await geocoder.reverseGeocode(
                latitude: position.latitude,
                longitude: position.longitude,
                settings: settings,
              ) ??
              '';
        }
        final next = MemoLocation(
          placeholder: placeholder,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (!mounted) return;
        setState(() => _location = next);
        _scheduleDraftSave();
        showTopToast(
          context,
          context.t.strings.legacy.msg_location_updated(
            next_displayText_fractionDigits_6: next.displayText(
              fractionDigits: 6,
            ),
          ),
          duration: const Duration(seconds: 2),
        );
      } catch (e) {
        if (!mounted) return;
        _showLocationError(e);
      } finally {
        if (mounted) {
          setState(() => _locating = false);
        }
      }
      return;
    }

    final settings = await _resolveLocationSettings();
    if (!settings.enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t
                .strings
                .legacy
                .msg_location_disabled_enable_settings_first,
          ),
          action: SnackBarAction(
            label: context.t.strings.legacy.msg_settings,
            onPressed: _openLocationSettings,
          ),
        ),
      );
      return;
    }

    setState(() => _locating = true);
    try {
      final position = await DeviceLocationService().getCurrentPosition();
      String placeholder = '';
      final geocoder = LocationGeocoder(
        logStore: ref.read(networkLogStoreProvider),
        logBuffer: ref.read(networkLogBufferProvider),
        logManager: ref.read(logManagerProvider),
      );
      placeholder =
          await geocoder.reverseGeocode(
            latitude: position.latitude,
            longitude: position.longitude,
            settings: settings,
          ) ??
          '';
      final next = MemoLocation(
        placeholder: placeholder,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() => _location = next);
      _scheduleDraftSave();
      showTopToast(
        context,
        context.t.strings.legacy.msg_location_updated(
          next_displayText_fractionDigits_6: next.displayText(
            fractionDigits: 6,
          ),
        ),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      _showLocationError(e);
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  String _locationErrorText(Object error) {
    if (error is LocationException) {
      return switch (error.code) {
        'service_disabled' =>
          context.t.strings.legacy.msg_location_services_disabled,
        'permission_denied' =>
          context.t.strings.legacy.msg_location_permission_denied,
        'permission_denied_forever' =>
          context.t.strings.legacy.msg_location_permission_denied_permanently,
        'timeout' => context.t.strings.legacy.msg_location_timed_try,
        _ => context.t.strings.legacy.msg_failed_get_location,
      };
    }
    if (error is TimeoutException) {
      return context.t.strings.legacy.msg_location_timed_try;
    }
    return context.t.strings.legacy.msg_failed_get_location;
  }

  bool _sameLocation(MemoLocation? a, MemoLocation? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.placeholder.trim() != b.placeholder.trim()) return false;
    if ((a.latitude - b.latitude).abs() > 1e-6) return false;
    if ((a.longitude - b.longitude).abs() > 1e-6) return false;
    return true;
  }

  Widget _buildMoreToolbar(BuildContext context, bool isDark) {
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final disabledColor = iconColor.withValues(alpha: 0.45);
    const gap = 6.0;
    const horizontalPadding = 10.0;
    const verticalPadding = 6.0;
    const iconButtonSize = 32.0;
    final canEdit = !_saving;

    Widget actionButton({
      required IconData icon,
      required VoidCallback onPressed,
      bool enabled = true,
    }) {
      return IconButton(
        icon: Icon(icon, size: 20, color: enabled ? iconColor : disabledColor),
        onPressed: enabled
            ? () {
                _closeMoreToolbar();
                onPressed();
              }
            : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: iconButtonSize,
          height: iconButtonSize,
        ),
        splashRadius: 18,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2B2B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            actionButton(
              icon: Icons.format_bold,
              enabled: canEdit,
              onPressed: _toggleBold,
            ),
            const SizedBox(width: gap),
            actionButton(
              icon: Icons.format_list_bulleted,
              enabled: canEdit,
              onPressed: () => _insertText('- '),
            ),
            const SizedBox(width: gap),
            actionButton(
              icon: Icons.format_underlined,
              enabled: canEdit,
              onPressed: _toggleUnderline,
            ),
            const SizedBox(width: gap),
            actionButton(
              icon: Icons.photo_camera_outlined,
              enabled: canEdit,
              onPressed: _capturePhoto,
            ),
            const SizedBox(width: gap),
            actionButton(
              icon: _locating ? Icons.my_location : Icons.place_outlined,
              enabled: canEdit && !_locating,
              onPressed: _requestLocation,
            ),
            const SizedBox(width: gap),
            actionButton(
              icon: Icons.undo,
              enabled: canEdit && _undoStack.isNotEmpty,
              onPressed: _undo,
            ),
            const SizedBox(width: gap),
            actionButton(
              icon: Icons.redo,
              enabled: canEdit && _redoStack.isNotEmpty,
              onPressed: _redo,
            ),
          ],
        ),
      ),
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
            ? 'Files unavailable from picker.'
            : 'No files selected.';
        showTopToast(context, msg);
        return;
      }

      setState(() {
        _pendingAttachments.addAll(added);
      });
      _scheduleDraftSave();
      final suffix = added.length == 1 ? '' : 's';
      final skipped = [
        if (missingPathCount > 0) '$missingPathCount unavailable',
      ];
      final summary = skipped.isEmpty
          ? 'Added ${added.length} file$suffix.'
          : 'Added ${added.length} file$suffix. Skipped ${skipped.join(', ')}.';
      showTopToast(context, summary);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File selection failed: $e')));
    }
  }

  Future<void> _capturePhoto() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final photo = Platform.isWindows
          ? await WindowsCameraCaptureScreen.capture(context)
          : await _imagePicker.pickImage(source: ImageSource.camera);
      if (!mounted || photo == null) return;

      final path = photo.path;
      if (path.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Camera file missing.')),
        );
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Camera file missing.')),
        );
        return;
      }

      final size = await file.length();
      if (!mounted) return;

      final filename = path.split(Platform.pathSeparator).last;
      final mimeType = _guessMimeType(filename);
      if (!mounted) return;
      setState(() {
        _pendingAttachments.add(
          _PendingAttachment(
            uid: generateUid(),
            filePath: path,
            filename: filename,
            mimeType: mimeType,
            size: size,
          ),
        );
        _pickedImages.add(photo);
      });
      _scheduleDraftSave();
      showTopToast(context, 'Added photo attachment.');
    } catch (e) {
      if (!mounted) return;
      if (_isWindowsNoCameraError(e)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No camera detected.')),
        );
        return;
      }
      if (_isWindowsCameraPermissionError(e)) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Camera permission denied. Enable camera access in Windows settings.',
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
      messenger.showSnackBar(SnackBar(content: Text('Camera failed: $e')));
    }
  }

  void _removePendingAttachment(String uid) {
    final index = _pendingAttachments.indexWhere((a) => a.uid == uid);
    if (index < 0) return;
    final removed = _pendingAttachments[index];
    setState(() {
      _pendingAttachments.removeAt(index);
      _pickedImages.removeWhere((x) => x.path == removed.filePath);
    });
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
      setState(() {
        _pendingAttachments[index] = _PendingAttachment(
          uid: uid,
          filePath: result.filePath,
          filename: result.filename,
          mimeType: result.mimeType,
          size: result.size,
        );
      });
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
    setState(() {
      _existingAttachments.removeAt(index);
      _queueDeletedAttachment(removed);
      _pendingAttachments.add(
        _PendingAttachment(
          uid: newUid,
          filePath: result.filePath,
          filename: result.filename,
          mimeType: result.mimeType,
          size: result.size,
        ),
      );
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

    Widget content;
    if (isImage && file != null) {
      content = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
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
      _linkedMemos.add(_LinkedMemo(name: name, label: label));
      _relationsDirty = true;
    });
  }

  void _removeLinkedMemo(String name) {
    final before = _linkedMemos.length;
    setState(() {
      _linkedMemos.removeWhere((m) => m.name == name);
      if (_linkedMemos.length != before) {
        _relationsDirty = true;
      }
    });
  }

  void _clearLinkedMemos() {
    if (_linkedMemos.isEmpty) return;
    setState(() => _linkedMemos.clear());
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
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : MemoFlowPalette.audioSurfaceLight;
    final chipText = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final chipDelete = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.grey.shade500;
    final moreBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final moreBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final (visibilityLabel, visibilityIcon, visibilityColor) =
        _resolveVisibilityStyle(context, _visibility);
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
    final tagStats = _tagStatsCache;
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
                              Expanded(
                                child: TextField(
                                  controller: _contentController,
                                  enabled: !_saving,
                                  keyboardType: TextInputType.multiline,
                                  maxLines: null,
                                  expands: true,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.35,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context
                                        .t
                                        .strings
                                        .legacy
                                        .msg_write_something_supports_tag_tasks_x,
                                    hintStyle: TextStyle(color: hintColor),
                                    border: InputBorder.none,
                                  ),
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
                              onDeleted: _saving ? null : _clearLocation,
                            ),
                          ),
                        ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _isMoreToolbarOpen
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  6,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildMoreToolbar(context, isDark),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    IconButton(
                                      key: _tagMenuKey,
                                      tooltip: 'Tag',
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              _closeMoreToolbar();
                                              _insertText('#');
                                              await _openTagMenuFromKey(
                                                _tagMenuKey,
                                                tagStats,
                                              );
                                            },
                                      icon: Icon(
                                        Icons.tag,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    IconButton(
                                      key: _templateMenuKey,
                                      tooltip: '模板',
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              _closeMoreToolbar();
                                              await _openTemplateMenuFromKey(
                                                _templateMenuKey,
                                                availableTemplates,
                                              );
                                            },
                                      icon: Icon(
                                        Icons.description_outlined,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Attachment',
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              _closeMoreToolbar();
                                              await _pickAttachments();
                                            },
                                      icon: Icon(
                                        Icons.attach_file,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    IconButton(
                                      key: _todoMenuKey,
                                      tooltip: 'Todo',
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              _closeMoreToolbar();
                                              await _openTodoShortcutMenuFromKey(
                                                _todoMenuKey,
                                              );
                                            },
                                      icon: Icon(
                                        Icons.playlist_add_check,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Link',
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              _closeMoreToolbar();
                                              await _openLinkMemoSheet();
                                            },
                                      icon: Icon(
                                        Icons.alternate_email_rounded,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 20,
                                      color: dividerColor,
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isMoreToolbarOpen
                                            ? moreBg
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: _isMoreToolbarOpen
                                            ? Border.all(
                                                color: moreBorder,
                                                width: 1,
                                              )
                                            : null,
                                      ),
                                      child: IconButton(
                                        tooltip: 'More',
                                        onPressed: _saving
                                            ? null
                                            : _toggleMoreToolbar,
                                        icon: Icon(
                                          Icons.more_horiz,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Tooltip(
                                      message: context.t.strings.legacy
                                          .msg_visibility_2(
                                            visibilityLabel: visibilityLabel,
                                          ),
                                      child: InkResponse(
                                        key: _visibilityMenuKey,
                                        onTap: _saving
                                            ? null
                                            : () {
                                                _closeMoreToolbar();
                                                _openVisibilityMenuFromKey();
                                              },
                                        radius: 18,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: visibilityColor.withValues(
                                                alpha: 0.85,
                                              ),
                                              width: 1.6,
                                            ),
                                          ),
                                          child: Icon(
                                            visibilityIcon,
                                            size: 14,
                                            color: visibilityColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
