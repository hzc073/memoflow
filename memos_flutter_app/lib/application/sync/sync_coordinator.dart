import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/logs/debug_log_store.dart';
import '../../data/local_library/local_attachment_store.dart';
import '../../data/local_library/local_library_fs.dart';
import '../../data/models/webdav_export_status.dart';
import '../../data/models/webdav_sync_meta.dart';
import '../../data/models/webdav_settings.dart';
import 'local_library_scan_service.dart';
import 'sync_dependencies.dart';
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
  SyncCoordinator(this._deps)
    : _webDavSyncService = _deps.webDavSyncService,
      _webDavBackupService = _deps.webDavBackupService,
      super(SyncCoordinatorState.initial) {
    _loadBackupState();
  }

  final SyncDependencies _deps;
  final WebDavSyncService _webDavSyncService;
  final WebDavBackupService _webDavBackupService;
  void Function(DebugLogEntry entry)? get _logWriter => _deps.logWriter;

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
  static const SyncError _contextNotReadyError = SyncError(
    code: SyncErrorCode.invalidConfig,
    retryable: true,
    message: 'context_not_ready',
  );

  bool _updateStateIfMounted(
    SyncCoordinatorState Function(SyncCoordinatorState current) updater,
  ) {
    if (!mounted) return false;
    state = updater(state);
    return true;
  }

  Future<void> _loadBackupState() async {
    final snapshot = await _deps.webDavBackupStateRepository.read();
    if (!mounted) return;
    final parsed = _parseIso(snapshot.lastBackupAt);
    if (parsed == null) return;
    if (!mounted) return;
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

  bool _hasDatabaseContext() {
    try {
      _deps.readDatabase();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isContextReadyForKind(SyncRequestKind kind) {
    switch (kind) {
      case SyncRequestKind.memos:
        final account = _deps.readCurrentAccount();
        final localLibrary = _deps.readCurrentLocalLibrary();
        if (account == null && localLibrary == null) return false;
        return _hasDatabaseContext();
      case SyncRequestKind.webDavSync:
        return true;
      case SyncRequestKind.webDavBackup:
        final account = _deps.readCurrentAccount();
        final localLibrary = _deps.readCurrentLocalLibrary();
        if (account == null && localLibrary == null) return false;
        return _hasDatabaseContext();
      case SyncRequestKind.localScan:
        final localLibrary = _deps.readCurrentLocalLibrary();
        return localLibrary != null && _hasDatabaseContext();
      case SyncRequestKind.all:
        return _isContextReadyForKind(SyncRequestKind.memos);
    }
  }

  SyncRunSkipped _skipContextNotReady(SyncRequestKind kind) {
    switch (kind) {
      case SyncRequestKind.memos:
        _updateStateIfMounted(
          (current) => current.copyWith(
            memos: current.memos.copyWith(
              running: false,
              lastError: _contextNotReadyError,
            ),
          ),
        );
        break;
      case SyncRequestKind.webDavSync:
        _updateStateIfMounted(
          (current) => current.copyWith(
            webDavSync: current.webDavSync.copyWith(
              running: false,
              lastError: _contextNotReadyError,
              hasPendingConflict: false,
            ),
            pendingWebDavConflicts: const <String>[],
          ),
        );
        break;
      case SyncRequestKind.webDavBackup:
        _updateStateIfMounted(
          (current) => current.copyWith(
            webDavBackup: current.webDavBackup.copyWith(
              running: false,
              lastError: _contextNotReadyError,
            ),
          ),
        );
        break;
      case SyncRequestKind.localScan:
        _updateStateIfMounted(
          (current) => current.copyWith(
            localScan: current.localScan.copyWith(
              running: false,
              lastError: _contextNotReadyError,
              hasPendingConflict: false,
            ),
            pendingLocalScanConflicts: const <LocalScanConflict>[],
          ),
        );
        break;
      case SyncRequestKind.all:
        break;
    }
    return const SyncRunSkipped(reason: _contextNotReadyError);
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
    if (request.kind == SyncRequestKind.webDavSync ||
        request.kind == SyncRequestKind.webDavBackup) {
      _writeWebDavLog(
        'Request received',
        detail: 'kind=${request.kind.name} reason=${request.reason.name}',
      );
    }
    if (!_isContextReadyForKind(request.kind)) {
      if (request.kind == SyncRequestKind.webDavSync ||
          request.kind == SyncRequestKind.webDavBackup) {
        _writeWebDavLog(
          'Request skipped',
          detail:
              'kind=${request.kind.name} reason=${request.reason.name} context_not_ready',
        );
      }
      return _skipContextNotReady(request.kind);
    }
    if (request.kind == SyncRequestKind.webDavSync &&
        (request.reason == SyncRequestReason.settings ||
            request.reason == SyncRequestReason.auto)) {
      _writeWebDavLog(
        'Request scheduled',
        detail: 'kind=${request.kind.name} reason=${request.reason.name}',
      );
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
    if (request.kind == SyncRequestKind.webDavSync ||
        request.kind == SyncRequestKind.webDavBackup) {
      _writeWebDavLog(
        'Request queued',
        detail: 'kind=${request.kind.name} reason=${request.reason.name}',
      );
    }
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

  Future<WebDavSyncMeta?> fetchWebDavSyncMeta() async {
    final settings = _deps.readWebDavSettings();
    final accountKey = _deps.readCurrentAccountKey();
    return _webDavSyncService.fetchRemoteMeta(
      settings: settings,
      accountKey: accountKey,
    );
  }

  Future<WebDavSyncMeta?> cleanWebDavDeprecatedPlainFiles() async {
    final settings = _deps.readWebDavSettings();
    final accountKey = _deps.readCurrentAccountKey();
    return _webDavSyncService.cleanDeprecatedRemotePlainFiles(
      settings: settings,
      accountKey: accountKey,
    );
  }

  Future<WebDavConnectionTestResult> testWebDavConnection({
    required WebDavSettings settings,
  }) async {
    final accountKey = _deps.readCurrentAccountKey();
    return _webDavSyncService.testConnection(
      settings: settings,
      accountKey: accountKey,
    );
  }

  Future<SyncError?> verifyWebDavBackup({
    required String password,
    required bool deep,
  }) async {
    final settings = _deps.readWebDavSettings();
    final accountKey = _deps.readCurrentAccountKey();
    return _webDavBackupService.verifyBackup(
      settings: settings,
      accountKey: accountKey,
      password: password,
      deep: deep,
    );
  }

  Future<WebDavExportStatus> fetchWebDavExportStatus() async {
    final settings = _deps.readWebDavSettings();
    final accountKey = _deps.readCurrentAccountKey();
    final localLibrary = _deps.readCurrentLocalLibrary();
    return _webDavBackupService.fetchExportStatus(
      settings: settings,
      accountKey: accountKey,
      activeLocalLibrary: localLibrary,
    );
  }

  Future<WebDavExportCleanupStatus> cleanWebDavPlainExport() async {
    final settings = _deps.readWebDavSettings();
    final accountKey = _deps.readCurrentAccountKey();
    final localLibrary = _deps.readCurrentLocalLibrary();
    return _webDavBackupService.cleanPlainExport(
      settings: settings,
      accountKey: accountKey,
      activeLocalLibrary: localLibrary,
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
    final accountKey = _deps.readCurrentAccountKey();
    if (accountKey == null || accountKey.trim().isEmpty) return;
    final settings = _deps.readWebDavSettings();
    if (!settings.autoSyncAllowed) return;
    if (!_canSyncWebDav(settings)) return;
    _logSettingsTriggeredBackupDecision(settings);
    _webDavAutoTimer?.cancel();
    _webDavAutoTimer = Timer(_webDavAutoDelay, () {
      if (!mounted) return;
      _queueRequest(request);
      unawaited(_processQueue());
    });
  }

  void _logSettingsTriggeredBackupDecision(WebDavSettings settings) {
    final detailParts = <String>['settings_sync_only'];
    if (!settings.isBackupEnabled) {
      detailParts.add('backup_disabled');
    } else if (settings.backupSchedule == WebDavBackupSchedule.manual) {
      detailParts.add('schedule=manual');
    } else {
      detailParts.add('schedule=${settings.backupSchedule.name}');
    }
    if (settings.backupConfigScope == WebDavBackupConfigScope.none) {
      detailParts.add('config_disabled');
    }
    if (!settings.backupContentMemos) {
      detailParts.add('memos_disabled');
    }
    _writeWebDavLog('Backup not queued', detail: detailParts.join(' '));
  }

  void _writeWebDavLog(String label, {String? detail, Object? error}) {
    final writer = _logWriter;
    if (writer == null) return;
    writer(
      DebugLogEntry(
        timestamp: DateTime.now(),
        category: 'webdav',
        label: label,
        detail: detail,
        error: error?.toString(),
      ),
    );
  }

  Future<SyncRunResult> _processQueue() async {
    if (!mounted) {
      _pendingRequests.clear();
      return const SyncRunSkipped();
    }
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
      if (mounted && _pendingRequests.isNotEmpty) {
        unawaited(_processQueue());
      } else if (!mounted) {
        _pendingRequests.clear();
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
    if (!mounted) {
      return const SyncRunSkipped();
    }
    if (!_isContextReadyForKind(request.kind)) {
      return _skipContextNotReady(request.kind);
    }
    return switch (request.kind) {
      SyncRequestKind.memos => _runMemosSync(request),
      SyncRequestKind.webDavSync => _runWebDavSync(request),
      SyncRequestKind.webDavBackup => _runWebDavBackup(request),
      SyncRequestKind.localScan => _runLocalScan(request),
      SyncRequestKind.all => const SyncRunSkipped(),
    };
  }

  Future<SyncRunResult> _runMemosSync(SyncRequest request) async {
    final account = _deps.readCurrentAccount();
    final localLibrary = _deps.readCurrentLocalLibrary();
    final hasWorkspace = account != null || localLibrary != null;
    if (!hasWorkspace) {
      return const SyncRunSkipped();
    }
    _cancelMemosRetryTimer();
    if (!_updateStateIfMounted(
      (current) => current.copyWith(
        memos: current.memos.copyWith(running: true, lastError: null),
      ),
    )) {
      return const SyncRunSkipped();
    }
    final result = await _deps.runMemosSync();
    if (!mounted) {
      return const SyncRunSkipped();
    }
    final now = DateTime.now();
    if (result is MemoSyncSuccess) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          memos: current.memos.copyWith(
            running: false,
            lastSuccessAt: now,
            lastError: null,
          ),
        ),
      );
    } else if (result is MemoSyncFailure) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          memos: current.memos.copyWith(
            running: false,
            lastError: result.error,
          ),
        ),
      );
    } else if (result is MemoSyncSkipped) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          memos: current.memos.copyWith(
            running: false,
            lastError: result.reason,
          ),
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
    if (!_hasDatabaseContext()) {
      _resetMemosRetryState();
      return;
    }
    final db = _deps.readDatabase();
    final retryable = await db.countOutboxRetryable();
    if (!mounted) return;
    final hasPendingOutbox = retryable > 0;
    final syncFailed = result is MemoSyncFailure;
    if (!hasPendingOutbox && !syncFailed) {
      _resetMemosRetryState();
      return;
    }
    if (_memosRetryTimer?.isActive ?? false) return;
    final delay = _consumeMemosRetryDelay();
    _memosRetryTimer = Timer(delay, () {
      if (!mounted) return;
      _memosRetryTimer = null;
      _queueRequest(
        const SyncRequest(
          kind: SyncRequestKind.memos,
          reason: SyncRequestReason.auto,
        ),
      );
      unawaited(_processQueue());
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
    return _deps.readCurrentLocalLibrary() != null;
  }

  Future<SyncRunResult> _runWebDavSync(SyncRequest request) async {
    final settings = _deps.readWebDavSettings();
    final accountKey = _deps.readCurrentAccountKey();
    final conflictResolutions = _pendingWebDavConflictResolutions;
    _pendingWebDavConflictResolutions = null;

    if (!_updateStateIfMounted(
      (current) => current.copyWith(
        webDavSync: current.webDavSync.copyWith(
          running: true,
          lastError: null,
          hasPendingConflict: false,
        ),
        pendingWebDavConflicts: const <String>[],
      ),
    )) {
      return const SyncRunSkipped();
    }

    _writeWebDavLog(
      'Coordinator sync started',
      detail: 'reason=${request.reason.name}',
    );

    final result = await _webDavSyncService.syncNow(
      settings: settings,
      accountKey: accountKey,
      conflictResolutions: conflictResolutions,
    );
    if (!mounted) {
      return const SyncRunSkipped();
    }

    final now = DateTime.now();
    if (result is WebDavSyncSuccess) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavSync: current.webDavSync.copyWith(
            running: false,
            lastSuccessAt: now,
            lastError: null,
            hasPendingConflict: false,
          ),
          pendingWebDavConflicts: const <String>[],
        ),
      );
      _writeWebDavLog(
        'Coordinator sync completed',
        detail: 'reason=${request.reason.name}',
      );
      return const SyncRunStarted();
    }
    if (result is WebDavSyncSkipped) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavSync: current.webDavSync.copyWith(
            running: false,
            lastError: result.reason,
            hasPendingConflict: false,
          ),
          pendingWebDavConflicts: const <String>[],
        ),
      );
      _writeWebDavLog(
        'Coordinator sync skipped',
        detail: 'reason=${request.reason.name}',
        error: result.reason,
      );
      return SyncRunSkipped(reason: result.reason);
    }
    if (result is WebDavSyncFailure) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavSync: current.webDavSync.copyWith(
            running: false,
            lastError: result.error,
            hasPendingConflict: false,
          ),
          pendingWebDavConflicts: const <String>[],
        ),
      );
      _writeWebDavLog(
        'Coordinator sync failed',
        detail: 'reason=${request.reason.name}',
        error: result.error,
      );
      return SyncRunFailure(result.error);
    }
    if (result is WebDavSyncConflict) {
      final error = request.reason == SyncRequestReason.manual
          ? null
          : SyncError(
              code: SyncErrorCode.conflict,
              retryable: false,
              presentationKey: 'legacy.msg_conflicts_detected_run_manual_sync',
            );
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavSync: current.webDavSync.copyWith(
            running: false,
            lastError: error,
            hasPendingConflict: true,
          ),
          pendingWebDavConflicts: result.conflicts,
        ),
      );
      _writeWebDavLog(
        'Coordinator sync conflict',
        detail:
            'reason=${request.reason.name} conflicts=${result.conflicts.length}',
      );
      return SyncRunConflict(result.conflicts);
    }
    return const SyncRunStarted();
  }

  Future<SyncRunResult> _runWebDavBackup(SyncRequest request) async {
    final settings = _deps.readWebDavSettings();
    final account = _deps.readCurrentAccount();
    final accountKey = account?.key;
    final localLibrary = _deps.readCurrentLocalLibrary();
    final token = (account?.personalAccessToken ?? '').trim();
    final manual = request.reason == SyncRequestReason.manual;
    final resolvedPassword = manual ? _pendingWebDavBackupPassword : null;
    final resolvedIssueHandler = manual
        ? _pendingWebDavBackupIssueHandler
        : null;
    _pendingWebDavBackupPassword = null;
    _pendingWebDavBackupIssueHandler = null;

    if (!_updateStateIfMounted(
      (current) => current.copyWith(
        webDavBackup: current.webDavBackup.copyWith(
          running: true,
          lastError: null,
        ),
        webDavRestoring: false,
      ),
    )) {
      return const SyncRunSkipped();
    }

    _writeWebDavLog(
      'Coordinator backup started',
      detail: 'reason=${request.reason.name}',
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
    if (!mounted) {
      return const SyncRunSkipped();
    }

    final now = DateTime.now();
    if (result is WebDavBackupSuccess) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavBackup: current.webDavBackup.copyWith(
            running: false,
            lastSuccessAt: now,
            lastError: null,
          ),
          webDavLastBackupAt: now,
        ),
      );
      _writeWebDavLog(
        'Coordinator backup completed',
        detail: 'reason=${request.reason.name}',
      );
      return const SyncRunStarted();
    }
    if (result is WebDavBackupMissingPassword) {
      final error = SyncError(
        code: SyncErrorCode.invalidConfig,
        retryable: false,
        presentationKey: 'legacy.webdav.backup_password_missing',
      );
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavBackup: current.webDavBackup.copyWith(
            running: false,
            lastError: error,
          ),
        ),
      );
      _writeWebDavLog(
        'Coordinator backup missing password',
        detail: 'reason=${request.reason.name}',
        error: error,
      );
      return SyncRunFailure(error);
    }
    if (result is WebDavBackupSkipped) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavBackup: current.webDavBackup.copyWith(
            running: false,
            lastError: result.reason,
          ),
        ),
      );
      _writeWebDavLog(
        'Coordinator backup skipped',
        detail: 'reason=${request.reason.name}',
        error: result.reason,
      );
      return SyncRunSkipped(reason: result.reason);
    }
    if (result is WebDavBackupFailure) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          webDavBackup: current.webDavBackup.copyWith(
            running: false,
            lastError: result.error,
          ),
        ),
      );
      _writeWebDavLog(
        'Coordinator backup failed',
        detail: 'reason=${request.reason.name}',
        error: result.error,
      );
      return SyncRunFailure(result.error);
    }
    return const SyncRunStarted();
  }

  Future<SyncRunResult> _runLocalScan(SyncRequest request) async {
    final localLibrary = _deps.readCurrentLocalLibrary();
    if (localLibrary == null) {
      return const SyncRunSkipped();
    }
    final scanService = LocalLibraryScanService(
      db: _deps.readDatabase(),
      fileSystem: LocalLibraryFileSystem(localLibrary),
      attachmentStore: LocalAttachmentStore(),
    );
    final conflictResolutions = _pendingLocalScanResolutions;
    _pendingLocalScanResolutions = null;

    if (!_updateStateIfMounted(
      (current) => current.copyWith(
        localScan: current.localScan.copyWith(
          running: true,
          lastError: null,
          hasPendingConflict: false,
        ),
        pendingLocalScanConflicts: const <LocalScanConflict>[],
      ),
    )) {
      return const SyncRunSkipped();
    }

    final result = await scanService.scanAndMerge(
      forceDisk: request.reason != SyncRequestReason.auto,
      conflictDecisions: conflictResolutions,
    );
    if (!mounted) {
      return const SyncRunSkipped();
    }

    final now = DateTime.now();
    if (result is LocalScanSuccess) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          localScan: current.localScan.copyWith(
            running: false,
            lastSuccessAt: now,
            lastError: null,
            hasPendingConflict: false,
          ),
          pendingLocalScanConflicts: const <LocalScanConflict>[],
        ),
      );
      return const SyncRunStarted();
    }
    if (result is LocalScanConflictResult) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          localScan: current.localScan.copyWith(
            running: false,
            hasPendingConflict: true,
          ),
          pendingLocalScanConflicts: result.conflicts,
        ),
      );
      return const SyncRunQueued();
    }
    if (result is LocalScanFailure) {
      _updateStateIfMounted(
        (current) => current.copyWith(
          localScan: current.localScan.copyWith(
            running: false,
            lastError: result.error,
          ),
        ),
      );
      return SyncRunFailure(result.error);
    }
    return const SyncRunStarted();
  }

  void _queueBackupIfDue({required SyncRequestReason reason}) {
    final settings = _deps.readWebDavSettings();
    if (reason != SyncRequestReason.manual && !settings.autoSyncAllowed) {
      _writeWebDavLog(
        'Backup not queued',
        detail: 'auto_sync_disallowed reason=${reason.name}',
      );
      return;
    }
    if (!settings.isBackupEnabled) {
      _writeWebDavLog(
        'Backup not queued',
        detail: 'backup_disabled reason=${reason.name}',
      );
      return;
    }
    if (settings.backupSchedule == WebDavBackupSchedule.manual) {
      _writeWebDavLog(
        'Backup not queued',
        detail: 'schedule=manual reason=${reason.name}',
      );
      return;
    }
    if (settings.backupConfigScope == WebDavBackupConfigScope.none &&
        !settings.backupContentMemos) {
      _writeWebDavLog(
        'Backup not queued',
        detail: 'content_empty reason=${reason.name}',
      );
      return;
    }
    final lastAt = state.webDavLastBackupAt;
    if (!_isBackupDue(lastAt, settings.backupSchedule)) {
      _writeWebDavLog(
        'Backup not queued',
        detail:
            'not_due schedule=${settings.backupSchedule.name} reason=${reason.name}',
      );
      return;
    }
    _writeWebDavLog(
      'Backup queued',
      detail: 'schedule=${settings.backupSchedule.name} reason=${reason.name}',
    );
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
    if (settings.username.trim().isEmpty &&
        settings.password.trim().isNotEmpty) {
      return false;
    }
    if (settings.username.trim().isNotEmpty &&
        settings.password.trim().isEmpty) {
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
