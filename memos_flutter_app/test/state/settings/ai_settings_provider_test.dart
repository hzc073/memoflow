// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/storage_read.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/data/repositories/ai_settings_repository.dart';
import 'package:memos_flutter_app/state/settings/ai_settings_provider.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/state/settings/preferences_provider.dart';

class _MemoryAiSettingsRepository extends AiSettingsRepository {
  _MemoryAiSettingsRepository(this._value)
    : super(const FlutterSecureStorage(), accountKey: 'test-account');

  AiSettings _value;

  @override
  Future<AiSettings> read({AppLanguage language = AppLanguage.en}) async =>
      _value;

  @override
  Future<void> write(AiSettings settings) async {
    _value = settings;
  }
}

class _DelayedAiSettingsRepository extends AiSettingsRepository {
  _DelayedAiSettingsRepository(this._loadedSnapshot)
    : super(const FlutterSecureStorage(), accountKey: 'test-account');

  final AiSettings _loadedSnapshot;
  final Completer<void> _gate = Completer<void>();
  AiSettings? writtenValue;

  void release() {
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  @override
  Future<AiSettings> read({AppLanguage language = AppLanguage.en}) async {
    await _gate.future;
    return _loadedSnapshot;
  }

  @override
  Future<void> write(AiSettings settings) async {
    writtenValue = settings;
  }
}

class _TestAiSettingsController extends AiSettingsController {
  _TestAiSettingsController(Ref ref, this._repository)
    : super(ref, _repository);

  final _MemoryAiSettingsRepository _repository;

  @override
  Future<void> setAll(AiSettings next, {bool triggerSync = true}) async {
    final normalized = AiSettingsMigration.normalize(next);
    state = normalized;
    await _repository.write(normalized);
  }
}

class _MemoryAppPreferencesRepository extends AppPreferencesRepository {
  _MemoryAppPreferencesRepository(this._prefs)
    : super(const FlutterSecureStorage(), accountKey: null);

  AppPreferences _prefs;

  @override
  Future<StorageReadResult<AppPreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<AppPreferences> read() async => _prefs;

  @override
  Future<void> write(AppPreferences prefs) async {
    _prefs = prefs;
  }

  @override
  Future<void> clear() async {
    _prefs = AppPreferences.defaultsForLanguage(AppLanguage.en);
  }
}

class _TestAppPreferencesController extends AppPreferencesController {
  _TestAppPreferencesController(Ref ref, this._repository)
    : super(ref, _repository, onLoaded: () {}) {
    state = _repository._prefs;
  }

  final _MemoryAppPreferencesRepository _repository;
}

class _MemoryDevicePreferencesRepository extends DevicePreferencesRepository {
  _MemoryDevicePreferencesRepository(this._prefs)
    : super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _prefs;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<DevicePreferences> read() async => _prefs;

