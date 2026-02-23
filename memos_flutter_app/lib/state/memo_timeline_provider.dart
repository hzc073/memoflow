import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:saf_stream/saf_stream.dart';

import '../core/debug_ephemeral_storage.dart';
import '../core/tags.dart';
import '../core/uid.dart';
import '../core/url.dart';
import '../data/db/app_database.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/local_library/local_library_naming.dart';
import '../data/models/account.dart';
import '../data/models/attachment.dart';
import '../data/models/local_memo.dart';
import '../data/models/memo_location.dart';
import '../data/models/memo_version.dart';
import '../data/models/recycle_bin_item.dart';
import 'database_provider.dart';
import 'memos_providers.dart';
import 'session_provider.dart';

final memoTimelineServiceProvider = Provider<MemoTimelineService>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  return MemoTimelineService(
    db: ref.watch(databaseProvider),
    account: account,
    triggerSync: () async {
      await ref.read(syncControllerProvider.notifier).syncNow();
    },
  );
});

final memoVersionsProvider = StreamProvider.family<List<MemoVersion>, String>((
  ref,
  memoUid,
) async* {
  final db = ref.watch(databaseProvider);
  final trimmedUid = memoUid.trim();
  if (trimmedUid.isEmpty) {
    yield const [];
    return;
  }

  Future<List<MemoVersion>> load() async {
    final rows = await db.listMemoVersionsByUid(trimmedUid, limit: 50);
    return rows.map(MemoVersion.fromDb).toList(growable: false);
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final recycleBinItemsProvider = StreamProvider<List<RecycleBinItem>>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(memoTimelineServiceProvider);

  Future<List<RecycleBinItem>> load() async {
    await service.purgeExpiredRecycleBin();
    final rows = await db.listRecycleBinItems();
    return rows.map(RecycleBinItem.fromDb).toList(growable: false);
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

class MemoTimelineService {
  MemoTimelineService({
    required this.db,
    required this.account,
    required this.triggerSync,
  });

  final AppDatabase db;
  final Account? account;
  final Future<void> Function() triggerSync;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
    ),
  );
  final SafStream _safStream = SafStream();
  final LocalAttachmentStore _attachmentStore = LocalAttachmentStore();

  static const int historyMaxVersions = 10;
  static const Duration recycleRetention = Duration(days: 30);
  static const String _storageRootName = 'memo_timeline_storage';
  static const String _versionsRootName = 'versions';
  static const String _recycleRootName = 'recycle_bin';

  Future<void> captureMemoVersion(LocalMemo memo) async {
    final memoUid = memo.uid.trim();
    if (memoUid.isEmpty) return;

    final storageKey = _buildStorageKey(prefix: 'version', memoUid: memoUid);
    final backedAttachments = await _backupAttachments(
      attachments: memo.attachments,
      storageRoot: _versionsRootName,
      storageKey: storageKey,
    );

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final payload = {
      'schema': 1,
      'storageRoot': _versionsRootName,
      'storageKey': storageKey,
      'memo': _memoPayload(memo: memo, attachments: backedAttachments),
    };

    await db.insertMemoVersion(
      memoUid: memoUid,
      snapshotTime: now,
      summary: _memoSummary(memo.content),
      payloadJson: jsonEncode(payload),
    );

    await _pruneMemoVersions(memoUid);
  }

  Future<void> restoreMemoVersion(MemoVersion version) async {
    final memoUid = version.memoUid.trim();
    if (memoUid.isEmpty) {
      throw const FormatException('version memo uid missing');
    }
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found');
    }
    final current = LocalMemo.fromDb(row);
    await captureMemoVersion(current);
    // Overwrite semantics: discard pending sync ops for this memo first.
    await db.deleteOutboxForMemo(current.uid);

    final payloadMemo = _payloadMemo(version.payload);
    final restoredContent = (payloadMemo['content'] as String?) ?? '';
    final restoredVisibility =
        (payloadMemo['visibility'] as String?) ?? current.visibility;
    final restoredPinned = (payloadMemo['pinned'] as bool?) ?? current.pinned;
    final restoredLocation = _parseLocation(payloadMemo['location']);
    final restoredAttachments = await _materializeRestoredAttachments(
      memoUid: current.uid,
      rawAttachments: payloadMemo['attachments'],
    );

    final now = DateTime.now().toUtc();
    final tags = extractTags(restoredContent);
    await db.upsertMemo(
      uid: current.uid,
      content: restoredContent,
      visibility: restoredVisibility,
      pinned: restoredPinned,
      state: current.state,
      createTimeSec: current.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: restoredAttachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: restoredLocation,
      relationCount: current.relationCount,
      syncState: 1,
      lastError: null,
    );

    final hasPendingAttachments = restoredAttachments.isNotEmpty;
    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': current.uid,
        'content': restoredContent,
        'visibility': restoredVisibility,
        'pinned': restoredPinned,
        'location': restoredLocation?.toJson(),
        'sync_attachments': true,
        if (hasPendingAttachments) 'has_pending_attachments': true,
      },
    );

    if (current.attachments.isNotEmpty) {
      await _enqueueDeleteAttachments(
        memoUid: current.uid,
        attachments: current.attachments,
      );
    }

    for (final attachment in restoredAttachments) {
      final filePath = _readLocalFilePathFromAttachment(attachment);
      await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': attachment.uid,
          'memo_uid': current.uid,
          'file_path': filePath,
          'filename': attachment.filename,
          'mime_type': attachment.type,
          'file_size': attachment.size,
        },
      );
    }

    unawaited(triggerSync());
  }

  Future<void> moveMemoToRecycleBin(LocalMemo memo) async {
    final memoUid = memo.uid.trim();
    if (memoUid.isEmpty) return;
    await purgeExpiredRecycleBin();

    final storageKey = _buildStorageKey(prefix: 'memo', memoUid: memoUid);
    final backedAttachments = await _backupAttachments(
      attachments: memo.attachments,
      storageRoot: _recycleRootName,
      storageKey: storageKey,
    );

    final deletedAt = DateTime.now().toUtc();
    final expireAt = deletedAt.add(recycleRetention);
    final payload = {
      'schema': 1,
      'storageRoot': _recycleRootName,
      'storageKey': storageKey,
      'memo': _memoPayload(memo: memo, attachments: backedAttachments),
    };

    await db.insertRecycleBinItem(
      itemType: 'memo',
      memoUid: memoUid,
      summary: _memoSummary(memo.content),
      payloadJson: jsonEncode(payload),
      deletedTime: deletedAt.millisecondsSinceEpoch,
      expireTime: expireAt.millisecondsSinceEpoch,
    );
  }

  Future<void> moveAttachmentToRecycleBin({
    required LocalMemo memo,
    required Attachment attachment,
    required int index,
  }) async {
    final memoUid = memo.uid.trim();
    if (memoUid.isEmpty) return;
    await purgeExpiredRecycleBin();

    final storageKey = _buildStorageKey(prefix: 'attachment', memoUid: memoUid);
    final backed = await _backupAttachments(
      attachments: [attachment],
      storageRoot: _recycleRootName,
      storageKey: storageKey,
    );
    if (backed.isEmpty) {
      throw StateError('Attachment backup failed');
    }

    final payload = {
      'schema': 1,
      'storageRoot': _recycleRootName,
      'storageKey': storageKey,
      'memo_uid': memoUid,
      'index': index,
      'attachment': backed.first.toJson(),
    };
    final deletedAt = DateTime.now().toUtc();
    final expireAt = deletedAt.add(recycleRetention);
    await db.insertRecycleBinItem(
      itemType: 'attachment',
      memoUid: memoUid,
      summary: '${attachment.filename} (${attachment.type})',
      payloadJson: jsonEncode(payload),
      deletedTime: deletedAt.millisecondsSinceEpoch,
      expireTime: expireAt.millisecondsSinceEpoch,
    );
  }

  Future<void> restoreRecycleBinItem(RecycleBinItem item) async {
    if (item.type == RecycleBinItemType.memo) {
      await _restoreMemoFromRecycleItem(item);
    } else {
      await _restoreAttachmentFromRecycleItem(item);
    }
    await _deleteRecycleItemStorage(item.payload);
    await db.deleteRecycleBinItemById(item.id);
    unawaited(triggerSync());
  }

  Future<void> deleteRecycleBinItem(RecycleBinItem item) async {
    await _deleteRecycleItemStorage(item.payload);
    await db.deleteRecycleBinItemById(item.id);
  }

  Future<void> purgeExpiredRecycleBin() async {
    final rows = await db.listRecycleBinItems();
    if (rows.isEmpty) return;
    final now = DateTime.now();
    for (final row in rows) {
      final item = RecycleBinItem.fromDb(row);
      if (!item.isExpired && !now.isAfter(item.expireTime)) continue;
      await _deleteRecycleItemStorage(item.payload);
      await db.deleteRecycleBinItemById(item.id);
    }
  }

  Future<void> clearRecycleBin() async {
    final rows = await db.listRecycleBinItems();
    for (final row in rows) {
      final item = RecycleBinItem.fromDb(row);
      await _deleteRecycleItemStorage(item.payload);
    }
    await db.clearRecycleBinItems();
  }

  Future<void> _restoreMemoFromRecycleItem(RecycleBinItem item) async {
    final payloadMemo = _payloadMemo(item.payload);
    final memoUid = (payloadMemo['uid'] as String?)?.trim().isNotEmpty == true
        ? (payloadMemo['uid'] as String).trim()
        : item.memoUid.trim();
    if (memoUid.isEmpty) {
      throw const FormatException('memo uid missing');
    }

    final existingRow = await db.getMemoByUid(memoUid);
    final existing = existingRow == null ? null : LocalMemo.fromDb(existingRow);
    final content = (payloadMemo['content'] as String?) ?? '';
    final visibility = (payloadMemo['visibility'] as String?) ?? 'PRIVATE';
    final pinned = (payloadMemo['pinned'] as bool?) ?? false;
    final state = (payloadMemo['state'] as String?) ?? 'NORMAL';
    final createTimeSec = _readInt(payloadMemo['create_time']);
    final location = _parseLocation(payloadMemo['location']);
    final restoredAttachments = await _materializeRestoredAttachments(
      memoUid: memoUid,
      rawAttachments: payloadMemo['attachments'],
    );
    final now = DateTime.now().toUtc();
    final safeCreateTimeSec = createTimeSec > 0
        ? createTimeSec
        : now.millisecondsSinceEpoch ~/ 1000;

    await db.upsertMemo(
      uid: memoUid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTimeSec: safeCreateTimeSec,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: extractTags(content),
      attachments: restoredAttachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: location,
      relationCount: existing?.relationCount ?? 0,
      syncState: 1,
      lastError: null,
    );

    final hasPendingAttachments = restoredAttachments.isNotEmpty;
    if (existing == null) {
      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': memoUid,
          'content': content,
          'visibility': visibility,
          'pinned': pinned,
          'has_attachments': hasPendingAttachments,
          if (location != null) 'location': location.toJson(),
        },
      );
      if (state == 'ARCHIVED') {
        await db.enqueueOutbox(
          type: 'update_memo',
          payload: {'uid': memoUid, 'state': 'ARCHIVED'},
        );
      }
    } else {
      await db.enqueueOutbox(
        type: 'update_memo',
        payload: {
          'uid': memoUid,
          'content': content,
          'visibility': visibility,
          'pinned': pinned,
          'state': state,
          'location': location?.toJson(),
          'sync_attachments': true,
          if (hasPendingAttachments) 'has_pending_attachments': true,
        },
      );
    }

    if (existing != null &&
        hasPendingAttachments &&
        existing.attachments.isNotEmpty) {
      await _enqueueDeleteAttachments(
        memoUid: memoUid,
        attachments: existing.attachments,
      );
    }

    for (final attachment in restoredAttachments) {
      final filePath = _readLocalFilePathFromAttachment(attachment);
      await db.enqueueOutbox(
        type: 'upload_attachment',
        payload: {
          'uid': attachment.uid,
          'memo_uid': memoUid,
          'file_path': filePath,
          'filename': attachment.filename,
          'mime_type': attachment.type,
          'file_size': attachment.size,
        },
      );
    }
  }

  Future<void> _restoreAttachmentFromRecycleItem(RecycleBinItem item) async {
    final payload = item.payload;
    final memoUid = (payload['memo_uid'] as String?)?.trim().isNotEmpty == true
        ? (payload['memo_uid'] as String).trim()
        : item.memoUid.trim();
    if (memoUid.isEmpty) {
      throw const FormatException('memo uid missing');
    }

    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found');
    }
    final memo = LocalMemo.fromDb(row);
    final attachmentRaw = payload['attachment'];
    if (attachmentRaw is! Map) {
      throw const FormatException('attachment payload missing');
    }
    final restored = await _materializeRestoredAttachments(
      memoUid: memoUid,
      rawAttachments: [attachmentRaw],
    );
    if (restored.isEmpty) {
      throw StateError('Attachment restore failed');
    }
    final restoredAttachment = restored.first;

    final insertIndex = _readInt(payload['index']);
    final nextAttachments = memo.attachments
        .map((attachment) => attachment.toJson())
        .toList(growable: true);
    final targetIndex = insertIndex.clamp(0, nextAttachments.length);
    nextAttachments.insert(targetIndex, restoredAttachment.toJson());

    final now = DateTime.now().toUtc();
    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: nextAttachments,
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': memo.content,
        'visibility': memo.visibility,
        'pinned': memo.pinned,
        'sync_attachments': true,
        'has_pending_attachments': true,
      },
    );

    final filePath = _readLocalFilePathFromAttachment(restoredAttachment);
    await db.enqueueOutbox(
      type: 'upload_attachment',
      payload: {
        'uid': restoredAttachment.uid,
        'memo_uid': memo.uid,
        'file_path': filePath,
        'filename': restoredAttachment.filename,
        'mime_type': restoredAttachment.type,
        'file_size': restoredAttachment.size,
      },
    );
  }

  Future<void> _pruneMemoVersions(String memoUid) async {
    final overflowIds = await db.listMemoVersionIdsExceedLimit(
      memoUid,
      keep: historyMaxVersions,
    );
    for (final id in overflowIds) {
      final row = await db.getMemoVersionById(id);
      if (row == null) {
        await db.deleteMemoVersionById(id);
        continue;
      }
      final payload = _decodePayload((row['payload_json'] as String?) ?? '{}');
      await _deleteVersionStorage(payload);
      await db.deleteMemoVersionById(id);
    }
  }

  Future<List<Attachment>> _backupAttachments({
    required List<Attachment> attachments,
    required String storageRoot,
    required String storageKey,
  }) async {
    if (attachments.isEmpty) return const [];
    final dir = await _ensureStorageDir(
      storageRoot: storageRoot,
      key: storageKey,
    );
    final backed = <Attachment>[];
    try {
      for (final attachment in attachments) {
        final archiveName = attachmentArchiveName(attachment);
        final destination = File(p.join(dir.path, archiveName));
        await _copyAttachmentSnapshot(
          attachment: attachment,
          destination: destination,
        );
        final size = destination.existsSync() ? destination.lengthSync() : 0;
        backed.add(
          Attachment(
            name: attachment.name,
            filename: attachment.filename,
            type: attachment.type,
            size: size,
            externalLink: Uri.file(destination.path).toString(),
          ),
        );
      }
      return backed;
    } catch (_) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<List<Attachment>> _materializeRestoredAttachments({
    required String memoUid,
    required dynamic rawAttachments,
  }) async {
    if (rawAttachments is! List) return const [];
    final restored = <Attachment>[];
    for (final item in rawAttachments) {
      if (item is! Map) continue;
      final attachment = Attachment.fromJson(item.cast<String, dynamic>());
      final sourcePath = _resolveLocalAttachmentPath(attachment);
      if (sourcePath == null || sourcePath.trim().isEmpty) {
        throw StateError('Attachment file missing');
      }
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        throw StateError('Attachment file missing: $sourcePath');
      }
      final newUid = generateUid();
      final archiveName = attachmentArchiveNameFromPayload(
        attachmentUid: newUid,
        filename: attachment.filename,
      );
      final destinationPath = await _attachmentStore.resolveAttachmentPath(
        memoUid,
        archiveName,
      );
      final destination = File(destinationPath);
      if (!destination.parent.existsSync()) {
        destination.parent.createSync(recursive: true);
      }
      await sourceFile.copy(destination.path);
      final size = destination.existsSync() ? destination.lengthSync() : 0;
      restored.add(
        Attachment(
          name: 'attachments/$newUid',
          filename: attachment.filename,
          type: attachment.type,
          size: size,
          externalLink: Uri.file(destination.path).toString(),
        ),
      );
    }
    return restored;
  }

  Future<void> _copyAttachmentSnapshot({
    required Attachment attachment,
    required File destination,
  }) async {
    if (!destination.parent.existsSync()) {
      destination.parent.createSync(recursive: true);
    }
    final external = attachment.externalLink.trim();
    if (external.startsWith('content://')) {
      await _safStream.copyToLocalFile(external, destination.path);
      return;
    }

    final directPath = _resolveLocalPath(external);
    if (directPath != null && directPath.trim().isNotEmpty) {
      final srcFile = File(directPath);
      if (!srcFile.existsSync()) {
        throw StateError('Attachment file not found: $directPath');
      }
      await srcFile.copy(destination.path);
      return;
    }

    final downloadUrl = _resolveDownloadUrl(attachment: attachment);
    if (downloadUrl.isEmpty) {
      throw StateError('Cannot resolve attachment source');
    }
    final response = await _dio.get<List<int>>(
      downloadUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: _buildAuthHeaders(),
      ),
    );
    final statusCode = response.statusCode ?? 200;
    if (statusCode >= 400 || response.data == null || response.data!.isEmpty) {
      throw StateError('Failed to download attachment');
    }
    await destination.writeAsBytes(response.data!, flush: true);
  }

  Map<String, dynamic> _memoPayload({
    required LocalMemo memo,
    required List<Attachment> attachments,
  }) {
    return <String, dynamic>{
      'uid': memo.uid,
      'content': memo.content,
      'visibility': memo.visibility,
      'pinned': memo.pinned,
      'state': memo.state,
      'create_time': memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      'update_time': memo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      'tags': memo.tags,
      'location': memo.location?.toJson(),
      'relation_count': memo.relationCount,
      'attachments': attachments
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _payloadMemo(Map<String, dynamic> payload) {
    final memo = payload['memo'];
    if (memo is Map) {
      return memo.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }

  Future<Directory> _ensureStorageDir({
    required String storageRoot,
    required String key,
  }) async {
    final root = await _storageRootDir();
    final dir = Directory(p.join(root.path, storageRoot, key));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<Directory> _storageRootDir() async {
    final base = await resolveAppSupportDirectory();
    final root = Directory(p.join(base.path, _storageRootName));
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    return root;
  }

  Future<void> _deleteVersionStorage(Map<String, dynamic> payload) async {
    await _deleteStorageByPayload(payload);
  }

  Future<void> _deleteRecycleItemStorage(Map<String, dynamic> payload) async {
    await _deleteStorageByPayload(payload);
  }

  Future<void> _deleteStorageByPayload(Map<String, dynamic> payload) async {
    final storageRoot = (payload['storageRoot'] as String?)?.trim() ?? '';
    final storageKey = (payload['storageKey'] as String?)?.trim() ?? '';
    if (storageRoot.isEmpty || storageKey.isEmpty) return;
    final root = await _storageRootDir();
    final dir = Directory(p.join(root.path, storageRoot, storageKey));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  String _buildStorageKey({required String prefix, required String memoUid}) {
    final uidPart = sanitizePathSegment(memoUid, fallback: 'memo');
    final ts = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '${prefix}_${uidPart}_$ts';
  }

  String _memoSummary(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '(empty)';
    const max = 80;
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max - 3)}...';
  }

  MemoLocation? _parseLocation(dynamic raw) {
    if (raw is Map) {
      return MemoLocation.fromJson(raw.cast<String, dynamic>());
    }
    return null;
  }

  String _resolveDownloadUrl({required Attachment attachment}) {
    final external = attachment.externalLink.trim();
    if (external.isNotEmpty) {
      if (isAbsoluteUrl(external)) return external;
      if (account != null) {
        return resolveMaybeRelativeUrl(account!.baseUrl, external);
      }
    }
    if (account != null &&
        attachment.name.trim().isNotEmpty &&
        attachment.filename.trim().isNotEmpty) {
      return joinBaseUrl(
        account!.baseUrl,
        'file/${attachment.name}/${attachment.filename}',
      );
    }
    return '';
  }

  Map<String, String> _buildAuthHeaders() {
    final token = account?.personalAccessToken.trim() ?? '';
    if (token.isEmpty) return const <String, String>{};
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  String? _resolveLocalPath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('file://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;
      return uri.toFilePath();
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      final scheme = parsed.scheme.toLowerCase();
      final looksLikeWindowsDrive = scheme.length == 1;
      if (!looksLikeWindowsDrive && scheme != 'file') {
        return null;
      }
    }
    if (trimmed.startsWith('/')) {
      if (_looksLikeServerRelativePath(trimmed)) {
        return null;
      }
      return trimmed;
    }
    if (trimmed.contains(':\\') || trimmed.contains(':/')) return trimmed;
    return null;
  }

  bool _looksLikeServerRelativePath(String rawPath) {
    final normalized = rawPath.trim().toLowerCase();
    // v0.21 resource binary route: /o/r/{uid}
    if (normalized.startsWith('/o/r/')) return true;
    // v0.22-v0.24 resource binary route: /file/resources/{id}[/{filename}]
    if (RegExp(r'^/file/resources/\d+($|[/?#])').hasMatch(normalized)) {
      return true;
    }
    // v0.25+ attachment binary route: /file/attachments/{uid}/{filename}
    if (RegExp(r'^/file/attachments/[^/?#]+($|[/?#])').hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  String _readLocalFilePathFromAttachment(Attachment attachment) {
    final path = _resolveLocalAttachmentPath(attachment);
    if (path == null || path.trim().isEmpty) {
      throw StateError('Attachment local file path missing');
    }
    return path;
  }

  String? _resolveLocalAttachmentPath(Attachment attachment) {
    final external = attachment.externalLink.trim();
    return _resolveLocalPath(external);
  }

  Future<void> _enqueueDeleteAttachments({
    required String memoUid,
    required List<Attachment> attachments,
  }) async {
    for (final attachment in attachments) {
      final name = attachment.name.isNotEmpty
          ? attachment.name
          : attachment.uid;
      if (name.isEmpty) continue;
      await db.enqueueOutbox(
        type: 'delete_attachment',
        payload: {'attachment_name': name, 'memo_uid': memoUid},
      );
    }
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Map<String, dynamic> _decodePayload(String raw) {
    if (raw.trim().isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }
}
