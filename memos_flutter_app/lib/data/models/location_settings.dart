enum LocationPrecision { province, city, district, street }

enum LocationServiceProvider { amap, baidu, google }

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

const _locationServiceProviderKeys = <LocationServiceProvider, String>{
  LocationServiceProvider.amap: 'amap',
  LocationServiceProvider.baidu: 'baidu',
  LocationServiceProvider.google: 'google',
};

const _locationServiceProviderValues = <String, LocationServiceProvider>{
  'amap': LocationServiceProvider.amap,
  'baidu': LocationServiceProvider.baidu,
  'google': LocationServiceProvider.google,
};

LocationPrecision parseLocationPrecision(String? raw) {
  if (raw == null) return LocationPrecision.city;
  final key = raw.trim().toLowerCase();
  return _locationPrecisionValues[key] ?? LocationPrecision.city;
}

LocationServiceProvider parseLocationServiceProvider(String? raw) {
  if (raw == null) return LocationServiceProvider.amap;
  final key = raw.trim().toLowerCase();
  return _locationServiceProviderValues[key] ?? LocationServiceProvider.amap;
}

class LocationSettings {
  static const defaults = LocationSettings(
    enabled: false,
    provider: LocationServiceProvider.amap,
    amapWebKey: '',
    amapSecurityKey: '',
    baiduWebKey: '',
    googleApiKey: '',
    precision: LocationPrecision.city,
  );

  const LocationSettings({
    required this.enabled,
    required this.provider,
    required this.amapWebKey,
    required this.amapSecurityKey,
    required this.baiduWebKey,
    required this.googleApiKey,
    required this.precision,
  });

  final bool enabled;
  final LocationServiceProvider provider;
  final String amapWebKey;
  final String amapSecurityKey;
  final String baiduWebKey;
  final String googleApiKey;
  final LocationPrecision precision;

  LocationSettings copyWith({
    bool? enabled,
    LocationServiceProvider? provider,
    String? amapWebKey,
    String? amapSecurityKey,
    String? baiduWebKey,
    String? googleApiKey,
    LocationPrecision? precision,
  }) {
    return LocationSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      amapWebKey: amapWebKey ?? this.amapWebKey,
      amapSecurityKey: amapSecurityKey ?? this.amapSecurityKey,
      baiduWebKey: baiduWebKey ?? this.baiduWebKey,
      googleApiKey: googleApiKey ?? this.googleApiKey,
      precision: precision ?? this.precision,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'provider': _locationServiceProviderKeys[provider],
    'amapWebKey': amapWebKey,
    'amapSecurityKey': amapSecurityKey,
    'baiduWebKey': baiduWebKey,
    'googleApiKey': googleApiKey,
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
      provider: parseLocationServiceProvider(parseString('provider')),
      amapWebKey: parseString('amapWebKey'),
      amapSecurityKey: parseString('amapSecurityKey'),
      baiduWebKey: parseString('baiduWebKey'),
      googleApiKey: parseString('googleApiKey'),
      precision: parseLocationPrecision(parseString('precision')),
    );
  }
}
