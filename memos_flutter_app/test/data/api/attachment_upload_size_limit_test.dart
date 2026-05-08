import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/api/memo_api_facade.dart';
import 'package:memos_flutter_app/data/api/memo_api_version.dart';
import 'package:memos_flutter_app/data/api/memos_api.dart';
import 'package:memos_flutter_app/data/models/server_setting.dart';

void main() {
  group('attachment upload size limit route compatibility', () {
    test('reads 0.21 maxUploadSizeMiB from system status', () async {
      final server = await _FakeLimitServer.start(
        version: MemoApiVersion.v021,
        statusPayload: const <String, Object?>{'maxUploadSizeMiB': 64},
      );
      addTearDown(server.close);

      final api = _authenticatedApi(server);
      final limit = await api.getAttachmentUploadSizeLimit();

      expect(limit.bytes, 64 * 1024 * 1024);
      expect(limit.source, AttachmentUploadSizeLimitSource.systemStatus);
      expect(server.singleRequest.path, '/api/v1/status');
    });

    test(
      'reads 0.24 uploadSizeLimitMb from workspace storage setting',
      () async {
        final server = await _FakeLimitServer.start(
          version: MemoApiVersion.v024,
          storageStatusCode: HttpStatus.ok,
          storagePayload: const <String, Object?>{
            'storageSetting': <String, Object?>{'uploadSizeLimitMb': '96'},
          },
        );
        addTearDown(server.close);

        final api = _authenticatedApi(server);
        final limit = await api.getAttachmentUploadSizeLimit();

        expect(limit.bytes, 96 * 1024 * 1024);
        expect(
          limit.source,
          AttachmentUploadSizeLimitSource.workspaceStorageSetting,
        );
        expect(server.singleRequest.path, '/api/v1/workspace/settings/STORAGE');
      },
    );

    test(
      'reads 0.27 uploadSizeLimitMb from instance storage setting',
      () async {
        final server = await _FakeLimitServer.start(
          version: MemoApiVersion.v027,
          storageStatusCode: HttpStatus.ok,
          storagePayload: const <String, Object?>{
            'storageSetting': <String, Object?>{'uploadSizeLimitMb': '128'},
          },
        );
        addTearDown(server.close);

        final api = _authenticatedApi(server);
        final limit = await api.getAttachmentUploadSizeLimit();

        expect(limit.bytes, 128 * 1024 * 1024);
        expect(
          limit.source,
          AttachmentUploadSizeLimitSource.instanceStorageSetting,
        );
        expect(server.singleRequest.path, '/api/v1/instance/settings/STORAGE');
      },
    );

    test('permission denied storage setting becomes unknown', () async {
      final server = await _FakeLimitServer.start(
        version: MemoApiVersion.v027,
        storageStatusCode: HttpStatus.forbidden,
      );
      addTearDown(server.close);

      final api = _authenticatedApi(server);
      final limit = await api.getAttachmentUploadSizeLimit();

      expect(limit.isUnknown, isTrue);
      expect(
        limit.unknownReason,
        AttachmentUploadSizeLimitUnknownReason.permissionDenied,
      );
    });

    test('missing storage setting endpoint becomes unknown', () async {
      final server = await _FakeLimitServer.start(
        version: MemoApiVersion.v024,
        storageStatusCode: HttpStatus.notFound,
      );
      addTearDown(server.close);

      final api = _authenticatedApi(server);
      final limit = await api.getAttachmentUploadSizeLimit();

      expect(limit.isUnknown, isTrue);
      expect(
        limit.unknownReason,
        AttachmentUploadSizeLimitUnknownReason.endpointUnavailable,
      );
    });

    test('malformed storage setting response becomes unknown', () async {
      final server = await _FakeLimitServer.start(
        version: MemoApiVersion.v027,
        rawBody: '<html>not json</html>',
      );
      addTearDown(server.close);

      final api = _authenticatedApi(server);
      final limit = await api.getAttachmentUploadSizeLimit();

      expect(limit.isUnknown, isTrue);
      expect(
        limit.unknownReason,
        AttachmentUploadSizeLimitUnknownReason.invalidResponse,
      );
    });
  });

  group('server settings route compatibility', () {
    test(
      'reads 0.21 attachment limit from status and memo is unsupported',
      () async {
        final server = await _FakeServerSettingsServer.start(
          version: MemoApiVersion.v021,
          statusPayload: const <String, Object?>{'maxUploadSizeMiB': 64},
        );
        addTearDown(server.close);

        final settings = await _authenticatedServerSettingsApi(
          server,
        ).getServerSettings();

        expect(settings.memoContentLimitBytes.supported, isFalse);
        expect(
          settings.memoContentLimitBytes.unavailableReason,
          ServerSettingUnavailableReason.unsupportedVersion,
        );
        expect(settings.attachmentUploadLimitMiB.value, 64);
        expect(
          settings.attachmentUploadLimitMiB.source,
          ServerSettingSource.legacySystemStatus,
        );
        expect(server.paths, ['/api/v1/status']);
      },
    );

    test(
      'updates 0.21 attachment limit through legacy system setting',
      () async {
        final server = await _FakeServerSettingsServer.start(
          version: MemoApiVersion.v021,
          legacySystemSettingResponse: const <String, Object?>{'value': '80'},
        );
        addTearDown(server.close);

        final value = await _authenticatedServerSettingsApi(
          server,
        ).updateServerAttachmentUploadLimitMiB(80);

        expect(value.value, 80);
        expect(value.source, ServerSettingSource.legacySystemSetting);
        expect(server.paths, ['/api/v1/system/setting']);
        expect(server.singleBody['name'], 'max-upload-size-mib');
        expect(server.singleBody['value'], '80');
      },
    );

    test('reads 0.24 workspace memo and storage settings', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v024,
        memoPayload: const <String, Object?>{
          'memoRelatedSetting': <String, Object?>{'contentLengthLimit': 2048},
        },
        storagePayload: const <String, Object?>{
          'storageSetting': <String, Object?>{'uploadSizeLimitMb': 96},
        },
      );
      addTearDown(server.close);

      final settings = await _authenticatedServerSettingsApi(
        server,
      ).getServerSettings();

      expect(settings.memoContentLimitBytes.value, 2048);
      expect(
        settings.memoContentLimitBytes.source,
        ServerSettingSource.workspaceMemoRelatedSetting,
      );
      expect(settings.attachmentUploadLimitMiB.value, 96);
      expect(
        settings.attachmentUploadLimitMiB.source,
        ServerSettingSource.workspaceStorageSetting,
      );
      expect(server.paths, [
        '/api/v1/workspace/settings/MEMO_RELATED',
        '/api/v1/workspace/settings/STORAGE',
      ]);
    });

    test('reads 0.27 instance memo and storage settings', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v027,
        memoPayload: const <String, Object?>{
          'memoRelatedSetting': <String, Object?>{'contentLengthLimit': 4096},
        },
        storagePayload: const <String, Object?>{
          'storageSetting': <String, Object?>{'uploadSizeLimitMb': 128},
        },
      );
      addTearDown(server.close);

      final settings = await _authenticatedServerSettingsApi(
        server,
      ).getServerSettings();

      expect(settings.memoContentLimitBytes.value, 4096);
      expect(
        settings.memoContentLimitBytes.source,
        ServerSettingSource.instanceMemoRelatedSetting,
      );
      expect(settings.attachmentUploadLimitMiB.value, 128);
      expect(
        settings.attachmentUploadLimitMiB.source,
        ServerSettingSource.instanceStorageSetting,
      );
      expect(server.paths, [
        '/api/v1/instance/settings/MEMO_RELATED',
        '/api/v1/instance/settings/STORAGE',
      ]);
    });

    test('storage update preserves sibling fields', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v027,
        storagePayload: const <String, Object?>{
          'name': 'instance/settings/STORAGE',
          'storageSetting': <String, Object?>{
            'storageType': 'S3',
            'filepathTemplate': '{{filename}}',
            'uploadSizeLimitMb': 32,
            's3Config': <String, Object?>{
              'bucket': 'memo-bucket',
              'region': 'ap-test-1',
            },
          },
        },
      );
      addTearDown(server.close);

      final value = await _authenticatedServerSettingsApi(
        server,
      ).updateServerAttachmentUploadLimitMiB(256);

      expect(value.value, 256);
      expect(server.paths, [
        '/api/v1/instance/settings/STORAGE',
        '/api/v1/instance/settings/STORAGE',
      ]);
      final storageSetting =
          server.lastBody['storageSetting'] as Map<String, dynamic>;
      expect(storageSetting['uploadSizeLimitMb'], 256);
      expect(storageSetting['storageType'], 'S3');
      expect(storageSetting['filepathTemplate'], '{{filename}}');
      expect(
        (storageSetting['s3Config'] as Map<String, dynamic>)['bucket'],
        'memo-bucket',
      );
    });

    test('memo related update preserves sibling fields', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v024,
        memoPayload: const <String, Object?>{
          'name': 'settings/MEMO_RELATED',
          'memoRelatedSetting': <String, Object?>{
            'contentLengthLimit': 1024,
            'enableReactions': true,
            'enableComments': false,
          },
        },
      );
      addTearDown(server.close);

      final value = await _authenticatedServerSettingsApi(
        server,
      ).updateServerMemoContentLimitBytes(3000);

      expect(value.value, 3000);
      expect(server.paths, [
        '/api/v1/workspace/settings/MEMO_RELATED',
        '/api/v1/workspace/settings/MEMO_RELATED',
      ]);
      final memoSetting =
          server.lastBody['memoRelatedSetting'] as Map<String, dynamic>;
      expect(memoSetting['contentLengthLimit'], 3000);
      expect(memoSetting['enableReactions'], isTrue);
      expect(memoSetting['enableComments'], isFalse);
    });

    test('permission denied is classified per field', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v027,
        storageStatusCode: HttpStatus.forbidden,
      );
      addTearDown(server.close);

      final value = await _authenticatedServerSettingsApi(
        server,
      ).getServerAttachmentUploadLimitMiB();

      expect(value.isUnavailable, isTrue);
      expect(
        value.unavailableReason,
        ServerSettingUnavailableReason.permissionDenied,
      );
    });

    test('missing endpoint is classified as endpoint unavailable', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v024,
        memoStatusCode: HttpStatus.notFound,
      );
      addTearDown(server.close);

      final value = await _authenticatedServerSettingsApi(
        server,
      ).getServerMemoContentLimitBytes();

      expect(value.isUnavailable, isTrue);
      expect(
        value.unavailableReason,
        ServerSettingUnavailableReason.endpointUnavailable,
      );
    });

    test('malformed response is classified as invalid response', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v027,
        rawStorageBody: '<html>bad gateway</html>',
      );
      addTearDown(server.close);

      final value = await _authenticatedServerSettingsApi(
        server,
      ).getServerAttachmentUploadLimitMiB();

      expect(value.isUnavailable, isTrue);
      expect(
        value.unavailableReason,
        ServerSettingUnavailableReason.invalidResponse,
      );
    });

    test('non-positive limit is classified separately', () async {
      final server = await _FakeServerSettingsServer.start(
        version: MemoApiVersion.v027,
        storagePayload: const <String, Object?>{
          'storageSetting': <String, Object?>{'uploadSizeLimitMb': 0},
        },
      );
      addTearDown(server.close);

      final value = await _authenticatedServerSettingsApi(
        server,
      ).getServerAttachmentUploadLimitMiB();

      expect(value.isUnavailable, isTrue);
      expect(
        value.unavailableReason,
        ServerSettingUnavailableReason.nonPositiveLimit,
      );
    });
  });
}

