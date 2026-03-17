import '../../core/app_localization.dart';
import '../models/app_preferences.dart';
import 'ai_provider_models.dart';

enum AiBackendKind { remoteApi, localApi }

enum AiProviderKind { openAiCompatible, anthropicCompatible }

enum AiProxyProtocol { http, socks5 }

String _backendKindToStorage(AiBackendKind value) => switch (value) {
  AiBackendKind.remoteApi => 'remote_api',
  AiBackendKind.localApi => 'local_api',
};

AiBackendKind _backendKindFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'local_api' => AiBackendKind.localApi,
    _ => AiBackendKind.remoteApi,
  };
}

String _providerKindToStorage(AiProviderKind value) => switch (value) {
  AiProviderKind.openAiCompatible => 'openai_compatible',
  AiProviderKind.anthropicCompatible => 'anthropic_compatible',
};

AiProviderKind _providerKindFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'anthropic_compatible' => AiProviderKind.anthropicCompatible,
    _ => AiProviderKind.openAiCompatible,
  };
}

String _proxyProtocolToStorage(AiProxyProtocol value) => switch (value) {
  AiProxyProtocol.http => 'http',
  AiProxyProtocol.socks5 => 'socks5',
};

AiProxyProtocol _proxyProtocolFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'socks5' => AiProxyProtocol.socks5,
    _ => AiProxyProtocol.http,
  };
}

AiBackendKind inferBackendKindFromBaseUrl(String baseUrl) {
  final trimmed = baseUrl.trim().toLowerCase();
  if (trimmed.isEmpty) return AiBackendKind.remoteApi;
  final uri = Uri.tryParse(trimmed);
  final host = uri?.host.toLowerCase() ?? '';
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return AiBackendKind.localApi;
  }
  if (host.startsWith('192.168.') ||
      host.startsWith('10.') ||
      host.startsWith('172.16.') ||
      host.startsWith('172.17.') ||
      host.startsWith('172.18.') ||
      host.startsWith('172.19.') ||
      host.startsWith('172.2')) {
    return AiBackendKind.localApi;
  }
  return AiBackendKind.remoteApi;
}

AiProviderKind inferGenerationProviderKind({
  required String baseUrl,
  required String model,
}) {
  final normalizedUrl = baseUrl.trim().toLowerCase();
  final normalizedModel = model.trim().toLowerCase();
  if (normalizedUrl.contains('anthropic') ||
      normalizedModel.contains('claude')) {
    return AiProviderKind.anthropicCompatible;
  }
  return AiProviderKind.openAiCompatible;
}

AiProviderAdapterKind inferAdapterKind({
  required String baseUrl,
  required String model,
  required AiProviderKind providerKind,
}) {
  if (providerKind == AiProviderKind.anthropicCompatible) {
    return AiProviderAdapterKind.anthropic;
  }
  final normalizedBase = baseUrl.trim().toLowerCase();
  final normalizedModel = model.trim().toLowerCase();
  if (normalizedBase.contains('googleapis') ||
      normalizedModel.contains('gemini')) {
    return AiProviderAdapterKind.gemini;
  }
  if (normalizedBase.contains('azure')) {
    return AiProviderAdapterKind.azureOpenAi;
  }
  if (normalizedBase.contains('ollama') || normalizedBase.contains(':11434')) {
    return AiProviderAdapterKind.ollama;
  }
  return AiProviderAdapterKind.openAiCompatible;
}

class AiProxySettings {
  const AiProxySettings({
    this.protocol = AiProxyProtocol.http,
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
    this.bypassLocalAddresses = true,
  });

  static const defaults = AiProxySettings();

  final AiProxyProtocol protocol;
  final String host;
  final int port;
  final String username;
  final String password;
  final bool bypassLocalAddresses;

  bool get isEmpty =>
      host.trim().isEmpty &&
      port <= 0 &&
      username.trim().isEmpty &&
      password.trim().isEmpty;

  bool get isConfigured => host.trim().isNotEmpty && port > 0 && port <= 65535;

