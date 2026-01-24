import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/settings/ai_settings_repository.dart';

class QuickPromptEditorScreen extends StatefulWidget {
  const QuickPromptEditorScreen({super.key});

  @override
  State<QuickPromptEditorScreen> createState() => _QuickPromptEditorScreenState();
}

class _QuickPromptEditorScreenState extends State<QuickPromptEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  var _selectedIconKey = QuickPromptIconCatalog.defaultKey;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_refresh);
    _contentController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _canSave {
    return _titleController.text.trim().isNotEmpty &&
        _contentController.text.trim().isNotEmpty;
  }

  void _save() {
    if (!_canSave) return;
    final prompt = AiQuickPrompt(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      iconKey: _selectedIconKey,
    );
    context.safePop(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border =
        isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.5);
    final inputBg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leadingWidth: 72,
        leading: TextButton(
          onPressed: () => context.safePop(),
          child: Text(
            context.tr(zh: '取消', en: 'Cancel'),
            style: TextStyle(
              color: MemoFlowPalette.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          context.tr(zh: '添加提示词', en: 'Add prompt'),
          style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              context.tr(zh: '保存', en: 'Save'),
              style: TextStyle(
                color: _canSave ? MemoFlowPalette.primary : textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(zh: '提示词标题', en: 'Prompt title'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr(zh: '如：情绪分析', en: 'e.g. Mood check'),
                    hintStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: MemoFlowPalette.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(zh: '具体指令内容', en: 'Prompt content'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  minLines: 4,
                  maxLines: 6,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr(
                      zh: '请分析我本周笔记中体现的情绪波动曲线…',
                      en: 'Describe how you want the summary…',
                    ),
                    hintStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: MemoFlowPalette.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr(zh: '图标选择', en: 'Icon'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
            children: [
              for (final option in QuickPromptIconCatalog.options)
                _IconChoiceTile(
                  icon: option.icon,
                  selected: option.key == _selectedIconKey,
                  borderColor: border,
                  onTap: () {
                    setState(() => _selectedIconKey = option.key);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr(
                    zh: '提示词将保存在快速总结中',
                    en: 'Your prompt will be saved in Quick prompts',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickPromptIconCatalog {
  static const defaultKey = AiQuickPrompt.defaultIconKey;

  static const options = <QuickPromptIconOption>[
    QuickPromptIconOption(key: 'trend', icon: Icons.trending_up),
    QuickPromptIconOption(key: 'idea', icon: Icons.lightbulb_outline),
    QuickPromptIconOption(key: 'note', icon: Icons.edit_note),
    QuickPromptIconOption(key: 'book', icon: Icons.menu_book),
    QuickPromptIconOption(key: 'sparkle', icon: Icons.auto_awesome),
    QuickPromptIconOption(key: 'settings', icon: Icons.settings_suggest),
    QuickPromptIconOption(key: 'doc', icon: Icons.description_outlined),
    QuickPromptIconOption(key: 'star', icon: Icons.stars_outlined),
  ];

  static IconData resolve(String key) {
    for (final option in options) {
      if (option.key == key) return option.icon;
    }
    final fallback = options.firstWhere(
      (option) => option.key == defaultKey,
      orElse: () => options.first,
    );
    return fallback.icon;
  }
}

class QuickPromptIconOption {
  const QuickPromptIconOption({
    required this.key,
    required this.icon,
  });

  final String key;
  final IconData icon;
}

class _IconChoiceTile extends StatelessWidget {
  const _IconChoiceTile({
    required this.icon,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MemoFlowPalette.primary;
    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.2 : 0.12)
        : (isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight);
    final stroke = selected ? accent : borderColor;
    final iconColor = selected ? accent : (isDark ? Colors.white : Colors.black87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: stroke),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 22)),
        ),
      ),
    );
  }
}
