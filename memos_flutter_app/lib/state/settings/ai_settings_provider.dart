import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/uid.dart';
import '../../data/ai/ai_settings_log.dart';
import '../../data/logs/log_manager.dart';
import '../sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../data/repositories/ai_settings_repository.dart';
import 'preferences_provider.dart';
import '../system/session_provider.dart';

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return AiSettingsRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final aiProviderRegistryProvider = Provider<AiProviderRegistry>((ref) {
  return AiProviderRegistry.defaults();
});

final aiSettingsProvider =
    StateNotifierProvider<AiSettingsController, AiSettings>((ref) {
      return AiSettingsController(ref, ref.watch(aiSettingsRepositoryProvider));
    });

class AiSettingsController extends StateNotifier<AiSettings> {
  AiSettingsController(Ref ref, AiSettingsRepository repo)
    : _ref = ref,
      _repo = repo,
      super(AiSettings.defaultsFor(ref.read(appPreferencesProvider).language)) {
    unawaited(_load());
  }

  final Ref _ref;
  final AiSettingsRepository _repo;
  int _localRevision = 0;

  Future<void> reloadFromStorage() async {
    _localRevision += 1;
    await _load();
  }

  Future<void> _load() async {
    final revisionAtStart = _localRevision;
    try {
      final loaded = await _repo.read(
        language: _ref.read(appPreferencesProvider).language,
      );
      if (_localRevision != revisionAtStart) {
        LogManager.instance.info(
          'AI settings load skipped because newer local changes exist',
        );
        return;
      }
      state = loaded;
      LogManager.instance.info(
        'AI settings loaded',
        context: <String, Object?>{
          'service_count': state.services.length,
          'route_count': state.taskRouteBindings.length,
          'quick_prompt_count': state.quickPrompts.length,
          'analysis_template_count': state.analysisPromptTemplates.length,
        },
      );
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'AI settings load failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> setAll(AiSettings next, {bool triggerSync = true}) async {
    final normalized = AiSettingsMigration.normalize(next);
    _localRevision += 1;
    state = normalized;
    await _repo.write(normalized);
    if (triggerSync) {
      unawaited(
        _ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.settings,
              ),
            ),
      );
    }
  }

  Future<void> setApiUrl(String v) async {
    final service = _resolveOrCreateServiceForCapability(AiCapability.chat);
    await setAll(
      _withUpsertedService(state, service.copyWith(baseUrl: v.trim())),
    );
  }

  Future<void> setApiKey(String v) async {
    final service = _resolveOrCreateServiceForCapability(AiCapability.chat);
    await setAll(
      _withUpsertedService(state, service.copyWith(apiKey: v.trim())),
    );
  }

  Future<void> setModel(String v) async {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return;
    final service = _resolveOrCreateServiceForCapability(AiCapability.chat);
    final existingModel = service.models.firstWhere(
      (model) =>
          model.modelKey.trim().toLowerCase() == trimmed.toLowerCase() &&
          model.capabilities.contains(AiCapability.chat),
      orElse: () => AiModelEntry(
        modelId: '',
        displayName: '',
        modelKey: '',
        capabilities: const <AiCapability>[],
        source: AiModelSource.manual,
        enabled: false,
      ),
    );
    final resolvedModel = existingModel.modelId.trim().isNotEmpty
        ? existingModel
        : AiModelEntry(
            modelId: 'mdl_${generateUid()}',
            displayName: trimmed,
            modelKey: trimmed,
            capabilities: const <AiCapability>[AiCapability.chat],
            source: AiModelSource.manual,
            enabled: true,
          );
    final nextService = _upsertModelInService(service, resolvedModel);
    final nextBindings =
        _replaceBindings(state.taskRouteBindings, <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.summary,
            serviceId: nextService.serviceId,
            modelId: resolvedModel.modelId,
            capability: AiCapability.chat,
          ),
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.analysisReport,
            serviceId: nextService.serviceId,
            modelId: resolvedModel.modelId,
            capability: AiCapability.chat,
          ),
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.quickPrompt,
            serviceId: nextService.serviceId,
            modelId: resolvedModel.modelId,
            capability: AiCapability.chat,
          ),
        ]);
    await setAll(
      _withUpsertedService(
        state.copyWith(
          taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(
            nextBindings,
          ),
        ),
        nextService,
      ),
    );
  }

  Future<void> setEmbeddingBaseUrl(String v) async {
    final service = _resolveOrCreateServiceForCapability(
      AiCapability.embedding,
    );
    await setAll(
      _withUpsertedService(state, service.copyWith(baseUrl: v.trim())),
    );
  }

  Future<void> setEmbeddingApiKey(String v) async {
    final service = _resolveOrCreateServiceForCapability(
      AiCapability.embedding,
    );
    await setAll(
      _withUpsertedService(state, service.copyWith(apiKey: v.trim())),
    );
  }

  Future<void> setEmbeddingModel(String v) async {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return;
    final service = _resolveOrCreateServiceForCapability(
      AiCapability.embedding,
    );
    final existingModel = service.models.firstWhere(
      (model) =>
          model.modelKey.trim().toLowerCase() == trimmed.toLowerCase() &&
          model.capabilities.contains(AiCapability.embedding),
      orElse: () => AiModelEntry(
        modelId: '',
        displayName: '',
        modelKey: '',
        capabilities: const <AiCapability>[],
        source: AiModelSource.manual,
        enabled: false,
      ),
    );
    final resolvedModel = existingModel.modelId.trim().isNotEmpty
        ? existingModel
        : AiModelEntry(
            modelId: 'mdl_${generateUid()}',
            displayName: trimmed,
            modelKey: trimmed,
            capabilities: const <AiCapability>[AiCapability.embedding],
            source: AiModelSource.manual,
            enabled: true,
          );
    final nextService = _upsertModelInService(service, resolvedModel);
    final nextBindings =
        _replaceBindings(state.taskRouteBindings, <AiTaskRouteBinding>[
          AiTaskRouteBinding(
            routeId: AiTaskRouteId.embeddingRetrieval,
            serviceId: nextService.serviceId,
            modelId: resolvedModel.modelId,
            capability: AiCapability.embedding,
          ),
        ]);
    await setAll(
      _withUpsertedService(
        state.copyWith(
          taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(
            nextBindings,
          ),
        ),
        nextService,
      ),
    );
  }

  Future<void> setPrompt(String v) async =>
      setAll(state.copyWith(prompt: v.trim()));
  Future<void> setUserProfile(String v) async =>
      setAll(state.copyWith(userProfile: v.trim()));

  Future<void> setGenerationProfiles(
    List<AiGenerationProfile> profiles, {
    String? selectedKey,
  }) async {
    final legacyState = state.copyWith(
      services: const <AiServiceInstance>[],
      taskRouteBindings: const <AiTaskRouteBinding>[],
      generationProfiles: List<AiGenerationProfile>.unmodifiable(profiles),
      selectedGenerationProfileKey: selectedKey,
    );
    await setAll(legacyState);
  }

  Future<void> setEmbeddingProfiles(
    List<AiEmbeddingProfile> profiles, {
    String? selectedKey,
  }) async {
    final legacyState = state.copyWith(
      services: const <AiServiceInstance>[],
      taskRouteBindings: const <AiTaskRouteBinding>[],
      embeddingProfiles: List<AiEmbeddingProfile>.unmodifiable(profiles),
      selectedEmbeddingProfileKey: selectedKey,
    );
    await setAll(legacyState);
  }

  Future<void> upsertService(
    AiServiceInstance service, {
    bool triggerSync = true,
  }) async {
    final existed = state.services.any(
      (item) => item.serviceId == service.serviceId,
    );
    await setAll(
      _withUpsertedService(state, service),
      triggerSync: triggerSync,
    );
    LogManager.instance.info(
      existed ? 'AI settings service updated' : 'AI settings service created',
      context: buildAiServiceLogContext(service),
    );
  }

  Future<void> deleteService(
    String serviceId, {
    bool triggerSync = true,
  }) async {
    final service = state.services.firstById(serviceId);
    final nextServices = state.services
        .where((service) => service.serviceId != serviceId)
        .toList(growable: false);
    final nextBindings = state.taskRouteBindings
        .where((binding) => binding.serviceId != serviceId)
        .toList(growable: false);
    await setAll(
      state.copyWith(
        services: List<AiServiceInstance>.unmodifiable(nextServices),
        taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(nextBindings),
      ),
      triggerSync: triggerSync,
    );
    if (service != null) {
      LogManager.instance.info(
        'AI settings service deleted',
        context: buildAiServiceLogContext(
          service,
          routeCount: state.taskRouteBindings
              .where((binding) => binding.serviceId == serviceId)
              .length,
        ),
      );
    }
  }

  Future<void> duplicateService(
    String serviceId, {
    bool triggerSync = true,
  }) async {
    final service = state.services.firstById(serviceId);
    if (service == null) return;
    final nextServiceId = 'svc_${generateUid()}';
    final duplicatedModels = service.models
        .map((model) => model.copyWith(modelId: 'mdl_${generateUid()}'))
        .toList(growable: false);
    final duplicated = service.copyWith(
      serviceId: nextServiceId,
      displayName: '${service.displayName} Copy',
      models: List<AiModelEntry>.unmodifiable(duplicatedModels),
      lastValidatedAt: null,
      lastValidationStatus: AiValidationStatus.unknown,
      lastValidationMessage: null,
    );
    await setAll(
      _withUpsertedService(state, duplicated),
      triggerSync: triggerSync,
    );
    LogManager.instance.info(
      'AI settings service duplicated',
      context: <String, Object?>{
        ...buildAiServiceLogContext(duplicated),
        'source_service_id': service.serviceId,
      },
    );
  }

  Future<void> setServiceEnabled(
    String serviceId,
    bool enabled, {
    bool triggerSync = true,
  }) async {
    final service = state.services.firstById(serviceId);
    if (service == null) return;
    final nextService = service.copyWith(enabled: enabled);
    await setAll(
      _withUpsertedService(state, nextService),
      triggerSync: triggerSync,
    );
    LogManager.instance.info(
      'AI settings service toggled',
      context: buildAiServiceLogContext(nextService),
    );
  }

  Future<void> upsertServiceModel(
    String serviceId,
    AiModelEntry model, {
    bool triggerSync = true,
  }) async {
    final service = state.services.firstById(serviceId);
    if (service == null) return;
    final existed = service.models.any((item) => item.modelId == model.modelId);
    final nextService = _upsertModelInService(service, model);
    await setAll(
      _withUpsertedService(state, nextService),
      triggerSync: triggerSync,
    );
    LogManager.instance.info(
      existed ? 'AI settings model updated' : 'AI settings model created',
      context: buildAiServiceLogContext(nextService, model: model),
    );
  }

  Future<void> deleteServiceModel(
    String serviceId,
    String modelId, {
    bool triggerSync = true,
  }) async {
    final service = state.services.firstById(serviceId);
    if (service == null) return;
    final model = service.models.firstWhere(
      (item) => item.modelId == modelId,
      orElse: () => AiModelEntry(
        modelId: '',
        displayName: '',
        modelKey: '',
        capabilities: const <AiCapability>[],
        source: AiModelSource.manual,
        enabled: false,
      ),
    );
    final removedRouteCount = state.taskRouteBindings
        .where(
          (binding) =>
              binding.serviceId == serviceId && binding.modelId == modelId,
        )
        .length;
    final nextService = service.copyWith(
      models: List<AiModelEntry>.unmodifiable(
        service.models.where((model) => model.modelId != modelId).toList(),
      ),
    );
    final nextBindings = state.taskRouteBindings
        .where(
          (binding) =>
              binding.serviceId != serviceId || binding.modelId != modelId,
        )
        .toList(growable: false);
    await setAll(
      _withUpsertedService(
        state.copyWith(
          taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(
            nextBindings,
          ),
        ),
        nextService,
      ),
      triggerSync: triggerSync,
    );
    if (model.modelId.isNotEmpty) {
      LogManager.instance.info(
        'AI settings model deleted',
        context: buildAiServiceLogContext(
          service,
          model: model,
          routeCount: removedRouteCount,
        ),
      );
    }
  }

  Future<void> saveTaskRouteBinding(
    AiTaskRouteBinding binding, {
    bool triggerSync = true,
  }) async {
    final nextBindings = _replaceBindings(
      state.taskRouteBindings,
      <AiTaskRouteBinding>[binding],
    );
    await setAll(
      state.copyWith(
        taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(nextBindings),
      ),
      triggerSync: triggerSync,
    );
    final service = state.services.firstById(binding.serviceId);
    final model = service?.models.firstWhere(
      (item) => item.modelId == binding.modelId,
      orElse: () => AiModelEntry(
        modelId: '',
        displayName: '',
        modelKey: '',
        capabilities: const <AiCapability>[],
        source: AiModelSource.manual,
        enabled: false,
      ),
    );
    LogManager.instance.info(
      'AI settings route binding saved',
      context: service == null
          ? <String, Object?>{
              'route_id': binding.routeId.name,
              'service_id': binding.serviceId,
              'model_id': binding.modelId,
              'route_capability': binding.capability.name,
            }
          : buildAiServiceLogContext(
              service,
              model: model != null && model.modelId.isNotEmpty ? model : null,
              binding: binding,
            ),
    );
  }

  Future<void> replaceTaskRouteBindings(
    List<AiTaskRouteBinding> bindings, {
    bool triggerSync = true,
  }) async {
    await setAll(
      state.copyWith(
        taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(bindings),
      ),
      triggerSync: triggerSync,
    );
  }

  Future<void> setProxySettings(
    AiProxySettings next, {
    bool triggerSync = true,
  }) async {
    await setAll(
      state.copyWith(proxySettings: next),
      triggerSync: triggerSync,
    );
    LogManager.instance.info(
      'AI settings proxy updated',
      context: buildAiProxySettingsLogContext(next),
    );
  }

  Future<void> recordServiceValidation(
    String serviceId,
    AiValidationStatus status, {
    String? message,
    DateTime? validatedAt,
    bool triggerSync = true,
  }) async {
    final service = state.services.firstById(serviceId);
    if (service == null) return;
    final nextService = service.copyWith(
      lastValidatedAt: validatedAt ?? DateTime.now(),
      lastValidationStatus: status,
      lastValidationMessage: message,
    );
    await setAll(
      _withUpsertedService(state, nextService),
      triggerSync: triggerSync,
    );
    LogManager.instance.info(
      'AI settings service validation recorded',
      context: <String, Object?>{
        ...buildAiServiceLogContext(nextService),
        'validation_status': status.name,
        if (message != null && message.trim().isNotEmpty)
          'validation_message': message.trim(),
      },
    );
  }

  Future<void> ensureInsightPromptTemplateInitialized(
    String insightId,
    String template,
  ) async {
    final normalizedInsightId = insightId.trim();
    final normalizedTemplate = template.trim();
    if (normalizedInsightId.isEmpty || normalizedTemplate.isEmpty) {
      return;
    }
    final existing =
        state.analysisPromptTemplates[normalizedInsightId]?.trim() ?? '';
    if (existing.isNotEmpty) {
      return;
    }
    await setInsightPromptTemplate(normalizedInsightId, normalizedTemplate);
  }

  Future<void> setInsightPromptTemplate(
    String insightId,
    String template,
  ) async {
    final normalizedInsightId = insightId.trim();
    if (normalizedInsightId.isEmpty) return;
    final nextTemplates = Map<String, String>.from(
      state.analysisPromptTemplates,
    );
    final normalizedTemplate = template.trim();
    if (normalizedTemplate.isEmpty) {
      nextTemplates.remove(normalizedInsightId);
    } else {
      nextTemplates[normalizedInsightId] = normalizedTemplate;
    }
    await setAll(
      state.copyWith(
        analysisPromptTemplates: Map<String, String>.unmodifiable(
          nextTemplates,
        ),
      ),
    );
  }

  Future<void> clearInsightPromptTemplate(String insightId) async {
    await setInsightPromptTemplate(insightId, '');
  }

  Future<void> setCustomInsightTemplate(
    AiCustomInsightTemplate template,
  ) async {
    final normalizedTitle = template.title.trim();
    final normalizedDescription = template.description.trim();
    final normalizedPrompt = template.promptTemplate.trim();
    final normalizedIconKey = template.iconKey.trim().isEmpty
        ? AiQuickPrompt.defaultIconKey
        : template.iconKey.trim();
    await setAll(
      state.copyWith(
        customInsightTemplate: AiCustomInsightTemplate(
          title: normalizedTitle,
          description: normalizedDescription,
          promptTemplate: normalizedPrompt,
          iconKey: normalizedIconKey,
        ),
      ),
    );
  }

  Future<void> clearCustomInsightTemplate() async {
    await setAll(
      state.copyWith(customInsightTemplate: const AiCustomInsightTemplate()),
    );
  }

  AiSettings _withUpsertedService(
    AiSettings current,
    AiServiceInstance service,
  ) {
    final services = current.services.toList(growable: true);
    final index = services.indexWhere(
      (item) => item.serviceId.trim() == service.serviceId.trim(),
    );
    if (index >= 0) {
      services[index] = service;
    } else {
      services.add(service);
    }
    return current.copyWith(
      services: List<AiServiceInstance>.unmodifiable(services),
    );
  }

  AiServiceInstance _resolveOrCreateServiceForCapability(
    AiCapability capability,
  ) {
    final routeId = switch (capability) {
      AiCapability.embedding => AiTaskRouteId.embeddingRetrieval,
      _ => AiTaskRouteId.summary,
    };
    final resolved = AiRouteResolver.resolveTaskRoute(
      services: state.services,
      bindings: state.taskRouteBindings,
      routeId: routeId,
      capability: capability,
    );
    if (resolved != null) return resolved.service;
    final existing = state.services.firstWhere(
      (service) => service.supports(capability),
      orElse: () => _buildDefaultService(capability),
    );
    return existing;
  }

  AiServiceInstance _buildDefaultService(AiCapability capability) {
    final template = switch (capability) {
      AiCapability.embedding => findAiProviderTemplate(aiTemplateCustomOpenAi)!,
      _ => findAiProviderTemplate(aiTemplateDeepSeek)!,
    };
    return AiServiceInstance(
      serviceId: 'svc_${generateUid()}',
      templateId: template.templateId,
      adapterKind: template.adapterKind,
      displayName: capability == AiCapability.embedding
          ? 'Embedding Service'
          : 'Generation Service',
      enabled: true,
      baseUrl: template.defaultBaseUrl,
      apiKey: '',
      customHeaders: template.defaultHeaders,
      models: const <AiModelEntry>[],
      lastValidatedAt: null,
      lastValidationStatus: AiValidationStatus.unknown,
      lastValidationMessage: null,
    );
  }

  AiServiceInstance _upsertModelInService(
    AiServiceInstance service,
    AiModelEntry model,
  ) {
    final models = service.models.toList(growable: true);
    final index = models.indexWhere(
      (item) => item.modelId.trim() == model.modelId.trim(),
    );
    if (index >= 0) {
      models[index] = model;
    } else {
      models.add(model);
    }
    return service.copyWith(models: List<AiModelEntry>.unmodifiable(models));
  }

  List<AiTaskRouteBinding> _replaceBindings(
    List<AiTaskRouteBinding> current,
    List<AiTaskRouteBinding> replacements,
  ) {
    final routeIds = replacements.map((binding) => binding.routeId).toSet();
    final next =
        current
            .where((binding) => !routeIds.contains(binding.routeId))
            .toList(growable: true)
          ..addAll(replacements);
    return List<AiTaskRouteBinding>.unmodifiable(next);
  }
}
