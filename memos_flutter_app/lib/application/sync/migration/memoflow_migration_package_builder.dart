import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/local_library/local_library_fs.dart';
import '../../../data/models/local_library.dart';
import '../config_transfer/config_transfer_bundle.dart';
import '../config_transfer/config_transfer_codec.dart';
import 'memoflow_migration_models.dart';

class MemoFlowMigrationPackageBuilder {
  MemoFlowMigrationPackageBuilder({
    required this.codec,
    required this.readConfigBundle,
  });

  final ConfigTransferCodec codec;
  final Future<ConfigTransferBundle> Function(
    Set<MemoFlowMigrationConfigType> configTypes,
  )
  readConfigBundle;

  Future<MemoFlowMigrationPackageBuildResult> buildPackage({
    required LocalLibrary sourceLibrary,
    required bool includeMemos,
    required Set<MemoFlowMigrationConfigType> configTypes,
    required String senderDeviceName,
    required String senderPlatform,
  }) async {
    if (!includeMemos && configTypes.isEmpty) {
      throw StateError('Nothing selected for migration.');
    }

    final fileSystem = LocalLibraryFileSystem(sourceLibrary);
    final tempRoot = await getTemporaryDirectory();
    final workingDir = await Directory(
      p.join(
        tempRoot.path,
        'memoflow_migration_${DateTime.now().millisecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final stagingDir = await Directory(
      p.join(workingDir.path, 'payload'),
    ).create(recursive: true);

    var memoCount = 0;
    var attachmentCount = 0;
    var draftCount = 0;
    var draftAttachmentCount = 0;

    if (includeMemos) {
      final memoEntries = await fileSystem.listMemos();
      final allFiles = await fileSystem.listAllFiles();
      final memoMetadataEntries = allFiles
          .where(
            (entry) => entry.relativePath
                .replaceAll('\\', '/')
                .startsWith(
                  '${LocalLibraryFileSystem.memoMetaDirRelativePath}/',
                ),
          )
          .toList(growable: false);
      final attachmentEntries = allFiles
          .where(
            (entry) => entry.relativePath
                .replaceAll('\\', '/')
                .startsWith('attachments/'),
          )
          .toList(growable: false);
      memoCount = memoEntries.length;
      attachmentCount = attachmentEntries.length;

      for (final entry in [
        ...memoEntries,
        ...memoMetadataEntries,
        ...attachmentEntries,
      ]) {
        final destination = File(p.join(stagingDir.path, entry.relativePath));
        await destination.parent.create(recursive: true);
        await fileSystem.copyToLocal(entry, destination.path);
      }
    }

    if (configTypes.isNotEmpty) {
      final bundle = await readConfigBundle(configTypes);
      final files = codec.encode(bundle, configTypes: configTypes);
      draftCount = bundle.draftBox?.draftCount ?? 0;
      draftAttachmentCount = bundle.draftBox?.draftAttachmentCount ?? 0;
      for (final entry in files.entries) {
        final target = File(p.join(stagingDir.path, entry.key));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.value, flush: true);
      }
    }

    final draftManifest = MemoFlowMigrationPackageManifest(
      schemaVersion: 1,
      protocolVersion: 'migration-v1',
      exportedAt: DateTime.now().toUtc(),
      senderDeviceName: senderDeviceName,
      senderPlatform: senderPlatform,
      sourceWorkspaceName: sourceLibrary.name,
      includeMemos: includeMemos,
      includeSettings: configTypes.isNotEmpty,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      draftCount: draftCount,
      draftAttachmentCount: draftAttachmentCount,
      totalBytes: 0,
      sha256: '',
      configTypes: configTypes,
    );
    final manifestFile = File(p.join(stagingDir.path, 'manifest.json'));
    await manifestFile.writeAsString(
      encodeJsonObject(draftManifest.toJson()),
      flush: true,
    );

    final zipFile = File(
      p.join(
        workingDir.path,
        'memoflow_migration_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    final archive = Archive();
    await for (final entity in stagingDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relativePath = p
          .relative(entity.path, from: stagingDir.path)
          .replaceAll('\\', '/');
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    await zipFile.writeAsBytes(encoded, flush: true);

    final totalBytes = await zipFile.length();
    final sha256 = await _hashFile(zipFile);

    return MemoFlowMigrationPackageBuildResult(
      packageFile: zipFile,
      manifest: draftManifest.copyWith(totalBytes: totalBytes, sha256: sha256),
    );
  }

  Future<String> _hashFile(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
