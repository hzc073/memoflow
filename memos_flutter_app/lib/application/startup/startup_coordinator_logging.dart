part of 'startup_coordinator.dart';

extension _StartupCoordinatorLogging on StartupCoordinator {
  Map<String, Object?> _sharePayloadContext(SharePayload payload) {
    return <String, Object?>{
      'shareType': payload.type.name,
      'shareHandlingMode': payload.handlingMode.name,
      'sharePathsCount': payload.paths.length,
      'shareHasText': (payload.text ?? '').trim().isNotEmpty,
    };
  }

  Map<String, Object?> _buildStartupContext({
    String? phase,
    String? source,
    bool? prefsLoaded,
    bool? hasWorkspace,
    bool? hasAccount,
    ResolvedAppSettings? settings,
    _StartupAction? action,
    String? reason,
    int? retryCount,
    Map<String, Object?>? extra,
  }) {
    final context = <String, Object?>{
      if (phase != null) 'phase': phase,
      if (source != null) 'source': source,
      if (prefsLoaded != null) 'prefsLoaded': prefsLoaded,
      if (hasWorkspace != null) 'hasWorkspace': hasWorkspace,
      if (hasAccount != null) 'hasAccount': hasAccount,
      'pendingShare': _pendingSharePayload != null,
      'pendingWidget': _pendingWidgetLaunch != null,
      if (settings != null) 'launchAction': settings.device.launchAction.name,
      if (action != null) 'action': action.name,
      if (reason != null) 'reason': reason,
      if (retryCount != null) 'retryCount': retryCount,
      if (_activeDesktopShareTasks.isNotEmpty)
        'activeDesktopShareTasks': _activeDesktopShareTasks.length,
      ...?extra,
    };
    return context;
  }

  void _logStartupInfo(
    String event, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final snapshot = '$event|${context ?? const <String, Object?>{}}';
    if (_startupLogKey == snapshot) return;
    _startupLogKey = snapshot;
    LogManager.instance.info(
      event,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logStartupDebug(String event, {Map<String, Object?>? context}) {
    final snapshot = '$event|${context ?? const <String, Object?>{}}';
    if (_startupDebugKey == snapshot) return;
    _startupDebugKey = snapshot;
    LogManager.instance.debug(event, context: context);
  }
}
