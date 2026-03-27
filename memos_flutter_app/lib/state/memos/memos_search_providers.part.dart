part of 'memos_providers.dart';

final memosStreamProvider = StreamProvider.family<List<LocalMemo>, MemosQuery>((
  ref,
  query,
) {
  final db = ref.watch(databaseProvider);
  final search = query.searchQuery.trim();
  final pageSize = query.pageSize > 0 ? query.pageSize : 200;
  final advancedFilters = query.advancedFilters.normalized();
  final localCandidateLimit = advancedFilters.isEmpty ? pageSize : null;
  return db
      .watchMemos(
        searchQuery: search.isEmpty ? null : search,
        state: query.state,
        tag: query.tag,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
        limit: localCandidateLimit,
      )
      .map(
        (rows) => _applyAdvancedFiltersToRows(
          rows,
          advancedFilters,
          pageSize: pageSize,
        ),
      );
});

final remoteSearchMemosProvider =
    StreamProvider.family<List<LocalMemo>, MemosQuery>((ref, query) async* {
      final db = ref.watch(databaseProvider);
      final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
      final normalizedSearch = query.searchQuery.trim();
      final normalizedTag = _normalizeTagInput(query.tag);
      final pageSize = query.pageSize > 0 ? query.pageSize : 200;
      final advancedFilters = query.advancedFilters.normalized();
      if (account == null) {
        final localCandidateLimit = advancedFilters.isEmpty ? pageSize : null;
        await for (final rows in db.watchMemos(
          searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
          state: query.state,
          tag: normalizedTag.isEmpty ? null : normalizedTag,
          startTimeSec: query.startTimeSec,
          endTimeSecExclusive: query.endTimeSecExclusive,
          limit: localCandidateLimit,
        )) {
          yield _applyAdvancedFiltersToRows(
            rows,
            advancedFilters,
            pageSize: pageSize,
          );
        }
        return;
      }

      final api = ref.watch(memosApiProvider);
      final logManager = ref.watch(logManagerProvider);
      await api.ensureServerHintsLoaded();
      final filters = <String>[];

      final creatorId = _parseUserId(account.user.name);
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

      final startTimeSec = query.startTimeSec;
      final endTimeSecExclusive = query.endTimeSecExclusive;
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
      var seed = <LocalMemo>[];
      try {
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
                  context: {
                    'traceId': traceId,
                    'page': requestPages,
                    'dioType': e.type.name,
                  },
                );
                useLegacyV2Search = false;
                continue;
              }
              rethrow;
            } on FormatException {
              logManager.warn(
                'Legacy v2 search parse failed, fallback to list',
                context: {'traceId': traceId, 'page': requestPages},
              );
              useLegacyV2Search = false;
              continue;
            }
          } else {
            final requestSize = targetCount - results.length;
            requestPages += 1;
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

            if (useLegacySearchFallback &&
                !_matchesRemoteSearchMemoLocally(
                  memo: memo,
                  creatorId: creatorId,
                  normalizedSearch: normalizedSearch,
                  normalizedTag: normalizedTag,
                  startTimeSec: startTimeSec,
                  endTimeSecExclusive: endTimeSecExclusive,
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

        seed = results;
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
          limit: advancedFilters.isEmpty ? pageSize : null,
        );
        seed = _applyAdvancedFiltersToRows(
          rows,
          advancedFilters,
          pageSize: pageSize,
        );
        logManager.info(
          'Search local fallback completed',
          context: {'traceId': traceId, 'resultCount': seed.length},
        );
      }
      yield seed;

      await for (final _ in db.changes) {
        final refreshed = await _refreshRemoteSeedWithLocal(seed: seed, db: db);
        seed = _applyAdvancedFiltersToMemos(
          refreshed,
          advancedFilters,
          pageSize: pageSize,
        );
        yield seed;
      }
    });

