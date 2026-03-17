import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/adapters/_ai_provider_http.dart';
import 'package:memos_flutter_app/data/ai/ai_settings_models.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_models.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_templates.dart';

void main() {
  test('HTTP proxy routes AI requests through the configured proxy', () async {
    var backendHits = 0;
    var proxyHits = 0;
    final backend = await _startJsonBackend(() => backendHits++);
    final proxy = await _startHttpProxy(() => proxyHits++);
    addTearDown(() async {
      await proxy.close(force: true);
      await backend.close(force: true);
    });

    final service = _service(
      baseUrl: 'http://${InternetAddress.loopbackIPv4.address}:${backend.port}',
      usesSharedProxy: true,
    );
    final dio = await buildAiProviderDio(
      service,
      proxySettings: AiProxySettings(
        protocol: AiProxyProtocol.http,
        host: InternetAddress.loopbackIPv4.address,
        port: proxy.port,
        bypassLocalAddresses: false,
      ),
    );
    addTearDown(() => dio.close(force: true));

    final response = await dio.get<Map<String, dynamic>>(
      resolveEndpoint(service.baseUrl, '/ping'),
    );

    expect(response.statusCode, 200);
    expect(response.data?['ok'], isTrue);
    expect(backendHits, 1);
    expect(proxyHits, 1);
  });

  test('SOCKS5 proxy routes AI requests without authentication', () async {
    var backendHits = 0;
    final backend = await _startJsonBackend(() => backendHits++);
    final proxy = await _Socks5ProxyServer.start();
    addTearDown(() async {
      await proxy.close();
      await backend.close(force: true);
    });

    final service = _service(
      baseUrl: 'http://${InternetAddress.loopbackIPv4.address}:${backend.port}',
      usesSharedProxy: true,
    );
    final dio = await buildAiProviderDio(
      service,
      proxySettings: AiProxySettings(
        protocol: AiProxyProtocol.socks5,
        host: InternetAddress.loopbackIPv4.address,
        port: proxy.port,
        bypassLocalAddresses: false,
      ),
    );
    addTearDown(() => dio.close(force: true));

    final response = await dio.get<Map<String, dynamic>>(
      resolveEndpoint(service.baseUrl, '/ping'),
    );

    expect(response.statusCode, 200);
    expect(response.data?['ok'], isTrue);
    expect(backendHits, 1);
    expect(proxy.connectCount, 1);
    expect(proxy.successfulAuthentications, 0);
  });

  test('SOCKS5 proxy forwards credentials when authentication is required', () async {
    var backendHits = 0;
    final backend = await _startJsonBackend(() => backendHits++);
    final proxy = await _Socks5ProxyServer.start(
      requiredUsername: 'demo',
      requiredPassword: 'secret',
    );
    addTearDown(() async {
      await proxy.close();
      await backend.close(force: true);
    });

    final service = _service(
      baseUrl: 'http://${InternetAddress.loopbackIPv4.address}:${backend.port}',
      usesSharedProxy: true,
    );
    final dio = await buildAiProviderDio(
      service,
      proxySettings: AiProxySettings(
        protocol: AiProxyProtocol.socks5,
        host: InternetAddress.loopbackIPv4.address,
        port: proxy.port,
        username: 'demo',
        password: 'secret',
        bypassLocalAddresses: false,
      ),
    );
    addTearDown(() => dio.close(force: true));

    final response = await dio.get<Map<String, dynamic>>(
      resolveEndpoint(service.baseUrl, '/ping'),
    );

    expect(response.statusCode, 200);
    expect(response.data?['ok'], isTrue);
    expect(backendHits, 1);
    expect(proxy.connectCount, 1);
    expect(proxy.successfulAuthentications, 1);
  });

  test('local targets bypass proxy when bypassLocalAddresses is enabled', () async {
    var backendHits = 0;
    var proxyHits = 0;
    final backend = await _startJsonBackend(() => backendHits++);
    final proxy = await _startHttpProxy(() => proxyHits++);
    addTearDown(() async {
      await proxy.close(force: true);
      await backend.close(force: true);
    });

    final service = _service(
      baseUrl: 'http://${InternetAddress.loopbackIPv4.address}:${backend.port}',
      usesSharedProxy: true,
    );
    final dio = await buildAiProviderDio(
      service,
      proxySettings: AiProxySettings(
        protocol: AiProxyProtocol.http,
        host: InternetAddress.loopbackIPv4.address,
        port: proxy.port,
        bypassLocalAddresses: true,
      ),
    );
    addTearDown(() => dio.close(force: true));

    final response = await dio.get<Map<String, dynamic>>(
      resolveEndpoint(service.baseUrl, '/ping'),
    );

    expect(response.statusCode, 200);
    expect(response.data?['ok'], isTrue);
    expect(backendHits, 1);
    expect(proxyHits, 0);
  });

  test('proxy-enabled services fail fast when shared proxy is incomplete', () async {
    final service = _service(
      baseUrl: 'https://api.openai.com',
      usesSharedProxy: true,
    );

    await expectLater(
      () => buildAiProviderDio(service, proxySettings: const AiProxySettings()),
      throwsA(
        predicate<Object>(
          (error) =>
              error is StateError &&
              error.toString().contains(
                '\u8be5\u670d\u52a1\u5df2\u542f\u7528\u4ee3\u7406\uff0c\u4f46 AI \u4ee3\u7406\u8bbe\u7f6e\u5c1a\u672a\u914d\u7f6e\u5b8c\u6574',
              ),
        ),
      ),
    );
  });
}

