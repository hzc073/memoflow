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
import 'package:saf_stream/saf_stream.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/attachment_url.dart';
import '../../core/hash.dart';
import '../../core/log_sanitizer.dart';
import '../../core/url.dart';
import '../../core/webdav_url.dart';
import '../../data/db/app_database.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../../data/local_library/local_library_fs.dart';
import '../../data/local_library/local_library_markdown.dart';
import '../../data/local_library/local_library_naming.dart';
import '../../data/local_library/local_library_paths.dart';
import '../../data/models/attachment.dart';
import '../../data/models/image_compression_settings.dart';
import '../../data/models/image_bed_settings.dart';
import '../../data/models/local_library.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/tag_snapshot.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_backup_state.dart';
import '../../data/models/webdav_export_signature.dart';
import '../../data/models/webdav_export_status.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/logs/webdav_backup_progress_tracker.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/models/app_lock.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/reminder_settings.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../data/repositories/webdav_backup_password_repository.dart';
import '../../data/repositories/webdav_backup_state_repository.dart';
import '../../data/repositories/webdav_vault_password_repository.dart';
import '../../data/webdav/webdav_client.dart';
import 'local_library_scan_service.dart';
import 'sync_error.dart';
import 'sync_types.dart';
import 'webdav_sync_service.dart';
import 'webdav_vault_service.dart';

part 'webdav_backup/webdav_backup_models.dart';
part 'webdav_backup/webdav_backup_progress.dart';
part 'webdav_backup/webdav_backup_crypto.dart';
part 'webdav_backup/webdav_backup_io.dart';
part 'webdav_backup/webdav_backup_manifest.dart';
part 'webdav_backup/webdav_backup_export.dart';
part 'webdav_backup/webdav_backup_import.dart';

abstract class _WebDavBackupServiceBase {
  AppDatabase get _db;
  Future<T> _withBoundDatabase<T>(Future<T> Function() action);
  LocalAttachmentStore get _attachmentStore;
  WebDavBackupStateRepository get _stateRepository;
  WebDavBackupPasswordRepository get _passwordRepository;
  WebDavVaultService get _vaultService;
  WebDavVaultPasswordRepository get _vaultPasswordRepository;
  WebDavSyncLocalAdapter? get _configAdapter;
  WebDavBackupProgressTracker? get _progressTracker;
  LocalLibraryScanService Function(LocalLibrary library)?
  get _scanServiceFactory;
  WebDavBackupClientFactory get _clientFactory;
  void Function(DebugLogEntry entry)? get _logWriter;
  AesGcm get _cipher;
  Random get _random;

  void _logEvent(String label, {String? detail, Object? error});
  void _startProgress(WebDavBackupProgressOperation operation);
  void _updateProgress({
    WebDavBackupProgressStage? stage,
    int? completed,
    int? total,
    String? currentPath,
    WebDavBackupProgressItemGroup? itemGroup,
  });
  Future<void> _waitIfPaused();
  void _finishProgress();
  Future<void> _setWakelockEnabled(bool enabled);
  WebDavBackupProgressItemGroup _progressItemGroupForPath(String rawPath);
  Duration _scheduleDuration(WebDavBackupSchedule schedule);
  DateTime _addMonths(DateTime date, int months);
  bool _isBackupDue(DateTime? last, WebDavBackupSchedule schedule);
  DateTime? _parseIso(String? raw);

