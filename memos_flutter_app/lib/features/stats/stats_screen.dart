import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../memos/memos_list_screen.dart';
import '../../state/preferences_provider.dart';
import '../../state/stats_providers.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late DateTime _selectedMonth;
  final _posterBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _backToAllMemos() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.safePop();
      return;
    }
    _backToAllMemos();
  }

  Future<void> _pickMonth(List<DateTime> months) async {
    if (months.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.tr(zh: '选择月份', en: 'Select month')),
                ),
              ),
              ...months.map((m) {
                final label = _formatMonth(m);
                final selected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;
                return ListTile(
                  leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(label),
                  onTap: () {
                    context.safePop();
                    setState(() => _selectedMonth = DateTime(m.year, m.month));
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sharePoster() async {
    final boundary = _posterBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '??????', en: 'Poster is not ready yet'))),
      );
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(2.0, 3.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '??????', en: 'Poster generation failed'))),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}stats_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '?????$e', en: 'Share failed: $e'))),
      );
    }
  }

  Widget _buildSharePoster({
    required LocalStats stats,
    required MonthlyStats monthly,
    required String monthLabel,
    required Map<DateTime, int> lastYear,
    required int lastYearMemos,
    required int currentStreak,
  }) {
    final size = MediaQuery.sizeOf(context);
    final posterBg = const Color(0xFFF9F7F2);
    final card = MemoFlowPalette.cardLight;
    final textMain = MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: 0.6);

    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.light),
      child: RepaintBoundary(
        key: _posterBoundaryKey,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DecoratedBox(
            decoration: BoxDecoration(color: posterBg),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PaperTexturePainter(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'MemoFlow',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: textMain,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr(zh: '记录统计', en: 'Memo stats'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MonthStatsCard(
                        card: card,
                        textMain: textMain,
                        textMuted: textMuted,
                        monthLabel: monthLabel,
                        onPickMonth: null,
                        onShare: null,
                        memos: monthly.totalMemos,
                        chars: monthly.totalChars,
                        maxMemosPerDay: monthly.maxMemosPerDay,
                        maxCharsPerDay: monthly.maxCharsPerDay,
                        activeDays: monthly.activeDays,
                        dailyCounts: _toMonthSeries(DateTime(monthly.year, monthly.month), monthly.dailyCounts),
                      ),
                      const SizedBox(height: 12),
                      _HeatmapCard(
                        card: card,
                        textMain: textMain,
                        textMuted: textMuted,
                        title: context.tr(
                          zh: '最近一年记录 $lastYearMemos 条笔记',
                          en: 'Last year: $lastYearMemos memos',
                        ),
                        onShare: null,
                        dailyCounts: lastYear,
                        isDark: false,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStatCard(
                              card: card,
                              textMain: textMain,
                              textMuted: textMuted,
                              icon: Icons.local_fire_department_outlined,
                              label: context.tr(zh: '当前连击', en: 'Current streak'),
                              value: context.tr(zh: '$currentStreak 天', en: '$currentStreak days'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MiniStatCard(
                              card: card,
                              textMain: textMain,
                              textMuted: textMuted,
                              icon: Icons.calendar_month_outlined,
                              label: context.tr(zh: '累计天数', en: 'Active days'),
                              value: context.tr(zh: '${stats.activeDays} 天', en: '${stats.activeDays} days'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 12,
                  child: Text(
                    context.tr(zh: '由 MemoFlow 生成', en: 'Generated by MemoFlow'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textMuted.withValues(alpha: 0.6),
                      letterSpacing: 0.6,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    final statsAsync = ref.watch(localStatsProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('MemoFlow'),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: context.tr(zh: '返回', en: 'Back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            TextButton(
              onPressed: () {
                final stats = statsAsync.valueOrNull;
                if (stats == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr(zh: '?????', en: 'Stats are loading'))),
                  );
                  return;
                }
                _sharePoster();
              },
              child: Text(
                context.tr(zh: '分享', en: 'Share'),
                style: TextStyle(color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.9 : 1.0)),
              ),
            ),
          ],
        ),
        body: statsAsync.when(
          data: (stats) {
            final months = _deriveMonths(stats.dailyCounts);
            final selected = _selectedMonth;
            final effectiveMonth = months.isNotEmpty && !months.any((m) => m.year == selected.year && m.month == selected.month) ? months.first : selected;
            final monthlyAsync = ref.watch(monthlyStatsProvider((year: effectiveMonth.year, month: effectiveMonth.month)));

            final lastYear = _lastNDaysCounts(stats.dailyCounts, days: 365);
            final lastYearMemos = lastYear.values.fold<int>(0, (sum, v) => sum + v);

            final currentStreak = _currentStreakDays(stats.dailyCounts);

            return monthlyAsync.when(
              data: (monthly) {
                final monthLabel = _formatMonth(DateTime(monthly.year, monthly.month));
                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        Text(
                          context.tr(zh: '记录统计', en: 'Memo stats'),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textMain),
                        ),
                        const SizedBox(height: 12),
                        _MonthStatsCard(
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          monthLabel: monthLabel,
                          onPickMonth: months.isEmpty ? null : () => _pickMonth(months),
                          onShare: _sharePoster,
                          memos: monthly.totalMemos,
                          chars: monthly.totalChars,
                          maxMemosPerDay: monthly.maxMemosPerDay,
                          maxCharsPerDay: monthly.maxCharsPerDay,
                          activeDays: monthly.activeDays,
                          dailyCounts: _toMonthSeries(DateTime(monthly.year, monthly.month), monthly.dailyCounts),
                        ),
                        const SizedBox(height: 14),
                        _HeatmapCard(
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          title: context.tr(
                            zh: '最近一年记录 $lastYearMemos 条笔记',
                            en: 'Last year: $lastYearMemos memos',
                          ),
                          onShare: _sharePoster,
                          dailyCounts: lastYear,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStatCard(
                                card: card,
                                textMain: textMain,
                                textMuted: textMuted,
                                icon: Icons.local_fire_department_outlined,
                                label: context.tr(zh: '当前连击', en: 'Current streak'),
                                value: context.tr(zh: '$currentStreak 天', en: '$currentStreak days'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStatCard(
                                card: card,
                                textMain: textMain,
                                textMuted: textMuted,
                                icon: Icons.calendar_month_outlined,
                                label: context.tr(zh: '累计天数', en: 'Active days'),
                                value: context.tr(zh: '${stats.activeDays} 天', en: '${stats.activeDays} days'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          // Keep opacity above zero so the boundary paints for toImage.
                          opacity: 0.01,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _buildSharePoster(
                              stats: stats,
                              monthly: monthly,
                              monthLabel: monthLabel,
                              lastYear: lastYear,
                              lastYearMemos: lastYearMemos,
                              currentStreak: currentStreak,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
        ),
      ),
    );
  }
}

class _MonthStatsCard extends StatelessWidget {
  const _MonthStatsCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.monthLabel,
    required this.onPickMonth,
    this.onShare,
    required this.memos,
    required this.chars,
    required this.maxMemosPerDay,
    required this.maxCharsPerDay,
    required this.activeDays,
    required this.dailyCounts,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String monthLabel;
  final VoidCallback? onPickMonth;
  final VoidCallback? onShare;
  final int memos;
  final int? chars;
  final int maxMemosPerDay;
  final int? maxCharsPerDay;
  final int activeDays;
  final List<int> dailyCounts;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              _MonthPill(
                label: monthLabel,
                textMuted: textMuted,
                onTap: onPickMonth,
              ),
              const Spacer(),
              if (onShare != null)
                InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onShare,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 16, color: MemoFlowPalette.primary),
                      const SizedBox(width: 6),
                      Text(
                        context.tr(zh: '分享', en: 'Share'),
                        style: TextStyle(fontWeight: FontWeight.w700, color: MemoFlowPalette.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Metric(
                      value: '$memos',
                      label: context.tr(zh: '笔记', en: 'Memos'),
                      textMain: textMain,
                      textMuted: textMuted,
                      big: true,
                    ),
                    const SizedBox(height: 14),
                    _Metric(
                      value: '$maxMemosPerDay',
                      label: context.tr(zh: '单日最多条数', en: 'Max per day'),
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                    const SizedBox(height: 14),
                    _Metric(
                      value: '$activeDays',
                      label: context.tr(zh: '坚持记录天数', en: 'Days with memos'),
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Metric(
                      value: chars == null ? '—' : _formatNumber(chars!),
                      label: context.tr(zh: '字数', en: 'Characters'),
                      textMain: textMain,
                      textMuted: textMuted,
                      big: true,
                    ),
                    const SizedBox(height: 14),
                    _Metric(
                      value: maxCharsPerDay == null ? '—' : _formatNumber(maxCharsPerDay!),
                      label: context.tr(zh: '单日最多字数', en: 'Max chars/day'),
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MonthlyBarChart(
            counts: dailyCounts,
            height: 96,
            textMuted: textMuted,
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({
    required this.counts,
    required this.height,
    required this.textMuted,
  });

  final List<int> counts;
  final double height;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.fold<int>(0, (max, v) => v > max ? v : max);
    final chartMax = math.max(maxCount, 1);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final c in counts)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: _BarDot(
                        count: c,
                        max: chartMax,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Text(
              '$maxCount',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted.withValues(alpha: 0.5)),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              '0',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarDot extends StatelessWidget {
  const _BarDot({required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final has = count > 0;
    final t = (count / max).clamp(0.0, 1.0);
    final barHeight = 72.0 * t;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (has)
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: MemoFlowPalette.primary.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
            ),
          )
        else
          const SizedBox(height: 0),
        const SizedBox(height: 6),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: has
                ? MemoFlowPalette.primary.withValues(alpha: 0.35)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06)),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.label,
    required this.textMuted,
    required this.onTap,
  });

  final String label;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textMuted)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.textMain,
    required this.textMuted,
    this.big = false,
  });

  final String value;
  final String label;
  final Color textMain;
  final Color textMuted;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 26 : 22,
            fontWeight: FontWeight.w900,
            color: textMain,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.title,
    this.onShare,
    required this.dailyCounts,
    required this.isDark,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String title;
  final VoidCallback? onShare;
  final Map<DateTime, int> dailyCounts;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textMain))),
              if (onShare != null)
                InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onShare,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    context.tr(zh: '分享', en: 'Share'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: MemoFlowPalette.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _YearHeatmap(
            dailyCounts: dailyCounts,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _monthLabels(dailyCounts.keys)
                .map((m) {
                  final label = context.appLanguage == AppLanguage.en
                      ? DateFormat.MMM(Localizations.localeOf(context).toString()).format(DateTime(2000, m.month))
                      : '${m.month}\u6708';
                  return Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted.withValues(alpha: 0.35)),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Iterable<DateTime> _monthLabels(Iterable<DateTime> days) {
    if (days.isEmpty) {
      final now = DateTime.now();
      return [DateTime(now.year, now.month)];
    }
    final sorted = days.toList()..sort();
    final start = sorted.first;
    final end = sorted.last;
    final points = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      final t = i / 6.0;
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (start.millisecondsSinceEpoch + (end.millisecondsSinceEpoch - start.millisecondsSinceEpoch) * t).round(),
        isUtc: true,
      ).toLocal();
      points.add(DateTime(dt.year, dt.month));
    }
    return points;
  }
}

class _YearHeatmap extends StatelessWidget {
  const _YearHeatmap({
    required this.dailyCounts,
    required this.isDark,
  });

  final Map<DateTime, int> dailyCounts;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const weeks = 52;
    const daysPerWeek = 7;

    final todayLocal = DateTime.now();
    final endUtc = DateTime.utc(todayLocal.year, todayLocal.month, todayLocal.day);
    final startUtc = endUtc.subtract(const Duration(days: weeks * daysPerWeek - 1));
    final alignedStart = startUtc.subtract(Duration(days: startUtc.weekday - 1));

    final maxCount = dailyCounts.values.fold<int>(0, (max, v) => v > max ? v : max);

    Color colorFor(int c) {
      if (c <= 0) return isDark ? const Color(0xFF262626) : Colors.black.withValues(alpha: 0.05);
      final t = maxCount <= 0 ? 0.0 : (c / maxCount).clamp(0.0, 1.0);
      if (t <= 0.33) return MemoFlowPalette.primary.withValues(alpha: isDark ? 0.45 : 0.25);
      if (t <= 0.66) return MemoFlowPalette.primary.withValues(alpha: isDark ? 0.7 : 0.55);
      return MemoFlowPalette.primary.withValues(alpha: 0.95);
    }

    final cells = <DateTime>[];
    for (var row = 0; row < daysPerWeek; row++) {
      for (var col = 0; col < weeks; col++) {
        cells.add(alignedStart.add(Duration(days: col * daysPerWeek + row)));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 3.0;
        final cellSize = ((constraints.maxWidth - spacing * (weeks - 1)) / weeks).clamp(3.0, 8.0);
        return SizedBox(
          height: cellSize * daysPerWeek + spacing * (daysPerWeek - 1),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: weeks,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 1,
            ),
            itemCount: weeks * daysPerWeek,
            itemBuilder: (context, index) {
              final day = cells[index];
              if (day.isAfter(endUtc)) {
                return const SizedBox.shrink();
              }
              final count = dailyCounts[day] ?? 0;
              return Container(
                decoration: BoxDecoration(
                  color: colorFor(count),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 18, color: MemoFlowPalette.primary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textMain)),
        ],
      ),
    );
  }
}

List<DateTime> _deriveMonths(Map<DateTime, int> dailyCounts) {
  final set = <DateTime>{};
  for (final d in dailyCounts.keys) {
    final local = d.toLocal();
    set.add(DateTime(local.year, local.month));
  }
  final list = set.toList();
  list.sort((a, b) => b.compareTo(a));
  return list;
}

Map<DateTime, int> _lastNDaysCounts(Map<DateTime, int> dailyCounts, {required int days}) {
  final todayLocal = DateTime.now();
  final endUtc = DateTime.utc(todayLocal.year, todayLocal.month, todayLocal.day);
  final startUtc = endUtc.subtract(Duration(days: days - 1));
  return {
    for (final e in dailyCounts.entries)
      if (!e.key.isBefore(startUtc) && !e.key.isAfter(endUtc)) e.key: e.value,
  };
}

List<int> _toMonthSeries(DateTime selected, Map<DateTime, int> counts) {
  final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
  final list = List<int>.filled(daysInMonth, 0);
  for (final entry in counts.entries) {
    final local = entry.key.toLocal();
    if (local.year != selected.year || local.month != selected.month) continue;
    final idx = local.day - 1;
    if (idx >= 0 && idx < list.length) {
      list[idx] += entry.value;
    }
  }
  return list;
}

int _currentStreakDays(Map<DateTime, int> dailyCounts) {
  final todayLocal = DateTime.now();
  var day = DateTime.utc(todayLocal.year, todayLocal.month, todayLocal.day);
  var streak = 0;
  while (true) {
    final c = dailyCounts[day] ?? 0;
    if (c <= 0) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

String _formatMonth(DateTime month) => '${month.year}-${month.month.toString().padLeft(2, '0')}';

String _formatNumber(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idxFromEnd = s.length - i;
    buf.write(s[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
      buf.write(',');
    }
  }
  return buf.toString();
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter({this.seed = 37});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final base = const Color(0xFFB7AEA1);
    final area = size.width * size.height;
    final dotCount = (area / 3600).clamp(180, 900).toInt();

    for (var i = 0; i < dotCount; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 0.7 + 0.2;
      final alpha = 0.02 + rand.nextDouble() * 0.05;
      final paint = Paint()..color = base.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }

    final linePaint = Paint()
      ..color = base.withValues(alpha: 0.04)
      ..strokeWidth = 0.6;
    final lineCount = (size.height / 14).clamp(24, 120).toInt();
    for (var i = 0; i < lineCount; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final length = size.width * (0.08 + rand.nextDouble() * 0.18);
      final angle = (rand.nextDouble() - 0.5) * 0.12;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawLine(Offset.zero, Offset(length, 0), linePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) => false;
}
