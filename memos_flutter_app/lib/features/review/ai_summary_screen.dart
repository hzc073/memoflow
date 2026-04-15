import 'dart:ui';

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/desktop_window_controls.dart';
import '../../core/drawer_navigation.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/top_toast.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/ai/ai_analysis_models.dart';
import '../../data/ai/ai_provider_models.dart';
import '../../data/ai/ai_route_config.dart';
import '../../data/ai/ai_settings_models.dart';
import '../../data/models/local_memo.dart';
import '../../state/memos/memo_mutation_service.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/app_drawer_menu_button.dart';
import '../home/home_navigation_host.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/ai_settings_screen.dart';
import '../../state/settings/ai_settings_provider.dart';
import '../../state/review/ai_analysis_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import 'ai_insight_history_shared.dart';
import 'ai_insight_models.dart';
import 'ai_insight_history_screen.dart';
import 'ai_insight_settings_sheet.dart';
import 'ai_insight_prompt_editor_screen.dart';
import 'quick_prompt_editor_screen.dart';
import '../../i18n/strings.g.dart';

class AiSummaryScreen extends ConsumerStatefulWidget {
  const AiSummaryScreen({
    super.key,
    this.initialHistorySelection,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
  });

  final AiInsightHistorySelection? initialHistorySelection;
  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  @override
  ConsumerState<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

enum _AiSummaryView { input, report }

class _AiSummaryScreenState extends ConsumerState<AiSummaryScreen> {
  final _reportBoundaryKey = GlobalKey();
  var _range = AiInsightRange.last7Days;
  DateTimeRange? _customRange;
  var _view = _AiSummaryView.input;
  var _isLoading = false;
  var _requestId = 0;
  var _selectedInsightId = AiInsightId.emotionMap;
  String? _selectedInsightTitleOverride;
  AiSavedAnalysisReport? _analysisReport;
  var _referencesExpanded = false;
  var _analysisProgress = 0.0;
  DateTimeRange? _reportRangeOverride;

  @override
  void initState() {
    super.initState();
    final initialSelection = widget.initialHistorySelection;
    if (initialSelection == null) return;
    _analysisReport = initialSelection.report;
    _view = _AiSummaryView.report;
    _selectedInsightId = initialSelection.insightId;
    _selectedInsightTitleOverride = initialSelection.titleOverride?.trim();
    _reportRangeOverride = initialSelection.range;
  }

