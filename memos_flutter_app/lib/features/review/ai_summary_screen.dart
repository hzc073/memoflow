import 'dart:ui';

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_localization.dart';
import '../../core/drawer_navigation.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/ai/ai_summary_service.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memo_markdown.dart';
import '../memos/memos_list_screen.dart';
import '../memos/recycle_bin_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../../state/ai_settings_provider.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import 'daily_review_screen.dart';
import 'quick_prompt_editor_screen.dart';
import '../../i18n/strings.g.dart';

class AiSummaryScreen extends ConsumerStatefulWidget {
  const AiSummaryScreen({super.key});

  @override
  ConsumerState<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

enum _AiSummaryView { input, report }

class _AiSummaryScreenState extends ConsumerState<AiSummaryScreen> {
  final _promptController = TextEditingController();
  final _aiService = AiSummaryService();
  final _reportBoundaryKey = GlobalKey();
  var _range = _AiRange.last7Days;
  DateTimeRange? _customRange;
  var _view = _AiSummaryView.input;
  var _isLoading = false;
  var _isQuickPromptEditing = false;
  var _requestId = 0;
  AiSummaryResult? _summary;
  var _insightExpanded = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    final route = switch (dest) {
      AppDrawerDestination.memos => const MemosListScreen(
        title: 'MemoFlow',
        state: 'NORMAL',
        showDrawer: true,
        enableCompose: true,
      ),
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.explore => const ExploreScreen(),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
        title: context.t.strings.legacy.msg_archive,
        state: 'ARCHIVED',
        showDrawer: true,
      ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.recycleBin => const RecycleBinScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    closeDrawerThenPushReplacement(context, route);
  }

  void _backToAllMemos(BuildContext context) {
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

  void _openTag(BuildContext context, String tag) {
    closeDrawerThenPushReplacement(
      context,
      MemosListScreen(
        title: '#$tag',
        state: 'NORMAL',
        tag: tag,
        showDrawer: true,
        enableCompose: true,
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  void _applyPrompt(String text) {
    _promptController.text = text;
    _promptController.selection = TextSelection.fromPosition(
      TextPosition(offset: _promptController.text.length),
    );
  }

  void _enterQuickPromptEditing() {
    if (_isQuickPromptEditing) return;
    setState(() => _isQuickPromptEditing = true);
  }

  void _exitQuickPromptEditing() {
    if (!_isQuickPromptEditing) return;
    setState(() => _isQuickPromptEditing = false);
  }

  Future<void> _addQuickPrompt() async {
    FocusScope.of(context).unfocus();
    final created = await Navigator.of(context).push<AiQuickPrompt>(
      MaterialPageRoute<AiQuickPrompt>(
        builder: (_) => const QuickPromptEditorScreen(),
      ),
    );
    if (!mounted || created == null) return;
    final settings = ref.read(aiSettingsProvider);
    final next = [...settings.quickPrompts];
    final key = '${created.title}|${created.content}|${created.iconKey}'
        .toLowerCase();
    final exists = next.any(
      (p) => '${p.title}|${p.content}|${p.iconKey}'.toLowerCase() == key,
    );
    if (!exists) {
      next.add(created);
      await ref
          .read(aiSettingsProvider.notifier)
          .setAll(settings.copyWith(quickPrompts: next));
    }
    if (!mounted) return;
    final content = created.content.trim().isNotEmpty
        ? created.content.trim()
        : created.title.trim();
    if (content.isNotEmpty) {
      _applyPrompt(content);
    }
  }

  Future<void> _removeQuickPrompt(AiQuickPrompt prompt) async {
    final settings = ref.read(aiSettingsProvider);
    bool same(AiQuickPrompt a, AiQuickPrompt b) {
      return a.title == b.title &&
          a.content == b.content &&
          a.iconKey == b.iconKey;
    }

    final next = settings.quickPrompts.where((p) => !same(p, prompt)).toList();
    await ref
        .read(aiSettingsProvider.notifier)
        .setAll(settings.copyWith(quickPrompts: next));
    if (!mounted) return;
    if (next.isEmpty) {
      setState(() => _isQuickPromptEditing = false);
    }
  }

  Future<DateTimeRange?> _pickCustomRange() {
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

  Future<void> _handleCustomRangeTap() async {
    final previous = _range;
    final picked = await _pickCustomRange();
    if (!mounted) return;
    if (picked == null) {
      setState(() => _range = previous);
      return;
    }
    setState(() {
      _customRange = picked;
      _range = _AiRange.custom;
    });
  }

  Future<void> _startSummary() async {
    if (_isLoading) return;
    final settings = ref.read(aiSettingsProvider);
    if (settings.apiKey.trim().isEmpty) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_enter_api_key_ai_settings,
      );
      return;
    }
    if (settings.apiUrl.trim().isEmpty) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_enter_api_url_ai_settings,
      );
      return;
    }

    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    try {
      final memoSource = await _buildMemoSource();
      if (!mounted || !_isLoading || requestId != _requestId) return;
      if (memoSource.text.trim().isEmpty) {
        setState(() => _isLoading = false);
        showTopToast(
          context,
          context.t.strings.legacy.msg_no_memos_summarize_range,
        );
        return;
      }

      final result = await _aiService.generateSummary(
        language: context.appLanguage,
        settings: settings,
        memoText: memoSource.text,
        rangeLabel: _rangeLabel(),
        memoCount: memoSource.total,
        includedCount: memoSource.included,
        customPrompt: _promptController.text.trim(),
      );
      if (!mounted || !_isLoading || requestId != _requestId) return;
      setState(() {
        _summary = result;
        _view = _AiSummaryView.report;
        _isLoading = false;
        _insightExpanded = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_ai_summary_failed(
              formatSummaryError_e: _formatSummaryError(e),
            ),
          ),
        ),
      );
    }
  }

