import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/attachments/queued_attachment_stager.dart';
import '../../core/uid.dart';
import '../../data/db/app_database.dart';
import '../../data/models/compose_draft.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import '../system/database_provider.dart';
import '../system/session_provider.dart';
import 'note_draft_provider.dart';

final composeDraftRepositoryProvider = Provider<ComposeDraftRepository>((ref) {
  final workspaceKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  if (workspaceKey == null || workspaceKey.trim().isEmpty) {
    throw StateError('Not authenticated');
  }
  return ComposeDraftRepository(
    database: ref.watch(databaseProvider),
    workspaceKey: workspaceKey,
    attachmentStager: ref.watch(queuedAttachmentStagerProvider),
    legacyNoteDraftRepository: ref.watch(noteDraftRepositoryProvider),
  );
});

final composeDraftsProvider = StreamProvider<List<ComposeDraftRecord>>((
  ref,
) async* {
  final repository = ref.watch(composeDraftRepositoryProvider);
  yield await repository.listDrafts();
  await for (final _ in repository.changes) {
    yield await repository.listDrafts();
  }
});

final composeDraftCountProvider = Provider<int>((ref) {
  return ref.watch(composeDraftsProvider).valueOrNull?.length ?? 0;
});

final latestComposeDraftProvider = FutureProvider<ComposeDraftRecord?>((
  ref,
) async {
  return ref.watch(composeDraftRepositoryProvider).latestDraft();
});

class ComposeDraftRepository {
  ComposeDraftRepository({
    required AppDatabase database,
    required String workspaceKey,
    required QueuedAttachmentStager attachmentStager,
    NoteDraftRepository? legacyNoteDraftRepository,
  }) : _database = database,
       _workspaceKey = workspaceKey.trim(),
       _attachmentStager = attachmentStager,
       _legacyNoteDraftRepository = legacyNoteDraftRepository;

  final AppDatabase _database;
  final String _workspaceKey;
  final QueuedAttachmentStager _attachmentStager;
  final NoteDraftRepository? _legacyNoteDraftRepository;

  bool _legacyImportAttempted = false;

  Stream<void> get changes => _database.changes;
  String get workspaceKey => _workspaceKey;

  Future<List<ComposeDraftRecord>> listDrafts({int? limit}) async {
    await _maybeImportLegacyDraft();
    return _listDraftsFromDb(limit: limit);
  }

  Future<ComposeDraftRecord?> latestDraft() async {
    await _maybeImportLegacyDraft();
    final row = await _database.getLatestComposeDraftRow(
      workspaceKey: _workspaceKey,
    );
    if (row == null) return null;
    return ComposeDraftRecord.fromRow(row);
  }

  Future<ComposeDraftRecord?> getByUid(String uid) async {
    await _maybeImportLegacyDraft();
    return getByUidWithoutLegacyImport(uid);
  }

  Future<ComposeDraftRecord?> getByUidWithoutLegacyImport(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return null;
    final row = await _database.getComposeDraftRow(
      uid: normalizedUid,
      workspaceKey: _workspaceKey,
    );
    if (row == null) return null;
    return ComposeDraftRecord.fromRow(row);
  }

  Future<String?> saveSnapshot({
    String? draftUid,
    required ComposeDraftSnapshot snapshot,
  }) async {
    final normalizedUid = draftUid?.trim();
    if (!snapshot.hasSavableContent) {
      if (normalizedUid != null && normalizedUid.isNotEmpty) {
        await deleteDraft(normalizedUid);
      }
      return null;
    }

    final existing = normalizedUid == null || normalizedUid.isEmpty
        ? null
        : await getByUidWithoutLegacyImport(normalizedUid);
    final now = DateTime.now().toUtc();
    final uid =
        existing?.uid ??
        (normalizedUid?.isNotEmpty == true ? normalizedUid! : generateUid());
    final record = ComposeDraftRecord(
      uid: uid,
      workspaceKey: _workspaceKey,
      snapshot: snapshot,
      createdTime: existing?.createdTime ?? now,
      updatedTime: now,
    );
    await _database.upsertComposeDraftRow(record.toRow());
    await _syncLegacyDraftMirror(snapshot.content);
    return uid;
  }

