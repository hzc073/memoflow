import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_localization.dart';
import '../core/hash.dart';
import '../core/webdav_url.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/local_library/local_library_fs.dart';
import '../data/local_library/local_library_markdown.dart';
import '../data/local_library/local_library_naming.dart';
import '../data/models/local_library.dart';
import '../data/models/local_memo.dart';
import '../data/models/webdav_backup.dart';
import '../data/models/webdav_backup_state.dart';
import '../data/models/webdav_settings.dart';
import '../data/settings/webdav_backup_password_repository.dart';
import '../data/settings/webdav_backup_state_repository.dart';
import '../data/webdav/webdav_client.dart';
import 'database_provider.dart';
import 'local_library_provider.dart';
import 'local_library_scanner.dart';
import 'memos_providers.dart';
import 'preferences_provider.dart';
import 'session_provider.dart';
import 'webdav_settings_provider.dart';

final webDavBackupStateRepositoryProvider =
    Provider<WebDavBackupStateRepository>((ref) {
      final accountKey = ref.watch(
        appSessionProvider.select((state) => state.valueOrNull?.currentKey),
      );
      return WebDavBackupStateRepository(
        ref.watch(secureStorageProvider),
        accountKey: accountKey,
      );
    });

final webDavBackupPasswordRepositoryProvider =
    Provider<WebDavBackupPasswordRepository>((ref) {
      final accountKey = ref.watch(
        appSessionProvider.select((state) => state.valueOrNull?.currentKey),
      );
      return WebDavBackupPasswordRepository(
        ref.watch(secureStorageProvider),
        accountKey: accountKey,
      );
    });

final webDavBackupControllerProvider =
    StateNotifierProvider<WebDavBackupController, WebDavBackupStatus>((ref) {
      final accountKey = ref.watch(
        appSessionProvider.select((state) => state.valueOrNull?.currentKey),
      );
      return WebDavBackupController(
        ref,
        accountKey: accountKey,
        stateRepository: ref.watch(webDavBackupStateRepositoryProvider),
        passwordRepository: ref.watch(webDavBackupPasswordRepositoryProvider),
      );
    });

class WebDavBackupStatus {
  const WebDavBackupStatus({
    required this.running,
    required this.restoring,
    required this.lastBackupAt,
    required this.lastSuccessAt,
    required this.lastError,
  });

  final bool running;
  final bool restoring;
  final DateTime? lastBackupAt;
  final DateTime? lastSuccessAt;
  final String? lastError;

  WebDavBackupStatus copyWith({
    bool? running,
    bool? restoring,
    DateTime? lastBackupAt,
    DateTime? lastSuccessAt,
    String? lastError,
  }) {
    return WebDavBackupStatus(
      running: running ?? this.running,
      restoring: restoring ?? this.restoring,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: lastError,
    );
  }

  static const initial = WebDavBackupStatus(
    running: false,
    restoring: false,
    lastBackupAt: null,
    lastSuccessAt: null,
    lastError: null,
  );
}

class WebDavBackupController extends StateNotifier<WebDavBackupStatus> {
  WebDavBackupController(
    this._ref, {
    required String? accountKey,
    required WebDavBackupStateRepository stateRepository,
    required WebDavBackupPasswordRepository passwordRepository,
  }) : _accountKey = accountKey,
       _stateRepository = stateRepository,
       _passwordRepository = passwordRepository,
       super(WebDavBackupStatus.initial) {
    unawaited(_loadState());
  }

  final Ref _ref;
  final String? _accountKey;
  final WebDavBackupStateRepository _stateRepository;
  final WebDavBackupPasswordRepository _passwordRepository;

  static const _backupDir = 'backup';
  static const _backupVersion = 'v1';
  static const _backupConfigFile = 'config.json';
  static const _backupIndexFile = 'index.enc';
  static const _backupObjectsDir = 'objects';
  static const _backupSnapshotsDir = 'snapshots';
  static const _chunkSize = 4 * 1024 * 1024;
  static const _nonceLength = 12;
  static const _macLength = 16;

