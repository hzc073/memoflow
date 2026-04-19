part of 'memos_providers.dart';

Future<String> _rewriteThirdPartyShareInlineUrlsForRemoteContent({
  required RemoteSyncController controller,
  required String memoUid,
  required String content,
}) async {
  final normalizedMemoUid = memoUid.trim();
  if (normalizedMemoUid.isEmpty || content.trim().isEmpty) {
    return content;
  }

  final localUrlsInContent = extractShareInlineLocalImageUrls(content).toSet();
  if (localUrlsInContent.isEmpty) {
    return content;
  }

  final row = await controller.db.getMemoByUid(normalizedMemoUid);
  final memo = row == null ? null : LocalMemo.fromDb(row);
  final sourceMappings = await controller.db.listMemoInlineImageSources(
    normalizedMemoUid,
  );

  final replacements = <String, String>{};
  final remoteLocalUrls = <String>{};
  final sourceLocalUrls = <String>{};

  if (memo != null) {
    for (final attachment in memo.attachments) {
      final localUrl = attachment.externalLink.trim();
      if (!localUrlsInContent.contains(localUrl)) continue;
      final remoteUrl = resolveShareInlineAttachmentRemoteUrl(
        attachment,
        baseUrl: controller.serverBaseUrl,
      );
      if (remoteUrl == null || remoteUrl.trim().isEmpty) continue;
      replacements[localUrl] = remoteUrl.trim();
      remoteLocalUrls.add(localUrl);
    }
  }

  for (final entry in sourceMappings.entries) {
    final localUrl = entry.key.trim();
    final sourceUrl = entry.value.trim();
    if (!localUrlsInContent.contains(localUrl)) continue;
    if (sourceUrl.isEmpty || replacements.containsKey(localUrl)) continue;
    replacements[localUrl] = sourceUrl;
    sourceLocalUrls.add(localUrl);
  }

  final removeLocalUrls = localUrlsInContent
      .where((localUrl) => !replacements.containsKey(localUrl))
      .toSet();
  final rewritten = rewriteShareInlineImageUrlsForSyncContent(
    content,
    replacements: replacements,
    removeLocalUrls: removeLocalUrls,
  );
  final remainingLocalUrls = extractShareInlineLocalImageUrls(rewritten);

  final rewrittenToRemoteCount = remoteLocalUrls.length;
  final rewrittenToSourceCount = sourceLocalUrls
      .where((localUrl) => !remoteLocalUrls.contains(localUrl))
      .length;
  final droppedLocalInlineImageCount = removeLocalUrls.length;
  final logContext = <String, Object?>{
    'memoUid': normalizedMemoUid,
    'rewrittenToRemoteCount': rewrittenToRemoteCount,
    'rewrittenToSourceCount': rewrittenToSourceCount,
    'droppedLocalInlineImageCount': droppedLocalInlineImageCount,
    'remainingFileUrlCount': remainingLocalUrls.length,
    'hasThirdPartyShareMarker': contentHasThirdPartyShareMarker(content),
  };

  if (remainingLocalUrls.isNotEmpty) {
    LogManager.instance.warn(
      'RemoteSync outbox: inline_image_remote_rewrite_remaining_local_urls',
      context: logContext,
    );
  } else if (rewritten != content) {
    LogManager.instance.debug(
      'RemoteSync outbox: inline_image_remote_rewrite_applied',
      context: logContext,
    );
  }

  return rewritten;
}

class _OutboxProcessResult {
  const _OutboxProcessResult({
    required this.blocked,
    required this.hasQuarantined,
  });

  final bool blocked;
  final bool hasQuarantined;
}

enum _OutboxFailureDisposition { retry, quarantine }

class _OutboxFailureClassification {
  const _OutboxFailureClassification._({
    required this.disposition,
    required this.failureCode,
    required this.failureKind,
    this.retryDelay,
  });

  const _OutboxFailureClassification.retry({
    required String failureCode,
    Duration? retryDelay,
  }) : this._(
         disposition: _OutboxFailureDisposition.retry,
         failureCode: failureCode,
         failureKind: 'retryable',
         retryDelay: retryDelay,
       );

  const _OutboxFailureClassification.quarantine({
    required String failureCode,
    required String failureKind,
  }) : this._(
         disposition: _OutboxFailureDisposition.quarantine,
         failureCode: failureCode,
         failureKind: failureKind,
       );

  final _OutboxFailureDisposition disposition;
  final String failureCode;
  final String failureKind;
  final Duration? retryDelay;
}

