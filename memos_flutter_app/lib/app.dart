import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app_localization.dart';
import 'core/app_theme.dart';
import 'core/memoflow_palette.dart';
import 'core/system_fonts.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/memos/memos_list_screen.dart';
import 'features/memos/note_input_sheet.dart';
import 'features/onboarding/language_selection_screen.dart';
import 'features/review/daily_review_screen.dart';
import 'features/share/share_handler.dart';
import 'features/settings/widgets_service.dart';
import 'features/updates/version_announcement_dialog.dart';
import 'state/logging_provider.dart';
import 'state/memos_providers.dart';
import 'state/preferences_provider.dart';
import 'state/reminder_scheduler.dart';
import 'state/reminder_settings_provider.dart';
import 'state/session_provider.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  HomeWidgetType? _pendingWidgetAction;
  SharePayload? _pendingSharePayload;
  bool _shareHandlingScheduled = false;
  bool _statsWidgetUpdating = false;
  String? _statsWidgetAccountKey;
  ProviderSubscription<AsyncValue<AppSessionState>>? _sessionSubscription;
  ProviderSubscription<AppPreferences>? _prefsSubscription;
  ProviderSubscription<ReminderSettings>? _reminderSettingsSubscription;
  ProviderSubscription<bool>? _prefsLoadedSubscription;
  DateTime? _lastResumeSyncAt;
  DateTime? _lastPauseSyncAt;
  DateTime? _lastReminderRescheduleAt;
  bool _versionAnnouncementChecked = false;
  Future<String?>? _appVersionFuture;
  String? _pendingThemeAccountKey;

  static const Map<String, String> _imageEditorI18nZh = {
    'Crop': '裁剪',
    'Brush': '涂鸦',
    'Text': '文字',
    'Link': '链接',
    'Flip': '翻转',
    'Rotate left': '向左旋转',
    'Rotate right': '向右旋转',
    'Blur': '模糊',
    'Filter': '滤镜',
    'Emoji': '贴纸',
    'Select Emoji': '选择贴纸',
    'Size Adjust': '大小调整',
    'Remove': '删除',
    'Size': '大小',
    'Color': '颜色',
    'Background Color': '背景颜色',
    'Background Opacity': '背景透明度',
    'Slider Filter Color': '滤镜颜色',
    'Slider Color': '颜色',
    'Slider Opicity': '透明度',
    'Reset': '重置',
    'Blur Radius': '模糊半径',
    'Color Opacity': '颜色透明度',
    'Insert Your Message': '输入文字',
    'https://example.com': '输入链接',
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
    ImageEditor.setI18n(language == AppLanguage.en ? _imageEditorI18nEn : _imageEditorI18nZh);
  }

  static Locale _localeFor(AppLanguage language) {
    return switch (language) {
      AppLanguage.zhHans => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      AppLanguage.en => const Locale('en'),
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

  static TextTheme _applyFontFamily(TextTheme theme, {String? family, List<String>? fallback}) {
    if (family == null && (fallback == null || fallback.isEmpty)) return theme;
    return theme.apply(fontFamily: family, fontFamilyFallback: fallback);
  }

  static ThemeData _applyPreferencesToTheme(ThemeData theme, AppPreferences prefs) {
    final lineHeight = _lineHeightFor(prefs.lineHeight);
    final textTheme = _applyLineHeight(
      _applyFontFamily(theme.textTheme, family: prefs.fontFamily, fallback: null),
      lineHeight,
    );
    final primaryTextTheme = _applyLineHeight(
      _applyFontFamily(theme.primaryTextTheme, family: prefs.fontFamily, fallback: null),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(logManagerProvider);
    HomeWidgetService.setLaunchHandler(_handleWidgetLaunch);
    _loadPendingWidgetAction();
    ShareHandlerService.setShareHandler(_handleShareLaunch);
    _loadPendingShare();
    _sessionSubscription = ref.listenManual<AsyncValue<AppSessionState>>(appSessionProvider, (prev, next) {
      final prevKey = prev?.valueOrNull?.currentKey;
      final nextKey = next.valueOrNull?.currentKey;
      if (nextKey != null && nextKey != prevKey) {
        _scheduleStatsWidgetUpdate();
        _lastResumeSyncAt = null;
        _lastPauseSyncAt = null;
        _triggerLifecycleSync(isResume: true);
        unawaited(ref.read(reminderSchedulerProvider).rescheduleAll(force: true));
      }
      if (nextKey != null) {
        if (ref.read(appPreferencesLoadedProvider)) {
          ref.read(appPreferencesProvider.notifier).ensureAccountThemeDefaults(nextKey);
        } else {
          _pendingThemeAccountKey = nextKey;
        }
      }
      if (next.valueOrNull?.currentAccount != null) {
        _scheduleShareHandling();
      }
    });
    _prefsSubscription = ref.listenManual<AppPreferences>(appPreferencesProvider, (prev, next) {
      if (prev?.fontFamily == next.fontFamily && prev?.fontFile == next.fontFile) return;
      unawaited(_ensureFontLoaded(next));
    });
    _prefsLoadedSubscription = ref.listenManual<bool>(appPreferencesLoadedProvider, (prev, next) {
      if (!next) return;
      final key = _pendingThemeAccountKey ?? ref.read(appSessionProvider).valueOrNull?.currentKey;
      if (key != null) {
        ref.read(appPreferencesProvider.notifier).ensureAccountThemeDefaults(key);
      }
      _pendingThemeAccountKey = null;
    });
    final reminderScheduler = ref.read(reminderSchedulerProvider);
    reminderScheduler.bindNavigator(_navigatorKey);
    unawaited(reminderScheduler.initialize());
    _reminderSettingsSubscription = ref.listenManual<ReminderSettings>(reminderSettingsProvider, (prev, next) {
      if (!ref.read(reminderSettingsLoadedProvider)) return;
      unawaited(reminderScheduler.rescheduleAll());
    });
    _scheduleStatsWidgetUpdate();
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

  void _scheduleVersionAnnouncementIfNeeded() {
    if (_versionAnnouncementChecked) return;
    _versionAnnouncementChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeShowVersionAnnouncement());
    });
  }

  Future<void> _maybeShowVersionAnnouncement() async {
    final version = await _resolveAppVersion();
    if (!mounted || version == null || version.isEmpty) return;

    final prefs = ref.read(appPreferencesProvider);
    final lastSeen = prefs.lastSeenAppVersion.trim();
    if (!prefs.hasSelectedLanguage) {
      if (lastSeen.isEmpty) {
        ref.read(appPreferencesProvider.notifier).setLastSeenAppVersion(version);
      }
      return;
    }
    if (lastSeen == version) return;

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final acknowledged = await VersionAnnouncementDialog.show(
      context,
      version: version,
      items: VersionAnnouncementContent.forVersion(version),
    );
    if (acknowledged == true && mounted) {
      ref.read(appPreferencesProvider.notifier).setLastSeenAppVersion(version);
    }
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
        title: trByLanguage(language: language, zh: '记录热力图', en: 'Activity Heatmap'),
        totalLabel: trByLanguage(language: language, zh: '总记录', en: 'Total'),
        rangeLabel: trByLanguage(language: language, zh: '最近 14 天', en: 'Last 14 days'),
      );
      _statsWidgetAccountKey = account.key;
    } catch (_) {
      // Ignore widget updates if the backend isn't reachable.
    } finally {
      _statsWidgetUpdating = false;
    }
  }

  Future<void> _syncAndUpdateStatsWidget({required bool forceWidgetUpdate}) async {
    final session = ref.read(appSessionProvider).valueOrNull;
    if (session?.currentAccount == null) return;

    try {
      await ref.read(syncControllerProvider.notifier).syncNow();
    } catch (_) {
      // Ignore sync errors here; widget update can still proceed.
    }
    await _updateStatsWidgetIfNeeded(force: forceWidgetUpdate);
  }

  void _triggerLifecycleSync({required bool isResume}) {
    final session = ref.read(appSessionProvider).valueOrNull;
    if (session?.currentAccount == null) return;

    final now = DateTime.now();
    if (isResume) {
      final last = _lastResumeSyncAt;
      if (last != null && now.difference(last) < const Duration(seconds: 15)) {
        return;
      }
      _lastResumeSyncAt = now;
    } else {
      final last = _lastPauseSyncAt;
      if (last != null && now.difference(last) < const Duration(seconds: 15)) {
        return;
      }
      _lastPauseSyncAt = now;
    }

    if (isResume) {
      unawaited(ref.read(appSessionProvider.notifier).refreshCurrentUser());
    }

    unawaited(_syncAndUpdateStatsWidget(forceWidgetUpdate: true));
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
        _triggerLifecycleSync(isResume: true);
        _rescheduleRemindersIfNeeded();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _triggerLifecycleSync(isResume: false);
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  List<int> _buildHeatmapDays(List<DateTime> timestamps, {required int dayCount}) {
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
        navigator.push(MaterialPageRoute<void>(builder: (_) => const DailyReviewScreen()));
        break;
      case HomeWidgetType.quickInput:
        _openAllMemos(navigator);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final sheetContext = _navigatorKey.currentContext;
          if (sheetContext != null) {
            NoteInputSheet.show(sheetContext);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(zh: '第三方分享未开启', en: 'Third-party share is disabled'),
        ),
      ),
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
    final locale = _localeFor(prefs.language);
    final scale = _textScaleFor(prefs.fontSize);
    _applyImageEditorI18n(prefs.language);

    if (_pendingWidgetAction != null) {
      _scheduleWidgetHandling();
    }
    if (_pendingSharePayload != null) {
      _scheduleShareHandling();
    }
    if (prefsLoaded) {
      _scheduleVersionAnnouncementIfNeeded();
    }

    return MaterialApp(
      title: 'MemoFlow',
      theme: _applyPreferencesToTheme(buildAppTheme(Brightness.light), prefs),
      darkTheme: _applyPreferencesToTheme(buildAppTheme(Brightness.dark), prefs),
      themeMode: themeMode,
      locale: locale,
      navigatorKey: _navigatorKey,
      supportedLocales: const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [loggerService.navigatorObserver],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: AppLockGate(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const MainHomePage(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.close();
    _prefsSubscription?.close();
    _prefsLoadedSubscription?.close();
    _reminderSettingsSubscription?.close();
    super.dispose();
  }
}

class MainHomePage extends ConsumerWidget {
  const MainHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsLoaded = ref.watch(appPreferencesLoadedProvider);
    final prefs = ref.watch(appPreferencesProvider);
    if (!prefsLoaded) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const SizedBox.expand(),
      );
    }
    if (!prefs.hasSelectedLanguage) {
      return const LanguageSelectionScreen();
    }

    final sessionAsync = ref.watch(appSessionProvider);
    final session = sessionAsync.valueOrNull;

    return sessionAsync.when(
      data: (session) => session.currentAccount == null ? const LoginScreen() : const HomeScreen(),
      loading: () {
        if (session != null) {
          return session.currentAccount == null ? const LoginScreen() : const HomeScreen();
        }
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const SizedBox.expand(),
        );
      },
      error: (e, _) {
        if (session != null) {
          return session.currentAccount == null ? const LoginScreen() : const HomeScreen();
        }
        return LoginScreen(initialError: e.toString());
      },
    );
  }
}
