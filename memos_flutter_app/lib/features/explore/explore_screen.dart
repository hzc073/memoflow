import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/attachment_toast.dart';
import '../../core/drawer_navigation.dart';
import '../../core/memo_relations.dart';
import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/content_fingerprint.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/reaction.dart';
import '../../data/models/user.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../about/about_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memo_detail_screen.dart';
import '../memos/memo_image_grid.dart';
import '../memos/memo_media_grid.dart';
import '../memos/memo_video_grid.dart';
import '../memos/memo_markdown.dart';
import '../memos/memos_list_screen.dart';
import '../memos/recycle_bin_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../sync/sync_queue_screen.dart';
import '../../i18n/strings.g.dart';

const _pageSize = 30;
const _orderBy = 'display_time desc';
const _scrollLoadThreshold = 240.0;
const _maxPreviewLines = 6;
const _maxPreviewRunes = 220;
const _likeReactionType = '❤️';
const _commentPreviewCount = 3;

const _quickMenuPaddingH = 6.0;
const _quickMenuPaddingV = 4.0;
const _quickMenuItemHPadding = 10.0;
const _quickMenuItemVPadding = 6.0;
const _quickMenuIconSize = 16.0;
const _quickMenuIconGap = 6.0;
const _quickMenuDividerWidth = 1.0;
const _quickMenuGap = 6.0;

OverlayEntry? _activeExploreQuickMenu;
Object? _activeExploreQuickMenuOwner;

typedef _PreviewResult = ({String text, bool truncated});

final RegExp _markdownLinkPattern = RegExp(r'\[([^\]]*)\]\(([^)]+)\)');
final RegExp _whitespaceCollapsePattern = RegExp(r'\s+');

