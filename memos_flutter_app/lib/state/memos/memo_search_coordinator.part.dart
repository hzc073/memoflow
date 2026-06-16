part of 'memos_providers.dart';

final memoSearchCoordinatorProvider = Provider<MemoSearchCoordinator>((ref) {
  return MemoSearchCoordinator(ref);
});

class MemoSearchCoordinator {
  MemoSearchCoordinator(this._ref);

  final Ref _ref;

  Stream<List<LocalMemo>> watchLocalMemos(MemosQuery query) {
    final search = MemoSearchMatcher.normalizeQuery(query.searchQuery);
    final pageSize = query.pageSize > 0 ? query.pageSize : 200;
    final advancedFilters = query.advancedFilters.normalized();
    final localCandidateLimit = _localCandidateLimitForAdvancedFilters(
      advancedFilters,
      pageSize,
    );
    final searchFilters = _memoSearchDbFiltersForAdvancedFilters(
      advancedFilters,
    );
    final db = _ref.read(databaseProvider);
    return db
        .watchMemos(
          searchQuery: search.isEmpty ? null : search,
          state: query.state,
          tag: query.tag,
          startTimeSec: query.startTimeSec,
          endTimeSecExclusive: query.endTimeSecExclusive,
          sortOrder: query.sortOrder,
          limit: localCandidateLimit,
          searchFilters: searchFilters,
        )
        .map(
          (rows) => _applyAdvancedFiltersToRows(
            rows,
            advancedFilters,
            pageSize: pageSize,
          ),
        );
  }

  Stream<List<LocalMemo>> _watchLocalFilteredMemos({
    required String searchQuery,
    required String state,
    required String? tag,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required AdvancedSearchFilters advancedFilters,
    required int pageSize,
    required int? candidateLimit,
    required _MemoPredicate predicate,
  }) {
    final db = _ref.read(databaseProvider);
    final normalizedSearch = MemoSearchMatcher.normalizeQuery(searchQuery);
    final normalizedTag = _normalizeTagInput(tag);
    final normalizedFilters = advancedFilters.normalized();
    final searchFilters = _memoSearchDbFiltersForAdvancedFilters(
      normalizedFilters,
    );
    return db
        .watchMemos(
          searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
          state: state,
          tag: normalizedTag.isEmpty ? null : normalizedTag,
          startTimeSec: startTimeSec,
          endTimeSecExclusive: endTimeSecExclusive,
          limit: candidateLimit,
          searchFilters: searchFilters,
        )
        .map((rows) {
          final filtered = _filterShortcutMemosFromRows(rows, predicate);
          return _applyAdvancedFiltersToMemos(
            filtered,
            normalizedFilters,
            pageSize: pageSize,
          );
        });
  }

  Future<List<LocalMemo>> loadRemoteSearchSeed({
    required MemosQuery query,
  }) async {
    final db = _ref.read(databaseProvider);
    final account = _ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      return watchLocalMemos(query).first;
    }

    final api = _ref.read(memosApiProvider);
    final logManager = _ref.read(logManagerProvider);
    await api.ensureServerHintsLoaded();

    final normalizedSearch = MemoSearchMatcher.normalizeQuery(
      query.searchQuery,
    );
    final normalizedTag = _normalizeTagInput(query.tag);
    final pageSize = query.pageSize > 0 ? query.pageSize : 200;
    final advancedFilters = query.advancedFilters.normalized();
    final localCandidateLimit = _localCandidateLimitForAdvancedFilters(
      advancedFilters,
      pageSize,
    );
    final startTimeSec = query.startTimeSec;
    final endTimeSecExclusive = query.endTimeSecExclusive;

