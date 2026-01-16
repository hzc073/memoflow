import 'package:flutter/widgets.dart';

import 'breadcrumb_store.dart';
import 'sync_status_tracker.dart';

class LoggerService with WidgetsBindingObserver {
  LoggerService({
    required BreadcrumbStore breadcrumbStore,
    required SyncStatusTracker syncStatusTracker,
  })  : _breadcrumbs = breadcrumbStore,
        _syncStatusTracker = syncStatusTracker,
        navigatorObserver = _BreadcrumbNavigatorObserver();

  final BreadcrumbStore _breadcrumbs;
  final SyncStatusTracker _syncStatusTracker;
  AppLifecycleState? _lifecycleState;
  bool _started = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    recordBreadcrumb('Lifecycle: ${_formatLifecycle(state)}');
  }

  final NavigatorObserver navigatorObserver;

  AppLifecycleState? get lifecycleState => _lifecycleState;
  SyncStatusTracker get syncStatusTracker => _syncStatusTracker;

  void start() {
    if (_started) return;
    _started = true;
    final binding = WidgetsBinding.instance;
    _lifecycleState = binding.lifecycleState;
    final initialState = _lifecycleState;
    if (initialState != null) {
      recordBreadcrumb('Lifecycle: ${_formatLifecycle(initialState)}');
    }
    binding.addObserver(this);
    _attachNavigatorObserver();
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _detachNavigatorObserver();
    _started = false;
  }

  void recordBreadcrumb(String message) {
    _breadcrumbs.add(message);
  }

  void recordScreen(String screen) {
    _breadcrumbs.add('Screen: $screen');
  }

  void recordAction(String action) {
    _breadcrumbs.add('Action: $action');
  }

  void recordError(String error) {
    _breadcrumbs.add('Error: $error');
  }

  static String formatLifecycle(AppLifecycleState? state) {
    if (state == null) return 'Unknown';
    return _formatLifecycle(state);
  }

  void _attachNavigatorObserver() {
    if (navigatorObserver is _BreadcrumbNavigatorObserver) {
      (navigatorObserver as _BreadcrumbNavigatorObserver).attach(this);
    }
  }

  void _detachNavigatorObserver() {
    if (navigatorObserver is _BreadcrumbNavigatorObserver) {
      (navigatorObserver as _BreadcrumbNavigatorObserver).detach();
    }
  }

  static String _formatLifecycle(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.resumed => 'Resumed',
      AppLifecycleState.inactive => 'Inactive',
      AppLifecycleState.paused => 'Paused',
      AppLifecycleState.detached => 'Detached',
      _ => 'Hidden',
    };
  }
}

class _BreadcrumbNavigatorObserver extends NavigatorObserver {
  LoggerService? _logger;

  void attach(LoggerService logger) {
    _logger = logger;
  }

  void detach() {
    _logger = null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logRoute(route, isDialog: route is PopupRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _logRoute(newRoute, isDialog: newRoute is PopupRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  String _routeLabel(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return route.runtimeType.toString();
  }

  void _logRoute(Route<dynamic> route, {required bool isDialog}) {
    final logger = _logger;
    if (logger == null) return;
    final label = _routeLabel(route);
    if (isDialog) {
      logger.recordBreadcrumb('Dialog: $label');
    } else {
      logger.recordScreen(label);
    }
  }
}
