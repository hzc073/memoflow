import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/adapters/openai_compatible_ai_provider_adapter.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';

void main() {
  late HttpServer server;
  late String baseUrl;
  late String zhipuBaseUrl;
  late List<Map<String, Object?>> requests;

  setUp(() async {
    requests = <Map<String, Object?>>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.host}:${server.port}/compatible-mode';
    zhipuBaseUrl = 'http://${server.address.host}:${server.port}/api/paas/v4';
    server.listen((request) async {
      final bodyText = await utf8.decoder.bind(request).join();
      Object? body;
      if (bodyText.trim().isNotEmpty) {
        body = jsonDecode(bodyText);
      }
      final headers = <String, String>{};
      request.headers.forEach((name, values) {
        headers[name] = values.join(',');
      });
      requests.add(<String, Object?>{
        'method': request.method,
        'path': request.uri.path,
        'headers': headers,
        'body': body,
      });

      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/chat/completions')) {
        request.response.write(
          jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{
                  'content': <Object?>[
                    <String, Object?>{'type': 'text', 'text': '我看见你一直在努力。'},
                    <String, Object?>{'type': 'text', 'text': ' 这封信想先抱抱你。'},
                  ],
                },
              },
            ],
          }),
        );
      } else if (request.uri.path.endsWith('/embeddings')) {
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <Object?>[
              <String, Object?>{
                'embedding': <Object?>[0.12, 0.34, 0.56],
              },
            ],
          }),
        );
      } else if (request.uri.path == '/catalog/models') {
        request.response.write(
          jsonEncode(<Object?>[
            <String, Object?>{
              'id': 'openai/gpt-4.1',
              'name': 'GPT-4.1',
              'publisher': 'GitHub',
              'summary': 'GitHub catalog model',
            },
          ]),
        );
      } else if (request.uri.path.endsWith('/models')) {
        request.response.write(
          jsonEncode(<String, Object?>{'data': <Object?>[]}),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(
          jsonEncode(<String, Object?>{'error': 'unexpected path'}),
        );
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test(
    'chat completion uses OpenAI compatible endpoint and parses content parts',
    () async {
      const adapter = OpenAiCompatibleAiProviderAdapter();
      final service = _service(baseUrl: baseUrl);

      final result = await adapter.chatCompletion(
        AiChatCompletionRequest(
          service: service,
          model: service.models.first,
          messages: const <AiChatMessage>[
            AiChatMessage(role: 'user', content: '请给我写一封看见自己的信'),
          ],
          systemPrompt: '像温和的咨询师一样说话',
          temperature: 0.3,
        ),
      );

      expect(result.text, '我看见你一直在努力。 这封信想先抱抱你。');
      expect(requests, hasLength(1));
      expect(requests.single['method'], 'POST');
      expect(requests.single['path'], '/compatible-mode/chat/completions');

      final headers = requests.single['headers']! as Map<String, String>;
      expect(headers['authorization'], 'Bearer sk-test');

      final body = requests.single['body']! as Map<String, Object?>;
      expect(body['model'], 'qwen-plus');
      expect(body['stream'], false);
      final messages = body['messages']! as List<Object?>;
      expect(messages, hasLength(2));
      expect((messages.first as Map<String, Object?>)['role'], 'system');
      expect((messages.last as Map<String, Object?>)['role'], 'user');
    },
  );

  test(
    'embedding uses OpenAI compatible endpoint and returns vector',
    () async {
      const adapter = OpenAiCompatibleAiProviderAdapter();
      final service = _service(baseUrl: baseUrl);

      final vector = await adapter.embed(
        AiEmbeddingRequest(
          service: service,
          model: service.models.last,
          input: '今天其实很累，但还是撑下来了。',
        ),
      );

      expect(vector, <double>[0.12, 0.34, 0.56]);
      expect(requests, hasLength(1));
      expect(requests.single['path'], '/compatible-mode/embeddings');

      final body = requests.single['body']! as Map<String, Object?>;
      expect(body['model'], 'text-embedding-v4');
      expect(body['input'], '今天其实很累，但还是撑下来了。');
    },
  );
  test('zhipu validation uses unversioned models endpoint', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();
    final service = _service(
      baseUrl: zhipuBaseUrl,
      serviceId: 'svc_zhipu',
      templateId: aiTemplateZhipu,
      displayName: 'Zhipu AI',
    );

    final result = await adapter.validateConfig(service);

    expect(result.status, AiValidationStatus.success);
    expect(requests, hasLength(1));
    expect(requests.single['method'], 'GET');
    expect(requests.single['path'], '/api/paas/v4/models');
  });

  test('zhipu chat completion uses unversioned endpoint', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();
    final service = _service(
      baseUrl: zhipuBaseUrl,
      serviceId: 'svc_zhipu',
      templateId: aiTemplateZhipu,
      displayName: 'Zhipu AI',
    );

    await adapter.chatCompletion(
      AiChatCompletionRequest(
        service: service,
        model: service.models.first,
        messages: const <AiChatMessage>[
          AiChatMessage(role: 'user', content: 'hello'),
        ],
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single['path'], '/api/paas/v4/chat/completions');
  });

  test('zhipu embedding uses unversioned endpoint', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();
    final service = _service(
      baseUrl: zhipuBaseUrl,
      serviceId: 'svc_zhipu',
      templateId: aiTemplateZhipu,
      displayName: 'Zhipu AI',
    );

    await adapter.embed(
      AiEmbeddingRequest(
        service: service,
        model: service.models.last,
        input: 'hello',
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single['path'], '/api/paas/v4/embeddings');
  });

  test(
    'openai base already containing v1 does not duplicate version',
    () async {
      const adapter = OpenAiCompatibleAiProviderAdapter();
      final service = _service(
        baseUrl: 'http://${server.address.host}:${server.port}/v1',
        templateId: aiTemplateOpenAi,
        displayName: 'OpenAI',
      );

      await adapter.chatCompletion(
        AiChatCompletionRequest(
          service: service,
          model: service.models.first,
          messages: const <AiChatMessage>[
            AiChatMessage(role: 'user', content: 'hello'),
          ],
        ),
      );

      expect(requests.single['path'], '/v1/chat/completions');
    },
  );

  test('github models keeps inference base unversioned', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();
    final service = _service(
      baseUrl: 'http://${server.address.host}:${server.port}/inference',
      templateId: aiTemplateGitHubModels,
      displayName: 'GitHub Models',
    );

    final validation = await adapter.validateConfig(service);
    expect(validation.status, AiValidationStatus.success);
    expect(requests.single['path'], '/catalog/models');

    requests.clear();
    await adapter.chatCompletion(
      AiChatCompletionRequest(
        service: service,
        model: service.models.first,
        messages: const <AiChatMessage>[
          AiChatMessage(role: 'user', content: 'hello'),
        ],
      ),
    );
    expect(requests.single['path'], '/inference/chat/completions');
  });

  test('github models discovery uses catalog endpoint', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();
    final service = _service(
      baseUrl: 'http://${server.address.host}:${server.port}/inference',
      templateId: aiTemplateGitHubModels,
      displayName: 'GitHub Models',
    );

    final models = await adapter.listModels(service);

    expect(requests.single['path'], '/catalog/models');
    expect(models, hasLength(1));
    expect(models.single.modelKey, 'openai/gpt-4.1');
    expect(models.single.displayName, 'GPT-4.1');
    expect(models.single.ownedBy, 'GitHub');
  });

  test('perplexity keeps root base unversioned', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();
    final service = _service(
      baseUrl: 'http://${server.address.host}:${server.port}',
      templateId: aiTemplatePerplexity,
      displayName: 'Perplexity',
    );

    final validation = await adapter.validateConfig(service);
    expect(validation.status, AiValidationStatus.success);
    expect(requests.single['path'], '/models');

    requests.clear();
    await adapter.chatCompletion(
      AiChatCompletionRequest(
        service: service,
        model: service.models.first,
        messages: const <AiChatMessage>[
          AiChatMessage(role: 'user', content: 'hello'),
        ],
      ),
    );
    expect(requests.single['path'], '/chat/completions');
  });

  test('edited templates keep exact configured gateway path', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();

    Future<void> expectConfiguredPath({
      required String templateId,
      required String baseUrl,
    }) async {
      requests.clear();
      final service = _service(baseUrl: baseUrl, templateId: templateId);

      await adapter.chatCompletion(
        AiChatCompletionRequest(
          service: service,
          model: service.models.first,
          messages: const <AiChatMessage>[
            AiChatMessage(role: 'user', content: 'hello'),
          ],
        ),
      );

      expect(requests.single['path'], '/gateway/chat/completions');
    }

    await expectConfiguredPath(
      templateId: aiTemplateZhipu,
      baseUrl: 'http://${server.address.host}:${server.port}/gateway',
    );
    await expectConfiguredPath(
      templateId: aiTemplateGitHubModels,
      baseUrl: 'http://${server.address.host}:${server.port}/gateway',
    );
    await expectConfiguredPath(
      templateId: aiTemplatePerplexity,
      baseUrl: 'http://${server.address.host}:${server.port}/gateway',
    );
  });

  test('versioned and special paths are preserved', () async {
    const adapter = OpenAiCompatibleAiProviderAdapter();

    Future<void> expectChatPath({
      required String baseUrl,
      required String templateId,
      required String displayName,
      required String expectedPath,
    }) async {
      requests.clear();
      final service = _service(
        baseUrl: baseUrl,
        templateId: templateId,
        displayName: displayName,
      );
      await adapter.chatCompletion(
        AiChatCompletionRequest(
          service: service,
          model: service.models.first,
          messages: const <AiChatMessage>[
            AiChatMessage(role: 'user', content: 'hello'),
          ],
        ),
      );
      expect(requests.single['path'], expectedPath);
    }

    await expectChatPath(
      baseUrl: 'http://${server.address.host}:${server.port}/v3/openai',
      templateId: aiTemplatePpio,
      displayName: 'PPIO',
      expectedPath: '/v3/openai/chat/completions',
    );
    await expectChatPath(
      baseUrl:
          'http://${server.address.host}:${server.port}/user-center/v1/model',
      templateId: aiTemplateCephalon,
      displayName: 'Cephalon',
      expectedPath: '/user-center/v1/model/chat/completions',
    );
    await expectChatPath(
      baseUrl: 'http://${server.address.host}:${server.port}/api/v3',
      templateId: aiTemplateDoubao,
      displayName: 'Doubao',
      expectedPath: '/api/v3/chat/completions',
    );
    await expectChatPath(
      baseUrl: 'http://${server.address.host}:${server.port}/v2',
      templateId: aiTemplateBaiduCloud,
      displayName: 'Baidu Cloud',
      expectedPath: '/v2/chat/completions',
    );
    await expectChatPath(
      baseUrl: 'http://${server.address.host}:${server.port}/inference',
      templateId: aiTemplateFireworks,
      displayName: 'Fireworks',
      expectedPath: '/inference/chat/completions',
    );
    await expectChatPath(
      baseUrl: 'http://${server.address.host}:${server.port}/openai',
      templateId: aiTemplateLongCat,
      displayName: 'LongCat',
      expectedPath: '/openai/chat/completions',
    );
    await expectChatPath(
      baseUrl: 'http://${server.address.host}:${server.port}/openai',
      templateId: aiTemplateGroq,
      displayName: 'Groq',
      expectedPath: '/openai/chat/completions',
    );
  });
}

AiServiceInstance _service({
  required String baseUrl,
  String serviceId = 'svc_dashscope',
  String templateId = aiTemplateOpenAi,
  String displayName = 'DashScope',
}) {
  return AiServiceInstance(
    serviceId: serviceId,
    templateId: templateId,
    adapterKind: AiProviderAdapterKind.openAiCompatible,
    displayName: displayName,
    enabled: true,
    baseUrl: baseUrl,
    apiKey: 'sk-test',
    customHeaders: const <String, String>{},
    models: const <AiModelEntry>[
      AiModelEntry(
        modelId: 'mdl_chat',
        displayName: 'Qwen Plus',
        modelKey: 'qwen-plus',
        capabilities: <AiCapability>[AiCapability.chat],
        source: AiModelSource.manual,
        enabled: true,
      ),
      AiModelEntry(
        modelId: 'mdl_embed',
        displayName: 'Embedding V4',
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
}