final shortcutMemosProvider =
    StreamProvider.family<List<LocalMemo>, ShortcutMemosQuery>((
      ref,
      query,
    ) async* {
      final db = ref.watch(databaseProvider);
      final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
      final search = query.searchQuery.trim();
      final normalizedTag = _normalizeTagInput(query.tag);
      final pageSize = query.pageSize > 0 ? query.pageSize : 200;
      final advancedFilters = query.advancedFilters.normalized();
      const int? localCandidateLimit = null;
      if (account == null) {
        await for (final rows in db.watchMemos(
          searchQuery: search.isEmpty ? null : search,
          state: query.state,
          tag: normalizedTag.isEmpty ? null : normalizedTag,
          startTimeSec: query.startTimeSec,
          endTimeSecExclusive: query.endTimeSecExclusive,
          limit: localCandidateLimit,
        )) {
          yield _applyAdvancedFiltersToRows(
            rows,
            advancedFilters,
            pageSize: pageSize,
          );
        }
        return;
      }

      final initialPredicate = _buildShortcutPredicate(query.shortcutFilter);

      if (initialPredicate != null) {
        await for (final rows in db.watchMemos(
          searchQuery: search.isEmpty ? null : search,
          state: query.state,
          tag: normalizedTag.isEmpty ? null : normalizedTag,
          startTimeSec: query.startTimeSec,
          endTimeSecExclusive: query.endTimeSecExclusive,
          limit: localCandidateLimit,
        )) {
          final predicate =
              _buildShortcutPredicate(query.shortcutFilter) ?? initialPredicate;
          final filtered = _filterShortcutMemosFromRows(rows, predicate);
          yield _applyAdvancedFiltersToMemos(
            filtered,
            advancedFilters,
            pageSize: pageSize,
          );
        }
        return;
      }

      final api = ref.watch(memosApiProvider);
      await api.ensureServerHintsLoaded();
      final creatorId = _parseUserId(account.user.name);
      final parent = _buildShortcutParent(creatorId);
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

      var seed = <LocalMemo>[];
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

        seed = _applyAdvancedFiltersToMemos(
          _sortShortcutMemos(results),
          advancedFilters,
          pageSize: pageSize,
        );
      } on DioException catch (e) {
        if (_shouldFallbackShortcutFilter(e)) {
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
          if (local != null) {
            seed = _applyAdvancedFiltersToMemos(
              local,
              advancedFilters,
              pageSize: pageSize,
            );
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      yield seed;

      await for (final _ in db.changes) {
        final refreshed = await _refreshShortcutSeedWithLocal(
          seed: seed,
          db: db,
        );
        seed = _applyAdvancedFiltersToMemos(
          refreshed,
          advancedFilters,
          pageSize: pageSize,
        );
        yield seed;
      }
    });

final quickSearchMemosProvider =
    StreamProvider.family<List<LocalMemo>, QuickSearchMemosQuery>((
      ref,
      query,
    ) async* {
      final db = ref.watch(databaseProvider);
      final search = query.searchQuery.trim();
      final normalizedTag = _normalizeTagInput(query.tag);
      final pageSize = query.pageSize > 0 ? query.pageSize : 200;
      final advancedFilters = query.advancedFilters.normalized();
      const int? localCandidateLimit = null;

      await for (final rows in db.watchMemos(
        searchQuery: search.isEmpty ? null : search,
        state: query.state,
        tag: normalizedTag.isEmpty ? null : normalizedTag,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
        limit: localCandidateLimit,
      )) {
        final predicate = _buildQuickSearchPredicate(
          kind: query.kind,
          nowLocal: DateTime.now(),
        );
        final filtered = _filterShortcutMemosFromRows(rows, predicate);
        yield _applyAdvancedFiltersToMemos(
          filtered,
          advancedFilters,
          pageSize: pageSize,
        );
      }
    });

List<LocalMemo> _applyAdvancedFiltersToRows(
  Iterable<Map<String, dynamic>> rows,
  AdvancedSearchFilters advancedFilters, {
  required int pageSize,
}) {
  return _applyAdvancedFiltersToMemos(
    rows.map(LocalMemo.fromDb),
    advancedFilters,
    pageSize: pageSize,
  );
}

List<LocalMemo> _applyAdvancedFiltersToMemos(
  Iterable<LocalMemo> memos,
  AdvancedSearchFilters advancedFilters, {
  required int pageSize,
}) {
  final normalizedFilters = advancedFilters.normalized();
  if (normalizedFilters.isEmpty) {
    if (pageSize > 0) {
      return memos.take(pageSize).toList(growable: false);
    }
    return memos.toList(growable: false);
  }

  final filtered = <LocalMemo>[];
  for (final memo in memos) {
    if (!normalizedFilters.matches(memo)) continue;
    filtered.add(memo);
    if (pageSize > 0 && filtered.length >= pageSize) {
      break;
    }
  }
  return filtered;
}

String? _buildShortcutFilter({
  required int? creatorId,
  required String searchQuery,
  required String? tag,
  required String shortcutFilter,
  int? startTimeSec,
  int? endTimeSecExclusive,
  bool includeCreatorId = true,
  bool useLegacyDialect = false,
}) {
  final filters = <String>[];
  if (includeCreatorId && creatorId != null) {
    filters.add(
      _buildCreatorFilterExpression(
        creatorId: creatorId,
        useLegacyDialect: useLegacyDialect,
      ),
    );
  }

  final normalizedSearch = searchQuery.trim();
  if (normalizedSearch.isNotEmpty) {
    filters.add('content.contains("${_escapeFilterValue(normalizedSearch)}")');
  }

  final normalizedTag = _normalizeTagInput(tag);
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

  final normalizedShortcut = shortcutFilter.trim();
  if (normalizedShortcut.isNotEmpty) {
    filters.add('($normalizedShortcut)');
  }

  if (filters.isEmpty) return null;
  return filters.join(' && ');
}

String? _buildShortcutParent(int? creatorId) {
  if (creatorId == null) return null;
  return 'users/$creatorId';
}

int? _parseUserId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final last = trimmed.contains('/') ? trimmed.split('/').last : trimmed;
  return int.tryParse(last.trim());
}

String _buildCreatorFilterExpression({
  required int creatorId,
  required bool useLegacyDialect,
}) {
  if (useLegacyDialect) {
    return "creator == 'users/$creatorId'";
  }
  return 'creator_id == $creatorId';
}

String _escapeFilterValue(String raw) {
  return raw
      .replaceAll('\\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', ' ');
}

String _normalizeTagInput(String? raw) {
  final normalized = normalizeTagPath(raw ?? '');
  return normalized;
}

String _memoRemoteKey(Memo memo) {
  final uid = memo.uid.trim();
  if (uid.isNotEmpty) return uid;
  return memo.name.trim();
}

String _searchTokenPreview(String token) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length <= 24) return trimmed;
  return '${trimmed.substring(0, 24)}...';
}

