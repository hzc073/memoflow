part of 'startup_coordinator.dart';

extension _StartupCoordinatorState on StartupCoordinator {
  _StartupSnapshot _readStartupSnapshot() {
    final prefsLoaded = _bootstrapAdapter.readDevicePreferencesLoaded(_ref);
    final settings = _bootstrapAdapter.readResolvedAppSettings(_ref);
    final session = _bootstrapAdapter.readSession(_ref);
    final hasAccount = session?.currentAccount != null;
    final hasWorkspace =
        hasAccount || _bootstrapAdapter.readCurrentLocalLibrary(_ref) != null;
    return _StartupSnapshot(
      prefsLoaded: prefsLoaded,
      settings: settings,
      hasAccount: hasAccount,
      hasWorkspace: hasWorkspace,
      navigatorReady: _navigatorKey.currentState != null,
      contextReady: _navigatorKey.currentContext != null,
    );
  }

  void _armStartupShareLaunchUi(SharePayload payload) {
    if (_startupHandled || !_shouldOpenSharePreviewDirectly(payload)) return;
    _setStartupSharePreviewPayload(payload);
    _setShareFlowActive(true);
  }

  void _armRuntimeShareLaunchUi(SharePayload payload) {
    if (!_startupHandled || !_shouldOpenSharePreviewDirectly(payload)) return;
    _setShareFlowActive(true);
  }

  void _setStartupSharePreviewPayload(SharePayload? payload) {
    if (identical(_startupSharePreviewPayload, payload)) return;
    _startupSharePreviewPayload = payload;
    _notifyCoordinatorListeners();
  }

  void _clearStartupShareLaunchUi() {
    _setStartupSharePreviewPayload(null);
  }

  void _setShareFlowActive(bool value) {
    if (_shareFlowActive == value) return;
    _shareFlowActive = value;
    _notifyCoordinatorListeners();
  }

  void _deferLaunchSync(WorkspacePreferences prefs) {
    _deferredLaunchSyncPreferences = prefs;
  }

  Future<void> _flushDeferredLaunchSyncIfNeeded() async {
    final prefs = _deferredLaunchSyncPreferences;
    if (prefs == null) return;
    _deferredLaunchSyncPreferences = null;
    _logStartupInfo(
      'Startup: autosync_resume_after_share',
      context: _buildStartupContext(
        phase: 'runtime',
        settings: _bootstrapAdapter.readResolvedAppSettings(_ref),
        action: _StartupAction.share,
      ),
    );
    await _syncOrchestrator.maybeSyncOnLaunch(prefs);
  }
}
