import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/markdown_editing.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';

class MemoEditorScreen extends ConsumerStatefulWidget {
  const MemoEditorScreen({super.key, this.existing});

  final LocalMemo? existing;

  @override
  ConsumerState<MemoEditorScreen> createState() => _MemoEditorScreenState();
}

class _MemoEditorScreenState extends ConsumerState<MemoEditorScreen> {
  late final TextEditingController _contentController;
  late final SmartEnterController _smartEnterController;
  final _visibilityMenuKey = GlobalKey();
  late String _visibility;
  late bool _pinned;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _contentController = TextEditingController(text: existing?.content ?? '');
    _smartEnterController = SmartEnterController(_contentController);
    _contentController.addListener(_handleContentChanged);
    _visibility = existing?.visibility ?? 'PRIVATE';
    _pinned = existing?.pinned ?? false;
  }

  @override
  void dispose() {
    _contentController.removeListener(_handleContentChanged);
    _smartEnterController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleContentChanged() {
    if (!mounted) return;
    setState(() {});
  }

  int _countNonWhitespaceChars(String s) {
    final stripped = s.replaceAll(RegExp(r'\s+'), '');
    return stripped.runes.length;
  }

  Future<void> _save() async {
    if (_saving) return;
    final content = _contentController.text.trimRight();
    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '内容不能为空', en: 'Content cannot be empty'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final now = DateTime.now();
      final uid = existing?.uid ?? generateUid();
      final createTime = existing?.createTime ?? now;
      final state = existing?.state ?? 'NORMAL';
      final attachments = existing?.attachments.map((a) => a.toJson()).toList(growable: false) ?? const <Map<String, dynamic>>[];
      final tags = extractTags(content);

      final db = ref.read(databaseProvider);
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
        syncState: 1,
        lastError: null,
      );

      if (existing == null) {
        await db.enqueueOutbox(type: 'create_memo', payload: {
          'uid': uid,
          'content': content,
          'visibility': _visibility,
          'pinned': _pinned,
          'has_attachments': attachments.isNotEmpty,
        });
      } else {
        await db.enqueueOutbox(type: 'update_memo', payload: {
          'uid': uid,
          'content': content,
          'visibility': _visibility,
          'pinned': _pinned,
        });
      }

      unawaited(ref.read(syncControllerProvider.notifier).syncNow());

      if (!mounted) return;
      context.safePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '保存失败：$e', en: 'Save failed: $e'))),
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
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + wrapped.length),
      composing: TextRange.empty,
    );
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
    await _openVisibilityMenu(RelativeRect.fromRect(rect, Offset.zero & overlay.size));
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
    setState(() => _visibility = selection);
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

  Widget _toolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    String? tooltip,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: _saving ? null : onPressed,
      icon: Icon(icon, size: 20),
      color: color,
      disabledColor: color.withValues(alpha: 0.4),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final content = _contentController.text;
    final count = _countNonWhitespaceChars(content);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final cardColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final textColor = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final hintColor = isDark ? const Color(0xFF666666) : Colors.grey.shade500;
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final metaColor = isDark ? Colors.white54 : Colors.black45;
    final (visibilityLabel, visibilityIcon, visibilityColor) = _resolveVisibilityStyle(context, _visibility);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(existing == null ? context.tr(zh: '新建 Memo', en: 'New Memo') : context.tr(zh: '编辑 Memo', en: 'Edit Memo')),
        actions: [
          IconButton(
            tooltip: context.tr(zh: '保存', en: 'Save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MemoFlowPalette.primary))
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
                          child: TextField(
                            controller: _contentController,
                            enabled: !_saving,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            style: TextStyle(fontSize: 16, height: 1.35, color: textColor),
                            decoration: InputDecoration(
                              hintText: context.tr(
                                zh: '写点什么…支持 #tag 和待办[ ] / [x]',
                                en: 'Write something... Supports #tag and tasks [ ] / [x]',
                              ),
                              hintStyle: TextStyle(color: hintColor),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: borderColor),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                        child: Row(
                          children: [
                            _toolbarButton(
                              icon: Icons.tag,
                              color: iconColor,
                              tooltip: context.tr(zh: '标签', en: 'Tag'),
                              onPressed: () => _insertText('#'),
                            ),
                            _toolbarButton(
                              icon: Icons.image_outlined,
                              color: iconColor,
                              tooltip: context.tr(zh: '图片', en: 'Image'),
                              onPressed: () => _insertText('![]()', caretOffset: 4),
                            ),
                            _toolbarButton(
                              icon: Icons.check_box_outlined,
                              color: iconColor,
                              tooltip: context.tr(zh: '待办', en: 'Task'),
                              onPressed: () => _insertText('- [ ] '),
                            ),
                            _toolbarButton(
                              icon: Icons.alternate_email_rounded,
                              color: iconColor,
                              tooltip: context.tr(zh: '提及', en: 'Mention'),
                              onPressed: () => _insertText('@'),
                            ),
                            _toolbarButton(
                              icon: Icons.format_bold,
                              color: iconColor,
                              tooltip: context.tr(zh: '加粗', en: 'Bold'),
                              onPressed: _toggleBold,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            Text(
                              context.tr(zh: '字数：$count', en: 'Count: $count'),
                              style: TextStyle(fontSize: 12, color: metaColor),
                            ),
                            const Spacer(),
                            InkWell(
                              key: _visibilityMenuKey,
                              onTap: _saving ? null : _openVisibilityMenuFromKey,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: visibilityColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: visibilityColor.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(visibilityIcon, size: 14, color: visibilityColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      visibilityLabel,
                                      style: TextStyle(fontSize: 12, color: visibilityColor, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: visibilityColor),
                                  ],
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
