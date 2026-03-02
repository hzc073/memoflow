class WebDavVaultConfig {
  const WebDavVaultConfig({
    required this.schemaVersion,
    required this.createdAt,
    required this.keyId,
    required this.kdf,
    required this.wrappedKey,
    this.recovery,
  });

  final int schemaVersion;
  final String createdAt;
  final String keyId;
  final WebDavVaultKdf kdf;
  final WebDavVaultWrappedKey wrappedKey;
  final WebDavVaultRecovery? recovery;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAt': createdAt,
        'keyId': keyId,
        'kdf': kdf.toJson(),
        'wrappedKey': wrappedKey.toJson(),
        if (recovery != null) 'recovery': recovery!.toJson(),
      };

  factory WebDavVaultConfig.fromJson(Map<String, dynamic> json) {
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
    final recoveryRaw = json['recovery'];
    return WebDavVaultConfig(
      schemaVersion: readInt('schemaVersion', 1),
      createdAt: readString('createdAt', ''),
      keyId: readString('keyId', ''),
      kdf: kdfRaw is Map
          ? WebDavVaultKdf.fromJson(kdfRaw.cast<String, dynamic>())
          : WebDavVaultKdf.defaults,
      wrappedKey: wrappedRaw is Map
          ? WebDavVaultWrappedKey.fromJson(wrappedRaw.cast<String, dynamic>())
          : const WebDavVaultWrappedKey(nonce: '', cipherText: '', mac: ''),
      recovery: recoveryRaw is Map
          ? WebDavVaultRecovery.fromJson(recoveryRaw.cast<String, dynamic>())
          : null,
    );
  }
}

class WebDavVaultRecovery {
  const WebDavVaultRecovery({required this.kdf, required this.wrappedKey});

  final WebDavVaultKdf kdf;
  final WebDavVaultWrappedKey wrappedKey;

  Map<String, dynamic> toJson() => {
        'kdf': kdf.toJson(),
        'wrappedKey': wrappedKey.toJson(),
      };

  factory WebDavVaultRecovery.fromJson(Map<String, dynamic> json) {
    final kdfRaw = json['kdf'];
    final wrappedRaw = json['wrappedKey'];
    return WebDavVaultRecovery(
      kdf: kdfRaw is Map
          ? WebDavVaultKdf.fromJson(kdfRaw.cast<String, dynamic>())
          : WebDavVaultKdf.defaults,
      wrappedKey: wrappedRaw is Map
          ? WebDavVaultWrappedKey.fromJson(wrappedRaw.cast<String, dynamic>())
          : const WebDavVaultWrappedKey(nonce: '', cipherText: '', mac: ''),
    );
  }
}

class WebDavVaultKdf {
  const WebDavVaultKdf({
    required this.salt,
    required this.iterations,
    required this.hash,
    required this.length,
  });

  final String salt;
  final int iterations;
  final String hash;
  final int length;

  static const defaults = WebDavVaultKdf(
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

  factory WebDavVaultKdf.fromJson(Map<String, dynamic> json) {
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

    return WebDavVaultKdf(
      salt: readString('salt', ''),
      iterations: readInt('iterations', WebDavVaultKdf.defaults.iterations),
      hash: readString('hash', WebDavVaultKdf.defaults.hash),
      length: readInt('length', WebDavVaultKdf.defaults.length),
    );
  }
}

class WebDavVaultWrappedKey {
  const WebDavVaultWrappedKey({
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

  factory WebDavVaultWrappedKey.fromJson(Map<String, dynamic> json) {
    String readString(String key, String fallback) {
      final raw = json[key];
      if (raw is String) return raw;
      return fallback;
    }

    return WebDavVaultWrappedKey(
      nonce: readString('nonce', ''),
      cipherText: readString('cipherText', ''),
      mac: readString('mac', ''),
    );
  }
}

class WebDavVaultEncryptedPayload {
  const WebDavVaultEncryptedPayload({
    required this.schemaVersion,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final int schemaVersion;
  final String nonce;
  final String cipherText;
  final String mac;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'nonce': nonce,
        'cipherText': cipherText,
        'mac': mac,
      };

  factory WebDavVaultEncryptedPayload.fromJson(Map<String, dynamic> json) {
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

    return WebDavVaultEncryptedPayload(
      schemaVersion: readInt('schemaVersion', 1),
      nonce: readString('nonce', ''),
      cipherText: readString('cipherText', ''),
      mac: readString('mac', ''),
    );
  }
}
