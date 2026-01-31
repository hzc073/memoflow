enum LocationPrecision {
  province,
  city,
  district,
  street,
}

const _locationPrecisionKeys = <LocationPrecision, String>{
  LocationPrecision.province: 'province',
  LocationPrecision.city: 'city',
  LocationPrecision.district: 'district',
  LocationPrecision.street: 'street',
};

const _locationPrecisionValues = <String, LocationPrecision>{
  'province': LocationPrecision.province,
  'city': LocationPrecision.city,
  'district': LocationPrecision.district,
  'street': LocationPrecision.street,
};

LocationPrecision parseLocationPrecision(String? raw) {
  if (raw == null) return LocationPrecision.city;
  final key = raw.trim().toLowerCase();
  return _locationPrecisionValues[key] ?? LocationPrecision.city;
}

class LocationSettings {
  static const defaults = LocationSettings(
    enabled: false,
    amapWebKey: '',
    amapSecurityKey: '',
    precision: LocationPrecision.city,
  );

  const LocationSettings({
    required this.enabled,
    required this.amapWebKey,
    required this.amapSecurityKey,
    required this.precision,
  });

  final bool enabled;
  final String amapWebKey;
  final String amapSecurityKey;
  final LocationPrecision precision;

  LocationSettings copyWith({
    bool? enabled,
    String? amapWebKey,
    String? amapSecurityKey,
    LocationPrecision? precision,
  }) {
    return LocationSettings(
      enabled: enabled ?? this.enabled,
      amapWebKey: amapWebKey ?? this.amapWebKey,
      amapSecurityKey: amapSecurityKey ?? this.amapSecurityKey,
      precision: precision ?? this.precision,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'amapWebKey': amapWebKey,
        'amapSecurityKey': amapSecurityKey,
        'precision': _locationPrecisionKeys[precision],
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
      precision: parseLocationPrecision(parseString('precision')),
    );
  }
}
