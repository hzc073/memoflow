import 'dart:math' as math;

import 'dart:async';
import 'dart:io';

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_localization.dart';
import '../../core/attachment_toast.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memo_image_grid.dart';
import '../memos/memo_markdown.dart';
import '../memos/memos_list_screen.dart';
import '../memos/widgets/audio_row.dart';

class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen> {
  final _swiperController = AppinioSwiperController();
  final _random = math.Random();
  late final _memosProvider = memosStreamProvider((
    searchQuery: '',
    state: 'NORMAL',
    tag: null,
    startTimeSec: null,
    endTimeSecExclusive: null,
    pageSize: 200,
  ));

  List<LocalMemo> _deck = const [];
  List<String> _memoIds = const [];
  int _cursor = 0;
  final _audioPlayer = AudioPlayer();
  final _audioPositionNotifier = ValueNotifier(Duration.zero);
  final _audioDurationNotifier = ValueNotifier<Duration?>(null);
  StreamSubscription<PlayerState>? _audioStateSub;
  StreamSubscription<Duration>? _audioPositionSub;
  StreamSubscription<Duration?>? _audioDurationSub;
  Timer? _audioProgressTimer;
  DateTime? _audioProgressStart;
  Duration _audioProgressBase = Duration.zero;
  Duration _audioProgressLast = Duration.zero;
  String? _playingMemoUid;
  String? _playingAudioUrl;
  bool _audioLoading = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(_memosProvider, (prev, next) {
      next.whenData((memos) {
        final changed = _syncDeck(memos);
        if (!changed || !mounted) return;
        setState(() {});
      });
    }, fireImmediately: true);
    _audioStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.playing) {
        _startAudioProgressTimer();
        if (_audioLoading) {
          setState(() => _audioLoading = false);
        }
      } else {
        _stopAudioProgressTimer();
      }
      if (state.processingState == ProcessingState.completed) {
        _stopAudioProgressTimer();
        unawaited(_audioPlayer.seek(Duration.zero));
        unawaited(_audioPlayer.pause());
        _audioPositionNotifier.value = Duration.zero;
        _audioDurationNotifier.value = null;
        setState(() {
          _playingMemoUid = null;
          _playingAudioUrl = null;
          _audioLoading = false;
        });
      }
    });
    _audioPositionSub = _audioPlayer.positionStream.listen((position) {
      if (!mounted || _playingMemoUid == null) return;
      if (_audioPlayer.playing && position <= _audioProgressLast) {
        return;
      }
      _audioProgressBase = position;
      _audioProgressLast = position;
      _audioProgressStart = DateTime.now();
      _audioPositionNotifier.value = position;
    });
    _audioDurationSub = _audioPlayer.durationStream.listen((duration) {
      if (!mounted || _playingMemoUid == null) return;
      _audioDurationNotifier.value = duration;
    });
  }

  @override
  void dispose() {
    _audioStateSub?.cancel();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioProgressTimer?.cancel();
    _audioPositionNotifier.dispose();
    _audioDurationNotifier.dispose();
    _audioPlayer.dispose();
    _swiperController.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      context.safePop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  bool _sameIds(List<String> next) {
    if (_memoIds.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (_memoIds[i] != next[i]) return false;
    }
    return true;
  }

  bool _syncDeck(List<LocalMemo> memos) {
    final ids = memos.map((m) => m.uid).toList(growable: false);
    if (_sameIds(ids)) {
      final lookup = {for (final memo in memos) memo.uid: memo};
      var changed = false;
      final next = <LocalMemo>[];
      for (final memo in _deck) {
        final updated = lookup[memo.uid] ?? memo;
        if (memo.contentFingerprint != updated.contentFingerprint ||
            memo.pinned != updated.pinned ||
            memo.state != updated.state ||
            memo.updateTime != updated.updateTime ||
            memo.syncState != updated.syncState ||
            memo.lastError != updated.lastError) {
          changed = true;
        }
        next.add(updated);
      }
      if (changed) {
        _deck = next;
      }
      return changed;
    }

    _memoIds = ids;
    _deck = List<LocalMemo>.from(memos)..shuffle(_random);
    _cursor = 0;
    return true;
  }

  void _rotateLeft() {
    if (_deck.length <= 1) return;
    final first = _deck.first;
    _deck = [..._deck.sublist(1), first];
  }

  void _rotateRight() {
    if (_deck.length <= 1) return;
    final last = _deck.last;
    _deck = [last, ..._deck.sublist(0, _deck.length - 1)];
  }

  void _startAudioProgressTimer() {
    if (_audioProgressTimer != null) return;
    _audioProgressBase = _audioPlayer.position;
    _audioProgressLast = _audioProgressBase;
    _audioProgressStart = DateTime.now();
    _audioProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _playingMemoUid == null) return;
      final now = DateTime.now();
      var position = _audioPlayer.position;
      if (_audioProgressStart != null && position <= _audioProgressLast) {
        position = _audioProgressBase + now.difference(_audioProgressStart!);
      } else {
        _audioProgressBase = position;
        _audioProgressStart = now;
      }
      _audioProgressLast = position;
      _audioPositionNotifier.value = position;
    });
  }

  void _stopAudioProgressTimer() {
    _audioProgressTimer?.cancel();
    _audioProgressTimer = null;
    _audioProgressStart = null;
  }

  String? _localAttachmentPath(Attachment attachment) {
    final raw = attachment.externalLink.trim();
    if (!raw.startsWith('file://')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final path = uri.toFilePath();
    if (path.trim().isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return path;
  }

  ({String url, String? localPath, Map<String, String>? headers})? _resolveAudioSource(
    Attachment attachment,
  ) {
    final rawLink = attachment.externalLink.trim();
    if (rawLink.isNotEmpty) {
      final localPath = _localAttachmentPath(attachment);
      if (localPath != null) {
        return (
          url: Uri.file(localPath).toString(),
          localPath: localPath,
          headers: null,
        );
      }
      return (url: rawLink, localPath: null, headers: null);
    }

    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    if (baseUrl == null) return null;
    final name = attachment.name.trim();
    final filename = attachment.filename.trim();
    if (name.isEmpty || filename.isEmpty) return null;
    final url = joinBaseUrl(baseUrl, 'file/$name/$filename');
    final token = account?.personalAccessToken ?? '';
    final headers = token.trim().isEmpty ? null : {'Authorization': 'Bearer $token'};
    return (url: url, localPath: null, headers: headers);
  }

  Future<void> _stopAudioPlayback({bool reset = true}) async {
    if (_playingMemoUid == null && _playingAudioUrl == null) return;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _stopAudioProgressTimer();
    if (reset) {
      _audioPositionNotifier.value = Duration.zero;
      _audioDurationNotifier.value = null;
    }
    if (!mounted) return;
    setState(() {
      _audioLoading = false;
      _playingMemoUid = null;
      _playingAudioUrl = null;
    });
  }

  Future<void> _toggleAudioPlayback(LocalMemo memo) async {
    if (_audioLoading) return;
    final audioAttachments =
        memo.attachments.where((a) => a.type.startsWith('audio')).toList(growable: false);
    if (audioAttachments.isEmpty) return;
    final attachment = audioAttachments.first;
    final source = _resolveAudioSource(attachment);
    if (source == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '无法读取音频资源', en: 'Unable to load audio source.'))),
      );
      return;
    }

    final url = source.url;
    final sameTarget = _playingMemoUid == memo.uid && _playingAudioUrl == url;
    if (sameTarget) {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        _stopAudioProgressTimer();
      } else {
        _startAudioProgressTimer();
        await _audioPlayer.play();
      }
      _audioPositionNotifier.value = _audioPlayer.position;
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _audioLoading = true;
      _playingMemoUid = memo.uid;
      _playingAudioUrl = url;
    });
    _audioPositionNotifier.value = Duration.zero;
    _audioDurationNotifier.value = null;

    try {
      await _audioPlayer.stop();
      Duration? loadedDuration;
      if (source.localPath != null) {
        loadedDuration = await _audioPlayer.setFilePath(source.localPath!);
      } else {
        loadedDuration = await _audioPlayer.setUrl(url, headers: source.headers);
      }
      _audioDurationNotifier.value = loadedDuration ?? _audioPlayer.duration;
      _startAudioProgressTimer();
      await _audioPlayer.play();
    } catch (e) {
      _stopAudioProgressTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '播放失败：$e', en: 'Playback failed: $e'))),
        );
        setState(() {
          _audioLoading = false;
          _playingMemoUid = null;
          _playingAudioUrl = null;
        });
      }
      _audioPositionNotifier.value = Duration.zero;
      _audioDurationNotifier.value = null;
    }
  }

  Future<void> _toggleMemoCheckbox(LocalMemo memo, int checkboxIndex) async {
    final updated = toggleCheckbox(
      memo.content,
      checkboxIndex,
      skipQuotedLines: false,
    );
    if (updated == memo.content) return;

    final db = ref.read(databaseProvider);
    final tags = extractTags(updated);

    await db.upsertMemo(
      uid: memo.uid,
      content: updated,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: memo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: memo.attachments.map((a) => a.toJson()).toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': updated,
        'visibility': memo.visibility,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';

    final memosAsync = ref.watch(_memosProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: context.tr(zh: '返回', en: 'Back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text(context.tr(zh: '随机漫步', en: 'Random Review')),
          centerTitle: true,
        ),
        body: memosAsync.when(
        data: (memos) {
          if (memos.isEmpty) {
            return Center(child: Text(context.tr(zh: '暂无内容', en: 'No content yet'), style: TextStyle(color: textMuted)));
          }

          final deck = _deck;
          final total = deck.length;
          final displayIndex = total == 0 ? 0 : (_cursor + 1).clamp(1, total);

          return Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(zh: '随机抽取你的卡片笔记', en: 'Randomly draw your memo cards'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                      ),
                    ),
                    Text(
                      '$displayIndex / $total',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 140),
                  child: AppinioSwiper(
                    controller: _swiperController,
                    cardCount: deck.length,
                    backgroundCardCount: 3,
                    backgroundCardScale: 0.92,
                    backgroundCardOffset: const Offset(0, 24),
                    swipeOptions: const SwipeOptions.symmetric(horizontal: true),
                    maxAngle: 14,
                    onSwipeEnd: (previousIndex, targetIndex, activity) {
                      if (!mounted) return;
                      unawaited(_stopAudioPlayback());
                      setState(() {
                        if (activity.direction == AxisDirection.right) {
                          _rotateRight();
                          _cursor = (_cursor - 1 + deck.length) % deck.length;
                        } else {
                          _rotateLeft();
                          _cursor = (_cursor + 1) % deck.length;
                        }
                        _swiperController.setCardIndex(0);
                      });
                    },
                    cardBuilder: (context, index) {
                      final memo = deck[index];
                      final isAudioActive = _playingMemoUid == memo.uid;
                      return _RandomWalkCard(
                        memo: memo,
                        card: card,
                        textMain: textMain,
                        textMuted: textMuted,
                        isDark: isDark,
                        baseUrl: baseUrl,
                        authHeader: authHeader,
                        audioPlaying: isAudioActive && _audioPlayer.playing,
                        audioLoading: isAudioActive && _audioLoading,
                        audioPositionListenable: isAudioActive ? _audioPositionNotifier : null,
                        audioDurationListenable: isAudioActive ? _audioDurationNotifier : null,
                        onAudioTap: () => unawaited(_toggleAudioPlayback(memo)),
                        onToggleTask: (request) =>
                            unawaited(_toggleMemoCheckbox(memo, request.taskIndex)),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
        ),
      ),
    );
  }
}

class _RandomWalkCard extends StatelessWidget {
  const _RandomWalkCard({
    required this.memo,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
    required this.baseUrl,
    required this.authHeader,
    required this.audioPlaying,
    required this.audioLoading,
    this.audioPositionListenable,
    this.audioDurationListenable,
    this.onAudioTap,
    this.onToggleTask,
  });

  final LocalMemo memo;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final bool isDark;
  final Uri? baseUrl;
  final String? authHeader;
  final bool audioPlaying;
  final bool audioLoading;
  final ValueListenable<Duration>? audioPositionListenable;
  final ValueListenable<Duration?>? audioDurationListenable;
  final VoidCallback? onAudioTap;
  final TaskToggleHandler? onToggleTask;

  @override
  Widget build(BuildContext context) {
    final dt = memo.updateTime;
    final dateText = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final language = context.appLanguage;
    final relative = _relative(dt, language);
    final content = memo.content.trim().isEmpty
        ? context.tr(zh: '（空内容）', en: '(Empty content)')
        : memo.content.trim();
    final contentStyle = TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, color: textMain);
    final imageEntries = collectMemoImageEntries(
      content: memo.content,
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
    );
    final audioAttachments =
        memo.attachments.where((a) => a.type.startsWith('audio')).toList(growable: false);
    final hasAudio = audioAttachments.isNotEmpty;
    final nonMediaAttachments = filterNonMediaAttachments(memo.attachments);
    final attachmentLines = attachmentNameLines(nonMediaAttachments);
    final attachmentCount = nonMediaAttachments.length;
    final audioDurationText = _parseVoiceDuration(memo.content) ?? '00:00';
    final audioDurationFallback = _parseVoiceDurationValue(memo.content);
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final imageBg =
        isDark ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6) : MemoFlowPalette.audioSurfaceLight;
    final maxGridHeight = MediaQuery.of(context).size.height * 0.4;
    final resolvedAudioTap = hasAudio ? onAudioTap : null;

    String formatDuration(Duration value) {
      final totalSeconds = value.inSeconds;
      final hh = totalSeconds ~/ 3600;
      final mm = (totalSeconds % 3600) ~/ 60;
      final ss = totalSeconds % 60;
      if (hh <= 0) {
        return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      }
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }

    Widget buildAudioRow(Duration position, Duration? duration) {
      final effectiveDuration = duration ?? audioDurationFallback;
      final clampedPosition = effectiveDuration != null && position > effectiveDuration
          ? effectiveDuration
          : position;
      final totalText = effectiveDuration != null
          ? formatDuration(effectiveDuration)
          : audioDurationText;
      final showPosition = clampedPosition > Duration.zero || audioPlaying;
      final displayText = effectiveDuration != null && showPosition
          ? '${formatDuration(clampedPosition)} / $totalText'
          : (showPosition ? formatDuration(clampedPosition) : totalText);

      return AudioRow(
        durationText: displayText,
        isDark: isDark,
        playing: audioPlaying,
        loading: audioLoading,
        position: clampedPosition,
        duration: duration,
        durationFallback: audioDurationFallback,
        onTap: resolvedAudioTap,
      );
    }

    Widget audioRow = buildAudioRow(Duration.zero, null);
    if (audioPositionListenable != null && audioDurationListenable != null) {
      audioRow = ValueListenableBuilder<Duration>(
        valueListenable: audioPositionListenable!,
        builder: (context, position, _) {
          return ValueListenableBuilder<Duration?>(
            valueListenable: audioDurationListenable!,
            builder: (context, duration, _) {
              return buildAudioRow(position, duration);
            },
          );
        },
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) => MemoDetailScreen(initialMemo: memo),
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(opacity: fade, child: child);
            },
          ),
        );
      },
      child: Hero(
        tag: memo.uid,
        createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateText,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: textMuted.withValues(alpha: 0.5), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        relative,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bodyHeight = constraints.maxHeight;
                        final fadeHeight = bodyHeight * 0.2;
                        return Stack(
                          children: [
                            SizedBox(
                              height: bodyHeight,
                              width: double.infinity,
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MemoMarkdown(
                                      data: content,
                                      textStyle: contentStyle,
                                      normalizeHeadings: true,
                                      renderImages: false,
                                      onToggleTask: onToggleTask,
                                    ),
                                    if (imageEntries.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      MemoImageGrid(
                                        images: imageEntries,
                                        columns: 3,
                                        maxCount: 9,
                                        maxHeight: maxGridHeight,
                                        radius: 10,
                                        spacing: 8,
                                        borderColor: borderColor.withValues(alpha: 0.65),
                                        backgroundColor: imageBg,
                                        textColor: textMain,
                                        enableDownload: true,
                                      ),
                                    ],
                                    if (hasAudio) ...[
                                      const SizedBox(height: 10),
                                      audioRow,
                                    ],
                                    if (attachmentCount > 0) ...[
                                      const SizedBox(height: 10),
                                      Builder(
                                        builder: (context) {
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => showAttachmentNamesToast(
                                              context,
                                              attachmentLines,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.attach_file,
                                                  size: 14,
                                                  color: textMuted,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  attachmentCount.toString(),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: fadeHeight,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        card.withAlpha(0),
                                        card,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _relative(DateTime dt, AppLanguage language) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays < 1) return trByLanguage(language: language, zh: '今天', en: 'Today');
    if (diff.inDays < 7) return trByLanguage(language: language, zh: '${diff.inDays}天前', en: '${diff.inDays}d ago');
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return trByLanguage(language: language, zh: '$weeks周前', en: '${weeks}w ago');
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return trByLanguage(language: language, zh: '$months个月前', en: '${months}mo ago');
    }
    final years = (diff.inDays / 365).floor();
    return trByLanguage(language: language, zh: '$years年前', en: '${years}y ago');
  }

  static String? _parseVoiceDuration(String content) {
    final value = _parseVoiceDurationValue(content);
    if (value == null) return null;
    final totalSeconds = value.inSeconds;
    final hh = totalSeconds ~/ 3600;
    final mm = (totalSeconds % 3600) ~/ 60;
    final ss = totalSeconds % 60;
    if (hh <= 0) {
      return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  static Duration? _parseVoiceDurationValue(String content) {
    final linePattern = RegExp(r'^[-*+]?\s*', unicode: true);
    final valuePattern = RegExp(
      r'^(时长|Duration)\s*[:：]\s*(\d{1,2}):(\d{1,2}):(\d{1,2})$',
      caseSensitive: false,
      unicode: true,
    );

    for (final rawLine in content.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final line = trimmed.replaceFirst(linePattern, '');
      final m = valuePattern.firstMatch(line);
      if (m == null) continue;
      final hh = int.tryParse(m.group(2) ?? '') ?? 0;
      final mm = int.tryParse(m.group(3) ?? '') ?? 0;
      final ss = int.tryParse(m.group(4) ?? '') ?? 0;
      if (hh == 0 && mm == 0 && ss == 0) return null;
      return Duration(hours: hh, minutes: mm, seconds: ss);
    }

    return null;
  }
}
