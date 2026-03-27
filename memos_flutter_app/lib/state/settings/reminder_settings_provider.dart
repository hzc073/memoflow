import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../data/models/reminder_settings.dart';
import 'preferences_provider.dart';
import '../system/session_provider.dart';

export '../../data/models/reminder_settings.dart';
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
