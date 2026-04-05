import 'package:dio/dio.dart';

import '../ai_provider_adapter.dart';
import '../ai_provider_models.dart';
import '_ai_provider_http.dart';

class OllamaAiProviderAdapter implements AiProviderAdapter {
  const OllamaAiProviderAdapter();

  @override
  Future<AiServiceValidationResult> validateConfig(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) async {
    final baseUrl = normalizeOllamaApiBaseUrl(service.baseUrl);
    if (baseUrl.isEmpty) {
      return const AiServiceValidationResult(
        status: AiValidationStatus.failed,
        message: 'Base URL is required.',
      );
    }
    final endpoint = resolveEndpoint(baseUrl, 'tags');
    final headers = _requestHeaders(service);
    final dio = await buildAiProviderDio(service, proxySettings: proxySettings);
    final stopwatch = logAiProviderRequestStarted(
      service,
      operation: 'validate_config',
      method: 'GET',
      endpoint: endpoint,
      proxySettings: proxySettings,
      requestHeaders: headers,
    );
    try {
      final response = await dio.get<Object?>(
        endpoint,
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
    final baseUrl = normalizeOllamaApiBaseUrl(service.baseUrl);
    if (baseUrl.isEmpty) return const <AiDiscoveredModel>[];
    final endpoint = resolveEndpoint(baseUrl, 'tags');
    final headers = _requestHeaders(service);
    final dio = await buildAiProviderDio(service, proxySettings: proxySettings);
    final stopwatch = logAiProviderRequestStarted(
      service,
      operation: 'list_models',
      method: 'GET',
      endpoint: endpoint,
      proxySettings: proxySettings,
      requestHeaders: headers,
    );
    var failureLogged = false;
    try {
      final response = await dio.get<Object?>(
        endpoint,
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
  ) async {
    final baseUrl = normalizeOllamaApiBaseUrl(request.service.baseUrl);
    if (baseUrl.isEmpty) {
      throw StateError('Base URL is required.');
    }
    final endpoint = resolveEndpoint(baseUrl, 'chat');
    final headers = <String, String>{
      ..._requestHeaders(request.service),
      'Content-Type': 'application/json',
    };
    final dio = await buildAiProviderDio(
      request.service,
      proxySettings: request.proxySettings,
      profile: AiProviderRequestTimeoutProfile.chatCompletion,
    );
    final stopwatch = logAiProviderRequestStarted(
      request.service,
      operation: 'chat_completion',
      method: 'POST',
      endpoint: endpoint,
      proxySettings: request.proxySettings,
      requestHeaders: headers,
    );
    var failureLogged = false;
    try {
      final options = <String, Object?>{};
      if (request.temperature != null) {
        options['temperature'] = request.temperature;
      }
      if (request.maxOutputTokens != null) {
        options['num_predict'] = request.maxOutputTokens;
      }
      final response = await dio.post<Object?>(
        endpoint,
        options: Options(headers: headers),
        data: <String, Object?>{
          'model': request.model.modelKey,
          'stream': false,
          'messages': <Map<String, Object?>>[
            if ((request.systemPrompt ?? '').trim().isNotEmpty)
              <String, Object?>{
                'role': 'system',
                'content': request.systemPrompt!.trim(),
              },
            ...request.messages.map(
              (message) => <String, Object?>{
                'role': message.role.trim(),
                'content': message.content,
              },
            ),
          ],
          if (options.isNotEmpty) 'options': options,
        },
      );
      final statusCode = response.statusCode;
      if ((statusCode ?? 0) < 200 || (statusCode ?? 0) >= 300) {
        final message = errorMessageFromResponse(response.data);
        failureLogged = true;
        logAiProviderRequestFailed(
          request.service,
          stopwatch,
          operation: 'chat_completion',
          method: 'POST',
          endpoint: endpoint,
          proxySettings: request.proxySettings,
          requestHeaders: headers,
          statusCode: statusCode,
          responseMessage: message,
        );
        throw StateError(message);
      }
      final text = _extractChatCompletionText(response.data);
      if (text.isEmpty) {
        final message = 'Chat completion returned empty content.';
        failureLogged = true;
        logAiProviderRequestFailed(
          request.service,
          stopwatch,
          operation: 'chat_completion',
          method: 'POST',
          endpoint: endpoint,
          proxySettings: request.proxySettings,
          requestHeaders: headers,
          statusCode: statusCode,
          responseMessage: message,
        );
        throw StateError(message);
      }
      logAiProviderRequestFinished(
        request.service,
        stopwatch,
        operation: 'chat_completion',
        method: 'POST',
        endpoint: endpoint,
        proxySettings: request.proxySettings,
        requestHeaders: headers,
        statusCode: statusCode,
      );
      return AiChatCompletionResult(text: text, raw: response.data);
    } catch (error, stackTrace) {
      if (!failureLogged) {
        logAiProviderRequestFailed(
          request.service,
          stopwatch,
          operation: 'chat_completion',
          method: 'POST',
          endpoint: endpoint,
          proxySettings: request.proxySettings,
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
  Future<List<double>> embed(AiEmbeddingRequest request) async {
    final baseUrl = normalizeOllamaApiBaseUrl(request.service.baseUrl);
    if (baseUrl.isEmpty) {
      throw StateError('Base URL is required.');
    }
    final input = request.input.trim();
    if (input.isEmpty) {
      throw StateError('Embedding input is required.');
    }
    final endpoint = resolveEndpoint(baseUrl, 'embed');
    final headers = <String, String>{
      ..._requestHeaders(request.service),
      'Content-Type': 'application/json',
    };
    final dio = await buildAiProviderDio(
      request.service,
      proxySettings: request.proxySettings,
      profile: AiProviderRequestTimeoutProfile.embedding,
    );
    final stopwatch = logAiProviderRequestStarted(
      request.service,
      operation: 'embed',
      method: 'POST',
      endpoint: endpoint,
      proxySettings: request.proxySettings,
      requestHeaders: headers,
    );
    var failureLogged = false;
    try {
      final response = await dio.post<Object?>(
        endpoint,
        options: Options(headers: headers),
        data: <String, Object?>{
          'model': request.model.modelKey,
          'input': input,
        },
      );
      final statusCode = response.statusCode;
      if ((statusCode ?? 0) < 200 || (statusCode ?? 0) >= 300) {
        final message = errorMessageFromResponse(response.data);
        failureLogged = true;
        logAiProviderRequestFailed(
          request.service,
          stopwatch,
          operation: 'embed',
          method: 'POST',
          endpoint: endpoint,
          proxySettings: request.proxySettings,
          requestHeaders: headers,
          statusCode: statusCode,
          responseMessage: message,
        );
        throw StateError(message);
      }

      final vector = _extractEmbedding(response.data);
      if (vector.isEmpty) {
        final message = 'Embedding API returned empty vector.';
        failureLogged = true;
        logAiProviderRequestFailed(
          request.service,
          stopwatch,
          operation: 'embed',
          method: 'POST',
          endpoint: endpoint,
          proxySettings: request.proxySettings,
          requestHeaders: headers,
          statusCode: statusCode,
          responseMessage: message,
        );
        throw StateError(message);
      }
      logAiProviderRequestFinished(
        request.service,
        stopwatch,
        operation: 'embed',
        method: 'POST',
        endpoint: endpoint,
        proxySettings: request.proxySettings,
        requestHeaders: headers,
        statusCode: statusCode,
      );
      return vector;
    } catch (error, stackTrace) {
      if (!failureLogged) {
        logAiProviderRequestFailed(
          request.service,
          stopwatch,
          operation: 'embed',
          method: 'POST',
          endpoint: endpoint,
          proxySettings: request.proxySettings,
          requestHeaders: headers,
          error: error,
          stackTrace: stackTrace,
          responseMessage: extractErrorMessage(error),
        );
      }
      rethrow;
    }
  }

  Map<String, String> _requestHeaders(AiServiceInstance service) {
    final headers = Map<String, String>.from(service.customHeaders);
    final apiKey = service.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  String _extractChatCompletionText(Object? data) {
    if (data is! Map) return '';
    final message = data['message'];
    if (message is Map) {
      final content = message['content'];
      if (content is String) {
        return content.trim();
      }
    }
    final direct = data['response'];
    if (direct is String) {
      return direct.trim();
    }
    return '';
  }

  List<double> _extractEmbedding(Object? data) {
    if (data is! Map) return const <double>[];
    final embeddings = data['embeddings'];
    if (embeddings is List && embeddings.isNotEmpty) {
      final first = embeddings.first;
      if (first is List) {
        return first
            .whereType<num>()
            .map((item) => item.toDouble())
            .toList(growable: false);
      }
      return embeddings
          .whereType<num>()
          .map((item) => item.toDouble())
          .toList(growable: false);
    }
    final embedding = data['embedding'];
    if (embedding is List) {
      return embedding
          .whereType<num>()
          .map((item) => item.toDouble())
          .toList(growable: false);
    }
    return const <double>[];
  }
}
