import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../application/attachments/queued_attachment_stager.dart';
import '../../core/app_localization.dart';
import '../../core/debug_ephemeral_storage.dart';
import '../../core/hash.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/api/memo_api_version.dart';
import '../../data/models/account.dart';
import '../../data/models/app_preferences.dart';
import 'create_memo_outbox_enqueue.dart';
import 'flomo_import_models.dart';
import 'flomo_import_mutation_service.dart';
import 'memo_sync_constraints.dart';

enum _BackendVersion { v025, v024, v021, unknown }

typedef GenericMarkdownImportDatabase = FlomoImportDatabase;

class GenericMarkdownImportController {
  const GenericMarkdownImportController();

  Future<ImportResult> importArchive({
    required GenericMarkdownImportDatabase db,
    required AppLanguage language,
    Account? account,
    String? importScopeKey,
    TagRecognitionPolicy tagRecognitionPolicy =
        TagRecognitionPolicy.defaultPolicy,
    required String filePath,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
  }) async {
    final engine = _GenericMarkdownImportEngine(
      db: db,
      language: language,
      account: account,
      importScopeKey: importScopeKey,
      tagRecognitionPolicy: tagRecognitionPolicy,
    );
    return engine.importFile(
      filePath: filePath,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }
}

class _GenericMarkdownImportEngine {
  _GenericMarkdownImportEngine({
    required this.db,
    required this.language,
    this.account,
    this.importScopeKey,
    this.tagRecognitionPolicy = TagRecognitionPolicy.defaultPolicy,
  });

  final GenericMarkdownImportDatabase db;
  final Account? account;
  final String? importScopeKey;
  final AppLanguage language;
  final TagRecognitionPolicy tagRecognitionPolicy;
  final QueuedAttachmentStager _queuedAttachmentStager =
      QueuedAttachmentStager();
  late final FlomoImportMutationService _mutationService =
      FlomoImportMutationService(db: db);

  static const _source = 'generic_markdown';
  static const _documentsDirName = 'imports';

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

