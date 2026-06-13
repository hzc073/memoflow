import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:memos_flutter_app/data/local_library/local_library_paths.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/repositories/local_library_repository.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;
  late FlutterSecureStorage storage;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    support = await initializeTestSupport();
    storage = const FlutterSecureStorage();
  });

  tearDown(() async {
    await support.dispose();
  });

  test(
    'migrates legacy secure-storage state to app support metadata',
    () async {
      final currentPath = await resolveManagedWorkspacePath(
        'managed_workspace',
      );
      final legacyState = LocalLibraryState(
        libraries: [
          LocalLibrary(
            key: 'managed_workspace',
            name: 'Managed Workspace',
            storageKind: LocalLibraryStorageKind.managedPrivate,
            treeUri: 'content://legacy/tree',
            rootPath: p.join('/old', 'ios', 'container'),
          ),
        ],
      );
      await storage.write(
        key: 'local_library_state_v1',
        value: jsonEncode(legacyState.toJson()),
      );

      final repo = LocalLibraryRepository(storage);
      final result = await repo.readWithStatus();

      expect(result.isSuccess, isTrue);
      final migrated = result.data!.libraries.single;
      expect(migrated.key, 'managed_workspace');
      expect(migrated.storageKind, LocalLibraryStorageKind.managedPrivate);
      expect(migrated.treeUri, isNull);
      expect(migrated.rootPath, currentPath);
      expect(migrated.updatedAt, isNotNull);

      await storage.write(
        key: 'local_library_state_v1',
        value: jsonEncode(
          const LocalLibraryState(
            libraries: [
              LocalLibrary(key: 'legacy_override', name: 'Legacy Override'),
            ],
          ).toJson(),
        ),
      );

      final secondRead = await repo.read();
      expect(secondRead.libraries.single.key, 'managed_workspace');
    },
  );

  test('skips stale legacy managed workspace metadata', () async {
    await storage.write(key: 'account_secret', value: 'secret-value');
    await storage.write(
      key: 'local_library_state_v1',
      value: jsonEncode(
        LocalLibraryState(
          libraries: [
            LocalLibrary(
              key: 'stale_workspace',
              name: 'Stale Workspace',
              storageKind: LocalLibraryStorageKind.managedPrivate,
              rootPath: p.join('/old', 'ios', 'container'),
            ),
          ],
        ).toJson(),
      ),
    );

    final repo = LocalLibraryRepository(storage);
    final state = await repo.read();

    expect(state.libraries, isEmpty);
    expect(await storage.read(key: 'account_secret'), 'secret-value');

    final stalePath = await resolveManagedWorkspacePath(
      'stale_workspace',
      create: false,
    );
    expect(await Directory(stalePath).exists(), isFalse);
  });
}
