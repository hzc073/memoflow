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
import '../../core/windows_adaptive_surface.dart';
import '../../core/top_toast.dart';
import '../../data/repositories/scene_micro_guide_repository.dart';
import '../../platform/platform_route.dart';
import '../../platform/widgets/platform_action_sheet.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/settings/app_lock_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/session_provider.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/home_navigation_host.dart';
import '../desktop/quick_input/desktop_quick_input_dialog.dart';
import '../notifications/notifications_screen.dart';
import '../settings/desktop_shortcuts_overview_screen.dart';
import '../settings/password_lock_screen.dart';
import '../settings/shortcut_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../voice/voice_record_screen.dart';
import 'memos_list_desktop_presentation.dart';
import 'note_input_sheet.dart';
import 'widgets/memos_list_title_menu.dart';
import '../../i18n/strings.g.dart';

typedef MemosListRouteRead = T Function<T>(ProviderListenable<T> provider);
typedef MemosListRouteToastPresenter =
    bool Function(BuildContext context, String message, {Duration duration});
typedef MemosListRouteSettingsFallbackOpener =
    Future<void> Function(BuildContext context);
typedef MemosListRouteNoteInputPresenter =
    Future<void> Function(
      BuildContext context, {
      String? initialText,
      List<String> initialAttachmentPaths,
      bool ignoreDraft,
    });
typedef MemosListRouteVoiceRecordOverlayPresenter =
    Future<VoiceRecordResult?> Function(
      BuildContext context, {
      bool autoStart,
      VoiceRecordOverlayDragSession? dragSession,
      VoiceRecordMode mode,
    });
typedef MemosListRouteDesktopUtilityOpener = bool Function();
typedef MemosListRouteDesktopPresentationResolver =
    MemosListDesktopPresentation Function(BuildContext context);

abstract interface class MemosListRouteDesktopAdapter {
  bool get desktopShortcutsEnabled;
  bool get traySupported;
  bool get supportsWindowControls;
  bool get supportsTaskbarVisibilityToggle;

  Future<DesktopSettingsWindowOpenResult> openSettingsWindow({
    required BuildContext feedbackContext,
  });

  Future<bool> isWindowVisible();
  Future<void> hideToTray();
  Future<void> showFromTray();
  Future<void> setSkipTaskbar(bool skip);
  Future<void> hideWindow();
  Future<void> showWindow();
  Future<void> focusWindow();
  Future<bool> isWindowMaximized();
  Future<void> minimizeWindow();
  Future<void> maximizeWindow();
  Future<void> unmaximizeWindow();
  Future<void> requestCloseWindow();
}

class DefaultMemosListRouteDesktopAdapter
    implements MemosListRouteDesktopAdapter {
  const DefaultMemosListRouteDesktopAdapter();

  @override
  bool get desktopShortcutsEnabled => isDesktopShortcutEnabled();

  @override
  bool get traySupported => DesktopTrayController.instance.supported;

  @override
  bool get supportsWindowControls => Platform.isWindows;

  @override
  bool get supportsTaskbarVisibilityToggle =>
      Platform.isWindows || Platform.isLinux;

  @override
  Future<DesktopSettingsWindowOpenResult> openSettingsWindow({
    required BuildContext feedbackContext,
  }) {
    return openDesktopSettingsWindow(feedbackContext: feedbackContext);
  }

  @override
  Future<bool> isWindowVisible() => windowManager.isVisible();

  @override
  Future<void> hideToTray() => DesktopTrayController.instance.hideToTray();

  @override
  Future<void> showFromTray() => DesktopTrayController.instance.showFromTray();

  @override
  Future<void> setSkipTaskbar(bool skip) => windowManager.setSkipTaskbar(skip);

  @override
  Future<void> hideWindow() => windowManager.hide();

  @override
  Future<void> showWindow() => windowManager.show();

  @override
  Future<void> focusWindow() => windowManager.focus();

  @override
  Future<bool> isWindowMaximized() => windowManager.isMaximized();

  @override
  Future<void> minimizeWindow() => windowManager.minimize();

  @override
  Future<void> maximizeWindow() => windowManager.maximize();

  @override
  Future<void> unmaximizeWindow() => windowManager.unmaximize();

  @override
  Future<void> requestCloseWindow() {
    return DesktopExitCoordinator.requestClose(source: 'window_button');
  }
}

