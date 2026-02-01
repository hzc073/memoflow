import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_localization.dart';
import '../core/image_bed_url.dart';
import '../core/memo_relations.dart';
import '../core/tags.dart';
import '../data/api/memos_api.dart';
import '../data/api/image_bed_api.dart';
import '../data/db/app_database.dart';
import '../data/logs/sync_status_tracker.dart';
import '../data/models/attachment.dart';
import '../data/models/image_bed_settings.dart';
import '../data/models/local_memo.dart';
import '../data/models/memo.dart';
import '../data/models/memo_location.dart';
import '../data/models/memo_relation.dart';
import '../data/settings/image_bed_settings_repository.dart';
import '../state/database_provider.dart';
import '../state/image_bed_settings_provider.dart';
import '../state/logging_provider.dart';
import '../state/network_log_provider.dart';
import '../state/preferences_provider.dart';
import '../state/session_provider.dart';

typedef MemosQuery = ({
  String searchQuery,
  String state,
  String? tag,
  int? startTimeSec,
  int? endTimeSecExclusive,
});

typedef ShortcutMemosQuery = ({
  String searchQuery,
  String state,
  String? tag,
  String shortcutFilter,
  int? startTimeSec,
  int? endTimeSecExclusive,
});

final memosApiProvider = Provider<MemosApi>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }
  final useLegacyApi = ref.watch(appPreferencesProvider.select((p) => p.useLegacyApi));
  final logStore = ref.watch(networkLogStoreProvider);
  final logBuffer = ref.watch(networkLogBufferProvider);
  final breadcrumbStore = ref.watch(breadcrumbStoreProvider);
  final logManager = ref.watch(logManagerProvider);
  return MemosApi.authenticated(
    baseUrl: account.baseUrl,
    personalAccessToken: account.personalAccessToken,
    useLegacyApi: useLegacyApi,
    logStore: logStore,
    logBuffer: logBuffer,
    breadcrumbStore: breadcrumbStore,
    logManager: logManager,
  );
});

final memosStreamProvider = StreamProvider.family<List<LocalMemo>, MemosQuery>((ref, query) {
  final db = ref.watch(databaseProvider);
  final search = query.searchQuery.trim();
  return db
      .watchMemos(
        searchQuery: search.isEmpty ? null : search,
        state: query.state,
        tag: query.tag,
        startTimeSec: query.startTimeSec,
        endTimeSecExclusive: query.endTimeSecExclusive,
        limit: 200,
      )
      .map((rows) => rows.map(LocalMemo.fromDb).toList(growable: false));
});

