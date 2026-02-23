import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/app_localization.dart';
import '../../core/debug_ephemeral_storage.dart';
import '../../core/hash.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/db/app_database.dart';
import '../../data/models/account.dart';
import '../../data/models/attachment.dart';
import '../../state/preferences_provider.dart';

typedef ImportProgressCallback = void Function(ImportProgressUpdate update);
typedef ImportCancelCheck = bool Function();

class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImportCancelled implements Exception {
  const ImportCancelled();
}

class ImportProgressUpdate {
  const ImportProgressUpdate({
    required this.progress,
    this.statusText,
    this.progressLabel,
    this.progressDetail,
  });

  final double progress;
  final String? statusText;
  final String? progressLabel;
  final String? progressDetail;
}

class ImportResult {
  const ImportResult({
    required this.memoCount,
    required this.attachmentCount,
    required this.failedCount,
    required this.newTags,
  });

  final int memoCount;
  final int attachmentCount;
  final int failedCount;
  final List<String> newTags;
}

enum _BackendVersion { v025, v024, v021, unknown }

class FlomoImportService {
  FlomoImportService({
    required this.db,
    required this.account,
    required this.language,
  });

  final AppDatabase db;
  final Account account;
  final AppLanguage language;

  static const _source = 'flomo';

  Future<ImportResult> importFile({
    required String filePath,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
  }) async {
    _ensureNotCancelled(isCancelled);
    _reportProgress(
      onProgress,
      progress: 0.05,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_checking_server_version',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_preparing',
      ),
      progressDetail: trByLanguageKey(
        language: language,
        key: 'legacy.msg_may_take_few_seconds',
      ),
    );