  AiProxySettings copyWith({
    AiProxyProtocol? protocol,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? bypassLocalAddresses,
  }) {
    return AiProxySettings(
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      bypassLocalAddresses:
          bypassLocalAddresses ?? this.bypassLocalAddresses,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'protocol': _proxyProtocolToStorage(protocol),
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'bypassLocalAddresses': bypassLocalAddresses,
  };

  factory AiProxySettings.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    return AiProxySettings(
      protocol: _proxyProtocolFromStorage(readString('protocol', 'http')),
      host: readString('host', ''),
      port: readInt('port', 0),
      username: readString('username', ''),
      password: readString('password', ''),
      bypassLocalAddresses: readBool('bypassLocalAddresses', true),
    );
  }
}

class AiQuickPrompt {
  const AiQuickPrompt({
    required this.title,
    required this.content,
    required this.iconKey,
  });

  static const defaultIconKey = 'sparkle';

  final String title;
  final String content;
  final String iconKey;

  AiQuickPrompt copyWith({String? title, String? content, String? iconKey}) {
    return AiQuickPrompt(
      title: title ?? this.title,
      content: content ?? this.content,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'iconKey': iconKey,
  };

  factory AiQuickPrompt.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    final title = readString('title', '');
    final content = readString('content', title);
    final iconKey = readString('iconKey', defaultIconKey);
    return AiQuickPrompt(title: title, content: content, iconKey: iconKey);
  }

  static AiQuickPrompt fromLegacy(String raw) {
    final trimmed = raw.trim();
    return AiQuickPrompt(
      title: trimmed,
      content: trimmed,
      iconKey: defaultIconKey,
    );
  }
}

class AiCustomInsightTemplate {
  const AiCustomInsightTemplate({
    this.title = '',
    this.description = '',
    this.promptTemplate = '',
    this.iconKey = AiQuickPrompt.defaultIconKey,
  });

  final String title;
  final String description;
  final String promptTemplate;
  final String iconKey;

  bool get isConfigured =>
      title.trim().isNotEmpty &&
      description.trim().isNotEmpty &&
      promptTemplate.trim().isNotEmpty;

  AiCustomInsightTemplate copyWith({
    String? title,
    String? description,
    String? promptTemplate,
    String? iconKey,
  }) {
    return AiCustomInsightTemplate(
      title: title ?? this.title,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'promptTemplate': promptTemplate,
    'iconKey': iconKey,
  };

  factory AiCustomInsightTemplate.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    return AiCustomInsightTemplate(
      title: readString('title', ''),
      description: readString('description', ''),
      promptTemplate: readString('promptTemplate', ''),
      iconKey: readString('iconKey', AiQuickPrompt.defaultIconKey),
    );
  }
}

class AiGenerationProfile {
  const AiGenerationProfile({
    required this.profileKey,
    required this.displayName,
    required this.backendKind,
    required this.providerKind,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.modelOptions,
    required this.enabled,
  });

  static const unconfigured = AiGenerationProfile(
    profileKey: '',
    displayName: 'Unconfigured Generation',
    backendKind: AiBackendKind.remoteApi,
    providerKind: AiProviderKind.openAiCompatible,
    baseUrl: '',
    apiKey: '',
    model: '',
    modelOptions: <String>[],
    enabled: false,
  );

  final String profileKey;
  final String displayName;
  final AiBackendKind backendKind;
  final AiProviderKind providerKind;
  final String baseUrl;
  final String apiKey;
  final String model;
  final List<String> modelOptions;
  final bool enabled;

  AiGenerationProfile copyWith({
    String? profileKey,
    String? displayName,
    AiBackendKind? backendKind,
    AiProviderKind? providerKind,
    String? baseUrl,
    String? apiKey,
    String? model,
    List<String>? modelOptions,
    bool? enabled,
  }) {
    return AiGenerationProfile(
      profileKey: profileKey ?? this.profileKey,
      displayName: displayName ?? this.displayName,
      backendKind: backendKind ?? this.backendKind,
      providerKind: providerKind ?? this.providerKind,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      modelOptions: modelOptions ?? this.modelOptions,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'profileKey': profileKey,
    'displayName': displayName,
    'backendKind': _backendKindToStorage(backendKind),
    'providerKind': _providerKindToStorage(providerKind),
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'modelOptions': modelOptions,
    'enabled': enabled,
  };

  factory AiGenerationProfile.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    List<String> readModelOptions(String key, List<String> fallback) {
      final raw = json[key];
      if (raw is! List) return fallback;
      final seen = <String>{};
      final options = <String>[];
      for (final item in raw) {
        if (item is! String) continue;
        final trimmed = item.trim();
        if (trimmed.isEmpty) continue;
        if (seen.add(trimmed.toLowerCase())) {
          options.add(trimmed);
        }
      }
      return options.isEmpty ? fallback : List.unmodifiable(options);
    }

    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }

