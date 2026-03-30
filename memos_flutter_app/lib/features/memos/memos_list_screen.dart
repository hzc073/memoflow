import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_localization.dart';
import '../../application/desktop/desktop_settings_window.dart';
import '../../core/desktop/shortcuts.dart';
import '../../application/desktop/desktop_tray_controller.dart';
import '../../application/desktop/desktop_exit_coordinator.dart';
import '../../core/drawer_navigation.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/scene_micro_guide_widgets.dart';
import '../../core/sync_error_presenter.dart';
import '../../application/sync/sync_feedback_presenter.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../../data/logs/sync_queue_progress_tracker.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/shortcut.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../state/settings/app_lock_provider.dart';
import '../home/app_drawer.dart';
import '../../state/system/debug_screenshot_mode_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/local_library_scanner.dart';
import '../../state/system/logging_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/memos/note_draft_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/memos/search_history_provider.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import '../../state/system/session_provider.dart';
import '../../state/settings/user_settings_provider.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../notifications/notifications_screen.dart';
import '../reminders/memo_reminder_editor_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/desktop_shortcuts_overview_screen.dart';
import '../settings/password_lock_screen.dart';
import '../settings/shortcut_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../tags/tag_edit_sheet.dart';
import '../voice/voice_record_screen.dart';
import '../desktop/quick_input/desktop_quick_input_dialog.dart';
import 'memo_detail_screen.dart';
import 'memo_editor_screen.dart';
import 'memo_versions_screen.dart';
import 'memo_markdown.dart';
import 'advanced_search_sheet.dart';
import 'memos_list_audio_playback_coordinator.dart';
import 'memos_list_inline_compose_coordinator.dart';
import 'memos_list_screen_view_state.dart';
import 'memos_list_viewport_coordinator.dart';
import 'recycle_bin_screen.dart';
import 'note_input_sheet.dart';
import 'widgets/floating_collapse_button.dart';
import 'widgets/memos_list_floating_actions.dart';
import 'widgets/memos_list_inline_compose_card.dart';
import 'widgets/memos_list_memo_card.dart';
import 'widgets/memos_list_memo_card_container.dart';
import 'widgets/memos_list_search_widgets.dart';
import 'widgets/memos_list_title_menu.dart';
import '../../i18n/strings.g.dart';

enum _MemoSortOption { createAsc, createDesc, updateAsc, updateDesc }

enum _AdvancedSearchChipKind {
  createdDateRange,
  hasLocation,
  locationContains,
  hasAttachments,
  attachmentNameContains,
  attachmentType,
  hasRelations,
}

class MemosListScreen extends ConsumerStatefulWidget {
  const MemosListScreen({
    super.key,
    required this.title,
    required this.state,
    this.tag,
    this.dayFilter,
    this.showDrawer = false,
    this.enableCompose = false,
    this.openDrawerOnStart = false,
    this.enableSearch = true,
    this.enableTitleMenu = true,
    this.showPillActions = true,
    this.showFilterTagChip = false,
    this.showTagFilters = false,
    this.toastMessage,
  });

  final String title;
  final String state;
  final String? tag;
  final DateTime? dayFilter;
  final bool showDrawer;
  final bool enableCompose;
  final bool openDrawerOnStart;
  final bool enableSearch;
  final bool enableTitleMenu;
  final bool showPillActions;
  final bool showFilterTagChip;
  final bool showTagFilters;
  final String? toastMessage;

  @override
  ConsumerState<MemosListScreen> createState() => _MemosListScreenState();
}

