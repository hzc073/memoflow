import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tags.dart';
import '../data/api/memos_api.dart';
import '../data/db/app_database.dart';
import '../data/logs/sync_status_tracker.dart';
import '../data/models/attachment.dart';
import '../data/models/local_memo.dart';
import '../state/database_provider.dart';
import '../state/logging_provider.dart';
import '../state/network_log_provider.dart';
import '../state/preferences_provider.dart';
import '../state/session_provider.dart';

typedef MemosQuery = ({
  String searchQuery,
  String state,
  String? tag,
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
  return MemosApi.authenticated(
    baseUrl: account.baseUrl,
    personalAccessToken: account.personalAccessToken,
    useLegacyApi: useLegacyApi,
    logStore: logStore,
    logBuffer: logBuffer,
    breadcrumbStore: breadcrumbStore,
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
        limit: 200,
      )
      .map((rows) => rows.map(LocalMemo.fromDb).toList(growable: false));
});

final syncControllerProvider = StateNotifierProvider<SyncController, AsyncValue<void>>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  if (account == null) {
    throw StateError('Not authenticated');
  }
  return SyncController(
    db: ref.watch(databaseProvider),
    api: ref.watch(memosApiProvider),
    currentUserName: account.user.name,
    syncStatusTracker: ref.read(syncStatusTrackerProvider),
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
    final tagStrings = await db.listTagStrings(state: 'NORMAL');
    final counts = <String, int>{};
    for (final s in tagStrings) {
      for (final t in s.split(' ')) {
        final tag = t.trim();
        if (tag.isEmpty) continue;
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final list = counts.entries.map((e) => TagStat(tag: e.key, count: e.value)).toList(growable: false);
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
  }) : super(const AsyncValue.data(null));

  final AppDatabase db;
  final MemosApi api;
  final String currentUserName;
  final SyncStatusTracker syncStatusTracker;

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

  static String _summarizeHttpError(DioException e) {
    final status = e.response?.statusCode;
    final msg = _extractErrorMessage(e.response?.data);

    if (status == null) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return '网络超时，请稍后重试';
      }
      if (e.type == DioExceptionType.connectionError) {
        return '网络连接失败，请检查网络';
      }
      final raw = e.message ?? '';
      return raw.trim().isEmpty ? '网络请求失败' : raw.trim();
    }

    final base = switch (status) {
      400 => '请求参数错误',
      401 => '认证失败，请检查 Token',
      403 => '权限不足',
      404 => '接口不存在（可能是 Memos 版本不兼容）',
      413 => '附件过大，超过服务器限制',
      500 => '服务器内部错误',
      _ => '请求失败',
    };

    if (msg.isEmpty) return '$base（HTTP $status）';
    return '$base（HTTP $status）：$msg';
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

    while (true) {
      try {
        final (memos, nextToken) = await api.listMemos(
          pageSize: 1000,
          pageToken: pageToken.isEmpty ? null : pageToken,
          state: state,
          filter: usedServerFilter ? creatorFilter : null,
          parent: useParent ? memoParent : null,
        );

        final strictOwnerCheck = !useParent && !usedServerFilter;
        for (final memo in memos) {
          if (strictOwnerCheck && !creatorMatchesCurrentUser(memo.creator)) {
            continue;
          }

          final local = await db.getMemoByUid(memo.uid);
          final localSync = (local?['sync_state'] as int?) ?? 0;
          final tags = _mergeTags(memo.tags, memo.content);
          final attachments = memo.attachments.map((a) => a.toJson()).toList(growable: false);
          final mergedAttachments = localSync == 0 ? attachments : _mergeAttachmentJson(local, attachments);

          await db.upsertMemo(
            uid: memo.uid,
            content: memo.content,
            visibility: memo.visibility,
            pinned: memo.pinned,
            state: memo.state,
            createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            updateTimeSec: memo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            tags: tags,
            attachments: mergedAttachments,
            syncState: localSync == 0 ? 0 : localSync,
          );
        }

        pageToken = nextToken;
        if (pageToken.isEmpty) {
          break;
        }
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (useParent && (status == 400 || status == 404 || status == 405)) {
          useParent = false;
          usedServerFilter = creatorFilter != null;
          pageToken = '';
          continue;
        }
        if (usedServerFilter && creatorFilter != null && (status == 400 || status == 500)) {
          // Some deployments behave unexpectedly when client-supplied filters are present.
          // Fall back to the default ListMemos behavior and filter locally.
          usedServerFilter = false;
          pageToken = '';
          continue;
        }
        final method = e.requestOptions.method;
        final path = e.requestOptions.uri.path;
        throw StateError('${_summarizeHttpError(e)}锛?method $path');
      }
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
            await _handleUploadAttachment(payload);
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
          _ => null,
        };
        if (memoUid != null && memoUid.isNotEmpty) {
          await db.updateMemoSyncState(memoUid, syncState: 2, lastError: '同步失败（$type）：$memoError');
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
    if (uid == null || uid.isEmpty || content == null) {
      throw const FormatException('create_memo missing fields');
    }
    try {
      final created = await api.createMemo(memoId: uid, content: content, visibility: visibility, pinned: pinned);
      final remoteUid = created.uid;
      if (remoteUid.isNotEmpty && remoteUid != uid) {
        await db.renameMemoUid(oldUid: uid, newUid: remoteUid);
        await db.rewriteOutboxMemoUids(oldUid: uid, newUid: remoteUid);
        return remoteUid;
      }
      return uid;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 409) {
        // Already exists (idempotency after retry).
        return uid;
      }
      rethrow;
    }
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
    await api.updateMemo(
      memoUid: uid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
    );
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

  Future<void> _handleUploadAttachment(Map<String, dynamic> payload) async {
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

    if (api.useLegacyApi) {
      List<String> existingNames;
      try {
        final existing = await api.listMemoAttachments(memoUid: memoUid);
        existingNames = existing.map((a) => a.name).where((n) => n.trim().isNotEmpty).toList(growable: false);
      } catch (_) {
        existingNames = await _listLocalAttachmentNames(memoUid);
      }
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

      final names = <String>{
        ...existingNames,
        created.name,
      }.where((n) => n.trim().isNotEmpty).toList(growable: false);

      await api.setMemoAttachments(memoUid: memoUid, attachmentNames: names);
      return;
    }

    List<String>? existingRemoteNames;
    var supportsSetAttachments = true;
    try {
      final existing = await api.listMemoAttachments(memoUid: memoUid);
      existingRemoteNames = existing.map((a) => a.name).where((n) => n.trim().isNotEmpty).toList(growable: false);
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

    if (supportsSetAttachments) {
      final names = <String>{
        ...?existingRemoteNames,
        created.name,
      }.where((n) => n.trim().isNotEmpty).toList(growable: false);
      await api.setMemoAttachments(memoUid: memoUid, attachmentNames: names);
    }
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
