import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/logs/log_manager.dart';
import '../../data/models/workspace_preferences.dart';
import '../../state/memos/app_sync_adapter_provider.dart';
import '../sync/sync_request.dart';

typedef StatsWidgetUpdater = Future<void> Function({required bool force});
typedef SyncFeedbackToast = void Function({required bool succeeded});
typedef SyncProgressToast = void Function();

class AppSyncOrchestrator {
  AppSyncOrchestrator({
    required WidgetRef ref,
    required StatsWidgetUpdater updateStatsWidgetIfNeeded,
    required SyncFeedbackToast showFeedbackToast,
    required SyncProgressToast showProgressToast,
  }) : _ref = ref,
       _updateStatsWidgetIfNeeded = updateStatsWidgetIfNeeded,
       _showFeedbackToast = showFeedbackToast,
       _showProgressToast = showProgressToast;

  final WidgetRef _ref;
  final StatsWidgetUpdater _updateStatsWidgetIfNeeded;
  final SyncFeedbackToast _showFeedbackToast;
  final SyncProgressToast _showProgressToast;

  DateTime? _lastResumeAutoSyncAt;
  bool _autoSyncRunning = false;

  static const Duration _resumeAutoSyncCooldown = Duration(seconds: 45);

  AppSyncAdapter get _adapter => _ref.read(appSyncAdapterProvider);

  void resetResumeCooldown() {
    _lastResumeAutoSyncAt = null;
  }

  Future<void> maybeSyncOnLaunch(WorkspacePreferences prefs) async {
    if (!prefs.autoSyncOnStartAndResume) {
      if (kDebugMode) {
        LogManager.instance.info(
          'AutoSync: skipped_on_launch_disabled',
          context: <String, Object?>{
            'trigger': 'launch',
            'workspaceMode': _resolveActiveWorkspaceMode(),
          },
        );
      }
      return;
    }
    if (!_hasActiveWorkspace()) {
      if (kDebugMode) {
        LogManager.instance.info(
          'AutoSync: skipped_on_launch_no_workspace',
          context: <String, Object?>{'trigger': 'launch'},
        );
      }
      return;
    }
    LogManager.instance.info(
      'AutoSync: request',
      context: <String, Object?>{
        'trigger': 'launch',
        'workspaceMode': _resolveActiveWorkspaceMode(),
        'forceWidgetUpdate': false,
      },
    );
    unawaited(
      _syncAndUpdateStatsWidget(
        forceWidgetUpdate: false,
        logReason: 'launch',
        requestReason: SyncRequestReason.launch,
        requestKind: SyncRequestKind.memos,
        showFeedbackToast: true,
      ),
    );
  }

  void triggerLifecycleSync({
    required bool isResume,
    bool refreshCurrentUserBeforeSync = true,
    bool showFeedbackToast = true,
  }) {
    if (!isResume) return;
    if (!_adapter.areStartupPreferencesLoaded()) {
      if (kDebugMode) {
        LogManager.instance.info(
          'AutoSync: lifecycle_skip_startup_not_ready',
          context: <String, Object?>{
            'trigger': 'resumed',
            'workspaceMode': _resolveActiveWorkspaceMode(),
          },
        );
      }
      return;
    }
    if (!_hasActiveWorkspace()) {
      if (kDebugMode) {
        LogManager.instance.info(
          'AutoSync: lifecycle_skip_no_workspace',
          context: <String, Object?>{'trigger': 'resumed'},
        );
      }
      return;
    }
    final prefs = _adapter.readWorkspacePreferences();
    if (!prefs.autoSyncOnStartAndResume) {
      if (kDebugMode) {
        LogManager.instance.info(
          'AutoSync: lifecycle_skip_disabled',
          context: <String, Object?>{
            'trigger': 'resumed',
            'workspaceMode': _resolveActiveWorkspaceMode(),
          },
        );
      }
      return;
    }

    final now = DateTime.now();
    final last = _lastResumeAutoSyncAt;
    if (last != null && now.difference(last) < _resumeAutoSyncCooldown) {
      if (kDebugMode) {
        LogManager.instance.info(
          'AutoSync: lifecycle_throttled',
          context: <String, Object?>{
            'trigger': 'resumed',
            'elapsedMs': now.difference(last).inMilliseconds,
            'cooldownMs': _resumeAutoSyncCooldown.inMilliseconds,
            'workspaceMode': _resolveActiveWorkspaceMode(),
          },
        );
      }
      return;
    }
    _lastResumeAutoSyncAt = now;

    LogManager.instance.info(
      'AutoSync: request',
      context: <String, Object?>{
        'trigger': 'resumed',
        'workspaceMode': _resolveActiveWorkspaceMode(),
        'forceWidgetUpdate': true,
        'refreshCurrentUserBeforeSync': refreshCurrentUserBeforeSync,
      },
    );
    unawaited(
      _syncAndUpdateStatsWidget(
        forceWidgetUpdate: true,
        logReason: 'lifecycle_resumed',
        requestReason: SyncRequestReason.resume,
        requestKind: SyncRequestKind.all,
        refreshCurrentUserBeforeSync: refreshCurrentUserBeforeSync,
        showFeedbackToast: showFeedbackToast,
      ),
    );
  }