  AiInsightDefinition get _selectedInsightDefinition =>
      definitionForInsight(_selectedInsightId);

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerDestination(context, dest);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: dest),
    );
  }

  void _backToAllMemos(BuildContext context) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleBackToPrimaryDestination(context);
      return;
    }
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

  void _backToInsightInput() {
    if (_isLoading || _view != _AiSummaryView.report) {
      return;
    }

    setState(() {
      _view = _AiSummaryView.input;
      _referencesExpanded = false;
      _reportRangeOverride = null;
    });
  }

  void _toggleReferencesExpanded() {
    setState(() {
      _referencesExpanded = !_referencesExpanded;
    });
  }

  void _openTag(BuildContext context, String tag) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerTag(context, tag);
      return;
    }
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
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleOpenNotifications(context);
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  Future<void> _openAiSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<DateTimeRange?> _pickCustomRange(
    BuildContext pickerContext,
    DateTimeRange? currentRange,
  ) {
    final now = DateTime.now();
    final initial =
        currentRange ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day),
        );
    return showDateRangePicker(
      context: pickerContext,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
  }

  Future<void> _openInsightSettings(AiInsightDefinition definition) async {
    if (_isLoading) return;
    final result = await showDialog<AiInsightSettingsResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AiInsightSettingsSheet(
          definition: definition,
          analysisLoading: _isLoading,
          customRangePicker: _pickCustomRange,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _runAnalysis(result);
  }

  Future<void> _openCustomTemplateEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AiInsightPromptEditorScreen.custom(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openCustomInsightSettings() async {
    if (_isLoading) return;
    final customTemplate = ref.read(aiSettingsProvider).customInsightTemplate;
    if (!customTemplate.isConfigured) {
      await _openCustomTemplateEditor();
      return;
    }
    final result = await showDialog<AiInsightSettingsResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AiInsightSettingsSheet(
          definition: customAiInsightDefinition,
          customTitle: customTemplate.title,
          customTemplateMode: true,
          analysisLoading: _isLoading,
          customRangePicker: _pickCustomRange,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _runAnalysis(result, titleOverride: customTemplate.title);
  }

  Future<void> _openInsightHistory() async {
    if (_isLoading) return;
    final selection = await Navigator.of(context)
        .push<AiInsightHistorySelection>(
          MaterialPageRoute<AiInsightHistorySelection>(
            builder: (_) => const AiInsightHistoryScreen(),
          ),
        );
    if (!mounted || selection == null) return;
    setState(() {
      _analysisReport = selection.report;
      _view = _AiSummaryView.report;
      _isLoading = false;
      _analysisProgress = 0.0;
      _referencesExpanded = false;
      _selectedInsightId = selection.insightId;
      _selectedInsightTitleOverride = selection.titleOverride?.trim();
      _reportRangeOverride = selection.range;
    });
  }

  Future<void> _runAnalysis(
    AiInsightSettingsResult result, {
    String? titleOverride,
  }) async {
    if (_isLoading) return;
    final settings = ref.read(aiSettingsProvider);
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final hasGenerationConfig = hasConfiguredChatRoute(
      settings,
      routeId: AiTaskRouteId.analysisReport,
    );
    final hasEmbeddingConfig = hasConfiguredEmbeddingRoute(settings);
    if (!hasGenerationConfig) {
      showTopToast(
        context,
        _aiConfigPrimaryMessage(
          isZh: isZh,
          hasGenerationConfig: hasGenerationConfig,
          hasEmbeddingConfig: hasEmbeddingConfig,
        ),
      );
      return;
    }
    if (!hasEmbeddingConfig) {
      showTopToast(context, _embeddingDegradedMessage(isZh: isZh));
    }

    final requestId = ++_requestId;
    setState(() {
      _range = result.range;
      _customRange = result.customRange;
      _selectedInsightId = result.insightId;
      _selectedInsightTitleOverride = titleOverride?.trim();
      _reportRangeOverride = null;
      _isLoading = true;
      _analysisProgress = 0.06;
    });
    try {
      if (!mounted || !_isLoading || requestId != _requestId) return;
      final analysisResult = await ref
          .read(aiAnalysisServiceProvider)
          .generateEmotionMap(
            language: context.appLanguage,
            settings: settings,
            range: resolveAiInsightRange(result.range, result.customRange),
            includePublic: result.allowPublic,
            includePrivate: result.allowPrivate,
            includeProtected: result.allowProtected,
            promptTemplate: result.promptTemplate.trim(),
            onProgress: (progress) {
              if (!mounted || !_isLoading || requestId != _requestId) return;
              setState(() {
                _analysisProgress = progress.clamp(0.0, 1.0);
              });
            },
          );
      if (!mounted || !_isLoading || requestId != _requestId) return;
      setState(() {
        _analysisReport = analysisResult;
        _view = _AiSummaryView.report;
        _isLoading = false;
        _analysisProgress = 0.0;
        _referencesExpanded = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isLoading = false;
        _analysisProgress = 0.0;
      });
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

  String _aiConfigPrimaryMessage({
    required bool isZh,
    required bool hasGenerationConfig,
    required bool hasEmbeddingConfig,
  }) {
    if (!hasGenerationConfig && !hasEmbeddingConfig) {
      return isZh
          ? 'AI \u8fd8\u6ca1\u6709\u914d\u7f6e\uff0c\u8bf7\u5148\u914d\u7f6e chat \u6a21\u578b\u3002'
          : 'AI is not configured yet. Please configure a chat model first.';
    }
    return isZh
        ? '\u8bf7\u5148\u914d\u7f6e\u53ef\u7528\u7684 chat \u6a21\u578b\u3002'
        : 'Please configure a working chat model first.';
  }

  String _embeddingDegradedMessage({required bool isZh}) {
    return isZh
        ? '\u5f53\u524d\u672a\u914d\u7f6e\u5411\u91cf\u6a21\u578b\uff0c\u4ecd\u53ef\u4ee5\u751f\u6210 AI \u603b\u7ed3\uff0c\u4f46\u5206\u6790\u51c6\u786e\u5ea6\u4f1a\u964d\u4f4e\u3002'
        : 'No embedding model is configured. AI summaries can still run, but analysis accuracy may be lower.';
  }

  String _buildStructuredReportText({
    required AiSavedAnalysisReport report,
    required bool forMemo,
  }) {
    final isZh = _isZhLocale();
    final title = _selectedInsightDisplayTitle();
    final header = forMemo ? '# $title' : title;
    final buffer = StringBuffer();
    buffer.writeln(header);
    buffer.writeln(_reportRangeLabel());
    buffer.writeln('');

    final summaryText = report.summary.trim();
    if (summaryText.isNotEmpty) {
      buffer.writeln(summaryText);
    }

    for (final section in _reportNarrativeSections(report)) {
      final body = section.body.trim();
      if (body.isEmpty) continue;
      buffer.writeln('');
      buffer.writeln(body);
    }

    final closing = _reportClosingText(report)?.trim();
    if (closing != null && closing.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(closing);
    }

    final references = _referenceEvidences(report);
    if (references.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(
        isZh
            ? '\u8fd9\u6b21\u6d1e\u5bdf\u53c2\u8003\u4e86\u8fd9\u4e9b\u7247\u6bb5\uff1a'
            : 'This insight drew on these note fragments:',
      );
      for (final evidence in references) {
        buffer.writeln('- "${evidence.quoteText.trim()}"');
      }
    }

    return buffer.toString().trim();
  }

  Future<void> _shareReport() async {
    final report = _analysisReport;
    if (report == null) {
      showTopToast(context, context.t.strings.legacy.msg_no_summary_share);
      return;
    }
    final text = _buildStructuredReportText(report: report, forMemo: false);
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
    final report = _analysisReport;
    if (report == null) {
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
          text: _buildStructuredReportText(report: report, forMemo: false),
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
    final report = _analysisReport;
    if (report == null) {
      showTopToast(context, context.t.strings.legacy.msg_no_summary_save);
      return;
    }

    final content = _buildStructuredReportText(report: report, forMemo: true);
    final uid = generateUid();
    final now = DateTime.now();
    final tags = extractTags(content);
    final aiAnalysisRepository = ref.read(aiAnalysisRepositoryProvider);

    try {
      await ref
          .read(memoMutationServiceProvider)
          .createQuickInputMemo(
            uid: uid,
            content: content,
            visibility: 'PRIVATE',
            nowSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
            tags: tags,
          );
      await aiAnalysisRepository.upsertMemoPolicy(memoUid: uid, allowAi: false);
      unawaited(
        ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            ),
      );
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
    return _reportRangeOverride ?? resolveAiInsightRange(_range, _customRange);
  }

  String _reportRangeLabel() {
    return formatAiInsightReportRangeLabel(context, _effectiveRange());
  }

  PreferredSizeWidget _buildAppBar({
    required BuildContext context,
    required bool isReport,
    required Color bg,
    required Color border,
    required Color textMain,
    required bool useDesktopSidePane,
  }) {
    final enableWindowsDragToMove = Platform.isWindows;
    final titleText = useDesktopSidePane
        ? context.t.strings.aiInsight.title
        : (isReport
              ? context.t.strings.legacy.msg_ai_summary_report
              : context.t.strings.aiInsight.title);
    return AppBar(
      title: IgnorePointer(
        ignoring: enableWindowsDragToMove,
        child: Text(
          titleText,
          style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
        ),
      ),
      centerTitle: !useDesktopSidePane,
      backgroundColor: useDesktopSidePane ? bg : Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: !useDesktopSidePane,
      toolbarHeight: 46,
      leading: useDesktopSidePane
          ? null
          : widget.presentation == HomeScreenPresentation.embeddedBottomNav
          ? AppDrawerMenuButton(
              tooltip: context.t.strings.legacy.msg_toggle_sidebar,
              iconColor: textMain,
              badgeBorderColor: bg,
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              color: textMain,
              onPressed: () => _backToAllMemos(context),
            ),
      actions: [
        if (isReport)
          IconButton(
            icon: const Icon(Icons.share),
            color: MemoFlowPalette.primary,
            onPressed: _shareReport,
          ),
        IconButton(
          tooltip: context.t.strings.settings.preferences.history,
          icon: Icon(Icons.history_rounded, color: textMain),
          onPressed: _openInsightHistory,
        ),
        if (enableWindowsDragToMove) const DesktopWindowControls(),
      ],
      flexibleSpace: enableWindowsDragToMove
          ? const DragToMoveArea(child: SizedBox.expand())
          : (useDesktopSidePane
                ? null
                : ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(color: bg.withValues(alpha: 0.9)),
                    ),
                  )),
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
    final isReport = _view == _AiSummaryView.report;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.aiSummary,
      onSelect: (d) => _navigate(context, d),
      onSelectTag: (t) => _openTag(context, t),
      onOpenNotifications: () => _openNotifications(context),
      embedded: useDesktopSidePane,
    );
    final pageBody = Stack(
      children: [
        if (isReport)
          _buildReportBody(
            bg: bg,
            card: card,
            border: border,
            textMain: textMain,
            textMuted: textMuted,
            report: _analysisReport,
          )
        else
          _buildInputBody(
            card: card,
            border: border,
            textMain: textMain,
            textMuted: textMuted,
          ),
        if (isReport)
          _buildBottomBar(
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
    );

    final shouldInterceptPop =
        widget.presentation != HomeScreenPresentation.embeddedBottomNav;

    return PopScope(
      canPop: !shouldInterceptPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !shouldInterceptPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        drawer: useDesktopSidePane ? null : drawerPanel,
        drawerEnableOpenDragGesture:
            widget.presentation != HomeScreenPresentation.embeddedBottomNav,
        appBar: _buildAppBar(
          context: context,
          isReport: isReport,
          bg: bg,
          border: border,
          textMain: textMain,
          useDesktopSidePane: useDesktopSidePane,
        ),
        body: useDesktopSidePane
            ? Row(
                children: [
                  SizedBox(
                    width: kMemoFlowDesktopDrawerWidth,
                    child: drawerPanel,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  Expanded(child: pageBody),
                ],
              )
            : pageBody,
      ),
    );
  }

  Widget _buildInputBody({
    required Color card,
    required Color border,
    required Color textMain,
    required Color textMuted,
  }) {
    final settings = ref.watch(aiSettingsProvider);
    final customTemplate = settings.customInsightTemplate;
    final isNarrow = MediaQuery.sizeOf(context).width < 640;
    final crossAxisCount = isNarrow ? 2 : 3;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = isNarrow ? 20.0 : 28.0;

    final hasGenerationConfig = hasConfiguredChatRoute(
      settings,
      routeId: AiTaskRouteId.analysisReport,
    );
    final hasEmbeddingConfig = hasConfiguredEmbeddingRoute(settings);

    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleAiInsightDefinitions.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isNarrow ? 0.92 : 1.08,
      ),
      itemBuilder: (context, index) {
        if (index == visibleAiInsightDefinitions.length) {
          return _AiCustomInsightCard(
            template: customTemplate,
            cardColor: card,
            borderColor: border,
            textMain: textMain,
            textMuted: textMuted,
            onTap: _openCustomInsightSettings,
            onEdit: customTemplate.isConfigured
                ? _openCustomTemplateEditor
                : null,
          );
        }
        final definition = visibleAiInsightDefinitions[index];
        return _AiInsightCard(
          definition: definition,
          cardColor: card,
          borderColor: border,
          textMain: textMain,
          textMuted: textMuted,
          onTap: () => _openInsightSettings(definition),
        );
      },
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width < 900 ? width : 840),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t.strings.aiInsight.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t.strings.aiInsight.subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: textMuted,
                    ),
                  ),
                  if (!hasGenerationConfig || !hasEmbeddingConfig) ...[
                    const SizedBox(height: 18),
                    _AiSettingsBanner(
                      hasGenerationConfig: hasGenerationConfig,
                      hasEmbeddingConfig: hasEmbeddingConfig,
                      textMain: textMain,
                      textMuted: textMuted,
                      borderColor: border,
                      cardColor: card,
                      onTap: _openAiSettings,
                    ),
                  ],
                  const SizedBox(height: 24),
                  grid,
                ],
              ),
            ),
          ),
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
    required AiSavedAnalysisReport? report,
  }) {
    if (report == null) {
      return const SizedBox.shrink();
    }
    return _buildLetterReportBody(
      bg: bg,
      card: card,
      border: border,
      textMain: textMain,
      textMuted: textMuted,
      report: report,
    );
  }

  Widget _buildBottomBar({
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
                  onPressed: _sharePoster,
                  icon: const Icon(Icons.palette, size: 20),
                  label: Text(
                    context.t.strings.legacy.msg_generate_share_poster,
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
          ),
        ),
      ),
    );
  }

  String _analysisProgressLabel(double progress) {
    final isZh = _isZhLocale();
    if (progress < 0.12) {
      return isZh ? '正在准备分析环境...' : 'Preparing analysis...';
    }
    if (progress < 0.34) {
      return isZh ? '正在检查可分析内容...' : 'Checking analyzable content...';
    }
    if (progress < 0.68) {
      return isZh ? '正在检索相关笔记...' : 'Retrieving relevant notes...';
    }
    if (progress < 0.78) {
      return isZh ? '正在整理关键线索...' : 'Organizing key evidence...';
    }
    if (progress < 0.92) {
      return isZh ? '正在生成洞察结果...' : 'Generating insights...';
    }
    return isZh ? '正在整理最终结果...' : 'Finalizing results...';
  }

  Widget _buildLoadingOverlay({
    required Color bg,
    required Color textMain,
    required Color textMuted,
  }) {
    final progress = _analysisProgress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();
    final progressLabel = _analysisProgressLabel(progress);
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              MemoFlowPalette.primary,
                            ),
                            backgroundColor: MemoFlowPalette.primary.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          progressLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$progressPercent%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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

