import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/ai_task_runtime.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';

void main() {
  test(
    'AiTaskRuntime dispatches chat and embedding by route binding',
    () async {
      final adapter = _FakeAdapter();
      final runtime = AiTaskRuntime(
        registry: AiProviderRegistry(
          adapters: <AiProviderAdapterKind, AiProviderAdapter>{
            AiProviderAdapterKind.openAiCompatible: adapter,
          },
        ),
      );

      final settings = AiSettings.defaultsFor(AppLanguage.zhHans).copyWith(
        proxySettings: const AiProxySettings(
          protocol: AiProxyProtocol.http,
          host: 'proxy.example.com',
          port: 7890,
        ),
        services: const <AiServiceInstance>[_service],
        taskRouteBindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.analysisReport,
            serviceId: 'svc_main',
            modelId: 'mdl_chat',
            capability: AiCapability.chat,
          ),
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.embeddingRetrieval,
            serviceId: 'svc_main',
            modelId: 'mdl_embed',
            capability: AiCapability.embedding,
          ),
        ],
      );

      final chat = await runtime.chatCompletion(
        settings: settings,
        routeId: AiTaskRouteId.analysisReport,
        systemPrompt: '请温柔一点',
        messages: const <AiChatMessage>[
          AiChatMessage(role: 'user', content: '今天很想被理解'),
        ],
      );
      final vector = await runtime.embed(settings: settings, input: '今天很想被理解');

      expect(chat.text, 'chat-ok');
      expect(vector, <double>[0.5, 0.25]);
      expect(adapter.lastChatRequest, isNotNull);
      expect(adapter.lastEmbeddingRequest, isNotNull);
      expect(adapter.lastChatRequest!.service.serviceId, 'svc_main');
      expect(adapter.lastChatRequest!.model.modelId, 'mdl_chat');
      expect(adapter.lastChatRequest!.proxySettings?.host, 'proxy.example.com');
      expect(adapter.lastEmbeddingRequest!.model.modelId, 'mdl_embed');
      expect(adapter.lastEmbeddingRequest!.proxySettings?.port, 7890);
    },
  );
}

class _FakeAdapter implements AiProviderAdapter {
  AiChatCompletionRequest? lastChatRequest;
  AiEmbeddingRequest? lastEmbeddingRequest;

  @override
  Future<AiChatCompletionResult> chatCompletion(
    AiChatCompletionRequest request,
  ) async {
    lastChatRequest = request;
    return const AiChatCompletionResult(text: 'chat-ok', raw: null);
  }

  @override
  Future<List<double>> embed(AiEmbeddingRequest request) async {
    lastEmbeddingRequest = request;
    return const <double>[0.5, 0.25];
  }

  @override
  Future<List<AiDiscoveredModel>> listModels(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) async {
    return const <AiDiscoveredModel>[];
  }

  @override
  Future<AiServiceValidationResult> validateConfig(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }
  ) async {
    return const AiServiceValidationResult(status: AiValidationStatus.success);
  }
}

const AiServiceInstance _service = AiServiceInstance(
  serviceId: 'svc_main',
  templateId: aiTemplateOpenAi,
  adapterKind: AiProviderAdapterKind.openAiCompatible,
  displayName: 'Main Service',
  enabled: true,
  baseUrl: 'https://example.com/compatible-mode',
  apiKey: 'sk-test',
  customHeaders: <String, String>{},
  models: <AiModelEntry>[
    AiModelEntry(
      modelId: 'mdl_chat',
      displayName: 'Chat Model',
      modelKey: 'qwen-plus',
      capabilities: <AiCapability>[AiCapability.chat],
      source: AiModelSource.manual,
      enabled: true,
    ),
    AiModelEntry(
      modelId: 'mdl_embed',
      displayName: 'Embedding Model',
      modelKey: 'text-embedding-v4',
      capabilities: <AiCapability>[AiCapability.embedding],
      source: AiModelSource.manual,
      enabled: true,
    ),
  ],
  lastValidatedAt: null,
  lastValidationStatus: AiValidationStatus.unknown,
  lastValidationMessage: null,
);
