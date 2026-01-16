import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiSettings {
  static const defaults = AiSettings(
    apiUrl: 'https://api.anthropic.com/v1',
    apiKey: '',
    model: 'Claude 3.5 Sonnet',
    prompt: '你是一位极简主义的笔记助手，擅长提炼核心观点并以优雅的格式排版。在回复时，请保持专业、温和且简洁的语气。尽量使用列表和简短的段落。',
    userProfile: '',
  );

  const AiSettings({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
    required this.prompt,
    required this.userProfile,
  });

  final String apiUrl;
  final String apiKey;
  final String model;
  final String prompt;
  final String userProfile;

  AiSettings copyWith({
    String? apiUrl,
    String? apiKey,
    String? model,
    String? prompt,
    String? userProfile,
  }) {
    return AiSettings(
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
      userProfile: userProfile ?? this.userProfile,
    );
  }

  Map<String, dynamic> toJson() => {
        'apiUrl': apiUrl,
        'apiKey': apiKey,
        'model': model,
        'prompt': prompt,
        'userProfile': userProfile,
      };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    return AiSettings(
      apiUrl: readString('apiUrl', AiSettings.defaults.apiUrl),
      apiKey: (json['apiKey'] is String) ? (json['apiKey'] as String).trim() : AiSettings.defaults.apiKey,
      model: readString('model', AiSettings.defaults.model),
      prompt: readString('prompt', AiSettings.defaults.prompt),
      userProfile: (json['userProfile'] is String) ? (json['userProfile'] as String).trim() : AiSettings.defaults.userProfile,
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

