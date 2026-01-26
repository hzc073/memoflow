import 'package:flutter/material.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';

enum ReleaseNoteCategory {
  feature,
  improvement,
  fix,
}

extension ReleaseNoteCategoryX on ReleaseNoteCategory {
  String label(BuildContext context) => switch (this) {
        ReleaseNoteCategory.feature => context.tr(zh: '新增', en: 'New'),
        ReleaseNoteCategory.improvement => context.tr(zh: '优化', en: 'Improved'),
        ReleaseNoteCategory.fix => context.tr(zh: '修复', en: 'Fixed'),
      };

  String labelWithColon(BuildContext context) => switch (this) {
        ReleaseNoteCategory.feature => context.tr(zh: '新增：', en: 'New: '),
        ReleaseNoteCategory.improvement => context.tr(zh: '优化：', en: 'Improved: '),
        ReleaseNoteCategory.fix => context.tr(zh: '修复：', en: 'Fixed: '),
      };

  Color tone({required bool isDark}) => switch (this) {
        ReleaseNoteCategory.feature => isDark ? MemoFlowPalette.primaryDark : MemoFlowPalette.primary,
        ReleaseNoteCategory.improvement => const Color(0xFF7E9B8F),
        ReleaseNoteCategory.fix => const Color(0xFFD48D4D),
      };

  Color badgeBackground({required bool isDark}) {
    final color = tone(isDark: isDark);
    return color.withValues(alpha: isDark ? 0.22 : 0.12);
  }
}



class VersionAnnouncementDialog extends StatelessWidget {
  const VersionAnnouncementDialog({
    super.key,
    required this.version,
    required this.items,
  });

  final String version;
  final List<VersionAnnouncementItem> items;

  static Future<bool?> show(
    BuildContext context, {
    required String version,
    required List<VersionAnnouncementItem> items,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return VersionAnnouncementDialog(version: version, items: items);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.65);
    final accent = MemoFlowPalette.primary;
    final shadow = Colors.black.withValues(alpha: 0.12);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                      color: shadow,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rocket_launch_rounded, size: 48, color: accent),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      zh: '版本公告 v$version',
                      en: 'Release Notes v$version',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _AnnouncementItemRow(
                          item: items[i],
                          textMain: textMain,
                          textMuted: textMuted,
                          isDark: isDark,
                        ),
                        if (i != items.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        context.tr(zh: '知道了', en: 'Got it'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VersionAnnouncementItem {
  const VersionAnnouncementItem({
    required this.category,
    required this.detailZh,
    required this.detailEn,
  });

  final ReleaseNoteCategory category;
  final String detailZh;
  final String detailEn;
}

class VersionAnnouncementEntry {
  const VersionAnnouncementEntry({
    required this.version,
    required this.dateLabel,
    required this.items,
  });

  final String version;
  final String dateLabel;
  final List<VersionAnnouncementItem> items;
}

class VersionAnnouncementContent {
  // Add new releases at the top; older entries stay below for the timeline.
  static const List<VersionAnnouncementEntry> entries = [
    VersionAnnouncementEntry(
      version: '1.0.5',
      dateLabel: '2024-05-20',
      items: [
        VersionAnnouncementItem(
          category: ReleaseNoteCategory.feature,
          detailZh: '第三方分享接入',
          detailEn: 'Third-party share integration',
        ),
        VersionAnnouncementItem(
          category: ReleaseNoteCategory.feature,
          detailZh: '功能组件和赞赏',
          detailEn: 'Feature widgets and donations',
        ),
        VersionAnnouncementItem(
          category: ReleaseNoteCategory.fix,
          detailZh: '编辑时图片无法加载',
          detailEn: 'Images not loading while editing',
        ),
        VersionAnnouncementItem(
          category: ReleaseNoteCategory.fix,
          detailZh: '链接过长无法渲染',
          detailEn: 'Long links not rendering',
        ),
        VersionAnnouncementItem(
          category: ReleaseNoteCategory.improvement,
          detailZh: '进入笔记详情自动展开',
          detailEn: 'Memo details auto-expand',
        ),
        VersionAnnouncementItem(
          category: ReleaseNoteCategory.improvement,
          detailZh: 'AI 设置持久化保存本地',
          detailEn: 'AI settings persist locally',
        ),
      ],
    ),
  ];

  static VersionAnnouncementEntry? entryForVersion(String version) {
    final normalized = version.trim();
    if (entries.isEmpty) return null;
    if (normalized.isEmpty) return entries.first;
    for (final entry in entries) {
      if (entry.version == normalized) return entry;
    }
    return null;
  }

  static List<VersionAnnouncementItem> forVersion(String version) {
    return entryForVersion(version)?.items ?? (entries.isNotEmpty ? entries.first.items : const []);
  }

  static VersionAnnouncementEntry? latestEntry() {
    if (entries.isEmpty) return null;
    return entries.first;
  }

  static List<VersionAnnouncementEntry> allEntries() => entries;
}

class _AnnouncementItemRow extends StatelessWidget {
  const _AnnouncementItemRow({
    required this.item,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
  });

  final VersionAnnouncementItem item;
  final Color textMain;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = item.category.labelWithColon(context);
    final highlight = item.category.tone(isDark: isDark);
    final detail = context.tr(zh: item.detailZh, en: item.detailEn);

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 13.5, height: 1.35, color: textMain),
        children: [
          TextSpan(
            text: title,
            style: TextStyle(fontWeight: FontWeight.w700, color: highlight),
          ),
          TextSpan(text: detail, style: TextStyle(color: textMuted)),
        ],
      ),
    );
  }
}
