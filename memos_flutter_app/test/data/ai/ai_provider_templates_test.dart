import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_templates.dart';

void main() {
  test('OpenAI template exposes built-in chat and embedding presets', () {
    final template = findAiProviderTemplate(aiTemplateOpenAi);
    expect(template, isNotNull);

    final presets = builtinModelPresetsForTemplate(template!);
    expect(presets.any((preset) => preset.modelKey == 'gpt-5.1'), isTrue);
    expect(
      presets.any((preset) => preset.modelKey == 'text-embedding-3-small'),
      isTrue,
    );
  });

  test('Custom Anthropic template inherits Anthropic built-in presets', () {
    final template = findAiProviderTemplate(aiTemplateCustomAnthropic);
    expect(template, isNotNull);

    final presets = builtinModelPresetsForTemplate(template!);
    expect(
      presets.any((preset) => preset.modelKey == 'claude-sonnet-4-5'),
      isTrue,
    );
  });

  test('Local templates keep presets empty by default', () {
    final ollama = findAiProviderTemplate(aiTemplateOllama);
    final lmStudio = findAiProviderTemplate(aiTemplateLmStudio);

    expect(ollama, isNotNull);
    expect(lmStudio, isNotNull);
    expect(builtinModelPresetsForTemplate(ollama!), isEmpty);
    expect(builtinModelPresetsForTemplate(lmStudio!), isEmpty);
  });

  test('default base urls match Cherry Studio style configured prefixes', () {
    final expectedBaseUrls = <String, String>{
      aiTemplateOpenAi: 'https://api.openai.com',
      aiTemplateAnthropic: 'https://api.anthropic.com/v1',
      aiTemplateGemini: 'https://generativelanguage.googleapis.com/v1beta',
      aiTemplateZhipu: 'https://open.bigmodel.cn/api/paas/v4',
      aiTemplateGitHubModels: 'https://models.github.ai/inference',
      aiTemplatePerplexity: 'https://api.perplexity.ai',
      aiTemplateOllama: 'http://localhost:11434',
      aiTemplateLmStudio: 'http://localhost:1234',
      aiTemplateNewApi: 'http://localhost:3000',
      aiTemplateOpenVinoModelServer: 'http://localhost:8000/v3',
      aiTemplatePpio: 'https://api.ppinfra.com/v3/openai',
      aiTemplateCephalon: 'https://cephalon.cloud/user-center/v1/model',
      aiTemplateDoubao: 'https://ark.cn-beijing.volces.com/api/v3',
      aiTemplateBaiduCloud: 'https://qianfan.baidubce.com/v2',
      aiTemplateGroq: 'https://api.groq.com/openai',
      aiTemplateFireworks: 'https://api.fireworks.ai/inference',
      aiTemplateLongCat: 'https://api.longcat.chat/openai',
      aiTemplateTencentCloudTi: 'https://api.lkeap.cloud.tencent.com',
      aiTemplateVoyageAi: 'https://api.voyageai.com',
      aiTemplateDeepSeek: 'https://api.deepseek.com',
      aiTemplateTogether: 'https://api.together.xyz',
      aiTemplateGrok: 'https://api.x.ai',
    };

    for (final entry in expectedBaseUrls.entries) {
      final template = findAiProviderTemplate(entry.key);
      expect(template, isNotNull, reason: entry.key);
      expect(template!.defaultBaseUrl, entry.value, reason: entry.key);
    }
  });
}
