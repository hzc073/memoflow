import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/memo_template_settings.dart';
import '../data/settings/memo_template_settings_repository.dart';
import 'session_provider.dart';
import 'webdav_sync_trigger_provider.dart';

final memoTemplateSettingsRepositoryProvider =
    Provider<MemoTemplateSettingsRepository>((ref) {
      final session = ref.watch(appSessionProvider).valueOrNull;
      final key = session?.currentKey?.trim();
      final storageKey = (key == null || key.isEmpty) ? 'device' : key;
      return MemoTemplateSettingsRepository(
        ref.watch(secureStorageProvider),
        accountKey: storageKey,
      );
    });

final memoTemplateSettingsProvider =
    StateNotifierProvider<MemoTemplateSettingsController, MemoTemplateSettings>(
      (ref) {
        return MemoTemplateSettingsController(
          ref,
          ref.watch(memoTemplateSettingsRepositoryProvider),
        );
      },
    );

class MemoTemplateSettingsController
    extends StateNotifier<MemoTemplateSettings> {
  MemoTemplateSettingsController(this._ref, this._repo)
    : super(MemoTemplateSettings.defaults) {
    unawaited(_load());
  }

  final Ref _ref;
  final MemoTemplateSettingsRepository _repo;

  Future<void> _load() async {
    final stored = await _repo.read();
    state = stored;
  }

  void _setAndPersist(MemoTemplateSettings next, {bool triggerSync = true}) {
    state = next;
    unawaited(_repo.write(next));
    if (triggerSync) {
      _ref.read(webDavSyncTriggerProvider.notifier).bump();
    }
  }

  Future<void> setAll(
    MemoTemplateSettings next, {
    bool triggerSync = true,
  }) async {
    state = next;
    await _repo.write(next);
    if (triggerSync) {
      _ref.read(webDavSyncTriggerProvider.notifier).bump();
    }
  }

  void setEnabled(bool value) {
    _setAndPersist(state.copyWith(enabled: value));
  }

  void setVariables(MemoTemplateVariableSettings value) {
    _setAndPersist(state.copyWith(variables: value));
  }

  void setDateFormat(String value) {
    _setAndPersist(
      state.copyWith(
        variables: state.variables.copyWith(
          dateFormat: value.trim().isEmpty
              ? MemoTemplateVariableSettings.defaults.dateFormat
              : value.trim(),
        ),
      ),
    );
  }

  void setTimeFormat(String value) {
    _setAndPersist(
      state.copyWith(
        variables: state.variables.copyWith(
          timeFormat: value.trim().isEmpty
              ? MemoTemplateVariableSettings.defaults.timeFormat
              : value.trim(),
        ),
      ),
    );
  }

  void setDateTimeFormat(String value) {
    _setAndPersist(
      state.copyWith(
        variables: state.variables.copyWith(
          dateTimeFormat: value.trim().isEmpty
              ? MemoTemplateVariableSettings.defaults.dateTimeFormat
              : value.trim(),
        ),
      ),
    );
  }

  void setWeatherEnabled(bool value) {
    _setAndPersist(
      state.copyWith(
        variables: state.variables.copyWith(weatherEnabled: value),
      ),
    );
  }

  void setWeatherCity(String value) {
    _setAndPersist(
      state.copyWith(
        variables: state.variables.copyWith(weatherCity: value.trim()),
      ),
    );
  }

  void setWeatherFallback(String value) {
    _setAndPersist(
      state.copyWith(
        variables: state.variables.copyWith(
          weatherFallback: value.trim().isEmpty
              ? MemoTemplateVariableSettings.defaults.weatherFallback
              : value.trim(),
        ),
      ),
    );
  }

  void setKeepUnknownVariables(bool value) {
    _setAndPersist(
      state.copyWith(
        variables: state.variables.copyWith(keepUnknownVariables: value),
      ),
    );
  }

  void setTemplates(List<MemoTemplate> templates) {
    _setAndPersist(
      state.copyWith(templates: templates.toList(growable: false)),
    );
  }

  void upsertTemplate(MemoTemplate template) {
    final list = state.templates.toList(growable: true);
    final index = list.indexWhere((element) => element.id == template.id);
    if (index >= 0) {
      list[index] = template;
    } else {
      list.add(template);
    }
    _setAndPersist(state.copyWith(templates: list.toList(growable: false)));
  }

  void removeTemplateById(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return;
    final next = state.templates
        .where((element) => element.id != normalized)
        .toList(growable: false);
    if (next.length == state.templates.length) return;
    _setAndPersist(state.copyWith(templates: next));
  }
}
