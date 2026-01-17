import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/url.dart';
import '../logs/breadcrumb_store.dart';
import '../logs/network_log_buffer.dart';
import '../logs/network_log_interceptor.dart';
import '../logs/network_log_store.dart';
import '../models/attachment.dart';
import '../models/instance_profile.dart';
import '../models/memo.dart';
import '../models/notification_item.dart';
import '../models/personal_access_token.dart';
import '../models/user.dart';

class MemosApi {
  MemosApi._(
    this._dio, {
    this.useLegacyApi = false,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
  }) {
    if (logStore != null) {
      _dio.interceptors.add(
        NetworkLogInterceptor(
          logStore,
          buffer: logBuffer,
          breadcrumbStore: breadcrumbStore,
        ),
      );
    }
  }

  final Dio _dio;
  final bool useLegacyApi;

  factory MemosApi.unauthenticated(
    Uri baseUrl, {
    bool useLegacyApi = false,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
  }) {
    return MemosApi._(
      Dio(
        BaseOptions(
          baseUrl: dioBaseUrlString(baseUrl),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ),
      useLegacyApi: useLegacyApi,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
    );
  }

  factory MemosApi.authenticated({
    required Uri baseUrl,
    required String personalAccessToken,
    bool useLegacyApi = false,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: dioBaseUrlString(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, Object?>{
          'Authorization': 'Bearer $personalAccessToken',
        },
      ),
    );
    return MemosApi._(
      dio,
      useLegacyApi: useLegacyApi,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
    );
  }

  Future<InstanceProfile> getInstanceProfile() async {
    final response = await _dio.get('api/v1/instance/profile');
    return InstanceProfile.fromJson(_expectJsonMap(response.data));
  }

  Future<User> getCurrentUser() async {
    DioException? lastDio;
    for (final attempt in <Future<User> Function()>[
      _getCurrentUserByAuthMe,
      _getCurrentUserByAuthStatusPost,
      _getCurrentUserByAuthStatusGet,
      _getCurrentUserBySessionCurrent,
      _getCurrentUserByUserMeV1,
      _getCurrentUserByUsersMeV1,
      _getCurrentUserByUserMeLegacy,
    ]) {
      try {
        return await attempt();
      } on DioException catch (e) {
        lastDio = e;
        if (!_shouldFallback(e)) rethrow;
      }
    }

    if (lastDio != null) throw lastDio;
    throw StateError('Unable to determine current user');
  }

  static bool _shouldFallback(DioException e) {
    final status = e.response?.statusCode ?? 0;
    return status == 404 || status == 405;
  }

  static bool _shouldFallbackLegacy(DioException e) {
    final status = e.response?.statusCode ?? 0;
    return status == 404 || status == 405;
  }

  Future<User> _getCurrentUserByAuthMe() async {
    final response = await _dio.get('api/v1/auth/me');
    final body = _expectJsonMap(response.data);
    final userJson = body['user'];
    if (userJson is Map) {
      return User.fromJson(userJson.cast<String, dynamic>());
    }
    // Some implementations return the user as the top-level payload.
    return User.fromJson(body);
  }

  Future<User> _getCurrentUserBySessionCurrent() async {
    final response = await _dio.get('api/v1/auth/sessions/current');
    final body = _expectJsonMap(response.data);
    final userJson = body['user'];
    if (userJson is Map) {
      return User.fromJson(userJson.cast<String, dynamic>());
    }
    // Some implementations return the user as the top-level payload.
    return User.fromJson(body);
  }

  Future<User> _getCurrentUserByAuthStatusPost() async {
    final response = await _dio.post('api/v1/auth/status', data: const <String, Object?>{});
    final body = _expectJsonMap(response.data);
    final userJson = body['user'];
    if (userJson is Map) {
      return User.fromJson(userJson.cast<String, dynamic>());
    }
    // Some implementations return the user as the top-level payload.
    return User.fromJson(body);
  }

  Future<User> _getCurrentUserByAuthStatusGet() async {
    final response = await _dio.get('api/v1/auth/status');
    final body = _expectJsonMap(response.data);
    final userJson = body['user'];
    if (userJson is Map) {
      return User.fromJson(userJson.cast<String, dynamic>());
    }
    return User.fromJson(body);
  }

  Future<User> _getCurrentUserByUserMeV1() async {
    final response = await _dio.get('api/v1/user/me');
    return User.fromJson(_expectJsonMap(response.data));
  }

  Future<User> _getCurrentUserByUsersMeV1() async {
    final response = await _dio.get('api/v1/users/me');
    final body = _expectJsonMap(response.data);
    final userJson = body['user'];
    if (userJson is Map) {
      return User.fromJson(userJson.cast<String, dynamic>());
    }
    return User.fromJson(body);
  }

  Future<User> _getCurrentUserByUserMeLegacy() async {
    final response = await _dio.get('api/user/me');
    return User.fromJson(_expectJsonMap(response.data));
  }

  Future<User> getUser({required String name}) async {
    final raw = name.trim();
    if (raw.isEmpty) {
      throw ArgumentError('getUser requires name');
    }

    final normalized = raw.startsWith('users/') ? raw : 'users/$raw';
    final response = await _dio.get('api/v1/$normalized');
    final body = _expectJsonMap(response.data);
    final userJson = body['user'];
    if (userJson is Map) {
      return User.fromJson(userJson.cast<String, dynamic>());
    }
    return User.fromJson(body);
  }

  static String? _tryExtractNumericUserId(String userNameOrId) {
    final raw = userNameOrId.trim();
    if (raw.isEmpty) return null;
    final last = raw.contains('/') ? raw.split('/').last : raw;
    final id = int.tryParse(last.trim());
    if (id == null) return null;
    return id.toString();
  }

  Future<String> _resolveNumericUserId({String? userName}) async {
    String effectiveUserName = (userName ?? '').trim();
    String? numericUserId = _tryExtractNumericUserId(effectiveUserName);

    Future<void> resolveFromUserName() async {
      if (numericUserId != null) return;
      if (effectiveUserName.isEmpty) return;

      final identifier = effectiveUserName.contains('/') ? effectiveUserName.split('/').last.trim() : effectiveUserName;
      if (identifier.isEmpty) return;

      try {
        final resolved = await getUser(name: identifier);
        numericUserId = _tryExtractNumericUserId(resolved.name);
      } catch (_) {
        // Ignore and fallback to other strategies.
      }
    }

    Future<void> resolveFromCurrentUser() async {
      if (numericUserId != null) return;

      final currentUser = await getCurrentUser();
      effectiveUserName = currentUser.name.trim();
      numericUserId = _tryExtractNumericUserId(effectiveUserName);
      if (numericUserId != null) return;

      final username = currentUser.username.trim();
      if (username.isEmpty) return;
      try {
        final resolved = await getUser(name: username);
        numericUserId = _tryExtractNumericUserId(resolved.name);
      } catch (_) {}
    }

    await resolveFromUserName();
    await resolveFromCurrentUser();
    if (numericUserId == null) {
      throw FormatException('Unable to determine numeric user id from "$effectiveUserName"');
    }
    return numericUserId!;
  }

  Future<({PersonalAccessToken personalAccessToken, String token})> createPersonalAccessToken({
    String? userName,
    required String description,
    required int expiresInDays,
  }) async {
    try {
      return await _createPersonalAccessTokenModern(
        userName: userName,
        description: description,
        expiresInDays: expiresInDays,
      );
    } on DioException catch (e) {
      if (useLegacyApi && _shouldFallbackLegacy(e)) {
        throw UnsupportedError('Legacy API does not support personal access tokens');
      }
      rethrow;
    }
  }

  Future<({PersonalAccessToken personalAccessToken, String token})> _createPersonalAccessTokenModern({
    String? userName,
    required String description,
    required int expiresInDays,
  }) async {
    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) {
      throw ArgumentError('createPersonalAccessToken requires description');
    }

    final numericUserId = await _resolveNumericUserId(userName: userName);

    final parent = 'users/$numericUserId';
    final path = 'api/v1/$parent/personalAccessTokens';

    String extractToken(Map<String, dynamic> body) {
      final tokenValue = body['token'] ?? body['accessToken'];
      final String? token;
      if (tokenValue is String) {
        token = tokenValue.trim();
      } else if (tokenValue != null) {
        token = tokenValue.toString().trim();
      } else {
        token = null;
      }
      if (token == null || token.isEmpty || token == 'null') {
        throw const FormatException('Token missing in response');
      }
      return token;
    }

    String tryExtractErrorMessage(DioException e) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'] ?? data['detail'];
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
      return '';
    }

