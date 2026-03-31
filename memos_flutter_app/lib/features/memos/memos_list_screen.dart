import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../application/desktop/desktop_tray_controller.dart';
import '../../application/sync/sync_feedback_presenter.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_localization.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/drawer_navigation.dart';
import '../../core/log_sanitizer.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/top_toast.dart';
import '../../data/models/compose_draft.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/shortcut.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../state/attachments/queued_attachment_stager_provider.dart';
import '../../state/memos/memo_composer_controller.dart';
import '../../state/memos/memo_composer_state.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/memos/note_draft_provider.dart';
import '../../state/memos/search_history_provider.dart';
import '../../state/settings/app_lock_provider.dart';
import '../../state/settings/memo_template_settings_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/settings/user_settings_provider.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/system/debug_screenshot_mode_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/local_library_scanner.dart';
import '../../state/system/logging_provider.dart';
import '../../state/system/scene_micro_guide_provider.dart';
import '../../state/system/session_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../home/app_drawer.dart';
import '../reminders/memo_reminder_editor_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tag_edit_sheet.dart';
import '../voice/voice_record_screen.dart';
import 'advanced_search_sheet.dart';
import 'draft_box_screen.dart';
import 'memo_detail_screen.dart';
import 'memo_editor_screen.dart';
import 'memo_markdown.dart';
import 'memo_versions_screen.dart';
import 'memos_list_animated_list_controller.dart';
import 'memos_list_audio_playback_coordinator.dart';
import 'memos_list_desktop_shortcut_delegate.dart';
import 'memos_list_diagnostics.dart';
import 'memos_list_header_controller.dart';
import 'memos_list_inline_compose_coordinator.dart';
import 'memos_list_inline_compose_ui_controller.dart';
import 'memos_list_local_library_coordinator.dart';
import 'memos_list_memo_action_delegate.dart';
import 'memos_list_mutation_coordinator.dart';
import 'memos_list_route_delegate.dart';
import 'memos_list_screen_view_state.dart';
import 'memos_list_viewport_coordinator.dart';
import 'widgets/memos_list_animated_memo_item.dart';
import 'widgets/memos_list_bootstrap_import_overlay.dart';
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

  @override
  ConsumerState<MemosListScreen> createState() => _MemosListScreenState();
}

