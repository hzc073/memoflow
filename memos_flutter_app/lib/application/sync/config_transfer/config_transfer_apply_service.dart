import '../../../data/ai/ai_settings_models.dart';
import '../../../data/models/app_lock.dart';
import '../../../data/models/app_preferences.dart';
import '../../../data/models/image_bed_settings.dart';
import '../../../data/models/image_compression_settings.dart';
import '../../../data/models/location_settings.dart';
import '../../../data/models/memo_template_settings.dart';
import '../../../data/models/reminder_settings.dart';
import '../../../data/models/webdav_settings.dart';
import '../migration/memoflow_migration_models.dart';
import '../migration/memoflow_migration_preferences_filter.dart';
import 'config_transfer_bundle.dart';

abstract class ConfigTransferLocalAdapter {
  Future<AppPreferences> readPreferences();
  Future<void> applyPreferences(AppPreferences preferences);

  Future<void> applyAiSettings(AiSettings settings);
  Future<void> applyReminderSettings(ReminderSettings settings);
  Future<void> applyImageBedSettings(ImageBedSettings settings);
  Future<void> applyImageCompressionSettings(ImageCompressionSettings settings);
  Future<void> applyLocationSettings(LocationSettings settings);
  Future<void> applyTemplateSettings(MemoTemplateSettings settings);
  Future<void> applyAppLockSnapshot(AppLockSnapshot snapshot);
  Future<void> applyWebDavSettings(WebDavSettings settings);
}

class ConfigTransferApplyService {
  const ConfigTransferApplyService({
    required this.localAdapter,
    required this.preferencesFilter,
  });

  final ConfigTransferLocalAdapter localAdapter;
  final MigrationPreferencesFilter preferencesFilter;

  Future<Set<MemoFlowMigrationConfigType>> applyBundle(
    ConfigTransferBundle bundle, {
    required Set<MemoFlowMigrationConfigType> allowedTypes,
  }) async {
    final applied = <MemoFlowMigrationConfigType>{};

    if (allowedTypes.contains(MemoFlowMigrationConfigType.preferences) &&
        bundle.preferences != null) {
      final current = await localAdapter.readPreferences();
      final merged = preferencesFilter.mergeTransferable(
        current,
        bundle.preferences!,
      );
      await localAdapter.applyPreferences(merged);
      applied.add(MemoFlowMigrationConfigType.preferences);
    }
    if (allowedTypes.contains(MemoFlowMigrationConfigType.reminderSettings) &&
        bundle.reminderSettings != null) {
      await localAdapter.applyReminderSettings(bundle.reminderSettings!);
      applied.add(MemoFlowMigrationConfigType.reminderSettings);
    }
    if (allowedTypes.contains(MemoFlowMigrationConfigType.templateSettings) &&
        bundle.templateSettings != null) {
      await localAdapter.applyTemplateSettings(bundle.templateSettings!);
      applied.add(MemoFlowMigrationConfigType.templateSettings);
    }
    if (allowedTypes.contains(MemoFlowMigrationConfigType.locationSettings) &&
        bundle.locationSettings != null) {
      await localAdapter.applyLocationSettings(bundle.locationSettings!);
      applied.add(MemoFlowMigrationConfigType.locationSettings);
    }
    if (allowedTypes.contains(
          MemoFlowMigrationConfigType.imageCompressionSettings,
        ) &&
        bundle.imageCompressionSettings != null) {
      await localAdapter.applyImageCompressionSettings(
        bundle.imageCompressionSettings!,
      );
      applied.add(MemoFlowMigrationConfigType.imageCompressionSettings);
    }
    if (allowedTypes.contains(MemoFlowMigrationConfigType.aiSettings) &&
        bundle.aiSettings != null) {
      await localAdapter.applyAiSettings(bundle.aiSettings!);
      applied.add(MemoFlowMigrationConfigType.aiSettings);
    }
    if (allowedTypes.contains(MemoFlowMigrationConfigType.imageBedSettings) &&
        bundle.imageBedSettings != null) {
      await localAdapter.applyImageBedSettings(bundle.imageBedSettings!);
      applied.add(MemoFlowMigrationConfigType.imageBedSettings);
    }
    if (allowedTypes.contains(MemoFlowMigrationConfigType.appLock) &&
        bundle.appLockSnapshot != null) {
      await localAdapter.applyAppLockSnapshot(bundle.appLockSnapshot!);
      applied.add(MemoFlowMigrationConfigType.appLock);
    }
    if (allowedTypes.contains(MemoFlowMigrationConfigType.webdavSettings) &&
        bundle.webDavSettings != null) {
      await localAdapter.applyWebDavSettings(bundle.webDavSettings!);
      applied.add(MemoFlowMigrationConfigType.webdavSettings);
    }

    return applied;
  }
}