    Future<({PersonalAccessToken personalAccessToken, String token})> request({
      required bool includeParent,
      required bool useSnakeCaseExpires,
      required bool includeExpires,
    }) async {
      final data = <String, Object?>{
        if (includeParent) 'parent': parent,
        'description': trimmedDescription,
        if (includeExpires) (useSnakeCaseExpires ? 'expires_in_days' : 'expiresInDays'): expiresInDays,
      };
      final response = await _dio.post(
        path,
        data: data,
      );
      final body = _expectJsonMap(response.data);
      final token = extractToken(body);

      final patJson = body['personalAccessToken'] ?? body['personal_access_token'];
      final personalAccessToken = patJson is Map
          ? PersonalAccessToken.fromJson(patJson.cast<String, dynamic>())
          : PersonalAccessToken(
              name: '',
              description: trimmedDescription,
              createdAt: null,
              expiresAt: null,
              lastUsedAt: null,
            );
      return (personalAccessToken: personalAccessToken, token: token);
    }

    final expiresOptional = expiresInDays == 0;

    try {
      return await request(includeParent: true, useSnakeCaseExpires: false, includeExpires: true);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 400) rethrow;

      final message = tryExtractErrorMessage(e);
      final unknownExpires = message.contains('expiresInDays') && message.toLowerCase().contains('unknown');

