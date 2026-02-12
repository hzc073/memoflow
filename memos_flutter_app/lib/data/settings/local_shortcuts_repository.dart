import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/shortcut.dart';

class LocalShortcutsRepository {
  LocalShortcutsRepository(this._storage, {required this.accountKey});

  static const _kPrefix = 'local_shortcuts_v1_';

  final FlutterSecureStorage _storage;
  final String accountKey;

  String get _storageKey => '$_kPrefix$accountKey';

  Future<List<Shortcut>> read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.trim().isEmpty) return const <Shortcut>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Shortcut>[];
      final out = <Shortcut>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final json = item.cast<String, dynamic>();
        out.add(Shortcut.fromJson(json));
      }
      return out;
    } catch (_) {
      return const <Shortcut>[];
    }
  }

  Future<void> write(List<Shortcut> items) async {
    final json = items.map((e) => e.toJson()).toList(growable: false);
    await _storage.write(key: _storageKey, value: jsonEncode(json));
  }

  Future<Shortcut> create({
    required String title,
    required String filter,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('createLocalShortcut requires title');
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final shortcut = Shortcut(
      name: 'local/$id',
      id: id,
      title: trimmedTitle,
      filter: filter,
    );

    final existing = await read();
    final next = [...existing, shortcut];
    await write(next);
    return shortcut;
  }

  Future<Shortcut> update({
    required Shortcut shortcut,
    required String title,
    required String filter,
  }) async {
    final targetId = shortcut.shortcutId;
    if (targetId.isEmpty) {
      throw ArgumentError('updateLocalShortcut requires shortcut id');
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('updateLocalShortcut requires title');
    }

    final existing = await read();
    final next = <Shortcut>[];
    Shortcut? updated;
    for (final item in existing) {
      if (item.shortcutId == targetId) {
        final merged = Shortcut(
          name: item.name,
          id: item.id,
          title: trimmedTitle,
          filter: filter,
        );
        updated = merged;
        next.add(merged);
      } else {
        next.add(item);
      }
    }
    if (updated == null) {
      throw StateError('Local shortcut not found');
    }
    await write(next);
    return updated;
  }

  Future<void> delete(Shortcut shortcut) async {
    final targetId = shortcut.shortcutId;
    if (targetId.isEmpty) {
      throw ArgumentError('deleteLocalShortcut requires shortcut id');
    }
    final existing = await read();
    final next = existing
        .where((e) => e.shortcutId != targetId)
        .toList(growable: false);
    await write(next);
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }
}
