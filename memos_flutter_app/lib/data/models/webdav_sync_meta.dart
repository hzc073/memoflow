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
  });

  final int schemaVersion;
  final String deviceId;
  final String updatedAt;
  final Map<String, WebDavFileMeta> files;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'deviceId': deviceId,
        'updatedAt': updatedAt,
        'files': files.map((key, value) => MapEntry(key, value.toJson())),
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

    return WebDavSyncMeta(
      schemaVersion: readInt('schemaVersion', 1),
      deviceId: readString('deviceId', ''),
      updatedAt: readString('updatedAt', ''),
      files: files,
    );
  }
}
