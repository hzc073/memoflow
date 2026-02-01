import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/url.dart';
import '../logs/breadcrumb_store.dart';
import '../logs/log_manager.dart';
import '../logs/network_log_buffer.dart';
import '../logs/network_log_interceptor.dart';
import '../logs/network_log_store.dart';
import '../models/attachment.dart';
import '../models/content_fingerprint.dart';
import '../models/instance_profile.dart';
import '../models/memo.dart';
import '../models/memo_location.dart';
import '../models/memo_relation.dart';
import '../models/notification_item.dart';
import '../models/personal_access_token.dart';
import '../models/reaction.dart';
import '../models/shortcut.dart';
import '../models/user.dart';
import '../models/user_setting.dart';
import '../models/user_stats.dart';

class MemosApi {
  MemosApi._(
    this._dio, {
    this.useLegacyApi = false,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    if (logStore != null || logManager != null || logBuffer != null || breadcrumbStore != null) {
      _dio.interceptors.add(
        NetworkLogInterceptor(
          logStore,
          buffer: logBuffer,
          breadcrumbStore: breadcrumbStore,
          logManager: logManager,
        ),
      );
    }
  }

  final Dio _dio;
  final bool useLegacyApi;
  static const Duration _attachmentTimeout = Duration(seconds: 120);
  static const Object _unset = Object();

  Options _attachmentOptions() {
    return Options(
      sendTimeout: _attachmentTimeout,
      receiveTimeout: _attachmentTimeout,
    );
  }

  factory MemosApi.unauthenticated(
    Uri baseUrl, {
    bool useLegacyApi = false,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
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
      logManager: logManager,
    );
  }

  factory MemosApi.authenticated({
    required Uri baseUrl,
    required String personalAccessToken,
    bool useLegacyApi = false,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
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
      logManager: logManager,
    );
  }

  Future<InstanceProfile> getInstanceProfile() async {
    final response = await _dio.get('api/v1/instance/profile');
    return InstanceProfile.fromJson(_expectJsonMap(response.data));
  }

  Future<User> getCurrentUser() async {
    DioException? lastDio;
    FormatException? lastFormat;
    for (final attempt in <Future<User> Function()>[
      _getCurrentUserByAuthMe,
      _getCurrentUserByAuthStatusPost,
      _getCurrentUserByAuthStatusGet,
      _getCurrentUserByAuthStatusV2,
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
      } on FormatException catch (e) {
        lastFormat = e;
      }
    }

    if (lastFormat != null) throw lastFormat;
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

  Future<User> _getCurrentUserByAuthStatusV2() async {
    final response = await _dio.post('api/v2/auth/status', data: const <String, Object?>{});
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

  Future<UserStatsSummary> getUserStatsSummary({String? userName}) async {
    try {
      return await _getUserStatsModernGetStats(userName: userName);
    } on DioException catch (e) {
      if (!_shouldFallback(e)) rethrow;
    }

    try {
      return await _getUserStatsLegacyStatsPath(userName: userName);
    } on DioException catch (e) {
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    return await _getUserStatsLegacyMemoStats(userName: userName);
  }

  Future<UserStatsSummary> _getUserStatsModernGetStats({String? userName}) async {
    final name = await _resolveUserName(userName: userName);
    final response = await _dio.get('api/v1/$name:getStats');
    final body = _expectJsonMap(response.data);
    return _parseUserStats(body);
  }

  Future<UserStatsSummary> _getUserStatsLegacyStatsPath({String? userName}) async {
    final name = await _resolveUserName(userName: userName);
    final response = await _dio.get('api/v1/$name/stats');
    final body = _expectJsonMap(response.data);
    return _parseUserStats(body);
  }

  Future<UserStatsSummary> _getUserStatsLegacyMemoStats({String? userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final response = await _dio.get(
      'api/v1/memo/stats',
      queryParameters: <String, Object?>{
        'creatorId': numericUserId,
      },
    );
    final list = response.data;
    final times = <DateTime>[];
    if (list is List) {
      for (final item in list) {
        final dt = _readLegacyTime(item);
        if (dt.millisecondsSinceEpoch > 0) {
          times.add(dt.toUtc());
        }
      }
    }
    return UserStatsSummary(
      memoDisplayTimes: times,
      totalMemoCount: times.length,
    );
  }

  UserStatsSummary _parseUserStats(Map<String, dynamic> body) {
    final list = body['memoDisplayTimestamps'] ?? body['memo_display_timestamps'];
    final times = <DateTime>[];
    if (list is List) {
      for (final item in list) {
        final dt = _readTimestamp(item);
        if (dt != null && dt.millisecondsSinceEpoch > 0) {
          times.add(dt.toUtc());
        }
      }
    }
    var total = _readInt(body['totalMemoCount'] ?? body['total_memo_count']);
    if (total <= 0) {
      total = times.length;
    }
    return UserStatsSummary(
      memoDisplayTimes: times,
      totalMemoCount: total,
    );
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

  Future<String> _resolveUserName({String? userName}) async {
    final raw = (userName ?? '').trim();
    if (raw.isNotEmpty) {
      return raw.startsWith('users/') ? raw : 'users/$raw';
    }
    final currentUser = await getCurrentUser();
    final name = currentUser.name.trim();
    if (name.isEmpty) {
      throw const FormatException('Unable to determine user name');
    }
    return name.startsWith('users/') ? name : 'users/$name';
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
      if (_shouldFallback(e)) {
        return await _createPersonalAccessTokenLegacy(
          userName: userName,
          description: description,
          expiresInDays: expiresInDays,
        );
      }
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

    Future<({PersonalAccessToken personalAccessToken, String token})> createViaPersonalAccessTokens() async {
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

    try {
      return await createViaPersonalAccessTokens();
    } on DioException catch (e) {
      if (_shouldFallback(e)) {
        return await _createUserAccessTokenCompat(
          parent: parent,
          description: trimmedDescription,
          expiresInDays: expiresInDays,
        );
      }
      rethrow;
    }
  }

  Future<({PersonalAccessToken personalAccessToken, String token})> _createUserAccessTokenCompat({
    required String parent,
    required String description,
    required int expiresInDays,
  }) async {
    final expiresAt = expiresInDays > 0 ? DateTime.now().toUtc().add(Duration(days: expiresInDays)) : null;

    Future<({PersonalAccessToken personalAccessToken, String token})> request({required bool useSnakeCaseExpires}) async {
      final data = <String, Object?>{
        'description': description,
        if (expiresAt != null) (useSnakeCaseExpires ? 'expires_at' : 'expiresAt'): expiresAt.toIso8601String(),
      };
      final response = await _dio.post(
        'api/v1/$parent/accessTokens',
        data: data,
      );
      final body = _expectJsonMap(response.data);
      final tokenValue = _readString(body['accessToken'] ?? body['access_token'] ?? body['token']);
      if (tokenValue.isEmpty) {
        throw const FormatException('Token missing in response');
      }
      final personalAccessToken = _personalAccessTokenFromAccessTokensJson(body, tokenValue: tokenValue);
      return (personalAccessToken: personalAccessToken, token: tokenValue);
    }

    if (expiresAt == null) {
      return request(useSnakeCaseExpires: false);
    }

    try {
      return await request(useSnakeCaseExpires: false);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 400) rethrow;
    }

    return request(useSnakeCaseExpires: true);
  }

  Future<({PersonalAccessToken personalAccessToken, String token})> _createPersonalAccessTokenLegacy({
    String? userName,
    required String description,
    required int expiresInDays,
  }) async {
    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) {
      throw ArgumentError('createPersonalAccessToken requires description');
    }

    final numericUserId = await _resolveNumericUserId(userName: userName);
    final name = 'users/$numericUserId';
    final expiresAt = expiresInDays > 0 ? DateTime.now().toUtc().add(Duration(days: expiresInDays)) : null;

    final response = await _dio.post(
      'api/v1/$name/access_tokens',
      data: <String, Object?>{
        'description': trimmedDescription,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      },
    );

    final body = _expectJsonMap(response.data);
    final token = _readString(body['accessToken'] ?? body['access_token']);
    if (token.isEmpty) {
      throw const FormatException('Token missing in response');
    }

    final pat = _personalAccessTokenFromLegacyJson(body, tokenValue: token);
    return (personalAccessToken: pat, token: token);
  }

  Future<List<PersonalAccessToken>> listPersonalAccessTokens({String? userName}) async {
    try {
      return await _listPersonalAccessTokensModern(userName: userName);
    } on DioException catch (e) {
      if (_shouldFallback(e)) {
        return await _listPersonalAccessTokensLegacy(userName: userName);
      }
      if (useLegacyApi && _shouldFallbackLegacy(e)) {
        throw UnsupportedError('Legacy API does not support personal access tokens');
      }
      rethrow;
    }
  }

  Future<List<PersonalAccessToken>> _listPersonalAccessTokensModern({String? userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final parent = 'users/$numericUserId';

    try {
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
    } on DioException catch (e) {
      if (!_shouldFallback(e)) rethrow;
    }

    return _listPersonalAccessTokensAccessTokens(parent: parent);
  }

  Future<List<PersonalAccessToken>> _listPersonalAccessTokensAccessTokens({required String parent}) async {
    final response = await _dio.get(
      'api/v1/$parent/accessTokens',
      queryParameters: const <String, Object?>{'pageSize': 1000},
    );
    final body = _expectJsonMap(response.data);
    final list = body['accessTokens'] ?? body['access_tokens'];
    final tokens = <PersonalAccessToken>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          tokens.add(_personalAccessTokenFromAccessTokensJson(item.cast<String, dynamic>()));
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

  Future<List<PersonalAccessToken>> _listPersonalAccessTokensLegacy({String? userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final name = 'users/$numericUserId';

    final response = await _dio.get('api/v1/$name/access_tokens');
    final body = _expectJsonMap(response.data);
    final list = body['accessTokens'] ?? body['access_tokens'];

    final tokens = <PersonalAccessToken>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final map = item.cast<String, dynamic>();
          final tokenValue = _readString(map['accessToken'] ?? map['access_token']);
          if (tokenValue.isEmpty) continue;
          tokens.add(_personalAccessTokenFromLegacyJson(map, tokenValue: tokenValue));
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

  Future<UserGeneralSetting> getUserGeneralSetting({String? userName}) async {
    final resolvedName = await _resolveUserName(userName: userName);
    DioException? lastError;

    try {
      return await _getUserGeneralSettingModern(userName: resolvedName, settingKey: 'GENERAL');
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallback(e)) rethrow;
    }

    try {
      return await _getUserGeneralSettingModern(userName: resolvedName, settingKey: 'general');
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallback(e)) rethrow;
    }

    try {
      return await _getUserGeneralSettingLegacyV1(userName: resolvedName);
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    try {
      return await _getUserGeneralSettingLegacyV2(userName: resolvedName);
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    throw lastError;
  }

  Future<UserGeneralSetting> updateUserGeneralSetting({
    String? userName,
    required UserGeneralSetting setting,
    required List<String> updateMask,
  }) async {
    final resolvedName = await _resolveUserName(userName: userName);
    final mask = _normalizeGeneralSettingMask(updateMask);
    if (mask.isEmpty) {
      throw ArgumentError('updateUserGeneralSetting requires updateMask');
    }

    try {
      return await _updateUserGeneralSettingModern(
        userName: resolvedName,
        settingKey: 'GENERAL',
        setting: setting,
        updateMask: mask,
      );
    } on DioException catch (e) {
      if (_shouldFallback(e) || e.response?.statusCode == 400) {
        try {
          return await _updateUserGeneralSettingModern(
            userName: resolvedName,
            settingKey: 'general',
            setting: setting,
            updateMask: mask,
          );
        } on DioException catch (inner) {
          if (!_shouldFallback(inner) && inner.response?.statusCode != 400) rethrow;
        }
      } else {
        rethrow;
      }
    }

    final legacyMask = _normalizeLegacyGeneralSettingMask(updateMask);

    try {
      return await _updateUserGeneralSettingLegacyV1(
        userName: resolvedName,
        setting: setting,
        updateMask: legacyMask,
      );
    } on DioException catch (e) {
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    return _updateUserGeneralSettingLegacyV2(
      userName: resolvedName,
      setting: setting,
      updateMask: legacyMask,
    );
  }

  Future<List<Shortcut>> listShortcuts({String? userName}) async {
    final parent = await _resolveUserName(userName: userName);
    try {
      return await _listShortcutsModern(parent: parent);
    } on DioException catch (e) {
      if (_shouldFallback(e) || _shouldFallbackLegacy(e)) {
        throw UnsupportedError('Shortcuts are not supported on this server');
      }
      rethrow;
    }
  }

  Future<Shortcut> createShortcut({
    String? userName,
    required String title,
    required String filter,
  }) async {
    final parent = await _resolveUserName(userName: userName);
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('createShortcut requires title');
    }
    final response = await _dio.post(
      'api/v1/$parent/shortcuts',
      data: <String, Object?>{
        'title': trimmedTitle,
        'filter': filter,
      },
    );
    return Shortcut.fromJson(_expectJsonMap(response.data));
  }

  Future<Shortcut> updateShortcut({
    String? userName,
    required Shortcut shortcut,
    required String title,
    required String filter,
  }) async {
    final parent = await _resolveUserName(userName: userName);
    final shortcutId = shortcut.shortcutId;
    if (shortcutId.isEmpty) {
      throw ArgumentError('updateShortcut requires shortcut id');
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('updateShortcut requires title');
    }
    final response = await _dio.patch(
      'api/v1/$parent/shortcuts/$shortcutId',
      queryParameters: const <String, Object?>{
        'updateMask': 'title,filter',
        'update_mask': 'title,filter',
      },
      data: <String, Object?>{
        if (shortcut.name.trim().isNotEmpty) 'name': shortcut.name.trim(),
        if (shortcut.id.trim().isNotEmpty) 'id': shortcut.id.trim(),
        'title': trimmedTitle,
        'filter': filter,
      },
    );
    return Shortcut.fromJson(_expectJsonMap(response.data));
  }

  Future<void> deleteShortcut({
    String? userName,
    required Shortcut shortcut,
  }) async {
    final parent = await _resolveUserName(userName: userName);
    final shortcutId = shortcut.shortcutId;
    if (shortcutId.isEmpty) {
      throw ArgumentError('deleteShortcut requires shortcut id');
    }
    await _dio.delete('api/v1/$parent/shortcuts/$shortcutId');
  }

  Future<List<UserWebhook>> listUserWebhooks({String? userName}) async {
    final resolvedName = await _resolveUserName(userName: userName);
    DioException? lastError;

    try {
      return await _listUserWebhooksModern(userName: resolvedName);
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallback(e)) rethrow;
    }

    try {
      return await _listUserWebhooksLegacyV1(userName: resolvedName);
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    try {
      return await _listUserWebhooksLegacyV2(userName: resolvedName);
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    throw lastError;
  }

  Future<UserWebhook> createUserWebhook({
    String? userName,
    required String displayName,
    required String url,
  }) async {
    final resolvedName = await _resolveUserName(userName: userName);
    DioException? lastError;
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError('createUserWebhook requires url');
    }

    try {
      return await _createUserWebhookModern(
        userName: resolvedName,
        displayName: displayName,
        url: trimmedUrl,
      );
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallback(e)) rethrow;
    }

    try {
      return await _createUserWebhookLegacyV1(
        userName: resolvedName,
        displayName: displayName,
        url: trimmedUrl,
      );
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    try {
      return await _createUserWebhookLegacyV2(
        userName: resolvedName,
        displayName: displayName,
        url: trimmedUrl,
      );
    } on DioException catch (e) {
      lastError = e;
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    throw lastError;
  }

  Future<UserWebhook> updateUserWebhook({
    required UserWebhook webhook,
    required String displayName,
    required String url,
  }) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError('updateUserWebhook requires url');
    }

    if (webhook.isLegacy) {
      try {
        return await _updateUserWebhookLegacyV1(
          webhook: webhook,
          displayName: displayName,
          url: trimmedUrl,
        );
      } on DioException catch (e) {
        if (_shouldFallbackLegacy(e)) {
          return _updateUserWebhookLegacyV2(
            webhook: webhook,
            displayName: displayName,
            url: trimmedUrl,
          );
        }
        rethrow;
      }
    }

    try {
      return await _updateUserWebhookModern(
        webhook: webhook,
        displayName: displayName,
        url: trimmedUrl,
      );
    } on DioException catch (e) {
      if (_shouldFallback(e)) {
        try {
          return await _updateUserWebhookLegacyV1(
            webhook: webhook,
            displayName: displayName,
            url: trimmedUrl,
          );
        } on DioException catch (inner) {
          if (_shouldFallbackLegacy(inner)) {
            return _updateUserWebhookLegacyV2(
              webhook: webhook,
              displayName: displayName,
              url: trimmedUrl,
            );
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> deleteUserWebhook({
    required UserWebhook webhook,
  }) async {
    if (webhook.isLegacy) {
      try {
        await _deleteUserWebhookLegacyV1(webhook: webhook);
      } on DioException catch (e) {
        if (_shouldFallbackLegacy(e)) {
          await _deleteUserWebhookLegacyV2(webhook: webhook);
          return;
        }
        rethrow;
      }
      return;
    }

    try {
      await _deleteUserWebhookModern(webhook: webhook);
    } on DioException catch (e) {
      if (_shouldFallback(e)) {
        try {
          await _deleteUserWebhookLegacyV1(webhook: webhook);
        } on DioException catch (inner) {
          if (_shouldFallbackLegacy(inner)) {
            await _deleteUserWebhookLegacyV2(webhook: webhook);
            return;
          }
          rethrow;
        }
        return;
      }
      rethrow;
    }
  }

  Future<UserGeneralSetting> _getUserGeneralSettingModern({
    required String userName,
    required String settingKey,
  }) async {
    final settingName = '$userName/settings/$settingKey';
    final response = await _dio.get('api/v1/$settingName');
    final body = _expectJsonMap(response.data);
    final payload = body['setting'];
    final json = payload is Map ? payload.cast<String, dynamic>() : body;
    final setting = UserSetting.fromJson(json);
    return setting.generalSetting ?? const UserGeneralSetting();
  }

  Future<UserGeneralSetting> _getUserGeneralSettingLegacyV1({required String userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final name = 'users/$numericUserId/setting';
    final response = await _dio.get('api/v1/$name');
    final body = _expectJsonMap(response.data);
    final payload = body['setting'];
    final json = payload is Map ? payload.cast<String, dynamic>() : body;
    final setting = UserSetting.fromJson(json);
    return setting.generalSetting ?? const UserGeneralSetting();
  }

  Future<UserGeneralSetting> _getUserGeneralSettingLegacyV2({required String userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final name = 'users/$numericUserId/setting';
    final response = await _dio.get('api/v2/$name');
    final body = _expectJsonMap(response.data);
    final payload = body['setting'];
    final json = payload is Map ? payload.cast<String, dynamic>() : body;
    final setting = UserSetting.fromJson(json);
    return setting.generalSetting ?? const UserGeneralSetting();
  }

  Future<UserGeneralSetting> _updateUserGeneralSettingModern({
    required String userName,
    required String settingKey,
    required UserGeneralSetting setting,
    required String updateMask,
  }) async {
    final settingName = '$userName/settings/$settingKey';
    final response = await _dio.patch(
      'api/v1/$settingName',
      queryParameters: <String, Object?>{
        'updateMask': updateMask,
        'update_mask': updateMask,
      },
      data: UserSetting(name: settingName, generalSetting: setting).toJson(),
    );
    final body = _expectJsonMap(response.data);
    final payload = body['setting'];
    final json = payload is Map ? payload.cast<String, dynamic>() : body;
    final parsed = UserSetting.fromJson(json);
    return parsed.generalSetting ?? setting;
  }

  Future<UserGeneralSetting> _updateUserGeneralSettingLegacyV1({
    required String userName,
    required UserGeneralSetting setting,
    required String updateMask,
  }) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final settingName = 'users/$numericUserId/setting';
    final data = _legacyUserSettingPayload(settingName, setting: setting);
    final response = await _dio.patch(
      'api/v1/$settingName',
      queryParameters: <String, Object?>{
        'updateMask': updateMask,
        'update_mask': updateMask,
      },
      data: data,
    );
    final body = _expectJsonMap(response.data);
    final payload = body['setting'];
    final json = payload is Map ? payload.cast<String, dynamic>() : body;
    final parsed = UserSetting.fromJson(json);
    return parsed.generalSetting ?? setting;
  }

  Future<UserGeneralSetting> _updateUserGeneralSettingLegacyV2({
    required String userName,
    required UserGeneralSetting setting,
    required String updateMask,
  }) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final settingName = 'users/$numericUserId/setting';
    final data = _legacyUserSettingPayload(settingName, setting: setting);
    final response = await _dio.patch(
      'api/v2/$settingName',
      queryParameters: <String, Object?>{
        'updateMask': updateMask,
        'update_mask': updateMask,
      },
      data: data,
    );
    final body = _expectJsonMap(response.data);
    final payload = body['setting'];
    final json = payload is Map ? payload.cast<String, dynamic>() : body;
    final parsed = UserSetting.fromJson(json);
    return parsed.generalSetting ?? setting;
  }

  Future<List<Shortcut>> _listShortcutsModern({required String parent}) async {
    final response = await _dio.get('api/v1/$parent/shortcuts');
    final body = _expectJsonMap(response.data);
    final list = body['shortcuts'];
    final shortcuts = <Shortcut>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          shortcuts.add(Shortcut.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return shortcuts;
  }

  Future<List<UserWebhook>> _listUserWebhooksModern({required String userName}) async {
    final response = await _dio.get('api/v1/$userName/webhooks');
    final body = _expectJsonMap(response.data);
    final list = body['webhooks'];
    return _parseUserWebhooks(list);
  }

  Future<List<UserWebhook>> _listUserWebhooksLegacyV1({required String userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final creatorName = 'users/$numericUserId';
    final response = await _dio.get(
      'api/v1/webhooks',
      queryParameters: <String, Object?>{'creator': creatorName},
    );
    final body = _expectJsonMap(response.data);
    final list = body['webhooks'];
    return _parseUserWebhooks(list);
  }

  Future<List<UserWebhook>> _listUserWebhooksLegacyV2({required String userName}) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final response = await _dio.get(
      'api/v2/webhooks',
      queryParameters: <String, Object?>{
        'creatorId': numericUserId,
        'creator_id': numericUserId,
      },
    );
    final body = _expectJsonMap(response.data);
    final list = body['webhooks'];
    return _parseUserWebhooks(list);
  }

  Future<UserWebhook> _createUserWebhookModern({
    required String userName,
    required String displayName,
    required String url,
  }) async {
    final response = await _dio.post(
      'api/v1/$userName/webhooks',
      data: <String, Object?>{
        if (displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
        'url': url,
      },
    );
    final body = _expectJsonMap(response.data);
    final json = _unwrapWebhookPayload(body);
    return UserWebhook.fromJson(json);
  }

  Future<UserWebhook> _createUserWebhookLegacyV1({
    required String userName,
    required String displayName,
    required String url,
  }) async {
    final label = displayName.trim().isNotEmpty ? displayName.trim() : url;
    final response = await _dio.post(
      'api/v1/webhooks',
      data: <String, Object?>{
        'name': label,
        'url': url,
      },
    );
    final body = _expectJsonMap(response.data);
    final json = _unwrapWebhookPayload(body);
    return UserWebhook.fromJson(json);
  }

  Future<UserWebhook> _createUserWebhookLegacyV2({
    required String userName,
    required String displayName,
    required String url,
  }) async {
    final label = displayName.trim().isNotEmpty ? displayName.trim() : url;
    final response = await _dio.post(
      'api/v2/webhooks',
      data: <String, Object?>{
        'name': label,
        'url': url,
      },
    );
    final body = _expectJsonMap(response.data);
    final json = _unwrapWebhookPayload(body);
    return UserWebhook.fromJson(json);
  }

  Future<UserWebhook> _updateUserWebhookModern({
    required UserWebhook webhook,
    required String displayName,
    required String url,
  }) async {
    final name = webhook.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('updateUserWebhook requires webhook name');
    }
    final response = await _dio.patch(
      'api/v1/$name',
      queryParameters: const <String, Object?>{
        'updateMask': 'display_name,url',
        'update_mask': 'display_name,url',
      },
      data: <String, Object?>{
        'name': name,
        if (displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
        'url': url,
      },
    );
    final body = _expectJsonMap(response.data);
    final json = _unwrapWebhookPayload(body);
    return UserWebhook.fromJson(json);
  }

  Future<UserWebhook> _updateUserWebhookLegacyV1({
    required UserWebhook webhook,
    required String displayName,
    required String url,
  }) async {
    final id = webhook.legacyId;
    if (id == null || id <= 0) {
      throw ArgumentError('updateUserWebhook requires legacy id');
    }
    final response = await _dio.patch(
      'api/v1/webhooks/$id',
      queryParameters: const <String, Object?>{
        'updateMask': 'name,url',
        'update_mask': 'name,url',
      },
      data: <String, Object?>{
        'id': id,
        'name': displayName.trim().isNotEmpty ? displayName.trim() : webhook.name,
        'url': url,
      },
    );
    final body = _expectJsonMap(response.data);
    final json = _unwrapWebhookPayload(body);
    return UserWebhook.fromJson(json);
  }

  Future<UserWebhook> _updateUserWebhookLegacyV2({
    required UserWebhook webhook,
    required String displayName,
    required String url,
  }) async {
    final id = webhook.legacyId;
    if (id == null || id <= 0) {
      throw ArgumentError('updateUserWebhook requires legacy id');
    }
    final response = await _dio.patch(
      'api/v2/webhooks/$id',
      queryParameters: const <String, Object?>{
        'updateMask': 'name,url',
        'update_mask': 'name,url',
      },
      data: <String, Object?>{
        'id': id,
        'name': displayName.trim().isNotEmpty ? displayName.trim() : webhook.name,
        'url': url,
      },
    );
    final body = _expectJsonMap(response.data);
    final json = _unwrapWebhookPayload(body);
    return UserWebhook.fromJson(json);
  }

  Future<void> _deleteUserWebhookModern({required UserWebhook webhook}) async {
    final name = webhook.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('deleteUserWebhook requires name');
    }
    await _dio.delete('api/v1/$name');
  }

  Future<void> _deleteUserWebhookLegacyV1({
    required UserWebhook webhook,
  }) async {
    final id = webhook.legacyId;
    if (id == null || id <= 0) {
      throw ArgumentError('deleteUserWebhook requires legacy id');
    }
    await _dio.delete('api/v1/webhooks/$id');
  }

  Future<void> _deleteUserWebhookLegacyV2({required UserWebhook webhook}) async {
    final id = webhook.legacyId;
    if (id == null || id <= 0) {
      throw ArgumentError('deleteUserWebhook requires legacy id');
    }
    await _dio.delete('api/v2/webhooks/$id');
  }

  List<UserWebhook> _parseUserWebhooks(dynamic list) {
    final webhooks = <UserWebhook>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          webhooks.add(UserWebhook.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return webhooks;
  }

  static Map<String, dynamic> _unwrapWebhookPayload(Map<String, dynamic> body) {
    final inner = body['webhook'];
    if (inner is Map) {
      return inner.cast<String, dynamic>();
    }
    return body;
  }

  static Map<String, dynamic> _legacyUserSettingPayload(String name, {required UserGeneralSetting setting}) {
    final data = <String, dynamic>{
      'name': name,
    };
    if (setting.locale != null && setting.locale!.trim().isNotEmpty) {
      data['locale'] = setting.locale!.trim();
    }
    if (setting.memoVisibility != null && setting.memoVisibility!.trim().isNotEmpty) {
      data['memoVisibility'] = setting.memoVisibility!.trim();
    }
    if (setting.theme != null && setting.theme!.trim().isNotEmpty) {
      data['appearance'] = setting.theme!.trim();
    }
    return data;
  }

  static String _normalizeGeneralSettingMask(List<String> fields) {
    final mapped = <String>{};
    for (final field in fields) {
      final trimmed = field.trim();
      if (trimmed.isEmpty) continue;
      switch (trimmed) {
        case 'memoVisibility':
        case 'memo_visibility':
        case 'generalSetting.memoVisibility':
        case 'general_setting.memo_visibility':
          mapped.add('memo_visibility');
          break;
        case 'locale':
        case 'generalSetting.locale':
        case 'general_setting.locale':
          mapped.add('locale');
          break;
        case 'theme':
        case 'appearance':
        case 'generalSetting.theme':
        case 'general_setting.theme':
        case 'generalSetting.appearance':
        case 'general_setting.appearance':
          mapped.add('theme');
          break;
        default:
          mapped.add(trimmed);
      }
    }
    return mapped.join(',');
  }

  static String _normalizeLegacyGeneralSettingMask(List<String> fields) {
    final mapped = <String>[];
    for (final field in fields) {
      final trimmed = field.trim();
      if (trimmed.isEmpty) continue;
      switch (trimmed) {
        case 'theme':
        case 'appearance':
        case 'generalSetting.theme':
        case 'general_setting.theme':
        case 'generalSetting.appearance':
        case 'general_setting.appearance':
          mapped.add('appearance');
          break;
        case 'memoVisibility':
        case 'memo_visibility':
        case 'generalSetting.memoVisibility':
        case 'general_setting.memo_visibility':
          mapped.add('memo_visibility');
          break;
        case 'locale':
        case 'generalSetting.locale':
        case 'general_setting.locale':
          mapped.add('locale');
          break;
        default:
          mapped.add(trimmed);
      }
    }
    return mapped.toSet().join(',');
  }

  static String _normalizeLegacyReactionType(String reactionType) {
    final trimmed = reactionType.trim();
    if (trimmed.isEmpty) return 'HEART';
    if (trimmed == 'HEART' || trimmed == 'THUMBS_UP') return trimmed;
    if (trimmed == '❤️' || trimmed == '❤' || trimmed == '♥') return 'HEART';
    if (trimmed == '👍') return 'THUMBS_UP';
    return 'HEART';
  }

  Future<(List<AppNotification> notifications, String nextPageToken)> listNotifications({
    int pageSize = 50,
    String? pageToken,
    String? userName,
    String? filter,
  }) async {
    if (!useLegacyApi) {
      return await _listNotificationsModern(
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
      if (!_shouldFallbackLegacy(e)) rethrow;
      return await _listNotificationsModern(
        pageSize: pageSize,
        pageToken: pageToken,
        userName: userName,
        filter: filter,
      );
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
    String? oldFilter,
    bool preferModern = false,
  }) async {
    Future<(List<Memo> memos, String nextPageToken)> callModern() {
      return _listMemosModern(
        pageSize: pageSize,
        pageToken: pageToken,
        state: state,
        filter: filter,
        parent: parent,
        orderBy: orderBy,
        oldFilter: oldFilter,
      );
    }

    if (preferModern) {
      try {
        return await callModern();
      } on DioException catch (e) {
        if (_shouldFallbackLegacy(e)) {
          return await _listMemosLegacy(
            pageSize: pageSize,
            pageToken: pageToken,
            state: state,
            filter: filter,
          );
        }
        rethrow;
      }
    }

    if (!useLegacyApi) {
      return callModern();
    }
    try {
      return await callModern();
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _listMemosLegacy(
          pageSize: pageSize,
          pageToken: pageToken,
          state: state,
          filter: filter,
        );
      }
      rethrow;
    }
  }

  Future<({List<Memo> memos, String nextPageToken, bool usedLegacyAll})> listExploreMemos({
    int pageSize = 50,
    String? pageToken,
    String? state,
    String? filter,
    String? orderBy,
  }) async {
    try {
      final (memos, nextToken) = await _listMemosModern(
        pageSize: pageSize,
        pageToken: pageToken,
        state: state,
        filter: filter,
        orderBy: orderBy,
      );
      return (memos: memos, nextPageToken: nextToken, usedLegacyAll: false);
    } on DioException catch (e) {
      if (!_shouldFallback(e) && !_shouldFallbackLegacy(e)) {
        rethrow;
      }
    }

    final (memos, nextToken) = await _listMemosAllLegacy(
      pageSize: pageSize,
      pageToken: pageToken,
    );
    return (memos: memos, nextPageToken: nextToken, usedLegacyAll: true);
  }

  Future<(List<Memo> memos, String nextPageToken)> _listMemosModern({
    required int pageSize,
    String? pageToken,
    String? state,
    String? filter,
    String? parent,
    String? orderBy,
    String? oldFilter,
  }) async {
    final normalizedPageToken = (pageToken ?? '').trim();
    final normalizedParent = (parent ?? '').trim();
    final normalizedOldFilter = (oldFilter ?? '').trim();
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
          memos.add(Memo.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    final nextToken = _readStringField(body, 'nextPageToken', 'next_page_token');
    return (memos, nextToken);
  }

  Future<(List<Memo> memos, String nextPageToken)> _listMemosAllLegacy({
    required int pageSize,
    String? pageToken,
  }) async {
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
    if (!useLegacyApi) {
      return _getMemoModern(memoUid);
    }
    try {
      return await _getMemoModern(memoUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _getMemoLegacy(memoUid);
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
    MemoLocation? location,
  }) async {
    if (!useLegacyApi) {
      return _createMemoModern(
        memoId: memoId,
        content: content,
        visibility: visibility,
        pinned: pinned,
        location: location,
      );
    }
    try {
      return await _createMemoModern(
        memoId: memoId,
        content: content,
        visibility: visibility,
        pinned: pinned,
        location: location,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _createMemoLegacy(
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
    MemoLocation? location,
  }) async {
    final response = await _dio.post(
      'api/v1/memos',
      queryParameters: <String, Object?>{'memoId': memoId},
      data: <String, Object?>{
        'content': content,
        'visibility': visibility,
        'pinned': pinned,
        if (location != null) 'location': location.toJson(),
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
    DateTime? displayTime,
    Object? location = _unset,
  }) async {
    if (!useLegacyApi) {
      return _updateMemoModern(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        displayTime: displayTime,
        location: location,
      );
    }
    try {
      return await _updateMemoModern(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        displayTime: displayTime,
        location: location,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _updateMemoLegacy(
          memoUid: memoUid,
          content: content,
          visibility: visibility,
          pinned: pinned,
          state: state,
          displayTime: displayTime,
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
    DateTime? displayTime,
    required Object? location,
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
    if (displayTime != null) {
      updateMask.add('display_time');
      data['displayTime'] = displayTime.toUtc().toIso8601String();
    }
    if (!identical(location, _unset)) {
      updateMask.add('location');
      data['location'] = location == null ? null : (location as MemoLocation).toJson();
    }
    if (updateMask.isEmpty) {
      throw ArgumentError('updateMemo requires at least one field');
    }

    final response = await _dio.patch(
      'api/v1/memos/$memoUid',
      queryParameters: <String, Object?>{
        'updateMask': updateMask.join(','),
        'update_mask': updateMask.join(','),
      },
      data: data,
    );
    return Memo.fromJson(_expectJsonMap(response.data));
  }

  Future<void> deleteMemo({required String memoUid, bool force = false}) async {
    final normalized = _normalizeMemoUid(memoUid);
    if (!useLegacyApi) {
      await _deleteMemoModern(memoUid: normalized, force: force);
      return;
    }
    try {
      await _deleteMemoLegacy(memoUid: normalized, force: force);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        await _deleteMemoModern(memoUid: normalized, force: force);
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

  Future<void> _deleteMemoLegacy({required String memoUid, required bool force}) async {
    try {
      await _dio.delete(
        'api/v1/memos/$memoUid',
        queryParameters: <String, Object?>{
          if (force) 'force': true,
        },
      );
      return;
    } on DioException catch (e) {
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    await _dio.delete('api/v1/memo/$memoUid');
  }

  static String _normalizeMemoUid(String memoUid) {
    final trimmed = memoUid.trim();
    if (trimmed.startsWith('memos/')) {
      return trimmed.substring('memos/'.length);
    }
    return trimmed;
  }

  static String _normalizeAttachmentUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('attachments/')) {
      return trimmed.substring('attachments/'.length);
    }
    if (trimmed.startsWith('resources/')) {
      return trimmed.substring('resources/'.length);
    }
    return trimmed;
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
      return await _createAttachmentCompat(
        attachmentId: attachmentId,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
        memoUid: memoUid,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _createAttachmentLegacy(
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
        options: _attachmentOptions(),
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
      options: _attachmentOptions(),
    );
    return Attachment.fromJson(_expectJsonMap(response.data));
  }

  Future<Attachment> _createAttachmentCompat({
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

    // 0.24 uses /resources.
    try {
      final response = await _dio.post(
        'api/v1/resources',
        queryParameters: <String, Object?>{'resourceId': attachmentId},
        data: data,
        options: _attachmentOptions(),
      );
      return Attachment.fromJson(_expectJsonMap(response.data));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404) rethrow;
    }

    // 0.25+ uses /attachments.
    final response = await _dio.post(
      'api/v1/attachments',
      queryParameters: <String, Object?>{'attachmentId': attachmentId},
      data: data,
      options: _attachmentOptions(),
    );
    return Attachment.fromJson(_expectJsonMap(response.data));
  }

  Future<Attachment> getAttachment({required String attachmentUid}) async {
    if (!useLegacyApi) {
      return _getAttachmentModern(attachmentUid);
    }
    try {
      return await _getAttachmentCompat(attachmentUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _getAttachmentLegacy(attachmentUid);
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

  Future<Attachment> _getAttachmentCompat(String attachmentUid) async {
    // 0.24 uses /resources/{id}.
    try {
      final response = await _dio.get('api/v1/resources/$attachmentUid');
      return Attachment.fromJson(_expectJsonMap(response.data));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404) rethrow;
    }

    // 0.25+ uses /attachments/{id}.
    final response = await _dio.get('api/v1/attachments/$attachmentUid');
    return Attachment.fromJson(_expectJsonMap(response.data));
  }

  Future<void> deleteAttachment({required String attachmentName}) async {
    final attachmentUid = _normalizeAttachmentUid(attachmentName);
    if (!useLegacyApi) {
      await _deleteAttachmentModern(attachmentUid);
      return;
    }
    try {
      await _deleteAttachmentCompat(attachmentUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        await _deleteAttachmentLegacy(attachmentUid);
        return;
      }
      rethrow;
    }
  }

  Future<void> _deleteAttachmentModern(String attachmentUid) async {
    // Newer builds use /attachments/{id}.
    try {
      await _dio.delete('api/v1/attachments/$attachmentUid');
      return;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404) rethrow;
    }

    // Older builds use /resources/{id}.
    await _dio.delete('api/v1/resources/$attachmentUid');
  }

  Future<void> _deleteAttachmentCompat(String attachmentUid) async {
    // 0.24 uses /resources/{id}.
    try {
      await _dio.delete('api/v1/resources/$attachmentUid');
      return;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404) rethrow;
    }

    // 0.25+ uses /attachments/{id}.
    await _dio.delete('api/v1/attachments/$attachmentUid');
  }

  Future<void> _deleteAttachmentLegacy(String attachmentUid) async {
    final targetId = _tryParseLegacyResourceId(attachmentUid);
    if (targetId == null) {
      throw FormatException('Invalid legacy attachment id: $attachmentUid');
    }
    await _dio.delete('api/v1/resource/$targetId');
  }

  Future<List<Attachment>> listMemoAttachments({
    required String memoUid,
  }) async {
    if (!useLegacyApi) {
      try {
        return await _listMemoAttachmentsModern(memoUid);
      } on DioException catch (e) {
        if (_shouldFallback(e)) {
          return await _listMemoResources(memoUid);
        }
        rethrow;
      }
    }
    try {
      return await _listMemoResources(memoUid);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return await _listMemoAttachmentsModern(memoUid);
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

  Future<List<Attachment>> _listMemoResources(String memoUid) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid/resources',
      queryParameters: const <String, Object?>{'pageSize': 1000},
    );
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
    return attachments;
  }

  Future<void> setMemoAttachments({
    required String memoUid,
    required List<String> attachmentNames,
  }) async {
    if (!useLegacyApi) {
      try {
        await _setMemoAttachmentsModern(memoUid, attachmentNames);
        return;
      } on DioException catch (e) {
        if (_shouldFallback(e)) {
          await _setMemoResources(memoUid, attachmentNames);
          return;
        }
        rethrow;
      }
    }
    try {
      await _setMemoResources(memoUid, attachmentNames);
      return;
    } on DioException catch (e) {
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    try {
      await _setMemoAttachmentsModern(memoUid, attachmentNames);
      return;
    } on DioException catch (e) {
      if (!_shouldFallbackLegacy(e)) rethrow;
    }

    await _setMemoAttachmentsLegacy(memoUid, attachmentNames);
  }

  Future<void> _setMemoAttachmentsModern(String memoUid, List<String> attachmentNames) async {
    await _dio.patch(
      'api/v1/memos/$memoUid/attachments',
      data: <String, Object?>{
        'name': 'memos/$memoUid',
        'attachments': attachmentNames.map((n) => <String, Object?>{'name': n}).toList(growable: false),
      },
      options: _attachmentOptions(),
    );
  }

  Future<void> _setMemoResources(String memoUid, List<String> attachmentNames) async {
    await _dio.patch(
      'api/v1/memos/$memoUid/resources',
      data: <String, Object?>{
        'name': 'memos/$memoUid',
        'resources': attachmentNames.map((n) => <String, Object?>{'name': n}).toList(growable: false),
      },
      options: _attachmentOptions(),
    );
  }

  Future<void> setMemoRelations({
    required String memoUid,
    required List<Map<String, dynamic>> relations,
  }) async {
    try {
      await _setMemoRelationsModern(memoUid, relations);
    } on DioException catch (e) {
      if (useLegacyApi && _shouldFallbackLegacy(e)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _setMemoRelationsModern(String memoUid, List<Map<String, dynamic>> relations) async {
    await _dio.patch(
      'api/v1/memos/$memoUid/relations',
      data: <String, Object?>{
        'name': 'memos/$memoUid',
        'relations': relations,
      },
    );
  }

  Future<(List<MemoRelation> relations, String nextPageToken)> listMemoRelations({
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
          if (pageToken != null && pageToken.trim().isNotEmpty) 'pageToken': pageToken,
          if (pageToken != null && pageToken.trim().isNotEmpty) 'page_token': pageToken,
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
      final nextToken = _readStringField(body, 'nextPageToken', 'next_page_token');
      return (relations, nextToken);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) {
        return (const <MemoRelation>[], '');
      }
      rethrow;
    }
  }

  Future<({List<Memo> memos, String nextPageToken, int totalSize})> listMemoComments({
    required String memoUid,
    int pageSize = 30,
    String? pageToken,
    String? orderBy,
  }) async {
    if (!useLegacyApi) {
      return _listMemoCommentsModern(
        memoUid: memoUid,
        pageSize: pageSize,
        pageToken: pageToken,
        orderBy: orderBy,
      );
    }
    try {
      return await _listMemoCommentsModern(
        memoUid: memoUid,
        pageSize: pageSize,
        pageToken: pageToken,
        orderBy: orderBy,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return _listMemoCommentsLegacyV2(
          memoUid: memoUid,
        );
      }
      rethrow;
    }
  }

  Future<({List<Memo> memos, String nextPageToken, int totalSize})> _listMemoCommentsModern({
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
        if (pageToken != null && pageToken.trim().isNotEmpty) 'pageToken': pageToken,
        if (pageToken != null && pageToken.trim().isNotEmpty) 'page_token': pageToken,
        if (orderBy != null && orderBy.trim().isNotEmpty) 'orderBy': orderBy.trim(),
        if (orderBy != null && orderBy.trim().isNotEmpty) 'order_by': orderBy.trim(),
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

  Future<({List<Memo> memos, String nextPageToken, int totalSize})> _listMemoCommentsLegacyV2({
    required String memoUid,
  }) async {
    final response = await _dio.get('api/v2/memos/$memoUid/comments');
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
    return (memos: memos, nextPageToken: '', totalSize: memos.length);
  }

  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})> listMemoReactions({
    required String memoUid,
    int pageSize = 50,
    String? pageToken,
  }) async {
    if (!useLegacyApi) {
      return _listMemoReactionsModern(
        memoUid: memoUid,
        pageSize: pageSize,
        pageToken: pageToken,
      );
    }
    try {
      return await _listMemoReactionsModern(
        memoUid: memoUid,
        pageSize: pageSize,
        pageToken: pageToken,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return _listMemoReactionsLegacyV2(
          memoUid: memoUid,
        );
      }
      rethrow;
    }
  }

  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})> _listMemoReactionsModern({
    required String memoUid,
    required int pageSize,
    String? pageToken,
  }) async {
    final response = await _dio.get(
      'api/v1/memos/$memoUid/reactions',
      queryParameters: <String, Object?>{
        if (pageSize > 0) 'pageSize': pageSize,
        if (pageSize > 0) 'page_size': pageSize,
        if (pageToken != null && pageToken.trim().isNotEmpty) 'pageToken': pageToken,
        if (pageToken != null && pageToken.trim().isNotEmpty) 'page_token': pageToken,
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
    final nextToken = _readStringField(body, 'nextPageToken', 'next_page_token');
    var totalSize = 0;
    final totalRaw = body['totalSize'] ?? body['total_size'];
    if (totalRaw is num) {
      totalSize = totalRaw.toInt();
    } else if (totalRaw is String) {
      totalSize = int.tryParse(totalRaw) ?? reactions.length;
    } else {
      totalSize = reactions.length;
    }
    return (reactions: reactions, nextPageToken: nextToken, totalSize: totalSize);
  }

  Future<({List<Reaction> reactions, String nextPageToken, int totalSize})> _listMemoReactionsLegacyV2({
    required String memoUid,
  }) async {
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
    return (reactions: reactions, nextPageToken: '', totalSize: reactions.length);
  }

  Future<Reaction> upsertMemoReaction({
    required String memoUid,
    required String reactionType,
  }) async {
    if (!useLegacyApi) {
      return _upsertMemoReactionModern(
        memoUid: memoUid,
        reactionType: reactionType,
      );
    }
    try {
      return await _upsertMemoReactionModern(
        memoUid: memoUid,
        reactionType: reactionType,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return _upsertMemoReactionLegacyV2(
          memoUid: memoUid,
          reactionType: reactionType,
        );
      }
      rethrow;
    }
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
    final name = reaction.name.trim();
    final legacyId = reaction.legacyId;

    if (!useLegacyApi && name.isNotEmpty) {
      try {
        await _deleteMemoReactionModern(name: name);
        return;
      } on DioException catch (e) {
        if (_shouldFallbackLegacy(e) && legacyId != null && legacyId > 0) {
          await _deleteMemoReactionLegacy(reactionId: legacyId);
          return;
        }
        rethrow;
      }
    }

    if (legacyId != null && legacyId > 0) {
      await _deleteMemoReactionLegacy(reactionId: legacyId);
      return;
    }

    if (name.isNotEmpty) {
      await _deleteMemoReactionModern(name: name);
      return;
    }

    throw ArgumentError('deleteMemoReaction requires reaction name or legacy id');
  }

  Future<void> _deleteMemoReactionModern({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('deleteMemoReaction requires name');
    }
    final path = trimmed.startsWith('memos/') ? 'api/v1/$trimmed' : 'api/v1/memos/$trimmed';
    await _dio.delete(path);
  }

  Future<void> _deleteMemoReactionLegacy({required int reactionId}) async {
    try {
      await _deleteMemoReactionLegacyV1(reactionId: reactionId);
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        await _deleteMemoReactionLegacyV2(reactionId: reactionId);
        return;
      }
      rethrow;
    }
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
    if (!useLegacyApi) {
      return _createMemoCommentModern(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
      );
    }
    try {
      return await _createMemoCommentModern(
        memoUid: memoUid,
        content: content,
        visibility: visibility,
      );
    } on DioException catch (e) {
      if (_shouldFallbackLegacy(e)) {
        return _createMemoCommentLegacyV2(
          memoUid: memoUid,
          content: content,
          visibility: visibility,
        );
      }
      rethrow;
    }
  }

  Future<Memo> _createMemoCommentModern({
    required String memoUid,
    required String content,
    required String visibility,
  }) async {
    final response = await _dio.post(
      'api/v1/memos/$memoUid/comments',
      data: <String, Object?>{
        'content': content,
        'visibility': visibility,
      },
    );
    return Memo.fromJson(_expectJsonMap(response.data));
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
      return Memo.fromJson(memoJson.cast<String, dynamic>());
    }
    return Memo.fromJson(body);
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
    DateTime? displayTime,
  }) async {
    final _ = displayTime;
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
    final response = await _dio.post(
      'api/v1/resource/blob',
      data: formData,
      options: _attachmentOptions(),
    );
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
      options: _attachmentOptions(),
    );
  }

  static Memo _legacyPlaceholderMemo(String memoUid, {required bool pinned}) {
    final normalizedUid = memoUid.trim();
    final name = normalizedUid.isEmpty ? '' : 'memos/$normalizedUid';
    return Memo(
      name: name,
      creator: '',
      content: '',
      contentFingerprint: computeContentFingerprint(''),
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
      contentFingerprint: memo.contentFingerprint,
      visibility: memo.visibility,
      pinned: pinned,
      state: memo.state,
      createTime: memo.createTime,
      updateTime: memo.updateTime,
      tags: memo.tags,
      attachments: memo.attachments,
      displayTime: memo.displayTime,
      location: memo.location,
      relations: memo.relations,
      reactions: memo.reactions,
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

    final content = _readString(json['content']);

    return Memo(
      name: name,
      creator: creator,
      content: content,
      contentFingerprint: computeContentFingerprint(content),
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

  static DateTime? _readTimestamp(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      return parsed?.toUtc();
    }
    if (value is Map) {
      final seconds = _readInt(value['seconds'] ?? value['Seconds']);
      final nanos = _readInt(value['nanos'] ?? value['Nanos']);
      if (seconds <= 0) return null;
      final millis = seconds * 1000 + (nanos ~/ 1000000);
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (value is int || value is num) {
      final raw = _readInt(value);
      if (raw <= 0) return null;
      if (raw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    }
    return null;
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
      final trimmed = value.trimLeft();
      if (_looksLikeHtml(trimmed)) {
        throw const FormatException('Unexpected HTML response. Check server URL or reverse proxy.');
      }
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw const FormatException('Expected JSON object');
  }

  static bool _looksLikeHtml(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.startsWith('<!doctype html') || lower.startsWith('<html');
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

  static PersonalAccessToken _personalAccessTokenFromAccessTokensJson(
    Map<String, dynamic> json, {
    String? tokenValue,
  }) {
    final name = _readString(json['name']);
    final description = _readString(json['description']);
    final issuedAt = _readString(json['issuedAt'] ?? json['issued_at']);
    final expiresAt = _readString(json['expiresAt'] ?? json['expires_at']);
    final token = tokenValue ?? _readString(json['accessToken'] ?? json['access_token']);
    final resolvedName = name.isNotEmpty ? name : token;
    return PersonalAccessToken.fromJson({
      'name': resolvedName,
      'description': description,
      if (issuedAt.isNotEmpty) 'createdAt': issuedAt,
      if (expiresAt.isNotEmpty) 'expiresAt': expiresAt,
    });
  }

  static PersonalAccessToken _personalAccessTokenFromLegacyJson(Map<String, dynamic> json, {required String tokenValue}) {
    final issuedAt = _readString(json['issuedAt'] ?? json['issued_at']);
    final expiresAt = _readString(json['expiresAt'] ?? json['expires_at']);
    final description = _readString(json['description']);
    return PersonalAccessToken.fromJson({
      'name': tokenValue,
      'description': description,
      if (issuedAt.isNotEmpty) 'createdAt': issuedAt,
      if (expiresAt.isNotEmpty) 'expiresAt': expiresAt,
    });
  }
}
