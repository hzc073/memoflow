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
      unawaited(_openShareQuickClipFlow(payload));
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) return;
      _appNavigator.openAllMemos();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted()) return;
        unawaited(_openShareFlow(payload));
      });
    });
    return true;
  }

  bool _shouldOpenSharePreviewDirectly(SharePayload payload) {
    return payload.type == SharePayloadType.text &&
        buildShareCaptureRequest(payload) != null;
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
      await service.start(
        payload: payload,
        submission: submission,
        locale: locale,
      );
    } finally {
      _clearStartupShareLaunchUi();
      _setShareFlowActive(false);
      unawaited(_flushDeferredLaunchSyncIfNeeded());
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
    final composeRequest = await navigator.push<ShareComposeRequest>(
      _buildSharePreviewRoute(payload),
    );
    if (!_isMounted() || composeRequest == null) return;
    _openComposeRequestWithCurrentContext(composeRequest);
  }

  Route<T> _buildInstantRoute<T>(Widget child) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
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
      ),
    );
  }

  void _openComposeRequest(BuildContext context, ShareComposeRequest request) {
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
      ignoreDraft: true,
    );
    if ((request.userMessage ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted()) return;
        showTopToast(context, request.userMessage!);
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
    showTopToast(
      context,
      context.t.strings.legacy.msg_third_party_share_disabled,
    );
  }
}