final remoteSearchMemosProvider = StreamProvider.family<List<LocalMemo>, MemosQuery>((ref, query) async* {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }

  final api = ref.watch(memosApiProvider);
  final db = ref.watch(databaseProvider);
  final filters = <String>[];

  final creatorId = _parseUserId(account.user.name);
  if (creatorId != null) {
    filters.add('creator_id == $creatorId');
  }

  final normalizedSearch = query.searchQuery.trim();
  if (normalizedSearch.isNotEmpty) {
    filters.add('content.contains("${_escapeFilterValue(normalizedSearch)}")');
  }

  var normalizedTag = (query.tag ?? '').trim();
  if (normalizedTag.startsWith('#')) {
    normalizedTag = normalizedTag.substring(1);
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
  var seed = <LocalMemo>[];
  try {
    final (memos, _) = await api.listMemos(
      pageSize: 200,
      state: query.state,
      filter: filter,
      orderBy: 'display_time desc',
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
    seed = results;
  } catch (_) {
    final rows = await db.listMemos(
      searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
      state: query.state,
      tag: normalizedTag.isEmpty ? null : normalizedTag,
      startTimeSec: query.startTimeSec,
      endTimeSecExclusive: query.endTimeSecExclusive,
      limit: 200,
    );
    seed = rows.map(LocalMemo.fromDb).toList(growable: false);
  }
  yield seed;

  await for (final _ in db.changes) {
    final refreshed = await _refreshRemoteSeedWithLocal(seed: seed, db: db);
    seed = refreshed;
    yield refreshed;
  }
});

final shortcutMemosProvider = StreamProvider.family<List<LocalMemo>, ShortcutMemosQuery>((ref, query) async* {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }

  final db = ref.watch(databaseProvider);
  final search = query.searchQuery.trim();
  final normalizedTag = (query.tag ?? '').trim();
  final initialPredicate = _buildShortcutPredicate(query.shortcutFilter);

  if (initialPredicate != null) {
    await for (final rows in db.watchMemos(
      searchQuery: search.isEmpty ? null : search,
      state: query.state,
      tag: normalizedTag.isEmpty ? null : normalizedTag,
      startTimeSec: query.startTimeSec,
      endTimeSecExclusive: query.endTimeSecExclusive,
      limit: 200,
    )) {
      final predicate = _buildShortcutPredicate(query.shortcutFilter) ?? initialPredicate;
      yield _filterShortcutMemosFromRows(rows, predicate);
    }
    return;
  }

  final api = ref.watch(memosApiProvider);
  final creatorId = _parseUserId(account.user.name);
  final parent = _buildShortcutParent(creatorId);
  final filter = _buildShortcutFilter(
    creatorId: creatorId,
    searchQuery: query.searchQuery,
    tag: query.tag,
    shortcutFilter: query.shortcutFilter,
    startTimeSec: query.startTimeSec,
    endTimeSecExclusive: query.endTimeSecExclusive,
    includeCreatorId: parent == null,
  );

  var seed = <LocalMemo>[];
  try {
    final (memos, _) = await api.listMemos(
      pageSize: 200,
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
      );
      if (local != null) {
        seed = local;
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

String? _buildShortcutFilter({
  required int? creatorId,
  required String searchQuery,
  required String? tag,
  required String shortcutFilter,
  int? startTimeSec,
  int? endTimeSecExclusive,
  bool includeCreatorId = true,
}) {
  final filters = <String>[];
  if (includeCreatorId && creatorId != null) {
    filters.add('creator_id == $creatorId');
  }

  final normalizedSearch = searchQuery.trim();
  if (normalizedSearch.isNotEmpty) {
    filters.add('content.contains("${_escapeFilterValue(normalizedSearch)}")');
  }

  var normalizedTag = (tag ?? '').trim();
  if (normalizedTag.startsWith('#')) {
    normalizedTag = normalizedTag.substring(1);
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

String _escapeFilterValue(String raw) {
  return raw.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ');
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
}) async {
  final predicate = _buildShortcutPredicate(shortcutFilter);
  if (predicate == null) return null;

  final normalizedSearch = searchQuery.trim();
  final normalizedTag = (tag ?? '').trim();
  final rows = await db.listMemos(
    searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
    state: state,
    tag: normalizedTag.isEmpty ? null : normalizedTag,
    startTimeSec: startTimeSec,
    endTimeSecExclusive: endTimeSecExclusive,
    limit: 200,
  );

  final memos = rows.map(LocalMemo.fromDb).where(predicate).toList(growable: true);
  return _sortShortcutMemos(memos);
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
  final memos = rows.map(LocalMemo.fromDb).where(predicate).toList(growable: true);
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
      tokens.add(_FilterToken(_FilterTokenType.number, input.substring(start, i)));
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
        final expected = values.map(_normalizeFilterTag).where((v) => v.isNotEmpty).toSet();
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
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
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
      relationCount: countReferenceRelations(memoUid: memo.uid, relations: memo.relations),
      location: memo.location,
      syncState: SyncState.synced,
      lastError: null,
    );
  }

final memoRelationsProvider = FutureProvider.family<List<MemoRelation>, String>((ref, memoUid) async {
  final api = ref.watch(memosApiProvider);
  final (relations, _) = await api.listMemoRelations(
    memoUid: memoUid,
    pageSize: 200,
  );
  return relations;
});

final syncControllerProvider = StateNotifierProvider<SyncController, AsyncValue<void>>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }
  final language = ref.watch(appPreferencesProvider.select((p) => p.language));
  return SyncController(
    db: ref.watch(databaseProvider),
    api: ref.watch(memosApiProvider),
    currentUserName: account.user.name,
    syncStatusTracker: ref.read(syncStatusTrackerProvider),
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
      if (memoUid == null || memoUid.isEmpty || updateTimeSec == null || raw == null || raw.isEmpty) continue;

      final memoUpdateTime = DateTime.fromMillisecondsSinceEpoch(updateTimeSec * 1000, isUtc: true).toLocal();

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

class SyncController extends StateNotifier<AsyncValue<void>> {
  SyncController({
    required this.db,
    required this.api,
    required this.currentUserName,
    required this.syncStatusTracker,
    required this.language,
    required this.imageBedRepository,
    this.onRelationsSynced,
  }) : super(const AsyncValue.data(null));

  final AppDatabase db;
  final MemosApi api;
  final String currentUserName;
  final SyncStatusTracker syncStatusTracker;
  final AppLanguage language;
  final ImageBedSettingsRepository imageBedRepository;
  final void Function(Set<String> memoUids)? onRelationsSynced;

  static int? _parseUserId(String userName) {
    final raw = userName.trim();
    if (raw.isEmpty) return null;
    final lastSegment = raw.contains('/') ? raw.split('/').last : raw;
    return int.tryParse(lastSegment);
  }

  String? get _creatorFilter {
    final id = _parseUserId(currentUserName);
    if (id == null) return null;
    return 'creator_id == $id';
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
          final msg = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
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
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return trByLanguage(
          language: language,
          zh: '网络超时，请稍后重试',
          en: 'Network timeout. Please try again.',
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        return trByLanguage(
          language: language,
          zh: '网络连接失败，请检查网络',
          en: 'Network connection failed. Please check your network.',
        );
      }
      final raw = e.message ?? '';
      if (raw.trim().isNotEmpty) return raw.trim();
      return trByLanguage(
        language: language,
        zh: '网络请求失败',
        en: 'Network request failed',
      );
    }

    final base = switch (status) {
      400 => trByLanguage(language: language, zh: '请求参数错误', en: 'Invalid request parameters'),
      401 => trByLanguage(language: language, zh: '认证失败，请检查 Token', en: 'Authentication failed. Check token.'),
      403 => trByLanguage(language: language, zh: '权限不足', en: 'Insufficient permissions'),
      404 => trByLanguage(language: language, zh: '接口不存在（可能是 Memos 版本不兼容）', en: 'Endpoint not found (version mismatch?)'),
      413 => trByLanguage(language: language, zh: '附件过大，超过服务器限制', en: 'Attachment too large'),
      500 => trByLanguage(language: language, zh: '服务器内部错误', en: 'Server error'),
      _ => trByLanguage(language: language, zh: '请求失败', en: 'Request failed'),
    };

    if (msg.isEmpty) {
      return trByLanguage(
        language: language,
        zh: '$base（HTTP $status）',
        en: '$base (HTTP $status)',
      );
    }
    return trByLanguage(
      language: language,
      zh: '$base（HTTP $status）：$msg',
      en: '$base (HTTP $status): $msg',
    );
  }

  static String _detailHttpError(DioException e) {
    final status = e.response?.statusCode;
    final uri = e.requestOptions.uri;
    final msg = _extractErrorMessage(e.response?.data);
    final reason = e.message ?? '';
    final parts = <String>[
      if (status != null) 'HTTP $status' else 'HTTP ?',
      '${e.requestOptions.method} $uri',
      if (msg.isNotEmpty) msg else if (reason.trim().isNotEmpty) reason.trim(),
    ];
    return parts.join(' | ');
  }

  static String _normalizeTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
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

  Future<void> syncNow() async {
    if (state.isLoading) return;
    syncStatusTracker.markSyncStarted();
    state = const AsyncValue.loading();
    final next = await AsyncValue.guard(() async {
      await _processOutbox();
      await _syncStateMemos(state: 'NORMAL');
      await _syncStateMemos(state: 'ARCHIVED');
    });
    state = next;
    if (next.hasError) {
      syncStatusTracker.markSyncFailed(next.error!);
    } else {
      syncStatusTracker.markSyncSuccess();
    }
  }

  Future<void> _syncStateMemos({required String state}) async {
    bool creatorMatchesCurrentUser(String creator) {
      final c = creator.trim();
      if (c.isEmpty) return false;
      if (c == currentUserName) return true;
      final currentId = _parseUserId(currentUserName);
      final creatorId = _parseUserId(c);
      if (currentId != null && creatorId != null) return currentId == creatorId;
      if (currentId != null && c == 'users/$currentId') return true;
      if (creatorId != null && currentUserName == 'users/$creatorId') return true;
      return false;
    }

    var pageToken = '';
    final creatorFilter = _creatorFilter;
    final memoParent = _memoParentName;
    final legacyCompat = api.useLegacyApi;
    var useParent = legacyCompat && memoParent != null && memoParent.isNotEmpty;
    var usedServerFilter = !useParent && creatorFilter != null;
    final remoteUids = <String>{};
    var completed = false;

    while (true) {
      try {
        final (memos, nextToken) = await api.listMemos(
          pageSize: 1000,
          pageToken: pageToken.isEmpty ? null : pageToken,
          state: state,
          filter: usedServerFilter ? creatorFilter : null,
          parent: useParent ? memoParent : null,
        );

        for (final memo in memos) {
          final creator = memo.creator.trim();
          if (creator.isNotEmpty && !creatorMatchesCurrentUser(creator)) {
            continue;
          }

          final local = await db.getMemoByUid(memo.uid);
          final localSync = (local?['sync_state'] as int?) ?? 0;
          final tags = _mergeTags(memo.tags, memo.content);
          final attachments = memo.attachments.map((a) => a.toJson()).toList(growable: false);
          final mergedAttachments = localSync == 0 ? attachments : _mergeAttachmentJson(local, attachments);
          final relationCount = countReferenceRelations(memoUid: memo.uid, relations: memo.relations);

          if (memo.uid.isNotEmpty) {
            remoteUids.add(memo.uid);
          }

          await db.upsertMemo(
            uid: memo.uid,
            content: memo.content,
            visibility: memo.visibility,
            pinned: memo.pinned,
            state: memo.state,
            createTimeSec: (memo.displayTime ?? memo.createTime).toUtc().millisecondsSinceEpoch ~/ 1000,
            updateTimeSec: memo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            tags: tags,
            attachments: mergedAttachments,
            location: memo.location,
            relationCount: relationCount,
            syncState: localSync == 0 ? 0 : localSync,
          );
        }

        pageToken = nextToken;
        if (pageToken.isEmpty) {
          completed = true;
          break;
        }
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (useParent && (status == 400 || status == 404 || status == 405)) {
          useParent = false;
          usedServerFilter = creatorFilter != null;
          pageToken = '';
          remoteUids.clear();
          completed = false;
          continue;
        }
        if (usedServerFilter && creatorFilter != null && (status == 400 || status == 500)) {
          // Some deployments behave unexpectedly when client-supplied filters are present.
          // Fall back to the default ListMemos behavior and filter locally.
          usedServerFilter = false;
          pageToken = '';
          remoteUids.clear();
          completed = false;
          continue;
        }
        final method = e.requestOptions.method;
        final path = e.requestOptions.uri.path;
        final requestLabel = trByLanguage(language: language, zh: '请求', en: 'Request');
        throw StateError('${_summarizeHttpError(e)} ($requestLabel: $method $path)');
      }
    }

    if (completed) {
      await _pruneMissingMemos(state: state, remoteUids: remoteUids);
    }
  }

  Future<void> _pruneMissingMemos({
    required String state,
    required Set<String> remoteUids,
  }) async {
    final pendingOutbox = await db.listPendingOutboxMemoUids();
    final locals = await db.listMemoUidSyncStates(state: state);
    for (final row in locals) {
      final uid = row['uid'] as String?;
      if (uid == null || uid.trim().isEmpty) continue;
      if (remoteUids.contains(uid)) continue;
      if (pendingOutbox.contains(uid)) continue;
      final syncState = row['sync_state'] as int? ?? 0;
      if (syncState != 0) continue;
      await db.deleteMemoByUid(uid);
    }
  }

  Future<void> _processOutbox() async {
    while (true) {
      final items = await db.listOutboxPending(limit: 1);
      if (items.isEmpty) return;
      final row = items.first;
      final id = row['id'] as int?;
      final type = row['type'] as String?;
      final payloadRaw = row['payload'] as String?;
      if (id == null || type == null || payloadRaw == null) continue;

      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(payloadRaw) as Map).cast<String, dynamic>();
      } catch (e) {
        await db.markOutboxError(id, error: 'Invalid payload: $e');
        await db.deleteOutbox(id);
        continue;
      }

      try {
        switch (type) {
          case 'create_memo':
            final uid = await _handleCreateMemo(payload);
            final hasAttachments = payload['has_attachments'] as bool? ?? false;
            if (!hasAttachments && uid != null && uid.isNotEmpty) {
              await db.updateMemoSyncState(uid, syncState: 0);
            }
            await db.deleteOutbox(id);
            break;
          case 'update_memo':
            await _handleUpdateMemo(payload);
            final uid = payload['uid'] as String?;
            if (uid != null && uid.isNotEmpty) {
              await db.updateMemoSyncState(uid, syncState: 0);
            }
            await db.deleteOutbox(id);
            break;
          case 'delete_memo':
            await _handleDeleteMemo(payload);
            await db.deleteOutbox(id);
            break;
          case 'upload_attachment':
            final isFinalized = await _handleUploadAttachment(payload);
            final memoUid = payload['memo_uid'] as String?;
            if (isFinalized && memoUid != null && memoUid.isNotEmpty) {
              await db.updateMemoSyncState(memoUid, syncState: 0);
            }
            await db.deleteOutbox(id);
            break;
          case 'delete_attachment':
            await _handleDeleteAttachment(payload);
            final memoUid = payload['memo_uid'] as String?;
            if (memoUid != null && memoUid.isNotEmpty) {
              await db.updateMemoSyncState(memoUid, syncState: 0);
            }
            await db.deleteOutbox(id);
            break;
          default:
            await db.markOutboxError(id, error: 'Unknown op type: $type');
            await db.deleteOutbox(id);
        }
      } catch (e) {
        final memoError = e is DioException ? _summarizeHttpError(e) : e.toString();
        final outboxError = e is DioException ? _detailHttpError(e) : e.toString();
        await db.markOutboxError(id, error: outboxError);
        final memoUid = switch (type) {
          'create_memo' => payload['uid'] as String?,
          'upload_attachment' => payload['memo_uid'] as String?,
          'delete_attachment' => payload['memo_uid'] as String?,
          _ => null,
        };
        if (memoUid != null && memoUid.isNotEmpty) {
          final errorText = trByLanguage(
            language: language,
            zh: '同步失败（$type）：$memoError',
            en: 'Sync failed ($type): $memoError',
          );
          await db.updateMemoSyncState(memoUid, syncState: 2, lastError: errorText);
        }
        // Keep ordering: stop processing further ops until this one succeeds.
        break;
      }
    }
  }

  Future<String?> _handleCreateMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    final content = payload['content'] as String?;
    final visibility = payload['visibility'] as String? ?? 'PRIVATE';
    final pinned = payload['pinned'] as bool? ?? false;
    final location = _parseLocationPayload(payload['location']);
    final displayTime = _parsePayloadTime(
      payload['display_time'] ?? payload['displayTime'] ?? payload['create_time'] ?? payload['createTime'],
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
    final hasPendingAttachments = payload['has_pending_attachments'] as bool? ?? false;
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

  Future<void> _applyMemoRelations(String memoUid, List<Map<String, dynamic>> relations) async {
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

    await api.setMemoRelations(memoUid: normalizedUid, relations: normalizedRelations);
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

  void _notifyRelationsSynced(String memoUid, List<Map<String, dynamic>> relations) {
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

  Future<bool> _handleUploadAttachment(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    final memoUid = payload['memo_uid'] as String?;
    final filePath = payload['file_path'] as String?;
    final filename = payload['filename'] as String?;
    final mimeType = payload['mime_type'] as String? ?? 'application/octet-stream';
    if (uid == null || uid.isEmpty || memoUid == null || memoUid.isEmpty || filePath == null || filename == null) {
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

    if (api.useLegacyApi) {
      final created = await _createAttachmentWith409Recovery(
        attachmentId: uid,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: null,
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
      if (status == 401 || status == 403 || status == 404 || status == 405 || status == 422) return false;
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
        .where((a) => !expectedNames.contains(a.name) && a.uid != localAttachmentUid)
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

    await db.enqueueOutbox(type: 'update_memo', payload: {
      'uid': memo.uid,
      'content': updatedContent,
      'visibility': memo.visibility,
      'pinned': memo.pinned,
    });
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
    final normalizedUid = trimmedUid.startsWith('memos/') ? trimmedUid.substring('memos/'.length) : trimmedUid;
    if (normalizedUid.isEmpty) return;
    final localNames = await _listLocalAttachmentNames(normalizedUid);
    try {
      await api.setMemoAttachments(memoUid: normalizedUid, attachmentNames: localNames);
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
        payload['attachment_name'] as String? ?? payload['attachmentName'] as String? ?? payload['name'] as String?;
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
  }) async {
    try {
      return await api.createAttachment(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
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
    await db.updateMemoAttachmentsJson(memoUid, attachmentsJson: jsonEncode(out));
  }

  static List<Map<String, dynamic>> _mergeAttachmentJson(Map<String, dynamic>? localRow, List<Map<String, dynamic>> remoteAttachments) {
    final map = <String, Map<String, dynamic>>{};
    for (final a in remoteAttachments) {
      final name = a['name'];
      if (name is String && name.isNotEmpty) {
        map[name] = a;
      }
    }

    final localJson = localRow?['attachments_json'];
    if (localJson is String && localJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(localJson);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final m = item.cast<String, dynamic>();
              final name = m['name'];
              if (name is String && name.isNotEmpty) {
                map.putIfAbsent(name, () => m);
              }
            }
          }
        }
      } catch (_) {}
    }

    return map.values.toList(growable: false);
  }
}
