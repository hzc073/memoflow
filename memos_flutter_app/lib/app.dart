import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter, PointerDeviceKind;

import 'package:crypto/crypto.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'application/app/app_sync_orchestrator.dart';
import 'application/sync/sync_coordinator.dart';
import 'application/sync/sync_request.dart';
import 'core/app_localization.dart';
import 'core/desktop_quick_input_channel.dart';
import 'core/desktop_settings_window.dart';
import 'core/desktop_shortcuts.dart';
import 'core/desktop_tray_controller.dart';
import 'core/app_theme.dart';
import 'core/memoflow_palette.dart';
import 'core/system_fonts.dart';
import 'core/sync_feedback.dart';
import 'core/tags.dart';
import 'core/top_toast.dart';
import 'core/uid.dart';
import 'i18n/strings.g.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/memos/link_memo_sheet.dart';
import 'features/memos/memos_list_screen.dart';
import 'features/memos/note_input_sheet.dart';
import 'features/onboarding/language_selection_screen.dart';
import 'features/review/daily_review_screen.dart';
import 'features/share/share_handler.dart';
import 'features/settings/widgets_service.dart';
import 'features/updates/notice_dialog.dart';
import 'features/updates/update_announcement_dialog.dart';
import 'data/models/account.dart';
import 'data/models/attachment.dart';
import 'data/models/memo_location.dart';
import 'data/logs/log_manager.dart';
import 'data/updates/update_config.dart';
import 'state/database_provider.dart';
import 'state/debug_screenshot_mode_provider.dart';
import 'state/home_loading_overlay_provider.dart';
import 'state/logging_provider.dart';
import 'state/local_library_provider.dart';
import 'state/memos_providers.dart';
import 'state/preferences_provider.dart';
import 'state/reminder_scheduler.dart';
import 'state/reminder_settings_provider.dart';
import 'state/session_provider.dart';
import 'state/update_config_provider.dart';
import 'state/user_settings_provider.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _mainHomePageKey = GlobalKey<_MainHomePageState>();
  HotKey? _desktopQuickInputHotKey;
  WindowController? _desktopQuickInputWindow;
  int? _desktopQuickInputWindowId;
  bool _desktopQuickInputWindowOpening = false;
  Future<void>? _desktopQuickInputWindowPrepareTask;
  final Set<int> _desktopVisibleSubWindowIds = <int>{};
  bool _desktopSubWindowsPrewarmScheduled = false;
  bool _desktopSubWindowVisibilitySyncInProgress = false;
  bool _desktopSubWindowVisibilitySyncQueued = false;
  bool _desktopSubWindowVisibilitySyncScheduled = false;
  DateTime? _lastDesktopSubWindowVisibilitySyncAt;
  static const Duration _desktopSubWindowVisibilitySyncDebounce = Duration(
    milliseconds: 360,
  );
  HomeWidgetType? _pendingWidgetAction;
  SharePayload? _pendingSharePayload;
  bool _shareHandlingScheduled = false;
  bool _launchActionHandled = false;
  bool _launchActionScheduled = false;
  Future<void>? _pendingWidgetActionLoad;
  Future<void>? _pendingShareLoad;
  bool _statsWidgetUpdating = false;
  String? _statsWidgetAccountKey;
  ProviderSubscription<AsyncValue<AppSessionState>>? _sessionSubscription;
  ProviderSubscription<AppPreferences>? _prefsSubscription;
  ProviderSubscription<ReminderSettings>? _reminderSettingsSubscription;
  ProviderSubscription<bool>? _prefsLoadedSubscription;
  ProviderSubscription<bool>? _debugScreenshotModeSubscription;
  late final AppSyncOrchestrator _syncOrchestrator;
  DateTime? _lastReminderRescheduleAt;
  bool _updateAnnouncementChecked = false;
  Future<String?>? _appVersionFuture;
  String? _pendingThemeAccountKey;
  AppLocale? _activeLocale;
  static const UpdateAnnouncementConfig _fallbackUpdateConfig =
      UpdateAnnouncementConfig(
        schemaVersion: 1,
        versionInfo: UpdateVersionInfo(
          latestVersion: '',
          isForce: false,
          downloadUrl: '',
          updateSource: '',
          publishAt: null,
          debugVersion: '',
          skipUpdateVersion: '',
        ),
        announcement: UpdateAnnouncement(
          id: 0,
          title: '',
          showWhenUpToDate: false,
          contentsByLocale: {},
          fallbackContents: [],
          newDonorIds: [],
        ),
        donors: [],
        releaseNotes: [],
        noticeEnabled: false,
        notice: null,
      );

  static const Map<String, String> _imageEditorI18nZh = {
    'Crop': '\u88c1\u526a',
    'Brush': '\u6d82\u9e26',
    'Text': '\u6587\u5b57',
    'Link': '\u94fe\u63a5',
    'Flip': '\u7ffb\u8f6c',
    'Rotate left': '\u5411\u5de6\u65cb\u8f6c',
    'Rotate right': '\u5411\u53f3\u65cb\u8f6c',
    'Blur': '\u6a21\u7cca',
    'Filter': '\u6ee4\u955c',
    'Emoji': '\u8d34\u7eb8',
    'Select Emoji': '\u9009\u62e9\u8d34\u7eb8',
    'Size Adjust': '\u5927\u5c0f\u8c03\u6574',
    'Remove': '\u5220\u9664',
    'Size': '\u5927\u5c0f',
    'Color': '\u989c\u8272',
    'Background Color': '\u80cc\u666f\u989c\u8272',
    'Background Opacity': '\u80cc\u666f\u900f\u660e\u5ea6',
    'Slider Filter Color': '\u6ee4\u955c\u989c\u8272',
    'Slider Color': '\u989c\u8272',
    'Slider Opicity': '\u900f\u660e\u5ea6',
    'Reset': '\u91cd\u7f6e',
    'Blur Radius': '\u6a21\u7cca\u534a\u5f84',
    'Color Opacity': '\u989c\u8272\u900f\u660e\u5ea6',
    'Insert Your Message': '\u8f93\u5165\u6587\u5b57',
    'https://example.com': '\u8f93\u5165\u94fe\u63a5',
  };

  static const Map<String, String> _imageEditorI18nZhHant = {
    'Crop': '\u88c1\u5207',
    'Brush': '\u5857\u9d09',
    'Text': '\u6587\u5b57',
    'Link': '\u9023\u7d50',
    'Flip': '\u7ffb\u8f49',
    'Rotate left': '\u5411\u5de6\u65cb\u8f49',
    'Rotate right': '\u5411\u53f3\u65cb\u8f49',
    'Blur': '\u6a21\u7cca',
    'Filter': '\u6ffe\u93e1',
    'Emoji': '\u8cbc\u7d19',
    'Select Emoji': '\u9078\u64c7\u8cbc\u7d19',
    'Size Adjust': '\u5927\u5c0f\u8abf\u6574',
    'Remove': '\u522a\u9664',
    'Size': '\u5927\u5c0f',
    'Color': '\u984f\u8272',
    'Background Color': '\u80cc\u666f\u984f\u8272',
    'Background Opacity': '\u80cc\u666f\u900f\u660e\u5ea6',
    'Slider Filter Color': '\u6ffe\u93e1\u984f\u8272',
    'Slider Color': '\u984f\u8272',
    'Slider Opicity': '\u900f\u660e\u5ea6',
    'Reset': '\u91cd\u8a2d',
    'Blur Radius': '\u6a21\u7cca\u534a\u5f91',
    'Color Opacity': '\u984f\u8272\u900f\u660e\u5ea6',
    'Insert Your Message': '\u8f38\u5165\u6587\u5b57',
    'https://example.com': '\u8f38\u5165\u9023\u7d50',
  };

  static const Map<String, String> _imageEditorI18nJa = {
    'Crop': '\u30c8\u30ea\u30df\u30f3\u30b0',
    'Brush': '\u30d6\u30e9\u30b7',
    'Text': '\u30c6\u30ad\u30b9\u30c8',
    'Link': '\u30ea\u30f3\u30af',
    'Flip': '\u53cd\u8ee2',
    'Rotate left': '\u5de6\u306b\u56de\u8ee2',
    'Rotate right': '\u53f3\u306b\u56de\u8ee2',
    'Blur': '\u307c\u304b\u3057',
    'Filter': '\u30d5\u30a3\u30eb\u30bf\u30fc',
    'Emoji': '\u7d75\u6587\u5b57',
    'Select Emoji': '\u7d75\u6587\u5b57\u3092\u9078\u629e',
    'Size Adjust': '\u30b5\u30a4\u30ba\u8abf\u6574',
    'Remove': '\u524a\u9664',
    'Size': '\u30b5\u30a4\u30ba',
    'Color': '\u8272',
    'Background Color': '\u80cc\u666f\u8272',
    'Background Opacity': '\u80cc\u666f\u306e\u900f\u660e\u5ea6',
    'Slider Filter Color': '\u30d5\u30a3\u30eb\u30bf\u30fc\u8272',
    'Slider Color': '\u8272',
    'Slider Opicity': '\u900f\u660e\u5ea6',
    'Reset': '\u30ea\u30bb\u30c3\u30c8',
    'Blur Radius': '\u307c\u304b\u3057\u534a\u5f84',
    'Color Opacity': '\u8272\u306e\u900f\u660e\u5ea6',
    'Insert Your Message': '\u30c6\u30ad\u30b9\u30c8\u3092\u5165\u529b',
    'https://example.com': '\u30ea\u30f3\u30af\u3092\u5165\u529b',
  };

  static const Map<String, String> _imageEditorI18nDe = {
    'Crop': 'Zuschneiden',
    'Brush': 'Pinsel',
    'Text': 'Text',
    'Link': 'Link',
    'Flip': 'Spiegeln',
    'Rotate left': 'Nach links drehen',
    'Rotate right': 'Nach rechts drehen',
    'Blur': 'Weichzeichnen',
    'Filter': 'Filter',
    'Emoji': 'Emoji',
    'Select Emoji': 'Emoji ausw\u00e4hlen',
    'Size Adjust': 'Gr\u00f6\u00dfe anpassen',
    'Remove': 'Entfernen',
    'Size': 'Gr\u00f6\u00dfe',
    'Color': 'Farbe',
    'Background Color': 'Hintergrundfarbe',
    'Background Opacity': 'Hintergrundtransparenz',
    'Slider Filter Color': 'Filterfarbe',
    'Slider Color': 'Farbe',
    'Slider Opicity': 'Transparenz',
    'Reset': 'Zur\u00fccksetzen',
    'Blur Radius': 'Weichzeichnungsradius',
    'Color Opacity': 'Farbtransparenz',
    'Insert Your Message': 'Text eingeben',
    'https://example.com': 'Link eingeben',
  };

  static const Map<String, String> _imageEditorI18nEn = {
    'Crop': 'Crop',
    'Brush': 'Brush',
    'Text': 'Text',
    'Link': 'Link',
    'Flip': 'Flip',
    'Rotate left': 'Rotate left',
    'Rotate right': 'Rotate right',
    'Blur': 'Blur',
    'Filter': 'Filter',
    'Emoji': 'Emoji',
    'Select Emoji': 'Select Emoji',
    'Size Adjust': 'Size Adjust',
    'Remove': 'Remove',
    'Size': 'Size',
    'Color': 'Color',
    'Background Color': 'Background Color',
    'Background Opacity': 'Background Opacity',
    'Slider Filter Color': 'Slider Filter Color',
    'Slider Color': 'Slider Color',
    'Slider Opicity': 'Slider Opicity',
    'Reset': 'Reset',
    'Blur Radius': 'Blur Radius',
    'Color Opacity': 'Color Opacity',
    'Insert Your Message': 'Insert Your Message',
    'https://example.com': 'https://example.com',
  };

  static void _applyImageEditorI18n(AppLanguage language) {
    final effective = language == AppLanguage.system
        ? appLanguageFromLocale(
            WidgetsBinding.instance.platformDispatcher.locale,
          )
        : language;
    final map = switch (effective) {
      AppLanguage.zhHans => _imageEditorI18nZh,
      AppLanguage.zhHantTw => _imageEditorI18nZhHant,
      AppLanguage.ja => _imageEditorI18nJa,
      AppLanguage.de => _imageEditorI18nDe,
      _ => _imageEditorI18nEn,
    };
    ImageEditor.setI18n(map);
  }

  static bool _isTraditionalZhLocale(Locale locale) {
    if (locale.languageCode.toLowerCase() != 'zh') return false;
    final script = locale.scriptCode?.toLowerCase();
    if (script == 'hant') return true;
    final region = locale.countryCode?.toUpperCase();
    return region == 'TW' || region == 'HK' || region == 'MO';
  }

  static AppLocale _deviceLocaleToAppLocale(Locale locale) {
    return switch (locale.languageCode.toLowerCase()) {
      'zh' =>
        _isTraditionalZhLocale(locale) ? AppLocale.zhHantTw : AppLocale.zhHans,
      'ja' => AppLocale.ja,
      'de' => AppLocale.de,
      _ => AppLocale.en,
    };
  }

  static AppLocale _appLocaleFor(AppLanguage language) {
    return switch (language) {
      AppLanguage.system => _deviceLocaleToAppLocale(
        WidgetsBinding.instance.platformDispatcher.locale,
      ),
      AppLanguage.zhHans => AppLocale.zhHans,
      AppLanguage.zhHantTw => AppLocale.zhHantTw,
      AppLanguage.en => AppLocale.en,
      AppLanguage.ja => AppLocale.ja,
      AppLanguage.de => AppLocale.de,
    };
  }

  static double _textScaleFor(AppFontSize v) {
    return switch (v) {
      AppFontSize.standard => 1.0,
      AppFontSize.large => 1.12,
      AppFontSize.small => 0.92,
    };
  }

  static double _lineHeightFor(AppLineHeight v) {
    return switch (v) {
      AppLineHeight.classic => 1.55,
      AppLineHeight.compact => 1.35,
      AppLineHeight.relaxed => 1.75,
    };
  }

  static ThemeMode _themeModeFor(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }

  static TextTheme _applyLineHeight(TextTheme theme, double height) {
    TextStyle? apply(TextStyle? style) => style?.copyWith(height: height);
    return theme.copyWith(
      bodyLarge: apply(theme.bodyLarge),
      bodyMedium: apply(theme.bodyMedium),
      bodySmall: apply(theme.bodySmall),
      titleLarge: apply(theme.titleLarge),
      titleMedium: apply(theme.titleMedium),
      titleSmall: apply(theme.titleSmall),
    );
  }

  static TextTheme _applyFontFamily(
    TextTheme theme, {
    String? family,
    List<String>? fallback,
  }) {
    if (family == null && (fallback == null || fallback.isEmpty)) return theme;
    return theme.apply(fontFamily: family, fontFamilyFallback: fallback);
  }

  static ThemeData _applyPreferencesToTheme(
    ThemeData theme,
    AppPreferences prefs,
  ) {
    final lineHeight = _lineHeightFor(prefs.lineHeight);
    final textTheme = _applyLineHeight(
      _applyFontFamily(
        theme.textTheme,
        family: prefs.fontFamily,
        fallback: null,
      ),
      lineHeight,
    );
    final primaryTextTheme = _applyLineHeight(
      _applyFontFamily(
        theme.primaryTextTheme,
        family: prefs.fontFamily,
        fallback: null,
      ),
      lineHeight,
    );

    return theme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
    );
  }

  Future<void> _ensureFontLoaded(AppPreferences prefs) async {
    final family = prefs.fontFamily;
    final filePath = prefs.fontFile;
    if (family == null || family.trim().isEmpty) return;
    if (filePath == null || filePath.trim().isEmpty) return;
    final loaded = await SystemFonts.ensureLoaded(
      SystemFontInfo(family: family, displayName: family, filePath: filePath),
    );
    if (loaded && mounted) {
      setState(() {});
    }
  }

  Future<void> _applyDebugScreenshotMode(bool enabled) async {
    if (!kDebugMode) return;
    try {
      if (enabled) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: const <SystemUiOverlay>[],
        );
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindDesktopMultiWindowHandler();
    setDesktopSettingsWindowVisibilityListener(({
      required int windowId,
      required bool visible,
    }) {
      _setDesktopSubWindowVisibility(windowId: windowId, visible: visible);
    });
    ref.read(logManagerProvider);
    _syncOrchestrator = AppSyncOrchestrator(
      ref: ref,
      updateStatsWidgetIfNeeded:
          ({required bool force}) => _updateStatsWidgetIfNeeded(force: force),
      showFeedbackToast: ({required bool succeeded}) =>
          _showAutoSyncFeedbackToast(succeeded: succeeded),
      showProgressToast: _showAutoSyncProgressToast,
    );
    HomeWidgetService.setLaunchHandler(_handleWidgetLaunch);
    _pendingWidgetActionLoad = _loadPendingWidgetAction();
    ShareHandlerService.setShareHandler(_handleShareLaunch);
    _pendingShareLoad = _loadPendingShare();
    _sessionSubscription = ref.listenManual<AsyncValue<AppSessionState>>(
      appSessionProvider,
      (prev, next) {
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
              'currentLocalLibraryKey': ref
                  .read(currentLocalLibraryProvider)
                  ?.key,
            },
          );
        }
        final shouldTriggerPostLoginSync = _didSessionAuthContextChange(
          prevKey: prevKey,
          nextKey: nextKey,
          prevAccount: prevAccount,
          nextAccount: nextAccount,
        );
        if (shouldTriggerPostLoginSync) {
          _scheduleStatsWidgetUpdate();
          _syncOrchestrator.resetResumeCooldown();
          _syncOrchestrator.triggerLifecycleSync(
            isResume: true,
            refreshCurrentUserBeforeSync: false,
            showFeedbackToast: false,
          );
          unawaited(
            ref.read(reminderSchedulerProvider).rescheduleAll(force: true),
          );
        }
        if (nextKey != null) {
          if (ref.read(appPreferencesLoadedProvider)) {
            ref
                .read(appPreferencesProvider.notifier)
                .ensureAccountThemeDefaults(nextKey);
          } else {
            _pendingThemeAccountKey = nextKey;
          }
        }
        if (nextAccount != null) {
          _scheduleShareHandling();
        }
      },
    );
    _prefsSubscription = ref.listenManual<AppPreferences>(
      appPreferencesProvider,
      (prev, next) {
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
          unawaited(_ensureFontLoaded(next));
        }
        if (isDesktopShortcutEnabled() &&
            prev?.desktopShortcutBindings != next.desktopShortcutBindings) {
          unawaited(_registerDesktopQuickInputHotKey(next));
        }
      },
    );
    _prefsLoadedSubscription = ref.listenManual<bool>(
      appPreferencesLoadedProvider,
      (prev, next) {
        if (kDebugMode) {
          LogManager.instance.info(
            'RouteGate: prefs_loaded_changed',
            context: <String, Object?>{
              'previous': prev,
              'next': next,
              'sessionKey': ref
                  .read(appSessionProvider)
                  .valueOrNull
                  ?.currentKey,
              'hasSelectedLanguage': ref
                  .read(appPreferencesProvider)
                  .hasSelectedLanguage,
            },
          );
        }
        if (!next) return;
        final key =
            _pendingThemeAccountKey ??
            ref.read(appSessionProvider).valueOrNull?.currentKey;
        if (key != null) {
          ref
              .read(appPreferencesProvider.notifier)
              .ensureAccountThemeDefaults(key);
        }
        _pendingThemeAccountKey = null;
      },
    );
    final reminderScheduler = ref.read(reminderSchedulerProvider);
    reminderScheduler.bindNavigator(_navigatorKey);
    unawaited(reminderScheduler.initialize());
    _reminderSettingsSubscription = ref.listenManual<ReminderSettings>(
      reminderSettingsProvider,
      (prev, next) {
        if (!ref.read(reminderSettingsLoadedProvider)) return;
        unawaited(reminderScheduler.rescheduleAll());
      },
    );
    if (kDebugMode) {
      _debugScreenshotModeSubscription = ref.listenManual<bool>(
        debugScreenshotModeProvider,
        (prev, next) {
          unawaited(_applyDebugScreenshotMode(next));
        },
      );
      unawaited(
        _applyDebugScreenshotMode(ref.read(debugScreenshotModeProvider)),
      );
    }
    if (isDesktopShortcutEnabled()) {
      unawaited(
        _registerDesktopQuickInputHotKey(ref.read(appPreferencesProvider)),
      );
      _scheduleDesktopSubWindowPrewarm();
    }
    if (DesktopTrayController.instance.supported) {
      DesktopTrayController.instance.configureActions(
        onOpenSettings: _handleOpenSettingsFromTray,
        onNewMemo: _handleCreateMemoFromTray,
      );
    }
    _scheduleStatsWidgetUpdate();
  }

  void _bindDesktopMultiWindowHandler() {
    if (kIsWeb) return;
    DesktopMultiWindow.setMethodHandler(_handleDesktopMultiWindowMethodCall);
  }

  bool get _shouldBlurDesktopMainWindow {
    if (_desktopVisibleSubWindowIds.isEmpty || kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  bool? _parseDesktopSubWindowVisibleFlag(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  void _setDesktopSubWindowVisibility({
    required int windowId,
    required bool visible,
  }) {
    if (windowId <= 0) return;
    final changed = visible
        ? _desktopVisibleSubWindowIds.add(windowId)
        : _desktopVisibleSubWindowIds.remove(windowId);
    if (!changed || !mounted) return;
    setState(() {});
  }

  void _scheduleDesktopSubWindowVisibilitySync({bool force = false}) {
    if (kIsWeb || _desktopVisibleSubWindowIds.isEmpty) return;
    if (!force) {
      final last = _lastDesktopSubWindowVisibilitySyncAt;
      if (last != null &&
          DateTime.now().difference(last) <
              _desktopSubWindowVisibilitySyncDebounce) {
        return;
      }
    }
    if (_desktopSubWindowVisibilitySyncScheduled) return;
    _desktopSubWindowVisibilitySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopSubWindowVisibilitySyncScheduled = false;
      unawaited(_syncDesktopSubWindowVisibility());
    });
  }

  Future<void> _syncDesktopSubWindowVisibility() async {
    if (kIsWeb || _desktopVisibleSubWindowIds.isEmpty) return;
    if (_desktopSubWindowVisibilitySyncInProgress) {
      _desktopSubWindowVisibilitySyncQueued = true;
      return;
    }
    _desktopSubWindowVisibilitySyncInProgress = true;
    _lastDesktopSubWindowVisibilitySyncAt = DateTime.now();
    try {
      final trackedIds = _desktopVisibleSubWindowIds.toSet();
      final nextVisibleIds = <int>{};
      Set<int>? existingIds;
      try {
        existingIds = (await DesktopMultiWindow.getAllSubWindowIds())
            .where((id) => id > 0)
            .toSet();
      } catch (_) {}

      for (final id in trackedIds) {
        if (existingIds != null && !existingIds.contains(id)) {
          continue;
        }
        final visible = await _queryDesktopSubWindowVisible(id);
        if (visible == true) {
          nextVisibleIds.add(id);
          continue;
        }
        if (visible == null && await _isDesktopSubWindowResponsive(id)) {
          nextVisibleIds.add(id);
        }
      }

      if (!mounted || setEquals(nextVisibleIds, _desktopVisibleSubWindowIds)) {
        return;
      }
      setState(() {
        _desktopVisibleSubWindowIds
          ..clear()
          ..addAll(nextVisibleIds);
      });
    } finally {
      _desktopSubWindowVisibilitySyncInProgress = false;
      if (_desktopSubWindowVisibilitySyncQueued) {
        _desktopSubWindowVisibilitySyncQueued = false;
        unawaited(_syncDesktopSubWindowVisibility());
      }
    }
  }

  Future<bool?> _queryDesktopSubWindowVisible(int windowId) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSubWindowIsVisibleMethod,
        null,
      );
      return _parseDesktopSubWindowVisibleFlag(result);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isDesktopSubWindowResponsive(int windowId) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsPingMethod,
        null,
      );
      if (result == null || result == true) {
        return true;
      }
    } catch (_) {}
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputPingMethod,
        null,
      );
      return result == null || result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _focusDesktopSubWindowById(int windowId) async {
    try {
      await WindowController.fromWindowId(windowId).show();
    } catch (_) {}

    if (_desktopQuickInputWindowId == windowId) {
      try {
        await DesktopMultiWindow.invokeMethod(
          windowId,
          desktopQuickInputFocusMethod,
          null,
        );
        return true;
      } catch (_) {}
      try {
        await DesktopMultiWindow.invokeMethod(
          windowId,
          desktopSettingsFocusMethod,
          null,
        );
        return true;
      } catch (_) {}
      return false;
    }

    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopSettingsFocusMethod,
        null,
      );
      return true;
    } catch (_) {}
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputFocusMethod,
        null,
      );
      return true;
    } catch (_) {}
    return false;
  }

  Future<void> _focusVisibleDesktopSubWindow() async {
    if (!_shouldBlurDesktopMainWindow || _desktopVisibleSubWindowIds.isEmpty) {
      return;
    }
    final candidateIds = _desktopVisibleSubWindowIds.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    for (final id in candidateIds) {
      final focused = await _focusDesktopSubWindowById(id);
      if (focused) return;
      _setDesktopSubWindowVisibility(windowId: id, visible: false);
    }
  }

  BuildContext? _resolveDesktopUiContext() {
    final direct = _navigatorKey.currentContext;
    if (direct != null && direct.mounted) return direct;
    final overlay = _navigatorKey.currentState?.overlay?.context;
    if (overlay != null && overlay.mounted) return overlay;
    return null;
  }

  void _scheduleDesktopSubWindowPrewarm() {
    if (!isDesktopShortcutEnabled() || _desktopSubWindowsPrewarmScheduled) {
      return;
    }
    _desktopSubWindowsPrewarmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prewarmDesktopSubWindows());
    });
  }

  Future<void> _prewarmDesktopSubWindows() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted || !isDesktopShortcutEnabled()) return;
    _bindDesktopMultiWindowHandler();
    try {
      await _ensureDesktopQuickInputWindowReady();
    } catch (error, stackTrace) {
      ref
          .read(logManagerProvider)
          .warn(
            'Desktop sub-window prewarm failed',
            error: error,
            stackTrace: stackTrace,
          );
    }
    prewarmDesktopSettingsWindowIfSupported();
  }

  Future<void> _registerDesktopQuickInputHotKey(AppPreferences prefs) async {
    if (!isDesktopShortcutEnabled()) return;
    final bindings = normalizeDesktopShortcutBindings(
      prefs.desktopShortcutBindings,
    );
    final binding = bindings[DesktopShortcutAction.quickRecord];
    if (binding == null) return;

    final nextHotKey = HotKey(
      key: binding.logicalKey,
      modifiers: <HotKeyModifier>[
        if (binding.primary)
          defaultTargetPlatform == TargetPlatform.macOS
              ? HotKeyModifier.meta
              : HotKeyModifier.control,
        if (binding.shift) HotKeyModifier.shift,
        if (binding.alt) HotKeyModifier.alt,
      ],
      scope: HotKeyScope.system,
    );

    final previous = _desktopQuickInputHotKey;
    if (previous != null) {
      try {
        await hotKeyManager.unregister(previous);
      } catch (_) {}
    }

    try {
      await hotKeyManager.register(
        nextHotKey,
        keyDownHandler: (_) {
          ref
              .read(logManagerProvider)
              .info(
                'Desktop shortcut matched',
                context: const <String, Object?>{
                  'action': 'quickRecord',
                  'source': 'system_hotkey',
                },
              );
          unawaited(_handleDesktopQuickInputHotKey());
        },
      );
      _desktopQuickInputHotKey = nextHotKey;
    } catch (error, stackTrace) {
      ref
          .read(logManagerProvider)
          .error(
            'Register desktop quick input hotkey failed',
            error: error,
            stackTrace: stackTrace,
          );
    }
  }

  Future<void> _unregisterDesktopQuickInputHotKey() async {
    final hotKey = _desktopQuickInputHotKey;
    if (hotKey == null) return;
    try {
      await hotKeyManager.unregister(hotKey);
    } catch (_) {}
    _desktopQuickInputHotKey = null;
  }

  Future<dynamic> _handleDesktopMultiWindowMethodCall(
    MethodCall call,
    int fromWindowId,
  ) async {
    if (!mounted) return null;
    switch (call.method) {
      case desktopQuickInputSubmitMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final contentRaw = map == null ? null : map['content'];
        final content = (contentRaw as String? ?? '').trimRight();
        final attachmentPayloads = _parseDesktopQuickInputMapList(
          map == null ? null : map['attachments'],
        );
        final relations = _parseDesktopQuickInputMapList(
          map == null ? null : map['relations'],
        );
        final location = _parseDesktopQuickInputLocation(
          map == null ? null : map['location'],
        );
        if (content.trim().isEmpty && attachmentPayloads.isEmpty) return false;
        try {
          await _submitDesktopQuickInput(
            content,
            attachmentPayloads: attachmentPayloads,
            location: location,
            relations: relations,
          );
          if (!mounted) return true;
          final context = _resolveDesktopUiContext();
          if (context?.mounted == true) {
            showTopToast(context!, '已保存到 MemoFlow');
          }
          return true;
        } catch (error, stackTrace) {
          ref
              .read(logManagerProvider)
              .error(
                'Desktop quick input submit from sub-window failed',
                error: error,
                stackTrace: stackTrace,
              );
          if (!mounted) return false;
          final context = _resolveDesktopUiContext();
          if (context?.mounted == true) {
            showTopToast(context!, '快速输入失败：$error');
          }
          return false;
        }
      case desktopQuickInputPlaceholderMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final labelRaw = map == null ? null : map['label'];
        final label = (labelRaw as String? ?? '\u529f\u80fd').trim();
        final context = _resolveDesktopUiContext();
        if (context != null) {
          showTopToast(
            context,
            '\u300c$label\u300d\u529f\u80fd\u6682\u672a\u5b9e\u73b0\uff08\u5360\u4f4d\uff09\u3002',
          );
        }
        return true;
      case desktopQuickInputPickLinkMemoMethod:
        if (_resolveDesktopUiContext() == null) {
          await DesktopTrayController.instance.showFromTray();
          await Future<void>.delayed(const Duration(milliseconds: 160));
        }
        final context = _resolveDesktopUiContext();
        if (context == null) {
          return {'error_message': 'main_window_not_ready'};
        }
        if (!context.mounted) {
          return {'error_message': 'main_window_not_ready'};
        }
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final rawNames = map == null ? null : map['existingNames'];
        final existingNames = <String>{};
        if (rawNames is List) {
          for (final item in rawNames) {
            final value = (item as String? ?? '').trim();
            if (value.isNotEmpty) existingNames.add(value);
          }
        }
        final selection = await LinkMemoSheet.show(
          context,
          existingNames: existingNames,
        );
        if (!mounted || selection == null) return null;
        final name = selection.name.trim();
        if (name.isEmpty) return null;
        final raw = selection.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        final fallback = name.startsWith('memos/')
            ? name.substring('memos/'.length)
            : name;
        final label = _truncateDesktopQuickInputLabel(
          raw.isNotEmpty ? raw : fallback,
        );
        return {'name': name, 'label': label};
      case desktopQuickInputListTagsMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final rawExisting = map == null ? null : map['existingTags'];
        final existing = <String>{};
        if (rawExisting is List) {
          for (final item in rawExisting) {
            final text = (item as String? ?? '').trim().toLowerCase();
            if (text.isEmpty) continue;
            final normalized = text.startsWith('#') ? text.substring(1) : text;
            if (normalized.isNotEmpty) {
              existing.add(normalized);
            }
          }
        }
        try {
          final stats = await ref.read(tagStatsProvider.future);
          final tags = <String>[];
          for (final stat in stats) {
            final tag = stat.tag.trim();
            if (tag.isEmpty) continue;
            if (existing.contains(tag.toLowerCase())) continue;
            tags.add(tag);
          }
          return tags;
        } catch (_) {
          return const <String>[];
        }
      case desktopSubWindowVisibilityMethod:
        final args = call.arguments;
        final map = args is Map ? args.cast<Object?, Object?>() : null;
        final visible = _parseDesktopSubWindowVisibleFlag(
          map == null ? null : map['visible'],
        );
        _setDesktopSubWindowVisibility(
          windowId: fromWindowId,
          visible: visible ?? true,
        );
        return true;
      case desktopSettingsReopenOnboardingMethod:
        try {
          await ref.read(appSessionProvider.notifier).reloadFromStorage();
        } catch (_) {}
        try {
          await ref.read(localLibrariesProvider.notifier).reloadFromStorage();
        } catch (_) {}
        final session = ref.read(appSessionProvider).valueOrNull;
        if (session?.currentAccount == null && session?.currentKey != null) {
          try {
            await ref.read(appSessionProvider.notifier).setCurrentKey(null);
          } catch (_) {}
        }
        ref.read(appPreferencesProvider.notifier).setHasSelectedLanguage(false);
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil('/', (route) => false);
        }
        return true;
      case desktopHomeShowLoadingOverlayMethod:
        ref.read(homeLoadingOverlayForceProvider.notifier).state = true;
        return true;
      case desktopQuickInputPingMethod:
        return true;
      case desktopQuickInputClosedMethod:
        _setDesktopSubWindowVisibility(windowId: fromWindowId, visible: false);
        if (_desktopQuickInputWindowId == fromWindowId) {
          _desktopQuickInputWindow = null;
          _desktopQuickInputWindowId = null;
        }
        return true;
      default:
        return null;
    }
  }

  Future<void> _handleOpenSettingsFromTray() async {
    if (!mounted) return;
    final context = _resolveDesktopUiContext();
    openDesktopSettingsWindowIfSupported(feedbackContext: context);
  }

  Future<void> _handleCreateMemoFromTray() async {
    if (!mounted) return;
    if (isDesktopShortcutEnabled()) {
      await _handleDesktopQuickInputHotKey();
      return;
    }
    final prefs = ref.read(appPreferencesProvider);
    _openQuickInput(autoFocus: prefs.quickInputAutoFocus);
  }

  Future<void> _handleDesktopQuickInputHotKey() async {
    if (!mounted || !isDesktopShortcutEnabled()) return;
    if (_desktopQuickInputWindowOpening) return;
    _bindDesktopMultiWindowHandler();

    final session = ref.read(appSessionProvider).valueOrNull;
    final localLibrary = ref.read(currentLocalLibraryProvider);
    if (session?.currentAccount == null && localLibrary == null) {
      await DesktopTrayController.instance.showFromTray();
      return;
    }

    _desktopQuickInputWindowOpening = true;
    try {
      var window = await _ensureDesktopQuickInputWindowReady();
      try {
        await window.show();
        _setDesktopSubWindowVisibility(
          windowId: window.windowId,
          visible: true,
        );
        await _focusDesktopQuickInputWindow(window.windowId);
      } catch (_) {
        // The cached controller can be stale after user closed sub-window.
        _desktopQuickInputWindow = null;
        _desktopQuickInputWindowId = null;
        window = await _ensureDesktopQuickInputWindowReady();
        await window.show();
        _setDesktopSubWindowVisibility(
          windowId: window.windowId,
          visible: true,
        );
        await _focusDesktopQuickInputWindow(window.windowId);
      }
    } catch (error, stackTrace) {
      ref
          .read(logManagerProvider)
          .error(
            'Desktop quick input hotkey action failed',
            error: error,
            stackTrace: stackTrace,
          );
      if (!mounted) return;
      final context = _resolveDesktopUiContext();
      if (context?.mounted == true) {
        showTopToast(context!, '快速输入失败：$error');
      }
    } finally {
      _desktopQuickInputWindowOpening = false;
    }
  }

  Future<WindowController> _ensureDesktopQuickInputWindowReady() async {
    await _refreshDesktopQuickInputWindowReference();
    final existing = _desktopQuickInputWindow;
    if (existing != null) return existing;

    final pending = _desktopQuickInputWindowPrepareTask;
    if (pending != null) {
      await pending;
      await _refreshDesktopQuickInputWindowReference();
      final prepared = _desktopQuickInputWindow;
      if (prepared != null) return prepared;
    }

    final completer = Completer<void>();
    _desktopQuickInputWindowPrepareTask = completer.future;
    try {
      await _refreshDesktopQuickInputWindowReference();
      final refreshed = _desktopQuickInputWindow;
      if (refreshed != null) return refreshed;

      final window = await DesktopMultiWindow.createWindow(
        jsonEncode(<String, dynamic>{
          desktopWindowTypeKey: desktopWindowTypeQuickInput,
        }),
      );
      _desktopQuickInputWindow = window;
      _desktopQuickInputWindowId = window.windowId;
      await window.setTitle('MemoFlow');
      await window.setFrame(const Offset(0, 0) & Size(420, 760));
      await window.center();
      return window;
    } finally {
      completer.complete();
      if (identical(_desktopQuickInputWindowPrepareTask, completer.future)) {
        _desktopQuickInputWindowPrepareTask = null;
      }
    }
  }

  Future<void> _refreshDesktopQuickInputWindowReference() async {
    final trackedId = _desktopQuickInputWindowId;
    if (trackedId == null) {
      _desktopQuickInputWindow = null;
      return;
    }
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      if (!ids.contains(trackedId)) {
        _setDesktopSubWindowVisibility(windowId: trackedId, visible: false);
        _desktopQuickInputWindow = null;
        _desktopQuickInputWindowId = null;
        return;
      }
      _desktopQuickInputWindow ??= WindowController.fromWindowId(trackedId);
    } catch (_) {
      _setDesktopSubWindowVisibility(windowId: trackedId, visible: false);
      _desktopQuickInputWindow = null;
      _desktopQuickInputWindowId = null;
    }
  }

  Future<void> _focusDesktopQuickInputWindow(int windowId) async {
    try {
      await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopQuickInputFocusMethod,
        null,
      );
    } catch (_) {}
  }

  String _resolveDesktopQuickInputVisibility() {
    final settings = ref.read(userGeneralSettingProvider).valueOrNull;
    final value = (settings?.memoVisibility ?? '').trim().toUpperCase();
    if (value == 'PUBLIC' || value == 'PROTECTED' || value == 'PRIVATE') {
      return value;
    }
    return 'PRIVATE';
  }

  List<Map<String, dynamic>> _parseDesktopQuickInputMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    final list = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = <String, dynamic>{};
      item.forEach((key, value) {
        final normalizedKey = key?.toString().trim() ?? '';
        if (normalizedKey.isEmpty) return;
        map[normalizedKey] = value;
      });
      if (map.isNotEmpty) {
        list.add(map);
      }
    }
    return list;
  }

  MemoLocation? _parseDesktopQuickInputLocation(dynamic raw) {
    if (raw is! Map) return null;
    final map = <String, dynamic>{};
    raw.forEach((key, value) {
      final normalizedKey = key?.toString().trim() ?? '';
      if (normalizedKey.isEmpty) return;
      map[normalizedKey] = value;
    });
    return MemoLocation.fromJson(map);
  }

  String _truncateDesktopQuickInputLabel(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  int _readDesktopQuickInputInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Future<void> _submitDesktopQuickInput(
    String rawContent, {
    List<Map<String, dynamic>> attachmentPayloads =
        const <Map<String, dynamic>>[],
    MemoLocation? location,
    List<Map<String, dynamic>> relations = const <Map<String, dynamic>>[],
  }) async {
    final content = rawContent.trimRight();
    if (content.trim().isEmpty && attachmentPayloads.isEmpty) return;

    final now = DateTime.now();
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final uid = generateUid();
    final visibility = _resolveDesktopQuickInputVisibility();
    final db = ref.read(databaseProvider);
    final tags = extractTags(content);
    final attachments = <Map<String, dynamic>>[];
    final uploadPayloads = <Map<String, dynamic>>[];
    for (final payload in attachmentPayloads) {
      final rawUid = (payload['uid'] as String? ?? '').trim();
      final filePath = (payload['file_path'] as String? ?? '').trim();
      final filename = (payload['filename'] as String? ?? '').trim();
      final mimeType = (payload['mime_type'] as String? ?? '').trim();
      final fileSize = _readDesktopQuickInputInt(payload['file_size']);
      if (filePath.isEmpty || filename.isEmpty) continue;
      final attachmentUid = rawUid.isEmpty ? generateUid() : rawUid;
      final externalLink = filePath.startsWith('content://')
          ? filePath
          : Uri.file(filePath).toString();
      attachments.add(
        Attachment(
          name: 'attachments/$attachmentUid',
          filename: filename,
          type: mimeType.isEmpty ? 'application/octet-stream' : mimeType,
          size: fileSize,
          externalLink: externalLink,
        ).toJson(),
      );
      uploadPayloads.add({
        'uid': attachmentUid,
        'memo_uid': uid,
        'file_path': filePath,
        'filename': filename,
        'mime_type': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        'file_size': fileSize,
      });
    }
    final normalizedRelations = relations
        .where((relation) => relation.isNotEmpty)
        .toList(growable: false);
    final hasAttachments = attachments.isNotEmpty;

    await db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: false,
      state: 'NORMAL',
      createTimeSec: nowSec,
      updateTimeSec: nowSec,
      tags: tags,
      attachments: attachments,
      location: location,
      relationCount: 0,
      syncState: 1,
    );

    await db.enqueueOutbox(
      type: 'create_memo',
      payload: {
        'uid': uid,
        'content': content,
        'visibility': visibility,
        'pinned': false,
        'has_attachments': hasAttachments,
        if (location != null) 'location': location.toJson(),
        if (normalizedRelations.isNotEmpty) 'relations': normalizedRelations,
      },
    );

    for (final payload in uploadPayloads) {
      await db.enqueueOutbox(type: 'upload_attachment', payload: payload);
    }

    unawaited(
      ref.read(syncCoordinatorProvider.notifier).requestSync(
            const SyncRequest(
              kind: SyncRequestKind.memos,
              reason: SyncRequestReason.manual,
            ),
          ),
    );
  }

  Future<void> _loadPendingWidgetAction() async {
    final type = await HomeWidgetService.consumePendingAction();
    if (!mounted || type == null) return;
    _pendingWidgetAction = type;
    _scheduleWidgetHandling();
  }

  Future<void> _loadPendingShare() async {
    final payload = await ShareHandlerService.consumePendingShare();
    if (!mounted || payload == null) return;
    _pendingSharePayload = payload;
    _scheduleShareHandling();
  }

  Future<void> _handleWidgetLaunch(HomeWidgetType type) async {
    _pendingWidgetAction = type;
    _scheduleWidgetHandling();
  }

  Future<void> _handleShareLaunch(SharePayload payload) async {
    _pendingSharePayload = payload;
    _scheduleShareHandling();
  }

  void _scheduleWidgetHandling() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handlePendingWidgetAction();
    });
  }

  void _scheduleShareHandling() {
    if (_shareHandlingScheduled) return;
    _shareHandlingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareHandlingScheduled = false;
      if (!mounted) return;
      _handlePendingShare();
    });
  }

  Future<void> _awaitPendingLaunchSources() async {
    final futures = <Future<void>>[];
    final widgetLoad = _pendingWidgetActionLoad;
    if (widgetLoad != null) futures.add(widgetLoad);
    final shareLoad = _pendingShareLoad;
    if (shareLoad != null) futures.add(shareLoad);
    if (futures.isEmpty) return;
    try {
      await Future.wait(futures);
    } catch (_) {}
  }

  void _scheduleLaunchActionHandling() {
    if (_launchActionHandled || _launchActionScheduled) return;
    _launchActionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchActionScheduled = false;
      if (!mounted) return;
      unawaited(_handleLaunchAction());
    });
  }

  Future<void> _handleLaunchAction() async {
    if (_launchActionHandled) return;
    await _awaitPendingLaunchSources();
    if (!mounted) return;
    if (!_hasActiveWorkspace()) return;

    _launchActionHandled = true;
    final prefs = ref.read(appPreferencesProvider);
    final hasPendingUiAction =
        _pendingSharePayload != null || _pendingWidgetAction != null;

    if (!hasPendingUiAction) {
      switch (prefs.launchAction) {
        case LaunchAction.dailyReview:
          final navigator = _navigatorKey.currentState;
          if (navigator != null) {
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => const DailyReviewScreen(),
              ),
            );
          }
          break;
        case LaunchAction.quickInput:
          _openQuickInput(autoFocus: prefs.quickInputAutoFocus);
          break;
        case LaunchAction.none:
          break;
        case LaunchAction.sync:
          // Deprecated. Kept for backward compatibility with stale in-memory
          // enum values before preferences migration writes back.
          break;
      }
    }

    await _syncOrchestrator.maybeSyncOnLaunch(prefs);
  }

  bool _hasActiveWorkspace() {
    final session = ref.read(appSessionProvider).valueOrNull;
    final hasAccount = session?.currentAccount != null;
    final hasLocalLibrary = ref.read(currentLocalLibraryProvider) != null;
    return hasAccount || hasLocalLibrary;
  }

  void _openQuickInput({required bool autoFocus}) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _openAllMemos(navigator);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sheetContext = _navigatorKey.currentContext;
      if (sheetContext != null) {
        NoteInputSheet.show(sheetContext, autoFocus: autoFocus);
      }
    });
  }

  void _scheduleStatsWidgetUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateStatsWidgetIfNeeded();
    });
  }

  Future<String?> _fetchAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      return version.isEmpty ? null : version;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveAppVersion() {
    return _appVersionFuture ??= _fetchAppVersion();
  }

  int _compareVersionTriplets(String remote, String local) {
    final remoteParts = _parseVersionTriplet(remote);
    final localParts = _parseVersionTriplet(local);
    for (var i = 0; i < 3; i++) {
      final diff = remoteParts[i].compareTo(localParts[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  List<int> _parseVersionTriplet(String version) {
    if (version.trim().isEmpty) return const [0, 0, 0];
    final trimmed = version.split(RegExp(r'[-+]')).first;
    final parts = trimmed.split('.');
    final values = <int>[0, 0, 0];
    for (var i = 0; i < 3; i++) {
      if (i >= parts.length) break;
      final match = RegExp(r'\d+').firstMatch(parts[i]);
      if (match == null) continue;
      values[i] = int.tryParse(match.group(0) ?? '') ?? 0;
    }
    return values;
  }

  void _scheduleUpdateAnnouncementIfNeeded() {
    if (_updateAnnouncementChecked) return;
    _updateAnnouncementChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeShowAnnouncements());
    });
  }

  Future<void> _maybeShowAnnouncements() async {
    var version = await _resolveAppVersion();
    if (!mounted || version == null || version.isEmpty) return;

    final prefs = ref.read(appPreferencesProvider);
    if (!prefs.hasSelectedLanguage) return;

    final config = await ref.read(updateConfigServiceProvider).fetchLatest();
    if (!mounted) return;
    final effectiveConfig = config ?? _fallbackUpdateConfig;

    var displayVersion = version;
    if (kDebugMode) {
      final debugVersion = effectiveConfig.versionInfo.debugVersion.trim();
      displayVersion = debugVersion.isNotEmpty ? debugVersion : '999.0';
    }

    await _maybeShowUpdateAnnouncementWithConfig(
      config: effectiveConfig,
      currentVersion: displayVersion,
      prefs: prefs,
    );
    await _maybeShowNoticeWithConfig(config: effectiveConfig, prefs: prefs);
  }

  Future<void> _maybeShowUpdateAnnouncementWithConfig({
    required UpdateAnnouncementConfig config,
    required String currentVersion,
    required AppPreferences prefs,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final publishReady = config.versionInfo.isPublishedAt(nowUtc);
    final latestVersion = config.versionInfo.latestVersion.trim();
    final skipUpdateVersion = config.versionInfo.skipUpdateVersion.trim();
    final hasUpdate =
        publishReady &&
        latestVersion.isNotEmpty &&
        (skipUpdateVersion.isEmpty || latestVersion != skipUpdateVersion) &&
        _compareVersionTriplets(latestVersion, currentVersion) > 0;
    final isForce = config.versionInfo.isForce && hasUpdate;

    final showWhenUpToDate = config.announcement.showWhenUpToDate;
    final announcementId = config.announcement.id;
    final hasUnseenAnnouncement =
        announcementId > 0 && announcementId != prefs.lastSeenAnnouncementId;
    final shouldShow =
        isForce || hasUpdate || (showWhenUpToDate && hasUnseenAnnouncement);
    if (!shouldShow) return;

    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;

    final action = await UpdateAnnouncementDialog.show(
      dialogContext,
      config: config,
      currentVersion: currentVersion,
    );
    if (!mounted || isForce) return;
    if (action == AnnouncementAction.update ||
        action == AnnouncementAction.later) {
      ref
          .read(appPreferencesProvider.notifier)
          .setLastSeenAnnouncement(
            version: currentVersion,
            announcementId: config.announcement.id,
          );
    }
  }

  Future<void> _maybeShowNoticeWithConfig({
    required UpdateAnnouncementConfig config,
    required AppPreferences prefs,
  }) async {
    if (!config.noticeEnabled) return;
    final notice = config.notice;
    if (notice == null || !notice.hasContents) return;

    final noticeHash = _hashNotice(notice);
    if (noticeHash.isEmpty) return;
    if (prefs.lastSeenNoticeHash.trim() == noticeHash) return;

    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;

    final acknowledged = await NoticeDialog.show(dialogContext, notice: notice);
    if (!mounted || acknowledged != true) return;
    ref.read(appPreferencesProvider.notifier).setLastSeenNoticeHash(noticeHash);
  }

  String _hashNotice(UpdateNotice notice) {
    final buffer = StringBuffer();
    buffer.write(notice.title.trim());
    final localeKeys = notice.contentsByLocale.keys.toList()..sort();
    for (final key in localeKeys) {
      buffer.write('|$key=');
      final entries = notice.contentsByLocale[key] ?? const <String>[];
      for (final line in entries) {
        buffer.write(line.trim());
        buffer.write('\n');
      }
    }
    if (notice.fallbackContents.isNotEmpty) {
      buffer.write('|fallback=');
      for (final line in notice.fallbackContents) {
        buffer.write(line.trim());
        buffer.write('\n');
      }
    }
    final raw = buffer.toString().trim();
    if (raw.isEmpty) return '';
    return sha1.convert(utf8.encode(raw)).toString();
  }

  Future<void> _updateStatsWidgetIfNeeded({bool force = false}) async {
    if (_statsWidgetUpdating) return;
    final session = ref.read(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    if (account == null) return;
    if (!force && _statsWidgetAccountKey == account.key) return;

    _statsWidgetUpdating = true;
    try {
      final api = ref.read(memosApiProvider);
      final stats = await api.getUserStatsSummary(userName: account.user.name);
      final days = _buildHeatmapDays(stats.memoDisplayTimes, dayCount: 14);
      final language = ref.read(appPreferencesProvider).language;
      await HomeWidgetService.updateStatsWidget(
        total: stats.totalMemoCount,
        days: days,
        title: trByLanguageKey(
          language: language,
          key: 'legacy.msg_activity_heatmap',
        ),
        totalLabel: trByLanguageKey(
          language: language,
          key: 'legacy.msg_total',
        ),
        rangeLabel: trByLanguageKey(
          language: language,
          key: 'legacy.msg_last_14_days',
        ),
      );
      _statsWidgetAccountKey = account.key;
    } catch (_) {
      // Ignore widget updates if the backend isn't reachable.
    } finally {
      _statsWidgetUpdating = false;
    }
  }

  void _showAutoSyncFeedbackToast({required bool succeeded}) {
    final language = ref.read(appPreferencesProvider).language;
    final message = buildAutoSyncFeedbackMessage(
      language: language,
      succeeded: succeeded,
    );
    var delivered = false;
    var retryScheduled = false;

    void emit({required String phase, bool allowRetry = false}) {
      if (delivered) return;
      final homeContext = _mainHomePageKey.currentContext;
      final navigatorContext = _navigatorKey.currentContext;
      final overlayContext =
          homeContext ??
          navigatorContext ??
          _navigatorKey.currentState?.overlay?.context;
      if (overlayContext == null) {
        LogManager.instance.info(
          'AutoSync: feedback_toast_skipped_no_context',
          context: <String, Object?>{
            'phase': phase,
            'succeeded': succeeded,
            'message': message,
          },
        );
        return;
      }
      final channel = showSyncFeedback(
        overlayContext: overlayContext,
        messengerContext: navigatorContext ?? homeContext,
        language: language,
        succeeded: succeeded,
        message: message,
      );
      final event = switch (channel) {
        SyncFeedbackChannel.snackbar => 'AutoSync: feedback_snackbar_shown',
        SyncFeedbackChannel.toast => 'AutoSync: feedback_toast_shown',
        SyncFeedbackChannel.skipped =>
          'AutoSync: feedback_toast_skipped_no_overlay',
      };
      LogManager.instance.info(
        event,
        context: <String, Object?>{
          'phase': phase,
          'succeeded': succeeded,
          'message': message,
          'hasHomeContext': homeContext != null,
          'hasNavigatorContext': navigatorContext != null,
        },
      );
      if (channel != SyncFeedbackChannel.skipped) {
        delivered = true;
      }
      if (allowRetry &&
          channel == SyncFeedbackChannel.skipped &&
          !retryScheduled) {
        retryScheduled = true;
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (!mounted) return;
          emit(phase: 'delayed_retry', allowRetry: false);
        });
      }
    }

    emit(phase: 'immediate', allowRetry: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      emit(phase: 'next_frame', allowRetry: true);
    });
  }

  void _showAutoSyncProgressToast() {
    final language = ref.read(appPreferencesProvider).language;
    final message = buildAutoSyncProgressMessage(language: language);
    final homeContext = _mainHomePageKey.currentContext;
    final navigatorContext = _navigatorKey.currentContext;
    final overlayContext =
        homeContext ??
        navigatorContext ??
        _navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) {
      LogManager.instance.info(
        'AutoSync: progress_toast_skipped_no_context',
        context: <String, Object?>{
          'message': message,
          'hasHomeContext': homeContext != null,
          'hasNavigatorContext': navigatorContext != null,
        },
      );
      return;
    }

    var shown = showTopToast(
      overlayContext,
      message,
      duration: const Duration(seconds: 2),
      topOffset: 96,
    );
    if (!shown &&
        navigatorContext != null &&
        !identical(overlayContext, navigatorContext)) {
      shown = showTopToast(
        navigatorContext,
        message,
        duration: const Duration(seconds: 2),
        topOffset: 96,
      );
    }

    LogManager.instance.info(
      shown
          ? 'AutoSync: progress_toast_shown'
          : 'AutoSync: progress_toast_skipped_no_overlay',
      context: <String, Object?>{
        'message': message,
        'hasHomeContext': homeContext != null,
        'hasNavigatorContext': navigatorContext != null,
      },
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

  void _rescheduleRemindersIfNeeded() {
    final now = DateTime.now();
    final last = _lastReminderRescheduleAt;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastReminderRescheduleAt = now;
    unawaited(ref.read(reminderSchedulerProvider).rescheduleAll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _bindDesktopMultiWindowHandler();
        _syncOrchestrator.triggerLifecycleSync(isResume: true);
        _rescheduleRemindersIfNeeded();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  List<int> _buildHeatmapDays(
    List<DateTime> timestamps, {
    required int dayCount,
  }) {
    final counts = List<int>.filled(dayCount, 0);
    if (dayCount <= 0) return counts;

    final now = DateTime.now();
    final endDay = DateTime(now.year, now.month, now.day);
    final startDay = endDay.subtract(Duration(days: dayCount - 1));

    for (final ts in timestamps) {
      final local = ts.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final index = day.difference(startDay).inDays;
      if (index < 0 || index >= dayCount) continue;
      counts[index] = counts[index] + 1;
    }
    return counts;
  }

  void _handlePendingWidgetAction() {
    final type = _pendingWidgetAction;
    if (type == null) return;
    final session = ref.read(appSessionProvider).valueOrNull;
    if (session?.currentAccount == null) return;
    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    _pendingWidgetAction = null;
    switch (type) {
      case HomeWidgetType.dailyReview:
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const DailyReviewScreen()),
        );
        break;
      case HomeWidgetType.quickInput:
        _openAllMemos(navigator);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final sheetContext = _navigatorKey.currentContext;
          if (sheetContext != null) {
            final autoFocus = ref
                .read(appPreferencesProvider)
                .quickInputAutoFocus;
            NoteInputSheet.show(sheetContext, autoFocus: autoFocus);
          }
        });
        break;
      case HomeWidgetType.stats:
        _openAllMemos(navigator);
        break;
    }
  }

  void _handlePendingShare() {
    final payload = _pendingSharePayload;
    if (payload == null) return;
    if (!ref.read(appPreferencesLoadedProvider)) {
      _scheduleShareHandling();
      return;
    }
    final prefs = ref.read(appPreferencesProvider);
    if (!prefs.thirdPartyShareEnabled) {
      _pendingSharePayload = null;
      _notifyShareDisabled();
      return;
    }
    final session = ref.read(appSessionProvider).valueOrNull;
    if (session?.currentAccount == null) return;
    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    _pendingSharePayload = null;
    _openAllMemos(navigator);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sheetContext = _navigatorKey.currentContext;
      if (sheetContext == null) return;
      _openShareComposer(sheetContext, payload);
    });
  }

  void _openShareComposer(BuildContext context, SharePayload payload) {
    if (payload.type == SharePayloadType.images) {
      if (payload.paths.isEmpty) return;
      NoteInputSheet.show(
        context,
        initialAttachmentPaths: payload.paths,
        initialSelection: const TextSelection.collapsed(offset: 0),
        ignoreDraft: true,
      );
      return;
    }

    final rawText = (payload.text ?? '').trim();
    final url = _extractShareUrl(rawText);
    final text = url == null ? rawText : '[]($url)';
    final selectionOffset = url == null ? text.length : 1;
    NoteInputSheet.show(
      context,
      initialText: text,
      initialSelection: TextSelection.collapsed(offset: selectionOffset),
      ignoreDraft: true,
    );
  }

  String? _extractShareUrl(String raw) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(raw);
    final url = match?.group(0);
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return url;
  }

  void _notifyShareDisabled() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    showTopToast(
      context,
      context.t.strings.legacy.msg_third_party_share_disabled,
    );
  }

  void _openAllMemos(NavigatorState navigator) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final prefsLoaded = ref.watch(appPreferencesLoadedProvider);
    final session = ref.watch(appSessionProvider).valueOrNull;
    final accountKey = session?.currentKey;
    final themeColor = prefs.resolveThemeColor(accountKey);
    final customTheme = prefs.resolveCustomTheme(accountKey);
    MemoFlowPalette.applyThemeColor(themeColor, customTheme: customTheme);
    final themeMode = _themeModeFor(prefs.themeMode);
    final loggerService = ref.watch(loggerServiceProvider);
    final appLocale = _appLocaleFor(prefs.language);
    if (_activeLocale != appLocale) {
      LocaleSettings.setLocale(appLocale);
      _activeLocale = appLocale;
    }
    final screenshotModeEnabled = kDebugMode
        ? ref.watch(debugScreenshotModeProvider)
        : false;
    final scale = _textScaleFor(prefs.fontSize);
    final blurDesktopMainWindow = _shouldBlurDesktopMainWindow;
    if (blurDesktopMainWindow) {
      _scheduleDesktopSubWindowVisibilitySync();
    }
    _applyImageEditorI18n(prefs.language);

    if (_pendingWidgetAction != null) {
      _scheduleWidgetHandling();
    }
    if (_pendingSharePayload != null) {
      _scheduleShareHandling();
    }
    if (prefsLoaded) {
      _scheduleUpdateAnnouncementIfNeeded();
    }
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    if (prefsLoaded &&
        (session?.currentAccount != null || localLibrary != null)) {
      _scheduleLaunchActionHandling();
    }

    return TranslationProvider(
      child: MaterialApp(
        title: 'MemoFlow',
        debugShowCheckedModeBanner: !screenshotModeEnabled,
        theme: _applyPreferencesToTheme(buildAppTheme(Brightness.light), prefs),
        darkTheme: _applyPreferencesToTheme(
          buildAppTheme(Brightness.dark),
          prefs,
        ),
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
            PointerDeviceKind.trackpad,
          },
        ),
        themeMode: themeMode,
        locale: appLocale.flutterLocale,
        navigatorKey: _navigatorKey,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [loggerService.navigatorObserver],
        onGenerateRoute: (settings) {
          if (settings.name == '/memos/day') {
            final arg = settings.arguments;
            return MaterialPageRoute<void>(
              builder: (_) => MemosListScreen(
                title: 'MemoFlow',
                state: 'NORMAL',
                showDrawer: true,
                enableCompose: true,
                dayFilter: arg is DateTime ? arg : null,
              ),
            );
          }
          return null;
        },
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final appContent = MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(scale)),
            child: AppLockGate(child: child ?? const SizedBox.shrink()),
          );
          if (!blurDesktopMainWindow) return appContent;

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final overlayColor = Colors.black.withValues(
            alpha: isDark ? 0.26 : 0.12,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              appContent,
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ColoredBox(color: overlayColor),
                ),
              ),
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  unawaited(_focusVisibleDesktopSubWindow());
                },
                child: ClipRect(child: ColoredBox(color: Colors.transparent)),
              ),
            ],
          );
        },
        home: MainHomePage(key: _mainHomePageKey),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    setDesktopSettingsWindowVisibilityListener(null);
    if (kDebugMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _sessionSubscription?.close();
    _prefsSubscription?.close();
    _prefsLoadedSubscription?.close();
    _reminderSettingsSubscription?.close();
    _debugScreenshotModeSubscription?.close();
    if (!kIsWeb) {
      DesktopMultiWindow.setMethodHandler(null);
    }
    if (isDesktopShortcutEnabled()) {
      unawaited(_unregisterDesktopQuickInputHotKey());
    }
    super.dispose();
  }
}

