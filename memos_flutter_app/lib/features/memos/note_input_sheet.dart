import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../data/models/memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/note_draft_provider.dart';
import 'link_memo_sheet.dart';
import '../voice/voice_record_screen.dart';

class NoteInputSheet extends ConsumerStatefulWidget {
  const NoteInputSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
      builder: (context) => const NoteInputSheet(),
    );
  }

  @override
  ConsumerState<NoteInputSheet> createState() => _NoteInputSheetState();
}

class _NoteInputSheetState extends ConsumerState<NoteInputSheet> {
  final _controller = TextEditingController();
  var _busy = false;
  Timer? _draftTimer;
  ProviderSubscription<AsyncValue<String>>? _draftSubscription;
  var _didApplyDraft = false;
  final _linkedMemos = <_LinkedMemo>[];
  final _pendingAttachments = <_PendingAttachment>[];
  final _tagMenuKey = GlobalKey();
  final _todoMenuKey = GlobalKey();
  final _moreMenuKey = GlobalKey();
  final _undoStack = <TextEditingValue>[];
  final _redoStack = <TextEditingValue>[];
  final _imagePicker = ImagePicker();
  TextEditingValue _lastValue = const TextEditingValue();
  var _isApplyingHistory = false;
  static const _maxHistory = 100;
  static const _maxAttachmentBytes = 30 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _lastValue = _controller.value;
    _controller.addListener(_scheduleDraftSave);
    _controller.addListener(_trackHistory);
    _applyDraft(ref.read(noteDraftProvider));
    _draftSubscription = ref.listenManual<AsyncValue<String>>(noteDraftProvider, (prev, next) {
      _applyDraft(next);
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _draftSubscription?.close();
    _controller.removeListener(_scheduleDraftSave);
    _controller.removeListener(_trackHistory);
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

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    final text = _controller.text;
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(noteDraftProvider.notifier).setDraft(text);
    });
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

  Future<void> _openMoreMenu() async {
    if (_busy) return;
    final target = _moreMenuKey.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    const iconCount = 6;
    const iconButtonSize = 32.0;
    const gap = 6.0;
    const horizontalPadding = 10.0;
    const verticalPadding = 6.0;
    final menuWidth = iconCount * iconButtonSize + (iconCount - 1) * gap + horizontalPadding * 2;
    final menuHeight = iconButtonSize + verticalPadding * 2;

    final overlaySize = overlay.size;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay);
    var left = anchor.dx + box.size.width / 2 - menuWidth / 2;
    left = left.clamp(8.0, overlaySize.width - menuWidth - 8.0);
    var top = anchor.dy - menuHeight - 12;
    if (top < 8.0) {
      top = anchor.dy + box.size.height + 12;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final iconColor = isDark ? Colors.white70 : Colors.black54;
        final disabledColor = iconColor.withValues(alpha: 0.35);
        Widget actionButton({
          required IconData icon,
          required VoidCallback onPressed,
          bool enabled = true,
        }) {
          return IconButton(
            icon: Icon(icon, size: 20, color: enabled ? iconColor : disabledColor),
            onPressed: enabled ? onPressed : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: iconButtonSize, height: iconButtonSize),
            splashRadius: 18,
          );
        }

