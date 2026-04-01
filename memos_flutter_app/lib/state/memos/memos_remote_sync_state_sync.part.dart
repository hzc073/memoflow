part of 'memos_providers.dart';

extension _RemoteSyncStateSync on RemoteSyncController {
  String _normalizeTag(String raw) {
    return normalizeTagPath(raw);
  }

  List<String> _mergeTags(List<String> remoteTags, String content) {
    final merged = <String>{};
    for (final tag in remoteTags) {
      final normalized = _normalizeTag(tag);
      if (normalized.isNotEmpty) merged.add(normalized);
    }
    for (final tag in extractTags(content)) {
      final normalized = _normalizeTag(tag);
      if (normalized.isNotEmpty) merged.add(normalized);
    }
    final list = merged.toList(growable: false);
    list.sort();
    return list;
  }

  bool _shouldDuplicateConflictWithRemote({
    required LocalMemo localMemo,
    required Memo remoteMemo,
  }) {
    final remoteUpdateSec =
        remoteMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final localUpdateSec =
        localMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (remoteUpdateSec <= localUpdateSec) {
      return false;
    }
    return !_memoEquivalentLocalAndRemote(localMemo, remoteMemo);
  }

  bool _memoEquivalentLocalAndRemote(LocalMemo localMemo, Memo remoteMemo) {
    if (localMemo.content != remoteMemo.content) return false;
    if (localMemo.visibility != remoteMemo.visibility) return false;
    if (localMemo.pinned != remoteMemo.pinned) return false;
    if (localMemo.state != remoteMemo.state) return false;

    final localTags = List<String>.from(localMemo.tags)..sort();
    final remoteTags = _mergeTags(remoteMemo.tags, remoteMemo.content);
    if (localTags.length != remoteTags.length) return false;
    for (var i = 0; i < localTags.length; i++) {
      if (localTags[i] != remoteTags[i]) return false;
    }

    final localLocation = localMemo.location;
    final remoteLocation = remoteMemo.location;
    if (localLocation == null && remoteLocation != null) return false;
    if (localLocation != null && remoteLocation == null) return false;
    if (localLocation != null && remoteLocation != null) {
      if (localLocation.placeholder.trim() !=
          remoteLocation.placeholder.trim()) {
        return false;
      }
      if ((localLocation.latitude - remoteLocation.latitude).abs() > 1e-7) {
        return false;
      }
      if ((localLocation.longitude - remoteLocation.longitude).abs() > 1e-7) {
        return false;
      }
    }

    final localAttachments =
        localMemo.attachments.map(_attachmentSignature).toList(growable: false)
          ..sort();
    final remoteAttachments =
        remoteMemo.attachments.map(_attachmentSignature).toList(growable: false)
          ..sort();
    if (localAttachments.length != remoteAttachments.length) return false;
    for (var i = 0; i < localAttachments.length; i++) {
      if (localAttachments[i] != remoteAttachments[i]) return false;
    }
    return true;
  }

  String _attachmentSignature(Attachment attachment) {
    return [
      attachment.name.trim(),
      attachment.filename.trim(),
      attachment.type.trim(),
      attachment.size.toString(),
      attachment.externalLink.trim(),
    ].join('|');
  }

  Future<String> _duplicateConflictLocalMemo({
    required LocalMemo localMemo,
    required String? localLastError,
  }) async {
    final duplicateUid = generateUid();
    final normalizedError =
        (localLastError == null || localLastError.trim().isEmpty)
        ? null
        : localLastError.trim();
    await db.upsertMemo(
      uid: duplicateUid,
      content: localMemo.content,
      visibility: localMemo.visibility,
      pinned: localMemo.pinned,
      state: localMemo.state,
      createTimeSec:
          localMemo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec:
          localMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: localMemo.tags,
      attachments: localMemo.attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      location: localMemo.location,
      relationCount: localMemo.relationCount,
      syncState: 1,
      lastError: normalizedError,
    );
    final rewritten = await db.rewriteOutboxMemoUids(
      oldUid: localMemo.uid,
      newUid: duplicateUid,
    );
    if (rewritten <= 0) {
      final allowed = await guardMemoContentForRemoteSync(
        db: db,
        enabled: true,
        memoUid: duplicateUid,
        content: localMemo.content,
      );
      if (allowed) {
        await db.enqueueOutbox(
          type: 'create_memo',
          payload: buildCreateMemoOutboxPayload(
            uid: duplicateUid,
            content: localMemo.content,
            visibility: localMemo.visibility,
            pinned: localMemo.pinned,
            createTimeSec:
                localMemo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            hasAttachments: false,
            location: localMemo.location,
          ),
        );
      }
    }
    return duplicateUid;
  }

