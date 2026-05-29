part of 'startup_coordinator.dart';

extension _StartupCoordinatorShare on StartupCoordinator {
  Future<void> _loadPendingShare() async {
    final payload = await ShareHandlerService.consumePendingShare();
    if (!_isMounted() || payload == null) return;
    _pendingSharePayload = payload;
    _armStartupShareLaunchUi(payload);
    _armRuntimeShareLaunchUi(payload);
    if (_startupHandled) {
      _logStartupInfo(
        'Startup: runtime_share',
        context: _buildStartupContext(
          phase: 'runtime',
          source: 'pending',
          extra: _sharePayloadContext(payload),
        ),
      );
      _scheduleShareHandling();
      return;
    }
    _requestStartupHandlingFromState(source: 'pending');
  }

  void _scheduleShareHandling() {
    if (_shareHandlingScheduled) return;
    _shareHandlingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareHandlingScheduled = false;
      if (!_isMounted()) return;
      _handlePendingShare();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  bool _handlePendingShare() {
    final payload = _pendingSharePayload;
    if (payload == null) return false;
    if (!_bootstrapAdapter.readDevicePreferencesLoaded(_ref)) return false;
    final prefs = _bootstrapAdapter.readDevicePreferences(_ref);
    final session = _bootstrapAdapter.readSession(_ref);
    final localLibrary = _bootstrapAdapter.readCurrentLocalLibrary(_ref);
    final hasWorkspace =
        session?.currentAccount != null || localLibrary != null;
    if (!prefs.thirdPartyShareEnabled) {
      _logStartupInfo(
        'Startup: share_disabled',
        context: _buildStartupContext(
          phase: _startupHandled ? 'runtime' : 'startup',
          extra: _sharePayloadContext(payload),
        ),
      );
      _pendingSharePayload = null;
      _clearStartupShareLaunchUi();
      _setShareFlowActive(false);
      _notifyShareFlowReleased(source: 'share_disabled');
      _notifyShareDisabled();
      return hasWorkspace;
    }
    if (!hasWorkspace) return false;
    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return false;

    _pendingSharePayload = null;
    _logStartupInfo(
      'Startup: share_preview_scheduled',
      context: _buildStartupContext(
        phase: _startupHandled ? 'runtime' : 'startup',
        extra: _sharePayloadContext(payload),
      ),
    );
    if (_shouldOpenSharePreviewDirectly(payload)) {
      unawaited(_openSharePreviewTaskFlow(payload));
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) return;
      _appNavigator.openAllMemos();
      WidgetsBinding.instance.scheduleFrame();
      _scheduleShareFlowAfterNavigation(payload);
    });
    WidgetsBinding.instance.scheduleFrame();
    return true;
  }

  Future<void> _openSharePreviewTaskFlow(SharePayload payload) async {
    if (await _tryOpenDesktopShareTaskWindow(
      payload,
      source: 'direct_preview',
    )) {
      return;
    }
    await _openShareQuickClipFlow(payload);
  }

  void _scheduleShareFlowAfterNavigation(
    SharePayload payload, {
    int attempt = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) return;
      final context = _navigatorKey.currentContext;
      final navigator = _navigatorKey.currentState;
      if (context == null || navigator == null) {
        if (attempt >= 2) return;
        WidgetsBinding.instance.scheduleFrame();
        _scheduleShareFlowAfterNavigation(payload, attempt: attempt + 1);
        return;
      }
      unawaited(_openShareFlow(payload));
    });
  }

  bool _shouldOpenSharePreviewDirectly(SharePayload payload) {
    return payload.type == SharePayloadType.text &&
        buildShareCaptureRequest(payload) != null;
  }

  String _nextDesktopShareTaskRequestId() {
    final candidate = _desktopShareTaskRequestIdFactory?.call().trim();
    if (candidate != null &&
        candidate.isNotEmpty &&
        !_activeDesktopShareTasks.containsKey(candidate)) {
      return candidate;
    }
    var requestId = '';
    do {
      _desktopShareTaskRequestSequence += 1;
      requestId = 'share-$_desktopShareTaskRequestSequence';
    } while (_activeDesktopShareTasks.containsKey(requestId));
    return requestId;
  }

  Future<bool> _tryOpenDesktopShareTaskWindow(
    SharePayload payload, {
    required String source,
  }) async {
    final captureRequest = buildShareCaptureRequest(payload);
    if (captureRequest == null) return false;
    final requestId = _nextDesktopShareTaskRequestId();
    final result = await _desktopShareTaskWindowOpener(
      requestId: requestId,
      payloadJson: sharePayloadToJson(payload),
    );
    if (result.opened) {
      _activeDesktopShareTasks[requestId] = payload;
      _clearStartupShareLaunchUi();
      _setShareFlowActive(true);
      _logStartupInfo(
        'Startup: share_task_window_opened',
        context: _buildStartupContext(
          phase: _startupHandled ? 'runtime' : 'startup',
          source: source,
          extra: <String, Object?>{
            ..._sharePayloadContext(payload),
            'requestId': requestId,
            'windowId': result.windowId,
            'sharePreviewUrl': captureRequest.url.toString(),
          },
        ),
      );
      return true;
    }
    _logStartupInfo(
      'Startup: share_task_window_fallback',
      context: _buildStartupContext(
        phase: _startupHandled ? 'runtime' : 'startup',
        source: source,
        reason: result.status.name,
        extra: <String, Object?>{
          ..._sharePayloadContext(payload),
          'sharePreviewUrl': captureRequest.url.toString(),
          if (result.error != null) 'error': result.error.toString(),
        },
      ),
    );
    return false;
  }

  Future<bool> _handleDesktopShareTaskResult(
    Object? arguments,
    int fromWindowId,
  ) async {
    final result = DesktopShareTaskResult.fromArgs(arguments);
    if (result == null) {
      _logStartupInfo(
        'Startup: share_task_result_ignored',
        context: _buildStartupContext(
          phase: 'runtime',
          reason: 'invalid_payload',
          extra: <String, Object?>{'fromWindowId': fromWindowId},
        ),
      );
      return false;
    }
    final payload = _activeDesktopShareTasks[result.requestId];
    if (payload == null) {
      _logStartupInfo(
        'Startup: share_task_result_ignored',
        context: _buildStartupContext(
          phase: 'runtime',
          reason: 'unknown_request_id',
          extra: <String, Object?>{
            'fromWindowId': fromWindowId,
            'requestId': result.requestId,
          },
        ),
      );
      return false;
    }
    await _desktopMainWindowForegrounder();
    if (!_isMounted()) return false;
    final context = _navigatorKey.currentContext;
    if (context == null) return false;
    if (!context.mounted) return false;

    _activeDesktopShareTasks.remove(result.requestId);
    _logStartupInfo(
      'Startup: share_task_result',
      context: _buildStartupContext(
        phase: 'runtime',
        extra: <String, Object?>{
          ..._sharePayloadContext(payload),
          'fromWindowId': fromWindowId,
          'requestId': result.requestId,
        },
      ),
    );
    _openComposeRequest(
      context,
      result.request.copyWith(showLocalSaveSuccessToast: true),
    );
    await _completeDesktopShareTaskUpdate(source: 'share_task_result');
    return true;
  }

  Future<bool> _handleDesktopShareTaskCanceled(
    Object? arguments,
    int fromWindowId,
  ) async {
    final requestId = desktopShareTaskCanceledRequestId(arguments);
    if (requestId == null || requestId.isEmpty) {
      _logStartupInfo(
        'Startup: share_task_cancel_ignored',
        context: _buildStartupContext(
          phase: 'runtime',
          reason: 'invalid_payload',
          extra: <String, Object?>{'fromWindowId': fromWindowId},
        ),
      );
      return false;
    }
    final payload = _activeDesktopShareTasks.remove(requestId);
    if (payload == null) {
      _logStartupInfo(
        'Startup: share_task_cancel_ignored',
        context: _buildStartupContext(
          phase: 'runtime',
          reason: 'unknown_request_id',
          extra: <String, Object?>{
            'fromWindowId': fromWindowId,
            'requestId': requestId,
          },
        ),
      );
      return false;
    }
    _logStartupInfo(
      'Startup: share_task_canceled',
      context: _buildStartupContext(
        phase: 'runtime',
        extra: <String, Object?>{
          ..._sharePayloadContext(payload),
          'fromWindowId': fromWindowId,
          'requestId': requestId,
        },
      ),
    );
    await _completeDesktopShareTaskUpdate(source: 'share_task_canceled');
    return true;
  }

  Future<void> _completeDesktopShareTaskUpdate({required String source}) async {
    _refreshShareFlowActiveAfterDesktopTaskUpdate();
    if (_activeDesktopShareTasks.isNotEmpty) return;
    _flushDeferredQuickClipRecoveryIfNeeded(source: source);
    scheduleQuickClipRecovery(source: source);
    await _flushDeferredLaunchSyncIfNeeded();
    _notifyShareFlowReleased(source: source);
  }

  Future<void> _openShareQuickClipFlow(SharePayload payload) async {
    final captureRequest = buildShareCaptureRequest(payload);
    if (captureRequest == null) {
      await _openShareFlow(payload);
      return;
    }
    _logStartupInfo(
      'Startup: share_preview_open',
      context: _buildStartupContext(
        phase: _startupHandled ? 'runtime' : 'startup',
        extra: <String, Object?>{
          ..._sharePayloadContext(payload),
          'sharePreviewUrl': captureRequest.url.toString(),
        },
      ),
    );
    try {
      _clearStartupShareLaunchUi();
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final activeContext = _navigatorKey.currentContext;
      if (activeContext == null || !activeContext.mounted) return;
      final initialTagText = buildDefaultQuickClipTagText(payload);
      final locale = Localizations.localeOf(activeContext);
      final submission = await showShareQuickClipSheet(
        activeContext,
        payload: payload,
        initialTagText: initialTagText,
        initialTitleAndLinkOnly: true,
      );
      if (!_isMounted() || !activeContext.mounted || submission == null) return;
      final service = ShareQuickClipService(
        ref: _ref,
        bootstrapAdapter: _bootstrapAdapter,
      );
      try {
        if (_shareQuickClipStartOverride != null) {
          await _shareQuickClipStartOverride(
            payload: payload,
            submission: submission,
            locale: locale,
          );
        } else {
          await service.start(
            payload: payload,
            submission: submission,
            locale: locale,
          );
        }
        if (_isMounted() &&
            activeContext.mounted &&
            submission.titleAndLinkOnly) {
          _showTopToast(
            activeContext,
            activeContext.t.strings.shareClip.localSavedPendingSync,
          );
        }
      } catch (error, stackTrace) {
        LogManager.instance.error(
          'Startup: share_quick_clip_failed',
          error: error,
          stackTrace: stackTrace,
          context: _buildStartupContext(
            phase: _startupHandled ? 'runtime' : 'startup',
            extra: _sharePayloadContext(payload),
          ),
        );
        if (_isMounted() && activeContext.mounted) {
          _showTopToast(
            activeContext,
            activeContext.t.strings.legacy.msg_create_failed_2(e: error),
          );
        }
      }
    } finally {
      _clearStartupShareLaunchUi();
      _setShareFlowActive(false);
      _flushDeferredQuickClipRecoveryIfNeeded(source: 'share_flow_completed');
      scheduleQuickClipRecovery(source: 'share_flow_completed');
      unawaited(_flushDeferredLaunchSyncIfNeeded());
      _notifyShareFlowReleased(source: 'share_flow_completed');
    }
  }

  Future<void> _openShareFlow(SharePayload payload) async {
    final currentContext = _navigatorKey.currentContext;
    if (currentContext == null) return;
    if (payload.type == SharePayloadType.images) {
      _openShareComposer(currentContext, payload);
      return;
    }

    final captureRequest = buildShareCaptureRequest(payload);
    if (captureRequest == null) {
      _openShareComposer(currentContext, payload);
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    if (await _tryOpenDesktopShareTaskWindow(
      payload,
      source: 'route_preview',
    )) {
      return;
    }
    _setShareFlowActive(true);
    try {
      final composeRequest = await navigator.push<ShareComposeRequest>(
        _buildSharePreviewRoute(payload),
      );
      if (!_isMounted() || composeRequest == null) return;
      _openComposeRequestWithCurrentContext(
        composeRequest.copyWith(showLocalSaveSuccessToast: true),
      );
    } finally {
      _clearStartupShareLaunchUi();
      _setShareFlowActive(false);
      _flushDeferredQuickClipRecoveryIfNeeded(source: 'share_flow_completed');
      scheduleQuickClipRecovery(source: 'share_flow_completed');
      unawaited(_flushDeferredLaunchSyncIfNeeded());
      _notifyShareFlowReleased(source: 'share_flow_completed');
    }
  }

  Route<T> _buildInstantRoute<T>(Widget child) {
    return buildFadeSlideRoute<T>(
      context: _navigatorKey.currentContext,
      builder: (_) => child,
      beginOffset: Offset.zero,
      enabled: false,
    );
  }

  Route<ShareComposeRequest> _buildSharePreviewRoute(SharePayload payload) {
    return _sharePreviewRouteBuilder?.call(payload) ??
        _buildInstantRoute<ShareComposeRequest>(
          ShareClipScreen(payload: payload),
        );
  }

  void _openShareComposer(BuildContext context, SharePayload payload) {
    if (payload.type == SharePayloadType.images) {
      if (payload.paths.isEmpty) return;
      _openComposeRequest(
        context,
        ShareComposeRequest(
          text: '',
          selectionOffset: 0,
          attachmentPaths: payload.paths,
          showLocalSaveSuccessToast: true,
        ),
      );
      return;
    }

    final draft = buildShareTextDraft(payload);
    _openComposeRequest(
      context,
      ShareComposeRequest(
        text: draft.text,
        selectionOffset: draft.selectionOffset,
        showLocalSaveSuccessToast: true,
      ),
    );
  }

  void _openComposeRequest(BuildContext context, ShareComposeRequest request) {
    final presenter = _shareComposeRequestPresenterOverride;
    if (presenter != null) {
      presenter(context, request);
    } else {
      NoteInputSheet.show(
        context,
        initialText: request.text,
        initialSelection: TextSelection.collapsed(
          offset: request.selectionOffset,
        ),
        initialAttachmentPaths: request.attachmentPaths,
        initialAttachmentSeeds: request.initialAttachmentSeeds,
        initialClipMetadataDraft: request.clipMetadataDraft,
        initialDeferredInlineImageAttachments:
            request.deferredInlineImageAttachments,
        initialDeferredVideoAttachments: request.deferredVideoAttachments,
        showLocalSaveSuccessToast: request.showLocalSaveSuccessToast,
        ignoreDraft: true,
      );
    }
    if ((request.userMessage ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted()) return;
        _showTopToast(context, request.userMessage!);
      });
    }
  }

  void _openComposeRequestWithCurrentContext(ShareComposeRequest request) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    _openComposeRequest(context, request);
  }

  void _notifyShareDisabled() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    _showTopToast(
      context,
      context.t.strings.legacy.msg_third_party_share_disabled,
    );
  }
}
