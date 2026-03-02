import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memo_relations.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/reaction.dart';
import '../../data/models/user.dart';
import '../database_provider.dart';
import '../memo_timeline_provider.dart';
import '../memos_providers.dart';
import '../reminder_scheduler.dart';

class MemoDetailController {
  MemoDetailController(this._ref);

  final Ref _ref;

  Future<LocalMemo?> loadMemoByUid(String uid) async {
    final row = await _ref.read(databaseProvider).getMemoByUid(uid);
    if (row == null) return null;
    return LocalMemo.fromDb(row);
  }

  Future<void> updateLocalAndEnqueue({
    required LocalMemo memo,
    bool? pinned,
    String? state,
  }) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now();

    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: pinned ?? memo.pinned,
      state: state ?? memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: memo.attachments
          .map((a) => a.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        if (pinned != null) 'pinned': pinned,
        if (state != null) 'state': state,
      },
    );
  }

  Future<void> deleteMemo(LocalMemo memo) async {
    final db = _ref.read(databaseProvider);
    final timelineService = _ref.read(memoTimelineServiceProvider);
    await timelineService.moveMemoToRecycleBin(memo);
    await db.deleteMemoByUid(memo.uid);
    await db.enqueueOutbox(
      type: 'delete_memo',
      payload: {'uid': memo.uid, 'force': false},
    );
    await _ref.read(reminderSchedulerProvider).rescheduleAll();
  }

  Future<void> updateMemoContentForTaskToggle({
    required LocalMemo memo,
    required String content,
    required DateTime updateTime,
    required List<String> tags,
  }) async {
    final db = _ref.read(databaseProvider);
    final timelineService = _ref.read(memoTimelineServiceProvider);

    await timelineService.captureMemoVersion(memo);
    await db.upsertMemo(
      uid: memo.uid,
      content: content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: memo.attachments
          .map((a) => a.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': content,
        'visibility': memo.visibility,
        'pinned': memo.pinned,
      },
    );
  }

  Future<void> replaceMemoAttachment({
    required LocalMemo memo,
    required Attachment oldAttachment,
    required List<Attachment> updatedAttachments,
    required int index,
    required String newUid,
    required String filePath,
    required String filename,
    required String mimeType,
    required int size,
    required DateTime now,
  }) async {
    final db = _ref.read(databaseProvider);
    final timelineService = _ref.read(memoTimelineServiceProvider);

    await timelineService.captureMemoVersion(memo);
    await timelineService.moveAttachmentToRecycleBin(
      memo: memo,
      attachment: oldAttachment,
      index: index,
    );
    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: updatedAttachments
          .map((a) => a.toJson())
          .toList(growable: false),
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
    await db.enqueueOutbox(
      type: 'upload_attachment',
      payload: {
        'uid': newUid,
        'memo_uid': memo.uid,
        'file_path': filePath,
        'filename': filename,
        'mime_type': mimeType,
        'file_size': size,
      },
    );
    final oldName = oldAttachment.name.isNotEmpty
        ? oldAttachment.name
        : oldAttachment.uid;
    if (oldName.isNotEmpty) {
      await db.enqueueOutbox(
        type: 'delete_attachment',
        payload: {'attachment_name': oldName, 'memo_uid': memo.uid},
      );
    }
  }

  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})>
  listMemoReactions({required String memoUid, int pageSize = 50}) async {
    final api = _ref.read(memosApiProvider);
    return api.listMemoReactions(memoUid: memoUid, pageSize: pageSize);
  }

  Future<({List<Memo> memos, String nextPageToken, int totalSize})>
  listMemoComments({required String memoUid, int pageSize = 50}) async {
    final api = _ref.read(memosApiProvider);
    return api.listMemoComments(memoUid: memoUid, pageSize: pageSize);
  }

  Future<Memo> createMemoComment({
    required String memoUid,
    required String content,
    required String visibility,
  }) async {
    final api = _ref.read(memosApiProvider);
    return api.createMemoComment(
      memoUid: memoUid,
      content: content,
      visibility: visibility,
    );
  }

  Future<User?> fetchUser({required String name}) async {
    try {
      return await _ref.read(memosApiProvider).getUser(name: name);
    } catch (_) {
      return null;
    }
  }

  Future<LocalMemo?> resolveMemoForOpen({required String uid}) async {
    final db = _ref.read(databaseProvider);
    final row = await db.getMemoByUid(uid);
    LocalMemo? memo = row == null ? null : LocalMemo.fromDb(row);

    if (memo == null) {
      final api = _ref.read(memosApiProvider);
      final remote = await api.getMemo(memoUid: uid);
      final remoteUid = remote.uid.isNotEmpty ? remote.uid : uid;
      await db.upsertMemo(
        uid: remoteUid,
        content: remote.content,
        visibility: remote.visibility,
        pinned: remote.pinned,
        state: remote.state,
        createTimeSec: remote.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: remote.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: remote.tags,
        attachments: remote.attachments
            .map((a) => a.toJson())
            .toList(growable: false),
        location: remote.location,
        relationCount: countReferenceRelations(
          memoUid: remoteUid,
          relations: remote.relations,
        ),
        syncState: 0,
      );
      final refreshed = await db.getMemoByUid(remoteUid);
      if (refreshed != null) {
        memo = LocalMemo.fromDb(refreshed);
      }
    }

    return memo;
  }
}
