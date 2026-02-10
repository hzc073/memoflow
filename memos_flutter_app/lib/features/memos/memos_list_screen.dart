import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_localization.dart';
import '../../core/attachment_toast.dart';
import '../../core/drawer_navigation.dart';
import '../../core/location_launcher.dart';
import '../../core/memo_relations.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/shortcut.dart';
import '../../features/home/app_drawer.dart';
import '../../state/database_provider.dart';
import '../../state/local_library_provider.dart';
import '../../state/local_library_scanner.dart';
import '../../state/logging_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/reminder_providers.dart';
import '../../state/reminder_scheduler.dart';
import '../../state/reminder_settings_provider.dart';
import '../../state/search_history_provider.dart';
import '../../state/session_provider.dart';
import '../../state/user_settings_provider.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../notifications/notifications_screen.dart';
import '../reminders/memo_reminder_editor_screen.dart';
import '../reminders/reminder_utils.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/shortcut_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import 'memo_detail_screen.dart';
import 'memo_editor_screen.dart';
import 'memo_image_grid.dart';
import 'memo_media_grid.dart';
import 'memo_markdown.dart';
import 'memo_location_line.dart';
import 'memo_video_grid.dart';
import 'note_input_sheet.dart';
import 'widgets/audio_row.dart';
import '../../i18n/strings.g.dart';

const _maxPreviewLines = 6;
const _maxPreviewRunes = 220;

typedef _PreviewResult = ({String text, bool truncated});

final RegExp _markdownLinkPattern = RegExp(r'\[([^\]]*)\]\(([^)]+)\)');
final RegExp _whitespaceCollapsePattern = RegExp(r'\s+');

enum _MemoSyncStatus { none, pending, failed }

enum _MemoSortOption { createAsc, createDesc, updateAsc, updateDesc }

class _OutboxMemoStatus {
  const _OutboxMemoStatus({required this.pending, required this.failed});
  const _OutboxMemoStatus.empty()
    : pending = const <String>{},
      failed = const <String>{};

  final Set<String> pending;
  final Set<String> failed;
}

