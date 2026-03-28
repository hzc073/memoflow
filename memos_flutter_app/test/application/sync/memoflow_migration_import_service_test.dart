import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_apply_service.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_bundle.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_codec.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_import_service.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_models.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_preferences_filter.dart';
import 'package:memos_flutter_app/core/debug_ephemeral_storage.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/data/local_library/local_attachment_store.dart';
import 'package:memos_flutter_app/data/local_library/local_library_fs.dart';
import 'package:memos_flutter_app/data/local_library/local_library_markdown.dart';
import 'package:memos_flutter_app/data/models/content_fingerprint.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/models/local_memo.dart';
import 'package:memos_flutter_app/state/system/database_provider.dart';

import '../../test_support.dart';

class _RecordingConfigApplyService extends ConfigTransferApplyService {
  _RecordingConfigApplyService(this.events)
    : super(
        localAdapter: _UnusedConfigTransferLocalAdapter(),
        preferencesFilter: const MigrationPreferencesFilter(),
      );

  final List<String> events;

  @override
  Future<Set<MemoFlowMigrationConfigType>> applyBundle(
    ConfigTransferBundle bundle, {
    required Set<MemoFlowMigrationConfigType> allowedTypes,
  }) async {
    events.add('apply');
    return <MemoFlowMigrationConfigType>{};
  }
}

class _UnusedConfigTransferLocalAdapter extends Fake
    implements ConfigTransferLocalAdapter {
  @override
  Future<AppPreferences> readPreferences() async => AppPreferences.defaults;
}

class _ThrowingConfigApplyService extends ConfigTransferApplyService {
  _ThrowingConfigApplyService()
    : super(
        localAdapter: _UnusedConfigTransferLocalAdapter(),
        preferencesFilter: const MigrationPreferencesFilter(),
      );

