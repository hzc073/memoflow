import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/webdav_url.dart';
import '../data/models/webdav_settings.dart';
import '../data/settings/webdav_settings_repository.dart';
import 'session_provider.dart';
import 'webdav_sync_trigger_provider.dart';

final webDavSettingsRepositoryProvider = Provider<WebDavSettingsRepository>((ref) {
  final accountKey = ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  return WebDavSettingsRepository(ref.watch(secureStorageProvider), accountKey: accountKey);
});

final webDavSettingsProvider = StateNotifierProvider<WebDavSettingsController, WebDavSettings>((ref) {
  return WebDavSettingsController(ref, ref.watch(webDavSettingsRepositoryProvider));
});

class WebDavSettingsController extends StateNotifier<WebDavSettings> {
  WebDavSettingsController(this._ref, this._repo) : super(WebDavSettings.defaults) {
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
    _ref.read(webDavSyncTriggerProvider.notifier).bump();
  }

  void setEnabled(bool value) => _setAndPersist(state.copyWith(enabled: value));

  void setServerUrl(String value) {
    final normalized = normalizeWebDavBaseUrl(value);
    _setAndPersist(state.copyWith(serverUrl: normalized));
  }

  void setUsername(String value) => _setAndPersist(state.copyWith(username: value.trim()));
  void setPassword(String value) => _setAndPersist(state.copyWith(password: value));
  void setAuthMode(WebDavAuthMode mode) => _setAndPersist(state.copyWith(authMode: mode));
  void setIgnoreTlsErrors(bool value) => _setAndPersist(state.copyWith(ignoreTlsErrors: value));

  void setRootPath(String value) {
    final normalized = normalizeWebDavRootPath(value);
    _setAndPersist(state.copyWith(rootPath: normalized));
  }
}
