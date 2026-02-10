import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';
import '../../data/updates/update_config.dart';
import '../../i18n/strings.g.dart';

enum ReleaseNoteCategory {
  feature,
  improvement,
  fix,
}

extension ReleaseNoteCategoryX on ReleaseNoteCategory {
  String label(BuildContext context) => switch (this) {
        ReleaseNoteCategory.feature => context.t.strings.legacy.msg_text_3,
        ReleaseNoteCategory.improvement => context.t.strings.legacy.msg_improved,
        ReleaseNoteCategory.fix => context.t.strings.legacy.msg_fixed_2,
      };

  String labelWithColon(BuildContext context) => switch (this) {
        ReleaseNoteCategory.feature => context.t.strings.legacy.msg_text_2,
        ReleaseNoteCategory.improvement => context.t.strings.legacy.msg_improved_2,
        ReleaseNoteCategory.fix => context.t.strings.legacy.msg_fixed,
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
                    context.t.strings.legacy.msg_release_notes_v(version: version),
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
                        context.t.strings.legacy.msg_got,
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

extension VersionAnnouncementItemLocalizationX on VersionAnnouncementItem {
  String localizedDetail(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode.toLowerCase();
    return languageCode == 'zh' ? detailZh : detailEn;
  }
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

List<VersionAnnouncementEntry> buildVersionAnnouncementEntries(List<UpdateReleaseNoteEntry> entries) {
  return entries
      .map(buildVersionAnnouncementEntry)
      .whereType<VersionAnnouncementEntry>()
      .toList(growable: false);
}

VersionAnnouncementEntry? buildVersionAnnouncementEntry(UpdateReleaseNoteEntry entry) {
  final version = entry.version.trim();
  if (version.isEmpty && entry.items.isEmpty) return null;
  return VersionAnnouncementEntry(
    version: version,
    dateLabel: entry.dateLabel,
    items: buildVersionAnnouncementItems(entry),
  );
}

VersionAnnouncementEntry? findVersionAnnouncementEntry(
  List<UpdateReleaseNoteEntry> entries,
  String version,
) {
  final normalized = _normalizeReleaseNoteVersion(version);
  if (normalized.isEmpty) return null;
  for (final entry in entries) {
    if (_normalizeReleaseNoteVersion(entry.version) == normalized) {
      return buildVersionAnnouncementEntry(entry);
    }
  }
  return null;
}

List<VersionAnnouncementItem> buildVersionAnnouncementItems(UpdateReleaseNoteEntry? entry) {
  if (entry == null) return const [];
  final items = <VersionAnnouncementItem>[];
  for (final item in entry.items) {
    final content = item.content.trim();
    if (content.isEmpty) continue;
    items.add(
      VersionAnnouncementItem(
        category: parseReleaseNoteCategory(item.category),
        detailZh: content,
        detailEn: content,
      ),
    );
  }
  return items;
}

ReleaseNoteCategory parseReleaseNoteCategory(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return ReleaseNoteCategory.feature;
  if (normalized.contains('新增') || normalized.contains('feature') || normalized.contains('new')) {
    return ReleaseNoteCategory.feature;
  }
  if (normalized.contains('优化') ||
      normalized.contains('improve') ||
      normalized.contains('perf') ||
      normalized.contains('performance')) {
    return ReleaseNoteCategory.improvement;
  }
  if (normalized.contains('修复') || normalized.contains('fix') || normalized.contains('bug')) {
    return ReleaseNoteCategory.fix;
  }
  return ReleaseNoteCategory.feature;
}

String _normalizeReleaseNoteVersion(String version) {
  final trimmed = version.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length >= 2 && (trimmed[0] == 'v' || trimmed[0] == 'V')) {
    return trimmed.substring(1);
  }
  return trimmed;
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
    final detail = item.localizedDetail(context);

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
