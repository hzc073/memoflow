import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:socks5_proxy/socks_client.dart';

import '../../../core/log_sanitizer.dart';
import '../../logs/log_manager.dart';
import '../ai_provider_models.dart';
import '../ai_settings_log.dart';
import '../ai_settings_models.dart';

enum AiProviderRequestTimeoutProfile { short, embedding, chatCompletion }

const _proxyConfigurationRequiredMessage =
    '\u8be5\u670d\u52a1\u5df2\u542f\u7528\u4ee3\u7406\uff0c\u4f46 AI \u4ee3\u7406\u8bbe\u7f6e\u5c1a\u672a\u914d\u7f6e\u5b8c\u6574';

Future<Dio> buildAiProviderDio(
  AiServiceInstance service, {
  AiProxySettings? proxySettings,
  AiProviderRequestTimeoutProfile profile =
      AiProviderRequestTimeoutProfile.short,
}) async {
  final receiveTimeout = switch (profile) {
    AiProviderRequestTimeoutProfile.short => const Duration(seconds: 20),
    AiProviderRequestTimeoutProfile.embedding => const Duration(seconds: 45),
    AiProviderRequestTimeoutProfile.chatCompletion => const Duration(
      seconds: 180,
    ),
  };
  final sendTimeout = switch (profile) {
    AiProviderRequestTimeoutProfile.short => const Duration(seconds: 20),
    AiProviderRequestTimeoutProfile.embedding => const Duration(seconds: 30),
    AiProviderRequestTimeoutProfile.chatCompletion => const Duration(
      seconds: 60,
    ),
  };
  final proxyDecision = await _resolveProxyDecision(service, proxySettings);
  final dio = Dio(
    BaseOptions(
      headers: Map<String, String>.from(service.customHeaders),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      _configureProxy(client, proxyDecision);
      return client;
    },
  );
  return dio;
}

String normalizeBaseUrl(String baseUrl) {
  return baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
}

bool hasApiVersionSegment(String hostOrPath) {
  final normalized = hostOrPath.trim();
  if (normalized.isEmpty) return false;
  final regex = RegExp(r'/v\d+(?:alpha|beta)?(?=/|$)', caseSensitive: false);
  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.hasScheme) {
    return regex.hasMatch(uri.path);
  }
  return regex.hasMatch(normalized);
}

String ensureVersionSegment(String baseUrl, String segment) {
  final normalizedBase = normalizeBaseUrl(baseUrl);
  if (normalizedBase.isEmpty) return normalizedBase;
  if (hasApiVersionSegment(normalizedBase)) {
    return normalizedBase;
  }
  final normalizedSegment = segment.replaceFirst(RegExp(r'^/+'), '');
  if (normalizedBase.endsWith('/$normalizedSegment')) {
    return normalizedBase;
  }
  return '$normalizedBase/$normalizedSegment';
}

String normalizeOpenAiCompatibleApiBaseUrl(AiServiceInstance service) {
  return normalizeBaseUrl(service.baseUrl);
}

String normalizeAnthropicApiBaseUrl(String baseUrl) {
  return ensureVersionSegment(baseUrl, 'v1');
}

String normalizeGeminiApiBaseUrl(String baseUrl) {
  return ensureVersionSegment(baseUrl, 'v1beta');
}

String normalizeAzureOpenAiApiBaseUrl(String baseUrl) {
  final normalized = normalizeBaseUrl(baseUrl);
  if (normalized.isEmpty) return normalized;
  final withoutV1 = normalized.replaceFirst(
    RegExp(r'/v1$', caseSensitive: false),
    '',
  );
  final withoutOpenAi = withoutV1.replaceFirst(
    RegExp(r'/openai$', caseSensitive: false),
    '',
  );
  return '${normalizeBaseUrl(withoutOpenAi)}/openai';
}

