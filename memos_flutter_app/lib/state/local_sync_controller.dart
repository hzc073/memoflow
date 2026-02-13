import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_stream/saf_stream.dart';

import '../core/app_localization.dart';
import '../data/db/app_database.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/local_library/local_library_fs.dart';
import '../data/local_library/local_library_markdown.dart';
import '../data/local_library/local_library_naming.dart';
import '../data/logs/sync_queue_progress_tracker.dart';
import '../data/models/attachment.dart';
import '../data/models/local_memo.dart';
import '../data/logs/sync_status_tracker.dart';
import 'preferences_provider.dart';
import 'sync_controller_base.dart';

class LocalSyncController extends SyncControllerBase {
  LocalSyncController({
    required this.db,
    required this.fileSystem,
    required this.attachmentStore,
    required this.syncStatusTracker,
    required this.syncQueueProgressTracker,
    required this.language,
  }) : super(const AsyncValue.data(null));

  final AppDatabase db;
  final LocalLibraryFileSystem fileSystem;
  final LocalAttachmentStore attachmentStore;
  final SyncStatusTracker syncStatusTracker;
  final SyncQueueProgressTracker syncQueueProgressTracker;
  final AppLanguage language;

  @override
  Future<void> syncNow() async {
    if (state.isLoading) return;
    syncStatusTracker.markSyncStarted();
    syncQueueProgressTracker.markSyncStarted();
    state = const AsyncValue.loading();
    final next = await AsyncValue.guard(() async {
      await fileSystem.ensureStructure();
      await _processOutbox();
      await _ensureIndex();
    });
    state = next;
    if (next.hasError) {
      syncStatusTracker.markSyncFailed(next.error!);
    } else {
      syncStatusTracker.markSyncSuccess();
    }
    syncQueueProgressTracker.markSyncFinished();
  }

  Future<void> _ensureIndex() async {
    final content = _buildIndexContent();
    await fileSystem.writeIndex(content);
  }

  String _buildIndexContent() {
    final now = DateTime.now().toIso8601String();
    return ['# MemoFlow Local Library', '', '- Updated: $now', ''].join('\n');
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

      var shouldStop = false;
      final isUploadTask = type == 'upload_attachment';
      syncQueueProgressTracker.markTaskStarted(id);
      try {
        switch (type) {
          case 'create_memo':
            final uid = await _handleUpsertMemo(payload);
            final hasAttachments = payload['has_attachments'] as bool? ?? false;
            if (!hasAttachments && uid != null && uid.isNotEmpty) {
              await db.updateMemoSyncState(uid, syncState: 0);
            }
            await db.deleteOutbox(id);
            break;
          case 'update_memo':
            final uid = await _handleUpsertMemo(payload);
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
            final finalized = await _handleUploadAttachment(
              payload,
              currentOutboxId: id,
            );
            final memoUid = payload['memo_uid'] as String?;
            if (finalized && memoUid != null && memoUid.isNotEmpty) {
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
        final memoError = e.toString();
        await db.markOutboxError(id, error: memoError);
        final memoUid = switch (type) {
          'create_memo' => payload['uid'] as String?,
          'update_memo' => payload['uid'] as String?,
          'upload_attachment' => payload['memo_uid'] as String?,
          'delete_attachment' => payload['memo_uid'] as String?,
          _ => null,
        };
        if (memoUid != null && memoUid.isNotEmpty) {
          final errorText = trByLanguageKey(
            language: language,
            key: 'legacy.msg_local_sync_failed',
            params: {'type': type, 'memoError': memoError},
          );
          await db.updateMemoSyncState(
            memoUid,
            syncState: 2,
            lastError: errorText,
          );
        }
        shouldStop = true;
      } finally {
        if (!shouldStop && isUploadTask) {
          await syncQueueProgressTracker.markTaskCompleted(outboxId: id);
        }
        syncQueueProgressTracker.clearCurrentTask(outboxId: id);
      }

      if (shouldStop) {
        break;
      }
    }
  }

  Future<String?> _handleUpsertMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    if (uid == null || uid.trim().isEmpty) {
      throw const FormatException('memo uid missing');
    }
    await _writeMemoFromDb(uid.trim());
    return uid.trim();
  }

  Future<void> _writeMemoFromDb(String memoUid) async {
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    final markdown = buildLocalLibraryMarkdown(memo);
    await fileSystem.writeMemo(uid: memoUid, content: markdown);
  }