      if (expiresOptional) {
        try {
          return await request(includeParent: true, useSnakeCaseExpires: false, includeExpires: false);
        } on DioException catch (_) {}
      }

      if (unknownExpires) {
        try {
          return await request(includeParent: true, useSnakeCaseExpires: true, includeExpires: true);
        } on DioException catch (_) {}
      }

      try {
        return await request(includeParent: false, useSnakeCaseExpires: false, includeExpires: true);
      } on DioException catch (_) {}

      if (unknownExpires) {
        return await request(includeParent: false, useSnakeCaseExpires: true, includeExpires: true);
      }
      rethrow;
    }
  }

  Future<List<PersonalAccessToken>> listPersonalAccessTokens({String? userName}) async {
    try {
      return await _listPersonalAccessTokensModern(userName: userName);
    } on DioException catch (e) {
      if (useLegacyApi && _shouldFallbackLegacy(e)) {
        throw UnsupportedError('Legacy API does not support personal access tokens');
      }
      rethrow;
    }
  }

  Future<List<PersonalAccessToken>> _listPersonalAccessTokensModern({String? userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final parent = 'users/$numericUserId';

    final response = await _dio.get(
      'api/v1/$parent/personalAccessTokens',
      queryParameters: const <String, Object?>{'pageSize': 1000},
    );
    final body = _expectJsonMap(response.data);
    final list = body['personalAccessTokens'] ?? body['personal_access_tokens'];
    final tokens = <PersonalAccessToken>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          tokens.add(PersonalAccessToken.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    tokens.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return tokens;
  }

  Future<(List<AppNotification> notifications, String nextPageToken)> listNotifications({
    int pageSize = 50,
    String? pageToken,
    String? userName,
    String? filter,
  }) async {
    if (!useLegacyApi) {
      return _listNotificationsModern(
        pageSize: pageSize,
        pageToken: pageToken,
        userName: userName,
        filter: filter,
      );
    }
    try {
      return await _listNotificationsLegacy(
        pageSize: pageSize,
        pageToken: pageToken,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _listNotificationsModern(
          pageSize: pageSize,
          pageToken: pageToken,
          userName: userName,
          filter: filter,
        );
      }
      rethrow;
    }
  }

  Future<(List<AppNotification> notifications, String nextPageToken)> _listNotificationsModern({
    required int pageSize,
    String? pageToken,
    String? userName,
    String? filter,
  }) async {
    final parent = await _resolveNotificationParent(userName);
    final normalizedToken = (pageToken ?? '').trim();
    final normalizedFilter = (filter ?? '').trim();

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
          notifications.add(AppNotification.fromModernJson(item.cast<String, dynamic>()));
        }
      }
    }
    final nextToken = _readStringField(body, 'nextPageToken', 'next_page_token');
    return (notifications, nextToken);
  }

  Future<(List<AppNotification> notifications, String nextPageToken)> _listNotificationsLegacy({
    required int pageSize,
    String? pageToken,
  }) async {
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
          notifications.add(AppNotification.fromLegacyJson(item.cast<String, dynamic>()));
        }
      }
    }
    final nextToken = _readStringField(body, 'nextPageToken', 'next_page_token');
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
    await _updateUserNotificationStatus(name: trimmedName, status: trimmedStatus);
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
      await _dio.delete('api/v1/$trimmedName');
      return;
    }
    await _dio.delete('api/v1/$trimmedName');
  }

  Future<void> _updateUserNotificationStatus({required String name, required String status}) async {
    await _dio.patch(
      'api/v1/$name',
      queryParameters: const <String, Object?>{
        'updateMask': 'status',
        'update_mask': 'status',
      },
      data: <String, Object?>{
        'name': name,
        'status': status,
      },
    );
  }

  Future<void> _updateInboxStatus({required String name, required String status}) async {
    await _dio.patch(
      'api/v1/$name',
      queryParameters: const <String, Object?>{
        'updateMask': 'status',
        'update_mask': 'status',
      },
      data: <String, Object?>{
        'name': name,
        'status': status,
      },
    );
  }

  Future<String> _resolveNotificationParent(String? userName) async {
    final raw = (userName ?? '').trim();
    if (raw.isEmpty) {
      final currentUser = await getCurrentUser();
      return currentUser.name;
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

  Future<(List<Memo> memos, String nextPageToken)> listMemos({
    int pageSize = 50,
    String? pageToken,
    String? state,
    String? filter,
    String? parent,
    String? orderBy,
  }) async {
    if (!useLegacyApi) {
      return _listMemosModern(
        pageSize: pageSize,
        pageToken: pageToken,
        state: state,
        filter: filter,
        parent: parent,
        orderBy: orderBy,
      );
    }
    try {
      return await _listMemosLegacy(
        pageSize: pageSize,
        pageToken: pageToken,
        state: state,
        filter: filter,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _listMemosModern(
          pageSize: pageSize,
          pageToken: pageToken,
          state: state,
          filter: filter,
          parent: parent,
          orderBy: orderBy,
        );
      }
      rethrow;
    }
  }

  Future<(List<Memo> memos, String nextPageToken)> _listMemosModern({
    required int pageSize,
    String? pageToken,
    String? state,
    String? filter,
    String? parent,
    String? orderBy,
  }) async {
    final normalizedPageToken = (pageToken ?? '').trim();
    final normalizedParent = (parent ?? '').trim();
    final response = await _dio.get(
      'api/v1/memos',
      queryParameters: <String, Object?>{
        'pageSize': pageSize,
        'page_size': pageSize,
        if (normalizedPageToken.isNotEmpty) 'pageToken': normalizedPageToken,
        if (normalizedPageToken.isNotEmpty) 'page_token': normalizedPageToken,
        if (normalizedParent.isNotEmpty) 'parent': normalizedParent,
        if (state != null && state.isNotEmpty) 'state': state,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        if (orderBy != null && orderBy.isNotEmpty) 'orderBy': orderBy,
        if (orderBy != null && orderBy.isNotEmpty) 'order_by': orderBy,
      },
    );
    final body = _expectJsonMap(response.data);
    final list = body['memos'];
    final memos = <Memo>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          memos.add(Memo.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    final nextToken = _readStringField(body, 'nextPageToken', 'next_page_token');
    return (memos, nextToken);
  }

  Future<Memo> getMemo({required String memoUid}) async {
    if (!useLegacyApi) {
      return _getMemoModern(memoUid);
    }
    try {
      return await _getMemoLegacy(memoUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _getMemoModern(memoUid);
      }
      rethrow;
    }
  }

  Future<Memo> _getMemoModern(String memoUid) async {
    final response = await _dio.get('api/v1/memos/$memoUid');
    return Memo.fromJson(_expectJsonMap(response.data));
  }

  Future<Memo> _getMemoLegacy(String memoUid) async {
    final response = await _dio.get('api/v1/memo/$memoUid');
    return _memoFromLegacy(_expectJsonMap(response.data));
  }

  Future<Memo> createMemo({
    required String memoId,
    required String content,
    String visibility = 'PRIVATE',
    bool pinned = false,
  }) async {
    if (!useLegacyApi) {
      return _createMemoModern(
        memoId: memoId,
        content: content,
        visibility: visibility,
        pinned: pinned,
      );
    }
    try {
      return await _createMemoLegacy(
        memoId: memoId,
        content: content,
        visibility: visibility,
        pinned: pinned,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _createMemoModern(
          memoId: memoId,
          content: content,
          visibility: visibility,
          pinned: pinned,
        );
      }
      rethrow;
    }
  }

  Future<Memo> _createMemoModern({
    required String memoId,
    required String content,
    required String visibility,
    required bool pinned,
  }) async {
    final response = await _dio.post(
      'api/v1/memos',
      queryParameters: <String, Object?>{'memoId': memoId},
      data: <String, Object?>{
        'content': content,
        'visibility': visibility,
        'pinned': pinned,
      },
    );
    return Memo.fromJson(_expectJsonMap(response.data));
  }

  Future<Memo> updateMemo({
    required String memoUid,
    String? content,
    String? visibility,
    bool? pinned,
    String? state,
  }) async {
    if (!useLegacyApi) {
      return _updateMemoModern(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
      );
    }
    try {
      return await _updateMemoLegacy(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _updateMemoModern(
          memoUid: memoUid,
          content: content,
          visibility: visibility,
          pinned: pinned,
          state: state,
        );
      }
      rethrow;
    }
  }

  Future<Memo> _updateMemoModern({
    required String memoUid,
    String? content,
    String? visibility,
    bool? pinned,
    String? state,
  }) async {
    final updateMask = <String>[];
    final data = <String, Object?>{
      'name': 'memos/$memoUid',
    };
    if (content != null) {
      updateMask.add('content');
      data['content'] = content;
    }
    if (visibility != null) {
      updateMask.add('visibility');
      data['visibility'] = visibility;
    }
    if (pinned != null) {
      updateMask.add('pinned');
      data['pinned'] = pinned;
    }
    if (state != null) {
      updateMask.add('state');
      data['state'] = state;
    }
    if (updateMask.isEmpty) {
      throw ArgumentError('updateMemo requires at least one field');
    }

    final response = await _dio.patch(
      'api/v1/memos/$memoUid',
      queryParameters: <String, Object?>{'updateMask': updateMask.join(',')},
      data: data,
    );
    return Memo.fromJson(_expectJsonMap(response.data));
  }

  Future<void> deleteMemo({required String memoUid, bool force = false}) async {
    if (!useLegacyApi) {
      await _deleteMemoModern(memoUid: memoUid, force: force);
      return;
    }
    try {
      await _deleteMemoLegacy(memoUid: memoUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        await _deleteMemoModern(memoUid: memoUid, force: force);
        return;
      }
      rethrow;
    }
  }

  Future<void> _deleteMemoModern({required String memoUid, required bool force}) async {
    await _dio.delete(
      'api/v1/memos/$memoUid',
      queryParameters: <String, Object?>{
        if (force) 'force': true,
      },
    );
  }

  Future<void> _deleteMemoLegacy({required String memoUid}) async {
    await _dio.delete('api/v1/memo/$memoUid');
  }

  Future<Attachment> createAttachment({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String? memoUid,
  }) async {
    if (!useLegacyApi) {
      return _createAttachmentModern(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
      );
    }
    try {
      return await _createAttachmentLegacy(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _createAttachmentModern(
          attachmentId: attachmentId,
          filename: filename,
          mimeType: mimeType,
          bytes: bytes,
          memoUid: memoUid,
        );
      }
      rethrow;
    }
  }

  Future<Attachment> _createAttachmentModern({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String? memoUid,
  }) async {
    final data = <String, Object?>{
      'filename': filename,
      'type': mimeType,
      'content': base64Encode(bytes),
      if (memoUid != null) 'memo': 'memos/$memoUid',
    };

    // Newer builds use /attachments.
    try {
      final response = await _dio.post(
        'api/v1/attachments',
        queryParameters: <String, Object?>{'attachmentId': attachmentId},
        data: data,
      );
      return Attachment.fromJson(_expectJsonMap(response.data));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404) rethrow;
    }

    // Older builds use /resources.
    final response = await _dio.post(
      'api/v1/resources',
      queryParameters: <String, Object?>{'resourceId': attachmentId},
      data: data,
    );
    return Attachment.fromJson(_expectJsonMap(response.data));
  }

  Future<Attachment> getAttachment({required String attachmentUid}) async {
    if (!useLegacyApi) {
      return _getAttachmentModern(attachmentUid);
    }
    try {
      return await _getAttachmentLegacy(attachmentUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _getAttachmentModern(attachmentUid);
      }
      rethrow;
    }
  }

  Future<Attachment> _getAttachmentModern(String attachmentUid) async {
    // Newer builds use /attachments/{id}.
    try {
      final response = await _dio.get('api/v1/attachments/$attachmentUid');
      return Attachment.fromJson(_expectJsonMap(response.data));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404) rethrow;
    }

    // Older builds use /resources/{id}.
    final response = await _dio.get('api/v1/resources/$attachmentUid');
    return Attachment.fromJson(_expectJsonMap(response.data));
  }

  Future<List<Attachment>> listMemoAttachments({
    required String memoUid,
  }) async {
    if (!useLegacyApi) {
      return _listMemoAttachmentsModern(memoUid);
    }
    try {
      return await _listMemoAttachmentsModern(memoUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        throw UnsupportedError('Legacy API does not support listMemoAttachments');
      }
      rethrow;
    }
  }

  Future<List<Attachment>> _listMemoAttachmentsModern(String memoUid) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid/attachments',
      queryParameters: const <String, Object?>{'pageSize': 1000},
    );
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
    return attachments;
  }

  Future<void> setMemoAttachments({
    required String memoUid,
    required List<String> attachmentNames,
  }) async {
    if (!useLegacyApi) {
      await _setMemoAttachmentsModern(memoUid, attachmentNames);
      return;
    }
    try {
      await _setMemoAttachmentsLegacy(memoUid, attachmentNames);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        await _setMemoAttachmentsModern(memoUid, attachmentNames);
        return;
      }
      rethrow;
    }
  }

  Future<void> _setMemoAttachmentsModern(String memoUid, List<String> attachmentNames) async {
    await _dio.patch(
      'api/v1/memos/$memoUid/attachments',
      data: <String, Object?>{
        'attachments': attachmentNames.map((n) => <String, Object?>{'name': n}).toList(growable: false),
      },
    );
  }

  Future<(List<Memo> memos, String nextPageToken)> _listMemosLegacy({
    required int pageSize,
    String? pageToken,
    String? state,
    String? filter,
  }) async {
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

  Future<Memo> _createMemoLegacy({
    required String memoId,
    required String content,
    required String visibility,
    required bool pinned,
  }) async {
    final _ = memoId;
    final response = await _dio.post(
      'api/v1/memo',
      data: <String, Object?>{
        'content': content,
        'visibility': visibility,
      },
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
  }) async {
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

    final response = await _dio.patch(
      'api/v1/memo/$memoUid',
      data: data,
    );
    return _memoFromLegacy(_expectJsonMap(response.data));
  }

  Future<Attachment> _createAttachmentLegacy({
    required String attachmentId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String? memoUid,
  }) async {
    final _ = [attachmentId, mimeType, memoUid];
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post('api/v1/resource/blob', data: formData);
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

  Future<void> _setMemoAttachmentsLegacy(String memoUid, List<String> attachmentNames) async {
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
    );
  }

  static Memo _legacyPlaceholderMemo(String memoUid, {required bool pinned}) {
    final normalizedUid = memoUid.trim();
    final name = normalizedUid.isEmpty ? '' : 'memos/$normalizedUid';
    return Memo(
      name: name,
      creator: '',
      content: '',
      visibility: 'PRIVATE',
      pinned: pinned,
      state: 'NORMAL',
      createTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updateTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      tags: const [],
      attachments: const [],
    );
  }

  static Memo _copyMemoWithPinned(Memo memo, bool pinned) {
    return Memo(
      name: memo.name,
      creator: memo.creator,
      content: memo.content,
      visibility: memo.visibility,
      pinned: pinned,
      state: memo.state,
      createTime: memo.createTime,
      updateTime: memo.updateTime,
      tags: memo.tags,
      attachments: memo.attachments,
    );
  }

  static Memo _memoFromLegacy(Map<String, dynamic> json) {
    final id = _readString(json['id']);
    final rawName = _readString(json['name']);
    final name = id.isNotEmpty
        ? 'memos/$id'
        : rawName.startsWith('memos/')
            ? rawName
            : rawName.isNotEmpty
                ? 'memos/$rawName'
                : '';

    final creatorId = _readString(json['creatorId'] ?? json['creator_id']);
    final creatorName = _readString(json['creatorName'] ?? json['creator_name']);
    final creator = creatorId.isNotEmpty ? 'users/$creatorId' : creatorName;

    final stateRaw = _readString(json['rowStatus'] ?? json['row_status'] ?? json['state']);
    final state = _normalizeLegacyRowStatus(stateRaw) ?? 'NORMAL';

    final attachments = _readLegacyAttachments(json['resourceList'] ?? json['resources'] ?? json['attachments']);

    return Memo(
      name: name,
      creator: creator,
      content: _readString(json['content']),
      visibility: _readString(json['visibility']).isNotEmpty ? _readString(json['visibility']) : 'PRIVATE',
      pinned: _readBool(json['pinned']),
      state: state,
      createTime: _readLegacyTime(json['createdTs'] ?? json['created_ts'] ?? json['createTime']),
      updateTime: _readLegacyTime(json['updatedTs'] ?? json['updated_ts'] ?? json['updateTime']),
      tags: const [],
      attachments: attachments,
    );
  }

  static List<Attachment> _readLegacyAttachments(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => _attachmentFromLegacy(e.cast<String, dynamic>()))
          .toList(growable: false);
    }
    return const [];
  }

  static Attachment _attachmentFromLegacy(Map<String, dynamic> json) {
    final id = _readString(json['id']);
    final nameRaw = _readString(json['name']);
    final uidRaw = _readString(json['uid']);
    var name = nameRaw.isNotEmpty ? nameRaw : uidRaw;
    if (name.isEmpty && id.isNotEmpty) {
      name = id;
    }
    if (name.isNotEmpty && !name.startsWith('resources/')) {
      name = 'resources/$name';
    }
    return Attachment(
      name: name,
      filename: _readString(json['filename']),
      type: _readString(json['type']),
      size: _readInt(json['size']),
      externalLink: _readString(json['externalLink'] ?? json['external_link']),
    );
  }

  static List<dynamic> _readListPayload(dynamic value) {
    if (value is List) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return _readListPayload(decoded);
      } catch (_) {
        return const [];
      }
    }
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      final list = map['memos'] ?? map['memoList'] ?? map['resources'] ?? map['attachments'] ?? map['data'];
      if (list is List) return list;
    }
    return const [];
  }

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    if (value == null) return '';
    return value.toString().trim();
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return false;
  }

  static DateTime _readLegacyTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final seconds = _readInt(value);
    if (seconds <= 0) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static String? _normalizeLegacyRowStatus(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    if (normalized.isEmpty) return null;
    if (normalized.contains('ARCHIVED')) return 'ARCHIVED';
    if (normalized.contains('NORMAL')) return 'NORMAL';
    return normalized;
  }

  static int? _tryParseLegacyCreatorId(String? filter) {
    final raw = (filter ?? '').trim();
    if (raw.isEmpty) return null;
    final match = RegExp(r'creator_id\s*==\s*(\d+)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  static int? _tryParseLegacyResourceId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.startsWith('resources/') ? trimmed.substring('resources/'.length) : trimmed;
    final numeric = int.tryParse(normalized);
    if (numeric != null) return numeric;
    return int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  static Object _legacyMemoIdValue(String memoUid) {
    final trimmed = memoUid.trim();
    final id = int.tryParse(trimmed);
    return id ?? trimmed;
  }

  static Map<String, dynamic> _expectJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw const FormatException('Expected JSON object');
  }

  static String _readStringField(Map<String, dynamic> body, String key, String altKey) {
    final primary = body[key];
    if (primary is String) return primary;
    if (primary is num) return primary.toString();
    final alt = body[altKey];
    if (alt is String) return alt;
    if (alt is num) return alt.toString();
    return '';
  }
}