  final _cipher = AesGcm.with256bits();
  final _random = Random.secure();

  Future<void> _loadState() async {
    final snapshot = await _stateRepository.read();
    state = state.copyWith(lastBackupAt: _parseIso(snapshot.lastBackupAt));
  }

  Future<void> checkAndBackupOnResume() async {
    if (state.running || state.restoring) return;
    final settings = _ref.read(webDavSettingsProvider);
    if (!settings.backupEnabled) return;
    if (settings.backupSchedule == WebDavBackupSchedule.manual) return;

    final last = await _stateRepository.read();
    final lastAt = _parseIso(last.lastBackupAt);
    final due = _isBackupDue(lastAt, settings.backupSchedule);
    if (!due) return;

    final storedPassword = await _passwordRepository.read();
    if (storedPassword == null || storedPassword.trim().isEmpty) return;
    await backupNow(password: storedPassword, manual: false);
  }

  Future<void> backupNow({String? password, bool manual = true}) async {
    if (state.running || state.restoring) return;
    final settings = _ref.read(webDavSettingsProvider);
    final accountKey = _accountKey;
    final localLibrary = _ref.read(currentLocalLibraryProvider);
    if (!settings.backupEnabled) {
      if (manual) {
        state = state.copyWith(
          lastError: _localized('备份未启用', 'Backup is disabled'),
        );
      }
      return;
    }
    if (accountKey == null || accountKey.trim().isEmpty) {
      state = state.copyWith(
        lastError: _localized('账号缺失，无法备份', 'Account missing for backup'),
      );
      return;
    }
    if (localLibrary == null) {
      state = state.copyWith(
        lastError: _localized(
          '仅本地库可用备份',
          'Backup is available only for local libraries',
        ),
      );
      return;
    }

    final resolvedPassword = await _resolvePassword(password);
    if (resolvedPassword == null || resolvedPassword.trim().isEmpty) {
      state = state.copyWith(
        lastError: _localized('缺少备份密码', 'Backup password missing'),
      );
      return;
    }

    state = state.copyWith(running: true, lastError: null);
    try {
      await _ref.read(syncControllerProvider.notifier).syncNow();
      final exportedMemos = await _exportLocalLibraryForBackup(localLibrary);
      if (exportedMemos > 0) {
        final memoFiles = await LocalLibraryFileSystem(
          localLibrary,
        ).listMemos();
        if (memoFiles.isEmpty) {
          state = state.copyWith(
            running: false,
            lastError: _localized(
              '本地库未发现笔记文件，备份已取消',
              'No memo files found in local library; backup cancelled',
            ),
          );
          return;
        }
      }

      final baseUrl = _parseBaseUrl(settings.serverUrl);
      final accountId = fnv1a64Hex(accountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = _buildClient(settings, baseUrl);
      try {
        await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
        final config = await _loadOrCreateConfig(
          client,
          baseUrl,
          rootPath,
          accountId,
          resolvedPassword,
        );
        final masterKey = await _resolveMasterKey(resolvedPassword, config);
        var index = await _loadIndex(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
        );

        final now = DateTime.now();
        final snapshotId = _buildSnapshotId(now);
        final build = await _buildSnapshot(
          localLibrary: localLibrary,
          index: index,
          masterKey: masterKey,
          client: client,
          baseUrl: baseUrl,
          rootPath: rootPath,
          accountId: accountId,
          snapshotId: snapshotId,
        );

        final snapshot = build.snapshot;
        index = _applySnapshotToIndex(
          index,
          snapshot,
          now,
          build.newObjectSizes,
        );
        index = await _applyRetention(
          client: client,
          baseUrl: baseUrl,
          rootPath: rootPath,
          accountId: accountId,
          masterKey: masterKey,
          index: index,
          retention: settings.backupRetentionCount,
        );

        await _uploadSnapshot(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
          snapshot,
        );
        await _saveIndex(
          client,
          baseUrl,
          rootPath,
          accountId,
          masterKey,
          index,
        );

        await _stateRepository.write(
          WebDavBackupState(
            lastBackupAt: now.toUtc().toIso8601String(),
            lastSnapshotId: snapshot.id,
          ),
        );
        if (settings.rememberBackupPassword) {
          await _passwordRepository.write(resolvedPassword);
        }

        state = state.copyWith(
          running: false,
          lastBackupAt: now,
          lastSuccessAt: now,
          lastError: null,
        );
      } finally {
        await client.close();
      }
    } catch (e) {
      state = state.copyWith(running: false, lastError: e.toString());
    }
  }

  Future<List<WebDavBackupSnapshotInfo>> listSnapshots({
    required String password,
  }) async {
    final settings = _ref.read(webDavSettingsProvider);
    final accountKey = _accountKey;
    if (accountKey == null || accountKey.trim().isEmpty) return const [];
    final baseUrl = _parseBaseUrl(settings.serverUrl);
    final accountId = fnv1a64Hex(accountKey);
    final rootPath = normalizeWebDavRootPath(settings.rootPath);
    final client = _buildClient(settings, baseUrl);
    try {
      await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
      final config = await _loadOrCreateConfig(
        client,
        baseUrl,
        rootPath,
        accountId,
        password,
      );
      final masterKey = await _resolveMasterKey(password, config);
      final index = await _loadIndex(
        client,
        baseUrl,
        rootPath,
        accountId,
        masterKey,
      );
      final snapshots = <WebDavBackupSnapshotInfo>[];
      for (final item in index.snapshots) {
        if (item.memosCount > 0 || item.fileCount == 0) {
          snapshots.add(item);
          continue;
        }
        try {
          final data = await _loadSnapshot(
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            masterKey: masterKey,
            snapshotId: item.id,
          );
          final memosCount = _countMemosInSnapshot(data);
          snapshots.add(
            WebDavBackupSnapshotInfo(
              id: item.id,
              createdAt: item.createdAt,
              memosCount: memosCount,
              fileCount: item.fileCount,
              totalBytes: item.totalBytes,
            ),
          );
        } catch (_) {
          snapshots.add(item);
        }
      }
      snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return snapshots;
    } finally {
      await client.close();
    }
  }

  Future<void> restoreSnapshot({
    required BuildContext context,
    required WebDavBackupSnapshotInfo snapshot,
    required String password,
  }) async {
    if (state.running || state.restoring) return;
    final settings = _ref.read(webDavSettingsProvider);
    final accountKey = _accountKey;
    final localLibrary = _ref.read(currentLocalLibraryProvider);
    if (accountKey == null || accountKey.trim().isEmpty) {
      state = state.copyWith(
        lastError: _localized('账号缺失，无法恢复', 'Account missing for restore'),
      );
      return;
    }
    if (localLibrary == null) {
      state = state.copyWith(
        lastError: _localized(
          '仅本地库可恢复备份',
          'Restore is only available for local libraries',
        ),
      );
      return;
    }

    state = state.copyWith(restoring: true, lastError: null);
    try {
      final baseUrl = _parseBaseUrl(settings.serverUrl);
      final accountId = fnv1a64Hex(accountKey);
      final rootPath = normalizeWebDavRootPath(settings.rootPath);
      final client = _buildClient(settings, baseUrl);
      try {
        await _ensureBackupCollections(client, baseUrl, rootPath, accountId);
        final config = await _loadOrCreateConfig(
          client,
          baseUrl,
          rootPath,
          accountId,
          password,
        );
        final masterKey = await _resolveMasterKey(password, config);
        final snapshotData = await _loadSnapshot(
          client: client,
          baseUrl: baseUrl,
          rootPath: rootPath,
          accountId: accountId,
          masterKey: masterKey,
          snapshotId: snapshot.id,
        );
        if (snapshotData.files.isEmpty) {
          state = state.copyWith(
            restoring: false,
            lastError: _localized('备份内容为空', 'Backup is empty'),
          );
          return;
        }
        if (!_snapshotHasMemos(snapshotData)) {
          state = state.copyWith(
            restoring: false,
            lastError: _localized('备份中没有笔记', 'No memos found in backup'),
          );
          return;
        }

        final fileSystem = LocalLibraryFileSystem(localLibrary);
        final attachmentStore = LocalAttachmentStore();
        await fileSystem.clearLibrary();
        await attachmentStore.clearAll();
        await fileSystem.ensureStructure();

        for (final entry in snapshotData.files) {
          await _restoreFile(
            entry: entry,
            fileSystem: fileSystem,
            client: client,
            baseUrl: baseUrl,
            rootPath: rootPath,
            accountId: accountId,
            masterKey: masterKey,
          );
        }

        final db = _ref.read(databaseProvider);
        await db.clearOutbox();
        final scanner = _ref.read(localLibraryScannerProvider);
        if (scanner != null && context.mounted) {
          await scanner.scanAndMerge(context, forceDisk: true);
        }

        state = state.copyWith(
          restoring: false,
          lastSuccessAt: DateTime.now(),
          lastError: null,
        );
      } finally {
        await client.close();
      }
    } catch (e) {
      state = state.copyWith(restoring: false, lastError: e.toString());
    }
  }

  Future<int> _exportLocalLibraryForBackup(LocalLibrary localLibrary) async {
    final db = _ref.read(databaseProvider);
    final fileSystem = LocalLibraryFileSystem(localLibrary);
    final attachmentStore = LocalAttachmentStore();
    await fileSystem.ensureStructure();

    final rows = await db.listMemosForExport(includeArchived: true);
    var memoCount = 0;
    for (final row in rows) {
      final memo = LocalMemo.fromDb(row);
      final uid = memo.uid.trim();
      if (uid.isEmpty) continue;
      final markdown = buildLocalLibraryMarkdown(memo);
      await fileSystem.writeMemo(uid: uid, content: markdown);
      memoCount += 1;

      if (memo.attachments.isEmpty) continue;
      for (final attachment in memo.attachments) {
        final archiveName = attachmentArchiveName(attachment);
        final privatePath = await attachmentStore.resolveAttachmentPath(
          uid,
          archiveName,
        );
        String? srcPath;
        if (File(privatePath).existsSync()) {
          srcPath = privatePath;
        } else {
          final link = attachment.externalLink.trim();
          if (link.startsWith('file://')) {
            try {
              srcPath = Uri.parse(link).toFilePath();
            } catch (_) {}
          }
        }
        if (srcPath == null || srcPath.trim().isEmpty) continue;
        final file = File(srcPath);
        if (!file.existsSync()) continue;
        await fileSystem.writeAttachmentFromFile(
          memoUid: uid,
          filename: archiveName,
          srcPath: file.path,
          mimeType: attachment.type.isNotEmpty
              ? attachment.type
              : _guessMimeType(archiveName),
        );
      }
    }
    return memoCount;
  }

  int _countMemosInSnapshot(WebDavBackupSnapshot snapshot) {
    var count = 0;
    for (final entry in snapshot.files) {
      final path = entry.path.trim().toLowerCase();
      if (path.startsWith('memos/') &&
          (path.endsWith('.md') || path.endsWith('.md.txt'))) {
        count += 1;
      }
    }
    return count;
  }

  bool _snapshotHasMemos(WebDavBackupSnapshot snapshot) {
    return _countMemosInSnapshot(snapshot) > 0;
  }

  Future<_SnapshotBuildResult> _buildSnapshot({
    required LocalLibrary localLibrary,
    required WebDavBackupIndex index,
    required SecretKey masterKey,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required String snapshotId,
  }) async {
    final fileSystem = LocalLibraryFileSystem(localLibrary);
    await fileSystem.ensureStructure();
    final entries = await fileSystem.listAllFiles();
    entries.sort((a, b) => a.relativePath.compareTo(b.relativePath));

    final knownObjects = <String>{...index.objects.keys};
    final newObjectSizes = <String, int>{};
    final files = <WebDavBackupFileEntry>[];

    for (final entry in entries) {
      final objects = <String>[];
      final stream = await fileSystem.openReadStream(
        entry,
        bufferSize: _chunkSize,
      );
      await for (final chunk in _chunkStream(stream)) {
        final hash = crypto.sha256.convert(chunk).toString();
        objects.add(hash);
        if (!knownObjects.contains(hash)) {
          final objectKey = await _deriveObjectKey(masterKey, hash);
          final encrypted = await _encryptBytes(objectKey, chunk);
          await _putBytes(
            client,
            _objectUri(baseUrl, rootPath, accountId, hash),
            encrypted,
          );
          knownObjects.add(hash);
          newObjectSizes[hash] = chunk.length;
        }
      }
      files.add(
        WebDavBackupFileEntry(
          path: entry.relativePath,
          size: entry.length,
          objects: objects,
          modifiedAt: entry.lastModified?.toUtc().toIso8601String(),
        ),
      );
    }

    final snapshot = WebDavBackupSnapshot(
      schemaVersion: 1,
      id: snapshotId,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      files: files,
    );
    return _SnapshotBuildResult(
      snapshot: snapshot,
      newObjectSizes: newObjectSizes,
    );
  }

  WebDavBackupIndex _applySnapshotToIndex(
    WebDavBackupIndex index,
    WebDavBackupSnapshot snapshot,
    DateTime now,
    Map<String, int> newObjectSizes,
  ) {
    final totalBytes = snapshot.files.fold<int>(
      0,
      (sum, entry) => sum + entry.size,
    );
    final memosCount = _countMemosInSnapshot(snapshot);
    final nextSnapshots = [...index.snapshots];
    nextSnapshots.add(
      WebDavBackupSnapshotInfo(
        id: snapshot.id,
        createdAt: snapshot.createdAt,
        memosCount: memosCount,
        fileCount: snapshot.files.length,
        totalBytes: totalBytes,
      ),
    );
    final updatedObjects = <String, WebDavBackupObjectInfo>{...index.objects};
    final snapshotObjectSet = <String>{};
    for (final file in snapshot.files) {
      snapshotObjectSet.addAll(file.objects);
    }
    for (final hash in snapshotObjectSet) {
      final existing = updatedObjects[hash];
      if (existing == null) {
        final size = newObjectSizes[hash] ?? 0;
        updatedObjects[hash] = WebDavBackupObjectInfo(size: size, refs: 1);
      } else {
        updatedObjects[hash] = WebDavBackupObjectInfo(
          size: existing.size,
          refs: existing.refs + 1,
        );
      }
    }

    return WebDavBackupIndex(
      schemaVersion: 1,
      updatedAt: now.toUtc().toIso8601String(),
      snapshots: nextSnapshots,
      objects: updatedObjects,
    );
  }

  Future<WebDavBackupIndex> _applyRetention({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required WebDavBackupIndex index,
    required int retention,
  }) async {
    if (retention <= 0) return index;
    if (index.snapshots.length <= retention) return index;

    final sorted = [...index.snapshots];
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final toRemove = sorted.take(sorted.length - retention).toList();
    if (toRemove.isEmpty) return index;

    final objectRefs = <String, WebDavBackupObjectInfo>{...index.objects};
    final remainingSnapshots = index.snapshots
        .where((s) => !toRemove.any((r) => r.id == s.id))
        .toList();
    for (final snapshot in toRemove) {
      final data = await _loadSnapshot(
        client: client,
        baseUrl: baseUrl,
        rootPath: rootPath,
        accountId: accountId,
        masterKey: masterKey,
        snapshotId: snapshot.id,
      );
      final snapshotObjects = <String>{};
      for (final file in data.files) {
        snapshotObjects.addAll(file.objects);
      }
      for (final hash in snapshotObjects) {
        final info = objectRefs[hash];
        if (info == null) continue;
        final nextRefs = info.refs - 1;
        if (nextRefs <= 0) {
          objectRefs.remove(hash);
          await _delete(client, _objectUri(baseUrl, rootPath, accountId, hash));
        } else {
          objectRefs[hash] = WebDavBackupObjectInfo(
            size: info.size,
            refs: nextRefs,
          );
        }
      }
      await _delete(
        client,
        _snapshotUri(baseUrl, rootPath, accountId, snapshot.id),
      );
    }

    return WebDavBackupIndex(
      schemaVersion: 1,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      snapshots: remainingSnapshots,
      objects: objectRefs,
    );
  }

  Future<void> _uploadSnapshot(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
    WebDavBackupSnapshot snapshot,
  ) async {
    final key = await _deriveSubKey(masterKey, 'snapshot:${snapshot.id}');
    final bytes = await _encryptJson(key, snapshot.toJson());
    await _putBytes(
      client,
      _snapshotUri(baseUrl, rootPath, accountId, snapshot.id),
      bytes,
    );
  }

  Future<void> _saveIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
    WebDavBackupIndex index,
  ) async {
    final key = await _deriveSubKey(masterKey, 'index');
    final bytes = await _encryptJson(key, index.toJson());
    await _putBytes(client, _indexUri(baseUrl, rootPath, accountId), bytes);
  }

