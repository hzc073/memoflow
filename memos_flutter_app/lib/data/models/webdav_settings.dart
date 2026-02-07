enum WebDavAuthMode { basic, digest }

enum WebDavBackupSchedule { manual, daily, weekly }

class WebDavSettings {
  const WebDavSettings({
    required this.enabled,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.authMode,
    required this.ignoreTlsErrors,
    required this.rootPath,
    required this.backupEnabled,
    required this.backupSchedule,
    required this.backupRetentionCount,
    required this.rememberBackupPassword,
  });

  final bool enabled;
  final String serverUrl;
  final String username;
  final String password;
  final WebDavAuthMode authMode;
  final bool ignoreTlsErrors;
  final String rootPath;
  final bool backupEnabled;
  final WebDavBackupSchedule backupSchedule;
  final int backupRetentionCount;
  final bool rememberBackupPassword;

  static const defaults = WebDavSettings(
    enabled: false,
    serverUrl: '',
    username: '',
    password: '',
    authMode: WebDavAuthMode.basic,
    ignoreTlsErrors: false,
    rootPath: '/MemoFlow/settings/v1',
    backupEnabled: false,
    backupSchedule: WebDavBackupSchedule.daily,
    backupRetentionCount: 5,
    rememberBackupPassword: false,
  );

  WebDavSettings copyWith({
    bool? enabled,
    String? serverUrl,
    String? username,
    String? password,
    WebDavAuthMode? authMode,
    bool? ignoreTlsErrors,
    String? rootPath,
    bool? backupEnabled,
    WebDavBackupSchedule? backupSchedule,
    int? backupRetentionCount,
    bool? rememberBackupPassword,
  }) {
    return WebDavSettings(
      enabled: enabled ?? this.enabled,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      authMode: authMode ?? this.authMode,
      ignoreTlsErrors: ignoreTlsErrors ?? this.ignoreTlsErrors,
      rootPath: rootPath ?? this.rootPath,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      backupSchedule: backupSchedule ?? this.backupSchedule,
      backupRetentionCount: backupRetentionCount ?? this.backupRetentionCount,
      rememberBackupPassword:
          rememberBackupPassword ?? this.rememberBackupPassword,
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
    'backupEnabled': backupEnabled,
    'backupSchedule': backupSchedule.name,
    'backupRetentionCount': backupRetentionCount,
    'rememberBackupPassword': rememberBackupPassword,
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

    WebDavBackupSchedule readBackupSchedule() {
      final raw = json['backupSchedule'];
      if (raw is String) {
        return WebDavBackupSchedule.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => WebDavSettings.defaults.backupSchedule,
        );
      }
      return WebDavSettings.defaults.backupSchedule;
    }

    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    return WebDavSettings(
      enabled: readBool('enabled', WebDavSettings.defaults.enabled),
      serverUrl: readString('serverUrl', WebDavSettings.defaults.serverUrl),
      username: readString('username', WebDavSettings.defaults.username),
      password: readString('password', WebDavSettings.defaults.password),
      authMode: readAuthMode(),
      ignoreTlsErrors: readBool(
        'ignoreTlsErrors',
        WebDavSettings.defaults.ignoreTlsErrors,
      ),
      rootPath: readString('rootPath', WebDavSettings.defaults.rootPath),
      backupEnabled: readBool(
        'backupEnabled',
        WebDavSettings.defaults.backupEnabled,
      ),
      backupSchedule: readBackupSchedule(),
      backupRetentionCount: readInt(
        'backupRetentionCount',
        WebDavSettings.defaults.backupRetentionCount,
      ),
      rememberBackupPassword: readBool(
        'rememberBackupPassword',
        WebDavSettings.defaults.rememberBackupPassword,
      ),
    );
  }
}