  Future<void> _putJson(
    WebDavClient client,
    Uri uri,
    Map<String, dynamic> json,
  );
  Future<void> _putBytes(WebDavClient client, Uri uri, List<int> bytes);
  Future<Uint8List?> _getBytes(WebDavClient client, Uri uri);
  Future<void> _delete(WebDavClient client, Uri uri);
  Uri _configUri(Uri baseUrl, String rootPath, String accountId);
  Uri _indexUri(Uri baseUrl, String rootPath, String accountId);
  Uri _objectUri(Uri baseUrl, String rootPath, String accountId, String hash);
  Uri _snapshotUri(
    Uri baseUrl,
    String rootPath,
    String accountId,
    String snapshotId,
  );
  String _backupBase(String accountId, String relative);
  String _backupBaseDir(String accountId);
  String _plainBase(String accountId, String relative);
  Uri _plainIndexUri(Uri baseUrl, String rootPath, String accountId);
  Uri _plainFileUri(
    Uri baseUrl,
    String rootPath,
    String accountId,
    String relativePath,
  );
  Future<void> _ensureBackupCollections(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  );
  Future<void> _ensureCollectionPath(
    WebDavClient client,
    Uri baseUrl,
    List<String> segments,
  );
  List<String> _splitPath(String path);
  WebDavClient _buildClient(WebDavSettings settings, Uri baseUrl);
  Uri _parseBaseUrl(String raw);
  Stream<Uint8List> _chunkStream(Stream<Uint8List> input);
  String _parentDirectory(String relativePath);
  Future<Uint8List> _readLocalEntryBytes(
    LocalLibraryFileSystem? fileSystem,
    LocalLibraryFileEntry? entry,
  );
  Future<_PlainBackupIndex?> _loadPlainIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  );
  Future<WebDavBackupConfig?> _loadConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  );
  Future<WebDavBackupConfig> _loadOrCreateConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    String password,
  );
  Future<void> _saveConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    WebDavBackupConfig config,
  );
  String _guessMimeType(String path);
  SyncError _keyedError(String key, {SyncErrorCode code});
  SyncError _httpError({
    required int statusCode,
    required String method,
    required Uri uri,
  });
  SyncError _mapUnexpectedError(Object error);

  Future<String?> _resolvePassword(String? override);
  Future<String?> _resolveVaultPassword(String? override);
  Future<SecretKey> _resolveMasterKeyFromLegacy({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required String password,
  });
  Future<SecretKey> _resolveVaultMasterKey({
    required WebDavSettings settings,
    required String accountKey,
    required String password,
  });
  Future<SecretKey> _resolveMasterKey(
    String password,
    WebDavBackupConfig config,
  );
  Future<SecretKey> _resolveMasterKeyWithRecoveryCode(
    String recoveryCode,
    WebDavBackupConfig config,
  );
  Future<SecretKey> _deriveKeyFromPassword(
    String password,
    WebDavBackupKdf kdf,
  );
  Future<SecretKey> _deriveSubKey(SecretKey masterKey, String info);
  Future<SecretKey> _deriveObjectKey(SecretKey masterKey, String objectHash);
  Future<Uint8List> _encryptBytes(SecretKey key, List<int> plain);
  Future<Uint8List> _decryptBytes(SecretKey key, List<int> combined);
  Future<Uint8List> _encryptJson(SecretKey key, Map<String, dynamic> json);
  Future<dynamic> _decryptJson(SecretKey key, List<int> data);
  Uint8List _randomBytes(int length);
  Future<void> _decryptObject({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required String hash,
  });

  Map<String, dynamic> _buildBackupSettingsSnapshotPayload(
    WebDavSettings settings, {
    required String exportedAt,
  });
  Map<String, dynamic> _wrapConfigPayload({
    required String exportedAt,
    required Object? data,
  });
  Uint8List _encodeJsonBytes(Object payload);
  String _resolveBackupMode({required bool usesServerMode});
  String _formatExportPathLabel(LocalLibrary library, String prefix);
  String _prefixExportPath(String prefix, String relativePath);
  Set<WebDavBackupConfigType> _resolveBackupConfigTypes({
    required WebDavBackupConfigScope scope,
    required WebDavBackupEncryptionMode encryptionMode,
  });
  WebDavBackupConfigType? _configTypeForPath(String path);
  Future<List<_BackupConfigFile>> _buildConfigFiles({
    required WebDavSettings settings,
    required WebDavBackupConfigScope scope,
    required String exportedAt,
  });
  WebDavBackupConfigBundle _parseConfigBundle(
    Map<WebDavBackupConfigType, Uint8List> configBytes,
  );
  Object? _decodeJsonValue(Uint8List bytes);
  bool _isValidConfigEnvelope(Map<String, dynamic> envelope);
  Map<String, dynamic>? _extractLegacyWebDavSettings(
    Map<String, dynamic> envelope,
  );
  Set<WebDavBackupConfigType> _availableConfigTypes(
    WebDavBackupConfigBundle bundle,
  );
  Future<void> _applyConfigBundle({
    required WebDavBackupConfigBundle bundle,
    WebDavBackupConfigDecisionHandler? decisionHandler,
  });

  int _countMemosInSnapshot(WebDavBackupSnapshot snapshot);
  int _countMemosInEntries(Iterable<WebDavBackupFileEntry> entries);
  int _countAttachmentsInEntries(Iterable<WebDavBackupFileEntry> entries);
  bool _snapshotHasMemos(WebDavBackupSnapshot snapshot);
  int _countMemosInPlainIndex(_PlainBackupIndex index);
  int _countMemosInUploads(Iterable<_PlainBackupFileUpload> uploads);
  int _countAttachmentsInUploads(Iterable<_PlainBackupFileUpload> uploads);
  bool _plainIndexHasMemos(_PlainBackupIndex index);
  bool _isMemoPath(String rawPath);
  bool _isAttachmentPath(String rawPath);
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
  });
  WebDavBackupIndex _applySnapshotToIndex(
    WebDavBackupIndex index,
    WebDavBackupSnapshot snapshot,
    DateTime now,
    Map<String, int> newObjectSizes,
  );
  WebDavBackupIndex _buildExportIndexFromSnapshot({
    required WebDavBackupSnapshot snapshot,
    required Map<String, int> objectSizes,
    required DateTime now,
  });
  bool _assertExportMirrorIntegritySync({
    required LocalLibrary exportLibrary,
    required WebDavBackupIndex exportIndex,
    required String backupBaseDir,
  });
  Future<WebDavBackupIndex> _applyRetention({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required WebDavBackupIndex index,
    required int retention,
  });
  Future<void> _uploadSnapshot(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
    WebDavBackupSnapshot snapshot,
  );
  Future<void> _saveIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
    WebDavBackupIndex index,
  );
  Future<WebDavBackupIndex> _loadIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
  );
  Future<WebDavBackupSnapshot> _loadSnapshot({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required String snapshotId,
  });
  Future<Uint8List> _readSnapshotFileBytes({
    required WebDavBackupFileEntry entry,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
  });
  String _buildSnapshotId(DateTime now);

  Future<LocalLibrary?> _resolveBackupLibrary(
    WebDavSettings settings,
    LocalLibrary? activeLocalLibrary,
    String? accountId,
  );
  Future<int> _exportLocalLibraryForBackup(LocalLibrary localLibrary);
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
  });
  Future<WebDavBackupExportResolution> _resolveExportIssue({
    required WebDavBackupExportIssue issue,
    required WebDavBackupExportIssueHandler? issueHandler,
    required Map<WebDavBackupExportIssueKind, WebDavBackupExportResolution>
    stickyResolutions,
  });
  String _formatExportIssueMessage(WebDavBackupExportIssue issue);
  String _dedupeAttachmentFilename(String filename, Set<String> used);
  Future<String?> _resolveAttachmentSourcePath({
    required LocalAttachmentStore attachmentStore,
    required String memoUid,
    required Attachment attachment,
    required String lookupName,
  });
  String? _resolveAttachmentUrl(Uri? baseUrl, Attachment attachment);
  Future<void> _pruneMirrorLibraryFiles({
    required LocalLibraryFileSystem fileSystem,
    required Set<String> targetMemoUids,
    required Map<String, Set<String>> expectedAttachmentsByMemo,
    required Set<String> skipAttachmentPruneUids,
  });
  String? _parseMemoUidFromFileName(String fileName);
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
  });
  Map<String, dynamic> _buildPlainBackupIndexPayload(
    List<_PlainBackupFileUpload> uploads,
    DateTime now,
  );
  Future<WebDavExportSignature?> _readExportSignature(
    LocalLibraryFileSystem fileSystem,
    String filename,
    String accountIdHash,
  );
  Future<void> _writeExportSignature(
    LocalLibraryFileSystem fileSystem,
    String filename,
    WebDavExportSignature signature,
  );
  WebDavExportSignature _buildExportSignature({
    required WebDavExportMode mode,
    required String accountIdHash,
    required String snapshotId,
    required WebDavExportFormat exportFormat,
    required String vaultKeyId,
    required DateTime lastSuccessAt,
  });
  DateTime _resolveExportLastSuccessAt({
    required DateTime exportAt,
    required DateTime? uploadAt,
    required bool webDavConfigured,
  });
  Future<bool> _detectPlainExport(LocalLibraryFileSystem fileSystem);
  Future<void> _deletePlainExportFiles(LocalLibraryFileSystem fileSystem);

  Future<void> _restoreFile({
    required WebDavBackupFileEntry entry,
    required LocalLibraryFileSystem fileSystem,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
  });
  Future<void> _restoreFileToPath({
    required WebDavBackupFileEntry entry,
    required String targetPath,
    required LocalLibraryFileSystem fileSystem,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
  });
  LocalLibraryScanService? _scanServiceFor(LocalLibrary library);
}

