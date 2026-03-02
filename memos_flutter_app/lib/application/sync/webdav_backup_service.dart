import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
import '../../data/models/image_bed_settings.dart';
import '../../data/models/local_library.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_backup_state.dart';
import '../../data/models/webdav_export_signature.dart';
import '../../data/models/webdav_export_status.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/logs/webdav_backup_progress_tracker.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../../data/settings/webdav_backup_password_repository.dart';
import '../../data/settings/webdav_backup_state_repository.dart';
import '../../data/settings/webdav_vault_password_repository.dart';
import '../../data/webdav/webdav_client.dart';
import '../../state/app_lock_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/reminder_settings_provider.dart';
import 'local_library_scan_service.dart';
import 'sync_error.dart';
import 'sync_types.dart';
import 'webdav_sync_service.dart';
import 'webdav_vault_service.dart';

enum WebDavBackupExportIssueKind { memo, attachment }

enum WebDavBackupExportAction { retry, skip, abort }

enum WebDavExportCleanupStatus { cleaned, notFound, blocked }

enum WebDavBackupConfigType {
  preferences,
  aiSettings,
  reminderSettings,
  imageBedSettings,
  locationSettings,
  templateSettings,
  appLock,
  noteDraft,
  webdavSettings,
}

class WebDavBackupConfigBundle {
  const WebDavBackupConfigBundle({
    this.preferences,
    this.aiSettings,
    this.reminderSettings,
    this.imageBedSettings,
    this.locationSettings,
    this.templateSettings,
    this.appLockSnapshot,
    this.noteDraft,
    this.webDavSettings,
  });

  final AppPreferences? preferences;
  final AiSettings? aiSettings;
  final ReminderSettings? reminderSettings;
  final ImageBedSettings? imageBedSettings;
  final LocationSettings? locationSettings;
  final MemoTemplateSettings? templateSettings;
  final AppLockSnapshot? appLockSnapshot;
  final String? noteDraft;
  final WebDavSettings? webDavSettings;

  bool get isEmpty =>
      preferences == null &&
      aiSettings == null &&
      reminderSettings == null &&
      imageBedSettings == null &&
      locationSettings == null &&
      templateSettings == null &&
      appLockSnapshot == null &&
      noteDraft == null &&
      webDavSettings == null;
}

class _BackupConfigFile {
  const _BackupConfigFile({
    required this.type,
    required this.path,
    required this.bytes,
  });

  final WebDavBackupConfigType type;
  final String path;
  final Uint8List bytes;
}

typedef WebDavBackupConfigDecisionHandler =
    Future<Set<WebDavBackupConfigType>> Function(
      WebDavBackupConfigBundle bundle,
    );

const _autoRestoreConfigTypes = <WebDavBackupConfigType>{
  WebDavBackupConfigType.preferences,
  WebDavBackupConfigType.reminderSettings,
  WebDavBackupConfigType.templateSettings,
  WebDavBackupConfigType.locationSettings,
};

const _confirmRestoreConfigTypes = <WebDavBackupConfigType>{
  WebDavBackupConfigType.webdavSettings,
  WebDavBackupConfigType.imageBedSettings,
  WebDavBackupConfigType.appLock,
  WebDavBackupConfigType.aiSettings,
};

const _exportOnlyConfigTypes = <WebDavBackupConfigType>{
  WebDavBackupConfigType.noteDraft,
};

const _safeBackupConfigTypes = <WebDavBackupConfigType>{
  WebDavBackupConfigType.preferences,
  WebDavBackupConfigType.reminderSettings,
  WebDavBackupConfigType.templateSettings,
  WebDavBackupConfigType.locationSettings,
};

