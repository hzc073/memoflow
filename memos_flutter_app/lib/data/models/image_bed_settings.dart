enum ImageBedProvider {
  lskyPro,
}

class ImageBedSettings {
  static const defaults = ImageBedSettings(
    enabled: false,
    provider: ImageBedProvider.lskyPro,
    baseUrl: '',
    email: '',
    password: '',
    strategyId: null,
    retryCount: 3,
    authToken: null,
  );

  const ImageBedSettings({
    required this.enabled,
    required this.provider,
    required this.baseUrl,
    required this.email,
    required this.password,
    required this.strategyId,
    required this.retryCount,
    required this.authToken,
  });

  final bool enabled;
  final ImageBedProvider provider;
  final String baseUrl;
  final String email;
  final String password;
  final String? strategyId;
  final int retryCount;
  final String? authToken;

  ImageBedSettings copyWith({
    bool? enabled,
    ImageBedProvider? provider,
    String? baseUrl,
    String? email,
    String? password,
    Object? strategyId = _unset,
    int? retryCount,
    Object? authToken = _unset,
  }) {
    return ImageBedSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      email: email ?? this.email,
      password: password ?? this.password,
      strategyId: identical(strategyId, _unset) ? this.strategyId : strategyId as String?,
      retryCount: retryCount ?? this.retryCount,
      authToken: identical(authToken, _unset) ? this.authToken : authToken as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider.name,
        'baseUrl': baseUrl,
        'email': email,
        'password': password,
        'strategyId': strategyId,
        'retryCount': retryCount,
        'authToken': authToken,
      };

  factory ImageBedSettings.fromJson(Map<String, dynamic> json) {
    ImageBedProvider parseProvider() {
      final raw = json['provider'];
      if (raw is String) {
        return ImageBedProvider.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => ImageBedSettings.defaults.provider,
        );
      }
      return ImageBedSettings.defaults.provider;
    }

    String parseString(String key) {
      final raw = json[key];
      if (raw is String) return raw;
      return raw?.toString() ?? '';
    }

    bool parseBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    int parseInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    String? parseOptional(String key) {
      final raw = json[key];
      if (raw is String) {
        final trimmed = raw.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    final baseUrl = parseString('baseUrl');
    final email = parseString('email');
    final password = parseString('password');

    return ImageBedSettings(
      enabled: parseBool('enabled', ImageBedSettings.defaults.enabled),
      provider: parseProvider(),
      baseUrl: baseUrl,
      email: email,
      password: password,
      strategyId: parseOptional('strategyId'),
      retryCount: parseInt('retryCount', ImageBedSettings.defaults.retryCount),
      authToken: parseOptional('authToken'),
    );
  }

  static const Object _unset = Object();
}
