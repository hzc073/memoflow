import 'package:dio/dio.dart';

import '../ai_provider_adapter.dart';
import '../ai_provider_models.dart';
import '_ai_provider_http.dart';

class AzureOpenAiAiProviderAdapter implements AiProviderAdapter {
  const AzureOpenAiAiProviderAdapter();

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
    final endpoint = resolveEndpoint(baseUrl, 'openai/models');
    final queryParameters = <String, Object?>{
      'api-version': _apiVersion(service),
    };
    final headers = _requestHeaders(service);
    final dio = await buildAiProviderDio(
      service,
      proxySettings: proxySettings,
    );
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
    final endpoint = resolveEndpoint(
      normalizeBaseUrl(service.baseUrl),
      'openai/models',
    );
    logAiProviderRequestUnsupported(
      service,
      operation: 'list_models',
      method: 'GET',
      endpoint: endpoint,
      proxySettings: proxySettings,
      queryParameters: <String, Object?>{'api-version': _apiVersion(service)},
      requestHeaders: _requestHeaders(service),
      reason: 'Azure OpenAI model discovery is not available yet.',
    );
    throw UnsupportedError(
      'Azure OpenAI model discovery is not available yet.',
    );
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

  String _apiVersion(AiServiceInstance service) {
    final headerValue = service.customHeaders['api-version']?.trim();
    if (headerValue != null && headerValue.isNotEmpty) {
      return headerValue;
    }
    return '2024-10-21';
  }

  Map<String, String> _requestHeaders(AiServiceInstance service) {
    final headers = Map<String, String>.from(service.customHeaders)
      ..remove('api-version');
    final apiKey = service.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['api-key'] = apiKey;
    }
    return headers;
  }
}
