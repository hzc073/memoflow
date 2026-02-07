import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalAttachmentStore {
  static const _rootDirName = 'local_attachments';

  Future<Directory> _rootDir() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, _rootDirName));
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    return root;
  }

  Future<Directory> ensureMemoDir(String memoUid) async {
    final root = await _rootDir();
    final dir = Directory(p.join(root.path, memoUid));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<String> resolveAttachmentPath(String memoUid, String filename) async {
    final dir = await ensureMemoDir(memoUid);
    return p.join(dir.path, filename);
  }

  Future<void> deleteAttachment(String memoUid, String filename) async {
    final path = await resolveAttachmentPath(memoUid, filename);
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> deleteMemoDir(String memoUid) async {
    final root = await _rootDir();
    final dir = Directory(p.join(root.path, memoUid));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> clearAll() async {
    final root = await _rootDir();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }
}
