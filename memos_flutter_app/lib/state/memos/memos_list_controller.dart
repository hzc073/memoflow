part of 'memos_list_providers.dart';

class MemosListController {
  MemosListController(this._ref);

  final Ref _ref;

  Future<void> logEmptyViewDiagnostics({
    required String queryKey,
    required String state,
    required int providerCount,
    required int animatedCount,
    required String searchQuery,
    required String? resolvedTag,
    required bool useShortcutFilter,
    required bool useQuickSearch,
    required bool useRemoteSearch,
    required int? startTimeSec,
    required int? endTimeSecExclusive,
    required String shortcutFilter,
    required QuickSearchKind? quickSearchKind,
  }) async {
    try {
      final db = _ref.read(databaseProvider);
      final sqlite = await db.db;
      int readCountValue(Object? raw) {
        return switch (raw) {
          int value => value,
          num value => value.toInt(),
          String value => int.tryParse(value.trim()) ?? 0,
          _ => 0,
        };
      }

      final countRows = await sqlite.rawQuery('''
        SELECT
          COUNT(*) AS total_count,
          SUM(CASE WHEN UPPER(COALESCE(state, 'NORMAL')) = 'ARCHIVED' THEN 1 ELSE 0 END) AS archived_count,
          SUM(CASE WHEN UPPER(COALESCE(state, 'NORMAL')) = 'ARCHIVED' THEN 0 ELSE 1 END) AS normal_count
        FROM memos
      ''');
      final countRow = countRows.isEmpty
          ? const <String, Object?>{}
          : countRows.first;
      final dbTotal = readCountValue(countRow['total_count']);
      final dbNormal = readCountValue(countRow['normal_count']);
      final dbArchived = readCountValue(countRow['archived_count']);
      final tag = resolvedTag?.trim();
      final normalizedSearch = searchQuery.trim();
      final normalizedShortcutFilter = shortcutFilter.trim();
      final previewRows = await db.listMemos(
        searchQuery: normalizedSearch.isEmpty ? null : normalizedSearch,
        state: state,
        tag: (tag == null || tag.isEmpty) ? null : tag,
        startTimeSec: startTimeSec,
        endTimeSecExclusive: endTimeSecExclusive,
        limit: 5,
      );
      final previewUids = previewRows
          .map((row) => row['uid'])
          .whereType<String>()
          .map((uid) => LogSanitizer.redactOpaque(uid, kind: 'memo_uid'))
          .toList(growable: false);
      _ref
          .read(logManagerProvider)
          .info(
            'Memos list: empty_view_diagnostic',
            context: <String, Object?>{
              'queryKeyFingerprint': LogSanitizer.redactOpaque(
                queryKey,
                kind: 'memos_query_key',
              ),
              'state': state,
              'providerCount': providerCount,
              'animatedCount': animatedCount,
              'searchLength': normalizedSearch.length,
              if (normalizedSearch.isNotEmpty)
                'searchQueryFingerprint': LogSanitizer.redactSemanticText(
                  normalizedSearch,
                  kind: 'search_query',
                ),
              if (tag != null && tag.isNotEmpty) ...<String, Object?>{
                'tagFingerprint': LogSanitizer.redactSemanticText(
                  tag,
                  kind: 'tag',
                ),
                'tagLength': tag.length,
              },
              'useShortcutFilter': useShortcutFilter,
              if (normalizedShortcutFilter.isNotEmpty) ...<String, Object?>{
                'shortcutFilterFingerprint': LogSanitizer.redactSemanticText(
                  normalizedShortcutFilter,
                  kind: 'shortcut_filter',
                ),
                'shortcutFilterLength': normalizedShortcutFilter.length,
              },
              'useQuickSearch': useQuickSearch,
              if (quickSearchKind != null)
                'quickSearchKind': quickSearchKind.name,
              'useRemoteSearch': useRemoteSearch,
              if (startTimeSec != null) 'startTimeSec': startTimeSec,
              if (endTimeSecExclusive != null)
                'endTimeSecExclusive': endTimeSecExclusive,
              'dbTotal': dbTotal,
              'dbNormal': dbNormal,
              'dbArchived': dbArchived,
              'dbPreviewCount': previewRows.length,
              if (previewUids.isNotEmpty) 'dbPreviewUids': previewUids,
            },
          );
    } catch (e, stackTrace) {
      _ref
          .read(logManagerProvider)
          .warn(
            'Memos list: empty_view_diagnostic_failed',
            error: e,
            stackTrace: stackTrace,
            context: <String, Object?>{
              'queryKeyFingerprint': LogSanitizer.redactOpaque(
                queryKey,
                kind: 'memos_query_key',
              ),
            },
          );
    }
  }

