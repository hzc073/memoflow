part of '../memos_api.dart';

mixin _MemosApiAuth on _MemosApiBase {
  Future<User> getCurrentUser() async {
    await _ensureServerHints();
    final attempts = _currentUserAttempts();
    if (attempts.isEmpty) {
      throw StateError('No current user endpoint configured');
    }
    return _runCurrentUserAttempt(attempts.first);
  }

  List<_CurrentUserEndpoint> _currentUserAttempts() {
    return _routeAdapter.currentUserRoutes
        .map(_mapCurrentUserRoute)
        .toList(growable: false);
  }

  _CurrentUserEndpoint _mapCurrentUserRoute(MemosCurrentUserRoute route) {
    return switch (route) {
      MemosCurrentUserRoute.authSessionCurrent =>
        _CurrentUserEndpoint.authSessionCurrent,
      MemosCurrentUserRoute.authMe => _CurrentUserEndpoint.authMe,
      MemosCurrentUserRoute.authStatusPost =>
        _CurrentUserEndpoint.authStatusPost,
      MemosCurrentUserRoute.authStatusGet => _CurrentUserEndpoint.authStatusGet,
      MemosCurrentUserRoute.authStatusV2 => _CurrentUserEndpoint.authStatusV2,
      MemosCurrentUserRoute.userMeV1 => _CurrentUserEndpoint.userMeV1,
      MemosCurrentUserRoute.usersMeV1 => _CurrentUserEndpoint.usersMeV1,
      MemosCurrentUserRoute.userMeLegacy => _CurrentUserEndpoint.userMeLegacy,
    };
  }

  Future<User> _runCurrentUserAttempt(_CurrentUserEndpoint endpoint) {
    return switch (endpoint) {
      _CurrentUserEndpoint.authSessionCurrent =>
        _getCurrentUserBySessionCurrent(),
      _CurrentUserEndpoint.authMe => _getCurrentUserByAuthMe(),
      _CurrentUserEndpoint.authStatusPost => _getCurrentUserByAuthStatusPost(),
      _CurrentUserEndpoint.authStatusGet => _getCurrentUserByAuthStatusGet(),
      _CurrentUserEndpoint.authStatusV2 => _getCurrentUserByAuthStatusV2(),
      _CurrentUserEndpoint.userMeV1 => _getCurrentUserByUserMeV1(),
      _CurrentUserEndpoint.usersMeV1 => _getCurrentUserByUsersMeV1(),
      _CurrentUserEndpoint.userMeLegacy => _getCurrentUserByUserMeLegacy(),
    };
  }

  bool _usesLegacyUserSettingRoute() {
    return _serverFlavor == _ServerApiFlavor.v0_21 ||
        _serverFlavor == _ServerApiFlavor.v0_22 ||
        _serverFlavor == _ServerApiFlavor.v0_23 ||
        _serverFlavor == _ServerApiFlavor.v0_24;
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
    final response = await _dio.post(
      'api/v1/auth/status',
      data: const <String, Object?>{},
    );
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
    final response = await _dio.post(
      'api/v2/auth/status',
      data: const <String, Object?>{},
    );
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

    await _ensureServerHints();

    Future<User> callModern() async {
      final normalized = raw.startsWith('users/') ? raw : 'users/$raw';
      final response = await _dio.get('api/v1/$normalized');
      final body = _expectJsonMap(response.data);
      final userJson = body['user'];
      if (userJson is Map) {
        return User.fromJson(userJson.cast<String, dynamic>());
      }
      return User.fromJson(body);
    }

    Future<User> callLegacy() async {
      var legacyKey = raw.startsWith('users/')
          ? raw.substring('users/'.length)
          : raw;
      legacyKey = legacyKey.trim();
      if (legacyKey.isEmpty) {
        throw const FormatException('Invalid legacy user identifier');
      }
      final numeric = int.tryParse(legacyKey);
      final path = numeric != null
          ? 'api/v1/user/$numeric'
          : 'api/v1/user/name/$legacyKey';
      final response = await _dio.get(path);
      return User.fromJson(_expectJsonMap(response.data));
    }

    if (_capabilities.preferLegacyAuthChain) {
      return callLegacy();
    }
    return callModern();
  }

  Future<UserStatsSummary> getUserStatsSummary({String? userName}) async {
    await _ensureServerHints();
    // Memos 0.23 does not expose a stable user-stats endpoint in v1 API.
    if (_serverFlavor == _ServerApiFlavor.v0_23) {
      return const UserStatsSummary(
        memoDisplayTimes: <DateTime>[],
        totalMemoCount: 0,
      );
    }
    final mode =
        _userStatsMode ??
        _capabilities.defaultUserStatsMode ??
        _UserStatsApiMode.modernGetStats;
    _userStatsMode = mode;
    switch (mode) {
      case _UserStatsApiMode.modernGetStats:
        return _getUserStatsModernGetStats(userName: userName);
      case _UserStatsApiMode.legacyStatsPath:
        return _getUserStatsLegacyStatsPath(userName: userName);
      case _UserStatsApiMode.legacyMemosStats:
        return _getUserStatsLegacyMemosStats(userName: userName);
      case _UserStatsApiMode.legacyMemoStats:
        final summary = await _getUserStatsLegacyMemoStats(userName: userName);
        _markMemoLegacy();
        return summary;
    }
  }

  Future<UserStatsSummary> _getUserStatsModernGetStats({
    String? userName,
  }) async {
    final name = await _resolveUserName(userName: userName);
    final response = await _dio.get('api/v1/$name:getStats');
    final body = _expectJsonMap(response.data);
    return _parseUserStats(body);
  }

  Future<UserStatsSummary> _getUserStatsLegacyStatsPath({
    String? userName,
  }) async {
    final name = await _resolveUserName(userName: userName);
    final response = await _dio.get('api/v1/$name/stats');
    final body = _expectJsonMap(response.data);
    return _parseUserStats(body);
  }

  Future<UserStatsSummary> _getUserStatsLegacyMemosStats({
    String? userName,
  }) async {
    final name = await _resolveUserName(userName: userName);
    final response = await _dio.get(
      'api/v1/memos/stats',
      queryParameters: <String, Object?>{'name': name},
    );
    final body = _expectJsonMap(response.data);
    final rawStats = _readMap(body['stats']) ?? body;
    final times = <DateTime>[];
    var total = 0;
    for (final entry in rawStats.entries) {
      final dateKey = entry.key.toString();
      final count = _readInt(entry.value);
      if (count <= 0) continue;
      final dt = _parseStatsDateKey(dateKey);
      if (dt == null) continue;
      total += count;
      for (var i = 0; i < count; i++) {
        times.add(dt);
      }
    }
    if (total <= 0) {
      total = times.length;
    }
    return UserStatsSummary(memoDisplayTimes: times, totalMemoCount: total);
  }

  Future<UserStatsSummary> _getUserStatsLegacyMemoStats({
    String? userName,
  }) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final response = await _dio.get(
      'api/v1/memo/stats',
      queryParameters: <String, Object?>{'creatorId': numericUserId},
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
    final list =
        body['memoDisplayTimestamps'] ?? body['memo_display_timestamps'];
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
    return UserStatsSummary(memoDisplayTimes: times, totalMemoCount: total);
  }

  Future<String> _resolveNumericUserId({String? userName}) async {
    String effectiveUserName = (userName ?? '').trim();
    String? numericUserId = _tryExtractNumericUserId(effectiveUserName);

    Future<void> resolveFromUserName() async {
      if (numericUserId != null) return;
      if (effectiveUserName.isEmpty) return;

      final identifier = effectiveUserName.contains('/')
          ? effectiveUserName.split('/').last.trim()
          : effectiveUserName;
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
      throw FormatException(
        'Unable to determine numeric user id from "$effectiveUserName"',
      );
    }
    return numericUserId!;
  }

  Future<String> _resolveUserName({String? userName}) async {
    final raw = (userName ?? '').trim();
    if (_usesUsernameUserResourceNames()) {
      final token = raw.contains('/') ? raw.split('/').last.trim() : raw;
      if (token.isNotEmpty && int.tryParse(token) == null) {
        return raw.startsWith('users/') ? raw : 'users/$token';
      }
    } else if (raw.isNotEmpty) {
      return raw.startsWith('users/') ? raw : 'users/$raw';
    }
    final currentUser = await getCurrentUser();
    final name = currentUser.name.trim();
    if (name.isEmpty) {
      throw const FormatException('Unable to determine user name');
    }
    return name.startsWith('users/') ? name : 'users/$name';
  }

  bool _usesV025AccessTokenRoutes() {
    final version = _serverVersion;
    return version != null && version.major == 0 && version.minor == 25;
  }

  bool _usesUsernameUserResourceNames() {
    final version = _serverVersion;
    return version != null && version.major == 0 && version.minor >= 27;
  }

  Future<String> createUserAccessToken({
    String? userName,
    required String description,
    required int expiresInDays,
  }) async {
    final result = await createPersonalAccessToken(
      userName: userName,
      description: description,
      expiresInDays: expiresInDays,
    );
    return result.token;
  }

  Future<({PersonalAccessToken personalAccessToken, String token})>
  createPersonalAccessToken({
    String? userName,
    required String description,
    required int expiresInDays,
  }) async {
    await _ensureServerHints();
    if (_serverFlavor == _ServerApiFlavor.v0_25Plus) {
      return _createPersonalAccessTokenModern(
        userName: userName,
        description: description,
        expiresInDays: expiresInDays,
      );
    }
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return _createPersonalAccessTokenLegacyV2(
        userName: userName,
        description: description,
        expiresInDays: expiresInDays,
      );
    }
    return _createPersonalAccessTokenLegacy(
      userName: userName,
      description: description,
      expiresInDays: expiresInDays,
    );
  }

  Future<({PersonalAccessToken personalAccessToken, String token})>
  _createPersonalAccessTokenModern({
    String? userName,
    required String description,
    required int expiresInDays,
  }) async {
    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) {
      throw ArgumentError('createPersonalAccessToken requires description');
    }

    final parent = _usesUsernameUserResourceNames()
        ? await _resolveUserName(userName: userName)
        : 'users/${await _resolveNumericUserId(userName: userName)}';
    if (_usesV025AccessTokenRoutes()) {
      final expiresAt = expiresInDays > 0
          ? DateTime.now().toUtc().add(Duration(days: expiresInDays))
          : null;
      final response = await _dio.post(
        'api/v1/$parent/accessTokens',
        data: <String, Object?>{
          'description': trimmedDescription,
          if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        },
      );
      final body = _expectJsonMap(response.data);
      final token = _readString(
        body['accessToken'] ?? body['access_token'] ?? body['token'],
      );
      if (token.isEmpty || token == 'null') {
        throw const FormatException('Token missing in response');
      }
      final personalAccessToken = _personalAccessTokenFromV025Json(
        body,
        tokenValue: token,
      );
      return (personalAccessToken: personalAccessToken, token: token);
    }

    final response = await _dio.post(
      'api/v1/$parent/personalAccessTokens',
      data: <String, Object?>{
        'parent': parent,
        'description': trimmedDescription,
        'expiresInDays': expiresInDays,
      },
    );
    final body = _expectJsonMap(response.data);
    final token = _readString(body['token'] ?? body['accessToken']);
    if (token.isEmpty || token == 'null') {
      throw const FormatException('Token missing in response');
    }
    final patJson =
        body['personalAccessToken'] ?? body['personal_access_token'];
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

  Future<({PersonalAccessToken personalAccessToken, String token})>
  _createPersonalAccessTokenLegacyV2({
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
    final expiresAt = expiresInDays > 0
        ? DateTime.now().toUtc().add(Duration(days: expiresInDays))
        : null;

    final response = await _dio.post(
      'api/v2/$name/access_tokens',
      data: <String, Object?>{
        'description': trimmedDescription,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
      },
    );

    final body = _expectJsonMap(response.data);
    final payload = body['accessToken'] ?? body['access_token'];
    if (payload is! Map) {
      throw const FormatException('accessToken missing in response');
    }
    final json = payload.cast<String, dynamic>();
    final token = _readString(json['accessToken'] ?? json['access_token']);
    if (token.isEmpty) {
      throw const FormatException('Token missing in response');
    }

    final pat = _personalAccessTokenFromLegacyJson(json, tokenValue: token);
    return (personalAccessToken: pat, token: token);
  }

  Future<({PersonalAccessToken personalAccessToken, String token})>
  _createPersonalAccessTokenLegacy({
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
    final expiresAt = expiresInDays > 0
        ? DateTime.now().toUtc().add(Duration(days: expiresInDays))
        : null;

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

  Future<List<PersonalAccessToken>> listPersonalAccessTokens({
    String? userName,
  }) async {
    await _ensureServerHints();
    if (_serverFlavor == _ServerApiFlavor.v0_25Plus) {
      return _listPersonalAccessTokensModern(userName: userName);
    }
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return _listPersonalAccessTokensLegacyV2(userName: userName);
    }
    return _listPersonalAccessTokensLegacy(userName: userName);
  }

  Future<List<PersonalAccessToken>> _listPersonalAccessTokensModern({
    String? userName,
  }) async {
    final parent = _usesUsernameUserResourceNames()
        ? await _resolveUserName(userName: userName)
        : 'users/${await _resolveNumericUserId(userName: userName)}';
    if (_usesV025AccessTokenRoutes()) {
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
            final map = item.cast<String, dynamic>();
            final tokenValue = _readString(
              map['accessToken'] ?? map['access_token'],
            );
            if (tokenValue.isEmpty) continue;
            tokens.add(
              _personalAccessTokenFromV025Json(map, tokenValue: tokenValue),
            );
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
          tokens.add(
            PersonalAccessToken.fromJson(item.cast<String, dynamic>()),
          );
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

  Future<List<PersonalAccessToken>> _listPersonalAccessTokensLegacy({
    String? userName,
  }) async {
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
          final tokenValue = _readString(
            map['accessToken'] ?? map['access_token'],
          );
          if (tokenValue.isEmpty) continue;
          tokens.add(
            _personalAccessTokenFromLegacyJson(map, tokenValue: tokenValue),
          );
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

  Future<List<PersonalAccessToken>> _listPersonalAccessTokensLegacyV2({
    String? userName,
  }) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final name = 'users/$numericUserId';

    final response = await _dio.get('api/v2/$name/access_tokens');
    final body = _expectJsonMap(response.data);
    final list = body['accessTokens'] ?? body['access_tokens'];

    final tokens = <PersonalAccessToken>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final map = item.cast<String, dynamic>();
          final tokenValue = _readString(
            map['accessToken'] ?? map['access_token'],
          );
          if (tokenValue.isEmpty) continue;
          tokens.add(
            _personalAccessTokenFromLegacyJson(map, tokenValue: tokenValue),
          );
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
    await _ensureServerHints();
    final resolvedName = await _resolveUserName(userName: userName);
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return _getUserGeneralSettingLegacyV2(userName: resolvedName);
    }
    if (_usesLegacyUserSettingRoute()) {
      return _getUserGeneralSettingLegacyV1(userName: resolvedName);
    }
    return _getUserGeneralSettingModern(
      userName: resolvedName,
      settingKey: 'GENERAL',
    );
  }

  Future<UserGeneralSetting> updateUserGeneralSetting({
    String? userName,
    required UserGeneralSetting setting,
    required List<String> updateMask,
  }) async {
    await _ensureServerHints();
    final resolvedName = await _resolveUserName(userName: userName);
    final modernMask = _normalizeGeneralSettingMask(updateMask);
    if (modernMask.isEmpty) {
      throw ArgumentError('updateUserGeneralSetting requires updateMask');
    }
    final legacyMask = _normalizeLegacyGeneralSettingMask(updateMask);
    if (legacyMask.isEmpty) {
      throw ArgumentError('updateUserGeneralSetting requires updateMask');
    }

    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return _updateUserGeneralSettingLegacyV2(
        userName: resolvedName,
        setting: setting,
        updateMask: legacyMask,
      );
    }
    if (_usesLegacyUserSettingRoute()) {
      return _updateUserGeneralSettingLegacyV1(
        userName: resolvedName,
        setting: setting,
        updateMask: legacyMask,
      );
    }
    return _updateUserGeneralSettingModern(
      userName: resolvedName,
      settingKey: 'GENERAL',
      setting: setting,
      updateMask: modernMask,
    );
  }

  Future<List<Shortcut>> listShortcuts({String? userName}) async {
    await _ensureServerHints();
    if (_useLegacyMemos || _shortcutsSupported == false) {
      return const <Shortcut>[];
    }

    final parent = await _resolveUserName(userName: userName);
    final shortcuts = await _listShortcutsModern(parent: parent);
    _shortcutsSupported = true;
    return shortcuts;
  }

  Future<Shortcut> createShortcut({
    String? userName,
    required String title,
    required String filter,
  }) async {
    await _ensureServerHints();
    if (_useLegacyMemos || _shortcutsSupported == false) {
      throw UnsupportedError('Shortcuts are not supported on this server');
    }

    final parent = await _resolveUserName(userName: userName);
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('createShortcut requires title');
    }
    final response = await _dio.post(
      'api/v1/$parent/shortcuts',
      data: <String, Object?>{'title': trimmedTitle, 'filter': filter},
    );
    _shortcutsSupported = true;
    return Shortcut.fromJson(_expectJsonMap(response.data));
  }

  Future<Shortcut> updateShortcut({
    String? userName,
    required Shortcut shortcut,
    required String title,
    required String filter,
  }) async {
    await _ensureServerHints();
    if (_useLegacyMemos || _shortcutsSupported == false) {
      throw UnsupportedError('Shortcuts are not supported on this server');
    }

    final parent = await _resolveUserName(userName: userName);
    final shortcutId = shortcut.shortcutId;
    if (shortcutId.isEmpty) {
      throw ArgumentError('updateShortcut requires shortcut id');
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('updateShortcut requires title');
    }
    final shortcutPayload = <String, Object?>{
      if (shortcut.name.trim().isNotEmpty) 'name': shortcut.name.trim(),
      if (shortcut.id.trim().isNotEmpty) 'id': shortcut.id.trim(),
      'title': trimmedTitle,
      'filter': filter,
    };
    final response = await _dio.patch(
      'api/v1/$parent/shortcuts/$shortcutId',
      queryParameters: const <String, Object?>{
        'updateMask': 'title,filter',
        'update_mask': 'title,filter',
      },
      data: shortcutPayload,
    );
    _shortcutsSupported = true;
    return Shortcut.fromJson(_expectJsonMap(response.data));
  }

  Future<void> deleteShortcut({
    String? userName,
    required Shortcut shortcut,
  }) async {
    await _ensureServerHints();
    if (_useLegacyMemos || _shortcutsSupported == false) {
      throw UnsupportedError('Shortcuts are not supported on this server');
    }

    final parent = await _resolveUserName(userName: userName);
    final shortcutId = shortcut.shortcutId;
    if (shortcutId.isEmpty) {
      throw ArgumentError('deleteShortcut requires shortcut id');
    }
    await _dio.delete('api/v1/$parent/shortcuts/$shortcutId');
    _shortcutsSupported = true;
  }

  Future<List<UserWebhook>> listUserWebhooks({String? userName}) async {
    await _ensureServerHints();
    final resolvedName = await _resolveUserName(userName: userName);
    if (_serverFlavor == _ServerApiFlavor.v0_25Plus) {
      return _listUserWebhooksModern(userName: resolvedName);
    }
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return _listUserWebhooksLegacyV2(userName: resolvedName);
    }
    return _listUserWebhooksLegacyV1(userName: resolvedName);
  }

  Future<UserWebhook> createUserWebhook({
    String? userName,
    required String displayName,
    required String url,
  }) async {
    await _ensureServerHints();
    final resolvedName = await _resolveUserName(userName: userName);
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError('createUserWebhook requires url');
    }
    if (_serverFlavor == _ServerApiFlavor.v0_25Plus) {
      return _createUserWebhookModern(
        userName: resolvedName,
        displayName: displayName,
        url: trimmedUrl,
      );
    }
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return _createUserWebhookLegacyV2(
        userName: resolvedName,
        displayName: displayName,
        url: trimmedUrl,
      );
    }
    return _createUserWebhookLegacyV1(
      userName: resolvedName,
      displayName: displayName,
      url: trimmedUrl,
    );
  }

  Future<UserWebhook> updateUserWebhook({
    required UserWebhook webhook,
    required String displayName,
    required String url,
  }) async {
    await _ensureServerHints();
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError('updateUserWebhook requires url');
    }
    if (_serverFlavor == _ServerApiFlavor.v0_25Plus) {
      if (webhook.isLegacy) {
        throw ArgumentError('updateUserWebhook requires webhook name');
      }
      return _updateUserWebhookModern(
        webhook: webhook,
        displayName: displayName,
        url: trimmedUrl,
      );
    }
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      return _updateUserWebhookLegacyV2(
        webhook: webhook,
        displayName: displayName,
        url: trimmedUrl,
      );
    }
    return _updateUserWebhookLegacyV1(
      webhook: webhook,
      displayName: displayName,
      url: trimmedUrl,
    );
  }

  Future<void> deleteUserWebhook({required UserWebhook webhook}) async {
    await _ensureServerHints();
    if (_serverFlavor == _ServerApiFlavor.v0_25Plus) {
      if (webhook.isLegacy) {
        throw ArgumentError('deleteUserWebhook requires name');
      }
      await _deleteUserWebhookModern(webhook: webhook);
      return;
    }
    if (_serverFlavor == _ServerApiFlavor.v0_21) {
      await _deleteUserWebhookLegacyV2(webhook: webhook);
      return;
    }
    await _deleteUserWebhookLegacyV1(webhook: webhook);
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

  Future<UserGeneralSetting> _getUserGeneralSettingLegacyV1({
    required String userName,
  }) async {
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final name = 'users/$numericUserId/setting';
    final response = await _dio.get('api/v1/$name');
    final body = _expectJsonMap(response.data);
    final payload = body['setting'];
    final json = payload is Map ? payload.cast<String, dynamic>() : body;
    final setting = UserSetting.fromJson(json);
    return setting.generalSetting ?? const UserGeneralSetting();
  }

  Future<UserGeneralSetting> _getUserGeneralSettingLegacyV2({
    required String userName,
  }) async {
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

  Future<List<UserWebhook>> _listUserWebhooksModern({
    required String userName,
  }) async {
    final response = await _dio.get('api/v1/$userName/webhooks');
    final body = _expectJsonMap(response.data);
    final list = body['webhooks'];
    return _parseUserWebhooks(list);
  }

  Future<List<UserWebhook>> _listUserWebhooksLegacyV1({
    required String userName,
  }) async {
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

  Future<List<UserWebhook>> _listUserWebhooksLegacyV2({
    required String userName,
  }) async {
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
      data: <String, Object?>{'name': label, 'url': url},
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
      data: <String, Object?>{'name': label, 'url': url},
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
        'name': displayName.trim().isNotEmpty
            ? displayName.trim()
            : webhook.name,
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
        'name': displayName.trim().isNotEmpty
            ? displayName.trim()
            : webhook.name,
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

  Future<void> _deleteUserWebhookLegacyV2({
    required UserWebhook webhook,
  }) async {
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
}
