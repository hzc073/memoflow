import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/top_toast.dart';
import '../../core/app_route_transitions.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/resolved_app_settings.dart';
import '../../data/models/workspace_preferences.dart';
import '../../features/memos/memo_detail_screen.dart';
import '../../features/memos/note_input_sheet.dart';
import '../../features/share/share_clip_models.dart';
import '../../features/share/share_clip_screen.dart';
import '../../features/share/share_handler.dart';
import '../../features/share/share_quick_clip_models.dart';
import '../../features/share/share_quick_clip_service.dart';
import '../../features/share/share_quick_clip_sheet.dart';
import '../../i18n/strings.g.dart';
import '../../presentation/navigation/app_navigator.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../app/app_sync_orchestrator.dart';
import '../widgets/home_widget_service.dart';

part 'startup_coordinator_models.dart';
part 'startup_coordinator_logging.dart';
part 'startup_coordinator_state.dart';
part 'startup_coordinator_decision.dart';
part 'startup_coordinator_share.dart';
part 'startup_coordinator_widget.dart';

enum _StartupAction { share, widget, launchAction, none }

typedef ShareQuickClipStartCallback =
    Future<void> Function({
      required SharePayload payload,
      required ShareQuickClipSubmission submission,
      required Locale locale,
    });
typedef ShareComposeRequestPresenter =
    void Function(BuildContext context, ShareComposeRequest request);
typedef TopToastPresenter = bool Function(BuildContext context, String message);

class StartupCoordinator extends ChangeNotifier {
  StartupCoordinator({
    required AppBootstrapAdapter bootstrapAdapter,
    required AppSyncOrchestrator syncOrchestrator,
    required AppNavigator appNavigator,
    required GlobalKey<NavigatorState> navigatorKey,
    required WidgetRef ref,
    required bool Function() isMounted,
    @visibleForTesting
    Route<ShareComposeRequest> Function(SharePayload payload)?
    sharePreviewRouteBuilder,
    @visibleForTesting ShareQuickClipStartCallback? shareQuickClipStartOverride,
    @visibleForTesting
    ShareComposeRequestPresenter? shareComposeRequestPresenterOverride,
    @visibleForTesting TopToastPresenter? topToastPresenterOverride,
  }) : _bootstrapAdapter = bootstrapAdapter,
       _syncOrchestrator = syncOrchestrator,
       _appNavigator = appNavigator,
       _navigatorKey = navigatorKey,
       _ref = ref,
       _isMounted = isMounted,
       _sharePreviewRouteBuilder = sharePreviewRouteBuilder,
       _shareQuickClipStartOverride = shareQuickClipStartOverride,
       _shareComposeRequestPresenterOverride =
           shareComposeRequestPresenterOverride,
       _topToastPresenterOverride = topToastPresenterOverride;

  final AppBootstrapAdapter _bootstrapAdapter;
  final AppSyncOrchestrator _syncOrchestrator;
  final AppNavigator _appNavigator;
  final GlobalKey<NavigatorState> _navigatorKey;
  final WidgetRef _ref;
  final bool Function() _isMounted;
  final Route<ShareComposeRequest> Function(SharePayload payload)?
  _sharePreviewRouteBuilder;
  final ShareQuickClipStartCallback? _shareQuickClipStartOverride;
  final ShareComposeRequestPresenter? _shareComposeRequestPresenterOverride;
  final TopToastPresenter? _topToastPresenterOverride;

  bool _showTopToast(BuildContext context, String message) {
    return (_topToastPresenterOverride ?? showTopToast)(context, message);
  }

  HomeWidgetLaunchPayload? _pendingWidgetLaunch;
  SharePayload? _pendingSharePayload;
  bool _shareHandlingScheduled = false;
  bool _widgetHandlingScheduled = false;
  bool _startupHandled = false;
  bool _startupScheduled = false;
  String? _startupScheduleKey;
  String? _startupLogKey;
  String? _startupDebugKey;
  String? _startupRetryKey;
  int _startupRetryCount = 0;
  bool _startupRetryScheduled = false;
  _StartupAction? _lastStartupAction;
  Future<void>? _pendingWidgetLaunchLoad;
  Future<void>? _pendingShareLoad;
  SharePayload? _startupSharePreviewPayload;
  bool _shareFlowActive = false;
  WorkspacePreferences? _deferredLaunchSyncPreferences;

  SharePayload? get startupSharePreviewPayload => _startupSharePreviewPayload;

  bool get shouldDeferHeavyStartupWork =>
      _startupSharePreviewPayload != null || _shareFlowActive;

  @visibleForTesting
  Map<String, Object?> debugReadStartupSnapshot() {
    final snapshot = _readStartupSnapshot();
    return <String, Object?>{
      'prefsLoaded': snapshot.prefsLoaded,
      'hasAccount': snapshot.hasAccount,
      'hasWorkspace': snapshot.hasWorkspace,
      'navigatorReady': snapshot.navigatorReady,
      'contextReady': snapshot.contextReady,
      'launchAction': snapshot.settings.device.launchAction.name,
    };
  }

