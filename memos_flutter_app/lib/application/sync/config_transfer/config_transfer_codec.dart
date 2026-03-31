import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../data/ai/ai_settings_models.dart';
import '../../../data/models/app_lock.dart';
import '../../../data/models/app_preferences.dart';
import '../../../data/models/image_bed_settings.dart';
import '../../../data/models/image_compression_settings.dart';
import '../../../data/models/location_settings.dart';
import '../../../data/models/memo_template_settings.dart';
import '../../../data/models/reminder_settings.dart';
import '../../../data/models/webdav_settings.dart';
import '../compose_draft_transfer.dart';
import '../migration/memoflow_migration_models.dart';
import '../migration/memoflow_migration_preferences_filter.dart';
import 'config_transfer_bundle.dart';

class ConfigTransferCodec {
  static const preferencesPath = 'config/preferences.json';
  static const reminderSettingsPath = 'config/reminder_settings.json';
  static const templateSettingsPath = 'config/template_settings.json';
  static const locationSettingsPath = 'config/location_settings.json';
  static const imageCompressionSettingsPath =
      'config/image_compression_settings.json';
  static const aiSettingsPath = 'config/ai_settings.json';
  static const imageBedSettingsPath = 'config/image_bed.json';
  static const appLockPath = 'config/app_lock.json';
  static const webDavSettingsPath = 'config/webdav_settings.json';
  static const draftBoxPath = composeDraftTransferConfigPath;
  static const legacyNoteDraftPath = 'config/note_draft.json';

  const ConfigTransferCodec();

  Map<String, Uint8List> encode(
    ConfigTransferBundle bundle, {
    required Set<MemoFlowMigrationConfigType> configTypes,
  }) {
    final files = <String, Uint8List>{};

    void writeFile(String path, Map<String, dynamic> value) {
      files[path] = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    }

    for (final type in configTypes) {
      switch (type) {
        case MemoFlowMigrationConfigType.preferences:
          final value = bundle.preferences;
          if (value != null) writeFile(preferencesPath, value.toJson());
        case MemoFlowMigrationConfigType.reminderSettings:
          final value = bundle.reminderSettings;
          if (value != null) writeFile(reminderSettingsPath, value.toJson());
        case MemoFlowMigrationConfigType.templateSettings:
          final value = bundle.templateSettings;
          if (value != null) writeFile(templateSettingsPath, value.toJson());
        case MemoFlowMigrationConfigType.locationSettings:
          final value = bundle.locationSettings;
          if (value != null) writeFile(locationSettingsPath, value.toJson());
        case MemoFlowMigrationConfigType.imageCompressionSettings:
          final value = bundle.imageCompressionSettings;
          if (value != null) {
            writeFile(imageCompressionSettingsPath, value.toJson());
          }
        case MemoFlowMigrationConfigType.aiSettings:
          final value = bundle.aiSettings;
          if (value != null) writeFile(aiSettingsPath, value.toJson());
        case MemoFlowMigrationConfigType.imageBedSettings:
          final value = bundle.imageBedSettings;
          if (value != null) writeFile(imageBedSettingsPath, value.toJson());
        case MemoFlowMigrationConfigType.appLock:
          final value = bundle.appLockSnapshot;
          if (value != null) writeFile(appLockPath, value.toJson());
        case MemoFlowMigrationConfigType.webdavSettings:
          final value = bundle.webDavSettings;
          if (value != null) writeFile(webDavSettingsPath, value.toJson());
        case MemoFlowMigrationConfigType.draftBox:
          final value = bundle.draftBox;
          if (value != null) {
            writeFile(draftBoxPath, value.toJson());
            for (final draft in value.drafts) {
              for (final attachment in draft.attachments) {
                final sourceFilePath = attachment.sourceFilePath?.trim() ?? '';
                if (sourceFilePath.isEmpty) {
                  throw const FormatException(
                    'Draft attachment source path missing',
                  );
                }
                final file = File(sourceFilePath);
                if (!file.existsSync()) {
                  throw FileSystemException(
                    'Draft attachment file not found',
                    sourceFilePath,
                  );
                }
                files[attachment.path] = Uint8List.fromList(
                  file.readAsBytesSync(),
                );
              }
            }
          }
      }
    }

    return files;
  }

  Future<ConfigTransferBundle> decodeFromDirectory(Directory root) async {
    Future<Map<String, dynamic>?> readJson(String relativePath) async {
      final file = File('${root.path}${Platform.pathSeparator}$relativePath');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    }

    final preferencesJson = await readJson(preferencesPath);
    final aiJson = await readJson(aiSettingsPath);
    final reminderJson = await readJson(reminderSettingsPath);
    final imageBedJson = await readJson(imageBedSettingsPath);
    final imageCompressionJson = await readJson(imageCompressionSettingsPath);
    final locationJson = await readJson(locationSettingsPath);
    final templateJson = await readJson(templateSettingsPath);
    final appLockJson = await readJson(appLockPath);
    final webDavJson = await readJson(webDavSettingsPath);
    final draftBoxJson = await readJson(draftBoxPath);
    final legacyNoteDraftJson = await readJson(legacyNoteDraftPath);

    String? legacyNoteDraftText() {
      final raw = legacyNoteDraftJson;
      if (raw == null) return null;
      final text = raw['text'];
      if (text is String && text.trim().isNotEmpty) return text;
      return null;
    }

    return ConfigTransferBundle(
      preferences: preferencesJson == null
          ? null
          : AppPreferencesTransferPayload.fromJson(preferencesJson),
      aiSettings: aiJson == null ? null : AiSettings.fromJson(aiJson),
      reminderSettings: reminderJson == null
          ? null
          : ReminderSettings.fromJson(
              reminderJson,
              fallback: ReminderSettings.defaultsFor(AppLanguage.en),
            ),
      imageBedSettings: imageBedJson == null
          ? null
          : ImageBedSettings.fromJson(imageBedJson),
      imageCompressionSettings: imageCompressionJson == null
          ? null
          : ImageCompressionSettings.fromJson(imageCompressionJson),
      locationSettings: locationJson == null
          ? null
          : LocationSettings.fromJson(locationJson),
      templateSettings: templateJson == null
          ? null
          : MemoTemplateSettings.fromJson(templateJson),
      appLockSnapshot: appLockJson == null
          ? null
          : AppLockSnapshot.fromJson(appLockJson),
      webDavSettings: webDavJson == null
          ? null
          : WebDavSettings.fromJson(webDavJson),
      draftBox: draftBoxJson == null
          ? (() {
              final legacyText = legacyNoteDraftText();
              if (legacyText == null) return null;
              return ComposeDraftTransferBundle.fromLegacyNoteDraft(legacyText);
            })()
          : ComposeDraftTransferBundle.fromJson(draftBoxJson),
    );
  }
}
