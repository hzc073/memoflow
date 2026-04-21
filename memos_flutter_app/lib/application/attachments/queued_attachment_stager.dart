import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saf_stream/saf_stream.dart';

import '../../core/debug_ephemeral_storage.dart';
import '../../data/logs/log_manager.dart';
import 'compression/compression_source_probe.dart';

const CompressionSourceProbeService _queuedAttachmentProbeService =
    CompressionSourceProbeService();

typedef CopyContentUriToLocalFile =
    Future<void> Function(String sourceUri, String destinationPath);

class StagedAttachment {
  const StagedAttachment({
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

class QueuedAttachmentStager {
  QueuedAttachmentStager({
    Future<Directory> Function()? resolveSupportDirectory,
    CopyContentUriToLocalFile? copyContentUriToLocalFile,
  }) : _resolveSupportDirectory =
           resolveSupportDirectory ?? resolveAppSupportDirectory,
       _copyContentUriToLocalFile =
           copyContentUriToLocalFile ??
           ((sourceUri, destinationPath) {
             return SafStream().copyToLocalFile(sourceUri, destinationPath);
           });

  static const String managedRootDirName = 'queued_attachment_uploads';

  final Future<Directory> Function() _resolveSupportDirectory;
  final CopyContentUriToLocalFile _copyContentUriToLocalFile;
  Directory? _managedRootDir;

  Future<StagedAttachment> stageDraftAttachment({
    required String uid,
    required String filePath,
    required String filename,
    required String mimeType,
    required int size,
    required String scopeKey,
  }) async {
    final normalizedUid = uid.trim();
    final resolvedMimeType = mimeType.trim().isEmpty
        ? 'application/octet-stream'
        : mimeType.trim();
    await _logStageStart(
      uid: normalizedUid,
      scopeKey: scopeKey,
      filePath: filePath,
      filename: filename,
      mimeType: resolvedMimeType,
      requestedSize: size,
    );
    try {
      final stagedPath = await _stageFile(
        uid: uid,
        filePath: filePath,
        filename: filename,
        scopeKey: scopeKey,
      );
      final stagedFile = File(stagedPath);
      final stagedSize = stagedFile.existsSync()
          ? await stagedFile.length()
          : size;
      final staged = StagedAttachment(
        uid: normalizedUid,
        filePath: stagedPath,
        filename: _normalizeFilename(filename, filePath: stagedPath, uid: uid),
        mimeType: resolvedMimeType,
        size: stagedSize,
      );
      await _logStageComplete(
        uid: normalizedUid,
        scopeKey: scopeKey,
        originalPath: filePath,
        staged: staged,
      );
      return staged;
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'QueuedAttachmentStager: stage_failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'uid': normalizedUid,
          'scopeKey': scopeKey,
          'filePath': filePath,
          'filename': filename,
          'mimeType': resolvedMimeType,
          'requestedSize': size,
        },
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> stageUploadPayload(
    Map<String, dynamic> payload, {
    required String scopeKey,
  }) async {
    final uid = (payload['uid'] as String? ?? '').trim();
    final filePath = (payload['file_path'] as String? ?? '').trim();
    final filename = (payload['filename'] as String? ?? '').trim();
    final mimeType = (payload['mime_type'] as String? ?? '').trim();
    if (uid.isEmpty || filePath.isEmpty || filename.isEmpty) {
      throw const FormatException('upload_attachment missing fields');
    }

    final staged = await stageDraftAttachment(
      uid: uid,
      filePath: filePath,
      filename: filename,
      mimeType: mimeType,
      size: _readInt(payload['file_size']),
      scopeKey: _normalizeScopeKey(
        (payload['memo_uid'] as String? ?? '').trim().isNotEmpty
            ? (payload['memo_uid'] as String).trim()
            : scopeKey,
      ),
    );
    final next = Map<String, dynamic>.from(payload);
    next['file_path'] = staged.filePath;
    next['filename'] = staged.filename;
    next['mime_type'] = staged.mimeType;
    next['file_size'] = staged.size;
    final shareInlineLocalUrl =
        (next['share_inline_local_url'] as String? ?? '').trim();
    if (shareInlineLocalUrl.isNotEmpty) {
      next['share_inline_local_url'] = Uri.file(staged.filePath).toString();
    }
    return next;
  }

  Future<List<Map<String, dynamic>>> stageUploadPayloads(
    Iterable<Map<String, dynamic>> payloads, {
    required String scopeKey,
  }) async {
    final staged = <Map<String, dynamic>>[];
    for (final payload in payloads) {
      staged.add(await stageUploadPayload(payload, scopeKey: scopeKey));
    }
    return staged;
  }

  bool isManagedPath(String path) {
    final normalized = _normalizePath(path);
    if (normalized.isEmpty) return false;
    final segments = p
        .split(normalized)
        .map((item) => item.toLowerCase())
        .toList(growable: false);
    return segments.contains(managedRootDirName.toLowerCase());
  }

  Future<void> deleteManagedFile(String path) async {
    final normalized = _normalizePath(path);
    if (!isManagedPath(normalized)) return;
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
    final root = await _resolveManagedRootDir();
    var parent = file.parent;
    while (parent.path != root.path && await parent.exists()) {
      final children = parent.listSync(followLinks: false);
      if (children.isNotEmpty) break;
      await parent.delete();
      parent = parent.parent;
    }
  }

  Future<String> _stageFile({
    required String uid,
    required String filePath,
    required String filename,
    required String scopeKey,
  }) async {
    final normalizedPath = _normalizePath(filePath);
    if (normalizedPath.isEmpty) {
      throw const FormatException('file_path missing');
    }
    if (isManagedPath(normalizedPath)) {
      final existing = File(normalizedPath);
      if (await existing.exists()) return existing.path;
    }
    final managedDir = await _resolveScopeDir(scopeKey);
    final targetPath = p.join(
      managedDir.path,
      _buildManagedFilename(
        uid: uid.trim(),
        filename: _normalizeFilename(
          filename,
          filePath: normalizedPath,
          uid: uid,
        ),
      ),
    );
    if (p.equals(normalizedPath, targetPath)) {
      return targetPath;
    }

    final tempPath = '$targetPath.part';
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    await tempFile.parent.create(recursive: true);
    if (normalizedPath.startsWith('content://')) {
      await _copyContentUriToLocalFile(normalizedPath, tempPath);
    } else {
      final sourceFile = File(normalizedPath);
      if (!await sourceFile.exists()) {
        throw FileSystemException('File not found', normalizedPath);
      }
      await sourceFile.copy(tempPath);
    }

    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetPath);
    return targetPath;
  }

  Future<Directory> _resolveManagedRootDir() async {
    if (_managedRootDir != null) return _managedRootDir!;
    final supportDir = await _resolveSupportDirectory();
    final dir = Directory(p.join(supportDir.path, managedRootDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _managedRootDir = dir;
    return dir;
  }

  Future<Directory> _resolveScopeDir(String scopeKey) async {
    final root = await _resolveManagedRootDir();
    final dir = Directory(p.join(root.path, _normalizeScopeKey(scopeKey)));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _normalizeScopeKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'default';
    final sanitized = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    return sanitized.isEmpty ? 'default' : sanitized;
  }

  String _normalizeFilename(
    String raw, {
    required String filePath,
    required String uid,
  }) {
    final trimmed = raw.trim();
    final fallback = p.basename(_normalizePath(filePath));
    final candidate = trimmed.isNotEmpty ? trimmed : fallback;
    final sanitized = candidate.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    if (sanitized.isNotEmpty) return sanitized;
    return uid.trim().isEmpty ? 'attachment' : uid.trim();
  }

  String _buildManagedFilename({
    required String uid,
    required String filename,
  }) {
    final sanitizedUid = uid.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '${sanitizedUid.isEmpty ? 'attachment' : sanitizedUid}_$filename';
  }

  String _normalizePath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('file://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        try {
          return uri.toFilePath();
        } catch (_) {}
      }
    }
    return trimmed;
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Future<void> _logStageStart({
    required String uid,
    required String scopeKey,
    required String filePath,
    required String filename,
    required String mimeType,
    required int requestedSize,
  }) async {
    final sourceContext = await _buildAttachmentLogContext(
      filePath: filePath,
      filename: filename,
      mimeType: mimeType,
      prefix: 'source',
    );
    LogManager.instance.debug(
      'QueuedAttachmentStager: stage_start',
      context: {
        'uid': uid,
        'scopeKey': scopeKey,
        'requestedSize': requestedSize,
        ...sourceContext,
      },
    );
  }

  Future<void> _logStageComplete({
    required String uid,
    required String scopeKey,
    required String originalPath,
    required StagedAttachment staged,
  }) async {
    final sourceContext = await _buildAttachmentLogContext(
      filePath: originalPath,
      filename: staged.filename,
      mimeType: staged.mimeType,
      prefix: 'source',
    );
    final stagedContext = await _buildAttachmentLogContext(
      filePath: staged.filePath,
      filename: staged.filename,
      mimeType: staged.mimeType,
      prefix: 'staged',
    );
    LogManager.instance.info(
      'QueuedAttachmentStager: stage_complete',
      context: {
        'uid': uid,
        'scopeKey': scopeKey,
        'pathChanged':
            _normalizePath(originalPath) != _normalizePath(staged.filePath),
        ..._buildAttachmentDeltaContext(
          sourceContext: sourceContext,
          stagedContext: stagedContext,
        ),
        ...sourceContext,
        ...stagedContext,
      },
    );
  }

  Future<Map<String, Object?>> _buildAttachmentLogContext({
    required String filePath,
    required String filename,
    required String mimeType,
    required String prefix,
  }) async {
    final normalizedPath = _normalizePath(filePath);
    final file = File(normalizedPath);
    final exists = normalizedPath.isNotEmpty && await file.exists();
    final context = <String, Object?>{
      '${prefix}Path': normalizedPath,
      '${prefix}Exists': exists,
      '${prefix}MimeType': mimeType,
      '${prefix}IsContentUri': normalizedPath.startsWith('content://'),
    };
    if (!exists) {
      return context;
    }
    context['${prefix}FileSize'] = await file.length();
    if (!mimeType.toLowerCase().startsWith('image/')) {
      return context;
    }
    final probe = await _queuedAttachmentProbeService.probe(
      path: normalizedPath,
      filename: filename,
      mimeType: mimeType,
    );
    context.addAll({
      '${prefix}ImageFormat': probe.format.name,
      '${prefix}RawWidth': probe.width,
      '${prefix}RawHeight': probe.height,
      '${prefix}DisplayWidth': probe.displayWidth,
      '${prefix}DisplayHeight': probe.displayHeight,
      '${prefix}Orientation': probe.orientation,
    });
    return context;
  }

  Map<String, Object?> _buildAttachmentDeltaContext({
    required Map<String, Object?> sourceContext,
    required Map<String, Object?> stagedContext,
  }) {
    int? readInt(Map<String, Object?> ctx, String key) {
      final raw = ctx[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
    }

    String? readString(Map<String, Object?> ctx, String key) {
      final raw = ctx[key];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    double? scale(int? source, int? target) {
      if (source == null || target == null || source <= 0) return null;
      return double.parse((target / source).toStringAsFixed(3));
    }

    final sourceSize = readInt(sourceContext, 'sourceFileSize');
    final stagedSize = readInt(stagedContext, 'stagedFileSize');
    final sourceDisplayWidth = readInt(sourceContext, 'sourceDisplayWidth');
    final sourceDisplayHeight = readInt(sourceContext, 'sourceDisplayHeight');
    final stagedDisplayWidth = readInt(stagedContext, 'stagedDisplayWidth');
    final stagedDisplayHeight = readInt(stagedContext, 'stagedDisplayHeight');

    return {
      'sourceImageFormat': readString(sourceContext, 'sourceImageFormat'),
      'stagedImageFormat': readString(stagedContext, 'stagedImageFormat'),
      'fileSizeDelta': (stagedSize != null && sourceSize != null)
          ? stagedSize - sourceSize
          : null,
      'displayWidthDelta':
          (stagedDisplayWidth != null && sourceDisplayWidth != null)
          ? stagedDisplayWidth - sourceDisplayWidth
          : null,
      'displayHeightDelta':
          (stagedDisplayHeight != null && sourceDisplayHeight != null)
          ? stagedDisplayHeight - sourceDisplayHeight
          : null,
      'displayWidthScale': scale(sourceDisplayWidth, stagedDisplayWidth),
      'displayHeightScale': scale(sourceDisplayHeight, stagedDisplayHeight),
    };
  }
}
