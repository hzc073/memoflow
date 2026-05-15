import 'dart:async';
import 'dart:math' as math;

import '../../data/models/memo_collection.dart';
import '../../data/models/rss_feed.dart';
import '../../data/repositories/rss_repository.dart';
import 'rss_feed_fetch_service.dart';

enum RssRefreshTrigger { collectionOpen }

class RssFeedRefreshFailure {
  const RssFeedRefreshFailure({
    required this.feedId,
    required this.feedTitle,
    required this.error,
  });

  final String feedId;
  final String feedTitle;
  final String error;
}

class RssCollectionOpenRefreshResult {
  const RssCollectionOpenRefreshResult({
    required this.collectionId,
    required this.trigger,
    required this.enabled,
    required this.coalesced,
    required this.startedAt,
    required this.completedAt,
    required this.consideredFeedCount,
    required this.staleFeedCount,
    required this.successCount,
    required this.failureCount,
    required this.failures,
  });

  final String collectionId;
  final RssRefreshTrigger trigger;
  final bool enabled;
  final bool coalesced;
  final DateTime startedAt;
  final DateTime completedAt;
  final int consideredFeedCount;
  final int staleFeedCount;
  final int successCount;
  final int failureCount;
  final List<RssFeedRefreshFailure> failures;

  int get skippedFeedCount => math.max(0, consideredFeedCount - staleFeedCount);

  bool get refreshedAny => successCount > 0 || failureCount > 0;

  RssCollectionOpenRefreshResult copyWith({bool? coalesced}) {
    return RssCollectionOpenRefreshResult(
      collectionId: collectionId,
      trigger: trigger,
      enabled: enabled,
      coalesced: coalesced ?? this.coalesced,
      startedAt: startedAt,
      completedAt: completedAt,
      consideredFeedCount: consideredFeedCount,
      staleFeedCount: staleFeedCount,
      successCount: successCount,
      failureCount: failureCount,
      failures: failures,
    );
  }
}

class RssRefreshCoordinator {
  RssRefreshCoordinator({
    required RssRepository repository,
    required RssFeedFetchService fetchService,
    DateTime Function()? now,
    int maxConcurrentFeeds = 3,
  }) : _repository = repository,
       _fetchService = fetchService,
       _now = now ?? DateTime.now,
       _maxConcurrentFeeds = math.max(1, maxConcurrentFeeds);

  final RssRepository _repository;
  final RssFeedFetchService _fetchService;
  final DateTime Function() _now;
  final int _maxConcurrentFeeds;
  final Map<String, Future<RssCollectionOpenRefreshResult>>
  _activeCollectionRuns = <String, Future<RssCollectionOpenRefreshResult>>{};

  Future<RssCollectionOpenRefreshResult> refreshCollectionOnOpen({
    required String collectionId,
    required CollectionRssRefreshPreferences preferences,
  }) {
    final normalizedCollectionId = collectionId.trim();
    final startedAt = _now();
    if (normalizedCollectionId.isEmpty || !preferences.enabled) {
      final now = _now();
      return Future<RssCollectionOpenRefreshResult>.value(
        RssCollectionOpenRefreshResult(
          collectionId: normalizedCollectionId,
          trigger: RssRefreshTrigger.collectionOpen,
          enabled: preferences.enabled,
          coalesced: false,
          startedAt: startedAt,
          completedAt: now,
          consideredFeedCount: 0,
          staleFeedCount: 0,
          successCount: 0,
          failureCount: 0,
          failures: const <RssFeedRefreshFailure>[],
        ),
      );
    }

    final active = _activeCollectionRuns[normalizedCollectionId];
    if (active != null) {
      return active.then((result) => result.copyWith(coalesced: true));
    }

    final run = _refreshCollectionOnOpen(
      collectionId: normalizedCollectionId,
      preferences: preferences,
      startedAt: startedAt,
    );
    _activeCollectionRuns[normalizedCollectionId] = run;
    unawaited(
      run.whenComplete(() {
        if (_activeCollectionRuns[normalizedCollectionId] == run) {
          _activeCollectionRuns.remove(normalizedCollectionId);
        }
      }),
    );
    return run;
  }

  Future<RssCollectionOpenRefreshResult> _refreshCollectionOnOpen({
    required String collectionId,
    required CollectionRssRefreshPreferences preferences,
    required DateTime startedAt,
  }) async {
    final sources = await _repository.listCollectionRssSources(collectionId);
    final interval = preferences.interval;
    final staleFeeds = sources
        .map((source) => source.feed)
        .where(
          (feed) => isRssFeedStaleForRefresh(
            feed,
            now: startedAt,
            interval: interval,
          ),
        )
        .toList(growable: false);
    if (staleFeeds.isEmpty) {
      final completedAt = _now();
      return RssCollectionOpenRefreshResult(
        collectionId: collectionId,
        trigger: RssRefreshTrigger.collectionOpen,
        enabled: preferences.enabled,
        coalesced: false,
        startedAt: startedAt,
        completedAt: completedAt,
        consideredFeedCount: sources.length,
        staleFeedCount: 0,
        successCount: 0,
        failureCount: 0,
        failures: const <RssFeedRefreshFailure>[],
      );
    }

    final failures = <RssFeedRefreshFailure>[];
    var successCount = 0;
    await _refreshFeedsBounded(
      staleFeeds,
      onSuccess: () => successCount += 1,
      onFailure: failures.add,
    );
    final completedAt = _now();
    return RssCollectionOpenRefreshResult(
      collectionId: collectionId,
      trigger: RssRefreshTrigger.collectionOpen,
      enabled: preferences.enabled,
      coalesced: false,
      startedAt: startedAt,
      completedAt: completedAt,
      consideredFeedCount: sources.length,
      staleFeedCount: staleFeeds.length,
      successCount: successCount,
      failureCount: failures.length,
      failures: List<RssFeedRefreshFailure>.unmodifiable(failures),
    );
  }

  Future<void> _refreshFeedsBounded(
    List<RssFeed> feeds, {
    required VoidCallback onSuccess,
    required void Function(RssFeedRefreshFailure failure) onFailure,
  }) async {
    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex += 1;
        if (index >= feeds.length) return;
        final feed = feeds[index];
        try {
          await _fetchService.refreshFeed(feed);
          onSuccess();
        } catch (error) {
          onFailure(
            RssFeedRefreshFailure(
              feedId: feed.id,
              feedTitle: feed.displayTitle,
              error: error.toString(),
            ),
          );
        }
      }
    }

    final workerCount = math.min(_maxConcurrentFeeds, feeds.length);
    await Future.wait<void>([
      for (var i = 0; i < workerCount; i += 1) worker(),
    ]);
  }
}

typedef VoidCallback = void Function();

bool isRssFeedStaleForRefresh(
  RssFeed feed, {
  required DateTime now,
  required Duration interval,
}) {
  if (interval <= Duration.zero) return true;
  final lastAttempt = latestRssFeedRefreshAttempt(feed);
  if (lastAttempt == null) return true;
  if (lastAttempt.isAfter(now)) return false;
  return now.difference(lastAttempt) >= interval;
}

DateTime? latestRssFeedRefreshAttempt(RssFeed feed) {
  final fetch = feed.lastFetchTime;
  final success = feed.lastSuccessTime;
  if (fetch == null) return success;
  if (success == null) return fetch;
  return fetch.isAfter(success) ? fetch : success;
}
