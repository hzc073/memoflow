import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../database_provider.dart';
import '../memos_providers.dart';
import '../session_provider.dart';

class LinkMemoController {
  LinkMemoController(this._ref);

  final Ref _ref;

  Future<List<Memo>> loadMemos({required String query}) async {
    final account = _ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final userName = account?.user.name ?? '';
    final trimmed = query.trim();

    if (account == null) {
      final db = _ref.read(databaseProvider);
      final rows = await db.listMemos(
        searchQuery: trimmed.isEmpty ? null : trimmed,
        state: 'NORMAL',
        tag: null,
        startTimeSec: null,
        endTimeSecExclusive: null,
        limit: 200,
      );
      return rows
          .map(LocalMemo.fromDb)
          .map(_memoFromLocal)
          .toList(growable: false);
    }

    final api = _ref.read(memosApiProvider);
    await api.ensureServerHintsLoaded();
    String? filter;
    String? oldFilter;
    String? parent;

    final useLegacyApi = api.useLegacyApi;
    if (useLegacyApi) {
      if (userName.isNotEmpty) {
        parent = userName;
      }
      if (trimmed.isNotEmpty) {
        oldFilter = 'content_search == [${jsonEncode(trimmed)}]';
      }
    } else {
      final userId = _tryExtractUserId(userName);
      final conditions = <String>[];
      if (userId != null) {
        conditions.add(
          _buildCreatorFilterExpression(
            userId,
            useLegacyDialect: api.usesLegacySearchFilterDialect,
          ),
        );
      }
      if (trimmed.isNotEmpty) {
        final escaped = _escapeFilterText(trimmed);
        conditions.add('content.contains("$escaped")');
      }
      if (conditions.isNotEmpty) {
        filter = conditions.join(' && ');
      }
    }

    final (remoteMemos, _) = await api.listMemos(
      pageSize: 200,
      filter: filter,
      oldFilter: oldFilter,
      parent: parent,
      preferModern: true,
    );
    return remoteMemos;
  }
}

String? _tryExtractUserId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.startsWith('users/')
      ? trimmed.substring('users/'.length)
      : trimmed;
  final last = normalized.contains('/') ? normalized.split('/').last : normalized;
  return int.tryParse(last) != null ? last : null;
}

String _escapeFilterText(String input) {
  return input.replaceAll('\\', r'\\').replaceAll('"', r'\"');
}

String _buildCreatorFilterExpression(
  String userId, {
  required bool useLegacyDialect,
}) {
  if (useLegacyDialect) {
    return "creator == 'users/$userId'";
  }
  return 'creator_id == $userId';
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
