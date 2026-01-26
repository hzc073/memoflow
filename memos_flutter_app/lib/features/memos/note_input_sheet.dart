import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_localization.dart';
import '../../core/markdown_editing.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../data/models/memo.dart';
import '../../data/models/user_setting.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/note_draft_provider.dart';
import '../../state/user_settings_provider.dart';
import 'attachment_gallery_screen.dart';
import 'link_memo_sheet.dart';
import '../voice/voice_record_screen.dart';

class NoteInputSheet extends ConsumerStatefulWidget {
  const NoteInputSheet({
    super.key,
    this.initialText,
    this.initialSelection,
    this.initialAttachmentPaths = const [],
    this.ignoreDraft = false,
  });

  final String? initialText;
  final TextSelection? initialSelection;
  final List<String> initialAttachmentPaths;
  final bool ignoreDraft;

  static Future<void> show(
    BuildContext context, {
    String? initialText,
    TextSelection? initialSelection,
    List<String> initialAttachmentPaths = const [],
    bool ignoreDraft = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
      builder: (context) => NoteInputSheet(
        initialText: initialText,
        initialSelection: initialSelection,
        initialAttachmentPaths: initialAttachmentPaths,
        ignoreDraft: ignoreDraft,
      ),
    );
  }

  @override
  ConsumerState<NoteInputSheet> createState() => _NoteInputSheetState();
}

class _NoteInputSheetState extends ConsumerState<NoteInputSheet> {
  late final TextEditingController _controller;
  late final SmartEnterController _smartEnterController;
  var _busy = false;
  Timer? _draftTimer;
  ProviderSubscription<AsyncValue<String>>? _draftSubscription;
  var _didApplyDraft = false;
  var _didSeedInitialAttachments = false;
  List<TagStat> _tagStatsCache = const [];
  final _linkedMemos = <_LinkedMemo>[];
  final _pendingAttachments = <_PendingAttachment>[];
  final _tagMenuKey = GlobalKey();
  final _todoMenuKey = GlobalKey();
  final _visibilityMenuKey = GlobalKey();
  final _undoStack = <TextEditingValue>[];
  final _redoStack = <TextEditingValue>[];
  final _imagePicker = ImagePicker();
  final _pickedImages = <XFile>[];
  TextEditingValue _lastValue = const TextEditingValue();
  var _isApplyingHistory = false;
  static const _maxHistory = 100;
  static const _maxAttachmentBytes = 30 * 1024 * 1024;
  String _visibility = 'PRIVATE';
  bool _visibilityTouched = false;
  bool _isMoreToolbarOpen = false;
  ProviderSubscription<AsyncValue<UserGeneralSetting>>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    final selection = widget.initialSelection;
    if (selection != null) {
      _controller.selection = _normalizeSelection(selection, _controller.text.length);
    }
    if (widget.ignoreDraft ||
        _controller.text.trim().isNotEmpty ||
        widget.initialAttachmentPaths.isNotEmpty) {
      _didApplyDraft = true;
    }
    _lastValue = _controller.value;
    _smartEnterController = SmartEnterController(_controller);
    _controller.addListener(_scheduleDraftSave);
    _controller.addListener(_trackHistory);
    _applyDraft(ref.read(noteDraftProvider));
    _applyDefaultVisibility(ref.read(userGeneralSettingProvider));
    _loadTagStats();
    unawaited(_seedInitialAttachments());
    _draftSubscription = ref.listenManual<AsyncValue<String>>(noteDraftProvider, (prev, next) {
      _applyDraft(next);
    });
    _settingsSubscription = ref.listenManual<AsyncValue<UserGeneralSetting>>(userGeneralSettingProvider, (prev, next) {
      _applyDefaultVisibility(next);
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _draftSubscription?.close();
    _settingsSubscription?.close();
    _controller.removeListener(_scheduleDraftSave);
    _controller.removeListener(_trackHistory);
    _smartEnterController.dispose();
    unawaited(ref.read(noteDraftProvider.notifier).setDraft(_controller.text));
    _controller.dispose();
    super.dispose();
  }

  void _applyDraft(AsyncValue<String> value) {
    if (_didApplyDraft) return;
    final draft = value.valueOrNull;
    if (draft == null) return;
    if (_controller.text.trim().isEmpty && draft.trim().isNotEmpty) {
      _controller.text = draft;
      _controller.selection = TextSelection.collapsed(offset: draft.length);
    }
    _didApplyDraft = true;
  }

  TextSelection _normalizeSelection(TextSelection selection, int length) {
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: length);
    }
    int clampOffset(int offset) => offset.clamp(0, length).toInt();
    return selection.copyWith(
      baseOffset: clampOffset(selection.baseOffset),
      extentOffset: clampOffset(selection.extentOffset),
    );
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

