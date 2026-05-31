import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/desktop/window_chrome_safe_area.dart';
import '../../core/desktop_db_write_channel.dart';
import '../../core/desktop/shortcuts.dart';
import '../../core/desktop_sync_channel.dart';
import '../../core/app_theme.dart';
import '../../core/memoflow_palette.dart';
import '../../core/desktop_quick_input_channel.dart';
import '../../core/top_toast.dart';
import '../../application/desktop/desktop_settings_window.dart';
import '../../application/sync/desktop_remote_sync_facade.dart';
import '../../application/sync/sync_coordinator.dart';
import '../../application/desktop/desktop_workspace_snapshot.dart';
import '../../data/db/db_write_protocol.dart';
import '../../data/logs/webdav_backup_progress_tracker.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/device_preferences.dart';
import '../../data/models/workspace_preferences.dart';
import '../../data/repositories/ai_settings_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/system/logging_provider.dart';
import '../../state/settings/ai_settings_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/resolved_preferences_provider.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/system/session_provider.dart';
import '../../state/webdav/webdav_backup_provider.dart';
import '../../data/models/local_library.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../review/ai_insight_prompt_editor_screen.dart';
import '../stats/stats_screen.dart';
import '../import/import_flow_screens.dart';
import '../updates/release_notes_screen.dart';
import 'about_us_screen.dart';
import 'account_security_screen.dart';
import 'ai_provider_settings_screen.dart';
import 'ai_settings_screen.dart';
import 'api_plugins_screen.dart';
import 'components_settings_screen.dart';
import 'desktop_shortcuts_settings_screen.dart';
import 'export_logs_screen.dart';
import 'export_memos_screen.dart';
import 'feedback_screen.dart';
import 'image_bed_settings_screen.dart';
import 'image_compression_settings_screen.dart';
import 'import_export_screen.dart';
import 'laboratory_screen.dart';
import 'location_settings_screen.dart';
import 'local_network_migration_screen.dart';
import 'memo_toolbar_settings_screen.dart';
import 'password_lock_screen.dart';
import 'preferences_settings_screen.dart';
import 'desktop_shortcuts_overview_screen.dart';
import 'self_repair_screen.dart';
import 'template_settings_screen.dart';
import 'user_guide_screen.dart';
import 'webdav_sync_screen.dart';
import 'widgets_screen.dart';
import 'windows_related_settings_screen.dart';

final desktopSettingsWorkspaceSnapshotProvider =
    StateProvider<DesktopWorkspaceSnapshot?>((ref) => null);

class DesktopSettingsWindowApp extends ConsumerWidget {
  const DesktopSettingsWindowApp({
    super.key,
    required this.windowId,
    this.initialTarget,
  });

  final int windowId;
  final DesktopSettingsWindowTarget? initialTarget;

  static AppLocale _appLocaleFor(AppLanguage language) {
    return appLocaleForLanguage(language);
  }

  static ThemeMode _themeModeFor(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
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

  static TextTheme _applyFontFamily(TextTheme theme, {String? family}) {
    if (family == null) return theme;
    return theme.apply(fontFamily: family);
  }

  static ThemeData _applyPreferencesToTheme(
    ThemeData theme,
    DevicePreferences prefs,
  ) {
    final lineHeight = _lineHeightFor(prefs.lineHeight);
    final textTheme = _applyLineHeight(
      _applyFontFamily(theme.textTheme, family: prefs.fontFamily),
      lineHeight,
    );
    final primaryTextTheme = _applyLineHeight(
      _applyFontFamily(theme.primaryTextTheme, family: prefs.fontFamily),
      lineHeight,
    );

    return theme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicePrefs = ref.watch(devicePreferencesProvider);
    final resolvedSettings = ref.watch(resolvedAppSettingsProvider);
    final themeColor = resolvedSettings.resolvedThemeColor;
    final customTheme = resolvedSettings.resolvedCustomTheme;
    MemoFlowPalette.applyThemeColor(themeColor, customTheme: customTheme);
    final appLocale = _appLocaleFor(devicePrefs.language);
    LocaleSettings.setLocale(appLocale);

    return TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MemoFlow Settings',
        theme: _applyPreferencesToTheme(
          buildAppTheme(Brightness.light),
          devicePrefs,
        ),
        darkTheme: _applyPreferencesToTheme(
          buildAppTheme(Brightness.dark),
          devicePrefs,
        ),
        themeMode: _themeModeFor(devicePrefs.themeMode),
        locale: appLocale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                _textScaleFor(devicePrefs.fontSize),
              ),
            ),
            child: _DesktopSettingsWindowFrame(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: DesktopSettingsWindowScreen(
          windowId: windowId,
          initialTarget: initialTarget,
        ),
      ),
    );
  }
}

