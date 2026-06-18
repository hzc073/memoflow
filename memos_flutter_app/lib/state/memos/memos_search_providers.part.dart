part of 'memos_providers.dart';

final memosStreamProvider = StreamProvider.family<List<LocalMemo>, MemosQuery>((
  ref,
  query,
) {
  final coordinator = ref.watch(memoSearchCoordinatorProvider);
  ref.watch(databaseProvider);
  return coordinator.watchLocalMemos(query);
});

final remoteSearchMemosProvider =
    StreamProvider.family<List<LocalMemo>, MemosQuery>((ref, query) async* {
      final coordinator = ref.watch(memoSearchCoordinatorProvider);
      final db = ref.watch(databaseProvider);
      final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) {
        yield* coordinator.watchLocalMemos(query);
        return;
      }

      ref.watch(memosApiProvider);
      ref.watch(logManagerProvider);
      var seed = await coordinator.loadRemoteSearchSeed(query: query);
      yield seed;

      await for (final _ in db.changes) {
        seed = await coordinator.refreshRemoteSearchResults(
          seed: seed,
          query: query,
        );
        yield seed;
      }
    });

final shortcutMemosProvider =
    StreamProvider.family<List<LocalMemo>, ShortcutMemosQuery>((
      ref,
      query,
    ) async* {
      final coordinator = ref.watch(memoSearchCoordinatorProvider);
      final db = ref.watch(databaseProvider);
      final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
      final pageSize = query.pageSize > 0 ? query.pageSize : 200;
      const int? localCandidateLimit = null;
      final initialPredicate = _buildShortcutPredicate(query.shortcutFilter);

      if (account == null) {
        if (initialPredicate != null) {
          yield* coordinator._watchLocalFilteredMemos(
            searchQuery: query.searchQuery,
            state: query.state,
            tag: query.tag,
            startTimeSec: query.startTimeSec,
            endTimeSecExclusive: query.endTimeSecExclusive,
            advancedFilters: query.advancedFilters,
            pageSize: pageSize,
            candidateLimit: localCandidateLimit,
            predicate: initialPredicate,
          );
        } else {
          yield* coordinator.watchLocalMemos((
            searchQuery: query.searchQuery,
            state: query.state,
            tag: query.tag,
            startTimeSec: query.startTimeSec,
            endTimeSecExclusive: query.endTimeSecExclusive,
            advancedFilters: query.advancedFilters,
            sortOrder: MemoSortOrder.createDesc,
            pageSize: query.pageSize,
          ));
        }
        return;
      }

      if (initialPredicate != null) {
        yield* coordinator._watchLocalFilteredMemos(
          searchQuery: query.searchQuery,
          state: query.state,
          tag: query.tag,
          startTimeSec: query.startTimeSec,
          endTimeSecExclusive: query.endTimeSecExclusive,
          advancedFilters: query.advancedFilters,
          pageSize: pageSize,
          candidateLimit: localCandidateLimit,
          predicate: initialPredicate,
        );
        return;
      }

      ref.watch(memosApiProvider);
      var seed = await coordinator.loadShortcutRemoteSeed(query: query);
      yield seed;

      await for (final _ in db.changes) {
        seed = await coordinator.refreshShortcutResults(
          seed: seed,
          query: query,
        );
        yield seed;
      }
    });

final quickSearchMemosProvider =
    StreamProvider.family<List<LocalMemo>, QuickSearchMemosQuery>((ref, query) {
      final coordinator = ref.watch(memoSearchCoordinatorProvider);
      ref.watch(databaseProvider);
      final pageSize = query.pageSize > 0 ? query.pageSize : 200;
      const int? localCandidateLimit = null;
      return coordinator._watchLocalFilteredMemos(
        searchQuery: query.searchQuery,
        state: query.state,
        tag: query.tag,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
        advancedFilters: query.advancedFilters,
        pageSize: pageSize,
        candidateLimit: localCandidateLimit,
        predicate: _buildQuickSearchPredicate(
          kind: query.kind,
          nowLocal: DateTime.now(),
        ),
      );
    });

final aiSemanticMemoSearchServiceProvider =
    Provider<AiSemanticMemoSearchService>((ref) {
      return AiSemanticMemoSearchService(
        repository: AiAnalysisRepository(
          ref.watch(databaseProvider),
          writeGateway: ref.watch(desktopDbWriteGatewayProvider),
        ),
        runtime: AiTaskRuntime(registry: ref.watch(aiProviderRegistryProvider)),
        readCurrentSettings: () => ref.read(aiSettingsProvider),
        currentTagRecognitionPolicy: () =>
            ref.read(currentWorkspacePreferencesProvider).tagRecognitionPolicy,
      );
    });

