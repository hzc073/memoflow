import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../application/desktop/desktop_resizable_panel_shell.dart';
import '../../application/desktop/desktop_quick_record_hotkey_state.dart';
import '../../application/sync/sync_feedback_presenter.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_motion.dart';
import '../../core/app_localization.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/drawer_navigation.dart';
import '../../core/log_sanitizer.dart';
import '../../core/memo_content_diagnostics.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/top_toast.dart';
import '../../data/ai/ai_semantic_memo_search_service.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/compose_draft.dart';
import '../../data/models/device_preferences.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_toolbar_preferences.dart';
import '../../data/models/shortcut.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../platform/platform_route.dart';
import '../../platform/platform_target.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/desktop_home_pane_state.dart';
import '../../state/memos/desktop_memo_preview_session.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/memos/note_draft_provider.dart';
import '../../state/memos/search_history_provider.dart';
import '../../state/settings/app_lock_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/settings/resolved_preferences_provider.dart';
import '../../state/settings/user_settings_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/system/debug_screenshot_mode_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/local_library_scanner.dart';
import '../collections/add_to_collection_sheet.dart';
import '../collections/collections_screen.dart';
import '../../state/system/logging_provider.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import '../../state/system/session_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../home/desktop_home_inline_compose_resize_capability.dart';
import '../home/home_navigation_host.dart';
import '../notifications/notifications_screen.dart';
import '../reminders/memo_reminder_editor_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../tags/tag_edit_sheet.dart';
import '../voice/voice_record_screen.dart';
import 'advanced_search_sheet.dart';
import 'android_memo_keyboard_resume_controller.dart';
import 'draft_box_screen.dart';
import 'memo_detail_screen.dart';
import 'memo_editor_screen.dart';
import 'memo_hero_flight.dart';
import 'memo_markdown.dart';
import 'memo_time_adjustment_sheet.dart';
import 'memo_versions_screen.dart';
import 'memos_list_animated_list_controller.dart';
import 'memos_list_audio_playback_coordinator.dart';
import 'memos_list_desktop_shortcut_delegate.dart';
import 'memos_list_diagnostics.dart';
import 'memos_list_floating_collapse_controller.dart';
import 'memos_list_header_controller.dart';
import 'home_quick_actions.dart';
import 'memos_list_inline_compose_coordinator.dart';
import 'memos_list_inline_compose_ui_controller.dart';
import 'memos_list_local_library_coordinator.dart';
import 'memos_list_memo_action_delegate.dart';
import 'memos_list_mutation_coordinator.dart';
import 'memos_list_desktop_presentation.dart';
import 'memos_list_route_delegate.dart';
import 'memos_list_screen_view_state.dart';
import 'memos_list_viewport_coordinator.dart';
import 'widgets/memos_list_animated_memo_item.dart';
import 'widgets/memos_list_bootstrap_import_overlay.dart';
import 'widgets/memos_list_desktop_preview_pane.dart';
import 'widgets/memos_list_floating_actions.dart';
import 'widgets/memos_list_inline_compose_card.dart';
import 'widgets/memos_list_memo_card.dart';
import 'widgets/memos_list_screen_body.dart';
import 'widgets/memos_list_search_header.dart';
import 'widgets/memos_list_search_widgets.dart';
import '../../i18n/strings.g.dart';

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
    this.showNoteInputSheet,
    this.showVoiceRecordOverlay,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
    this.hidePrimaryComposeFab = false,
    this.enableDesktopResizableHomeInlineCompose = false,
    this.enableDrawerOpenDragGesture = true,
    this.initialDesktopUtilityView = DesktopHomeUtilityView.none,
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
  final MemosListRouteNoteInputPresenter? showNoteInputSheet;
  final MemosListRouteVoiceRecordOverlayPresenter? showVoiceRecordOverlay;
  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;
  final bool hidePrimaryComposeFab;
  final bool enableDesktopResizableHomeInlineCompose;
  final bool enableDrawerOpenDragGesture;
  final DesktopHomeUtilityView initialDesktopUtilityView;

  @override
  ConsumerState<MemosListScreen> createState() => _MemosListScreenState();
}