final _outboxMemoStatusProvider = StreamProvider<_OutboxMemoStatus>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);

  Future<_OutboxMemoStatus> load() async {
    final sqlite = await db.db;
    final rows = await sqlite.query(
      'outbox',
      columns: const ['type', 'payload', 'state'],
      where: 'state IN (0, 2)',
      orderBy: 'id ASC',
    );
    final pending = <String>{};
    final failed = <String>{};

    for (final row in rows) {
      final type = row['type'];
      final payload = row['payload'];
      final state = row['state'];
      if (type is! String || payload is! String) continue;

      final decoded = _decodeOutboxPayload(payload);
      final uid = _extractOutboxMemoUid(type, decoded);
      if (uid == null || uid.trim().isEmpty) continue;
      final normalized = uid.trim();

      if (state == 2) {
        failed.add(normalized);
        pending.remove(normalized);
      } else {
        if (!failed.contains(normalized)) {
          pending.add(normalized);
        }
      }
    }

    return _OutboxMemoStatus(pending: pending, failed: failed);
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

Map<String, dynamic> _decodeOutboxPayload(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {}
  return <String, dynamic>{};
}

String? _extractOutboxMemoUid(String type, Map<String, dynamic> payload) {
  return switch (type) {
    'create_memo' ||
    'update_memo' ||
    'delete_memo' => payload['uid'] as String?,
    'upload_attachment' => payload['memo_uid'] as String?,
    _ => null,
  };
}

_MemoSyncStatus _resolveMemoSyncStatus(
  LocalMemo memo,
  _OutboxMemoStatus status,
) {
  final uid = memo.uid.trim();
  if (uid.isEmpty) return _MemoSyncStatus.none;
  if (status.failed.contains(uid)) return _MemoSyncStatus.failed;
  if (status.pending.contains(uid)) return _MemoSyncStatus.pending;
  return switch (memo.syncState) {
    SyncState.error => _MemoSyncStatus.failed,
    SyncState.pending => _MemoSyncStatus.pending,
    _ => _MemoSyncStatus.none,
  };
}

int _compactRuneCount(String text) {
  if (text.isEmpty) return 0;
  final compact = text.replaceAll(_whitespaceCollapsePattern, '');
  return compact.runes.length;
}

bool _isWhitespaceRune(int rune) {
  switch (rune) {
    case 0x09:
    case 0x0A:
    case 0x0B:
    case 0x0C:
    case 0x0D:
    case 0x20:
      return true;
    default:
      return String.fromCharCode(rune).trim().isEmpty;
  }
}

int _cutIndexByCompactRunes(String text, int maxCompactRunes) {
  if (text.isEmpty || maxCompactRunes <= 0) return 0;
  var count = 0;
  final iterator = RuneIterator(text);
  while (iterator.moveNext()) {
    final rune = iterator.current;
    if (!_isWhitespaceRune(rune)) {
      count++;
      if (count >= maxCompactRunes) {
        return iterator.rawIndex + iterator.currentSize;
      }
    }
  }
  return text.length;
}

String _truncatePreviewText(String text, int maxCompactRunes) {
  var count = 0;
  var index = 0;

  for (final match in _markdownLinkPattern.allMatches(text)) {
    final prefix = text.substring(index, match.start);
    final prefixCount = _compactRuneCount(prefix);
    if (count + prefixCount >= maxCompactRunes) {
      final remaining = maxCompactRunes - count;
      final cutOffset = _cutIndexByCompactRunes(prefix, remaining);
      return text.substring(0, index + cutOffset);
    }
    count += prefixCount;

    final label = match.group(1) ?? '';
    final labelCount = _compactRuneCount(label);
    if (count + labelCount >= maxCompactRunes) {
      if (count >= maxCompactRunes) {
        return text.substring(0, match.start);
      }
      return text.substring(0, match.end);
    }
    count += labelCount;
    index = match.end;
  }

  final tail = text.substring(index);
  final tailCount = _compactRuneCount(tail);
  if (count + tailCount >= maxCompactRunes) {
    final remaining = maxCompactRunes - count;
    final cutOffset = _cutIndexByCompactRunes(tail, remaining);
    return text.substring(0, index + cutOffset);
  }

  return text;
}

class _LruCache<K, V> {
  _LruCache({required int capacity}) : _capacity = capacity;

  final int _capacity;
  final _map = <K, V>{};

  V? get(K key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  void set(K key, V value) {
    if (_capacity <= 0) return;
    _map.remove(key);
    _map[key] = value;
    if (_map.length > _capacity) {
      _map.remove(_map.keys.first);
    }
  }

  void removeWhere(bool Function(K key) test) {
    final keys = _map.keys.where(test).toList(growable: false);
    for (final key in keys) {
      _map.remove(key);
    }
  }
}

class _MemoRenderCacheEntry {
  const _MemoRenderCacheEntry({
    required this.previewText,
    required this.preview,
    required this.taskStats,
  });

  final String previewText;
  final _PreviewResult preview;
  final TaskStats taskStats;
}

final _memoRenderCache = _LruCache<String, _MemoRenderCacheEntry>(
  capacity: 120,
);

String _memoRenderCacheKey(
  LocalMemo memo, {
  required bool collapseLongContent,
  required bool collapseReferences,
  required AppLanguage language,
}) {
  return '${memo.uid}|'
      '${memo.contentFingerprint}|'
      '${collapseLongContent ? 1 : 0}|'
      '${collapseReferences ? 1 : 0}|'
      '${language.name}';
}

void _invalidateMemoRenderCacheForUid(String memoUid) {
  final trimmed = memoUid.trim();
  if (trimmed.isEmpty) return;
  _memoRenderCache.removeWhere((key) => key.startsWith('$trimmed|'));
}

_PreviewResult _truncatePreview(
  String text, {
  required bool collapseLongContent,
}) {
  if (!collapseLongContent) {
    return (text: text, truncated: false);
  }

  var result = text;
  var truncated = false;
  final lines = result.split('\n');
  if (lines.length > _maxPreviewLines) {
    result = lines.take(_maxPreviewLines).join('\n');
    truncated = true;
  }

  final truncatedText = _truncatePreviewText(result, _maxPreviewRunes);
  if (truncatedText != result) {
    result = truncatedText;
    truncated = true;
  }

  if (truncated) {
    result = result.trimRight();
    result = result.endsWith('...') ? result : '$result...';
  }
  return (text: result, truncated: truncated);
}

class MemosListScreen extends ConsumerStatefulWidget {
  const MemosListScreen({
    super.key,
    required this.title,
    required this.state,
    this.tag,
    this.dayFilter,
    this.showDrawer = false,
    this.enableCompose = false,
    this.openDrawerOnStart = false,
    this.enableSearch = true,
    this.enableTitleMenu = true,
    this.showPillActions = true,
    this.showFilterTagChip = false,
    this.showTagFilters = false,
    this.toastMessage,
  });

  final String title;
  final String state;
  final String? tag;
  final DateTime? dayFilter;
  final bool showDrawer;
  final bool enableCompose;
  final bool openDrawerOnStart;
  final bool enableSearch;
  final bool enableTitleMenu;
  final bool showPillActions;
  final bool showFilterTagChip;
  final bool showTagFilters;
  final String? toastMessage;

  @override
  ConsumerState<MemosListScreen> createState() => _MemosListScreenState();
}

class _MemosListScreenState extends ConsumerState<MemosListScreen> {
  static const int _initialPageSize = 200;
  static const int _pageStep = 200;
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _titleKey = GlobalKey();
  final _scrollController = ScrollController();
  GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();

  var _searching = false;
  var _openedDrawerOnStart = false;
  String? _selectedShortcutId;
  String? _activeTagFilter;
  var _sortOption = _MemoSortOption.createDesc;
  List<LocalMemo> _animatedMemos = [];
  String _listSignature = '';
  final Set<String> _pendingRemovedUids = <String>{};
  var _showBackToTop = false;
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
  DateTime? _lastAudioProgressLogAt;
  Duration _lastAudioProgressLogPosition = Duration.zero;
  Duration? _lastAudioLoggedDuration;
  bool _audioDurationMissingLogged = false;
  String? _playingMemoUid;
  String? _playingAudioUrl;
  bool _audioLoading = false;
  DateTime? _lastBackPressedAt;
  bool _autoScanTriggered = false;
  bool _autoScanInFlight = false;
  int _pageSize = _initialPageSize;
  bool _reachedEnd = false;
  bool _loadingMore = false;
  String _paginationKey = '';
  int _lastResultCount = 0;
  int _currentResultCount = 0;
  bool _currentLoading = false;
  bool _currentShowSearchLanding = false;

  ({int startSec, int endSecExclusive}) _dayRangeSeconds(DateTime day) {
    final localDay = DateTime(day.year, day.month, day.day);
    final nextDay = localDay.add(const Duration(days: 1));
    return (
      startSec: localDay.toUtc().millisecondsSinceEpoch ~/ 1000,
      endSecExclusive: nextDay.toUtc().millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  void initState() {
    super.initState();
    _activeTagFilter = _normalizeTag(widget.tag);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = widget.toastMessage;
      if (message == null || message.trim().isEmpty) return;
      showTopToast(context, message);
    });
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
        final memoUid = _playingMemoUid;
        if (memoUid != null) {
          _logAudioAction(
            'completed memo=${_shortMemoUid(memoUid)} pos=${_formatDuration(_audioPlayer.position)}',
            context: {
              'memo': memoUid,
              'positionMs': _audioPlayer.position.inMilliseconds,
            },
          );
        }
        _resetAudioLogState();
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
        return;
      }
      setState(() {});
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
      if (duration == null || duration <= Duration.zero) {
        if (!_audioDurationMissingLogged) {
          _audioDurationMissingLogged = true;
          _logAudioBreadcrumb(
            'duration missing memo=${_shortMemoUid(_playingMemoUid!)}',
            context: {
              'memo': _playingMemoUid!,
              'durationMs': duration?.inMilliseconds,
            },
          );
        }
        return;
      }
      if (_lastAudioLoggedDuration == duration) return;
      _lastAudioLoggedDuration = duration;
      _logAudioBreadcrumb(
        'duration memo=${_shortMemoUid(_playingMemoUid!)} dur=${_formatDuration(duration)}',
        context: {
          'memo': _playingMemoUid!,
          'durationMs': duration.inMilliseconds,
        },
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDrawerIfNeeded());
  }

  @override
  void didUpdateWidget(covariant MemosListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _activeTagFilter = _normalizeTag(widget.tag);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioStateSub?.cancel();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioProgressTimer?.cancel();
    _audioPositionNotifier.dispose();
    _audioDurationNotifier.dispose();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _normalizeTag(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final withoutHash = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;
    return withoutHash.toLowerCase();
  }

  void _selectTagFilter(String? tag) {
    setState(() => _activeTagFilter = _normalizeTag(tag));
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final metrics = _scrollController.position;
    final threshold = metrics.viewportDimension * 2;
    final shouldShow = metrics.pixels >= threshold;
    if (shouldShow != _showBackToTop && mounted) {
      setState(() => _showBackToTop = shouldShow);
    }
    _maybeLoadMore();
  }

  void _triggerLoadMore() {
    _loadingMore = true;
    _pageSize += _pageStep;
    if (mounted) {
      setState(() {});
    }
  }

  void _maybeLoadMore() {
    if (_currentShowSearchLanding) return;
    if (_currentLoading) return;
    if (_loadingMore || _reachedEnd) return;
    if (!_scrollController.hasClients) return;
    final metrics = _scrollController.position;
    if (metrics.maxScrollExtent <= 0) return;
    final triggerOffset = metrics.maxScrollExtent - (metrics.viewportDimension * 0.6);
    if (metrics.pixels < triggerOffset) return;
    if (_currentResultCount < _pageSize) {
      _reachedEnd = true;
      return;
    }
    _triggerLoadMore();
  }

  void _maybeAutoLoadMore() {
    if (_currentShowSearchLanding) return;
    if (_currentLoading) return;
    if (_loadingMore || _reachedEnd) return;
    if (_currentResultCount < _pageSize || _currentResultCount <= 0) {
      _reachedEnd = true;
      return;
    }
    _triggerLoadMore();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  bool _shouldEnableHomeSort({required bool useRemoteSearch}) {
    if (_searching || useRemoteSearch) return false;
    if (widget.state != 'NORMAL') return false;
    return widget.showDrawer;
  }

  String _sortOptionLabel(BuildContext context, _MemoSortOption option) {
    return switch (option) {
      _MemoSortOption.createAsc => context.t.strings.legacy.msg_created_time,
      _MemoSortOption.createDesc => context.t.strings.legacy.msg_created_time_2,
      _MemoSortOption.updateAsc => context.t.strings.legacy.msg_updated_time_2,
      _MemoSortOption.updateDesc => context.t.strings.legacy.msg_updated_time,
    };
  }

  int _compareMemosForSort(LocalMemo a, LocalMemo b) {
    if (a.pinned != b.pinned) {
      return a.pinned ? -1 : 1;
    }

    int primary;
    switch (_sortOption) {
      case _MemoSortOption.createAsc:
        primary = a.createTime.compareTo(b.createTime);
        break;
      case _MemoSortOption.createDesc:
        primary = b.createTime.compareTo(a.createTime);
        break;
      case _MemoSortOption.updateAsc:
        primary = a.updateTime.compareTo(b.updateTime);
        break;
      case _MemoSortOption.updateDesc:
        primary = b.updateTime.compareTo(a.updateTime);
        break;
    }
    if (primary != 0) return primary;

    final fallback = b.createTime.compareTo(a.createTime);
    if (fallback != 0) return fallback;
    return a.uid.compareTo(b.uid);
  }

  List<LocalMemo> _applyHomeSort(List<LocalMemo> memos) {
    if (memos.length < 2) return memos;
    final sorted = List<LocalMemo>.from(memos);
    sorted.sort(_compareMemosForSort);
    return sorted;
  }

  Widget _buildSortMenuButton(BuildContext context, {required bool isDark}) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    return PopupMenuButton<_MemoSortOption>(
      tooltip: context.t.strings.legacy.msg_sort,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withValues(alpha: 0.7)),
      ),
      color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
      onSelected: (value) {
        if (value == _sortOption) return;
        setState(() => _sortOption = value);
      },
      itemBuilder: (context) => [
        _buildSortMenuItem(context, _MemoSortOption.createAsc, textColor),
        _buildSortMenuItem(context, _MemoSortOption.createDesc, textColor),
        _buildSortMenuItem(context, _MemoSortOption.updateAsc, textColor),
        _buildSortMenuItem(context, _MemoSortOption.updateDesc, textColor),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  PopupMenuItem<_MemoSortOption> _buildSortMenuItem(
    BuildContext context,
    _MemoSortOption option,
    Color textColor,
  ) {
    final selected = option == _sortOption;
    final label = _sortOptionLabel(context, option);
    return PopupMenuItem<_MemoSortOption>(
      value: option,
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: selected
                ? Icon(Icons.check, size: 16, color: MemoFlowPalette.primary)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? MemoFlowPalette.primary : textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _resetAudioLogState() {
    _lastAudioProgressLogAt = null;
    _lastAudioProgressLogPosition = Duration.zero;
    _lastAudioLoggedDuration = null;
    _audioDurationMissingLogged = false;
  }

  void _logAudioAction(String message, {Map<String, Object?>? context}) {
    if (!mounted) return;
    ref.read(loggerServiceProvider).recordAction('Audio $message');
    ref.read(logManagerProvider).info('Audio $message', context: context);
  }

  void _logAudioBreadcrumb(String message, {Map<String, Object?>? context}) {
    if (!mounted) return;
    ref.read(loggerServiceProvider).recordBreadcrumb('Audio: $message');
    ref.read(logManagerProvider).info('Audio $message', context: context);
  }

  void _logAudioError(String message, Object error, StackTrace stackTrace) {
    if (!mounted) return;
    ref.read(loggerServiceProvider).recordError('Audio $message');
    ref
        .read(logManagerProvider)
        .error('Audio $message', error: error, stackTrace: stackTrace);
  }

  void _maybeLogAudioProgress(Duration position) {
    final memoUid = _playingMemoUid;
    if (!mounted || memoUid == null) return;
    final now = DateTime.now();
    final lastAt = _lastAudioProgressLogAt;
    if (lastAt != null && now.difference(lastAt) < const Duration(seconds: 4)) {
      return;
    }
    final lastPos = _lastAudioProgressLogPosition;
    final duration = _audioDurationNotifier.value;
    final message = position <= lastPos && lastAt != null
        ? 'progress stalled memo=${_shortMemoUid(memoUid)} pos=${_formatDuration(position)} dur=${_formatDuration(duration)}'
        : 'progress memo=${_shortMemoUid(memoUid)} pos=${_formatDuration(position)} dur=${_formatDuration(duration)}';
    _logAudioBreadcrumb(
      message,
      context: {
        'memo': memoUid,
        'positionMs': position.inMilliseconds,
        'durationMs': duration?.inMilliseconds,
        'playing': _audioPlayer.playing,
        'state': _audioPlayer.processingState.toString(),
      },
    );
    _lastAudioProgressLogAt = now;
    _lastAudioProgressLogPosition = position;
  }

  String _shortMemoUid(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return '--';
    return trimmed.length <= 6 ? trimmed : trimmed.substring(0, 6);
  }

  String _formatDuration(Duration? value) {
    if (value == null) return '--:--';
    final totalSeconds = value.inSeconds;
    final hh = totalSeconds ~/ 3600;
    final mm = (totalSeconds % 3600) ~/ 60;
    final ss = totalSeconds % 60;
    if (hh <= 0) {
      return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  String _formatReminderTime(DateTime time) {
    final locale = Localizations.localeOf(context).toString();
    final datePart = DateFormat.Md(locale).format(time);
    final timePart = DateFormat.Hm(locale).format(time);
    return '$datePart $timePart';
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
      _maybeLogAudioProgress(position);
    });
  }

  void _stopAudioProgressTimer() {
    _audioProgressTimer?.cancel();
    _audioProgressTimer = null;
    _audioProgressStart = null;
  }

  Future<void> _seekAudioPosition(LocalMemo memo, Duration target) async {
    if (_playingMemoUid != memo.uid) return;
    final duration = _audioDurationNotifier.value;
    if (duration == null || duration <= Duration.zero) return;
    var clamped = target;
    if (clamped < Duration.zero) {
      clamped = Duration.zero;
    } else if (clamped > duration) {
      clamped = duration;
    }
    await _audioPlayer.seek(clamped);
    _audioProgressBase = clamped;
    _audioProgressLast = clamped;
    _audioProgressStart = DateTime.now();
    _audioPositionNotifier.value = clamped;
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
      final isAbsolute = isAbsoluteUrl(rawLink);
      final resolved = resolveMaybeRelativeUrl(baseUrl, rawLink);
      final headers = (!isAbsolute && authHeader != null) ? {'Authorization': authHeader} : null;
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

  Future<void> _toggleAudioPlayback(LocalMemo memo) async {
    if (_audioLoading) return;
    final audioAttachments = memo.attachments
        .where((a) => a.type.startsWith('audio'))
        .toList(growable: false);
    if (audioAttachments.isEmpty) return;
    final attachment = audioAttachments.first;
    final source = _resolveAudioSource(attachment);
    if (source == null) {
      _logAudioBreadcrumb('source missing memo=${_shortMemoUid(memo.uid)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_unable_load_audio_source,
          ),
        ),
      );
      return;
    }

    final url = source.url;
    final sourceLabel = source.localPath != null ? 'local' : 'remote';
    final sameTarget = _playingMemoUid == memo.uid && _playingAudioUrl == url;
    if (sameTarget) {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        _stopAudioProgressTimer();
        _logAudioAction(
          'pause memo=${_shortMemoUid(memo.uid)} pos=${_formatDuration(_audioPlayer.position)}',
          context: {
            'memo': memo.uid,
            'positionMs': _audioPlayer.position.inMilliseconds,
            'source': sourceLabel,
          },
        );
      } else {
        _startAudioProgressTimer();
        _lastAudioProgressLogAt = null;
        _logAudioAction(
          'resume memo=${_shortMemoUid(memo.uid)} pos=${_formatDuration(_audioPlayer.position)}',
          context: {
            'memo': memo.uid,
            'positionMs': _audioPlayer.position.inMilliseconds,
            'source': sourceLabel,
          },
        );
        await _audioPlayer.play();
      }
      _audioPositionNotifier.value = _audioPlayer.position;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _resetAudioLogState();
    _logAudioAction(
      'load start memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
      context: {'memo': memo.uid, 'source': sourceLabel},
    );
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
      final resolvedDuration = loadedDuration ?? _audioPlayer.duration;
      _audioDurationNotifier.value = resolvedDuration;
      if (resolvedDuration == null || resolvedDuration <= Duration.zero) {
        _audioDurationMissingLogged = true;
        _logAudioBreadcrumb(
          'duration missing memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
          context: {
            'memo': memo.uid,
            'durationMs': resolvedDuration?.inMilliseconds,
            'source': sourceLabel,
          },
        );
      } else {
        _lastAudioLoggedDuration = resolvedDuration;
        _logAudioBreadcrumb(
          'duration memo=${_shortMemoUid(memo.uid)} dur=${_formatDuration(resolvedDuration)} source=$sourceLabel',
          context: {
            'memo': memo.uid,
            'durationMs': resolvedDuration.inMilliseconds,
            'source': sourceLabel,
          },
        );
      }
      _logAudioAction(
        'play memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
        context: {'memo': memo.uid, 'source': sourceLabel},
      );
      _startAudioProgressTimer();
      if (mounted) {
        setState(() => _audioLoading = false);
      }
      await _audioPlayer.play();
    } catch (e, stackTrace) {
      _logAudioError(
        'playback failed memo=${_shortMemoUid(memo.uid)} source=$sourceLabel',
        e,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _audioLoading = false;
        _playingMemoUid = null;
        _playingAudioUrl = null;
      });
      _stopAudioProgressTimer();
      _audioPositionNotifier.value = Duration.zero;
      _audioDurationNotifier.value = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_playback_failed(e: e)),
        ),
      );
      return;
    }
  }

  void _openDrawerIfNeeded() {
    if (!mounted ||
        _openedDrawerOnStart ||
        !widget.openDrawerOnStart ||
        !widget.showDrawer) {
      return;
    }
    _openedDrawerOnStart = true;
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openSearch() {
    setState(() => _searching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _searching = false);
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(searchHistoryProvider.notifier).add(trimmed);
  }

  void _applySearchQuery(String query) {
    final trimmed = query.trim();
    _searchController.text = trimmed;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    setState(() {});
    _submitSearch(trimmed);
  }

  Shortcut? _findShortcutById(List<Shortcut> shortcuts) {
    final id = _selectedShortcutId;
    if (id == null || id.isEmpty) return null;
    for (final shortcut in shortcuts) {
      if (shortcut.shortcutId == id) return shortcut;
    }
    return null;
  }

  String _formatShortcutLoadError(BuildContext context, Object error) {
    if (error is UnsupportedError) {
      return context.t.strings.legacy.msg_shortcuts_not_supported_server;
    }
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return context.t.strings.legacy.msg_shortcuts_not_supported_server;
      }
    }
    return context.t.strings.legacy.msg_failed_load_shortcuts;
  }

  bool get _isAllMemos {
    final tag = _activeTagFilter;
    return widget.state == 'NORMAL' && (tag == null || tag.isEmpty);
  }

  void _backToAllMemos() {
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

  Future<bool> _handleWillPop() async {
    if (_searching) {
      _closeSearch();
      return false;
    }
    if (widget.dayFilter != null) {
      return true;
    }
    if (!_isAllMemos) {
      if (widget.showDrawer) {
        _backToAllMemos();
        return false;
      }
      return true;
    }

    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      showTopToast(
        context,
        context.t.strings.legacy.msg_press_back_exit,
        duration: const Duration(seconds: 2),
      );
      return false;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return true;
  }

  void _navigateDrawer(AppDrawerDestination dest) {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final hasAccount =
        ref.read(appSessionProvider).valueOrNull?.currentAccount != null;
    if (!hasAccount && dest == AppDrawerDestination.explore) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }
    final route = switch (dest) {
      AppDrawerDestination.memos => const MemosListScreen(
        title: 'MemoFlow',
        state: 'NORMAL',
        showDrawer: true,
        enableCompose: true,
      ),
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.explore => const ExploreScreen(),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
        title: context.t.strings.legacy.msg_archive,
        state: 'ARCHIVED',
        showDrawer: true,
      ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    closeDrawerThenPushReplacement(context, route);
  }

  void _openNotifications() {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final hasAccount =
        ref.read(appSessionProvider).valueOrNull?.currentAccount != null;
    if (!hasAccount) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_feature_not_available_local_library_mode,
      );
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  void _openSyncQueue() {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SyncQueueScreen()));
  }

  void _openTagFromDrawer(String tag) {
    if (ref.read(appPreferencesProvider).hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    closeDrawerThenPushReplacement(
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

  Future<void> _openNoteInput() async {
    if (!widget.enableCompose) return;
    await NoteInputSheet.show(context);
  }

  Future<void> _openAccountSwitcher() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final localLibraries = ref.read(localLibrariesProvider);
    final total = accounts.length + localLibraries.length;
    if (total < 2) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.t.strings.legacy.msg_switch_workspace),
              ),
            ),
            if (accounts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.t.strings.legacy.msg_accounts,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              ...accounts.map(
                (a) => ListTile(
                  leading: Icon(
                    a.key == session?.currentKey
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    a.user.displayName.isNotEmpty
                        ? a.user.displayName
                        : a.user.name,
                  ),
                  subtitle: Text(a.baseUrl.toString()),
                  onTap: () async {
                    await Navigator.of(context).maybePop();
                    if (!mounted) return;
                    await ref
                        .read(appSessionProvider.notifier)
                        .switchAccount(a.key);
                  },
                ),
              ),
            ],
            if (localLibraries.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.t.strings.legacy.msg_local_libraries,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              ...localLibraries.map(
                (l) => ListTile(
                  leading: Icon(
                    l.key == session?.currentKey
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    l.name.isNotEmpty
                        ? l.name
                        : context.t.strings.legacy.msg_local_library,
                  ),
                  subtitle: Text(l.locationLabel),
                  onTap: () async {
                    await Navigator.of(context).maybePop();
                    if (!mounted) return;
                    await ref
                        .read(appSessionProvider.notifier)
                        .switchWorkspace(l.key);
                    if (!mounted) return;
                    await WidgetsBinding.instance.endOfFrame;
                    if (!mounted) return;
                    await _maybeScanLocalLibrary();
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeScanLocalLibrary() async {
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_scan_local_library),
            content: Text(
              context.t.strings.legacy.msg_scan_disk_directory_merge_local_database,
            ),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_scan),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final scanner = ref.read(localLibraryScannerProvider);
    if (scanner == null) return;
    try {
      await scanner.scanAndMerge(context);
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_scan_completed,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_scan_failed(e: e)),
        ),
      );
    }
  }

  void _maybeAutoScanLocalLibrary({
    required bool memosLoading,
    required List<LocalMemo>? memosValue,
    required bool useRemoteSearch,
    required bool useShortcutFilter,
    required String searchQuery,
    required String? resolvedTag,
    required DateTime? filterDay,
  }) {
    if (_autoScanTriggered || _autoScanInFlight) return;
    if (memosLoading) return;
    if (useRemoteSearch || useShortcutFilter) return;
    if (widget.state != 'NORMAL') return;
    if (searchQuery.trim().isNotEmpty) return;
    if (resolvedTag != null && resolvedTag.trim().isNotEmpty) return;
    if (filterDay != null) return;
    if (memosValue != null && memosValue.isNotEmpty) return;

    final scanner = ref.read(localLibraryScannerProvider);
    if (scanner == null) return;
    _autoScanTriggered = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _autoScanInFlight = true;
      try {
        final db = ref.read(databaseProvider);
        final existing = await db.listMemos(limit: 1);
        if (!mounted) return;
        if (existing.isNotEmpty) return;

        final diskMemos = await scanner.fileSystem.listMemos();
        if (!mounted || diskMemos.isEmpty) return;

        await scanner.scanAndMerge(context, forceDisk: true);
        if (!mounted) return;
        showTopToast(
          context,
          context.t.strings.legacy.msg_imported_memos_local_library,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.strings.legacy.msg_local_library_import_failed(e: e),
            ),
          ),
        );
      } finally {
        _autoScanInFlight = false;
      }
    });
  }

  Future<void> _createShortcutFromMenu() async {
    final result = await Navigator.of(context).push<ShortcutEditorResult>(
      MaterialPageRoute<ShortcutEditorResult>(
        builder: (_) => const ShortcutEditorScreen(),
      ),
    );
    if (result == null) return;

    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_not_authenticated),
        ),
      );
      return;
    }
    try {
      final created = await ref
          .read(memosApiProvider)
          .createShortcut(
            userName: account.user.name,
            title: result.title,
            filter: result.filter,
          );
      ref.invalidate(shortcutsProvider);
      if (!mounted) return;
      setState(() => _selectedShortcutId = created.shortcutId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_create_failed_2(e: e)),
        ),
      );
    }
  }

  Future<void> _openTitleMenu() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final showShortcuts = _isAllMemos && session?.currentAccount != null;
    if (!showShortcuts && accounts.length < 2) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || titleBox == null) return;

    final position = titleBox.localToGlobal(Offset.zero, ancestor: overlay);
    final maxWidth = overlay.size.width - 24;
    final width = (maxWidth < 220 ? maxWidth : 240).toDouble();
    final left = position.dx.clamp(12.0, overlay.size.width - width - 12.0);
    final top = position.dy + titleBox.size.height + 6;
    final availableHeight = overlay.size.height - top - 16;
    final menuMaxHeight = availableHeight > 120
        ? availableHeight
        : overlay.size.height * 0.6;

    final action = await showGeneralDialog<_TitleMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'title_menu',
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, _) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: _TitleMenuDropdown(
              selectedShortcutId: _selectedShortcutId,
              showShortcuts: showShortcuts,
              showAccountSwitcher: accounts.length > 1,
              maxHeight: menuMaxHeight,
              formatShortcutError: _formatShortcutLoadError,
            ),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action.type) {
      case _TitleMenuActionType.selectShortcut:
        setState(() => _selectedShortcutId = action.shortcutId);
        break;
      case _TitleMenuActionType.clearShortcut:
        setState(() => _selectedShortcutId = null);
        break;
      case _TitleMenuActionType.createShortcut:
        await _createShortcutFromMenu();
        break;
      case _TitleMenuActionType.openAccountSwitcher:
        await _openAccountSwitcher();
        break;
    }
  }

  Future<void> _updateMemo(
    LocalMemo memo, {
    bool? pinned,
    String? state,
  }) async {
    final now = DateTime.now();
    final db = ref.read(databaseProvider);

    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: pinned ?? memo.pinned,
      state: state ?? memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
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
        if (pinned != null) 'pinned': pinned,
        if (state != null) 'state': state,
      },
    );
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  Future<void> _updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
    bool triggerSync = true,
  }) async {
    if (content == memo.content) return;
    final updateTime = preserveUpdateTime ? memo.updateTime : DateTime.now();
    final db = ref.read(databaseProvider);
    final tags = extractTags(content);

    await db.upsertMemo(
      uid: memo.uid,
      content: content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
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
        'content': content,
        'visibility': memo.visibility,
      },
    );
    if (triggerSync) {
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    }
  }

  Future<void> _toggleMemoCheckbox(
    LocalMemo memo,
    int checkboxIndex, {
    required bool skipQuotedLines,
  }) async {
    final updated = toggleCheckbox(
      memo.content,
      checkboxIndex,
      skipQuotedLines: skipQuotedLines,
    );
    if (updated == memo.content) return;
    _invalidateMemoRenderCacheForUid(memo.uid);
    invalidateMemoMarkdownCacheForUid(memo.uid);
    await _updateMemoContent(
      memo,
      updated,
      preserveUpdateTime: true,
      triggerSync: false,
    );
  }

  Future<void> _deleteMemo(LocalMemo memo) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_delete_memo),
            content: Text(
              context.t.strings.legacy.msg_removed_locally_now_deleted_server_when,
            ),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    _removeMemoWithAnimation(memo);
    final db = ref.read(databaseProvider);
    await db.deleteMemoByUid(memo.uid);
    await db.enqueueOutbox(
      type: 'delete_memo',
      payload: {'uid': memo.uid, 'force': false},
    );
    await ref.read(reminderSchedulerProvider).rescheduleAll();
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  Future<void> _restoreMemo(LocalMemo memo) async {
    try {
      await _updateMemo(memo, state: 'NORMAL');
      if (!mounted) return;
      final message = context.t.strings.legacy.msg_restored;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MemosListScreen(
            title: 'MemoFlow',
            state: 'NORMAL',
            showDrawer: true,
            enableCompose: true,
            toastMessage: message,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_restore_failed(e: e),
          ),
        ),
      );
    }
  }

  Future<void> _archiveMemo(LocalMemo memo) async {
    try {
      await _updateMemo(memo, state: 'ARCHIVED');
      _removeMemoWithAnimation(memo);
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_archived,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_archive_failed(e: e),
          ),
        ),
      );
    }
  }

  Future<void> _handleMemoAction(LocalMemo memo, _MemoCardAction action) async {
    switch (action) {
      case _MemoCardAction.togglePinned:
        await _updateMemo(memo, pinned: !memo.pinned);
        return;
      case _MemoCardAction.edit:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoEditorScreen(existing: memo),
          ),
        );
        ref.invalidate(memoRelationsProvider(memo.uid));
        return;
      case _MemoCardAction.reminder:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoReminderEditorScreen(memo: memo),
          ),
        );
        return;
      case _MemoCardAction.archive:
        await _archiveMemo(memo);
        return;
      case _MemoCardAction.restore:
        await _restoreMemo(memo);
        return;
      case _MemoCardAction.delete:
        await _deleteMemo(memo);
        return;
    }
  }

  void _removeMemoWithAnimation(LocalMemo memo) {
    final index = _animatedMemos.indexWhere((m) => m.uid == memo.uid);
    if (index < 0) return;
    final removed = _animatedMemos.removeAt(index);
    _pendingRemovedUids.add(removed.uid);
    final outboxStatus =
        ref.read(_outboxMemoStatusProvider).valueOrNull ??
        const _OutboxMemoStatus.empty();

    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildAnimatedMemoItem(
        context: context,
        memo: removed,
        animation: animation,
        prefs: ref.read(appPreferencesProvider),
        outboxStatus: outboxStatus,
        removing: true,
      ),
      duration: const Duration(milliseconds: 380),
    );
    setState(() {});
  }

  void _syncAnimatedMemos(List<LocalMemo> memos, String signature) {
    if (_pendingRemovedUids.isNotEmpty) {
      final memoIds = memos.map((m) => m.uid).toSet();
      _pendingRemovedUids.removeWhere((uid) => !memoIds.contains(uid));
    }
    final filtered = memos
        .where((m) => !_pendingRemovedUids.contains(m.uid))
        .toList(growable: true);
    if (_listSignature != signature ||
        !_sameMemoList(_animatedMemos, filtered)) {
      _listSignature = signature;
      _animatedMemos = filtered;
      _listKey = GlobalKey<SliverAnimatedListState>();
      return;
    }

    var changed = false;
    final next = List<LocalMemo>.from(_animatedMemos);
    for (var i = 0; i < filtered.length; i++) {
      if (!_sameMemoData(_animatedMemos[i], filtered[i])) {
        next[i] = filtered[i];
        changed = true;
      }
    }
    if (changed) {
      _animatedMemos = next;
    }
  }

  static bool _sameMemoList(List<LocalMemo> a, List<LocalMemo> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].uid != b[i].uid) return false;
    }
    return true;
  }

  static bool _sameMemoData(LocalMemo a, LocalMemo b) {
    if (identical(a, b)) return true;
    if (a.uid != b.uid) return false;
    if (a.content != b.content) return false;
    if (a.visibility != b.visibility) return false;
    if (a.pinned != b.pinned) return false;
    if (a.state != b.state) return false;
    if (a.createTime != b.createTime) return false;
    if (a.updateTime != b.updateTime) return false;
    if (a.syncState != b.syncState) return false;
    if (a.lastError != b.lastError) return false;
    if (!listEquals(a.tags, b.tags)) return false;
    if (!_sameAttachments(a.attachments, b.attachments)) return false;
    return true;
  }

  static bool _sameAttachments(List<Attachment> a, List<Attachment> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.name != right.name) return false;
      if (left.filename != right.filename) return false;
      if (left.type != right.type) return false;
      if (left.size != right.size) return false;
      if (left.externalLink != right.externalLink) return false;
    }
    return true;
  }

  Widget _buildAnimatedMemoItem({
    required BuildContext context,
    required LocalMemo memo,
    required Animation<double> animation,
    required AppPreferences prefs,
    required _OutboxMemoStatus outboxStatus,
    required bool removing,
  }) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return SizeTransition(
      sizeFactor: curved,
      axis: Axis.vertical,
      axisAlignment: 0.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildMemoCard(
          context,
          memo,
          prefs: prefs,
          outboxStatus: outboxStatus,
          removing: removing,
        ),
      ),
    );
  }

  Widget _buildMemoCard(
    BuildContext context,
    LocalMemo memo, {
    required AppPreferences prefs,
    required _OutboxMemoStatus outboxStatus,
    required bool removing,
  }) {
    final displayTime = memo.createTime.millisecondsSinceEpoch > 0
        ? memo.createTime
        : memo.updateTime;
    final isAudioActive = _playingMemoUid == memo.uid;
    final isAudioPlaying = isAudioActive && _audioPlayer.playing;
    final isAudioLoading = isAudioActive && _audioLoading;
    final audioPositionListenable = isAudioActive
        ? _audioPositionNotifier
        : null;
    final audioDurationListenable = isAudioActive
        ? _audioDurationNotifier
        : null;
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final imageEntries = collectMemoImageEntries(
      content: memo.content,
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
    );
    final videoEntries = collectMemoVideoEntries(
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
    );
    final mediaEntries = buildMemoMediaEntries(
      images: imageEntries,
      videos: videoEntries,
    );
    final hapticsEnabled = prefs.hapticsEnabled;

    void maybeHaptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final syncStatus = _resolveMemoSyncStatus(memo, outboxStatus);
    final reminderMap = ref.watch(memoReminderMapProvider);
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final reminder = reminderMap[memo.uid];
    final nextReminderTime = reminder == null
        ? null
        : nextEffectiveReminderTime(
            now: DateTime.now(),
            times: reminder.times,
            settings: reminderSettings,
          );
    final reminderText = nextReminderTime == null
        ? null
        : _formatReminderTime(nextReminderTime);

    return _MemoCard(
      key: ValueKey(memo.uid),
      memo: memo,
      dateText: _dateFmt.format(displayTime),
      reminderText: reminderText,
      collapseLongContent: prefs.collapseLongContent,
      collapseReferences: prefs.collapseReferences,
      isAudioPlaying: removing ? false : isAudioPlaying,
      isAudioLoading: removing ? false : isAudioLoading,
      audioPositionListenable: removing ? null : audioPositionListenable,
      audioDurationListenable: removing ? null : audioDurationListenable,
      imageEntries: imageEntries,
      mediaEntries: mediaEntries,
      onAudioSeek: removing || !isAudioActive
          ? null
          : (pos) => _seekAudioPosition(memo, pos),
      onAudioTap: removing ? null : () => _toggleAudioPlayback(memo),
      syncStatus: syncStatus,
      onSyncStatusTap: syncStatus == _MemoSyncStatus.none
          ? null
          : _openSyncQueue,
      onToggleTask: removing
          ? (_) {}
          : (index) {
              unawaited(
                _toggleMemoCheckbox(
                  memo,
                  index,
                  skipQuotedLines: prefs.collapseReferences,
                ),
              );
            },
      onTap: removing
          ? () {}
          : () {
              maybeHaptic();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MemoDetailScreen(initialMemo: memo),
                ),
              );
            },
      onDoubleTap: removing || memo.state == 'ARCHIVED'
          ? () {}
          : () {
              maybeHaptic();
              unawaited(_handleMemoAction(memo, _MemoCardAction.edit));
            },
      onLongPress: removing
          ? () {}
          : () async {
              maybeHaptic();
              await Clipboard.setData(ClipboardData(text: memo.content));
              if (!context.mounted) return;
              showTopToast(
                context,
                context.t.strings.legacy.msg_memo_copied,
                duration: const Duration(milliseconds: 1200),
              );
            },
      onAction: removing
          ? (_) {}
          : (action) async => _handleMemoAction(memo, action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text;
    final filterDay = widget.dayFilter;
    final dayRange = filterDay == null ? null : _dayRangeSeconds(filterDay);
    final startTimeSec = dayRange?.startSec;
    final endTimeSecExclusive = dayRange?.endSecExclusive;
    final shortcutsAsync = ref.watch(shortcutsProvider);
    final shortcuts = shortcutsAsync.valueOrNull ?? const <Shortcut>[];
    final selectedShortcut = _findShortcutById(shortcuts);
    final shortcutFilter = selectedShortcut?.filter ?? '';
    final useShortcutFilter = shortcutFilter.trim().isNotEmpty;
    final resolvedTag = _activeTagFilter;
    final useRemoteSearch = !useShortcutFilter && searchQuery.trim().isNotEmpty;
    final queryKey =
        '${widget.state}|${resolvedTag ?? ''}|${searchQuery.trim()}|${shortcutFilter.trim()}|'
        '${startTimeSec ?? ''}|${endTimeSecExclusive ?? ''}|${useShortcutFilter ? 1 : 0}|'
        '${useRemoteSearch ? 1 : 0}';
    if (_paginationKey != queryKey) {
      _paginationKey = queryKey;
      _pageSize = _initialPageSize;
      _reachedEnd = false;
      _loadingMore = false;
      _lastResultCount = 0;
    }
    final shortcutQuery = (
      searchQuery: searchQuery,
      state: widget.state,
      tag: resolvedTag,
      shortcutFilter: shortcutFilter,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      pageSize: _pageSize,
    );
    final memosAsync = useShortcutFilter
        ? ref.watch(shortcutMemosProvider(shortcutQuery))
        : useRemoteSearch
        ? ref.watch(
            remoteSearchMemosProvider((
              searchQuery: searchQuery,
              state: widget.state,
              tag: resolvedTag,
              startTimeSec: startTimeSec,
              endTimeSecExclusive: endTimeSecExclusive,
              pageSize: _pageSize,
            )),
          )
        : ref.watch(
            memosStreamProvider((
              searchQuery: searchQuery,
              state: widget.state,
              tag: resolvedTag,
              startTimeSec: startTimeSec,
              endTimeSecExclusive: endTimeSecExclusive,
              pageSize: _pageSize,
            )),
          );
    final outboxStatus =
        ref.watch(_outboxMemoStatusProvider).valueOrNull ??
        const _OutboxMemoStatus.empty();
    final searchHistory = ref.watch(searchHistoryProvider);
    final tagStats =
        ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final recommendedTags = [...tagStats]
      ..sort((a, b) => b.count.compareTo(a.count));
    final showSearchLanding = _searching && searchQuery.trim().isEmpty;
    final memosValue = memosAsync.valueOrNull;
    final memosLoading = memosAsync.isLoading;
    final memosError = memosAsync.whenOrNull(error: (e, _) => e);
    final enableHomeSort = _shouldEnableHomeSort(
      useRemoteSearch: useRemoteSearch,
    );

    _currentResultCount = memosValue?.length ?? 0;
    _currentLoading = memosLoading;
    _currentShowSearchLanding = showSearchLanding;
    if (_currentResultCount != _lastResultCount) {
      _lastResultCount = _currentResultCount;
      _loadingMore = false;
    }
    _reachedEnd = _currentResultCount < _pageSize;
    if (!_currentLoading &&
        !_currentShowSearchLanding &&
        !_reachedEnd &&
        !_loadingMore &&
        _currentResultCount >= _pageSize &&
        _currentResultCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeAutoLoadMore();
      });
    }

    _maybeAutoScanLocalLibrary(
      memosLoading: memosLoading,
      memosValue: memosValue,
      useRemoteSearch: useRemoteSearch,
      useShortcutFilter: useShortcutFilter,
      searchQuery: searchQuery,
      resolvedTag: resolvedTag,
      filterDay: filterDay,
    );

    if (memosValue != null) {
      final sortedMemos = enableHomeSort
          ? _applyHomeSort(memosValue)
          : memosValue;
      final listSignature =
          '${widget.state}|${resolvedTag ?? ''}|${searchQuery.trim()}|${shortcutFilter.trim()}|'
          '${useShortcutFilter ? 1 : 0}|${startTimeSec ?? ''}|${endTimeSecExclusive ?? ''}|'
          '${enableHomeSort ? _sortOption.name : 'default'}';
      _syncAnimatedMemos(sortedMemos, listSignature);
    }
    final visibleMemos = _animatedMemos;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg =
        (isDark
                ? MemoFlowPalette.backgroundDark
                : MemoFlowPalette.backgroundLight)
            .withValues(alpha: 0.9);
    final listTopPadding = widget.showPillActions ? 0.0 : 16.0;
    final listVisualOffset = widget.showPillActions ? 6.0 : 0.0;
    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;
    final backToTopBaseOffset = widget.enableCompose && !_searching
        ? 104.0
        : 24.0;
    void maybeHaptic() {
      if (!hapticsEnabled) return;
      HapticFeedback.selectionClick();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (!context.mounted) return;
        if (!shouldPop) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: widget.showDrawer
            ? AppDrawer(
                selected: widget.state == 'ARCHIVED'
                    ? AppDrawerDestination.archived
                    : AppDrawerDestination.memos,
                onSelect: _navigateDrawer,
                onSelectTag: _openTagFromDrawer,
                onOpenNotifications: _openNotifications,
              )
            : null,
        drawerEnableOpenDragGesture: widget.showDrawer && !_searching,
        drawerEdgeDragWidth:
            widget.showDrawer && !_searching ? screenWidth : null,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await ref.read(syncControllerProvider.notifier).syncNow();
                if (useShortcutFilter) {
                  ref.invalidate(shortcutMemosProvider(shortcutQuery));
                }
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: headerBg,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: !_searching,
                    leading: _searching
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new),
                            onPressed: _closeSearch,
                          )
                        : null,
                    title: _searching
                        ? Container(
                            key: const ValueKey('search'),
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? MemoFlowPalette.cardDark
                                  : MemoFlowPalette.cardLight,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? MemoFlowPalette.borderDark.withValues(
                                        alpha: 0.7,
                                      )
                                    : MemoFlowPalette.borderLight,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: context.t.strings.legacy.msg_search,
                                border: InputBorder.none,
                                isDense: true,
                                prefixIcon: const Icon(Icons.search, size: 18),
                              ),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: _submitSearch,
                            ),
                          )
                        : (widget.enableTitleMenu
                              ? InkWell(
                                  key: _titleKey,
                                  onTap: () {
                                    maybeHaptic();
                                    _openTitleMenu();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.expand_more,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                )),
                    actions: _searching
                        ? (widget.enableSearch
                              ? [
                                  TextButton(
                                    onPressed: _closeSearch,
                                    child: Text(
                                      context.t.strings.legacy.msg_cancel_2,
                                      style: TextStyle(
                                        color: MemoFlowPalette.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ]
                              : null)
                        : (widget.enableSearch
                              ? [
                                  if (enableHomeSort)
                                    _buildSortMenuButton(
                                      context,
                                      isDark: isDark,
                                    ),
                                  IconButton(
                                    tooltip: context.t.strings.legacy.msg_search,
                                    onPressed: _openSearch,
                                    icon: const Icon(Icons.search),
                                  ),
                                ]
                              : null),
                    bottom: _searching
                        ? null
                        : (widget.showPillActions
                              ? PreferredSize(
                                  preferredSize: const Size.fromHeight(46),
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        0,
                                      ),
                                      child: _PillRow(
                                        onWeeklyInsights: () {
                                          maybeHaptic();
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const StatsScreen(),
                                            ),
                                          );
                                        },
                                        onAiSummary: () {
                                          maybeHaptic();
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const AiSummaryScreen(),
                                            ),
                                          );
                                        },
                                        onDailyReview: () {
                                          maybeHaptic();
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const DailyReviewScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                )
                              : (widget.showFilterTagChip &&
                                        (resolvedTag?.trim().isNotEmpty ??
                                            false)
                                    ? PreferredSize(
                                        preferredSize: const Size.fromHeight(
                                          48,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            10,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: _FilterTagChip(
                                              label: '#${resolvedTag!.trim()}',
                                              onClear: widget.showTagFilters
                                                  ? () => _selectTagFilter(null)
                                                  : (widget.showDrawer
                                                        ? _backToAllMemos
                                                        : () => context
                                                              .safePop()),
                                            ),
                                          ),
                                        ),
                                      )
                                    : null)),
                  ),
                  if (widget.showTagFilters &&
                      !_searching &&
                      recommendedTags.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _TagFilterBar(
                        tags: recommendedTags
                            .take(12)
                            .map((e) => e.tag)
                            .toList(growable: false),
                        selectedTag: resolvedTag,
                        onSelectTag: _selectTagFilter,
                      ),
                    ),
                  if (memosLoading && memosValue != null)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                  if (memosError != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          context.t.strings.legacy.msg_failed_load_3(memosError: memosError),
                        ),
                      ),
                    )
                  else if (showSearchLanding)
                    SliverToBoxAdapter(
                      child: _SearchLanding(
                        history: searchHistory,
                        onClearHistory: () =>
                            ref.read(searchHistoryProvider.notifier).clear(),
                        onRemoveHistory: (value) => ref
                            .read(searchHistoryProvider.notifier)
                            .remove(value),
                        onSelectHistory: _applySearchQuery,
                        tags: recommendedTags
                            .map((e) => e.tag)
                            .toList(growable: false),
                        onSelectTag: _applySearchQuery,
                      ),
                    )
                  else if (memosValue == null && memosLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visibleMemos.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 140),
                        child: Center(
                          child: Text(
                            _searching
                                ? context.t.strings.legacy.msg_no_results_found
                                : context.t.strings.legacy.msg_no_content_yet,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        listTopPadding + listVisualOffset,
                        16,
                        140,
                      ),
                      sliver: SliverAnimatedList(
                        key: _listKey,
                        initialItemCount: visibleMemos.length,
                        itemBuilder: (context, index, animation) {
                          final memo = visibleMemos[index];
                          return _buildAnimatedMemoItem(
                            context: context,
                            memo: memo,
                            animation: animation,
                            prefs: prefs,
                            outboxStatus: outboxStatus,
                            removing: false,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: backToTopBaseOffset + bottomInset,
              child: _BackToTopButton(
                visible: _showBackToTop,
                hapticsEnabled: hapticsEnabled,
                onPressed: _scrollToTop,
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: widget.enableCompose && !_searching
            ? _MemoFlowFab(
                onPressed: _openNoteInput,
                hapticsEnabled: hapticsEnabled,
              )
            : null,
      ),
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.onWeeklyInsights,
    required this.onAiSummary,
    required this.onDailyReview,
  });

  final VoidCallback onWeeklyInsights;
  final VoidCallback onAiSummary;
  final VoidCallback onDailyReview;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final bgColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillButton(
                    icon: Icons.insights,
                    iconColor: MemoFlowPalette.primary,
                    label: context.t.strings.legacy.msg_monthly_stats,
                    onPressed: onWeeklyInsights,
                    backgroundColor: bgColor,
                    borderColor: borderColor,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 10),
                  _PillButton(
                    icon: Icons.auto_awesome,
                    iconColor: isDark
                        ? MemoFlowPalette.aiChipBlueDark
                        : MemoFlowPalette.aiChipBlueLight,
                    label: context.t.strings.legacy.msg_ai_summary,
                    onPressed: onAiSummary,
                    backgroundColor: bgColor,
                    borderColor: borderColor,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 10),
                  _PillButton(
                    icon: Icons.explore,
                    iconColor: isDark
                        ? MemoFlowPalette.reviewChipOrangeDark
                        : MemoFlowPalette.reviewChipOrangeLight,
                    label: context.t.strings.legacy.msg_random_review,
                    onPressed: onDailyReview,
                    backgroundColor: bgColor,
                    borderColor: borderColor,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _TitleMenuActionType {
  selectShortcut,
  clearShortcut,
  createShortcut,
  openAccountSwitcher,
}

class _TitleMenuAction {
  const _TitleMenuAction._(this.type, {this.shortcutId});

  const _TitleMenuAction.selectShortcut(String id)
    : this._(_TitleMenuActionType.selectShortcut, shortcutId: id);
  const _TitleMenuAction.clearShortcut()
    : this._(_TitleMenuActionType.clearShortcut);
  const _TitleMenuAction.createShortcut()
    : this._(_TitleMenuActionType.createShortcut);
  const _TitleMenuAction.openAccountSwitcher()
    : this._(_TitleMenuActionType.openAccountSwitcher);

  final _TitleMenuActionType type;
  final String? shortcutId;
}

class _TitleMenuDropdown extends ConsumerWidget {
  const _TitleMenuDropdown({
    required this.selectedShortcutId,
    required this.showShortcuts,
    required this.showAccountSwitcher,
    required this.maxHeight,
    required this.formatShortcutError,
  });

  final String? selectedShortcutId;
  final bool showShortcuts;
  final bool showAccountSwitcher;
  final double maxHeight;
  final String Function(BuildContext, Object) formatShortcutError;

  static const _shortcutIcons = [
    Icons.folder_outlined,
    Icons.lightbulb_outline,
    Icons.edit_note,
    Icons.bookmark_border,
    Icons.label_outline,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final dividerColor = border.withValues(alpha: 0.6);

    final shortcutsAsync = showShortcuts ? ref.watch(shortcutsProvider) : null;
    final items = <Widget>[];

    void addRow(Widget row) {
      if (items.isNotEmpty) {
        items.add(Divider(height: 1, color: dividerColor));
      }
      items.add(row);
    }

    if (showShortcuts && shortcutsAsync != null) {
      shortcutsAsync.when(
        data: (shortcuts) {
          final hasSelection =
              selectedShortcutId != null &&
              selectedShortcutId!.isNotEmpty &&
              shortcuts.any(
                (shortcut) => shortcut.shortcutId == selectedShortcutId,
              );
          addRow(
            _TitleMenuItem(
              icon: Icons.note_outlined,
              label: context.t.strings.legacy.msg_all_memos_2,
              selected: !hasSelection,
              onTap: () => Navigator.of(
                context,
              ).pop(const _TitleMenuAction.clearShortcut()),
            ),
          );

          if (shortcuts.isEmpty) {
            addRow(
              _TitleMenuItem(
                icon: Icons.info_outline,
                label: context.t.strings.legacy.msg_no_shortcuts,
                enabled: false,
                textColor: textMuted,
                iconColor: textMuted,
              ),
            );
          } else {
            for (var i = 0; i < shortcuts.length; i++) {
              final shortcut = shortcuts[i];
              final label = shortcut.title.trim().isNotEmpty
                  ? shortcut.title.trim()
                  : context.t.strings.legacy.msg_untitled;
              addRow(
                _TitleMenuItem(
                  icon: _shortcutIcons[i % _shortcutIcons.length],
                  label: label,
                  selected: shortcut.shortcutId == selectedShortcutId,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_TitleMenuAction.selectShortcut(shortcut.shortcutId)),
                ),
              );
            }
          }

          addRow(
            _TitleMenuItem(
              icon: Icons.add_circle_outline,
              label: context.t.strings.legacy.msg_shortcut,
              accent: true,
              onTap: () => Navigator.of(
                context,
              ).pop(const _TitleMenuAction.createShortcut()),
            ),
          );
        },
        loading: () {
          addRow(
            _TitleMenuItem(
              icon: Icons.note_outlined,
              label: context.t.strings.legacy.msg_all_memos_2,
              selected:
                  selectedShortcutId == null || selectedShortcutId!.isEmpty,
              onTap: () => Navigator.of(
                context,
              ).pop(const _TitleMenuAction.clearShortcut()),
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.hourglass_bottom,
              label: context.t.strings.legacy.msg_loading,
              enabled: false,
              textColor: textMuted,
              iconColor: textMuted,
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.add_circle_outline,
              label: context.t.strings.legacy.msg_shortcut,
              accent: true,
              onTap: () => Navigator.of(
                context,
              ).pop(const _TitleMenuAction.createShortcut()),
            ),
          );
        },
        error: (error, _) {
          addRow(
            _TitleMenuItem(
              icon: Icons.note_outlined,
              label: context.t.strings.legacy.msg_all_memos_2,
              selected:
                  selectedShortcutId == null || selectedShortcutId!.isEmpty,
              onTap: () => Navigator.of(
                context,
              ).pop(const _TitleMenuAction.clearShortcut()),
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.info_outline,
              label: formatShortcutError(context, error),
              enabled: false,
              textColor: textMuted,
              iconColor: textMuted,
            ),
          );
          addRow(
            _TitleMenuItem(
              icon: Icons.add_circle_outline,
              label: context.t.strings.legacy.msg_shortcut,
              accent: true,
              onTap: () => Navigator.of(
                context,
              ).pop(const _TitleMenuAction.createShortcut()),
            ),
          );
        },
      );
    }

    if (showAccountSwitcher) {
      addRow(
        _TitleMenuItem(
          icon: Icons.swap_horiz,
          label: context.t.strings.legacy.msg_switch_account,
          onTap: () => Navigator.of(
            context,
          ).pop(const _TitleMenuAction.openAccountSwitcher()),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(child: Column(children: items)),
          ),
        ),
      ),
    );
  }
}

class _TitleMenuItem extends StatelessWidget {
  const _TitleMenuItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.accent = false,
    this.enabled = true,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool accent;
  final bool enabled;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final baseMuted = textMain.withValues(alpha: 0.6);
    final accentColor = MemoFlowPalette.primary;
    final labelColor =
        textColor ??
        (accent
            ? accentColor
            : selected
            ? textMain
            : baseMuted);
    final resolvedIconColor =
        iconColor ??
        (accent
            ? accentColor
            : selected
            ? accentColor
            : baseMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: resolvedIconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check, size: 16, color: accentColor)
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchLanding extends StatefulWidget {
  const _SearchLanding({
    required this.history,
    required this.onClearHistory,
    required this.onRemoveHistory,
    required this.onSelectHistory,
    required this.tags,
    required this.onSelectTag,
  });

  final List<String> history;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onRemoveHistory;
  final ValueChanged<String> onSelectHistory;
  final List<String> tags;
  final ValueChanged<String> onSelectTag;

  @override
  State<_SearchLanding> createState() => _SearchLandingState();
}

class _SearchLandingState extends State<_SearchLanding> {
  static const _collapsedTagCount = 6;
  bool _showAllTags = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final chipBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final accent = MemoFlowPalette.primary;
    final tags = widget.tags;
    final hasMoreTags = tags.length > _collapsedTagCount;
    final visibleTags = _showAllTags || !hasMoreTags
        ? tags
        : tags.take(_collapsedTagCount).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.t.strings.legacy.msg_recent_searches,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (widget.history.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClearHistory,
                  icon: Icon(Icons.delete_outline, size: 18, color: textMuted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.t.strings.legacy.msg_no_search_history,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            )
          else
            Column(
              children: [
                for (final item in widget.history)
                  InkWell(
                    onTap: () => widget.onSelectHistory(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 18, color: textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(fontSize: 14, color: textMain),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => widget.onRemoveHistory(item),
                            icon: Icon(Icons.close, size: 18, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                context.t.strings.legacy.msg_suggested_tags,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const Spacer(),
              if (hasMoreTags)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllTags = !_showAllTags),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _showAllTags ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: textMuted,
                  ),
                  label: Text(
                    _showAllTags
                        ? context.t.strings.legacy.msg_collapse
                        : context.t.strings.legacy.msg_show_all,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (tags.isEmpty)
            Text(
              context.t.strings.legacy.msg_no_tags,
              style: TextStyle(fontSize: 12, color: textMuted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tag in visibleTags)
                  InkWell(
                    onTap: () => widget.onSelectTag('#${tag.trim()}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                  color: Colors.black.withValues(alpha: 0.06),
                                ),
                              ],
                      ),
                      child: Text(
                        '#${tag.trim()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              context.t.strings.legacy.msg_search_title_content_tags,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilterBar extends StatelessWidget {
  const _TagFilterBar({
    required this.tags,
    required this.selectedTag,
    required this.onSelectTag,
  });

  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onSelectTag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final accent = MemoFlowPalette.primary;
    final chipBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final selectedBg = accent.withValues(alpha: isDark ? 0.22 : 0.14);
    final selectedBorder = accent.withValues(alpha: isDark ? 0.55 : 0.6);
    final normalizedSelected = (selectedTag ?? '').trim();

    Widget buildChip(
      String label, {
      required bool selected,
      required VoidCallback onTap,
    }) {
      final bg = selected ? selectedBg : chipBg;
      final chipBorder = selected ? selectedBorder : border;
      final textColor = selected ? accent : textMuted;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: chipBorder),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.strings.legacy.msg_filter_tags,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textMain,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              buildChip(
                context.t.strings.legacy.msg_all_2,
                selected: normalizedSelected.isEmpty,
                onTap: () => onSelectTag(null),
              ),
              for (final tag in tags)
                buildChip(
                  '#${tag.trim()}',
                  selected: normalizedSelected == tag.trim(),
                  onTap: () => onSelectTag(tag),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterTagChip extends StatelessWidget {
  const _FilterTagChip({required this.label, this.onClear});

  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MemoFlowPalette.primary;
    final bg = accent.withValues(alpha: isDark ? 0.22 : 0.14);
    final border = accent.withValues(alpha: isDark ? 0.55 : 0.6);
    final textColor = accent;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.close, size: 14, color: textColor),
          ],
        ],
      ),
    );

    if (onClear == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.05,
            ),
          ),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: iconColor),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

enum _MemoCardAction { togglePinned, edit, reminder, archive, restore, delete }

class _MemoCard extends StatefulWidget {
  const _MemoCard({
    super.key,
    required this.memo,
    required this.dateText,
    required this.reminderText,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.isAudioPlaying,
    required this.isAudioLoading,
    required this.audioPositionListenable,
    required this.audioDurationListenable,
    required this.imageEntries,
    required this.mediaEntries,
    required this.onAudioSeek,
    required this.onAudioTap,
    required this.syncStatus,
    this.onSyncStatusTap,
    required this.onToggleTask,
    required this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    required this.onAction,
  });

  final LocalMemo memo;
  final String dateText;
  final String? reminderText;
  final bool collapseLongContent;
  final bool collapseReferences;
  final bool isAudioPlaying;
  final bool isAudioLoading;
  final ValueListenable<Duration>? audioPositionListenable;
  final ValueListenable<Duration?>? audioDurationListenable;
  final List<MemoImageEntry> imageEntries;
  final List<MemoMediaEntry> mediaEntries;
  final ValueChanged<Duration>? onAudioSeek;
  final VoidCallback? onAudioTap;
  final _MemoSyncStatus syncStatus;
  final VoidCallback? onSyncStatusTap;
  final ValueChanged<int> onToggleTask;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final ValueChanged<_MemoCardAction> onAction;

  @override
  State<_MemoCard> createState() => _MemoCardState();
}

class _MemoCardState extends State<_MemoCard> {
  var _expanded = false;

  static String _previewText(
    String content, {
    required bool collapseReferences,
    required AppLanguage language,
  }) {
    final trimmed = content.trim();
    if (!collapseReferences) return trimmed;

    final lines = trimmed.split('\n');
    final keep = <String>[];
    var quoteLines = 0;
    for (final line in lines) {
      if (line.trimLeft().startsWith('>')) {
        quoteLines++;
        continue;
      }
      keep.add(line);
    }

    final main = keep.join('\n').trim();
    if (quoteLines == 0) return main;
    if (main.isEmpty) {
      final cleaned = lines
          .map((l) => l.replaceFirst(RegExp(r'^\\s*>\\s?'), ''))
          .join('\n')
          .trim();
      return cleaned.isEmpty ? trimmed : cleaned;
    }
    return '$main\n\n${trByLanguageKey(language: language, key: 'legacy.msg_quoted_lines', params: {'quoteLines': quoteLines})}';
  }

  @override
  void didUpdateWidget(covariant _MemoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memo.uid != widget.memo.uid) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.memo;
    final dateText = widget.dateText;
    final reminderText = widget.reminderText;
    final collapseLongContent = widget.collapseLongContent;
    final collapseReferences = widget.collapseReferences;
    final onToggleTask = widget.onToggleTask;
    final onTap = widget.onTap;
    final onAction = widget.onAction;
    final onAudioTap = widget.onAudioTap;
    final audioPlaying = widget.isAudioPlaying;
    final audioLoading = widget.isAudioLoading;
    final audioPositionListenable = widget.audioPositionListenable;
    final audioDurationListenable = widget.audioDurationListenable;
    final onAudioSeek = widget.onAudioSeek;
    final mediaEntries = widget.mediaEntries;
    final syncStatus = widget.syncStatus;
    final onSyncStatusTap = widget.onSyncStatusTap;
    final onDoubleTap = widget.onDoubleTap;
    final onLongPress = widget.onLongPress;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final isPinned = memo.pinned;
    final pinColor = MemoFlowPalette.primary;
    final pinBorderColor = pinColor.withValues(alpha: isDark ? 0.5 : 0.4);
    final pinTint = pinColor.withValues(alpha: isDark ? 0.18 : 0.08);
    final cardSurface = isPinned
        ? Color.alphaBlend(pinTint, cardColor)
        : cardColor;
    final cardBorderColor = isPinned ? pinBorderColor : borderColor;
    final menuColor = isDark
        ? const Color(0xFF2B2523)
        : const Color(0xFFF6E7E3);
    final deleteColor = isDark
        ? const Color(0xFFFF7A7A)
        : const Color(0xFFE05656);
    final isArchived = widget.memo.state == 'ARCHIVED';
    final pendingColor = textMain.withValues(alpha: isDark ? 0.45 : 0.35);
    final attachmentColor = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final showSyncStatus = syncStatus != _MemoSyncStatus.none;
    final headerMinHeight = 32.0;
    final syncIcon = syncStatus == _MemoSyncStatus.failed
        ? Icons.error_outline
        : Icons.cloud_upload_outlined;
    final syncColor = syncStatus == _MemoSyncStatus.failed
        ? deleteColor
        : pendingColor;
    final pinnedChip = isPinned
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pinColor.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: pinBorderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin, size: 12, color: pinColor),
                const SizedBox(width: 4),
                Text(
                  context.t.strings.legacy.msg_pinned,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: pinColor,
                  ),
                ),
              ],
            ),
          )
        : null;

    final audio = memo.attachments
        .where((a) => a.type.startsWith('audio'))
        .toList(growable: false);
    final hasAudio = audio.isNotEmpty;
    final nonMediaAttachments = filterNonMediaAttachments(memo.attachments);
    final attachmentLines = attachmentNameLines(nonMediaAttachments);
    final attachmentCount = nonMediaAttachments.length;
    final language = context.appLanguage;
    final cacheKey = _memoRenderCacheKey(
      memo,
      collapseLongContent: collapseLongContent,
      collapseReferences: collapseReferences,
      language: language,
    );
    final cached = _memoRenderCache.get(cacheKey);
    final previewText =
        cached?.previewText ??
        _previewText(
          memo.content,
          collapseReferences: false,
          language: language,
        );
    final preview =
        cached?.preview ??
        _truncatePreview(previewText, collapseLongContent: collapseLongContent);
    final taskStats =
        cached?.taskStats ??
        countTaskStats(memo.content, skipQuotedLines: collapseReferences);
    if (cached == null) {
      _memoRenderCache.set(
        cacheKey,
        _MemoRenderCacheEntry(
          previewText: previewText,
          preview: preview,
          taskStats: taskStats,
        ),
      );
    }
    final showToggle = preview.truncated;
    final showCollapsed = showToggle && !_expanded;
    final displayText = previewText;
    final markdownCacheKey = '$cacheKey|md';
    final showProgress = !hasAudio && taskStats.total > 0;
    final progress = showProgress ? taskStats.checked / taskStats.total : 0.0;
    final audioDurationText = _parseVoiceDuration(memo.content) ?? '00:00';
    final audioDurationFallback = _parseVoiceDurationValue(memo.content);

    Widget buildMediaGrid() {
      if (mediaEntries.isEmpty) return const SizedBox.shrink();
      final previewBorder = borderColor.withValues(alpha: 0.65);
      final previewBg = isDark
          ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6)
          : MemoFlowPalette.audioSurfaceLight;
      final maxHeight = MediaQuery.of(context).size.height * 0.4;
      return MemoMediaGrid(
        entries: mediaEntries,
        columns: 3,
        maxCount: 9,
        maxHeight: maxHeight,
        radius: 0,
        spacing: 4,
        borderColor: previewBorder,
        backgroundColor: previewBg,
        textColor: textMain,
        enableDownload: true,
      );
    }

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
        onSeek: onAudioSeek,
        onTap: onAudioTap,
      );
    }

    Widget audioRow = buildAudioRow(Duration.zero, null);
    if (audioPositionListenable != null && audioDurationListenable != null) {
      audioRow = ValueListenableBuilder<Duration>(
        valueListenable: audioPositionListenable,
        builder: (context, position, _) {
          return ValueListenableBuilder<Duration?>(
            valueListenable: audioDurationListenable,
            builder: (context, duration, _) {
              return buildAudioRow(position, duration);
            },
          );
        },
      );
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showProgress) ...[
          _TaskProgressBar(
            progress: progress,
            isDark: isDark,
            total: taskStats.total,
            checked: taskStats.checked,
          ),
          const SizedBox(height: 2),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemoMarkdown(
              cacheKey: markdownCacheKey,
              data: displayText,
              maxLines: showCollapsed ? 6 : null,
              textStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textMain),
              blockSpacing: 4,
              normalizeHeadings: true,
              renderImages: false,
              onToggleTask: (request) => onToggleTask(request.taskIndex),
            ),
            if (showToggle) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _expanded
                        ? context.t.strings.legacy.msg_collapse
                        : context.t.strings.legacy.msg_expand,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MemoFlowPalette.primary,
                    ),
                  ),
                ),
              ),
            ],
            if (mediaEntries.isNotEmpty) ...[
              const SizedBox(height: 2),
              buildMediaGrid(),
            ],
            if (hasAudio) ...[const SizedBox(height: 2), audioRow],
            if (attachmentCount > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (context) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            showAttachmentNamesToast(context, attachmentLines),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 14,
                                color: attachmentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                attachmentCount.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: attachmentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        _MemoRelationsSection(
          memoUid: memo.uid,
          initialCount: memo.relationCount,
        ),
      ],
    );

    if (onDoubleTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: onDoubleTap,
        child: content,
      );
    }

    return Hero(
      tag: memo.uid,
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorderColor),
              boxShadow: [
                BoxShadow(
                  blurRadius: isDark ? 20 : 12,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.03),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: headerMinHeight,
                          child: Row(
                            children: [
                              if (pinnedChip != null) ...[
                                pinnedChip,
                                const SizedBox(width: 8),
                              ],
                              Text(
                                dateText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: textMain.withValues(
                                    alpha: isDark ? 0.4 : 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (memo.location != null) ...[
                          const SizedBox(height: 2),
                          MemoLocationLine(
                            location: memo.location!,
                            textColor: textMain.withValues(
                              alpha: isDark ? 0.4 : 0.5,
                            ),
                            onTap: () => openAmapLocation(context, memo.location!),
                          ),
                        ],
                      ],
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (reminderText != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_active_outlined,
                                      size: 14,
                                      color: MemoFlowPalette.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      reminderText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: MemoFlowPalette.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (showSyncStatus)
                              IconButton(
                                onPressed: onSyncStatusTap,
                                icon: Icon(
                                  syncIcon,
                                  size: 16,
                                  color: syncColor,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                splashRadius: 16,
                              ),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: PopupMenuButton<_MemoCardAction>(
                                  tooltip: context.t.strings.legacy.msg_more,
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.more_horiz,
                                    size: 20,
                                    color: textMain.withValues(
                                      alpha: isDark ? 0.4 : 0.5,
                                    ),
                                  ),
                                  onSelected: onAction,
                                  color: menuColor,
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  itemBuilder: (context) => isArchived
                                      ? [
                                          PopupMenuItem(
                                            value: _MemoCardAction.restore,
                                            child: Text(
                                              context.t.strings.legacy.msg_restore,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.delete,
                                            child: Text(
                                              context.t.strings.legacy.msg_delete,
                                              style: TextStyle(
                                                color: deleteColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ]
                                      : [
                                          PopupMenuItem(
                                            value: _MemoCardAction.togglePinned,
                                            child: Text(
                                              memo.pinned
                                                  ? context.t.strings.legacy.msg_unpin
                                                  : context.t.strings.legacy.msg_pin,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.edit,
                                            child: Text(
                                              context.t.strings.legacy.msg_edit,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.reminder,
                                            child: Text(
                                              context.t.strings.legacy.msg_reminder,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.archive,
                                            child: Text(
                                              context.t.strings.legacy.msg_archive,
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: _MemoCardAction.delete,
                                            child: Text(
                                              context.t.strings.legacy.msg_delete,
                                              style: TextStyle(
                                                color: deleteColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 0),
                content,
              ],
            ),
          ),
        ),
      ),
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
    final linePattern = RegExp(r'^[-*+•·]?\s*', unicode: true);
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

class _MemoRelationsSection extends ConsumerStatefulWidget {
  const _MemoRelationsSection({
    required this.memoUid,
    required this.initialCount,
  });

  final String memoUid;
  final int initialCount;

  @override
  ConsumerState<_MemoRelationsSection> createState() =>
      _MemoRelationsSectionState();
}

class _MemoRelationsSectionState extends ConsumerState<_MemoRelationsSection> {
  bool _expanded = false;
  int _cachedTotal = 0;

  @override
  void initState() {
    super.initState();
    _cachedTotal = widget.initialCount;
  }

  @override
  void didUpdateWidget(covariant _MemoRelationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCount != oldWidget.initialCount) {
      _cachedTotal = widget.initialCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded && _cachedTotal == 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final bg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);

    final summaryRow = _RelationSummaryRow(
      borderColor: borderColor,
      bg: bg,
      textMain: textMain,
      textMuted: textMuted,
      expanded: _expanded,
      countText: _cachedTotal.toString(),
      onTap: () => setState(() => _expanded = !_expanded),
      boxed: false,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            summaryRow,
            if (_expanded) const SizedBox(height: 2),
            if (_expanded) _buildExpanded(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, bool isDark) {
    final relationsAsync = ref.watch(memoRelationsProvider(widget.memoUid));
    return relationsAsync.when(
      data: (relations) {
        final currentName = 'memos/${widget.memoUid}';
        final referencing = <_RelationItem>[];
        final referencedBy = <_RelationItem>[];
        final seenReferencing = <String>{};
        final seenReferencedBy = <String>{};

        for (final relation in relations) {
          final type = relation.type.trim().toUpperCase();
          if (type != 'REFERENCE') {
            continue;
          }
          final memoName = relation.memo.name.trim();
          final relatedName = relation.relatedMemo.name.trim();

          if (memoName == currentName && relatedName.isNotEmpty) {
            if (seenReferencing.add(relatedName)) {
              referencing.add(
                _RelationItem(
                  name: relatedName,
                  snippet: relation.relatedMemo.snippet,
                ),
              );
            }
            continue;
          }
          if (relatedName == currentName && memoName.isNotEmpty) {
            if (seenReferencedBy.add(memoName)) {
              referencedBy.add(
                _RelationItem(name: memoName, snippet: relation.memo.snippet),
              );
            }
          }
        }

        final total = referencing.length + referencedBy.length;
        _maybeCacheTotal(total);

        if (total == 0) {
          return _buildEmptyState(context, isDark);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (referencing.isNotEmpty)
              _RelationGroup(
                title: context.t.strings.legacy.msg_references,
                items: referencing,
                isDark: isDark,
                showHeader: false,
                onTap: (item) => _openMemo(context, ref, item.name),
                boxed: false,
              ),
            if (referencing.isNotEmpty && referencedBy.isNotEmpty)
              const SizedBox(height: 2),
            if (referencedBy.isNotEmpty)
              _RelationGroup(
                title: context.t.strings.legacy.msg_referenced,
                items: referencedBy,
                isDark: isDark,
                showHeader: false,
                onTap: (item) => _openMemo(context, ref, item.name),
                boxed: false,
              ),
          ],
        );
      },
      loading: () => _buildLoading(context),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  void _maybeCacheTotal(int total) {
    if (_cachedTotal == total) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _cachedTotal = total);
    });
  }

  Widget _buildLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.link, size: 14, color: textMuted),
          const SizedBox(width: 6),
          Text(
            context.t.strings.legacy.msg_loading_links,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const Spacer(),
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.link_off, size: 14, color: textMuted),
          const SizedBox(width: 6),
          Text(
            context.t.strings.legacy.msg_no_links,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMemo(
    BuildContext context,
    WidgetRef ref,
    String rawName,
  ) async {
    final uid = _normalizeMemoUid(rawName);
    if (uid.isEmpty || uid == widget.memoUid) return;

    final db = ref.read(databaseProvider);
    final row = await db.getMemoByUid(uid);
    LocalMemo? memo = row == null ? null : LocalMemo.fromDb(row);

    if (memo == null) {
      final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account != null) {
        try {
          final api = ref.read(memosApiProvider);
          final remote = await api.getMemo(memoUid: uid);
          final remoteUid = remote.uid.isNotEmpty ? remote.uid : uid;
          await db.upsertMemo(
            uid: remoteUid,
            content: remote.content,
            visibility: remote.visibility,
            pinned: remote.pinned,
            state: remote.state,
            createTimeSec:
                remote.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            updateTimeSec:
                remote.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            tags: remote.tags,
            attachments: remote.attachments
                .map((a) => a.toJson())
                .toList(growable: false),
            location: remote.location,
            relationCount: countReferenceRelations(
              memoUid: remoteUid,
              relations: remote.relations,
            ),
            syncState: 0,
          );
          final refreshed = await db.getMemoByUid(remoteUid);
          if (refreshed != null) {
            memo = LocalMemo.fromDb(refreshed);
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.strings.legacy.msg_failed_load_4(e: e),
              ),
            ),
          );
          return;
        }
      }
    }

    if (memo == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_memo_not_found_locally,
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoDetailScreen(initialMemo: memo!),
      ),
    );
  }

  String _normalizeMemoUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('memos/')) return trimmed.substring('memos/'.length);
    return trimmed;
  }
}

class _RelationSummaryRow extends StatelessWidget {
  const _RelationSummaryRow({
    required this.borderColor,
    required this.bg,
    required this.textMain,
    required this.textMuted,
    required this.expanded,
    required this.countText,
    required this.onTap,
    this.boxed = true,
  });

  final Color borderColor;
  final Color bg;
  final Color textMain;
  final Color textMuted;
  final bool expanded;
  final String countText;
  final VoidCallback onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final label = context.t.strings.legacy.msg_links;
    final decoration = boxed
        ? BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withValues(alpha: 0.7)),
          )
        : null;
    final padding = boxed
        ? const EdgeInsets.symmetric(horizontal: 12)
        : EdgeInsets.zero;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: padding,
          decoration: decoration,
          child: Row(
            children: [
              Icon(Icons.link, size: 14, color: textMuted),
              const SizedBox(width: 6),
              Text(
                '$label - $countText',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMain,
                ),
              ),
              const Spacer(),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({
    required this.title,
    required this.items,
    required this.isDark,
    this.showHeader = true,
    this.onTap,
    this.boxed = true,
  });

  final String title;
  final List<_RelationItem> items;
  final bool isDark;
  final bool showHeader;
  final ValueChanged<_RelationItem>? onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final bg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final headerColor = textMain.withValues(alpha: isDark ? 0.7 : 0.8);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final decoration = boxed
        ? BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor.withValues(alpha: 0.7)),
          )
        : null;
    final padding = boxed
        ? const EdgeInsets.fromLTRB(12, 10, 12, 12)
        : EdgeInsets.zero;
    return Container(
      padding: padding,
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Icon(Icons.link, size: 14, color: headerColor),
                const SizedBox(width: 6),
                Text(
                  '$title (${items.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: headerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          ...items.map((item) {
            final row = Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _shortMemoId(item.name),
                      style: TextStyle(fontSize: 10, color: headerColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _relationSnippet(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textMain),
                    ),
                  ),
                ],
              ),
            );
            if (onTap == null) return row;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap!(item),
                child: row,
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _relationSnippet(_RelationItem item) {
    final snippet = item.snippet.trim();
    if (snippet.isNotEmpty) return snippet;
    final name = item.name.trim();
    if (name.isNotEmpty) return name;
    return '';
  }

  static String _shortMemoId(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '--';
    final raw = trimmed.startsWith('memos/')
        ? trimmed.substring('memos/'.length)
        : trimmed;
    return raw.length <= 6 ? raw : raw.substring(0, 6);
  }
}

