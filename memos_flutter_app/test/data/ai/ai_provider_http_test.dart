import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/adapters/_ai_provider_http.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_models.dart';
import 'package:memos_flutter_app/data/ai/ai_provider_templates.dart';

void main() {
  final service = _service();

  test('short profile keeps validation and discovery requests snappy', () async {
    final dio = await buildAiProviderDio(
      service,
      profile: AiProviderRequestTimeoutProfile.short,
    );

    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 20));
    expect(dio.options.sendTimeout, const Duration(seconds: 20));
  });

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
}

AiServiceInstance _service() {
  return const AiServiceInstance(
    serviceId: 'svc_dashscope',
    templateId: aiTemplateOpenAi,
    adapterKind: AiProviderAdapterKind.openAiCompatible,
    displayName: 'DashScope',
    enabled: true,
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    apiKey: 'sk-test',
    customHeaders: <String, String>{},
    models: <AiModelEntry>[],
    lastValidatedAt: null,
    lastValidationStatus: AiValidationStatus.unknown,
    lastValidationMessage: null,
  );
}
