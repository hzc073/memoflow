import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';

class VoiceRecordScreen extends ConsumerStatefulWidget {
  const VoiceRecordScreen({super.key});

  @override
  ConsumerState<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends ConsumerState<VoiceRecordScreen> with TickerProviderStateMixin {
  static const _maxDuration = Duration(minutes: 60);

  final _recorder = AudioRecorder();
  final _filenameFmt = DateFormat('yyyyMMdd_HHmmss');
  final _stopwatch = Stopwatch();

  late final AnimationController _blink;
  late final Animation<double> _blinkOpacity;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;

  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _filePath;
  String? _fileName;
  bool _recording = false;
  bool _paused = false;
  double _ampLevel = 0.0;
  double _ampPeak = 0.0;
  bool _awaitingConfirm = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _blinkOpacity = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blink, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _stopwatch.stop();
    _blink.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _resetToIdle() {
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    _stopMeter();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
      _elapsed = Duration.zero;
      _startedAt = null;
      _filePath = null;
      _fileName = null;
      _awaitingConfirm = false;
      _processing = false;
      _ampLevel = 0.0;
      _ampPeak = 0.0;
    });
  }

  Future<void> _start() async {
    if (_recording) return;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '需要麦克风权限', en: 'Microphone permission required'))),
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(dir.path, 'recordings'));
    if (!recordingsDir.existsSync()) {
      recordingsDir.createSync(recursive: true);
    }

    final now = DateTime.now();
    final fileName = 'voice_${_filenameFmt.format(now)}.m4a';
    final filePath = p.join(recordingsDir.path, fileName);

    setState(() {
      _startedAt = now;
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
        SnackBar(content: Text(context.tr(zh: '启动录音失败：$e', en: 'Failed to start recording: $e'))),
      );
      return;
    }

    setState(() {
      _recording = true;
      _ampLevel = 0.0;
      _ampPeak = 0.0;
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

  Future<void> _togglePause() async {
    if (!_recording) return;
    try {
      if (_paused) {
        await _recorder.resume();
        _stopwatch.start();
        _blink.repeat(reverse: true);
        setState(() => _paused = false);
      } else {
        await _recorder.pause();
        _stopwatch.stop();
        _blink.stop();
        setState(() {
          _paused = true;
          _elapsed = _stopwatch.elapsed;
          _ampLevel = 0.0;
          _ampPeak = 0.0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '操作失败：$e', en: 'Operation failed: $e'))),
      );
    }
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
        SnackBar(content: Text(context.tr(zh: '停止录音失败：$e', en: 'Failed to stop recording: $e'))),
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
      _awaitingConfirm = true;
      _processing = false;
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
          SnackBar(content: Text(context.tr(zh: '录音信息缺失', en: 'Recording info missing'))),
        );
      }
      _resetToIdle();
      return;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '录音文件不存在', en: 'Recording file not found'))),
        );
      }
      _resetToIdle();
      return;
    }

    try {
      final size = file.lengthSync();
      final now = DateTime.now();
      final memoUid = generateUid();
      final attachmentUid = generateUid();
      final durationText = _formatDuration(_elapsed);
      final language = ref.read(appPreferencesProvider).language;
      final createdAt = DateFormat('yyyy-MM-dd HH:mm').format(now);

      final content = trByLanguage(
        language: language,
        zh: '🎙️ 语音记录\n'
            '#voice\n'
            '\n'
            '- 时长：$durationText\n'
            '- 创建：$createdAt\n',
        en: '🎙️ Voice memo\n'
            '#voice\n'
            '\n'
            '- Duration: $durationText\n'
            '- Created: $createdAt\n',
      );

      final attachments = [
        Attachment(
          name: 'attachments/$attachmentUid',
          filename: fileName,
          type: 'audio/mp4',
          size: size,
          externalLink: '',
        ).toJson(),
      ];

      final db = ref.read(databaseProvider);
      await db.upsertMemo(
        uid: memoUid,
        content: content,
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: const ['voice'],
        attachments: attachments,
        syncState: 1,
      );

      await db.enqueueOutbox(type: 'create_memo', payload: {
        'uid': memoUid,
        'content': content,
        'visibility': 'PRIVATE',
        'pinned': false,
        'has_attachments': true,
      });
      await db.enqueueOutbox(type: 'upload_attachment', payload: {
        'uid': attachmentUid,
        'memo_uid': memoUid,
        'file_path': filePath,
        'filename': fileName,
        'mime_type': 'audio/mp4',
      });

      // Try best-effort sync in background (manual refresh still available).
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());

      if (!mounted) return;
      setState(() {
        _awaitingConfirm = false;
        _processing = false;
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '已创建语音 memo（待同步）', en: 'Voice memo created (pending sync)'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '发送失败：$e', en: 'Send failed: $e'))),
      );
    }
  }

  Future<void> _discardRecording() async {
    if (_processing || !_awaitingConfirm) return;
    setState(() => _processing = true);
    final filePath = _filePath;
    if (filePath != null && filePath.trim().isNotEmpty) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (_) {}
    }
    _resetToIdle();
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen(
      (amp) {
        if (!_recording || _paused) return;
        final level = _normalizeDbfs(amp.current);
        final smoothed = _ampLevel * 0.7 + level * 0.3;
        final peak = math.max(_ampPeak * 0.92, smoothed);
        if (mounted) {
          setState(() {
            _ampLevel = smoothed;
            _ampPeak = peak;
          });
        }
      },
      onError: (_) {},
    );
  }

  void _stopMeter() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _ampLevel = 0.0;
    _ampPeak = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Colors.black.withValues(alpha: isDark ? 0.6 : 0.3);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : MemoFlowPalette.cardLight;
    final textMain = isDark ? const Color(0xFFD1D1D1) : MemoFlowPalette.textLight;
    final textMuted = isDark ? const Color(0xFF8E8E8E) : Colors.grey.shade400;
    final recActive = _recording && !_paused;

    final elapsedText = _formatDisplayDuration(_elapsed);
    final limitText = '${_formatDisplayDuration(_maxDuration)} Limit';
    final dateText = DateFormat('yyyy-MM-dd').format(_startedAt ?? DateTime.now());
    final size = MediaQuery.sizeOf(context);
    final cardWidth = math.min(size.width * 0.88, 342.0).toDouble();
    final cardHeight = math.min(size.height * 0.78, 600.0).toDouble();

    return Scaffold(
      backgroundColor: isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight,
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: overlay)),
          SafeArea(
            child: Center(
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                        color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'REC',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.2,
                                        color: textMain,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildRecDot(active: recActive),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateText,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 192,
                                    child: _buildWaveform(
                                      isDark: isDark,
                                      level: recActive ? _ampLevel : 0.0,
                                      peak: recActive ? _ampPeak : 0.0,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    context.tr(zh: '波形随音量动态跳动', en: 'Waveform reacts to volume'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.6,
                                      color: textMuted.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                            child: Column(
                              children: [
                                Text(
                                  elapsedText,
                                  style: TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                    color: isDark ? const Color(0xFFF5F5F5) : textMain,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  limitText,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textMuted),
                                ),
                                const SizedBox(height: 24),
                                if (_awaitingConfirm)
                                  _buildConfirmRow(isDark: isDark)
                                else
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildPauseButton(isDark: isDark, iconColor: textMain),
                                      _buildPrimaryButton(isDark: isDark),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecDot({required bool active}) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
    );
    if (!active) {
      return Opacity(opacity: 0.4, child: dot);
    }
    return FadeTransition(opacity: _blinkOpacity, child: dot);
  }

  Widget _buildPauseButton({required bool isDark, required Color iconColor}) {
    final enabled = _recording;
    final bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6);
    final border = isDark ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : null;
    final icon = _paused ? Icons.play_arrow_rounded : Icons.pause_rounded;

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTap: enabled ? _togglePause : null,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Icon(icon, size: 30, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildConfirmRow({required bool isDark}) {
    final disabled = _processing;
    const discardColor = Color(0xFFEF4444);
    const confirmColor = Color(0xFF22C55E);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildConfirmButton(
          isDark: isDark,
          icon: Icons.close_rounded,
          color: discardColor,
          enabled: !disabled,
          onTap: _discardRecording,
        ),
        const SizedBox(width: 24),
        _buildConfirmButton(
          isDark: isDark,
          icon: Icons.check_rounded,
          color: confirmColor,
          enabled: !disabled,
          onTap: _saveRecording,
        ),
      ],
    );
  }

  Widget _buildConfirmButton({
    required bool isDark,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.6,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                blurRadius: isDark ? 20.0 : 14.0,
                color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              ),
            ],
          ),
          child: Icon(icon, size: 32, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required bool isDark}) {
    final showStop = _recording;
    final enabled = !_processing;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.6,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTap: enabled ? (showStop ? _stopForConfirm : _start) : null,
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MemoFlowPalette.primary.withValues(alpha: 0.1), width: 6),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MemoFlowPalette.primary.withValues(alpha: 0.2)),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: MemoFlowPalette.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: isDark ? 20 : 16,
                      color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ],
                ),
                child: Center(
                  child: showStop
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      : const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform({required bool isDark, required double level, required double peak}) {
    final leftBars = isDark
        ? const [32.0, 48.0, 80.0, 56.0, 112.0]
        : const [24.0, 48.0, 80.0, 32.0, 56.0, 128.0, 40.0, 64.0];
    final centerBars = isDark ? const [144.0, 192.0, 128.0, 96.0] : const [96.0, 160.0, 112.0, 192.0, 80.0];
    final rightBars = isDark ? const [16.0, 16.0, 16.0, 16.0, 16.0] : const [16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0];

    final leftColor = isDark
        ? const Color(0xFF8E8E8E).withValues(alpha: 0.4)
        : MemoFlowPalette.textLight.withValues(alpha: 0.3);
    final centerColor = isDark ? const Color(0xFFD1D1D1) : MemoFlowPalette.textLight;
    final rightColor = isDark
        ? const Color(0xFF8E8E8E).withValues(alpha: 0.2)
        : MemoFlowPalette.textLight.withValues(alpha: 0.1);

    double scaleFor(double base, double minScale, double maxScale) {
      final scale = minScale + (maxScale - minScale) * level.clamp(0.0, 1.0);
      return math.max(0.1, base * scale);
    }

    final bars = <Widget>[];
    void addBars(List<double> heights, Color color, double minScale, double maxScale) {
      for (final h in heights) {
        final scaled = math.max(4.0, scaleFor(h, minScale, maxScale));
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
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: bars),
        line,
      ],
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