void _dismissExploreQuickMenu() {
  _activeExploreQuickMenu?.remove();
  _activeExploreQuickMenu = null;
  _activeExploreQuickMenuOwner = null;
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

String _escapeFilterValue(String raw) {
  return raw
      .replaceAll('\\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', ' ');
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  final _creatorCache = <String, User>{};
  final _creatorFetching = <String>{};
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();

  Timer? _debounce;
  List<Memo> _memos = [];
  String _nextPageToken = '';
  String? _error;
  bool _loading = false;
  bool _legacySearchLimited = false;
  bool _searchExpanded = false;
  bool _commentSending = false;
  String? _commentingMemoUid;
  String? _replyingMemoUid;
  String? _replyingCommentCreator;
  final _commentCache = <String, List<Memo>>{};
  final _commentTotals = <String, int>{};
  final _commentErrors = <String, String>{};
  final _commentLoading = <String>{};
  final _reactionCache = <String, List<Reaction>>{};
  final _reactionTotals = <String, int>{};
  final _reactionErrors = <String, String>{};
  final _reactionLoading = <String>{};
  final _reactionUpdating = <String>{};
  final _reactionPreviewRequested = <String>{};
  final _commentedByMe = <String>{};
  final _commentPreviewRequested = <String>{};
  ProviderSubscription<AsyncValue<AppSessionState>>? _sessionSubscription;
  String? _activeAccountKey;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _activeAccountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
    _sessionSubscription = ref.listenManual<AsyncValue<AppSessionState>>(
      appSessionProvider,
      (prev, next) {
        final prevKey = prev?.valueOrNull?.currentKey;
        final nextKey = next.valueOrNull?.currentKey;
        if (prevKey == nextKey) return;
        _handleAccountChange(nextKey);
      },
    );
    _scrollController.addListener(_handleScroll);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sessionSubscription?.close();
    _searchController.dispose();
    _searchFocus.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _backToAllMemos(BuildContext context) {
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

  void _navigate(BuildContext context, AppDrawerDestination dest) {
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

  void _openTag(BuildContext context, String tag) {
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

  void _openNotifications(BuildContext context) {
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  void _toggleSearch() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    if (!_searchExpanded && !hasQuery) {
      setState(() => _searchExpanded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocus.requestFocus();
      });
      return;
    }

    setState(() => _searchExpanded = false);
    if (hasQuery) {
      _searchController.clear();
      _refresh();
    }
  }

  void _handleScroll() {
    if (_loading || _nextPageToken.isEmpty) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _scrollLoadThreshold) {
      _fetchPage();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    if (mounted) {
      setState(() {});
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _refresh();
    });
  }

  Future<void> _refresh() async {
    await _fetchPage(reset: true);
  }

  void _handleAccountChange(String? nextKey) {
    _activeAccountKey = nextKey;
    _requestId++;
    _loading = false;
    _nextPageToken = '';
    _error = null;
    _legacySearchLimited = false;
    _memos = [];
    _creatorCache.clear();
    _creatorFetching.clear();
    _commentCache.clear();
    _commentTotals.clear();
    _commentErrors.clear();
    _commentLoading.clear();
    _reactionCache.clear();
    _reactionTotals.clear();
    _reactionErrors.clear();
    _reactionLoading.clear();
    _reactionUpdating.clear();
    _reactionPreviewRequested.clear();
    _commentedByMe.clear();
    _commentPreviewRequested.clear();
    _commentingMemoUid = null;
    _replyingMemoUid = null;
    _replyingCommentCreator = null;
    _commentController.clear();
    if (!mounted) return;
    setState(() {});
    _refresh();
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _nextPageToken.isEmpty) return;

    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      if (!mounted) return;
      setState(() => _error = context.t.strings.legacy.msg_not_signed);
      return;
    }

    final accountKey = account.key;
    _activeAccountKey ??= accountKey;
    final requestId = ++_requestId;
    final query = _searchController.text.trim();
    final includeProtected = account.personalAccessToken.trim().isNotEmpty;
    final filter = _buildFilter(query, includeProtected: includeProtected);

    if (!mounted) return;
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _legacySearchLimited = false;
        _nextPageToken = '';
        _memos = [];
        _commentCache.clear();
        _commentTotals.clear();
        _commentErrors.clear();
        _commentLoading.clear();
        _reactionCache.clear();
        _reactionTotals.clear();
        _reactionErrors.clear();
        _reactionLoading.clear();
        _reactionUpdating.clear();
        _commentedByMe.clear();
        _reactionPreviewRequested.clear();
        _commentPreviewRequested.clear();
      }
    });

    try {
      final api = ref.read(memosApiProvider);
      final result = await api.listExploreMemos(
        pageSize: _pageSize,
        pageToken: reset ? null : _nextPageToken,
        state: 'NORMAL',
        filter: filter,
        orderBy: _orderBy,
      );
      if (!mounted ||
          requestId != _requestId ||
          _activeAccountKey != accountKey)
        return;
      setState(() {
        if (reset) {
          _memos = result.memos;
        } else {
          _memos = [..._memos, ...result.memos];
        }
        _nextPageToken = result.nextPageToken;
        _legacySearchLimited = result.usedLegacyAll && query.isNotEmpty;
        _error = null;
      });
      _seedReactionCache(result.memos);
      unawaited(_prefetchCreators(result.memos));
    } catch (e) {
      if (!mounted ||
          requestId != _requestId ||
          _activeAccountKey != accountKey)
        return;
      setState(() {
        if (reset) {
          _error = e.toString();
        }
        _legacySearchLimited = false;
      });
      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_failed_load_4(e: e)),
          ),
        );
      }
    } finally {
      if (mounted &&
          requestId == _requestId &&
          _activeAccountKey == accountKey) {
        setState(() => _loading = false);
      }
    }
  }

  String _buildFilter(String query, {required bool includeProtected}) {
    final visibilities = includeProtected
        ? ['PUBLIC', 'PROTECTED']
        : ['PUBLIC'];
    final visibilityExpr = visibilities.map((v) => '"$v"').join(', ');
    final conditions = <String>['visibility in [$visibilityExpr]'];
    if (query.isNotEmpty) {
      conditions.add('content.contains("${_escapeFilterValue(query)}")');
    }
    return conditions.join(' && ');
  }

  Future<void> _prefetchCreators(List<Memo> memos) async {
    await _prefetchCreatorsByName(memos.map((memo) => memo.creator));
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

  void _seedReactionCache(List<Memo> memos) {
    final updates = <String, List<Reaction>>{};
    final totals = <String, int>{};
    final creators = <String>{};
    for (final memo in memos) {
      final uid = memo.uid;
      if (uid.isEmpty) continue;
      if (_reactionCache.containsKey(uid)) continue;
      if (memo.reactions.isEmpty) continue;
      updates[uid] = memo.reactions;
      totals[uid] = memo.reactions.where(_isLikeReaction).length;
      for (final reaction in memo.reactions) {
        final creator = reaction.creator.trim();
        if (creator.isNotEmpty) {
          creators.add(creator);
        }
      }
    }
    if (updates.isEmpty) return;
    setState(() {
      _reactionCache.addAll(updates);
      _reactionTotals.addAll(totals);
    });
    if (creators.isNotEmpty) {
      unawaited(_prefetchCreatorsByName(creators));
    }
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://'))
      return trimmed;
    if (baseUrl == null) return trimmed;
    return joinBaseUrl(baseUrl, trimmed);
  }

  Memo? _findMemoByUid(String uid) {
    final target = uid.trim();
    if (target.isEmpty) return null;
    for (final memo in _memos) {
      if (memo.uid == target) return memo;
    }
    return null;
  }

  String _creatorMetaLine(User? creator, String fallback, String dateText) {
    final rawName = (creator?.name ?? '').trim();
    final rawFallback = fallback.trim();
    final id = rawName.isNotEmpty ? rawName : rawFallback;
    if (id.isEmpty) return dateText;
    return '${id.toUpperCase()} - $dateText';
  }

  String _creatorDisplayName(User? creator, String fallback) {
    final display = creator?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = creator?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final trimmed = fallback.trim();
    if (trimmed.startsWith('users/')) {
      return '${context.t.strings.legacy.msg_user} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.t.strings.legacy.msg_unknown : trimmed;
  }

  String _creatorInitial(User? creator, String fallback) {
    final title = _creatorDisplayName(creator, fallback);
    if (title.isEmpty) return '?';
    return title.characters.first.toUpperCase();
  }

  String _currentUserName() {
    return ref
            .read(appSessionProvider)
            .valueOrNull
            ?.currentAccount
            ?.user
            .name
            .trim() ??
        '';
  }

  int _commentCountFor(Memo memo) {
    final memoName = memo.name.trim();
    var count = 0;
    for (final relation in memo.relations) {
      if (relation.type.toUpperCase() == 'COMMENT' &&
          relation.relatedMemo.name.trim() == memoName) {
        count++;
      }
    }
    final cached = _commentTotals[memo.uid] ?? 0;
    return count > 0 ? count : cached;
  }

  bool _isLikeReaction(Reaction reaction) {
    final type = reaction.reactionType.trim();
    return type == _likeReactionType || type == 'HEART';
  }

  List<String> _likeCreatorNames(List<Reaction> reactions) {
    if (reactions.isEmpty) return const [];
    final result = <String>[];
    final seen = <String>{};
    for (final reaction in reactions) {
      if (!_isLikeReaction(reaction)) continue;
      final creator = reaction.creator.trim();
      if (creator.isEmpty) continue;
      if (seen.add(creator)) {
        result.add(creator);
      }
    }
    return result;
  }

  List<Reaction> _reactionListFor(Memo memo) {
    return _reactionCache[memo.uid] ?? memo.reactions;
  }

  int _reactionCountFor(Memo memo) {
    final reactions = _reactionListFor(memo);
    if (reactions.isNotEmpty) {
      return reactions.where(_isLikeReaction).length;
    }
    return _reactionTotals[memo.uid] ?? 0;
  }

  bool _hasMyReaction(Memo memo) {
    final currentUser = _currentUserName();
    if (currentUser.isEmpty) return false;
    final reactions = _reactionListFor(memo);
    for (final reaction in reactions) {
      if (_isLikeReaction(reaction) && reaction.creator.trim() == currentUser) {
        return true;
      }
    }
    return false;
  }

  bool _hasMyComment(Memo memo) {
    final uid = memo.uid;
    if (uid.isEmpty) return false;
    if (_commentedByMe.contains(uid)) return true;
    final currentUser = _currentUserName();
    if (currentUser.isEmpty) return false;
    final comments = _commentCache[uid];
    if (comments == null) return false;
    return comments.any((comment) => comment.creator.trim() == currentUser);
  }

  void _toggleComment(Memo memo) {
    final nextUid = _commentingMemoUid == memo.uid ? null : memo.uid;
    setState(() {
      _commentingMemoUid = nextUid;
      _replyingMemoUid = null;
      _replyingCommentCreator = null;
    });
    _commentController.clear();
    if (nextUid != null) {
      _commentFocusNode.requestFocus();
      unawaited(_loadComments(memo));
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _replyToComment(Memo memo, Memo comment) {
    setState(() {
      _commentingMemoUid = memo.uid;
      _replyingMemoUid = memo.uid;
      _replyingCommentCreator = comment.creator;
    });
    _commentController.clear();
    _commentFocusNode.requestFocus();
    if (!_commentLoading.contains(memo.uid) &&
        !_commentCache.containsKey(memo.uid)) {
      unawaited(_loadComments(memo));
    }
  }

  void _exitCommentEditing() {
    if (_commentingMemoUid == null) return;
    setState(() {
      _commentingMemoUid = null;
      _replyingMemoUid = null;
      _replyingCommentCreator = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _loadComments(Memo memo, {int pageSize = 50}) async {
    final uid = memo.uid;
    if (uid.isEmpty || _commentLoading.contains(uid)) return;
    setState(() {
      _commentLoading.add(uid);
      _commentErrors.remove(uid);
    });
    try {
      final api = ref.read(memosApiProvider);
      final result = await api.listMemoComments(
        memoUid: uid,
        pageSize: pageSize,
      );
      if (!mounted) return;
      final existing = _commentCache[uid] ?? const <Memo>[];
      final optimistic = existing
          .where((m) => m.name.startsWith('local/'))
          .toList(growable: false);
      final resultNames = <String>{};
      for (final m in result.memos) {
        resultNames.add(m.name);
      }
      final merged = <Memo>[
        ...optimistic,
        ...result.memos,
        ...existing.where(
          (m) => !m.name.startsWith('local/') && !resultNames.contains(m.name),
        ),
      ];
      _commentCache[uid] = merged;
      _commentTotals[uid] = result.totalSize;
      final currentUser = _currentUserName();
      if (currentUser.isNotEmpty) {
        final hasMine = merged.any((m) => m.creator.trim() == currentUser);
        if (hasMine) {
          _commentedByMe.add(uid);
        } else {
          _commentedByMe.remove(uid);
        }
      }
      unawaited(_prefetchCreators(merged));
    } catch (e) {
      if (!mounted) return;
      _commentErrors[uid] = e.toString();
    } finally {
      if (mounted) {
        setState(() => _commentLoading.remove(uid));
      }
    }
  }

  void _requestCommentPreview(Memo memo) {
    final uid = memo.uid;
    if (uid.isEmpty) return;
    if (_commentPreviewRequested.contains(uid)) return;
    if (_commentLoading.contains(uid)) return;
    _commentPreviewRequested.add(uid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadComments(memo, pageSize: _commentPreviewCount));
    });
  }

  void _requestReactionPreview(Memo memo) {
    final uid = memo.uid;
    if (uid.isEmpty) return;
    if (_reactionPreviewRequested.contains(uid)) return;
    if (_reactionLoading.contains(uid)) return;
    _reactionPreviewRequested.add(uid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadReactions(memo));
    });
  }

  Future<List<Reaction>> _loadReactions(Memo memo) async {
    final uid = memo.uid;
    if (uid.isEmpty) return const [];
    final cached = _reactionCache[uid];
    if (cached != null) return cached;
    if (_reactionLoading.contains(uid)) return memo.reactions;

    setState(() {
      _reactionLoading.add(uid);
      _reactionErrors.remove(uid);
    });

    try {
      final api = ref.read(memosApiProvider);
      final result = await api.listMemoReactions(memoUid: uid, pageSize: 50);
      if (!mounted) return memo.reactions;
      _reactionCache[uid] = result.reactions;
      _reactionTotals[uid] = result.reactions.where(_isLikeReaction).length;
      if (result.reactions.isNotEmpty) {
        unawaited(
          _prefetchCreatorsByName(result.reactions.map((r) => r.creator)),
        );
      }
      return result.reactions;
    } catch (e) {
      if (!mounted) return memo.reactions;
      _reactionErrors[uid] = e.toString();
      return memo.reactions;
    } finally {
      if (mounted) {
        setState(() => _reactionLoading.remove(uid));
      }
    }
  }

  Future<void> _toggleLike(Memo memo) async {
    final uid = memo.uid;
    if (uid.isEmpty) return;
    final currentUser = _currentUserName();
    if (currentUser.isEmpty) return;
    if (_reactionUpdating.contains(uid)) return;

    setState(() => _reactionUpdating.add(uid));
    final reactions = _reactionListFor(memo);
    final mine = reactions
        .where((r) => _isLikeReaction(r) && r.creator.trim() == currentUser)
        .toList(growable: false);

    try {
      final api = ref.read(memosApiProvider);
      if (mine.isNotEmpty) {
        final updated = reactions
            .where((r) => !mine.contains(r))
            .toList(growable: false);
        _updateMemoReactions(uid, updated);
        for (final reaction in mine) {
          await api.deleteMemoReaction(reaction: reaction);
        }
      } else {
        final optimistic = Reaction(
          name: '',
          creator: currentUser,
          contentId: 'memos/$uid',
          reactionType: _likeReactionType,
        );
        final updated = [...reactions, optimistic];
        _updateMemoReactions(uid, updated);
        final created = await api.upsertMemoReaction(
          memoUid: uid,
          reactionType: _likeReactionType,
        );
        if (!mounted) return;
        final currentList = List<Reaction>.from(_reactionCache[uid] ?? updated);
        final idx = currentList.indexWhere(
          (r) =>
              r.creator.trim() == currentUser &&
              _isLikeReaction(r) &&
              r.name.trim().isEmpty,
        );
        if (idx >= 0) {
          currentList[idx] = created;
        } else {
          currentList.add(created);
        }
        _updateMemoReactions(uid, currentList);
      }
    } catch (e) {
      if (!mounted) return;
      _updateMemoReactions(uid, reactions);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_react(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _reactionUpdating.remove(uid));
      }
    }
  }

  void _updateMemoReactions(String uid, List<Reaction> reactions) {
    final updatedTotal = reactions.where(_isLikeReaction).length;
    setState(() {
      _reactionCache[uid] = reactions;
      _reactionTotals[uid] = updatedTotal;
      _memos = _memos
          .map((m) => m.uid == uid ? _copyMemoWithReactions(m, reactions) : m)
          .toList(growable: false);
    });
  }

  Memo _copyMemoWithReactions(Memo memo, List<Reaction> reactions) {
    return Memo(
      name: memo.name,
      creator: memo.creator,
      content: memo.content,
      contentFingerprint: memo.contentFingerprint,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTime: memo.createTime,
      updateTime: memo.updateTime,
      displayTime: memo.displayTime,
      tags: memo.tags,
      attachments: memo.attachments,
      location: memo.location,
      relations: memo.relations,
      reactions: reactions,
    );
  }

  Memo _buildOptimisticComment({
    required String memoUid,
    required String content,
    required String visibility,
    required String creator,
  }) {
    final now = DateTime.now().toUtc();
    final fingerprint = computeContentFingerprint(content);
    return Memo(
      name: 'local/${now.microsecondsSinceEpoch}',
      creator: creator,
      content: content,
      contentFingerprint: fingerprint,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTime: now,
      updateTime: now,
      displayTime: now,
      tags: const [],
      attachments: const [],
      relations: const [],
      reactions: const [],
    );
  }

  Future<void> _submitComment() async {
    final uid = _commentingMemoUid;
    if (uid == null || uid.trim().isEmpty) return;
    final content = _commentController.text.trim();
    if (content.isEmpty || _commentSending) return;
    final api = ref.read(memosApiProvider);

    final memo = _findMemoByUid(uid);
    final visibility = (memo?.visibility ?? '').trim().isNotEmpty
        ? memo!.visibility
        : 'PUBLIC';
    final creator = _currentUserName();
    final optimistic = _buildOptimisticComment(
      memoUid: uid,
      content: content,
      visibility: visibility,
      creator: creator,
    );

    setState(() {
      _commentSending = true;
      final list = List<Memo>.from(_commentCache[uid] ?? const <Memo>[]);
      list.insert(0, optimistic);
      _commentCache[uid] = list;
      final total = _commentTotals[uid];
      if (total != null && total > 0) {
        _commentTotals[uid] = total + 1;
      } else {
        _commentTotals[uid] = list.length;
      }
      _commentedByMe.add(uid);
      _replyingMemoUid = null;
      _replyingCommentCreator = null;
      _commentController.clear();
    });
    _exitCommentEditing();

    try {
      final created = await api.createMemoComment(
        memoUid: uid,
        content: content,
        visibility: visibility,
      );
      if (!mounted) return;
      final list = List<Memo>.from(_commentCache[uid] ?? const <Memo>[]);
      final idx = list.indexWhere((m) => m.name == optimistic.name);
      if (idx >= 0) {
        list[idx] = created;
      } else {
        list.insert(0, created);
      }
      _commentCache[uid] = list;
      final total = _commentTotals[uid];
      if (total != null && total > 0) {
        _commentTotals[uid] = total;
      } else {
        _commentTotals[uid] = list.length;
      }
      _commentedByMe.add(uid);
      unawaited(_prefetchCreators([created]));
      if (memo != null && !_commentLoading.contains(uid)) {
        unawaited(_loadComments(memo, pageSize: 50));
      }
    } catch (e) {
      if (!mounted) return;
      final list = List<Memo>.from(_commentCache[uid] ?? const <Memo>[]);
      list.removeWhere((m) => m.name == optimistic.name);
      _commentCache[uid] = list;
      final total = _commentTotals[uid];
      if (total != null && total > 0) {
        _commentTotals[uid] = math.max(0, total - 1);
      } else {
        _commentTotals[uid] = list.length;
      }
      final hasMine =
          creator.isNotEmpty && list.any((m) => m.creator.trim() == creator);
      if (!hasMine) {
        _commentedByMe.remove(uid);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_comment(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _commentSending = false);
      }
    }
  }

  Widget _buildCommentComposer({
    required String hint,
    required bool isDark,
    required Color textMain,
    required Color textMuted,
  }) {
    final surface = isDark ? MemoFlowPalette.cardDark : Colors.white;
    final inputBg = isDark
        ? MemoFlowPalette.backgroundDark
        : const Color(0xFFF7F5F1);
    return TapRegion(
      onTapOutside: (_) => _exitCommentEditing(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.emoji_emotions_outlined,
                          color: textMuted,
                        ),
                        onPressed: () {},
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.image_outlined, color: textMuted),
                        onPressed: () {},
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitComment(),
                          style: TextStyle(color: textMain),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: TextStyle(
                              color: textMuted.withValues(alpha: 0.7),
                            ),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: MemoFlowPalette.primary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _commentSending ? null : _submitComment,
                        style: TextButton.styleFrom(
                          foregroundColor: MemoFlowPalette.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          context.t.strings.legacy.msg_send,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LocalMemo _toLocalMemo(Memo memo) {
    return LocalMemo(
      uid: memo.uid,
      content: memo.content,
      contentFingerprint: memo.contentFingerprint,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTime: memo.createTime.toLocal(),
      updateTime: memo.updateTime.toLocal(),
      tags: memo.tags,
      attachments: memo.attachments,
      relationCount: countReferenceRelations(
        memoUid: memo.uid,
        relations: memo.relations,
      ),
      location: memo.location,
      syncState: SyncState.synced,
      lastError: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final cardMuted = isDark
        ? MemoFlowPalette.cardDark
        : const Color(0xFFE6E2DC);
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark
        ? MemoFlowPalette.borderDark.withValues(alpha: 0.7)
        : MemoFlowPalette.borderLight;
    final hapticsEnabled = prefs.hapticsEnabled;
    final collapseLongContent = prefs.collapseLongContent;
    final collapseReferences = prefs.collapseReferences;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final commentMemo = _commentingMemoUid == null
        ? null
        : _findMemoByUid(_commentingMemoUid!);
    final commentCreator = commentMemo == null
        ? null
        : _creatorCache[commentMemo.creator];
    final commentMode = commentMemo != null;
    final baseUrl = account?.baseUrl;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final authHeader = (account?.personalAccessToken ?? '').isEmpty
        ? null
        : 'Bearer ${account!.personalAccessToken}';
    final searchQuery = _searchController.text.trim();
    final highlightQuery = searchQuery.isEmpty ? null : searchQuery;

    void maybeHaptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final showLoading = _loading && _memos.isEmpty;
    final showError = _error != null && _memos.isEmpty && !showLoading;
    final showEmpty = _memos.isEmpty && !showLoading && _error == null;

    final listBottomPadding = commentMode ? 220.0 : 120.0;

    Widget listBody;
    if (showLoading) {
      listBody = const Center(child: CircularProgressIndicator());
    } else if (showError) {
      listBody = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t.strings.legacy.msg_failed_load_2,
                style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refresh,
                child: Text(context.t.strings.legacy.msg_retry),
              ),
            ],
          ),
        ),
      );
    } else if (showEmpty) {
      listBody = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 24, 16, listBottomPadding),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                context.t.strings.legacy.msg_no_content_yet,
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
            ),
          ],
        ),
      );
    } else {
      listBody = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, listBottomPadding),
          itemBuilder: (context, index) {
            if (index < _memos.length) {
              final memo = _memos[index];
              final creator = _creatorCache[memo.creator];
              final displayTime = memo.displayTime ?? memo.updateTime;
              final dateText = _dateFmt.format(displayTime.toLocal());
              final displayName = _creatorDisplayName(creator, memo.creator);
              final metaLine = _creatorMetaLine(
                creator,
                memo.creator,
                dateText,
              );
              final initial = _creatorInitial(creator, memo.creator);
              final avatarUrl = _resolveAvatarUrl(
                creator?.avatarUrl ?? '',
                baseUrl,
              );
              final comments = _commentCache[memo.uid] ?? const <Memo>[];
              final commentError = _commentErrors[memo.uid];
              final commentsLoading = _commentLoading.contains(memo.uid);
              final commentCount = _commentCountFor(memo);
              final reactions = _reactionListFor(memo);
              final reactionCount = _reactionCountFor(memo);
              final isLiked = _hasMyReaction(memo);
              final hasOwnComment = _hasMyComment(memo);
              final likeCreators = _likeCreatorNames(reactions);

              if (commentCount > 0 &&
                  comments.isEmpty &&
                  !commentsLoading &&
                  commentError == null) {
                _requestCommentPreview(memo);
              }
              if (reactionCount > 0 &&
                  reactions.isEmpty &&
                  !_reactionLoading.contains(memo.uid)) {
                _requestReactionPreview(memo);
              }

              return _ExploreMemoCard(
                memo: memo,
                displayName: displayName,
                metaLine: metaLine,
                avatarUrl: avatarUrl,
                baseUrl: baseUrl,
                authHeader: authHeader,
                rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
                attachAuthForSameOriginAbsolute:
                    attachAuthForSameOriginAbsolute,
                initial: initial,
                commentCount: commentCount,
                likeCreators: likeCreators,
                reactionCount: reactionCount,
                isLiked: isLiked,
                hasOwnComment: hasOwnComment,
                comments: comments,
                commentsLoading: commentsLoading,
                commentError: commentError,
                isCommenting: _commentingMemoUid == memo.uid,
                commentingMode: commentMode,
                cardColor: commentMode ? cardMuted : card,
                borderColor: border,
                highlightQuery: highlightQuery,
                collapseLongContent: collapseLongContent,
                collapseReferences: collapseReferences,
                resolveCreator: (name) => _creatorCache[name],
                onTap: () {
                  maybeHaptic();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MemoDetailScreen(
                        initialMemo: _toLocalMemo(memo),
                        readOnly: true,
                        showEngagement: true,
                      ),
                    ),
                  );
                },
                onToggleComment: () {
                  maybeHaptic();
                  _toggleComment(memo);
                },
                onToggleLike: () {
                  maybeHaptic();
                  _toggleLike(memo);
                },
                onReplyComment: (parent, comment) {
                  maybeHaptic();
                  _replyToComment(parent, comment);
                },
                onMore: () {
                  maybeHaptic();
                },
              );
            }

            if (_loading && _memos.isNotEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (_nextPageToken.isNotEmpty && _memos.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _fetchPage,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(context.t.strings.legacy.msg_load_more),
                  ),
                ),
              );
            }
            return const SizedBox(height: 24);
          },
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: _memos.length + 1,
        ),
      );
    }

    final showSearchBar =
        _searchExpanded || _searchController.text.trim().isNotEmpty;
    final searchBar = showSearchBar
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText:
                            context.t.strings.legacy.msg_search_public_memos,
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _refresh(),
                    ),
                  ),
                  if (_searchController.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: context.t.strings.legacy.msg_clear_2,
                      icon: Icon(Icons.close, size: 16, color: textMuted),
                      onPressed: () {
                        _searchController.clear();
                        _refresh();
                      },
                    ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    final replyCreator = _replyingMemoUid == commentMemo?.uid
        ? _replyingCommentCreator
        : null;
    final replyUser = replyCreator == null ? null : _creatorCache[replyCreator];
    final replyName = replyCreator == null
        ? ''
        : _creatorDisplayName(replyUser, replyCreator);
    final commentHint = commentMemo == null
        ? context.t.strings.legacy.msg_write_comment
        : replyCreator != null && replyName.isNotEmpty
        ? context.t.strings.legacy.msg_reply(replyName: replyName)
        : context.t.strings.legacy.msg_reply_3(
            creatorDisplayName_commentCreator_commentMemo_creator:
                _creatorDisplayName(commentCreator, commentMemo.creator),
          );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final enableWindowsDragToMove =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.explore,
      onSelect: (d) => _navigate(context, d),
      onSelectTag: (t) => _openTag(context, t),
      onOpenNotifications: () => _openNotifications(context),
      embedded: useDesktopSidePane,
    );
    final pageBody = Stack(
      children: [
        Column(
          children: [
            searchBar,
            if (_legacySearchLimited)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context
                      .t
                      .strings
                      .legacy
                      .msg_legacy_servers_not_support_search_filters,
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ),
            Expanded(child: listBody),
          ],
        ),
        if (commentMemo != null)
          _buildCommentComposer(
            hint: commentHint,
            isDark: isDark,
            textMain: textMain,
            textMuted: textMuted,
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        drawer: useDesktopSidePane ? null : drawerPanel,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: !useDesktopSidePane,
          toolbarHeight: 46,
          iconTheme: IconThemeData(color: textMain),
          flexibleSpace: enableWindowsDragToMove
              ? const DragToMoveArea(child: SizedBox.expand())
              : null,
          title: IgnorePointer(
            ignoring: enableWindowsDragToMove,
            child: Text(
              context.t.strings.legacy.msg_explore,
              style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
            ),
          ),
          actions: [
            IconButton(
              tooltip: showSearchBar
                  ? context.t.strings.legacy.msg_close_search
                  : context.t.strings.legacy.msg_search,
              icon: Icon(
                showSearchBar ? Icons.close : Icons.search,
                color: textMain,
              ),
              onPressed: _toggleSearch,
            ),
          ],
        ),
        body: useDesktopSidePane
            ? Row(
                children: [
                  SizedBox(
                    width: kMemoFlowDesktopDrawerWidth,
                    child: drawerPanel,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  Expanded(child: pageBody),
                ],
              )
            : pageBody,
      ),
    );
  }
}