    final baseUrl = readString('baseUrl', '');
    final model = readString('model', '');
    return AiGenerationProfile(
      profileKey: readString('profileKey', 'default_generation'),
      displayName: readString('displayName', 'Default Generation'),
      backendKind: _backendKindFromStorage(
        readString(
          'backendKind',
          _backendKindToStorage(inferBackendKindFromBaseUrl(baseUrl)),
        ),
      ),
      providerKind: _providerKindFromStorage(
        readString(
          'providerKind',
          _providerKindToStorage(
            inferGenerationProviderKind(baseUrl: baseUrl, model: model),
          ),
        ),
      ),
      baseUrl: baseUrl,
      apiKey: readString('apiKey', ''),
      model: model,
      modelOptions: readModelOptions('modelOptions', const <String>[]),
      enabled: readBool('enabled', true),
    );
  }
}

class AiEmbeddingProfile {
  const AiEmbeddingProfile({
    required this.profileKey,
    required this.displayName,
    required this.backendKind,
    required this.providerKind,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.enabled,
  });

  final String profileKey;
  final String displayName;
  final AiBackendKind backendKind;
  final AiProviderKind providerKind;
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool enabled;

  AiEmbeddingProfile copyWith({
    String? profileKey,
    String? displayName,
    AiBackendKind? backendKind,
    AiProviderKind? providerKind,
    String? baseUrl,
    String? apiKey,
    String? model,
    bool? enabled,
  }) {
    return AiEmbeddingProfile(
      profileKey: profileKey ?? this.profileKey,
      displayName: displayName ?? this.displayName,
      backendKind: backendKind ?? this.backendKind,
      providerKind: providerKind ?? this.providerKind,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'profileKey': profileKey,
    'displayName': displayName,
    'backendKind': _backendKindToStorage(backendKind),
    'providerKind': _providerKindToStorage(providerKind),
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'enabled': enabled,
  };

  factory AiEmbeddingProfile.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }

    final baseUrl = readString('baseUrl', '');
    return AiEmbeddingProfile(
      profileKey: readString('profileKey', 'default_embedding'),
      displayName: readString('displayName', 'Default Embedding'),
      backendKind: _backendKindFromStorage(
        readString(
          'backendKind',
          _backendKindToStorage(inferBackendKindFromBaseUrl(baseUrl)),
        ),
      ),
      providerKind: _providerKindFromStorage(
        readString(
          'providerKind',
          _providerKindToStorage(AiProviderKind.openAiCompatible),
        ),
      ),
      baseUrl: baseUrl,
      apiKey: readString('apiKey', ''),
      model: readString('model', ''),
      enabled: readBool('enabled', true),
    );
  }
}

class AiSettings {
  static const int currentSchemaVersion = 4;

  static const defaultModelOptions = <String>[
    'deepseek-chat',
    'Claude 3.5 Sonnet',
    'Claude 3.5 Haiku',
    'Claude 3 Opus',
    'GPT-4o mini',
    'GPT-4o',
  ];

  static AiSettings defaultsFor(AppLanguage language) {
    return AiSettings(
      schemaVersion: currentSchemaVersion,
      services: const <AiServiceInstance>[],
      taskRouteBindings: const <AiTaskRouteBinding>[],
      generationProfiles: const <AiGenerationProfile>[],
      selectedGenerationProfileKey: '',
      embeddingProfiles: const <AiEmbeddingProfile>[],
      selectedEmbeddingProfileKey: null,
      prompt: trByLanguageKey(
        language: language,
        key: 'legacy.ai_summary.default_prompt',
      ),
      userProfile: '',
      proxySettings: AiProxySettings.defaults,
      quickPrompts: const <AiQuickPrompt>[],
      analysisPromptTemplates: const <String, String>{},
    );
  }