  Future<void> _handleDeleteMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    if (uid == null || uid.trim().isEmpty) {
      throw const FormatException('delete_memo missing uid');
    }
    await fileSystem.deleteMemo(uid.trim());
    await fileSystem.deleteAttachmentsDir(uid.trim());
    await attachmentStore.deleteMemoDir(uid.trim());
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

    final archiveName = attachmentArchiveNameFromPayload(
      attachmentUid: uid,
      filename: filename,
    );
    final privatePath = await attachmentStore.resolveAttachmentPath(
      memoUid,
      archiveName,
    );
    await _copyToPrivate(filePath, privatePath);

    await fileSystem.writeAttachmentFromFile(
      memoUid: memoUid,
      filename: archiveName,
      srcPath: privatePath,
      mimeType: mimeType,
    );

    final size = File(privatePath).existsSync()
        ? File(privatePath).lengthSync()
        : 0;
    final attachment = Attachment(
      name: 'attachments/$uid',
      filename: filename,
      type: mimeType,
      size: size,
      externalLink: Uri.file(privatePath).toString(),
    );
    await _upsertAttachment(memoUid, attachment);

    return await _isLastPendingAttachmentUpload(memoUid, currentOutboxId);
  }

  Future<void> _handleDeleteAttachment(Map<String, dynamic> payload) async {
    final name =
        payload['attachment_name'] as String? ??
        payload['attachmentName'] as String? ??
        payload['name'] as String?;
    final memoUid = payload['memo_uid'] as String?;
    if (name == null ||
        name.trim().isEmpty ||
        memoUid == null ||
        memoUid.trim().isEmpty) {
      throw const FormatException('delete_attachment missing name');
    }
    final uid = _normalizeAttachmentUid(name);

    final row = await db.getMemoByUid(memoUid);
    if (row == null) return;
    final memo = LocalMemo.fromDb(row);
    final next = <Map<String, dynamic>>[];
    Attachment? removed;
    for (final attachment in memo.attachments) {
      if (attachment.uid == uid || attachment.name == name) {
        removed = attachment;
        continue;
      }
      next.add(attachment.toJson());
    }
    await db.updateMemoAttachmentsJson(
      memoUid,
      attachmentsJson: jsonEncode(next),
    );

    if (removed != null) {
      final archiveName = attachmentArchiveName(removed);
      await fileSystem.deleteAttachment(memoUid, archiveName);
      await attachmentStore.deleteAttachment(memoUid, archiveName);
    }
  }

  Future<void> _upsertAttachment(String memoUid, Attachment attachment) async {
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    final next = <Map<String, dynamic>>[];
    var replaced = false;
    for (final existing in memo.attachments) {
      if (existing.uid == attachment.uid) {
        next.add(attachment.toJson());
        replaced = true;
      } else {
        next.add(existing.toJson());
      }
    }
    if (!replaced) {
      next.add(attachment.toJson());
    }
    await db.updateMemoAttachmentsJson(
      memoUid,
      attachmentsJson: jsonEncode(next),
    );
  }

  Future<void> _copyToPrivate(String src, String destPath) async {
    final trimmed = src.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('file_path missing');
    }
    final resolved = trimmed.startsWith('file://')
        ? Uri.parse(trimmed).toFilePath()
        : trimmed;
    if (resolved == destPath) return;
    if (resolved.startsWith('content://')) {
      await SafStream().copyToLocalFile(resolved, destPath);
      return;
    }
    final file = File(resolved);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', resolved);
    }
    await file.copy(destPath);
  }

  Future<bool> _isLastPendingAttachmentUpload(
    String memoUid,
    int currentOutboxId,
  ) async {
    final rows = await db.listOutboxPendingByType('upload_attachment');
    for (final row in rows) {
      final id = row['id'];
      if (id is int && id == currentOutboxId) continue;
      final payload = row['payload'];
      if (payload is! String || payload.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final target = decoded['memo_uid'] as String?;
          if (target != null && target == memoUid) {
            return false;
          }
        }
      } catch (_) {}
    }
    return true;
  }

  String _normalizeAttachmentUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('attachments/'))
      return trimmed.substring('attachments/'.length);
    if (trimmed.startsWith('resources/'))
      return trimmed.substring('resources/'.length);
    return trimmed;
  }
}
