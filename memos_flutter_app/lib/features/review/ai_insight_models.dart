import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/ai/ai_analysis_models.dart'
    show
        AiAnalysisTemplateSnapshot,
        AiRetrievalPreviewItem,
        AiRetrievalPreviewPayload;
import '../../i18n/strings.g.dart';

enum AiInsightId {
  todayClues,
  emotionMap,
  themeResonance,
  thoughtTrace,
  blindSpotDiscovery,
  relationshipView,
  actionExtraction,
  longTermTrajectory,
  customTemplate,
}

class AiInsightDefinition {
  const AiInsightDefinition({
    required this.id,
    required this.icon,
    required this.accent,
  });

  final AiInsightId id;
  final IconData icon;
  final Color accent;

  String title(BuildContext context) => switch (id) {
    AiInsightId.todayClues =>
      context.t.strings.aiInsight.cards.todayClues.title,
    AiInsightId.emotionMap => _emotionMapTitle(context),
    AiInsightId.themeResonance =>
      context.t.strings.aiInsight.cards.themeResonance.title,
    AiInsightId.thoughtTrace =>
      context.t.strings.aiInsight.cards.thoughtTrace.title,
    AiInsightId.blindSpotDiscovery =>
      context.t.strings.aiInsight.cards.blindSpotDiscovery.title,
    AiInsightId.relationshipView =>
      context.t.strings.aiInsight.cards.relationshipView.title,
    AiInsightId.actionExtraction =>
      context.t.strings.aiInsight.cards.actionExtraction.title,
    AiInsightId.longTermTrajectory =>
      context.t.strings.aiInsight.cards.longTermTrajectory.title,
    AiInsightId.customTemplate => _customTemplateTitle(context),
  };

  String description(BuildContext context) => switch (id) {
    AiInsightId.todayClues =>
      context.t.strings.aiInsight.cards.todayClues.description,
    AiInsightId.emotionMap => _emotionMapDescription(context),
    AiInsightId.themeResonance =>
      context.t.strings.aiInsight.cards.themeResonance.description,
    AiInsightId.thoughtTrace =>
      context.t.strings.aiInsight.cards.thoughtTrace.description,
    AiInsightId.blindSpotDiscovery =>
      context.t.strings.aiInsight.cards.blindSpotDiscovery.description,
    AiInsightId.relationshipView =>
      context.t.strings.aiInsight.cards.relationshipView.description,
    AiInsightId.actionExtraction =>
      context.t.strings.aiInsight.cards.actionExtraction.description,
    AiInsightId.longTermTrajectory =>
      context.t.strings.aiInsight.cards.longTermTrajectory.description,
    AiInsightId.customTemplate => _customTemplateDescription(context),
  };
}

const aiInsightDefinitions = <AiInsightDefinition>[
  AiInsightDefinition(
    id: AiInsightId.todayClues,
    icon: Icons.search_rounded,
    accent: Color(0xFFE6A468),
  ),
  AiInsightDefinition(
    id: AiInsightId.emotionMap,
    icon: Icons.favorite_rounded,
    accent: Color(0xFFE695AE),
  ),
  AiInsightDefinition(
    id: AiInsightId.themeResonance,
    icon: Icons.auto_awesome_rounded,
    accent: Color(0xFF7DB8E8),
  ),
  AiInsightDefinition(
    id: AiInsightId.thoughtTrace,
    icon: Icons.bubble_chart_rounded,
    accent: Color(0xFF66C9C8),
  ),
  AiInsightDefinition(
    id: AiInsightId.blindSpotDiscovery,
    icon: Icons.visibility_rounded,
    accent: Color(0xFFB7BE64),
  ),
  AiInsightDefinition(
    id: AiInsightId.relationshipView,
    icon: Icons.people_alt_rounded,
    accent: Color(0xFFD9918F),
  ),
  AiInsightDefinition(
    id: AiInsightId.actionExtraction,
    icon: Icons.bolt_rounded,
    accent: Color(0xFFE6A756),
  ),
  AiInsightDefinition(
    id: AiInsightId.longTermTrajectory,
    icon: Icons.show_chart_rounded,
    accent: Color(0xFF72C7C9),
  ),
];

const visibleAiInsightDefinitions = aiInsightDefinitions;

