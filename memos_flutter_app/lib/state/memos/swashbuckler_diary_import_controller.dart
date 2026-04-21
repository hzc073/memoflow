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
import '../../core/memo_content_diagnostics.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../core/url.dart';
import '../../data/api/memo_api_version.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/account.dart';
import '../../data/models/app_preferences.dart';
import 'create_memo_outbox_enqueue.dart';
import 'flomo_import_models.dart';
import 'flomo_import_mutation_service.dart';
import 'memo_sync_constraints.dart';

enum _BackendVersion { v025, v024, v021, unknown }

class SwashbucklerDiaryImportController {
  const SwashbucklerDiaryImportController();

  Future<ImportResult> importArchive({
    required SwashbucklerDiaryImportDatabase db,
    required AppLanguage language,
    Account? account,
    String? importScopeKey,
    required String filePath,
    required ImportProgressCallback onProgress,
    required ImportCancelCheck isCancelled,
  }) async {
    final engine = _SwashbucklerDiaryImportEngine(
      db: db,
      language: language,
      account: account,
      importScopeKey: importScopeKey,
    );
    return engine.importFile(
      filePath: filePath,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }
}

typedef SwashbucklerDiaryImportDatabase = FlomoImportDatabase;

class _SwashbucklerDiaryImportEngine {
  _SwashbucklerDiaryImportEngine({
    required this.db,
    required this.language,
    this.account,
    this.importScopeKey,
  });

  final SwashbucklerDiaryImportDatabase db;
  final Account? account;
  final String? importScopeKey;
  final AppLanguage language;
  final QueuedAttachmentStager _queuedAttachmentStager =
      QueuedAttachmentStager();
  late final FlomoImportMutationService _mutationService =
      FlomoImportMutationService(db: db);

  static const _source = 'swashbuckler_diary';
  static const _documentsDirName = 'imports';
  static const _versionFileName = 'version.json';
  static const _settingsFileName = 'settings.json';

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
    if (_containsMemoFlowStructure(archive)) {
      throw ImportException(
        trByLanguageKey(
          language: language,
          key: 'legacy.msg_unsupported_file_type',
        ),
      );
    }

    final importRoot = await _resolveImportRoot(fileMd5);
    await _extractArchiveSafely(archive, importRoot);

    final jsonEntries = _swashbucklerDiaryJsonEntries(archive);
    if (jsonEntries.isNotEmpty) {
      return _importJsonExport(
        archiveEntries: jsonEntries,
        importRoot: importRoot,
        onProgress: onProgress,
        isCancelled: isCancelled,
        counters: counters,
      );
    }

    final markdownEntries = _swashbucklerDiaryMarkdownEntries(archive);
    if (markdownEntries.isNotEmpty) {
      return _importMarkdownExport(
        archiveEntries: markdownEntries,
        importRoot: importRoot,
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

  Future<ImportResult> _importJsonExport({
    required List<ArchiveFile> archiveEntries,
    required Directory importRoot,
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
        key: 'legacy.msg_parsing',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_parsing',
      ),
      progressDetail: 'SwashbucklerDiary JSON',
    );

    final existingTags = await _loadExistingTags();
    final importedTags = <String>{};
    final total = archiveEntries.length;
    var processed = 0;

    for (final entry in archiveEntries) {
      _ensureNotCancelled(isCancelled);
      processed += 1;

      final parsed = _parseJsonDiaryEntry(entry, importRoot: importRoot);
      if (parsed == null ||
          (parsed.content.trim().isEmpty && parsed.attachments.isEmpty)) {
        counters.setFailedCount(counters.failedCount() + 1);
        _reportQueueProgress(onProgress, processed, total);
        continue;
      }
      _logImportedMemoDiagnostics(
        sourceFile: entry.name,
        parsed: parsed,
        kind: 'json',
      );

      importedTags.addAll(parsed.tags);
      final queuedAttachmentCount = await _persistParsedMemo(parsed);
      counters.setAttachmentCount(
        counters.attachmentCount() + queuedAttachmentCount,
      );
      counters.setMemoCount(counters.memoCount() + 1);
      _reportQueueProgress(onProgress, processed, total);
    }

    return _finishImport(
      onProgress: onProgress,
      counters: counters,
      existingTags: existingTags,
      importedTags: importedTags,
    );
  }

  Future<ImportResult> _importMarkdownExport({
    required List<ArchiveFile> archiveEntries,
    required Directory importRoot,
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
        key: 'legacy.msg_parsing',
      ),
      progressLabel: trByLanguageKey(
        language: language,
        key: 'legacy.msg_parsing',
      ),
      progressDetail: 'SwashbucklerDiary Markdown/TXT',
    );

    final existingTags = await _loadExistingTags();
    final importedTags = <String>{};
    final total = archiveEntries.length;
    var processed = 0;

    for (final entry in archiveEntries) {
      _ensureNotCancelled(isCancelled);
      processed += 1;

      final parsed = _parseMarkdownDiaryEntry(entry, importRoot: importRoot);
      if (parsed == null ||
          (parsed.content.trim().isEmpty && parsed.attachments.isEmpty)) {
        counters.setFailedCount(counters.failedCount() + 1);
        _reportQueueProgress(onProgress, processed, total);
        continue;
      }
      _logImportedMemoDiagnostics(
        sourceFile: entry.name,
        parsed: parsed,
        kind: 'markdown',
      );

      importedTags.addAll(parsed.tags);
      final queuedAttachmentCount = await _persistParsedMemo(parsed);
      counters.setAttachmentCount(
        counters.attachmentCount() + queuedAttachmentCount,
      );
      counters.setMemoCount(counters.memoCount() + 1);
      _reportQueueProgress(onProgress, processed, total);
    }

    return _finishImport(
      onProgress: onProgress,
      counters: counters,
      existingTags: existingTags,
      importedTags: importedTags,
    );
  }