  Future<void> _seedInitialAttachments() async {
    if (_didSeedInitialAttachments) return;
    _didSeedInitialAttachments = true;
    final paths = widget.initialAttachmentPaths;
    if (paths.isEmpty) return;

    final added = <_PendingAttachment>[];
    for (final raw in paths) {
      final path = raw.trim();
      if (path.isEmpty) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      final size = file.lengthSync();
      if (size > _maxAttachmentBytes) continue;
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
    setState(() {
      _pendingAttachments.addAll(added);
    });
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    final text = _controller.text;
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(noteDraftProvider.notifier).setDraft(text);
    });
  }

  Future<void> _loadTagStats() async {
    try {
      final tags = await ref.read(tagStatsProvider.future);
      if (!mounted) return;
      setState(() => _tagStatsCache = tags);
    } catch (_) {}
  }

  void _trackHistory() {
    if (_isApplyingHistory) return;
    final value = _controller.value;
    if (value.text == _lastValue.text && value.selection == _lastValue.selection) {
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
    final current = _controller.value;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    _controller.value = previous;
    _lastValue = previous;
    _isApplyingHistory = false;
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _isApplyingHistory = true;
    final current = _controller.value;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    _controller.value = next;
    _lastValue = next;
    _isApplyingHistory = false;
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
    await _openVisibilityMenu(RelativeRect.fromRect(rect, Offset.zero & overlay.size));
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
              Text(context.tr(zh: '私密', en: 'Private')),
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
              Text(context.tr(zh: '受保护', en: 'Protected')),
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
              Text(context.tr(zh: '公开', en: 'Public')),
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
  }

  String _normalizedVisibility() {
    final value = _visibility.trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  (String label, IconData icon, Color color) _resolveVisibilityStyle(BuildContext context, String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PUBLIC':
        return (
          context.tr(zh: '公开', en: 'Public'),
          Icons.public,
          const Color(0xFF3B8C52),
        );
      case 'PROTECTED':
        return (
          context.tr(zh: '受保护', en: 'Protected'),
          Icons.verified_user,
          const Color(0xFFB26A2B),
        );
      default:
        return (
          context.tr(zh: '私密', en: 'Private'),
          Icons.lock,
          const Color(0xFF7C7C7C),
        );
    }
  }

  Future<void> _closeWithDraft() async {
    if (_busy) return;
    _draftTimer?.cancel();
    await ref.read(noteDraftProvider.notifier).setDraft(_controller.text);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _insertText(String text, {int? caretOffset}) {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final newText = value.text.replaceRange(start, end, text);
    final caret = start + (caretOffset ?? text.length);
    _controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
  }

  void _toggleBold() {
    final value = _controller.value;
    final sel = value.selection;
    if (!sel.isValid) {
      _insertText('****');
      _controller.selection = const TextSelection.collapsed(offset: 2);
      return;
    }
    if (sel.isCollapsed) {
      _insertText('****');
      _controller.selection = TextSelection.collapsed(offset: sel.start + 2);
      return;
    }
    final selected = value.text.substring(sel.start, sel.end);
    final wrapped = '**$selected**';
    _controller.value = value.copyWith(
      text: value.text.replaceRange(sel.start, sel.end, wrapped),
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + wrapped.length),
      composing: TextRange.empty,
    );
  }

  void _toggleUnderline() {
    final value = _controller.value;
    final sel = value.selection;
    const prefix = '<u>';
    const suffix = '</u>';
    if (!sel.isValid || sel.isCollapsed) {
      _insertText('$prefix$suffix', caretOffset: prefix.length);
      return;
    }
    final selected = value.text.substring(sel.start, sel.end);
    final wrapped = '$prefix$selected$suffix';
    _controller.value = value.copyWith(
      text: value.text.replaceRange(sel.start, sel.end, wrapped),
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + wrapped.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _openTagMenuFromKey(GlobalKey key, List<TagStat> tags) async {
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
    await _openTagMenu(RelativeRect.fromRect(rect, Offset.zero & overlay.size), tags);
  }

  Future<void> _openTagMenu(RelativeRect position, List<TagStat> tags) async {
    if (_busy) return;
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
    final normalized = selection.startsWith('#') ? selection.substring(1) : selection;
    if (normalized.isEmpty) return;
    _insertText('$normalized ');
  }

  Future<void> _openTodoShortcutMenu(RelativeRect position) async {
    if (_busy) return;
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
    await _openTodoShortcutMenu(RelativeRect.fromRect(rect, Offset.zero & overlay.size));
  }

  void _toggleMoreToolbar() {
    if (_busy) return;
    setState(() => _isMoreToolbarOpen = !_isMoreToolbarOpen);
  }

  void _closeMoreToolbar() {
    if (!_isMoreToolbarOpen) return;
    setState(() => _isMoreToolbarOpen = false);
  }

  Widget _buildMoreToolbar(BuildContext context, bool isDark) {
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final disabledColor = iconColor.withValues(alpha: 0.45);
    const gap = 6.0;
    const horizontalPadding = 10.0;
    const verticalPadding = 6.0;
    const iconButtonSize = 32.0;
    final canEdit = !_busy;

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
        constraints: const BoxConstraints.tightFor(width: iconButtonSize, height: iconButtonSize),
        splashRadius: 18,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
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

  Future<void> _pickAttachments() async {
    if (_busy) return;
    try {
      final files = await _imagePicker.pickMultiImage();
      if (!mounted) return;
      if (files.isEmpty) return;

      final added = <_PendingAttachment>[];
      final accepted = <XFile>[];
      var tooLargeCount = 0;
      for (final file in files) {
        final path = file.path;
        if (path.trim().isEmpty) continue;
        final handle = File(path);
        if (!handle.existsSync()) continue;
        final size = handle.lengthSync();
        if (size > _maxAttachmentBytes) {
          tooLargeCount++;
          continue;
        }
        final filename = file.name.trim().isNotEmpty ? file.name.trim() : path.split(Platform.pathSeparator).last;
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
        accepted.add(file);
      }

      if (added.isEmpty) {
        final msg = tooLargeCount > 0 ? 'Image too large (max 30 MB).' : 'No images selected.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      setState(() {
        _pendingAttachments.addAll(added);
        _pickedImages.addAll(accepted);
      });
      final suffix = added.length == 1 ? '' : 's';
      final summary = tooLargeCount > 0
          ? 'Added ${added.length} image$suffix. Skipped $tooLargeCount over 30 MB.'
          : 'Added ${added.length} image$suffix.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image selection failed: $e')));
    }
  }

  Future<void> _capturePhoto() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (!mounted || photo == null) return;

      final path = photo.path;
      if (path.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Camera file missing.')));
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        messenger.showSnackBar(const SnackBar(content: Text('Camera file missing.')));
        return;
      }

      final size = await file.length();
      if (!mounted) return;
      if (size > _maxAttachmentBytes) {
        messenger.showSnackBar(const SnackBar(content: Text('Photo too large (max 30 MB).')));
        return;
      }

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
      messenger.showSnackBar(const SnackBar(content: Text('Added photo attachment.')));
    } catch (e) {
      if (!mounted) return;
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
  }

  bool _isImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
  }

  File? _resolvePendingAttachmentFile(_PendingAttachment attachment) {
    final path = attachment.filePath.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String _pendingSourceId(String uid) => 'pending:$uid';

  List<({AttachmentImageSource source, _PendingAttachment attachment, File file})> _pendingImageSources() {
    final items = <({AttachmentImageSource source, _PendingAttachment attachment, File file})>[];
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
    final index = items.indexWhere((item) => item.attachment.uid == attachment.uid);
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
    if (result.size > _maxAttachmentBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '图片过大（最大 30 MB）', en: 'Image too large (max 30 MB).'))),
      );
      return;
    }
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
  }

  Widget _buildAttachmentPreview(bool isDark) {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();
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
              for (var i = 0; i < _pendingAttachments.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _buildAttachmentTile(_pendingAttachments[i], isDark: isDark, size: tileSize),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(_PendingAttachment attachment, {required bool isDark, required double size}) {
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final surfaceColor = isDark ? MemoFlowPalette.audioSurfaceDark : MemoFlowPalette.audioSurfaceLight;
    final iconColor = (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight).withValues(alpha: 0.6);
    final removeBg = isDark ? Colors.black.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.5);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.12);
    final isImage = _isImageMimeType(attachment.mimeType);
    final file = _resolvePendingAttachmentFile(attachment);

    Widget content;
    if (isImage && file != null) {
      content = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _attachmentFallback(iconColor: iconColor, surfaceColor: surfaceColor, isImage: true);
        },
      );
    } else {
      content = _attachmentFallback(iconColor: iconColor, surfaceColor: surfaceColor, isImage: isImage);
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: (isImage && file != null) ? () => _openAttachmentViewer(attachment) : null,
          child: tile,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _busy ? null : () => _removePendingAttachment(attachment.uid),
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
  }) {
    return Container(
      color: surfaceColor,
      alignment: Alignment.center,
      child: Icon(
        isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
        size: 22,
        color: iconColor,
      ),
    );
  }

  Set<String> get _linkedMemoNames => _linkedMemos.map((m) => m.name).toSet();

  void _addLinkedMemo(Memo memo) {
    final name = memo.name.trim();
    if (name.isEmpty) return;
    if (_linkedMemos.any((m) => m.name == name)) return;
    final label = _linkedMemoLabel(memo);
    setState(() => _linkedMemos.add(_LinkedMemo(name: name, label: label)));
  }

  void _removeLinkedMemo(String name) {
    setState(() => _linkedMemos.removeWhere((m) => m.name == name));
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
      return _truncateLabel(name.startsWith('memos/') ? name.substring('memos/'.length) : name);
    }
    return _truncateLabel(memo.uid);
  }

  String _truncateLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  Future<void> _submitOrVoice() async {
    if (_busy) return;
    final content = _controller.text.trimRight();
    final relations = _linkedMemos.map((m) => m.toRelationJson()).toList(growable: false);
    final pendingAttachments = List<_PendingAttachment>.from(_pendingAttachments);
    final hasAttachments = pendingAttachments.isNotEmpty;
    if (content.trim().isEmpty && !hasAttachments) {
      if (relations.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter content before creating a link.')),
        );
        return;
      }
      if (!mounted) return;
      context.safePop();
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VoiceRecordScreen()));
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final uid = generateUid();
      final tags = extractTags(content);
      final db = ref.read(databaseProvider);
      final visibility = _normalizedVisibility();

      final attachments = pendingAttachments
          .map(
            (p) {
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
            },
          )
          .toList(growable: false);

      await db.upsertMemo(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: tags,
        attachments: attachments,
        syncState: 1,
      );

      await db.enqueueOutbox(type: 'create_memo', payload: {
        'uid': uid,
        'content': content,
        'visibility': visibility,
        'pinned': false,
        'has_attachments': hasAttachments,
        if (relations.isNotEmpty) 'relations': relations,
      });

      for (final attachment in pendingAttachments) {
        await db.enqueueOutbox(type: 'upload_attachment', payload: {
          'uid': attachment.uid,
          'memo_uid': uid,
          'file_path': attachment.filePath,
          'filename': attachment.filename,
          'mime_type': attachment.mimeType,
          'file_size': attachment.size,
        });
      }

      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      _draftTimer?.cancel();
      _controller.clear();
      _clearLinkedMemos();
      _pendingAttachments.clear();
      _pickedImages.clear();
      await ref.read(noteDraftProvider.notifier).clear();

      if (!mounted) return;
      context.safePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textColor = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.06) : MemoFlowPalette.audioSurfaceLight;
    final chipText = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final chipDelete = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey.shade500;
    final moreBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final moreBorder = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final (visibilityLabel, visibilityIcon, visibilityColor) = _resolveVisibilityStyle(context, _visibility);

    final tagStats = _tagStatsCache;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: isDark ? 4 : 2, sigmaY: isDark ? 4 : 2),
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
                    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sheetColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        border: isDark ? Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                            blurRadius: 40,
                            offset: const Offset(0, -10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 160, maxHeight: 340),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAttachmentPreview(isDark),
                            Flexible(
                              fit: FlexFit.loose,
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                style: TextStyle(fontSize: 17, height: 1.35, color: textColor),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                hintText: context.tr(zh: '写下你的想法...', en: 'Write down your thoughts...'),
                                  hintStyle: TextStyle(color: isDark ? const Color(0xFF666666) : Colors.grey.shade500),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_linkedMemos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                                  onDeleted: _busy ? null : () => _removeLinkedMemo(memo.name),
                                ),
                              )
                              .toList(growable: false),
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
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: _isMoreToolbarOpen
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildMoreToolbar(context, isDark),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
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
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            _closeMoreToolbar();
                                            _insertText('#');
                                            await _openTagMenuFromKey(_tagMenuKey, tagStats);
                                          },
                                    icon: Icon(Icons.tag, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                  IconButton(
                                    tooltip: 'Attachment',
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            _closeMoreToolbar();
                                            await _pickAttachments();
                                          },
                                    icon: Icon(Icons.attach_file, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                  IconButton(
                                    key: _todoMenuKey,
                                    tooltip: 'Todo',
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            _closeMoreToolbar();
                                            await _openTodoShortcutMenuFromKey(_todoMenuKey);
                                          },
                                    icon: Icon(Icons.playlist_add_check, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                  IconButton(
                                    tooltip: 'Link',
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            _closeMoreToolbar();
                                            await _openLinkMemoSheet();
                                          },
                                    icon: Icon(Icons.alternate_email_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                  Container(width: 1, height: 20, color: dividerColor),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    decoration: BoxDecoration(
                                      color: _isMoreToolbarOpen ? moreBg : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: _isMoreToolbarOpen ? Border.all(color: moreBorder, width: 1) : null,
                                    ),
                                    child: IconButton(
                                      tooltip: 'More',
                                      onPressed: _busy ? null : _toggleMoreToolbar,
                                      icon: Icon(Icons.more_horiz, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ),
                                  Tooltip(
                                    message: context.tr(zh: '可见性：$visibilityLabel', en: 'Visibility: $visibilityLabel'),
                                    child: InkResponse(
                                      key: _visibilityMenuKey,
                                      onTap: _busy
                                          ? null
                                          : () {
                                              _closeMoreToolbar();
                                              _openVisibilityMenuFromKey(_visibilityMenuKey);
                                            },
                                      radius: 18,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: visibilityColor.withValues(alpha: 0.85), width: 1.6),
                                        ),
                                        child: Icon(visibilityIcon, size: 14, color: visibilityColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _busy ? null : _submitOrVoice,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 120),
                              scale: _busy ? 0.98 : 1.0,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: MemoFlowPalette.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.3 : 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _busy
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : ValueListenableBuilder<TextEditingValue>(
                                          valueListenable: _controller,
                                          builder: (context, value, _) {
                                            final hasText = value.text.trim().isNotEmpty;
                                            final hasAttachments = _pendingAttachments.isNotEmpty;
                                            final showSend = hasText || hasAttachments;
                                            return AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 160),
                                              transitionBuilder: (child, animation) {
                                                return ScaleTransition(scale: animation, child: child);
                                              },
                                              child: Icon(
                                                showSend ? Icons.send_rounded : Icons.graphic_eq,
                                                key: ValueKey<bool>(showSend),
                                                color: Colors.white,
                                                size: showSend ? 24 : 28,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ),
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
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
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
          ],
        ),
      ),
    );
  }
}

enum _TodoShortcutAction {
  checkbox,
  codeBlock,
}

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



