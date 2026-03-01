import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../application/sync/sync_coordinator.dart';
import '../application/sync/sync_request.dart';
import '../core/app_localization.dart';
import 'preferences_provider.dart';
import 'session_provider.dart';

enum ReminderSoundMode { system, silent, custom }

class ReminderSettings {
  static const Object _unset = Object();

  const ReminderSettings({
    required this.enabled,
    required this.notificationTitle,
    required this.notificationBody,
    required this.soundMode,
    required this.soundUri,
    required this.soundTitle,
    required this.vibrationEnabled,
    required this.dndEnabled,
    required this.dndStartMinutes,
    required this.dndEndMinutes,
  });

  final bool enabled;
  final String notificationTitle;
  final String notificationBody;
  final ReminderSoundMode soundMode;
  final String? soundUri;
  final String? soundTitle;
  final bool vibrationEnabled;
  final bool dndEnabled;
  final int dndStartMinutes;
  final int dndEndMinutes;

  static ReminderSettings defaultsFor(AppLanguage language) {
    final title = trByLanguageKey(
      language: language,
      key: 'legacy.reminder.default_title',
    );
    final body = trByLanguageKey(
      language: language,
      key: 'legacy.reminder.default_body',
    );
    return ReminderSettings(
      enabled: false,
      notificationTitle: title,
      notificationBody: body,
      soundMode: ReminderSoundMode.system,
      soundUri: null,
      soundTitle: null,
      vibrationEnabled: true,
      dndEnabled: false,
      dndStartMinutes: 23 * 60,
      dndEndMinutes: 7 * 60,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
        'soundMode': soundMode.name,
        'soundUri': soundUri,
        'soundTitle': soundTitle,
        'vibrationEnabled': vibrationEnabled,
        'dndEnabled': dndEnabled,
        'dndStartMinutes': dndStartMinutes,
        'dndEndMinutes': dndEndMinutes,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json, {required ReminderSettings fallback}) {
    ReminderSoundMode parseSoundMode() {
      final raw = json['soundMode'];
      if (raw is String) {
        return ReminderSoundMode.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => fallback.soundMode,
        );
      }
      return fallback.soundMode;
    }

    bool parseBool(String key, bool fallbackValue) {
      final raw = json[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      return fallbackValue;
    }

    String parseString(String key, String fallbackValue) {
      final raw = json[key];
      if (raw is String) return raw;
      return fallbackValue;
    }

    String? parseNullableString(String key) {
      final raw = json[key];
      if (raw is String && raw.trim().isNotEmpty) return raw;
      return null;
    }

    int parseMinutes(String key, int fallbackValue) {
      final raw = json[key];
      if (raw is int) return raw.clamp(0, 24 * 60 - 1);
      if (raw is num) return raw.toInt().clamp(0, 24 * 60 - 1);
      return fallbackValue;
    }

    var soundMode = parseSoundMode();
    final soundUri = parseNullableString('soundUri');
    if (soundMode == ReminderSoundMode.custom && soundUri == null) {
      soundMode = ReminderSoundMode.system;
    }

    return ReminderSettings(
      enabled: parseBool('enabled', fallback.enabled),
      notificationTitle: parseString('notificationTitle', fallback.notificationTitle),
      notificationBody: parseString('notificationBody', fallback.notificationBody),
      soundMode: soundMode,
      soundUri: soundUri,
      soundTitle: parseNullableString('soundTitle') ?? fallback.soundTitle,
      vibrationEnabled: parseBool('vibrationEnabled', fallback.vibrationEnabled),
      dndEnabled: parseBool('dndEnabled', fallback.dndEnabled),
      dndStartMinutes: parseMinutes('dndStartMinutes', fallback.dndStartMinutes),
      dndEndMinutes: parseMinutes('dndEndMinutes', fallback.dndEndMinutes),
    );
  }

  ReminderSettings copyWith({
    bool? enabled,
    String? notificationTitle,
    String? notificationBody,
    ReminderSoundMode? soundMode,
    Object? soundUri = _unset,
    Object? soundTitle = _unset,
    bool? vibrationEnabled,
    bool? dndEnabled,
    int? dndStartMinutes,
    int? dndEndMinutes,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      soundMode: soundMode ?? this.soundMode,
      soundUri: identical(soundUri, _unset) ? this.soundUri : soundUri as String?,
      soundTitle: identical(soundTitle, _unset) ? this.soundTitle : soundTitle as String?,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndStartMinutes: dndStartMinutes ?? this.dndStartMinutes,
      dndEndMinutes: dndEndMinutes ?? this.dndEndMinutes,
    );
  }

  TimeOfDay get dndStartTime => TimeOfDay(hour: dndStartMinutes ~/ 60, minute: dndStartMinutes % 60);
  TimeOfDay get dndEndTime => TimeOfDay(hour: dndEndMinutes ~/ 60, minute: dndEndMinutes % 60);
}

final reminderSettingsRepositoryProvider = Provider<ReminderSettingsRepository>((ref) {
  final accountKey = ref.watch(appSessionProvider.select((state) => state.valueOrNull?.currentKey));
  return ReminderSettingsRepository(ref.watch(secureStorageProvider), accountKey: accountKey);
});

final reminderSettingsLoadedProvider = StateProvider<bool>((ref) => false);

final reminderSettingsProvider = StateNotifierProvider<ReminderSettingsController, ReminderSettings>((ref) {
  final loadedState = ref.read(reminderSettingsLoadedProvider.notifier);
  Future.microtask(() => loadedState.state = false);
  return ReminderSettingsController(
    ref,
    ref.watch(reminderSettingsRepositoryProvider),
    onLoaded: () => loadedState.state = true,
  );
});

class ReminderSettingsController extends StateNotifier<ReminderSettings> {
  ReminderSettingsController(
    this._ref,
    this._repo, {
    void Function()? onLoaded,
  })  : _onLoaded = onLoaded,
        super(ReminderSettings.defaultsFor(_ref.read(appPreferencesProvider).language)) {
    unawaited(_loadFromStorage());
  }

