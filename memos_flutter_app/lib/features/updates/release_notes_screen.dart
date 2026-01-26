import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import 'version_announcement_dialog.dart';

class ReleaseNotesScreen extends StatelessWidget {
  const ReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = VersionAnnouncementContent.allEntries();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final lineColor = isDark ? MemoFlowPalette.primaryDark : MemoFlowPalette.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '更新日志', en: 'Release Notes')),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          if (entries.isEmpty)
            Center(
              child: Text(
                context.tr(zh: '暂无更新日志', en: 'No release notes yet'),
                style: TextStyle(color: textMuted),
              ),
            )
          else
            Stack(
              children: [
                Positioned(
                  left: 28,
                  top: 16,
                  bottom: 36,
                  child: Container(
                    width: 2,
                    color: lineColor.withValues(alpha: 0.55),
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      _TimelineEntry(
                        entry: entries[i],
                        card: card,
                        textMain: textMain,
                        textMuted: textMuted,
                        lineColor: lineColor,
                        isDark: isDark,
                      ),
                      if (i != entries.length - 1) const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        context.tr(
                          zh: '以上是全部历史内容\nMEMOFLOW SINCE 2023',
                          en: 'That is all the history so far\nMEMOFLOW SINCE 2023',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, height: 1.4, color: textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.entry,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.lineColor,
    required this.isDark,
  });

  final VersionAnnouncementEntry entry;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final Color lineColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight,
                shape: BoxShape.circle,
                border: Border.all(color: lineColor, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'v${entry.version}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: lineColor),
                    ),
                    const Spacer(),
                    if (entry.dateLabel.trim().isNotEmpty)
                      Text(
                        entry.dateLabel,
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < entry.items.length; i++) ...[
                  _TimelineItem(
                    item: entry.items[i],
                    textMain: textMain,
                    isDark: isDark,
                  ),
                  if (i != entry.items.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.item,
    required this.textMain,
    required this.isDark,
  });

  final VersionAnnouncementItem item;
  final Color textMain;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final detail = context.tr(zh: item.detailZh, en: item.detailEn);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryBadge(category: item.category, isDark: isDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: TextStyle(fontSize: 12.5, height: 1.35, color: textMain),
          ),
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({
    required this.category,
    required this.isDark,
  });

  final ReleaseNoteCategory category;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = category.label(context);
    final color = category.tone(isDark: isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: category.badgeBackground(isDark: isDark),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
