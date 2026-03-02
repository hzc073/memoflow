import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings/ai_settings_repository.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/models/image_bed_settings.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_template_settings.dart';
import '../../state/ai_settings_provider.dart';
import '../../state/app_lock_provider.dart';
import '../../state/image_bed_settings_provider.dart';
import '../../state/location_settings_provider.dart';
import '../../state/memo_template_settings_provider.dart';
import '../../state/note_draft_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/reminder_settings_provider.dart';
import '../../state/webdav_settings_provider.dart';
import 'webdav_sync_service.dart';

class RiverpodWebDavSyncLocalAdapter implements WebDavSyncLocalAdapter {
  RiverpodWebDavSyncLocalAdapter(this._ref);

  final Ref _ref;

  @override
  Future<WebDavSyncLocalSnapshot> readSnapshot() async {
    final prefs = _ref.read(appPreferencesProvider);
    final ai = _ref.read(aiSettingsProvider);
    final reminder = _ref.read(reminderSettingsProvider);
    final imageBed = _ref.read(imageBedSettingsProvider);
    final location = _ref.read(locationSettingsProvider);
    final template = _ref.read(memoTemplateSettingsProvider);
    final lockRepo = _ref.read(appLockRepositoryProvider);
    final lockSnapshot = await lockRepo.readSnapshot();
    final draft = _ref.read(noteDraftProvider).valueOrNull ?? '';
    return WebDavSyncLocalSnapshot(
      preferences: prefs,
      aiSettings: ai,
      reminderSettings: reminder,
      imageBedSettings: imageBed,
      locationSettings: location,
      templateSettings: template,
      appLockSnapshot: lockSnapshot,
      noteDraft: draft,
    );
  }

  @override
  Future<void> applyPreferences(AppPreferences preferences) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .setAll(preferences, triggerSync: false);
  }

  @override
  Future<void> applyAiSettings(AiSettings settings) async {
    await _ref
        .read(aiSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyReminderSettings(ReminderSettings settings) async {
    await _ref
        .read(reminderSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyImageBedSettings(ImageBedSettings settings) async {
    await _ref
        .read(imageBedSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyLocationSettings(LocationSettings settings) async {
    await _ref
        .read(locationSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyTemplateSettings(MemoTemplateSettings settings) async {
    await _ref
        .read(memoTemplateSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyAppLockSnapshot(AppLockSnapshot snapshot) async {
    await _ref
        .read(appLockProvider.notifier)
        .setSnapshot(snapshot, triggerSync: false);
  }

  @override
  Future<void> applyNoteDraft(String text) async {
    await _ref
        .read(noteDraftProvider.notifier)
        .setDraft(text, triggerSync: false);
  }

  @override
  Future<void> applyWebDavSettings(WebDavSettings settings) async {
    _ref.read(webDavSettingsProvider.notifier).setAll(settings);
  }
}
