part of '../memos_api.dart';

abstract class _MemosApiBase {
  _MemosApiBase._(
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
  final Map<int, ({String commentMemoUid, String relatedMemoUid})>
  _notificationRefsById =
      <int, ({String commentMemoUid, String relatedMemoUid})>{};

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
    return Options();
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

  bool _legacyMemoEndpointsAllowed() {
    return _capabilities.allowLegacyMemoEndpoints;
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
}

class MemosApi extends _MemosApiBase
    with
        _MemosApiAuth,
        _MemosApiNotifications,
        _MemosApiResources,
        _MemosApiMemos {
  MemosApi._(
    super.dio, {
    super.useLegacyApi,
    super.strictRouteLock,
    super.strictServerVersion,
    super.instanceProfile,
    super.logStore,
    super.logBuffer,
    super.breadcrumbStore,
    super.logManager,
  }) : super._();

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
}