  @override
  Future<void> write(DevicePreferences prefs) async {
    _prefs = prefs;
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(Ref ref, this._repository)
    : super(ref, _repository, onLoaded: () {}) {
    state = _repository._prefs;
  }

  final _MemoryDevicePreferencesRepository _repository;
}

void main() {
  test(
    'AiSettingsController upserts services and clears impacted routes on model delete',
    () async {
      final aiRepository = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );
      final prefsRepository = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );
      final devicePrefsRepository = _MemoryDevicePreferencesRepository(
        DevicePreferences.defaultsForLanguage(AppLanguage.en),
      );
      final container = ProviderContainer(
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) =>
                _TestDevicePreferencesController(ref, devicePrefsRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(aiSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final notifier = container.read(aiSettingsProvider.notifier);
      const embeddingService = AiServiceInstance(
        serviceId: 'svc_embed',
        templateId: aiTemplateOllama,
        adapterKind: AiProviderAdapterKind.ollama,
        displayName: 'Ollama Embedding',
        enabled: true,
        baseUrl: 'http://127.0.0.1:11434',
        apiKey: '',
        customHeaders: <String, String>{},
        models: <AiModelEntry>[
          AiModelEntry(
            modelId: 'mdl_embed',
            displayName: 'bge-m3',
            modelKey: 'bge-m3',
            capabilities: <AiCapability>[AiCapability.embedding],
            source: AiModelSource.manual,
            enabled: true,
          ),
        ],
        lastValidatedAt: null,
        lastValidationStatus: AiValidationStatus.unknown,
        lastValidationMessage: null,
      );

      await notifier.upsertService(embeddingService);
      await notifier.saveTaskRouteBinding(
        const AiTaskRouteBinding(
          routeId: AiTaskRouteId.embeddingRetrieval,
          serviceId: 'svc_embed',
          modelId: 'mdl_embed',
          capability: AiCapability.embedding,
        ),
      );

      expect(
        aiRepository._value.services.any(
          (service) => service.serviceId == 'svc_embed',
        ),
        isTrue,
      );
      expect(aiRepository._value.selectedEmbeddingProfile?.model, 'bge-m3');

      await notifier.deleteServiceModel('svc_embed', 'mdl_embed');

      final state = aiRepository._value;
      expect(state.services.firstById('svc_embed')?.models, isEmpty);
      expect(
        state.taskRouteBindings.where(
          (binding) => binding.routeId == AiTaskRouteId.embeddingRetrieval,
        ),
        isEmpty,
      );
    },
  );

  test(
    'AiSettingsController does not let late load overwrite newer local edits',
    () async {
      const loadedSettings = AiSettings(
        schemaVersion: AiSettings.currentSchemaVersion,
        services: <AiServiceInstance>[
          AiServiceInstance(
            serviceId: 'svc_loaded_embed',
            templateId: aiTemplateCustomOpenAi,
            adapterKind: AiProviderAdapterKind.openAiCompatible,
            displayName: 'Loaded Embedding',
            enabled: true,
            baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
            apiKey: 'loaded-key',
            customHeaders: <String, String>{},
            models: <AiModelEntry>[
              AiModelEntry(
                modelId: 'mdl_loaded_embed',
                displayName: 'qwen3-vl-embedding',
                modelKey: 'qwen3-vl-embedding',
                capabilities: <AiCapability>[AiCapability.embedding],
                source: AiModelSource.manual,
                enabled: true,
              ),
            ],
            lastValidatedAt: null,
            lastValidationStatus: AiValidationStatus.unknown,
            lastValidationMessage: null,
          ),
        ],
        taskRouteBindings: <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.embeddingRetrieval,
            serviceId: 'svc_loaded_embed',
            modelId: 'mdl_loaded_embed',
            capability: AiCapability.embedding,
          ),
        ],
        generationProfiles: <AiGenerationProfile>[
          AiGenerationProfile.unconfigured,
        ],
        selectedGenerationProfileKey: '',
        embeddingProfiles: <AiEmbeddingProfile>[
          AiEmbeddingProfile(
            profileKey: 'loaded_embed_profile',
            displayName: 'Loaded Embedding',
            backendKind: AiBackendKind.remoteApi,
            providerKind: AiProviderKind.openAiCompatible,
            baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
            apiKey: 'loaded-key',
            model: 'qwen3-vl-embedding',
            enabled: true,
          ),
        ],
        selectedEmbeddingProfileKey: 'loaded_embed_profile',
        prompt: '',
        userProfile: '',
        quickPrompts: <AiQuickPrompt>[],
        analysisPromptTemplates: <String, String>{},
      );
      final aiRepository = _DelayedAiSettingsRepository(loadedSettings);
      final prefsRepository = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );
      final devicePrefsRepository = _MemoryDevicePreferencesRepository(
        DevicePreferences.defaultsForLanguage(AppLanguage.en),
      );
      final container = ProviderContainer(
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) =>
                _TestDevicePreferencesController(ref, devicePrefsRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => AiSettingsController(ref, aiRepository),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(aiSettingsProvider.notifier);
      final nextState = container
          .read(aiSettingsProvider)
          .copyWith(
            services: const <AiServiceInstance>[
              AiServiceInstance(
                serviceId: 'svc_new_embed',
                templateId: aiTemplateCustomOpenAi,
                adapterKind: AiProviderAdapterKind.openAiCompatible,
                displayName: 'Edited Embedding',
                enabled: true,
                baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
                apiKey: 'new-key',
                customHeaders: <String, String>{},
                models: <AiModelEntry>[
                  AiModelEntry(
                    modelId: 'mdl_new_embed',
                    displayName: 'text-embedding-v4',
                    modelKey: 'text-embedding-v4',
                    capabilities: <AiCapability>[AiCapability.embedding],
                    source: AiModelSource.manual,
                    enabled: true,
                  ),
                ],
                lastValidatedAt: null,
                lastValidationStatus: AiValidationStatus.unknown,
                lastValidationMessage: null,
              ),
            ],
            taskRouteBindings: const <AiTaskRouteBinding>[
              AiTaskRouteBinding(
                routeId: AiTaskRouteId.embeddingRetrieval,
                serviceId: 'svc_new_embed',
                modelId: 'mdl_new_embed',
                capability: AiCapability.embedding,
              ),
            ],
            generationProfiles: const <AiGenerationProfile>[
              AiGenerationProfile.unconfigured,
            ],
            selectedGenerationProfileKey: '',
            embeddingProfiles: const <AiEmbeddingProfile>[
              AiEmbeddingProfile(
                profileKey: 'new_embed_profile',
                displayName: 'Edited Embedding',
                backendKind: AiBackendKind.remoteApi,
                providerKind: AiProviderKind.openAiCompatible,
                baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
                apiKey: 'new-key',
                model: 'text-embedding-v4',
                enabled: true,
              ),
            ],
            selectedEmbeddingProfileKey: 'new_embed_profile',
          );

      await notifier.setAll(nextState, triggerSync: false);
      aiRepository.release();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(aiSettingsProvider);
      expect(state.selectedEmbeddingProfile?.model, 'text-embedding-v4');
      expect(
        aiRepository.writtenValue?.selectedEmbeddingProfile?.model,
        'text-embedding-v4',
      );
    },
  );

