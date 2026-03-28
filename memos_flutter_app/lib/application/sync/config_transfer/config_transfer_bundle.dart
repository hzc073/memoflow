import '../../../data/ai/ai_settings_models.dart';
import '../../../data/models/app_lock.dart';
import '../../../data/models/image_bed_settings.dart';
import '../../../data/models/image_compression_settings.dart';
import '../../../data/models/location_settings.dart';
import '../../../data/models/memo_template_settings.dart';
import '../../../data/models/reminder_settings.dart';
import '../../../data/models/webdav_settings.dart';
import '../migration/memoflow_migration_preferences_filter.dart';

class ConfigTransferBundle {
  const ConfigTransferBundle({
    this.preferences,
    this.aiSettings,
    this.reminderSettings,
    this.imageBedSettings,
    this.imageCompressionSettings,
    this.locationSettings,
    this.templateSettings,
    this.appLockSnapshot,
    this.webDavSettings,
  });

  final AppPreferencesTransferPayload? preferences;
  final AiSettings? aiSettings;
  final ReminderSettings? reminderSettings;
  final ImageBedSettings? imageBedSettings;
  final ImageCompressionSettings? imageCompressionSettings;
  final LocationSettings? locationSettings;
  final MemoTemplateSettings? templateSettings;
  final AppLockSnapshot? appLockSnapshot;
  final WebDavSettings? webDavSettings;

  bool get isEmpty =>
      preferences == null &&
      aiSettings == null &&
      reminderSettings == null &&
      imageBedSettings == null &&
      imageCompressionSettings == null &&
      locationSettings == null &&
      templateSettings == null &&
      appLockSnapshot == null &&
      webDavSettings == null;
}
