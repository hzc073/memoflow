import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_localization.dart';
import '../core/tags.dart';
import '../core/uid.dart';
import '../data/db/app_database.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/local_library/local_library_fs.dart';
import '../data/local_library/local_library_naming.dart';
import '../data/local_library/local_library_parser.dart';
import '../data/models/attachment.dart';
import '../data/models/local_memo.dart';
import 'database_provider.dart';
import 'local_library_provider.dart';
import 'preferences_provider.dart';

final localLibraryScannerProvider = Provider<LocalLibraryScanner?>((ref) {
  final library = ref.watch(currentLocalLibraryProvider);
  if (library == null) return null;
  final language = ref.watch(appPreferencesProvider.select((p) => p.language));
  return LocalLibraryScanner(
    db: ref.watch(databaseProvider),
    fileSystem: LocalLibraryFileSystem(library),
    attachmentStore: LocalAttachmentStore(),
    language: language,
  );
});

class LocalLibraryScanner {
  LocalLibraryScanner({
    required this.db,
    required this.fileSystem,
    required this.attachmentStore,
    required this.language,
  });

  final AppDatabase db;
  final LocalLibraryFileSystem fileSystem;
  final LocalAttachmentStore attachmentStore;
  final AppLanguage language;

  Future<void> scanAndMerge(
    BuildContext context, {
    bool forceDisk = false,
  }) async {
    await fileSystem.ensureStructure();
    final memoEntries = await fileSystem.listMemos();
    final diskMemos = <String, LocalLibraryParsedMemo>{};
    final diskAttachments = <String, List<Attachment>>{};

    for (final entry in memoEntries) {
      final raw = await fileSystem.readFileText(entry);
      if (raw == null || raw.trim().isEmpty) continue;
      final parsed = parseLocalLibraryMarkdown(raw);
      var uid = parsed.uid.trim();
      if (uid.isEmpty) {
        final lower = entry.name.toLowerCase();
        if (lower.endsWith('.md.txt')) {
          uid = entry.name.substring(0, entry.name.length - 7);
        } else if (lower.endsWith('.md')) {
          uid = entry.name.substring(0, entry.name.length - 3);
        } else {
          uid = entry.name;
        }
        uid = uid.trim();
      }
      if (uid.isEmpty) continue;
      final attachments = await _loadDiskAttachments(uid);
      diskMemos[uid] = parsed;
      diskAttachments[uid] = attachments;
    }

    final dbRows = await db.listMemosForExport(includeArchived: true);
    final dbByUid = <String, Map<String, dynamic>>{};
    for (final row in dbRows) {
      final uid = row['uid'];
      if (uid is String && uid.trim().isNotEmpty) {
        dbByUid[uid.trim()] = row;
      }
    }

    final pendingUids = await db.listPendingOutboxMemoUids();

    for (final entry in diskMemos.entries) {
      final uid = entry.key;
      final parsed = entry.value;
      final attachments = diskAttachments[uid] ?? const <Attachment>[];
      final row = dbByUid[uid];
      if (row == null) {
        await _upsertMemoFromDisk(uid, parsed, attachments, relationCount: 0);
        continue;
      }

      final localMemo = LocalMemo.fromDb(row);
      final mergedTags = _mergeTags(parsed.tags, parsed.content);
      final needsUpdate = _shouldUpdate(
        localMemo: localMemo,
        parsed: parsed,
        diskAttachments: attachments,
        mergedTags: mergedTags,
      );
      if (!needsUpdate) continue;

      final hasConflict =
          localMemo.syncState != SyncState.synced || pendingUids.contains(uid);
      var useDisk = true;
      if (!forceDisk && hasConflict) {
        useDisk = await _resolveConflict(context, uid, isDeletion: false);
      }
      if (!useDisk) continue;

      await db.deleteOutboxForMemo(uid);
      await _upsertMemoFromDisk(
        uid,
        parsed,
        attachments,
        relationCount: localMemo.relationCount,
      );
    }

    final diskUids = diskMemos.keys.toSet();
    for (final row in dbRows) {
      final uid = row['uid'];
      if (uid is! String || uid.trim().isEmpty) continue;
      final normalized = uid.trim();
      if (diskUids.contains(normalized)) continue;

      final localMemo = LocalMemo.fromDb(row);
      final hasConflict =
          localMemo.syncState != SyncState.synced ||
          pendingUids.contains(normalized);
      var useDisk = true;
      if (!forceDisk && hasConflict) {
        useDisk = await _resolveConflict(context, normalized, isDeletion: true);
      }
      if (!useDisk) continue;

      await db.deleteOutboxForMemo(normalized);
      await db.deleteMemoByUid(normalized);
    }
  }