  static final defaults = defaultsFor(AppLanguage.en);

  const AiSettings({
    required this.schemaVersion,
    required this.services,
    required this.taskRouteBindings,
    required this.generationProfiles,
    required this.selectedGenerationProfileKey,
    required this.embeddingProfiles,
    required this.selectedEmbeddingProfileKey,
    required this.prompt,
    required this.userProfile,
    this.proxySettings = AiProxySettings.defaults,
    required this.quickPrompts,
    required this.analysisPromptTemplates,
    this.customInsightTemplate = const AiCustomInsightTemplate(),
  });

  final int schemaVersion;
  final List<AiServiceInstance> services;
  final List<AiTaskRouteBinding> taskRouteBindings;
  final List<AiGenerationProfile> generationProfiles;
  final String selectedGenerationProfileKey;
  final List<AiEmbeddingProfile> embeddingProfiles;
  final String? selectedEmbeddingProfileKey;
  final String prompt;
  final String userProfile;
  final AiProxySettings proxySettings;
  final List<AiQuickPrompt> quickPrompts;
  final Map<String, String> analysisPromptTemplates;
  final AiCustomInsightTemplate customInsightTemplate;

  AiGenerationProfile get selectedGenerationProfile {
    final normalized = selectedGenerationProfileKey.trim();
    if (normalized.isNotEmpty) {
      for (final profile in generationProfiles) {
        if (profile.profileKey.trim() == normalized) return profile;
      }
    }
    return generationProfiles.firstOrNull ?? AiGenerationProfile.unconfigured;
  }

  AiEmbeddingProfile? get selectedEmbeddingProfile {
    final normalized = selectedEmbeddingProfileKey?.trim() ?? '';
    if (normalized.isNotEmpty) {
      for (final profile in embeddingProfiles) {
        if (profile.profileKey.trim() == normalized) return profile;
      }
    }
    return embeddingProfiles.firstOrNull;
  }

  List<AiEmbeddingProfile> get enabledEmbeddingProfiles => embeddingProfiles
      .where((profile) => profile.enabled)
      .toList(growable: false);

  bool get hasEnabledEmbeddingProfile => enabledEmbeddingProfiles.isNotEmpty;

  String get apiUrl => selectedGenerationProfile.baseUrl;
  String get apiKey => selectedGenerationProfile.apiKey;
  String get model => selectedGenerationProfile.model;
  List<String> get modelOptions => selectedGenerationProfile.modelOptions;
  Map<String, String> get insightPromptTemplates => analysisPromptTemplates;
  String get embeddingBaseUrl => selectedEmbeddingProfile?.baseUrl ?? '';
  String get embeddingApiKey => selectedEmbeddingProfile?.apiKey ?? '';
  String get embeddingModel => selectedEmbeddingProfile?.model ?? '';

