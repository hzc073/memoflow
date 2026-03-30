import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../application/desktop/desktop_exit_coordinator.dart';
import '../../application/desktop/desktop_settings_window.dart';
import '../../application/desktop/desktop_tray_controller.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/drawer_navigation.dart';
import '../../core/platform_layout.dart';
import '../../core/top_toast.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/settings/app_lock_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/session_provider.dart';
import '../home/app_drawer.dart';
import '../about/about_screen.dart';
import '../desktop/quick_input/desktop_quick_input_dialog.dart';
import '../explore/explore_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/desktop_shortcuts_overview_screen.dart';
import '../settings/password_lock_screen.dart';
import '../settings/shortcut_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../tags/tags_screen.dart';
import '../voice/voice_record_screen.dart';
import 'note_input_sheet.dart';
import 'recycle_bin_screen.dart';
import 'widgets/memos_list_title_menu.dart';
import '../../i18n/strings.g.dart';

typedef MemosListRouteRead = T Function<T>(ProviderListenable<T> provider);

class MemosListRouteDelegate extends ChangeNotifier {
  MemosListRouteDelegate({
    required BuildContext Function() contextResolver,
    required MemosListRouteRead read,
    required GlobalKey<ScaffoldState> scaffoldKey,
    required Widget Function({String? toastMessage}) buildHomeScreen,
    required Widget Function() buildArchivedScreen,
    required VoidCallback invalidateShortcuts,
    required Future<void> Function(String rawContent) submitDesktopQuickInput,
    required Future<void> Function() scrollToTop,
    required VoidCallback focusInlineCompose,
    required bool Function() shouldUseInlineComposeForCurrentWindow,
    required bool Function() enableCompose,
    required bool Function() searching,
    required bool Function() windowsHeaderSearchExpanded,
    required VoidCallback closeSearch,
    required VoidCallback closeWindowsHeaderSearch,
    required Future<void> Function() maybeScanLocalLibrary,
    required bool Function() isAllMemos,
    required bool Function() showDrawer,
    required DateTime? Function() dayFilter,
    required String? Function() selectedShortcutIdResolver,
    required void Function(String? shortcutId) selectShortcutId,
    required void Function(SceneMicroGuideId id) markSceneGuideSeen,
  }) : _contextResolver = contextResolver,
       _read = read,
       _scaffoldKey = scaffoldKey,
       _buildHomeScreen = buildHomeScreen,
       _buildArchivedScreen = buildArchivedScreen,
       _invalidateShortcuts = invalidateShortcuts,
       _submitDesktopQuickInput = submitDesktopQuickInput,
       _scrollToTop = scrollToTop,
       _focusInlineCompose = focusInlineCompose,
       _shouldUseInlineComposeForCurrentWindow =
           shouldUseInlineComposeForCurrentWindow,
       _enableCompose = enableCompose,
       _searching = searching,
       _windowsHeaderSearchExpanded = windowsHeaderSearchExpanded,
       _closeSearch = closeSearch,
       _closeWindowsHeaderSearch = closeWindowsHeaderSearch,
       _maybeScanLocalLibrary = maybeScanLocalLibrary,
       _isAllMemos = isAllMemos,
       _showDrawer = showDrawer,
       _dayFilter = dayFilter,
       _selectedShortcutIdResolver = selectedShortcutIdResolver,
       _selectShortcutId = selectShortcutId,
       _markSceneGuideSeen = markSceneGuideSeen;

  final BuildContext Function() _contextResolver;
  final MemosListRouteRead _read;
  final GlobalKey<ScaffoldState> _scaffoldKey;
  final Widget Function({String? toastMessage}) _buildHomeScreen;
  final Widget Function() _buildArchivedScreen;
  final VoidCallback _invalidateShortcuts;
  final Future<void> Function(String rawContent) _submitDesktopQuickInput;
  final Future<void> Function() _scrollToTop;
  final VoidCallback _focusInlineCompose;
  final bool Function() _shouldUseInlineComposeForCurrentWindow;
  final bool Function() _enableCompose;
  final bool Function() _searching;
  final bool Function() _windowsHeaderSearchExpanded;
  final VoidCallback _closeSearch;
  final VoidCallback _closeWindowsHeaderSearch;
  final Future<void> Function() _maybeScanLocalLibrary;
  final bool Function() _isAllMemos;
  final bool Function() _showDrawer;
  final DateTime? Function() _dayFilter;
  final String? Function() _selectedShortcutIdResolver;
  final void Function(String? shortcutId) _selectShortcutId;
  final void Function(SceneMicroGuideId id) _markSceneGuideSeen;

