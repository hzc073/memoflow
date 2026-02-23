import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

const bool _kEphemeralDebugDefault = true;
const bool _kEphemeralDebugFromDefine = bool.fromEnvironment(
  'MEMOFLOW_EPHEMERAL_DEBUG',
  defaultValue: _kEphemeralDebugDefault,
);

const String _kEphemeralRootDirName = 'memoflow_debug_ephemeral';

bool get isEphemeralDebugStorageEnabled =>
    kDebugMode && _kEphemeralDebugFromDefine;

Future<Directory> _ensureDirectory(Directory dir) async {
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<Directory> _resolveEphemeralRootDirectory() async {
  final temp = await getTemporaryDirectory();
  return _ensureDirectory(Directory(p.join(temp.path, _kEphemeralRootDirName)));
}

Future<void> prepareEphemeralDebugStorage({required bool clearExisting}) async {
  if (!isEphemeralDebugStorageEnabled) return;
  final root = await _resolveEphemeralRootDirectory();
  if (clearExisting && await root.exists()) {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  }
  await _ensureDirectory(root);
}

Future<Directory> resolveAppSupportDirectory() async {
  if (!isEphemeralDebugStorageEnabled) {
    return getApplicationSupportDirectory();
  }
  final root = await _resolveEphemeralRootDirectory();
  return _ensureDirectory(Directory(p.join(root.path, 'support')));
}

Future<Directory> resolveAppDocumentsDirectory() async {
  if (!isEphemeralDebugStorageEnabled) {
    return getApplicationDocumentsDirectory();
  }
  final root = await _resolveEphemeralRootDirectory();
  return _ensureDirectory(Directory(p.join(root.path, 'documents')));
}

Future<String> resolveDatabasesDirectoryPath() async {
  if (!isEphemeralDebugStorageEnabled) {
    return getDatabasesPath();
  }
  final root = await _resolveEphemeralRootDirectory();
  final dir = await _ensureDirectory(Directory(p.join(root.path, 'databases')));
  return dir.path;
}

Future<File> resolveEphemeralSecureStorageFile() async {
  final root = await _resolveEphemeralRootDirectory();
  final dir = await _ensureDirectory(Directory(p.join(root.path, 'secure')));
  return File(p.join(dir.path, 'secure_storage.json'));
}
