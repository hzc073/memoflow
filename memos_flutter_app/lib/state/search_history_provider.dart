import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_provider.dart';

class SearchHistoryRepository {
  SearchHistoryRepository(this._storage, {required this.accountKey});

  final FlutterSecureStorage _storage;
  final String accountKey;

  String get _storageKey => 'search_history_v1_$accountKey';

  Future<List<String>> read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> write(List<String> items) async {
    await _storage.write(key: _storageKey, value: jsonEncode(items));
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }
}

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  final session = ref.watch(appSessionProvider).valueOrNull;
  final key = session?.currentKey?.trim();
  final storageKey = (key == null || key.isEmpty) ? 'device' : key;
  return SearchHistoryRepository(
    ref.watch(secureStorageProvider),
    accountKey: storageKey,
  );
});

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryController, List<String>>((ref) {
      return SearchHistoryController(
        ref.watch(searchHistoryRepositoryProvider),
      );
    });

class SearchHistoryController extends StateNotifier<List<String>> {
  SearchHistoryController(this._repo) : super(const []) {
    unawaited(_load());
  }

  static const _maxItems = 12;

  final SearchHistoryRepository _repo;

  Future<void> _load() async {
    final stored = await _repo.read();
    state = stored;
  }

  void add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final next = [trimmed, ...state.where((e) => e != trimmed)];
    if (next.length > _maxItems) {
      next.removeRange(_maxItems, next.length);
    }
    state = next;
    unawaited(_repo.write(next));
  }

  void remove(String query) {
    final next = state.where((e) => e != query).toList(growable: false);
    state = next;
    unawaited(_repo.write(next));
  }

  void clear() {
    state = const [];
    unawaited(_repo.clear());
  }
}
