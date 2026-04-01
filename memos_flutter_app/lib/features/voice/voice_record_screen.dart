import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../../core/app_localization.dart';
import '../../core/debug_ephemeral_storage.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../state/settings/preferences_provider.dart';
import '../../i18n/strings.g.dart';
import 'android_quick_spectrum_recorder.dart';
import 'quick_spectrum_animator.dart';
import 'quick_spectrum_frame.dart';

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

enum VoiceRecordMode { standard, quickFabCompose }

enum _VoiceRecordQuickAction { none, discard, lock, draft }

abstract interface class VoiceRecordRecorder {
  Future<bool> hasPermission();
  Future<bool> hasInputDevice();
  Future<void> start({required String path});
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> cancel();
  Stream<Amplitude> onAmplitudeChanged(Duration interval);
  void dispose();
}

class AudioRecorderVoiceRecordRecorder implements VoiceRecordRecorder {
  AudioRecorderVoiceRecordRecorder() : _delegate = AudioRecorder();

  final AudioRecorder _delegate;

  @override
  Future<bool> hasPermission() => _delegate.hasPermission();

  @override
  Future<bool> hasInputDevice() async {
    try {
      final devices = await _delegate.listInputDevices();
      return devices.isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> start({required String path}) {
    return _delegate.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
      ),
      path: path,
    );
  }

  @override
  Future<void> pause() => _delegate.pause();

  @override
  Future<void> resume() => _delegate.resume();

  @override
  Future<String?> stop() => _delegate.stop();

  @override
  Future<void> cancel() => _delegate.cancel();

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    return _delegate.onAmplitudeChanged(interval);
  }

  @override
  void dispose() {
    _delegate.dispose();
  }
}