class MemosListRouteDelegate extends ChangeNotifier {
  MemosListRouteDelegate({
    required BuildContext Function() contextResolver,
    required MemosListRouteRead read,
    required GlobalKey<ScaffoldState> scaffoldKey,
    required Widget Function({String? toastMessage}) buildHomeScreen,
    required VoidCallback invalidateShortcuts,
    required Future<void> Function(String rawContent) submitDesktopQuickInput,
    required Future<void> Function() scrollToTop,
    required VoidCallback focusInlineCompose,
    required bool Function() shouldUseInlineComposeForCurrentWindow,
    required bool Function() enableCompose,
    required bool Function() searching,
    required bool Function() desktopHeaderSearchExpanded,
    required VoidCallback closeSearch,
    required VoidCallback closeDesktopHeaderSearch,
    required Future<void> Function() maybeScanLocalLibrary,
    required bool Function() isAllMemos,
    required bool Function() showDrawer,
    required DateTime? Function() dayFilter,
    required String? Function() selectedShortcutIdResolver,
    required void Function(String? shortcutId) selectShortcutId,
    required void Function(SceneMicroGuideId id) markSceneGuideSeen,
    HomeEmbeddedNavigationHost? embeddedNavigationHost,
    MemosListRouteDesktopAdapter? desktopAdapter,
    MemosListRouteToastPresenter? showToast,
    MemosListRouteSettingsFallbackOpener? openSettingsFallback,
    MemosListRouteDesktopPresentationResolver? desktopPresentationResolver,
    MemosListRouteNoteInputPresenter? showNoteInputSheet,
    MemosListRouteNoteInputPresenter? showDesktopComposeSurface,
    MemosListRouteVoiceRecordOverlayPresenter? showVoiceRecordOverlay,
    MemosListRouteDesktopUtilityOpener? openDesktopSyncQueue,
    MemosListRouteDesktopUtilityOpener? openDesktopNotifications,
  }) : _contextResolver = contextResolver,
       _read = read,
       _scaffoldKey = scaffoldKey,
       _buildHomeScreen = buildHomeScreen,
       _invalidateShortcuts = invalidateShortcuts,
       _submitDesktopQuickInput = submitDesktopQuickInput,
       _scrollToTop = scrollToTop,
       _focusInlineCompose = focusInlineCompose,
       _shouldUseInlineComposeForCurrentWindow =
           shouldUseInlineComposeForCurrentWindow,
       _enableCompose = enableCompose,
       _searching = searching,
       _desktopHeaderSearchExpanded = desktopHeaderSearchExpanded,
       _closeSearch = closeSearch,
       _closeDesktopHeaderSearch = closeDesktopHeaderSearch,
       _maybeScanLocalLibrary = maybeScanLocalLibrary,
       _isAllMemos = isAllMemos,
       _showDrawer = showDrawer,
       _dayFilter = dayFilter,
       _selectedShortcutIdResolver = selectedShortcutIdResolver,
       _selectShortcutId = selectShortcutId,
       _markSceneGuideSeen = markSceneGuideSeen,
       _embeddedNavigationHost = embeddedNavigationHost,
       _desktopAdapter =
           desktopAdapter ?? const DefaultMemosListRouteDesktopAdapter(),
       _showToast = showToast ?? _defaultShowToast,
       _openSettingsFallback =
           openSettingsFallback ?? _defaultOpenSettingsFallback,
       _desktopPresentationResolver = desktopPresentationResolver,
       _showNoteInputSheet = showNoteInputSheet ?? _defaultShowNoteInputSheet,
       _showDesktopComposeSurface = showDesktopComposeSurface,
       _showVoiceRecordOverlay =
           showVoiceRecordOverlay ?? _defaultShowVoiceRecordOverlay,
       _openDesktopSyncQueue = openDesktopSyncQueue,
       _openDesktopNotifications = openDesktopNotifications;

