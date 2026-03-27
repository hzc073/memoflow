import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_coordinator.dart';
import '../../application/sync/sync_dependencies.dart';
import '../../application/sync/webdav_backup_service.dart';
import '../../application/sync/webdav_sync_service.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../system/database_provider.dart';
import '../system/local_library_provider.dart';
import '../memos/memos_providers.dart';
import '../system/session_provider.dart';
import '../webdav/webdav_backup_provider.dart'
    show
        webDavBackupPasswordRepositoryProvider,
        webDavBackupProgressTrackerProvider,
        webDavBackupStateRepositoryProvider;
import '../webdav/webdav_local_adapter.dart';
import '../webdav/webdav_log_provider.dart';
import '../webdav/webdav_settings_provider.dart';
import '../webdav/webdav_device_id_provider.dart'
    show webDavAccountKeyProvider, webDavDeviceIdRepositoryProvider;
import '../webdav/webdav_sync_provider.dart'
    show webDavSyncStateRepositoryProvider;
import '../webdav/webdav_vault_provider.dart';

final syncCoordinatorProvider =
    StateNotifierProvider<SyncCoordinator, SyncCoordinatorState>((ref) {
      final container = ref.container;
      final attachmentStore = LocalAttachmentStore();
      final localAdapter = RiverpodWebDavSyncLocalAdapter(container);
      final webDavSyncService = WebDavSyncService(
        syncStateRepository: ref.watch(webDavSyncStateRepositoryProvider),
        deviceIdRepository: ref.watch(webDavDeviceIdRepositoryProvider),
        localAdapter: localAdapter,
        vaultService: ref.watch(webDavVaultServiceProvider),
        vaultPasswordRepository: ref.watch(
          webDavVaultPasswordRepositoryProvider,
        ),
        logWriter: (entry) =>
            unawaited(container.read(webDavLogStoreProvider).add(entry)),
      );
      final webDavBackupService = WebDavBackupService(
        readDatabase: () => container.read(databaseProvider),
        attachmentStore: attachmentStore,
        stateRepository: ref.watch(webDavBackupStateRepositoryProvider),
        passwordRepository: ref.watch(webDavBackupPasswordRepositoryProvider),
        vaultService: ref.watch(webDavVaultServiceProvider),
        vaultPasswordRepository: ref.watch(
          webDavVaultPasswordRepositoryProvider,
        ),
        configAdapter: localAdapter,
        progressTracker: ref.watch(webDavBackupProgressTrackerProvider),
        logWriter: (entry) =>
            unawaited(container.read(webDavLogStoreProvider).add(entry)),
      );
      final deps = SyncDependencies(
        webDavSyncService: webDavSyncService,
        webDavBackupService: webDavBackupService,
        webDavBackupStateRepository: ref.watch(
          webDavBackupStateRepositoryProvider,
        ),
        readWebDavSettings: () => container.read(webDavSettingsProvider),
        readCurrentAccountKey: () => container.read(webDavAccountKeyProvider),
        readCurrentAccount: () =>
            container.read(appSessionProvider).valueOrNull?.currentAccount,
        readCurrentLocalLibrary: () =>
            container.read(currentLocalLibraryProvider),
        readDatabase: () => container.read(databaseProvider),
        runMemosSync: () =>
            container.read(syncControllerProvider.notifier).syncNow(),
        logWriter: (entry) =>
            unawaited(container.read(webDavLogStoreProvider).add(entry)),
      );
      return SyncCoordinator(deps);
    });