  Future<WebDavBackupIndex> _loadIndex(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    SecretKey masterKey,
  ) async {
    final data = await _getBytes(
      client,
      _indexUri(baseUrl, rootPath, accountId),
    );
    if (data == null) return WebDavBackupIndex.empty;
    final key = await _deriveSubKey(masterKey, 'index');
    final decoded = await _decryptJson(key, data);
    if (decoded is Map) {
      return WebDavBackupIndex.fromJson(decoded.cast<String, dynamic>());
    }
    return WebDavBackupIndex.empty;
  }

  Future<WebDavBackupSnapshot> _loadSnapshot({
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
    required String snapshotId,
  }) async {
    final data = await _getBytes(
      client,
      _snapshotUri(baseUrl, rootPath, accountId, snapshotId),
    );
    if (data == null) {
      throw StateError(_localized('备份快照丢失', 'Backup snapshot missing'));
    }
    final key = await _deriveSubKey(masterKey, 'snapshot:$snapshotId');
    final decoded = await _decryptJson(key, data);
    if (decoded is Map) {
      return WebDavBackupSnapshot.fromJson(decoded.cast<String, dynamic>());
    }
    throw StateError(_localized('备份快照损坏', 'Backup snapshot corrupted'));
  }

  Future<void> _restoreFile({
    required WebDavBackupFileEntry entry,
    required LocalLibraryFileSystem fileSystem,
    required WebDavClient client,
    required Uri baseUrl,
    required String rootPath,
    required String accountId,
    required SecretKey masterKey,
  }) async {
    final controller = StreamController<Uint8List>();
    final writeFuture = fileSystem.writeFileFromChunks(
      entry.path,
      controller.stream,
      mimeType: _guessMimeType(entry.path),
    );

    if (entry.objects.isEmpty) {
      await controller.close();
      await writeFuture;
      return;
    }

    for (final hash in entry.objects) {
      final objectData = await _getBytes(
        client,
        _objectUri(baseUrl, rootPath, accountId, hash),
      );
      if (objectData == null) {
        throw StateError(_localized('备份对象缺失', 'Backup object missing'));
      }
      final key = await _deriveObjectKey(masterKey, hash);
      final plain = await _decryptBytes(key, objectData);
      controller.add(plain);
    }

    await controller.close();
    await writeFuture;
  }

