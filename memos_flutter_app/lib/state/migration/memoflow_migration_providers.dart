import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/config_transfer/config_transfer_apply_service.dart';
import '../../application/sync/config_transfer/config_transfer_bundle.dart';
import '../../application/sync/config_transfer/config_transfer_codec.dart';
import '../../application/sync/compose_draft_transfer.dart';
import '../../application/sync/migration/memoflow_device_name_resolver.dart';
import '../../application/sync/migration/memoflow_migration_client.dart';
import '../../application/sync/migration/memoflow_migration_import_service.dart';
import '../../application/sync/migration/memoflow_migration_models.dart';
import '../../application/sync/migration/memoflow_migration_package_builder.dart';
import '../../application/sync/migration/memoflow_migration_preferences_filter.dart';
import '../../application/sync/migration/memoflow_migration_server.dart';
import '../../data/db/app_database.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../attachments/queued_attachment_stager_provider.dart';
import '../settings/ai_settings_provider.dart';
import '../settings/app_lock_provider.dart';
import '../settings/image_bed_settings_provider.dart';
import '../settings/image_compression_settings_provider.dart';
import '../settings/location_settings_provider.dart';
import '../memos/compose_draft_provider.dart';
import '../settings/memo_template_settings_provider.dart';
import '../settings/preferences_provider.dart';
import '../settings/reminder_settings_provider.dart';
import '../system/database_provider.dart';
import '../system/local_library_provider.dart';
import '../system/session_provider.dart';
import '../webdav/webdav_settings_provider.dart';
import 'memoflow_migration_receiver_controller.dart';
import 'memoflow_migration_sender_controller.dart';
import 'memoflow_migration_state.dart';

class RiverpodConfigTransferLocalAdapter implements ConfigTransferLocalAdapter {
  RiverpodConfigTransferLocalAdapter(this._ref, this._preferencesFilter);

  final Ref _ref;
  final MigrationPreferencesFilter _preferencesFilter;

  Future<ConfigTransferBundle> readBundle(
    Set<MemoFlowMigrationConfigType> configTypes,
  ) async {
    final prefs = _ref.read(appPreferencesProvider);
    final bundle = ConfigTransferBundle(
      preferences: configTypes.contains(MemoFlowMigrationConfigType.preferences)
          ? _preferencesFilter.extractTransferable(prefs)
          : null,
      aiSettings: configTypes.contains(MemoFlowMigrationConfigType.aiSettings)
          ? await _ref
                .read(aiSettingsRepositoryProvider)
                .read(language: prefs.language)
          : null,
      reminderSettings:
          configTypes.contains(MemoFlowMigrationConfigType.reminderSettings)
          ? _ref.read(reminderSettingsProvider)
          : null,
      imageBedSettings:
          configTypes.contains(MemoFlowMigrationConfigType.imageBedSettings)
          ? _ref.read(imageBedSettingsProvider)
          : null,
      imageCompressionSettings:
          configTypes.contains(
            MemoFlowMigrationConfigType.imageCompressionSettings,
          )
          ? _ref.read(imageCompressionSettingsProvider)
          : null,
      locationSettings:
          configTypes.contains(MemoFlowMigrationConfigType.locationSettings)
          ? _ref.read(locationSettingsProvider)
          : null,
      templateSettings:
          configTypes.contains(MemoFlowMigrationConfigType.templateSettings)
          ? _ref.read(memoTemplateSettingsProvider)
          : null,
      appLockSnapshot: configTypes.contains(MemoFlowMigrationConfigType.appLock)
          ? await _ref.read(appLockRepositoryProvider).readSnapshot()
          : null,
      webDavSettings:
          configTypes.contains(MemoFlowMigrationConfigType.webdavSettings)
          ? _ref.read(webDavSettingsProvider)
          : null,
      draftBox: configTypes.contains(MemoFlowMigrationConfigType.draftBox)
          ? ComposeDraftTransferBundle.fromDraftRecords(
              await _ref.read(composeDraftRepositoryProvider).listDrafts(),
            )
          : null,
    );
    return bundle;
  }