  Future<void> _syncAndUpdateStatsWidget({
    required bool forceWidgetUpdate,
    required String logReason,
    required SyncRequestReason requestReason,
    required SyncRequestKind requestKind,
    bool refreshCurrentUserBeforeSync = false,
    bool showFeedbackToast = false,
  }) async {
    final startedAt = DateTime.now();
    if (_autoSyncRunning) {
      LogManager.instance.info(
        'AutoSync: skipped_running',
        context: <String, Object?>{
          'reason': logReason,
          'refreshCurrentUserBeforeSync': refreshCurrentUserBeforeSync,
        },
      );
      return;
    }
    var session = _adapter.readSession();
    var hasAccount = session?.currentAccount != null;
    var hasLocalLibrary = _adapter.hasLocalLibrary();
    var hasWorkspace = hasAccount || hasLocalLibrary;
    if (!hasWorkspace) {
      if (kDebugMode) {
        LogManager.instance.info(
          'AutoSync: skipped_no_workspace',
          context: <String, Object?>{'reason': logReason},
        );
      }
      return;
    }
    if (!_adapter.isSyncContextReady()) {
      LogManager.instance.info(
        'AutoSync: skipped_preconditions',
        context: <String, Object?>{
          'reason': logReason,
          'hasWorkspace': hasWorkspace,
          'hasAuthenticatedAccount': _adapter.hasAuthenticatedAccount(),
          'databaseContextReady': _adapter.isDatabaseContextReady(),
          'syncContextReady': _adapter.isSyncContextReady(),
        },
      );
      return;
    }

    LogManager.instance.info(
      'AutoSync: start',
      context: <String, Object?>{
        'reason': logReason,
        'workspaceMode': _resolveActiveWorkspaceMode(),
        'forceWidgetUpdate': forceWidgetUpdate,
        'refreshCurrentUserBeforeSync': refreshCurrentUserBeforeSync,
      },
    );

    _autoSyncRunning = true;
    var syncSucceeded = true;
    if (showFeedbackToast) {
      _showProgressToast();
    }
    try {
      try {
        if (refreshCurrentUserBeforeSync && hasAccount) {
          await _adapter.refreshCurrentUser();
          session = _adapter.readSession();
          hasAccount = session?.currentAccount != null;
          hasLocalLibrary = _adapter.hasLocalLibrary();
          hasWorkspace = hasAccount || hasLocalLibrary;
          if (!hasWorkspace) {
            LogManager.instance.info(
              'AutoSync: skipped_after_session_refresh_no_workspace',
              context: <String, Object?>{'reason': logReason},
            );
            return;
          }
          if (!_adapter.isSyncContextReady()) {
            LogManager.instance.info(
              'AutoSync: skipped_preconditions',
              context: <String, Object?>{
                'reason': logReason,
                'hasWorkspace': hasWorkspace,
                'hasAuthenticatedAccount': _adapter.hasAuthenticatedAccount(),
                'databaseContextReady': _adapter.isDatabaseContextReady(),
                'syncContextReady': _adapter.isSyncContextReady(),
                'afterRefresh': true,
              },
            );
            return;
          }
        }
        await _adapter.requestSync(
          SyncRequest(kind: requestKind, reason: requestReason),
        );
      } catch (error, stackTrace) {
        syncSucceeded = false;
        LogManager.instance.warn(
          'AutoSync: sync_failed',
          error: error,
          stackTrace: stackTrace,
          context: <String, Object?>{'reason': logReason},
        );
        // Ignore sync errors here; widget update can still proceed.
      }
      if (hasAccount) {
        await _updateStatsWidgetIfNeeded(force: forceWidgetUpdate);
      }
      LogManager.instance.info(
        'AutoSync: completed',
        context: <String, Object?>{
          'reason': logReason,
          'workspaceMode': _resolveActiveWorkspaceMode(),
          'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
          'syncSucceeded': syncSucceeded,
          'hasAccount': hasAccount,
          'hasLocalLibrary': hasLocalLibrary,
          'widgetUpdateAttempted': hasAccount,
          'forceWidgetUpdate': forceWidgetUpdate,
          'refreshCurrentUserBeforeSync': refreshCurrentUserBeforeSync,
        },
      );
      if (showFeedbackToast) {
        _showFeedbackToast(succeeded: syncSucceeded);
      }
    } finally {
      _autoSyncRunning = false;
    }
  }

  bool _hasActiveWorkspace() {
    final session = _adapter.readSession();
    final hasAccount = session?.currentAccount != null;
    final hasLocalLibrary = _adapter.hasLocalLibrary();
    return hasAccount || hasLocalLibrary;
  }

  String _resolveActiveWorkspaceMode() {
    final session = _adapter.readSession();
    final hasAccount = session?.currentAccount != null;
    final hasLocalLibrary = _adapter.hasLocalLibrary();
    if (hasAccount && hasLocalLibrary) return 'hybrid';
    if (hasAccount) return 'remote';
    if (hasLocalLibrary) return 'local';
    return 'none';
  }
}
