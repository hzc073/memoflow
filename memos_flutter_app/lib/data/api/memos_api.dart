import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/url.dart';
import 'server_api_profile.dart';
import 'server_route_adapter.dart';
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

enum _NotificationApiMode { modern, legacyV1, legacyV2 }

enum _UserStatsApiMode {
  modernGetStats,
  legacyStatsPath,
  legacyMemosStats,
  legacyMemoStats,
}

enum _AttachmentApiMode { attachments, resources, legacy }

enum _ServerApiFlavor { unknown, v0_25Plus, v0_24, v0_23, v0_22, v0_21 }

enum _CurrentUserEndpoint {
  authSessionCurrent,
  authMe,
  authStatusPost,
  authStatusGet,
  authStatusV2,
  userMeV1,
  usersMeV1,
  userMeLegacy,
}

class _ApiCapabilities {
  const _ApiCapabilities({
    required this.allowLegacyMemoEndpoints,
    required this.memoLegacyByDefault,
    required this.preferLegacyAuthChain,
    required this.forceLegacyMemoByPreference,
    required this.defaultAttachmentMode,
    required this.defaultUserStatsMode,
    required this.defaultNotificationMode,
    required this.shortcutsSupportedByDefault,
  });

  final bool allowLegacyMemoEndpoints;
  final bool memoLegacyByDefault;
  final bool preferLegacyAuthChain;
  final bool forceLegacyMemoByPreference;
  final _AttachmentApiMode? defaultAttachmentMode;
  final _UserStatsApiMode? defaultUserStatsMode;
  final _NotificationApiMode? defaultNotificationMode;
  final bool? shortcutsSupportedByDefault;

  static _ApiCapabilities resolve({
    required _ServerApiFlavor flavor,
    required bool useLegacyApi,
  }) {
    final forceLegacyMemoByPreference =
        useLegacyApi && flavor == _ServerApiFlavor.v0_21;
    if (forceLegacyMemoByPreference) {
      return const _ApiCapabilities(
        allowLegacyMemoEndpoints: true,
        memoLegacyByDefault: true,
        preferLegacyAuthChain: true,
        forceLegacyMemoByPreference: true,
        defaultAttachmentMode: _AttachmentApiMode.legacy,
        defaultUserStatsMode: _UserStatsApiMode.legacyMemoStats,
        defaultNotificationMode: _NotificationApiMode.legacyV2,
        shortcutsSupportedByDefault: false,
      );
    }

    final profile = MemosServerApiProfiles.byFlavor(
      _serverFlavorToPublicFlavor(flavor),
    );
    return _ApiCapabilities(
      allowLegacyMemoEndpoints: profile.allowLegacyMemoEndpoints,
      memoLegacyByDefault: profile.memoLegacyByDefault,
      preferLegacyAuthChain: profile.preferLegacyAuthChain,
      forceLegacyMemoByPreference: false,
      defaultAttachmentMode: _attachmentModeFromProfile(
        profile.defaultAttachmentMode,
      ),
      defaultUserStatsMode: _userStatsModeFromProfile(
        profile.defaultUserStatsMode,
      ),
      defaultNotificationMode: _notificationModeFromProfile(
        profile.defaultNotificationMode,
      ),
      shortcutsSupportedByDefault: profile.shortcutsSupportedByDefault,
    );
  }

  static MemosServerFlavor _serverFlavorToPublicFlavor(
    _ServerApiFlavor flavor,
  ) {
    return switch (flavor) {
      _ServerApiFlavor.v0_21 => MemosServerFlavor.v0_21,
      _ServerApiFlavor.v0_22 => MemosServerFlavor.v0_22,
      _ServerApiFlavor.v0_23 => MemosServerFlavor.v0_23,
      _ServerApiFlavor.v0_24 => MemosServerFlavor.v0_24,
      _ServerApiFlavor.v0_25Plus ||
      _ServerApiFlavor.unknown => MemosServerFlavor.v0_25Plus,
    };
  }

