import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_motion.dart';
import '../../core/app_localization.dart';
import '../../core/splash_tokens.g.dart';
import '../../core/startup_timing.dart';
import '../../application/startup/startup_coordinator.dart';
import '../legal/legal_consent_gate.dart';
import '../startup/startup_screen.dart';
import '../startup/storage_error_screen.dart';
import '../startup/storage_error_banner.dart';
import '../auth/login_screen.dart';
import 'home_entry_screen.dart';
import '../onboarding/language_selection_screen.dart';
import '../../data/models/app_preferences.dart';
import '../../state/memos/app_bootstrap_adapter_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/session_provider.dart';
import '../../state/system/storage_error_provider.dart';
import '../../application/desktop/desktop_exit_coordinator.dart';

class MainHomePage extends ConsumerStatefulWidget {
  const MainHomePage({super.key, this.startupCoordinator});

  final StartupCoordinator? startupCoordinator;

  @override
  ConsumerState<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends ConsumerState<MainHomePage> {
  String? _lastRouteDecisionKey;

  void _handleStartupCoordinatorChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Timer? _startupMinTimer;
  bool _startupMinElapsed = false;
  bool _startupMinTimerStarted = false;
  bool _firstFrameRendered = false;
  bool _loggedFirstBuild = false;
  bool _loggedPrefsLoaded = false;
  bool _loggedSessionReady = false;
  bool _loggedBuildStart = false;
  bool _loggedBuildEnd = false;
  bool _loggedFirstFrameGate = false;
  bool _startupShownLogged = false;
  bool _startupHiddenLogged = false;
  bool _contentFirstFrameLogged = false;
  int? _startupMinTargetTotalMs;
  int? _startupMinRemainingMs;
  int? _startupElapsedAtFirstFrameMs;
  String? _lastDestination;
  Widget? _lockedContent;

  @override
  void initState() {
    super.initState();
    widget.startupCoordinator?.addListener(_handleStartupCoordinatorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstFrameRendered = true;
      StartupTiming.markStep('main_home_first_frame_ready');
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant MainHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startupCoordinator == widget.startupCoordinator) return;
    oldWidget.startupCoordinator?.removeListener(
      _handleStartupCoordinatorChanged,
    );
    widget.startupCoordinator?.addListener(_handleStartupCoordinatorChanged);
  }

  @override
  void dispose() {
    widget.startupCoordinator?.removeListener(_handleStartupCoordinatorChanged);
    _startupMinTimer?.cancel();
    super.dispose();
  }

  void _logRouteDecision({
    required bool prefsLoaded,
    required bool hasSelectedLanguage,
    required String sessionState,
    required String? sessionKey,
    required bool hasCurrentAccount,
    required bool hasLocalLibrary,
    required String destination,
  }) {
    final key =
        '$prefsLoaded|$hasSelectedLanguage|$sessionState|$sessionKey|$hasCurrentAccount|$hasLocalLibrary|$destination';
    if (_lastRouteDecisionKey == key) return;
    _lastRouteDecisionKey = key;
    _lastDestination = destination;
    StartupTiming.markEvent(
      'route_decided',
      extra: <String, Object?>{
        'prefsLoaded': prefsLoaded,
        'hasSelectedLanguage': hasSelectedLanguage,
        'sessionState': sessionState,
        'sessionKey': sessionKey,
        'hasCurrentAccount': hasCurrentAccount,
        'hasLocalLibrary': hasLocalLibrary,
        'destination': destination,
      },
      once: false,
    );
  }

  void _startStartupMinTimer({
    required int elapsedMs,
    required int minVisibleMs,
  }) {
    if (_startupMinTimerStarted) return;
    _startupMinTimerStarted = true;
    _startupMinElapsed = false;
    _startupMinTimer?.cancel();
    _startupElapsedAtFirstFrameMs = elapsedMs;
    _startupMinTargetTotalMs = minVisibleMs;
    _startupMinRemainingMs = minVisibleMs;
    if (minVisibleMs <= 0) {
      _startupMinElapsed = true;
      return;
    }
    _startupMinTimer = Timer(Duration(milliseconds: minVisibleMs), () {
      if (!mounted) return;
      setState(() {
        _startupMinElapsed = true;
      });
    });
  }

  Widget _buildStartupPlaceholder() {
    return const ColoredBox(
      color: SplashTokens.backgroundColor,
      child: SizedBox.expand(),
    );
  }

  void _scheduleContentFirstFrameLog() {
    if (_contentFirstFrameLogged) return;
    _contentFirstFrameLogged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTiming.markEvent(
        'home_first_frame',
        extra: <String, Object?>{'destination': _lastDestination ?? 'unknown'},
        once: false,
      );
    });
  }

  Future<void> _retryStorageLoad() async {
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(appSessionProvider.notifier).reloadFromStorage();
    await container
        .read(devicePreferencesProvider.notifier)
        .reloadFromStorage();
    await container
        .read(currentWorkspacePreferencesProvider.notifier)
        .reloadFromStorage();
    await container.read(localLibrariesProvider.notifier).reloadFromStorage();
  }

  void _exitApp() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      DesktopExitCoordinator.requestExit(reason: 'storage_error');
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedBuildStart) {
      _loggedBuildStart = true;
      StartupTiming.markStep('main_home_build_start');
    }
    if (!_loggedFirstBuild) {
      _loggedFirstBuild = true;
      StartupTiming.markMainHomeBuild();
    }
    Widget finalize(Widget child) {
      if (!_loggedBuildEnd) {
        _loggedBuildEnd = true;
        StartupTiming.markStep('main_home_build_end');
      }
      return child;
    }

    if (!_firstFrameRendered) {
      if (!_loggedFirstFrameGate) {
        _loggedFirstFrameGate = true;
        StartupTiming.markStep('main_home_gate_placeholder');
      }
      final locale = ui.PlatformDispatcher.instance.locale;
      final showStartupSlogan = locale.languageCode != 'en';
      return finalize(StartupScreen(showSlogan: showStartupSlogan));
    }

    final adapter = ref.read(appBootstrapAdapterProvider);
    final prefsLoaded = adapter.watchDevicePreferencesLoaded(ref);
    final prefs = adapter.watchDevicePreferences(ref);
    final sessionAsync = adapter.watchSession(ref);
    final session = sessionAsync.valueOrNull;
    final localLibrary = adapter.watchCurrentLocalLibrary(ref);
    final storageError = ref.watch(storageLoadErrorProvider);
    final hasStorageError = storageError != null;
    final showStartupSlogan = !prefersEnglishFor(prefs.language);
    if (!_startupMinTimerStarted) {
      _startStartupMinTimer(
        elapsedMs: StartupTiming.elapsedMs,
        minVisibleMs: startupMinimumVisibleMsFor(
          context: context,
          showSlogan: showStartupSlogan,
        ),
      );
    }
    final waitingForReady =
        !prefsLoaded || (sessionAsync.isLoading && session == null);

    if (prefsLoaded && !_loggedPrefsLoaded) {
      _loggedPrefsLoaded = true;
      StartupTiming.markPrefsLoaded();
    }
    if (!sessionAsync.isLoading && !_loggedSessionReady) {
      _loggedSessionReady = true;
      final state = sessionAsync.hasError
          ? 'error'
          : (sessionAsync.hasValue ? 'data' : 'unknown');
      StartupTiming.markSessionReady(state: state, hasSession: session != null);
    }

    Widget content;
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
      content = _buildStartupPlaceholder();
    } else if (!prefs.hasSelectedLanguage) {
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
      content = const LanguageSelectionScreen();
    } else {
      content = sessionAsync.when(
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
          return needsLogin ? const LoginScreen() : const HomeEntryScreen();
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
                !hasWorkspace &&
                prefs.onboardingMode == AppOnboardingMode.server;
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
            return needsLogin ? const LoginScreen() : const HomeEntryScreen();
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
          return _buildStartupPlaceholder();
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
                !hasWorkspace &&
                prefs.onboardingMode == AppOnboardingMode.server;
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
            return needsLogin ? const LoginScreen() : const HomeEntryScreen();
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

    if (!hasStorageError &&
        _lastDestination != null &&
        _lastDestination != 'splash') {
      _lockedContent = content;
    }

    if (hasStorageError) {
      if (_lockedContent == null) {
        content = StorageErrorScreen(
          error: storageError,
          onRetry: _retryStorageLoad,
          onExit: _exitApp,
        );
      } else {
        content = Stack(
          children: [
            _lockedContent!,
            StorageErrorBanner(
              error: storageError,
              onRetry: _retryStorageLoad,
              onExit: _exitApp,
            ),
          ],
        );
      }
    }

    var showStartup = !_startupMinElapsed || waitingForReady;
    if (hasStorageError) {
      showStartup = false;
    }
    if (showStartup && !_startupShownLogged) {
      _startupShownLogged = true;
      StartupTiming.markEvent(
        'startup_screen_shown',
        extra: <String, Object?>{
          'elapsedMs': StartupTiming.elapsedMs,
          'minTargetTotalMs': _startupMinTargetTotalMs,
          'minRemainingMs': _startupMinRemainingMs,
          'elapsedAtFirstFrameMs': _startupElapsedAtFirstFrameMs,
          'waitingForReady': waitingForReady,
        },
        once: false,
      );
    }
    if (!showStartup) {
      if (_startupShownLogged && !_startupHiddenLogged) {
        _startupHiddenLogged = true;
        StartupTiming.markEvent(
          'startup_screen_hidden',
          extra: <String, Object?>{
            'elapsedMs': StartupTiming.elapsedMs,
            'destination': _lastDestination ?? 'unknown',
          },
          once: false,
        );
      }
      _scheduleContentFirstFrameLog();
    }
    final child = showStartup
        ? StartupScreen(showSlogan: showStartupSlogan)
        : content;
    final startupTransitionDuration = AppMotion.effectiveDuration(
      context,
      AppMotion.route,
    );

    final animatedChild = AnimatedSwitcher(
      duration: startupTransitionDuration,
      switchInCurve: AppMotion.standardCurve,
      switchOutCurve: AppMotion.exitCurve,
      transitionBuilder: (child, animation) {
        if (startupTransitionDuration == Duration.zero) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.standardCurve,
          reverseCurve: AppMotion.exitCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: AppMotion.verticalEntryOffset,
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(showStartup ? 'startup' : 'content'),
        child: child,
      ),
    );

    if (showStartup || hasStorageError) {
      return finalize(animatedChild);
    }

    return finalize(
      LegalConsentGate(
        placeholder: StartupScreen(showSlogan: showStartupSlogan),
        child: animatedChild,
      ),
    );
  }
}
