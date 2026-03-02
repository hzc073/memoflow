import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/hash.dart';
import '../../core/webdav_url.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/models/webdav_vault.dart';
import '../../data/webdav/webdav_client.dart';
import 'sync_error.dart';

typedef WebDavVaultClientFactory = WebDavClient Function({
  required Uri baseUrl,
  required WebDavSettings settings,
});

class WebDavVaultService {
  WebDavVaultService({WebDavVaultClientFactory? clientFactory})
      : _clientFactory = clientFactory ?? _defaultClientFactory;

  static const _vaultDir = 'vault';
  static const _vaultConfigFile = 'config.json';
  static const _legacyBackupDir = 'backup';
  static const _legacyBackupVersion = 'v1';
  static const _legacyBackupConfigFile = 'config.json';
  static const _nonceLength = 12;
  static const _macLength = 16;

  final WebDavVaultClientFactory _clientFactory;
  final _cipher = AesGcm.with256bits();
  final _random = Random.secure();

  Future<WebDavVaultConfig?> loadConfig({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) return null;
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _clientFactory(baseUrl: baseUrl, settings: settings);
    try {
      final uri = _vaultConfigUri(baseUrl, rootPath, accountId);
      final res = await client.get(uri);
      if (res.statusCode == 404) return null;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw _httpError(statusCode: res.statusCode, uri: uri, method: 'GET');
      }
      final decoded = jsonDecode(res.bodyText);
      if (decoded is Map) {
        return WebDavVaultConfig.fromJson(decoded.cast<String, dynamic>());
      }
      throw _keyedError(
        'legacy.webdav.config_corrupted',
        code: SyncErrorCode.dataCorrupt,
      );
    } finally {
      await client.close();
    }
  }

  Future<WebDavBackupConfig?> loadLegacyBackupConfig({
    required WebDavSettings settings,
    required String? accountKey,
  }) async {
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) return null;
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _clientFactory(baseUrl: baseUrl, settings: settings);
    try {
      final uri = _legacyBackupConfigUri(baseUrl, rootPath, accountId);
      final res = await client.get(uri);
      if (res.statusCode == 404) return null;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw _httpError(statusCode: res.statusCode, uri: uri, method: 'GET');
      }
      final decoded = jsonDecode(res.bodyText);
      if (decoded is Map) {
        return WebDavBackupConfig.fromJson(decoded.cast<String, dynamic>());
      }
      throw _keyedError(
        'legacy.webdav.config_corrupted',
        code: SyncErrorCode.dataCorrupt,
      );
    } finally {
      await client.close();
    }
  }

  Future<String> setupVault({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
    List<int>? masterKeyOverride,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_password_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_account_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }

    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _clientFactory(baseUrl: baseUrl, settings: settings);
    try {
      await _ensureVaultCollections(client, baseUrl, rootPath, accountId);
      final masterKey = masterKeyOverride ?? _randomBytes(32);
      final bundle = await _buildWrappedKeyBundle(
        secret: normalizedPassword,
        masterKey: masterKey,
      );
      final recoveryBundle = await _buildRecoveryBundle(masterKey);
      final config = WebDavVaultConfig(
        schemaVersion: 1,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        keyId: _generateKeyId(),
        kdf: bundle.kdf,
        wrappedKey: bundle.wrappedKey,
        recovery: recoveryBundle.recovery,
      );
      await _saveConfig(client, baseUrl, rootPath, accountId, config);
      return recoveryBundle.recoveryCode;
    } finally {
      await client.close();
    }
  }

  Future<String> recoverVaultPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final normalizedPassword = newPassword.trim();
    if (normalizedPassword.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_password_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_account_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _clientFactory(baseUrl: baseUrl, settings: settings);
    try {
      await _ensureVaultCollections(client, baseUrl, rootPath, accountId);
      final config = await _loadConfig(client, baseUrl, rootPath, accountId);
      if (config == null) {
        throw _keyedError(
          'legacy.msg_no_backups_found',
          code: SyncErrorCode.unknown,
        );
      }
      final masterKey = await resolveMasterKeyWithRecoveryCode(
        recoveryCode,
        config,
      );
      final masterBytes = await masterKey.extractBytes();
      final bundle = await _buildWrappedKeyBundle(
        secret: normalizedPassword,
        masterKey: masterBytes,
      );
      final recoveryBundle = await _buildRecoveryBundle(masterBytes);
      final updated = WebDavVaultConfig(
        schemaVersion: config.schemaVersion,
        createdAt: config.createdAt,
        keyId: config.keyId.isNotEmpty ? config.keyId : _generateKeyId(),
        kdf: bundle.kdf,
        wrappedKey: bundle.wrappedKey,
        recovery: recoveryBundle.recovery,
      );
      await _saveConfig(client, baseUrl, rootPath, accountId, updated);
      return recoveryBundle.recoveryCode;
    } finally {
      await client.close();
    }
  }

  Future<SecretKey> resolveMasterKey(
    String password,
    WebDavVaultConfig config,
  ) async {
    final kdf = config.kdf;
    if (kdf.salt.isEmpty) {
      throw _keyedError(
        'legacy.webdav.config_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kek = await _deriveKeyFromPassword(password, kdf);
    final wrapped = config.wrappedKey;
    try {
      final box = SecretBox(
        base64Decode(wrapped.cipherText),
        nonce: base64Decode(wrapped.nonce),
        mac: Mac(base64Decode(wrapped.mac)),
      );
      final clear = await _cipher.decrypt(box, secretKey: kek);
      return SecretKey(clear);
    } catch (_) {
      throw _keyedError(
        'legacy.webdav.password_invalid',
        code: SyncErrorCode.authFailed,
      );
    }
  }

  Future<SecretKey> resolveMasterKeyWithRecoveryCode(
    String recoveryCode,
    WebDavVaultConfig config,
  ) async {
    final recovery = config.recovery;
    if (recovery == null) {
      throw _keyedError(
        'legacy.webdav.recovery_not_configured',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final normalized = _normalizeRecoveryCode(recoveryCode);
    if (normalized.isEmpty) {
      throw _keyedError(
        'legacy.webdav.recovery_code_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kdf = recovery.kdf;
    if (kdf.salt.isEmpty) {
      throw _keyedError(
        'legacy.webdav.config_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kek = await _deriveKeyFromPassword(normalized, kdf);
    final wrapped = recovery.wrappedKey;
    try {
      final box = SecretBox(
        base64Decode(wrapped.cipherText),
        nonce: base64Decode(wrapped.nonce),
        mac: Mac(base64Decode(wrapped.mac)),
      );
      final clear = await _cipher.decrypt(box, secretKey: kek);
      return SecretKey(clear);
    } catch (_) {
      throw _keyedError(
        'legacy.webdav.recovery_code_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
  }

  Future<SecretKey> resolveLegacyMasterKey({
    required String password,
    required WebDavBackupConfig config,
  }) async {
    final kdf = config.kdf;
    if (kdf.salt.isEmpty) {
      throw _keyedError(
        'legacy.webdav.config_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kek = await _deriveLegacyKeyFromPassword(password, kdf);
    final wrapped = config.wrappedKey;
    try {
      final box = SecretBox(
        base64Decode(wrapped.cipherText),
        nonce: base64Decode(wrapped.nonce),
        mac: Mac(base64Decode(wrapped.mac)),
      );
      final clear = await _cipher.decrypt(box, secretKey: kek);
      return SecretKey(clear);
    } catch (_) {
      throw _keyedError(
        'legacy.webdav.password_invalid',
        code: SyncErrorCode.authFailed,
      );
    }
  }

  Future<WebDavVaultEncryptedPayload> encryptJsonPayload({
    required SecretKey masterKey,
    required String info,
    required Map<String, dynamic> payload,
  }) async {
    final key = await _deriveSubKey(masterKey, info);
    final encoded = utf8.encode(jsonEncode(payload));
    final box = await _cipher.encrypt(
      encoded,
      secretKey: key,
      nonce: _randomBytes(_nonceLength),
    );
    return WebDavVaultEncryptedPayload(
      schemaVersion: 1,
      nonce: base64Encode(box.nonce),
      cipherText: base64Encode(box.cipherText),
      mac: base64Encode(box.mac.bytes),
    );
  }

  Future<Map<String, dynamic>> decryptJsonPayload({
    required SecretKey masterKey,
    required String info,
    required WebDavVaultEncryptedPayload payload,
  }) async {
    final key = await _deriveSubKey(masterKey, info);
    final box = SecretBox(
      base64Decode(payload.cipherText),
      nonce: base64Decode(payload.nonce),
      mac: Mac(base64Decode(payload.mac)),
    );
    final plain = await _cipher.decrypt(box, secretKey: key);
    final decoded = jsonDecode(utf8.decode(plain, allowMalformed: true));
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw _keyedError(
      'legacy.webdav.data_corrupted',
      code: SyncErrorCode.dataCorrupt,
    );
  }

  Future<void> deleteDeprecatedFiles({
    required WebDavSettings settings,
    required String? accountKey,
    required List<String> files,
  }) async {
    if (files.isEmpty) return;
    final normalizedAccountKey = accountKey?.trim() ?? '';
    if (normalizedAccountKey.isEmpty) return;
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(normalizedAccountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _clientFactory(baseUrl: baseUrl, settings: settings);
    try {
      for (final name in files) {
        final uri = _fileUri(baseUrl, rootPath, accountId, name);
        final res = await client.delete(uri);
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw _httpError(statusCode: res.statusCode, uri: uri, method: 'DELETE');
        }
      }
    } finally {
      await client.close();
    }
  }

  Future<WebDavVaultConfig?> _loadConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final uri = _vaultConfigUri(baseUrl, rootPath, accountId);
    final res = await client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(statusCode: res.statusCode, uri: uri, method: 'GET');
    }
    final decoded = jsonDecode(res.bodyText);
    if (decoded is Map) {
      return WebDavVaultConfig.fromJson(decoded.cast<String, dynamic>());
    }
    throw _keyedError(
      'legacy.webdav.config_corrupted',
      code: SyncErrorCode.dataCorrupt,
    );
  }

  Future<void> _saveConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    WebDavVaultConfig config,
  ) async {
    final uri = _vaultConfigUri(baseUrl, rootPath, accountId);
    final bytes = utf8.encode(jsonEncode(config.toJson()));
    final res = await client.put(uri, body: bytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _httpError(statusCode: res.statusCode, uri: uri, method: 'PUT');
    }
  }

  Future<void> _ensureVaultCollections(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final segments = <String>[
      ..._splitPath(rootPath),
      'accounts',
      accountId,
      _vaultDir,
    ];
    await _ensureCollectionPath(client, baseUrl, segments);
  }

  Future<void> _ensureCollectionPath(
    WebDavClient client,
    Uri baseUrl,
    List<String> segments,
  ) async {
    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      final uri = joinWebDavUri(
        baseUrl: baseUrl,
        rootPath: '',
        relativePath: current,
      );
      final res = await client.mkcol(uri);
      if (res.statusCode == 201 ||
          res.statusCode == 405 ||
          res.statusCode == 200 ||
          res.statusCode == 409) {
        continue;
      }
      throw _httpError(statusCode: res.statusCode, uri: uri, method: 'MKCOL');
    }
  }

  WebDavVaultKdf _buildKdf() {
    final salt = _randomBytes(16);
    return WebDavVaultKdf(
      salt: base64Encode(salt),
      iterations: WebDavVaultKdf.defaults.iterations,
      hash: WebDavVaultKdf.defaults.hash,
      length: WebDavVaultKdf.defaults.length,
    );
  }

  String _generateRecoveryCode() {
    final bytes = _randomBytes(20);
    final compact = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return _formatRecoveryCode(compact);
  }

  String _generateKeyId() {
    final bytes = _randomBytes(16);
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String _normalizeRecoveryCode(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  }

  String _formatRecoveryCode(String compact) {
    if (compact.isEmpty) return compact;
    final groups = <String>[];
    for (var i = 0; i < compact.length; i += 4) {
      final end = i + 4;
      groups.add(
        compact.substring(i, end > compact.length ? compact.length : end),
      );
    }
    return groups.join('-');
  }

  Future<_VaultWrappedKeyBundle> _buildWrappedKeyBundle({
    required String secret,
    required List<int> masterKey,
  }) async {
    final normalizedSecret = secret.trim();
    if (normalizedSecret.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_password_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final kdf = _buildKdf();
    final kek = await _deriveKeyFromPassword(normalizedSecret, kdf);
    final box = await _cipher.encrypt(
      masterKey,
      secretKey: kek,
      nonce: _randomBytes(_nonceLength),
    );
    return _VaultWrappedKeyBundle(
      kdf: kdf,
      wrappedKey: WebDavVaultWrappedKey(
        nonce: base64Encode(box.nonce),
        cipherText: base64Encode(box.cipherText),
        mac: base64Encode(box.mac.bytes),
      ),
    );
  }

  Future<_VaultRecoveryBundle> _buildRecoveryBundle(List<int> masterKey) async {
    final recoveryCode = _generateRecoveryCode();
    final recoveryBundle = await _buildWrappedKeyBundle(
      secret: _normalizeRecoveryCode(recoveryCode),
      masterKey: masterKey,
    );
    return _VaultRecoveryBundle(
      recoveryCode: recoveryCode,
      recovery: WebDavVaultRecovery(
        kdf: recoveryBundle.kdf,
        wrappedKey: recoveryBundle.wrappedKey,
      ),
    );
  }

  Future<SecretKey> _deriveKeyFromPassword(
    String password,
    WebDavVaultKdf kdf,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdf.iterations,
      bits: kdf.length * 8,
    );
    final salt = base64Decode(kdf.salt);
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  Future<SecretKey> _deriveLegacyKeyFromPassword(
    String password,
    WebDavBackupKdf kdf,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdf.iterations,
      bits: kdf.length * 8,
    );
    final salt = base64Decode(kdf.salt);
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  Future<SecretKey> _deriveSubKey(SecretKey masterKey, String info) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: masterKey,
      nonce: utf8.encode('MemoFlowVault'),
      info: utf8.encode(info),
    );
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Uri _vaultConfigUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: 'accounts/$accountId/$_vaultDir/$_vaultConfigFile',
    );
  }

  Uri _legacyBackupConfigUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: 'accounts/$accountId/$_legacyBackupDir/$_legacyBackupVersion/$_legacyBackupConfigFile',
    );
  }

  Uri _fileUri(Uri baseUrl, String rootPath, String accountId, String name) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: 'accounts/$accountId/$name',
    );
  }

  List<String> _splitPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split('/')
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
  }

  Uri _parseBaseUrl(String raw) {
    final baseUrl = Uri.tryParse(raw.trim());
    if (baseUrl == null || !baseUrl.hasScheme || !baseUrl.hasAuthority) {
      throw _keyedError(
        'legacy.msg_invalid_webdav_server_url',
        code: SyncErrorCode.invalidConfig,
      );
    }
    return baseUrl;
  }

  SyncError _httpError({
    required int statusCode,
    required Uri uri,
    required String method,
  }) {
    final code = switch (statusCode) {
      401 => SyncErrorCode.authFailed,
      403 => SyncErrorCode.permission,
      >= 500 => SyncErrorCode.server,
      _ => SyncErrorCode.unknown,
    };
    return SyncError(
      code: code,
      retryable: statusCode >= 500,
      message: 'Bad state: WebDAV $method failed (HTTP $statusCode)',
      httpStatus: statusCode,
    );
  }

  SyncError _keyedError(String key, {required SyncErrorCode code}) {
    return SyncError(
      code: code,
      retryable: false,
      presentationKey: key,
    );
  }
}

class _VaultWrappedKeyBundle {
  const _VaultWrappedKeyBundle({required this.kdf, required this.wrappedKey});

  final WebDavVaultKdf kdf;
  final WebDavVaultWrappedKey wrappedKey;
}

class _VaultRecoveryBundle {
  const _VaultRecoveryBundle({
    required this.recoveryCode,
    required this.recovery,
  });

  final String recoveryCode;
  final WebDavVaultRecovery recovery;
}

WebDavClient _defaultClientFactory({
  required Uri baseUrl,
  required WebDavSettings settings,
}) {
  return WebDavClient(
    baseUrl: baseUrl,
    username: settings.username,
    password: settings.password,
    authMode: settings.authMode,
    ignoreBadCert: settings.ignoreTlsErrors,
  );
}
