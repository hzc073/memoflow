import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../../data/local_library/local_library_fs.dart';
import '../../data/models/local_library.dart';
import '../../data/models/image_bed_settings.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_template_settings.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/logs/sync_queue_progress_tracker.dart';
import '../../data/logs/sync_status_tracker.dart';
import '../../data/settings/ai_settings_repository.dart';
import '../../state/ai_settings_provider.dart';
import '../../state/app_lock_provider.dart';
import '../../state/database_provider.dart';
import '../../state/image_bed_settings_provider.dart';
import '../../state/local_library_provider.dart';
import '../../state/location_settings_provider.dart';
import '../../state/memo_template_settings_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/note_draft_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/reminder_settings_provider.dart';
import '../../state/session_provider.dart';
import '../../state/webdav_backup_provider.dart' show webDavBackupPasswordRepositoryProvider, webDavBackupStateRepositoryProvider;
import '../../state/webdav_log_provider.dart';
import '../../state/webdav_settings_provider.dart';
import '../../state/webdav_sync_provider.dart' show webDavDeviceIdRepositoryProvider, webDavSyncStateRepositoryProvider;
import 'local_library_scan_service.dart';
import 'memo_sync_service.dart';
import 'sync_error.dart';
import 'sync_request.dart';
import 'sync_types.dart';
import 'webdav_backup_service.dart';
import 'webdav_sync_service.dart';

class SyncCoordinatorState {
  const SyncCoordinatorState({
    required this.memos,
    required this.webDavSync,
    required this.webDavBackup,
    required this.localScan,
    required this.webDavLastBackupAt,
    required this.webDavRestoring,
    required this.pendingWebDavConflicts,
    required this.pendingLocalScanConflicts,
  });

  final SyncFlowStatus memos;
  final SyncFlowStatus webDavSync;
  final SyncFlowStatus webDavBackup;
  final SyncFlowStatus localScan;
  final DateTime? webDavLastBackupAt;
  final bool webDavRestoring;
  final List<String> pendingWebDavConflicts;
  final List<LocalScanConflict> pendingLocalScanConflicts;

  SyncCoordinatorState copyWith({
    SyncFlowStatus? memos,
    SyncFlowStatus? webDavSync,
    SyncFlowStatus? webDavBackup,
    SyncFlowStatus? localScan,
    DateTime? webDavLastBackupAt,
    bool? webDavRestoring,
    List<String>? pendingWebDavConflicts,
    List<LocalScanConflict>? pendingLocalScanConflicts,
  }) {
    return SyncCoordinatorState(
      memos: memos ?? this.memos,
      webDavSync: webDavSync ?? this.webDavSync,
      webDavBackup: webDavBackup ?? this.webDavBackup,
      localScan: localScan ?? this.localScan,
      webDavLastBackupAt: webDavLastBackupAt ?? this.webDavLastBackupAt,
      webDavRestoring: webDavRestoring ?? this.webDavRestoring,
      pendingWebDavConflicts:
          pendingWebDavConflicts ?? this.pendingWebDavConflicts,
      pendingLocalScanConflicts:
          pendingLocalScanConflicts ?? this.pendingLocalScanConflicts,
    );
  }

  static const initial = SyncCoordinatorState(
    memos: SyncFlowStatus.idle,
    webDavSync: SyncFlowStatus.idle,
    webDavBackup: SyncFlowStatus.idle,
    localScan: SyncFlowStatus.idle,
    webDavLastBackupAt: null,
    webDavRestoring: false,
    pendingWebDavConflicts: <String>[],
    pendingLocalScanConflicts: <LocalScanConflict>[],
  );
}

class SyncCoordinator extends StateNotifier<SyncCoordinatorState> {
  SyncCoordinator(
    this._ref,
    this._webDavSyncService,
    this._webDavBackupService,
  ) : super(SyncCoordinatorState.initial) {
    _loadBackupState();
  }

  final Ref _ref;
  final WebDavSyncService _webDavSyncService;
  final WebDavBackupService _webDavBackupService;

  final Map<SyncRequestKind, SyncRequest> _pendingRequests = {};
  SyncRequestKind? _activeKind;
  Timer? _webDavAutoTimer;
  Timer? _memosRetryTimer;
  int _memosRetryBackoffIndex = 0;
  Map<String, bool>? _pendingWebDavConflictResolutions;
  Map<String, bool>? _pendingLocalScanResolutions;
  String? _pendingWebDavBackupPassword;
  WebDavBackupExportIssueHandler? _pendingWebDavBackupIssueHandler;

