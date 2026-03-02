import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync/sync_coordinator.dart';
import '../application/sync/sync_request.dart';
import '../core/webdav_url.dart';
import '../data/models/webdav_settings.dart';
import '../data/settings/webdav_settings_repository.dart';
import 'session_provider.dart';

final webDavSettingsRepositoryProvider = Provider<WebDavSettingsRepository>((
  ref,
) {
  final accountKey = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  return WebDavSettingsRepository(
    ref.watch(secureStorageProvider),
    accountKey: accountKey,
  );
});

final webDavSettingsProvider =
    StateNotifierProvider<WebDavSettingsController, WebDavSettings>((ref) {
      return WebDavSettingsController(
        ref,
        ref.watch(webDavSettingsRepositoryProvider),
      );
    });

class WebDavSettingsController extends StateNotifier<WebDavSettings> {
  WebDavSettingsController(this._ref, this._repo)
    : super(WebDavSettings.defaults) {
    unawaited(_load());
  }

  final Ref _ref;
  final WebDavSettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.read();
  }

  void _setAndPersist(WebDavSettings next) {
    state = next;
    unawaited(_repo.write(next));
    unawaited(
      _ref.read(syncCoordinatorProvider.notifier).requestSync(
            const SyncRequest(
              kind: SyncRequestKind.webDavSync,
              reason: SyncRequestReason.settings,
            ),
          ),
    );
  }

  void setEnabled(bool value) => _setAndPersist(state.copyWith(enabled: value));

  void setServerUrl(String value) {
    final normalized = normalizeWebDavBaseUrl(value);
    _setAndPersist(state.copyWith(serverUrl: normalized));
  }

  void setUsername(String value) =>
      _setAndPersist(state.copyWith(username: value.trim()));
  void setPassword(String value) =>
      _setAndPersist(state.copyWith(password: value));
  void setAuthMode(WebDavAuthMode mode) =>
      _setAndPersist(state.copyWith(authMode: mode));
  void setIgnoreTlsErrors(bool value) =>
      _setAndPersist(state.copyWith(ignoreTlsErrors: value));

  void setRootPath(String value) {
    final normalized = normalizeWebDavRootPath(value);
    _setAndPersist(state.copyWith(rootPath: normalized));
  }

  void setVaultEnabled(bool value) =>
      _setAndPersist(state.copyWith(vaultEnabled: value));

  void setRememberVaultPassword(bool value) =>
      _setAndPersist(state.copyWith(rememberVaultPassword: value));

  void setVaultKeepPlainCache(bool value) =>
      _setAndPersist(state.copyWith(vaultKeepPlainCache: value));

  void setBackupEnabled(bool value) =>
      _setAndPersist(state.copyWith(backupEnabled: value));

  void setBackupConfigScope(WebDavBackupConfigScope scope) =>
      _setAndPersist(state.copyWith(backupConfigScope: scope));

  void setBackupContentMemos(bool value) =>
      _setAndPersist(state.copyWith(backupContentMemos: value));

  void setBackupEncryptionMode(WebDavBackupEncryptionMode mode) =>
      _setAndPersist(state.copyWith(backupEncryptionMode: mode));

  void setBackupSchedule(WebDavBackupSchedule schedule) =>
      _setAndPersist(state.copyWith(backupSchedule: schedule));

  void setBackupRetentionCount(int value) {
    final next = value < 1 ? 1 : value;
    _setAndPersist(state.copyWith(backupRetentionCount: next));
  }

  void setRememberBackupPassword(bool value) =>
      _setAndPersist(state.copyWith(rememberBackupPassword: value));

  void setBackupExportEncrypted(bool value) =>
      _setAndPersist(state.copyWith(backupExportEncrypted: value));

  void setBackupMirrorLocation({String? treeUri, String? rootPath}) {
    final normalizedTreeUri = (treeUri ?? '').trim();
    final normalizedRootPath = (rootPath ?? '').trim();
    _setAndPersist(
      state.copyWith(
        backupMirrorTreeUri: normalizedTreeUri,
        backupMirrorRootPath: normalizedRootPath,
      ),
    );
  }

  void setAll(WebDavSettings settings) => _setAndPersist(settings);
}
