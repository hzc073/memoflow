import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/db/app_database.dart';
import '../../../data/local_library/local_attachment_store.dart';
import '../../../data/local_library/local_library_fs.dart';
import '../../../data/local_library/local_library_paths.dart';
import '../../../data/models/local_library.dart';
import '../../attachments/queued_attachment_stager.dart';
import '../compose_draft_transfer.dart';
import '../config_transfer/config_transfer_apply_service.dart';
import '../config_transfer/config_transfer_codec.dart';
import '../local_library_scan_service.dart';
import '../sync_types.dart';
import 'memoflow_migration_models.dart';
import '../../../state/memos/compose_draft_provider.dart';

class MemoFlowMigrationImportService {
  MemoFlowMigrationImportService({
    required this.db,
    required this.attachmentStore,
    required this.attachmentStager,
    required this.configApplyService,
    required this.codec,
    required this.createWorkspaceDatabase,
    required this.deleteWorkspaceDatabase,
    required this.registerLibrary,
    required this.switchWorkspace,
    required this.currentLibrary,
    this.unregisterLibrary,
  });

  final AppDatabase db;
  final LocalAttachmentStore attachmentStore;
  final QueuedAttachmentStager attachmentStager;
  final ConfigTransferApplyService configApplyService;
  final ConfigTransferCodec codec;
  final AppDatabase Function(String workspaceKey) createWorkspaceDatabase;
  final Future<void> Function(String workspaceKey) deleteWorkspaceDatabase;
  final Future<void> Function(LocalLibrary library) registerLibrary;
  final Future<void> Function(String workspaceKey) switchWorkspace;
  final LocalLibrary? Function() currentLibrary;
  final Future<void> Function(String workspaceKey)? unregisterLibrary;

