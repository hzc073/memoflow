import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/memos_api.dart';
import '../../data/models/memo.dart';
import '../../data/models/reaction.dart';
import '../system/session_provider.dart';
import 'memos_providers.dart';

const kMemoLikeReactionType = '\u2764\uFE0F';

final memoEngagementClientProvider = Provider<MemoEngagementClient>((ref) {
  return _MemosApiMemoEngagementClient(ref);
});

final memoEngagementControllerProvider =
    StateNotifierProvider.family<
      MemoEngagementController,
      MemoEngagementState,
      MemoEngagementRequest
    >((ref, request) {
      return MemoEngagementController(
        ref: ref,
        client: ref.watch(memoEngagementClientProvider),
        request: request,
      );
    });

abstract class MemoEngagementClient {
  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})>
  listMemoReactions({required String memoUid, int pageSize = 50});

  Future<({List<Memo> memos, String nextPageToken, int totalSize})>
  listMemoComments({required String memoUid, int pageSize = 50});

  Future<Reaction> upsertMemoReaction({
    required String memoUid,
    required String reactionType,
  });

  Future<void> deleteMemoReaction({required Reaction reaction});

  Future<Memo> createMemoComment({
    required String memoUid,
    required String content,
    required String visibility,
  });
}

class _MemosApiMemoEngagementClient implements MemoEngagementClient {
  const _MemosApiMemoEngagementClient(this._ref);

  final Ref _ref;

  MemosApi get _api => _ref.read(memosApiProvider);

  @override
  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})>
  listMemoReactions({required String memoUid, int pageSize = 50}) {
    return _api.listMemoReactions(memoUid: memoUid, pageSize: pageSize);
  }

  @override
  Future<({List<Memo> memos, String nextPageToken, int totalSize})>
  listMemoComments({required String memoUid, int pageSize = 50}) {
    return _api.listMemoComments(memoUid: memoUid, pageSize: pageSize);
  }

  @override
  Future<Reaction> upsertMemoReaction({
    required String memoUid,
    required String reactionType,
  }) {
    return _api.upsertMemoReaction(
      memoUid: memoUid,
      reactionType: reactionType,
    );
  }

  @override
  Future<void> deleteMemoReaction({required Reaction reaction}) {
    return _api.deleteMemoReaction(reaction: reaction);
  }

  @override
  Future<Memo> createMemoComment({
    required String memoUid,
    required String content,
    required String visibility,
  }) {
    return _api.createMemoComment(
      memoUid: memoUid,
      content: content,
      visibility: visibility,
    );
  }
}

class MemoEngagementRequest {
  const MemoEngagementRequest({
    required this.memoUid,
    required this.memoVisibility,
  });

  final String memoUid;
  final String memoVisibility;

  String get normalizedMemoUid => memoUid.trim();

  String get normalizedMemoVisibility {
    final value = memoVisibility.trim();
    return value.isEmpty ? 'PUBLIC' : value;
  }

  @override
  bool operator ==(Object other) {
    return other is MemoEngagementRequest &&
        other.memoUid == memoUid &&
        other.memoVisibility == memoVisibility;
  }

  @override
  int get hashCode => Object.hash(memoUid, memoVisibility);
}

class MemoReactionSummary {
  const MemoReactionSummary({required this.reactionType, required this.count});

  final String reactionType;
  final int count;

  @override
  bool operator ==(Object other) {
    return other is MemoReactionSummary &&
        other.reactionType == reactionType &&
        other.count == count;
  }

  @override
  int get hashCode => Object.hash(reactionType, count);

  @override
  String toString() {
    return 'MemoReactionSummary(reactionType: $reactionType, count: $count)';
  }
}

class MemoEngagementSnapshot {
  const MemoEngagementSnapshot({
    this.reactions = const <Reaction>[],
    this.comments = const <Memo>[],
    this.likeTotal = 0,
    this.commentTotal = 0,
  });

  final List<Reaction> reactions;
  final List<Memo> comments;
  final int likeTotal;
  final int commentTotal;

