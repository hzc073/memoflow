import 'ai_provider_models.dart';
import 'ai_provider_templates.dart';
import 'ai_route_resolver.dart';
import 'ai_settings_models.dart';

class AiSettingsMigration {
  const AiSettingsMigration._();

  static AiSettings normalize(AiSettings source) {
    final normalizedServices = source.services.isNotEmpty
        ? _normalizeServices(source.services)
        : _migrateLegacyServices(source);
    final normalizedBindings =
        source.services.isNotEmpty || source.taskRouteBindings.isNotEmpty
        ? _normalizeBindings(source.taskRouteBindings, normalizedServices)
        : _migrateLegacyBindings(source, normalizedServices);
    final shadows = _buildShadowProfiles(
      services: normalizedServices,
      bindings: normalizedBindings,
    );
    return AiSettings(
      schemaVersion: AiSettings.currentSchemaVersion,
      services: List<AiServiceInstance>.unmodifiable(normalizedServices),
      taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(
        normalizedBindings,
      ),
      generationProfiles: shadows.generationProfiles,
      selectedGenerationProfileKey: shadows.selectedGenerationProfileKey,
      embeddingProfiles: shadows.embeddingProfiles,
      selectedEmbeddingProfileKey: shadows.selectedEmbeddingProfileKey,
      prompt: source.prompt,
      userProfile: source.userProfile,
      proxySettings: _normalizeProxySettings(source.proxySettings),
      quickPrompts: List<AiQuickPrompt>.unmodifiable(source.quickPrompts),
      analysisPromptTemplates: Map<String, String>.unmodifiable(
        source.analysisPromptTemplates,
      ),
      customInsightTemplate: source.customInsightTemplate,
    );
  }

  static List<AiServiceInstance> _normalizeServices(
    List<AiServiceInstance> services,
  ) {
    final next = <AiServiceInstance>[];
    final seenServiceIds = <String>{};
    for (final service in services) {
      final normalizedServiceId = service.serviceId.trim();
      if (normalizedServiceId.isEmpty ||
          !seenServiceIds.add(normalizedServiceId)) {
        continue;
      }
      final normalizedHeaders = <String, String>{};
      service.customHeaders.forEach((headerKey, headerValue) {
        final normalizedKey = headerKey.trim();
        final normalizedValue = headerValue.trim();
        if (normalizedKey.isEmpty || normalizedValue.isEmpty) return;
        normalizedHeaders[normalizedKey] = normalizedValue;
      });

      final normalizedModels = <AiModelEntry>[];
      final seenModelIds = <String>{};
      final seenModelKeys = <String>{};
      for (final model in service.models) {
        final modelId = model.modelId.trim();
        final modelKey = model.modelKey.trim();
        if (modelId.isEmpty || modelKey.isEmpty) continue;
        if (!seenModelIds.add(modelId)) continue;
        final normalizedModelKey = modelKey.toLowerCase();
        if (!seenModelKeys.add(normalizedModelKey)) continue;
        final displayName = model.displayName.trim().isEmpty
            ? model.modelKey.trim()
            : model.displayName.trim();
        normalizedModels.add(
          model.copyWith(
            modelId: modelId,
            modelKey: model.modelKey.trim(),
            displayName: displayName,
            capabilities: List<AiCapability>.unmodifiable(
              model.capabilities.toSet().toList(growable: false),
            ),
          ),
        );
      }

      next.add(
        service.copyWith(
          serviceId: normalizedServiceId,
          templateId: service.templateId.trim(),
          displayName: service.displayName.trim().isEmpty
              ? _fallbackServiceName(service.templateId)
              : service.displayName.trim(),
          baseUrl: service.baseUrl.trim(),
          apiKey: service.apiKey.trim(),
          customHeaders: Map<String, String>.unmodifiable(normalizedHeaders),
          models: List<AiModelEntry>.unmodifiable(normalizedModels),
        ),
      );
    }
    return List<AiServiceInstance>.unmodifiable(next);
  }

