import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app/app_sync_orchestrator.dart';
import '../../core/desktop/shortcuts.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/account.dart';
import '../../data/models/device_preferences.dart';
import '../../data/models/reminder_settings.dart';
import '../../data/models/resolved_app_settings.dart';
import '../system/reminder_scheduler.dart';
import '../system/session_provider.dart';
import 'app_bootstrap_adapter_provider.dart';

class AppBootstrapController {
  AppBootstrapController(this._adapter);

  final AppBootstrapAdapter _adapter;

  ProviderSubscription<AsyncValue<AppSessionState>>? _sessionSubscription;
  ProviderSubscription<DevicePreferences>? _devicePreferencesSubscription;
  ProviderSubscription<ResolvedAppSettings>? _resolvedSettingsSubscription;
  ProviderSubscription<ReminderSettings>? _reminderSettingsSubscription;
  ProviderSubscription<bool>? _debugScreenshotModeSubscription;
  bool _bound = false;

  DateTime? _lastReminderRescheduleAt;
  bool _firstFrameRendered = false;
  bool _reminderRescheduleQueued = false;
  bool _reminderRescheduleForce = false;

  void bind({
    required WidgetRef ref,
    required AppSyncOrchestrator syncOrchestrator,
    required VoidCallback scheduleStatsWidgetUpdate,
    required VoidCallback scheduleShareHandling,
    required Future<void> Function(DevicePreferences prefs) ensureFontLoaded,
    required Future<void> Function(DevicePreferences prefs)
    registerDesktopQuickInputHotKey,
    required Future<void> Function(bool enabled) applyDebugScreenshotMode,
    required ReminderTapHandler reminderTapHandler,
    required VoidCallback scheduleDesktopQuickInputIdlePrewarm,
  }) {
    if (_bound) return;
    _bound = true;

    _sessionSubscription = _adapter.listenSession(ref, (prev, next) {
      _handleSessionChanged(
        ref: ref,
        prev: prev,
        next: next,
        syncOrchestrator: syncOrchestrator,
        scheduleStatsWidgetUpdate: scheduleStatsWidgetUpdate,
        scheduleShareHandling: scheduleShareHandling,
      );
    });

    _devicePreferencesSubscription = _adapter.listenDevicePreferences(ref, (
      prev,
      next,
    ) {
      _handleDevicePreferencesChanged(
        prev: prev,
        next: next,
        scheduleStatsWidgetUpdate: scheduleStatsWidgetUpdate,
        ensureFontLoaded: ensureFontLoaded,
        registerDesktopQuickInputHotKey: registerDesktopQuickInputHotKey,
      );
    });

    _resolvedSettingsSubscription = _adapter.listenResolvedAppSettings(ref, (
      prev,
      next,
    ) {
      _handleResolvedSettingsChanged(
        prev: prev,
        next: next,
        scheduleStatsWidgetUpdate: scheduleStatsWidgetUpdate,
      );
    });

    final reminderScheduler = _adapter.readReminderScheduler(ref);
    final initialDebugScreenshotMode = kDebugMode
        ? _adapter.readDebugScreenshotMode(ref)
        : false;
    final initialDevicePreferences = isDesktopShortcutEnabled()
        ? _adapter.readDevicePreferences(ref)
        : null;

    reminderScheduler.setTapHandler(reminderTapHandler);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFrameRendered = true;
      _flushQueuedReminderReschedule(reminderScheduler);
      unawaited(reminderScheduler.initialize(caller: 'post_first_frame'));
    });

    _reminderSettingsSubscription = _adapter.listenReminderSettings(ref, (
      prev,
      next,
    ) {
      _handleReminderSettingsChanged(
        ref: ref,
        reminderScheduler: reminderScheduler,
      );
    });

    if (kDebugMode) {
      _debugScreenshotModeSubscription = _adapter.listenDebugScreenshotMode(
        ref,
        (prev, next) {
          unawaited(applyDebugScreenshotMode(next));
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(applyDebugScreenshotMode(initialDebugScreenshotMode));
      });
    }

    if (isDesktopShortcutEnabled()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final prefs = initialDevicePreferences;
        if (prefs != null) {
          unawaited(registerDesktopQuickInputHotKey(prefs));
        }
        scheduleDesktopQuickInputIdlePrewarm();
      });
    }
  }

  void dispose() {
    _sessionSubscription?.close();
    _devicePreferencesSubscription?.close();
    _resolvedSettingsSubscription?.close();
    _reminderSettingsSubscription?.close();
    _debugScreenshotModeSubscription?.close();
    _bound = false;
  }

  void rescheduleRemindersIfNeeded({required WidgetRef ref}) {
    final now = DateTime.now();
    final last = _lastReminderRescheduleAt;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastReminderRescheduleAt = now;
    _queueReminderReschedule(
      reminderScheduler: _adapter.readReminderScheduler(ref),
      reason: 'lifecycle_resume',
    );
  }

  void _handleSessionChanged({
    required WidgetRef ref,
    required AsyncValue<AppSessionState>? prev,
    required AsyncValue<AppSessionState> next,
    required AppSyncOrchestrator syncOrchestrator,
    required VoidCallback scheduleStatsWidgetUpdate,
    required VoidCallback scheduleShareHandling,
  }) {
    final prevState = prev?.valueOrNull;
    final nextState = next.valueOrNull;
    final prevKey = prevState?.currentKey;
    final nextKey = nextState?.currentKey;
    final prevAccount = prevState?.currentAccount;
    final nextAccount = nextState?.currentAccount;
    if (kDebugMode) {
      LogManager.instance.info(
        'RouteGate: session_changed',
        context: <String, Object?>{
          'previousKey': prevKey,
          'nextKey': nextKey,
          'hasPreviousAccount': prevAccount != null,
          'hasNextAccount': nextAccount != null,
          'currentLocalLibraryKey': _adapter.readCurrentLocalLibrary(ref)?.key,
        },
      );
    }
    final shouldTriggerPostLoginSync = _didSessionAuthContextChange(
      prevKey: prevKey,
      nextKey: nextKey,
      prevAccount: prevAccount,
      nextAccount: nextAccount,
    );
    final sessionIsStable = next.asData != null && !next.isLoading;
    if (shouldTriggerPostLoginSync && sessionIsStable && nextKey != null) {
      scheduleStatsWidgetUpdate();
      syncOrchestrator.resetResumeCooldown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final latestSession = _adapter.readSession(ref);
        final latestKey = latestSession?.currentKey;
        final latestAccount = latestSession?.currentAccount;
        if (latestKey != nextKey || latestAccount == null) {
          return;
        }
        syncOrchestrator.triggerLifecycleSync(
          isResume: true,
          refreshCurrentUserBeforeSync: false,
          showFeedbackToast: false,
        );
      });
      _queueReminderReschedule(
        reminderScheduler: _adapter.readReminderScheduler(ref),
        force: true,
        reason: 'session_changed',
      );
    }
    if (nextAccount != null) {
      scheduleShareHandling();
    }
  }

  void _handleDevicePreferencesChanged({
    required DevicePreferences? prev,
    required DevicePreferences next,
    required VoidCallback scheduleStatsWidgetUpdate,
    required Future<void> Function(DevicePreferences prefs) ensureFontLoaded,
    required Future<void> Function(DevicePreferences prefs)
    registerDesktopQuickInputHotKey,
  }) {
    if (kDebugMode) {
      final hasOnboardingChanged =
          prev?.hasSelectedLanguage != next.hasSelectedLanguage ||
          prev?.language != next.language;
      if (hasOnboardingChanged) {
        LogManager.instance.info(
          'RouteGate: prefs_changed',
          context: <String, Object?>{
            'previousLanguage': prev?.language.name,
            'nextLanguage': next.language.name,
            'previousHasSelectedLanguage': prev?.hasSelectedLanguage,
            'nextHasSelectedLanguage': next.hasSelectedLanguage,
          },
        );
      }
    }
    if (prev?.fontFamily != next.fontFamily ||
        prev?.fontFile != next.fontFile) {
      unawaited(ensureFontLoaded(next));
    }
    if (isDesktopShortcutEnabled() &&
        prev?.desktopShortcutBindings != next.desktopShortcutBindings) {
      unawaited(registerDesktopQuickInputHotKey(next));
    }
    final shouldRefreshWidgets =
        prev == null ||
        prev.language != next.language ||
        prev.themeColor != next.themeColor ||
        prev.themeMode != next.themeMode ||
        prev.customTheme != next.customTheme;
    if (shouldRefreshWidgets) {
      scheduleStatsWidgetUpdate();
    }
  }

  void _handleResolvedSettingsChanged({
    required ResolvedAppSettings? prev,
    required ResolvedAppSettings next,
    required VoidCallback scheduleStatsWidgetUpdate,
  }) {
    final shouldRefreshWidgets =
        prev == null ||
        prev.workspaceKey != next.workspaceKey ||
        prev.resolvedThemeColor != next.resolvedThemeColor ||
        prev.resolvedCustomTheme != next.resolvedCustomTheme;
    if (shouldRefreshWidgets) {
      scheduleStatsWidgetUpdate();
    }
  }

  void _handleReminderSettingsChanged({
    required WidgetRef ref,
    required ReminderScheduler reminderScheduler,
  }) {
    if (!_adapter.readReminderSettingsLoaded(ref)) return;
    _queueReminderReschedule(
      reminderScheduler: reminderScheduler,
      reason: 'reminder_settings_changed',
    );
  }

  void _queueReminderReschedule({
    required ReminderScheduler reminderScheduler,
    bool force = false,
    String? reason,
  }) {
    if (_firstFrameRendered) {
      unawaited(reminderScheduler.rescheduleAll(force: force, caller: reason));
      return;
    }
    _reminderRescheduleQueued = true;
    if (force) {
      _reminderRescheduleForce = true;
    }
  }

  void _flushQueuedReminderReschedule(ReminderScheduler reminderScheduler) {
    if (!_reminderRescheduleQueued) return;
    final force = _reminderRescheduleForce;
    _reminderRescheduleQueued = false;
    _reminderRescheduleForce = false;
    unawaited(
      reminderScheduler.rescheduleAll(force: force, caller: 'post_first_frame'),
    );
  }

  bool _didSessionAuthContextChange({
    required String? prevKey,
    required String? nextKey,
    required Account? prevAccount,
    required Account? nextAccount,
  }) {
    if (nextKey == null || nextAccount == null) return false;
    if (prevKey != nextKey) return true;
    if (prevAccount == null) return true;
    if (prevAccount.baseUrl.toString() != nextAccount.baseUrl.toString()) {
      return true;
    }
    if (prevAccount.personalAccessToken != nextAccount.personalAccessToken) {
      return true;
    }
    if ((prevAccount.serverVersionOverride ?? '').trim() !=
        (nextAccount.serverVersionOverride ?? '').trim()) {
      return true;
    }
    if (prevAccount.useLegacyApiOverride != nextAccount.useLegacyApiOverride) {
      return true;
    }
    return false;
  }
}
