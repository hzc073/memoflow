import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/ai/ai_analysis_models.dart';
import '../../data/ai/ai_settings_models.dart';
import '../../state/settings/ai_settings_provider.dart';
import 'ai_insight_models.dart';
import 'quick_prompt_editor_screen.dart';

class AiInsightHistorySelection {
  const AiInsightHistorySelection({
    required this.report,
    required this.rangeStart,
    required this.rangeEndExclusive,
    required this.insightId,
    this.titleOverride,
  });

  final AiSavedAnalysisReport report;
  final int rangeStart;
  final int rangeEndExclusive;
  final AiInsightId insightId;
  final String? titleOverride;

  DateTimeRange get range {
    final start = DateTime.fromMillisecondsSinceEpoch(
      rangeStart * 1000,
      isUtc: true,
    ).toLocal();
    final endExclusive = DateTime.fromMillisecondsSinceEpoch(
      rangeEndExclusive * 1000,
      isUtc: true,
    ).toLocal();
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEndExclusive = DateTime(
      endExclusive.year,
      endExclusive.month,
      endExclusive.day,
    );
    return DateTimeRange(
      start: normalizedStart,
      end: normalizedEndExclusive.subtract(const Duration(days: 1)),
    );
  }
}

class AiInsightHistoryDescriptor {
  const AiInsightHistoryDescriptor({
    required this.insightId,
    required this.title,
    required this.icon,
    required this.accent,
    this.titleOverride,
  });

  final AiInsightId insightId;
  final String title;
  final IconData icon;
  final Color accent;
  final String? titleOverride;
}

AiInsightHistoryDescriptor resolveAiInsightHistoryDescriptor(
  BuildContext context,
  WidgetRef ref,
  AiSavedAnalysisHistoryEntry entry,
) {
  return resolveAiInsightHistoryDescriptorWithSettings(
    context,
    settings: ref.read(aiSettingsProvider),
    entry: entry,
  );
}

AiInsightHistoryDescriptor resolveAiInsightHistoryDescriptorWithSettings(
  BuildContext context, {
  required AiSettings settings,
  required AiSavedAnalysisHistoryEntry entry,
}) {
  final templateId = entry.templateId.trim();
  final titleSnapshot = entry.templateTitleSnapshot.trim();
  final iconKeySnapshot = entry.templateIconKeySnapshot.trim();

  if (entry.templateKind == AiAnalysisTemplateKind.builtIn) {
    final insightId = tryParseAiInsightIdStorageKey(templateId);
    if (insightId != null && insightId != AiInsightId.customTemplate) {
      final definition = definitionForInsight(insightId);
      return AiInsightHistoryDescriptor(
        insightId: insightId,
        title: definition.title(context),
        icon: definition.icon,
        accent: definition.accent,
      );
    }
  }

  if (entry.templateKind == AiAnalysisTemplateKind.custom) {
    final matchingTemplate = settings.findCustomInsightTemplate(templateId);
    final resolvedTitle = titleSnapshot.isNotEmpty
        ? titleSnapshot
        : (matchingTemplate?.title.trim() ?? '');
    final resolvedIconKey = iconKeySnapshot.isNotEmpty
        ? iconKeySnapshot
        : (matchingTemplate?.iconKey.trim() ?? '');
    if (resolvedTitle.isNotEmpty) {
      return AiInsightHistoryDescriptor(
        insightId: AiInsightId.customTemplate,
        title: resolvedTitle,
        titleOverride: resolvedTitle,
        icon: QuickPromptIconCatalog.resolve(resolvedIconKey),
        accent: MemoFlowPalette.primary,
      );
    }
  }

  final normalized = entry.promptTemplate.trim();
  for (final definition in visibleAiInsightDefinitions) {
    final resolved = resolveInsightPromptTemplate(
      context,
      insightId: definition.id,
      templates: settings.insightPromptTemplates,
    ).trim();
    if (resolved.isNotEmpty && resolved == normalized) {
      return AiInsightHistoryDescriptor(
        insightId: definition.id,
        title: definition.title(context),
        icon: definition.icon,
        accent: definition.accent,
      );
    }
  }
  for (final customTemplate in settings.customInsightTemplates) {
    if (customTemplate.promptTemplate.trim() != normalized) {
      continue;
    }
    return AiInsightHistoryDescriptor(
      insightId: AiInsightId.customTemplate,
      title: customTemplate.title.trim(),
      titleOverride: customTemplate.title.trim(),
      icon: QuickPromptIconCatalog.resolve(customTemplate.iconKey),
      accent: MemoFlowPalette.primary,
    );
  }
  final fallback = aiInsightHistoryTitle(context);
  return AiInsightHistoryDescriptor(
    insightId: AiInsightId.emotionMap,
    title: fallback,
    titleOverride: fallback,
    icon: Icons.history_rounded,
    accent: MemoFlowPalette.primary,
  );
}

String aiInsightHistoryTitle(BuildContext context) {
  return _isZhLocale(context) ? '历史思考' : 'Insight History';
}

String aiInsightHistoryOpenFailedText(BuildContext context) {
  return _isZhLocale(context)
      ? '这条历史暂时打不开。'
      : 'This history entry cannot be opened right now.';
}

String aiInsightHistoryStaleLabel(BuildContext context) {
  return _isZhLocale(context) ? '笔记已更新' : 'Notes updated';
}

String aiInsightHistoryVisibilityLabel(
  BuildContext context,
  AiSavedAnalysisHistoryEntry entry,
) {
  final labels = <String>[
    if (entry.includePublic) (_isZhLocale(context) ? '公开' : 'Public'),
    if (entry.includePrivate) (_isZhLocale(context) ? '私密' : 'Private'),
    if (entry.includeProtected) (_isZhLocale(context) ? '受保护' : 'Protected'),
  ];
  return labels.join(' / ');
}

bool _isZhLocale(BuildContext context) {
  return Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
}