  Future<MemoFlowMigrationResult> importPackage({
    required File packageFile,
    required MemoFlowMigrationProposal proposal,
    required MemoFlowMigrationReceiveMode receiveMode,
    required Set<MemoFlowMigrationConfigType> allowedConfigTypes,
    bool activateImportedWorkspace = true,
    void Function(MemoFlowMigrationTransferStage stage, {String? message})?
    onProgress,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final extractDir = await Directory(
      p.join(
        tempRoot.path,
        'memoflow_migration_import_${DateTime.now().millisecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    LocalLibrary? importedLibrary;
    var registeredImportedLibrary = false;

    try {
      onProgress?.call(MemoFlowMigrationTransferStage.validating);
      await extractFileToDisk(packageFile.path, extractDir.path);
      await _normalizeExtractedPaths(extractDir);
      final payloadDir = await _resolvePayloadRoot(extractDir);

      String? workspaceName;
      String? workspaceKey;
      if (proposal.manifest.includeMemos) {
        if (receiveMode == MemoFlowMigrationReceiveMode.newWorkspace) {
          importedLibrary = await _importIntoNewWorkspace(
            payloadDir: payloadDir,
            senderDeviceName: proposal.senderDeviceName,
            expectedMemoCount: proposal.manifest.memoCount,
            expectedAttachmentCount: proposal.manifest.attachmentCount,
            onProgress: onProgress,
          );
          workspaceName = importedLibrary.name;
          workspaceKey = importedLibrary.key;
        } else {
          final active = currentLibrary();
          if (active == null) {
            throw StateError('No current local workspace to overwrite.');
          }
          await _overwriteCurrentWorkspace(
            payloadDir: payloadDir,
            library: active,
            expectedMemoCount: proposal.manifest.memoCount,
            expectedAttachmentCount: proposal.manifest.attachmentCount,
            onProgress: onProgress,
          );
          workspaceName = active.name;
          workspaceKey = active.key;
        }
      } else {
        final active = currentLibrary();
        workspaceName = active?.name;
        workspaceKey = active?.key;
      }

      final bundle = await codec.decodeFromDirectory(payloadDir);
      onProgress?.call(MemoFlowMigrationTransferStage.applyingConfig);
      final applied = <MemoFlowMigrationConfigType>{};
      final configAllowedTypes = allowedConfigTypes.difference(
        const <MemoFlowMigrationConfigType>{
          MemoFlowMigrationConfigType.draftBox,
        },
      );
      applied.addAll(
        await configApplyService.applyBundle(
          bundle,
          allowedTypes: configAllowedTypes,
        ),
      );
      final targetWorkspaceKey = workspaceKey?.trim();
      if (allowedConfigTypes.contains(MemoFlowMigrationConfigType.draftBox) &&
          bundle.draftBox != null &&
          targetWorkspaceKey != null &&
          targetWorkspaceKey.isNotEmpty) {
        final targetDb = importedLibrary != null
            ? createWorkspaceDatabase(targetWorkspaceKey)
            : db;
        try {
          final materializedDrafts =
              await materializeComposeDraftTransferBundle(
                bundle: bundle.draftBox!,
                rootDirectory: payloadDir,
                workspaceKey: targetWorkspaceKey,
                attachmentStager: attachmentStager,
              );
          final repository = ComposeDraftRepository(
            database: targetDb,
            workspaceKey: targetWorkspaceKey,
            attachmentStager: attachmentStager,
          );
          final draftsToApply = bundle.draftBox!.mergeWithExistingOnRestore
              ? mergeComposeDraftRecords(
                  existing: await repository.listDrafts(),
                  incoming: materializedDrafts,
                  workspaceKey: targetWorkspaceKey,
                )
              : materializedDrafts;
          await repository.replaceAllDrafts(draftsToApply);
          applied.add(MemoFlowMigrationConfigType.draftBox);
        } finally {
          if (importedLibrary != null) {
            await targetDb.close();
          }
        }
      }
      final skipped = proposal.manifest.configTypes.difference(applied);

      if (importedLibrary != null) {
        await registerLibrary(importedLibrary);
        registeredImportedLibrary = true;
        if (activateImportedWorkspace) {
          await switchWorkspace(importedLibrary.key);
        }
      }

      return MemoFlowMigrationResult(
        sourceDeviceName: proposal.senderDeviceName,
        receiveMode: receiveMode,
        memoCount: proposal.manifest.memoCount,
        attachmentCount: proposal.manifest.attachmentCount,
        draftCount: proposal.manifest.draftCount,
        draftAttachmentCount: proposal.manifest.draftAttachmentCount,
        appliedConfigTypes: applied,
        skippedConfigTypes: skipped,
        workspaceName: workspaceName,
        workspaceKey: workspaceKey,
      );
    } catch (error) {
      if (importedLibrary != null) {
        await _rollbackImportedWorkspace(
          importedLibrary,
          unregisterFromLibraryList: registeredImportedLibrary,
        );
      }
      rethrow;
    } finally {
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
    }
  }

  Future<void> activateImportedWorkspace(String workspaceKey) {
    return switchWorkspace(workspaceKey);
  }

  Future<LocalLibrary> _importIntoNewWorkspace({
    required Directory payloadDir,
    required String senderDeviceName,
    required int expectedMemoCount,
    required int expectedAttachmentCount,
    required void Function(
      MemoFlowMigrationTransferStage stage, {
      String? message,
    })?
    onProgress,
  }) async {
    final key = 'migration_${DateTime.now().millisecondsSinceEpoch}';
    await ensureManagedWorkspaceStructure(key);
    final path = await resolveManagedWorkspacePath(key);
    final name = _buildWorkspaceName(senderDeviceName);
    final library = LocalLibrary(
      key: key,
      name: name,
      storageKind: LocalLibraryStorageKind.managedPrivate,
      rootPath: path,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final targetDb = createWorkspaceDatabase(key);
    try {
      await _writeExtractedFilesToLibrary(
        payloadDir: payloadDir,
        library: library,
        targetDb: targetDb,
        expectedMemoCount: expectedMemoCount,
        expectedAttachmentCount: expectedAttachmentCount,
        onProgress: onProgress,
      );
      return library;
    } catch (_) {
      await targetDb.close();
      await _deleteImportedWorkspaceArtifacts(library);
      rethrow;
    } finally {
      await targetDb.close();
    }
  }

  Future<void> _overwriteCurrentWorkspace({
    required Directory payloadDir,
    required LocalLibrary library,
    required int expectedMemoCount,
    required int expectedAttachmentCount,
    required void Function(
      MemoFlowMigrationTransferStage stage, {
      String? message,
    })?
    onProgress,
  }) async {
    await _writeExtractedFilesToLibrary(
      payloadDir: payloadDir,
      library: library,
      targetDb: db,
      expectedMemoCount: expectedMemoCount,
      expectedAttachmentCount: expectedAttachmentCount,
      clearFirst: true,
      onProgress: onProgress,
    );
  }

  Future<void> _writeExtractedFilesToLibrary({
    required Directory payloadDir,
    required LocalLibrary library,
    required AppDatabase targetDb,
    required int expectedMemoCount,
    required int expectedAttachmentCount,
    bool clearFirst = false,
    required void Function(
      MemoFlowMigrationTransferStage stage, {
      String? message,
    })?
    onProgress,
  }) async {
    final fileSystem = LocalLibraryFileSystem(library);
    final memosDir = Directory(p.join(payloadDir.path, 'memos'));
    final attachmentsDir = Directory(p.join(payloadDir.path, 'attachments'));
    final sourceFileCount =
        await _countFiles(memosDir) + await _countFiles(attachmentsDir);
    if (expectedMemoCount + expectedAttachmentCount > 0 &&
        sourceFileCount == 0) {
      throw StateError(
        'Migration package did not contain the expected memo files.',
      );
    }

    if (clearFirst) {
      await fileSystem.clearLibrary();
      await fileSystem.deleteRelativeFile(
        LocalLibraryFileSystem.scanManifestFilename,
      );
    }
    await fileSystem.ensureStructure();

    onProgress?.call(MemoFlowMigrationTransferStage.importingFiles);

    if (await memosDir.exists()) {
      await for (final entity in memosDir.list(recursive: true)) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: payloadDir.path);
        await fileSystem.writeFileFromChunks(
          relative,
          entity.openRead().map(Uint8List.fromList),
          mimeType: _guessMimeType(entity.path),
        );
      }
    }

    if (await attachmentsDir.exists()) {
      await for (final entity in attachmentsDir.list(recursive: true)) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: payloadDir.path);
        await fileSystem.writeFileFromChunks(
          relative,
          entity.openRead().map(Uint8List.fromList),
          mimeType: _guessMimeType(entity.path),
        );
      }
    }

    onProgress?.call(MemoFlowMigrationTransferStage.scanning);
    final scanService = LocalLibraryScanService(
      db: targetDb,
      fileSystem: fileSystem,
      attachmentStore: attachmentStore,
    );
    final result = await scanService.scanAndMerge(forceDisk: true);
    if (result is LocalScanFailure) {
      throw StateError(result.error.message ?? 'Local library scan failed.');
    }
  }

