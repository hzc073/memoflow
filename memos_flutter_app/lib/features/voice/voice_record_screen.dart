import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../../core/app_localization.dart';
import '../../core/debug_ephemeral_storage.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../state/settings/preferences_provider.dart';
import '../../i18n/strings.g.dart';

class VoiceRecordResult {
  const VoiceRecordResult({
    required this.filePath,
    required this.fileName,
    required this.size,
    required this.duration,
    required this.suggestedContent,
  });

  final String filePath;
  final String fileName;
  final int size;
  final Duration duration;
  final String suggestedContent;
}

enum VoiceRecordPresentation { page, overlay }

enum _VoiceRecordQuickAction { none, discard, lock, draft }

class VoiceRecordOverlayDragSession extends ChangeNotifier {
  Offset _offset = Offset.zero;
  int _gestureEndSequence = 0;

  Offset get offset => _offset;
  int get gestureEndSequence => _gestureEndSequence;

  void update(Offset offset) {
    if (_offset == offset) return;
    _offset = offset;
    notifyListeners();
  }

  void endGesture() {
    _gestureEndSequence += 1;
    notifyListeners();
  }
}

class VoiceRecordScreen extends ConsumerStatefulWidget {
  const VoiceRecordScreen({
    super.key,
    this.presentation = VoiceRecordPresentation.page,
    this.autoStart = false,
    this.dragSession,
  });

  final VoiceRecordPresentation presentation;
  final bool autoStart;
  final VoiceRecordOverlayDragSession? dragSession;