String normalizeOllamaApiBaseUrl(String baseUrl) {
  final normalized = normalizeBaseUrl(baseUrl);
  if (normalized.isEmpty) return normalized;
  final withoutV1 = normalized.replaceFirst(
    RegExp(r'/v1$', caseSensitive: false),
    '',
  );
  final withoutApi = withoutV1.replaceFirst(
    RegExp(r'/api$', caseSensitive: false),
    '',
  );
  final withoutChat = withoutApi.replaceFirst(
    RegExp(r'/chat$', caseSensitive: false),
    '',
  );
  return '${normalizeBaseUrl(withoutChat)}/api';
}

String resolveEndpoint(String baseUrl, String path) {
  final normalizedBase = normalizeBaseUrl(baseUrl);
  final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
  if (normalizedBase.isEmpty) return normalizedPath;
  return '$normalizedBase/$normalizedPath';
}

Stopwatch logAiProviderRequestStarted(
  AiServiceInstance service, {
  required String operation,
  required String method,
  required String endpoint,
  AiProxySettings? proxySettings,
  Map<String, Object?>? queryParameters,
  Map<String, String>? requestHeaders,
}) {
  final stopwatch = Stopwatch()..start();
  LogManager.instance.info(
    'AI adapter request started',
    context: _buildAiProviderRequestLogContext(
      service,
      operation: operation,
      method: method,
      endpoint: endpoint,
      proxySettings: proxySettings,
      queryParameters: queryParameters,
      requestHeaders: requestHeaders,
    ),
  );
  return stopwatch;
}

void logAiProviderRequestFinished(
  AiServiceInstance service,
  Stopwatch stopwatch, {
  required String operation,
  required String method,
  required String endpoint,
  AiProxySettings? proxySettings,
  Map<String, Object?>? queryParameters,
  Map<String, String>? requestHeaders,
  int? statusCode,
  int? discoveredCount,
  String? responseMessage,
}) {
  if (stopwatch.isRunning) {
    stopwatch.stop();
  }
  LogManager.instance.info(
    'AI adapter request finished',
    context: _buildAiProviderRequestLogContext(
      service,
      operation: operation,
      method: method,
      endpoint: endpoint,
      proxySettings: proxySettings,
      queryParameters: queryParameters,
      requestHeaders: requestHeaders,
      statusCode: statusCode,
      elapsedMs: stopwatch.elapsedMilliseconds,
      discoveredCount: discoveredCount,
      responseMessage: responseMessage,
    ),
  );
}

void logAiProviderRequestFailed(
  AiServiceInstance service,
  Stopwatch stopwatch, {
  required String operation,
  required String method,
  required String endpoint,
  AiProxySettings? proxySettings,
  Map<String, Object?>? queryParameters,
  Map<String, String>? requestHeaders,
  int? statusCode,
  Object? error,
  StackTrace? stackTrace,
  String? responseMessage,
}) {
  if (stopwatch.isRunning) {
    stopwatch.stop();
  }
  final resolvedStatusCode =
      statusCode ?? (error is DioException ? error.response?.statusCode : null);
  LogManager.instance.warn(
    'AI adapter request failed',
    error: error,
    stackTrace: stackTrace,
    context: _buildAiProviderRequestLogContext(
      service,
      operation: operation,
      method: method,
      endpoint: endpoint,
      proxySettings: proxySettings,
      queryParameters: queryParameters,
      requestHeaders: requestHeaders,
      statusCode: resolvedStatusCode,
      elapsedMs: stopwatch.elapsedMilliseconds,
      responseMessage: responseMessage,
    ),
  );
}

void logAiProviderRequestUnsupported(
  AiServiceInstance service, {
  required String operation,
  required String method,
  required String endpoint,
  AiProxySettings? proxySettings,
  Map<String, Object?>? queryParameters,
  Map<String, String>? requestHeaders,
  String? reason,
}) {
  LogManager.instance.info(
    'AI adapter request unsupported',
    context: _buildAiProviderRequestLogContext(
      service,
      operation: operation,
      method: method,
      endpoint: endpoint,
      proxySettings: proxySettings,
      queryParameters: queryParameters,
      requestHeaders: requestHeaders,
      responseMessage: reason,
    ),
  );
}

