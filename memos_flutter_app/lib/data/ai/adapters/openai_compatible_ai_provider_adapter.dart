import 'package:dio/dio.dart';

import '../ai_provider_adapter.dart';
import '../ai_provider_models.dart';
import '../ai_provider_templates.dart';
import '_ai_provider_http.dart';

class OpenAiCompatibleAiProviderAdapter implements AiProviderAdapter {
  const OpenAiCompatibleAiProviderAdapter();

  @override
  Future<AiServiceValidationResult> validateConfig(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) async {
    final baseUrl = _apiBaseUrl(service);
    if (baseUrl.isEmpty) {
      return const AiServiceValidationResult(
        status: AiValidationStatus.failed,
        message: 'Base URL is required.',
      );
    }

    final endpoint = _modelsEndpoint(service);
    final headers = _requestHeaders(service);
    final dio = await buildAiProviderDio(
      service,
      proxySettings: proxySettings,
      profile: AiProviderRequestTimeoutProfile.short,
    );
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
    final baseUrl = _apiBaseUrl(service);
    if (baseUrl.isEmpty) return const <AiDiscoveredModel>[];
    final endpoint = _modelsEndpoint(service);
    final headers = _requestHeaders(service);
    final dio = await buildAiProviderDio(
      service,
      proxySettings: proxySettings,
      profile: AiProviderRequestTimeoutProfile.short,
    );
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
      final models = _extractDiscoveredModels(service, response.data);
      if (models.isEmpty) {
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
    final baseUrl = _apiBaseUrl(request.service);
    if (baseUrl.isEmpty) {
      throw StateError('Base URL is required.');
    }
    final endpoint = resolveEndpoint(baseUrl, 'chat/completions');
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
      final response = await dio.post<Object?>(
        endpoint,
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
    final baseUrl = _apiBaseUrl(request.service);
    if (baseUrl.isEmpty) {
      throw StateError('Base URL is required.');
    }
    final input = request.input.trim();
    if (input.isEmpty) {
      throw StateError('Embedding input is required.');
    }
    final endpoint = resolveEndpoint(baseUrl, 'embeddings');
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

  String _apiBaseUrl(AiServiceInstance service) {
    return normalizeOpenAiCompatibleApiBaseUrl(service);
  }

  String _modelsEndpoint(AiServiceInstance service) {
    final baseUrl = _apiBaseUrl(service);
    if (baseUrl.isEmpty) return '';
    if (_usesGitHubCatalogModelDiscovery(service, baseUrl)) {
      return _githubCatalogModelsEndpoint(baseUrl);
    }
    return resolveEndpoint(baseUrl, 'models');
  }

  bool _usesGitHubCatalogModelDiscovery(
    AiServiceInstance service,
    String baseUrl,
  ) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) {
      return false;
    }
    final normalizedPath = uri.path
        .replaceAll(RegExp(r'/+$'), '')
        .toLowerCase();
    final isOfficialHost = uri.host.toLowerCase() == 'models.github.ai';
    return isOfficialHost ||
        (service.templateId == aiTemplateGitHubModels &&
            normalizedPath.endsWith('/inference'));
  }

  String _githubCatalogModelsEndpoint(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) {
      return resolveEndpoint(baseUrl, 'models');
    }
    final normalizedPath = uri.path.replaceAll(RegExp(r'/+$'), '');
    final catalogPath = normalizedPath.toLowerCase().endsWith('/inference')
        ? normalizedPath.replaceFirst(
            RegExp(r'/inference$', caseSensitive: false),
            '/catalog',
          )
        : normalizedPath.isEmpty
        ? '/catalog'
        : '$normalizedPath/catalog';
    return uri.replace(path: '$catalogPath/models').toString();
  }

  List<AiDiscoveredModel> _extractDiscoveredModels(
    AiServiceInstance service,
    Object? data,
  ) {
    if (_usesGitHubCatalogResponse(service, data)) {
      return _extractGitHubCatalogModels(data as List);
    }
    if (data is! Map || data['data'] is! List) {
      return const <AiDiscoveredModel>[];
    }
    final models = <AiDiscoveredModel>[];
    for (final item in (data['data'] as List)) {
      if (item is! Map) continue;
      final modelKey = (item['id'] ?? '').toString().trim();
      if (modelKey.isEmpty) continue;
      final displayName = ((item['name'] ?? item['id']) ?? '')
          .toString()
          .trim();
      final ownedBy =
          ((item['owned_by'] ?? item['ownedBy'] ?? item['provider']) ?? '')
              .toString()
              .trim();
      models.add(
        AiDiscoveredModel(
          displayName: displayName.isEmpty ? modelKey : displayName,
          modelKey: modelKey,
          capabilities: inferOpenAiCompatibleCapabilities(modelKey),
          ownedBy: ownedBy.isEmpty ? null : ownedBy,
        ),
      );
    }
    return models;
  }

  bool _usesGitHubCatalogResponse(AiServiceInstance service, Object? data) {
    return service.templateId == aiTemplateGitHubModels && data is List;
  }

  List<AiDiscoveredModel> _extractGitHubCatalogModels(List data) {
    final models = <AiDiscoveredModel>[];
    for (final item in data) {
      if (item is! Map) continue;
      final modelKey = (item['id'] ?? '').toString().trim();
      if (modelKey.isEmpty) continue;
      final displayName = ((item['name'] ?? item['id']) ?? '')
          .toString()
          .trim();
      final ownedBy = ((item['publisher'] ?? item['owned_by']) ?? '')
          .toString()
          .trim();
      models.add(
        AiDiscoveredModel(
          displayName: displayName.isEmpty ? modelKey : displayName,
          modelKey: modelKey,
          capabilities: inferOpenAiCompatibleCapabilities(modelKey),
          ownedBy: ownedBy.isEmpty ? null : ownedBy,
        ),
      );
    }
    return models;
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
