import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../application/sync/sync_coordinator.dart';
import '../application/sync/sync_request.dart';
import 'session_provider.dart';

final noteDraftRepositoryProvider = Provider<NoteDraftRepository>((ref) {
  final accountKey = ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  return NoteDraftRepository(ref.watch(secureStorageProvider), accountKey: accountKey);
});

final noteDraftProvider = StateNotifierProvider<NoteDraftController, AsyncValue<String>>((ref) {
  return NoteDraftController(ref, ref.watch(noteDraftRepositoryProvider));
});

class NoteDraftController extends StateNotifier<AsyncValue<String>> {
  NoteDraftController(this._ref, this._repo) : super(const AsyncValue.loading()) {
    unawaited(_load());
  }

  final Ref _ref;
  final NoteDraftRepository _repo;

  Future<void> _load() async {
    final draft = await _repo.read();
    state = AsyncValue.data(draft);
  }

  Future<void> setDraft(String text, {bool triggerSync = true}) async {
    final normalized = text;
    state = AsyncValue.data(normalized);
    if (normalized.trim().isEmpty) {
      await _repo.clear();
    } else {
      await _repo.write(normalized);
    }
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

  Future<void> clear() async {
    state = const AsyncValue.data('');
    await _repo.clear();
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

class NoteDraftRepository {
  NoteDraftRepository(this._storage, {required String? accountKey}) : _accountKey = accountKey;

  static const _kPrefix = 'note_draft_v2_';
  static const _kLegacyKey = 'note_draft_v1';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<String> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return '';
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      final legacy = await _storage.read(key: _kLegacyKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        await write(legacy);
        return legacy;
      }
      return '';
    }
    return raw;
  }

  Future<void> write(String text) async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.write(key: storageKey, value: text);
  }

  Future<void> clear() async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.delete(key: storageKey);
  }
}
