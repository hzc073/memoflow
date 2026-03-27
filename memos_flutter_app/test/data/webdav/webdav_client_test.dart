import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/webdav_settings.dart';
import 'package:memos_flutter_app/data/webdav/webdav_client.dart';

void main() {
  late HttpServer server;
  late Uri baseUrl;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = Uri.parse('http://${server.address.host}:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('put sends content-length instead of chunked transfer', () async {
    final requests = <Map<String, String?>>[];
    server.listen((request) async {
      await request.drain<List<int>>(<int>[]);
      requests.add(<String, String?>{
        'content-length': request.headers.value(
          HttpHeaders.contentLengthHeader,
        ),
        'transfer-encoding': request.headers.value(
          HttpHeaders.transferEncodingHeader,
        ),
      });
      request.response.statusCode = HttpStatus.created;
      await request.response.close();
    });

    final client = WebDavClient(
      baseUrl: baseUrl,
      username: '',
      password: '',
      authMode: WebDavAuthMode.basic,
      ignoreBadCert: false,
    );
    addTearDown(client.close);

    final payload = utf8.encode('hello webdav');
    final response = await client.put(
      baseUrl.replace(path: '/memo.md'),
      body: payload,
    );

    expect(response.statusCode, HttpStatus.created);
    expect(requests, hasLength(1));
    expect(requests.single['content-length'], '${payload.length}');
    expect(requests.single['transfer-encoding'], isNull);
  });

  test('put retries on rate limit responses', () async {
    var attempts = 0;
    server.listen((request) async {
      await request.drain<List<int>>(<int>[]);
      attempts += 1;
      if (attempts < 3) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.headers.set(HttpHeaders.retryAfterHeader, '0');
      } else {
        request.response.statusCode = HttpStatus.created;
      }
      await request.response.close();
    });

    final client = WebDavClient(
      baseUrl: baseUrl,
      username: '',
      password: '',
      authMode: WebDavAuthMode.basic,
      ignoreBadCert: false,
    );
    addTearDown(client.close);

    final response = await client.put(
      baseUrl.replace(path: '/retry.md'),
      body: utf8.encode('retry me'),
    );

    expect(response.statusCode, HttpStatus.created);
    expect(attempts, 3);
  });

  test('write requests are throttled between attempts', () async {
    server.listen((request) async {
      await request.drain<List<int>>(<int>[]);
      request.response.statusCode = HttpStatus.created;
      await request.response.close();
    });

    final delays = <Duration>[];
    final client = WebDavClient(
      baseUrl: baseUrl,
      username: '',
      password: '',
      authMode: WebDavAuthMode.basic,
      ignoreBadCert: false,
      writeCooldown: const Duration(milliseconds: 180),
      delayRunner: (delay) async {
        delays.add(delay);
      },
    );
    addTearDown(client.close);

    await client.put(
      baseUrl.replace(path: '/first.md'),
      body: utf8.encode('one'),
    );
    await client.put(
      baseUrl.replace(path: '/second.md'),
      body: utf8.encode('two'),
    );

    expect(delays, hasLength(1));
    expect(delays.single, greaterThan(const Duration(milliseconds: 120)));
    expect(delays.single, lessThanOrEqualTo(const Duration(milliseconds: 180)));
  });

  test('put backs off exponentially on server errors', () async {
    var attempts = 0;
    server.listen((request) async {
      await request.drain<List<int>>(<int>[]);
      attempts += 1;
      request.response.statusCode = attempts < 3
          ? HttpStatus.serviceUnavailable
          : HttpStatus.created;
      await request.response.close();
    });

    final delays = <Duration>[];
    final client = WebDavClient(
      baseUrl: baseUrl,
      username: '',
      password: '',
      authMode: WebDavAuthMode.basic,
      ignoreBadCert: false,
      writeCooldown: Duration.zero,
      delayRunner: (delay) async {
        delays.add(delay);
      },
    );
    addTearDown(client.close);

    final response = await client.put(
      baseUrl.replace(path: '/503.md'),
      body: utf8.encode('retry me'),
    );

    expect(response.statusCode, HttpStatus.created);
    expect(attempts, 3);
    expect(delays, hasLength(2));
    expect(delays[0], greaterThanOrEqualTo(const Duration(seconds: 1)));
    expect(delays[0], lessThan(const Duration(milliseconds: 1251)));
    expect(delays[1], greaterThanOrEqualTo(const Duration(seconds: 2)));
    expect(delays[1], lessThan(const Duration(milliseconds: 2251)));
  });
}
