class MemoFlowBridgeSettings {
  const MemoFlowBridgeSettings({
    required this.enabled,
    required this.host,
    required this.port,
    required this.token,
    required this.deviceName,
    required this.serverName,
    required this.apiVersion,
    required this.lastPairedAtMs,
  });

  static const MemoFlowBridgeSettings defaults = MemoFlowBridgeSettings(
    enabled: false,
    host: '',
    port: 3000,
    token: '',
    deviceName: '',
    serverName: '',
    apiVersion: 'bridge-v1',
    lastPairedAtMs: 0,
  );

  final bool enabled;
  final String host;
  final int port;
  final String token;
  final String deviceName;
  final String serverName;
  final String apiVersion;
  final int lastPairedAtMs;

  bool get isPaired =>
      host.trim().isNotEmpty && port > 0 && token.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'host': host,
      'port': port,
      'token': token,
      'deviceName': deviceName,
      'serverName': serverName,
      'apiVersion': apiVersion,
      'lastPairedAtMs': lastPairedAtMs,
    };
  }

  factory MemoFlowBridgeSettings.fromJson(Map<String, dynamic> json) {
    int parsePort() {
      final raw = json['port'];
      if (raw is int && raw > 0 && raw <= 65535) return raw;
      if (raw is num) {
        final v = raw.toInt();
        if (v > 0 && v <= 65535) return v;
      }
      if (raw is String) {
        final v = int.tryParse(raw.trim());
        if (v != null && v > 0 && v <= 65535) return v;
      }
      return defaults.port;
    }

    int parseLastPairedAtMs() {
      final raw = json['lastPairedAtMs'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    }

    String parseString(String key, String fallback) {
      final raw = json[key];
      if (raw is String) return raw.trim();
      return fallback;
    }

    bool parseBool(String key, bool fallback) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallback;
    }

    return MemoFlowBridgeSettings(
      enabled: parseBool('enabled', defaults.enabled),
      host: parseString('host', defaults.host),
      port: parsePort(),
      token: parseString('token', defaults.token),
      deviceName: parseString('deviceName', defaults.deviceName),
      serverName: parseString('serverName', defaults.serverName),
      apiVersion: parseString('apiVersion', defaults.apiVersion),
      lastPairedAtMs: parseLastPairedAtMs(),
    );
  }

  MemoFlowBridgeSettings copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? token,
    String? deviceName,
    String? serverName,
    String? apiVersion,
    int? lastPairedAtMs,
  }) {
    return MemoFlowBridgeSettings(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      deviceName: deviceName ?? this.deviceName,
      serverName: serverName ?? this.serverName,
      apiVersion: apiVersion ?? this.apiVersion,
      lastPairedAtMs: lastPairedAtMs ?? this.lastPairedAtMs,
    );
  }
}
