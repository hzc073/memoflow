part of '../webdav_backup_service.dart';

enum WebDavBackupExportIssueKind { memo, attachment }

enum WebDavBackupExportAction { retry, skip, abort }

enum WebDavExportCleanupStatus { cleaned, notFound, blocked }

enum WebDavBackupConfigType {
  preferences,
  aiSettings,
  reminderSettings,
  imageBedSettings,
  imageCompressionSettings,
  locationSettings,
  templateSettings,
  appLock,
  noteDraft,
  draftBox,
  tags,
  webdavSettings,
}

class WebDavBackupConfigBundle {
  const WebDavBackupConfigBundle({
    this.preferences,
    this.aiSettings,
    this.reminderSettings,
    this.imageBedSettings,
    this.imageCompressionSettings,
    this.locationSettings,
    this.templateSettings,
    this.appLockSnapshot,
    this.noteDraft,
    this.draftBox,
    this.tagsSnapshot,
    this.webDavSettings,
  });

  final AppPreferences? preferences;
  final AiSettings? aiSettings;
  final ReminderSettings? reminderSettings;
  final ImageBedSettings? imageBedSettings;
  final ImageCompressionSettings? imageCompressionSettings;
  final LocationSettings? locationSettings;
  final MemoTemplateSettings? templateSettings;
  final AppLockSnapshot? appLockSnapshot;
  final String? noteDraft;
  final ComposeDraftTransferBundle? draftBox;
  final TagSnapshot? tagsSnapshot;
  final WebDavSettings? webDavSettings;

  bool get isEmpty =>
      preferences == null &&
      aiSettings == null &&
      reminderSettings == null &&
      imageBedSettings == null &&
      imageCompressionSettings == null &&
      locationSettings == null &&
      templateSettings == null &&
      appLockSnapshot == null &&
      noteDraft == null &&
      draftBox == null &&
      tagsSnapshot == null &&
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
  WebDavBackupConfigType.imageCompressionSettings,
  WebDavBackupConfigType.draftBox,
  WebDavBackupConfigType.tags,
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
  WebDavBackupConfigType.imageCompressionSettings,
  WebDavBackupConfigType.draftBox,
  WebDavBackupConfigType.tags,
};

const _fullBackupConfigTypes = <WebDavBackupConfigType>{
  WebDavBackupConfigType.preferences,
  WebDavBackupConfigType.reminderSettings,
  WebDavBackupConfigType.templateSettings,
  WebDavBackupConfigType.locationSettings,
  WebDavBackupConfigType.webdavSettings,
  WebDavBackupConfigType.imageBedSettings,
  WebDavBackupConfigType.imageCompressionSettings,
  WebDavBackupConfigType.appLock,
  WebDavBackupConfigType.noteDraft,
  WebDavBackupConfigType.draftBox,
  WebDavBackupConfigType.aiSettings,
  WebDavBackupConfigType.tags,
};

const _backupDir = 'backup';
const _backupVersion = 'v1';
const _backupConfigFile = 'config.json';
const _backupIndexFile = 'index.enc';
const _backupObjectsDir = 'objects';
const _backupSnapshotsDir = 'snapshots';
const _backupConfigDir = 'config';
const _backupSettingsSnapshotPath = 'config/webdav_settings.json';
const _backupPreferencesSnapshotPath = 'config/preferences.json';
const _backupAiSettingsSnapshotPath = 'config/ai_settings.json';
const _backupReminderSnapshotPath = 'config/reminder_settings.json';
const _backupImageBedSnapshotPath = 'config/image_bed.json';
const _backupImageCompressionSnapshotPath =
    'config/image_compression_settings.json';
const _backupLocationSnapshotPath = 'config/location_settings.json';
const _backupTemplateSnapshotPath = 'config/template_settings.json';
const _backupAppLockSnapshotPath = 'config/app_lock.json';
const _backupNoteDraftSnapshotPath = 'config/note_draft.json';
const _backupDraftBoxSnapshotPath = composeDraftTransferConfigPath;
const _backupTagsSnapshotPath = 'config/tags.json';
const _backupManifestFile = 'manifest.json';
const _plainBackupIndexFile = 'index.json';
const _exportEncSignatureFile = '.memoflow_export_enc.json';
const _exportPlainSignatureFile = '.memoflow_export_plain.json';
const _exportStagingDir = '.memoflow_export_staging';
const _chunkSize = 4 * 1024 * 1024;
const _nonceLength = 12;
const _macLength = 16;

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

typedef WebDavBackupClientFactory =
    WebDavClient Function({
      required Uri baseUrl,
      required WebDavSettings settings,
      void Function(DebugLogEntry entry)? logWriter,
    });

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
        final entry = _PlainBackupFile.fromJson(item.cast<String, dynamic>());
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
