import 'dart:convert';
import 'dart:io';

import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/db/app_database.dart';
import '../../data/logs/log_manager.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../../data/local_library/local_library_fs.dart';
import '../../data/local_library/local_library_naming.dart';
import '../../data/local_library/local_library_parser.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import 'sync_error.dart';
import 'sync_types.dart';

class LocalLibraryScanService {
  LocalLibraryScanService({
    required this.db,
    required this.fileSystem,
    required this.attachmentStore,
  });

  final AppDatabase db;
  final LocalLibraryFileSystem fileSystem;
  final LocalAttachmentStore attachmentStore;

  Future<LocalScanResult> scanAndMerge({
    bool forceDisk = false,
    Map<String, bool>? conflictDecisions,
  }) async {
    try {
      return await _scanAndMergeCore(
        forceDisk: forceDisk,
        conflictDecisions: conflictDecisions,
      );
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'LocalLibrary scan: failed',
        error: error,
        stackTrace: stackTrace,
      );
      return LocalScanFailure(
        SyncError(
          code: SyncErrorCode.unknown,
          retryable: false,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> scanAndMergeIncremental({bool forceDisk = false}) async {
    await _scanAndMergeIncrementalCore(forceDisk: forceDisk);
  }

  Future<LocalScanResult> _scanAndMergeCore({
    required bool forceDisk,
    required Map<String, bool>? conflictDecisions,
  }) async {
    final startedAt = DateTime.now();
    LogManager.instance.info(
      'LocalLibrary scan: start',
      context: <String, Object?>{'forceDisk': forceDisk},
    );
    await fileSystem.ensureStructure();
    final memoEntries = await fileSystem.listMemos();
    final diskMemos = <String, LocalLibraryParsedMemo>{};
    final diskAttachments = <String, List<Attachment>>{};
    var parsedMemoCount = 0;
    var skippedEmptyFileCount = 0;
    var skippedMissingUidCount = 0;

    for (final entry in memoEntries) {
      final raw = await fileSystem.readFileText(entry);
      if (raw == null || raw.trim().isEmpty) {
        skippedEmptyFileCount++;
        continue;
      }
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
      if (uid.isEmpty) {
        skippedMissingUidCount++;
        continue;
      }
      final attachments = await _loadDiskAttachments(uid);
      diskMemos[uid] = parsed;
      diskAttachments[uid] = attachments;
      parsedMemoCount++;
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
    var pendingOutboxDeleteGuardSkipCount = 0;
    final pendingOutboxDeleteGuardSkipSample = <String>[];
    final hasPendingOutbox = pendingUids.isNotEmpty;
    final effectiveForceDisk = forceDisk && !hasPendingOutbox;
    if (forceDisk && hasPendingOutbox) {
      LogManager.instance.warn(
        'LocalLibrary scan: force_disk_downgraded_due_pending_outbox',
        context: <String, Object?>{
          'pendingOutboxMemoCount': pendingUids.length,
        },
      );
    }
    var insertedCount = 0;
    var updatedCount = 0;
    var unchangedCount = 0;
    var deletedCount = 0;
    var skippedConflictKeepLocalCount = 0;
    var skippedForceDiskConflictCount = 0;
    var conflictPromptCount = 0;
    var conflictUseDiskCount = 0;
    var outboxClearedCount = 0;
    final deletedSampleUids = <String>[];
    final updatedSampleUids = <String>[];
    final insertedSampleUids = <String>[];
    final skippedForceDiskConflictSampleUids = <String>[];
    final conflicts = <LocalScanConflict>[];

    if (conflictDecisions == null) {
      for (final entry in diskMemos.entries) {
        final uid = entry.key;
        final parsed = entry.value;
        final attachments = diskAttachments[uid] ?? const <Attachment>[];
        final row = dbByUid[uid];
        if (row == null) continue;

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
            localMemo.syncState != SyncState.synced ||
            pendingUids.contains(uid);
        if (!effectiveForceDisk && hasConflict) {
          conflicts.add(
            LocalScanConflict(memoUid: uid, isDeletion: false),
          );
        }
      }

      final diskUids = diskMemos.keys.toSet();
      for (final row in dbRows) {
        final uid = row['uid'];
        if (uid is! String || uid.trim().isEmpty) continue;
        final normalized = uid.trim();
        if (diskUids.contains(normalized)) continue;
        if (hasPendingOutbox) continue;

        final localMemo = LocalMemo.fromDb(row);
        final hasConflict =
            localMemo.syncState != SyncState.synced ||
            pendingUids.contains(normalized);
        if (!effectiveForceDisk && hasConflict) {
          conflicts.add(
            LocalScanConflict(memoUid: normalized, isDeletion: true),
          );
        }
      }

      if (conflicts.isNotEmpty) {
        LogManager.instance.info(
          'LocalLibrary scan: conflicts_detected',
          context: <String, Object?>{
            'conflictCount': conflicts.length,
            'forceDisk': forceDisk,
          },
        );
        return LocalScanConflictResult(conflicts);
      }
    }

    for (final entry in diskMemos.entries) {
      final uid = entry.key;
      final parsed = entry.value;
      final attachments = diskAttachments[uid] ?? const <Attachment>[];
      final row = dbByUid[uid];
      if (row == null) {
        await _upsertMemoFromDisk(uid, parsed, attachments, relationCount: 0);
        insertedCount++;
        if (insertedSampleUids.length < 8) {
          insertedSampleUids.add(uid);
        }
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
      if (!needsUpdate) {
        unchangedCount++;
        continue;
      }

      final hasConflict =
          localMemo.syncState != SyncState.synced || pendingUids.contains(uid);
      if (effectiveForceDisk && hasConflict) {
        skippedForceDiskConflictCount++;
        if (skippedForceDiskConflictSampleUids.length < 8) {
          skippedForceDiskConflictSampleUids.add(uid);
        }
        continue;
      }
      var useDisk = true;
      if (!effectiveForceDisk && hasConflict) {
        conflictPromptCount++;
        useDisk = conflictDecisions?[uid] ?? false;
        if (useDisk) {
          conflictUseDiskCount++;
        } else {
          skippedConflictKeepLocalCount++;
        }
      }
      if (!useDisk) continue;

      await db.deleteOutboxForMemo(uid);
      outboxClearedCount++;
      await _upsertMemoFromDisk(
        uid,
        parsed,
        attachments,
        relationCount: localMemo.relationCount,
      );
      updatedCount++;
      if (updatedSampleUids.length < 8) {
        updatedSampleUids.add(uid);
      }
    }

    final diskUids = diskMemos.keys.toSet();
    for (final row in dbRows) {
      final uid = row['uid'];
      if (uid is! String || uid.trim().isEmpty) continue;
      final normalized = uid.trim();
      if (diskUids.contains(normalized)) continue;
      if (hasPendingOutbox) {
        pendingOutboxDeleteGuardSkipCount++;
        if (pendingOutboxDeleteGuardSkipSample.length < 8) {
          pendingOutboxDeleteGuardSkipSample.add(normalized);
        }
        continue;
      }

      final localMemo = LocalMemo.fromDb(row);
      final hasConflict =
          localMemo.syncState != SyncState.synced ||
          pendingUids.contains(normalized);
      if (effectiveForceDisk && hasConflict) {
        skippedForceDiskConflictCount++;
        if (skippedForceDiskConflictSampleUids.length < 8) {
          skippedForceDiskConflictSampleUids.add(normalized);
        }
        continue;
      }
      var useDisk = true;
      if (!effectiveForceDisk && hasConflict) {
        conflictPromptCount++;
        useDisk = conflictDecisions?[normalized] ?? false;
        if (useDisk) {
          conflictUseDiskCount++;
        } else {
          skippedConflictKeepLocalCount++;
        }
      }
      if (!useDisk) continue;

      await db.deleteOutboxForMemo(normalized);
      outboxClearedCount++;
      await db.deleteMemoByUid(normalized);
      deletedCount++;
      if (deletedSampleUids.length < 8) {
        deletedSampleUids.add(normalized);
      }
    }

    final dbRowsAfter = await db.listMemosForExport(includeArchived: true);
    var dbAfterNormalCount = 0;
    var dbAfterArchivedCount = 0;
    for (final row in dbRowsAfter) {
      final state = (row['state'] as String? ?? '').trim().toUpperCase();
      if (state == 'ARCHIVED') {
        dbAfterArchivedCount++;
      } else {
        dbAfterNormalCount++;
      }
    }
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    LogManager.instance.info(
      'LocalLibrary scan: completed',
      context: <String, Object?>{
        'forceDisk': forceDisk,
        'effectiveForceDisk': effectiveForceDisk,
        'elapsedMs': elapsedMs,
        'diskFiles': memoEntries.length,
        'diskParsed': parsedMemoCount,
        'skippedEmptyFile': skippedEmptyFileCount,
        'skippedMissingUid': skippedMissingUidCount,
        'dbBefore': dbRows.length,
        'dbAfter': dbRowsAfter.length,
        'dbAfterNormal': dbAfterNormalCount,
        'dbAfterArchived': dbAfterArchivedCount,
        'pendingOutboxMemoCount': pendingUids.length,
        'inserted': insertedCount,
        'updated': updatedCount,
        'deleted': deletedCount,
        'unchanged': unchangedCount,
        'conflictPrompted': conflictPromptCount,
        'conflictUseDisk': conflictUseDiskCount,
        'conflictKeepLocal': skippedConflictKeepLocalCount,
        'skippedForceDiskConflict': skippedForceDiskConflictCount,
        'pendingOutboxDeleteGuardSkipped': pendingOutboxDeleteGuardSkipCount,
        'outboxCleared': outboxClearedCount,
        if (insertedSampleUids.isNotEmpty) 'insertedSample': insertedSampleUids,
        if (updatedSampleUids.isNotEmpty) 'updatedSample': updatedSampleUids,
        if (deletedSampleUids.isNotEmpty) 'deletedSample': deletedSampleUids,
        if (skippedForceDiskConflictSampleUids.isNotEmpty)
          'skippedForceDiskConflictSample': skippedForceDiskConflictSampleUids,
        if (pendingOutboxDeleteGuardSkipSample.isNotEmpty)
          'pendingOutboxDeleteGuardSkipSample':
              pendingOutboxDeleteGuardSkipSample,
      },
    );
    // Ensure memo list streams refresh even when scan result is unchanged.
    db.notifyDataChanged();
    return const LocalScanSuccess();
  }

  Future<void> _scanAndMergeIncrementalCore({required bool forceDisk}) async {
    final startedAt = DateTime.now();
    LogManager.instance.info(
      'LocalLibrary scan: incremental_start',
      context: <String, Object?>{'forceDisk': forceDisk},
    );
    await fileSystem.ensureStructure();
    final memoEntries = await fileSystem.listMemos();
    final pendingUids = await db.listPendingOutboxMemoUids();
    final hasPendingOutbox = pendingUids.isNotEmpty;
    final effectiveForceDisk = forceDisk && !hasPendingOutbox;
    if (forceDisk && hasPendingOutbox) {
      LogManager.instance.warn(
        'LocalLibrary scan: incremental_force_disk_downgraded',
        context: <String, Object?>{
          'pendingOutboxMemoCount': pendingUids.length,
        },
      );
    }

    final previousManifest = await _readScanManifestSafe();
    final nextManifestByPath = <String, _ScanManifestEntry>{};
    final currentPaths = <String>{};
    final currentUids = <String>{};
    var parsedAttemptedCount = 0;
    var reusedByManifestCount = 0;
    var skippedEmptyFileCount = 0;
    var skippedMissingUidCount = 0;
    var insertedCount = 0;
    var updatedCount = 0;
    var unchangedCount = 0;
    var deletedCount = 0;
    var movedPathDropCount = 0;
    var skippedConflictKeepLocalCount = 0;
    var skippedForceDiskConflictCount = 0;
    var pendingOutboxDeleteGuardSkipCount = 0;
    var outboxClearedCount = 0;
    var staleManifestPrunedCount = 0;
    final insertedSampleUids = <String>[];
    final updatedSampleUids = <String>[];
    final deletedSampleUids = <String>[];
    final conflictSkippedSampleUids = <String>[];

    for (final entry in memoEntries) {
      final path = entry.relativePath;
      currentPaths.add(path);
      final cached = previousManifest.entriesByPath[path];
      final canReuse =
          !effectiveForceDisk &&
          cached != null &&
          !cached.needsRecheck &&
          _manifestEntryMatchesFile(cached, entry);
      if (canReuse) {
        reusedByManifestCount++;
        nextManifestByPath[path] = cached;
        final cachedUid = cached.uid.trim();
        if (cachedUid.isNotEmpty) currentUids.add(cachedUid);
        continue;
      }

      parsedAttemptedCount++;
      final raw = await fileSystem.readFileText(entry);
      if (raw == null || raw.trim().isEmpty) {
        skippedEmptyFileCount++;
        if (cached != null) {
          nextManifestByPath[path] = cached;
          final cachedUid = cached.uid.trim();
          if (cachedUid.isNotEmpty) currentUids.add(cachedUid);
        }
        continue;
      }
      final parsed = parseLocalLibraryMarkdown(raw);
      final uid = _resolveMemoUid(parsed: parsed, entryName: entry.name);
      if (uid.isEmpty) {
        skippedMissingUidCount++;
        if (cached != null) {
          nextManifestByPath[path] = cached;
          final cachedUid = cached.uid.trim();
          if (cachedUid.isNotEmpty) currentUids.add(cachedUid);
        }
        continue;
      }

      final attachments = await _loadDiskAttachments(uid);
      final row = await db.getMemoByUid(uid);
      var shouldPersistCurrentManifest = true;

      if (row == null) {
        await _upsertMemoFromDisk(uid, parsed, attachments, relationCount: 0);
        insertedCount++;
        if (insertedSampleUids.length < 8) {
          insertedSampleUids.add(uid);
        }
      } else {
        final localMemo = LocalMemo.fromDb(row);
        final mergedTags = _mergeTags(parsed.tags, parsed.content);
        final needsUpdate = _shouldUpdate(
          localMemo: localMemo,
          parsed: parsed,
          diskAttachments: attachments,
          mergedTags: mergedTags,
        );
        if (!needsUpdate) {
          unchangedCount++;
        } else {
          final hasConflict =
              localMemo.syncState != SyncState.synced ||
              pendingUids.contains(uid);
          if (effectiveForceDisk && hasConflict) {
            skippedForceDiskConflictCount++;
            shouldPersistCurrentManifest = false;
            if (conflictSkippedSampleUids.length < 8) {
              conflictSkippedSampleUids.add(uid);
            }
          } else if (hasConflict) {
            skippedConflictKeepLocalCount++;
            shouldPersistCurrentManifest = false;
            if (conflictSkippedSampleUids.length < 8) {
              conflictSkippedSampleUids.add(uid);
            }
          } else {
            await db.deleteOutboxForMemo(uid);
            outboxClearedCount++;
            await _upsertMemoFromDisk(
              uid,
              parsed,
              attachments,
              relationCount: localMemo.relationCount,
            );
            updatedCount++;
            if (updatedSampleUids.length < 8) {
              updatedSampleUids.add(uid);
            }
          }
        }
      }

      if (shouldPersistCurrentManifest) {
        final manifestEntry = _ScanManifestEntry(
          uid: uid,
          length: entry.length,
          modifiedMs: _entryModifiedMs(entry),
          needsRecheck: false,
        );
        nextManifestByPath[path] = manifestEntry;
        currentUids.add(uid);
      } else {
        final recheckEntry =
            (cached ??
                    _ScanManifestEntry(uid: uid, length: 0, modifiedMs: null))
                .copyWith(
                  uid: uid,
                  length: entry.length,
                  modifiedMs: _entryModifiedMs(entry),
                  needsRecheck: true,
                );
        nextManifestByPath[path] = recheckEntry;
        final cachedUid = recheckEntry.uid.trim();
        if (cachedUid.isNotEmpty) currentUids.add(cachedUid);
      }
    }

    for (final previous in previousManifest.entriesByPath.entries) {
      final path = previous.key;
      final previousEntry = previous.value;
      if (currentPaths.contains(path)) continue;
      final uid = previousEntry.uid.trim();
      if (uid.isEmpty) continue;

      if (currentUids.contains(uid)) {
        movedPathDropCount++;
        continue;
      }

      if (hasPendingOutbox) {
        pendingOutboxDeleteGuardSkipCount++;
        nextManifestByPath[path] = previousEntry;
        continue;
      }

      final row = await db.getMemoByUid(uid);
      if (row == null) {
        staleManifestPrunedCount++;
        continue;
      }
      final localMemo = LocalMemo.fromDb(row);
      final hasConflict =
          localMemo.syncState != SyncState.synced || pendingUids.contains(uid);
      if (effectiveForceDisk && hasConflict) {
        skippedForceDiskConflictCount++;
        nextManifestByPath[path] = previousEntry;
        if (conflictSkippedSampleUids.length < 8) {
          conflictSkippedSampleUids.add(uid);
        }
        continue;
      }
      if (hasConflict) {
        skippedConflictKeepLocalCount++;
        nextManifestByPath[path] = previousEntry;
        if (conflictSkippedSampleUids.length < 8) {
          conflictSkippedSampleUids.add(uid);
        }
        continue;
      }

      await db.deleteOutboxForMemo(uid);
      outboxClearedCount++;
      await db.deleteMemoByUid(uid);
      deletedCount++;
      if (deletedSampleUids.length < 8) {
        deletedSampleUids.add(uid);
      }
    }

    await _writeScanManifestSafe(
      _ScanManifest(entriesByPath: nextManifestByPath),
    );
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    LogManager.instance.info(
      'LocalLibrary scan: incremental_completed',
      context: <String, Object?>{
        'forceDisk': forceDisk,
        'effectiveForceDisk': effectiveForceDisk,
        'elapsedMs': elapsedMs,
        'diskFiles': memoEntries.length,
        'manifestPrevious': previousManifest.entriesByPath.length,
        'manifestNext': nextManifestByPath.length,
        'parsedAttempted': parsedAttemptedCount,
        'reusedByManifest': reusedByManifestCount,
        'skippedEmptyFile': skippedEmptyFileCount,
        'skippedMissingUid': skippedMissingUidCount,
        'inserted': insertedCount,
        'updated': updatedCount,
        'unchanged': unchangedCount,
        'deleted': deletedCount,
        'movedPathDropped': movedPathDropCount,
        'staleManifestPruned': staleManifestPrunedCount,
        'pendingOutboxMemoCount': pendingUids.length,
        'pendingOutboxDeleteGuardSkipped': pendingOutboxDeleteGuardSkipCount,
        'skippedConflictKeepLocal': skippedConflictKeepLocalCount,
        'skippedForceDiskConflict': skippedForceDiskConflictCount,
        'outboxCleared': outboxClearedCount,
        if (insertedSampleUids.isNotEmpty) 'insertedSample': insertedSampleUids,
        if (updatedSampleUids.isNotEmpty) 'updatedSample': updatedSampleUids,
        if (deletedSampleUids.isNotEmpty) 'deletedSample': deletedSampleUids,
        if (conflictSkippedSampleUids.isNotEmpty)
          'conflictSkippedSample': conflictSkippedSampleUids,
      },
    );
    db.notifyDataChanged();
  }

  Future<_ScanManifest> _readScanManifestSafe() async {
    try {
      final raw = await fileSystem.readScanManifest();
      if (raw == null || raw.trim().isEmpty) return _ScanManifest.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _ScanManifest.empty();
      return _ScanManifest.fromJson(decoded.cast<String, dynamic>());
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'LocalLibrary scan: manifest_read_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return _ScanManifest.empty();
    }
  }

  Future<void> _writeScanManifestSafe(_ScanManifest manifest) async {
    try {
      await fileSystem.writeScanManifest(jsonEncode(manifest.toJson()));
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'LocalLibrary scan: manifest_write_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'entryCount': manifest.entriesByPath.length},
      );
    }
  }

  bool _manifestEntryMatchesFile(
    _ScanManifestEntry manifestEntry,
    LocalLibraryFileEntry fileEntry,
  ) {
    return manifestEntry.length == fileEntry.length &&
        manifestEntry.modifiedMs == _entryModifiedMs(fileEntry);
  }

  int? _entryModifiedMs(LocalLibraryFileEntry entry) {
    return entry.lastModified?.toUtc().millisecondsSinceEpoch;
  }

  String _resolveMemoUid({
    required LocalLibraryParsedMemo parsed,
    required String entryName,
  }) {
    var uid = parsed.uid.trim();
    if (uid.isNotEmpty) return uid;
    final lower = entryName.toLowerCase();
    if (lower.endsWith('.md.txt')) {
      uid = entryName.substring(0, entryName.length - 7);
    } else if (lower.endsWith('.md')) {
      uid = entryName.substring(0, entryName.length - 3);
    } else {
      uid = entryName;
    }
    return uid.trim();
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
    if (localMemo.content.trimRight() != parsed.content.trimRight()) {
      return true;
    }
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

class _ScanManifestEntry {
  const _ScanManifestEntry({
    required this.uid,
    required this.length,
    required this.modifiedMs,
    this.needsRecheck = false,
  });

  final String uid;
  final int length;
  final int? modifiedMs;
  final bool needsRecheck;

  _ScanManifestEntry copyWith({
    String? uid,
    int? length,
    int? modifiedMs,
    bool? needsRecheck,
  }) {
    return _ScanManifestEntry(
      uid: uid ?? this.uid,
      length: length ?? this.length,
      modifiedMs: modifiedMs ?? this.modifiedMs,
      needsRecheck: needsRecheck ?? this.needsRecheck,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'length': length,
    'modifiedMs': modifiedMs,
    'needsRecheck': needsRecheck,
  };

  factory _ScanManifestEntry.fromJson(Map<String, dynamic> json) {
    int readLength() {
      final raw = json['length'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    }

    int? readModifiedMs() {
      final raw = json['modifiedMs'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
    }

    bool readNeedsRecheck() {
      final raw = json['needsRecheck'];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return false;
    }

    final rawUid = json['uid'];
    final uid = rawUid is String ? rawUid.trim() : '';
    return _ScanManifestEntry(
      uid: uid,
      length: readLength(),
      modifiedMs: readModifiedMs(),
      needsRecheck: readNeedsRecheck(),
    );
  }
}

class _ScanManifest {
  const _ScanManifest({required this.entriesByPath});

  final Map<String, _ScanManifestEntry> entriesByPath;

  factory _ScanManifest.empty() => const _ScanManifest(entriesByPath: {});

  Map<String, dynamic> toJson() => {
    'version': 1,
    'entries': entriesByPath.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory _ScanManifest.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    if (rawEntries is! Map) return _ScanManifest.empty();
    final entries = <String, _ScanManifestEntry>{};
    rawEntries.forEach((key, value) {
      if (key is! String || value is! Map) return;
      entries[key] = _ScanManifestEntry.fromJson(value.cast<String, dynamic>());
    });
    return _ScanManifest(entriesByPath: entries);
  }
}
