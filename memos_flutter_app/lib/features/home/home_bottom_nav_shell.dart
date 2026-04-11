import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drawer_navigation.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/home_navigation_preferences.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/system/session_provider.dart';
import '../about/about_screen.dart';
import '../memos/memos_list_screen.dart';
import '../memos/note_input_sheet.dart';
import '../memos/recycle_bin_screen.dart';
import '../memos/widgets/memos_list_floating_actions.dart';
import '../notifications/notifications_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../tags/tags_screen.dart';
import '../voice/voice_record_screen.dart';
import 'app_drawer.dart';
import 'home_navigation_host.dart';
import 'home_navigation_resolver.dart';
import 'home_root_destination_registry.dart';
import '../../i18n/strings.g.dart';

class HomeBottomNavShell extends ConsumerStatefulWidget {
  const HomeBottomNavShell({super.key});

  static Future<void> Function(BuildContext context)?
  debugShowNoteInputOverride;

  @override
  ConsumerState<HomeBottomNavShell> createState() => _HomeBottomNavShellState();
}

class _HomeBottomNavShellState extends ConsumerState<HomeBottomNavShell>
    with SingleTickerProviderStateMixin
    implements HomeEmbeddedNavigationHost {
  static const double _kTabSwipeMinDistance = 72;
  static const double _kTabSwipeMinHorizontalRatio = 1.35;
  static const Duration _kTabTransitionDuration = Duration(milliseconds: 210);
  static const double _kSwipeEdgeTriggerExtent = 24;

  HomeRootDestination _activeDestination = HomeRootDestination.memos;
  VoiceRecordOverlayDragSession? _voiceOverlayDragSession;
  Future<void>? _voiceOverlayDragFuture;
  late final AnimationController _tabTransitionController;
  HomeRootDestination? _transitionPreviousDestination;
  int _transitionDirection = 0;
  int? _trackedBodySwipePointer;
  Offset? _bodySwipeStartPosition;
  Offset? _bodySwipeLatestPosition;
  final Map<HomeRootDestination, List<Rect>> _globalSwipeExclusionRects = {};

  @override
  void initState() {
    super.initState();
    _tabTransitionController =
        AnimationController(vsync: this, duration: _kTabTransitionDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _finishTabTransition();
            }
          });
  }

  @override
  void dispose() {
    _tabTransitionController.dispose();
    super.dispose();
  }

  bool get _currentHasAccount =>
      ref.read(appSessionProvider).valueOrNull?.currentAccount != null;

  ResolvedHomeNavigationPreferences get _resolvedPreferences {
    final preferences = ref.read(
      currentWorkspacePreferencesProvider.select(
        (value) => value.homeNavigationPreferences,
      ),
    );
    return resolveHomeNavigationPreferences(
      preferences,
      hasAccount: _currentHasAccount,
    );
  }

  bool _isMobileNativePlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _switchDestination(HomeRootDestination destination) {
    if (_activeDestination == destination) return;
    final visibleTabs = _resolvedPreferences.visibleTabs;
    final currentIndex = visibleTabs.indexOf(_activeDestination);
    final nextIndex = visibleTabs.indexOf(destination);
    final direction =
        currentIndex >= 0 && nextIndex >= 0 && nextIndex != currentIndex
        ? (nextIndex > currentIndex ? 1 : -1)
        : 0;

    if (_tabTransitionController.isAnimating) {
      _tabTransitionController.stop();
      _finishTabTransition();
    }

    setState(() {
      _transitionPreviousDestination = direction == 0
          ? null
          : _activeDestination;
      _transitionDirection = direction;
      _activeDestination = destination;
    });

    if (direction != 0) {
      _tabTransitionController.forward(from: 0);
    }
  }

  void _switchToAdjacentDestination(
    List<HomeRootDestination> visibleTabs,
    HomeRootDestination activeDestination,
    int offset,
  ) {
    final currentIndex = visibleTabs.indexOf(activeDestination);
    if (currentIndex < 0) return;
    final nextIndex = currentIndex + offset;
    if (nextIndex < 0 || nextIndex >= visibleTabs.length) return;
    _switchDestination(visibleTabs[nextIndex]);
  }

  void _finishTabTransition() {
    if (!mounted) return;
    setState(() {
      _transitionPreviousDestination = null;
      _transitionDirection = 0;
    });
  }

  void _handleBodySwipePointerDown(PointerDownEvent event) {
    if (_trackedBodySwipePointer != null ||
        _tabTransitionController.isAnimating) {
      return;
    }
    if (_isGlobalSwipeExcluded(event.position)) return;
    _trackedBodySwipePointer = event.pointer;
    _bodySwipeStartPosition = event.position;
    _bodySwipeLatestPosition = event.position;
  }

  void _handleBodySwipePointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackedBodySwipePointer) return;
    _bodySwipeLatestPosition = event.position;
  }

  void _handleBodySwipePointerUp(
    PointerUpEvent event,
    List<HomeRootDestination> visibleTabs,
    HomeRootDestination activeDestination,
  ) {
    if (event.pointer != _trackedBodySwipePointer) return;
    _bodySwipeLatestPosition = event.position;
    final start = _bodySwipeStartPosition;
    final end = _bodySwipeLatestPosition;
    _resetBodySwipeTracking();
    if (start == null || end == null) return;

    final dragDx = end.dx - start.dx;
    final dragDy = (end.dy - start.dy).abs();
    if (dragDx.abs() < _kTabSwipeMinDistance) return;
    if (dragDx.abs() <= dragDy * _kTabSwipeMinHorizontalRatio) return;

    if (activeDestination == HomeRootDestination.memos) {
      if (dragDx >= 0) return;
      _switchToAdjacentDestination(visibleTabs, activeDestination, 1);
      return;
    }

    _switchToAdjacentDestination(
      visibleTabs,
      activeDestination,
      dragDx < 0 ? 1 : -1,
    );
  }

  void _handleBodySwipePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _trackedBodySwipePointer) return;
    _resetBodySwipeTracking();
  }

  void _resetBodySwipeTracking() {
    _trackedBodySwipePointer = null;
    _bodySwipeStartPosition = null;
    _bodySwipeLatestPosition = null;
  }

  bool _isGlobalSwipeExcluded(Offset globalPosition) {
    final rects = _globalSwipeExclusionRects[_activeDestination];
    if (rects == null || rects.isEmpty) return false;
    final width = MediaQuery.sizeOf(context).width;
    final isNearHorizontalEdge =
        globalPosition.dx <= _kSwipeEdgeTriggerExtent ||
        globalPosition.dx >= width - _kSwipeEdgeTriggerExtent;
    if (isNearHorizontalEdge) return false;
    for (final rect in rects) {
      if (rect.contains(globalPosition)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildAnimatedBody(
    List<HomeRootDestination> visibleTabs,
    HomeRootDestination activeDestination,
  ) {
    final previousDestination =
        visibleTabs.contains(_transitionPreviousDestination)
        ? _transitionPreviousDestination
        : null;
    final transitionAnimation = CurvedAnimation(
      parent: _tabTransitionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final destination in visibleTabs)
            _buildAnimatedDestinationLayer(
              destination: destination,
              activeDestination: activeDestination,
              previousDestination: previousDestination,
              transitionAnimation: transitionAnimation,
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDestinationLayer({
    required HomeRootDestination destination,
    required HomeRootDestination activeDestination,
    required HomeRootDestination? previousDestination,
    required Animation<double> transitionAnimation,
  }) {
    final page = KeyedSubtree(
      key: ValueKey(destination),
      child: buildHomeRootScreen(
        context: context,
        destination: destination,
        presentation: HomeScreenPresentation.embeddedBottomNav,
        navigationHost: this,
      ),
    );
    final isActive = destination == activeDestination;
    final isPrevious = destination == previousDestination;

    if (!isActive && !isPrevious) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: page),
      );
    }

    if (isPrevious && _transitionDirection != 0) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: Offset(_transitionDirection > 0 ? -1 : 1, 0),
        ).animate(transitionAnimation),
        child: IgnorePointer(ignoring: true, child: page),
      );
    }

    if (isActive &&
        isPrevious == false &&
        previousDestination != null &&
        _transitionDirection != 0) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(_transitionDirection > 0 ? 1 : -1, 0),
          end: Offset.zero,
        ).animate(transitionAnimation),
        child: page,
      );
    }

    return page;
  }

  Widget _buildSwipeAwareBody({
    required Widget child,
    required HomeRootDestination activeDestination,
    required List<HomeRootDestination> visibleTabs,
    required bool enabled,
  }) {
    if (!enabled ||
        visibleTabs.length < 2 ||
        _tabTransitionController.isAnimating) {
      return child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleBodySwipePointerDown,
      onPointerMove: _handleBodySwipePointerMove,
      onPointerUp: (event) =>
          _handleBodySwipePointerUp(event, visibleTabs, activeDestination),
      onPointerCancel: _handleBodySwipePointerCancel,
      child: child,
    );
  }

  void _closeDrawerThen(BuildContext context, VoidCallback action) {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !navigator.mounted) return;
    final shouldPopDrawer = navigator.canPop();
    if (shouldPopDrawer) {
      navigator.pop();
    }
    if (!shouldPopDrawer) {
      action();
      return;
    }
    Future<void>.delayed(kDrawerCloseNavigationDelay, () {
      if (!mounted) return;
      action();
    });
  }

  void _closeDrawerThenPush(BuildContext context, Widget route) {
    _closeDrawerThen(context, () {
      if (!mounted) return;
      Navigator.of(
        this.context,
      ).push(MaterialPageRoute<void>(builder: (_) => route));
    });
  }

  Widget _buildStandaloneRouteForDrawer(
    BuildContext context,
    AppDrawerDestination destination,
  ) {
    final overlayNavigationHost = _OverlayHomeNavigationHost(shell: this);
    return switch (destination) {
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.recycleBin => const RecycleBinScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
      AppDrawerDestination.memos ||
      AppDrawerDestination.explore ||
      AppDrawerDestination.dailyReview ||
      AppDrawerDestination.aiSummary ||
      AppDrawerDestination.resources ||
      AppDrawerDestination.archived ||
      AppDrawerDestination.settings => buildHomeRootScreen(
        context: context,
        destination:
            homeRootDestinationFromDrawerDestination(destination) ??
            HomeRootDestination.memos,
        presentation: HomeScreenPresentation.standalone,
        navigationHost: overlayNavigationHost,
      ),
    };
  }

  Future<void> _openNoteInput() {
    final override = HomeBottomNavShell.debugShowNoteInputOverride;
    if (override != null) {
      return override(context);
    }
    return NoteInputSheet.show(context);
  }

  Future<void> _openVoiceNoteInput({
    VoiceRecordOverlayDragSession? dragSession,
  }) async {
    final result = await VoiceRecordScreen.showOverlay(
      context,
      autoStart: true,
      dragSession: dragSession,
      mode: VoiceRecordMode.quickFabCompose,
    );
    if (!mounted || result == null) return;
    await NoteInputSheet.show(
      context,
      initialAttachmentPaths: [result.filePath],
      ignoreDraft: true,
    );
  }

  Future<void> _handleVoiceFabLongPressStart(
    LongPressStartDetails details,
  ) async {
    if (_voiceOverlayDragFuture != null) return;
    final dragSession = VoiceRecordOverlayDragSession();
    _voiceOverlayDragSession = dragSession;
    dragSession.update(Offset.zero);
    final future = _openVoiceNoteInput(dragSession: dragSession);
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

  @override
  void handleDrawerDestination(
    BuildContext context,
    AppDrawerDestination destination,
  ) {
    final rootDestination = homeRootDestinationFromDrawerDestination(
      destination,
    );
    final resolved = _resolvedPreferences;
    if (rootDestination != null &&
        !isHomeRootDestinationAvailable(
          rootDestination,
          hasAccount: _currentHasAccount,
        )) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }

    if (rootDestination != null &&
        resolved.visibleTabs.contains(rootDestination)) {
      _closeDrawerThen(context, () => _switchDestination(rootDestination));
      return;
    }

    _closeDrawerThenPush(
      context,
      _buildStandaloneRouteForDrawer(context, destination),
    );
  }

  @override
  void handleDrawerTag(BuildContext context, String tag) {
    _closeDrawerThenPush(
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

  @override
  void handleOpenNotifications(BuildContext context) {
    if (!_currentHasAccount) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }
    _closeDrawerThenPush(context, const NotificationsScreen());
  }

  @override
  void handleBackToPrimaryDestination(BuildContext context) {
    final resolved = _resolvedPreferences;
    _switchDestination(
      resolved.fallbackDestinationFor(HomeRootDestination.memos),
    );
  }

  @override
  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  ) {
    if (rects.isEmpty) {
      _globalSwipeExclusionRects.remove(destination);
      return;
    }
    _globalSwipeExclusionRects[destination] = List<Rect>.unmodifiable(rects);
  }

  @override
  void clearGlobalSwipeExclusionRects(HomeRootDestination destination) {
    _globalSwipeExclusionRects.remove(destination);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (value) => value.homeNavigationPreferences,
      ),
    );
    final hasAccount = ref.watch(
      appSessionProvider.select(
        (value) => value.valueOrNull?.currentAccount != null,
      ),
    );
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((value) => value.hapticsEnabled),
    );
    final resolved = resolveHomeNavigationPreferences(
      preferences,
      hasAccount: hasAccount,
    );
    final effectiveActive = resolved.fallbackDestinationFor(_activeDestination);
    if (effectiveActive != _activeDestination) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _switchDestination(effectiveActive);
      });
    }

    final visibleTabs = resolved.visibleTabs;
    final activeDestination = effectiveActive;
    final primaryDestination = resolved.fallbackDestinationFor(
      HomeRootDestination.memos,
    );
    final enableVoiceFabLongPress = _isMobileNativePlatform();
    final enableSwipeNavigation = _isMobileNativePlatform();

    return PopScope(
      canPop: activeDestination == primaryDestination,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || activeDestination == primaryDestination) return;
        _switchDestination(primaryDestination);
      },
      child: Scaffold(
        body: _buildSwipeAwareBody(
          activeDestination: activeDestination,
          visibleTabs: visibleTabs,
          enabled: enableSwipeNavigation,
          child: _buildAnimatedBody(visibleTabs, activeDestination),
        ),
        bottomNavigationBar: _HomeBottomNavigationBar(
          resolved: resolved,
          activeDestination: activeDestination,
          onSelectDestination: _switchDestination,
          onAddPressed: _openNoteInput,
          onAddLongPressStart: enableVoiceFabLongPress
              ? _handleVoiceFabLongPressStart
              : null,
          onAddLongPressMoveUpdate: enableVoiceFabLongPress
              ? _handleVoiceFabLongPressMoveUpdate
              : null,
          onAddLongPressEnd: enableVoiceFabLongPress
              ? _handleVoiceFabLongPressEnd
              : null,
          hapticsEnabled: hapticsEnabled,
        ),
      ),
    );
  }
}