class WebDavBackupService extends _WebDavBackupServiceBase
    with
        _WebDavBackupProgressMixin,
        _WebDavBackupCryptoMixin,
        _WebDavBackupIoMixin,
        _WebDavBackupManifestMixin,
        _WebDavBackupExportMixin,
        _WebDavBackupImportMixin {
  WebDavBackupService({
    required AppDatabase Function() readDatabase,
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
  }) : _readDatabase = readDatabase,
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

  final AppDatabase Function() _readDatabase;
  @override
  final LocalAttachmentStore _attachmentStore;
  @override
  final WebDavBackupStateRepository _stateRepository;
  @override
  final WebDavBackupPasswordRepository _passwordRepository;
  @override
  final WebDavVaultService _vaultService;
  @override
  final WebDavVaultPasswordRepository _vaultPasswordRepository;
  @override
  final WebDavSyncLocalAdapter? _configAdapter;
  @override
  final WebDavBackupProgressTracker? _progressTracker;
  @override
  final LocalLibraryScanService Function(LocalLibrary library)?
  _scanServiceFactory;
  @override
  final WebDavBackupClientFactory _clientFactory;
  @override
  final void Function(DebugLogEntry entry)? _logWriter;

  @override
  final _cipher = AesGcm.with256bits();
  @override
  final _random = Random.secure();
  AppDatabase? _boundDatabase;

  @override
  Future<T> _withBoundDatabase<T>(Future<T> Function() action) async {
    final previous = _boundDatabase;
    _boundDatabase ??= _readDatabase();
    try {
      return await action();
    } finally {
      _boundDatabase = previous;
    }
  }

  @override
  AppDatabase get _db => _boundDatabase ?? _readDatabase();
}
