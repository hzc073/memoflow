enum WebDavAuthMode { basic, digest }

enum WebDavBackupSchedule { manual, daily, weekly, monthly, onOpen }

enum WebDavBackupEncryptionMode { encrypted, plain }

enum WebDavBackupConfigScope { none, safe, full }

class WebDavSettings {
  const WebDavSettings({
    required this.enabled,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.authMode,
    required this.ignoreTlsErrors,
    required this.rootPath,
    required this.vaultEnabled,
    required this.rememberVaultPassword,
    required this.vaultKeepPlainCache,
    required this.backupEnabled,
    required this.backupContentMemos,
    required this.backupConfigScope,
    required this.backupEncryptionMode,
    required this.backupSchedule,
    required this.backupRetentionCount,
    required this.rememberBackupPassword,
    required this.backupExportEncrypted,
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
  final bool vaultEnabled;
  final bool rememberVaultPassword;
  final bool vaultKeepPlainCache;
  final bool backupEnabled;
  final bool backupContentMemos;
  final WebDavBackupConfigScope backupConfigScope;
  final WebDavBackupEncryptionMode backupEncryptionMode;
  final WebDavBackupSchedule backupSchedule;
  final int backupRetentionCount;
  final bool rememberBackupPassword;
  final bool backupExportEncrypted;
  final String backupMirrorTreeUri;
  final String backupMirrorRootPath;

  bool get isBackupEnabled => enabled && backupEnabled;
  bool get backupContentConfig =>
      backupConfigScope != WebDavBackupConfigScope.none;

  static const defaults = WebDavSettings(
    enabled: false,
    serverUrl: '',
    username: '',
    password: '',
    authMode: WebDavAuthMode.basic,
    ignoreTlsErrors: false,
    rootPath: '/MemoFlow/settings/v1',
    vaultEnabled: false,
    rememberVaultPassword: true,
    vaultKeepPlainCache: false,
    backupEnabled: false,
    backupContentMemos: true,
    backupConfigScope: WebDavBackupConfigScope.safe,
    backupEncryptionMode: WebDavBackupEncryptionMode.encrypted,
    backupSchedule: WebDavBackupSchedule.daily,
    backupRetentionCount: 5,
    rememberBackupPassword: true,
    backupExportEncrypted: true,
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
    bool? vaultEnabled,
    bool? rememberVaultPassword,
    bool? vaultKeepPlainCache,
    bool? backupEnabled,
    bool? backupContentMemos,
    WebDavBackupConfigScope? backupConfigScope,
    WebDavBackupEncryptionMode? backupEncryptionMode,
    WebDavBackupSchedule? backupSchedule,
    int? backupRetentionCount,
    bool? rememberBackupPassword,
    bool? backupExportEncrypted,
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
      vaultEnabled: vaultEnabled ?? this.vaultEnabled,
      rememberVaultPassword:
          rememberVaultPassword ?? this.rememberVaultPassword,
      vaultKeepPlainCache: vaultKeepPlainCache ?? this.vaultKeepPlainCache,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      backupContentMemos: backupContentMemos ?? this.backupContentMemos,
      backupConfigScope: backupConfigScope ?? this.backupConfigScope,
      backupEncryptionMode:
          backupEncryptionMode ?? this.backupEncryptionMode,
      backupSchedule: backupSchedule ?? this.backupSchedule,
      backupRetentionCount: backupRetentionCount ?? this.backupRetentionCount,
      rememberBackupPassword:
          rememberBackupPassword ?? this.rememberBackupPassword,
      backupExportEncrypted:
          backupExportEncrypted ?? this.backupExportEncrypted,
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
    'vaultEnabled': vaultEnabled,
    'rememberVaultPassword': rememberVaultPassword,
    'vaultKeepPlainCache': vaultKeepPlainCache,
    'backupEnabled': backupEnabled,
    'backupContentMemos': backupContentMemos,
    'backupConfigScope': backupConfigScope.name,
    'backupContentConfig': backupContentConfig,
    'backupEncryptionMode': backupEncryptionMode.name,
    'backupSchedule': backupSchedule.name,
    'backupRetentionCount': backupRetentionCount,
    'rememberBackupPassword': rememberBackupPassword,
    'backupExportEncrypted': backupExportEncrypted,
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

    WebDavBackupConfigScope readBackupConfigScope() {
      final raw = json['backupConfigScope'];
      if (raw is String) {
        return WebDavBackupConfigScope.values.firstWhere(
          (scope) => scope.name == raw,
          orElse: () => WebDavSettings.defaults.backupConfigScope,
        );
      }
      final legacy =
          readBool('backupContentConfig', WebDavSettings.defaults.backupContentConfig);
      return legacy
          ? WebDavBackupConfigScope.safe
          : WebDavBackupConfigScope.none;
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
      vaultEnabled: readBool(
        'vaultEnabled',
        WebDavSettings.defaults.vaultEnabled,
      ),
      rememberVaultPassword: readBool(
        'rememberVaultPassword',
        WebDavSettings.defaults.rememberVaultPassword,
      ),
      vaultKeepPlainCache: readBool(
        'vaultKeepPlainCache',
        WebDavSettings.defaults.vaultKeepPlainCache,
      ),
      backupEnabled: readBool(
        'backupEnabled',
        WebDavSettings.defaults.backupEnabled,
      ),
      backupContentMemos: readBool(
        'backupContentMemos',
        WebDavSettings.defaults.backupContentMemos,
      ),
      backupConfigScope: readBackupConfigScope(),
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
      backupExportEncrypted: readBool(
        'backupExportEncrypted',
        WebDavSettings.defaults.backupExportEncrypted,
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