  int get likeCount {
    if (likeTotal > 0) return likeTotal;
    return countMemoLikeCreators(reactions);
  }

  int get visibleCommentCount {
    if (commentTotal > 0) return commentTotal;
    return comments.length;
  }

  bool get hasEngagement {
    return likeCount > 0 ||
        visibleCommentCount > 0 ||
        otherReactionSummaries.isNotEmpty;
  }

  List<Reaction> get likeReactions {
    return reactions.where(isMemoLikeReaction).toList(growable: false);
  }

  List<MemoReactionSummary> get otherReactionSummaries {
    return memoOtherReactionSummaries(reactions);
  }

  bool hasUserLike(String currentUser) {
    return hasCurrentUserMemoLike(reactions, currentUser);
  }

  bool hasUserComment(String currentUser) {
    final normalized = currentUser.trim();
    if (normalized.isEmpty) return false;
    return comments.any((comment) => comment.creator.trim() == normalized);
  }

  MemoEngagementSnapshot copyWith({
    List<Reaction>? reactions,
    List<Memo>? comments,
    int? likeTotal,
    int? commentTotal,
  }) {
    return MemoEngagementSnapshot(
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
      likeTotal: likeTotal ?? this.likeTotal,
      commentTotal: commentTotal ?? this.commentTotal,
    );
  }
}

const Object _unset = Object();

class MemoEngagementState {
  const MemoEngagementState({
    this.snapshot = const MemoEngagementSnapshot(),
    this.reactionsLoaded = false,
    this.commentsLoaded = false,
    this.reactionsLoading = false,
    this.commentsLoading = false,
    this.reactionUpdating = false,
    this.commentSending = false,
    this.reactionsError,
    this.commentsError,
  });

  final MemoEngagementSnapshot snapshot;
  final bool reactionsLoaded;
  final bool commentsLoaded;
  final bool reactionsLoading;
  final bool commentsLoading;
  final bool reactionUpdating;
  final bool commentSending;
  final String? reactionsError;
  final String? commentsError;

  bool get loaded => reactionsLoaded && commentsLoaded;
  bool get loading => reactionsLoading || commentsLoading;

  MemoEngagementState copyWith({
    MemoEngagementSnapshot? snapshot,
    bool? reactionsLoaded,
    bool? commentsLoaded,
    bool? reactionsLoading,
    bool? commentsLoading,
    bool? reactionUpdating,
    bool? commentSending,
    Object? reactionsError = _unset,
    Object? commentsError = _unset,
  }) {
    return MemoEngagementState(
      snapshot: snapshot ?? this.snapshot,
      reactionsLoaded: reactionsLoaded ?? this.reactionsLoaded,
      commentsLoaded: commentsLoaded ?? this.commentsLoaded,
      reactionsLoading: reactionsLoading ?? this.reactionsLoading,
      commentsLoading: commentsLoading ?? this.commentsLoading,
      reactionUpdating: reactionUpdating ?? this.reactionUpdating,
      commentSending: commentSending ?? this.commentSending,
      reactionsError: identical(reactionsError, _unset)
          ? this.reactionsError
          : reactionsError as String?,
      commentsError: identical(commentsError, _unset)
          ? this.commentsError
          : commentsError as String?,
    );
  }
}

class MemoEngagementController extends StateNotifier<MemoEngagementState> {
  MemoEngagementController({
    required Ref ref,
    required MemoEngagementClient client,
    required MemoEngagementRequest request,
  }) : _ref = ref,
       _client = client,
       _request = request,
       super(const MemoEngagementState());

  final Ref _ref;
  final MemoEngagementClient _client;
  final MemoEngagementRequest _request;

  Future<void>? _reactionsLoadFuture;
  Future<void>? _commentsLoadFuture;

  Future<void> load({bool force = false}) async {
    await Future.wait(<Future<void>>[
      loadReactions(force: force),
      loadComments(force: force),
    ]);
  }

