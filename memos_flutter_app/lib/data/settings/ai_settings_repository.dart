import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  AiQuickPrompt copyWith({
    String? title,
    String? content,
    String? iconKey,
  }) {
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

class AiSettings {
  static const defaultModelOptions = <String>[
    'deepseek-chat',
    'Claude 3.5 Sonnet',
    'Claude 3.5 Haiku',
    'Claude 3 Opus',
    'GPT-4o mini',
    'GPT-4o',
  ];

  static const defaults = AiSettings(
    apiUrl: 'https://api.deepseek.com',
    apiKey: '',
    model: 'deepseek-chat',
    modelOptions: defaultModelOptions,
    prompt: '你是一位极简主义的笔记助手，擅长提炼核心观点并以优雅的格式排版。在回复时，请保持专业、温和且简洁的语气。尽量使用列表和简短的段落。',
    userProfile: '',
    quickPrompts: const <AiQuickPrompt>[],
  );

  const AiSettings({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
    required this.modelOptions,
    required this.prompt,
    required this.userProfile,
    required this.quickPrompts,
  });

  final String apiUrl;
  final String apiKey;
  final String model;
  final List<String> modelOptions;
  final String prompt;
  final String userProfile;
  final List<AiQuickPrompt> quickPrompts;

  AiSettings copyWith({
    String? apiUrl,
    String? apiKey,
    String? model,
    List<String>? modelOptions,
    String? prompt,
    String? userProfile,
    List<AiQuickPrompt>? quickPrompts,
  }) {
    return AiSettings(
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      modelOptions: modelOptions ?? this.modelOptions,
      prompt: prompt ?? this.prompt,
      userProfile: userProfile ?? this.userProfile,
      quickPrompts: quickPrompts ?? this.quickPrompts,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiUrl': apiUrl,
    'apiKey': apiKey,
    'model': model,
    'modelOptions': modelOptions,
    'prompt': prompt,
    'userProfile': userProfile,
    'quickPrompts': quickPrompts.map((p) => p.toJson()).toList(growable: false),
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
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
        final normalized = trimmed.toLowerCase();
        if (seen.add(normalized)) {
          options.add(trimmed);
        }
      }
      if (options.isEmpty) return fallback;
      return options;
    }

    bool containsModel(List<String> options, String model) {
      final normalized = model.trim().toLowerCase();
      if (normalized.isEmpty) return false;
      return options.any((option) => option.trim().toLowerCase() == normalized);
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
        final key = '${prompt.title}|${prompt.content}|${prompt.iconKey}';
        if (seen.add(key)) {
          prompts.add(prompt);
        }
      }
      if (prompts.isEmpty) return fallback;
      return prompts.toList(growable: false);
    }

    final model = readString('model', AiSettings.defaults.model);
    var modelOptions = readModelOptions(
      'modelOptions',
      AiSettings.defaults.modelOptions,
    );
    if (model.trim().isNotEmpty && !containsModel(modelOptions, model)) {
      modelOptions = [model, ...modelOptions];
    }

    return AiSettings(
      apiUrl: readString('apiUrl', AiSettings.defaults.apiUrl),
      apiKey: (json['apiKey'] is String)
          ? (json['apiKey'] as String).trim()
          : AiSettings.defaults.apiKey,
      model: model,
      modelOptions: modelOptions,
      prompt: readString('prompt', AiSettings.defaults.prompt),
      userProfile: (json['userProfile'] is String)
          ? (json['userProfile'] as String).trim()
          : AiSettings.defaults.userProfile,
      quickPrompts: readQuickPrompts(
        'quickPrompts',
        AiSettings.defaults.quickPrompts,
      ),
    );
  }
}

class AiSettingsRepository {
  AiSettingsRepository(this._storage);

  static const _kKey = 'ai_settings_v1';

  final FlutterSecureStorage _storage;

  Future<AiSettings> read() async {
    final raw = await _storage.read(key: _kKey);
    if (raw == null || raw.trim().isEmpty) return AiSettings.defaults;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AiSettings.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return AiSettings.defaults;
  }

  Future<void> write(AiSettings settings) async {
    await _storage.write(key: _kKey, value: jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _kKey);
  }
}
