import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/api/memo_api_facade.dart';
import 'package:memos_flutter_app/data/api/memo_api_version.dart';

void main() {
  group('MemoApiFacade updateMemo route compatibility', () {
    for (final version in kMemoApiVersionsProbeOrder) {
      test(
        'version ${version.versionString} sends expected update memo params',
        () async {
          final harness = await _FakeUpdateMemoServer.start(version);
          addTearDown(() async {
            await harness.close();
          });

          final api = MemoApiFacade.authenticated(
            baseUrl: harness.baseUrl,
            personalAccessToken: 'test-pat',
            version: version,
          );

          final memo = await api.updateMemo(
            memoUid: '101',
            content: 'updated memo content',
          );
          expect(memo.uid, '101');

          final capturedRequest = harness.findUpdateRequest();
          expect(capturedRequest, isNotNull);

          if (version == MemoApiVersion.v021) {
            expect(capturedRequest!.path, '/api/v1/memo/101');
            expect(capturedRequest.queryParameters, isEmpty);
          } else if (version == MemoApiVersion.v022) {
            expect(capturedRequest!.method, 'POST');
            expect(
              capturedRequest.path,
              '/memos.api.v1.MemoService/UpdateMemo',
            );
            expect(capturedRequest.queryParameters, isEmpty);
          } else {
            expect(capturedRequest!.path, '/api/v1/memos/101');
            expect(capturedRequest.queryParameters['updateMask'], 'content');
            expect(
              capturedRequest.queryParameters.containsKey('update_mask'),
              isFalse,
            );
          }
        },
      );
    }
  });

  group('MemoApiFacade updateMemo pinned compatibility', () {
    for (final version in kMemoApiVersionsProbeOrder) {
      test(
        'version ${version.versionString} uses expected pinned route',
        () async {
          final harness = await _FakeUpdateMemoServer.start(version);
          addTearDown(() async {
            await harness.close();
          });

          final api = MemoApiFacade.authenticated(
            baseUrl: harness.baseUrl,
            personalAccessToken: 'test-pat',
            version: version,
          );

          final memo = await api.updateMemo(
            memoUid: '101',
            content: 'updated memo content',
            pinned: true,
          );
          expect(memo.uid, '101');

          final capturedRequest = harness.findUpdateRequest();
          expect(capturedRequest, isNotNull);

          final organizerRequest = harness.findOrganizerRequest();
          if (version == MemoApiVersion.v021) {
            expect(capturedRequest!.path, '/api/v1/memo/101');
            expect(organizerRequest, isNotNull);
          } else if (version == MemoApiVersion.v022) {
            expect(memo.pinned, isTrue);
            expect(capturedRequest!.method, 'POST');
            expect(
              capturedRequest.path,
              '/memos.api.v1.MemoService/UpdateMemo',
            );
            expect(capturedRequest.queryParameters, isEmpty);
            expect(organizerRequest, isNotNull);
          } else if (version == MemoApiVersion.v023) {
            expect(memo.pinned, isTrue);
            expect(capturedRequest!.path, '/api/v1/memos/101');
            expect(capturedRequest.queryParameters['updateMask'], 'content');
            expect(
              capturedRequest.queryParameters.containsKey('update_mask'),
              isFalse,
            );
            expect(organizerRequest, isNotNull);
          } else {
            expect(memo.pinned, isTrue);
            expect(capturedRequest!.path, '/api/v1/memos/101');
            expect(
              capturedRequest.queryParameters['updateMask'],
              'content,pinned',
            );
            expect(
              capturedRequest.queryParameters.containsKey('update_mask'),
              isFalse,
            );
            expect(organizerRequest, isNull);
          }
        },
      );
    }
  });

  group('MemoApiFacade updateMemo createTime compatibility', () {
    test(
      'version 0.25.0 ignores create_time and keeps display_time only',
      () async {
        final harness = await _FakeUpdateMemoServer.start(MemoApiVersion.v025);
        addTearDown(() async {
          await harness.close();
        });

        final api = MemoApiFacade.authenticated(
          baseUrl: harness.baseUrl,
          personalAccessToken: 'test-pat',
          version: MemoApiVersion.v025,
        );

        final memo = await api.updateMemo(
          memoUid: '101',
          createTime: DateTime.utc(2026, 3, 13, 18, 0),
          displayTime: DateTime.utc(2026, 3, 13, 18, 0),
        );
        expect(memo.uid, '101');

        final capturedRequest = harness.findUpdateRequest();
        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.path, '/api/v1/memos/101');
        expect(capturedRequest.queryParameters['updateMask'], 'display_time');
      },
    );

    test(
      'version 0.26.0 sends create_time and display_time together',
      () async {
        final harness = await _FakeUpdateMemoServer.start(MemoApiVersion.v026);
        addTearDown(() async {
          await harness.close();
        });

        final api = MemoApiFacade.authenticated(
          baseUrl: harness.baseUrl,
          personalAccessToken: 'test-pat',
          version: MemoApiVersion.v026,
        );

        final memo = await api.updateMemo(
          memoUid: '101',
          createTime: DateTime.utc(2026, 3, 13, 18, 0),
          displayTime: DateTime.utc(2026, 3, 13, 18, 0),
        );
        expect(memo.uid, '101');

        final capturedRequest = harness.findUpdateRequest();
        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.path, '/api/v1/memos/101');
        expect(
          capturedRequest.queryParameters['updateMask'],
          'create_time,display_time',
        );
      },
    );

    test(
      'version 0.27.0 sends create_time and display_time together',
      () async {
        final harness = await _FakeUpdateMemoServer.start(MemoApiVersion.v027);
        addTearDown(() async {
          await harness.close();
        });

        final api = MemoApiFacade.authenticated(
          baseUrl: harness.baseUrl,
          personalAccessToken: 'test-pat',
          version: MemoApiVersion.v027,
        );

        final memo = await api.updateMemo(
          memoUid: '101',
          createTime: DateTime.utc(2026, 3, 13, 18, 0),
          displayTime: DateTime.utc(2026, 3, 13, 18, 0),
        );
        expect(memo.uid, '101');

        final capturedRequest = harness.findUpdateRequest();
        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.path, '/api/v1/memos/101');
        expect(
          capturedRequest.queryParameters['updateMask'],
          'create_time,display_time',
        );
      },
    );
  });
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