const customAiInsightDefinition = AiInsightDefinition(
  id: AiInsightId.customTemplate,
  icon: Icons.add_rounded,
  accent: Color(0xFF7C7AF8),
);

AiInsightDefinition definitionForInsight(AiInsightId id) {
  if (id == AiInsightId.customTemplate) {
    return customAiInsightDefinition;
  }
  return aiInsightDefinitions.firstWhere((definition) => definition.id == id);
}

extension AiInsightIdStorage on AiInsightId {
  String get storageKey => switch (this) {
    AiInsightId.todayClues => 'today_clues',
    AiInsightId.emotionMap => 'emotion_map',
    AiInsightId.themeResonance => 'theme_resonance',
    AiInsightId.thoughtTrace => 'thought_trace',
    AiInsightId.blindSpotDiscovery => 'blind_spot_discovery',
    AiInsightId.relationshipView => 'relationship_view',
    AiInsightId.actionExtraction => 'action_extraction',
    AiInsightId.longTermTrajectory => 'long_term_trajectory',
    AiInsightId.customTemplate => 'custom_template',
  };
}

AiInsightId? tryParseAiInsightIdStorageKey(String value) {
  return switch (value.trim()) {
    'today_clues' => AiInsightId.todayClues,
    'emotion_map' => AiInsightId.emotionMap,
    'theme_resonance' => AiInsightId.themeResonance,
    'thought_trace' => AiInsightId.thoughtTrace,
    'blind_spot_discovery' => AiInsightId.blindSpotDiscovery,
    'relationship_view' => AiInsightId.relationshipView,
    'action_extraction' => AiInsightId.actionExtraction,
    'long_term_trajectory' => AiInsightId.longTermTrajectory,
    'custom_template' => AiInsightId.customTemplate,
    _ => null,
  };
}

enum AiInsightRange { last3Days, last7Days, last30Days, custom }

extension AiInsightRangeLabel on AiInsightRange {
  String label(BuildContext context) => switch (this) {
    AiInsightRange.last3Days => context.t.strings.aiInsight.timeRange.last3Days,
    AiInsightRange.last7Days => context.t.strings.aiInsight.timeRange.last7Days,
    AiInsightRange.last30Days =>
      context.t.strings.aiInsight.timeRange.last30Days,
    AiInsightRange.custom => context.t.strings.aiInsight.timeRange.customRange,
  };
}

DateTimeRange resolveAiInsightRange(
  AiInsightRange range,
  DateTimeRange? customRange, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  if (range == AiInsightRange.custom && customRange != null) {
    return customRange;
  }
  if (range == AiInsightRange.last30Days) {
    return DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
  }
  if (range == AiInsightRange.last3Days) {
    return DateTimeRange(
      start: today.subtract(const Duration(days: 2)),
      end: today,
    );
  }
  return DateTimeRange(
    start: today.subtract(const Duration(days: 6)),
    end: today,
  );
}

String formatAiInsightRangeLabel(
  DateTimeRange range, {
  String pattern = 'yyyy.MM.dd',
}) {
  final formatter = DateFormat(pattern);
  return '${formatter.format(range.start)} - ${formatter.format(range.end)}';
}

String formatAiInsightReportRangeLabel(
  BuildContext context,
  DateTimeRange range,
) {
  final locale = Localizations.localeOf(context).toString();
  final sameYear = range.start.year == range.end.year;
  final sameMonth = sameYear && range.start.month == range.end.month;
  final startFormatter = sameYear
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  final endFormatter = sameYear
      ? (sameMonth ? DateFormat.d(locale) : DateFormat.MMMd(locale))
      : DateFormat.yMMMd(locale);
  return '${startFormatter.format(range.start)} - ${endFormatter.format(range.end)}';
}

int estimateAiInsightTokens(String payloadText) {
  if (payloadText.trim().isEmpty) return 0;
  return (utf8.encode(payloadText).length / 4).ceil();
}

typedef AiPreviewMemoItem = AiRetrievalPreviewItem;
typedef AiAnalysisPreviewPayload = AiRetrievalPreviewPayload;

String resolveInsightPromptTemplate(
  BuildContext context, {
  required AiInsightId insightId,
  required Map<String, String> templates,
}) {
  final stored = templates[insightId.storageKey]?.trim() ?? '';
  if (stored.isNotEmpty &&
      !_isBuiltinInsightPromptTemplate(context, insightId, stored)) {
    return stored;
  }
  return defaultInsightPromptTemplate(context, insightId);
}

