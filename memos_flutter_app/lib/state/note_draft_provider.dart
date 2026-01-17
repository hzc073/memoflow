import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_provider.dart';

final noteDraftRepositoryProvider = Provider<NoteDraftRepository>((ref) {
  return NoteDraftRepository(ref.watch(secureStorageProvider));
});

final noteDraftProvider = StateNotifierProvider<NoteDraftController, AsyncValue<String>>((ref) {
  return NoteDraftController(ref.watch(noteDraftRepositoryProvider));
});

class NoteDraftController extends StateNotifier<AsyncValue<String>> {
  NoteDraftController(this._repo) : super(const AsyncValue.loading()) {
    unawaited(_load());
  }

  final NoteDraftRepository _repo;

  Future<void> _load() async {
    final draft = await _repo.read();
    state = AsyncValue.data(draft);
  }

  Future<void> setDraft(String text) async {
    final normalized = text;
    state = AsyncValue.data(normalized);
    if (normalized.trim().isEmpty) {
      await _repo.clear();
    } else {
      await _repo.write(normalized);
    }
  }

  Future<void> clear() async {
    state = const AsyncValue.data('');
    await _repo.clear();
  }
}

class NoteDraftRepository {
  NoteDraftRepository(this._storage);

  static const _kKey = 'note_draft_v1';

  final FlutterSecureStorage _storage;

  Future<String> read() async {
    final raw = await _storage.read(key: _kKey);
    return raw ?? '';
  }

  Future<void> write(String text) async {
    await _storage.write(key: _kKey, value: text);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kKey);
  }
}
