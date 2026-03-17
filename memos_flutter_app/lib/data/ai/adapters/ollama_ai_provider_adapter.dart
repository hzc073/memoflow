import '../ai_provider_adapter.dart';
import '../ai_provider_models.dart';
import '_ai_provider_http.dart';

class OllamaAiProviderAdapter implements AiProviderAdapter {
  const OllamaAiProviderAdapter();

  @override
  Future<AiServiceValidationResult> validateConfig(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }
  ) async {
    final baseUrl = normalizeBaseUrl(service.baseUrl);
    if (baseUrl.isEmpty) {
      return const AiServiceValidationResult(
        status: AiValidationStatus.failed,
        message: 'Base URL is required.',
      );
    }
    final endpoint = resolveEndpoint(baseUrl, 'api/tags');
    final dio = await buildAiProviderDio(service, proxySettings: proxySettings);
    final stopwatch = logAiProviderRequestStarted(
      service,
      operation: 'validate_config',
      method: 'GET',
      endpoint: endpoint,
      proxySettings: proxySettings,
    );
    try {
      final response = await dio.get<Object?>(endpoint);
      final statusCode = response.statusCode;
      if ((statusCode ?? 0) >= 200 && (statusCode ?? 0) < 300) {
        logAiProviderRequestFinished(
          service,
          stopwatch,
          operation: 'validate_config',
          method: 'GET',
          endpoint: endpoint,
          proxySettings: proxySettings,
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
    final baseUrl = normalizeBaseUrl(service.baseUrl);
    if (baseUrl.isEmpty) return const <AiDiscoveredModel>[];
    final endpoint = resolveEndpoint(baseUrl, 'api/tags');
    final dio = await buildAiProviderDio(service, proxySettings: proxySettings);
    final stopwatch = logAiProviderRequestStarted(
      service,
      operation: 'list_models',
      method: 'GET',
      endpoint: endpoint,
      proxySettings: proxySettings,
    );
    var failureLogged = false;
    try {
      final response = await dio.get<Object?>(endpoint);
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
          statusCode: statusCode,
          discoveredCount: 0,
          responseMessage: 'No model list returned.',
        );
        return const <AiDiscoveredModel>[];
      }
      final models = <AiDiscoveredModel>[];
      for (final item in (data['models'] as List)) {
        if (item is! Map) continue;
        final modelKey = (item['model'] ?? item['name'] ?? '')
            .toString()
            .trim();
        if (modelKey.isEmpty) continue;
        final displayName = (item['name'] ?? modelKey).toString().trim();
        models.add(
          AiDiscoveredModel(
            displayName: displayName.isEmpty ? modelKey : displayName,
            modelKey: modelKey,
            capabilities: inferOllamaCapabilities(modelKey),
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
}