bool _matchesRemoteSearchMemoLocally({
  required Memo memo,
  required int? creatorId,
  required String normalizedSearch,
  required String normalizedTag,
  required int? startTimeSec,
  required int? endTimeSecExclusive,
}) {
  if (creatorId != null) {
    final creatorRaw = memo.creator.trim();
    if (creatorRaw.isNotEmpty) {
      final memoCreatorId = _parseUserId(creatorRaw);
      if (memoCreatorId != null) {
        if (memoCreatorId != creatorId) return false;
      } else if (creatorRaw != 'users/$creatorId') {
        return false;
      }
    }
  }

  if (normalizedSearch.isNotEmpty) {
    final content = memo.content.toLowerCase();
    if (!content.contains(normalizedSearch.toLowerCase())) {
      return false;
    }
  }

  if (normalizedTag.isNotEmpty) {
    final tags = <String>{};
    for (final tag in memo.tags) {
      final normalized = _normalizeTagInput(tag);
      if (normalized.isNotEmpty) {
        tags.add(normalized);
      }
    }
    if (!tags.contains(normalizedTag)) {
      for (final tag in extractTags(memo.content)) {
        final normalized = _normalizeTagInput(tag);
        if (normalized.isNotEmpty) {
          tags.add(normalized);
        }
      }
    }
    if (!tags.contains(normalizedTag)) {
      return false;
    }
  }

  final createdSec = memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000;
  if (startTimeSec != null && createdSec < startTimeSec) {
    return false;
  }
  if (endTimeSecExclusive != null && createdSec >= endTimeSecExclusive) {
    return false;
  }

  return true;
}

bool _shouldFallbackShortcutFilter(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }
  return status == 400 || status == 404 || status == 405 || status == 500;
}

Future<List<LocalMemo>?> _tryListShortcutMemosLocally({
  required AppDatabase db,
  required String searchQuery,
  required String state,
  required String? tag,
  required String shortcutFilter,
  required AdvancedSearchFilters advancedFilters,
  int? startTimeSec,
  int? endTimeSecExclusive,
  required int? candidateLimit,
}) async {
  final predicate = _buildShortcutPredicate(shortcutFilter);
  if (predicate == null) return null;

  final normalizedSearch = searchQuery.trim();
  final normalizedTag = _normalizeTagInput(tag);
  final rows = await db.listMemos(
    searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
    state: state,
    tag: normalizedTag.isEmpty ? null : normalizedTag,
    startTimeSec: startTimeSec,
    endTimeSecExclusive: endTimeSecExclusive,
    limit: candidateLimit,
  );

  final memos = rows
      .map(LocalMemo.fromDb)
      .where(predicate)
      .toList(growable: true);
  return _applyAdvancedFiltersToMemos(
    _sortShortcutMemos(memos),
    advancedFilters,
    pageSize: 0,
  );
}

typedef _MemoPredicate = bool Function(LocalMemo memo);

