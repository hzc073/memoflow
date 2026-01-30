class LocationSettings {
  static const defaults = LocationSettings(
    enabled: false,
    amapWebKey: '',
    amapSecurityKey: '',
  );

  const LocationSettings({
    required this.enabled,
    required this.amapWebKey,
    required this.amapSecurityKey,
  });

  final bool enabled;
  final String amapWebKey;
  final String amapSecurityKey;

  LocationSettings copyWith({
    bool? enabled,
    String? amapWebKey,
    String? amapSecurityKey,
  }) {
    return LocationSettings(
      enabled: enabled ?? this.enabled,
      amapWebKey: amapWebKey ?? this.amapWebKey,
      amapSecurityKey: amapSecurityKey ?? this.amapSecurityKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'amapWebKey': amapWebKey,
        'amapSecurityKey': amapSecurityKey,
      };

  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    bool parseBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    String parseString(String key) {
      final raw = json[key];
      if (raw is String) return raw;
      return raw?.toString() ?? '';
    }

    return LocationSettings(
      enabled: parseBool('enabled', LocationSettings.defaults.enabled),
      amapWebKey: parseString('amapWebKey'),
      amapSecurityKey: parseString('amapSecurityKey'),
    );
  }
}