bool hasCustomInsightPromptTemplate(
  Map<String, String> templates,
  AiInsightId insightId,
) {
  final stored = (templates[insightId.storageKey]?.trim() ?? '');
  if (stored.isEmpty) {
    return false;
  }
  return true;
}

bool hasMeaningfulCustomInsightPromptTemplate(
  BuildContext context,
  Map<String, String> templates,
  AiInsightId insightId,
) {
  final stored = (templates[insightId.storageKey]?.trim() ?? '');
  if (stored.isEmpty) {
    return false;
  }
  return !_isBuiltinInsightPromptTemplate(context, insightId, stored);
}

bool _isBuiltinInsightPromptTemplate(
  BuildContext context,
  AiInsightId insightId,
  String template,
) {
  final normalized = template.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized == defaultInsightPromptTemplate(context, insightId).trim()) {
    return true;
  }
  final legacy = _legacyInsightPromptTemplate(context, insightId)?.trim();
  return legacy != null && legacy.isNotEmpty && normalized == legacy;
}

String? _legacyInsightPromptTemplate(
  BuildContext context,
  AiInsightId insightId,
) {
  final isZh =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  return switch (insightId) {
    AiInsightId.todayClues =>
      isZh
          ? '\u8bf7\u805a\u7126\u6700\u8fd1\u6700\u503c\u5f97\u7ee7\u7eed\u8ffd\u8e2a\u7684\u4e00\u5230\u4e24\u4e2a\u7ebf\u7d22\uff1a\u90a3\u4e9b\u53cd\u590d\u51fa\u73b0\u3001\u5c1a\u672a\u89e3\u51b3\u3001\u6b63\u5728\u53d1\u9175\u7684\u4e8b\u60c5\u3002\u5199\u51fa\u5b83\u4eec\u5728\u8bb0\u5f55\u4e2d\u5982\u4f55\u6d6e\u73b0\u3001\u4e3a\u4ec0\u4e48\u503c\u5f97\u6ce8\u610f\uff0c\u4ee5\u53ca\u63a5\u4e0b\u6765\u6700\u503c\u5f97\u7559\u610f\u7684\u53d8\u5316\u3002\u4fdd\u6301\u8fde\u8d2f\u53d9\u8ff0\uff0c\u4e0d\u8981\u5199\u6210\u6e05\u5355\u6216\u62a5\u544a\u3002'
          : null,
    AiInsightId.emotionMap =>
      isZh
          ? '\u8bf7\u628a\u91cd\u70b9\u653e\u5728\u8fd9\u6bb5\u65f6\u95f4\u7684\u60c5\u7eea\u6d41\u52a8\u4e0a\uff1a\u54ea\u4e9b\u60c5\u7eea\u5728\u53cd\u590d\u51fa\u73b0\uff0c\u5b83\u4eec\u901a\u5e38\u7531\u4ec0\u4e48\u89e6\u53d1\uff0c\u53c8\u600e\u6837\u5f71\u54cd\u4e86\u884c\u52a8\u3001\u5173\u7cfb\u6216\u8eab\u4f53\u611f\u53d7\u3002\u7528\u6e29\u548c\u5177\u4f53\u7684\u65b9\u5f0f\u5199\u51fa\u60c5\u7eea\u53d8\u5316\uff0c\u800c\u4e0d\u662f\u7ed9\u60c5\u7eea\u8d34\u6807\u7b7e\u3002'
          : null,
    AiInsightId.themeResonance =>
      isZh
          ? '\u8bf7\u8bc6\u522b\u6700\u8fd1\u53cd\u590d\u56de\u6765\u7684\u4e3b\u9898\u3001\u6267\u5ff5\u6216\u7275\u5f15\u529b\u3002\u8bf4\u660e\u8fd9\u4e9b\u4e3b\u9898\u4e3a\u4ec0\u4e48\u6301\u7eed\u51fa\u73b0\uff0c\u5f7c\u6b64\u4e4b\u95f4\u600e\u6837\u547c\u5e94\uff0c\u4ee5\u53ca\u5b83\u4eec\u900f\u9732\u51fa\u4f60\u8fd9\u6bb5\u65f6\u95f4\u771f\u6b63\u5173\u5fc3\u7684\u662f\u4ec0\u4e48\u3002'
          : null,
    AiInsightId.thoughtTrace =>
      isZh
          ? '\u8bf7\u6cbf\u7740\u8bb0\u5f55\u4e2d\u7684\u601d\u8def\u7ee7\u7eed\u5f80\u4e0b\u68b3\u7406\uff1a\u6709\u54ea\u4e9b\u95ee\u9898\u3001\u5224\u65ad\u3001\u72b9\u8c6b\u6216\u6f5c\u5728\u5047\u8bbe\u5728\u63a8\u52a8\u8fd9\u6bb5\u65f6\u95f4\u7684\u601d\u8003\u3002\u5c3d\u91cf\u5199\u51fa\u601d\u7ef4\u662f\u600e\u6837\u4e00\u6b65\u6b65\u5c55\u5f00\u7684\uff0c\u4ee5\u53ca\u5b83\u5361\u4f4f\u6216\u8f6c\u5411\u7684\u5730\u65b9\u3002'
          : null,
    AiInsightId.blindSpotDiscovery =>
      isZh
          ? '\u8bf7\u6e29\u548c\u5730\u6307\u51fa\u8bb0\u5f55\u91cc\u5bb9\u6613\u88ab\u5ffd\u89c6\u7684\u4fe1\u53f7\u3001\u77db\u76fe\u3001\u91cd\u590d\u52a8\u4f5c\u6216\u9690\u85cf\u6a21\u5f0f\u3002\u4e0d\u8981\u6b66\u65ad\u4e0b\u7ed3\u8bba\uff0c\u800c\u662f\u5e2e\u52a9\u6211\u770b\u89c1\u90a3\u4e9b\u5e73\u65f6\u4e0d\u5bb9\u6613\u6ce8\u610f\u5230\u7684\u90e8\u5206\uff0c\u4ee5\u53ca\u5b83\u4eec\u53ef\u80fd\u610f\u5473\u7740\u4ec0\u4e48\u3002'
          : null,
    AiInsightId.relationshipView =>
      isZh
          ? '\u8bf7\u4ece\u4eba\u4e0e\u5173\u7cfb\u7684\u89d2\u5ea6\u9605\u8bfb\u8fd9\u4e9b\u8bb0\u5f55\uff1a\u8c01\u5728\u9760\u8fd1\uff0c\u8c01\u5728\u62c9\u626f\uff0c\u54ea\u4e9b\u4e92\u52a8\u6b63\u5728\u6539\u53d8\u6211\u7684\u611f\u53d7\u548c\u9009\u62e9\u3002\u91cd\u70b9\u5199\u51fa\u5173\u7cfb\u4e2d\u7684\u5f20\u529b\u3001\u652f\u6301\u6216\u8fb9\u754c\u611f\uff0c\u800c\u4e0d\u662f\u53ea\u590d\u8ff0\u4e8b\u4ef6\u3002'
          : null,
    AiInsightId.actionExtraction =>
      isZh
          ? '\u8bf7\u4ece\u8fd9\u4e9b\u8bb0\u5f55\u91cc\u63d0\u70bc\u51fa\u6700\u503c\u5f97\u5c1d\u8bd5\u7684\u4e00\u4e24\u4e2a\u5177\u4f53\u884c\u52a8\u6216\u5c0f\u5b9e\u9a8c\u3002\u8bf4\u660e\u8fd9\u4e9b\u884c\u52a8\u5bf9\u5e94\u4e86\u4ec0\u4e48\u7ebf\u7d22\uff0c\u4e3a\u4ec0\u4e48\u73b0\u5728\u9002\u5408\u5f00\u59cb\uff0c\u4ee5\u53ca\u600e\u6837\u8ba9\u5b83\u4eec\u8db3\u591f\u8f7b\u3001\u8db3\u591f\u53ef\u6267\u884c\u3002\u4e0d\u8981\u7ed9\u51fa\u5197\u957f\u6e05\u5355\u3002'
          : null,
    AiInsightId.longTermTrajectory =>
      isZh
          ? '\u8bf7\u628a\u8fd9\u4e9b\u8bb0\u5f55\u653e\u56de\u66f4\u957f\u7684\u65f6\u95f4\u7ebf\u4e0a\uff0c\u89c2\u5bdf\u9636\u6bb5\u6027\u7684\u53d8\u5316\u3001\u5faa\u73af\u548c\u8d8b\u52bf\u3002\u5199\u51fa\u4ec0\u4e48\u5728\u6162\u6162\u79ef\u7d2f\uff0c\u4ec0\u4e48\u5728\u53cd\u590d\u56de\u5230\u539f\u70b9\uff0c\u4ee5\u53ca\u8fd9\u6bb5\u65f6\u95f4\u76f8\u6bd4\u66f4\u65e9\u4ee5\u524d\u6700\u660e\u663e\u7684\u53d8\u5316\u3002'
          : null,
    AiInsightId.customTemplate =>
      isZh
          ? '\u8bf7\u6839\u636e\u6211\u81ea\u5b9a\u4e49\u7684\u6a21\u677f\u6807\u9898\u3001\u8bf4\u660e\u548c\u63d0\u793a\u8bcd\uff0c\u7ed3\u5408\u8fd9\u4e9b\u8bb0\u5f55\u5c55\u5f00\u5206\u6790\u3002'
          : 'Analyze these notes using the custom title, description, and prompt I provided.',
  };
}