  @override
  Future<void> applyAiSettings(settings) async {
    await _ref
        .read(aiSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyAppLockSnapshot(snapshot) async {
    await _ref
        .read(appLockProvider.notifier)
        .setSnapshot(snapshot, triggerSync: false);
  }

  @override
  Future<void> applyImageBedSettings(settings) async {
    await _ref
        .read(imageBedSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyImageCompressionSettings(settings) async {
    await _ref
        .read(imageCompressionSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyLocationSettings(settings) async {
    await _ref
        .read(locationSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyPreferences(preferences) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .setAll(preferences, triggerSync: false);
  }

  @override
  Future<void> applyReminderSettings(settings) async {
    await _ref
        .read(reminderSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyTemplateSettings(settings) async {
    await _ref
        .read(memoTemplateSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyWebDavSettings(settings) async {
    _ref.read(webDavSettingsProvider.notifier).setAll(settings);
  }

  @override
  Future<AppPreferences> readPreferences() async {
    return _ref.read(appPreferencesProvider);
  }
}

final migrationPreferencesFilterProvider = Provider<MigrationPreferencesFilter>(
  (ref) {
    return const MigrationPreferencesFilter();
  },
);

final configTransferCodecProvider = Provider<ConfigTransferCodec>((ref) {
  return const ConfigTransferCodec();
});

final configTransferLocalAdapterProvider =
    Provider<RiverpodConfigTransferLocalAdapter>((ref) {
      return RiverpodConfigTransferLocalAdapter(
        ref,
        ref.watch(migrationPreferencesFilterProvider),
      );
    });

final memoFlowDeviceNameResolverProvider = Provider<MemoFlowDeviceNameResolver>(
  (ref) {
    return const MemoFlowDeviceNameResolver();
  },
);

final memoFlowMigrationPackageBuilderProvider =
    Provider<MemoFlowMigrationPackageBuilder>((ref) {
      final adapter = ref.watch(configTransferLocalAdapterProvider);
      return MemoFlowMigrationPackageBuilder(
        codec: ref.watch(configTransferCodecProvider),
        readConfigBundle: adapter.readBundle,
      );
    });

final memoFlowMigrationClientProvider = Provider<MemoFlowMigrationClient>((
  ref,
) {
  return MemoFlowMigrationClient();
});

final memoFlowMigrationImportServiceProvider =
    Provider<MemoFlowMigrationImportService>((ref) {
      return MemoFlowMigrationImportService(
        db: ref.watch(databaseProvider),
        attachmentStore: LocalAttachmentStore(),
        attachmentStager: ref.watch(queuedAttachmentStagerProvider),
        configApplyService: ConfigTransferApplyService(
          localAdapter: ref.watch(configTransferLocalAdapterProvider),
          preferencesFilter: ref.watch(migrationPreferencesFilterProvider),
        ),
        codec: ref.watch(configTransferCodecProvider),
        createWorkspaceDatabase: (workspaceKey) {
          return AppDatabase(dbName: databaseNameForAccountKey(workspaceKey));
        },
        deleteWorkspaceDatabase: (workspaceKey) {
          return AppDatabase.deleteDatabaseFile(
            dbName: databaseNameForAccountKey(workspaceKey),
          );
        },
        registerLibrary: (library) async {
          ref.read(localLibrariesProvider.notifier).upsert(library);
        },
        unregisterLibrary: (workspaceKey) {
          return ref.read(localLibrariesProvider.notifier).remove(workspaceKey);
        },
        switchWorkspace: (workspaceKey) async {
          await ref
              .read(appSessionProvider.notifier)
              .switchWorkspace(workspaceKey);
        },
        currentLibrary: () => ref.read(currentLocalLibraryProvider),
      );
    });

final memoFlowMigrationServerProvider =
    Provider.autoDispose<MemoFlowMigrationServer>((ref) {
      final server = MemoFlowMigrationServer(
        importService: ref.watch(memoFlowMigrationImportServiceProvider),
      );
      ref.onDispose(server.dispose);
      return server;
    });

final memoFlowMigrationSenderControllerProvider =
    StateNotifierProvider.autoDispose<
      MemoFlowMigrationSenderController,
      MemoFlowMigrationSenderState
    >((ref) {
      final controller = MemoFlowMigrationSenderController(
        initialLibrary: ref.read(currentLocalLibraryProvider),
        currentLibrary: () => ref.read(currentLocalLibraryProvider),
        packageBuilder: ref.watch(memoFlowMigrationPackageBuilderProvider),
        client: ref.watch(memoFlowMigrationClientProvider),
        deviceNameResolver: ref.watch(memoFlowDeviceNameResolverProvider),
      );
      ref.onDispose(() {
        unawaited(controller.disposeResources());
      });
      return controller;
    });

final memoFlowMigrationReceiverControllerProvider =
    StateNotifierProvider.autoDispose<
      MemoFlowMigrationReceiverController,
      MemoFlowMigrationReceiverState
    >((ref) {
      return MemoFlowMigrationReceiverController(
        server: ref.watch(memoFlowMigrationServerProvider),
        deviceNameResolver: ref.watch(memoFlowDeviceNameResolverProvider),
        currentLibrary: () => ref.read(currentLocalLibraryProvider),
      );
    });
