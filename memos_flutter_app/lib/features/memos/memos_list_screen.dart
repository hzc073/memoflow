import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../application/sync/sync_coordinator.dart';
import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_localization.dart';
import '../../core/attachment_toast.dart';
import '../../core/desktop_settings_window.dart';
import '../../core/desktop_shortcuts.dart';
import '../../core/desktop_tray_controller.dart';
import '../../core/drawer_navigation.dart';
import '../../core/location_launcher.dart';
import '../../core/memo_relations.dart';
import '../../core/memo_template_renderer.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/sync_feedback.dart';
import '../../core/tags.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/api/server_api_profile.dart';
import '../../data/db/app_database.dart';
import '../../data/logs/sync_queue_progress_tracker.dart';
import '../../data/models/attachment.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/shortcut.dart';
import '../../data/location/location_geocoder.dart';
import '../../data/location/device_location_service.dart';
import '../../state/app_lock_provider.dart';
import '../../features/home/app_drawer.dart';
import '../../state/database_provider.dart';
import '../../state/debug_screenshot_mode_provider.dart';
import '../../state/local_library_provider.dart';
import '../../state/local_library_scanner.dart';
import '../../state/location_settings_provider.dart';
import '../../state/logging_provider.dart';
import '../../state/memo_timeline_provider.dart';
import '../../state/memo_template_settings_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/network_log_provider.dart';
import '../../state/note_draft_provider.dart';
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
import '../settings/desktop_shortcuts_overview_screen.dart';
import '../settings/location_settings_screen.dart';
import '../settings/password_lock_screen.dart';
import '../settings/shortcut_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../voice/voice_record_screen.dart';
import 'attachment_gallery_screen.dart';
import 'desktop_quick_input_dialog.dart';
import 'memo_detail_screen.dart';
import 'memo_editor_screen.dart';
import 'memo_image_grid.dart';
import 'memo_versions_screen.dart';
import 'memo_media_grid.dart';
import 'memo_markdown.dart';
import 'memo_location_line.dart';
import 'compose_toolbar_shared.dart';
import 'link_memo_sheet.dart';
import 'recycle_bin_screen.dart';
import 'memo_video_grid.dart';
import 'note_input_sheet.dart';
import 'windows_camera_capture_screen.dart';
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
      where: 'state IN (?, ?, ?, ?)',
      whereArgs: const [
        AppDatabase.outboxStatePending,
        AppDatabase.outboxStateRunning,
        AppDatabase.outboxStateRetry,
        AppDatabase.outboxStateError,
      ],
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

      final stateCode = switch (state) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v.trim()),
        _ => null,
      };
      if (stateCode == AppDatabase.outboxStateError) {
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

final _normalMemoCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<int> load() async {
    final sqlite = await db.db;
    final rows = await sqlite.rawQuery('''
      SELECT COUNT(*) AS memo_count
      FROM memos
      WHERE state = 'NORMAL'
    ''');
    if (rows.isEmpty) return 0;
    final raw = rows.first['memo_count'];
    return switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
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
    'upload_attachment' ||
    'delete_attachment' => payload['memo_uid'] as String?,
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

class _MemosListScreenState extends ConsumerState<MemosListScreen>
    with WindowListener {
  static const int _initialPageSize = 200;
  static const int _pageStep = 200;
  static const int _bootstrapImportThreshold = 50;
  static const double _mobilePullLoadThreshold = 64;
  static const Duration _desktopWheelLoadDebounce = Duration(milliseconds: 220);
  static const double _scrollToTopMinSpeedPxPerSecond = 2600;
  static const double _scrollToTopMaxSpeedPxPerSecond = 14000;
  static const double _scrollToTopDistanceSpeedFactor = 90;
  static const Duration _scrollToTopTick = Duration(milliseconds: 16);
  static const double _scrollToTopTickSeconds = 0.016;
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _inlineComposeController = TextEditingController();
  final _inlineComposeFocusNode = FocusNode();
  final _inlineTagMenuKey = GlobalKey();
  final _inlineTemplateMenuKey = GlobalKey();
  final _inlineTodoMenuKey = GlobalKey();
  final _inlineVisibilityMenuKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _titleKey = GlobalKey();
  final _scrollController = ScrollController();
  GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();

  var _searching = false;
  var _openedDrawerOnStart = false;
  String? _selectedShortcutId;
  QuickSearchKind? _selectedQuickSearchKind;
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
  bool _bootstrapImportActive = false;
  int _bootstrapImportTotal = 0;
  DateTime? _bootstrapImportStartedAt;
  int _pageSize = _initialPageSize;
  bool _reachedEnd = false;
  bool _loadingMore = false;
  String _paginationKey = '';
  int _lastResultCount = 0;
  int _currentResultCount = 0;
  String? _lastEmptyDiagnosticKey;
  String? _lastLoadingPhaseKey;
  bool _currentLoading = false;
  bool _currentShowSearchLanding = false;
  double _mobileBottomPullDistance = 0;
  bool _mobileBottomPullArmed = false;
  DateTime? _lastDesktopWheelLoadAt;
  bool _scrollToTopAnimating = false;
  Timer? _scrollToTopTimer;
  double _lastObservedScrollOffset = 0;
  DateTime? _lastScrollJumpLogAt;
  int _loadMoreRequestSeq = 0;
  int? _activeLoadMoreRequestId;
  String? _activeLoadMoreSource;
  bool _desktopWindowMaximized = false;
  bool _windowsHeaderSearchExpanded = false;
  bool _desktopQuickInputSubmitting = false;
  bool _inlineComposeBusy = false;
  bool _inlineComposeDraftApplied = false;
  String _inlineVisibility = 'PRIVATE';
  bool _inlineVisibilityTouched = false;
  final _inlineImagePicker = ImagePicker();
  final _inlineTemplateRenderer = MemoTemplateRenderer();
  MemoLocation? _inlineLocation;
  bool _inlineLocating = false;
  bool _inlineMoreToolbarOpen = false;
  final List<TextEditingValue> _inlineUndoStack = <TextEditingValue>[];
  final List<TextEditingValue> _inlineRedoStack = <TextEditingValue>[];
  TextEditingValue _inlineLastValue = const TextEditingValue();
  bool _inlineApplyingHistory = false;
  static const int _inlineMaxHistory = 100;
  Timer? _inlineComposeDraftTimer;
  ProviderSubscription<AsyncValue<String>>? _inlineDraftSubscription;
  final List<_InlinePendingAttachment> _inlinePendingAttachments =
      <_InlinePendingAttachment>[];
  final List<_InlineLinkedMemo> _inlineLinkedMemos = <_InlineLinkedMemo>[];

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
    _inlineComposeController.addListener(_scheduleInlineComposeDraftSave);
    _inlineComposeController.addListener(_trackInlineComposeHistory);
    _inlineLastValue = _inlineComposeController.value;
    _applyInlineComposeDraft(ref.read(noteDraftProvider));
    _inlineDraftSubscription = ref.listenManual<AsyncValue<String>>(
      noteDraftProvider,
      (prev, next) => _applyInlineComposeDraft(next),
    );
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
    if (Platform.isWindows) {
      windowManager.addListener(this);
      unawaited(_syncDesktopWindowState());
    }
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.addHandler(_handleDesktopShortcuts);
    }
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
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    if (isDesktopShortcutEnabled()) {
      HardwareKeyboard.instance.removeHandler(_handleDesktopShortcuts);
    }
    _inlineComposeDraftTimer?.cancel();
    _inlineDraftSubscription?.close();
    _inlineComposeController.removeListener(_scheduleInlineComposeDraftSave);
    _inlineComposeController.removeListener(_trackInlineComposeHistory);
    _inlineComposeController.dispose();
    _inlineComposeFocusNode.dispose();
    _searchFocusNode.dispose();
    _scrollToTopTimer?.cancel();
    _scrollToTopTimer = null;
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

  String _apiVersionBandLabel(MemosVersionNumber? version) {
    if (version == null) return '-';
    if (version.major == 0 && version.minor >= 20 && version.minor < 30) {
      return '0.2x';
    }
    return '${version.major}.${version.minor}x';
  }

  String _buildDebugApiVersionText(MemosVersionResolution? resolution) {
    if (resolution == null) return 'API -';
    final band = _apiVersionBandLabel(resolution.parsedVersion);
    final effective = resolution.effectiveVersion.trim();
    if (effective.isEmpty) return 'API $band';
    return 'API $band ($effective)';
  }

  void _selectTagFilter(String? tag) {
    setState(() => _activeTagFilter = _normalizeTag(tag));
  }

  bool _isTouchPullLoadPlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _resetMobilePullLoadState({bool notify = false}) {
    if (_mobileBottomPullDistance == 0 && !_mobileBottomPullArmed) return;
    if (notify && mounted) {
      setState(() {
        _mobileBottomPullDistance = 0;
        _mobileBottomPullArmed = false;
      });
      return;
    }
    _mobileBottomPullDistance = 0;
    _mobileBottomPullArmed = false;
  }

  bool _handleLoadMoreScrollNotification(ScrollNotification notification) {
    if (!_isTouchPullLoadPlatform()) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_scrollToTopAnimating) return false;

    final canArmPullLoad =
        !_currentShowSearchLanding &&
        !_currentLoading &&
        !_loadingMore &&
        !_reachedEnd;
    if (!canArmPullLoad) {
      _resetMobilePullLoadState(notify: false);
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final nearBottom =
          notification.metrics.pixels >=
          (notification.metrics.maxScrollExtent - 1);
      if (!nearBottom) {
        _resetMobilePullLoadState(notify: true);
      }
    }

    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      final atBottom =
          notification.metrics.maxScrollExtent > 0 &&
          notification.metrics.pixels >=
              (notification.metrics.maxScrollExtent - 1);
      if (!atBottom || notification.overscroll <= 0) return false;

      final nextDistance = (_mobileBottomPullDistance + notification.overscroll)
          .clamp(0.0, _mobilePullLoadThreshold * 2);
      final nextArmed = nextDistance >= _mobilePullLoadThreshold;
      if (nextDistance != _mobileBottomPullDistance ||
          nextArmed != _mobileBottomPullArmed) {
        setState(() {
          _mobileBottomPullDistance = nextDistance;
          _mobileBottomPullArmed = nextArmed;
        });
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final armed = _mobileBottomPullArmed;
      _resetMobilePullLoadState(notify: true);
      if (armed) {
        _loadMoreFromActionWithSource('mobile_pull_release');
      }
    }
    return false;
  }

  void _handleDesktopPointerSignal(PointerSignalEvent event) {
    if (_isTouchPullLoadPlatform()) return;
    if (_scrollToTopAnimating) return;
    if (event is! PointerScrollEvent) return;
    if (event.scrollDelta.dy <= 0) return;
    if (!_scrollController.hasClients) return;

    final metrics = _scrollController.position;
    if (metrics.maxScrollExtent <= 0) return;
    final nearBottom =
        metrics.pixels >=
        (metrics.maxScrollExtent - metrics.viewportDimension * 0.08);
    if (!nearBottom) return;

    final now = DateTime.now();
    final last = _lastDesktopWheelLoadAt;
    if (last != null && now.difference(last) < _desktopWheelLoadDebounce) {
      return;
    }
    _lastDesktopWheelLoadAt = now;
    _loadMoreFromActionWithSource('desktop_wheel');
  }

  String _describeLoadMoreBlockReason() {
    if (_currentShowSearchLanding) return 'search_landing';
    if (_currentLoading) return 'provider_loading';
    if (_loadingMore) return 'already_loading_more';
    if (_reachedEnd) return 'reached_end';
    if (_currentResultCount <= 0) return 'empty_result';
    if (_currentResultCount < _pageSize) return 'result_less_than_page_size';
    return 'unknown';
  }

  Map<String, Object?> _paginationDebugContext({
    ScrollMetrics? metrics,
    Map<String, Object?>? extra,
  }) {
    final context = <String, Object?>{
      'pageSize': _pageSize,
      'resultCount': _currentResultCount,
      'lastResultCount': _lastResultCount,
      'loadingMore': _loadingMore,
      'reachedEnd': _reachedEnd,
      'providerLoading': _currentLoading,
      'showSearchLanding': _currentShowSearchLanding,
      if (_activeLoadMoreRequestId != null)
        'activeRequestId': _activeLoadMoreRequestId,
      if (_activeLoadMoreSource != null)
        'activeRequestSource': _activeLoadMoreSource,
    };
    if (metrics != null) {
      context['offset'] = metrics.pixels;
      context['maxScrollExtent'] = metrics.maxScrollExtent;
      context['viewportHeight'] = metrics.viewportDimension;
    }
    if (extra != null && extra.isNotEmpty) {
      context.addAll(extra);
    }
    return context;
  }

  void _logPaginationDebug(
    String event, {
    ScrollMetrics? metrics,
    Map<String, Object?>? context,
  }) {
    if (!mounted) return;
    ref
        .read(logManagerProvider)
        .debug(
          'Memos pagination: $event',
          context: _paginationDebugContext(metrics: metrics, extra: context),
        );
  }

  void _logVisibleCountDecrease({
    required int beforeLength,
    required int afterLength,
    required bool signatureChanged,
    required bool listChanged,
    required String fromSignature,
    required String toSignature,
    required List<String> removedSample,
  }) {
    if (!mounted || afterLength >= beforeLength) return;
    ref
        .read(logManagerProvider)
        .info(
          'Memos list: visible_count_decreased',
          context: <String, Object?>{
            'beforeLength': beforeLength,
            'afterLength': afterLength,
            'decreasedBy': beforeLength - afterLength,
            'signatureChanged': signatureChanged,
            'listChanged': listChanged,
            'fromSignature': fromSignature,
            'toSignature': toSignature,
            if (removedSample.isNotEmpty) 'removedSample': removedSample,
          },
        );
  }

  void _maybeLogEmptyViewDiagnostics({
    required String queryKey,
    required List<LocalMemo>? memosValue,
    required bool memosLoading,
    required Object? memosError,
    required List<LocalMemo> visibleMemos,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) {
    if (memosValue == null || memosLoading || memosError != null) return;
    if (visibleMemos.isNotEmpty) return;
    final providerCount = memosValue.length;
    final diagnosticKey =
        '$queryKey|provider:$providerCount|animated:${visibleMemos.length}';
    if (_lastEmptyDiagnosticKey == diagnosticKey) return;
    _lastEmptyDiagnosticKey = diagnosticKey;
    unawaited(
      _logEmptyViewDiagnostics(
        queryKey: queryKey,
        providerCount: providerCount,
        animatedCount: visibleMemos.length,
        searchQuery: searchQuery,
        resolvedTag: resolvedTag,
        useShortcutFilter: useShortcutFilter,
        useQuickSearch: useQuickSearch,
        useRemoteSearch: useRemoteSearch,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        shortcutFilter: shortcutFilter,
        quickSearchKind: quickSearchKind,
      ),
    );
  }

  String _describeSyncState(SyncFlowStatus state) {
    if (state.running) return 'loading';
    if (state.lastError != null) return 'error';
    if (state.lastSuccessAt != null) return 'value';
    return 'idle';
  }

  String _buildMemosLoadingPhase({
    required bool memosLoading,
    required bool hasProviderValue,
    required Object? memosError,
    required int providerCount,
    required int animatedCount,
  }) {
    if (memosError != null) return 'provider_error';
    if (memosLoading && !hasProviderValue) return 'initial_loading';
    if (memosLoading && hasProviderValue) return 'refreshing_with_cached';
    if (!hasProviderValue) return 'no_provider_value';
    if (providerCount > 0) return 'data_ready';
    if (animatedCount > 0) return 'rendering_cached';
    return 'data_empty';
  }

  void _maybeLogMemosLoadingPhase({
    required String queryKey,
    required bool memosLoading,
    required Object? memosError,
    required List<LocalMemo>? memosValue,
    required List<LocalMemo> visibleMemos,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
    required SyncFlowStatus syncState,
    required SyncQueueProgressSnapshot syncQueueSnapshot,
  }) {
    if (!kDebugMode || !mounted) return;
    final hasProviderValue = memosValue != null;
    final providerCount = memosValue?.length ?? 0;
    final animatedCount = visibleMemos.length;
    final phase = _buildMemosLoadingPhase(
      memosLoading: memosLoading,
      hasProviderValue: hasProviderValue,
      memosError: memosError,
      providerCount: providerCount,
      animatedCount: animatedCount,
    );
    final key = [
      phase,
      queryKey,
      memosLoading,
      hasProviderValue,
      providerCount,
      animatedCount,
      _pageSize,
      _reachedEnd,
      _loadingMore,
      _describeSyncState(syncState),
      syncQueueSnapshot.syncing,
      syncQueueSnapshot.totalTasks,
      syncQueueSnapshot.completedTasks,
      syncQueueSnapshot.currentOutboxId,
      syncQueueSnapshot.currentProgress?.toStringAsFixed(2) ?? '-',
      useShortcutFilter,
      useQuickSearch,
      useRemoteSearch,
      shortcutFilter.trim().isNotEmpty ? shortcutFilter.trim() : '-',
      quickSearchKind?.name ?? '-',
    ].join('|');
    if (_lastLoadingPhaseKey == key) return;
    _lastLoadingPhaseKey = key;

    ref
        .read(logManagerProvider)
        .info(
          'Memos loading: phase',
          context: <String, Object?>{
            'phase': phase,
            'queryKey': queryKey,
            'memosLoading': memosLoading,
            'hasProviderValue': hasProviderValue,
            'providerCount': providerCount,
            'animatedCount': animatedCount,
            'pageSize': _pageSize,
            'reachedEnd': _reachedEnd,
            'loadingMore': _loadingMore,
            'providerLoading': _currentLoading,
            'showSearchLanding': _currentShowSearchLanding,
            'syncState': _describeSyncState(syncState),
            'queueSyncing': syncQueueSnapshot.syncing,
            'queueTotalTasks': syncQueueSnapshot.totalTasks,
            'queueCompletedTasks': syncQueueSnapshot.completedTasks,
            'queueCurrentOutboxId': syncQueueSnapshot.currentOutboxId,
            'queueCurrentProgress': syncQueueSnapshot.currentProgress,
            'useShortcutFilter': useShortcutFilter,
            'useQuickSearch': useQuickSearch,
            'useRemoteSearch': useRemoteSearch,
            if (shortcutFilter.trim().isNotEmpty)
              'shortcutFilter': shortcutFilter.trim(),
            if (quickSearchKind != null)
              'quickSearchKind': quickSearchKind.name,
            if (memosError != null) 'error': memosError.toString(),
          },
        );
  }

  Future<void> _logEmptyViewDiagnostics({
    required String queryKey,
    required int providerCount,
    required int animatedCount,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) async {
    try {
      final db = ref.read(databaseProvider);
      final allRows = await db.listMemosForExport(includeArchived: true);
      var dbNormal = 0;
      var dbArchived = 0;
      for (final row in allRows) {
        final state = (row['state'] as String? ?? '').trim().toUpperCase();
        if (state == 'ARCHIVED') {
          dbArchived++;
        } else {
          dbNormal++;
        }
      }
      final tag = resolvedTag?.trim();
      final normalizedSearch = searchQuery.trim();
      final previewRows = await db.listMemos(
        searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
        state: widget.state,
        tag: (tag == null || tag.isEmpty) ? null : tag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        limit: 5,
      );
      final previewUids = previewRows
          .map((row) => row['uid'])
          .whereType<String>()
          .toList(growable: false);
      if (!mounted) return;
      ref
          .read(logManagerProvider)
          .info(
            'Memos list: empty_view_diagnostic',
            context: <String, Object?>{
              'queryKey': queryKey,
              'state': widget.state,
              'providerCount': providerCount,
              'animatedCount': animatedCount,
              'searchLength': normalizedSearch.length,
              if (tag != null && tag.isNotEmpty) 'tag': tag,
              'useShortcutFilter': useShortcutFilter,
              if (shortcutFilter.trim().isNotEmpty)
                'shortcutFilter': shortcutFilter.trim(),
              'useQuickSearch': useQuickSearch,
              if (quickSearchKind != null)
                'quickSearchKind': quickSearchKind.name,
              'useRemoteSearch': useRemoteSearch,
              if (startTimeSec != null) 'startTimeSec': startTimeSec,
              if (endTimeSecExclusive != null)
                'endTimeSecExclusive': endTimeSecExclusive,
              'dbTotal': allRows.length,
              'dbNormal': dbNormal,
              'dbArchived': dbArchived,
              'dbPreviewCount': previewRows.length,
              if (previewUids.isNotEmpty) 'dbPreviewUids': previewUids,
            },
          );
    } catch (e, stackTrace) {
      if (!mounted) return;
      ref
          .read(logManagerProvider)
          .warn(
            'Memos list: empty_view_diagnostic_failed',
            error: e,
            stackTrace: stackTrace,
            context: <String, Object?>{'queryKey': queryKey},
          );
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final metrics = _scrollController.position;
    final previousOffset = _lastObservedScrollOffset;
    _lastObservedScrollOffset = metrics.pixels;

    final jumpedToTopUnexpectedly =
        previousOffset > (metrics.viewportDimension * 0.8) &&
        metrics.pixels <= 4 &&
        (previousOffset - metrics.pixels) > (metrics.viewportDimension * 0.8);
    if (jumpedToTopUnexpectedly) {
      final now = DateTime.now();
      final lastAt = _lastScrollJumpLogAt;
      if (lastAt == null ||
          now.difference(lastAt) > const Duration(milliseconds: 700)) {
        _lastScrollJumpLogAt = now;
        _logPaginationDebug(
          'scroll_jump_to_top_detected',
          metrics: metrics,
          context: {'previousOffset': previousOffset},
        );
      }
    }

    final threshold = metrics.viewportDimension * 2;
    final shouldShow = metrics.pixels >= threshold;
    if (shouldShow != _showBackToTop && mounted) {
      setState(() => _showBackToTop = shouldShow);
    }
  }

  void _triggerLoadMore({required String source}) {
    final requestId = ++_loadMoreRequestSeq;
    final previousPageSize = _pageSize;
    _activeLoadMoreRequestId = requestId;
    _activeLoadMoreSource = source;
    _loadingMore = true;
    _pageSize += _pageStep;
    _logPaginationDebug(
      'load_more_trigger',
      metrics: _scrollController.hasClients ? _scrollController.position : null,
      context: {
        'requestId': requestId,
        'source': source,
        'fromPageSize': previousPageSize,
        'toPageSize': _pageSize,
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  bool _canLoadMore() {
    if (_currentShowSearchLanding || _currentLoading) return false;
    if (_scrollToTopAnimating) return false;
    if (_loadingMore || _reachedEnd) return false;
    if (_currentResultCount <= 0) return false;
    if (_currentResultCount < _pageSize) {
      _reachedEnd = true;
      return false;
    }
    return true;
  }

  void _loadMoreFromActionWithSource(String source) {
    if (!_canLoadMore()) {
      _logPaginationDebug(
        'load_more_skipped',
        metrics: _scrollController.hasClients
            ? _scrollController.position
            : null,
        context: {'source': source, 'reason': _describeLoadMoreBlockReason()},
      );
      return;
    }
    _resetMobilePullLoadState(notify: false);
    _triggerLoadMore(source: source);
  }

  void _scrollByPage({required bool down}) {
    if (!_scrollController.hasClients) return;
    final metrics = _scrollController.position;
    final step = metrics.viewportDimension * 0.9;
    final rawTarget = down ? metrics.pixels + step : metrics.pixels - step;
    final target = rawTarget.clamp(0.0, metrics.maxScrollExtent);
    if ((target - metrics.pixels).abs() < 1) return;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  bool _handlePageNavigationShortcut({
    required LogicalKeyboardKey key,
    required bool primaryPressed,
    required bool shiftPressed,
    required bool altPressed,
  }) {
    if (primaryPressed || shiftPressed || altPressed) return false;
    if (_searchFocusNode.hasFocus) return false;
    if (key == LogicalKeyboardKey.pageUp) {
      _scrollByPage(down: false);
      return true;
    }
    if (key != LogicalKeyboardKey.pageDown) return false;
    _scrollByPage(down: true);
    if (!_scrollController.hasClients) {
      _loadMoreFromActionWithSource('page_down_no_clients');
      return true;
    }
    final metrics = _scrollController.position;
    final nearBottom =
        metrics.maxScrollExtent <= 0 ||
        metrics.pixels >=
            (metrics.maxScrollExtent - metrics.viewportDimension * 0.35);
    if (nearBottom) {
      _loadMoreFromActionWithSource('page_down_near_bottom');
    }
    return true;
  }

  void _stopScrollToTopFlow({bool snapToTop = false}) {
    _scrollToTopTimer?.cancel();
    _scrollToTopTimer = null;
    _scrollToTopAnimating = false;
    if (snapToTop && _scrollController.hasClients) {
      try {
        _scrollController.jumpTo(0);
      } catch (_) {}
    }
  }

  double _scrollToTopSpeedForDistance(double distanceToTopPx) {
    final safeDistance = distanceToTopPx.isFinite
        ? math.max(0.0, distanceToTopPx)
        : 0.0;
    final speed =
        _scrollToTopMinSpeedPxPerSecond +
        math.sqrt(safeDistance) * _scrollToTopDistanceSpeedFactor;
    return math.min(speed, _scrollToTopMaxSpeedPxPerSecond);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    if (_scrollToTopAnimating) return;
    _logPaginationDebug(
      'scroll_to_top_action',
      metrics: _scrollController.position,
      context: {'mode': 'distance_dynamic_speed'},
    );

    _scrollToTopAnimating = true;
    _scrollToTopTimer?.cancel();
    _scrollToTopTimer = Timer.periodic(_scrollToTopTick, (_) {
      if (!mounted || !_scrollController.hasClients) {
        _stopScrollToTopFlow();
        return;
      }
      final position = _scrollController.position;
      final current = position.pixels;
      if (current <= 0.5) {
        _stopScrollToTopFlow(snapToTop: true);
        return;
      }

      // Dynamic speed based on distance-to-top, but fixed per tick to avoid
      // large compensation jumps when frames are delayed.
      final speed = _scrollToTopSpeedForDistance(current);
      final delta = speed * _scrollToTopTickSeconds;
      final target = (current - delta).clamp(0.0, position.maxScrollExtent);
      if ((current - target).abs() < 0.001) return;
      try {
        _scrollController.jumpTo(target);
      } catch (_) {
        _stopScrollToTopFlow();
        return;
      }
      if (target <= 0.5) {
        _stopScrollToTopFlow(snapToTop: true);
      }
    });
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

  Widget _buildHeaderTitleWidget(
    BuildContext context, {
    required VoidCallback maybeHaptic,
  }) {
    if (widget.enableTitleMenu) {
      return InkWell(
        key: _titleKey,
        onTap: () {
          maybeHaptic();
          _openTitleMenu();
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      );
    }
    return Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildTopSearchField(
    BuildContext context, {
    required bool isDark,
    required bool autofocus,
    String? hintText,
  }) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      key: const ValueKey('search'),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? MemoFlowPalette.borderDark.withValues(alpha: 0.7)
              : MemoFlowPalette.borderLight,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText ?? context.t.strings.legacy.msg_search,
          border: InputBorder.none,
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: hasQuery
              ? IconButton(
                  tooltip: context.t.strings.legacy.msg_clear,
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close, size: 16),
                )
              : null,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: _submitSearch,
      ),
    );
  }

  bool _shouldUseInlineComposeForCurrentWindow() {
    if (!widget.enableCompose || _searching) {
      return false;
    }
    final width = MediaQuery.sizeOf(context).width;
    return shouldUseInlineComposeLayout(width);
  }

  bool _isDesktopShortcutRouteActive() {
    if (!mounted || !isDesktopShortcutEnabled()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return !ref.read(appLockProvider).locked;
  }

  void _showShortcutPlaceholder(String label) {
    showTopToast(
      context,
      '\u300c$label\u300d\u529f\u80fd\u6682\u672a\u5b9e\u73b0\uff08\u5360\u4f4d\uff09\u3002',
    );
  }

  void _focusSearchFromShortcut() {
    if (Platform.isWindows && !_searching) {
      _openWindowsHeaderSearch();
      return;
    }
    _openSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _openQuickInputFromShortcut() async {
    if (!widget.enableCompose) return;
    if (_windowsHeaderSearchExpanded) {
      _closeWindowsHeaderSearch();
    }
    if (_searching) {
      _closeSearch();
    }
    if (_shouldUseInlineComposeForCurrentWindow()) {
      _scrollToTop();
      _inlineComposeFocusNode.requestFocus();
      return;
    }
    await _openNoteInput();
  }

  Future<void> _openQuickRecordFromShortcut() async {
    if (!isDesktopShortcutEnabled()) {
      _showShortcutPlaceholder('快速输入');
      return;
    }
    final content = await DesktopQuickInputDialog.show(
      context,
      onImagePressed: () => _showShortcutPlaceholder('插入图片'),
    );
    if (!mounted || content == null) return;
    await _submitDesktopQuickInput(content);
  }

  Future<void> _submitDesktopQuickInput(String rawContent) async {
    final content = rawContent.trimRight();
    if (content.trim().isEmpty || _desktopQuickInputSubmitting) return;

    setState(() => _desktopQuickInputSubmitting = true);
    try {
      final now = DateTime.now();
      final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      final uid = generateUid();
      final visibility = _resolveInlineComposeVisibility();
      final db = ref.read(databaseProvider);
      final tags = extractTags(content);

      await db.upsertMemo(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        state: 'NORMAL',
        createTimeSec: nowSec,
        updateTimeSec: nowSec,
        tags: tags,
        attachments: const <Map<String, dynamic>>[],
        location: null,
        relationCount: 0,
        syncState: 1,
      );

      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': uid,
          'content': content,
          'visibility': visibility,
          'pinned': false,
          'has_attachments': false,
        },
      );

      unawaited(ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual)));
      if (!mounted) return;
      showTopToast(context, '已保存到 MemoFlow');
    } catch (error, stackTrace) {
      ref
          .read(logManagerProvider)
          .error(
            'Desktop quick input submit failed',
            error: error,
            stackTrace: stackTrace,
          );
      if (!mounted) return;
      showTopToast(context, '快速输入保存失败：$error');
    } finally {
      if (mounted) {
        setState(() => _desktopQuickInputSubmitting = false);
      }
    }
  }

  String _toggleDesktopDrawerFromShortcut() {
    if (!widget.showDrawer) return 'drawer_disabled';

    final width = MediaQuery.sizeOf(context).width;
    final supportsDesktopPane = shouldUseDesktopSidePaneLayout(width);
    if (supportsDesktopPane) {
      // Desktop side pane remains pinned open.
      return 'desktop_sidepane_pinned';
    }

    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return 'scaffold_missing';
    if (scaffold.isDrawerOpen) {
      Navigator.of(context).maybePop();
      return 'drawer_closed';
    } else {
      scaffold.openDrawer();
      return 'drawer_opened';
    }
  }

  Future<void> _toggleMemoFlowVisibilityFromShortcut() async {
    if (!isDesktopShortcutEnabled()) {
      _showShortcutPlaceholder('\u663e\u793a/\u9690\u85cf MemoFlow');
      return;
    }
    try {
      if (DesktopTrayController.instance.supported) {
        final visible = await windowManager.isVisible();
        if (visible) {
          await DesktopTrayController.instance.hideToTray();
        } else {
          await DesktopTrayController.instance.showFromTray();
        }
        return;
      }
      final visible = await windowManager.isVisible();
      if (visible) {
        if (Platform.isWindows || Platform.isLinux) {
          await windowManager.setSkipTaskbar(true);
        }
        await windowManager.hide();
        return;
      }
      if (Platform.isWindows || Platform.isLinux) {
        await windowManager.setSkipTaskbar(false);
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (error) {
      if (!mounted) return;
      showTopToast(context, '显示/隐藏 MemoFlow 失败：$error');
    }
  }

  void _openPasswordLockFromShortcut() {
    final lockState = ref.read(appLockProvider);
    if (lockState.enabled && lockState.hasPassword) {
      ref.read(appLockProvider.notifier).lock();
      showTopToast(context, '\u5df2\u542f\u7528\u5e94\u7528\u9501\u3002');
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PasswordLockScreen()));
  }

  void _openShortcutOverviewPage() {
    final bindings = normalizeDesktopShortcutBindings(
      ref.read(appPreferencesProvider).desktopShortcutBindings,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DesktopShortcutsOverviewScreen(bindings: bindings),
      ),
    );
  }

  bool _shouldTraceDesktopShortcut(
    KeyEvent event,
    Set<LogicalKeyboardKey> pressedKeys,
  ) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.f1) return true;
    return isPrimaryShortcutModifierPressed(pressedKeys) ||
        isShiftModifierPressed(pressedKeys) ||
        isAltModifierPressed(pressedKeys);
  }

  void _logDesktopShortcutEvent({
    required String stage,
    required KeyEvent event,
    required Set<LogicalKeyboardKey> pressedKeys,
    DesktopShortcutAction? action,
    String? reason,
    Map<String, Object?>? extra,
  }) {
    if (!mounted) return;
    final payload = <String, Object?>{
      'keyId': event.logicalKey.keyId,
      'keyLabel': event.logicalKey.keyLabel,
      'debugName': event.logicalKey.debugName,
      'primaryPressed': isPrimaryShortcutModifierPressed(pressedKeys),
      'shiftPressed': isShiftModifierPressed(pressedKeys),
      'altPressed': isAltModifierPressed(pressedKeys),
      if (action != null) 'action': action.name,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
    };
    if (extra != null && extra.isNotEmpty) {
      payload.addAll(extra);
    }
    final logger = ref.read(logManagerProvider);
    if (stage == 'matched' || stage == 'delegated') {
      logger.info('Desktop shortcut: $stage', context: payload);
    } else {
      logger.debug('Desktop shortcut: $stage', context: payload);
    }
  }

  void _toggleInlineHighlight() {
    final value = _inlineComposeController.value;
    final selection = value.selection;
    const prefix = '==';
    const suffix = '==';
    if (!selection.isValid || selection.isCollapsed) {
      _insertInlineComposeText('$prefix$suffix', caretOffset: prefix.length);
      return;
    }
    final selected = value.text.substring(selection.start, selection.end);
    final wrapped = '$prefix$selected$suffix';
    _inlineComposeController.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, wrapped),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  bool _handleDesktopShortcuts(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    if (!_isDesktopShortcutRouteActive()) {
      if (_shouldTraceDesktopShortcut(event, pressed)) {
        _logDesktopShortcutEvent(
          stage: 'ignored',
          event: event,
          pressedKeys: pressed,
          reason: 'route_inactive_or_locked',
        );
      }
      return false;
    }

    final bindings = normalizeDesktopShortcutBindings(
      ref.read(appPreferencesProvider).desktopShortcutBindings,
    );
    bool matches(DesktopShortcutAction action) {
      return matchesDesktopShortcut(
        event: event,
        pressedKeys: pressed,
        binding: bindings[action]!,
      );
    }

    final primaryPressed = isPrimaryShortcutModifierPressed(pressed);
    final shiftPressed = isShiftModifierPressed(pressed);
    final altPressed = isAltModifierPressed(pressed);
    final key = event.logicalKey;
    final inlineEditorActive = _inlineComposeFocusNode.hasFocus;
    final traceThisKey = _shouldTraceDesktopShortcut(event, pressed);

    if (matches(DesktopShortcutAction.shortcutOverview) ||
        key == LogicalKeyboardKey.f1) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.shortcutOverview,
        reason: key == LogicalKeyboardKey.f1 ? 'f1_fallback' : null,
      );
      _openShortcutOverviewPage();
      showTopToast(context, '已打开快捷键总览。');
      return true;
    }

    if (matches(DesktopShortcutAction.search)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.search,
      );
      _focusSearchFromShortcut();
      return true;
    }
    if (matches(DesktopShortcutAction.quickInput)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.quickInput,
      );
      unawaited(_openQuickInputFromShortcut());
      return true;
    }
    if (matches(DesktopShortcutAction.quickRecord)) {
      // Desktop global hotkey is handled in App-level hotkey_manager to avoid
      // duplicate dialogs when the app is foregrounded.
      if (!DesktopTrayController.instance.supported) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.quickRecord,
          reason: 'in_window_dialog',
        );
        unawaited(_openQuickRecordFromShortcut());
      } else {
        _logDesktopShortcutEvent(
          stage: 'delegated',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.quickRecord,
          reason: 'handled_by_app_hotkey_manager',
        );
      }
      return true;
    }

    if (inlineEditorActive) {
      if (matches(DesktopShortcutAction.publishMemo) ||
          (!primaryPressed &&
              shiftPressed &&
              !altPressed &&
              key == LogicalKeyboardKey.enter)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.publishMemo,
          reason: matches(DesktopShortcutAction.publishMemo)
              ? 'binding'
              : 'shift_enter_fallback',
        );
        unawaited(_submitInlineCompose());
        return true;
      }
      if (matches(DesktopShortcutAction.bold)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.bold,
        );
        _toggleInlineBold();
        return true;
      }
      if (matches(DesktopShortcutAction.underline)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.underline,
        );
        _toggleInlineUnderline();
        return true;
      }
      if (matches(DesktopShortcutAction.highlight)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.highlight,
        );
        _toggleInlineHighlight();
        return true;
      }
      if (matches(DesktopShortcutAction.unorderedList)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.unorderedList,
        );
        _insertInlineComposeText('- ');
        return true;
      }
      if (matches(DesktopShortcutAction.orderedList)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.orderedList,
        );
        _insertInlineComposeText('1. ');
        return true;
      }
      if (matches(DesktopShortcutAction.undo)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.undo,
        );
        _undoInlineCompose();
        return true;
      }
      if (matches(DesktopShortcutAction.redo)) {
        _logDesktopShortcutEvent(
          stage: 'matched',
          event: event,
          pressedKeys: pressed,
          action: DesktopShortcutAction.redo,
        );
        _redoInlineCompose();
        return true;
      }
    }
    if (!inlineEditorActive &&
        _handlePageNavigationShortcut(
          key: key,
          primaryPressed: primaryPressed,
          shiftPressed: shiftPressed,
          altPressed: altPressed,
        )) {
      return true;
    }

    if (matches(DesktopShortcutAction.enableAppLock)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.enableAppLock,
      );
      _openPasswordLockFromShortcut();
      return true;
    }
    if (matches(DesktopShortcutAction.toggleSidebar)) {
      final drawerResult = _toggleDesktopDrawerFromShortcut();
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.toggleSidebar,
        extra: {'drawerResult': drawerResult},
      );
      return true;
    }
    if (matches(DesktopShortcutAction.refresh)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.refresh,
      );
      unawaited(ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual)));
      return true;
    }
    if (matches(DesktopShortcutAction.backHome)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.backHome,
      );
      _backToAllMemos();
      return true;
    }
    if (matches(DesktopShortcutAction.openSettings)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.openSettings,
      );
      if (openDesktopSettingsWindowIfSupported(feedbackContext: context)) {
        return true;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      return true;
    }
    if (matches(DesktopShortcutAction.toggleFlomo)) {
      _logDesktopShortcutEvent(
        stage: 'matched',
        event: event,
        pressedKeys: pressed,
        action: DesktopShortcutAction.toggleFlomo,
      );
      unawaited(_toggleMemoFlowVisibilityFromShortcut());
      return true;
    }
    if (traceThisKey) {
      _logDesktopShortcutEvent(
        stage: 'no_match',
        event: event,
        pressedKeys: pressed,
        extra: {'inlineEditorActive': inlineEditorActive},
      );
    }
    return false;
  }

  Future<void> _syncDesktopWindowState() async {
    if (!Platform.isWindows) return;
    final maximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = maximized);
  }

  Future<void> _minimizeDesktopWindow() async {
    if (!Platform.isWindows) return;
    await windowManager.minimize();
  }

  Future<void> _toggleDesktopWindowMaximize() async {
    if (!Platform.isWindows) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncDesktopWindowState();
  }

  Future<void> _closeDesktopWindow() async {
    if (!Platform.isWindows) return;
    final closeToTray = ref.read(
      appPreferencesProvider.select((p) => p.windowsCloseToTray),
    );
    if (closeToTray && DesktopTrayController.instance.supported) {
      try {
        await DesktopTrayController.instance.hideToTray();
        return;
      } catch (error, stackTrace) {
        ref
            .read(logManagerProvider)
            .warn(
              'Hide to tray failed. Falling back to closing window.',
              error: error,
              stackTrace: stackTrace,
            );
      }
    }
    await windowManager.close();
  }

  Widget _buildPillActionsRow(
    BuildContext context, {
    required VoidCallback maybeHaptic,
  }) {
    return _PillRow(
      onWeeklyInsights: () {
        maybeHaptic();
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const StatsScreen()));
      },
      onAiSummary: () {
        maybeHaptic();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AiSummaryScreen()),
        );
      },
      onDailyReview: () {
        maybeHaptic();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DailyReviewScreen()),
        );
      },
    );
  }

  Widget _buildWindowsDesktopTitleBar(
    BuildContext context, {
    required bool isDark,
    required bool enableHomeSort,
    required bool showPillActions,
    required VoidCallback maybeHaptic,
    required bool screenshotModeEnabled,
    required String debugApiVersionText,
  }) {
    final barBg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DragToMoveArea(child: SizedBox.expand()),
          Row(
            children: [
              SizedBox(
                width: 260,
                child: Row(
                  children: [
                    IgnorePointer(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/splash/splash_logo.png',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.auto_stories_rounded,
                              size: 22,
                              color: textColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: textColor, fontSize: 14),
                        child: widget.enableTitleMenu
                            ? _buildHeaderTitleWidget(
                                context,
                                maybeHaptic: maybeHaptic,
                              )
                            : IgnorePointer(
                                child: _buildHeaderTitleWidget(
                                  context,
                                  maybeHaptic: maybeHaptic,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _windowsHeaderSearchExpanded
                          ? _buildTopSearchField(
                              context,
                              isDark: isDark,
                              autofocus: false,
                              hintText: 'Quick search...',
                            )
                          : (showPillActions
                                ? _buildPillActionsRow(
                                    context,
                                    maybeHaptic: maybeHaptic,
                                  )
                                : const SizedBox.shrink()),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (enableHomeSort) ...[
                _buildSortMenuButton(context, isDark: isDark),
                const SizedBox(width: 2),
              ],
              if (widget.enableSearch)
                IconButton(
                  tooltip: _windowsHeaderSearchExpanded
                      ? context.t.strings.legacy.msg_cancel_2
                      : context.t.strings.legacy.msg_search,
                  onPressed: _toggleWindowsHeaderSearch,
                  icon: Icon(
                    _windowsHeaderSearchExpanded ? Icons.close : Icons.search,
                  ),
                ),
              if (kDebugMode && !screenshotModeEnabled) ...[
                IgnorePointer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MemoFlowPalette.primary.withValues(
                          alpha: isDark ? 0.24 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.45 : 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        debugApiVersionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MemoFlowPalette.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _DesktopWindowIconButton(
                tooltip: 'Minimize',
                onPressed: () => unawaited(_minimizeDesktopWindow()),
                icon: Icons.minimize_rounded,
              ),
              _DesktopWindowIconButton(
                tooltip: _desktopWindowMaximized ? 'Restore' : 'Maximize',
                onPressed: () => unawaited(_toggleDesktopWindowMaximize()),
                icon: _desktopWindowMaximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
              ),
              _DesktopWindowIconButton(
                tooltip: 'Close',
                onPressed: () => unawaited(_closeDesktopWindow()),
                icon: Icons.close_rounded,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() => _desktopWindowMaximized = false);
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
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
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
          : (!isAbsolute ||
                (attachAuthForSameOriginAbsolute &&
                    isSameOriginWithBase(baseUrl, resolved)));
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
          content: Text(context.t.strings.legacy.msg_unable_load_audio_source),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _openWindowsHeaderSearch() {
    if (!Platform.isWindows || !widget.enableSearch) return;
    if (_windowsHeaderSearchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
      return;
    }
    setState(() => _windowsHeaderSearchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeWindowsHeaderSearch({bool clearQuery = true}) {
    if (!Platform.isWindows || !_windowsHeaderSearchExpanded) return;
    _searchFocusNode.unfocus();
    if (clearQuery) {
      _searchController.clear();
    }
    setState(() {
      _windowsHeaderSearchExpanded = false;
      _selectedQuickSearchKind = null;
    });
  }

  void _toggleWindowsHeaderSearch() {
    if (_windowsHeaderSearchExpanded) {
      _closeWindowsHeaderSearch();
      return;
    }
    _openWindowsHeaderSearch();
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _windowsHeaderSearchExpanded = false;
      _selectedQuickSearchKind = null;
    });
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

  void _toggleQuickSearchKind(QuickSearchKind kind) {
    setState(() {
      if (_selectedQuickSearchKind == kind) {
        _selectedQuickSearchKind = null;
      } else {
        _selectedQuickSearchKind = kind;
      }
    });
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
    if (_windowsHeaderSearchExpanded) {
      _closeWindowsHeaderSearch();
      return false;
    }
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
      AppDrawerDestination.recycleBin => const RecycleBinScreen(),
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

  Future<void> _retryFailedMemoSync(String memoUid) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) {
      _openSyncQueue();
      return;
    }
    final db = ref.read(databaseProvider);
    final retried = await db.retryOutboxErrors(memoUid: normalizedUid);
    if (retried <= 0) {
      _openSyncQueue();
      return;
    }
    if (!mounted) return;
    showTopToast(context, context.t.strings.legacy.msg_retry_started);
    unawaited(ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual)));
  }

  Future<void> _handleMemoSyncStatusTap(
    _MemoSyncStatus status,
    String memoUid,
  ) async {
    switch (status) {
      case _MemoSyncStatus.failed:
        await _retryFailedMemoSync(memoUid);
        return;
      case _MemoSyncStatus.pending:
      case _MemoSyncStatus.none:
        _openSyncQueue();
        return;
    }
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

  void _applyInlineComposeDraft(AsyncValue<String> value) {
    if (_inlineComposeDraftApplied) return;
    final draft = value.valueOrNull;
    if (draft == null) return;
    if (_inlineComposeController.text.trim().isEmpty &&
        draft.trim().isNotEmpty) {
      _inlineComposeController.text = draft;
      _inlineComposeController.selection = TextSelection.collapsed(
        offset: draft.length,
      );
    }
    _inlineComposeDraftApplied = true;
  }

  void _scheduleInlineComposeDraftSave() {
    _inlineComposeDraftTimer?.cancel();
    final text = _inlineComposeController.text;
    _inlineComposeDraftTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(noteDraftProvider.notifier).setDraft(text);
    });
  }

  String _resolveInlineComposeVisibility() {
    final settings = ref.read(userGeneralSettingProvider).valueOrNull;
    final value = (settings?.memoVisibility ?? '').trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  String _normalizedInlineVisibility(String raw) {
    final value = raw.trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  String _currentInlineVisibility() {
    if (_inlineVisibilityTouched) {
      return _normalizedInlineVisibility(_inlineVisibility);
    }
    return _resolveInlineComposeVisibility();
  }

  (String label, IconData icon, Color color) _resolveInlineVisibilityStyle(
    BuildContext context,
    String raw,
  ) {
    switch (raw.trim().toUpperCase()) {
      case 'PUBLIC':
        return (
          context.t.strings.legacy.msg_public,
          Icons.public,
          const Color(0xFF3B8C52),
        );
      case 'PROTECTED':
        return (
          context.t.strings.legacy.msg_protected,
          Icons.verified_user,
          const Color(0xFFB26A2B),
        );
      default:
        return (
          context.t.strings.legacy.msg_private_2,
          Icons.lock,
          const Color(0xFF7C7C7C),
        );
    }
  }

  void _insertInlineComposeText(String text, {int? caretOffset}) {
    final value = _inlineComposeController.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final newText = value.text.replaceRange(start, end, text);
    final caret = start + (caretOffset ?? text.length);
    _inlineComposeController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
  }

  void _replaceInlineComposeText(String text) {
    _inlineComposeController.value = _inlineComposeController.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  void _trackInlineComposeHistory() {
    if (_inlineApplyingHistory) return;
    final value = _inlineComposeController.value;
    if (value.text == _inlineLastValue.text &&
        value.selection == _inlineLastValue.selection) {
      return;
    }
    _inlineUndoStack.add(_inlineLastValue);
    if (_inlineUndoStack.length > _inlineMaxHistory) {
      _inlineUndoStack.removeAt(0);
    }
    _inlineRedoStack.clear();
    _inlineLastValue = value;
  }

  void _undoInlineCompose() {
    if (_inlineUndoStack.isEmpty || _inlineComposeBusy) return;
    _inlineApplyingHistory = true;
    final current = _inlineComposeController.value;
    final previous = _inlineUndoStack.removeLast();
    _inlineRedoStack.add(current);
    _inlineComposeController.value = previous;
    _inlineLastValue = previous;
    _inlineApplyingHistory = false;
    if (mounted) setState(() {});
  }

  void _redoInlineCompose() {
    if (_inlineRedoStack.isEmpty || _inlineComposeBusy) return;
    _inlineApplyingHistory = true;
    final current = _inlineComposeController.value;
    final next = _inlineRedoStack.removeLast();
    _inlineUndoStack.add(current);
    _inlineComposeController.value = next;
    _inlineLastValue = next;
    _inlineApplyingHistory = false;
    if (mounted) setState(() {});
  }

  void _toggleInlineBold() {
    final value = _inlineComposeController.value;
    final selection = value.selection;
    if (!selection.isValid) {
      _insertInlineComposeText('****');
      _inlineComposeController.selection = const TextSelection.collapsed(
        offset: 2,
      );
      return;
    }
    if (selection.isCollapsed) {
      _insertInlineComposeText('****');
      _inlineComposeController.selection = TextSelection.collapsed(
        offset: selection.start + 2,
      );
      return;
    }
    final selected = value.text.substring(selection.start, selection.end);
    final wrapped = '**$selected**';
    _inlineComposeController.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, wrapped),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _toggleInlineUnderline() {
    final value = _inlineComposeController.value;
    final selection = value.selection;
    const prefix = '<u>';
    const suffix = '</u>';
    if (!selection.isValid || selection.isCollapsed) {
      _insertInlineComposeText('$prefix$suffix', caretOffset: prefix.length);
      return;
    }
    final selected = value.text.substring(selection.start, selection.end);
    final wrapped = '$prefix$selected$suffix';
    _inlineComposeController.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, wrapped),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + wrapped.length,
      ),
      composing: TextRange.empty,
    );
  }

  Future<void> _openInlineLocationSettings() async {
    if (_inlineComposeBusy) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LocationSettingsScreen()),
    );
  }

  Future<LocationSettings> _resolveInlineLocationSettings() async {
    final current = ref.read(locationSettingsProvider);
    if (current.enabled) return current;
    final stored = await ref.read(locationSettingsRepositoryProvider).read();
    if (!mounted) return stored;
    await ref
        .read(locationSettingsProvider.notifier)
        .setAll(stored, triggerSync: false);
    return stored;
  }

  String _inlineLocationErrorText(Object error) {
    if (error is LocationException) {
      return switch (error.code) {
        'service_disabled' =>
          context.t.strings.legacy.msg_location_services_disabled,
        'permission_denied' =>
          context.t.strings.legacy.msg_location_permission_denied,
        'permission_denied_forever' =>
          context.t.strings.legacy.msg_location_permission_denied_permanently,
        'timeout' => context.t.strings.legacy.msg_location_timed_try,
        _ => context.t.strings.legacy.msg_failed_get_location,
      };
    }
    if (error is TimeoutException) {
      return context.t.strings.legacy.msg_location_timed_try;
    }
    return context.t.strings.legacy.msg_failed_get_location;
  }

  bool _isInlineWindowsLocationSettingsActionable(Object error) {
    if (!Platform.isWindows || error is! LocationException) return false;
    return error.code == 'permission_denied' ||
        error.code == 'permission_denied_forever' ||
        error.code == 'service_disabled';
  }

  void _showInlineLocationError(Object error) {
    final messenger = ScaffoldMessenger.of(context);
    final message = _inlineLocationErrorText(error);
    if (!_isInlineWindowsLocationSettingsActionable(error)) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('$message. Enable location access in Windows settings.'),
        action: SnackBarAction(
          label: context.t.strings.legacy.msg_settings,
          onPressed: () {
            unawaited(DeviceLocationService().openSystemLocationSettings());
          },
        ),
      ),
    );
  }

  Future<void> _openWindowsCameraSettings() async {
    if (!Platform.isWindows) return;
    try {
      await Process.start('cmd', <String>[
        '/c',
        'start',
        '',
        'ms-settings:privacy-webcam',
      ]);
    } catch (_) {}
  }

  bool _isWindowsCameraPermissionError(Object error) {
    if (!Platform.isWindows) return false;
    final message = error.toString().toLowerCase();
    return message.contains('permission') ||
        message.contains('access denied') ||
        message.contains('cameraaccessdenied') ||
        message.contains('privacy');
  }

  bool _isWindowsNoCameraError(Object error) {
    if (!Platform.isWindows) return false;
    final message = error.toString().toLowerCase();
    return message.contains('no camera') ||
        message.contains('no available camera') ||
        message.contains('no device') ||
        message.contains('camera_not_found') ||
        message.contains('camera not found') ||
        message.contains('capture device') ||
        message.contains('cameradelegate') ||
        message.contains('no capture devices') ||
        message.contains('unavailable');
  }

  Future<void> _requestInlineLocation() async {
    if (_inlineComposeBusy || _inlineLocating) return;
    if (Platform.isWindows) {
      setState(() => _inlineLocating = true);
      try {
        final position = await DeviceLocationService().getCurrentPosition();
        final settings = await _resolveInlineLocationSettings();
        String placeholder = '';
        if (settings.enabled) {
          final geocoder = LocationGeocoder(
            logStore: ref.read(networkLogStoreProvider),
            logBuffer: ref.read(networkLogBufferProvider),
            logManager: ref.read(logManagerProvider),
          );
          placeholder =
              await geocoder.reverseGeocode(
                latitude: position.latitude,
                longitude: position.longitude,
                settings: settings,
              ) ??
              '';
        }
        final next = MemoLocation(
          placeholder: placeholder,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (!mounted) return;
        setState(() => _inlineLocation = next);
        showTopToast(
          context,
          context.t.strings.legacy.msg_location_updated(
            next_displayText_fractionDigits_6: next.displayText(
              fractionDigits: 6,
            ),
          ),
          duration: const Duration(seconds: 2),
        );
      } catch (error) {
        if (!mounted) return;
        _showInlineLocationError(error);
      } finally {
        if (mounted) {
          setState(() => _inlineLocating = false);
        }
      }
      return;
    }

    final settings = await _resolveInlineLocationSettings();
    if (!settings.enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t
                .strings
                .legacy
                .msg_location_disabled_enable_settings_first,
          ),
          action: SnackBarAction(
            label: context.t.strings.legacy.msg_settings,
            onPressed: _openInlineLocationSettings,
          ),
        ),
      );
      return;
    }

    setState(() => _inlineLocating = true);
    try {
      final position = await DeviceLocationService().getCurrentPosition();
      String placeholder = '';
      final geocoder = LocationGeocoder(
        logStore: ref.read(networkLogStoreProvider),
        logBuffer: ref.read(networkLogBufferProvider),
        logManager: ref.read(logManagerProvider),
      );
      placeholder =
          await geocoder.reverseGeocode(
            latitude: position.latitude,
            longitude: position.longitude,
            settings: settings,
          ) ??
          '';
      final next = MemoLocation(
        placeholder: placeholder,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() => _inlineLocation = next);
      showTopToast(
        context,
        context.t.strings.legacy.msg_location_updated(
          next_displayText_fractionDigits_6: next.displayText(
            fractionDigits: 6,
          ),
        ),
        duration: const Duration(seconds: 2),
      );
    } catch (error) {
      if (!mounted) return;
      _showInlineLocationError(error);
    } finally {
      if (mounted) {
        setState(() => _inlineLocating = false);
      }
    }
  }

  Future<void> _captureInlinePhoto() async {
    if (_inlineComposeBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final photo = Platform.isWindows
          ? await WindowsCameraCaptureScreen.capture(context)
          : await _inlineImagePicker.pickImage(source: ImageSource.camera);
      if (!mounted || photo == null) return;
      final path = photo.path.trim();
      if (path.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Camera file missing.')),
        );
        return;
      }
      final file = File(path);
      if (!file.existsSync()) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Camera file missing.')),
        );
        return;
      }
      final size = await file.length();
      if (!mounted) return;
      final filename = path.split(Platform.pathSeparator).last;
      final mimeType = _guessInlineAttachmentMimeType(filename);
      setState(() {
        _inlinePendingAttachments.add(
          _InlinePendingAttachment(
            uid: generateUid(),
            filePath: path,
            filename: filename,
            mimeType: mimeType,
            size: size,
          ),
        );
      });
      showTopToast(context, 'Added photo attachment.');
    } catch (error) {
      if (!mounted) return;
      if (_isWindowsNoCameraError(error)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No camera detected.')),
        );
        return;
      }
      if (_isWindowsCameraPermissionError(error)) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Camera permission denied. Enable camera access in Windows settings.',
            ),
            action: SnackBarAction(
              label: context.t.strings.legacy.msg_settings,
              onPressed: () {
                unawaited(_openWindowsCameraSettings());
              },
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Camera failed: $error')));
    }
  }

  void _toggleInlineMoreToolbar() {
    if (_inlineComposeBusy) return;
    setState(() => _inlineMoreToolbarOpen = !_inlineMoreToolbarOpen);
  }

  void _closeInlineMoreToolbar() {
    if (!_inlineMoreToolbarOpen) return;
    setState(() => _inlineMoreToolbarOpen = false);
  }

  Widget _buildInlineMoreToolbar({required bool isDark}) {
    return MemoComposeMoreToolbar(
      isDark: isDark,
      busy: _inlineComposeBusy,
      onBoldPressed: () {
        _closeInlineMoreToolbar();
        _toggleInlineBold();
      },
      onListPressed: () {
        _closeInlineMoreToolbar();
        _insertInlineComposeText('- ');
      },
      onUnderlinePressed: () {
        _closeInlineMoreToolbar();
        _toggleInlineUnderline();
      },
      onCameraPressed: () {
        _closeInlineMoreToolbar();
        unawaited(_captureInlinePhoto());
      },
      onLocationPressed: () {
        _closeInlineMoreToolbar();
        unawaited(_requestInlineLocation());
      },
      onUndoPressed: () {
        _closeInlineMoreToolbar();
        _undoInlineCompose();
      },
      onRedoPressed: () {
        _closeInlineMoreToolbar();
        _redoInlineCompose();
      },
      undoEnabled: _inlineUndoStack.isNotEmpty,
      redoEnabled: _inlineRedoStack.isNotEmpty,
      locationBusy: _inlineLocating,
    );
  }

  Set<String> get _inlineLinkedMemoNames =>
      _inlineLinkedMemos.map((m) => m.name).toSet();

  void _addInlineLinkedMemo(Memo memo) {
    final name = memo.name.trim();
    if (name.isEmpty) return;
    if (_inlineLinkedMemos.any((m) => m.name == name)) return;
    final raw = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final label = raw.isNotEmpty
        ? _truncateInlineLabel(raw)
        : _truncateInlineLabel(
            name.startsWith('memos/') ? name.substring('memos/'.length) : name,
          );
    setState(
      () => _inlineLinkedMemos.add(_InlineLinkedMemo(name: name, label: label)),
    );
  }

  void _removeInlineLinkedMemo(String name) {
    setState(() => _inlineLinkedMemos.removeWhere((m) => m.name == name));
  }

  String _truncateInlineLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  Future<void> _openInlineLinkMemoSheet() async {
    if (_inlineComposeBusy) return;
    final selection = await LinkMemoSheet.show(
      context,
      existingNames: _inlineLinkedMemoNames,
    );
    if (!mounted || selection == null) return;
    _addInlineLinkedMemo(selection);
  }

  Future<void> _openInlineTagMenuFromKey(
    GlobalKey key,
    List<TagStat> tags,
  ) async {
    if (_inlineComposeBusy) return;
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    await _openInlineTagMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      tags,
    );
  }

  Future<void> _openInlineTagMenu(
    RelativeRect position,
    List<TagStat> tags,
  ) async {
    if (_inlineComposeBusy) return;
    final items = tags.isEmpty
        ? [
            const PopupMenuItem<String>(
              enabled: false,
              child: Text('No tags yet'),
            ),
          ]
        : tags
              .map(
                (stat) => PopupMenuItem<String>(
                  value: stat.tag,
                  child: Text('#${stat.tag}'),
                ),
              )
              .toList(growable: false);

    final selection = await showMenu<String>(
      context: context,
      position: position,
      items: items,
    );
    if (!mounted || selection == null) return;
    final normalized = selection.startsWith('#')
        ? selection.substring(1)
        : selection;
    if (normalized.isEmpty) return;
    _insertInlineComposeText('$normalized ');
  }

  Future<void> _openInlineTemplateMenuFromKey(
    GlobalKey key,
    List<MemoTemplate> templates,
  ) async {
    if (_inlineComposeBusy) return;
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    await _openInlineTemplateMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      templates,
    );
  }

  Future<void> _openInlineTemplateMenu(
    RelativeRect position,
    List<MemoTemplate> templates,
  ) async {
    if (_inlineComposeBusy) return;
    final items = templates.isEmpty
        ? const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(enabled: false, child: Text('暂无模板')),
          ]
        : templates
              .map(
                (template) => PopupMenuItem<String>(
                  value: template.id,
                  child: Text(template.name),
                ),
              )
              .toList(growable: false);

    final selectedId = await showMenu<String>(
      context: context,
      position: position,
      items: items,
    );
    if (!mounted || selectedId == null) return;
    MemoTemplate? selected;
    for (final item in templates) {
      if (item.id == selectedId) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;
    await _applyInlineTemplate(selected);
  }

  Future<void> _applyInlineTemplate(MemoTemplate template) async {
    final templateSettings = ref.read(memoTemplateSettingsProvider);
    final locationSettings = ref.read(locationSettingsProvider);
    final rendered = await _inlineTemplateRenderer.render(
      templateContent: template.content,
      variableSettings: templateSettings.variables,
      locationSettings: locationSettings,
    );
    if (!mounted) return;
    _replaceInlineComposeText(rendered);
  }

  Future<void> _openInlineTodoShortcutMenuFromKey(GlobalKey key) async {
    if (_inlineComposeBusy) return;
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    await _openInlineTodoShortcutMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    );
  }

  Future<void> _openInlineTodoShortcutMenu(RelativeRect position) async {
    if (_inlineComposeBusy) return;
    final action = await showMenu<MemoComposeTodoShortcutAction>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.checkbox,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_box_outlined, size: 18),
              SizedBox(width: 8),
              Text('Checkbox'),
            ],
          ),
        ),
        PopupMenuItem(
          value: MemoComposeTodoShortcutAction.codeBlock,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code, size: 18),
              SizedBox(width: 8),
              Text('Code block'),
            ],
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case MemoComposeTodoShortcutAction.checkbox:
        _insertInlineComposeText('- [ ] ');
        break;
      case MemoComposeTodoShortcutAction.codeBlock:
        _insertInlineComposeText('```\n\n```', caretOffset: 4);
        break;
    }
  }

  Future<void> _openInlineVisibilityMenuFromKey(GlobalKey key) async {
    if (_inlineComposeBusy) return;
    final target = key.currentContext;
    if (target == null) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = target.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    await _openInlineVisibilityMenu(
      RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    );
  }

  Future<void> _openInlineVisibilityMenu(RelativeRect position) async {
    if (_inlineComposeBusy) return;
    final selection = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'PRIVATE',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_private_2),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'PROTECTED',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_protected),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'PUBLIC',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 18),
              const SizedBox(width: 8),
              Text(context.t.strings.legacy.msg_public),
            ],
          ),
        ),
      ],
    );
    if (!mounted || selection == null) return;
    setState(() {
      _inlineVisibility = selection;
      _inlineVisibilityTouched = true;
    });
  }

  String _guessInlineAttachmentMimeType(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot == -1 ? '' : lower.substring(dot + 1);
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      '7z' => 'application/x-7z-compressed',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'log' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  bool _isInlineImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
  }

  bool _isInlineVideoMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('video/');
  }

  Future<void> _pickInlineAttachments() async {
    if (_inlineComposeBusy) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withReadStream: true,
      );
      if (!mounted) return;
      final files = result?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;

      final added = <_InlinePendingAttachment>[];
      var missingPathCount = 0;
      Directory? tempDir;
      for (final file in files) {
        String path = (file.path ?? '').trim();
        if (path.isEmpty) {
          final stream = file.readStream;
          final bytes = file.bytes;
          if (stream == null && bytes == null) {
            missingPathCount++;
            continue;
          }
          tempDir ??= await getTemporaryDirectory();
          final name = file.name.trim().isNotEmpty
              ? file.name.trim()
              : 'attachment_${generateUid()}';
          final tempFile = File(
            '${tempDir.path}${Platform.pathSeparator}${generateUid()}_$name',
          );
          if (bytes != null) {
            await tempFile.writeAsBytes(bytes, flush: true);
          } else if (stream != null) {
            final sink = tempFile.openWrite();
            await sink.addStream(stream);
            await sink.close();
          }
          path = tempFile.path;
        }

        if (path.trim().isEmpty) {
          missingPathCount++;
          continue;
        }

        final handle = File(path);
        if (!handle.existsSync()) {
          missingPathCount++;
          continue;
        }
        final size = handle.lengthSync();
        final filename = file.name.trim().isNotEmpty
            ? file.name.trim()
            : path.split(Platform.pathSeparator).last;
        final mimeType = _guessInlineAttachmentMimeType(filename);
        added.add(
          _InlinePendingAttachment(
            uid: generateUid(),
            filePath: path,
            filename: filename,
            mimeType: mimeType,
            size: size,
          ),
        );
      }

      if (!mounted) return;
      if (added.isEmpty) {
        final msg = missingPathCount > 0
            ? 'Files unavailable from picker.'
            : 'No files selected.';
        showTopToast(context, msg);
        return;
      }

      setState(() {
        _inlinePendingAttachments.addAll(added);
      });
      final suffix = added.length == 1 ? '' : 's';
      final skipped = [
        if (missingPathCount > 0) '$missingPathCount unavailable',
      ];
      final summary = skipped.isEmpty
          ? 'Added ${added.length} file$suffix.'
          : 'Added ${added.length} file$suffix. Skipped ${skipped.join(', ')}.';
      showTopToast(context, summary);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File selection failed: $error')));
    }
  }

  void _removeInlinePendingAttachment(String uid) {
    setState(() => _inlinePendingAttachments.removeWhere((a) => a.uid == uid));
  }

  File? _resolveInlinePendingAttachmentFile(
    _InlinePendingAttachment attachment,
  ) {
    final path = attachment.filePath.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String _inlinePendingSourceId(String uid) => 'inline-pending:$uid';

  List<
    ({
      AttachmentImageSource source,
      _InlinePendingAttachment attachment,
      File file,
    })
  >
  _inlinePendingImageSources() {
    final items =
        <
          ({
            AttachmentImageSource source,
            _InlinePendingAttachment attachment,
            File file,
          })
        >[];
    for (final attachment in _inlinePendingAttachments) {
      if (!_isInlineImageMimeType(attachment.mimeType)) continue;
      final file = _resolveInlinePendingAttachmentFile(attachment);
      if (file == null) continue;
      items.add((
        source: AttachmentImageSource(
          id: _inlinePendingSourceId(attachment.uid),
          title: attachment.filename,
          mimeType: attachment.mimeType,
          localFile: file,
        ),
        attachment: attachment,
        file: file,
      ));
    }
    return items;
  }

  Future<void> _openInlineAttachmentViewer(
    _InlinePendingAttachment attachment,
  ) async {
    final items = _inlinePendingImageSources();
    if (items.isEmpty) return;
    final index = items.indexWhere(
      (item) => item.attachment.uid == attachment.uid,
    );
    if (index < 0) return;
    final sources = items.map((item) => item.source).toList(growable: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentGalleryScreen(
          images: sources,
          initialIndex: index,
          onReplace: _replaceInlinePendingAttachment,
          enableDownload: true,
        ),
      ),
    );
  }

  Future<void> _replaceInlinePendingAttachment(EditedImageResult result) async {
    final id = result.sourceId;
    if (!id.startsWith('inline-pending:')) return;
    final uid = id.substring('inline-pending:'.length);
    final index = _inlinePendingAttachments.indexWhere((a) => a.uid == uid);
    if (index < 0) return;
    setState(() {
      _inlinePendingAttachments[index] = _InlinePendingAttachment(
        uid: uid,
        filePath: result.filePath,
        filename: result.filename,
        mimeType: result.mimeType,
        size: result.size,
      );
    });
  }

  Widget _buildInlineAttachmentPreview(bool isDark) {
    if (_inlinePendingAttachments.isEmpty) return const SizedBox.shrink();
    const tileSize = 62.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: tileSize,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < _inlinePendingAttachments.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _buildInlineAttachmentTile(
                  _inlinePendingAttachments[i],
                  isDark: isDark,
                  size: tileSize,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineAttachmentTile(
    _InlinePendingAttachment attachment, {
    required bool isDark,
    required double size,
  }) {
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final surfaceColor = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final iconColor =
        (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
            .withValues(alpha: 0.6);
    final removeBg = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.5);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.12);
    final isImage = _isInlineImageMimeType(attachment.mimeType);
    final isVideo = _isInlineVideoMimeType(attachment.mimeType);
    final file = _resolveInlinePendingAttachmentFile(attachment);

    Widget content;
    if (isImage && file != null) {
      content = Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _inlineAttachmentFallback(
            iconColor: iconColor,
            surfaceColor: surfaceColor,
            isImage: true,
          );
        },
      );
    } else if (isVideo && file != null) {
      final entry = MemoVideoEntry(
        id: attachment.uid,
        title: attachment.filename.isNotEmpty ? attachment.filename : 'video',
        mimeType: attachment.mimeType,
        size: attachment.size,
        localFile: file,
        videoUrl: null,
        headers: null,
      );
      content = AttachmentVideoThumbnail(
        entry: entry,
        width: size,
        height: size,
        borderRadius: 14,
        fit: BoxFit.cover,
        showPlayIcon: false,
      );
    } else {
      content = _inlineAttachmentFallback(
        iconColor: iconColor,
        surfaceColor: surfaceColor,
        isImage: isImage,
        isVideo: isVideo,
      );
    }

    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: content),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: (isImage && file != null)
              ? () => _openInlineAttachmentViewer(attachment)
              : null,
          child: tile,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _inlineComposeBusy
                ? null
                : () => _removeInlinePendingAttachment(attachment.uid),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: removeBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inlineAttachmentFallback({
    required Color iconColor,
    required Color surfaceColor,
    required bool isImage,
    bool isVideo = false,
  }) {
    return Container(
      color: surfaceColor,
      alignment: Alignment.center,
      child: Icon(
        isImage
            ? Icons.image_outlined
            : (isVideo
                  ? Icons.videocam_outlined
                  : Icons.insert_drive_file_outlined),
        size: 22,
        color: iconColor,
      ),
    );
  }

  void _addInlineVoiceAttachment(VoiceRecordResult result) {
    final messenger = ScaffoldMessenger.of(context);
    final path = result.filePath.trim();
    if (path.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_recording_path_missing),
        ),
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_recording_file_not_found_2,
          ),
        ),
      );
      return;
    }

    final size = result.size > 0 ? result.size : file.lengthSync();
    final filename = result.fileName.trim().isNotEmpty
        ? result.fileName.trim()
        : path.split(Platform.pathSeparator).last;
    final mimeType = _guessInlineAttachmentMimeType(filename);
    setState(() {
      _inlinePendingAttachments.add(
        _InlinePendingAttachment(
          uid: generateUid(),
          filePath: path,
          filename: filename,
          mimeType: mimeType,
          size: size,
        ),
      );
    });
    showTopToast(context, context.t.strings.legacy.msg_added_voice_attachment);
  }

  Future<void> _submitInlineCompose() async {
    if (_inlineComposeBusy || !widget.enableCompose) return;
    final content = _inlineComposeController.text.trimRight();
    final relations = _inlineLinkedMemos
        .map((m) => m.toRelationJson())
        .toList(growable: false);
    final pendingAttachments = List<_InlinePendingAttachment>.from(
      _inlinePendingAttachments,
    );
    final hasAttachments = pendingAttachments.isNotEmpty;
    if (content.trim().isEmpty && !hasAttachments) {
      if (relations.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter content before creating a link.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      final result = await Navigator.of(context).push<VoiceRecordResult>(
        MaterialPageRoute(builder: (_) => const VoiceRecordScreen()),
      );
      if (!mounted || result == null) return;
      _addInlineVoiceAttachment(result);
      return;
    }

    setState(() => _inlineComposeBusy = true);
    try {
      final now = DateTime.now();
      final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      final uid = generateUid();
      final tags = extractTags(content);
      final visibility = _currentInlineVisibility();
      final db = ref.read(databaseProvider);
      final attachments = pendingAttachments
          .map((attachment) {
            final rawPath = attachment.filePath.trim();
            final externalLink = rawPath.isEmpty
                ? ''
                : rawPath.startsWith('content://')
                ? rawPath
                : Uri.file(rawPath).toString();
            return Attachment(
              name: 'attachments/${attachment.uid}',
              filename: attachment.filename,
              type: attachment.mimeType,
              size: attachment.size,
              externalLink: externalLink,
            ).toJson();
          })
          .toList(growable: false);

      await db.upsertMemo(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        state: 'NORMAL',
        createTimeSec: nowSec,
        updateTimeSec: nowSec,
        tags: tags,
        attachments: attachments,
        location: _inlineLocation,
        relationCount: 0,
        syncState: 1,
      );

      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': uid,
          'content': content,
          'visibility': visibility,
          'pinned': false,
          'has_attachments': hasAttachments,
          if (_inlineLocation != null) 'location': _inlineLocation!.toJson(),
          if (relations.isNotEmpty) 'relations': relations,
        },
      );

      for (final attachment in pendingAttachments) {
        await db.enqueueOutbox(
          type: 'upload_attachment',
          payload: {
            'uid': attachment.uid,
            'memo_uid': uid,
            'file_path': attachment.filePath,
            'filename': attachment.filename,
            'mime_type': attachment.mimeType,
            'file_size': attachment.size,
          },
        );
      }

      unawaited(ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual)));
      _inlineComposeDraftTimer?.cancel();
      _inlineComposeController.clear();
      await ref.read(noteDraftProvider.notifier).clear();
      if (mounted) {
        setState(() {
          _inlinePendingAttachments.clear();
          _inlineLinkedMemos.clear();
          _inlineLocation = null;
          _inlineLocating = false;
          _inlineMoreToolbarOpen = false;
          _inlineUndoStack.clear();
          _inlineRedoStack.clear();
          _inlineLastValue = _inlineComposeController.value;
        });
        _inlineComposeFocusNode.requestFocus();
      }
    } catch (error, stackTrace) {
      ref
          .read(logManagerProvider)
          .error(
            'Inline compose submit failed',
            error: error,
            stackTrace: stackTrace,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_create_failed_2(e: error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _inlineComposeBusy = false);
      }
    }
  }

  Widget _buildInlineComposeCard({
    required bool isDark,
    required List<TagStat> tagStats,
    required List<MemoTemplate> availableTemplates,
  }) {
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final hintColor = textColor.withValues(alpha: isDark ? 0.42 : 0.55);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : MemoFlowPalette.audioSurfaceLight;
    final chipText = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final (visibilityLabel, visibilityIcon, visibilityColor) =
        _resolveInlineVisibilityStyle(context, _currentInlineVisibility());

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.75)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  color: Colors.black.withValues(alpha: 0.05),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInlineAttachmentPreview(isDark),
          if (_inlineLinkedMemos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _inlineLinkedMemos
                    .map(
                      (memo) => InputChip(
                        avatar: Icon(
                          Icons.alternate_email_rounded,
                          size: 16,
                          color: chipText.withValues(alpha: 0.75),
                        ),
                        label: Text(
                          memo.label,
                          style: TextStyle(fontSize: 12, color: chipText),
                        ),
                        backgroundColor: chipBg,
                        deleteIconColor: chipText.withValues(alpha: 0.55),
                        onDeleted: _inlineComposeBusy
                            ? null
                            : () => _removeInlineLinkedMemo(memo.name),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          if (_inlineLocating)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.t.strings.legacy.msg_locating,
                    style: TextStyle(fontSize: 12, color: chipText),
                  ),
                ],
              ),
            ),
          if (_inlineLocation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: chipText.withValues(alpha: 0.75),
                  ),
                  label: Text(
                    _inlineLocation!.displayText(fractionDigits: 6),
                    style: TextStyle(fontSize: 12, color: chipText),
                  ),
                  backgroundColor: chipBg,
                  deleteIconColor: chipText.withValues(alpha: 0.55),
                  onDeleted: _inlineComposeBusy
                      ? null
                      : () => setState(() => _inlineLocation = null),
                ),
              ),
            ),
          TextField(
            controller: _inlineComposeController,
            focusNode: _inlineComposeFocusNode,
            enabled: !_inlineComposeBusy,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontSize: 15, height: 1.35, color: textColor),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: context.t.strings.legacy.msg_write_thoughts,
              hintStyle: TextStyle(color: hintColor),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _inlineMoreToolbarOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildInlineMoreToolbar(isDark: isDark),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MemoComposePrimaryToolbar(
                  isDark: isDark,
                  busy: _inlineComposeBusy,
                  moreOpen: _inlineMoreToolbarOpen,
                  visibilityMessage: context.t.strings.legacy.msg_visibility_2(
                    visibilityLabel: visibilityLabel,
                  ),
                  visibilityIcon: visibilityIcon,
                  visibilityColor: visibilityColor,
                  tagButtonKey: _inlineTagMenuKey,
                  templateButtonKey: _inlineTemplateMenuKey,
                  todoButtonKey: _inlineTodoMenuKey,
                  visibilityButtonKey: _inlineVisibilityMenuKey,
                  onTagPressed: () {
                    _closeInlineMoreToolbar();
                    _insertInlineComposeText('#');
                    unawaited(
                      _openInlineTagMenuFromKey(_inlineTagMenuKey, tagStats),
                    );
                  },
                  onTemplatePressed: () {
                    _closeInlineMoreToolbar();
                    unawaited(
                      _openInlineTemplateMenuFromKey(
                        _inlineTemplateMenuKey,
                        availableTemplates,
                      ),
                    );
                  },
                  onAttachmentPressed: () {
                    _closeInlineMoreToolbar();
                    unawaited(_pickInlineAttachments());
                  },
                  onTodoPressed: () {
                    _closeInlineMoreToolbar();
                    unawaited(
                      _openInlineTodoShortcutMenuFromKey(_inlineTodoMenuKey),
                    );
                  },
                  onLinkPressed: () {
                    _closeInlineMoreToolbar();
                    unawaited(_openInlineLinkMemoSheet());
                  },
                  onToggleMorePressed: _toggleInlineMoreToolbar,
                  onVisibilityPressed: () {
                    _closeInlineMoreToolbar();
                    unawaited(
                      _openInlineVisibilityMenuFromKey(
                        _inlineVisibilityMenuKey,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _inlineComposeController,
                builder: (context, value, _) {
                  final showSend =
                      value.text.trim().isNotEmpty ||
                      _inlinePendingAttachments.isNotEmpty;
                  return Material(
                    color: MemoFlowPalette.primary,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _inlineComposeBusy ? null : _submitInlineCompose,
                      child: SizedBox(
                        width: 38,
                        height: 30,
                        child: Center(
                          child: _inlineComposeBusy
                              ? SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                                  child: Icon(
                                    showSend
                                        ? Icons.send_rounded
                                        : Icons.graphic_eq,
                                    key: ValueKey<bool>(showSend),
                                    size: showSend ? 18 : 20,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
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
    final syncState = ref.read(syncCoordinatorProvider).memos;
    if (syncState.running) {
      showTopToast(context, context.t.strings.legacy.msg_syncing);
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_scan_local_library),
            content: Text(
              context
                  .t
                  .strings
                  .legacy
                  .msg_scan_disk_directory_merge_local_database,
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
    if (!mounted) return;
    final currentSyncState = ref.read(syncCoordinatorProvider).memos;
    if (currentSyncState.running) {
      showTopToast(context, context.t.strings.legacy.msg_syncing);
      return;
    }
    final scanner = ref.read(localLibraryScannerProvider);
    if (scanner == null) return;
    try {
      var result = await scanner.scanAndMerge(forceDisk: false);
      while (result is LocalScanConflictResult) {
        final decisions = await _resolveLocalScanConflicts(result.conflicts);
        result = await scanner.scanAndMerge(
          forceDisk: false,
          conflictDecisions: decisions,
        );
      }
      if (!mounted) return;
      switch (result) {
        case LocalScanSuccess():
          showTopToast(context, context.t.strings.legacy.msg_scan_completed);
          return;
        case LocalScanFailure(:final error):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.strings.legacy.msg_scan_failed(
                      e: _formatLocalScanError(error),
                    ),
              ),
            ),
          );
          return;
        default:
          return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_scan_failed(e: e))),
      );
    }
  }

  Future<Map<String, bool>> _resolveLocalScanConflicts(
    List<LocalScanConflict> conflicts,
  ) async {
    final decisions = <String, bool>{};
    for (final conflict in conflicts) {
      final useDisk =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.t.strings.legacy.msg_resolve_conflict),
              content: Text(
                conflict.isDeletion
                    ? context
                        .t
                        .strings
                        .legacy
                        .msg_memo_missing_disk_but_has_local
                    : context
                        .t
                        .strings
                        .legacy
                        .msg_disk_content_conflicts_local_pending_changes,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.t.strings.legacy.msg_keep_local),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.t.strings.legacy.msg_use_disk),
                ),
              ],
            ),
          ) ??
          false;
      decisions[conflict.memoUid] = useDisk;
    }
    return decisions;
  }

  String _formatLocalScanError(SyncError error) {
    return presentSyncError(language: context.appLanguage, error: error);
  }


  void _maybeAutoScanLocalLibrary({
    required bool memosLoading,
    required List<LocalMemo>? memosValue,
    required bool useRemoteSearch,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required String searchQuery,
    required String? resolvedTag,
    required DateTime? filterDay,
  }) {
    if (_autoScanTriggered || _autoScanInFlight) return;
    if (memosLoading) return;
    if (useRemoteSearch || useShortcutFilter || useQuickSearch) return;
    if (widget.state != 'NORMAL') return;
    if (searchQuery.trim().isNotEmpty) return;
    if (resolvedTag != null && resolvedTag.trim().isNotEmpty) return;
    if (filterDay != null) return;
    if (memosValue != null && memosValue.isNotEmpty) return;

    final scanner = ref.read(localLibraryScannerProvider);
    if (scanner == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _autoScanInFlight = true;
      var bootstrapModeEnabled = false;
      try {
        final db = ref.read(databaseProvider);
        final existing = await db.listMemos(limit: 1);
        if (!mounted) return;
        if (existing.isNotEmpty) return;

        final diskMemos = await scanner.fileSystem.listMemos();
        if (!mounted || diskMemos.isEmpty) return;
        if (diskMemos.length >= _bootstrapImportThreshold) {
          bootstrapModeEnabled = true;
          setState(() {
            _bootstrapImportActive = true;
            _bootstrapImportTotal = diskMemos.length;
            _bootstrapImportStartedAt = DateTime.now();
          });
        }
        _autoScanTriggered = true;
        await ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual));
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
        if (bootstrapModeEnabled && mounted) {
          setState(() {
            _bootstrapImportActive = false;
            _bootstrapImportTotal = 0;
            _bootstrapImportStartedAt = null;
          });
        }
        _autoScanInFlight = false;
      }
    });
  }

  Widget _buildBootstrapImportOverlay(
    BuildContext context, {
    required bool isDark,
    required int importedCount,
    required int totalCount,
    required Duration? elapsed,
  }) {
    final cardColor = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.62 : 0.58);
    final backdropColor =
        (isDark
                ? MemoFlowPalette.backgroundDark
                : MemoFlowPalette.backgroundLight)
            .withValues(alpha: isDark ? 0.94 : 0.96);
    final safeTotal = totalCount <= 0 ? importedCount : totalCount;
    final safeImported = importedCount.clamp(0, safeTotal).toInt();
    final progress = safeTotal > 0
        ? (safeImported / safeTotal).clamp(0.0, 1.0).toDouble()
        : null;
    final elapsedText = elapsed == null ? null : _formatDuration(elapsed);

    return AbsorbPointer(
      child: Container(
        color: backdropColor,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor.withValues(alpha: 0.92)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: MemoFlowPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.t.strings.legacy.msg_importing_memos,
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${context.t.strings.legacy.msg_imported_memos}: $safeImported / $safeTotal',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: MemoFlowPalette.primary,
                      backgroundColor: MemoFlowPalette.primary.withValues(
                        alpha: isDark ? 0.2 : 0.16,
                      ),
                    ),
                  ),
                ],
                if (elapsedText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${context.t.strings.legacy.msg_loading} $elapsedText',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
        SnackBar(content: Text(context.t.strings.legacy.msg_not_authenticated)),
      );
      return;
    }
    try {
      final api = ref.read(memosApiProvider);
      await api.ensureServerHintsLoaded();
      final useLocalShortcuts =
          api.usesLegacySearchFilterDialect ||
          api.shortcutsSupportedHint == false;
      final created = useLocalShortcuts
          ? await ref
                .read(localShortcutsRepositoryProvider)
                .create(title: result.title, filter: result.filter)
          : await api.createShortcut(
              userName: account.user.name,
              title: result.title,
              filter: result.filter,
            );
      ref.invalidate(shortcutsProvider);
      if (!mounted) return;
      setState(() {
        _selectedShortcutId = created.shortcutId;
        _selectedQuickSearchKind = null;
      });
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
    if (!overlay.hasSize || !titleBox.hasSize) return;
    if (overlay.size.width <= 40 || overlay.size.height <= 40) return;

    final position = titleBox.localToGlobal(Offset.zero, ancestor: overlay);
    final maxWidth = overlay.size.width - 24;
    if (maxWidth <= 0) return;
    final width = (maxWidth < 220 ? maxWidth : 240).toDouble().clamp(
      140.0,
      320.0,
    );
    final left = position.dx.clamp(12.0, overlay.size.width - width - 12.0);
    final top = position.dy + titleBox.size.height + 6;
    final availableHeight = overlay.size.height - top - 16;
    final menuMaxHeight =
        (availableHeight > 120 ? availableHeight : overlay.size.height * 0.6)
            .clamp(140.0, overlay.size.height - 12.0);

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
        setState(() {
          _selectedShortcutId = action.shortcutId;
          _selectedQuickSearchKind = null;
        });
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
    unawaited(ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual)));
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
    final timelineService = ref.read(memoTimelineServiceProvider);
    final tags = extractTags(content);

    await timelineService.captureMemoVersion(memo);

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
      unawaited(ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual)));
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
              context
                  .t
                  .strings
                  .legacy
                  .msg_removed_locally_now_deleted_server_when,
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

    final db = ref.read(databaseProvider);
    final timelineService = ref.read(memoTimelineServiceProvider);
    try {
      await timelineService.moveMemoToRecycleBin(memo);
      _removeMemoWithAnimation(memo);
      await db.deleteMemoByUid(memo.uid);
      await db.enqueueOutbox(
        type: 'delete_memo',
        payload: {'uid': memo.uid, 'force': false},
      );
      await ref.read(reminderSchedulerProvider).rescheduleAll();
      unawaited(ref.read(syncCoordinatorProvider.notifier).requestSync(const SyncRequest(kind: SyncRequestKind.memos, reason: SyncRequestReason.manual)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_delete_failed(e: e)),
        ),
      );
    }
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
          content: Text(context.t.strings.legacy.msg_restore_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _archiveMemo(LocalMemo memo) async {
    try {
      await _updateMemo(memo, state: 'ARCHIVED');
      _removeMemoWithAnimation(memo);
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_archived);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_archive_failed(e: e)),
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
      case _MemoCardAction.history:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoVersionsScreen(memoUid: memo.uid),
          ),
        );
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
    final sameSignature = _listSignature == signature;

    // Pagination appends items at the tail. Keep list state and insert rows
    // instead of rebuilding the whole sliver to avoid scroll jumps on desktop.
    if (sameSignature &&
        _animatedMemos.isNotEmpty &&
        filtered.length > _animatedMemos.length &&
        _sameMemoPrefix(_animatedMemos, filtered)) {
      final insertStart = _animatedMemos.length;
      final insertCount = filtered.length - _animatedMemos.length;
      _logPaginationDebug(
        'animated_list_append_prepare',
        metrics: _scrollController.hasClients
            ? _scrollController.position
            : null,
        context: {
          'signature': signature,
          'beforeLength': _animatedMemos.length,
          'afterLength': filtered.length,
          'insertStart': insertStart,
          'insertCount': insertCount,
        },
      );
      _animatedMemos = filtered;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final state = _listKey.currentState;
        if (state == null) return;
        for (var i = 0; i < insertCount; i++) {
          state.insertItem(insertStart + i, duration: Duration.zero);
        }
        _logPaginationDebug(
          'animated_list_append_applied',
          metrics: _scrollController.hasClients
              ? _scrollController.position
              : null,
          context: {
            'signature': signature,
            'insertCount': insertCount,
            'currentLength': _animatedMemos.length,
          },
        );
      });
      return;
    }

    final signatureChanged = _listSignature != signature;
    final listChanged = !_sameMemoList(_animatedMemos, filtered);
    if (signatureChanged || listChanged) {
      final beforeLength = _animatedMemos.length;
      final afterLength = filtered.length;
      if (afterLength < beforeLength) {
        _logVisibleCountDecrease(
          beforeLength: beforeLength,
          afterLength: afterLength,
          signatureChanged: signatureChanged,
          listChanged: listChanged,
          fromSignature: _listSignature,
          toSignature: signature,
          removedSample: _collectRemovedMemoUids(
            _animatedMemos,
            filtered,
            limit: 8,
          ),
        );
      }
      _logPaginationDebug(
        'animated_list_rebuild',
        metrics: _scrollController.hasClients
            ? _scrollController.position
            : null,
        context: {
          'signatureChanged': signatureChanged,
          'listChanged': listChanged,
          'fromSignature': _listSignature,
          'toSignature': signature,
          'beforeLength': beforeLength,
          'afterLength': afterLength,
        },
      );
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

  static List<String> _collectRemovedMemoUids(
    List<LocalMemo> before,
    List<LocalMemo> after, {
    int limit = 8,
  }) {
    if (before.isEmpty || limit <= 0) return const <String>[];
    final afterUids = after.map((memo) => memo.uid).toSet();
    final removed = <String>[];
    for (final memo in before) {
      if (afterUids.contains(memo.uid)) continue;
      removed.add(memo.uid);
      if (removed.length >= limit) break;
    }
    return removed;
  }

  static bool _sameMemoPrefix(List<LocalMemo> prefix, List<LocalMemo> full) {
    if (prefix.length > full.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i].uid != full[i].uid) return false;
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
    Widget memoCard = _buildMemoCard(
      context,
      memo,
      prefs: prefs,
      outboxStatus: outboxStatus,
      removing: removing,
    );
    if (Platform.isWindows) {
      memoCard = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kMemoFlowDesktopMemoCardMaxWidth,
          ),
          child: memoCard,
        ),
      );
    }
    return SizeTransition(
      sizeFactor: curved,
      axis: Axis.vertical,
      axisAlignment: 0.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: memoCard,
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
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final imageEntries = collectMemoImageEntries(
      content: memo.content,
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    final videoEntries = collectMemoVideoEntries(
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    final mediaEntries = buildMemoMediaEntries(
      images: imageEntries,
      videos: videoEntries,
    );
    final hapticsEnabled = prefs.hapticsEnabled;
    final locationProvider = ref.watch(
      locationSettingsProvider.select((value) => value.provider),
    );

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
    final inSearchContext =
        _searching ||
        _windowsHeaderSearchExpanded ||
        _searchController.text.trim().isNotEmpty ||
        _selectedQuickSearchKind != null;
    final highlightQuery = _searchController.text.trim();

    return _MemoCard(
      key: ValueKey(memo.uid),
      memo: memo,
      dateText: _dateFmt.format(displayTime),
      reminderText: reminderText,
      initiallyExpanded: inSearchContext,
      highlightQuery: highlightQuery.isEmpty ? null : highlightQuery,
      collapseLongContent: prefs.collapseLongContent,
      collapseReferences: prefs.collapseReferences,
      isAudioPlaying: removing ? false : isAudioPlaying,
      isAudioLoading: removing ? false : isAudioLoading,
      audioPositionListenable: removing ? null : audioPositionListenable,
      audioDurationListenable: removing ? null : audioDurationListenable,
      imageEntries: imageEntries,
      mediaEntries: mediaEntries,
      locationProvider: locationProvider,
      onAudioSeek: removing || !isAudioActive
          ? null
          : (pos) => _seekAudioPosition(memo, pos),
      onAudioTap: removing ? null : () => _toggleAudioPlayback(memo),
      syncStatus: syncStatus,
      onSyncStatusTap: syncStatus == _MemoSyncStatus.none
          ? null
          : () => unawaited(_handleMemoSyncStatusTap(syncStatus, memo.uid)),
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
    final selectedQuickSearchKind = _selectedQuickSearchKind;
    final resolvedTag = _activeTagFilter;
    final useQuickSearch =
        !useShortcutFilter && selectedQuickSearchKind != null;
    final useRemoteSearch =
        !useShortcutFilter && !useQuickSearch && searchQuery.trim().isNotEmpty;
    final quickSearchQuery = selectedQuickSearchKind == null
        ? null
        : (
            kind: selectedQuickSearchKind,
            searchQuery: searchQuery,
            state: widget.state,
            tag: resolvedTag,
            startTimeSec: startTimeSec,
            endTimeSecExclusive: endTimeSecExclusive,
            pageSize: _pageSize,
          );
    final queryKey =
        '${widget.state}|${resolvedTag ?? ''}|${searchQuery.trim()}|${shortcutFilter.trim()}|'
        '${startTimeSec ?? ''}|${endTimeSecExclusive ?? ''}|${useShortcutFilter ? 1 : 0}|'
        '${selectedQuickSearchKind?.name ?? ''}|${useQuickSearch ? 1 : 0}|'
        '${useRemoteSearch ? 1 : 0}';
    if (_paginationKey != queryKey) {
      final previousVisibleCount = _currentResultCount;
      if (previousVisibleCount > 0 && _paginationKey.isNotEmpty) {
        ref
            .read(logManagerProvider)
            .info(
              'Memos pagination: query_changed_reset_results',
              context: <String, Object?>{
                'visibleCountBeforeReset': previousVisibleCount,
                'fromKey': _paginationKey,
                'toKey': queryKey,
              },
            );
      }
      _logPaginationDebug(
        'query_key_changed_reset_pagination',
        context: {'fromKey': _paginationKey, 'toKey': queryKey},
      );
      _paginationKey = queryKey;
      _pageSize = _initialPageSize;
      _reachedEnd = false;
      _loadingMore = false;
      _lastResultCount = 0;
      _resetMobilePullLoadState(notify: false);
      _lastDesktopWheelLoadAt = null;
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
        : useQuickSearch
        ? ref.watch(quickSearchMemosProvider(quickSearchQuery!))
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
    final syncState = ref.watch(syncCoordinatorProvider).memos;
    final syncQueueSnapshot = ref
        .watch(syncQueueProgressTrackerProvider)
        .snapshot;
    final outboxStatus =
        ref.watch(_outboxMemoStatusProvider).valueOrNull ??
        const _OutboxMemoStatus.empty();
    final searchHistory = ref.watch(searchHistoryProvider);
    final tagStats =
        ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final templateSettings = ref.watch(memoTemplateSettingsProvider);
    final availableTemplates = templateSettings.enabled
        ? templateSettings.templates
        : const <MemoTemplate>[];
    final recommendedTags = [...tagStats]
      ..sort((a, b) => b.count.compareTo(a.count));
    final showSearchLanding =
        _searching && searchQuery.trim().isEmpty && !useQuickSearch;
    final memosValue = memosAsync.valueOrNull;
    final memosLoading = memosAsync.isLoading;
    final memosError = memosAsync.whenOrNull(error: (e, _) => e);
    final normalMemoCount =
        ref.watch(_normalMemoCountProvider).valueOrNull ?? 0;
    final bootstrapImportedCount = _bootstrapImportTotal > 0
        ? normalMemoCount.clamp(0, _bootstrapImportTotal).toInt()
        : normalMemoCount;
    final bootstrapElapsed = _bootstrapImportStartedAt == null
        ? null
        : DateTime.now().difference(_bootstrapImportStartedAt!);
    final enableHomeSort = _shouldEnableHomeSort(
      useRemoteSearch: useRemoteSearch,
    );
    final hasProviderValue = memosValue != null;

    _currentResultCount = hasProviderValue
        ? memosValue.length
        : _animatedMemos.length;
    _currentLoading = memosLoading;
    _currentShowSearchLanding = showSearchLanding;
    if (hasProviderValue && _currentResultCount != _lastResultCount) {
      final previousCount = _lastResultCount;
      final wasLoadingMore = _loadingMore;
      final requestId = _activeLoadMoreRequestId;
      final requestSource = _activeLoadMoreSource;
      _lastResultCount = _currentResultCount;
      _loadingMore = false;
      if (wasLoadingMore) {
        _logPaginationDebug(
          'load_more_applied',
          metrics: _scrollController.hasClients
              ? _scrollController.position
              : null,
          context: {
            'requestId': requestId,
            'source': requestSource,
            'previousCount': previousCount,
            'nextCount': _currentResultCount,
            'delta': _currentResultCount - previousCount,
          },
        );
        _activeLoadMoreRequestId = null;
        _activeLoadMoreSource = null;
      }
    }
    if (hasProviderValue) {
      _reachedEnd = _currentResultCount < _pageSize;
    }

    _maybeAutoScanLocalLibrary(
      memosLoading: memosLoading,
      memosValue: memosValue,
      useRemoteSearch: useRemoteSearch,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
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
          '${useShortcutFilter ? 1 : 0}|${selectedQuickSearchKind?.name ?? ''}|'
          '${useQuickSearch ? 1 : 0}|${startTimeSec ?? ''}|${endTimeSecExclusive ?? ''}|'
          '${enableHomeSort ? _sortOption.name : 'default'}';
      _syncAnimatedMemos(sortedMemos, listSignature);
    }
    final visibleMemos = _animatedMemos;
    _maybeLogMemosLoadingPhase(
      queryKey: queryKey,
      memosLoading: memosLoading,
      memosError: memosError,
      memosValue: memosValue,
      visibleMemos: visibleMemos,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      useRemoteSearch: useRemoteSearch,
      shortcutFilter: shortcutFilter,
      quickSearchKind: selectedQuickSearchKind,
      syncState: syncState,
      syncQueueSnapshot: syncQueueSnapshot,
    );
    _maybeLogEmptyViewDiagnostics(
      queryKey: queryKey,
      memosValue: memosValue,
      memosLoading: memosLoading,
      memosError: memosError,
      visibleMemos: visibleMemos,
      searchQuery: searchQuery,
      resolvedTag: resolvedTag,
      useShortcutFilter: useShortcutFilter,
      useQuickSearch: useQuickSearch,
      useRemoteSearch: useRemoteSearch,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      shortcutFilter: shortcutFilter,
      quickSearchKind: selectedQuickSearchKind,
    );
    final showLoadMoreHint =
        memosError == null && visibleMemos.isNotEmpty && !showSearchLanding;
    final loadMoreBusy = _loadingMore || _currentLoading;
    final touchPullLoadEnabled = _isTouchPullLoadPlatform();
    final loadMoreHintText = loadMoreBusy
        ? context.t.strings.legacy.msg_loading
        : (_reachedEnd
              ? context.t.strings.legacy.msg_loaded_all_content
              : (touchPullLoadEnabled
                    ? (_mobileBottomPullArmed
                          ? context.t.strings.legacy.msg_release_to_load_more
                          : context.t.strings.legacy.msg_pull_up_to_load_more)
                    : context.t.strings.legacy.msg_scroll_down_to_load_more));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loadMoreHintTextColor =
        (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight)
            .withValues(alpha: isDark ? 0.52 : 0.46);
    final loadMoreHintDisplayText = '—— $loadMoreHintText ——';
    final headerBg =
        (isDark
                ? MemoFlowPalette.backgroundDark
                : MemoFlowPalette.backgroundLight)
            .withValues(alpha: 0.9);
    final showHeaderPillActions =
        widget.showPillActions && widget.state == 'NORMAL';
    final listTopPadding = showHeaderPillActions ? 0.0 : 16.0;
    final listVisualOffset = showHeaderPillActions ? 6.0 : 0.0;
    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    final screenshotModeEnabled = kDebugMode
        ? ref.watch(debugScreenshotModeProvider)
        : false;
    final session = ref.watch(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    final apiVersionResolution = account == null
        ? null
        : MemosServerApiProfiles.resolve(
            manualVersionOverride: account.serverVersionOverride,
            detectedVersion: account.instanceProfile.version,
          );
    final debugApiVersionText = _buildDebugApiVersionText(apiVersionResolution);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;
    final supportsDesktopSidePane =
        widget.showDrawer && shouldUseDesktopSidePaneLayout(screenWidth);
    final useDesktopSidePane = supportsDesktopSidePane;
    final useInlineCompose =
        widget.enableCompose &&
        !_searching &&
        shouldUseInlineComposeLayout(screenWidth);
    final useWindowsDesktopHeader = Platform.isWindows;
    final drawerPanel = widget.showDrawer
        ? AppDrawer(
            selected: widget.state == 'ARCHIVED'
                ? AppDrawerDestination.archived
                : AppDrawerDestination.memos,
            onSelect: _navigateDrawer,
            onSelectTag: _openTagFromDrawer,
            onOpenNotifications: _openNotifications,
            embedded: useDesktopSidePane,
          )
        : null;
    final showComposeFab =
        widget.enableCompose && !_searching && !useInlineCompose;
    final backToTopBaseOffset = showComposeFab ? 104.0 : 24.0;
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
        drawer: useDesktopSidePane ? null : drawerPanel,
        drawerEnableOpenDragGesture:
            !useDesktopSidePane && widget.showDrawer && !_searching,
        drawerEdgeDragWidth:
            !useDesktopSidePane && widget.showDrawer && !_searching
            ? screenWidth
            : null,
        body: (() {
          final memoListBody = Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  final scanner = ref.read(localLibraryScannerProvider);
                  final coordinator = ref.read(
                    syncCoordinatorProvider.notifier,
                  );
                  if (ref.read(syncCoordinatorProvider).memos.running) {
                    if (context.mounted) {
                      showTopToast(
                        context,
                        context.t.strings.legacy.msg_syncing,
                      );
                    }
                    final deadline = DateTime.now().add(
                      const Duration(seconds: 45),
                    );
                    while (context.mounted &&
                        ref.read(syncCoordinatorProvider).memos.running &&
                        DateTime.now().isBefore(deadline)) {
                      await Future<void>.delayed(
                        const Duration(milliseconds: 180),
                      );
                    }
                    if (!context.mounted) return;
                    final inFlightStatus =
                        ref.read(syncCoordinatorProvider).memos;
                    if (!inFlightStatus.running) {
                      final language = ref.read(
                        appPreferencesProvider.select((p) => p.language),
                      );
                      showSyncFeedback(
                        overlayContext: context,
                        messengerContext: context,
                        language: language,
                        succeeded: inFlightStatus.lastError == null,
                      );
                    }
                    return;
                  }
                  if (scanner != null) {
                    try {
                      await scanner.scanAndMergeIncremental(forceDisk: false);
                      _autoScanTriggered = true;
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t.strings.legacy.msg_scan_failed(e: e),
                          ),
                        ),
                      );
                    }
                  }
                  if (!context.mounted) return;
                  final syncResult = await coordinator.requestSync(
                    const SyncRequest(
                      kind: SyncRequestKind.memos,
                      reason: SyncRequestReason.manual,
                    ),
                  );
                  if (!context.mounted) return;
                  if (syncResult is SyncRunQueued) return;
                  final syncStatus = ref.read(syncCoordinatorProvider).memos;
                  if (syncStatus.running) return;
                  final language = ref.read(
                    appPreferencesProvider.select((p) => p.language),
                  );
                  showSyncFeedback(
                    overlayContext: context,
                    messengerContext: context,
                    language: language,
                    succeeded: syncStatus.lastError == null,
                  );
                  if (useShortcutFilter) {
                    ref.invalidate(shortcutMemosProvider(shortcutQuery));
                  } else if (useQuickSearch && quickSearchQuery != null) {
                    ref.invalidate(quickSearchMemosProvider(quickSearchQuery));
                  }
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleLoadMoreScrollNotification,
                  child: Listener(
                    onPointerSignal: _handleDesktopPointerSignal,
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
                          toolbarHeight: useWindowsDesktopHeader && !_searching
                              ? 0
                              : kToolbarHeight,
                          titleSpacing: useWindowsDesktopHeader && !_searching
                              ? 0
                              : NavigationToolbar.kMiddleSpacing,
                          automaticallyImplyLeading:
                              !useWindowsDesktopHeader && !_searching,
                          leading: useWindowsDesktopHeader
                              ? null
                              : (_searching
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back_ios_new,
                                        ),
                                        onPressed: _closeSearch,
                                      )
                                    : null),
                          title: useWindowsDesktopHeader && !_searching
                              ? null
                              : (_searching
                                    ? _buildTopSearchField(
                                        context,
                                        isDark: isDark,
                                        autofocus: true,
                                      )
                                    : _buildHeaderTitleWidget(
                                        context,
                                        maybeHaptic: maybeHaptic,
                                      )),
                          actions: useWindowsDesktopHeader && !_searching
                              ? null
                              : [
                                  if (kDebugMode && !screenshotModeEnabled)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 150,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MemoFlowPalette.primary
                                                  .withValues(
                                                    alpha: isDark ? 0.24 : 0.12,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: MemoFlowPalette.primary
                                                    .withValues(
                                                      alpha: isDark
                                                          ? 0.45
                                                          : 0.25,
                                                    ),
                                              ),
                                            ),
                                            child: Text(
                                              debugApiVersionText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: MemoFlowPalette.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ...?_searching
                                      ? (widget.enableSearch
                                            ? [
                                                TextButton(
                                                  onPressed: _closeSearch,
                                                  child: Text(
                                                    context
                                                        .t
                                                        .strings
                                                        .legacy
                                                        .msg_cancel_2,
                                                    style: TextStyle(
                                                      color: MemoFlowPalette
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                if (!useWindowsDesktopHeader)
                                                  IconButton(
                                                    tooltip: context
                                                        .t
                                                        .strings
                                                        .legacy
                                                        .msg_search,
                                                    onPressed: _openSearch,
                                                    icon: const Icon(
                                                      Icons.search,
                                                    ),
                                                  ),
                                              ]
                                            : null),
                                ],
                          bottom: useWindowsDesktopHeader && !_searching
                              ? null
                              : _searching
                              ? (useShortcutFilter
                                    ? null
                                    : PreferredSize(
                                        preferredSize: const Size.fromHeight(
                                          46,
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              8,
                                            ),
                                            child: _SearchQuickFilterBar(
                                              selectedKind:
                                                  _selectedQuickSearchKind,
                                              onSelectKind:
                                                  _toggleQuickSearchKind,
                                            ),
                                          ),
                                        ),
                                      ))
                              : (showHeaderPillActions
                                    ? PreferredSize(
                                        preferredSize: const Size.fromHeight(
                                          46,
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              0,
                                            ),
                                            child: _buildPillActionsRow(
                                              context,
                                              maybeHaptic: maybeHaptic,
                                            ),
                                          ),
                                        ),
                                      )
                                    : (widget.showFilterTagChip &&
                                              (resolvedTag?.trim().isNotEmpty ??
                                                  false)
                                          ? PreferredSize(
                                              preferredSize:
                                                  const Size.fromHeight(48),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      0,
                                                      16,
                                                      10,
                                                    ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: _FilterTagChip(
                                                    label:
                                                        '#${resolvedTag!.trim()}',
                                                    onClear:
                                                        widget.showTagFilters
                                                        ? () =>
                                                              _selectTagFilter(
                                                                null,
                                                              )
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
                        if (useInlineCompose)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: _buildInlineComposeCard(
                                isDark: isDark,
                                tagStats: tagStats,
                                availableTemplates: availableTemplates,
                              ),
                            ),
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
                        if (memosLoading && visibleMemos.isNotEmpty)
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
                                context.t.strings.legacy.msg_failed_load_3(
                                  memosError: memosError,
                                ),
                              ),
                            ),
                          )
                        else if (showSearchLanding)
                          SliverToBoxAdapter(
                            child: _SearchLanding(
                              history: searchHistory,
                              onClearHistory: () => ref
                                  .read(searchHistoryProvider.notifier)
                                  .clear(),
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
                        else if (memosLoading && visibleMemos.isEmpty)
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
                                      ? context
                                            .t
                                            .strings
                                            .legacy
                                            .msg_no_results_found
                                      : context
                                            .t
                                            .strings
                                            .legacy
                                            .msg_no_content_yet,
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
                              showLoadMoreHint ? 20 : 140,
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
                        if (showLoadMoreHint)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                140,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      loadMoreHintDisplayText,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                            color: loadMoreHintTextColor,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
              if (_bootstrapImportActive)
                Positioned.fill(
                  child: _buildBootstrapImportOverlay(
                    context,
                    isDark: isDark,
                    importedCount: bootstrapImportedCount,
                    totalCount: _bootstrapImportTotal,
                    elapsed: bootstrapElapsed,
                  ),
                ),
            ],
          );
          final bodyContent = () {
            if (!useDesktopSidePane || drawerPanel == null) {
              return memoListBody;
            }
            final dividerColor = isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08);
            final desktopContent = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kMemoFlowDesktopContentMaxWidth,
                  ),
                  child: memoListBody,
                ),
              ),
            );
            return Row(
              children: [
                SizedBox(
                  width: kMemoFlowDesktopDrawerWidth,
                  child: drawerPanel,
                ),
                VerticalDivider(width: 1, thickness: 1, color: dividerColor),
                Expanded(child: desktopContent),
              ],
            );
          }();
          if (useWindowsDesktopHeader && !_searching) {
            return Column(
              children: [
                _buildWindowsDesktopTitleBar(
                  context,
                  isDark: isDark,
                  enableHomeSort: enableHomeSort,
                  showPillActions: showHeaderPillActions,
                  maybeHaptic: maybeHaptic,
                  screenshotModeEnabled: screenshotModeEnabled,
                  debugApiVersionText: debugApiVersionText,
                ),
                Expanded(child: bodyContent),
              ],
            );
          }
          return bodyContent;
        })(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: showComposeFab
            ? _MemoFlowFab(
                onPressed: _openNoteInput,
                hapticsEnabled: hapticsEnabled,
              )
            : null,
      ),
    );
  }
}

