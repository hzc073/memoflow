import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:memos_flutter_app/application/attachments/queued_attachment_stager.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/models/attachment.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/state/memos/compose_draft_provider.dart';
import 'package:memos_flutter_app/state/memos/note_draft_provider.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test('saves and reads full compose draft snapshot', () async {
    final harness = await _createHarness(support);
    addTearDown(harness.dispose);

    final attachment = await harness.createManagedAttachment(
      uid: 'attachment-1',
      filename: 'hello.txt',
      content: 'hello draft',
    );

    final draftId = await harness.repository.saveSnapshot(
      snapshot: ComposeDraftSnapshot(
        content: 'draft content',
        visibility: 'PRIVATE',
        relations: const <Map<String, dynamic>>[
          <String, dynamic>{'memo': 'memo-1'},
        ],
        attachments: <ComposeDraftAttachment>[attachment],
        location: const MemoLocation(
          placeholder: 'Shanghai',
          latitude: 31.2304,
          longitude: 121.4737,
        ),
      ),
    );

    expect(draftId, isNotNull);

    final drafts = await harness.repository.listDrafts();
    expect(drafts, hasLength(1));

    final saved = drafts.single;
    expect(saved.uid, draftId);
    expect(saved.snapshot.content, 'draft content');
    expect(saved.snapshot.visibility, 'PRIVATE');
    expect(saved.snapshot.relations, hasLength(1));
    expect(saved.snapshot.attachments, hasLength(1));
    expect(saved.snapshot.attachments.single.filePath, attachment.filePath);
    expect(saved.snapshot.location?.placeholder, 'Shanghai');

    final latest = await harness.repository.latestDraft();
    expect(latest?.uid, draftId);
  });

  test('missing new draft columns decode as create drafts', () {
    final draft = ComposeDraftRecord.fromRow(<String, dynamic>{
      'uid': 'legacy-draft',
      'workspace_key': 'workspace-1',
      'content': 'legacy content',
      'visibility': 'PRIVATE',
      'relations_json': '[]',
      'attachments_json': '[]',
      'created_time': 10,
      'updated_time': 20,
    });

    expect(draft.kind, ComposeDraftKind.createMemo);
    expect(draft.isCreateMemoDraft, isTrue);
    expect(draft.isEditMemoDraft, isFalse);
    expect(draft.targetMemoUid, isNull);
    expect(draft.snapshot.existingAttachments, isEmpty);
  });

  test(
    'updating same draft keeps one record and latest draft sorts by update time',
    () async {
      final harness = await _createHarness(support);
      addTearDown(harness.dispose);

      final firstId = await harness.repository.saveSnapshot(
        snapshot: const ComposeDraftSnapshot(
          content: 'first version',
          visibility: 'PRIVATE',
        ),
      );
      expect(firstId, isNotNull);

      final updatedId = await harness.repository.saveSnapshot(
        draftUid: firstId,
        snapshot: const ComposeDraftSnapshot(
          content: 'first version updated',
          visibility: 'PRIVATE',
        ),
      );
      expect(updatedId, firstId);

      var drafts = await harness.repository.listDrafts();
      expect(drafts, hasLength(1));
      expect(drafts.single.snapshot.content, 'first version updated');

      await Future<void>.delayed(const Duration(milliseconds: 2));
      final secondId = await harness.repository.saveSnapshot(
        snapshot: const ComposeDraftSnapshot(
          content: 'second draft',
          visibility: 'PUBLIC',
        ),
      );

      drafts = await harness.repository.listDrafts();
      expect(drafts, hasLength(2));
      expect(drafts.first.uid, secondId);
      expect(drafts.last.uid, firstId);
    },
  );

  test(
    'empty snapshot does not persist and deletes managed attachments',
    () async {
      final harness = await _createHarness(support);
      addTearDown(harness.dispose);

      final attachment = await harness.createManagedAttachment(
        uid: 'attachment-2',
        filename: 'cleanup.txt',
        content: 'cleanup me',
      );
      final managedFile = File(attachment.filePath);
      expect(await managedFile.exists(), isTrue);

      final draftId = await harness.repository.saveSnapshot(
        snapshot: ComposeDraftSnapshot(
          content: '',
          visibility: 'PRIVATE',
          attachments: <ComposeDraftAttachment>[attachment],
        ),
      );
      expect(draftId, isNotNull);

      final clearedId = await harness.repository.saveSnapshot(
        draftUid: draftId,
        snapshot: const ComposeDraftSnapshot(
          content: '',
          visibility: 'PRIVATE',
        ),
      );

      expect(clearedId, isNull);
      expect(await harness.repository.listDrafts(), isEmpty);
      expect(await managedFile.exists(), isFalse);
    },
  );

  test('imports legacy note draft only when draft box is empty', () async {
    final legacyRepository = _FakeNoteDraftRepository('legacy note draft');
    final harness = await _createHarness(
      support,
      legacyNoteDraftRepository: legacyRepository,
    );
    addTearDown(harness.dispose);

    final imported = await harness.repository.latestDraft();
    expect(imported, isNotNull);
    expect(imported?.snapshot.content, 'legacy note draft');

    await harness.repository.saveSnapshot(
      snapshot: const ComposeDraftSnapshot(
        content: 'current draft',
        visibility: 'PRIVATE',
      ),
    );

    final drafts = await harness.repository.listDrafts();
    expect(
      drafts.where((draft) => draft.snapshot.content == 'legacy note draft'),
      hasLength(1),
    );
  });

  test('deleting last draft clears legacy note draft mirror', () async {
    final legacyRepository = _FakeNoteDraftRepository('');
    final harness = await _createHarness(
      support,
      legacyNoteDraftRepository: legacyRepository,
    );
    addTearDown(harness.dispose);

    final draftId = await harness.repository.saveSnapshot(
      snapshot: const ComposeDraftSnapshot(
        content: 'draft to delete',
        visibility: 'PRIVATE',
      ),
    );
    expect(draftId, isNotNull);
    expect(await legacyRepository.read(), 'draft to delete');

    await harness.repository.deleteDraft(draftId!);
    expect(await legacyRepository.read(), isEmpty);

    final reopenedRepository = ComposeDraftRepository(
      database: harness.database,
      workspaceKey: 'workspace-1',
      attachmentStager: harness.attachmentStager,
      legacyNoteDraftRepository: legacyRepository,
    );
    expect(await reopenedRepository.latestDraft(), isNull);
  });

  test(
    'edit draft upserts by target memo without touching create mirror',
    () async {
      final legacyRepository = _FakeNoteDraftRepository('');
      final harness = await _createHarness(
        support,
        legacyNoteDraftRepository: legacyRepository,
      );
      addTearDown(harness.dispose);

      final createId = await harness.repository.saveSnapshot(
        snapshot: const ComposeDraftSnapshot(
          content: 'create draft',
          visibility: 'PRIVATE',
        ),
      );
      expect(createId, isNotNull);
      expect(await legacyRepository.read(), 'create draft');

      final targetUpdate = DateTime.utc(2025, 1, 2, 3, 4, 5);
      final firstEditId = await harness.repository.saveEditDraft(
        targetMemoUid: 'memo-1',
        targetMemoContentFingerprint: 'fingerprint-1',
        targetMemoUpdateTime: targetUpdate,
        snapshot: const ComposeDraftSnapshot(
          content: 'first edit',
          visibility: 'PUBLIC',
        ),
      );
      final secondEditId = await harness.repository.saveEditDraft(
        targetMemoUid: 'memo-1',
        targetMemoContentFingerprint: 'fingerprint-2',
        targetMemoUpdateTime: targetUpdate.add(const Duration(minutes: 1)),
        snapshot: const ComposeDraftSnapshot(
          content: 'second edit',
          visibility: 'PROTECTED',
        ),
      );

      expect(secondEditId, firstEditId);
      expect(await legacyRepository.read(), 'create draft');

      final drafts = await harness.repository.listDrafts();
      expect(drafts.where((draft) => draft.isEditMemoDraft), hasLength(1));
      final editDraft = await harness.repository.getEditDraftForMemo('memo-1');
      expect(editDraft, isNotNull);
      expect(editDraft!.uid, firstEditId);
      expect(editDraft.snapshot.content, 'second edit');
      expect(editDraft.snapshot.visibility, 'PROTECTED');
      expect(editDraft.targetMemoUid, 'memo-1');
      expect(editDraft.targetMemoContentFingerprint, 'fingerprint-2');
      expect(
        editDraft.targetMemoUpdateTime,
        targetUpdate.add(const Duration(minutes: 1)),
      );
      expect((await harness.repository.latestCreateDraft())?.uid, createId);
    },
  );

  test('deleteEditDraftForMemo removes only the visible edit draft', () async {
    final legacyRepository = _FakeNoteDraftRepository('');
    final harness = await _createHarness(
      support,
      legacyNoteDraftRepository: legacyRepository,
    );
    addTearDown(harness.dispose);

    final createId = await harness.repository.saveSnapshot(
      snapshot: const ComposeDraftSnapshot(
        content: 'create draft',
        visibility: 'PRIVATE',
      ),
    );
    final editId = await harness.repository.saveEditDraft(
      targetMemoUid: 'memo-1',
      snapshot: const ComposeDraftSnapshot(
        content: 'edit draft',
        visibility: 'PRIVATE',
      ),
    );
    expect(createId, isNotNull);
    expect(editId, isNotNull);

    await harness.repository.deleteEditDraftForMemo('memo-1');

    expect(await harness.repository.getEditDraftForMemo('memo-1'), isNull);
    expect(
      (await harness.repository.getByUid(createId!))?.snapshot.content,
      'create draft',
    );
    expect(await legacyRepository.read(), 'create draft');
  });

  test('edit drafts serialize existing memo attachments', () async {
    final harness = await _createHarness(support);
    addTearDown(harness.dispose);
    const existingAttachment = Attachment(
      name: 'attachments/existing-1',
      filename: 'existing.png',
      type: 'image/png',
      size: 123,
      externalLink: 'https://example.com/existing.png',
      width: 640,
      height: 480,
      hash: 'hash-existing',
    );

    final draftId = await harness.repository.saveEditDraft(
      targetMemoUid: 'memo-1',
      snapshot: const ComposeDraftSnapshot(
        content: 'edit with existing attachment',
        visibility: 'PRIVATE',
        existingAttachments: <Attachment>[existingAttachment],
      ),
    );

    expect(draftId, isNotNull);
    final restored = await harness.repository.getEditDraftForMemo('memo-1');
    expect(restored?.snapshot.existingAttachments, hasLength(1));
    expect(
      restored?.snapshot.existingAttachments.single.toJson(),
      existingAttachment.toJson(),
    );
    expect(restored?.snapshot.previewText, 'edit with existing attachment');
  });

  test(
    'deleteDraft preserves managed attachments kept for pending upload',
    () async {
      final harness = await _createHarness(support);
      addTearDown(harness.dispose);

      final attachment = await harness.createManagedAttachment(
        uid: 'attachment-keep',
        filename: 'keep.txt',
        content: 'keep me for upload',
      );
      final managedFile = File(attachment.filePath);
      expect(await managedFile.exists(), isTrue);

      final draftId = await harness.repository.saveSnapshot(
        snapshot: ComposeDraftSnapshot(
          content: 'draft with upload pending',
          visibility: 'PRIVATE',
          attachments: <ComposeDraftAttachment>[attachment],
        ),
      );

      expect(draftId, isNotNull);

      await harness.repository.deleteDraft(
        draftId!,
        keepPaths: <String>{attachment.filePath},
      );

      expect(await harness.repository.listDrafts(), isEmpty);
      expect(await managedFile.exists(), isTrue);
    },
  );
}

