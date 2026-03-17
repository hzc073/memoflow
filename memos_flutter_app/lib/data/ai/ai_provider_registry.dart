import 'adapters/anthropic_ai_provider_adapter.dart';
import 'adapters/azure_openai_ai_provider_adapter.dart';
import 'adapters/gemini_ai_provider_adapter.dart';
import 'adapters/ollama_ai_provider_adapter.dart';
import 'adapters/openai_compatible_ai_provider_adapter.dart';
import 'ai_provider_adapter.dart';
import 'ai_provider_models.dart';

class AiProviderRegistry {
  AiProviderRegistry({Map<AiProviderAdapterKind, AiProviderAdapter>? adapters})
    : _adapters =
          adapters ?? const <AiProviderAdapterKind, AiProviderAdapter>{};

  factory AiProviderRegistry.defaults() {
    return AiProviderRegistry(
      adapters: <AiProviderAdapterKind, AiProviderAdapter>{
        AiProviderAdapterKind.openAiCompatible:
            const OpenAiCompatibleAiProviderAdapter(),
        AiProviderAdapterKind.anthropic: const AnthropicAiProviderAdapter(),
        AiProviderAdapterKind.gemini: const GeminiAiProviderAdapter(),
        AiProviderAdapterKind.azureOpenAi: const AzureOpenAiAiProviderAdapter(),
        AiProviderAdapterKind.ollama: const OllamaAiProviderAdapter(),
      },
    );
  }

  final Map<AiProviderAdapterKind, AiProviderAdapter> _adapters;

  AiProviderAdapter adapterFor(AiProviderAdapterKind adapterKind) {
    return _adapters[adapterKind] ?? _UnsupportedAiProviderAdapter(adapterKind);
  }
}

class _UnsupportedAiProviderAdapter implements AiProviderAdapter {
  const _UnsupportedAiProviderAdapter(this.adapterKind);

  final AiProviderAdapterKind adapterKind;

  @override
  Future<AiChatCompletionResult> chatCompletion(
    AiChatCompletionRequest request,
  ) {
    throw UnsupportedError('Adapter $adapterKind is not implemented yet.');
  }

  @override
  Future<List<double>> embed(AiEmbeddingRequest request) {
    throw UnsupportedError('Adapter $adapterKind is not implemented yet.');
  }

  @override
  Future<List<AiDiscoveredModel>> listModels(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) {
    throw UnsupportedError('Adapter $adapterKind is not implemented yet.');
  }

  @override
  Future<AiServiceValidationResult> validateConfig(
    AiServiceInstance service, {
    AiProxySettings? proxySettings,
  }) {
    throw UnsupportedError('Adapter $adapterKind is not implemented yet.');
  }
}