  Future<int> _persistParsedMemo(_ParsedDiaryMemo parsed) async {
    final memoUid = parsed.memoUid;
    final attachmentPayloads = await _queuedAttachmentStager
        .stageUploadPayloads(
          parsed.attachments
              .map(
                (attachment) => <String, dynamic>{
                  'uid': attachment.uid,
                  'memo_uid': memoUid,
                  'file_path': attachment.filePath,
                  'filename': attachment.filename,
                  'mime_type': attachment.mimeType,
                  'file_size': attachment.size,
                },
              )
              .toList(growable: false),
          scopeKey: memoUid,
        );

    final attachments = mergePendingAttachmentPlaceholders(
      attachments: const <Map<String, dynamic>>[],
      pendingAttachments: attachmentPayloads,
    );

    final allowed = await guardMemoContentForRemoteSync(
      db: db,
      enabled: account != null,
      memoUid: memoUid,
      content: parsed.content,
    );

    return _mutationService.persistImportedMemo(
      memoUid: memoUid,
      content: parsed.content,
      visibility: 'PRIVATE',
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

  _ParsedDiaryMemo? _parseJsonDiaryEntry(
    ArchiveFile entry, {
    required Directory importRoot,
  }) {
    final raw = utf8.decode(_readArchiveBytes(entry), allowMalformed: true);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final map = _normalizeMap(decoded);
    if (!_looksLikeDiaryJson(map)) return null;

    final title = _readString(map, 'title');
    final body = _readString(map, 'content');
    final mood = _readString(map, 'mood');
    final weather = _readString(map, 'weather');
    final location = _readString(map, 'location');

    final sanitizedBody = _sanitizeDiaryContent(body);
    final content = _composeDiaryContent(
      title: title,
      mood: mood,
      weather: weather,
      location: location,
      body: sanitizedBody,
    );

    final tags = <String>{
      ..._readTagNames(map),
      ...extractTags(sanitizedBody),
      ...extractTags(content),
    }.toList(growable: false)..sort();

    final resourceUris = _orderedResourceUris(
      content: body,
      declaredUris: _readResourceUris(map),
    );

    final createTime =
        _readDateTime(map, 'createtime') ??
        _fallbackDateFromBasename(entry.name);
    final updateTime = _readDateTime(map, 'updatetime') ?? createTime;

    return _ParsedDiaryMemo(
      memoUid: generateUid(),
      content: content,
      createTime: createTime,
      updateTime: updateTime,
      pinned: _readBool(map, 'top'),
      tags: tags,
      attachments: _resolveAttachments(resourceUris, importRoot),
    );
  }

  _ParsedDiaryMemo? _parseMarkdownDiaryEntry(
    ArchiveFile entry, {
    required Directory importRoot,
  }) {
    final raw = utf8.decode(_readArchiveBytes(entry), allowMalformed: true);
    final frontMatter = _parseMarkdownFrontMatter(raw);
    final markdownBody = frontMatter?.body ?? raw;
    final content = _sanitizeDiaryContent(markdownBody).trim();
    final tags = <String>{...extractTags(content)}.toList(growable: false)
      ..sort();
    final resourceUris = _orderedResourceUris(
      content: markdownBody,
      declaredUris: const [],
    );
    final createTime =
        frontMatter?.created ??
        _parseMarkdownDateTime(entry.name) ??
        _fallbackDateFromBasename(entry.name);
    final updateTime = frontMatter?.updated ?? createTime;

    return _ParsedDiaryMemo(
      memoUid: generateUid(),
      content: content,
      createTime: createTime,
      updateTime: updateTime,
      pinned: frontMatter?.pinned ?? false,
      tags: tags,
      attachments: _resolveAttachments(resourceUris, importRoot),
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
          pinned = value.toLowerCase() == 'true';
      }
    }

    return _MarkdownFrontMatter(
      body: body,
      created: created,
      updated: updated,
      pinned: pinned,
    );
  }

  List<String> _orderedResourceUris({
    required String content,
    required List<String> declaredUris,
  }) {
    final uris = <String>[];
    final seen = <String>{};

    void addUri(String raw) {
      final normalized = _normalizeResourceUri(raw);
      if (normalized == null || normalized.isEmpty || !seen.add(normalized)) {
        return;
      }
      uris.add(normalized);
    }

    for (final uri in declaredUris) {
      addUri(uri);
    }

    for (final match in _resourceUriPattern.allMatches(content)) {
      final value = match.group(0);
      if (value != null) {
        addUri(value);
      }
    }

    return uris;
  }

  List<_QueuedAttachment> _resolveAttachments(
    List<String> resourceUris,
    Directory importRoot,
  ) {
    final attachments = <_QueuedAttachment>[];
    for (final uri in resourceUris) {
      final localPath = _resolveResourcePath(importRoot, uri);
      if (localPath == null) continue;
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

  String? _resolveResourcePath(Directory importRoot, String uri) {
    final normalized = uri.replaceAll('\\', '/');
    final resolved = p.normalize(
      p.join(importRoot.path, normalized.replaceAll('/', p.separator)),
    );
    if (!p.isWithin(importRoot.path, resolved)) return null;
    return resolved;
  }

  String _composeDiaryContent({
    required String title,
    required String mood,
    required String weather,
    required String location,
    required String body,
  }) {
    final parts = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      parts.add(trimmedTitle);
    }

    final metaLines = <String>[];
    final trimmedMood = mood.trim();
    final trimmedWeather = weather.trim();
    final trimmedLocation = location.trim();
    if (trimmedMood.isNotEmpty) {
      metaLines.add('Mood: $trimmedMood');
    }
    if (trimmedWeather.isNotEmpty) {
      metaLines.add('Weather: $trimmedWeather');
    }
    if (trimmedLocation.isNotEmpty) {
      metaLines.add('Location: $trimmedLocation');
    }
    if (metaLines.isNotEmpty) {
      parts.add(metaLines.join('\n'));
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isNotEmpty) {
      parts.add(trimmedBody);
    }

    return parts.join('\n\n').trim();
  }

  String _sanitizeDiaryContent(String raw) {
    var content = raw.replaceAll('\r\n', '\n');

    content = content.replaceAllMapped(_resourceImagePattern, (match) {
      final target = match.group(1) ?? '';
      return _normalizeResourceUri(target) == null ? match.group(0)! : '';
    });

    content = content.replaceAllMapped(_resourceLinkPattern, (match) {
      final label = (match.group(1) ?? '').trim();
      final target = match.group(2) ?? '';
      if (_normalizeResourceUri(target) == null) {
        return match.group(0)!;
      }
      return label;
    });

    content = content.replaceAllMapped(_resourceMediaTagPattern, (match) {
      final target = (match.group(1) ?? '').trim();
      return _normalizeResourceUri(target) == null ? match.group(0)! : '';
    });

    final lines = content.split('\n');
    final kept = <String>[];
    var previousBlank = false;
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      final isBlank = trimmed.isEmpty;
      if (isBlank) {
        if (!previousBlank) {
          kept.add('');
        }
        previousBlank = true;
        continue;
      }

      if (_normalizeResourceUri(trimmed) != null) {
        continue;
      }

      kept.add(line);
      previousBlank = false;
    }

    return kept.join('\n').trim();
  }

  List<ArchiveFile> _swashbucklerDiaryJsonEntries(Archive archive) {
    final entries = <ArchiveFile>[];
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final lower = _normalizeArchivePath(file.name).toLowerCase();
      if (!lower.endsWith('.json')) continue;
      final base = p.basename(lower);
      if (base == _versionFileName || base == _settingsFileName) continue;
      final decoded = _tryDecodeJson(_readArchiveBytes(file));
      if (decoded is! Map) continue;
      if (_looksLikeDiaryJson(_normalizeMap(decoded))) {
        entries.add(file);
      }
    }
    entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  List<ArchiveFile> _swashbucklerDiaryMarkdownEntries(Archive archive) {
    final entries = <ArchiveFile>[];
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = _normalizeArchivePath(file.name);
      final lower = normalized.toLowerCase();
      if (!lower.endsWith('.md') && !lower.endsWith('.txt')) continue;
      final base = _stripDuplicateExportSuffix(
        p.basenameWithoutExtension(normalized),
      );
      if (_tryParseDateTime(base) == null) continue;
      entries.add(file);
    }
    entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  bool _containsMemoFlowStructure(Archive archive) {
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = _normalizeArchivePath(file.name).toLowerCase();
      if (normalized == 'index.md' || normalized.endsWith('/index.md')) {
        return true;
      }
      final segments = normalized.split('/');
      final memosIndex = segments.lastIndexOf('memos');
      if (memosIndex != -1 && memosIndex < segments.length - 1) {
        return true;
      }
    }
    return false;
  }

