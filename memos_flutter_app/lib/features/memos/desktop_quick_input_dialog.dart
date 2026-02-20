import 'package:flutter/material.dart';

class DesktopQuickInputDialog extends StatefulWidget {
  const DesktopQuickInputDialog({
    super.key,
    this.initialText,
    this.onImagePressed,
    this.backgroundOverlayColor,
  });

  final String? initialText;
  final VoidCallback? onImagePressed;
  final Color? backgroundOverlayColor;

  static Future<String?> show(
    BuildContext context, {
    String? initialText,
    VoidCallback? onImagePressed,
    Color? backgroundOverlayColor,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: backgroundOverlayColor,
      builder: (_) => DesktopQuickInputDialog(
        initialText: initialText,
        onImagePressed: onImagePressed,
        backgroundOverlayColor: backgroundOverlayColor,
      ),
    );
  }

  @override
  State<DesktopQuickInputDialog> createState() =>
      _DesktopQuickInputDialogState();
}

class _DesktopQuickInputDialogState extends State<DesktopQuickInputDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  void _insertText(String value, {int? caretOffset}) {
    final current = _controller.value;
    final selection = current.selection;
    final start = selection.isValid ? selection.start : current.text.length;
    final end = selection.isValid ? selection.end : current.text.length;
    final nextText = current.text.replaceRange(start, end, value);
    final cursor = start + (caretOffset ?? value.length);
    _controller.value = current.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
  }

  void _toggleBold() {
    final value = _controller.value;
    final selection = value.selection;
    const prefix = '**';
    const suffix = '**';
    if (!selection.isValid || selection.isCollapsed) {
      _insertText('$prefix$suffix', caretOffset: prefix.length);
      return;
    }
    final selected = value.text.substring(selection.start, selection.end);
    final wrapped = '$prefix$selected$suffix';
    _controller.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, wrapped),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _submit() {
    final content = _controller.text.trimRight();
    if (content.trim().isEmpty) return;
    Navigator.of(context).pop(content);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171717) : const Color(0xFFF4F4F4);
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E6);
    final textMain = isDark ? const Color(0xFFF1F1F1) : const Color(0xFF222222);
    final textMuted = isDark
        ? const Color(0xFF8F8F8F)
        : const Color(0xFF9C9C9C);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minHeight: 440),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                child: Row(
                  children: [
                    Text(
                      'MemoFlow',
                      style: TextStyle(
                        fontSize: 34 / 1.8,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '置顶（预留）',
                      onPressed: null,
                      icon: Icon(Icons.push_pin_outlined, color: textMuted),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, color: textMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    style: TextStyle(
                      fontSize: 17,
                      color: textMain,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      hintText: '现在的想法是...',
                      hintStyle: TextStyle(color: textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    _ToolbarButton(
                      tooltip: '标签',
                      onTap: () => _insertText('#'),
                      icon: Icons.tag_outlined,
                    ),
                    _ToolbarButton(
                      tooltip: '图片',
                      onTap: widget.onImagePressed,
                      icon: Icons.image_outlined,
                    ),
                    _ToolbarButton(
                      tooltip: '加粗',
                      onTap: _toggleBold,
                      icon: Icons.text_fields,
                    ),
                    _ToolbarButton(
                      tooltip: '无序列表',
                      onTap: () => _insertText('- '),
                      icon: Icons.format_list_bulleted,
                    ),
                    _ToolbarButton(
                      tooltip: '有序列表',
                      onTap: () => _insertText('1. '),
                      icon: Icons.format_list_numbered,
                    ),
                    _ToolbarButton(
                      tooltip: '关联',
                      onTap: () => _insertText('@'),
                      icon: Icons.alternate_email_rounded,
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(52, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFACACAC) : const Color(0xFF9C9C9C);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 22),
      splashRadius: 18,
    );
  }
}