MemosApi _authenticatedApi(_FakeLimitServer server) {
  return MemoApiFacade.authenticated(
    baseUrl: server.baseUrl,
    personalAccessToken: 'test-pat',
    version: server.version,
  );
}

MemosApi _authenticatedServerSettingsApi(_FakeServerSettingsServer server) {
  return MemoApiFacade.authenticated(
    baseUrl: server.baseUrl,
    personalAccessToken: 'test-pat',
    version: server.version,
  );
}

class _CapturedRequest {
  const _CapturedRequest({required this.method, required this.path});

  final String method;
  final String path;
}

class _FakeLimitServer {
  _FakeLimitServer._({
    required this.version,
    required HttpServer server,
    required this.statusPayload,
    required this.storagePayload,
    required this.storageStatusCode,
    required this.rawBody,
  }) : _server = server;

  final MemoApiVersion version;
  final HttpServer _server;
  final Object? statusPayload;
  final Object? storagePayload;
  final int storageStatusCode;
  final String? rawBody;
  final requests = <_CapturedRequest>[];

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  _CapturedRequest get singleRequest {
    expect(requests, hasLength(1));
    return requests.single;
  }

  static Future<_FakeLimitServer> start({
    required MemoApiVersion version,
    Object? statusPayload,
    Object? storagePayload,
    int storageStatusCode = HttpStatus.ok,
    String? rawBody,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _FakeLimitServer._(
      version: version,
      server: server,
      statusPayload: statusPayload,
      storagePayload: storagePayload,
      storageStatusCode: storageStatusCode,
      rawBody: rawBody,
    );
    server.listen(harness._handleRequest);
    return harness;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handleRequest(HttpRequest request) async {
    await utf8.decoder.bind(request).join();
    requests.add(
      _CapturedRequest(method: request.method, path: request.uri.path),
    );

    if (rawBody != null) {
      request.response.statusCode = HttpStatus.ok;
      request.response.write(rawBody);
      await request.response.close();
      return;
    }

    if (version == MemoApiVersion.v021 &&
        request.method == 'GET' &&
        request.uri.path == '/api/v1/status') {
      await _writeJson(
        request.response,
        statusPayload ?? const <String, Object?>{'maxUploadSizeMiB': 32},
      );
      return;
    }

    final expectedStoragePath = switch (version) {
      MemoApiVersion.v022 ||
      MemoApiVersion.v023 ||
      MemoApiVersion.v024 => '/api/v1/workspace/settings/STORAGE',
      MemoApiVersion.v025 ||
      MemoApiVersion.v026 ||
      MemoApiVersion.v027 => '/api/v1/instance/settings/STORAGE',
      MemoApiVersion.v021 => '',
    };
    if (request.method == 'GET' && request.uri.path == expectedStoragePath) {
      await _writeJson(
        request.response,
        storagePayload ??
            const <String, Object?>{
              'storageSetting': <String, Object?>{'uploadSizeLimitMb': '32'},
            },
        statusCode: storageStatusCode,
      );
      return;
    }

    await _writeJson(request.response, <String, Object?>{
      'error': 'Unhandled route',
    }, statusCode: HttpStatus.notFound);
  }
}

class _CapturedServerSettingRequest {
  const _CapturedServerSettingRequest({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> body;
}

class _FakeServerSettingsServer {
  _FakeServerSettingsServer._({
    required this.version,
    required HttpServer server,
    required this.statusPayload,
    required this.memoPayload,
    required this.storagePayload,
    required this.legacySystemSettingResponse,
    required this.memoStatusCode,
    required this.storageStatusCode,
    required this.rawStorageBody,
  }) : _server = server;

  final MemoApiVersion version;
  final HttpServer _server;
  final Object? statusPayload;
  final Object? memoPayload;
  final Object? storagePayload;
  final Object? legacySystemSettingResponse;
  final int memoStatusCode;
  final int storageStatusCode;
  final String? rawStorageBody;
  final requests = <_CapturedServerSettingRequest>[];

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  List<String> get paths => requests.map((r) => r.path).toList(growable: false);

  Map<String, dynamic> get singleBody {
    expect(requests, hasLength(1));
    return requests.single.body;
  }

  Map<String, dynamic> get lastBody {
    expect(requests, isNotEmpty);
    return requests.last.body;
  }

  static Future<_FakeServerSettingsServer> start({
    required MemoApiVersion version,
    Object? statusPayload,
    Object? memoPayload,
    Object? storagePayload,
    Object? legacySystemSettingResponse,
    int memoStatusCode = HttpStatus.ok,
    int storageStatusCode = HttpStatus.ok,
    String? rawStorageBody,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _FakeServerSettingsServer._(
      version: version,
      server: server,
      statusPayload: statusPayload,
      memoPayload: memoPayload,
      storagePayload: storagePayload,
      legacySystemSettingResponse: legacySystemSettingResponse,
      memoStatusCode: memoStatusCode,
      storageStatusCode: storageStatusCode,
      rawStorageBody: rawStorageBody,
    );
    server.listen(harness._handleRequest);
    return harness;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handleRequest(HttpRequest request) async {
    final rawBody = await utf8.decoder.bind(request).join();
    final body = _decodeBody(rawBody);
    requests.add(
      _CapturedServerSettingRequest(
        method: request.method,
        path: request.uri.path,
        body: body,
      ),
    );

    if (version == MemoApiVersion.v021 &&
        request.method == 'GET' &&
        request.uri.path == '/api/v1/status') {
      await _writeJson(
        request.response,
        statusPayload ?? const <String, Object?>{'maxUploadSizeMiB': 32},
      );
      return;
    }

    if (version == MemoApiVersion.v021 &&
        request.method == 'POST' &&
        request.uri.path == '/api/v1/system/setting') {
      await _writeJson(
        request.response,
        legacySystemSettingResponse ?? const <String, Object?>{'value': '32'},
      );
      return;
    }

    final memoPath = _memoPath(version);
    if (memoPath.isNotEmpty && request.uri.path == memoPath) {
      if (request.method == 'GET') {
        await _writeJson(
          request.response,
          memoPayload ??
              const <String, Object?>{
                'memoRelatedSetting': <String, Object?>{
                  'contentLengthLimit': 1024,
                },
              },
          statusCode: memoStatusCode,
        );
        return;
      }
      if (request.method == 'PATCH') {
        await _writeJson(request.response, body);
        return;
      }
    }

    final storagePath = _storagePath(version);
    if (storagePath.isNotEmpty && request.uri.path == storagePath) {
      if (rawStorageBody != null) {
        request.response.statusCode = HttpStatus.ok;
        request.response.write(rawStorageBody);
        await request.response.close();
        return;
      }
      if (request.method == 'GET') {
        await _writeJson(
          request.response,
          storagePayload ??
              const <String, Object?>{
                'storageSetting': <String, Object?>{'uploadSizeLimitMb': 32},
              },
          statusCode: storageStatusCode,
        );
        return;
      }
      if (request.method == 'PATCH') {
        await _writeJson(request.response, body);
        return;
      }
    }

    await _writeJson(request.response, const <String, Object?>{
      'error': 'Unhandled route',
    }, statusCode: HttpStatus.notFound);
  }

  static String _memoPath(MemoApiVersion version) {
    return switch (version) {
      MemoApiVersion.v022 ||
      MemoApiVersion.v023 ||
      MemoApiVersion.v024 => '/api/v1/workspace/settings/MEMO_RELATED',
      MemoApiVersion.v025 ||
      MemoApiVersion.v026 ||
      MemoApiVersion.v027 => '/api/v1/instance/settings/MEMO_RELATED',
      MemoApiVersion.v021 => '',
    };
  }

  static String _storagePath(MemoApiVersion version) {
    return switch (version) {
      MemoApiVersion.v022 ||
      MemoApiVersion.v023 ||
      MemoApiVersion.v024 => '/api/v1/workspace/settings/STORAGE',
      MemoApiVersion.v025 ||
      MemoApiVersion.v026 ||
      MemoApiVersion.v027 => '/api/v1/instance/settings/STORAGE',
      MemoApiVersion.v021 => '',
    };
  }
}

Map<String, dynamic> _decodeBody(String rawBody) {
  if (rawBody.trim().isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(rawBody);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return decoded.cast<String, dynamic>();
  return <String, dynamic>{};
}

Future<void> _writeJson(
  HttpResponse response,
  Object payload, {
  int statusCode = HttpStatus.ok,
}) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(payload));
  await response.close();
}
