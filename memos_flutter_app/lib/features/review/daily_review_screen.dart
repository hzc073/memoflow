import 'dart:math' as math;

import 'dart:async';
import 'dart:io';

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/attachment_toast.dart';
import '../../core/desktop_window_controls.dart';
import '../../core/drawer_navigation.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/tag_colors.dart';
import '../../core/tags.dart';
import '../../core/url.dart';
import '../../data/ai/ai_analysis_models.dart';
import '../../data/models/attachment.dart';
import '../../data/models/home_navigation_preferences.dart';
import '../../data/models/local_library.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/user.dart';
import '../../state/memos/memo_mutation_service.dart';
import '../../state/system/session_provider.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/review/ai_analysis_provider.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_menu_button.dart';
import '../home/home_navigation_host.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memo_image_grid.dart';
import '../memos/memo_location_line.dart';
import '../memos/memo_markdown.dart';
import '../memos/memo_video_grid.dart';
import '../memos/memos_list_screen.dart';
import '../memos/recycle_bin_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../tags/tags_screen.dart';
import '../memos/widgets/audio_row.dart';
import 'ai_insight_history_shared.dart';
import 'random_walk_display.dart';
import 'ai_summary_screen.dart';
import 'random_walk_models.dart';
import 'random_walk_providers.dart';
import '../../i18n/strings.g.dart';

