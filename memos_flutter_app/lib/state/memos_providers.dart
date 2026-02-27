import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_localization.dart';
import '../core/image_bed_url.dart';
import '../core/memo_relations.dart';
import '../core/tags.dart';
import '../core/uid.dart';
import '../data/api/memo_api_facade.dart';
import '../data/api/memo_api_version.dart';
import '../data/api/memos_api.dart';
import '../data/api/image_bed_api.dart';
import '../data/db/app_database.dart';
import '../data/logs/log_manager.dart';
import '../data/logs/sync_status_tracker.dart';
import '../data/models/attachment.dart';
import '../data/models/image_bed_settings.dart';
import '../data/models/local_memo.dart';
import '../data/models/memo.dart';
import '../data/models/memo_location.dart';
import '../data/models/memo_relation.dart';
import '../data/settings/image_bed_settings_repository.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/local_library/local_library_fs.dart';
import '../data/logs/sync_queue_progress_tracker.dart';
import '../state/database_provider.dart';
import '../state/image_bed_settings_provider.dart';
import '../state/local_library_provider.dart';
import '../state/local_sync_controller.dart';
import '../state/logging_provider.dart';
import '../state/memoflow_bridge_settings_provider.dart';
import '../state/network_log_provider.dart';
import '../state/preferences_provider.dart';
import '../state/session_provider.dart';
import '../state/sync_controller_base.dart';

typedef MemosQuery = ({
  String searchQuery,
  String state,
  String? tag,
  int? startTimeSec,
  int? endTimeSecExclusive,
  int pageSize,
});

typedef ShortcutMemosQuery = ({
  String searchQuery,
  String state,
  String? tag,
  String shortcutFilter,
  int? startTimeSec,
  int? endTimeSecExclusive,
  int pageSize,
});

typedef _CurrentAccountAuthContext = ({
  String key,
  String baseUrl,
  String personalAccessToken,
  String userName,
  String instanceVersion,
  String serverVersionOverride,
  bool? useLegacyApiOverride,
});

_CurrentAccountAuthContext? _currentAccountAuthContext(
  AsyncValue<AppSessionState> session,
) {
  final account = session.valueOrNull?.currentAccount;
  if (account == null) return null;
  return (
    key: account.key,
    baseUrl: account.baseUrl.toString(),
    personalAccessToken: account.personalAccessToken,
    userName: account.user.name,
    instanceVersion: account.instanceProfile.version.trim(),
    serverVersionOverride: (account.serverVersionOverride ?? '').trim(),
    useLegacyApiOverride: account.useLegacyApiOverride,
  );
}

enum QuickSearchKind { attachments, links, voice, onThisDay }

final RegExp _memoMarkdownLinkPattern = RegExp(
  r'\[[^\]]+\]\(([^)\s]+)\)',
  caseSensitive: false,
);
final RegExp _memoInlineUrlPattern = RegExp(
  r'(?:https?:\/\/|www\.)[^\s<>()]+',
  caseSensitive: false,
);

typedef QuickSearchMemosQuery = ({
  QuickSearchKind kind,
  String searchQuery,
  String state,
  String? tag,
  int? startTimeSec,
  int? endTimeSecExclusive,
  int pageSize,
});

final memosApiProvider = Provider<MemosApi>((ref) {
  final authContext = ref.watch(
    appSessionProvider.select(_currentAccountAuthContext),
  );
  if (authContext == null) {
    throw StateError('Not authenticated');
  }
  final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }
  final sessionController = ref.read(appSessionProvider.notifier);
  final effectiveVersion = sessionController
      .resolveEffectiveServerVersionForAccount(account: account);
  final parsedVersion = parseMemoApiVersion(effectiveVersion);
  if (parsedVersion == null) {
    throw StateError(
      'No fixed API version selected for current account. Please select API version manually.',
    );
  }
  final logStore = ref.watch(networkLogStoreProvider);
  final logBuffer = ref.watch(networkLogBufferProvider);
  final breadcrumbStore = ref.watch(breadcrumbStoreProvider);
  final logManager = ref.watch(logManagerProvider);
  return MemoApiFacade.authenticated(
    baseUrl: account.baseUrl,
    personalAccessToken: account.personalAccessToken,
    version: parsedVersion,
    logStore: logStore,
    logBuffer: logBuffer,
    breadcrumbStore: breadcrumbStore,
    logManager: logManager,
  );
});

final memosStreamProvider = StreamProvider.family<List<LocalMemo>, MemosQuery>((
  ref,
  query,
) {
  final db = ref.watch(databaseProvider);
  final search = query.searchQuery.trim();
  final pageSize = query.pageSize > 0 ? query.pageSize : 200;
  return db
      .watchMemos(
        searchQuery: search.isEmpty ? null : search,
        state: query.state,
        tag: query.tag,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
        limit: pageSize,
      )
      .map((rows) => rows.map(LocalMemo.fromDb).toList(growable: false));
});

final remoteSearchMemosProvider =
    StreamProvider.family<List<LocalMemo>, MemosQuery>((ref, query) async* {
      final db = ref.watch(databaseProvider);
      final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
      final normalizedSearch = query.searchQuery.trim();
      final normalizedTag = _normalizeTagInput(query.tag);
      final pageSize = query.pageSize > 0 ? query.pageSize : 200;
      if (account == null) {
        await for (final rows in db.watchMemos(
          searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
          state: query.state,
          tag: normalizedTag.isEmpty ? null : normalizedTag,
          startTimeSec: query.startTimeSec,
          endTimeSecExclusive: query.endTimeSecExclusive,
          limit: pageSize,
        )) {
          yield rows.map(LocalMemo.fromDb).toList(growable: false);
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
            if (uid.isNotEmpty) {
              final row = await db.getMemoByUid(uid);
              if (row != null) {
                results.add(LocalMemo.fromDb(row));
                dbHitCount += 1;
              } else {
                results.add(_localMemoFromRemote(memo));
                dbMissCount += 1;
              }
            } else {
              results.add(_localMemoFromRemote(memo));
              dbMissCount += 1;
            }

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
          limit: pageSize,
        );
        seed = rows.map(LocalMemo.fromDb).toList(growable: false);
        logManager.info(
          'Search local fallback completed',
          context: {'traceId': traceId, 'resultCount': seed.length},
        );
      }
      yield seed;

      await for (final _ in db.changes) {
        final refreshed = await _refreshRemoteSeedWithLocal(seed: seed, db: db);
        seed = refreshed;
        yield refreshed;
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
          final memos = rows.map(LocalMemo.fromDb).toList(growable: false);
          yield _applyShortcutPageLimit(memos, pageSize);
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
          yield _applyShortcutPageLimit(filtered, pageSize);
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
          if (uid.isEmpty) continue;
          final row = await db.getMemoByUid(uid);
          if (row != null) {
            results.add(LocalMemo.fromDb(row));
          } else {
            results.add(_localMemoFromRemote(memo));
          }
        }

        seed = _sortShortcutMemos(results);
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
            candidateLimit: localCandidateLimit,
          );
          if (local != null) {
            seed = _applyShortcutPageLimit(local, pageSize);
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      yield seed;

      await for (final _ in db.changes) {
        yield await _refreshShortcutSeedWithLocal(seed: seed, db: db);
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
        yield _applyShortcutPageLimit(filtered, pageSize);
      }
    });

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
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return '';
  final withoutHash = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  return withoutHash.toLowerCase();
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
  return _sortShortcutMemos(memos);
}

