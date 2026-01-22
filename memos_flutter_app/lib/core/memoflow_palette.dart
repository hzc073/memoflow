import 'package:flutter/material.dart';

import 'theme_colors.dart';

class MemoFlowPalette {
  static Color primary = themeColorSpec(AppThemeColor.brickRed).primary;
  static Color primaryDark = themeColorSpec(AppThemeColor.brickRed).primaryDark;

  static void applyThemeColor(AppThemeColor color) {
    final spec = themeColorSpec(color);
    primary = spec.primary;
    primaryDark = spec.primaryDark;
  }

  static const backgroundLight = Color(0xFFF5F2ED);
  static const backgroundDark = Color(0xFF121212);

  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1E1E1E);

  static const borderLight = Color(0xFFE2DDD5);
  static const borderDark = Color(0xFF2C2C2C);

  static const textLight = Color(0xFF3C3C3C);
  static const textDark = Color(0xFFE5E9F0);

  static const audioSurfaceLight = Color(0xFFF9F7F4);
  static const audioSurfaceDark = Color(0xFF181818);

  static const aiChipBlueLight = Color(0xFF5682A3);
  static const aiChipBlueDark = Color(0xFF7DAACC);

  static const reviewChipOrangeLight = Color(0xFFD48D4D);
  static const reviewChipOrangeDark = Color(0xFFE1A670);

}
