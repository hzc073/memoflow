import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/ai_settings_repository.dart';
import 'session_provider.dart';

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  return AiSettingsRepository(ref.watch(secureStorageProvider));
});

final aiSettingsProvider = StateNotifierProvider<AiSettingsController, AiSettings>((ref) {
  return AiSettingsController(ref.watch(aiSettingsRepositoryProvider));
});

class AiSettingsController extends StateNotifier<AiSettings> {
  AiSettingsController(this._repo) : super(AiSettings.defaults) {
    unawaited(_load());
  }

  final AiSettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.read();
  }

  Future<void> setAll(AiSettings next) async {
    state = next;
    await _repo.write(next);
  }

  Future<void> setApiUrl(String v) async => setAll(state.copyWith(apiUrl: v.trim()));
  Future<void> setApiKey(String v) async => setAll(state.copyWith(apiKey: v.trim()));
  Future<void> setModel(String v) async => setAll(state.copyWith(model: v.trim()));
  Future<void> setPrompt(String v) async => setAll(state.copyWith(prompt: v.trim()));
  Future<void> setUserProfile(String v) async => setAll(state.copyWith(userProfile: v.trim()));
}

