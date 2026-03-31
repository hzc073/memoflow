import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/webdav_sync_service.dart';
import '../../data/models/image_compression_settings.dart';
import '../../data/models/image_bed_settings.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/compose_draft.dart';
import '../../data/models/tag_snapshot.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../memos/compose_draft_provider.dart';
import '../settings/ai_settings_provider.dart';
import '../settings/app_lock_provider.dart';
import '../settings/image_bed_settings_provider.dart';
import '../settings/image_compression_settings_provider.dart';
import '../settings/location_settings_provider.dart';
import '../settings/memo_template_settings_provider.dart';
import '../memos/note_draft_provider.dart';
import '../settings/preferences_provider.dart';
import '../settings/reminder_settings_provider.dart';
import '../system/session_provider.dart';
import '../tags/tag_repository.dart';
import 'webdav_settings_provider.dart';

class RiverpodWebDavSyncLocalAdapter implements WebDavSyncLocalAdapter {
  RiverpodWebDavSyncLocalAdapter(this._container);

  final ProviderContainer _container;

  @override
  String? get currentWorkspaceKey =>
      _container.read(appSessionProvider).valueOrNull?.currentKey;

  @override
  Future<WebDavSyncLocalSnapshot> readSnapshot() async {
    final prefs = _container.read(appPreferencesProvider);
    final ai = await _container
        .read(aiSettingsRepositoryProvider)
        .read(language: prefs.language);
    final reminder = _container.read(reminderSettingsProvider);
    final imageBed = _container.read(imageBedSettingsProvider);
    final imageCompression = _container.read(imageCompressionSettingsProvider);
    final location = _container.read(locationSettingsProvider);
    final template = _container.read(memoTemplateSettingsProvider);
    final lockRepo = _container.read(appLockRepositoryProvider);
    final lockSnapshot = await lockRepo.readSnapshot();
    final draft = _container.read(noteDraftProvider).valueOrNull ?? '';
    final tagsSnapshot = await _container
        .read(tagRepositoryProvider)
        .readSnapshot();
    return WebDavSyncLocalSnapshot(
      preferences: prefs,
      aiSettings: ai,
      reminderSettings: reminder,
      imageBedSettings: imageBed,
      imageCompressionSettings: imageCompression,
      locationSettings: location,
      templateSettings: template,
      appLockSnapshot: lockSnapshot,
      noteDraft: draft,
      tagsSnapshot: tagsSnapshot,
    );
  }

  @override
  Future<void> applyPreferences(AppPreferences preferences) async {
    await _container
        .read(appPreferencesProvider.notifier)
        .setAll(preferences, triggerSync: false);
  }

  @override
  Future<void> applyAiSettings(AiSettings settings) async {
    await _container
        .read(aiSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyReminderSettings(ReminderSettings settings) async {
    await _container
        .read(reminderSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyImageBedSettings(ImageBedSettings settings) async {
    await _container
        .read(imageBedSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyImageCompressionSettings(
    ImageCompressionSettings settings,
  ) async {
    await _container
        .read(imageCompressionSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyLocationSettings(LocationSettings settings) async {
    await _container
        .read(locationSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyTemplateSettings(MemoTemplateSettings settings) async {
    await _container
        .read(memoTemplateSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyAppLockSnapshot(AppLockSnapshot snapshot) async {
    await _container
        .read(appLockProvider.notifier)
        .setSnapshot(snapshot, triggerSync: false);
  }

  @override
  Future<void> applyNoteDraft(String text) async {
    await _container
        .read(noteDraftProvider.notifier)
        .setDraft(text, triggerSync: false);
  }

  @override
  Future<List<ComposeDraftRecord>> readComposeDrafts() {
    return _container.read(composeDraftRepositoryProvider).listDrafts();
  }

  @override
  Future<void> replaceComposeDrafts(List<ComposeDraftRecord> drafts) async {
    final repository = _container.read(composeDraftRepositoryProvider);
    await repository.replaceAllDrafts(drafts);
    final latestDraft = await repository.latestDraft();
    final noteDraftController = _container.read(noteDraftProvider.notifier);
    if (latestDraft == null) {
      await noteDraftController.clear(triggerSync: false);
      return;
    }
    await noteDraftController.setDraft(
      latestDraft.snapshot.content,
      triggerSync: false,
    );
  }

  @override
  Future<void> applyTags(TagSnapshot snapshot) async {
    await _container.read(tagRepositoryProvider).applySnapshot(snapshot);
  }

  @override
  Future<void> applyWebDavSettings(WebDavSettings settings) async {
    _container.read(webDavSettingsProvider.notifier).setAll(settings);
  }
}