  @override
  Future<Set<MemoFlowMigrationConfigType>> applyBundle(
    ConfigTransferBundle bundle, {
    required Set<MemoFlowMigrationConfigType> allowedTypes,
  }) async {
    throw StateError('config apply failed');
  }
}

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test(
    'imports a new workspace into its own database before switching',
    () async {
      final currentDbName = uniqueDbName('memoflow_current');
      final currentDb = AppDatabase(dbName: currentDbName);
      final events = <String>[];
      final fixture = await _createPackageFixture(support);

      LocalLibrary? registeredLibrary;
      String? switchedWorkspaceKey;

      final service = MemoFlowMigrationImportService(
        db: currentDb,
        attachmentStore: LocalAttachmentStore(),
        configApplyService: _RecordingConfigApplyService(events),
        codec: const ConfigTransferCodec(),
        createWorkspaceDatabase: (workspaceKey) {
          return AppDatabase(dbName: databaseNameForAccountKey(workspaceKey));
        },
        deleteWorkspaceDatabase: (workspaceKey) {
          return AppDatabase.deleteDatabaseFile(
            dbName: databaseNameForAccountKey(workspaceKey),
          );
        },
        registerLibrary: (library) async {
          registeredLibrary = library;
          events.add('register');
        },
        switchWorkspace: (workspaceKey) async {
          switchedWorkspaceKey = workspaceKey;
          events.add('switch');
        },
        currentLibrary: () => null,
      );

      try {
        final result = await service.importPackage(
          packageFile: fixture.packageFile,
          proposal: fixture.proposal,
          receiveMode: MemoFlowMigrationReceiveMode.newWorkspace,
          allowedConfigTypes: const <MemoFlowMigrationConfigType>{},
        );

        expect(events, <String>['apply', 'register', 'switch']);
        expect(registeredLibrary, isNotNull);
        expect(switchedWorkspaceKey, registeredLibrary!.key);
        expect(result.workspaceName, registeredLibrary!.name);

        expect(await currentDb.getMemoByUid(fixture.memoUid), isNull);

        final importedDb = AppDatabase(
          dbName: databaseNameForAccountKey(registeredLibrary!.key),
        );
        try {
          final importedRow = await importedDb.getMemoByUid(fixture.memoUid);
          expect(importedRow, isNotNull);
          expect(importedRow?['content'], fixture.memoContent);
        } finally {
          await importedDb.close();
        }
      } finally {
        await currentDb.close();
        await deleteTestDatabase(currentDbName);
        if (registeredLibrary != null) {
          await AppDatabase.deleteDatabaseFile(
            dbName: databaseNameForAccountKey(registeredLibrary!.key),
          );
        }
        if (await fixture.packageDir.exists()) {
          await fixture.packageDir.delete(recursive: true);
        }
      }
    },
  );

  test(
    'imports overwrite package when archive has a payload root folder',
    () async {
      final dbName = uniqueDbName('memoflow_overwrite_nested_payload');
      final currentDb = AppDatabase(dbName: dbName);
      final libraryDir = await support.createTempDir(
        'memoflow_overwrite_library',
      );
      final library = LocalLibrary(
        key: 'local_workspace',
        name: 'Local Workspace',
        rootPath: libraryDir.path,
      );
      final fixture = await _createPackageFixture(
        support,
        nestedPayloadRoot: true,
      );

      final service = MemoFlowMigrationImportService(
        db: currentDb,
        attachmentStore: LocalAttachmentStore(),
        configApplyService: _RecordingConfigApplyService(<String>[]),
        codec: const ConfigTransferCodec(),
        createWorkspaceDatabase: (workspaceKey) {
          return AppDatabase(dbName: databaseNameForAccountKey(workspaceKey));
        },
        deleteWorkspaceDatabase: (workspaceKey) {
          return AppDatabase.deleteDatabaseFile(
            dbName: databaseNameForAccountKey(workspaceKey),
          );
        },
        registerLibrary: (_) async {},
        switchWorkspace: (_) async {},
        currentLibrary: () => library,
      );

      try {
        await service.importPackage(
          packageFile: fixture.packageFile,
          proposal: fixture.proposal,
          receiveMode: MemoFlowMigrationReceiveMode.overwriteCurrent,
          allowedConfigTypes: const <MemoFlowMigrationConfigType>{},
        );

        final row = await currentDb.getMemoByUid(fixture.memoUid);
        expect(row, isNotNull);
        expect(row?['content'], fixture.memoContent);

        final fileSystem = LocalLibraryFileSystem(library);
        expect(
          await fileSystem.fileExists('memos/${fixture.memoUid}.md'),
          isTrue,
        );
      } finally {
        await currentDb.close();
        await deleteTestDatabase(dbName);
        if (await fixture.packageDir.exists()) {
          await fixture.packageDir.delete(recursive: true);
        }
        if (await libraryDir.exists()) {
          await libraryDir.delete(recursive: true);
        }
      }
    },
  );

  test(
    'can defer switching imported workspace until after upload response',
    () async {
      final currentDbName = uniqueDbName('memoflow_current_deferred');
      final currentDb = AppDatabase(dbName: currentDbName);
      final events = <String>[];
      final fixture = await _createPackageFixture(support);

      LocalLibrary? registeredLibrary;
      String? switchedWorkspaceKey;

      final service = MemoFlowMigrationImportService(
        db: currentDb,
        attachmentStore: LocalAttachmentStore(),
        configApplyService: _RecordingConfigApplyService(events),
        codec: const ConfigTransferCodec(),
        createWorkspaceDatabase: (workspaceKey) {
          return AppDatabase(dbName: databaseNameForAccountKey(workspaceKey));
        },
        deleteWorkspaceDatabase: (workspaceKey) {
          return AppDatabase.deleteDatabaseFile(
            dbName: databaseNameForAccountKey(workspaceKey),
          );
        },
        registerLibrary: (library) async {
          registeredLibrary = library;
          events.add('register');
        },
        switchWorkspace: (workspaceKey) async {
          switchedWorkspaceKey = workspaceKey;
          events.add('switch');
        },
        currentLibrary: () => null,
      );

      try {
        final result = await service.importPackage(
          packageFile: fixture.packageFile,
          proposal: fixture.proposal,
          receiveMode: MemoFlowMigrationReceiveMode.newWorkspace,
          allowedConfigTypes: const <MemoFlowMigrationConfigType>{},
          activateImportedWorkspace: false,
        );

        expect(events, <String>['apply', 'register']);
        expect(registeredLibrary, isNotNull);
        expect(switchedWorkspaceKey, isNull);
        expect(result.workspaceKey, registeredLibrary!.key);

        await service.activateImportedWorkspace(result.workspaceKey!);

        expect(events, <String>['apply', 'register', 'switch']);
        expect(switchedWorkspaceKey, registeredLibrary!.key);
      } finally {
        await currentDb.close();
        await deleteTestDatabase(currentDbName);
        if (registeredLibrary != null) {
          await AppDatabase.deleteDatabaseFile(
            dbName: databaseNameForAccountKey(registeredLibrary!.key),
          );
        }
        if (await fixture.packageDir.exists()) {
          await fixture.packageDir.delete(recursive: true);
        }
      }
    },
  );

  test(
    'rolls back imported workspace files when post-import apply fails',
    () async {
      final currentDbName = uniqueDbName('memoflow_current_apply_failure');
      final currentDb = AppDatabase(dbName: currentDbName);
      final fixture = await _createPackageFixture(support);
      final workspacesRoot = Directory(
        p.join((await resolveAppSupportDirectory()).path, 'workspaces'),
      );
      final baselineWorkspaceNames = await workspacesRoot.exists()
          ? await workspacesRoot
                .list()
                .map((entry) => p.basename(entry.path))
                .toSet()
          : <String>{};

      try {
        final service = MemoFlowMigrationImportService(
          db: currentDb,
          attachmentStore: LocalAttachmentStore(),
          configApplyService: _ThrowingConfigApplyService(),
          codec: const ConfigTransferCodec(),
          createWorkspaceDatabase: (workspaceKey) {
            return AppDatabase(dbName: databaseNameForAccountKey(workspaceKey));
          },
          deleteWorkspaceDatabase: (workspaceKey) {
            return AppDatabase.deleteDatabaseFile(
              dbName: databaseNameForAccountKey(workspaceKey),
            );
          },
          registerLibrary: (_) async {},
          switchWorkspace: (_) async {},
          currentLibrary: () => null,
        );

        await expectLater(
          () => service.importPackage(
            packageFile: fixture.packageFile,
            proposal: fixture.proposal,
            receiveMode: MemoFlowMigrationReceiveMode.newWorkspace,
            allowedConfigTypes: const <MemoFlowMigrationConfigType>{},
          ),
          throwsA(isA<StateError>()),
        );

        if (await workspacesRoot.exists()) {
          final nextWorkspaceNames = await workspacesRoot
              .list()
              .map((entry) => p.basename(entry.path))
              .toSet();
          expect(nextWorkspaceNames, baselineWorkspaceNames);
        }
      } finally {
        await currentDb.close();
        await deleteTestDatabase(currentDbName);
        if (await fixture.packageDir.exists()) {
          await fixture.packageDir.delete(recursive: true);
        }
      }
    },
  );

  test(
    'unregisters and deletes imported workspace when switch fails',
    () async {
      final currentDbName = uniqueDbName('memoflow_current_switch_failure');
      final currentDb = AppDatabase(dbName: currentDbName);
      final fixture = await _createPackageFixture(support);

      LocalLibrary? registeredLibrary;
      String? unregisteredWorkspaceKey;

      try {
        final service = MemoFlowMigrationImportService(
          db: currentDb,
          attachmentStore: LocalAttachmentStore(),
          configApplyService: _RecordingConfigApplyService(<String>[]),
          codec: const ConfigTransferCodec(),
          createWorkspaceDatabase: (workspaceKey) {
            return AppDatabase(dbName: databaseNameForAccountKey(workspaceKey));
          },
          deleteWorkspaceDatabase: (workspaceKey) {
            return AppDatabase.deleteDatabaseFile(
              dbName: databaseNameForAccountKey(workspaceKey),
            );
          },
          registerLibrary: (library) async {
            registeredLibrary = library;
          },
          unregisterLibrary: (workspaceKey) async {
            unregisteredWorkspaceKey = workspaceKey;
          },
          switchWorkspace: (_) async {
            throw StateError('switch failed');
          },
          currentLibrary: () => null,
        );

        await expectLater(
          () => service.importPackage(
            packageFile: fixture.packageFile,
            proposal: fixture.proposal,
            receiveMode: MemoFlowMigrationReceiveMode.newWorkspace,
            allowedConfigTypes: const <MemoFlowMigrationConfigType>{},
          ),
          throwsA(isA<StateError>()),
        );

        expect(registeredLibrary, isNotNull);
        expect(unregisteredWorkspaceKey, registeredLibrary!.key);

        final dbPath = p.join(
          await resolveDatabasesDirectoryPath(),
          databaseNameForAccountKey(registeredLibrary!.key),
        );
        expect(await File(dbPath).exists(), isFalse);

        final workspaceDir = Directory(p.dirname(registeredLibrary!.rootPath!));
        expect(await workspaceDir.exists(), isFalse);
      } finally {
        await currentDb.close();
        await deleteTestDatabase(currentDbName);
        if (await fixture.packageDir.exists()) {
          await fixture.packageDir.delete(recursive: true);
        }
      }
    },
  );
}

