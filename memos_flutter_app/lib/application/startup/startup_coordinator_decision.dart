part of 'startup_coordinator.dart';

extension _StartupCoordinatorDecision on StartupCoordinator {
  void _requestStartupHandlingFromState({String? source}) {
    try {
      final snapshot = _readStartupSnapshot();
      _requestStartupHandling(
        prefsLoaded: snapshot.prefsLoaded,
        hasWorkspace: snapshot.hasWorkspace,
        hasAccount: snapshot.hasAccount,
        prefs: snapshot.prefs,
        source: source,
      );
    } catch (e, st) {
      _logStartupInfo(
        'Startup: state_read_failed',
        context: _buildStartupContext(
          source: source,
          reason: 'state_read_failed',
        ),
        error: e,
        stackTrace: st,
      );
      final action = _pendingSharePayload != null
          ? _StartupAction.share
          : (_pendingWidgetLaunch != null
                ? _StartupAction.widget
                : _StartupAction.none);
      if (action != _StartupAction.none) {
        _scheduleStartupRetry(action: action, reason: 'state_read_failed');
      }
    }
  }

  _StartupSelection _resolveStartupSelection(AppPreferences prefs) {
    return _StartupSelection(
      action: _selectStartupAction(prefs),
      reason: _selectStartupReason(prefs),
    );
  }

  _StartupAction _selectStartupAction(AppPreferences prefs) {
    return StartupCoordinator._startupActionFromName(
      StartupCoordinator.debugSelectStartupActionName(
        hasPendingShare: _pendingSharePayload != null,
        hasPendingWidget: _pendingWidgetLaunch != null,
        launchAction: prefs.launchAction,
      ),
    );
  }

  String _selectStartupReason(AppPreferences prefs) {
    return StartupCoordinator.debugSelectStartupReason(
      hasPendingShare: _pendingSharePayload != null,
      hasPendingWidget: _pendingWidgetLaunch != null,
      launchAction: prefs.launchAction,
    );
  }

  String? _evaluateShareBlockReason({
    required bool prefsLoaded,
    required bool hasAccount,
    required bool hasNavigator,
    required bool hasContext,
  }) {
    return StartupCoordinator.debugEvaluateShareBlockReason(
      prefsLoaded: prefsLoaded,
      hasAccount: hasAccount,
      hasNavigator: hasNavigator,
      hasContext: hasContext,
    );
  }

  String? _evaluateWidgetBlockReason({
    required bool hasWorkspace,
    required bool hasNavigator,
    required bool hasContext,
  }) {
    return StartupCoordinator.debugEvaluateWidgetBlockReason(
      hasWorkspace: hasWorkspace,
      hasNavigator: hasNavigator,
      hasContext: hasContext,
    );
  }

  bool _shouldRetryForReason(String reason) {
    return StartupCoordinator.debugShouldRetryForReason(reason);
  }

  _StartupBlockEvaluation _evaluateExecutionBlock({
    required _StartupAction action,
    required _StartupSnapshot snapshot,
  }) {
    final reason = switch (action) {
      _StartupAction.share =>
        _evaluateShareBlockReason(
              prefsLoaded: snapshot.prefsLoaded,
              hasAccount: snapshot.hasAccount,
              hasNavigator: snapshot.navigatorReady,
              hasContext: snapshot.contextReady,
            ) ??
            'unknown',
      _StartupAction.widget =>
        _evaluateWidgetBlockReason(
              hasWorkspace: snapshot.hasWorkspace,
              hasNavigator: snapshot.navigatorReady,
              hasContext: snapshot.contextReady,
            ) ??
            'unknown',
      _ => 'unknown',
    };
    return _StartupBlockEvaluation(
      reason: reason,
      shouldRetry: _shouldRetryForReason(reason),
    );
  }