    final backend = await _detectBackendVersion();
    if (backend == _BackendVersion.unknown) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_unable_detect_backend_version_check_server',
        ),
      );
    }

    _ensureNotCancelled(isCancelled);
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_import_file_not_found',
        ),
      );
    }

    _reportProgress(
      onProgress,
      progress: 0.1,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_reading_file',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_preparing',
      ),
      progressDetail: p.basename(filePath),
    );

    final bytes = await file.readAsBytes();
    final fileMd5 = md5.convert(bytes).toString();
    final existing = await db.getImportHistory(
      source: _source,
      fileMd5: fileMd5,
    );
    final existingStatus = (existing?['status'] as int?) ?? 0;
    if (existing != null && existingStatus == 1) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_file_has_already_been_imported_skipped',
        ),
      );
    }
    if (await _importMarkerExists(fileMd5)) {
      if (existingStatus != 1) {
        await _deleteImportMarker(fileMd5);
      } else {
        throw ImportException(
          trByLanguageKey(
            language: language,
            key: 'legacy.msg_file_has_already_been_imported_skipped',
          ),
        );
      }
    }

    final historyId = await db.upsertImportHistory(
      source: _source,
      fileMd5: fileMd5,
      fileName: p.basename(filePath),
      status: 0,
      memoCount: 0,
      attachmentCount: 0,
      failedCount: 0,
      error: null,
    );

    var memoCount = 0;
    var attachmentCount = 0;
    var failedCount = 0;

    try {
      final result = await _importBytes(
        filePath: filePath,
        bytes: bytes,
        fileMd5: fileMd5,
        onProgress: onProgress,
        isCancelled: isCancelled,
        counters: _ImportCounters(
          memoCount: () => memoCount,
          setMemoCount: (v) => memoCount = v,
          attachmentCount: () => attachmentCount,
          setAttachmentCount: (v) => attachmentCount = v,
          failedCount: () => failedCount,
          setFailedCount: (v) => failedCount = v,
        ),
      );

      await db.updateImportHistory(
        id: historyId,
        status: 1,
        memoCount: result.memoCount,
        attachmentCount: result.attachmentCount,
        failedCount: result.failedCount,
        error: null,
      );
      await _writeImportMarker(fileMd5, p.basename(filePath));
      return result;
    } catch (e) {
      final message = e is ImportException ? e.message : e.toString();
      await db.updateImportHistory(
        id: historyId,
        status: 2,
        memoCount: memoCount,
        attachmentCount: attachmentCount,
        failedCount: failedCount,
        error: message,
      );
      await _deleteImportMarker(fileMd5);
      rethrow;
    }
  }

  Future<ImportResult> _importBytes({
    required String filePath,
    required List<int> bytes,
    required String fileMd5,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
    required _ImportCounters counters,
  }) async {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.zip')) {
      return _importZipBytes(
        bytes: bytes,
        fileMd5: fileMd5,
        onProgress: onProgress,
        isCancelled: isCancelled,
        counters: counters,
      );
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return _importHtmlBytes(
        bytes: bytes,
        htmlRootPath: p.dirname(filePath),
        onProgress: onProgress,
        isCancelled: isCancelled,
        counters: counters,
      );
    }
    throw ImportException(
      trByLanguageKey(
        language: language,
        key: 'legacy.msg_unsupported_file_type',
      ),
    );
  }

  Future<ImportResult> _importZipBytes({
    required List<int> bytes,
    required String fileMd5,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
    required _ImportCounters counters,
  }) async {
    _ensureNotCancelled(isCancelled);
    _reportProgress(
      onProgress,
      progress: 0.15,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_decoding_zip',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_parsing',
      ),
      progressDetail: trByLanguageKey(
        language: language,
        key: 'legacy.msg_preparing_file_structure',
      ),
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final memoEntries = _memoFlowMemoEntries(archive);
    if (memoEntries.isNotEmpty || _memoFlowIndexExists(archive)) {
      return _importMemoFlowExportZip(
        archive: archive,
        fileMd5: fileMd5,
        onProgress: onProgress,
        isCancelled: isCancelled,
        counters: counters,
      );
    }
    final htmlEntry = archive.files.firstWhere(
      (f) => f.isFile && f.name.toLowerCase().endsWith('.html'),
      orElse: () => ArchiveFile('', 0, const []),
    );
    if (htmlEntry.name.isEmpty) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_no_html_file_found_zip',
        ),
      );
    }

    final htmlBytes = _readArchiveBytes(htmlEntry);
    final htmlRootInZip = p.dirname(htmlEntry.name);
    final importRoot = await _resolveImportRoot(fileMd5);
    await _extractArchiveSafely(archive, importRoot);

    final htmlRootPath = p.normalize(p.join(importRoot.path, htmlRootInZip));
    return _importHtmlBytes(
      bytes: htmlBytes,
      htmlRootPath: htmlRootPath,
      onProgress: onProgress,
      isCancelled: isCancelled,
      counters: counters,
    );
  }

  Future<ImportResult> _importMemoFlowExportZip({
    required Archive archive,
    required String fileMd5,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
    required _ImportCounters counters,
  }) async {
    _ensureNotCancelled(isCancelled);
    _reportProgress(
      onProgress,
      progress: 0.2,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_parsing_memoflow_export',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_parsing',
      ),
      progressDetail: trByLanguageKey(
        language: language,
        key: 'legacy.msg_preparing_memo_content',
      ),
    );

    final memoEntries = _memoFlowMemoEntries(archive);
    if (memoEntries.isEmpty) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_no_markdown_memos_found_zip',
        ),
      );
    }

    final importRoot = await _resolveImportRoot(fileMd5);
    await _extractArchiveSafely(archive, importRoot);

    final attachmentEntries = _memoFlowAttachmentEntries(archive);
    final attachmentsByMemoUid = <String, List<_MemoFlowArchiveAttachment>>{};
    for (final entry in attachmentEntries) {
      attachmentsByMemoUid
          .putIfAbsent(entry.memoUid, () => <_MemoFlowArchiveAttachment>[])
          .add(entry);
    }

    final existingTags = await _loadExistingTags();
    final importedTags = <String>{};

    final total = memoEntries.length;
    var processed = 0;

    for (final memoFile in memoEntries) {
      _ensureNotCancelled(isCancelled);
      processed++;

      final raw = utf8.decode(
        _readArchiveBytes(memoFile),
        allowMalformed: true,
      );
      final parsed = _parseMemoFlowMarkdown(raw);
      final content = parsed.content.trimRight();
      if (content.trim().isEmpty) {
        counters.setFailedCount(counters.failedCount() + 1);
        _reportQueueProgress(onProgress, processed, total);
        continue;
      }

      final memoUid = parsed.uid.isNotEmpty ? parsed.uid : generateUid();
      final mergedTags = <String>{
        ...parsed.tags,
        ...extractTags(content),
      }.toList(growable: false)..sort();
      importedTags.addAll(mergedTags);

      final memoAttachments =
          attachmentsByMemoUid[parsed.uid] ??
          const <_MemoFlowArchiveAttachment>[];
      final attachments = <Map<String, dynamic>>[];
      final attachmentQueue = <_QueuedAttachment>[];
      for (final attachment in memoAttachments) {
        final localPath = _resolveArchivePath(
          importRoot,
          attachment.archivePath,
        );
        if (localPath == null) continue;
        final file = File(localPath);
        if (!file.existsSync()) continue;
        final filename = attachment.filename;
        final mimeType = _guessMimeType(filename);
        final size = file.lengthSync();
        final attachmentUid = generateUid();
        attachments.add(
          Attachment(
            name: 'attachments/$attachmentUid',
            filename: filename,
            type: mimeType,
            size: size,
            externalLink: Uri.file(localPath).toString(),
          ).toJson(),
        );
        attachmentQueue.add(
          _QueuedAttachment(
            uid: attachmentUid,
            memoUid: memoUid,
            filePath: localPath,
            filename: filename,
            mimeType: mimeType,
            size: size,
          ),
        );
      }

      await db.upsertMemo(
        uid: memoUid,
        content: content,
        visibility: parsed.visibility,
        pinned: parsed.pinned,
        state: parsed.state,
        createTimeSec: parsed.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: parsed.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: mergedTags,
        attachments: attachments,
        location: null,
        relationCount: 0,
        syncState: 1,
      );

      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': memoUid,
          'content': content,
          'visibility': parsed.visibility,
          'pinned': parsed.pinned,
          'has_attachments': attachments.isNotEmpty,
          'display_time':
              parsed.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        },
      );

      if (parsed.state.trim().isNotEmpty &&
          parsed.state.trim().toUpperCase() != 'NORMAL') {
        await db.enqueueOutbox(
          type: 'update_memo',
          payload: {'uid': memoUid, 'state': parsed.state},
        );
      }

      for (final attachment in attachmentQueue) {
        await db.enqueueOutbox(
          type: 'upload_attachment',
          payload: {
            'uid': attachment.uid,
            'memo_uid': attachment.memoUid,
            'file_path': attachment.filePath,
            'filename': attachment.filename,
            'mime_type': attachment.mimeType,
            'file_size': attachment.size,
          },
        );
        counters.setAttachmentCount(counters.attachmentCount() + 1);
      }

      counters.setMemoCount(counters.memoCount() + 1);
      _reportQueueProgress(onProgress, processed, total);
    }

    final newTags =
        importedTags.difference(existingTags).toList(growable: false)..sort();

    _reportProgress(
      onProgress,
      progress: 1.0,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_import_complete',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_done',
      ),
      progressDetail: trByLanguageKey(
        language: language,
        key: 'legacy.msg_submitting_sync_queue',
      ),
    );

    return ImportResult(
      memoCount: counters.memoCount(),
      attachmentCount: counters.attachmentCount(),
      failedCount: counters.failedCount(),
      newTags: newTags,
    );
  }

  Future<ImportResult> _importHtmlBytes({
    required List<int> bytes,
    required String htmlRootPath,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
    required _ImportCounters counters,
  }) async {
    _ensureNotCancelled(isCancelled);
    _reportProgress(
      onProgress,
      progress: 0.25,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_parsing_html',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_parsing',
      ),
      progressDetail: trByLanguageKey(
        language: language,
        key: 'legacy.msg_locating_memo_content',
      ),
    );

    final html = utf8.decode(bytes, allowMalformed: true);
    final parsed = _parseFlomoHtml(html, htmlRootPath);
    if (parsed.isEmpty) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_no_memos_found_html',
        ),
      );
    }

    final existingTags = await _loadExistingTags();
    final importedTags = <String>{};

    final total = parsed.length;
    var processed = 0;

    for (final item in parsed) {
      _ensureNotCancelled(isCancelled);
      processed++;
      final rawContent = item.content.trim();
      if (rawContent.isEmpty) {
        counters.setFailedCount(counters.failedCount() + 1);
        _reportQueueProgress(onProgress, processed, total);
        continue;
      }

      final content = rawContent;
      final memoUid = generateUid();
      final tags = extractTags(content);
      importedTags.addAll(tags);

      final attachments = <Map<String, dynamic>>[];
      final attachmentQueue = <_QueuedAttachment>[];
      for (final file in item.attachments) {
        final attachmentUid = generateUid();
        attachments.add(
          Attachment(
            name: 'attachments/$attachmentUid',
            filename: file.filename,
            type: file.mimeType,
            size: file.size,
            externalLink: file.externalLink,
          ).toJson(),
        );
        attachmentQueue.add(
          _QueuedAttachment(
            uid: attachmentUid,
            memoUid: memoUid,
            filePath: file.localPath,
            filename: file.filename,
            mimeType: file.mimeType,
            size: file.size,
          ),
        );
      }

      await db.upsertMemo(
        uid: memoUid,
        content: content,
        visibility: 'PRIVATE',
        pinned: false,
        state: 'NORMAL',
        createTimeSec: item.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: item.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: tags,
        attachments: attachments,
        location: null,
        relationCount: 0,
        syncState: 1,
      );

      await db.enqueueOutbox(
        type: 'create_memo',
        payload: {
          'uid': memoUid,
          'content': content,
          'visibility': 'PRIVATE',
          'pinned': false,
          'has_attachments': attachments.isNotEmpty,
          'display_time':
              item.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        },
      );

      for (final attachment in attachmentQueue) {
        await db.enqueueOutbox(
          type: 'upload_attachment',
          payload: {
            'uid': attachment.uid,
            'memo_uid': attachment.memoUid,
            'file_path': attachment.filePath,
            'filename': attachment.filename,
            'mime_type': attachment.mimeType,
            'file_size': attachment.size,
          },
        );
        counters.setAttachmentCount(counters.attachmentCount() + 1);
      }

      counters.setMemoCount(counters.memoCount() + 1);
      _reportQueueProgress(onProgress, processed, total);
    }

    final newTags =
        importedTags.difference(existingTags).toList(growable: false)..sort();

    _reportProgress(
      onProgress,
      progress: 1.0,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_import_complete',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_done',
      ),
      progressDetail: trByLanguageKey(
        language: language,
        key: 'legacy.msg_submitting_sync_queue',
      ),
    );

    return ImportResult(
      memoCount: counters.memoCount(),
      attachmentCount: counters.attachmentCount(),
      failedCount: counters.failedCount(),
      newTags: newTags,
    );
  }

  Future<Set<String>> _loadExistingTags() async {
    final tags = await db.listTagStrings(state: 'NORMAL');
    final out = <String>{};
    for (final line in tags) {
      final parts = line.split(' ');
      for (final tag in parts) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) out.add(trimmed);
      }
    }
    return out;
  }

  Future<_BackendVersion> _detectBackendVersion() async {
    final dio = Dio(
      BaseOptions(
        baseUrl: dioBaseUrlString(account.baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, Object?>{
          'Authorization': 'Bearer ${account.personalAccessToken}',
        },
      ),
    );

    if (await _probeEndpoint(dio, 'api/v1/instance/profile')) {
      return _BackendVersion.v025;
    }
    if (await _probeEndpoint(dio, 'api/v1/workspace/profile')) {
      return _BackendVersion.v024;
    }
    if (await _probeEndpoint(dio, 'api/v2/workspace/profile')) {
      return _BackendVersion.v021;
    }
    return _BackendVersion.unknown;
  }

  Future<bool> _probeEndpoint(Dio dio, String path) async {
    try {
      final response = await dio.get(path);
      final status = response.statusCode ?? 0;
      return status >= 200 && status < 300;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404 || status == 405) return false;
      rethrow;
    }
  }

  Future<Directory> _resolveImportRoot(
    String fileMd5, {
    bool create = true,
  }) async {
    final base = await resolveAppDocumentsDirectory();
    final key = account.key.isNotEmpty
        ? account.key
        : account.baseUrl.toString();
    final accountHash = fnv1a64Hex(key);
    final dir = Directory(
      p.join(base.path, 'MemoFlow_imports', accountHash, fileMd5),
    );
    if (create && !dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _importMarkerFile(String fileMd5, {bool create = false}) async {
    final root = await _resolveImportRoot(fileMd5, create: create);
    return File(p.join(root.path, 'import.json'));
  }

  Future<bool> _importMarkerExists(String fileMd5) async {
    final marker = await _importMarkerFile(fileMd5);
    return marker.existsSync();
  }

  Future<void> _writeImportMarker(String fileMd5, String fileName) async {
    final marker = await _importMarkerFile(fileMd5, create: true);
    if (!marker.existsSync()) {
      final payload = jsonEncode({
        'md5': fileMd5,
        'fileName': fileName,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      await marker.writeAsString(payload, flush: true);
    }
  }

  Future<void> _deleteImportMarker(String fileMd5) async {
    final marker = await _importMarkerFile(fileMd5);
    if (marker.existsSync()) {
      await marker.delete();
    }
  }

  Future<void> _extractArchiveSafely(Archive archive, Directory target) async {
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final outPath = p.normalize(p.join(target.path, file.name));
      if (!p.isWithin(target.path, outPath)) continue;
      final parent = Directory(p.dirname(outPath));
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      final bytes = _readArchiveBytes(file);
      await File(outPath).writeAsBytes(bytes, flush: true);
    }
  }

  List<int> _readArchiveBytes(ArchiveFile file) {
    return file.content;
  }

  List<ArchiveFile> _memoFlowMemoEntries(Archive archive) {
    final entries = <ArchiveFile>[];
    for (final file in archive.files) {
      if (_isMemoFlowMemoEntry(file)) {
        entries.add(file);
      }
    }
    return entries;
  }

  bool _memoFlowIndexExists(Archive archive) {
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = _normalizeArchivePath(file.name).toLowerCase();
      if (normalized == 'index.md' || normalized.endsWith('memos/index.md')) {
        return true;
      }
    }
    return false;
  }

  bool _isMemoFlowMemoEntry(ArchiveFile file) {
    if (!file.isFile) return false;
    final normalized = _normalizeArchivePath(file.name);
    final lower = normalized.toLowerCase();
    if (!lower.endsWith('.md')) return false;
    final segments = lower.split('/');
    final memosIndex = segments.lastIndexOf('memos');
    if (memosIndex == -1 || memosIndex >= segments.length - 1) return false;
    final filename = segments.last;
    return filename != 'index.md';
  }

  List<_MemoFlowArchiveAttachment> _memoFlowAttachmentEntries(Archive archive) {
    final entries = <_MemoFlowArchiveAttachment>[];
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = _normalizeArchivePath(file.name);
      final segments = normalized.split('/');
      final lowerSegments = segments
          .map((s) => s.toLowerCase())
          .toList(growable: false);
      final idx = lowerSegments.lastIndexOf('attachments');
      if (idx == -1 || segments.length < idx + 3) continue;
      final memoUid = segments[idx + 1].trim();
      final filename = segments.last.trim();
      if (memoUid.isEmpty || filename.isEmpty) continue;
      entries.add(
        _MemoFlowArchiveAttachment(
          memoUid: memoUid,
          filename: filename,
          archivePath: file.name,
        ),
      );
    }
    return entries;
  }

  String _normalizeArchivePath(String raw) {
    var normalized = raw.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }

  String? _resolveArchivePath(Directory root, String archivePath) {
    final outPath = p.normalize(p.join(root.path, archivePath));
    if (!p.isWithin(root.path, outPath)) return null;
    return outPath;
  }

  _MemoFlowParsedMemo _parseMemoFlowMarkdown(String raw) {
    final lines = const LineSplitter().convert(raw);
    var meta = <String, String>{};
    var contentStart = 0;

    if (lines.isNotEmpty && lines.first.trim() == '---') {
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          meta = _parseMemoFlowFrontMatter(lines.sublist(1, i));
          contentStart = i + 1;
          break;
        }
      }
    }

    var contentLines = contentStart > 0 ? lines.sublist(contentStart) : lines;
    if (contentStart > 0 &&
        contentLines.isNotEmpty &&
        contentLines.first.trim().isEmpty) {
      contentLines = contentLines.sublist(1);
    }

    final content = contentLines.join('\n');
    final uid = (meta['uid'] ?? '').trim();
    final created = _parseMemoFlowTime(meta['created'], DateTime.now());
    final updated = _parseMemoFlowTime(meta['updated'], created);
    final visibility = _normalizeMemoFlowVisibility(meta['visibility']);
    final pinned = _parseMemoFlowBool(meta['pinned']);
    final state = _normalizeMemoFlowState(meta['state']);
    final tags = _parseMemoFlowTags(meta['tags']);

    return _MemoFlowParsedMemo(
      uid: uid,
      content: content,
      createTime: created,
      updateTime: updated,
      visibility: visibility,
      pinned: pinned,
      state: state,
      tags: tags,
    );
  }

  Map<String, String> _parseMemoFlowFrontMatter(List<String> lines) {
    final out = <String, String>{};
    for (final line in lines) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim().toLowerCase();
      final value = line.substring(idx + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      out[key] = value;
    }
    return out;
  }

  DateTime _parseMemoFlowTime(String? raw, DateTime fallback) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return fallback;
    return DateTime.tryParse(value) ?? fallback;
  }

  bool _parseMemoFlowBool(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return value == 'true' || value == '1' || value == 'yes';
  }

  String _normalizeMemoFlowVisibility(String? raw) {
    final value = raw?.trim().toUpperCase() ?? '';
    return switch (value) {
      'PUBLIC' || 'PROTECTED' || 'PRIVATE' => value,
      _ => 'PRIVATE',
    };
  }

  String _normalizeMemoFlowState(String? raw) {
    final value = raw?.trim().toUpperCase() ?? '';
    return switch (value) {
      'ARCHIVED' || 'NORMAL' => value,
      _ => 'NORMAL',
    };
  }

  List<String> _parseMemoFlowTags(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return const [];
    final tags = <String>{};
    for (final part in value.split(RegExp(r'\s+'))) {
      var t = part.trim();
      if (t.startsWith('#')) {
        t = t.substring(1);
      }
      if (t.endsWith(',')) {
        t = t.substring(0, t.length - 1);
      }
      if (t.isNotEmpty) {
        tags.add(t);
      }
    }
    final list = tags.toList(growable: false);
    list.sort();
    return list;
  }

  List<_ParsedMemo> _parseFlomoHtml(String html, String htmlRootPath) {
    final document = html_parser.parse(html);
    final memoNodes = document.querySelectorAll('.memo');
    if (memoNodes.isEmpty) return const [];

    final results = <_ParsedMemo>[];
    for (final memo in memoNodes) {
      final timeText = memo.querySelector('.time')?.text.trim() ?? '';
      final createTime = _parseTime(timeText);

      final contentEl = memo.querySelector('.content');
      var content = contentEl == null ? '' : _htmlToPlainText(contentEl).trim();

      final transcriptNodes = memo.querySelectorAll('.audio-player__content');
      final transcript = transcriptNodes
          .map((e) => e.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n');
      if (transcript.isNotEmpty) {
        content = content.isEmpty ? transcript : '$content\n\n$transcript';
      }

      final attachments = _extractAttachments(memo, htmlRootPath);

      results.add(
        _ParsedMemo(
          createTime: createTime,
          content: content,
          attachments: attachments,
        ),
      );
    }
    return results;
  }

  List<_ParsedAttachment> _extractAttachments(
    dom.Element memo,
    String htmlRootPath,
  ) {
    final files = memo.querySelector('.files');
    if (files == null) return const [];

    final attachments = <_ParsedAttachment>[];
    final seen = <String>{};

    void addPath(String? raw) {
      final normalized = _normalizeRelativePath(raw);
      if (normalized == null) return;
      final resolved = p.normalize(p.join(htmlRootPath, normalized));
      if (!p.isWithin(htmlRootPath, resolved)) return;
      if (seen.contains(resolved)) return;
      final file = File(resolved);
      if (!file.existsSync()) return;

      final filename = p.basename(resolved);
      attachments.add(
        _ParsedAttachment(
          localPath: resolved,
          filename: filename,
          mimeType: _guessMimeType(filename),
          size: file.lengthSync(),
          externalLink: Uri.file(resolved).toString(),
        ),
      );
      seen.add(resolved);
    }

    for (final audio in files.querySelectorAll('audio')) {
      addPath(audio.attributes['src']);
    }
    for (final img in files.querySelectorAll('img')) {
      addPath(img.attributes['src']);
    }
    for (final link in files.querySelectorAll('a')) {
      addPath(link.attributes['href']);
    }

    return attachments;
  }

  String? _normalizeRelativePath(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:')) {
      return null;
    }
    final queryIndex = value.indexOf('?');
    if (queryIndex != -1) value = value.substring(0, queryIndex);
    final hashIndex = value.indexOf('#');
    if (hashIndex != -1) value = value.substring(0, hashIndex);
    value = value.replaceAll('\\', '/');
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    return value.isEmpty ? null : value;
  }

  DateTime _parseTime(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    try {
      return fmt.parse(trimmed);
    } catch (_) {
      return DateTime.tryParse(trimmed) ?? DateTime.now();
    }
  }

  String _htmlToPlainText(dom.Element root) {
    final blocks = <String>[];

    void addBlock(String text) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;
      blocks.add(trimmed);
    }

    for (final node in root.nodes) {
      if (node is dom.Element) {
        final tag = node.localName ?? '';
        switch (tag) {
          case 'p':
            addBlock(_renderInline(node));
            break;
          case 'ul':
          case 'ol':
            final items = node
                .querySelectorAll('li')
                .map(_renderInline)
                .where((e) => e.trim().isNotEmpty)
                .toList();
            if (items.isNotEmpty) {
              addBlock(items.map((e) => '- $e').join('\n'));
            }
            break;
          case 'br':
            addBlock('');
            break;
          default:
            addBlock(_renderInline(node));
            break;
        }
      } else if (node is dom.Text) {
        addBlock(node.text);
      }
    }

    if (blocks.isEmpty) {
      final fallback = root.text.trim();
      if (fallback.isNotEmpty) return fallback;
    }
    return blocks.join('\n\n');
  }

  String _renderInline(dom.Node node) {
    if (node is dom.Text) return node.text;
    if (node is dom.Element) {
      final tag = node.localName ?? '';
      if (tag == 'br') return '\n';
      if (tag == 'a') {
        final text = node.text.trim();
        final href = node.attributes['href'];
        if (href == null || href.trim().isEmpty) return text;
        if (text.isEmpty) return href;
        if (text.contains(href)) return text;
        return '$text $href';
      }
      return node.nodes.map(_renderInline).join();
    }
    return '';
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot == -1 ? '' : lower.substring(dot + 1);
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      '7z' => 'application/x-7z-compressed',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'log' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  void _reportQueueProgress(
    ImportProgressCallback onProgress,
    int processed,
    int total,
  ) {
    final ratio = total == 0 ? 1.0 : processed / total;
    final progress = 0.3 + (0.6 * ratio);
    _reportProgress(
      onProgress,
      progress: progress,
      statusText: trByLanguageKey(
        language: language,
        key: 'legacy.msg_importing_memos',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_importing',
      ),
      progressDetail: trByLanguageKey(
        language: language,
        key: 'legacy.msg_processing',
        params: {'processed': processed, 'total': total},
      ),
    );
  }

  void _reportProgress(
    ImportProgressCallback onProgress, {
    required double progress,
    String? statusText,
    String? progressLabel,
    String? progressDetail,
  }) {
    onProgress(
      ImportProgressUpdate(
        progress: progress,
        statusText: statusText,
        progressLabel: progressLabel,
        progressDetail: progressDetail,
      ),
    );
  }

  void _ensureNotCancelled(ImportCancelCheck isCancelled) {
    if (isCancelled()) {
      throw const ImportCancelled();
    }
  }
}