extension on _AiSummaryScreenState {
  Widget _buildLetterReportBody({
    required Color bg,
    required Color card,
    required Color border,
    required Color textMain,
    required Color textMuted,
    required AiSavedAnalysisReport report,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 720 ? 20.0 : 28.0;
    final paper = isDark ? card : const Color(0xFFFFFBF5);
    final paperBorder = isDark ? border : const Color(0xFFE6D8C6);
    final titleColor = isDark ? textMain : const Color(0xFF5C4438);
    final bodyColor = textMain.withValues(alpha: isDark ? 0.92 : 0.84);
    final subtleText = textMuted.withValues(alpha: isDark ? 0.92 : 0.9);
    final accentSoft = isDark
        ? const Color(0xFF3B2F28)
        : const Color(0xFFF3E7D8);
    final referenceBg = isDark
        ? card.withValues(alpha: 0.88)
        : const Color(0xFFF9F4EC);
    final narrativeSections = _reportNarrativeSections(report);
    final leaveSpaceText = _reportLeaveSpaceText(report);
    final closingText = _reportClosingText(report);
    final referenceEvidences = _referenceEvidences(report);

    return ListView(
      padding: const EdgeInsets.only(bottom: 132),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width < 980 ? width : 860),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                24,
              ),
              child: RepaintBoundary(
                key: _reportBoundaryKey,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  decoration: BoxDecoration(
                    color: paper,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: paperBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _reportBadgeTitle(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 720;
                          final titleBlock = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _reportHeaderTitle(),
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _reportRangeLabel(),
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: subtleText,
                                ),
                              ),
                            ],
                          );
                          final backButton = OutlinedButton.icon(
                            onPressed: _backToInsightInput,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: Text(_reportBackLabel()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: titleColor,
                              side: BorderSide(
                                color: paperBorder.withValues(alpha: 0.95),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                titleBlock,
                                const SizedBox(height: 16),
                                backButton,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: titleBlock),
                              const SizedBox(width: 16),
                              backButton,
                            ],
                          );
                        },
                      ),
                      if (report.isStale) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: accentSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: paperBorder.withValues(alpha: 0.9),
                            ),
                          ),
                          child: Text(
                            _reportStaleWarning(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Divider(
                        color: paperBorder.withValues(alpha: 0.9),
                        height: 1,
                      ),
                      if (report.summary.trim().isNotEmpty) ...[
                        const SizedBox(height: 24),
                        ..._buildLetterParagraphs(
                          text: report.summary,
                          textColor: bodyColor,
                        ),
                      ],
                      for (final section in narrativeSections) ...[
                        const SizedBox(height: 22),
                        ..._buildLetterParagraphs(
                          text: section.body,
                          textColor: bodyColor,
                        ),
                      ],
                      if (_shouldShowLeaveSpaceText(leaveSpaceText)) ...[
                        const SizedBox(height: 20),
                        _buildLeaveSpaceBlock(
                          text: leaveSpaceText!,
                          textColor: bodyColor,
                          titleColor: titleColor,
                          background: referenceBg,
                          borderColor: paperBorder,
                        ),
                      ],
                      if (_shouldShowClosingText(closingText)) ...[
                        const SizedBox(height: 22),
                        _buildClosingBlock(
                          text: closingText!,
                          textColor: titleColor,
                          background: accentSoft,
                          borderColor: paperBorder,
                        ),
                      ],
                      if (_shouldShowReferenceSection(referenceEvidences)) ...[
                        const SizedBox(height: 22),
                        _buildReferenceSection(
                          evidences: referenceEvidences,
                          titleColor: titleColor,
                          textColor: bodyColor,
                          subtleText: subtleText,
                          background: referenceBg,
                          borderColor: paperBorder,
                        ),
                      ],
                      const SizedBox(height: 28),
                      Center(
                        child: Text(
                          context.t.strings.legacy.msg_generated_ai_memoflow,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: subtleText.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<AiAnalysisSectionData> _reportNarrativeSections(
    AiSavedAnalysisReport report,
  ) {
    final sections = <AiAnalysisSectionData>[];
    for (final section in report.sections) {
      final body = section.body.trim();
      if (body.isEmpty ||
          section.sectionKey == 'closing' ||
          section.sectionKey == 'leave_space') {
        continue;
      }
      sections.add(section);
    }
    return sections;
  }

  String? _reportLeaveSpaceText(AiSavedAnalysisReport report) {
    for (final section in report.sections) {
      if (section.sectionKey != 'leave_space') {
        continue;
      }
      final body = section.body.trim();
      if (_shouldShowLeaveSpaceText(body)) {
        return body;
      }
    }
    return null;
  }

  bool _shouldShowLeaveSpaceText(String? text) {
    final trimmed = (text ?? '').trim();
    if (trimmed.length < 24) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    const markers = <String>[
      '留白',
      '还看不清',
      '不够',
      '更多',
      '先不',
      '暂时',
      '也许',
      'not yet',
      'not clear',
      'not enough',
      'for now',
      'maybe',
    ];
    return markers.any(lower.contains);
  }

  String? _reportClosingText(AiSavedAnalysisReport report) {
    for (final section in report.sections) {
      if (section.sectionKey == 'closing' && section.body.trim().isNotEmpty) {
        return section.body.trim();
      }
    }
    for (final suggestion in report.followUpSuggestions) {
      final trimmed = suggestion.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  bool _shouldShowClosingText(String? text) {
    final trimmed = (text ?? '').trim();
    return trimmed.length >= 18;
  }

  List<AiAnalysisEvidenceData> _referenceEvidences(
    AiSavedAnalysisReport report,
  ) {
    final seen = <String>{};
    final result = <AiAnalysisEvidenceData>[];
    for (final evidence in report.evidences) {
      final quote = evidence.quoteText.trim();
      if (quote.isEmpty) continue;
      if (seen.add(evidence.evidenceKey)) {
        result.add(evidence);
      }
      if (result.length >= 6) {
        break;
      }
    }
    return result;
  }

  Widget _buildLeaveSpaceBlock({
    required String text,
    required Color textColor,
    required Color titleColor,
    required Color background,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isZhLocale()
                ? '\u8fd9\u6b21\u6211\u5148\u66ff\u4f60\u7559\u4e00\u70b9\u7a7a\u767d'
                : 'A little space, for now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 10),
          ..._buildLetterParagraphs(text: text, textColor: textColor),
        ],
      ),
    );
  }

  Widget _buildClosingBlock({
    required String text,
    required Color textColor,
    required Color background,
    required Color borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Text(
        text.trim(),
        style: TextStyle(
          fontSize: 15,
          height: 1.85,
          fontWeight: FontWeight.w600,
          color: textColor.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildReferenceSection({
    required List<AiAnalysisEvidenceData> evidences,
    required Color titleColor,
    required Color textColor,
    required Color subtleText,
    required Color background,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: 0.78)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _toggleReferencesExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.menu_book_rounded, color: titleColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _reportReferenceTitle(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _reportReferenceSubtitle(),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: subtleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _referencesExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: subtleText,
                  ),
                ],
              ),
            ),
          ),
          if (_referencesExpanded) ...[
            Divider(height: 1, color: borderColor.withValues(alpha: 0.78)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  for (var index = 0; index < evidences.length; index++) ...[
                    _ReferenceQuoteCard(
                      quote: _compactQuote(evidences[index].quoteText),
                      textColor: textColor,
                      borderColor: borderColor,
                      onTap: () => _openEvidenceMemo(evidences[index]),
                      openLabel: _isZhLocale()
                          ? '\u6253\u5f00\u539f\u7b14\u8bb0'
                          : 'Open note',
                    ),
                    if (index != evidences.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildLetterParagraphs({
    required String text,
    required Color textColor,
  }) {
    final paragraphs = _splitLetterParagraphs(text);
    if (paragraphs.isEmpty) {
      return const <Widget>[];
    }
    final widgets = <Widget>[];
    for (var index = 0; index < paragraphs.length; index++) {
      widgets.add(
        Text(
          paragraphs[index],
          style: TextStyle(fontSize: 16, height: 1.95, color: textColor),
        ),
      );
      if (index != paragraphs.length - 1) {
        widgets.add(const SizedBox(height: 18));
      }
    }
    return widgets;
  }

  String _compactQuote(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 140) {
      return normalized;
    }
    return '${normalized.substring(0, 140).trim()}...';
  }

  List<String> _splitLetterParagraphs(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    return normalized
        .split(RegExp(r'\n\s*\n+'))
        .map(
          (paragraph) => paragraph
              .replaceAll(RegExp(r'\s*\n\s*'), ' ')
              .replaceAll(RegExp(r'\s{2,}'), ' ')
              .trim(),
        )
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
  }

  bool _shouldShowReferenceSection(List<AiAnalysisEvidenceData> evidences) {
    return evidences.length >= 2;
  }

  bool _isZhLocale() {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  }

  String _reportBadgeTitle() {
    return context.t.strings.aiInsight.title;
  }

  String _reportHeaderTitle() {
    return _selectedInsightDisplayTitle();
  }

  String _selectedInsightDisplayTitle() {
    final override = _selectedInsightTitleOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return _selectedInsightDefinition.title(context);
  }

  String _reportBackLabel() {
    return _isZhLocale()
        ? '\u56de\u5230 AI \u601d\u8003\u5ba4'
        : 'Back to studio';
  }

  String _reportReferenceTitle() {
    return _isZhLocale()
        ? '\u8fd9\u6b21\u6d1e\u5bdf\u53c2\u8003\u4e86\u8fd9\u4e9b\u7247\u6bb5'
        : 'Fragments behind this insight';
  }

  String _reportReferenceSubtitle() {
    return _isZhLocale()
        ? '\u4e0d\u60f3\u6253\u65ad\u6b63\u6587\uff0c\u6240\u4ee5\u6211\u628a\u5b83\u4eec\u653e\u5728\u4e86\u8fd9\u91cc\u3002'
        : 'Open any note fragment here without interrupting the insight.';
  }

  String _reportStaleWarning() {
    return _isZhLocale()
        ? '\u8fd9\u4efd\u6d1e\u5bdf\u57fa\u4e8e\u8f83\u65e9\u7684\u4e00\u6279\u7b14\u8bb0\u7ebf\u7d22\u751f\u6210\u3002\u5982\u679c\u4f60\u60f3\u8ba9\u5b83\u66f4\u8d34\u8fd1\u6b64\u523b\uff0c\u53ef\u4ee5\u91cd\u65b0\u751f\u6210\u4e00\u6b21\u3002'
        : 'This insight was generated from an older set of note clues. Regenerate it if you want it to feel closer to now.';
  }

  Future<void> _openEvidenceMemo(AiAnalysisEvidenceData evidence) async {
    final row = await ref.read(databaseProvider).getMemoByUid(evidence.memoUid);
    if (!mounted || row == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoDetailScreen(initialMemo: LocalMemo.fromDb(row)),
      ),
    );
  }
}

class _ReferenceQuoteCard extends StatelessWidget {
  const _ReferenceQuoteCard({
    required this.quote,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
    required this.openLabel,
  });

  final String quote;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '"$quote"',
              style: TextStyle(fontSize: 14, height: 1.7, color: textColor),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: openLabel,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onTap,
              icon: const Icon(Icons.north_east_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.definition,
    required this.cardColor,
    required this.borderColor,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final AiInsightDefinition definition;
  final Color cardColor;
  final Color borderColor;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: definition.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  definition.icon,
                  color: definition.accent,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                definition.title(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  definition.description(context),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: textMuted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiCustomInsightCard extends StatelessWidget {
  const _AiCustomInsightCard({
    required this.template,
    required this.cardColor,
    required this.borderColor,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
    this.onEdit,
  });

  final AiCustomInsightTemplate template;
  final Color cardColor;
  final Color borderColor;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final title = template.isConfigured
        ? template.title.trim()
        : (isZh ? '\u81ea\u5b9a\u4e49\u6a21\u677f' : 'Custom Template');
    final description = template.isConfigured
        ? template.description.trim()
        : (isZh
              ? '\u70b9\u51fb\u521b\u5efa\u4e00\u4e2a\u4f60\u81ea\u5df1\u7684\u5206\u6790\u6a21\u677f\uff0c\u53ef\u4ee5\u8bbe\u7f6e\u6807\u9898\u3001\u63d0\u793a\u8bcd\u3001\u56fe\u6807\u548c\u8bf4\u660e\u3002'
              : 'Create your own analysis template with a title, prompt, icon, and note.');
    final accent = MemoFlowPalette.primary;
    final icon = template.isConfigured
        ? QuickPromptIconCatalog.resolve(template.iconKey)
        : Icons.add_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const Spacer(),
                  if (template.isConfigured && onEdit != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: accent,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: textMuted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiSettingsBanner extends StatelessWidget {
  const _AiSettingsBanner({
    required this.hasGenerationConfig,
    required this.hasEmbeddingConfig,
    required this.textMain,
    required this.textMuted,
    required this.borderColor,
    required this.cardColor,
    required this.onTap,
  });

  final bool hasGenerationConfig;
  final bool hasEmbeddingConfig;
  final Color textMain;
  final Color textMuted;
  final Color borderColor;
  final Color cardColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isZh =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final title = _title(isZh);
    final description = _description(isZh);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MemoFlowPalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.settings_suggest_rounded,
              color: MemoFlowPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, height: 1.5, color: textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: MemoFlowPalette.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(isZh ? '\u53bb\u8bbe\u7f6e' : 'Open'),
          ),
        ],
      ),
    );
  }

  String _title(bool isZh) {
    if (!hasGenerationConfig && !hasEmbeddingConfig) {
      return isZh
          ? 'AI \u8fd8\u6ca1\u6709\u914d\u7f6e'
          : 'AI is not configured yet';
    }
    if (!hasGenerationConfig) {
      return isZh
          ? '\u8fd8\u7f3a chat \u6a21\u578b\u914d\u7f6e'
          : 'Chat model setup is missing';
    }
    return isZh
        ? '\u672a\u914d\u7f6e\u5411\u91cf\u6a21\u578b'
        : 'Embedding model is optional but recommended';
  }

  String _description(bool isZh) {
    if (!hasGenerationConfig && !hasEmbeddingConfig) {
      return isZh
          ? '\u8bf7\u5148\u914d\u7f6e chat \u6a21\u578b\u3002\u914d\u597d chat \u540e\u5373\u53ef\u5f00\u59cb AI \u603b\u7ed3\uff0c\u8865\u5145\u5411\u91cf\u6a21\u578b\u53ef\u4ee5\u63d0\u5347\u5206\u6790\u51c6\u786e\u5ea6\u3002'
          : 'Configure a chat model first. You can start AI summaries once chat is ready, and add an embedding model later for better analysis accuracy.';
    }
    if (!hasGenerationConfig) {
      return isZh
          ? '\u5f53\u524d\u8fd8\u7f3a chat \u6a21\u578b\uff0c\u6682\u65f6\u8fd8\u4e0d\u80fd\u5f00\u59cb AI \u603b\u7ed3\u3002'
          : 'A chat model is still missing, so AI summaries cannot start yet.';
    }
    return isZh
        ? '\u5f53\u524d\u5df2\u914d\u7f6e chat \u6a21\u578b\uff0c\u53ef\u4ee5\u5f00\u59cb AI \u603b\u7ed3\uff1b\u4f46\u672a\u914d\u7f6e\u5411\u91cf\u6a21\u578b\uff0cAI \u5206\u6790\u51c6\u786e\u5ea6\u4f1a\u964d\u4f4e\u3002'
        : 'Chat is configured, so AI summaries can start now. Without an embedding model, analysis accuracy may be lower.';
  }
}
