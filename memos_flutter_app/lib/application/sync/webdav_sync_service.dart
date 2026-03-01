import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/hash.dart';
import '../../core/log_sanitizer.dart';
import '../../core/webdav_url.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/models/image_bed_settings.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/models/webdav_sync_meta.dart';
import '../../data/models/webdav_sync_state.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../../data/settings/webdav_device_id_repository.dart';
import '../../data/settings/webdav_sync_state_repository.dart';
import '../../data/webdav/webdav_client.dart';
import '../../state/app_lock_provider.dart' show AppLockSnapshot;
import '../../state/preferences_provider.dart' show AppPreferences;
import '../../state/reminder_settings_provider.dart' show ReminderSettings;
import 'sync_error.dart';
import 'sync_types.dart';

const _webDavMetaFile = 'meta.json';
const _webDavPreferencesFile = 'preferences.json';
const _webDavAiFile = 'ai_settings.json';
const _webDavAppLockFile = 'app_lock.json';
const _webDavDraftFile = 'note_draft.json';
const _webDavReminderFile = 'reminder_settings.json';
const _webDavImageBedFile = 'image_bed.json';
const _webDavLocationFile = 'location_settings.json';
const _webDavTemplateFile = 'template_settings.json';

class WebDavSyncLocalSnapshot {
  const WebDavSyncLocalSnapshot({
    required this.preferences,
    required this.aiSettings,
    required this.reminderSettings,
    required this.imageBedSettings,
    required this.locationSettings,
    required this.templateSettings,
    required this.appLockSnapshot,
    required this.noteDraft,
  });

  final AppPreferences preferences;
  final AiSettings aiSettings;
  final ReminderSettings reminderSettings;
  final ImageBedSettings imageBedSettings;
  final LocationSettings locationSettings;
  final MemoTemplateSettings templateSettings;
  final AppLockSnapshot appLockSnapshot;
  final String noteDraft;
}

abstract class WebDavSyncLocalAdapter {
  Future<WebDavSyncLocalSnapshot> readSnapshot();

  Future<void> applyPreferences(AppPreferences preferences);
  Future<void> applyAiSettings(AiSettings settings);
  Future<void> applyReminderSettings(ReminderSettings settings);
  Future<void> applyImageBedSettings(ImageBedSettings settings);
  Future<void> applyLocationSettings(LocationSettings settings);
  Future<void> applyTemplateSettings(MemoTemplateSettings settings);
  Future<void> applyAppLockSnapshot(AppLockSnapshot snapshot);
  Future<void> applyNoteDraft(String text);
}

typedef WebDavClientFactory = WebDavClient Function({
  required Uri baseUrl,
  required WebDavSettings settings,
  void Function(DebugLogEntry entry)? logWriter,
});

class WebDavSyncService {
  WebDavSyncService({
    required WebDavSyncStateRepository syncStateRepository,
    required WebDavDeviceIdRepository deviceIdRepository,
    required WebDavSyncLocalAdapter localAdapter,
    WebDavClientFactory? clientFactory,
    void Function(DebugLogEntry entry)? logWriter,
  }) : _syncStateRepository = syncStateRepository,
       _deviceIdRepository = deviceIdRepository,
       _localAdapter = localAdapter,
       _clientFactory = clientFactory ?? _defaultClientFactory,
       _logWriter = logWriter;

  final WebDavSyncStateRepository _syncStateRepository;
  final WebDavDeviceIdRepository _deviceIdRepository;
  final WebDavSyncLocalAdapter _localAdapter;
  final WebDavClientFactory _clientFactory;
  final void Function(DebugLogEntry entry)? _logWriter;