class _MemoFlowArchiveAttachment {
  const _MemoFlowArchiveAttachment({
    required this.memoUid,
    required this.filename,
    required this.archivePath,
  });

  final String memoUid;
  final String filename;
  final String archivePath;
}

class _MemoFlowParsedMemo {
  const _MemoFlowParsedMemo({
    required this.uid,
    required this.content,
    required this.createTime,
    required this.updateTime,
    required this.visibility,
    required this.pinned,
    required this.state,
    required this.tags,
  });

  final String uid;
  final String content;
  final DateTime createTime;
  final DateTime updateTime;
  final String visibility;
  final bool pinned;
  final String state;
  final List<String> tags;
}

class _ParsedMemo {
  const _ParsedMemo({
    required this.createTime,
    required this.content,
    required this.attachments,
  });

  final DateTime createTime;
  final String content;
  final List<_ParsedAttachment> attachments;
}

class _ParsedAttachment {
  const _ParsedAttachment({
    required this.localPath,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.externalLink,
  });

  final String localPath;
  final String filename;
  final String mimeType;
  final int size;
  final String externalLink;
}

class _QueuedAttachment {
  const _QueuedAttachment({
    required this.uid,
    required this.memoUid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String uid;
  final String memoUid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}

class _ImportCounters {
  const _ImportCounters({
    required this.memoCount,
    required this.setMemoCount,
    required this.attachmentCount,
    required this.setAttachmentCount,
    required this.failedCount,
    required this.setFailedCount,
  });

  final int Function() memoCount;
  final void Function(int) setMemoCount;
  final int Function() attachmentCount;
  final void Function(int) setAttachmentCount;
  final int Function() failedCount;
  final void Function(int) setFailedCount;
}