String defaultInsightPromptTemplate(
  BuildContext context,
  AiInsightId insightId,
) {
  final isZh =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  return switch (insightId) {
    AiInsightId.todayClues =>
      isZh
          ? '''你现在是一个细腻、克制、善于观察的阅读者。请阅读我提供的笔记内容，不要机械总结，而是像在一堆生活碎片里，帮我找到“此刻最值得被看见的线索”。

你的任务不是罗列内容，而是识别：
- 我最近反复在意的事
- 我情绪背后真正牵动我的问题
- 那些我自己可能已经写出来，但还没来得及命名的变化或信号

请遵守以下要求：
1. 用“写给我”的口吻输出，像一封短短信，不要写成报告。
2. 开头先用 1～2 句话回应我最近整体的状态，让我感觉“被读懂了”。
3. 接着提炼 2～4 条“今日线索”，每条都要：
   - 有一个简短的小标题
   - 说明你为什么注意到这条线索
   - 引用我笔记中的细节来支撑，而不是空泛判断
4. 最后用一小段话告诉我：这些线索可能在提醒我什么。
5. 不要使用“根据你的内容可以看出”“综合来看”这类 AI 套话。
6. 不要过度积极，也不要鸡汤，要真实、温和、克制。
7. 允许保留不确定性，可以使用“也许”“像是在”“似乎”这样的表达。

输出结构参考：
- 一段开场回应
- 今日线索 1
- 今日线索 2
- 今日线索 3（如果有）
- 一个收束段落

请结合引用内容写，不要脱离原文臆测。'''
          : 'Focus on the one or two clues that feel most worth tracking right now: recurring, unresolved, or still-developing threads. Explain how they surface in the notes, why they matter, and what feels most important to keep watching next. Keep the writing continuous rather than turning it into a checklist or report.',
    AiInsightId.emotionMap =>
      isZh
          ? '''请阅读我提供的笔记，帮我绘制一份“情绪地图”。这不是简单统计开心、难过，而是要看见我最近的情绪是如何流动、堆积、转折和变化的。

请遵守以下要求：
1. 输出风格像写给我的回信，不要写成心理测评报告。
2. 开头先描述我最近整体的情绪天气，例如：紧绷、反复、压抑、松动、麻木、回暖、摇摆……但表达要自然，不要模板化。
3. 正文请识别：
   - 最近最常出现的 2～4 种情绪
   - 这些情绪通常在什么情境下被触发
   - 它们会引发我怎样的后续反应（比如回避、内耗、自责、争辩、冷下来、想靠近、想逃）
4. 不只写表层情绪，也尝试区分情绪下面更深一层的体验，例如：
   - 生气下面可能是委屈
   - 焦虑下面可能是失控感
   - 麻木下面可能是疲惫或失望
5. 每个判断都尽量引用笔记里的具体片段或细节来支撑。
6. 最后补一段“情绪走向观察”，告诉我：
   - 这些情绪最近是变重了、变轻了，还是在循环
   - 有没有某种情绪在反复出现，值得我特别留意
7. 语言要温和、准确、不过度解释，不要说教。

请避免：
- 只列标签
- 空洞安慰
- 生硬使用专业术语
- 把内容写成表格

请把结果写得像一个真正读完我近况的人，在认真帮我整理内心天气。'''
          : 'Focus on the emotional currents in this stretch of time: which feelings keep returning, what tends to trigger them, and how they shape actions, relationships, or body sensations. Describe emotional movement in a warm and concrete way instead of labeling feelings from a distance.',
    AiInsightId.themeResonance =>
      isZh
          ? '''请阅读我提供的笔记，帮我识别最近反复出现的“主题”。这些主题不一定是高频词，也可能是反复出现的处境、关系模式、担忧、期待、拉扯或执念。

你的任务是从零散记录中听出“最近我一直在围绕什么打转”。

请遵守以下要求：
1. 输出像一封有层次的短回信，不要写成知识分析报告。
2. 开头先用一小段话概括：最近我生命里有哪些主题正在同时发声。
3. 然后提炼 2～4 个主题，每个主题都需要包含：
   - 一个准确、自然的小标题
   - 这个主题为什么成立
   - 它在不同笔记里是如何以不同形式出现的
   - 它可能连接着我怎样的内在关注
4. 所谓“主题”可以是：
   - 对关系的在意
   - 对自我价值的怀疑
   - 对未来的焦虑
   - 对秩序、掌控、安全感、认可、边界、表达的关注
   - 某种长期未解决的拉扯
5. 每个主题都尽量结合原文细节，不要空泛抽象。
6. 最后一段请写：这些主题彼此之间有没有共鸣，它们可能共同指向什么。
7. 用语要有人味，不要写成“主题一、主题二”的僵硬论文格式，可以保留一点文学感，但不要矫饰。

请重点做“提炼与连线”，不要只做内容归纳。'''
          : 'Identify the themes, obsessions, or pulls that keep returning lately. Explain why they continue to surface, how they echo one another, and what they reveal about what you have been genuinely caring about in this period.',
    AiInsightId.thoughtTrace =>
      isZh
          ? '''请阅读我提供的笔记，帮我识别最近记录里出现的“思维迹象”。这里关注的不是结论对错，而是我在看待事情时，正在反复使用哪些思维路径、解释方式和内在推演习惯。

请遵守以下要求：
1. 输出语气要温和、审慎，像一个聪明但不评判的人在陪我一起复盘。
2. 不要把我病理化，也不要轻易下诊断。
3. 请重点观察这些内容：
   - 我是如何解释别人行为的
   - 我遇到事情时，是否容易迅速归因到自己
   - 我会不会倾向于灾难化、绝对化、过度负责、预设他人看法、反复自我审判
   - 我是否也在出现新的、更灵活的理解方式
4. 请提炼 2～4 条明显的“思维迹象”，每条都包括：
   - 一个简短标题
   - 相关的笔记证据
   - 这条思维路径通常会把我带向什么感受或后果
5. 如果你发现我既有旧模式，也有新的松动迹象，请把两者都写出来。
6. 最后写一小段总结：
   - 最近我的思维更像是在防御、求证、控制，还是在慢慢变得松动
   - 哪一种思维习惯最值得我温柔地留意
7. 不要说教，不要给出“你应该如何做”的训练建议，这个模板只负责看见和命名。

请让文字读起来像“你真的在理解我脑子里是怎么转的”，而不是在做刻板分析。'''
          : 'Follow the lines of thought in the notes a little further: which questions, judgments, hesitations, or hidden assumptions have been shaping this stretch of thinking. Show how the thinking unfolds step by step, and where it gets stuck or changes direction.',
    AiInsightId.blindSpotDiscovery =>
      isZh
          ? '''请阅读我提供的笔记，帮我做一次“盲点发现”。这里的盲点不是挑错，也不是批评我，而是帮我看见：有哪些我已经写出来、但自己可能还没完全意识到的重复模式、矛盾、遗漏或被忽视的信号。

请遵守以下要求：
1. 语气必须温和、克制、有善意，像提醒，而不是审判。
2. 开头先说明：你看到的不是“问题清单”，而是一些值得轻轻停下来再看一眼的地方。
3. 请提炼 2～4 个可能的盲点，每个盲点都包含：
   - 一个简短标题
   - 你为什么会注意到它
   - 它在笔记中体现在哪些细节里
   - 这个盲点可能让我忽略了什么
4. 盲点可能包括但不限于：
   - 我总在说别人，却很少说自己真正要什么
   - 我总在自责，却忽略了自己的委屈
   - 我表面说无所谓，但内容里其实很在意
   - 我一直强调道理，却跳过了感受
   - 我在重复某个困境，却没有真正触碰核心
5. 允许使用“也许”“可能”“我不确定，但像是……”这样的表达，避免武断定性。
6. 最后请写一个温柔的收束段落，告诉我：
   - 如果要从这些盲点里选一个最值得继续观察的，会是哪一个
   - 为什么它值得被慢一点看见
7. 不要输出成清单式说教，不要使用训诫口吻。

请让我感受到：这不是在被挑毛病，而是在被提醒那些自己还没看清的地方。'''
          : 'Gently point out the signals, contradictions, repeated moves, or hidden patterns that are easy to miss in the notes. Do not make hard claims; help me notice what usually slips past attention and what it may be hinting at.',
    AiInsightId.relationshipView =>
      isZh
          ? '''请阅读我提供的笔记，从“关系”的角度重新理解这些记录。重点不是泛泛谈人际关系，而是看见：我在与别人互动时，内心真正发生了什么，我在关系里扮演了什么位置，又在害怕、期待、维护什么。

请遵守以下要求：
1. 输出要像写给我的一封关系观察信，不要写成咨询报告。
2. 开头先简短回应：最近我的关系状态给人的整体感觉是什么，例如靠近、后退、敏感、防御、渴望连接、害怕受伤、不断试探边界等。
3. 然后提炼 2～4 个关系观察，每个都包括：
   - 一个简短标题
   - 关系中的具体表现或场景
   - 我在这个关系片段里可能在保护什么、期待什么、担心什么
   - 相关笔记证据
4. 重点关注：
   - 我如何理解别人
   - 我如何承接他人的情绪
   - 我是否容易自责、迎合、退缩、控制、疏离、试探
   - 我在关系里是否既想靠近又想防御
5. 可以观察“角色位置”，比如：
   - 解释者
   - 承担者
   - 退后的人
   - 观察者
   - 防御者
   - 渴望被看见的人
6. 最后请写一段总结：最近我的关系模式里，最明显的拉扯是什么。
7. 不要直接下判断说“你就是回避型/焦虑型”，避免贴标签。

请让结果读起来像：有人真的在关系层面读懂了我，而不是只看事件表面。'''
          : 'Read these notes through the lens of people and relationships: who is moving closer, who is pulling away, and which interactions are shifting my feelings or choices. Emphasize tension, support, or boundaries in the relationships rather than merely retelling events.',
    AiInsightId.actionExtraction =>
      isZh
          ? '''请阅读我提供的笔记，从这些想法、情绪、困扰和反复中，帮我提炼出“现在真正值得去做的行动”。不是列很多建议，而是从复杂内容里筛出少量、具体、可执行、贴合我当下状态的下一步。

请遵守以下要求：
1. 输出风格要像一封鼓励但不强推的回信，不要写成任务管理器。
2. 开头先用几句话回应：最近我面对的事情很多，哪些最消耗我，哪些最值得优先处理。
3. 然后只提炼 2～4 个行动建议，每条都必须满足：
   - 足够小，可以开始
   - 足够具体，不空泛
   - 和我笔记里真实出现的问题有关
   - 不以“变得更好”为目标，而以“让当下更可承受、更清楚一点”为目标
4. 每个行动建议都要包含：
   - 一个简短标题
   - 为什么是这一步，而不是更大的动作
   - 它对应了我笔记中的哪类困扰
5. 行动方向可以包括：
   - 一个需要说出口的边界
   - 一个值得写下来的问题
   - 一个需要暂停的内耗动作
   - 一个可以验证现实的微实验
   - 一个照顾身体或情绪的具体动作
6. 最后请加一小段话：如果我只做一件事，最值得先做哪一件，以及为什么。
7. 语气不要命令，不要鸡血，也不要把行动说得像 KPI。

请让我感觉：这些行动真的是从我的生活里长出来的，而不是 AI 随手给的万能建议。'''
          : 'Extract one or two concrete actions or small experiments that feel most worth trying next. Explain which clues they answer, why now is a fitting time to begin, and how to keep them light and realistic instead of turning them into a long action list.',
    AiInsightId.longTermTrajectory =>
      isZh
          ? '''请阅读我提供的笔记，从更长一点的时间视角，帮我观察我的“长期轨迹”。重点不是总结近况，而是看见：我持续在重复什么、坚持什么、逃开什么、靠近什么，我的内在模式有没有出现缓慢但真实的变化。

请遵守以下要求：
1. 输出语气要沉静、诚实、有陪伴感，像在帮我回望一段路。
2. 开头先给出一个整体判断：
   - 最近这段时间，我像是在原地打转、缓慢转向，还是在某个旧模式里出现了新的松动
3. 然后提炼 2～4 条“长期轨迹观察”，每条都包含：
   - 一个简短标题
   - 这条轨迹为什么成立
   - 它在笔记中是如何反复出现的
   - 它有没有发生细微变化
4. 可以重点关注：
   - 情绪反应是否在重复
   - 对自己的评价方式是否在重复
   - 关系中的位置是否总是类似
   - 某类困扰是否总在回返
   - 有没有一些旧有模式正在慢慢松动
5. 允许同时写出“重复”与“变化”，不要只强调成长，也不要只强调困住。
6. 最后请写一个收束段落：
   - 如果把这段时期看成一条路，我现在大概走到了哪里
   - 接下来最值得继续观察的是什么
7. 不要写成年度总结，也不要用宏大口号。

请把它写得像一个真正陪我走过一段时间的人，在回望我身上的那些缓慢变化。'''
          : 'Place these notes back on a longer timeline and look for phase changes, cycles, and trends. Describe what has been slowly accumulating, what keeps looping back, and what feels most noticeably different from earlier periods.',
    AiInsightId.customTemplate =>
      isZh
          ? '\u8bf7\u6839\u636e\u6211\u81ea\u5b9a\u4e49\u7684\u6807\u9898\u3001\u8bf4\u660e\u548c\u63d0\u793a\u8bcd\uff0c\u56f4\u7ed5\u8fd9\u4e9b\u8bb0\u5f55\u505a\u4e00\u6b21\u6709\u6df1\u5ea6\u3001\u6709\u7ebf\u7d22\u7684\u5206\u6790\u3002'
          : 'Use my custom title, description, and prompt to analyze these notes in a focused and thoughtful way.',
  };
}

