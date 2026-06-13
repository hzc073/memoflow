import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../data/local_library/local_library_fs.dart';
import '../../data/local_library/local_library_paths.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/local_library.dart';

class LocalLibraryImportMigrationService {
  Future<LocalLibrary> migrateIfNeeded(LocalLibrary library) async {
    if (library.storageKind == LocalLibraryStorageKind.managedPrivate) {
      return _rebaseManagedPrivateLibrary(library);
    }

    final targetPath = await resolveManagedWorkspacePath(library.key);
    final targetLibrary = library.copyWith(
      storageKind: LocalLibraryStorageKind.managedPrivate,
      clearTreeUri: true,
      rootPath: targetPath,
      updatedAt: DateTime.now(),
    );

    final currentRoot = (library.rootPath ?? '').trim();
    if (!library.isSaf &&
        currentRoot.isNotEmpty &&
        p.normalize(currentRoot) == p.normalize(targetPath)) {
      return targetLibrary;
    }

    final sourceFileSystem = LocalLibraryFileSystem(library);
    final targetFileSystem = LocalLibraryFileSystem(targetLibrary);

    final sourceFiles = await _relevantFiles(sourceFileSystem);
    if (sourceFiles.isEmpty) {
      await targetFileSystem.ensureStructure();
      return targetLibrary;
    }

    final existingTargetFiles = await _relevantFiles(targetFileSystem);
    if (existingTargetFiles.isNotEmpty &&
        _sameRelativeFiles(sourceFiles, existingTargetFiles)) {
      return targetLibrary;
    }

    await _clearTarget(targetFileSystem);
    await targetFileSystem.ensureStructure();

    for (final entry in sourceFiles) {
      final stream = await sourceFileSystem.openReadStream(entry);
      await targetFileSystem.writeFileFromChunks(
        entry.relativePath,
        stream,
        mimeType: _guessMimeType(entry.name),
      );
    }

    final copiedFiles = await _relevantFiles(targetFileSystem);
    if (!_sameRelativeFiles(sourceFiles, copiedFiles)) {
      throw StateError('Local library migration verification failed');
    }

    if (kDebugMode) {
      LogManager.instance.info(
        'LocalLibrary migration completed',
        context: <String, Object?>{
          'workspaceKey': library.key,
          'sourceIsSaf': library.isSaf,
          'fileCount': copiedFiles.length,
        },
      );
    }

    return targetLibrary;
  }

  Future<LocalLibrary> _rebaseManagedPrivateLibrary(
    LocalLibrary library,
  ) async {
    final targetPath = await resolveManagedWorkspacePath(library.key);
    final currentRoot = (library.rootPath ?? '').trim();
    final pathChanged =
        currentRoot.isEmpty ||
        p.normalize(currentRoot) != p.normalize(targetPath);
    final treeUriChanged = library.treeUri?.trim().isNotEmpty ?? false;
    if (!pathChanged && !treeUriChanged) {
      return library;
    }

    return library.copyWith(
      storageKind: LocalLibraryStorageKind.managedPrivate,
      clearTreeUri: true,
      rootPath: targetPath,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _clearTarget(LocalLibraryFileSystem fileSystem) async {
    await fileSystem.clearLibrary();
    await fileSystem.deleteRelativeFile(
      LocalLibraryFileSystem.scanManifestFilename,
    );
  }

  Future<List<LocalLibraryFileEntry>> _relevantFiles(
    LocalLibraryFileSystem fileSystem,
  ) async {
    final files = await fileSystem.listAllFiles();
    return files
        .where((entry) {
          final path = entry.relativePath.replaceAll('\\', '/').trim();
          if (path.isEmpty) return false;
          if (path == 'index.md' || path == 'index.md.txt') return true;
          if (path == LocalLibraryFileSystem.scanManifestFilename) return true;
          return path.startsWith('memos/') || path.startsWith('attachments/');
        })
        .toList(growable: false)
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
  }

  bool _sameRelativeFiles(
    List<LocalLibraryFileEntry> a,
    List<LocalLibraryFileEntry> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].relativePath != b[i].relativePath) return false;
      if (a[i].length != b[i].length) return false;
    }
    return true;
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    return 'application/octet-stream';
  }
}
