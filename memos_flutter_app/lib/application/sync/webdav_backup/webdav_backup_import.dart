part of '../webdav_backup_service.dart';

mixin _WebDavBackupImportMixin on _WebDavBackupServiceBase {
  Future<WebDavRestoreResult> restoreSnapshot({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return _withBoundDatabase(() async {
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
            final config = await _loadConfig(
              client,
              baseUrl,
              rootPath,
              accountId,
            );
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

          final entries = snapshotData.files
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
    });
  }

  Future<WebDavRestoreResult> restorePlainBackup({
    required WebDavSettings settings,
    required String? accountKey,
    required LocalLibrary? activeLocalLibrary,
    Map<String, bool>? conflictDecisions,
    WebDavBackupConfigDecisionHandler? configDecisionHandler,
  }) async {
    return _withBoundDatabase(() async {
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

          final entries = index.files
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
    });
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
          final config = await _loadConfig(
            client,
            baseUrl,
            rootPath,
            accountId,
          );
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

        _logEvent(
          'Restore completed',
          detail: 'snapshot=${snapshot.id} (export)',
        );
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

  @override
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

  @override
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

  @override
  LocalLibraryScanService? _scanServiceFor(LocalLibrary library) {
    final factory = _scanServiceFactory;
    if (factory != null) return factory(library);
    return LocalLibraryScanService(
      db: _db,
      fileSystem: LocalLibraryFileSystem(library),
      attachmentStore: _attachmentStore,
    );
  }
}