  AiSettings copyWith({
    int? schemaVersion,
    List<AiServiceInstance>? services,
    List<AiTaskRouteBinding>? taskRouteBindings,
    List<AiGenerationProfile>? generationProfiles,
    String? selectedGenerationProfileKey,
    List<AiEmbeddingProfile>? embeddingProfiles,
    Object? selectedEmbeddingProfileKey = _unset,
    String? prompt,
    String? userProfile,
    AiProxySettings? proxySettings,
    List<AiQuickPrompt>? quickPrompts,
    Map<String, String>? analysisPromptTemplates,
    Map<String, String>? insightPromptTemplates,
    AiCustomInsightTemplate? customInsightTemplate,
    String? apiUrl,
    String? apiKey,
    String? model,
    List<String>? modelOptions,
    String? embeddingBaseUrl,
    String? embeddingApiKey,
    String? embeddingModel,
  }) {
    var nextGenerationProfiles = generationProfiles ?? this.generationProfiles;
    final nextSelectedGenerationKey =
        selectedGenerationProfileKey ?? this.selectedGenerationProfileKey;

    if (apiUrl != null ||
        apiKey != null ||
        model != null ||
        modelOptions != null) {
      final current = _resolveSelectedGeneration(
        profiles: nextGenerationProfiles,
        key: nextSelectedGenerationKey,
      );
      final replacement = current.copyWith(
        baseUrl: apiUrl,
        apiKey: apiKey,
        model: model,
        modelOptions: modelOptions,
        backendKind: apiUrl != null
            ? inferBackendKindFromBaseUrl(apiUrl)
            : null,
        providerKind: (apiUrl != null || model != null)
            ? inferGenerationProviderKind(
                baseUrl: apiUrl ?? current.baseUrl,
                model: model ?? current.model,
              )
            : null,
      );
      nextGenerationProfiles = _replaceGenerationProfile(
        profiles: nextGenerationProfiles,
        replacement: replacement,
      );
    }

    var nextEmbeddingProfiles = embeddingProfiles ?? this.embeddingProfiles;
    final resolvedSelectedEmbeddingKey =
        identical(selectedEmbeddingProfileKey, _unset)
        ? this.selectedEmbeddingProfileKey
        : selectedEmbeddingProfileKey as String?;
    if (embeddingBaseUrl != null ||
        embeddingApiKey != null ||
        embeddingModel != null) {
      final current = _resolveSelectedEmbedding(
        profiles: nextEmbeddingProfiles,
        key: resolvedSelectedEmbeddingKey,
      );
      final replacement =
          (current ??
                  AiEmbeddingProfile(
                    profileKey: 'default_embedding',
                    displayName: 'Default Embedding',
                    backendKind: inferBackendKindFromBaseUrl(
                      embeddingBaseUrl ?? '',
                    ),
                    providerKind: AiProviderKind.openAiCompatible,
                    baseUrl: embeddingBaseUrl ?? '',
                    apiKey: embeddingApiKey ?? '',
                    model: embeddingModel ?? '',
                    enabled: true,
                  ))
              .copyWith(
                baseUrl: embeddingBaseUrl,
                apiKey: embeddingApiKey,
                model: embeddingModel,
                backendKind: embeddingBaseUrl != null
                    ? inferBackendKindFromBaseUrl(embeddingBaseUrl)
                    : null,
              );
      nextEmbeddingProfiles = _replaceEmbeddingProfile(
        profiles: nextEmbeddingProfiles,
        replacement: replacement,
      );
    }

    return AiSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      services: services ?? this.services,
      taskRouteBindings: taskRouteBindings ?? this.taskRouteBindings,
      generationProfiles: nextGenerationProfiles,
      selectedGenerationProfileKey: nextSelectedGenerationKey,
      embeddingProfiles: nextEmbeddingProfiles,
      selectedEmbeddingProfileKey: resolvedSelectedEmbeddingKey,
      prompt: prompt ?? this.prompt,
      userProfile: userProfile ?? this.userProfile,
      proxySettings: proxySettings ?? this.proxySettings,
      quickPrompts: quickPrompts ?? this.quickPrompts,
      analysisPromptTemplates:
          analysisPromptTemplates ??
          insightPromptTemplates ??
          this.analysisPromptTemplates,
      customInsightTemplate:
          customInsightTemplate ?? this.customInsightTemplate,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'services': services
        .map((service) => service.toJson())
        .toList(growable: false),
    'taskRouteBindings': taskRouteBindings
        .map((binding) => binding.toJson())
        .toList(growable: false),
    'generationProfiles': generationProfiles
        .map((p) => p.toJson())
        .toList(growable: false),
    'selectedGenerationProfileKey': selectedGenerationProfileKey,
    'embeddingProfiles': embeddingProfiles
        .map((p) => p.toJson())
        .toList(growable: false),
    'selectedEmbeddingProfileKey': selectedEmbeddingProfileKey,
    'prompt': prompt,
    'userProfile': userProfile,
    'proxySettings': proxySettings.toJson(),
    'quickPrompts': quickPrompts.map((p) => p.toJson()).toList(growable: false),
    'analysisPromptTemplates': analysisPromptTemplates,
    'insightPromptTemplates': analysisPromptTemplates,
    'customInsightTemplate': customInsightTemplate.toJson(),
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    List<AiQuickPrompt> readQuickPrompts(
      String key,
      List<AiQuickPrompt> fallback,
    ) {
      final raw = json[key];
      if (raw is! List) return fallback;
      final prompts = <AiQuickPrompt>[];
      final seen = <String>{};
      for (final item in raw) {
        AiQuickPrompt? prompt;
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            prompt = AiQuickPrompt.fromLegacy(trimmed);
          }
        } else if (item is Map) {
          prompt = AiQuickPrompt.fromJson(item.cast<String, dynamic>());
        }
        if (prompt == null) continue;
        if (prompt.title.trim().isEmpty && prompt.content.trim().isEmpty) {
          continue;
        }
        final dedupeKey = '${prompt.title}|${prompt.content}|${prompt.iconKey}';
        if (seen.add(dedupeKey)) {
          prompts.add(prompt);
        }
      }
      return prompts.isEmpty ? fallback : List.unmodifiable(prompts);
    }

    Map<String, String> readPromptTemplates() {
      final raw =
          json['analysisPromptTemplates'] ?? json['insightPromptTemplates'];
      if (raw is! Map) return const <String, String>{};
      final templates = <String, String>{};
      raw.forEach((templateKey, templateValue) {
        final normalizedKey = templateKey.toString().trim();
        final normalizedValue = templateValue is String
            ? templateValue.trim()
            : templateValue?.toString().trim() ?? '';
        if (normalizedKey.isEmpty || normalizedValue.isEmpty) return;
        templates[normalizedKey] = normalizedValue;
      });
      return Map.unmodifiable(templates);
    }

    AiCustomInsightTemplate readCustomInsightTemplate() {
      final raw = json['customInsightTemplate'];
      if (raw is! Map) return const AiCustomInsightTemplate();
      return AiCustomInsightTemplate.fromJson(raw.cast<String, dynamic>());
    }

    AiProxySettings readProxySettings() {
      final raw = json['proxySettings'];
      if (raw is! Map) return AiProxySettings.defaults;
      return AiProxySettings.fromJson(raw.cast<String, dynamic>());
    }

    List<AiGenerationProfile> readGenerationProfiles() {
      final raw = json['generationProfiles'];
      if (raw is List) {
        final profiles = raw
            .whereType<Map>()
            .map(
              (item) =>
                  AiGenerationProfile.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false);
        if (profiles.isNotEmpty) return profiles;
      }

      final legacyBaseUrl = readString('apiUrl', '');
      final legacyApiKey = (json['apiKey'] is String)
          ? (json['apiKey'] as String).trim()
          : '';
      final legacyModel = readString('model', '');
      final legacyOptionsRaw = json['modelOptions'];
      final legacyOptions = legacyOptionsRaw is List
          ? legacyOptionsRaw
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      if (legacyBaseUrl.isEmpty &&
          legacyApiKey.isEmpty &&
          legacyModel.isEmpty &&
          legacyOptions.isEmpty) {
        return const <AiGenerationProfile>[];
      }
      return <AiGenerationProfile>[
        AiGenerationProfile(
          profileKey: 'default_generation',
          displayName: 'Default Generation',
          backendKind: inferBackendKindFromBaseUrl(legacyBaseUrl),
          providerKind: inferGenerationProviderKind(
            baseUrl: legacyBaseUrl,
            model: legacyModel,
          ),
          baseUrl: legacyBaseUrl,
          apiKey: legacyApiKey,
          model: legacyModel,
          modelOptions: List.unmodifiable(legacyOptions),
          enabled: true,
        ),
      ];
    }

    List<AiEmbeddingProfile> readEmbeddingProfiles() {
      final raw = json['embeddingProfiles'];
      if (raw is! List) return const <AiEmbeddingProfile>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => AiEmbeddingProfile.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    }

    List<AiServiceInstance> readServices() {
      final raw = json['services'];
      if (raw is! List) return const <AiServiceInstance>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => AiServiceInstance.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    }

    List<AiTaskRouteBinding> readBindings() {
      final raw = json['taskRouteBindings'];
      if (raw is! List) return const <AiTaskRouteBinding>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => AiTaskRouteBinding.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    }

    final generationProfiles = readGenerationProfiles();
    final selectedGenerationKey = readString(
      'selectedGenerationProfileKey',
      generationProfiles.isNotEmpty ? generationProfiles.first.profileKey : '',
    );
    final embeddingProfiles = readEmbeddingProfiles();
    final selectedEmbeddingKeyRaw = json['selectedEmbeddingProfileKey'];
    final selectedEmbeddingKey =
        selectedEmbeddingKeyRaw is String &&
            selectedEmbeddingKeyRaw.trim().isNotEmpty
        ? selectedEmbeddingKeyRaw.trim()
        : (embeddingProfiles.isNotEmpty
              ? embeddingProfiles.first.profileKey
              : null);
    final rawSchemaVersion = json['schemaVersion'];

    return AiSettings(
      schemaVersion: rawSchemaVersion is num ? rawSchemaVersion.toInt() : 2,
      services: List<AiServiceInstance>.unmodifiable(readServices()),
      taskRouteBindings: List<AiTaskRouteBinding>.unmodifiable(readBindings()),
      generationProfiles: generationProfiles,
      selectedGenerationProfileKey: selectedGenerationKey,
      embeddingProfiles: embeddingProfiles,
      selectedEmbeddingProfileKey: selectedEmbeddingKey,
      prompt: readString('prompt', AiSettings.defaults.prompt),
      userProfile: (json['userProfile'] is String)
          ? (json['userProfile'] as String).trim()
          : AiSettings.defaults.userProfile,
      proxySettings: readProxySettings(),
      quickPrompts: readQuickPrompts(
        'quickPrompts',
        AiSettings.defaults.quickPrompts,
      ),
      analysisPromptTemplates: readPromptTemplates(),
      customInsightTemplate: readCustomInsightTemplate(),
    );
  }

  static AiGenerationProfile _resolveSelectedGeneration({
    required List<AiGenerationProfile> profiles,
    required String key,
  }) {
    final normalized = key.trim();
    for (final profile in profiles) {
      if (profile.profileKey.trim() == normalized) return profile;
    }
    return profiles.firstOrNull ?? AiGenerationProfile.unconfigured;
  }

  static AiEmbeddingProfile? _resolveSelectedEmbedding({
    required List<AiEmbeddingProfile> profiles,
    required String? key,
  }) {
    final normalized = key?.trim() ?? '';
    if (normalized.isEmpty) return profiles.firstOrNull;
    for (final profile in profiles) {
      if (profile.profileKey.trim() == normalized) return profile;
    }
    return profiles.firstOrNull;
  }

  static List<AiGenerationProfile> _replaceGenerationProfile({
    required List<AiGenerationProfile> profiles,
    required AiGenerationProfile replacement,
  }) {
    if (profiles.isEmpty) return <AiGenerationProfile>[replacement];
    final next = <AiGenerationProfile>[];
    var replaced = false;
    for (final profile in profiles) {
      if (profile.profileKey.trim() == replacement.profileKey.trim()) {
        next.add(replacement);
        replaced = true;
      } else {
        next.add(profile);
      }
    }
    if (!replaced) next.insert(0, replacement);
    return List.unmodifiable(next);
  }

  static List<AiEmbeddingProfile> _replaceEmbeddingProfile({
    required List<AiEmbeddingProfile> profiles,
    required AiEmbeddingProfile replacement,
  }) {
    if (profiles.isEmpty) return <AiEmbeddingProfile>[replacement];
    final next = <AiEmbeddingProfile>[];
    var replaced = false;
    for (final profile in profiles) {
      if (profile.profileKey.trim() == replacement.profileKey.trim()) {
        next.add(replacement);
        replaced = true;
      } else {
        next.add(profile);
      }
    }
    if (!replaced) next.insert(0, replacement);
    return List.unmodifiable(next);
  }
}

const Object _unset = Object();

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
