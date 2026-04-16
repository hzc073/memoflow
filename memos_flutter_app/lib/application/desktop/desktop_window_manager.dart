import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop_db_write_channel.dart';
import '../../core/desktop_quick_input_channel.dart';
import '../../core/desktop_sync_channel.dart';
import '../../application/sync/desktop_remote_sync_facade.dart';
import '../../application/sync/sync_coordinator.dart';
import '../../data/db/db_write_protocol.dart';
import 'desktop_workspace_snapshot.dart';
import 'desktop_settings_window.dart';
import '../../core/desktop/shortcuts.dart';
import 'desktop_tray_controller.dart';
import 'desktop_exit_coordinator.dart';
import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../application/sync/webdav_backup_service.dart';
import '../../data/logs/webdav_backup_progress_tracker.dart';
import '../../data/models/local_library.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_settings.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../state/review/ai_analysis_provider.dart';
import '../../state/settings/ai_settings_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/tags/tag_repository.dart';
import '../../state/webdav/webdav_backup_provider.dart';
import 'desktop_quick_input_controller.dart';

typedef DesktopQuickInputLauncher =
    Future<void> Function({required bool autoFocus});

class DesktopWindowManager {
  DesktopWindowManager({
    required AppBootstrapAdapter bootstrapAdapter,
    required WidgetRef ref,
    required GlobalKey<NavigatorState> navigatorKey,
    required DesktopQuickInputController quickInputController,
    required DesktopQuickInputLauncher openQuickInput,
    required bool Function() isMounted,
    required VoidCallback onVisibilityChanged,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _ref = ref,
       _navigatorKey = navigatorKey,
       _quickInputController = quickInputController,
       _openQuickInput = openQuickInput,
       _isMounted = isMounted,
       _onVisibilityChanged = onVisibilityChanged;

  final AppBootstrapAdapter _bootstrapAdapter;
  final WidgetRef _ref;
  final GlobalKey<NavigatorState> _navigatorKey;
  final DesktopQuickInputController _quickInputController;
  final DesktopQuickInputLauncher _openQuickInput;
  final bool Function() _isMounted;
  final VoidCallback _onVisibilityChanged;

  final Set<int> _desktopVisibleSubWindowIds = <int>{};
  bool _desktopSubWindowsPrewarmScheduled = false;
  bool _desktopSubWindowVisibilitySyncInProgress = false;
  bool _desktopSubWindowVisibilitySyncQueued = false;
  bool _desktopSubWindowVisibilitySyncScheduled = false;
  DateTime? _lastDesktopSubWindowVisibilitySyncAt;
  int? _desktopQuickInputWindowId;
  ProviderSubscription<SyncCoordinatorState>? _syncCoordinatorSub;
  WebDavBackupProgressTracker? _boundBackupProgressTracker;
  VoidCallback? _backupProgressListener;
  bool _syncBridgeBound = false;

  static const Duration _desktopSubWindowVisibilitySyncDebounce = Duration(
    milliseconds: 360,
  );

  void configureTrayActions() {
    if (!DesktopTrayController.instance.supported) return;
    DesktopTrayController.instance.configureActions(
      onOpenSettings: _handleOpenSettingsFromTray,
      onNewMemo: _handleCreateMemoFromTray,
      onExit: () => DesktopExitCoordinator.requestExit(reason: 'tray_exit'),
    );
  }

  void bindMethodHandler() {
    if (kIsWeb) return;
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
    _bindDesktopSyncBridge();
  }

  void unbindMethodHandler() {
    if (kIsWeb) return;
    DesktopMultiWindow.setMethodHandler(null);
    _unbindDesktopSyncBridge();
  }

  void updateQuickInputWindowId(int? windowId) {
    _desktopQuickInputWindowId = windowId;
  }

  bool get shouldBlurMainWindow {
    if (_desktopVisibleSubWindowIds.isEmpty || kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  void setSubWindowVisibility({required int windowId, required bool visible}) {
    if (windowId <= 0) return;
    final changed = visible
        ? _desktopVisibleSubWindowIds.add(windowId)
        : _desktopVisibleSubWindowIds.remove(windowId);
    if (!changed || !_isMounted()) return;
    _onVisibilityChanged();
  }

  void scheduleVisibilitySync({bool force = false}) {
    if (kIsWeb || _desktopVisibleSubWindowIds.isEmpty) return;
    if (!force) {
      final last = _lastDesktopSubWindowVisibilitySyncAt;
      if (last != null &&
          DateTime.now().difference(last) <
              _desktopSubWindowVisibilitySyncDebounce) {
        return;
      }
    }
    if (_desktopSubWindowVisibilitySyncScheduled) return;
    _desktopSubWindowVisibilitySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopSubWindowVisibilitySyncScheduled = false;
      unawaited(_syncDesktopSubWindowVisibility());
    });
  }

  Future<void> focusVisibleSubWindow() async {
    if (!shouldBlurMainWindow || _desktopVisibleSubWindowIds.isEmpty) {
      return;
    }
    final candidateIds = _desktopVisibleSubWindowIds.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    for (final id in candidateIds) {
      final focused = await _focusDesktopSubWindowById(id);
      if (focused) return;
      setSubWindowVisibility(windowId: id, visible: false);
    }
  }

  void schedulePrewarm() {
    if (!isDesktopShortcutEnabled() || _desktopSubWindowsPrewarmScheduled) {
      return;
    }
    _desktopSubWindowsPrewarmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prewarmDesktopSubWindows());
    });
  }

  @visibleForTesting
  Future<dynamic> handleMethodCallForTest(
    MethodCall call, {
    int fromWindowId = 0,
  }) {
    return _handleMethodCall(call, fromWindowId);
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int fromWindowId) async {
    if (!_isMounted()) return null;
    if (_isQuickInputMethod(call.method)) {
      return _quickInputController.handleMethodCall(call, fromWindowId);
    }
    switch (call.method) {
      case desktopSubWindowVisibilityMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final visible = _parseDesktopSubWindowVisibleFlag(
          map == null ? null : map['visible'],
        );
        setSubWindowVisibility(
          windowId: fromWindowId,
          visible: visible ?? true,
        );
        return true;
      case desktopDbWriteMethod:
        return _handleDesktopDbWrite(call.arguments);
      case desktopSyncRequestMethod:
        return _handleDesktopSyncRequest(call.arguments, fromWindowId);
      case desktopSyncStateSnapshotMethod:
        return _handleDesktopSyncStateSnapshot(call.arguments);
      case desktopSyncProgressSnapshotMethod:
        return desktopSyncRpcSuccess(
          _ref.read(webDavBackupProgressTrackerProvider).snapshot.toJson(),
        );
      case desktopSettingsReopenOnboardingMethod:
        try {
          await _bootstrapAdapter.reloadSessionFromStorage(_ref);
        } catch (_) {}
        try {
          await _bootstrapAdapter.reloadLocalLibrariesFromStorage(_ref);
        } catch (_) {}
        final session = _bootstrapAdapter.readSession(_ref);
        if (session?.currentAccount == null && session?.currentKey != null) {
          try {
            await _bootstrapAdapter.setCurrentSessionKey(_ref, null);
          } catch (_) {}
        }
        _bootstrapAdapter.setHasSelectedLanguage(_ref, false);
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil('/', (route) => false);
        }
        return true;
      case desktopMainReloadWorkspaceMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final hasKey = map != null && map.containsKey('currentKey');
        final rawKey = map == null ? null : map['currentKey'];
        final log = _bootstrapAdapter.readLogManager(_ref);
        String? desiredKey;
        var setKeyOk = true;
        var sessionReloadOk = true;
        var librariesReloadOk = true;
        var keyEmpty = false;
        var keyInvalidType = false;
        if (hasKey) {
          if (rawKey == null) {
            keyEmpty = true;
            desiredKey = null;
          } else if (rawKey is String) {
            final nextKey = rawKey.trim();
            keyEmpty = nextKey.isEmpty;
            desiredKey = nextKey.isEmpty ? null : nextKey;
          } else {
            keyInvalidType = true;
            setKeyOk = false;
            log.warn(
              'Desktop workspace reload ignored non-string currentKey',
              context: <String, Object?>{'type': rawKey.runtimeType.toString()},
            );
          }
        }
        if (hasKey && !keyInvalidType) {
          try {
            await _bootstrapAdapter.reloadSessionFromStorage(_ref);
          } catch (error, stackTrace) {
            sessionReloadOk = false;
            log.error(
              'Desktop workspace reload failed to refresh session',
              error: error,
              stackTrace: stackTrace,
            );
          }
          final activeKey = _bootstrapAdapter
              .readSession(_ref)
              ?.currentKey
              ?.trim();
          final resolvedActiveKey = (activeKey == null || activeKey.isEmpty)
              ? null
              : activeKey;
          if (resolvedActiveKey != desiredKey) {
            try {
              await _bootstrapAdapter.setCurrentSessionKey(_ref, desiredKey);
            } catch (error, stackTrace) {
              setKeyOk = false;
              log.error(
                desiredKey == null
                    ? 'Desktop workspace reload failed to clear session key'
                    : 'Desktop workspace reload failed to set session key',
                error: error,
                stackTrace: stackTrace,
              );
            }
          }
        }
        try {
          await _bootstrapAdapter.reloadLocalLibrariesFromStorage(_ref);
        } catch (error, stackTrace) {
          librariesReloadOk = false;
          log.error(
            'Desktop workspace reload failed to refresh libraries',
            error: error,
            stackTrace: stackTrace,
          );
        }
        log.info(
          'Desktop workspace reload handled',
          context: <String, Object?>{
            'hasKey': hasKey,
            'keyEmpty': keyEmpty,
            'keyInvalidType': keyInvalidType,
            'sessionReloadOk': sessionReloadOk,
            'setKeyOk': setKeyOk,
            'reloadOk': librariesReloadOk,
          },
        );
        return librariesReloadOk && (!hasKey || (sessionReloadOk && setKeyOk));
      case desktopMainReloadAiSettingsMethod:
        final log = _bootstrapAdapter.readLogManager(_ref);
        try {
          if (!_isMounted()) return false;
          await _ref.read(aiSettingsProvider.notifier).reloadFromStorage();
          if (!_isMounted()) return false;
          log.info('Desktop AI settings reload handled');
          return true;
        } catch (error, stackTrace) {
          log.error(
            'Desktop AI settings reload failed',
            error: error,
            stackTrace: stackTrace,
          );
          return false;
        }
      case desktopMainReloadPreferencesMethod:
        final log = _bootstrapAdapter.readLogManager(_ref);
        try {
          await _ref
              .read(devicePreferencesProvider.notifier)
              .reloadFromStorage();
          await _ref
              .read(currentWorkspacePreferencesProvider.notifier)
              .reloadFromStorage();
          final quickInputWindowId = _desktopQuickInputWindowId;
          if (quickInputWindowId != null && quickInputWindowId > 0) {
            try {
              await DesktopMultiWindow.invokeMethod(
                quickInputWindowId,
                desktopMainReloadPreferencesMethod,
                null,
              );
            } catch (_) {}
          }
          log.info('Desktop preferences reload handled');
          return true;
        } catch (error, stackTrace) {
          log.error(
            'Desktop preferences reload failed',
            error: error,
            stackTrace: stackTrace,
          );
          return false;
        }
      case desktopHomeShowLoadingOverlayMethod:
        _bootstrapAdapter.forceHomeLoadingOverlay(_ref);
        return true;
      case desktopMainGetWorkspaceSnapshotMethod:
        final session = _bootstrapAdapter.readSession(_ref);
        final localLibrary = _bootstrapAdapter.readCurrentLocalLibrary(_ref);
        return DesktopWorkspaceSnapshot(
          currentKey: session?.currentKey,
          hasCurrentAccount: session?.currentAccount != null,
          hasLocalLibrary: localLibrary != null,
        ).toJson();
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> _handleDesktopDbWrite(dynamic arguments) async {
    try {
      if (arguments is! Map) {
        throw const FormatException('Invalid desktop db write payload.');
      }
      final envelope = DbWriteEnvelope.fromJson(
        Map<Object?, Object?>.from(arguments),
      );
      final session = _bootstrapAdapter.readSession(_ref);
      final currentKey = session?.currentKey?.trim() ?? '';
      if (currentKey.isEmpty) {
        return const DbWriteResult.failure(
          DbWriteError(
            code: 'workspace_unavailable',
            message: 'No active workspace is available for database writes.',
            retryable: true,
          ),
        ).toJson();
      }
      final expectedDbName = databaseNameForAccountKey(currentKey);
      if (currentKey != envelope.workspaceKey ||
          expectedDbName != envelope.dbName) {
        return const DbWriteResult.failure(
          DbWriteError(
            code: 'workspace_mismatch',
            message:
                'The main window workspace does not match the write request.',
            retryable: true,
          ),
        ).toJson();
      }

      final value = switch (envelope.commandType) {
        appDatabaseWriteCommandType =>
          await _ref
              .read(databaseProvider)
              .executeWriteEnvelopeLocally(envelope),
        tagRepositoryWriteCommandType =>
          await _ref
              .read(tagRepositoryProvider)
              .executeWriteEnvelopeLocally(envelope),
        aiAnalysisRepositoryWriteCommandType =>
          await _ref
              .read(aiAnalysisRepositoryProvider)
              .executeWriteEnvelopeLocally(envelope),
        _ => throw UnsupportedError(
          'Unsupported desktop db write command: ${envelope.commandType}',
        ),
      };
      return DbWriteResult.success(value).toJson();
    } catch (error) {
      final writeError = error is DbWriteException
          ? DbWriteError(
              code: error.code,
              message: error.message,
              retryable: error.retryable,
            )
          : DbWriteError(
              code: 'write_failed',
              message: error.toString(),
              retryable: true,
            );
      return DbWriteResult.failure(writeError).toJson();
    }
  }

  String _currentWorkspaceKey() {
    return _bootstrapAdapter.readSession(_ref)?.currentKey?.trim() ?? '';
  }

  Map<String, dynamic>? _validateDesktopSyncWorkspace(dynamic arguments) {
    final map = arguments is Map ? Map<Object?, Object?>.from(arguments) : null;
    final requestedWorkspace = (map?['workspaceKey'] as String? ?? '').trim();
    final currentWorkspace = _currentWorkspaceKey();
    if (requestedWorkspace.isNotEmpty &&
        currentWorkspace.isNotEmpty &&
        requestedWorkspace != currentWorkspace) {
      return desktopSyncRpcFailure(
        syncError: const SyncError(
          code: SyncErrorCode.invalidConfig,
          retryable: true,
          message: 'desktop_sync_workspace_mismatch',
        ),
      );
    }
    return null;
  }

  Map<String, dynamic> _handleDesktopSyncStateSnapshot(dynamic arguments) {
    final validationFailure = _validateDesktopSyncWorkspace(arguments);
    if (validationFailure != null) return validationFailure;
    return desktopSyncRpcSuccess(_ref.read(syncCoordinatorProvider).toJson());
  }

  Future<Map<String, dynamic>> _handleDesktopSyncRequest(
    dynamic arguments,
    int fromWindowId,
  ) async {
    try {
      final validationFailure = _validateDesktopSyncWorkspace(arguments);
      if (validationFailure != null) return validationFailure;
      if (arguments is! Map) {
        throw const FormatException('Invalid desktop sync request payload.');
      }
      final args = Map<Object?, Object?>.from(
        arguments,
      ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      final payload = args['payload'];
      final payloadMap = payload is Map
          ? Map<Object?, Object?>.from(payload).map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      final facade = _ref.read(syncCoordinatorProvider.notifier);
      final operation = args['operation'] as String? ?? '';
      final promptSessionId = _resolveDesktopSyncPromptSessionId(
        args,
        operation: operation,
        fromWindowId: fromWindowId,
      );
      final value = switch (operation) {
        'requestSync' => syncRunResultToJson(
          await facade.requestSync(
            SyncRequest.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['request'] as Map? ?? const <String, dynamic>{},
              ).map<String, dynamic>(
                (key, item) => MapEntry(key.toString(), item),
              ),
            ),
          ),
        ),
        'requestWebDavBackup' => syncRunResultToJson(
          await facade.requestWebDavBackup(
            reason: SyncRequestReason.values.firstWhere(
              (item) => item.name == (payloadMap['reason'] as String? ?? ''),
              orElse: () => SyncRequestReason.manual,
            ),
            password: payloadMap['password'] as String?,
            onExportIssue: fromWindowId <= 0
                ? null
                : (issue) => _promptDesktopBackupExportIssue(
                    windowId: fromWindowId,
                    sessionId: promptSessionId,
                    issue: issue,
                  ),
          ),
        ),
        'fetchWebDavSyncMeta' => (await facade.fetchWebDavSyncMeta())?.toJson(),
        'cleanWebDavDeprecatedPlainFiles' =>
          (await facade.cleanWebDavDeprecatedPlainFiles())?.toJson(),
        'testWebDavConnection' => (await facade.testWebDavConnection(
          settings: WebDavSettings.fromJson(
            Map<Object?, Object?>.from(
              payloadMap['settings'] as Map? ?? const <String, dynamic>{},
            ).map<String, dynamic>(
              (key, item) => MapEntry(key.toString(), item),
            ),
          ),
        )).toJson(),
        'verifyWebDavBackup' => (await facade.verifyWebDavBackup(
          password: payloadMap['password'] as String? ?? '',
          deep: payloadMap['deep'] == true,
        ))?.toJson(),
        'fetchWebDavExportStatus' =>
          (await facade.fetchWebDavExportStatus()).toJson(),
        'cleanWebDavPlainExport' =>
          (await facade.cleanWebDavPlainExport()).name,
        'listWebDavBackupSnapshots' => (await facade.listWebDavBackupSnapshots(
          settings: WebDavSettings.fromJson(
            Map<Object?, Object?>.from(
              payloadMap['settings'] as Map? ?? const <String, dynamic>{},
            ).map<String, dynamic>(
              (key, item) => MapEntry(key.toString(), item),
            ),
          ),
          accountKey: payloadMap['accountKey'] as String?,
          password: payloadMap['password'] as String? ?? '',
        )).map((item) => item.toJson()).toList(growable: false),
        'recoverWebDavBackupPassword' =>
          await facade.recoverWebDavBackupPassword(
            settings: WebDavSettings.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['settings'] as Map? ?? const <String, dynamic>{},
              ).map<String, dynamic>(
                (key, item) => MapEntry(key.toString(), item),
              ),
            ),
            accountKey: payloadMap['accountKey'] as String?,
            recoveryCode: payloadMap['recoveryCode'] as String? ?? '',
            newPassword: payloadMap['newPassword'] as String? ?? '',
          ),
        'restoreWebDavPlainBackup' => webDavRestoreResultToJson(
          await facade.restoreWebDavPlainBackup(
            settings: WebDavSettings.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['settings'] as Map? ?? const <String, dynamic>{},
              ).map<String, dynamic>(
                (key, item) => MapEntry(key.toString(), item),
              ),
            ),
            accountKey: payloadMap['accountKey'] as String?,
            activeLocalLibrary: payloadMap['activeLocalLibrary'] is Map
                ? LocalLibrary.fromJson(
                    Map<Object?, Object?>.from(
                      payloadMap['activeLocalLibrary'] as Map,
                    ).cast<String, dynamic>(),
                  )
                : null,
            conflictDecisions: (payloadMap['conflictDecisions'] as Map?)
                ?.map<String, bool>(
                  (key, value) => MapEntry(key.toString(), value == true),
                ),
            onConfigRestorePrompt: fromWindowId <= 0
                ? null
                : (candidates) => _promptDesktopBackupConfigRestore(
                    windowId: fromWindowId,
                    sessionId: promptSessionId,
                    candidates: candidates,
                  ),
          ),
        ),
        'restoreWebDavPlainBackupToDirectory' => webDavRestoreResultToJson(
          await facade.restoreWebDavPlainBackupToDirectory(
            settings: WebDavSettings.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['settings'] as Map? ?? const <String, dynamic>{},
              ).map<String, dynamic>(
                (key, item) => MapEntry(key.toString(), item),
              ),
            ),
            accountKey: payloadMap['accountKey'] as String?,
            exportLibrary: LocalLibrary.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['exportLibrary'] as Map? ??
                    const <String, dynamic>{},
              ).cast<String, dynamic>(),
            ),
            exportPrefix: payloadMap['exportPrefix'] as String? ?? '',
            onConfigRestorePrompt: fromWindowId <= 0
                ? null
                : (candidates) => _promptDesktopBackupConfigRestore(
                    windowId: fromWindowId,
                    sessionId: promptSessionId,
                    candidates: candidates,
                  ),
          ),
        ),
        'restoreWebDavSnapshot' => webDavRestoreResultToJson(
          await facade.restoreWebDavSnapshot(
            settings: WebDavSettings.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['settings'] as Map? ?? const <String, dynamic>{},
              ).map<String, dynamic>(
                (key, item) => MapEntry(key.toString(), item),
              ),
            ),
            accountKey: payloadMap['accountKey'] as String?,
            activeLocalLibrary: payloadMap['activeLocalLibrary'] is Map
                ? LocalLibrary.fromJson(
                    Map<Object?, Object?>.from(
                      payloadMap['activeLocalLibrary'] as Map,
                    ).cast<String, dynamic>(),
                  )
                : null,
            snapshot: WebDavBackupSnapshotInfo.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['snapshot'] as Map? ?? const <String, dynamic>{},
              ).cast<String, dynamic>(),
            ),
            password: payloadMap['password'] as String? ?? '',
            conflictDecisions: (payloadMap['conflictDecisions'] as Map?)
                ?.map<String, bool>(
                  (key, value) => MapEntry(key.toString(), value == true),
                ),
            onConfigRestorePrompt: fromWindowId <= 0
                ? null
                : (candidates) => _promptDesktopBackupConfigRestore(
                    windowId: fromWindowId,
                    sessionId: promptSessionId,
                    candidates: candidates,
                  ),
          ),
        ),
        'restoreWebDavSnapshotToDirectory' => webDavRestoreResultToJson(
          await facade.restoreWebDavSnapshotToDirectory(
            settings: WebDavSettings.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['settings'] as Map? ?? const <String, dynamic>{},
              ).map<String, dynamic>(
                (key, item) => MapEntry(key.toString(), item),
              ),
            ),
            accountKey: payloadMap['accountKey'] as String?,
            snapshot: WebDavBackupSnapshotInfo.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['snapshot'] as Map? ?? const <String, dynamic>{},
              ).cast<String, dynamic>(),
            ),
            password: payloadMap['password'] as String? ?? '',
            exportLibrary: LocalLibrary.fromJson(
              Map<Object?, Object?>.from(
                payloadMap['exportLibrary'] as Map? ??
                    const <String, dynamic>{},
              ).cast<String, dynamic>(),
            ),
            exportPrefix: payloadMap['exportPrefix'] as String? ?? '',
            onConfigRestorePrompt: fromWindowId <= 0
                ? null
                : (candidates) => _promptDesktopBackupConfigRestore(
                    windowId: fromWindowId,
                    sessionId: promptSessionId,
                    candidates: candidates,
                  ),
          ),
        ),
        'resolveWebDavConflicts' => () async {
          await facade.resolveWebDavConflicts(
            (payloadMap['resolutions'] as Map? ?? const <String, dynamic>{})
                .map<String, bool>(
                  (key, value) => MapEntry(key.toString(), value == true),
                ),
          );
          return null;
        }(),
        'resolveLocalScanConflicts' => () async {
          await facade.resolveLocalScanConflicts(
            (payloadMap['resolutions'] as Map? ?? const <String, dynamic>{})
                .map<String, bool>(
                  (key, value) => MapEntry(key.toString(), value == true),
                ),
          );
          return null;
        }(),
        'retryPending' => () async {
          await facade.retryPending();
          return null;
        }(),
        'pauseBackupProgress' => () {
          _ref.read(webDavBackupProgressTrackerProvider).pauseIfRunning();
          return null;
        }(),
        'resumeBackupProgress' => () {
          _ref.read(webDavBackupProgressTrackerProvider).resume();
          return null;
        }(),
        _ => throw UnsupportedError(
          'Unsupported desktop sync operation: $operation',
        ),
      };
      return desktopSyncRpcSuccess(value);
    } catch (error) {
      final syncError = error is SyncError
          ? error
          : const SyncError(
              code: SyncErrorCode.invalidConfig,
              retryable: true,
              message: 'desktop_sync_request_failed',
            );
      return desktopSyncRpcFailure(syncError: syncError);
    }
  }

  String _resolveDesktopSyncPromptSessionId(
    Map<String, dynamic> args, {
    required String operation,
    required int fromWindowId,
  }) {
    final explicit = (args['sessionId'] as String? ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final requestId = (args['requestId'] as String? ?? '').trim();
    if (requestId.isNotEmpty) {
      return 'desktopSyncSession.$requestId';
    }
    return [
      'desktopSyncSession',
      fromWindowId.toString(),
      operation,
      DateTime.now().microsecondsSinceEpoch.toString(),
    ].join('.');
  }

  DesktopSyncPromptMetadata _createDesktopSyncPromptMetadata({
    required String sessionId,
    required String promptType,
  }) {
    return DesktopSyncPromptMetadata(
      requestId: [
        'desktopSyncPrompt',
        promptType,
        DateTime.now().microsecondsSinceEpoch.toString(),
      ].join('.'),
      sessionId: sessionId,
    );
  }

  Future<WebDavBackupExportResolution> _promptDesktopBackupExportIssue({
    required int windowId,
    required String sessionId,
    required WebDavBackupExportIssue issue,
  }) async {
    final metadata = _createDesktopSyncPromptMetadata(
      sessionId: sessionId,
      promptType: 'backupExportIssue',
    );
    try {
      final raw = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSyncPromptBackupExportIssueMethod,
        <String, dynamic>{
          'workspaceKey': _currentWorkspaceKey(),
          ...metadata.toJson(),
          'issue': serializeWebDavBackupExportIssue(issue),
        },
      );
      return deserializeWebDavBackupExportPromptResponse(
        raw,
        expectedMetadata: metadata,
      );
    } catch (_) {}
    return const WebDavBackupExportResolution(
      action: WebDavBackupExportAction.abort,
    );
  }

  Future<Set<WebDavBackupConfigType>> _promptDesktopBackupConfigRestore({
    required int windowId,
    required String sessionId,
    required Set<WebDavBackupConfigType> candidates,
  }) async {
    final metadata = _createDesktopSyncPromptMetadata(
      sessionId: sessionId,
      promptType: 'backupConfigRestore',
    );
    try {
      final raw = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSyncPromptBackupConfigRestoreMethod,
        <String, dynamic>{
          'workspaceKey': _currentWorkspaceKey(),
          ...metadata.toJson(),
          'configTypes': serializeWebDavBackupConfigTypes(candidates),
        },
      );
      return deserializeWebDavBackupConfigPromptResponse(
        raw,
        expectedMetadata: metadata,
      );
    } catch (_) {}
    return const <WebDavBackupConfigType>{};
  }

  void _bindDesktopSyncBridge() {
    if (_syncBridgeBound || kIsWeb) return;
    _syncBridgeBound = true;
    _syncCoordinatorSub = _ref.listenManual<SyncCoordinatorState>(
      syncCoordinatorProvider,
      (previous, next) {
        unawaited(_broadcastDesktopSyncState(next));
      },
    );
    _boundBackupProgressTracker = _ref.read(
      webDavBackupProgressTrackerProvider,
    );
    _backupProgressListener = () {
      final tracker = _boundBackupProgressTracker;
      if (tracker == null) return;
      unawaited(_broadcastDesktopSyncProgress(tracker.snapshot));
    };
    _boundBackupProgressTracker?.addListener(_backupProgressListener!);
    unawaited(_broadcastDesktopSyncState(_ref.read(syncCoordinatorProvider)));
    unawaited(
      _broadcastDesktopSyncProgress(
        _ref.read(webDavBackupProgressTrackerProvider).snapshot,
      ),
    );
  }

  void _unbindDesktopSyncBridge() {
    _syncBridgeBound = false;
    _syncCoordinatorSub?.close();
    _syncCoordinatorSub = null;
    final listener = _backupProgressListener;
    if (listener != null) {
      _boundBackupProgressTracker?.removeListener(listener);
    }
    _backupProgressListener = null;
    _boundBackupProgressTracker = null;
  }

  Future<void> _broadcastDesktopSyncState(SyncCoordinatorState state) async {
    if (kIsWeb) return;
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      final payload = <String, dynamic>{
        'workspaceKey': _currentWorkspaceKey(),
        'state': state.toJson(),
      };
      for (final id in ids) {
        try {
          await DesktopMultiWindow.invokeMethod(
            id,
            desktopSyncStateChangedMethod,
            payload,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _broadcastDesktopSyncProgress(
    WebDavBackupProgressSnapshot snapshot,
  ) async {
    if (kIsWeb) return;
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      final payload = <String, dynamic>{
        'workspaceKey': _currentWorkspaceKey(),
        'progress': snapshot.toJson(),
      };
      for (final id in ids) {
        try {
          await DesktopMultiWindow.invokeMethod(
            id,
            desktopSyncProgressChangedMethod,
            payload,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  bool _isQuickInputMethod(String method) {
    return method == desktopQuickInputSubmitMethod ||
        method == desktopQuickInputPlaceholderMethod ||
        method == desktopQuickInputPickLinkMemoMethod ||
        method == desktopQuickInputListTagsMethod ||
        method == desktopQuickInputPingMethod ||
        method == desktopQuickInputClosedMethod;
  }

  bool? _parseDesktopSubWindowVisibleFlag(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  Future<void> _syncDesktopSubWindowVisibility() async {
    if (kIsWeb || _desktopVisibleSubWindowIds.isEmpty) return;
    if (_desktopSubWindowVisibilitySyncInProgress) {
      _desktopSubWindowVisibilitySyncQueued = true;
      return;
    }
    _desktopSubWindowVisibilitySyncInProgress = true;
    _lastDesktopSubWindowVisibilitySyncAt = DateTime.now();
    try {
      final trackedIds = _desktopVisibleSubWindowIds.toSet();
      final nextVisibleIds = <int>{};
      Set<int>? existingIds;
      try {
        existingIds = (await DesktopMultiWindow.getAllSubWindowIds())
            .where((id) => id > 0)
            .toSet();
      } catch (_) {}

      for (final id in trackedIds) {
        if (existingIds != null && !existingIds.contains(id)) {
          continue;
        }
        final visible = await _queryDesktopSubWindowVisible(id);
        if (visible == true) {
          nextVisibleIds.add(id);
          continue;
        }
        if (visible == null && await _isDesktopSubWindowResponsive(id)) {
          nextVisibleIds.add(id);
        }
      }

      if (!_isMounted() ||
          setEquals(nextVisibleIds, _desktopVisibleSubWindowIds)) {
        return;
      }
      _desktopVisibleSubWindowIds
        ..clear()
        ..addAll(nextVisibleIds);
      _onVisibilityChanged();
    } finally {
      _desktopSubWindowVisibilitySyncInProgress = false;
      if (_desktopSubWindowVisibilitySyncQueued) {
        _desktopSubWindowVisibilitySyncQueued = false;
        unawaited(_syncDesktopSubWindowVisibility());
      }
    }
  }

  Future<bool?> _queryDesktopSubWindowVisible(int windowId) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSubWindowIsVisibleMethod,
        null,
      );
      return _parseDesktopSubWindowVisibleFlag(result);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isDesktopSubWindowResponsive(int windowId) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsPingMethod,
        null,
      );
      if (result == null || result == true) {
        return true;
      }
    } catch (_) {}
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputPingMethod,
        null,
      );
      return result == null || result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _focusDesktopSubWindowById(int windowId) async {
    try {
      await WindowController.fromWindowId(windowId).show();
    } catch (_) {}

    if (_desktopQuickInputWindowId == windowId) {
      try {
        await DesktopMultiWindow.invokeMethod(
          windowId,
          desktopQuickInputFocusMethod,
          null,
        );
        return true;
      } catch (_) {}
      try {
        await DesktopMultiWindow.invokeMethod(
          windowId,
          desktopSettingsFocusMethod,
          null,
        );
        return true;
      } catch (_) {}
      return false;
    }

    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsFocusMethod,
        null,
      );
      return true;
    } catch (_) {}
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputFocusMethod,
        null,
      );
      return true;
    } catch (_) {}
    return false;
  }

  Future<void> _prewarmDesktopSubWindows() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!_isMounted() || !isDesktopShortcutEnabled()) return;
    bindMethodHandler();
    try {
      await _quickInputController.prewarm();
    } catch (error, stackTrace) {
      _bootstrapAdapter
          .readLogManager(_ref)
          .warn(
            'Desktop sub-window prewarm failed',
            error: error,
            stackTrace: stackTrace,
          );
    }
    prewarmDesktopSettingsWindowIfSupported();
  }

  Future<void> _handleOpenSettingsFromTray() async {
    if (!_isMounted()) return;
    final context = _resolveDesktopUiContext();
    openDesktopSettingsWindowIfSupported(feedbackContext: context);
  }

  Future<void> _handleCreateMemoFromTray() async {
    if (!_isMounted()) return;
    if (isDesktopShortcutEnabled()) {
      await _quickInputController.handleHotKey();
      return;
    }
    final autoFocus = _bootstrapAdapter
        .readDevicePreferences(_ref)
        .quickInputAutoFocus;
    unawaited(_openQuickInput(autoFocus: autoFocus));
  }

  BuildContext? _resolveDesktopUiContext() {
    final direct = _navigatorKey.currentContext;
    if (direct != null && direct.mounted) return direct;
    final overlay = _navigatorKey.currentState?.overlay?.context;
    if (overlay != null && overlay.mounted) return overlay;
    return null;
  }
}