  Future<bool> _allowPrivateVisibilityPruneForCurrentServer() async {
    // 0.24 deployments may intermittently omit private items from list responses.
    // Keep private/protected rows locally to avoid accidental data loss.
    if (api.isRouteProfileV024) {
      return false;
    }
    return _isAuthenticatedAsCurrentUser();
  }

  Future<bool> _isAuthenticatedAsCurrentUser() async {
    final expectedName = currentUserName.trim();
    if (expectedName.isEmpty) return false;

    try {
      final user = await api.getCurrentUser();
      final actualName = user.name.trim();
      if (actualName.isEmpty) return false;
      if (actualName == expectedName) return true;

      final expectedId = RemoteSyncController._parseUserId(expectedName);
      final actualId = RemoteSyncController._parseUserId(actualName);
      if (expectedId != null && actualId != null) {
        return expectedId == actualId;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncStateMemos({
    required String runId,
    required String state,
    required bool allowPrivateVisibilityPrune,
  }) async {
    bool creatorMatchesCurrentUser(String creator) {
      final c = creator.trim();
      if (c.isEmpty) return false;
      if (c == currentUserName) return true;
      final currentId = RemoteSyncController._parseUserId(currentUserName);
      final creatorId = RemoteSyncController._parseUserId(c);
      if (currentId != null && creatorId != null) return currentId == creatorId;
      if (currentId != null && c == 'users/$currentId') return true;
      if (creatorId != null && currentUserName == 'users/$creatorId') {
        return true;
      }
      return false;
    }

    var pageToken = '';
    // 0.23 creator-scoped filters are much slower on some deployments.
    var syncPageSize = api.requiresCreatorScopedListMemos ? 600 : 1000;
    // For 0.23, cold list queries can exceed the default large-list timeout.
    // Keep this override scoped to the creator-filter route profile only.
    final syncListReceiveTimeout = api.requiresCreatorScopedListMemos
        ? const Duration(seconds: 180)
        : null;
    final creatorFilter = _creatorFilter;
    final memoParent = _memoParentName;
    final legacyCompat = api.useLegacyApi;
    final needsCreatorScopedList =
        legacyCompat || api.requiresCreatorScopedListMemos;
    final preferParentScopedList = api.isRouteProfileV024;
    var useParent =
        (legacyCompat || preferParentScopedList) &&
        memoParent != null &&
        memoParent.isNotEmpty &&
        api.supportsMemoParentQuery;
    // 0.23 requires creator-scoped list requests to include private memos.
    // Some 0.24.x deployments reject creator filters, so those versions should
    // fall back to local creator filtering.
    var usedServerFilter =
        needsCreatorScopedList && !useParent && creatorFilter != null;
    final remoteUids = <String>{};
    var completed = false;
    var pageCount = 0;
    var remoteFetchedCount = 0;
    var creatorFilteredOutCount = 0;
    var upsertedCount = 0;
    var preservedDraftCount = 0;
    var duplicateConflictCount = 0;
    final duplicateConflictSampleUids = <String>[];
    final pendingOutboxMemoUids = await db.listPendingOutboxMemoUids();
    final deletedMemoMarkerUids = await db.listMemoDeleteMarkerUids();

    LogManager.instance.info(
      'RemoteSync state: start',
      context: <String, Object?>{
        'controllerId': _controllerId,
        'runId': runId,
        'state': state,
        'allowPrivateVisibilityPrune': allowPrivateVisibilityPrune,
        'syncPageSize': syncPageSize,
        'usedServerFilter': usedServerFilter,
        'usedParentQuery': useParent,
      },
    );

    while (true) {
      if (_isDisposed) {
        _logSyncAbortDisposed(
          runId: runId,
          stage: 'sync_state_loop_before_request',
          syncState: state,
        );
        return;
      }
      try {
        final (memos, nextToken) = await api.listMemos(
          pageSize: syncPageSize,
          pageToken: pageToken.isEmpty ? null : pageToken,
          state: state,
          filter: usedServerFilter ? creatorFilter : null,
          parent: useParent ? memoParent : null,
          receiveTimeout: syncListReceiveTimeout,
        );
        if (_isDisposed) {
          _logSyncAbortDisposed(
            runId: runId,
            stage: 'sync_state_loop_after_request',
            syncState: state,
          );
          return;
        }
        pageCount++;
        remoteFetchedCount += memos.length;
        LogManager.instance.debug(
          'RemoteSync state: page_received',
          context: <String, Object?>{
            'state': state,
            'page': pageCount,
            'pageSize': syncPageSize,
            'receivedCount': memos.length,
            'hasNextToken': nextToken.isNotEmpty,
          },
        );

        for (final memo in memos) {
          if (_isDisposed) {
            _logSyncAbortDisposed(
              runId: runId,
              stage: 'sync_state_loop_each_memo',
              syncState: state,
            );
            return;
          }
          final creator = memo.creator.trim();
          if (creator.isNotEmpty && !creatorMatchesCurrentUser(creator)) {
            creatorFilteredOutCount++;
            continue;
          }
          final memoUid = memo.uid.trim();
          if (memoUid.isNotEmpty) {
            remoteUids.add(memoUid);
          }
          if (memoUid.isNotEmpty && deletedMemoMarkerUids.contains(memoUid)) {
            continue;
          }

          final local = await db.getMemoByUid(memo.uid);
          final localSync = (local?['sync_state'] as int?) ?? 0;
          final localMemo = local == null ? null : LocalMemo.fromDb(local);
          var preserveLocalDraft = localMemo != null && localSync != 0;
          var effectiveLocalSync = localSync;
          final hasPendingOutboxForMemo =
              localMemo != null &&
              pendingOutboxMemoUids.contains(localMemo.uid.trim());
          if (localMemo != null &&
              preserveLocalDraft &&
              hasPendingOutboxForMemo &&
              _shouldDuplicateConflictWithRemote(
                localMemo: localMemo,
                remoteMemo: memo,
              )) {
            final duplicateUid = await _duplicateConflictLocalMemo(
              localMemo: localMemo,
              localLastError: (local?['last_error'] as String?)?.trim(),
            );
            pendingOutboxMemoUids.remove(localMemo.uid.trim());
            pendingOutboxMemoUids.add(duplicateUid.trim());
            duplicateConflictCount++;
            if (duplicateConflictSampleUids.length < 8) {
              duplicateConflictSampleUids.add(localMemo.uid.trim());
            }
            preserveLocalDraft = false;
            effectiveLocalSync = 0;
          }
          if (preserveLocalDraft) {
            preservedDraftCount++;
          }
          final draftMemo = preserveLocalDraft ? localMemo! : null;
          final preserveLocalCreateTime =
              draftMemo == null &&
              shouldPreserveLocalCreateTime(
                localMemo: localMemo,
                localSyncState: localSync,
                remoteMemo: memo,
              );
          final tags = draftMemo != null
              ? draftMemo.tags
              : _mergeTags(memo.tags, memo.content);
          final attachments = memo.attachments
              .map((a) => a.toJson())
              .toList(growable: false);
          final mergedAttachments = draftMemo != null
              ? draftMemo.attachments
                    .map((a) => a.toJson())
                    .toList(growable: false)
              : attachments;
          final relationCount = draftMemo != null
              ? draftMemo.relationCount
              : countReferenceRelations(
                  memoUid: memo.uid,
                  relations: memo.relations,
                );
          final localLastErrorRaw = local?['last_error'];
          final localLastError = localLastErrorRaw is String
              ? localLastErrorRaw
              : null;
          final content = draftMemo != null ? draftMemo.content : memo.content;
          final visibility = draftMemo != null
              ? draftMemo.visibility
              : memo.visibility;
          final pinned = draftMemo != null ? draftMemo.pinned : memo.pinned;
          final memoState = draftMemo != null ? draftMemo.state : memo.state;
          final createTimeSec = draftMemo != null
              ? draftMemo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000
              : preserveLocalCreateTime
              ? localMemo!.createTime.toUtc().millisecondsSinceEpoch ~/ 1000
              : (memo.displayTime ?? memo.createTime)
                        .toUtc()
                        .millisecondsSinceEpoch ~/
                    1000;
          final updateTimeSec = draftMemo != null
              ? draftMemo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000
              : memo.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
          final location = draftMemo != null
              ? draftMemo.location
              : memo.location;

          await db.upsertMemo(
            uid: memo.uid,
            content: content,
            visibility: visibility,
            pinned: pinned,
            state: memoState,
            createTimeSec: createTimeSec,
            updateTimeSec: updateTimeSec,
            tags: tags,
            attachments: mergedAttachments,
            location: location,
            relationCount: relationCount,
            syncState: effectiveLocalSync == 0 ? 0 : effectiveLocalSync,
            lastError: preserveLocalDraft ? localLastError : null,
          );
          upsertedCount++;
        }

        pageToken = nextToken;
        if (pageToken.isEmpty) {
          completed = true;
          break;
        }
      } on DioException catch (e) {
        if (_isDisposed) {
          _logSyncAbortDisposed(
            runId: runId,
            stage: 'sync_state_dio_exception',
            syncState: state,
          );
          return;
        }
        if ((e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionTimeout) &&
            syncPageSize > 200) {
          final previousPageSize = syncPageSize;
          syncPageSize = syncPageSize > 600 ? 600 : (syncPageSize ~/ 2);
          if (syncPageSize < 200) {
            syncPageSize = 200;
          }
          pageToken = '';
          remoteUids.clear();
          completed = false;
          pageCount = 0;
          remoteFetchedCount = 0;
          creatorFilteredOutCount = 0;
          upsertedCount = 0;
          preservedDraftCount = 0;
          duplicateConflictCount = 0;
          duplicateConflictSampleUids.clear();
          LogManager.instance.warn(
            'RemoteSync state: reduce_page_size_after_timeout',
            context: <String, Object?>{
              'state': state,
              'previousPageSize': previousPageSize,
              'nextPageSize': syncPageSize,
            },
          );
          continue;
        }
        final status = e.response?.statusCode;
        if (useParent && (status == 400 || status == 404 || status == 405)) {
          useParent = false;
          usedServerFilter = needsCreatorScopedList && creatorFilter != null;
          pageToken = '';
          remoteUids.clear();
          completed = false;
          pageCount = 0;
          remoteFetchedCount = 0;
          creatorFilteredOutCount = 0;
          upsertedCount = 0;
          preservedDraftCount = 0;
          duplicateConflictCount = 0;
          duplicateConflictSampleUids.clear();
          LogManager.instance.warn(
            'RemoteSync state: fallback_parent_query_to_filter',
            context: <String, Object?>{'state': state, 'status': status},
          );
          continue;
        }
        if (usedServerFilter &&
            creatorFilter != null &&
            (status == 400 || status == 500)) {
          // Some deployments behave unexpectedly when client-supplied filters are present.
          // Fall back to the default ListMemos behavior and filter locally.
          usedServerFilter = false;
          pageToken = '';
          remoteUids.clear();
          completed = false;
          pageCount = 0;
          remoteFetchedCount = 0;
          creatorFilteredOutCount = 0;
          upsertedCount = 0;
          preservedDraftCount = 0;
          duplicateConflictCount = 0;
          duplicateConflictSampleUids.clear();
          LogManager.instance.warn(
            'RemoteSync state: fallback_server_filter_to_local_filter',
            context: <String, Object?>{'state': state, 'status': status},
          );
          continue;
        }
        throw _summarizeHttpError(e);
      }
    }

    if (_isDisposed) {
      _logSyncAbortDisposed(
        runId: runId,
        stage: 'sync_state_before_prune',
        syncState: state,
      );
      return;
    }
    var prunedCount = 0;
    if (completed) {
      prunedCount = await _pruneMissingMemos(
        state: state,
        remoteUids: remoteUids,
        allowPrivateVisibilityPrune: allowPrivateVisibilityPrune,
      );
    }
    LogManager.instance.info(
      'RemoteSync state: completed',
      context: <String, Object?>{
        'controllerId': _controllerId,
        'runId': runId,
        'state': state,
        'completed': completed,
        'pages': pageCount,
        'remoteFetched': remoteFetchedCount,
        'creatorFilteredOut': creatorFilteredOutCount,
        'upserted': upsertedCount,
        'preservedDraft': preservedDraftCount,
        'duplicateConflict': duplicateConflictCount,
        if (duplicateConflictSampleUids.isNotEmpty)
          'duplicateConflictSample': duplicateConflictSampleUids,
        'remoteUidCount': remoteUids.length,
        'pruned': prunedCount,
      },
    );
  }

  Future<int> _pruneMissingMemos({
    required String state,
    required Set<String> remoteUids,
    required bool allowPrivateVisibilityPrune,
  }) async {
    if (_isDisposed) return 0;
    final pendingOutbox = await db.listPendingOutboxMemoUids();
    final locals = await db.listMemoUidSyncStates(state: state);
    var deletedCount = 0;
    for (final row in locals) {
      if (_isDisposed) return deletedCount;
      final uid = row['uid'] as String?;
      if (uid == null || uid.trim().isEmpty) continue;
      if (remoteUids.contains(uid)) continue;
      if (pendingOutbox.contains(uid)) continue;
      final syncState = row['sync_state'] as int? ?? 0;
      if (syncState != 0) continue;
      final visibility = ((row['visibility'] as String?) ?? '')
          .trim()
          .toUpperCase();
      if (!allowPrivateVisibilityPrune &&
          (visibility == 'PRIVATE' || visibility == 'PROTECTED')) {
        continue;
      }
      await db.deleteMemoByUid(uid);
      deletedCount++;
    }
    return deletedCount;
  }
}
