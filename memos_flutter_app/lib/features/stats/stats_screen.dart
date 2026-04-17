import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/local_memo.dart';
import '../../features/collections/add_to_collection_sheet.dart';
import '../../features/reminders/memo_reminder_editor_screen.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/settings/resolved_preferences_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../memos/memo_editor_screen.dart';
import '../memos/memo_markdown.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memo_versions_screen.dart';
import '../memos/memos_list_memo_action_delegate.dart';
import '../memos/memos_list_mutation_coordinator.dart';
import '../memos/memos_list_screen.dart';
import '../memos/widgets/memos_list_memo_card.dart';
import '../memos/widgets/memos_list_memo_card_container.dart';
import '../sync/sync_queue_screen.dart';
import '../../state/memos/stats_providers.dart';
import '../../i18n/strings.g.dart';

enum _StatsScreenView { data, calendar }

final _calendarDayMemosProvider =
    StreamProvider.family<List<LocalMemo>, DateTime>((ref, day) async* {
      final db = ref.watch(databaseProvider);
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final nextDay = DateTime(day.year, day.month, day.day + 1);

      Future<List<LocalMemo>> load() async {
        final sqlite = await db.db;
        final startSec = normalizedDay.toUtc().millisecondsSinceEpoch ~/ 1000;
        final endSec = nextDay.toUtc().millisecondsSinceEpoch ~/ 1000;
        final rows = await sqlite.query(
          'memos',
          where: "state = 'NORMAL' AND create_time >= ? AND create_time < ?",
          whereArgs: [startSec, endSec],
          orderBy: 'pinned DESC, create_time DESC',
        );
        return rows.map(LocalMemo.fromDb).toList(growable: false);
      }

      yield await load();
      await for (final _ in db.changes) {
        yield await load();
      }
    });

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late DateTime _selectedMonth;
  DateTime? _selectedDay;
  _StatsScreenView _selectedView = _StatsScreenView.data;
  final _posterBoundaryKey = GlobalKey();
  final ValueNotifier<Duration> _idleAudioPosition = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration?> _idleAudioDuration = ValueNotifier(null);
  final Map<String, GlobalKey<MemoListCardState>> _calendarMemoCardKeys =
      <String, GlobalKey<MemoListCardState>>{};
  late final MemosListMutationCoordinator _memoMutationCoordinator;
  late final MemosListMemoActionDelegate _memoActionDelegate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _memoMutationCoordinator = MemosListMutationCoordinator(read: ref.read);
    _memoActionDelegate = MemosListMemoActionDelegate(
      contextResolver: () => context,
      mutationCoordinator: _memoMutationCoordinator,
      onRetryOpenSyncQueue: (_) => _openSyncQueue(),
      confirmDelete: _confirmDeleteMemo,
      removeMemoWithAnimation: (_) {},
      invalidateMemoRenderCache: invalidateMemoRenderCacheForUid,
      invalidateMemoMarkdownCache: invalidateMemoMarkdownCacheForUid,
      openEditor: _openMemoEditor,
      openHistory: _openMemoHistory,
      openReminder: _openMemoReminder,
      openAddToCollection: _openAddMemoToCollection,
      handleRestoreSuccess: (toastMessage) async {
        if (!mounted) return;
        showTopToast(context, toastMessage);
      },
      showTopToast: (message) {
        if (!mounted) return;
        showTopToast(context, message);
      },
      showSnackBar: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  void dispose() {
    _idleAudioPosition.dispose();
    _idleAudioDuration.dispose();
    _memoMutationCoordinator.dispose();
    super.dispose();
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

  Future<void> _openSyncQueue() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SyncQueueScreen()));
  }

  Future<bool> _confirmDeleteMemo(LocalMemo memo) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_delete_memo),
            content: Text(
              context
                  .t
                  .strings
                  .legacy
                  .msg_removed_locally_now_deleted_server_when,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.t.strings.legacy.msg_delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openMemoEditor(LocalMemo memo) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MemoEditorScreen(existing: memo)),
    );
  }

  Future<void> _openMemoHistory(LocalMemo memo) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoVersionsScreen(memoUid: memo.uid),
      ),
    );
  }

  Future<void> _openMemoReminder(LocalMemo memo) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoReminderEditorScreen(memo: memo),
      ),
    );
  }

  Future<void> _openAddMemoToCollection(LocalMemo memo) async {
    await showAddMemoToCollectionSheet(context: context, ref: ref, memo: memo);
  }

  Future<void> _handleCalendarMemoToggleTask(LocalMemo memo, int index) async {
    final prefs = ref
        .read(resolvedAppSettingsProvider)
        .toLegacyAppPreferences();
    await _memoActionDelegate.toggleMemoCheckbox(
      memo,
      index,
      skipQuotedLines: prefs.collapseReferences,
    );
  }

  Future<void> _handleCalendarMemoSyncStatusTap(
    LocalMemo memo,
    MemoSyncStatus status,
  ) async {
    await _memoActionDelegate.handleMemoSyncStatusTap(status, memo.uid);
  }

  Future<void> _handleCalendarMemoAction(
    LocalMemo memo,
    MemoCardAction action,
  ) async {
    await _memoActionDelegate.handleMemoAction(memo, action);
  }

  void _openMemoDetail(LocalMemo memo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoDetailScreen(initialMemo: memo),
      ),
    );
  }

  Future<void> _pickMonth(List<DateTime> months) async {
    if (months.isEmpty) return;
    final firstDate = DateTime(months.last.year, months.last.month, 1);
    final lastMonth = months.first;
    final lastDate = DateTime(lastMonth.year, lastMonth.month + 1, 0);
    final candidate = _selectedDay ?? _selectedMonth;
    final initialDate = _clampDateToRange(
      DateTime(candidate.year, candidate.month, math.max(candidate.day, 1)),
      firstDate,
      lastDate,
    );
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: MemoFlowPalette.primary,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    _setSelectedDay(picked);
  }

  Future<XFile?> _capturePosterFile() async {
    final boundary = _posterBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      showTopToast(context, context.t.strings.legacy.msg_poster_not_ready_yet);
      return null;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return null;
      final pixelRatio = MediaQuery.of(
        context,
      ).devicePixelRatio.clamp(2.0, 3.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_poster_generation_failed,
            ),
          ),
        );
        return null;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}stats_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return XFile(file.path);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_share_failed(e: e)),
        ),
      );
      return null;
    }
  }

  Future<void> _sharePoster() async {
    final file = await _capturePosterFile();
    if (file == null || !mounted) return;
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  Future<void> _shareStatsPoster() async {
    final previousView = _selectedView;
    if (previousView == _StatsScreenView.data) {
      await _sharePoster();
      return;
    }

    if (previousView != _StatsScreenView.data) {
      setState(() => _selectedView = _StatsScreenView.data);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    final file = await _capturePosterFile();
    if (!mounted) return;

    if (previousView != _StatsScreenView.data) {
      setState(() => _selectedView = previousView);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (file == null) return;
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  GlobalKey<MemoListCardState> _calendarMemoCardKeyForUid(String memoUid) {
    return _calendarMemoCardKeys.putIfAbsent(
      memoUid,
      () => GlobalKey<MemoListCardState>(debugLabel: 'stats-calendar-$memoUid'),
    );
  }

  void _setSelectedMonth(DateTime month) {
    final normalized = DateTime(month.year, month.month);
    if (_sameMonth(_selectedMonth, normalized)) return;
    setState(() => _selectedMonth = normalized);
  }

  void _setSelectedDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final normalizedMonth = DateTime(normalizedDay.year, normalizedDay.month);
    if (DateUtils.isSameDay(_selectedDay, normalizedDay) &&
        _sameMonth(_selectedMonth, normalizedMonth)) {
      return;
    }
    setState(() {
      _selectedDay = normalizedDay;
      _selectedMonth = normalizedMonth;
    });
  }

  void _setSelectedView(_StatsScreenView view) {
    if (_selectedView == view) return;
    setState(() => _selectedView = view);
  }

  void _selectAdjacentMonth(
    List<DateTime> months,
    DateTime currentMonth, {
    required bool previous,
  }) {
    final currentIndex = months.indexWhere(
      (month) => _sameMonth(month, currentMonth),
    );
    if (currentIndex < 0) return;
    final targetIndex = previous ? currentIndex + 1 : currentIndex - 1;
    if (targetIndex < 0 || targetIndex >= months.length) return;
    _setSelectedMonth(months[targetIndex]);
  }

  DateTime _resolveSelectedCalendarDay(
    DateTime month,
    Map<DateTime, int> dailyCounts,
  ) {
    final explicit = _selectedDay;
    if (explicit != null && _sameMonth(explicit, month)) {
      return DateTime(explicit.year, explicit.month, explicit.day);
    }

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    if (_sameMonth(normalizedToday, month)) {
      return normalizedToday;
    }

    final activeDays =
        dailyCounts.entries
            .where((entry) => entry.value > 0)
            .map((entry) => entry.key.toLocal())
            .map((day) => DateTime(day.year, day.month, day.day))
            .where((day) => _sameMonth(day, month))
            .toList(growable: false)
          ..sort();
    if (activeDays.isNotEmpty) {
      return activeDays.last;
    }

    return DateTime(month.year, month.month, 1);
  }

  Widget _buildDataStatsContent({
    required BoxConstraints constraints,
    required List<DateTime> months,
    required String monthTitle,
    required String monthLabel,
    required MonthlyStats monthly,
    required _MonthGrowthSummaryNew growth,
    required String trendMonthLabel,
    required DateTime monthDate,
    required List<int> daySeries,
    required Map<DateTime, int> lastYear,
    required AnnualInsights annual,
    required List<_MetricItemNew> bottomItems,
    required List<_MetricItemNew> additionalBottomItems,
    required Color card,
    required Color textMain,
    required Color textMuted,
    required bool isDark,
  }) {
    final isDesktop = constraints.maxWidth >= 980;
    final onPickMonth = months.isEmpty ? null : () => _pickMonth(months);
    final annualRowHeight = ((constraints.maxWidth - 14) * 0.28)
        .clamp(200.0, 260.0)
        .toDouble();
    final annualTrendHeight = ((constraints.maxWidth - 14) * 0.12)
        .clamp(120.0, 150.0)
        .toDouble();
    final headerChildren = <Widget>[
      Text(
        context.t.strings.legacy.msg_memo_stats,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textMain,
        ),
      ),
      const SizedBox(height: 12),
      _StatsViewModeToggle(
        selectedView: _selectedView,
        onChanged: _setSelectedView,
        textMain: textMain,
        textMuted: textMuted,
      ),
    ];

    if (isDesktop) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ...headerChildren,
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 35,
                child: _MonthlyOverviewCardNew(
                  card: card,
                  textMain: textMain,
                  textMuted: textMuted,
                  title: monthTitle,
                  monthLabel: monthLabel,
                  onPickMonth: onPickMonth,
                  memos: monthly.totalMemos,
                  chars: monthly.totalChars,
                  maxMemosPerDay: monthly.maxMemosPerDay,
                  maxCharsPerDay: monthly.maxCharsPerDay,
                  growth: growth,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 65,
                child: _DailyTrendCardNew(
                  card: card,
                  textMain: textMain,
                  textMuted: textMuted,
                  monthLabel: trendMonthLabel,
                  month: monthDate,
                  counts: daySeries,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: annualRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 66,
                  child: _HeatmapCard(
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    title: '\u5e74\u5ea6\u7b14\u8bb0\u70ed\u529b\u56fe',
                    dailyCounts: lastYear,
                    isDark: isDark,
                    compact: false,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 34,
                  child: _AnnualInsightsCardNew(
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    insights: annual,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: annualTrendHeight,
            child: _YearCharsTrendCardNew(
              card: card,
              textMain: textMain,
              textMuted: textMuted,
              points: annual.monthlyChars,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 14),
          _BottomMetricRowNew(
            items: bottomItems,
            card: card,
            textMain: textMain,
            textMuted: textMuted,
          ),
          const SizedBox(height: 12),
          _BottomMetricRowNew(
            items: additionalBottomItems,
            card: card,
            textMain: textMain,
            textMuted: textMuted,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        ...headerChildren,
        const SizedBox(height: 12),
        _MonthlyOverviewCardNew(
          card: card,
          textMain: textMain,
          textMuted: textMuted,
          title: monthTitle,
          monthLabel: monthLabel,
          onPickMonth: onPickMonth,
          memos: monthly.totalMemos,
          chars: monthly.totalChars,
          maxMemosPerDay: monthly.maxMemosPerDay,
          maxCharsPerDay: monthly.maxCharsPerDay,
          growth: growth,
        ),
        const SizedBox(height: 12),
        _DailyTrendCardNew(
          card: card,
          textMain: textMain,
          textMuted: textMuted,
          monthLabel: trendMonthLabel,
          month: monthDate,
          counts: daySeries,
        ),
        const SizedBox(height: 12),
        _HeatmapCard(
          card: card,
          textMain: textMain,
          textMuted: textMuted,
          title: '\u5e74\u5ea6\u7b14\u8bb0\u70ed\u529b\u56fe',
          dailyCounts: lastYear,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _YearCharsTrendCardNew(
          card: card,
          textMain: textMain,
          textMuted: textMuted,
          points: annual.monthlyChars,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _AnnualInsightsCardNew(
          card: card,
          textMain: textMain,
          textMuted: textMuted,
          insights: annual,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _BottomMetricWrapNew(
          items: [...bottomItems, ...additionalBottomItems],
          card: card,
          textMain: textMain,
          textMuted: textMuted,
        ),
      ],
    );
  }

  Widget _buildCalendarStatsContent({
    required BoxConstraints constraints,
    required List<DateTime> months,
    required DateTime monthDate,
    required MonthlyStats monthly,
    required Color card,
    required Color textMain,
    required Color textMuted,
  }) {
    final isDesktop = constraints.maxWidth >= 980;
    final monthIndex = months.indexWhere(
      (month) => _sameMonth(month, monthDate),
    );
    final canGoPrevious = monthIndex >= 0 && monthIndex < months.length - 1;
    final canGoNext = monthIndex > 0;
    final onPickMonth = months.isEmpty ? null : () => _pickMonth(months);
    final selectedDay = _resolveSelectedCalendarDay(
      monthDate,
      monthly.dailyCounts,
    );
    final selectedDayMemosAsync = ref.watch(
      _calendarDayMemosProvider(selectedDay),
    );
    final outboxStatus =
        ref.watch(memosListOutboxStatusProvider).valueOrNull ??
        const OutboxMemoStatus.empty();
    final prefs = ref
        .watch(resolvedAppSettingsProvider)
        .toLegacyAppPreferences();
    final tagColors = ref.watch(tagColorLookupProvider);
    final headerChildren = <Widget>[
      Text(
        context.t.strings.legacy.msg_memo_stats,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textMain,
        ),
      ),
      const SizedBox(height: 12),
      _StatsViewModeToggle(
        selectedView: _selectedView,
        onChanged: _setSelectedView,
        textMain: textMain,
        textMuted: textMuted,
      ),
      const SizedBox(height: 12),
    ];
    final calendarCard = _CalendarMonthCard(
      card: card,
      textMain: textMain,
      textMuted: textMuted,
      month: monthDate,
      dailyCounts: monthly.dailyCounts,
      selectedDay: selectedDay,
      onPickMonth: onPickMonth,
      onSelectDay: _setSelectedDay,
      onPreviousMonth: canGoPrevious
          ? () => _selectAdjacentMonth(months, monthDate, previous: true)
          : null,
      onNextMonth: canGoNext
          ? () => _selectAdjacentMonth(months, monthDate, previous: false)
          : null,
    );
    final selectedDaySection = _CalendarSelectedDaySection(
      selectedDay: selectedDay,
      dayMemosAsync: selectedDayMemosAsync,
      memoCardKeyForUid: _calendarMemoCardKeyForUid,
      prefs: prefs,
      outboxStatus: outboxStatus,
      tagColors: tagColors,
      audioPositionListenable: _idleAudioPosition,
      audioDurationListenable: _idleAudioDuration,
      onOpenMemo: _openMemoDetail,
      onToggleTask: _handleCalendarMemoToggleTask,
      onSyncStatusTap: _handleCalendarMemoSyncStatusTap,
      onAction: _handleCalendarMemoAction,
      textMain: textMain,
      textMuted: textMuted,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 16 : 12,
        0,
        isDesktop ? 16 : 12,
        24,
      ),
      children: [
        ...headerChildren,
        calendarCard,
        const SizedBox(height: 16),
        selectedDaySection,
      ],
    );
  }

  // ignore: unused_element
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
                  child: CustomPaint(painter: _PaperTexturePainter()),
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
                            context.t.strings.legacy.msg_memo_stats,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textMuted,
                            ),
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
                        dailyCounts: _toMonthSeries(
                          DateTime(monthly.year, monthly.month),
                          monthly.dailyCounts,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HeatmapCard(
                        card: card,
                        textMain: textMain,
                        textMuted: textMuted,
                        title: context.t.strings.legacy.msg_last_year_memos(
                          lastYearMemos: lastYearMemos,
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
                              label:
                                  context.t.strings.legacy.msg_current_streak,
                              value: context.t.strings.legacy.msg_days_3(
                                currentStreak: currentStreak,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MiniStatCard(
                              card: card,
                              textMain: textMain,
                              textMuted: textMuted,
                              icon: Icons.calendar_month_outlined,
                              label: context.t.strings.legacy.msg_active_days,
                              value: context.t.strings.legacy.msg_days(
                                stats_activeDays: stats.activeDays,
                              ),
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
                    context.t.strings.legacy.msg_generated_memoflow,
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
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final enableWindowsDragToMove =
        Theme.of(context).platform == TargetPlatform.windows;

    final statsAsync = ref.watch(localStatsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          flexibleSpace: enableWindowsDragToMove
              ? const DragToMoveArea(child: SizedBox.expand())
              : null,
          title: IgnorePointer(
            ignoring: enableWindowsDragToMove,
            child: const Text('MemoFlow'),
          ),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: widget.showBackButton,
          leading: widget.showBackButton
              ? IconButton(
                  tooltip: context.t.strings.legacy.msg_back,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBack,
                )
              : null,
          actions: [
            TextButton(
              onPressed: () async {
                final stats = statsAsync.valueOrNull;
                if (stats == null) {
                  showTopToast(
                    context,
                    context.t.strings.legacy.msg_stats_loading,
                  );
                  return;
                }
                await _shareStatsPoster();
              },
              child: Text(
                context.t.strings.legacy.msg_share,
                style: TextStyle(
                  color: MemoFlowPalette.primary.withValues(
                    alpha: isDark ? 0.9 : 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: statsAsync.when(
          data: (stats) {
            final months = _deriveMonths(stats.dailyCounts);
            final selected = _selectedMonth;
            final effectiveMonth =
                months.isNotEmpty &&
                    !months.any(
                      (m) =>
                          m.year == selected.year && m.month == selected.month,
                    )
                ? months.first
                : selected;

            final monthlyKey = (
              year: effectiveMonth.year,
              month: effectiveMonth.month,
            );
            final previousMonth = DateTime(
              effectiveMonth.year,
              effectiveMonth.month - 1,
              1,
            );
            final previousKey = (
              year: previousMonth.year,
              month: previousMonth.month,
            );

            final monthlyAsync = ref.watch(monthlyStatsProvider(monthlyKey));
            final previousAsync = ref.watch(monthlyStatsProvider(previousKey));
            final annualAsync = ref.watch(annualInsightsProvider(monthlyKey));
            final writingHourAsync = ref.watch(writingHourSummaryProvider);

            final monthly = monthlyAsync.valueOrNull;
            final previous = previousAsync.valueOrNull;
            final annual = annualAsync.valueOrNull;
            final hasError =
                monthlyAsync.hasError ||
                previousAsync.hasError ||
                annualAsync.hasError;
            if (monthly == null || previous == null || annual == null) {
              if (hasError) {
                final error =
                    monthlyAsync.asError?.error ??
                    previousAsync.asError?.error ??
                    annualAsync.asError?.error;
                return Center(
                  child: Text(
                    context.t.strings.legacy.msg_failed_load_4(
                      e: error?.toString() ?? '',
                    ),
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }

            final monthDate = DateTime(monthly.year, monthly.month, 1);
            final monthLabel = _formatMonth(monthDate);
            final monthTitle = context.t.strings.legacy.msg_monthly_overview(
              month: monthLabel,
            );
            final trendMonthLabel = DateFormat(
              'MMM yyyy',
              Localizations.localeOf(context).toLanguageTag(),
            ).format(monthDate);
            final growth = _buildMonthlyGrowthSummary(
              context: context,
              current: monthly.totalMemos,
              previous: previous.totalMemos,
            );

            final daySeries = _toMonthSeries(monthDate, monthly.dailyCounts);
            final lastYear = _lastNDaysCounts(stats.dailyCounts, days: 365);
            final currentStreak = _currentStreakDays(stats.dailyCounts);
            final longestStreak = _longestStreakDays(stats.dailyCounts);
            final averageDailyChars = _averageCharsPerNaturalDay(
              totalChars: stats.totalChars,
              naturalDays: stats.daysSinceFirstMemo,
            );
            final writingHourSummary = writingHourAsync.valueOrNull;
            final commonWritingTime = _formatHourRange(
              writingHourSummary?.peakHour,
            );
            final activeWeekday = _mostActiveWeekday(stats.dailyCounts);
            final mostActiveWeekdayLabel = _weekdayLabel(
              context,
              activeWeekday?.weekday,
            );
            final mostActiveWeekdayTooltip = activeWeekday == null
                ? null
                : context.t.strings.legacy.msg_total_count_times(
                    count: _formatNumber(activeWeekday.count),
                  );
            final bottomItems = <_MetricItemNew>[
              _MetricItemNew(
                icon: Icons.local_fire_department_outlined,
                label: context.t.strings.legacy.msg_current_streak_days,
                value: _formatNumber(currentStreak),
                centerValue: true,
              ),
              _MetricItemNew(
                icon: Icons.calendar_month_outlined,
                label: context.t.strings.legacy.msg_total_days,
                value: _formatNumber(stats.daysSinceFirstMemo),
                centerValue: true,
              ),
              _MetricItemNew(
                icon: Icons.text_fields_rounded,
                label: context.t.strings.legacy.msg_average_daily_characters,
                value: _formatNumber(averageDailyChars),
                centerValue: true,
              ),
              _MetricItemNew(
                icon: Icons.emoji_events_outlined,
                label: context.t.strings.legacy.msg_longest_streak_days,
                value: _formatNumber(longestStreak),
                centerValue: true,
              ),
            ];
            final additionalBottomItems = <_MetricItemNew>[
              _MetricItemNew(
                icon: Icons.article_outlined,
                label: context.t.strings.legacy.msg_total_memos_metric,
                value: _formatNumber(stats.totalMemos),
                centerValue: true,
              ),
              _MetricItemNew(
                icon: Icons.description_outlined,
                label: context.t.strings.legacy.msg_total_characters_metric,
                value: _formatNumber(stats.totalChars),
                centerValue: true,
              ),
              _MetricItemNew(
                icon: Icons.schedule_outlined,
                label: context.t.strings.legacy.msg_common_writing_time,
                value: commonWritingTime,
                centerValue: true,
              ),
              _MetricItemNew(
                icon: Icons.today_outlined,
                label: context.t.strings.legacy.msg_most_active_day,
                value: mostActiveWeekdayLabel,
                centerValue: true,
                tooltip: mostActiveWeekdayTooltip,
              ),
            ];

            return RepaintBoundary(
              key: _posterBoundaryKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_selectedView == _StatsScreenView.calendar) {
                    return _buildCalendarStatsContent(
                      constraints: constraints,
                      months: months,
                      monthDate: monthDate,
                      monthly: monthly,
                      card: card,
                      textMain: textMain,
                      textMuted: textMuted,
                    );
                  }
                  return _buildDataStatsContent(
                    constraints: constraints,
                    months: months,
                    monthTitle: monthTitle,
                    monthLabel: monthLabel,
                    monthly: monthly,
                    growth: growth,
                    trendMonthLabel: trendMonthLabel,
                    monthDate: monthDate,
                    daySeries: daySeries,
                    lastYear: lastYear,
                    annual: annual,
                    bottomItems: bottomItems,
                    additionalBottomItems: additionalBottomItems,
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    isDark: isDark,
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(context.t.strings.legacy.msg_failed_load_4(e: e)),
          ),
        ),
      ),
    );
  }
}

class _StatsViewModeToggle extends StatelessWidget {
  const _StatsViewModeToggle({
    required this.selectedView,
    required this.onChanged,
    required this.textMain,
    required this.textMuted,
  });

  final _StatsScreenView selectedView;
  final ValueChanged<_StatsScreenView> onChanged;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final thumbColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.95);
    final selectedColor = textMain;
    final unselectedColor = textMuted.withValues(alpha: 0.82);

    return CupertinoSlidingSegmentedControl<_StatsScreenView>(
      groupValue: selectedView,
      padding: const EdgeInsets.all(3),
      backgroundColor: trackColor,
      thumbColor: thumbColor,
      onValueChanged: (value) {
        if (value != null) onChanged(value);
      },
      children: {
        _StatsScreenView.data: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Text(
            context.tr(zh: '\u6570\u636e', en: 'Data'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selectedView == _StatsScreenView.data
                  ? selectedColor
                  : unselectedColor,
            ),
          ),
        ),
        _StatsScreenView.calendar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Text(
            context.tr(zh: '\u65e5\u5386', en: 'Calendar'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selectedView == _StatsScreenView.calendar
                  ? selectedColor
                  : unselectedColor,
            ),
          ),
        ),
      },
    );
  }
}

class _CalendarDayData {
  const _CalendarDayData({
    required this.day,
    required this.count,
    required this.intensity,
    required this.isCurrentMonth,
    required this.isToday,
  });

  final DateTime day;
  final int count;
  final int intensity;
  final bool isCurrentMonth;
  final bool isToday;
}

class _CalendarMonthCard extends StatelessWidget {
  const _CalendarMonthCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.month,
    required this.dailyCounts,
    required this.selectedDay,
    required this.onPickMonth,
    required this.onSelectDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final DateTime month;
  final Map<DateTime, int> dailyCounts;
  final DateTime selectedDay;
  final VoidCallback? onPickMonth;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthLabel = _formatCalendarMonthTitle(context, month);
    final weekdayLabels = _calendarWeekdayLabels(context);
    final days = _buildCalendarMonthDays(context, month, dailyCounts);

    final titleChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            monthLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
        ),
        if (onPickMonth != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 20, color: textMuted),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildCalendarSectionDecoration(card, isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: onPickMonth == null
                    ? titleChild
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: onPickMonth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: titleChild,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              _CalendarMonthNavButton(
                icon: Icons.chevron_left,
                onTap: onPreviousMonth,
                color: textMuted,
              ),
              const SizedBox(width: 6),
              _CalendarMonthNavButton(
                icon: Icons.chevron_right,
                onTap: onNextMonth,
                color: textMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textMuted.withValues(alpha: 0.68),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final item = days[index];
              final isSelected = DateUtils.isSameDay(item.day, selectedDay);
              final fill = isSelected
                  ? MemoFlowPalette.primary.withValues(
                      alpha: isDark ? 0.88 : 0.96,
                    )
                  : _calendarCellFill(
                      intensity: item.intensity,
                      isCurrentMonth: item.isCurrentMonth,
                      isDark: isDark,
                    );
              final border = isSelected
                  ? Border.all(
                      color: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.96 : 0.72,
                      ),
                      width: 1.5,
                    )
                  : item.isToday
                  ? Border.all(
                      color: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.88 : 0.64,
                      ),
                      width: 1.6,
                    )
                  : null;
              final textColor = isSelected
                  ? Colors.white
                  : _calendarCellTextColor(
                      textMain: textMain,
                      textMuted: textMuted,
                      intensity: item.intensity,
                      isCurrentMonth: item.isCurrentMonth,
                    );
              final cell = AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(16),
                  border: border,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${item.day.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              );

              if (!item.isCurrentMonth) return cell;

              return Tooltip(
                message: _buildCalendarDayTooltip(
                  context,
                  day: item.day,
                  count: item.count,
                ),
                waitDuration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelectDay(item.day),
                    child: cell,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarMonthNavButton extends StatelessWidget {
  const _CalendarMonthNavButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 22,
        color: disabled ? color.withValues(alpha: 0.35) : color,
      ),
    );
  }
}

class _CalendarSelectedDaySection extends StatelessWidget {
  const _CalendarSelectedDaySection({
    required this.selectedDay,
    required this.dayMemosAsync,
    required this.memoCardKeyForUid,
    required this.prefs,
    required this.outboxStatus,
    required this.tagColors,
    required this.audioPositionListenable,
    required this.audioDurationListenable,
    required this.onOpenMemo,
    required this.onToggleTask,
    required this.onSyncStatusTap,
    required this.onAction,
    required this.textMain,
    required this.textMuted,
  });

  final DateTime selectedDay;
  final AsyncValue<List<LocalMemo>> dayMemosAsync;
  final GlobalKey<MemoListCardState> Function(String memoUid) memoCardKeyForUid;
  final AppPreferences prefs;
  final OutboxMemoStatus outboxStatus;
  final TagColorLookup tagColors;
  final ValueListenable<Duration> audioPositionListenable;
  final ValueListenable<Duration?> audioDurationListenable;
  final ValueChanged<LocalMemo> onOpenMemo;
  final Future<void> Function(LocalMemo memo, int index) onToggleTask;
  final Future<void> Function(LocalMemo memo, MemoSyncStatus status)
  onSyncStatusTap;
  final Future<void> Function(LocalMemo memo, MemoCardAction action) onAction;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return dayMemosAsync.when(
      data: (memos) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CalendarSelectedDayHeader(
              selectedDay: selectedDay,
              memoCount: memos.length,
              textMain: textMain,
              textMuted: textMuted,
            ),
            const SizedBox(height: 8),
            if (memos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                child: Text(
                  context.tr(
                    zh: '\u8fd9\u4e00\u5929\u8fd8\u6ca1\u6709\u7b14\u8bb0\uff0c\u53ef\u4ee5\u70b9\u5176\u4ed6\u65e5\u671f\u770b\u770b\u3002',
                    en: 'No memos on this day yet. Try another date.',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (var index = 0; index < memos.length; index++) ...[
                    _CalendarSelectedMemoRow(
                      memoCardKey: memoCardKeyForUid(memos[index].uid),
                      memo: memos[index],
                      prefs: prefs,
                      outboxStatus: outboxStatus,
                      tagColors: tagColors,
                      audioPositionListenable: audioPositionListenable,
                      audioDurationListenable: audioDurationListenable,
                      onOpenMemo: onOpenMemo,
                      onToggleTask: onToggleTask,
                      onSyncStatusTap: onSyncStatusTap,
                      onAction: onAction,
                    ),
                    if (index != memos.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarSelectedDayHeader(
            selectedDay: selectedDay,
            memoCount: null,
            textMain: textMain,
            textMuted: textMuted,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarSelectedDayHeader(
            selectedDay: selectedDay,
            memoCount: null,
            textMain: textMain,
            textMuted: textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            context.t.strings.legacy.msg_failed_load_4(e: error),
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSelectedDayHeader extends StatelessWidget {
  const _CalendarSelectedDayHeader({
    required this.selectedDay,
    required this.memoCount,
    required this.textMain,
    required this.textMuted,
  });

  final DateTime selectedDay;
  final int? memoCount;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final countLabel = memoCount == null
        ? context.tr(zh: '\u52a0\u8f7d\u4e2d', en: 'Loading')
        : context.tr(
            zh: '\u5171${_formatNumber(memoCount!)}\u6761\u7b14\u8bb0',
            en: '${_formatNumber(memoCount!)} memos',
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            _formatSelectedDayTitle(context, selectedDay),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
          Text(
            countLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MemoFlowPalette.primary.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSelectedMemoRow extends StatelessWidget {
  const _CalendarSelectedMemoRow({
    required this.memoCardKey,
    required this.memo,
    required this.prefs,
    required this.outboxStatus,
    required this.tagColors,
    required this.audioPositionListenable,
    required this.audioDurationListenable,
    required this.onOpenMemo,
    required this.onToggleTask,
    required this.onSyncStatusTap,
    required this.onAction,
  });

  final GlobalKey<MemoListCardState> memoCardKey;
  final LocalMemo memo;
  final AppPreferences prefs;
  final OutboxMemoStatus outboxStatus;
  final TagColorLookup tagColors;
  final ValueListenable<Duration> audioPositionListenable;
  final ValueListenable<Duration?> audioDurationListenable;
  final ValueChanged<LocalMemo> onOpenMemo;
  final Future<void> Function(LocalMemo memo, int index) onToggleTask;
  final Future<void> Function(LocalMemo memo, MemoSyncStatus status)
  onSyncStatusTap;
  final Future<void> Function(LocalMemo memo, MemoCardAction action) onAction;

  @override
  Widget build(BuildContext context) {
    return MemosListMemoCardContainer(
      memoCardKey: memoCardKey,
      memo: memo,
      heroTag: null,
      prefs: prefs,
      outboxStatus: outboxStatus,
      tagColors: tagColors,
      removing: false,
      searching: false,
      windowsHeaderSearchExpanded: false,
      selectedQuickSearchKind: null,
      searchQuery: '',
      playingMemoUid: null,
      audioPlaying: false,
      audioLoading: false,
      audioPositionListenable: audioPositionListenable,
      audioDurationListenable: audioDurationListenable,
      onAudioSeek: null,
      onAudioTap: null,
      onSyncStatusTap: (status) => unawaited(onSyncStatusTap(memo, status)),
      onToggleTask: (index) => unawaited(onToggleTask(memo, index)),
      onTap: () => onOpenMemo(memo),
      onAction: (action) => unawaited(onAction(memo, action)),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.share,
                          size: 16,
                          color: MemoFlowPalette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.t.strings.legacy.msg_share,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: MemoFlowPalette.primary,
                          ),
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
                      label: context.t.strings.legacy.msg_memos,
                      textMain: textMain,
                      textMuted: textMuted,
                      big: true,
                    ),
                    const SizedBox(height: 14),
                    _Metric(
                      value: '$maxMemosPerDay',
                      label: context.t.strings.legacy.msg_max_per_day,
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                    const SizedBox(height: 14),
                    _Metric(
                      value: '$activeDays',
                      label: context.t.strings.legacy.msg_days_memos,
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
                      value: chars == null ? '--' : _formatNumber(chars!),
                      label: context.t.strings.legacy.msg_characters,
                      textMain: textMain,
                      textMuted: textMuted,
                      big: true,
                    ),
                    const SizedBox(height: 14),
                    _Metric(
                      value: maxCharsPerDay == null
                          ? '--'
                          : _formatNumber(maxCharsPerDay!),
                      label: context.t.strings.legacy.msg_max_chars_day,
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
                      child: _BarDot(count: c, max: chartMax),
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
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textMuted.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              '0',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textMuted.withValues(alpha: 0.5),
              ),
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
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.06)),
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, color: textMuted),
              ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textMuted.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _HeatmapCard extends StatefulWidget {
  const _HeatmapCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.title,
    this.onShare,
    required this.dailyCounts,
    required this.isDark,
    this.compact = false,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String title;
  final VoidCallback? onShare;
  final Map<DateTime, int> dailyCounts;
  final bool isDark;
  final bool compact;

  @override
  State<_HeatmapCard> createState() => _HeatmapCardState();
}

class _HeatmapCardState extends State<_HeatmapCard> {
  late final ScrollController _scrollController;
  bool _didInitialScrollToLatest = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureInitialScrollToLatest() {
    if (_didInitialScrollToLatest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_didInitialScrollToLatest) return;
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        _scrollController.jumpTo(maxExtent);
      }
      _didInitialScrollToLatest = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = widget.compact ? 18.0 : 20.0;
    final sectionGap = widget.compact ? 2.0 : 10.0;
    final labelsGap = widget.compact ? 2.0 : 8.0;
    final fallbackBodyHeight = widget.compact ? 122.0 : 164.0;
    final heatmapBody = LayoutBuilder(
      builder: (context, constraints) {
        const weeks = 53;
        const rows = 7;
        const baseSpacing = 2.0;
        final availH = constraints.maxHeight;
        final axisHeight = widget.compact ? 10.0 : 14.0;
        final bottomPadding = widget.compact ? 4.0 : 6.0;
        final fallbackCell = widget.compact ? 9.8 : 13.2;
        final maxCell = widget.compact ? 18.0 : 28.0;

        var cellSize = fallbackCell;
        if (availH.isFinite) {
          final usableH = math.max(
            0,
            availH - labelsGap - axisHeight - bottomPadding,
          );
          final cellByHeight = (usableH - baseSpacing * (rows - 1)) / rows;
          cellSize = cellByHeight;
        }
        if (!cellSize.isFinite || cellSize <= 0) {
          cellSize = fallbackCell;
        }
        cellSize = cellSize.clamp(2.0, maxCell).toDouble();
        final horizontalSpacing = baseSpacing;
        final gridWidth = cellSize * weeks + horizontalSpacing * (weeks - 1);
        _ensureInitialScrollToLatest();

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _YearHeatmap(
                  dailyCounts: widget.dailyCounts,
                  isDark: widget.isDark,
                  maxCell: cellSize,
                  cellSize: cellSize,
                  horizontalSpacing: horizontalSpacing,
                  verticalSpacing: baseSpacing,
                ),
                SizedBox(height: labelsGap),
                _HeatmapMonthAxisNew(
                  textMuted: widget.textMuted,
                  maxCell: cellSize,
                  compact: widget.compact,
                  cellSize: cellSize,
                  horizontalSpacing: horizontalSpacing,
                ),
                SizedBox(height: bottomPadding),
              ],
            ),
          ),
        );
      },
    );

    return Container(
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: widget.isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.maxHeight.isFinite;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: widget.textMain,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionGap),
              if (hasBoundedHeight)
                Expanded(child: heatmapBody)
              else
                SizedBox(height: fallbackBodyHeight, child: heatmapBody),
            ],
          );
        },
      ),
    );
  }
}

class _HeatmapMonthAxisNew extends StatelessWidget {
  const _HeatmapMonthAxisNew({
    required this.textMuted,
    required this.maxCell,
    required this.compact,
    this.cellSize,
    this.horizontalSpacing = 2.0,
  });

  final Color textMuted;
  final double maxCell;
  final bool compact;
  final double? cellSize;
  final double horizontalSpacing;

  @override
  Widget build(BuildContext context) {
    const weeks = 53;

    final todayLocal = DateTime.now();
    final endLocal = DateTime(
      todayLocal.year,
      todayLocal.month,
      todayLocal.day,
    );
    final currentWeekStart = endLocal.subtract(
      Duration(days: endLocal.weekday - DateTime.monday),
    );
    final alignedStart = currentWeekStart.subtract(
      const Duration(days: (weeks - 1) * DateTime.daysPerWeek),
    );
    final locale = Localizations.localeOf(context).toString();

    final ticks = <({DateTime month, int weekIndex})>[];
    var month = DateTime(alignedStart.year, alignedStart.month, 1);
    if (month.isBefore(alignedStart)) {
      month = DateTime(month.year, month.month + 1, 1);
    }
    while (!month.isAfter(endLocal)) {
      final weekIndex = month.difference(alignedStart).inDays ~/ 7;
      if (weekIndex >= 0 && weekIndex < weeks) {
        ticks.add((month: month, weekIndex: weekIndex));
      }
      month = DateTime(month.year, month.month + 1, 1);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedCellSize =
            cellSize ??
            ((constraints.maxWidth - horizontalSpacing * (weeks - 1)) / weeks)
                .clamp(3.0, maxCell)
                .toDouble();
        final gridWidth =
            resolvedCellSize * weeks + horizontalSpacing * (weeks - 1);
        final minGap = compact ? 30.0 : 34.0;

        var lastLeft = -999.0;
        final labels = <Widget>[];
        for (final tick in ticks) {
          final rawLeft =
              tick.weekIndex * (resolvedCellSize + horizontalSpacing);
          final labelText = DateFormat.MMM(locale).format(tick.month);
          final left = rawLeft
              .clamp(0.0, math.max(0.0, gridWidth - 26.0))
              .toDouble();
          if (left - lastLeft < minGap) continue;
          lastLeft = left;
          labels.add(
            Positioned(
              left: left,
              top: 0,
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  color: textMuted.withValues(alpha: 0.35),
                ),
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: gridWidth,
            height: compact ? 10 : 14,
            child: Stack(clipBehavior: Clip.none, children: labels),
          ),
        );
      },
    );
  }
}

class _YearHeatmap extends StatelessWidget {
  const _YearHeatmap({
    required this.dailyCounts,
    required this.isDark,
    this.maxCell = 8.6,
    this.cellSize,
    this.horizontalSpacing = 2.0,
    this.verticalSpacing = 2.0,
  });

  final Map<DateTime, int> dailyCounts;
  final bool isDark;
  final double maxCell;
  final double? cellSize;
  final double horizontalSpacing;
  final double verticalSpacing;

  @override
  Widget build(BuildContext context) {
    const weeks = 53;
    const daysPerWeek = 7;

    final todayLocal = DateTime.now();
    final endLocal = DateTime(
      todayLocal.year,
      todayLocal.month,
      todayLocal.day,
    );
    final startLocal = endLocal.subtract(const Duration(days: 364));
    final currentWeekStart = endLocal.subtract(
      Duration(days: endLocal.weekday - DateTime.monday),
    );
    final alignedStart = currentWeekStart.subtract(
      Duration(days: (weeks - 1) * daysPerWeek),
    );

    final maxCount = dailyCounts.values.fold<int>(
      0,
      (max, v) => v > max ? v : max,
    );

    Color colorFor(int c, {required bool inRange}) {
      if (!inRange) {
        return isDark
            ? const Color(0xFF262626)
            : Colors.black.withValues(alpha: 0.04);
      }
      if (c <= 0) {
        return isDark
            ? const Color(0xFF2C2C2C)
            : Colors.black.withValues(alpha: 0.05);
      }
      final t = maxCount <= 0 ? 0.0 : (c / maxCount).clamp(0.0, 1.0);
      final level = (t * 6).ceil().clamp(1, 6);
      const lightAlphas = <double>[0.16, 0.28, 0.42, 0.58, 0.76, 0.96];
      const darkAlphas = <double>[0.24, 0.38, 0.52, 0.68, 0.84, 0.98];
      final alpha = isDark ? darkAlphas[level - 1] : lightAlphas[level - 1];
      return MemoFlowPalette.primary.withValues(alpha: alpha);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridBorder = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04);
        final resolvedCellSize =
            cellSize ??
            ((constraints.maxWidth - horizontalSpacing * (weeks - 1)) / weeks)
                .clamp(3.0, maxCell)
                .toDouble();
        final gridWidth =
            resolvedCellSize * weeks + horizontalSpacing * (weeks - 1);
        final gridHeight =
            resolvedCellSize * daysPerWeek +
            verticalSpacing * (daysPerWeek - 1);

        Widget buildCell(DateTime day) {
          if (day.isAfter(endLocal)) {
            return SizedBox(width: resolvedCellSize, height: resolvedCellSize);
          }
          final inRange = !day.isBefore(startLocal) && !day.isAfter(endLocal);
          final count = inRange ? (dailyCounts[day] ?? 0) : 0;
          final isToday = DateUtils.isSameDay(day, endLocal);
          final borderColor = isToday
              ? MemoFlowPalette.primary.withValues(alpha: isDark ? 0.98 : 0.9)
              : gridBorder;
          final borderWidth = isToday ? 1.3 : 0.6;
          final cell = Container(
            width: resolvedCellSize,
            height: resolvedCellSize,
            decoration: BoxDecoration(
              color: colorFor(count, inRange: inRange),
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(2),
            ),
          );
          if (!inRange) return cell;

          final tooltip =
              '${DateFormat('yyyy-MM-dd').format(day)}  ${_formatNumber(count)}\u6761\u7b14\u8bb0';
          return Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 250),
            child: MouseRegion(cursor: SystemMouseCursors.click, child: cell),
          );
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var row = 0; row < daysPerWeek; row++) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var col = 0; col < weeks; col++) ...[
                        buildCell(
                          alignedStart.add(
                            Duration(days: col * daysPerWeek + row),
                          ),
                        ),
                        if (col < weeks - 1) SizedBox(width: horizontalSpacing),
                      ],
                    ],
                  ),
                  if (row < daysPerWeek - 1) SizedBox(height: verticalSpacing),
                ],
              ],
            ),
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
    final cardSurface = isDark
        ? card
        : Color.lerp(card, Colors.white, 0.35) ?? card;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardSurface,
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyOverviewCardNew extends StatelessWidget {
  const _MonthlyOverviewCardNew({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.title,
    required this.monthLabel,
    required this.onPickMonth,
    required this.memos,
    required this.chars,
    required this.maxMemosPerDay,
    required this.maxCharsPerDay,
    required this.growth,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String title;
  final String monthLabel;
  final VoidCallback? onPickMonth;
  final int memos;
  final int? chars;
  final int maxMemosPerDay;
  final int? maxCharsPerDay;
  final _MonthGrowthSummaryNew growth;

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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
              ),
              _MonthPill(
                label: monthLabel,
                textMuted: textMuted,
                onTap: onPickMonth,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricKVNew(
                      value: _formatNumber(memos),
                      label: context.t.strings.legacy.msg_memo_count,
                      textMain: textMain,
                      textMuted: textMuted,
                      big: true,
                    ),
                    const SizedBox(height: 12),
                    _MetricKVNew(
                      value: _formatNumber(maxMemosPerDay),
                      label: context.t.strings.legacy.msg_max_per_day,
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricKVNew(
                      value: chars == null ? '--' : _formatNumber(chars!),
                      label:
                          context.t.strings.legacy.msg_total_characters_short,
                      textMain: textMain,
                      textMuted: textMuted,
                      big: true,
                    ),
                    const SizedBox(height: 12),
                    _MetricKVNew(
                      value: maxCharsPerDay == null
                          ? '--'
                          : _formatNumber(maxCharsPerDay!),
                      label: context
                          .t
                          .strings
                          .legacy
                          .msg_max_characters_single_day,
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MetricKVNew extends StatelessWidget {
  const _MetricKVNew({
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
    final unitSplit = value.lastIndexOf(' ');
    final hasUnit = unitSplit > 0 && unitSplit < value.length - 1;
    final numberText = hasUnit ? value.substring(0, unitSplit) : value;
    final unitText = hasUnit ? value.substring(unitSplit + 1) : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hasUnit
            ? Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: numberText,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: textMain,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: ' $unitText',
                      style: TextStyle(
                        fontSize: big ? 18 : 14,
                        fontWeight: FontWeight.w700,
                        color: textMuted.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: textMain,
                  height: 1,
                ),
              ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textMuted.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _DailyTrendCardNew extends StatelessWidget {
  const _DailyTrendCardNew({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.monthLabel,
    required this.month,
    required this.counts,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String monthLabel;
  final DateTime month;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxCount = counts.fold<int>(0, (max, v) => v > max ? v : max);
    final averageCount = counts.isEmpty
        ? 0.0
        : counts.fold<int>(0, (sum, v) => sum + v) / counts.length;
    final chartTop = math
        .max(
          maxCount <= 0 ? 1.0 : (maxCount * 1.15).ceilToDouble(),
          averageCount + 1,
        )
        .toDouble();
    final averageLabel = averageCount == averageCount.roundToDouble()
        ? averageCount.round().toString()
        : averageCount.toStringAsFixed(1);
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
              Text(
                context.t.strings.legacy.msg_daily_memo_trend,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
              const Spacer(),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: chartTop,
                alignment: BarChartAlignment.spaceBetween,
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: textMuted.withValues(alpha: isDark ? 0.34 : 0.28),
                      width: 1,
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if ((value - value.round()).abs() > 0.001) {
                          return const SizedBox.shrink();
                        }
                        final day = value.round() + 1;
                        const marks = <int>{5, 10, 15, 20, 25};
                        if (day < 1 ||
                            day > counts.length ||
                            !marks.contains(day)) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          space: 3,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 1,
                                height: 4,
                                color: textMuted.withValues(
                                  alpha: isDark ? 0.45 : 0.36,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: textMuted.withValues(alpha: 0.58),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        Colors.black.withValues(alpha: 0.86),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = (group.x + 1).clamp(1, counts.length);
                      final date = DateTime(month.year, month.month, day);
                      final count = counts[day - 1];
                      return BarTooltipItem(
                        context.t.strings.legacy.msg_date_memo_count_tooltip(
                          date: DateFormat('yyyy-MM-dd').format(date),
                          count: _formatNumber(count),
                        ),
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      );
                    },
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: averageCount,
                      color: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.6 : 0.5,
                      ),
                      strokeWidth: 1.2,
                      dashArray: const [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 2, bottom: 6),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.95 : 0.86,
                          ),
                        ),
                        labelResolver: (_) => context.t.strings.legacy
                            .msg_average_value(value: averageLabel),
                      ),
                    ),
                  ],
                ),
                barGroups: [
                  for (var i = 0; i < counts.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i].toDouble(),
                          width: 6,
                          color: MemoFlowPalette.primary.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnualInsightsCardNew extends StatelessWidget {
  const _AnnualInsightsCardNew({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.insights,
    required this.isDark,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final AnnualInsights insights;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final cloud = _TagWordCloudNew(
          slices: insights.tagDistribution,
          textMain: textMain,
          textMuted: textMuted,
          isDark: isDark,
        );

        return Container(
          padding: const EdgeInsets.all(14),
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
          child: hasBoundedHeight ? cloud : SizedBox(height: 220, child: cloud),
        );
      },
    );
  }
}

class _TagWordCloudNew extends StatefulWidget {
  const _TagWordCloudNew({
    required this.slices,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
  });

  final List<TagDistribution> slices;
  final Color textMain;
  final Color textMuted;
  final bool isDark;

  @override
  State<_TagWordCloudNew> createState() => _TagWordCloudNewState();
}

class _TagWordCloudNewState extends State<_TagWordCloudNew> {
  List<_PlacedWordNew> _placedWords = const <_PlacedWordNew>[];
  int _layoutHash = 0;
  int? _hoveredIndex;
  Offset? _hoverPosition;
  static const int _minTagCountForCloud = 5;

  int _effectiveTagCount(List<TagDistribution> slices) {
    final uniqueTags = <String>{};
    for (final item in slices) {
      if (item.count <= 0 || item.isUntagged) continue;
      final tag = item.tag.trim();
      if (tag.isEmpty) continue;
      uniqueTags.add(tag);
    }
    return uniqueTags.length;
  }

  @override
  void didUpdateWidget(covariant _TagWordCloudNew oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slices != widget.slices ||
        oldWidget.isDark != widget.isDark) {
      _placedWords = const <_PlacedWordNew>[];
      _layoutHash = 0;
      _hoveredIndex = null;
      _hoverPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTagCount = _effectiveTagCount(widget.slices);
    if (effectiveTagCount < _minTagCountForCloud) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.textMuted.withValues(
            alpha: widget.isDark ? 0.08 : 0.06,
          ),
          border: Border.all(
            color: widget.textMuted.withValues(
              alpha: widget.isDark ? 0.2 : 0.14,
            ),
          ),
        ),
        child: Center(
          child: Text(
            context.t.strings.legacy.msg_need_at_least_five_tags,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.textMuted,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const cloudPadding = 4.0;
        final cloudSize = Size(
          math.max(48.0, constraints.maxWidth - cloudPadding * 2),
          math.max(64.0, constraints.maxHeight - cloudPadding * 2),
        );
        _ensureLayout(cloudSize);
        final hoverIndex = _hoveredIndex;
        final hoverWord =
            hoverIndex != null &&
                hoverIndex >= 0 &&
                hoverIndex < _placedWords.length
            ? _placedWords[hoverIndex]
            : null;
        final hoverPos = _hoverPosition;
        return Padding(
          padding: const EdgeInsets.all(cloudPadding),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) => _setHover(
                    _hitTestWord(event.localPosition),
                    event.localPosition,
                  ),
                  onExit: (_) => _setHover(null, null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _setHover(
                      _hitTestWord(details.localPosition),
                      details.localPosition,
                    ),
                    child: RepaintBoundary(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(
                          end: _hoveredIndex == null ? 0.0 : 1.0,
                        ),
                        builder: (context, hoverStrength, _) {
                          return CustomPaint(
                            size: Size.infinite,
                            painter: _WordCloudPainterNew(
                              words: _placedWords,
                              activeIndex: _hoveredIndex,
                              hoverStrength: hoverStrength,
                              highlightColor: MemoFlowPalette.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (hoverWord != null && hoverPos != null)
                Positioned(
                  left: (hoverPos.dx - 120).clamp(0.0, cloudSize.width - 260.0),
                  top: (hoverPos.dy - 86).clamp(0.0, cloudSize.height - 82.0),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 190,
                            maxWidth: 260,
                          ),
                          child: Text(
                            context.t.strings.legacy.msg_tag_cloud_tooltip(
                              count: _formatNumber(hoverWord.count),
                              percent: _formatPercentInt(
                                hoverWord.count,
                                hoverWord.totalCount,
                              ),
                              latest: _formatDateYmd(hoverWord.latestMemoAt),
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _setHover(int? index, Offset? localPos) {
    if (_hoveredIndex == index && _hoverPosition == localPos) return;
    if (!mounted) return;
    setState(() {
      _hoveredIndex = index;
      _hoverPosition = localPos;
    });
  }

  int? _hitTestWord(Offset localPos) {
    for (var i = _placedWords.length - 1; i >= 0; i--) {
      if (_placedWords[i].rect.contains(localPos)) return i;
    }
    return null;
  }

  String _formatPercentInt(int value, int total) {
    if (total <= 0) return '0';
    return ((value * 100.0) / total).round().toString();
  }

  String _formatDateYmd(DateTime? dt) {
    if (dt == null) return '--';
    return DateFormat('yyyy-MM-dd').format(dt.toLocal());
  }

  void _ensureLayout(Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final hash = Object.hash(
      size.width.floor(),
      size.height.floor(),
      widget.isDark,
      Object.hashAll(
        widget.slices.map(
          (e) => Object.hash(e.tag, e.count, e.isUntagged, e.colorHex),
        ),
      ),
    );
    if (hash == _layoutHash) return;

    final words = _buildWords(widget.slices);
    if (words.isEmpty) {
      _placedWords = const <_PlacedWordNew>[];
      _hoveredIndex = null;
      _hoverPosition = null;
      _layoutHash = hash;
      return;
    }

    final shortSide = math.min(size.width, size.height);
    final densityScale = math
        .sqrt((words.length / 16).clamp(1.0, 10.0))
        .toDouble();
    final baseMinTextSize = (shortSide * 0.10 / densityScale)
        .clamp(8.0, 13.0)
        .toDouble();
    final baseMaxTextSize = math
        .max(
          (shortSide * 0.30 / densityScale).clamp(16.0, 34.0).toDouble(),
          baseMinTextSize + 3,
        )
        .toDouble();
    List<_PlacedWordNew> placed = const <_PlacedWordNew>[];
    var currentMin = baseMinTextSize;
    var currentMax = baseMaxTextSize;
    for (var i = 0; i < 10; i++) {
      final candidate = _layoutWords(
        size: size,
        words: words,
        totalCount: words.first.totalCount,
        minTextSize: currentMin,
        maxTextSize: currentMax,
      );
      placed = candidate;
      if (candidate.length >= words.length) break;

      currentMin = (currentMin * 0.9).clamp(4.0, 13.0).toDouble();
      currentMax = (currentMax * 0.88).clamp(currentMin + 1.5, 34.0).toDouble();
    }

    _placedWords = placed;
    if (_hoveredIndex != null &&
        (_hoveredIndex! < 0 || _hoveredIndex! >= _placedWords.length)) {
      _hoveredIndex = null;
      _hoverPosition = null;
    }
    _layoutHash = hash;
  }

  List<_PlacedWordNew> _layoutWords({
    required Size size,
    required List<_TagCloudWordNew> words,
    required int totalCount,
    required double minTextSize,
    required double maxTextSize,
  }) {
    if (words.isEmpty) return const <_PlacedWordNew>[];
    final placed = <_PlacedWordNew>[];

    final maxCount = words.first.count;
    final minCount = words.last.count;
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final fontSize = _fontSizeForCount(
        count: word.count,
        minCount: minCount,
        maxCount: maxCount,
        minTextSize: minTextSize,
        maxTextSize: maxTextSize,
      );
      final baseStyle = TextStyle(
        color: word.color,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        height: 1.0,
      );

      final painter = TextPainter(
        text: TextSpan(text: word.layoutText, style: baseStyle),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      if (painter.width <= 0 || painter.height <= 0) continue;
      final rect = _findPlacementRect(
        size: size,
        center: center,
        textSize: Size(painter.width, painter.height),
        placed: placed,
        wordIndex: i,
      );
      if (rect == null) return placed;

      placed.add(
        _PlacedWordNew(
          painter: painter,
          offset: rect.topLeft,
          rect: rect,
          text: word.layoutText,
          baseStyle: baseStyle,
          label: word.label,
          count: word.count,
          totalCount: totalCount,
          latestMemoAt: word.latestMemoAt,
        ),
      );
    }

    return placed;
  }

  double _fontSizeForCount({
    required int count,
    required int minCount,
    required int maxCount,
    required double minTextSize,
    required double maxTextSize,
  }) {
    if (maxCount <= minCount) return (minTextSize + maxTextSize) / 2;
    final t = ((count - minCount) / (maxCount - minCount)).clamp(0.0, 1.0);
    return minTextSize + (maxTextSize - minTextSize) * t;
  }

  Rect? _findPlacementRect({
    required Size size,
    required Offset center,
    required Size textSize,
    required List<_PlacedWordNew> placed,
    required int wordIndex,
  }) {
    const edgePadding = 2.0;
    const collidePadding = 0.8;
    final w = textSize.width;
    final h = textSize.height;

    final shortSide = math.min(size.width, size.height);
    final startRadius = shortSide * 0.09;
    final centerVoidRadius = shortSide * 0.11;
    final radiusStep = math.max(3.0, shortSide / 75);
    final maxRadius = math.max(size.width, size.height) * 0.95;
    final maxSteps = (maxRadius / radiusStep).ceil();
    final assignedArm = wordIndex % 4;

    bool canUse(Rect rect) {
      if (placed.isNotEmpty &&
          _hitsCenterVoid(rect, center: center, radius: centerVoidRadius)) {
        return false;
      }
      return _isRectAvailable(
        rect,
        size: size,
        placed: placed,
        edgePadding: edgePadding,
        collidePadding: collidePadding,
      );
    }

    for (var step = 0; step < maxSteps; step++) {
      final radius = startRadius + step * radiusStep;
      final bend = radius * 0.72;
      for (final centerPoint in _buildArmProbeCenters(
        center,
        assignedArm,
        radius,
        bend,
      )) {
        final candidate = Rect.fromCenter(
          center: centerPoint,
          width: w,
          height: h,
        );
        if (canUse(candidate)) return candidate;
      }
    }

    for (var step = 0; step < maxSteps; step++) {
      final radius = startRadius + step * radiusStep;
      final bend = radius * 0.64;
      for (var armShift = 1; armShift < 4; armShift++) {
        final arm = (assignedArm + armShift) % 4;
        for (final centerPoint in _buildArmProbeCenters(
          center,
          arm,
          radius,
          bend,
        )) {
          final candidate = Rect.fromCenter(
            center: centerPoint,
            width: w,
            height: h,
          );
          if (canUse(candidate)) return candidate;
        }
      }
    }

    final gridStep = math.max(2.0, math.min(w, h) * 0.35);
    final maxX = size.width - w - edgePadding;
    final maxY = size.height - h - edgePadding;
    for (var y = edgePadding; y <= maxY; y += gridStep) {
      for (var x = edgePadding; x <= maxX; x += gridStep) {
        final rect = Rect.fromLTWH(x, y, w, h);
        if (canUse(rect)) {
          return rect;
        }
      }
    }

    return null;
  }

  List<Offset> _buildArmProbeCenters(
    Offset center,
    int arm,
    double radius,
    double bend,
  ) {
    final baseCenter = center + _armSpiralOffset(arm, radius, bend);
    final tangent = _armTangent(arm);
    final normal = Offset(-tangent.dy, tangent.dx);
    const tangentShifts = <double>[0, -3, 3, -6, 6];
    const normalShifts = <double>[0, -4, 4, -8, 8];
    final points = <Offset>[];

    for (final t in tangentShifts) {
      for (final n in normalShifts) {
        points.add(baseCenter + tangent * t + normal * n);
      }
    }
    return points;
  }

  Offset _armSpiralOffset(int arm, double radius, double bend) {
    switch (arm % 4) {
      case 0:
        return Offset(radius, -bend);
      case 1:
        return Offset(bend, radius);
      case 2:
        return Offset(-radius, bend);
      default:
        return Offset(-bend, -radius);
    }
  }

  Offset _armTangent(int arm) {
    switch (arm % 4) {
      case 0:
        return const Offset(0.94, -0.34);
      case 1:
        return const Offset(0.34, 0.94);
      case 2:
        return const Offset(-0.94, 0.34);
      default:
        return const Offset(-0.34, -0.94);
    }
  }

  bool _hitsCenterVoid(
    Rect rect, {
    required Offset center,
    required double radius,
  }) {
    final nearestX = center.dx.clamp(rect.left, rect.right);
    final nearestY = center.dy.clamp(rect.top, rect.bottom);
    final dx = nearestX - center.dx;
    final dy = nearestY - center.dy;
    return dx * dx + dy * dy < radius * radius;
  }

  bool _isRectAvailable(
    Rect rect, {
    required Size size,
    required List<_PlacedWordNew> placed,
    required double edgePadding,
    required double collidePadding,
  }) {
    if (rect.left < edgePadding ||
        rect.top < edgePadding ||
        rect.right > size.width - edgePadding ||
        rect.bottom > size.height - edgePadding) {
      return false;
    }

    final inflated = rect.inflate(collidePadding);
    for (final item in placed) {
      if (inflated.overlaps(item.rect.inflate(collidePadding))) {
        return false;
      }
    }
    return true;
  }

  List<_TagCloudWordNew> _buildWords(List<TagDistribution> slices) {
    final merged =
        <String, ({int count, Color? color, DateTime? latestMemoAt})>{};
    for (final item in slices) {
      if (item.count <= 0 || item.isUntagged) continue;
      final name = item.tag.trim().isEmpty
          ? context.t.strings.legacy.msg_unnamed_tag
          : item.tag.trim();
      final old = merged[name];
      final preferredColor = old?.color ?? _tryParseHexColorNew(item.colorHex);
      final oldLatest = old?.latestMemoAt;
      final latestMemoAt = oldLatest == null
          ? item.latestMemoAt
          : (item.latestMemoAt == null
                ? oldLatest
                : (item.latestMemoAt!.isAfter(oldLatest)
                      ? item.latestMemoAt
                      : oldLatest));
      merged[name] = (
        count: (old?.count ?? 0) + item.count,
        color: preferredColor,
        latestMemoAt: latestMemoAt,
      );
    }

    final sorted =
        merged.entries
            .map(
              (e) => (
                word: e.key,
                count: e.value.count,
                color: e.value.color,
                latestMemoAt: e.value.latestMemoAt,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) return byCount;
            return a.word.compareTo(b.word);
          });
    if (sorted.isEmpty) return const <_TagCloudWordNew>[];

    final totalCount = sorted.fold<int>(0, (sum, item) => sum + item.count);
    final maxCount = sorted.first.count;
    return [
      for (var i = 0; i < sorted.length; i++)
        _TagCloudWordNew(
          label: sorted[i].word,
          layoutText: i.isOdd
              ? _toVerticalText(sorted[i].word)
              : sorted[i].word,
          count: sorted[i].count,
          totalCount: totalCount,
          latestMemoAt: sorted[i].latestMemoAt,
          color: sorted[i].color ?? _themeScaleColor(sorted[i].count, maxCount),
        ),
    ];
  }

  String _toVerticalText(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 1) return trimmed;
    final chars = trimmed.runes
        .map((r) => String.fromCharCode(r))
        .toList(growable: false);
    return chars.join('\n');
  }

  Color _themeScaleColor(int value, int maxValue) {
    final t = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final level = (t * 6).ceil().clamp(1, 6);
    const lightAlphas = <double>[0.22, 0.34, 0.46, 0.58, 0.74, 0.92];
    const darkAlphas = <double>[0.3, 0.42, 0.54, 0.66, 0.8, 0.96];
    final alpha = widget.isDark
        ? darkAlphas[level - 1]
        : lightAlphas[level - 1];
    return MemoFlowPalette.primary.withValues(alpha: alpha);
  }
}

class _TagCloudWordNew {
  const _TagCloudWordNew({
    required this.label,
    required this.layoutText,
    required this.count,
    required this.totalCount,
    required this.latestMemoAt,
    required this.color,
  });

  final String label;
  final String layoutText;
  final int count;
  final int totalCount;
  final DateTime? latestMemoAt;
  final Color color;
}

class _PlacedWordNew {
  const _PlacedWordNew({
    required this.painter,
    required this.offset,
    required this.rect,
    required this.text,
    required this.baseStyle,
    required this.label,
    required this.count,
    required this.totalCount,
    required this.latestMemoAt,
  });

  final TextPainter painter;
  final Offset offset;
  final Rect rect;
  final String text;
  final TextStyle baseStyle;
  final String label;
  final int count;
  final int totalCount;
  final DateTime? latestMemoAt;
}

class _WordCloudPainterNew extends CustomPainter {
  const _WordCloudPainterNew({
    required this.words,
    required this.activeIndex,
    required this.hoverStrength,
    required this.highlightColor,
  });

  final List<_PlacedWordNew> words;
  final int? activeIndex;
  final double hoverStrength;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final active =
        activeIndex != null && activeIndex! >= 0 && activeIndex! < words.length
        ? activeIndex
        : null;

    for (var i = 0; i < words.length; i++) {
      if (active != null && i == active) continue;
      final word = words[i];
      word.painter.paint(canvas, word.offset);
    }

    if (active == null) return;
    final target = words[active];
    final scale = 1.0 + 0.05 * hoverStrength;
    final darkAlpha = (0.18 * hoverStrength).clamp(0.0, 0.3);
    final darkColor = Colors.black.withValues(alpha: darkAlpha);
    final baseColor = target.baseStyle.color ?? Colors.black;
    final hoveredStyle = target.baseStyle.copyWith(
      color: Color.alphaBlend(darkColor, baseColor),
      fontSize: (target.baseStyle.fontSize ?? 12) * scale,
    );
    final hoverPainter = TextPainter(
      text: TextSpan(text: target.text, style: hoveredStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final hoverOffset = Offset(
      target.rect.center.dx - hoverPainter.width / 2,
      target.rect.center.dy - hoverPainter.height / 2,
    );
    final hoverRect = Rect.fromLTWH(
      hoverOffset.dx - 2,
      hoverOffset.dy - 1,
      hoverPainter.width + 4,
      hoverPainter.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hoverRect, const Radius.circular(4)),
      Paint()..color = highlightColor.withValues(alpha: 0.12 * hoverStrength),
    );
    hoverPainter.paint(canvas, hoverOffset);
  }

  @override
  bool shouldRepaint(covariant _WordCloudPainterNew oldDelegate) {
    return oldDelegate.words != words ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.hoverStrength != hoverStrength ||
        oldDelegate.highlightColor != highlightColor;
  }
}

class _YearCharsTrendCardNew extends StatelessWidget {
  const _YearCharsTrendCardNew({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.points,
    required this.isDark,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final List<MonthlyChars> points;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const defaultChartHeight = 132.0;
        const minChartHeight = 68.0;
        const consumedHeight = 56.0;
        final chartHeight = constraints.hasBoundedHeight
            ? math.max(minChartHeight, constraints.maxHeight - consumedHeight)
            : defaultChartHeight;

        return Container(
          padding: const EdgeInsets.all(12),
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
              Text(
                context.t.strings.legacy.msg_yearly_character_trend,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: chartHeight,
                child: _YearCharsTrendChartNew(
                  points: points,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YearCharsTrendChartNew extends StatelessWidget {
  const _YearCharsTrendChartNew({
    required this.points,
    required this.textMuted,
  });

  final List<MonthlyChars> points;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          context.t.strings.legacy.msg_no_data,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textMuted,
          ),
        ),
      );
    }

    final normalized = _normalizeYearPoints(points);
    final spots = <FlSpot>[
      for (var i = 0; i < normalized.length; i++)
        FlSpot(i.toDouble(), normalized[i].totalChars.toDouble()),
    ];
    final maxChars = normalized.fold<int>(
      0,
      (max, item) => item.totalChars > max ? item.totalChars : max,
    );
    final maxY = maxChars <= 0 ? 1.0 : (maxChars * 1.15).ceilToDouble();
    final yInterval = maxY <= 3 ? 1.0 : (maxY / 3).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: textMuted.withValues(alpha: 0.16),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    _formatNumber(value.round()),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: textMuted.withValues(alpha: 0.72),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if ((value - value.round()).abs() > 0.001) {
                  return const SizedBox.shrink();
                }
                final index = value.round();
                if (index < 0 || index >= normalized.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    '${normalized[index].month.month}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: textMuted.withValues(alpha: 0.58),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => Colors.black.withValues(alpha: 0.86),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.round().clamp(0, normalized.length - 1);
                final point = normalized[index];
                return LineTooltipItem(
                  context.t.strings.legacy.msg_month_characters_tooltip(
                    month: DateFormat('yyyy-MM').format(point.month),
                    chars: _formatNumber(point.totalChars),
                  ),
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            preventCurveOvershootingThreshold: 0,
            barWidth: 1.5,
            isStrokeCapRound: true,
            color: MemoFlowPalette.primary.withValues(alpha: 0.95),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2.0,
                  color: MemoFlowPalette.primary.withValues(alpha: 0.95),
                  strokeWidth: 1,
                  strokeColor: Colors.white.withValues(alpha: 0.9),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MemoFlowPalette.primary.withValues(alpha: 0.15),
                  MemoFlowPalette.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MonthlyChars> _normalizeYearPoints(List<MonthlyChars> input) {
    if (input.isEmpty) return const [];

    final sorted = [...input]..sort((a, b) => a.month.compareTo(b.month));
    final endMonth = DateTime(
      sorted.last.month.year,
      sorted.last.month.month,
      1,
    );
    final startMonth = DateTime(endMonth.year, endMonth.month - 11, 1);
    final totals = <DateTime, int>{};
    for (final item in sorted) {
      final key = DateTime(item.month.year, item.month.month, 1);
      totals[key] = (totals[key] ?? 0) + item.totalChars;
    }

    return List<MonthlyChars>.generate(12, (index) {
      final month = DateTime(startMonth.year, startMonth.month + index, 1);
      return MonthlyChars(month: month, totalChars: totals[month] ?? 0);
    });
  }
}

class _BottomMetricRowNew extends StatelessWidget {
  const _BottomMetricRowNew({
    required this.items,
    required this.card,
    required this.textMain,
    required this.textMuted,
  });

  final List<_MetricItemNew> items;
  final Color card;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _MiniStatCardNew(
              card: card,
              textMain: textMain,
              textMuted: textMuted,
              icon: items[i].icon,
              label: items[i].label,
              value: items[i].value,
              centerValue: items[i].centerValue,
              tooltip: items[i].tooltip,
            ),
          ),
          if (i < items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _BottomMetricWrapNew extends StatelessWidget {
  const _BottomMetricWrapNew({
    required this.items,
    required this.card,
    required this.textMain,
    required this.textMuted,
  });

  final List<_MetricItemNew> items;
  final Color card;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _MiniStatCardNew(
                  card: card,
                  textMain: textMain,
                  textMuted: textMuted,
                  icon: item.icon,
                  label: item.label,
                  value: item.value,
                  centerValue: item.centerValue,
                  tooltip: item.tooltip,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MiniStatCardNew extends StatelessWidget {
  const _MiniStatCardNew({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.icon,
    required this.label,
    required this.value,
    this.centerValue = false,
    this.tooltip,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final IconData icon;
  final String label;
  final String value;
  final bool centerValue;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 16, color: MemoFlowPalette.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (centerValue)
            Center(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: textMain,
                  height: 1,
                ),
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: textMain,
                height: 1,
              ),
            ),
        ],
      ),
    );
    final tip = tooltip?.trim();
    if (tip == null || tip.isEmpty) return content;
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(cursor: SystemMouseCursors.help, child: content),
    );
  }
}

class _MetricItemNew {
  const _MetricItemNew({
    required this.icon,
    required this.label,
    required this.value,
    this.centerValue = false,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool centerValue;
  final String? tooltip;
}

Color? _tryParseHexColorNew(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;

  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length != 6 && normalized.length != 8) return null;
  final intValue = int.tryParse(normalized, radix: 16);
  if (intValue == null) return null;
  if (normalized.length == 6) return Color(0xFF000000 | intValue);
  return Color(intValue);
}

enum _GrowthTrendNew { up, down, flat }

class _MonthGrowthSummaryNew {
  const _MonthGrowthSummaryNew({required this.text, required this.trend});

  final String text;
  final _GrowthTrendNew trend;
}

_MonthGrowthSummaryNew _buildMonthlyGrowthSummary({
  required BuildContext context,
  required int current,
  required int previous,
}) {
  if (previous <= 0) {
    if (current <= 0) {
      return _MonthGrowthSummaryNew(
        text: context.t.strings.legacy.msg_vs_last_month_same_memo_count,
        trend: _GrowthTrendNew.flat,
      );
    }
    return _MonthGrowthSummaryNew(
      text: context.t.strings.legacy.msg_vs_last_month_increase_memo_count,
      trend: _GrowthTrendNew.up,
    );
  }

  final delta = current - previous;
  if (delta == 0) {
    return _MonthGrowthSummaryNew(
      text: context.t.strings.legacy.msg_vs_last_month_same_memo_count,
      trend: _GrowthTrendNew.flat,
    );
  }

  return _MonthGrowthSummaryNew(
    text: delta > 0
        ? context.t.strings.legacy.msg_vs_last_month_increase_memo_count
        : context.t.strings.legacy.msg_vs_last_month_decrease_memo_count,
    trend: delta > 0 ? _GrowthTrendNew.up : _GrowthTrendNew.down,
  );
}

List<DateTime> _deriveMonths(Map<DateTime, int> dailyCounts) {
  final today = DateTime.now();
  var earliest = DateTime(today.year, today.month);
  var latest = earliest;
  for (final d in dailyCounts.keys) {
    final local = d.toLocal();
    final month = DateTime(local.year, local.month);
    if (month.isBefore(earliest)) earliest = month;
    if (month.isAfter(latest)) latest = month;
  }

  final months = <DateTime>[];
  var cursor = latest;
  while (!cursor.isBefore(earliest)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month - 1);
  }
  return months;
}

DateTime _clampDateToRange(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

BoxDecoration _buildCalendarSectionDecoration(
  Color card, {
  required bool isDark,
}) {
  return BoxDecoration(
    color: isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.02), card)
        : Color.alphaBlend(Colors.white.withValues(alpha: 0.3), card),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.03),
    ),
  );
}

String _formatCalendarMonthTitle(BuildContext context, DateTime month) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  try {
    return DateFormat.yMMMM(localeTag).format(month);
  } catch (_) {
    return _formatMonth(month);
  }
}

String _formatSelectedDayTitle(BuildContext context, DateTime day) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  try {
    return DateFormat.yMMMMd(localeTag).format(day);
  } catch (_) {
    return DateFormat('yyyy-MM-dd').format(day);
  }
}

List<String> _calendarWeekdayLabels(BuildContext context) {
  final localizations = MaterialLocalizations.of(context);
  final weekdays = localizations.narrowWeekdays;
  final firstDay = localizations.firstDayOfWeekIndex;
  return List<String>.generate(
    7,
    (index) => weekdays[(firstDay + index) % weekdays.length],
    growable: false,
  );
}

List<_CalendarDayData> _buildCalendarMonthDays(
  BuildContext context,
  DateTime month,
  Map<DateTime, int> dailyCounts,
) {
  final localizations = MaterialLocalizations.of(context);
  final firstDayOfMonth = DateTime(month.year, month.month, 1);
  final weekdayIndex = firstDayOfMonth.weekday % DateTime.daysPerWeek;
  final leadingDays =
      (weekdayIndex - localizations.firstDayOfWeekIndex + 7) % 7;
  final gridStart = DateTime(month.year, month.month, 1 - leadingDays);
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final maxCount = dailyCounts.values.fold<int>(
    0,
    (max, value) => math.max(max, value),
  );

  return List<_CalendarDayData>.generate(42, (index) {
    final day = DateTime(
      gridStart.year,
      gridStart.month,
      gridStart.day + index,
    );
    final isCurrentMonth = _sameMonth(day, month);
    final count = isCurrentMonth ? (dailyCounts[day] ?? 0) : 0;
    return _CalendarDayData(
      day: day,
      count: count,
      intensity: _resolveCalendarIntensity(count: count, maxCount: maxCount),
      isCurrentMonth: isCurrentMonth,
      isToday: DateUtils.isSameDay(day, normalizedToday),
    );
  }, growable: false);
}

int _resolveCalendarIntensity({required int count, required int maxCount}) {
  if (count <= 0 || maxCount <= 0) return 0;
  if (count >= maxCount) return 6;
  final ratio = count / maxCount;
  return (ratio * 6).ceil().clamp(1, 6);
}

Color _calendarCellFill({
  required int intensity,
  required bool isCurrentMonth,
  required bool isDark,
}) {
  if (!isCurrentMonth) {
    return Colors.transparent;
  }
  if (intensity <= 0) {
    return isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF7F3EE);
  }
  const lightAlphas = <double>[0.16, 0.24, 0.34, 0.46, 0.60, 0.78];
  const darkAlphas = <double>[0.22, 0.30, 0.40, 0.54, 0.68, 0.84];
  final alpha = isDark ? darkAlphas[intensity - 1] : lightAlphas[intensity - 1];
  return MemoFlowPalette.primary.withValues(alpha: alpha);
}

Color _calendarCellTextColor({
  required Color textMain,
  required Color textMuted,
  required int intensity,
  required bool isCurrentMonth,
}) {
  if (!isCurrentMonth) {
    return textMuted.withValues(alpha: 0.38);
  }
  if (intensity >= 4) {
    return Colors.white;
  }
  if (intensity > 0) {
    return textMain;
  }
  return textMuted.withValues(alpha: 0.88);
}

String _buildCalendarDayTooltip(
  BuildContext context, {
  required DateTime day,
  required int count,
}) {
  final dateLabel = DateFormat('yyyy-MM-dd').format(day);
  return context.tr(
    zh: '$dateLabel  ·  ${_formatNumber(count)} \u6761\u7b14\u8bb0',
    en: '$dateLabel · ${_formatNumber(count)} memos',
  );
}

Map<DateTime, int> _lastNDaysCounts(
  Map<DateTime, int> dailyCounts, {
  required int days,
}) {
  final todayLocal = DateTime.now();
  final endLocal = DateTime(todayLocal.year, todayLocal.month, todayLocal.day);
  final startLocal = endLocal.subtract(Duration(days: days - 1));
  return {
    for (final e in dailyCounts.entries)
      if (!e.key.isBefore(startLocal) && !e.key.isAfter(endLocal))
        e.key: e.value,
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
  var day = DateTime(todayLocal.year, todayLocal.month, todayLocal.day);
  var streak = 0;
  while (true) {
    final c = dailyCounts[day] ?? 0;
    if (c <= 0) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

int _longestStreakDays(Map<DateTime, int> dailyCounts) {
  if (dailyCounts.isEmpty) return 0;
  final days = dailyCounts.keys.toList()..sort();

  var longest = 0;
  var streak = 0;
  DateTime? previous;
  for (final day in days) {
    final count = dailyCounts[day] ?? 0;
    if (count <= 0) continue;

    if (previous != null && day.difference(previous).inDays == 1) {
      streak += 1;
    } else {
      streak = 1;
    }
    if (streak > longest) longest = streak;
    previous = day;
  }
  return longest;
}

int _averageCharsPerNaturalDay({
  required int totalChars,
  required int naturalDays,
}) {
  if (totalChars <= 0 || naturalDays <= 0) return 0;
  return (totalChars / naturalDays).round();
}

String _formatHourRange(int? hour) {
  if (hour == null || hour < 0 || hour > 23) return '--';
  final start = hour.toString().padLeft(2, '0');
  return '$start:00';
}

({int weekday, int count})? _mostActiveWeekday(Map<DateTime, int> dailyCounts) {
  if (dailyCounts.isEmpty) return null;
  final totals = List<int>.filled(7, 0);
  for (final entry in dailyCounts.entries) {
    final count = entry.value;
    if (count <= 0) continue;
    final weekday = entry.key.toLocal().weekday;
    if (weekday >= 1 && weekday <= 7) {
      totals[weekday - 1] += count;
    }
  }

  var bestWeekday = -1;
  var bestCount = 0;
  for (var i = 0; i < totals.length; i++) {
    final value = totals[i];
    if (value > bestCount) {
      bestWeekday = i + 1;
      bestCount = value;
    }
  }
  if (bestWeekday < 1 || bestCount <= 0) return null;
  return (weekday: bestWeekday, count: bestCount);
}

String _weekdayLabel(BuildContext context, int? weekday) {
  switch (weekday) {
    case DateTime.monday:
      return context.t.strings.legacy.msg_weekday_monday;
    case DateTime.tuesday:
      return context.t.strings.legacy.msg_weekday_tuesday;
    case DateTime.wednesday:
      return context.t.strings.legacy.msg_weekday_wednesday;
    case DateTime.thursday:
      return context.t.strings.legacy.msg_weekday_thursday;
    case DateTime.friday:
      return context.t.strings.legacy.msg_weekday_friday;
    case DateTime.saturday:
      return context.t.strings.legacy.msg_weekday_saturday;
    case DateTime.sunday:
      return context.t.strings.legacy.msg_weekday_sunday;
    default:
      return '--';
  }
}

String _formatMonth(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

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
  const _PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(37);
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