final aiSearchIndexPreflightProvider =
    FutureProvider.family<
      AiSemanticMemoSearchIndexPreflight,
      AiSearchMemosQuery
    >((ref, query) async {
      final normalizedSearch = MemoSearchMatcher.normalizeQuery(
        query.searchQuery,
      );
      if (normalizedSearch.isEmpty) {
        return AiSemanticMemoSearchIndexPreflight.empty;
      }
      final service = ref.watch(aiSemanticMemoSearchServiceProvider);
      final settings = ref.watch(aiSettingsProvider);
      return service.estimateIndexWorkForSearchScope(
        settings: settings,
        query: normalizedSearch,
        state: query.state,
        tag: query.tag,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
      );
    });

final aiSearchMemosProvider =
    FutureProvider.family<List<LocalMemo>, AiSearchMemosQuery>((
      ref,
      query,
    ) async {
      final service = ref.watch(aiSemanticMemoSearchServiceProvider);
      final settings = ref.watch(aiSettingsProvider);
      final logManager = ref.watch(logManagerProvider);
      final pageSize = query.pageSize > 0 ? query.pageSize : 200;
      final normalizedSearch = MemoSearchMatcher.normalizeQuery(
        query.searchQuery,
      );
      if (normalizedSearch.isEmpty) return const <LocalMemo>[];

      try {
        final result = await service.search(
          settings: settings,
          query: normalizedSearch,
          state: query.state,
          tag: query.tag,
          startTimeSec: query.startTimeSec,
          endTimeSecExclusive: query.endTimeSecExclusive,
          limit: pageSize * 3,
        );
        final filtered = filterAiSearchHitsForMemoList(
          result.hits,
          advancedFilters: query.advancedFilters,
          pageSize: pageSize,
        );
        logManager.info(
          'AI search flow completed',
          context: <String, Object?>{
            'queryLength': normalizedSearch.length,
            'readyChunks': result.readyChunkCount,
            'scoredChunks': result.scoredChunkCount,
            'rawHitCount': result.hits.length,
            'resultCount': filtered.length,
          },
        );
        return filtered;
      } catch (error, stackTrace) {
        logManager.warn(
          'AI search flow failed',
          error: error,
          stackTrace: stackTrace,
          context: <String, Object?>{
            'queryLength': normalizedSearch.length,
            'state': query.state,
            'tag': query.tag,
          },
        );
        rethrow;
      }
    });

List<LocalMemo> filterAiSearchHitsForMemoList(
  Iterable<AiSemanticMemoSearchHit> hits, {
  required AdvancedSearchFilters advancedFilters,
  required int pageSize,
}) {
  final normalizedFilters = advancedFilters.normalized();
  final normalizedPageSize = pageSize > 0 ? pageSize : null;
  final filtered = <LocalMemo>[];
  for (final hit in hits) {
    if (!normalizedFilters.matches(hit.memo)) continue;
    filtered.add(hit.memo);
    if (normalizedPageSize != null && filtered.length >= normalizedPageSize) {
      break;
    }
  }
  return filtered;
}

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

int? _localCandidateLimitForAdvancedFilters(
  AdvancedSearchFilters advancedFilters,
  int pageSize,
) {
  final normalizedFilters = advancedFilters.normalized();
  if (_advancedFiltersRequireDartPostFilter(normalizedFilters)) {
    return null;
  }
  return pageSize > 0 ? pageSize : null;
}

bool _advancedFiltersRequireDartPostFilter(
  AdvancedSearchFilters advancedFilters,
) {
  final filters = advancedFilters.normalized();
  return filters.locationContains.isNotEmpty ||
      filters.attachmentNameContains.isNotEmpty ||
      filters.attachmentType != null;
}

MemoSearchDbFilters _memoSearchDbFiltersForAdvancedFilters(
  AdvancedSearchFilters advancedFilters,
) {
  final filters = advancedFilters.normalized();
  final range = filters.createdDateRange;
  final startTimeSec = range == null ? null : _toEpochSecond(range.start);
  final endTimeSecExclusive = range == null
      ? null
      : _toEpochSecond(
          _normalizeLocalDay(range.end).add(const Duration(days: 1)),
        );

  return MemoSearchDbFilters(
    createdStartTimeSec: startTimeSec,
    createdEndTimeSecExclusive: endTimeSecExclusive,
    hasLocation: _toggleFilterToBool(filters.hasLocation),
    hasAttachments: _toggleFilterToBool(filters.hasAttachments),
    hasRelations: _toggleFilterToBool(filters.hasRelations),
  );
}

bool? _toggleFilterToBool(SearchToggleFilter filter) {
  return switch (filter) {
    SearchToggleFilter.any => null,
    SearchToggleFilter.yes => true,
    SearchToggleFilter.no => false,
  };
}

