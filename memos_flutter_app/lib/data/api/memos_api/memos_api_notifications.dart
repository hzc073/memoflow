part of '../memos_api.dart';

mixin _MemosApiNotifications on _MemosApiBase, _MemosApiAuth {
  Future<(List<AppNotification> notifications, String nextPageToken)>
  listNotifications({
    int pageSize = 50,
    String? pageToken,
    String? userName,
    String? filter,
  }) async {
    await _ensureServerHints();
    final mode =
        _notificationMode ??
        _capabilities.defaultNotificationMode ??
        _NotificationApiMode.modern;
    _notificationMode = mode;
    switch (mode) {
      case _NotificationApiMode.modern:
        return _listNotificationsModern(
          pageSize: pageSize,
          pageToken: pageToken,
          userName: userName,
          filter: filter,
        );
      case _NotificationApiMode.legacyV1:
        return _listNotificationsLegacyV1(
          pageSize: pageSize,
          pageToken: pageToken,
        );
      case _NotificationApiMode.legacyV2:
        return _listNotificationsLegacyV2(
          pageSize: pageSize,
          pageToken: pageToken,
        );
    }
  }

  Future<(List<AppNotification> notifications, String nextPageToken)>
  _listNotificationsModern({
    required int pageSize,
    String? pageToken,
    String? userName,
    String? filter,
  }) async {
    final parent = await _resolveNotificationParent(userName);
    final normalizedToken = (pageToken ?? '').trim();
    final normalizedFilter = (filter ?? '').trim();
    if (normalizedToken.isEmpty) {
      _notificationRefsById.clear();
    }

    final response = await _dio.get(
      'api/v1/$parent/notifications',
      queryParameters: <String, Object?>{
        if (pageSize > 0) 'pageSize': pageSize,
        if (pageSize > 0) 'page_size': pageSize,
        if (normalizedToken.isNotEmpty) 'pageToken': normalizedToken,
        if (normalizedToken.isNotEmpty) 'page_token': normalizedToken,
        if (normalizedFilter.isNotEmpty) 'filter': normalizedFilter,
      },
    );

    final body = _expectJsonMap(response.data);
    final list = body['notifications'];
    final notifications = <AppNotification>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final notification = AppNotification.fromModernJson(
            item.cast<String, dynamic>(),
          );
          notifications.add(notification);
          _cacheModernNotificationRefs(
            notification: notification,
            json: item.cast<String, dynamic>(),
          );
        }
      }
    }
    final nextToken = _readStringField(
      body,
      'nextPageToken',
      'next_page_token',
    );
    return (notifications, nextToken);
  }

  Future<(List<AppNotification> notifications, String nextPageToken)>
  _listNotificationsLegacyV1({required int pageSize, String? pageToken}) async {
    final normalizedToken = (pageToken ?? '').trim();
    final response = await _dio.get(
      'api/v1/inboxes',
      queryParameters: <String, Object?>{
        if (pageSize > 0) 'pageSize': pageSize,
        if (pageSize > 0) 'page_size': pageSize,
        if (normalizedToken.isNotEmpty) 'pageToken': normalizedToken,
        if (normalizedToken.isNotEmpty) 'page_token': normalizedToken,
      },
    );

    final body = _expectJsonMap(response.data);
    final list = body['inboxes'];
    final notifications = <AppNotification>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          notifications.add(
            AppNotification.fromLegacyJson(item.cast<String, dynamic>()),
          );
        }
      }
    }
    final nextToken = _readStringField(
      body,
      'nextPageToken',
      'next_page_token',
    );
    return (notifications, nextToken);
  }

  Future<(List<AppNotification> notifications, String nextPageToken)>
  _listNotificationsLegacyV2({required int pageSize, String? pageToken}) async {
    final normalizedToken = (pageToken ?? '').trim();
    final response = await _dio.get(
      'api/v2/inboxes',
      queryParameters: <String, Object?>{
        if (pageSize > 0) 'pageSize': pageSize,
        if (pageSize > 0) 'page_size': pageSize,
        if (normalizedToken.isNotEmpty) 'pageToken': normalizedToken,
        if (normalizedToken.isNotEmpty) 'page_token': normalizedToken,
      },
    );

    final body = _expectJsonMap(response.data);
    final list = body['inboxes'];
    final notifications = <AppNotification>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          notifications.add(
            AppNotification.fromLegacyJson(item.cast<String, dynamic>()),
          );
        }
      }
    }
    final nextToken = _readStringField(
      body,
      'nextPageToken',
      'next_page_token',
    );
    return (notifications, nextToken);
  }

  Future<void> updateNotificationStatus({
    required String name,
    required String status,
    required NotificationSource source,
  }) async {
    final trimmedName = name.trim();
    final trimmedStatus = status.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('updateNotificationStatus requires name');
    }
    if (trimmedStatus.isEmpty) {
      throw ArgumentError('updateNotificationStatus requires status');
    }

    if (source == NotificationSource.legacy) {
      await _updateInboxStatus(name: trimmedName, status: trimmedStatus);
      return;
    }
    await _updateUserNotificationStatus(
      name: trimmedName,
      status: trimmedStatus,
    );
  }

  Future<void> deleteNotification({
    required String name,
    required NotificationSource source,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('deleteNotification requires name');
    }
    if (source == NotificationSource.legacy) {
      await _dio.delete('${_legacyInboxBasePath()}/$trimmedName');
      return;
    }
    await _dio.delete('api/v1/$trimmedName');
  }

  Future<void> _updateUserNotificationStatus({
    required String name,
    required String status,
  }) async {
    await _dio.patch(
      'api/v1/$name',
      queryParameters: const <String, Object?>{
        'updateMask': 'status',
        'update_mask': 'status',
      },
      data: <String, Object?>{'name': name, 'status': status},
    );
  }

  Future<void> _updateInboxStatus({
    required String name,
    required String status,
  }) async {
    await _dio.patch(
      '${_legacyInboxBasePath()}/$name',
      queryParameters: const <String, Object?>{
        'updateMask': 'status',
        'update_mask': 'status',
      },
      data: <String, Object?>{'name': name, 'status': status},
    );
  }

  String _legacyInboxBasePath() {
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return 'api/v2';
    }
    return 'api/v1';
  }

  Future<String> _resolveNotificationParent(String? userName) async {
    final raw = (userName ?? '').trim();
    if (_usesUsernameUserResourceNames()) {
      return _resolveUserName(userName: raw.isEmpty ? null : raw);
    }
    if (raw.isEmpty) {
      return _resolveUserName();
    }
    if (raw.startsWith('users/')) return raw;
    final numeric = _tryExtractNumericUserId(raw);
    if (numeric != null) return 'users/$numeric';
    try {
      final resolved = await getUser(name: raw);
      if (resolved.name.trim().isNotEmpty) return resolved.name;
    } catch (_) {}
    return raw;
  }

  Future<({String commentMemoUid, String relatedMemoUid})>
  getMemoCommentActivityRefs({required int activityId}) async {
    await _ensureServerHints();
    if (activityId <= 0) {
      return (commentMemoUid: '', relatedMemoUid: '');
    }

    final cachedRefs = _notificationRefsById[activityId];
    if (cachedRefs != null &&
        (cachedRefs.commentMemoUid.isNotEmpty ||
            cachedRefs.relatedMemoUid.isNotEmpty)) {
      return cachedRefs;
    }

    final activity = _serverFlavor == _ServerApiFlavor.v0_21
        ? await _getActivityLegacyV2(activityId)
        : await _getActivityModern(activityId);
    return _extractMemoCommentRefs(activity);
  }

  void _cacheModernNotificationRefs({
    required AppNotification notification,
    required Map<String, dynamic> json,
  }) {
    final notificationId = notification.activityId;
    if (notificationId == null || notificationId <= 0) {
      return;
    }
    final refs = _extractNotificationRefs(json);
    if (refs.commentMemoUid.isEmpty && refs.relatedMemoUid.isEmpty) {
      return;
    }
    _notificationRefsById[notificationId] = refs;
  }

  ({String commentMemoUid, String relatedMemoUid}) _extractNotificationRefs(
    Map<String, dynamic> json,
  ) {
    final memoComment = _readMap(json['memoComment'] ?? json['memo_comment']);
    if (memoComment != null) {
      return _extractMemoRefsFromPayload(memoComment);
    }

    final memoMention = _readMap(json['memoMention'] ?? json['memo_mention']);
    if (memoMention != null) {
      return _extractMemoRefsFromPayload(memoMention);
    }

    return (commentMemoUid: '', relatedMemoUid: '');
  }

  ({String commentMemoUid, String relatedMemoUid}) _extractMemoRefsFromPayload(
    Map<String, dynamic> payload,
  ) {
    final memoName = _readString(
      payload['memo'] ?? payload['memoName'] ?? payload['memo_name'],
    );
    final relatedMemoName = _readString(
      payload['relatedMemo'] ??
          payload['relatedMemoName'] ??
          payload['related_memo'] ??
          payload['related_memo_name'],
    );

    return (
      commentMemoUid: _normalizeMemoUid(memoName),
      relatedMemoUid: _normalizeMemoUid(relatedMemoName),
    );
  }

  Future<Map<String, dynamic>> _getActivityModern(int activityId) async {
    final response = await _dio.get('api/v1/activities/$activityId');
    return _expectJsonMap(response.data);
  }

  Future<Map<String, dynamic>> _getActivityLegacyV2(int activityId) async {
    final response = await _dio.get('v2/activities/$activityId');
    final body = _expectJsonMap(response.data);
    final activity = _readMap(body['activity']);
    return activity ?? body;
  }

  ({String commentMemoUid, String relatedMemoUid}) _extractMemoCommentRefs(
    Map<String, dynamic> activity,
  ) {
    final payload = _readMap(activity['payload']);
    final memoComment = _readMap(
      payload?['memoComment'] ?? payload?['memo_comment'],
    );
    if (memoComment == null) {
      return (commentMemoUid: '', relatedMemoUid: '');
    }

    final commentName = _readString(
      memoComment['memo'] ??
          memoComment['memoName'] ??
          memoComment['memo_name'],
    );
    final relatedName = _readString(
      memoComment['relatedMemo'] ??
          memoComment['relatedMemoName'] ??
          memoComment['related_memo'] ??
          memoComment['related_memo_name'],
    );
    final commentId = _readInt(memoComment['memoId'] ?? memoComment['memo_id']);
    final relatedId = _readInt(
      memoComment['relatedMemoId'] ?? memoComment['related_memo_id'],
    );

    final commentUid = _normalizeMemoUid(
      commentName.isNotEmpty
          ? commentName
          : (commentId > 0 ? 'memos/$commentId' : ''),
    );
    final relatedUid = _normalizeMemoUid(
      relatedName.isNotEmpty
          ? relatedName
          : (relatedId > 0 ? 'memos/$relatedId' : ''),
    );

    return (commentMemoUid: commentUid, relatedMemoUid: relatedUid);
  }
}
