import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/attachments/attachment_preprocessor.dart';
import '../../application/attachments/queued_attachment_stager.dart';
import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_types.dart';
import '../../core/image_bed_url.dart';
import '../../core/memo_relations.dart';
import '../../core/tags.dart';
import '../../core/uid.dart';
import '../../data/api/memo_api_facade.dart';
import '../../data/api/memo_api_version.dart';
import '../../data/api/memos_api.dart';
import '../../data/api/image_bed_api.dart';
import '../../data/db/app_database.dart';
import '../../data/logs/log_manager.dart';
import '../../data/logs/sync_status_tracker.dart';
import '../../data/models/attachment.dart';
import '../../data/models/image_bed_settings.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/memo_location.dart';
import '../../data/models/memo_relation.dart';
import '../../data/repositories/image_bed_settings_repository.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../../data/local_library/local_library_fs.dart';
import '../../features/share/share_inline_image_content.dart';
import 'create_memo_outbox_payload.dart';
import 'create_memo_time_policy.dart';
import '../../data/logs/sync_queue_progress_tracker.dart';
import '../system/database_provider.dart';
import '../attachments/attachment_preprocessor_provider.dart';
import '../settings/image_bed_settings_provider.dart';
import '../system/local_library_provider.dart';
import '../sync/local_sync_controller.dart';
import '../system/logging_provider.dart';
import '../settings/memoflow_bridge_settings_provider.dart';
import '../system/network_log_provider.dart';
import '../system/session_provider.dart';
import '../sync/sync_controller_base.dart';

part 'memos_query_models.part.dart';
part 'memos_advanced_search.part.dart';
part 'memos_api_provider.part.dart';
part 'memos_search_providers.part.dart';
part 'memos_shortcut_filter_parser.part.dart';
part 'memos_relations_provider.part.dart';
part 'memos_tag_stats_provider.part.dart';
part 'memos_resources_provider.part.dart';
part 'memos_remote_sync_errors.part.dart';
part 'memos_remote_sync_state_sync.part.dart';
part 'memos_remote_sync_outbox.part.dart';
part 'memos_remote_sync_attachments.part.dart';
part 'memos_remote_sync_controller.part.dart';

final _currentLocalLibrarySyncIdentityProvider = Provider<String?>((ref) {
  final localLibrary = ref.watch(currentLocalLibraryProvider);
  if (localLibrary == null) return null;
  return [
    localLibrary.key,
    localLibrary.rootPath ?? '',
    localLibrary.treeUri ?? '',
  ].join('|');
});

final syncControllerProvider =
    StateNotifierProvider<SyncControllerBase, AsyncValue<void>>((ref) {
      final localLibraryIdentity = ref.watch(
        _currentLocalLibrarySyncIdentityProvider,
      );
      if (localLibraryIdentity != null) {
        final localLibrary = ref.read(currentLocalLibraryProvider);
        if (localLibrary == null) {
          throw StateError('Local library disappeared during sync setup');
        }
        return LocalSyncController(
          db: ref.watch(databaseProvider),
          fileSystem: LocalLibraryFileSystem(localLibrary),
          attachmentStore: LocalAttachmentStore(),
          bridgeSettingsRepository: ref.watch(
            memoFlowBridgeSettingsRepositoryProvider,
          ),
          syncStatusTracker: ref.read(syncStatusTrackerProvider),
          syncQueueProgressTracker: ref.read(syncQueueProgressTrackerProvider),
          attachmentPreprocessor: ref.watch(attachmentPreprocessorProvider),
        );
      }

      final authContext = ref.watch(
        appSessionProvider.select(_currentAccountAuthContext),
      );
      if (authContext == null) {
        throw StateError('Not authenticated');
      }
      return RemoteSyncController(
        db: ref.watch(databaseProvider),
        api: ref.watch(memosApiProvider),
        currentUserName: authContext.userName,
        syncStatusTracker: ref.read(syncStatusTrackerProvider),
        syncQueueProgressTracker: ref.read(syncQueueProgressTrackerProvider),
        imageBedRepository: ref.watch(imageBedSettingsRepositoryProvider),
        attachmentPreprocessor: ref.watch(attachmentPreprocessorProvider),
        onRelationsSynced: (memoUids) {
          for (final uid in memoUids) {
            final trimmed = uid.trim();
            if (trimmed.isEmpty) continue;
            ref.invalidate(memoRelationsProvider(trimmed));
          }
        },
      );
    });