  Future<WebDavSyncResult> syncNow({
    required WebDavSettings settings,
    required String? accountKey,
    Map<String, bool>? conflictResolutions,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (!_canSync(settings) || normalizedAccountKey.isEmpty) {
      final reason = SyncError(
        code: SyncErrorCode.invalidConfig,
        retryable: false,
        presentationKey: 'legacy.webdav.not_configured',
      );
      _logEvent('Sync skipped', detail: 'not_configured');
      return WebDavSyncSkipped(reason: reason);
    }

    final baseUrl = Uri.tryParse(settings.serverUrl.trim());
    if (baseUrl == null || !baseUrl.hasScheme || !baseUrl.hasAuthority) {
      final error = SyncError(
        code: SyncErrorCode.invalidConfig,
        retryable: false,
        presentationKey: 'legacy.msg_invalid_webdav_server_url',
        presentationParams: const {'prefix': 'Bad state: '},
      );
      _logEvent('Sync failed', error: error);
      return WebDavSyncFailure(error);
    }

    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _clientFactory(
      baseUrl: baseUrl,
      settings: settings,
      logWriter: _logWriter,
    );
    _logEvent('Sync started');
    try {
      await _ensureCollections(client, baseUrl, rootPath, accountId);
      final lastSync = await _syncStateRepository.read();
      final snapshot = await _localAdapter.readSnapshot();
      final localPayloads = _buildLocalPayloads(snapshot);
      final remoteMeta = await _fetchRemoteMeta(
        client,
        baseUrl,
        rootPath,
        accountId,
      );
      final diff = _diffFiles(localPayloads, remoteMeta, lastSync);
      final diffDetail =
          'uploads=${diff.uploads.length} downloads=${diff.downloads.length} conflicts=${diff.conflicts.length}';

      if (diff.conflicts.isNotEmpty) {
        if (conflictResolutions == null) {
          _logEvent('Sync blocked', detail: 'conflicts_detected');
          return WebDavSyncConflict(diff.conflicts.toList(growable: false));
        }
        diff.applyConflictChoices(conflictResolutions);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _downloadRemote(
        client,
        baseUrl,
        rootPath,
        accountId,
        diff.downloads,
      );
      await _uploadLocal(
        client,
        baseUrl,
        rootPath,
        accountId,
        diff.uploads,
        localPayloads,
      );
      final mergedMeta = _buildMergedMeta(
        localPayloads,
        remoteMeta,
        diff,
        now,
        await _resolveDeviceId(),
      );
      await _writeRemoteMeta(
        client,
        baseUrl,
        rootPath,
        accountId,
        mergedMeta,
      );
      await _syncStateRepository.write(
        WebDavSyncState(lastSyncAt: now, files: mergedMeta.files),
      );
      _logEvent('Sync completed', detail: diffDetail);
      return const WebDavSyncSuccess();
    } on SyncError catch (error) {
      _logEvent('Sync failed', error: error);
      return WebDavSyncFailure(error);
    } catch (error) {
      final mapped = _mapUnexpectedError(error);
      _logEvent('Sync failed', error: mapped);
      return WebDavSyncFailure(mapped);
    } finally {
      await client.close();
    }
  }

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

  bool _canSync(WebDavSettings settings) {
    if (!settings.enabled) return false;
    if (settings.serverUrl.trim().isEmpty) return false;
    if (settings.username.trim().isEmpty && settings.password.trim().isNotEmpty) {
      return false;
    }
    if (settings.username.trim().isNotEmpty && settings.password.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _ensureCollections(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final segments = <String>[..._splitPath(rootPath), 'accounts', accountId];
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
          res.statusCode == 200 ||
          res.statusCode == 409) {
        continue;
      }
      throw _httpError(
        statusCode: res.statusCode,
        message: 'WebDAV mkcol failed (HTTP ${res.statusCode})',
      );
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

  Future<String> _resolveDeviceId() async {
    return _deviceIdRepository.readOrCreate();
  }

  Map<String, _WebDavFilePayload> _buildLocalPayloads(
    WebDavSyncLocalSnapshot snapshot,
  ) {
    return <String, _WebDavFilePayload>{
      _webDavPreferencesFile: _payloadFromJson(
        _preferencesForSync(snapshot.preferences),
      ),
      _webDavAiFile: _payloadFromJson(snapshot.aiSettings.toJson()),
      _webDavReminderFile: _payloadFromJson(snapshot.reminderSettings.toJson()),
      _webDavImageBedFile: _payloadFromJson(snapshot.imageBedSettings.toJson()),
      _webDavLocationFile: _payloadFromJson(snapshot.locationSettings.toJson()),
      _webDavTemplateFile: _payloadFromJson(
        snapshot.templateSettings.toJson(),
      ),
      _webDavAppLockFile: _payloadFromJson(snapshot.appLockSnapshot.toJson()),
      _webDavDraftFile: _payloadFromJson({'text': snapshot.noteDraft}),
    };
  }

  Map<String, dynamic> _preferencesForSync(AppPreferences prefs) {
    final json = Map<String, dynamic>.from(prefs.toJson());
    json.remove('lastSeenAppVersion');
    json.remove('lastSeenAnnouncementVersion');
    json.remove('lastSeenAnnouncementId');
    json.remove('lastSeenNoticeHash');
    json.remove('fontFile');
    json.remove('homeInitialLoadingOverlayShown');
    return json;
  }

  _WebDavFilePayload _payloadFromJson(Map<String, dynamic> json) {
    final encoded = jsonEncode(json);
    final bytes = utf8.encode(encoded);
    final hash = sha256.convert(bytes).toString();
    return _WebDavFilePayload(
      jsonText: encoded,
      hash: hash,
      size: bytes.length,
    );
  }

  Future<WebDavSyncMeta?> _fetchRemoteMeta(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final uri = _fileUri(baseUrl, rootPath, accountId, _webDavMetaFile);
    final res = await client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        message: 'WebDAV meta fetch failed (HTTP ${res.statusCode})',
      );
    }
    try {
      final decoded = jsonDecode(res.bodyText);
      if (decoded is Map) {
        return WebDavSyncMeta.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeRemoteMeta(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    WebDavSyncMeta meta,
  ) async {
    final uri = _fileUri(baseUrl, rootPath, accountId, _webDavMetaFile);
    final payload = utf8.encode(jsonEncode(meta.toJson()));
    final res = await client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        message: 'WebDAV meta update failed (HTTP ${res.statusCode})',
      );
    }
  }

  _WebDavDiff _diffFiles(
    Map<String, _WebDavFilePayload> local,
    WebDavSyncMeta? remote,
    WebDavSyncState lastSync,
  ) {
    final uploads = <String>{};
    final downloads = <String>{};
    final conflicts = <String>{};
    final remoteFiles = remote?.files ?? const <String, WebDavFileMeta>{};
    final lastFiles = lastSync.files;
    for (final entry in local.entries) {
      final name = entry.key;
      final localHash = entry.value.hash;
      final remoteHash = remoteFiles[name]?.hash;
      final lastHash = lastFiles[name]?.hash;
      final localChanged = lastHash == null
          ? localHash.isNotEmpty
          : localHash != lastHash;
      final remoteChanged = lastHash == null
          ? remoteHash != null
          : remoteHash != lastHash;
      if (remoteHash == null) {
        uploads.add(name);
        continue;
      }
      if (localChanged && remoteChanged) {
        if (remoteHash != null && remoteHash != localHash) {
          conflicts.add(name);
        }
        continue;
      }
      if (localChanged && remoteHash != null && remoteHash != localHash) {
        uploads.add(name);
        continue;
      }
      if (remoteChanged && remoteHash != null && remoteHash != localHash) {
        downloads.add(name);
      }
    }
    return _WebDavDiff(
      uploads: uploads,
      downloads: downloads,
      conflicts: conflicts,
    );
  }

  Future<void> _downloadRemote(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    Set<String> files,
  ) async {
    if (files.isEmpty) return;
    for (final name in files) {
      final uri = _fileUri(baseUrl, rootPath, accountId, name);
      final res = await client.get(uri);
      if (res.statusCode == 404) continue;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw _httpError(
          statusCode: res.statusCode,
          message: 'WebDAV download failed (HTTP ${res.statusCode})',
        );
      }
      await _applyRemoteFile(name, res.bodyText);
    }
  }

  Future<void> _uploadLocal(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    Set<String> files,
    Map<String, _WebDavFilePayload> localPayloads,
  ) async {
    if (files.isEmpty) return;
    for (final name in files) {
      final payload = localPayloads[name];
      if (payload == null) continue;
      final uri = _fileUri(baseUrl, rootPath, accountId, name);
      final res = await client.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: utf8.encode(payload.jsonText),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw _httpError(
          statusCode: res.statusCode,
          message: 'WebDAV upload failed (HTTP ${res.statusCode})',
        );
      }
    }
  }

  Future<void> _applyRemoteFile(String name, String raw) async {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        json = decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    if (json == null) return;

    switch (name) {
      case _webDavPreferencesFile:
        final remote = AppPreferences.fromJson(json);
        final merged = await _mergePreferences(remote);
        await _localAdapter.applyPreferences(merged);
        break;
      case _webDavAiFile:
        final settings = AiSettings.fromJson(json);
        await _localAdapter.applyAiSettings(settings);
        break;
      case _webDavReminderFile:
        final current = (await _localAdapter.readSnapshot()).reminderSettings;
        final settings = ReminderSettings.fromJson(json, fallback: current);
        await _localAdapter.applyReminderSettings(settings);
        break;
      case _webDavImageBedFile:
        final settings = ImageBedSettings.fromJson(json);
        await _localAdapter.applyImageBedSettings(settings);
        break;
      case _webDavLocationFile:
        final settings = LocationSettings.fromJson(json);
        await _localAdapter.applyLocationSettings(settings);
        break;
      case _webDavTemplateFile:
        final settings = MemoTemplateSettings.fromJson(json);
        await _localAdapter.applyTemplateSettings(settings);
        break;
      case _webDavAppLockFile:
        final snapshot = AppLockSnapshot.fromJson(json);
        await _localAdapter.applyAppLockSnapshot(snapshot);
        break;
      case _webDavDraftFile:
        final text = (json['text'] as String?) ?? '';
        await _localAdapter.applyNoteDraft(text);
        break;
    }
  }

  Future<AppPreferences> _mergePreferences(AppPreferences remote) async {
    final current = (await _localAdapter.readSnapshot()).preferences;
    final mergedJson = Map<String, dynamic>.from(remote.toJson());
    mergedJson['lastSeenAppVersion'] = current.lastSeenAppVersion;
    mergedJson['lastSeenAnnouncementVersion'] =
        current.lastSeenAnnouncementVersion;
    mergedJson['lastSeenAnnouncementId'] = current.lastSeenAnnouncementId;
    mergedJson['lastSeenNoticeHash'] = current.lastSeenNoticeHash;
    mergedJson['fontFile'] = current.fontFile;
    mergedJson['homeInitialLoadingOverlayShown'] =
        current.homeInitialLoadingOverlayShown;
    return AppPreferences.fromJson(mergedJson);
  }

  Uri _fileUri(Uri baseUrl, String rootPath, String accountId, String name) {
    final relative = 'accounts/$accountId/$name';
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: relative,
    );
  }

