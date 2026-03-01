import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_coordinator.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../core/memoflow_palette.dart';
import '../../data/logs/log_manager.dart';
import '../../data/logs/sync_queue_progress_tracker.dart';
import '../../state/home_loading_overlay_provider.dart';
import '../../state/logging_provider.dart';
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
  ProviderSubscription<SyncFlowStatus>? _syncSubscription;
  ProviderSubscription<bool>? _forceOverlaySubscription;
  late bool _overlayVisible;
  bool _overlayShownPersisted = false;
  bool _showCloseAction = false;
  bool _manuallyClosed = false;
  bool _syncAwaitingCompletion = false;
  bool _syncObservedLoading = false;
  bool _syncFinished = false;
  bool _syncSucceeded = false;
  String? _lastOverlayPhaseKey;

  @override
  void initState() {
    super.initState();
    final forceOverlay = ref.read(homeLoadingOverlayForceProvider);
    _overlayVisible =
        forceOverlay ||
        !ref.read(appPreferencesProvider).homeInitialLoadingOverlayShown;
    _logOverlayLifecycle(
      'overlay_init',
      context: <String, Object?>{
        'forceOverlay': forceOverlay,
        'overlayVisible': _overlayVisible,
        'persistedShown': ref
            .read(appPreferencesProvider)
            .homeInitialLoadingOverlayShown,
      },
    );
    _syncSubscription = ref.listenManual<SyncFlowStatus>(
      syncCoordinatorProvider.select((state) => state.memos),
      _handleSyncStateChanged,
    );
    _forceOverlaySubscription = ref.listenManual<bool>(
      homeLoadingOverlayForceProvider,
      _handleForceOverlayChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_overlayVisible) return;
      _consumeForceOverlayFlag();
      _markOverlayShown();
      _startLoadingGate();
    });
  }

  void _handleForceOverlayChanged(bool? previous, bool next) {
    if (!next || !mounted) return;
    _consumeForceOverlayFlag();
    _markOverlayShown();
    if (_overlayVisible) return;
    setState(() {
      _overlayVisible = true;
      _showCloseAction = false;
      _manuallyClosed = false;
      _syncAwaitingCompletion = false;
      _syncObservedLoading = false;
      _syncFinished = false;
      _syncSucceeded = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_overlayVisible) return;
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
      _logOverlayLifecycle(
        'close_action_revealed',
        context: <String, Object?>{'timeoutSec': _showCloseAfter.inSeconds},
      );
      setState(() => _showCloseAction = true);
    });

    _syncAwaitingCompletion = true;
    final syncState = ref.read(syncCoordinatorProvider).memos;
    final queue = ref.read(syncQueueProgressTrackerProvider).snapshot;
    _logOverlayLifecycle(
      'gate_start',
      context: _overlayContext(
        extra: <String, Object?>{
          'syncState': _describeAsyncState(syncState),
          'queueSyncing': queue.syncing,
          'queueTotalTasks': queue.totalTasks,
          'queueCompletedTasks': queue.completedTasks,
          'queueCurrentOutboxId': queue.currentOutboxId,
          'queueCurrentProgress': queue.currentProgress,
        },
      ),
    );
    _syncObservedLoading = syncState.running;
    if (syncState.running) {
      _logOverlayLifecycle('skip_sync_request_already_loading');
      return;
    }
    _logOverlayLifecycle('request_sync_now');
    unawaited(
      ref.read(syncCoordinatorProvider.notifier).requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.launch,
            ),
          ),
    );
  }

  void _handleSyncStateChanged(
    SyncFlowStatus? previous,
    SyncFlowStatus next,
  ) {
    _logOverlayLifecycle(
      'sync_state_changed',
      context: _overlayContext(
        extra: <String, Object?>{
          'previousSyncState': _describeAsyncState(previous),
          'nextSyncState': _describeAsyncState(next),
          'observedLoading': _syncObservedLoading,
          'awaitingCompletion': _syncAwaitingCompletion,
        },
      ),
    );
    if (!_syncAwaitingCompletion || _syncFinished || !_overlayVisible) return;

    if (next.running) {
      _syncObservedLoading = true;
      return;
    }

    if (!_syncObservedLoading && previous?.running != true) {
      return;
    }

    _completeSyncTracking(success: next.lastError == null);
  }

  void _completeSyncTracking({required bool success}) {
    if (!mounted || _syncFinished) return;
    _logOverlayLifecycle(
      'sync_tracking_completed',
      context: _overlayContext(extra: <String, Object?>{'success': success}),
    );
    setState(() {
      _syncFinished = true;
      _syncSucceeded = success;
    });
  }

  void _hideOverlayAutomatically() {
    if (!_overlayVisible || _manuallyClosed) return;
    _logOverlayLifecycle(
      'overlay_hidden_auto',
      context: _overlayContext(extra: <String, Object?>{'reason': 'all_ready'}),
    );
    setState(() => _overlayVisible = false);
    _showCloseTimer?.cancel();
  }

  void _closeOverlayManually() {
    if (!_overlayVisible) return;
    _logOverlayLifecycle(
      'overlay_hidden_manual',
      context: _overlayContext(
        extra: <String, Object?>{'reason': 'user_close'},
      ),
    );
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
    required bool syncing,
    required double? preciseSyncProgress,
  }) {
    if (syncing && preciseSyncProgress != null) {
      final value = preciseSyncProgress.clamp(0.0, 0.999).toDouble();
      return value <= 0 ? 0.01 : value;
    }
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
    _forceOverlaySubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userInfoAsync = ref.watch(userGeneralSettingProvider);
    final resourcesAsync = ref.watch(resourcesProvider);
    final statsAsync = ref.watch(localStatsProvider);
    final syncState = ref.watch(syncCoordinatorProvider).memos;
    final syncQueueSnapshot = ref
        .watch(syncQueueProgressTrackerProvider)
        .snapshot;

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
      syncing: syncQueueSnapshot.syncing,
      preciseSyncProgress: syncQueueSnapshot.overallProgress,
    );
    _logOverlayBuildPhase(
      userReady: userReady,
      resourcesReady: resourcesReady,
      statsReady: statsReady,
      syncReady: syncReady,
      allReady: allReady,
      progress: progress,
      syncState: syncState,
      syncQueueSnapshot: syncQueueSnapshot,
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

  void _logOverlayBuildPhase({
    required bool userReady,
    required bool resourcesReady,
    required bool statsReady,
    required bool syncReady,
    required bool allReady,
    required double progress,
    required SyncFlowStatus syncState,
    required SyncQueueProgressSnapshot syncQueueSnapshot,
  }) {
    if (!kDebugMode) return;
    if (!_overlayVisible && allReady) return;
    final key = [
      _overlayVisible,
      _manuallyClosed,
      _showCloseAction,
      userReady,
      resourcesReady,
      statsReady,
      syncReady,
      allReady,
      progress.toStringAsFixed(2),
      _describeAsyncState(syncState),
      syncQueueSnapshot.syncing,
      syncQueueSnapshot.totalTasks,
      syncQueueSnapshot.completedTasks,
      syncQueueSnapshot.currentOutboxId,
      syncQueueSnapshot.currentProgress?.toStringAsFixed(2) ?? '-',
    ].join('|');
    if (_lastOverlayPhaseKey == key) return;
    _lastOverlayPhaseKey = key;
    _logOverlayLifecycle(
      'overlay_phase',
      context: _overlayContext(
        extra: <String, Object?>{
          'userReady': userReady,
          'resourcesReady': resourcesReady,
          'statsReady': statsReady,
          'syncReady': syncReady,
          'allReady': allReady,
          'progress': progress,
          'syncState': _describeAsyncState(syncState),
          'queueSyncing': syncQueueSnapshot.syncing,
          'queueTotalTasks': syncQueueSnapshot.totalTasks,
          'queueCompletedTasks': syncQueueSnapshot.completedTasks,
          'queueCurrentOutboxId': syncQueueSnapshot.currentOutboxId,
          'queueCurrentProgress': syncQueueSnapshot.currentProgress,
        },
      ),
    );
  }

  Map<String, Object?> _overlayContext({Map<String, Object?>? extra}) {
    final context = <String, Object?>{
      'overlayVisible': _overlayVisible,
      'showCloseAction': _showCloseAction,
      'manuallyClosed': _manuallyClosed,
      'syncAwaitingCompletion': _syncAwaitingCompletion,
      'syncObservedLoading': _syncObservedLoading,
      'syncFinished': _syncFinished,
      'syncSucceeded': _syncSucceeded,
    };
    if (extra != null && extra.isNotEmpty) {
      context.addAll(extra);
    }
    return context;
  }

  String _describeAsyncState(SyncFlowStatus? state) {
    if (state == null) return 'null';
    if (state.running) return 'running';
    final error = state.lastError;
    if (error != null) return 'error(${error.code.name})';
    return 'idle';
  }

  void _logOverlayLifecycle(String event, {Map<String, Object?>? context}) {
    if (!kDebugMode) return;
    LogManager.instance.info('HomeLoading: $event', context: context);
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
