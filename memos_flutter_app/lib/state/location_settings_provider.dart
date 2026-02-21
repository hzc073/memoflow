import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/location_settings.dart';
import '../data/settings/location_settings_repository.dart';
import 'session_provider.dart';
import 'webdav_sync_trigger_provider.dart';

final locationSettingsRepositoryProvider = Provider<LocationSettingsRepository>(
  (ref) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final key = session?.currentKey?.trim();
    final storageKey = (key == null || key.isEmpty) ? 'device' : key;
    return LocationSettingsRepository(
      ref.watch(secureStorageProvider),
      accountKey: storageKey,
    );
  },
);

final locationSettingsProvider =
    StateNotifierProvider<LocationSettingsController, LocationSettings>((ref) {
      return LocationSettingsController(
        ref,
        ref.watch(locationSettingsRepositoryProvider),
      );
    });

class LocationSettingsController extends StateNotifier<LocationSettings> {
  LocationSettingsController(this._ref, this._repo)
    : super(LocationSettings.defaults) {
    unawaited(_load());
  }

  final Ref _ref;
  final LocationSettingsRepository _repo;

  Future<void> _load() async {
    final stored = await _repo.read();
    state = stored;
  }

  void _setAndPersist(LocationSettings next, {bool triggerSync = true}) {
    state = next;
    unawaited(_repo.write(next));
    if (triggerSync) {
      _ref.read(webDavSyncTriggerProvider.notifier).bump();
    }
  }

  void setEnabled(bool value) => _setAndPersist(state.copyWith(enabled: value));

  void setProvider(LocationServiceProvider value) {
    _setAndPersist(state.copyWith(provider: value));
  }

  void setAmapWebKey(String value) {
    _setAndPersist(state.copyWith(amapWebKey: value.trim()));
  }

  void setAmapSecurityKey(String value) {
    _setAndPersist(state.copyWith(amapSecurityKey: value.trim()));
  }

  void setBaiduWebKey(String value) {
    _setAndPersist(state.copyWith(baiduWebKey: value.trim()));
  }

  void setGoogleApiKey(String value) {
    _setAndPersist(state.copyWith(googleApiKey: value.trim()));
  }

  void setPrecision(LocationPrecision value) {
    _setAndPersist(state.copyWith(precision: value));
  }

  Future<void> setAll(LocationSettings next, {bool triggerSync = true}) async {
    state = next;
    await _repo.write(next);
    if (triggerSync) {
      _ref.read(webDavSyncTriggerProvider.notifier).bump();
    }
  }
}
