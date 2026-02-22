import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/home_loading_overlay_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/stats_providers.dart';
import '../../state/user_settings_provider.dart';
import '../memos/memos_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const Duration _showCloseAfter = Duration(seconds: 30);
  static const int _totalLoadingSteps = 4;

  Timer? _showCloseTimer;
  ProviderSubscription<AsyncValue<void>>? _syncSubscription;
  late bool _overlayVisible;
  bool _overlayShownPersisted = false;
  bool _showCloseAction = false;
  bool _manuallyClosed = false;
  bool _syncAwaitingCompletion = false;
  bool _syncObservedLoading = false;
  bool _syncFinished = false;
  bool _syncSucceeded = false;

  @override
  void initState() {
    super.initState();
    final forceOverlay = ref.read(homeLoadingOverlayForceProvider);
    _overlayVisible =
        forceOverlay ||
        !ref.read(appPreferencesProvider).homeInitialLoadingOverlayShown;
    _syncSubscription = ref.listenManual<AsyncValue<void>>(
      syncControllerProvider,
      _handleSyncStateChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_overlayVisible) return;
      _consumeForceOverlayFlag();
      _markOverlayShown();
      _startLoadingGate();
    });
  }

  void _consumeForceOverlayFlag() {
    if (!ref.read(homeLoadingOverlayForceProvider)) return;
    ref.read(homeLoadingOverlayForceProvider.notifier).state = false;
  }

  void _markOverlayShown() {
    if (_overlayShownPersisted) return;
    _overlayShownPersisted = true;
    ref
        .read(appPreferencesProvider.notifier)
        .setHomeInitialLoadingOverlayShown(true);
  }

  void _startLoadingGate() {
    _showCloseTimer?.cancel();
    _showCloseTimer = Timer(_showCloseAfter, () {
      if (!mounted || !_overlayVisible || _manuallyClosed) return;
      setState(() => _showCloseAction = true);
    });

    _syncAwaitingCompletion = true;
    final syncState = ref.read(syncControllerProvider);
    _syncObservedLoading = syncState.isLoading;
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  void _handleSyncStateChanged(
    AsyncValue<void>? previous,
    AsyncValue<void> next,
  ) {
    if (!_syncAwaitingCompletion || _syncFinished || !_overlayVisible) return;

    if (next.isLoading) {
      _syncObservedLoading = true;
      return;
    }

    if (!_syncObservedLoading && previous?.isLoading != true) {
      return;
    }

    _completeSyncTracking(success: next.hasValue);
  }

  void _completeSyncTracking({required bool success}) {
    if (!mounted || _syncFinished) return;
    setState(() {
      _syncFinished = true;
      _syncSucceeded = success;
    });
  }

  void _hideOverlayAutomatically() {
    if (!_overlayVisible || _manuallyClosed) return;
    setState(() => _overlayVisible = false);
    _showCloseTimer?.cancel();
  }

  void _closeOverlayManually() {
    if (!_overlayVisible) return;
    setState(() {
      _manuallyClosed = true;
      _overlayVisible = false;
    });
    _showCloseTimer?.cancel();
  }

  double _progressValue({
    required bool userReady,
    required bool resourcesReady,
    required bool statsReady,
    required bool syncReady,
  }) {
    final doneCount = <bool>[
      userReady,
      resourcesReady,
      statsReady,
      syncReady,
    ].where((done) => done).length;
    final value = doneCount / _totalLoadingSteps;
    if (value <= 0) return 0.05;
    if (value >= 1) return 1;
    return value;
  }

  @override
  void dispose() {
    _showCloseTimer?.cancel();
    _syncSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userInfoAsync = ref.watch(userGeneralSettingProvider);
    final resourcesAsync = ref.watch(resourcesProvider);
    final statsAsync = ref.watch(localStatsProvider);

    final userReady = userInfoAsync.hasValue;
    final resourcesReady = resourcesAsync.hasValue;
    final statsReady = statsAsync.hasValue;
    final syncReady = _syncFinished && _syncSucceeded;
    final allReady = userReady && resourcesReady && statsReady && syncReady;
    final progress = _progressValue(
      userReady: userReady,
      resourcesReady: resourcesReady,
      statsReady: statsReady,
      syncReady: syncReady,
    );

    if (allReady && _overlayVisible && !_manuallyClosed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hideOverlayAutomatically();
      });
    }

    return Stack(
      children: [
        const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
        if (_overlayVisible)
          Positioned.fill(
            child: _HomeLoadingOverlay(
              progress: progress,
              showCloseAction: _showCloseAction,
              onClose: _closeOverlayManually,
            ),
          ),
      ],
    );
  }
}

class _HomeLoadingOverlay extends StatelessWidget {
  const _HomeLoadingOverlay({
    required this.progress,
    required this.showCloseAction,
    required this.onClose,
  });

  final double progress;
  final bool showCloseAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.32)
        : Colors.white.withValues(alpha: 0.36);
    final dialogBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.62 : 0.58);
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: ColoredBox(color: overlayColor),
          ),
        ),
        const ModalBarrier(dismissible: false, color: Colors.transparent),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: dialogBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        MemoFlowPalette.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '\u52A0\u8F7D\u7B14\u8BB0\u4E2D...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress,
                      backgroundColor: textMuted.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        MemoFlowPalette.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                  if (showCloseAction) ...[
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(color: border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('\u5173\u95ED'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
