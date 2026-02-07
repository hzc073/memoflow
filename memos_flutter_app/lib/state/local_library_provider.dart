import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/local_library.dart';
import '../data/settings/local_library_repository.dart';
import 'session_provider.dart';

final localLibraryRepositoryProvider = Provider<LocalLibraryRepository>((ref) {
  return LocalLibraryRepository(ref.watch(secureStorageProvider));
});

final localLibrariesLoadedProvider = StateProvider<bool>((ref) => false);

final localLibrariesProvider = StateNotifierProvider<LocalLibrariesController, List<LocalLibrary>>((ref) {
  final loadedState = ref.read(localLibrariesLoadedProvider.notifier);
  Future.microtask(() => loadedState.state = false);
  return LocalLibrariesController(
    ref.watch(localLibraryRepositoryProvider),
    onLoaded: () => loadedState.state = true,
  );
});

class LocalLibrariesController extends StateNotifier<List<LocalLibrary>> {
  LocalLibrariesController(
    this._repo, {
    void Function()? onLoaded,
  })  : _onLoaded = onLoaded,
        super(const []) {
    _loadFromStorage();
  }

  final LocalLibraryRepository _repo;
  final void Function()? _onLoaded;
  Future<void> _writeChain = Future<void>.value();

  Future<void> _loadFromStorage() async {
    final stored = await _repo.read();
    if (!mounted) return;
    state = stored.libraries;
    _onLoaded?.call();
  }

  void upsert(LocalLibrary library) {
    final key = library.key.trim();
    if (key.isEmpty) return;
    final next = [...state];
    final index = next.indexWhere((l) => l.key == key);
    final now = DateTime.now();
    final updated = library.copyWith(
      createdAt: library.createdAt ?? now,
      updatedAt: now,
    );
    if (index >= 0) {
      next[index] = updated;
    } else {
      next.add(updated);
    }
    state = next;
    _persist(next);
  }

  void remove(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    final next = state.where((l) => l.key != trimmed).toList(growable: false);
    state = next;
    _persist(next);
  }

  void _persist(List<LocalLibrary> libraries) {
    _writeChain = _writeChain.then((_) => _repo.write(LocalLibraryState(libraries: libraries)));
  }
}

final currentLocalLibraryProvider = Provider<LocalLibrary?>((ref) {
  final key = ref.watch(appSessionProvider.select((s) => s.valueOrNull?.currentKey));
  if (key == null || key.trim().isEmpty) return null;
  final libraries = ref.watch(localLibrariesProvider);
  for (final library in libraries) {
    if (library.key == key) return library;
  }
  return null;
});

final isLocalLibraryModeProvider = Provider<bool>((ref) {
  return ref.watch(currentLocalLibraryProvider) != null;
});