List<LocalMemo> _sortShortcutMemos(List<LocalMemo> memos) {
  memos.sort((a, b) {
    if (a.pinned != b.pinned) {
      return a.pinned ? -1 : 1;
    }
    return b.updateTime.compareTo(a.updateTime);
  });
  return memos;
}

List<LocalMemo> _filterShortcutMemosFromRows(
  Iterable<Map<String, dynamic>> rows,
  _MemoPredicate predicate,
) {
  final memos = rows
      .map(LocalMemo.fromDb)
      .where(predicate)
      .toList(growable: true);
  return _sortShortcutMemos(memos);
}

Future<List<LocalMemo>> _refreshRemoteSeedWithLocal({
  required List<LocalMemo> seed,
  required AppDatabase db,
}) async {
  if (seed.isEmpty) return seed;
  final refreshed = <LocalMemo>[];
  for (final memo in seed) {
    final uid = memo.uid.trim();
    if (uid.isEmpty) continue;
    final row = await db.getMemoByUid(uid);
    if (row != null) {
      refreshed.add(LocalMemo.fromDb(row));
    } else {
      refreshed.add(memo);
    }
  }
  return refreshed;
}

Future<List<LocalMemo>> _refreshShortcutSeedWithLocal({
  required List<LocalMemo> seed,
  required AppDatabase db,
}) async {
  if (seed.isEmpty) return seed;
  final refreshed = <LocalMemo>[];
  for (final memo in seed) {
    final uid = memo.uid.trim();
    if (uid.isEmpty) continue;
    final row = await db.getMemoByUid(uid);
    if (row != null) {
      refreshed.add(LocalMemo.fromDb(row));
    } else {
      refreshed.add(memo);
    }
  }
  return _sortShortcutMemos(refreshed);
}

_MemoPredicate? _buildShortcutPredicate(String filter) {
  final trimmed = filter.trim();
  if (trimmed.isEmpty) return (_) => true;
  try {
    final normalized = _normalizeShortcutFilterForLocal(trimmed);
    final tokens = _tokenizeShortcutFilter(normalized);
    final parser = _ShortcutFilterParser(tokens);
    final predicate = parser.parse();
    if (predicate == null || !parser.isAtEnd) return null;
    return predicate;
  } catch (_) {
    return null;
  }
}

_MemoPredicate _buildQuickSearchPredicate({
  required QuickSearchKind kind,
  required DateTime nowLocal,
}) {
  return switch (kind) {
    QuickSearchKind.attachments => (memo) => memo.attachments.isNotEmpty,
    QuickSearchKind.links => _memoHasLink,
    QuickSearchKind.voice => _memoHasVoiceAttachment,
    QuickSearchKind.onThisDay => (memo) => _isMemoOnThisDay(memo, nowLocal),
  };
}

bool _memoHasLink(LocalMemo memo) {
  final content = memo.content.trim();
  if (content.isEmpty) return false;

  for (final match in _memoMarkdownLinkPattern.allMatches(content)) {
    final url = (match.group(1) ?? '').trim();
    if (_isHttpLikeUrl(url)) return true;
  }
  for (final match in _memoInlineUrlPattern.allMatches(content)) {
    final url = (match.group(0) ?? '').trim();
    if (_isHttpLikeUrl(url)) return true;
  }
  return false;
}

bool _isHttpLikeUrl(String raw) {
  var candidate = raw.trim();
  if (candidate.isEmpty) return false;
  if (candidate.startsWith('www.')) {
    candidate = 'https://$candidate';
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

bool _memoHasVoiceAttachment(LocalMemo memo) {
  for (final attachment in memo.attachments) {
    if (_isAudioAttachment(attachment)) {
      return true;
    }
  }
  return false;
}

bool _isAudioAttachment(Attachment attachment) {
  final type = attachment.type.trim().toLowerCase();
  if (type.startsWith('audio/')) return true;
  if (type == 'audio') return true;

  final filename = attachment.filename.trim().toLowerCase();
  if (filename.isEmpty) return false;
  const audioExtensions = <String>[
    '.aac',
    '.amr',
    '.flac',
    '.m4a',
    '.mp3',
    '.ogg',
    '.opus',
    '.wav',
    '.wma',
  ];
  for (final ext in audioExtensions) {
    if (filename.endsWith(ext)) return true;
  }
  return false;
}

bool _isMemoOnThisDay(LocalMemo memo, DateTime nowLocal) {
  final created = memo.createTime;
  if (created.year >= nowLocal.year) return false;
  return created.month == nowLocal.month && created.day == nowLocal.day;
}

LocalMemo _localMemoFromRemote(Memo memo) {
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
