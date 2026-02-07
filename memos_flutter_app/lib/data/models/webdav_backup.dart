class WebDavBackupConfig {
  const WebDavBackupConfig({
    required this.schemaVersion,
    required this.createdAt,
    required this.kdf,
    required this.wrappedKey,
  });

  final int schemaVersion;
  final String createdAt;
  final WebDavBackupKdf kdf;
  final WebDavBackupWrappedKey wrappedKey;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'createdAt': createdAt,
    'kdf': kdf.toJson(),
    'wrappedKey': wrappedKey.toJson(),
  };

  factory WebDavBackupConfig.fromJson(Map<String, dynamic> json) {
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

    final kdfRaw = json['kdf'];
    final wrappedRaw = json['wrappedKey'];
    return WebDavBackupConfig(
      schemaVersion: readInt('schemaVersion', 1),
      createdAt: readString('createdAt', ''),
      kdf: kdfRaw is Map
          ? WebDavBackupKdf.fromJson(kdfRaw.cast<String, dynamic>())
          : WebDavBackupKdf.defaults,
      wrappedKey: wrappedRaw is Map
          ? WebDavBackupWrappedKey.fromJson(wrappedRaw.cast<String, dynamic>())
          : const WebDavBackupWrappedKey(nonce: '', cipherText: '', mac: ''),
    );
  }
}

class WebDavBackupKdf {
  const WebDavBackupKdf({
    required this.salt,
    required this.iterations,
    required this.hash,
    required this.length,
  });

  final String salt;
  final int iterations;
  final String hash;
  final int length;

  static const defaults = WebDavBackupKdf(
    salt: '',
    iterations: 200000,
    hash: 'sha256',
    length: 32,
  );

  Map<String, dynamic> toJson() => {
    'salt': salt,
    'iterations': iterations,
    'hash': hash,
    'length': length,
  };

  factory WebDavBackupKdf.fromJson(Map<String, dynamic> json) {
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

    return WebDavBackupKdf(
      salt: readString('salt', ''),
      iterations: readInt('iterations', WebDavBackupKdf.defaults.iterations),
      hash: readString('hash', WebDavBackupKdf.defaults.hash),
      length: readInt('length', WebDavBackupKdf.defaults.length),
    );
  }
}

class WebDavBackupWrappedKey {
  const WebDavBackupWrappedKey({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final String nonce;
  final String cipherText;
  final String mac;

  Map<String, dynamic> toJson() => {
    'nonce': nonce,
    'cipherText': cipherText,
    'mac': mac,
  };

  factory WebDavBackupWrappedKey.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String) return raw;
      return fallback;
    }

    return WebDavBackupWrappedKey(
      nonce: readString('nonce', ''),
      cipherText: readString('cipherText', ''),
      mac: readString('mac', ''),
    );
  }
}

class WebDavBackupIndex {
  const WebDavBackupIndex({
    required this.schemaVersion,
    required this.updatedAt,
    required this.snapshots,
    required this.objects,
  });

  final int schemaVersion;
  final String updatedAt;
  final List<WebDavBackupSnapshotInfo> snapshots;
  final Map<String, WebDavBackupObjectInfo> objects;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'updatedAt': updatedAt,
    'snapshots': snapshots.map((s) => s.toJson()).toList(growable: false),
    'objects': objects.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory WebDavBackupIndex.fromJson(Map<String, dynamic> json) {
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

    final snapshots = <WebDavBackupSnapshotInfo>[];
    final rawSnapshots = json['snapshots'];
    if (rawSnapshots is List) {
      for (final item in rawSnapshots) {
        if (item is Map) {
          snapshots.add(
            WebDavBackupSnapshotInfo.fromJson(item.cast<String, dynamic>()),
          );
        }
      }
    }

    final objects = <String, WebDavBackupObjectInfo>{};
    final rawObjects = json['objects'];
    if (rawObjects is Map) {
      for (final entry in rawObjects.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is Map) {
          objects[key] = WebDavBackupObjectInfo.fromJson(
            value.cast<String, dynamic>(),
          );
        }
      }
    }

    return WebDavBackupIndex(
      schemaVersion: readInt('schemaVersion', 1),
      updatedAt: readString('updatedAt', ''),
      snapshots: snapshots,
      objects: objects,
    );
  }

  static const empty = WebDavBackupIndex(
    schemaVersion: 1,
    updatedAt: '',
    snapshots: [],
    objects: {},
  );
}

class WebDavBackupSnapshotInfo {
  const WebDavBackupSnapshotInfo({
    required this.id,
    required this.createdAt,
    required this.memosCount,
    required this.fileCount,
    required this.totalBytes,
  });

  final String id;
  final String createdAt;
  final int memosCount;
  final int fileCount;
  final int totalBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt,
    'memosCount': memosCount,
    'fileCount': fileCount,
    'totalBytes': totalBytes,
  };

  factory WebDavBackupSnapshotInfo.fromJson(Map<String, dynamic> json) {
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

    return WebDavBackupSnapshotInfo(
      id: readString('id', ''),
      createdAt: readString('createdAt', ''),
      memosCount: readInt('memosCount', 0),
      fileCount: readInt('fileCount', 0),
      totalBytes: readInt('totalBytes', 0),
    );
  }
}

class WebDavBackupObjectInfo {
  const WebDavBackupObjectInfo({required this.size, required this.refs});

  final int size;
  final int refs;

  Map<String, dynamic> toJson() => {'size': size, 'refs': refs};

  factory WebDavBackupObjectInfo.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return fallback;
    }

    return WebDavBackupObjectInfo(
      size: readInt('size', 0),
      refs: readInt('refs', 0),
    );
  }
}

class WebDavBackupSnapshot {
  const WebDavBackupSnapshot({
    required this.schemaVersion,
    required this.id,
    required this.createdAt,
    required this.files,
  });

  final int schemaVersion;
  final String id;
  final String createdAt;
  final List<WebDavBackupFileEntry> files;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'createdAt': createdAt,
    'files': files.map((f) => f.toJson()).toList(growable: false),
  };

  factory WebDavBackupSnapshot.fromJson(Map<String, dynamic> json) {
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

    final files = <WebDavBackupFileEntry>[];
    final rawFiles = json['files'];
    if (rawFiles is List) {
      for (final item in rawFiles) {
        if (item is Map) {
          files.add(
            WebDavBackupFileEntry.fromJson(item.cast<String, dynamic>()),
          );
        }
      }
    }

    return WebDavBackupSnapshot(
      schemaVersion: readInt('schemaVersion', 1),
      id: readString('id', ''),
      createdAt: readString('createdAt', ''),
      files: files,
    );
  }
}

class WebDavBackupFileEntry {
  const WebDavBackupFileEntry({
    required this.path,
    required this.size,
    required this.objects,
    this.modifiedAt,
  });

  final String path;
  final int size;
  final List<String> objects;
  final String? modifiedAt;

  Map<String, dynamic> toJson() => {
    'path': path,
    'size': size,
    'objects': objects,
    if (modifiedAt != null) 'modifiedAt': modifiedAt,
  };

  factory WebDavBackupFileEntry.fromJson(Map<String, dynamic> json) {
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

    List<String> readList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw.whereType<String>().toList(growable: false);
      }
      return const [];
    }

    final modifiedRaw = json['modifiedAt'];
    final modifiedAt = modifiedRaw is String ? modifiedRaw : null;

    return WebDavBackupFileEntry(
      path: readString('path', ''),
      size: readInt('size', 0),
      objects: readList('objects'),
      modifiedAt: modifiedAt,
    );
  }
}
