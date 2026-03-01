import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';

class TestSupport {
  TestSupport(this.root);

  final Directory root;

  Future<Directory> createTempDir(String prefix) async {
    final dir = Directory(
      p.join(root.path, '$prefix-${DateTime.now().microsecondsSinceEpoch}'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

class TestPathProviderPlatform extends PathProviderPlatform {
  TestPathProviderPlatform(this.root) : super();

  final Directory root;

  Future<String> _ensureDir(String name) async {
    final dir = Directory(p.join(root.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<String?> getTemporaryPath() => _ensureDir('temp');

  @override
  Future<String?> getApplicationSupportPath() => _ensureDir('support');

  @override
  Future<String?> getLibraryPath() => _ensureDir('library');

  @override
  Future<String?> getApplicationDocumentsPath() => _ensureDir('documents');

  @override
  Future<String?> getApplicationCachePath() => _ensureDir('cache');

  @override
  Future<String?> getExternalStoragePath() => _ensureDir('external');

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return <String>[await _ensureDir('external_cache')];
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    final suffix = type == null ? 'external_storage' : 'external_${type.name}';
    return <String>[await _ensureDir(suffix)];
  }

  @override
  Future<String?> getDownloadsPath() => _ensureDir('downloads');
}

Future<TestSupport> initializeTestSupport() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final root = await Directory.systemTemp.createTemp('memoflow_test_');
  PathProviderPlatform.instance = TestPathProviderPlatform(root);
  return TestSupport(root);
}

String uniqueDbName(String prefix) {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  return '${prefix}_$stamp.db';
}

Future<void> deleteTestDatabase(String dbName) async {
  await AppDatabase.deleteDatabaseFile(dbName: dbName);
}

