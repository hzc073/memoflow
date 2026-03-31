part of '../webdav_backup_service.dart';

mixin _WebDavBackupManifestMixin on _WebDavBackupServiceBase {
  @override
  Map<String, dynamic> _buildBackupSettingsSnapshotPayload(
    WebDavSettings settings, {
    required String exportedAt,
  }) {
    return _wrapConfigPayload(exportedAt: exportedAt, data: settings.toJson());
  }

  @override
  Map<String, dynamic> _wrapConfigPayload({
    required String exportedAt,
    required Object? data,
  }) {
    return {'schemaVersion': 1, 'exportedAt': exportedAt, 'data': data};
  }

  @override
  Uint8List _encodeJsonBytes(Object payload) {
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  @override
  String _resolveBackupMode({required bool usesServerMode}) {
    return usesServerMode ? 'server' : 'local';
  }

  @override
  String _formatExportPathLabel(LocalLibrary library, String prefix) {
    final base = library.locationLabel.trim();
    final normalized = prefix.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return base;
    if (base.isEmpty) return normalized;
    return '$base/$normalized';
  }

  @override
  String _prefixExportPath(String prefix, String relativePath) {
    final normalizedPrefix = prefix.replaceAll('\\', '/').trim();
    final normalizedPath = relativePath.replaceAll('\\', '/').trim();
    if (normalizedPrefix.isEmpty) return normalizedPath;
    if (normalizedPath.isEmpty) return normalizedPrefix;
    return '$normalizedPrefix/$normalizedPath';
  }

  @override
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

  @override
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
    if (normalized == _backupImageCompressionSnapshotPath) {
      return WebDavBackupConfigType.imageCompressionSettings;
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
    if (normalized == _backupDraftBoxSnapshotPath) {
      return WebDavBackupConfigType.draftBox;
    }
    if (normalized == _backupTagsSnapshotPath) {
      return WebDavBackupConfigType.tags;
    }
    if (normalized == _backupSettingsSnapshotPath) {
      return WebDavBackupConfigType.webdavSettings;
    }
    return null;
  }

  @override
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
      snapshot = await _configAdapter.readSnapshot();
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
        data: snapshot.aiSettings.toWebDavJson(),
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
    if (types.contains(WebDavBackupConfigType.imageCompressionSettings) &&
        snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.imageCompressionSettings.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.imageCompressionSettings,
          path: _backupImageCompressionSnapshotPath,
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
    if (types.contains(WebDavBackupConfigType.draftBox) &&
        _configAdapter != null) {
      final drafts = await _configAdapter.readComposeDrafts();
      final bundle = ComposeDraftTransferBundle.fromDraftRecords(drafts);
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: bundle.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.draftBox,
          path: _backupDraftBoxSnapshotPath,
          bytes: _encodeJsonBytes(payload),
        ),
      );
      for (final draft in bundle.drafts) {
        for (final attachment in draft.attachments) {
          final sourcePath = attachment.sourceFilePath?.trim() ?? '';
          if (sourcePath.isEmpty) {
            throw const FormatException('Draft attachment source path missing');
          }
          final file = File(sourcePath);
          if (!await file.exists()) {
            throw FileSystemException(
              'Draft attachment file not found',
              sourcePath,
            );
          }
          files.add(
            _BackupConfigFile(
              type: WebDavBackupConfigType.draftBox,
              path: attachment.path,
              bytes: Uint8List.fromList(await file.readAsBytes()),
            ),
          );
        }
      }
    }
    if (types.contains(WebDavBackupConfigType.tags) && snapshot != null) {
      final payload = _wrapConfigPayload(
        exportedAt: exportedAt,
        data: snapshot.tagsSnapshot.toJson(),
      );
      files.add(
        _BackupConfigFile(
          type: WebDavBackupConfigType.tags,
          path: _backupTagsSnapshotPath,
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

  @override
  WebDavBackupConfigBundle _parseConfigBundle(
    Map<WebDavBackupConfigType, Uint8List> configBytes,
  ) {
    AppPreferences? preferences;
    AiSettings? aiSettings;
    ReminderSettings? reminderSettings;
    ImageBedSettings? imageBedSettings;
    ImageCompressionSettings? imageCompressionSettings;
    LocationSettings? locationSettings;
    MemoTemplateSettings? templateSettings;
    AppLockSnapshot? appLockSnapshot;
    String? noteDraft;
    ComposeDraftTransferBundle? draftBox;
    TagSnapshot? tagsSnapshot;
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

    final imageBedBytes = configBytes[WebDavBackupConfigType.imageBedSettings];
    if (imageBedBytes != null) {
      final envelope = readEnvelope(imageBedBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        imageBedSettings = safeParse(() => ImageBedSettings.fromJson(data));
      }
    }

    final imageCompressionBytes =
        configBytes[WebDavBackupConfigType.imageCompressionSettings];
    if (imageCompressionBytes != null) {
      final envelope = readEnvelope(imageCompressionBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        imageCompressionSettings = safeParse(
          () => ImageCompressionSettings.fromJson(data),
        );
      }
    }

    final locationBytes = configBytes[WebDavBackupConfigType.locationSettings];
    if (locationBytes != null) {
      final envelope = readEnvelope(locationBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        locationSettings = safeParse(() => LocationSettings.fromJson(data));
      }
    }

    final templateBytes = configBytes[WebDavBackupConfigType.templateSettings];
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

    final draftBoxBytes = configBytes[WebDavBackupConfigType.draftBox];
    if (draftBoxBytes != null) {
      final envelope = readEnvelope(draftBoxBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        draftBox = safeParse(() => ComposeDraftTransferBundle.fromJson(data));
      }
    } else if (noteDraft != null && noteDraft.trim().isNotEmpty) {
      draftBox = ComposeDraftTransferBundle.fromLegacyNoteDraft(noteDraft);
    }

    final tagsBytes = configBytes[WebDavBackupConfigType.tags];
    if (tagsBytes != null) {
      final envelope = readEnvelope(tagsBytes);
      final data = envelope == null ? null : readConfigData(envelope);
      if (data != null) {
        tagsSnapshot = safeParse(() => TagSnapshot.fromJson(data));
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
          webDavSettings = safeParse(() => WebDavSettings.fromJson(resolved));
        }
      }
    }

    return WebDavBackupConfigBundle(
      preferences: preferences,
      aiSettings: aiSettings,
      reminderSettings: reminderSettings,
      imageBedSettings: imageBedSettings,
      imageCompressionSettings: imageCompressionSettings,
      locationSettings: locationSettings,
      templateSettings: templateSettings,
      appLockSnapshot: appLockSnapshot,
      noteDraft: noteDraft,
      draftBox: draftBox,
      tagsSnapshot: tagsSnapshot,
      webDavSettings: webDavSettings,
    );
  }

  @override
  Object? _decodeJsonValue(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  @override
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

  @override
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

  @override
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
    if (bundle.imageCompressionSettings != null) {
      types.add(WebDavBackupConfigType.imageCompressionSettings);
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
    if (bundle.draftBox != null) {
      types.add(WebDavBackupConfigType.draftBox);
    }
    if (bundle.tagsSnapshot != null) {
      types.add(WebDavBackupConfigType.tags);
    }
    if (bundle.webDavSettings != null) {
      types.add(WebDavBackupConfigType.webdavSettings);
    }
    return types;
  }

  @override
  Future<void> _applyConfigBundle({
    required WebDavBackupConfigBundle bundle,
    WebDavBackupConfigDecisionHandler? decisionHandler,
    Directory? draftAttachmentRootDirectory,
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
              await _configAdapter.applyPreferences(prefs);
            }
            break;
          case WebDavBackupConfigType.aiSettings:
            final ai = bundle.aiSettings;
            if (ai != null) {
              await _configAdapter.applyAiSettings(ai);
            }
            break;
          case WebDavBackupConfigType.reminderSettings:
            final reminder = bundle.reminderSettings;
            if (reminder != null) {
              await _configAdapter.applyReminderSettings(reminder);
            }
            break;
          case WebDavBackupConfigType.imageBedSettings:
            final imageBed = bundle.imageBedSettings;
            if (imageBed != null) {
              await _configAdapter.applyImageBedSettings(imageBed);
            }
            break;
          case WebDavBackupConfigType.imageCompressionSettings:
            final settings = bundle.imageCompressionSettings;
            if (settings != null) {
              await _configAdapter.applyImageCompressionSettings(settings);
            }
            break;
          case WebDavBackupConfigType.locationSettings:
            final location = bundle.locationSettings;
            if (location != null) {
              await _configAdapter.applyLocationSettings(location);
            }
            break;
          case WebDavBackupConfigType.templateSettings:
            final template = bundle.templateSettings;
            if (template != null) {
              await _configAdapter.applyTemplateSettings(template);
            }
            break;
          case WebDavBackupConfigType.appLock:
            final lockSnapshot = bundle.appLockSnapshot;
            if (lockSnapshot != null) {
              await _configAdapter.applyAppLockSnapshot(lockSnapshot);
            }
            break;
          case WebDavBackupConfigType.noteDraft:
            final draft = bundle.noteDraft;
            if (draft != null) {
              await _configAdapter.applyNoteDraft(draft);
            }
            break;
          case WebDavBackupConfigType.draftBox:
            final draftBox = bundle.draftBox;
            if (draftBox != null) {
              final workspaceKey =
                  _configAdapter.currentWorkspaceKey ?? 'default';
              final drafts = await materializeComposeDraftTransferBundle(
                bundle: draftBox,
                rootDirectory: draftAttachmentRootDirectory,
                workspaceKey: workspaceKey,
                attachmentStager: QueuedAttachmentStager(),
              );
              final draftsToApply = draftBox.mergeWithExistingOnRestore
                  ? mergeComposeDraftRecords(
                      existing: await _configAdapter.readComposeDrafts(),
                      incoming: drafts,
                      workspaceKey: workspaceKey,
                    )
                  : drafts;
              await _configAdapter.replaceComposeDrafts(draftsToApply);
            }
            break;
          case WebDavBackupConfigType.tags:
            final snapshot = bundle.tagsSnapshot;
            if (snapshot != null) {
              await _configAdapter.applyTags(snapshot);
            }
            break;
          case WebDavBackupConfigType.webdavSettings:
            final webDavSettings = bundle.webDavSettings;
            if (webDavSettings != null) {
              await _configAdapter.applyWebDavSettings(webDavSettings);
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

  @override
  int _countMemosInSnapshot(WebDavBackupSnapshot snapshot) {
    var count = 0;
    for (final entry in snapshot.files) {
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  @override
  int _countMemosInEntries(Iterable<WebDavBackupFileEntry> entries) {
    var count = 0;
    for (final entry in entries) {
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  @override
  int _countAttachmentsInEntries(Iterable<WebDavBackupFileEntry> entries) {
    var count = 0;
    for (final entry in entries) {
      if (_isAttachmentPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  int _countDraftAttachmentsInEntries(Iterable<WebDavBackupFileEntry> entries) {
    var count = 0;
    for (final entry in entries) {
      if (_isDraftAttachmentPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  @override
  bool _snapshotHasMemos(WebDavBackupSnapshot snapshot) {
    return _countMemosInSnapshot(snapshot) > 0;
  }

  @override
  int _countMemosInPlainIndex(_PlainBackupIndex index) {
    var count = 0;
    for (final entry in index.files) {
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  @override
  int _countMemosInUploads(Iterable<_PlainBackupFileUpload> uploads) {
    var count = 0;
    for (final entry in uploads) {
      if (_isMemoPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  @override
  int _countAttachmentsInUploads(Iterable<_PlainBackupFileUpload> uploads) {
    var count = 0;
    for (final entry in uploads) {
      if (_isAttachmentPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  @override
  bool _plainIndexHasMemos(_PlainBackupIndex index) {
    return _countMemosInPlainIndex(index) > 0;
  }

  @override
  bool _isMemoPath(String rawPath) {
    final path = rawPath.trim().toLowerCase();
    return path.startsWith('memos/') &&
        (path.endsWith('.md') || path.endsWith('.md.txt'));
  }

  @override
  bool _isAttachmentPath(String rawPath) {
    final path = rawPath.trim().toLowerCase();
    return path.startsWith('attachments/');
  }

  bool _isDraftAttachmentPath(String rawPath) {
    final path = rawPath.trim().replaceAll('\\', '/').toLowerCase();
    return path.startsWith('$composeDraftTransferAttachmentsDir/');
  }

  int _countDraftsInConfigFiles(Iterable<_BackupConfigFile> files) {
    for (final file in files) {
      if (file.path != _backupDraftBoxSnapshotPath) continue;
      final decoded = _decodeJsonValue(file.bytes);
      if (decoded is! Map) return 0;
      final envelope = decoded.cast<String, dynamic>();
      final data = envelope['data'];
      if (data is Map<String, dynamic>) {
        return ComposeDraftTransferBundle.fromJson(data).draftCount;
      }
      if (data is Map) {
        return ComposeDraftTransferBundle.fromJson(
          data.cast<String, dynamic>(),
        ).draftCount;
      }
      return 0;
    }
    return 0;
  }

  @override
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
    final draftCount = _countDraftsInConfigFiles(configFiles);
    final draftAttachmentCount = _countDraftAttachmentsInEntries(files);
    final totalSize = files.fold<int>(0, (sum, entry) => sum + entry.size);
    final manifest = WebDavBackupManifest(
      schemaVersion: 1,
      exportedAt: exportedAt,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      draftCount: draftCount,
      draftAttachmentCount: draftAttachmentCount,
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  String _buildSnapshotId(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final utc = now.toUtc();
    return '${utc.year}${two(utc.month)}${two(utc.day)}_${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }
}
