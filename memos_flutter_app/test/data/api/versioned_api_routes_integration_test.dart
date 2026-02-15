import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/api/memo_api_facade.dart';
import 'package:memos_flutter_app/data/api/memo_api_version.dart';

const Set<String> _allCurrentUserEndpoints = <String>{
  'GET /api/v1/auth/sessions/current',
  'GET /api/v1/auth/me',
  'POST /api/v1/auth/status',
  'GET /api/v1/auth/status',
  'POST /api/v2/auth/status',
  'GET /api/v1/user/me',
  'GET /api/v1/users/me',
  'GET /api/user/me',
};

void main() {
  group('MemoApiFacade versioned route compatibility', () {
    for (final version in kMemoApiVersionsProbeOrder) {
      test(
        'version ${version.versionString} uses expected auth + list routes',
        () async {
          final harness = await _FakeMemosServer.start(version);
          addTearDown(() async {
            await harness.close();
          });

          final api = MemoApiFacade.authenticated(
            baseUrl: harness.baseUrl,
            personalAccessToken: 'test-pat',
            version: version,
          );

          final user = await api.getCurrentUser();
          expect(user.name, 'users/1');

          final (memos, nextPageToken) = await api.listMemos(
            pageSize: 10,
            state: 'NORMAL',
          );
          expect(memos, hasLength(1));
          expect(memos.first.uid, '101');

          final expected = _expectedRoutes(version);
          final currentUserRequest = harness.findRequest(
            method: expected.currentUserMethod,
            path: expected.currentUserPath,
          );
          expect(currentUserRequest, isNotNull);

          final listRequest = harness.findRequest(
            method: 'GET',
            path: expected.listMemosPath,
          );
          expect(listRequest, isNotNull);
          final capturedListRequest = listRequest!;

          if (expected.usesLegacyMemoListRoute) {
            expect(capturedListRequest.queryParameters['rowStatus'], 'NORMAL');
            expect(capturedListRequest.queryParameters['limit'], '10');
            expect(nextPageToken, '1');
          } else {
            expect(capturedListRequest.queryParameters['pageSize'], '10');
            expect(capturedListRequest.queryParameters['page_size'], '10');
            expect(nextPageToken, isEmpty);
          }

          switch (version) {
            case MemoApiVersion.v022:
              expect(
                capturedListRequest.queryParameters['filter'],
                'row_status == "NORMAL"',
              );
              expect(
                capturedListRequest.queryParameters.containsKey('state'),
                isFalse,
              );
              expect(
                capturedListRequest.queryParameters.containsKey('view'),
                isFalse,
              );
              break;
            case MemoApiVersion.v023:
              expect(
                capturedListRequest.queryParameters['view'],
                'MEMO_VIEW_FULL',
              );
              expect(
                capturedListRequest.queryParameters['filter'],
                'row_status == "NORMAL"',
              );
              expect(
                capturedListRequest.queryParameters.containsKey('state'),
                isFalse,
              );
              break;
            case MemoApiVersion.v024:
            case MemoApiVersion.v025:
            case MemoApiVersion.v026:
              expect(capturedListRequest.queryParameters['state'], 'NORMAL');
              expect(
                capturedListRequest.queryParameters.containsKey('view'),
                isFalse,
              );
              break;
            case MemoApiVersion.v021:
              expect(
                capturedListRequest.queryParameters.containsKey('state'),
                isFalse,
              );
              expect(
                capturedListRequest.queryParameters.containsKey('filter'),
                isFalse,
              );
              break;
          }

          final currentUserAttemptCount = harness.requests.where((request) {
            return _allCurrentUserEndpoints.contains(
              '${request.method} ${request.path}',
            );
          }).length;
          expect(currentUserAttemptCount, 1);
        },
      );
    }
  });
}

class _ExpectedRoutes {
  const _ExpectedRoutes({
    required this.currentUserMethod,
    required this.currentUserPath,
    required this.listMemosPath,
    required this.usesLegacyMemoListRoute,
  });

  final String currentUserMethod;
  final String currentUserPath;
  final String listMemosPath;
  final bool usesLegacyMemoListRoute;
}

