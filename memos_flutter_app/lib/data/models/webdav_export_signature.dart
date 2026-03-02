enum WebDavExportMode { enc, plain }

enum WebDavExportFormat { full, incremental }

class WebDavExportSignature {
  const WebDavExportSignature({
    required this.schemaVersion,
    required this.mode,
    required this.accountIdHash,
    required this.createdAt,
    required this.lastSuccessAt,
    required this.snapshotId,
    required this.exportFormat,
    required this.vaultKeyId,
  });

  final int schemaVersion;
  final WebDavExportMode mode;
  final String accountIdHash;
  final String createdAt;
  final String lastSuccessAt;
  final String snapshotId;
  final WebDavExportFormat exportFormat;
  final String vaultKeyId;

  bool get isValid =>
      schemaVersion == 1 &&
      accountIdHash.trim().isNotEmpty &&
      createdAt.trim().isNotEmpty &&
      lastSuccessAt.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'mode': mode.name,
        'accountIdHash': accountIdHash,
        'createdAt': createdAt,
        'lastSuccessAt': lastSuccessAt,
        'snapshotId': snapshotId,
        'exportFormat': exportFormat.name,
        'vaultKeyId': vaultKeyId,
      };

  static WebDavExportSignature? fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    String readString(String key) {
      final raw = json[key];
      if (raw is String) return raw;
      return '';
    }

    WebDavExportMode readMode() {
      final raw = readString('mode');
      return WebDavExportMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => WebDavExportMode.enc,
      );
    }

    WebDavExportFormat readFormat() {
      final raw = readString('exportFormat');
      return WebDavExportFormat.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => WebDavExportFormat.full,
      );
    }

    final signature = WebDavExportSignature(
      schemaVersion: readInt('schemaVersion', 1),
      mode: readMode(),
      accountIdHash: readString('accountIdHash'),
      createdAt: readString('createdAt'),
      lastSuccessAt: readString('lastSuccessAt'),
      snapshotId: readString('snapshotId'),
      exportFormat: readFormat(),
      vaultKeyId: readString('vaultKeyId'),
    );
    return signature.isValid ? signature : null;
  }
}