  bool _shouldUpdate({
    required LocalMemo localMemo,
    required LocalLibraryParsedMemo parsed,
    required List<Attachment> diskAttachments,
    required List<String> mergedTags,
  }) {
    final dbUpdateSec =
        localMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final diskUpdateSec =
        parsed.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (dbUpdateSec != diskUpdateSec) return true;
    if (localMemo.content.trimRight() != parsed.content.trimRight())
      return true;
    if (localMemo.visibility != parsed.visibility) return true;
    if (localMemo.pinned != parsed.pinned) return true;
    if (localMemo.state != parsed.state) return true;
    if (!_listEquals(localMemo.tags, mergedTags)) return true;
    if (!_attachmentsEqual(localMemo.attachments, diskAttachments)) return true;
    return false;
  }

  Future<void> _upsertMemoFromDisk(
    String uid,
    LocalLibraryParsedMemo parsed,
    List<Attachment> attachments, {
    required int relationCount,
  }) async {
    final mergedTags = _mergeTags(parsed.tags, parsed.content);
    await db.upsertMemo(
      uid: uid,
      content: parsed.content.trimRight(),
      visibility: parsed.visibility,
      pinned: parsed.pinned,
      state: parsed.state,
      createTimeSec: parsed.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: parsed.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: mergedTags,
      attachments: attachments.map((a) => a.toJson()).toList(growable: false),
      location: null,
      relationCount: relationCount,
      syncState: 0,
      lastError: null,
    );
  }

  List<String> _mergeTags(List<String> rawTags, String content) {
    final merged = <String>{};
    for (final tag in rawTags) {
      final normalized = _normalizeTag(tag);
      if (normalized.isNotEmpty) merged.add(normalized);
    }
    for (final tag in extractTags(content)) {
      final normalized = _normalizeTag(tag);
      if (normalized.isNotEmpty) merged.add(normalized);
    }
    final list = merged.toList(growable: false)..sort();
    return list;
  }

  String _normalizeTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('#')
        ? trimmed.substring(1).toLowerCase()
        : trimmed.toLowerCase();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _attachmentsEqual(List<Attachment> a, List<Attachment> b) {
    String key(Attachment v) =>
        '${v.uid}|${v.filename}|${v.size}|${v.type}|${v.externalLink.trim()}';
    final aKeys = a.map(key).toList()..sort();
    final bKeys = b.map(key).toList()..sort();
    if (aKeys.length != bKeys.length) return false;
    for (var i = 0; i < aKeys.length; i++) {
      if (aKeys[i] != bKeys[i]) return false;
    }
    return true;
  }

  Future<List<Attachment>> _loadDiskAttachments(String memoUid) async {
    final entries = await fileSystem.listAttachments(memoUid);
    if (entries.isEmpty) return const <Attachment>[];
    final attachments = <Attachment>[];
    for (final entry in entries) {
      final uid = parseAttachmentUidFromFilename(entry.name) ?? generateUid();
      final originalFilename =
          parseAttachmentUidFromFilename(entry.name) == null
          ? entry.name
          : stripAttachmentUidPrefix(entry.name, uid);
      final mimeType = _guessMimeType(originalFilename);
      final archiveName = entry.name;
      final privatePath = await attachmentStore.resolveAttachmentPath(
        memoUid,
        archiveName,
      );
      final file = File(privatePath);
      if (!file.existsSync() || file.lengthSync() != entry.length) {
        await fileSystem.copyToLocal(entry, privatePath);
      }
      attachments.add(
        Attachment(
          name: 'attachments/$uid',
          filename: originalFilename,
          type: mimeType,
          size: entry.length,
          externalLink: Uri.file(privatePath).toString(),
        ),
      );
    }
    return attachments;
  }

  Future<bool> _resolveConflict(
    BuildContext context,
    String memoUid, {
    required bool isDeletion,
  }) async {
    final title = context.tr(zh: '冲突处理', en: 'Resolve conflict');
    final content = isDeletion
        ? context.tr(
            zh: '磁盘缺失该笔记，但本地还有未同步改动。选择“以磁盘为准”将删除本地记录。',
            en: 'The memo is missing on disk but has local pending changes. Use disk to delete locally.',
          )
        : context.tr(
            zh: '磁盘与本地未同步内容冲突。选择“以磁盘为准”将覆盖本地内容。',
            en: 'Disk content conflicts with local pending changes. Use disk to overwrite local content.',
          );
    final result =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.tr(zh: '以本地为准', en: 'Keep local')),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.tr(zh: '以磁盘为准', en: 'Use disk')),
              ),
            ],
          ),
        ) ??
        false;
    return result;
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot == -1 ? '' : lower.substring(dot + 1);
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      '7z' => 'application/x-7z-compressed',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'log' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }
}