  static List<AiTaskRouteBinding> _normalizeBindings(
    List<AiTaskRouteBinding> bindings,
    List<AiServiceInstance> services,
  ) {
    final next = <AiTaskRouteBinding>[];
    final seenRoutes = <AiTaskRouteId>{};
    for (final binding in bindings) {
      if (!seenRoutes.add(binding.routeId)) continue;
      final service = services.firstById(binding.serviceId);
      final model = service?.models.firstById(binding.modelId);
      if (service == null || model == null) continue;
      if (!model.capabilities.contains(binding.capability)) continue;
      next.add(
        binding.copyWith(
          serviceId: binding.serviceId.trim(),
          modelId: binding.modelId.trim(),
        ),
      );
    }
    return List<AiTaskRouteBinding>.unmodifiable(next);
  }

  static List<AiServiceInstance> _migrateLegacyServices(AiSettings source) {
    final next = <AiServiceInstance>[];
    for (final profile in source.generationProfiles) {
      final serviceId = _legacyGenerationServiceId(profile.profileKey);
      final adapterKind = inferAdapterKind(
        baseUrl: profile.baseUrl,
        model: profile.model,
        providerKind: profile.providerKind,
      );
      final template = matchTemplateForBaseUrl(
        adapterKind: adapterKind,
        baseUrl: profile.baseUrl,
      );
      final modelOptions = _normalizeModelKeys([
        profile.model,
        ...profile.modelOptions,
      ]);
      next.add(
        AiServiceInstance(
          serviceId: serviceId,
          templateId: template.templateId,
          adapterKind: adapterKind,
          displayName: profile.displayName.trim().isEmpty
              ? 'Imported Generation'
              : profile.displayName.trim(),
          enabled: profile.enabled,
          baseUrl: profile.baseUrl.trim(),
          apiKey: profile.apiKey.trim(),
          customHeaders: const <String, String>{},
          models: List<AiModelEntry>.unmodifiable(
            modelOptions
                .map(
                  (modelKey) => AiModelEntry(
                    modelId: _legacyModelId(serviceId, modelKey),
                    displayName: modelKey,
                    modelKey: modelKey,
                    capabilities: const <AiCapability>[AiCapability.chat],
                    source: AiModelSource.migrated,
                    enabled: true,
                  ),
                )
                .toList(growable: false),
          ),
          lastValidatedAt: null,
          lastValidationStatus: AiValidationStatus.unknown,
          lastValidationMessage: null,
        ),
      );
    }
    for (final profile in source.embeddingProfiles) {
      final serviceId = _legacyEmbeddingServiceId(profile.profileKey);
      final adapterKind = inferAdapterKind(
        baseUrl: profile.baseUrl,
        model: profile.model,
        providerKind: profile.providerKind,
      );
      final template = matchTemplateForBaseUrl(
        adapterKind: adapterKind,
        baseUrl: profile.baseUrl,
      );
      final modelKey = profile.model.trim();
      next.add(
        AiServiceInstance(
          serviceId: serviceId,
          templateId: template.templateId,
          adapterKind: adapterKind,
          displayName: profile.displayName.trim().isEmpty
              ? 'Imported Embedding'
              : profile.displayName.trim(),
          enabled: profile.enabled,
          baseUrl: profile.baseUrl.trim(),
          apiKey: profile.apiKey.trim(),
          customHeaders: const <String, String>{},
          models: modelKey.isEmpty
              ? const <AiModelEntry>[]
              : <AiModelEntry>[
                  AiModelEntry(
                    modelId: _legacyModelId(serviceId, modelKey),
                    displayName: modelKey,
                    modelKey: modelKey,
                    capabilities: const <AiCapability>[AiCapability.embedding],
                    source: AiModelSource.migrated,
                    enabled: true,
                  ),
                ],
          lastValidatedAt: null,
          lastValidationStatus: AiValidationStatus.unknown,
          lastValidationMessage: null,
        ),
      );
    }
    return _normalizeServices(next);
  }