class _InlinePendingAttachment {
  const _InlinePendingAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}

class _InlineLinkedMemo {
  const _InlineLinkedMemo({required this.name, required this.label});

  final String name;
  final String label;

  Map<String, dynamic> toRelationJson() {
    return {
      'relatedMemo': {'name': name},
      'type': 'REFERENCE',
    };
  }
}

class _DesktopWindowIconButton extends StatelessWidget {
  const _DesktopWindowIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.destructive = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = destructive
        ? (isDark ? const Color(0xFFFFB4B4) : const Color(0xFFC62828))
        : (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight);
    final hoverColor = destructive
        ? const Color(0x33E53935)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: hoverColor,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 30,
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
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

    return FittedBox(
      fit: BoxFit.scaleDown,
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
    final api = ref.watch(memosApiProvider);
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
    final useLocalShortcuts =
        api.usesLegacySearchFilterDialect ||
        api.shortcutsSupportedHint == false;
    final canCreateShortcut =
        useLocalShortcuts || api.shortcutsSupportedHint != false;
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

          if (canCreateShortcut) {
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
          }
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
          if (canCreateShortcut) {
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
          }
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
          if (canCreateShortcut) {
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
          }
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 240.0;
                return SingleChildScrollView(
                  primary: false,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: items,
                    ),
                  ),
                );
              },
            ),
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
  static const _historyListMaxHeight = 220.0;

  final ScrollController _historyScrollController = ScrollController();
  bool _showAllTags = false;

  @override
  void dispose() {
    _historyScrollController.dispose();
    super.dispose();
  }

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
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _historyListMaxHeight,
              ),
              child: Scrollbar(
                controller: _historyScrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _historyScrollController,
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: widget.history.length,
                  itemBuilder: (context, index) {
                    final item = widget.history[index];
                    return InkWell(
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
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
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

class _SearchQuickFilterBar extends StatelessWidget {
  const _SearchQuickFilterBar({
    required this.selectedKind,
    required this.onSelectKind,
  });

  final QuickSearchKind? selectedKind;
  final ValueChanged<QuickSearchKind> onSelectKind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.64);
    final accent = MemoFlowPalette.primary;
    final chipBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final selectedBg = accent.withValues(alpha: isDark ? 0.22 : 0.14);
    final selectedBorder = accent.withValues(alpha: isDark ? 0.58 : 0.48);
    final items = <({QuickSearchKind kind, IconData icon, String label})>[
      (
        kind: QuickSearchKind.attachments,
        icon: Icons.attachment_outlined,
        label: context.t.strings.legacy.msg_attachments,
      ),
      (
        kind: QuickSearchKind.links,
        icon: Icons.link_outlined,
        label: trByLanguage(
          language: context.appLanguage,
          zh: '链接',
          en: 'Links',
        ),
      ),
      (
        kind: QuickSearchKind.voice,
        icon: Icons.keyboard_voice_outlined,
        label: context.t.strings.legacy.msg_voice_memos,
      ),
      (
        kind: QuickSearchKind.onThisDay,
        icon: Icons.history_edu_outlined,
        label: trByLanguage(
          language: context.appLanguage,
          zh: '那年今日',
          en: 'On This Day',
        ),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildQuickChip(
              item: items[i],
              selected: selectedKind == items[i].kind,
              textMuted: textMuted,
              accent: accent,
              chipBg: chipBg,
              border: border,
              selectedBg: selectedBg,
              selectedBorder: selectedBorder,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required ({QuickSearchKind kind, IconData icon, String label}) item,
    required bool selected,
    required Color textMuted,
    required Color accent,
    required Color chipBg,
    required Color border,
    required Color selectedBg,
    required Color selectedBorder,
  }) {
    final bg = selected ? selectedBg : chipBg;
    final chipBorder = selected ? selectedBorder : border;
    final textColor = selected ? accent : textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onSelectKind(item.kind),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
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

enum _MemoCardAction {
  togglePinned,
  edit,
  history,
  reminder,
  archive,
  restore,
  delete,
}

class _MemoCard extends StatefulWidget {
  const _MemoCard({
    super.key,
    required this.memo,
    required this.dateText,
    required this.reminderText,
    required this.initiallyExpanded,
    required this.highlightQuery,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.isAudioPlaying,
    required this.isAudioLoading,
    required this.audioPositionListenable,
    required this.audioDurationListenable,
    required this.imageEntries,
    required this.mediaEntries,
    required this.locationProvider,
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
  final bool initiallyExpanded;
  final String? highlightQuery;
  final bool collapseLongContent;
  final bool collapseReferences;
  final bool isAudioPlaying;
  final bool isAudioLoading;
  final ValueListenable<Duration>? audioPositionListenable;
  final ValueListenable<Duration?>? audioDurationListenable;
  final List<MemoImageEntry> imageEntries;
  final List<MemoMediaEntry> mediaEntries;
  final LocationServiceProvider locationProvider;
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
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

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
      _expanded = widget.initiallyExpanded;
      return;
    }
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
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
    final normalizedHighlightQuery = widget.highlightQuery?.trim();
    final highlightQuery =
        normalizedHighlightQuery == null || normalizedHighlightQuery.isEmpty
        ? null
        : normalizedHighlightQuery;
    final highlightKey = highlightQuery?.toLowerCase() ?? '';
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
    final markdownCacheKey = '$cacheKey|md|searchhl=v2|hl=$highlightKey';
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
        preserveSquareTilesWhenHeightLimited: Platform.isWindows,
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
              highlightQuery: highlightQuery,
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
                            onTap: () => openMemoLocation(
                              context,
                              memo.location!,
                              memoUid: memo.uid,
                              provider: widget.locationProvider,
                            ),
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
                                            value: _MemoCardAction.history,
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .settings
                                                  .preferences
                                                  .history,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.restore,
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_restore,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.delete,
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_delete,
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
                                                  ? context
                                                        .t
                                                        .strings
                                                        .legacy
                                                        .msg_unpin
                                                  : context
                                                        .t
                                                        .strings
                                                        .legacy
                                                        .msg_pin,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.edit,
                                            child: Text(
                                              context.t.strings.legacy.msg_edit,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.history,
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .settings
                                                  .preferences
                                                  .history,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.reminder,
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_reminder,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: _MemoCardAction.archive,
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_archive,
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: _MemoCardAction.delete,
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_delete,
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
    final linePattern = RegExp(r'^[-*+•]?\s*', unicode: true);
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
              content: Text(context.t.strings.legacy.msg_failed_load_4(e: e)),
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
          content: Text(context.t.strings.legacy.msg_memo_not_found_locally),
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
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_TaskProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final targetValue = widget.progress.clamp(0.0, 1.0);
      final currentValue = _animation.value;
      final difference = (targetValue - currentValue).abs();

      // 鏍规嵁杩涘害宸窛璋冩暣鍔ㄧ敾鏃堕暱锛氬樊璺濊秺澶э紝鍔ㄧ敾鏃堕棿瓒婇暱
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