Future<HttpServer> _startJsonBackend(void Function() onRequest) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      onRequest();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'ok': true}));
      await request.response.close();
    }),
  );
  return server;
}

Future<HttpServer> _startHttpProxy(void Function() onRequest) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      onRequest();
      final targetUri = _resolveProxyTargetUri(request);
      final client = HttpClient();
      try {
        final upstreamRequest = await client.openUrl(request.method, targetUri);
        request.headers.forEach((name, values) {
          if (name.toLowerCase() == HttpHeaders.hostHeader) {
            return;
          }
          for (final value in values) {
            upstreamRequest.headers.add(name, value);
          }
        });
        await request.cast<List<int>>().pipe(upstreamRequest);
        final upstreamResponse = await upstreamRequest.close();
        request.response.statusCode = upstreamResponse.statusCode;
        upstreamResponse.headers.forEach((name, values) {
          for (final value in values) {
            request.response.headers.add(name, value);
          }
        });
        await upstreamResponse.pipe(request.response);
      } finally {
        client.close(force: true);
      }
    }),
  );
  return server;
}

Uri _resolveProxyTargetUri(HttpRequest request) {
  final requestedUri = request.requestedUri;
  if (requestedUri.hasScheme) {
    return requestedUri;
  }
  final hostHeader = request.headers.host;
  final port = request.connectionInfo?.localPort ?? 80;
  return Uri(
    scheme: 'http',
    host: hostHeader,
    port: port,
    path: request.uri.path,
    query: request.uri.hasQuery ? request.uri.query : null,
  );
}

AiServiceInstance _service({
  required String baseUrl,
  required bool usesSharedProxy,
}) {
  return AiServiceInstance(
    serviceId: 'svc_proxy_test',
    templateId: aiTemplateOpenAi,
    adapterKind: AiProviderAdapterKind.openAiCompatible,
    displayName: 'Proxy Test',
    enabled: true,
    usesSharedProxy: usesSharedProxy,
    baseUrl: baseUrl,
    apiKey: 'sk-test',
    customHeaders: const <String, String>{},
    models: const <AiModelEntry>[],
    lastValidatedAt: null,
    lastValidationStatus: AiValidationStatus.unknown,
    lastValidationMessage: null,
  );
}

class _Socks5ProxyServer {
  _Socks5ProxyServer._(
    this._server, {
    this.requiredUsername,
    this.requiredPassword,
  });

  final ServerSocket _server;
  final String? requiredUsername;
  final String? requiredPassword;
  final Set<Socket> _sockets = <Socket>{};

  var connectCount = 0;
  var successfulAuthentications = 0;

  int get port => _server.port;