class _DesktopSettingsWindowFrame extends StatelessWidget {
  const _DesktopSettingsWindowFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171717) : const Color(0xFFF4F4F4);
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E6);

    return SafeArea(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        ),
      ),
    );
  }
}

class DesktopSettingsWindowScreen extends StatefulWidget {
  const DesktopSettingsWindowScreen({
    super.key,
    required this.windowId,
    this.initialTarget,
  });

  final int windowId;
  final DesktopSettingsWindowTarget? initialTarget;

  @override
  State<DesktopSettingsWindowScreen> createState() =>
      _DesktopSettingsWindowScreenState();
}

class _DesktopSettingsWindowScreenState
    extends State<DesktopSettingsWindowScreen> {
  Future<bool>? _mainWindowChannelProbe;
  ProviderSubscription<String?>? _sessionKeySub;
  ProviderSubscription<List<LocalLibrary>>? _localLibrariesSub;
  ProviderSubscription<AiSettings>? _aiSettingsSub;
  ProviderSubscription<DevicePreferences>? _devicePreferencesSub;
  ProviderSubscription<WorkspacePreferences>? _workspacePreferencesSub;
  Timer? _aiSettingsReloadDebounce;
  Timer? _preferencesReloadDebounce;
  DesktopSettingsWindowTarget? _settingsTargetRequest;
  bool _workspaceListenersBound = false;
  bool _workspaceSnapshotLoading = true;
  bool _windowVisible = true;
  int _settingsRootResetToken = 0;
  int _settingsTargetRequestToken = 0;
  String? _workspaceSnapshotError;

  @override
  void initState() {
    super.initState();
    _settingsTargetRequest = widget.initialTarget;
    if (_settingsTargetRequest != null) {
      _settingsTargetRequestToken = 1;
    }
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
    unawaited(_initializeWindowManager());
    unawaited(_notifyMainWindowVisibility(true));
    unawaited(_refreshWorkspaceSnapshotWithRetry());
  }

  @override
  void dispose() {
    _windowVisible = false;
    unawaited(_notifyMainWindowVisibility(false));
    DesktopMultiWindow.setMethodHandler(null);
    _sessionKeySub?.close();
    _localLibrariesSub?.close();
    _aiSettingsSub?.close();
    _devicePreferencesSub?.close();
    _workspacePreferencesSub?.close();
    _aiSettingsReloadDebounce?.cancel();
    _preferencesReloadDebounce?.cancel();
    super.dispose();
  }

  void _setWorkspaceSnapshotState({required bool loading, String? error}) {
    if (!mounted) return;
    setState(() {
      _workspaceSnapshotLoading = loading;
      _workspaceSnapshotError = error;
    });
  }

  Future<void> _initializeWindowManager() async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setBackgroundColor(const Color(0x00000000));
    } catch (_) {}
  }

  Future<void> _notifyMainWindowVisibility(bool visible) async {
    try {
      await _invokeMainWindowMethod(
        desktopSubWindowVisibilityMethod,
        <String, dynamic>{'visible': visible},
      );
    } catch (_) {}
  }

  void _syncWorkspaceSnapshotFromLocalState({String? currentKeyOverride}) {
    final container = ProviderScope.containerOf(context, listen: false);
    final session = container.read(appSessionProvider).valueOrNull;
    final currentKey = currentKeyOverride ?? session?.currentKey;
    final libraries = container.read(localLibrariesProvider);
    final hasLocalLibrary =
        currentKey != null &&
        libraries.any((library) => library.key == currentKey);
    container
        .read(desktopSettingsWorkspaceSnapshotProvider.notifier)
        .state = DesktopWorkspaceSnapshot(
      currentKey: currentKey,
      hasCurrentAccount: session?.currentAccount != null,
      hasLocalLibrary: hasLocalLibrary,
    );
  }

  Future<void> _reloadWorkspaceStateFromStorage() async {
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(appSessionProvider.notifier).reloadFromStorage();
    await container.read(localLibrariesProvider.notifier).reloadFromStorage();
    _syncWorkspaceSnapshotFromLocalState();
  }

  void _bindWorkspaceChangeListeners() {
    if (_workspaceListenersBound) return;
    final container = ProviderScope.containerOf(context, listen: false);
    _sessionKeySub = container.listen<String?>(
      appSessionProvider.select((state) => state.valueOrNull?.currentKey),
      (prev, next) {
        if (prev == next) return;
        _syncWorkspaceSnapshotFromLocalState(currentKeyOverride: next);
        unawaited(
          _notifyMainWindowWorkspaceChanged(
            reason: 'session_key',
            currentKey: next,
          ),
        );
      },
    );
    _localLibrariesSub = container.listen<List<LocalLibrary>>(
      localLibrariesProvider,
      (prev, next) {
        if (_sameLocalLibraryKeys(prev, next)) return;
        _syncWorkspaceSnapshotFromLocalState();
        unawaited(_notifyMainWindowWorkspaceChanged(reason: 'local_libraries'));
      },
    );
    _aiSettingsSub = container.listen<AiSettings>(aiSettingsProvider, (
      prev,
      next,
    ) {
      if (prev == next) return;
      _scheduleMainWindowAiSettingsReload();
    });
    _devicePreferencesSub = container.listen<DevicePreferences>(
      devicePreferencesProvider,
      (prev, next) {
        if (identical(prev, next)) return;
        _scheduleMainWindowPreferencesReload();
      },
    );
    _workspacePreferencesSub = container.listen<WorkspacePreferences>(
      currentWorkspacePreferencesProvider,
      (prev, next) {
        if (identical(prev, next)) return;
        _scheduleMainWindowPreferencesReload();
      },
    );
    _workspaceListenersBound = true;
  }

  void _scheduleMainWindowAiSettingsReload() {
    _aiSettingsReloadDebounce?.cancel();
    _aiSettingsReloadDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      unawaited(_notifyMainWindowAiSettingsChanged());
    });
  }

  void _scheduleMainWindowPreferencesReload() {
    _preferencesReloadDebounce?.cancel();
    _preferencesReloadDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      unawaited(_notifyMainWindowPreferencesChanged());
    });
  }

  bool _sameLocalLibraryKeys(
    List<LocalLibrary>? prev,
    List<LocalLibrary> next,
  ) {
    if (prev == null) return false;
    if (prev.length != next.length) return false;
    final prevKeys = prev.map((l) => l.key).toList()..sort();
    final nextKeys = next.map((l) => l.key).toList()..sort();
    for (var i = 0; i < prevKeys.length; i++) {
      if (prevKeys[i] != nextKeys[i]) return false;
    }
    return true;
  }

  Future<void> _notifyMainWindowWorkspaceChanged({
    required String reason,
    String? currentKey,
  }) async {
    try {
      final args = <String, dynamic>{'reason': reason};
      if (reason == 'session_key' || currentKey != null) {
        args['currentKey'] = currentKey;
      }
      await _invokeMainWindowMethod(desktopMainReloadWorkspaceMethod, args);
    } catch (_) {}
  }

  Future<void> _notifyMainWindowAiSettingsChanged() async {
    try {
      await _invokeMainWindowMethod(desktopMainReloadAiSettingsMethod);
    } catch (_) {}
  }

  Future<void> _notifyMainWindowPreferencesChanged() async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await container
          .read(devicePreferencesProvider.notifier)
          .waitForPendingWrites();
      await container
          .read(currentWorkspacePreferencesProvider.notifier)
          .waitForPendingWrites();
      await _invokeMainWindowMethod(desktopMainReloadPreferencesMethod);
    } catch (_) {}
  }

  bool _isMainWindowChannelMissing(PlatformException error) {
    if (error.code.trim() == '-1') return true;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('target window not found') ||
        message.contains('target window channel not found');
  }

  Future<void> _wakeMainWindow() async {
    try {
      await WindowController.main().show();
    } catch (_) {}
  }

  Future<bool> _probeMainWindowChannel() async {
    const maxAttempts = 10;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await DesktopMultiWindow.invokeMethod(0, desktopQuickInputPingMethod);
        return true;
      } on MissingPluginException {
        // Main window handler not ready yet. Retry shortly.
      } on PlatformException catch (error) {
        if (!_isMainWindowChannelMissing(error)) {
          return false;
        }
      }
      if (attempt == 1 || attempt == 3 || attempt == 6) {
        await _wakeMainWindow();
      }
      await Future<void>.delayed(Duration(milliseconds: 120 + (attempt * 100)));
    }
    return false;
  }

  Future<bool> _ensureMainWindowChannelReady({bool force = false}) {
    if (!force) {
      final pending = _mainWindowChannelProbe;
      if (pending != null) return pending;
    }
    final future = _probeMainWindowChannel().then((ready) {
      if (!ready) {
        _mainWindowChannelProbe = null;
      }
      return ready;
    });
    _mainWindowChannelProbe = future;
    return future;
  }

  Future<dynamic> _invokeMainWindowMethod(
    String method, [
    dynamic arguments,
  ]) async {
    var ready = await _ensureMainWindowChannelReady();
    if (!ready) {
      ready = await _ensureMainWindowChannelReady(force: true);
    }
    if (!ready) {
      throw MissingPluginException('Main window channel is not ready.');
    }
    return DesktopMultiWindow.invokeMethod(0, method, arguments);
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int _) async {
    if (call.method == desktopSettingsFocusMethod) {
      await _bringWindowToFront();
      return true;
    }
    if (call.method == desktopSettingsOpenTargetMethod) {
      final target = DesktopSettingsWindowTarget.fromPayload(call.arguments);
      if (target == null) return false;
      if (mounted) {
        setState(() {
          _settingsTargetRequest = target;
          _settingsTargetRequestToken += 1;
        });
      }
      return true;
    }
    if (call.method == desktopDbChangedMethod) {
      final args = call.arguments;
      if (args is Map) {
        final event = DesktopDbChangeEvent.fromJson(
          Map<Object?, Object?>.from(args),
        );
        final container = ProviderScope.containerOf(context, listen: false);
        final currentKey =
            container
                .read(appSessionProvider)
                .valueOrNull
                ?.currentKey
                ?.trim() ??
            '';
        final expectedDbName = currentKey.isEmpty
            ? null
            : databaseNameForAccountKey(currentKey);
        if (currentKey == event.workspaceKey &&
            expectedDbName == event.dbName) {
          try {
            container.read(databaseProvider).notifyDataChanged();
          } catch (_) {}
        }
      }
      return true;
    }
    if (call.method == desktopSyncStateChangedMethod) {
      final args = call.arguments;
      if (args is Map) {
        final map = Map<Object?, Object?>.from(
          args,
        ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
        final container = ProviderScope.containerOf(context, listen: false);
        final currentKey =
            container
                .read(appSessionProvider)
                .valueOrNull
                ?.currentKey
                ?.trim() ??
            '';
        final eventKey = (map['workspaceKey'] as String? ?? '').trim();
        if (currentKey.isEmpty || eventKey.isEmpty || currentKey == eventKey) {
          final rawState = map['state'];
          if (rawState is Map) {
            container
                .read(desktopSyncFacadeProvider)
                .applyRemoteStateSnapshot(
                  SyncCoordinatorState.fromJson(
                    Map<Object?, Object?>.from(
                      rawState,
                    ).cast<String, dynamic>(),
                  ),
                );
          }
        }
      }
      return true;
    }
    if (call.method == desktopSyncProgressChangedMethod) {
      final args = call.arguments;
      if (args is Map) {
        final map = Map<Object?, Object?>.from(
          args,
        ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
        final container = ProviderScope.containerOf(context, listen: false);
        final currentKey =
            container
                .read(appSessionProvider)
                .valueOrNull
                ?.currentKey
                ?.trim() ??
            '';
        final eventKey = (map['workspaceKey'] as String? ?? '').trim();
        if (currentKey.isEmpty || eventKey.isEmpty || currentKey == eventKey) {
          final rawProgress = map['progress'];
          if (rawProgress is Map) {
            container
                .read(webDavBackupProgressTrackerProvider)
                .applySnapshot(
                  WebDavBackupProgressSnapshot.fromJson(
                    Map<Object?, Object?>.from(
                      rawProgress,
                    ).cast<String, dynamic>(),
                  ),
                );
          }
        }
      }
      return true;
    }
    if (call.method == desktopSyncPromptBackupExportIssueMethod) {
      final args = call.arguments;
      if (args is Map) {
        final map = Map<Object?, Object?>.from(
          args,
        ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
        final metadata = DesktopSyncPromptMetadata.fromJson(map);
        final rawIssue = map['issue'];
        if (rawIssue is Map) {
          final container = ProviderScope.containerOf(context, listen: false);
          final resolution = await container
              .read(desktopSyncFacadeProvider)
              .handleBackupExportIssuePrompt(
                deserializeWebDavBackupExportIssue(
                  Map<Object?, Object?>.from(rawIssue).cast<String, dynamic>(),
                ),
              );
          return serializeWebDavBackupExportPromptResponse(
            metadata: metadata,
            resolution: resolution,
          );
        }
      }
      return serializeWebDavBackupExportPromptResponse(
        metadata: const DesktopSyncPromptMetadata(requestId: '', sessionId: ''),
        resolution: const WebDavBackupExportResolution(
          action: WebDavBackupExportAction.abort,
        ),
      );
    }
    if (call.method == desktopSyncPromptBackupConfigRestoreMethod) {
      final args = call.arguments;
      if (args is Map) {
        final map = Map<Object?, Object?>.from(
          args,
        ).map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
        final metadata = DesktopSyncPromptMetadata.fromJson(map);
        final rawTypes = map['configTypes'];
        if (rawTypes is List) {
          final container = ProviderScope.containerOf(context, listen: false);
          final selected = await container
              .read(desktopSyncFacadeProvider)
              .handleBackupConfigRestorePrompt(
                deserializeWebDavBackupConfigTypes(rawTypes),
              );
          return serializeWebDavBackupConfigPromptResponse(
            metadata: metadata,
            selected: selected,
          );
        }
      }
      return serializeWebDavBackupConfigPromptResponse(
        metadata: const DesktopSyncPromptMetadata(requestId: '', sessionId: ''),
        selected: const [],
      );
    }
    if (call.method == desktopSubWindowExitMethod) {
      unawaited(_closeWindowForExit());
      return true;
    }
    if (call.method == desktopSubWindowIsVisibleMethod) {
      return _windowVisible;
    }
    if (call.method == desktopSettingsRefreshSessionMethod) {
      if (mounted) {
        setState(() {
          _settingsRootResetToken += 1;
        });
      }
      await _reloadWorkspaceStateFromStorage();
      await _refreshWorkspaceSnapshotWithRetry(showErrorOnFailure: false);
      return true;
    }
    if (call.method == desktopSettingsPingMethod) {
      return true;
    }
    return null;
  }

  Future<void> _closeWindowForExit() async {
    _windowVisible = false;
    try {
      await WindowController.fromWindowId(widget.windowId).close();
      return;
    } catch (_) {}
    if (defaultTargetPlatform == TargetPlatform.windows) {
      try {
        await windowManager.close();
      } catch (_) {}
    }
  }

  Future<DesktopWorkspaceSnapshot> _fetchWorkspaceSnapshot() async {
    final raw = await _invokeMainWindowMethod(
      desktopMainGetWorkspaceSnapshotMethod,
    );
    if (raw is! Map) {
      throw const FormatException('Invalid workspace snapshot payload.');
    }
    return DesktopWorkspaceSnapshot.fromJson(Map<Object?, Object?>.from(raw));
  }

  Future<void> _refreshWorkspaceSnapshotWithRetry({
    bool showErrorOnFailure = true,
  }) async {
    _setWorkspaceSnapshotState(loading: true, error: null);
    final delays = <Duration>[
      Duration.zero,
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 800),
    ];
    Object? lastError;
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!mounted) return;
      try {
        final snapshot = await _fetchWorkspaceSnapshot();
        if (!mounted) return;
        final container = ProviderScope.containerOf(context, listen: false);
        container
                .read(desktopSettingsWorkspaceSnapshotProvider.notifier)
                .state =
            snapshot;
        _setWorkspaceSnapshotState(loading: false, error: null);
        _bindWorkspaceChangeListeners();
        return;
      } catch (error) {
        lastError = error;
      }
    }

    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    if (lastError != null) {
      container
          .read(logManagerProvider)
          .warn('Desktop settings snapshot unavailable', error: lastError);
    }
    if (showErrorOnFailure) {
      container.read(desktopSettingsWorkspaceSnapshotProvider.notifier).state =
          null;
    }
    _setWorkspaceSnapshotState(
      loading: false,
      error: showErrorOnFailure
          ? context.tr(
              zh: '主窗口不可用，请从主窗口重新打开设置窗口。',
              en: 'Main window unavailable. Please reopen settings from the main window.',
            )
          : null,
    );
  }

  Future<void> _bringWindowToFront() async {
    final controller = WindowController.fromWindowId(widget.windowId);
    try {
      await controller.show();
      _windowVisible = true;
      unawaited(_notifyMainWindowVisibility(true));
    } catch (_) {
      // Ignore platform/channel failures.
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      try {
        await windowManager.ensureInitialized();
        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {
        // Ignore platform/channel failures.
      }
    }
  }

  Future<void> _closeWindow() async {
    _windowVisible = false;
    await _notifyMainWindowVisibility(false);
    if (mounted) {
      setState(() {
        _settingsRootResetToken += 1;
      });
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
    }
    // IMPORTANT: settings sub-window must stay warm for hot reopen.
    // Do NOT replace this with close(); always hide to preserve process state.
    final controller = WindowController.fromWindowId(widget.windowId);
    try {
      await controller.hide();
    } catch (_) {
      try {
        await controller.close();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_workspaceSnapshotLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _workspaceSnapshotError;
    if (error != null) {
      return _DesktopSettingsWindowErrorState(
        message: error,
        onRetry: () => unawaited(_refreshWorkspaceSnapshotWithRetry()),
        onClose: () => unawaited(_closeWindow()),
      );
    }
    return _DesktopSettingsWorkbench(
      rootResetToken: _settingsRootResetToken,
      targetRequest: _settingsTargetRequest,
      targetRequestToken: _settingsTargetRequestToken,
      onRequestClose: () => unawaited(_closeWindow()),
    );
  }
}

class _DesktopSettingsWindowErrorState extends StatelessWidget {
  const _DesktopSettingsWindowErrorState({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: onRetry,
                    child: Text(context.tr(zh: '重试', en: 'Retry')),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onClose,
                    child: Text(context.tr(zh: '关闭', en: 'Close')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DesktopSettingsPane {
  account,
  preferences,
  windowsRelated,
  ai,
  appLock,
  laboratory,
  components,
  feedback,
  importExport,
  about,
  userGuide,
  stats,
  widgets,
  apiPlugins,
}

class _DesktopSettingsWorkbench extends StatefulWidget {
  const _DesktopSettingsWorkbench({
    required this.rootResetToken,
    required this.targetRequest,
    required this.targetRequestToken,
    required this.onRequestClose,
  });

  final int rootResetToken;
  final DesktopSettingsWindowTarget? targetRequest;
  final int targetRequestToken;
  final VoidCallback onRequestClose;

  @override
  State<_DesktopSettingsWorkbench> createState() =>
      _DesktopSettingsWorkbenchState();
}

class _DesktopSettingsWorkbenchState extends State<_DesktopSettingsWorkbench> {
  var _pane = _DesktopSettingsPane.account;
  GlobalKey<NavigatorState> _paneNavigatorKey = GlobalKey<NavigatorState>();
  var _appliedTargetRequestToken = 0;
  WidgetBuilder? _pendingTargetRouteBuilder;

  @override
  void initState() {
    super.initState();
    _applyTargetRequestIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _DesktopSettingsWorkbench oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootResetToken != widget.rootResetToken) {
      _pane = _DesktopSettingsPane.account;
      _paneNavigatorKey = GlobalKey<NavigatorState>();
    }
    _applyTargetRequestIfNeeded();
  }

  void _applyTargetRequestIfNeeded() {
    if (_appliedTargetRequestToken == widget.targetRequestToken) return;
    final target = widget.targetRequest;
    if (target == null) return;
    _appliedTargetRequestToken = widget.targetRequestToken;
    switch (target) {
      case DesktopSettingsWindowTarget.ai:
        _pane = _DesktopSettingsPane.ai;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = null;
      case DesktopSettingsWindowTarget.aiProvider:
        _pane = _DesktopSettingsPane.ai;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const AiProviderSettingsScreen();
      case DesktopSettingsWindowTarget.quickPrompts:
        _pane = _DesktopSettingsPane.ai;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) =>
            const AiInsightPromptEditorScreen.custom();
      case DesktopSettingsWindowTarget.desktopShortcuts:
        _pane = _DesktopSettingsPane.windowsRelated;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) =>
            const DesktopShortcutsSettingsScreen();
      case DesktopSettingsWindowTarget.templates:
        _pane = _DesktopSettingsPane.components;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const TemplateSettingsScreen();
      case DesktopSettingsWindowTarget.memoToolbar:
        _pane = _DesktopSettingsPane.preferences;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const MemoToolbarSettingsScreen();
      case DesktopSettingsWindowTarget.location:
        _pane = _DesktopSettingsPane.components;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const LocationSettingsScreen();
      case DesktopSettingsWindowTarget.imageBed:
        _pane = _DesktopSettingsPane.components;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const ImageBedSettingsScreen();
      case DesktopSettingsWindowTarget.imageCompression:
        _pane = _DesktopSettingsPane.components;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) =>
            const ImageCompressionSettingsScreen();
      case DesktopSettingsWindowTarget.webDavBackup:
        _pane = _DesktopSettingsPane.components;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const WebDavSyncScreen();
      case DesktopSettingsWindowTarget.importData:
        _pane = _DesktopSettingsPane.importExport;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const ImportSourceScreen();
      case DesktopSettingsWindowTarget.exportMemos:
        _pane = _DesktopSettingsPane.importExport;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const ExportMemosScreen();
      case DesktopSettingsWindowTarget.localNetworkMigration:
        _pane = _DesktopSettingsPane.importExport;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const LocalNetworkMigrationScreen();
      case DesktopSettingsWindowTarget.desktopShortcutsOverview:
        _pane = _DesktopSettingsPane.windowsRelated;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = _buildDesktopShortcutsOverviewTarget;
      case DesktopSettingsWindowTarget.selfRepair:
        _pane = _DesktopSettingsPane.feedback;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const SelfRepairScreen();
      case DesktopSettingsWindowTarget.exportDiagnostics:
        _pane = _DesktopSettingsPane.feedback;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const ExportLogsScreen();
      case DesktopSettingsWindowTarget.feedback:
        _pane = _DesktopSettingsPane.feedback;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = null;
      case DesktopSettingsWindowTarget.releaseNotes:
        _pane = _DesktopSettingsPane.about;
        _paneNavigatorKey = GlobalKey<NavigatorState>();
        _pendingTargetRouteBuilder = (_) => const ReleaseNotesScreen();
    }
  }

  Widget _buildDesktopShortcutsOverviewTarget(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    final bindings = normalizeDesktopShortcutBindings(
      container.read(devicePreferencesProvider).desktopShortcutBindings,
    );
    return DesktopShortcutsOverviewScreen(bindings: bindings);
  }

  void _pushPendingTargetRouteIfNeeded() {
    final builder = _pendingTargetRouteBuilder;
    if (builder == null) return;
    _pendingTargetRouteBuilder = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_pushPaneRoute(MaterialPageRoute<void>(builder: builder)));
    });
  }

  void _selectPane(_DesktopSettingsPane pane) {
    if (_pane == pane) {
      _paneNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _pane = pane;
      _paneNavigatorKey = GlobalKey<NavigatorState>();
      _pendingTargetRouteBuilder = null;
    });
  }

  Future<T?> _pushPaneRoute<T>(Route<T> route) {
    final navigator = _paneNavigatorKey.currentState;
    if (navigator != null) return navigator.push<T>(route);
    return Navigator.of(context).push<T>(route);
  }

  bool _handleDesktopSettingsShortcuts(KeyEvent event) {
    if (!mounted || !isDesktopShortcutEnabled()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (event is! KeyDownEvent) return false;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final primaryPressed = isPrimaryShortcutModifierPressed(pressed);
    final altPressed = isAltModifierPressed(pressed);
    final container = ProviderScope.containerOf(context, listen: false);
    final bindings = normalizeDesktopShortcutBindings(
      container.read(devicePreferencesProvider).desktopShortcutBindings,
    );
    final overviewBinding = bindings[DesktopShortcutAction.shortcutOverview];
    final shortcutMatched =
        (overviewBinding != null &&
            matchesDesktopShortcut(
              event: event,
              pressedKeys: pressed,
              binding: overviewBinding,
            )) ||
        (event.logicalKey == LogicalKeyboardKey.f1 &&
            !primaryPressed &&
            !altPressed);
    if (!shortcutMatched) return false;

    container
        .read(logManagerProvider)
        .info(
          'Desktop shortcut matched in settings window',
          context: <String, Object?>{
            'action': DesktopShortcutAction.shortcutOverview.name,
            'keyId': event.logicalKey.keyId,
            'keyLabel': event.logicalKey.keyLabel,
          },
        );
    _pushPaneRoute(
      MaterialPageRoute<void>(
        builder: (_) => DesktopShortcutsOverviewScreen(bindings: bindings),
      ),
    );
    showTopToast(
      context,
      context.t.strings.legacy.msg_shortcuts_overview_opened,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _pushPendingTargetRouteIfNeeded();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.64);
    final leftBg = isDark ? const Color(0xFF1D1D1D) : const Color(0xFFF7F5F2);
    final rightBg = isDark ? const Color(0xFF181818) : const Color(0xFFEFEBE6);
    final divider = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0DBD3);
    final showAppCloseButton =
        Theme.of(context).platform != TargetPlatform.macOS;
    final chromeInsets = resolveDesktopWindowChromeInsets(
      platform: Theme.of(context).platform,
      contentExtendsIntoTitleBar: true,
    );
    final items = <_DesktopPaneItem>[
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.account,
        icon: Icons.person_outline,
        label: context.t.strings.legacy.msg_account_security,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.preferences,
        icon: Icons.tune,
        label: context.t.strings.legacy.msg_preferences,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.windowsRelated,
        icon: Icons.desktop_windows_outlined,
        label: context.tr(zh: 'Windows相关设置', en: 'Windows settings'),
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.ai,
        icon: Icons.smart_toy_outlined,
        label: context.t.strings.legacy.msg_ai_settings,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.appLock,
        icon: Icons.lock_outline,
        label: context.t.strings.legacy.msg_app_lock,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.laboratory,
        icon: Icons.science_outlined,
        label: context.t.strings.legacy.msg_laboratory,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.components,
        icon: Icons.extension_outlined,
        label: context.t.strings.legacy.msg_components,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.feedback,
        icon: Icons.chat_bubble_outline,
        label: context.t.strings.legacy.msg_feedback,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.importExport,
        icon: Icons.import_export,
        label: context.t.strings.legacy.msg_import_export,
      ),
      _DesktopPaneItem(
        pane: _DesktopSettingsPane.about,
        icon: Icons.info_outline,
        label: context.t.strings.legacy.msg_about,
      ),
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        return _handleDesktopSettingsShortcuts(event)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      },
      child: Column(
        children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151515) : const Color(0xFFF1ECE6),
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DragToMoveArea(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: 14 + chromeInsets.leading,
                        end: 14,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.t.strings.legacy.msg_settings,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showAppCloseButton)
                  IconButton(
                    tooltip: context.t.strings.legacy.msg_close,
                    icon: Icon(Icons.close, size: 18, color: textMuted),
                    onPressed: widget.onRequestClose,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 270,
                  child: ColoredBox(
                    color: leftBg,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                      children: [
                        for (final item in items)
                          _DesktopPaneNavTile(
                            icon: item.icon,
                            label: item.label,
                            selected: _pane == item.pane,
                            onTap: () => _selectPane(item.pane),
                          ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: divider),
                Expanded(
                  child: ColoredBox(
                    color: rightBg,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: KeyedSubtree(
                        key: ValueKey(_pane),
                        child: Navigator(
                          key: _paneNavigatorKey,
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => _DesktopPaneContent(pane: _pane),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPaneItem {
  const _DesktopPaneItem({
    required this.pane,
    required this.icon,
    required this.label,
  });

  final _DesktopSettingsPane pane;
  final IconData icon;
  final String label;
}

class _DesktopPaneNavTile extends StatelessWidget {
  const _DesktopPaneNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? MemoFlowPalette.primary.withValues(alpha: 0.22)
        : MemoFlowPalette.primary.withValues(alpha: 0.12);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.7 : 0.78);
    final fg = selected ? MemoFlowPalette.primary : textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: hoverBg,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPaneContent extends StatelessWidget {
  const _DesktopPaneContent({required this.pane});

  final _DesktopSettingsPane pane;

  @override
  Widget build(BuildContext context) {
    return switch (pane) {
      _DesktopSettingsPane.account => const AccountSecurityScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.preferences => const PreferencesSettingsScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.windowsRelated => const WindowsRelatedSettingsScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.ai => const AiSettingsScreen(showBackButton: false),
      _DesktopSettingsPane.appLock => const PasswordLockScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.laboratory => const LaboratoryScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.components => const ComponentsSettingsScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.feedback => const FeedbackScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.importExport => const ImportExportScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.about => const AboutUsScreen(showBackButton: false),
      _DesktopSettingsPane.userGuide => const UserGuideScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.stats => const StatsScreen(showBackButton: false),
      _DesktopSettingsPane.widgets => const WidgetsScreen(
        showBackButton: false,
      ),
      _DesktopSettingsPane.apiPlugins => const ApiPluginsScreen(
        showBackButton: false,
      ),
    };
  }
}