  Future<ImportResult> _finishImport({
    required ImportProgressCallback onProgress,
    required _ImportCounters counters,
    required Set<String> existingTags,
    required Set<String> importedTags,
  }) async {
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
      for (final tag in line.split(' ')) {
        final normalized = normalizeTagPath(tag);
        if (normalized.isNotEmpty) {
          out.add(normalized);
        }
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
    if (currentAccount == null) {
      return false;
    }
    if (currentAccount.personalAccessToken.trim().isEmpty) {
      return false;
    }
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
      MemoApiVersion.v027 => true,
      _ => false,
    };
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

  List<int> _readArchiveBytes(ArchiveFile file) => file.content;

  String _normalizeArchivePath(String raw) {
    var normalized = raw.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }

  Object? _tryDecodeJson(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> value) {
    final out = <String, dynamic>{};
    value.forEach((key, item) {
      if (key is String) {
        out[key.toLowerCase()] = item;
      }
    });
    return out;
  }

  bool _looksLikeDiaryJson(Map<String, dynamic> map) {
    final hasContent = map.containsKey('content');
    final hasCreateTime = map.containsKey('createtime');
    final hasUpdateTime = map.containsKey('updatetime');
    return hasContent && (hasCreateTime || hasUpdateTime);
  }

  String _readString(Map<String, dynamic> map, String key) {
    final value = map[key.toLowerCase()];
    return value is String ? value : '';
  }

  bool _readBool(Map<String, dynamic> map, String key) {
    final value = map[key.toLowerCase()];
    return switch (value) {
      bool flag => flag,
      num flag => flag != 0,
      String flag =>
        flag.trim().toLowerCase() == 'true' ||
            flag.trim() == '1' ||
            flag.trim().toLowerCase() == 'yes',
      _ => false,
    };
  }

  DateTime? _readDateTime(Map<String, dynamic> map, String key) {
    final value = map[key.toLowerCase()];
    if (value is String) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }

  List<String> _readTagNames(Map<String, dynamic> map) {
    final value = map['tags'];
    if (value is! List) {
      return const [];
    }
    final tags = <String>{};
    for (final item in value) {
      if (item is String) {
        final normalized = normalizeTagPath(item);
        if (normalized.isNotEmpty) {
          tags.add(normalized);
        }
        continue;
      }
      if (item is Map) {
        final name = _readString(_normalizeMap(item), 'name');
        final normalized = normalizeTagPath(name);
        if (normalized.isNotEmpty) {
          tags.add(normalized);
        }
      }
    }
    final list = tags.toList(growable: false);
    list.sort();
    return list;
  }

  List<String> _readResourceUris(Map<String, dynamic> map) {
    final value = map['resources'];
    if (value is! List) {
      return const [];
    }
    final uris = <String>[];
    final seen = <String>{};
    for (final item in value) {
      String? uri;
      if (item is String) {
        uri = item;
      } else if (item is Map) {
        uri = _readString(_normalizeMap(item), 'resourceuri');
      }
      final normalized = uri == null ? null : _normalizeResourceUri(uri);
      if (normalized == null || normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      uris.add(normalized);
    }
    return uris;
  }

  DateTime _fallbackDateFromBasename(String archivePath) {
    final base = _stripDuplicateExportSuffix(
      p.basenameWithoutExtension(archivePath),
    );
    return _tryParseDateTime(base) ?? DateTime.now();
  }

  DateTime? _parseMarkdownDateTime(String archivePath) {
    final base = _stripDuplicateExportSuffix(
      p.basenameWithoutExtension(archivePath),
    );
    return _tryParseDateTime(base);
  }

  String _stripDuplicateExportSuffix(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^(.*)\((\d+)\)$').firstMatch(trimmed);
    return match == null ? trimmed : (match.group(1) ?? trimmed).trimRight();
  }

  DateTime? _tryParseDateTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final compact = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$',
    ).firstMatch(trimmed);
    if (compact != null) {
      return DateTime(
        int.parse(compact.group(1)!),
        int.parse(compact.group(2)!),
        int.parse(compact.group(3)!),
        int.parse(compact.group(4)!),
        int.parse(compact.group(5)!),
        int.parse(compact.group(6)!),
      );
    }
    return DateTime.tryParse(trimmed);
  }