class _OverlayHomeNavigationHost implements HomeEmbeddedNavigationHost {
  const _OverlayHomeNavigationHost({required this.shell});

  final _HomeBottomNavShellState shell;

  void _dismissOverlayThen(BuildContext context, VoidCallback action) {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !navigator.mounted) {
      if (shell.mounted) {
        action();
      }
      return;
    }

    final scaffold = Scaffold.maybeOf(context);
    final isDrawerOpen = scaffold?.isDrawerOpen ?? false;
    if (isDrawerOpen) {
      navigator.pop();
    }

    void dismissRoute() {
      final overlayNavigator = Navigator.maybeOf(context);
      if (overlayNavigator == null || !overlayNavigator.mounted) {
        if (shell.mounted) {
          action();
        }
        return;
      }

      unawaited(
        overlayNavigator.maybePop().then((_) {
          if (!shell.mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!shell.mounted) return;
            action();
          });
        }),
      );
    }

    if (isDrawerOpen) {
      Future<void>.delayed(kDrawerCloseNavigationDelay, dismissRoute);
      return;
    }

    dismissRoute();
  }

  @override
  void handleDrawerDestination(
    BuildContext context,
    AppDrawerDestination destination,
  ) {
    _dismissOverlayThen(context, () {
      shell.handleDrawerDestination(shell.context, destination);
    });
  }

  @override
  void handleDrawerTag(BuildContext context, String tag) {
    _dismissOverlayThen(context, () {
      shell.handleDrawerTag(shell.context, tag);
    });
  }

  @override
  void handleOpenNotifications(BuildContext context) {
    _dismissOverlayThen(context, () {
      shell.handleOpenNotifications(shell.context);
    });
  }

  @override
  void handleBackToPrimaryDestination(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !navigator.mounted) {
      if (shell.mounted) {
        shell.handleBackToPrimaryDestination(shell.context);
      }
      return;
    }

    unawaited(
      navigator.maybePop().then((didPop) {
        if (didPop || !shell.mounted) return;
        shell.handleBackToPrimaryDestination(shell.context);
      }),
    );
  }

  @override
  void updateGlobalSwipeExclusionRects(
    HomeRootDestination destination,
    List<Rect> rects,
  ) {
    shell.updateGlobalSwipeExclusionRects(destination, rects);
  }

  @override
  void clearGlobalSwipeExclusionRects(HomeRootDestination destination) {
    shell.clearGlobalSwipeExclusionRects(destination);
  }
}

