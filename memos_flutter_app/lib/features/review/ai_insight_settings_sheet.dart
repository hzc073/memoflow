import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/ai/ai_provider_models.dart';
import '../../data/ai/ai_route_config.dart';
import '../../data/ai/ai_settings_models.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/ai_settings_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../settings/ai_settings_screen.dart';
import 'ai_insight_models.dart';
import 'ai_insight_prompt_editor_screen.dart';

typedef AiInsightCustomRangePicker =
    Future<DateTimeRange?> Function(
      BuildContext context,
      DateTimeRange? currentRange,
    );

class AiInsightSettingsSheet extends ConsumerStatefulWidget {
  const AiInsightSettingsSheet({
    super.key,
    required this.definition,
    this.customTitle,
    this.customTemplateMode = false,
    this.customRangePicker,
    this.analysisLoading = false,
  });

  final AiInsightDefinition definition;
  final String? customTitle;
  final bool customTemplateMode;
  final AiInsightCustomRangePicker? customRangePicker;
  final bool analysisLoading;

  @override
  ConsumerState<AiInsightSettingsSheet> createState() =>
      _AiInsightSettingsSheetState();
}

class _AiInsightSettingsSheetState
    extends ConsumerState<AiInsightSettingsSheet> {
  late AiInsightRange _range;
  AiInsightRange _lastNonCustomRange = AiInsightRange.last7Days;
  DateTimeRange? _customRange;
  var _allowPublic = true;
  late bool _allowPrivate;
  var _allowProtected = false;
  var _didSeedPromptTemplate = false;

  bool get _isCustomTemplateMode => widget.customTemplateMode;

  String get _displayTitle {
    final override = widget.customTitle?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return widget.definition.title(context);
  }

  @override
  void initState() {
    super.initState();
    _range = AiInsightRange.last7Days;
    _allowPrivate = ref.read(appPreferencesProvider).aiSummaryAllowPrivateMemos;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isCustomTemplateMode || _didSeedPromptTemplate) {
      return;
    }
    _didSeedPromptTemplate = true;
    final defaultTemplate = defaultInsightPromptTemplate(
      context,
      widget.definition.id,
    );
    Future.microtask(() async {
      await ref
          .read(aiSettingsProvider.notifier)
          .ensureInsightPromptTemplateInitialized(
            widget.definition.id.storageKey,
            defaultTemplate,
          );
    });
  }

  String get _promptTemplate {
    final settings = ref.read(aiSettingsProvider);
    if (_isCustomTemplateMode) {
      return settings.customInsightTemplate.promptTemplate.trim();
    }
    return resolveInsightPromptTemplate(
      context,
      insightId: widget.definition.id,
      templates: settings.insightPromptTemplates,
    );
  }

  DateTimeRange get _effectiveRange =>
      resolveAiInsightRange(_range, _customRange);

  String _rangeLabel() {
    return formatAiInsightRangeLabel(_effectiveRange);
  }

  bool _hasGenerationConfig(AiSettings settings) {
    return hasConfiguredChatRoute(
      settings,
      routeId: AiTaskRouteId.analysisReport,
    );
  }

  bool _hasEmbeddingConfig(AiSettings settings) {
    return hasConfiguredEmbeddingRoute(settings);
  }

  bool _hasRequiredAiConfig(AiSettings settings) {
    return _hasGenerationConfig(settings);
  }

  Future<DateTimeRange?> _pickCustomRange() {
    final picker = widget.customRangePicker;
    if (picker != null) {
      return picker(context, _customRange);
    }
    final now = DateTime.now();
    final initial =
        _customRange ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day),
        );
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
  }

  Future<void> _selectRange(AiInsightRange nextRange) async {
    if (nextRange == AiInsightRange.custom) {
      final picked = await _pickCustomRange();
      if (!mounted) return;
      if (picked == null) {
        if (_customRange == null) {
          setState(() => _range = _lastNonCustomRange);
        }
        return;
      }
      setState(() {
        _customRange = picked;
        _range = AiInsightRange.custom;
      });
      return;
    }
    setState(() {
      _range = nextRange;
      _lastNonCustomRange = nextRange;
    });
  }

  void _toggleAllowPublic(bool value) {
    setState(() => _allowPublic = value);
  }

  void _toggleAllowPrivate(bool value) {
    setState(() => _allowPrivate = value);
    ref
        .read(appPreferencesProvider.notifier)
        .setAiSummaryAllowPrivateMemos(value);
  }

  void _toggleAllowProtected(bool value) {
    setState(() => _allowProtected = value);
  }

  Future<void> _openPromptEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _isCustomTemplateMode
            ? const AiInsightPromptEditorScreen.custom()
            : AiInsightPromptEditorScreen(insightId: widget.definition.id),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAiSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _startAnalysis() {
    if (!_canStartAnalysis) return;
    Navigator.of(context).pop(
      AiInsightSettingsResult(
        insightId: widget.definition.id,
        range: _range,
        customRange: _customRange,
        allowPublic: _allowPublic,
        allowPrivate: _allowPrivate,
        allowProtected: _allowProtected,
        previewPayload: AiAnalysisPreviewPayload.empty,
        promptTemplate: _promptTemplate,
      ),
    );
  }

  bool get _canStartAnalysis {
    final settings = ref.read(aiSettingsProvider);
    return !widget.analysisLoading &&
        _hasRequiredAiConfig(settings) &&
        (_allowPublic || _allowPrivate || _allowProtected) &&
        _promptTemplate.trim().isNotEmpty;
  }

  String _aiConfigTitle({
    required bool isZh,
    required bool hasGeneration,
    required bool hasEmbedding,
  }) {
    if (!hasGeneration && !hasEmbedding) {
      return isZh
          ? 'AI \u8fd8\u6ca1\u6709\u914d\u7f6e'
          : 'AI is not configured yet';
    }
    if (!hasGeneration) {
      return isZh
          ? '\u8fd8\u7f3a\u804a\u5929\u6a21\u578b\u914d\u7f6e'
          : 'Chat model setup is missing';
    }
    return isZh
        ? '\u672a\u914d\u7f6e\u5411\u91cf\u6a21\u578b'
        : 'Embedding model is optional but recommended';
  }

  String _aiConfigDescription({
    required bool isZh,
    required bool hasGeneration,
    required bool hasEmbedding,
  }) {
    if (!hasGeneration && !hasEmbedding) {
      return isZh
          ? '\u8bf7\u5148\u914d\u7f6e chat \u6a21\u578b\u3002\u914d\u7f6e\u597d chat \u540e\u5373\u53ef\u5f00\u59cb AI \u603b\u7ed3\uff0c\u4e4b\u540e\u518d\u8865\u5145\u5411\u91cf\u6a21\u578b\u53ef\u4ee5\u63d0\u5347\u5206\u6790\u51c6\u786e\u5ea6\u3002'
          : 'Configure a chat model first. You can start AI summaries once chat is ready, and add an embedding model later for better analysis accuracy.';
    }
    if (!hasGeneration) {
      return isZh
          ? '\u5f53\u524d\u8fd8\u7f3a chat \u6a21\u578b\uff0c\u6682\u65f6\u8fd8\u4e0d\u80fd\u5f00\u59cb AI \u603b\u7ed3\u3002'
          : 'A chat model is still missing, so AI summaries cannot start yet.';
    }
    return isZh
        ? '\u5f53\u524d\u5df2\u914d\u7f6e chat \u6a21\u578b\uff0c\u53ef\u4ee5\u5f00\u59cb AI \u603b\u7ed3\uff1b\u4f46\u672a\u914d\u7f6e\u5411\u91cf\u6a21\u578b\uff0cAI \u5206\u6790\u51c6\u786e\u5ea6\u4f1a\u964d\u4f4e\u3002'
        : 'Chat is configured, so AI summaries can start now. Without an embedding model, analysis accuracy may be lower.';
  }

  String _promptSectionTitle(bool isZh) {
    if (_isCustomTemplateMode) {
      return isZh
          ? '\u7f16\u8f91\u81ea\u5b9a\u4e49\u6a21\u677f'
          : 'Edit Custom Template';
    }
    return context.t.strings.aiInsight.promptSettings.editPromptTemplate;
  }

  String _promptSectionDescription(bool isZh) {
    if (_isCustomTemplateMode) {
      return isZh
          ? '\u4fee\u6539\u6807\u9898\u3001\u63d0\u793a\u8bcd\u3001\u56fe\u6807\u548c\u8bf4\u660e\u3002'
          : 'Update the title, prompt, icon, and note.';
    }
    return context.t.strings.aiInsight.promptSettings.description;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.66 : 0.58);
    final accentSoft = widget.definition.accent.withValues(alpha: 0.12);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.8;
    final minHeight = mediaQuery.size.height * 0.5;
    final hasGeneration = _hasGenerationConfig(settings);
    final hasEmbedding = _hasEmbeddingConfig(settings);
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight,
            maxHeight: maxHeight,
            maxWidth: 560,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: border.withValues(alpha: isDark ? 0.72 : 0.9),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t.strings.aiInsight.settingsTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _displayTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.definition.accent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionTitle(
                          title: context.t.strings.aiInsight.timeRange.title,
                          textColor: textMain,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _RangeOptionTile(
                              selected: _range == AiInsightRange.last3Days,
                              title: context
                                  .t
                                  .strings
                                  .aiInsight
                                  .timeRange
                                  .last3Days,
                              activeColor: MemoFlowPalette.primary,
                              textColor: textMain,
                              borderColor: border,
                              onTap: () =>
                                  _selectRange(AiInsightRange.last3Days),
                            ),
                            _RangeOptionTile(
                              selected: _range == AiInsightRange.last7Days,
                              title: context
                                  .t
                                  .strings
                                  .aiInsight
                                  .timeRange
                                  .last7Days,
                              activeColor: MemoFlowPalette.primary,
                              textColor: textMain,
                              borderColor: border,
                              onTap: () =>
                                  _selectRange(AiInsightRange.last7Days),
                            ),
                            _RangeOptionTile(
                              selected: _range == AiInsightRange.last30Days,
                              title: context
                                  .t
                                  .strings
                                  .aiInsight
                                  .timeRange
                                  .last30Days,
                              activeColor: MemoFlowPalette.primary,
                              textColor: textMain,
                              borderColor: border,
                              onTap: () =>
                                  _selectRange(AiInsightRange.last30Days),
                            ),
                            _RangeOptionTile(
                              selected: _range == AiInsightRange.custom,
                              title: context
                                  .t
                                  .strings
                                  .aiInsight
                                  .timeRange
                                  .customRange,
                              activeColor: MemoFlowPalette.primary,
                              textColor: textMain,
                              borderColor: border,
                              onTap: () => _selectRange(AiInsightRange.custom),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _rangeLabel(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: border),
                        const SizedBox(height: 16),
                        _SectionTitle(
                          title: context.t.strings.aiInsight.privacyScope.title,
                          textColor: textMain,
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _VisibilityCheckTile(
                                  value: _allowPublic,
                                  onChanged: _toggleAllowPublic,
                                  label: isZh ? '\u516c\u5f00' : 'Public',
                                  textColor: textMain,
                                  activeColor: MemoFlowPalette.primary,
                                ),
                                _VisibilityCheckTile(
                                  value: _allowPrivate,
                                  onChanged: _toggleAllowPrivate,
                                  label: isZh ? '\u79c1\u5bc6' : 'Private',
                                  textColor: textMain,
                                  activeColor: MemoFlowPalette.primary,
                                ),
                                _VisibilityCheckTile(
                                  value: _allowProtected,
                                  onChanged: _toggleAllowProtected,
                                  label: isZh
                                      ? '\u53d7\u4fdd\u62a4'
                                      : 'Protected',
                                  textColor: textMain,
                                  activeColor: MemoFlowPalette.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isZh
                                  ? '\u52fe\u9009\u540e\uff0c\u6240\u9009\u53ef\u89c1\u6027\u7684\u7b14\u8bb0\u4f1a\u76f4\u63a5\u8fdb\u5165\u5206\u6790\u3002'
                                  : 'Checked visibilities will be sent directly into the analysis.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: border),
                        const SizedBox(height: 16),
                        _SectionTitle(
                          title:
                              context.t.strings.aiInsight.promptSettings.title,
                          textColor: textMain,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _openPromptEditor,
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: accentSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _promptSectionTitle(isZh),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _promptSectionDescription(isZh),
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!hasGeneration || !hasEmbedding) ...[
                          const SizedBox(height: 16),
                          Divider(color: border),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.settings_suggest_rounded,
                                      color: MemoFlowPalette.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _aiConfigTitle(
                                          isZh: isZh,
                                          hasGeneration: hasGeneration,
                                          hasEmbedding: hasEmbedding,
                                        ),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: textMain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _aiConfigDescription(
                                    isZh: isZh,
                                    hasGeneration: hasGeneration,
                                    hasEmbedding: hasEmbedding,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: _openAiSettings,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: MemoFlowPalette.primary,
                                    side: BorderSide(
                                      color: MemoFlowPalette.primary.withValues(
                                        alpha: 0.32,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: Text(
                                    isZh
                                        ? '\u53bb AI \u8bbe\u7f6e'
                                        : 'Open AI Settings',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: card,
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textMain,
                                side: BorderSide(color: border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: Text(context.t.strings.common.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _canStartAnalysis
                                  ? _startAnalysis
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: MemoFlowPalette.primary,
                                disabledBackgroundColor: MemoFlowPalette.primary
                                    .withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: Text(
                                context.t.strings.aiInsight.startAnalysis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.textColor});

  final String title;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }
}

class _RangeOptionTile extends StatelessWidget {
  const _RangeOptionTile({
    required this.selected,
    required this.title,
    required this.activeColor,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final Color activeColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? activeColor.withValues(alpha: 0.12)
        : Colors.transparent;
    final stroke = selected ? activeColor : borderColor;
    final foreground = selected ? activeColor : textColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: stroke),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityCheckTile extends StatelessWidget {
  const _VisibilityCheckTile({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.textColor,
    required this.activeColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final Color textColor;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: value ? activeColor : textColor,
        ),
      ),
      showCheckmark: false,
      side: BorderSide(
        color: value ? activeColor : Theme.of(context).dividerColor,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: activeColor.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
