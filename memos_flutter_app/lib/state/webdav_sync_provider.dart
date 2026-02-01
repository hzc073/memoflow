import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_localization.dart';
import '../core/hash.dart';
import '../core/webdav_url.dart';
import '../data/models/webdav_settings.dart';
import '../data/models/webdav_sync_meta.dart';
import '../data/models/webdav_sync_state.dart';
import '../data/settings/ai_settings_repository.dart';
import '../data/settings/webdav_sync_state_repository.dart';
import '../data/webdav/webdav_client.dart';
import '../data/models/image_bed_settings.dart';
import '../data/models/location_settings.dart';
import '../data/settings/webdav_device_id_repository.dart';
import 'ai_settings_provider.dart';
import 'app_lock_provider.dart';
import 'image_bed_settings_provider.dart';
import 'location_settings_provider.dart';
import 'note_draft_provider.dart';
import 'preferences_provider.dart';
import 'reminder_settings_provider.dart';
import 'session_provider.dart';
import 'webdav_settings_provider.dart';
import 'webdav_sync_trigger_provider.dart';

const _webDavMetaFile = 'meta.json';
const _webDavPreferencesFile = 'preferences.json';
const _webDavAiFile = 'ai_settings.json';
const _webDavAppLockFile = 'app_lock.json';
const _webDavDraftFile = 'note_draft.json';
const _webDavReminderFile = 'reminder_settings.json';
const _webDavImageBedFile = 'image_bed.json';
const _webDavLocationFile = 'location_settings.json';

final webDavSyncStateRepositoryProvider = Provider<WebDavSyncStateRepository>((ref) {
  final accountKey = ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  return WebDavSyncStateRepository(ref.watch(secureStorageProvider), accountKey: accountKey);
});

final webDavSyncControllerProvider = StateNotifierProvider<WebDavSyncController, WebDavSyncStatus>((ref) {
  final accountKey = ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  return WebDavSyncController(
    ref,
    accountKey: accountKey,
    syncStateRepository: ref.watch(webDavSyncStateRepositoryProvider),
  );
});

final webDavDeviceIdRepositoryProvider = Provider<WebDavDeviceIdRepository>((ref) {
  return WebDavDeviceIdRepository(ref.watch(secureStorageProvider));
});

class WebDavSyncStatus {
  const WebDavSyncStatus({
    required this.syncing,
    required this.lastSuccessAt,
    required this.lastError,
    required this.hasPendingConflict,
  });

  final bool syncing;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final bool hasPendingConflict;

  WebDavSyncStatus copyWith({
    bool? syncing,
    DateTime? lastSuccessAt,
    String? lastError,
    bool? hasPendingConflict,
  }) {
    return WebDavSyncStatus(
      syncing: syncing ?? this.syncing,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: lastError,
      hasPendingConflict: hasPendingConflict ?? this.hasPendingConflict,
    );
  }

  static const initial = WebDavSyncStatus(
    syncing: false,
    lastSuccessAt: null,
    lastError: null,
    hasPendingConflict: false,
  );
}

class WebDavSyncController extends StateNotifier<WebDavSyncStatus> {
  WebDavSyncController(
    this._ref, {
    required String? accountKey,
    required WebDavSyncStateRepository syncStateRepository,
  })  : _accountKey = accountKey,
        _syncStateRepository = syncStateRepository,
        super(WebDavSyncStatus.initial) {
    _ref.listen<int>(webDavSyncTriggerProvider, (prev, next) {
      if (prev == next) return;
      scheduleAutoSync();
    });
  }

  final Ref _ref;
  final String? _accountKey;
  final WebDavSyncStateRepository _syncStateRepository;
  Timer? _autoTimer;
  bool _autoSyncSuppressed = false;

  static const _autoDelay = Duration(seconds: 2);

  void scheduleAutoSync() {
    if (_autoSyncSuppressed) return;
    final accountKey = _accountKey;
    if (accountKey == null || accountKey.trim().isEmpty) return;
    final settings = _ref.read(webDavSettingsProvider);
    if (!_canSync(settings)) return;
    _autoTimer?.cancel();
    _autoTimer = Timer(_autoDelay, () {
      unawaited(syncNow());
    });
  }