  String? _normalizeResourceUri(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value.replaceAll('\\', '/');
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme.toLowerCase() != 'appdata') {
        return null;
      }
      final combinedPath = <String>[
        if (uri.host.trim().isNotEmpty) uri.host.trim(),
        ...uri.pathSegments.where((segment) => segment.trim().isNotEmpty),
      ].join('/');
      value = 'appdata/$combinedPath';
    }

    while (value.startsWith('/')) {
      value = value.substring(1);
    }

    final lower = value.toLowerCase();
    if (lower.startsWith('appdata/')) {
      return value;
    }
    if (lower.startsWith('image/') ||
        lower.startsWith('audio/') ||
        lower.startsWith('video/')) {
      return value;
    }
    return null;
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

  void _logImportedMemoDiagnostics({
    required String sourceFile,
    required _ParsedDiaryMemo parsed,
    required String kind,
  }) {
    if (!shouldLogMemoContentDiagnostics(parsed.content)) {
      return;
    }
    LogManager.instance.info(
      'Swashbuckler import memo diagnostics',
      context: <String, Object?>{
        ...buildMemoContentDiagnostics(parsed.content, memoUid: parsed.memoUid),
        'sourceKind': kind,
        'sourceFileFingerprint': md5
            .convert(utf8.encode(sourceFile))
            .toString(),
        'attachmentCount': parsed.attachments.length,
        'tagCount': parsed.tags.length,
        'pinned': parsed.pinned,
      },
    );
  }
}