class _ExploreMemoCard extends StatefulWidget {
  const _ExploreMemoCard({
    required this.memo,
    required this.displayName,
    required this.metaLine,
    required this.avatarUrl,
    required this.baseUrl,
    required this.authHeader,
    required this.rebaseAbsoluteFileUrlForV024,
    required this.attachAuthForSameOriginAbsolute,
    required this.initial,
    required this.commentCount,
    required this.likeCreators,
    required this.reactionCount,
    required this.isLiked,
    required this.hasOwnComment,
    required this.comments,
    required this.commentsLoading,
    required this.commentError,
    required this.isCommenting,
    required this.commentingMode,
    required this.cardColor,
    required this.borderColor,
    required this.highlightQuery,
    required this.collapseLongContent,
    required this.collapseReferences,
    required this.resolveCreator,
    required this.onTap,
    required this.onToggleComment,
    required this.onToggleLike,
    required this.onReplyComment,
    required this.onMore,
  });

  final Memo memo;
  final String displayName;
  final String metaLine;
  final String avatarUrl;
  final Uri? baseUrl;
  final String? authHeader;
  final bool rebaseAbsoluteFileUrlForV024;
  final bool attachAuthForSameOriginAbsolute;
  final String initial;
  final int commentCount;
  final List<String> likeCreators;
  final int reactionCount;
  final bool isLiked;
  final bool hasOwnComment;
  final List<Memo> comments;
  final bool commentsLoading;
  final String? commentError;
  final bool isCommenting;
  final bool commentingMode;
  final Color cardColor;
  final Color borderColor;
  final String? highlightQuery;
  final bool collapseLongContent;
  final bool collapseReferences;
  final User? Function(String name) resolveCreator;
  final VoidCallback onTap;
  final VoidCallback onToggleComment;
  final VoidCallback onToggleLike;
  final void Function(Memo parent, Memo comment) onReplyComment;
  final VoidCallback onMore;

