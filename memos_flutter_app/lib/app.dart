import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_localization.dart';
import 'core/app_theme.dart';
import 'core/system_fonts.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/memos/memos_list_screen.dart';
import 'features/memos/note_input_sheet.dart';
import 'features/review/daily_review_screen.dart';
import 'features/settings/widgets_service.dart';
import 'features/splash/splash_page.dart';
import 'state/logging_provider.dart';
import 'state/memos_providers.dart';
import 'state/preferences_provider.dart';
import 'state/session_provider.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  HomeWidgetType? _pendingWidgetAction;
  bool _statsWidgetUpdating = false;
  String? _statsWidgetAccountKey;
  ProviderSubscription<AsyncValue<AppSessionState>>? _sessionSubscription;
  ProviderSubscription<AppPreferences>? _prefsSubscription;
  DateTime? _lastResumeSyncAt;
  DateTime? _lastPauseSyncAt;

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
    HomeWidgetService.setLaunchHandler(_handleWidgetLaunch);
    _loadPendingWidgetAction();
    _sessionSubscription = ref.listenManual<AsyncValue<AppSessionState>>(appSessionProvider, (prev, next) {
      final prevKey = prev?.valueOrNull?.currentKey;
      final nextKey = next.valueOrNull?.currentKey;
      if (nextKey != null && nextKey != prevKey) {
        _scheduleStatsWidgetUpdate();
        _lastResumeSyncAt = null;
        _lastPauseSyncAt = null;
        _triggerLifecycleSync(isResume: true);
      }
    });
    _prefsSubscription = ref.listenManual<AppPreferences>(appPreferencesProvider, (prev, next) {
      if (prev?.fontFamily == next.fontFamily && prev?.fontFile == next.fontFile) return;
      unawaited(_ensureFontLoaded(next));
    });
    _scheduleStatsWidgetUpdate();
  }

  Future<void> _loadPendingWidgetAction() async {
    final type = await HomeWidgetService.consumePendingAction();
    if (!mounted || type == null) return;
    _pendingWidgetAction = type;
    _scheduleWidgetHandling();
  }

  Future<void> _handleWidgetLaunch(HomeWidgetType type) async {
    _pendingWidgetAction = type;
    _scheduleWidgetHandling();
  }

  void _scheduleWidgetHandling() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handlePendingWidgetAction();
    });
  }

  void _scheduleStatsWidgetUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateStatsWidgetIfNeeded();
    });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _triggerLifecycleSync(isResume: true);
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

  void _openAllMemos(NavigatorState navigator) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'memoflow',
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
    final themeMode = _themeModeFor(prefs.themeMode);
    final loggerService = ref.watch(loggerServiceProvider);
    final locale = _localeFor(prefs.language);
    final scale = _textScaleFor(prefs.fontSize);

    if (_pendingWidgetAction != null) {
      _scheduleWidgetHandling();
    }

    return MaterialApp(
      title: 'memoflow',
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
      home: SplashPage(nextBuilder: (_) => const MainHomePage()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.close();
    _prefsSubscription?.close();
    super.dispose();
  }
}

class MainHomePage extends ConsumerWidget {
  const MainHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);
    final session = sessionAsync.valueOrNull;

    return sessionAsync.when(
      data: (session) => session.currentAccount == null ? const LoginScreen() : const HomeScreen(),
      loading: () {
        if (session != null) {
          return session.currentAccount == null ? const LoginScreen() : const HomeScreen();
        }
        return const SplashContent();
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
