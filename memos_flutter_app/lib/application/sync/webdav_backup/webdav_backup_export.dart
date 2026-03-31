part of '../webdav_backup_service.dart';

mixin _WebDavBackupExportMixin on _WebDavBackupServiceBase {
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
    return _withBoundDatabase(() async {
      final normalizedAccountKey = accountKey?.trim() ?? '';
      final accountId = normalizedAccountKey.isEmpty
          ? ''
          : fnv1a64Hex(normalizedAccountKey);
      final includeConfig =
          settings.backupConfigScope != WebDavBackupConfigScope.none;
      final includeMemos = settings.backupContentMemos;
      final usePlainBackup =
          settings.backupEncryptionMode == WebDavBackupEncryptionMode.plain;
      final useVault = settings.vaultEnabled && !usePlainBackup;
      final triggerLabel = manual ? 'manual' : 'auto';
      if (normalizedAccountKey.isEmpty) {
        _logEvent('Backup skipped', detail: 'account_missing ($triggerLabel)');
        return WebDavBackupSkipped(
          reason: _keyedError(
            'legacy.webdav.backup_account_missing',
            code: SyncErrorCode.invalidConfig,
          ),
        );
      }
      final backupLibrary = includeMemos
          ? await _resolveBackupLibrary(settings, activeLocalLibrary, accountId)
          : null;
      final usesMirrorLibrary = includeMemos && activeLocalLibrary == null;
      final exportLibrary = usesMirrorLibrary ? backupLibrary : null;
      LocalLibrary? snapshotLibrary = backupLibrary;
      DateTime? exportSuccessAt;
      DateTime? uploadSuccessAt;
      var plainExportCompleted = false;
      if (!settings.isBackupEnabled) {
        _logEvent(
          'Backup skipped',
          detail:
              'disabled ($triggerLabel) enabled=${settings.enabled} backupEnabled=${settings.backupEnabled} memos=${settings.backupContentMemos} config=${settings.backupConfigScope.name}',
        );
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
            _logEvent(
              'Backup skipped',
              detail: 'password_missing ($triggerLabel)',
            );
            return const WebDavBackupMissingPassword();
          }
        } else {
          resolvedPassword = await _resolvePassword(password);
          if (resolvedPassword == null || resolvedPassword.trim().isEmpty) {
            _logEvent(
              'Backup skipped',
              detail: 'password_missing ($triggerLabel)',
            );
            return const WebDavBackupMissingPassword();
          }
        }
      }

      final exportedAt = DateTime.now().toUtc().toIso8601String();
      _logEvent(
        'Backup started',
        detail:
            'mode=${usePlainBackup ? 'plain' : 'encrypted'} ($triggerLabel)',
      );
      _startProgress(WebDavBackupProgressOperation.backup);
      _updateProgress(stage: WebDavBackupProgressStage.preparing);
      await _setWakelockEnabled(true);
      try {
        if (includeMemos) {
          final exportedMemos = await _exportLocalLibraryForBackup(
            snapshotLibrary!,
            pruneToCurrentData: usesMirrorLibrary,
            attachmentBaseUrl: attachmentBaseUrl,
            attachmentAuthHeader: attachmentAuthHeader,
            issueHandler: manual ? onExportIssue : null,
          );
          if (usesMirrorLibrary) {
            exportSuccessAt = DateTime.now();
            plainExportCompleted = true;
          }
          if (exportedMemos > 0) {
            final memoFiles = await LocalLibraryFileSystem(
              snapshotLibrary,
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
              configFiles: includeConfig
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
                lastUploadSuccessAt: uploadSuccessAt.toUtc().toIso8601String(),
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

          final snapshotId = _buildSnapshotId(now);
          final configFiles = includeConfig
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

          await _waitIfPaused();
          _updateProgress(
            stage: WebDavBackupProgressStage.writingManifest,
            currentPath: '$_backupSnapshotsDir/${snapshot.id}.enc',
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
          if (exportLibrary != null && plainExportCompleted) {
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

          final previousState = await _stateRepository.read();
          await _stateRepository.write(
            previousState.copyWith(
              lastBackupAt: now.toUtc().toIso8601String(),
              lastSnapshotId: snapshot.id,
              lastExportSuccessAt:
                  exportSuccessAt?.toUtc().toIso8601String() ??
                  previousState.lastExportSuccessAt,
              lastUploadSuccessAt: uploadSuccessAt.toUtc().toIso8601String(),
            ),
          );
          if (useVault) {
            if (settings.rememberVaultPassword && vaultPassword != null) {
              await _vaultPasswordRepository.write(vaultPassword);
            }
          } else if (settings.rememberBackupPassword &&
              legacyPassword != null) {
            await _passwordRepository.write(legacyPassword);
          }

          _logEvent('Backup completed', detail: 'snapshot=${snapshot.id}');
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
        await _setWakelockEnabled(false);
        _finishProgress();
      }
    });
  }

  @override
  Future<LocalLibrary?> _resolveBackupLibrary(
    WebDavSettings settings,
    LocalLibrary? activeLocalLibrary,
    String? accountId,
  ) async {
    if (activeLocalLibrary != null) return activeLocalLibrary;
    final normalizedAccountId = accountId?.trim() ?? '';
    if (normalizedAccountId.isEmpty) return null;
    final rootPath = await resolveManagedWebDavMirrorPath(normalizedAccountId);
    return LocalLibrary(
      key: 'webdav_backup_mirror_$normalizedAccountId',
      name: 'WebDAV Backup Mirror',
      storageKind: LocalLibraryStorageKind.managedPrivate,
      rootPath: rootPath,
    );
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
        ? await _resolveBackupLibrary(settings, null, accountId)
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
        ? await _resolveBackupLibrary(
            settings,
            null,
            fnv1a64Hex(normalizedAccountKey),
          )
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

    final contentUri = attachment.externalLink.trim();
    if (contentUri.startsWith('content://')) {
      final bytes = await SafStream().readFileBytes(contentUri);
      if (bytes.isEmpty) {
        throw SyncError(
          code: SyncErrorCode.dataCorrupt,
          retryable: false,
          message: 'Attachment download failed',
        );
      }
      await fileSystem.writeFileFromChunks(
        'attachments/$memoUid/$archiveName',
        Stream<Uint8List>.value(bytes),
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

  @override
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

  @override
  String? _resolveAttachmentUrl(Uri? baseUrl, Attachment attachment) {
    final resolved = resolveAttachmentRemoteUrl(baseUrl, attachment);
    if (resolved == null || resolved.trim().isEmpty) return null;
    return resolved;
  }

  @override
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

  @override
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

  @override
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
        await _delete(
          client,
          _plainFileUri(baseUrl, rootPath, accountId, path),
        );
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
      await _ensureCollectionPath(client, baseUrl, [
        ...baseSegments,
        ..._splitPath(dir),
      ]);
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
      final bytes =
          upload.bytes ?? await _readLocalEntryBytes(fileSystem, upload.entry);
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
    final draftCount = _countDraftsInUploads(uploads);
    final draftAttachmentCount = _countDraftAttachmentsInUploads(uploads);
    final totalSize = uploads.fold<int>(0, (sum, entry) => sum + entry.size);
    final manifest = WebDavBackupManifest(
      schemaVersion: 1,
      exportedAt: exportedAt,
      memoCount: memoCount,
      attachmentCount: attachmentCount,
      draftCount: draftCount,
      draftAttachmentCount: draftAttachmentCount,
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

  @override
  String _parentDirectory(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/').trim();
    final idx = normalized.lastIndexOf('/');
    if (idx <= 0) return '';
    return normalized.substring(0, idx);
  }

  @override
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

  @override
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

  @override
  Map<String, dynamic> _buildPlainBackupIndexPayload(
    List<_PlainBackupFileUpload> uploads,
    DateTime now,
  ) {
    return {
      'schemaVersion': 1,
      'generatedAt': now.toUtc().toIso8601String(),
      'files': uploads
          .map(
            (entry) => {
              'path': entry.path,
              'size': entry.size,
              if (entry.modifiedAt != null) 'modifiedAt': entry.modifiedAt,
            },
          )
          .toList(growable: false),
    };
  }

  @override
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
        final signature = WebDavExportSignature.fromJson(
          decoded.cast<String, dynamic>(),
        );
        if (signature == null) return null;
        if (signature.accountIdHash.trim() != accountIdHash.trim()) {
          return null;
        }
        return signature;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> _writeExportSignature(
    LocalLibraryFileSystem fileSystem,
    String filename,
    WebDavExportSignature signature,
  ) async {
    await fileSystem.writeText(filename, jsonEncode(signature.toJson()));
  }

  @override
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

  @override
  DateTime _resolveExportLastSuccessAt({
    required DateTime exportAt,
    required DateTime? uploadAt,
    required bool webDavConfigured,
  }) {
    if (webDavConfigured && uploadAt != null) return uploadAt;
    return exportAt;
  }

  @override
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

  @override
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

  int _countDraftAttachmentsInUploads(
    Iterable<_PlainBackupFileUpload> uploads,
  ) {
    var count = 0;
    for (final entry in uploads) {
      if (_isDraftAttachmentPath(entry.path)) {
        count += 1;
      }
    }
    return count;
  }

  int _countDraftsInUploads(Iterable<_PlainBackupFileUpload> uploads) {
    for (final upload in uploads) {
      if (upload.path != _backupDraftBoxSnapshotPath) continue;
      final bytes = upload.bytes;
      if (bytes == null) return 0;
      final decoded = _decodeJsonValue(bytes);
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

  bool _isDraftAttachmentPath(String rawPath) {
    final path = rawPath.trim().replaceAll('\\', '/').toLowerCase();
    return path.startsWith('$composeDraftTransferAttachmentsDir/');
  }
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
          detail: LogSanitizer.redactPathLike(prevDir.path),
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
          detail: LogSanitizer.redactPathLike(stagingRoot.path),
          error: error,
        );
      }
    }
  }
}
