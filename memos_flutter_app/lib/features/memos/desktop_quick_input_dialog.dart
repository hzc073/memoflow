import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memo_template_renderer.dart';
import '../../data/models/memo_template_settings.dart';
import '../../state/location_settings_provider.dart';
import '../../state/memo_template_settings_provider.dart';

class DesktopQuickInputDialog extends ConsumerStatefulWidget {
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
  ConsumerState<DesktopQuickInputDialog> createState() =>
      _DesktopQuickInputDialogState();
}

class _DesktopQuickInputDialogState
    extends ConsumerState<DesktopQuickInputDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final _templateMenuKey = GlobalKey();
  final _templateRenderer = MemoTemplateRenderer();

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

  void _replaceText(String value) {
    _controller.value = _controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
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

  Future<void> _openTemplateMenuFromKey(
    GlobalKey key,
    List<MemoTemplate> templates,
  ) async {
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

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

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final selectedId = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
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

  @override
  Widget build(BuildContext context) {
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
    final availableTemplates = templateSettings.enabled
        ? templateSettings.templates
        : const <MemoTemplate>[];
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
                      tooltip: '缃《锛堥鐣欙級',
                      onPressed: null,
                      icon: Icon(Icons.push_pin_outlined, color: textMuted),
                    ),
                    IconButton(
                      tooltip: '鍏抽棴',
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
                      hintText: '鐜板湪鐨勬兂娉曟槸...',
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
                      tooltip: '鏍囩',
                      onTap: () => _insertText('#'),
                      icon: Icons.tag_outlined,
                    ),
                    _ToolbarButton(
                      buttonKey: _templateMenuKey,
                      tooltip: '模板',
                      onTap: () => _openTemplateMenuFromKey(
                        _templateMenuKey,
                        availableTemplates,
                      ),
                      icon: Icons.description_outlined,
                    ),
                    _ToolbarButton(
                      tooltip: '鍥剧墖',
                      onTap: widget.onImagePressed,
                      icon: Icons.image_outlined,
                    ),
                    _ToolbarButton(
                      tooltip: '鍔犵矖',
                      onTap: _toggleBold,
                      icon: Icons.text_fields,
                    ),
                    _ToolbarButton(
                      tooltip: '鏃犲簭鍒楄〃',
                      onTap: () => _insertText('- '),
                      icon: Icons.format_list_bulleted,
                    ),
                    _ToolbarButton(
                      tooltip: '鏈夊簭鍒楄〃',
                      onTap: () => _insertText('1. '),
                      icon: Icons.format_list_numbered,
                    ),
                    _ToolbarButton(
                      tooltip: '鍏宠仈',
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
    this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final Key? buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFACACAC) : const Color(0xFF9C9C9C);
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 22),
      splashRadius: 18,
    );
  }
}
