import 'ai_provider_adapter.dart';
import 'ai_provider_models.dart';
import 'ai_provider_registry.dart';
import 'ai_route_resolver.dart';

class AiTaskRuntime {
  const AiTaskRuntime({required AiProviderRegistry registry})
    : _registry = registry;

  final AiProviderRegistry _registry;

  AiResolvedTaskRoute? resolveChatRoute(
    AiSettings settings, {
    required AiTaskRouteId routeId,
  }) {
    return AiRouteResolver.resolveTaskRoute(
      services: settings.services,
      bindings: settings.taskRouteBindings,
      routeId: routeId,
      capability: AiCapability.chat,
    );
  }

  AiResolvedTaskRoute? resolveEmbeddingRoute(AiSettings settings) {
    return AiRouteResolver.resolveTaskRoute(
      services: settings.services,
      bindings: settings.taskRouteBindings,
      routeId: AiTaskRouteId.embeddingRetrieval,
      capability: AiCapability.embedding,
    );
  }

  Future<AiChatCompletionResult> chatCompletion({
    required AiSettings settings,
    required AiTaskRouteId routeId,
    required List<AiChatMessage> messages,
    String? systemPrompt,
    double? temperature,
    int? maxOutputTokens,
  }) async {
    final route = resolveChatRoute(settings, routeId: routeId);
    if (route == null) {
      throw StateError('No chat route configured for ${routeId.name}.');
    }
    final adapter = _registry.adapterFor(route.service.adapterKind);
    return adapter.chatCompletion(
      AiChatCompletionRequest(
        service: route.service,
        model: route.model,
        messages: messages,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
        proxySettings: settings.proxySettings,
      ),
    );
  }

  Future<List<double>> embed({
    required AiSettings settings,
    required String input,
  }) async {
    final route = resolveEmbeddingRoute(settings);
    if (route == null) {
      throw StateError('No embedding route configured.');
    }
    final adapter = _registry.adapterFor(route.service.adapterKind);
    return adapter.embed(
      AiEmbeddingRequest(
        service: route.service,
        model: route.model,
        input: input,
        proxySettings: settings.proxySettings,
      ),
    );
  }

  AiGenerationProfile? resolveGenerationProfile(
    AiSettings settings, {
    required AiTaskRouteId routeId,
  }) {
    final route = resolveChatRoute(settings, routeId: routeId);
    if (route == null) return null;
    return AiGenerationProfile(
      profileKey:
          'route_${route.routeId.name}_${route.service.serviceId}_${route.model.modelId}',
      displayName: _displayName(route),
      backendKind: AiBackendKind.remoteApi,
      providerKind: _providerKindFromAdapter(route.service.adapterKind),
      baseUrl: route.service.baseUrl,
      apiKey: route.service.apiKey,
      model: route.model.modelKey,
      modelOptions: <String>[route.model.modelKey],
      enabled: route.service.enabled && route.model.enabled,
    );
  }

  AiEmbeddingProfile? resolveEmbeddingProfile(AiSettings settings) {
    final route = resolveEmbeddingRoute(settings);
    if (route == null) return null;
    return AiEmbeddingProfile(
      profileKey:
          'route_${route.routeId.name}_${route.service.serviceId}_${route.model.modelId}',
      displayName: _displayName(route),
      backendKind: AiBackendKind.remoteApi,
      providerKind: _providerKindFromAdapter(route.service.adapterKind),
      baseUrl: route.service.baseUrl,
      apiKey: route.service.apiKey,
      model: route.model.modelKey,
      enabled: route.service.enabled && route.model.enabled,
    );
  }

  String _displayName(AiResolvedTaskRoute route) {
    final modelName = route.model.displayName.trim().isEmpty
        ? route.model.modelKey.trim()
        : route.model.displayName.trim();
    return '${route.service.displayName} · $modelName';
  }

  AiProviderKind _providerKindFromAdapter(AiProviderAdapterKind adapterKind) {
    return switch (adapterKind) {
      AiProviderAdapterKind.anthropic => AiProviderKind.anthropicCompatible,
      _ => AiProviderKind.openAiCompatible,
    };
  }
}