    final filters = <String>[];
    final currentUserName = account.user.name.trim();
    final creatorId = _parseUserId(currentUserName);
    final creatorFilter = creatorId == null
        ? null
        : _buildCreatorFilterExpression(
            creatorId: creatorId,
            useLegacyDialect: api.usesLegacySearchFilterDialect,
          );
    if (creatorFilter != null) {
      filters.add(creatorFilter);
    }
    if (normalizedSearch.isNotEmpty) {
      filters.add(
        'content.contains("${_escapeFilterValue(normalizedSearch)}")',
      );
    }
    if (normalizedTag.isNotEmpty) {
      filters.add('tag in ["${_escapeFilterValue(normalizedTag)}"]');
    }
    if (startTimeSec != null) {
      filters.add('created_ts >= $startTimeSec');
    }
    if (endTimeSecExclusive != null) {
      final endInclusive = endTimeSecExclusive - 1;
      if (endInclusive >= 0) {
        filters.add('created_ts <= $endInclusive');
      }
    }

    final filter = filters.isEmpty ? null : filters.join(' && ');
    final requiresCreatorScopedList = api.requiresCreatorScopedListMemos;
    final useLegacySearchFallback =
        api.usesLegacyMemos || api.usesLegacySearchFilterDialect;
    final effectiveFilter = api.usesLegacyMemos
        ? creatorFilter
        : (useLegacySearchFallback
              ? (requiresCreatorScopedList ? creatorFilter : null)
              : filter);

    final traceId = DateTime.now().microsecondsSinceEpoch.toString();
    logManager.info(
      'Search flow started',
      context: {
        'traceId': traceId,
        'state': query.state,
        'queryLength': normalizedSearch.length,
        'tag': normalizedTag,
        'pageSize': pageSize,
        'creatorId': creatorId,
        'startTimeSec': startTimeSec,
        'endTimeSecExclusive': endTimeSecExclusive,
        'legacySearchFallback': useLegacySearchFallback,
      },
    );