  Future<Directory> _resolvePayloadRoot(Directory extractDir) async {
    var current = extractDir;
    for (var depth = 0; depth < 4; depth++) {
      if (await _hasPayloadEntries(current)) {
        return current;
      }
      final children = await current
          .list(followLinks: false)
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .toList();
      if (children.length != 1) {
        break;
      }
      current = children.single;
    }
    return extractDir;
  }

  Future<bool> _hasPayloadEntries(Directory dir) async {
    final memosDir = Directory(p.join(dir.path, 'memos'));
    if (await memosDir.exists()) return true;
    final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
    if (await attachmentsDir.exists()) return true;
    final configDir = Directory(p.join(dir.path, 'config'));
    if (await configDir.exists()) return true;
    final manifestFile = File(p.join(dir.path, 'manifest.json'));
    return manifestFile.exists();
  }

  Future<int> _countFiles(Directory dir) async {
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        count += 1;
      }
    }
    return count;
  }

  Future<void> _normalizeExtractedPaths(Directory root) async {
    if (Platform.isWindows) {
      return;
    }
    final pendingMoves = <({File source, String normalizedRelativePath})>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: root.path);
      final normalizedRelativePath = relativePath.replaceAll('\\', '/');
      if (normalizedRelativePath == relativePath) continue;
      pendingMoves.add((
        source: entity,
        normalizedRelativePath: normalizedRelativePath,
      ));
    }

    for (final move in pendingMoves) {
      final target = File(p.join(root.path, move.normalizedRelativePath));
      await target.parent.create(recursive: true);
      if (await target.exists()) {
        await target.delete();
      }
      await move.source.rename(target.path);
    }
  }

  String _buildWorkspaceName(String senderDeviceName) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return '来自 $senderDeviceName 的迁移 ${formatter.format(DateTime.now())}';
  }

  Future<void> _rollbackImportedWorkspace(
    LocalLibrary library, {
    required bool unregisterFromLibraryList,
  }) async {
    if (unregisterFromLibraryList) {
      try {
        await unregisterLibrary?.call(library.key);
      } catch (_) {}
    }
    await _deleteImportedWorkspaceArtifacts(library);
  }

  Future<void> _deleteImportedWorkspaceArtifacts(LocalLibrary library) async {
    try {
      await deleteWorkspaceDatabase(library.key);
    } catch (_) {}

    final rootPath = library.rootPath?.trim() ?? '';
    if (rootPath.isEmpty) return;
    final workspaceDir = Directory(p.dirname(rootPath));
    try {
      if (await workspaceDir.exists()) {
        await workspaceDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.md') || lower.endsWith('.txt')) {
      return 'text/plain';
    }
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}
