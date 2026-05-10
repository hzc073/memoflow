import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/attachments/queued_attachment_stager.dart';
import '../../core/uid.dart';
import '../../data/db/app_database.dart';
import '../../data/models/compose_draft.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import '../system/database_provider.dart';
import 'compose_draft_mutation_service.dart';
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
    mutations: ref.watch(composeDraftMutationServiceProvider),
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
    ComposeDraftMutationService? mutations,
    NoteDraftRepository? legacyNoteDraftRepository,
  }) : _database = database,
       _workspaceKey = workspaceKey.trim(),
       _attachmentStager = attachmentStager,
       _mutations = mutations ?? ComposeDraftMutationService(db: database),
       _legacyNoteDraftRepository = legacyNoteDraftRepository;

  final AppDatabase _database;
  final String _workspaceKey;
  final QueuedAttachmentStager _attachmentStager;
  final ComposeDraftMutationService _mutations;
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

  Future<ComposeDraftRecord?> latestCreateDraft() async {
    await _maybeImportLegacyDraft();
    final row = await _latestCreateDraftRow();
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

  Future<ComposeDraftRecord?> getEditDraftForMemo(String targetMemoUid) async {
    final normalizedUid = targetMemoUid.trim();
    if (normalizedUid.isEmpty) return null;
    final row = await _database.getComposeEditDraftRowForMemo(
      workspaceKey: _workspaceKey,
      targetMemoUid: normalizedUid,
    );
    if (row == null) return null;
    return ComposeDraftRecord.fromRow(row);
  }

  Future<String?> saveSnapshot({
    String? draftUid,
    required ComposeDraftSnapshot snapshot,
  }) async {
    final uid = await _saveRecord(
      draftUid: draftUid,
      snapshot: snapshot,
      kind: ComposeDraftKind.createMemo,
      targetMemoUid: null,
      targetMemoContentFingerprint: null,
      targetMemoUpdateTime: null,
      deleteExistingWhenEmpty: true,
    );
    if (uid != null) {
      await _syncLegacyDraftMirror(snapshot.content);
    }
    return uid;
  }

  Future<String?> saveEditDraft({
    required String targetMemoUid,
    required ComposeDraftSnapshot snapshot,
    String? targetMemoContentFingerprint,
    DateTime? targetMemoUpdateTime,
  }) async {
    final normalizedTarget = targetMemoUid.trim();
    if (normalizedTarget.isEmpty) return null;
    final existing = await getEditDraftForMemo(normalizedTarget);
    return _saveRecord(
      draftUid: existing?.uid,
      snapshot: snapshot,
      kind: ComposeDraftKind.editMemo,
      targetMemoUid: normalizedTarget,
      targetMemoContentFingerprint: targetMemoContentFingerprint,
      targetMemoUpdateTime: targetMemoUpdateTime,
      deleteExistingWhenEmpty: true,
    );
  }

  Future<String?> _saveRecord({
    String? draftUid,
    required ComposeDraftSnapshot snapshot,
    required ComposeDraftKind kind,
    required String? targetMemoUid,
    required String? targetMemoContentFingerprint,
    required DateTime? targetMemoUpdateTime,
    required bool deleteExistingWhenEmpty,
  }) async {
    final normalizedUid = draftUid?.trim();
    if (!snapshot.hasSavableContent) {
      if (deleteExistingWhenEmpty &&
          normalizedUid != null &&
          normalizedUid.isNotEmpty) {
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
      kind: kind,
      targetMemoUid: targetMemoUid,
      targetMemoContentFingerprint: targetMemoContentFingerprint,
      targetMemoUpdateTime: targetMemoUpdateTime,
    );
    await _mutations.upsertDraftRow(record.toRow());
    return uid;
  }

  Future<void> deleteDraft(
    String uid, {
    Set<String> keepPaths = const <String>{},
  }) async {
    final existing = await getByUidWithoutLegacyImport(uid);
    if (existing == null) return;
    await _mutations.deleteDraft(existing.uid);
    await _deleteAttachmentFiles(
      existing.snapshot.attachments,
      keepPaths: keepPaths,
    );
    if (existing.isCreateMemoDraft) {
      await _syncLegacyDraftMirrorFromLatestCreateDraft();
    }
  }

  Future<void> deleteEditDraftForMemo(String targetMemoUid) async {
    final existing = await getEditDraftForMemo(targetMemoUid);
    if (existing == null) return;
    await deleteDraft(existing.uid);
  }

  Future<void> clearDrafts() async {
    final existing = await _listDraftsFromDb();
    await _mutations.deleteDraftsByWorkspace(_workspaceKey);
    await _deleteDraftAttachmentFiles(existing);
    await _syncLegacyDraftMirror(null);
  }

  Future<void> replaceAllDrafts(Iterable<ComposeDraftRecord> drafts) async {
    final existing = await _listDraftsFromDb();
    final nextDrafts = drafts
        .map((draft) => draft.copyWith(workspaceKey: _workspaceKey))
        .toList(growable: false);
    await _mutations.replaceDraftRows(
      workspaceKey: _workspaceKey,
      rows: nextDrafts.map((draft) => draft.toRow()).toList(growable: false),
    );
    final keepPaths = nextDrafts
        .expand((draft) => draft.snapshot.attachments)
        .map((attachment) => attachment.filePath.trim())
        .where((path) => path.isNotEmpty)
        .toSet();
    await _deleteDraftAttachmentFiles(existing, keepPaths: keepPaths);
    await _syncLegacyDraftMirrorFromLatestCreateDraft();
  }

  Future<void> _maybeImportLegacyDraft() async {
    if (_legacyImportAttempted) return;
    _legacyImportAttempted = true;
    final legacyRepository = _legacyNoteDraftRepository;
    if (legacyRepository == null) return;

    final existing = await _latestCreateDraftRow();
    if (existing != null) return;

    final legacyText = await legacyRepository.read();
    if (legacyText.trim().isEmpty) return;

    final now = DateTime.now().toUtc();
    await _mutations.upsertDraftRow(
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

  Future<Map<String, dynamic>?> _latestCreateDraftRow() async {
    final rows = await _listDraftsFromDb();
    for (final draft in rows) {
      if (draft.isCreateMemoDraft) return draft.toRow();
    }
    return null;
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

  Future<void> _syncLegacyDraftMirrorFromLatestCreateDraft() async {
    final row = await _latestCreateDraftRow();
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