        void closeMenuAnd(VoidCallback action) {
          Navigator.of(dialogContext).pop();
          action();
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        actionButton(
                          icon: Icons.format_bold,
                          onPressed: () => closeMenuAnd(_toggleBold),
                        ),
                        const SizedBox(width: gap),
                        actionButton(
                          icon: Icons.format_list_bulleted,
                          onPressed: () => closeMenuAnd(() => _insertText('- ')),
                        ),
                        const SizedBox(width: gap),
                        actionButton(
                          icon: Icons.format_underlined,
                          onPressed: () => closeMenuAnd(_toggleUnderline),
                        ),
                        const SizedBox(width: gap),
                        actionButton(
                          icon: Icons.photo_camera_outlined,
                          onPressed: () => closeMenuAnd(_capturePhoto),
                        ),
                        const SizedBox(width: gap),
                        actionButton(
                          icon: Icons.undo,
                          enabled: _undoStack.isNotEmpty,
                          onPressed: () => closeMenuAnd(_undo),
                        ),
                        const SizedBox(width: gap),
                        actionButton(
                          icon: Icons.redo,
                          enabled: _redoStack.isNotEmpty,
                          onPressed: () => closeMenuAnd(_redo),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (!mounted || result == null) return;

      final added = <_PendingAttachment>[];
      var tooLargeCount = 0;
      for (final file in result.files) {
        final path = file.path;
        if (path == null || path.trim().isEmpty) continue;
        final handle = File(path);
        if (!handle.existsSync()) continue;
        final size = file.size > 0 ? file.size : handle.lengthSync();
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
      }

      if (added.isEmpty) {
        final msg = tooLargeCount > 0 ? 'File too large (max 30 MB).' : 'No files selected.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      setState(() => _pendingAttachments.addAll(added));
      final suffix = added.length == 1 ? '' : 's';
      final summary = tooLargeCount > 0
          ? 'Added ${added.length} attachment$suffix. Skipped $tooLargeCount over 30 MB.'
          : 'Added ${added.length} attachment$suffix.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attachment failed: $e')));
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
      });
      messenger.showSnackBar(const SnackBar(content: Text('Added photo attachment.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Camera failed: $e')));
    }
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
      Navigator.of(context).pop();
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VoiceRecordScreen()));
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final uid = generateUid();
      final tags = extractTags(content);
      final db = ref.read(databaseProvider);

      final attachments = pendingAttachments
          .map(
            (p) => Attachment(
              name: 'attachments/${p.uid}',
              filename: p.filename,
              type: p.mimeType,
              size: p.size,
              externalLink: '',
            ).toJson(),
          )
          .toList(growable: false);

      await db.upsertMemo(
        uid: uid,
        content: content,
        visibility: 'PRIVATE',
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
        'visibility': 'PRIVATE',
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
        });
      }

      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      _draftTimer?.cancel();
      _controller.clear();
      _clearLinkedMemos();
      _pendingAttachments.clear();
      await ref.read(noteDraftProvider.notifier).clear();

      if (!mounted) return;
      Navigator.of(context).pop();
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

    final tagsAsync = ref.watch(tagStatsProvider);
    final tagStats = tagsAsync.valueOrNull ?? const <TagStat>[];

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
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(fontSize: 17, height: 1.35, color: textColor),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Write your memo...',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF666666) : Colors.grey.shade500),
                          ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                      child: Row(
                        children: [
                          IconButton(
                            key: _tagMenuKey,
                            tooltip: 'Tag',
                            onPressed: _busy
                                ? null
                                : () async {
                                    _insertText('#');
                                    await _openTagMenuFromKey(_tagMenuKey, tagStats);
                                  },
                            icon: Icon(Icons.tag, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          IconButton(
                            tooltip: 'Attachment',
                            onPressed: _busy ? null : _pickAttachments,
                            icon: Icon(Icons.attach_file, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          IconButton(
                            key: _todoMenuKey,
                            tooltip: 'Todo',
                            onPressed: _busy ? null : () => _openTodoShortcutMenuFromKey(_todoMenuKey),
                            icon: Icon(Icons.playlist_add_check, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          IconButton(
                            tooltip: 'Link',
                            onPressed: _busy ? null : _openLinkMemoSheet,
                            icon: Icon(Icons.alternate_email_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          Container(width: 1, height: 20, color: dividerColor),
                          IconButton(
                            key: _moreMenuKey,
                            tooltip: 'More',
                            onPressed: _busy ? null : _openMoreMenu,
                            icon: Icon(Icons.more_horiz, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          const Spacer(),
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