class _FakeUpdateMemoServer {
  _FakeUpdateMemoServer._(this.version, this._server);

  final MemoApiVersion version;
  final HttpServer _server;
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeUpdateMemoServer> start(MemoApiVersion version) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _FakeUpdateMemoServer._(version, server);
    server.listen(harness._handleRequest);
    return harness;
  }

  _CapturedRequest? findUpdateRequest() {
    for (final request in requests) {
      final isRestUpdate =
          request.method == 'PATCH' &&
          (request.path == '/api/v1/memo/101' ||
              request.path == '/api/v1/memos/101');
      final isGrpcWebUpdate =
          request.method == 'POST' &&
          request.path == '/memos.api.v1.MemoService/UpdateMemo';
      if (isRestUpdate || isGrpcWebUpdate) {
        return request;
      }
    }
    return null;
  }

  _CapturedRequest? findOrganizerRequest() {
    for (final request in requests) {
      if (request.method == 'POST' &&
          request.path == '/api/v1/memo/101/organizer') {
        return request;
      }
    }
    return null;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    await request.drain<List<int>>(<int>[]);
    requests.add(
      _CapturedRequest(
        method: request.method,
        path: request.uri.path,
        queryParameters: request.uri.queryParameters,
      ),
    );

    if (version == MemoApiVersion.v021 &&
        request.method == 'PATCH' &&
        request.uri.path == '/api/v1/memo/101') {
      await _writeJson(request.response, <String, Object?>{
        'id': 101,
        'creatorId': 1,
        'content': 'updated memo content',
        'visibility': 'PRIVATE',
        'pinned': false,
        'rowStatus': 'NORMAL',
        'createdTs': 1704067200,
        'updatedTs': 1704067260,
      });
      return;
    }

    if (version != MemoApiVersion.v021 &&
        request.method == 'PATCH' &&
        request.uri.path == '/api/v1/memos/101') {
      final updateMask = request.uri.queryParameters['updateMask'] ?? '';
      final pinned = updateMask.contains('pinned');
      await _writeJson(request.response, <String, Object?>{
        'name': 'memos/101',
        'creator': 'users/1',
        'content': 'updated memo content',
        'visibility': 'PRIVATE',
        'pinned': pinned,
        'state': 'NORMAL',
        'createTime': '2024-01-01T00:00:00Z',
        'updateTime': '2024-01-01T00:01:00Z',
        'tags': const <String>[],
        'attachments': const <Object>[],
      });
      return;
    }

    if (version == MemoApiVersion.v022 &&
        request.method == 'POST' &&
        request.uri.path == '/memos.api.v1.MemoService/UpdateMemo') {
      await _writeGrpcWebOk(request.response);
      return;
    }

    if (version == MemoApiVersion.v022 &&
        request.method == 'GET' &&
        request.uri.path == '/api/v1/memos/101') {
      await _writeJson(request.response, <String, Object?>{
        'name': 'memos/101',
        'creator': 'users/1',
        'content': 'updated memo content',
        'visibility': 'PRIVATE',
        'pinned': false,
        'state': 'NORMAL',
        'createTime': '2024-01-01T00:00:00Z',
        'updateTime': '2024-01-01T00:01:00Z',
        'displayTime': '2024-01-01T00:00:00Z',
        'tags': const <String>[],
        'attachments': const <Object>[],
      });
      return;
    }

    if (request.method == 'POST' &&
        request.uri.path == '/api/v1/memo/101/organizer') {
      await _writeJson(request.response, <String, Object?>{
        'id': 101,
        'creatorId': 1,
        'content': 'updated memo content',
        'visibility': 'PRIVATE',
        'pinned': true,
        'rowStatus': 'NORMAL',
        'createdTs': 1704067200,
        'updatedTs': 1704067260,
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

Future<void> _writeGrpcWebOk(HttpResponse response) async {
  response.statusCode = HttpStatus.ok;
  response.headers.contentType = ContentType('application', 'grpc-web+proto');
  final trailer = utf8.encode('grpc-status: 0\r\n');
  final bytes = BytesBuilder()
    ..addByte(0x00)
    ..add(<int>[0, 0, 0, 0])
    ..addByte(0x80)
    ..add(_u32be(trailer.length))
    ..add(trailer);
  response.add(bytes.toBytes());
  await response.close();
}

List<int> _u32be(int value) => <int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];
