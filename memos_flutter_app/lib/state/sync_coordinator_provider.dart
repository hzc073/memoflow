import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync/sync_coordinator.dart';
import '../application/sync/sync_dependencies.dart';
import '../application/sync/webdav_backup_service.dart';
import '../application/sync/webdav_sync_service.dart';
import '../data/local_library/local_attachment_store.dart';
import 'database_provider.dart';
import 'local_library_provider.dart';
import 'memos_providers.dart';
import 'session_provider.dart';
import 'webdav_backup_provider.dart'
    show
        webDavBackupPasswordRepositoryProvider,
        webDavBackupProgressTrackerProvider,
        webDavBackupStateRepositoryProvider;
import 'webdav_local_adapter.dart';
import 'webdav_log_provider.dart';
import 'webdav_settings_provider.dart';
import 'webdav_device_id_provider.dart'
    show webDavAccountKeyProvider, webDavDeviceIdRepositoryProvider;
import 'webdav_sync_provider.dart'
    show webDavSyncStateRepositoryProvider;
import 'webdav_vault_provider.dart';

final syncCoordinatorProvider =
    StateNotifierProvider<SyncCoordinator, SyncCoordinatorState>((ref) {
      final db = ref.watch(databaseProvider);
      final attachmentStore = LocalAttachmentStore();
      final localAdapter = RiverpodWebDavSyncLocalAdapter(ref);
      final webDavSyncService = WebDavSyncService(
        syncStateRepository: ref.watch(webDavSyncStateRepositoryProvider),
        deviceIdRepository: ref.watch(webDavDeviceIdRepositoryProvider),
        localAdapter: localAdapter,
        vaultService: ref.watch(webDavVaultServiceProvider),
        vaultPasswordRepository: ref.watch(webDavVaultPasswordRepositoryProvider),
        logWriter: (entry) =>
            unawaited(ref.read(webDavLogStoreProvider).add(entry)),
      );
      final webDavBackupService = WebDavBackupService(
        db: db,
        attachmentStore: attachmentStore,
        stateRepository: ref.watch(webDavBackupStateRepositoryProvider),
        passwordRepository: ref.watch(webDavBackupPasswordRepositoryProvider),
        vaultService: ref.watch(webDavVaultServiceProvider),
        vaultPasswordRepository: ref.watch(webDavVaultPasswordRepositoryProvider),
        configAdapter: localAdapter,
        progressTracker: ref.watch(webDavBackupProgressTrackerProvider),
        logWriter: (entry) =>
            unawaited(ref.read(webDavLogStoreProvider).add(entry)),
      );
      final deps = SyncDependencies(
        webDavSyncService: webDavSyncService,
        webDavBackupService: webDavBackupService,
        webDavBackupStateRepository: ref.watch(
          webDavBackupStateRepositoryProvider,
        ),
        readWebDavSettings: () => ref.read(webDavSettingsProvider),
        readCurrentAccountKey: () => ref.read(webDavAccountKeyProvider),
        readCurrentAccount: () =>
            ref.read(appSessionProvider).valueOrNull?.currentAccount,
        readCurrentLocalLibrary: () => ref.read(currentLocalLibraryProvider),
        readDatabase: () => db,
        runMemosSync: () => ref.read(syncControllerProvider.notifier).syncNow(),
      );
      return SyncCoordinator(deps);
    });
