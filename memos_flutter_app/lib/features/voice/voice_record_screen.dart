import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';

class VoiceRecordScreen extends ConsumerStatefulWidget {
  const VoiceRecordScreen({super.key});

  @override
  ConsumerState<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends ConsumerState<VoiceRecordScreen> with SingleTickerProviderStateMixin {
  static const _maxDuration = Duration(minutes: 60);

  final _recorder = AudioRecorder();
  final _filenameFmt = DateFormat('yyyyMMdd_HHmmss');

  AnimationController? _pulse;
  Timer? _ticker;

  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _filePath;
  String? _fileName;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.95,
      upperBound: 1.08,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse?.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('需要麦克风权限')));
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
    });

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
      ),
      path: filePath,
    );

    _pulse?.repeat(reverse: true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt == null) return;
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= _maxDuration) {
        unawaited(_stop());
        return;
      }
      setState(() => _elapsed = elapsed);
    });

    setState(() => _recording = true);
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    _pulse?.stop();
    _pulse?.value = 1.0;

    await _recorder.stop();

    setState(() => _recording = false);

    final filePath = _filePath;
    final fileName = _fileName;
    if (filePath == null || fileName == null) return;

    final file = File(filePath);
    if (!file.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('录音文件不存在')));
      return;
    }

    final size = file.lengthSync();
    final now = DateTime.now();
    final memoUid = generateUid();
    final attachmentUid = generateUid();
    final durationText = _formatDuration(_elapsed);

    final content = '🎙️ 语音记录\n'
        '#voice\n'
        '\n'
        '- 时长：$durationText\n'
        '- 创建：${DateFormat('yyyy-MM-dd HH:mm').format(now)}\n';

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
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已创建语音 memo（待同步）')));
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final elapsedText = _formatDuration(_elapsed);

    return Scaffold(
      appBar: AppBar(title: const Text('语音 Memo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                _recording ? '录音中…（最长 60 分钟）' : '点击开始录音',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                elapsedText,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const Spacer(),
              Center(
                child: GestureDetector(
                  onTap: _recording ? _stop : _start,
                  child: AnimatedBuilder(
                    animation: _pulse!,
                    builder: (context, child) {
                      final s = _recording ? _pulse!.value : 1.0;
                      return Transform.scale(scale: s, child: child);
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: _recording ? Colors.red : colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: _recording ? 24 : 12,
                            spreadRadius: _recording ? 6 : 2,
                            color: (_recording ? Colors.red : colorScheme.primary).withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                      child: Icon(
                        _recording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _fileName ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