  static const Duration _webDavAutoDelay = Duration(seconds: 2);
  static const List<Duration> _localMemoRetryBackoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 40),
  ];
  static const List<Duration> _remoteMemoRetryBackoff = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 24),
    Duration(seconds: 45),
  ];

  Future<void> _loadBackupState() async {
    final snapshot = await _ref.read(webDavBackupStateRepositoryProvider).read();
    final parsed = _parseIso(snapshot.lastBackupAt);
    if (parsed == null) return;
    state = state.copyWith(webDavLastBackupAt: parsed);
  }

  int _reasonPriority(SyncRequestReason reason) {
    return switch (reason) {
      SyncRequestReason.manual => 0,
      SyncRequestReason.resume || SyncRequestReason.launch => 1,
      SyncRequestReason.settings => 2,
      SyncRequestReason.auto => 3,
    };
  }

  SyncRequest _mergeRequests(SyncRequest existing, SyncRequest incoming) {
    final existingPriority = _reasonPriority(existing.reason);
    final incomingPriority = _reasonPriority(incoming.reason);
    final reason = incomingPriority < existingPriority
        ? incoming.reason
        : existing.reason;
    return SyncRequest(
      kind: existing.kind,
      reason: reason,
      refreshCurrentUserBeforeSync:
          existing.refreshCurrentUserBeforeSync ||
          incoming.refreshCurrentUserBeforeSync,
      showFeedbackToast:
          existing.showFeedbackToast || incoming.showFeedbackToast,
      forceWidgetUpdate:
          existing.forceWidgetUpdate || incoming.forceWidgetUpdate,
    );
  }

  Future<SyncRunResult> requestSync(SyncRequest request) async {
    if (request.kind == SyncRequestKind.webDavSync &&
        (request.reason == SyncRequestReason.settings ||
            request.reason == SyncRequestReason.auto)) {
      _scheduleWebDavAuto(request);
      return const SyncRunQueued();
    }

    if (request.kind == SyncRequestKind.all) {
      _queueRequest(
        SyncRequest(
          kind: SyncRequestKind.memos,
          reason: request.reason,
          refreshCurrentUserBeforeSync: request.refreshCurrentUserBeforeSync,
          showFeedbackToast: request.showFeedbackToast,
          forceWidgetUpdate: request.forceWidgetUpdate,
        ),
      );
      _queueBackupIfDue(reason: request.reason);
      return _processQueue();
    }

    _queueRequest(request);
    return _processQueue();
  }

  Future<SyncRunResult> requestWebDavBackup({
    required SyncRequestReason reason,
    String? password,
    WebDavBackupExportIssueHandler? onExportIssue,
  }) {
    if (reason == SyncRequestReason.manual) {
      _pendingWebDavBackupPassword = password;
      _pendingWebDavBackupIssueHandler = onExportIssue;
    }
    return requestSync(
      SyncRequest(kind: SyncRequestKind.webDavBackup, reason: reason),
    );
  }

  Future<void> resolveWebDavConflicts(Map<String, bool> resolutions) async {
    _pendingWebDavConflictResolutions = resolutions;
    _queueRequest(
      const SyncRequest(
        kind: SyncRequestKind.webDavSync,
        reason: SyncRequestReason.manual,
      ),
    );
    await _processQueue();
  }

  Future<void> resolveLocalScanConflicts(Map<String, bool> resolutions) async {
    _pendingLocalScanResolutions = resolutions;
    _queueRequest(
      const SyncRequest(
        kind: SyncRequestKind.localScan,
        reason: SyncRequestReason.manual,
      ),
    );
    await _processQueue();
  }

  Future<void> retryPending() async {
    await _processQueue();
  }

  void _queueRequest(SyncRequest request) {
    final existing = _pendingRequests[request.kind];
    if (existing == null) {
      _pendingRequests[request.kind] = request;
    } else {
      _pendingRequests[request.kind] = _mergeRequests(existing, request);
    }
  }

  void _scheduleWebDavAuto(SyncRequest request) {
    final accountKey = _ref.read(appSessionProvider).valueOrNull?.currentKey;
    if (accountKey == null || accountKey.trim().isEmpty) return;
    final settings = _ref.read(webDavSettingsProvider);
    if (!_canSyncWebDav(settings)) return;
    _webDavAutoTimer?.cancel();
    _webDavAutoTimer = Timer(_webDavAutoDelay, () {
      _queueRequest(request);
      _processQueue();
    });
  }

  Future<SyncRunResult> _processQueue() async {
    if (_activeKind != null) {
      return const SyncRunQueued();
    }
    if (_pendingRequests.isEmpty) {
      return const SyncRunSkipped();
    }

    final next = _selectNextRequest();
    if (next == null) {
      return const SyncRunSkipped();
    }
    _activeKind = next.kind;
    try {
      return await _runRequest(next);
    } finally {
      _activeKind = null;
      // Schedule retry if queued during run.
      if (_pendingRequests.isNotEmpty) {
        unawaited(_processQueue());
      }
    }
  }

  SyncRequest? _selectNextRequest() {
    SyncRequest? best;
    int? bestPriority;
    for (final entry in _pendingRequests.entries) {
      final candidate = entry.value;
      final priority = _reasonPriority(candidate.reason);
      if (best == null) {
        best = candidate;
        bestPriority = priority;
        continue;
      }
      if (priority < (bestPriority ?? 0)) {
        best = candidate;
        bestPriority = priority;
        continue;
      }
      if (priority == bestPriority) {
        if (_kindPriority(candidate.kind) < _kindPriority(best.kind)) {
          best = candidate;
          bestPriority = priority;
        }
      }
    }
    if (best != null) {
      _pendingRequests.remove(best.kind);
    }
    return best;
  }

  int _kindPriority(SyncRequestKind kind) {
    return switch (kind) {
      SyncRequestKind.memos => 0,
      SyncRequestKind.webDavBackup => 1,
      SyncRequestKind.webDavSync => 2,
      SyncRequestKind.localScan => 3,
      SyncRequestKind.all => 4,
    };
  }

  Future<SyncRunResult> _runRequest(SyncRequest request) async {
    return switch (request.kind) {
      SyncRequestKind.memos => _runMemosSync(request),
      SyncRequestKind.webDavSync => _runWebDavSync(request),
      SyncRequestKind.webDavBackup => _runWebDavBackup(request),
      SyncRequestKind.localScan => _runLocalScan(request),
      SyncRequestKind.all => const SyncRunSkipped(),
    };
  }

  Future<SyncRunResult> _runMemosSync(SyncRequest request) async {
    final session = _ref.read(appSessionProvider).valueOrNull;
    final localLibrary = _ref.read(currentLocalLibraryProvider);
    final hasWorkspace = session?.currentAccount != null || localLibrary != null;
    if (!hasWorkspace) {
      return const SyncRunSkipped();
    }
    _cancelMemosRetryTimer();
    state = state.copyWith(
      memos: state.memos.copyWith(running: true, lastError: null),
    );
    final controller = _ref.read(syncControllerProvider.notifier);
    final result = await controller.syncNow();
    final now = DateTime.now();
    if (result is MemoSyncSuccess) {
      state = state.copyWith(
        memos: state.memos.copyWith(
          running: false,
          lastSuccessAt: now,
          lastError: null,
        ),
      );
    } else if (result is MemoSyncFailure) {
      state = state.copyWith(
        memos: state.memos.copyWith(
          running: false,
          lastError: result.error,
        ),
      );
    } else if (result is MemoSyncSkipped) {
      state = state.copyWith(
        memos: state.memos.copyWith(
          running: false,
          lastError: result.reason,
        ),
      );
    }

    await _scheduleMemosRetryIfNeeded(result);

    if (result is MemoSyncFailure) {
      return SyncRunFailure(result.error);
    }
    if (result is MemoSyncSkipped) {
      return SyncRunSkipped(reason: result.reason);
    }
    return const SyncRunStarted();
  }

  Future<void> _scheduleMemosRetryIfNeeded(MemoSyncResult result) async {
    final db = _ref.read(databaseProvider);
    final retryable = await db.countOutboxRetryable();
    final hasPendingOutbox = retryable > 0;
    final syncFailed = result is MemoSyncFailure;
    if (!hasPendingOutbox && !syncFailed) {
      _resetMemosRetryState();
      return;
    }
    if (_memosRetryTimer?.isActive ?? false) return;
    final delay = _consumeMemosRetryDelay();
    _memosRetryTimer = Timer(delay, () {
      _memosRetryTimer = null;
      _queueRequest(
        const SyncRequest(
          kind: SyncRequestKind.memos,
          reason: SyncRequestReason.auto,
        ),
      );
      _processQueue();
    });
  }

  Duration _consumeMemosRetryDelay() {
    final list = _isLocalWorkspace()
        ? _localMemoRetryBackoff
        : _remoteMemoRetryBackoff;
    if (list.isEmpty) {
      return const Duration(seconds: 5);
    }
    final index = _memosRetryBackoffIndex < 0
        ? 0
        : (_memosRetryBackoffIndex >= list.length
              ? list.length - 1
              : _memosRetryBackoffIndex);
    final delay = list[index];
    if (_memosRetryBackoffIndex < list.length - 1) {
      _memosRetryBackoffIndex++;
    }
    return delay;
  }

  void _resetMemosRetryState() {
    _cancelMemosRetryTimer();
    _memosRetryBackoffIndex = 0;
  }

  void _cancelMemosRetryTimer() {
    _memosRetryTimer?.cancel();
    _memosRetryTimer = null;
  }

  bool _isLocalWorkspace() {
    return _ref.read(currentLocalLibraryProvider) != null;
  }

  Future<SyncRunResult> _runWebDavSync(SyncRequest request) async {
    final settings = _ref.read(webDavSettingsProvider);
    final accountKey = _ref.read(appSessionProvider).valueOrNull?.currentKey;
    final conflictResolutions = _pendingWebDavConflictResolutions;
    _pendingWebDavConflictResolutions = null;

    state = state.copyWith(
      webDavSync: state.webDavSync.copyWith(
        running: true,
        lastError: null,
        hasPendingConflict: false,
      ),
      pendingWebDavConflicts: const <String>[],
    );

    final result = await _webDavSyncService.syncNow(
      settings: settings,
      accountKey: accountKey,
      conflictResolutions: conflictResolutions,
    );

    final now = DateTime.now();
    if (result is WebDavSyncSuccess) {
      state = state.copyWith(
        webDavSync: state.webDavSync.copyWith(
          running: false,
          lastSuccessAt: now,
          lastError: null,
          hasPendingConflict: false,
        ),
        pendingWebDavConflicts: const <String>[],
      );
      return const SyncRunStarted();
    }
    if (result is WebDavSyncSkipped) {
      state = state.copyWith(
        webDavSync: state.webDavSync.copyWith(
          running: false,
          lastError: result.reason,
          hasPendingConflict: false,
        ),
        pendingWebDavConflicts: const <String>[],
      );
      return SyncRunSkipped(reason: result.reason);
    }
    if (result is WebDavSyncFailure) {
      state = state.copyWith(
        webDavSync: state.webDavSync.copyWith(
          running: false,
          lastError: result.error,
          hasPendingConflict: false,
        ),
        pendingWebDavConflicts: const <String>[],
      );
      return SyncRunFailure(result.error);
    }
    if (result is WebDavSyncConflict) {
      final error = request.reason == SyncRequestReason.manual
          ? null
          : SyncError(
              code: SyncErrorCode.conflict,
              retryable: false,
              presentationKey:
                  'legacy.msg_conflicts_detected_run_manual_sync',
            );
      state = state.copyWith(
        webDavSync: state.webDavSync.copyWith(
          running: false,
          lastError: error,
          hasPendingConflict: true,
        ),
        pendingWebDavConflicts: result.conflicts,
      );
      return SyncRunConflict(result.conflicts);
    }
    return const SyncRunStarted();
  }

  Future<SyncRunResult> _runWebDavBackup(SyncRequest request) async {
    final settings = _ref.read(webDavSettingsProvider);
    final account = _ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final accountKey = account?.key;
    final localLibrary = _ref.read(currentLocalLibraryProvider);
    final token = (account?.personalAccessToken ?? '').trim();
    final manual = request.reason == SyncRequestReason.manual;
    final resolvedPassword = manual ? _pendingWebDavBackupPassword : null;
    final resolvedIssueHandler =
        manual ? _pendingWebDavBackupIssueHandler : null;
    _pendingWebDavBackupPassword = null;
    _pendingWebDavBackupIssueHandler = null;

    state = state.copyWith(
      webDavBackup: state.webDavBackup.copyWith(
        running: true,
        lastError: null,
      ),
      webDavRestoring: false,
    );

    final result = await _webDavBackupService.backupNow(
      settings: settings,
      accountKey: accountKey,
      activeLocalLibrary: localLibrary,
      password: resolvedPassword,
      manual: manual,
      attachmentBaseUrl: account?.baseUrl,
      attachmentAuthHeader: token.isEmpty ? null : 'Bearer $token',
      onExportIssue: resolvedIssueHandler,
    );

    final now = DateTime.now();
    if (result is WebDavBackupSuccess) {
      state = state.copyWith(
        webDavBackup: state.webDavBackup.copyWith(
          running: false,
          lastSuccessAt: now,
          lastError: null,
        ),
        webDavLastBackupAt: now,
      );
      return const SyncRunStarted();
    }
    if (result is WebDavBackupMissingPassword) {
      final error = SyncError(
        code: SyncErrorCode.invalidConfig,
        retryable: false,
        presentationKey: 'legacy.webdav.backup_password_missing',
      );
      state = state.copyWith(
        webDavBackup: state.webDavBackup.copyWith(
          running: false,
          lastError: error,
        ),
      );
      return SyncRunFailure(error);
    }
    if (result is WebDavBackupSkipped) {
      state = state.copyWith(
        webDavBackup: state.webDavBackup.copyWith(
          running: false,
          lastError: result.reason,
        ),
      );
      return SyncRunSkipped(reason: result.reason);
    }
    if (result is WebDavBackupFailure) {
      state = state.copyWith(
        webDavBackup: state.webDavBackup.copyWith(
          running: false,
          lastError: result.error,
        ),
      );
      return SyncRunFailure(result.error);
    }
    return const SyncRunStarted();
  }

  Future<SyncRunResult> _runLocalScan(SyncRequest request) async {
    final localLibrary = _ref.read(currentLocalLibraryProvider);
    if (localLibrary == null) {
      return const SyncRunSkipped();
    }
    final scanService = LocalLibraryScanService(
      db: _ref.read(databaseProvider),
      fileSystem: LocalLibraryFileSystem(localLibrary),
      attachmentStore: LocalAttachmentStore(),
    );
    final conflictResolutions = _pendingLocalScanResolutions;
    _pendingLocalScanResolutions = null;

    state = state.copyWith(
      localScan: state.localScan.copyWith(
        running: true,
        lastError: null,
        hasPendingConflict: false,
      ),
      pendingLocalScanConflicts: const <LocalScanConflict>[],
    );

    final result = await scanService.scanAndMerge(
      forceDisk: request.reason != SyncRequestReason.auto,
      conflictDecisions: conflictResolutions,
    );

    final now = DateTime.now();
    if (result is LocalScanSuccess) {
      state = state.copyWith(
        localScan: state.localScan.copyWith(
          running: false,
          lastSuccessAt: now,
          lastError: null,
          hasPendingConflict: false,
        ),
        pendingLocalScanConflicts: const <LocalScanConflict>[],
      );
      return const SyncRunStarted();
    }
    if (result is LocalScanConflictResult) {
      state = state.copyWith(
        localScan: state.localScan.copyWith(
          running: false,
          hasPendingConflict: true,
        ),
        pendingLocalScanConflicts: result.conflicts,
      );
      return const SyncRunQueued();
    }
    if (result is LocalScanFailure) {
      state = state.copyWith(
        localScan: state.localScan.copyWith(
          running: false,
          lastError: result.error,
        ),
      );
      return SyncRunFailure(result.error);
    }
    return const SyncRunStarted();
  }

  void _queueBackupIfDue({required SyncRequestReason reason}) {
    final settings = _ref.read(webDavSettingsProvider);
    if (!settings.isBackupEnabled) return;
    if (settings.backupSchedule == WebDavBackupSchedule.manual) return;
    if (!settings.backupContentConfig && !settings.backupContentMemos) return;
    final lastAt = state.webDavLastBackupAt;
    if (!_isBackupDue(lastAt, settings.backupSchedule)) return;
    _queueRequest(
      SyncRequest(kind: SyncRequestKind.webDavBackup, reason: reason),
    );
  }

  bool _isBackupDue(DateTime? last, WebDavBackupSchedule schedule) {
    if (schedule == WebDavBackupSchedule.manual) return false;
    if (schedule == WebDavBackupSchedule.onOpen) return true;
    if (last == null) return true;
    if (schedule == WebDavBackupSchedule.monthly) {
      final next = _addMonths(last, 1);
      final now = DateTime.now();
      return !now.isBefore(next);
    }
    final diff = DateTime.now().difference(last);
    return diff >= _scheduleDuration(schedule);
  }

  Duration _scheduleDuration(WebDavBackupSchedule schedule) {
    return switch (schedule) {
      WebDavBackupSchedule.daily => const Duration(days: 1),
      WebDavBackupSchedule.weekly => const Duration(days: 7),
      WebDavBackupSchedule.monthly => const Duration(days: 30),
      WebDavBackupSchedule.onOpen => Duration.zero,
      WebDavBackupSchedule.manual => Duration.zero,
    };
  }

  DateTime _addMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;
    return DateTime(
      year,
      month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  DateTime? _parseIso(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _canSyncWebDav(WebDavSettings settings) {
    if (!settings.enabled) return false;
    if (settings.serverUrl.trim().isEmpty) return false;
    if (settings.username.trim().isEmpty && settings.password.trim().isNotEmpty) {
      return false;
    }
    if (settings.username.trim().isNotEmpty && settings.password.trim().isEmpty) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _webDavAutoTimer?.cancel();
    _cancelMemosRetryTimer();
    super.dispose();
  }
}

class _RiverpodWebDavSyncLocalAdapter implements WebDavSyncLocalAdapter {
  _RiverpodWebDavSyncLocalAdapter(this._ref);

  final Ref _ref;

  @override
  Future<WebDavSyncLocalSnapshot> readSnapshot() async {
    final prefs = _ref.read(appPreferencesProvider);
    final ai = _ref.read(aiSettingsProvider);
    final reminder = _ref.read(reminderSettingsProvider);
    final imageBed = _ref.read(imageBedSettingsProvider);
    final location = _ref.read(locationSettingsProvider);
    final template = _ref.read(memoTemplateSettingsProvider);
    final lockRepo = _ref.read(appLockRepositoryProvider);
    final lockSnapshot = await lockRepo.readSnapshot();
    final draft = _ref.read(noteDraftProvider).valueOrNull ?? '';
    return WebDavSyncLocalSnapshot(
      preferences: prefs,
      aiSettings: ai,
      reminderSettings: reminder,
      imageBedSettings: imageBed,
      locationSettings: location,
      templateSettings: template,
      appLockSnapshot: lockSnapshot,
      noteDraft: draft,
    );
  }

  @override
  Future<void> applyPreferences(AppPreferences preferences) async {
    await _ref
        .read(appPreferencesProvider.notifier)
        .setAll(preferences, triggerSync: false);
  }

  @override
  Future<void> applyAiSettings(AiSettings settings) async {
    await _ref.read(aiSettingsProvider.notifier).setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyReminderSettings(ReminderSettings settings) async {
    await _ref
        .read(reminderSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyImageBedSettings(ImageBedSettings settings) async {
    await _ref
        .read(imageBedSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyLocationSettings(LocationSettings settings) async {
    await _ref
        .read(locationSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyTemplateSettings(MemoTemplateSettings settings) async {
    await _ref
        .read(memoTemplateSettingsProvider.notifier)
        .setAll(settings, triggerSync: false);
  }

  @override
  Future<void> applyAppLockSnapshot(AppLockSnapshot snapshot) async {
    await _ref
        .read(appLockProvider.notifier)
        .setSnapshot(snapshot, triggerSync: false);
  }

  @override
  Future<void> applyNoteDraft(String text) async {
    await _ref
        .read(noteDraftProvider.notifier)
        .setDraft(text, triggerSync: false);
  }
}

final syncCoordinatorProvider =
    StateNotifierProvider<SyncCoordinator, SyncCoordinatorState>((ref) {
      final db = ref.watch(databaseProvider);
      final attachmentStore = LocalAttachmentStore();
      final webDavSyncService = WebDavSyncService(
        syncStateRepository: ref.watch(webDavSyncStateRepositoryProvider),
        deviceIdRepository: ref.watch(webDavDeviceIdRepositoryProvider),
        localAdapter: _RiverpodWebDavSyncLocalAdapter(ref),
        logWriter: (entry) =>
            unawaited(ref.read(webDavLogStoreProvider).add(entry)),
      );
      final webDavBackupService = WebDavBackupService(
        db: db,
        attachmentStore: attachmentStore,
        stateRepository: ref.watch(webDavBackupStateRepositoryProvider),
        passwordRepository: ref.watch(webDavBackupPasswordRepositoryProvider),
        logWriter: (entry) =>
            unawaited(ref.read(webDavLogStoreProvider).add(entry)),
      );
      return SyncCoordinator(ref, webDavSyncService, webDavBackupService);
    });