  WebDavSyncMeta _buildMergedMeta(
    Map<String, _WebDavFilePayload> localPayloads,
    WebDavSyncMeta? remote,
    _WebDavDiff diff,
    String now,
    String deviceId,
  ) {
    final files = <String, WebDavFileMeta>{};
    for (final entry in localPayloads.entries) {
      final name = entry.key;
      final payload = entry.value;
      final useLocal = diff.uploads.contains(name);
      final useRemote = diff.downloads.contains(name);
      if (useRemote && remote != null) {
        final meta = remote.files[name];
        if (meta != null) {
          files[name] = meta;
          continue;
        }
      }
      if (useLocal || !useRemote) {
        files[name] = WebDavFileMeta(
          hash: payload.hash,
          updatedAt: now,
          size: payload.size,
        );
      }
    }
    return WebDavSyncMeta(
      schemaVersion: 1,
      deviceId: deviceId,
      updatedAt: now,
      files: files,
    );
  }

  SyncError _httpError({required int statusCode, required String message}) {
    final code = switch (statusCode) {
      401 => SyncErrorCode.authFailed,
      403 => SyncErrorCode.permission,
      >= 500 => SyncErrorCode.server,
      _ => SyncErrorCode.unknown,
    };
    return SyncError(
      code: code,
      retryable: statusCode >= 500,
      message: 'Bad state: $message',
      httpStatus: statusCode,
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
}

WebDavClient _defaultClientFactory({
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

class _WebDavFilePayload {
  _WebDavFilePayload({
    required this.jsonText,
    required this.hash,
    required this.size,
  });

  final String jsonText;
  final String hash;
  final int size;
}

class _WebDavDiff {
  _WebDavDiff({
    required this.uploads,
    required this.downloads,
    required this.conflicts,
  });

  final Set<String> uploads;
  final Set<String> downloads;
  final Set<String> conflicts;

  void applyConflictChoices(Map<String, bool> choices) {
    for (final entry in choices.entries) {
      final name = entry.key;
      final useLocal = entry.value;
      if (!conflicts.contains(name)) continue;
      if (useLocal) {
        uploads.add(name);
      } else {
        downloads.add(name);
      }
    }
    conflicts.clear();
  }
}
