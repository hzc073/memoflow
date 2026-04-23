import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
      return;
    }
    _data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  test('AiSettings.fromJson falls back to an empty insight template map', () {
    final settings = AiSettings.fromJson(<String, dynamic>{
      'apiUrl': 'https://example.com',
      'apiKey': 'test-key',
      'model': 'gpt-4o-mini',
      'prompt': 'Base prompt',
    });

    expect(settings.insightPromptTemplates, isEmpty);
  });

  test('AiSettings.fromJson falls back to default proxy settings', () {
    final settings = AiSettings.fromJson(<String, dynamic>{
      'apiUrl': 'https://example.com',
      'apiKey': 'test-key',
      'model': 'gpt-4o-mini',
      'prompt': 'Base prompt',
    });

    expect(settings.proxySettings.protocol, AiProxyProtocol.http);
    expect(settings.proxySettings.isConfigured, isFalse);
    expect(settings.proxySettings.bypassLocalAddresses, isTrue);
  });

  test('AiSettingsRepository round-trips insight prompt templates', () async {
    final storage = _MemorySecureStorage();
    final repository = AiSettingsRepository(storage, accountKey: 'user-1');
    final initial = AiSettings.defaultsFor(AppLanguage.en).copyWith(
      insightPromptTemplates: const <String, String>{
        'today_clues': 'Focus on recent tensions.',
        'emotion_map': 'Summarize emotional patterns.',
      },
    );

    await repository.write(initial);
    final raw = await storage.read(key: 'ai_settings_v2_user-1');
    final encoded = jsonDecode(raw!) as Map<String, dynamic>;

    expect(
      encoded['insightPromptTemplates'],
      containsPair('today_clues', 'Focus on recent tensions.'),
    );

    final restored = await repository.read(language: AppLanguage.en);
    expect(restored.insightPromptTemplates, const <String, String>{
      'today_clues': 'Focus on recent tensions.',
      'emotion_map': 'Summarize emotional patterns.',
    });
  });

  test(
    'AiSettings.fromJson migrates legacy custom insight template to list',
    () {
      final settings = AiSettings.fromJson(<String, dynamic>{
        'prompt': 'Base prompt',
        'customInsightTemplate': <String, dynamic>{
          'title': 'Weekly Lens',
          'description': 'Focus on recurring weekly patterns.',
          'promptTemplate': 'Analyze my week with care.',
          'iconKey': 'star',
        },
      });

      final normalized = AiSettingsMigration.normalize(settings);

      expect(normalized.customInsightTemplates, hasLength(1));
      expect(normalized.customInsightTemplates.single.title, 'Weekly Lens');
      expect(
        normalized.customInsightTemplates.single.templateId.trim(),
        isNotEmpty,
      );
      expect(normalized.defaultInsightTemplatesCollapsed, isFalse);
    },
  );

  test(
    'AiSettingsRepository round-trips custom templates and default section state',
    () async {
      final storage = _MemorySecureStorage();
      final repository = AiSettingsRepository(storage, accountKey: 'user-3');
      final settings = AiSettings.defaultsFor(AppLanguage.en).copyWith(
        customInsightTemplates: const <AiCustomInsightTemplate>[
          AiCustomInsightTemplate(
            templateId: 'tpl_weekly',
            title: 'Weekly Lens',
            description: 'Focus on recurring weekly patterns.',
            promptTemplate: 'Analyze the last week with care.',
            iconKey: 'star',
          ),
        ],
        defaultInsightTemplatesCollapsed: true,
      );

      await repository.write(settings);
      final restored = await repository.read(language: AppLanguage.en);

      expect(restored.customInsightTemplates, hasLength(1));
      expect(restored.customInsightTemplates.single.templateId, 'tpl_weekly');
      expect(restored.defaultInsightTemplatesCollapsed, isTrue);
    },
  );

  test(
    'AiSettingsMigration migrates legacy profiles into services and routes',
    () {
      final legacy = AiSettings.fromJson(<String, dynamic>{
        'apiUrl': 'https://api.deepseek.com',
        'apiKey': 'sk-test',
        'model': 'deepseek-chat',
        'modelOptions': <String>['deepseek-chat', 'deepseek-reasoner'],
        'embeddingProfiles': <Map<String, dynamic>>[
          <String, dynamic>{
            'profileKey': 'legacy_embed',
            'displayName': 'Legacy Embedding',
            'baseUrl': 'http://127.0.0.1:11434',
            'apiKey': '',
            'model': 'bge-m3',
            'enabled': true,
          },
        ],
        'selectedEmbeddingProfileKey': 'legacy_embed',
        'prompt': 'Base prompt',
      });

      final normalized = AiSettingsMigration.normalize(legacy);

      expect(normalized.schemaVersion, AiSettings.currentSchemaVersion);
      expect(normalized.services, hasLength(2));
      expect(
        normalized.taskRouteBindings.map((binding) => binding.routeId),
        containsAll(<AiTaskRouteId>[
          AiTaskRouteId.summary,
          AiTaskRouteId.analysisReport,
          AiTaskRouteId.quickPrompt,
          AiTaskRouteId.embeddingRetrieval,
        ]),
      );
      expect(normalized.selectedGenerationProfile.model, 'deepseek-chat');
      expect(normalized.selectedEmbeddingProfile?.model, 'bge-m3');
    },
  );

  test('AiSettingsRepository writes v3 services and route bindings', () async {
    final storage = _MemorySecureStorage();
    final repository = AiSettingsRepository(storage, accountKey: 'user-2');
    final settings = AiSettings.defaultsFor(AppLanguage.en).copyWith(
      services: const <AiServiceInstance>[
        AiServiceInstance(
          serviceId: 'svc_test',
          templateId: aiTemplateOpenAi,
          adapterKind: AiProviderAdapterKind.openAiCompatible,
          displayName: 'OpenAI Main',
          enabled: true,
          usesSharedProxy: true,
          baseUrl: 'https://api.openai.com',
          apiKey: 'sk-test',
          customHeaders: <String, String>{'x-test': '1'},
          models: <AiModelEntry>[
            AiModelEntry(
              modelId: 'mdl_chat',
              displayName: 'gpt-4o-mini',
              modelKey: 'gpt-4o-mini',
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
      proxySettings: const AiProxySettings(
        protocol: AiProxyProtocol.socks5,
        host: 'proxy.example.com',
        port: 1080,
        username: 'demo',
        password: 'secret',
        bypassLocalAddresses: false,
      ),
      taskRouteBindings: const <AiTaskRouteBinding>[
        AiTaskRouteBinding(
          routeId: AiTaskRouteId.summary,
          serviceId: 'svc_test',
          modelId: 'mdl_chat',
          capability: AiCapability.chat,
        ),
      ],
    );

    await repository.write(settings);
    final raw = await storage.read(key: 'ai_settings_v2_user-2');
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], AiSettings.currentSchemaVersion);
    expect(decoded['services'], isA<List<dynamic>>());
    expect(decoded['taskRouteBindings'], isA<List<dynamic>>());
    expect(decoded['proxySettings'], isA<Map<String, dynamic>>());
    expect(
      decoded['proxySettings'],
      containsPair('protocol', AiProxyProtocol.socks5.name),
    );
    expect(
      (decoded['services'] as List<dynamic>).single,
      containsPair('usesSharedProxy', true),
    );

    final restored = await repository.read(language: AppLanguage.en);
    expect(restored.services.single.displayName, 'OpenAI Main');
    expect(restored.services.single.usesSharedProxy, isTrue);
    expect(restored.taskRouteBindings.single.routeId, AiTaskRouteId.summary);
    expect(restored.proxySettings.protocol, AiProxyProtocol.socks5);
    expect(restored.proxySettings.host, 'proxy.example.com');
    expect(restored.proxySettings.port, 1080);
    expect(restored.proxySettings.username, 'demo');
    expect(restored.proxySettings.password, 'secret');
    expect(restored.proxySettings.bypassLocalAddresses, isFalse);
  });

  test(
    'AiSettingsRepository migrates missing proxy fields with defaults',
    () async {
      final storage = _MemorySecureStorage();
      final repository = AiSettingsRepository(
        storage,
        accountKey: 'user-legacy',
      );
      final legacyJson = AiSettings.defaultsFor(AppLanguage.en)
          .copyWith(
            services: const <AiServiceInstance>[
              AiServiceInstance(
                serviceId: 'svc_legacy',
                templateId: aiTemplateOpenAi,
                adapterKind: AiProviderAdapterKind.openAiCompatible,
                displayName: 'Legacy Service',
                enabled: true,
                baseUrl: 'https://api.openai.com',
                apiKey: 'sk-test',
                customHeaders: <String, String>{},
                models: <AiModelEntry>[],
                lastValidatedAt: null,
                lastValidationStatus: AiValidationStatus.unknown,
                lastValidationMessage: null,
              ),
            ],
          )
          .toJson();
      legacyJson['schemaVersion'] = 3;
      legacyJson.remove('proxySettings');
      final legacyServices = (legacyJson['services'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      legacyServices.single.remove('usesSharedProxy');

      await storage.write(
        key: 'ai_settings_v2_user-legacy',
        value: jsonEncode(legacyJson),
      );

      final restored = await repository.read(language: AppLanguage.en);

      expect(restored.schemaVersion, AiSettings.currentSchemaVersion);
      expect(restored.proxySettings.protocol, AiProxyProtocol.http);
      expect(restored.proxySettings.isConfigured, isFalse);
      expect(restored.proxySettings.bypassLocalAddresses, isTrue);
      expect(restored.services.single.usesSharedProxy, isFalse);
    },
  );
}
