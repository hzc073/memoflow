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
    implements HomeEmbeddedNavigationHost {
  HomeRootDestination _activeDestination = HomeRootDestination.memos;
  VoiceRecordOverlayDragSession? _voiceOverlayDragSession;
  Future<void>? _voiceOverlayDragFuture;

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
    setState(() => _activeDestination = destination);
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
    final activeIndex = visibleTabs.indexOf(activeDestination);
    final enableVoiceFabLongPress = _isMobileNativePlatform();

    return PopScope(
      canPop: activeDestination == primaryDestination,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || activeDestination == primaryDestination) return;
        _switchDestination(primaryDestination);
      },
      child: Scaffold(
        body: IndexedStack(
          index: activeIndex < 0 ? 0 : activeIndex,
          children: [
            for (final destination in visibleTabs)
              KeyedSubtree(
                key: ValueKey(destination),
                child: buildHomeRootScreen(
                  context: context,
                  destination: destination,
                  presentation: HomeScreenPresentation.embeddedBottomNav,
                  navigationHost: this,
                ),
              ),
          ],
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
          height: 94,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
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
                    const SizedBox(width: 84),
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
              Positioned(
                left: 0,
                right: 0,
                top: -24,
                child: Center(
                  child: MemoFlowFab(
                    onPressed: () => unawaited(onAddPressed()),
                    onLongPressStart: onAddLongPressStart,
                    onLongPressMoveUpdate: onAddLongPressMoveUpdate,
                    onLongPressEnd: onAddLongPressEnd,
                    hapticsEnabled: hapticsEnabled,
                  ),
                ),
              ),
            ],
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(definition.icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              definition.labelBuilder(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
