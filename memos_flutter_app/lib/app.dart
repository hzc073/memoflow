import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'state/logging_provider.dart';
import 'state/preferences_provider.dart';
import 'state/session_provider.dart';
import 'state/theme_mode_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

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

  static TextTheme _applyFontFallback(TextTheme theme, List<String>? fallback) {
    if (fallback == null) return theme;
    TextStyle? apply(TextStyle? style) => style?.copyWith(fontFamilyFallback: fallback);
    return theme.copyWith(
      bodyLarge: apply(theme.bodyLarge),
      bodyMedium: apply(theme.bodyMedium),
      bodySmall: apply(theme.bodySmall),
      titleLarge: apply(theme.titleLarge),
      titleMedium: apply(theme.titleMedium),
      titleSmall: apply(theme.titleSmall),
    );
  }

  static ThemeData _applyPreferencesToTheme(ThemeData theme, AppPreferences prefs) {
    final lineHeight = _lineHeightFor(prefs.lineHeight);
    final fontFallback = prefs.useSystemFont
        ? null
        : const [
            'MiSans',
            'HarmonyOS Sans SC',
            'PingFang SC',
            'Microsoft YaHei',
            'Noto Sans CJK SC',
            'Noto Sans SC',
          ];

    return theme.copyWith(
      textTheme: _applyFontFallback(_applyLineHeight(theme.textTheme, lineHeight), fontFallback),
      primaryTextTheme: _applyFontFallback(_applyLineHeight(theme.primaryTextTheme, lineHeight), fontFallback),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);
    final session = sessionAsync.valueOrNull;
    final themeMode = ref.watch(appThemeModeProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final loggerService = ref.watch(loggerServiceProvider);
    final locale = _localeFor(prefs.language);
    final scale = _textScaleFor(prefs.fontSize);

    return MaterialApp(
      title: 'Memos',
      theme: _applyPreferencesToTheme(buildAppTheme(Brightness.light), prefs),
      darkTheme: _applyPreferencesToTheme(buildAppTheme(Brightness.dark), prefs),
      themeMode: themeMode,
      locale: locale,
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
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: sessionAsync.when(
        data: (session) => session.currentAccount == null ? const LoginScreen() : const HomeScreen(),
        loading: () {
          // Keep showing the previous screen while connecting so login inputs don't reset.
          if (session != null) {
            return session.currentAccount == null ? const LoginScreen() : const HomeScreen();
          }
          return const _SplashScreen();
        },
        error: (e, _) {
          if (session != null) {
            return session.currentAccount == null ? const LoginScreen() : const HomeScreen();
          }
          return LoginScreen(initialError: e.toString());
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
