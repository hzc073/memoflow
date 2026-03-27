import '../../data/db/app_database.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/models/account.dart';
import '../../data/models/local_library.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/repositories/webdav_backup_state_repository.dart';
import 'sync_types.dart';
import 'webdav_backup_service.dart';
import 'webdav_sync_service.dart';

class SyncDependencies {
  const SyncDependencies({
    required this.webDavSyncService,
    required this.webDavBackupService,
    required this.webDavBackupStateRepository,
    required this.readWebDavSettings,
    required this.readCurrentAccountKey,
    required this.readCurrentAccount,
    required this.readCurrentLocalLibrary,
    required this.readDatabase,
    required this.runMemosSync,
    this.logWriter,
  });

  final WebDavSyncService webDavSyncService;
  final WebDavBackupService webDavBackupService;
  final WebDavBackupStateRepository webDavBackupStateRepository;
  final WebDavSettings Function() readWebDavSettings;
  final String? Function() readCurrentAccountKey;
  final Account? Function() readCurrentAccount;
  final LocalLibrary? Function() readCurrentLocalLibrary;
  final AppDatabase Function() readDatabase;
  final Future<MemoSyncResult> Function() runMemosSync;
  final void Function(DebugLogEntry entry)? logWriter;
}
