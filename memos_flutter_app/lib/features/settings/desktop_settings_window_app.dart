import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_theme.dart';
import '../../core/memoflow_palette.dart';
import '../../core/desktop_quick_input_channel.dart';
import '../../i18n/strings.g.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import 'settings_screen.dart';

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
  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler(_handleMethodCall);
    unawaited(_reloadSessionFromStorage());
    unawaited(_initializeWindowManager());
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
      await DesktopMultiWindow.invokeMethod(
        0,
        desktopSubWindowVisibilityMethod,
        <String, dynamic>{'visible': visible},
      );
    } catch (_) {}
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int _) async {
    if (call.method == desktopSettingsFocusMethod) {
      await _bringWindowToFront();
      return true;
    }
    if (call.method == desktopSettingsRefreshSessionMethod) {
      await _reloadSessionFromStorage();
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
    final controller = WindowController.fromWindowId(widget.windowId);
    try {
      await controller.hide();
    } catch (_) {
      await controller.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      onRequestClose: () => unawaited(_closeWindow()),
      enableDragToMove: true,
    );
  }
}
