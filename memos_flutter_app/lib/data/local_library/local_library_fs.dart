import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../models/local_library.dart';

class LocalLibraryFileEntry {
  const LocalLibraryFileEntry({
    required this.relativePath,
    required this.name,
    required this.isDir,
    required this.length,
    required this.lastModified,
    this.uri,
    this.path,
  });

  final String relativePath;
  final String name;
  final bool isDir;
  final int length;
  final DateTime? lastModified;
  final String? uri;
  final String? path;
}

class LocalLibraryFileSystem {
  LocalLibraryFileSystem(this.library, {SafUtil? safUtil, SafStream? safStream})
    : _saf = safUtil ?? SafUtil(),
      _stream = safStream ?? SafStream();

  final LocalLibrary library;
  final SafUtil _saf;
  final SafStream _stream;

  bool get isSaf => library.isSaf;

  String get _rootPath => library.rootPath ?? '';
  String get _rootUri => library.treeUri ?? '';

  Future<void> ensureStructure() async {
    await _ensureDir(['memos']);
    await _ensureDir(['attachments']);
  }

  Future<void> writeIndex(String content) async {
    await _writeTextFile(['index.md'], content);
  }

  Future<String?> readIndex() async {
    return _readTextFile(['index.md']);
  }

  Future<List<LocalLibraryFileEntry>> listMemos() async {
    return _listFilesInDir(
      ['memos'],
      filter: (name) {
        final lower = name.toLowerCase();
        if (lower == 'index.md' || lower == 'index.md.txt') return false;
        return lower.endsWith('.md') || lower.endsWith('.md.txt');
      },
    );
  }

  Future<String?> readFileText(LocalLibraryFileEntry entry) async {
    if (isSaf) {
      if (entry.uri == null) return null;
      final bytes = await _stream.readFileBytes(entry.uri!);
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (entry.path == null) return null;
    return File(entry.path!).readAsString();
  }

  Future<void> writeMemo({required String uid, required String content}) async {
    await _writeTextFile(['memos', '$uid.md'], content);
  }

  Future<void> deleteMemo(String uid) async {
    await _deleteFile(['memos', '$uid.md']);
  }

  Future<List<LocalLibraryFileEntry>> listAttachments(String memoUid) async {
    return _listFilesInDir(['attachments', memoUid]);
  }

  Future<void> writeAttachmentFromFile({
    required String memoUid,
    required String filename,
    required String srcPath,
    required String mimeType,
  }) async {
    final dir = await _ensureDir(['attachments', memoUid]);
    if (isSaf) {
      await _stream.pasteLocalFile(
        srcPath,
        dir,
        filename,
        mimeType,
        overwrite: true,
      );
      return;
    }
    final dest = File(p.join(dir, filename));
    if (!dest.parent.existsSync()) {
      dest.parent.createSync(recursive: true);
    }
    await File(srcPath).copy(dest.path);
  }

  Future<void> deleteAttachment(String memoUid, String filename) async {
    await _deleteFile(['attachments', memoUid, filename]);
  }

  Future<void> deleteAttachmentsDir(String memoUid) async {
    await _deleteDir(['attachments', memoUid]);
  }

  Future<void> clearLibrary() async {
    await _deleteFile(['index.md']);
    await _deleteDir(['memos']);
    await _deleteDir(['attachments']);
  }

  Future<void> copyToLocal(LocalLibraryFileEntry entry, String destPath) async {
    if (isSaf) {
      if (entry.uri == null) return;
      await _stream.copyToLocalFile(entry.uri!, destPath);
      return;
    }
    if (entry.path == null) return;
    await File(entry.path!).copy(destPath);
  }

  Future<List<LocalLibraryFileEntry>> listAllFiles() async {
    if (!isSaf) {
      final root = Directory(_rootPath);
      if (!root.existsSync()) return const [];
      final entries = <LocalLibraryFileEntry>[];
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: root.path);
        final normalized = relative.replaceAll('\\', '/');
        final stat = await entity.stat();
        entries.add(
          LocalLibraryFileEntry(
            relativePath: normalized,
            name: p.basename(entity.path),
            isDir: false,
            length: stat.size,
            lastModified: stat.modified,
            path: entity.path,
          ),
        );
      }
      return entries;
    }