class _RelationItem {
  const _RelationItem({required this.name, required this.snippet});

  final String name;
  final String snippet;
}

class _TaskProgressBar extends StatefulWidget {
  const _TaskProgressBar({
    required this.progress,
    required this.isDark,
    required this.total,
    required this.checked,
  });

  final double progress;
  final bool isDark;
  final int total;
  final int checked;

  @override
  State<_TaskProgressBar> createState() => _TaskProgressBarState();
}

class _TaskProgressBarState extends State<_TaskProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    final targetValue = widget.progress.clamp(0.0, 1.0);
    _animation = Tween<double>(
      begin: targetValue,
      end: targetValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.value = 1.0; // 直接跳到目标值，不播放动画
  }

  @override
  void didUpdateWidget(_TaskProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final targetValue = widget.progress.clamp(0.0, 1.0);
      final currentValue = _animation.value;
      final difference = (targetValue - currentValue).abs();

      // 根据进度差距调整动画时长：差距越大，动画时间越长
      final animationDuration = Duration(
        milliseconds: (400 + difference * 500).round(),
      );

      _controller.duration = animationDuration;

      _animation = Tween<double>(begin: currentValue, end: targetValue).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textColor = widget.isDark ? Colors.white70 : Colors.black54;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final percentage = (_animation.value * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.t.strings.legacy.msg_progress} (${widget.checked}/${widget.total})',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '$percentage%',
                    key: ValueKey(percentage),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _animation.value,
                minHeight: 8,
                backgroundColor: bg,
                valueColor: AlwaysStoppedAnimation(MemoFlowPalette.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MemoFlowFab extends StatefulWidget {
  const _MemoFlowFab({required this.onPressed, required this.hapticsEnabled});

  final VoidCallback? onPressed;
  final bool hapticsEnabled;

  @override
  State<_MemoFlowFab> createState() => _MemoFlowFabState();
}

class _MemoFlowFabState extends State<_MemoFlowFab> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) {
              if (widget.hapticsEnabled) {
                HapticFeedback.selectionClick();
              }
              setState(() => _pressed = true);
            },
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: MemoFlowPalette.primary,
            shape: BoxShape.circle,
            border: Border.all(color: bg, width: 4),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 10),
                color: MemoFlowPalette.primary.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.2
                      : 0.3,
                ),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
    );
  }
}

class _BackToTopButton extends StatefulWidget {
  const _BackToTopButton({
    required this.visible,
    required this.hapticsEnabled,
    required this.onPressed,
  });

  final bool visible;
  final bool hapticsEnabled;
  final VoidCallback onPressed;

  @override
  State<_BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<_BackToTopButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = MemoFlowPalette.primary;
    final iconColor = Colors.white;
    final scale = widget.visible ? (_pressed ? 0.92 : 1.0) : 0.85;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Semantics(
            button: true,
            label: context.t.strings.legacy.msg_back_top,
            child: GestureDetector(
              onTapDown: (_) {
                if (widget.hapticsEnabled) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _pressed = true);
              },
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) {
                setState(() => _pressed = false);
                widget.onPressed();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      color: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.35 : 0.25,
                      ),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 26,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
