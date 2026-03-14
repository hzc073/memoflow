import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/api/memo_api_facade.dart';
import 'package:memos_flutter_app/data/api/memo_api_version.dart';

void main() {
  group('MemoApiFacade createMemo route compatibility', () {
    for (final version in kMemoApiVersionsProbeOrder) {
      test(
        'version ${version.versionString} sends expected create memo params',
        () async {
          final harness = await _FakeCreateMemoServer.start(version);
          addTearDown(() async {
            await harness.close();
          });

          final api = MemoApiFacade.authenticated(
            baseUrl: harness.baseUrl,
            personalAccessToken: 'test-pat',
            version: version,
          );

          final created = await api.createMemo(
            memoId: '101',
            content: 'created memo content',
            visibility: 'PRIVATE',
            createTime: DateTime.utc(2026, 3, 13, 18, 0),
            displayTime: DateTime.utc(2026, 3, 13, 18, 0),
            relations: const <Map<String, dynamic>>[
              {
                'relatedMemo': {'name': 'memos/102'},
                'type': 'REFERENCE',
              },
            ],
          );
          expect(created.uid, '101');

          final capturedRequest = harness.findCreateRequest();
          expect(capturedRequest, isNotNull);
          final jsonBody =
              capturedRequest!.jsonBody ?? const <String, dynamic>{};

          if (version == MemoApiVersion.v021) {
            expect(capturedRequest.path, '/api/v1/memo');
            expect(capturedRequest.queryParameters, isEmpty);
            expect(jsonBody.containsKey('createTime'), isFalse);
            expect(jsonBody.containsKey('displayTime'), isFalse);
            expect(jsonBody.containsKey('relations'), isFalse);
          } else {
            expect(capturedRequest.path, '/api/v1/memos');
            expect(capturedRequest.queryParameters['memoId'], '101');

            if (version == MemoApiVersion.v026) {
              expect(jsonBody['createTime'], '2026-03-13T18:00:00.000Z');
              expect(jsonBody['displayTime'], '2026-03-13T18:00:00.000Z');
              expect(jsonBody['relations'], isA<List<dynamic>>());
            } else {
              expect(jsonBody.containsKey('createTime'), isFalse);
              expect(jsonBody.containsKey('displayTime'), isFalse);
              expect(jsonBody.containsKey('relations'), isFalse);
            }
          }
        },
      );
    }
  });
}

class _CapturedCreateRequest {
  const _CapturedCreateRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.jsonBody,
  });

  final String method;
  final String path;
  final Map<String, String> queryParameters;
  final Map<String, dynamic>? jsonBody;
}

class _FakeCreateMemoServer {
  _FakeCreateMemoServer._(this.version, this._server);

  final MemoApiVersion version;
  final HttpServer _server;
  final List<_CapturedCreateRequest> requests = <_CapturedCreateRequest>[];

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeCreateMemoServer> start(MemoApiVersion version) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _FakeCreateMemoServer._(version, server);
    server.listen(harness._handleRequest);
    return harness;
  }

  _CapturedCreateRequest? findCreateRequest() {
    for (final request in requests) {
      final isLegacyCreate =
          request.method == 'POST' && request.path == '/api/v1/memo';
      final isModernCreate =
          request.method == 'POST' && request.path == '/api/v1/memos';
      if (isLegacyCreate || isModernCreate) {
        return request;
      }
    }
    return null;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final bodyText = await utf8.decoder.bind(request).join();
    Map<String, dynamic>? jsonBody;
    if (bodyText.trim().isNotEmpty) {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map) {
        jsonBody = decoded.cast<String, dynamic>();
      }
    }

    requests.add(
      _CapturedCreateRequest(
        method: request.method,
        path: request.uri.path,
        queryParameters: request.uri.queryParameters,
        jsonBody: jsonBody,
      ),
    );

    if (version == MemoApiVersion.v021 &&
        request.method == 'POST' &&
        request.uri.path == '/api/v1/memo') {
      await _writeJson(request.response, <String, Object?>{
        'id': 101,
        'creatorId': 1,
        'content': 'created memo content',
        'visibility': 'PRIVATE',
        'pinned': false,
        'rowStatus': 'NORMAL',
        'createdTs': 1704067200,
        'updatedTs': 1704067260,
      });
      return;
    }

    if (version != MemoApiVersion.v021 &&
        request.method == 'POST' &&
        request.uri.path == '/api/v1/memos') {
      await _writeJson(request.response, <String, Object?>{
        'name': 'memos/101',
        'creator': 'users/1',
        'content': 'created memo content',
        'visibility': 'PRIVATE',
        'pinned': false,
        'state': 'NORMAL',
        'createTime': '2026-03-13T18:00:00Z',
        'updateTime': '2026-03-13T18:00:00Z',
        'tags': const <String>[],
        'attachments': const <Object>[],
      });
      return;
    }

    await _writeJson(request.response, <String, Object?>{
      'error': 'Unhandled test route',
      'method': request.method,
      'path': request.uri.path,
    }, statusCode: HttpStatus.notFound);
  }
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