class _MemosListScreenState extends ConsumerState<MemosListScreen>
    with WindowListener {
  static const int _initialPageSize = 200;
  static const int _pageStep = 200;

  final DateFormat _dayDateFmt = DateFormat('yyyy-MM-dd');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _floatingCollapseViewportKey = GlobalKey();
  final FocusNode _inlineComposeFocusNode = FocusNode();
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
  late final MemosListRouteDelegate _routeDelegate;
  late final MemosListMemoActionDelegate _memoActionDelegate;
  late final MemosListAnimatedListController _animatedListController;
  late final MemosListDiagnostics _diagnostics;

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

  TextEditingController get _searchController =>
      _headerController.searchController;
  FocusNode get _searchFocusNode => _headerController.searchFocusNode;
  bool get _searching => _headerController.searching;
  String? get _selectedShortcutId => _headerController.selectedShortcutId;
  QuickSearchKind? get _selectedQuickSearchKind =>
      _headerController.selectedQuickSearchKind;
  AdvancedSearchFilters get _advancedSearchFilters =>
      _headerController.advancedSearchFilters;
  String? get _activeTagFilter => _headerController.activeTagFilter;
  bool get _hasAdvancedSearchFilters =>
      _headerController.hasAdvancedSearchFilters;
  bool get _windowsHeaderSearchExpanded =>
      _headerController.windowsHeaderSearchExpanded;
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
  bool get _showBackToTop => _viewportCoordinator.showBackToTop;
  bool get _floatingCollapseScrolling =>
      _viewportCoordinator.floatingCollapseScrolling;
  String? get _floatingCollapseMemoUid =>
      _viewportCoordinator.floatingCollapseMemoUid;
  bool get _scrollToTopAnimating => _viewportCoordinator.scrollToTopAnimating;
  GlobalKey<SliverAnimatedListState> get _listKey =>
      _animatedListController.listKey;
  List<LocalMemo> get _animatedMemos => _animatedListController.animatedMemos;
  bool get _desktopWindowMaximized => _routeDelegate.desktopWindowMaximized;

  bool get _isAllMemos {
    final tag = _activeTagFilter;
    return widget.state == 'NORMAL' && (tag == null || tag.isEmpty);
  }

  @override
  void initState() {
    super.initState();
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
      buildArchivedScreen: _buildArchivedScreen,
      invalidateShortcuts: () => ref.invalidate(shortcutsProvider),
      submitDesktopQuickInput: _submitDesktopQuickInput,
      scrollToTop: _handleScrollToTop,
      focusInlineCompose: _inlineComposeFocusNode.requestFocus,
      shouldUseInlineComposeForCurrentWindow:
          _shouldUseInlineComposeForCurrentWindow,
      enableCompose: () => widget.enableCompose,
      searching: () => _searching,
      windowsHeaderSearchExpanded: () => _windowsHeaderSearchExpanded,
      closeSearch: _closeSearch,
      closeWindowsHeaderSearch: _closeWindowsHeaderSearch,
      maybeScanLocalLibrary: _maybeScanLocalLibrary,
      isAllMemos: () => _isAllMemos,
      showDrawer: () => widget.showDrawer,
      dayFilter: () => widget.dayFilter,
      selectedShortcutIdResolver: () => _selectedShortcutId,
      selectShortcutId: (shortcutId) =>
          _headerController.selectShortcut(shortcutId),
      markSceneGuideSeen: _markSceneGuideSeen,
      showNoteInputSheet: widget.showNoteInputSheet,
      showVoiceRecordOverlay: widget.showVoiceRecordOverlay,
    );
    _memoActionDelegate = MemosListMemoActionDelegate(
      contextResolver: () => context,
      mutationCoordinator: _mutationCoordinator,
      onRetryOpenSyncQueue: (_) async => _routeDelegate.openSyncQueue(),
      confirmDelete: _confirmDeleteMemo,
      removeMemoWithAnimation: _removeMemoWithAnimation,
      invalidateMemoRenderCache: invalidateMemoRenderCacheForUid,
      invalidateMemoMarkdownCache: invalidateMemoMarkdownCacheForUid,
      openEditor: _openMemoEditor,
      openHistory: _openMemoHistory,
      openReminder: _openMemoReminder,
      handleRestoreSuccess: (toastMessage) async {
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
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
    _diagnostics = MemosListDiagnostics(
      debugLog: (message, {error, stackTrace, context}) {
        ref
            .read(logManagerProvider)
            .debug(
              message,
              error: error,
              stackTrace: stackTrace,
              context: context,
            );
      },
      infoLog: (message, {error, stackTrace, context}) {
        ref
            .read(logManagerProvider)
            .info(
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
        ref.read(appPreferencesProvider).desktopShortcutBindings,
      ),
      routeActive: _isDesktopShortcutRouteActive,
      inlineEditorActive: () => _inlineComposeFocusNode.hasFocus,
      traySupported: () => DesktopTrayController.instance.supported,
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

    _inlineComposeCoordinator.addListener(
      _handleInlineComposeCoordinatorChanged,
    );
    _audioPlaybackCoordinator.addListener(_handleCoordinatorChanged);
    _mutationCoordinator.addListener(_handleCoordinatorChanged);
    _viewportCoordinator.addListener(_handleCoordinatorChanged);
    _headerController.addListener(_handleCoordinatorChanged);
    _inlineComposeUiController.addListener(_handleCoordinatorChanged);
    _localLibraryCoordinator.addListener(_handleCoordinatorChanged);
    _routeDelegate.addListener(_handleCoordinatorChanged);
    _animatedListController.addListener(_handleCoordinatorChanged);
    _inlineComposer.addListener(_handleInlineComposeStateChanged);
    _scrollController.addListener(_handleViewportScrollChanged);
    _inlineComposer.textController.addListener(_handleInlineComposeChanged);
    _inlineComposeFocusNode.addListener(_handleInlineComposeFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleViewportScrollChanged();
      _openDrawerIfNeeded();
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
    _scrollController.removeListener(_handleViewportScrollChanged);
    _inlineComposer.removeListener(_handleInlineComposeStateChanged);
    _inlineComposer.textController.removeListener(_handleInlineComposeChanged);
    _inlineComposeFocusNode.removeListener(_handleInlineComposeFocusChanged);
    _inlineComposeCoordinator.removeListener(
      _handleInlineComposeCoordinatorChanged,
    );
    _audioPlaybackCoordinator.removeListener(_handleCoordinatorChanged);
    _mutationCoordinator.removeListener(_handleCoordinatorChanged);
    _viewportCoordinator.removeListener(_handleCoordinatorChanged);
    _headerController.removeListener(_handleCoordinatorChanged);
    _inlineComposeUiController.removeListener(_handleCoordinatorChanged);
    _localLibraryCoordinator.removeListener(_handleCoordinatorChanged);
    _routeDelegate.removeListener(_handleCoordinatorChanged);
    _animatedListController.removeListener(_handleCoordinatorChanged);
    _voiceOverlayDragSession?.dispose();
    unawaited(_saveInlineComposeDraft(triggerSync: false));
    _inlineComposeCoordinator.dispose();
    _audioPlaybackCoordinator.dispose();
    _mutationCoordinator.dispose();
    _viewportCoordinator.dispose();
    _inlineComposeUiController.dispose();
    _localLibraryCoordinator.dispose();
    _routeDelegate.dispose();
    _animatedListController.dispose();
    _inlineComposeFocusNode.dispose();
    _inlineComposer.dispose();
    _headerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleInlineComposeCoordinatorChanged() {
    if (mounted) {
      setState(() {});
    }
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
    if (mounted) {
      setState(() {});
    }
  }

  void _clearInlineComposeState() {
    _inlineComposeDraftTimer?.cancel();
    _suppressInlineComposeDraftSave = true;
    _inlineComposeActiveDraftId = null;
    _inlineComposeCoordinator.resetAfterSuccessfulSubmit();
    _inlineComposeCoordinator.resetDraftStateToDefault();
    _suppressInlineComposeDraftSave = false;
    unawaited(ref.read(noteDraftProvider.notifier).clear());
    if (mounted) {
      setState(() {});
    }
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
    );
  }

  MemosListScreen _buildArchivedScreen() {
    return MemosListScreen(
      title: context.t.strings.legacy.msg_archive,
      state: 'ARCHIVED',
      showDrawer: true,
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
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
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
    final effect = _viewportCoordinator.handleScroll(metrics);
    if (effect.jumpedToTopUnexpectedly) {
      _logPaginationDebug(
        'scroll_jump_to_top_detected',
        metrics: _currentScrollMetricsForLogging(),
        context: <String, Object?>{'previousOffset': effect.previousOffset},
      );
    }
    _requestFloatingCollapseRecompute();
  }

  void _requestFloatingCollapseRecompute() {
    _viewportCoordinator.requestFloatingCollapseRecompute(
      schedulePostFrame: (callback) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callback());
      },
      resolveMemoUid: () => _animatedListController
          .resolveFloatingCollapseMemoUid(_floatingCollapseViewportKey),
    );
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
    final memoState = _animatedListController.currentStateFor(memoUid);
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

  bool _isDesktopShortcutRouteActive() {
    if (!mounted || !isDesktopShortcutEnabled()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return !ref.read(appLockProvider).locked;
  }

  void _focusSearchFromShortcut() {
    _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    _headerController.focusSearchFromShortcut(
      isWindowsDesktop: Platform.isWindows,
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
  }

  @override
  void onWindowUnmaximize() {
    _routeDelegate.onWindowUnmaximize();
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

  void _openWindowsHeaderSearch() {
    if (!Platform.isWindows || !widget.enableSearch) return;
    _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    _headerController.openWindowsHeaderSearch();
  }

  void _closeWindowsHeaderSearch({bool clearQuery = true}) {
    if (!Platform.isWindows || !_windowsHeaderSearchExpanded) return;
    _headerController.closeWindowsHeaderSearch(clearQuery: clearQuery);
  }

  void _toggleWindowsHeaderSearch() {
    if (_windowsHeaderSearchExpanded) {
      _closeWindowsHeaderSearch();
      return;
    }
    _openWindowsHeaderSearch();
  }

  void _closeSearch() {
    _headerController.closeSearch(
      clearGlobalFocus: () => FocusScope.of(context).unfocus(),
    );
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
          await ref
              .read(composeDraftRepositoryProvider)
              .deleteDraft(submittedDraftId);
        }
        for (final attachment in draft.pendingAttachments) {
          unawaited(
            ref
                .read(queuedAttachmentStagerProvider)
                .deleteManagedFile(attachment.filePath),
          );
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
    final selectedDraftId = await DraftBoxScreen.show(
      context,
      activeDraftId: _inlineComposeActiveDraftId,
    );
    if (!mounted) return;

    if (selectedDraftId != null && selectedDraftId.trim().isNotEmpty) {
      final selectedDraft = await ref
          .read(composeDraftRepositoryProvider)
          .getByUid(selectedDraftId);
      if (!mounted || selectedDraft == null) return;
      _restoreInlineComposeDraft(selectedDraft);
      _inlineComposeFocusNode.requestFocus();
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
    ref.invalidate(memoRelationsProvider(memo.uid));
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
          return await showDialog<bool>(
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
          return await showDialog<bool>(
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
    required ShortcutMemosQuery? shortcutQuery,
    required QuickSearchMemosQuery? quickSearchQuery,
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
    }
  }

  void _showRefreshSyncFeedback({required bool succeeded}) {
    final language = ref.read(appPreferencesProvider.select((p) => p.language));
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
    final outboxStatus =
        ref.read(memosListOutboxStatusProvider).valueOrNull ??
        const OutboxMemoStatus.empty();
    final prefs = ref.read(appPreferencesProvider);
    final tagColors = ref.read(tagColorLookupProvider);
    _animatedListController.removeMemoWithAnimation(
      memo,
      builder: (context, animation) => MemosListAnimatedMemoItem(
        memoCardKey: _animatedListController.keyFor(memo.uid),
        memo: memo,
        animation: animation,
        prefs: prefs,
        outboxStatus: outboxStatus,
        removing: true,
        tagColors: tagColors,
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
        onFloatingStateChanged: _requestFloatingCollapseRecompute,
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
    final inlineVisibilityPresentation = _inlineComposeUiController
        .resolveInlineVisibilityPresentation(context, inlineVisibility);
    final tagPresentationSignature = buildMemosListTagPresentationSignature(
      tagStats,
    );
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
          '${useQuickSearch ? 1 : 0}|${queryState.startTimeSec ?? ''}|${queryState.endTimeSecExclusive ?? ''}|'
          '${queryState.enableHomeSort ? _sortOption.name : 'default'}|$tagPresentationSignature|'
          '${queryState.advancedFilters.signature}';
      _animatedListController.syncAnimatedMemos(
        sortedMemos,
        listSignature,
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
    _animatedListController.syncMemoCardKeys(visibleMemos);
    _requestFloatingCollapseRecompute();

    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    final screenshotModeEnabled = kDebugMode
        ? ref.watch(debugScreenshotModeProvider)
        : false;
    final session = ref.watch(appSessionProvider).valueOrNull;
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

    _diagnostics.maybeLogMemosLoadingPhase(
      debugMode: kDebugMode,
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
    final drawerPanel = widget.showDrawer
        ? AppDrawer(
            selected: widget.state == 'ARCHIVED'
                ? AppDrawerDestination.archived
                : AppDrawerDestination.memos,
            onSelect: _routeDelegate.navigateDrawer,
            onSelectTag: _openTagFromDrawer,
            onOpenNotifications: _routeDelegate.openNotifications,
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
      autofocus: _searching && !Platform.isWindows,
      hasAdvancedFilters: _hasAdvancedSearchFilters,
      onOpenAdvancedFilters: () => unawaited(_openAdvancedSearchSheet()),
      onSubmitted: (value) => _headerController.submitSearch(
        value,
        addHistory: ref.read(searchHistoryProvider.notifier).add,
      ),
      hintText: _windowsHeaderSearchExpanded
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
        widget.showFilterTagChip && (resolvedTag?.trim().isNotEmpty ?? false)
        ? MemosListFilterTagChip(
            label: '#${resolvedTag!.trim()}',
            colors: tagColorLookup.resolveChipColorsByPath(
              resolvedTag.trim(),
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
    final inlineComposeChild = viewState.layout.useInlineCompose
        ? MemosListInlineComposeCard(
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
            onRemoveAttachment:
                _inlineComposeCoordinator.removePendingAttachment,
            onOpenAttachment: (attachment) => unawaited(
              _inlineComposeCoordinator.openAttachmentViewer(
                context,
                attachment,
              ),
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
          )
        : null;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
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
          windowsHeaderSearchExpanded: _windowsHeaderSearchExpanded,
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
          showBackToTop: _showBackToTop,
          hapticsEnabled: hapticsEnabled,
          floatingCollapseVisible: _floatingCollapseMemoUid != null,
          floatingCollapseScrolling: _floatingCollapseScrolling,
        ),
        drawerPanel: drawerPanel,
        titleChild: titleChild,
        searchFieldChild: searchFieldChild,
        sortButton: sortButton,
        resolvedTagChip: resolvedTagChip,
        advancedFilterSliver: advancedFilterSliver,
        inlineComposeChild: inlineComposeChild,
        tagFilterBarChild: tagFilterBarChild,
        searchLandingChild: searchLandingChild,
        bootstrapOverlayChild: _localLibraryCoordinator.bootstrapImportActive
            ? bootstrapOverlayChild
            : null,
        floatingActionButton: floatingActionButton,
        onRefresh: () => _handleRefresh(
          useShortcutFilter: useShortcutFilter,
          useQuickSearch: useQuickSearch,
          shortcutQuery: shortcutQuery,
          quickSearchQuery: quickSearchQuery,
        ),
        onScrollNotification: _handleViewportScrollNotification,
        onPointerSignal: _handleViewportPointerSignal,
        onCloseSearch: _closeSearch,
        onOpenSearch: _openSearch,
        onToggleWindowsHeaderSearch: _toggleWindowsHeaderSearch,
        onToggleQuickSearchKind: _headerController.toggleQuickSearchKind,
        onDismissGuide: () {
          if (activeListGuideId == null) return;
          _markSceneGuideSeen(activeListGuideId);
        },
        onCollapseFloatingMemo: _collapseActiveMemoFromFloatingButton,
        onScrollToTop: () => unawaited(_handleScrollToTop()),
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
          return MemosListAnimatedMemoItem(
            memoCardKey: _animatedListController.keyFor(memo.uid),
            memo: memo,
            animation: animation,
            prefs: prefs,
            outboxStatus: outboxStatus,
            removing: false,
            tagColors: tagColorLookup,
            searching: _searching,
            windowsHeaderSearchExpanded: _windowsHeaderSearchExpanded,
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
              if (prefs.hapticsEnabled) {
                HapticFeedback.selectionClick();
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MemoDetailScreen(initialMemo: memo),
                ),
              );
            },
            onDoubleTapEdit: () {
              _markSceneGuideSeen(SceneMicroGuideId.memoListGestures);
              unawaited(
                _memoActionDelegate.handleMemoAction(memo, MemoCardAction.edit),
              );
            },
            onLongPressCopy: () {
              _markSceneGuideSeen(SceneMicroGuideId.memoListGestures);
            },
            onFloatingStateChanged: _requestFloatingCollapseRecompute,
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