  void _scheduleStartupRetry({
    required _StartupAction action,
    required String reason,
  }) {
    if (_startupHandled) return;
    final key =
        '${action.name}|$reason|${_pendingSharePayload != null}|${_pendingWidgetLaunch != null}';
    if (_startupRetryKey != key) {
      _startupRetryKey = key;
      _startupRetryCount = 0;
      _startupRetryScheduled = false;
    }
    if (_startupRetryCount >= 2 || _startupRetryScheduled) return;
    final delay = _startupRetryCount == 0
        ? Duration.zero
        : const Duration(milliseconds: 250);
    _startupRetryCount += 1;
    _startupRetryScheduled = true;
    _logStartupDebug(
      'Startup: retry_scheduled',
      context: _buildStartupContext(
        action: action,
        reason: reason,
        retryCount: _startupRetryCount,
        extra: {'delayMs': delay.inMilliseconds},
      ),
    );
    _logStartupInfo(
      'Startup: scheduled',
      context: _buildStartupContext(
        phase: 'startup',
        source: 'retry',
        action: action,
        reason: reason,
        retryCount: _startupRetryCount,
        extra: {'delayMs': delay.inMilliseconds},
      ),
    );

    void trigger() {
      _startupRetryScheduled = false;
      if (!_isMounted() || _startupHandled) return;
      _scheduleStartupHandling();
    }

    if (delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => trigger());
    } else {
      Future<void>.delayed(delay, trigger);
    }
  }

  void _requestStartupHandling({
    required bool prefsLoaded,
    required bool hasWorkspace,
    required bool hasAccount,
    required AppPreferences prefs,
    String? source,
    bool force = false,
  }) {
    if (_startupHandled) return;
    final selection = _resolveStartupSelection(prefs);
    final key =
        '$prefsLoaded|$hasWorkspace|$hasAccount|${_pendingSharePayload != null}|${_pendingWidgetLaunch != null}|${prefs.launchAction}|${selection.action}';
    if (!force) {
      if (_startupScheduleKey == key) return;
      _startupScheduleKey = key;
    }
    final baseContext = _buildStartupContext(
      phase: 'startup',
      source: source,
      prefsLoaded: prefsLoaded,
      hasWorkspace: hasWorkspace,
      hasAccount: hasAccount,
      prefs: prefs,
      action: selection.action,
      reason: selection.reason,
      retryCount: _startupRetryCount,
    );
    _logStartupInfo('Startup: request', context: baseContext);
    _logStartupDebug('Startup: request', context: baseContext);
    if (!prefsLoaded) {
      _logStartupInfo(
        'Startup: deferred',
        context: _buildStartupContext(
          phase: 'startup',
          source: source,
          prefsLoaded: prefsLoaded,
          hasWorkspace: hasWorkspace,
          hasAccount: hasAccount,
          prefs: prefs,
          action: selection.action,
          reason: 'prefs_not_loaded',
        ),
      );
      return;
    }
    if (!hasWorkspace) {
      _logStartupInfo(
        'Startup: deferred',
        context: _buildStartupContext(
          phase: 'startup',
          source: source,
          prefsLoaded: prefsLoaded,
          hasWorkspace: hasWorkspace,
          hasAccount: hasAccount,
          prefs: prefs,
          action: selection.action,
          reason: 'no_workspace',
        ),
      );
      return;
    }
    if (_scheduleStartupHandling()) {
      _logStartupInfo('Startup: scheduled', context: baseContext);
    }
  }

  bool _scheduleStartupHandling() {
    if (_startupHandled || _startupScheduled) return false;
    _startupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupScheduled = false;
      if (!_isMounted()) return;
      unawaited(_handleStartupActions());
    });
    return true;
  }

  void _handlePrefsLaunchAction(_StartupSnapshot snapshot) {
    switch (snapshot.prefs.launchAction) {
      case LaunchAction.dailyReview:
        _appNavigator.openDailyReview();
        break;
      case LaunchAction.explore:
        if (!snapshot.hasAccount) break;
        _appNavigator.openExplore();
        break;
      case LaunchAction.quickInput:
        unawaited(
          openQuickInput(
            autoFocus: AppPreferences.defaults.quickInputAutoFocus,
          ),
        );
        break;
      case LaunchAction.none:
      case LaunchAction.sync:
        break;
    }
  }

  _StartupExecutionResult _executeStartupAction({
    required _StartupSelection selection,
    required _StartupSnapshot snapshot,
  }) {
    switch (selection.action) {
      case _StartupAction.share:
        final handled = _handlePendingShare();
        if (handled) {
          _pendingWidgetLaunch = null;
        }
        return _StartupExecutionResult(
          handled: handled,
          blockReason: handled
              ? null
              : _evaluateShareBlockReason(
                  prefsLoaded: snapshot.prefsLoaded,
                  hasAccount: snapshot.hasAccount,
                  hasNavigator: snapshot.navigatorReady,
                  hasContext: snapshot.contextReady,
                ),
        );
      case _StartupAction.widget:
        final handled = _handlePendingWidgetAction();
        return _StartupExecutionResult(
          handled: handled,
          blockReason: handled
              ? null
              : _evaluateWidgetBlockReason(
                  hasWorkspace: snapshot.hasWorkspace,
                  hasNavigator: snapshot.navigatorReady,
                  hasContext: snapshot.contextReady,
                ),
        );
      case _StartupAction.launchAction:
        _handlePrefsLaunchAction(snapshot);
        return const _StartupExecutionResult(handled: true);
      case _StartupAction.none:
        return const _StartupExecutionResult(handled: true);
    }
  }

  Future<void> _handleStartupActions() async {
    if (_startupHandled || !_isMounted()) return;

    late final _StartupSnapshot snapshot;
    try {
      snapshot = _readStartupSnapshot();
    } catch (e, st) {
      _logStartupInfo(
        'Startup: state_read_failed',
        context: _buildStartupContext(
          phase: 'startup',
          reason: 'state_read_failed',
        ),
        error: e,
        stackTrace: st,
      );
      final action = _pendingSharePayload != null
          ? _StartupAction.share
          : (_pendingWidgetLaunch != null
                ? _StartupAction.widget
                : _StartupAction.none);
      if (action != _StartupAction.none) {
        _scheduleStartupRetry(action: action, reason: 'state_read_failed');
      }
      return;
    }

    final readinessReason = !snapshot.prefsLoaded
        ? 'prefs_not_loaded'
        : (!snapshot.hasWorkspace ? 'no_workspace' : null);
    if (readinessReason != null) {
      _logStartupInfo(
        'Startup: deferred',
        context: _buildStartupContext(
          phase: 'startup',
          prefsLoaded: snapshot.prefsLoaded,
          hasWorkspace: snapshot.hasWorkspace,
          hasAccount: snapshot.hasAccount,
          prefs: snapshot.prefs,
          reason: readinessReason,
        ),
      );
      return;
    }

    final selection = _resolveStartupSelection(snapshot.prefs);
    if (_lastStartupAction != null && _lastStartupAction != selection.action) {
      _logStartupDebug(
        'Startup: action_changed',
        context: _buildStartupContext(
          phase: 'startup',
          prefsLoaded: snapshot.prefsLoaded,
          hasWorkspace: snapshot.hasWorkspace,
          hasAccount: snapshot.hasAccount,
          prefs: snapshot.prefs,
          action: selection.action,
          reason: selection.reason,
          extra: {'previousAction': _lastStartupAction!.name},
        ),
      );
    }
    _lastStartupAction = selection.action;
    _logStartupInfo(
      'Startup: select_action',
      context: _buildStartupContext(
        phase: 'startup',
        prefsLoaded: snapshot.prefsLoaded,
        hasWorkspace: snapshot.hasWorkspace,
        hasAccount: snapshot.hasAccount,
        prefs: snapshot.prefs,
        action: selection.action,
        reason: selection.reason,
      ),
    );
    _logStartupDebug(
      'Startup: select_action',
      context: _buildStartupContext(
        phase: 'startup',
        prefsLoaded: snapshot.prefsLoaded,
        hasWorkspace: snapshot.hasWorkspace,
        hasAccount: snapshot.hasAccount,
        prefs: snapshot.prefs,
        action: selection.action,
        reason: selection.reason,
        retryCount: _startupRetryCount,
      ),
    );

    final execution = _executeStartupAction(
      selection: selection,
      snapshot: snapshot,
    );
    if (!execution.handled) {
      final block = _evaluateExecutionBlock(
        action: selection.action,
        snapshot: snapshot,
      );
      _logStartupInfo(
        'Startup: deferred',
        context: _buildStartupContext(
          phase: 'startup',
          prefsLoaded: snapshot.prefsLoaded,
          hasWorkspace: snapshot.hasWorkspace,
          hasAccount: snapshot.hasAccount,
          prefs: snapshot.prefs,
          action: selection.action,
          reason: execution.blockReason ?? block.reason,
        ),
      );
      _logStartupDebug(
        'Startup: deferred',
        context: _buildStartupContext(
          phase: 'startup',
          prefsLoaded: snapshot.prefsLoaded,
          hasWorkspace: snapshot.hasWorkspace,
          hasAccount: snapshot.hasAccount,
          prefs: snapshot.prefs,
          action: selection.action,
          reason: execution.blockReason ?? block.reason,
          retryCount: _startupRetryCount,
        ),
      );
      if (selection.action == _StartupAction.share &&
          block.reason == 'no_account') {
        _clearStartupShareLaunchUi();
        _setShareFlowActive(false);
      }
      if (block.shouldRetry) {
        _scheduleStartupRetry(action: selection.action, reason: block.reason);
      }
      return;
    }

    _startupHandled = true;
    _logStartupInfo(
      'Startup: handled',
      context: _buildStartupContext(
        phase: 'startup',
        prefsLoaded: snapshot.prefsLoaded,
        hasWorkspace: snapshot.hasWorkspace,
        hasAccount: snapshot.hasAccount,
        prefs: snapshot.prefs,
        action: selection.action,
      ),
    );
    _logStartupInfo(
      'Startup: autosync',
      context: _buildStartupContext(
        phase: 'startup',
        prefsLoaded: snapshot.prefsLoaded,
        hasWorkspace: snapshot.hasWorkspace,
        hasAccount: snapshot.hasAccount,
        prefs: snapshot.prefs,
        action: selection.action,
      ),
    );
    if (selection.action == _StartupAction.share && _shareFlowActive) {
      _logStartupInfo(
        'Startup: autosync_deferred_for_share',
        context: _buildStartupContext(
          phase: 'startup',
          prefsLoaded: snapshot.prefsLoaded,
          hasWorkspace: snapshot.hasWorkspace,
          hasAccount: snapshot.hasAccount,
          prefs: snapshot.prefs,
          action: selection.action,
        ),
      );
      _deferLaunchSync(snapshot.prefs);
      return;
    }
    await _syncOrchestrator.maybeSyncOnLaunch(snapshot.prefs);
  }
}