  @override
  State<_ExploreMemoCard> createState() => _ExploreMemoCardState();
}

class _ExploreMemoCardState extends State<_ExploreMemoCard> {
  var _expanded = false;
  final _quickMenuOwner = Object();

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
          .map((l) => l.replaceFirst(RegExp(r'^\s*>\s?'), ''))
          .join('\n')
          .trim();
      return cleaned.isEmpty ? trimmed : cleaned;
    }
    return '$main\n\n${trByLanguageKey(language: language, key: 'legacy.msg_quoted_lines', params: {'quoteLines': quoteLines})}';
  }

  static ({String title, String body}) _splitTitleAndBody(String content) {
    final rawLines = content.split('\n');
    final tagBounds = _tagLineBounds(rawLines);
    final lines = <String>[];
    for (var i = 0; i < rawLines.length; i++) {
      if (i == tagBounds.first || i == tagBounds.last) continue;
      lines.add(rawLines[i]);
    }
    final nonEmpty = lines
        .where((l) => l.trim().isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.length < 2) {
      return (title: '', body: lines.join('\n').trim());
    }
    final titleIndex = lines.indexWhere((l) => l.trim().isNotEmpty);
    if (titleIndex < 0) {
      return (title: '', body: lines.join('\n').trim());
    }
    final rawTitle = lines[titleIndex].trim();
    final title = _cleanTitleLine(rawTitle);
    if (title.isEmpty) {
      return (title: '', body: lines.join('\n').trim());
    }
    final body = lines.sublist(titleIndex + 1).join('\n').trim();
    return (title: title, body: body);
  }

  static ({int? first, int? last}) _tagLineBounds(List<String> lines) {
    int? firstNonEmpty;
    int? lastNonEmpty;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      firstNonEmpty ??= i;
      lastNonEmpty = i;
    }
    final firstTag =
        (firstNonEmpty != null && _isTagOnlyLine(lines[firstNonEmpty]))
        ? firstNonEmpty
        : null;
    final lastTag =
        (lastNonEmpty != null && _isTagOnlyLine(lines[lastNonEmpty]))
        ? lastNonEmpty
        : null;
    return (first: firstTag, last: lastTag);
  }

  static bool _isTagOnlyLine(String line) {
    final trimmed = line.trim();
    if (trimmed.length <= 1) return false;
    return RegExp(r'^#[^\s]+$').hasMatch(trimmed);
  }

  static String _cleanTitleLine(String line) {
    var cleaned = line;
    cleaned = cleaned.replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^\s*>\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^\s*[-*+]\s+\[(?: |x|X)\]\s+'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
    return cleaned.trim();
  }

  static String _commentSnippet(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> _highlightTerms(String? query) {
    if (query == null) return const [];
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return const [];
    final seen = <String>{};
    final terms = <String>[];
    for (final token in tokens) {
      final normalized = token.toLowerCase();
      if (!seen.add(normalized)) continue;
      terms.add(token);
    }
    terms.sort((a, b) => b.runes.length.compareTo(a.runes.length));
    return terms;
  }

  static TextSpan _buildHighlightedTextSpan({
    required String text,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
    required String? query,
  }) {
    final terms = _highlightTerms(query);
    if (terms.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final pattern = terms.map(RegExp.escape).join('|');
    final matcher = RegExp(pattern, caseSensitive: false, unicode: true);
    final matches = matcher.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.end <= cursor) continue;
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: highlightStyle,
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    if (spans.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  static String _commentAuthor(
    BuildContext context,
    User? creator,
    String fallback,
  ) {
    final display = creator?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = creator?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final trimmed = fallback.trim();
    if (trimmed.startsWith('users/')) {
      return '${context.t.strings.legacy.msg_user} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.t.strings.legacy.msg_unknown : trimmed;
  }

  @override
  void dispose() {
    if (_activeExploreQuickMenuOwner == _quickMenuOwner) {
      _dismissExploreQuickMenu();
    }
    super.dispose();
  }

  ({double width, double height}) _measureQuickMenu(
    BuildContext context,
    List<String> labels,
    TextStyle textStyle,
  ) {
    final textPainter = TextPainter(textDirection: Directionality.of(context));
    var maxTextHeight = 0.0;
    var width = _quickMenuPaddingH * 2;
    for (var i = 0; i < labels.length; i++) {
      textPainter.text = TextSpan(text: labels[i], style: textStyle);
      textPainter.layout();
      maxTextHeight = math.max(maxTextHeight, textPainter.height);
      final itemWidth =
          _quickMenuItemHPadding * 2 +
          _quickMenuIconSize +
          _quickMenuIconGap +
          textPainter.width;
      width += itemWidth;
      if (i != labels.length - 1) {
        width += _quickMenuDividerWidth;
      }
    }
    final contentHeight = math.max(_quickMenuIconSize, maxTextHeight);
    final height =
        _quickMenuPaddingV * 2 + _quickMenuItemVPadding * 2 + contentHeight;
    return (width: width, height: height);
  }

  void _showQuickMenu(BuildContext anchorContext) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    final renderBox = anchorContext.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final padding = MediaQuery.of(context).padding;
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final likeLabel = context.t.strings.legacy.msg_like;
    final commentLabel = context.t.strings.legacy.msg_comment;
    final textColor = Colors.white.withValues(alpha: 0.9);
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: textColor,
    );
    final menuSize = _measureQuickMenu(context, [
      likeLabel,
      commentLabel,
    ], textStyle);
    final menuWidth = menuSize.width;
    final menuHeight = menuSize.height;

    final minLeft = padding.left + 8;
    final maxLeft = screenSize.width - padding.right - menuWidth - 8;
    final safeMaxLeft = math.max(minLeft, maxLeft);
    var left = offset.dx - menuWidth - _quickMenuGap;
    if (left < minLeft) {
      left = offset.dx + size.width + _quickMenuGap;
    }
    left = math.min(math.max(left, minLeft), safeMaxLeft);

    final minTop = padding.top + 8;
    final maxTop = screenSize.height - padding.bottom - menuHeight - 8;
    final safeMaxTop = math.max(minTop, maxTop);
    var top = offset.dy + (size.height - menuHeight) / 2;
    top = math.min(math.max(top, minTop), safeMaxTop);

    final menuBg = isDark ? const Color(0xFF1F1F1F) : const Color(0xFF2A2A2A);
    final dividerColor = Colors.white.withValues(alpha: 0.12);
    final activeColor = MemoFlowPalette.primary;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        Widget buildItem({
          required IconData icon,
          required String label,
          required bool active,
          required VoidCallback onTap,
        }) {
          final color = active ? activeColor : textColor;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                _dismissExploreQuickMenu();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _quickMenuItemHPadding,
                  vertical: _quickMenuItemVPadding,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: _quickMenuIconSize, color: color),
                    const SizedBox(width: _quickMenuIconGap),
                    Text(label, style: textStyle.copyWith(color: color)),
                  ],
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissExploreQuickMenu,
                child: const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _quickMenuPaddingH,
                    vertical: _quickMenuPaddingV,
                  ),
                  decoration: BoxDecoration(
                    color: menuBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.4 : 0.25,
                        ),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildItem(
                        icon: widget.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: likeLabel,
                        active: widget.isLiked,
                        onTap: widget.onToggleLike,
                      ),
                      Container(
                        width: _quickMenuDividerWidth,
                        height: _quickMenuIconSize + 4,
                        color: dividerColor,
                      ),
                      buildItem(
                        icon: widget.hasOwnComment
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        label: commentLabel,
                        active: widget.hasOwnComment,
                        onTap: widget.onToggleComment,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    _activeExploreQuickMenu = entry;
    _activeExploreQuickMenuOwner = _quickMenuOwner;
    overlay.insert(entry);
  }

  void _toggleQuickMenu(BuildContext anchorContext) {
    widget.onMore();
    if (_activeExploreQuickMenuOwner == _quickMenuOwner) {
      _dismissExploreQuickMenu();
      return;
    }
    _dismissExploreQuickMenu();
    _showQuickMenu(anchorContext);
  }

  bool _isImageAttachment(Attachment attachment) {
    final type = attachment.type.trim().toLowerCase();
    return type.startsWith('image');
  }

  String _resolveAttachmentUrl(
    Attachment attachment, {
    required bool thumbnail,
  }) {
    final external = attachment.externalLink.trim();
    if (external.isNotEmpty) {
      final isRelative = !isAbsoluteUrl(external);
      final resolved = resolveMaybeRelativeUrl(widget.baseUrl, external);
      return (thumbnail && isRelative)
          ? appendThumbnailParam(resolved)
          : resolved;
    }
    final baseUrl = widget.baseUrl;
    if (baseUrl == null) return '';
    final url = joinBaseUrl(
      baseUrl,
      'file/${attachment.name}/${attachment.filename}',
    );
    return thumbnail ? appendThumbnailParam(url) : url;
  }

  void _openImagePreview(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: widget.authHeader == null
                ? null
                : {'Authorization': widget.authHeader!},
            placeholder: (context, _) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem({required Memo comment, required Color textMain}) {
    final images = comment.attachments
        .where(_isImageAttachment)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 12, color: textMain),
            children: [
              TextSpan(
                text:
                    '${_commentAuthor(context, widget.resolveCreator(comment.creator), comment.creator)}: ',
                style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
              ),
              TextSpan(
                text: _commentSnippet(comment.content),
                style: TextStyle(color: textMain),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final attachment in images) _buildCommentImage(attachment),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCommentImage(Attachment attachment) {
    final thumbUrl = _resolveAttachmentUrl(attachment, thumbnail: true);
    final fullUrl = _resolveAttachmentUrl(attachment, thumbnail: false);
    final displayUrl = thumbUrl.isNotEmpty ? thumbUrl : fullUrl;
    if (displayUrl.isEmpty) return const SizedBox.shrink();
    final viewUrl = fullUrl.isNotEmpty ? fullUrl : displayUrl;

    return GestureDetector(
      onTap: viewUrl.isEmpty ? null : () => _openImagePreview(viewUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: displayUrl,
          httpHeaders: widget.authHeader == null
              ? null
              : {'Authorization': widget.authHeader!},
          width: 100,
          height: 72,
          fit: BoxFit.cover,
          placeholder: (context, _) => const SizedBox(
            width: 100,
            height: 72,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => const SizedBox(
            width: 100,
            height: 72,
            child: Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color textMuted) {
    final avatarSize = 36.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.initial,
        style: TextStyle(fontWeight: FontWeight.w700, color: textMuted),
      ),
    );

    final avatarUrl = widget.avatarUrl.trim();
    if (avatarUrl.isEmpty) return fallback;
    if (avatarUrl.startsWith('data:')) {
      final bytes = tryDecodeDataUri(avatarUrl);
      if (bytes == null) return fallback;
      return ClipOval(
        child: Image.memory(
          bytes,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveUserAvatarUrl(User? user) {
    final raw = user?.avatarUrl.trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('data:')) return raw;
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return raw;
    final baseUrl = widget.baseUrl;
    if (baseUrl == null) return raw;
    return joinBaseUrl(baseUrl, raw);
  }

  String _initialForUser(User? user, String fallback) {
    final name = _commentAuthor(context, user, fallback).trim();
    if (name.isEmpty) return '?';
    final rune = name.runes.first;
    return String.fromCharCode(rune).toUpperCase();
  }

  Widget _buildTinyAvatar(User? user, String fallback, {double size = 20}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final border = widget.cardColor;
    final url = _resolveUserAvatarUrl(user);
    final fallbackWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _initialForUser(user, fallback),
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    if (url.isEmpty) return fallbackWidget;
    if (url.startsWith('data:')) {
      final bytes = tryDecodeDataUri(url);
      if (bytes == null) return fallbackWidget;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1),
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
        border: Border.all(color: border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, _) => fallbackWidget,
        errorWidget: (context, _, __) => fallbackWidget,
      ),
    );
  }

  Widget _buildAvatarStack(
    List<String> creators, {
    double size = 20,
    int maxCount = 5,
  }) {
    final names = creators
        .where((c) => c.trim().isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return const SizedBox.shrink();
    final display = names.take(maxCount).toList(growable: false);
    final extra = names.length - display.length;
    final overlap = size * 0.35;
    final slot = size - overlap;
    final totalSlots = display.length + (extra > 0 ? 1 : 0);
    final width = size + (totalSlots - 1) * slot;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < display.length; i++)
            Positioned(
              left: i * slot,
              child: _buildTinyAvatar(
                widget.resolveCreator(display[i]),
                display[i],
                size: size,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: display.length * slot,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MemoFlowPalette.primary.withValues(alpha: 0.15),
                  border: Border.all(color: widget.cardColor, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontSize: size * 0.45,
                    fontWeight: FontWeight.w700,
                    color: MemoFlowPalette.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLikeSummary({required Color textMuted}) {
    final hasLikes =
        widget.reactionCount > 0 ||
        widget.isLiked ||
        widget.likeCreators.isNotEmpty;
    if (!hasLikes) return const SizedBox.shrink();
    final iconColor = widget.isLiked ? MemoFlowPalette.primary : textMuted;
    final avatars = _buildAvatarStack(
      widget.likeCreators,
      size: 20,
      maxCount: 5,
    );
    final remaining = widget.reactionCount - widget.likeCreators.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onToggleLike,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              if (widget.likeCreators.isNotEmpty) avatars,
              if (widget.likeCreators.isEmpty)
                Text(
                  widget.reactionCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              if (remaining > 0 && widget.likeCreators.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  '+$remaining',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentSummary({
    required Color textMain,
    required Color textMuted,
  }) {
    final hasComments =
        widget.commentCount > 0 ||
        widget.hasOwnComment ||
        widget.comments.isNotEmpty;
    if (!hasComments) return const SizedBox.shrink();

    final iconColor = widget.hasOwnComment
        ? MemoFlowPalette.primary
        : textMuted;
    final preview = widget.comments.isNotEmpty ? widget.comments.first : null;
    final previewText = preview == null ? '' : _commentSnippet(preview.content);
    final previewCreator = preview == null
        ? null
        : widget.resolveCreator(preview.creator);
    final previewName = preview == null
        ? ''
        : _commentAuthor(context, previewCreator, preview.creator);

    final label = widget.commentCount <= 0
        ? context.t.strings.legacy.msg_no_comments_yet
        : context.t.strings.legacy.msg_comments(
            widget_commentCount: widget.commentCount,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onToggleComment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(
                widget.hasOwnComment
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              if (preview != null) ...[
                _buildTinyAvatar(previewCreator, preview.creator, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$previewName ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        TextSpan(
                          text: previewText,
                          style: TextStyle(fontSize: 12, color: textMain),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentPreviewLine({
    required Memo comment,
    required Color textMain,
  }) {
    final previewCreator = widget.resolveCreator(comment.creator);
    final previewName = _commentAuthor(
      context,
      previewCreator,
      comment.creator,
    );
    final previewText = _commentSnippet(comment.content);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTinyAvatar(previewCreator, comment.creator, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$previewName ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                TextSpan(
                  text: previewText,
                  style: TextStyle(fontSize: 12, color: textMain),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.memo;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = widget.cardColor;
    final borderColor = widget.borderColor;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final language = context.appLanguage;

    final tag = memo.tags.isNotEmpty ? memo.tags.first.trim() : '';
    final split = _splitTitleAndBody(memo.content);
    final title = split.title;
    final bodyText = split.body;

    final previewText = _previewText(
      bodyText,
      collapseReferences: widget.collapseReferences,
      language: language,
    );
    final preview = _truncatePreview(
      previewText,
      collapseLongContent: widget.collapseLongContent,
    );
    final showToggle = preview.truncated;
    final showCollapsed = showToggle && !_expanded;
    final displayText = showCollapsed ? preview.text : previewText;
    final hasBody = displayText.trim().isNotEmpty;
    final showLike =
        widget.reactionCount > 0 ||
        widget.isLiked ||
        widget.likeCreators.isNotEmpty;
    final showComment =
        widget.commentCount > 0 ||
        widget.hasOwnComment ||
        widget.comments.isNotEmpty;
    final previewCount = math.min(widget.comments.length, _commentPreviewCount);
    final totalCommentCount = widget.commentCount > 0
        ? widget.commentCount
        : widget.comments.length;
    final remainingComments = math.max(0, totalCommentCount - previewCount);
    final imageEntries = collectMemoImageEntries(
      content: memo.content,
      attachments: memo.attachments,
      baseUrl: widget.baseUrl,
      authHeader: widget.authHeader,
      rebaseAbsoluteFileUrlForV024: widget.rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: widget.attachAuthForSameOriginAbsolute,
    );
    final videoEntries = collectMemoVideoEntries(
      attachments: memo.attachments,
      baseUrl: widget.baseUrl,
      authHeader: widget.authHeader,
      rebaseAbsoluteFileUrlForV024: widget.rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: widget.attachAuthForSameOriginAbsolute,
    );
    final mediaEntries = buildMemoMediaEntries(
      images: imageEntries,
      videos: videoEntries,
    );
    final nonMediaAttachments = filterNonMediaAttachments(memo.attachments);
    final attachmentLines = attachmentNameLines(nonMediaAttachments);
    final attachmentCount = nonMediaAttachments.length;

    final shadow = widget.commentingMode
        ? null
        : [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            ),
          ];

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  _VisibilityChip(visibility: memo.visibility),
                ],
              ),
              if (tag.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MemoFlowPalette.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (title.isNotEmpty) ...[
                const SizedBox(height: 10),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: _buildHighlightedTextSpan(
                    text: title,
                    query: widget.highlightQuery,
                    baseStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                    highlightStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      backgroundColor: const Color(0xFFFFFF00),
                    ),
                  ),
                ),
              ],
              if (hasBody) ...[
                const SizedBox(height: 6),
                MemoMarkdown(
                  data: displayText,
                  highlightQuery: widget.highlightQuery,
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textMain,
                    height: 1.5,
                  ),
                  blockSpacing: 4,
                  normalizeHeadings: true,
                  renderImages: false,
                ),
              ] else if (title.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  context.t.strings.legacy.msg_no_content,
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
              if (showToggle) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
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
                const SizedBox(height: 12),
                MemoMediaGrid(
                  entries: mediaEntries,
                  columns: 3,
                  maxCount: 9,
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                  radius: 10,
                  spacing: 8,
                  borderColor: borderColor.withValues(alpha: 0.65),
                  backgroundColor: isDark
                      ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6)
                      : MemoFlowPalette.audioSurfaceLight,
                  textColor: textMain,
                  enableDownload: true,
                ),
              ],
              if (attachmentCount > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Builder(
                    builder: (context) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => showAttachmentNamesToast(
                            context,
                            attachmentLines,
                          ),
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
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(height: 1, color: borderColor.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showLike)
                        Expanded(child: _buildLikeSummary(textMuted: textMuted))
                      else
                        const Spacer(),
                      Builder(
                        builder: (buttonContext) => IconButton(
                          icon: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: textMuted,
                          ),
                          onPressed: () => _toggleQuickMenu(buttonContext),
                          tooltip: context.t.strings.legacy.msg_more,
                        ),
                      ),
                    ],
                  ),
                  if (showComment) ...[
                    const SizedBox(height: 6),
                    _buildCommentSummary(
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                    if (!widget.isCommenting && previewCount > 1) ...[
                      const SizedBox(height: 6),
                      for (var i = 1; i < previewCount; i++) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _buildCommentPreviewLine(
                            comment: widget.comments[i],
                            textMain: textMain,
                          ),
                        ),
                        if (i != previewCount - 1) const SizedBox(height: 6),
                      ],
                    ],
                    if (!widget.isCommenting && remainingComments > 0) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: widget.onToggleComment,
                          style: TextButton.styleFrom(
                            foregroundColor: textMuted,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                          ),
                          child: Text(
                            context.t.strings.legacy.msg_more_comments(
                              remainingComments: remainingComments,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              if (widget.isCommenting) ...[
                const SizedBox(height: 8),
                if (widget.commentsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (widget.commentError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      widget.commentError ?? '',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  )
                else if (widget.comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      context.t.strings.legacy.msg_no_comments_yet,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.comments.length; i++) ...[
                        GestureDetector(
                          onTap: () => widget.onReplyComment(
                            widget.memo,
                            widget.comments[i],
                          ),
                          child: _buildCommentPreviewLine(
                            comment: widget.comments[i],
                            textMain: textMain,
                          ),
                        ),
                        if (i != widget.comments.length - 1)
                          const SizedBox(height: 6),
                      ],
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    final heroTag = memo.uid.isNotEmpty ? memo.uid : memo.name;
    if (heroTag.isEmpty) return card;
    return Hero(
      tag: heroTag,
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: card,
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.visibility});

  final String visibility;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _resolveStyle(context, visibility);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static (String label, IconData icon, Color color) _resolveStyle(
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
}
