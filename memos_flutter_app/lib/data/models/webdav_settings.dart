enum WebDavAuthMode {
  basic,
  digest,
}

class WebDavSettings {
  const WebDavSettings({
    required this.enabled,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.authMode,
    required this.ignoreTlsErrors,
    required this.rootPath,
  });

  final bool enabled;
  final String serverUrl;
  final String username;
  final String password;
  final WebDavAuthMode authMode;
  final bool ignoreTlsErrors;
  final String rootPath;

  static const defaults = WebDavSettings(
    enabled: false,
    serverUrl: '',
    username: '',
    password: '',
    authMode: WebDavAuthMode.basic,
    ignoreTlsErrors: false,
    rootPath: '/MemoFlow/settings/v1',
  );

  WebDavSettings copyWith({
    bool? enabled,
    String? serverUrl,
    String? username,
    String? password,
    WebDavAuthMode? authMode,
    bool? ignoreTlsErrors,
    String? rootPath,
  }) {
    return WebDavSettings(
      enabled: enabled ?? this.enabled,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      authMode: authMode ?? this.authMode,
      ignoreTlsErrors: ignoreTlsErrors ?? this.ignoreTlsErrors,
      rootPath: rootPath ?? this.rootPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'authMode': authMode.name,
        'ignoreTlsErrors': ignoreTlsErrors,
        'rootPath': rootPath,
      };

  factory WebDavSettings.fromJson(Map<String, dynamic> json) {
    bool readBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String) return raw;
      return fallback;
    }

    WebDavAuthMode readAuthMode() {
      final raw = json['authMode'];
      if (raw is String) {
        return WebDavAuthMode.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => WebDavSettings.defaults.authMode,
        );
      }
      return WebDavSettings.defaults.authMode;
    }

    return WebDavSettings(
      enabled: readBool('enabled', WebDavSettings.defaults.enabled),
      serverUrl: readString('serverUrl', WebDavSettings.defaults.serverUrl),
      username: readString('username', WebDavSettings.defaults.username),
      password: readString('password', WebDavSettings.defaults.password),
      authMode: readAuthMode(),
      ignoreTlsErrors: readBool('ignoreTlsErrors', WebDavSettings.defaults.ignoreTlsErrors),
      rootPath: readString('rootPath', WebDavSettings.defaults.rootPath),
    );
  }
}
