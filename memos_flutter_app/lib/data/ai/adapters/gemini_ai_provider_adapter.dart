import 'package:dio/dio.dart';

import '../ai_provider_adapter.dart';
import '../ai_provider_models.dart';
import '_ai_provider_http.dart';

class GeminiAiProviderAdapter implements AiProviderAdapter {
  const GeminiAiProviderAdapter();

  @override
  Future<AiServiceValidationResult> validateConfig(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }
  ) async {
    final baseUrl = _baseUrl(service.baseUrl);
    if (baseUrl.isEmpty) {
      return const AiServiceValidationResult(
        status: AiValidationStatus.failed,
        message: 'Base URL is required.',
      );
    }
    final endpoint = resolveEndpoint(baseUrl, 'models');
    final queryParameters = _queryParameters(service);
    final headers = _requestHeaders(service);
    final dio = await buildAiProviderDio(service, proxySettings: proxySettings);
    final stopwatch = logAiProviderRequestStarted(
      service,
      operation: 'validate_config',
      method: 'GET',
      endpoint: endpoint,
      proxySettings: proxySettings,
      queryParameters: queryParameters,
      requestHeaders: headers,
    );
    try {
      final response = await dio.get<Object?>(
        endpoint,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      final statusCode = response.statusCode;
      if ((statusCode ?? 0) >= 200 && (statusCode ?? 0) < 300) {
        logAiProviderRequestFinished(
          service,
          stopwatch,
          operation: 'validate_config',
          method: 'GET',
          endpoint: endpoint,
          proxySettings: proxySettings,
          queryParameters: queryParameters,
          requestHeaders: headers,
          statusCode: statusCode,
          responseMessage: 'Connection succeeded.',
        );
        return const AiServiceValidationResult(
          status: AiValidationStatus.success,
          message: 'Connection succeeded.',
        );
      }
      final message = errorMessageFromResponse(response.data);
      logAiProviderRequestFailed(
        service,
        stopwatch,
        operation: 'validate_config',
        method: 'GET',
        endpoint: endpoint,
        proxySettings: proxySettings,
        queryParameters: queryParameters,
        requestHeaders: headers,
        statusCode: statusCode,
        responseMessage: message,
      );
      return AiServiceValidationResult(
        status: AiValidationStatus.failed,
        message: message,
      );
    } catch (error, stackTrace) {
      final message = extractErrorMessage(error);
      logAiProviderRequestFailed(
        service,
        stopwatch,
        operation: 'validate_config',
        method: 'GET',
        endpoint: endpoint,
        proxySettings: proxySettings,
        queryParameters: queryParameters,
        requestHeaders: headers,
        error: error,
        stackTrace: stackTrace,
        responseMessage: message,
      );
      return AiServiceValidationResult(
        status: AiValidationStatus.failed,
        message: message,
      );
    }
  }

  @override
  Future<List<AiDiscoveredModel>> listModels(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) async {
    final baseUrl = _baseUrl(service.baseUrl);
    if (baseUrl.isEmpty) return const <AiDiscoveredModel>[];
    final endpoint = resolveEndpoint(baseUrl, 'models');
    final queryParameters = _queryParameters(service);
    final headers = _requestHeaders(service);
    final dio = await buildAiProviderDio(service, proxySettings: proxySettings);
    final stopwatch = logAiProviderRequestStarted(
      service,
      operation: 'list_models',
      method: 'GET',
      endpoint: endpoint,
      proxySettings: proxySettings,
      queryParameters: queryParameters,
      requestHeaders: headers,
    );
    var failureLogged = false;
    try {
      final response = await dio.get<Object?>(
        endpoint,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      final statusCode = response.statusCode;
      if ((statusCode ?? 0) < 200 || (statusCode ?? 0) >= 300) {
        final message = errorMessageFromResponse(response.data);
        failureLogged = true;
        logAiProviderRequestFailed(
          service,
          stopwatch,
          operation: 'list_models',
          method: 'GET',
          endpoint: endpoint,
          proxySettings: proxySettings,
          queryParameters: queryParameters,
          requestHeaders: headers,
          statusCode: statusCode,
          responseMessage: message,
        );
        throw StateError(message);
      }
      final data = response.data;
      if (data is! Map || data['models'] is! List) {
        logAiProviderRequestFinished(
          service,
          stopwatch,
          operation: 'list_models',
          method: 'GET',
          endpoint: endpoint,
          proxySettings: proxySettings,
          queryParameters: queryParameters,
          requestHeaders: headers,
          statusCode: statusCode,
          discoveredCount: 0,
          responseMessage: 'No model list returned.',
        );
        return const <AiDiscoveredModel>[];
      }
      final models = <AiDiscoveredModel>[];
      for (final item in (data['models'] as List)) {
        if (item is! Map) continue;
        final rawName = (item['name'] ?? '').toString().trim();
        if (rawName.isEmpty) continue;
        final modelKey = rawName.replaceFirst(RegExp(r'^models/'), '');
        final supportedMethods = (item['supportedGenerationMethods'] is List)
            ? (item['supportedGenerationMethods'] as List)
                  .map((method) => method.toString().trim())
                  .toSet()
            : const <String>{};
        final capabilities = <AiCapability>[];
        if (supportedMethods.contains('generateContent') ||
            supportedMethods.isEmpty) {
          capabilities.add(AiCapability.chat);
        }
        if (supportedMethods.contains('embedContent')) {
          capabilities.add(AiCapability.embedding);
        }
        models.add(
          AiDiscoveredModel(
            displayName: (item['displayName'] ?? modelKey).toString().trim(),
            modelKey: modelKey,
            capabilities: capabilities.isEmpty
                ? const <AiCapability>[AiCapability.chat]
                : capabilities,
          ),
        );
      }
      logAiProviderRequestFinished(
        service,
        stopwatch,
        operation: 'list_models',
        method: 'GET',
        endpoint: endpoint,
        proxySettings: proxySettings,
        queryParameters: queryParameters,
        requestHeaders: headers,
        statusCode: statusCode,
        discoveredCount: models.length,
      );
      return models;
    } catch (error, stackTrace) {
      if (!failureLogged) {
        logAiProviderRequestFailed(
          service,
          stopwatch,
          operation: 'list_models',
          method: 'GET',
          endpoint: endpoint,
          proxySettings: proxySettings,
          queryParameters: queryParameters,
          requestHeaders: headers,
          error: error,
          stackTrace: stackTrace,
          responseMessage: extractErrorMessage(error),
        );
      }
      rethrow;
    }
  }

  @override
  Future<AiChatCompletionResult> chatCompletion(
    AiChatCompletionRequest request,
  ) {
    throw UnsupportedError('Chat completion is not wired to runtime yet.');
  }

  @override
  Future<List<double>> embed(AiEmbeddingRequest request) {
    throw UnsupportedError('Embeddings are not wired to runtime yet.');
  }

  String _baseUrl(String baseUrl) {
    final normalized = normalizeBaseUrl(baseUrl);
    if (normalized.isEmpty) return normalized;
    if (normalized.contains('/v1beta') || normalized.contains('/v1/')) {
      return normalized;
    }
    return '$normalized/v1beta';
  }

  Map<String, Object?> _queryParameters(AiServiceInstance service) {
    final apiKey = service.apiKey.trim();
    return apiKey.isEmpty
        ? const <String, Object?>{}
        : <String, Object?>{'key': apiKey};
  }

  Map<String, String> _requestHeaders(AiServiceInstance service) {
    final headers = Map<String, String>.from(service.customHeaders);
    final apiKey = service.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers.putIfAbsent('x-goog-api-key', () => apiKey);
    }
    return headers;
  }
}
