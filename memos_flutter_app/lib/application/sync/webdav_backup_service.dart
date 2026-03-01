import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

import '../../core/hash.dart';
import '../../core/log_sanitizer.dart';
import '../../core/url.dart';
import '../../core/webdav_url.dart';
import '../../data/db/app_database.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../../data/local_library/local_library_fs.dart';
import '../../data/local_library/local_library_markdown.dart';
import '../../data/local_library/local_library_naming.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_library.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_backup_state.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/settings/webdav_backup_password_repository.dart';
import '../../data/settings/webdav_backup_state_repository.dart';
import '../../data/webdav/webdav_client.dart';
import 'local_library_scan_service.dart';
import 'sync_error.dart';
import 'sync_types.dart';

enum WebDavBackupExportIssueKind { memo, attachment }

enum WebDavBackupExportAction { retry, skip, abort }

class WebDavBackupExportIssue {
  const WebDavBackupExportIssue({
    required this.kind,
    required this.memoUid,
    this.attachmentFilename,
    required this.error,
  });

  final WebDavBackupExportIssueKind kind;
  final String memoUid;
  final String? attachmentFilename;
  final Object error;
}

class WebDavBackupExportResolution {
  const WebDavBackupExportResolution({
    required this.action,
    this.applyToRemainingFailures = false,
  });

  final WebDavBackupExportAction action;
  final bool applyToRemainingFailures;
}

typedef WebDavBackupExportIssueHandler =
    Future<WebDavBackupExportResolution> Function(
      WebDavBackupExportIssue issue,
    );

typedef WebDavBackupClientFactory = WebDavClient Function({
  required Uri baseUrl,
  required WebDavSettings settings,
  void Function(DebugLogEntry entry)? logWriter,
});

class WebDavBackupService {
  WebDavBackupService({
    required AppDatabase db,
    required LocalAttachmentStore attachmentStore,
    required WebDavBackupStateRepository stateRepository,
    required WebDavBackupPasswordRepository passwordRepository,
    LocalLibraryScanService Function(LocalLibrary library)? scanServiceFactory,
    WebDavBackupClientFactory? clientFactory,
    void Function(DebugLogEntry entry)? logWriter,
  }) : _db = db,
       _attachmentStore = attachmentStore,
       _stateRepository = stateRepository,
       _passwordRepository = passwordRepository,
       _scanServiceFactory = scanServiceFactory,
       _clientFactory = clientFactory ?? _defaultBackupClientFactory,
       _logWriter = logWriter;

  final AppDatabase _db;
  final LocalAttachmentStore _attachmentStore;
  final WebDavBackupStateRepository _stateRepository;
  final WebDavBackupPasswordRepository _passwordRepository;
  final LocalLibraryScanService Function(LocalLibrary library)?
  _scanServiceFactory;
  final WebDavBackupClientFactory _clientFactory;
  final void Function(DebugLogEntry entry)? _logWriter;

  static const _backupDir = 'backup';
  static const _backupVersion = 'v1';
  static const _backupConfigFile = 'config.json';
  static const _backupIndexFile = 'index.enc';
  static const _backupObjectsDir = 'objects';
  static const _backupSnapshotsDir = 'snapshots';
  static const _backupSettingsSnapshotPath = 'config/webdav_settings.json';
  static const _plainBackupIndexFile = 'index.json';
  static const _chunkSize = 4 * 1024 * 1024;
  static const _nonceLength = 12;
  static const _macLength = 16;

  final _cipher = AesGcm.with256bits();
  final _random = Random.secure();

  void _logEvent(String label, {String? detail, Object? error}) {
    final writer = _logWriter;
    if (writer == null) return;
    writer(
      DebugLogEntry(
        timestamp: DateTime.now(),
        category: 'webdav',
        label: label,
        detail: detail,
        error: error == null
            ? null
            : LogSanitizer.sanitizeText(error.toString()),
      ),
    );
  }

