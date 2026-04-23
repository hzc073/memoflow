import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/ai/ai_settings_models.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'ai_insight_models.dart';
import 'quick_prompt_editor_screen.dart';

class AiInsightPromptEditorScreen extends ConsumerStatefulWidget {
  const AiInsightPromptEditorScreen({super.key, required this.insightId})
    : customTemplateMode = false,
      templateId = null;

  const AiInsightPromptEditorScreen.custom({super.key, this.templateId})
    : insightId = AiInsightId.customTemplate,
      customTemplateMode = true;

  final AiInsightId insightId;
  final bool customTemplateMode;
  final String? templateId;

  @override
  ConsumerState<AiInsightPromptEditorScreen> createState() =>
      _AiInsightPromptEditorScreenState();
}

class _AiInsightPromptEditorScreenState
    extends ConsumerState<AiInsightPromptEditorScreen> {
  late final TextEditingController _promptController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  var _didLoadInitialValue = false;
  var _didSeedPromptTemplate = false;
  var _saving = false;
  var _selectedIconKey = QuickPromptIconCatalog.defaultKey;

  bool get _isCustomMode => widget.customTemplateMode;
  bool get _isCreatingCustomTemplate =>
      _isCustomMode && (widget.templateId?.trim().isEmpty ?? true);

  bool get _canSave {
    if (_isCustomMode) {
      return _titleController.text.trim().isNotEmpty &&
          _descriptionController.text.trim().isNotEmpty &&
          _promptController.text.trim().isNotEmpty;
    }
    return _promptController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController()..addListener(_refresh);
    _titleController = TextEditingController()..addListener(_refresh);
    _descriptionController = TextEditingController()..addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isCustomMode) {
      if (_didLoadInitialValue) return;
      final template = _customTemplateFromSettings();
      _titleController.text = template.title;
      _descriptionController.text = template.description;
      _promptController.text = template.promptTemplate;
      _selectedIconKey = template.iconKey.trim().isEmpty
          ? QuickPromptIconCatalog.defaultKey
          : template.iconKey;
      _didLoadInitialValue = true;
      return;
    }

    if (!_didSeedPromptTemplate) {
      _didSeedPromptTemplate = true;
      final defaultTemplate = defaultInsightPromptTemplate(
        context,
        widget.insightId,
      );
      Future.microtask(() async {
        await ref
            .read(aiSettingsProvider.notifier)
            .ensureInsightPromptTemplateInitialized(
              widget.insightId.storageKey,
              defaultTemplate,
            );
      });
    }
    if (_didLoadInitialValue) {
      return;
    }
    _promptController.text = _templateFromSettings();
    _didLoadInitialValue = true;
  }

  @override
  void dispose() {
    _promptController
      ..removeListener(_refresh)
      ..dispose();
    _titleController
      ..removeListener(_refresh)
      ..dispose();
    _descriptionController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _templateFromSettings() {
    final settings = ref.read(aiSettingsProvider);
    return resolveInsightPromptTemplate(
      context,
      insightId: widget.insightId,
      templates: settings.insightPromptTemplates,
    );
  }

  AiCustomInsightTemplate _customTemplateFromSettings() {
    final settings = ref.read(aiSettingsProvider);
    final templateId = widget.templateId?.trim() ?? '';
    if (templateId.isEmpty) {
      return const AiCustomInsightTemplate();
    }
    return settings.findCustomInsightTemplate(templateId) ??
        const AiCustomInsightTemplate();
  }

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    setState(() => _saving = true);
    if (_isCustomMode) {
      final template = AiCustomInsightTemplate(
        templateId: widget.templateId?.trim() ?? '',
        title: _titleController.text,
        description: _descriptionController.text,
        promptTemplate: _promptController.text,
        iconKey: _selectedIconKey,
      );
      if (_isCreatingCustomTemplate) {
        await ref
            .read(aiSettingsProvider.notifier)
            .addCustomInsightTemplate(template);
      } else {
        await ref
            .read(aiSettingsProvider.notifier)
            .updateCustomInsightTemplate(widget.templateId ?? '', template);
      }
    } else {
      await ref
          .read(aiSettingsProvider.notifier)
          .setInsightPromptTemplate(
            widget.insightId.storageKey,
            _promptController.text,
          );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _restoreDefaultPlaceholder() {
    final template = defaultInsightPromptTemplate(context, widget.insightId);
    setState(() {
      _promptController.text = template;
      _promptController.selection = TextSelection.collapsed(
        offset: _promptController.text.length,
      );
    });
  }

  String _pageTitle() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    if (_isCustomMode) {
      if (_isCreatingCustomTemplate) {
        return isZh
            ? '\u65b0\u5efa\u81ea\u5b9a\u4e49\u6a21\u677f'
            : 'New Custom Template';
      }
      return isZh
          ? '\u7f16\u8f91\u81ea\u5b9a\u4e49\u6a21\u677f'
          : 'Edit Custom Template';
    }
    return context.t.strings.aiInsight.promptSettings.editPromptTemplate;
  }

  String _customDescription() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    return isZh
        ? '\u8bbe\u7f6e\u6807\u9898\u3001\u8bf4\u660e\u3001\u56fe\u6807\u548c\u63d0\u793a\u8bcd\uff0c\u65b9\u4fbf\u4f60\u533a\u5206\u8fd9\u4e2a\u6a21\u677f\u7684\u7528\u9014\u3002'
        : 'Set the title, note, icon, and prompt so you can quickly recognize this template.';
  }

  String _titleLabel() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    return isZh ? '\u6807\u9898' : 'Title';
  }

  String _titleHint() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    return isZh
        ? '\u6bd4\u5982\uff1a\u6211\u6700\u8fd1\u7684\u80fd\u91cf\u6f0f\u53e3'
        : 'For example: My Recent Energy Drains';
  }

  String _descriptionLabel() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    return isZh ? '\u8bf4\u660e' : 'Description';
  }

  String _descriptionHint() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    return isZh
        ? '\u7528\u6765\u6982\u62ec\u8fd9\u4e2a\u6a21\u677f\u7684\u5206\u6790\u89d2\u5ea6\uff0c\u65b9\u4fbf\u4f60\u81ea\u5df1\u8bc6\u522b'
        : 'Summarize this template\'s analysis angle for your own reference';
  }

  String _promptLabel() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    return isZh ? '\u63d0\u793a\u8bcd' : 'Prompt';
  }

  String _iconLabel() {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    return isZh ? '\u56fe\u6807' : 'Icon';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.66 : 0.58);

    if (_isCustomMode) {
      final titleText = _titleController.text.trim().isEmpty
          ? definitionForInsight(AiInsightId.customTemplate).title(context)
          : _titleController.text.trim();
      final descriptionText = _descriptionController.text.trim().isEmpty
          ? _customDescription()
          : _descriptionController.text.trim();
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(_pageTitle()),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: MemoFlowPalette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        QuickPromptIconCatalog.resolve(_selectedIconKey),
                        color: MemoFlowPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            descriptionText,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _EditorFieldCard(
                label: _titleLabel(),
                hintText: _titleHint(),
                controller: _titleController,
                textMain: textMain,
                textMuted: textMuted,
                card: card,
                border: border,
              ),
              const SizedBox(height: 14),
              _EditorFieldCard(
                label: _descriptionLabel(),
                hintText: _descriptionHint(),
                controller: _descriptionController,
                minLines: 3,
                maxLines: 4,
                textMain: textMain,
                textMuted: textMuted,
                card: card,
                border: border,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _iconLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final option in QuickPromptIconCatalog.options)
                          SizedBox.square(
                            dimension: 60,
                            child: _InsightIconChoiceTile(
                              icon: option.icon,
                              selected: option.key == _selectedIconKey,
                              borderColor: border,
                              onTap: () {
                                setState(() => _selectedIconKey = option.key);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _EditorFieldCard(
                label: _promptLabel(),
                hintText: context
                    .t
                    .strings
                    .aiInsight
                    .promptSettings
                    .editorPlaceholder,
                controller: _promptController,
                minLines: 8,
                maxLines: 12,
                textMain: textMain,
                textMuted: textMuted,
                card: card,
                border: border,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving || !_canSave ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: MemoFlowPalette.primary,
                    disabledBackgroundColor: MemoFlowPalette.primary.withValues(
                      alpha: 0.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.t.strings.common.save,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final definition = definitionForInsight(widget.insightId);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(_pageTitle()),
        actions: [
          TextButton(
            onPressed: _restoreDefaultPlaceholder,
            child: Text(
              Localizations.localeOf(context).languageCode.toLowerCase() == 'zh'
                  ? '\u6062\u590d\u9ed8\u8ba4'
                  : 'Restore Default',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title(context),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t.strings.aiInsight.promptSettings
                          .editorDescription(
                            insight: definition.title(context),
                          ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _promptController,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: textMain,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: context
                          .t
                          .strings
                          .aiInsight
                          .promptSettings
                          .editorPlaceholder,
                      hintStyle: TextStyle(color: textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving || !_canSave ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: MemoFlowPalette.primary,
                    disabledBackgroundColor: MemoFlowPalette.primary.withValues(
                      alpha: 0.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.t.strings.common.save,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
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

class _EditorFieldCard extends StatelessWidget {
  const _EditorFieldCard({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.textMain,
    required this.textMuted,
    required this.card,
    required this.border,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final Color textMain;
  final Color textMuted;
  final Color card;
  final Color border;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            style: TextStyle(fontSize: 15, height: 1.5, color: textMain),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hintText,
              hintStyle: TextStyle(color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightIconChoiceTile extends StatelessWidget {
  const _InsightIconChoiceTile({
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
    final iconColor = selected
        ? accent
        : (isDark ? Colors.white : Colors.black87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: stroke),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 20)),
        ),
      ),
    );
  }
}