  static _AttachmentApiMode _attachmentModeFromProfile(
    MemosAttachmentRouteMode mode,
  ) {
    return switch (mode) {
      MemosAttachmentRouteMode.legacy => _AttachmentApiMode.legacy,
      MemosAttachmentRouteMode.resources => _AttachmentApiMode.resources,
      MemosAttachmentRouteMode.attachments => _AttachmentApiMode.attachments,
    };
  }

  static _UserStatsApiMode _userStatsModeFromProfile(
    MemosUserStatsRouteMode mode,
  ) {
    return switch (mode) {
      MemosUserStatsRouteMode.modernGetStats =>
        _UserStatsApiMode.modernGetStats,
      MemosUserStatsRouteMode.legacyStatsPath =>
        _UserStatsApiMode.legacyStatsPath,
      MemosUserStatsRouteMode.legacyMemosStats =>
        _UserStatsApiMode.legacyMemosStats,
      MemosUserStatsRouteMode.legacyMemoStats =>
        _UserStatsApiMode.legacyMemoStats,
    };
  }

  static _NotificationApiMode _notificationModeFromProfile(
    MemosNotificationRouteMode mode,
  ) {
    return switch (mode) {
      MemosNotificationRouteMode.modern => _NotificationApiMode.modern,
      MemosNotificationRouteMode.legacyV1 => _NotificationApiMode.legacyV1,
      MemosNotificationRouteMode.legacyV2 => _NotificationApiMode.legacyV2,
    };
  }
}

class _ServerVersion implements Comparable<_ServerVersion> {
  const _ServerVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static _ServerVersion? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(trimmed);
    if (match == null) return null;
    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    final patch = int.tryParse(match.group(3) ?? '0');
    if (major == null || minor == null || patch == null) return null;
    return _ServerVersion(major, minor, patch);
  }

  @override
  int compareTo(_ServerVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >=(_ServerVersion other) => compareTo(other) >= 0;
}