List<LocalMemo> _applyShortcutPageLimit(List<LocalMemo> memos, int pageSize) {
  if (pageSize <= 0 || memos.length <= pageSize) return memos;
  return memos.take(pageSize).toList(growable: false);
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

enum _FilterTokenType {
  identifier,
  number,
  string,
  andOp,
  orOp,
  eq,
  gte,
  lte,
  inOp,
  lParen,
  rParen,
  lBracket,
  rBracket,
  comma,
  dot,
}

class _FilterToken {
  const _FilterToken(this.type, this.lexeme);

  final _FilterTokenType type;
  final String lexeme;
}

List<_FilterToken> _tokenizeShortcutFilter(String input) {
  final tokens = <_FilterToken>[];
  var i = 0;
  while (i < input.length) {
    final ch = input[i];
    if (ch.trim().isEmpty) {
      i++;
      continue;
    }
    if (input.startsWith('&&', i)) {
      tokens.add(const _FilterToken(_FilterTokenType.andOp, '&&'));
      i += 2;
      continue;
    }
    if (input.startsWith('||', i)) {
      tokens.add(const _FilterToken(_FilterTokenType.orOp, '||'));
      i += 2;
      continue;
    }
    if (input.startsWith('>=', i)) {
      tokens.add(const _FilterToken(_FilterTokenType.gte, '>='));
      i += 2;
      continue;
    }
    if (input.startsWith('<=', i)) {
      tokens.add(const _FilterToken(_FilterTokenType.lte, '<='));
      i += 2;
      continue;
    }
    if (input.startsWith('==', i)) {
      tokens.add(const _FilterToken(_FilterTokenType.eq, '=='));
      i += 2;
      continue;
    }
    switch (ch) {
      case '(':
        tokens.add(const _FilterToken(_FilterTokenType.lParen, '('));
        i++;
        continue;
      case ')':
        tokens.add(const _FilterToken(_FilterTokenType.rParen, ')'));
        i++;
        continue;
      case '[':
        tokens.add(const _FilterToken(_FilterTokenType.lBracket, '['));
        i++;
        continue;
      case ']':
        tokens.add(const _FilterToken(_FilterTokenType.rBracket, ']'));
        i++;
        continue;
      case ',':
        tokens.add(const _FilterToken(_FilterTokenType.comma, ','));
        i++;
        continue;
      case '.':
        tokens.add(const _FilterToken(_FilterTokenType.dot, '.'));
        i++;
        continue;
      case '"':
      case '\'':
        final quote = ch;
        i++;
        final buffer = StringBuffer();
        while (i < input.length) {
          final c = input[i];
          if (c == '\\' && i + 1 < input.length) {
            buffer.write(input[i + 1]);
            i += 2;
            continue;
          }
          if (c == quote) {
            i++;
            break;
          }
          buffer.write(c);
          i++;
        }
        tokens.add(_FilterToken(_FilterTokenType.string, buffer.toString()));
        continue;
    }

    if (_isDigit(ch)) {
      final start = i;
      while (i < input.length && _isDigit(input[i])) {
        i++;
      }
      tokens.add(
        _FilterToken(_FilterTokenType.number, input.substring(start, i)),
      );
      continue;
    }

    if (_isIdentifierStart(ch)) {
      final start = i;
      i++;
      while (i < input.length && _isIdentifierPart(input[i])) {
        i++;
      }
      final text = input.substring(start, i);
      if (text == 'in') {
        tokens.add(const _FilterToken(_FilterTokenType.inOp, 'in'));
      } else {
        tokens.add(_FilterToken(_FilterTokenType.identifier, text));
      }
      continue;
    }

    throw FormatException('Unexpected filter token: $ch');
  }
  return tokens;
}

bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

bool _isIdentifierStart(String ch) {
  final code = ch.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || ch == '_';
}

bool _isIdentifierPart(String ch) {
  return _isIdentifierStart(ch) || _isDigit(ch);
}

class _ShortcutFilterParser {
  _ShortcutFilterParser(this._tokens);

  final List<_FilterToken> _tokens;
  var _pos = 0;

  bool get isAtEnd => _pos >= _tokens.length;

  _MemoPredicate? parse() {
    final expr = _parseOr();
    return expr;
  }

  _MemoPredicate? _parseOr() {
    final first = _parseAnd();
    if (first == null) return null;
    var left = first;
    while (_match(_FilterTokenType.orOp)) {
      final right = _parseAnd();
      if (right == null) return null;
      final prev = left;
      left = (memo) => prev(memo) || right(memo);
    }
    return left;
  }

  _MemoPredicate? _parseAnd() {
    final first = _parsePrimary();
    if (first == null) return null;
    var left = first;
    while (_match(_FilterTokenType.andOp)) {
      final right = _parsePrimary();
      if (right == null) return null;
      final prev = left;
      left = (memo) => prev(memo) && right(memo);
    }
    return left;
  }

  _MemoPredicate? _parsePrimary() {
    if (_match(_FilterTokenType.lParen)) {
      final expr = _parseOr();
      if (expr == null || !_match(_FilterTokenType.rParen)) return null;
      return expr;
    }
    return _parseCondition();
  }

  _MemoPredicate? _parseCondition() {
    final ident = _consume(_FilterTokenType.identifier);
    if (ident == null) return null;
    switch (ident.lexeme) {
      case 'tag':
        if (!_match(_FilterTokenType.inOp)) return null;
        final values = _parseStringList();
        if (values == null) return null;
        final expected = values
            .map(_normalizeFilterTag)
            .where((v) => v.isNotEmpty)
            .toSet();
        return (memo) {
          for (final tag in memo.tags) {
            if (expected.contains(_normalizeFilterTag(tag))) return true;
          }
          return false;
        };
      case 'visibility':
        if (_match(_FilterTokenType.eq)) {
          final value = _consumeString();
          if (value == null) return null;
          final target = value.toUpperCase();
          return (memo) => memo.visibility.toUpperCase() == target;
        }
        if (_match(_FilterTokenType.inOp)) {
          final values = _parseStringList();
          if (values == null) return null;
          final set = values.map((v) => v.toUpperCase()).toSet();
          return (memo) => set.contains(memo.visibility.toUpperCase());
        }
        return null;
      case 'created_ts':
      case 'updated_ts':
        final isCreated = ident.lexeme == 'created_ts';
        if (_match(_FilterTokenType.gte)) {
          final value = _consumeNumber();
          if (value == null) return null;
          return (memo) => _timestampForMemo(memo, isCreated) >= value;
        }
        if (_match(_FilterTokenType.lte)) {
          final value = _consumeNumber();
          if (value == null) return null;
          return (memo) => _timestampForMemo(memo, isCreated) <= value;
        }
        return null;
      case 'content':
        if (!_match(_FilterTokenType.dot)) return null;
        final method = _consume(_FilterTokenType.identifier);
        if (method == null || method.lexeme != 'contains') return null;
        if (!_match(_FilterTokenType.lParen)) return null;
        final value = _consumeString();
        if (value == null || !_match(_FilterTokenType.rParen)) return null;
        return (memo) => memo.content.contains(value);
      case 'pinned':
        if (!_match(_FilterTokenType.eq)) return null;
        final boolValue = _consumeBool();
        if (boolValue == null) return null;
        return (memo) => memo.pinned == boolValue;
      case 'creator_id':
        if (!_match(_FilterTokenType.eq)) return null;
        final value = _consumeNumber();
        if (value == null) return null;
        return (_) => true;
      default:
        return null;
    }
  }

  List<String>? _parseStringList() {
    if (!_match(_FilterTokenType.lBracket)) return null;
    final values = <String>[];
    if (_check(_FilterTokenType.rBracket)) {
      _advance();
      return values;
    }
    while (!isAtEnd) {
      final value = _consumeString();
      if (value == null) return null;
      values.add(value);
      if (_match(_FilterTokenType.comma)) continue;
      if (_match(_FilterTokenType.rBracket)) break;
      return null;
    }
    return values;
  }

  String? _consumeString() {
    final token = _consume(_FilterTokenType.string);
    return token?.lexeme;
  }

  int? _consumeNumber() {
    final token = _consume(_FilterTokenType.number);
    if (token == null) return null;
    return int.tryParse(token.lexeme);
  }

  bool? _consumeBool() {
    if (_match(_FilterTokenType.identifier)) {
      final text = _previous().lexeme.toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
    }
    if (_match(_FilterTokenType.number)) {
      return _previous().lexeme != '0';
    }
    return null;
  }

  bool _match(_FilterTokenType type) {
    if (_check(type)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _check(_FilterTokenType type) {
    if (isAtEnd) return false;
    return _tokens[_pos].type == type;
  }

  _FilterToken _advance() {
    return _tokens[_pos++];
  }

  _FilterToken? _consume(_FilterTokenType type) {
    if (_check(type)) return _advance();
    return null;
  }

  _FilterToken _previous() => _tokens[_pos - 1];
}

int _timestampForMemo(LocalMemo memo, bool created) {
  final dt = created ? memo.createTime : memo.updateTime;
  return dt.toUtc().millisecondsSinceEpoch ~/ 1000;
}

String _normalizeFilterTag(String raw) {
  return _normalizeTagInput(raw);
}

String _normalizeShortcutFilterForLocal(String raw) {
  final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  return raw.replaceAllMapped(
    RegExp(r'(created_ts|updated_ts)\s*>=\s*now\(\)\s*-\s*(\d+)'),
    (match) {
      final field = match.group(1) ?? '';
      final seconds = int.tryParse(match.group(2) ?? '');
      if (field.isEmpty || seconds == null) return match.group(0) ?? '';
      final start = nowSec - seconds;
      return '$field >= $start';
    },
  );
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

List<MemoRelation> _decodeMemoRelationsCache(String raw) {
  if (raw.trim().isEmpty) return const <MemoRelation>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      final relations = <MemoRelation>[];
      for (final item in decoded) {
        if (item is Map) {
          relations.add(MemoRelation.fromJson(item.cast<String, dynamic>()));
        }
      }
      return relations;
    }
  } catch (_) {}
  return const <MemoRelation>[];
}

String _encodeMemoRelationsCache(List<MemoRelation> relations) {
  if (relations.isEmpty) return '[]';
  final items = <Map<String, dynamic>>[];
  for (final relation in relations) {
    items.add({
      'memo': {'name': relation.memo.name, 'snippet': relation.memo.snippet},
      'relatedMemo': {
        'name': relation.relatedMemo.name,
        'snippet': relation.relatedMemo.snippet,
      },
      'type': relation.type,
    });
  }
  return jsonEncode(items);
}

Future<List<MemoRelation>> _loadMemoRelationsCache(
  AppDatabase db,
  String memoUid,
) async {
  final raw = await db.getMemoRelationsCacheJson(memoUid);
  if (raw == null) return const <MemoRelation>[];
  return _decodeMemoRelationsCache(raw);
}

Future<void> _storeMemoRelationsCache(
  AppDatabase db,
  String memoUid,
  List<MemoRelation> relations,
) async {
  await db.upsertMemoRelationsCache(
    memoUid,
    relationsJson: _encodeMemoRelationsCache(relations),
  );
}

Future<void> _refreshMemoRelationsCache(Ref ref, String memoUid) async {
  final normalized = memoUid.trim();
  if (normalized.isEmpty) return;
  try {
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) return;
    final api = ref.read(memosApiProvider);
    final (relations, _) = await api.listMemoRelations(
      memoUid: normalized,
      pageSize: 200,
    );
    final db = ref.read(databaseProvider);
    await _storeMemoRelationsCache(db, normalized, relations);
  } catch (_) {}
}

final memoRelationsProvider = StreamProvider.family<List<MemoRelation>, String>(
  (ref, memoUid) async* {
    final normalized = memoUid.trim();
    if (normalized.isEmpty) {
      yield const <MemoRelation>[];
      return;
    }

    final db = ref.watch(databaseProvider);

    Future<List<MemoRelation>> load() async =>
        _loadMemoRelationsCache(db, normalized);

    unawaited(_refreshMemoRelationsCache(ref, normalized));

    yield await load();
    await for (final _ in db.changes) {
      yield await load();
    }
  },
);

final syncControllerProvider =
    StateNotifierProvider<SyncControllerBase, AsyncValue<void>>((ref) {
      final language = ref.watch(
        appPreferencesProvider.select((p) => p.language),
      );
      final localLibrary = ref.watch(currentLocalLibraryProvider);
      if (localLibrary != null) {
        return LocalSyncController(
          db: ref.watch(databaseProvider),
          fileSystem: LocalLibraryFileSystem(localLibrary),
          attachmentStore: LocalAttachmentStore(),
          bridgeSettingsRepository: ref.watch(
            memoFlowBridgeSettingsRepositoryProvider,
          ),
          syncStatusTracker: ref.read(syncStatusTrackerProvider),
          syncQueueProgressTracker: ref.read(syncQueueProgressTrackerProvider),
          language: language,
        );
      }

      final authContext = ref.watch(
        appSessionProvider.select(_currentAccountAuthContext),
      );
      if (authContext == null) {
        throw StateError('Not authenticated');
      }
      return RemoteSyncController(
        db: ref.watch(databaseProvider),
        api: ref.watch(memosApiProvider),
        currentUserName: authContext.userName,
        syncStatusTracker: ref.read(syncStatusTrackerProvider),
        syncQueueProgressTracker: ref.read(syncQueueProgressTrackerProvider),
        language: language,
        imageBedRepository: ref.watch(imageBedSettingsRepositoryProvider),
        onRelationsSynced: (memoUids) {
          for (final uid in memoUids) {
            final trimmed = uid.trim();
            if (trimmed.isEmpty) continue;
            ref.invalidate(memoRelationsProvider(trimmed));
          }
        },
      );
    });

class TagStat {
  const TagStat({required this.tag, required this.count});

  final String tag;
  final int count;
}

final tagStatsProvider = StreamProvider<List<TagStat>>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<List<TagStat>> load() async {
    int readInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    final sqlite = await db.db;
    final rows = await sqlite.query(
      'tag_stats_cache',
      columns: const ['tag', 'memo_count'],
    );
    final list = <TagStat>[];
    for (final row in rows) {
      final tag = row['tag'];
      if (tag is! String || tag.trim().isEmpty) continue;
      final count = readInt(row['memo_count']);
      if (count <= 0) continue;
      list.add(TagStat(tag: tag.trim(), count: count));
    }
    list.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.tag.compareTo(b.tag);
    });
    return list;
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