extension _RemoteSyncOutbox on RemoteSyncController {
  Future<_OutboxProcessResult> _processOutbox() async {
    var processedCount = 0;
    var successCount = 0;
    var failedCount = 0;
    final typeCounts = <String, int>{};
    String? blockedType;
    String? blockedReason;
    while (true) {
      final headItems = await db.listOutboxPending(limit: 1);
      if (headItems.isEmpty) {
        final hasAttention = await db.countOutboxAttention() > 0;
        LogManager.instance.info(
          'RemoteSync outbox: summary',
          context: <String, Object?>{
            'processed': processedCount,
            'succeeded': successCount,
            'failed': failedCount,
            'blocked': false,
            'hasQuarantined': hasAttention,
            if (typeCounts.isNotEmpty) 'typeCounts': typeCounts,
          },
        );
        return _OutboxProcessResult(
          blocked: false,
          hasQuarantined: hasAttention,
        );
      }

      final head = headItems.first;
      final headId = head['id'] as int?;
      final headType = head['type'] as String?;
      final headState =
          (head['state'] as int?) ?? AppDatabase.outboxStatePending;
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final retryAtRaw = head['retry_at'];
      final retryAtMs = switch (retryAtRaw) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v.trim()),
        _ => null,
      };
      if (headId == null || headType == null) continue;
      if (headState == AppDatabase.outboxStateRetry &&
          retryAtMs != null &&
          retryAtMs > nowMs) {
        blockedType = headType;
        blockedReason = 'retry_waiting';
        break;
      }
      if (headState == AppDatabase.outboxStateRunning) {
        await _mutations.recoverOutboxRunningTasks();
        continue;
      }

