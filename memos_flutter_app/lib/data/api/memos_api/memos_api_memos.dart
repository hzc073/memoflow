part of memos_api;

mixin _MemosApiMemos on _MemosApiBase {
  static const String _kGrpcWebContentType = 'application/grpc-web+proto';
  static const String _kGrpcWebUpdateMemoPath =
      '/memos.api.v1.MemoService/UpdateMemo';

  bool _supportsLegacyMemoUpdateEndpoint() {
    return _serverFlavor == _ServerApiFlavor.v0_21;
  }

  bool _legacyMemoUpdateEndpointAllowed() {
    return _legacyMemoEndpointsAllowed() && _supportsLegacyMemoUpdateEndpoint();
  }

  Future<(List<Memo> memos, String nextPageToken)> listMemos({
    int pageSize = 50,
    String? pageToken,
    String? state,
    String? filter,
    String? parent,
    String? orderBy,
    String? oldFilter,
    Duration? receiveTimeout,
    bool preferModern = false,
  }) async {
    await _ensureServerHints();
    if (_useLegacyMemos) {
      if (!_ensureLegacyMemoEndpointAllowed(
        'api/v1/memo',
        operation: 'list_memos_force_legacy',
      )) {
        throw StateError(
          'Legacy memo endpoint is disabled for ${_serverFlavor.name}',
        );
      }
      return _listMemosLegacy(
        pageSize: pageSize,
        pageToken: pageToken,
        state: state,
        filter: filter,
      );
    }
    return _listMemosModern(
      pageSize: pageSize,
      pageToken: pageToken,
      state: state,
      filter: filter,
      parent: parent,
      orderBy: orderBy,
      oldFilter: oldFilter,
      receiveTimeout: receiveTimeout,
    );
  }

  Future<({List<Memo> memos, String nextPageToken, bool usedLegacyAll})>
  listExploreMemos({
    int pageSize = 50,
    String? pageToken,
    String? state,
    String? filter,
    String? orderBy,
  }) async {
    await _ensureServerHints();
    if (_useLegacyMemos) {
      final (legacyMemos, legacyToken) = await _listMemosAllLegacy(
        pageSize: pageSize,
        pageToken: pageToken,
      );
      return (
        memos: legacyMemos,
        nextPageToken: legacyToken,
        usedLegacyAll: true,
      );
    }

    final effectiveFilter = _normalizeExploreFilterForServer(
      filter: filter,
      state: state,
    );
    final (memos, nextToken) = await _listMemosModern(
      pageSize: pageSize,
      pageToken: pageToken,
      state: state,
      filter: effectiveFilter,
      orderBy: orderBy,
    );
    return (memos: memos, nextPageToken: nextToken, usedLegacyAll: false);
  }

  String _normalizeExploreFilterForServer({
    String? filter,
    String? state,
    bool forceLegacyDialect = false,
  }) {
    final normalized = (filter ?? '').trim();
    if (!forceLegacyDialect &&
        _serverFlavor != _ServerApiFlavor.v0_22 &&
        _serverFlavor != _ServerApiFlavor.v0_23) {
      return normalized;
    }

    final conditions = <String>[];
    final rowStatus = _normalizeLegacyRowStatus(state);
    if (rowStatus != null && rowStatus.isNotEmpty) {
      conditions.add('row_status == "${_escapeLegacyFilterString(rowStatus)}"');
    }

    var includeProtected = true;
    final visibilityMatch = RegExp(
      r'''visibility\s+in\s+\[([^\]]*)\]''',
    ).firstMatch(normalized);
    if (visibilityMatch != null) {
      includeProtected = RegExp(
        r'''["']PROTECTED["']''',
      ).hasMatch(visibilityMatch.group(1) ?? '');
    }
    final visibilities = includeProtected
        ? "'PUBLIC', 'PROTECTED'"
        : "'PUBLIC'";
    conditions.add('visibilities == [$visibilities]');

    final query = _extractExploreModernContentQuery(normalized);
    if (query.isNotEmpty) {
      conditions.add('content_search == [${jsonEncode(query)}]');
    }

    return conditions.join(' && ');
  }

  Future<(List<Memo> memos, String nextPageToken)> _listMemosModern({
    required int pageSize,
    String? pageToken,
    String? state,
    String? filter,
    String? parent,
    String? orderBy,
    String? oldFilter,
    Duration? receiveTimeout,
  }) async {
    final normalizedPageToken = (pageToken ?? '').trim();
    final normalizedParent = (parent ?? '').trim();
    final normalizedOldFilter = (oldFilter ?? '').trim();
    final effectiveFilter = _routeAdapter.usesLegacyRowStatusFilterInListMemos
        ? _mergeLegacyRowStatusFilter(filter: filter, state: state)
        : filter;
    final timeout =
        receiveTimeout ?? (pageSize >= 500 ? _largeListReceiveTimeout : null);
    final response = await _dio.get(
      'api/v1/memos',
      options: timeout == null ? null : Options(receiveTimeout: timeout),
      queryParameters: <String, Object?>{
        'pageSize': pageSize,
        'page_size': pageSize,
        if (_routeAdapter.requiresMemoFullView) 'view': 'MEMO_VIEW_FULL',
        if (normalizedPageToken.isNotEmpty) 'pageToken': normalizedPageToken,
        if (normalizedPageToken.isNotEmpty) 'page_token': normalizedPageToken,
        if (_routeAdapter.supportsMemoParentQuery &&
            normalizedParent.isNotEmpty)
          'parent': normalizedParent,
        if (_routeAdapter.sendsStateInListMemos &&
            state != null &&
            state.isNotEmpty)
          'state': state,
        if (effectiveFilter != null && effectiveFilter.isNotEmpty)
          'filter': effectiveFilter,
        if (orderBy != null && orderBy.isNotEmpty) 'orderBy': orderBy,
        if (orderBy != null && orderBy.isNotEmpty) 'order_by': orderBy,
        if (normalizedOldFilter.isNotEmpty) 'oldFilter': normalizedOldFilter,
        if (normalizedOldFilter.isNotEmpty) 'old_filter': normalizedOldFilter,
      },
    );
    final body = _expectJsonMap(response.data);
    final list = body['memos'];
    final memos = <Memo>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          memos.add(_memoFromJson(item.cast<String, dynamic>()));
        }
      }
    }
    final nextToken = _readStringField(
      body,
      'nextPageToken',
      'next_page_token',
    );
    return (memos, nextToken);
  }

  Future<(List<Memo> memos, String nextPageToken)> _listMemosAllLegacy({
    required int pageSize,
    String? pageToken,
  }) async {
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo/all',
      operation: 'list_memos_all_legacy',
    )) {
      throw StateError(
        'Legacy memo/all endpoint is blocked for server flavor ${_serverFlavor.name}',
      );
    }
    final normalizedToken = (pageToken ?? '').trim();
    final offset = int.tryParse(normalizedToken) ?? 0;
    final limit = pageSize > 0 ? pageSize : 0;
    final response = await _dio.get(
      'api/v1/memo/all',
      queryParameters: <String, Object?>{
        if (limit > 0) 'limit': limit,
        if (offset > 0) 'offset': offset,
      },
    );

    final list = _readListPayload(response.data);
    final memos = <Memo>[];
    for (final item in list) {
      if (item is Map) {
        memos.add(_memoFromLegacy(item.cast<String, dynamic>()));
      }
    }
    if (limit <= 0) {
      return (memos, '');
    }
    if (memos.isEmpty) {
      return (memos, '');
    }
    final nextOffset = offset + memos.length;
    final nextToken = memos.length < limit ? '' : nextOffset.toString();
    return (memos, nextToken);
  }

  Future<Memo> getMemo({required String memoUid}) async {
    await _ensureServerHints();
    if (_useLegacyMemos) {
      if (!_ensureLegacyMemoEndpointAllowed(
        'api/v1/memo',
        operation: 'get_memo_force_legacy',
      )) {
        throw StateError(
          'Legacy memo endpoint is disabled for ${_serverFlavor.name}',
        );
      }
      return _getMemoLegacy(memoUid);
    }
    return _getMemoModern(memoUid);
  }

  Future<Memo> _getMemoModern(String memoUid) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid',
      queryParameters: <String, Object?>{
        if (_routeAdapter.requiresMemoFullView) 'view': 'MEMO_VIEW_FULL',
      },
    );
    return _memoFromJson(_expectJsonMap(response.data));
  }

  Future<Memo> _getMemoLegacy(String memoUid) async {
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo',
      operation: 'get_memo_legacy',
    )) {
      throw StateError(
        'Legacy memo endpoint is disabled for ${_serverFlavor.name}',
      );
    }
    return _getMemoLegacyV1(memoUid);
  }

  Future<Memo> getMemoCompat({required String memoUid}) async {
    return getMemo(memoUid: memoUid);
  }

  Future<Memo> _getMemoLegacyV1(String memoUid) async {
    final response = await _dio.get('api/v1/memo/$memoUid');
    return _memoFromLegacy(_expectJsonMap(response.data));
  }

  Future<Memo> createMemo({
    required String memoId,
    required String content,
    String visibility = 'PRIVATE',
    bool pinned = false,
    MemoLocation? location,
    DateTime? createTime,
    DateTime? displayTime,
    List<Map<String, dynamic>> relations = const <Map<String, dynamic>>[],
  }) async {
    await _ensureServerHints();
    if (_useLegacyMemos) {
      if (!_ensureLegacyMemoEndpointAllowed(
        'api/v1/memo',
        operation: 'create_memo_force_legacy',
      )) {
        throw StateError(
          'Legacy memo endpoint is disabled for ${_serverFlavor.name}',
        );
      }
      return _createMemoLegacy(
        memoId: memoId,
        content: content,
        visibility: visibility,
        pinned: pinned,
      );
    }
    return _createMemoModern(
      memoId: memoId,
      content: content,
      visibility: visibility,
      pinned: pinned,
      location: location,
      createTime: createTime,
      displayTime: displayTime,
      relations: relations,
    );
  }

  bool get supportsCreateMemoTimestampsInCreateBody =>
      _supportsCreateMemoTimestampFieldsInModernBody();

  bool get supportsCreateMemoRelationsInCreateBody =>
      _supportsCreateMemoRelationsInModernBody();

  bool get supportsMemoCreateTimeUpdate => _supportsMemoCreateTimeUpdate();

  Future<Memo> _createMemoModern({
    required String memoId,
    required String content,
    required String visibility,
    required bool pinned,
    MemoLocation? location,
    DateTime? createTime,
    DateTime? displayTime,
    required List<Map<String, dynamic>> relations,
  }) async {
    final supportsLocation = _supportsMemoLocationField();
    final supportsPinned = _supportsPinnedInModernMemoBody();
    final supportsCreateTimestamps =
        _supportsCreateMemoTimestampFieldsInModernBody();
    final supportsCreateRelations = _supportsCreateMemoRelationsInModernBody();
    final resolvedDisplayTime = displayTime ?? createTime;
    final response = await _dio.post(
      'api/v1/memos',
      queryParameters: <String, Object?>{'memoId': memoId},
      data: <String, Object?>{
        'content': content,
        'visibility': visibility,
        if (supportsPinned) 'pinned': pinned,
        if (supportsLocation && location != null) 'location': location.toJson(),
        if (supportsCreateTimestamps && createTime != null)
          'createTime': createTime.toUtc().toIso8601String(),
        if (supportsCreateTimestamps && resolvedDisplayTime != null)
          'displayTime': resolvedDisplayTime.toUtc().toIso8601String(),
        if (supportsCreateRelations && relations.isNotEmpty)
          'relations': relations,
      },
    );
    final memo = _memoFromJson(_expectJsonMap(response.data));
    if (!pinned || supportsPinned) {
      return memo;
    }
    return _setMemoPinnedWithLegacyOrganizer(
      memoUid: memo.uid,
      pinned: true,
      fallbackMemo: memo,
      operation: 'create_memo_pinned_legacy_organizer',
    );
  }

  Future<Memo> updateMemo({
    required String memoUid,
    String? content,
    String? visibility,
    bool? pinned,
    String? state,
    DateTime? createTime,
    DateTime? displayTime,
    Object? location = _unset,
  }) async {
    await _ensureServerHints();
    final canUseLegacyUpdateEndpoint = _legacyMemoUpdateEndpointAllowed();
    if (_useLegacyMemos) {
      if (!canUseLegacyUpdateEndpoint ||
          !_ensureLegacyMemoEndpointAllowed(
            'api/v1/memo',
            operation: 'update_memo_force_legacy',
          )) {
        throw StateError(
          'Legacy memo endpoint is disabled for ${_serverFlavor.name}',
        );
      }
      return _updateMemoLegacy(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        createTime: createTime,
        displayTime: displayTime,
      );
    }
    return _updateMemoModern(
      memoUid: memoUid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTime: createTime,
      displayTime: displayTime,
      location: location,
    );
  }

  Future<Memo> _updateMemoModern({
    required String memoUid,
    String? content,
    String? visibility,
    bool? pinned,
    String? state,
    DateTime? createTime,
    DateTime? displayTime,
    required Object? location,
  }) async {
    final updateMask = <String>[];
    final data = <String, Object?>{'name': 'memos/$memoUid'};
    final supportsPinned = _supportsPinnedInModernMemoBody();
    if (content != null) {
      updateMask.add('content');
      data['content'] = content;
    }
    if (visibility != null) {
      updateMask.add('visibility');
      data['visibility'] = visibility;
    }
    final pinnedNeedsLegacyOrganizer = pinned != null && !supportsPinned;
    if (pinned != null && supportsPinned) {
      updateMask.add('pinned');
      data['pinned'] = pinned;
    }
    if (state != null) {
      final normalizedState = _normalizeLegacyRowStatus(state) ?? state;
      if (_usesRowStatusStateField()) {
        updateMask.add('row_status');
        data['rowStatus'] = _rowStatusStateForUpdate(normalizedState);
      } else {
        updateMask.add('state');
        data['state'] = state;
      }
    }
    if (createTime != null && _supportsMemoCreateTimeUpdate()) {
      updateMask.add('create_time');
      data['createTime'] = createTime.toUtc().toIso8601String();
    }
    if (displayTime != null) {
      updateMask.add(_displayTimeUpdateMaskField());
      data['displayTime'] = displayTime.toUtc().toIso8601String();
    }
    final supportsLocation = _supportsMemoLocationField();
    final locationRequested = !identical(location, _unset);
    if (locationRequested && supportsLocation) {
      updateMask.add('location');
      data['location'] = location == null
          ? null
          : (location as MemoLocation).toJson();
    }
    final droppedUnsupportedLocation = locationRequested && !supportsLocation;
    if (updateMask.isEmpty) {
      if (pinnedNeedsLegacyOrganizer) {
        return _setMemoPinnedWithLegacyOrganizer(
          memoUid: memoUid,
          pinned: pinned,
          operation: 'update_memo_pinned_legacy_organizer',
        );
      }
      if (droppedUnsupportedLocation) {
        return getMemo(memoUid: memoUid);
      }
      throw ArgumentError('updateMemo requires at least one field');
    }

    if (_serverFlavor == _ServerApiFlavor.v0_22) {
      final resolvedDisplayTime = await _resolveGrpcWebV022DisplayTime(
        memoUid: memoUid,
        updateMask: updateMask,
        displayTime: displayTime,
      );
      if (resolvedDisplayTime != null &&
          !updateMask.contains(_displayTimeUpdateMaskField())) {
        updateMask.add(_displayTimeUpdateMaskField());
        data['displayTime'] = resolvedDisplayTime.toUtc().toIso8601String();
      }
      try {
        await _updateMemoModernV022GrpcWeb(
          memoUid: memoUid,
          data: data,
          updateMask: updateMask,
        );
        final memo = await getMemo(memoUid: memoUid);
        if (!pinnedNeedsLegacyOrganizer) {
          return memo;
        }
        return _setMemoPinnedWithLegacyOrganizer(
          memoUid: memoUid,
          pinned: pinned,
          fallbackMemo: memo,
          operation: 'update_memo_pinned_legacy_organizer',
        );
      } on DioException catch (e) {
        if (!_shouldFallbackFromGrpcWebUpdateMemoV022(e)) {
          rethrow;
        }
      }
    }

    final response = await _dio.patch(
      'api/v1/memos/$memoUid',
      queryParameters: <String, Object?>{'updateMask': updateMask.join(',')},
      data: data,
    );
    final memo = _memoFromJson(_expectJsonMap(response.data));
    if (!pinnedNeedsLegacyOrganizer) {
      return memo;
    }
    return _setMemoPinnedWithLegacyOrganizer(
      memoUid: memoUid,
      pinned: pinned,
      fallbackMemo: memo,
      operation: 'update_memo_pinned_legacy_organizer',
    );
  }

  bool _usesRowStatusStateField() {
    return _routeAdapter.usesRowStatusMemoStateField;
  }

  String _rowStatusStateForUpdate(String state) {
    final normalized = state.trim().toUpperCase();
    if (_serverFlavor == _ServerApiFlavor.v0_22 && normalized == 'NORMAL') {
      return 'ACTIVE';
    }
    return normalized;
  }

  String _displayTimeUpdateMaskField() {
    if (_serverFlavor == _ServerApiFlavor.v0_22) {
      return 'display_ts';
    }
    return 'display_time';
  }

  bool _supportsMemoLocationField() {
    return _serverFlavor != _ServerApiFlavor.v0_22 &&
        _serverFlavor != _ServerApiFlavor.v0_21;
  }

  bool _supportsPinnedInModernMemoBody() {
    return _serverFlavor != _ServerApiFlavor.v0_22 &&
        _serverFlavor != _ServerApiFlavor.v0_23;
  }

  bool _supportsCreateMemoTimestampFieldsInModernBody() {
    return _supportsModernCreateMemoBodyFields(
      minimum: const _ServerVersion(0, 26, 0),
    );
  }

  bool _supportsCreateMemoRelationsInModernBody() {
    return _supportsModernCreateMemoBodyFields(
      minimum: const _ServerVersion(0, 26, 0),
    );
  }

  bool _supportsMemoCreateTimeUpdate() {
    return _supportsModernCreateMemoBodyFields(
      minimum: const _ServerVersion(0, 26, 0),
    );
  }

  bool _supportsModernCreateMemoBodyFields({required _ServerVersion minimum}) {
    final version = _serverVersion;
    if (version == null) {
      return false;
    }
    if (version.major > 0) {
      return true;
    }
    return version >= minimum;
  }

  Future<Memo> _setMemoPinnedWithLegacyOrganizer({
    required String memoUid,
    required bool pinned,
    Memo? fallbackMemo,
    required String operation,
  }) async {
    if (memoUid.trim().isEmpty) {
      if (fallbackMemo != null) {
        return _copyMemoWithPinned(fallbackMemo, pinned);
      }
      throw ArgumentError('setMemoPinnedWithLegacyOrganizer requires memoUid');
    }
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo/$memoUid/organizer',
      operation: operation,
    )) {
      if (fallbackMemo != null) {
        return _copyMemoWithPinned(fallbackMemo, pinned);
      }
      throw StateError(
        'Legacy memo organizer endpoint is disabled for ${_serverFlavor.name}',
      );
    }
    try {
      final response = await _dio.post(
        'api/v1/memo/$memoUid/organizer',
        data: <String, Object?>{'pinned': pinned},
      );
      return _memoFromLegacy(_expectJsonMap(response.data));
    } catch (_) {
      if (fallbackMemo != null) {
        return _copyMemoWithPinned(fallbackMemo, pinned);
      }
      rethrow;
    }
  }

  Future<DateTime?> _resolveGrpcWebV022DisplayTime({
    required String memoUid,
    required List<String> updateMask,
    required DateTime? displayTime,
  }) async {
    if (displayTime != null) {
      return displayTime;
    }
    if (_serverFlavor != _ServerApiFlavor.v0_22) {
      return null;
    }
    final needsPrimaryUpdate =
        updateMask.contains('content') ||
        updateMask.contains('visibility') ||
        updateMask.contains('row_status');
    if (!needsPrimaryUpdate) {
      return null;
    }
    try {
      final memo = await getMemo(memoUid: memoUid);
      return memo.displayTime ?? memo.createTime;
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateMemoModernV022GrpcWeb({
    required String memoUid,
    required Map<String, Object?> data,
    required List<String> updateMask,
  }) async {
    final requestMessage = _encodeGrpcWebV022UpdateMemoRequest(
      memoUid: memoUid,
      data: data,
      updateMask: updateMask,
    );
    final response = await _dio.post(
      _kGrpcWebUpdateMemoPath,
      data: _wrapGrpcWebDataFrame(requestMessage),
      options: Options(
        responseType: ResponseType.bytes,
        headers: <String, Object?>{
          'Content-Type': _kGrpcWebContentType,
          'Accept': _kGrpcWebContentType,
          'X-Grpc-Web': '1',
          'X-User-Agent': 'grpc-web-dart',
          'grpc-accept-encoding': 'identity',
          'accept-encoding': 'identity',
        },
      ),
    );

    final responseBytes = _asUint8List(response.data);
    final decoded = _parseGrpcWebResponse(responseBytes);
    final trailerStatus =
        int.tryParse(decoded.trailers['grpc-status'] ?? '') ?? 0;
    if (trailerStatus != 0) {
      throw DioException.badResponse(
        statusCode: _grpcStatusToHttpStatus(trailerStatus),
        requestOptions: response.requestOptions,
        response: Response<dynamic>(
          requestOptions: response.requestOptions,
          statusCode: _grpcStatusToHttpStatus(trailerStatus),
          data:
              decoded.trailers['grpc-message'] ?? 'grpc-web update memo failed',
        ),
      );
    }
  }

  bool _shouldFallbackFromGrpcWebUpdateMemoV022(DioException error) {
    final status = error.response?.statusCode ?? 0;
    if (status == 404 || status == 405 || status == 501) {
      return true;
    }
    final message = [
      error.message ?? '',
      error.error?.toString() ?? '',
      error.response?.data?.toString() ?? '',
    ].join(' | ').toLowerCase();
    return message.contains('unimplemented') ||
        message.contains('not found') ||
        message.contains('unsupported media type');
  }

  Uint8List _encodeGrpcWebV022UpdateMemoRequest({
    required String memoUid,
    required Map<String, Object?> data,
    required List<String> updateMask,
  }) {
    final memoBuffer = BytesBuilder();
    _writeProtoStringField(memoBuffer, 1, 'memos/$memoUid');

    final rowStatus = (data['rowStatus'] ?? '').toString().trim().toUpperCase();
    final rowStatusValue = switch (rowStatus) {
      'ACTIVE' => 1,
      'ARCHIVED' => 2,
      _ => null,
    };
    if (rowStatusValue != null) {
      _writeProtoVarintField(memoBuffer, 3, rowStatusValue);
    }

    final displayTime = _parseOptionalGrpcWebUpdateTime(data['displayTime']);
    if (displayTime != null) {
      final timestampBuffer = BytesBuilder();
      _writeProtoVarintField(
        timestampBuffer,
        1,
        displayTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      );
      _writeProtoMessageField(memoBuffer, 7, timestampBuffer.toBytes());
    }

    final content = data['content'] as String?;
    if (content != null) {
      _writeProtoStringField(memoBuffer, 8, content);
    }

    final visibility = (data['visibility'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final visibilityValue = switch (visibility) {
      'PRIVATE' => 1,
      'PROTECTED' => 2,
      'PUBLIC' => 3,
      _ => null,
    };
    if (visibilityValue != null) {
      _writeProtoVarintField(memoBuffer, 10, visibilityValue);
    }

    final requestBuffer = BytesBuilder();
    _writeProtoMessageField(requestBuffer, 1, memoBuffer.toBytes());

    final fieldMaskBuffer = BytesBuilder();
    for (final path in updateMask) {
      _writeProtoStringField(fieldMaskBuffer, 1, path);
    }
    _writeProtoMessageField(requestBuffer, 2, fieldMaskBuffer.toBytes());
    return requestBuffer.toBytes();
  }

  DateTime? _parseOptionalGrpcWebUpdateTime(Object? raw) {
    if (raw is DateTime) {
      return raw.toUtc();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed == null) return null;
      return parsed.isUtc ? parsed : parsed.toUtc();
    }
    return null;
  }

  void _writeProtoStringField(
    BytesBuilder buffer,
    int fieldNumber,
    String value,
  ) {
    final bytes = utf8.encode(value);
    _writeProtoTag(buffer, fieldNumber, 2);
    _writeProtoVarint(buffer, bytes.length);
    buffer.add(bytes);
  }

  void _writeProtoVarintField(BytesBuilder buffer, int fieldNumber, int value) {
    _writeProtoTag(buffer, fieldNumber, 0);
    _writeProtoVarint(buffer, value);
  }

  void _writeProtoMessageField(
    BytesBuilder buffer,
    int fieldNumber,
    Uint8List value,
  ) {
    _writeProtoTag(buffer, fieldNumber, 2);
    _writeProtoVarint(buffer, value.length);
    buffer.add(value);
  }

  void _writeProtoTag(BytesBuilder buffer, int fieldNumber, int wireType) {
    _writeProtoVarint(buffer, (fieldNumber << 3) | wireType);
  }

  void _writeProtoVarint(BytesBuilder buffer, int value) {
    var current = value;
    while (current >= 0x80) {
      buffer.addByte((current & 0x7F) | 0x80);
      current >>= 7;
    }
    buffer.addByte(current);
  }

  Uint8List _wrapGrpcWebDataFrame(Uint8List message) {
    final buffer = BytesBuilder();
    buffer.addByte(0x00);
    buffer.add(_uint32BigEndian(message.length));
    buffer.add(message);
    return buffer.toBytes();
  }

  Uint8List _uint32BigEndian(int value) {
    return Uint8List.fromList(<int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  Uint8List _asUint8List(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is List) return Uint8List.fromList(data.cast<int>());
    throw const FormatException('Expected binary grpc-web response');
  }

  _GrpcWebDecoded _parseGrpcWebResponse(Uint8List bytes) {
    final message = BytesBuilder();
    final trailers = <String, String>{};
    var offset = 0;
    while (offset + 5 <= bytes.length) {
      final flag = bytes[offset];
      final length =
          (bytes[offset + 1] << 24) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 8) |
          bytes[offset + 4];
      offset += 5;
      if (offset + length > bytes.length) {
        throw const FormatException('Invalid grpc-web frame length');
      }
      final frame = Uint8List.sublistView(bytes, offset, offset + length);
      offset += length;
      if ((flag & 0x80) != 0) {
        final text = utf8.decode(frame, allowMalformed: true);
        for (final line in text.split('\r\n')) {
          if (line.isEmpty) continue;
          final separator = line.indexOf(':');
          if (separator <= 0) continue;
          trailers[line.substring(0, separator).trim().toLowerCase()] = line
              .substring(separator + 1)
              .trim();
        }
      } else {
        message.add(frame);
      }
    }
    return _GrpcWebDecoded(messageBytes: message.toBytes(), trailers: trailers);
  }

  int _grpcStatusToHttpStatus(int grpcStatus) {
    return switch (grpcStatus) {
      3 => 400,
      16 => 401,
      7 => 403,
      5 => 404,
      14 => 503,
      _ => 500,
    };
  }

  String? _mergeLegacyRowStatusFilter({
    required String? filter,
    required String? state,
  }) {
    final normalizedState = _normalizeLegacyRowStatus(state);
    final normalizedFilter = (filter ?? '').trim();
    if (normalizedState == null || normalizedState.isEmpty) {
      return normalizedFilter.isEmpty ? null : normalizedFilter;
    }

    if (RegExp(r'\brow_status\b').hasMatch(normalizedFilter)) {
      return normalizedFilter;
    }

    final rowStatusClause =
        'row_status == "${_escapeLegacyFilterString(normalizedState)}"';
    if (normalizedFilter.isEmpty) {
      return rowStatusClause;
    }
    return '($normalizedFilter) && ($rowStatusClause)';
  }

  Future<void> deleteMemo({required String memoUid, bool force = false}) async {
    await _ensureServerHints();
    final normalized = _normalizeMemoUid(memoUid);
    if (_useLegacyMemos) {
      if (!_ensureLegacyMemoEndpointAllowed(
        'api/v1/memo',
        operation: 'delete_memo_force_legacy',
      )) {
        throw StateError(
          'Legacy memo endpoint is disabled for ${_serverFlavor.name}',
        );
      }
      await _deleteMemoLegacy(memoUid: normalized, force: force);
      return;
    }
    await _deleteMemoModern(memoUid: normalized, force: force);
  }

  Future<void> _deleteMemoModern({
    required String memoUid,
    required bool force,
  }) async {
    await _dio.delete(
      'api/v1/memos/$memoUid',
      queryParameters: <String, Object?>{if (force) 'force': true},
    );
  }

  Future<void> _deleteMemoLegacy({
    required String memoUid,
    required bool force,
  }) async {
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo',
      operation: 'delete_memo_legacy',
    )) {
      throw StateError(
        'Legacy memo endpoint is disabled for ${_serverFlavor.name}',
      );
    }

    await _dio.delete('api/v1/memo/$memoUid');
  }

  Future<void> setMemoRelations({
    required String memoUid,
    required List<Map<String, dynamic>> relations,
  }) async {
    if (_useLegacyMemos) {
      return;
    }
    await _setMemoRelationsModern(memoUid, relations);
  }

  Future<void> _setMemoRelationsModern(
    String memoUid,
    List<Map<String, dynamic>> relations,
  ) async {
    await _dio.patch(
      'api/v1/memos/$memoUid/relations',
      data: <String, Object?>{'name': 'memos/$memoUid', 'relations': relations},
    );
  }

  Future<(List<MemoRelation> relations, String nextPageToken)>
  listMemoRelations({
    required String memoUid,
    int pageSize = 50,
    String? pageToken,
  }) async {
    try {
      final response = await _dio.get(
        'api/v1/memos/$memoUid/relations',
        queryParameters: <String, Object?>{
          if (pageSize > 0) 'pageSize': pageSize,
          if (pageSize > 0) 'page_size': pageSize,
          if (pageToken != null && pageToken.trim().isNotEmpty)
            'pageToken': pageToken,
          if (pageToken != null && pageToken.trim().isNotEmpty)
            'page_token': pageToken,
        },
      );
      final body = _expectJsonMap(response.data);
      final list = body['relations'];
      final relations = <MemoRelation>[];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            relations.add(MemoRelation.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
      final nextToken = _readStringField(
        body,
        'nextPageToken',
        'next_page_token',
      );
      return (relations, nextToken);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) {
        return (const <MemoRelation>[], '');
      }
      rethrow;
    }
  }

  Future<({List<Memo> memos, String nextPageToken, int totalSize})>
  listMemoComments({
    required String memoUid,
    int pageSize = 30,
    String? pageToken,
    String? orderBy,
  }) async {
    if (_useLegacyMemos) {
      return _listMemoCommentsLegacyV2(memoUid: memoUid);
    }
    return _listMemoCommentsModern(
      memoUid: memoUid,
      pageSize: pageSize,
      pageToken: pageToken,
      orderBy: orderBy,
    );
  }

  Future<({List<Memo> memos, String nextPageToken, int totalSize})>
  _listMemoCommentsModern({
    required String memoUid,
    required int pageSize,
    String? pageToken,
    String? orderBy,
  }) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid/comments',
      queryParameters: <String, Object?>{
        if (pageSize > 0) 'pageSize': pageSize,
        if (pageSize > 0) 'page_size': pageSize,
        if (pageToken != null && pageToken.trim().isNotEmpty)
          'pageToken': pageToken,
        if (pageToken != null && pageToken.trim().isNotEmpty)
          'page_token': pageToken,
        if (orderBy != null && orderBy.trim().isNotEmpty)
          'orderBy': orderBy.trim(),
        if (orderBy != null && orderBy.trim().isNotEmpty)
          'order_by': orderBy.trim(),
      },
    );
    final body = _expectJsonMap(response.data);
    final list = body['memos'];
    final memos = <Memo>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          memos.add(_memoFromJson(item.cast<String, dynamic>()));
        }
      }
    }
    final nextToken = _readStringField(
      body,
      'nextPageToken',
      'next_page_token',
    );
    var totalSize = 0;
    final totalRaw = body['totalSize'] ?? body['total_size'];
    if (totalRaw is num) {
      totalSize = totalRaw.toInt();
    } else if (totalRaw is String) {
      totalSize = int.tryParse(totalRaw) ?? memos.length;
    } else {
      totalSize = memos.length;
    }
    return (memos: memos, nextPageToken: nextToken, totalSize: totalSize);
  }

  Future<({List<Memo> memos, String nextPageToken, int totalSize})>
  _listMemoCommentsLegacyV2({required String memoUid}) async {
    final response = await _dio.get('api/v2/memos/$memoUid/comments');
    final body = _expectJsonMap(response.data);
    final list = body['memos'];
    final memos = <Memo>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          memos.add(_memoFromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return (memos: memos, nextPageToken: '', totalSize: memos.length);
  }

  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})>
  listMemoReactions({
    required String memoUid,
    int pageSize = 50,
    String? pageToken,
  }) async {
    if (_useLegacyMemos) {
      return _listMemoReactionsLegacyV2(memoUid: memoUid);
    }
    return _listMemoReactionsModern(
      memoUid: memoUid,
      pageSize: pageSize,
      pageToken: pageToken,
    );
  }

  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})>
  _listMemoReactionsModern({
    required String memoUid,
    required int pageSize,
    String? pageToken,
  }) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid/reactions',
      queryParameters: <String, Object?>{
        if (pageSize > 0) 'pageSize': pageSize,
        if (pageSize > 0) 'page_size': pageSize,
        if (pageToken != null && pageToken.trim().isNotEmpty)
          'pageToken': pageToken,
        if (pageToken != null && pageToken.trim().isNotEmpty)
          'page_token': pageToken,
      },
    );
    final body = _expectJsonMap(response.data);
    final list = body['reactions'];
    final reactions = <Reaction>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          reactions.add(Reaction.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    final nextToken = _readStringField(
      body,
      'nextPageToken',
      'next_page_token',
    );
    var totalSize = 0;
    final totalRaw = body['totalSize'] ?? body['total_size'];
    if (totalRaw is num) {
      totalSize = totalRaw.toInt();
    } else if (totalRaw is String) {
      totalSize = int.tryParse(totalRaw) ?? reactions.length;
    } else {
      totalSize = reactions.length;
    }
    return (
      reactions: reactions,
      nextPageToken: nextToken,
      totalSize: totalSize,
    );
  }

  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})>
  _listMemoReactionsLegacyV2({required String memoUid}) async {
    final response = await _dio.get('api/v2/memos/$memoUid/reactions');
    final body = _expectJsonMap(response.data);
    final list = body['reactions'];
    final reactions = <Reaction>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          reactions.add(Reaction.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return (
      reactions: reactions,
      nextPageToken: '',
      totalSize: reactions.length,
    );
  }

  Future<Reaction> upsertMemoReaction({
    required String memoUid,
    required String reactionType,
  }) async {
    if (_useLegacyMemos) {
      return _upsertMemoReactionLegacyV2(
        memoUid: memoUid,
        reactionType: reactionType,
      );
    }
    return _upsertMemoReactionModern(
      memoUid: memoUid,
      reactionType: reactionType,
    );
  }

  Future<Reaction> _upsertMemoReactionModern({
    required String memoUid,
    required String reactionType,
  }) async {
    final name = 'memos/$memoUid';
    final response = await _dio.post(
      'api/v1/memos/$memoUid/reactions',
      data: <String, Object?>{
        'name': name,
        'reaction': <String, Object?>{
          'contentId': name,
          'reactionType': reactionType,
        },
      },
    );
    return Reaction.fromJson(_expectJsonMap(response.data));
  }

  Future<Reaction> _upsertMemoReactionLegacyV2({
    required String memoUid,
    required String reactionType,
  }) async {
    final normalizedType = _normalizeLegacyReactionType(reactionType);
    final response = await _dio.post(
      'api/v2/memos/$memoUid/reactions',
      queryParameters: <String, Object?>{
        'reaction.contentId': 'memos/$memoUid',
        'reaction.reactionType': normalizedType,
      },
    );
    final body = _expectJsonMap(response.data);
    final reactionJson = body['reaction'];
    if (reactionJson is Map) {
      return Reaction.fromJson(reactionJson.cast<String, dynamic>());
    }
    return Reaction.fromJson(body);
  }

  Future<void> deleteMemoReaction({required Reaction reaction}) async {
    final rawName = reaction.name.trim();
    final contentId = reaction.contentId.trim();
    final parsedId = _parseReactionIdFromName(rawName);
    final legacyId = reaction.legacyId ?? parsedId;
    final normalizedName = _normalizeReactionName(rawName, contentId, parsedId);

    if (_useLegacyMemos) {
      if (legacyId == null || legacyId <= 0) {
        throw ArgumentError('deleteMemoReaction requires legacy id');
      }
      await _deleteMemoReactionLegacyV2(reactionId: legacyId);
      return;
    }

    if (normalizedName != null && normalizedName.isNotEmpty) {
      await _deleteMemoReactionModern(name: normalizedName);
      return;
    }

    if (legacyId != null && legacyId > 0) {
      await _deleteMemoReactionLegacyV1(reactionId: legacyId);
      return;
    }

    throw ArgumentError(
      'deleteMemoReaction requires reaction name or legacy id',
    );
  }

  int? _parseReactionIdFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('/');
    if (parts.isEmpty) return null;
    final last = parts.last.trim();
    if (last.isEmpty) return null;
    return int.tryParse(last);
  }

  String? _normalizeReactionName(String name, String contentId, int? parsedId) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('memos/')) {
      final segments = trimmed.split('/');
      if (segments.length >= 4) {
        return trimmed;
      }
    }
    final reactionId = parsedId ?? _parseReactionIdFromName(trimmed);
    if (reactionId == null) return trimmed;
    if (contentId.startsWith('memos/')) {
      return '$contentId/reactions/$reactionId';
    }
    return trimmed;
  }

  Future<void> _deleteMemoReactionModern({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('deleteMemoReaction requires name');
    }
    final path =
        (trimmed.startsWith('memos/') || trimmed.startsWith('reactions/'))
        ? 'api/v1/$trimmed'
        : 'api/v1/memos/$trimmed';
    await _dio.delete(path);
  }

  Future<void> _deleteMemoReactionLegacyV1({required int reactionId}) async {
    if (reactionId <= 0) {
      throw ArgumentError('deleteMemoReaction requires legacy id');
    }
    await _dio.delete('api/v1/reactions/$reactionId');
  }

  Future<void> _deleteMemoReactionLegacyV2({required int reactionId}) async {
    if (reactionId <= 0) {
      throw ArgumentError('deleteMemoReaction requires legacy id');
    }
    await _dio.delete('api/v2/reactions/$reactionId');
  }

  Future<Memo> createMemoComment({
    required String memoUid,
    required String content,
    String visibility = 'PUBLIC',
  }) async {
    if (_useLegacyMemos) {
      return _createMemoCommentLegacyV2(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
      );
    }
    return _createMemoCommentModern(
      memoUid: memoUid,
      content: content,
      visibility: visibility,
    );
  }

  Future<Memo> _createMemoCommentModern({
    required String memoUid,
    required String content,
    required String visibility,
  }) async {
    final response = await _dio.post(
      'api/v1/memos/$memoUid/comments',
      data: <String, Object?>{'content': content, 'visibility': visibility},
    );
    return _memoFromJson(_expectJsonMap(response.data));
  }

  Future<Memo> _createMemoCommentLegacyV2({
    required String memoUid,
    required String content,
    required String visibility,
  }) async {
    final response = await _dio.post(
      'api/v2/memos/$memoUid/comments',
      queryParameters: <String, Object?>{
        'comment.content': content,
        'comment.visibility': visibility,
      },
    );
    final body = _expectJsonMap(response.data);
    final memoJson = body['memo'];
    if (memoJson is Map) {
      return _memoFromJson(memoJson.cast<String, dynamic>());
    }
    return _memoFromJson(body);
  }

  Future<(List<Memo> memos, String nextPageToken)> _listMemosLegacy({
    required int pageSize,
    String? pageToken,
    String? state,
    String? filter,
  }) async {
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo',
      operation: 'list_memos_legacy',
    )) {
      throw StateError(
        'Legacy memo endpoint is blocked for server flavor ${_serverFlavor.name}',
      );
    }
    final normalizedToken = (pageToken ?? '').trim();
    final offset = int.tryParse(normalizedToken) ?? 0;
    final limit = pageSize > 0 ? pageSize : 0;
    final rowStatus = _normalizeLegacyRowStatus(state);
    final creatorId = _tryParseLegacyCreatorId(filter);
    final response = await _dio.get(
      'api/v1/memo',
      queryParameters: <String, Object?>{
        if (rowStatus != null) 'rowStatus': rowStatus,
        if (creatorId != null) 'creatorId': creatorId,
        if (limit > 0) 'limit': limit,
        if (offset > 0) 'offset': offset,
      },
    );

    final list = _readListPayload(response.data);
    final memos = <Memo>[];
    for (final item in list) {
      if (item is Map) {
        memos.add(_memoFromLegacy(item.cast<String, dynamic>()));
      }
    }
    if (limit <= 0) {
      return (memos, '');
    }
    if (memos.isEmpty) {
      return (memos, '');
    }
    final nextOffset = offset + memos.length;
    return (memos, nextOffset.toString());
  }

  Future<List<Memo>> searchMemosLegacyV2({
    required String searchQuery,
    int? creatorId,
    String? state,
    String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    int limit = 10,
  }) async {
    await _ensureServerHints();
    final filter = _buildLegacyV2SearchFilter(
      searchQuery: searchQuery,
      creatorId: creatorId,
      state: state,
      tag: tag,
      startTimeSec: startTimeSec,
      endTimeSecExclusive: endTimeSecExclusive,
      limit: limit,
    );
    if (filter == null) {
      return const <Memo>[];
    }

    final response = await _dio.get(
      'api/v2/memos:search',
      queryParameters: <String, Object?>{'filter': filter},
    );
    final body = _expectJsonMap(response.data);
    final list = body['memos'];
    final memos = <Memo>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          memos.add(_memoFromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return memos;
  }

  Future<Memo> _createMemoLegacy({
    required String memoId,
    required String content,
    required String visibility,
    required bool pinned,
  }) async {
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo',
      operation: 'create_memo_legacy',
    )) {
      throw StateError(
        'Legacy memo endpoint is blocked for server flavor ${_serverFlavor.name}',
      );
    }
    final _ = memoId;
    final response = await _dio.post(
      'api/v1/memo',
      data: <String, Object?>{'content': content, 'visibility': visibility},
    );
    var memo = _memoFromLegacy(_expectJsonMap(response.data));
    if (!pinned) return memo;

    final memoUid = memo.uid;
    if (memoUid.isEmpty) {
      return _copyMemoWithPinned(memo, true);
    }

    try {
      final pinResponse = await _dio.post(
        'api/v1/memo/$memoUid/organizer',
        data: const <String, Object?>{'pinned': true},
      );
      memo = _memoFromLegacy(_expectJsonMap(pinResponse.data));
      return memo;
    } catch (_) {
      return _copyMemoWithPinned(memo, true);
    }
  }

  Future<Memo> _updateMemoLegacy({
    required String memoUid,
    String? content,
    String? visibility,
    bool? pinned,
    String? state,
    DateTime? createTime,
    DateTime? displayTime,
  }) async {
    if (!_supportsLegacyMemoUpdateEndpoint()) {
      throw StateError(
        'Legacy memo update endpoint is blocked for server flavor ${_serverFlavor.name}',
      );
    }
    if (!_ensureLegacyMemoEndpointAllowed(
      'api/v1/memo',
      operation: 'update_memo_legacy',
    )) {
      throw StateError(
        'Legacy memo endpoint is blocked for server flavor ${_serverFlavor.name}',
      );
    }
    final _ = (createTime, displayTime);
    if (pinned != null) {
      await _dio.post(
        'api/v1/memo/$memoUid/organizer',
        data: <String, Object?>{'pinned': pinned},
      );
    }

    final data = <String, Object?>{
      'id': _legacyMemoIdValue(memoUid),
      if (content != null) 'content': content,
      if (visibility != null) 'visibility': visibility,
      if (state != null) 'rowStatus': _normalizeLegacyRowStatus(state) ?? state,
    };

    if (data.length == 1) {
      return _legacyPlaceholderMemo(memoUid, pinned: pinned ?? false);
    }

    final response = await _dio.patch('api/v1/memo/$memoUid', data: data);
    return _memoFromLegacy(_expectJsonMap(response.data));
  }

  Memo _memoFromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    final stateRaw = _readString(
      normalized['state'] ??
          normalized['rowStatus'] ??
          normalized['row_status'],
    );
    final state = _normalizeLegacyRowStatus(stateRaw);
    if (state != null && state.isNotEmpty) {
      normalized['state'] = state;
    }
    final memo = Memo.fromJson(normalized);
    return _normalizeMemoForServer(memo);
  }

  Memo _normalizeMemoForServer(Memo memo) {
    if (_serverFlavor != _ServerApiFlavor.v0_22) return memo;
    final normalizedAttachments = _normalizeAttachmentsForServer(
      memo.attachments,
    );
    if (identical(normalizedAttachments, memo.attachments)) return memo;
    return Memo(
      name: memo.name,
      creator: memo.creator,
      content: memo.content,
      contentFingerprint: memo.contentFingerprint,
      visibility: memo.visibility,
      pinned: memo.pinned,
      state: memo.state,
      createTime: memo.createTime,
      updateTime: memo.updateTime,
      tags: memo.tags,
      attachments: normalizedAttachments,
      displayTime: memo.displayTime,
      location: memo.location,
      relations: memo.relations,
      reactions: memo.reactions,
    );
  }
}

class _GrpcWebDecoded {
  const _GrpcWebDecoded({required this.messageBytes, required this.trailers});

  final Uint8List messageBytes;
  final Map<String, String> trailers;
}
