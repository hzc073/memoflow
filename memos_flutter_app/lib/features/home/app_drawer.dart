import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/memos_providers.dart';
import '../../state/session_provider.dart';
import '../../state/stats_providers.dart';

enum AppDrawerDestination {
  memos,
  dailyReview,
  aiSummary,
  archived,
  tags,
  resources,
  stats,
  settings,
  about,
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    this.onSelectTag,
  });

  final AppDrawerDestination selected;
  final ValueChanged<AppDrawerDestination> onSelect;
  final ValueChanged<String>? onSelectTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.85, 320.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final title = (account?.user.displayName.isNotEmpty ?? false)
        ? account!.user.displayName
        : (account?.user.name.isNotEmpty ?? false)
            ? account!.user.name
            : 'MemoFlow';

    final statsAsync = ref.watch(localStatsProvider);
    final tagsAsync = ref.watch(tagStatsProvider);

    final bg = isDark ? const Color(0xFF181818) : MemoFlowPalette.backgroundLight;
    final textMain = isDark ? const Color(0xFFD1D1D1) : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.4 : 0.5);
    final hover = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

    return Drawer(
      width: width,
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: textMain,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '通知',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通知：待实现')));
                        },
                        icon: Icon(Icons.notifications, color: textMuted),
                      ),
                      IconButton(
                        tooltip: '设置',
                        onPressed: () => onSelect(AppDrawerDestination.settings),
                        icon: Icon(Icons.settings, color: textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  statsAsync.when(
                    data: (stats) {
                      final tagCount = tagsAsync.valueOrNull?.length ?? 0;
                      return Row(
                        children: [
                          Expanded(child: _DrawerStat(value: '${stats.totalMemos}', label: '笔记', textMain: textMain, textMuted: textMuted)),
                          Expanded(child: _DrawerStat(value: '$tagCount', label: '标签', textMain: textMain, textMuted: textMuted)),
                          Expanded(child: _DrawerStat(value: '${stats.daysSinceFirstMemo}', label: '天', textMain: textMain, textMuted: textMuted)),
                        ],
                      );
                    },
                    loading: () => Row(
                      children: [
                        Expanded(child: _DrawerStat(value: '—', label: '笔记', textMain: textMain, textMuted: textMuted)),
                        Expanded(child: _DrawerStat(value: '—', label: '标签', textMain: textMain, textMuted: textMuted)),
                        Expanded(child: _DrawerStat(value: '—', label: '天', textMain: textMain, textMuted: textMuted)),
                      ],
                    ),
                    error: (e, _) => Text('统计加载失败：$e', style: TextStyle(color: textMuted)),
                  ),
                  const SizedBox(height: 14),
                  statsAsync.when(
                    data: (stats) => _DrawerHeatmap(
                      dailyCounts: stats.dailyCounts,
                      isDark: isDark,
                    ),
                    loading: () => const SizedBox(height: 84),
                    error: (_, _) => const SizedBox(height: 84),
                  ),
                  const SizedBox(height: 16),
                  _NavButton(
                    selected: selected == AppDrawerDestination.memos,
                    label: '全部笔记',
                    icon: Icons.grid_view,
                    onTap: () => onSelect(AppDrawerDestination.memos),
                    textMain: textMain,
                    hover: hover,
                  ),
                  _NavButton(
                    selected: selected == AppDrawerDestination.dailyReview,
                    label: '每日回顾',
                    icon: Icons.auto_awesome,
                    onTap: () => onSelect(AppDrawerDestination.dailyReview),
                    textMain: textMain,
                    hover: hover,
                  ),
                  _NavButton(
                    selected: selected == AppDrawerDestination.aiSummary,
                    label: 'AI 总结',
                    icon: Icons.track_changes,
                    onTap: () => onSelect(AppDrawerDestination.aiSummary),
                    textMain: textMain,
                    hover: hover,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '全部标签',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: textMuted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '筛选',
                        onPressed: () => onSelect(AppDrawerDestination.tags),
                        icon: Icon(Icons.tune, color: textMuted, size: 20),
                      ),
                    ],
                  ),
                  tagsAsync.when(
                    data: (tags) {
                      if (tags.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('暂无标签', style: TextStyle(color: textMuted)),
                        );
                      }
                      final preview = tags.take(4).toList(growable: false);
                      return Column(
                        children: [
                          for (final t in preview)
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                final cb = onSelectTag;
                                if (cb != null) {
                                  cb(t.tag);
                                } else {
                                  onSelect(AppDrawerDestination.tags);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.tag, size: 20, color: textMuted),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(t.tag, style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
                                    ),
                                    Icon(Icons.chevron_right, color: textMuted),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('加载中…', style: TextStyle(color: textMuted)),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('标签加载失败：$e', style: TextStyle(color: textMuted)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08)),
                  const SizedBox(height: 8),
                  _BottomNavRow(
                    label: '回收站',
                    icon: Icons.delete,
                    onTap: () => onSelect(AppDrawerDestination.archived),
                    textColor: textMain.withValues(alpha: isDark ? 0.6 : 0.7),
                    hover: hover,
                  ),
                  _BottomNavRow(
                    label: '关于',
                    icon: Icons.info,
                    onTap: () => onSelect(AppDrawerDestination.about),
                    textColor: textMain.withValues(alpha: isDark ? 0.6 : 0.7),
                    hover: hover,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: Container(
                width: 128,
                height: 6,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerStat extends StatelessWidget {
  const _DrawerStat({
    required this.value,
    required this.label,
    required this.textMain,
    required this.textMuted,
  });

  final String value;
  final String label;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textMain)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.textMain,
    required this.hover,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color textMain;
  final Color hover;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? MemoFlowPalette.primary : Colors.transparent;
    final fg = selected ? Colors.white : textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: selected ? Colors.white.withValues(alpha: 0.12) : null,
          hoverColor: selected ? null : hover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavRow extends StatelessWidget {
  const _BottomNavRow({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.textColor,
    required this.hover,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color textColor;
  final Color hover;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          hoverColor: hover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerHeatmap extends StatelessWidget {
  const _DrawerHeatmap({
    required this.dailyCounts,
    required this.isDark,
  });

  final Map<DateTime, int> dailyCounts;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // 18 weeks x 7 days grid.
    const weeks = 18;
    const daysPerWeek = 7;

    final todayLocal = DateTime.now();
    final endUtc = DateTime.utc(todayLocal.year, todayLocal.month, todayLocal.day);
    final startUtc = endUtc.subtract(const Duration(days: weeks * daysPerWeek - 1));
    final alignedStart = startUtc.subtract(Duration(days: startUtc.weekday - 1));

    final maxCount = dailyCounts.values.fold<int>(0, (max, v) => v > max ? v : max);

    Color colorFor(int c) {
      if (c <= 0) return isDark ? const Color(0xFF262626) : Colors.black.withValues(alpha: 0.05);
      final t = maxCount <= 0 ? 0.0 : (c / maxCount).clamp(0.0, 1.0);

      if (isDark) {
        if (t <= 0.33) return const Color(0xFF4A4A4A);
        if (t <= 0.66) return const Color(0xFFC0564D);
        return const Color(0xFFE0665B);
      }

      if (t <= 0.25) return const Color(0xFFD1D8C4);
      if (t <= 0.5) return const Color(0xFFA3AD90);
      if (t <= 0.75) return const Color(0xFFD88B83);
      return MemoFlowPalette.primary;
    }

    final todayUtc = endUtc;

    final cells = <DateTime>[];
    for (var row = 0; row < daysPerWeek; row++) {
      for (var col = 0; col < weeks; col++) {
        final day = alignedStart.add(Duration(days: col * daysPerWeek + row));
        cells.add(day);
      }
    }

    String monthLabel(DateTime d) => '${d.toLocal().month}月';
    final mid = alignedStart.add(const Duration(days: (weeks * daysPerWeek) ~/ 2));
    final late = alignedStart.add(const Duration(days: (weeks * daysPerWeek) - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: weeks,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemCount: weeks * daysPerWeek,
          itemBuilder: (context, index) {
            final day = cells[index];
            final count = dailyCounts[day] ?? 0;
            final isToday = day == todayUtc;
            final color = colorFor(count);
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                border: isToday ? Border.all(color: isDark ? const Color(0xFFE0665B) : MemoFlowPalette.primary, width: 1) : null,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(monthLabel(alignedStart), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: (isDark ? const Color(0xFFD1D1D1) : MemoFlowPalette.textLight).withValues(alpha: 0.35))),
            Text(monthLabel(mid), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: (isDark ? const Color(0xFFD1D1D1) : MemoFlowPalette.textLight).withValues(alpha: 0.35))),
            Text(monthLabel(late), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: (isDark ? const Color(0xFFD1D1D1) : MemoFlowPalette.textLight).withValues(alpha: 0.35))),
          ],
        ),
      ],
    );
  }
}