class _MemosListScreenState extends ConsumerState<MemosListScreen>
    with WindowListener {
  static const int _initialPageSize = 200;
  static const int _pageStep = 200;
  static const int _bootstrapImportThreshold = 50;
  final _dayDateFmt = DateFormat('yyyy-MM-dd');
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final MemoComposerController _inlineComposer;
  final _inlineComposeFocusNode = FocusNode();
  final _inlineEditorFieldKey = GlobalKey();
  final _inlineTagMenuKey = GlobalKey();
  final _inlineTemplateMenuKey = GlobalKey();
  final _inlineTodoMenuKey = GlobalKey();
  final _inlineVisibilityMenuKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _titleKey = GlobalKey();
  final _scrollController = ScrollController();
  final _floatingCollapseViewportKey = GlobalKey();
  final Map<String, GlobalKey<MemoListCardState>> _memoCardKeys =
      <String, GlobalKey<MemoListCardState>>{};
  GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();

  var _searching = false;
  var _openedDrawerOnStart = false;
  String? _selectedShortcutId;
  QuickSearchKind? _selectedQuickSearchKind;
  var _advancedSearchFilters = AdvancedSearchFilters.empty;
  String? _activeTagFilter;
  SceneMicroGuideId? _presentedListGuideId;
  var _sortOption = _MemoSortOption.createDesc;
  List<LocalMemo> _animatedMemos = [];
  String _listSignature = '';
  final Set<String> _pendingRemovedUids = <String>{};
  late final MemosListAudioPlaybackCoordinator _audioPlaybackCoordinator;
  late final MemosListViewportCoordinator _viewportCoordinator;
  DateTime? _lastBackPressedAt;
  bool _autoScanTriggered = false;
  bool _autoScanInFlight = false;
  bool _bootstrapImportActive = false;
  int _bootstrapImportTotal = 0;
  DateTime? _bootstrapImportStartedAt;
  String? _lastEmptyDiagnosticKey;
  String? _lastLoadingPhaseKey;
  VoiceRecordOverlayDragSession? _voiceOverlayDragSession;
  Future<void>? _voiceOverlayDragFuture;
  String? _lastWorkspaceDebugSignature;
  bool _desktopWindowMaximized = false;
  bool _windowsHeaderSearchExpanded = false;
  bool _desktopQuickInputSubmitting = false;
  bool _inlineComposeBusy = false;
  bool _inlineComposeDraftApplied = false;
  late final MemosListInlineComposeCoordinator _inlineComposeCoordinator;
  Timer? _inlineComposeDraftTimer;
  ProviderSubscription<AsyncValue<String>>? _inlineDraftSubscription;
  TextEditingController get _inlineComposeController =>
      _inlineComposer.textController;
  bool get _inlineCanUndo => _inlineComposer.canUndo;
  bool get _inlineCanRedo => _inlineComposer.canRedo;
  int get _pageSize => _viewportCoordinator.pageSize;
  bool get _reachedEnd => _viewportCoordinator.reachedEnd;
  bool get _loadingMore => _viewportCoordinator.loadingMore;
  String get _paginationKey => _viewportCoordinator.paginationKey;
  int get _lastResultCount => _viewportCoordinator.lastResultCount;
  int get _currentResultCount => _viewportCoordinator.currentResultCount;
  bool get _currentLoading => _viewportCoordinator.currentLoading;
  bool get _currentShowSearchLanding =>
      _viewportCoordinator.currentShowSearchLanding;
  bool get _mobileBottomPullArmed => _viewportCoordinator.mobileBottomPullArmed;
  int? get _activeLoadMoreRequestId =>
      _viewportCoordinator.activeLoadMoreRequestId;
  String? get _activeLoadMoreSource =>
      _viewportCoordinator.activeLoadMoreSource;
  bool get _showBackToTop => _viewportCoordinator.showBackToTop;
  bool get _floatingCollapseScrolling =>
      _viewportCoordinator.floatingCollapseScrolling;
  String? get _floatingCollapseMemoUid =>
      _viewportCoordinator.floatingCollapseMemoUid;
  bool get _scrollToTopAnimating => _viewportCoordinator.scrollToTopAnimating;

  @override
  void initState() {
    super.initState();
    _activeTagFilter = _normalizeTag(widget.tag);
    _inlineComposer = MemoComposerController();
    _inlineComposeCoordinator = MemosListInlineComposeCoordinator(
      ref: ref,
      composer: _inlineComposer,
      templateRenderer: MemoTemplateRenderer(),
      imagePicker: ImagePicker(),
    );
    _audioPlaybackCoordinator = MemosListAudioPlaybackCoordinator(
      read: ref.read,
    );
    _viewportCoordinator = MemosListViewportCoordinator(
      initialPageSize: _initialPageSize,
      pageStep: _pageStep,
    );
    _inlineComposeCoordinator.addListener(
      _handleInlineComposeCoordinatorChanged,
    );
    _audioPlaybackCoordinator.addListener(
      _handleAudioPlaybackCoordinatorChanged,
    );
    _viewportCoordinator.addListener(_handleViewportCoordinatorChanged);
    _scrollController.addListener(_handleViewportScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleViewportScrollChanged(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = widget.toastMessage;
      if (message == null || message.trim().isEmpty) return;
      showTopToast(context, message);
    });
    _inlineComposeController.addListener(_handleInlineComposeChanged);
    _inlineComposeController.addListener(_scheduleInlineComposeDraftSave);
    _inlineComposeFocusNode.addListener(_handleInlineComposeFocusChanged);
    _applyInlineComposeDraft(ref.read(noteDraftProvider));
    _inlineDraftSubscription = ref.listenManual<AsyncValue<String>>(
      noteDraftProvider,
      (prev, next) => _applyInlineComposeDraft(next),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDrawerIfNeeded());
    if (Platform.isWindows) {
      windowManager.addListener(this);
      unawaited(_syncDesktopWindowState());
    }
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.addHandler(_handleDesktopShortcuts);
    }
  }

  @override
  void didUpdateWidget(covariant MemosListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _activeTagFilter = _normalizeTag(widget.tag);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.removeHandler(_handleDesktopShortcuts);
    }
    _inlineComposeDraftTimer?.cancel();
    _inlineDraftSubscription?.close();
    _inlineComposeController.removeListener(_handleInlineComposeChanged);
    _inlineComposeController.removeListener(_scheduleInlineComposeDraftSave);
    _inlineComposeCoordinator.removeListener(
      _handleInlineComposeCoordinatorChanged,
    );
    _audioPlaybackCoordinator.removeListener(
      _handleAudioPlaybackCoordinatorChanged,
    );
    _viewportCoordinator.removeListener(_handleViewportCoordinatorChanged);
    _inlineComposeCoordinator.dispose();
    _audioPlaybackCoordinator.dispose();
    _viewportCoordinator.dispose();
    _inlineComposer.dispose();
    _inlineComposeFocusNode.removeListener(_handleInlineComposeFocusChanged);
    _inlineComposeFocusNode.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _normalizeTag(String? raw) {
    final normalized = normalizeTagPath(raw ?? '');
    if (normalized.isEmpty) return null;
    return normalized;
  }

  void _handleInlineComposeCoordinatorChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAudioPlaybackCoordinatorChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleViewportCoordinatorChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleMemoAudioTap(LocalMemo memo) async {
    final result = await _audioPlaybackCoordinator.togglePlayback(memo);
    if (!mounted) return;
    switch (result.kind) {
      case MemosListAudioToggleResultKind.handled:
        return;
      case MemosListAudioToggleResultKind.sourceMissing:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_unable_load_audio_source,
            ),
          ),
        );
        return;
      case MemosListAudioToggleResultKind.playbackFailed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_playback_failed(
                e: result.error ?? '',
              ),
            ),
          ),
        );
        return;
    }
  }

  void _selectTagFilter(String? tag) {
    setState(() => _activeTagFilter = _normalizeTag(tag));
  }

  bool get _hasAdvancedSearchFilters => !_advancedSearchFilters.isEmpty;

  void _setAdvancedSearchFilters(AdvancedSearchFilters filters) {
    setState(() => _advancedSearchFilters = filters.normalized());
  }

  void _clearAdvancedSearchFilters() {
    if (!_hasAdvancedSearchFilters) return;
    setState(() => _advancedSearchFilters = AdvancedSearchFilters.empty);
  }

  void _removeSingleAdvancedFilter(_AdvancedSearchChipKind kind) {
    final next = switch (kind) {
      _AdvancedSearchChipKind.createdDateRange =>
        _advancedSearchFilters.copyWith(createdDateRange: null),
      _AdvancedSearchChipKind.hasLocation => _advancedSearchFilters.copyWith(
        hasLocation: SearchToggleFilter.any,
      ),
      _AdvancedSearchChipKind.locationContains =>
        _advancedSearchFilters.copyWith(locationContains: ''),
      _AdvancedSearchChipKind.hasAttachments => _advancedSearchFilters.copyWith(
        hasAttachments: SearchToggleFilter.any,
      ),
      _AdvancedSearchChipKind.attachmentNameContains =>
        _advancedSearchFilters.copyWith(attachmentNameContains: ''),
      _AdvancedSearchChipKind.attachmentType => _advancedSearchFilters.copyWith(
        attachmentType: null,
      ),
      _AdvancedSearchChipKind.hasRelations => _advancedSearchFilters.copyWith(
        hasRelations: SearchToggleFilter.any,
      ),
    };
    _setAdvancedSearchFilters(next);
  }

  Future<void> _openAdvancedSearchSheet() async {
    final result = await AdvancedSearchSheet.show(
      context,
      initial: _advancedSearchFilters,
      showCreatedDateFilter: widget.dayFilter == null,
    );
    if (!mounted || result == null) return;
    _setAdvancedSearchFilters(result);
  }

  String _localizedToggleFilterLabel(SearchToggleFilter value) {
    return switch (value) {
      SearchToggleFilter.any => context.t.strings.legacy.msg_any,
      SearchToggleFilter.yes => context.t.strings.legacy.msg_yes,
      SearchToggleFilter.no => context.t.strings.legacy.msg_no,
    };
  }

  bool _isTouchPullLoadPlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Map<String, Object?> _paginationDebugContext({
    ScrollMetrics? metrics,
    Map<String, Object?>? extra,
  }) {
    final context = <String, Object?>{
      'pageSize': _pageSize,
      'resultCount': _currentResultCount,
      'lastResultCount': _lastResultCount,
      'loadingMore': _loadingMore,
      'reachedEnd': _reachedEnd,
      'providerLoading': _currentLoading,
      'showSearchLanding': _currentShowSearchLanding,
      if (_activeLoadMoreRequestId != null)
        'activeRequestId': _activeLoadMoreRequestId,
      if (_activeLoadMoreSource != null)
        'activeRequestSource': _activeLoadMoreSource,
    };
    if (metrics != null) {
      context['offset'] = metrics.pixels;
      context['maxScrollExtent'] = metrics.maxScrollExtent;
      context['viewportHeight'] = metrics.viewportDimension;
    }
    if (extra != null && extra.isNotEmpty) {
      context.addAll(extra);
    }
    return context;
  }

  void _logPaginationDebug(
    String event, {
    ScrollMetrics? metrics,
    Map<String, Object?>? context,
  }) {
    if (!mounted) return;
    ref
        .read(logManagerProvider)
        .debug(
          'Memos pagination: $event',
          context: _paginationDebugContext(metrics: metrics, extra: context),
        );
  }

  void _logVisibleCountDecrease({
    required int beforeLength,
    required int afterLength,
    required bool signatureChanged,
    required bool listChanged,
    required String fromSignature,
    required String toSignature,
    required List<String> removedSample,
  }) {
    if (!mounted || afterLength >= beforeLength) return;
    ref
        .read(logManagerProvider)
        .info(
          'Memos list: visible_count_decreased',
          context: <String, Object?>{
            'beforeLength': beforeLength,
            'afterLength': afterLength,
            'decreasedBy': beforeLength - afterLength,
            'signatureChanged': signatureChanged,
            'listChanged': listChanged,
            'fromSignature': fromSignature,
            'toSignature': toSignature,
            if (removedSample.isNotEmpty) 'removedSample': removedSample,
          },
        );
  }

  void _maybeLogEmptyViewDiagnostics({
    required String queryKey,
    required List<LocalMemo>? memosValue,
    required bool memosLoading,
    required Object? memosError,
    required List<LocalMemo> visibleMemos,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) {
    if (memosValue == null || memosLoading || memosError != null) return;
    if (visibleMemos.isNotEmpty) return;
    final providerCount = memosValue.length;
    final diagnosticKey =
        '$queryKey|provider:$providerCount|animated:${visibleMemos.length}';
    if (_lastEmptyDiagnosticKey == diagnosticKey) return;
    _lastEmptyDiagnosticKey = diagnosticKey;
    unawaited(
      _logEmptyViewDiagnostics(
        queryKey: queryKey,
        providerCount: providerCount,
        animatedCount: visibleMemos.length,
        searchQuery: searchQuery,
        resolvedTag: resolvedTag,
        useShortcutFilter: useShortcutFilter,
        useQuickSearch: useQuickSearch,
        useRemoteSearch: useRemoteSearch,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        shortcutFilter: shortcutFilter,
        quickSearchKind: quickSearchKind,
      ),
    );
  }

  String _describeSyncState(SyncFlowStatus state) {
    if (state.running) return 'loading';
    if (state.lastError != null) return 'error';
    if (state.lastSuccessAt != null) return 'value';
    return 'idle';
  }

  String _buildMemosLoadingPhase({
    required bool memosLoading,
    required bool hasProviderValue,
    required Object? memosError,
    required int providerCount,
    required int animatedCount,
  }) {
    if (memosError != null) return 'provider_error';
    if (memosLoading && !hasProviderValue) return 'initial_loading';
    if (memosLoading && hasProviderValue) return 'refreshing_with_cached';
    if (!hasProviderValue) return 'no_provider_value';
    if (providerCount > 0) return 'data_ready';
    if (animatedCount > 0) return 'rendering_cached';
    return 'data_empty';
  }

  void _maybeLogMemosLoadingPhase({
    required String queryKey,
    required bool memosLoading,
    required Object? memosError,
    required List<LocalMemo>? memosValue,
    required List<LocalMemo> visibleMemos,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
    required SyncFlowStatus syncState,
    required SyncQueueProgressSnapshot syncQueueSnapshot,
  }) {
    if (!kDebugMode || !mounted) return;
    final hasProviderValue = memosValue != null;
    final providerCount = memosValue?.length ?? 0;
    final animatedCount = visibleMemos.length;
    final phase = _buildMemosLoadingPhase(
      memosLoading: memosLoading,
      hasProviderValue: hasProviderValue,
      memosError: memosError,
      providerCount: providerCount,
      animatedCount: animatedCount,
    );
    final key = [
      phase,
      queryKey,
      memosLoading,
      hasProviderValue,
      providerCount,
      animatedCount,
      _pageSize,
      _reachedEnd,
      _loadingMore,
      _describeSyncState(syncState),
      syncQueueSnapshot.syncing,
      syncQueueSnapshot.totalTasks,
      syncQueueSnapshot.completedTasks,
      syncQueueSnapshot.currentOutboxId,
      syncQueueSnapshot.currentProgress?.toStringAsFixed(2) ?? '-',
      useShortcutFilter,
      useQuickSearch,
      useRemoteSearch,
      shortcutFilter.trim().isNotEmpty ? shortcutFilter.trim() : '-',
      quickSearchKind?.name ?? '-',
    ].join('|');
    if (_lastLoadingPhaseKey == key) return;
    _lastLoadingPhaseKey = key;

    ref
        .read(logManagerProvider)
        .info(
          'Memos loading: phase',
          context: <String, Object?>{
            'phase': phase,
            'queryKey': queryKey,
            'memosLoading': memosLoading,
            'hasProviderValue': hasProviderValue,
            'providerCount': providerCount,
            'animatedCount': animatedCount,
            'pageSize': _pageSize,
            'reachedEnd': _reachedEnd,
            'loadingMore': _loadingMore,
            'providerLoading': _currentLoading,
            'showSearchLanding': _currentShowSearchLanding,
            'syncState': _describeSyncState(syncState),
            'queueSyncing': syncQueueSnapshot.syncing,
            'queueTotalTasks': syncQueueSnapshot.totalTasks,
            'queueCompletedTasks': syncQueueSnapshot.completedTasks,
            'queueCurrentOutboxId': syncQueueSnapshot.currentOutboxId,
            'queueCurrentProgress': syncQueueSnapshot.currentProgress,
            'useShortcutFilter': useShortcutFilter,
            'useQuickSearch': useQuickSearch,
            'useRemoteSearch': useRemoteSearch,
            if (shortcutFilter.trim().isNotEmpty)
              'shortcutFilter': shortcutFilter.trim(),
            if (quickSearchKind != null)
              'quickSearchKind': quickSearchKind.name,
            if (memosError != null) 'error': memosError.toString(),
          },
        );
  }

  Future<void> _logEmptyViewDiagnostics({
    required String queryKey,
    required int providerCount,
    required int animatedCount,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) async {
    if (!mounted) return;
    await ref
        .read(memosListControllerProvider)
        .logEmptyViewDiagnostics(
          queryKey: queryKey,
          state: widget.state,
          providerCount: providerCount,
          animatedCount: animatedCount,
          searchQuery: searchQuery,
          resolvedTag: resolvedTag,
          useShortcutFilter: useShortcutFilter,
          useQuickSearch: useQuickSearch,
          useRemoteSearch: useRemoteSearch,
          startTimeSec: startTimeSec,
          endTimeSecExclusive: endTimeSecExclusive,
          shortcutFilter: shortcutFilter,
          quickSearchKind: quickSearchKind,
        );
  }

  GlobalKey<MemoListCardState> _memoCardKeyFor(String memoUid) {
    return _memoCardKeys.putIfAbsent(memoUid, GlobalKey<MemoListCardState>.new);
  }

  void _syncMemoCardKeys(List<LocalMemo> memos) {
    final keepUids = memos.map((memo) => memo.uid).toSet();
    _memoCardKeys.removeWhere((uid, _) => !keepUids.contains(uid));
  }

  MemosListViewportMetrics? _currentViewportMetrics() {
    if (!_scrollController.hasClients) return null;
    return _viewportMetricsFromScrollMetrics(_scrollController.position);
  }

  ScrollMetrics? _currentScrollMetricsForLogging() {
    if (!_scrollController.hasClients) return null;
    return _scrollController.position;
  }

  void _logLoadMoreEffect(
    MemosListViewportLoadMoreEffect effect, {
    ScrollMetrics? metrics,
  }) {
    switch (effect.kind) {
      case MemosListViewportLoadMoreEffectKind.none:
        return;
      case MemosListViewportLoadMoreEffectKind.triggered:
        _logPaginationDebug(
          'load_more_trigger',
          metrics: metrics,
          context: {
            'requestId': effect.requestId,
            'source': effect.source,
            'fromPageSize': effect.fromPageSize,
            'toPageSize': effect.toPageSize,
          },
        );
      case MemosListViewportLoadMoreEffectKind.skipped:
        _logPaginationDebug(
          'load_more_skipped',
          metrics: metrics,
          context: {'source': effect.source, 'reason': effect.skipReason},
        );
    }
  }

  void _handleViewportScrollChanged() {
    final metrics = _currentViewportMetrics();
    if (metrics == null) return;
    final effect = _viewportCoordinator.handleScroll(metrics);
    if (effect.jumpedToTopUnexpectedly) {
      _logPaginationDebug(
        'scroll_jump_to_top_detected',
        metrics: _currentScrollMetricsForLogging(),
        context: {'previousOffset': effect.previousOffset},
      );
    }
    _requestFloatingCollapseRecompute();
  }

  void _requestFloatingCollapseRecompute() {
    _viewportCoordinator.requestFloatingCollapseRecompute(
      schedulePostFrame: (callback) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callback());
      },
      resolveMemoUid: _resolveFloatingCollapseMemoUid,
    );
  }

  String? _resolveFloatingCollapseMemoUid() {
    final viewportRect = globalRectForKey(_floatingCollapseViewportKey);
    if (viewportRect == null) return null;

    MemoFloatingCollapseCandidate? nextCandidate;
    for (final key in _memoCardKeys.values) {
      final candidate = key.currentState?.resolveFloatingCollapseCandidate(
        viewportRect,
      );
      if (candidate == null) continue;
      if (nextCandidate == null ||
          candidate.visibleHeight > nextCandidate.visibleHeight) {
        nextCandidate = candidate;
      }
    }

    return nextCandidate?.memoUid;
  }

  MemosListViewportScrollEvent? _viewportScrollEventFromNotification(
    ScrollNotification notification,
  ) {
    final metrics = _viewportMetricsFromScrollMetrics(notification.metrics);
    if (notification is ScrollStartNotification) {
      return MemosListViewportScrollEvent(
        kind: MemosListViewportScrollEventKind.start,
        metrics: metrics,
        hasDragDetails: notification.dragDetails != null,
        overscroll: 0,
        userDirection: null,
      );
    }
    if (notification is ScrollUpdateNotification) {
      return MemosListViewportScrollEvent(
        kind: MemosListViewportScrollEventKind.update,
        metrics: metrics,
        hasDragDetails: notification.dragDetails != null,
        overscroll: 0,
        userDirection: null,
      );
    }
    if (notification is OverscrollNotification) {
      return MemosListViewportScrollEvent(
        kind: MemosListViewportScrollEventKind.overscroll,
        metrics: metrics,
        hasDragDetails: notification.dragDetails != null,
        overscroll: notification.overscroll,
        userDirection: null,
      );
    }
    if (notification is ScrollEndNotification) {
      return MemosListViewportScrollEvent(
        kind: MemosListViewportScrollEventKind.end,
        metrics: metrics,
        hasDragDetails: false,
        overscroll: 0,
        userDirection: null,
      );
    }
    if (notification is UserScrollNotification) {
      return MemosListViewportScrollEvent(
        kind: MemosListViewportScrollEventKind.user,
        metrics: metrics,
        hasDragDetails: false,
        overscroll: 0,
        userDirection: notification.direction,
      );
    }
    return null;
  }

  bool _handleViewportScrollNotification(ScrollNotification notification) {
    final event = _viewportScrollEventFromNotification(notification);
    if (event == null) return false;
    _viewportCoordinator.handleFloatingCollapseScrollEvent(event);
    final effect = _viewportCoordinator.handleLoadMoreScrollEvent(
      event,
      touchPullEnabled: _isTouchPullLoadPlatform(),
    );
    _logLoadMoreEffect(effect, metrics: notification.metrics);
    _requestFloatingCollapseRecompute();
    return false;
  }

  void _collapseActiveMemoFromFloatingButton() {
    final memoUid = _floatingCollapseMemoUid;
    if (memoUid == null) return;
    final memoState = _memoCardKeys[memoUid]?.currentState;
    if (memoState == null) return;
    memoState.collapseFromFloating();
    _requestFloatingCollapseRecompute();
  }

  bool _handlePageNavigationShortcut({
    required bool down,
    required String source,
  }) {
    if (_searchFocusNode.hasFocus) return false;
    final effect = _viewportCoordinator.handlePageNavigationShortcut(
      down: down,
      searchFocused: false,
      source: source,
      scrollAdapter: _ScreenViewportScrollAdapter(_scrollController),
    );
    _logLoadMoreEffect(effect, metrics: _currentScrollMetricsForLogging());
    return true;
  }

  void _handleViewportPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final effect = _viewportCoordinator.handleDesktopWheel(
      deltaY: event.scrollDelta.dy,
      touchPullEnabled: _isTouchPullLoadPlatform(),
      metrics: _currentViewportMetrics(),
    );
    _logLoadMoreEffect(effect, metrics: _currentScrollMetricsForLogging());
  }

  Future<void> _handleScrollToTop() async {
    final adapter = _ScreenViewportScrollAdapter(_scrollController);
    if (!adapter.hasClients || _scrollToTopAnimating) return;
    _logPaginationDebug(
      'scroll_to_top_action',
      metrics: _currentScrollMetricsForLogging(),
      context: {'mode': 'distance_dynamic_speed'},
    );
    await _viewportCoordinator.scrollToTop(adapter);
  }

  MemosListViewportMetrics _viewportMetricsFromScrollMetrics(
    ScrollMetrics metrics,
  ) {
    return MemosListViewportMetrics(
      pixels: metrics.pixels,
      maxScrollExtent: metrics.maxScrollExtent,
      viewportDimension: metrics.viewportDimension,
      axis: metrics.axis,
    );
  }

  String _sortOptionLabel(BuildContext context, _MemoSortOption option) {
    return switch (option) {
      _MemoSortOption.createAsc => context.t.strings.legacy.msg_created_time,
      _MemoSortOption.createDesc => context.t.strings.legacy.msg_created_time_2,
      _MemoSortOption.updateAsc => context.t.strings.legacy.msg_updated_time_2,
      _MemoSortOption.updateDesc => context.t.strings.legacy.msg_updated_time,
    };
  }

  int _compareMemosForSort(LocalMemo a, LocalMemo b) {
    if (a.pinned != b.pinned) {
      return a.pinned ? -1 : 1;
    }

    int primary;
    switch (_sortOption) {
      case _MemoSortOption.createAsc:
        primary = a.createTime.compareTo(b.createTime);
        break;
      case _MemoSortOption.createDesc:
        primary = b.createTime.compareTo(a.createTime);
        break;
      case _MemoSortOption.updateAsc:
        primary = a.updateTime.compareTo(b.updateTime);
        break;
      case _MemoSortOption.updateDesc:
        primary = b.updateTime.compareTo(a.updateTime);
        break;
    }
    if (primary != 0) return primary;

    final fallback = b.createTime.compareTo(a.createTime);
    if (fallback != 0) return fallback;
    return a.uid.compareTo(b.uid);
  }

  List<LocalMemo> _applyHomeSort(List<LocalMemo> memos) {
    if (memos.length < 2) return memos;
    final sorted = List<LocalMemo>.from(memos);
    sorted.sort(_compareMemosForSort);
    return sorted;
  }

  Widget _buildSortMenuButton(BuildContext context, {required bool isDark}) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    return PopupMenuButton<_MemoSortOption>(
      tooltip: context.t.strings.legacy.msg_sort,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withValues(alpha: 0.7)),
      ),
      color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
      onSelected: (value) {
        if (value == _sortOption) return;
        setState(() => _sortOption = value);
      },
      itemBuilder: (context) => [
        _buildSortMenuItem(context, _MemoSortOption.createAsc, textColor),
        _buildSortMenuItem(context, _MemoSortOption.createDesc, textColor),
        _buildSortMenuItem(context, _MemoSortOption.updateAsc, textColor),
        _buildSortMenuItem(context, _MemoSortOption.updateDesc, textColor),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  PopupMenuItem<_MemoSortOption> _buildSortMenuItem(
    BuildContext context,
    _MemoSortOption option,
    Color textColor,
  ) {
    final selected = option == _sortOption;
    final label = _sortOptionLabel(context, option);
    return PopupMenuItem<_MemoSortOption>(
      value: option,
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: selected
                ? Icon(Icons.check, size: 16, color: MemoFlowPalette.primary)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? MemoFlowPalette.primary : textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTitleWidget(
    BuildContext context, {
    required VoidCallback maybeHaptic,
  }) {
    if (widget.enableTitleMenu) {
      return InkWell(
        key: _titleKey,
        onTap: () {
          maybeHaptic();
          _openTitleMenu();
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      );
    }
    return Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildTopSearchField(
    BuildContext context, {
    required bool isDark,
    required bool autofocus,
    required bool hasAdvancedFilters,
    required VoidCallback onOpenAdvancedFilters,
    String? hintText,
  }) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final suffixIconWidth = hasQuery ? 72.0 : 40.0;
    Widget buildSearchActionButton({
      required String tooltip,
      required VoidCallback onPressed,
      required Widget icon,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        splashRadius: 18,
        icon: icon,
      );
    }

    return Container(
      key: const ValueKey('search'),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? MemoFlowPalette.borderDark.withValues(alpha: 0.7)
              : MemoFlowPalette.borderLight,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText ?? context.t.strings.legacy.msg_search,
          border: InputBorder.none,
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIconConstraints: BoxConstraints(
            minWidth: suffixIconWidth,
            minHeight: 36,
          ),
          suffixIcon: SizedBox(
            width: suffixIconWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                buildSearchActionButton(
                  tooltip: context.t.strings.legacy.msg_advanced_search,
                  onPressed: onOpenAdvancedFilters,
                  icon: Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: hasAdvancedFilters ? MemoFlowPalette.primary : null,
                  ),
                ),
                if (hasQuery)
                  buildSearchActionButton(
                    tooltip: context.t.strings.legacy.msg_clear,
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: _submitSearch,
      ),
    );
  }

  bool _shouldUseInlineComposeForCurrentWindow() {
    if (!widget.enableCompose || _searching) {
      return false;
    }
    final width = MediaQuery.sizeOf(context).width;
    return shouldUseInlineComposeLayout(width);
  }

  bool _isDesktopShortcutRouteActive() {
    if (!mounted || !isDesktopShortcutEnabled()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return !ref.read(appLockProvider).locked;
  }

  void _showShortcutPlaceholder(String label) {
    showTopToast(
      context,
      '\u300c$label\u300d\u529f\u80fd\u6682\u672a\u5b9e\u73b0\uff08\u5360\u4f4d\uff09\u3002',
    );
  }

  void _focusSearchFromShortcut() {
    if (Platform.isWindows && !_searching) {
      _openWindowsHeaderSearch();
      return;
    }
    _openSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _openQuickInputFromShortcut() async {
    if (!widget.enableCompose) return;
    if (_windowsHeaderSearchExpanded) {
      _closeWindowsHeaderSearch();
    }
    if (_searching) {
      _closeSearch();
    }
    if (_shouldUseInlineComposeForCurrentWindow()) {
      unawaited(_handleScrollToTop());
      _inlineComposeFocusNode.requestFocus();
      return;
    }
    await _openNoteInput();
  }

  Future<void> _openQuickRecordFromShortcut() async {
    if (!isDesktopShortcutEnabled()) {
      _showShortcutPlaceholder(context.t.strings.legacy.msg_quick_record);
      return;
    }
    final content = await DesktopQuickInputDialog.show(
      context,
      onImagePressed: () =>
          _showShortcutPlaceholder(context.t.strings.legacy.msg_image),
    );
    if (!mounted || content == null) return;
    await _submitDesktopQuickInput(content);
  }

  Future<void> _submitDesktopQuickInput(String rawContent) async {
    final content = rawContent.trimRight();
    if (content.trim().isEmpty || _desktopQuickInputSubmitting) return;

    setState(() => _desktopQuickInputSubmitting = true);
    try {
      final now = DateTime.now();
      final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      final uid = generateUid();
      final visibility = _inlineComposeCoordinator.resolveDefaultVisibility();
      final tags = extractTags(content);

      await ref
          .read(memosListControllerProvider)
          .createQuickInputMemo(
            uid: uid,
            content: content,
            visibility: visibility,
            nowSec: nowSec,
            tags: tags,
          );

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
      showTopToast(context, context.t.strings.legacy.msg_saved_to_memoflow);
    } catch (error, stackTrace) {
      ref
          .read(logManagerProvider)
          .error(
            'Desktop quick input submit failed',
            error: error,
            stackTrace: stackTrace,
          );
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_quick_input_save_failed_with_error(
          error: error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _desktopQuickInputSubmitting = false);
      }
    }
  }

  String _toggleDesktopDrawerFromShortcut() {
    if (!widget.showDrawer) return 'drawer_disabled';

    final width = MediaQuery.sizeOf(context).width;
    final supportsDesktopPane = shouldUseDesktopSidePaneLayout(width);
    if (supportsDesktopPane) {
      // Desktop side pane remains pinned open.
      return 'desktop_sidepane_pinned';
    }

    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return 'scaffold_missing';
    if (scaffold.isDrawerOpen) {
      Navigator.of(context).maybePop();
      return 'drawer_closed';
    } else {
      scaffold.openDrawer();
      return 'drawer_opened';
    }
  }

  Future<void> _toggleMemoFlowVisibilityFromShortcut() async {
    if (!isDesktopShortcutEnabled()) {
      _showShortcutPlaceholder('\u663e\u793a/\u9690\u85cf MemoFlow');
      return;
    }
    try {
      if (DesktopTrayController.instance.supported) {
        final visible = await windowManager.isVisible();
        if (visible) {
          await DesktopTrayController.instance.hideToTray();
        } else {
          await DesktopTrayController.instance.showFromTray();
        }
        return;
      }
      final visible = await windowManager.isVisible();
      if (visible) {
        if (Platform.isWindows || Platform.isLinux) {
          await windowManager.setSkipTaskbar(true);
        }
        await windowManager.hide();
        return;
      }
      if (Platform.isWindows || Platform.isLinux) {
        await windowManager.setSkipTaskbar(false);
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (error) {
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_toggle_memoflow_failed_with_error(
          error: error,
        ),
      );
    }
  }

  void _openPasswordLockFromShortcut() {
    final lockState = ref.read(appLockProvider);
    if (lockState.enabled && lockState.hasPassword) {
      ref.read(appLockProvider.notifier).lock();
      showTopToast(context, '\u5df2\u542f\u7528\u5e94\u7528\u9501\u3002');
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PasswordLockScreen()));
  }

  void _openShortcutOverviewPage() {
    final bindings = normalizeDesktopShortcutBindings(
      ref.read(appPreferencesProvider).desktopShortcutBindings,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DesktopShortcutsOverviewScreen(bindings: bindings),
      ),
    );
  }

  bool _shouldTraceDesktopShortcut(
    KeyEvent event,
    Set<LogicalKeyboardKey> pressedKeys,
  ) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.f1) return true;
    return isPrimaryShortcutModifierPressed(pressedKeys) ||
        isShiftModifierPressed(pressedKeys) ||
        isAltModifierPressed(pressedKeys);
  }

  void _logDesktopShortcutEvent({
    required String stage,
    required KeyEvent event,
    required Set<LogicalKeyboardKey> pressedKeys,
    DesktopShortcutAction? action,
    String? reason,
    Map<String, Object?>? extra,
  }) {
    if (!mounted) return;
    final payload = <String, Object?>{
      'keyId': event.logicalKey.keyId,
      'keyLabel': event.logicalKey.keyLabel,
      'debugName': event.logicalKey.debugName,
      'primaryPressed': isPrimaryShortcutModifierPressed(pressedKeys),
      'shiftPressed': isShiftModifierPressed(pressedKeys),
      'altPressed': isAltModifierPressed(pressedKeys),
      if (action != null) 'action': action.name,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
    };
    if (extra != null && extra.isNotEmpty) {
      payload.addAll(extra);
    }
    final logger = ref.read(logManagerProvider);
    if (stage == 'matched' || stage == 'delegated') {
      logger.info('Desktop shortcut: $stage', context: payload);
    } else {
      logger.debug('Desktop shortcut: $stage', context: payload);
    }
  }

  void _toggleInlineHighlight() {
    _inlineComposer.toggleHighlight();
  }

  void _toggleInlineUnorderedList() {
    _inlineComposer.toggleUnorderedList();
  }

  void _toggleInlineOrderedList() {
    _inlineComposer.toggleOrderedList();
  }

  Future<void> _cutInlineParagraphs() async {
    await _inlineComposer.cutCurrentParagraphs();
  }

  bool _handleDesktopShortcuts(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    if (!_isDesktopShortcutRouteActive()) {
      if (_shouldTraceDesktopShortcut(event, pressed)) {
        _logDesktopShortcutEvent(
          stage: 'ignored',
          event: event,
          pressedKeys: pressed,
          reason: 'route_inactive_or_locked',
        );
      }
      return false;
    }

    final bindings = normalizeDesktopShortcutBindings(
      ref.read(appPreferencesProvider).desktopShortcutBindings,
    );
    bool matches(DesktopShortcutAction action) {
      return matchesDesktopShortcut(
        event: event,
        pressedKeys: pressed,
        binding: bindings[action]!,
      );
    }

    final key = event.logicalKey;
    final inlineEditorActive = _inlineComposeFocusNode.hasFocus;
    final traceThisKey = _shouldTraceDesktopShortcut(event, pressed);

    if (matches(DesktopShortcutAction.shortcutOverview) ||
        key == LogicalKeyboardKey.f1) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.shortcutOverview,
        reason: key == LogicalKeyboardKey.f1 ? 'f1_fallback' : null,
      );
      _markSceneGuideSeen(SceneMicroGuideId.desktopGlobalShortcuts);
      _openShortcutOverviewPage();
      showTopToast(
        context,
        context.t.strings.legacy.msg_shortcuts_overview_opened,
      );
      return true;
    }

    if (matches(DesktopShortcutAction.search)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.search,
      );
      _markSceneGuideSeen(SceneMicroGuideId.desktopGlobalShortcuts);
      _focusSearchFromShortcut();
      return true;
    }
    if (matches(DesktopShortcutAction.quickInput)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.quickInput,
      );
      unawaited(_openQuickInputFromShortcut());
      return true;
    }
    if (matches(DesktopShortcutAction.quickRecord)) {
      // Desktop global hotkey is handled in App-level hotkey_manager to avoid
      // duplicate dialogs when the app is foregrounded.
      if (!DesktopTrayController.instance.supported) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.quickRecord,
          reason: 'in_window_dialog',
        );
        _markSceneGuideSeen(SceneMicroGuideId.desktopGlobalShortcuts);
        unawaited(_openQuickRecordFromShortcut());
      } else {
        _logDesktopShortcutEvent(
          stage: 'delegated',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.quickRecord,
          reason: 'handled_by_app_hotkey_manager',
        );
        _markSceneGuideSeen(SceneMicroGuideId.desktopGlobalShortcuts);
      }
      return true;
    }

    if (inlineEditorActive) {
      if (matches(DesktopShortcutAction.publishMemo) ||
          (!isPrimaryShortcutModifierPressed(pressed) &&
              isShiftModifierPressed(pressed) &&
              !isAltModifierPressed(pressed) &&
              key == LogicalKeyboardKey.enter)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.publishMemo,
          reason: matches(DesktopShortcutAction.publishMemo)
              ? 'binding'
              : 'shift_enter_fallback',
        );
        unawaited(_submitInlineCompose());
        return true;
      }
      if (matches(DesktopShortcutAction.bold)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.bold,
        );
        _toggleInlineBold();
        return true;
      }
      if (matches(DesktopShortcutAction.underline)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.underline,
        );
        _toggleInlineUnderline();
        return true;
      }
      if (matches(DesktopShortcutAction.highlight)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.highlight,
        );
        _toggleInlineHighlight();
        return true;
      }
      if (matches(DesktopShortcutAction.unorderedList)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.unorderedList,
        );
        _toggleInlineUnorderedList();
        return true;
      }
      if (matches(DesktopShortcutAction.orderedList)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.orderedList,
        );
        _toggleInlineOrderedList();
        return true;
      }
      if (matches(DesktopShortcutAction.undo)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.undo,
        );
        _undoInlineCompose();
        return true;
      }
      if (matches(DesktopShortcutAction.redo)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.redo,
        );
        _redoInlineCompose();
        return true;
      }
    }
    if (!inlineEditorActive &&
        matches(DesktopShortcutAction.previousPage) &&
        _handlePageNavigationShortcut(
          down: false,
          source: 'shortcut_previous_page',
        )) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.previousPage,
      );
      return true;
    }
    if (!inlineEditorActive &&
        matches(DesktopShortcutAction.nextPage) &&
        _handlePageNavigationShortcut(
          down: true,
          source: 'shortcut_next_page',
        )) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.nextPage,
      );
      return true;
    }

    if (matches(DesktopShortcutAction.enableAppLock)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.enableAppLock,
      );
      _openPasswordLockFromShortcut();
      return true;
    }
    if (matches(DesktopShortcutAction.toggleSidebar)) {
      final drawerResult = _toggleDesktopDrawerFromShortcut();
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.toggleSidebar,
        extra: {'drawerResult': drawerResult},
      );
      return true;
    }
    if (matches(DesktopShortcutAction.refresh)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.refresh,
      );
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
      return true;
    }
    if (matches(DesktopShortcutAction.backHome)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.backHome,
      );
      _backToAllMemos();
      return true;
    }
    if (matches(DesktopShortcutAction.openSettings)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.openSettings,
      );
      if (openDesktopSettingsWindowIfSupported(feedbackContext: context)) {
        return true;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      return true;
    }
    if (matches(DesktopShortcutAction.toggleFlomo)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.toggleFlomo,
      );
      unawaited(_toggleMemoFlowVisibilityFromShortcut());
      return true;
    }
    if (traceThisKey) {
      _logDesktopShortcutEvent(
        stage: 'no_match',
        event: event,
        pressedKeys: pressed,
        extra: {'inlineEditorActive': inlineEditorActive},
      );
    }
    return false;
  }

  Future<void> _syncDesktopWindowState() async {
    if (!Platform.isWindows) return;
    final maximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = maximized);
  }

  Future<void> _minimizeDesktopWindow() async {
    if (!Platform.isWindows) return;
    await windowManager.minimize();
  }

  Future<void> _toggleDesktopWindowMaximize() async {
    if (!Platform.isWindows) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncDesktopWindowState();
  }

  Future<void> _closeDesktopWindow() async {
    if (!Platform.isWindows) return;
    await DesktopExitCoordinator.requestClose(source: 'window_button');
  }

  Widget _buildPillActionsRow(
    BuildContext context, {
    required VoidCallback maybeHaptic,
  }) {
    return MemosListPillRow(
      onWeeklyInsights: () {
        maybeHaptic();
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const StatsScreen()));
      },
      onAiSummary: () {
        maybeHaptic();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AiSummaryScreen()),
        );
      },
      onDailyReview: () {
        maybeHaptic();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DailyReviewScreen()),
        );
      },
    );
  }

  Widget _buildWindowsDesktopTitleBar(
    BuildContext context, {
    required bool isDark,
    required bool enableHomeSort,
    required bool showPillActions,
    required VoidCallback maybeHaptic,
    required bool screenshotModeEnabled,
    required String debugApiVersionText,
  }) {
    final barBg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DragToMoveArea(child: SizedBox.expand()),
          Row(
            children: [
              SizedBox(
                width: 260,
                child: Row(
                  children: [
                    IgnorePointer(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/splash/splash_logo.png',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.auto_stories_rounded,
                              size: 22,
                              color: textColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: textColor, fontSize: 14),
                        child: widget.enableTitleMenu
                            ? _buildHeaderTitleWidget(
                                context,
                                maybeHaptic: maybeHaptic,
                              )
                            : IgnorePointer(
                                child: _buildHeaderTitleWidget(
                                  context,
                                  maybeHaptic: maybeHaptic,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _windowsHeaderSearchExpanded
                          ? _buildTopSearchField(
                              context,
                              isDark: isDark,
                              autofocus: false,
                              hasAdvancedFilters: _hasAdvancedSearchFilters,
                              onOpenAdvancedFilters: _openAdvancedSearchSheet,
                              hintText:
                                  context.t.strings.legacy.msg_quick_search,
                            )
                          : (showPillActions
                                ? _buildPillActionsRow(
                                    context,
                                    maybeHaptic: maybeHaptic,
                                  )
                                : const SizedBox.shrink()),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (enableHomeSort) ...[
                _buildSortMenuButton(context, isDark: isDark),
                const SizedBox(width: 2),
              ],
              if (widget.enableSearch)
                IconButton(
                  tooltip: _windowsHeaderSearchExpanded
                      ? context.t.strings.legacy.msg_cancel_2
                      : context.t.strings.legacy.msg_search,
                  onPressed: _toggleWindowsHeaderSearch,
                  icon: Icon(
                    _windowsHeaderSearchExpanded ? Icons.close : Icons.search,
                  ),
                ),
              if (kDebugMode && !screenshotModeEnabled) ...[
                IgnorePointer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MemoFlowPalette.primary.withValues(
                          alpha: isDark ? 0.24 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.45 : 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        debugApiVersionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MemoFlowPalette.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              DesktopWindowIconButton(
                tooltip: context.t.strings.legacy.msg_minimize,
                onPressed: () => unawaited(_minimizeDesktopWindow()),
                icon: Icons.minimize_rounded,
              ),
              DesktopWindowIconButton(
                tooltip: _desktopWindowMaximized
                    ? context.t.strings.legacy.msg_restore_window
                    : context.t.strings.legacy.msg_maximize,
                onPressed: () => unawaited(_toggleDesktopWindowMaximize()),
                icon: _desktopWindowMaximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
              ),
              DesktopWindowIconButton(
                tooltip: context.t.strings.legacy.msg_close,
                onPressed: () => unawaited(_closeDesktopWindow()),
                icon: Icons.close_rounded,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = false);
  }

  String _formatDuration(Duration? value) {
    if (value == null) return '--:--';
    final totalSeconds = value.inSeconds;
    final hh = totalSeconds ~/ 3600;
    final mm = (totalSeconds % 3600) ~/ 60;
    final ss = totalSeconds % 60;
    if (hh <= 0) {
      return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  void _openDrawerIfNeeded() {
    if (!mounted ||
        _openedDrawerOnStart ||
        !widget.openDrawerOnStart ||
        !widget.showDrawer) {
      return;
    }
    _openedDrawerOnStart = true;
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openSearch() {
    _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _openWindowsHeaderSearch() {
    if (!Platform.isWindows || !widget.enableSearch) return;
    _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    if (_windowsHeaderSearchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
      return;
    }
    setState(() => _windowsHeaderSearchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeWindowsHeaderSearch({bool clearQuery = true}) {
    if (!Platform.isWindows || !_windowsHeaderSearchExpanded) return;
    _searchFocusNode.unfocus();
    if (clearQuery) {
      _searchController.clear();
    }
    setState(() {
      _windowsHeaderSearchExpanded = false;
      _selectedQuickSearchKind = null;
      if (clearQuery) {
        _advancedSearchFilters = AdvancedSearchFilters.empty;
      }
    });
  }

  void _toggleWindowsHeaderSearch() {
    if (_windowsHeaderSearchExpanded) {
      _closeWindowsHeaderSearch();
      return;
    }
    _openWindowsHeaderSearch();
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _windowsHeaderSearchExpanded = false;
      _selectedQuickSearchKind = null;
      _advancedSearchFilters = AdvancedSearchFilters.empty;
    });
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(searchHistoryProvider.notifier).add(trimmed);
  }

  void _applySearchQuery(String query) {
    final trimmed = query.trim();
    _searchController.text = trimmed;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    setState(() {});
    _submitSearch(trimmed);
  }

  void _toggleQuickSearchKind(QuickSearchKind kind) {
    setState(() {
      if (_selectedQuickSearchKind == kind) {
        _selectedQuickSearchKind = null;
      } else {
        _selectedQuickSearchKind = kind;
      }
    });
  }

  List<({String label, _AdvancedSearchChipKind kind})>
  _buildActiveAdvancedSearchChipData(BuildContext context) {
    final filters = _advancedSearchFilters.normalized();
    if (filters.isEmpty) {
      return const <({String label, _AdvancedSearchChipKind kind})>[];
    }

    final chips = <({String label, _AdvancedSearchChipKind kind})>[];
    final createdDateRange = filters.createdDateRange;
    if (createdDateRange != null) {
      chips.add((
        label:
            '${context.t.strings.legacy.msg_date_range_2}: ${_dayDateFmt.format(createdDateRange.start)} - ${_dayDateFmt.format(createdDateRange.end)}',
        kind: _AdvancedSearchChipKind.createdDateRange,
      ));
    }
    if (filters.hasLocation != SearchToggleFilter.any &&
        (filters.hasLocation == SearchToggleFilter.no ||
            filters.locationContains.isEmpty)) {
      chips.add((
        label:
            '${context.t.strings.legacy.msg_location_2}: ${_localizedToggleFilterLabel(filters.hasLocation)}',
        kind: _AdvancedSearchChipKind.hasLocation,
      ));
    }
    if (filters.locationContains.isNotEmpty) {
      chips.add((
        label:
            '${context.t.strings.legacy.msg_location_contains}: ${filters.locationContains}',
        kind: _AdvancedSearchChipKind.locationContains,
      ));
    }
    if (filters.hasAttachments != SearchToggleFilter.any &&
        (filters.hasAttachments == SearchToggleFilter.no ||
            (filters.attachmentNameContains.isEmpty &&
                filters.attachmentType == null))) {
      chips.add((
        label:
            '${context.t.strings.legacy.msg_attachments}: ${_localizedToggleFilterLabel(filters.hasAttachments)}',
        kind: _AdvancedSearchChipKind.hasAttachments,
      ));
    }
    if (filters.attachmentNameContains.isNotEmpty) {
      chips.add((
        label:
            '${context.t.strings.legacy.msg_attachment_name_contains}: ${filters.attachmentNameContains}',
        kind: _AdvancedSearchChipKind.attachmentNameContains,
      ));
    }
    if (filters.attachmentType != null) {
      final typeLabel = switch (filters.attachmentType!) {
        AdvancedAttachmentType.image => context.t.strings.legacy.msg_image,
        AdvancedAttachmentType.audio => context.t.strings.legacy.msg_audio,
        AdvancedAttachmentType.document =>
          context.t.strings.legacy.msg_document,
        AdvancedAttachmentType.other => context.t.strings.legacy.msg_other,
      };
      chips.add((
        label: '${context.t.strings.legacy.msg_attachment_type}: $typeLabel',
        kind: _AdvancedSearchChipKind.attachmentType,
      ));
    }
    if (filters.hasRelations != SearchToggleFilter.any) {
      chips.add((
        label:
            '${context.t.strings.legacy.msg_linked_memos}: ${_localizedToggleFilterLabel(filters.hasRelations)}',
        kind: _AdvancedSearchChipKind.hasRelations,
      ));
    }

    return chips;
  }

  Widget _buildActiveAdvancedFilterSliver(BuildContext context) {
    final chips = _buildActiveAdvancedSearchChipData(context);
    if (chips.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.62);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.t.strings.legacy.msg_advanced_search,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearAdvancedSearchFilters,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.t.strings.legacy.msg_clear_all_filters,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  MemosListFilterTagChip(
                    label: chip.label,
                    onClear: () => _removeSingleAdvancedFilter(chip.kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _markSceneGuideSeen(SceneMicroGuideId id) {
    unawaited(ref.read(sceneMicroGuideProvider.notifier).markSeen(id));
  }

  String _desktopGlobalShortcutsGuideMessage(BuildContext context) {
    final bindings = ref.read(appPreferencesProvider).desktopShortcutBindings;
    final searchLabel = desktopShortcutGuideBindingLabel(
      bindings,
      DesktopShortcutAction.search,
    );
    final quickRecordLabel = desktopShortcutGuideBindingLabel(
      bindings,
      DesktopShortcutAction.quickRecord,
    );
    final overviewLabel = desktopShortcutGuideBindingLabel(
      bindings,
      DesktopShortcutAction.shortcutOverview,
    );
    return context.t.strings.legacy
        .msg_scene_micro_guide_desktop_global_shortcuts(
          search: searchLabel,
          quickRecord: quickRecordLabel,
          overview: overviewLabel,
        );
  }

  String _formatShortcutLoadError(BuildContext context, Object error) {
    if (error is UnsupportedError) {
      return context.t.strings.legacy.msg_shortcuts_not_supported_server;
    }
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return context.t.strings.legacy.msg_shortcuts_not_supported_server;
      }
    }
    return context.t.strings.legacy.msg_failed_load_shortcuts;
  }

  bool get _isAllMemos {
    final tag = _activeTagFilter;
    return widget.state == 'NORMAL' && (tag == null || tag.isEmpty);
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

  Future<bool> _handleWillPop() async {
    if (_windowsHeaderSearchExpanded) {
      _closeWindowsHeaderSearch();
      return false;
    }
    if (_searching) {
      _closeSearch();
      return false;
    }
    if (widget.dayFilter != null) {
      return true;
    }
    if (!_isAllMemos) {
      if (widget.showDrawer) {
        _backToAllMemos();
        return false;
      }
      return true;
    }

    if (!ref.read(appPreferencesProvider).confirmExitOnBack) {
      _lastBackPressedAt = null;
      dismissTopToast();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return true;
    }

    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      showTopToast(
        context,
        context.t.strings.legacy.msg_press_back_exit,
        duration: const Duration(seconds: 2),
      );
      return false;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return true;
  }

  void _navigateDrawer(AppDrawerDestination dest) {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final hasAccount =
        ref.read(appSessionProvider).valueOrNull?.currentAccount != null;
    if (!hasAccount && dest == AppDrawerDestination.explore) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }
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

  void _openNotifications() {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final hasAccount =
        ref.read(appSessionProvider).valueOrNull?.currentAccount != null;
    if (!hasAccount) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  void _openSyncQueue() {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SyncQueueScreen()));
  }

  Future<void> _retryFailedMemoSync(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) {
      _openSyncQueue();
      return;
    }
    final retried = await ref
        .read(memosListControllerProvider)
        .retryOutboxErrors(memoUid: normalizedUid);
    if (retried <= 0) {
      _openSyncQueue();
      return;
    }
    if (!mounted) return;
    showTopToast(context, context.t.strings.legacy.msg_retry_started);
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
  }

  Future<void> _handleMemoSyncStatusTap(
    MemoSyncStatus status,
    String memoUid,
  ) async {
    switch (status) {
      case MemoSyncStatus.failed:
        await _retryFailedMemoSync(memoUid);
        return;
      case MemoSyncStatus.pending:
      case MemoSyncStatus.none:
        _openSyncQueue();
        return;
    }
  }

  void _openTagFromDrawer(String tag) {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
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

  Future<void> _openNoteInput() async {
    if (!widget.enableCompose) return;
    await NoteInputSheet.show(context);
  }

  Future<void> _openVoiceNoteInput({
    VoiceRecordOverlayDragSession? dragSession,
  }) async {
    if (!widget.enableCompose) return;
    final result = await VoiceRecordScreen.showOverlay(
      context,
      autoStart: true,
      dragSession: dragSession,
    );
    if (!mounted || result == null) return;
    await NoteInputSheet.show(
      context,
      initialText: result.suggestedContent,
      initialAttachmentPaths: [result.filePath],
      ignoreDraft: true,
    );
  }

  Future<void> _handleVoiceFabLongPressStart(
    LongPressStartDetails details,
  ) async {
    if (!widget.enableCompose || _voiceOverlayDragFuture != null) return;
    final dragSession = VoiceRecordOverlayDragSession();
    _voiceOverlayDragSession = dragSession;
    dragSession.update(Offset.zero);
    final future = _openVoiceNoteInput(dragSession: dragSession);
    _voiceOverlayDragFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_voiceOverlayDragSession, dragSession)) {
          _voiceOverlayDragSession = null;
        }
        if (identical(_voiceOverlayDragFuture, future)) {
          _voiceOverlayDragFuture = null;
        }
      }),
    );
  }

  void _handleVoiceFabLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _voiceOverlayDragSession?.update(details.offsetFromOrigin);
  }

  void _handleVoiceFabLongPressEnd(LongPressEndDetails details) {
    _voiceOverlayDragSession?.endGesture();
  }

  void _applyInlineComposeDraft(AsyncValue<String> value) {
    if (_inlineComposeDraftApplied) return;
    final draft = value.valueOrNull;
    if (draft == null) return;
    if (_inlineComposeController.text.trim().isEmpty &&
        draft.trim().isNotEmpty) {
      _inlineComposeController.text = draft;
      _inlineComposeController.selection = TextSelection.collapsed(
        offset: draft.length,
      );
    }
    _inlineComposeDraftApplied = true;
  }

  void _scheduleInlineComposeDraftSave() {
    _inlineComposeDraftTimer?.cancel();
    final text = _inlineComposeController.text;
    _inlineComposeDraftTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(noteDraftProvider.notifier).setDraft(text);
    });
  }

  void _handleInlineComposeChanged() {
    _syncInlineTagAutocompleteState();
  }

  void _handleInlineComposeFocusChanged() {
    if (!mounted) return;
    _syncInlineTagAutocompleteState();
    setState(() {});
  }

  void _syncInlineTagAutocompleteState() {
    _inlineComposer.syncTagAutocompleteState(
      tagStats: _currentInlineTagStats(),
      hasFocus: _inlineComposeFocusNode.hasFocus,
    );
  }

  List<TagStat> _currentInlineTagStats() {
    return ref.read(tagStatsProvider).valueOrNull ?? const <TagStat>[];
  }

  (String label, IconData icon, Color color) _resolveInlineVisibilityStyle(
    BuildContext context,
    String raw,
  ) {
    switch (raw.trim().toUpperCase()) {
      case 'PUBLIC':
        return (
          context.t.strings.legacy.msg_public,
          Icons.public,
          const Color(0xFF3B8C52),
        );
      case 'PROTECTED':
        return (
          context.t.strings.legacy.msg_protected,
          Icons.verified_user,
          const Color(0xFFB26A2B),
        );
      default:
        return (
          context.t.strings.legacy.msg_private_2,
          Icons.lock,
          const Color(0xFF7C7C7C),
        );
    }
  }

  void _undoInlineCompose() {
    if (!_inlineCanUndo || _inlineComposeBusy) return;
    _inlineComposer.undo();
    if (mounted) setState(() {});
  }

  void _redoInlineCompose() {
    if (!_inlineCanRedo || _inlineComposeBusy) return;
    _inlineComposer.redo();
    if (mounted) setState(() {});
  }

  void _toggleInlineBold() {
    _inlineComposer.toggleBold();
  }

  void _toggleInlineUnderline() {
    _inlineComposer.toggleUnderline();
  }

  Future<void> _openAccountSwitcher() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final localLibraries = ref.read(localLibrariesProvider);
    final total = accounts.length + localLibraries.length;
    if (total < 2) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.t.strings.legacy.msg_switch_workspace),
              ),
            ),
            if (accounts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.t.strings.legacy.msg_accounts,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              ...accounts.map(
                (a) => ListTile(
                  leading: Icon(
                    a.key == session?.currentKey
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    a.user.displayName.isNotEmpty
                        ? a.user.displayName
                        : a.user.name,
                  ),
                  subtitle: Text(a.baseUrl.toString()),
                  onTap: () async {
                    await Navigator.of(context).maybePop();
                    if (!mounted) return;
                    await ref
                        .read(appSessionProvider.notifier)
                        .switchAccount(a.key);
                  },
                ),
              ),
            ],
            if (localLibraries.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.t.strings.legacy.msg_local_libraries,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              ...localLibraries.map(
                (l) => ListTile(
                  leading: Icon(
                    l.key == session?.currentKey
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    l.name.isNotEmpty
                        ? l.name
                        : context.t.strings.legacy.msg_local_library,
                  ),
                  subtitle: Text(l.locationLabel),
                  onTap: () async {
                    await Navigator.of(context).maybePop();
                    if (!mounted) return;
                    await ref
                        .read(appSessionProvider.notifier)
                        .switchWorkspace(l.key);
                    if (!mounted) return;
                    await WidgetsBinding.instance.endOfFrame;
                    if (!mounted) return;
                    await _maybeScanLocalLibrary();
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeScanLocalLibrary() async {
    if (!mounted) return;
    final syncState = ref.read(syncCoordinatorProvider).memos;
    if (syncState.running) {
      showTopToast(context, context.t.strings.legacy.msg_syncing);
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_scan_local_library),
            content: Text(
              context
                  .t
                  .strings
                  .legacy
                  .msg_scan_disk_directory_merge_local_database,
            ),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_scan),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    if (!mounted) return;
    final currentSyncState = ref.read(syncCoordinatorProvider).memos;
    if (currentSyncState.running) {
      showTopToast(context, context.t.strings.legacy.msg_syncing);
      return;
    }
    final scanner = ref.read(localLibraryScannerProvider);
    if (scanner == null) return;
    try {
      var result = await scanner.scanAndMerge(forceDisk: false);
      while (result is LocalScanConflictResult) {
        final decisions = await _resolveLocalScanConflicts(result.conflicts);
        result = await scanner.scanAndMerge(
          forceDisk: false,
          conflictDecisions: decisions,
        );
      }
      if (!mounted) return;
      switch (result) {
        case LocalScanSuccess():
          showTopToast(context, context.t.strings.legacy.msg_scan_completed);
          return;
        case LocalScanFailure(:final error):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.strings.legacy.msg_scan_failed(
                  e: _formatLocalScanError(error),
                ),
              ),
            ),
          );
          return;
        default:
          return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_scan_failed(e: e))),
      );
    }
  }

  Future<Map<String, bool>> _resolveLocalScanConflicts(
    List<LocalScanConflict> conflicts,
  ) async {
    final decisions = <String, bool>{};
    for (final conflict in conflicts) {
      final useDisk =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.t.strings.legacy.msg_resolve_conflict),
              content: Text(
                conflict.isDeletion
                    ? context
                          .t
                          .strings
                          .legacy
                          .msg_memo_missing_disk_but_has_local
                    : context
                          .t
                          .strings
                          .legacy
                          .msg_disk_content_conflicts_local_pending_changes,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.t.strings.legacy.msg_keep_local),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.t.strings.legacy.msg_use_disk),
                ),
              ],
            ),
          ) ??
          false;
      decisions[conflict.memoUid] = useDisk;
    }
    return decisions;
  }

  String _formatLocalScanError(SyncError error) {
    return presentSyncError(language: context.appLanguage, error: error);
  }

  void _maybeAutoScanLocalLibrary({
    required bool memosLoading,
    required List<LocalMemo>? memosValue,
    required bool useRemoteSearch,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required String searchQuery,
    required String? resolvedTag,
    required DateTime? filterDay,
  }) {
    if (_autoScanTriggered || _autoScanInFlight) return;
    if (memosLoading) return;
    if (useRemoteSearch || useShortcutFilter || useQuickSearch) return;
    if (widget.state != 'NORMAL') return;
    if (searchQuery.trim().isNotEmpty) return;
    if (resolvedTag != null && resolvedTag.trim().isNotEmpty) return;
    if (filterDay != null) return;
    if (memosValue != null && memosValue.isNotEmpty) return;

    final scanner = ref.read(localLibraryScannerProvider);
    if (scanner == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _autoScanInFlight = true;
      var bootstrapModeEnabled = false;
      try {
        final hasLocalMemos = await ref
            .read(memosListControllerProvider)
            .hasAnyLocalMemos();
        if (!mounted) return;
        if (hasLocalMemos) return;

        final diskMemos = await scanner.fileSystem.listMemos();
        if (!mounted || diskMemos.isEmpty) return;
        if (diskMemos.length >= _bootstrapImportThreshold) {
          bootstrapModeEnabled = true;
          setState(() {
            _bootstrapImportActive = true;
            _bootstrapImportTotal = diskMemos.length;
            _bootstrapImportStartedAt = DateTime.now();
          });
        }
        _autoScanTriggered = true;
        await ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_local_library_import_failed(e: e),
            ),
          ),
        );
      } finally {
        if (bootstrapModeEnabled && mounted) {
          setState(() {
            _bootstrapImportActive = false;
            _bootstrapImportTotal = 0;
            _bootstrapImportStartedAt = null;
          });
        }
        _autoScanInFlight = false;
      }
    });
  }

  Widget _buildBootstrapImportOverlay(
    BuildContext context, {
    required bool isDark,
    required int importedCount,
    required int totalCount,
    required Duration? elapsed,
  }) {
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.62 : 0.58);
    final backdropColor =
        (isDark
                ? MemoFlowPalette.backgroundDark
                : MemoFlowPalette.backgroundLight)
            .withValues(alpha: isDark ? 0.94 : 0.96);
    final safeTotal = totalCount <= 0 ? importedCount : totalCount;
    final safeImported = importedCount.clamp(0, safeTotal).toInt();
    final progress = safeTotal > 0
        ? (safeImported / safeTotal).clamp(0.0, 1.0).toDouble()
        : null;
    final elapsedText = elapsed == null ? null : _formatDuration(elapsed);

    return AbsorbPointer(
      child: Container(
        color: backdropColor,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor.withValues(alpha: 0.92)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: MemoFlowPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.t.strings.legacy.msg_importing_memos,
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${context.t.strings.legacy.msg_imported_memos}: $safeImported / $safeTotal',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: MemoFlowPalette.primary,
                      backgroundColor: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.2 : 0.16,
                      ),
                    ),
                  ),
                ],
                if (elapsedText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${context.t.strings.legacy.msg_loading} $elapsedText',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitInlineCompose() async {
    if (_inlineComposeBusy || !widget.enableCompose) return;
    final draft = await _inlineComposeCoordinator.prepareSubmissionDraft(
      context,
    );
    if (!mounted || draft == null) return;

    setState(() => _inlineComposeBusy = true);
    try {
      final now = DateTime.now();
      final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      final uid = generateUid();

      await ref
          .read(memosListControllerProvider)
          .createInlineComposeMemo(
            uid: uid,
            content: draft.content,
            visibility: draft.visibility,
            nowSec: nowSec,
            tags: draft.tags,
            attachments: draft.attachmentsPayload,
            location: draft.location,
            relations: draft.relations,
            pendingAttachments: draft.pendingAttachments,
          );

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
      _inlineComposeDraftTimer?.cancel();
      await ref.read(noteDraftProvider.notifier).clear();
      _inlineComposeCoordinator.resetAfterSuccessfulSubmit();
      if (mounted) {
        _inlineComposeFocusNode.requestFocus();
      }
    } catch (error, stackTrace) {
      ref
          .read(logManagerProvider)
          .error(
            'Inline compose submit failed',
            error: error,
            stackTrace: stackTrace,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_create_failed_2(e: error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _inlineComposeBusy = false);
      }
    }
  }

  Future<void> _createShortcutFromMenu() async {
    final result = await Navigator.of(context).push<ShortcutEditorResult>(
      MaterialPageRoute<ShortcutEditorResult>(
        builder: (_) => const ShortcutEditorScreen(),
      ),
    );
    if (result == null) return;

    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_not_authenticated)),
      );
      return;
    }
    try {
      final created = await ref
          .read(memosListControllerProvider)
          .createShortcut(title: result.title, filter: result.filter);
      ref.invalidate(shortcutsProvider);
      if (!mounted) return;
      setState(() {
        _selectedShortcutId = created.shortcutId;
        _selectedQuickSearchKind = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_create_failed_2(e: e)),
        ),
      );
    }
  }

  Future<void> _openTitleMenu() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final showShortcuts = _isAllMemos && session?.currentAccount != null;
    if (!showShortcuts && accounts.length < 2) return;
    if (showShortcuts) {
      _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    }

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || titleBox == null) return;
    if (!overlay.hasSize || !titleBox.hasSize) return;
    if (overlay.size.width <= 40 || overlay.size.height <= 40) return;

    final position = titleBox.localToGlobal(Offset.zero, ancestor: overlay);
    final maxWidth = overlay.size.width - 24;
    if (maxWidth <= 0) return;
    final width = (maxWidth < 220 ? maxWidth : 240).toDouble().clamp(
      140.0,
      320.0,
    );
    final left = position.dx.clamp(12.0, overlay.size.width - width - 12.0);
    final top = position.dy + titleBox.size.height + 6;
    final availableHeight = overlay.size.height - top - 16;
    final menuMaxHeight =
        (availableHeight > 120 ? availableHeight : overlay.size.height * 0.6)
            .clamp(140.0, overlay.size.height - 12.0);

    final action = await showGeneralDialog<MemosListTitleMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'title_menu',
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, _) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: MemosListTitleMenuDropdown(
              selectedShortcutId: _selectedShortcutId,
              showShortcuts: showShortcuts,
              showAccountSwitcher: accounts.length > 1,
              maxHeight: menuMaxHeight,
              formatShortcutError: _formatShortcutLoadError,
            ),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action.type) {
      case MemosListTitleMenuActionType.selectShortcut:
        setState(() {
          _selectedShortcutId = action.shortcutId;
          _selectedQuickSearchKind = null;
        });
        break;
      case MemosListTitleMenuActionType.clearShortcut:
        setState(() => _selectedShortcutId = null);
        break;
      case MemosListTitleMenuActionType.createShortcut:
        await _createShortcutFromMenu();
        break;
      case MemosListTitleMenuActionType.openAccountSwitcher:
        await _openAccountSwitcher();
        break;
    }
  }

  Future<void> _updateMemo(
    LocalMemo memo, {
    bool? pinned,
    String? state,
  }) async {
    await ref
        .read(memosListControllerProvider)
        .updateMemo(memo, pinned: pinned, state: state);
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
  }

  Future<void> _updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
    bool triggerSync = true,
  }) async {
    if (content == memo.content) return;
    await ref
        .read(memosListControllerProvider)
        .updateMemoContent(
          memo,
          content,
          preserveUpdateTime: preserveUpdateTime,
        );
    if (triggerSync) {
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
    }
  }

  Future<void> _toggleMemoCheckbox(
    LocalMemo memo,
    int checkboxIndex, {
    required bool skipQuotedLines,
  }) async {
    final updated = toggleCheckbox(
      memo.content,
      checkboxIndex,
      skipQuotedLines: skipQuotedLines,
    );
    if (updated == memo.content) return;
    invalidateMemoRenderCacheForUid(memo.uid);
    invalidateMemoMarkdownCacheForUid(memo.uid);
    await _updateMemoContent(
      memo,
      updated,
      preserveUpdateTime: true,
      triggerSync: false,
    );
  }

  Future<void> _deleteMemo(LocalMemo memo) async {
    final confirmed =
        await showDialog<bool>(
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
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await ref
          .read(memosListControllerProvider)
          .deleteMemo(
            memo,
            onMovedToRecycleBin: () => _removeMemoWithAnimation(memo),
          );
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_delete_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _restoreMemo(LocalMemo memo) async {
    try {
      await _updateMemo(memo, state: 'NORMAL');
      if (!mounted) return;
      final message = context.t.strings.legacy.msg_restored;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MemosListScreen(
            title: 'MemoFlow',
            state: 'NORMAL',
            showDrawer: true,
            enableCompose: true,
            toastMessage: message,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_restore_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _archiveMemo(LocalMemo memo) async {
    try {
      await _updateMemo(memo, state: 'ARCHIVED');
      _removeMemoWithAnimation(memo);
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_archived);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_archive_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _handleMemoAction(LocalMemo memo, MemoCardAction action) async {
    switch (action) {
      case MemoCardAction.togglePinned:
        await _updateMemo(memo, pinned: !memo.pinned);
        return;
      case MemoCardAction.edit:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoEditorScreen(existing: memo),
          ),
        );
        ref.invalidate(memoRelationsProvider(memo.uid));
        return;
      case MemoCardAction.history:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoVersionsScreen(memoUid: memo.uid),
          ),
        );
        return;
      case MemoCardAction.reminder:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoReminderEditorScreen(memo: memo),
          ),
        );
        return;
      case MemoCardAction.archive:
        await _archiveMemo(memo);
        return;
      case MemoCardAction.restore:
        await _restoreMemo(memo);
        return;
      case MemoCardAction.delete:
        await _deleteMemo(memo);
        return;
    }
  }

  void _removeMemoWithAnimation(LocalMemo memo) {
    final index = _animatedMemos.indexWhere((m) => m.uid == memo.uid);
    if (index < 0) return;
    final removed = _animatedMemos.removeAt(index);
    _pendingRemovedUids.add(removed.uid);
    final outboxStatus =
        ref.read(memosListOutboxStatusProvider).valueOrNull ??
        const OutboxMemoStatus.empty();
    final tagColors = ref.watch(tagColorLookupProvider);

    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildAnimatedMemoItem(
        context: context,
        memo: removed,
        animation: animation,
        prefs: ref.read(appPreferencesProvider),
        outboxStatus: outboxStatus,
        removing: true,
        tagColors: tagColors,
      ),
      duration: const Duration(milliseconds: 380),
    );
    setState(() {});
  }

  void _syncAnimatedMemos(List<LocalMemo> memos, String signature) {
    if (_pendingRemovedUids.isNotEmpty) {
      final memoIds = memos.map((m) => m.uid).toSet();
      _pendingRemovedUids.removeWhere((uid) => !memoIds.contains(uid));
    }
    final filtered = memos
        .where((m) => !_pendingRemovedUids.contains(m.uid))
        .toList(growable: true);
    final sameSignature = _listSignature == signature;

    // Pagination appends items at the tail. Keep list state and insert rows
    // instead of rebuilding the whole sliver to avoid scroll jumps on desktop.
    if (sameSignature &&
        _animatedMemos.isNotEmpty &&
        filtered.length > _animatedMemos.length &&
        _sameMemoPrefix(_animatedMemos, filtered)) {
      final insertStart = _animatedMemos.length;
      final insertCount = filtered.length - _animatedMemos.length;
      _logPaginationDebug(
        'animated_list_append_prepare',
        metrics: _scrollController.hasClients
            ? _scrollController.position
            : null,
        context: {
          'signature': signature,
          'beforeLength': _animatedMemos.length,
          'afterLength': filtered.length,
          'insertStart': insertStart,
          'insertCount': insertCount,
        },
      );
      _animatedMemos = filtered;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final state = _listKey.currentState;
        if (state == null) return;
        for (var i = 0; i < insertCount; i++) {
          state.insertItem(insertStart + i, duration: Duration.zero);
        }
        _logPaginationDebug(
          'animated_list_append_applied',
          metrics: _scrollController.hasClients
              ? _scrollController.position
              : null,
          context: {
            'signature': signature,
            'insertCount': insertCount,
            'currentLength': _animatedMemos.length,
          },
        );
      });
      return;
    }

    final signatureChanged = _listSignature != signature;
    final listChanged = !_sameMemoList(_animatedMemos, filtered);
    if (signatureChanged || listChanged) {
      final beforeLength = _animatedMemos.length;
      final afterLength = filtered.length;
      if (afterLength < beforeLength) {
        _logVisibleCountDecrease(
          beforeLength: beforeLength,
          afterLength: afterLength,
          signatureChanged: signatureChanged,
          listChanged: listChanged,
          fromSignature: _listSignature,
          toSignature: signature,
          removedSample: _collectRemovedMemoUids(
            _animatedMemos,
            filtered,
            limit: 8,
          ),
        );
      }
      _logPaginationDebug(
        'animated_list_rebuild',
        metrics: _scrollController.hasClients
            ? _scrollController.position
            : null,
        context: {
          'signatureChanged': signatureChanged,
          'listChanged': listChanged,
          'fromSignature': _listSignature,
          'toSignature': signature,
          'beforeLength': beforeLength,
          'afterLength': afterLength,
        },
      );
      _listSignature = signature;
      _animatedMemos = filtered;
      _listKey = GlobalKey<SliverAnimatedListState>();
      return;
    }

    var changed = false;
    final next = List<LocalMemo>.from(_animatedMemos);
    for (var i = 0; i < filtered.length; i++) {
      if (!_sameMemoData(_animatedMemos[i], filtered[i])) {
        next[i] = filtered[i];
        changed = true;
      }
    }
    if (changed) {
      _animatedMemos = next;
    }
  }

  static bool _sameMemoList(List<LocalMemo> a, List<LocalMemo> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].uid != b[i].uid) return false;
    }
    return true;
  }

  static List<String> _collectRemovedMemoUids(
    List<LocalMemo> before,
    List<LocalMemo> after, {
    int limit = 8,
  }) {
    if (before.isEmpty || limit <= 0) return const <String>[];
    final afterUids = after.map((memo) => memo.uid).toSet();
    final removed = <String>[];
    for (final memo in before) {
      if (afterUids.contains(memo.uid)) continue;
      removed.add(memo.uid);
      if (removed.length >= limit) break;
    }
    return removed;
  }

  static bool _sameMemoPrefix(List<LocalMemo> prefix, List<LocalMemo> full) {
    if (prefix.length > full.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i].uid != full[i].uid) return false;
    }
    return true;
  }

  static bool _sameMemoData(LocalMemo a, LocalMemo b) {
    if (identical(a, b)) return true;
    if (a.uid != b.uid) return false;
    if (a.content != b.content) return false;
    if (a.visibility != b.visibility) return false;
    if (a.pinned != b.pinned) return false;
    if (a.state != b.state) return false;
    if (a.createTime != b.createTime) return false;
    if (a.updateTime != b.updateTime) return false;
    if (a.syncState != b.syncState) return false;
    if (a.lastError != b.lastError) return false;
    if (!listEquals(a.tags, b.tags)) return false;
    if (!_sameAttachments(a.attachments, b.attachments)) return false;
    return true;
  }

  static bool _sameAttachments(List<Attachment> a, List<Attachment> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.name != right.name) return false;
      if (left.filename != right.filename) return false;
      if (left.type != right.type) return false;
      if (left.size != right.size) return false;
      if (left.externalLink != right.externalLink) return false;
    }
    return true;
  }

  Widget _buildAnimatedMemoItem({
    required BuildContext context,
    required LocalMemo memo,
    required Animation<double> animation,
    required AppPreferences prefs,
    required OutboxMemoStatus outboxStatus,
    required bool removing,
    required TagColorLookup tagColors,
  }) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    Widget memoCard = MemosListMemoCardContainer(
      memoCardKey: _memoCardKeyFor(memo.uid),
      memo: memo,
      prefs: prefs,
      outboxStatus: outboxStatus,
      tagColors: tagColors,
      removing: removing,
      searching: _searching,
      windowsHeaderSearchExpanded: _windowsHeaderSearchExpanded,
      selectedQuickSearchKind: _selectedQuickSearchKind,
      searchQuery: _searchController.text,
      playingMemoUid: _audioPlaybackCoordinator.playingMemoUid,
      audioPlaying: _audioPlaybackCoordinator.audioPlaying,
      audioLoading: _audioPlaybackCoordinator.audioLoading,
      audioPositionListenable: _audioPlaybackCoordinator.positionListenable,
      audioDurationListenable: _audioPlaybackCoordinator.durationListenable,
      onAudioSeek: (pos) =>
          unawaited(_audioPlaybackCoordinator.seek(memo, pos)),
      onAudioTap: () => unawaited(_handleMemoAudioTap(memo)),
      onSyncStatusTap: (status) =>
          unawaited(_handleMemoSyncStatusTap(status, memo.uid)),
      onToggleTask: (index) {
        unawaited(
          _toggleMemoCheckbox(
            memo,
            index,
            skipQuotedLines: prefs.collapseReferences,
          ),
        );
      },
      onTap: () {
        if (prefs.hapticsEnabled) {
          HapticFeedback.selectionClick();
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoDetailScreen(initialMemo: memo),
          ),
        );
      },
      onDoubleTap: () {
        if (prefs.hapticsEnabled) {
          HapticFeedback.selectionClick();
        }
        _markSceneGuideSeen(SceneMicroGuideId.memoListGestures);
        unawaited(_handleMemoAction(memo, MemoCardAction.edit));
      },
      onLongPress: () async {
        if (prefs.hapticsEnabled) {
          HapticFeedback.selectionClick();
        }
        _markSceneGuideSeen(SceneMicroGuideId.memoListGestures);
        await Clipboard.setData(ClipboardData(text: memo.content));
        if (!context.mounted) return;
        showTopToast(
          context,
          context.t.strings.legacy.msg_memo_copied,
          duration: const Duration(milliseconds: 1200),
        );
      },
      onFloatingStateChanged: _requestFloatingCollapseRecompute,
      onAction: (action) async => _handleMemoAction(memo, action),
    );
    if (Platform.isWindows) {
      memoCard = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kMemoFlowDesktopMemoCardMaxWidth,
          ),
          child: memoCard,
        ),
      );
    }
    return SizeTransition(
      sizeFactor: curved,
      axis: Axis.vertical,
      axisAlignment: 0.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: memoCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text;
    final filterDay = widget.dayFilter;
    final shortcutsAsync = ref.watch(shortcutsProvider);
    final shortcuts = shortcutsAsync.valueOrNull ?? const <Shortcut>[];
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;
    final queryState = buildMemosListScreenQueryState(
      searchQuery: searchQuery,
      filterDay: filterDay,
      state: widget.state,
      pageSize: _pageSize,
      shortcuts: shortcuts,
      selectedShortcutId: _selectedShortcutId,
      selectedQuickSearchKind: _selectedQuickSearchKind,
      resolvedTag: _activeTagFilter,
      advancedFilters: _advancedSearchFilters,
      searching: _searching,
      showDrawer: widget.showDrawer,
    );
    final layoutState = buildMemosListScreenLayoutState(
      query: queryState,
      state: widget.state,
      showDrawer: widget.showDrawer,
      showPillActions: widget.showPillActions,
      showFilterTagChip: widget.showFilterTagChip,
      enableCompose: widget.enableCompose,
      searching: _searching,
      screenWidth: screenWidth,
      isWindowsDesktop: Platform.isWindows,
    );
    final resolvedTag = queryState.resolvedTag;
    final advancedFilters = queryState.advancedFilters;
    final useShortcutFilter = queryState.useShortcutFilter;
    final useQuickSearch = queryState.useQuickSearch;
    final useRemoteSearch = queryState.useRemoteSearch;
    final shortcutFilter = queryState.shortcutFilter;
    final selectedQuickSearchKind = queryState.selectedQuickSearchKind;
    final shortcutQuery = queryState.shortcutQuery;
    final quickSearchQuery = queryState.quickSearchQuery;
    final queryKey = queryState.queryKey;
    final previousQueryKey = _paginationKey;
    if (_viewportCoordinator.syncQueryKey(
      queryKey,
      previousVisibleCount: _currentResultCount,
    )) {
      final previousVisibleCount = _currentResultCount;
      if (previousVisibleCount > 0 && previousQueryKey.isNotEmpty) {
        ref
            .read(logManagerProvider)
            .info(
              'Memos pagination: query_changed_reset_results',
              context: <String, Object?>{
                'visibleCountBeforeReset': previousVisibleCount,
                'fromKey': previousQueryKey,
                'toKey': queryKey,
              },
            );
      }
      _logPaginationDebug(
        'query_key_changed_reset_pagination',
        context: {'fromKey': previousQueryKey, 'toKey': queryKey},
      );
    }
    final memosAsync = switch (queryState.sourceKind) {
      MemosListMemoSourceKind.shortcut => ref.watch(
        shortcutMemosProvider(shortcutQuery!),
      ),
      MemosListMemoSourceKind.quickSearch => ref.watch(
        quickSearchMemosProvider(quickSearchQuery!),
      ),
      MemosListMemoSourceKind.remoteSearch => ref.watch(
        remoteSearchMemosProvider(queryState.baseQuery),
      ),
      MemosListMemoSourceKind.stream => ref.watch(
        memosStreamProvider(queryState.baseQuery),
      ),
    };
    final syncState = ref.watch(syncCoordinatorProvider).memos;
    final syncQueueSnapshot = ref
        .watch(syncQueueProgressTrackerProvider)
        .snapshot;
    final outboxStatus =
        ref.watch(memosListOutboxStatusProvider).valueOrNull ??
        const OutboxMemoStatus.empty();
    final searchHistory = ref.watch(searchHistoryProvider);
    final tagStats =
        ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final tagColorLookup = ref.watch(tagColorLookupProvider);
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
    final toolbarPreferences = ref.watch(
      appPreferencesProvider.select((p) => p.memoToolbarPreferences),
    );
    final inlineVisibility = _inlineComposeCoordinator.currentVisibility();
    final inlineVisibilityStyle = _resolveInlineVisibilityStyle(
      context,
      inlineVisibility,
    );
    final tagPresentationSignature = buildMemosListTagPresentationSignature(
      tagStats,
    );
    final memosValue = memosAsync.valueOrNull;
    final memosLoading = memosAsync.isLoading;
    final memosError = memosAsync.whenOrNull(error: (e, _) => e);
    final normalMemoCount =
        ref.watch(memosListNormalMemoCountProvider).valueOrNull ?? 0;
    final bootstrapImportedCount = _bootstrapImportTotal > 0
        ? normalMemoCount.clamp(0, _bootstrapImportTotal).toInt()
        : normalMemoCount;
    final bootstrapElapsed = _bootstrapImportStartedAt == null
        ? null
        : DateTime.now().difference(_bootstrapImportStartedAt!);
    final hasProviderValue = memosValue != null;

    final nextResultCount = hasProviderValue
        ? memosValue.length
        : _animatedMemos.length;
    final previousCount = _lastResultCount;
    final wasLoadingMore = _loadingMore;
    final requestId = _activeLoadMoreRequestId;
    final requestSource = _activeLoadMoreSource;
    _viewportCoordinator.updateSnapshot(
      hasProviderValue: hasProviderValue,
      resultCount: nextResultCount,
      providerLoading: memosLoading,
      showSearchLanding: queryState.showSearchLanding,
    );
    if (hasProviderValue && _currentResultCount != previousCount) {
      if (wasLoadingMore) {
        _logPaginationDebug(
          'load_more_applied',
          metrics: _scrollController.hasClients
              ? _scrollController.position
              : null,
          context: {
            'requestId': requestId,
            'source': requestSource,
            'previousCount': previousCount,
            'nextCount': _currentResultCount,
            'delta': _currentResultCount - previousCount,
          },
        );
      }
    }

    _maybeAutoScanLocalLibrary(
      memosLoading: memosLoading,
      memosValue: memosValue,
      useRemoteSearch: useRemoteSearch,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      searchQuery: searchQuery,
      resolvedTag: resolvedTag,
      filterDay: filterDay,
    );

    if (memosValue != null) {
      final sortedMemos = queryState.enableHomeSort
          ? _applyHomeSort(memosValue)
          : memosValue;
      final listSignature =
          '${widget.state}|${resolvedTag ?? ''}|${searchQuery.trim()}|${shortcutFilter.trim()}|'
          '${useShortcutFilter ? 1 : 0}|${selectedQuickSearchKind?.name ?? ''}|'
          '${useQuickSearch ? 1 : 0}|${queryState.startTimeSec ?? ''}|${queryState.endTimeSecExclusive ?? ''}|'
          '${queryState.enableHomeSort ? _sortOption.name : 'default'}|$tagPresentationSignature|'
          '${advancedFilters.signature}';
      _syncAnimatedMemos(sortedMemos, listSignature);
    }
    final visibleMemos = _animatedMemos;
    _syncMemoCardKeys(visibleMemos);
    _requestFloatingCollapseRecompute();
    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    final screenshotModeEnabled = kDebugMode
        ? ref.watch(debugScreenshotModeProvider)
        : false;
    final session = ref.watch(appSessionProvider).valueOrNull;
    final currentLocalLibrary = ref.watch(currentLocalLibraryProvider);
    final sceneGuideState = ref.watch(sceneMicroGuideProvider);
    final guideState = buildMemosListScreenGuideState(
      isAllMemos: _isAllMemos,
      enableSearch: widget.enableSearch,
      enableTitleMenu: widget.enableTitleMenu,
      searching: _searching,
      sessionHasAccount: session?.currentAccount != null,
      desktopShortcutEnabled: isDesktopShortcutEnabled(),
      hasVisibleMemos: visibleMemos.isNotEmpty,
      guideState: sceneGuideState,
      presentedListGuideId: _presentedListGuideId,
    );
    final viewState = buildMemosListScreenViewState(
      query: queryState,
      layout: layoutState,
      guide: guideState,
      tagStats: tagStats,
      tagColorLookup: tagColorLookup,
      templateSettings: templateSettings,
    );
    final activeListGuideId = viewState.guide.activeListGuideId;
    if (_presentedListGuideId == null && activeListGuideId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _presentedListGuideId != null) return;
        setState(() => _presentedListGuideId = activeListGuideId);
      });
    }
    _maybeLogMemosLoadingPhase(
      queryKey: queryKey,
      memosLoading: memosLoading,
      memosError: memosError,
      memosValue: memosValue,
      visibleMemos: visibleMemos,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      useRemoteSearch: useRemoteSearch,
      shortcutFilter: shortcutFilter,
      quickSearchKind: selectedQuickSearchKind,
      syncState: syncState,
      syncQueueSnapshot: syncQueueSnapshot,
    );
    _maybeLogEmptyViewDiagnostics(
      queryKey: queryKey,
      memosValue: memosValue,
      memosLoading: memosLoading,
      memosError: memosError,
      visibleMemos: visibleMemos,
      searchQuery: searchQuery,
      resolvedTag: resolvedTag,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      useRemoteSearch: useRemoteSearch,
      startTimeSec: queryState.startTimeSec,
      endTimeSecExclusive: queryState.endTimeSecExclusive,
      shortcutFilter: shortcutFilter,
      quickSearchKind: selectedQuickSearchKind,
    );
    final showLoadMoreHint =
        memosError == null &&
        visibleMemos.isNotEmpty &&
        !viewState.query.showSearchLanding;
    final loadMoreBusy = _loadingMore || _currentLoading;
    final touchPullLoadEnabled = _isTouchPullLoadPlatform();
    final loadMoreHintText = loadMoreBusy
        ? context.t.strings.legacy.msg_loading
        : (_reachedEnd
              ? context.t.strings.legacy.msg_loaded_all_content
              : (touchPullLoadEnabled
                    ? (_mobileBottomPullArmed
                          ? context.t.strings.legacy.msg_release_to_load_more
                          : context.t.strings.legacy.msg_pull_up_to_load_more)
                    : context.t.strings.legacy.msg_scroll_down_to_load_more));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loadMoreHintTextColor =
        (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
            .withValues(alpha: isDark ? 0.52 : 0.46);
    final loadMoreHintDisplayText = '- $loadMoreHintText -';
    final headerBg =
        (isDark
                ? MemoFlowPalette.backgroundDark
                : MemoFlowPalette.backgroundLight)
            .withValues(alpha: 0.9);
    final activeListGuideMessage = switch (activeListGuideId) {
      SceneMicroGuideId.desktopGlobalShortcuts =>
        _desktopGlobalShortcutsGuideMessage(context),
      SceneMicroGuideId.memoListSearchAndShortcuts =>
        context.t.strings.legacy.msg_scene_micro_guide_list_search_shortcuts,
      SceneMicroGuideId.memoListGestures =>
        context.t.strings.legacy.msg_scene_micro_guide_list_gestures,
      _ => null,
    };
    if (kDebugMode) {
      final currentKey = session?.currentKey;
      final resolvedDb = (currentKey == null || currentKey.trim().isEmpty)
          ? null
          : databaseNameForAccountKey(currentKey);
      final workspaceMode = currentLocalLibrary != null
          ? 'local'
          : (session?.currentAccount != null ? 'remote' : 'none');
      final debugSignature = [
        currentKey ?? '',
        resolvedDb ?? '',
        workspaceMode,
        currentLocalLibrary?.key ?? '',
        currentLocalLibrary?.name ?? '',
        currentLocalLibrary?.locationLabel ?? '',
      ].join('|');
      if (_lastWorkspaceDebugSignature != debugSignature) {
        _lastWorkspaceDebugSignature = debugSignature;
        ref
            .read(logManagerProvider)
            .info(
              'MemosList build: workspace_debug',
              context: <String, Object?>{
                'event': 'build',
                'currentKey': currentKey,
                'resolvedDbName': resolvedDb,
                'workspaceMode': workspaceMode,
                'currentLocalLibraryNull': currentLocalLibrary == null,
                'localLibraryKey': currentLocalLibrary?.key,
                'localLibraryName': currentLocalLibrary?.name,
                'localLibraryLocation': currentLocalLibrary?.locationLabel,
              },
            );
      }
    }
    final debugApiVersionText = ref.watch(memosListDebugApiVersionTextProvider);
    final drawerPanel = widget.showDrawer
        ? AppDrawer(
            selected: widget.state == 'ARCHIVED'
                ? AppDrawerDestination.archived
                : AppDrawerDestination.memos,
            onSelect: _navigateDrawer,
            onSelectTag: _openTagFromDrawer,
            onOpenNotifications: _openNotifications,
            embedded: viewState.layout.useDesktopSidePane,
            selectedTagPath: (resolvedTag ?? '').trim().isEmpty
                ? null
                : resolvedTag!.trim(),
          )
        : null;
    void maybeHaptic() {
      if (!hapticsEnabled) return;
      HapticFeedback.selectionClick();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (!context.mounted) return;
        if (!shouldPop) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          if (Platform.isWindows) {
            await DesktopExitCoordinator.requestExit(reason: 'back');
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: viewState.layout.useDesktopSidePane ? null : drawerPanel,
        drawerEnableOpenDragGesture:
            !viewState.layout.useDesktopSidePane &&
            widget.showDrawer &&
            !_searching,
        drawerEdgeDragWidth:
            !viewState.layout.useDesktopSidePane &&
                widget.showDrawer &&
                !_searching
            ? screenWidth
            : null,
        body: (() {
          final memoListBody = Stack(
            key: _floatingCollapseViewportKey,
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  final scanner = ref.read(localLibraryScannerProvider);
                  final coordinator = ref.read(
                    syncCoordinatorProvider.notifier,
                  );
                  if (ref.read(syncCoordinatorProvider).memos.running) {
                    if (context.mounted) {
                      showTopToast(
                        context,
                        context.t.strings.legacy.msg_syncing,
                      );
                    }
                    final deadline = DateTime.now().add(
                      const Duration(seconds: 45),
                    );
                    while (context.mounted &&
                        ref.read(syncCoordinatorProvider).memos.running &&
                        DateTime.now().isBefore(deadline)) {
                      await Future<void>.delayed(
                        const Duration(milliseconds: 180),
                      );
                    }
                    if (!context.mounted) return;
                    final inFlightStatus = ref
                        .read(syncCoordinatorProvider)
                        .memos;
                    if (!inFlightStatus.running) {
                      final language = ref.read(
                        appPreferencesProvider.select((p) => p.language),
                      );
                      showSyncFeedback(
                        overlayContext: context,
                        messengerContext: context,
                        language: language,
                        succeeded: inFlightStatus.lastError == null,
                      );
                    }
                    return;
                  }
                  if (scanner != null) {
                    try {
                      await scanner.scanAndMergeIncremental(forceDisk: false);
                      _autoScanTriggered = true;
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t.strings.legacy.msg_scan_failed(e: e),
                          ),
                        ),
                      );
                    }
                  }
                  if (!context.mounted) return;
                  final syncResult = await coordinator.requestSync(
                    const SyncRequest(
                      kind: SyncRequestKind.memos,
                      reason: SyncRequestReason.manual,
                    ),
                  );
                  if (!context.mounted) return;
                  if (syncResult is SyncRunQueued) return;
                  final syncStatus = ref.read(syncCoordinatorProvider).memos;
                  if (syncStatus.running) return;
                  final language = ref.read(
                    appPreferencesProvider.select((p) => p.language),
                  );
                  showSyncFeedback(
                    overlayContext: context,
                    messengerContext: context,
                    language: language,
                    succeeded: syncStatus.lastError == null,
                  );
                  if (useShortcutFilter) {
                    ref.invalidate(shortcutMemosProvider(shortcutQuery!));
                  } else if (useQuickSearch && quickSearchQuery != null) {
                    ref.invalidate(quickSearchMemosProvider(quickSearchQuery));
                  }
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleViewportScrollNotification,
                  child: Listener(
                    onPointerSignal: _handleViewportPointerSignal,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          backgroundColor: headerBg,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          surfaceTintColor: Colors.transparent,
                          toolbarHeight:
                              viewState.layout.useWindowsDesktopHeader &&
                                  !_searching
                              ? 0
                              : kToolbarHeight,
                          titleSpacing:
                              viewState.layout.useWindowsDesktopHeader &&
                                  !_searching
                              ? 0
                              : NavigationToolbar.kMiddleSpacing,
                          automaticallyImplyLeading:
                              !viewState.layout.useWindowsDesktopHeader &&
                              !_searching,
                          leading: viewState.layout.useWindowsDesktopHeader
                              ? null
                              : (_searching
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back_ios_new,
                                        ),
                                        onPressed: _closeSearch,
                                      )
                                    : null),
                          title:
                              viewState.layout.useWindowsDesktopHeader &&
                                  !_searching
                              ? null
                              : (_searching
                                    ? _buildTopSearchField(
                                        context,
                                        isDark: isDark,
                                        autofocus: true,
                                        hasAdvancedFilters:
                                            _hasAdvancedSearchFilters,
                                        onOpenAdvancedFilters:
                                            _openAdvancedSearchSheet,
                                      )
                                    : _buildHeaderTitleWidget(
                                        context,
                                        maybeHaptic: maybeHaptic,
                                      )),
                          actions:
                              viewState.layout.useWindowsDesktopHeader &&
                                  !_searching
                              ? null
                              : [
                                  if (!_searching &&
                                      viewState.activeTagStat?.tagId != null)
                                    IconButton(
                                      tooltip:
                                          context.t.strings.legacy.msg_edit_tag,
                                      onPressed: () async {
                                        await TagEditSheet.showEditorDialog(
                                          context,
                                          tag: viewState.activeTagStat,
                                        );
                                      },
                                      icon: const Icon(Icons.edit),
                                    ),
                                  if (kDebugMode && !screenshotModeEnabled)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 150,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MemoFlowPalette.primary
                                                  .withValues(
                                                    alpha: isDark ? 0.24 : 0.12,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: MemoFlowPalette.primary
                                                    .withValues(
                                                      alpha: isDark
                                                          ? 0.45
                                                          : 0.25,
                                                    ),
                                              ),
                                            ),
                                            child: Text(
                                              debugApiVersionText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: MemoFlowPalette.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ...?_searching
                                      ? (widget.enableSearch
                                            ? [
                                                TextButton(
                                                  onPressed: _closeSearch,
                                                  child: Text(
                                                    context
                                                        .t
                                                        .strings
                                                        .legacy
                                                        .msg_cancel_2,
                                                    style: TextStyle(
                                                      color: MemoFlowPalette
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ]
                                            : null)
                                      : (widget.enableSearch
                                            ? [
                                                if (viewState
                                                    .query
                                                    .enableHomeSort)
                                                  _buildSortMenuButton(
                                                    context,
                                                    isDark: isDark,
                                                  ),
                                                if (!viewState
                                                    .layout
                                                    .useWindowsDesktopHeader)
                                                  IconButton(
                                                    tooltip: context
                                                        .t
                                                        .strings
                                                        .legacy
                                                        .msg_search,
                                                    onPressed: _openSearch,
                                                    icon: const Icon(
                                                      Icons.search,
                                                    ),
                                                  ),
                                              ]
                                            : null),
                                ],
                          bottom:
                              viewState.layout.useWindowsDesktopHeader &&
                                  !_searching
                              ? null
                              : _searching
                              ? (useShortcutFilter
                                    ? null
                                    : PreferredSize(
                                        preferredSize: const Size.fromHeight(
                                          46,
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              8,
                                            ),
                                            child:
                                                MemosListSearchQuickFilterBar(
                                                  selectedKind: viewState
                                                      .query
                                                      .selectedQuickSearchKind,
                                                  onSelectKind:
                                                      _toggleQuickSearchKind,
                                                ),
                                          ),
                                        ),
                                      ))
                              : (viewState.layout.showHeaderPillActions
                                    ? PreferredSize(
                                        preferredSize: const Size.fromHeight(
                                          46,
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              0,
                                            ),
                                            child: _buildPillActionsRow(
                                              context,
                                              maybeHaptic: maybeHaptic,
                                            ),
                                          ),
                                        ),
                                      )
                                    : (widget.showFilterTagChip &&
                                              (resolvedTag?.trim().isNotEmpty ??
                                                  false)
                                          ? PreferredSize(
                                              preferredSize:
                                                  const Size.fromHeight(48),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      0,
                                                      16,
                                                      10,
                                                    ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: MemosListFilterTagChip(
                                                    label:
                                                        '#${resolvedTag!.trim()}',
                                                    colors: tagColorLookup
                                                        .resolveChipColorsByPath(
                                                          resolvedTag.trim(),
                                                          surfaceColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surface,
                                                          isDark: isDark,
                                                        ),
                                                    onClear:
                                                        widget.showTagFilters
                                                        ? () =>
                                                              _selectTagFilter(
                                                                null,
                                                              )
                                                        : (widget.showDrawer
                                                              ? _backToAllMemos
                                                              : () => context
                                                                    .safePop()),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : null)),
                        ),
                        if (activeListGuideId != null &&
                            activeListGuideMessage != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: SceneMicroGuideBanner(
                                message: activeListGuideMessage,
                                onDismiss: () =>
                                    _markSceneGuideSeen(activeListGuideId),
                              ),
                            ),
                          ),
                        if (viewState.layout.useInlineCompose)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: MemosListInlineComposeCard(
                                composer: _inlineComposer,
                                focusNode: _inlineComposeFocusNode,
                                busy: _inlineComposeBusy,
                                locating: _inlineComposeCoordinator.locating,
                                location: _inlineComposeCoordinator.location,
                                visibility: inlineVisibility,
                                visibilityTouched:
                                    _inlineComposeCoordinator.visibilityTouched,
                                visibilityLabel: inlineVisibilityStyle.$1,
                                visibilityIcon: inlineVisibilityStyle.$2,
                                visibilityColor: inlineVisibilityStyle.$3,
                                isDark: isDark,
                                tagStats: tagStats,
                                availableTemplates:
                                    viewState.availableTemplates,
                                tagColorLookup: tagColorLookup,
                                toolbarPreferences: toolbarPreferences,
                                editorFieldKey: _inlineEditorFieldKey,
                                tagMenuKey: _inlineTagMenuKey,
                                templateMenuKey: _inlineTemplateMenuKey,
                                todoMenuKey: _inlineTodoMenuKey,
                                visibilityMenuKey: _inlineVisibilityMenuKey,
                                onSubmit: () {
                                  unawaited(_submitInlineCompose());
                                },
                                onRemoveAttachment: _inlineComposeCoordinator
                                    .removePendingAttachment,
                                onOpenAttachment: (attachment) {
                                  unawaited(
                                    _inlineComposeCoordinator
                                        .openAttachmentViewer(
                                          context,
                                          attachment,
                                        ),
                                  );
                                },
                                onRemoveLinkedMemo:
                                    _inlineComposeCoordinator.removeLinkedMemo,
                                onRequestLocation: () {
                                  unawaited(
                                    _inlineComposeCoordinator.requestLocation(
                                      context,
                                    ),
                                  );
                                },
                                onClearLocation:
                                    _inlineComposeCoordinator.clearLocation,
                                onOpenTemplateMenu: () {
                                  unawaited(
                                    _inlineComposeCoordinator
                                        .openTemplateMenuFromKey(
                                          context,
                                          _inlineTemplateMenuKey,
                                          viewState.availableTemplates,
                                        ),
                                  );
                                },
                                onPickGallery: () {
                                  unawaited(
                                    _inlineComposeCoordinator
                                        .pickGalleryAttachments(context),
                                  );
                                },
                                onPickFile: () {
                                  unawaited(
                                    _inlineComposeCoordinator.pickAttachments(
                                      context,
                                    ),
                                  );
                                },
                                onOpenLinkMemo: () {
                                  unawaited(
                                    _inlineComposeCoordinator.openLinkMemoSheet(
                                      context,
                                    ),
                                  );
                                },
                                onCaptureCamera: () {
                                  unawaited(
                                    _inlineComposeCoordinator.capturePhoto(
                                      context,
                                    ),
                                  );
                                },
                                onOpenTodoMenu: () {
                                  unawaited(
                                    _inlineComposeCoordinator
                                        .openTodoShortcutMenuFromKey(
                                          context,
                                          _inlineTodoMenuKey,
                                        ),
                                  );
                                },
                                onOpenVisibilityMenu: () {
                                  unawaited(
                                    _inlineComposeCoordinator
                                        .openVisibilityMenuFromKey(
                                          context,
                                          _inlineVisibilityMenuKey,
                                        ),
                                  );
                                },
                                onCutParagraphs: () {
                                  unawaited(_cutInlineParagraphs());
                                },
                              ),
                            ),
                          ),
                        if (widget.showTagFilters &&
                            !_searching &&
                            viewState.recommendedTags.isNotEmpty)
                          SliverToBoxAdapter(
                            child: MemosListTagFilterBar(
                              tags: viewState.recommendedTags
                                  .take(12)
                                  .map((e) => e.tag)
                                  .toList(growable: false),
                              selectedTag: resolvedTag,
                              onSelectTag: _selectTagFilter,
                              tagColors: tagColorLookup,
                            ),
                          ),
                        if (_hasAdvancedSearchFilters)
                          _buildActiveAdvancedFilterSliver(context),
                        if (memosLoading && visibleMemos.isNotEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          ),
                        if (memosError != null)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                context.t.strings.legacy.msg_failed_load_3(
                                  memosError: memosError,
                                ),
                              ),
                            ),
                          )
                        else if (viewState.query.showSearchLanding)
                          SliverToBoxAdapter(
                            child: MemosListSearchLanding(
                              history: searchHistory,
                              onClearHistory: () => ref
                                  .read(searchHistoryProvider.notifier)
                                  .clear(),
                              onRemoveHistory: (value) => ref
                                  .read(searchHistoryProvider.notifier)
                                  .remove(value),
                              onSelectHistory: _applySearchQuery,
                              tags: viewState.recommendedTags
                                  .map((e) => e.tag)
                                  .toList(growable: false),
                              tagColors: tagColorLookup,
                              onSelectTag: _applySearchQuery,
                            ),
                          )
                        else if (memosLoading && visibleMemos.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (visibleMemos.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 140),
                              child: Center(
                                child: Text(
                                  _searching
                                      ? context
                                            .t
                                            .strings
                                            .legacy
                                            .msg_no_results_found
                                      : context
                                            .t
                                            .strings
                                            .legacy
                                            .msg_no_content_yet,
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              viewState.layout.listTopPadding +
                                  viewState.layout.listVisualOffset,
                              16,
                              showLoadMoreHint ? 20 : 140,
                            ),
                            sliver: SliverAnimatedList(
                              key: _listKey,
                              initialItemCount: visibleMemos.length,
                              itemBuilder: (context, index, animation) {
                                final memo = visibleMemos[index];
                                return _buildAnimatedMemoItem(
                                  context: context,
                                  memo: memo,
                                  animation: animation,
                                  prefs: prefs,
                                  outboxStatus: outboxStatus,
                                  removing: false,
                                  tagColors: tagColorLookup,
                                );
                              },
                            ),
                          ),
                        if (showLoadMoreHint)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                140,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      loadMoreHintDisplayText,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                            color: loadMoreHintTextColor,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: MemoFloatingCollapseButton(
                  visible: _floatingCollapseMemoUid != null,
                  scrolling: _floatingCollapseScrolling,
                  label: context.t.strings.legacy.msg_collapse,
                  onPressed: _collapseActiveMemoFromFloatingButton,
                  padding: EdgeInsets.only(
                    top: viewState.layout.floatingCollapseTopPadding,
                    right: 16,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: viewState.layout.backToTopBaseOffset + bottomInset,
                child: BackToTopButton(
                  visible: _showBackToTop,
                  hapticsEnabled: hapticsEnabled,
                  onPressed: _handleScrollToTop,
                ),
              ),
              if (_bootstrapImportActive)
                Positioned.fill(
                  child: _buildBootstrapImportOverlay(
                    context,
                    isDark: isDark,
                    importedCount: bootstrapImportedCount,
                    totalCount: _bootstrapImportTotal,
                    elapsed: bootstrapElapsed,
                  ),
                ),
            ],
          );
          final bodyContent = () {
            if (!viewState.layout.useDesktopSidePane || drawerPanel == null) {
              return memoListBody;
            }
            final dividerColor = isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08);
            final desktopContent = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kMemoFlowDesktopContentMaxWidth,
                  ),
                  child: memoListBody,
                ),
              ),
            );
            return Row(
              children: [
                SizedBox(
                  width: kMemoFlowDesktopDrawerWidth,
                  child: drawerPanel,
                ),
                VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                Expanded(child: desktopContent),
              ],
            );
          }();
          if (viewState.layout.useWindowsDesktopHeader && !_searching) {
            return Column(
              children: [
                _buildWindowsDesktopTitleBar(
                  context,
                  isDark: isDark,
                  enableHomeSort: viewState.query.enableHomeSort,
                  showPillActions: viewState.layout.showHeaderPillActions,
                  maybeHaptic: maybeHaptic,
                  screenshotModeEnabled: screenshotModeEnabled,
                  debugApiVersionText: debugApiVersionText,
                ),
                Expanded(child: bodyContent),
              ],
            );
          }
          return bodyContent;
        })(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: viewState.layout.showComposeFab
            ? MemoFlowFab(
                onPressed: _openNoteInput,
                onLongPressStart: _handleVoiceFabLongPressStart,
                onLongPressMoveUpdate: _handleVoiceFabLongPressMoveUpdate,
                onLongPressEnd: _handleVoiceFabLongPressEnd,
                hapticsEnabled: hapticsEnabled,
              )
            : null,
      ),
    );
  }
}

class _ScreenViewportScrollAdapter implements MemosListViewportScrollAdapter {
  const _ScreenViewportScrollAdapter(this._controller);

  final ScrollController _controller;

  @override
  bool get hasClients => _controller.hasClients;

  @override
  MemosListViewportMetrics get metrics {
    final position = _controller.position;
    return MemosListViewportMetrics(
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
      viewportDimension: position.viewportDimension,
      axis: position.axis,
    );
  }

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) {
    return _controller.animateTo(offset, duration: duration, curve: curve);
  }

  @override
  void jumpTo(double offset) {
    _controller.jumpTo(offset);
  }
}