Future<_ComposeDraftRepositoryHarness> _createHarness(
  TestSupport support, {
  NoteDraftRepository? legacyNoteDraftRepository,
}) async {
  final dbName = uniqueDbName('compose_draft_repository');
  final appDb = AppDatabase(dbName: dbName);
  final supportDir = await support.createTempDir('compose_draft_support');
  final stager = QueuedAttachmentStager(
    resolveSupportDirectory: () async => supportDir,
  );
  final repository = ComposeDraftRepository(
    database: appDb,
    workspaceKey: 'workspace-1',
    attachmentStager: stager,
    legacyNoteDraftRepository: legacyNoteDraftRepository,
  );
  return _ComposeDraftRepositoryHarness(
    dbName: dbName,
    database: appDb,
    repository: repository,
    attachmentStager: stager,
    rootDir: supportDir,
  );
}

class _ComposeDraftRepositoryHarness {
  _ComposeDraftRepositoryHarness({
    required this.dbName,
    required this.database,
    required this.repository,
    required this.attachmentStager,
    required this.rootDir,
  });

  final String dbName;
  final AppDatabase database;
  final ComposeDraftRepository repository;
  final QueuedAttachmentStager attachmentStager;
  final Directory rootDir;

  Future<ComposeDraftAttachment> createManagedAttachment({
    required String uid,
    required String filename,
    required String content,
  }) async {
    final sourceFile = File(p.join(rootDir.path, 'src_$filename'));
    await sourceFile.parent.create(recursive: true);
    await sourceFile.writeAsString(content);
    final staged = await attachmentStager.stageDraftAttachment(
      uid: uid,
      filePath: sourceFile.path,
      filename: filename,
      mimeType: 'text/plain',
      size: content.length,
      scopeKey: 'workspace-1',
    );
    return ComposeDraftAttachment(
      uid: staged.uid,
      filePath: staged.filePath,
      filename: staged.filename,
      mimeType: staged.mimeType,
      size: staged.size,
    );
  }

  Future<void> dispose() async {
    await database.close();
    await deleteTestDatabase(dbName);
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
  }
}

class _FakeNoteDraftRepository extends NoteDraftRepository {
  _FakeNoteDraftRepository(String initialValue)
    : _value = initialValue,
      super(const FlutterSecureStorage(), accountKey: 'test-account');

  String _value;

  @override
  Future<String> read() async => _value;

  @override
  Future<void> write(String text) async {
    _value = text;
  }

  @override
  Future<void> clear() async {
    _value = '';
  }
}