  static List<AiTaskRouteBinding> _migrateLegacyBindings(
    AiSettings source,
    List<AiServiceInstance> services,
  ) {
    final next = <AiTaskRouteBinding>[];
    final generationProfile = source.selectedGenerationProfile;
    if (generationProfile.profileKey.trim().isNotEmpty) {
      final serviceId = _legacyGenerationServiceId(
        generationProfile.profileKey,
      );
      final modelId = _legacyModelId(serviceId, generationProfile.model);
      next.add(
        AiTaskRouteBinding(
          routeId: AiTaskRouteId.summary,
          serviceId: serviceId,
          modelId: modelId,
          capability: AiCapability.chat,
        ),
      );
      next.add(
        AiTaskRouteBinding(
          routeId: AiTaskRouteId.analysisReport,
          serviceId: serviceId,
          modelId: modelId,
          capability: AiCapability.chat,
        ),
      );
      next.add(
        AiTaskRouteBinding(
          routeId: AiTaskRouteId.quickPrompt,
          serviceId: serviceId,
          modelId: modelId,
          capability: AiCapability.chat,
        ),
      );
    }

    final embeddingProfile = source.selectedEmbeddingProfile;
    if (embeddingProfile != null &&
        embeddingProfile.profileKey.trim().isNotEmpty) {
      final serviceId = _legacyEmbeddingServiceId(embeddingProfile.profileKey);
      final modelId = _legacyModelId(serviceId, embeddingProfile.model);
      next.add(
        AiTaskRouteBinding(
          routeId: AiTaskRouteId.embeddingRetrieval,
          serviceId: serviceId,
          modelId: modelId,
          capability: AiCapability.embedding,
        ),
      );
    }
    return _normalizeBindings(next, services);
  }

  static _ShadowProfiles _buildShadowProfiles({
    required List<AiServiceInstance> services,
    required List<AiTaskRouteBinding> bindings,
  }) {
    final generationProfiles = <AiGenerationProfile>[];
    for (final service in services) {
      final chatModels = service.models
          .where((model) => model.capabilities.contains(AiCapability.chat))
          .toList(growable: false);
      final modelOptions = chatModels
          .map((model) => model.modelKey.trim())
          .where((modelKey) => modelKey.isNotEmpty)
          .toList(growable: false);
      for (final model in chatModels) {
        generationProfiles.add(
          AiGenerationProfile(
            profileKey: _shadowProfileKey(service.serviceId, model.modelId),
            displayName: '${service.displayName} · ${model.displayName}',
            backendKind: inferBackendKindFromBaseUrl(service.baseUrl),
            providerKind: _providerKindFromAdapter(service.adapterKind),
            baseUrl: service.baseUrl,
            apiKey: service.apiKey,
            model: model.modelKey,
            modelOptions: modelOptions,
            enabled: service.enabled && model.enabled,
          ),
        );
      }
    }

    final embeddingProfiles = <AiEmbeddingProfile>[];
    for (final service in services) {
      for (final model in service.models.where(
        (model) => model.capabilities.contains(AiCapability.embedding),
      )) {
        embeddingProfiles.add(
          AiEmbeddingProfile(
            profileKey: _shadowProfileKey(service.serviceId, model.modelId),
            displayName: '${service.displayName} · ${model.displayName}',
            backendKind: inferBackendKindFromBaseUrl(service.baseUrl),
            providerKind: _providerKindFromAdapter(service.adapterKind),
            baseUrl: service.baseUrl,
            apiKey: service.apiKey,
            model: model.modelKey,
            enabled: service.enabled && model.enabled,
          ),
        );
      }
    }

    final resolvedSummary = AiRouteResolver.resolveTaskRoute(
      services: services,
      bindings: bindings,
      routeId: AiTaskRouteId.summary,
      capability: AiCapability.chat,
    );
    final resolvedEmbedding = AiRouteResolver.resolveTaskRoute(
      services: services,
      bindings: bindings,
      routeId: AiTaskRouteId.embeddingRetrieval,
      capability: AiCapability.embedding,
    );

    _promoteSelectedGeneration(generationProfiles, resolvedSummary);
    _promoteSelectedEmbedding(embeddingProfiles, resolvedEmbedding);

    return _ShadowProfiles(
      generationProfiles: List<AiGenerationProfile>.unmodifiable(
        generationProfiles,
      ),
      selectedGenerationProfileKey: resolvedSummary == null
          ? ''
          : _shadowProfileKey(
              resolvedSummary.service.serviceId,
              resolvedSummary.model.modelId,
            ),
      embeddingProfiles: List<AiEmbeddingProfile>.unmodifiable(
        embeddingProfiles,
      ),
      selectedEmbeddingProfileKey: resolvedEmbedding == null
          ? null
          : _shadowProfileKey(
              resolvedEmbedding.service.serviceId,
              resolvedEmbedding.model.modelId,
            ),
    );
  }

