class WebDavFileMeta {
  const WebDavFileMeta({
    required this.hash,
    required this.updatedAt,
    required this.size,
    this.etag,
  });

  final String hash;
  final String updatedAt;
  final int size;
  final String? etag;

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'updatedAt': updatedAt,
        'size': size,
        if (etag != null) 'etag': etag,
      };

  factory WebDavFileMeta.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String) return raw;
      return fallback;
    }

    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return fallback;
    }

    return WebDavFileMeta(
      hash: readString('hash', ''),
      updatedAt: readString('updatedAt', ''),
      size: readInt('size', 0),
      etag: json['etag'] as String?,
    );
  }
}

class WebDavSyncMeta {
  const WebDavSyncMeta({
    required this.schemaVersion,
    required this.deviceId,
    required this.updatedAt,
    required this.files,
    this.deprecatedFiles = const <String>[],
    this.deprecatedDetectedAt,
    this.deprecatedRemindAfter,
    this.deprecatedClearedAt,
  });

  final int schemaVersion;
  final String deviceId;
  final String updatedAt;
  final Map<String, WebDavFileMeta> files;
  final List<String> deprecatedFiles;
  final String? deprecatedDetectedAt;
  final String? deprecatedRemindAfter;
  final String? deprecatedClearedAt;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'deviceId': deviceId,
        'updatedAt': updatedAt,
        'files': files.map((key, value) => MapEntry(key, value.toJson())),
        if (deprecatedFiles.isNotEmpty) 'deprecatedFiles': deprecatedFiles,
        if (deprecatedDetectedAt != null)
          'deprecatedDetectedAt': deprecatedDetectedAt,
        if (deprecatedRemindAfter != null)
          'deprecatedRemindAfter': deprecatedRemindAfter,
        if (deprecatedClearedAt != null)
          'deprecatedClearedAt': deprecatedClearedAt,
      };

  factory WebDavSyncMeta.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return fallback;
    }

    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String) return raw;
      return fallback;
    }

    final rawFiles = json['files'];
    final files = <String, WebDavFileMeta>{};
    if (rawFiles is Map) {
      for (final entry in rawFiles.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is Map) {
          files[key] = WebDavFileMeta.fromJson(value.cast<String, dynamic>());
        }
      }
    }

    final deprecatedFiles = <String>[];
    final rawDeprecated = json['deprecatedFiles'];
    if (rawDeprecated is List) {
      for (final item in rawDeprecated) {
        if (item is String && item.trim().isNotEmpty) {
          deprecatedFiles.add(item);
        }
      }
    }

    final detectedAt = readString('deprecatedDetectedAt', '');
    final remindAfter = readString('deprecatedRemindAfter', '');
    final clearedAt = readString('deprecatedClearedAt', '');

    return WebDavSyncMeta(
      schemaVersion: readInt('schemaVersion', 1),
      deviceId: readString('deviceId', ''),
      updatedAt: readString('updatedAt', ''),
      files: files,
      deprecatedFiles: deprecatedFiles,
      deprecatedDetectedAt: detectedAt.trim().isEmpty ? null : detectedAt,
      deprecatedRemindAfter: remindAfter.trim().isEmpty ? null : remindAfter,
      deprecatedClearedAt: clearedAt.trim().isEmpty ? null : clearedAt,
    );
  }
}
