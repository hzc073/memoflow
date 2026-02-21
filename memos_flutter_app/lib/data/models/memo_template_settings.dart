class MemoTemplate {
  const MemoTemplate({
    required this.id,
    required this.name,
    required this.content,
  });

  final String id;
  final String name;
  final String content;

  MemoTemplate copyWith({String? id, String? name, String? content}) {
    return MemoTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'content': content};

  factory MemoTemplate.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final raw = json[key];
      if (raw is String) return raw.trim();
      return '';
    }

    final name = readString('name');
    final contentRaw = json['content'];
    final content = contentRaw is String ? contentRaw : '';
    final id = readString('id');
    final fallbackId = 'legacy:${name.toLowerCase()}|${content.trim()}';
    return MemoTemplate(
      id: id.isEmpty ? fallbackId : id,
      name: name,
      content: content,
    );
  }
}

class MemoTemplateVariableSettings {
  static const defaults = MemoTemplateVariableSettings(
    dateFormat: 'yyyy-MM-dd',
    timeFormat: 'HH:mm',
    dateTimeFormat: 'yyyy-MM-dd HH:mm',
    weatherEnabled: false,
    weatherCity: '',
    weatherFallback: '--',
    keepUnknownVariables: true,
  );

  const MemoTemplateVariableSettings({
    required this.dateFormat,
    required this.timeFormat,
    required this.dateTimeFormat,
    required this.weatherEnabled,
    required this.weatherCity,
    required this.weatherFallback,
    required this.keepUnknownVariables,
  });

  final String dateFormat;
  final String timeFormat;
  final String dateTimeFormat;
  final bool weatherEnabled;
  final String weatherCity;
  final String weatherFallback;
  final bool keepUnknownVariables;

  MemoTemplateVariableSettings copyWith({
    String? dateFormat,
    String? timeFormat,
    String? dateTimeFormat,
    bool? weatherEnabled,
    String? weatherCity,
    String? weatherFallback,
    bool? keepUnknownVariables,
  }) {
    return MemoTemplateVariableSettings(
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      dateTimeFormat: dateTimeFormat ?? this.dateTimeFormat,
      weatherEnabled: weatherEnabled ?? this.weatherEnabled,
      weatherCity: weatherCity ?? this.weatherCity,
      weatherFallback: weatherFallback ?? this.weatherFallback,
      keepUnknownVariables: keepUnknownVariables ?? this.keepUnknownVariables,
    );
  }

  Map<String, dynamic> toJson() => {
    'dateFormat': dateFormat,
    'timeFormat': timeFormat,
    'dateTimeFormat': dateTimeFormat,
    'weatherEnabled': weatherEnabled,
    'weatherCity': weatherCity,
    'weatherFallback': weatherFallback,
    'keepUnknownVariables': keepUnknownVariables,
  };

  factory MemoTemplateVariableSettings.fromJson(Map<String, dynamic> json) {
    bool parseBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    String parseString(String key, String fallback) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return fallback;
    }

    return MemoTemplateVariableSettings(
      dateFormat: parseString('dateFormat', defaults.dateFormat),
      timeFormat: parseString('timeFormat', defaults.timeFormat),
      dateTimeFormat: parseString('dateTimeFormat', defaults.dateTimeFormat),
      weatherEnabled: parseBool('weatherEnabled', defaults.weatherEnabled),
      weatherCity: parseString('weatherCity', defaults.weatherCity),
      weatherFallback: parseString('weatherFallback', defaults.weatherFallback),
      keepUnknownVariables: parseBool(
        'keepUnknownVariables',
        defaults.keepUnknownVariables,
      ),
    );
  }
}

class MemoTemplateSettings {
  static const defaults = MemoTemplateSettings(
    enabled: false,
    templates: <MemoTemplate>[],
    variables: MemoTemplateVariableSettings.defaults,
  );

  const MemoTemplateSettings({
    required this.enabled,
    required this.templates,
    required this.variables,
  });

  final bool enabled;
  final List<MemoTemplate> templates;
  final MemoTemplateVariableSettings variables;

  MemoTemplateSettings copyWith({
    bool? enabled,
    List<MemoTemplate>? templates,
    MemoTemplateVariableSettings? variables,
  }) {
    return MemoTemplateSettings(
      enabled: enabled ?? this.enabled,
      templates: templates ?? this.templates,
      variables: variables ?? this.variables,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'templates': templates.map((e) => e.toJson()).toList(growable: false),
    'variables': variables.toJson(),
  };

  factory MemoTemplateSettings.fromJson(Map<String, dynamic> json) {
    bool parseBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    List<MemoTemplate> parseTemplates() {
      final raw = json['templates'];
      if (raw is! List) return const <MemoTemplate>[];
      final seen = <String>{};
      final output = <MemoTemplate>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final parsed = MemoTemplate.fromJson(item.cast<String, dynamic>());
        if (parsed.name.trim().isEmpty) continue;
        if (!seen.add(parsed.id)) continue;
        output.add(parsed);
      }
      return output;
    }

    MemoTemplateVariableSettings parseVariables() {
      final raw = json['variables'];
      if (raw is Map) {
        return MemoTemplateVariableSettings.fromJson(
          raw.cast<String, dynamic>(),
        );
      }
      return MemoTemplateVariableSettings.defaults;
    }

    return MemoTemplateSettings(
      enabled: parseBool('enabled', defaults.enabled),
      templates: parseTemplates(),
      variables: parseVariables(),
    );
  }
}
