import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/logs/breadcrumb_store.dart';
import '../data/logs/log_manager.dart';
import '../data/logs/logger_service.dart';
import '../data/logs/log_report_generator.dart';
import '../data/logs/network_log_buffer.dart';
import '../data/logs/sync_queue_progress_tracker.dart';
import '../data/logs/sync_status_tracker.dart';
import 'database_provider.dart';
import 'session_provider.dart';

final breadcrumbStoreProvider = Provider<BreadcrumbStore>((ref) {
  return BreadcrumbStore();
});

final networkLogBufferProvider = Provider<NetworkLogBuffer>((ref) {
  return NetworkLogBuffer(maxEntries: 200);
});

final logManagerProvider = Provider<LogManager>((ref) {
  final manager = LogManager.instance;
  unawaited(manager.init());
  return manager;
});

final syncStatusTrackerProvider = Provider<SyncStatusTracker>((ref) {
  return SyncStatusTracker();
});

final syncQueueProgressTrackerProvider =
    ChangeNotifierProvider<SyncQueueProgressTracker>((ref) {
      final tracker = SyncQueueProgressTracker();
      ref.onDispose(tracker.dispose);
      return tracker;
    });

final loggerServiceProvider = Provider<LoggerService>((ref) {
  final service = LoggerService(
    breadcrumbStore: ref.read(breadcrumbStoreProvider),
    syncStatusTracker: ref.read(syncStatusTrackerProvider),
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

final logReportGeneratorProvider = Provider<LogReportGenerator>((ref) {
  final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
  return LogReportGenerator(
    db: ref.watch(databaseProvider),
    loggerService: ref.watch(loggerServiceProvider),
    breadcrumbStore: ref.watch(breadcrumbStoreProvider),
    networkLogBuffer: ref.watch(networkLogBufferProvider),
    syncStatusTracker: ref.watch(syncStatusTrackerProvider),
    currentAccount: account,
  );
});
