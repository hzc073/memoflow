import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/adapters/_ai_provider_http.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_models.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_templates.dart';

void main() {
  final service = _service();

  test(
    'short profile keeps validation and discovery requests snappy',
    () async {
      final dio = await buildAiProviderDio(
        service,
        profile: AiProviderRequestTimeoutProfile.short,
      );

      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 20));
      expect(dio.options.sendTimeout, const Duration(seconds: 20));
    },
  );

  test('embedding profile uses a moderate timeout', () async {
    final dio = await buildAiProviderDio(
      service,
      profile: AiProviderRequestTimeoutProfile.embedding,
    );

    expect(dio.options.receiveTimeout, const Duration(seconds: 45));
    expect(dio.options.sendTimeout, const Duration(seconds: 30));
  });

  test(
    'chat completion profile follows Cherry Studio style longer timeout',
    () async {
      final dio = await buildAiProviderDio(
        service,
        profile: AiProviderRequestTimeoutProfile.chatCompletion,
      );

      expect(dio.options.receiveTimeout, const Duration(seconds: 180));
      expect(dio.options.sendTimeout, const Duration(seconds: 60));
    },
  );

  test(
    'openai compatible base keeps configured path when version is missing',
    () {
      final baseUrl = normalizeOpenAiCompatibleApiBaseUrl(
        _service(
          baseUrl: 'https://api.openai.com',
          templateId: aiTemplateOpenAi,
        ),
      );

      expect(baseUrl, 'https://api.openai.com');
    },
  );

  test('openai compatible base keeps configured special paths', () {
    expect(
      normalizeOpenAiCompatibleApiBaseUrl(
        _service(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          templateId: aiTemplateZhipu,
        ),
      ),
      'https://open.bigmodel.cn/api/paas/v4',
    );
    expect(
      normalizeOpenAiCompatibleApiBaseUrl(
        _service(
          baseUrl: 'https://models.github.ai/inference',
          templateId: aiTemplateGitHubModels,
        ),
      ),
      'https://models.github.ai/inference',
    );
    expect(
      normalizeOpenAiCompatibleApiBaseUrl(
        _service(
          baseUrl: 'https://api.perplexity.ai',
          templateId: aiTemplatePerplexity,
        ),
      ),
      'https://api.perplexity.ai',
    );
  });

  test('openai compatible base does not change edited template paths', () {
    expect(
      normalizeOpenAiCompatibleApiBaseUrl(
        _service(baseUrl: 'https://example.com', templateId: aiTemplateZhipu),
      ),
      'https://example.com',
    );
    expect(
      normalizeOpenAiCompatibleApiBaseUrl(
        _service(
          baseUrl: 'https://example.com/openai',
          templateId: aiTemplateGitHubModels,
        ),
      ),
      'https://example.com/openai',
    );
    expect(
      normalizeOpenAiCompatibleApiBaseUrl(
        _service(
          baseUrl: 'https://example.com/api',
          templateId: aiTemplatePerplexity,
        ),
      ),
      'https://example.com/api',
    );
  });

  test(
    'openai compatible base preserves configured versioned and special paths',
    () {
      expect(
        normalizeOpenAiCompatibleApiBaseUrl(
          _service(
            baseUrl: 'https://api.ppinfra.com/v3/openai',
            templateId: aiTemplatePpio,
          ),
        ),
        'https://api.ppinfra.com/v3/openai',
      );
      expect(
        normalizeOpenAiCompatibleApiBaseUrl(
          _service(
            baseUrl: 'https://cephalon.cloud/user-center/v1/model',
            templateId: aiTemplateCephalon,
          ),
        ),
        'https://cephalon.cloud/user-center/v1/model',
      );
      expect(
        normalizeOpenAiCompatibleApiBaseUrl(
          _service(
            baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
            templateId: aiTemplateDoubao,
          ),
        ),
        'https://ark.cn-beijing.volces.com/api/v3',
      );
      expect(
        normalizeOpenAiCompatibleApiBaseUrl(
          _service(
            baseUrl: 'https://api.fireworks.ai/inference',
            templateId: aiTemplateFireworks,
          ),
        ),
        'https://api.fireworks.ai/inference',
      );
    },
  );

  test('anthropic base defaults to /v1 once', () {
    expect(
      normalizeAnthropicApiBaseUrl('https://api.anthropic.com'),
      'https://api.anthropic.com/v1',
    );
    expect(
      normalizeAnthropicApiBaseUrl('https://api.anthropic.com/v1'),
      'https://api.anthropic.com/v1',
    );
  });

  test('gemini base defaults to /v1beta and keeps existing versions', () {
    expect(
      normalizeGeminiApiBaseUrl('https://generativelanguage.googleapis.com'),
      'https://generativelanguage.googleapis.com/v1beta',
    );
    expect(
      normalizeGeminiApiBaseUrl(
        'https://generativelanguage.googleapis.com/v1beta',
      ),
      'https://generativelanguage.googleapis.com/v1beta',
    );
    expect(
      normalizeGeminiApiBaseUrl(
        'https://generativelanguage.googleapis.com/v1alpha',
      ),
      'https://generativelanguage.googleapis.com/v1alpha',
    );
  });

  test('azure openai base normalizes to /openai', () {
    expect(
      normalizeAzureOpenAiApiBaseUrl('https://example.openai.azure.com'),
      'https://example.openai.azure.com/openai',
    );
    expect(
      normalizeAzureOpenAiApiBaseUrl('https://example.openai.azure.com/openai'),
      'https://example.openai.azure.com/openai',
    );
    expect(
      normalizeAzureOpenAiApiBaseUrl(
        'https://example.openai.azure.com/openai/v1',
      ),
      'https://example.openai.azure.com/openai',
    );
  });

  test('ollama base normalizes to /api', () {
    expect(
      normalizeOllamaApiBaseUrl('http://localhost:11434'),
      'http://localhost:11434/api',
    );
    expect(
      normalizeOllamaApiBaseUrl('http://localhost:11434/api'),
      'http://localhost:11434/api',
    );
    expect(
      normalizeOllamaApiBaseUrl('http://localhost:11434/chat'),
      'http://localhost:11434/api',
    );
  });
}

AiServiceInstance _service({
  String baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  String templateId = aiTemplateOpenAi,
}) {
  return AiServiceInstance(
    serviceId: 'svc_dashscope',
    templateId: templateId,
    adapterKind: AiProviderAdapterKind.openAiCompatible,
    displayName: 'DashScope',
    enabled: true,
    baseUrl: baseUrl,
    apiKey: 'sk-test',
    customHeaders: <String, String>{},
    models: <AiModelEntry>[],
    lastValidatedAt: null,
    lastValidationStatus: AiValidationStatus.unknown,
    lastValidationMessage: null,
  );
}
