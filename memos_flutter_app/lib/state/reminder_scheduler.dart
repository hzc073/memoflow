import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_localization.dart';
import '../core/desktop_tray_controller.dart';
import '../core/system_settings_launcher.dart';
import '../data/models/local_memo.dart';
import '../data/models/memo_reminder.dart';
import 'reminder_utils.dart';
import 'database_provider.dart';
import 'logging_provider.dart';
import 'preferences_provider.dart';
import 'reminder_settings_provider.dart';
import 'session_provider.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

enum ReminderTapTarget { memoDetail, memosList }

class ReminderTapPayload {
  const ReminderTapPayload({
    required this.memoUid,
    required this.target,
    this.memo,
  });

  final String memoUid;
  final ReminderTapTarget target;
  final LocalMemo? memo;
}

typedef ReminderTapHandler = Future<void> Function(ReminderTapPayload payload);

class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  ReminderTapHandler? _tapHandler;
  bool _initialized = false;
  Completer<void>? _initCompleter;
  DateTime? _lastRescheduleAt;
  int? _androidSdkInt;
  Timer? _windowsReminderTicker;
  Timer? _windowsTestReminderTimer;
  final Set<LocalNotification> _windowsActiveNotifications =
      <LocalNotification>{};
  List<_WindowsPendingReminder> _windowsPendingReminders =
      const <_WindowsPendingReminder>[];
  bool _windowsNotifierReady = false;
  bool _windowsReminderTicking = false;

  bool get _supportsReminderNotifications =>
      Platform.isAndroid || Platform.isWindows;

  void setTapHandler(ReminderTapHandler? handler) {
    _tapHandler = handler;
  }

  String channelIdFor(ReminderSettings settings) => _channelIdFor(settings);

  void _logInfo(String message, {Map<String, Object?>? context}) {
    _ref.read(logManagerProvider).info('Reminder: $message', context: context);
  }

  void _logWarn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _ref
        .read(logManagerProvider)
        .warn(
          'Reminder: $message',
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
  }

  void _logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _ref
        .read(logManagerProvider)
        .error(
          'Reminder: $message',
          error: error,
          stackTrace: stackTrace,
          context: context,
        );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    if (!_supportsReminderNotifications) {
      _initialized = true;
      _logInfo(
        'init_skip',
        context: {
          'reason': 'unsupported_platform',
          'platform': Platform.operatingSystem,
        },
      );
      _initCompleter?.complete();
      return;
    }

    if (Platform.isWindows) {
      try {
        await localNotifier.setup(
          appName: 'MemoFlow',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
        _windowsNotifierReady = true;
        _logInfo('windows_notifier_initialized');
      } catch (e, st) {
        _windowsNotifierReady = false;
        _logError('windows_notifier_init_failed', error: e, stackTrace: st);
      }
      _initialized = true;
      _initCompleter?.complete();
      return;
    }

    _logInfo('init_start');
    tz_data.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
      _logInfo('timezone_resolved', context: {'tz': timeZone.identifier});
    } catch (e, st) {
      tz.setLocalLocation(tz.UTC);
      _logWarn('timezone_fallback', error: e, stackTrace: st);
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    _logInfo('plugin_initialized');

    final details = await _plugin.getNotificationAppLaunchDetails();
    final didLaunch = details?.didNotificationLaunchApp ?? false;
    final payload = details?.notificationResponse?.payload;
    final hasPayload = payload != null && payload.trim().isNotEmpty;
    _logInfo(
      'launch_details',
      context: {'didLaunch': didLaunch, 'hasPayload': hasPayload},
    );
    if (didLaunch && hasPayload) {
      unawaited(_handleNotificationTap(payload));
    }

    _initialized = true;
    _initCompleter?.complete();
  }

  Future<void> rescheduleAll({bool force = false}) async {
    await initialize();
    if (!_supportsReminderNotifications) return;
    _logInfo('reschedule_start', context: {'force': force});

    if (!force && _lastRescheduleAt != null) {
      final last = _lastRescheduleAt!;
      final elapsed = DateTime.now().difference(last);
      if (elapsed < const Duration(seconds: 3)) {
        _logInfo(
          'reschedule_skip_recent',
          context: {'elapsedMs': elapsed.inMilliseconds},
        );
        return;
      }
    }
    _lastRescheduleAt = DateTime.now();

    if (Platform.isWindows) {
      await _rescheduleAllForWindows();
      return;
    }

    final session = _ref.read(appSessionProvider).valueOrNull;
    if (session?.currentAccount == null) {
      _logWarn('reschedule_skip', context: {'reason': 'no_session'});
      await _plugin.cancelAll();
      return;
    }

    final settings = _ref.read(reminderSettingsProvider);
    if (!settings.enabled) {
      _logInfo('reschedule_skip', context: {'reason': 'disabled'});
      await _plugin.cancelAll();
      return;
    }

    final permissions = await _checkPermissions();
    if (!permissions.notificationsGranted) {
      _logWarn(
        'reschedule_skip',
        context: {
          'reason': 'notifications_denied',
          'exactAlarmGranted': permissions.exactAlarmGranted,
        },
      );
      await _plugin.cancelAll();
      return;
    }

    await _plugin.cancelAll();
    _logInfo('reschedule_cancel_all');

    final db = _ref.read(databaseProvider);
    final rows = await db.listMemoReminders();
    if (rows.isEmpty) {
      _logInfo('reschedule_empty');
      return;
    }

    _logInfo('reschedule_loaded', context: {'memos': rows.length});
    final now = DateTime.now();
    final channel = await _ensureChannel(settings);
    final details = NotificationDetails(
      android: _androidDetails(settings, channel),
    );
    final title = settings.notificationTitle;
    final body = settings.notificationBody;
    var scheduledCount = 0;
    var exactCount = 0;
    var inexactCount = 0;
    var skippedDnd = 0;
    var skippedPast = 0;
    var removedCount = 0;
    var catchUpCount = 0;

    for (final row in rows) {
      final reminder = MemoReminder.fromDb(row);
      final pendingTimes = <DateTime>[];
      final catchUps = <DateTime>{};

      for (final time in reminder.times) {
        final normalized = DateTime(
          time.year,
          time.month,
          time.day,
          time.hour,
          time.minute,
        );
        final dndEnd = dndEndFor(normalized, settings);
        if (dndEnd != null && dndEnd.isAfter(now)) {
          pendingTimes.add(normalized);
          catchUps.add(
            DateTime(
              dndEnd.year,
              dndEnd.month,
              dndEnd.day,
              dndEnd.hour,
              dndEnd.minute,
            ),
          );
          continue;
        }
        if (!normalized.isBefore(now)) {
          pendingTimes.add(normalized);
        }
      }

      final deduped = _dedupeTimes(pendingTimes);
      if (deduped.isEmpty) {
        await db.deleteMemoReminder(reminder.memoUid);
        removedCount++;
        continue;
      }

      if (!_sameTimes(deduped, reminder.times)) {
        await db.upsertMemoReminder(
          memoUid: reminder.memoUid,
          mode: reminder.mode.name,
          timesJson: MemoReminder.encodeTimes(deduped),
        );
      }

      for (final time in deduped) {
        if (isInDnd(time, settings)) {
          skippedDnd++;
          continue;
        }
        if (time.isBefore(now)) {
          skippedPast++;
          continue;
        }
        final exactUsed = await _scheduleNotification(
          details: details,
          memoUid: reminder.memoUid,
          when: time,
          key: _timeKey(time),
          title: title,
          body: body,
        );
        scheduledCount++;
        if (exactUsed) {
          exactCount++;
        } else {
          inexactCount++;
        }
      }

      for (final time in catchUps) {
        if (time.isBefore(now)) {
          skippedPast++;
          continue;
        }
        final exactUsed = await _scheduleNotification(
          details: details,
          memoUid: reminder.memoUid,
          when: time,
          key: 'dnd_${_timeKey(time)}',
          title: title,
          body: body,
        );
        scheduledCount++;
        catchUpCount++;
        if (exactUsed) {
          exactCount++;
        } else {
          inexactCount++;
        }
      }
    }

    _logInfo(
      'reschedule_done',
      context: {
        'memos': rows.length,
        'scheduled': scheduledCount,
        'exact': exactCount,
        'inexact': inexactCount,
        'catchUps': catchUpCount,
        'skippedDnd': skippedDnd,
        'skippedPast': skippedPast,
        'removed': removedCount,
      },
    );
    final pending = await _plugin.pendingNotificationRequests();
    _logInfo('reschedule_pending', context: {'pending': pending.length});
  }

  Future<void> _rescheduleAllForWindows() async {
    if (!_windowsNotifierReady) {
      _logWarn(
        'reschedule_skip',
        context: {'reason': 'windows_notifier_not_ready'},
      );
      await _clearWindowsSchedules(closeNotifications: false);
      return;
    }

    final session = _ref.read(appSessionProvider).valueOrNull;
    if (session?.currentAccount == null) {
      _logWarn('reschedule_skip', context: {'reason': 'no_session'});
      await _clearWindowsSchedules();
      return;
    }

    final settings = _ref.read(reminderSettingsProvider);
    if (!settings.enabled) {
      _logInfo('reschedule_skip', context: {'reason': 'disabled'});
      await _clearWindowsSchedules();
      return;
    }

    final permissions = await _checkPermissions();
    if (!permissions.notificationsGranted) {
      _logWarn(
        'reschedule_skip',
        context: {
          'reason': 'notifications_denied',
          'exactAlarmGranted': permissions.exactAlarmGranted,
        },
      );
      await _clearWindowsSchedules();
      return;
    }

    await _clearWindowsSchedules();
    _logInfo('reschedule_cancel_all');

    final db = _ref.read(databaseProvider);
    final rows = await db.listMemoReminders();
    if (rows.isEmpty) {
      _logInfo('reschedule_empty');
      return;
    }

    _logInfo('reschedule_loaded', context: {'memos': rows.length});
    final now = DateTime.now();
    final pendingReminders = <_WindowsPendingReminder>[];
    var scheduledCount = 0;
    var skippedDnd = 0;
    var skippedPast = 0;
    var removedCount = 0;
    var catchUpCount = 0;

    for (final row in rows) {
      final reminder = MemoReminder.fromDb(row);
      final pendingTimes = <DateTime>[];
      final catchUps = <DateTime>{};

      for (final time in reminder.times) {
        final normalized = DateTime(
          time.year,
          time.month,
          time.day,
          time.hour,
          time.minute,
        );
        final dndEnd = dndEndFor(normalized, settings);
        if (dndEnd != null && dndEnd.isAfter(now)) {
          pendingTimes.add(normalized);
          catchUps.add(
            DateTime(
              dndEnd.year,
              dndEnd.month,
              dndEnd.day,
              dndEnd.hour,
              dndEnd.minute,
            ),
          );
          continue;
        }
        if (!normalized.isBefore(now)) {
          pendingTimes.add(normalized);
        }
      }

      final deduped = _dedupeTimes(pendingTimes);
      if (deduped.isEmpty) {
        await db.deleteMemoReminder(reminder.memoUid);
        removedCount++;
        continue;
      }

      if (!_sameTimes(deduped, reminder.times)) {
        await db.upsertMemoReminder(
          memoUid: reminder.memoUid,
          mode: reminder.mode.name,
          timesJson: MemoReminder.encodeTimes(deduped),
        );
      }

      for (final time in deduped) {
        if (isInDnd(time, settings)) {
          skippedDnd++;
          continue;
        }
        if (time.isBefore(now)) {
          skippedPast++;
          continue;
        }
        pendingReminders.add(
          _WindowsPendingReminder(
            memoUid: reminder.memoUid,
            when: time,
            key: _timeKey(time),
          ),
        );
        scheduledCount++;
      }

      for (final time in catchUps) {
        if (time.isBefore(now)) {
          skippedPast++;
          continue;
        }
        pendingReminders.add(
          _WindowsPendingReminder(
            memoUid: reminder.memoUid,
            when: time,
            key: 'dnd_${_timeKey(time)}',
          ),
        );
        scheduledCount++;
        catchUpCount++;
      }
    }

    pendingReminders.sort((a, b) => a.when.compareTo(b.when));
    _windowsPendingReminders = pendingReminders;
    _startWindowsReminderTicker();

    _logInfo(
      'reschedule_done',
      context: {
        'memos': rows.length,
        'scheduled': scheduledCount,
        'exact': 0,
        'inexact': scheduledCount,
        'catchUps': catchUpCount,
        'skippedDnd': skippedDnd,
        'skippedPast': skippedPast,
        'removed': removedCount,
      },
    );
    _logInfo(
      'reschedule_pending',
      context: {'pending': _windowsPendingReminders.length},
    );
  }

  void _startWindowsReminderTicker() {
    _windowsReminderTicker?.cancel();
    if (_windowsPendingReminders.isEmpty) return;

    _windowsReminderTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_deliverDueWindowsReminders());
    });
    unawaited(_deliverDueWindowsReminders());
  }

  Future<void> _deliverDueWindowsReminders() async {
    if (!_windowsNotifierReady) return;
    if (_windowsReminderTicking) return;
    final pending = _windowsPendingReminders;
    if (pending.isEmpty) return;

    _windowsReminderTicking = true;
    try {
      final now = DateTime.now();
      final due = <_WindowsPendingReminder>[];
      final remaining = <_WindowsPendingReminder>[];

      for (final reminder in pending) {
        if (reminder.when.isAfter(now)) {
          remaining.add(reminder);
        } else {
          due.add(reminder);
        }
      }

      _windowsPendingReminders = remaining;
      if (due.isEmpty) return;

      final settings = _ref.read(reminderSettingsProvider);
      for (final reminder in due) {
        await _showWindowsReminderNotification(reminder, settings);
      }

      _logInfo(
        'windows_due_delivered',
        context: {'count': due.length, 'remaining': remaining.length},
      );
    } finally {
      _windowsReminderTicking = false;
      if (_windowsPendingReminders.isEmpty) {
        _windowsReminderTicker?.cancel();
        _windowsReminderTicker = null;
      }
    }
  }

  Future<void> _showWindowsReminderNotification(
    _WindowsPendingReminder reminder,
    ReminderSettings settings,
  ) async {
    final language = _ref.read(appPreferencesProvider).language;
    final titleRaw = settings.notificationTitle.trim();
    final bodyRaw = settings.notificationBody.trim();
    final title = titleRaw.isEmpty
        ? trByLanguageKey(
            language: language,
            key: 'legacy.reminder.default_title',
          )
        : titleRaw;
    final body = bodyRaw.isEmpty
        ? trByLanguageKey(
            language: language,
            key: 'legacy.reminder.default_body',
          )
        : bodyRaw;
    final notification = LocalNotification(
      title: title,
      body: body,
      silent: settings.soundMode == ReminderSoundMode.silent,
    );

    void cleanup() {
      if (!_windowsActiveNotifications.remove(notification)) return;
      unawaited(notification.destroy());
    }

    notification.onClick = () {
      unawaited(_handleWindowsNotificationTap(reminder.memoUid));
      cleanup();
    };
    notification.onClose = (_) => cleanup();

    _windowsActiveNotifications.add(notification);
    try {
      await notification.show();
      _logInfo(
        'windows_notification_shown',
        context: {
          'memo': _memoToken(reminder.memoUid),
          'when': reminder.when.toIso8601String(),
          'key': reminder.key,
        },
      );
    } catch (e, st) {
      _windowsActiveNotifications.remove(notification);
      _logError(
        'windows_notification_show_failed',
        error: e,
        stackTrace: st,
        context: {'memo': _memoToken(reminder.memoUid), 'key': reminder.key},
      );
    }
  }

  Future<void> _handleWindowsNotificationTap(String memoUid) async {
    if (Platform.isWindows && DesktopTrayController.instance.supported) {
      try {
        await DesktopTrayController.instance.showFromTray();
      } catch (_) {}
    }
    await _handleNotificationTap(jsonEncode({'memo_uid': memoUid}));
  }

  Future<void> _clearWindowsSchedules({bool closeNotifications = true}) async {
    _windowsReminderTicker?.cancel();
    _windowsReminderTicker = null;
    _windowsTestReminderTimer?.cancel();
    _windowsTestReminderTimer = null;
    _windowsPendingReminders = const <_WindowsPendingReminder>[];

    if (!closeNotifications || _windowsActiveNotifications.isEmpty) return;
    final active = _windowsActiveNotifications.toList(growable: false);
    _windowsActiveNotifications.clear();
    for (final notification in active) {
      try {
        await notification.destroy();
      } catch (_) {}
    }
  }

  LocalNotification _buildWindowsTestNotification(ReminderSettings settings) {
    final language = _ref.read(appPreferencesProvider).language;
    final titleRaw = settings.notificationTitle.trim();
    final bodyRaw = settings.notificationBody.trim();
    final title = titleRaw.isEmpty
        ? trByLanguageKey(
            language: language,
            key: 'legacy.reminder.default_title',
          )
        : titleRaw;
    final body = bodyRaw.isEmpty
        ? trByLanguageKey(
            language: language,
            key: 'legacy.reminder.default_body',
          )
        : bodyRaw;

    final notification = LocalNotification(
      title: title,
      body: body,
      silent: settings.soundMode == ReminderSoundMode.silent,
    );
    void cleanup() {
      if (!_windowsActiveNotifications.remove(notification)) return;
      unawaited(notification.destroy());
    }

    notification.onClick = () {
      if (DesktopTrayController.instance.supported) {
        unawaited(DesktopTrayController.instance.showFromTray());
      }
      cleanup();
    };
    notification.onClose = (_) => cleanup();
    return notification;
  }

  Future<bool> sendTestNotification() async {
    await initialize();
    if (!_supportsReminderNotifications) return false;
    _logInfo('test_immediate_start');
    final settings = _ref.read(reminderSettingsProvider);

    if (Platform.isWindows) {
      if (!_windowsNotifierReady) return false;
      try {
        final test = _buildWindowsTestNotification(settings);
        await test.show();
        _windowsActiveNotifications.add(test);
        _logInfo('test_immediate_sent', context: {'platform': 'windows'});
        return true;
      } catch (e, st) {
        _logError('test_immediate_failed', error: e, stackTrace: st);
        return false;
      }
    }

    final permissions = await _checkPermissions();
    if (!permissions.notificationsGranted) {
      _logWarn(
        'test_immediate_denied',
        context: {'exactAlarmGranted': permissions.exactAlarmGranted},
      );
      return false;
    }

    final channel = await _ensureChannel(settings);
    final details = NotificationDetails(
      android: _androidDetails(settings, channel),
    );
    final payload = jsonEncode({'test': true});
    final id = _notificationId(
      'test',
      DateTime.now().microsecondsSinceEpoch.toString(),
    );
    try {
      await _plugin.show(
        id,
        settings.notificationTitle,
        settings.notificationBody,
        details,
        payload: payload,
      );
      _logInfo('test_immediate_sent', context: {'id': id});
      return true;
    } catch (e, st) {
      _logError(
        'test_immediate_failed',
        error: e,
        stackTrace: st,
        context: {'id': id},
      );
      return false;
    }
  }

  Future<({bool ok, bool exactUsed, DateTime? scheduledAt, int pendingCount})>
  scheduleTestReminder({Duration delay = const Duration(minutes: 1)}) async {
    await initialize();
    if (!_supportsReminderNotifications) {
      return (ok: false, exactUsed: false, scheduledAt: null, pendingCount: 0);
    }
    _logInfo('test_schedule_start', context: {'delayMs': delay.inMilliseconds});
    final settings = _ref.read(reminderSettingsProvider);

    if (Platform.isWindows) {
      if (!_windowsNotifierReady) {
        return (
          ok: false,
          exactUsed: false,
          scheduledAt: null,
          pendingCount: 0,
        );
      }
      final when = DateTime.now().add(delay);
      _windowsTestReminderTimer?.cancel();
      _windowsTestReminderTimer = Timer(delay, () {
        final test = _buildWindowsTestNotification(settings);
        _windowsActiveNotifications.add(test);
        unawaited(test.show());
      });
      _logInfo(
        'test_schedule_done',
        context: {
          'when': when.toIso8601String(),
          'exactUsed': false,
          'pending': _windowsPendingReminders.length + 1,
          'platform': 'windows',
        },
      );
      return (
        ok: true,
        exactUsed: false,
        scheduledAt: when,
        pendingCount: _windowsPendingReminders.length + 1,
      );
    }

    final permissions = await _checkPermissions();
    if (!permissions.notificationsGranted) {
      _logWarn(
        'test_schedule_denied',
        context: {'exactAlarmGranted': permissions.exactAlarmGranted},
      );
      return (ok: false, exactUsed: false, scheduledAt: null, pendingCount: 0);
    }

    final channel = await _ensureChannel(settings);
    final details = NotificationDetails(
      android: _androidDetails(settings, channel),
    );
    final now = DateTime.now();
    final when = now.add(delay);
    final payload = jsonEncode({'test': true});
    final id = _notificationId('test', when.toIso8601String());
    final exactUsed = await _scheduleZoned(
      id: id,
      title: settings.notificationTitle,
      body: settings.notificationBody,
      when: when,
      details: details,
      payload: payload,
      preferExact: true,
      logTag: 'test',
      logContext: {'id': id},
    );

    final pending = await _plugin.pendingNotificationRequests();
    _logInfo(
      'test_schedule_done',
      context: {
        'when': when.toIso8601String(),
        'exactUsed': exactUsed,
        'pending': pending.length,
      },
    );
    return (
      ok: true,
      exactUsed: exactUsed,
      scheduledAt: when,
      pendingCount: pending.length,
    );
  }

  Future<void> cancelAll() async {
    await initialize();
    if (!_supportsReminderNotifications) return;
    if (Platform.isWindows) {
      await _clearWindowsSchedules();
      _logInfo('cancel_all');
      return;
    }
    await _plugin.cancelAll();
    _logInfo('cancel_all');
  }

  Future<void> dispose() async {
    await _clearWindowsSchedules();
    _tapHandler = null;
  }

  Future<_ReminderPermissionStatus> _checkPermissions() async {
    if (!Platform.isAndroid) {
      return const _ReminderPermissionStatus(
        notificationsGranted: true,
        exactAlarmGranted: true,
      );
    }
    final sdkInt = await _getAndroidSdkInt();
    var notificationsGranted = true;
    var exactAlarmGranted = true;
    bool? canScheduleExact;
    if (sdkInt >= 33) {
      notificationsGranted = await Permission.notification.isGranted;
    }
    if (sdkInt >= 31) {
      exactAlarmGranted = await Permission.scheduleExactAlarm.isGranted;
      canScheduleExact = await SystemSettingsLauncher.canScheduleExactAlarms();
    }
    final context = <String, Object?>{
      'sdk': sdkInt,
      'notificationsGranted': notificationsGranted,
      'exactAlarmGranted': exactAlarmGranted,
      'canScheduleExact': canScheduleExact,
    };
    if (notificationsGranted && exactAlarmGranted) {
      _logInfo('permissions_check', context: context);
    } else {
      _logWarn('permissions_check', context: context);
    }
    return _ReminderPermissionStatus(
      notificationsGranted: notificationsGranted,
      exactAlarmGranted: exactAlarmGranted,
    );
  }

  Future<int> _getAndroidSdkInt() async {
    final cached = _androidSdkInt;
    if (cached != null) return cached;
    final info = await DeviceInfoPlugin().androidInfo;
    _androidSdkInt = info.version.sdkInt;
    return info.version.sdkInt;
  }

  AndroidNotificationDetails _androidDetails(
    ReminderSettings settings,
    AndroidNotificationChannel channel,
  ) {
    AndroidNotificationSound? sound;
    if (settings.soundMode == ReminderSoundMode.custom &&
        settings.soundUri != null) {
      sound = UriAndroidNotificationSound(settings.soundUri!);
    }
    final vibrationPattern = settings.vibrationEnabled
        ? Int64List.fromList(const [0, 280, 160, 280])
        : null;

    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: settings.soundMode != ReminderSoundMode.silent,
      sound: sound,
      enableVibration: settings.vibrationEnabled,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.private,
    );
  }

  Future<AndroidNotificationChannel> _ensureChannel(
    ReminderSettings settings,
  ) async {
    final language = _ref.read(appPreferencesProvider).language;
    final name = trByLanguageKey(
      language: language,
      key: 'legacy.msg_memo_reminders',
    );
    final description = trByLanguageKey(
      language: language,
      key: 'legacy.msg_memoflow_local_reminders',
    );
    final channelId = _channelIdFor(settings);

    AndroidNotificationSound? sound;
    if (settings.soundMode == ReminderSoundMode.custom &&
        settings.soundUri != null) {
      sound = UriAndroidNotificationSound(settings.soundUri!);
    }

    final channel = AndroidNotificationChannel(
      channelId,
      name,
      description: description,
      importance: Importance.high,
      playSound: settings.soundMode != ReminderSoundMode.silent,
      sound: sound,
      enableVibration: settings.vibrationEnabled,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    return channel;
  }

  Future<bool> _scheduleNotification({
    required NotificationDetails details,
    required String memoUid,
    required DateTime when,
    required String key,
    required String title,
    required String body,
  }) async {
    final payload = jsonEncode({'memo_uid': memoUid});
    return _scheduleZoned(
      id: _notificationId(memoUid, key),
      title: title,
      body: body,
      when: when,
      details: details,
      payload: payload,
      preferExact: true,
      logTag: 'memo',
      logContext: {'memo': _memoToken(memoUid), 'key': key},
    );
  }

  Future<bool> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required NotificationDetails details,
    required String payload,
    required bool preferExact,
    String? logTag,
    Map<String, Object?>? logContext,
  }) async {
    final scheduleTime = tz.TZDateTime.from(when, tz.local);
    final context = <String, Object?>{
      'id': id,
      'when': when.toIso8601String(),
      if (logTag != null) 'tag': logTag,
    };
    if (logContext != null) {
      context.addAll(logContext);
    }
    if (!preferExact) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduleTime,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      _logInfo('schedule_inexact', context: context);
      return false;
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduleTime,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      _logInfo('schedule_exact', context: context);
      return true;
    } on PlatformException catch (e, st) {
      _logWarn(
        'schedule_exact_failed',
        error: e,
        stackTrace: st,
        context: context,
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduleTime,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      _logInfo('schedule_inexact_fallback', context: context);
      return false;
    } catch (e, st) {
      _logError('schedule_failed', error: e, stackTrace: st, context: context);
      rethrow;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) {
      _logWarn('tap_empty_payload', context: {'id': response.id});
      return;
    }
    _logInfo(
      'tap_response',
      context: {'id': response.id, 'payloadSize': payload.length},
    );
    unawaited(_handleNotificationTap(payload));
  }

  Future<void> _handleNotificationTap(String payload) async {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        data = decoded.cast<String, dynamic>();
      }
    } catch (e, st) {
      _logWarn('tap_invalid_payload', error: e, stackTrace: st);
    }
    final memoUid = (data?['memo_uid'] as String?)?.trim() ?? '';
    if (memoUid.isEmpty) {
      _logWarn('tap_missing_memo_uid');
      return;
    }
    final memoToken = _memoToken(memoUid);

    final session = _ref.read(appSessionProvider).valueOrNull;
    if (session?.currentAccount == null) {
      _logWarn('tap_no_session', context: {'memo': memoToken});
      return;
    }

    final handler = _tapHandler;
    if (handler == null) {
      _logWarn('tap_missing_handler', context: {'memo': memoToken});
      return;
    }

    final db = _ref.read(databaseProvider);
    final row = await db.getMemoByUid(memoUid);
    if (row == null) {
      _logWarn('tap_memo_missing', context: {'memo': memoToken});
      unawaited(
        handler(
          ReminderTapPayload(
            memoUid: memoUid,
            target: ReminderTapTarget.memosList,
          ),
        ),
      );
      return;
    }

    _logInfo('tap_open_memo', context: {'memo': memoToken});
    final memo = LocalMemo.fromDb(row);
    unawaited(
      handler(
        ReminderTapPayload(
          memoUid: memoUid,
          memo: memo,
          target: ReminderTapTarget.memoDetail,
        ),
      ),
    );
  }

  String _channelIdFor(ReminderSettings settings) {
    final soundKey = settings.soundMode == ReminderSoundMode.silent
        ? 'silent'
        : (settings.soundUri?.trim().isNotEmpty ?? false)
        ? settings.soundUri!.trim()
        : 'default';
    final vibrationKey = settings.vibrationEnabled ? 'vibrate' : 'no_vibrate';
    return 'memo_reminders_${_stableHash('$soundKey|$vibrationKey')}';
  }

  int _notificationId(String memoUid, String key) {
    return _stableHash('$memoUid|$key');
  }

  static String _timeKey(DateTime time) {
    return time.toLocal().toIso8601String();
  }

  static List<DateTime> _dedupeTimes(List<DateTime> times) {
    final seen = <String>{};
    final result = <DateTime>[];
    final sorted = [...times]..sort();
    for (final time in sorted) {
      final key = _timeKey(time);
      if (seen.add(key)) {
        result.add(time);
      }
    }
    return result;
  }

  static bool _sameTimes(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    final aKeys = a.map(_timeKey).toList()..sort();
    final bKeys = b.map(_timeKey).toList()..sort();
    for (var i = 0; i < aKeys.length; i++) {
      if (aKeys[i] != bKeys[i]) return false;
    }
    return true;
  }

  static String _memoToken(String memoUid) {
    return _stableHash(memoUid).toRadixString(16);
  }

  static int _stableHash(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }
    return hash;
  }
}

class _ReminderPermissionStatus {
  const _ReminderPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmGranted,
  });

  final bool notificationsGranted;
  final bool exactAlarmGranted;
}

class _WindowsPendingReminder {
  const _WindowsPendingReminder({
    required this.memoUid,
    required this.when,
    required this.key,
  });

  final String memoUid;
  final DateTime when;
  final String key;
}