class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({
    super.key,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
  });

  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen> {
  static const double _collapsedFilterTagMaxHeight = 112;

  final _random = math.Random();
  final GlobalKey _deckSwipeExclusionKey = GlobalKey();
  ProviderSubscription<AsyncValue<List<RandomWalkDeckEntry>>>?
  _deckSubscription;
  List<RandomWalkDeckEntry> _deck = const [];
  List<String> _deckKeys = const [];
  List<String> _deckRevisionKeys = const [];
  final _creatorCache = <String, User>{};
  final _creatorFetching = <String>{};
  int _deckVersion = 0;
  int _cursor = 0;
  String? _activeQueryKey;
  String? _resolvedQueryKey;
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
  RandomWalkSourceScope _selectedSource = RandomWalkSourceScope.allMemos;
  Set<String> _selectedTags = <String>{};
  DateTimeRange? _selectedDateRange;
  late int _sampleSeed;

  @override
  void initState() {
    super.initState();
    _sampleSeed = _nextSampleSeed();
    _subscribeDeck();
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
    widget.embeddedNavigationHost?.clearGlobalSwipeExclusionRects(
      HomeRootDestination.dailyReview,
    );
    _deckSubscription?.close();
    _audioStateSub?.cancel();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioProgressTimer?.cancel();
    _audioPositionNotifier.dispose();
    _audioDurationNotifier.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _back() {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleBackToPrimaryDestination(context);
      return;
    }
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

  void _navigate(AppDrawerDestination dest) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerDestination(context, dest);
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

  void _openTag(String tag) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerTag(context, tag);
      return;
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

  void _openNotifications() {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleOpenNotifications(context);
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  int _nextSampleSeed() => _random.nextInt(0x3fffffff);

  RandomWalkQuery get _deckQuery {
    final sortedTags = _selectedTags.toList(growable: false)..sort();
    final range = _selectedDateRange;
    final startSec = range == null
        ? null
        : DateTime(
                range.start.year,
                range.start.month,
                range.start.day,
              ).toUtc().millisecondsSinceEpoch ~/
              1000;
    final endSec = range == null
        ? null
        : DateTime(
                range.end.year,
                range.end.month,
                range.end.day,
              ).add(const Duration(days: 1)).toUtc().millisecondsSinceEpoch ~/
              1000;
    return RandomWalkQuery(
      source: _selectedSource,
      selectedTagKeys: sortedTags,
      dateStartSec: startSec,
      dateEndSecExclusive: endSec,
      sampleLimit: randomWalkSampleLimit,
      sampleSeed: _sampleSeed,
    );
  }

  String _queryKeyFor(RandomWalkQuery query) {
    return [
      query.source.name,
      query.selectedTagKeys.join(','),
      query.dateStartSec?.toString() ?? '',
      query.dateEndSecExclusive?.toString() ?? '',
      query.sampleSeed.toString(),
    ].join('|');
  }

  void _subscribeDeck() {
    final query = _deckQuery;
    _activeQueryKey = _queryKeyFor(query);
    _deckSubscription?.close();
    _deckSubscription = ref.listenManual(randomWalkDeckProvider(query), (
      prev,
      next,
    ) {
      next.whenData((entries) {
        _resolvedQueryKey = _activeQueryKey;
        unawaited(
          _prefetchCreatorsByName(
            entries
                .map((entry) => entry.creatorRef?.trim() ?? '')
                .where((name) => name.isNotEmpty),
          ),
        );
        final changed = _syncDeck(entries);
        if (!changed || !mounted) return;
        setState(() {});
      });
    }, fireImmediately: true);
  }

  Future<void> _prefetchCreatorsByName(Iterable<String> names) async {
    final api = ref.read(memosApiProvider);
    final pending = <String>[];
    for (final raw in names) {
      final creator = raw.trim();
      if (creator.isEmpty) continue;
      if (_creatorCache.containsKey(creator)) continue;
      if (_creatorFetching.contains(creator)) continue;
      _creatorFetching.add(creator);
      pending.add(creator);
    }
    if (pending.isEmpty) return;

    final updates = <String, User>{};
    for (final creator in pending) {
      try {
        final user = await api.getUser(name: creator);
        updates[creator] = user;
      } catch (_) {
      } finally {
        _creatorFetching.remove(creator);
      }
    }
    if (updates.isEmpty || !mounted) return;
    setState(() => _creatorCache.addAll(updates));
  }

  String _formatDateYmd(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }
    if (baseUrl == null) return trimmed;
    return joinBaseUrl(baseUrl, trimmed);
  }

  String _currentUserFallbackLabel(User? user, LocalLibrary? localLibrary) {
    final display = user?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = user?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final libraryName = localLibrary?.name.trim() ?? '';
    if (libraryName.isNotEmpty) return libraryName;
    return '?';
  }

  String _initialForLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '?';
    final rune = trimmed.runes.first;
    return String.fromCharCode(rune).toUpperCase();
  }

  Widget _buildHeaderAvatar({
    required String rawAvatarUrl,
    required Uri? baseUrl,
    required String fallback,
    required Color borderColor,
    required Color textColor,
    required bool isDark,
    double size = 80,
  }) {
    final resolvedUrl = _resolveAvatarUrl(rawAvatarUrl, baseUrl);
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final fallbackWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: borderColor, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _initialForLabel(fallback),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
    if (resolvedUrl.isEmpty) return fallbackWidget;
    if (resolvedUrl.startsWith('data:')) {
      final bytes = tryDecodeDataUri(resolvedUrl);
      if (bytes == null) return fallbackWidget;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallbackWidget,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: resolvedUrl,
        fit: BoxFit.cover,
        placeholder: (context, progress) => fallbackWidget,
        errorWidget: (context, url, error) => fallbackWidget,
      ),
    );
  }

  bool _sameDeckKeys(List<String> next) {
    if (_deckKeys.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (_deckKeys[i] != next[i]) return false;
    }
    return true;
  }

  bool _sameDeckRevisionKeys(List<String> next) {
    if (_deckRevisionKeys.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (_deckRevisionKeys[i] != next[i]) return false;
    }
    return true;
  }

  bool _syncDeck(List<RandomWalkDeckEntry> entries) {
    final keys = entries.map((entry) => entry.key).toList(growable: false);
    final revisions = entries
        .map((entry) => entry.revisionKey)
        .toList(growable: false);
    if (_sameDeckKeys(keys)) {
      if (_sameDeckRevisionKeys(revisions)) {
        return false;
      }
      _deck = entries;
      _deckRevisionKeys = revisions;
      return true;
    }

    _deckKeys = keys;
    _deckRevisionKeys = revisions;
    _deck = entries;
    _deckVersion += 1;
    _cursor = 0;
    return true;
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

    final tags = extractTags(updated);
    await ref
        .read(memoMutationServiceProvider)
        .updateMemoContentForTaskToggle(
          memo: memo,
          content: updated,
          updateTime: memo.updateTime,
          tags: tags,
        );
  }

  Future<void> _openAiHistoryEntry(AiSavedAnalysisHistoryEntry entry) async {
    final report = await ref
        .read(aiAnalysisRepositoryProvider)
        .loadAnalysisReportByTaskId(entry.taskId);
    if (!mounted) return;
    if (report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aiInsightHistoryOpenFailedText(context))),
      );
      return;
    }
    final descriptor = resolveAiInsightHistoryDescriptor(
      context,
      ref,
      entry.promptTemplate,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiSummaryScreen(
          initialHistorySelection: AiInsightHistorySelection(
            report: report,
            rangeStart: entry.rangeStart,
            rangeEndExclusive: entry.rangeEndExclusive,
            insightId: descriptor.insightId,
            titleOverride: descriptor.titleOverride,
          ),
        ),
      ),
    );
  }

  List<String> _availableTags(
    List<TagStat> tagStats,
    TagColorLookup tagColors,
  ) {
    final ordered = <String>[];
    final remaining = <String>{
      for (final stat in tagStats)
        if (tagColors.resolveCanonicalPath(stat.path).isNotEmpty)
          tagColors.resolveCanonicalPath(stat.path),
    };
    for (final stat in tagStats) {
      final path = tagColors.resolveCanonicalPath(stat.path);
      if (path.isEmpty || !remaining.remove(path)) continue;
      ordered.add(path);
    }

    final leftovers = remaining.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...ordered, ...leftovers];
  }

  bool get _sourceSupportsTagFilter =>
      _selectedSource != RandomWalkSourceScope.aiHistory;

  String _sourceLabel(RandomWalkSourceScope source, BuildContext context) {
    return switch (source) {
      RandomWalkSourceScope.allMemos =>
        context.t.strings.legacy.msg_random_review_source_all_notes,
      RandomWalkSourceScope.exploreMemos =>
        context.t.strings.legacy.msg_random_review_source_explore_notes,
      RandomWalkSourceScope.aiHistory =>
        context.t.strings.legacy.msg_random_review_source_ai_history,
    };
  }

  String _dateFilterLabel(BuildContext context, RandomWalkSourceScope source) {
    if (source == RandomWalkSourceScope.aiHistory) {
      return context.t.strings.legacy.msg_random_review_ai_history_date_range;
    }
    return context.t.strings.legacy.msg_select_date_range;
  }

  List<String> _sortTags(
    Iterable<String> tags,
    List<TagStat> tagStats,
    TagColorLookup tagColors,
  ) {
    final orderedPaths = _availableTags(tagStats, tagColors);
    final orderMap = <String, int>{
      for (var i = 0; i < orderedPaths.length; i++) orderedPaths[i]: i,
    };
    final sorted = tags.toList(growable: false);
    sorted.sort((a, b) {
      final canonicalA = tagColors.resolveCanonicalPath(a);
      final canonicalB = tagColors.resolveCanonicalPath(b);
      final rankA = orderMap[canonicalA] ?? 1 << 20;
      final rankB = orderMap[canonicalB] ?? 1 << 20;
      if (rankA != rankB) return rankA.compareTo(rankB);
      return canonicalA.compareTo(canonicalB);
    });
    return sorted;
  }

  String _normalizeTag(String raw) {
    return normalizeTagPath(raw);
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
    required RandomWalkSourceScope source,
    required Set<String> tags,
    required DateTimeRange? dateRange,
  }) {
    final tagColors = ref.read(tagColorLookupProvider);
    final normalizedTags = tags
        .map(_normalizeTag)
        .map(tagColors.resolveCanonicalPath)
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final normalizedRange = dateRange == null
        ? null
        : _normalizeRange(dateRange);
    _selectedSource = source;
    _selectedTags = normalizedTags;
    _selectedDateRange = normalizedRange;
    _sampleSeed = _nextSampleSeed();
    _subscribeDeck();
    unawaited(_stopAudioPlayback());
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openFilterSheet() async {
    final tagStats =
        ref.read(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final tagColors = ref.read(tagColorLookupProvider);
    final availableTags = _availableTags(tagStats, tagColors);
    var draftSource = _selectedSource;
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

    TagChipColors? resolveTagChipColors(String tag) {
      return tagColors.resolveChipColorsByPath(
        tag,
        surfaceColor: chipBg,
        isDark: isDark,
      );
    }

    Widget buildTagFilterChip(String tag, StateSetter setModalState) {
      final selected = draftTags.contains(tag);
      final colors = resolveTagChipColors(tag);
      final defaultSelectedColor = accent.withValues(
        alpha: isDark ? 0.24 : 0.15,
      );
      final defaultSelectedBorder = accent.withValues(
        alpha: isDark ? 0.62 : 0.55,
      );
      final softTagBackground = colors?.background.withValues(
        alpha: isDark ? 0.24 : 0.14,
      );
      final unselectedBackground = softTagBackground ?? chipBg;
      final selectedBackground = colors?.background ?? defaultSelectedColor;
      final visibleBackground = Color.alphaBlend(
        selected ? selectedBackground : unselectedBackground,
        sheetBg,
      );
      final labelColor = resolveReadableTextColor(visibleBackground);
      return FilterChip(
        label: Text('#$tag'),
        selected: selected,
        onSelected: (nextSelected) {
          setModalState(() {
            if (nextSelected) {
              draftTags.add(tag);
            } else {
              draftTags.remove(tag);
            }
          });
        },
        backgroundColor: unselectedBackground,
        selectedColor: selectedBackground,
        side: BorderSide(
          color: selected
              ? (colors?.border ?? defaultSelectedBorder)
              : (colors?.border.withValues(alpha: isDark ? 0.55 : 0.45) ??
                    border),
        ),
        labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w600),
        showCheckmark: false,
      );
    }

    Widget buildSourceChip(
      RandomWalkSourceScope source,
      StateSetter setModalState,
    ) {
      final selected = draftSource == source;
      return FilterChip(
        label: Text(_sourceLabel(source, context)),
        selected: selected,
        onSelected: (_) {
          setModalState(() {
            draftSource = source;
          });
        },
        backgroundColor: chipBg,
        selectedColor: accent.withValues(alpha: isDark ? 0.24 : 0.15),
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.62 : 0.55)
              : border,
        ),
        labelStyle: TextStyle(
          color: selected ? accent : textMain,
          fontWeight: FontWeight.w600,
        ),
        showCheckmark: false,
      );
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.56 : 0.4),
      builder: (dialogContext) {
        var tagsExpanded = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final screenSize = MediaQuery.sizeOf(context);
            final dialogHeight = math.min(screenSize.height * 0.78, 720.0);
            return Dialog(
              backgroundColor: sheetBg,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: border),
              ),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SizedBox(
                  width: math.min(screenSize.width - 48, 560),
                  height: dialogHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  draftSource = RandomWalkSourceScope.allMemos;
                                  draftTags = <String>{};
                                  draftRange = null;
                                  tagsExpanded = false;
                                });
                              },
                              child: Text(context.t.strings.legacy.msg_clear_2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final collapsedTagHeight = math.min(
                                math.max(
                                  _collapsedFilterTagMaxHeight,
                                  constraints.maxHeight * 0.34,
                                ),
                                168.0,
                              );
                              final showTagFilters =
                                  draftSource !=
                                  RandomWalkSourceScope.aiHistory;

                              Widget buildTagViewport() {
                                return Stack(
                                  children: [
                                    ClipRect(
                                      child: ScrollConfiguration(
                                        behavior: const MaterialScrollBehavior()
                                            .copyWith(scrollbars: false),
                                        child: SingleChildScrollView(
                                          physics: tagsExpanded
                                              ? const ClampingScrollPhysics()
                                              : const NeverScrollableScrollPhysics(),
                                          child: Align(
                                            alignment: Alignment.topLeft,
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                FilterChip(
                                                  label: Text(
                                                    context
                                                        .t
                                                        .strings
                                                        .legacy
                                                        .msg_all_2,
                                                  ),
                                                  selected: draftTags.isEmpty,
                                                  onSelected: (_) {
                                                    setModalState(() {
                                                      draftTags.clear();
                                                    });
                                                  },
                                                  backgroundColor: chipBg,
                                                  selectedColor: accent
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.24
                                                            : 0.15,
                                                      ),
                                                  side: BorderSide(
                                                    color: draftTags.isEmpty
                                                        ? accent.withValues(
                                                            alpha: isDark
                                                                ? 0.62
                                                                : 0.55,
                                                          )
                                                        : border,
                                                  ),
                                                  labelStyle: TextStyle(
                                                    color: draftTags.isEmpty
                                                        ? accent
                                                        : textMain,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  showCheckmark: false,
                                                ),
                                                for (final tag in availableTags)
                                                  buildTagFilterChip(
                                                    tag,
                                                    setModalState,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      height: 28,
                                      child: IgnorePointer(
                                        child: AnimatedOpacity(
                                          opacity: tagsExpanded ? 0 : 1,
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          curve: Curves.easeOut,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  sheetBg.withAlpha(0),
                                                  sheetBg,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context
                                        .t
                                        .strings
                                        .legacy
                                        .msg_random_review_source_scope,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      buildSourceChip(
                                        RandomWalkSourceScope.allMemos,
                                        setModalState,
                                      ),
                                      buildSourceChip(
                                        RandomWalkSourceScope.exploreMemos,
                                        setModalState,
                                      ),
                                      buildSourceChip(
                                        RandomWalkSourceScope.aiHistory,
                                        setModalState,
                                      ),
                                    ],
                                  ),
                                  if (showTagFilters) ...[
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            context
                                                .t
                                                .strings
                                                .legacy
                                                .msg_select_tags,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textMuted,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            setModalState(() {
                                              tagsExpanded = !tagsExpanded;
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          icon: AnimatedRotation(
                                            turns: tagsExpanded ? 0.5 : 0,
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            child: const Icon(
                                              Icons.expand_more_rounded,
                                              size: 18,
                                            ),
                                          ),
                                          label: Text(
                                            tagsExpanded
                                                ? context
                                                      .t
                                                      .strings
                                                      .legacy
                                                      .msg_collapse
                                                : context
                                                      .t
                                                      .strings
                                                      .legacy
                                                      .msg_expand,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (availableTags.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          context
                                              .t
                                              .strings
                                              .legacy
                                              .msg_no_tags_yet,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: textMuted,
                                          ),
                                        ),
                                      )
                                    else if (tagsExpanded)
                                      Expanded(child: buildTagViewport())
                                    else
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        height: collapsedTagHeight,
                                        child: buildTagViewport(),
                                      ),
                                  ],
                                  const SizedBox(height: 18),
                                  Text(
                                    _dateFilterLabel(context, draftSource),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      10,
                                      10,
                                    ),
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
                                            _formatRangeLabel(
                                              draftRange,
                                              context,
                                            ),
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
                                            final picked = await _pickDateRange(
                                              draftRange,
                                            );
                                            if (picked == null) return;
                                            setModalState(() {
                                              draftRange = _normalizeRange(
                                                picked,
                                              );
                                            });
                                          },
                                          child: Text(
                                            context.t.strings.legacy.msg_select,
                                          ),
                                        ),
                                        if (draftRange != null)
                                          TextButton(
                                            onPressed: () {
                                              setModalState(() {
                                                draftRange = null;
                                              });
                                            },
                                            child: Text(
                                              context
                                                  .t
                                                  .strings
                                                  .legacy
                                                  .msg_clear_2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
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
                                    source: draftSource,
                                    tags: draftTags,
                                    dateRange: draftRange,
                                  );
                                  Navigator.of(dialogContext).pop();
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
        _selectedSource != RandomWalkSourceScope.allMemos ||
        (_sourceSupportsTagFilter && _selectedTags.isNotEmpty) ||
        _selectedDateRange != null;
    final enableWindowsDragToMove =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final tagStats =
        ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final tagColors = ref.watch(tagColorLookupProvider);
    final selectedTags = _sourceSupportsTagFilter
        ? _sortTags(_selectedTags, tagStats, tagColors)
        : const <String>[];
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final currentUser = account?.user;
    final localLibrary = ref.watch(currentLocalLibraryProvider);
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

    final deckAsync = ref.watch(randomWalkDeckProvider(_deckQuery));
    final syncState = ref.watch(syncCoordinatorProvider);
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.dailyReview,
      onSelect: _navigate,
      onSelectTag: _openTag,
      onOpenNotifications: _openNotifications,
      embedded: useDesktopSidePane,
    );

    final shouldInterceptPop =
        widget.presentation != HomeScreenPresentation.embeddedBottomNav;

    return PopScope(
      canPop: !shouldInterceptPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !shouldInterceptPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: bg,
        drawer: useDesktopSidePane ? null : drawerPanel,
        drawerEnableOpenDragGesture:
            widget.presentation != HomeScreenPresentation.embeddedBottomNav,
        appBar: AppBar(
          backgroundColor: useDesktopSidePane ? bg : Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: !useDesktopSidePane,
          toolbarHeight: 46,
          iconTheme: IconThemeData(color: textMain),
          flexibleSpace: enableWindowsDragToMove
              ? const DragToMoveArea(child: SizedBox.expand())
              : null,
          leading: useDesktopSidePane
              ? null
              : widget.presentation ==
                    HomeScreenPresentation.embeddedBottomNav
              ? AppDrawerMenuButton(
                  tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                  iconColor: textMain,
                  badgeBorderColor: bg,
                )
              : IconButton(
                  tooltip: context.t.strings.legacy.msg_back,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _back,
                ),
          title: IgnorePointer(
            ignoring: enableWindowsDragToMove,
            child: Text(
              context.t.strings.legacy.msg_random_review,
              style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
            ),
          ),
          centerTitle: !useDesktopSidePane,
          actions: [
            IconButton(
              tooltip: context.t.strings.legacy.msg_filter,
              icon: Icon(
                Icons.tune_rounded,
                color: hasActiveFilter ? MemoFlowPalette.primary : null,
              ),
              onPressed: _openFilterSheet,
            ),
            if (enableWindowsDragToMove) const DesktopWindowControls(),
          ],
        ),
        body: () {
          final canUseCachedDeck =
              _activeQueryKey == _resolvedQueryKey && _deck.isNotEmpty;
          final showRefreshChip =
              canUseCachedDeck &&
              (deckAsync.isLoading ||
                  syncState.memos.running ||
                  syncState.localScan.running);

          Widget buildDeckBody(List<RandomWalkDeckEntry> entries) {
            if (entries.isEmpty) {
              return Center(
                child: Text(
                  context.t.strings.legacy.msg_no_content_yet,
                  style: TextStyle(color: textMuted),
                ),
              );
            }

            final deck = entries;
            final total = deck.length;
            final displayIndex = total == 0 ? 0 : (_cursor + 1).clamp(1, total);
            final canLoopCards = deck.length > 1;
            final backgroundCardCount = deck.length <= 2
                ? 0
                : math.min(3, deck.length - 2);
            final avatarBorderColor = isDark
                ? MemoFlowPalette.borderDark
                : MemoFlowPalette.borderLight;

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
                      if (showRefreshChip) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: MemoFlowPalette.primary.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.t.strings.legacy.msg_syncing_2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: MemoFlowPalette.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
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
                        if (_selectedSource != RandomWalkSourceScope.allMemos)
                          _ActiveFilterChip(
                            label: _sourceLabel(_selectedSource, context),
                            isDark: isDark,
                            surfaceColor: bg,
                          ),
                        for (final tag in selectedTags)
                          _ActiveFilterChip(
                            label: '#$tag',
                            isDark: isDark,
                            surfaceColor: bg,
                            colors: tagColors.resolveChipColorsByPath(
                              tag,
                              surfaceColor: card,
                              isDark: isDark,
                            ),
                          ),
                        if (_selectedDateRange != null)
                          _ActiveFilterChip(
                            label: _formatRangeLabel(
                              _selectedDateRange,
                              context,
                            ),
                            isDark: isDark,
                            surfaceColor: bg,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 140),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxCardWidth = useDesktopSidePane
                            ? math.min(
                                kMemoFlowDesktopMemoCardMaxWidth,
                                constraints.maxWidth,
                              )
                            : constraints.maxWidth;
                        return Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxCardWidth),
                            child: _HomeSwipeExclusionReporter(
                              key: _deckSwipeExclusionKey,
                              destination: HomeRootDestination.dailyReview,
                              navigationHost: widget.embeddedNavigationHost,
                              child: AppinioSwiper(
                                key: ValueKey(_deckVersion),
                                cardCount: deck.length,
                                backgroundCardCount: backgroundCardCount,
                                backgroundCardScale: 0.92,
                                backgroundCardOffset: const Offset(0, 24),
                                initialIndex: 0,
                                loop: canLoopCards,
                                isDisabled: !canLoopCards,
                                swipeOptions: const SwipeOptions.symmetric(
                                  horizontal: true,
                                ),
                                maxAngle: 14,
                                onSwipeEnd:
                                    (previousIndex, targetIndex, activity) {
                                      if (!mounted) return;
                                      unawaited(_stopAudioPlayback());
                                      setState(() {
                                        _cursor = deck.isEmpty
                                            ? 0
                                            : targetIndex % deck.length;
                                      });
                                    },
                                cardBuilder: (context, index) {
                                  final entry = deck[index];
                                  if (entry.isAiHistory) {
                                    final history = entry.historyEntry!;
                                    final createdAt =
                                        DateTime.fromMillisecondsSinceEpoch(
                                          history.createdTime,
                                          isUtc: true,
                                        ).toLocal();
                                    final headerPrimaryText =
                                        '${formatExactDaysAgo(exactDaysAgo(createdAt, DateTime.now()), context.appLanguage)} \u00B7 ${resolveDayPeriod(createdAt, context)}';
                                    final headerSecondaryText = _formatDateYmd(
                                      createdAt,
                                    );
                                    final headerAvatar = _buildHeaderAvatar(
                                      rawAvatarUrl:
                                          currentUser?.avatarUrl ?? '',
                                      baseUrl: baseUrl,
                                      fallback: _currentUserFallbackLabel(
                                        currentUser,
                                        localLibrary,
                                      ),
                                      borderColor: avatarBorderColor,
                                      textColor: textMain,
                                      isDark: isDark,
                                    );
                                    return KeyedSubtree(
                                      key: ValueKey(entry.key),
                                      child: RepaintBoundary(
                                        child: _RandomWalkAiHistoryCard(
                                          entry: history,
                                          bodyText:
                                              entry.fullBodyText
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? entry.fullBodyText!.trim()
                                              : history.summary.trim(),
                                          headerPrimaryText: headerPrimaryText,
                                          headerSecondaryText:
                                              headerSecondaryText,
                                          headerAvatar: headerAvatar,
                                          card: card,
                                          textMain: textMain,
                                          textMuted: textMuted,
                                          isDark: isDark,
                                          onTap: () => unawaited(
                                            _openAiHistoryEntry(history),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final memo = entry.memo!;
                                  final createdAt = memo.createTime;
                                  final headerPrimaryText =
                                      '${formatExactDaysAgo(exactDaysAgo(createdAt, DateTime.now()), context.appLanguage)} \u00B7 ${resolveDayPeriod(createdAt, context)}';
                                  final headerSecondaryText = _formatDateYmd(
                                    createdAt,
                                  );
                                  final creator =
                                      _creatorCache[entry.creatorRef?.trim() ??
                                          ''];
                                  final avatarFallback =
                                      entry.memoOrigin ==
                                          RandomWalkMemoOrigin.explore
                                      ? (creator?.displayName
                                                    .trim()
                                                    .isNotEmpty ==
                                                true
                                            ? creator!.displayName.trim()
                                            : creator?.username
                                                      .trim()
                                                      .isNotEmpty ==
                                                  true
                                            ? creator!.username.trim()
                                            : entry.creatorFallback)
                                      : _currentUserFallbackLabel(
                                          currentUser,
                                          localLibrary,
                                        );
                                  final avatarUrl =
                                      entry.memoOrigin ==
                                          RandomWalkMemoOrigin.explore
                                      ? creator?.avatarUrl ?? ''
                                      : currentUser?.avatarUrl ?? '';
                                  final headerAvatar = _buildHeaderAvatar(
                                    rawAvatarUrl: avatarUrl,
                                    baseUrl: baseUrl,
                                    fallback: avatarFallback,
                                    borderColor: avatarBorderColor,
                                    textColor: textMain,
                                    isDark: isDark,
                                  );
                                  final isAudioActive =
                                      _playingMemoUid == memo.uid;
                                  final canToggleTasks =
                                      entry.memoOrigin ==
                                      RandomWalkMemoOrigin.localAll;
                                  return KeyedSubtree(
                                    key: ValueKey(entry.key),
                                    child: RepaintBoundary(
                                      child: _RandomWalkCard(
                                        memo: memo,
                                        headerPrimaryText: headerPrimaryText,
                                        headerSecondaryText:
                                            headerSecondaryText,
                                        headerAvatar: headerAvatar,
                                        card: card,
                                        textMain: textMain,
                                        textMuted: textMuted,
                                        isDark: isDark,
                                        baseUrl: baseUrl,
                                        authHeader: authHeader,
                                        rebaseAbsoluteFileUrlForV024:
                                            rebaseAbsoluteFileUrlForV024,
                                        attachAuthForSameOriginAbsolute:
                                            attachAuthForSameOriginAbsolute,
                                        audioPlaying:
                                            isAudioActive &&
                                            _audioPlayer.playing,
                                        audioLoading:
                                            isAudioActive && _audioLoading,
                                        audioPositionListenable: isAudioActive
                                            ? _audioPositionNotifier
                                            : null,
                                        audioDurationListenable: isAudioActive
                                            ? _audioDurationNotifier
                                            : null,
                                        onAudioTap: () => unawaited(
                                          _toggleAudioPlayback(memo),
                                        ),
                                        onToggleTask: canToggleTasks
                                            ? (request) => unawaited(
                                                _toggleMemoCheckbox(
                                                  memo,
                                                  request.taskIndex,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 22),
              ],
            );
          }

          final pageBody = deckAsync.when(
            data: buildDeckBody,
            loading: () => canUseCachedDeck
                ? buildDeckBody(_deck)
                : const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              if (canUseCachedDeck) {
                return buildDeckBody(_deck);
              }
              final message = e is RandomWalkSignInRequiredException
                  ? context.t.strings.legacy.msg_not_signed
                  : context.t.strings.legacy.msg_failed_load_4(e: e);
              return Center(child: Text(message));
            },
          );
          if (!useDesktopSidePane) {
            return pageBody;
          }
          return Row(
            children: [
              SizedBox(width: kMemoFlowDesktopDrawerWidth, child: drawerPanel),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              Expanded(child: pageBody),
            ],
          );
        }(),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.isDark,
    required this.surfaceColor,
    this.colors,
  });

  final String label;
  final bool isDark;
  final Color surfaceColor;
  final TagChipColors? colors;

  @override
  Widget build(BuildContext context) {
    final accent = MemoFlowPalette.primary;
    final bg =
        colors?.background ?? accent.withValues(alpha: isDark ? 0.22 : 0.12);
    final borderColor =
        colors?.border ?? accent.withValues(alpha: isDark ? 0.6 : 0.5);
    final visibleBackground = Color.alphaBlend(bg, surfaceColor);
    final textColor = resolveReadableTextColor(visibleBackground);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _HomeSwipeExclusionReporter extends StatefulWidget {
  const _HomeSwipeExclusionReporter({
    super.key,
    required this.destination,
    required this.navigationHost,
    required this.child,
  });

  final HomeRootDestination destination;
  final HomeEmbeddedNavigationHost? navigationHost;
  final Widget child;

  @override
  State<_HomeSwipeExclusionReporter> createState() =>
      _HomeSwipeExclusionReporterState();
}

class _HomeSwipeExclusionReporterState
    extends State<_HomeSwipeExclusionReporter> {
  Rect? _lastReportedRect;

  @override
  void didUpdateWidget(covariant _HomeSwipeExclusionReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationHost != null &&
        oldWidget.navigationHost != widget.navigationHost) {
      oldWidget.navigationHost!.clearGlobalSwipeExclusionRects(
        oldWidget.destination,
      );
    }
  }

  @override
  void dispose() {
    widget.navigationHost?.clearGlobalSwipeExclusionRects(widget.destination);
    super.dispose();
  }

  void _reportRect() {
    if (!mounted) return;
    final host = widget.navigationHost;
    if (host == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
      host.clearGlobalSwipeExclusionRects(widget.destination);
      _lastReportedRect = null;
      return;
    }

    final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    if (_lastReportedRect == rect) return;
    _lastReportedRect = rect;
    host.updateGlobalSwipeExclusionRects(widget.destination, [rect]);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportRect());
    return widget.child;
  }
}

class _RandomWalkAiHistoryCard extends StatelessWidget {
  const _RandomWalkAiHistoryCard({
    required this.entry,
    required this.bodyText,
    required this.headerPrimaryText,
    required this.headerSecondaryText,
    required this.headerAvatar,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
    required this.onTap,
  });

  final AiSavedAnalysisHistoryEntry entry;
  final String bodyText;
  final String headerPrimaryText;
  final String headerSecondaryText;
  final Widget headerAvatar;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = bodyText.trim();
    final contentStyle = TextStyle(
      fontSize: 16,
      height: 1.6,
      fontWeight: FontWeight.w600,
      color: textMain,
    );
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'ai-history-${entry.taskId}',
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerPrimaryText,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              headerSecondaryText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textMuted.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      headerAvatar,
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
                                child: MemoMarkdown(
                                  data: content,
                                  textStyle: contentStyle,
                                  normalizeHeadings: true,
                                  renderImages: false,
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
}

class _RandomWalkCard extends StatelessWidget {
  const _RandomWalkCard({
    required this.memo,
    required this.headerPrimaryText,
    required this.headerSecondaryText,
    required this.headerAvatar,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
    required this.baseUrl,
    required this.authHeader,
    required this.rebaseAbsoluteFileUrlForV024,
    required this.attachAuthForSameOriginAbsolute,
    required this.audioPlaying,
    required this.audioLoading,
    this.audioPositionListenable,
    this.audioDurationListenable,
    this.onAudioTap,
    this.onToggleTask,
  });

  final LocalMemo memo;
  final String headerPrimaryText;
  final String headerSecondaryText;
  final Widget headerAvatar;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final bool isDark;
  final Uri? baseUrl;
  final String? authHeader;
  final bool rebaseAbsoluteFileUrlForV024;
  final bool attachAuthForSameOriginAbsolute;
  final bool audioPlaying;
  final bool audioLoading;
  final ValueListenable<Duration>? audioPositionListenable;
  final ValueListenable<Duration?>? audioDurationListenable;
  final VoidCallback? onAudioTap;
  final TaskToggleHandler? onToggleTask;

  @override
  Widget build(BuildContext context) {
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
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    final videoEntries = collectMemoVideoEntries(
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
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
    final location = memo.location;
    final hasLocation =
        location != null &&
        location.displayText(fractionDigits: 6).trim().isNotEmpty;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerPrimaryText,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              headerSecondaryText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textMuted.withValues(alpha: 0.72),
                              ),
                            ),
                            if (hasLocation) ...[
                              const SizedBox(height: 6),
                              MemoLocationLine(
                                location: location,
                                textColor: textMuted.withValues(alpha: 0.82),
                                fontSize: 12,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      headerAvatar,
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
                                    if (videoEntries.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      MemoVideoGrid(
                                        videos: videoEntries,
                                        columns: 3,
                                        maxCount: 9,
                                        maxHeight: maxGridHeight,
                                        radius: 10,
                                        spacing: 8,
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
      r'^(?:\u65f6\u957f|Duration)\s*[:\uFF1A]\s*(\d{1,2}):(\d{1,2}):(\d{1,2})$',
      caseSensitive: false,
      unicode: true,
    );

    for (final rawLine in content.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final line = trimmed.replaceFirst(linePattern, '');
      final m = valuePattern.firstMatch(line);
      if (m == null) continue;
      final hh = int.tryParse(m.group(1) ?? '') ?? 0;
      final mm = int.tryParse(m.group(2) ?? '') ?? 0;
      final ss = int.tryParse(m.group(3) ?? '') ?? 0;
      if (hh == 0 && mm == 0 && ss == 0) return null;
      return Duration(hours: hh, minutes: mm, seconds: ss);
    }

    return null;
  }
}