  final Ref _ref;
  final ReminderSettingsRepository _repo;
  final void Function()? _onLoaded;

  Future<void> _loadFromStorage() async {
    final stored = await _repo.read();
    if (stored != null) {
      state = stored;
    } else {
      final defaults = ReminderSettings.defaultsFor(_ref.read(appPreferencesProvider).language);
      state = defaults;
      await _repo.write(defaults);
    }
    _onLoaded?.call();
  }

  void _setAndPersist(ReminderSettings next) {
    state = next;
    unawaited(_repo.write(next));
    unawaited(
      _ref.read(syncCoordinatorProvider.notifier).requestSync(
            const SyncRequest(
              kind: SyncRequestKind.webDavSync,
              reason: SyncRequestReason.settings,
            ),
          ),
    );
  }

  Future<void> setAll(ReminderSettings next, {bool triggerSync = true}) async {
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

  void setEnabled(bool value) => _setAndPersist(state.copyWith(enabled: value));
  void setNotificationTitle(String value) => _setAndPersist(state.copyWith(notificationTitle: value));
  void setNotificationBody(String value) => _setAndPersist(state.copyWith(notificationBody: value));
  void setSound({
    required ReminderSoundMode mode,
    String? uri,
    String? title,
  }) {
    _setAndPersist(
      state.copyWith(soundMode: mode, soundUri: uri, soundTitle: title),
    );
  }

  void setVibrationEnabled(bool value) => _setAndPersist(state.copyWith(vibrationEnabled: value));
  void setDndEnabled(bool value) => _setAndPersist(state.copyWith(dndEnabled: value));
  void setDndStartMinutes(int minutes) => _setAndPersist(state.copyWith(dndStartMinutes: minutes));
  void setDndEndMinutes(int minutes) => _setAndPersist(state.copyWith(dndEndMinutes: minutes));
}

class ReminderSettingsRepository {
  ReminderSettingsRepository(this._storage, {required String? accountKey}) : _accountKey = accountKey;

  static const _kPrefix = 'reminder_settings_v2_';
  static const _kLegacyKey = 'reminder_settings_v1';

  final FlutterSecureStorage _storage;
  final String? _accountKey;

  String? get _storageKey {
    final key = _accountKey;
    if (key == null || key.trim().isEmpty) return null;
    return '$_kPrefix$key';
  }

  Future<ReminderSettings?> read() async {
    final storageKey = _storageKey;
    if (storageKey == null) return null;
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      final legacy = await _storage.read(key: _kLegacyKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(legacy);
          if (decoded is Map) {
            final fallback = ReminderSettings.defaultsFor(AppLanguage.zhHans);
            final settings = ReminderSettings.fromJson(decoded.cast<String, dynamic>(), fallback: fallback);
            await write(settings);
            return settings;
          }
        } catch (_) {}
      }
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final fallback = ReminderSettings.defaultsFor(AppLanguage.zhHans);
        return ReminderSettings.fromJson(decoded.cast<String, dynamic>(), fallback: fallback);
      }
    } catch (_) {}
    return null;
  }

  Future<void> write(ReminderSettings settings) async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.write(key: storageKey, value: jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final storageKey = _storageKey;
    if (storageKey == null) return;
    await _storage.delete(key: storageKey);
  }
}
