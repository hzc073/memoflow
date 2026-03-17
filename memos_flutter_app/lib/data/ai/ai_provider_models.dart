import 'dart:collection';

enum AiProviderAdapterKind {
  openAiCompatible,
  anthropic,
  gemini,
  azureOpenAi,
  ollama,
}

enum AiCapability { chat, embedding, vision }

enum AiProviderTemplateGroup { cloud, local, custom }

enum AiModelSource { migrated, manual, discovered }

enum AiValidationStatus { unknown, success, failed }

enum AiTaskRouteId {
  summary,
  analysisReport,
  quickPrompt,
  embeddingRetrieval,
}

String _adapterKindToStorage(AiProviderAdapterKind value) => switch (value) {
  AiProviderAdapterKind.openAiCompatible => 'openai_compatible',
  AiProviderAdapterKind.anthropic => 'anthropic',
  AiProviderAdapterKind.gemini => 'gemini',
  AiProviderAdapterKind.azureOpenAi => 'azure_openai',
  AiProviderAdapterKind.ollama => 'ollama',
};

AiProviderAdapterKind _adapterKindFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'anthropic' => AiProviderAdapterKind.anthropic,
    'gemini' => AiProviderAdapterKind.gemini,
    'azure_openai' => AiProviderAdapterKind.azureOpenAi,
    'ollama' => AiProviderAdapterKind.ollama,
    _ => AiProviderAdapterKind.openAiCompatible,
  };
}

String _capabilityToStorage(AiCapability value) => switch (value) {
  AiCapability.chat => 'chat',
  AiCapability.embedding => 'embedding',
  AiCapability.vision => 'vision',
};

AiCapability _capabilityFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'embedding' => AiCapability.embedding,
    'vision' => AiCapability.vision,
    _ => AiCapability.chat,
  };
}

String _templateGroupToStorage(AiProviderTemplateGroup value) => switch (value) {
  AiProviderTemplateGroup.cloud => 'cloud',
  AiProviderTemplateGroup.local => 'local',
  AiProviderTemplateGroup.custom => 'custom',
};

AiProviderTemplateGroup _templateGroupFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'local' => AiProviderTemplateGroup.local,
    'custom' => AiProviderTemplateGroup.custom,
    _ => AiProviderTemplateGroup.cloud,
  };
}

String _modelSourceToStorage(AiModelSource value) => switch (value) {
  AiModelSource.migrated => 'migrated',
  AiModelSource.manual => 'manual',
  AiModelSource.discovered => 'discovered',
};

AiModelSource _modelSourceFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'manual' => AiModelSource.manual,
    'discovered' => AiModelSource.discovered,
    _ => AiModelSource.migrated,
  };
}

String _validationStatusToStorage(AiValidationStatus value) => switch (value) {
  AiValidationStatus.unknown => 'unknown',
  AiValidationStatus.success => 'success',
  AiValidationStatus.failed => 'failed',
};

AiValidationStatus _validationStatusFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'success' => AiValidationStatus.success,
    'failed' => AiValidationStatus.failed,
    _ => AiValidationStatus.unknown,
  };
}

String _taskRouteIdToStorage(AiTaskRouteId value) => switch (value) {
  AiTaskRouteId.summary => 'summary',
  AiTaskRouteId.analysisReport => 'analysis_report',
  AiTaskRouteId.quickPrompt => 'quick_prompt',
  AiTaskRouteId.embeddingRetrieval => 'embedding_retrieval',
};

AiTaskRouteId _taskRouteIdFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'analysis_report' => AiTaskRouteId.analysisReport,
    'quick_prompt' => AiTaskRouteId.quickPrompt,
    'embedding_retrieval' => AiTaskRouteId.embeddingRetrieval,
    _ => AiTaskRouteId.summary,
  };
}

class AiProviderTemplate {
  const AiProviderTemplate({
    required this.templateId,
    required this.displayName,
    required this.group,
    required this.adapterKind,
    required this.defaultBaseUrl,
    required this.defaultHeaders,
    required this.supportsModelDiscovery,
    required this.requiresApiKey,
    required this.supportedCapabilities,
    required this.docsUrl,
    this.logoAsset,
  });

