import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/desktop_shortcuts.dart';
import '../../core/app_theme.dart';
import '../../core/memoflow_palette.dart';
import '../../core/desktop_quick_input_channel.dart';
import '../../core/top_toast.dart';
import '../../i18n/strings.g.dart';
import '../../state/logging_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../stats/stats_screen.dart';
import 'about_us_screen.dart';
import 'account_security_screen.dart';
import 'ai_settings_screen.dart';
import 'api_plugins_screen.dart';
import 'components_settings_screen.dart';
import 'feedback_screen.dart';
import 'import_export_screen.dart';
import 'laboratory_screen.dart';
import 'password_lock_screen.dart';
import 'preferences_settings_screen.dart';
import 'desktop_shortcuts_overview_screen.dart';
import 'user_guide_screen.dart';
import 'widgets_screen.dart';
import 'windows_related_settings_screen.dart';

class DesktopSettingsWindowApp extends ConsumerWidget {
  const DesktopSettingsWindowApp({super.key, required this.windowId});

  final int windowId;

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
    AppPreferences prefs,
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
    final prefs = ref.watch(appPreferencesProvider);
    final accountKey = ref.watch(
      appSessionProvider.select((state) => state.valueOrNull?.currentKey),
    );
    final themeColor = prefs.resolveThemeColor(accountKey);
    final customTheme = prefs.resolveCustomTheme(accountKey);
    MemoFlowPalette.applyThemeColor(themeColor, customTheme: customTheme);
    final appLocale = _appLocaleFor(prefs.language);
    LocaleSettings.setLocale(appLocale);

    return TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MemoFlow Settings',
        theme: _applyPreferencesToTheme(buildAppTheme(Brightness.light), prefs),
        darkTheme: _applyPreferencesToTheme(
          buildAppTheme(Brightness.dark),
          prefs,
        ),
        themeMode: _themeModeFor(prefs.themeMode),
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
              textScaler: TextScaler.linear(_textScaleFor(prefs.fontSize)),
            ),
            child: _DesktopSettingsWindowFrame(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: DesktopSettingsWindowScreen(windowId: windowId),
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
  const DesktopSettingsWindowScreen({super.key, required this.windowId});

  final int windowId;

  @override
  State<DesktopSettingsWindowScreen> createState() =>
      _DesktopSettingsWindowScreenState();
}

class _DesktopSettingsWindowScreenState
    extends State<DesktopSettingsWindowScreen> {
  Future<bool>? _mainWindowChannelProbe;

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
    unawaited(_reloadSessionFromStorage());
    unawaited(_initializeWindowManager());
    unawaited(_notifyMainWindowVisibility(true));
  }

  @override
  void dispose() {
    unawaited(_notifyMainWindowVisibility(false));
    DesktopMultiWindow.setMethodHandler(null);
    super.dispose();
  }

  Future<void> _initializeWindowManager() async {
    try {
      await windowManager.ensureInitialized();
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        await windowManager.setBackgroundColor(const Color(0x00000000));
      }
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
    if (call.method == desktopSubWindowIsVisibleMethod) {
      try {
        await windowManager.ensureInitialized();
        return await windowManager.isVisible();
      } catch (_) {
        return true;
      }
    }
    if (call.method == desktopSettingsRefreshSessionMethod) {
      await _reloadSessionFromStorage();
      return true;
    }
    if (call.method == desktopSettingsPingMethod) {
      return true;
    }
    return null;
  }

  Future<void> _reloadSessionFromStorage() async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await container.read(appSessionProvider.notifier).reloadFromStorage();
    } catch (_) {}
  }

  Future<void> _bringWindowToFront() async {
    try {
      await windowManager.ensureInitialized();
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      } else {
        await windowManager.show();
      }
      await windowManager.focus();
    } catch (_) {
      // Ignore platform/channel failures.
    }
  }

  Future<void> _closeWindow() async {
    await _notifyMainWindowVisibility(false);
    if (mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
    }
    // IMPORTANT: settings sub-window must stay warm for hot reopen.
    // Do NOT replace this with close(); always hide to preserve process state.
    try {
      await windowManager.hide();
    } catch (_) {
      try {
        final controller = WindowController.fromWindowId(widget.windowId);
        await controller.hide();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DesktopSettingsWorkbench(
      onRequestClose: () => unawaited(_closeWindow()),
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
  const _DesktopSettingsWorkbench({required this.onRequestClose});

  final VoidCallback onRequestClose;

  @override
  State<_DesktopSettingsWorkbench> createState() =>
      _DesktopSettingsWorkbenchState();
}

class _DesktopSettingsWorkbenchState extends State<_DesktopSettingsWorkbench> {
  var _pane = _DesktopSettingsPane.account;

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
      container.read(appPreferencesProvider).desktopShortcutBindings,
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DesktopShortcutsOverviewScreen(bindings: bindings),
      ),
    );
    showTopToast(context, '已打开快捷键总览。');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.64);
    final leftBg = isDark ? const Color(0xFF1D1D1D) : const Color(0xFFF7F5F2);
    final rightBg = isDark ? const Color(0xFF181818) : const Color(0xFFEFEBE6);
    final divider = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0DBD3);
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
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            onTap: () => setState(() => _pane = item.pane),
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
                        child: _DesktopPaneContent(pane: _pane),
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
      _DesktopSettingsPane.account => const AccountSecurityScreen(),
      _DesktopSettingsPane.preferences => const PreferencesSettingsScreen(),
      _DesktopSettingsPane.windowsRelated =>
        const WindowsRelatedSettingsScreen(),
      _DesktopSettingsPane.ai => const AiSettingsScreen(),
      _DesktopSettingsPane.appLock => const PasswordLockScreen(),
      _DesktopSettingsPane.laboratory => const LaboratoryScreen(),
      _DesktopSettingsPane.components => const ComponentsSettingsScreen(),
      _DesktopSettingsPane.feedback => const FeedbackScreen(),
      _DesktopSettingsPane.importExport => const ImportExportScreen(),
      _DesktopSettingsPane.about => const AboutUsScreen(),
      _DesktopSettingsPane.userGuide => const UserGuideScreen(),
      _DesktopSettingsPane.stats => const StatsScreen(),
      _DesktopSettingsPane.widgets => const WidgetsScreen(),
      _DesktopSettingsPane.apiPlugins => const ApiPluginsScreen(),
    };
  }
}