class MainHomePage extends ConsumerStatefulWidget {
  const MainHomePage({super.key});

  @override
  ConsumerState<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends ConsumerState<MainHomePage> {
  String? _lastRouteDecisionKey;

  void _logRouteDecision({
    required bool prefsLoaded,
    required bool hasSelectedLanguage,
    required String sessionState,
    required String? sessionKey,
    required bool hasCurrentAccount,
    required bool hasLocalLibrary,
    required String destination,
  }) {
    if (!kDebugMode) return;
    final key =
        '$prefsLoaded|$hasSelectedLanguage|$sessionState|$sessionKey|$hasCurrentAccount|$hasLocalLibrary|$destination';
    if (_lastRouteDecisionKey == key) return;
    _lastRouteDecisionKey = key;
    LogManager.instance.info(
      'RouteGate: main_home_decision',
      context: <String, Object?>{
        'prefsLoaded': prefsLoaded,
        'hasSelectedLanguage': hasSelectedLanguage,
        'sessionState': sessionState,
        'sessionKey': sessionKey,
        'hasCurrentAccount': hasCurrentAccount,
        'hasLocalLibrary': hasLocalLibrary,
        'destination': destination,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsLoaded = ref.watch(appPreferencesLoadedProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final sessionAsync = ref.watch(appSessionProvider);
    final session = sessionAsync.valueOrNull;
    final localLibrary = ref.watch(currentLocalLibraryProvider);

    if (!prefsLoaded) {
      _logRouteDecision(
        prefsLoaded: false,
        hasSelectedLanguage: prefs.hasSelectedLanguage,
        sessionState: sessionAsync.isLoading
            ? 'loading'
            : (sessionAsync.hasError ? 'error' : 'data'),
        sessionKey: session?.currentKey,
        hasCurrentAccount: session?.currentAccount != null,
        hasLocalLibrary: localLibrary != null,
        destination: 'splash',
      );
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const SizedBox.expand(),
      );
    }
    if (!prefs.hasSelectedLanguage) {
      _logRouteDecision(
        prefsLoaded: true,
        hasSelectedLanguage: false,
        sessionState: sessionAsync.isLoading
            ? 'loading'
            : (sessionAsync.hasError ? 'error' : 'data'),
        sessionKey: session?.currentKey,
        hasCurrentAccount: session?.currentAccount != null,
        hasLocalLibrary: localLibrary != null,
        destination: 'onboarding',
      );
      return const LanguageSelectionScreen();
    }

    return sessionAsync.when(
      data: (session) {
        final hasCurrentAccount = session.currentAccount != null;
        final hasLocalLibrary = localLibrary != null;
        final hasWorkspace = hasCurrentAccount || hasLocalLibrary;
        final showOnboarding =
            !hasWorkspace &&
            (prefs.onboardingMode == null ||
                prefs.onboardingMode == AppOnboardingMode.local);
        final needsLogin =
            !hasWorkspace && prefs.onboardingMode == AppOnboardingMode.server;
        _logRouteDecision(
          prefsLoaded: true,
          hasSelectedLanguage: prefs.hasSelectedLanguage,
          sessionState: 'data',
          sessionKey: session.currentKey,
          hasCurrentAccount: hasCurrentAccount,
          hasLocalLibrary: hasLocalLibrary,
          destination: showOnboarding
              ? 'onboarding'
              : (needsLogin ? 'login' : 'home'),
        );
        if (showOnboarding) return const LanguageSelectionScreen();
        return needsLogin ? const LoginScreen() : const HomeScreen();
      },
      loading: () {
        if (session != null) {
          final hasCurrentAccount = session.currentAccount != null;
          final hasLocalLibrary = localLibrary != null;
          final hasWorkspace = hasCurrentAccount || hasLocalLibrary;
          final showOnboarding =
              !hasWorkspace &&
              (prefs.onboardingMode == null ||
                  prefs.onboardingMode == AppOnboardingMode.local);
          final needsLogin =
              !hasWorkspace && prefs.onboardingMode == AppOnboardingMode.server;
          _logRouteDecision(
            prefsLoaded: true,
            hasSelectedLanguage: prefs.hasSelectedLanguage,
            sessionState: 'loading_with_cached',
            sessionKey: session.currentKey,
            hasCurrentAccount: hasCurrentAccount,
            hasLocalLibrary: hasLocalLibrary,
            destination: showOnboarding
                ? 'onboarding'
                : (needsLogin ? 'login' : 'home'),
          );
          if (showOnboarding) return const LanguageSelectionScreen();
          return needsLogin ? const LoginScreen() : const HomeScreen();
        }
        _logRouteDecision(
          prefsLoaded: true,
          hasSelectedLanguage: prefs.hasSelectedLanguage,
          sessionState: 'loading_without_cached',
          sessionKey: null,
          hasCurrentAccount: false,
          hasLocalLibrary: localLibrary != null,
          destination: 'splash',
        );
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const SizedBox.expand(),
        );
      },
      error: (e, _) {
        if (session != null) {
          final hasCurrentAccount = session.currentAccount != null;
          final hasLocalLibrary = localLibrary != null;
          final hasWorkspace = hasCurrentAccount || hasLocalLibrary;
          final showOnboarding =
              !hasWorkspace &&
              (prefs.onboardingMode == null ||
                  prefs.onboardingMode == AppOnboardingMode.local);
          final needsLogin =
              !hasWorkspace && prefs.onboardingMode == AppOnboardingMode.server;
          _logRouteDecision(
            prefsLoaded: true,
            hasSelectedLanguage: prefs.hasSelectedLanguage,
            sessionState: 'error_with_cached',
            sessionKey: session.currentKey,
            hasCurrentAccount: hasCurrentAccount,
            hasLocalLibrary: hasLocalLibrary,
            destination: showOnboarding
                ? 'onboarding'
                : (needsLogin ? 'login' : 'home'),
          );
          if (showOnboarding) return const LanguageSelectionScreen();
          return needsLogin ? const LoginScreen() : const HomeScreen();
        }
        final showOnboarding =
            prefs.onboardingMode == null ||
            prefs.onboardingMode == AppOnboardingMode.local;
        _logRouteDecision(
          prefsLoaded: true,
          hasSelectedLanguage: prefs.hasSelectedLanguage,
          sessionState: 'error_without_cached',
          sessionKey: null,
          hasCurrentAccount: false,
          hasLocalLibrary: localLibrary != null,
          destination: showOnboarding ? 'onboarding' : 'login_error',
        );
        if (showOnboarding) return const LanguageSelectionScreen();
        return LoginScreen(initialError: e.toString());
      },
    );
  }
}