  Future<void> loadReactions({bool force = false}) {
    final uid = _request.normalizedMemoUid;
    if (uid.isEmpty) return Future<void>.value();
    if (!force && state.reactionsLoaded) return Future<void>.value();
    final inFlight = _reactionsLoadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadReactions(uid);
    _reactionsLoadFuture = future;
    future.whenComplete(() {
      if (identical(_reactionsLoadFuture, future)) {
        _reactionsLoadFuture = null;
      }
    });
    return future;
  }

  Future<void> loadComments({bool force = false}) {
    final uid = _request.normalizedMemoUid;
    if (uid.isEmpty) return Future<void>.value();
    if (!force && state.commentsLoaded) return Future<void>.value();
    final inFlight = _commentsLoadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadComments(uid);
    _commentsLoadFuture = future;
    future.whenComplete(() {
      if (identical(_commentsLoadFuture, future)) {
        _commentsLoadFuture = null;
      }
    });
    return future;
  }

  Future<void> _loadReactions(String uid) async {
    state = state.copyWith(reactionsLoading: true, reactionsError: null);
    try {
      final result = await _client.listMemoReactions(
        memoUid: uid,
        pageSize: 50,
      );
      final reactions = result.reactions;
      state = state.copyWith(
        snapshot: state.snapshot.copyWith(
          reactions: reactions,
          likeTotal: countMemoLikeCreators(reactions),
        ),
        reactionsLoaded: true,
        reactionsError: null,
      );
    } catch (error) {
      state = state.copyWith(reactionsError: error.toString());
    } finally {
      state = state.copyWith(reactionsLoading: false);
    }
  }

  Future<void> _loadComments(String uid) async {
    state = state.copyWith(commentsLoading: true, commentsError: null);
    try {
      final result = await _client.listMemoComments(memoUid: uid, pageSize: 50);
      final comments = result.memos;
      final total = result.totalSize > 0 ? result.totalSize : comments.length;
      state = state.copyWith(
        snapshot: state.snapshot.copyWith(
          comments: comments,
          commentTotal: total,
        ),
        commentsLoaded: true,
        commentsError: null,
      );
    } catch (error) {
      state = state.copyWith(commentsError: error.toString());
    } finally {
      state = state.copyWith(commentsLoading: false);
    }
  }

  Future<void> toggleLike() async {
    final uid = _request.normalizedMemoUid;
    if (uid.isEmpty || state.reactionUpdating) return;
    final currentUser = _currentUserName();
    if (currentUser.isEmpty) return;

    final previous = List<Reaction>.from(state.snapshot.reactions);
    final mine = previous
        .where(
          (reaction) =>
              isMemoLikeReaction(reaction) &&
              reaction.creator.trim() == currentUser,
        )
        .toList(growable: false);

    state = state.copyWith(reactionUpdating: true);
    try {
      if (mine.isNotEmpty) {
        final updated = previous
            .where((reaction) => !mine.contains(reaction))
            .toList(growable: false);
        _updateReactions(updated);
        for (final reaction in mine) {
          await _client.deleteMemoReaction(reaction: reaction);
        }
      } else {
        final optimistic = Reaction(
          name: '',
          creator: currentUser,
          contentId: 'memos/$uid',
          reactionType: kMemoLikeReactionType,
        );
        final updated = [...previous, optimistic];
        _updateReactions(updated);
        final created = await _client.upsertMemoReaction(
          memoUid: uid,
          reactionType: kMemoLikeReactionType,
        );
        final current = List<Reaction>.from(state.snapshot.reactions);
        final index = current.indexWhere(
          (reaction) =>
              isMemoLikeReaction(reaction) &&
              reaction.creator.trim() == currentUser &&
              reaction.name.trim().isEmpty,
        );
        if (index >= 0) {
          current[index] = created;
        } else {
          current.add(created);
        }
        _updateReactions(current);
      }
    } catch (_) {
      _updateReactions(previous);
      rethrow;
    } finally {
      state = state.copyWith(reactionUpdating: false);
    }
  }