  Future<void> syncNow({BuildContext? context}) async {
    if (state.syncing) return;
    final settings = _ref.read(webDavSettingsProvider);
    final accountKey = _accountKey;
    if (!_canSync(settings) || accountKey == null || accountKey.trim().isEmpty) {
      state = state.copyWith(
        lastError: _ref.read(appPreferencesProvider).language == AppLanguage.en
            ? 'WebDAV is not configured'
            : 'WebDAV 未配置',
      );
      return;
    }

    state = state.copyWith(syncing: true, lastError: null, hasPendingConflict: false);
    try {
      final baseUrl = Uri.tryParse(settings.serverUrl.trim());
      if (baseUrl == null || !baseUrl.hasScheme || !baseUrl.hasAuthority) {
        throw StateError(trByLanguage(
          language: _ref.read(appPreferencesProvider).language,
          zh: 'WebDAV 服务器地址无效',
          en: 'Invalid WebDAV server URL',
        ));
      }

      final accountId = fnv1a64Hex(accountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = WebDavClient(
        baseUrl: baseUrl,
        username: settings.username,
        password: settings.password,
        authMode: settings.authMode,
        ignoreBadCert: settings.ignoreTlsErrors,
      );
      try {
        await _ensureCollections(client, baseUrl, rootPath, accountId);
        final lastSync = await _syncStateRepository.read();
        final localPayloads = await _buildLocalPayloads(lastSync);
        final remoteMeta = await _fetchRemoteMeta(client, baseUrl, rootPath, accountId);

        final diff = _diffFiles(localPayloads, remoteMeta, lastSync);
        if (context != null && !context.mounted) return;
        if (diff.conflicts.isNotEmpty) {
          if (context == null) {
            state = state.copyWith(
              syncing: false,
              hasPendingConflict: true,
              lastError: trByLanguage(
                language: _ref.read(appPreferencesProvider).language,
                zh: '存在冲突，需要手动同步',
                en: 'Conflicts detected. Run manual sync.',
              ),
            );
            return;
          }
          final resolved = await _resolveConflicts(context, diff.conflicts);
          if (resolved == null) {
            state = state.copyWith(syncing: false);
            return;
          }
          diff.applyConflictChoices(resolved);
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
        await _writeRemoteMeta(client, baseUrl, rootPath, accountId, mergedMeta);
        await _syncStateRepository.write(
          WebDavSyncState(
            lastSyncAt: now,
            files: mergedMeta.files,
          ),
        );
        state = state.copyWith(syncing: false, lastSuccessAt: DateTime.now(), lastError: null);
      } finally {
        await client.close();
      }
    } catch (e) {
      state = state.copyWith(syncing: false, lastError: e.toString(), hasPendingConflict: false);
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  bool _canSync(WebDavSettings settings) {
    if (!settings.enabled) return false;
    if (settings.serverUrl.trim().isEmpty) return false;
    if (settings.username.trim().isEmpty && settings.password.trim().isNotEmpty) return false;
    if (settings.username.trim().isNotEmpty && settings.password.trim().isEmpty) return false;
    return true;
  }

  Future<void> _ensureCollections(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final segments = <String>[
      ..._splitPath(rootPath),
      'accounts',
      accountId,
    ];
    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      final uri = joinWebDavUri(baseUrl: baseUrl, rootPath: '', relativePath: current);
      final res = await client.mkcol(uri);
      if (res.statusCode == 201 || res.statusCode == 405 || res.statusCode == 200) {
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
    return trimmed.split('/').where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  Future<String> _resolveDeviceId() async {
    final repo = _ref.read(webDavDeviceIdRepositoryProvider);
    return repo.readOrCreate();
  }

  Future<Map<String, _WebDavFilePayload>> _buildLocalPayloads(WebDavSyncState lastSync) async {
    final prefs = _ref.read(appPreferencesProvider);
    final ai = _ref.read(aiSettingsProvider);
    final reminder = _ref.read(reminderSettingsProvider);
    final imageBed = _ref.read(imageBedSettingsProvider);
    final locationSettings = _ref.read(locationSettingsProvider);
    final lockRepo = _ref.read(appLockRepositoryProvider);
    final lockSnapshot = await lockRepo.readSnapshot();
    final draftValue = _ref.read(noteDraftProvider).valueOrNull ?? '';

    final payloads = <String, _WebDavFilePayload>{
      _webDavPreferencesFile: _payloadFromJson(_preferencesForSync(prefs)),
      _webDavAiFile: _payloadFromJson(ai.toJson()),
      _webDavReminderFile: _payloadFromJson(reminder.toJson()),
      _webDavImageBedFile: _payloadFromJson(imageBed.toJson()),
      _webDavLocationFile: _payloadFromJson(locationSettings.toJson()),
      _webDavAppLockFile: _payloadFromJson(lockSnapshot.toJson()),
      _webDavDraftFile: _payloadFromJson({'text': draftValue}),
    };

    return payloads;
  }

  Map<String, dynamic> _preferencesForSync(AppPreferences prefs) {
    final json = Map<String, dynamic>.from(prefs.toJson());
    json.remove('lastSeenAppVersion');
    json.remove('lastSeenAnnouncementVersion');
    json.remove('lastSeenAnnouncementId');
    json.remove('lastSeenNoticeHash');
    json.remove('fontFile');
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
      throw StateError('WebDAV meta fetch failed (HTTP ${res.statusCode})');
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
      throw StateError('WebDAV meta update failed (HTTP ${res.statusCode})');
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
      final localChanged = lastHash == null ? localHash.isNotEmpty : localHash != lastHash;
      final remoteChanged = lastHash == null ? remoteHash != null : remoteHash != lastHash;
      if (remoteHash == null && localChanged) {
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
        throw StateError('WebDAV download failed (HTTP ${res.statusCode})');
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
        throw StateError('WebDAV upload failed (HTTP ${res.statusCode})');
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

    _autoSyncSuppressed = true;
    try {
      switch (name) {
        case _webDavPreferencesFile:
          final remote = AppPreferences.fromJson(json);
          final current = _ref.read(appPreferencesProvider);
          final merged = _mergePreferences(current, remote);
          await _ref.read(appPreferencesProvider.notifier).setAll(merged, triggerSync: false);
          break;
        case _webDavAiFile:
          final settings = AiSettings.fromJson(json);
          await _ref.read(aiSettingsProvider.notifier).setAll(settings, triggerSync: false);
          break;
        case _webDavReminderFile:
          final current = _ref.read(reminderSettingsProvider);
          final fallback = current;
          final settings = ReminderSettings.fromJson(json, fallback: fallback);
          await _ref.read(reminderSettingsProvider.notifier).setAll(settings, triggerSync: false);
          break;
        case _webDavImageBedFile:
          final settings = ImageBedSettings.fromJson(json);
          await _ref.read(imageBedSettingsProvider.notifier).setAll(settings, triggerSync: false);
          break;
        case _webDavLocationFile:
          final settings = LocationSettings.fromJson(json);
          await _ref.read(locationSettingsProvider.notifier).setAll(settings, triggerSync: false);
          break;
        case _webDavAppLockFile:
          final snapshot = AppLockSnapshot.fromJson(json);
          await _ref.read(appLockProvider.notifier).setSnapshot(snapshot, triggerSync: false);
          break;
        case _webDavDraftFile:
          final text = (json['text'] as String?) ?? '';
          await _ref.read(noteDraftProvider.notifier).setDraft(text, triggerSync: false);
          break;
      }
    } finally {
      _autoSyncSuppressed = false;
    }
  }

  AppPreferences _mergePreferences(AppPreferences current, AppPreferences remote) {
    return current.copyWith(
      language: remote.language,
      hasSelectedLanguage: remote.hasSelectedLanguage,
      fontSize: remote.fontSize,
      lineHeight: remote.lineHeight,
      fontFamily: remote.fontFamily,
      collapseLongContent: remote.collapseLongContent,
      collapseReferences: remote.collapseReferences,
      launchAction: remote.launchAction,
      hapticsEnabled: remote.hapticsEnabled,
      useLegacyApi: remote.useLegacyApi,
      networkLoggingEnabled: remote.networkLoggingEnabled,
      themeMode: remote.themeMode,
      themeColor: remote.themeColor,
      customTheme: remote.customTheme,
      accountThemeColors: remote.accountThemeColors,
      accountCustomThemes: remote.accountCustomThemes,
      showDrawerExplore: remote.showDrawerExplore,
      showDrawerDailyReview: remote.showDrawerDailyReview,
      showDrawerAiSummary: remote.showDrawerAiSummary,
      showDrawerResources: remote.showDrawerResources,
      aiSummaryAllowPrivateMemos: remote.aiSummaryAllowPrivateMemos,
      supporterCrownEnabled: remote.supporterCrownEnabled,
      thirdPartyShareEnabled: remote.thirdPartyShareEnabled,
      lastSeenAppVersion: current.lastSeenAppVersion,
      lastSeenAnnouncementVersion: current.lastSeenAnnouncementVersion,
      lastSeenAnnouncementId: current.lastSeenAnnouncementId,
    );
  }

  Uri _fileUri(Uri baseUrl, String rootPath, String accountId, String name) {
    final relative = 'accounts/$accountId/$name';
    return joinWebDavUri(baseUrl: baseUrl, rootPath: rootPath, relativePath: relative);
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

  Future<Map<String, bool>?> _resolveConflicts(BuildContext context, Set<String> conflicts) async {
    return showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => _WebDavConflictDialog(conflicts: conflicts.toList(growable: false)),
    );
  }
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

class _WebDavConflictDialog extends StatefulWidget {
  const _WebDavConflictDialog({required this.conflicts});

  final List<String> conflicts;

  @override
  State<_WebDavConflictDialog> createState() => _WebDavConflictDialogState();
}

class _WebDavConflictDialogState extends State<_WebDavConflictDialog> {
  final Map<String, bool> _choices = {};
  bool _applyToAll = false;
  bool _useLocalForAll = true;

  @override
  void initState() {
    super.initState();
    for (final name in widget.conflicts) {
      _choices[name] = true;
    }
  }

  void _toggleApplyAll(bool? value) {
    setState(() {
      _applyToAll = value ?? false;
      if (_applyToAll) {
        for (final name in widget.conflicts) {
          _choices[name] = _useLocalForAll;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = context.appLanguage;
    return AlertDialog(
      title: Text(trByLanguage(language: language, zh: '同步冲突', en: 'Sync conflicts')),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trByLanguage(
                  language: language,
                  zh: '以下设置在本地和远端都有修改，请选择保留哪个版本。',
                  en: 'These settings changed locally and remotely. Choose which version to keep.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _applyToAll,
                onChanged: _toggleApplyAll,
                title: Text(trByLanguage(language: language, zh: '应用到全部', en: 'Apply to all')),
              ),
              if (_applyToAll)
                RadioGroup<bool>(
                  groupValue: _useLocalForAll,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _useLocalForAll = value;
                      for (final name in widget.conflicts) {
                        _choices[name] = value;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          title: Text(trByLanguage(language: language, zh: '使用本地', en: 'Use local')),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: false,
                          title: Text(trByLanguage(language: language, zh: '使用远端', en: 'Use remote')),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_applyToAll)
                ...widget.conflicts.map(
                  (name) => RadioGroup<bool>(
                    groupValue: _choices[name],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _choices[name] = value);
                    },
                    child: Column(
                      children: [
                        const Divider(height: 12),
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          title: Text(trByLanguage(language: language, zh: '使用本地', en: 'Use local')),
                        ),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: false,
                          title: Text(trByLanguage(language: language, zh: '使用远端', en: 'Use remote')),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(trByLanguage(language: language, zh: '取消', en: 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_choices),
          child: Text(trByLanguage(language: language, zh: '确定', en: 'Apply')),
        ),
      ],
    );
  }
}