  static void _promoteSelectedGeneration(
    List<AiGenerationProfile> profiles,
    AiResolvedTaskRoute? resolved,
  ) {
    if (resolved == null) return;
    final selectedKey = _shadowProfileKey(
      resolved.service.serviceId,
      resolved.model.modelId,
    );
    final index = profiles.indexWhere(
      (profile) => profile.profileKey == selectedKey,
    );
    if (index <= 0) return;
    final selected = profiles.removeAt(index);
    profiles.insert(0, selected);
  }

  static void _promoteSelectedEmbedding(
    List<AiEmbeddingProfile> profiles,
    AiResolvedTaskRoute? resolved,
  ) {
    if (resolved == null) return;
    final selectedKey = _shadowProfileKey(
      resolved.service.serviceId,
      resolved.model.modelId,
    );
    final index = profiles.indexWhere(
      (profile) => profile.profileKey == selectedKey,
    );
    if (index <= 0) return;
    final selected = profiles.removeAt(index);
    profiles.insert(0, selected);
  }

  static String _fallbackServiceName(String templateId) {
    return findAiProviderTemplate(templateId)?.displayName ?? 'AI Service';
  }

  static String _legacyGenerationServiceId(String profileKey) =>
      'svc_legacy_gen_${_sanitizeIdSegment(profileKey)}';

  static String _legacyEmbeddingServiceId(String profileKey) =>
      'svc_legacy_embed_${_sanitizeIdSegment(profileKey)}';

  static String _legacyModelId(String serviceId, String modelKey) =>
      'mdl_${_sanitizeIdSegment(serviceId)}_${_sanitizeIdSegment(modelKey)}';

  static String shadowProfileKey(String serviceId, String modelId) =>
      _shadowProfileKey(serviceId, modelId);

  static String _shadowProfileKey(String serviceId, String modelId) =>
      'shadow_${_sanitizeIdSegment(serviceId)}_${_sanitizeIdSegment(modelId)}';

  static String _sanitizeIdSegment(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  static List<String> _normalizeModelKeys(Iterable<String> values) {
    final seen = <String>{};
    final next = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (!seen.add(normalized)) continue;
      next.add(trimmed);
    }
    return List<String>.unmodifiable(next);
  }

  static AiProviderKind _providerKindFromAdapter(
    AiProviderAdapterKind adapterKind,
  ) {
    return switch (adapterKind) {
      AiProviderAdapterKind.anthropic => AiProviderKind.anthropicCompatible,
      _ => AiProviderKind.openAiCompatible,
    };
  }

  static AiProxySettings _normalizeProxySettings(AiProxySettings settings) {
    final normalizedPort = settings.port > 0 && settings.port <= 65535
        ? settings.port
        : 0;
    return settings.copyWith(
      host: settings.host.trim(),
      port: normalizedPort,
      username: settings.username.trim(),
      password: settings.password.trim(),
    );
  }
}

class _ShadowProfiles {
  const _ShadowProfiles({
    required this.generationProfiles,
    required this.selectedGenerationProfileKey,
    required this.embeddingProfiles,
    required this.selectedEmbeddingProfileKey,
  });

  final List<AiGenerationProfile> generationProfiles;
  final String selectedGenerationProfileKey;
  final List<AiEmbeddingProfile> embeddingProfiles;
  final String? selectedEmbeddingProfileKey;
}