class MemosApi {
  MemosApi._(
    this._dio, {
    this.useLegacyApi = false,
    this.strictRouteLock = false,
    this.strictServerVersion,
    InstanceProfile? instanceProfile,
    NetworkLogStore? logStore,
    NetworkLogBuffer? logBuffer,
    BreadcrumbStore? breadcrumbStore,
    LogManager? logManager,
  }) {
    _instanceProfileHint = instanceProfile;
    _logManager = logManager;
    _capabilities = _ApiCapabilities.resolve(
      flavor: _ServerApiFlavor.unknown,
      useLegacyApi: useLegacyApi,
    );
    _memoApiLegacy = _capabilities.memoLegacyByDefault;
    _initializeRouteMode(instanceProfile);
    if (logStore != null ||
        logManager != null ||
        logBuffer != null ||
        breadcrumbStore != null) {
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
  final bool strictRouteLock;
  final String? strictServerVersion;
  InstanceProfile? _instanceProfileHint;
  LogManager? _logManager;
  _ServerApiFlavor _serverFlavor = _ServerApiFlavor.unknown;
  _ServerVersion? _serverVersion;
  String _serverVersionRaw = '';
  bool _serverHintsApplied = false;
  bool _serverHintsLogged = false;
  bool _memoApiLegacy = false;
  _NotificationApiMode? _notificationMode;
  _UserStatsApiMode? _userStatsMode;
  _AttachmentApiMode? _attachmentMode;
  bool? _shortcutsSupported;
  MemosRouteAdapter _routeAdapter = MemosRouteAdapters.fallback();
  _ApiCapabilities _capabilities = _ApiCapabilities.resolve(
    flavor: _ServerApiFlavor.unknown,
    useLegacyApi: false,
  );
  static const Duration _attachmentTimeout = Duration(seconds: 120);
  static const Duration _largeListReceiveTimeout = Duration(seconds: 90);
  static const Object _unset = Object();

  bool get _useLegacyMemos {
    if (_memoApiLegacy) return true;
    return _capabilities.forceLegacyMemoByPreference;
  }

  bool get usesLegacyMemos => _useLegacyMemos;
  bool get usesLegacySearchFilterDialect =>
      _routeAdapter.usesRowStatusMemoStateField;
  bool get supportsMemoParentQuery => _routeAdapter.supportsMemoParentQuery;
  bool get requiresCreatorScopedListMemos =>
      _routeAdapter.requiresCreatorScopedListMemos;
  bool get isRouteProfileV024 =>
      _routeAdapter.profile.flavor == MemosServerFlavor.v0_24;
  bool? get shortcutsSupportedHint => _shortcutsSupported;
  bool get isStrictRouteLocked => strictRouteLock;
  String get effectiveServerVersion {
    if (_serverVersionRaw.trim().isNotEmpty) return _serverVersionRaw.trim();
    final strict = (strictServerVersion ?? '').trim();
    if (strict.isNotEmpty) return strict;
    return '';
  }

  Future<void> ensureServerHintsLoaded() {
    if (strictRouteLock) return Future<void>.value();
    return _ensureServerHints();
  }

  void _initializeRouteMode(InstanceProfile? profile) {
    if (!strictRouteLock) {
      _bootstrapServerHintsFromInstanceProfile(profile);
      return;
    }

    final strictVersion = (strictServerVersion ?? profile?.version ?? '')
        .trim();
    if (strictVersion.isEmpty) {
      throw ArgumentError(
        'strictRouteLock requires strictServerVersion or instanceProfile.version',
      );
    }
    _instanceProfileHint = InstanceProfile(
      version: strictVersion,
      mode: profile?.mode ?? '',
      instanceUrl: profile?.instanceUrl ?? '',
      owner: profile?.owner ?? '',
    );
    _serverVersionRaw = strictVersion;
    _serverVersion = _ServerVersion.tryParse(strictVersion);
    final flavor = _inferServerFlavor(_serverVersion);
    _applyServerHints(flavor);
    _serverHintsApplied = true;
    _logServerHints();
  }

  void _bootstrapServerHintsFromInstanceProfile(InstanceProfile? profile) {
    final rawVersion = profile?.version ?? '';
    if (rawVersion.trim().isEmpty) return;
    _serverVersionRaw = rawVersion;
    _serverVersion = _ServerVersion.tryParse(rawVersion);
    final flavor = _inferServerFlavor(_serverVersion);
    _applyServerHints(flavor);
  }

  void _markMemoLegacy() {
    if (_legacyMemoEndpointsAllowed()) {
      _memoApiLegacy = true;
    }
  }

  Options _attachmentOptions() {
    return Options(
      sendTimeout: _attachmentTimeout,
      receiveTimeout: _attachmentTimeout,
    );
  }

  Future<void> _ensureServerHints() async {
    if (strictRouteLock) return;
    if (_serverHintsApplied) return;
    await _loadServerHints();
  }

  Future<void> _loadServerHints() async {
    if (strictRouteLock) return;
    if (_serverHintsApplied) return;
    InstanceProfile? profile = _instanceProfileHint;
    if (profile == null || profile.version.trim().isEmpty) {
      try {
        profile = await getInstanceProfile();
      } catch (_) {
        profile = null;
      }
    }

    _instanceProfileHint = profile ?? _instanceProfileHint;
    final rawVersion = profile?.version ?? '';
    _serverVersionRaw = rawVersion;
    _serverVersion = _ServerVersion.tryParse(rawVersion);
    final flavor = _inferServerFlavor(_serverVersion);
    _applyServerHints(flavor);
    _logServerHints();
    _serverHintsApplied = true;
  }

  _ServerApiFlavor _inferServerFlavor(_ServerVersion? version) {
    if (version == null) return _ServerApiFlavor.v0_25Plus;
    final v0_25 = _ServerVersion(0, 25, 0);
    final v0_24 = _ServerVersion(0, 24, 0);
    final v0_23 = _ServerVersion(0, 23, 0);
    final v0_22 = _ServerVersion(0, 22, 0);
    if (version >= v0_25) return _ServerApiFlavor.v0_25Plus;
    if (version >= v0_24) return _ServerApiFlavor.v0_24;
    if (version >= v0_23) return _ServerApiFlavor.v0_23;
    if (version >= v0_22) return _ServerApiFlavor.v0_22;
    return _ServerApiFlavor.v0_21;
  }

  MemosRouteAdapter _buildRouteAdapter({
    required _ServerApiFlavor flavor,
    required _ServerVersion? version,
  }) {
    final profile = MemosServerApiProfiles.byFlavor(
      _ApiCapabilities._serverFlavorToPublicFlavor(flavor),
    );
    final parsedVersion = version == null
        ? null
        : MemosVersionNumber(version.major, version.minor, version.patch);
    return MemosRouteAdapters.resolve(
      profile: profile,
      parsedVersion: parsedVersion,
    );
  }

  void _applyServerHints(_ServerApiFlavor flavor) {
    _serverFlavor = flavor;
    _routeAdapter = _buildRouteAdapter(flavor: flavor, version: _serverVersion);
    _capabilities = _ApiCapabilities.resolve(
      flavor: flavor,
      useLegacyApi: useLegacyApi,
    );
    _memoApiLegacy = _capabilities.memoLegacyByDefault;
    _attachmentMode ??= _capabilities.defaultAttachmentMode;
    _userStatsMode ??= _capabilities.defaultUserStatsMode;
    _notificationMode ??= _capabilities.defaultNotificationMode;
    _shortcutsSupported ??= _capabilities.shortcutsSupportedByDefault;
  }

  void _logServerHints() {
    if (_serverHintsLogged) return;
    _serverHintsLogged = true;
    _logManager?.info(
      'Server API hints',
      context: <String, Object?>{
        'versionRaw': _serverVersionRaw,
        'versionParsed': _serverVersion == null
            ? ''
            : '${_serverVersion!.major}.${_serverVersion!.minor}.${_serverVersion!.patch}',
        'flavor': _serverFlavor.name,
        'useLegacyApi': useLegacyApi,
        'memoLegacy': _memoApiLegacy,
        'attachmentMode': _attachmentMode?.name ?? '',
        'userStatsMode': _userStatsMode?.name ?? '',
        'notificationMode': _notificationMode?.name ?? '',
        'routeProfile': _routeAdapter.profile.flavor.name,
        'routeFullView': _routeAdapter.requiresMemoFullView,
        'routeLegacyRowStatusFilter':
            _routeAdapter.usesLegacyRowStatusFilterInListMemos,
        'routeSendState': _routeAdapter.sendsStateInListMemos,
        'shortcutsSupported': _shortcutsSupported,
        'allowLegacyMemoEndpoints': _capabilities.allowLegacyMemoEndpoints,
        'preferLegacyAuthChain': _capabilities.preferLegacyAuthChain,
        'forceLegacyMemoByPreference':
            _capabilities.forceLegacyMemoByPreference,
      },
    );
  }

  factory MemosApi.unauthenticated(
    Uri baseUrl, {
    bool useLegacyApi = false,
    bool strictRouteLock = false,
    String? strictServerVersion,
    InstanceProfile? instanceProfile,
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
      strictRouteLock: strictRouteLock,
      strictServerVersion: strictServerVersion,
      instanceProfile: instanceProfile,
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
    bool strictRouteLock = false,
    String? strictServerVersion,
    InstanceProfile? instanceProfile,
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
      strictRouteLock: strictRouteLock,
      strictServerVersion: strictServerVersion,
      instanceProfile: instanceProfile,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
      logManager: logManager,
    );
  }

  factory MemosApi.sessionAuthenticated({
    required Uri baseUrl,
    required String sessionCookie,
    bool useLegacyApi = false,
    bool strictRouteLock = false,
    String? strictServerVersion,
    InstanceProfile? instanceProfile,
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
        headers: <String, Object?>{'Cookie': sessionCookie},
      ),
    );
    return MemosApi._(
      dio,
      useLegacyApi: useLegacyApi,
      strictRouteLock: strictRouteLock,
      strictServerVersion: strictServerVersion,
      instanceProfile: instanceProfile,
      logStore: logStore,
      logBuffer: logBuffer,
      breadcrumbStore: breadcrumbStore,
      logManager: logManager,
    );
  }

  Future<InstanceProfile> getInstanceProfile() async {
    InstanceProfile? fallbackProfile;
    try {
      final response = await _dio.get('api/v1/instance/profile');
      final profile = InstanceProfile.fromJson(_expectJsonMap(response.data));
      final hasInfo =
          profile.version.trim().isNotEmpty ||
          profile.mode.trim().isNotEmpty ||
          profile.instanceUrl.trim().isNotEmpty ||
          profile.owner.trim().isNotEmpty;
      if (hasInfo) return profile;
      fallbackProfile = profile;
    } on DioException catch (e) {
      if (!_shouldFallbackProfile(e)) rethrow;
    } on FormatException {
      // Try legacy system status below.
    }

    try {
      final response = await _dio.get('api/v1/status');
      final body = _expectJsonMap(response.data);
      final profile = _instanceProfileFromStatus(body);
      final hasInfo =
          profile.version.trim().isNotEmpty ||
          profile.mode.trim().isNotEmpty ||
          profile.instanceUrl.trim().isNotEmpty ||
          profile.owner.trim().isNotEmpty;
      if (hasInfo) return profile;
    } on DioException {
      if (fallbackProfile != null) return fallbackProfile;
      rethrow;
    } on FormatException {
      if (fallbackProfile != null) return fallbackProfile;
      rethrow;
    }

    return fallbackProfile ?? const InstanceProfile.empty();
  }

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

  bool _legacyMemoEndpointsAllowed() {
    return _capabilities.allowLegacyMemoEndpoints;
  }

  bool _supportsLegacyMemoUpdateEndpoint() {
    return _serverFlavor == _ServerApiFlavor.v0_21;
  }

  bool _legacyMemoUpdateEndpointAllowed() {
    return _legacyMemoEndpointsAllowed() && _supportsLegacyMemoUpdateEndpoint();
  }

  void _logMemoFallbackDecision({
    required String operation,
    required bool allowed,
    required String reason,
    DioException? error,
    String? endpoint,
  }) {
    final requestPath = error?.requestOptions.path;
    final statusCode = error?.response?.statusCode;
    final safeEndpoint = (endpoint ?? requestPath ?? '').trim();
    _logManager?.log(
      allowed ? LogLevel.info : LogLevel.warn,
      allowed ? 'Memo legacy fallback enabled' : 'Memo legacy fallback blocked',
      error: error,
      context: <String, Object?>{
        'operation': operation,
        'reason': reason,
        'status': statusCode,
        'endpoint': safeEndpoint,
        'serverFlavor': _serverFlavor.name,
        'serverVersion': _serverVersionRaw,
        'memoLegacy': _memoApiLegacy,
        'useLegacyApi': useLegacyApi,
      },
    );
  }

  bool _ensureLegacyMemoEndpointAllowed(
    String endpoint, {
    required String operation,
  }) {
    if (_legacyMemoEndpointsAllowed()) return true;
    final wasLegacy = _memoApiLegacy;
    if (wasLegacy) {
      _memoApiLegacy = false;
    }
    _logMemoFallbackDecision(
      operation: operation,
      allowed: false,
      reason: 'legacy_endpoint_forbidden_by_flavor',
      endpoint: endpoint,
    );
    return false;
  }

  bool _shouldFallbackProfile(DioException e) {
    if (strictRouteLock) return false;
    final status = e.response?.statusCode ?? 0;
    if (status == 401 || status == 403 || status == 404 || status == 405) {
      return true;
    }
    if (status == 0) {
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown;
    }
    return false;
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

  static InstanceProfile _instanceProfileFromStatus(Map<String, dynamic> body) {
    final profile = _readMap(body['profile']);
    final version = _readString(profile?['version']);
    final mode = _readString(profile?['mode']);

    final customizedProfile = _readMap(
      body['customizedProfile'] ?? body['customized_profile'],
    );
    final instanceUrl = _readString(
      customizedProfile?['externalUrl'] ??
          customizedProfile?['external_url'] ??
          customizedProfile?['instanceUrl'] ??
          customizedProfile?['instance_url'],
    );

    final host = _readMap(body['host']);
    final owner = _readString(
      host?['name'] ?? host?['username'] ?? host?['nickname'] ?? host?['id'],
    );

    return InstanceProfile(
      version: version,
      mode: mode,
      instanceUrl: instanceUrl,
      owner: owner,
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

  bool _usesV025AccessTokenRoutes() {
    final version = _serverVersion;
    return version != null && version.major == 0 && version.minor == 25;
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

    final numericUserId = await _resolveNumericUserId(userName: userName);

    final parent = 'users/$numericUserId';
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
    final numericUserId = await _resolveNumericUserId(userName: userName);
    final parent = 'users/$numericUserId';
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

  static Map<String, dynamic> _unwrapWebhookPayload(Map<String, dynamic> body) {
    final inner = body['webhook'];
    if (inner is Map) {
      return inner.cast<String, dynamic>();
    }
    return body;
  }

  static Map<String, dynamic> _legacyUserSettingPayload(
    String name, {
    required UserGeneralSetting setting,
  }) {
    final data = <String, dynamic>{'name': name};
    if (setting.locale != null && setting.locale!.trim().isNotEmpty) {
      data['locale'] = setting.locale!.trim();
    }
    if (setting.memoVisibility != null &&
        setting.memoVisibility!.trim().isNotEmpty) {
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
    if (trimmed == '\u{2764}\u{FE0F}' ||
        trimmed == '\u{2764}' ||
        trimmed == '\u{2665}')
      return 'HEART';
    if (trimmed == '\u{1F44D}') return 'THUMBS_UP';
    return 'HEART';
  }

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
          notifications.add(
            AppNotification.fromModernJson(item.cast<String, dynamic>()),
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

  Future<({String commentMemoUid, String relatedMemoUid})>
  getMemoCommentActivityRefs({required int activityId}) async {
    await _ensureServerHints();
    if (activityId <= 0) {
      return (commentMemoUid: '', relatedMemoUid: '');
    }

    final activity = _serverFlavor == _ServerApiFlavor.v0_21
        ? await _getActivityLegacyV2(activityId)
        : await _getActivityModern(activityId);
    return _extractMemoCommentRefs(activity);
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

  static String _extractExploreModernContentQuery(String filter) {
    final normalized = filter.trim();
    if (normalized.isEmpty) return '';
    final match = RegExp(
      r'''content\.contains\("((?:\\.|[^"\\])*)"\)''',
    ).firstMatch(normalized);
    if (match == null) return '';
    return _decodeEscapedFilterString(match.group(1) ?? '');
  }

  static String _decodeEscapedFilterString(String escaped) {
    if (escaped.isEmpty) return '';
    try {
      final decoded = jsonDecode('"$escaped"');
      if (decoded is String) return decoded;
    } catch (_) {
      // Fall back to a conservative unescape for malformed payloads.
    }
    return escaped.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
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
        receiveTimeout ??
        (pageSize >= 500 ? _largeListReceiveTimeout : null);
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
    );
  }

  Future<Memo> _createMemoModern({
    required String memoId,
    required String content,
    required String visibility,
    required bool pinned,
    MemoLocation? location,
  }) async {
    final supportsLocation = _supportsMemoLocationField();
    final response = await _dio.post(
      'api/v1/memos',
      queryParameters: <String, Object?>{'memoId': memoId},
      data: <String, Object?>{
        'content': content,
        'visibility': visibility,
        'pinned': pinned,
        if (supportsLocation && location != null) 'location': location.toJson(),
      },
    );
    return _memoFromJson(_expectJsonMap(response.data));
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
        displayTime: displayTime,
      );
    }
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
    final data = <String, Object?>{'name': 'memos/$memoUid'};
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
      final normalizedState = _normalizeLegacyRowStatus(state) ?? state;
      if (_usesRowStatusStateField()) {
        updateMask.add('row_status');
        data['rowStatus'] = _rowStatusStateForUpdate(normalizedState);
      } else {
        updateMask.add('state');
        data['state'] = state;
      }
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
      if (droppedUnsupportedLocation) {
        return getMemo(memoUid: memoUid);
      }
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
    return _memoFromJson(_expectJsonMap(response.data));
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

    final response = await _dio.patch('api/v1/memo/$memoUid', data: data);
    return _memoFromLegacy(_expectJsonMap(response.data));
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

  List<Attachment> _normalizeAttachmentsForServer(
    List<Attachment> attachments,
  ) {
    if (attachments.isEmpty) return attachments;
    var changed = false;
    final normalized = <Attachment>[];
    for (final attachment in attachments) {
      final next = _normalizeAttachmentForServer(attachment);
      if (!identical(next, attachment)) {
        changed = true;
      }
      normalized.add(next);
    }
    return changed ? normalized : attachments;
  }

  Attachment _normalizeAttachmentForServer(Attachment attachment) {
    final name = attachment.name.trim();
    final isLegacyResource = name.startsWith('resources/');
    if (!isLegacyResource) return attachment;
    final external = attachment.externalLink.trim();
    if (_serverFlavor == _ServerApiFlavor.v0_22) {
      if (external.isNotEmpty) return attachment;
      return Attachment(
        name: attachment.name,
        filename: attachment.filename,
        type: attachment.type,
        size: attachment.size,
        externalLink: '/file/$name',
      );
    }

    // Repair stale links generated by old client logic on 0.23+.
    if (external.isNotEmpty &&
        RegExp(r'^/file/resources/\d+$').hasMatch(external) &&
        attachment.filename.trim().isNotEmpty) {
      return Attachment(
        name: attachment.name,
        filename: attachment.filename,
        type: attachment.type,
        size: attachment.size,
        externalLink: '/file/$name/${attachment.filename}',
      );
    }
    return attachment;
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
    final creatorName = _readString(
      json['creatorName'] ?? json['creator_name'],
    );
    final creator = creatorId.isNotEmpty ? 'users/$creatorId' : creatorName;

    final stateRaw = _readString(
      json['rowStatus'] ?? json['row_status'] ?? json['state'],
    );
    final state = _normalizeLegacyRowStatus(stateRaw) ?? 'NORMAL';

    final attachments = _readLegacyAttachments(
      json['resourceList'] ?? json['resources'] ?? json['attachments'],
    );

    final content = _readString(json['content']);

    return Memo(
      name: name,
      creator: creator,
      content: content,
      contentFingerprint: computeContentFingerprint(content),
      visibility: _readString(json['visibility']).isNotEmpty
          ? _readString(json['visibility'])
          : 'PRIVATE',
      pinned: _readBool(json['pinned']),
      state: state,
      createTime: _readLegacyTime(
        json['createdTs'] ?? json['created_ts'] ?? json['createTime'],
      ),
      updateTime: _readLegacyTime(
        json['updatedTs'] ?? json['updated_ts'] ?? json['updateTime'],
      ),
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
    final externalRaw = _readString(
      json['externalLink'] ?? json['external_link'],
    );
    var name = nameRaw.isNotEmpty ? nameRaw : uidRaw;
    if (name.isEmpty && id.isNotEmpty) {
      name = id;
    }
    if (name.isNotEmpty && !name.startsWith('resources/')) {
      name = 'resources/$name';
    }
    final externalLink = externalRaw.isNotEmpty
        ? externalRaw
        : (uidRaw.isNotEmpty ? '/o/r/$uidRaw' : '');
    return Attachment(
      name: name,
      filename: _readString(json['filename']),
      type: _readString(json['type']),
      size: _readInt(json['size']),
      externalLink: externalLink,
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
      final list =
          map['memos'] ??
          map['memoList'] ??
          map['resources'] ??
          map['attachments'] ??
          map['data'];
      if (list is List) return list;
    }
    return const [];
  }

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    if (value == null) return '';
    return value.toString().trim();
  }

  static Map<String, dynamic>? _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
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
      return DateTime.tryParse(value.trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final seconds = _readInt(value);
    if (seconds <= 0)
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static DateTime? _parseStatsDateKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return DateTime.tryParse('${trimmed}T00:00:00Z');
    }
    final parsed = DateTime.tryParse(trimmed);
    return parsed?.toUtc();
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
    if (normalized == 'ACTIVE' || normalized.endsWith('_ACTIVE')) {
      return 'NORMAL';
    }
    if (normalized.contains('NORMAL')) return 'NORMAL';
    return normalized;
  }

  static int? _tryParseLegacyCreatorId(String? filter) {
    final raw = (filter ?? '').trim();
    if (raw.isEmpty) return null;
    final creatorIdMatch = RegExp(r'creator_id\s*==\s*(\d+)').firstMatch(raw);
    if (creatorIdMatch != null) {
      return int.tryParse(creatorIdMatch.group(1) ?? '');
    }
    final creatorNameMatch = RegExp(
      r'''creator\s*==\s*['"]users/(\d+)['"]''',
    ).firstMatch(raw);
    if (creatorNameMatch == null) return null;
    return int.tryParse(creatorNameMatch.group(1) ?? '');
  }

  static String? _buildLegacyV2SearchFilter({
    required String searchQuery,
    int? creatorId,
    String? state,
    String? tag,
    int? startTimeSec,
    int? endTimeSecExclusive,
    required int limit,
  }) {
    final conditions = <String>[];

    if (creatorId != null) {
      conditions.add("creator == 'users/$creatorId'");
    }

    final normalizedState = _normalizeLegacyRowStatus(state);
    if (normalizedState != null && normalizedState.isNotEmpty) {
      conditions.add(
        "row_status == '${_escapeLegacyFilterString(normalizedState)}'",
      );
    }

    final terms = <String>{};
    final normalizedSearch = searchQuery.trim();
    if (normalizedSearch.isNotEmpty) {
      terms.add(normalizedSearch);
    }

    final normalizedTag = _normalizeLegacySearchTag(tag);
    if (normalizedTag.isNotEmpty) {
      terms.add('#$normalizedTag');
      terms.add(normalizedTag);
    }

    if (terms.isNotEmpty) {
      final quotedTerms = terms
          .map((term) => "'${_escapeLegacyFilterString(term)}'")
          .join(', ');
      conditions.add('content_search == [$quotedTerms]');
    }

    if (startTimeSec != null) {
      conditions.add('display_time_after == $startTimeSec');
    }
    if (endTimeSecExclusive != null) {
      final endInclusive = endTimeSecExclusive - 1;
      if (endInclusive >= 0) {
        conditions.add('display_time_before == $endInclusive');
      }
    }

    var effectiveLimit = limit;
    if (effectiveLimit <= 0) {
      effectiveLimit = 10;
    }
    if (effectiveLimit > 1000) {
      effectiveLimit = 1000;
    }
    conditions.add('limit == $effectiveLimit');

    if (conditions.isEmpty) return null;
    return conditions.join(' && ');
  }

  static String _normalizeLegacySearchTag(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  }

  static String _escapeLegacyFilterString(String raw) {
    return raw
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', ' ');
  }

  static int? _tryParseLegacyResourceId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.startsWith('resources/')
        ? trimmed.substring('resources/'.length)
        : trimmed;
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
        throw const FormatException(
          'Unexpected HTML response. Check server URL or reverse proxy.',
        );
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

  static String _readStringField(
    Map<String, dynamic> body,
    String key,
    String altKey,
  ) {
    final primary = body[key];
    if (primary is String) return primary;
    if (primary is num) return primary.toString();
    final alt = body[altKey];
    if (alt is String) return alt;
    if (alt is num) return alt.toString();
    return '';
  }

  static PersonalAccessToken _personalAccessTokenFromLegacyJson(
    Map<String, dynamic> json, {
    required String tokenValue,
  }) {
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

  static PersonalAccessToken _personalAccessTokenFromV025Json(
    Map<String, dynamic> json, {
    required String tokenValue,
  }) {
    final issuedAt = _readString(json['issuedAt'] ?? json['issued_at']);
    final expiresAt = _readString(json['expiresAt'] ?? json['expires_at']);
    final description = _readString(json['description']);
    final name = _readString(json['name']);
    return PersonalAccessToken.fromJson({
      'name': name.isNotEmpty ? name : tokenValue,
      'description': description,
      if (issuedAt.isNotEmpty) 'createdAt': issuedAt,
      if (expiresAt.isNotEmpty) 'expiresAt': expiresAt,
    });
  }
}
