part of 'startup_coordinator.dart';

extension _StartupCoordinatorWidget on StartupCoordinator {
  Future<void> _loadPendingWidgetLaunch() async {
    final payload = await HomeWidgetService.consumePendingLaunch();
    if (!_isMounted() || payload == null) return;
    _pendingWidgetLaunch = payload;
    if (_startupHandled) {
      _logStartupInfo(
        'Startup: runtime_widget',
        context: _buildStartupContext(phase: 'runtime', source: 'pending'),
      );
      _scheduleWidgetHandling();
      return;
    }
    _requestStartupHandlingFromState(source: 'pending');
  }

  void _scheduleWidgetHandling() {
    if (_widgetHandlingScheduled) return;
    _widgetHandlingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _widgetHandlingScheduled = false;
      if (!_isMounted()) return;
      _handlePendingWidgetAction();
    });
  }

  bool _handlePendingWidgetAction() {
    final payload = _pendingWidgetLaunch;
    if (payload == null) return false;
    final session = _bootstrapAdapter.readSession(_ref);
    final localLibrary = _bootstrapAdapter.readCurrentLocalLibrary(_ref);
    if (session?.currentAccount == null && localLibrary == null) return false;
    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return false;

    _pendingWidgetLaunch = null;
    switch (payload.widgetType) {
      case HomeWidgetType.dailyReview:
        final memoUid = payload.memoUid?.trim();
        if (memoUid == null || memoUid.isEmpty) {
          _appNavigator.openDailyReview();
          break;
        }
        unawaited(_openWidgetMemoDetail(memoUid));
        break;
      case HomeWidgetType.quickInput:
        unawaited(
          openQuickInput(
            autoFocus: AppPreferences.defaults.quickInputAutoFocus,
          ),
        );
        break;
      case HomeWidgetType.calendar:
        final epochSec = payload.dayEpochSec;
        if (epochSec == null || epochSec <= 0) {
          _appNavigator.openAllMemos();
          break;
        }
        final selectedDay = DateTime.fromMillisecondsSinceEpoch(
          epochSec * 1000,
          isUtc: true,
        ).toLocal();
        final normalizedSelectedDay = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
        );
        final now = DateTime.now();
        final normalizedToday = DateTime(now.year, now.month, now.day);
        if (normalizedSelectedDay.isAfter(normalizedToday)) {
          _appNavigator.openAllMemos();
          break;
        }
        _appNavigator.openDayMemos(selectedDay);
        break;
    }
    return true;
  }

  Future<void> _openWidgetMemoDetail(String memoUid) async {
    final row = await _bootstrapAdapter
        .readDatabase(_ref)
        .getMemoByUid(memoUid);
    if (!_isMounted()) return;
    if (row == null) {
      _appNavigator.openDailyReview();
      return;
    }
    final memo = LocalMemo.fromDb(row);
    _appNavigator.openAllMemos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context == null) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MemoDetailScreen(initialMemo: memo),
        ),
      );
    });
  }
}
