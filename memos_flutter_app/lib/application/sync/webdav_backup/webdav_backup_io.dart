part of '../webdav_backup_service.dart';

mixin _WebDavBackupIoMixin on _WebDavBackupServiceBase {
  @override
  Future<void> _putJson(
    WebDavClient client,
    Uri uri,
    Map<String, dynamic> json,
  ) async {
    final encoded = utf8.encode(jsonEncode(json));
    await _putBytes(client, uri, encoded);
  }

  @override
  Future<void> _putBytes(WebDavClient client, Uri uri, List<int> bytes) async {
    final res = await client.put(uri, body: bytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        method: 'PUT',
        uri: uri,
      );
    }
  }

  @override
  Future<Uint8List?> _getBytes(WebDavClient client, Uri uri) async {
    final res = await client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        method: 'GET',
        uri: uri,
      );
    }
    return Uint8List.fromList(res.bytes);
  }

  @override
  Future<void> _delete(WebDavClient client, Uri uri) async {
    final res = await client.delete(uri);
    if (res.statusCode == 404) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(
        statusCode: res.statusCode,
        method: 'DELETE',
        uri: uri,
      );
    }
  }

  @override
  Uri _configUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, _backupConfigFile),
    );
  }

  @override
  Uri _indexUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, _backupIndexFile),
    );
  }

  @override
  Uri _objectUri(Uri baseUrl, String rootPath, String accountId, String hash) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, '$_backupObjectsDir/$hash.bin'),
    );
  }

  @override
  Uri _snapshotUri(
    Uri baseUrl,
    String rootPath,
    String accountId,
    String snapshotId,
  ) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(
        accountId,
        '$_backupSnapshotsDir/$snapshotId.enc',
      ),
    );
  }

  @override
  String _backupBase(String accountId, String relative) {
    return 'accounts/$accountId/$_backupDir/$_backupVersion/$relative';
  }

  @override
  String _backupBaseDir(String accountId) {
    return 'accounts/$accountId/$_backupDir/$_backupVersion';
  }

  @override
  String _plainBase(String accountId, String relative) {
    return _backupBase(accountId, relative);
  }

  @override
  Uri _plainIndexUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _plainBase(accountId, _plainBackupIndexFile),
    );
  }

  @override
  Uri _plainFileUri(
    Uri baseUrl,
    String rootPath,
    String accountId,
    String relativePath,
  ) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _plainBase(accountId, relativePath),
    );
  }

  @override
  Future<void> _ensureBackupCollections(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final segments = <String>[
      ..._splitPath(rootPath),
      'accounts',
      accountId,
      _backupDir,
      _backupVersion,
    ];
    await _ensureCollectionPath(client, baseUrl, segments);
    await _ensureCollectionPath(client, baseUrl, [
      ...segments,
      _backupObjectsDir,
    ]);
    await _ensureCollectionPath(client, baseUrl, [
      ...segments,
      _backupSnapshotsDir,
    ]);
  }

  @override
  Future<void> _ensureCollectionPath(
    WebDavClient client,
    Uri baseUrl,
    List<String> segments,
  ) async {
    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      final uri = joinWebDavUri(
        baseUrl: baseUrl,
        rootPath: '',
        relativePath: current,
      );
      final res = await client.mkcol(uri);
      if (res.statusCode == 201 ||
          res.statusCode == 405 ||
          res.statusCode == 200) {
        continue;
      }
      if (res.statusCode == 409) {
        continue;
      }
    }
  }

  @override
  List<String> _splitPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split('/')
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  WebDavClient _buildClient(WebDavSettings settings, Uri baseUrl) {
    return _clientFactory(
      baseUrl: baseUrl,
      settings: settings,
      logWriter: _logWriter,
    );
  }

  @override
  Uri _parseBaseUrl(String raw) {
    final baseUrl = Uri.tryParse(raw.trim());
    if (baseUrl == null || !baseUrl.hasScheme || !baseUrl.hasAuthority) {
      throw _keyedError(
        'legacy.webdav.server_url_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    return baseUrl;
  }

  @override
  Stream<Uint8List> _chunkStream(Stream<Uint8List> input) async* {
    final buffer = <int>[];
    await for (final data in input) {
      buffer.addAll(data);
      while (buffer.length >= _chunkSize) {
        final chunk = Uint8List.fromList(buffer.sublist(0, _chunkSize));
        buffer.removeRange(0, _chunkSize);
        yield chunk;
      }
    }
    if (buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  }

  @override
  Future<WebDavBackupConfig?> _loadConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final uri = _configUri(baseUrl, rootPath, accountId);
    final res = await client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SyncError(
        code: res.statusCode >= 500
            ? SyncErrorCode.server
            : SyncErrorCode.unknown,
        retryable: res.statusCode >= 500,
        message: 'WebDAV config fetch failed (HTTP ${res.statusCode})',
        httpStatus: res.statusCode,
      );
    }
    final decoded = jsonDecode(res.bodyText);
    if (decoded is Map) {
      return WebDavBackupConfig.fromJson(decoded.cast<String, dynamic>());
    }
    throw _keyedError(
      'legacy.webdav.config_corrupted',
      code: SyncErrorCode.dataCorrupt,
    );
  }

  @override
  Future<void> _saveConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    WebDavBackupConfig config,
  ) {
    return _putJson(
      client,
      _configUri(baseUrl, rootPath, accountId),
      config.toJson(),
    );
  }

  @override
  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  @override
  SyncError _keyedError(
    String key, {
    SyncErrorCode code = SyncErrorCode.unknown,
    bool retryable = false,
    Map<String, String>? params,
  }) {
    return SyncError(
      code: code,
      retryable: retryable,
      presentationKey: key,
      presentationParams: params,
    );
  }

  @override
  SyncError _httpError({
    required int statusCode,
    required String method,
    required Uri uri,
  }) {
    final code = switch (statusCode) {
      401 => SyncErrorCode.authFailed,
      403 => SyncErrorCode.permission,
      409 => SyncErrorCode.conflict,
      408 || 425 || 429 => SyncErrorCode.server,
      >= 500 => SyncErrorCode.server,
      _ => SyncErrorCode.unknown,
    };
    return SyncError(
      code: code,
      retryable:
          statusCode == 408 ||
          statusCode == 425 ||
          statusCode == 429 ||
          statusCode >= 500,
      message: 'Bad state: WebDAV $method failed (HTTP $statusCode)',
      httpStatus: statusCode,
      requestMethod: method,
      requestPath: uri.toString(),
    );
  }

  @override
  SyncError _mapUnexpectedError(Object error) {
    if (error is SyncError) return error;
    if (error is SocketException ||
        error is HandshakeException ||
        error is HttpException) {
      return SyncError(
        code: SyncErrorCode.network,
        retryable: true,
        message: error.toString(),
      );
    }
    return SyncError(
      code: SyncErrorCode.unknown,
      retryable: false,
      message: error.toString(),
    );
  }
}

WebDavClient _defaultBackupClientFactory({
  required Uri baseUrl,
  required WebDavSettings settings,
  void Function(DebugLogEntry entry)? logWriter,
}) {
  return WebDavClient(
    baseUrl: baseUrl,
    username: settings.username,
    password: settings.password,
    authMode: settings.authMode,
    ignoreBadCert: settings.ignoreTlsErrors,
    logWriter: logWriter,
  );
}
