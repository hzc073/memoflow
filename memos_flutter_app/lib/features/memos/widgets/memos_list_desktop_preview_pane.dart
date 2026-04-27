import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_motion_widgets.dart';
import '../../../core/memo_content_diagnostics.dart';
import '../../../core/memoflow_palette.dart';
import '../../../data/logs/log_manager.dart';
import '../../../data/models/local_memo.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/memos/desktop_memo_preview_session.dart';
import '../memo_detail_screen.dart';

enum _DesktopPreviewRevealStage {
  empty,
  initialLoader,
  swapLoader,
  waitingData,
  revealing,
  visible,
  error,
}

class MemosListDesktopPreviewPane extends ConsumerStatefulWidget {
  const MemosListDesktopPreviewPane({
    super.key,
    required this.selectedMemo,
    required this.isVisible,
    required this.onClose,
    required this.onEditMemo,
  });

  final LocalMemo? selectedMemo;
  final bool isVisible;
  final VoidCallback onClose;
  final VoidCallback onEditMemo;

  @override
  ConsumerState<MemosListDesktopPreviewPane> createState() =>
      _MemosListDesktopPreviewPaneState();
}

class _MemosListDesktopPreviewPaneState
    extends ConsumerState<MemosListDesktopPreviewPane> {
  final ScrollController _scrollController = ScrollController();

  AudioPlayer? _audioPlayer;
  String? _currentAudioUrl;
  bool _headerElevated = false;
  bool _motionGateOpen = false;
  int _visualRequestId = 0;
  int _visualCycleEpochMs = 0;
  int _lastPrimaryReadyRequestId = 0;
  int _lastSupplementaryReadyRequestId = 0;
  int _lastWaitingDataRequestId = 0;
  Timer? _motionGateTimer;
  Timer? _revealCompleteTimer;
  String? _visualErrorMessage;
  DesktopMemoPreviewCacheKey? _revealedKey;
  DesktopMemoPreviewCacheKey? _stagedKey;
  DesktopMemoPreviewCacheKey? _supplementaryReadyKey;
  MemoDocumentResolvedData? _stagedData;
  _DesktopPreviewRevealStage _revealStage = _DesktopPreviewRevealStage.empty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollChanged);
  }

  @override
  void didUpdateWidget(covariant MemosListDesktopPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handlePaneInputsChanged(oldWidget);
  }

  @override
  void dispose() {
    _cancelVisualTimers();
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _handlePaneInputsChanged(MemosListDesktopPreviewPane oldWidget) {
    final session = ref.read(desktopMemoPreviewSessionProvider);
    final wasVisible = oldWidget.isVisible;
    final isVisible = widget.isVisible;
    final oldMemo = oldWidget.selectedMemo;
    final nextMemo = widget.selectedMemo;

    if (!isVisible) {
      _clearVisualState(reason: 'pane_hidden');
      return;
    }

    if (!wasVisible) {
      if (nextMemo == null) {
        _clearVisualState(clearRevealedKey: false);
        return;
      }
      _beginInitialLoaderCycle(_resolvedRequestIdForSelection(session));
      _handleSessionChanged(session);
      return;
    }

    if (_sameMemoIdentity(oldMemo, nextMemo)) {
      return;
    }

    if (nextMemo == null) {
      _clearVisualState(clearRevealedKey: false);
      return;
    }

    _beginSwapLoaderCycle(_resolvedRequestIdForSelection(session));
    _handleSessionChanged(session);
  }

  void _handleScrollChanged() {
    final elevated =
        _scrollController.hasClients && _scrollController.position.pixels > 2;
    if (_headerElevated == elevated) return;
    setState(() => _headerElevated = elevated);
  }

  Future<void> _togglePlayAudio(
    String url, {
    Map<String, String>? headers,
  }) async {
    final player = _audioPlayer ??= AudioPlayer();
    if (_currentAudioUrl == url) {
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
      if (!mounted) return;
      setState(() {});
      return;
    }

    setState(() => _currentAudioUrl = url);
    try {
      await player.setUrl(url, headers: headers);
      await player.play();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentAudioUrl = null);
    }
  }

  bool _sameMemoIdentity(LocalMemo? a, LocalMemo? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.uid.trim() == b.uid.trim() &&
        a.contentFingerprint.trim() == b.contentFingerprint.trim() &&
        a.updateTime.microsecondsSinceEpoch ==
            b.updateTime.microsecondsSinceEpoch;
  }

  bool _memoMatchesKey(LocalMemo? memo, DesktopMemoPreviewCacheKey? key) {
    if (memo == null || key == null) return false;
    return memo.uid.trim() == key.memoUid &&
        memo.contentFingerprint.trim() == key.contentFingerprint &&
        memo.updateTime.microsecondsSinceEpoch == key.updateTimeMicros;
  }

  int _resolvedRequestIdForSelection(DesktopMemoPreviewSessionState session) {
    final selectedMemo = widget.selectedMemo;
    if (selectedMemo == null) return 0;
    final requestedMemo = session.requestedMemo;
    if (_sameMemoIdentity(requestedMemo, selectedMemo)) {
      return session.requestId;
    }
    final dataMemo = session.data?.memo;
    if (_sameMemoIdentity(dataMemo, selectedMemo)) {
      return session.requestId;
    }
    return 0;
  }

  bool _sessionTargetsSelection(DesktopMemoPreviewSessionState session) {
    final selectedMemo = widget.selectedMemo;
    if (selectedMemo == null) return false;
    return _sameMemoIdentity(session.requestedMemo, selectedMemo) ||
        _sameMemoIdentity(session.data?.memo, selectedMemo);
  }

  int _nowEpochMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

  int _currentCycleElapsedMs() {
    if (_visualCycleEpochMs == 0) return 0;
    return _nowEpochMs() - _visualCycleEpochMs;
  }

  Duration _resolvedLoaderGateDuration(bool initial) {
    return AppMotion.effectiveDuration(
      context,
      initial
          ? AppMotion.desktopPreviewInitialLoaderMin
          : AppMotion.desktopPreviewSwapLoaderMin,
    );
  }

  Duration get _resolvedRevealDuration => AppMotion.effectiveDuration(
    context,
    AppMotion.desktopPreviewContentReveal,
  );

  void _resetHeaderElevation() {
    if (!_headerElevated) return;
    setState(() => _headerElevated = false);
  }

  void _cancelVisualTimers({bool logCancellation = false, String? reason}) {
    final memo = widget.selectedMemo;
    final shouldLogCancellation =
        logCancellation &&
        memo != null &&
        (_revealStage == _DesktopPreviewRevealStage.initialLoader ||
            _revealStage == _DesktopPreviewRevealStage.swapLoader ||
            _revealStage == _DesktopPreviewRevealStage.waitingData ||
            _revealStage == _DesktopPreviewRevealStage.revealing);
    _motionGateTimer?.cancel();
    _motionGateTimer = null;
    _revealCompleteTimer?.cancel();
    _revealCompleteTimer = null;
    if (shouldLogCancellation) {
      _logPreviewEvent(
        'content_reveal_cancelled',
        memo: memo,
        context: <String, Object?>{
          'requestId': _visualRequestId,
          if (reason != null) 'reason': reason,
          'elapsedMs': _currentCycleElapsedMs(),
        },
      );
    }
  }

  void _clearVisualState({bool clearRevealedKey = false, String? reason}) {
    _cancelVisualTimers(
      logCancellation: widget.isVisible || reason == 'pane_hidden',
      reason: reason,
    );
    final nextRevealedKey = clearRevealedKey ? null : _revealedKey;
    if (!mounted) {
      _motionGateOpen = false;
      _visualRequestId = 0;
      _visualCycleEpochMs = 0;
      _visualErrorMessage = null;
      _stagedData = null;
      _stagedKey = null;
      _supplementaryReadyKey = null;
      _revealStage = _DesktopPreviewRevealStage.empty;
      _revealedKey = nextRevealedKey;
      return;
    }
    setState(() {
      _motionGateOpen = false;
      _visualRequestId = 0;
      _visualCycleEpochMs = 0;
      _visualErrorMessage = null;
      _stagedData = null;
      _stagedKey = null;
      _supplementaryReadyKey = null;
      _revealStage = _DesktopPreviewRevealStage.empty;
      _revealedKey = nextRevealedKey;
    });
    _resetHeaderElevation();
  }

  void _beginLoaderCycle({required bool initial, required int requestId}) {
    final memo = widget.selectedMemo;
    if (memo == null) return;
    _cancelVisualTimers(
      logCancellation: true,
      reason: initial ? 'initial_loader_restart' : 'swap_loader_restart',
    );
    final nextStage = initial
        ? _DesktopPreviewRevealStage.initialLoader
        : _DesktopPreviewRevealStage.swapLoader;
    final now = _nowEpochMs();
    setState(() {
      _motionGateOpen = false;
      _visualRequestId = requestId;
      _visualCycleEpochMs = now;
      _visualErrorMessage = null;
      _stagedData = null;
      _stagedKey = null;
      _supplementaryReadyKey = null;
      _revealStage = nextStage;
    });
    _lastWaitingDataRequestId = 0;
    _resetHeaderElevation();
    _logPreviewEvent(
      initial ? 'pane_loader_started' : 'swap_loader_started',
      memo: memo,
      context: <String, Object?>{'requestId': requestId, 'elapsedMs': 0},
    );
    _armMotionGate(initial: initial, memo: memo);
  }

  void _beginInitialLoaderCycle(int requestId) {
    _beginLoaderCycle(initial: true, requestId: requestId);
  }

  void _beginSwapLoaderCycle(int requestId) {
    _beginLoaderCycle(initial: false, requestId: requestId);
  }

  void _armMotionGate({required bool initial, required LocalMemo memo}) {
    final duration = _resolvedLoaderGateDuration(initial);
    if (duration == Duration.zero) {
      _motionGateOpen = true;
      _logPreviewEvent(
        initial ? 'pane_loader_min_elapsed' : 'swap_loader_min_elapsed',
        memo: memo,
        context: <String, Object?>{
          'requestId': _visualRequestId,
          'elapsedMs': _currentCycleElapsedMs(),
        },
      );
      _handleMotionGateOpened();
      return;
    }
    _motionGateTimer = Timer(duration, () {
      if (!mounted) return;
      _motionGateTimer = null;
      _motionGateOpen = true;
      _logPreviewEvent(
        initial ? 'pane_loader_min_elapsed' : 'swap_loader_min_elapsed',
        memo: memo,
        context: <String, Object?>{
          'requestId': _visualRequestId,
          'elapsedMs': _currentCycleElapsedMs(),
        },
      );
      _handleMotionGateOpened();
    });
  }

  void _handleMotionGateOpened() {
    if (!widget.isVisible) return;
    _tryStartReveal(ref.read(desktopMemoPreviewSessionProvider));
  }

  void _handleSessionChanged(DesktopMemoPreviewSessionState session) {
    if (!mounted || !widget.isVisible || !_sessionTargetsSelection(session)) {
      return;
    }

    final selectedMemo = widget.selectedMemo;
    if (selectedMemo == null) return;

    final sameVisibleContent =
        _revealStage == _DesktopPreviewRevealStage.visible &&
        _memoMatchesKey(selectedMemo, _revealedKey);
    final inLoaderCycle =
        _revealStage == _DesktopPreviewRevealStage.initialLoader ||
        _revealStage == _DesktopPreviewRevealStage.swapLoader ||
        _revealStage == _DesktopPreviewRevealStage.waitingData;

    if (session.requestId != 0 && session.requestId != _visualRequestId) {
      if (sameVisibleContent) {
        return;
      }
      if (inLoaderCycle) {
        setState(() => _visualRequestId = session.requestId);
      } else {
        _beginSwapLoaderCycle(session.requestId);
      }
    }

    if (session.phase == DesktopMemoPreviewPhase.ready &&
        session.data != null &&
        session.activeKey != null) {
      final nextData = session.data!;
      final nextKey = session.activeKey!;
      if (!_sameMemoIdentity(nextData.memo, selectedMemo)) {
        return;
      }
      final needsStageUpdate =
          _stagedKey != nextKey || !identical(_stagedData, nextData);
      if (needsStageUpdate) {
        setState(() {
          _stagedData = nextData;
          _stagedKey = nextKey;
          _visualErrorMessage = null;
        });
      }
      _tryStartReveal(session);
      return;
    }

    if (session.phase == DesktopMemoPreviewPhase.error) {
      _visualErrorMessage = session.errorMessage;
      if (_motionGateOpen) {
        _showErrorState(session);
      }
    }
  }

  void _showErrorState(DesktopMemoPreviewSessionState session) {
    final memo = widget.selectedMemo;
    if (memo == null) return;
    if (_revealStage == _DesktopPreviewRevealStage.error &&
        _visualErrorMessage == session.errorMessage) {
      return;
    }
    setState(() {
      _revealStage = _DesktopPreviewRevealStage.error;
      _stagedData = null;
      _stagedKey = null;
      _supplementaryReadyKey = null;
      _visualErrorMessage = session.errorMessage;
    });
  }

  void _tryStartReveal(DesktopMemoPreviewSessionState session) {
    if (!mounted || !widget.isVisible || !_motionGateOpen) {
      return;
    }

    final memo = widget.selectedMemo;
    if (memo == null) {
      return;
    }

    if (session.phase == DesktopMemoPreviewPhase.error) {
      _showErrorState(session);
      return;
    }

    final stagedData = _stagedData;
    final stagedKey = _stagedKey;
    final requestId = _visualRequestId == 0
        ? session.requestId
        : _visualRequestId;

    if (stagedData == null ||
        stagedKey == null ||
        !_sameMemoIdentity(stagedData.memo, memo)) {
      if (_revealStage != _DesktopPreviewRevealStage.waitingData) {
        setState(() => _revealStage = _DesktopPreviewRevealStage.waitingData);
      }
      if (_lastWaitingDataRequestId != requestId) {
        _lastWaitingDataRequestId = requestId;
        _logPreviewEvent(
          'content_reveal_waiting_data',
          memo: memo,
          context: <String, Object?>{
            'requestId': requestId,
            'elapsedMs': _currentCycleElapsedMs(),
          },
        );
      }
      return;
    }

    if (_revealStage == _DesktopPreviewRevealStage.revealing ||
        (_revealStage == _DesktopPreviewRevealStage.visible &&
            _revealedKey == stagedKey)) {
      return;
    }

    final previousRevealedKey = _revealedKey;
    final elapsedMs = _currentCycleElapsedMs();
    setState(() {
      _revealStage = _DesktopPreviewRevealStage.revealing;
      _revealedKey = stagedKey;
      _visualErrorMessage = null;
    });

    if (_lastPrimaryReadyRequestId != requestId) {
      _lastPrimaryReadyRequestId = requestId;
      _logPreviewEvent(
        'primary_ready',
        memo: stagedData.memo,
        context: <String, Object?>{
          'requestId': requestId,
          'elapsedMs': elapsedMs,
        },
      );
    }

    _logPreviewEvent(
      'content_reveal_started',
      memo: stagedData.memo,
      context: <String, Object?>{
        'requestId': requestId,
        'elapsedMs': elapsedMs,
      },
    );

    if (previousRevealedKey != null && previousRevealedKey != stagedKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
      });
      _resetHeaderElevation();
    }

    _scheduleSupplementaryReady(
      requestId: requestId,
      key: stagedKey,
      memo: stagedData.memo,
    );

    final duration = _resolvedRevealDuration;
    _revealCompleteTimer?.cancel();
    if (duration == Duration.zero) {
      _completeReveal(requestId, stagedData.memo);
      return;
    }
    _revealCompleteTimer = Timer(
      duration,
      () => _completeReveal(requestId, stagedData.memo),
    );
  }

  void _scheduleSupplementaryReady({
    required int requestId,
    required DesktopMemoPreviewCacheKey key,
    required LocalMemo memo,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(desktopMemoPreviewSessionProvider);
      if (!widget.isVisible ||
          (_visualRequestId != 0 && _visualRequestId != requestId) ||
          latest.requestId != requestId ||
          _revealedKey != key ||
          (_revealStage != _DesktopPreviewRevealStage.revealing &&
              _revealStage != _DesktopPreviewRevealStage.visible)) {
        return;
      }
      if (_lastSupplementaryReadyRequestId == requestId &&
          _supplementaryReadyKey == key) {
        return;
      }
      setState(() {
        _supplementaryReadyKey = key;
      });
      _lastSupplementaryReadyRequestId = requestId;
      _logPreviewEvent(
        'supplementary_ready',
        memo: memo,
        context: <String, Object?>{
          'requestId': requestId,
          'elapsedMs': _currentCycleElapsedMs(),
        },
      );
    });
  }

  void _completeReveal(int requestId, LocalMemo memo) {
    if (!mounted) return;
    if (_visualRequestId != 0 && _visualRequestId != requestId) {
      return;
    }
    _revealCompleteTimer = null;
    if (_revealStage != _DesktopPreviewRevealStage.revealing) {
      return;
    }
    setState(() => _revealStage = _DesktopPreviewRevealStage.visible);
    _logPreviewEvent(
      'content_reveal_completed',
      memo: memo,
      context: <String, Object?>{
        'requestId': requestId,
        'elapsedMs': _currentCycleElapsedMs(),
      },
    );
  }

  void _logPreviewEvent(
    String event, {
    required LocalMemo memo,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    if (!kDebugMode) return;
    LogManager.instance.info(
      'Desktop preview: $event',
      context: <String, Object?>{
        ...buildMemoContentDiagnostics(memo.content, memoUid: memo.uid),
        ...context,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DesktopMemoPreviewSessionState>(
      desktopMemoPreviewSessionProvider,
      (_, next) => _handleSessionChanged(next),
    );
    ref.watch(desktopMemoPreviewSessionProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.26 : 0.08);
    final headerShadow = _headerElevated
        ? <BoxShadow>[
            BoxShadow(
              color: shadowColor,
              blurRadius: isDark ? 18 : 14,
              offset: const Offset(0, 6),
            ),
          ]
        : const <BoxShadow>[];

    final visibleResolvedData =
        _revealStage == _DesktopPreviewRevealStage.revealing ||
            _revealStage == _DesktopPreviewRevealStage.visible
        ? _stagedData
        : null;
    final showSupplementary =
        visibleResolvedData != null &&
        _revealedKey != null &&
        _supplementaryReadyKey == _revealedKey;
    final canOpenFullDetail =
        _revealStage == _DesktopPreviewRevealStage.visible &&
        visibleResolvedData != null;
    final hasSelection = widget.selectedMemo != null;

    Widget bodyChild;
    if (_revealStage == _DesktopPreviewRevealStage.error) {
      bodyChild = KeyedSubtree(
        key: const ValueKey<String>('desktop-memo-preview-error'),
        child: _PreviewErrorPane(
          message:
              _visualErrorMessage ??
              context.t.strings.legacy.msg_action_failed(e: 'preview'),
          onRetry: () =>
              ref.read(desktopMemoPreviewSessionProvider.notifier).retry(),
        ),
      );
    } else if (visibleResolvedData != null) {
      bodyChild = KeyedSubtree(
        key: ValueKey<String>(
          'desktop-memo-preview-content:'
          '${visibleResolvedData.memo.uid}:'
          '${visibleResolvedData.memo.contentFingerprint}:'
          '${visibleResolvedData.memo.updateTime.microsecondsSinceEpoch}',
        ),
        child: MemoDocumentBody(
          resolvedData: visibleResolvedData,
          header: MemoDocumentPrimaryContent(
            resolvedData: visibleResolvedData,
            readOnly: true,
            isArchived: visibleResolvedData.memo.state == 'ARCHIVED',
            markdownSelectable: true,
          ),
          scrollController: _scrollController,
          showSupplementarySections: showSupplementary,
          shouldShowEngagement: true,
          audioHandle: MemoDocumentAudioHandle(
            isPlayingForUrl: (url) =>
                (_audioPlayer?.playing ?? false) && _currentAudioUrl == url,
            playerStateStream: _audioPlayer?.playerStateStream,
            onTogglePlayAudio: _togglePlayAudio,
          ),
        ),
      );
    } else if (hasSelection) {
      bodyChild = KeyedSubtree(
        key: ValueKey<String>(
          'desktop-memo-preview-loader:${_revealStage.name}',
        ),
        child: _PreviewBodySkeleton(
          backgroundColor: surfaceColor,
          dividerColor: dividerColor,
        ),
      );
    } else {
      bodyChild = const KeyedSubtree(
        key: ValueKey<String>('desktop-memo-preview-empty-pane'),
        child: _PreviewBodyEmptyState(),
      );
    }

    return KeyedSubtree(
      key: const ValueKey<String>('desktop-memo-preview-pane'),
      child: ColoredBox(
        color: surfaceColor,
        child: Column(
          children: [
            AnimatedContainer(
              duration: AppMotion.effectiveDuration(context, AppMotion.fast),
              curve: AppMotion.standardCurve,
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(bottom: BorderSide(color: dividerColor)),
                boxShadow: headerShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t.strings.legacy.msg_preview,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _PreviewPaneActionButton(
                      buttonKey: const ValueKey<String>(
                        'desktop-memo-preview-edit',
                      ),
                      tooltip: context.t.strings.legacy.msg_edit_memo,
                      onPressed: canOpenFullDetail ? widget.onEditMemo : null,
                      icon: Icons.edit_rounded,
                    ),
                    _PreviewPaneActionButton(
                      buttonKey: const ValueKey<String>(
                        'desktop-memo-preview-close',
                      ),
                      tooltip: context.t.strings.legacy.msg_close,
                      onPressed: widget.onClose,
                      icon: Icons.close_rounded,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AppSharedAxisSwitcher(
                duration: AppMotion.desktopPreviewContentReveal,
                reverseDuration: const Duration(milliseconds: 80),
                axis: Axis.vertical,
                offset: 0.01,
                scaleBegin: 0.995,
                switchInCurve: AppMotion.desktopPreviewRevealCurve,
                switchOutCurve: AppMotion.desktopPreviewSwapCurve,
                layoutBuilder: (currentChild, _) =>
                    currentChild ?? const SizedBox.shrink(),
                child: bodyChild,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemosListDesktopPreviewEmptyPane extends StatelessWidget {
  const MemosListDesktopPreviewEmptyPane({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return MemosListDesktopPreviewPane(
      selectedMemo: null,
      isVisible: true,
      onClose: onClose,
      onEditMemo: () {},
    );
  }
}

class _PreviewPaneActionButton extends StatelessWidget {
  const _PreviewPaneActionButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppPressScale(
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _PreviewBodyEmptyState extends StatelessWidget {
  const _PreviewBodyEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.preview_outlined,
              size: 32,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
            const SizedBox(height: 12),
            Text(
              context.t.strings.legacy.msg_preview,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.t.strings.legacy.msg_no_content_yet,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewErrorPane extends StatelessWidget {
  const _PreviewErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.t.strings.legacy.msg_retry_sync),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBodySkeleton extends StatefulWidget {
  const _PreviewBodySkeleton({
    required this.backgroundColor,
    required this.dividerColor,
  });

  final Color backgroundColor;
  final Color dividerColor;

  @override
  State<_PreviewBodySkeleton> createState() => _PreviewBodySkeletonState();
}

class _PreviewBodySkeletonState extends State<_PreviewBodySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.desktopPreviewLoaderPulse,
    );
    _opacity = Tween<double>(
      begin: 0.78,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.isEnabled(context)) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final blockColor = onSurface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.09 : 0.07,
    );

    Widget skeletonLine({
      required double widthFactor,
      double height = 14,
      double radius = 8,
    }) {
      return FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(opacity: _opacity.value, child: child);
      },
      child: Container(
        key: const ValueKey<String>('desktop-memo-preview-skeleton'),
        color: widget.backgroundColor.withValues(alpha: 0.92),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            skeletonLine(widthFactor: 0.52, height: 16),
            const SizedBox(height: 24),
            skeletonLine(widthFactor: 0.92),
            const SizedBox(height: 12),
            skeletonLine(widthFactor: 0.86),
            const SizedBox(height: 12),
            skeletonLine(widthFactor: 0.95),
            const SizedBox(height: 12),
            skeletonLine(widthFactor: 0.74),
            const SizedBox(height: 12),
            skeletonLine(widthFactor: 0.88),
            const SizedBox(height: 28),
            Container(height: 1, color: widget.dividerColor),
            const SizedBox(height: 28),
            skeletonLine(widthFactor: 0.42, height: 12),
            const SizedBox(height: 14),
            skeletonLine(widthFactor: 0.64, height: 12),
          ],
        ),
      ),
    );
  }
}
