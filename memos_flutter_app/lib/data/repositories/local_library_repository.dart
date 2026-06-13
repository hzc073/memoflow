import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';
import '../../core/storage_read.dart';
import '../local_library/local_library_paths.dart';
import '../models/local_library.dart';

class LocalLibraryState {
  const LocalLibraryState({required this.libraries});

  final List<LocalLibrary> libraries;

  Map<String, dynamic> toJson() => {
    'libraries': libraries.map((l) => l.toJson()).toList(growable: false),
  };

  factory LocalLibraryState.fromJson(Map<String, dynamic> json) {
    final list = <LocalLibrary>[];
    final raw = json['libraries'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(LocalLibrary.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return LocalLibraryState(libraries: list);
  }
}

class LocalLibraryRepository {
  LocalLibraryRepository(
    this._storage, {
    LocalLibraryMetadataStore? metadataStore,
  }) : _metadataStore =
           metadataStore ?? const AppSupportLocalLibraryMetadataStore();

  static const _kStateKey = 'local_library_state_v1';

  final FlutterSecureStorage _storage;
  final LocalLibraryMetadataStore _metadataStore;

  Future<StorageReadResult<LocalLibraryState>> readWithStatus() async {
    final appDataResult = await _metadataStore.readWithStatus();
    if (appDataResult.isError || appDataResult.isSuccess) {
      return appDataResult;
    }

    final legacyResult = await _readLegacyWithStatus();
    if (!legacyResult.isSuccess) {
      return legacyResult;
    }

    try {
      final migrated = await _migrateLegacyState(legacyResult.data!);
      await _metadataStore.write(migrated);
      return StorageReadResult.success(migrated);
    } catch (error, stackTrace) {
      return StorageReadResult.failure(cause: error, stackTrace: stackTrace);
    }
  }

  Future<StorageReadResult<LocalLibraryState>> _readLegacyWithStatus() async {
    String? raw;
    try {
      raw = await _storage.read(key: _kStateKey);
    } catch (error, stackTrace) {
      return StorageReadResult.failure(cause: error, stackTrace: stackTrace);
    }
    if (raw == null || raw.trim().isEmpty) {
      return StorageReadResult.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return StorageReadResult.success(
          LocalLibraryState.fromJson(decoded.cast<String, dynamic>()),
        );
      }
      return StorageReadResult.failure(
        cause: const FormatException('Expected JSON object'),
        stackTrace: StackTrace.current,
      );
    } catch (error, stackTrace) {
      return StorageReadResult.failure(cause: error, stackTrace: stackTrace);
    }
  }

  Future<LocalLibraryState> read() async {
    final result = await readWithStatus();
    if (result.isSuccess) {
      return result.data!;
    }
    return const LocalLibraryState(libraries: []);
  }

  Future<void> write(LocalLibraryState state) async {
    await _metadataStore.write(state);
  }

  Future<void> clear() async {
    await _metadataStore.clear();
    await _storage.delete(key: _kStateKey);
  }

  Future<LocalLibraryState> _migrateLegacyState(LocalLibraryState state) async {
    final migrated = <LocalLibrary>[];
    for (final library in state.libraries) {
      if (library.storageKind != LocalLibraryStorageKind.managedPrivate) {
        migrated.add(library);
        continue;
      }

      final probe = await probeManagedWorkspacePath(library.key);
      if (!probe.existsInCurrentContainer) {
        continue;
      }

      migrated.add(await _rebaseManagedPrivateLibrary(library));
    }
    return LocalLibraryState(libraries: migrated);
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
}

abstract class LocalLibraryMetadataStore {
  Future<StorageReadResult<LocalLibraryState>> readWithStatus();

  Future<void> write(LocalLibraryState state);

  Future<void> clear();
}

class AppSupportLocalLibraryMetadataStore implements LocalLibraryMetadataStore {
  const AppSupportLocalLibraryMetadataStore();

  static const _dirName = 'local_library';
  static const _fileName = 'state_v1.json';

  @override
  Future<StorageReadResult<LocalLibraryState>> readWithStatus() async {
    try {
      final file = await _metadataFile(createParent: false);
      if (!await file.exists()) {
        return StorageReadResult.empty();
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return StorageReadResult.empty();
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return StorageReadResult.success(
          LocalLibraryState.fromJson(decoded.cast<String, dynamic>()),
        );
      }
      return StorageReadResult.failure(
        cause: const FormatException('Expected JSON object'),
        stackTrace: StackTrace.current,
      );
    } catch (error, stackTrace) {
      return StorageReadResult.failure(cause: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> write(LocalLibraryState state) async {
    final file = await _metadataFile(createParent: true);
    await file.writeAsString(jsonEncode(state.toJson()), flush: true);
  }

  @override
  Future<void> clear() async {
    final file = await _metadataFile(createParent: false);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _metadataFile({required bool createParent}) async {
    final supportDir = await resolveAppSupportDirectory();
    final dir = Directory(p.join(supportDir.path, _dirName));
    if (createParent && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, _fileName));
  }
}