  Future<void> createQuickInputMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
  }) async {
    final db = _ref.read(databaseProvider);
    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: nowSec,
      updateTimeSec: nowSec,
      tags: tags,
      attachments: const <Map<String, dynamic>>[],
      location: null,
      relationCount: 0,
      syncState: 1,
    );

    await db.enqueueOutbox(
      type: 'create_memo',
      payload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        createTimeSec: nowSec,
        hasAttachments: false,
      ),
    );
  }

  Future<int> retryOutboxErrors({required String memoUid}) async {
    final db = _ref.read(databaseProvider);
    return db.retryOutboxErrors(memoUid: memoUid);
  }

  Future<void> createInlineComposeMemo({
    required String uid,
    required String content,
    required String visibility,
    required int nowSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    required List<Map<String, dynamic>> relations,
    required List<MemoComposerPendingAttachment> pendingAttachments,
  }) async {
    final db = _ref.read(databaseProvider);
    final attachmentPayloads = pendingAttachments
        .map(
          (attachment) => <String, dynamic>{
            'uid': attachment.uid,
            'memo_uid': uid,
            'file_path': attachment.filePath,
            'filename': attachment.filename,
            'mime_type': attachment.mimeType,
            'file_size': attachment.size,
          },
        )
        .toList(growable: false);
    final localAttachments = mergePendingAttachmentPlaceholders(
      attachments: attachments,
      pendingAttachments: attachmentPayloads,
    );

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: nowSec,
      updateTimeSec: nowSec,
      tags: tags,
      attachments: localAttachments,
      location: location,
      relationCount: 0,
      syncState: 1,
    );

    final hasAttachments = pendingAttachments.isNotEmpty;
    await enqueueCreateMemoWithAttachmentUploads(
      read: _ref.read,
      db: db,
      createPayload: buildCreateMemoOutboxPayload(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: false,
        createTimeSec: nowSec,
        hasAttachments: hasAttachments,
        location: location,
        relations: relations,
      ),
      attachmentPayloads: attachmentPayloads,
    );
  }

  Future<void> updateMemo(LocalMemo memo, {bool? pinned, String? state}) async {
    final now = DateTime.now();
    final db = _ref.read(databaseProvider);

    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: pinned ?? memo.pinned,
      state: state ?? memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: memo.attachments
          .map((a) => a.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        if (pinned != null) 'pinned': pinned,
        if (state != null) 'state': state,
      },
    );
  }

  Future<void> updateMemoContent(
    LocalMemo memo,
    String content, {
    bool preserveUpdateTime = false,
  }) async {
    if (content == memo.content) return;
    final updateTime = preserveUpdateTime ? memo.updateTime : DateTime.now();
    final db = _ref.read(databaseProvider);
    final timelineService = _ref.read(memoTimelineServiceProvider);
    final tags = extractTags(content);

    await timelineService.captureMemoVersion(memo);

    await db.upsertMemo(
      uid: memo.uid,
      content: content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: memo.attachments
          .map((a) => a.toJson())
          .toList(growable: false),
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(
      type: 'update_memo',
      payload: {
        'uid': memo.uid,
        'content': content,
        'visibility': memo.visibility,
      },
    );
  }

  Future<void> deleteMemo(
    LocalMemo memo, {
    void Function()? onMovedToRecycleBin,
  }) async {
    await _ref
        .read(memoDeleteServiceProvider)
        .deleteMemo(memo, onMovedToRecycleBin: onMovedToRecycleBin);
  }

  Future<bool> hasAnyLocalMemos() async {
    final db = _ref.read(databaseProvider);
    final existing = await db.listMemos(limit: 1);
    return existing.isNotEmpty;
  }

  Future<MemosListMemoResolveResult> resolveMemoForOpen({
    required String uid,
  }) async {
    final db = _ref.read(databaseProvider);
    if (await db.hasMemoDeleteMarker(uid)) {
      return const MemosListMemoResolveResult.notFound();
    }
    final row = await db.getMemoByUid(uid);
    LocalMemo? memo = row == null ? null : LocalMemo.fromDb(row);

    if (memo == null) {
      final account = _ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account != null) {
        try {
          final api = _ref.read(memosApiProvider);
          final remote = await api.getMemo(memoUid: uid);
          final remoteUid = remote.uid.isNotEmpty ? remote.uid : uid;
          await db.upsertMemo(
            uid: remoteUid,
            content: remote.content,
            visibility: remote.visibility,
            pinned: remote.pinned,
            state: remote.state,
            createTimeSec:
                remote.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            updateTimeSec:
                remote.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
            tags: remote.tags,
            attachments: remote.attachments
                .map((a) => a.toJson())
                .toList(growable: false),
            location: remote.location,
            relationCount: countReferenceRelations(
              memoUid: remoteUid,
              relations: remote.relations,
            ),
            syncState: 0,
          );
          final refreshed = await db.getMemoByUid(remoteUid);
          if (refreshed != null) {
            memo = LocalMemo.fromDb(refreshed);
          }
        } catch (e) {
          return MemosListMemoResolveResult.error(e);
        }
      }
    }

    if (memo == null) {
      return const MemosListMemoResolveResult.notFound();
    }
    return MemosListMemoResolveResult.found(memo);
  }

  Future<Shortcut> createShortcut({
    required String title,
    required String filter,
  }) async {
    final account = _ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      throw StateError('Not authenticated');
    }
    final api = _ref.read(memosApiProvider);
    await api.ensureServerHintsLoaded();
    final useLocalShortcuts =
        api.usesLegacySearchFilterDialect ||
        api.shortcutsSupportedHint == false;
    return useLocalShortcuts
        ? await _ref
              .read(localShortcutsRepositoryProvider)
              .create(title: title, filter: filter)
        : await api.createShortcut(
            userName: account.user.name,
            title: title,
            filter: filter,
          );
  }
}
