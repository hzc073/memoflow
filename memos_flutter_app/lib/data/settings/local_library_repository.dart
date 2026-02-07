import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/local_library.dart';

class LocalLibraryState {
  const LocalLibraryState({required this.libraries});

  final List<LocalLibrary> libraries;

  Map<String, dynamic> toJson() => {
        'libraries': libraries.map((l) => l.toJson()).toList(growable: false),
      };

  factory LocalLibraryState.fromJson(Map<String, dynamic> json) {
    final list = <LocalLibrary>[];
    final raw = json['libraries'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(LocalLibrary.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return LocalLibraryState(libraries: list);
  }
}

class LocalLibraryRepository {
  LocalLibraryRepository(this._storage);

  static const _kStateKey = 'local_library_state_v1';

  final FlutterSecureStorage _storage;

  Future<LocalLibraryState> read() async {
    final raw = await _storage.read(key: _kStateKey);
    if (raw == null || raw.trim().isEmpty) {
      return const LocalLibraryState(libraries: []);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return LocalLibraryState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return const LocalLibraryState(libraries: []);
  }

  Future<void> write(LocalLibraryState state) async {
    await _storage.write(key: _kStateKey, value: jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _kStateKey);
  }
}