  Future<String?> setupBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    final resolvedPassword = password.trim();
    if (resolvedPassword.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_password_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_account_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }

    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _buildClient(settings, baseUrl);
    try {
      await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
      final existing = await _loadConfig(client, baseUrl, rootPath, accountId);
      if (existing == null) {
        final created = await _createConfigWithRecovery(resolvedPassword);
        await _saveConfig(client, baseUrl, rootPath, accountId, created.config);
        return created.recoveryCode;
      }

      final masterKey = await _resolveMasterKey(resolvedPassword, existing);
      if (existing.recovery != null) return null;
      final recovery = await _buildRecoveryBundle(masterKey);
      final updated = WebDavBackupConfig(
        schemaVersion: existing.schemaVersion,
        createdAt: existing.createdAt,
        kdf: existing.kdf,
        wrappedKey: existing.wrappedKey,
        recovery: recovery.recovery,
      );
      await _saveConfig(client, baseUrl, rootPath, accountId, updated);
      return recovery.recoveryCode;
    } finally {
      await client.close();
    }
  }

  Future<String> recoverBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final resolvedPassword = newPassword.trim();
    final normalizedRecoveryCode = _normalizeRecoveryCode(recoveryCode);
    if (resolvedPassword.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_password_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    if (normalizedRecoveryCode.isEmpty) {
      throw _keyedError(
        'legacy.webdav.recovery_code_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }

    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_account_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _buildClient(settings, baseUrl);
    try {
      await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
      final config = await _loadConfig(client, baseUrl, rootPath, accountId);
      if (config == null) {
        throw _keyedError(
          'legacy.msg_no_backups_found',
          code: SyncErrorCode.unknown,
        );
      }
      final masterKey = await _resolveMasterKeyWithRecoveryCode(
        normalizedRecoveryCode,
        config,
      );
      final masterKeyBytes = await masterKey.extractBytes();
      final passwordBundle = await _buildWrappedKeyBundle(
        secret: resolvedPassword,
        masterKey: masterKeyBytes,
      );
      final recoveryBundle = await _buildRecoveryBundle(masterKey);
      final updated = WebDavBackupConfig(
        schemaVersion: config.schemaVersion,
        createdAt: config.createdAt,
        kdf: passwordBundle.kdf,
        wrappedKey: passwordBundle.wrappedKey,
        recovery: recoveryBundle.recovery,
      );
      await _saveConfig(client, baseUrl, rootPath, accountId, updated);
      return recoveryBundle.recoveryCode;
    } finally {
      await client.close();
    }
  }

  Future<WebDavBackupResult> backupNow({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    String? password,
    bool manual = true,
    Uri? attachmentBaseUrl,
    String? attachmentAuthHeader,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    final includeConfig = settings.backupContentConfig;
    final includeMemos = settings.backupContentMemos;
    final usePlainBackup =
        settings.backupEncryptionMode == WebDavBackupEncryptionMode.plain;
    final backupLibrary = includeMemos
        ? _resolveBackupLibrary(settings, activeLocalLibrary)
        : null;
    final usesMirrorLibrary = includeMemos && activeLocalLibrary == null;
    final triggerLabel = manual ? 'manual' : 'auto';
    if (!settings.isBackupEnabled) {
      _logEvent('Backup skipped', detail: 'disabled ($triggerLabel)');
      return WebDavBackupSkipped(
        reason: _keyedError(
          'legacy.webdav.backup_disabled',
          code: SyncErrorCode.invalidConfig,
        ),
      );
    }
    if (!includeConfig && !includeMemos) {
      _logEvent('Backup skipped', detail: 'content_empty ($triggerLabel)');
      return WebDavBackupSkipped(
        reason: SyncError(
          code: SyncErrorCode.invalidConfig,
          retryable: false,
          message: 'BACKUP_CONTENT_EMPTY',
        ),
      );
    }
    if (normalizedAccountKey.isEmpty) {
      _logEvent('Backup skipped', detail: 'account_missing ($triggerLabel)');
      return WebDavBackupSkipped(
        reason: _keyedError(
          'legacy.webdav.backup_account_missing',
          code: SyncErrorCode.invalidConfig,
        ),
      );
    }
    if (includeMemos && backupLibrary == null) {
      _logEvent(
        'Backup skipped',
        detail: 'mirror_location_missing ($triggerLabel)',
      );
      return WebDavBackupSkipped(
        reason: SyncError(
          code: SyncErrorCode.invalidConfig,
          retryable: false,
          presentationKey: 'legacy.msg_export_path_not_set',
        ),
      );
    }

    String? resolvedPassword;
    if (!usePlainBackup) {
      resolvedPassword = await _resolvePassword(password);
      if (resolvedPassword == null || resolvedPassword.trim().isEmpty) {
        _logEvent('Backup skipped', detail: 'password_missing ($triggerLabel)');
        return const WebDavBackupMissingPassword();
      }
    }

    _logEvent(
      'Backup started',
      detail: 'mode=${usePlainBackup ? 'plain' : 'encrypted'} ($triggerLabel)',
    );
    try {
      if (includeMemos) {
        final exportedMemos = await _exportLocalLibraryForBackup(
          backupLibrary!,
          pruneToCurrentData: usesMirrorLibrary,
          attachmentBaseUrl: attachmentBaseUrl,
          attachmentAuthHeader: attachmentAuthHeader,
          issueHandler: manual ? onExportIssue : null,
        );
        if (exportedMemos > 0) {
          final memoFiles = await LocalLibraryFileSystem(
            backupLibrary,
          ).listMemos();
          if (memoFiles.isEmpty) {
            return WebDavBackupFailure(
              _keyedError(
                'legacy.webdav.backup_no_memo_files',
                code: SyncErrorCode.dataCorrupt,
              ),
            );
          }
        }
      }

      final baseUrl = _parseBaseUrl(settings.serverUrl);
      final accountId = fnv1a64Hex(normalizedAccountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = _buildClient(settings, baseUrl);
      try {
        await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
        final now = DateTime.now();
        if (usePlainBackup) {
          await _backupPlain(
            settings: settings,
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            localLibrary: backupLibrary,
            includeMemos: includeMemos,
            includeConfig: includeConfig,
          );
          await _stateRepository.write(
            WebDavBackupState(
              lastBackupAt: now.toUtc().toIso8601String(),
              lastSnapshotId: null,
            ),
          );
          _logEvent('Backup completed', detail: 'mode=plain');
          return const WebDavBackupSuccess();
        }

        final securedPassword = resolvedPassword!;
        final config = await _loadOrCreateConfig(
          client,
          baseUrl,
          rootPath,
          accountId,
          securedPassword,
        );
        final masterKey = await _resolveMasterKey(securedPassword, config);
        var index = await _loadIndex(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
        );

        final snapshotId = _buildSnapshotId(now);
        final build = await _buildSnapshot(
          localLibrary: backupLibrary,
          includeMemos: includeMemos,
          configPayload: includeConfig
              ? _buildBackupSettingsSnapshotPayload(settings)
              : null,
          index: index,
          masterKey: masterKey,
          client: client,
          baseUrl: baseUrl,
          rootPath: rootPath,
          accountId: accountId,
          snapshotId: snapshotId,
        );
        if (build.snapshot.files.isEmpty) {
          return WebDavBackupSkipped(
            reason: SyncError(
              code: SyncErrorCode.unknown,
              retryable: false,
              message: 'BACKUP_CONTENT_EMPTY',
            ),
          );
        }

        final snapshot = build.snapshot;
        index = _applySnapshotToIndex(
          index,
          snapshot,
          now,
          build.newObjectSizes,
        );
        index = await _applyRetention(
          client: client,
          baseUrl: baseUrl,
          rootPath: rootPath,
          accountId: accountId,
          masterKey: masterKey,
          index: index,
          retention: settings.backupRetentionCount,
        );

        await _uploadSnapshot(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
          snapshot,
        );
        await _saveIndex(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
          index,
        );

        await _stateRepository.write(
          WebDavBackupState(
            lastBackupAt: now.toUtc().toIso8601String(),
            lastSnapshotId: snapshot.id,
          ),
        );
        if (settings.rememberBackupPassword) {
          await _passwordRepository.write(securedPassword);
        }

        _logEvent(
          'Backup completed',
          detail: 'snapshot=${snapshot.id}',
        );
        return const WebDavBackupSuccess();
      } finally {
        await client.close();
      }
    } on _BackupExportAborted catch (e) {
      final error =
          e.error ??
          _keyedError('legacy.msg_cancel_2', code: SyncErrorCode.unknown);
      _logEvent('Backup cancelled', detail: error.presentationKey);
      return WebDavBackupSkipped(reason: error);
    } on SyncError catch (error) {
      _logEvent('Backup failed', error: error);
      return WebDavBackupFailure(error);
    } catch (error) {
      final mapped = _mapUnexpectedError(error);
      _logEvent('Backup failed', error: mapped);
      return WebDavBackupFailure(mapped);
    }
  }

  LocalLibrary? _resolveBackupLibrary(
    WebDavSettings settings,
    LocalLibrary? activeLocalLibrary,
  ) {
    if (activeLocalLibrary != null) return activeLocalLibrary;
    final treeUri = settings.backupMirrorTreeUri.trim();
    final rootPath = settings.backupMirrorRootPath.trim();
    if (treeUri.isEmpty && rootPath.isEmpty) return null;
    return LocalLibrary(
      key: 'webdav_backup_mirror',
      name: 'WebDAV 备份镜像',
      treeUri: treeUri.isEmpty ? null : treeUri,
      rootPath: treeUri.isNotEmpty ? null : rootPath,
    );
  }

  Map<String, dynamic> _buildBackupSettingsSnapshotPayload(
    WebDavSettings settings,
  ) {
    return {
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'webDav': {
        'enabled': settings.enabled,
        'serverUrl': settings.serverUrl,
        'username': settings.username,
        'authMode': settings.authMode.name,
        'ignoreTlsErrors': settings.ignoreTlsErrors,
        'rootPath': settings.rootPath,
      },
      'backup': {
      'backupEnabled': settings.backupEnabled,
      'backupEncryptionMode': settings.backupEncryptionMode.name,
      'backupSchedule': settings.backupSchedule.name,
      'backupRetentionCount': settings.backupRetentionCount,
      'rememberBackupPassword': settings.rememberBackupPassword,
        'backupMirrorTreeUri': settings.backupMirrorTreeUri,
        'backupMirrorRootPath': settings.backupMirrorRootPath,
        'backupContentConfig': settings.backupContentConfig,
        'backupContentMemos': settings.backupContentMemos,
      },
    };
  }

  Future<List<WebDavBackupSnapshotInfo>> listSnapshots({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) return const [];
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _buildClient(settings, baseUrl);
    try {
      await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
      final config = await _loadConfig(client, baseUrl, rootPath, accountId);
      if (config == null) return const [];
      final masterKey = await _resolveMasterKey(password, config);
      final index = await _loadIndex(
        client,
        baseUrl,
        rootPath,
        accountId,
        masterKey,
      );
      final snapshots = <WebDavBackupSnapshotInfo>[];
      for (final item in index.snapshots) {
        if (item.memosCount > 0 || item.fileCount == 0) {
          snapshots.add(item);
          continue;
        }
        try {
          final data = await _loadSnapshot(
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            masterKey: masterKey,
            snapshotId: item.id,
          );
          final memosCount = _countMemosInSnapshot(data);
          snapshots.add(
            WebDavBackupSnapshotInfo(
              id: item.id,
              createdAt: item.createdAt,
              memosCount: memosCount,
              fileCount: item.fileCount,
              totalBytes: item.totalBytes,
            ),
          );
        } catch (_) {
          snapshots.add(item);
        }
      }
      snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return snapshots;
    } finally {
      await client.close();
    }
  }

  Future<WebDavRestoreResult> restoreSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      return WebDavRestoreSkipped(
        reason: _keyedError(
          'legacy.webdav.restore_account_missing',
          code: SyncErrorCode.invalidConfig,
        ),
      );
    }
    if (activeLocalLibrary == null) {
      _logEvent('Restore skipped', detail: 'local_only');
      return WebDavRestoreSkipped(
        reason: _keyedError(
          'legacy.webdav.restore_local_only',
          code: SyncErrorCode.invalidConfig,
        ),
      );
    }

    _logEvent('Restore started', detail: 'snapshot=${snapshot.id}');
    try {
      final baseUrl = _parseBaseUrl(settings.serverUrl);
      final accountId = fnv1a64Hex(normalizedAccountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = _buildClient(settings, baseUrl);
      try {
        await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
        final config = await _loadConfig(client, baseUrl, rootPath, accountId);
        if (config == null) {
          throw _keyedError(
            'legacy.msg_no_backups_found',
            code: SyncErrorCode.unknown,
          );
        }
        final masterKey = await _resolveMasterKey(password, config);
        final snapshotData = await _loadSnapshot(
          client: client,
          baseUrl: baseUrl,
          rootPath: rootPath,
          accountId: accountId,
          masterKey: masterKey,
          snapshotId: snapshot.id,
        );
        if (snapshotData.files.isEmpty) {
          _logEvent('Restore failed', detail: 'snapshot_empty');
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.backup_empty',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }
        if (!_snapshotHasMemos(snapshotData)) {
          _logEvent('Restore failed', detail: 'no_memos');
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.backup_no_memos',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }

        final fileSystem = LocalLibraryFileSystem(activeLocalLibrary);
        await fileSystem.clearLibrary();
        await _attachmentStore.clearAll();
        await fileSystem.ensureStructure();

        for (final entry in snapshotData.files) {
          if (_isBackupSettingsSnapshotPath(entry.path)) {
            continue;
          }
          await _restoreFile(
            entry: entry,
            fileSystem: fileSystem,
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            masterKey: masterKey,
          );
        }

        await _db.clearOutbox();
        final scanService = _scanServiceFor(activeLocalLibrary);
        if (scanService != null) {
          final scanResult = await scanService.scanAndMerge(
            forceDisk: true,
            conflictDecisions: conflictDecisions,
          );
          switch (scanResult) {
            case LocalScanConflictResult(:final conflicts):
              return WebDavRestoreConflict(conflicts);
            case LocalScanFailure(:final error):
              return WebDavRestoreFailure(error);
            case LocalScanSuccess():
              break;
          }
        }

        _logEvent('Restore completed', detail: 'snapshot=${snapshot.id}');
        return const WebDavRestoreSuccess();
      } finally {
        await client.close();
      }
    } on SyncError catch (error) {
      _logEvent('Restore failed', error: error);
      return WebDavRestoreFailure(error);
    } catch (error) {
      final mapped = _mapUnexpectedError(error);
      _logEvent('Restore failed', error: mapped);
      return WebDavRestoreFailure(mapped);
    }
  }

  Future<WebDavRestoreResult> restorePlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      return WebDavRestoreSkipped(
        reason: _keyedError(
          'legacy.webdav.restore_account_missing',
          code: SyncErrorCode.invalidConfig,
        ),
      );
    }
    if (activeLocalLibrary == null) {
      _logEvent('Restore skipped', detail: 'local_only');
      return WebDavRestoreSkipped(
        reason: _keyedError(
          'legacy.webdav.restore_local_only',
          code: SyncErrorCode.invalidConfig,
        ),
      );
    }

    _logEvent('Restore started', detail: 'mode=plain');
    try {
      final baseUrl = _parseBaseUrl(settings.serverUrl);
      final accountId = fnv1a64Hex(normalizedAccountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = _buildClient(settings, baseUrl);
      try {
        await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
        final index = await _loadPlainIndex(
          client,
          baseUrl,
          rootPath,
          accountId,
        );
        if (index == null) {
          _logEvent('Restore failed', detail: 'no_backups_found');
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.msg_no_backups_found',
              code: SyncErrorCode.unknown,
            ),
          );
        }
        if (index.files.isEmpty) {
          _logEvent('Restore failed', detail: 'backup_empty');
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.backup_empty',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }
        if (!_plainIndexHasMemos(index)) {
          _logEvent('Restore failed', detail: 'no_memos');
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.backup_no_memos',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }

        final fileSystem = LocalLibraryFileSystem(activeLocalLibrary);
        await fileSystem.clearLibrary();
        await _attachmentStore.clearAll();
        await fileSystem.ensureStructure();

        for (final entry in index.files) {
          if (_isBackupSettingsSnapshotPath(entry.path)) {
            continue;
          }
          final bytes = await _getBytes(
            client,
            _plainFileUri(baseUrl, rootPath, accountId, entry.path),
          );
          if (bytes == null) {
            throw SyncError(
              code: SyncErrorCode.dataCorrupt,
              retryable: false,
              message: 'BACKUP_FILE_MISSING',
            );
          }
          await fileSystem.writeFileFromChunks(
            entry.path,
            Stream<Uint8List>.value(Uint8List.fromList(bytes)),
            mimeType: _guessMimeType(entry.path),
          );
        }

        await _db.clearOutbox();
        final scanService = _scanServiceFor(activeLocalLibrary);
        if (scanService != null) {
          final scanResult = await scanService.scanAndMerge(
            forceDisk: true,
            conflictDecisions: conflictDecisions,
          );
          switch (scanResult) {
            case LocalScanConflictResult(:final conflicts):
              return WebDavRestoreConflict(conflicts);
            case LocalScanFailure(:final error):
              return WebDavRestoreFailure(error);
            case LocalScanSuccess():
              break;
          }
        }

        _logEvent('Restore completed', detail: 'mode=plain');
        return const WebDavRestoreSuccess();
      } finally {
        await client.close();
      }
    } on SyncError catch (error) {
      _logEvent('Restore failed', error: error);
      return WebDavRestoreFailure(error);
    } catch (error) {
      final mapped = _mapUnexpectedError(error);
      _logEvent('Restore failed', error: mapped);
      return WebDavRestoreFailure(mapped);
    }
  }

  Future<int> _exportLocalLibraryForBackup(
    LocalLibrary localLibrary, {
    bool pruneToCurrentData = false,
    Uri? attachmentBaseUrl,
    String? attachmentAuthHeader,
    WebDavBackupExportIssueHandler? issueHandler,
  }) async {
    final fileSystem = LocalLibraryFileSystem(localLibrary);
    await fileSystem.ensureStructure();

    final rows = await _db.listMemosForExport(includeArchived: true);
    final stickyResolutions =
        <WebDavBackupExportIssueKind, WebDavBackupExportResolution>{};
    final targetMemoUids = <String>{};
    final expectedAttachmentsByMemo = <String, Set<String>>{};
    final skipAttachmentPruneUids = <String>{};
    var memoCount = 0;
    final httpClient = Dio();
    try {
      for (final row in rows) {
        final memo = LocalMemo.fromDb(row);
        final uid = memo.uid.trim();
        if (uid.isEmpty) continue;
        targetMemoUids.add(uid);
        final markdown = buildLocalLibraryMarkdown(memo);

        var memoWritten = false;
        while (!memoWritten) {
          try {
            await fileSystem.writeMemo(uid: uid, content: markdown);
            memoWritten = true;
            memoCount += 1;
          } catch (error) {
            final resolution = await _resolveExportIssue(
              issue: WebDavBackupExportIssue(
                kind: WebDavBackupExportIssueKind.memo,
                memoUid: uid,
                error: error,
              ),
              issueHandler: issueHandler,
              stickyResolutions: stickyResolutions,
            );
            if (resolution.action == WebDavBackupExportAction.retry) {
              continue;
            }
            if (resolution.action == WebDavBackupExportAction.skip) {
              skipAttachmentPruneUids.add(uid);
              break;
            }
          }
        }
        if (!memoWritten) {
          continue;
        }

        final expectedAttachmentNames = <String>{};
        final usedAttachmentNames = <String>{};
        var attachmentFailed = false;
        for (final attachment in memo.attachments) {
          final localLookupName = attachmentArchiveName(attachment);
          final archiveName = _dedupeAttachmentFilename(
            localLookupName,
            usedAttachmentNames,
          );
          usedAttachmentNames.add(archiveName);
          var exported = false;
          while (!exported) {
            try {
              await _exportAttachmentForBackup(
                fileSystem: fileSystem,
                attachmentStore: _attachmentStore,
                memoUid: uid,
                attachment: attachment,
                archiveName: archiveName,
                localLookupName: localLookupName,
                baseUrl: attachmentBaseUrl,
                authHeader: attachmentAuthHeader,
                httpClient: httpClient,
              );
              expectedAttachmentNames.add(archiveName);
              exported = true;
            } catch (error) {
              final resolution = await _resolveExportIssue(
                issue: WebDavBackupExportIssue(
                  kind: WebDavBackupExportIssueKind.attachment,
                  memoUid: uid,
                  attachmentFilename: archiveName,
                  error: error,
                ),
                issueHandler: issueHandler,
                stickyResolutions: stickyResolutions,
              );
              if (resolution.action == WebDavBackupExportAction.retry) {
                continue;
              }
              if (resolution.action == WebDavBackupExportAction.skip) {
                attachmentFailed = true;
                break;
              }
            }
          }
        }

        if (attachmentFailed) {
          skipAttachmentPruneUids.add(uid);
        } else {
          expectedAttachmentsByMemo[uid] = expectedAttachmentNames;
        }
      }

      if (pruneToCurrentData) {
        await _pruneMirrorLibraryFiles(
          fileSystem: fileSystem,
          targetMemoUids: targetMemoUids,
          expectedAttachmentsByMemo: expectedAttachmentsByMemo,
          skipAttachmentPruneUids: skipAttachmentPruneUids,
        );
      }
    } finally {
      httpClient.close();
    }

    return memoCount;
  }

  Future<WebDavBackupExportResolution> _resolveExportIssue({
    required WebDavBackupExportIssue issue,
    required WebDavBackupExportIssueHandler? issueHandler,
    required Map<WebDavBackupExportIssueKind, WebDavBackupExportResolution>
    stickyResolutions,
  }) async {
    final sticky = stickyResolutions[issue.kind];
    if (sticky != null) {
      if (sticky.action == WebDavBackupExportAction.abort) {
        throw _BackupExportAborted(
          _keyedError('legacy.msg_cancel_2', code: SyncErrorCode.unknown),
        );
      }
      return sticky;
    }

    if (issueHandler == null) {
      throw SyncError(
        code: SyncErrorCode.unknown,
        retryable: false,
        message: _formatExportIssueMessage(issue),
      );
    }

    final resolution = await issueHandler(issue);
    if (resolution.action == WebDavBackupExportAction.abort) {
      throw _BackupExportAborted(
        _keyedError('legacy.msg_cancel_2', code: SyncErrorCode.unknown),
      );
    }
    if (resolution.applyToRemainingFailures &&
        resolution.action != WebDavBackupExportAction.retry) {
      stickyResolutions[issue.kind] = resolution;
    }
    return resolution;
  }

  String _formatExportIssueMessage(WebDavBackupExportIssue issue) {
    final kindLabel = switch (issue.kind) {
      WebDavBackupExportIssueKind.memo => 'memo',
      WebDavBackupExportIssueKind.attachment => 'attachment',
    };
    final target = issue.kind == WebDavBackupExportIssueKind.memo
        ? issue.memoUid
        : '${issue.memoUid}/${issue.attachmentFilename ?? ''}';
    final rawError = issue.error.toString().trim();
    final errorText = rawError.isEmpty ? 'unknown error' : rawError;
    return '$kindLabel[$target] failed: $errorText';
  }

  String _dedupeAttachmentFilename(String filename, Set<String> used) {
    if (!used.contains(filename)) return filename;
    final dot = filename.lastIndexOf('.');
    final hasExt = dot > 0;
    final base = hasExt ? filename.substring(0, dot) : filename;
    final ext = hasExt ? filename.substring(dot) : '';
    var index = 1;
    while (true) {
      final candidate = '$base ($index)$ext';
      if (!used.contains(candidate)) return candidate;
      index += 1;
    }
  }

  Future<void> _exportAttachmentForBackup({
    required LocalLibraryFileSystem fileSystem,
    required LocalAttachmentStore attachmentStore,
    required String memoUid,
    required Attachment attachment,
    required String archiveName,
    required String localLookupName,
    required Uri? baseUrl,
    required String? authHeader,
    required Dio httpClient,
  }) async {
    final sourcePath = await _resolveAttachmentSourcePath(
      attachmentStore: attachmentStore,
      memoUid: memoUid,
      attachment: attachment,
      lookupName: localLookupName,
    );
    final mimeType = attachment.type.isNotEmpty
        ? attachment.type
        : _guessMimeType(archiveName);
    if (sourcePath != null) {
      await fileSystem.writeAttachmentFromFile(
        memoUid: memoUid,
        filename: archiveName,
        srcPath: sourcePath,
        mimeType: mimeType,
      );
      return;
    }

    final url = _resolveAttachmentUrl(baseUrl, attachment);
    if (url == null || url.isEmpty) {
      throw SyncError(
        code: SyncErrorCode.dataCorrupt,
        retryable: false,
        message: 'Attachment source missing',
      );
    }
    final response = await httpClient.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: authHeader == null ? null : {'Authorization': authHeader},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw SyncError(
        code: SyncErrorCode.dataCorrupt,
        retryable: false,
        message: 'Attachment download failed',
      );
    }
    await fileSystem.writeFileFromChunks(
      'attachments/$memoUid/$archiveName',
      Stream<Uint8List>.value(Uint8List.fromList(bytes)),
      mimeType: mimeType,
    );
  }

  Future<String?> _resolveAttachmentSourcePath({
    required LocalAttachmentStore attachmentStore,
    required String memoUid,
    required Attachment attachment,
    required String lookupName,
  }) async {
    final privatePath = await attachmentStore.resolveAttachmentPath(
      memoUid,
      lookupName,
    );
    final privateFile = File(privatePath);
    if (privateFile.existsSync()) return privateFile.path;

    final link = attachment.externalLink.trim();
    if (!link.startsWith('file://')) return null;
    try {
      final path = Uri.parse(link).toFilePath();
      if (path.trim().isEmpty) return null;
      final file = File(path);
      if (!file.existsSync()) return null;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  String? _resolveAttachmentUrl(Uri? baseUrl, Attachment attachment) {
    final link = attachment.externalLink.trim();
    if (link.isNotEmpty &&
        !link.startsWith('file://') &&
        !link.startsWith('content://')) {
      final resolved = resolveMaybeRelativeUrl(baseUrl, link);
      return resolved.trim().isEmpty ? null : resolved;
    }
    if (baseUrl == null) return null;
    final filename = attachment.filename.trim();
    if (filename.isEmpty) return null;
    return joinBaseUrl(baseUrl, 'file/${attachment.name}/$filename');
  }

  Future<void> _pruneMirrorLibraryFiles({
    required LocalLibraryFileSystem fileSystem,
    required Set<String> targetMemoUids,
    required Map<String, Set<String>> expectedAttachmentsByMemo,
    required Set<String> skipAttachmentPruneUids,
  }) async {
    final files = await fileSystem.listAllFiles();
    final deletedAttachmentDirs = <String>{};

    for (final entry in files) {
      final segments = entry.relativePath
          .replaceAll('\\', '/')
          .split('/')
          .where((s) => s.trim().isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty) continue;

      if (segments[0] == 'memos' && segments.length == 2) {
        final memoUid = _parseMemoUidFromFileName(segments[1]);
        if (memoUid == null || memoUid.isEmpty) continue;
        if (targetMemoUids.contains(memoUid)) continue;
        await fileSystem.deleteRelativeFile(entry.relativePath);
        if (deletedAttachmentDirs.add(memoUid)) {
          await fileSystem.deleteAttachmentsDir(memoUid);
        }
        continue;
      }

      if (segments[0] == 'attachments' && segments.length >= 3) {
        final memoUid = segments[1].trim();
        if (memoUid.isEmpty) continue;
        if (!targetMemoUids.contains(memoUid)) {
          if (deletedAttachmentDirs.add(memoUid)) {
            await fileSystem.deleteAttachmentsDir(memoUid);
          }
          continue;
        }
        if (skipAttachmentPruneUids.contains(memoUid)) {
          continue;
        }
        final expected = expectedAttachmentsByMemo[memoUid] ?? const <String>{};
        final filename = segments.sublist(2).join('/');
        if (!expected.contains(filename)) {
          await fileSystem.deleteRelativeFile(entry.relativePath);
        }
      }
    }

    for (final memoUid in targetMemoUids) {
      if (skipAttachmentPruneUids.contains(memoUid)) continue;
      final expected = expectedAttachmentsByMemo[memoUid] ?? const <String>{};
      if (expected.isEmpty) {
        await fileSystem.deleteAttachmentsDir(memoUid);
      }
    }
  }

  String? _parseMemoUidFromFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('.md.txt')) {
      final uid = trimmed
          .substring(0, trimmed.length - '.md.txt'.length)
          .trim();
      return uid.isEmpty ? null : uid;
    }
    if (lower.endsWith('.md')) {
      final uid = trimmed.substring(0, trimmed.length - '.md'.length).trim();
      return uid.isEmpty ? null : uid;
    }
    return null;
  }

  int _countMemosInSnapshot(WebDavBackupSnapshot snapshot) {
    var count = 0;
    for (final entry in snapshot.files) {
      final path = entry.path.trim().toLowerCase();
      if (path.startsWith('memos/') &&
          (path.endsWith('.md') || path.endsWith('.md.txt'))) {
        count += 1;
      }
    }
    return count;
  }

  bool _snapshotHasMemos(WebDavBackupSnapshot snapshot) {
    return _countMemosInSnapshot(snapshot) > 0;
  }

  int _countMemosInPlainIndex(_PlainBackupIndex index) {
    var count = 0;
    for (final entry in index.files) {
      final path = entry.path.trim().toLowerCase();
      if (path.startsWith('memos/') &&
          (path.endsWith('.md') || path.endsWith('.md.txt'))) {
        count += 1;
      }
    }
    return count;
  }

  bool _plainIndexHasMemos(_PlainBackupIndex index) {
    return _countMemosInPlainIndex(index) > 0;
  }

  bool _isBackupSettingsSnapshotPath(String relativePath) {
    return relativePath.replaceAll('\\', '/').toLowerCase() ==
        _backupSettingsSnapshotPath;
  }

  Future<void> _backupPlain({
    required WebDavSettings settings,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required LocalLibrary? localLibrary,
    required bool includeMemos,
    required bool includeConfig,
  }) async {
    final uploads = <_PlainBackupFileUpload>[];
    LocalLibraryFileSystem? fileSystem;

    if (includeMemos) {
      final targetLibrary = localLibrary;
      if (targetLibrary == null) {
        throw _keyedError(
          'legacy.msg_export_path_not_set',
          code: SyncErrorCode.invalidConfig,
        );
      }
      fileSystem = LocalLibraryFileSystem(targetLibrary);
      await fileSystem.ensureStructure();
      final entries = await fileSystem.listAllFiles();
      entries.sort((a, b) => a.relativePath.compareTo(b.relativePath));
      for (final entry in entries) {
        final normalized = entry.relativePath.replaceAll('\\', '/').trim();
        if (normalized.isEmpty) continue;
        uploads.add(
          _PlainBackupFileUpload(
            path: normalized,
            size: entry.length,
            modifiedAt: entry.lastModified?.toUtc().toIso8601String(),
            entry: entry,
          ),
        );
      }
    }

    if (includeConfig) {
      final payload = _buildBackupSettingsSnapshotPayload(settings);
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      uploads.add(
        _PlainBackupFileUpload(
          path: _backupSettingsSnapshotPath,
          size: bytes.length,
          modifiedAt: DateTime.now().toUtc().toIso8601String(),
          bytes: bytes,
        ),
      );
    }

    if (uploads.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_empty',
        code: SyncErrorCode.invalidConfig,
      );
    }

    final previousIndex = await _loadPlainIndex(
      client,
      baseUrl,
      rootPath,
      accountId,
    );
    if (previousIndex != null) {
      final previousPaths = previousIndex.files
          .map((entry) => entry.path)
          .toSet();
      final nextPaths = uploads.map((entry) => entry.path).toSet();
      final removedPaths = previousPaths.difference(nextPaths);
      for (final path in removedPaths) {
        await _delete(client, _plainFileUri(baseUrl, rootPath, accountId, path));
      }
    }

    final baseSegments = <String>[
      ..._splitPath(rootPath),
      'accounts',
      accountId,
      _backupDir,
      _backupVersion,
    ];
    final requiredDirs = <String>{};
    for (final upload in uploads) {
      final dir = _parentDirectory(upload.path);
      if (dir.isEmpty) continue;
      requiredDirs.add(dir);
    }
    final sortedDirs = requiredDirs.toList()..sort();
    for (final dir in sortedDirs) {
      await _ensureCollectionPath(
        client,
        baseUrl,
        [...baseSegments, ..._splitPath(dir)],
      );
    }

    for (final upload in uploads) {
      final bytes = upload.bytes ??
          await _readLocalEntryBytes(fileSystem, upload.entry);
      await _putBytes(
        client,
        _plainFileUri(baseUrl, rootPath, accountId, upload.path),
        bytes,
      );
    }

    final now = DateTime.now();
    final indexPayload = _buildPlainBackupIndexPayload(uploads, now);
    await _putJson(
      client,
      _plainIndexUri(baseUrl, rootPath, accountId),
      indexPayload,
    );
  }

  String _parentDirectory(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/').trim();
    final idx = normalized.lastIndexOf('/');
    if (idx <= 0) return '';
    return normalized.substring(0, idx);
  }

  Future<Uint8List> _readLocalEntryBytes(
    LocalLibraryFileSystem? fileSystem,
    LocalLibraryFileEntry? entry,
  ) async {
    if (fileSystem == null || entry == null) {
      throw SyncError(
        code: SyncErrorCode.dataCorrupt,
        retryable: false,
        message: 'BACKUP_FILE_MISSING',
      );
    }
    final builder = BytesBuilder(copy: false);
    final stream = await fileSystem.openReadStream(
      entry,
      bufferSize: _chunkSize,
    );
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  Future<_PlainBackupIndex?> _loadPlainIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final bytes = await _getBytes(
      client,
      _plainIndexUri(baseUrl, rootPath, accountId),
    );
    if (bytes == null) return null;
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    return _PlainBackupIndex.fromJson(decoded);
  }

  Map<String, dynamic> _buildPlainBackupIndexPayload(
    List<_PlainBackupFileUpload> uploads,
    DateTime now,
  ) {
    return {
      'schemaVersion': 1,
      'generatedAt': now.toUtc().toIso8601String(),
      'files':
          uploads
              .map(
                (entry) => {
                  'path': entry.path,
                  'size': entry.size,
                  if (entry.modifiedAt != null)
                    'modifiedAt': entry.modifiedAt,
                },
              )
              .toList(growable: false),
    };
  }

  Future<_SnapshotBuildResult> _buildSnapshot({
    required LocalLibrary? localLibrary,
    required bool includeMemos,
    required Map<String, dynamic>? configPayload,
    required WebDavBackupIndex index,
    required SecretKey masterKey,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required String snapshotId,
  }) async {
    final knownObjects = <String>{...index.objects.keys};
    final newObjectSizes = <String, int>{};
    final files = <WebDavBackupFileEntry>[];

    if (includeMemos) {
      final targetLibrary = localLibrary;
      if (targetLibrary == null) {
        throw _keyedError(
          'legacy.msg_export_path_not_set',
          code: SyncErrorCode.invalidConfig,
        );
      }
      final fileSystem = LocalLibraryFileSystem(targetLibrary);
      await fileSystem.ensureStructure();
      final entries = await fileSystem.listAllFiles();
      entries.sort((a, b) => a.relativePath.compareTo(b.relativePath));

      for (final entry in entries) {
        final objects = <String>[];
        final stream = await fileSystem.openReadStream(
          entry,
          bufferSize: _chunkSize,
        );
        await for (final chunk in _chunkStream(stream)) {
          final hash = crypto.sha256.convert(chunk).toString();
          objects.add(hash);
          if (!knownObjects.contains(hash)) {
            final objectKey = await _deriveObjectKey(masterKey, hash);
            final encrypted = await _encryptBytes(objectKey, chunk);
            await _putBytes(
              client,
              _objectUri(baseUrl, rootPath, accountId, hash),
              encrypted,
            );
            knownObjects.add(hash);
            newObjectSizes[hash] = chunk.length;
          }
        }
        files.add(
          WebDavBackupFileEntry(
            path: entry.relativePath,
            size: entry.length,
            objects: objects,
            modifiedAt: entry.lastModified?.toUtc().toIso8601String(),
          ),
        );
      }
    }

    if (configPayload != null) {
      final payloadBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(configPayload)),
      );
      final hash = crypto.sha256.convert(payloadBytes).toString();
      if (!knownObjects.contains(hash)) {
        final objectKey = await _deriveObjectKey(masterKey, hash);
        final encrypted = await _encryptBytes(objectKey, payloadBytes);
        await _putBytes(
          client,
          _objectUri(baseUrl, rootPath, accountId, hash),
          encrypted,
        );
        knownObjects.add(hash);
        newObjectSizes[hash] = payloadBytes.length;
      }
      files.add(
        WebDavBackupFileEntry(
          path: _backupSettingsSnapshotPath,
          size: payloadBytes.length,
          objects: [hash],
          modifiedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    }

    final snapshot = WebDavBackupSnapshot(
      schemaVersion: 1,
      id: snapshotId,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      files: files,
    );
    return _SnapshotBuildResult(
      snapshot: snapshot,
      newObjectSizes: newObjectSizes,
    );
  }

  WebDavBackupIndex _applySnapshotToIndex(
    WebDavBackupIndex index,
    WebDavBackupSnapshot snapshot,
    DateTime now,
    Map<String, int> newObjectSizes,
  ) {
    final totalBytes = snapshot.files.fold<int>(
      0,
      (sum, entry) => sum + entry.size,
    );
    final memosCount = _countMemosInSnapshot(snapshot);
    final nextSnapshots = [...index.snapshots];
    nextSnapshots.add(
      WebDavBackupSnapshotInfo(
        id: snapshot.id,
        createdAt: snapshot.createdAt,
        memosCount: memosCount,
        fileCount: snapshot.files.length,
        totalBytes: totalBytes,
      ),
    );
    final updatedObjects = <String, WebDavBackupObjectInfo>{...index.objects};
    final snapshotObjectSet = <String>{};
    for (final file in snapshot.files) {
      snapshotObjectSet.addAll(file.objects);
    }
    for (final hash in snapshotObjectSet) {
      final existing = updatedObjects[hash];
      if (existing == null) {
        final size = newObjectSizes[hash] ?? 0;
        updatedObjects[hash] = WebDavBackupObjectInfo(size: size, refs: 1);
      } else {
        updatedObjects[hash] = WebDavBackupObjectInfo(
          size: existing.size,
          refs: existing.refs + 1,
        );
      }
    }

    return WebDavBackupIndex(
      schemaVersion: 1,
      updatedAt: now.toUtc().toIso8601String(),
      snapshots: nextSnapshots,
      objects: updatedObjects,
    );
  }

  Future<WebDavBackupIndex> _applyRetention({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required WebDavBackupIndex index,
    required int retention,
  }) async {
    if (retention <= 0) return index;
    if (index.snapshots.length <= retention) return index;

    final sorted = [...index.snapshots];
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final toRemove = sorted.take(sorted.length - retention).toList();
    if (toRemove.isEmpty) return index;

    final objectRefs = <String, WebDavBackupObjectInfo>{...index.objects};
    final remainingSnapshots = index.snapshots
        .where((s) => !toRemove.any((r) => r.id == s.id))
        .toList();
    for (final snapshot in toRemove) {
      final data = await _loadSnapshot(
        client: client,
        baseUrl: baseUrl,
        rootPath: rootPath,
        accountId: accountId,
        masterKey: masterKey,
        snapshotId: snapshot.id,
      );
      final snapshotObjects = <String>{};
      for (final file in data.files) {
        snapshotObjects.addAll(file.objects);
      }
      for (final hash in snapshotObjects) {
        final info = objectRefs[hash];
        if (info == null) continue;
        final nextRefs = info.refs - 1;
        if (nextRefs <= 0) {
          objectRefs.remove(hash);
          await _delete(client, _objectUri(baseUrl, rootPath, accountId, hash));
        } else {
          objectRefs[hash] = WebDavBackupObjectInfo(
            size: info.size,
            refs: nextRefs,
          );
        }
      }
      await _delete(
        client,
        _snapshotUri(baseUrl, rootPath, accountId, snapshot.id),
      );
    }

    return WebDavBackupIndex(
      schemaVersion: 1,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      snapshots: remainingSnapshots,
      objects: objectRefs,
    );
  }

  Future<void> _uploadSnapshot(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
    WebDavBackupSnapshot snapshot,
  ) async {
    final key = await _deriveSubKey(masterKey, 'snapshot:${snapshot.id}');
    final bytes = await _encryptJson(key, snapshot.toJson());
    await _putBytes(
      client,
      _snapshotUri(baseUrl, rootPath, accountId, snapshot.id),
      bytes,
    );
  }

  Future<void> _saveIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
    WebDavBackupIndex index,
  ) async {
    final key = await _deriveSubKey(masterKey, 'index');
    final bytes = await _encryptJson(key, index.toJson());
    await _putBytes(client, _indexUri(baseUrl, rootPath, accountId), bytes);
  }

  Future<WebDavBackupIndex> _loadIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
  ) async {
    final data = await _getBytes(
      client,
      _indexUri(baseUrl, rootPath, accountId),
    );
    if (data == null) return WebDavBackupIndex.empty;
    final key = await _deriveSubKey(masterKey, 'index');
    final decoded = await _decryptJson(key, data);
    if (decoded is Map) {
      return WebDavBackupIndex.fromJson(decoded.cast<String, dynamic>());
    }
    return WebDavBackupIndex.empty;
  }

  Future<WebDavBackupSnapshot> _loadSnapshot({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required String snapshotId,
  }) async {
    final data = await _getBytes(
      client,
      _snapshotUri(baseUrl, rootPath, accountId, snapshotId),
    );
    if (data == null) {
      throw _keyedError(
        'legacy.webdav.snapshot_missing',
        code: SyncErrorCode.dataCorrupt,
      );
    }
    final key = await _deriveSubKey(masterKey, 'snapshot:$snapshotId');
    final decoded = await _decryptJson(key, data);
    if (decoded is Map) {
      return WebDavBackupSnapshot.fromJson(decoded.cast<String, dynamic>());
    }
    throw _keyedError(
      'legacy.webdav.snapshot_corrupted',
      code: SyncErrorCode.dataCorrupt,
    );
  }

  Future<void> _restoreFile({
    required WebDavBackupFileEntry entry,
    required LocalLibraryFileSystem fileSystem,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
  }) async {
    final controller = StreamController<Uint8List>();
    final writeFuture = fileSystem.writeFileFromChunks(
      entry.path,
      controller.stream,
      mimeType: _guessMimeType(entry.path),
    );

    if (entry.objects.isEmpty) {
      await controller.close();
      await writeFuture;
      return;
    }

    for (final hash in entry.objects) {
      final objectData = await _getBytes(
        client,
        _objectUri(baseUrl, rootPath, accountId, hash),
      );
      if (objectData == null) {
        throw _keyedError(
          'legacy.webdav.object_missing',
          code: SyncErrorCode.dataCorrupt,
        );
      }
      final key = await _deriveObjectKey(masterKey, hash);
      final plain = await _decryptBytes(key, objectData);
      controller.add(plain);
    }

    await controller.close();
    await writeFuture;
  }

  Future<WebDavBackupConfig> _loadOrCreateConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    String password,
  ) async {
    final existing = await _loadConfig(client, baseUrl, rootPath, accountId);
    if (existing != null) return existing;
    final config = await _createConfig(password);
    await _saveConfig(client, baseUrl, rootPath, accountId, config);
    return config;
  }

  Future<WebDavBackupConfig?> _loadConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final uri = _configUri(baseUrl, rootPath, accountId);
    final res = await client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SyncError(
        code: res.statusCode >= 500
            ? SyncErrorCode.server
            : SyncErrorCode.unknown,
        retryable: res.statusCode >= 500,
        message: 'WebDAV config fetch failed (HTTP ${res.statusCode})',
        httpStatus: res.statusCode,
      );
    }
    final decoded = jsonDecode(res.bodyText);
    if (decoded is Map) {
      return WebDavBackupConfig.fromJson(decoded.cast<String, dynamic>());
    }
    throw _keyedError(
      'legacy.webdav.config_corrupted',
      code: SyncErrorCode.dataCorrupt,
    );
  }

  Future<void> _saveConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    WebDavBackupConfig config,
  ) {
    return _putJson(
      client,
      _configUri(baseUrl, rootPath, accountId),
      config.toJson(),
    );
  }

  Future<WebDavBackupConfig> _createConfig(String password) async {
    final masterKey = _randomBytes(32);
    final passwordBundle = await _buildWrappedKeyBundle(
      secret: password,
      masterKey: masterKey,
    );
    return WebDavBackupConfig(
      schemaVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      kdf: passwordBundle.kdf,
      wrappedKey: passwordBundle.wrappedKey,
    );
  }

  Future<_CreatedConfigWithRecovery> _createConfigWithRecovery(
    String password,
  ) async {
    final masterKey = _randomBytes(32);
    final passwordBundle = await _buildWrappedKeyBundle(
      secret: password,
      masterKey: masterKey,
    );
    final recoveryCode = _generateRecoveryCode();
    final recoveryBundle = await _buildWrappedKeyBundle(
      secret: _normalizeRecoveryCode(recoveryCode),
      masterKey: masterKey,
    );
    final config = WebDavBackupConfig(
      schemaVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      kdf: passwordBundle.kdf,
      wrappedKey: passwordBundle.wrappedKey,
      recovery: WebDavBackupRecovery(
        kdf: recoveryBundle.kdf,
        wrappedKey: recoveryBundle.wrappedKey,
      ),
    );
    return _CreatedConfigWithRecovery(
      config: config,
      recoveryCode: recoveryCode,
    );
  }

  Future<_RecoveryBundle> _buildRecoveryBundle(SecretKey masterKey) async {
    final masterBytes = await masterKey.extractBytes();
    final recoveryCode = _generateRecoveryCode();
    final recoveryBundle = await _buildWrappedKeyBundle(
      secret: _normalizeRecoveryCode(recoveryCode),
      masterKey: masterBytes,
    );
    return _RecoveryBundle(
      recoveryCode: recoveryCode,
      recovery: WebDavBackupRecovery(
        kdf: recoveryBundle.kdf,
        wrappedKey: recoveryBundle.wrappedKey,
      ),
    );
  }

  Future<_WrappedKeyBundle> _buildWrappedKeyBundle({
    required String secret,
    required List<int> masterKey,
  }) async {
    final normalizedSecret = secret.trim();
    if (normalizedSecret.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_password_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kdf = _buildKdf();
    final kek = await _deriveKeyFromPassword(normalizedSecret, kdf);
    final box = await _cipher.encrypt(
      masterKey,
      secretKey: kek,
      nonce: _randomBytes(_nonceLength),
    );
    return _WrappedKeyBundle(
      kdf: kdf,
      wrappedKey: WebDavBackupWrappedKey(
        nonce: base64Encode(box.nonce),
        cipherText: base64Encode(box.cipherText),
        mac: base64Encode(box.mac.bytes),
      ),
    );
  }

  WebDavBackupKdf _buildKdf() {
    final salt = _randomBytes(16);
    return WebDavBackupKdf(
      salt: base64Encode(salt),
      iterations: WebDavBackupKdf.defaults.iterations,
      hash: WebDavBackupKdf.defaults.hash,
      length: WebDavBackupKdf.defaults.length,
    );
  }

  String _generateRecoveryCode() {
    final bytes = _randomBytes(20);
    final compact = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return _formatRecoveryCode(compact);
  }

  String _normalizeRecoveryCode(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  }

  String _formatRecoveryCode(String compact) {
    if (compact.isEmpty) return compact;
    final groups = <String>[];
    for (var i = 0; i < compact.length; i += 4) {
      final end = i + 4;
      groups.add(
        compact.substring(i, end > compact.length ? compact.length : end),
      );
    }
    return groups.join('-');
  }

  Future<SecretKey> _resolveMasterKey(
    String password,
    WebDavBackupConfig config,
  ) async {
    final kdf = config.kdf;
    if (kdf.salt.isEmpty) {
      throw _keyedError(
        'legacy.webdav.config_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kek = await _deriveKeyFromPassword(password, kdf);
    final wrapped = config.wrappedKey;
    try {
      final box = SecretBox(
        base64Decode(wrapped.cipherText),
        nonce: base64Decode(wrapped.nonce),
        mac: Mac(base64Decode(wrapped.mac)),
      );
      final clear = await _cipher.decrypt(box, secretKey: kek);
      return SecretKey(clear);
    } catch (_) {
      throw _keyedError(
        'legacy.webdav.password_invalid',
        code: SyncErrorCode.authFailed,
      );
    }
  }

  Future<SecretKey> _resolveMasterKeyWithRecoveryCode(
    String recoveryCode,
    WebDavBackupConfig config,
  ) async {
    final recovery = config.recovery;
    if (recovery == null) {
      throw _keyedError(
        'legacy.webdav.recovery_not_configured',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final normalizedCode = _normalizeRecoveryCode(recoveryCode);
    if (normalizedCode.isEmpty) {
      throw _keyedError(
        'legacy.webdav.recovery_code_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kdf = recovery.kdf;
    if (kdf.salt.isEmpty) {
      throw _keyedError(
        'legacy.webdav.config_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kek = await _deriveKeyFromPassword(normalizedCode, kdf);
    final wrapped = recovery.wrappedKey;
    try {
      final box = SecretBox(
        base64Decode(wrapped.cipherText),
        nonce: base64Decode(wrapped.nonce),
        mac: Mac(base64Decode(wrapped.mac)),
      );
      final clear = await _cipher.decrypt(box, secretKey: kek);
      return SecretKey(clear);
    } catch (_) {
      throw _keyedError(
        'legacy.webdav.recovery_code_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
  }

  Future<SecretKey> _deriveKeyFromPassword(
    String password,
    WebDavBackupKdf kdf,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdf.iterations,
      bits: kdf.length * 8,
    );
    final salt = base64Decode(kdf.salt);
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  Future<SecretKey> _deriveSubKey(SecretKey masterKey, String info) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: masterKey,
      nonce: utf8.encode('MemoFlowBackup'),
      info: utf8.encode(info),
    );
  }

  Future<SecretKey> _deriveObjectKey(SecretKey masterKey, String objectHash) {
    return _deriveSubKey(masterKey, 'object:$objectHash');
  }

  Future<Uint8List> _encryptBytes(SecretKey key, List<int> plain) async {
    final box = await _cipher.encrypt(
      plain,
      secretKey: key,
      nonce: _randomBytes(_nonceLength),
    );
    final bytes = Uint8List(
      box.nonce.length + box.cipherText.length + box.mac.bytes.length,
    );
    bytes.setRange(0, box.nonce.length, box.nonce);
    bytes.setRange(
      box.nonce.length,
      box.nonce.length + box.cipherText.length,
      box.cipherText,
    );
    bytes.setRange(
      box.nonce.length + box.cipherText.length,
      box.nonce.length + box.cipherText.length + box.mac.bytes.length,
      box.mac.bytes,
    );
    return bytes;
  }

  Future<Uint8List> _decryptBytes(SecretKey key, List<int> combined) async {
    if (combined.length < _nonceLength + _macLength) {
      throw _keyedError(
        'legacy.webdav.data_corrupted',
        code: SyncErrorCode.dataCorrupt,
      );
    }
    final nonce = combined.sublist(0, _nonceLength);
    final macBytes = combined.sublist(combined.length - _macLength);
    final cipherText = combined.sublist(
      _nonceLength,
      combined.length - _macLength,
    );
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final plain = await _cipher.decrypt(box, secretKey: key);
    return Uint8List.fromList(plain);
  }

  Future<Uint8List> _encryptJson(
    SecretKey key,
    Map<String, dynamic> json,
  ) async {
    final encoded = jsonEncode(json);
    return _encryptBytes(key, utf8.encode(encoded));
  }

  Future<dynamic> _decryptJson(SecretKey key, List<int> data) async {
    final plain = await _decryptBytes(key, data);
    return jsonDecode(utf8.decode(plain, allowMalformed: true));
  }

  Future<void> _putJson(
    WebDavClient client,
    Uri uri,
    Map<String, dynamic> json,
  ) async {
    final encoded = utf8.encode(jsonEncode(json));
    await _putBytes(client, uri, encoded);
  }

  Future<void> _putBytes(WebDavClient client, Uri uri, List<int> bytes) async {
    final res = await client.put(uri, body: bytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        method: 'PUT',
        uri: uri,
      );
    }
  }

  Future<Uint8List?> _getBytes(WebDavClient client, Uri uri) async {
    final res = await client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        method: 'GET',
        uri: uri,
      );
    }
    return Uint8List.fromList(res.bytes);
  }

  Future<void> _delete(WebDavClient client, Uri uri) async {
    final res = await client.delete(uri);
    if (res.statusCode == 404) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        method: 'DELETE',
        uri: uri,
      );
    }
  }

  String _buildSnapshotId(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final utc = now.toUtc();
    return '${utc.year}${two(utc.month)}${two(utc.day)}_${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }

  Uri _configUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, _backupConfigFile),
    );
  }

  Uri _indexUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, _backupIndexFile),
    );
  }

  Uri _objectUri(Uri baseUrl, String rootPath, String accountId, String hash) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, '$_backupObjectsDir/$hash.bin'),
    );
  }

  Uri _snapshotUri(
    Uri baseUrl,
    String rootPath,
    String accountId,
    String snapshotId,
  ) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(
        accountId,
        '$_backupSnapshotsDir/$snapshotId.enc',
      ),
    );
  }

  String _backupBase(String accountId, String relative) {
    return 'accounts/$accountId/$_backupDir/$_backupVersion/$relative';
  }

  String _plainBase(String accountId, String relative) {
    return _backupBase(accountId, relative);
  }

  Uri _plainIndexUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _plainBase(accountId, _plainBackupIndexFile),
    );
  }

  Uri _plainFileUri(
    Uri baseUrl,
    String rootPath,
    String accountId,
    String relativePath,
  ) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _plainBase(accountId, relativePath),
    );
  }

  Future<void> _ensureBackupCollections(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final segments = <String>[
      ..._splitPath(rootPath),
      'accounts',
      accountId,
      _backupDir,
      _backupVersion,
    ];
    await _ensureCollectionPath(client, baseUrl, segments);
    await _ensureCollectionPath(client, baseUrl, [
      ...segments,
      _backupObjectsDir,
    ]);
    await _ensureCollectionPath(client, baseUrl, [
      ...segments,
      _backupSnapshotsDir,
    ]);
  }

  Future<void> _ensureCollectionPath(
    WebDavClient client,
    Uri baseUrl,
    List<String> segments,
  ) async {
    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      final uri = joinWebDavUri(
        baseUrl: baseUrl,
        rootPath: '',
        relativePath: current,
      );
      final res = await client.mkcol(uri);
      if (res.statusCode == 201 ||
          res.statusCode == 405 ||
          res.statusCode == 200) {
        continue;
      }
      if (res.statusCode == 409) {
        continue;
      }
    }
  }

  List<String> _splitPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split('/')
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
  }

  WebDavClient _buildClient(WebDavSettings settings, Uri baseUrl) {
    return _clientFactory(
      baseUrl: baseUrl,
      settings: settings,
      logWriter: _logWriter,
    );
  }

  Uri _parseBaseUrl(String raw) {
    final baseUrl = Uri.tryParse(raw.trim());
    if (baseUrl == null || !baseUrl.hasScheme || !baseUrl.hasAuthority) {
      throw _keyedError(
        'legacy.webdav.server_url_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    return baseUrl;
  }

  Stream<Uint8List> _chunkStream(Stream<Uint8List> input) async* {
    final buffer = <int>[];
    await for (final data in input) {
      buffer.addAll(data);
      while (buffer.length >= _chunkSize) {
        final chunk = Uint8List.fromList(buffer.sublist(0, _chunkSize));
        buffer.removeRange(0, _chunkSize);
        yield chunk;
      }
    }
    if (buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  }

  Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  Duration _scheduleDuration(WebDavBackupSchedule schedule) {
    return switch (schedule) {
      WebDavBackupSchedule.daily => const Duration(days: 1),
      WebDavBackupSchedule.weekly => const Duration(days: 7),
      WebDavBackupSchedule.monthly => const Duration(days: 30),
      WebDavBackupSchedule.onOpen => Duration.zero,
      WebDavBackupSchedule.manual => Duration.zero,
    };
  }

  DateTime _addMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = min(date.day, lastDayOfMonth);
    return DateTime(
      year,
      month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  bool _isBackupDue(DateTime? last, WebDavBackupSchedule schedule) {
    if (schedule == WebDavBackupSchedule.manual) return false;
    if (schedule == WebDavBackupSchedule.onOpen) return true;
    if (last == null) return true;
    if (schedule == WebDavBackupSchedule.monthly) {
      final next = _addMonths(last, 1);
      final now = DateTime.now();
      return !now.isBefore(next);
    }
    final diff = DateTime.now().difference(last);
    return diff >= _scheduleDuration(schedule);
  }

  DateTime? _parseIso(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  LocalLibraryScanService? _scanServiceFor(LocalLibrary library) {
    final factory = _scanServiceFactory;
    if (factory != null) return factory(library);
    return LocalLibraryScanService(
      db: _db,
      fileSystem: LocalLibraryFileSystem(library),
      attachmentStore: _attachmentStore,
    );
  }

  SyncError _keyedError(
    String key, {
    SyncErrorCode code = SyncErrorCode.unknown,
    bool retryable = false,
    Map<String, String>? params,
  }) {
    return SyncError(
      code: code,
      retryable: retryable,
      presentationKey: key,
      presentationParams: params,
    );
  }

  SyncError _httpError({
    required int statusCode,
    required String method,
    required Uri uri,
  }) {
    final code = switch (statusCode) {
      401 => SyncErrorCode.authFailed,
      403 => SyncErrorCode.permission,
      409 => SyncErrorCode.conflict,
      >= 500 => SyncErrorCode.server,
      _ => SyncErrorCode.unknown,
    };
    return SyncError(
      code: code,
      retryable: statusCode >= 500,
      message: 'Bad state: WebDAV $method failed (HTTP $statusCode)',
      httpStatus: statusCode,
      requestMethod: method,
      requestPath: uri.toString(),
    );
  }

  SyncError _mapUnexpectedError(Object error) {
    if (error is SyncError) return error;
    if (error is SocketException ||
        error is HandshakeException ||
        error is HttpException) {
      return SyncError(
        code: SyncErrorCode.network,
        retryable: true,
        message: error.toString(),
      );
    }
    return SyncError(
      code: SyncErrorCode.unknown,
      retryable: false,
      message: error.toString(),
    );
  }

  Future<String?> _resolvePassword(String? override) async {
    if (override != null && override.trim().isNotEmpty) return override;
    return _passwordRepository.read();
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}

WebDavClient _defaultBackupClientFactory({
  required Uri baseUrl,
  required WebDavSettings settings,
  void Function(DebugLogEntry entry)? logWriter,
}) {
  return WebDavClient(
    baseUrl: baseUrl,
    username: settings.username,
    password: settings.password,
    authMode: settings.authMode,
    ignoreBadCert: settings.ignoreTlsErrors,
    logWriter: logWriter,
  );
}

class _SnapshotBuildResult {
  const _SnapshotBuildResult({
    required this.snapshot,
    required this.newObjectSizes,
  });

  final WebDavBackupSnapshot snapshot;
  final Map<String, int> newObjectSizes;
}

class _PlainBackupIndex {
  const _PlainBackupIndex({required this.files});

  final List<_PlainBackupFile> files;

  static _PlainBackupIndex? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final filesRaw = raw['files'];
    if (filesRaw is! List) return null;
    final files = <_PlainBackupFile>[];
    for (final item in filesRaw) {
      if (item is Map) {
        final entry = _PlainBackupFile.fromJson(
          item.cast<String, dynamic>(),
        );
        if (entry != null) {
          files.add(entry);
        }
      }
    }
    return _PlainBackupIndex(files: files);
  }
}

class _PlainBackupFile {
  const _PlainBackupFile({
    required this.path,
    required this.size,
    this.modifiedAt,
  });

  final String path;
  final int size;
  final String? modifiedAt;

  static _PlainBackupFile? fromJson(Map<String, dynamic> json) {
    final rawPath = json['path'];
    if (rawPath is! String || rawPath.trim().isEmpty) return null;
    final rawSize = json['size'];
    int size = 0;
    if (rawSize is int) {
      size = rawSize;
    } else if (rawSize is num) {
      size = rawSize.toInt();
    } else if (rawSize is String) {
      size = int.tryParse(rawSize.trim()) ?? 0;
    }
    final rawModified = json['modifiedAt'];
    return _PlainBackupFile(
      path: rawPath,
      size: size,
      modifiedAt: rawModified is String && rawModified.trim().isNotEmpty
          ? rawModified
          : null,
    );
  }
}

class _PlainBackupFileUpload {
  const _PlainBackupFileUpload({
    required this.path,
    required this.size,
    this.modifiedAt,
    this.entry,
    this.bytes,
  });

  final String path;
  final int size;
  final String? modifiedAt;
  final LocalLibraryFileEntry? entry;
  final Uint8List? bytes;
}

class _WrappedKeyBundle {
  const _WrappedKeyBundle({required this.kdf, required this.wrappedKey});

  final WebDavBackupKdf kdf;
  final WebDavBackupWrappedKey wrappedKey;
}

class _RecoveryBundle {
  const _RecoveryBundle({required this.recoveryCode, required this.recovery});

  final String recoveryCode;
  final WebDavBackupRecovery recovery;
}

class _CreatedConfigWithRecovery {
  const _CreatedConfigWithRecovery({
    required this.config,
    required this.recoveryCode,
  });

  final WebDavBackupConfig config;
  final String recoveryCode;
}

class _BackupExportAborted implements Exception {
  const _BackupExportAborted(this.error);

  final SyncError? error;
}
