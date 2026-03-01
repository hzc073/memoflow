import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync/sync_coordinator.dart';
import '../application/sync/sync_request.dart';
import '../data/settings/ai_settings_repository.dart';
import 'preferences_provider.dart';
import 'session_provider.dart';

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  final accountKey = ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  return AiSettingsRepository(ref.watch(secureStorageProvider), accountKey: accountKey);
});

final aiSettingsProvider = StateNotifierProvider<AiSettingsController, AiSettings>((ref) {
  return AiSettingsController(ref, ref.watch(aiSettingsRepositoryProvider));
});

class AiSettingsController extends StateNotifier<AiSettings> {
  AiSettingsController(Ref ref, AiSettingsRepository repo)
      : _ref = ref,
        _repo = repo,
        super(AiSettings.defaultsFor(ref.read(appPreferencesProvider).language)) {
    unawaited(_load());
  }

  final Ref _ref;
  final AiSettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.read(
      language: _ref.read(appPreferencesProvider).language,
    );
  }

  Future<void> setAll(AiSettings next, {bool triggerSync = true}) async {
    state = next;
    await _repo.write(next);
    if (triggerSync) {
      unawaited(
        _ref.read(syncCoordinatorProvider.notifier).requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.settings,
              ),
            ),
      );
    }
  }

  Future<void> setApiUrl(String v) async => setAll(state.copyWith(apiUrl: v.trim()));
  Future<void> setApiKey(String v) async => setAll(state.copyWith(apiKey: v.trim()));
  Future<void> setModel(String v) async => setAll(state.copyWith(model: v.trim()));
  Future<void> setPrompt(String v) async => setAll(state.copyWith(prompt: v.trim()));
  Future<void> setUserProfile(String v) async => setAll(state.copyWith(userProfile: v.trim()));
}