  final GlobalKey titleAnchorKey = GlobalKey();

  DateTime? _lastBackPressedAt;
  bool _desktopWindowMaximized = false;

  bool get desktopWindowMaximized => _desktopWindowMaximized;

  BuildContext get _context => _contextResolver();

  void backToAllMemos() {
    Navigator.of(_context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => _buildHomeScreen()),
      (route) => false,
    );
  }

  Future<bool> handleWillPop() async {
    final context = _context;
    if (_windowsHeaderSearchExpanded()) {
      _closeWindowsHeaderSearch();
      return false;
    }
    if (_searching()) {
      _closeSearch();
      return false;
    }
    if (_dayFilter() != null) {
      return true;
    }
    if (!_isAllMemos()) {
      if (_showDrawer()) {
        backToAllMemos();
        return false;
      }
      return true;
    }

    if (!_read(appPreferencesProvider).confirmExitOnBack) {
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

  void navigateDrawer(AppDrawerDestination dest) {
    final context = _context;
    if (_read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final hasAccount =
        _read(appSessionProvider).valueOrNull?.currentAccount != null;
    if (!hasAccount && dest == AppDrawerDestination.explore) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }
    final route = switch (dest) {
      AppDrawerDestination.memos => _buildHomeScreen(),
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.explore => const ExploreScreen(),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => _buildArchivedScreen(),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.recycleBin => const RecycleBinScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    closeDrawerThenPushReplacement(context, route);
  }

  void openNotifications() {
    final context = _context;
    if (_read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final hasAccount =
        _read(appSessionProvider).valueOrNull?.currentAccount != null;
    if (!hasAccount) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  void openSyncQueue() {
    final context = _context;
    if (_read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SyncQueueScreen()));
  }

  Future<void> openNoteInput() async {
    if (!_enableCompose()) return;
    await NoteInputSheet.show(_context);
  }

  Future<void> openVoiceNoteInput({
    VoiceRecordOverlayDragSession? origin,
  }) async {
    if (!_enableCompose()) return;
    final context = _context;
    final result = await VoiceRecordScreen.showOverlay(
      context,
      autoStart: true,
      dragSession: origin,
    );
    if (!context.mounted || result == null) return;
    await NoteInputSheet.show(
      context,
      initialText: result.suggestedContent,
      initialAttachmentPaths: [result.filePath],
      ignoreDraft: true,
    );
  }

  Future<void> openAccountSwitcher() async {
    final context = _context;
    final session = _read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final localLibraries = _read(localLibrariesProvider);
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
                    await _read(
                      appSessionProvider.notifier,
                    ).switchAccount(a.key);
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
                    await _read(
                      appSessionProvider.notifier,
                    ).switchWorkspace(l.key);
                    await WidgetsBinding.instance.endOfFrame;
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

  Future<void> createShortcutFromMenu() async {
    final context = _context;
    final result = await Navigator.of(context).push<ShortcutEditorResult>(
      MaterialPageRoute<ShortcutEditorResult>(
        builder: (_) => const ShortcutEditorScreen(),
      ),
    );
    if (result == null) return;

    final account = _read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_not_authenticated)),
      );
      return;
    }
    try {
      final created = await _read(
        memosListControllerProvider,
      ).createShortcut(title: result.title, filter: result.filter);
      _invalidateShortcuts();
      _selectShortcutId(created.shortcutId);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_create_failed_2(e: error)),
        ),
      );
    }
  }

  Future<void> openTitleMenu() async {
    final context = _context;
    final session = _read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final showShortcuts = _isAllMemos() && session?.currentAccount != null;
    if (!showShortcuts && accounts.length < 2) return;
    if (showShortcuts) {
      _markSceneGuideSeen(SceneMicroGuideId.memoListSearchAndShortcuts);
    }

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final titleBox =
        titleAnchorKey.currentContext?.findRenderObject() as RenderBox?;
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
              selectedShortcutId: _selectedShortcutIdResolver(),
              showShortcuts: showShortcuts,
              showAccountSwitcher: accounts.length > 1,
              maxHeight: menuMaxHeight,
              formatShortcutError: formatShortcutLoadError,
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action.type) {
      case MemosListTitleMenuActionType.selectShortcut:
        _selectShortcutId(action.shortcutId);
        break;
      case MemosListTitleMenuActionType.clearShortcut:
        _selectShortcutId(null);
        break;
      case MemosListTitleMenuActionType.createShortcut:
        await createShortcutFromMenu();
        break;
      case MemosListTitleMenuActionType.openAccountSwitcher:
        await openAccountSwitcher();
        break;
    }
  }

  String formatShortcutLoadError(BuildContext context, Object error) {
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

  void showShortcutPlaceholder(String label) {
    showTopToast(
      _context,
      '\u300c$label\u300d\u529f\u80fd\u6682\u672a\u5b9e\u73b0\uff08\u5360\u4f4d\uff09\u3002',
    );
  }

  Future<void> openQuickInputFromShortcut() async {
    if (!_enableCompose()) return;
    if (_windowsHeaderSearchExpanded()) {
      _closeWindowsHeaderSearch();
    }
    if (_searching()) {
      _closeSearch();
    }
    if (_shouldUseInlineComposeForCurrentWindow()) {
      unawaited(_scrollToTop());
      _focusInlineCompose();
      return;
    }
    await openNoteInput();
  }

  Future<void> openQuickRecordFromShortcut() async {
    if (!isDesktopShortcutEnabled()) {
      showShortcutPlaceholder(_context.t.strings.legacy.msg_quick_record);
      return;
    }
    final content = await DesktopQuickInputDialog.show(
      _context,
      onImagePressed: () =>
          showShortcutPlaceholder(_context.t.strings.legacy.msg_image),
    );
    if (content == null) return;
    await _submitDesktopQuickInput(content);
  }

  String toggleDesktopDrawerFromShortcut() {
    if (!_showDrawer()) return 'drawer_disabled';

    final width = MediaQuery.sizeOf(_context).width;
    final supportsDesktopPane = shouldUseDesktopSidePaneLayout(width);
    if (supportsDesktopPane) {
      return 'desktop_sidepane_pinned';
    }

    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return 'scaffold_missing';
    if (scaffold.isDrawerOpen) {
      Navigator.of(_context).maybePop();
      return 'drawer_closed';
    } else {
      scaffold.openDrawer();
      return 'drawer_opened';
    }
  }

  Future<void> toggleMemoFlowVisibilityFromShortcut() async {
    final context = _context;
    if (!isDesktopShortcutEnabled()) {
      showShortcutPlaceholder('\u663e\u793a/\u9690\u85cf MemoFlow');
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
      if (!context.mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_toggle_memoflow_failed_with_error(
          error: error,
        ),
      );
    }
  }

  void openPasswordLockFromShortcut() {
    final context = _context;
    final lockState = _read(appLockProvider);
    if (lockState.enabled && lockState.hasPassword) {
      _read(appLockProvider.notifier).lock();
      showTopToast(context, '\u5df2\u542f\u7528\u5e94\u7528\u9501\u3002');
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PasswordLockScreen()));
  }

  void openShortcutOverviewPage() {
    final bindings = normalizeDesktopShortcutBindings(
      _read(appPreferencesProvider).desktopShortcutBindings,
    );
    Navigator.of(_context).push(
      MaterialPageRoute<void>(
        builder: (_) => DesktopShortcutsOverviewScreen(bindings: bindings),
      ),
    );
  }

  Future<void> openSettings() async {
    final context = _context;
    if (openDesktopSettingsWindowIfSupported(feedbackContext: context)) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  Future<void> syncDesktopWindowState() async {
    if (!Platform.isWindows) return;
    _desktopWindowMaximized = await windowManager.isMaximized();
    notifyListeners();
  }

  Future<void> minimizeDesktopWindow() async {
    if (!Platform.isWindows) return;
    await windowManager.minimize();
  }

  Future<void> toggleDesktopWindowMaximize() async {
    if (!Platform.isWindows) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await syncDesktopWindowState();
  }

  Future<void> closeDesktopWindow() async {
    if (!Platform.isWindows) return;
    await DesktopExitCoordinator.requestClose(source: 'window_button');
  }

  void onWindowMaximize() {
    _desktopWindowMaximized = true;
    notifyListeners();
  }

  void onWindowUnmaximize() {
    _desktopWindowMaximized = false;
    notifyListeners();
  }
}
