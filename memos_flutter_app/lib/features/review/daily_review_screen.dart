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
import '../../state/memo_timeline_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memo_image_grid.dart';
import '../memos/memo_markdown.dart';
import '../memos/memos_list_screen.dart';
import '../memos/widgets/audio_row.dart';
import '../../i18n/strings.g.dart';

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
  List<LocalMemo> _allMemos = const [];
  Set<String> _selectedTags = <String>{};
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    ref.listenManual(_memosProvider, (prev, next) {
      next.whenData((memos) {
        _allMemos = memos;
        final filtered = _filterMemos(memos);
        final changed = _syncDeck(filtered);
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
    _audioProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
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

  ({String url, String? localPath, Map<String, String>? headers})?
  _resolveAudioSource(Attachment attachment) {
    final rawLink = attachment.externalLink.trim();
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    if (rawLink.isNotEmpty) {
      final localPath = _localAttachmentPath(attachment);
      if (localPath != null) {
        return (
          url: Uri.file(localPath).toString(),
          localPath: localPath,
          headers: null,
        );
      }
      var resolved = resolveMaybeRelativeUrl(baseUrl, rawLink);
      if (rebaseAbsoluteFileUrlForV024) {
        final rebased = rebaseAbsoluteFileUrlToBase(baseUrl, resolved);
        if (rebased != null && rebased.isNotEmpty) {
          resolved = rebased;
        }
      }
      final isAbsolute = isAbsoluteUrl(resolved);
      final canAttachAuth = rebaseAbsoluteFileUrlForV024
          ? (!isAbsolute || isSameOriginWithBase(baseUrl, resolved))
          : !isAbsolute;
      final headers = (canAttachAuth && authHeader != null)
          ? {'Authorization': authHeader}
          : null;
      return (url: resolved, localPath: null, headers: headers);
    }

    if (baseUrl == null) return null;
    final name = attachment.name.trim();
    final filename = attachment.filename.trim();
    if (name.isEmpty || filename.isEmpty) return null;
    final url = joinBaseUrl(baseUrl, 'file/$name/$filename');
    final headers = authHeader == null ? null : {'Authorization': authHeader};
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
    final audioAttachments = memo.attachments
        .where((a) => a.type.startsWith('audio'))
        .toList(growable: false);
    if (audioAttachments.isEmpty) return;
    final attachment = audioAttachments.first;
    final source = _resolveAudioSource(attachment);
    if (source == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_unable_load_audio_source),
        ),
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
        loadedDuration = await _audioPlayer.setUrl(
          url,
          headers: source.headers,
        );
      }
      _audioDurationNotifier.value = loadedDuration ?? _audioPlayer.duration;
      _startAudioProgressTimer();
      await _audioPlayer.play();
    } catch (e) {
      _stopAudioProgressTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_playback_failed_2(e: e)),
          ),
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
    final timelineService = ref.read(memoTimelineServiceProvider);
    final tags = extractTags(updated);

    await timelineService.captureMemoVersion(memo);

    await db.upsertMemo(
      uid: memo.uid,
      content: updated,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: memo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: memo.attachments
          .map((a) => a.toJson())
          .toList(growable: false),
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

  List<LocalMemo> _filterMemos(List<LocalMemo> memos) {
    final normalizedTagKeys = _selectedTags
        .map(_tagKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    final range = _selectedDateRange;

    final hasTagFilter = normalizedTagKeys.isNotEmpty;
    final hasDateFilter = range != null;
    if (!hasTagFilter && !hasDateFilter) {
      return memos;
    }

    final dateWindow = range == null
        ? null
        : (
            start: DateTime(
              range.start.year,
              range.start.month,
              range.start.day,
            ),
            endExclusive: DateTime(
              range.end.year,
              range.end.month,
              range.end.day,
            ).add(const Duration(days: 1)),
          );

    final filtered = <LocalMemo>[];
    for (final memo in memos) {
      if (hasTagFilter) {
        final memoTagKeys = memo.tags
            .map(_tagKey)
            .where((key) => key.isNotEmpty)
            .toSet();
        if (memoTagKeys.intersection(normalizedTagKeys).isEmpty) {
          continue;
        }
      }
      if (hasDateFilter) {
        final createdAt = memo.createTime;
        if (createdAt.isBefore(dateWindow!.start) ||
            !createdAt.isBefore(dateWindow.endExclusive)) {
          continue;
        }
      }
      filtered.add(memo);
    }
    return filtered;
  }

  List<String> _availableTags() {
    final tagMap = <String, String>{};
    for (final memo in _allMemos) {
      for (final rawTag in memo.tags) {
        final normalized = _normalizeTag(rawTag);
        final key = _tagKey(normalized);
        if (key.isEmpty) continue;
        tagMap.putIfAbsent(key, () => normalized);
      }
    }
    final tags = tagMap.values.toList(growable: false);
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  String _normalizeTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed;
  }

  String _tagKey(String raw) {
    final normalized = _normalizeTag(raw);
    return normalized.toLowerCase();
  }

  DateTimeRange _normalizeRange(DateTimeRange range) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    if (end.isBefore(start)) {
      return DateTimeRange(start: start, end: start);
    }
    return DateTimeRange(start: start, end: end);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatRangeLabel(DateTimeRange? range, BuildContext context) {
    if (range == null) return context.t.strings.legacy.msg_select_date_range;
    return '${_formatDate(range.start)} ~ ${_formatDate(range.end)}';
  }

  Future<DateTimeRange?> _pickDateRange(DateTimeRange? initial) {
    final now = DateTime.now();
    final normalizedInitial = _normalizeRange(
      initial ??
          DateTimeRange(
            start: DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 29)),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: normalizedInitial,
    );
  }

  void _applyFilters({
    required Set<String> tags,
    required DateTimeRange? dateRange,
  }) {
    final normalizedTags = tags
        .map(_normalizeTag)
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final normalizedRange = dateRange == null
        ? null
        : _normalizeRange(dateRange);
    _selectedTags = normalizedTags;
    _selectedDateRange = normalizedRange;
    final changed = _syncDeck(_filterMemos(_allMemos));
    if (changed) {
      _swiperController.setCardIndex(0);
    }
    unawaited(_stopAudioPlayback());
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openFilterSheet() async {
    final availableTags = _availableTags();
    var draftTags = Set<String>.from(_selectedTags);
    var draftRange = _selectedDateRange;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final chipBg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final accent = MemoFlowPalette.primary;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(top: BorderSide(color: border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.t.strings.legacy.msg_filter,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                draftTags = <String>{};
                                draftRange = null;
                              });
                            },
                            child: Text(context.t.strings.legacy.msg_clear_2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t.strings.legacy.msg_select_tags,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (availableTags.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            context.t.strings.legacy.msg_no_tags_yet,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textMuted,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(context.t.strings.legacy.msg_all_2),
                              selected: draftTags.isEmpty,
                              onSelected: (_) {
                                setModalState(() {
                                  draftTags.clear();
                                });
                              },
                              backgroundColor: chipBg,
                              selectedColor: accent.withValues(
                                alpha: isDark ? 0.24 : 0.15,
                              ),
                              side: BorderSide(
                                color: draftTags.isEmpty
                                    ? accent.withValues(
                                        alpha: isDark ? 0.62 : 0.55,
                                      )
                                    : border,
                              ),
                              labelStyle: TextStyle(
                                color: draftTags.isEmpty ? accent : textMain,
                                fontWeight: FontWeight.w600,
                              ),
                              showCheckmark: false,
                            ),
                            for (final tag in availableTags)
                              FilterChip(
                                label: Text('#$tag'),
                                selected: draftTags.contains(tag),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      draftTags.add(tag);
                                    } else {
                                      draftTags.remove(tag);
                                    }
                                  });
                                },
                                backgroundColor: chipBg,
                                selectedColor: accent.withValues(
                                  alpha: isDark ? 0.24 : 0.15,
                                ),
                                side: BorderSide(
                                  color: draftTags.contains(tag)
                                      ? accent.withValues(
                                          alpha: isDark ? 0.62 : 0.55,
                                        )
                                      : border,
                                ),
                                labelStyle: TextStyle(
                                  color: draftTags.contains(tag)
                                      ? accent
                                      : textMain,
                                  fontWeight: FontWeight.w600,
                                ),
                                showCheckmark: false,
                              ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      Text(
                        context.t.strings.legacy.msg_select_date_range,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range_outlined,
                              size: 18,
                              color: textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatRangeLabel(draftRange, context),
                                style: TextStyle(
                                  color: draftRange == null
                                      ? textMuted
                                      : textMain,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await _pickDateRange(draftRange);
                                if (picked == null) return;
                                setModalState(() {
                                  draftRange = _normalizeRange(picked);
                                });
                              },
                              child: Text(context.t.strings.legacy.msg_select),
                            ),
                            if (draftRange != null)
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    draftRange = null;
                                  });
                                },
                                child: Text(
                                  context.t.strings.legacy.msg_clear_2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(bottomSheetContext).pop(),
                              child: Text(
                                context.t.strings.legacy.msg_cancel_2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                _applyFilters(
                                  tags: draftTags,
                                  dateRange: draftRange,
                                );
                                Navigator.of(bottomSheetContext).pop();
                              },
                              child: Text(context.t.strings.legacy.msg_apply),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final hasActiveFilter =
        _selectedTags.isNotEmpty || _selectedDateRange != null;
    final selectedTags = _selectedTags.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
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
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text(context.t.strings.legacy.msg_random_review),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: context.t.strings.legacy.msg_filter,
              icon: Icon(
                Icons.tune_rounded,
                color: hasActiveFilter ? MemoFlowPalette.primary : null,
              ),
              onPressed: _openFilterSheet,
            ),
          ],
        ),
        body: memosAsync.when(
          data: (memos) {
            if (memos.isEmpty) {
              return Center(
                child: Text(
                  context.t.strings.legacy.msg_no_content_yet,
                  style: TextStyle(color: textMuted),
                ),
              );
            }

            final deck = _deck;
            if (deck.isEmpty) {
              return Center(
                child: Text(
                  context.t.strings.legacy.msg_no_content_yet,
                  style: TextStyle(color: textMuted),
                ),
              );
            }
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
                          context.t.strings.legacy.msg_randomly_draw_memo_cards,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ),
                      Text(
                        '$displayIndex / $total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasActiveFilter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in selectedTags)
                          _ActiveFilterChip(label: '#$tag', isDark: isDark),
                        if (_selectedDateRange != null)
                          _ActiveFilterChip(
                            label: _formatRangeLabel(
                              _selectedDateRange,
                              context,
                            ),
                            isDark: isDark,
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
                      swipeOptions: const SwipeOptions.symmetric(
                        horizontal: true,
                      ),
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
                          rebaseAbsoluteFileUrlForV024:
                              rebaseAbsoluteFileUrlForV024,
                          audioPlaying: isAudioActive && _audioPlayer.playing,
                          audioLoading: isAudioActive && _audioLoading,
                          audioPositionListenable: isAudioActive
                              ? _audioPositionNotifier
                              : null,
                          audioDurationListenable: isAudioActive
                              ? _audioDurationNotifier
                              : null,
                          onAudioTap: () =>
                              unawaited(_toggleAudioPlayback(memo)),
                          onToggleTask: (request) => unawaited(
                            _toggleMemoCheckbox(memo, request.taskIndex),
                          ),
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
          error: (e, _) => Center(
            child: Text(context.t.strings.legacy.msg_failed_load_4(e: e)),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = MemoFlowPalette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: isDark ? 0.6 : 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
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
    required this.rebaseAbsoluteFileUrlForV024,
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
  final bool rebaseAbsoluteFileUrlForV024;
  final bool audioPlaying;
  final bool audioLoading;
  final ValueListenable<Duration>? audioPositionListenable;
  final ValueListenable<Duration?>? audioDurationListenable;
  final VoidCallback? onAudioTap;
  final TaskToggleHandler? onToggleTask;

  @override
  Widget build(BuildContext context) {
    final dt = memo.updateTime;
    final dateText =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final language = context.appLanguage;
    final relative = _relative(dt, language);
    final content = memo.content.trim().isEmpty
        ? context.t.strings.legacy.msg_empty_content
        : memo.content.trim();
    final contentStyle = TextStyle(
      fontSize: 16,
      height: 1.6,
      fontWeight: FontWeight.w600,
      color: textMain,
    );
    final imageEntries = collectMemoImageEntries(
      content: memo.content,
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
    );
    final audioAttachments = memo.attachments
        .where((a) => a.type.startsWith('audio'))
        .toList(growable: false);
    final hasAudio = audioAttachments.isNotEmpty;
    final nonMediaAttachments = filterNonMediaAttachments(memo.attachments);
    final attachmentLines = attachmentNameLines(nonMediaAttachments);
    final attachmentCount = nonMediaAttachments.length;
    final audioDurationText = _parseVoiceDuration(memo.content) ?? '00:00';
    final audioDurationFallback = _parseVoiceDurationValue(memo.content);
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final imageBg = isDark
        ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6)
        : MemoFlowPalette.audioSurfaceLight;
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
      final clampedPosition =
          effectiveDuration != null && position > effectiveDuration
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
            pageBuilder: (context, animation, secondaryAnimation) =>
                MemoDetailScreen(initialMemo: memo),
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: textMuted.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        relative,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textMuted.withValues(alpha: 0.6),
                        ),
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
                                        borderColor: borderColor.withValues(
                                          alpha: 0.65,
                                        ),
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
                                            onTap: () =>
                                                showAttachmentNamesToast(
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
                                      colors: [card.withAlpha(0), card],
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
    if (diff.inDays < 1) {
      return trByLanguageKey(language: language, key: 'legacy.msg_today');
    }
    if (diff.inDays < 7) {
      return trByLanguageKey(
        language: language,
        key: 'legacy.msg_ago_3',
        params: {'diff_inDays': diff.inDays},
      );
    }
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return trByLanguageKey(
        language: language,
        key: 'legacy.msg_ago_4',
        params: {'weeks': weeks},
      );
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return trByLanguageKey(
        language: language,
        key: 'legacy.msg_ago',
        params: {'months': months},
      );
    }
    final years = (diff.inDays / 365).floor();
    return trByLanguageKey(
      language: language,
      key: 'legacy.msg_ago_2',
      params: {'years': years},
    );
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
