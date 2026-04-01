part of 'memos_providers.dart';

extension _RemoteSyncAttachments on RemoteSyncController {
  Future<bool> _shouldBindAttachmentDuringCreateMemo(String memoUid) async {
    final normalizedMemoUid = memoUid.trim();
    if (normalizedMemoUid.isEmpty) return false;
    if (!api.supportsCreateMemoAttachmentsInCreateBody) return false;

    final rows = await db.listOutboxPendingByType('create_memo');
    for (final row in rows) {
      final payloadRaw = row['payload'];
      if (payloadRaw is! String) continue;
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is! Map) continue;
        final payload = decoded.cast<String, dynamic>();
        final queuedUid = (payload['uid'] as String? ?? '').trim();
        if (queuedUid == normalizedMemoUid) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> _handleUploadAttachment(
    Map<String, dynamic> payload, {
    required int currentOutboxId,
  }) async {
    final uid = payload['uid'] as String?;
    final memoUid = payload['memo_uid'] as String?;
    final filePath = payload['file_path'] as String?;
    final filename = payload['filename'] as String?;
    final mimeType =
        payload['mime_type'] as String? ?? 'application/octet-stream';
    final skipCompression = switch (payload['skip_compression']) {
      final bool value => value,
      final num value => value != 0,
      final String value => value.trim().toLowerCase() == 'true',
      _ => false,
    };
    final shareInlineImage = switch (payload['share_inline_image']) {
      final bool value => value,
      final num value => value != 0,
      final String value => value.trim().toLowerCase() == 'true',
      _ => false,
    };
    final fromThirdPartyShare = switch (payload['from_third_party_share']) {
      final bool value => value,
      final num value => value != 0,
      final String value => value.trim().toLowerCase() == 'true',
      _ => false,
    };
    final shareInlineLocalUrl =
        (payload['share_inline_local_url'] as String? ?? '').trim();
    if (uid == null ||
        uid.isEmpty ||
        memoUid == null ||
        memoUid.isEmpty ||
        filePath == null ||
        filename == null) {
      throw const FormatException('upload_attachment missing fields');
    }

    final processed = await attachmentPreprocessor.preprocess(
      AttachmentPreprocessRequest(
        filePath: filePath,
        filename: filename,
        mimeType: mimeType,
        skipCompression: skipCompression,
      ),
    );
    final processedFile = File(processed.filePath);
    if (!processedFile.existsSync()) {
      throw FileSystemException('File not found', processed.filePath);
    }
    final bytes = await processedFile.readAsBytes();

    final processedExternalLink = processed.filePath.startsWith('content://')
        ? processed.filePath
        : Uri.file(processed.filePath).toString();
    await _updateLocalAttachmentMeta(
      memoUid: memoUid,
      localAttachmentUid: uid,
      filename: processed.filename,
      mimeType: processed.mimeType,
      size: processed.size,
      width: processed.width,
      height: processed.height,
      hash: processed.hash,
      externalLink: processedExternalLink,
    );

    if (_isImageMimeType(processed.mimeType)) {
      final settings = await imageBedRepository.read();
      if (settings.enabled) {
        final url = await _uploadImageToImageBed(
          settings: settings,
          bytes: bytes,
          filename: processed.filename,
        );
        if (shareInlineImage && shareInlineLocalUrl.isNotEmpty) {
          await _replaceShareInlineMemoContent(
            memoUid: memoUid,
            localUrl: shareInlineLocalUrl,
            remoteUrl: url,
            removeAttachmentUid: uid,
            enqueueUpdate: true,
          );
        } else {
          await _appendImageBedLink(
            memoUid: memoUid,
            localAttachmentUid: uid,
            imageUrl: url,
          );
        }
        await _deleteManagedUploadSourceIfUnused(filePath);
        return false;
      }
    }

    final preserveLocalInlineReference =
        shareInlineImage &&
        fromThirdPartyShare &&
        shareInlineLocalUrl.isNotEmpty;
    final bindAttachmentDuringCreateMemo =
        await _shouldBindAttachmentDuringCreateMemo(memoUid);

    if (api.usesLegacyMemos) {
      final created = await _createAttachmentWith409Recovery(
        attachmentId: uid,
        filename: processed.filename,
        mimeType: processed.mimeType,
        bytes: bytes,
        memoUid: null,
        onSendProgress: (sentBytes, totalBytes) {
          syncQueueProgressTracker.updateCurrentTaskProgress(
            outboxId: currentOutboxId,
            sentBytes: sentBytes,
            totalBytes: totalBytes,
          );
        },
      );

      await _updateLocalMemoAttachment(
        memoUid: memoUid,
        localAttachmentUid: uid,
        filename: processed.filename,
        remote: _resolveAttachmentWithFallbackLink(created),
        preserveExternalLink: preserveLocalInlineReference,
      );

      final remoteUrl = _resolveAttachmentExternalLink(created);
      if (shareInlineImage && !preserveLocalInlineReference) {
        if (remoteUrl.isEmpty) {
          throw StateError('Uploaded inline image missing externalLink');
        }
        await _replaceShareInlineMemoContent(
          memoUid: memoUid,
          localUrl: shareInlineLocalUrl,
          remoteUrl: remoteUrl,
        );
      }

      final shouldFinalize = await _isLastPendingAttachmentUpload(memoUid);
      if (!shouldFinalize) {
        return false;
      }

      await _syncMemoAttachments(memoUid);
      if (shareInlineImage && !preserveLocalInlineReference) {
        await _syncCurrentLocalMemoContent(memoUid);
      }
      if (!preserveLocalInlineReference) {
        await _deleteManagedUploadSourceIfUnused(filePath);
      }
      return true;
    }

    var supportsSetAttachments = !bindAttachmentDuringCreateMemo;
    if (!bindAttachmentDuringCreateMemo) {
      try {
        await api.listMemoAttachments(memoUid: memoUid);
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        if (status == 404 || status == 405) {
          supportsSetAttachments = false;
        } else {
          rethrow;
        }
      }
    }

    final created = await _createAttachmentWith409Recovery(
      attachmentId: uid,
      filename: processed.filename,
      mimeType: processed.mimeType,
      bytes: bytes,
      memoUid: bindAttachmentDuringCreateMemo
          ? null
          : (supportsSetAttachments ? null : memoUid),
      onSendProgress: (sentBytes, totalBytes) {
        syncQueueProgressTracker.updateCurrentTaskProgress(
          outboxId: currentOutboxId,
          sentBytes: sentBytes,
          totalBytes: totalBytes,
        );
      },
    );

    await _updateLocalMemoAttachment(
      memoUid: memoUid,
      localAttachmentUid: uid,
      filename: filename,
      remote: _resolveAttachmentWithFallbackLink(created),
      preserveExternalLink: preserveLocalInlineReference,
    );

    final remoteUrl = _resolveAttachmentExternalLink(created);
    if (shareInlineImage && !preserveLocalInlineReference) {
      if (remoteUrl.isEmpty) {
        throw StateError('Uploaded inline image missing externalLink');
      }
      await _replaceShareInlineMemoContent(
        memoUid: memoUid,
        localUrl: shareInlineLocalUrl,
        remoteUrl: remoteUrl,
      );
    }

    final shouldFinalize = await _isLastPendingAttachmentUpload(memoUid);
    if (!shouldFinalize) {
      return false;
    }
    if (bindAttachmentDuringCreateMemo) {
      return false;
    }

    if (supportsSetAttachments && !bindAttachmentDuringCreateMemo) {
      await _syncMemoAttachments(memoUid);
    }
    if (shareInlineImage && !preserveLocalInlineReference) {
      await _syncCurrentLocalMemoContent(memoUid);
    }
    if (!preserveLocalInlineReference) {
      await _deleteManagedUploadSourceIfUnused(filePath);
    }
    return true;
  }

  bool _isImageMimeType(String mimeType) {
    return mimeType.trim().toLowerCase().startsWith('image/');
  }

  Attachment _resolveAttachmentWithFallbackLink(Attachment attachment) {
    final externalLink = _resolveAttachmentExternalLink(attachment);
    if (externalLink == attachment.externalLink) {
      return attachment;
    }
    return Attachment(
      name: attachment.name,
      filename: attachment.filename,
      type: attachment.type,
      size: attachment.size,
      externalLink: externalLink,
      width: attachment.width,
      height: attachment.height,
      hash: attachment.hash,
    );
  }

  String _resolveAttachmentExternalLink(Attachment attachment) {
    final external = attachment.externalLink.trim();
    if (external.isNotEmpty) return external;
    final name = attachment.name.trim();
    if (name.isEmpty) return '';
    final filename = attachment.filename.trim();
    if (name.startsWith('resources/') || name.startsWith('attachments/')) {
      return filename.isNotEmpty ? '/file/$name/$filename' : '/file/$name';
    }
    return '';
  }

  Uri _resolveImageBedBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Image bed URL is required');
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      throw const FormatException('Invalid image bed URL');
    }
    return sanitizeImageBedBaseUrl(parsed);
  }

  Future<String> _uploadImageToImageBed({
    required ImageBedSettings settings,
    required List<int> bytes,
    required String filename,
  }) async {
    final baseUrl = _resolveImageBedBaseUrl(settings.baseUrl);
    final maxAttempts = (settings.retryCount < 0 ? 0 : settings.retryCount) + 1;
    var lastError = Object();
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await _uploadImageToLsky(
          baseUrl: baseUrl,
          settings: settings,
          bytes: bytes,
          filename: filename,
        );
      } catch (e) {
        lastError = e;
        if (!_shouldRetryImageBedError(e) || attempt == maxAttempts - 1) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw lastError;
  }

  bool _shouldRetryImageBedError(Object error) {
    if (error is ImageBedRequestException) {
      final status = error.statusCode;
      if (status == null) return true;
      if (status == 401 ||
          status == 403 ||
          status == 404 ||
          status == 405 ||
          status == 422) {
        return false;
      }
      if (status == 429) return true;
      return status >= 500;
    }
    return false;
  }

  Future<String> _uploadImageToLsky({
    required Uri baseUrl,
    required ImageBedSettings settings,
    required List<int> bytes,
    required String filename,
  }) async {
    final email = settings.email.trim();
    final password = settings.password;
    final strategyId = settings.strategyId?.trim();
    String? token = settings.authToken?.trim();
    if (token != null && token.isEmpty) {
      token = null;
    }

    Future<String?> fetchToken() async {
      if (email.isEmpty || password.isEmpty) return null;
      final newToken = await ImageBedApi.createLskyToken(
        baseUrl: baseUrl,
        email: email,
        password: password,
      );
      await imageBedRepository.write(settings.copyWith(authToken: newToken));
      return newToken;
    }

    token ??= await fetchToken();

    Future<String> uploadLegacy(String? authToken) {
      return ImageBedApi.uploadLskyLegacy(
        baseUrl: baseUrl,
        bytes: bytes,
        filename: filename,
        token: authToken,
        strategyId: strategyId,
      );
    }

    try {
      return await uploadLegacy(token);
    } on ImageBedRequestException catch (e) {
      if (e.statusCode == 401 && email.isNotEmpty && password.isNotEmpty) {
        await imageBedRepository.write(settings.copyWith(authToken: null));
        final refreshed = await fetchToken();
        if (refreshed != null) {
          return await uploadLegacy(refreshed);
        }
      }

      final isUnsupported = e.statusCode == 404 || e.statusCode == 405;
      if (isUnsupported && strategyId != null && strategyId.isNotEmpty) {
        return ImageBedApi.uploadLskyModern(
          baseUrl: baseUrl,
          bytes: bytes,
          filename: filename,
          storageId: strategyId,
        );
      }

      if (e.statusCode == 401 && (token?.isNotEmpty ?? false)) {
        return await uploadLegacy(null);
      }

      rethrow;
    }
  }

  Future<void> _replaceShareInlineMemoContent({
    required String memoUid,
    required String localUrl,
    required String remoteUrl,
    String? removeAttachmentUid,
    bool enqueueUpdate = false,
  }) async {
    final trimmedLocalUrl = localUrl.trim();
    final trimmedRemoteUrl = remoteUrl.trim();
    if (trimmedLocalUrl.isEmpty || trimmedRemoteUrl.isEmpty) return;
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    final updatedContent = replaceShareInlineLocalUrlWithRemote(
      memo.content,
      localUrl: trimmedLocalUrl,
      remoteUrl: trimmedRemoteUrl,
    );
    final attachments = removeAttachmentUid == null
        ? memo.attachments.map((item) => item.toJson()).toList(growable: false)
        : memo.attachments
              .where(
                (item) =>
                    item.uid != removeAttachmentUid &&
                    item.name != 'attachments/$removeAttachmentUid' &&
                    item.name != 'resources/$removeAttachmentUid',
              )
              .map((item) => item.toJson())
              .toList(growable: false);
    await _rewriteLocalMemo(
      memo,
      content: updatedContent,
      attachments: attachments,
    );
    if (enqueueUpdate) {
      final allowed = await guardMemoContentForRemoteSync(
        db: db,
        enabled: true,
        memoUid: memo.uid,
        content: updatedContent,
      );
      if (allowed) {
        await db.enqueueOutbox(
          type: 'update_memo',
          payload: {
            'uid': memo.uid,
            'content': updatedContent,
            'visibility': memo.visibility,
            'pinned': memo.pinned,
          },
        );
      }
    }
  }

  Future<void> _syncCurrentLocalMemoContent(String memoUid) async {
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    await api.updateMemo(
      memoUid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: memo.pinned,
    );
  }

  Future<void> _rewriteLocalMemo(
    LocalMemo memo, {
    required String content,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final now = DateTime.now().toUtc();
    await db.upsertMemo(
      uid: memo.uid,
      content: content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: extractTags(content),
      attachments: attachments,
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );
  }

  Future<void> _appendImageBedLink({
    required String memoUid,
    required String localAttachmentUid,
    required String imageUrl,
  }) async {
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      throw StateError('Memo not found: $memoUid');
    }
    final memo = LocalMemo.fromDb(row);
    final updatedContent = _appendImageMarkdown(memo.content, imageUrl);

    final expectedNames = <String>{
      'attachments/$localAttachmentUid',
      'resources/$localAttachmentUid',
    };
    final remainingAttachments = memo.attachments
        .where(
          (a) => !expectedNames.contains(a.name) && a.uid != localAttachmentUid,
        )
        .map((a) => a.toJson())
        .toList(growable: false);

    final tags = extractTags(updatedContent);
    final now = DateTime.now().toUtc();
    await db.upsertMemo(
      uid: memo.uid,
      content: updatedContent,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.millisecondsSinceEpoch ~/ 1000,
      tags: tags,
      attachments: remainingAttachments,
      location: memo.location,
      relationCount: memo.relationCount,
      syncState: 1,
      lastError: null,
    );

    final allowed = await guardMemoContentForRemoteSync(
      db: db,
      enabled: true,
      memoUid: memo.uid,
      content: updatedContent,
    );
    if (allowed) {
      await db.enqueueOutbox(
        type: 'update_memo',
        payload: {
          'uid': memo.uid,
          'content': updatedContent,
          'visibility': memo.visibility,
          'pinned': memo.pinned,
        },
      );
    }
  }

  String _appendImageMarkdown(String content, String url) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return content;
    final buffer = StringBuffer(content);
    if (buffer.isNotEmpty && !content.endsWith('\n')) {
      buffer.write('\n');
    }
    buffer.write('![]($trimmedUrl)\n');
    return buffer.toString();
  }

  Future<void> _syncMemoAttachments(String memoUid) async {
    final trimmedUid = memoUid.trim();
    final normalizedUid = trimmedUid.startsWith('memos/')
        ? trimmedUid.substring('memos/'.length)
        : trimmedUid;
    if (normalizedUid.isEmpty) return;
    final localNames = await _listLocalAttachmentNames(normalizedUid);
    try {
      await api.setMemoAttachments(
        memoUid: normalizedUid,
        attachmentNames: localNames,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _handleDeleteAttachment(Map<String, dynamic> payload) async {
    final name =
        payload['attachment_name'] as String? ??
        payload['attachmentName'] as String? ??
        payload['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw const FormatException('delete_attachment missing name');
    }
    try {
      await api.deleteAttachment(attachmentName: name);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) return;
      rethrow;
    }
  }

  Future<int> _countPendingAttachmentUploads(String memoUid) async {
    final rows = await db.listOutboxPendingByType('upload_attachment');
    var count = 0;
    for (final row in rows) {
      final payloadRaw = row['payload'];
      if (payloadRaw is! String) continue;
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is! Map) continue;
        final payload = decoded.cast<String, dynamic>();
        final targetMemoUid = payload['memo_uid'];
        if (targetMemoUid is String && targetMemoUid.trim() == memoUid) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<bool> _isLastPendingAttachmentUpload(String memoUid) async {
    final pending = await _countPendingAttachmentUploads(memoUid);
    return pending <= 1;
  }

  Future<void> _deleteManagedUploadSourceIfUnused(String filePath) async {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) return;
    final stager = QueuedAttachmentStager();
    if (!stager.isManagedPath(trimmed)) return;
    try {
      await stager.deleteManagedFile(trimmed);
    } catch (_) {}
  }

  Future<List<String>> _listLocalAttachmentNames(String memoUid) async {
    final row = await db.getMemoByUid(memoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final names = <String>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final name = item['name'];
        if (name is String && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }
      return names.toSet().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Attachment> _createAttachmentWith409Recovery({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    required String? memoUid,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    try {
      return await api.createAttachment(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 409) rethrow;
      return api.getAttachment(attachmentUid: attachmentId);
    }
  }

  Future<void> _updateLocalAttachmentMeta({
    required String memoUid,
    required String localAttachmentUid,
    required String filename,
    required String mimeType,
    required int size,
    int? width,
    int? height,
    String? hash,
    String? externalLink,
  }) async {
    final row = await db.getMemoByUid(memoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;

    final expectedNames = <String>{
      'attachments/$localAttachmentUid',
      'resources/$localAttachmentUid',
    };

    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final name = (m['name'] as String?) ?? '';
      final fn = (m['filename'] as String?) ?? '';

      if (expectedNames.contains(name) || fn == filename) {
        final next = Map<String, dynamic>.from(m);
        next['filename'] = filename;
        next['type'] = mimeType;
        next['size'] = size;
        if (externalLink != null) {
          next['externalLink'] = externalLink;
        }
        if (width != null) next['width'] = width;
        if (height != null) next['height'] = height;
        if (hash != null) next['hash'] = hash;
        out.add(next);
        changed = true;
        continue;
      }
      out.add(m);
    }

    if (!changed) return;
    await db.updateMemoAttachmentsJson(
      memoUid,
      attachmentsJson: jsonEncode(out),
    );
  }

  Future<void> _updateLocalMemoAttachment({
    required String memoUid,
    required String localAttachmentUid,
    required String filename,
    required Attachment remote,
    bool preserveExternalLink = false,
  }) async {
    final row = await db.getMemoByUid(memoUid);
    final raw = row?['attachments_json'];
    if (raw is! String || raw.trim().isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;

    final expectedNames = <String>{
      'attachments/$localAttachmentUid',
      'resources/$localAttachmentUid',
    };

    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final name = (m['name'] as String?) ?? '';
      final fn = (m['filename'] as String?) ?? '';

      if (expectedNames.contains(name) || fn == filename) {
        final next = Map<String, dynamic>.from(m);
        next['name'] = remote.name;
        next['filename'] = remote.filename;
        next['type'] = remote.type;
        next['size'] = remote.size;
        final previousExternalLink = (m['externalLink'] as String? ?? '')
            .trim();
        next['externalLink'] =
            preserveExternalLink && previousExternalLink.isNotEmpty
            ? previousExternalLink
            : remote.externalLink;
        if (remote.width != null) next['width'] = remote.width;
        if (remote.height != null) next['height'] = remote.height;
        if (remote.hash != null) next['hash'] = remote.hash;
        out.add(next);
        changed = true;
        continue;
      }

      out.add(m);
    }

    if (!changed) return;
    await db.updateMemoAttachmentsJson(
      memoUid,
      attachmentsJson: jsonEncode(out),
    );
  }
}
