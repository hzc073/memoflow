import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/sync/local_library_scan_service.dart';
import '../data/local_library/local_attachment_store.dart';
import '../data/local_library/local_library_fs.dart';
import 'database_provider.dart';
import 'local_library_provider.dart';

final localLibraryScannerProvider = Provider<LocalLibraryScanService?>((ref) {
  final library = ref.watch(currentLocalLibraryProvider);
  if (library == null) return null;
  return LocalLibraryScanService(
    db: ref.watch(databaseProvider),
    fileSystem: LocalLibraryFileSystem(library),
    attachmentStore: LocalAttachmentStore(),
  );
});
