import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'preferences_provider.dart';
import 'session_provider.dart';

enum AutoLockTime {
  immediately('立即', 'Immediately'),
  after1Min('1 分钟', '1 minute'),
  after5Min('5 分钟', '5 minutes'),
  after15Min('15 分钟', '15 minutes');

  const AutoLockTime(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String labelFor(AppLanguage language) => language == AppLanguage.en ? labelEn : labelZh;

  Duration get duration => switch (this) {
        AutoLockTime.immediately => Duration.zero,
        AutoLockTime.after1Min => const Duration(minutes: 1),
        AutoLockTime.after5Min => const Duration(minutes: 5),
        AutoLockTime.after15Min => const Duration(minutes: 15),
      };
}

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.autoLockTime,
    required this.hasPassword,
    required this.locked,
    required this.loaded,
    this.lastBackgroundAt,
  });

  final bool enabled;
  final AutoLockTime autoLockTime;
  final bool hasPassword;
  final bool locked;
  final bool loaded;
  final DateTime? lastBackgroundAt;

  AppLockState copyWith({
    bool? enabled,
    AutoLockTime? autoLockTime,
    bool? hasPassword,
    bool? locked,
    bool? loaded,
    DateTime? lastBackgroundAt,
    bool clearLastBackgroundAt = false,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      autoLockTime: autoLockTime ?? this.autoLockTime,
      hasPassword: hasPassword ?? this.hasPassword,
      locked: locked ?? this.locked,
      loaded: loaded ?? this.loaded,
      lastBackgroundAt: clearLastBackgroundAt ? null : (lastBackgroundAt ?? this.lastBackgroundAt),
    );
  }

  static const AppLockState initial = AppLockState(
    enabled: false,
    autoLockTime: AutoLockTime.immediately,
    hasPassword: false,
    locked: false,
    loaded: false,
  );
}

class AppLockSettings {
  const AppLockSettings({
    required this.enabled,
    required this.autoLockTime,
  });

  final bool enabled;
  final AutoLockTime autoLockTime;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'autoLockTime': autoLockTime.name,
      };

  factory AppLockSettings.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'] is bool ? json['enabled'] as bool : false;
    final raw = json['autoLockTime'];
    AutoLockTime parsed = AutoLockTime.immediately;
    if (raw is String) {
      parsed = AutoLockTime.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => AutoLockTime.immediately,
      );
    }
    return AppLockSettings(enabled: enabled, autoLockTime: parsed);
  }

  static const defaults = AppLockSettings(
    enabled: false,
    autoLockTime: AutoLockTime.immediately,
  );
}

final appLockRepositoryProvider = Provider<AppLockRepository>((ref) {
  return AppLockRepository(ref.watch(secureStorageProvider));
});

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(ref.watch(appLockRepositoryProvider));
});

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._repo) : super(AppLockState.initial) {
    unawaited(_load());
  }

  final AppLockRepository _repo;

  Future<void> _load() async {
    final settings = await _repo.readSettings();
    final hasPassword = await _repo.hasPassword();
    state = state.copyWith(
      enabled: settings.enabled,
      autoLockTime: settings.autoLockTime,
      hasPassword: hasPassword,
      locked: settings.enabled && hasPassword,
      loaded: true,
    );
  }

  void setEnabled(bool v) {
    final next = state.copyWith(
      enabled: v,
      locked: v ? state.locked : false,
      clearLastBackgroundAt: !v,
    );
    state = next;
    unawaited(_repo.writeSettings(AppLockSettings(enabled: v, autoLockTime: next.autoLockTime)));
  }

  void setAutoLockTime(AutoLockTime v) {
    state = state.copyWith(autoLockTime: v);
    unawaited(_repo.writeSettings(AppLockSettings(enabled: state.enabled, autoLockTime: v)));
  }

  Future<void> setPassword(String password) async {
    await _repo.setPassword(password);
    state = state.copyWith(hasPassword: true);
  }

  Future<bool> verifyPassword(String password) async {
    final ok = await _repo.verifyPassword(password);
    if (ok) {
      state = state.copyWith(locked: false, clearLastBackgroundAt: true);
    }
    return ok;
  }

  void lock() {
    if (!state.enabled || !state.hasPassword) return;
    state = state.copyWith(locked: true);
  }

  void recordBackgrounded() {
    if (!state.enabled || !state.hasPassword) return;
    final now = DateTime.now();
    final shouldLock = state.autoLockTime == AutoLockTime.immediately;
    state = state.copyWith(lastBackgroundAt: now, locked: shouldLock ? true : state.locked);
  }

  void handleAppResumed() {
    if (!state.enabled || !state.hasPassword) return;
    final last = state.lastBackgroundAt;
    if (last == null) return;
    final shouldLock = state.autoLockTime == AutoLockTime.immediately ||
        DateTime.now().difference(last) >= state.autoLockTime.duration;
    state = state.copyWith(clearLastBackgroundAt: true, locked: shouldLock ? true : state.locked);
  }
}

class AppLockRepository {
  AppLockRepository(this._storage);

  static const _kStateKey = 'app_lock_state_v1';
  static const _kPasswordKey = 'app_lock_password_v1';

  final FlutterSecureStorage _storage;

  Future<AppLockSettings> readSettings() async {
    final raw = await _storage.read(key: _kStateKey);
    if (raw == null || raw.trim().isEmpty) {
      return AppLockSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppLockSettings.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return AppLockSettings.defaults;
  }

  Future<void> writeSettings(AppLockSettings settings) async {
    await _storage.write(key: _kStateKey, value: jsonEncode(settings.toJson()));
  }

  Future<bool> hasPassword() async {
    return (await _readPasswordRecord()) != null;
  }

  Future<void> setPassword(String password) async {
    final salt = _generateSalt();
    final digest = _hashPassword(password, salt);
    final record = _PasswordRecord(salt: salt, hash: digest);
    await _storage.write(key: _kPasswordKey, value: jsonEncode(record.toJson()));
  }

  Future<bool> verifyPassword(String password) async {
    final record = await _readPasswordRecord();
    if (record == null) return false;
    final digest = _hashPassword(password, record.salt);
    return digest == record.hash;
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  Future<_PasswordRecord?> _readPasswordRecord() async {
    final raw = await _storage.read(key: _kPasswordKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _PasswordRecord.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }
}

class _PasswordRecord {
  const _PasswordRecord({required this.salt, required this.hash});

  final String salt;
  final String hash;

  Map<String, dynamic> toJson() => {
        'salt': salt,
        'hash': hash,
      };

  factory _PasswordRecord.fromJson(Map<String, dynamic> json) {
    final salt = json['salt'];
    final hash = json['hash'];
    if (salt is! String || hash is! String) {
      throw const FormatException('Invalid password record');
    }
    return _PasswordRecord(salt: salt, hash: hash);
  }
}
