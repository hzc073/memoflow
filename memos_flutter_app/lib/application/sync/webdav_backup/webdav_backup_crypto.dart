part of '../webdav_backup_service.dart';

mixin _WebDavBackupCryptoMixin on _WebDavBackupServiceBase {
  Future<String?> setupBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String password,
  }) async {
    final resolvedPassword = password.trim();
    if (resolvedPassword.isEmpty) {
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
    final client = _buildClient(settings, baseUrl);
    try {
      await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
      final existing = await _loadConfig(client, baseUrl, rootPath, accountId);
      if (existing == null) {
        final created = await _createConfigWithRecovery(resolvedPassword);
        await _saveConfig(client, baseUrl, rootPath, accountId, created.config);
        return created.recoveryCode;
      }

      final masterKey = await _resolveMasterKey(resolvedPassword, existing);
      if (existing.recovery != null) return null;
      final recovery = await _buildRecoveryBundle(masterKey);
      final updated = WebDavBackupConfig(
        schemaVersion: existing.schemaVersion,
        createdAt: existing.createdAt,
        kdf: existing.kdf,
        wrappedKey: existing.wrappedKey,
        recovery: recovery.recovery,
      );
      await _saveConfig(client, baseUrl, rootPath, accountId, updated);
      return recovery.recoveryCode;
    } finally {
      await client.close();
    }
  }

  Future<String> recoverBackupPassword({
    required WebDavSettings settings,
    required String? accountKey,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final resolvedPassword = newPassword.trim();
    final normalizedRecoveryCode = _normalizeRecoveryCode(recoveryCode);
    if (resolvedPassword.isEmpty) {
      throw _keyedError(
        'legacy.webdav.backup_password_missing',
        code: SyncErrorCode.invalidConfig,
      );
    }
    if (normalizedRecoveryCode.isEmpty) {
      throw _keyedError(
        'legacy.webdav.recovery_code_invalid',
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
    final client = _buildClient(settings, baseUrl);
    try {
      await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
      final config = await _loadConfig(client, baseUrl, rootPath, accountId);
      if (config == null) {
        throw _keyedError(
          'legacy.msg_no_backups_found',
          code: SyncErrorCode.unknown,
        );
      }
      final masterKey = await _resolveMasterKeyWithRecoveryCode(
        normalizedRecoveryCode,
        config,
      );
      final masterKeyBytes = await masterKey.extractBytes();
      final passwordBundle = await _buildWrappedKeyBundle(
        secret: resolvedPassword,
        masterKey: masterKeyBytes,
      );
      final recoveryBundle = await _buildRecoveryBundle(masterKey);
      final updated = WebDavBackupConfig(
        schemaVersion: config.schemaVersion,
        createdAt: config.createdAt,
        kdf: passwordBundle.kdf,
        wrappedKey: passwordBundle.wrappedKey,
        recovery: recoveryBundle.recovery,
      );
      await _saveConfig(client, baseUrl, rootPath, accountId, updated);
      return recoveryBundle.recoveryCode;
    } finally {
      await client.close();
    }
  }

  @override
  Future<WebDavBackupConfig> _loadOrCreateConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    String password,
  ) async {
    final existing = await _loadConfig(client, baseUrl, rootPath, accountId);
    if (existing != null) return existing;
    final config = await _createConfig(password);
    await _saveConfig(client, baseUrl, rootPath, accountId, config);
    return config;
  }

  Future<WebDavBackupConfig> _createConfig(String password) async {
    final masterKey = _randomBytes(32);
    final passwordBundle = await _buildWrappedKeyBundle(
      secret: password,
      masterKey: masterKey,
    );
    return WebDavBackupConfig(
      schemaVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      kdf: passwordBundle.kdf,
      wrappedKey: passwordBundle.wrappedKey,
    );
  }

  Future<_CreatedConfigWithRecovery> _createConfigWithRecovery(
    String password,
  ) async {
    final masterKey = _randomBytes(32);
    final passwordBundle = await _buildWrappedKeyBundle(
      secret: password,
      masterKey: masterKey,
    );
    final recoveryCode = _generateRecoveryCode();
    final recoveryBundle = await _buildWrappedKeyBundle(
      secret: _normalizeRecoveryCode(recoveryCode),
      masterKey: masterKey,
    );
    final config = WebDavBackupConfig(
      schemaVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      kdf: passwordBundle.kdf,
      wrappedKey: passwordBundle.wrappedKey,
      recovery: WebDavBackupRecovery(
        kdf: recoveryBundle.kdf,
        wrappedKey: recoveryBundle.wrappedKey,
      ),
    );
    return _CreatedConfigWithRecovery(
      config: config,
      recoveryCode: recoveryCode,
    );
  }

  Future<_RecoveryBundle> _buildRecoveryBundle(SecretKey masterKey) async {
    final masterBytes = await masterKey.extractBytes();
    final recoveryCode = _generateRecoveryCode();
    final recoveryBundle = await _buildWrappedKeyBundle(
      secret: _normalizeRecoveryCode(recoveryCode),
      masterKey: masterBytes,
    );
    return _RecoveryBundle(
      recoveryCode: recoveryCode,
      recovery: WebDavBackupRecovery(
        kdf: recoveryBundle.kdf,
        wrappedKey: recoveryBundle.wrappedKey,
      ),
    );
  }

  Future<_WrappedKeyBundle> _buildWrappedKeyBundle({
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
    return _WrappedKeyBundle(
      kdf: kdf,
      wrappedKey: WebDavBackupWrappedKey(
        nonce: base64Encode(box.nonce),
        cipherText: base64Encode(box.cipherText),
        mac: base64Encode(box.mac.bytes),
      ),
    );
  }

  WebDavBackupKdf _buildKdf() {
    final salt = _randomBytes(16);
    return WebDavBackupKdf(
      salt: base64Encode(salt),
      iterations: WebDavBackupKdf.defaults.iterations,
      hash: WebDavBackupKdf.defaults.hash,
      length: WebDavBackupKdf.defaults.length,
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

  @override
  Future<SecretKey> _resolveMasterKey(
    String password,
    WebDavBackupConfig config,
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

  @override
  Future<SecretKey> _resolveMasterKeyWithRecoveryCode(
    String recoveryCode,
    WebDavBackupConfig config,
  ) async {
    final recovery = config.recovery;
    if (recovery == null) {
      throw _keyedError(
        'legacy.webdav.recovery_not_configured',
        code: SyncErrorCode.invalidConfig,
      );
    }
    final normalizedCode = _normalizeRecoveryCode(recoveryCode);
    if (normalizedCode.isEmpty) {
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
    final kek = await _deriveKeyFromPassword(normalizedCode, kdf);
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

  @override
  Future<SecretKey> _deriveKeyFromPassword(
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

  @override
  Future<SecretKey> _deriveSubKey(SecretKey masterKey, String info) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: masterKey,
      nonce: utf8.encode('MemoFlowBackup'),
      info: utf8.encode(info),
    );
  }

  @override
  Future<SecretKey> _deriveObjectKey(SecretKey masterKey, String objectHash) {
    return _deriveSubKey(masterKey, 'object:$objectHash');
  }

  @override
  Future<Uint8List> _encryptBytes(SecretKey key, List<int> plain) async {
    final box = await _cipher.encrypt(
      plain,
      secretKey: key,
      nonce: _randomBytes(_nonceLength),
    );
    final bytes = Uint8List(
      box.nonce.length + box.cipherText.length + box.mac.bytes.length,
    );
    bytes.setRange(0, box.nonce.length, box.nonce);
    bytes.setRange(
      box.nonce.length,
      box.nonce.length + box.cipherText.length,
      box.cipherText,
    );
    bytes.setRange(
      box.nonce.length + box.cipherText.length,
      box.nonce.length + box.cipherText.length + box.mac.bytes.length,
      box.mac.bytes,
    );
    return bytes;
  }

  @override
  Future<Uint8List> _decryptBytes(SecretKey key, List<int> combined) async {
    if (combined.length < _nonceLength + _macLength) {
      throw _keyedError(
        'legacy.webdav.data_corrupted',
        code: SyncErrorCode.dataCorrupt,
      );
    }
    final nonce = combined.sublist(0, _nonceLength);
    final macBytes = combined.sublist(combined.length - _macLength);
    final cipherText = combined.sublist(
      _nonceLength,
      combined.length - _macLength,
    );
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final plain = await _cipher.decrypt(box, secretKey: key);
    return Uint8List.fromList(plain);
  }

  @override
  Future<Uint8List> _encryptJson(
    SecretKey key,
    Map<String, dynamic> json,
  ) async {
    final encoded = jsonEncode(json);
    return _encryptBytes(key, utf8.encode(encoded));
  }

  @override
  Future<dynamic> _decryptJson(SecretKey key, List<int> data) async {
    final plain = await _decryptBytes(key, data);
    return jsonDecode(utf8.decode(plain, allowMalformed: true));
  }

  @override
  Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  @override
  Future<String?> _resolvePassword(String? override) async {
    if (override != null && override.trim().isNotEmpty) return override;
    return _passwordRepository.read();
  }

  @override
  Future<String?> _resolveVaultPassword(String? override) async {
    if (override != null && override.trim().isNotEmpty) return override;
    return _vaultPasswordRepository.read();
  }

  @override
  Future<SecretKey> _resolveMasterKeyFromLegacy({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required String password,
  }) async {
    final config = await _loadConfig(client, baseUrl, rootPath, accountId);
    if (config == null) {
      throw _keyedError(
        'legacy.msg_no_backups_found',
        code: SyncErrorCode.unknown,
      );
    }
    return _resolveMasterKey(password, config);
  }

  @override
  Future<SecretKey> _resolveVaultMasterKey({
    required WebDavSettings settings,
    required String accountKey,
    required String password,
  }) async {
    final config = await _vaultService.loadConfig(
      settings: settings,
      accountKey: accountKey,
    );
    if (config == null) {
      throw _keyedError(
        'legacy.webdav.config_invalid',
        code: SyncErrorCode.invalidConfig,
      );
    }
    return _vaultService.resolveMasterKey(password, config);
  }

  @override
  Future<void> _decryptObject({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required String hash,
  }) async {
    final objectData = await _getBytes(
      client,
      _objectUri(baseUrl, rootPath, accountId, hash),
    );
    if (objectData == null) {
      throw _keyedError(
        'legacy.webdav.object_missing',
        code: SyncErrorCode.dataCorrupt,
      );
    }
    final key = await _deriveObjectKey(masterKey, hash);
    await _decryptBytes(key, objectData);
  }
}
