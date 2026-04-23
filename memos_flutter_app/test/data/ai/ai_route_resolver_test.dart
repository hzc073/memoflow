import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/ai_route_config.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';

void main() {
  test(
    'AiRouteResolver falls back to another enabled model in same service',
    () {
      const service = AiServiceInstance(
        serviceId: 'svc_main',
        templateId: aiTemplateOpenAi,
        adapterKind: AiProviderAdapterKind.openAiCompatible,
        displayName: 'OpenAI Main',
        enabled: true,
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        customHeaders: <String, String>{},
        models: <AiModelEntry>[
          AiModelEntry(
            modelId: 'mdl_disabled',
            displayName: 'gpt-disabled',
            modelKey: 'gpt-disabled',
            capabilities: <AiCapability>[AiCapability.chat],
            source: AiModelSource.manual,
            enabled: false,
          ),
          AiModelEntry(
            modelId: 'mdl_ready',
            displayName: 'gpt-ready',
            modelKey: 'gpt-ready',
            capabilities: <AiCapability>[AiCapability.chat],
            source: AiModelSource.manual,
            enabled: true,
          ),
        ],
        lastValidatedAt: null,
        lastValidationStatus: AiValidationStatus.unknown,
        lastValidationMessage: null,
      );

      final resolved = AiRouteResolver.resolveTaskRoute(
        services: const <AiServiceInstance>[service],
        bindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.summary,
            serviceId: 'svc_main',
            modelId: 'mdl_disabled',
            capability: AiCapability.chat,
          ),
        ],
        routeId: AiTaskRouteId.summary,
        capability: AiCapability.chat,
      );

      expect(resolved, isNotNull);
      expect(resolved!.service.serviceId, 'svc_main');
      expect(resolved.model.modelId, 'mdl_ready');
      expect(resolved.source, AiRouteResolutionSource.serviceFallback);
    },
  );

  test(
    'AiRouteResolver falls back globally when bound service is unusable',
    () {
      const disabledService = AiServiceInstance(
        serviceId: 'svc_disabled',
        templateId: aiTemplateOpenAi,
        adapterKind: AiProviderAdapterKind.openAiCompatible,
        displayName: 'Disabled',
        enabled: false,
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        customHeaders: <String, String>{},
        models: <AiModelEntry>[
          AiModelEntry(
            modelId: 'mdl_disabled',
            displayName: 'gpt-disabled',
            modelKey: 'gpt-disabled',
            capabilities: <AiCapability>[AiCapability.chat],
            source: AiModelSource.manual,
            enabled: true,
          ),
        ],
        lastValidatedAt: null,
        lastValidationStatus: AiValidationStatus.unknown,
        lastValidationMessage: null,
      );
      const fallbackService = AiServiceInstance(
        serviceId: 'svc_fallback',
        templateId: aiTemplateOpenAi,
        adapterKind: AiProviderAdapterKind.openAiCompatible,
        displayName: 'Fallback',
        enabled: true,
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        customHeaders: <String, String>{},
        models: <AiModelEntry>[
          AiModelEntry(
            modelId: 'mdl_fallback',
            displayName: 'gpt-fallback',
            modelKey: 'gpt-fallback',
            capabilities: <AiCapability>[AiCapability.chat],
            source: AiModelSource.manual,
            enabled: true,
          ),
        ],
        lastValidatedAt: null,
        lastValidationStatus: AiValidationStatus.unknown,
        lastValidationMessage: null,
      );

      final resolved = AiRouteResolver.resolveTaskRoute(
        services: const <AiServiceInstance>[disabledService, fallbackService],
        bindings: const <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.summary,
            serviceId: 'svc_disabled',
            modelId: 'mdl_disabled',
            capability: AiCapability.chat,
          ),
        ],
        routeId: AiTaskRouteId.summary,
        capability: AiCapability.chat,
      );

      expect(resolved, isNotNull);
      expect(resolved!.service.serviceId, 'svc_fallback');
      expect(resolved.model.modelId, 'mdl_fallback');
      expect(resolved.source, AiRouteResolutionSource.globalFallback);
    },
  );

  test('hasConfiguredChatRoute accepts local providers without API keys', () {
    const localService = AiServiceInstance(
      serviceId: 'svc_local',
      templateId: aiTemplateOllama,
      adapterKind: AiProviderAdapterKind.ollama,
      displayName: 'Local Ollama',
      enabled: true,
      baseUrl: 'http://127.0.0.1:11434',
      apiKey: '',
      customHeaders: <String, String>{},
      models: <AiModelEntry>[
        AiModelEntry(
          modelId: 'mdl_chat',
          displayName: 'llama3.1',
          modelKey: 'llama3.1',
          capabilities: <AiCapability>[AiCapability.chat],
          source: AiModelSource.manual,
          enabled: true,
        ),
      ],
      lastValidatedAt: null,
      lastValidationStatus: AiValidationStatus.unknown,
      lastValidationMessage: null,
    );

    final settings = AiSettings.defaultsFor(AppLanguage.en).copyWith(
      services: const <AiServiceInstance>[localService],
      taskRouteBindings: const <AiTaskRouteBinding>[
        AiTaskRouteBinding(
          routeId: AiTaskRouteId.analysisReport,
          serviceId: 'svc_local',
          modelId: 'mdl_chat',
          capability: AiCapability.chat,
        ),
      ],
    );

    expect(
      hasConfiguredChatRoute(settings, routeId: AiTaskRouteId.analysisReport),
      isTrue,
    );
  });

  test(
    'selectableRouteOptionsForCapability skips disabled services and models',
    () {
      const settings = AiSettings(
        schemaVersion: AiSettings.currentSchemaVersion,
        services: <AiServiceInstance>[
          AiServiceInstance(
            serviceId: 'svc_disabled',
            templateId: aiTemplateOpenAi,
            adapterKind: AiProviderAdapterKind.openAiCompatible,
            displayName: 'Disabled Service',
            enabled: false,
            baseUrl: 'https://api.openai.com',
            apiKey: 'sk-test',
            customHeaders: <String, String>{},
            models: <AiModelEntry>[
              AiModelEntry(
                modelId: 'mdl_disabled_service',
                displayName: 'gpt-disabled-service',
                modelKey: 'gpt-disabled-service',
                capabilities: <AiCapability>[AiCapability.chat],
                source: AiModelSource.manual,
                enabled: true,
              ),
            ],
            lastValidatedAt: null,
            lastValidationStatus: AiValidationStatus.unknown,
            lastValidationMessage: null,
          ),
          AiServiceInstance(
            serviceId: 'svc_main',
            templateId: aiTemplateOpenAi,
            adapterKind: AiProviderAdapterKind.openAiCompatible,
            displayName: 'Enabled Service',
            enabled: true,
            baseUrl: 'https://api.openai.com',
            apiKey: 'sk-test',
            customHeaders: <String, String>{},
            models: <AiModelEntry>[
              AiModelEntry(
                modelId: 'mdl_disabled_model',
                displayName: 'gpt-disabled-model',
                modelKey: 'gpt-disabled-model',
                capabilities: <AiCapability>[AiCapability.chat],
                source: AiModelSource.manual,
                enabled: false,
              ),
              AiModelEntry(
                modelId: 'mdl_ready',
                displayName: 'gpt-ready',
                modelKey: 'gpt-ready',
                capabilities: <AiCapability>[AiCapability.chat],
                source: AiModelSource.manual,
                enabled: true,
              ),
            ],
            lastValidatedAt: null,
            lastValidationStatus: AiValidationStatus.unknown,
            lastValidationMessage: null,
          ),
        ],
        taskRouteBindings: <AiTaskRouteBinding>[],
        generationProfiles: <AiGenerationProfile>[],
        selectedGenerationProfileKey: '',
        embeddingProfiles: <AiEmbeddingProfile>[],
        selectedEmbeddingProfileKey: null,
        prompt: '',
        userProfile: '',
        quickPrompts: <AiQuickPrompt>[],
        analysisPromptTemplates: <String, String>{},
        customInsightTemplates: <AiCustomInsightTemplate>[],
      );

      final options = selectableRouteOptionsForCapability(
        settings,
        capability: AiCapability.chat,
      );

      expect(options, hasLength(1));
      expect(options.single.service.serviceId, 'svc_main');
      expect(options.single.model.modelId, 'mdl_ready');
    },
  );
}