class _HomeBottomNavigationBar extends StatelessWidget {
  const _HomeBottomNavigationBar({
    required this.resolved,
    required this.activeDestination,
    required this.onSelectDestination,
    required this.onAddPressed,
    required this.onAddLongPressStart,
    required this.onAddLongPressMoveUpdate,
    required this.onAddLongPressEnd,
    required this.hapticsEnabled,
  });

  final ResolvedHomeNavigationPreferences resolved;
  final HomeRootDestination activeDestination;
  final ValueChanged<HomeRootDestination> onSelectDestination;
  final Future<void> Function() onAddPressed;
  final Future<void> Function(LongPressStartDetails details)?
  onAddLongPressStart;
  final void Function(LongPressMoveUpdateDetails details)?
  onAddLongPressMoveUpdate;
  final void Function(LongPressEndDetails details)? onAddLongPressEnd;
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? MemoFlowPalette.cardDark
        : Theme.of(context).colorScheme.surface;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _HomeBottomNavigationGroup(
                    destinations: [
                      resolved.leftPrimary,
                      resolved.leftSecondary,
                    ],
                    activeDestination: activeDestination,
                    onSelectDestination: onSelectDestination,
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: Center(
                    child: MemoFlowFab(
                      onPressed: () => unawaited(onAddPressed()),
                      onLongPressStart: onAddLongPressStart,
                      onLongPressMoveUpdate: onAddLongPressMoveUpdate,
                      onLongPressEnd: onAddLongPressEnd,
                      hapticsEnabled: hapticsEnabled,
                      size: 44,
                      iconSize: 22,
                      borderWidth: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: _HomeBottomNavigationGroup(
                    destinations: [
                      resolved.rightPrimary,
                      resolved.rightSecondary,
                    ],
                    activeDestination: activeDestination,
                    onSelectDestination: onSelectDestination,
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

class _HomeBottomNavigationGroup extends StatelessWidget {
  const _HomeBottomNavigationGroup({
    required this.destinations,
    required this.activeDestination,
    required this.onSelectDestination,
  });

  final List<HomeRootDestination> destinations;
  final HomeRootDestination activeDestination;
  final ValueChanged<HomeRootDestination> onSelectDestination;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final destination in destinations)
          Expanded(
            child: destination == HomeRootDestination.none
                ? const SizedBox.shrink()
                : _HomeBottomNavigationItem(
                    destination: destination,
                    selected: destination == activeDestination,
                    onTap: () => onSelectDestination(destination),
                  ),
          ),
      ],
    );
  }
}

class _HomeBottomNavigationItem extends StatelessWidget {
  const _HomeBottomNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final HomeRootDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final definition = homeRootDestinationDefinition(destination);
    if (definition == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? MemoFlowPalette.primary
        : (isDark ? Colors.white70 : Colors.black54);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Center(
          child: Text(
            definition.labelBuilder(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
