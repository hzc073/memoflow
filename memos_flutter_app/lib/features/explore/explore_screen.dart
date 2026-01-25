import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
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
import '../memos/memo_markdown.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../review/ai_summary_screen.dart';
import '../review/daily_review_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../sync/sync_queue_screen.dart';

const _pageSize = 30;
const _orderBy = 'display_time desc';
const _scrollLoadThreshold = 240.0;
const _maxPreviewLines = 6;
const _maxPreviewRunes = 220;
const _likeReactionType = '❤️';

typedef _PreviewResult = ({String text, bool truncated});

_PreviewResult _truncatePreview(String text, {required bool collapseLongContent}) {
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

  final compact = result.replaceAll(RegExp(r'\s+'), '');
  if (compact.runes.length > _maxPreviewRunes) {
    result = String.fromCharCodes(result.runes.take(_maxPreviewRunes));
    truncated = true;
  }

  if (truncated) {
    result = result.trimRight();
    result = result.endsWith('...') ? result : '$result...';
  }
  return (text: result, truncated: truncated);
}

String _escapeFilterValue(String raw) {
  return raw.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ');
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
  final _commentedByMe = <String>{};
  ProviderSubscription<AsyncValue<AppSessionState>>? _sessionSubscription;
  String? _activeAccountKey;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _activeAccountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
    _sessionSubscription = ref.listenManual<AsyncValue<AppSessionState>>(appSessionProvider, (prev, next) {
      final prevKey = prev?.valueOrNull?.currentKey;
      final nextKey = next.valueOrNull?.currentKey;
      if (prevKey == nextKey) return;
      _handleAccountChange(nextKey);
    });
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
    context.safePop();
    final route = switch (dest) {
      AppDrawerDestination.memos =>
        const MemosListScreen(title: 'MemoFlow', state: 'NORMAL', showDrawer: true, enableCompose: true),
      AppDrawerDestination.syncQueue => const SyncQueueScreen(),
      AppDrawerDestination.explore => const ExploreScreen(),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => MemosListScreen(
          title: context.tr(zh: 'Archive', en: 'Archive'),
          state: 'ARCHIVED',
          showDrawer: true,
        ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
  }

  void _openTag(BuildContext context, String tag) {
    context.safePop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MemosListScreen(
          title: '#$tag',
          state: 'NORMAL',
          tag: tag,
          showDrawer: true,
          enableCompose: true,
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    context.safePop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - _scrollLoadThreshold) {
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
    _commentedByMe.clear();
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
      setState(() => _error = context.tr(zh: '未登录', en: 'Not signed in'));
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
      if (!mounted || requestId != _requestId || _activeAccountKey != accountKey) return;
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
      if (!mounted || requestId != _requestId || _activeAccountKey != accountKey) return;
      setState(() {
        if (reset) {
          _error = e.toString();
        }
        _legacySearchLimited = false;
      });
      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
        );
      }
    } finally {
      if (mounted && requestId == _requestId && _activeAccountKey == accountKey) {
        setState(() => _loading = false);
      }
    }
  }

  String _buildFilter(String query, {required bool includeProtected}) {
    final visibilities = includeProtected ? ['PUBLIC', 'PROTECTED'] : ['PUBLIC'];
    final visibilityExpr = visibilities.map((v) => '"$v"').join(', ');
    final conditions = <String>['visibility in [$visibilityExpr]'];
    if (query.isNotEmpty) {
      conditions.add('content.contains("${_escapeFilterValue(query)}")');
    }
    return conditions.join(' && ');
  }

  Future<void> _prefetchCreators(List<Memo> memos) async {
    final api = ref.read(memosApiProvider);
    final pending = <String>[];
    for (final memo in memos) {
      final creator = memo.creator.trim();
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
      } catch (_) {} finally {
        _creatorFetching.remove(creator);
      }
    }
    if (updates.isEmpty || !mounted) return;
    setState(() => _creatorCache.addAll(updates));
  }

  void _seedReactionCache(List<Memo> memos) {
    final updates = <String, List<Reaction>>{};
    final totals = <String, int>{};
    for (final memo in memos) {
      final uid = memo.uid;
      if (uid.isEmpty) continue;
      if (_reactionCache.containsKey(uid)) continue;
      if (memo.reactions.isEmpty) continue;
      updates[uid] = memo.reactions;
      totals[uid] = memo.reactions.where(_isLikeReaction).length;
    }
    if (updates.isEmpty) return;
    setState(() {
      _reactionCache.addAll(updates);
      _reactionTotals.addAll(totals);
    });
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return trimmed;
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
      return '${context.tr(zh: '用户', en: 'User')} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.tr(zh: '未知用户', en: 'Unknown') : trimmed;
  }

  String _creatorInitial(User? creator, String fallback) {
    final title = _creatorDisplayName(creator, fallback);
    if (title.isEmpty) return '?';
    return title.characters.first.toUpperCase();
  }

  String _currentUserName() {
    return ref.read(appSessionProvider).valueOrNull?.currentAccount?.user.name.trim() ?? '';
  }

  int _commentCountFor(Memo memo) {
    final memoName = memo.name.trim();
    var count = 0;
    for (final relation in memo.relations) {
      if (relation.type.toUpperCase() == 'COMMENT' && relation.relatedMemo.name.trim() == memoName) {
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
    if (!_commentLoading.contains(memo.uid) && !_commentCache.containsKey(memo.uid)) {
      unawaited(_loadComments(memo));
    }
  }

  void _exitCommentEditing() {
    if (_replyingCommentCreator == null) return;
    setState(() {
      _commentingMemoUid = null;
      _replyingMemoUid = null;
      _replyingCommentCreator = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _loadComments(Memo memo) async {
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
        pageSize: 50,
      );
      if (!mounted) return;
      _commentCache[uid] = result.memos;
      _commentTotals[uid] = result.totalSize;
      final currentUser = _currentUserName();
      if (currentUser.isNotEmpty) {
        final hasMine = result.memos.any((m) => m.creator.trim() == currentUser);
        if (hasMine) {
          _commentedByMe.add(uid);
        } else {
          _commentedByMe.remove(uid);
        }
      }
      unawaited(_prefetchCreators(result.memos));
    } catch (e) {
      if (!mounted) return;
      _commentErrors[uid] = e.toString();
    } finally {
      if (mounted) {
        setState(() => _commentLoading.remove(uid));
      }
    }
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
    try {
      final api = ref.read(memosApiProvider);
      final reactions = await _loadReactions(memo);
      final mine = reactions
          .where((r) => _isLikeReaction(r) && r.creator.trim() == currentUser)
          .toList(growable: false);

      if (mine.isNotEmpty) {
        for (final reaction in mine) {
          await api.deleteMemoReaction(reaction: reaction);
        }
        final updated = reactions.where((r) => !mine.contains(r)).toList(growable: false);
        _updateMemoReactions(uid, updated);
      } else {
        final created = await api.upsertMemoReaction(memoUid: uid, reactionType: _likeReactionType);
        final updated = [...reactions, created];
        _updateMemoReactions(uid, updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '点赞失败：$e', en: 'Failed to react: $e'))),
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
          .map(
            (m) => m.uid == uid ? _copyMemoWithReactions(m, reactions) : m,
          )
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
      relations: memo.relations,
      reactions: reactions,
    );
  }

  Future<void> _submitComment() async {
    final uid = _commentingMemoUid;
    if (uid == null || uid.trim().isEmpty) return;
    final content = _commentController.text.trim();
    if (content.isEmpty || _commentSending) return;

    setState(() => _commentSending = true);
    try {
      final memo = _findMemoByUid(uid);
      final visibility = (memo?.visibility ?? '').trim().isNotEmpty ? memo!.visibility : 'PUBLIC';
      final api = ref.read(memosApiProvider);
      final created = await api.createMemoComment(
        memoUid: uid,
        content: content,
        visibility: visibility,
      );
      if (!mounted) return;
      final list = _commentCache[uid] ?? <Memo>[];
      list.insert(0, created);
      _commentCache[uid] = list;
      final total = _commentTotals[uid];
      if (total != null && total > 0) {
        _commentTotals[uid] = total + 1;
      } else {
        _commentTotals[uid] = list.length;
      }
      _commentController.clear();
      _commentedByMe.add(uid);
      _replyingMemoUid = null;
      _replyingCommentCreator = null;
      unawaited(_prefetchCreators([created]));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '评论失败：$e', en: 'Failed to comment: $e'))),
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
    final inputBg = isDark ? MemoFlowPalette.backgroundDark : const Color(0xFFF7F5F1);
    return TapRegion(
      onTapOutside: _replyingCommentCreator == null ? null : (_) => _exitCommentEditing(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                        icon: Icon(Icons.emoji_emotions_outlined, color: textMuted),
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
                            hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: textMuted.withValues(alpha: 0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: textMuted.withValues(alpha: 0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: MemoFlowPalette.primary.withValues(alpha: 0.6)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _commentSending ? null : _submitComment,
                        style: TextButton.styleFrom(
                          foregroundColor: MemoFlowPalette.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: Text(
                          context.tr(zh: '发送', en: 'Send'),
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
      syncState: SyncState.synced,
      lastError: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final cardMuted = isDark ? MemoFlowPalette.cardDark : const Color(0xFFE6E2DC);
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark ? MemoFlowPalette.borderDark.withValues(alpha: 0.7) : MemoFlowPalette.borderLight;
    final hapticsEnabled = prefs.hapticsEnabled;
    final collapseLongContent = prefs.collapseLongContent;
    final collapseReferences = prefs.collapseReferences;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final commentMemo = _commentingMemoUid == null ? null : _findMemoByUid(_commentingMemoUid!);
    final commentCreator = commentMemo == null ? null : _creatorCache[commentMemo.creator];
    final commentMode = commentMemo != null;
    final baseUrl = account?.baseUrl;
    final authHeader =
        (account?.personalAccessToken ?? '').isEmpty ? null : 'Bearer ${account!.personalAccessToken}';

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
                context.tr(zh: '加载失败', en: 'Failed to load'),
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
                child: Text(context.tr(zh: '重试', en: 'Retry')),
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
                context.tr(zh: '暂无内容', en: 'No content yet'),
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
              final metaLine = _creatorMetaLine(creator, memo.creator, dateText);
              final initial = _creatorInitial(creator, memo.creator);
              final avatarUrl = _resolveAvatarUrl(creator?.avatarUrl ?? '', baseUrl);
              final comments = _commentCache[memo.uid] ?? const <Memo>[];
              final commentError = _commentErrors[memo.uid];
              final commentsLoading = _commentLoading.contains(memo.uid);
              final commentCount = _commentCountFor(memo);
              final reactionCount = _reactionCountFor(memo);
              final isLiked = _hasMyReaction(memo);
              final hasOwnComment = _hasMyComment(memo);

              return _ExploreMemoCard(
                memo: memo,
                displayName: displayName,
                metaLine: metaLine,
                avatarUrl: avatarUrl,
                baseUrl: baseUrl,
                authHeader: authHeader,
                initial: initial,
                commentCount: commentCount,
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
                    label: Text(context.tr(zh: '加载更多', en: 'Load more')),
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

    final showSearchBar = _searchExpanded || _searchController.text.trim().isNotEmpty;
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
                        hintText: context.tr(zh: '搜索公开内容', en: 'Search public memos'),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _refresh(),
                    ),
                  ),
                  if (_searchController.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: context.tr(zh: '清除', en: 'Clear'),
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

    final replyCreator = _replyingMemoUid == commentMemo?.uid ? _replyingCommentCreator : null;
    final replyUser = replyCreator == null ? null : _creatorCache[replyCreator];
    final replyName = replyCreator == null ? '' : _creatorDisplayName(replyUser, replyCreator);
    final commentHint = commentMemo == null
        ? context.tr(zh: '写下评论...', en: 'Write a comment...')
        : replyCreator != null && replyName.isNotEmpty
            ? context.tr(zh: '回复 $replyName...', en: 'Reply $replyName...')
            : context.tr(
                zh: '回复 ${_creatorDisplayName(commentCreator, commentMemo.creator)}...',
                en: 'Reply ${_creatorDisplayName(commentCreator, commentMemo.creator)}...',
              );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _backToAllMemos(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        drawer: AppDrawer(
          selected: AppDrawerDestination.explore,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: textMain),
          title: Text(
            context.tr(zh: '探索', en: 'Explore'),
            style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
          ),
          actions: [
            IconButton(
              tooltip: showSearchBar ? context.tr(zh: '关闭搜索', en: 'Close search') : context.tr(zh: '搜索', en: 'Search'),
              icon: Icon(showSearchBar ? Icons.close : Icons.search, color: textMain),
              onPressed: _toggleSearch,
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                searchBar,
                if (_legacySearchLimited)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      context.tr(
                        zh: '旧版本服务器不支持搜索过滤，结果可能不完整。',
                        en: 'Legacy servers do not support search filters; results may be incomplete.',
                      ),
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
        ),
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
    required this.initial,
    required this.commentCount,
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
  final String initial;
  final int commentCount;
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
      final cleaned = lines.map((l) => l.replaceFirst(RegExp(r'^\s*>\s?'), '')).join('\n').trim();
      return cleaned.isEmpty ? trimmed : cleaned;
    }
    return '$main\n\n${trByLanguage(language: language, zh: '引用 $quoteLines 行', en: 'Quoted $quoteLines lines')}';
  }

  static ({String title, String body}) _splitTitleAndBody(String content) {
    final rawLines = content.split('\n');
    final tagBounds = _tagLineBounds(rawLines);
    final lines = <String>[];
    for (var i = 0; i < rawLines.length; i++) {
      if (i == tagBounds.first || i == tagBounds.last) continue;
      lines.add(rawLines[i]);
    }
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList(growable: false);
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
    final firstTag = (firstNonEmpty != null && _isTagOnlyLine(lines[firstNonEmpty])) ? firstNonEmpty : null;
    final lastTag = (lastNonEmpty != null && _isTagOnlyLine(lines[lastNonEmpty])) ? lastNonEmpty : null;
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

  static String _commentAuthor(BuildContext context, User? creator, String fallback) {
    final display = creator?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = creator?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final trimmed = fallback.trim();
    if (trimmed.startsWith('users/')) {
      return '${context.tr(zh: '用户', en: 'User')} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.tr(zh: '未知用户', en: 'Unknown') : trimmed;
  }

  bool _isImageAttachment(Attachment attachment) {
    final type = attachment.type.trim().toLowerCase();
    return type.startsWith('image');
  }

  String _resolveAttachmentUrl(Attachment attachment, {required bool thumbnail}) {
    final external = attachment.externalLink.trim();
    if (external.isNotEmpty) return external;
    final baseUrl = widget.baseUrl;
    if (baseUrl == null) return '';
    final url = joinBaseUrl(baseUrl, 'file/${attachment.name}/${attachment.filename}');
    return thumbnail ? '$url?thumbnail=true' : url;
  }

  void _openImagePreview(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: widget.authHeader == null ? null : {'Authorization': widget.authHeader!},
            placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem({
    required Memo comment,
    required Color textMain,
  }) {
    final images = comment.attachments.where(_isImageAttachment).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 12, color: textMain),
            children: [
              TextSpan(
                text: '${_commentAuthor(context, widget.resolveCreator(comment.creator), comment.creator)}: ',
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
          httpHeaders: widget.authHeader == null ? null : {'Authorization': widget.authHeader!},
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
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.initial,
        style: TextStyle(fontWeight: FontWeight.w700, color: textMuted),
      ),
    );

    final avatarUrl = widget.avatarUrl.trim();
    if (avatarUrl.isEmpty || avatarUrl.startsWith('data:')) return fallback;

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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.memo;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = widget.cardColor;
    final borderColor = widget.borderColor;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
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
    final preview = _truncatePreview(previewText, collapseLongContent: widget.collapseLongContent);
    final showToggle = preview.truncated;
    final showCollapsed = showToggle && !_expanded;
    final displayText = showCollapsed ? preview.text : previewText;
    final hasBody = displayText.trim().isNotEmpty;
    final showLike = widget.reactionCount > 0 || widget.isLiked;
    final showComment = widget.commentCount > 0 || widget.hasOwnComment;

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
                          style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MemoFlowPalette.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
              if (title.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain),
                ),
              ],
              if (hasBody) ...[
                const SizedBox(height: 6),
                MemoMarkdown(
                  data: displayText,
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textMain, height: 1.5),
                  blockSpacing: 4,
                  normalizeHeadings: true,
                ),
              ] else if (title.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  context.tr(zh: '无内容', en: 'No content'),
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
                      _expanded ? context.tr(zh: '收起', en: 'Collapse') : context.tr(zh: '展开', en: 'Expand'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MemoFlowPalette.primary),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(height: 1, color: borderColor.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (showLike)
                    _buildAction(
                      icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                      count: widget.reactionCount,
                      color: widget.isLiked ? MemoFlowPalette.primary : textMuted,
                      onTap: widget.onToggleLike,
                    ),
                  if (showLike && showComment) const SizedBox(width: 10),
                  if (showComment)
                    _buildAction(
                      icon: widget.hasOwnComment ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      count: widget.commentCount,
                      color: widget.hasOwnComment ? MemoFlowPalette.primary : textMuted,
                      onTap: widget.onToggleComment,
                    ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.more_horiz, size: 18, color: textMuted),
                    onPressed: widget.onMore,
                    tooltip: context.tr(zh: '更多', en: 'More'),
                  ),
                ],
              ),
              if (widget.isCommenting) ...[
                const SizedBox(height: 8),
                if (widget.commentsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                      context.tr(zh: '暂无评论', en: 'No comments yet'),
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.comments.length; i++) ...[
                        GestureDetector(
                          onTap: () => widget.onReplyComment(widget.memo, widget.comments[i]),
                          child: _buildCommentItem(comment: widget.comments[i], textMain: textMain),
                        ),
                        if (i != widget.comments.length - 1) const SizedBox(height: 6),
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
      createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
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
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  static (String label, IconData icon, Color color) _resolveStyle(BuildContext context, String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PUBLIC':
        return (
          context.tr(zh: '公开', en: 'Public'),
          Icons.public,
          const Color(0xFF3B8C52),
        );
      case 'PROTECTED':
        return (
          context.tr(zh: '受保护', en: 'Protected'),
          Icons.verified_user,
          const Color(0xFFB26A2B),
        );
      default:
        return (
          context.tr(zh: '私密', en: 'Private'),
          Icons.lock,
          const Color(0xFF7C7C7C),
        );
    }
  }
}
