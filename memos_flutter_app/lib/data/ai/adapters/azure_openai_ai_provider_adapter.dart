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
  }) async {
    final baseUrl = normalizeAzureOpenAiApiBaseUrl(service.baseUrl);
    if (baseUrl.isEmpty) {
      return const AiServiceValidationResult(
        status: AiValidationStatus.failed,
        message: 'Base URL is required.',
      );
    }
    final endpoint = resolveEndpoint(baseUrl, 'models');
    final queryParameters = <String, Object?>{
      'api-version': _apiVersion(service),
    };
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
    final endpoint = resolveEndpoint(
      normalizeAzureOpenAiApiBaseUrl(service.baseUrl),
      'models',
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
  ) async {
    final baseUrl = normalizeAzureOpenAiApiBaseUrl(request.service.baseUrl);
    if (baseUrl.isEmpty) {
      throw StateError('Base URL is required.');
    }
    final endpoint = resolveEndpoint(baseUrl, 'chat/completions');
    final queryParameters = <String, Object?>{
      'api-version': _apiVersion(request.service),
    };
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
      queryParameters: queryParameters,
      requestHeaders: headers,
    );
    var failureLogged = false;
    try {
      final response = await dio.post<Object?>(
        endpoint,
        queryParameters: queryParameters,
        options: Options(headers: headers),
        data: <String, Object?>{
          'model': request.model.modelKey,
          'stream': false,
          if (request.temperature != null) 'temperature': request.temperature,
          if (request.maxOutputTokens != null)
            'max_tokens': request.maxOutputTokens,
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
          queryParameters: queryParameters,
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
          queryParameters: queryParameters,
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
        queryParameters: queryParameters,
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
  Future<List<double>> embed(AiEmbeddingRequest request) async {
    final baseUrl = normalizeAzureOpenAiApiBaseUrl(request.service.baseUrl);
    if (baseUrl.isEmpty) {
      throw StateError('Base URL is required.');
    }
    final input = request.input.trim();
    if (input.isEmpty) {
      throw StateError('Embedding input is required.');
    }
    final endpoint = resolveEndpoint(baseUrl, 'embeddings');
    final queryParameters = <String, Object?>{
      'api-version': _apiVersion(request.service),
    };
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
      queryParameters: queryParameters,
      requestHeaders: headers,
    );
    var failureLogged = false;
    try {
      final response = await dio.post<Object?>(
        endpoint,
        queryParameters: queryParameters,
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
          queryParameters: queryParameters,
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
          queryParameters: queryParameters,
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
        queryParameters: queryParameters,
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

  String _extractChatCompletionText(Object? data) {
    if (data is! Map || data['choices'] is! List) {
      return '';
    }
    final choices = data['choices'] as List;
    if (choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is Map) {
      final fromMessage = _readContentValue(message['content']);
      if (fromMessage.isNotEmpty) return fromMessage;
    }
    return _readContentValue(first['text']);
  }

  String _readContentValue(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value is List) {
      final buffer = StringBuffer();
      for (final item in value) {
        if (item is String) {
          buffer.write(item);
          continue;
        }
        if (item is Map) {
          final text = item['text'];
          if (text is String && text.trim().isNotEmpty) {
            buffer.write(text);
          }
        }
      }
      return buffer.toString().trim();
    }
    return '';
  }

  List<double> _extractEmbedding(Object? data) {
    if (data is! Map || data['data'] is! List) {
      return const <double>[];
    }
    final items = data['data'] as List;
    if (items.isEmpty) return const <double>[];
    final first = items.first;
    if (first is! Map || first['embedding'] is! List) {
      return const <double>[];
    }
    return (first['embedding'] as List)
        .whereType<num>()
        .map((item) => item.toDouble())
        .toList(growable: false);
  }
}