    if (_shouldCheckBackendVersion()) {
      final backend = await _detectBackendVersion();
      if (backend == _BackendVersion.unknown) {
        throw ImportException(
          trByLanguageKey(
            language: language,
            key: 'legacy.msg_unable_detect_backend_version_check_server',
          ),
        );
      }
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

    final historyId = await _mutationService.beginImportHistory(
      source: _source,
      fileMd5: fileMd5,
      fileName: p.basename(filePath),
    );

    var memoCount = 0;
    var attachmentCount = 0;
    var failedCount = 0;

    try {
      final result = await _importZipBytes(
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
      await _mutationService.completeImportHistory(
        historyId: historyId,
        memoCount: result.memoCount,
        attachmentCount: result.attachmentCount,
        failedCount: result.failedCount,
      );
      await _writeImportMarker(fileMd5, p.basename(filePath));
      return result;
    } catch (e) {
      final message = e is ImportException ? e.message : e.toString();
      await _mutationService.failImportHistory(
        historyId: historyId,
        memoCount: memoCount,
        attachmentCount: attachmentCount,
        failedCount: failedCount,
        error: message,
      );
      await _deleteImportMarker(fileMd5);
      rethrow;
    }
  }

  Future<ImportResult> _importZipBytes({
    required String filePath,
    required List<int> bytes,
    required String fileMd5,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
    required _ImportCounters counters,
  }) async {
    if (!filePath.toLowerCase().endsWith('.zip')) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_unsupported_file_type',
        ),
      );
    }

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
    final markdownEntries = _genericMarkdownEntries(archive);
    if (markdownEntries.isEmpty) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_no_generic_markdown_files_found_zip',
        ),
      );
    }

    final importRoot = await _resolveImportRoot(fileMd5);
    await _extractArchiveSafely(archive, importRoot);

    final existingTags = await _loadExistingTags();
    final importedTags = <String>{};
    final total = markdownEntries.length;
    var processed = 0;

    for (final entry in markdownEntries) {
      _ensureNotCancelled(isCancelled);
      processed += 1;

      final parsed = _parseMarkdownEntry(entry, importRoot: importRoot);
      if (parsed.content.trim().isEmpty && parsed.attachments.isEmpty) {
        counters.setFailedCount(counters.failedCount() + 1);
        _reportQueueProgress(onProgress, processed, total);
        continue;
      }

      importedTags.addAll(parsed.tags);
      final queuedAttachmentCount = await _persistParsedMemo(parsed);
      counters.setAttachmentCount(
        counters.attachmentCount() + queuedAttachmentCount,
      );
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

  Future<int> _persistParsedMemo(_ParsedGenericMarkdownMemo parsed) async {
    final attachmentPayloads = await _queuedAttachmentStager
        .stageUploadPayloads(
          parsed.attachments
              .map(
                (attachment) => <String, dynamic>{
                  'uid': attachment.uid,
                  'memo_uid': parsed.memoUid,
                  'file_path': attachment.filePath,
                  'filename': attachment.filename,
                  'mime_type': attachment.mimeType,
                  'file_size': attachment.size,
                },
              )
              .toList(growable: false),
          scopeKey: parsed.memoUid,
        );

    final attachments = mergePendingAttachmentPlaceholders(
      attachments: const <Map<String, dynamic>>[],
      pendingAttachments: attachmentPayloads,
    );

    final allowed = await guardMemoContentForRemoteSync(
      db: db,
      enabled: account != null,
      memoUid: parsed.memoUid,
      content: parsed.content,
    );

    return _mutationService.persistImportedMemo(
      memoUid: parsed.memoUid,
      content: parsed.content,
      visibility: parsed.visibility,
      pinned: parsed.pinned,
      state: 'NORMAL',
      createTimeSec: parsed.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: parsed.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: parsed.tags,
      attachments: attachments,
      location: null,
      relationCount: 0,
      allowRemoteSync: allowed,
      uploadBeforeCreate: _shouldEnqueueAttachmentUploadsBeforeCreate(),
      attachmentPayloads: attachmentPayloads,
    );
  }

  _ParsedGenericMarkdownMemo _parseMarkdownEntry(
    ArchiveFile entry, {
    required Directory importRoot,
  }) {
    final raw = utf8.decode(_readArchiveBytes(entry), allowMalformed: true);
    final frontMatter = _parseMarkdownFrontMatter(raw);
    final markdownBody = frontMatter?.body ?? raw;
    final resourceUris = _orderedResourceUris(markdownBody);
    final attachments = _resolveAttachments(
      resourceUris,
      importRoot: importRoot,
      markdownArchivePath: entry.name,
    );
    final content = _sanitizeMarkdownContent(
      markdownBody,
      importRoot: importRoot,
      markdownArchivePath: entry.name,
    ).trim();
    final tags = deriveVisibleMemoTags(
      content: content,
      remoteTags: frontMatter?.tags ?? const <String>[],
      policy: tagRecognitionPolicy,
    );
    final fallbackTime = _archiveEntryTime(entry);
    final createTime = frontMatter?.created ?? fallbackTime;
    final updateTime = frontMatter?.updated ?? createTime;

    return _ParsedGenericMarkdownMemo(
      memoUid: generateUid(),
      content: content,
      createTime: createTime,
      updateTime: updateTime,
      pinned: frontMatter?.pinned ?? false,
      visibility: frontMatter?.visibility ?? 'PRIVATE',
      tags: tags,
      attachments: attachments,
    );
  }

  _MarkdownFrontMatter? _parseMarkdownFrontMatter(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('---\n')) {
      return null;
    }
    final end = normalized.indexOf('\n---\n', 4);
    if (end == -1) {
      return null;
    }
    final header = normalized.substring(4, end);
    final body = normalized.substring(end + 5);
    DateTime? created;
    DateTime? updated;
    bool? pinned;
    String? visibility;
    final tags = <String>{};

    for (final rawLine in header.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final split = line.indexOf(':');
      if (split <= 0) continue;
      final key = line.substring(0, split).trim().toLowerCase();
      final value = line.substring(split + 1).trim();
      switch (key) {
        case 'created':
          created = DateTime.tryParse(value)?.toLocal() ?? created;
        case 'updated':
          updated = DateTime.tryParse(value)?.toLocal() ?? updated;
        case 'pinned':
          pinned = _parseBool(value);
        case 'visibility':
          visibility = _normalizeVisibility(value);
        case 'tags':
          tags.addAll(_parseFrontMatterTags(value));
      }
    }

    return _MarkdownFrontMatter(
      body: body,
      created: created,
      updated: updated,
      pinned: pinned,
      visibility: visibility,
      tags: tags.toList(growable: false)..sort(),
    );
  }

  List<String> _orderedResourceUris(String content) {
    final uris = <String>[];
    final seen = <String>{};

    void addUri(String? raw) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty || !seen.add(value)) return;
      uris.add(value);
    }

    for (final match in _markdownImagePattern.allMatches(content)) {
      addUri(match.group(1));
    }
    for (final match in _markdownLinkPattern.allMatches(content)) {
      addUri(match.group(3));
    }
    for (final match in _htmlImagePattern.allMatches(content)) {
      addUri(match.group(1));
    }
    for (final match in _htmlAudioVideoPattern.allMatches(content)) {
      addUri(match.group(2));
    }

    return uris;
  }

  List<_QueuedAttachment> _resolveAttachments(
    List<String> resourceUris, {
    required Directory importRoot,
    required String markdownArchivePath,
  }) {
    final attachments = <_QueuedAttachment>[];
    final seen = <String>{};
    for (final uri in resourceUris) {
      final localPath = _resolveAttachmentResourcePath(
        importRoot: importRoot,
        markdownArchivePath: markdownArchivePath,
        uri: uri,
      );
      if (localPath == null || !seen.add(localPath)) continue;
      final file = File(localPath);
      if (!file.existsSync()) continue;
      final filename = p.basename(localPath);
      attachments.add(
        _QueuedAttachment(
          uid: generateUid(),
          filePath: localPath,
          filename: filename,
          mimeType: _guessMimeType(filename),
          size: file.lengthSync(),
        ),
      );
    }
    return attachments;
  }

  String _sanitizeMarkdownContent(
    String raw, {
    required Directory importRoot,
    required String markdownArchivePath,
  }) {
    var content = raw.replaceAll('\r\n', '\n');

    bool resolves(String? target) {
      if (target == null) return false;
      return _resolveAttachmentResourcePath(
            importRoot: importRoot,
            markdownArchivePath: markdownArchivePath,
            uri: target,
          ) !=
          null;
    }

    content = content.replaceAllMapped(_markdownImagePattern, (match) {
      return resolves(match.group(1)) ? '' : match.group(0)!;
    });
    content = content.replaceAllMapped(_markdownLinkPattern, (match) {
      final prefix = match.group(1) ?? '';
      final label = match.group(2) ?? '';
      return resolves(match.group(3)) ? '$prefix$label' : match.group(0)!;
    });
    content = content.replaceAllMapped(_htmlImagePattern, (match) {
      return resolves(match.group(1)) ? '' : match.group(0)!;
    });
    content = content.replaceAllMapped(_htmlAudioVideoPattern, (match) {
      return resolves(match.group(2)) ? '' : match.group(0)!;
    });

    final lines = content.split('\n');
    final kept = <String>[];
    var previousBlank = false;
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final isBlank = line.trim().isEmpty;
      if (isBlank) {
        if (!previousBlank) kept.add('');
        previousBlank = true;
        continue;
      }
      kept.add(line);
      previousBlank = false;
    }
    return kept.join('\n').trim();
  }

  String? _resolveAttachmentResourcePath({
    required Directory importRoot,
    required String markdownArchivePath,
    required String uri,
  }) {
    final localPath = _resolveResourcePath(
      importRoot: importRoot,
      markdownArchivePath: markdownArchivePath,
      uri: uri,
    );
    if (localPath == null || _isMarkdownFilePath(localPath)) return null;
    return localPath;
  }

  String? _resolveResourcePath({
    required Directory importRoot,
    required String markdownArchivePath,
    required String uri,
  }) {
    final normalizedUri = _normalizeLocalResourceUri(uri);
    if (normalizedUri == null) return null;
    final markdownDir = p.dirname(_normalizeArchivePath(markdownArchivePath));
    final candidates = <String>[
      if (markdownDir != '.')
        p.normalize(
          p.join(
            importRoot.path,
            markdownDir.replaceAll('/', p.separator),
            normalizedUri.replaceAll('/', p.separator),
          ),
        ),
      p.normalize(
        p.join(importRoot.path, normalizedUri.replaceAll('/', p.separator)),
      ),
      p.normalize(
        p.join(
          importRoot.path,
          'assets',
          normalizedUri.replaceAll('/', p.separator),
        ),
      ),
    ];

    for (final candidate in candidates) {
      if (!p.isWithin(importRoot.path, candidate)) continue;
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  bool _isMarkdownFilePath(String path) {
    return p.extension(path).toLowerCase() == '.md';
  }

  String? _normalizeLocalResourceUri(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('<') && value.endsWith('>')) {
      value = value.substring(1, value.length - 1).trim();
    }
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:') ||
        lower.startsWith('mailto:')) {
      return null;
    }
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) return null;
    final queryIndex = value.indexOf('?');
    if (queryIndex != -1) value = value.substring(0, queryIndex);
    final hashIndex = value.indexOf('#');
    if (hashIndex != -1) value = value.substring(0, hashIndex);
    value = value.replaceAll('\\', '/');
    try {
      value = Uri.decodeFull(value);
    } catch (_) {
      // Keep the original text if it is not valid percent-encoding.
    }
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    if (value.isEmpty) return null;
    final segments = value.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.any((segment) => segment == '..')) return null;
    return segments.join('/');
  }

  List<ArchiveFile> _genericMarkdownEntries(Archive archive) {
    final entries = <ArchiveFile>[];
    for (final file in archive.files) {
      if (_isGenericMarkdownEntry(file)) entries.add(file);
    }
    entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  bool _isGenericMarkdownEntry(ArchiveFile file) {
    if (!file.isFile) return false;
    final normalized = _normalizeArchivePath(file.name);
    final lower = normalized.toLowerCase();
    if (!lower.endsWith('.md')) return false;
    final segments = lower.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;
    if (segments.length > 1 &&
        segments.take(segments.length - 1).any(_isExcludedDirectorySegment)) {
      return false;
    }
    return true;
  }

  bool _isExcludedDirectorySegment(String segment) {
    return segment == 'assets' ||
        segment == '.obsidian' ||
        segment == '.git' ||
        segment == '__macosx' ||
        segment.startsWith('.');
  }

  String _normalizeArchivePath(String raw) {
    var normalized = raw.replaceAll('\\', '/');
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }

  DateTime _archiveEntryTime(ArchiveFile entry) {
    final time = entry.lastModDateTime;
    return time.year < 1980 ? DateTime.now() : time;
  }

  List<int> _readArchiveBytes(ArchiveFile file) => file.content;

  Future<void> _extractArchiveSafely(Archive archive, Directory target) async {
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final outPath = p.normalize(p.join(target.path, file.name));
      if (!p.isWithin(target.path, outPath)) continue;
      final parent = Directory(p.dirname(outPath));
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      await File(outPath).writeAsBytes(_readArchiveBytes(file), flush: true);
    }
  }

  Future<Directory> _resolveImportRoot(
    String fileMd5, {
    bool create = true,
  }) async {
    final base = await resolveAppDocumentsDirectory();
    final accountKey = account?.key.trim() ?? '';
    final workspaceKey = (importScopeKey ?? '').trim();
    final baseUrl = account?.baseUrl.toString().trim() ?? '';
    final key = accountKey.isNotEmpty
        ? accountKey
        : (workspaceKey.isNotEmpty
              ? workspaceKey
              : (baseUrl.isNotEmpty ? baseUrl : 'local'));
    final accountHash = fnv1a64Hex(key);
    final dir = Directory(
      p.join(base.path, _documentsDirName, _source, accountHash, fileMd5),
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

  Future<Set<String>> _loadExistingTags() async {
    final tags = await db.listTagStrings(state: 'NORMAL');
    final out = <String>{};
    for (final line in tags) {
      for (final tag in line.split(' ')) {
        final normalized = normalizeTagPath(tag);
        if (normalized.isNotEmpty) out.add(normalized);
      }
    }
    return out;
  }

  Future<_BackendVersion> _detectBackendVersion() async {
    final currentAccount = account;
    if (currentAccount == null) {
      return _BackendVersion.unknown;
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: dioBaseUrlString(currentAccount.baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, Object?>{
          'Authorization': 'Bearer ${currentAccount.personalAccessToken}',
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

  bool _shouldCheckBackendVersion() {
    final currentAccount = account;
    if (currentAccount == null) return false;
    if (currentAccount.personalAccessToken.trim().isEmpty) return false;
    return currentAccount.baseUrl.toString().trim().isNotEmpty;
  }

  bool _shouldEnqueueAttachmentUploadsBeforeCreate() {
    final rawVersion =
        (account?.serverVersionOverride ??
                account?.instanceProfile.version ??
                '')
            .trim();
    final version = parseMemoApiVersion(rawVersion);
    return switch (version) {
      MemoApiVersion.v023 ||
      MemoApiVersion.v024 ||
      MemoApiVersion.v025 ||
      MemoApiVersion.v026 ||
      MemoApiVersion.v027 ||
      MemoApiVersion.v028 ||
      MemoApiVersion.v029 => true,
      _ => false,
    };
  }

  bool _parseBool(String value) {
    final lower = value.trim().toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }

  String _normalizeVisibility(String value) {
    final upper = value.trim().toUpperCase();
    return switch (upper) {
      'PUBLIC' || 'PROTECTED' || 'PRIVATE' => upper,
      _ => 'PRIVATE',
    };
  }

  List<String> _parseFrontMatterTags(String raw) {
    var value = raw.trim();
    if (value.startsWith('[') && value.endsWith(']')) {
      value = value.substring(1, value.length - 1);
    }
    final tags = <String>{};
    for (final part in value.split(RegExp(r'[\s,]+'))) {
      final normalized = normalizeTagPath(part);
      if (normalized.isNotEmpty) tags.add(normalized);
    }
    final list = tags.toList(growable: false);
    list.sort();
    return list;
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

final RegExp _markdownImagePattern = RegExp(
  r'!\[[^\]]*\]\(([^)]+)\)',
  caseSensitive: false,
);
final RegExp _markdownLinkPattern = RegExp(
  r'(^|[^!])\[([^\]]*)\]\(([^)]+)\)',
  caseSensitive: false,
  multiLine: true,
);
final RegExp _htmlImagePattern = RegExp(
  """<img\\b[^>]*\\bsrc=["']([^"']+)["'][^>]*/?>""",
  caseSensitive: false,
);
final RegExp _htmlAudioVideoPattern = RegExp(
  """<(audio|video)\\b[^>]*\\bsrc=["']([^"']+)["'][^>]*(?:>.*?</\\1>|/?>)""",
  caseSensitive: false,
  dotAll: true,
);

class _ParsedGenericMarkdownMemo {
  const _ParsedGenericMarkdownMemo({
    required this.memoUid,
    required this.content,
    required this.createTime,
    required this.updateTime,
    required this.pinned,
    required this.visibility,
    required this.tags,
    required this.attachments,
  });

  final String memoUid;
  final String content;
  final DateTime createTime;
  final DateTime updateTime;
  final bool pinned;
  final String visibility;
  final List<String> tags;
  final List<_QueuedAttachment> attachments;
}

class _QueuedAttachment {
  const _QueuedAttachment({
    required this.uid,
    required this.filePath,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String uid;
  final String filePath;
  final String filename;
  final String mimeType;
  final int size;
}

class _MarkdownFrontMatter {
  const _MarkdownFrontMatter({
    required this.body,
    required this.tags,
    this.created,
    this.updated,
    this.pinned,
    this.visibility,
  });

  final String body;
  final DateTime? created;
  final DateTime? updated;
  final bool? pinned;
  final String? visibility;
  final List<String> tags;
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
