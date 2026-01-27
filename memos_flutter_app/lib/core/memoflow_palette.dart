import 'package:flutter/material.dart';

import 'theme_colors.dart';

class MemoFlowPalette {
  static Color primary = themeColorSpec(AppThemeColor.brickRed).primary;
  static Color primaryDark = themeColorSpec(AppThemeColor.brickRed).primaryDark;

  static const Color _defaultBackgroundLight = Color(0xFFF5F2ED);
  static const Color _defaultBackgroundDark = Color(0xFF121212);
  static const Color _defaultCardLight = Color(0xFFFFFFFF);
  static const Color _defaultCardDark = Color(0xFF1E1E1E);
  static const Color _defaultBorderLight = Color(0xFFE2DDD5);
  static const Color _defaultBorderDark = Color(0xFF2C2C2C);
  static const Color _defaultAudioSurfaceLight = Color(0xFFF9F7F4);
  static const Color _defaultAudioSurfaceDark = Color(0xFF181818);

  static void applyThemeColor(AppThemeColor color, {CustomThemeSettings? customTheme}) {
    if (color == AppThemeColor.custom) {
      final resolved = customTheme ?? CustomThemeSettings.defaults;
      final pair = resolved.resolvePair();
      primary = pair.light;
      primaryDark = pair.dark;
      if (resolved.mode == CustomThemeMode.manual) {
        _applyCustomSurfaces(resolved.manualSurfacesLight, resolved.manualSurfacesDark);
      } else {
        _applyDerivedSurfaces(pair);
      }
      return;
    }
    final spec = themeColorSpec(color);
    primary = spec.primary;
    primaryDark = spec.primaryDark;
    _resetSurfaces();
  }

  static Color backgroundLight = _defaultBackgroundLight;
  static Color backgroundDark = _defaultBackgroundDark;

  static Color cardLight = _defaultCardLight;
  static Color cardDark = _defaultCardDark;

  static Color borderLight = _defaultBorderLight;
  static Color borderDark = _defaultBorderDark;

  static const textLight = Color(0xFF3C3C3C);
  static const textDark = Color(0xFFE5E9F0);

  static Color audioSurfaceLight = _defaultAudioSurfaceLight;
  static Color audioSurfaceDark = _defaultAudioSurfaceDark;

  static const aiChipBlueLight = Color(0xFF5682A3);
  static const aiChipBlueDark = Color(0xFF7DAACC);

  static const reviewChipOrangeLight = Color(0xFFD48D4D);
  static const reviewChipOrangeDark = Color(0xFFE1A670);

  static void _applyDerivedSurfaces(CustomThemeColorPair pair) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: pair.light,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: pair.dark,
      brightness: Brightness.dark,
    );
    backgroundLight = lightScheme.surfaceContainerLowest;
    cardLight = lightScheme.surface;
    borderLight = lightScheme.outlineVariant;
    audioSurfaceLight = lightScheme.surfaceContainerLow;

    backgroundDark = darkScheme.surfaceContainerLowest;
    cardDark = darkScheme.surfaceContainerLow;
    borderDark = darkScheme.outlineVariant;
    audioSurfaceDark = darkScheme.surfaceContainerLow;
  }

  static void _applyCustomSurfaces(
    CustomThemeSurfaces light,
    CustomThemeSurfaces dark,
  ) {
    backgroundLight = light.background;
    cardLight = light.card;
    borderLight = light.border;
    audioSurfaceLight = light.card;

    backgroundDark = dark.background;
    cardDark = dark.card;
    borderDark = dark.border;
    audioSurfaceDark = dark.card;
  }

  static void _resetSurfaces() {
    backgroundLight = _defaultBackgroundLight;
    backgroundDark = _defaultBackgroundDark;
    cardLight = _defaultCardLight;
    cardDark = _defaultCardDark;
    borderLight = _defaultBorderLight;
    borderDark = _defaultBorderDark;
    audioSurfaceLight = _defaultAudioSurfaceLight;
    audioSurfaceDark = _defaultAudioSurfaceDark;
  }
}