class ResourceEntry {
  const ResourceEntry({
    required this.memoUid,
    required this.memoUpdateTime,
    required this.attachment,
  });

  final String memoUid;
  final DateTime memoUpdateTime;
  final Attachment attachment;
}

final resourcesProvider = StreamProvider<List<ResourceEntry>>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<List<ResourceEntry>> load() async {
    final rows = await db.listMemoAttachmentRows(state: 'NORMAL');
    final entries = <ResourceEntry>[];

    for (final row in rows) {
      final memoUid = row['uid'] as String?;
      final updateTimeSec = row['update_time'] as int?;
      final raw = row['attachments_json'] as String?;
      if (memoUid == null ||
          memoUid.isEmpty ||
          updateTimeSec == null ||
          raw == null ||
          raw.isEmpty) {
        continue;
      }

      final memoUpdateTime = DateTime.fromMillisecondsSinceEpoch(
        updateTimeSec * 1000,
        isUtc: true,
      ).toLocal();

      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              entries.add(
                ResourceEntry(
                  memoUid: memoUid,
                  memoUpdateTime: memoUpdateTime,
                  attachment: Attachment.fromJson(item.cast<String, dynamic>()),
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    entries.sort((a, b) => b.memoUpdateTime.compareTo(a.memoUpdateTime));
    return entries;
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

class RemoteSyncController extends SyncControllerBase {
  RemoteSyncController({
    required this.db,
    required this.api,
    required this.currentUserName,
    required this.syncStatusTracker,
    required this.syncQueueProgressTracker,
    required this.language,
    required this.imageBedRepository,
    this.onRelationsSynced,
  }) : super(const AsyncValue.data(null));

  final AppDatabase db;
  final MemosApi api;
  final String currentUserName;
  final SyncStatusTracker syncStatusTracker;
  final SyncQueueProgressTracker syncQueueProgressTracker;
  final AppLanguage language;
  final ImageBedSettingsRepository imageBedRepository;
  final void Function(Set<String> memoUids)? onRelationsSynced;
  Timer? _retrySyncTimer;
  int _retryBackoffIndex = 0;
  int _syncRunSeq = 0;
  bool _rerunRequestedWhileLoading = false;
  bool _isDisposed = false;
  final String _controllerId =
      'remote_${DateTime.now().toUtc().millisecondsSinceEpoch}_${identityHashCode(Object())}';

  static const List<Duration> _retryBackoffSteps = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 24),
    Duration(seconds: 45),
  ];
  static const int _bulkOutboxTaskLogHeadCount = 3;
  static const int _bulkOutboxTaskLogEvery = 250;
  static const int _outboxProgressLogEvery = 200;
  static const Duration _slowOutboxTaskThreshold = Duration(seconds: 2);

  static int? _parseUserId(String userName) {
    final raw = userName.trim();
    if (raw.isEmpty) return null;
    final lastSegment = raw.contains('/') ? raw.split('/').last : raw;
    return int.tryParse(lastSegment);
  }

  String? get _creatorFilter {
    final id = _parseUserId(currentUserName);
    if (id == null) return null;
    return _buildCreatorFilterExpression(
      creatorId: id,
      useLegacyDialect: api.usesLegacySearchFilterDialect,
    );
  }

  String? get _memoParentName {
    final raw = currentUserName.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('users/')) return raw;
    final id = _parseUserId(raw);
    if (id == null) return null;
    return 'users/$id';
  }

  static String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'] ?? data['detail'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    if (data is String) {
      final s = data.trim();
      if (s.isEmpty) return '';
      // gRPC gateway usually returns JSON, but keep it best-effort.
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final msg =
              decoded['message'] ?? decoded['error'] ?? decoded['detail'];
          if (msg is String && msg.trim().isNotEmpty) return msg.trim();
        }
      } catch (_) {}
      return s;
    }
    return '';
  }

  String _summarizeHttpError(DioException e) {
    final status = e.response?.statusCode;
    final msg = _extractErrorMessage(e.response?.data);

    if (status == null) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return trByLanguageKey(
          language: language,
          key: 'legacy.msg_network_timeout_try',
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        return trByLanguageKey(
          language: language,
          key: 'legacy.msg_network_connection_failed_check_network',
        );
      }
      final raw = e.message ?? '';
      if (raw.trim().isNotEmpty) return raw.trim();
      return trByLanguageKey(
        language: language,
        key: 'legacy.msg_network_request_failed',
      );
    }

    final base = switch (status) {
      400 => trByLanguageKey(
        language: language,
        key: 'legacy.msg_invalid_request_parameters',
      ),
      401 => trByLanguageKey(
        language: language,
        key: 'legacy.msg_authentication_failed_check_token',
      ),
      403 => trByLanguageKey(
        language: language,
        key: 'legacy.msg_insufficient_permissions',
      ),
      404 => trByLanguageKey(
        language: language,
        key: 'legacy.msg_endpoint_not_found_version_mismatch',
      ),
      413 => trByLanguageKey(
        language: language,
        key: 'legacy.msg_attachment_too_large',
      ),
      500 => trByLanguageKey(
        language: language,
        key: 'legacy.msg_server_error',
      ),
      _ => trByLanguageKey(
        language: language,
        key: 'legacy.msg_request_failed',
      ),
    };

    if (msg.isEmpty) {
      return trByLanguageKey(
        language: language,
        key: 'legacy.msg_http_2',
        params: {'base': base, 'status': status},
      );
    }
    return trByLanguageKey(
      language: language,
      key: 'legacy.msg_http',
      params: {'base': base, 'status': status, 'msg': msg},
    );
  }

  static String _detailHttpError(DioException e) {
    final status = e.response?.statusCode;
    final uri = e.requestOptions.uri;
    final msg = _extractErrorMessage(e.response?.data);
    final reason = (e.message ?? '').trim();
    final lowLevel = (e.error?.toString() ?? '').trim();
    final detail = msg.isNotEmpty
        ? msg
        : (reason.isNotEmpty
              ? reason
              : (lowLevel.isNotEmpty ? lowLevel : 'unknown'));
    final parts = <String>[
      if (status != null) 'HTTP $status' else 'HTTP ?',
      '${e.requestOptions.method} $uri',
      detail,
    ];
    return parts.join(' | ');
  }

  static bool _isTransientOutboxNetworkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
      case DioExceptionType.unknown:
        break;
    }

    final texts = <String>[
      e.message ?? '',
      e.error?.toString() ?? '',
      _extractErrorMessage(e.response?.data),
    ];
    final combined = texts.join(' | ').toLowerCase();
    if (combined.trim().isEmpty) return false;

    return combined.contains(
          'connection closed before full header was received',
        ) ||
        combined.contains('connection reset by peer') ||
        combined.contains('connection aborted') ||
        combined.contains('broken pipe') ||
        combined.contains('socketexception') ||
        combined.contains('httpexception');
  }

  static String _normalizeTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final withoutHash = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;
    return withoutHash.toLowerCase();
  }

  static List<String> _mergeTags(List<String> remoteTags, String content) {
    final merged = <String>{};
    for (final tag in remoteTags) {
      final normalized = _normalizeTag(tag);
      if (normalized.isNotEmpty) merged.add(normalized);
    }
    for (final tag in extractTags(content)) {
      final normalized = _normalizeTag(tag);
      if (normalized.isNotEmpty) merged.add(normalized);
    }
    final list = merged.toList(growable: false);
    list.sort();
    return list;
  }

  bool _shouldDuplicateConflictWithRemote({
    required LocalMemo localMemo,
    required Memo remoteMemo,
  }) {
    final remoteUpdateSec =
        remoteMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final localUpdateSec =
        localMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (remoteUpdateSec <= localUpdateSec) {
      return false;
    }
    return !_memoEquivalentLocalAndRemote(localMemo, remoteMemo);
  }

  bool _memoEquivalentLocalAndRemote(LocalMemo localMemo, Memo remoteMemo) {
    if (localMemo.content != remoteMemo.content) return false;
    if (localMemo.visibility != remoteMemo.visibility) return false;
    if (localMemo.pinned != remoteMemo.pinned) return false;
    if (localMemo.state != remoteMemo.state) return false;

    final localTags = List<String>.from(localMemo.tags)..sort();
    final remoteTags = _mergeTags(remoteMemo.tags, remoteMemo.content);
    if (localTags.length != remoteTags.length) return false;
    for (var i = 0; i < localTags.length; i++) {
      if (localTags[i] != remoteTags[i]) return false;
    }

    final localLocation = localMemo.location;
    final remoteLocation = remoteMemo.location;
    if (localLocation == null && remoteLocation != null) return false;
    if (localLocation != null && remoteLocation == null) return false;
    if (localLocation != null && remoteLocation != null) {
      if (localLocation.placeholder.trim() !=
          remoteLocation.placeholder.trim()) {
        return false;
      }
      if ((localLocation.latitude - remoteLocation.latitude).abs() > 1e-7) {
        return false;
      }
      if ((localLocation.longitude - remoteLocation.longitude).abs() > 1e-7) {
        return false;
      }
    }

    final localAttachments =
        localMemo.attachments.map(_attachmentSignature).toList(growable: false)
          ..sort();
    final remoteAttachments =
        remoteMemo.attachments.map(_attachmentSignature).toList(growable: false)
          ..sort();
    if (localAttachments.length != remoteAttachments.length) return false;
    for (var i = 0; i < localAttachments.length; i++) {
      if (localAttachments[i] != remoteAttachments[i]) return false;
    }
    return true;
  }

  String _attachmentSignature(Attachment attachment) {
    return [
      attachment.name.trim(),
      attachment.filename.trim(),
      attachment.type.trim(),
      attachment.size.toString(),
      attachment.externalLink.trim(),
    ].join('|');
  }

  Future<String> _duplicateConflictLocalMemo({
    required LocalMemo localMemo,
    required String? localLastError,
  }) async {
    final duplicateUid = generateUid();
    final normalizedError =
        (localLastError == null || localLastError.trim().isEmpty)
        ? null
        : localLastError.trim();
    await db.upsertMemo(
      uid: duplicateUid,
      content: localMemo.content,
      visibility: localMemo.visibility,
      pinned: localMemo.pinned,
      state: localMemo.state,
      createTimeSec:
          localMemo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec:
          localMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: localMemo.tags,
      attachments: localMemo.attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: localMemo.location,
      relationCount: localMemo.relationCount,
      syncState: 1,
      lastError: normalizedError,
    );
    final rewritten = await db.rewriteOutboxMemoUids(
      oldUid: localMemo.uid,
      newUid: duplicateUid,
    );
    if (rewritten <= 0) {
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': duplicateUid,
          'content': localMemo.content,
          'visibility': localMemo.visibility,
          'pinned': localMemo.pinned,
          'has_attachments': false,
          if (localMemo.location != null)
            'location': localMemo.location!.toJson(),
        },
      );
    }
    return duplicateUid;
  }

  void _cancelRetrySyncTimer() {
    _retrySyncTimer?.cancel();
    _retrySyncTimer = null;
  }

  Duration _consumeRetryDelay() {
    final index = _retryBackoffIndex < 0
        ? 0
        : (_retryBackoffIndex >= _retryBackoffSteps.length
              ? _retryBackoffSteps.length - 1
              : _retryBackoffIndex);
    final delay = _retryBackoffSteps[index];
    if (_retryBackoffIndex < _retryBackoffSteps.length - 1) {
      _retryBackoffIndex++;
    }
    return delay;
  }

  void _resetRetryState() {
    _cancelRetrySyncTimer();
    _retryBackoffIndex = 0;
  }

  Future<bool> _hasPendingOutbox() async {
    final count = await db.countOutboxRetryable();
    return count > 0;
  }

  Future<void> _scheduleRetrySyncIfNeeded({
    required bool hasPendingOutbox,
    required bool syncFailed,
  }) async {
    if (_isDisposed) return;
    if (_retrySyncTimer?.isActive ?? false) return;
    if (!hasPendingOutbox && !syncFailed) {
      _resetRetryState();
      return;
    }
    final delay = _consumeRetryDelay();
    _retrySyncTimer = Timer(delay, () {
      _retrySyncTimer = null;
      if (_isDisposed) return;
      unawaited(syncNow());
    });
  }

  @override
  void dispose() {
    final queueSnapshot = syncQueueProgressTracker.snapshot;
    if (queueSnapshot.syncing) {
      syncQueueProgressTracker.markSyncFinished();
      LogManager.instance.info(
        'RemoteSync: controller_disposed_release_queue_lock',
        context: <String, Object?>{
          'controllerId': _controllerId,
          'queueCurrentOutboxId': queueSnapshot.currentOutboxId,
          'queueTotalTasks': queueSnapshot.totalTasks,
          'queueCompletedTasks': queueSnapshot.completedTasks,
        },
      );
    }
    LogManager.instance.info(
      'RemoteSync: controller_disposed',
      context: <String, Object?>{
        'controllerId': _controllerId,
        'retryTimerActive': _retrySyncTimer?.isActive ?? false,
      },
    );
    _isDisposed = true;
    _cancelRetrySyncTimer();
    super.dispose();
  }

  @override
  Future<void> syncNow() async {
    final runId =
        'run_${DateTime.now().toUtc().millisecondsSinceEpoch}_${++_syncRunSeq}';
    if (_isDisposed) {
      LogManager.instance.info(
        'RemoteSync: sync_skipped_disposed',
        context: <String, Object?>{
          'controllerId': _controllerId,
          'runId': runId,
        },
      );
      return;
    }
    final queueSnapshot = syncQueueProgressTracker.snapshot;
    final globalSyncing = queueSnapshot.syncing;
    final stateLoading = _readStateLoadingSafely(runId: runId) ?? false;
    if (stateLoading || globalSyncing) {
      _rerunRequestedWhileLoading = true;
      LogManager.instance.debug(
        'RemoteSync: sync_skipped_loading',
        context: <String, Object?>{
          'controllerId': _controllerId,
          'runId': runId,
          'rerunRequested': true,
          'stateLoading': stateLoading,
          'globalSyncing': globalSyncing,
          'queueCurrentOutboxId': queueSnapshot.currentOutboxId,
          'queueTotalTasks': queueSnapshot.totalTasks,
          'queueCompletedTasks': queueSnapshot.completedTasks,
          'queueOverallProgress': queueSnapshot.overallProgress,
        },
      );
      return;
    }
    LogManager.instance.info(
      'RemoteSync: sync_start',
      context: <String, Object?>{
        'controllerId': _controllerId,
        'runId': runId,
        'effectiveServerVersion': api.effectiveServerVersion,
        'usesLegacyMemos': api.usesLegacyMemos,
        'requiresCreatorScopedList': api.requiresCreatorScopedListMemos,
      },
    );
    _cancelRetrySyncTimer();
    _rerunRequestedWhileLoading = false;
    syncStatusTracker.markSyncStarted();
    await db.recoverOutboxRunningTasks();
    final totalPendingAtStart = await db.countOutboxPending();
    syncQueueProgressTracker.markSyncStarted(totalTasks: totalPendingAtStart);
    if (!_setStateSafely(
      const AsyncValue.loading(),
      runId: runId,
      stage: 'set_loading',
    )) {
      syncQueueProgressTracker.markSyncFinished();
      return;
    }
    var outboxBlocked = false;
    final next = await AsyncValue.guard(() async {
      await api.ensureServerHintsLoaded();
      if (_isDisposed) {
        _logSyncAbortDisposed(runId: runId, stage: 'after_ensure_server_hints');
        return;
      }
      outboxBlocked = await _processOutbox();
      if (_isDisposed) {
        _logSyncAbortDisposed(runId: runId, stage: 'after_process_outbox');
        return;
      }
      final allowPrivateVisibilityPrune =
          await _allowPrivateVisibilityPruneForCurrentServer();
      if (_isDisposed) {
        _logSyncAbortDisposed(
          runId: runId,
          stage: 'after_resolve_visibility_prune',
        );
        return;
      }
      await _syncStateMemos(
        runId: runId,
        state: 'NORMAL',
        allowPrivateVisibilityPrune: allowPrivateVisibilityPrune,
      );
      if (_isDisposed) {
        _logSyncAbortDisposed(
          runId: runId,
          stage: 'after_sync_normal_state',
          syncState: 'NORMAL',
        );
        return;
      }
      await _syncStateMemos(
        runId: runId,
        state: 'ARCHIVED',
        allowPrivateVisibilityPrune: allowPrivateVisibilityPrune,
      );
    });
    if (_isDisposed) {
      _logSyncAbortDisposed(runId: runId, stage: 'after_guard_before_commit');
      syncQueueProgressTracker.markSyncFinished();
      return;
    }
    if (!_setStateSafely(next, runId: runId, stage: 'set_result')) {
      syncQueueProgressTracker.markSyncFinished();
      return;
    }
    if (next.hasError) {
      syncStatusTracker.markSyncFailed(next.error!);
      LogManager.instance.warn(
        'RemoteSync: sync_failed',
        error: next.error,
        stackTrace: next.stackTrace,
        context: <String, Object?>{
          'controllerId': _controllerId,
          'runId': runId,
          'outboxBlocked': outboxBlocked,
        },
      );
    } else {
      syncStatusTracker.markSyncSuccess();
      LogManager.instance.info(
        'RemoteSync: sync_success',
        context: <String, Object?>{
          'controllerId': _controllerId,
          'runId': runId,
          'outboxBlocked': outboxBlocked,
        },
      );
    }
    syncQueueProgressTracker.markSyncFinished();

    if (!_isDisposed) {
      final hasPendingOutbox = await _hasPendingOutbox();
      final syncFailed = next.hasError;
      if (!hasPendingOutbox && !syncFailed) {
        _resetRetryState();
      } else if (outboxBlocked || syncFailed) {
        await _scheduleRetrySyncIfNeeded(
          hasPendingOutbox: hasPendingOutbox,
          syncFailed: syncFailed,
        );
      }
    }

    if (_rerunRequestedWhileLoading && !_isDisposed) {
      _rerunRequestedWhileLoading = false;
      LogManager.instance.info(
        'RemoteSync: sync_rerun_requested',
        context: <String, Object?>{
          'controllerId': _controllerId,
          'runId': runId,
        },
      );
      unawaited(syncNow());
    }
  }

  bool? _readStateLoadingSafely({required String runId}) {
    try {
      return state.isLoading;
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'RemoteSync: read_state_loading_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'controllerId': _controllerId,
          'runId': runId,
        },
      );
      return null;
    }
  }

  bool _setStateSafely(
    AsyncValue<void> next, {
    required String runId,
    required String stage,
  }) {
    if (_isDisposed) {
      _logSyncAbortDisposed(runId: runId, stage: 'state_set_skipped_$stage');
      return false;
    }
    try {
      state = next;
      return true;
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'RemoteSync: set_state_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'controllerId': _controllerId,
          'runId': runId,
          'stage': stage,
        },
      );
      return false;
    }
  }

  void _logSyncAbortDisposed({
    required String runId,
    required String stage,
    String? syncState,
  }) {
    LogManager.instance.info(
      'RemoteSync: sync_aborted_disposed',
      context: <String, Object?>{
        'controllerId': _controllerId,
        'runId': runId,
        'stage': stage,
        if (syncState != null) 'syncState': syncState,
      },
    );
  }

  Future<bool> _allowPrivateVisibilityPruneForCurrentServer() async {
    // 0.24 deployments may intermittently omit private items from list responses.
    // Keep private/protected rows locally to avoid accidental data loss.
    if (api.isRouteProfileV024) {
      return false;
    }
    return _isAuthenticatedAsCurrentUser();
  }

  Future<bool> _isAuthenticatedAsCurrentUser() async {
    final expectedName = currentUserName.trim();
    if (expectedName.isEmpty) return false;

    try {
      final user = await api.getCurrentUser();
      final actualName = user.name.trim();
      if (actualName.isEmpty) return false;
      if (actualName == expectedName) return true;

      final expectedId = _parseUserId(expectedName);
      final actualId = _parseUserId(actualName);
      if (expectedId != null && actualId != null) {
        return expectedId == actualId;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncStateMemos({
    required String runId,
    required String state,
    required bool allowPrivateVisibilityPrune,
  }) async {
    bool creatorMatchesCurrentUser(String creator) {
      final c = creator.trim();
      if (c.isEmpty) return false;
      if (c == currentUserName) return true;
      final currentId = _parseUserId(currentUserName);
      final creatorId = _parseUserId(c);
      if (currentId != null && creatorId != null) return currentId == creatorId;
      if (currentId != null && c == 'users/$currentId') return true;
      if (creatorId != null && currentUserName == 'users/$creatorId') {
        return true;
      }
      return false;
    }

    var pageToken = '';
    // 0.23 creator-scoped filters are much slower on some deployments.
    var syncPageSize = api.requiresCreatorScopedListMemos ? 600 : 1000;
    // For 0.23, cold list queries can exceed the default large-list timeout.
    // Keep this override scoped to the creator-filter route profile only.
    final syncListReceiveTimeout = api.requiresCreatorScopedListMemos
        ? const Duration(seconds: 180)
        : null;
    final creatorFilter = _creatorFilter;
    final memoParent = _memoParentName;
    final legacyCompat = api.useLegacyApi;
    final needsCreatorScopedList =
        legacyCompat || api.requiresCreatorScopedListMemos;
    final preferParentScopedList = api.isRouteProfileV024;
    var useParent =
        (legacyCompat || preferParentScopedList) &&
        memoParent != null &&
        memoParent.isNotEmpty &&
        api.supportsMemoParentQuery;
    // 0.23 requires creator-scoped list requests to include private memos.
    // Some 0.24.x deployments reject creator filters, so those versions should
    // fall back to local creator filtering.
    var usedServerFilter =
        needsCreatorScopedList && !useParent && creatorFilter != null;
    final remoteUids = <String>{};
    var completed = false;
    var pageCount = 0;
    var remoteFetchedCount = 0;
    var creatorFilteredOutCount = 0;
    var upsertedCount = 0;
    var preservedDraftCount = 0;
    var duplicateConflictCount = 0;
    final duplicateConflictSampleUids = <String>[];
    final pendingOutboxMemoUids = await db.listPendingOutboxMemoUids();

    LogManager.instance.info(
      'RemoteSync state: start',
      context: <String, Object?>{
        'controllerId': _controllerId,
        'runId': runId,
        'state': state,
        'allowPrivateVisibilityPrune': allowPrivateVisibilityPrune,
        'syncPageSize': syncPageSize,
        'usedServerFilter': usedServerFilter,
        'usedParentQuery': useParent,
      },
    );

    while (true) {
      if (_isDisposed) {
        _logSyncAbortDisposed(
          runId: runId,
          stage: 'sync_state_loop_before_request',
          syncState: state,
        );
        return;
      }
      try {
        final (memos, nextToken) = await api.listMemos(
          pageSize: syncPageSize,
          pageToken: pageToken.isEmpty ? null : pageToken,
          state: state,
          filter: usedServerFilter ? creatorFilter : null,
          parent: useParent ? memoParent : null,
          receiveTimeout: syncListReceiveTimeout,
        );
        if (_isDisposed) {
          _logSyncAbortDisposed(
            runId: runId,
            stage: 'sync_state_loop_after_request',
            syncState: state,
          );
          return;
        }
        pageCount++;
        remoteFetchedCount += memos.length;
        LogManager.instance.debug(
          'RemoteSync state: page_received',
          context: <String, Object?>{
            'state': state,
            'page': pageCount,
            'pageSize': syncPageSize,
            'receivedCount': memos.length,
            'hasNextToken': nextToken.isNotEmpty,
          },
        );

        for (final memo in memos) {
          if (_isDisposed) {
            _logSyncAbortDisposed(
              runId: runId,
              stage: 'sync_state_loop_each_memo',
              syncState: state,
            );
            return;
          }
          final creator = memo.creator.trim();
          if (creator.isNotEmpty && !creatorMatchesCurrentUser(creator)) {
            creatorFilteredOutCount++;
            continue;
          }

          final local = await db.getMemoByUid(memo.uid);
          final localSync = (local?['sync_state'] as int?) ?? 0;
          final localMemo = local == null ? null : LocalMemo.fromDb(local);
          var preserveLocalDraft = localMemo != null && localSync != 0;
          var effectiveLocalSync = localSync;
          final hasPendingOutboxForMemo =
              localMemo != null &&
              pendingOutboxMemoUids.contains(localMemo.uid.trim());
          if (localMemo != null &&
              preserveLocalDraft &&
              hasPendingOutboxForMemo &&
              _shouldDuplicateConflictWithRemote(
                localMemo: localMemo,
                remoteMemo: memo,
              )) {
            final duplicateUid = await _duplicateConflictLocalMemo(
              localMemo: localMemo,
              localLastError: (local?['last_error'] as String?)?.trim(),
            );
            pendingOutboxMemoUids.remove(localMemo.uid.trim());
            pendingOutboxMemoUids.add(duplicateUid.trim());
            duplicateConflictCount++;
            if (duplicateConflictSampleUids.length < 8) {
              duplicateConflictSampleUids.add(localMemo.uid.trim());
            }
            preserveLocalDraft = false;
            effectiveLocalSync = 0;
          }
          if (preserveLocalDraft) {
            preservedDraftCount++;
          }
          final draftMemo = preserveLocalDraft ? localMemo! : null;
          final tags = draftMemo != null
              ? draftMemo.tags
              : _mergeTags(memo.tags, memo.content);
          final attachments = memo.attachments
              .map((a) => a.toJson())
              .toList(growable: false);
          final mergedAttachments = draftMemo != null
              ? draftMemo.attachments
                    .map((a) => a.toJson())
                    .toList(growable: false)
              : attachments;
          final relationCount = draftMemo != null
              ? draftMemo.relationCount
              : countReferenceRelations(
                  memoUid: memo.uid,
                  relations: memo.relations,
                );
          final localLastErrorRaw = local?['last_error'];
          final localLastError = localLastErrorRaw is String
              ? localLastErrorRaw
              : null;
          final content = draftMemo != null ? draftMemo.content : memo.content;
          final visibility = draftMemo != null
              ? draftMemo.visibility
              : memo.visibility;
          final pinned = draftMemo != null ? draftMemo.pinned : memo.pinned;
          final memoState = draftMemo != null ? draftMemo.state : memo.state;
          final createTimeSec = draftMemo != null
              ? draftMemo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000
              : (memo.displayTime ?? memo.createTime)
                        .toUtc()
                        .millisecondsSinceEpoch ~/
                    1000;
          final updateTimeSec = draftMemo != null
              ? draftMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000
              : memo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
          final location = draftMemo != null
              ? draftMemo.location
              : memo.location;

          if (memo.uid.isNotEmpty) {
            remoteUids.add(memo.uid);
          }

          await db.upsertMemo(
            uid: memo.uid,
            content: content,
            visibility: visibility,
            pinned: pinned,
            state: memoState,
            createTimeSec: createTimeSec,
            updateTimeSec: updateTimeSec,
            tags: tags,
            attachments: mergedAttachments,
            location: location,
            relationCount: relationCount,
            syncState: effectiveLocalSync == 0 ? 0 : effectiveLocalSync,
            lastError: preserveLocalDraft ? localLastError : null,
          );
          upsertedCount++;
        }

        pageToken = nextToken;
        if (pageToken.isEmpty) {
          completed = true;
          break;
        }
      } on DioException catch (e) {
        if (_isDisposed) {
          _logSyncAbortDisposed(
            runId: runId,
            stage: 'sync_state_dio_exception',
            syncState: state,
          );
          return;
        }
        if ((e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionTimeout) &&
            syncPageSize > 200) {
          final previousPageSize = syncPageSize;
          syncPageSize = syncPageSize > 600 ? 600 : (syncPageSize ~/ 2);
          if (syncPageSize < 200) {
            syncPageSize = 200;
          }
          pageToken = '';
          remoteUids.clear();
          completed = false;
          pageCount = 0;
          remoteFetchedCount = 0;
          creatorFilteredOutCount = 0;
          upsertedCount = 0;
          preservedDraftCount = 0;
          duplicateConflictCount = 0;
          duplicateConflictSampleUids.clear();
          LogManager.instance.warn(
            'RemoteSync state: reduce_page_size_after_timeout',
            context: <String, Object?>{
              'state': state,
              'previousPageSize': previousPageSize,
              'nextPageSize': syncPageSize,
            },
          );
          continue;
        }
        final status = e.response?.statusCode;
        if (useParent && (status == 400 || status == 404 || status == 405)) {
          useParent = false;
          usedServerFilter = needsCreatorScopedList && creatorFilter != null;
          pageToken = '';
          remoteUids.clear();
          completed = false;
          pageCount = 0;
          remoteFetchedCount = 0;
          creatorFilteredOutCount = 0;
          upsertedCount = 0;
          preservedDraftCount = 0;
          duplicateConflictCount = 0;
          duplicateConflictSampleUids.clear();
          LogManager.instance.warn(
            'RemoteSync state: fallback_parent_query_to_filter',
            context: <String, Object?>{'state': state, 'status': status},
          );
          continue;
        }
        if (usedServerFilter &&
            creatorFilter != null &&
            (status == 400 || status == 500)) {
          // Some deployments behave unexpectedly when client-supplied filters are present.
          // Fall back to the default ListMemos behavior and filter locally.
          usedServerFilter = false;
          pageToken = '';
          remoteUids.clear();
          completed = false;
          pageCount = 0;
          remoteFetchedCount = 0;
          creatorFilteredOutCount = 0;
          upsertedCount = 0;
          preservedDraftCount = 0;
          duplicateConflictCount = 0;
          duplicateConflictSampleUids.clear();
          LogManager.instance.warn(
            'RemoteSync state: fallback_server_filter_to_local_filter',
            context: <String, Object?>{'state': state, 'status': status},
          );
          continue;
        }
        final method = e.requestOptions.method;
        final path = e.requestOptions.uri.path;
        final requestLabel = trByLanguageKey(
          language: language,
          key: 'legacy.msg_request_2',
        );
        throw StateError(
          '${_summarizeHttpError(e)} ($requestLabel: $method $path)',
        );
      }
    }

    if (_isDisposed) {
      _logSyncAbortDisposed(
        runId: runId,
        stage: 'sync_state_before_prune',
        syncState: state,
      );
      return;
    }
    var prunedCount = 0;
    if (completed) {
      prunedCount = await _pruneMissingMemos(
        state: state,
        remoteUids: remoteUids,
        allowPrivateVisibilityPrune: allowPrivateVisibilityPrune,
      );
    }
    LogManager.instance.info(
      'RemoteSync state: completed',
      context: <String, Object?>{
        'controllerId': _controllerId,
        'runId': runId,
        'state': state,
        'completed': completed,
        'pages': pageCount,
        'remoteFetched': remoteFetchedCount,
        'creatorFilteredOut': creatorFilteredOutCount,
        'upserted': upsertedCount,
        'preservedDraft': preservedDraftCount,
        'duplicateConflict': duplicateConflictCount,
        if (duplicateConflictSampleUids.isNotEmpty)
          'duplicateConflictSample': duplicateConflictSampleUids,
        'remoteUidCount': remoteUids.length,
        'pruned': prunedCount,
      },
    );
  }

  Future<int> _pruneMissingMemos({
    required String state,
    required Set<String> remoteUids,
    required bool allowPrivateVisibilityPrune,
  }) async {
    if (_isDisposed) return 0;
    final pendingOutbox = await db.listPendingOutboxMemoUids();
    final locals = await db.listMemoUidSyncStates(state: state);
    var deletedCount = 0;
    for (final row in locals) {
      if (_isDisposed) return deletedCount;
      final uid = row['uid'] as String?;
      if (uid == null || uid.trim().isEmpty) continue;
      if (remoteUids.contains(uid)) continue;
      if (pendingOutbox.contains(uid)) continue;
      final syncState = row['sync_state'] as int? ?? 0;
      if (syncState != 0) continue;
      final visibility = ((row['visibility'] as String?) ?? '')
          .trim()
          .toUpperCase();
      if (!allowPrivateVisibilityPrune &&
          (visibility == 'PRIVATE' || visibility == 'PROTECTED')) {
        continue;
      }
      await db.deleteMemoByUid(uid);
      deletedCount++;
    }
    return deletedCount;
  }

  Future<bool> _processOutbox() async {
    var processedCount = 0;
    var successCount = 0;
    var failedCount = 0;
    final typeCounts = <String, int>{};
    String? blockedType;
    String? blockedReason;
    while (true) {
      final headItems = await db.listOutboxPending(limit: 1);
      if (headItems.isEmpty) {
        LogManager.instance.info(
          'RemoteSync outbox: summary',
          context: <String, Object?>{
            'processed': processedCount,
            'succeeded': successCount,
            'failed': failedCount,
            'blocked': false,
            if (typeCounts.isNotEmpty) 'typeCounts': typeCounts,
          },
        );
        return false;
      }

      final head = headItems.first;
      final headId = head['id'] as int?;
      final headType = head['type'] as String?;
      final headState =
          (head['state'] as int?) ?? AppDatabase.outboxStatePending;
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final retryAtRaw = head['retry_at'];
      final retryAtMs = switch (retryAtRaw) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v.trim()),
        _ => null,
      };
      if (headId == null || headType == null) continue;
      if (headState == AppDatabase.outboxStateError) {
        blockedType = headType;
        blockedReason = 'error_head';
        break;
      }
      if (headState == AppDatabase.outboxStateRetry &&
          retryAtMs != null &&
          retryAtMs > nowMs) {
        blockedType = headType;
        blockedReason = 'retry_waiting';
        break;
      }
      if (headState == AppDatabase.outboxStateRunning) {
        await db.recoverOutboxRunningTasks();
        continue;
      }

      final row = await db.claimOutboxTaskById(headId, nowMs: nowMs);
      if (row == null) continue;
      final id = row['id'] as int?;
      final type = row['type'] as String?;
      final payloadRaw = row['payload'] as String?;
      final attemptsSoFar = (row['attempts'] as int?) ?? 0;
      if (id == null || type == null || payloadRaw == null) continue;

      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(payloadRaw) as Map).cast<String, dynamic>();
      } catch (e) {
        await db.markOutboxError(id, error: 'Invalid payload: $e');
        processedCount++;
        failedCount++;
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        LogManager.instance.warn(
          'RemoteSync outbox: invalid_payload',
          error: e,
          context: <String, Object?>{'id': id, 'type': type},
        );
        _maybeLogOutboxProgress(
          processedCount: processedCount,
          successCount: successCount,
          failedCount: failedCount,
          typeCounts: typeCounts,
          currentType: type,
        );
        syncQueueProgressTracker.updateCompletedTasks(
          successCount + failedCount,
        );
        blockedType = type;
        blockedReason = 'invalid_payload';
        break;
      }

      processedCount++;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      final memoUid = _outboxMemoUid(type, payload);
      final shouldLogTaskDetail = _shouldLogOutboxTaskDetail(
        type: type,
        processedCount: processedCount,
      );
      if (shouldLogTaskDetail) {
        LogManager.instance.debug(
          'RemoteSync outbox: task_start',
          context: <String, Object?>{
            'id': id,
            'type': type,
            if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
          },
        );
      }

      var shouldStop = false;
      final isUploadTask = type == 'upload_attachment';
      final taskStartAt = DateTime.now();
      syncQueueProgressTracker.markTaskStarted(id);
      try {
        switch (type) {
          case 'create_memo':
            final uid = await _handleCreateMemo(payload);
            final hasAttachments = payload['has_attachments'] as bool? ?? false;
            if (!hasAttachments && uid != null && uid.isNotEmpty) {
              await db.updateMemoSyncState(uid, syncState: 0);
            }
            await db.markOutboxDone(id);
            await db.deleteOutbox(id);
            break;
          case 'update_memo':
            await _handleUpdateMemo(payload);
            final uid = payload['uid'] as String?;
            final hasPendingAttachments =
                payload['has_pending_attachments'] as bool? ?? false;
            if (!hasPendingAttachments && uid != null && uid.isNotEmpty) {
              await db.updateMemoSyncState(uid, syncState: 0);
            }
            await db.markOutboxDone(id);
            await db.deleteOutbox(id);
            break;
          case 'delete_memo':
            await _handleDeleteMemo(payload);
            await db.markOutboxDone(id);
            await db.deleteOutbox(id);
            break;
          case 'upload_attachment':
            final isFinalized = await _handleUploadAttachment(
              payload,
              currentOutboxId: id,
            );
            final memoUid = payload['memo_uid'] as String?;
            if (isFinalized && memoUid != null && memoUid.isNotEmpty) {
              await db.updateMemoSyncState(memoUid, syncState: 0);
            }
            await db.markOutboxDone(id);
            await db.deleteOutbox(id);
            break;
          case 'delete_attachment':
            await _handleDeleteAttachment(payload);
            final memoUid = payload['memo_uid'] as String?;
            if (memoUid != null && memoUid.isNotEmpty) {
              final pendingUploads = await _countPendingAttachmentUploads(
                memoUid,
              );
              if (pendingUploads <= 0) {
                await db.updateMemoSyncState(memoUid, syncState: 0);
              }
            }
            await db.markOutboxDone(id);
            await db.deleteOutbox(id);
            break;
          case 'submit_log_report':
            await _handleSubmitLogReport(payload);
            await db.markOutboxDone(id);
            await db.deleteOutbox(id);
            break;
          default:
            throw StateError('Unknown op type: $type');
        }
        successCount++;
        final elapsedMs = DateTime.now().difference(taskStartAt).inMilliseconds;
        final isSlowTask = elapsedMs >= _slowOutboxTaskThreshold.inMilliseconds;
        if (shouldLogTaskDetail || isSlowTask) {
          LogManager.instance.debug(
            'RemoteSync outbox: task_done',
            context: <String, Object?>{
              'id': id,
              'type': type,
              if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
              'elapsedMs': elapsedMs,
              if (isSlowTask) 'slow': true,
            },
          );
        }
      } catch (e) {
        failedCount++;
        final elapsedMs = DateTime.now().difference(taskStartAt).inMilliseconds;
        final transientNetworkError =
            e is DioException && _isTransientOutboxNetworkError(e);
        final memoError = e is DioException
            ? _summarizeHttpError(e)
            : e.toString();
        final outboxError = e is DioException
            ? _detailHttpError(e)
            : e.toString();
        if (transientNetworkError) {
          final delay = _retryDelayForOutboxAttempt(attemptsSoFar);
          final retryAt =
              DateTime.now().toUtc().millisecondsSinceEpoch +
              delay.inMilliseconds;
          await db.markOutboxRetryScheduled(
            id,
            error: outboxError,
            retryAtMs: retryAt,
          );
          blockedReason = 'retry_scheduled';
          if (memoUid != null && memoUid.isNotEmpty) {
            await db.updateMemoSyncState(memoUid, syncState: 1);
          }
        } else {
          await db.markOutboxError(id, error: outboxError);
          final failedMemoUid = switch (type) {
            'create_memo' => payload['uid'] as String?,
            'upload_attachment' => payload['memo_uid'] as String?,
            'delete_attachment' => payload['memo_uid'] as String?,
            _ => null,
          };
          if (failedMemoUid != null && failedMemoUid.isNotEmpty) {
            final errorText = trByLanguageKey(
              language: language,
              key: 'legacy.msg_sync_failed',
              params: {'type': type, 'memoError': memoError},
            );
            await db.updateMemoSyncState(
              failedMemoUid,
              syncState: 2,
              lastError: errorText,
            );
          }
          blockedReason = 'error';
        }
        LogManager.instance.warn(
          'RemoteSync outbox: task_failed',
          error: e,
          context: <String, Object?>{
            'id': id,
            'type': type,
            if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
            'transientNetworkError': transientNetworkError,
            'elapsedMs': elapsedMs,
          },
        );
        // Keep ordering: stop processing further ops until this one succeeds.
        blockedType = type;
        shouldStop = true;
      } finally {
        if (!shouldStop && isUploadTask) {
          await syncQueueProgressTracker.markTaskCompleted(outboxId: id);
        }
        syncQueueProgressTracker.clearCurrentTask(outboxId: id);
      }
      _maybeLogOutboxProgress(
        processedCount: processedCount,
        successCount: successCount,
        failedCount: failedCount,
        typeCounts: typeCounts,
        currentType: type,
      );
      syncQueueProgressTracker.updateCompletedTasks(successCount + failedCount);

      if (shouldStop) {
        blockedType = blockedType ?? type;
        break;
      }
    }
    final blockedOnType = blockedType;
    LogManager.instance.info(
      'RemoteSync outbox: summary',
      context: <String, Object?>{
        'processed': processedCount,
        'succeeded': successCount,
        'failed': failedCount,
        'blocked': true,
        'blockedOnType': blockedOnType,
        if (blockedReason != null) 'blockedReason': blockedReason,
        if (typeCounts.isNotEmpty) 'typeCounts': typeCounts,
      },
    );
    return true;
  }

  Future<String?> _handleCreateMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    final content = payload['content'] as String?;
    final visibility = payload['visibility'] as String? ?? 'PRIVATE';
    final pinned = payload['pinned'] as bool? ?? false;
    final location = _parseLocationPayload(payload['location']);
    final displayTime = _parsePayloadTime(
      payload['display_time'] ??
          payload['displayTime'] ??
          payload['create_time'] ??
          payload['createTime'],
    );
    final relationsRaw = payload['relations'];
    final relations = <Map<String, dynamic>>[];
    if (relationsRaw is List) {
      for (final item in relationsRaw) {
        if (item is Map) {
          relations.add(item.cast<String, dynamic>());
        }
      }
    }
    if (uid == null || uid.isEmpty || content == null) {
      throw const FormatException('create_memo missing fields');
    }
    try {
      final created = await api.createMemo(
        memoId: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        location: location,
      );
      final remoteUid = created.uid;
      final targetUid = remoteUid.isNotEmpty ? remoteUid : uid;
      if (relations.isNotEmpty) {
        await _applyMemoRelations(targetUid, relations);
      }
      if (remoteUid.isNotEmpty && remoteUid != uid) {
        await db.renameMemoUid(oldUid: uid, newUid: remoteUid);
        await db.rewriteOutboxMemoUids(oldUid: uid, newUid: remoteUid);
      }
      if (displayTime != null) {
        try {
          await api.updateMemo(memoUid: targetUid, displayTime: displayTime);
        } on DioException catch (e) {
          final status = e.response?.statusCode ?? 0;
          if (status != 400 && status != 404 && status != 405) {
            rethrow;
          }
        }
      }
      return targetUid;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 409) {
        // Already exists (idempotency after retry).
        return uid;
      }
      rethrow;
    }
  }

  DateTime? _parsePayloadTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is int) return _epochToDateTime(raw);
    if (raw is double) return _epochToDateTime(raw.round());
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return _epochToDateTime(asInt);
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed.isUtc ? parsed : parsed.toUtc();
    }
    return null;
  }

  MemoLocation? _parseLocationPayload(dynamic raw) {
    if (raw is Map) {
      return MemoLocation.fromJson(raw.cast<String, dynamic>());
    }
    return null;
  }

  DateTime _epochToDateTime(int value) {
    final ms = value > 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> _handleUpdateMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    if (uid == null || uid.isEmpty) {
      throw const FormatException('update_memo missing uid');
    }
    final content = payload['content'] as String?;
    final visibility = payload['visibility'] as String?;
    final pinned = payload['pinned'] as bool?;
    final state = payload['state'] as String?;
    final hasLocation = payload.containsKey('location');
    final location = _parseLocationPayload(payload['location']);
    final syncAttachments = payload['sync_attachments'] as bool? ?? false;
    final hasPendingAttachments =
        payload['has_pending_attachments'] as bool? ?? false;
    final hasRelations = payload.containsKey('relations');
    final relationsRaw = payload['relations'];
    final relations = <Map<String, dynamic>>[];
    if (relationsRaw is List) {
      for (final item in relationsRaw) {
        if (item is Map) {
          relations.add(item.cast<String, dynamic>());
        }
      }
    }
    if (hasLocation) {
      await api.updateMemo(
        memoUid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        location: payload['location'] == null ? null : location,
      );
    } else {
      await api.updateMemo(
        memoUid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
      );
    }
    if (hasRelations) {
      await _applyMemoRelations(uid, relations);
    }
    if (syncAttachments && !hasPendingAttachments) {
      await _syncMemoAttachments(uid);
    }
  }

  Future<void> _applyMemoRelations(
    String memoUid,
    List<Map<String, dynamic>> relations,
  ) async {
    final normalizedUid = _normalizeMemoUid(memoUid);
    if (normalizedUid.isEmpty) return;
    final memoName = 'memos/$normalizedUid';

    final normalizedRelations = <Map<String, dynamic>>[];
    final seenNames = <String>{};
    for (final relation in relations) {
      final name = _readRelationRelatedMemoName(relation);
      final trimmedName = name.trim();
      if (trimmedName.isEmpty || trimmedName == memoName) continue;
      if (!seenNames.add(trimmedName)) continue;
      normalizedRelations.add(<String, dynamic>{
        'relatedMemo': {'name': trimmedName},
        'type': 'REFERENCE',
      });
    }

    await api.setMemoRelations(
      memoUid: normalizedUid,
      relations: normalizedRelations,
    );
    _notifyRelationsSynced(normalizedUid, normalizedRelations);
  }

  String _readRelationRelatedMemoName(Map<String, dynamic> relation) {
    final relatedRaw = relation['relatedMemo'] ?? relation['related_memo'];
    if (relatedRaw is Map) {
      final name = relatedRaw['name'];
      if (name is String) return name.trim();
    }
    return '';
  }

  void _notifyRelationsSynced(
    String memoUid,
    List<Map<String, dynamic>> relations,
  ) {
    final uids = _collectRelationUids(memoUid: memoUid, relations: relations);
    if (uids.isEmpty) return;
    onRelationsSynced?.call(uids);
  }

  Set<String> _collectRelationUids({
    required String memoUid,
    required List<Map<String, dynamic>> relations,
  }) {
    final uids = <String>{};
    final normalized = _normalizeMemoUid(memoUid);
    if (normalized.isNotEmpty) {
      uids.add(normalized);
    }
    for (final relation in relations) {
      final relatedName = _readRelationRelatedMemoName(relation);
      final relatedUid = _normalizeMemoUid(relatedName);
      if (relatedUid.isNotEmpty) {
        uids.add(relatedUid);
      }
    }
    return uids;
  }

  String _normalizeMemoUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('memos/')) {
      return trimmed.substring('memos/'.length);
    }
    return trimmed;
  }

  bool _shouldLogOutboxTaskDetail({
    required String type,
    required int processedCount,
  }) {
    if (!_isBulkOutboxTaskType(type)) {
      return true;
    }
    if (processedCount <= _bulkOutboxTaskLogHeadCount) {
      return true;
    }
    return processedCount % _bulkOutboxTaskLogEvery == 0;
  }

  bool _isBulkOutboxTaskType(String type) {
    return type == 'create_memo' || type == 'update_memo';
  }

  void _maybeLogOutboxProgress({
    required int processedCount,
    required int successCount,
    required int failedCount,
    required Map<String, int> typeCounts,
    required String currentType,
  }) {
    if (processedCount <= 0 || processedCount % _outboxProgressLogEvery != 0) {
      return;
    }
    LogManager.instance.info(
      'RemoteSync outbox: progress',
      context: <String, Object?>{
        'processed': processedCount,
        'succeeded': successCount,
        'failed': failedCount,
        'currentType': currentType,
        if (typeCounts.isNotEmpty) 'typeCounts': typeCounts,
      },
    );
  }

  Duration _retryDelayForOutboxAttempt(int attemptsSoFar) {
    if (_retryBackoffSteps.isEmpty) {
      return const Duration(seconds: 5);
    }
    final normalizedAttempts = attemptsSoFar < 0 ? 0 : attemptsSoFar;
    final index = normalizedAttempts >= _retryBackoffSteps.length
        ? _retryBackoffSteps.length - 1
        : normalizedAttempts;
    return _retryBackoffSteps[index];
  }

  String? _outboxMemoUid(String type, Map<String, dynamic> payload) {
    return switch (type) {
      'create_memo' ||
      'update_memo' ||
      'delete_memo' => payload['uid'] as String?,
      'upload_attachment' ||
      'delete_attachment' => payload['memo_uid'] as String?,
      _ => null,
    };
  }

  Future<void> _handleDeleteMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    final force = payload['force'] as bool? ?? false;
    if (uid == null || uid.isEmpty) {
      throw const FormatException('delete_memo missing uid');
    }
    try {
      await api.deleteMemo(memoUid: uid, force: force);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) return;
      rethrow;
    }
  }

  Future<bool> _handleUploadAttachment(
    Map<String, dynamic> payload, {
    required int currentOutboxId,
  }) async {
    final uid = payload['uid'] as String?;
    final memoUid = payload['memo_uid'] as String?;
    final filePath = payload['file_path'] as String?;
    final filename = payload['filename'] as String?;
    final mimeType =
        payload['mime_type'] as String? ?? 'application/octet-stream';
    if (uid == null ||
        uid.isEmpty ||
        memoUid == null ||
        memoUid.isEmpty ||
        filePath == null ||
        filename == null) {
      throw const FormatException('upload_attachment missing fields');
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }
    final bytes = await file.readAsBytes();

    if (_isImageMimeType(mimeType)) {
      final settings = await imageBedRepository.read();
      if (settings.enabled) {
        final url = await _uploadImageToImageBed(
          settings: settings,
          bytes: bytes,
          filename: filename,
        );
        await _appendImageBedLink(
          memoUid: memoUid,
          localAttachmentUid: uid,
          imageUrl: url,
        );
        return false;
      }
    }

    if (api.usesLegacyMemos) {
      final created = await _createAttachmentWith409Recovery(
        attachmentId: uid,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: null,
        onSendProgress: (sentBytes, totalBytes) {
          syncQueueProgressTracker.updateCurrentTaskProgress(
            outboxId: currentOutboxId,
            sentBytes: sentBytes,
            totalBytes: totalBytes,
          );
        },
      );

      await _updateLocalMemoAttachment(
        memoUid: memoUid,
        localAttachmentUid: uid,
        filename: filename,
        remote: created,
      );

      final shouldFinalize = await _isLastPendingAttachmentUpload(memoUid);
      if (!shouldFinalize) {
        return false;
      }

      await _syncMemoAttachments(memoUid);
      return true;
    }

    var supportsSetAttachments = true;
    try {
      await api.listMemoAttachments(memoUid: memoUid);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        supportsSetAttachments = false;
      } else {
        rethrow;
      }
    }

    final created = await _createAttachmentWith409Recovery(
      attachmentId: uid,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
      memoUid: supportsSetAttachments ? null : memoUid,
      onSendProgress: (sentBytes, totalBytes) {
        syncQueueProgressTracker.updateCurrentTaskProgress(
          outboxId: currentOutboxId,
          sentBytes: sentBytes,
          totalBytes: totalBytes,
        );
      },
    );

    await _updateLocalMemoAttachment(
      memoUid: memoUid,
      localAttachmentUid: uid,
      filename: filename,
      remote: created,
    );

    final shouldFinalize = await _isLastPendingAttachmentUpload(memoUid);
    if (!supportsSetAttachments || !shouldFinalize) {
      return shouldFinalize;
    }

    await _syncMemoAttachments(memoUid);
    return true;
  }

  bool _isImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
  }

  Uri _resolveImageBedBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Image bed URL is required');
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      throw const FormatException('Invalid image bed URL');
    }
    return sanitizeImageBedBaseUrl(parsed);
  }

  Future<String> _uploadImageToImageBed({
    required ImageBedSettings settings,
    required List<int> bytes,
    required String filename,
  }) async {
    final baseUrl = _resolveImageBedBaseUrl(settings.baseUrl);
    final maxAttempts = (settings.retryCount < 0 ? 0 : settings.retryCount) + 1;
    var lastError = Object();
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await _uploadImageToLsky(
          baseUrl: baseUrl,
          settings: settings,
          bytes: bytes,
          filename: filename,
        );
      } catch (e) {
        lastError = e;
        if (!_shouldRetryImageBedError(e) || attempt == maxAttempts - 1) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw lastError;
  }

  bool _shouldRetryImageBedError(Object error) {
    if (error is ImageBedRequestException) {
      final status = error.statusCode;
      if (status == null) return true;
      if (status == 401 ||
          status == 403 ||
          status == 404 ||
          status == 405 ||
          status == 422) {
        return false;
      }
      if (status == 429) return true;
      return status >= 500;
    }
    return false;
  }

  Future<String> _uploadImageToLsky({
    required Uri baseUrl,
    required ImageBedSettings settings,
    required List<int> bytes,
    required String filename,
  }) async {
    final email = settings.email.trim();
    final password = settings.password;
    final strategyId = settings.strategyId?.trim();
    String? token = settings.authToken?.trim();
    if (token != null && token.isEmpty) {
      token = null;
    }

    Future<String?> fetchToken() async {
      if (email.isEmpty || password.isEmpty) return null;
      final newToken = await ImageBedApi.createLskyToken(
        baseUrl: baseUrl,
        email: email,
        password: password,
      );
      await imageBedRepository.write(settings.copyWith(authToken: newToken));
      return newToken;
    }

    token ??= await fetchToken();

    Future<String> uploadLegacy(String? authToken) {
      return ImageBedApi.uploadLskyLegacy(
        baseUrl: baseUrl,
        bytes: bytes,
        filename: filename,
        token: authToken,
        strategyId: strategyId,
      );
    }

    try {
      return await uploadLegacy(token);
    } on ImageBedRequestException catch (e) {
      if (e.statusCode == 401 && email.isNotEmpty && password.isNotEmpty) {
        await imageBedRepository.write(settings.copyWith(authToken: null));
        final refreshed = await fetchToken();
        if (refreshed != null) {
          return await uploadLegacy(refreshed);
        }
      }

      final isUnsupported = e.statusCode == 404 || e.statusCode == 405;
      if (isUnsupported && strategyId != null && strategyId.isNotEmpty) {
        return ImageBedApi.uploadLskyModern(
          baseUrl: baseUrl,
          bytes: bytes,
          filename: filename,
          storageId: strategyId,
        );
      }

      if (e.statusCode == 401 && (token?.isNotEmpty ?? false)) {
        return await uploadLegacy(null);
      }

      rethrow;
    }
  }

  Future<void> _appendImageBedLink({
    required String memoUid,
    required String localAttachmentUid,
    required String imageUrl,
  }) async {
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    final updatedContent = _appendImageMarkdown(memo.content, imageUrl);

    final expectedNames = <String>{
      'attachments/$localAttachmentUid',
      'resources/$localAttachmentUid',
    };
    final remainingAttachments = memo.attachments
        .where(
          (a) => !expectedNames.contains(a.name) && a.uid != localAttachmentUid,
        )
        .map((a) => a.toJson())
        .toList(growable: false);

    final tags = extractTags(updatedContent);
    final now = DateTime.now().toUtc();
    await db.upsertMemo(
      uid: memo.uid,
      content: updatedContent,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: remainingAttachments,
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': updatedContent,
        'visibility': memo.visibility,
        'pinned': memo.pinned,
      },
    );
  }

  String _appendImageMarkdown(String content, String url) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return content;
    final buffer = StringBuffer(content);
    if (buffer.isNotEmpty && !content.endsWith('\n')) {
      buffer.write('\n');
    }
    buffer.write('![]($trimmedUrl)\n');
    return buffer.toString();
  }

  Future<void> _syncMemoAttachments(String memoUid) async {
    final trimmedUid = memoUid.trim();
    final normalizedUid = trimmedUid.startsWith('memos/')
        ? trimmedUid.substring('memos/'.length)
        : trimmedUid;
    if (normalizedUid.isEmpty) return;
    final localNames = await _listLocalAttachmentNames(normalizedUid);
    try {
      await api.setMemoAttachments(
        memoUid: normalizedUid,
        attachmentNames: localNames,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _handleDeleteAttachment(Map<String, dynamic> payload) async {
    final name =
        payload['attachment_name'] as String? ??
        payload['attachmentName'] as String? ??
        payload['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw const FormatException('delete_attachment missing name');
    }
    try {
      await api.deleteAttachment(attachmentName: name);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) return;
      rethrow;
    }
  }

  Future<void> _handleSubmitLogReport(Map<String, dynamic> payload) async {
    final report = _readPayloadString(payload['report']);
    if (report.isEmpty) {
      throw const FormatException('submit_log_report missing report');
    }

    final createdAt =
        _parsePayloadTime(payload['created_time']) ?? DateTime.now().toUtc();
    final submissionId = _resolveLogSubmissionId(
      raw: payload['submission_id'],
      createdAt: createdAt,
    );
    final apiVersion = api.effectiveServerVersion.trim();
    final title = _readPayloadString(payload['title']);
    final memoTitle = title.isEmpty
        ? 'MemoFlow Log Report (${apiVersion.isEmpty ? 'unknown' : apiVersion})'
        : title;

    final memoId = _buildLogReportMemoId(submissionId);
    final memo = await _createLogReportMemoWith409Recovery(
      memoId: memoId,
      content: _buildLogReportMemoContent(
        title: memoTitle,
        apiVersion: apiVersion,
        createdAt: createdAt,
        report: report,
      ),
    );
    final memoUid = memo.uid.trim();
    if (memoUid.isEmpty) {
      throw StateError('submit_log_report createMemo returned empty uid');
    }

    final attachmentName = await _createLogReportAttachment(
      submissionId: submissionId,
      createdAt: createdAt,
      report: report,
    );
    await _bindLogReportAttachment(
      memoUid: memoUid,
      attachmentName: attachmentName,
    );
  }

  Future<Memo> _createLogReportMemoWith409Recovery({
    required String memoId,
    required String content,
  }) async {
    try {
      return await api.createMemo(
        memoId: memoId,
        content: content,
        visibility: 'PRIVATE',
        pinned: false,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 409) rethrow;
      return api.getMemo(memoUid: memoId);
    }
  }

  Future<String> _createLogReportAttachment({
    required String submissionId,
    required DateTime createdAt,
    required String report,
  }) async {
    final attachment = await _createAttachmentWith409Recovery(
      attachmentId: _buildLogReportAttachmentId(submissionId),
      filename: _buildLogReportFileName(createdAt),
      mimeType: 'text/plain',
      bytes: utf8.encode(report),
      memoUid: null,
    );
    final name = attachment.name.trim();
    if (name.isEmpty) {
      throw StateError(
        'submit_log_report createAttachment returned empty name',
      );
    }
    return name;
  }

  Future<void> _bindLogReportAttachment({
    required String memoUid,
    required String attachmentName,
  }) async {
    try {
      await api.setMemoAttachments(
        memoUid: memoUid,
        attachmentNames: <String>[attachmentName],
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return;
      }
      rethrow;
    }
  }

  String _buildLogReportMemoContent({
    required String title,
    required String apiVersion,
    required DateTime createdAt,
    required String report,
  }) {
    final normalizedReport = report.replaceAll('\r\n', '\n').trim();
    const previewLimit = 1200;
    final preview = normalizedReport.length <= previewLimit
        ? normalizedReport
        : '${normalizedReport.substring(0, previewLimit)}\n...[truncated, see attachment]';
    final versionLabel = apiVersion.trim().isEmpty ? 'unknown' : apiVersion;

    return <String>[
      '# $title',
      '',
      '- Client time (UTC): ${createdAt.toUtc().toIso8601String()}',
      '- API version: $versionLabel',
      '- User: $currentUserName',
      '- Report length: ${normalizedReport.length}',
      '',
      'Preview:',
      '',
      preview,
    ].join('\n');
  }

  String _resolveLogSubmissionId({
    required Object? raw,
    required DateTime createdAt,
  }) {
    final direct = _readPayloadString(raw);
    if (direct.isNotEmpty) {
      final normalized = direct.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      if (normalized.isNotEmpty) return normalized;
    }
    return createdAt.toUtc().microsecondsSinceEpoch.toString();
  }

  String _buildLogReportMemoId(String submissionId) {
    return 'memoflow-log-$submissionId';
  }

  String _buildLogReportAttachmentId(String submissionId) {
    return 'memoflow-log-file-$submissionId';
  }

  String _buildLogReportFileName(DateTime createdAt) {
    final compact = createdAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '_');
    return 'MemoFlow_log_$compact.txt';
  }

  String _readPayloadString(Object? raw) {
    if (raw is String) return raw.trim();
    if (raw == null) return '';
    return raw.toString().trim();
  }

  Future<int> _countPendingAttachmentUploads(String memoUid) async {
    final rows = await db.listOutboxPendingByType('upload_attachment');
    var count = 0;
    for (final row in rows) {
      final payloadRaw = row['payload'];
      if (payloadRaw is! String) continue;
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is! Map) continue;
        final payload = decoded.cast<String, dynamic>();
        final targetMemoUid = payload['memo_uid'];
        if (targetMemoUid is String && targetMemoUid.trim() == memoUid) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<bool> _isLastPendingAttachmentUpload(String memoUid) async {
    final pending = await _countPendingAttachmentUploads(memoUid);
    return pending <= 1;
  }

  Future<List<String>> _listLocalAttachmentNames(String memoUid) async {
    final row = await db.getMemoByUid(memoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final names = <String>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final name = item['name'];
        if (name is String && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }
      return names.toSet().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Attachment> _createAttachmentWith409Recovery({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    required String? memoUid,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    try {
      return await api.createAttachment(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 409) rethrow;
      return api.getAttachment(attachmentUid: attachmentId);
    }
  }

  Future<void> _updateLocalMemoAttachment({
    required String memoUid,
    required String localAttachmentUid,
    required String filename,
    required Attachment remote,
  }) async {
    final row = await db.getMemoByUid(memoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;

    final expectedNames = <String>{
      'attachments/$localAttachmentUid',
      'resources/$localAttachmentUid',
    };

    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final name = (m['name'] as String?) ?? '';
      final fn = (m['filename'] as String?) ?? '';

      if (expectedNames.contains(name) || fn == filename) {
        final next = Map<String, dynamic>.from(m);
        next['name'] = remote.name;
        next['filename'] = remote.filename;
        next['type'] = remote.type;
        next['size'] = remote.size;
        next['externalLink'] = remote.externalLink;
        out.add(next);
        changed = true;
        continue;
      }

      out.add(m);
    }

    if (!changed) return;
    await db.updateMemoAttachmentsJson(
      memoUid,
      attachmentsJson: jsonEncode(out),
    );
  }
}