  static Future<VoiceRecordResult?> showOverlay(
    BuildContext context, {
    bool autoStart = true,
    VoiceRecordOverlayDragSession? dragSession,
  }) {
    return showGeneralDialog<VoiceRecordResult>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          VoiceRecordScreen(
            presentation: VoiceRecordPresentation.overlay,
            autoStart: autoStart,
            dragSession: dragSession,
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends ConsumerState<VoiceRecordScreen>
    with TickerProviderStateMixin {
  static const _maxDuration = Duration(minutes: 60);
  static const double _silenceGate = 0.08;
  static const double _voiceActivityGate = 0.18;
  static const int _maxVisualizerBars = 21;
  static const double _defaultHorizontalQuickActionThreshold = 72.0;
  static const double _defaultVerticalQuickActionThreshold = 68.0;
  static const double _compactHorizontalQuickActionThreshold = 56.0;
  static const double _compactVerticalQuickActionThreshold = 52.0;
  static const double _compactActionZoneDiameter = 68.0;
  static const double _compactSideActionCenterX = 118.0;
  static const double _compactSideActionCenterY = -72.0;
  static const double _compactTopActionCenterY = -142.0;

  final _recorder = AudioRecorder();
  final _filenameFmt = DateFormat('yyyyMMdd_HHmmss');
  final _stopwatch = Stopwatch();

  late final AnimationController _blink;
  late final Animation<double> _blinkOpacity;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;

  Duration _elapsed = Duration.zero;
  String? _filePath;
  String? _fileName;
  bool _recording = false;
  bool _paused = false;
  double _ampLevel = 0.0;
  double _ampPeak = 0.0;
  bool _voiceActive = false;
  final List<double> _visualizerSamples = List<double>.filled(
    _maxVisualizerBars,
    0.0,
  );
  int _visualizerCursor = 0;
  bool _awaitingConfirm = false;
  bool _processing = false;
  bool _gestureLocked = false;
  Offset _dragOffset = Offset.zero;
  _VoiceRecordQuickAction _dragPreviewAction = _VoiceRecordQuickAction.none;
  int _handledExternalGestureEndSequence = 0;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _blinkOpacity = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(parent: _blink, curve: Curves.easeInOut));
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_start());
      });
    }
    _attachDragSessionListener();
  }

  @override
  void didUpdateWidget(covariant VoiceRecordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dragSession != widget.dragSession) {
      _detachDragSessionListener(oldWidget.dragSession);
      _attachDragSessionListener();
    }
  }

  @override
  void dispose() {
    _detachDragSessionListener(widget.dragSession);
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _stopwatch.stop();
    _blink.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _attachDragSessionListener() {
    final dragSession = widget.dragSession;
    if (dragSession == null) return;
    _handledExternalGestureEndSequence = dragSession.gestureEndSequence;
    dragSession.addListener(_handleExternalDragSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleExternalDragSessionChanged();
    });
  }

  void _detachDragSessionListener(VoiceRecordOverlayDragSession? dragSession) {
    dragSession?.removeListener(_handleExternalDragSessionChanged);
  }

  void _handleExternalDragSessionChanged() {
    final dragSession = widget.dragSession;
    if (dragSession == null || !mounted) return;

    if (!_gestureLocked && !_awaitingConfirm && !_processing) {
      final nextOffset = dragSession.offset;
      final nextAction = _resolveQuickAction(nextOffset);
      if (nextOffset != _dragOffset || nextAction != _dragPreviewAction) {
        setState(() {
          _dragOffset = nextOffset;
          _dragPreviewAction = nextAction;
        });
      }
    }

    if (dragSession.gestureEndSequence != _handledExternalGestureEndSequence) {
      _handledExternalGestureEndSequence = dragSession.gestureEndSequence;
      unawaited(_handleRecordPanEnd());
    }
  }

  void _resetToIdle() {
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    _stopMeter();
    _resetVisualizer();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
      _elapsed = Duration.zero;
      _filePath = null;
      _fileName = null;
      _awaitingConfirm = false;
      _processing = false;
      _ampLevel = 0.0;
      _ampPeak = 0.0;
      _voiceActive = false;
      _gestureLocked = false;
      _dragOffset = Offset.zero;
      _dragPreviewAction = _VoiceRecordQuickAction.none;
    });
  }

  void _resetVisualizer() {
    for (var i = 0; i < _visualizerSamples.length; i++) {
      _visualizerSamples[i] = 0.0;
    }
    _visualizerCursor = 0;
  }

  void _pushVisualizerSample(double value) {
    if (_visualizerSamples.isEmpty) return;
    _visualizerSamples[_visualizerCursor] = value;
    _visualizerCursor = (_visualizerCursor + 1) % _visualizerSamples.length;
  }

  double _visualizerSampleAt(int index, int totalCount) {
    if (_visualizerSamples.isEmpty) return 0.0;
    final len = _visualizerSamples.length;
    var start = _visualizerCursor - totalCount;
    var idx = (start + index) % len;
    if (idx < 0) idx += len;
    return _visualizerSamples[idx];
  }

  Future<void> _closeScreen() async {
    if (_processing) return;
    if (_recording) {
      try {
        await _recorder.cancel();
      } catch (_) {}
    }
    final path = _filePath;
    if (path != null && path.trim().isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    context.safePop();
  }

  Future<void> _start() async {
    if (_recording) return;
    final micGranted = await _recorder.hasPermission();
    if (!micGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_microphone_permission_required,
          ),
        ),
      );
      return;
    }

    if (isDesktopTargetPlatform()) {
      try {
        final devices = await _recorder.listInputDevices();
        if (devices.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.strings.legacy.msg_no_recording_input_device_found,
              ),
            ),
          );
          return;
        }
      } catch (_) {}
    }

    final dir = await resolveAppDocumentsDirectory();
    final recordingsDir = Directory(p.join(dir.path, 'recordings'));
    if (!recordingsDir.existsSync()) {
      recordingsDir.createSync(recursive: true);
    }

    final now = DateTime.now();
    final fileName = 'voice_${_filenameFmt.format(now)}.m4a';
    final filePath = p.join(recordingsDir.path, fileName);

    setState(() {
      _elapsed = Duration.zero;
      _fileName = fileName;
      _filePath = filePath;
      _paused = false;
      _awaitingConfirm = false;
      _processing = false;
    });

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 16000,
        ),
        path: filePath,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_failed_start_recording(e: e),
          ),
        ),
      );
      _resetToIdle();
      return;
    }

    _resetVisualizer();
    setState(() {
      _recording = true;
      _ampLevel = 0.0;
      _ampPeak = 0.0;
      _voiceActive = false;
    });

    _stopwatch
      ..reset()
      ..start();
    _blink.repeat(reverse: true);
    _startMeter();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_recording || _paused) return;
      final elapsed = _stopwatch.elapsed;
      if (elapsed >= _maxDuration) {
        unawaited(_stopForConfirm());
        return;
      }
      if (mounted) {
        setState(() => _elapsed = elapsed);
      }
    });
  }

  Future<void> _stopForConfirm() async {
    if (!_recording || _processing) return;
    setState(() => _processing = true);
    _ticker?.cancel();
    _blink.stop();
    _stopMeter();
    _stopwatch.stop();

    final elapsed = _stopwatch.elapsed;
    String? stoppedPath;
    try {
      stoppedPath = await _recorder.stop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_failed_stop_recording(e: e),
          ),
        ),
      );
      _resetToIdle();
      return;
    }

    if (!mounted) return;
    if (stoppedPath != null && stoppedPath.trim().isNotEmpty) {
      _filePath = stoppedPath;
      _fileName = p.basename(stoppedPath);
    }

    setState(() {
      _recording = false;
      _paused = false;
      _elapsed = elapsed;
      _ampLevel = 0.0;
      _ampPeak = 0.0;
      _voiceActive = false;
      _awaitingConfirm = true;
      _processing = false;
      _gestureLocked = false;
      _dragOffset = Offset.zero;
      _dragPreviewAction = _VoiceRecordQuickAction.none;
    });
  }

  Future<void> _saveRecording() async {
    if (_processing || !_awaitingConfirm) return;
    setState(() => _processing = true);

    final filePath = _filePath;
    final fileName = _fileName;
    if (filePath == null || fileName == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_recording_info_missing),
          ),
        );
      }
      _resetToIdle();
      return;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_recording_file_not_found,
            ),
          ),
        );
      }
      _resetToIdle();
      return;
    }

    try {
      final size = file.lengthSync();
      final language = ref.read(appPreferencesProvider).language;

      final content = trByLanguageKey(
        language: language,
        key: 'legacy.msg_voice_memo',
      );

      if (!mounted) return;
      setState(() {
        _awaitingConfirm = false;
        _processing = false;
      });
      context.safePop(
        VoiceRecordResult(
          filePath: filePath,
          fileName: fileName,
          size: size,
          duration: _elapsed,
          suggestedContent: content,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_send_failed(e: e))),
      );
    }
  }

  String _formatDisplayDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _normalizeDbfs(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0.0;
    const minDb = -60.0;
    const maxDb = 0.0;
    final clamped = dbfs.clamp(minDb, maxDb);
    return ((clamped - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
  }

  void _startMeter() {
    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
          if (!_recording || _paused) return;
          final level = _normalizeDbfs(amp.current);
          final gated = level < _voiceActivityGate ? 0.0 : level;
          final smoothed = _ampLevel * 0.7 + gated * 0.3;
          final peak = math.max(_ampPeak * 0.92, smoothed);
          final nextLevel = smoothed < _silenceGate ? 0.0 : smoothed;
          final nextPeak = peak < _silenceGate ? 0.0 : peak;
          final hasVoice = nextLevel > 0.0;
          final visualLevel = hasVoice ? nextLevel : 0.0;
          final visualPeak = hasVoice ? nextPeak : 0.0;
          if (mounted) {
            _pushVisualizerSample(visualLevel);
            setState(() {
              _ampLevel = visualLevel;
              _ampPeak = visualPeak;
              _voiceActive = hasVoice;
            });
          }
        }, onError: (_) {});
  }

  void _stopMeter() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _ampLevel = 0.0;
    _ampPeak = 0.0;
    _voiceActive = false;
    _resetVisualizer();
  }

  Future<void> _saveAndReturn() async {
    if (_processing) return;
    if (_recording) {
      await _stopForConfirm();
    }
    if (_awaitingConfirm) {
      await _saveRecording();
    }
  }

  void _toggleGestureLock() {
    if (!_recording || _awaitingConfirm || _processing) return;
    setState(() {
      _gestureLocked = !_gestureLocked;
      _dragOffset = Offset.zero;
      _dragPreviewAction = _VoiceRecordQuickAction.none;
    });
  }

  void _handleRecordPanUpdate(DragUpdateDetails details) {
    if (!_recording || _awaitingConfirm || _processing || _gestureLocked) {
      return;
    }
    final nextOffset = _dragOffset + details.delta;
    final nextAction = _resolveQuickAction(nextOffset);
    if (nextOffset == _dragOffset && nextAction == _dragPreviewAction) {
      return;
    }
    setState(() {
      _dragOffset = nextOffset;
      _dragPreviewAction = nextAction;
    });
  }

  Future<void> _handleRecordPanEnd() async {
    if (_processing) return;
    final action = _dragPreviewAction;
    if (_dragOffset != Offset.zero ||
        _dragPreviewAction != _VoiceRecordQuickAction.none) {
      setState(() {
        _dragOffset = Offset.zero;
        _dragPreviewAction = _VoiceRecordQuickAction.none;
      });
    }
    switch (action) {
      case _VoiceRecordQuickAction.discard:
        await _closeScreen();
        break;
      case _VoiceRecordQuickAction.lock:
        if (mounted) {
          setState(() => _gestureLocked = true);
        }
        break;
      case _VoiceRecordQuickAction.draft:
        await _saveAndReturn();
        break;
      case _VoiceRecordQuickAction.none:
        break;
    }
  }

  _VoiceRecordQuickAction _resolveQuickAction(Offset offset) {
    final compactOverlay = _shouldUseCompactOverlayLayout(
      MediaQuery.maybeSizeOf(context),
    );
    if (compactOverlay) {
      return _resolveCompactOverlayQuickAction(offset);
    }
    final horizontalThreshold = compactOverlay
        ? _compactHorizontalQuickActionThreshold
        : _defaultHorizontalQuickActionThreshold;
    final verticalThreshold = compactOverlay
        ? _compactVerticalQuickActionThreshold
        : _defaultVerticalQuickActionThreshold;
    final dx = offset.dx;
    final dy = offset.dy;
    final horizontalDominant = dx.abs() > dy.abs();
    if (dy <= -verticalThreshold && !horizontalDominant) {
      return _VoiceRecordQuickAction.lock;
    }
    if (dx <= -horizontalThreshold && horizontalDominant) {
      return _VoiceRecordQuickAction.discard;
    }
    if (dx >= horizontalThreshold && horizontalDominant) {
      return _VoiceRecordQuickAction.draft;
    }
    return _VoiceRecordQuickAction.none;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverlay = widget.presentation == VoiceRecordPresentation.overlay;
    final overlay = Colors.black.withValues(alpha: isDark ? 0.18 : 0.08);
    final cardColor = isDark
        ? const Color(0xFF1F1A19)
        : const Color(0xFFFFF9F6);
    final textMain = isDark
        ? const Color(0xFFD1D1D1)
        : MemoFlowPalette.textLight;
    final textMuted = isDark
        ? const Color(0xFFB3A9A4)
        : const Color(0xFF9F938E);
    final recActive = _recording && !_paused;

    final elapsedText = _formatDisplayDuration(_elapsed);
    final limitText = context.tr(
      zh: '\u6700\u957F ${_formatDisplayDuration(_maxDuration)}',
      en: '${_formatDisplayDuration(_maxDuration)} max',
    );
    final size = MediaQuery.sizeOf(context);
    final useCompactOverlay = _shouldUseCompactOverlayLayout(size);
    final cardWidth = math.min(size.width - 24, 408.0).toDouble();
    final cardHeight = math.min(size.height - 28, 820.0).toDouble();
    final bgColor = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final panelColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.62);
    final secondaryPanel = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.74);
    final headerLabel = _awaitingConfirm
        ? context.tr(zh: '\u5F55\u97F3\u5B8C\u6210', en: 'Ready to save')
        : (_recording
              ? context.tr(zh: '\u5F55\u97F3\u4E2D', en: 'Recording')
              : context.t.strings.legacy.msg_voice_memos);
    final lockHint = _gestureLocked
        ? context.tr(
            zh: '\u5DF2\u9501\u5B9A\uFF0C\u70B9\u51FB\u9EA6\u514B\u98CE\u7ED3\u675F',
            en: 'Locked - tap mic to finish',
          )
        : context.tr(zh: '\u4E0A\u6ED1\u9501\u5B9A', en: 'Slide up to lock');
    final discardHint = context.tr(
      zh: '\u5DE6\u6ED1\u653E\u5F03',
      en: 'Slide left to discard',
    );
    final draftHint = context.tr(
      zh: '\u53F3\u6ED1\u8F6C\u8349\u7A3F',
      en: 'Slide right to draft',
    );
    final compactGestureHint = _gestureLocked
        ? context.tr(
            zh: '\u5DF2\u9501\u5B9A\uFF0C\u70B9\u51FB\u9EA6\u514B\u98CE\u7ED3\u675F',
            en: 'Locked - tap mic to finish',
          )
        : context.tr(
            zh: '\u5DE6\u6ED1\u653E\u5F03 \u00B7 \u4E0A\u6ED1\u9501\u5B9A \u00B7 \u53F3\u6ED1\u8F6C\u8349\u7A3F',
            en: 'Left discard - Up lock - Right draft',
          );

    if (useCompactOverlay) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _closeScreen();
        },
        child: _buildCompactOverlayLayout(
          context: context,
          isDark: isDark,
          overlayColor: overlay,
          cardColor: cardColor,
          textMain: textMain,
          textMuted: textMuted,
          panelColor: panelColor,
          secondaryPanel: secondaryPanel,
          recActive: recActive,
          elapsedText: elapsedText,
          headerLabel: headerLabel,
          compactGestureHint: compactGestureHint,
          size: size,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _closeScreen();
      },
      child: Material(
        color: isOverlay ? Colors.transparent : bgColor,
        child: Stack(
          children: [
            Positioned.fill(
              child: isOverlay
                  ? ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: ColoredBox(color: overlay),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            bgColor,
                            MemoFlowPalette.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                    ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.03),
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: isOverlay ? 34 : 26,
                            offset: const Offset(0, 18),
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.34 : 0.1,
                            ),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: -24,
                            top: -18,
                            child: IgnorePointer(
                              child: Container(
                                width: 168,
                                height: 168,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: MemoFlowPalette.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 80,
                                      color: MemoFlowPalette.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -18,
                            bottom: 96,
                            child: IgnorePointer(
                              child: Container(
                                width: 124,
                                height: 124,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: MemoFlowPalette.primary.withValues(
                                    alpha: 0.06,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 60,
                                      color: MemoFlowPalette.primary.withValues(
                                        alpha: 0.06,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: panelColor,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildRecDot(active: recActive),
                                          const SizedBox(width: 8),
                                          Text(
                                            'REC',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.6,
                                              color: textMain.withValues(
                                                alpha: 0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      headerLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  elapsedText,
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                    color: isDark
                                        ? const Color(0xFFF7F1EE)
                                        : textMain,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  limitText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      width: double.infinity,
                                      constraints: const BoxConstraints(
                                        maxWidth: 312,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 26,
                                      ),
                                      decoration: BoxDecoration(
                                        color: secondaryPanel,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 132,
                                            child: _buildWaveform(
                                              isDark: false,
                                              level: recActive
                                                  ? _ampLevel
                                                  : 0.0,
                                              peak: recActive ? _ampPeak : 0.0,
                                              showVoiceBars:
                                                  recActive && _voiceActive,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          AnimatedOpacity(
                                            opacity:
                                                (_recording &&
                                                    !_awaitingConfirm)
                                                ? 1.0
                                                : 0.55,
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.arrow_upward_rounded,
                                                  size: 16,
                                                  color: MemoFlowPalette.primary
                                                      .withValues(alpha: 0.85),
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    lockHint,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: MemoFlowPalette
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.85,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildQuickActionButton(
                                      icon: Icons.chevron_left_rounded,
                                      active:
                                          _dragPreviewAction ==
                                          _VoiceRecordQuickAction.discard,
                                      enabled: !_processing,
                                      onTap: () => unawaited(_closeScreen()),
                                      foreground: MemoFlowPalette.primary,
                                    ),
                                    const SizedBox(width: 18),
                                    _buildQuickActionButton(
                                      icon: _gestureLocked
                                          ? Icons.lock_rounded
                                          : Icons.lock_open_rounded,
                                      active:
                                          _dragPreviewAction ==
                                              _VoiceRecordQuickAction.lock ||
                                          _gestureLocked,
                                      enabled:
                                          _recording &&
                                          !_awaitingConfirm &&
                                          !_processing,
                                      onTap: _toggleGestureLock,
                                      foreground: MemoFlowPalette.primary,
                                    ),
                                    const SizedBox(width: 18),
                                    _buildQuickActionButton(
                                      icon: Icons.notes_rounded,
                                      active:
                                          _dragPreviewAction ==
                                          _VoiceRecordQuickAction.draft,
                                      enabled:
                                          !_processing &&
                                          (_recording || _awaitingConfirm),
                                      onTap: () => unawaited(_saveAndReturn()),
                                      foreground: _awaitingConfirm
                                          ? MemoFlowPalette.primary
                                          : textMain.withValues(alpha: 0.8),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _buildPrimaryButton(isDark: isDark),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        discardHint,
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        draftHint,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              tooltip: context.t.strings.legacy.msg_close,
                              onPressed: _processing
                                  ? null
                                  : () => unawaited(_closeScreen()),
                              icon: Icon(
                                Icons.close_rounded,
                                color: textMain.withValues(alpha: 0.66),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldUseCompactOverlayLayout(Size? size) {
    if (widget.presentation != VoiceRecordPresentation.overlay ||
        size == null) {
      return false;
    }
    return size.height >= 560 && size.height >= size.width;
  }

  double _dragProgressForAction(
    _VoiceRecordQuickAction action, {
    required bool compact,
  }) {
    final horizontalThreshold = compact
        ? _compactHorizontalQuickActionThreshold
        : _defaultHorizontalQuickActionThreshold;
    final verticalThreshold = compact
        ? _compactVerticalQuickActionThreshold
        : _defaultVerticalQuickActionThreshold;

    switch (action) {
      case _VoiceRecordQuickAction.discard:
        return (-_dragOffset.dx / horizontalThreshold).clamp(0.0, 1.0);
      case _VoiceRecordQuickAction.lock:
        return (-_dragOffset.dy / verticalThreshold).clamp(0.0, 1.0);
      case _VoiceRecordQuickAction.draft:
        return (_dragOffset.dx / horizontalThreshold).clamp(0.0, 1.0);
      case _VoiceRecordQuickAction.none:
        return 0.0;
    }
  }

  _VoiceRecordQuickAction _resolveCompactOverlayQuickAction(Offset offset) {
    final translatedOffset = _compactOverlayBaseButtonOffset(offset);
    final hitRadius = (_compactActionZoneDiameter / 2) + 8;
    final candidates = <(_VoiceRecordQuickAction, Offset)>[
      (
        _VoiceRecordQuickAction.discard,
        const Offset(-_compactSideActionCenterX, _compactSideActionCenterY),
      ),
      (_VoiceRecordQuickAction.lock, const Offset(0, _compactTopActionCenterY)),
      (
        _VoiceRecordQuickAction.draft,
        const Offset(_compactSideActionCenterX, _compactSideActionCenterY),
      ),
    ];

    _VoiceRecordQuickAction matchedAction = _VoiceRecordQuickAction.none;
    double matchedDistance = double.infinity;
    for (final candidate in candidates) {
      final distance = (translatedOffset - candidate.$2).distance;
      if (distance <= hitRadius && distance < matchedDistance) {
        matchedDistance = distance;
        matchedAction = candidate.$1;
      }
    }
    return matchedAction;
  }

  Offset _compactOverlayBaseButtonOffset(Offset rawOffset) {
    final clampedDx = rawOffset.dx.clamp(
      -_compactHorizontalQuickActionThreshold * 2.3,
      _compactHorizontalQuickActionThreshold * 2.3,
    );
    final clampedDy = rawOffset.dy.clamp(_compactTopActionCenterY - 10, 0.0);
    return Offset(clampedDx * 0.78, clampedDy * 0.9);
  }

  Offset _dragTranslationForPrimaryButton({required bool compact}) {
    if (!compact || _gestureLocked || _awaitingConfirm) {
      return Offset.zero;
    }
    final baseOffset = compact
        ? _compactOverlayBaseButtonOffset(_dragOffset)
        : Offset(
            _dragOffset.dx.clamp(
                  -_defaultHorizontalQuickActionThreshold,
                  _defaultHorizontalQuickActionThreshold,
                ) *
                0.78,
            _dragOffset.dy.clamp(-_defaultVerticalQuickActionThreshold, 0.0) *
                0.9,
          );
    final activeAction = _resolveQuickAction(_dragOffset);
    final actionProgress = _dragProgressForAction(
      activeAction,
      compact: compact,
    );

    switch (activeAction) {
      case _VoiceRecordQuickAction.discard:
        return baseOffset + Offset(-12 * actionProgress, -2 * actionProgress);
      case _VoiceRecordQuickAction.lock:
        return baseOffset + Offset(0, -14 * actionProgress);
      case _VoiceRecordQuickAction.draft:
        return baseOffset + Offset(12 * actionProgress, -2 * actionProgress);
      case _VoiceRecordQuickAction.none:
        return baseOffset;
    }
  }

  Widget _buildCompactOverlayLayout({
    required BuildContext context,
    required bool isDark,
    required Color overlayColor,
    required Color cardColor,
    required Color textMain,
    required Color textMuted,
    required Color panelColor,
    required Color secondaryPanel,
    required bool recActive,
    required String elapsedText,
    required String headerLabel,
    required String compactGestureHint,
    required Size size,
  }) {
    final panelWidth = math.min(size.width - 12, 420.0).toDouble();
    final panelHeight = (size.height * 0.38).clamp(300.0, 352.0).toDouble();
    final closeColor = textMain.withValues(alpha: 0.66);
    final discardProgress = _dragProgressForAction(
      _VoiceRecordQuickAction.discard,
      compact: true,
    );
    final lockProgress = _dragProgressForAction(
      _VoiceRecordQuickAction.lock,
      compact: true,
    );
    final draftProgress = _dragProgressForAction(
      _VoiceRecordQuickAction.draft,
      compact: true,
    );
    final dragOffset = _dragTranslationForPrimaryButton(compact: true);
    final dragEmphasis = math.max(
      discardProgress,
      math.max(lockProgress, draftProgress),
    );
    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: Offset.zero, end: dragOffset),
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          builder: (context, animatedOffset, child) {
            return Transform.translate(offset: animatedOffset, child: child);
          },
          child: AnimatedScale(
            scale: 1 - (dragEmphasis * 0.05),
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: _buildPrimaryButton(
              isDark: isDark,
              compact: true,
              surfaceColor: cardColor,
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ColoredBox(color: overlayColor),
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.03),
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.34 : 0.1,
                          ),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tight = constraints.maxHeight < 320;
                        final contentPadding = tight
                            ? const EdgeInsets.fromLTRB(18, 16, 18, 16)
                            : const EdgeInsets.fromLTRB(20, 18, 20, 18);
                        final timerFontSize = tight ? 28.0 : 30.0;
                        final waveformHeight = tight ? 60.0 : 70.0;
                        final waveformMaxWidth = tight ? 260.0 : 280.0;
                        final bottomReserve = tight ? 42.0 : 52.0;
                        final timerGap = tight ? 8.0 : 10.0;
                        final sectionGap = tight ? 10.0 : 12.0;

                        return Stack(
                          children: [
                            Padding(
                              padding: contentPadding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: panelColor,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildRecDot(active: recActive),
                                            const SizedBox(width: 8),
                                            Text(
                                              'REC',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.6,
                                                color: textMain.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          headerLabel,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 28),
                                    ],
                                  ),
                                  SizedBox(height: timerGap),
                                  Text(
                                    elapsedText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: timerFontSize,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                      color: isDark
                                          ? const Color(0xFFF7F1EE)
                                          : textMain,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  Center(
                                    child: Container(
                                      width: double.infinity,
                                      constraints: BoxConstraints(
                                        maxWidth: waveformMaxWidth,
                                      ),
                                      height: waveformHeight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: secondaryPanel,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                        ),
                                      ),
                                      child: Center(
                                        child: _buildWaveform(
                                          isDark: false,
                                          level: recActive ? _ampLevel : 0.0,
                                          peak: recActive ? _ampPeak : 0.0,
                                          showVoiceBars:
                                              recActive && _voiceActive,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  Text(
                                    compactGestureHint,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  SizedBox(height: bottomReserve),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: IconButton(
                                tooltip: context.t.strings.legacy.msg_close,
                                onPressed: _processing
                                    ? null
                                    : () => unawaited(_closeScreen()),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: closeColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 340,
                  height: 220,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        left: 30,
                        bottom: 38,
                        child: _buildOverlayQuickActionZone(
                          icon: Icons.close_rounded,
                          active:
                              _dragPreviewAction ==
                              _VoiceRecordQuickAction.discard,
                          enabled: !_processing,
                          onTap: () => unawaited(_closeScreen()),
                          progress: discardProgress,
                          width: _compactActionZoneDiameter,
                          height: _compactActionZoneDiameter,
                          translation: Offset(
                            -discardProgress * 12,
                            -discardProgress * 2,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 108,
                        child: _buildOverlayQuickActionZone(
                          icon: _gestureLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          active:
                              _dragPreviewAction ==
                                  _VoiceRecordQuickAction.lock ||
                              _gestureLocked,
                          enabled:
                              _recording && !_awaitingConfirm && !_processing,
                          onTap: _toggleGestureLock,
                          progress: lockProgress,
                          width: _compactActionZoneDiameter,
                          height: _compactActionZoneDiameter,
                          translation: Offset(0, -lockProgress * 14),
                        ),
                      ),
                      Positioned(
                        right: 30,
                        bottom: 38,
                        child: _buildOverlayQuickActionZone(
                          icon: Icons.notes_rounded,
                          active:
                              _dragPreviewAction ==
                              _VoiceRecordQuickAction.draft,
                          enabled:
                              !_processing && (_recording || _awaitingConfirm),
                          onTap: () => unawaited(_saveAndReturn()),
                          progress: draftProgress,
                          width: _compactActionZoneDiameter,
                          height: _compactActionZoneDiameter,
                          translation: Offset(
                            draftProgress * 12,
                            -draftProgress * 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecDot({required bool active}) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
    if (!active) {
      return Opacity(opacity: 0.4, child: dot);
    }
    return FadeTransition(opacity: _blinkOpacity, child: dot);
  }

  Widget _buildPrimaryButton({
    required bool isDark,
    bool compact = false,
    Color? surfaceColor,
  }) {
    final showStop = _recording && !_awaitingConfirm;
    final enabled = !_processing;
    final showConfirm = _awaitingConfirm;
    final amplitudeScale = showStop
        ? (1 + (_ampPeak.clamp(0.0, 1.0) * 0.16))
        : 1.0;
    final gestureSize = compact ? 64.0 : 132.0;
    final pulseRingSize = compact ? 76.0 : 116.0;
    final innerRingSize = compact ? 70.0 : 96.0;
    final filledCoreSize = compact ? 64.0 : 82.0;
    final idleIconSize = compact ? 28.0 : 36.0;
    final confirmIconSize = compact ? 28.0 : 34.0;
    final stopSize = compact ? 20.0 : 24.0;
    final outerBorderColor =
        surfaceColor ??
        (isDark
            ? MemoFlowPalette.backgroundDark
            : MemoFlowPalette.backgroundLight);
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.6,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTap: enabled
            ? () {
                if (showConfirm) {
                  unawaited(_saveAndReturn());
                  return;
                }
                unawaited(showStop ? _stopForConfirm() : _start());
              }
            : null,
        onPanUpdate: enabled ? _handleRecordPanUpdate : null,
        onPanEnd: enabled ? (_) => unawaited(_handleRecordPanEnd()) : null,
        onPanCancel: enabled
            ? () {
                if (_dragOffset == Offset.zero &&
                    _dragPreviewAction == _VoiceRecordQuickAction.none) {
                  return;
                }
                setState(() {
                  _dragOffset = Offset.zero;
                  _dragPreviewAction = _VoiceRecordQuickAction.none;
                });
              }
            : null,
        child: SizedBox(
          width: gestureSize,
          height: gestureSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                scale: amplitudeScale,
                duration: const Duration(milliseconds: 140),
                child: Container(
                  width: pulseRingSize,
                  height: pulseRingSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MemoFlowPalette.primary.withValues(alpha: 0.12),
                      width: 6,
                    ),
                  ),
                ),
              ),
              Container(
                width: innerRingSize,
                height: innerRingSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MemoFlowPalette.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: filledCoreSize,
                height: filledCoreSize,
                decoration: BoxDecoration(
                  color: MemoFlowPalette.primary,
                  shape: BoxShape.circle,
                  border: compact
                      ? Border.all(color: outerBorderColor, width: 4)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: compact ? 24 : (isDark ? 24 : 18),
                      offset: compact ? const Offset(0, 10) : Offset.zero,
                      color: MemoFlowPalette.primary.withValues(
                        alpha: compact
                            ? (isDark ? 0.2 : 0.3)
                            : (isDark ? 0.3 : 0.26),
                      ),
                    ),
                  ],
                ),
                child: Center(
                  child: showConfirm
                      ? Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: confirmIconSize,
                        )
                      : showStop
                      ? Container(
                          width: stopSize,
                          height: stopSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              compact ? 5 : 4,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: idleIconSize,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayQuickActionZone({
    required IconData icon,
    required bool active,
    required bool enabled,
    required VoidCallback onTap,
    required double progress,
    required double width,
    required double height,
    Offset translation = Offset.zero,
  }) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final background = Color.lerp(
      Colors.white.withValues(alpha: 0.84),
      MemoFlowPalette.primary.withValues(alpha: 0.18),
      active ? 1.0 : (clampedProgress * 0.85),
    );
    final foreground = active
        ? MemoFlowPalette.primary
        : MemoFlowPalette.textLight.withValues(alpha: enabled ? 0.88 : 0.46);

    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: Offset.zero, end: translation),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      builder: (context, animatedOffset, child) {
        return Transform.translate(offset: animatedOffset, child: child);
      },
      child: AnimatedScale(
        scale: active ? 1.08 : (1.0 + (clampedProgress * 0.06)),
        duration: const Duration(milliseconds: 140),
        child: AnimatedOpacity(
          opacity: enabled ? (0.8 + (clampedProgress * 0.2)) : 0.45,
          duration: const Duration(milliseconds: 140),
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: MemoFlowPalette.primary.withValues(
                    alpha: active ? 0.24 : (0.08 + (clampedProgress * 0.12)),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                    color: Colors.black.withValues(
                      alpha: 0.06 + (clampedProgress * 0.03),
                    ),
                  ),
                ],
              ),
              child: Center(child: Icon(icon, size: 22, color: foreground)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool active,
    required bool enabled,
    required VoidCallback onTap,
    required Color foreground,
    double size = 50,
    double iconSize = 24,
    double progress = 0,
    Offset translation = Offset.zero,
  }) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final background = Color.lerp(
      Colors.white.withValues(alpha: 0.78),
      MemoFlowPalette.primary.withValues(alpha: 0.16),
      active ? 1.0 : (clampedProgress * 0.8),
    );
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: Offset.zero, end: translation),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      builder: (context, animatedOffset, child) {
        return Transform.translate(offset: animatedOffset, child: child);
      },
      child: AnimatedScale(
        scale: active ? 1.08 : (1.0 + (clampedProgress * 0.08)),
        duration: const Duration(milliseconds: 140),
        child: AnimatedOpacity(
          opacity: enabled ? (0.82 + (clampedProgress * 0.18)) : 0.42,
          duration: const Duration(milliseconds: 140),
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: size <= 44 ? 14 : 18,
                    offset: Offset(0, size <= 44 ? 6 : 8),
                    color: Colors.black.withValues(
                      alpha: 0.06 + (clampedProgress * 0.03),
                    ),
                  ),
                ],
              ),
              child: Icon(icon, size: iconSize, color: foreground),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform({
    required bool isDark,
    required double level,
    required double peak,
    required bool showVoiceBars,
  }) {
    final leftBars = isDark
        ? const [32.0, 48.0, 80.0, 56.0, 112.0]
        : const [24.0, 48.0, 80.0, 32.0, 56.0, 128.0, 40.0, 64.0];
    final centerBars = isDark
        ? const [144.0, 192.0, 128.0, 96.0]
        : const [96.0, 160.0, 112.0, 192.0, 80.0];
    final rightBars = isDark
        ? const [16.0, 16.0, 16.0, 16.0, 16.0]
        : const [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0];

    final leftColor = isDark
        ? const Color(0xFF8E8E8E).withValues(alpha: 0.4)
        : MemoFlowPalette.textLight.withValues(alpha: 0.3);
    final centerColor = isDark
        ? const Color(0xFFD1D1D1)
        : MemoFlowPalette.textLight;
    final rightColor = isDark
        ? const Color(0xFF8E8E8E).withValues(alpha: 0.2)
        : MemoFlowPalette.textLight.withValues(alpha: 0.1);
    final idleDashColor = isDark
        ? const Color(0xFF8E8E8E).withValues(alpha: 0.65)
        : MemoFlowPalette.textLight.withValues(alpha: 0.28);

    Widget buildVoiceBars() {
      double scaleFor(
        double base,
        double sampleLevel,
        double minScale,
        double maxScale,
      ) {
        final scale =
            minScale + (maxScale - minScale) * sampleLevel.clamp(0.0, 1.0);
        return math.max(4.0, base * scale);
      }

      final bars = <Widget>[];
      final totalBars = leftBars.length + centerBars.length + rightBars.length;
      var sampleIndex = 0;
      double nextSample() {
        final value = _visualizerSampleAt(sampleIndex, totalBars);
        sampleIndex += 1;
        return value;
      }

      void addBars(
        List<double> heights,
        Color color,
        double minScale,
        double maxScale,
      ) {
        for (final h in heights) {
          final sample = nextSample();
          final scaled = scaleFor(h, sample, minScale, maxScale);
          bars.add(_buildWaveBar(height: scaled, color: color));
          bars.add(const SizedBox(width: 4));
        }
      }

      addBars(leftBars, leftColor, 0.25, 0.95);
      addBars(centerBars, centerColor, 0.35, 1.15);
      addBars(rightBars, rightColor, 0.2, 0.7);

      if (bars.isNotEmpty) {
        bars.removeLast();
      }
      return Row(mainAxisSize: MainAxisSize.min, children: bars);
    }

    Widget buildIdleDashes() {
      return LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 2.0;
          const dashHeight = 12.0;
          const dashGap = 4.0;
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 260.0;
          final dashCount = math.max(
            16,
            (maxWidth / (dashWidth + dashGap)).floor(),
          );
          final dashes = <Widget>[];
          for (var i = 0; i < dashCount; i++) {
            dashes.add(
              Container(
                width: dashWidth,
                height: dashHeight,
                decoration: BoxDecoration(
                  color: idleDashColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
            if (i != dashCount - 1) {
              dashes.add(const SizedBox(width: dashGap));
            }
          }
          return Row(mainAxisSize: MainAxisSize.min, children: dashes);
        },
      );
    }

    final lineColor = const Color(0xFF22C55E);
    final lineHeight = 80.0 + 140.0 * math.max(level, peak);
    final line = SizedBox(
      width: 2,
      height: lineHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? lineColor : lineColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            top: -4,
            left: -3,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: lineColor,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          blurRadius: 8,
                          color: lineColor.withValues(alpha: 0.6),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [showVoiceBars ? buildVoiceBars() : buildIdleDashes(), line],
    );
  }

  Widget _buildWaveBar({required double height, required Color color}) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