    try {
      final localMatches = await _loadLocalSearchMemos(
        db: db,
        searchQuery: normalizedSearch,
        state: query.state,
        tag: normalizedTag.isEmpty ? null : normalizedTag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        advancedFilters: advancedFilters,
        candidateLimit: localCandidateLimit,
        sortOrder: query.sortOrder,
      );
      final matchedLocalMemoKeys = localMatches
          .map(_memoLocalKey)
          .where((key) => key.isNotEmpty)
          .toSet();
      final results = <LocalMemo>[];
      final seenMemoKeys = <String>{};
      final targetCount = pageSize > 0 ? pageSize : 200;
      var nextPageToken = '';
      var useLegacyV2Search =
          useLegacySearchFallback && normalizedSearch.isNotEmpty;
      var legacyV2SearchCompleted = false;
      var requestPages = 0;
      var remoteFetchedCount = 0;
      var dedupSkippedCount = 0;
      var filteredOutCount = 0;
      var dbHitCount = 0;
      var dbMissCount = 0;

      while (results.length < targetCount) {
        List<Memo> memos = const <Memo>[];
        var nextToken = '';

        if (useLegacyV2Search && !legacyV2SearchCompleted) {
          requestPages += 1;
          logManager.debug(
            'Search request page',
            context: {
              'traceId': traceId,
              'page': requestPages,
              'mode': 'legacy_v2_search',
              'requestSize': targetCount,
            },
          );
          try {
            memos = await api.searchMemosLegacyV2(
              searchQuery: normalizedSearch,
              creatorId: creatorId,
              state: query.state,
              tag: normalizedTag.isEmpty ? null : normalizedTag,
              startTimeSec: startTimeSec,
              endTimeSecExclusive: endTimeSecExclusive,
              limit: targetCount,
            );
            legacyV2SearchCompleted = true;
            logManager.debug(
              'Search response page',
              context: {
                'traceId': traceId,
                'page': requestPages,
                'mode': 'legacy_v2_search',
                'returned': memos.length,
              },
            );
          } on DioException catch (e) {
            final status = e.response?.statusCode;
            if (status == 404 || status == 405 || status == 400) {
              logManager.warn(
                'Legacy v2 search fallback to list',
                context: {
                  'traceId': traceId,
                  'page': requestPages,
                  'status': status,
                },
              );
              useLegacyV2Search = false;
              continue;
            }
            if (status == null && _shouldFallbackShortcutFilter(e)) {
              logManager.warn(
                'Legacy v2 search network fallback to list',
                context: {'traceId': traceId, 'page': requestPages},
              );
              useLegacyV2Search = false;
              continue;
            }
            rethrow;
          } on FormatException catch (error, stackTrace) {
            logManager.warn(
              'Legacy v2 search parse failed, fallback to list',
              error: error,
              stackTrace: stackTrace,
              context: {'traceId': traceId, 'page': requestPages},
            );
            useLegacyV2Search = false;
            continue;
          }
        } else {
          requestPages += 1;
          final requestSize = targetCount - results.length;
          logManager.debug(
            'Search request page',
            context: {
              'traceId': traceId,
              'page': requestPages,
              'mode': 'list_memos',
              'requestSize': requestSize > 0 ? requestSize : targetCount,
              'pageToken': _searchTokenPreview(nextPageToken),
            },
          );
          final (listed, listedNextToken) = await api.listMemos(
            pageSize: requestSize > 0 ? requestSize : targetCount,
            pageToken: nextPageToken.isEmpty ? null : nextPageToken,
            state: query.state,
            filter: effectiveFilter,
            orderBy: 'display_time desc',
          );
          memos = listed;
          nextToken = listedNextToken;
          logManager.debug(
            'Search response page',
            context: {
              'traceId': traceId,
              'page': requestPages,
              'mode': 'list_memos',
              'returned': listed.length,
              'nextPageToken': _searchTokenPreview(nextToken),
            },
          );
        }

        if (memos.isEmpty) {
          break;
        }

        for (final memo in memos) {
          remoteFetchedCount += 1;
          final memoKey = _memoRemoteKey(memo);
          if (memoKey.isNotEmpty && !seenMemoKeys.add(memoKey)) {
            dedupSkippedCount += 1;
            continue;
          }

          if (!_matchesRemoteSearchMemoLocally(
            memo: memo,
            currentUserName: currentUserName,
            currentUserId: creatorId,
            normalizedSearch: normalizedSearch,
            normalizedTag: normalizedTag,
            startTimeSec: startTimeSec,
            endTimeSecExclusive: endTimeSecExclusive,
            matchedLocalMemoKeys: matchedLocalMemoKeys,
          )) {
            filteredOutCount += 1;
            continue;
          }

          final uid = memo.uid.trim();
          LocalMemo localMemo;
          if (uid.isNotEmpty) {
            final row = await db.getMemoByUid(uid);
            if (row != null) {
              localMemo = LocalMemo.fromDb(row);
              dbHitCount += 1;
            } else {
              localMemo = _localMemoFromRemote(memo);
              dbMissCount += 1;
            }
          } else {
            localMemo = _localMemoFromRemote(memo);
            dbMissCount += 1;
          }

          if (!advancedFilters.matches(localMemo)) {
            filteredOutCount += 1;
            continue;
          }

          results.add(localMemo);
          if (results.length >= targetCount) {
            break;
          }
        }

        if (results.length >= targetCount || useLegacyV2Search) {
          break;
        }
        if (nextToken.isEmpty) {
          break;
        }
        nextPageToken = nextToken;
      }

      logManager.info(
        'Search flow completed',
        context: {
          'traceId': traceId,
          'resultCount': results.length,
          'targetCount': targetCount,
          'requestPages': requestPages,
          'remoteFetched': remoteFetchedCount,
          'dedupSkipped': dedupSkippedCount,
          'filteredOut': filteredOutCount,
          'dbHit': dbHitCount,
          'dbMiss': dbMissCount,
          'usedLegacyV2Search': legacyV2SearchCompleted,
        },
      );

      return _mergeRemoteSearchSeedWithLocalMatches(
        seed: results,
        localMatches: localMatches,
        advancedFilters: advancedFilters,
        pageSize: pageSize,
      );
    } catch (error, stackTrace) {
      logManager.warn(
        'Search flow failed, fallback to local cache',
        error: error,
        stackTrace: stackTrace,
        context: {
          'traceId': traceId,
          'state': query.state,
          'queryLength': normalizedSearch.length,
          'tag': normalizedTag,
          'pageSize': pageSize,
        },
      );
      final rows = await db.listMemos(
        searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
        state: query.state,
        tag: normalizedTag.isEmpty ? null : normalizedTag,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
        sortOrder: query.sortOrder,
        limit: localCandidateLimit,
        searchFilters: _memoSearchDbFiltersForAdvancedFilters(advancedFilters),
      );
      final seed = _applyAdvancedFiltersToRows(
        rows,
        advancedFilters,
        pageSize: pageSize,
      );
      logManager.info(
        'Search local fallback completed',
        context: {'traceId': traceId, 'resultCount': seed.length},
      );
      return seed;
    }
  }

  Future<List<LocalMemo>> refreshRemoteSearchResults({
    required List<LocalMemo> seed,
    required MemosQuery query,
  }) async {
    final db = _ref.read(databaseProvider);
    final normalizedSearch = MemoSearchMatcher.normalizeQuery(
      query.searchQuery,
    );
    final normalizedTag = _normalizeTagInput(query.tag);
    final pageSize = query.pageSize > 0 ? query.pageSize : 200;
    final advancedFilters = query.advancedFilters.normalized();
    final localCandidateLimit = _localCandidateLimitForAdvancedFilters(
      advancedFilters,
      pageSize,
    );
    final refreshed = await _refreshRemoteSeedWithLocal(seed: seed, db: db);
    final localMatches = await _loadLocalSearchMemos(
      db: db,
      searchQuery: normalizedSearch,
      state: query.state,
      tag: normalizedTag.isEmpty ? null : normalizedTag,
      startTimeSec: query.startTimeSec,
      endTimeSecExclusive: query.endTimeSecExclusive,
      advancedFilters: advancedFilters,
      candidateLimit: localCandidateLimit,
      sortOrder: query.sortOrder,
    );
    return _mergeRemoteSearchSeedWithLocalMatches(
      seed: refreshed,
      localMatches: localMatches,
      advancedFilters: advancedFilters,
      pageSize: pageSize,
    );
  }

  Future<List<LocalMemo>> loadShortcutRemoteSeed({
    required ShortcutMemosQuery query,
  }) async {
    final db = _ref.read(databaseProvider);
    final account = _ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      return const <LocalMemo>[];
    }

    final api = _ref.read(memosApiProvider);
    await api.ensureServerHintsLoaded();
    final creatorId = _parseUserId(account.user.name);
    final parent = _buildShortcutParent(creatorId);
    final pageSize = query.pageSize > 0 ? query.pageSize : 200;
    final advancedFilters = query.advancedFilters.normalized();
    const int? localCandidateLimit = null;
    final filter = _buildShortcutFilter(
      creatorId: creatorId,
      searchQuery: query.searchQuery,
      tag: query.tag,
      shortcutFilter: query.shortcutFilter,
      startTimeSec: query.startTimeSec,
      endTimeSecExclusive: query.endTimeSecExclusive,
      includeCreatorId: parent == null || !api.supportsMemoParentQuery,
      useLegacyDialect: api.usesLegacySearchFilterDialect,
    );

    try {
      final (memos, _) = await api.listMemos(
        pageSize: pageSize,
        state: query.state,
        filter: filter,
        parent: parent,
      );

      final results = <LocalMemo>[];
      for (final memo in memos) {
        final uid = memo.uid.trim();
        LocalMemo localMemo;
        if (uid.isNotEmpty) {
          final row = await db.getMemoByUid(uid);
          if (row != null) {
            localMemo = LocalMemo.fromDb(row);
          } else {
            localMemo = _localMemoFromRemote(memo);
          }
        } else {
          localMemo = _localMemoFromRemote(memo);
        }
        if (!advancedFilters.matches(localMemo)) continue;
        results.add(localMemo);
      }

      return _applyAdvancedFiltersToMemos(
        _sortShortcutMemos(results),
        advancedFilters,
        pageSize: pageSize,
      );
    } on DioException catch (e) {
      if (!_shouldFallbackShortcutFilter(e)) rethrow;
      final local = await _tryListShortcutMemosLocally(
        db: db,
        searchQuery: query.searchQuery,
        state: query.state,
        tag: query.tag,
        shortcutFilter: query.shortcutFilter,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
        advancedFilters: advancedFilters,
        candidateLimit: localCandidateLimit,
      );
      if (local == null) rethrow;
      return _applyAdvancedFiltersToMemos(
        local,
        advancedFilters,
        pageSize: pageSize,
      );
    }
  }

  Future<List<LocalMemo>> refreshShortcutResults({
    required List<LocalMemo> seed,
    required ShortcutMemosQuery query,
  }) async {
    final advancedFilters = query.advancedFilters.normalized();
    final pageSize = query.pageSize > 0 ? query.pageSize : 200;
    final refreshed = await _refreshShortcutSeedWithLocal(
      seed: seed,
      db: _ref.read(databaseProvider),
    );
    return _applyAdvancedFiltersToMemos(
      refreshed,
      advancedFilters,
      pageSize: pageSize,
    );
  }

  Future<List<Memo>> loadLinkMemos({required String query}) async {
    final db = _ref.read(databaseProvider);
    final account = _ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final userName = account?.user.name ?? '';
    final normalizedQuery = MemoSearchMatcher.normalizeQuery(query);

    final localRows = await db.listMemos(
      searchQuery: normalizedQuery.isEmpty ? null : normalizedQuery,
      state: 'NORMAL',
      tag: null,
      startTimeSec: null,
      endTimeSecExclusive: null,
      limit: 200,
    );
    final localMemos = localRows
        .map(LocalMemo.fromDb)
        .map(_memoFromLocal)
        .toList(growable: false);

    if (account == null) {
      return localMemos;
    }

    final matchedLocalUids = localMemos
        .map((memo) => memo.uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();

    final api = _ref.read(memosApiProvider);
    await api.ensureServerHintsLoaded();
    String? filter;
    String? oldFilter;
    String? parent;

    if (api.useLegacyApi) {
      if (userName.isNotEmpty) {
        parent = userName;
      }
      if (normalizedQuery.isNotEmpty) {
        oldFilter = 'content_search == [${jsonEncode(normalizedQuery)}]';
      }
    } else {
      final userId = _parseUserId(userName);
      final conditions = <String>[];
      if (userId != null) {
        conditions.add(
          _buildCreatorFilterExpression(
            creatorId: userId,
            useLegacyDialect: api.usesLegacySearchFilterDialect,
          ),
        );
      }
      if (normalizedQuery.isNotEmpty) {
        final escaped = _escapeFilterValue(normalizedQuery);
        conditions.add('content.contains("$escaped")');
      }
      if (conditions.isNotEmpty) {
        filter = conditions.join(' && ');
      }
    }

    try {
      final (remoteMemos, _) = await api.listMemos(
        pageSize: 200,
        filter: filter,
        oldFilter: oldFilter,
        parent: parent,
        preferModern: true,
      );
      final merged = <Memo>[];
      final seen = <String>{};

      void addMemo(Memo memo) {
        final key = memo.uid.trim().isEmpty
            ? memo.name.trim()
            : memo.uid.trim();
        if (key.isNotEmpty && !seen.add(key)) return;
        merged.add(memo);
      }

      for (final memo in remoteMemos) {
        if (normalizedQuery.isNotEmpty) {
          final uid = memo.uid.trim();
          final matchedLocally =
              uid.isNotEmpty && matchedLocalUids.contains(uid);
          if (!matchedLocally &&
              !MemoSearchMatcher.matchesText(
                text: MemoSearchDocumentBuilder.buildCanonical(
                  content: memo.content,
                  tagsText: memo.tags.join(' '),
                ),
                query: normalizedQuery,
              )) {
            continue;
          }
        }
        addMemo(memo);
      }

      for (final memo in localMemos) {
        addMemo(memo);
      }

      return merged;
    } on DioException {
      return localMemos;
    }
  }
}

Memo _memoFromLocal(LocalMemo memo) {
  final uid = memo.uid.trim();
  final name = uid.isEmpty ? '' : 'memos/$uid';
  return Memo(
    name: name,
    creator: '',
    content: memo.content,
    contentFingerprint: memo.contentFingerprint,
    visibility: memo.visibility,
    pinned: memo.pinned,
    state: memo.state,
    createTime: memo.createTime,
    updateTime: memo.updateTime,
    tags: memo.tags,
    attachments: memo.attachments,
    location: memo.location,
  );
}