  test(
    'AiSettingsController reloadFromStorage refreshes externally updated settings',
    () async {
      final initial = AiSettings.defaultsFor(AppLanguage.en);
      final reloaded = AiSettingsMigration.normalize(
        initial.copyWith(
          services: const <AiServiceInstance>[
            AiServiceInstance(
              serviceId: 'svc_reload',
              templateId: aiTemplateCustomOpenAi,
              adapterKind: AiProviderAdapterKind.openAiCompatible,
              displayName: 'Reloaded Service',
              enabled: true,
              baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
              apiKey: 'reloaded-key',
              customHeaders: <String, String>{},
              models: <AiModelEntry>[
                AiModelEntry(
                  modelId: 'mdl_reload',
                  displayName: 'qwen3-max',
                  modelKey: 'qwen3-max',
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
          taskRouteBindings: const <AiTaskRouteBinding>[
            AiTaskRouteBinding(
              routeId: AiTaskRouteId.summary,
              serviceId: 'svc_reload',
              modelId: 'mdl_reload',
              capability: AiCapability.chat,
            ),
            AiTaskRouteBinding(
              routeId: AiTaskRouteId.analysisReport,
              serviceId: 'svc_reload',
              modelId: 'mdl_reload',
              capability: AiCapability.chat,
            ),
            AiTaskRouteBinding(
              routeId: AiTaskRouteId.quickPrompt,
              serviceId: 'svc_reload',
              modelId: 'mdl_reload',
              capability: AiCapability.chat,
            ),
          ],
        ),
      );
      final aiRepository = _MemoryAiSettingsRepository(initial);
      final prefsRepository = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );
      final devicePrefsRepository = _MemoryDevicePreferencesRepository(
        DevicePreferences.defaultsForLanguage(AppLanguage.en),
      );
      final container = ProviderContainer(
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) =>
                _TestDevicePreferencesController(ref, devicePrefsRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => AiSettingsController(ref, aiRepository),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(aiSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      aiRepository._value = reloaded;
      await container.read(aiSettingsProvider.notifier).reloadFromStorage();

      final state = container.read(aiSettingsProvider);
      expect(state.services.single.serviceId, 'svc_reload');
      expect(state.apiKey, 'reloaded-key');
      expect(state.model, 'qwen3-max');
    },
  );

  test(
    'AiSettingsController ignores pending async load after dispose',
    () async {
      final aiRepository = _DelayedAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );
      final prefsRepository = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );
      final devicePrefsRepository = _MemoryDevicePreferencesRepository(
        DevicePreferences.defaultsForLanguage(AppLanguage.en),
      );
      final container = ProviderContainer(
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) =>
                _TestDevicePreferencesController(ref, devicePrefsRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => AiSettingsController(ref, aiRepository),
          ),
        ],
      );

      container.read(aiSettingsProvider);
      container.dispose();
      aiRepository.release();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(true, isTrue);
    },
  );

  test(
    'AiSettingsController manages custom insight templates and collapsed state',
    () async {
      final aiRepository = _MemoryAiSettingsRepository(
        AiSettings.defaultsFor(AppLanguage.en),
      );
      final prefsRepository = _MemoryAppPreferencesRepository(
        AppPreferences.defaultsForLanguage(AppLanguage.en),
      );
      final devicePrefsRepository = _MemoryDevicePreferencesRepository(
        DevicePreferences.defaultsForLanguage(AppLanguage.en),
      );
      final container = ProviderContainer(
        overrides: [
          devicePreferencesProvider.overrideWith(
            (ref) =>
                _TestDevicePreferencesController(ref, devicePrefsRepository),
          ),
          appPreferencesProvider.overrideWith(
            (ref) => _TestAppPreferencesController(ref, prefsRepository),
          ),
          aiSettingsProvider.overrideWith(
            (ref) => _TestAiSettingsController(ref, aiRepository),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(aiSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final controller = container.read(aiSettingsProvider.notifier);

      await controller.addCustomInsightTemplate(
        const AiCustomInsightTemplate(
          title: 'Weekly Lens',
          description: 'Focus on recurring weekly patterns.',
          promptTemplate: 'Analyze the last week with care.',
          iconKey: 'star',
        ),
      );

      final created = container.read(aiSettingsProvider).customInsightTemplates;
      expect(created, hasLength(1));
      expect(created.single.templateId.trim(), isNotEmpty);

      await controller.updateCustomInsightTemplate(
        created.single.templateId,
        created.single.copyWith(title: 'Weekly Reflection'),
      );
      expect(
        container.read(aiSettingsProvider).customInsightTemplates.single.title,
        'Weekly Reflection',
      );

      await controller.setDefaultInsightTemplatesCollapsed(true);
      expect(
        container.read(aiSettingsProvider).defaultInsightTemplatesCollapsed,
        isTrue,
      );

      await controller.deleteCustomInsightTemplate(created.single.templateId);
      expect(
        container.read(aiSettingsProvider).customInsightTemplates,
        isEmpty,
      );
    },
  );
}
