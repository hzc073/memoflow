import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/desktop_window_controls.dart';
import '../../core/memoflow_palette.dart';
import '../../data/ai/ai_analysis_models.dart';
import '../../state/review/ai_analysis_provider.dart';
import 'ai_insight_history_shared.dart';
import 'ai_insight_models.dart';

class AiInsightHistoryScreen extends ConsumerStatefulWidget {
  const AiInsightHistoryScreen({super.key});

  @override
  ConsumerState<AiInsightHistoryScreen> createState() =>
      _AiInsightHistoryScreenState();
}

class _AiInsightHistoryScreenState
    extends ConsumerState<AiInsightHistoryScreen> {
  late final Future<List<AiSavedAnalysisHistoryEntry>> _historyFuture;
  int? _openingTaskId;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref
        .read(aiAnalysisRepositoryProvider)
        .listAnalysisReportHistory(analysisType: AiAnalysisType.emotionMap);
  }

  Future<void> _openHistoryEntry(AiSavedAnalysisHistoryEntry entry) async {
    if (_openingTaskId != null) return;
    setState(() => _openingTaskId = entry.taskId);
    final report = await ref
        .read(aiAnalysisRepositoryProvider)
        .loadAnalysisReportByTaskId(entry.taskId);
    if (!mounted) return;
    setState(() => _openingTaskId = null);
    if (report == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loadFailedText())));
      return;
    }
    final descriptor = resolveAiInsightHistoryDescriptor(context, ref, entry);
    Navigator.of(context).pop(
      AiInsightHistorySelection(
        report: report,
        rangeStart: entry.rangeStart,
        rangeEndExclusive: entry.rangeEndExclusive,
        insightId: descriptor.insightId,
        titleOverride: descriptor.titleOverride,
      ),
    );
  }

  String _historyTitle() {
    return aiInsightHistoryTitle(context);
  }

  String _emptyTitle() {
    return _isZhLocale()
        ? '\u8fd8\u6ca1\u6709\u5386\u53f2\u601d\u8003'
        : 'No past insights yet';
  }

  String _emptySubtitle() {
    return _isZhLocale()
        ? '\u6bcf\u6b21\u5b8c\u6210 AI \u601d\u8003\uff0c\u90fd\u4f1a\u5728\u8fd9\u91cc\u7559\u4e0b\u8bb0\u5f55\u3002'
        : 'Every completed AI insight will show up here.';
  }

  String _loadFailedText() {
    return aiInsightHistoryOpenFailedText(context);
  }

  String _staleLabel() {
    return aiInsightHistoryStaleLabel(context);
  }

  String _formatCreatedTime(int createdTime) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      createdTime,
      isUtc: true,
    ).toLocal();
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).add_Hm().format(date);
  }

  String _formatRange(AiSavedAnalysisHistoryEntry entry) {
    final selection = AiInsightHistorySelection(
      report: const AiSavedAnalysisReport(
        taskId: 0,
        taskUid: '',
        status: AiTaskStatus.completed,
        summary: '',
        sections: <AiAnalysisSectionData>[],
        evidences: <AiAnalysisEvidenceData>[],
        followUpSuggestions: <String>[],
        isStale: false,
      ),
      rangeStart: entry.rangeStart,
      rangeEndExclusive: entry.rangeEndExclusive,
      insightId: AiInsightId.emotionMap,
    );
    return formatAiInsightReportRangeLabel(context, selection.range);
  }

  bool _isZhLocale() {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enableWindowsDragToMove = Platform.isWindows;
    final bg = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? MemoFlowPalette.cardDark : Colors.white;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = colorScheme.onSurface;
    final textMuted = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 46,
        flexibleSpace: enableWindowsDragToMove
            ? const DragToMoveArea(child: SizedBox.expand())
            : null,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: IgnorePointer(
          ignoring: enableWindowsDragToMove,
          child: Text(
            _historyTitle(),
            style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
          ),
        ),
        actions: [if (enableWindowsDragToMove) const DesktopWindowControls()],
      ),
      body: FutureBuilder<List<AiSavedAnalysisHistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _loadFailedText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted),
                ),
              ),
            );
          }
          final items = snapshot.data ?? const <AiSavedAnalysisHistoryEntry>[];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 34,
                      color: textMuted.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _emptyTitle(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _emptySubtitle(),
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.5, color: textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = items[index];
              final descriptor = resolveAiInsightHistoryDescriptor(
                context,
                ref,
                entry,
              );
              final isOpening = _openingTaskId == entry.taskId;
              final summary = entry.summary.trim();
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isOpening ? null : () => _openHistoryEntry(entry),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: descriptor.accent.withValues(
                              alpha: isDark ? 0.24 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            descriptor.icon,
                            size: 20,
                            color: descriptor.accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      descriptor.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: textMain,
                                      ),
                                    ),
                                  ),
                                  if (entry.isStale)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: MemoFlowPalette.primary
                                            .withValues(
                                              alpha: isDark ? 0.22 : 0.1,
                                            ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _staleLabel(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: MemoFlowPalette.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatCreatedTime(entry.createdTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatRange(entry),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                aiInsightHistoryVisibilityLabel(context, entry),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                              if (summary.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  summary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.55,
                                    color: textMain.withValues(alpha: 0.86),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        isOpening
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: textMuted,
                              ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