  @visibleForTesting
  static String debugSelectStartupActionName({
    required bool hasPendingShare,
    required bool hasPendingWidget,
    required LaunchAction launchAction,
  }) {
    if (hasPendingShare) return _StartupAction.share.name;
    if (hasPendingWidget) return _StartupAction.widget.name;
    if (launchAction != LaunchAction.none) {
      return _StartupAction.launchAction.name;
    }
    return _StartupAction.none.name;
  }

  @visibleForTesting
  static String debugSelectStartupReason({
    required bool hasPendingShare,
    required bool hasPendingWidget,
    required LaunchAction launchAction,
  }) {
    if (hasPendingShare) return 'pending_share';
    if (hasPendingWidget) return 'pending_widget';
    if (launchAction != LaunchAction.none) return 'prefs_launch_action';
    return 'none';
  }

  @visibleForTesting
  static String? debugEvaluateShareBlockReason({
    required bool prefsLoaded,
    required bool hasAccount,
    required bool hasNavigator,
    required bool hasContext,
  }) {
    if (!prefsLoaded) return 'prefs_not_loaded';
    if (!hasAccount) return 'no_account';
    if (!hasNavigator) return 'no_navigator';
    if (!hasContext) return 'no_context';
    return null;
  }

  @visibleForTesting
  static String? debugEvaluateWidgetBlockReason({
    required bool hasWorkspace,
    required bool hasNavigator,
    required bool hasContext,
  }) {
    if (!hasWorkspace) return 'no_workspace';
    if (!hasNavigator) return 'no_navigator';
    if (!hasContext) return 'no_context';
    return null;
  }

  @visibleForTesting
  static bool debugShouldRetryForReason(String reason) {
    return reason == 'no_navigator' || reason == 'no_context';
  }

  static _StartupAction _startupActionFromName(String name) {
    return switch (name) {
      'share' => _StartupAction.share,
      'widget' => _StartupAction.widget,
      'launchAction' => _StartupAction.launchAction,
      _ => _StartupAction.none,
    };
  }

  Future<void> loadPendingLaunchSources() {
    _pendingWidgetLaunchLoad = _loadPendingWidgetLaunch();
    _pendingShareLoad = _loadPendingShare();
    return Future.wait(<Future<void>>[
      _pendingWidgetLaunchLoad!,
      _pendingShareLoad!,
    ], eagerError: false);
  }

  Future<void> handleWidgetLaunch(HomeWidgetLaunchPayload payload) async {
    _pendingWidgetLaunch = payload;
    if (_startupHandled) {
      _logStartupInfo(
        'Startup: runtime_widget',
        context: _buildStartupContext(phase: 'runtime', source: 'launch'),
      );
      _scheduleWidgetHandling();
      return;
    }
    _requestStartupHandlingFromState(source: 'launch');
  }

  Future<void> handleShareLaunch(SharePayload payload) async {
    _pendingSharePayload = payload;
    _armStartupShareLaunchUi(payload);
    _armRuntimeShareLaunchUi(payload);
    if (_startupHandled) {
      _logStartupInfo(
        'Startup: runtime_share',
        context: _buildStartupContext(
          phase: 'runtime',
          source: 'launch',
          extra: _sharePayloadContext(payload),
        ),
      );
      _scheduleShareHandling();
      return;
    }
    _requestStartupHandlingFromState(source: 'launch');
  }

  void onPrefsLoaded({String? source}) {
    _requestStartupHandlingFromState(source: source ?? 'prefs_loaded');
  }

  void onSessionChanged({String? source}) {
    _requestStartupHandlingFromState(source: source ?? 'session');
  }

  void onLocalLibraryChanged({String? source}) {
    _requestStartupHandlingFromState(source: source ?? 'local_library');
  }

  void onBuild({
    required bool prefsLoaded,
    required bool hasWorkspace,
    required bool hasAccount,
    required ResolvedAppSettings settings,
    String? source,
    bool force = false,
  }) {
    _requestStartupHandling(
      prefsLoaded: prefsLoaded,
      hasWorkspace: hasWorkspace,
      hasAccount: hasAccount,
      settings: settings,
      source: source ?? 'build',
      force: force,
    );
  }

  void scheduleShareHandling() => _scheduleShareHandling();

  void scheduleWidgetHandling() => _scheduleWidgetHandling();

  @override
  void dispose() {
    _startupHandled = true;
    super.dispose();
  }

  Future<void> openQuickInput({required bool autoFocus}) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _appNavigator.openAllMemos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sheetContext = _navigatorKey.currentContext;
      if (sheetContext != null) {
        NoteInputSheet.show(sheetContext, autoFocus: autoFocus);
      }
    });
  }

  void _notifyCoordinatorListeners() {
    notifyListeners();
  }
}