    final rootUri = _rootUri;
    if (rootUri.trim().isEmpty) return const [];
    final entries = <LocalLibraryFileEntry>[];
    final queue = <({String uri, String relative})>[
      (uri: rootUri, relative: ''),
    ];
    while (queue.isNotEmpty) {
      final item = queue.removeLast();
      final children = await _saf.list(item.uri);
      for (final child in children) {
        final rel = item.relative.isEmpty
            ? child.name
            : '${item.relative}/${child.name}';
        if (child.isDir) {
          queue.add((uri: child.uri, relative: rel));
          continue;
        }
        entries.add(
          LocalLibraryFileEntry(
            relativePath: rel,
            name: child.name,
            isDir: false,
            length: child.length,
            lastModified: child.lastModified == 0
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    child.lastModified,
                    isUtc: true,
                  ).toLocal(),
            uri: child.uri,
          ),
        );
      }
    }
    return entries;
  }

  Future<Stream<Uint8List>> openReadStream(
    LocalLibraryFileEntry entry, {
    int? bufferSize,
  }) async {
    if (isSaf) {
      if (entry.uri == null) return Stream<Uint8List>.empty();
      return _stream.readFileStream(entry.uri!, bufferSize: bufferSize);
    }
    if (entry.path == null) return Stream<Uint8List>.empty();
    return File(entry.path!).openRead().map(Uint8List.fromList);
  }

  Future<void> writeFileFromChunks(
    String relativePath,
    Stream<Uint8List> chunks, {
    required String mimeType,
  }) async {
    final normalized = relativePath.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) return;
    final filename = segments.removeLast();
    final dir = await _ensureDir(segments);
    if (isSaf) {
      final info = await _stream.startWriteStream(
        dir,
        filename,
        mimeType,
        overwrite: true,
      );
      try {
        await for (final chunk in chunks) {
          await _stream.writeChunk(info.session, chunk);
        }
      } finally {
        await _stream.endWriteStream(info.session);
      }
      return;
    }

    final file = File(p.join(dir, filename));
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final sink = file.openWrite();
    await for (final chunk in chunks) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();
  }

  Future<List<LocalLibraryFileEntry>> _listFilesInDir(
    List<String> segments, {
    bool Function(String name)? filter,
  }) async {
    if (isSaf) {
      final dir = await _findDir(segments);
      if (dir == null) return const [];
      final children = await _saf.list(dir);
      final entries = <LocalLibraryFileEntry>[];
      for (final child in children) {
        if (child.isDir) continue;
        if (filter != null && !filter(child.name)) continue;
        final rel = segments.isEmpty
            ? child.name
            : [...segments, child.name].join('/');
        entries.add(
          LocalLibraryFileEntry(
            relativePath: rel,
            name: child.name,
            isDir: false,
            length: child.length,
            lastModified: child.lastModified == 0
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    child.lastModified,
                    isUtc: true,
                  ).toLocal(),
            uri: child.uri,
          ),
        );
      }
      return entries;
    }

    final dirPath = p.joinAll([_rootPath, ...segments]);
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];
    final entries = <LocalLibraryFileEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (filter != null && !filter(name)) continue;
      final stat = await entity.stat();
      final rel = segments.isEmpty ? name : [...segments, name].join('/');
      entries.add(
        LocalLibraryFileEntry(
          relativePath: rel,
          name: name,
          isDir: false,
          length: stat.size,
          lastModified: stat.modified,
          path: entity.path,
        ),
      );
    }
    return entries;
  }

  Future<String?> _readTextFile(List<String> segments) async {
    final entry = await _findFile(segments);
    if (entry == null) return null;
    if (isSaf) {
      final bytes = await _stream.readFileBytes(entry);
      return utf8.decode(bytes, allowMalformed: true);
    }
    return File(entry).readAsString();
  }

  Future<void> _writeTextFile(List<String> segments, String content) async {
    final dirSegments = [...segments];
    final filename = dirSegments.removeLast();
    final dir = await _ensureDir(dirSegments);
    if (isSaf) {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final mimeType = _textMimeTypeForFilename(filename);
      await _stream.writeFileBytes(
        dir,
        filename,
        mimeType,
        bytes,
        overwrite: true,
      );
      return;
    }
    final file = File(p.join(dir, filename));
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(content, flush: true);
  }

  String _textMimeTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'text/plain';
  }

  Future<void> _deleteFile(List<String> segments) async {
    final target = await _findFile(segments);
    if (target == null) return;
    if (isSaf) {
      await _saf.delete(target, false);
      return;
    }
    final file = File(target);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> _deleteDir(List<String> segments) async {
    final target = await _findDir(segments);
    if (target == null) return;
    if (isSaf) {
      await _saf.delete(target, true);
      return;
    }
    final dir = Directory(target);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> _ensureDir(List<String> segments) async {
    if (isSaf) {
      final root = _rootUri;
      if (root.trim().isEmpty) {
        throw StateError('SAF root uri missing');
      }
      if (segments.isEmpty) return root;
      final created = await _saf.mkdirp(root, segments);
      return created.uri;
    }
    final root = _rootPath;
    if (root.trim().isEmpty) {
      throw StateError('Local library root path missing');
    }
    final dirPath = p.joinAll([root, ...segments]);
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  Future<String?> _findDir(List<String> segments) async {
    if (isSaf) {
      final root = _rootUri;
      if (root.trim().isEmpty) return null;
      if (segments.isEmpty) return root;
      final found = await _saf.child(root, segments);
      return found?.uri;
    }
    final root = _rootPath;
    if (root.trim().isEmpty) return null;
    final dirPath = p.joinAll([root, ...segments]);
    final dir = Directory(dirPath);
    return dir.existsSync() ? dir.path : null;
  }

  Future<String?> _findFile(List<String> segments) async {
    if (segments.isEmpty) return null;
    final dirSegments = [...segments];
    final filename = dirSegments.removeLast();
    if (isSaf) {
      final dirUri = await _findDir(dirSegments);
      if (dirUri == null) return null;
      final file = await _saf.child(dirUri, [filename]);
      return file?.uri;
    }
    final root = _rootPath;
    if (root.trim().isEmpty) return null;
    final path = p.joinAll([root, ...segments]);
    final file = File(path);
    return file.existsSync() ? file.path : null;
  }
}