      final row = await _mutations.claimOutboxTaskById(headId, nowMs: nowMs);
      if (row == null) continue;
      final id = row['id'] as int?;
      final type = row['type'] as String?;
      final payloadRaw = row['payload'] as String?;
      final attemptsSoFar = (row['attempts'] as int?) ?? 0;
      if (id == null || type == null || payloadRaw == null) continue;

      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(payloadRaw) as Map).cast<String, dynamic>();
      } catch (e) {
        await _mutations.markOutboxQuarantined(
          id,
          error: 'Invalid payload: $e',
          failureCode: 'invalid_payload',
          failureKind: 'fatal_immediate',
        );
        processedCount++;
        failedCount++;
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        LogManager.instance.warn(
          'RemoteSync outbox: invalid_payload',
          error: e,
          context: <String, Object?>{'id': id, 'type': type},
        );
        _maybeLogOutboxProgress(
          processedCount: processedCount,
          successCount: successCount,
          failedCount: failedCount,
          typeCounts: typeCounts,
          currentType: type,
        );
        syncQueueProgressTracker.updateCompletedTasks(
          successCount + failedCount,
        );
        continue;
      }

      processedCount++;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      final memoUid = _outboxMemoUid(type, payload);
      final shouldLogTaskDetail = _shouldLogOutboxTaskDetail(
        type: type,
        processedCount: processedCount,
      );
      if (shouldLogTaskDetail) {
        LogManager.instance.debug(
          'RemoteSync outbox: task_start',
          context: <String, Object?>{
            'id': id,
            'type': type,
            if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
          },
        );
      }

      var shouldStop = false;
      final isUploadTask = type == 'upload_attachment';
      final taskStartAt = DateTime.now();
      syncQueueProgressTracker.markTaskStarted(id);
      final suppressDeletedMemoTask =
          memoUid != null &&
          memoUid.isNotEmpty &&
          type != 'delete_memo' &&
          type != 'delete_attachment' &&
          await db.hasMemoDeleteMarker(memoUid);
      if (suppressDeletedMemoTask) {
        await _mutations.completeOutboxTask(id);
        successCount++;
        if (isUploadTask) {
          await syncQueueProgressTracker.markTaskCompleted(outboxId: id);
        }
        syncQueueProgressTracker.clearCurrentTask(outboxId: id);
        final elapsedMs = DateTime.now().difference(taskStartAt).inMilliseconds;
        LogManager.instance.info(
          'RemoteSync outbox: discard_deleted_memo_task',
          context: <String, Object?>{
            'id': id,
            'type': type,
            'memoUid': memoUid,
            'elapsedMs': elapsedMs,
          },
        );
        _maybeLogOutboxProgress(
          processedCount: processedCount,
          successCount: successCount,
          failedCount: failedCount,
          typeCounts: typeCounts,
          currentType: type,
        );
        syncQueueProgressTracker.updateCompletedTasks(
          successCount + failedCount,
        );
        continue;
      }
      try {
        switch (type) {
          case 'create_memo':
            final uid = await _handleCreateMemo(payload);
            final hasAttachments = payload['has_attachments'] as bool? ?? false;
            if (uid != null && uid.isNotEmpty) {
              final hasFollowUpOutbox =
                  hasAttachments &&
                  await db.hasPendingOutboxTaskForMemo(
                    uid,
                    types: const {'upload_attachment', 'update_memo'},
                  );
              if (!hasFollowUpOutbox) {
                await _mutations.updateMemoSyncState(uid, syncState: 0);
              }
            }
            await _mutations.completeOutboxTask(id);
            break;
          case 'update_memo':
            await _handleUpdateMemo(payload);
            final uid = payload['uid'] as String?;
            final hasPendingAttachments =
                payload['has_pending_attachments'] as bool? ?? false;
            final hasPendingAttachmentTasks =
                !hasPendingAttachments &&
                uid != null &&
                uid.isNotEmpty &&
                await db.hasPendingOutboxTaskForMemo(
                  uid,
                  types: const {'upload_attachment', 'delete_attachment'},
                );
            if (!hasPendingAttachments &&
                !hasPendingAttachmentTasks &&
                uid != null &&
                uid.isNotEmpty) {
              await _mutations.updateMemoSyncState(uid, syncState: 0);
            }
            await _mutations.completeOutboxTask(id);
            break;
          case 'delete_memo':
            await _handleDeleteMemo(payload);
            final uid = payload['uid'] as String?;
            if (uid != null && uid.trim().isNotEmpty) {
              await _mutations.deleteMemoDeleteTombstone(uid);
            }
            await _mutations.completeOutboxTask(id);
            break;
          case 'upload_attachment':
            final isFinalized = await _handleUploadAttachment(
              payload,
              currentOutboxId: id,
            );
            final memoUid = payload['memo_uid'] as String?;
            if (isFinalized && memoUid != null && memoUid.isNotEmpty) {
              await _mutations.updateMemoSyncState(memoUid, syncState: 0);
            }
            await _mutations.completeOutboxTask(id);
            break;
          case 'delete_attachment':
            await _handleDeleteAttachment(payload);
            final memoUid = payload['memo_uid'] as String?;
            if (memoUid != null && memoUid.isNotEmpty) {
              final pendingUploads = await _countPendingAttachmentUploads(
                memoUid,
              );
              if (pendingUploads <= 0) {
                await _mutations.updateMemoSyncState(memoUid, syncState: 0);
              }
            }
            await _mutations.completeOutboxTask(id);
            break;
          case 'submit_log_report':
            LogManager.instance.info(
              'RemoteSync outbox: submit_log_report_discarded',
              context: <String, Object?>{
                'id': id,
                'reason': 'feature_disabled',
              },
            );
            await _mutations.completeOutboxTask(id);
            break;
          default:
            throw StateError('Unknown op type: $type');
        }
        successCount++;
        final elapsedMs = DateTime.now().difference(taskStartAt).inMilliseconds;
        final isSlowTask =
            elapsedMs >=
            RemoteSyncController._slowOutboxTaskThreshold.inMilliseconds;
        if (shouldLogTaskDetail || isSlowTask) {
          LogManager.instance.debug(
            'RemoteSync outbox: task_done',
            context: <String, Object?>{
              'id': id,
              'type': type,
              if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
              'elapsedMs': elapsedMs,
              if (isSlowTask) 'slow': true,
            },
          );
        }
      } catch (e) {
        failedCount++;
        final elapsedMs = DateTime.now().difference(taskStartAt).inMilliseconds;
        final discardedMissingSourceUpload =
            type == 'upload_attachment' &&
            await _discardMissingSourceUploadTaskIfNeeded(
              outboxId: id,
              payload: payload,
              error: e,
              elapsedMs: elapsedMs,
            );
        if (!discardedMissingSourceUpload) {
          final memoError = e is DioException
              ? _summarizeHttpError(e)
              : SyncError(
                  code: SyncErrorCode.unknown,
                  retryable: false,
                  message: e.toString(),
                );
          final outboxError = e is DioException
              ? _detailHttpError(e)
              : e.toString();
          final classification = _classifyOutboxFailure(
            type: type,
            payload: payload,
            error: e,
            attemptsSoFar: attemptsSoFar,
          );
          final transientNetworkError =
              classification.disposition == _OutboxFailureDisposition.retry;
          if (transientNetworkError) {
            final delay =
                classification.retryDelay ??
                _retryDelayForOutboxAttempt(attemptsSoFar);
            final retryAt =
                DateTime.now().toUtc().millisecondsSinceEpoch +
                delay.inMilliseconds;
            await _mutations.markOutboxRetryScheduled(
              id,
              error: outboxError,
              retryAtMs: retryAt,
            );
            blockedReason = 'retry_scheduled';
            if (memoUid != null && memoUid.isNotEmpty) {
              await _mutations.updateMemoSyncState(memoUid, syncState: 1);
            }
          } else {
            await _mutations.markOutboxQuarantined(
              id,
              error: outboxError,
              failureCode: classification.failureCode,
              failureKind: classification.failureKind,
            );
            final failedMemoUid = switch (type) {
              'create_memo' => payload['uid'] as String?,
              'update_memo' => payload['uid'] as String?,
              'upload_attachment' => payload['memo_uid'] as String?,
              'delete_attachment' => payload['memo_uid'] as String?,
              _ => null,
            };
            if (failedMemoUid != null && failedMemoUid.isNotEmpty) {
              final memoErrorMessage = _memoSyncErrorMessageForFailure(
                failureCode: classification.failureCode,
                fallbackMessage: memoError.message?.trim(),
                rawError: outboxError,
              );
              final syncError = SyncError(
                code: SyncErrorCode.unknown,
                retryable: false,
                message: memoErrorMessage,
                presentationKey: 'legacy.msg_sync_failed',
                presentationParams: {'type': type},
                cause: memoError,
              );
              await _mutations.updateMemoSyncState(
                failedMemoUid,
                syncState: 2,
                lastError: encodeSyncError(syncError),
              );
              await _cascadeMemoQuarantine(
                rootOutboxId: id,
                memoUid: failedMemoUid,
                failureKind: classification.failureKind,
              );
            }
          }
          if (type == 'delete_memo' && memoUid != null && memoUid.isNotEmpty) {
            final currentState = await db.getMemoDeleteTombstoneState(memoUid);
            await _mutations.upsertMemoDeleteTombstone(
              memoUid: memoUid,
              state:
                  currentState ??
                  AppDatabase.memoDeleteTombstoneStatePendingRemoteDelete,
              lastError: outboxError,
            );
          }
          LogManager.instance.warn(
            'RemoteSync outbox: task_failed',
            error: e,
            context: <String, Object?>{
              'id': id,
              'type': type,
              if (memoUid != null && memoUid.isNotEmpty) 'memoUid': memoUid,
              'transientNetworkError': transientNetworkError,
              'failureCode': classification.failureCode,
              'elapsedMs': elapsedMs,
            },
          );
          if (classification.disposition == _OutboxFailureDisposition.retry) {
            blockedType = type;
            shouldStop = true;
          }
        }
      } finally {
        if (!shouldStop && isUploadTask) {
          await syncQueueProgressTracker.markTaskCompleted(outboxId: id);
        }
        syncQueueProgressTracker.clearCurrentTask(outboxId: id);
      }
      _maybeLogOutboxProgress(
        processedCount: processedCount,
        successCount: successCount,
        failedCount: failedCount,
        typeCounts: typeCounts,
        currentType: type,
      );
      syncQueueProgressTracker.updateCompletedTasks(successCount + failedCount);

      if (shouldStop) {
        blockedType = blockedType ?? type;
        break;
      }
    }
    final blockedOnType = blockedType;
    final hasAttention = await db.countOutboxAttention() > 0;
    LogManager.instance.info(
      'RemoteSync outbox: summary',
      context: <String, Object?>{
        'processed': processedCount,
        'succeeded': successCount,
        'failed': failedCount,
        'blocked': true,
        'hasQuarantined': hasAttention,
        'blockedOnType': blockedOnType,
        if (blockedReason != null) 'blockedReason': blockedReason,
        if (typeCounts.isNotEmpty) 'typeCounts': typeCounts,
      },
    );
    return _OutboxProcessResult(blocked: true, hasQuarantined: hasAttention);
  }

  Future<bool> _discardMissingSourceUploadTaskIfNeeded({
    required int outboxId,
    required Map<String, dynamic> payload,
    required Object error,
    required int elapsedMs,
  }) async {
    if (!_isMissingSourceUploadError(error)) {
      return false;
    }

    final memoUid = (payload['memo_uid'] as String? ?? '').trim();
    final attachmentUid = (payload['uid'] as String? ?? '').trim();
    final filePath = (payload['file_path'] as String? ?? '').trim();

    await _mutations.deleteOutbox(outboxId);
    if (memoUid.isNotEmpty && attachmentUid.isNotEmpty) {
      await _mutations.removePendingAttachmentPlaceholder(
        memoUid: memoUid,
        attachmentUid: attachmentUid,
      );
    }
    if (filePath.isNotEmpty) {
      final stager = QueuedAttachmentStager();
      if (stager.isManagedPath(filePath)) {
        try {
          await stager.deleteManagedFile(filePath);
        } catch (_) {}
      }
    }
    if (memoUid.isNotEmpty) {
      final hasMorePending = await db.hasPendingOutboxTaskForMemo(memoUid);
      await _mutations.updateMemoSyncState(
        memoUid,
        syncState: hasMorePending ? 1 : 0,
        lastError: null,
      );
    }
    LogManager.instance.warn(
      'RemoteSync outbox: discard_missing_source_upload',
      error: error,
      context: <String, Object?>{
        'id': outboxId,
        if (memoUid.isNotEmpty) 'memoUid': memoUid,
        if (attachmentUid.isNotEmpty) 'attachmentUid': attachmentUid,
        if (filePath.isNotEmpty) 'filePath': filePath,
        'elapsedMs': elapsedMs,
      },
    );
    return true;
  }

  bool _isMissingSourceUploadError(Object error) {
    if (error is FileSystemException) {
      return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('file not found');
  }

  Future<List<String>> _listCreateMemoAttachmentNames(String memoUid) async {
    final row = await db.getMemoByUid(memoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final names = <String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = item.cast<String, dynamic>();
        final name = (map['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final externalLink = (map['externalLink'] as String? ?? '').trim();
        if (_isAttachmentReadyForCreateMemo(
          name: name,
          externalLink: externalLink,
        )) {
          names.add(name);
        }
      }
      return names.toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  bool _isAttachmentReadyForCreateMemo({
    required String name,
    required String externalLink,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;
    final normalizedExternalLink = externalLink.trim().toLowerCase();
    if (normalizedName.startsWith('resources/')) {
      return true;
    }
    if (!normalizedName.startsWith('attachments/')) {
      return false;
    }
    if (normalizedExternalLink.isEmpty) return false;
    if (normalizedExternalLink.startsWith('file:')) return false;
    if (normalizedExternalLink.startsWith('content:')) return false;
    return true;
  }

  Future<String?> _handleCreateMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    final rawContent = payload['content'] as String?;
    final payloadVisibility = payload['visibility'] as String? ?? 'PRIVATE';
    final payloadPinned = payload['pinned'] as bool? ?? false;
    final payloadLocation = _parseLocationPayload(payload['location']);
    final payloadCreateTime = _parsePayloadTime(
      payload['create_time'] ??
          payload['createTime'] ??
          payload['display_time'] ??
          payload['displayTime'],
    );
    final payloadDisplayTime = _parsePayloadTime(
      payload['display_time'] ?? payload['displayTime'],
    );
    final payloadResolvedDisplayTime = payloadDisplayTime ?? payloadCreateTime;
    final relationsRaw = payload['relations'];
    final relations = <Map<String, dynamic>>[];
    if (relationsRaw is List) {
      for (final item in relationsRaw) {
        if (item is Map) {
          relations.add(item.cast<String, dynamic>());
        }
      }
    }
    if (uid == null || uid.isEmpty || rawContent == null) {
      throw const FormatException('create_memo missing fields');
    }
    final localRow = await db.getMemoByUid(uid);
    final localMemo = localRow == null ? null : LocalMemo.fromDb(localRow);
    final effectiveRawContent = localMemo?.content ?? rawContent;
    final effectiveVisibility = localMemo?.visibility ?? payloadVisibility;
    final effectivePinned = localMemo?.pinned ?? payloadPinned;
    final effectiveLocation = localMemo?.location ?? payloadLocation;
    final effectiveCreateTime =
        localMemo?.createTime.toUtc() ?? payloadCreateTime;
    final effectiveDisplayTime =
        localMemo?.displayTime?.toUtc() ??
        payloadResolvedDisplayTime ??
        effectiveCreateTime;
    final content = await _rewriteThirdPartyShareInlineUrlsForRemote(
      memoUid: uid,
      content: effectiveRawContent,
    );
    final normalizedRelations = normalizeReferenceRelationPayloads(
      memoUid: uid,
      relations: relations,
    );
    final attachmentNames = await _listCreateMemoAttachmentNames(uid);
    final followUpDisplayTime = resolveCreateMemoFollowUpDisplayTime(
      supportsCreateMemoTimestampsInCreateBody:
          api.supportsCreateMemoTimestampsInCreateBody,
      createTime: effectiveCreateTime,
      displayTime: effectiveDisplayTime,
    );
    final followUpCreateTime = resolveCreateMemoFollowUpCreateTime(
      supportsCreateMemoTimestampsInCreateBody:
          api.supportsCreateMemoTimestampsInCreateBody,
      supportsMemoCreateTimeUpdate: api.supportsMemoCreateTimeUpdate,
      createTime: effectiveCreateTime,
    );
    try {
      final created = await api.createMemo(
        memoId: uid,
        content: content,
        visibility: effectiveVisibility,
        pinned: effectivePinned,
        location: effectiveLocation,
        createTime: api.supportsCreateMemoTimestampsInCreateBody
            ? effectiveCreateTime
            : null,
        displayTime: api.supportsCreateMemoTimestampsInCreateBody
            ? effectiveDisplayTime
            : null,
        attachmentNames: attachmentNames,
        relations: normalizedRelations,
      );
      final remoteUid = created.uid;
      final targetUid = remoteUid.isNotEmpty ? remoteUid : uid;
      if (remoteUid.isNotEmpty && remoteUid != uid) {
        await _mutations.renameMemoUidAndRewriteOutboxMemoUids(
          oldUid: uid,
          newUid: remoteUid,
        );
      }
      if (normalizedRelations.isNotEmpty &&
          !api.supportsCreateMemoRelationsInCreateBody) {
        await _applyMemoRelations(targetUid, normalizedRelations);
      } else if (normalizedRelations.isNotEmpty) {
        _notifyRelationsSynced(targetUid, normalizedRelations);
      }
      if (followUpCreateTime != null || followUpDisplayTime != null) {
        try {
          await api.updateMemo(
            memoUid: targetUid,
            createTime: followUpCreateTime,
            displayTime: followUpDisplayTime,
          );
        } on DioException catch (e) {
          final status = e.response?.statusCode ?? 0;
          if (status != 400 && status != 404 && status != 405) {
            rethrow;
          }
        }
      }
      return targetUid;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 409) {
        if (api.supportsMemoCreateTimeUpdate &&
            (effectiveCreateTime != null || effectiveDisplayTime != null)) {
          await api.updateMemo(
            memoUid: uid,
            createTime: effectiveCreateTime,
            displayTime: effectiveDisplayTime,
          );
        } else if (followUpDisplayTime != null) {
          try {
            await api.updateMemo(
              memoUid: uid,
              displayTime: followUpDisplayTime,
            );
          } on DioException catch (e) {
            final retryStatus = e.response?.statusCode ?? 0;
            if (retryStatus != 400 &&
                retryStatus != 404 &&
                retryStatus != 405) {
              rethrow;
            }
          }
        }
        if (attachmentNames.isNotEmpty) {
          await api.setMemoAttachments(
            memoUid: uid,
            attachmentNames: attachmentNames,
          );
        }
        if (normalizedRelations.isNotEmpty) {
          await _applyMemoRelations(uid, normalizedRelations);
        }
        return uid;
      }
      rethrow;
    }
  }

  DateTime? _parsePayloadTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is int) return _epochToDateTime(raw);
    if (raw is double) return _epochToDateTime(raw.round());
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return _epochToDateTime(asInt);
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed.isUtc ? parsed : parsed.toUtc();
    }
    return null;
  }

  MemoLocation? _parseLocationPayload(dynamic raw) {
    if (raw is Map) {
      return MemoLocation.fromJson(raw.cast<String, dynamic>());
    }
    return null;
  }

  DateTime _epochToDateTime(int value) {
    final ms = value > 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> _handleUpdateMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    if (uid == null || uid.isEmpty) {
      throw const FormatException('update_memo missing uid');
    }
    final rawContent = payload['content'] as String?;
    final content = rawContent == null
        ? null
        : await _rewriteThirdPartyShareInlineUrlsForRemote(
            memoUid: uid,
            content: rawContent,
          );
    final visibility = payload['visibility'] as String?;
    final pinned = payload['pinned'] as bool?;
    final state = payload['state'] as String?;
    final hasLocation = payload.containsKey('location');
    final location = _parseLocationPayload(payload['location']);
    final syncAttachments = payload['sync_attachments'] as bool? ?? false;
    final hasPendingAttachments =
        payload['has_pending_attachments'] as bool? ?? false;
    final hasRelations = payload.containsKey('relations');
    final relationsRaw = payload['relations'];
    final relations = <Map<String, dynamic>>[];
    if (relationsRaw is List) {
      for (final item in relationsRaw) {
        if (item is Map) {
          relations.add(item.cast<String, dynamic>());
        }
      }
    }
    if (hasLocation) {
      await api.updateMemo(
        memoUid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        location: payload['location'] == null ? null : location,
      );
    } else {
      await api.updateMemo(
        memoUid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
      );
    }
    if (hasRelations) {
      await _applyMemoRelations(uid, relations);
    }
    if (syncAttachments && !hasPendingAttachments) {
      await _syncMemoAttachments(uid);
    }
  }

  Future<String> _rewriteThirdPartyShareInlineUrlsForRemote({
    required String memoUid,
    required String content,
  }) async {
    return _rewriteThirdPartyShareInlineUrlsForRemoteContent(
      controller: this,
      memoUid: memoUid,
      content: content,
    );
  }

  Future<void> _applyMemoRelations(
    String memoUid,
    List<Map<String, dynamic>> relations,
  ) async {
    final normalizedUid = _normalizeMemoUid(memoUid);
    if (normalizedUid.isEmpty) return;
    final patch = prepareReferenceRelationPatch(
      memoUid: normalizedUid,
      relations: relations,
    );
    if (!patch.shouldSync) {
      return;
    }

    await api.setMemoRelations(
      memoUid: normalizedUid,
      relations: patch.relations,
    );
    _notifyRelationsSynced(normalizedUid, patch.relations);
  }

  void _notifyRelationsSynced(
    String memoUid,
    List<Map<String, dynamic>> relations,
  ) {
    final uids = _collectRelationUids(memoUid: memoUid, relations: relations);
    if (uids.isEmpty) return;
    onRelationsSynced?.call(uids);
  }

  Set<String> _collectRelationUids({
    required String memoUid,
    required List<Map<String, dynamic>> relations,
  }) {
    final uids = <String>{};
    final normalized = _normalizeMemoUid(memoUid);
    if (normalized.isNotEmpty) {
      uids.add(normalized);
    }
    final normalizedRelations = normalizeReferenceRelationPayloads(
      memoUid: normalized,
      relations: relations,
    );
    for (final relation in normalizedRelations) {
      final relatedRaw = relation['relatedMemo'];
      final relatedName = relatedRaw is Map
          ? ((relatedRaw['name'] as String?) ?? '')
          : '';
      final relatedUid = _normalizeMemoUid(relatedName);
      if (relatedUid.isNotEmpty) {
        uids.add(relatedUid);
      }
    }
    return uids;
  }

  String _normalizeMemoUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('memos/')) {
      return trimmed.substring('memos/'.length);
    }
    return trimmed;
  }

  bool _shouldLogOutboxTaskDetail({
    required String type,
    required int processedCount,
  }) {
    if (!_isBulkOutboxTaskType(type)) {
      return true;
    }
    if (processedCount <= RemoteSyncController._bulkOutboxTaskLogHeadCount) {
      return true;
    }
    return processedCount % RemoteSyncController._bulkOutboxTaskLogEvery == 0;
  }

  bool _isBulkOutboxTaskType(String type) {
    return type == 'create_memo' || type == 'update_memo';
  }

  void _maybeLogOutboxProgress({
    required int processedCount,
    required int successCount,
    required int failedCount,
    required Map<String, int> typeCounts,
    required String currentType,
  }) {
    if (processedCount <= 0 ||
        processedCount % RemoteSyncController._outboxProgressLogEvery != 0) {
      return;
    }
    LogManager.instance.info(
      'RemoteSync outbox: progress',
      context: <String, Object?>{
        'processed': processedCount,
        'succeeded': successCount,
        'failed': failedCount,
        'currentType': currentType,
        if (typeCounts.isNotEmpty) 'typeCounts': typeCounts,
      },
    );
  }

  Duration _retryDelayForOutboxAttempt(int attemptsSoFar) {
    if (RemoteSyncController._retryBackoffSteps.isEmpty) {
      return const Duration(seconds: 5);
    }
    final normalizedAttempts = attemptsSoFar < 0 ? 0 : attemptsSoFar;
    final index =
        normalizedAttempts >= RemoteSyncController._retryBackoffSteps.length
        ? RemoteSyncController._retryBackoffSteps.length - 1
        : normalizedAttempts;
    return RemoteSyncController._retryBackoffSteps[index];
  }

  _OutboxFailureClassification _classifyOutboxFailure({
    required String type,
    required Map<String, dynamic> payload,
    required Object error,
    required int attemptsSoFar,
  }) {
    if (error is FormatException) {
      return const _OutboxFailureClassification.quarantine(
        failureCode: 'invalid_payload',
        failureKind: 'fatal_immediate',
      );
    }
    if (looksLikeRemoteMemoTooLongError(error)) {
      return const _OutboxFailureClassification.quarantine(
        failureCode: 'content_too_long',
        failureKind: 'fatal_immediate',
      );
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (_isTransientOutboxNetworkError(error) ||
          status == 429 ||
          (status != null && status >= 500)) {
        return _OutboxFailureClassification.retry(
          failureCode: status == 429 ? 'rate_limited' : 'network_retryable',
          retryDelay: _retryDelayForOutboxAttempt(attemptsSoFar),
        );
      }
      if (type == 'update_memo' && status == 404) {
        return const _OutboxFailureClassification.quarantine(
          failureCode: 'remote_missing_memo',
          failureKind: 'fatal_immediate',
        );
      }
      if (status != null && status >= 400 && status < 500) {
        return const _OutboxFailureClassification.quarantine(
          failureCode: 'http_client_fatal',
          failureKind: 'fatal_immediate',
        );
      }
    }
    if (attemptsSoFar >= 2) {
      return const _OutboxFailureClassification.quarantine(
        failureCode: 'unknown_non_retryable',
        failureKind: 'fatal_after_threshold',
      );
    }
    return _OutboxFailureClassification.retry(
      failureCode: 'unknown_retryable',
      retryDelay: _retryDelayForOutboxAttempt(attemptsSoFar),
    );
  }

  String _memoSyncErrorMessageForFailure({
    required String failureCode,
    String? fallbackMessage,
    required String rawError,
  }) {
    final fallback = (fallbackMessage ?? '').trim();
    switch (failureCode) {
      case 'content_too_long':
        return buildRemoteMemoTooLongUserMessage(
          maxChars: tryParseRemoteMemoLengthLimit(
            '$rawError${fallback.isEmpty ? '' : ' | $fallback'}',
          ),
        );
      case 'remote_missing_memo':
        return 'memo not found on remote server';
      case 'blocked_by_quarantined_memo_root':
        return 'blocked by quarantined memo root task';
      case 'invalid_payload':
        return 'invalid sync payload';
      default:
        if (fallback.isNotEmpty) {
          return fallback;
        }
        return rawError;
    }
  }

  Future<void> _cascadeMemoQuarantine({
    required int rootOutboxId,
    required String memoUid,
    required String failureKind,
  }) async {
    final normalizedUid = memoUid.trim();
    if (normalizedUid.isEmpty) return;
    final rows = await db.listOutboxByMemoUid(
      normalizedUid,
      types: const {
        'create_memo',
        'update_memo',
        'upload_attachment',
        'delete_attachment',
      },
      states: const {
        AppDatabase.outboxStatePending,
        AppDatabase.outboxStateRunning,
        AppDatabase.outboxStateRetry,
      },
    );
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null || id <= rootOutboxId) continue;
      await _mutations.markOutboxQuarantined(
        id,
        error: 'Blocked by quarantined memo root task',
        failureCode: 'blocked_by_quarantined_memo_root',
        failureKind: failureKind,
        incrementAttempts: false,
      );
    }
  }

  String? _outboxMemoUid(String type, Map<String, dynamic> payload) {
    return switch (type) {
      'create_memo' ||
      'update_memo' ||
      'delete_memo' => payload['uid'] as String?,
      'upload_attachment' ||
      'delete_attachment' => payload['memo_uid'] as String?,
      _ => null,
    };
  }

  Future<void> _handleDeleteMemo(Map<String, dynamic> payload) async {
    final uid = payload['uid'] as String?;
    final force = payload['force'] as bool? ?? false;
    if (uid == null || uid.isEmpty) {
      throw const FormatException('delete_memo missing uid');
    }
    try {
      await api.deleteMemo(memoUid: uid, force: force);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) return;
      rethrow;
    }
  }
}