class _MemosListScreenState extends ConsumerState<MemosListScreen>
    with WindowListener {
  static const int _initialPageSize = 200;
  static const int _pageStep = 200;
  static const double _homeInlineComposeHitZoneExtent = 12;
  static const double _homeInlineComposeViewportMargin = 20;
  static const double _homeInlineComposeMinWidth = 420;
  static const double _homeInlineComposeDefaultWidth = 620;
  static const double _homeInlineComposeMinEditorHeight = 96;
  static const double _homeInlineComposeMaxEditorHeight = 420;

  final DateFormat _dayDateFmt = DateFormat('yyyy-MM-dd');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _floatingCollapseViewportKey = GlobalKey();
  final GlobalKey _homeInlineComposeCardKey = GlobalKey();
  final FocusNode _inlineComposeFocusNode = FocusNode();
  late final AndroidMemoKeyboardResumeController
  _inlineComposeKeyboardResumeController;
  final GlobalKey _inlineEditorFieldKey = GlobalKey();
  final GlobalKey _inlineTagMenuKey = GlobalKey();
  final GlobalKey _inlineTemplateMenuKey = GlobalKey();
  final GlobalKey _inlineTodoMenuKey = GlobalKey();
  final GlobalKey _inlineVisibilityMenuKey = GlobalKey();

  late final MemoComposerController _inlineComposer;
  late final MemosListAudioPlaybackCoordinator _audioPlaybackCoordinator;
  late final MemosListDesktopShortcutDelegate _desktopShortcutDelegate;
  late final MemosListHeaderController _headerController;
  late final MemosListInlineComposeCoordinator _inlineComposeCoordinator;
  late final MemosListInlineComposeUiController _inlineComposeUiController;
  late final MemosListLocalLibraryCoordinator _localLibraryCoordinator;
  late final MemosListMutationCoordinator _mutationCoordinator;
  late final MemosListViewportCoordinator _viewportCoordinator;
  late final MemosListFloatingCollapseController _floatingCollapseController;
  late final MemosListRouteDelegate _routeDelegate;
  late final MemosListMemoActionDelegate _memoActionDelegate;
  late final MemosListAnimatedListController _animatedListController;
  late final MemosListDiagnostics _diagnostics;
  late final LogManager _logManager;

  Timer? _inlineComposeDraftTimer;
  String? _inlineComposeActiveDraftId;
  bool _suppressInlineComposeDraftSave = false;
  SceneMicroGuideId? _presentedListGuideId;
  bool _openedDrawerOnStart = false;
  VoiceRecordOverlayDragSession? _voiceOverlayDragSession;
  Future<void>? _voiceOverlayDragFuture;
  ComposeDraftRepository? _composeDraftRepository;
  NoteDraftController? _noteDraftController;
  NoteDraftRepository? _noteDraftRepository;
  String _inlineComposeDefaultVisibility = 'PRIVATE';
  double? _homeInlinePanelWidth;
  double? _homeInlinePanelEditorHeight;
  double _homeInlinePanelXRatio = 0;
  double _homeInlinePanelYRatio = 0;
  double _homeInlinePanelChromeHeight = 0;
  double _homeInlineAvailableHeight = 0;
  bool _homeInlinePanelMetricsReady = false;
  bool _homeInlinePanelRestored = false;
  bool _viewportDerivedMetricsSyncScheduled = false;
  int _previewTransitionKey = 0;
  int _composeTransitionKey = 0;
  Timer? _desktopPreviewPressTimer;
  int _desktopPreviewPressSequence = 0;
  int? _activeDesktopPreviewPressSequence;
  LocalMemo? _desktopPreviewPressMemo;
  DesktopHomePaneState? _desktopPreviewRollbackPaneState;
  bool? _desktopPreviewRollbackSecondaryPaneVisible;
  bool _desktopPreviewPressOpened = false;
  bool _desktopPreviewPressShouldDeselect = false;
  int _ignoredDesktopPreviewTapCount = 0;
  bool _inlineComposeKeyboardResumeVisible = false;
  String? _desktopComposeInitialText;
  List<String> _desktopComposeInitialAttachmentPaths = const <String>[];
  bool _desktopComposeIgnoreDraft = false;
  String _floatingCollapseVisibleMemoSignature = '';
  late DesktopHomeUtilityView _desktopHomeUtilityView;
  Timer? _scrollPerfIdleTimer;
  _MemosScrollPerfSession? _scrollPerfSession;
  late final VoidCallback _audioPlaybackCoordinatorListener;
  late final VoidCallback _mutationCoordinatorListener;
  late final VoidCallback _viewportCoordinatorListener;
  late final VoidCallback _headerControllerListener;
  late final VoidCallback _inlineComposeUiControllerListener;
  late final VoidCallback _localLibraryCoordinatorListener;
  late final VoidCallback _routeDelegateListener;
  late final VoidCallback _animatedListControllerListener;
  late final VoidCallback _showBackToTopDiagnosticsListener;
  late final VoidCallback _floatingCollapseDiagnosticsListener;
  late final TimingsCallback _frameTimingsCallback;
  bool _lastShowBackToTopDiagnosticsValue = false;
  MemosListFloatingCollapseState _lastFloatingCollapseDiagnosticsState =
      const MemosListFloatingCollapseState(memoUid: null, scrolling: false);

  @visibleForTesting
  MemosListFloatingCollapseController get debugFloatingCollapseController =>
      _floatingCollapseController;

  @visibleForTesting
  MemoComposerController get debugInlineComposer => _inlineComposer;

  @visibleForTesting
  TextEditingController get debugSearchController => _searchController;

  @visibleForTesting
  bool get debugAiSearchActive => _aiSearchActive;

  @visibleForTesting
  void debugStartAiSearch() => _startAiSearch();

  @visibleForTesting
  MemosListScreenLayoutState debugBuildCurrentLayoutState() {
    final mediaQuery = MediaQuery.of(context);
    final queryState = buildMemosListScreenQueryState(
      searchQuery: _searchController.text,
      filterDay: widget.dayFilter,
      state: widget.state,
      pageSize: _pageSize,
      shortcuts: const <Shortcut>[],
      selectedShortcutId: _selectedShortcutId,
      selectedQuickSearchKind: _selectedQuickSearchKind,
      aiSearchActive: _aiSearchActive,
      resolvedTag: _activeTagFilter,
      advancedFilters: _advancedSearchFilters,
      sortOrder: _headerController.querySortOrder,
      searching: _searching,
      showDrawer: widget.showDrawer,
    );
    return buildMemosListScreenLayoutState(
      query: queryState,
      desktopPresentation: _resolveCurrentMemosListDesktopPresentation(
        screenWidth: mediaQuery.size.width,
      ),
      state: widget.state,
      showDrawer: widget.showDrawer,
      showPillActions: widget.showPillActions,
      showFilterTagChip: widget.showFilterTagChip,
      enableCompose: widget.enableCompose,
      hidePrimaryComposeFab: widget.hidePrimaryComposeFab,
      searching: _searching,
    );
  }

  TextEditingController get _searchController =>
      _headerController.searchController;
  FocusNode get _searchFocusNode => _headerController.searchFocusNode;
  bool get _searching => _headerController.searching;
  String? get _selectedShortcutId => _headerController.selectedShortcutId;
  QuickSearchKind? get _selectedQuickSearchKind =>
      _headerController.selectedQuickSearchKind;
  bool get _aiSearchActive => _headerController.aiSearchActive;
  AdvancedSearchFilters get _advancedSearchFilters =>
      _headerController.advancedSearchFilters;
  String? get _activeTagFilter => _headerController.activeTagFilter;
  bool get _hasAdvancedSearchFilters =>
      _headerController.hasAdvancedSearchFilters;
  bool get _desktopHeaderSearchExpanded =>
      _headerController.desktopHeaderSearchExpanded;
  MemosListSortOption get _sortOption => _headerController.sortOption;
  bool get _inlineComposeBusy => _mutationCoordinator.inlineComposeSubmitting;
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
  bool get _scrollToTopAnimating => _viewportCoordinator.scrollToTopAnimating;
  GlobalKey<SliverAnimatedListState> get _listKey =>
      _animatedListController.listKey;
  List<LocalMemo> get _animatedMemos => _animatedListController.animatedMemos;
  bool get _desktopWindowMaximized => _routeDelegate.desktopWindowMaximized;

  bool get _isAllMemos {
    final tag = _activeTagFilter;
    return widget.state == 'NORMAL' && (tag == null || tag.isEmpty);
  }

  bool get _enableScrollPerfDiagnostics =>
      !kReleaseMode &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows;

  bool get _enableResizableHomeInlineCompose =>
      shouldEnableDesktopHomeInlineComposeResizeForMemosList(
        platform: Theme.of(context).platform,
        presentation: widget.presentation,
        navigationHost: widget.embeddedNavigationHost,
        explicitlyEnabled: widget.enableDesktopResizableHomeInlineCompose,
        showDrawer: widget.showDrawer,
        enableCompose: widget.enableCompose,
        state: widget.state,
        tag: widget.tag,
        dayFilter: widget.dayFilter,
      );

  bool get _isDesktopContextMenuTarget =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  DesktopHomeLayoutPreference get _desktopHomeLayoutPreference =>
      ref.read(devicePreferencesProvider).desktopHomeLayoutPreference;

  void _persistDesktopHomeLayoutPreference(DesktopHomeLayoutPreference value) {
    ref
        .read(devicePreferencesProvider.notifier)
        .setDesktopHomeLayoutPreference(value);
  }

  void _setDesktopPreviewPaneVisiblePreference(bool visible) {
    final current = _desktopHomeLayoutPreference;
    if (current.secondaryPaneVisible == visible) return;
    _persistDesktopHomeLayoutPreference(
      DesktopHomeLayoutPreference(
        navMode: current.navMode,
        secondaryPaneVisible: visible,
        secondaryPaneWidth: current.secondaryPaneWidth,
      ),
    );
  }

  void _setDesktopPreviewPaneWidthPreference(double width) {
    final resolvedWidth = width
        .clamp(
          kWindowsDesktopSecondaryPaneMinWidth,
          kWindowsDesktopSecondaryPaneMaxWidth,
        )
        .toDouble();
    final current = _desktopHomeLayoutPreference;
    if ((current.secondaryPaneWidth - resolvedWidth).abs() < 0.5) return;
    _persistDesktopHomeLayoutPreference(
      DesktopHomeLayoutPreference(
        navMode: current.navMode,
        secondaryPaneVisible: current.secondaryPaneVisible,
        secondaryPaneWidth: resolvedWidth,
      ),
    );
  }

  MemosListDesktopPresentation _resolveCurrentMemosListDesktopPresentation({
    double? screenWidth,
  }) {
    final width = screenWidth ?? MediaQuery.maybeOf(context)?.size.width ?? 0;
    return resolveMemosListDesktopPresentation(
      screenWidth: width,
      showDrawer: widget.showDrawer,
      platform: defaultTargetPlatform,
    );
  }

  DesktopLayoutSpec _resolveCurrentDesktopLayout() {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 0;
    return resolveDesktopLayoutPolicy(width, platform: defaultTargetPlatform);
  }

  void _resetDesktopComposeSeed() {
    _desktopComposeInitialText = null;
    _desktopComposeInitialAttachmentPaths = const <String>[];
    _desktopComposeIgnoreDraft = false;
  }

  LocalMemo? _findMemoByUid(List<LocalMemo> memos, String? memoUid) {
    final selectedUid = memoUid?.trim() ?? '';
    if (selectedUid.isEmpty) return null;
    for (final memo in memos) {
      if (memo.uid == selectedUid) {
        return memo;
      }
    }
    return null;
  }

  bool _isTextInputFocused() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedWidget = focusedContext?.widget;
    return focusedWidget is EditableText;
  }

  bool _isTextEditingKeyboardOwnerActive() {
    return _inlineComposeFocusNode.hasFocus || _isTextInputFocused();
  }

  void _selectDesktopMemo(LocalMemo memo, {required bool showPreview}) {
    final memoUid = memo.uid.trim();
    if (memoUid.isEmpty) return;
    final paneState = ref.read(desktopHomePaneStateProvider);
    if (paneState.selectedMemoUid != memoUid) {
      _setStateWithDiagnostics(
        'desktop_preview_transition',
        () => _previewTransitionKey += 1,
      );
    }
    final controller = ref.read(desktopHomePaneStateProvider.notifier);
    if (showPreview) {
      controller.showPreview(memoUid);
      _setDesktopPreviewPaneVisiblePreference(true);
      return;
    }
    controller.selectMemo(memoUid);
  }

  void _deselectDesktopMemo({bool persistHidden = true}) {
    final paneState = ref.read(desktopHomePaneStateProvider);
    if (!paneState.hasSelection &&
        paneState.secondaryPaneMode == DesktopHomeSecondaryPaneMode.none) {
      return;
    }
    _setStateWithDiagnostics(
      'desktop_preview_transition',
      () => _previewTransitionKey += 1,
    );
    ref.read(desktopHomePaneStateProvider.notifier).deselectMemo();
    if (persistHidden) {
      _setDesktopPreviewPaneVisiblePreference(false);
    }
  }

  void _openDesktopPreview(LocalMemo memo, {bool requestMemo = true}) {
    if (kDebugMode) {
      final paneState = ref.read(desktopHomePaneStateProvider);
      _logManager.info(
        'Desktop preview: open_request',
        context: <String, Object?>{
          ...buildMemoContentDiagnostics(memo.content, memoUid: memo.uid),
          'previewVisible': paneState.previewVisible,
          'secondaryPaneMode': paneState.secondaryPaneMode.name,
          'alreadySelected': paneState.selectedMemoUid == memo.uid,
          'transitionKey': _previewTransitionKey,
        },
      );
    }
    _selectDesktopMemo(memo, showPreview: true);
    if (!requestMemo) {
      return;
    }
    unawaited(
      ref.read(desktopMemoPreviewSessionProvider.notifier).requestMemo(memo),
    );
  }

  Duration _desktopPreviewPressThresholdDuration() {
    if (!AppMotion.isEnabled(context)) {
      return Duration.zero;
    }
    return AppMotion.desktopPressDown;
  }

  bool _isSameDesktopPreviewPressMemo(LocalMemo memo, LocalMemo? other) {
    final memoUid = memo.uid.trim();
    final otherUid = other?.uid.trim() ?? '';
    return memoUid.isNotEmpty && memoUid == otherUid;
  }

  bool _matchesDesktopPreviewPressSequence(int sequence, LocalMemo memo) {
    return mounted &&
        _activeDesktopPreviewPressSequence == sequence &&
        _isSameDesktopPreviewPressMemo(memo, _desktopPreviewPressMemo);
  }

  void _clearDesktopPreviewPressState({bool resetTapIgnore = false}) {
    _desktopPreviewPressTimer?.cancel();
    _desktopPreviewPressTimer = null;
    _activeDesktopPreviewPressSequence = null;
    _desktopPreviewPressMemo = null;
    _desktopPreviewRollbackPaneState = null;
    _desktopPreviewRollbackSecondaryPaneVisible = null;
    _desktopPreviewPressOpened = false;
    _desktopPreviewPressShouldDeselect = false;
    if (resetTapIgnore) {
      _ignoredDesktopPreviewTapCount = 0;
    }
  }

  void _restoreDesktopPreviewPaneState(
    DesktopHomePaneState paneState, {
    required bool secondaryPaneVisible,
  }) {
    ref.read(desktopHomePaneStateProvider.notifier).restore(paneState);
    _setDesktopPreviewPaneVisiblePreference(secondaryPaneVisible);
  }

  void _cancelPendingDesktopPreviewPress({required bool rollbackIfOpened}) {
    final rollbackPaneState = _desktopPreviewRollbackPaneState;
    final rollbackSecondaryPaneVisible =
        _desktopPreviewRollbackSecondaryPaneVisible;
    final shouldRollback =
        rollbackIfOpened &&
        _desktopPreviewPressOpened &&
        rollbackPaneState != null &&
        rollbackSecondaryPaneVisible != null;
    if (shouldRollback) {
      _restoreDesktopPreviewPaneState(
        rollbackPaneState,
        secondaryPaneVisible: rollbackSecondaryPaneVisible,
      );
    }
    _clearDesktopPreviewPressState();
  }

  void _handleDesktopPreviewTapDown(LocalMemo memo) {
    final memoUid = memo.uid.trim();
    if (memoUid.isEmpty) return;
    _cancelPendingDesktopPreviewPress(rollbackIfOpened: true);
    final sequence = ++_desktopPreviewPressSequence;
    _activeDesktopPreviewPressSequence = sequence;
    _desktopPreviewPressMemo = memo;
    _desktopPreviewRollbackPaneState = ref.read(desktopHomePaneStateProvider);
    _desktopPreviewRollbackSecondaryPaneVisible =
        _desktopHomeLayoutPreference.secondaryPaneVisible;
    _desktopPreviewPressOpened = false;
    _desktopPreviewPressShouldDeselect =
        _desktopPreviewRollbackPaneState?.selectedMemoUid == memoUid;
    if (_desktopPreviewPressShouldDeselect) {
      return;
    }
    unawaited(
      ref.read(desktopMemoPreviewSessionProvider.notifier).requestMemo(memo),
    );
    final threshold = _desktopPreviewPressThresholdDuration();
    if (threshold <= Duration.zero) {
      if (_matchesDesktopPreviewPressSequence(sequence, memo)) {
        _desktopPreviewPressOpened = true;
        _openDesktopPreview(memo, requestMemo: false);
      }
      return;
    }
    _desktopPreviewPressTimer = Timer(threshold, () {
      _desktopPreviewPressTimer = null;
      if (!_matchesDesktopPreviewPressSequence(sequence, memo)) {
        return;
      }
      _desktopPreviewPressOpened = true;
      _openDesktopPreview(memo, requestMemo: false);
    });
  }

  void _handleDesktopPreviewTapUp(LocalMemo memo) {
    if (!_isSameDesktopPreviewPressMemo(memo, _desktopPreviewPressMemo)) {
      return;
    }
    _ignoredDesktopPreviewTapCount += 1;
    _desktopPreviewPressTimer?.cancel();
    _desktopPreviewPressTimer = null;
    if (_desktopPreviewPressShouldDeselect) {
      _deselectDesktopMemo();
      _clearDesktopPreviewPressState(resetTapIgnore: false);
      return;
    }
    if (!_desktopPreviewPressOpened) {
      _desktopPreviewPressOpened = true;
      _openDesktopPreview(memo, requestMemo: false);
    }
    _clearDesktopPreviewPressState(resetTapIgnore: false);
  }

  void _handleDesktopPreviewTapCancel() {
    _cancelPendingDesktopPreviewPress(rollbackIfOpened: true);
  }

  void _handleDesktopPreviewTap(LocalMemo memo) {
    if (_ignoredDesktopPreviewTapCount > 0) {
      _ignoredDesktopPreviewTapCount -= 1;
      return;
    }
    _cancelPendingDesktopPreviewPress(rollbackIfOpened: true);
    _openDesktopPreview(memo);
  }

  void _openDesktopPreviewPane() {
    final paneState = ref.read(desktopHomePaneStateProvider);
    ref
        .read(desktopHomePaneStateProvider.notifier)
        .openPreviewPane(selectedMemoUid: paneState.selectedMemoUid);
    _setDesktopPreviewPaneVisiblePreference(true);
  }

  void _closeDesktopPreview({bool persistHidden = true}) {
    final paneState = ref.read(desktopHomePaneStateProvider);
    if (!paneState.hasSelection &&
        paneState.secondaryPaneMode == DesktopHomeSecondaryPaneMode.none) {
      return;
    }
    _deselectDesktopMemo(persistHidden: persistHidden);
  }

  void _openDesktopComposeNew({
    String? initialText,
    List<String> initialAttachmentPaths = const <String>[],
    bool ignoreDraft = false,
  }) {
    final paneState = ref.read(desktopHomePaneStateProvider);
    _setStateWithDiagnostics('desktop_compose_new', () {
      _composeTransitionKey += 1;
      _desktopComposeInitialText = initialText;
      _desktopComposeInitialAttachmentPaths = List<String>.from(
        initialAttachmentPaths,
      );
      _desktopComposeIgnoreDraft = ignoreDraft;
    });
    ref
        .read(desktopHomePaneStateProvider.notifier)
        .showComposeNew(selectedMemoUid: paneState.selectedMemoUid);
  }

  void _openDesktopComposeEdit(LocalMemo memo) {
    _setStateWithDiagnostics('desktop_compose_edit', () {
      _composeTransitionKey += 1;
      _resetDesktopComposeSeed();
    });
    ref.read(desktopHomePaneStateProvider.notifier).showComposeEdit(memo.uid);
  }

  void _closeDesktopCompose() {
    _setStateWithDiagnostics('desktop_compose_close', () {
      _resetDesktopComposeSeed();
    });
    ref.read(desktopHomePaneStateProvider.notifier).closeCompose();
  }

  void _toggleDesktopComposeFullscreen() {
    final controller = ref.read(desktopHomePaneStateProvider.notifier);
    final paneState = ref.read(desktopHomePaneStateProvider);
    if (!paneState.editorVisible) return;
    if (paneState.isEditorFullscreen) {
      controller.restoreComposeToCentered();
      return;
    }
    controller.expandComposeToFullscreen();
  }

  void _handleDesktopComposeSaved() {
    final paneState = ref.read(desktopHomePaneStateProvider);
    final selectedMemoUid = paneState.selectedMemoUid;
    final isEdit = paneState.composeDraftTarget is DesktopHomeComposeEditMemo;
    _setStateWithDiagnostics('desktop_compose_saved', () {
      _resetDesktopComposeSeed();
      if (isEdit) {
        _previewTransitionKey += 1;
      }
    });
    ref.read(desktopHomePaneStateProvider.notifier).closeCompose();
    if (isEdit && selectedMemoUid != null && selectedMemoUid.isNotEmpty) {
      ref.invalidate(memoRelationsProvider(selectedMemoUid));
    }
  }

  Future<void> _showDesktopComposeDialog({
    LocalMemo? existing,
    String? initialText,
    List<String> initialAttachmentPaths = const <String>[],
    bool ignoreDraft = false,
    bool fullscreen = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final editor = MemoEditorScreen(
          existing: existing,
          initialText: initialText,
          initialAttachmentPaths: initialAttachmentPaths,
          ignoreDraft: ignoreDraft,
          onSaved: () => Navigator.of(dialogContext).pop(),
          onCloseRequested: () => Navigator.of(dialogContext).pop(),
        );
        if (fullscreen) {
          return Dialog.fullscreen(child: editor);
        }
        return Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 920,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
            ),
            child: editor,
          ),
        );
      },
    );
  }

  Future<void> _showDesktopComposeSurface(
    BuildContext _, {
    String? initialText,
    List<String> initialAttachmentPaths = const <String>[],
    bool ignoreDraft = false,
  }) async {
    final layoutSpec = _resolveCurrentDesktopLayout();
    if (layoutSpec.tier != DesktopLayoutTier.narrow) {
      _openDesktopComposeNew(
        initialText: initialText,
        initialAttachmentPaths: initialAttachmentPaths,
        ignoreDraft: ignoreDraft,
      );
      return;
    }
    await _showDesktopComposeDialog(
      initialText: initialText,
      initialAttachmentPaths: initialAttachmentPaths,
      ignoreDraft: ignoreDraft,
      fullscreen: layoutSpec.tier == DesktopLayoutTier.narrow,
    );
  }

  void _clearDesktopPaneSelection() {
    final paneState = ref.read(desktopHomePaneStateProvider);
    if (!paneState.hasSelection &&
        paneState.secondaryPaneMode == DesktopHomeSecondaryPaneMode.none &&
        !paneState.editorVisible) {
      return;
    }
    ref.read(desktopHomePaneStateProvider.notifier).clear();
  }

  void _toggleDesktopSecondaryPane() {
    final layoutSpec = _resolveCurrentDesktopLayout();
    if (!layoutSpec.supportsSecondaryPane) return;
    final paneState = ref.read(desktopHomePaneStateProvider);
    if (paneState.previewVisible) {
      _closeDesktopPreview();
      return;
    }
    _openDesktopPreviewPane();
  }

  Future<void> _copyMemoContent(LocalMemo memo) async {
    if (ref.read(devicePreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    await Clipboard.setData(ClipboardData(text: memo.content));
    if (!mounted) return;
    showTopToast(
      context,
      context.t.strings.legacy.msg_memo_copied,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _showMemoContextMenu(
    LocalMemo memo,
    Offset globalPosition, {
    required bool showPreviewOnSelect,
  }) async {
    _selectDesktopMemo(memo, showPreview: showPreviewOnSelect);
    final action = await showMemoCardContextMenu(
      context: context,
      memo: memo,
      globalPosition: globalPosition,
    );
    if (!mounted || action == null) return;
    await _memoActionDelegate.handleMemoAction(memo, action);
  }

  void _syncDesktopPreviewSelection({
    required MemosListScreenLayoutState layout,
    required List<LocalMemo> visibleMemos,
  }) {
    final paneState = ref.read(desktopHomePaneStateProvider);
    if (paneState.editorVisible) {
      return;
    }
    final previewEnabled = layout.supportsDesktopPreviewPane;
    if (!previewEnabled) {
      if (paneState.hasSelection ||
          paneState.secondaryPaneMode != DesktopHomeSecondaryPaneMode.none) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _clearDesktopPaneSelection();
        });
      }
      return;
    }

    final selectedUid = paneState.selectedMemoUid;
    if (selectedUid == null || selectedUid.isEmpty) return;
    final stillVisible = visibleMemos.any((memo) => memo.uid == selectedUid);
    if (stillVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clearDesktopPaneSelection();
    });
  }

  void _openMemoDetailRoute(LocalMemo memo, {Object? heroTag}) {
    Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoDetailScreen(
          initialMemo: memo,
          heroTag: heroTag,
          onRequestEditExisting: (detailMemo) async {
            final shouldReturnToPreviewAfterEdit =
                _resolveCurrentMemosListDesktopPresentation()
                    .previewPanePolicy
                    .defaultMemoClickOpensPreview;
            await _openMemoEditor(detailMemo);
            if (shouldReturnToPreviewAfterEdit && mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  double _effectiveHomeInlineAvailableHeight(BuildContext context) {
    if (_homeInlineAvailableHeight > 0) {
      return _homeInlineAvailableHeight;
    }
    return math.max(320, MediaQuery.sizeOf(context).height - 240);
  }

  double _resolveHomeInlineMaxWidth(double availableWidth) {
    if (availableWidth <= 0) return 0;
    return math.max(0, availableWidth - _homeInlineComposeViewportMargin * 2);
  }

  double _resolveHomeInlineMaxEditorHeight(double availableHeight) {
    if (availableHeight <= 0) return 0;
    return math.min(_homeInlineComposeMaxEditorHeight, availableHeight * 0.5);
  }

  double _estimateHomeInlinePanelChromeHeight(
    MemoToolbarPreferences toolbarPreferences,
  ) {
    final topActions = toolbarPreferences.visibleItemIdsForRow(
      MemoToolbarRow.top,
    );
    final bottomActions = toolbarPreferences.visibleItemIdsForRow(
      MemoToolbarRow.bottom,
    );
    var toolbarActionsHeight = 0.0;
    if (topActions.isNotEmpty) {
      toolbarActionsHeight += 32;
    }
    if (topActions.isNotEmpty && bottomActions.isNotEmpty) {
      toolbarActionsHeight += 6;
    }
    if (bottomActions.isNotEmpty) {
      toolbarActionsHeight += 32;
    }
    if (toolbarActionsHeight > 0) {
      toolbarActionsHeight += 4;
    }
    final toolbarHeight = math.max(30.0, toolbarActionsHeight);
    return 12 + 10 + 10 + toolbarHeight + 4;
  }

  double _clampRatio(double value) => value.clamp(0, 1).toDouble();

  double _offsetFromRatio(double ratio, double freeSpace) {
    if (freeSpace <= 0) return 0;
    return _clampRatio(ratio) * freeSpace;
  }

  double _ratioFromOffset(double offset, double freeSpace) {
    if (freeSpace <= 0) return 0;
    return _clampRatio(offset / freeSpace);
  }

  double _resolveHomeInlineHorizontalFreeWidth(
    double availableWidth,
    double panelWidth,
  ) {
    return math
        .max(
          0,
          availableWidth - panelWidth - _homeInlineComposeViewportMargin * 2,
        )
        .toDouble();
  }

  void _syncHomeInlineAvailableHeight() {
    final size = _floatingCollapseViewportKey.currentContext?.size;
    final next = size?.height ?? 0;
    if (!mounted || next <= 0) return;
    if ((_homeInlineAvailableHeight - next).abs() < 0.5) return;
    _setStateWithDiagnostics(
      'home_inline_available_height',
      () => _homeInlineAvailableHeight = next,
    );
  }

  void _scheduleViewportDerivedMetricsSync() {
    if (_viewportDerivedMetricsSyncScheduled) return;
    _viewportDerivedMetricsSyncScheduled = true;
    _recordScrollPerfViewportDerivedMetricsSyncScheduled();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportDerivedMetricsSyncScheduled = false;
      if (!mounted) return;
      _recordScrollPerfViewportDerivedMetricsSyncApplied();
      _syncHomeInlineAvailableHeight();
      final metrics = _currentViewportMetrics();
      if (metrics != null) {
        _floatingCollapseController.updateViewportMetrics(metrics);
      }
    });
  }

  void _scheduleFloatingCollapseVisibleMemoPrune(List<LocalMemo> visibleMemos) {
    final nextSignature = visibleMemos.map((memo) => memo.uid).join('|');
    if (nextSignature == _floatingCollapseVisibleMemoSignature) return;
    _floatingCollapseVisibleMemoSignature = nextSignature;
    final visibleUids = visibleMemos.map((memo) => memo.uid).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _floatingCollapseController.pruneToVisibleMemoUids(visibleUids);
    });
  }

  void _handleHomeInlineLayoutMetrics(InlineComposeLayoutMetrics metrics) {
    final chromeHeight = math.max(0, metrics.chromeHeight).toDouble();
    final nextEditorHeight =
        _homeInlinePanelEditorHeight ?? metrics.editorViewportHeight;
    if ((_homeInlinePanelChromeHeight - chromeHeight).abs() < 0.5 &&
        ((_homeInlinePanelEditorHeight ?? -1) - nextEditorHeight).abs() < 0.5 &&
        _homeInlinePanelMetricsReady) {
      return;
    }
    _setStateWithDiagnostics('home_inline_layout_metrics', () {
      _homeInlinePanelChromeHeight = chromeHeight;
      _homeInlinePanelEditorHeight = nextEditorHeight;
      _homeInlinePanelMetricsReady = true;
    });
  }

  HomeInlineComposePanelLayoutPreference? _readHomeInlinePanelSavedLayout() {
    return ref.read(
      devicePreferencesProvider.select(
        (value) => value.homeInlineComposePanelLayout,
      ),
    );
  }

  void _setHomeInlinePanelLayoutFromPreference({
    required HomeInlineComposePanelLayoutPreference? saved,
    required double availableWidth,
    required double availableHeight,
    required double chromeHeight,
    required bool resetUnavailableAxes,
  }) {
    final maxWidth = _resolveHomeInlineMaxWidth(availableWidth);
    final maxEditorHeight = _resolveHomeInlineMaxEditorHeight(availableHeight);
    final minWidth = math.min(_homeInlineComposeMinWidth, maxWidth);
    final minEditorHeight = math.min(
      _homeInlineComposeMinEditorHeight,
      maxEditorHeight,
    );
    final restoredWidth = (saved?.width ?? _homeInlineComposeDefaultWidth)
        .clamp(minWidth, maxWidth)
        .toDouble();
    final restoredEditorHeight =
        (saved?.editorHeight ??
                _homeInlinePanelEditorHeight ??
                _homeInlineComposeMinEditorHeight)
            .clamp(minEditorHeight, maxEditorHeight)
            .toDouble();
    final panelHeight = chromeHeight + restoredEditorHeight;
    final freeWidth = _resolveHomeInlineHorizontalFreeWidth(
      availableWidth,
      restoredWidth,
    );
    final freeHeight = math.max(0, availableHeight - panelHeight);
    _homeInlinePanelWidth = restoredWidth;
    _homeInlinePanelEditorHeight = restoredEditorHeight;
    _homeInlinePanelXRatio = _clampRatio(saved?.xRatio ?? 0);
    _homeInlinePanelYRatio = _clampRatio(saved?.yRatio ?? 0);
    if (resetUnavailableAxes && freeWidth <= 0) {
      _homeInlinePanelXRatio = 0;
    }
    if (resetUnavailableAxes && freeHeight <= 0) {
      _homeInlinePanelYRatio = 0;
    }
    _homeInlinePanelRestored = true;
  }

  void _primeHomeInlinePanelLayout({
    required bool devicePreferencesLoaded,
    required double availableWidth,
    required double availableHeight,
    required double estimatedChromeHeight,
  }) {
    if (_homeInlinePanelRestored ||
        _homeInlinePanelMetricsReady ||
        !devicePreferencesLoaded ||
        availableWidth <= 0 ||
        availableHeight <= 0) {
      return;
    }
    _homeInlinePanelChromeHeight = estimatedChromeHeight;
    _homeInlinePanelMetricsReady = true;
    _setHomeInlinePanelLayoutFromPreference(
      saved: _readHomeInlinePanelSavedLayout(),
      availableWidth: availableWidth,
      availableHeight: availableHeight,
      chromeHeight: estimatedChromeHeight,
      resetUnavailableAxes: false,
    );
  }

  void _maybeRestoreHomeInlinePanelLayout({
    required double availableWidth,
    required double availableHeight,
  }) {
    if (_homeInlinePanelRestored ||
        !_homeInlinePanelMetricsReady ||
        availableWidth <= 0 ||
        availableHeight <= 0) {
      return;
    }
    _setStateWithDiagnostics('home_inline_restore_layout', () {
      _setHomeInlinePanelLayoutFromPreference(
        saved: _readHomeInlinePanelSavedLayout(),
        availableWidth: availableWidth,
        availableHeight: availableHeight,
        chromeHeight: _homeInlinePanelChromeHeight,
        resetUnavailableAxes: true,
      );
    });
  }

  DesktopResizablePanelRect? _buildHomeInlinePanelRect({
    required double availableWidth,
    required double availableHeight,
  }) {
    final width = _homeInlinePanelWidth;
    final editorHeight = _homeInlinePanelEditorHeight;
    if (width == null ||
        editorHeight == null ||
        !_homeInlinePanelMetricsReady) {
      return null;
    }
    final minWidth = math.min(
      _homeInlineComposeMinWidth,
      _resolveHomeInlineMaxWidth(availableWidth),
    );
    final minEditorHeight = math.min(
      _homeInlineComposeMinEditorHeight,
      _resolveHomeInlineMaxEditorHeight(availableHeight),
    );
    final clampedWidth = width
        .clamp(minWidth, _resolveHomeInlineMaxWidth(availableWidth))
        .toDouble();
    final clampedEditorHeight = editorHeight
        .clamp(
          minEditorHeight,
          _resolveHomeInlineMaxEditorHeight(availableHeight),
        )
        .toDouble();
    final panelHeight = _homeInlinePanelChromeHeight + clampedEditorHeight;
    final freeWidth = _resolveHomeInlineHorizontalFreeWidth(
      availableWidth,
      clampedWidth,
    );
    final freeHeight = math.max(0, availableHeight - panelHeight).toDouble();
    final logicalLeft = _offsetFromRatio(_homeInlinePanelXRatio, freeWidth);
    final logicalTop = _offsetFromRatio(_homeInlinePanelYRatio, freeHeight);
    return DesktopResizablePanelRect(
      left:
          _homeInlineComposeHitZoneExtent +
          _homeInlineComposeViewportMargin +
          logicalLeft,
      top: _homeInlineComposeHitZoneExtent + logicalTop,
      width: clampedWidth,
      height: panelHeight,
    );
  }

  double? _readHomeInlineComposeGlobalTop() {
    final context = _homeInlineComposeCardKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero).dy;
  }

  void _restoreHomeInlineComposeViewportAnchor(double? previousGlobalTop) {
    if (previousGlobalTop == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final nextGlobalTop = _readHomeInlineComposeGlobalTop();
      if (nextGlobalTop == null) return;
      final delta = nextGlobalTop - previousGlobalTop;
      if (delta.abs() < 0.5) return;
      final position = _scrollController.position;
      final target = (position.pixels + delta)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      if ((target - position.pixels).abs() < 0.5) return;
      _scrollController.jumpTo(target);
    });
  }

  void _applyHomeInlinePanelRect(
    DesktopResizablePanelRect rect, {
    required double availableWidth,
    required double availableHeight,
    bool persist = false,
  }) {
    final previousRect = _buildHomeInlinePanelRect(
      availableWidth: availableWidth,
      availableHeight: availableHeight,
    );
    final maxWidth = _resolveHomeInlineMaxWidth(availableWidth);
    final maxEditorHeight = _resolveHomeInlineMaxEditorHeight(availableHeight);
    final minWidth = math.min(_homeInlineComposeMinWidth, maxWidth);
    final minEditorHeight = math.min(
      _homeInlineComposeMinEditorHeight,
      maxEditorHeight,
    );
    final shouldMaintainViewportAnchor =
        previousRect != null && (rect.top - previousRect.top).abs() < 0.5;
    final previousGlobalTop = shouldMaintainViewportAnchor
        ? _readHomeInlineComposeGlobalTop()
        : null;
    final nextWidth = rect.width.clamp(minWidth, maxWidth).toDouble();
    final nextEditorHeight = (rect.height - _homeInlinePanelChromeHeight)
        .clamp(minEditorHeight, maxEditorHeight)
        .toDouble();
    final panelHeight = _homeInlinePanelChromeHeight + nextEditorHeight;
    final freeWidth = _resolveHomeInlineHorizontalFreeWidth(
      availableWidth,
      nextWidth,
    );
    final freeHeight = math.max(0, availableHeight - panelHeight).toDouble();
    final nextLeft =
        (rect.left -
                _homeInlineComposeHitZoneExtent -
                _homeInlineComposeViewportMargin)
            .clamp(0, freeWidth)
            .toDouble();
    final nextTop = (rect.top - _homeInlineComposeHitZoneExtent)
        .clamp(0, freeHeight)
        .toDouble();
    final nextXRatio = _ratioFromOffset(nextLeft, freeWidth);
    final nextYRatio = _ratioFromOffset(nextTop, freeHeight);
    _setStateWithDiagnostics('home_inline_panel_rect', () {
      _homeInlinePanelWidth = nextWidth;
      _homeInlinePanelEditorHeight = nextEditorHeight;
      _homeInlinePanelXRatio = nextXRatio;
      _homeInlinePanelYRatio = nextYRatio;
    });
    _restoreHomeInlineComposeViewportAnchor(previousGlobalTop);
    if (!persist) return;
    ref
        .read(devicePreferencesProvider.notifier)
        .setHomeInlineComposePanelLayout(
          HomeInlineComposePanelLayoutPreference(
            width: nextWidth,
            editorHeight: nextEditorHeight,
            xRatio: nextXRatio,
            yRatio: nextYRatio,
          ),
        );
  }

  @override
  void initState() {
    super.initState();
    _desktopHomeUtilityView = widget.initialDesktopUtilityView;
    _inlineComposer = MemoComposerController();
    _headerController = MemosListHeaderController(initialTag: widget.tag);
    _inlineComposeCoordinator = MemosListInlineComposeCoordinator(
      ref: ref,
      composer: _inlineComposer,
      templateRenderer: MemoTemplateRenderer(),
      imagePicker: ImagePicker(),
    );
    _audioPlaybackCoordinator = MemosListAudioPlaybackCoordinator(
      read: ref.read,
    );
    _mutationCoordinator = MemosListMutationCoordinator(read: ref.read);
    _viewportCoordinator = MemosListViewportCoordinator(
      initialPageSize: _initialPageSize,
      pageStep: _pageStep,
    );
    _floatingCollapseController = MemosListFloatingCollapseController();
    _inlineComposeUiController = MemosListInlineComposeUiController(
      composer: _inlineComposer,
      focusNode: _inlineComposeFocusNode,
      currentTagStats: () =>
          ref.read(tagStatsProvider).valueOrNull ?? const <TagStat>[],
      readDraft: () => ref.read(noteDraftProvider),
      listenDraft: (listener) => ref.listenManual<AsyncValue<String>>(
        noteDraftProvider,
        (previous, next) => listener(next),
      ),
      saveDraft: (value) =>
          ref.read(noteDraftProvider.notifier).setDraft(value),
      busy: () => _mutationCoordinator.inlineComposeSubmitting,
    );
    _inlineComposeKeyboardResumeController =
        AndroidMemoKeyboardResumeController(
          focusNode: _inlineComposeFocusNode,
          isSurfaceEligible: _isInlineComposeKeyboardResumeEligible,
          isRouteCurrent: _isKeyboardResumeRouteCurrent,
          isKeyboardVisible: _isKeyboardVisibleForResume,
        );
    _localLibraryCoordinator = MemosListLocalLibraryCoordinator(
      read: ref.read,
      errorFormatter: (error) =>
          presentSyncError(language: context.appLanguage, error: error),
      onAutoScanFailure: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_local_library_import_failed(
                e: error,
              ),
            ),
          ),
        );
      },
    );
    _routeDelegate = MemosListRouteDelegate(
      contextResolver: () => context,
      read: ref.read,
      scaffoldKey: _scaffoldKey,
      buildHomeScreen: _buildHomeScreen,
      invalidateShortcuts: () => ref.invalidate(shortcutsProvider),
      submitDesktopQuickInput: _submitDesktopQuickInput,
      scrollToTop: _handleScrollToTop,
      focusInlineCompose: _inlineComposeFocusNode.requestFocus,
      shouldUseInlineComposeForCurrentWindow:
          _shouldUseInlineComposeForCurrentWindow,
      enableCompose: () => widget.enableCompose,
      searching: () => _searching,
      desktopHeaderSearchExpanded: () => _desktopHeaderSearchExpanded,
      closeSearch: _closeSearch,
      closeDesktopHeaderSearch: _closeDesktopHeaderSearch,
      maybeScanLocalLibrary: _maybeScanLocalLibrary,
      isAllMemos: () => _isAllMemos,
      showDrawer: () => widget.showDrawer,
      dayFilter: () => widget.dayFilter,
      selectedShortcutIdResolver: () => _selectedShortcutId,
      selectShortcutId: (shortcutId) =>
          _headerController.selectShortcut(shortcutId),
      markSceneGuideSeen: _markSceneGuideSeen,
      embeddedNavigationHost: widget.embeddedNavigationHost,
      desktopPresentationResolver: (_) =>
          _resolveCurrentMemosListDesktopPresentation(),
      showNoteInputSheet: widget.showNoteInputSheet,
      showDesktopComposeSurface: _showDesktopComposeSurface,
      showVoiceRecordOverlay: widget.showVoiceRecordOverlay,
      openDesktopSyncQueue: () =>
          _showDesktopHomeUtilityView(DesktopHomeUtilityView.syncQueue),
      openDesktopNotifications: () =>
          _showDesktopHomeUtilityView(DesktopHomeUtilityView.notifications),
    );
    _memoActionDelegate = MemosListMemoActionDelegate(
      contextResolver: () => context,
      mutationCoordinator: _mutationCoordinator,
      onRetryOpenSyncQueue: (_) async => _routeDelegate.openSyncQueue(),
      confirmDelete: _confirmDeleteMemo,
      removeMemoWithAnimation: _removeMemoWithAnimation,
      invalidateMemoRenderCache: invalidateMemoRenderCacheForUid,
      invalidateMemoMarkdownCache: invalidateMemoMarkdownCacheForUid,
      copyMemoContent: _copyMemoContent,
      openEditor: _openMemoEditor,
      openHistory: _openMemoHistory,
      openReminder: _openMemoReminder,
      openAddToCollection: (memo) async {
        await showAddMemoToCollectionSheet(
          context: context,
          ref: ref,
          memo: memo,
        );
      },
      pickTimeAdjustment: (memo) {
        return showMemoTimeAdjustmentSheet(context: context, memo: memo);
      },
      handleRestoreSuccess: (toastMessage) async {
        if (!mounted) return;
        final embeddedNavigationHost = widget.embeddedNavigationHost;
        if (embeddedNavigationHost != null) {
          showTopToast(context, toastMessage);
          embeddedNavigationHost.handleBackToPrimaryDestination(context);
          return;
        }
        await Navigator.of(context).pushReplacement(
          buildPlatformPageRoute<void>(
            context: context,
            builder: (_) => _buildHomeScreen(toastMessage: toastMessage),
          ),
        );
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
    _animatedListController = MemosListAnimatedListController();
    _logManager = ref.read(logManagerProvider);
    _diagnostics = MemosListDiagnostics(
      debugLog: (message, {error, stackTrace, context}) {
        _logManager.debug(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      },
      infoLog: (message, {error, stackTrace, context}) {
        _logManager.info(
          message,
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
      },
      logEmptyViewDiagnostics:
          ({
            required queryKey,
            required providerCount,
            required animatedCount,
            required searchQuery,
            required resolvedTag,
            required useShortcutFilter,
            required useQuickSearch,
            required useAiSearch,
            required useRemoteSearch,
            required startTimeSec,
            required endTimeSecExclusive,
            required shortcutFilter,
            required quickSearchKind,
          }) {
            return ref
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
                  useAiSearch: useAiSearch,
                  useRemoteSearch: useRemoteSearch,
                  startTimeSec: startTimeSec,
                  endTimeSecExclusive: endTimeSecExclusive,
                  shortcutFilter: shortcutFilter,
                  quickSearchKind: quickSearchKind,
                );
          },
    );
    _desktopShortcutDelegate = MemosListDesktopShortcutDelegate(
      bindingsResolver: () => normalizeDesktopShortcutBindings(
        ref.read(devicePreferencesProvider).desktopShortcutBindings,
      ),
      routeActive: _isDesktopShortcutRouteActive,
      inlineEditorActive: () => _inlineComposeFocusNode.hasFocus,
      quickRecordSystemHotKeyActive: () => desktopQuickRecordHotKeyIsActive(
        ref.read(desktopQuickRecordHotKeyRegistrationStatusProvider),
      ),
      callbacks: MemosListDesktopShortcutCallbacks(
        onMarkDesktopShortcutGuideSeen: () =>
            _markSceneGuideSeen(SceneMicroGuideId.desktopGlobalShortcuts),
        onOpenShortcutOverview: () {
          _routeDelegate.openShortcutOverviewPage();
          showTopToast(
            context,
            context.t.strings.legacy.msg_shortcuts_overview_opened,
          );
        },
        onFocusSearch: _focusSearchFromShortcut,
        onOpenQuickInput: () =>
            unawaited(_routeDelegate.openQuickInputFromShortcut()),
        onOpenQuickRecord: () =>
            unawaited(_routeDelegate.openQuickRecordFromShortcut()),
        onSubmitInlineCompose: () => unawaited(_submitInlineCompose()),
        onToggleBold: _inlineComposeUiController.toggleBold,
        onToggleUnderline: _inlineComposeUiController.toggleUnderline,
        onToggleHighlight: _inlineComposeUiController.toggleHighlight,
        onToggleUnorderedList: _inlineComposeUiController.toggleUnorderedList,
        onToggleOrderedList: _inlineComposeUiController.toggleOrderedList,
        onUndo: _inlineComposeUiController.undo,
        onRedo: _inlineComposeUiController.redo,
        onPageNavigation: ({required down, required source}) =>
            _handlePageNavigationShortcut(down: down, source: source),
        onOpenPasswordLock: _routeDelegate.openPasswordLockFromShortcut,
        onToggleSidebar: _routeDelegate.toggleDesktopDrawerFromShortcut,
        onRefresh: () => unawaited(
          ref
              .read(syncCoordinatorProvider.notifier)
              .requestSync(
                const SyncRequest(
                  kind: SyncRequestKind.memos,
                  reason: SyncRequestReason.manual,
                ),
              ),
        ),
        onBackHome: _routeDelegate.backToAllMemos,
        onOpenSettings: () => unawaited(_routeDelegate.openSettings()),
        onToggleMemoFlowVisibility: () =>
            unawaited(_routeDelegate.toggleMemoFlowVisibilityFromShortcut()),
      ),
    );
    _audioPlaybackCoordinatorListener = _buildStateListener(
      'audio_playback_coordinator',
    );
    _mutationCoordinatorListener = _buildStateListener('mutation_coordinator');
    _viewportCoordinatorListener = _buildStateListener('viewport_coordinator');
    _headerControllerListener = _buildStateListener('header_controller');
    _inlineComposeUiControllerListener = _buildStateListener(
      'inline_compose_ui_controller',
    );
    _localLibraryCoordinatorListener = _buildStateListener(
      'local_library_coordinator',
    );
    _routeDelegateListener = _buildStateListener('route_delegate');
    _animatedListControllerListener = _buildStateListener(
      'animated_list_controller',
    );

    _inlineComposeCoordinator.addListener(
      _handleInlineComposeCoordinatorChanged,
    );
    _audioPlaybackCoordinator.addListener(_audioPlaybackCoordinatorListener);
    _mutationCoordinator.addListener(_mutationCoordinatorListener);
    _viewportCoordinator.addListener(_viewportCoordinatorListener);
    _headerController.addListener(_headerControllerListener);
    _inlineComposeUiController.addListener(_inlineComposeUiControllerListener);
    _localLibraryCoordinator.addListener(_localLibraryCoordinatorListener);
    _routeDelegate.addListener(_routeDelegateListener);
    _animatedListController.addListener(_animatedListControllerListener);
    _inlineComposer.addListener(_handleInlineComposeStateChanged);
    _scrollController.addListener(_handleViewportScrollChanged);
    _inlineComposer.textController.addListener(_handleInlineComposeChanged);
    _inlineComposeFocusNode.addListener(_handleInlineComposeFocusChanged);
    _showBackToTopDiagnosticsListener = _handleShowBackToTopDiagnosticsChanged;
    _viewportCoordinator.showBackToTopListenable.addListener(
      _showBackToTopDiagnosticsListener,
    );
    _floatingCollapseDiagnosticsListener =
        _handleFloatingCollapseDiagnosticsChanged;
    _floatingCollapseController.addListener(
      _floatingCollapseDiagnosticsListener,
    );
    _lastShowBackToTopDiagnosticsValue = _viewportCoordinator.showBackToTop;
    _lastFloatingCollapseDiagnosticsState = _floatingCollapseController.value;
    _frameTimingsCallback = _handleFrameTimings;
    SchedulerBinding.instance.addTimingsCallback(_frameTimingsCallback);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleViewportScrollChanged();
      _openDrawerIfNeeded();
      _scheduleViewportDerivedMetricsSync();
      if (!mounted) return;
      final message = widget.toastMessage;
      if (message == null || message.trim().isEmpty) return;
      showTopToast(context, message);
    });
    if (Platform.isWindows) {
      windowManager.addListener(this);
      unawaited(_routeDelegate.syncDesktopWindowState());
    }
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.addHandler(_handleDesktopShortcuts);
    }
  }

  @override
  void didUpdateWidget(covariant MemosListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _headerController.syncExternalTag(widget.tag);
    }
    if (oldWidget.initialDesktopUtilityView !=
            widget.initialDesktopUtilityView &&
        widget.initialDesktopUtilityView != DesktopHomeUtilityView.none) {
      _desktopHomeUtilityView = widget.initialDesktopUtilityView;
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
    _desktopPreviewPressTimer?.cancel();
    _scrollController.removeListener(_handleViewportScrollChanged);
    _inlineComposer.removeListener(_handleInlineComposeStateChanged);
    _inlineComposer.textController.removeListener(_handleInlineComposeChanged);
    _inlineComposeFocusNode.removeListener(_handleInlineComposeFocusChanged);
    _inlineComposeCoordinator.removeListener(
      _handleInlineComposeCoordinatorChanged,
    );
    _audioPlaybackCoordinator.removeListener(_audioPlaybackCoordinatorListener);
    _mutationCoordinator.removeListener(_mutationCoordinatorListener);
    _viewportCoordinator.removeListener(_viewportCoordinatorListener);
    _headerController.removeListener(_headerControllerListener);
    _inlineComposeUiController.removeListener(
      _inlineComposeUiControllerListener,
    );
    _localLibraryCoordinator.removeListener(_localLibraryCoordinatorListener);
    _routeDelegate.removeListener(_routeDelegateListener);
    _animatedListController.removeListener(_animatedListControllerListener);
    _viewportCoordinator.showBackToTopListenable.removeListener(
      _showBackToTopDiagnosticsListener,
    );
    _floatingCollapseController.removeListener(
      _floatingCollapseDiagnosticsListener,
    );
    SchedulerBinding.instance.removeTimingsCallback(_frameTimingsCallback);
    _flushScrollPerfSession('dispose');
    _scrollPerfIdleTimer?.cancel();
    _scrollPerfIdleTimer = null;
    _voiceOverlayDragSession?.dispose();
    unawaited(_saveInlineComposeDraft(triggerSync: false));
    _inlineComposeKeyboardResumeController.dispose();
    _inlineComposeCoordinator.dispose();
    _audioPlaybackCoordinator.dispose();
    _mutationCoordinator.dispose();
    _viewportCoordinator.dispose();
    _inlineComposeUiController.dispose();
    _localLibraryCoordinator.dispose();
    _routeDelegate.dispose();
    _animatedListController.dispose();
    _floatingCollapseController.dispose();
    _inlineComposeFocusNode.dispose();
    _inlineComposer.dispose();
    _headerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleInlineComposeCoordinatorChanged() {
    _setStateWithDiagnostics('inline_compose_coordinator', () {});
    _scheduleInlineComposeDraftSave();
  }

  void _handleInlineComposeStateChanged() {
    if (_suppressInlineComposeDraftSave) return;
    _scheduleInlineComposeDraftSave();
  }

  void _scheduleInlineComposeDraftSave() {
    if (_suppressInlineComposeDraftSave) return;
    _inlineComposeDraftTimer?.cancel();
    _inlineComposeDraftTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveInlineComposeDraft());
    });
  }

  Future<String?> _saveInlineComposeDraft({bool triggerSync = true}) async {
    final repository = _composeDraftRepository;
    final noteDraftController = _noteDraftController;
    final noteDraftRepository = _noteDraftRepository;
    if (repository == null || noteDraftController == null) {
      return null;
    }
    final snapshot = ComposeDraftSnapshot(
      content: _inlineComposer.textController.text,
      visibility: _inlineComposeCoordinator.visibilityTouched
          ? _inlineComposeCoordinator.visibility
          : _inlineComposeDefaultVisibility,
      relations: _inlineComposer.linkedMemos
          .map((memo) => memo.toRelationJson())
          .toList(growable: false),
      attachments: _inlineComposer.pendingAttachments
          .map(ComposeDraftAttachment.fromPendingAttachment)
          .toList(growable: false),
      location: _inlineComposeCoordinator.location,
    );
    final nextDraftId = await repository.saveSnapshot(
      draftUid: _inlineComposeActiveDraftId,
      snapshot: snapshot,
    );
    _inlineComposeActiveDraftId = nextDraftId;
    await _persistLegacyInlineComposeDraft(
      _inlineComposer.textController.text,
      noteDraftController: noteDraftController,
      noteDraftRepository: noteDraftRepository,
      triggerSync: triggerSync,
    );
    return nextDraftId;
  }

  Future<void> _persistLegacyInlineComposeDraft(
    String text, {
    required NoteDraftController noteDraftController,
    required NoteDraftRepository? noteDraftRepository,
    required bool triggerSync,
  }) async {
    if (mounted) {
      await noteDraftController.setDraft(text, triggerSync: triggerSync);
      return;
    }
    final repository = noteDraftRepository;
    if (repository == null) return;
    if (text.trim().isEmpty) {
      await repository.clear();
      return;
    }
    await repository.write(text);
  }

  void _restoreInlineComposeDraft(ComposeDraftRecord draft) {
    _inlineComposeDraftTimer?.cancel();
    _suppressInlineComposeDraftSave = true;
    _inlineComposeActiveDraftId = draft.uid;
    _inlineComposeCoordinator.restoreDraftState(
      visibility: draft.snapshot.visibility,
      location: draft.snapshot.location,
    );
    _inlineComposer.replaceText(draft.snapshot.content, clearHistory: true);
    _inlineComposer.setLinkedMemos(
      _inlineLinkedMemosFromRelations(draft.snapshot.relations),
    );
    _inlineComposer.setPendingAttachments(
      draft.snapshot.attachments
          .map((attachment) => attachment.toPendingAttachment())
          .toList(growable: false),
    );
    _suppressInlineComposeDraftSave = false;
    _setStateWithDiagnostics('restore_inline_compose_draft', () {});
  }

  void _clearInlineComposeState() {
    _inlineComposeDraftTimer?.cancel();
    _suppressInlineComposeDraftSave = true;
    _inlineComposeActiveDraftId = null;
    _inlineComposeCoordinator.resetAfterSuccessfulSubmit();
    _inlineComposeCoordinator.resetDraftStateToDefault();
    _suppressInlineComposeDraftSave = false;
    unawaited(ref.read(noteDraftProvider.notifier).clear());
    _setStateWithDiagnostics('clear_inline_compose_state', () {});
  }

  List<MemoComposerLinkedMemo> _inlineLinkedMemosFromRelations(
    List<Map<String, dynamic>> relations,
  ) {
    final linked = <MemoComposerLinkedMemo>[];
    final seenNames = <String>{};
    for (final relation in relations) {
      final relatedMemoRaw = relation['relatedMemo'];
      if (relatedMemoRaw is! Map) continue;
      final name = (relatedMemoRaw['name'] as String? ?? '').trim();
      if (name.isEmpty || !seenNames.add(name)) continue;
      linked.add(
        MemoComposerLinkedMemo(
          name: name,
          label: name.startsWith('memos/') ? name.substring(6) : name,
        ),
      );
    }
    return linked;
  }

  MemosListScreen _buildHomeScreen({String? toastMessage}) {
    return MemosListScreen(
      title: 'MemoFlow',
      state: 'NORMAL',
      showDrawer: true,
      enableCompose: true,
      toastMessage: toastMessage,
      presentation: widget.presentation,
      embeddedNavigationHost: widget.embeddedNavigationHost,
      hidePrimaryComposeFab: widget.hidePrimaryComposeFab,
      enableDrawerOpenDragGesture: true,
    );
  }

  MemosListScreen _buildArchivedScreen() {
    return MemosListScreen(
      title: context.t.strings.legacy.msg_archive,
      state: 'ARCHIVED',
      showDrawer: true,
      presentation: widget.presentation,
      embeddedNavigationHost: widget.embeddedNavigationHost,
      hidePrimaryComposeFab: widget.hidePrimaryComposeFab,
      enableDrawerOpenDragGesture:
          widget.presentation != HomeScreenPresentation.embeddedBottomNav,
    );
  }

  void _openHomeQuickAction(HomeQuickAction action) {
    if (ref.read(devicePreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final hasAccount =
        ref.read(appSessionProvider).valueOrNull?.currentAccount != null;
    if (!hasAccount &&
        (action == HomeQuickAction.explore ||
            action == HomeQuickAction.notifications)) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }

    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      switch (action) {
        case HomeQuickAction.none:
          return;
        case HomeQuickAction.monthlyStats:
          break;
        case HomeQuickAction.collections:
          embeddedNavigationHost.handleDrawerDestination(
            context,
            AppDrawerDestination.collections,
          );
          return;
        case HomeQuickAction.aiSummary:
          embeddedNavigationHost.handleDrawerDestination(
            context,
            AppDrawerDestination.aiSummary,
          );
          return;
        case HomeQuickAction.dailyReview:
          embeddedNavigationHost.handleDrawerDestination(
            context,
            AppDrawerDestination.dailyReview,
          );
          return;
        case HomeQuickAction.explore:
          embeddedNavigationHost.handleDrawerDestination(
            context,
            AppDrawerDestination.explore,
          );
          return;
        case HomeQuickAction.notifications:
          embeddedNavigationHost.handleOpenNotifications(context);
          return;
        case HomeQuickAction.resources:
          embeddedNavigationHost.handleDrawerDestination(
            context,
            AppDrawerDestination.resources,
          );
          return;
        case HomeQuickAction.archived:
          embeddedNavigationHost.handleDrawerDestination(
            context,
            AppDrawerDestination.archived,
          );
          return;
      }
    }

    final Widget? route = switch (action) {
      HomeQuickAction.none => null,
      HomeQuickAction.monthlyStats => const StatsScreen(),
      HomeQuickAction.collections => const CollectionsScreen(),
      HomeQuickAction.aiSummary => const AiSummaryScreen(),
      HomeQuickAction.dailyReview => const DailyReviewScreen(),
      HomeQuickAction.explore => const ExploreScreen(),
      HomeQuickAction.notifications => const NotificationsScreen(),
      HomeQuickAction.resources => const ResourcesScreen(),
      HomeQuickAction.archived => _buildArchivedScreen(),
    };

    if (route == null) return;
    Navigator.of(context).push(
      buildPlatformPageRoute<void>(context: context, builder: (_) => route),
    );
  }

  void _markSceneGuideSeen(SceneMicroGuideId id) {
    unawaited(ref.read(sceneMicroGuideProvider.notifier).markSeen(id));
  }

  String _desktopGlobalShortcutsGuideMessage(BuildContext context) {
    final bindings = ref
        .read(devicePreferencesProvider)
        .desktopShortcutBindings;
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

  bool _isMobileNativePlatform() {
    if (kIsWeb) return false;
    final target = resolvePlatformTarget(context);
    return defaultTargetPlatform == TargetPlatform.android ||
        target == PlatformTarget.iPhone;
  }

  bool _isTouchPullLoadPlatform() => _isMobileNativePlatform();

  void _logPaginationDebug(
    String event, {
    ScrollMetrics? metrics,
    Map<String, Object?>? context,
  }) {
    _diagnostics.logPaginationDebug(
      event,
      pageSize: _pageSize,
      resultCount: _currentResultCount,
      lastResultCount: _lastResultCount,
      loadingMore: _loadingMore,
      reachedEnd: _reachedEnd,
      providerLoading: _currentLoading,
      showSearchLanding: _currentShowSearchLanding,
      activeRequestId: _activeLoadMoreRequestId,
      activeRequestSource: _activeLoadMoreSource,
      metrics: metrics,
      extra: context,
    );
  }

  VoidCallback _buildStateListener(String source) {
    return () => _setStateWithDiagnostics(source, () {});
  }

  void _setStateWithDiagnostics(String source, VoidCallback fn) {
    if (!mounted) return;
    _recordScrollPerfStateTrigger(source);
    setState(fn);
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!_enableScrollPerfDiagnostics) return;
    final session = _scrollPerfSession;
    if (session == null) return;
    for (final timing in timings) {
      session.recordFrameTiming(timing);
    }
  }

  void _handleShowBackToTopDiagnosticsChanged() {
    final next = _viewportCoordinator.showBackToTop;
    if (next == _lastShowBackToTopDiagnosticsValue) return;
    _lastShowBackToTopDiagnosticsValue = next;
    final session = _scrollPerfSession;
    if (session == null) return;
    session.showBackToTopToggleCount += 1;
  }

  void _handleFloatingCollapseDiagnosticsChanged() {
    final next = _floatingCollapseController.value;
    final previous = _lastFloatingCollapseDiagnosticsState;
    if (next == previous) return;
    _lastFloatingCollapseDiagnosticsState = next;
    final session = _scrollPerfSession;
    if (session == null) return;
    session.floatingStateChangeCount += 1;
    if (previous.memoUid != next.memoUid) {
      session.floatingMemoSwitchCount += 1;
    }
    if (previous.scrolling != next.scrolling) {
      session.floatingScrollingToggleCount += 1;
    }
  }

  void _ensureScrollPerfSession(String source, {double? pixels}) {
    if (!_enableScrollPerfDiagnostics) return;
    final initialPixels = pixels ?? _currentViewportMetrics()?.pixels ?? 0.0;
    final session = _scrollPerfSession ??= _MemosScrollPerfSession(
      startedAt: DateTime.now(),
      initialPixels: initialPixels,
    );
    session.recordActivity(source, pixels: pixels);
    _scrollPerfIdleTimer?.cancel();
    _scrollPerfIdleTimer = Timer(
      const Duration(milliseconds: 420),
      () => _flushScrollPerfSession('idle'),
    );
  }

  void _flushScrollPerfSession(String reason) {
    if (!_enableScrollPerfDiagnostics) return;
    final session = _scrollPerfSession;
    if (session == null || !session.hasMeaningfulData) {
      _scrollPerfSession = null;
      return;
    }
    _scrollPerfSession = null;
    _scrollPerfIdleTimer?.cancel();
    _scrollPerfIdleTimer = null;
    _logManager.info(
      'Memos scroll perf: session',
      context: session.toContext(reason: reason),
    );
  }

  void _recordScrollPerfStateTrigger(String source) {
    final session = _scrollPerfSession;
    if (session == null) return;
    session.recordStateTrigger(source);
  }

  void _recordScrollPerfViewportDerivedMetricsSyncScheduled() {
    final session = _scrollPerfSession;
    if (session == null) return;
    session.viewportDerivedSyncScheduleCount += 1;
  }

  void _recordScrollPerfViewportDerivedMetricsSyncApplied() {
    final session = _scrollPerfSession;
    if (session == null) return;
    session.viewportDerivedSyncApplyCount += 1;
  }

  void _recordScrollPerfFloatingGeometryChange({required bool removed}) {
    final session = _scrollPerfSession;
    if (session == null) return;
    if (removed) {
      session.floatingGeometryRemoveCount += 1;
      return;
    }
    session.floatingGeometryUpsertCount += 1;
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
          context: <String, Object?>{
            'requestId': effect.requestId,
            'source': effect.source,
            'fromPageSize': effect.fromPageSize,
            'toPageSize': effect.toPageSize,
          },
        );
        return;
      case MemosListViewportLoadMoreEffectKind.skipped:
        _logPaginationDebug(
          'load_more_skipped',
          metrics: metrics,
          context: <String, Object?>{
            'source': effect.source,
            'reason': effect.skipReason,
          },
        );
        return;
    }
  }

  void _handleViewportScrollChanged() {
    final metrics = _currentViewportMetrics();
    if (metrics == null) return;
    _ensureScrollPerfSession('scroll_listener', pixels: metrics.pixels);
    _scrollPerfSession?.recordScrollListenerTick(pixels: metrics.pixels);
    final effect = _viewportCoordinator.handleScroll(metrics);
    _floatingCollapseController.updateViewportMetrics(metrics);
    if (effect.jumpedToTopUnexpectedly) {
      _logPaginationDebug(
        'scroll_jump_to_top_detected',
        metrics: _currentScrollMetricsForLogging(),
        context: <String, Object?>{'previousOffset': effect.previousOffset},
      );
    }
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
    if ((event.kind == MemosListViewportScrollEventKind.start ||
            event.kind == MemosListViewportScrollEventKind.update ||
            event.kind == MemosListViewportScrollEventKind.overscroll) &&
        _activeDesktopPreviewPressSequence != null) {
      _cancelPendingDesktopPreviewPress(rollbackIfOpened: true);
    }
    _ensureScrollPerfSession(
      'scroll_notification_${event.kind.name}',
      pixels: event.metrics.pixels,
    );
    _scrollPerfSession?.recordScrollNotification(
      event.kind.name,
      pixels: event.metrics.pixels,
    );
    _floatingCollapseController.handleScrollEvent(event);
    final effect = _viewportCoordinator.handleLoadMoreScrollEvent(
      event,
      touchPullEnabled: _isTouchPullLoadPlatform(),
    );
    _logLoadMoreEffect(effect, metrics: notification.metrics);
    return false;
  }

  void _collapseActiveMemoFromFloatingButton() {
    final memoUid = _floatingCollapseController.value.memoUid;
    if (memoUid == null) return;
    final memoState = _animatedListController.currentStateFor(memoUid);
    if (memoState == null) return;
    final cardTopScrollOffset = memoState.currentCardTopScrollOffset();
    memoState.collapseFromFloating();
    _restoreFloatingCollapseScrollAnchor(cardTopScrollOffset);
  }

  void _restoreFloatingCollapseScrollAnchor(double? cardTopScrollOffset) {
    if (cardTopScrollOffset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final target = cardTopScrollOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((target - position.pixels).abs() < 0.5) return;
      _scrollController.jumpTo(target);
    });
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
    final pixels = _currentViewportMetrics()?.pixels;
    _ensureScrollPerfSession('pointer_signal', pixels: pixels);
    _scrollPerfSession?.recordPointerSignal(
      event.scrollDelta.dy,
      pixels: pixels,
    );
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
      context: <String, Object?>{'mode': 'distance_dynamic_speed'},
    );
    await _viewportCoordinator.scrollToTop(adapter);
  }

  bool _shouldUseInlineComposeForCurrentWindow() {
    return _inlineComposeUiController.shouldUseInlineComposeForCurrentWindow(
      enableCompose: widget.enableCompose,
      searching: _searching,
      screenWidth: MediaQuery.sizeOf(context).width,
    );
  }

  bool _isInlineComposeKeyboardResumeEligible() {
    if (!mounted || !widget.enableCompose || _inlineComposeBusy) return false;
    if (!_inlineComposeKeyboardResumeVisible) return false;
    return _homeInlineComposeCardKey.currentContext != null;
  }

  bool _isKeyboardResumeRouteCurrent() {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  bool _isKeyboardVisibleForResume() {
    if (!mounted) return false;
    final mediaQuery = MediaQuery.maybeOf(context);
    return (mediaQuery?.viewInsets.bottom ?? 0) > 0;
  }

  bool _isDesktopShortcutRouteActive() {
    if (!mounted || !isDesktopShortcutEnabled()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return !ref.read(appLockProvider).locked;
  }

  void _focusSearchFromShortcut() {
    _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    _headerController.focusSearchFromShortcut(
      searchPresentation:
          _resolveCurrentMemosListDesktopPresentation().searchPresentation,
      onOpenSearch: _openSearch,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _submitDesktopQuickInput(String rawContent) async {
    final visibility = _inlineComposeCoordinator.resolveDefaultVisibility();
    final result = await _mutationCoordinator.submitQuickInput(
      rawContent: rawContent,
      visibility: visibility,
    );
    if (!mounted) return;
    switch (result.kind) {
      case MemosListMutationResultKind.handled:
        showTopToast(context, context.t.strings.legacy.msg_saved_to_memoflow);
        return;
      case MemosListMutationResultKind.noop:
        return;
      case MemosListMutationResultKind.failed:
        showTopToast(
          context,
          context.t.strings.legacy.msg_quick_input_save_failed_with_error(
            error: result.error ?? '',
          ),
        );
        return;
    }
  }

  void _logDesktopShortcutEvent({
    required String stage,
    required KeyEvent event,
    required Set<LogicalKeyboardKey> pressedKeys,
    DesktopShortcutAction? action,
    String? reason,
    Map<String, Object?>? extra,
  }) {
    final payload = <String, Object?>{
      'keyId': event.logicalKey.keyId,
      'keyLabel': event.logicalKey.keyLabel,
      'debugName': event.logicalKey.debugName,
      'primaryPressed': isPrimaryShortcutModifierPressed(pressedKeys),
      'shiftPressed': isShiftModifierPressed(pressedKeys),
      'altPressed': isAltModifierPressed(pressedKeys),
      if (action != null) 'action': action.name,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      if (extra != null) ...extra,
    };
    if (stage == 'matched' || stage == 'delegated') {
      ref
          .read(logManagerProvider)
          .info('Desktop shortcut: $stage', context: payload);
    } else {
      ref
          .read(logManagerProvider)
          .debug('Desktop shortcut: $stage', context: payload);
    }
  }

  bool _handleDesktopShortcuts(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final paneState = ref.read(desktopHomePaneStateProvider);
    final selectedMemo = _findMemoByUid(
      _animatedMemos,
      paneState.selectedMemoUid,
    );
    final usesDefaultDesktopPreviewLayout =
        !kIsWeb &&
        _resolveCurrentMemosListDesktopPresentation()
            .previewPanePolicy
            .defaultMemoClickOpensPreview;
    final primaryPressed = isPrimaryShortcutModifierPressed(pressed);
    final shiftPressed = isShiftModifierPressed(pressed);
    final altPressed = isAltModifierPressed(pressed);
    final textEditingKeyboardOwnerActive = _isTextEditingKeyboardOwnerActive();

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        paneState.secondaryPaneMode != DesktopHomeSecondaryPaneMode.none) {
      _closeDesktopPreview();
      return true;
    }

    if (!textEditingKeyboardOwnerActive && selectedMemo != null) {
      if (!primaryPressed &&
          !shiftPressed &&
          !altPressed &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          usesDefaultDesktopPreviewLayout) {
        _openMemoDetailRoute(
          selectedMemo,
          heroTag: memoHeroTagForMemo(selectedMemo),
        );
        return true;
      }

      if (primaryPressed && !shiftPressed && !altPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyE &&
            usesDefaultDesktopPreviewLayout) {
          unawaited(
            _memoActionDelegate.handleMemoAction(
              selectedMemo,
              MemoCardAction.edit,
            ),
          );
          return true;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyC) {
          unawaited(_copyMemoContent(selectedMemo));
          return true;
        }
      }
    }

    final dispatch = _desktopShortcutDelegate.handle(event, pressed);
    if (dispatch.shouldLog) {
      final stage = switch (dispatch.stage) {
        MemosListDesktopShortcutDispatchStage.ignored => 'ignored',
        MemosListDesktopShortcutDispatchStage.noMatch => 'no_match',
        MemosListDesktopShortcutDispatchStage.matched => 'matched',
        MemosListDesktopShortcutDispatchStage.delegated => 'delegated',
      };
      _logDesktopShortcutEvent(
        stage: stage,
        event: event,
        pressedKeys: pressed,
        action: dispatch.action,
        reason: dispatch.reason,
        extra: dispatch.extra,
      );
    }
    return dispatch.handled;
  }

  @override
  void onWindowMaximize() {
    _routeDelegate.onWindowMaximize();
    _scheduleViewportDerivedMetricsSync();
  }

  @override
  void onWindowUnmaximize() {
    _routeDelegate.onWindowUnmaximize();
    _scheduleViewportDerivedMetricsSync();
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
    _headerController.openSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _openDesktopHeaderSearch() {
    if (!_resolveCurrentMemosListDesktopPresentation()
            .usesDesktopHeaderSearch ||
        !widget.enableSearch) {
      return;
    }
    _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    _headerController.openDesktopHeaderSearch();
  }

  void _closeDesktopHeaderSearch({bool clearQuery = true}) {
    if (!_desktopHeaderSearchExpanded) return;
    _headerController.closeDesktopHeaderSearch(clearQuery: clearQuery);
  }

  void _toggleDesktopHeaderSearch() {
    if (_desktopHeaderSearchExpanded) {
      _closeDesktopHeaderSearch();
      return;
    }
    _openDesktopHeaderSearch();
  }

  void _closeSearch() {
    _headerController.closeSearch(
      clearGlobalFocus: () => FocusScope.of(context).unfocus(),
    );
  }

  void _startAiSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty || _aiSearchActive) return;
    unawaited(_startAiSearchWithPreflight(query));
  }

  Future<void> _startAiSearchWithPreflight(String query) async {
    final aiSearchQuery = _buildAiSearchPreflightQuery(query);
    if (aiSearchQuery == null) return;
    AiSemanticMemoSearchIndexPreflight preflight;
    try {
      preflight = await ref.read(
        aiSearchIndexPreflightProvider(aiSearchQuery).future,
      );
    } on AiSemanticMemoSearchConfigurationException {
      _activateAiSearch(query);
      return;
    } catch (error, stackTrace) {
      _logManager.warn(
        'AI search index preflight failed; continuing with AI search flow',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'queryLength': query.length},
      );
      _activateAiSearch(query);
      return;
    }
    if (!mounted || _searchController.text.trim() != query) return;
    if (preflight.needsIndexing) {
      final confirmed = await _confirmAiSearchIndexing(preflight);
      if (!confirmed || !mounted || _searchController.text.trim() != query) {
        return;
      }
    }
    _activateAiSearch(query);
  }

  AiSearchMemosQuery? _buildAiSearchPreflightQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final dayRange = _aiSearchDayRangeSeconds(widget.dayFilter);
    return (
      searchQuery: trimmed,
      state: widget.state,
      tag: _activeTagFilter,
      startTimeSec: dayRange?.startSec,
      endTimeSecExclusive: dayRange?.endSecExclusive,
      advancedFilters: _advancedSearchFilters,
      pageSize: _pageSize,
    );
  }

  ({int startSec, int endSecExclusive})? _aiSearchDayRangeSeconds(
    DateTime? day,
  ) {
    if (day == null) return null;
    final localDay = DateTime(day.year, day.month, day.day);
    final nextDay = localDay.add(const Duration(days: 1));
    return (
      startSec: localDay.toUtc().millisecondsSinceEpoch ~/ 1000,
      endSecExclusive: nextDay.toUtc().millisecondsSinceEpoch ~/ 1000,
    );
  }

  Future<bool> _confirmAiSearchIndexing(
    AiSemanticMemoSearchIndexPreflight preflight,
  ) async {
    final legacy = context.t.strings.legacy;
    final message = preflight.usesRemoteBackend
        ? legacy.msg_ai_search_index_confirm_remote_message
        : legacy.msg_ai_search_index_confirm_local_message;
    return await showPlatformAlertDialog<bool>(
          context: context,
          title: legacy.msg_ai_search_index_confirm_title,
          message: message,
          details: legacy.msg_ai_search_index_confirm_token_estimate(
            count: preflight.estimatedTokenCount,
          ),
          actions: [
            PlatformDialogAction<bool>(
              value: false,
              label: legacy.msg_cancel_2,
            ),
            PlatformDialogAction<bool>(
              value: true,
              label: legacy.msg_ai_search_index_confirm_continue,
              isDefault: true,
            ),
          ],
        ) ??
        false;
  }

  void _activateAiSearch(String query) {
    if (!mounted || _searchController.text.trim() != query) return;
    ref.read(searchHistoryProvider.notifier).add(query);
    _headerController.startAiSearch();
  }

  void _stopAiSearch() {
    _headerController.stopAiSearch();
  }

  Future<void> _openAdvancedSearchSheet() async {
    final result = await AdvancedSearchSheet.show(
      context,
      initial: _advancedSearchFilters,
      showCreatedDateFilter: widget.dayFilter == null,
    );
    if (!mounted || result == null) return;
    _headerController.setAdvancedSearchFilters(result);
  }

  void _handleInlineComposeChanged() {
    _inlineComposeUiController.handleComposerChanged();
  }

  void _handleInlineComposeFocusChanged() {
    _inlineComposeUiController.handleFocusChanged();
  }

  Future<void> _submitInlineCompose() async {
    if (!widget.enableCompose || _mutationCoordinator.inlineComposeSubmitting) {
      return;
    }
    final draft = await _inlineComposeCoordinator.prepareSubmissionDraft(
      context,
    );
    if (!mounted || draft == null) return;

    final result = await _mutationCoordinator.submitInlineCompose(draft);
    if (!mounted) return;
    switch (result.kind) {
      case MemosListMutationResultKind.handled:
        final submittedDraftId = _inlineComposeActiveDraftId;
        _inlineComposeUiController.cancelDraftSave();
        _inlineComposeDraftTimer?.cancel();
        _suppressInlineComposeDraftSave = true;
        await ref.read(noteDraftProvider.notifier).clear();
        _inlineComposeCoordinator.resetAfterSuccessfulSubmit();
        _inlineComposeActiveDraftId = null;
        if (submittedDraftId != null && submittedDraftId.isNotEmpty) {
          final keepPaths = draft.pendingAttachments
              .map((attachment) => attachment.filePath.trim())
              .where((path) => path.isNotEmpty)
              .toSet();
          await ref
              .read(composeDraftRepositoryProvider)
              .deleteDraft(submittedDraftId, keepPaths: keepPaths);
        }
        _suppressInlineComposeDraftSave = false;
        if (mounted) {
          _inlineComposeFocusNode.requestFocus();
        }
        return;
      case MemosListMutationResultKind.noop:
        return;
      case MemosListMutationResultKind.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_create_failed_2(
                e: result.error ?? '',
              ),
            ),
          ),
        );
        return;
    }
  }

  Future<void> _openInlineComposeDraftBox() async {
    if (!widget.enableCompose || _inlineComposeBusy) return;
    final currentDraftId = await _saveInlineComposeDraft();
    if (!mounted) return;
    final selection = await DraftBoxScreen.show(
      context,
      activeDraftId: _inlineComposeActiveDraftId,
    );
    if (!mounted) return;

    if (selection != null && selection.isCreateMemoDraft) {
      final selectedDraft = await ref
          .read(composeDraftRepositoryProvider)
          .getByUid(selection.draftUid);
      if (!mounted || selectedDraft == null) return;
      _restoreInlineComposeDraft(selectedDraft);
      _inlineComposeFocusNode.requestFocus();
      return;
    }
    if (selection != null && selection.isEditMemoDraft) {
      showTopToast(
        context,
        context.tr(
          zh: '请从草稿箱页面打开编辑草稿',
          en: 'Open edit drafts from the Draft Box page.',
        ),
      );
      return;
    }

    if (currentDraftId != null && currentDraftId.isNotEmpty) {
      final existing = await ref
          .read(composeDraftRepositoryProvider)
          .getByUidWithoutLegacyImport(currentDraftId);
      if (!mounted) return;
      if (existing == null) {
        _clearInlineComposeState();
      }
    }
  }

  Future<bool> _confirmDeleteMemo(LocalMemo memo) async {
    return await showPlatformAlertDialog<bool>(
          context: context,
          title: context.t.strings.legacy.msg_delete_memo,
          message: context
              .t
              .strings
              .legacy
              .msg_removed_locally_now_deleted_server_when,
          actions: [
            PlatformDialogAction<bool>(
              value: false,
              label: context.t.strings.legacy.msg_cancel_2,
            ),
            PlatformDialogAction<bool>(
              value: true,
              label: context.t.strings.legacy.msg_delete,
              isDefault: true,
              isDestructive: true,
            ),
          ],
        ) ??
        false;
  }

  Future<void> _openMemoEditor(LocalMemo memo) async {
    final desktopPresentation = _resolveCurrentMemosListDesktopPresentation();
    if (!kIsWeb && desktopPresentation.usesDesktopComposeSurface) {
      final layoutSpec = _resolveCurrentDesktopLayout();
      if (layoutSpec.tier != DesktopLayoutTier.narrow) {
        _openDesktopComposeEdit(memo);
        return;
      }
      await _showDesktopComposeDialog(
        existing: memo,
        fullscreen: layoutSpec.tier == DesktopLayoutTier.narrow,
      );
      ref.invalidate(memoRelationsProvider(memo.uid));
      return;
    }
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoEditorScreen(existing: memo),
      ),
    );
    ref.invalidate(memoRelationsProvider(memo.uid));
  }

  Future<void> _openMemoHistory(LocalMemo memo) async {
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoVersionsScreen(memoUid: memo.uid),
      ),
    );
  }

  Future<void> _openMemoReminder(LocalMemo memo) async {
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => MemoReminderEditorScreen(memo: memo),
      ),
    );
  }

  void _openTagFromDrawer(String tag) {
    if (ref.read(devicePreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerTag(context, tag);
      return;
    }
    _clearDesktopHomeUtilityView();
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

  bool _supportsDesktopHomeUtilityEmbedding() {
    if (!widget.showDrawer || widget.embeddedNavigationHost != null) {
      return false;
    }
    final target = resolvePlatformTarget(context);
    return target == PlatformTarget.macOS ||
        target == PlatformTarget.windows ||
        target == PlatformTarget.linux;
  }

  bool _showDesktopHomeUtilityView(DesktopHomeUtilityView view) {
    if (!_supportsDesktopHomeUtilityEmbedding()) return false;
    if (_desktopHomeUtilityView == view) return true;
    setState(() => _desktopHomeUtilityView = view);
    return true;
  }

  void _clearDesktopHomeUtilityView() {
    if (_desktopHomeUtilityView == DesktopHomeUtilityView.none) return;
    setState(() => _desktopHomeUtilityView = DesktopHomeUtilityView.none);
  }

  void _handleHomeDrawerDestination(AppDrawerDestination destination) {
    final currentDestination = widget.state == 'ARCHIVED'
        ? AppDrawerDestination.archived
        : AppDrawerDestination.memos;
    if (destination == currentDestination &&
        _desktopHomeUtilityView != DesktopHomeUtilityView.none) {
      if (ref.read(devicePreferencesProvider).hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      _clearDesktopHomeUtilityView();
      return;
    }
    if (destination != AppDrawerDestination.syncQueue) {
      _clearDesktopHomeUtilityView();
    }
    _routeDelegate.navigateDrawer(destination);
  }

  void _handleHomeOpenNotifications() {
    _routeDelegate.openNotifications();
  }

  Future<void> _handleVoiceFabLongPressStart(
    LongPressStartDetails details,
  ) async {
    if (!widget.enableCompose || _voiceOverlayDragFuture != null) return;
    final dragSession = VoiceRecordOverlayDragSession();
    _voiceOverlayDragSession = dragSession;
    dragSession.update(Offset.zero);
    final future = _routeDelegate.openVoiceNoteInput(origin: dragSession);
    _voiceOverlayDragFuture = future;
    unawaited(
      future.whenComplete(() {
        _voiceOverlayDragFuture = null;
        _voiceOverlayDragSession = null;
      }),
    );
  }

  void _handleVoiceFabLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _voiceOverlayDragSession?.update(details.localOffsetFromOrigin);
  }

  void _handleVoiceFabLongPressEnd(LongPressEndDetails details) {
    _voiceOverlayDragSession?.endGesture();
  }

  Future<void> _maybeScanLocalLibrary() async {
    await _localLibraryCoordinator.runManualScan(
      _ScreenLocalLibraryPromptDelegate(
        confirmManualScan: () async {
          if (!mounted) return false;
          final syncState = ref.read(syncCoordinatorProvider).memos;
          if (syncState.running) {
            showTopToast(context, context.t.strings.legacy.msg_syncing);
            return false;
          }
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return false;
          return await showPlatformDialog<bool>(
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
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.t.strings.legacy.msg_cancel_2),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(context.t.strings.legacy.msg_scan),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        resolveConflict: (conflict) async {
          if (!mounted) return false;
          return await showPlatformDialog<bool>(
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
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.t.strings.legacy.msg_keep_local),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(context.t.strings.legacy.msg_use_disk),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        showSyncBusy: () {
          if (!mounted) return;
          showTopToast(context, context.t.strings.legacy.msg_syncing);
        },
        showScanSuccess: () {
          if (!mounted) return;
          showTopToast(context, context.t.strings.legacy.msg_scan_completed);
        },
        showScanFailure: (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t.strings.legacy.msg_scan_failed(e: error)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRefresh({
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useAiSearch,
    required ShortcutMemosQuery? shortcutQuery,
    required QuickSearchMemosQuery? quickSearchQuery,
    required AiSearchMemosQuery? aiSearchQuery,
  }) async {
    final initialContext = context;
    final scanner = ref.read(localLibraryScannerProvider);
    final coordinator = ref.read(syncCoordinatorProvider.notifier);
    if (ref.read(syncCoordinatorProvider).memos.running) {
      if (mounted) {
        showTopToast(
          initialContext,
          initialContext.t.strings.legacy.msg_syncing,
        );
      }
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (mounted &&
          ref.read(syncCoordinatorProvider).memos.running &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
      if (!context.mounted) return;
      final inFlightStatus = ref.read(syncCoordinatorProvider).memos;
      if (!inFlightStatus.running) {
        _showRefreshSyncFeedback(succeeded: inFlightStatus.lastError == null);
      }
      return;
    }
    if (scanner != null) {
      try {
        await scanner.scanAndMergeIncremental(forceDisk: false);
        _localLibraryCoordinator.markAutoScanTriggered();
      } catch (error) {
        if (!context.mounted) return;
        _showRefreshScanFailure(error);
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
    _showRefreshSyncFeedback(succeeded: syncStatus.lastError == null);
    if (useShortcutFilter && shortcutQuery != null) {
      ref.invalidate(shortcutMemosProvider(shortcutQuery));
    } else if (useQuickSearch && quickSearchQuery != null) {
      ref.invalidate(quickSearchMemosProvider(quickSearchQuery));
    } else if (useAiSearch && aiSearchQuery != null) {
      ref.invalidate(aiSearchMemosProvider(aiSearchQuery));
    }
  }

  void _showRefreshSyncFeedback({required bool succeeded}) {
    final language = ref.read(
      devicePreferencesProvider.select((p) => p.language),
    );
    showSyncFeedback(
      overlayContext: context,
      messengerContext: context,
      language: language,
      succeeded: succeeded,
    );
  }

  void _showRefreshScanFailure(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t.strings.legacy.msg_scan_failed(e: error)),
      ),
    );
  }

  Map<String, Object?> _buildQueryTransitionLogContext({
    required String fromKey,
    required String toKey,
  }) {
    return <String, Object?>{
      'fromQueryKeyFingerprint': _redactQueryKeyForLogging(fromKey),
      'toQueryKeyFingerprint': _redactQueryKeyForLogging(toKey),
    };
  }

  String _redactQueryKeyForLogging(String queryKey) {
    final trimmed = queryKey.trim();
    if (trimmed.isEmpty) return '';
    return LogSanitizer.redactOpaque(trimmed, kind: 'memos_query_key');
  }

  void _removeMemoWithAnimation(LocalMemo memo) {
    if (_audioPlaybackCoordinator.playingMemoUid == memo.uid) {
      unawaited(
        _audioPlaybackCoordinator.stopActivePlayback(memoUid: memo.uid),
      );
    }
    final outboxStatus =
        ref.read(memosListOutboxStatusProvider).valueOrNull ??
        const OutboxMemoStatus.empty();
    final prefs = ref
        .read(resolvedAppSettingsProvider)
        .toLegacyAppPreferences();
    final tagColors = ref.read(tagColorLookupProvider);
    ref
        .read(logManagerProvider)
        .info(
          'Memo delete animation start',
          context: <String, Object?>{
            ...buildMemoContentDiagnostics(memo.content, memoUid: memo.uid),
            'attachmentCount': memo.attachments.length,
            'attachmentImageCount': memo.attachments
                .where((attachment) => attachment.type.startsWith('image/'))
                .length,
            'attachmentVideoCount': memo.attachments
                .where((attachment) => attachment.type.startsWith('video/'))
                .length,
            'attachmentAudioCount': memo.attachments
                .where((attachment) => attachment.type.startsWith('audio/'))
                .length,
            'isWindows': Platform.isWindows,
            'searching': _searching,
            'desktopHeaderSearchExpanded': _desktopHeaderSearchExpanded,
          },
        );
    _animatedListController.removeMemoWithAnimation(
      memo,
      animationsEnabled: AppMotion.isEnabled(context),
      builder: (context, animation) => MemosListAnimatedMemoItem(
        memoCardKey: GlobalKey<MemoListCardState>(
          debugLabel: 'removing-${memo.uid}',
        ),
        memo: memo,
        heroTag: null,
        selected: false,
        animation: animation,
        prefs: prefs,
        outboxStatus: outboxStatus,
        removing: true,
        tagColors: tagColors,
        searching: _searching,
        windowsHeaderSearchExpanded: _desktopHeaderSearchExpanded,
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
        onSyncStatusTap: (status) => unawaited(
          _memoActionDelegate.handleMemoSyncStatusTap(status, memo.uid),
        ),
        onToggleTask: (index) => unawaited(
          _memoActionDelegate.toggleMemoCheckbox(
            memo,
            index,
            skipQuotedLines: prefs.collapseReferences,
          ),
        ),
        onTap: () {},
        onDoubleTapEdit: () {},
        onLongPressCopy: () =>
            _markSceneGuideSeen(SceneMicroGuideId.memoListGestures),
        onFloatingGeometryChanged: (geometry) {
          if (!mounted) return;
          _recordScrollPerfFloatingGeometryChange(removed: geometry == null);
          if (geometry == null) {
            _floatingCollapseController.removeGeometry(memo.uid);
            return;
          }
          _floatingCollapseController.upsertGeometry(memo.uid, geometry);
        },
        onAction: (action) =>
            unawaited(_memoActionDelegate.handleMemoAction(memo, action)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _composeDraftRepository = ref.watch(composeDraftRepositoryProvider);
    _noteDraftController = ref.watch(noteDraftProvider.notifier);
    _noteDraftRepository = ref.watch(noteDraftRepositoryProvider);
    final userSettings = ref.watch(userGeneralSettingProvider).valueOrNull;
    _inlineComposeDefaultVisibility = _inlineComposeCoordinator
        .normalizeVisibility(userSettings?.memoVisibility ?? 'PRIVATE');
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
      aiSearchActive: _aiSearchActive,
      resolvedTag: _activeTagFilter,
      advancedFilters: _advancedSearchFilters,
      sortOrder: _headerController.querySortOrder,
      searching: _searching,
      showDrawer: widget.showDrawer,
    );
    final layoutState = buildMemosListScreenLayoutState(
      query: queryState,
      desktopPresentation: _resolveCurrentMemosListDesktopPresentation(
        screenWidth: screenWidth,
      ),
      state: widget.state,
      showDrawer: widget.showDrawer,
      showPillActions: widget.showPillActions,
      showFilterTagChip: widget.showFilterTagChip,
      enableCompose: widget.enableCompose,
      hidePrimaryComposeFab: widget.hidePrimaryComposeFab,
      searching: _searching,
    );
    final resolvedTag = queryState.resolvedTag;
    final useShortcutFilter = queryState.useShortcutFilter;
    final useQuickSearch = queryState.useQuickSearch;
    final useAiSearch = queryState.useAiSearch;
    final useRemoteSearch = queryState.useRemoteSearch;
    final shortcutFilter = queryState.shortcutFilter;
    final selectedQuickSearchKind = queryState.selectedQuickSearchKind;
    final shortcutQuery = queryState.shortcutQuery;
    final quickSearchQuery = queryState.quickSearchQuery;
    final aiSearchQuery = queryState.aiSearchQuery;
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
                ..._buildQueryTransitionLogContext(
                  fromKey: previousQueryKey,
                  toKey: queryKey,
                ),
              },
            );
      }
      _logPaginationDebug(
        'query_key_changed_reset_pagination',
        context: _buildQueryTransitionLogContext(
          fromKey: previousQueryKey,
          toKey: queryKey,
        ),
      );
    }

    final memosAsync = switch (queryState.sourceKind) {
      MemosListMemoSourceKind.shortcut => ref.watch(
        shortcutMemosProvider(shortcutQuery!),
      ),
      MemosListMemoSourceKind.quickSearch => ref.watch(
        quickSearchMemosProvider(quickSearchQuery!),
      ),
      MemosListMemoSourceKind.aiSearch => ref.watch(
        aiSearchMemosProvider(aiSearchQuery!),
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
      currentWorkspacePreferencesProvider.select(
        (p) => p.memoToolbarPreferences,
      ),
    );
    final inlineVisibility = _inlineComposeCoordinator.currentVisibility();
    final inlineVisibilityPresentation = _inlineComposeUiController
        .resolveInlineVisibilityPresentation(context, inlineVisibility);
    final memosValue = memosAsync.valueOrNull;
    final memosLoading = memosAsync.isLoading;
    final memosError = memosAsync.whenOrNull(error: (error, _) => error);
    final normalMemoCount =
        ref.watch(memosListNormalMemoCountProvider).valueOrNull ?? 0;
    final currentLocalLibrary = ref.watch(currentLocalLibraryProvider);
    final bootstrapImportedCount =
        _localLibraryCoordinator.bootstrapImportTotal > 0
        ? normalMemoCount
              .clamp(0, _localLibraryCoordinator.bootstrapImportTotal)
              .toInt()
        : normalMemoCount;
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
    if (hasProviderValue &&
        _currentResultCount != previousCount &&
        wasLoadingMore) {
      _logPaginationDebug(
        'load_more_applied',
        metrics: _currentScrollMetricsForLogging(),
        context: <String, Object?>{
          'requestId': requestId,
          'source': requestSource,
          'previousCount': previousCount,
          'nextCount': _currentResultCount,
          'delta': _currentResultCount - previousCount,
        },
      );
    }

    final shouldMaybeAutoScan =
        !memosLoading &&
        !useRemoteSearch &&
        !useShortcutFilter &&
        !useQuickSearch &&
        !useAiSearch &&
        widget.state == 'NORMAL' &&
        searchQuery.trim().isEmpty &&
        (resolvedTag == null || resolvedTag.trim().isEmpty) &&
        filterDay == null &&
        (memosValue == null || memosValue.isEmpty);
    if (shouldMaybeAutoScan) {
      unawaited(
        _localLibraryCoordinator.maybeAutoScan(
          hasCurrentLibrary: currentLocalLibrary != null,
          normalMemoCount: normalMemoCount,
          syncRunning: syncState.running,
        ),
      );
    }

    if (memosValue != null) {
      final sortedMemos = queryState.enableHomeSort
          ? _headerController.applyHomeSort(memosValue)
          : memosValue;
      final listSignature =
          '${widget.state}|${resolvedTag ?? ''}|${searchQuery.trim()}|${shortcutFilter.trim()}|'
          '${useShortcutFilter ? 1 : 0}|${selectedQuickSearchKind?.name ?? ''}|'
          '${useQuickSearch ? 1 : 0}|${useAiSearch ? 1 : 0}|${queryState.startTimeSec ?? ''}|${queryState.endTimeSecExclusive ?? ''}|'
          '${queryState.enableHomeSort ? _sortOption.name : 'default'}|'
          '${queryState.advancedFilters.signature}';
      _animatedListController.syncAnimatedMemos(
        sortedMemos,
        listSignature,
        animationsEnabled: AppMotion.isEnabled(context),
        logEvent: (event, context) => _logPaginationDebug(
          event,
          metrics: _currentScrollMetricsForLogging(),
          context: context,
        ),
        logVisibleDecrease:
            ({
              required beforeLength,
              required afterLength,
              required signatureChanged,
              required listChanged,
              required fromSignature,
              required toSignature,
              required removedSample,
            }) {
              _diagnostics.logVisibleCountDecrease(
                beforeLength: beforeLength,
                afterLength: afterLength,
                signatureChanged: signatureChanged,
                listChanged: listChanged,
                fromSignature: fromSignature,
                toSignature: toSignature,
                removedSample: removedSample,
              );
            },
        metrics: _currentScrollMetricsForLogging(),
        schedulePostFrame: (callback) {
          WidgetsBinding.instance.addPostFrameCallback((_) => callback());
        },
      );
    }

    final visibleMemos = _animatedMemos;
    _scrollPerfSession?.recordBuild(visibleMemos.length);
    _animatedListController.syncMemoCardKeys(visibleMemos);
    _scheduleFloatingCollapseVisibleMemoPrune(visibleMemos);

    final devicePrefs = ref.watch(devicePreferencesProvider);
    final desktopHomePaneState = ref.watch(desktopHomePaneStateProvider);
    final previewSession = ref.watch(desktopMemoPreviewSessionProvider);
    final desktopHomeLayoutPreference = devicePrefs.desktopHomeLayoutPreference;
    final resolvedSettings = ref.watch(resolvedAppSettingsProvider);
    final prefs = resolvedSettings.toLegacyAppPreferences();
    final workspacePrefs = ref.watch(currentWorkspacePreferencesProvider);
    final hapticsEnabled = devicePrefs.hapticsEnabled;
    final screenshotModeEnabled = kDebugMode
        ? ref.watch(debugScreenshotModeProvider)
        : false;
    final session = ref.watch(appSessionProvider).valueOrNull;
    final hasAccount = session?.currentAccount != null;
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
    _inlineComposeKeyboardResumeVisible = viewState.layout.useInlineCompose;
    _inlineComposeKeyboardResumeController.updateKeyboardVisibility();
    _syncDesktopPreviewSelection(
      layout: viewState.layout,
      visibleMemos: visibleMemos,
    );
    final previewMemo = desktopHomePaneState.previewVisible
        ? _findMemoByUid(visibleMemos, desktopHomePaneState.selectedMemoUid)
        : null;
    final previewWarmupMemo =
        previewMemo ?? (visibleMemos.isNotEmpty ? visibleMemos.first : null);
    if (viewState.layout.supportsDesktopPreviewPane &&
        previewWarmupMemo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(desktopMemoPreviewSessionProvider.notifier)
            .prewarmMemo(previewWarmupMemo);
      });
    }
    if (viewState.layout.supportsDesktopPreviewPane &&
        desktopHomePaneState.previewVisible &&
        previewMemo != null) {
      final requestedMemo = previewSession.requestedMemo;
      final previewChanged =
          requestedMemo?.uid != previewMemo.uid ||
          requestedMemo?.contentFingerprint != previewMemo.contentFingerprint ||
          requestedMemo?.updateTime != previewMemo.updateTime;
      if (previewChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref
                .read(desktopMemoPreviewSessionProvider.notifier)
                .requestMemo(previewMemo),
          );
        });
      }
    }
    if (_enableResizableHomeInlineCompose &&
        viewState.layout.useInlineCompose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleViewportDerivedMetricsSync();
      });
    }
    final activeListGuideId = viewState.guide.activeListGuideId;
    if (_presentedListGuideId == null && activeListGuideId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _presentedListGuideId != null) return;
        _setStateWithDiagnostics(
          'scene_guide_presented',
          () => _presentedListGuideId = activeListGuideId,
        );
      });
    }

    _diagnostics.maybeLogMemosLoadingPhase(
      debugMode: kDebugMode,
      queryKey: queryKey,
      memosLoading: memosLoading,
      memosError: memosError,
      memosValue: memosValue,
      visibleMemos: visibleMemos,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      useAiSearch: useAiSearch,
      useRemoteSearch: useRemoteSearch,
      shortcutFilter: shortcutFilter,
      quickSearchKind: selectedQuickSearchKind,
      syncState: syncState,
      syncQueueSnapshot: syncQueueSnapshot,
      pageSize: _pageSize,
      reachedEnd: _reachedEnd,
      loadingMore: _loadingMore,
      providerLoading: _currentLoading,
      showSearchLanding: _currentShowSearchLanding,
    );
    _diagnostics.maybeLogEmptyViewDiagnostics(
      debugMode: kDebugMode,
      queryKey: queryKey,
      memosValue: memosValue,
      memosLoading: memosLoading,
      memosError: memosError,
      visibleMemos: visibleMemos,
      searchQuery: searchQuery,
      resolvedTag: resolvedTag,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      useAiSearch: useAiSearch,
      useRemoteSearch: useRemoteSearch,
      startTimeSec: queryState.startTimeSec,
      endTimeSecExclusive: queryState.endTimeSecExclusive,
      shortcutFilter: shortcutFilter,
      quickSearchKind: selectedQuickSearchKind,
    );
    if (kDebugMode) {
      final currentKey = session?.currentKey;
      final resolvedDb = (currentKey == null || currentKey.trim().isEmpty)
          ? null
          : databaseNameForAccountKey(currentKey);
      final workspaceMode = currentLocalLibrary != null
          ? 'local'
          : (session?.currentAccount != null ? 'remote' : 'none');
      _diagnostics.maybeLogWorkspaceDebug(
        debugMode: true,
        currentKey: currentKey,
        resolvedDbName: resolvedDb,
        workspaceMode: workspaceMode,
        currentLocalLibrary: currentLocalLibrary,
        localLibraryKey: currentLocalLibrary?.key,
        localLibraryName: currentLocalLibrary?.name,
        localLibraryLocation: currentLocalLibrary?.locationLabel,
      );
    }

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
    final debugApiVersionText = ref.watch(memosListDebugApiVersionTextProvider);
    final resolvedTagPath = (resolvedTag ?? '').trim();
    final desktopUtilityView = _supportsDesktopHomeUtilityEmbedding()
        ? _desktopHomeUtilityView
        : DesktopHomeUtilityView.none;
    final desktopUtilityActive =
        desktopUtilityView != DesktopHomeUtilityView.none;
    final selectedDrawerDestination = desktopUtilityActive
        ? null
        : (widget.state == 'ARCHIVED'
              ? AppDrawerDestination.archived
              : AppDrawerDestination.memos);
    final selectedDrawerTagPath =
        desktopUtilityActive || resolvedTagPath.isEmpty
        ? null
        : resolvedTagPath;
    final drawerPanel = widget.showDrawer
        ? AppDrawer(
            selected: selectedDrawerDestination,
            onSelect: _handleHomeDrawerDestination,
            onSelectTag: _openTagFromDrawer,
            onOpenNotifications: _handleHomeOpenNotifications,
            embedded: viewState.layout.useDesktopSidePane,
            selectedTagPath: selectedDrawerTagPath,
          )
        : null;
    final desktopDrawerPanelBuilder = widget.showDrawer
        ? (AppDrawerViewMode viewMode, bool embedded) => AppDrawer(
            selected: selectedDrawerDestination,
            onSelect: _handleHomeDrawerDestination,
            onSelectTag: _openTagFromDrawer,
            onOpenNotifications: _handleHomeOpenNotifications,
            embedded: embedded,
            viewMode: viewMode,
            selectedTagPath: selectedDrawerTagPath,
          )
        : null;

    void maybeHaptic() {
      if (!hapticsEnabled) return;
      HapticFeedback.selectionClick();
    }

    final resolvedQuickActions = resolveHomeQuickActions(
      rawPrimary: workspacePrefs.homeQuickActionPrimary,
      rawSecondary: workspacePrefs.homeQuickActionSecondary,
      rawTertiary: workspacePrefs.homeQuickActionTertiary,
      hasAccount: hasAccount,
    );
    final quickActions = [
      for (final action in resolvedQuickActions)
        if (action != HomeQuickAction.none)
          buildHomeQuickActionChipData(
            context: context,
            action: action,
            isDark: isDark,
            onPressed: () => _openHomeQuickAction(action),
          ),
    ];

    final titleChild = MemosListHeaderTitle(
      title: widget.title,
      enableTitleMenu: widget.enableTitleMenu,
      anchorKey: _routeDelegate.titleAnchorKey,
      onOpenTitleMenu: () => unawaited(_routeDelegate.openTitleMenu()),
      maybeHaptic: maybeHaptic,
    );
    final searchFieldChild = MemosListTopSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      isDark: isDark,
      autofocus:
          _searching &&
          !viewState.layout.desktopPresentation.usesDesktopHeaderSearch,
      hasAdvancedFilters: _hasAdvancedSearchFilters,
      onOpenAdvancedFilters: () => unawaited(_openAdvancedSearchSheet()),
      onSubmitted: (value) => _headerController.submitSearch(
        value,
        addHistory: ref.read(searchHistoryProvider.notifier).add,
      ),
      hintText: _desktopHeaderSearchExpanded
          ? context.t.strings.legacy.msg_quick_search
          : null,
    );
    final sortButton = viewState.query.enableHomeSort
        ? MemosListSortMenuButton(controller: _headerController, isDark: isDark)
        : null;
    final advancedFilterSliver = _hasAdvancedSearchFilters
        ? MemosListActiveAdvancedFilterSliver(
            chips: _headerController.buildActiveAdvancedSearchChipData(
              context,
              dayDateFormat: _dayDateFmt,
            ),
            onClearAll: _headerController.clearAdvancedSearchFilters,
            onRemoveSingle: _headerController.removeSingleAdvancedFilter,
          )
        : null;
    final resolvedTagChip =
        widget.showFilterTagChip && resolvedTagPath.isNotEmpty
        ? MemosListFilterTagChip(
            label: '#$resolvedTagPath',
            colors: tagColorLookup.resolveChipColorsByPath(
              resolvedTagPath,
              surfaceColor: Theme.of(context).colorScheme.surface,
              isDark: isDark,
            ),
            onClear: widget.showTagFilters
                ? () => _headerController.selectTagFilter(null)
                : (widget.showDrawer
                      ? _routeDelegate.backToAllMemos
                      : () => Navigator.of(context).maybePop()),
          )
        : null;
    final tagFilterBarChild =
        widget.showTagFilters &&
            !_searching &&
            viewState.recommendedTags.isNotEmpty
        ? MemosListTagFilterBar(
            tags: viewState.recommendedTags
                .take(12)
                .map((e) => e.tag)
                .toList(growable: false),
            selectedTag: resolvedTag,
            onSelectTag: _headerController.selectTagFilter,
            tagColors: tagColorLookup,
          )
        : null;
    final devicePreferencesLoaded = ref.watch(devicePreferencesLoadedProvider);
    final shouldEnableResizableHomeInlineCompose =
        _enableResizableHomeInlineCompose &&
        viewState.layout.useInlineCompose &&
        viewState
            .layout
            .desktopPresentation
            .inlineComposeCapability
            .supportsResize;
    final supportsDesktopSecondaryPane =
        viewState.layout.supportsDesktopPreviewPane;
    final enableDesktopPreviewInteraction =
        supportsDesktopSecondaryPane &&
        (viewState.layout.useDesktopPreviewPane ||
            desktopHomePaneState.secondaryPaneMode !=
                DesktopHomeSecondaryPaneMode.none);
    Widget buildInlineComposeCard({
      double? desktopEditorViewportHeight,
      ValueChanged<InlineComposeLayoutMetrics>? onLayoutMetricsChanged,
    }) {
      return KeyedSubtree(
        key: _homeInlineComposeCardKey,
        child: MemosListInlineComposeCard(
          composer: _inlineComposer,
          focusNode: _inlineComposeFocusNode,
          pendingDraftCount: ref.watch(composeDraftCountProvider),
          busy: _inlineComposeBusy,
          locating: _inlineComposeCoordinator.locating,
          location: _inlineComposeCoordinator.location,
          visibility: inlineVisibility,
          visibilityTouched: _inlineComposeCoordinator.visibilityTouched,
          visibilityLabel: inlineVisibilityPresentation.label,
          visibilityIcon: inlineVisibilityPresentation.icon,
          visibilityColor: inlineVisibilityPresentation.color,
          isDark: isDark,
          tagStats: tagStats,
          availableTemplates: viewState.availableTemplates,
          tagColorLookup: tagColorLookup,
          toolbarPreferences: toolbarPreferences,
          editorFieldKey: _inlineEditorFieldKey,
          tagMenuKey: _inlineTagMenuKey,
          templateMenuKey: _inlineTemplateMenuKey,
          todoMenuKey: _inlineTodoMenuKey,
          visibilityMenuKey: _inlineVisibilityMenuKey,
          onSubmit: () => unawaited(_submitInlineCompose()),
          onRemoveAttachment: _inlineComposeCoordinator.removePendingAttachment,
          onOpenAttachment: (attachment) => unawaited(
            _inlineComposeCoordinator.openAttachmentViewer(context, attachment),
          ),
          onRemoveLinkedMemo: _inlineComposeCoordinator.removeLinkedMemo,
          onRequestLocation: () =>
              unawaited(_inlineComposeCoordinator.requestLocation(context)),
          onClearLocation: _inlineComposeCoordinator.clearLocation,
          onOpenTemplateMenu: () => unawaited(
            _inlineComposeCoordinator.openTemplateMenuFromKey(
              context,
              _inlineTemplateMenuKey,
              viewState.availableTemplates,
            ),
          ),
          onPickGallery: () => unawaited(
            _inlineComposeCoordinator.pickGalleryAttachments(context),
          ),
          onPickFile: () =>
              unawaited(_inlineComposeCoordinator.pickAttachments(context)),
          onOpenLinkMemo: () =>
              unawaited(_inlineComposeCoordinator.openLinkMemoSheet(context)),
          onCaptureCamera: () =>
              unawaited(_inlineComposeCoordinator.capturePhoto(context)),
          onOpenDraftBox: () => unawaited(_openInlineComposeDraftBox()),
          onOpenTodoMenu: () => unawaited(
            _inlineComposeCoordinator.openTodoShortcutMenuFromKey(
              context,
              _inlineTodoMenuKey,
            ),
          ),
          onOpenVisibilityMenu: () => unawaited(
            _inlineComposeCoordinator.openVisibilityMenuFromKey(
              context,
              _inlineVisibilityMenuKey,
            ),
          ),
          onCutParagraphs: () =>
              unawaited(_inlineComposeUiController.cutCurrentParagraphs()),
          desktopEditorViewportHeight: desktopEditorViewportHeight,
          onLayoutMetricsChanged: onLayoutMetricsChanged,
        ),
      );
    }

    final inlineComposeChild = viewState.layout.useInlineCompose
        ? (shouldEnableResizableHomeInlineCompose
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = math.max(
                      0.0,
                      constraints.maxWidth -
                          _homeInlineComposeHitZoneExtent * 2,
                    );
                    final measuredAvailableHeight = _homeInlineAvailableHeight;
                    final availableHeight = measuredAvailableHeight > 0
                        ? measuredAvailableHeight
                        : _effectiveHomeInlineAvailableHeight(context);
                    _primeHomeInlinePanelLayout(
                      devicePreferencesLoaded: devicePreferencesLoaded,
                      availableWidth: availableWidth,
                      availableHeight: availableHeight,
                      estimatedChromeHeight:
                          _estimateHomeInlinePanelChromeHeight(
                            toolbarPreferences,
                          ),
                    );
                    if (!_homeInlinePanelRestored &&
                        devicePreferencesLoaded &&
                        _homeInlinePanelMetricsReady &&
                        availableWidth > 0 &&
                        availableHeight > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _maybeRestoreHomeInlinePanelLayout(
                          availableWidth: availableWidth,
                          availableHeight: availableHeight,
                        );
                      });
                    }
                    final rect = _buildHomeInlinePanelRect(
                      availableWidth: availableWidth,
                      availableHeight: availableHeight,
                    );
                    if (rect == null) {
                      return buildInlineComposeCard(
                        onLayoutMetricsChanged: _handleHomeInlineLayoutMetrics,
                      );
                    }
                    final shellHeight =
                        rect.bottom + _homeInlineComposeHitZoneExtent;
                    final minWidth = math.min(
                      _homeInlineComposeMinWidth,
                      _resolveHomeInlineMaxWidth(availableWidth),
                    );
                    final minHeight =
                        _homeInlinePanelChromeHeight +
                        math.min(
                          _homeInlineComposeMinEditorHeight,
                          _resolveHomeInlineMaxEditorHeight(availableHeight),
                        );
                    final maxHeight =
                        _homeInlinePanelChromeHeight +
                        _resolveHomeInlineMaxEditorHeight(availableHeight);
                    return SizedBox(
                      height: shellHeight,
                      child: DesktopResizablePanelShell(
                        viewportSize: Size(
                          availableWidth + _homeInlineComposeHitZoneExtent * 2,
                          shellHeight,
                        ),
                        rect: rect,
                        minWidth: minWidth,
                        maxWidth: _resolveHomeInlineMaxWidth(availableWidth),
                        minHeight: minHeight,
                        maxHeight: maxHeight,
                        hitZoneExtent: _homeInlineComposeHitZoneExtent,
                        showHandleAffordance: true,
                        boundaryInsets: const EdgeInsets.symmetric(
                          horizontal: _homeInlineComposeViewportMargin,
                        ),
                        onChanged: (next) => _applyHomeInlinePanelRect(
                          next,
                          availableWidth: availableWidth,
                          availableHeight: availableHeight,
                        ),
                        onChangeEnd: (next) => _applyHomeInlinePanelRect(
                          next,
                          availableWidth: availableWidth,
                          availableHeight: availableHeight,
                          persist: true,
                        ),
                        child: buildInlineComposeCard(
                          desktopEditorViewportHeight:
                              _homeInlinePanelEditorHeight,
                          onLayoutMetricsChanged:
                              _handleHomeInlineLayoutMetrics,
                        ),
                      ),
                    );
                  },
                )
              : buildInlineComposeCard())
        : null;
    final inlineComposePadding = shouldEnableResizableHomeInlineCompose
        ? const EdgeInsets.only(top: 2)
        : const EdgeInsets.fromLTRB(16, 10, 16, 8);
    final searchLandingChild = MemosListSearchLanding(
      history: searchHistory,
      onClearHistory: () => ref.read(searchHistoryProvider.notifier).clear(),
      onRemoveHistory: (value) =>
          ref.read(searchHistoryProvider.notifier).remove(value),
      onSelectHistory: (query) => _headerController.applySearchQuery(
        query,
        addHistory: ref.read(searchHistoryProvider.notifier).add,
      ),
      tags: viewState.recommendedTags.map((e) => e.tag).toList(growable: false),
      tagColors: tagColorLookup,
      onSelectTag: (query) => _headerController.applySearchQuery(
        query,
        addHistory: ref.read(searchHistoryProvider.notifier).add,
      ),
    );
    final bootstrapOverlayChild = MemosListBootstrapImportOverlay(
      active: _localLibraryCoordinator.bootstrapImportActive,
      importedCount: bootstrapImportedCount,
      totalCount: _localLibraryCoordinator.bootstrapImportTotal,
      startedAt: _localLibraryCoordinator.bootstrapImportStartedAt,
      formatDuration: _formatDuration,
    );
    final enableVoiceFabLongPress = _isMobileNativePlatform();
    final floatingActionButton = viewState.layout.showComposeFab
        ? MemoFlowFab(
            onPressed: _routeDelegate.openNoteInput,
            onLongPressStart: enableVoiceFabLongPress
                ? _handleVoiceFabLongPressStart
                : null,
            onLongPressMoveUpdate: enableVoiceFabLongPress
                ? _handleVoiceFabLongPressMoveUpdate
                : null,
            onLongPressEnd: enableVoiceFabLongPress
                ? _handleVoiceFabLongPressEnd
                : null,
            hapticsEnabled: hapticsEnabled,
          )
        : null;
    final resolvedPreviewMemo = previewMemo;
    Widget? desktopPreviewPane;
    if (viewState.layout.supportsDesktopPreviewPane) {
      desktopPreviewPane = MemosListDesktopPreviewPane(
        selectedMemo: resolvedPreviewMemo,
        isVisible: desktopHomePaneState.previewVisible,
        onClose: _closeDesktopPreview,
        onEditMemo: () {
          final activeMemo =
              ref.read(desktopMemoPreviewSessionProvider).data?.memo ??
              resolvedPreviewMemo;
          if (activeMemo == null) return;
          unawaited(_openMemoEditor(activeMemo));
        },
      );
    }
    Widget? desktopEditorModalSurface;
    final composeTarget = desktopHomePaneState.composeDraftTarget;
    if (desktopHomePaneState.editorVisible) {
      final presentation = desktopHomePaneState.isEditorFullscreen
          ? MemoEditorPresentation.desktopFullscreen
          : MemoEditorPresentation.desktopModal;
      if (composeTarget is DesktopHomeComposeEditMemo) {
        final composeMemo = _findMemoByUid(visibleMemos, composeTarget.memoUid);
        if (composeMemo != null) {
          desktopEditorModalSurface = KeyedSubtree(
            key: ValueKey<String>(
              'desktop-memo-editor-surface:${composeMemo.uid}:$_composeTransitionKey',
            ),
            child: MemoEditorScreen(
              existing: composeMemo,
              presentation: presentation,
              onSaved: _handleDesktopComposeSaved,
              onCloseRequested: _closeDesktopCompose,
              onToggleFullscreen: _toggleDesktopComposeFullscreen,
            ),
          );
        }
      } else {
        desktopEditorModalSurface = KeyedSubtree(
          key: ValueKey<String>(
            'desktop-memo-editor-surface:new:$_composeTransitionKey',
          ),
          child: MemoEditorScreen(
            initialText: _desktopComposeInitialText,
            initialAttachmentPaths: _desktopComposeInitialAttachmentPaths,
            ignoreDraft: _desktopComposeIgnoreDraft,
            presentation: presentation,
            onSaved: _handleDesktopComposeSaved,
            onCloseRequested: _closeDesktopCompose,
            onToggleFullscreen: _toggleDesktopComposeFullscreen,
          ),
        );
      }
    }
    final desktopSecondaryPaneVisible =
        !desktopUtilityActive &&
        desktopHomePaneState.previewVisible &&
        desktopPreviewPane != null;
    final desktopPrimaryContentOverride = switch (desktopUtilityView) {
      DesktopHomeUtilityView.none => null,
      DesktopHomeUtilityView.syncQueue => SyncQueueScreen(
        presentation: HomeScreenPresentation.desktopEmbedded,
        onDesktopEmbeddedBack: _clearDesktopHomeUtilityView,
      ),
      DesktopHomeUtilityView.notifications => NotificationsScreen(
        presentation: HomeScreenPresentation.desktopEmbedded,
        onDesktopEmbeddedBack: _clearDesktopHomeUtilityView,
      ),
    };
    final desktopTrailingActions = <Widget>[
      if (!desktopUtilityActive && sortButton != null) sortButton,
      if (!desktopUtilityActive && supportsDesktopSecondaryPane)
        IconButton(
          key: const ValueKey<String>('desktop-preview-pane-toggle'),
          tooltip: context.t.strings.legacy.msg_preview,
          onPressed: _toggleDesktopSecondaryPane,
          icon: Icon(
            desktopSecondaryPaneVisible
                ? Icons.visibility
                : Icons.visibility_outlined,
          ),
        ),
      IconButton(
        tooltip: context.t.strings.legacy.msg_create_memo,
        onPressed: _routeDelegate.openNoteInput,
        icon: const Icon(Icons.add_rounded),
      ),
      IconButton(
        tooltip: context.t.strings.legacy.msg_notifications,
        onPressed: _routeDelegate.openNotifications,
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      IconButton(
        tooltip: context.t.strings.legacy.msg_settings,
        onPressed: () => unawaited(_routeDelegate.openSettings()),
        icon: const Icon(Icons.settings_outlined),
      ),
    ];

    final shouldInterceptPop =
        widget.presentation != HomeScreenPresentation.embeddedBottomNav ||
        _isAllMemos;

    return PopScope(
      canPop: !shouldInterceptPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !shouldInterceptPop) return;
        if (desktopUtilityActive) {
          _clearDesktopHomeUtilityView();
          return;
        }
        final shouldPop = await _routeDelegate.handleWillPop();
        if (!context.mounted) return;
        if (!shouldPop) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          if (Platform.isWindows) {
            await _routeDelegate.closeDesktopWindow();
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: MemosListScreenBody(
        scaffoldKey: _scaffoldKey,
        scrollController: _scrollController,
        floatingCollapseViewportKey: _floatingCollapseViewportKey,
        listKey: _listKey,
        data: MemosListScreenBodyData(
          viewState: viewState,
          searching: _searching,
          showFilterTagChip: widget.showFilterTagChip,
          enableSearch: widget.enableSearch,
          enableTitleMenu: widget.enableTitleMenu,
          screenshotModeEnabled: screenshotModeEnabled,
          desktopHeaderSearchExpanded: _desktopHeaderSearchExpanded,
          desktopWindowMaximized: _desktopWindowMaximized,
          debugApiVersionText: debugApiVersionText,
          activeListGuideId: activeListGuideId,
          activeListGuideMessage: activeListGuideMessage,
          memosLoading: memosLoading,
          memosError: memosError,
          visibleMemos: visibleMemos,
          showLoadMoreHint: showLoadMoreHint,
          loadMoreHintDisplayText: loadMoreHintDisplayText,
          loadMoreHintTextColor: loadMoreHintTextColor,
          headerBackgroundColor: headerBg,
          bottomInset: bottomInset,
          hapticsEnabled: hapticsEnabled,
          desktopPreviewVisible: desktopSecondaryPaneVisible,
          enableDrawerOpenDragGesture: widget.enableDrawerOpenDragGesture,
        ),
        drawerPanel: drawerPanel,
        titleChild: titleChild,
        searchFieldChild: searchFieldChild,
        sortButton: sortButton,
        resolvedTagChip: resolvedTagChip,
        advancedFilterSliver: advancedFilterSliver,
        inlineComposeChild: inlineComposeChild,
        inlineComposePadding: inlineComposePadding,
        expandDesktopBodyWidth: shouldEnableResizableHomeInlineCompose,
        tagFilterBarChild: tagFilterBarChild,
        searchLandingChild: searchLandingChild,
        bootstrapOverlayChild: _localLibraryCoordinator.bootstrapImportActive
            ? bootstrapOverlayChild
            : null,
        desktopPrimaryContentOverride: desktopPrimaryContentOverride,
        desktopPreviewPane: desktopPreviewPane,
        desktopEditorModalSurface: desktopEditorModalSurface,
        desktopEditorModalVisible:
            desktopHomePaneState.editorVisible &&
            desktopEditorModalSurface != null,
        desktopPreviewPaneWidth: desktopHomeLayoutPreference.secondaryPaneWidth,
        onDesktopPreviewPaneWidthChanged: _setDesktopPreviewPaneWidthPreference,
        floatingActionButton: floatingActionButton,
        onRefresh: () => _handleRefresh(
          useShortcutFilter: useShortcutFilter,
          useQuickSearch: useQuickSearch,
          useAiSearch: useAiSearch,
          shortcutQuery: shortcutQuery,
          quickSearchQuery: quickSearchQuery,
          aiSearchQuery: aiSearchQuery,
        ),
        onScrollNotification: _handleViewportScrollNotification,
        onPointerSignal: _handleViewportPointerSignal,
        showBackToTopListenable: _viewportCoordinator.showBackToTopListenable,
        floatingCollapseListenable: _floatingCollapseController,
        onCloseSearch: _closeSearch,
        onOpenSearch: _openSearch,
        onToggleDesktopHeaderSearch: _toggleDesktopHeaderSearch,
        onToggleQuickSearchKind: _headerController.toggleQuickSearchKind,
        onStartAiSearch: _startAiSearch,
        onStopAiSearch: _stopAiSearch,
        onDismissGuide: () {
          if (activeListGuideId == null) return;
          _markSceneGuideSeen(activeListGuideId);
        },
        onViewportLayoutChanged: _scheduleViewportDerivedMetricsSync,
        onCollapseFloatingMemo: _collapseActiveMemoFromFloatingButton,
        onScrollToTop: () => unawaited(_handleScrollToTop()),
        quickActions: quickActions,
        desktopDrawerPanelBuilder: desktopDrawerPanelBuilder,
        desktopTrailingActions: desktopTrailingActions,
        onMinimize: () => unawaited(_routeDelegate.minimizeDesktopWindow()),
        onToggleMaximize: () =>
            unawaited(_routeDelegate.toggleDesktopWindowMaximize()),
        onClose: () => unawaited(_routeDelegate.closeDesktopWindow()),
        onEditTag: () async {
          if (viewState.activeTagStat == null) return;
          await TagEditSheet.showEditorDialog(
            context,
            tag: viewState.activeTagStat,
          );
        },
        animatedItemBuilder: (context, index, animation) {
          final memo = visibleMemos[index];
          final heroTag = memoHeroTagForMemo(memo);
          return MemosListAnimatedMemoItem(
            memoCardKey: _animatedListController.keyFor(memo.uid),
            memo: memo,
            heroTag: heroTag,
            selected: desktopHomePaneState.selectedMemoUid == memo.uid,
            animation: animation,
            prefs: prefs,
            outboxStatus: outboxStatus,
            removing: false,
            tagColors: tagColorLookup,
            searching: _searching,
            windowsHeaderSearchExpanded: _desktopHeaderSearchExpanded,
            selectedQuickSearchKind: _selectedQuickSearchKind,
            searchQuery: _searchController.text,
            playingMemoUid: _audioPlaybackCoordinator.playingMemoUid,
            audioPlaying: _audioPlaybackCoordinator.audioPlaying,
            audioLoading: _audioPlaybackCoordinator.audioLoading,
            audioPositionListenable:
                _audioPlaybackCoordinator.positionListenable,
            audioDurationListenable:
                _audioPlaybackCoordinator.durationListenable,
            onAudioSeek: (pos) =>
                unawaited(_audioPlaybackCoordinator.seek(memo, pos)),
            onAudioTap: () => unawaited(_handleMemoAudioTap(memo)),
            onSyncStatusTap: (status) => unawaited(
              _memoActionDelegate.handleMemoSyncStatusTap(status, memo.uid),
            ),
            onToggleTask: (index) => unawaited(
              _memoActionDelegate.toggleMemoCheckbox(
                memo,
                index,
                skipQuotedLines: prefs.collapseReferences,
              ),
            ),
            onTap: () {
              if (enableDesktopPreviewInteraction) {
                _handleDesktopPreviewTap(memo);
                return;
              }
              if (prefs.hapticsEnabled) {
                HapticFeedback.selectionClick();
              }
              _openMemoDetailRoute(memo, heroTag: heroTag);
            },
            onTapDown: enableDesktopPreviewInteraction
                ? (_) {
                    if (prefs.hapticsEnabled) {
                      HapticFeedback.selectionClick();
                    }
                    _handleDesktopPreviewTapDown(memo);
                  }
                : null,
            onTapUp: enableDesktopPreviewInteraction
                ? (_) => _handleDesktopPreviewTapUp(memo)
                : null,
            onTapCancel: enableDesktopPreviewInteraction
                ? _handleDesktopPreviewTapCancel
                : null,
            onDoubleTapEdit: () {
              _markSceneGuideSeen(SceneMicroGuideId.memoListGestures);
              if (enableDesktopPreviewInteraction) {
                _openMemoDetailRoute(memo, heroTag: heroTag);
                return;
              }
              unawaited(
                _memoActionDelegate.handleMemoAction(memo, MemoCardAction.edit),
              );
            },
            onLongPressCopy: _isDesktopContextMenuTarget
                ? null
                : () {
                    _markSceneGuideSeen(SceneMicroGuideId.memoListGestures);
                  },
            onSecondaryTapDown: _isDesktopContextMenuTarget
                ? (details) => unawaited(
                    _showMemoContextMenu(
                      memo,
                      details.globalPosition,
                      showPreviewOnSelect:
                          enableDesktopPreviewInteraction &&
                          desktopHomePaneState.previewVisible,
                    ),
                  )
                : null,
            onFloatingGeometryChanged: (geometry) {
              if (!mounted) return;
              _recordScrollPerfFloatingGeometryChange(
                removed: geometry == null,
              );
              if (geometry == null) {
                _floatingCollapseController.removeGeometry(memo.uid);
                return;
              }
              _floatingCollapseController.upsertGeometry(memo.uid, geometry);
            },
            onAction: (action) =>
                unawaited(_memoActionDelegate.handleMemoAction(memo, action)),
          );
        },
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

class _MemosScrollPerfSession {
  _MemosScrollPerfSession({
    required this.startedAt,
    required double initialPixels,
  }) : startPixels = initialPixels,
       lastPixels = initialPixels,
       endPixels = initialPixels;

  final DateTime startedAt;
  final double startPixels;
  double lastPixels;
  double endPixels;
  double absoluteScrollDistance = 0;
  double maxTickDelta = 0;
  double totalWheelDeltaAbs = 0;
  int pointerSignalCount = 0;
  int scrollListenerTickCount = 0;
  int scrollNotificationCount = 0;
  int viewportDerivedSyncScheduleCount = 0;
  int viewportDerivedSyncApplyCount = 0;
  int rootBuildCount = 0;
  int maxVisibleMemoCount = 0;
  int floatingGeometryUpsertCount = 0;
  int floatingGeometryRemoveCount = 0;
  int floatingStateChangeCount = 0;
  int floatingMemoSwitchCount = 0;
  int floatingScrollingToggleCount = 0;
  int showBackToTopToggleCount = 0;
  int frameCount = 0;
  int buildOver8MsCount = 0;
  int rasterOver8MsCount = 0;
  int frameOver16MsCount = 0;
  int frameOver33MsCount = 0;
  double worstFrameTotalMs = 0;
  double worstBuildMs = 0;
  double worstRasterMs = 0;
  final Map<String, int> activityCounts = <String, int>{};
  final Map<String, int> scrollNotificationKindCounts = <String, int>{};
  final Map<String, int> stateTriggerCounts = <String, int>{};

  bool get hasMeaningfulData =>
      pointerSignalCount > 0 ||
      scrollListenerTickCount > 0 ||
      scrollNotificationCount > 0 ||
      frameCount > 0;

  void recordActivity(String source, {double? pixels}) {
    activityCounts[source] = (activityCounts[source] ?? 0) + 1;
    if (pixels != null) {
      updatePixels(pixels);
    }
  }

  void updatePixels(double pixels) {
    final delta = (pixels - lastPixels).abs();
    if (delta > 0) {
      absoluteScrollDistance += delta;
      if (delta > maxTickDelta) {
        maxTickDelta = delta;
      }
    }
    lastPixels = pixels;
    endPixels = pixels;
  }

  void recordPointerSignal(double deltaY, {double? pixels}) {
    pointerSignalCount += 1;
    totalWheelDeltaAbs += deltaY.abs();
    if (pixels != null) {
      updatePixels(pixels);
    }
  }

  void recordScrollListenerTick({double? pixels}) {
    scrollListenerTickCount += 1;
    if (pixels != null) {
      updatePixels(pixels);
    }
  }

  void recordScrollNotification(String kind, {double? pixels}) {
    scrollNotificationCount += 1;
    scrollNotificationKindCounts[kind] =
        (scrollNotificationKindCounts[kind] ?? 0) + 1;
    if (pixels != null) {
      updatePixels(pixels);
    }
  }

  void recordStateTrigger(String source) {
    stateTriggerCounts[source] = (stateTriggerCounts[source] ?? 0) + 1;
  }

  void recordBuild(int visibleMemoCount) {
    rootBuildCount += 1;
    if (visibleMemoCount > maxVisibleMemoCount) {
      maxVisibleMemoCount = visibleMemoCount;
    }
  }

  void recordFrameTiming(FrameTiming timing) {
    frameCount += 1;
    final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
    final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
    final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
    if (buildMs > 8) {
      buildOver8MsCount += 1;
    }
    if (rasterMs > 8) {
      rasterOver8MsCount += 1;
    }
    if (totalMs > 16) {
      frameOver16MsCount += 1;
    }
    if (totalMs > 33) {
      frameOver33MsCount += 1;
    }
    if (totalMs > worstFrameTotalMs) {
      worstFrameTotalMs = totalMs;
    }
    if (buildMs > worstBuildMs) {
      worstBuildMs = buildMs;
    }
    if (rasterMs > worstRasterMs) {
      worstRasterMs = rasterMs;
    }
  }

  Map<String, Object?> toContext({required String reason}) {
    return <String, Object?>{
      'reason': reason,
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'startPixels': startPixels,
      'endPixels': endPixels,
      'absoluteScrollDistance': absoluteScrollDistance,
      'maxTickDelta': maxTickDelta,
      'pointerSignalCount': pointerSignalCount,
      'totalWheelDeltaAbs': totalWheelDeltaAbs,
      'scrollListenerTickCount': scrollListenerTickCount,
      'scrollNotificationCount': scrollNotificationCount,
      if (activityCounts.isNotEmpty) 'activityCounts': activityCounts,
      if (scrollNotificationKindCounts.isNotEmpty)
        'scrollNotificationKinds': scrollNotificationKindCounts,
      'rootBuildCount': rootBuildCount,
      'maxVisibleMemoCount': maxVisibleMemoCount,
      if (stateTriggerCounts.isNotEmpty)
        'stateTriggerCounts': stateTriggerCounts,
      'viewportDerivedSyncScheduleCount': viewportDerivedSyncScheduleCount,
      'viewportDerivedSyncApplyCount': viewportDerivedSyncApplyCount,
      'floatingGeometryUpsertCount': floatingGeometryUpsertCount,
      'floatingGeometryRemoveCount': floatingGeometryRemoveCount,
      'floatingStateChangeCount': floatingStateChangeCount,
      'floatingMemoSwitchCount': floatingMemoSwitchCount,
      'floatingScrollingToggleCount': floatingScrollingToggleCount,
      'showBackToTopToggleCount': showBackToTopToggleCount,
      'frameCount': frameCount,
      'buildOver8MsCount': buildOver8MsCount,
      'rasterOver8MsCount': rasterOver8MsCount,
      'frameOver16MsCount': frameOver16MsCount,
      'frameOver33MsCount': frameOver33MsCount,
      'worstFrameTotalMs': worstFrameTotalMs,
      'worstBuildMs': worstBuildMs,
      'worstRasterMs': worstRasterMs,
    };
  }
}

class _ScreenLocalLibraryPromptDelegate
    implements MemosListLocalLibraryPromptDelegate {
  const _ScreenLocalLibraryPromptDelegate({
    required Future<bool> Function() confirmManualScan,
    required Future<bool> Function(LocalScanConflict conflict) resolveConflict,
    required VoidCallback showSyncBusy,
    required VoidCallback showScanSuccess,
    required void Function(Object error) showScanFailure,
  }) : _confirmManualScan = confirmManualScan,
       _resolveConflict = resolveConflict,
       _showSyncBusy = showSyncBusy,
       _showScanSuccess = showScanSuccess,
       _showScanFailure = showScanFailure;

  final Future<bool> Function() _confirmManualScan;
  final Future<bool> Function(LocalScanConflict conflict) _resolveConflict;
  final VoidCallback _showSyncBusy;
  final VoidCallback _showScanSuccess;
  final void Function(Object error) _showScanFailure;

  @override
  Future<bool> confirmManualScan() => _confirmManualScan();

  @override
  Future<bool> resolveConflict(LocalScanConflict conflict) =>
      _resolveConflict(conflict);

  @override
  void showSyncBusy() => _showSyncBusy();

  @override
  void showScanSuccess() => _showScanSuccess();

  @override
  void showScanFailure(Object error) => _showScanFailure(error);
}