const _fullBackupConfigTypes = <WebDavBackupConfigType>{
  WebDavBackupConfigType.preferences,
  WebDavBackupConfigType.reminderSettings,
  WebDavBackupConfigType.templateSettings,
  WebDavBackupConfigType.locationSettings,
  WebDavBackupConfigType.webdavSettings,
  WebDavBackupConfigType.imageBedSettings,
  WebDavBackupConfigType.appLock,
  WebDavBackupConfigType.noteDraft,
  WebDavBackupConfigType.aiSettings,
};

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
    required WebDavVaultService vaultService,
    required WebDavVaultPasswordRepository vaultPasswordRepository,
    WebDavSyncLocalAdapter? configAdapter,
    WebDavBackupProgressTracker? progressTracker,
    LocalLibraryScanService Function(LocalLibrary library)? scanServiceFactory,
    WebDavBackupClientFactory? clientFactory,
    void Function(DebugLogEntry entry)? logWriter,
  }) : _db = db,
       _attachmentStore = attachmentStore,
       _stateRepository = stateRepository,
       _passwordRepository = passwordRepository,
       _vaultService = vaultService,
       _vaultPasswordRepository = vaultPasswordRepository,
       _configAdapter = configAdapter,
       _progressTracker = progressTracker,
       _scanServiceFactory = scanServiceFactory,
       _clientFactory = clientFactory ?? _defaultBackupClientFactory,
       _logWriter = logWriter;

  final AppDatabase _db;
  final LocalAttachmentStore _attachmentStore;
  final WebDavBackupStateRepository _stateRepository;
  final WebDavBackupPasswordRepository _passwordRepository;
  final WebDavVaultService _vaultService;
  final WebDavVaultPasswordRepository _vaultPasswordRepository;
  final WebDavSyncLocalAdapter? _configAdapter;
  final WebDavBackupProgressTracker? _progressTracker;
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
  static const _backupConfigDir = 'config';
  static const _backupSettingsSnapshotPath = 'config/webdav_settings.json';
  static const _backupPreferencesSnapshotPath = 'config/preferences.json';
  static const _backupAiSettingsSnapshotPath = 'config/ai_settings.json';
  static const _backupReminderSnapshotPath = 'config/reminder_settings.json';
  static const _backupImageBedSnapshotPath = 'config/image_bed.json';
  static const _backupLocationSnapshotPath = 'config/location_settings.json';
  static const _backupTemplateSnapshotPath = 'config/template_settings.json';
  static const _backupAppLockSnapshotPath = 'config/app_lock.json';
  static const _backupNoteDraftSnapshotPath = 'config/note_draft.json';
  static const _backupManifestFile = 'manifest.json';
  static const _plainBackupIndexFile = 'index.json';
  static const _exportEncSignatureFile = '.memoflow_export_enc.json';
  static const _exportPlainSignatureFile = '.memoflow_export_plain.json';
  static const _exportStagingDir = '.memoflow_export_staging';
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

  void _startProgress(WebDavBackupProgressOperation operation) {
    _progressTracker?.start(operation: operation);
  }

  void _updateProgress({
    WebDavBackupProgressStage? stage,
    int? completed,
    int? total,
    String? currentPath,
    WebDavBackupProgressItemGroup? itemGroup,
  }) {
    _progressTracker?.update(
      stage: stage,
      completed: completed,
      total: total,
      currentPath: currentPath,
      itemGroup: itemGroup,
    );
  }

  Future<void> _waitIfPaused() async {
    final tracker = _progressTracker;
    if (tracker == null) return;
    await tracker.waitIfPaused();
  }

  void _finishProgress() {
    _progressTracker?.finish();
  }

  Future<void> _setWakelockEnabled(bool enabled) async {
    if (kIsWeb) return;
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
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
    final includeConfig =
        settings.backupConfigScope != WebDavBackupConfigScope.none;
    final includeMemos = settings.backupContentMemos;
    final usePlainBackup =
        settings.backupEncryptionMode == WebDavBackupEncryptionMode.plain;
    final useVault = settings.vaultEnabled && !usePlainBackup;
    final backupLibrary = includeMemos
        ? _resolveBackupLibrary(settings, activeLocalLibrary)
        : null;
    final usesMirrorLibrary = includeMemos && activeLocalLibrary == null;
    final exportEncrypted =
        includeMemos &&
        usesMirrorLibrary &&
        !usePlainBackup &&
        settings.backupExportEncrypted;
    final exportLibrary = usesMirrorLibrary ? backupLibrary : null;
    LocalLibrary? snapshotLibrary = backupLibrary;
    Directory? tempExportDir;
    _ExportWriter? exportWriter;
    DateTime? exportSuccessAt;
    DateTime? uploadSuccessAt;
    var plainExportCompleted = false;
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
    String? resolvedVaultPassword;
    if (!usePlainBackup) {
      if (useVault) {
        resolvedVaultPassword = await _resolveVaultPassword(password);
        if (resolvedVaultPassword == null ||
            resolvedVaultPassword.trim().isEmpty) {
          _logEvent('Backup skipped', detail: 'password_missing ($triggerLabel)');
          return const WebDavBackupMissingPassword();
        }
      } else {
        resolvedPassword = await _resolvePassword(password);
        if (resolvedPassword == null || resolvedPassword.trim().isEmpty) {
          _logEvent('Backup skipped', detail: 'password_missing ($triggerLabel)');
          return const WebDavBackupMissingPassword();
        }
      }
    }

    final exportedAt = DateTime.now().toUtc().toIso8601String();
    _logEvent(
      'Backup started',
      detail: 'mode=${usePlainBackup ? 'plain' : 'encrypted'} ($triggerLabel)',
    );
    _startProgress(WebDavBackupProgressOperation.backup);
    _updateProgress(stage: WebDavBackupProgressStage.preparing);
    await _setWakelockEnabled(true);
    try {
      if (includeMemos) {
        if (exportEncrypted) {
          final tempRoot = await getTemporaryDirectory();
          final parent = Directory(
            p.join(tempRoot.path, 'memoflow_backup_export'),
          );
          if (!await parent.exists()) {
            await parent.create(recursive: true);
          }
          tempExportDir = await parent.createTemp('export_');
          snapshotLibrary = LocalLibrary(
            key: 'webdav_backup_export',
            name: 'WebDAV Backup Export',
            rootPath: tempExportDir!.path,
          );
        }
        final exportedMemos = await _exportLocalLibraryForBackup(
          snapshotLibrary!,
          pruneToCurrentData: usesMirrorLibrary && !exportEncrypted,
          attachmentBaseUrl: attachmentBaseUrl,
          attachmentAuthHeader: attachmentAuthHeader,
          issueHandler: manual ? onExportIssue : null,
        );
        if (!exportEncrypted && usesMirrorLibrary) {
          exportSuccessAt = DateTime.now();
          plainExportCompleted = true;
        }
        if (exportedMemos > 0) {
          final memoFiles = await LocalLibraryFileSystem(
            snapshotLibrary!,
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
        WebDavBackupConfig? legacyConfig;
        String vaultKeyId = '';
        if (usePlainBackup) {
          await _backupPlain(
            settings: settings,
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            localLibrary: backupLibrary,
            includeMemos: includeMemos,
            configFiles:
                includeConfig
                    ? await _buildConfigFiles(
                        settings: settings,
                        scope: settings.backupConfigScope,
                        exportedAt: exportedAt,
                      )
                    : const [],
            exportedAt: exportedAt,
            backupMode: _resolveBackupMode(
              usesServerMode: activeLocalLibrary == null,
            ),
          );
          uploadSuccessAt = DateTime.now();
          if (plainExportCompleted && exportLibrary != null) {
            final fileSystem = LocalLibraryFileSystem(exportLibrary);
            final previousPlain = await _readExportSignature(
              fileSystem,
              _exportPlainSignatureFile,
              accountId,
            );
            final successAt = _resolveExportLastSuccessAt(
              exportAt: exportSuccessAt ?? now,
              uploadAt: uploadSuccessAt,
              webDavConfigured: settings.serverUrl.trim().isNotEmpty,
            );
            final signature = _buildExportSignature(
              mode: WebDavExportMode.plain,
              accountIdHash: accountId,
              snapshotId: '',
              exportFormat: WebDavExportFormat.full,
              vaultKeyId: '',
              createdAt: previousPlain?.createdAt,
              lastSuccessAt: successAt,
            );
            await _writeExportSignature(
              fileSystem,
              _exportPlainSignatureFile,
              signature,
            );
          }

          final previousState = await _stateRepository.read();
          await _stateRepository.write(
            previousState.copyWith(
              lastBackupAt: now.toUtc().toIso8601String(),
              lastSnapshotId: null,
              lastExportSuccessAt:
                  exportSuccessAt?.toUtc().toIso8601String() ??
                  previousState.lastExportSuccessAt,
              lastUploadSuccessAt:
                  uploadSuccessAt?.toUtc().toIso8601String() ??
                  previousState.lastUploadSuccessAt,
            ),
          );
          _updateProgress(
            stage: WebDavBackupProgressStage.completed,
            currentPath: '',
          );
          _logEvent('Backup completed', detail: 'mode=plain');
          return const WebDavBackupSuccess();
        }

        SecretKey masterKey;
        String? legacyPassword;
        String? vaultPassword;
        if (useVault) {
          vaultPassword = resolvedVaultPassword!;
          final vaultConfig = await _vaultService.loadConfig(
            settings: settings,
            accountKey: normalizedAccountKey,
          );
          if (vaultConfig == null) {
            throw _keyedError(
              'legacy.webdav.config_invalid',
              code: SyncErrorCode.invalidConfig,
            );
          }
          vaultKeyId = vaultConfig.keyId;
          masterKey = await _vaultService.resolveMasterKey(
            vaultPassword,
            vaultConfig,
          );
        } else {
          legacyPassword = resolvedPassword!;
          legacyConfig = await _loadOrCreateConfig(
            client,
            baseUrl,
            rootPath,
            accountId,
            legacyPassword,
          );
          masterKey = await _resolveMasterKey(legacyPassword, legacyConfig);
        }
        var index = await _loadIndex(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
        );
        if (exportEncrypted && exportLibrary != null) {
          exportWriter = _ExportWriter(
            library: exportLibrary,
            backupBaseDir: _backupBaseDir(accountId),
            exportStagingDir: _exportStagingDir,
            chunkSize: _chunkSize,
            logEvent: _logEvent,
          );
        }

        final snapshotId = _buildSnapshotId(now);
        final configFiles =
            includeConfig
                ? await _buildConfigFiles(
                    settings: settings,
                    scope: settings.backupConfigScope,
                    exportedAt: exportedAt,
                  )
                : const <_BackupConfigFile>[];
        final build = await _buildSnapshot(
          localLibrary: snapshotLibrary,
          includeMemos: includeMemos,
          configFiles: configFiles,
          index: index,
          masterKey: masterKey,
          client: client,
          baseUrl: baseUrl,
          rootPath: rootPath,
          accountId: accountId,
          snapshotId: snapshotId,
          exportedAt: exportedAt,
          backupMode: _resolveBackupMode(
            usesServerMode: activeLocalLibrary == null,
          ),
          exportWriter: exportWriter,
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

        if (exportWriter != null && exportLibrary != null) {
          final exportIndex = _buildExportIndexFromSnapshot(
            snapshot: snapshot,
            objectSizes: build.objectSizes,
            now: now,
          );
          final snapshotKey =
              await _deriveSubKey(masterKey, 'snapshot:${snapshot.id}');
          final snapshotBytes =
              await _encryptJson(snapshotKey, snapshot.toJson());
          await exportWriter.writeSnapshot(snapshot.id, snapshotBytes);

          final indexKey = await _deriveSubKey(masterKey, 'index');
          final indexBytes = await _encryptJson(indexKey, exportIndex.toJson());
          await exportWriter.writeIndex(indexBytes);

          if (legacyConfig != null) {
            final configBytes = Uint8List.fromList(
              utf8.encode(jsonEncode(legacyConfig!.toJson())),
            );
            await exportWriter.writeConfig(configBytes);
          }
          await exportWriter.commit();
          exportSuccessAt = DateTime.now();
          assert(() {
            final ok = _assertExportMirrorIntegritySync(
              exportLibrary: exportLibrary,
              exportIndex: exportIndex,
              backupBaseDir: _backupBaseDir(accountId),
            );
            if (!ok) {
              _logEvent('Export mirror integrity check failed');
            }
            return ok;
          }());

          final fileSystem = LocalLibraryFileSystem(exportLibrary);
          final previousEnc = await _readExportSignature(
            fileSystem,
            _exportEncSignatureFile,
            accountId,
          );
          final signature = _buildExportSignature(
            mode: WebDavExportMode.enc,
            accountIdHash: accountId,
            snapshotId: snapshot.id,
            exportFormat: WebDavExportFormat.full,
            vaultKeyId: vaultKeyId,
            createdAt: previousEnc?.createdAt,
            lastSuccessAt: exportSuccessAt!,
          );
          await _writeExportSignature(
            fileSystem,
            _exportEncSignatureFile,
            signature,
          );
        }

        await _waitIfPaused();
        _updateProgress(
          stage: WebDavBackupProgressStage.writingManifest,
          currentPath: '${_backupSnapshotsDir}/${snapshot.id}.enc',
          itemGroup: WebDavBackupProgressItemGroup.manifest,
        );
        await _uploadSnapshot(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
          snapshot,
        );
        await _waitIfPaused();
        _updateProgress(
          stage: WebDavBackupProgressStage.writingManifest,
          currentPath: _backupIndexFile,
          itemGroup: WebDavBackupProgressItemGroup.manifest,
        );
        await _saveIndex(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
          index,
        );

        uploadSuccessAt = DateTime.now();
        if (exportLibrary != null) {
          final fileSystem = LocalLibraryFileSystem(exportLibrary);
          if (exportWriter != null) {
            final previousEnc = await _readExportSignature(
              fileSystem,
              _exportEncSignatureFile,
              accountId,
            );
            if (previousEnc != null) {
              final successAt = _resolveExportLastSuccessAt(
                exportAt: exportSuccessAt ?? now,
                uploadAt: uploadSuccessAt,
                webDavConfigured: settings.serverUrl.trim().isNotEmpty,
              );
              final signature = _buildExportSignature(
                mode: WebDavExportMode.enc,
                accountIdHash: accountId,
                snapshotId: snapshot.id,
                exportFormat: WebDavExportFormat.full,
                vaultKeyId: vaultKeyId,
                createdAt: previousEnc.createdAt,
                lastSuccessAt: successAt,
              );
              await _writeExportSignature(
                fileSystem,
                _exportEncSignatureFile,
                signature,
              );
            }
          } else if (plainExportCompleted) {
            final previousPlain = await _readExportSignature(
              fileSystem,
              _exportPlainSignatureFile,
              accountId,
            );
            final successAt = _resolveExportLastSuccessAt(
              exportAt: exportSuccessAt ?? now,
              uploadAt: uploadSuccessAt,
              webDavConfigured: settings.serverUrl.trim().isNotEmpty,
            );
            final signature = _buildExportSignature(
              mode: WebDavExportMode.plain,
              accountIdHash: accountId,
              snapshotId: '',
              exportFormat: WebDavExportFormat.full,
              vaultKeyId: vaultKeyId,
              createdAt: previousPlain?.createdAt,
              lastSuccessAt: successAt,
            );
            await _writeExportSignature(
              fileSystem,
              _exportPlainSignatureFile,
              signature,
            );
          }
        }

        final previousState = await _stateRepository.read();
        await _stateRepository.write(
          previousState.copyWith(
            lastBackupAt: now.toUtc().toIso8601String(),
            lastSnapshotId: snapshot.id,
            lastExportSuccessAt:
                exportSuccessAt?.toUtc().toIso8601String() ??
                previousState.lastExportSuccessAt,
            lastUploadSuccessAt:
                uploadSuccessAt?.toUtc().toIso8601String() ??
                previousState.lastUploadSuccessAt,
          ),
        );
        if (useVault) {
          if (settings.rememberVaultPassword && vaultPassword != null) {
            await _vaultPasswordRepository.write(vaultPassword);
          }
        } else if (settings.rememberBackupPassword && legacyPassword != null) {
          await _passwordRepository.write(legacyPassword);
        }

        _logEvent(
          'Backup completed',
          detail: 'snapshot=${snapshot.id}',
        );
        _updateProgress(
          stage: WebDavBackupProgressStage.completed,
          currentPath: '',
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
    } finally {
      if (tempExportDir != null) {
        try {
          await tempExportDir!.delete(recursive: true);
        } catch (_) {}
      }
      await _setWakelockEnabled(false);
      _finishProgress();
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
    WebDavSettings settings, {
    required String exportedAt,
  }) {
    return _wrapConfigPayload(
      exportedAt: exportedAt,
      data: settings.toJson(),
    );
  }

  Map<String, dynamic> _wrapConfigPayload({
    required String exportedAt,
    required Object? data,
  }) {
    return {
      'schemaVersion': 1,
      'exportedAt': exportedAt,
      'data': data,
    };
  }

  Uint8List _encodeJsonBytes(Object payload) {
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  String _resolveBackupMode({required bool usesServerMode}) {
    return usesServerMode ? 'server' : 'local';
  }

  String _formatExportPathLabel(LocalLibrary library, String prefix) {
    final base = library.locationLabel.trim();
    final normalized = prefix.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return base;
    if (base.isEmpty) return normalized;
    return '$base/$normalized';
  }

  String _prefixExportPath(String prefix, String relativePath) {
    final normalizedPrefix = prefix.replaceAll('\\', '/').trim();
    final normalizedPath = relativePath.replaceAll('\\', '/').trim();
    if (normalizedPrefix.isEmpty) return normalizedPath;
    if (normalizedPath.isEmpty) return normalizedPrefix;
    return '$normalizedPrefix/$normalizedPath';
  }

  Set<WebDavBackupConfigType> _resolveBackupConfigTypes({
    required WebDavBackupConfigScope scope,
    required WebDavBackupEncryptionMode encryptionMode,
  }) {
    if (scope == WebDavBackupConfigScope.none) return const {};
    if (scope == WebDavBackupConfigScope.full &&
        encryptionMode != WebDavBackupEncryptionMode.encrypted) {
      return _safeBackupConfigTypes;
    }
    return scope == WebDavBackupConfigScope.full
        ? _fullBackupConfigTypes
        : _safeBackupConfigTypes;
  }

  WebDavBackupConfigType? _configTypeForPath(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    if (normalized == _backupPreferencesSnapshotPath) {
      return WebDavBackupConfigType.preferences;
    }
    if (normalized == _backupAiSettingsSnapshotPath) {
      return WebDavBackupConfigType.aiSettings;
    }
    if (normalized == _backupReminderSnapshotPath) {
      return WebDavBackupConfigType.reminderSettings;
    }
    if (normalized == _backupImageBedSnapshotPath) {
      return WebDavBackupConfigType.imageBedSettings;
    }
    if (normalized == _backupLocationSnapshotPath) {
      return WebDavBackupConfigType.locationSettings;
    }
    if (normalized == _backupTemplateSnapshotPath) {
      return WebDavBackupConfigType.templateSettings;
    }
    if (normalized == _backupAppLockSnapshotPath) {
      return WebDavBackupConfigType.appLock;
    }
    if (normalized == _backupNoteDraftSnapshotPath) {
      return WebDavBackupConfigType.noteDraft;
    }
    if (normalized == _backupSettingsSnapshotPath) {
      return WebDavBackupConfigType.webdavSettings;
    }
    return null;
  }

  Future<List<_BackupConfigFile>> _buildConfigFiles({
    required WebDavSettings settings,
    required WebDavBackupConfigScope scope,
    required String exportedAt,
  }) async {
    final types = _resolveBackupConfigTypes(
      scope: scope,
      encryptionMode: settings.backupEncryptionMode,
    );
    if (types.isEmpty) return const [];
    WebDavSyncLocalSnapshot? snapshot;
    final needsLocalSnapshot = types.any(
      (type) => type != WebDavBackupConfigType.webdavSettings,
    );
    if (needsLocalSnapshot && _configAdapter != null) {
      snapshot = await _configAdapter!.readSnapshot();
    }

    final files = <_BackupConfigFile>[];
    if (types.contains(WebDavBackupConfigType.preferences) &&
        snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.preferences.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.preferences,
          path: _backupPreferencesSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.aiSettings) && snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.aiSettings.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.aiSettings,
          path: _backupAiSettingsSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.reminderSettings) &&
        snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.reminderSettings.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.reminderSettings,
          path: _backupReminderSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.imageBedSettings) &&
        snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.imageBedSettings.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.imageBedSettings,
          path: _backupImageBedSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.locationSettings) &&
        snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.locationSettings.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.locationSettings,
          path: _backupLocationSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.templateSettings) &&
        snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.templateSettings.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.templateSettings,
          path: _backupTemplateSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.appLock) && snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.appLockSnapshot.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.appLock,
          path: _backupAppLockSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.noteDraft) && snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: {'text': snapshot.noteDraft},
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.noteDraft,
          path: _backupNoteDraftSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }
    if (types.contains(WebDavBackupConfigType.webdavSettings)) {
      final payload = _buildBackupSettingsSnapshotPayload(
        settings,
        exportedAt: exportedAt,
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.webdavSettings,
          path: _backupSettingsSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
    }

    return files;
  }

  WebDavBackupConfigBundle _parseConfigBundle(
    Map<WebDavBackupConfigType, Uint8List> configBytes,
  ) {
    AppPreferences? preferences;
    AiSettings? aiSettings;
    ReminderSettings? reminderSettings;
    ImageBedSettings? imageBedSettings;
    LocationSettings? locationSettings;
    MemoTemplateSettings? templateSettings;
    AppLockSnapshot? appLockSnapshot;
    String? noteDraft;
    WebDavSettings? webDavSettings;

    T? safeParse<T>(T Function() parser) {
      try {
        return parser();
      } catch (_) {
        return null;
      }
    }

    Map<String, dynamic>? readEnvelope(Uint8List bytes) {
      final decoded = _decodeJsonValue(bytes);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    }

    Map<String, dynamic>? readConfigData(Map<String, dynamic> envelope) {
      if (!_isValidConfigEnvelope(envelope)) return null;
      final data = envelope['data'];
      if (data is Map) return data.cast<String, dynamic>();
      return null;
    }

    final preferencesBytes = configBytes[WebDavBackupConfigType.preferences];
    if (preferencesBytes != null) {
      final envelope = readEnvelope(preferencesBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        preferences = safeParse(() => AppPreferences.fromJson(data));
      }
    }

    final reminderBytes = configBytes[WebDavBackupConfigType.reminderSettings];
    if (reminderBytes != null) {
      final envelope = readEnvelope(reminderBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        final fallbackLanguage =
            preferences?.language ?? AppPreferences.defaults.language;
        reminderSettings = safeParse(
          () => ReminderSettings.fromJson(
            data,
            fallback: ReminderSettings.defaultsFor(fallbackLanguage),
          ),
        );
      }
    }

    final aiBytes = configBytes[WebDavBackupConfigType.aiSettings];
    if (aiBytes != null) {
      final envelope = readEnvelope(aiBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        aiSettings = safeParse(() => AiSettings.fromJson(data));
      }
    }

    final imageBedBytes =
        configBytes[WebDavBackupConfigType.imageBedSettings];
    if (imageBedBytes != null) {
      final envelope = readEnvelope(imageBedBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        imageBedSettings = safeParse(() => ImageBedSettings.fromJson(data));
      }
    }

    final locationBytes =
        configBytes[WebDavBackupConfigType.locationSettings];
    if (locationBytes != null) {
      final envelope = readEnvelope(locationBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        locationSettings = safeParse(() => LocationSettings.fromJson(data));
      }
    }

    final templateBytes =
        configBytes[WebDavBackupConfigType.templateSettings];
    if (templateBytes != null) {
      final envelope = readEnvelope(templateBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        templateSettings = safeParse(() => MemoTemplateSettings.fromJson(data));
      }
    }

    final appLockBytes = configBytes[WebDavBackupConfigType.appLock];
    if (appLockBytes != null) {
      final envelope = readEnvelope(appLockBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        appLockSnapshot = safeParse(() => AppLockSnapshot.fromJson(data));
      }
    }

    final noteDraftBytes = configBytes[WebDavBackupConfigType.noteDraft];
    if (noteDraftBytes != null) {
      final envelope = readEnvelope(noteDraftBytes);
      if (envelope != null && _isValidConfigEnvelope(envelope)) {
        final data = envelope['data'];
        if (data is String) {
          noteDraft = data;
        } else if (data is Map) {
          final text = data['text'];
          if (text is String) noteDraft = text;
        }
      }
    }

    final webDavBytes = configBytes[WebDavBackupConfigType.webdavSettings];
    if (webDavBytes != null) {
      final envelope = readEnvelope(webDavBytes);
        if (envelope != null && _isValidConfigEnvelope(envelope)) {
          final data = envelope['data'];
          Map<String, dynamic>? settingsJson;
          if (data is Map) {
            settingsJson = data.cast<String, dynamic>();
          } else {
            settingsJson = _extractLegacyWebDavSettings(envelope);
          }
        if (settingsJson != null) {
          final resolved = settingsJson;
          webDavSettings =
              safeParse(() => WebDavSettings.fromJson(resolved));
        }
      }
    }

    return WebDavBackupConfigBundle(
      preferences: preferences,
      aiSettings: aiSettings,
      reminderSettings: reminderSettings,
      imageBedSettings: imageBedSettings,
      locationSettings: locationSettings,
      templateSettings: templateSettings,
      appLockSnapshot: appLockSnapshot,
      noteDraft: noteDraft,
      webDavSettings: webDavSettings,
    );
  }

  Object? _decodeJsonValue(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  bool _isValidConfigEnvelope(Map<String, dynamic> envelope) {
    int readInt(String key) {
      final raw = envelope[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? -1;
      return -1;
    }

    final schemaVersion = readInt('schemaVersion');
    final exportedAt = envelope['exportedAt'];
    return schemaVersion >= 1 &&
        exportedAt is String &&
        exportedAt.trim().isNotEmpty;
  }

  Map<String, dynamic>? _extractLegacyWebDavSettings(
    Map<String, dynamic> envelope,
  ) {
    final webDav = envelope['webDav'];
    final backup = envelope['backup'];
    final vault = envelope['vault'];
    if (webDav is! Map && backup is! Map && vault is! Map) {
      return null;
    }
    final settings = <String, dynamic>{};
    if (webDav is Map) {
      settings['enabled'] = webDav['enabled'];
      settings['serverUrl'] = webDav['serverUrl'];
      settings['username'] = webDav['username'];
      settings['authMode'] = webDav['authMode'];
      settings['ignoreTlsErrors'] = webDav['ignoreTlsErrors'];
      settings['rootPath'] = webDav['rootPath'];
    }
    if (backup is Map) {
      settings['backupEnabled'] = backup['backupEnabled'];
      settings['backupEncryptionMode'] = backup['backupEncryptionMode'];
      settings['backupSchedule'] = backup['backupSchedule'];
      settings['backupRetentionCount'] = backup['backupRetentionCount'];
      settings['rememberBackupPassword'] = backup['rememberBackupPassword'];
      settings['backupExportEncrypted'] = backup['backupExportEncrypted'];
      settings['backupMirrorTreeUri'] = backup['backupMirrorTreeUri'];
      settings['backupMirrorRootPath'] = backup['backupMirrorRootPath'];
      settings['backupConfigScope'] = backup['backupConfigScope'];
      settings['backupContentConfig'] = backup['backupContentConfig'];
      settings['backupContentMemos'] = backup['backupContentMemos'];
    }
    if (vault is Map) {
      settings['vaultEnabled'] = vault['enabled'];
      settings['rememberVaultPassword'] = vault['rememberPassword'];
      settings['vaultKeepPlainCache'] = vault['keepPlainCache'];
    }
    return settings.isEmpty ? null : settings;
  }

  Set<WebDavBackupConfigType> _availableConfigTypes(
    WebDavBackupConfigBundle bundle,
  ) {
    final types = <WebDavBackupConfigType>{};
    if (bundle.preferences != null) {
      types.add(WebDavBackupConfigType.preferences);
    }
    if (bundle.aiSettings != null) {
      types.add(WebDavBackupConfigType.aiSettings);
    }
    if (bundle.reminderSettings != null) {
      types.add(WebDavBackupConfigType.reminderSettings);
    }
    if (bundle.imageBedSettings != null) {
      types.add(WebDavBackupConfigType.imageBedSettings);
    }
    if (bundle.locationSettings != null) {
      types.add(WebDavBackupConfigType.locationSettings);
    }
    if (bundle.templateSettings != null) {
      types.add(WebDavBackupConfigType.templateSettings);
    }
    if (bundle.appLockSnapshot != null) {
      types.add(WebDavBackupConfigType.appLock);
    }
    if (bundle.noteDraft != null) {
      types.add(WebDavBackupConfigType.noteDraft);
    }
    if (bundle.webDavSettings != null) {
      types.add(WebDavBackupConfigType.webdavSettings);
    }
    return types;
  }

  Future<void> _applyConfigBundle({
    required WebDavBackupConfigBundle bundle,
    WebDavBackupConfigDecisionHandler? decisionHandler,
  }) async {
    if (_configAdapter == null || bundle.isEmpty) return;
    final available = _availableConfigTypes(bundle);
    final exportOnlyTypes = available.intersection(_exportOnlyConfigTypes);
    final autoTypes = available.intersection(_autoRestoreConfigTypes);
    final confirmTypes = available.intersection(_confirmRestoreConfigTypes);
    final allowed = <WebDavBackupConfigType>{...autoTypes};
    if (confirmTypes.isNotEmpty && decisionHandler != null) {
      final selected = await decisionHandler(bundle);
      allowed.addAll(confirmTypes.intersection(selected));
    }
    if (exportOnlyTypes.isNotEmpty) {
      _logEvent(
        'Config export-only',
        detail: exportOnlyTypes.map((e) => e.name).join(','),
      );
    }

    for (final type in allowed) {
      try {
        switch (type) {
          case WebDavBackupConfigType.preferences:
            final prefs = bundle.preferences;
            if (prefs != null) {
              await _configAdapter!.applyPreferences(prefs);
            }
            break;
          case WebDavBackupConfigType.aiSettings:
            final ai = bundle.aiSettings;
            if (ai != null) {
              await _configAdapter!.applyAiSettings(ai);
            }
            break;
          case WebDavBackupConfigType.reminderSettings:
            final reminder = bundle.reminderSettings;
            if (reminder != null) {
              await _configAdapter!.applyReminderSettings(reminder);
            }
            break;
          case WebDavBackupConfigType.imageBedSettings:
            final imageBed = bundle.imageBedSettings;
            if (imageBed != null) {
              await _configAdapter!.applyImageBedSettings(imageBed);
            }
            break;
          case WebDavBackupConfigType.locationSettings:
            final location = bundle.locationSettings;
            if (location != null) {
              await _configAdapter!.applyLocationSettings(location);
            }
            break;
          case WebDavBackupConfigType.templateSettings:
            final template = bundle.templateSettings;
            if (template != null) {
              await _configAdapter!.applyTemplateSettings(template);
            }
            break;
          case WebDavBackupConfigType.appLock:
            final lockSnapshot = bundle.appLockSnapshot;
            if (lockSnapshot != null) {
              await _configAdapter!.applyAppLockSnapshot(lockSnapshot);
            }
            break;
          case WebDavBackupConfigType.noteDraft:
            final draft = bundle.noteDraft;
            if (draft != null) {
              await _configAdapter!.applyNoteDraft(draft);
            }
            break;
          case WebDavBackupConfigType.webdavSettings:
            final webDavSettings = bundle.webDavSettings;
            if (webDavSettings != null) {
              await _configAdapter!.applyWebDavSettings(webDavSettings);
            }
            break;
        }
      } catch (error) {
        _logEvent('Config restore failed', error: error);
      }
    }
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
      SecretKey masterKey;
      if (settings.vaultEnabled) {
        masterKey = await _resolveVaultMasterKey(
          settings: settings,
          accountKey: normalizedAccountKey,
          password: password,
        );
      } else {
        final config = await _loadConfig(client, baseUrl, rootPath, accountId);
        if (config == null) return const [];
        masterKey = await _resolveMasterKey(password, config);
      }
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

  Future<SyncError?> verifyBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
    bool deep = false,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      return _keyedError(
        'legacy.webdav.backup_account_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    if (settings.backupEncryptionMode == WebDavBackupEncryptionMode.plain) {
      return _keyedError(
        'legacy.webdav.backup_disabled',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _buildClient(settings, baseUrl);
    try {
      await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
      final masterKey = settings.vaultEnabled
          ? await _resolveVaultMasterKey(
              settings: settings,
              accountKey: normalizedAccountKey,
              password: password,
            )
          : await _resolveMasterKeyFromLegacy(
              client: client,
              baseUrl: baseUrl,
              rootPath: rootPath,
              accountId: accountId,
              password: password,
            );
      final index = await _loadIndex(
        client,
        baseUrl,
        rootPath,
        accountId,
        masterKey,
      );
      if (index.snapshots.isEmpty) {
        return _keyedError(
          'legacy.webdav.backup_empty',
          code: SyncErrorCode.dataCorrupt,
        );
      }
      final sorted = [...index.snapshots]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = sorted.first;
      final snapshot = await _loadSnapshot(
        client: client,
        baseUrl: baseUrl,
        rootPath: rootPath,
        accountId: accountId,
        masterKey: masterKey,
        snapshotId: latest.id,
      );
      if (snapshot.files.isEmpty) {
        return _keyedError(
          'legacy.webdav.backup_empty',
          code: SyncErrorCode.dataCorrupt,
        );
      }
      if (deep) {
        final tempRoot = await getTemporaryDirectory();
        final parent = Directory(
          p.join(tempRoot.path, 'memoflow_backup_verify'),
        );
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
        final tempDir = await parent.createTemp('restore_');
        final tempLibrary = LocalLibrary(
          key: 'webdav_backup_verify',
          name: 'WebDAV Backup Verify',
          rootPath: tempDir.path,
        );
        final fileSystem = LocalLibraryFileSystem(tempLibrary);
        try {
          for (final entry in snapshot.files) {
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
        } finally {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      } else {
        String? firstObject;
        for (final entry in snapshot.files) {
          if (entry.objects.isEmpty) continue;
          firstObject = entry.objects.first;
          break;
        }
        if (firstObject != null && firstObject.isNotEmpty) {
          await _decryptObject(
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            masterKey: masterKey,
            hash: firstObject,
          );
        }
      }
      return null;
    } on SyncError catch (error) {
      return error;
    } catch (error) {
      return _mapUnexpectedError(error);
    } finally {
      await client.close();
    }
  }

  Future<WebDavExportStatus> fetchExportStatus({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    final accountId = normalizedAccountKey.isEmpty
        ? ''
        : fnv1a64Hex(normalizedAccountKey);
    final webDavConfigured = settings.serverUrl.trim().isNotEmpty;
    final exportLibrary = activeLocalLibrary == null
        ? _resolveBackupLibrary(settings, null)
        : null;
    final state = await _stateRepository.read();

    if (exportLibrary == null || accountId.isEmpty) {
      return WebDavExportStatus(
        webDavConfigured: webDavConfigured,
        encSignature: null,
        plainSignature: null,
        plainDetected: false,
        plainDeprecated: false,
        plainDetectedAt: state.exportPlainDetectedAt,
        plainRemindAfter: state.exportPlainRemindAfter,
        lastExportSuccessAt: state.lastExportSuccessAt,
        lastUploadSuccessAt: state.lastUploadSuccessAt,
      );
    }

    final fileSystem = LocalLibraryFileSystem(exportLibrary);
    final encSignature = await _readExportSignature(
      fileSystem,
      _exportEncSignatureFile,
      accountId,
    );
    final plainSignature = await _readExportSignature(
      fileSystem,
      _exportPlainSignatureFile,
      accountId,
    );
    final legacyPlainDetected = await _detectPlainExport(fileSystem);
    final plainDetected = plainSignature != null || legacyPlainDetected;
    final plainDeprecated = encSignature != null && plainDetected;

    var detectedAt = state.exportPlainDetectedAt;
    var remindAfter = state.exportPlainRemindAfter;
    if (plainDetected && detectedAt == null) {
      final now = DateTime.now().toUtc();
      detectedAt = now.toIso8601String();
      remindAfter = now.add(const Duration(days: 7)).toIso8601String();
      await _stateRepository.write(
        state.copyWith(
          exportPlainDetectedAt: detectedAt,
          exportPlainRemindAfter: remindAfter,
        ),
      );
    }

    return WebDavExportStatus(
      webDavConfigured: webDavConfigured,
      encSignature: encSignature,
      plainSignature: plainSignature,
      plainDetected: plainDetected,
      plainDeprecated: plainDeprecated,
      plainDetectedAt: detectedAt,
      plainRemindAfter: remindAfter,
      lastExportSuccessAt: state.lastExportSuccessAt,
      lastUploadSuccessAt: state.lastUploadSuccessAt,
    );
  }

  Future<WebDavExportCleanupStatus> cleanPlainExport({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      return WebDavExportCleanupStatus.notFound;
    }
    final exportLibrary = activeLocalLibrary == null
        ? _resolveBackupLibrary(settings, null)
        : null;
    if (exportLibrary == null) {
      return WebDavExportCleanupStatus.notFound;
    }

    final status = await fetchExportStatus(
      settings: settings,
      accountKey: accountKey,
      activeLocalLibrary: activeLocalLibrary,
    );
    if (!status.plainDetected) {
      return WebDavExportCleanupStatus.notFound;
    }
    final hasUpload = status.lastUploadSuccessAt != null;
    final hasExport = status.lastExportSuccessAt != null;
    final requiresUpload = status.webDavConfigured;
    if (requiresUpload && !hasUpload) {
      return WebDavExportCleanupStatus.blocked;
    }
    if (!requiresUpload && !hasExport) {
      return WebDavExportCleanupStatus.blocked;
    }

    final fileSystem = LocalLibraryFileSystem(exportLibrary);
    await _deletePlainExportFiles(fileSystem);

    final previous = await _stateRepository.read();
    final clearedAt = DateTime.now().toUtc().toIso8601String();
    await _stateRepository.write(
      WebDavBackupState(
        lastBackupAt: previous.lastBackupAt,
        lastSnapshotId: previous.lastSnapshotId,
        lastExportSuccessAt: previous.lastExportSuccessAt,
        lastUploadSuccessAt: previous.lastUploadSuccessAt,
        exportPlainDetectedAt: null,
        exportPlainRemindAfter: null,
        exportPlainClearedAt: clearedAt,
      ),
    );

    return WebDavExportCleanupStatus.cleaned;
  }

  Future<WebDavRestoreResult> restoreSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
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
    _startProgress(WebDavBackupProgressOperation.restore);
    _updateProgress(stage: WebDavBackupProgressStage.preparing);
    await _setWakelockEnabled(true);
    try {
      final baseUrl = _parseBaseUrl(settings.serverUrl);
      final accountId = fnv1a64Hex(normalizedAccountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = _buildClient(settings, baseUrl);
      try {
        await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
        SecretKey masterKey;
        if (settings.vaultEnabled) {
          masterKey = await _resolveVaultMasterKey(
            settings: settings,
            accountKey: normalizedAccountKey,
            password: password,
          );
        } else {
          final config = await _loadConfig(client, baseUrl, rootPath, accountId);
          if (config == null) {
            throw _keyedError(
              'legacy.msg_no_backups_found',
              code: SyncErrorCode.unknown,
            );
          }
          masterKey = await _resolveMasterKey(password, config);
        }
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
        final configPayloads = <WebDavBackupConfigType, Uint8List>{};
        await fileSystem.clearLibrary();
        await _attachmentStore.clearAll();
        await fileSystem.ensureStructure();

        final entries =
            snapshotData.files
                .where((entry) => entry.path != _backupManifestFile)
                .toList(growable: false);
        var restoredCount = 0;
        final totalCount = entries.length;
        _updateProgress(
          stage: WebDavBackupProgressStage.downloading,
          completed: restoredCount,
          total: totalCount,
          currentPath: '',
          itemGroup: WebDavBackupProgressItemGroup.other,
        );
        for (final entry in entries) {
          await _waitIfPaused();
          _updateProgress(
            stage: WebDavBackupProgressStage.downloading,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
          final configType = _configTypeForPath(entry.path);
          if (configType != null) {
            try {
              final bytes = await _readSnapshotFileBytes(
                entry: entry,
                client: client,
                baseUrl: baseUrl,
                rootPath: rootPath,
                accountId: accountId,
                masterKey: masterKey,
              );
              configPayloads[configType] = bytes;
              restoredCount += 1;
              _updateProgress(
                stage: WebDavBackupProgressStage.writing,
                completed: restoredCount,
                total: totalCount,
                currentPath: entry.path,
                itemGroup: WebDavBackupProgressItemGroup.config,
              );
            } catch (error) {
              _logEvent('Config restore skipped', error: error);
              restoredCount += 1;
              _updateProgress(
                stage: WebDavBackupProgressStage.writing,
                completed: restoredCount,
                total: totalCount,
                currentPath: entry.path,
                itemGroup: WebDavBackupProgressItemGroup.config,
              );
            }
            continue;
          }
          _updateProgress(
            stage: WebDavBackupProgressStage.writing,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
          await _restoreFile(
            entry: entry,
            fileSystem: fileSystem,
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            masterKey: masterKey,
          );
          restoredCount += 1;
          _updateProgress(
            stage: WebDavBackupProgressStage.writing,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
        }

        await _db.clearOutbox();
        final scanService = _scanServiceFor(activeLocalLibrary);
        if (scanService != null) {
          await _waitIfPaused();
          _updateProgress(
            stage: WebDavBackupProgressStage.scanning,
            completed: restoredCount,
            total: totalCount,
            currentPath: '',
          );
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

        if (configPayloads.isNotEmpty) {
          final bundle = _parseConfigBundle(configPayloads);
          await _applyConfigBundle(
            bundle: bundle,
            decisionHandler: configDecisionHandler,
          );
        }

        _logEvent('Restore completed', detail: 'snapshot=${snapshot.id}');
        _updateProgress(
          stage: WebDavBackupProgressStage.completed,
          currentPath: '',
        );
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
    } finally {
      await _setWakelockEnabled(false);
      _finishProgress();
    }
  }

  Future<WebDavRestoreResult> restorePlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
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
    _startProgress(WebDavBackupProgressOperation.restore);
    _updateProgress(stage: WebDavBackupProgressStage.preparing);
    await _setWakelockEnabled(true);
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
        final configPayloads = <WebDavBackupConfigType, Uint8List>{};
        await fileSystem.clearLibrary();
        await _attachmentStore.clearAll();
        await fileSystem.ensureStructure();

        final entries =
            index.files
                .where((entry) => entry.path != _backupManifestFile)
                .toList(growable: false);
        var restoredCount = 0;
        final totalCount = entries.length;
        _updateProgress(
          stage: WebDavBackupProgressStage.downloading,
          completed: restoredCount,
          total: totalCount,
          currentPath: '',
          itemGroup: WebDavBackupProgressItemGroup.other,
        );

        for (final entry in entries) {
          await _waitIfPaused();
          _updateProgress(
            stage: WebDavBackupProgressStage.downloading,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
          final configType = _configTypeForPath(entry.path);
          if (configType != null) {
            final bytes = await _getBytes(
              client,
              _plainFileUri(baseUrl, rootPath, accountId, entry.path),
            );
            if (bytes != null) {
              configPayloads[configType] = Uint8List.fromList(bytes);
            }
            restoredCount += 1;
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: WebDavBackupProgressItemGroup.config,
            );
            continue;
          }
          _updateProgress(
            stage: WebDavBackupProgressStage.writing,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
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
          restoredCount += 1;
          _updateProgress(
            stage: WebDavBackupProgressStage.writing,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
        }

        await _db.clearOutbox();
        final scanService = _scanServiceFor(activeLocalLibrary);
        if (scanService != null) {
          await _waitIfPaused();
          _updateProgress(
            stage: WebDavBackupProgressStage.scanning,
            completed: restoredCount,
            total: totalCount,
            currentPath: '',
          );
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

        if (configPayloads.isNotEmpty) {
          final bundle = _parseConfigBundle(configPayloads);
          await _applyConfigBundle(
            bundle: bundle,
            decisionHandler: configDecisionHandler,
          );
        }

        _logEvent('Restore completed', detail: 'mode=plain');
        _updateProgress(
          stage: WebDavBackupProgressStage.completed,
          currentPath: '',
        );
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
    } finally {
      await _setWakelockEnabled(false);
      _finishProgress();
    }
  }

  Future<WebDavRestoreResult> restoreSnapshotToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
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

    _logEvent('Restore started', detail: 'snapshot=${snapshot.id} (export)');
    _startProgress(WebDavBackupProgressOperation.restore);
    _updateProgress(stage: WebDavBackupProgressStage.preparing);
    await _setWakelockEnabled(true);
    try {
      final baseUrl = _parseBaseUrl(settings.serverUrl);
      final accountId = fnv1a64Hex(normalizedAccountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = _buildClient(settings, baseUrl);
      try {
        await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
        SecretKey masterKey;
        if (settings.vaultEnabled) {
          masterKey = await _resolveVaultMasterKey(
            settings: settings,
            accountKey: normalizedAccountKey,
            password: password,
          );
        } else {
          final config = await _loadConfig(client, baseUrl, rootPath, accountId);
          if (config == null) {
            throw _keyedError(
              'legacy.msg_no_backups_found',
              code: SyncErrorCode.unknown,
            );
          }
          masterKey = await _resolveMasterKey(password, config);
        }
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

        WebDavBackupManifest? manifest;
        WebDavBackupFileEntry? manifestEntry;
        for (final entry in snapshotData.files) {
          if (entry.path == _backupManifestFile) {
            manifestEntry = entry;
            break;
          }
        }
        if (manifestEntry != null) {
          final bytes = await _readSnapshotFileBytes(
            entry: manifestEntry,
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            masterKey: masterKey,
          );
          final decoded = _decodeJsonValue(bytes);
          if (decoded is Map) {
            manifest = WebDavBackupManifest.fromJson(
              decoded.cast<String, dynamic>(),
            );
          }
        }
        if (manifest == null) {
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.data_corrupted',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }

        final fileSystem = LocalLibraryFileSystem(exportLibrary);
        final configPayloads = <WebDavBackupConfigType, Uint8List>{};
        var restoredMemoCount = 0;
        var missingAttachments = 0;
        var restoredCount = 0;
        final totalCount = snapshotData.files.length;
        _updateProgress(
          stage: WebDavBackupProgressStage.downloading,
          completed: restoredCount,
          total: totalCount,
          currentPath: '',
          itemGroup: WebDavBackupProgressItemGroup.other,
        );
        for (final entry in snapshotData.files) {
          await _waitIfPaused();
          _updateProgress(
            stage: WebDavBackupProgressStage.downloading,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
          final targetPath = _prefixExportPath(exportPrefix, entry.path);
          if (entry.path == _backupManifestFile) {
            final bytes = await _readSnapshotFileBytes(
              entry: entry,
              client: client,
              baseUrl: baseUrl,
              rootPath: rootPath,
              accountId: accountId,
              masterKey: masterKey,
            );
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: WebDavBackupProgressItemGroup.manifest,
            );
            await fileSystem.writeFileFromChunks(
              targetPath,
              Stream<Uint8List>.value(bytes),
              mimeType: _guessMimeType(entry.path),
            );
            restoredCount += 1;
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: WebDavBackupProgressItemGroup.manifest,
            );
            continue;
          }
          final configType = _configTypeForPath(entry.path);
          if (configType != null) {
            final bytes = await _readSnapshotFileBytes(
              entry: entry,
              client: client,
              baseUrl: baseUrl,
              rootPath: rootPath,
              accountId: accountId,
              masterKey: masterKey,
            );
            configPayloads[configType] = bytes;
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: WebDavBackupProgressItemGroup.config,
            );
            await fileSystem.writeFileFromChunks(
              targetPath,
              Stream<Uint8List>.value(bytes),
              mimeType: _guessMimeType(entry.path),
            );
            restoredCount += 1;
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: WebDavBackupProgressItemGroup.config,
            );
            continue;
          }
          try {
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: _progressItemGroupForPath(entry.path),
            );
            await _restoreFileToPath(
              entry: entry,
              targetPath: targetPath,
              fileSystem: fileSystem,
              client: client,
              baseUrl: baseUrl,
              rootPath: rootPath,
              accountId: accountId,
              masterKey: masterKey,
            );
            restoredCount += 1;
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: _progressItemGroupForPath(entry.path),
            );
            if (_isMemoPath(entry.path)) {
              restoredMemoCount += 1;
            }
          } catch (error) {
            if (_isAttachmentPath(entry.path)) {
              missingAttachments += 1;
              try {
                await fileSystem.deleteRelativeFile(targetPath);
              } catch (_) {}
              restoredCount += 1;
              _updateProgress(
                stage: WebDavBackupProgressStage.writing,
                completed: restoredCount,
                total: totalCount,
                currentPath: entry.path,
                itemGroup: WebDavBackupProgressItemGroup.attachment,
              );
              continue;
            }
            return WebDavRestoreFailure(_mapUnexpectedError(error));
          }
        }

        if (restoredMemoCount < manifest.memoCount) {
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.backup_no_memos',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }

        if (configPayloads.isNotEmpty) {
          final bundle = _parseConfigBundle(configPayloads);
          await _applyConfigBundle(
            bundle: bundle,
            decisionHandler: configDecisionHandler,
          );
        }

        _logEvent('Restore completed', detail: 'snapshot=${snapshot.id} (export)');
        _updateProgress(
          stage: WebDavBackupProgressStage.completed,
          currentPath: '',
        );
        return WebDavRestoreSuccess(
          missingAttachments: missingAttachments,
          exportPath: _formatExportPathLabel(exportLibrary, exportPrefix),
        );
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
    } finally {
      await _setWakelockEnabled(false);
      _finishProgress();
    }
  }

  Future<WebDavRestoreResult> restorePlainBackupToDirectory({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary exportLibrary,
    required String exportPrefix,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
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

    _logEvent('Restore started', detail: 'mode=plain (export)');
    _startProgress(WebDavBackupProgressOperation.restore);
    _updateProgress(stage: WebDavBackupProgressStage.preparing);
    await _setWakelockEnabled(true);
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

        WebDavBackupManifest? manifest;
        _PlainBackupFile? manifestEntry;
        for (final entry in index.files) {
          if (entry.path == _backupManifestFile) {
            manifestEntry = entry;
            break;
          }
        }
        if (manifestEntry != null) {
          final bytes = await _getBytes(
            client,
            _plainFileUri(baseUrl, rootPath, accountId, manifestEntry.path),
          );
          if (bytes != null) {
            final decoded = _decodeJsonValue(Uint8List.fromList(bytes));
            if (decoded is Map) {
              manifest = WebDavBackupManifest.fromJson(
                decoded.cast<String, dynamic>(),
              );
            }
          }
        }
        if (manifest == null) {
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.data_corrupted',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }

        final fileSystem = LocalLibraryFileSystem(exportLibrary);
        final configPayloads = <WebDavBackupConfigType, Uint8List>{};
        var restoredMemoCount = 0;
        var missingAttachments = 0;
        var restoredCount = 0;
        final totalCount = index.files.length;
        _updateProgress(
          stage: WebDavBackupProgressStage.downloading,
          completed: restoredCount,
          total: totalCount,
          currentPath: '',
          itemGroup: WebDavBackupProgressItemGroup.other,
        );
        for (final entry in index.files) {
          await _waitIfPaused();
          _updateProgress(
            stage: WebDavBackupProgressStage.downloading,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
          final targetPath = _prefixExportPath(exportPrefix, entry.path);
          final bytes = await _getBytes(
            client,
            _plainFileUri(baseUrl, rootPath, accountId, entry.path),
          );
          if (bytes == null) {
            if (_isAttachmentPath(entry.path)) {
              missingAttachments += 1;
              restoredCount += 1;
              _updateProgress(
                stage: WebDavBackupProgressStage.writing,
                completed: restoredCount,
                total: totalCount,
                currentPath: entry.path,
                itemGroup: WebDavBackupProgressItemGroup.attachment,
              );
              continue;
            }
            return WebDavRestoreFailure(
              _keyedError(
                'legacy.webdav.backup_no_memos',
                code: SyncErrorCode.dataCorrupt,
              ),
            );
          }
          final configType = _configTypeForPath(entry.path);
          if (configType != null) {
            configPayloads[configType] = Uint8List.fromList(bytes);
            _updateProgress(
              stage: WebDavBackupProgressStage.writing,
              completed: restoredCount,
              total: totalCount,
              currentPath: entry.path,
              itemGroup: WebDavBackupProgressItemGroup.config,
            );
          }
          await fileSystem.writeFileFromChunks(
            targetPath,
            Stream<Uint8List>.value(Uint8List.fromList(bytes)),
            mimeType: _guessMimeType(entry.path),
          );
          restoredCount += 1;
          _updateProgress(
            stage: WebDavBackupProgressStage.writing,
            completed: restoredCount,
            total: totalCount,
            currentPath: entry.path,
            itemGroup: _progressItemGroupForPath(entry.path),
          );
          if (_isMemoPath(entry.path)) {
            restoredMemoCount += 1;
          }
        }

        if (restoredMemoCount < manifest.memoCount) {
          return WebDavRestoreFailure(
            _keyedError(
              'legacy.webdav.backup_no_memos',
              code: SyncErrorCode.dataCorrupt,
            ),
          );
        }

        if (configPayloads.isNotEmpty) {
          final bundle = _parseConfigBundle(configPayloads);
          await _applyConfigBundle(
            bundle: bundle,
            decisionHandler: configDecisionHandler,
          );
        }

        _logEvent('Restore completed', detail: 'mode=plain (export)');
        _updateProgress(
          stage: WebDavBackupProgressStage.completed,
          currentPath: '',
        );
        return WebDavRestoreSuccess(
          missingAttachments: missingAttachments,
          exportPath: _formatExportPathLabel(exportLibrary, exportPrefix),
        );
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
    } finally {
      await _setWakelockEnabled(false);
      _finishProgress();
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
    final memos = rows.map(LocalMemo.fromDb).toList(growable: false);
    final totalAttachments = memos.fold<int>(
      0,
      (sum, memo) => sum + memo.attachments.length,
    );
    final totalFiles = memos.length + totalAttachments;
    var completedFiles = 0;
    _updateProgress(
      stage: WebDavBackupProgressStage.exporting,
      completed: completedFiles,
      total: totalFiles,
      itemGroup: WebDavBackupProgressItemGroup.memo,
    );
    final stickyResolutions =
        <WebDavBackupExportIssueKind, WebDavBackupExportResolution>{};
    final targetMemoUids = <String>{};
    final expectedAttachmentsByMemo = <String, Set<String>>{};
    final skipAttachmentPruneUids = <String>{};
    var memoCount = 0;
    final httpClient = Dio();
    try {
      for (final memo in memos) {
        await _waitIfPaused();
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
            completedFiles += 1;
            _updateProgress(
              stage: WebDavBackupProgressStage.exporting,
              completed: completedFiles,
              total: totalFiles,
              currentPath: 'memos/$uid.md',
              itemGroup: WebDavBackupProgressItemGroup.memo,
            );
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
              completedFiles += 1;
              _updateProgress(
                stage: WebDavBackupProgressStage.exporting,
                completed: completedFiles,
                total: totalFiles,
                currentPath: 'memos/$uid.md',
                itemGroup: WebDavBackupProgressItemGroup.memo,
              );
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
          await _waitIfPaused();
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
              completedFiles += 1;
              _updateProgress(
                stage: WebDavBackupProgressStage.exporting,
                completed: completedFiles,
                total: totalFiles,
                currentPath: 'attachments/$uid/$archiveName',
                itemGroup: WebDavBackupProgressItemGroup.attachment,
              );
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
                completedFiles += 1;
                _updateProgress(
                  stage: WebDavBackupProgressStage.exporting,
                  completed: completedFiles,
                  total: totalFiles,
                  currentPath: 'attachments/$uid/$archiveName',
                  itemGroup: WebDavBackupProgressItemGroup.attachment,
                );
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
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  int _countMemosInEntries(Iterable<WebDavBackupFileEntry> entries) {
    var count = 0;
    for (final entry in entries) {
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  int _countAttachmentsInEntries(Iterable<WebDavBackupFileEntry> entries) {
    var count = 0;
    for (final entry in entries) {
      if (_isAttachmentPath(entry.path)) {
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
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  int _countMemosInUploads(Iterable<_PlainBackupFileUpload> uploads) {
    var count = 0;
    for (final entry in uploads) {
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  int _countAttachmentsInUploads(Iterable<_PlainBackupFileUpload> uploads) {
    var count = 0;
    for (final entry in uploads) {
      if (_isAttachmentPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  bool _plainIndexHasMemos(_PlainBackupIndex index) {
    return _countMemosInPlainIndex(index) > 0;
  }

  bool _isMemoPath(String rawPath) {
    final path = rawPath.trim().toLowerCase();
    return path.startsWith('memos/') &&
        (path.endsWith('.md') || path.endsWith('.md.txt'));
  }

  bool _isAttachmentPath(String rawPath) {
    final path = rawPath.trim().toLowerCase();
    return path.startsWith('attachments/');
  }

  WebDavBackupProgressItemGroup _progressItemGroupForPath(String rawPath) {
    final path = rawPath.trim();
    if (path.isEmpty) return WebDavBackupProgressItemGroup.other;
    if (path == _backupManifestFile ||
        path == _plainBackupIndexFile ||
        path.endsWith('.enc')) {
      return WebDavBackupProgressItemGroup.manifest;
    }
    if (_configTypeForPath(path) != null) {
      return WebDavBackupProgressItemGroup.config;
    }
    if (_isMemoPath(path)) {
      return WebDavBackupProgressItemGroup.memo;
    }
    if (_isAttachmentPath(path)) {
      return WebDavBackupProgressItemGroup.attachment;
    }
    return WebDavBackupProgressItemGroup.other;
  }

  Future<void> _backupPlain({
    required WebDavSettings settings,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required LocalLibrary? localLibrary,
    required bool includeMemos,
    required List<_BackupConfigFile> configFiles,
    required String exportedAt,
    required String backupMode,
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

    if (configFiles.isNotEmpty) {
      for (final configFile in configFiles) {
        uploads.add(
          _PlainBackupFileUpload(
            path: configFile.path,
            size: configFile.bytes.length,
            modifiedAt: DateTime.now().toUtc().toIso8601String(),
            bytes: configFile.bytes,
          ),
        );
      }
    }

    if (uploads.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_empty',
        code: SyncErrorCode.invalidConfig,
      );
    }

    var uploadedCount = 0;
    _updateProgress(
      stage: WebDavBackupProgressStage.uploading,
      completed: uploadedCount,
      total: uploads.length,
      currentPath: '',
      itemGroup: WebDavBackupProgressItemGroup.other,
    );

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
      await _waitIfPaused();
      _updateProgress(
        stage: WebDavBackupProgressStage.uploading,
        completed: uploadedCount,
        total: uploads.length,
        currentPath: upload.path,
        itemGroup: _progressItemGroupForPath(upload.path),
      );
      final bytes = upload.bytes ??
          await _readLocalEntryBytes(fileSystem, upload.entry);
      await _putBytes(
        client,
        _plainFileUri(baseUrl, rootPath, accountId, upload.path),
        bytes,
      );
      uploadedCount += 1;
      _updateProgress(
        stage: WebDavBackupProgressStage.uploading,
        completed: uploadedCount,
        total: uploads.length,
        currentPath: upload.path,
        itemGroup: _progressItemGroupForPath(upload.path),
      );
    }

    final memoCount = _countMemosInUploads(uploads);
    final attachmentCount = _countAttachmentsInUploads(uploads);
    final totalSize = uploads.fold<int>(
      0,
      (sum, entry) => sum + entry.size,
    );
    final manifest = WebDavBackupManifest(
      schemaVersion: 1,
      exportedAt: exportedAt,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      totalSize: totalSize,
      backupMode: backupMode,
      encrypted: false,
    );
    final manifestBytes = _encodeJsonBytes(manifest.toJson());
    uploads.add(
      _PlainBackupFileUpload(
        path: _backupManifestFile,
        size: manifestBytes.length,
        modifiedAt: DateTime.now().toUtc().toIso8601String(),
        bytes: manifestBytes,
      ),
    );

    final now = DateTime.now();
    final indexPayload = _buildPlainBackupIndexPayload(uploads, now);
    _updateProgress(
      stage: WebDavBackupProgressStage.writingManifest,
      completed: uploads.length,
      total: uploads.length,
      currentPath: _plainBackupIndexFile,
      itemGroup: WebDavBackupProgressItemGroup.manifest,
    );
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

  Future<WebDavExportSignature?> _readExportSignature(
    LocalLibraryFileSystem fileSystem,
    String filename,
    String accountIdHash,
  ) async {
    final content = await fileSystem.readText(filename);
    if (content == null || content.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final signature =
            WebDavExportSignature.fromJson(decoded.cast<String, dynamic>());
        if (signature == null) return null;
        if (signature.accountIdHash.trim() != accountIdHash.trim()) {
          return null;
        }
        return signature;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeExportSignature(
    LocalLibraryFileSystem fileSystem,
    String filename,
    WebDavExportSignature signature,
  ) async {
    await fileSystem.writeText(filename, jsonEncode(signature.toJson()));
  }

  WebDavExportSignature _buildExportSignature({
    required WebDavExportMode mode,
    required String accountIdHash,
    required String snapshotId,
    required WebDavExportFormat exportFormat,
    required String vaultKeyId,
    required DateTime lastSuccessAt,
    String? createdAt,
  }) {
    return WebDavExportSignature(
      schemaVersion: 1,
      mode: mode,
      accountIdHash: accountIdHash,
      createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
      lastSuccessAt: lastSuccessAt.toUtc().toIso8601String(),
      snapshotId: snapshotId,
      exportFormat: exportFormat,
      vaultKeyId: vaultKeyId,
    );
  }

  DateTime _resolveExportLastSuccessAt({
    required DateTime exportAt,
    required DateTime? uploadAt,
    required bool webDavConfigured,
  }) {
    if (webDavConfigured && uploadAt != null) return uploadAt;
    return exportAt;
  }

  Future<bool> _detectPlainExport(LocalLibraryFileSystem fileSystem) async {
    final hasIndex =
        await fileSystem.fileExists('index.md') ||
        await fileSystem.fileExists('index.md.txt');
    if (hasIndex) return true;
    final hasManifest = await fileSystem.fileExists(
      LocalLibraryFileSystem.scanManifestFilename,
    );
    if (hasManifest) return true;
    final hasMemos = await fileSystem.dirExists('memos');
    if (hasMemos) return true;
    final hasAttachments = await fileSystem.dirExists('attachments');
    return hasAttachments;
  }

  Future<void> _deletePlainExportFiles(
    LocalLibraryFileSystem fileSystem,
  ) async {
    await fileSystem.deleteRelativeFile('index.md');
    await fileSystem.deleteRelativeFile('index.md.txt');
    await fileSystem.deleteRelativeFile(
      LocalLibraryFileSystem.scanManifestFilename,
    );
    await fileSystem.deleteDirRelative('memos');
    await fileSystem.deleteDirRelative('attachments');
    await fileSystem.deleteRelativeFile(_exportPlainSignatureFile);
  }

  Future<_SnapshotBuildResult> _buildSnapshot({
    required LocalLibrary? localLibrary,
    required bool includeMemos,
    required List<_BackupConfigFile> configFiles,
    required WebDavBackupIndex index,
    required SecretKey masterKey,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required String snapshotId,
    required String exportedAt,
    required String backupMode,
    _ExportWriter? exportWriter,
  }) async {
    final knownObjects = <String>{...index.objects.keys};
    final newObjectSizes = <String, int>{};
    final objectSizes = <String, int>{};
    final files = <WebDavBackupFileEntry>[];
    var processedFiles = 0;
    var totalFiles = 0;

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
      totalFiles = entries.length + configFiles.length + 1;
      _updateProgress(
        stage: WebDavBackupProgressStage.uploading,
        completed: processedFiles,
        total: totalFiles,
        currentPath: '',
        itemGroup: WebDavBackupProgressItemGroup.other,
      );

      for (final entry in entries) {
        await _waitIfPaused();
        _updateProgress(
          stage: WebDavBackupProgressStage.uploading,
          completed: processedFiles,
          total: totalFiles,
          currentPath: entry.relativePath,
          itemGroup: _progressItemGroupForPath(entry.relativePath),
        );
        final objects = <String>[];
        final stream = await fileSystem.openReadStream(
          entry,
          bufferSize: _chunkSize,
        );
        await for (final chunk in _chunkStream(stream)) {
          final hash = crypto.sha256.convert(chunk).toString();
          objectSizes[hash] = chunk.length;
          objects.add(hash);
          if (exportWriter != null || !knownObjects.contains(hash)) {
            final objectKey = await _deriveObjectKey(masterKey, hash);
            final encrypted = await _encryptBytes(objectKey, chunk);
            if (exportWriter != null) {
              await exportWriter.writeObject(hash, encrypted);
            }
            if (!knownObjects.contains(hash)) {
              await _putBytes(
                client,
                _objectUri(baseUrl, rootPath, accountId, hash),
                encrypted,
              );
              knownObjects.add(hash);
              newObjectSizes[hash] = chunk.length;
            }
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
        processedFiles += 1;
        _updateProgress(
          stage: WebDavBackupProgressStage.uploading,
          completed: processedFiles,
          total: totalFiles,
          currentPath: entry.relativePath,
          itemGroup: _progressItemGroupForPath(entry.relativePath),
        );
      }
    }

    if (configFiles.isNotEmpty) {
      for (final configFile in configFiles) {
        if (totalFiles == 0) {
          totalFiles = configFiles.length + 1;
          _updateProgress(
            stage: WebDavBackupProgressStage.uploading,
            completed: processedFiles,
            total: totalFiles,
            currentPath: '',
            itemGroup: WebDavBackupProgressItemGroup.other,
          );
        }
        await _waitIfPaused();
        _updateProgress(
          stage: WebDavBackupProgressStage.uploading,
          completed: processedFiles,
          total: totalFiles,
          currentPath: configFile.path,
          itemGroup: WebDavBackupProgressItemGroup.config,
        );
        final payloadBytes = configFile.bytes;
        final hash = crypto.sha256.convert(payloadBytes).toString();
        if (exportWriter != null || !knownObjects.contains(hash)) {
          final objectKey = await _deriveObjectKey(masterKey, hash);
          final encrypted = await _encryptBytes(objectKey, payloadBytes);
          if (exportWriter != null) {
            await exportWriter.writeObject(hash, encrypted);
          }
          if (!knownObjects.contains(hash)) {
            await _putBytes(
              client,
              _objectUri(baseUrl, rootPath, accountId, hash),
              encrypted,
            );
            knownObjects.add(hash);
            newObjectSizes[hash] = payloadBytes.length;
          }
        }
        objectSizes[hash] = payloadBytes.length;
        files.add(
          WebDavBackupFileEntry(
            path: configFile.path,
            size: payloadBytes.length,
            objects: [hash],
            modifiedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        processedFiles += 1;
        _updateProgress(
          stage: WebDavBackupProgressStage.uploading,
          completed: processedFiles,
          total: totalFiles,
          currentPath: configFile.path,
          itemGroup: WebDavBackupProgressItemGroup.config,
        );
      }
    }

    final memoCount = _countMemosInEntries(files);
    final attachmentCount = _countAttachmentsInEntries(files);
    final totalSize = files.fold<int>(
      0,
      (sum, entry) => sum + entry.size,
    );
    final manifest = WebDavBackupManifest(
      schemaVersion: 1,
      exportedAt: exportedAt,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      totalSize: totalSize,
      backupMode: backupMode,
      encrypted: true,
    );
    final manifestBytes = _encodeJsonBytes(manifest.toJson());
    final manifestHash = crypto.sha256.convert(manifestBytes).toString();
    if (exportWriter != null || !knownObjects.contains(manifestHash)) {
      final objectKey = await _deriveObjectKey(masterKey, manifestHash);
      final encrypted = await _encryptBytes(objectKey, manifestBytes);
      if (exportWriter != null) {
        await exportWriter.writeObject(manifestHash, encrypted);
      }
      if (!knownObjects.contains(manifestHash)) {
        await _putBytes(
          client,
          _objectUri(baseUrl, rootPath, accountId, manifestHash),
          encrypted,
        );
        knownObjects.add(manifestHash);
        newObjectSizes[manifestHash] = manifestBytes.length;
      }
    }
    objectSizes[manifestHash] = manifestBytes.length;
    files.add(
      WebDavBackupFileEntry(
        path: _backupManifestFile,
        size: manifestBytes.length,
        objects: [manifestHash],
        modifiedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    processedFiles += 1;
    _updateProgress(
      stage: WebDavBackupProgressStage.uploading,
      completed: processedFiles,
      total: totalFiles > 0 ? totalFiles : processedFiles,
      currentPath: _backupManifestFile,
      itemGroup: WebDavBackupProgressItemGroup.manifest,
    );

    final snapshot = WebDavBackupSnapshot(
      schemaVersion: 1,
      id: snapshotId,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      files: files,
    );
    return _SnapshotBuildResult(
      snapshot: snapshot,
      newObjectSizes: newObjectSizes,
      objectSizes: objectSizes,
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

  WebDavBackupIndex _buildExportIndexFromSnapshot({
    required WebDavBackupSnapshot snapshot,
    required Map<String, int> objectSizes,
    required DateTime now,
  }) {
    final totalBytes = snapshot.files.fold<int>(
      0,
      (sum, entry) => sum + entry.size,
    );
    final memosCount = _countMemosInSnapshot(snapshot);
    final snapshotInfo = WebDavBackupSnapshotInfo(
      id: snapshot.id,
      createdAt: snapshot.createdAt,
      memosCount: memosCount,
      fileCount: snapshot.files.length,
      totalBytes: totalBytes,
    );
    final snapshotObjects = <String>{};
    for (final file in snapshot.files) {
      snapshotObjects.addAll(file.objects);
    }
    final objects = <String, WebDavBackupObjectInfo>{};
    for (final hash in snapshotObjects) {
      objects[hash] = WebDavBackupObjectInfo(
        size: objectSizes[hash] ?? 0,
        refs: 1,
      );
    }
    return WebDavBackupIndex(
      schemaVersion: 1,
      updatedAt: now.toUtc().toIso8601String(),
      snapshots: [snapshotInfo],
      objects: objects,
    );
  }

  bool _assertExportMirrorIntegritySync({
    required LocalLibrary exportLibrary,
    required WebDavBackupIndex exportIndex,
    required String backupBaseDir,
  }) {
    if (exportLibrary.isSaf) return true;
    final rootPath = exportLibrary.rootPath ?? '';
    if (rootPath.trim().isEmpty) return true;
    final basePath = p.join(rootPath, backupBaseDir);
    final indexPath = p.join(basePath, _backupIndexFile);
    if (!File(indexPath).existsSync()) return false;
    for (final snapshot in exportIndex.snapshots) {
      final snapshotPath = p.join(
        basePath,
        _backupSnapshotsDir,
        '${snapshot.id}.enc',
      );
      if (!File(snapshotPath).existsSync()) return false;
    }
    for (final hash in exportIndex.objects.keys) {
      final objectPath = p.join(basePath, _backupObjectsDir, '$hash.bin');
      if (!File(objectPath).existsSync()) return false;
    }
    return true;
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

  Future<void> _restoreFileToPath({
    required WebDavBackupFileEntry entry,
    required String targetPath,
    required LocalLibraryFileSystem fileSystem,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
  }) async {
    final controller = StreamController<Uint8List>();
    final writeFuture = fileSystem.writeFileFromChunks(
      targetPath,
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

  Future<Uint8List> _readSnapshotFileBytes({
    required WebDavBackupFileEntry entry,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
  }) async {
    if (entry.objects.isEmpty) return Uint8List(0);
    final builder = BytesBuilder(copy: false);
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
      builder.add(plain);
    }
    return builder.toBytes();
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

  String _backupBaseDir(String accountId) {
    return 'accounts/$accountId/$_backupDir/$_backupVersion';
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

  Future<String?> _resolveVaultPassword(String? override) async {
    if (override != null && override.trim().isNotEmpty) return override;
    return _vaultPasswordRepository.read();
  }

  Future<SecretKey> _resolveMasterKeyFromLegacy({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required String password,
  }) async {
    final config = await _loadConfig(client, baseUrl, rootPath, accountId);
    if (config == null) {
      throw _keyedError(
        'legacy.msg_no_backups_found',
        code: SyncErrorCode.unknown,
      );
    }
    return _resolveMasterKey(password, config);
  }

  Future<SecretKey> _resolveVaultMasterKey({
    required WebDavSettings settings,
    required String accountKey,
    required String password,
  }) async {
    final config = await _vaultService.loadConfig(
      settings: settings,
      accountKey: accountKey,
    );
    if (config == null) {
      throw _keyedError(
        'legacy.webdav.config_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    return _vaultService.resolveMasterKey(password, config);
  }

  Future<void> _decryptObject({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required String hash,
  }) async {
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
    await _decryptBytes(key, objectData);
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

class _ExportWriter {
  _ExportWriter({
    required this.library,
    required this.backupBaseDir,
    required this.exportStagingDir,
    required this.chunkSize,
    this.logEvent,
  }) : _fileSystem = LocalLibraryFileSystem(library);

  final LocalLibrary library;
  final String backupBaseDir;
  final String exportStagingDir;
  final int chunkSize;
  final void Function(String label, {String? detail, Object? error})? logEvent;
  final LocalLibraryFileSystem _fileSystem;

  String _resolvedPath(String relative) {
    return '$exportStagingDir/$backupBaseDir/$relative';
  }

  Future<void> writeObject(String hash, Uint8List bytes) async {
    await _writeBytes('objects/$hash.bin', bytes);
  }

  Future<void> writeSnapshot(String snapshotId, Uint8List bytes) async {
    await _writeBytes('snapshots/$snapshotId.enc', bytes);
  }

  Future<void> writeIndex(Uint8List bytes) async {
    await _writeBytes('index.enc', bytes);
  }

  Future<void> writeConfig(Uint8List bytes) async {
    await _writeBytes('config.json', bytes);
  }

  Future<void> _writeBytes(String relative, Uint8List bytes) async {
    await _fileSystem.writeFileFromChunks(
      _resolvedPath(relative),
      Stream<Uint8List>.value(bytes),
      mimeType: 'application/octet-stream',
    );
  }

  Future<void> commit() async {
    if (library.isSaf) {
      await _promoteStagingSaf();
    } else {
      await _promoteStagingLocal();
    }
  }

  Future<void> _promoteStagingSaf() async {
    final prefix = '$exportStagingDir/';
    final entries = await _fileSystem.listAllFiles();
    for (final entry in entries) {
      if (!entry.relativePath.startsWith(prefix)) continue;
      final target = entry.relativePath.substring(prefix.length);
      final stream = await _fileSystem.openReadStream(
        entry,
        bufferSize: chunkSize,
      );
      await _fileSystem.writeFileFromChunks(
        target,
        stream,
        mimeType: 'application/octet-stream',
      );
    }
    await _fileSystem.deleteDirRelative(exportStagingDir);
  }

  Future<void> _promoteStagingLocal() async {
    final rootPath = library.rootPath ?? '';
    if (rootPath.trim().isEmpty) return;
    final stagingBase = p.join(rootPath, exportStagingDir, backupBaseDir);
    final finalBase = p.join(rootPath, backupBaseDir);
    final stagingDir = Directory(stagingBase);
    if (!stagingDir.existsSync()) return;
    final finalDir = Directory(finalBase);
    final finalParent = Directory(p.dirname(finalBase));
    if (!finalParent.existsSync()) {
      finalParent.createSync(recursive: true);
    }
    final prevPath = '$finalBase.prev';
    final prevDir = Directory(prevPath);
    if (finalDir.existsSync()) {
      if (prevDir.existsSync()) {
        prevDir.deleteSync(recursive: true);
      }
      await finalDir.rename(prevPath);
    }
    await stagingDir.rename(finalBase);
    if (prevDir.existsSync()) {
      try {
        await prevDir.delete(recursive: true);
      } catch (error) {
        logEvent?.call(
          'Export cleanup failed',
          detail: prevDir.path,
          error: error,
        );
      }
    }
    final stagingRoot = Directory(p.join(rootPath, exportStagingDir));
    if (stagingRoot.existsSync()) {
      try {
        await stagingRoot.delete(recursive: true);
      } catch (error) {
        logEvent?.call(
          'Export staging cleanup failed',
          detail: stagingRoot.path,
          error: error,
        );
      }
    }
  }
}

class _SnapshotBuildResult {
  const _SnapshotBuildResult({
    required this.snapshot,
    required this.newObjectSizes,
    required this.objectSizes,
  });

  final WebDavBackupSnapshot snapshot;
  final Map<String, int> newObjectSizes;
  final Map<String, int> objectSizes;
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