  Future<WebDavBackupConfig> _loadOrCreateConfig(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
    String password,
  ) async {
    final uri = _configUri(baseUrl, rootPath, accountId);
    final res = await client.get(uri);
    if (res.statusCode == 404) {
      final config = await _createConfig(password);
      await _putJson(client, uri, config.toJson());
      return config;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV config fetch failed (HTTP ${res.statusCode})');
    }
    final decoded = jsonDecode(res.bodyText);
    if (decoded is Map) {
      return WebDavBackupConfig.fromJson(decoded.cast<String, dynamic>());
    }
    throw StateError(_localized('备份配置损坏', 'Backup config corrupted'));
  }

  Future<WebDavBackupConfig> _createConfig(String password) async {
    final salt = _randomBytes(16);
    final kdf = WebDavBackupKdf(
      salt: base64Encode(salt),
      iterations: WebDavBackupKdf.defaults.iterations,
      hash: WebDavBackupKdf.defaults.hash,
      length: WebDavBackupKdf.defaults.length,
    );
    final kek = await _deriveKeyFromPassword(password, kdf);
    final masterKey = _randomBytes(32);
    final box = await _cipher.encrypt(
      masterKey,
      secretKey: kek,
      nonce: _randomBytes(_nonceLength),
    );
    final wrapped = WebDavBackupWrappedKey(
      nonce: base64Encode(box.nonce),
      cipherText: base64Encode(box.cipherText),
      mac: base64Encode(box.mac.bytes),
    );
    return WebDavBackupConfig(
      schemaVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      kdf: kdf,
      wrappedKey: wrapped,
    );
  }