typedef VoiceRecordDocumentsDirectoryResolver = Future<Directory> Function();
typedef VoiceRecordNowProvider = DateTime Function();
typedef VoiceRecordCompletionHandler = void Function(VoiceRecordResult? result);

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
    this.mode = VoiceRecordMode.standard,
    this.recorder,
    this.quickSpectrumRecorder,
    this.documentsDirectoryResolver,
    this.nowProvider,
    this.onComplete,
  });

  final VoiceRecordPresentation presentation;
  final bool autoStart;
  final VoiceRecordOverlayDragSession? dragSession;
  final VoiceRecordMode mode;
  final VoiceRecordRecorder? recorder;
  final AndroidQuickSpectrumRecorder? quickSpectrumRecorder;
  final VoiceRecordDocumentsDirectoryResolver? documentsDirectoryResolver;
  final VoiceRecordNowProvider? nowProvider;
  final VoiceRecordCompletionHandler? onComplete;

  static Future<VoiceRecordResult?> showOverlay(
    BuildContext context, {
    bool autoStart = true,
    VoiceRecordOverlayDragSession? dragSession,
    VoiceRecordMode mode = VoiceRecordMode.standard,
  }) {
    if (mode == VoiceRecordMode.quickFabCompose) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        final completer = Completer<VoiceRecordResult?>();
        late final OverlayEntry entry;
        var completed = false;

        void complete(VoiceRecordResult? result) {
          if (completed) return;
          completed = true;
          entry.remove();
          completer.complete(result);
        }

        entry = OverlayEntry(
          builder: (overlayContext) => Positioned.fill(
            child: VoiceRecordScreen(
              presentation: VoiceRecordPresentation.overlay,
              autoStart: autoStart,
              dragSession: dragSession,
              mode: mode,
              onComplete: complete,
            ),
          ),
        );
        overlay.insert(entry);
        return completer.future;
      }
    }
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
            mode: mode,
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
  static const int _visualizerHistoryLength = 64;
  static const Duration _standardAmplitudeInterval = Duration(
    milliseconds: 120,
  );
  static const Duration _quickAmplitudeInterval = Duration(milliseconds: 36);
  static const double _quickWaveformMaxAmplitudeFactor = 0.56;
  static const double _quickWaveformMinBarHalfHeight = 4.0;
  static const double _quickWaveformResponseExponent = 1.2;
  static const double _quickNoiseFloorDb = -50.0;
  static const double _quickVoiceActivityGate = 0.22;
  static const double _quickSilenceGate = 0.12;
  static const double _quickSpectrumDisplayGate = 0.18;
  static const double _quickAmplitudeGamma = 0.95;
  static const double _quickSmoothingRetain = 0.24;
  static const double _quickPeakDecay = 0.82;
  static const double _quickVisualizerRawBlend = 0.72;
  static const double _defaultHorizontalQuickActionThreshold = 72.0;
  static const double _defaultVerticalQuickActionThreshold = 68.0;
  static const double _compactHorizontalQuickActionThreshold = 56.0;
  static const double _compactVerticalQuickActionThreshold = 52.0;
  static const double _compactActionZoneDiameter = 68.0;
  static const double _compactSideActionCenterX = 118.0;
  static const double _compactSideActionCenterY = -72.0;
  static const double _compactTopActionCenterY = -142.0;
  static const double _compactQuickDiscardActivationX = 54.0;
  static const double _compactQuickLockActivationX = 54.0;
  static const double _compactQuickDiscardMaxY = 28.0;

  late final VoiceRecordRecorder _recorder =
      widget.recorder ?? AudioRecorderVoiceRecordRecorder();
  late final AndroidQuickSpectrumRecorder? _quickSpectrumRecorder =
      widget.mode == VoiceRecordMode.quickFabCompose
      ? (widget.quickSpectrumRecorder ??
            (Platform.isAndroid ? AndroidQuickSpectrumRecorder() : null))
      : null;
  final _filenameFmt = DateFormat('yyyyMMdd_HHmmss');
  final _stopwatch = Stopwatch();
  final QuickSpectrumAnimator _quickSpectrumAnimator = QuickSpectrumAnimator(
    barCount: QuickSpectrumFrame.barCount,
  );

  late final AnimationController _blink;
  late final Animation<double> _blinkOpacity;
  late final Ticker _spectrumTicker;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<QuickSpectrumFrame>? _quickSpectrumFrameSub;

  Duration _elapsed = Duration.zero;
  String? _filePath;
  String? _fileName;
  bool _recording = false;
  bool _paused = false;
  double _ampLevel = 0.0;
  double _ampPeak = 0.0;
  bool _voiceActive = false;
  Duration? _lastSpectrumTickElapsed;
  final List<double> _visualizerSamples = List<double>.filled(
    _visualizerHistoryLength,
    0.0,
  );
  int _visualizerCursor = 0;
  bool _awaitingConfirm = false;
  bool _processing = false;
  bool _gestureLocked = false;
  Offset _dragOffset = Offset.zero;
  _VoiceRecordQuickAction _dragPreviewAction = _VoiceRecordQuickAction.none;
  int _handledExternalGestureEndSequence = 0;

  bool get _isQuickFabComposeMode =>
      widget.mode == VoiceRecordMode.quickFabCompose;
  bool get _usesPageQuickPauseAction =>
      _isQuickFabComposeMode &&
      widget.presentation == VoiceRecordPresentation.page;
  bool get _usesNativeQuickSpectrum => _quickSpectrumRecorder != null;
  bool get _supportsDraftQuickAction => !_isQuickFabComposeMode;

  void _finish([VoiceRecordResult? result]) {
    final onComplete = widget.onComplete;
    if (onComplete != null) {
      onComplete(result);
      return;
    }
    if (!mounted) return;
    context.safePop(result);
  }

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
    _spectrumTicker = createTicker(_handleSpectrumTick);
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
    _quickSpectrumFrameSub?.cancel();
    _spectrumTicker.dispose();
    _stopwatch.stop();
    _blink.dispose();
    if (widget.quickSpectrumRecorder == null) {
      _quickSpectrumRecorder?.dispose();
    }
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
    _resetSpectrum(hard: true);
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

  void _resetSpectrum({required bool hard}) {
    _quickSpectrumAnimator.reset(hard: hard);
    _lastSpectrumTickElapsed = null;
    if (hard) {
      _spectrumTicker.stop();
    } else if (!_spectrumTicker.isActive) {
      _spectrumTicker.start();
    }
  }

  void _startSpectrumFeed() {
    _quickSpectrumFrameSub?.cancel();
    if (!_usesNativeQuickSpectrum) {
      _resetSpectrum(hard: true);
      return;
    }
    _resetSpectrum(hard: true);
    _spectrumTicker.start();
    _quickSpectrumFrameSub = _quickSpectrumRecorder!.frames.listen((frame) {
      _quickSpectrumAnimator.setTargetBars(frame.bars);
      _ampLevel = frame.rmsLevel;
      _ampPeak = frame.peakLevel;
      _voiceActive = frame.hasVoice;
    });
  }

  void _stopSpectrumFeed({required bool hard}) {
    _quickSpectrumFrameSub?.cancel();
    _quickSpectrumFrameSub = null;
    _resetSpectrum(hard: hard);
  }

  void _handleSpectrumTick(Duration elapsed) {
    if (!_usesNativeQuickSpectrum) return;
    final previousElapsed = _lastSpectrumTickElapsed;
    _lastSpectrumTickElapsed = elapsed;
    if (previousElapsed == null) return;

    final deltaSeconds =
        ((elapsed - previousElapsed).inMicroseconds /
                Duration.microsecondsPerSecond)
            .clamp(1 / 240, 1 / 20);
    final changed = _quickSpectrumAnimator.tick(deltaSeconds);

    if (changed && mounted) {
      setState(() {});
      return;
    }

    if (!_quickSpectrumAnimator.hasVisibleBars && !_recording) {
      _spectrumTicker.stop();
    }
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

  List<double> _visualizerHistory() {
    final totalCount = _visualizerSamples.length;
    return List<double>.generate(
      totalCount,
      (index) => _visualizerSampleAt(index, totalCount),
      growable: false,
    );
  }

  Future<void> _closeScreen() async {
    if (_processing) return;
    if (_recording) {
      try {
        if (_usesNativeQuickSpectrum) {
          await _quickSpectrumRecorder!.cancel();
        } else {
          await _recorder.cancel();
        }
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
    _finish();
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
      final hasInputDevice = await _recorder.hasInputDevice();
      if (!hasInputDevice) {
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
    }

    final dir =
        await (widget.documentsDirectoryResolver ??
            resolveAppDocumentsDirectory)();
    final recordingsDir = Directory(p.join(dir.path, 'recordings'));
    if (!recordingsDir.existsSync()) {
      recordingsDir.createSync(recursive: true);
    }

    final now = (widget.nowProvider ?? DateTime.now)();
    final fileExtension = 'm4a';
    final fileName = 'voice_${_filenameFmt.format(now)}.$fileExtension';
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
      if (_usesNativeQuickSpectrum) {
        await _quickSpectrumRecorder!.start(path: filePath);
      } else {
        await _recorder.start(path: filePath);
      }
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
    if (_usesNativeQuickSpectrum) {
      _startSpectrumFeed();
    }
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
    await _stopRecording(autoComplete: false);
  }

  Future<void> _stopRecording({required bool autoComplete}) async {
    if (!_recording || _processing) return;
    setState(() => _processing = true);
    _ticker?.cancel();
    _blink.stop();
    _stopMeter();
    _stopwatch.stop();

    final elapsed = _stopwatch.elapsed;
    String? stoppedPath;
    try {
      stoppedPath = _usesNativeQuickSpectrum
          ? await _quickSpectrumRecorder!.stop()
          : await _recorder.stop();
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

    final nextElapsed = elapsed;
    if (autoComplete) {
      setState(() {
        _recording = false;
        _paused = false;
        _elapsed = nextElapsed;
        _ampLevel = 0.0;
        _ampPeak = 0.0;
        _voiceActive = false;
        _awaitingConfirm = false;
        _gestureLocked = false;
        _dragOffset = Offset.zero;
        _dragPreviewAction = _VoiceRecordQuickAction.none;
      });
      await _completeAndPopRecording();
      return;
    }

    setState(() {
      _recording = false;
      _paused = false;
      _elapsed = nextElapsed;
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
    await _completeAndPopRecording();
  }

  Future<void> _completeAndPopRecording() async {
    final result = _buildRecordingResult();
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _awaitingConfirm = false;
      _processing = false;
      _gestureLocked = false;
      _dragOffset = Offset.zero;
      _dragPreviewAction = _VoiceRecordQuickAction.none;
    });
    _finish(result);
  }

  VoiceRecordResult? _buildRecordingResult() {
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
      return null;
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
      return null;
    }

    try {
      final size = file.lengthSync();
      final language = ref.read(appPreferencesProvider).language;
      final content = trByLanguageKey(
        language: language,
        key: 'legacy.msg_voice_memo',
      );
      return VoiceRecordResult(
        filePath: filePath,
        fileName: fileName,
        size: size,
        duration: _elapsed,
        suggestedContent: content,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_send_failed(e: e)),
          ),
        );
      }
      return null;
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

  double _normalizeQuickDbfs(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0.0;
    const maxDb = 0.0;
    final clamped = dbfs.clamp(_quickNoiseFloorDb, maxDb);
    final normalized =
        ((clamped - _quickNoiseFloorDb) / (maxDb - _quickNoiseFloorDb)).clamp(
          0.0,
          1.0,
        );
    return math.pow(normalized, _quickAmplitudeGamma).toDouble();
  }

  void _startMeter() {
    if (_usesNativeQuickSpectrum) {
      _ampLevel = 0.0;
      _ampPeak = 0.0;
      _voiceActive = false;
      return;
    }
    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(
          _isQuickFabComposeMode
              ? _quickAmplitudeInterval
              : _standardAmplitudeInterval,
        )
        .listen((amp) {
          if (!_recording || _paused) return;
          final quickMode = _isQuickFabComposeMode;
          final level = quickMode
              ? _normalizeQuickDbfs(amp.current)
              : _normalizeDbfs(amp.current);
          final voiceGate = quickMode
              ? _quickVoiceActivityGate
              : _voiceActivityGate;
          final silenceGate = quickMode ? _quickSilenceGate : _silenceGate;
          final smoothingRetain = quickMode ? _quickSmoothingRetain : 0.7;
          final smoothingIncoming = 1.0 - smoothingRetain;
          final peakDecay = quickMode ? _quickPeakDecay : 0.92;
          final gated = level < voiceGate ? 0.0 : level;
          final smoothed =
              _ampLevel * smoothingRetain + gated * smoothingIncoming;
          final peak = math.max(_ampPeak * peakDecay, smoothed);
          final nextLevel = smoothed < silenceGate ? 0.0 : smoothed;
          final nextPeak = peak < silenceGate ? 0.0 : peak;
          final hasVoice = quickMode
              ? nextLevel >= _quickSpectrumDisplayGate
              : nextLevel > 0.0;
          final visualLevel = hasVoice ? nextLevel : 0.0;
          final visualPeak = hasVoice ? nextPeak : 0.0;
          final visualSample = hasVoice
              ? quickMode
                    ? (gated * _quickVisualizerRawBlend +
                              nextLevel * (1.0 - _quickVisualizerRawBlend))
                          .clamp(0.0, 1.0)
                    : visualLevel
              : 0.0;
          if (mounted) {
            _pushVisualizerSample(visualSample);
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
    _stopSpectrumFeed(hard: !_usesNativeQuickSpectrum);
  }

  Future<void> _saveAndReturn() async {
    if (_processing) return;
    if (_recording) {
      await _stopRecording(autoComplete: _isQuickFabComposeMode);
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

  Future<void> _togglePageQuickPause() async {
    if (!_usesPageQuickPauseAction ||
        !_recording ||
        _awaitingConfirm ||
        _processing) {
      return;
    }
    if (_paused) {
      await _resumeRecording();
      return;
    }
    await _pauseRecording();
  }

  Future<void> _pauseRecording() async {
    try {
      if (_usesNativeQuickSpectrum) {
        await _quickSpectrumRecorder!.pause();
      } else {
        await _recorder.pause();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              zh: '\u6682\u505C\u5F55\u97F3\u5931\u8D25\uFF1A$e',
              en: 'Failed to pause recording: $e',
            ),
          ),
        ),
      );
      return;
    }

    _stopwatch.stop();
    _blink.stop();
    _stopMeter();
    if (!mounted) return;
    setState(() {
      _paused = true;
      _ampLevel = 0.0;
      _ampPeak = 0.0;
      _voiceActive = false;
      _dragOffset = Offset.zero;
      _dragPreviewAction = _VoiceRecordQuickAction.none;
    });
  }

  Future<void> _resumeRecording() async {
    try {
      if (_usesNativeQuickSpectrum) {
        await _quickSpectrumRecorder!.resume();
      } else {
        await _recorder.resume();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              zh: '\u7EE7\u7EED\u5F55\u97F3\u5931\u8D25\uFF1A$e',
              en: 'Failed to resume recording: $e',
            ),
          ),
        ),
      );
      return;
    }

    _stopwatch.start();
    _blink.repeat(reverse: true);
    _startMeter();
    if (_usesNativeQuickSpectrum) {
      _startSpectrumFeed();
    }
    if (!mounted) return;
    setState(() {
      _paused = false;
      _dragOffset = Offset.zero;
      _dragPreviewAction = _VoiceRecordQuickAction.none;
    });
  }

  void _handleRecordPanUpdate(DragUpdateDetails details) {
    if (_paused ||
        !_recording ||
        _awaitingConfirm ||
        _processing ||
        _gestureLocked) {
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
        if (_isQuickFabComposeMode &&
            _recording &&
            !_gestureLocked &&
            !_paused) {
          await _stopRecording(autoComplete: true);
        }
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
    if (_isQuickFabComposeMode) {
      if (dx <= -horizontalThreshold && horizontalDominant) {
        return _VoiceRecordQuickAction.discard;
      }
      if (_usesPageQuickPauseAction) {
        return _VoiceRecordQuickAction.none;
      }
      if (dx >= horizontalThreshold && horizontalDominant) {
        return _VoiceRecordQuickAction.lock;
      }
      return _VoiceRecordQuickAction.none;
    }
    if (dy <= -verticalThreshold && !horizontalDominant) {
      return _VoiceRecordQuickAction.lock;
    }
    if (dx <= -horizontalThreshold && horizontalDominant) {
      return _VoiceRecordQuickAction.discard;
    }
    if (_supportsDraftQuickAction &&
        dx >= horizontalThreshold &&
        horizontalDominant) {
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
    final isQuickPageLayout = _isQuickFabComposeMode && !isOverlay;
    final panelColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.62);
    final secondaryPanel = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.74);
    final headerLabel = _isQuickFabComposeMode
        ? switch ((_paused, _gestureLocked, _dragPreviewAction, _recording)) {
            (true, _, _, true) => context.tr(
              zh: '\u5DF2\u6682\u505C',
              en: 'Paused',
            ),
            (_, _, _, false) => context.t.strings.legacy.msg_voice_memos,
            (false, false, _VoiceRecordQuickAction.discard, true) => context.tr(
              zh: '\u677E\u5F00\u653E\u5F03\u5F55\u97F3',
              en: 'Release to discard recording',
            ),
            (false, false, _VoiceRecordQuickAction.lock, true) => context.tr(
              zh: '\u677E\u5F00\u9501\u5B9A\u81EA\u52A8\u5F55\u97F3',
              en: 'Release to lock recording',
            ),
            (_, _, _, true) => context.tr(
              zh: '\u5F55\u97F3\u4E2D',
              en: 'Recording',
            ),
          }
        : switch ((_gestureLocked, _dragPreviewAction)) {
            (true, _) => context.tr(zh: '\u5DF2\u9501\u5B9A', en: 'Locked'),
            (false, _VoiceRecordQuickAction.lock) => context.tr(
              zh: '\u5DF2\u9501\u5B9A',
              en: 'Locked',
            ),
            (false, _VoiceRecordQuickAction.discard) => context.tr(
              zh: '\u677E\u624B\u653E\u5F03',
              en: 'Release to discard',
            ),
            (false, _VoiceRecordQuickAction.draft) => context.tr(
              zh: '\u677E\u624B\u8F6C\u8349\u7A3F',
              en: 'Release to draft',
            ),
            _ when _awaitingConfirm => context.tr(
              zh: '\u5F55\u97F3\u5B8C\u6210',
              en: 'Ready to save',
            ),
            _ when _recording => context.tr(
              zh: '\u5F55\u97F3\u4E2D',
              en: 'Recording',
            ),
            _ => context.t.strings.legacy.msg_voice_memos,
          };
    final lockHint = _gestureLocked
        ? context.tr(
            zh: '\u5DF2\u9501\u5B9A\uFF0C\u70B9\u51FB\u9EA6\u514B\u98CE\u7ED3\u675F',
            en: 'Locked - tap mic to finish',
          )
        : _isQuickFabComposeMode
        ? context.tr(zh: '\u53F3\u6ED1\u9501\u5B9A', en: 'Slide right to lock')
        : context.tr(zh: '\u4E0A\u6ED1\u9501\u5B9A', en: 'Slide up to lock');
    final discardHint = context.tr(
      zh: '\u5DE6\u6ED1\u653E\u5F03',
      en: 'Slide left to discard',
    );
    final draftHint = _isQuickFabComposeMode
        ? context.tr(zh: '\u677E\u624B\u5B8C\u6210', en: 'Release to finish')
        : context.tr(
            zh: '\u53F3\u6ED1\u8F6C\u8349\u7A3F',
            en: 'Slide right to draft',
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
                                    if (isQuickPageLayout) ...[
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          headerLabel,
                                          key: const ValueKey(
                                            'voice_record_header_label',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: textMuted,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      const Spacer(),
                                      Text(
                                        headerLabel,
                                        key: const ValueKey(
                                          'voice_record_header_label',
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  elapsedText,
                                  style: TextStyle(
                                    fontSize: isQuickPageLayout ? 34 : 38,
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
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isQuickPageLayout ? 296 : 312,
                                      ),
                                      child: SizedBox.expand(
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isQuickPageLayout
                                                ? 0
                                                : 18,
                                            vertical: isQuickPageLayout
                                                ? 0
                                                : 26,
                                          ),
                                          decoration: isQuickPageLayout
                                              ? null
                                              : BoxDecoration(
                                                  color: secondaryPanel,
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.06,
                                                              )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                  ),
                                                ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final availableHeight =
                                                  constraints.maxHeight;
                                              final canShowLockHint =
                                                  !isQuickPageLayout &&
                                                  availableHeight >= 180;
                                              final reservedHeight =
                                                  canShowLockHint
                                                  ? (isQuickPageLayout
                                                        ? 30
                                                        : 40)
                                                  : 0.0;
                                              final maxWaveformHeight = math
                                                  .max(
                                                    0.0,
                                                    availableHeight -
                                                        reservedHeight,
                                                  );
                                              final preferredWaveformHeight =
                                                  isQuickPageLayout
                                                  ? 88.0
                                                  : 132.0;
                                              final minWaveformHeight =
                                                  isQuickPageLayout
                                                  ? 32.0
                                                  : 56.0;
                                              final waveformHeight =
                                                  maxWaveformHeight <= 0
                                                  ? 0.0
                                                  : maxWaveformHeight <
                                                        minWaveformHeight
                                                  ? maxWaveformHeight
                                                  : math.min(
                                                      preferredWaveformHeight,
                                                      maxWaveformHeight,
                                                    );

                                              return Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (waveformHeight > 0)
                                                    SizedBox(
                                                      height: waveformHeight,
                                                      child: _buildWaveform(
                                                        isDark: false,
                                                        level: recActive
                                                            ? _ampLevel
                                                            : 0.0,
                                                        peak: recActive
                                                            ? _ampPeak
                                                            : 0.0,
                                                        showVoiceBars:
                                                            recActive &&
                                                            _voiceActive,
                                                      ),
                                                    ),
                                                  if (canShowLockHint) ...[
                                                    SizedBox(
                                                      height: isQuickPageLayout
                                                          ? 8
                                                          : 12,
                                                    ),
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
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            _isQuickFabComposeMode
                                                                ? Icons
                                                                      .arrow_forward_rounded
                                                                : Icons
                                                                      .arrow_upward_rounded,
                                                            size: 16,
                                                            color:
                                                                MemoFlowPalette
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.85,
                                                                    ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Flexible(
                                                            child: Text(
                                                              lockHint,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                fontSize:
                                                                    isQuickPageLayout
                                                                    ? 11
                                                                    : 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: MemoFlowPalette
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.85,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isQuickPageLayout ? 8 : 10),
                                Row(
                                  children: [
                                    _buildQuickActionButton(
                                      icon: Icons.chevron_left_rounded,
                                      active:
                                          _dragPreviewAction ==
                                          _VoiceRecordQuickAction.discard,
                                      enabled: !_processing,
                                      onTap: () => unawaited(_closeScreen()),
                                      foreground: MemoFlowPalette.primary,
                                      size: isQuickPageLayout ? 44 : 50,
                                      iconSize: isQuickPageLayout ? 22 : 24,
                                    ),
                                    if (_supportsDraftQuickAction) ...[
                                      SizedBox(
                                        width: isQuickPageLayout ? 14 : 18,
                                      ),
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
                                        size: isQuickPageLayout ? 44 : 50,
                                        iconSize: isQuickPageLayout ? 22 : 24,
                                      ),
                                      SizedBox(
                                        width: isQuickPageLayout ? 14 : 18,
                                      ),
                                      _buildQuickActionButton(
                                        icon: Icons.notes_rounded,
                                        active:
                                            _dragPreviewAction ==
                                            _VoiceRecordQuickAction.draft,
                                        enabled:
                                            !_processing &&
                                            (_recording || _awaitingConfirm),
                                        onTap: () =>
                                            unawaited(_saveAndReturn()),
                                        foreground: _awaitingConfirm
                                            ? MemoFlowPalette.primary
                                            : textMain.withValues(alpha: 0.8),
                                        size: isQuickPageLayout ? 44 : 50,
                                        iconSize: isQuickPageLayout ? 22 : 24,
                                      ),
                                    ] else ...[
                                      const Spacer(),
                                      _buildQuickActionButton(
                                        icon: _usesPageQuickPauseAction
                                            ? (_paused
                                                  ? Icons.play_arrow_rounded
                                                  : Icons.pause_rounded)
                                            : (_gestureLocked
                                                  ? Icons.lock_rounded
                                                  : Icons.lock_open_rounded),
                                        active: _usesPageQuickPauseAction
                                            ? _paused
                                            : (_dragPreviewAction ==
                                                      _VoiceRecordQuickAction
                                                          .lock ||
                                                  _gestureLocked),
                                        enabled:
                                            _recording &&
                                            !_awaitingConfirm &&
                                            !_processing,
                                        onTap: _usesPageQuickPauseAction
                                            ? () => unawaited(
                                                _togglePageQuickPause(),
                                              )
                                            : _toggleGestureLock,
                                        foreground: MemoFlowPalette.primary,
                                        size: isQuickPageLayout ? 44 : 50,
                                        iconSize: isQuickPageLayout ? 22 : 24,
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: isQuickPageLayout ? 14 : 18),
                                _buildPrimaryButton(
                                  isDark: isDark,
                                  compact: isQuickPageLayout,
                                ),
                                if (!isQuickPageLayout) ...[
                                  SizedBox(height: isQuickPageLayout ? 10 : 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          discardHint,
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                            fontSize: isQuickPageLayout
                                                ? 11
                                                : 12,
                                            fontWeight: FontWeight.w600,
                                            color: textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          draftHint,
                                          textAlign: _supportsDraftQuickAction
                                              ? TextAlign.right
                                              : TextAlign.center,
                                          style: TextStyle(
                                            fontSize: isQuickPageLayout
                                                ? 11
                                                : 12,
                                            fontWeight: FontWeight.w600,
                                            color: textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
    if (action == _VoiceRecordQuickAction.draft && !_supportsDraftQuickAction) {
      return 0.0;
    }
    if (compact && _isQuickFabComposeMode) {
      return _dragPreviewAction == action ? 1.0 : 0.0;
    }
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
    if (_isQuickFabComposeMode) {
      if (translatedOffset.dx <= -_compactQuickDiscardActivationX &&
          translatedOffset.dy <= _compactQuickDiscardMaxY) {
        return _VoiceRecordQuickAction.discard;
      }
      if (translatedOffset.dx >= _compactQuickLockActivationX &&
          translatedOffset.dy <= _compactQuickDiscardMaxY) {
        return _VoiceRecordQuickAction.lock;
      }
      return _VoiceRecordQuickAction.none;
    }
    final hitRadius = (_compactActionZoneDiameter / 2) + 8;
    final candidates = <(_VoiceRecordQuickAction, Offset)>[
      (
        _VoiceRecordQuickAction.discard,
        const Offset(-_compactSideActionCenterX, _compactSideActionCenterY),
      ),
      (_VoiceRecordQuickAction.lock, const Offset(0, _compactTopActionCenterY)),
    ];
    if (_supportsDraftQuickAction) {
      candidates.add((
        _VoiceRecordQuickAction.draft,
        const Offset(_compactSideActionCenterX, _compactSideActionCenterY),
      ));
    }

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
        if (_isQuickFabComposeMode) {
          return baseOffset + Offset(12 * actionProgress, -2 * actionProgress);
        }
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
      math.max(lockProgress, _supportsDraftQuickAction ? draftProgress : 0.0),
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
                        right: _isQuickFabComposeMode ? 30 : null,
                        bottom: _isQuickFabComposeMode ? 38 : 108,
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
                          translation: _isQuickFabComposeMode
                              ? Offset(lockProgress * 12, -lockProgress * 2)
                              : Offset(0, -lockProgress * 14),
                        ),
                      ),
                      if (_supportsDraftQuickAction)
                        Positioned(
                          right: 30,
                          bottom: 38,
                          child: _buildOverlayQuickActionZone(
                            icon: Icons.notes_rounded,
                            active:
                                _dragPreviewAction ==
                                _VoiceRecordQuickAction.draft,
                            enabled:
                                !_processing &&
                                (_recording || _awaitingConfirm),
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
        key: const ValueKey('voice_record_primary_button'),
        onTap: enabled
            ? () {
                if (showConfirm) {
                  unawaited(_saveAndReturn());
                  return;
                }
                if (showStop) {
                  unawaited(
                    _isQuickFabComposeMode
                        ? _saveAndReturn()
                        : _stopForConfirm(),
                  );
                  return;
                }
                unawaited(_start());
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
    final samples = _visualizerHistory();
    final silenceGate = _isQuickFabComposeMode
        ? _quickSilenceGate
        : _silenceGate;

    if (_usesNativeQuickSpectrum) {
      const spectrumBarColor = Color(0xFF8DB7F7);
      final baselineColor = spectrumBarColor.withValues(alpha: 0.16);
      final guideColor = Colors.white.withValues(alpha: 0.22);
      final guideStrength =
          (showVoiceBars ? math.max(level, peak) : peak * 0.38).clamp(0.0, 1.0);

      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 260.0;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 70.0;
          return CustomPaint(
            key: const ValueKey('voice_record_quick_spectrum'),
            size: Size(width, height),
            painter: _AudioSpectrumPainter(
              bars: _quickSpectrumAnimator.displayBars,
              barColor: spectrumBarColor,
              baselineColor: baselineColor,
              guideColor: guideColor,
              minBarHeight: 1.2,
              maxBarHeightFactor: 0.86,
              guideStrength: guideStrength,
            ),
          );
        },
      );
    }

    final waveformColor = isDark
        ? const Color(0xFFF4F2EE)
        : MemoFlowPalette.textLight.withValues(alpha: 0.92);
    final baselineColor = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : MemoFlowPalette.textLight.withValues(alpha: 0.18);
    final playheadColor = const Color(0xFFC8D27C);
    final playheadStrength =
        (showVoiceBars ? math.max(level, peak) : peak * 0.4).clamp(0.0, 1.0);
    final maxAmplitudeFactor = _isQuickFabComposeMode
        ? _quickWaveformMaxAmplitudeFactor
        : 0.42;
    final minBarHalfHeight = _isQuickFabComposeMode
        ? _quickWaveformMinBarHalfHeight
        : 7.0;
    final responseCurve = _isQuickFabComposeMode
        ? Curves.linear
        : Curves.easeOutCubic;
    final responseExponent = _isQuickFabComposeMode
        ? _quickWaveformResponseExponent
        : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 260.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 70.0;
        return CustomPaint(
          key: ValueKey(
            _isQuickFabComposeMode
                ? 'voice_record_quick_waveform'
                : 'voice_record_standard_waveform',
          ),
          size: Size(width, height),
          painter: _CenteredBarWaveformPainter(
            samples: samples,
            barColor: waveformColor,
            baselineColor: baselineColor,
            playheadColor: playheadColor,
            silenceGate: silenceGate,
            maxAmplitudeFactor: maxAmplitudeFactor,
            minBarHalfHeight: minBarHalfHeight,
            playheadStrength: playheadStrength,
            responseCurve: responseCurve,
            responseExponent: responseExponent,
          ),
        );
      },
    );
  }
}

class _CenteredBarWaveformPainter extends CustomPainter {
  const _CenteredBarWaveformPainter({
    required this.samples,
    required this.barColor,
    required this.baselineColor,
    required this.playheadColor,
    required this.silenceGate,
    required this.maxAmplitudeFactor,
    required this.minBarHalfHeight,
    required this.playheadStrength,
    required this.responseCurve,
    required this.responseExponent,
  });

  final List<double> samples;
  final Color barColor;
  final Color baselineColor;
  final Color playheadColor;
  final double silenceGate;
  final double maxAmplitudeFactor;
  final double minBarHalfHeight;
  final double playheadStrength;
  final Curve responseCurve;
  final double responseExponent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final baselineY = size.height / 2;
    _drawDashedBaseline(
      canvas: canvas,
      width: size.width,
      baselineY: baselineY,
    );
    _drawWaveformBars(canvas: canvas, size: size, baselineY: baselineY);
    _drawPlayhead(canvas: canvas, size: size);
  }

  @override
  bool shouldRepaint(covariant _CenteredBarWaveformPainter oldDelegate) {
    return !listEquals(oldDelegate.samples, samples) ||
        oldDelegate.barColor != barColor ||
        oldDelegate.baselineColor != baselineColor ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.silenceGate != silenceGate ||
        oldDelegate.maxAmplitudeFactor != maxAmplitudeFactor ||
        oldDelegate.minBarHalfHeight != minBarHalfHeight ||
        oldDelegate.playheadStrength != playheadStrength ||
        oldDelegate.responseCurve != responseCurve ||
        oldDelegate.responseExponent != responseExponent;
  }

  void _drawDashedBaseline({
    required Canvas canvas,
    required double width,
    required double baselineY,
  }) {
    final dashPaint = Paint()
      ..color = baselineColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    const dashWidth = 4.5;
    const gap = 6.0;
    for (double x = 0.0; x < width; x += dashWidth + gap) {
      final endX = math.min(width, x + dashWidth);
      canvas.drawLine(Offset(x, baselineY), Offset(endX, baselineY), dashPaint);
    }
  }

  void _drawWaveformBars({
    required Canvas canvas,
    required Size size,
    required double baselineY,
  }) {
    if (samples.isEmpty) return;

    final barWidth = size.width < 240 ? 3.0 : 3.4;
    final gap = size.width < 240 ? 4.0 : 4.8;
    final barCount = math.max(
      18,
      ((size.width + gap) / (barWidth + gap)).floor(),
    );
    final resampled = _resampleWaveformSamples(
      samples: samples,
      count: barCount,
      silenceGate: silenceGate,
      responseCurve: responseCurve,
      responseExponent: responseExponent,
    );
    if (resampled.isEmpty) return;

    final spacing = size.width / resampled.length;
    final maxBarHalfHeight = math.max(
      16.0,
      math.min(size.height * maxAmplitudeFactor, baselineY - 6.0),
    );
    final shadowPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth + 1.8;
    final barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var index = 0; index < resampled.length; index++) {
      final sample = resampled[index];
      if (sample <= 0.0) continue;

      final positionRatio = ((index + 0.5) / resampled.length - 0.5).abs() * 2;
      final edgeFade = 0.78 + (1.0 - positionRatio) * 0.22;
      final halfHeight =
          minBarHalfHeight + (maxBarHalfHeight - minBarHalfHeight) * sample;
      final x = spacing * index + spacing / 2;
      final top = math.max(4.0, baselineY - halfHeight);
      final bottom = math.min(size.height - 4.0, baselineY + halfHeight);

      shadowPaint.color = barColor.withValues(
        alpha: (0.06 + sample * 0.08) * edgeFade,
      );
      barPaint.color = barColor.withValues(
        alpha: (0.84 + sample * 0.16) * edgeFade,
      );

      canvas.drawLine(Offset(x, top), Offset(x, bottom), shadowPaint);
      canvas.drawLine(Offset(x, top), Offset(x, bottom), barPaint);
    }
  }

  void _drawPlayhead({required Canvas canvas, required Size size}) {
    final centerX = size.width / 2;
    final glowPaint = Paint()
      ..color = playheadColor.withValues(
        alpha: 0.16 + (playheadStrength * 0.14),
      )
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final linePaint = Paint()
      ..color = playheadColor.withValues(
        alpha: 0.72 + (playheadStrength * 0.22),
      )
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX, 2.0),
      Offset(centerX, size.height - 2.0),
      glowPaint,
    );
    canvas.drawLine(
      Offset(centerX, 2.0),
      Offset(centerX, size.height - 2.0),
      linePaint,
    );
  }
}

class _AudioSpectrumPainter extends CustomPainter {
  _AudioSpectrumPainter({
    required List<double> bars,
    required this.barColor,
    required this.baselineColor,
    required this.guideColor,
    required this.minBarHeight,
    required this.maxBarHeightFactor,
    required this.guideStrength,
  }) : bars = List<double>.unmodifiable(bars);

  final List<double> bars;
  final Color barColor;
  final Color baselineColor;
  final Color guideColor;
  final double minBarHeight;
  final double maxBarHeightFactor;
  final double guideStrength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || bars.isEmpty) return;

    final baselineY = size.height - 2.0;
    _drawBaseline(canvas: canvas, size: size, baselineY: baselineY);
    _drawBars(canvas: canvas, size: size, baselineY: baselineY);
    _drawCenterGuide(canvas: canvas, size: size, baselineY: baselineY);
  }

  @override
  bool shouldRepaint(covariant _AudioSpectrumPainter oldDelegate) {
    return !listEquals(oldDelegate.bars, bars) ||
        oldDelegate.barColor != barColor ||
        oldDelegate.baselineColor != baselineColor ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.minBarHeight != minBarHeight ||
        oldDelegate.maxBarHeightFactor != maxBarHeightFactor ||
        oldDelegate.guideStrength != guideStrength;
  }

  void _drawBaseline({
    required Canvas canvas,
    required Size size,
    required double baselineY,
  }) {
    final paint = Paint()
      ..color = baselineColor
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), paint);
  }

  void _drawBars({
    required Canvas canvas,
    required Size size,
    required double baselineY,
  }) {
    final count = bars.length;
    if (count == 0) return;

    final gap = size.width < 260 ? 1.8 : 2.2;
    final totalGapWidth = gap * (count - 1);
    final barWidth = ((size.width - totalGapWidth) / count).clamp(1.6, 4.0);
    final totalBarsWidth = count * barWidth + totalGapWidth;
    final startX = (size.width - totalBarsWidth) / 2;
    final maxBarHeight = math.max(
      14.0,
      math.min(size.height * maxBarHeightFactor, baselineY - 6.0),
    );
    final radius = Radius.circular(barWidth * 0.45);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var index = 0; index < count; index++) {
      final value = bars[index].clamp(0.0, 1.0);
      final height = minBarHeight + (maxBarHeight - minBarHeight) * value;
      final left = startX + index * (barWidth + gap);
      final top = baselineY - height;
      paint.color = barColor.withValues(alpha: 0.24 + value * 0.66);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          radius,
        ),
        paint,
      );
    }
  }

  void _drawCenterGuide({
    required Canvas canvas,
    required Size size,
    required double baselineY,
  }) {
    final paint = Paint()
      ..color = guideColor.withValues(alpha: 0.14 + guideStrength * 0.18)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final centerX = size.width / 2;
    canvas.drawLine(
      Offset(centerX, 1.0),
      Offset(centerX, baselineY - 4),
      paint,
    );
  }
}

List<double> _resampleWaveformSamples({
  required List<double> samples,
  required int count,
  required double silenceGate,
  required Curve responseCurve,
  required double responseExponent,
}) {
  if (samples.isEmpty || count <= 0) {
    return const <double>[];
  }

  return List<double>.generate(count, (index) {
    final start = index * samples.length / count;
    final end = (index + 1) * samples.length / count;
    final from = start.floor().clamp(0, samples.length - 1);
    final to = math.max(from + 1, end.ceil()).clamp(1, samples.length);

    double sum = 0.0;
    double peak = 0.0;
    var sampleCount = 0;
    for (var i = from; i < to; i++) {
      final sample = samples[i].clamp(0.0, 1.0);
      sum += sample;
      peak = math.max(peak, sample);
      sampleCount += 1;
    }

    if (sampleCount == 0) return 0.0;
    final average = sum / sampleCount;
    final blended = average * 0.55 + peak * 0.45;
    if (blended < silenceGate) return 0.0;
    final curved = responseCurve.transform(blended.clamp(0.0, 1.0));
    if (responseExponent == 1.0) {
      return curved;
    }
    return math.pow(curved, responseExponent).toDouble().clamp(0.0, 1.0);
  }, growable: false);
}