  String _formatSummaryError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return context
              .t
              .strings
              .legacy
              .msg_connection_timeout_check_network_api_url;
        case DioExceptionType.sendTimeout:
          return context.t.strings.legacy.msg_request_send_timeout_try;
        case DioExceptionType.receiveTimeout:
          return context.t.strings.legacy.msg_server_response_timeout_try;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          if (code == 401 || code == 403) {
            return context
                .t
                .strings
                .legacy
                .msg_invalid_api_key_insufficient_permissions;
          }
          if (code == 404) {
            return context.t.strings.legacy.msg_api_url_incorrect;
          }
          if (code == 429) {
            return context.t.strings.legacy.msg_too_many_requests_try_later;
          }
          if (code != null) {
            return context.t.strings.legacy.msg_server_returned_error(
              code: code,
            );
          }
          return context.t.strings.legacy.msg_server_response_error;
        case DioExceptionType.connectionError:
          return context.t.strings.legacy.msg_network_connection_failed;
        case DioExceptionType.cancel:
          return context.t.strings.legacy.msg_request_cancelled;
        case DioExceptionType.badCertificate:
          return context.t.strings.legacy.msg_bad_ssl_certificate;
        case DioExceptionType.unknown:
          break;
      }
      return error.message ?? error.toString();
    }
    return error.toString();
  }

  void _cancelSummary() {
    if (!_isLoading) return;
    setState(() {
      _isLoading = false;
      _requestId++;
    });
  }

  String _buildSummaryText({
    required AiSummaryResult summary,
    required bool forMemo,
  }) {
    final title = context.t.strings.legacy.msg_ai_summary_report;
    final header = forMemo ? '# $title' : title;
    final insights = summary.insights.isNotEmpty
        ? summary.insights
        : [context.t.strings.legacy.msg_no_summary_yet];
    final moodTrend = summary.moodTrend.isNotEmpty
        ? summary.moodTrend
        : context.t.strings.legacy.msg_no_mood_trend;
    final keywordText = summary.keywords.isNotEmpty
        ? summary.keywords.map(_normalizeKeyword).join(' ')
        : context.t.strings.legacy.msg_no_keywords;

    final buffer = StringBuffer();
    buffer.writeln(header);
    buffer.writeln('${context.t.strings.legacy.msg_range}: ${_rangeLabel()}');
    buffer.writeln('');
    buffer.writeln(context.t.strings.legacy.msg_key_insights);
    for (final insight in insights) {
      buffer.writeln('- $insight');
    }
    buffer.writeln('');
    buffer.writeln('${context.t.strings.legacy.msg_mood_trend}: $moodTrend');
    buffer.writeln('');
    buffer.writeln('${context.t.strings.legacy.msg_keywords}: $keywordText');
    return buffer.toString().trim();
  }

  Future<void> _shareReport() async {
    final summary = _summary;
    if (summary == null) {
      showTopToast(context, context.t.strings.legacy.msg_no_summary_share);
      return;
    }
    final text = _buildSummaryText(summary: summary, forMemo: false);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: context.t.strings.legacy.msg_ai_summary_report,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_share_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _sharePoster() async {
    final summary = _summary;
    if (summary == null) {
      showTopToast(context, context.t.strings.legacy.msg_no_summary_share);
      return;
    }
    final boundary = _reportBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      showTopToast(context, context.t.strings.legacy.msg_poster_not_ready_yet);
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      final pixelRatio = MediaQuery.of(
        context,
      ).devicePixelRatio.clamp(2.0, 3.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_poster_generation_failed,
            ),
          ),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}ai_summary_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: _buildSummaryText(summary: summary, forMemo: false),
          subject: context.t.strings.legacy.msg_ai_summary_report,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_share_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _saveAsMemo() async {
    final summary = _summary;
    if (summary == null) {
      showTopToast(context, context.t.strings.legacy.msg_no_summary_save);
      return;
    }

    final content = _buildSummaryText(summary: summary, forMemo: true);
    final uid = generateUid();
    final now = DateTime.now();
    final tags = extractTags(content);
    final db = ref.read(databaseProvider);

    try {
      await db.upsertMemo(
        uid: uid,
        content: content,
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: tags,
        attachments: const [],
        location: null,
        relationCount: 0,
        syncState: 1,
      );
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': uid,
          'content': content,
          'visibility': 'PRIVATE',
          'pinned': false,
          'has_attachments': false,
        },
      );
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_saved_memo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
        ),
      );
    }
  }

  DateTimeRange _effectiveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_range == _AiRange.custom && _customRange != null) {
      return _customRange!;
    }
    if (_range == _AiRange.last30Days) {
      return DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      );
    }
    return DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
  }

  String _rangeLabel() {
    final fmt = DateFormat('yyyy.MM.dd');
    final range = _effectiveRange();
    return '${fmt.format(range.start)} - ${fmt.format(range.end)}';
  }

  String _reportTitle() {
    final range = _effectiveRange();
    final days = range.end.difference(range.start).inDays + 1;
    if (_range == _AiRange.last7Days || days <= 7) {
      return context.t.strings.legacy.msg_week;
    }
    if (_range == _AiRange.last30Days || days <= 31) {
      return context.t.strings.legacy.msg_month;
    }
    return context.t.strings.legacy.msg_period_review;
  }

  String _reportRangeLabel() {
    final range = _effectiveRange();
    final locale = Localizations.localeOf(context).toString();
    final sameYear = range.start.year == range.end.year;
    final sameMonth = sameYear && range.start.month == range.end.month;
    final startFmt = sameYear
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    final endFmt = sameYear
        ? (sameMonth ? DateFormat.d(locale) : DateFormat.MMMd(locale))
        : DateFormat.yMMMd(locale);
    return '${startFmt.format(range.start)} - ${endFmt.format(range.end)}';
  }

  String _buildInsightMarkdown(AiSummaryResult summary) {
    final insights = summary.insights.isNotEmpty
        ? summary.insights
        : [context.t.strings.legacy.msg_no_summary_yet];
    final moodTrend = summary.moodTrend.isNotEmpty
        ? summary.moodTrend
        : context.t.strings.legacy.msg_no_mood_trend;
    final buffer = StringBuffer();
    buffer.writeln('### ${context.t.strings.legacy.msg_key_insights}');
    buffer.writeln('');
    buffer.writeln('> ${context.t.strings.legacy.msg_intro}: $moodTrend');
    buffer.writeln('');
    for (var i = 0; i < insights.length; i++) {
      final text = insights[i].trim();
      if (text.isEmpty) continue;
      if (i == 0) {
        buffer.writeln('- **$text**');
      } else {
        buffer.writeln('- $text');
      }
    }
    return buffer.toString().trim();
  }

  Future<_MemoSource> _buildMemoSource() async {
    final range = _effectiveRange();
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final endExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));
    final allowPrivate = ref
        .read(appPreferencesProvider)
        .aiSummaryAllowPrivateMemos;
    final db = ref.read(databaseProvider);
    final rows = await db.listMemosForExport(
      startTimeSec: start.toUtc().millisecondsSinceEpoch ~/ 1000,
      endTimeSecExclusive: endExclusive.toUtc().millisecondsSinceEpoch ~/ 1000,
    );
    if (rows.isEmpty) {
      return const _MemoSource.empty();
    }

    final buffer = StringBuffer();
    var total = 0;
    var included = 0;
    for (final row in rows) {
      final visibility = (row['visibility'] as String?)?.trim() ?? 'PRIVATE';
      if (!allowPrivate && visibility.toUpperCase() == 'PRIVATE') {
        continue;
      }
      final content = (row['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) continue;
      total += 1;
      final createdSec = (row['create_time'] as int?) ?? 0;
      final created = DateTime.fromMillisecondsSinceEpoch(
        createdSec * 1000,
        isUtc: true,
      ).toLocal();
      final stamp = DateFormat('yyyy-MM-dd').format(created);
      final line = '[$stamp] $content';
      if (buffer.length + line.length + 1 > _MemoSource.maxChars) {
        break;
      }
      buffer.writeln(line);
      included += 1;
    }

    return _MemoSource(
      text: buffer.toString().trim(),
      total: total,
      included: included,
    );
  }

  PreferredSizeWidget _buildAppBar({
    required BuildContext context,
    required bool isReport,
    required Color bg,
    required Color border,
    required Color textMain,
  }) {
    return AppBar(
      title: Text(
        isReport
            ? context.t.strings.legacy.msg_ai_summary_report
            : context.t.strings.legacy.msg_ai_summary,
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        color: textMain,
        onPressed: () => _backToAllMemos(context),
      ),
      actions: isReport
          ? [
              IconButton(
                icon: const Icon(Icons.share),
                color: MemoFlowPalette.primary,
                onPressed: _shareReport,
              ),
            ]
          : null,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: bg.withValues(alpha: 0.9)),
        ),
      ),
      bottom: isReport
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: border.withValues(alpha: 0.6)),
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
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.5);
    final chipBg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final inputBg = chipBg;
    final isReport = _view == _AiSummaryView.report;
    final quickPrompts = ref.watch(
      aiSettingsProvider.select((s) => s.quickPrompts),
    );
    final allowPrivate = ref.watch(
      appPreferencesProvider.select((p) => p.aiSummaryAllowPrivateMemos),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        drawer: AppDrawer(
          selected: AppDrawerDestination.aiSummary,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: _buildAppBar(
          context: context,
          isReport: isReport,
          bg: bg,
          border: border,
          textMain: textMain,
        ),
        body: Stack(
          children: [
            if (isReport)
              _buildReportBody(
                bg: bg,
                card: card,
                border: border,
                textMain: textMain,
                textMuted: textMuted,
                summary: _summary ?? AiSummaryResult.empty,
              )
            else
              _buildInputBody(
                card: card,
                border: border,
                textMain: textMain,
                textMuted: textMuted,
                chipBg: chipBg,
                inputBg: inputBg,
                quickPrompts: quickPrompts,
                allowPrivate: allowPrivate,
                onAllowPrivateChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setAiSummaryAllowPrivateMemos(v),
              ),
            _buildBottomBar(
              isReport: isReport,
              bg: bg,
              border: border,
              textMain: textMain,
              card: card,
            ),
            if (_isLoading)
              _buildLoadingOverlay(
                bg: bg,
                textMain: textMain,
                textMuted: textMuted,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBody({
    required Color card,
    required Color border,
    required Color textMain,
    required Color textMuted,
    required Color chipBg,
    required Color inputBg,
    required List<AiQuickPrompt> quickPrompts,
    required bool allowPrivate,
    required ValueChanged<bool> onAllowPrivateChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveTrack = border.withValues(alpha: isDark ? 0.6 : 1);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t.strings.legacy.msg_date_range_3,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AiRangeButton(
                      label: _AiRange.last7Days.labelFor(context.appLanguage),
                      selected: _range == _AiRange.last7Days,
                      onTap: () => setState(() => _range = _AiRange.last7Days),
                      primary: MemoFlowPalette.primary,
                      background: chipBg,
                      borderColor: border,
                      textColor: textMain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiRangeButton(
                      label: _AiRange.last30Days.labelFor(context.appLanguage),
                      selected: _range == _AiRange.last30Days,
                      onTap: () => setState(() => _range = _AiRange.last30Days),
                      primary: MemoFlowPalette.primary,
                      background: chipBg,
                      borderColor: border,
                      textColor: textMain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiRangeButton(
                      label: _AiRange.custom.labelFor(context.appLanguage),
                      selected: _range == _AiRange.custom,
                      onTap: _handleCustomRangeTap,
                      primary: MemoFlowPalette.primary,
                      background: chipBg,
                      borderColor: border,
                      textColor: textMain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                context.t.strings.legacy.msg_summary_prompt_optional,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _promptController,
                minLines: 4,
                maxLines: 4,
                style: TextStyle(fontSize: 15, height: 1.5, color: textMain),
                decoration: InputDecoration(
                  hintText:
                      context.t.strings.legacy.msg_enter_what_want_summarize,
                  hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: border.withValues(alpha: 0.0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: border.withValues(alpha: 0.0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: MemoFlowPalette.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: border.withValues(alpha: 0.6)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t.strings.legacy.msg_allow_private_memos,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: allowPrivate,
                      onChanged: onAllowPrivateChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: MemoFlowPalette.primary,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: inactiveTrack,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Text(
              context.t.strings.legacy.msg_quick_prompts,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: textMuted,
              ),
            ),
            const Spacer(),
            if (quickPrompts.isNotEmpty && !_isQuickPromptEditing)
              TextButton(
                onPressed: _enterQuickPromptEditing,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.t.strings.legacy.msg_manage,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MemoFlowPalette.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final prompt in quickPrompts)
              _QuickPromptChip(
                label: prompt.title.trim().isNotEmpty
                    ? prompt.title.trim()
                    : prompt.content.trim(),
                background: card,
                borderColor: border,
                textColor: textMain,
                accent: MemoFlowPalette.primary,
                icon: QuickPromptIconCatalog.resolve(prompt.iconKey),
                editing: _isQuickPromptEditing,
                onDelete: _isQuickPromptEditing
                    ? () => _removeQuickPrompt(prompt)
                    : null,
                onLongPress: _enterQuickPromptEditing,
                onTap: () {
                  final content = prompt.content.trim().isNotEmpty
                      ? prompt.content.trim()
                      : prompt.title.trim();
                  if (content.isNotEmpty) {
                    _applyPrompt(content);
                  }
                },
              ),
            _QuickPromptAddChip(
              borderColor: border,
              textColor: _isQuickPromptEditing
                  ? MemoFlowPalette.primary
                  : textMuted,
              label: _isQuickPromptEditing
                  ? context.t.strings.legacy.msg_done
                  : context.t.strings.legacy.msg_add_2,
              icon: _isQuickPromptEditing ? Icons.check : Icons.add,
              onTap: _isQuickPromptEditing
                  ? _exitQuickPromptEditing
                  : _addQuickPrompt,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportBody({
    required Color bg,
    required Color card,
    required Color border,
    required Color textMain,
    required Color textMuted,
    required AiSummaryResult summary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportBg = isDark ? bg : const Color(0xFFF7F2EA);
    final reportCard = isDark ? card : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? border : border.withValues(alpha: 0.7);
    final moodWarm = const Color(0xFFF2A167);
    final moodDeep = const Color(0xFFE98157);
    final moodLight = const Color(0xFFF7C796);
    final moodChipBg = moodWarm.withValues(alpha: isDark ? 0.25 : 0.2);
    final moodChipBorder = moodWarm.withValues(alpha: isDark ? 0.45 : 0.35);
    final moodChipText = isDark
        ? textMain.withValues(alpha: 0.9)
        : const Color(0xFF6B5344);
    final title = _reportTitle();
    final dateLabel = _reportRangeLabel();
    final rawKeywords = summary.keywords.isNotEmpty
        ? summary.keywords
        : [context.t.strings.legacy.msg_no_keywords_2];
    final keywords = rawKeywords.map(_normalizeKeyword).toList(growable: false);
    final insightMarkdown = _buildInsightMarkdown(summary);
    final shouldCollapse = insightMarkdown.length > 260;
    final showCollapsed = shouldCollapse && !_insightExpanded;
    final insightStyle = TextStyle(
      fontSize: 14,
      height: 1.7,
      color: textMain.withValues(alpha: isDark ? 0.85 : 0.82),
    );
    Widget insightContent = MemoMarkdown(
      data: insightMarkdown,
      textStyle: insightStyle,
      blockSpacing: 10,
      shrinkWrap: true,
    );
    if (showCollapsed) {
      insightContent = SizedBox(
        height: 260,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: insightContent,
        ),
      );
    }
    final headerTextColor = isDark ? MemoFlowPalette.textLight : textMain;
    final headerTextMuted = headerTextColor.withValues(alpha: 0.6);

    return RepaintBoundary(
      key: _reportBoundaryKey,
      child: Container(
        color: reportBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 200),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: reportCard,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 190,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFF4E8), Color(0xFFFFE7D6)],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                center: Alignment(-0.2, -0.2),
                                radius: 0.9,
                                colors: [
                                  Color(0xFFFBD7B1),
                                  Color(0xFFF4A96F),
                                  Color(0xFFE97B57),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: moodWarm.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 30,
                          top: 24,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  moodLight.withValues(alpha: 0.9),
                                  moodWarm.withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 28,
                          bottom: 26,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  moodWarm.withValues(alpha: 0.8),
                                  moodDeep.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: headerTextColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: headerTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final keyword in keywords)
                          _KeywordChip(
                            label: keyword,
                            background: moodChipBg,
                            textColor: moodChipText,
                            borderColor: moodChipBorder,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                    child: Stack(
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          child: ClipRect(child: insightContent),
                        ),
                        if (showCollapsed)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 70,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    reportCard.withValues(alpha: 0.0),
                                    reportCard,
                                  ],
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() => _insightExpanded = true);
                                  },
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                  ),
                                  label: Text(
                                    context.t.strings.legacy.msg_expand_2,
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: textMain.withValues(
                                      alpha: 0.65,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Center(
                      child: Text(
                        context.t.strings.legacy.msg_generated_ai_memoflow,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required bool isReport,
    required Color bg,
    required Color border,
    required Color textMain,
    required Color card,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [bg, bg.withValues(alpha: 0.9), Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: isReport ? _sharePoster : _startSummary,
                  icon: Icon(
                    isReport ? Icons.palette : Icons.auto_awesome,
                    size: 20,
                  ),
                  label: Text(
                    isReport
                        ? context.t.strings.legacy.msg_generate_share_poster
                        : context.t.strings.legacy.msg_generate_summary,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MemoFlowPalette.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (isReport) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _saveAsMemo,
                    icon: const Icon(Icons.save_as, size: 20),
                    label: Text(context.t.strings.legacy.msg_save_memo),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textMain,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      backgroundColor: card,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeKeyword(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('#')) return trimmed;
    return '#$trimmed';
  }

  Widget _buildLoadingOverlay({
    required Color bg,
    required Color textMain,
    required Color textMuted,
  }) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: bg.withValues(alpha: 0.4),
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              MemoFlowPalette.primary,
                            ),
                            backgroundColor: MemoFlowPalette.primary.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.t.strings.legacy.msg_analyzing_memos,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.t.strings.legacy.msg_about_15_seconds_left,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: TextButton(
                      onPressed: _cancelSummary,
                      style: TextButton.styleFrom(
                        foregroundColor: textMain.withValues(alpha: 0.4),
                      ),
                      child: Text(context.t.strings.legacy.msg_cancel),
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

enum _AiRange { last7Days, last30Days, custom }

extension _AiRangeLabel on _AiRange {
  String labelFor(AppLanguage language) => switch (this) {
    _AiRange.last7Days => trByLanguageKey(
      language: language,
      key: 'legacy.msg_last_7_days',
    ),
    _AiRange.last30Days => trByLanguageKey(
      language: language,
      key: 'legacy.msg_last_30_days',
    ),
    _AiRange.custom => trByLanguageKey(
      language: language,
      key: 'legacy.msg_custom',
    ),
  };
}

class _MemoSource {
  const _MemoSource({
    required this.text,
    required this.total,
    required this.included,
  });

  final String text;
  final int total;
  final int included;

  static const maxChars = 12000;

  const _MemoSource.empty() : text = '', total = 0, included = 0;
}

class _AiRangeButton extends StatelessWidget {
  const _AiRangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    required this.background,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;
  final Color background;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary : background,
            borderRadius: BorderRadius.circular(12),
            border: selected ? null : Border.all(color: borderColor),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.label,
    required this.background,
    required this.borderColor,
    required this.textColor,
    required this.accent,
    required this.icon,
    required this.editing,
    required this.onDelete,
    required this.onLongPress,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color borderColor;
  final Color textColor;
  final Color accent;
  final IconData icon;
  final bool editing;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final decorated = editing
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              content,
              if (onDelete != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE05656),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          )
        : content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: editing ? null : onTap,
        onLongPress: editing ? null : onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: decorated,
      ),
    );
  }
}

class _QuickPromptAddChip extends StatelessWidget {
  const _QuickPromptAddChip({
    required this.borderColor,
    required this.textColor,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final Color borderColor;
  final Color textColor;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.background,
    required this.textColor,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