  Future<SecretKey> _resolveMasterKey(
    String password,
    WebDavBackupConfig config,
  ) async {
    final kdf = config.kdf;
    if (kdf.salt.isEmpty) {
      throw StateError(_localized('备份配置无效', 'Invalid backup config'));
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
      throw StateError(_localized('备份密码错误', 'Invalid backup password'));
    }
  }

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

  Future<SecretKey> _deriveSubKey(SecretKey masterKey, String info) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: masterKey,
      nonce: utf8.encode('MemoFlowBackup'),
      info: utf8.encode(info),
    );
  }

  Future<SecretKey> _deriveObjectKey(SecretKey masterKey, String objectHash) {
    return _deriveSubKey(masterKey, 'object:$objectHash');
  }

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

  Future<Uint8List> _decryptBytes(SecretKey key, List<int> combined) async {
    if (combined.length < _nonceLength + _macLength) {
      throw StateError(_localized('备份数据损坏', 'Backup data corrupted'));
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

  Future<Uint8List> _encryptJson(
    SecretKey key,
    Map<String, dynamic> json,
  ) async {
    final encoded = jsonEncode(json);
    return _encryptBytes(key, utf8.encode(encoded));
  }

  Future<dynamic> _decryptJson(SecretKey key, List<int> data) async {
    final plain = await _decryptBytes(key, data);
    return jsonDecode(utf8.decode(plain, allowMalformed: true));
  }

  Future<void> _putJson(
    WebDavClient client,
    Uri uri,
    Map<String, dynamic> json,
  ) async {
    final encoded = utf8.encode(jsonEncode(json));
    await _putBytes(client, uri, encoded);
  }

  Future<void> _putBytes(WebDavClient client, Uri uri, List<int> bytes) async {
    final res = await client.put(uri, body: bytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV PUT failed (HTTP ${res.statusCode})');
    }
  }

  Future<Uint8List?> _getBytes(WebDavClient client, Uri uri) async {
    final res = await client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV GET failed (HTTP ${res.statusCode})');
    }
    return Uint8List.fromList(res.bytes);
  }

  Future<void> _delete(WebDavClient client, Uri uri) async {
    final res = await client.delete(uri);
    if (res.statusCode == 404) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV DELETE failed (HTTP ${res.statusCode})');
    }
  }

  String _buildSnapshotId(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final utc = now.toUtc();
    return '${utc.year}${two(utc.month)}${two(utc.day)}_${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }

  Uri _configUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, _backupConfigFile),
    );
  }

  Uri _indexUri(Uri baseUrl, String rootPath, String accountId) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, _backupIndexFile),
    );
  }

  Uri _objectUri(Uri baseUrl, String rootPath, String accountId, String hash) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(accountId, '$_backupObjectsDir/$hash.bin'),
    );
  }

  Uri _snapshotUri(
    Uri baseUrl,
    String rootPath,
    String accountId,
    String snapshotId,
  ) {
    return joinWebDavUri(
      baseUrl: baseUrl,
      rootPath: rootPath,
      relativePath: _backupBase(
        accountId,
        '$_backupSnapshotsDir/$snapshotId.enc',
      ),
    );
  }

  String _backupBase(String accountId, String relative) {
    return 'accounts/$accountId/$_backupDir/$_backupVersion/$relative';
  }

  Future<void> _ensureBackupCollections(
    WebDavClient client,
    Uri baseUrl,
    String rootPath,
    String accountId,
  ) async {
    final segments = <String>[
      ..._splitPath(rootPath),
      'accounts',
      accountId,
      _backupDir,
      _backupVersion,
    ];
    await _ensureCollectionPath(client, baseUrl, segments);
    await _ensureCollectionPath(client, baseUrl, [
      ...segments,
      _backupObjectsDir,
    ]);
    await _ensureCollectionPath(client, baseUrl, [
      ...segments,
      _backupSnapshotsDir,
    ]);
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
          res.statusCode == 200) {
        continue;
      }
      if (res.statusCode == 409) {
        continue;
      }
    }
  }

  List<String> _splitPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split('/')
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
  }

  WebDavClient _buildClient(WebDavSettings settings, Uri baseUrl) {
    return WebDavClient(
      baseUrl: baseUrl,
      username: settings.username,
      password: settings.password,
      authMode: settings.authMode,
      ignoreBadCert: settings.ignoreTlsErrors,
    );
  }

  Uri _parseBaseUrl(String raw) {
    final baseUrl = Uri.tryParse(raw.trim());
    if (baseUrl == null || !baseUrl.hasScheme || !baseUrl.hasAuthority) {
      throw StateError(
        _localized('WebDAV 服务器地址无效', 'Invalid WebDAV server URL'),
      );
    }
    return baseUrl;
  }

  Stream<Uint8List> _chunkStream(Stream<Uint8List> input) async* {
    final buffer = <int>[];
    await for (final data in input) {
      buffer.addAll(data);
      while (buffer.length >= _chunkSize) {
        final chunk = Uint8List.fromList(buffer.sublist(0, _chunkSize));
        buffer.removeRange(0, _chunkSize);
        yield chunk;
      }
    }
    if (buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  }

  Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  Duration _scheduleDuration(WebDavBackupSchedule schedule) {
    return switch (schedule) {
      WebDavBackupSchedule.daily => const Duration(days: 1),
      WebDavBackupSchedule.weekly => const Duration(days: 7),
      WebDavBackupSchedule.manual => Duration.zero,
    };
  }

  bool _isBackupDue(DateTime? last, WebDavBackupSchedule schedule) {
    if (schedule == WebDavBackupSchedule.manual) return false;
    if (last == null) return true;
    final diff = DateTime.now().difference(last);
    return diff >= _scheduleDuration(schedule);
  }

  DateTime? _parseIso(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _localized(String zh, String en) {
    final language = _ref.read(appPreferencesProvider).language;
    return trByLanguage(language: language, zh: zh, en: en);
  }

  Future<String?> _resolvePassword(String? override) async {
    if (override != null && override.trim().isNotEmpty) return override;
    return _passwordRepository.read();
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}

class _SnapshotBuildResult {
  const _SnapshotBuildResult({
    required this.snapshot,
    required this.newObjectSizes,
  });

  final WebDavBackupSnapshot snapshot;
  final Map<String, int> newObjectSizes;
}