  final BuildContext Function() _contextResolver;
  final MemosListRouteRead _read;
  final GlobalKey<ScaffoldState> _scaffoldKey;
  final Widget Function({String? toastMessage}) _buildHomeScreen;
  final VoidCallback _invalidateShortcuts;
  final Future<void> Function(String rawContent) _submitDesktopQuickInput;
  final Future<void> Function() _scrollToTop;
  final VoidCallback _focusInlineCompose;
  final bool Function() _shouldUseInlineComposeForCurrentWindow;
  final bool Function() _enableCompose;
  final bool Function() _searching;
  final bool Function() _desktopHeaderSearchExpanded;
  final VoidCallback _closeSearch;
  final VoidCallback _closeDesktopHeaderSearch;
  final Future<void> Function() _maybeScanLocalLibrary;
  final bool Function() _isAllMemos;
  final bool Function() _showDrawer;
  final DateTime? Function() _dayFilter;
  final String? Function() _selectedShortcutIdResolver;
  final void Function(String? shortcutId) _selectShortcutId;
  final void Function(SceneMicroGuideId id) _markSceneGuideSeen;
  final HomeEmbeddedNavigationHost? _embeddedNavigationHost;
  final MemosListRouteDesktopAdapter _desktopAdapter;
  final MemosListRouteToastPresenter _showToast;
  final MemosListRouteSettingsFallbackOpener _openSettingsFallback;
  final MemosListRouteDesktopPresentationResolver? _desktopPresentationResolver;
  final MemosListRouteNoteInputPresenter _showNoteInputSheet;
  final MemosListRouteNoteInputPresenter? _showDesktopComposeSurface;
  final MemosListRouteVoiceRecordOverlayPresenter _showVoiceRecordOverlay;
  final MemosListRouteDesktopUtilityOpener? _openDesktopSyncQueue;
  final MemosListRouteDesktopUtilityOpener? _openDesktopNotifications;

  final GlobalKey titleAnchorKey = GlobalKey();

  DateTime? _lastBackPressedAt;
  bool _desktopWindowMaximized = false;
  bool _disposed = false;

  bool get desktopWindowMaximized => _desktopWindowMaximized;

  BuildContext get _context => _contextResolver();

  Route<T> _buildRoute<T>(WidgetBuilder builder) {
    return buildPlatformPageRoute<T>(context: _context, builder: builder);
  }

  MemosListDesktopPresentation _resolveDesktopPresentation(
    BuildContext context,
  ) {
    final injected = _desktopPresentationResolver;
    if (injected != null) return injected(context);
    return resolveMemosListDesktopPresentation(
      screenWidth: MediaQuery.maybeOf(context)?.size.width ?? 0,
      showDrawer: _showDrawer(),
      platform: Theme.of(context).platform,
    );
  }

