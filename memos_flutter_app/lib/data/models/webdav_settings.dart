enum WebDavAuthMode { basic, digest }

enum WebDavBackupSchedule { manual, daily, weekly, monthly, onOpen }

enum WebDavBackupEncryptionMode { encrypted, plain }

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
    required this.backupContentConfig,
    required this.backupContentMemos,
    required this.backupEncryptionMode,
    required this.backupSchedule,
    required this.backupRetentionCount,
    required this.rememberBackupPassword,
    required this.backupMirrorTreeUri,
    required this.backupMirrorRootPath,
  });

  final bool enabled;
  final String serverUrl;
  final String username;
  final String password;
  final WebDavAuthMode authMode;
  final bool ignoreTlsErrors;
  final String rootPath;
  final bool backupEnabled;
  final bool backupContentConfig;
  final bool backupContentMemos;
  final WebDavBackupEncryptionMode backupEncryptionMode;
  final WebDavBackupSchedule backupSchedule;
  final int backupRetentionCount;
  final bool rememberBackupPassword;
  final String backupMirrorTreeUri;
  final String backupMirrorRootPath;

  bool get isBackupEnabled => enabled && backupEnabled;

  static const defaults = WebDavSettings(
    enabled: false,
    serverUrl: '',
    username: '',
    password: '',
    authMode: WebDavAuthMode.basic,
    ignoreTlsErrors: false,
    rootPath: '/MemoFlow/settings/v1',
    backupEnabled: false,
    backupContentConfig: true,
    backupContentMemos: true,
    backupEncryptionMode: WebDavBackupEncryptionMode.encrypted,
    backupSchedule: WebDavBackupSchedule.daily,
    backupRetentionCount: 5,
    rememberBackupPassword: true,
    backupMirrorTreeUri: '',
    backupMirrorRootPath: '',
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
    bool? backupContentConfig,
    bool? backupContentMemos,
    WebDavBackupEncryptionMode? backupEncryptionMode,
    WebDavBackupSchedule? backupSchedule,
    int? backupRetentionCount,
    bool? rememberBackupPassword,
    String? backupMirrorTreeUri,
    String? backupMirrorRootPath,
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
      backupContentConfig: backupContentConfig ?? this.backupContentConfig,
      backupContentMemos: backupContentMemos ?? this.backupContentMemos,
      backupEncryptionMode:
          backupEncryptionMode ?? this.backupEncryptionMode,
      backupSchedule: backupSchedule ?? this.backupSchedule,
      backupRetentionCount: backupRetentionCount ?? this.backupRetentionCount,
      rememberBackupPassword:
          rememberBackupPassword ?? this.rememberBackupPassword,
      backupMirrorTreeUri: backupMirrorTreeUri ?? this.backupMirrorTreeUri,
      backupMirrorRootPath: backupMirrorRootPath ?? this.backupMirrorRootPath,
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
    'backupContentConfig': backupContentConfig,
    'backupContentMemos': backupContentMemos,
    'backupEncryptionMode': backupEncryptionMode.name,
    'backupSchedule': backupSchedule.name,
    'backupRetentionCount': backupRetentionCount,
    'rememberBackupPassword': rememberBackupPassword,
    'backupMirrorTreeUri': backupMirrorTreeUri,
    'backupMirrorRootPath': backupMirrorRootPath,
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

    WebDavBackupEncryptionMode readBackupEncryptionMode() {
      final raw = json['backupEncryptionMode'];
      if (raw is String) {
        return WebDavBackupEncryptionMode.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => WebDavSettings.defaults.backupEncryptionMode,
        );
      }
      return WebDavSettings.defaults.backupEncryptionMode;
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
      backupContentConfig: readBool(
        'backupContentConfig',
        WebDavSettings.defaults.backupContentConfig,
      ),
      backupContentMemos: readBool(
        'backupContentMemos',
        WebDavSettings.defaults.backupContentMemos,
      ),
      backupEncryptionMode: readBackupEncryptionMode(),
      backupSchedule: readBackupSchedule(),
      backupRetentionCount: readInt(
        'backupRetentionCount',
        WebDavSettings.defaults.backupRetentionCount,
      ),
      rememberBackupPassword: readBool(
        'rememberBackupPassword',
        WebDavSettings.defaults.rememberBackupPassword,
      ),
      backupMirrorTreeUri: readString(
        'backupMirrorTreeUri',
        WebDavSettings.defaults.backupMirrorTreeUri,
      ),
      backupMirrorRootPath: readString(
        'backupMirrorRootPath',
        WebDavSettings.defaults.backupMirrorRootPath,
      ),
    );
  }
}