  final String templateId;
  final String displayName;
  final AiProviderTemplateGroup group;
  final AiProviderAdapterKind adapterKind;
  final String defaultBaseUrl;
  final Map<String, String> defaultHeaders;
  final bool supportsModelDiscovery;
  final bool requiresApiKey;
  final List<AiCapability> supportedCapabilities;
  final String docsUrl;
  final String? logoAsset;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'templateId': templateId,
    'displayName': displayName,
    'group': _templateGroupToStorage(group),
    'adapterKind': _adapterKindToStorage(adapterKind),
    'defaultBaseUrl': defaultBaseUrl,
    'defaultHeaders': defaultHeaders,
    'supportsModelDiscovery': supportsModelDiscovery,
    'requiresApiKey': requiresApiKey,
    'supportedCapabilities': supportedCapabilities
        .map(_capabilityToStorage)
        .toList(growable: false),
    'docsUrl': docsUrl,
    'logoAsset': logoAsset,
  };

  factory AiProviderTemplate.fromJson(Map<String, dynamic> json) {
    List<AiCapability> readCapabilities(String key) {
      final raw = json[key];
      if (raw is! List) return const <AiCapability>[];
      return List<AiCapability>.unmodifiable(
        raw.whereType<String>().map(_capabilityFromStorage),
      );
    }

    Map<String, String> readHeaders(String key) {
      final raw = json[key];
      if (raw is! Map) return const <String, String>{};
      final next = <String, String>{};
      raw.forEach((headerKey, headerValue) {
        final normalizedKey = headerKey.toString().trim();
        final normalizedValue = headerValue?.toString().trim() ?? '';
        if (normalizedKey.isEmpty || normalizedValue.isEmpty) return;
        next[normalizedKey] = normalizedValue;
      });
      return Map<String, String>.unmodifiable(next);
    }

    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    return AiProviderTemplate(
      templateId: readString('templateId', ''),
      displayName: readString('displayName', ''),
      group: _templateGroupFromStorage(readString('group', 'cloud')),
      adapterKind: _adapterKindFromStorage(
        readString('adapterKind', 'openai_compatible'),
      ),
      defaultBaseUrl: readString('defaultBaseUrl', ''),
      defaultHeaders: readHeaders('defaultHeaders'),
      supportsModelDiscovery: readBool('supportsModelDiscovery', false),
      requiresApiKey: readBool('requiresApiKey', true),
      supportedCapabilities: readCapabilities('supportedCapabilities'),
      docsUrl: readString('docsUrl', ''),
      logoAsset: readString('logoAsset', ''),
    );
  }
}

class AiModelEntry {
  const AiModelEntry({
    required this.modelId,
    required this.displayName,
    required this.modelKey,
    required this.capabilities,
    required this.source,
    required this.enabled,
  });

  final String modelId;
  final String displayName;
  final String modelKey;
  final List<AiCapability> capabilities;
  final AiModelSource source;
  final bool enabled;

  bool supports(AiCapability capability) {
    return capabilities.contains(capability);
  }

  AiModelEntry copyWith({
    String? modelId,
    String? displayName,
    String? modelKey,
    List<AiCapability>? capabilities,
    AiModelSource? source,
    bool? enabled,
  }) {
    return AiModelEntry(
      modelId: modelId ?? this.modelId,
      displayName: displayName ?? this.displayName,
      modelKey: modelKey ?? this.modelKey,
      capabilities: capabilities ?? this.capabilities,
      source: source ?? this.source,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'modelId': modelId,
    'displayName': displayName,
    'modelKey': modelKey,
    'capabilities': capabilities
        .map(_capabilityToStorage)
        .toList(growable: false),
    'source': _modelSourceToStorage(source),
    'enabled': enabled,
  };

  factory AiModelEntry.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    final rawCapabilities = json['capabilities'];
    final capabilities = rawCapabilities is List
        ? rawCapabilities
              .whereType<String>()
              .map(_capabilityFromStorage)
              .toList(growable: false)
        : const <AiCapability>[AiCapability.chat];

    return AiModelEntry(
      modelId: readString('modelId', ''),
      displayName: readString('displayName', ''),
      modelKey: readString('modelKey', ''),
      capabilities: List<AiCapability>.unmodifiable(capabilities),
      source: _modelSourceFromStorage(readString('source', 'migrated')),
      enabled: readBool('enabled', true),
    );
  }
}

class AiServiceInstance {
  const AiServiceInstance({
    required this.serviceId,
    required this.templateId,
    required this.adapterKind,
    required this.displayName,
    required this.enabled,
    this.usesSharedProxy = false,
    required this.baseUrl,
    required this.apiKey,
    required this.customHeaders,
    required this.models,
    required this.lastValidatedAt,
    required this.lastValidationStatus,
    required this.lastValidationMessage,
  });

  final String serviceId;
  final String templateId;
  final AiProviderAdapterKind adapterKind;
  final String displayName;
  final bool enabled;
  final bool usesSharedProxy;
  final String baseUrl;
  final String apiKey;
  final Map<String, String> customHeaders;
  final List<AiModelEntry> models;
  final DateTime? lastValidatedAt;
  final AiValidationStatus lastValidationStatus;
  final String? lastValidationMessage;

  Iterable<AiModelEntry> enabledModelsFor(AiCapability capability) sync* {
    for (final model in models) {
      if (model.enabled && model.supports(capability)) {
        yield model;
      }
    }
  }

  bool supports(AiCapability capability) {
    return models.any((model) => model.enabled && model.supports(capability));
  }