String extractErrorMessage(
  Object error, {
  String fallback = 'Request failed.',
}) {
  if (error is DioException) {
    final response = error.response;
    if (response != null) {
      return errorMessageFromResponse(response.data, fallback: fallback);
    }
    return error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : fallback;
  }
  final message = error.toString().trim();
  if (message.isEmpty) return fallback;
  return message.replaceFirst('Exception: ', '');
}

String errorMessageFromResponse(
  Object? data, {
  String fallback = 'Request failed.',
}) {
  if (data is Map) {
    final directMessage = _readMessage(data);
    if (directMessage != null) return directMessage;
    final error = data['error'];
    if (error is Map) {
      final nestedMessage = _readMessage(error);
      if (nestedMessage != null) return nestedMessage;
    }
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
  }
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }
  return fallback;
}

String? _readMessage(Map data) {
  for (final key in const <String>['message', 'detail', 'error_msg', 'code']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

Map<String, Object?> _buildAiProviderRequestLogContext(
  AiServiceInstance service, {
  required String operation,
  required String method,
  required String endpoint,
  AiProxySettings? proxySettings,
  Map<String, Object?>? queryParameters,
  Map<String, String>? requestHeaders,
  int? statusCode,
  int? elapsedMs,
  int? discoveredCount,
  String? responseMessage,
}) {
  final resolvedSettings = proxySettings ?? AiProxySettings.defaults;
  return <String, Object?>{
    ...buildAiServiceLogContext(
      service,
      endpoint: endpoint,
      discoveredCount: discoveredCount,
    ),
    'operation': operation,
    'method': method.toUpperCase(),
    'proxy_mode': describeAiProxyMode(service, proxySettings: proxySettings),
    if (_shouldLogProxyAddress(service, proxySettings: proxySettings))
      'proxy_host': LogSanitizer.maskHost(resolvedSettings.host),
    if (_shouldLogProxyAddress(service, proxySettings: proxySettings))
      'proxy_port': resolvedSettings.port,
    if (requestHeaders != null) 'request_header_count': requestHeaders.length,
    if (requestHeaders != null && requestHeaders.isNotEmpty)
      'request_headers': LogSanitizer.sanitizeHeaders(requestHeaders),
    if (queryParameters != null) 'query_param_count': queryParameters.length,
    if (queryParameters != null && queryParameters.isNotEmpty)
      'query_params': LogSanitizer.sanitizeJson(queryParameters),
    if (statusCode != null) 'status_code': statusCode,
    if (elapsedMs != null) 'elapsed_ms': elapsedMs,
    if (responseMessage != null && responseMessage.trim().isNotEmpty)
      'response_message': LogSanitizer.sanitizeText(responseMessage.trim()),
  };
}

String describeAiProxyMode(
  AiServiceInstance service, {
  AiProxySettings? proxySettings,
}) {
  if (!service.usesSharedProxy) return 'direct';
  final settings = proxySettings ?? AiProxySettings.defaults;
  if (!settings.isConfigured) return 'misconfigured';
  if (settings.bypassLocalAddresses &&
      isLocalOrPrivateBaseUrl(service.baseUrl)) {
    return 'bypass_local';
  }
  return settings.protocol.name;
}

bool _shouldLogProxyAddress(
  AiServiceInstance service, {
  AiProxySettings? proxySettings,
}) {
  final mode = describeAiProxyMode(service, proxySettings: proxySettings);
  return mode == AiProxyProtocol.http.name ||
      mode == AiProxyProtocol.socks5.name;
}

Future<_AiProxyDecision> _resolveProxyDecision(
  AiServiceInstance service,
  AiProxySettings? proxySettings,
) async {
  if (!service.usesSharedProxy) {
    return const _AiProxyDecision(mode: 'direct');
  }
  final settings = proxySettings ?? AiProxySettings.defaults;
  if (!settings.isConfigured) {
    throw StateError(_proxyConfigurationRequiredMessage);
  }
  if (settings.bypassLocalAddresses &&
      isLocalOrPrivateBaseUrl(service.baseUrl)) {
    return const _AiProxyDecision(mode: 'bypass_local');
  }
  if (settings.protocol == AiProxyProtocol.http) {
    return _AiProxyDecision(
      mode: AiProxyProtocol.http.name,
      settings: settings,
    );
  }
  return _AiProxyDecision(
    mode: AiProxyProtocol.socks5.name,
    settings: settings,
    resolvedProxyHost: await _resolveProxyHost(settings.host),
  );
}

void _configureProxy(HttpClient client, _AiProxyDecision decision) {
  final settings = decision.settings;
  if (settings == null || !settings.isConfigured) {
    return;
  }
  if (decision.mode == AiProxyProtocol.http.name) {
    client.findProxy = (uri) => 'PROXY ${settings.host}:${settings.port}';
    if (settings.username.trim().isNotEmpty ||
        settings.password.trim().isNotEmpty) {
      client.authenticateProxy = (host, port, scheme, realm) async {
        client.addProxyCredentials(
          host,
          port,
          realm ?? '',
          HttpClientBasicCredentials(settings.username, settings.password),
        );
        return true;
      };
    }
    return;
  }
  if (decision.mode == AiProxyProtocol.socks5.name &&
      decision.resolvedProxyHost != null) {
    SocksTCPClient.assignToHttpClient(client, <ProxySettings>[
      ProxySettings(
        decision.resolvedProxyHost!,
        settings.port,
        username: settings.username.trim().isEmpty ? null : settings.username,
        password: settings.password.trim().isEmpty ? null : settings.password,
      ),
    ]);
  }
}

Future<InternetAddress> _resolveProxyHost(String host) async {
  final normalized = host.trim();
  final parsed = InternetAddress.tryParse(normalized);
  if (parsed != null) return parsed;
  final lookedUp = await InternetAddress.lookup(normalized);
  if (lookedUp.isEmpty) {
    throw StateError('Unable to resolve proxy host.');
  }
  return lookedUp.first;
}

bool isLocalOrPrivateBaseUrl(String baseUrl) {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed) ?? Uri.tryParse('http://$trimmed');
  final host = uri?.host.trim().toLowerCase() ?? '';
  if (host.isEmpty) return false;
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final parsed = InternetAddress.tryParse(host);
  if (parsed == null) return false;
  if (parsed.isLoopback) return true;
  final raw = parsed.rawAddress;
  if (parsed.type == InternetAddressType.IPv4 && raw.length == 4) {
    final first = raw[0];
    final second = raw[1];
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        (first == 169 && second == 254) ||
        first == 127;
  }
  if (parsed.type == InternetAddressType.IPv6 && raw.length == 16) {
    final first = raw[0];
    final second = raw[1];
    final isUniqueLocal = (first & 0xfe) == 0xfc;
    final isLinkLocal = first == 0xfe && (second & 0xc0) == 0x80;
    return isUniqueLocal || isLinkLocal;
  }
  return false;
}

class _AiProxyDecision {
  const _AiProxyDecision({
    required this.mode,
    this.settings,
    this.resolvedProxyHost,
  });

  final String mode;
  final AiProxySettings? settings;
  final InternetAddress? resolvedProxyHost;
}

List<AiCapability> inferOpenAiCompatibleCapabilities(String modelKey) {
  final normalized = modelKey.trim().toLowerCase();
  if (normalized.contains('embed') || normalized.contains('embedding')) {
    return const <AiCapability>[AiCapability.embedding];
  }
  return const <AiCapability>[AiCapability.chat];
}

List<AiCapability> inferOllamaCapabilities(String modelKey) {
  final normalized = modelKey.trim().toLowerCase();
  if (normalized.contains('embed') || normalized.contains('embedding')) {
    return const <AiCapability>[AiCapability.embedding];
  }
  return const <AiCapability>[AiCapability.chat];
}
