part of '../memos_api.dart';

mixin _MemosApiResources on _MemosApiBase {
  Future<AttachmentUploadSizeLimit> getAttachmentUploadSizeLimit() async {
    final limit = await getServerAttachmentUploadLimitMiB();
    if (limit.isKnown) {
      return AttachmentUploadSizeLimit.known(
        bytes: limit.value! * 1024 * 1024,
        source: _attachmentUploadSizeLimitSource(limit.source),
      );
    }
    return AttachmentUploadSizeLimit.unknown(
      _attachmentUploadSizeLimitUnknownReason(limit.unavailableReason),
    );
  }

  Future<ServerSettingsSnapshot> getServerSettings() async {
    final memoLimit = await getServerMemoContentLimitBytes();
    final attachmentLimit = await getServerAttachmentUploadLimitMiB();
    return ServerSettingsSnapshot(
      memoContentLimitBytes: memoLimit,
      attachmentUploadLimitMiB: attachmentLimit,
    );
  }

  Future<ServerSettingValue<int>> getServerMemoContentLimitBytes() async {
    await _ensureServerHints();
    return switch (_serverFlavor) {
      _ServerApiFlavor.v0_21 => const ServerSettingValue<int>.unsupported(),
      _ServerApiFlavor.v0_22 ||
      _ServerApiFlavor.v0_23 ||
      _ServerApiFlavor.v0_24 => _getMemoRelatedContentLimitBytes(
        path: 'api/v1/workspace/settings/MEMO_RELATED',
        source: ServerSettingSource.workspaceMemoRelatedSetting,
      ),
      _ServerApiFlavor.v0_25Plus ||
      _ServerApiFlavor.unknown => _getMemoRelatedContentLimitBytes(
        path: 'api/v1/instance/settings/MEMO_RELATED',
        source: ServerSettingSource.instanceMemoRelatedSetting,
      ),
    };
  }

  Future<ServerSettingValue<int>> getServerAttachmentUploadLimitMiB() async {
    await _ensureServerHints();
    return switch (_serverFlavor) {
      _ServerApiFlavor.v0_21 => _getLegacyStatusAttachmentUploadLimitMiB(),
      _ServerApiFlavor.v0_22 ||
      _ServerApiFlavor.v0_23 ||
      _ServerApiFlavor.v0_24 => _getStorageUploadLimitMiB(
        path: 'api/v1/workspace/settings/STORAGE',
        source: ServerSettingSource.workspaceStorageSetting,
      ),
      _ServerApiFlavor.v0_25Plus ||
      _ServerApiFlavor.unknown => _getStorageUploadLimitMiB(
        path: 'api/v1/instance/settings/STORAGE',
        source: ServerSettingSource.instanceStorageSetting,
      ),
    };
  }

  Future<ServerSettingValue<int>> updateServerMemoContentLimitBytes(
    int bytes,
  ) async {
    if (bytes <= 0) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Memo content length limit must be positive.',
      );
    }
    await _ensureServerHints();
    return switch (_serverFlavor) {
      _ServerApiFlavor.v0_21 => const ServerSettingValue<int>.unsupported(),
      _ServerApiFlavor.v0_22 ||
      _ServerApiFlavor.v0_23 ||
      _ServerApiFlavor.v0_24 => _updateMemoRelatedContentLimitBytes(
        path: 'api/v1/workspace/settings/MEMO_RELATED',
        name: 'settings/MEMO_RELATED',
        source: ServerSettingSource.workspaceMemoRelatedSetting,
        bytes: bytes,
      ),
      _ServerApiFlavor.v0_25Plus ||
      _ServerApiFlavor.unknown => _updateMemoRelatedContentLimitBytes(
        path: 'api/v1/instance/settings/MEMO_RELATED',
        name: 'instance/settings/MEMO_RELATED',
        source: ServerSettingSource.instanceMemoRelatedSetting,
        bytes: bytes,
        updateMask: 'memo_related_setting.content_length_limit',
      ),
    };
  }

  Future<ServerSettingValue<int>> updateServerAttachmentUploadLimitMiB(
    int mebibytes,
  ) async {
    if (mebibytes <= 0) {
      throw ArgumentError.value(
        mebibytes,
        'mebibytes',
        'Attachment upload size limit must be positive.',
      );
    }
    await _ensureServerHints();
    return switch (_serverFlavor) {
      _ServerApiFlavor.v0_21 => _updateLegacySystemAttachmentUploadLimitMiB(
        mebibytes,
      ),
      _ServerApiFlavor.v0_22 ||
      _ServerApiFlavor.v0_23 ||
      _ServerApiFlavor.v0_24 => _updateStorageUploadLimitMiB(
        path: 'api/v1/workspace/settings/STORAGE',
        name: 'settings/STORAGE',
        source: ServerSettingSource.workspaceStorageSetting,
        mebibytes: mebibytes,
      ),
      _ServerApiFlavor.v0_25Plus ||
      _ServerApiFlavor.unknown => _updateStorageUploadLimitMiB(
        path: 'api/v1/instance/settings/STORAGE',
        name: 'instance/settings/STORAGE',
        source: ServerSettingSource.instanceStorageSetting,
        mebibytes: mebibytes,
        updateMask: 'storage_setting.upload_size_limit_mb',
      ),
    };
  }

  Future<ServerSettingValue<int>>
  _getLegacyStatusAttachmentUploadLimitMiB() async {
    try {
      final response = await _dio.get('api/v1/status');
      final body = _expectJsonMap(response.data);
      return _serverSettingFromPositiveInt(
        body['maxUploadSizeMiB'] ?? body['max_upload_size_mib'],
        source: ServerSettingSource.legacySystemStatus,
      );
    } on DioException catch (error) {
      return _unknownServerSettingValue(error);
    } on FormatException {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.invalidResponse,
      );
    }
  }

  Future<ServerSettingValue<int>> _getStorageUploadLimitMiB({
    required String path,
    required ServerSettingSource source,
  }) async {
    try {
      final response = await _dio.get(path);
      final body = _expectJsonMap(response.data);
      final storageSetting = _extractServerSettingValue(
        body,
        camelKey: 'storageSetting',
        snakeKey: 'storage_setting',
      );
      return _serverSettingFromPositiveInt(
        storageSetting?['uploadSizeLimitMb'] ??
            storageSetting?['upload_size_limit_mb'],
        source: source,
      );
    } on DioException catch (error) {
      return _unknownServerSettingValue(error);
    } on FormatException {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.invalidResponse,
      );
    }
  }

  Future<ServerSettingValue<int>> _getMemoRelatedContentLimitBytes({
    required String path,
    required ServerSettingSource source,
  }) async {
    try {
      final response = await _dio.get(path);
      final body = _expectJsonMap(response.data);
      final memoRelatedSetting = _extractServerSettingValue(
        body,
        camelKey: 'memoRelatedSetting',
        snakeKey: 'memo_related_setting',
      );
      return _serverSettingFromPositiveInt(
        memoRelatedSetting?['contentLengthLimit'] ??
            memoRelatedSetting?['content_length_limit'],
        source: source,
      );
    } on DioException catch (error) {
      return _unknownServerSettingValue(error);
    } on FormatException {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.invalidResponse,
      );
    }
  }

  Future<ServerSettingValue<int>> _updateLegacySystemAttachmentUploadLimitMiB(
    int mebibytes,
  ) async {
    try {
      final response = await _dio.post(
        'api/v1/system/setting',
        data: <String, Object?>{
          'name': 'max-upload-size-mib',
          'value': mebibytes.toString(),
          'description': '',
        },
      );
      final body = _expectJsonMap(response.data);
      final value = body['value'] ?? body['maxUploadSizeMiB'] ?? mebibytes;
      return _serverSettingFromPositiveInt(
        value,
        source: ServerSettingSource.legacySystemSetting,
      );
    } on DioException catch (error) {
      return _unknownServerSettingValue(error);
    } on FormatException {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.invalidResponse,
      );
    }
  }

  Future<ServerSettingValue<int>> _updateStorageUploadLimitMiB({
    required String path,
    required String name,
    required ServerSettingSource source,
    required int mebibytes,
    String? updateMask,
  }) async {
    try {
      final response = await _dio.get(path);
      final body = _expectJsonMap(response.data);
      final payload = _serverSettingPayload(body);
      final storageSetting = Map<String, Object?>.from(
        _extractServerSettingValue(
              body,
              camelKey: 'storageSetting',
              snakeKey: 'storage_setting',
            ) ??
            const <String, Object?>{},
      );
      _setIntFieldPreservingStyle(
        storageSetting,
        camelKey: 'uploadSizeLimitMb',
        snakeKey: 'upload_size_limit_mb',
        value: mebibytes,
      );
      final data = Map<String, Object?>.from(payload);
      data['name'] = _readString(payload['name']).isNotEmpty
          ? payload['name']
          : name;
      _putServerSettingValue(
        data,
        camelKey: 'storageSetting',
        snakeKey: 'storage_setting',
        value: storageSetting,
      );
      final updated = await _dio.patch(
        path,
        queryParameters: _updateMaskQuery(updateMask),
        data: data,
      );
      final updatedBody = _expectJsonMap(updated.data);
      final updatedStorageSetting = _extractServerSettingValue(
        updatedBody,
        camelKey: 'storageSetting',
        snakeKey: 'storage_setting',
      );
      return _serverSettingFromPositiveInt(
        updatedStorageSetting?['uploadSizeLimitMb'] ??
            updatedStorageSetting?['upload_size_limit_mb'] ??
            mebibytes,
        source: source,
      );
    } on DioException catch (error) {
      return _unknownServerSettingValue(error);
    } on FormatException {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.invalidResponse,
      );
    }
  }

  Future<ServerSettingValue<int>> _updateMemoRelatedContentLimitBytes({
    required String path,
    required String name,
    required ServerSettingSource source,
    required int bytes,
    String? updateMask,
  }) async {
    try {
      final response = await _dio.get(path);
      final body = _expectJsonMap(response.data);
      final payload = _serverSettingPayload(body);
      final memoRelatedSetting = Map<String, Object?>.from(
        _extractServerSettingValue(
              body,
              camelKey: 'memoRelatedSetting',
              snakeKey: 'memo_related_setting',
            ) ??
            const <String, Object?>{},
      );
      _setIntFieldPreservingStyle(
        memoRelatedSetting,
        camelKey: 'contentLengthLimit',
        snakeKey: 'content_length_limit',
        value: bytes,
      );
      final data = Map<String, Object?>.from(payload);
      data['name'] = _readString(payload['name']).isNotEmpty
          ? payload['name']
          : name;
      _putServerSettingValue(
        data,
        camelKey: 'memoRelatedSetting',
        snakeKey: 'memo_related_setting',
        value: memoRelatedSetting,
      );
      final updated = await _dio.patch(
        path,
        queryParameters: _updateMaskQuery(updateMask),
        data: data,
      );
      final updatedBody = _expectJsonMap(updated.data);
      final updatedMemoRelatedSetting = _extractServerSettingValue(
        updatedBody,
        camelKey: 'memoRelatedSetting',
        snakeKey: 'memo_related_setting',
      );
      return _serverSettingFromPositiveInt(
        updatedMemoRelatedSetting?['contentLengthLimit'] ??
            updatedMemoRelatedSetting?['content_length_limit'] ??
            bytes,
        source: source,
      );
    } on DioException catch (error) {
      return _unknownServerSettingValue(error);
    } on FormatException {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.invalidResponse,
      );
    }
  }

  ServerSettingValue<int> _serverSettingFromPositiveInt(
    Object? value, {
    required ServerSettingSource source,
  }) {
    final normalized = _tryReadServerSettingInt(value);
    if (normalized == null) {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.invalidResponse,
      );
    }
    if (normalized <= 0) {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.nonPositiveLimit,
      );
    }
    return ServerSettingValue<int>.known(value: normalized, source: source);
  }

  int? _tryReadServerSettingInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  ServerSettingValue<int> _unknownServerSettingValue(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.permissionDenied,
      );
    }
    if (status == 404 || status == 405) {
      return const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.endpointUnavailable,
      );
    }
    return const ServerSettingValue<int>.unavailable(
      unavailableReason: ServerSettingUnavailableReason.requestFailed,
    );
  }

  Map<String, dynamic> _serverSettingPayload(Map<String, dynamic> body) {
    return _readMap(body['setting']) ?? body;
  }

  Map<String, dynamic>? _extractServerSettingValue(
    Map<String, dynamic> body, {
    required String camelKey,
    required String snakeKey,
  }) {
    final payload = _serverSettingPayload(body);
    final direct = _readMap(payload[camelKey]) ?? _readMap(payload[snakeKey]);
    if (direct != null) return direct;

    final value = _readMap(payload['value']);
    final nested = _readMap(value?[camelKey]) ?? _readMap(value?[snakeKey]);
    if (nested != null) return nested;
    return _readMap(value?['value']);
  }

  void _setIntFieldPreservingStyle(
    Map<String, Object?> map, {
    required String camelKey,
    required String snakeKey,
    required int value,
  }) {
    if (map.containsKey(snakeKey) && !map.containsKey(camelKey)) {
      map[snakeKey] = value;
      return;
    }
    map[camelKey] = value;
  }

  void _putServerSettingValue(
    Map<String, Object?> payload, {
    required String camelKey,
    required String snakeKey,
    required Map<String, Object?> value,
  }) {
    if (payload.containsKey(snakeKey) && !payload.containsKey(camelKey)) {
      payload[snakeKey] = value;
      return;
    }
    payload[camelKey] = value;
  }

  Map<String, Object?>? _updateMaskQuery(String? updateMask) {
    final normalized = (updateMask ?? '').trim();
    if (normalized.isEmpty) return null;
    return <String, Object?>{
      'updateMask': normalized,
      'update_mask': normalized,
    };
  }

  AttachmentUploadSizeLimitSource _attachmentUploadSizeLimitSource(
    ServerSettingSource? source,
  ) {
    return switch (source) {
      ServerSettingSource.legacySystemStatus ||
      ServerSettingSource.legacySystemSetting ||
      null => AttachmentUploadSizeLimitSource.systemStatus,
      ServerSettingSource.workspaceStorageSetting =>
        AttachmentUploadSizeLimitSource.workspaceStorageSetting,
      ServerSettingSource.instanceStorageSetting =>
        AttachmentUploadSizeLimitSource.instanceStorageSetting,
      ServerSettingSource.workspaceMemoRelatedSetting ||
      ServerSettingSource.instanceMemoRelatedSetting =>
        AttachmentUploadSizeLimitSource.instanceStorageSetting,
    };
  }

  AttachmentUploadSizeLimitUnknownReason
  _attachmentUploadSizeLimitUnknownReason(
    ServerSettingUnavailableReason? reason,
  ) {
    return switch (reason) {
      ServerSettingUnavailableReason.localLibrary =>
        AttachmentUploadSizeLimitUnknownReason.localLibrary,
      ServerSettingUnavailableReason.permissionDenied =>
        AttachmentUploadSizeLimitUnknownReason.permissionDenied,
      ServerSettingUnavailableReason.endpointUnavailable ||
      ServerSettingUnavailableReason.unsupportedVersion =>
        AttachmentUploadSizeLimitUnknownReason.endpointUnavailable,
      ServerSettingUnavailableReason.invalidResponse =>
        AttachmentUploadSizeLimitUnknownReason.invalidResponse,
      ServerSettingUnavailableReason.nonPositiveLimit =>
        AttachmentUploadSizeLimitUnknownReason.nonPositiveLimit,
      ServerSettingUnavailableReason.requestFailed ||
      null => AttachmentUploadSizeLimitUnknownReason.requestFailed,
    };
  }

  Future<Attachment> createAttachment({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String? memoUid,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    await _ensureServerHints();
    if (_useLegacyMemos || _attachmentMode == _AttachmentApiMode.legacy) {
      return _createAttachmentLegacy(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
        onSendProgress: onSendProgress,
      );
    }
    if (_attachmentMode == _AttachmentApiMode.resources) {
      return _createAttachmentCompat(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
        onSendProgress: onSendProgress,
      );
    }
    return _createAttachmentModern(
      attachmentId: attachmentId,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
      memoUid: memoUid,
      onSendProgress: onSendProgress,
    );
  }

  Future<Attachment> _createAttachmentModern({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String? memoUid,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final data = <String, Object?>{
      'filename': filename,
      'type': mimeType,
      'content': base64Encode(bytes),
      if (memoUid != null) 'memo': 'memos/$memoUid',
    };
    final response = await _dio.post(
      'api/v1/attachments',
      queryParameters: <String, Object?>{'attachmentId': attachmentId},
      data: data,
      options: _attachmentOptions(),
      onSendProgress: onSendProgress,
    );
    _attachmentMode = _AttachmentApiMode.attachments;
    final attachment = Attachment.fromJson(_expectJsonMap(response.data));
    return _normalizeAttachmentForServer(attachment);
  }

  Future<Attachment> _createAttachmentCompat({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String? memoUid,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final data = <String, Object?>{
      'filename': filename,
      'type': mimeType,
      'content': base64Encode(bytes),
      if (memoUid != null) 'memo': 'memos/$memoUid',
    };
    final response = await _dio.post(
      'api/v1/resources',
      queryParameters: <String, Object?>{'resourceId': attachmentId},
      data: data,
      options: _attachmentOptions(),
      onSendProgress: onSendProgress,
    );
    _attachmentMode = _AttachmentApiMode.resources;
    final attachment = Attachment.fromJson(_expectJsonMap(response.data));
    return _normalizeAttachmentForServer(attachment);
  }

  Future<Attachment> getAttachment({required String attachmentUid}) async {
    await _ensureServerHints();
    if (_useLegacyMemos || _attachmentMode == _AttachmentApiMode.legacy) {
      return _getAttachmentLegacy(attachmentUid);
    }
    if (_attachmentMode == _AttachmentApiMode.resources) {
      return _getAttachmentCompat(attachmentUid);
    }
    return _getAttachmentModern(attachmentUid);
  }

  Future<Attachment> _getAttachmentModern(String attachmentUid) async {
    final response = await _dio.get('api/v1/attachments/$attachmentUid');
    _attachmentMode = _AttachmentApiMode.attachments;
    final attachment = Attachment.fromJson(_expectJsonMap(response.data));
    return _normalizeAttachmentForServer(attachment);
  }

  Future<Attachment> _getAttachmentCompat(String attachmentUid) async {
    final response = await _dio.get('api/v1/resources/$attachmentUid');
    _attachmentMode = _AttachmentApiMode.resources;
    final attachment = Attachment.fromJson(_expectJsonMap(response.data));
    return _normalizeAttachmentForServer(attachment);
  }

  Future<void> deleteAttachment({required String attachmentName}) async {
    await _ensureServerHints();
    final attachmentUid = _normalizeAttachmentUid(attachmentName);
    if (_useLegacyMemos || _attachmentMode == _AttachmentApiMode.legacy) {
      await _deleteAttachmentLegacy(attachmentUid);
      return;
    }
    if (_attachmentMode == _AttachmentApiMode.resources) {
      await _deleteAttachmentCompat(attachmentUid);
      return;
    }
    await _deleteAttachmentModern(attachmentUid);
  }

  Future<void> _deleteAttachmentModern(String attachmentUid) async {
    await _dio.delete('api/v1/attachments/$attachmentUid');
    _attachmentMode = _AttachmentApiMode.attachments;
  }

  Future<void> _deleteAttachmentCompat(String attachmentUid) async {
    await _dio.delete('api/v1/resources/$attachmentUid');
    _attachmentMode = _AttachmentApiMode.resources;
  }

  Future<void> _deleteAttachmentLegacy(String attachmentUid) async {
    final targetId = _tryParseLegacyResourceId(attachmentUid);
    if (targetId == null) {
      throw FormatException('Invalid legacy attachment id: $attachmentUid');
    }
    await _dio.delete('api/v1/resource/$targetId');
    _attachmentMode = _AttachmentApiMode.legacy;
  }

  Future<List<Attachment>> listMemoAttachments({
    required String memoUid,
  }) async {
    await _ensureServerHints();
    if (_attachmentMode == _AttachmentApiMode.legacy) {
      return const <Attachment>[];
    }
    if (_attachmentMode == _AttachmentApiMode.resources) {
      return _listMemoResources(memoUid);
    }
    if (_attachmentMode == _AttachmentApiMode.attachments) {
      return _listMemoAttachmentsModern(memoUid);
    }
    return _listMemoAttachmentsModern(memoUid);
  }

  Future<List<Attachment>> _listMemoAttachmentsModern(String memoUid) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid/attachments',
      queryParameters: const <String, Object?>{'pageSize': 1000},
    );
    _attachmentMode = _AttachmentApiMode.attachments;
    final body = _expectJsonMap(response.data);
    final list = body['attachments'];
    final attachments = <Attachment>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          attachments.add(Attachment.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return _normalizeAttachmentsForServer(attachments);
  }

  Future<List<Attachment>> _listMemoResources(String memoUid) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid/resources',
      queryParameters: const <String, Object?>{'pageSize': 1000},
    );
    _attachmentMode = _AttachmentApiMode.resources;
    final body = _expectJsonMap(response.data);
    final list = body['resources'];
    final attachments = <Attachment>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          attachments.add(Attachment.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return _normalizeAttachmentsForServer(attachments);
  }

  Future<void> setMemoAttachments({
    required String memoUid,
    required List<String> attachmentNames,
  }) async {
    await _ensureServerHints();
    if (_attachmentMode == _AttachmentApiMode.legacy) {
      await _setMemoAttachmentsLegacy(memoUid, attachmentNames);
      return;
    }
    if (_attachmentMode == _AttachmentApiMode.resources) {
      await _setMemoResources(memoUid, attachmentNames);
      return;
    }
    if (_attachmentMode == _AttachmentApiMode.attachments) {
      await _setMemoAttachmentsModern(memoUid, attachmentNames);
      return;
    }
    await _setMemoAttachmentsModern(memoUid, attachmentNames);
  }

  Future<void> _setMemoAttachmentsModern(
    String memoUid,
    List<String> attachmentNames,
  ) async {
    await _dio.patch(
      'api/v1/memos/$memoUid/attachments',
      data: <String, Object?>{
        'name': 'memos/$memoUid',
        'attachments': attachmentNames
            .map((n) => <String, Object?>{'name': n})
            .toList(growable: false),
      },
      options: _attachmentOptions(),
    );
    _attachmentMode = _AttachmentApiMode.attachments;
  }

  Future<void> _setMemoResources(
    String memoUid,
    List<String> attachmentNames,
  ) async {
    await _dio.patch(
      'api/v1/memos/$memoUid/resources',
      data: <String, Object?>{
        'name': 'memos/$memoUid',
        'resources': attachmentNames
            .map((n) => <String, Object?>{'name': n})
            .toList(growable: false),
      },
      options: _attachmentOptions(),
    );
    _attachmentMode = _AttachmentApiMode.resources;
  }

  Future<Attachment> _createAttachmentLegacy({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String? memoUid,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final _ = [attachmentId, mimeType, memoUid];
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post(
      'api/v1/resource/blob',
      data: formData,
      options: _attachmentOptions(),
      onSendProgress: onSendProgress,
    );
    _attachmentMode = _AttachmentApiMode.legacy;
    return _attachmentFromLegacy(_expectJsonMap(response.data));
  }

  Future<Attachment> _getAttachmentLegacy(String attachmentUid) async {
    final targetId = _tryParseLegacyResourceId(attachmentUid);
    if (targetId == null) {
      throw FormatException('Invalid legacy attachment id: $attachmentUid');
    }
    final response = await _dio.get('api/v1/resource');
    final list = _readListPayload(response.data);
    for (final item in list) {
      if (item is Map) {
        final map = item.cast<String, dynamic>();
        if (_readInt(map['id']) == targetId) {
          return _attachmentFromLegacy(map);
        }
      }
    }
    throw StateError('Legacy attachment not found: $attachmentUid');
  }

  Future<void> _setMemoAttachmentsLegacy(
    String memoUid,
    List<String> attachmentNames,
  ) async {
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo',
      operation: 'set_memo_attachments_legacy',
    )) {
      throw StateError(
        'Legacy memo attachment endpoint is blocked for server flavor ${_serverFlavor.name}',
      );
    }
    final resourceIds = attachmentNames
        .map(_tryParseLegacyResourceId)
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    await _dio.patch(
      'api/v1/memo/$memoUid',
      data: <String, Object?>{
        'id': _legacyMemoIdValue(memoUid),
        'resourceIdList': resourceIds,
      },
      options: _attachmentOptions(),
    );
    _attachmentMode = _AttachmentApiMode.legacy;
  }
}