int _toEpochSecond(DateTime value) {
  return value.toUtc().millisecondsSinceEpoch ~/ 1000;
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

  final normalizedSearch = MemoSearchMatcher.normalizeQuery(searchQuery);
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
  required String currentUserName,
  required int? currentUserId,
  required String normalizedSearch,
  required String normalizedTag,
  required TagRecognitionPolicy tagRecognitionPolicy,
  required int? startTimeSec,
  required int? endTimeSecExclusive,
  Set<String> matchedLocalMemoKeys = const <String>{},
}) {
  final memoKey = _memoRemoteKey(memo);
  final matchedLocally =
      memoKey.isNotEmpty && matchedLocalMemoKeys.contains(memoKey);

  if (!matchedLocally) {
    final creatorRaw = memo.creator.trim();
    if (!_memoCreatorMatchesCurrentUser(
      creatorRaw,
      currentUserName: currentUserName,
      currentUserId: currentUserId,
    )) {
      return false;
    }
  }

  if (normalizedSearch.isNotEmpty) {
    if (!matchedLocally &&
        !MemoSearchMatcher.matchesText(
          text: MemoSearchDocumentBuilder.buildCanonical(
            content: memo.content,
            tagsText: deriveVisibleMemoTags(
              content: memo.content,
              remoteTags: memo.tags,
              policy: tagRecognitionPolicy,
            ).join(' '),
          ),
          query: normalizedSearch,
        )) {
      return false;
    }
  }

  if (normalizedTag.isNotEmpty) {
    final tags = deriveVisibleMemoTags(
      content: memo.content,
      remoteTags: memo.tags,
      policy: tagRecognitionPolicy,
    ).toSet();
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

bool _memoCreatorMatchesCurrentUser(
  String rawCreator, {
  required String currentUserName,
  required int? currentUserId,
}) {
  final creator = rawCreator.trim();
  if (creator.isEmpty) return false;

  final normalizedCurrentName = currentUserName.trim();
  if (normalizedCurrentName.isNotEmpty && creator == normalizedCurrentName) {
    return true;
  }

  final creatorId = _parseUserId(creator);
  if (creatorId != null && currentUserId != null) {
    return creatorId == currentUserId;
  }

  if (currentUserId != null && creator == 'users/$currentUserId') {
    return true;
  }

  return false;
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

  final normalizedSearch = MemoSearchMatcher.normalizeQuery(searchQuery);
  final normalizedTag = _normalizeTagInput(tag);
  final rows = await db.listMemos(
    searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
    state: state,
    tag: normalizedTag.isEmpty ? null : normalizedTag,
    startTimeSec: startTimeSec,
    endTimeSecExclusive: endTimeSecExclusive,
    limit: candidateLimit,
    searchFilters: _memoSearchDbFiltersForAdvancedFilters(advancedFilters),
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

Future<List<LocalMemo>> _loadLocalSearchMemos({
  required AppDatabase db,
  required String searchQuery,
  required String state,
  required String? tag,
  required AdvancedSearchFilters advancedFilters,
  required int? candidateLimit,
  MemoSortOrder sortOrder = MemoSortOrder.createDesc,
  int? startTimeSec,
  int? endTimeSecExclusive,
}) async {
  final rows = await db.listMemos(
    searchQuery: searchQuery.isEmpty ? null : searchQuery,
    state: state,
    tag: tag,
    startTimeSec: startTimeSec,
    endTimeSecExclusive: endTimeSecExclusive,
    sortOrder: sortOrder,
    limit: candidateLimit,
    searchFilters: _memoSearchDbFiltersForAdvancedFilters(advancedFilters),
  );
  return _applyAdvancedFiltersToRows(
    rows,
    advancedFilters,
    pageSize: candidateLimit ?? 0,
  );
}

String _memoLocalKey(LocalMemo memo) {
  final uid = memo.uid.trim();
  if (uid.isNotEmpty) return uid;
  return memo.contentFingerprint;
}

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

List<LocalMemo> _mergeRemoteSearchSeedWithLocalMatches({
  required Iterable<LocalMemo> seed,
  required Iterable<LocalMemo> localMatches,
  required AdvancedSearchFilters advancedFilters,
  required int pageSize,
}) {
  final merged = <LocalMemo>[];
  final seen = <String>{};

  void addMemo(LocalMemo memo) {
    final key = _memoLocalKey(memo);
    if (key.isNotEmpty && !seen.add(key)) {
      return;
    }
    if (!advancedFilters.matches(memo)) {
      return;
    }
    merged.add(memo);
  }

  for (final memo in seed) {
    addMemo(memo);
    if (pageSize > 0 && merged.length >= pageSize) {
      return merged;
    }
  }

  for (final memo in localMatches) {
    addMemo(memo);
    if (pageSize > 0 && merged.length >= pageSize) {
      return merged;
    }
  }

  return merged;
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

LocalMemo _localMemoFromRemote(
  Memo memo, {
  TagRecognitionPolicy tagRecognitionPolicy =
      TagRecognitionPolicy.defaultPolicy,
}) {
  return LocalMemo(
    uid: memo.uid,
    content: memo.content,
    contentFingerprint: memo.contentFingerprint,
    visibility: memo.visibility,
    pinned: memo.pinned,
    state: memo.state,
    createTime: memo.createTime.toLocal(),
    updateTime: memo.updateTime.toLocal(),
    tags: deriveVisibleMemoTags(
      content: memo.content,
      remoteTags: memo.tags,
      policy: tagRecognitionPolicy,
    ),
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
