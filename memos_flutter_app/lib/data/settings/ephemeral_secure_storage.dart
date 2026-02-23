import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/debug_ephemeral_storage.dart';

/// A debug-only secure-storage replacement backed by a temporary JSON file.
///
/// It is process-shared (for desktop multi-window) and wiped on next debug run.
class EphemeralSecureStorage extends FlutterSecureStorage {
  EphemeralSecureStorage({
    super.iOptions = IOSOptions.defaultOptions,
    super.aOptions = AndroidOptions.defaultOptions,
    super.lOptions = LinuxOptions.defaultOptions,
    super.wOptions = WindowsOptions.defaultOptions,
    super.webOptions = WebOptions.defaultOptions,
    super.mOptions = MacOsOptions.defaultOptions,
  });

  Future<void> _queue = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, String>> _readStore() async {
    final file = await resolveEphemeralSecureStorageFile();
    try {
      if (!await file.exists()) return <String, String>{};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map(
        (k, v) => MapEntry(k.toString(), (v ?? '').toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _writeStore(Map<String, String> data) async {
    final file = await resolveEphemeralSecureStorageFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    return _enqueue(() async {
      final data = await _readStore();
      if (value == null) {
        data.remove(key);
      } else {
        data[key] = value;
      }
      await _writeStore(data);
    });
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    return _enqueue(() async {
      final data = await _readStore();
      return data[key];
    });
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    return _enqueue(() async {
      final data = await _readStore();
      return data.containsKey(key);
    });
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    return _enqueue(() async {
      final data = await _readStore();
      if (data.remove(key) != null) {
        await _writeStore(data);
      }
    });
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    return _enqueue(_readStore);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    return _enqueue(() async {
      await _writeStore(<String, String>{});
    });
  }
}