  void backToAllMemos() {
    final embeddedNavigationHost = _embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleBackToPrimaryDestination(_context);
      return;
    }
    Navigator.of(_context).pushAndRemoveUntil(
      _buildRoute<void>((_) => _buildHomeScreen()),
      (route) => false,
    );
  }

  Future<bool> handleWillPop() async {
    final context = _context;
    if (_desktopHeaderSearchExpanded()) {
      _closeDesktopHeaderSearch();
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
      final embeddedNavigationHost = _embeddedNavigationHost;
      if (embeddedNavigationHost != null) {
        embeddedNavigationHost.handleBackToPrimaryDestination(context);
        return false;
      }
      if (_showDrawer()) {
        backToAllMemos();
        return false;
      }
      return true;
    }

    if (!_read(devicePreferencesProvider).confirmExitOnBack) {
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
    if (_read(devicePreferencesProvider).hapticsEnabled) {
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
    final embeddedNavigationHost = _embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerDestination(context, dest);
      return;
    }
    if (dest == AppDrawerDestination.syncQueue &&
        (_openDesktopSyncQueue?.call() ?? false)) {
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: dest),
    );
  }

  void openNotifications() {
    final context = _context;
    if (_read(devicePreferencesProvider).hapticsEnabled) {
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
    final embeddedNavigationHost = _embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleOpenNotifications(context);
      return;
    }
    if (_openDesktopNotifications?.call() ?? false) return;
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  void openSyncQueue() {
    final context = _context;
    if (_read(devicePreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    if (_openDesktopSyncQueue?.call() ?? false) return;
    Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => const SyncQueueScreen(),
      ),
    );
  }

  Future<void> openNoteInput() async {
    if (!_enableCompose()) return;
    final context = _context;
    final desktopComposeSurface = _showDesktopComposeSurface;
    if (_resolveDesktopPresentation(context).usesDesktopComposeSurface &&
        desktopComposeSurface != null) {
      await desktopComposeSurface(context);
      return;
    }
    await _showNoteInputSheet(context);
  }

  Future<void> openVoiceNoteInput({
    VoiceRecordOverlayDragSession? origin,
  }) async {
    if (!_enableCompose()) return;
    final context = _context;
    final result = await _showVoiceRecordOverlay(
      context,
      autoStart: true,
      dragSession: origin,
      mode: VoiceRecordMode.quickFabCompose,
    );
    if (!context.mounted || result == null) return;
    final desktopComposeSurface = _showDesktopComposeSurface;
    if (_resolveDesktopPresentation(context).usesDesktopComposeSurface &&
        desktopComposeSurface != null) {
      await desktopComposeSurface(
        context,
        initialAttachmentPaths: [result.filePath],
        ignoreDraft: true,
      );
      return;
    }
    await _showNoteInputSheet(
      context,
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

    Widget buildAccountSwitcherContent(BuildContext surfaceContext) {
      return SafeArea(
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
                    style: Theme.of(surfaceContext).textTheme.labelMedium,
                  ),
                ),
              ),
              ...accounts.map(
                (account) => ListTile(
                  leading: Icon(
                    account.key == session?.currentKey
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    account.user.displayName.isNotEmpty
                        ? account.user.displayName
                        : account.user.name,
                  ),
                  subtitle: Text(account.baseUrl.toString()),
                  onTap: () async {
                    await Navigator.of(surfaceContext).maybePop();
                    await _read(
                      appSessionProvider.notifier,
                    ).switchAccount(account.key);
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
                    style: Theme.of(surfaceContext).textTheme.labelMedium,
                  ),
                ),
              ),
              ...localLibraries.map(
                (library) => ListTile(
                  leading: Icon(
                    library.key == session?.currentKey
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    library.name.isNotEmpty
                        ? library.name
                        : context.t.strings.legacy.msg_local_library,
                  ),
                  subtitle: Text(library.locationLabel),
                  onTap: () async {
                    await Navigator.of(surfaceContext).maybePop();
                    await _read(
                      appSessionProvider.notifier,
                    ).switchWorkspace(library.key);
                    await WidgetsBinding.instance.endOfFrame;
                    await _maybeScanLocalLibrary();
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    if (shouldUseWindowsAdaptiveSurface(context)) {
      await showWindowsAdaptiveSurface<void>(
        context: context,
        kind: WindowsAdaptiveSurfaceKind.popover,
        anchorContext: titleAnchorKey.currentContext,
        fallbackAlignment: Alignment.topLeft,
        maxWidth: 480,
        builder: buildAccountSwitcherContent,
      );
      return;
    }

    await showPlatformActionSheet<void>(
      context: context,
      builder: buildAccountSwitcherContent,
    );
  }

  Future<void> createShortcutFromMenu() async {
    final context = _context;
    final result = await Navigator.of(context).push<ShortcutEditorResult>(
      buildPlatformPageRoute<ShortcutEditorResult>(
        context: context,
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
    _showToast(
      _context,
      '\u300c$label\u300d\u529f\u80fd\u6682\u672a\u5b9e\u73b0\uff08\u5360\u4f4d\uff09\u3002',
    );
  }

  Future<void> openQuickInputFromShortcut() async {
    if (!_enableCompose()) return;
    if (_desktopHeaderSearchExpanded()) {
      _closeDesktopHeaderSearch();
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
    if (!_desktopAdapter.desktopShortcutsEnabled) {
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
    if (!_desktopAdapter.desktopShortcutsEnabled) {
      showShortcutPlaceholder('\u663e\u793a/\u9690\u85cf MemoFlow');
      return;
    }
    try {
      if (_desktopAdapter.traySupported) {
        final visible = await _desktopAdapter.isWindowVisible();
        if (visible) {
          await _desktopAdapter.hideToTray();
        } else {
          await _desktopAdapter.showFromTray();
        }
        return;
      }
      final visible = await _desktopAdapter.isWindowVisible();
      if (visible) {
        if (_desktopAdapter.supportsTaskbarVisibilityToggle) {
          await _desktopAdapter.setSkipTaskbar(true);
        }
        await _desktopAdapter.hideWindow();
        return;
      }
      if (_desktopAdapter.supportsTaskbarVisibilityToggle) {
        await _desktopAdapter.setSkipTaskbar(false);
      }
      await _desktopAdapter.showWindow();
      await _desktopAdapter.focusWindow();
    } catch (error) {
      if (!context.mounted) return;
      _showToast(
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
      _showToast(context, '\u5df2\u542f\u7528\u5e94\u7528\u9501\u3002');
      return;
    }
    Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => const PasswordLockScreen(),
      ),
    );
  }

  void openShortcutOverviewPage() {
    final bindings = normalizeDesktopShortcutBindings(
      _read(devicePreferencesProvider).desktopShortcutBindings,
    );
    Navigator.of(_context).push(
      _buildRoute<void>(
        (_) => DesktopShortcutsOverviewScreen(bindings: bindings),
      ),
    );
  }

  Future<void> openSettings() async {
    final context = _context;
    final result = await _desktopAdapter.openSettingsWindow(
      feedbackContext: context,
    );
    if (result.opened) {
      return;
    }
    if (!context.mounted) return;
    await _openSettingsFallback(context);
  }

  Future<void> syncDesktopWindowState() async {
    if (!_desktopAdapter.supportsWindowControls || _disposed) return;
    final maximized = await _desktopAdapter.isWindowMaximized();
    if (_disposed || _desktopWindowMaximized == maximized) return;
    _desktopWindowMaximized = maximized;
    _notifyChanged();
  }

  Future<void> minimizeDesktopWindow() async {
    if (!_desktopAdapter.supportsWindowControls) return;
    await _desktopAdapter.minimizeWindow();
  }

  Future<void> toggleDesktopWindowMaximize() async {
    if (!_desktopAdapter.supportsWindowControls) return;
    if (await _desktopAdapter.isWindowMaximized()) {
      await _desktopAdapter.unmaximizeWindow();
    } else {
      await _desktopAdapter.maximizeWindow();
    }
    await syncDesktopWindowState();
  }

  Future<void> closeDesktopWindow() async {
    if (!_desktopAdapter.supportsWindowControls) return;
    await _desktopAdapter.requestCloseWindow();
  }

  void onWindowMaximize() {
    if (_desktopWindowMaximized) return;
    _desktopWindowMaximized = true;
    _notifyChanged();
  }

  void onWindowUnmaximize() {
    if (!_desktopWindowMaximized) return;
    _desktopWindowMaximized = false;
    _notifyChanged();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notifyChanged() {
    if (_disposed) return;
    notifyListeners();
  }

  static bool _defaultShowToast(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    return showTopToast(context, message, duration: duration);
  }

  static Future<void> _defaultOpenSettingsFallback(BuildContext context) {
    return Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  static Future<void> _defaultShowNoteInputSheet(
    BuildContext context, {
    String? initialText,
    List<String> initialAttachmentPaths = const [],
    bool ignoreDraft = false,
  }) {
    return NoteInputSheet.show(
      context,
      initialText: initialText,
      initialAttachmentPaths: initialAttachmentPaths,
      ignoreDraft: ignoreDraft,
    );
  }

  static Future<VoiceRecordResult?> _defaultShowVoiceRecordOverlay(
    BuildContext context, {
    bool autoStart = true,
    VoiceRecordOverlayDragSession? dragSession,
    VoiceRecordMode mode = VoiceRecordMode.standard,
  }) {
    return VoiceRecordScreen.showOverlay(
      context,
      autoStart: autoStart,
      dragSession: dragSession,
      mode: mode,
    );
  }
}