final RegExp _resourceUriPattern = RegExp(
  '(?:appdata:///|/?appdata/|/?(?:Image|Audio|Video)/)[^\\s)"\'>]+',
  caseSensitive: false,
);
final RegExp _resourceImagePattern = RegExp(
  '!\\[[^\\]]*\\]\\(([^)]+)\\)',
  caseSensitive: false,
);
final RegExp _resourceLinkPattern = RegExp(
  '\\[([^\\]]*)\\]\\(([^)]+)\\)',
  caseSensitive: false,
);
final RegExp _resourceMediaTagPattern = RegExp(
  '<(?:audio|video)\\b[^>]*\\bsrc=["\']([^"\']+)["\'][^>]*>.*?</(?:audio|video)>',
  caseSensitive: false,
  dotAll: true,
);

class _ParsedDiaryMemo {
  const _ParsedDiaryMemo({
    required this.memoUid,
    required this.content,
    required this.createTime,
    required this.updateTime,
    required this.pinned,
    required this.tags,
    required this.attachments,
  });

  final String memoUid;
  final String content;
  final DateTime createTime;
  final DateTime updateTime;
  final bool pinned;
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
    this.created,
    this.updated,
    this.pinned,
  });

  final String body;
  final DateTime? created;
  final DateTime? updated;
  final bool? pinned;
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
