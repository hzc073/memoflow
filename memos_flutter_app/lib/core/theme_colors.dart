import 'package:flutter/material.dart';

enum AppThemeColor {
  brickRed,
  ochre,
  cypressGreen,
  duskPurple,
}

class AppThemeColorSpec {
  const AppThemeColorSpec({
    required this.primary,
    required this.primaryDark,
  });

  final Color primary;
  final Color primaryDark;
}

const Map<AppThemeColor, AppThemeColorSpec> _themeColorSpecs = {
  AppThemeColor.brickRed: AppThemeColorSpec(
    primary: Color(0xFFC0564D),
    primaryDark: Color(0xFFD16A61),
  ),
  AppThemeColor.ochre: AppThemeColorSpec(
    primary: Color(0xFFD48D4D),
    primaryDark: Color(0xFFE1A670),
  ),
  AppThemeColor.cypressGreen: AppThemeColorSpec(
    primary: Color(0xFF7E9B8F),
    primaryDark: Color(0xFF8FB1A4),
  ),
  AppThemeColor.duskPurple: AppThemeColorSpec(
    primary: Color(0xFF7C5A73),
    primaryDark: Color(0xFF95718B),
  ),
};

AppThemeColorSpec themeColorSpec(AppThemeColor color) {
  return _themeColorSpecs[color] ?? _themeColorSpecs[AppThemeColor.brickRed]!;
}
