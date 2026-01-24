import 'dart:ui';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/ai/ai_summary_service.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
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
  var _allowPrivate = false;
  var _isQuickPromptEditing = false;
  var _requestId = 0;
  AiSummaryResult? _summary;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    context.safePop();
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
          title: context.tr(zh: '回收站', en: 'Archive'),
          state: 'ARCHIVED',
          showDrawer: true,
        ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
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
    context.safePop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MemosListScreen(
          title: '#$tag',
          state: 'NORMAL',
          tag: tag,
          showDrawer: true,
          enableCompose: true,
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    context.safePop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
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
    final key =
        '${created.title}|${created.content}|${created.iconKey}'.toLowerCase();
    final exists = next.any(
      (p) =>
          '${p.title}|${p.content}|${p.iconKey}'.toLowerCase() == key,
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
    final initial = _customRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(
            const Duration(days: 6),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '请先在 AI 设置中填写 API Key', en: 'Please enter API Key in AI settings'))),
      );
      return;
    }
    if (settings.apiUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '请先在 AI 设置中填写 API URL', en: 'Please enter API URL in AI settings'))),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '该时间范围内没有可总结的笔记', en: 'No memos to summarize in this range'))),
        );
        return;
      }

      final result = await _aiService.generateSummary(
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
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: 'AI 总结失败：$e', en: 'AI summary failed: $e'))),
      );
    }
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
    final title = context.tr(zh: 'AI 总结报告', en: 'AI Summary Report');
    final header = forMemo ? '# $title' : title;
    final insights = summary.insights.isNotEmpty
        ? summary.insights
        : [context.tr(zh: '暂无总结结果', en: 'No summary yet')];
    final moodTrend = summary.moodTrend.isNotEmpty
        ? summary.moodTrend
        : context.tr(zh: '暂无情绪趋势', en: 'No mood trend');
    final keywordText = summary.keywords.isNotEmpty
        ? summary.keywords.map(_normalizeKeyword).join(' ')
        : context.tr(zh: '暂无关键词', en: 'No keywords');

    final buffer = StringBuffer();
    buffer.writeln(header);
    buffer.writeln('${context.tr(zh: '时间范围', en: 'Range')}: ${_rangeLabel()}');
    buffer.writeln('');
    buffer.writeln(context.tr(zh: '核心洞察', en: 'Key insights'));
    for (final insight in insights) {
      buffer.writeln('- $insight');
    }
    buffer.writeln('');
    buffer.writeln('${context.tr(zh: '情绪趋势', en: 'Mood trend')}: $moodTrend');
    buffer.writeln('');
    buffer.writeln('${context.tr(zh: '关键词', en: 'Keywords')}: $keywordText');
    return buffer.toString().trim();
  }

  Future<void> _shareReport() async {
    final summary = _summary;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '暂无可分享的总结', en: 'No summary to share'))),
      );
      return;
    }
    final text = _buildSummaryText(summary: summary, forMemo: false);
    try {
      await Share.share(
        text,
        subject: context.tr(zh: 'AI 总结报告', en: 'AI Summary Report'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '分享失败：$e', en: 'Share failed: $e'))),
      );
    }
  }

  Future<void> _sharePoster() async {
    final summary = _summary;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '暂无可分享的总结', en: 'No summary to share'))),
      );
      return;
    }
    final boundary = _reportBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '暂时无法生成海报', en: 'Poster is not ready yet'))),
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
          SnackBar(content: Text(context.tr(zh: '海报生成失败', en: 'Poster generation failed'))),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}ai_summary_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildSummaryText(summary: summary, forMemo: false),
        subject: context.tr(zh: 'AI 总结报告', en: 'AI Summary Report'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '分享失败：$e', en: 'Share failed: $e'))),
      );
    }
  }

  Future<void> _saveAsMemo() async {
    final summary = _summary;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '暂无可保存的总结', en: 'No summary to save'))),
      );
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
        syncState: 1,
      );
      await db.enqueueOutbox(type: 'create_memo', payload: {
        'uid': uid,
        'content': content,
        'visibility': 'PRIVATE',
        'pinned': false,
        'has_attachments': false,
      });
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '已保存为笔记', en: 'Saved as memo'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '保存失败：$e', en: 'Save failed: $e'))),
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

  Future<_MemoSource> _buildMemoSource() async {
    final range = _effectiveRange();
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final endExclusive = DateTime(range.end.year, range.end.month, range.end.day)
        .add(const Duration(days: 1));
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
      if (!_allowPrivate && visibility.toUpperCase() == 'PRIVATE') {
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
      title: Text(isReport ? context.tr(zh: 'AI 总结报告', en: 'AI Summary Report') : context.tr(zh: 'AI 总结', en: 'AI Summary')),
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
    final accentBlue = isDark
        ? MemoFlowPalette.aiChipBlueDark
        : MemoFlowPalette.aiChipBlueLight;
    final accentGreen = isDark ? const Color(0xFF86AD86) : const Color(0xFF6B8E6B);
    final primaryChip = isDark
        ? Color.alphaBlend(
            MemoFlowPalette.primary.withValues(alpha: 0.2),
            card,
          )
        : const Color(0xFFFDF1F0);
    final blueChip = isDark
        ? Color.alphaBlend(accentBlue.withValues(alpha: 0.18), card)
        : const Color(0xFFE8F1F8);
    final greenChip = isDark
        ? Color.alphaBlend(accentGreen.withValues(alpha: 0.18), card)
        : const Color(0xFFF1F6F1);
    final neutralChipText = textMain.withValues(alpha: 0.7);
    final isReport = _view == _AiSummaryView.report;
    final quickPrompts =
        ref.watch(aiSettingsProvider.select((s) => s.quickPrompts));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
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
                chipBg: chipBg,
                accentBlue: accentBlue,
                accentGreen: accentGreen,
                primaryChip: primaryChip,
                blueChip: blueChip,
                greenChip: greenChip,
                neutralChipText: neutralChipText,
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
                allowPrivate: _allowPrivate,
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
                context.tr(zh: '时间范围', en: 'Date range'),
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
                      onTap: () =>
                          setState(() => _range = _AiRange.last7Days),
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
                      onTap: () =>
                          setState(() => _range = _AiRange.last30Days),
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
                context.tr(zh: '总结指令 (可选)', en: 'Summary prompt (optional)'),
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
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: textMain,
                ),
                decoration: InputDecoration(
                  hintText: context.tr(zh: '输入你想总结的内容或指令...', en: 'Enter what you want to summarize...'),
                  hintStyle: TextStyle(
                    color: textMuted.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: border.withValues(alpha: 0.0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: border.withValues(alpha: 0.0)),
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
                      context.tr(zh: '允许发送私有权限笔记', en: 'Allow private memos'),
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
                      onChanged: (v) => setState(() => _allowPrivate = v),
                      activeColor: Colors.white,
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
              context.tr(zh: '快速提示词', en: 'Quick prompts'),
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
                  context.tr(zh: '管理', en: 'Manage'),
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
              textColor:
                  _isQuickPromptEditing ? MemoFlowPalette.primary : textMuted,
              label: _isQuickPromptEditing
                  ? context.tr(zh: '完成', en: 'Done')
                  : context.tr(zh: '添加', en: 'Add'),
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
    required Color chipBg,
    required Color accentBlue,
    required Color accentGreen,
    required Color primaryChip,
    required Color blueChip,
    required Color greenChip,
    required Color neutralChipText,
    required AiSummaryResult summary,
  }) {
    final insightTextColor = textMain.withValues(alpha: 0.9);
    final insights = summary.insights.isNotEmpty
        ? summary.insights
        : [context.tr(zh: '暂无总结结果', en: 'No summary yet')];
    final moodTrend = summary.moodTrend.isNotEmpty
        ? summary.moodTrend
        : context.tr(zh: '暂无情绪趋势', en: 'No mood trend');
    final rawKeywords = summary.keywords.isNotEmpty
        ? summary.keywords
        : [context.tr(zh: '暂无关键词', en: 'No keywords')];
    final keywords = <_KeywordData>[];
    for (var i = 0; i < rawKeywords.length; i++) {
      final label = _normalizeKeyword(rawKeywords[i]);
      if (i == 0) {
        keywords.add(_KeywordData(label, primaryChip, MemoFlowPalette.primary));
      } else if (i == 3) {
        keywords.add(_KeywordData(label, blueChip, accentBlue));
      } else if (i == 5) {
        keywords.add(_KeywordData(label, greenChip, accentGreen));
      } else {
        keywords.add(_KeywordData(label, chipBg, neutralChipText));
      }
    }

    return RepaintBoundary(
      key: _reportBoundaryKey,
      child: Container(
        color: bg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 200),
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _rangeLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: textMain.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 20,
                              color: MemoFlowPalette.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr(zh: '核心洞察', en: 'Key insights'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < insights.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _InsightBullet(
                            text: insights[i],
                            bulletColor: MemoFlowPalette.primary,
                            textColor: insightTextColor,
                          ),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insights, size: 20, color: accentBlue),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr(zh: '情绪趋势', en: 'Mood trend'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              moodTrend,
                              style: TextStyle(
                                fontSize: 12,
                                color: textMain.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MoodChart(
                          lineColor: MemoFlowPalette.primary,
                          background: chipBg,
                          textColor: textMain,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.label, size: 20, color: accentGreen),
                            const SizedBox(width: 8),
                            Text(
                              context.tr(zh: '关键词', en: 'Keywords'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final keyword in keywords)
                              _KeywordChip(
                                label: keyword.label,
                                background: keyword.background,
                                textColor: keyword.textColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          MemoFlowPalette.primary.withValues(alpha: 0.2),
                          MemoFlowPalette.primary.withValues(alpha: 0.06),
                          MemoFlowPalette.primary.withValues(alpha: 0.2),
                        ],
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
              colors: [
                bg,
                bg.withValues(alpha: 0.9),
                Colors.transparent,
              ],
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
                        ? context.tr(zh: '生成分享海报', en: 'Generate share poster')
                        : context.tr(zh: '开始生成总结', en: 'Generate summary'),
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
                    label: Text(context.tr(zh: '保存为笔记', en: 'Save as memo')),
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
                            backgroundColor:
                                MemoFlowPalette.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.tr(zh: '正在深度分析您的笔记...', en: 'Analyzing your memos...'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(zh: '预计还需 15 秒', en: 'About 15 seconds left'),
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
                      child: Text(context.tr(zh: '取消生成', en: 'Cancel')),
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

enum _AiRange {
  last7Days,
  last30Days,
  custom;
}

extension _AiRangeLabel on _AiRange {
  String labelFor(AppLanguage language) => switch (this) {
        _AiRange.last7Days => trByLanguage(language: language, zh: '最近一周', en: 'Last 7 days'),
        _AiRange.last30Days => trByLanguage(language: language, zh: '最近一月', en: 'Last 30 days'),
        _AiRange.custom => trByLanguage(language: language, zh: '自定义', en: 'Custom'),
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

  const _MemoSource.empty()
      : text = '',
        total = 0,
        included = 0;
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
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
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

class _InsightBullet extends StatelessWidget {
  const _InsightBullet({
    required this.text,
    required this.bulletColor,
    required this.textColor,
  });

  final String text;
  final Color bulletColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: bulletColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodChart extends StatelessWidget {
  const _MoodChart({
    required this.lineColor,
    required this.background,
    required this.textColor,
  });

  final Color lineColor;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _MoodChartPainter(
                    progress: value,
                    color: lineColor,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr(zh: '周一', en: 'Mon'),
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.3),
                ),
              ),
              Text(
                context.tr(zh: '周四', en: 'Thu'),
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.3),
                ),
              ),
              Text(
                context.tr(zh: '周末', en: 'Weekend'),
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodChartPainter extends CustomPainter {
  _MoodChartPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.17, h * 0.9, w * 0.33, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.1, w * 0.67, h * 0.3)
      ..quadraticBezierTo(w * 0.83, h * 0.5, w, h * 0.6);

    for (final metric in path.computeMetrics()) {
      final extract = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(extract, paint);
    }

    final dot = Offset(w * 0.67, h * 0.3);
    canvas.drawCircle(dot, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MoodChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _KeywordData {
  const _KeywordData(this.label, this.background, this.textColor);

  final String label;
  final Color background;
  final Color textColor;
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.background,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
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