_ExpectedRoutes _expectedRoutes(MemoApiVersion version) {
  return switch (version) {
    MemoApiVersion.v021 => const _ExpectedRoutes(
      currentUserMethod: 'POST',
      currentUserPath: '/api/v2/auth/status',
      listMemosPath: '/api/v1/memo',
      usesLegacyMemoListRoute: true,
    ),
    MemoApiVersion.v022 => const _ExpectedRoutes(
      currentUserMethod: 'POST',
      currentUserPath: '/api/v1/auth/status',
      listMemosPath: '/api/v1/memos',
      usesLegacyMemoListRoute: false,
    ),
    MemoApiVersion.v023 => const _ExpectedRoutes(
      currentUserMethod: 'POST',
      currentUserPath: '/api/v1/auth/status',
      listMemosPath: '/api/v1/memos',
      usesLegacyMemoListRoute: false,
    ),
    MemoApiVersion.v024 => const _ExpectedRoutes(
      currentUserMethod: 'POST',
      currentUserPath: '/api/v1/auth/status',
      listMemosPath: '/api/v1/memos',
      usesLegacyMemoListRoute: false,
    ),
    MemoApiVersion.v025 => const _ExpectedRoutes(
      currentUserMethod: 'GET',
      currentUserPath: '/api/v1/auth/sessions/current',
      listMemosPath: '/api/v1/memos',
      usesLegacyMemoListRoute: false,
    ),
    MemoApiVersion.v026 => const _ExpectedRoutes(
      currentUserMethod: 'GET',
      currentUserPath: '/api/v1/auth/me',
      listMemosPath: '/api/v1/memos',
      usesLegacyMemoListRoute: false,
    ),
  };
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
  });

  final String method;
  final String path;
  final Map<String, String> queryParameters;
}

class _FakeMemosServer {
  _FakeMemosServer._(this.version, this._server);

  final MemoApiVersion version;
  final HttpServer _server;
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeMemosServer> start(MemoApiVersion version) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _FakeMemosServer._(version, server);
    server.listen(harness._handleRequest);
    return harness;
  }

  _CapturedRequest? findRequest({
    required String method,
    required String path,
  }) {
    for (final request in requests) {
      if (request.method == method && request.path == path) {
        return request;
      }
    }
    return null;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    await utf8.decoder.bind(request).join();
    requests.add(
      _CapturedRequest(
        method: request.method,
        path: request.uri.path,
        queryParameters: request.uri.queryParameters,
      ),
    );

    final expected = _expectedRoutes(version);
    final isCurrentUserRoute =
        request.method == expected.currentUserMethod &&
        request.uri.path == expected.currentUserPath;
    if (isCurrentUserRoute) {
      await _writeJson(request.response, <String, Object?>{
        'user': <String, Object?>{
          'name': 'users/1',
          'username': 'demo',
          'displayName': 'Demo User',
          'avatarUrl': '',
          'description': '',
        },
      });
      return;
    }

    final isListMemosRoute =
        request.method == 'GET' && request.uri.path == expected.listMemosPath;
    if (isListMemosRoute) {
      await _writeJson(request.response, _listMemosPayload(version));
      return;
    }

    await _writeJson(request.response, <String, Object?>{
      'error': 'Unhandled test route',
      'method': request.method,
      'path': request.uri.path,
    }, statusCode: HttpStatus.notFound);
  }
}

Object _listMemosPayload(MemoApiVersion version) {
  if (version == MemoApiVersion.v021) {
    return <Object?>[
      <String, Object?>{
        'id': 101,
        'creatorId': 1,
        'content': 'legacy memo',
        'visibility': 'PRIVATE',
        'pinned': false,
        'rowStatus': 'NORMAL',
        'createdTs': 1704067200,
        'updatedTs': 1704067260,
      },
    ];
  }

  return <String, Object?>{
    'memos': <Object?>[
      <String, Object?>{
        'name': 'memos/101',
        'creator': 'users/1',
        'content': 'modern memo',
        'visibility': 'PRIVATE',
        'pinned': false,
        'state': 'NORMAL',
        'createTime': '2024-01-01T00:00:00Z',
        'updateTime': '2024-01-01T00:01:00Z',
        'tags': const <String>[],
        'attachments': const <Object>[],
      },
    ],
    'nextPageToken': '',
  };
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
