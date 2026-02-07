import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/image_bed_url.dart';
import '../data/models/image_bed_settings.dart';
import '../data/settings/image_bed_settings_repository.dart';
import 'session_provider.dart';
import 'webdav_sync_trigger_provider.dart';

final imageBedSettingsRepositoryProvider = Provider<ImageBedSettingsRepository>(
  (ref) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final key = session?.currentKey?.trim();
    final storageKey = (key == null || key.isEmpty) ? 'device' : key;
    return ImageBedSettingsRepository(
      ref.watch(secureStorageProvider),
      accountKey: storageKey,
    );
  },
);

final imageBedSettingsProvider =
    StateNotifierProvider<ImageBedSettingsController, ImageBedSettings>((ref) {
      return ImageBedSettingsController(
        ref,
        ref.watch(imageBedSettingsRepositoryProvider),
      );
    });

class ImageBedSettingsController extends StateNotifier<ImageBedSettings> {
  ImageBedSettingsController(this._ref, this._repo)
    : super(ImageBedSettings.defaults) {
    unawaited(_load());
  }

  final Ref _ref;
  final ImageBedSettingsRepository _repo;

  Future<void> _load() async {
    final stored = await _repo.read();
    state = stored;
  }

  void _setAndPersist(ImageBedSettings next, {bool triggerSync = true}) {
    state = next;
    unawaited(_repo.write(next));
    if (triggerSync) {
      _ref.read(webDavSyncTriggerProvider.notifier).bump();
    }
  }

  void setEnabled(bool value) => _setAndPersist(state.copyWith(enabled: value));

  void setProvider(ImageBedProvider provider) {
    _setAndPersist(state.copyWith(provider: provider, authToken: null));
  }

  void setBaseUrl(String value) {
    final trimmed = value.trim();
    final normalized = _normalizeBaseUrl(trimmed);
    _setAndPersist(state.copyWith(baseUrl: normalized, authToken: null));
  }

  void setEmail(String value) {
    _setAndPersist(state.copyWith(email: value.trim(), authToken: null));
  }

  void setPassword(String value) {
    _setAndPersist(state.copyWith(password: value, authToken: null));
  }

  void setStrategyId(String? value) {
    final trimmed = (value ?? '').trim();
    _setAndPersist(
      state.copyWith(strategyId: trimmed.isEmpty ? null : trimmed),
    );
  }

  void setRetryCount(int value) {
    _setAndPersist(state.copyWith(retryCount: value));
  }

  void setAuthToken(String? value) {
    final trimmed = (value ?? '').trim();
    _setAndPersist(state.copyWith(authToken: trimmed.isEmpty ? null : trimmed));
  }

  Future<void> setAll(ImageBedSettings next, {bool triggerSync = true}) async {
    state = next;
    await _repo.write(next);
    if (triggerSync) {
      _ref.read(webDavSyncTriggerProvider.notifier).bump();
    }
  }

  String _normalizeBaseUrl(String raw) {
    if (raw.isEmpty) return '';
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return raw;
    return sanitizeImageBedBaseUrl(parsed).toString();
  }
}