  AiServiceInstance copyWith({
    String? serviceId,
    String? templateId,
    AiProviderAdapterKind? adapterKind,
    String? displayName,
    bool? enabled,
    bool? usesSharedProxy,
    String? baseUrl,
    String? apiKey,
    Map<String, String>? customHeaders,
    List<AiModelEntry>? models,
    Object? lastValidatedAt = _unset,
    AiValidationStatus? lastValidationStatus,
    Object? lastValidationMessage = _unset,
  }) {
    return AiServiceInstance(
      serviceId: serviceId ?? this.serviceId,
      templateId: templateId ?? this.templateId,
      adapterKind: adapterKind ?? this.adapterKind,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      usesSharedProxy: usesSharedProxy ?? this.usesSharedProxy,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      customHeaders: customHeaders ?? this.customHeaders,
      models: models ?? this.models,
      lastValidatedAt: identical(lastValidatedAt, _unset)
          ? this.lastValidatedAt
          : lastValidatedAt as DateTime?,
      lastValidationStatus:
          lastValidationStatus ?? this.lastValidationStatus,
      lastValidationMessage: identical(lastValidationMessage, _unset)
          ? this.lastValidationMessage
          : lastValidationMessage as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'serviceId': serviceId,
    'templateId': templateId,
    'adapterKind': _adapterKindToStorage(adapterKind),
    'displayName': displayName,
    'enabled': enabled,
    'usesSharedProxy': usesSharedProxy,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'customHeaders': customHeaders,
    'models': models.map((model) => model.toJson()).toList(growable: false),
    'lastValidatedAt': lastValidatedAt?.toIso8601String(),
    'lastValidationStatus': _validationStatusToStorage(lastValidationStatus),
    'lastValidationMessage': lastValidationMessage,
  };

  factory AiServiceInstance.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    Map<String, String> readHeaders() {
      final raw = json['customHeaders'];
      if (raw is! Map) return const <String, String>{};
      final headers = <String, String>{};
      raw.forEach((headerKey, headerValue) {
        final normalizedKey = headerKey.toString().trim();
        final normalizedValue = headerValue?.toString().trim() ?? '';
        if (normalizedKey.isEmpty || normalizedValue.isEmpty) return;
        headers[normalizedKey] = normalizedValue;
      });
      return Map<String, String>.unmodifiable(headers);
    }

    DateTime? readDateTime(String key) {
      final raw = json[key];
      if (raw is! String || raw.trim().isEmpty) return null;
      return DateTime.tryParse(raw.trim());
    }

    final rawModels = json['models'];
    final models = rawModels is List
        ? rawModels
              .whereType<Map>()
              .map((item) => AiModelEntry.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false)
        : const <AiModelEntry>[];

    return AiServiceInstance(
      serviceId: readString('serviceId', ''),
      templateId: readString('templateId', ''),
      adapterKind: _adapterKindFromStorage(
        readString('adapterKind', 'openai_compatible'),
      ),
      displayName: readString('displayName', ''),
      enabled: readBool('enabled', true),
      usesSharedProxy: readBool('usesSharedProxy', false),
      baseUrl: readString('baseUrl', ''),
      apiKey: readString('apiKey', ''),
      customHeaders: readHeaders(),
      models: List<AiModelEntry>.unmodifiable(models),
      lastValidatedAt: readDateTime('lastValidatedAt'),
      lastValidationStatus: _validationStatusFromStorage(
        readString('lastValidationStatus', 'unknown'),
      ),
      lastValidationMessage: (json['lastValidationMessage'] as String?)?.trim(),
    );
  }
}

class AiTaskRouteBinding {
  const AiTaskRouteBinding({
    required this.routeId,
    required this.serviceId,
    required this.modelId,
    required this.capability,
  });

  final AiTaskRouteId routeId;
  final String serviceId;
  final String modelId;
  final AiCapability capability;

  AiTaskRouteBinding copyWith({
    AiTaskRouteId? routeId,
    String? serviceId,
    String? modelId,
    AiCapability? capability,
  }) {
    return AiTaskRouteBinding(
      routeId: routeId ?? this.routeId,
      serviceId: serviceId ?? this.serviceId,
      modelId: modelId ?? this.modelId,
      capability: capability ?? this.capability,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'routeId': _taskRouteIdToStorage(routeId),
    'serviceId': serviceId,
    'modelId': modelId,
    'capability': _capabilityToStorage(capability),
  };

  factory AiTaskRouteBinding.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    return AiTaskRouteBinding(
      routeId: _taskRouteIdFromStorage(readString('routeId', 'summary')),
      serviceId: readString('serviceId', ''),
      modelId: readString('modelId', ''),
      capability: _capabilityFromStorage(readString('capability', 'chat')),
    );
  }
}

extension AiServiceListExtension on Iterable<AiServiceInstance> {
  AiServiceInstance? firstById(String serviceId) {
    final normalized = serviceId.trim();
    if (normalized.isEmpty) return null;
    for (final service in this) {
      if (service.serviceId.trim() == normalized) return service;
    }
    return null;
  }
}

extension AiModelListExtension on Iterable<AiModelEntry> {
  AiModelEntry? firstById(String modelId) {
    final normalized = modelId.trim();
    if (normalized.isEmpty) return null;
    for (final model in this) {
      if (model.modelId.trim() == normalized) return model;
    }
    return null;
  }
}

extension AiStringMapExtension on Map<String, String> {
  Map<String, String> get unmodifiable {
    return UnmodifiableMapView<String, String>(this);
  }
}

const Object _unset = Object();