Future<
  ({
    String memoContent,
    String memoUid,
    File packageFile,
    Directory packageDir,
    MemoFlowMigrationProposal proposal,
  })
>
_createPackageFixture(
  TestSupport support, {
  bool nestedPayloadRoot = false,
}) async {
  final memoUid = 'memo-migration-import';
  final memoContent = 'imported memo content';
  final createdAt = DateTime.utc(2025, 1, 1, 12);
  final memo = LocalMemo(
    uid: memoUid,
    content: memoContent,
    contentFingerprint: computeContentFingerprint(memoContent),
    visibility: 'PRIVATE',
    pinned: false,
    state: 'NORMAL',
    createTime: createdAt,
    updateTime: createdAt,
    tags: const <String>[],
    attachments: const [],
    relationCount: 0,
    location: null,
    syncState: SyncState.synced,
    lastError: null,
  );

  final archive = Archive();
  final markdownBytes = utf8.encode(buildLocalLibraryMarkdown(memo));
  final memoPath = nestedPayloadRoot
      ? 'payload/memos/$memoUid.md'
      : 'memos/$memoUid.md';
  archive.addFile(ArchiveFile(memoPath, markdownBytes.length, markdownBytes));
  final zipBytes = ZipEncoder().encode(archive);

  final packageDir = await support.createTempDir('memoflow_import_package');
  final packageFile = File(p.join(packageDir.path, 'package.zip'));
  await packageFile.writeAsBytes(zipBytes, flush: true);

  return (
    memoContent: memoContent,
    memoUid: memoUid,
    packageFile: packageFile,
    packageDir: packageDir,
    proposal: MemoFlowMigrationProposal(
      proposalId: 'proposal-1',
      sessionId: 'session-1',
      pairingCode: '123456',
      senderDeviceName: 'Sender',
      senderPlatform: 'windows',
      manifest: MemoFlowMigrationPackageManifest(
        schemaVersion: 1,
        protocolVersion: 'migration-v1',
        exportedAt: createdAt,
        senderDeviceName: 'Sender',
        senderPlatform: 'windows',
        sourceWorkspaceName: 'Source Workspace',
        includeMemos: true,
        includeSettings: false,
        memoCount: 1,
        attachmentCount: 0,
        totalBytes: zipBytes.length,
        sha256: crypto.sha256.convert(zipBytes).toString(),
        configTypes: const <MemoFlowMigrationConfigType>{},
      ),
    ),
  );
}
