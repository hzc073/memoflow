import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync/webdav_backup_service.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/settings/webdav_backup_password_repository.dart';
import '../data/settings/webdav_backup_state_repository.dart';
import 'database_provider.dart';
import 'session_provider.dart';
import 'webdav_log_provider.dart';

export '../application/sync/webdav_backup_service.dart'
    show
        WebDavBackupExportAction,
        WebDavBackupExportIssue,
        WebDavBackupExportIssueHandler,
        WebDavBackupExportIssueKind,
        WebDavBackupExportResolution;

final webDavBackupStateRepositoryProvider =
    Provider<WebDavBackupStateRepository>((ref) {
      final accountKey = ref.watch(
        appSessionProvider.select((state) => state.valueOrNull?.currentKey),
      );
      return WebDavBackupStateRepository(
        ref.watch(secureStorageProvider),
        accountKey: accountKey,
      );
    });

final webDavBackupPasswordRepositoryProvider =
    Provider<WebDavBackupPasswordRepository>((ref) {
      final accountKey = ref.watch(
        appSessionProvider.select((state) => state.valueOrNull?.currentKey),
      );
      return WebDavBackupPasswordRepository(
        ref.watch(secureStorageProvider),
        accountKey: accountKey,
      );
    });

final webDavBackupServiceProvider = Provider<WebDavBackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return WebDavBackupService(
    db: db,
    attachmentStore: LocalAttachmentStore(),
    stateRepository: ref.watch(webDavBackupStateRepositoryProvider),
    passwordRepository: ref.watch(webDavBackupPasswordRepositoryProvider),
    logWriter: (entry) =>
        unawaited(ref.read(webDavLogStoreProvider).add(entry)),
  );
});