String _emotionMapTitle(BuildContext context) {
  final isZh =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  return isZh ? '\u60c5\u7eea\u5730\u56fe' : 'Letter Back';
}

String _emotionMapDescription(BuildContext context) {
  final isZh =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  return isZh
      ? '\u5206\u6790\u8bb0\u5f55\u4e2d\u7684\u60c5\u7eea\u6d41\u52a8\uff0c\u770b\u770b\u6700\u8fd1\u4ec0\u4e48\u5728\u6301\u7eed\u5f71\u54cd\u4f60\u7684\u72b6\u6001\u3002'
      : 'Read this stretch of notes back as a gentle reply instead of a report.';
}

String _customTemplateTitle(BuildContext context) {
  final isZh =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  return isZh ? '\u81ea\u5b9a\u4e49\u6a21\u677f' : 'Custom Template';
}

String _customTemplateDescription(BuildContext context) {
  final isZh =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  return isZh
      ? '\u521b\u5efa\u4e00\u4e2a\u5c5e\u4e8e\u4f60\u7684 AI \u5206\u6790\u89c6\u89d2\u3002'
      : 'Create an AI analysis perspective that fits you.';
}

class AiInsightSettingsResult {
  const AiInsightSettingsResult({
    required this.insightId,
    required this.range,
    required this.customRange,
    required this.allowPublic,
    required this.allowPrivate,
    required this.allowProtected,
    required this.previewPayload,
    required this.promptTemplate,
    this.templateSnapshot = AiAnalysisTemplateSnapshot.legacy,
  });

  final AiInsightId insightId;
  final AiInsightRange range;
  final DateTimeRange? customRange;
  final bool allowPublic;
  final bool allowPrivate;
  final bool allowProtected;
  final AiAnalysisPreviewPayload previewPayload;
  final String promptTemplate;
  final AiAnalysisTemplateSnapshot templateSnapshot;
}
