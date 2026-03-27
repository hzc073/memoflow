import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/webdav_backup_service.dart';
import 'webdav_local_adapter.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../../data/logs/webdav_backup_progress_tracker.dart';
import '../../data/repositories/webdav_backup_password_repository.dart';
import '../../data/repositories/webdav_backup_state_repository.dart';
import 'webdav_device_id_provider.dart';
import 'webdav_vault_provider.dart';
import '../system/database_provider.dart';
import '../system/session_provider.dart';
import 'webdav_log_provider.dart';

export '../../application/sync/webdav_backup_service.dart'
    show
        WebDavBackupExportAction,
        WebDavBackupExportIssue,
        WebDavBackupExportIssueHandler,
        WebDavBackupExportIssueKind,
        WebDavBackupExportResolution;

final webDavBackupProgressTrackerProvider =
    ChangeNotifierProvider<WebDavBackupProgressTracker>((ref) {
      final tracker = WebDavBackupProgressTracker();
      ref.onDispose(tracker.dispose);
      return tracker;
    });

final webDavBackupStateRepositoryProvider =
    Provider<WebDavBackupStateRepository>((ref) {
      final accountKey = ref.watch(webDavAccountKeyProvider);
      return WebDavBackupStateRepository(
        ref.watch(secureStorageProvider),
        accountKey: accountKey,
      );
    });

final webDavBackupPasswordRepositoryProvider =
    Provider<WebDavBackupPasswordRepository>((ref) {
      final accountKey = ref.watch(webDavAccountKeyProvider);
      return WebDavBackupPasswordRepository(
        ref.watch(secureStorageProvider),
        accountKey: accountKey,
      );
    });

final webDavBackupServiceProvider = Provider<WebDavBackupService>((ref) {
  final container = ref.container;
  return WebDavBackupService(
    readDatabase: () => container.read(databaseProvider),
    attachmentStore: LocalAttachmentStore(),
    stateRepository: ref.watch(webDavBackupStateRepositoryProvider),
    passwordRepository: ref.watch(webDavBackupPasswordRepositoryProvider),
    vaultService: ref.watch(webDavVaultServiceProvider),
    vaultPasswordRepository: ref.watch(webDavVaultPasswordRepositoryProvider),
    configAdapter: RiverpodWebDavSyncLocalAdapter(container),
    progressTracker: ref.watch(webDavBackupProgressTrackerProvider),
    logWriter: (entry) =>
        unawaited(container.read(webDavLogStoreProvider).add(entry)),
  );
});
