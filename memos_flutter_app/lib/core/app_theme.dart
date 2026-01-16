import 'package:flutter/material.dart';

import 'memoflow_palette.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final scaffoldBackgroundColor =
      brightness == Brightness.dark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
  final seedColor = brightness == Brightness.dark ? MemoFlowPalette.primaryDark : MemoFlowPalette.primary;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scaffoldBackgroundColor.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: brightness == Brightness.dark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: colorScheme.onSurface),
      actionTextColor: colorScheme.primary,
    ),
  );
}