  static Future<_Socks5ProxyServer> start({
    String? requiredUsername,
    String? requiredPassword,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = _Socks5ProxyServer._(
      server,
      requiredUsername: requiredUsername,
      requiredPassword: requiredPassword,
    );
    server.listen(proxy._handleClient);
    return proxy;
  }

  Future<void> close() async {
    for (final socket in _sockets.toList(growable: false)) {
      await socket.close();
      socket.destroy();
    }
    await _server.close();
  }

  Future<void> _handleClient(Socket client) async {
    _sockets.add(client);
    final reader = _SocketBufferReader(client);
    Socket? upstream;
    StreamSubscription<List<int>>? upstreamSubscription;
    try {
      final greetingHeader = await reader.readExact(2);
      final methodCount = greetingHeader[1];
      final methods = await reader.readExact(methodCount);
      final requiresAuth = requiredUsername != null || requiredPassword != null;
      final selectedMethod = requiresAuth ? 0x02 : 0x00;
      if (!methods.contains(selectedMethod)) {
        client.add(const <int>[0x05, 0xff]);
        await client.flush();
        return;
      }

      client.add(<int>[0x05, selectedMethod]);
      await client.flush();

      if (selectedMethod == 0x02) {
        final authVersion = (await reader.readExact(1)).single;
        final usernameLength = (await reader.readExact(1)).single;
        final username = utf8.decode(await reader.readExact(usernameLength));
        final passwordLength = (await reader.readExact(1)).single;
        final password = utf8.decode(await reader.readExact(passwordLength));
        final authenticated =
            authVersion == 0x01 &&
            username == requiredUsername &&
            password == requiredPassword;
        client.add(<int>[0x01, authenticated ? 0x00 : 0x01]);
        await client.flush();
        if (!authenticated) {
          return;
        }
        successfulAuthentications++;
      }

      final requestHeader = await reader.readExact(4);
      final command = requestHeader[1];
      final addressType = requestHeader[3];
      if (command != 0x01) {
        client.add(const <int>[0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await client.flush();
        return;
      }

      final destinationHost = await _readDestinationHost(reader, addressType);
      final portBytes = await reader.readExact(2);
      final destinationPort = (portBytes[0] << 8) | portBytes[1];

      upstream = await Socket.connect(destinationHost, destinationPort);
      connectCount++;

      client.add(const <int>[0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
      await client.flush();

      reader.relayTo(upstream);
      upstreamSubscription = upstream.listen(
        client.add,
        onDone: client.destroy,
        onError: (Object error, StackTrace stackTrace) {
          client.destroy();
        },
        cancelOnError: true,
      );

      await Future.any<void>(<Future<void>>[client.done, upstream.done]);
    } finally {
      await upstreamSubscription?.cancel();
      await reader.dispose();
      await upstream?.close();
      upstream?.destroy();
      await client.close();
      client.destroy();
      _sockets.remove(client);
    }
  }

  Future<String> _readDestinationHost(
    _SocketBufferReader reader,
    int addressType,
  ) async {
    switch (addressType) {
      case 0x01:
        final bytes = await reader.readExact(4);
        return bytes.join('.');
      case 0x03:
        final length = (await reader.readExact(1)).single;
        return utf8.decode(await reader.readExact(length));
      case 0x04:
        final bytes = await reader.readExact(16);
        return InternetAddress.fromRawAddress(
          bytes,
          type: InternetAddressType.IPv6,
        ).address;
    }
    throw UnsupportedError('Unsupported SOCKS5 address type: $addressType');
  }
}

class _SocketBufferReader {
  _SocketBufferReader(this.socket) {
    _subscription = socket.listen(
      (data) {
        _buffer.addAll(data);
        _resolveWaiter();
      },
      onDone: () {
        _closed = true;
        _resolveWaiter();
      },
      onError: (Object error, StackTrace stackTrace) {
        _error = error;
        _stackTrace = stackTrace;
        _closed = true;
        _resolveWaiter();
      },
      cancelOnError: true,
    );
  }

  final Socket socket;
  final Queue<int> _buffer = Queue<int>();
  late final StreamSubscription<List<int>> _subscription;

  Completer<void>? _waiter;
  var _closed = false;
  Object? _error;
  StackTrace? _stackTrace;

  Future<Uint8List> readExact(int length) async {
    while (_buffer.length < length) {
      if (_closed) {
        if (_error != null && _stackTrace != null) {
          Error.throwWithStackTrace(_error!, _stackTrace!);
        }
        throw StateError('Unexpected end of SOCKS5 stream.');
      }
      _waiter ??= Completer<void>();
      await _waiter!.future;
    }

    final bytes = Uint8List(length);
    for (var index = 0; index < length; index++) {
      bytes[index] = _buffer.removeFirst();
    }
    return bytes;
  }

  void relayTo(Socket upstream) {
    if (_buffer.isNotEmpty) {
      upstream.add(Uint8List.fromList(_buffer.toList(growable: false)));
      _buffer.clear();
    }
    _subscription.onData(upstream.add);
    _subscription.onDone(upstream.destroy);
    _subscription.onError((Object error, StackTrace stackTrace) {
      upstream.destroy();
    });
  }

  Future<void> dispose() => _subscription.cancel();

  void _resolveWaiter() {
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) {
      _waiter = null;
      waiter.complete();
    }
  }
}