  Future<Memo?> createComment(String content) async {
    final uid = _request.normalizedMemoUid;
    final trimmed = content.trim();
    if (uid.isEmpty || trimmed.isEmpty || state.commentSending) return null;

    state = state.copyWith(commentSending: true);
    try {
      final created = await _client.createMemoComment(
        memoUid: uid,
        content: trimmed,
        visibility: _request.normalizedMemoVisibility,
      );
      final comments = <Memo>[created, ...state.snapshot.comments];
      final currentTotal = state.snapshot.visibleCommentCount;
      state = state.copyWith(
        snapshot: state.snapshot.copyWith(
          comments: comments,
          commentTotal: currentTotal + 1,
        ),
        commentsLoaded: true,
        commentsError: null,
      );
      return created;
    } catch (_) {
      rethrow;
    } finally {
      state = state.copyWith(commentSending: false);
    }
  }

  void _updateReactions(List<Reaction> reactions) {
    state = state.copyWith(
      snapshot: state.snapshot.copyWith(
        reactions: reactions,
        likeTotal: countMemoLikeCreators(reactions),
      ),
      reactionsLoaded: true,
      reactionsError: null,
    );
  }

  String _currentUserName() {
    return _ref
            .read(appSessionProvider)
            .valueOrNull
            ?.currentAccount
            ?.user
            .name
            .trim() ??
        '';
  }
}

bool isMemoLikeReaction(Reaction reaction) {
  final type = reaction.reactionType.trim();
  return type == kMemoLikeReactionType || type == 'HEART';
}

int countMemoLikeCreators(Iterable<Reaction> reactions) {
  final creators = <String>{};
  for (final reaction in reactions) {
    if (!isMemoLikeReaction(reaction)) continue;
    final creator = reaction.creator.trim();
    if (creator.isEmpty) continue;
    creators.add(creator);
  }
  return creators.length;
}

bool hasCurrentUserMemoLike(Iterable<Reaction> reactions, String currentUser) {
  final normalized = currentUser.trim();
  if (normalized.isEmpty) return false;
  return reactions.any(
    (reaction) =>
        isMemoLikeReaction(reaction) && reaction.creator.trim() == normalized,
  );
}

List<Reaction> uniqueMemoCreatorReactions(Iterable<Reaction> reactions) {
  final seen = <String>{};
  final unique = <Reaction>[];
  for (final reaction in reactions) {
    final creator = reaction.creator.trim();
    if (creator.isEmpty) continue;
    if (seen.add(creator)) {
      unique.add(reaction);
    }
  }
  return unique;
}

List<MemoReactionSummary> memoOtherReactionSummaries(
  Iterable<Reaction> reactions,
) {
  final creatorsByType = <String, Set<String>>{};
  final anonymousCounts = <String, int>{};
  for (final reaction in reactions) {
    if (isMemoLikeReaction(reaction)) continue;
    final type = reaction.reactionType.trim();
    if (type.isEmpty) continue;
    final creator = reaction.creator.trim();
    if (creator.isEmpty) {
      anonymousCounts[type] = (anonymousCounts[type] ?? 0) + 1;
      continue;
    }
    creatorsByType.putIfAbsent(type, () => <String>{}).add(creator);
  }

  final summaries = <MemoReactionSummary>[];
  for (final entry in creatorsByType.entries) {
    summaries.add(
      MemoReactionSummary(reactionType: entry.key, count: entry.value.length),
    );
  }
  for (final entry in anonymousCounts.entries) {
    final index = summaries.indexWhere(
      (summary) => summary.reactionType == entry.key,
    );
    if (index >= 0) {
      final current = summaries[index];
      summaries[index] = MemoReactionSummary(
        reactionType: current.reactionType,
        count: current.count + entry.value,
      );
    } else {
      summaries.add(
        MemoReactionSummary(reactionType: entry.key, count: entry.value),
      );
    }
  }
  summaries.sort((a, b) {
    final countCompare = b.count.compareTo(a.count);
    if (countCompare != 0) return countCompare;
    return a.reactionType.compareTo(b.reactionType);
  });
  return summaries;
}