  Future<void> deleteDraft(String uid) async {
    final existing = await getByUidWithoutLegacyImport(uid);
    if (existing == null) return;
    await _database.deleteComposeDraft(existing.uid);
    await _deleteAttachmentFiles(existing.snapshot.attachments);
    await _syncLegacyDraftMirrorFromLatest();
  }

  Future<void> clearDrafts() async {
    final existing = await _listDraftsFromDb();
    await _database.deleteComposeDraftsByWorkspace(_workspaceKey);
    await _deleteDraftAttachmentFiles(existing);
    await _syncLegacyDraftMirror(null);
  }

  Future<void> replaceAllDrafts(Iterable<ComposeDraftRecord> drafts) async {
    final existing = await _listDraftsFromDb();
    final nextDrafts = drafts
        .map((draft) => draft.copyWith(workspaceKey: _workspaceKey))
        .toList(growable: false);
    await _database.replaceComposeDraftRows(
      workspaceKey: _workspaceKey,
      rows: nextDrafts.map((draft) => draft.toRow()).toList(growable: false),
    );
    final keepPaths = nextDrafts
        .expand((draft) => draft.snapshot.attachments)
        .map((attachment) => attachment.filePath.trim())
        .where((path) => path.isNotEmpty)
        .toSet();
    await _deleteDraftAttachmentFiles(existing, keepPaths: keepPaths);
    await _syncLegacyDraftMirrorFromLatest();
  }

  Future<void> _maybeImportLegacyDraft() async {
    if (_legacyImportAttempted) return;
    _legacyImportAttempted = true;
    final legacyRepository = _legacyNoteDraftRepository;
    if (legacyRepository == null) return;

    final existing = await _database.getLatestComposeDraftRow(
      workspaceKey: _workspaceKey,
    );
    if (existing != null) return;

    final legacyText = await legacyRepository.read();
    if (legacyText.trim().isEmpty) return;

    final now = DateTime.now().toUtc();
    await _database.upsertComposeDraftRow(
      ComposeDraftRecord(
        uid: generateUid(),
        workspaceKey: _workspaceKey,
        snapshot: ComposeDraftSnapshot(
          content: legacyText,
          visibility: 'PRIVATE',
        ),
        createdTime: now,
        updatedTime: now,
      ).toRow(),
    );
  }

  Future<List<ComposeDraftRecord>> _listDraftsFromDb({int? limit}) async {
    final rows = await _database.listComposeDraftRows(
      workspaceKey: _workspaceKey,
      limit: limit,
    );
    return rows.map(ComposeDraftRecord.fromRow).toList(growable: false);
  }

  Future<void> _deleteDraftAttachmentFiles(
    List<ComposeDraftRecord> drafts, {
    Set<String> keepPaths = const <String>{},
  }) async {
    for (final draft in drafts) {
      await _deleteAttachmentFiles(
        draft.snapshot.attachments,
        keepPaths: keepPaths,
      );
    }
  }

  Future<void> _deleteAttachmentFiles(
    List<ComposeDraftAttachment> attachments, {
    Set<String> keepPaths = const <String>{},
  }) async {
    for (final attachment in attachments) {
      final path = attachment.filePath.trim();
      if (path.isNotEmpty && keepPaths.contains(path)) {
        continue;
      }
      await _attachmentStager.deleteManagedFile(attachment.filePath);
    }
  }

  Future<void> _syncLegacyDraftMirrorFromLatest() async {
    final row = await _database.getLatestComposeDraftRow(
      workspaceKey: _workspaceKey,
    );
    await _syncLegacyDraftMirror((row?['content'] as String?) ?? '');
  }

  Future<void> _syncLegacyDraftMirror(String? text) async {
    final legacyRepository = _legacyNoteDraftRepository;
    if (legacyRepository == null) return;
    final normalizedText = text ?? '';
    if (normalizedText.trim().isEmpty) {
      await legacyRepository.clear();
      return;
    }
    await legacyRepository.write(normalizedText);
  }
}
