import 'package:flutter/material.dart';

enum AppThemeColor {
  brickRed,
  ochre,
  cypressGreen,
  duskPurple,
  custom,
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

enum CustomThemeMode {
  auto,
  manual,
}

class CustomThemeColorPair {
  const CustomThemeColorPair({
    required this.light,
    required this.dark,
  });

  final Color light;
  final Color dark;

  Map<String, dynamic> toJson() => {
        'light': _colorToStorage(light),
        'dark': _colorToStorage(dark),
      };

  static CustomThemeColorPair? tryParse(Map<String, dynamic> json) {
    final light = _colorFromStorage(json['light']);
    final dark = _colorFromStorage(json['dark']);
    if (light == null || dark == null) return null;
    return CustomThemeColorPair(light: light, dark: dark);
  }
}

class CustomThemeSurfaces {
  const CustomThemeSurfaces({
    required this.background,
    required this.card,
    required this.border,
  });

  final Color background;
  final Color card;
  final Color border;

  CustomThemeSurfaces copyWith({
    Color? background,
    Color? card,
    Color? border,
  }) {
    return CustomThemeSurfaces(
      background: background ?? this.background,
      card: card ?? this.card,
      border: border ?? this.border,
    );
  }

  bool matches(CustomThemeSurfaces other) {
    return background == other.background && card == other.card && border == other.border;
  }

  Map<String, dynamic> toJson() => {
        'background': _colorToStorage(background),
        'card': _colorToStorage(card),
        'border': _colorToStorage(border),
      };

  static CustomThemeSurfaces? tryParse(Map<String, dynamic> json) {
    final background = _colorFromStorage(json['background']);
    final card = _colorFromStorage(json['card']);
    final border = _colorFromStorage(json['border']);
    if (background == null || card == null || border == null) return null;
    return CustomThemeSurfaces(background: background, card: card, border: border);
  }
}

class CustomThemeSurfacePair {
  const CustomThemeSurfacePair({
    required this.light,
    required this.dark,
  });

  final CustomThemeSurfaces light;
  final CustomThemeSurfaces dark;
}

CustomThemeSurfaces deriveThemeSurfaces({
  required Color seed,
  required Brightness brightness,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  return CustomThemeSurfaces(
    background: scheme.surfaceContainerLowest,
    card: brightness == Brightness.dark ? scheme.surfaceContainerLow : scheme.surface,
    border: scheme.outlineVariant,
  );
}

class CustomThemeSettings {
  const CustomThemeSettings({
    required this.mode,
    required this.autoLight,
    required this.manualLight,
    required this.manualDark,
    required this.manualSurfacesLight,
    required this.manualSurfacesDark,
    required this.history,
  });

  final CustomThemeMode mode;
  final Color autoLight;
  final Color manualLight;
  final Color manualDark;
  final CustomThemeSurfaces manualSurfacesLight;
  final CustomThemeSurfaces manualSurfacesDark;
  final List<CustomThemeColorPair> history;

  static const defaults = CustomThemeSettings(
    mode: CustomThemeMode.auto,
    autoLight: Color(0xFFC0564D),
    manualLight: Color(0xFFC0564D),
    manualDark: Color(0xFFD16A61),
    manualSurfacesLight: CustomThemeSurfaces(
      background: Color(0xFFF5F2ED),
      card: Color(0xFFFFFFFF),
      border: Color(0xFFE2DDD5),
    ),
    manualSurfacesDark: CustomThemeSurfaces(
      background: Color(0xFF121212),
      card: Color(0xFF1E1E1E),
      border: Color(0xFF2C2C2C),
    ),
    history: <CustomThemeColorPair>[],
  );

  CustomThemeColorPair resolvePair() {
    if (mode == CustomThemeMode.manual) {
      return CustomThemeColorPair(light: manualLight, dark: manualDark);
    }
    return CustomThemeColorPair(light: autoLight, dark: deriveAutoDarkColor(autoLight));
  }

  CustomThemeSurfacePair resolveSurfaces() {
    if (mode == CustomThemeMode.manual) {
      return CustomThemeSurfacePair(light: manualSurfacesLight, dark: manualSurfacesDark);
    }
    final pair = resolvePair();
    return CustomThemeSurfacePair(
      light: deriveThemeSurfaces(seed: pair.light, brightness: Brightness.light),
      dark: deriveThemeSurfaces(seed: pair.dark, brightness: Brightness.dark),
    );
  }

  CustomThemeSettings copyWith({
    CustomThemeMode? mode,
    Color? autoLight,
    Color? manualLight,
    Color? manualDark,
    CustomThemeSurfaces? manualSurfacesLight,
    CustomThemeSurfaces? manualSurfacesDark,
    List<CustomThemeColorPair>? history,
  }) {
    return CustomThemeSettings(
      mode: mode ?? this.mode,
      autoLight: autoLight ?? this.autoLight,
      manualLight: manualLight ?? this.manualLight,
      manualDark: manualDark ?? this.manualDark,
      manualSurfacesLight: manualSurfacesLight ?? this.manualSurfacesLight,
      manualSurfacesDark: manualSurfacesDark ?? this.manualSurfacesDark,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'autoLight': _colorToStorage(autoLight),
        'manualLight': _colorToStorage(manualLight),
        'manualDark': _colorToStorage(manualDark),
        'manualSurfacesLight': manualSurfacesLight.toJson(),
        'manualSurfacesDark': manualSurfacesDark.toJson(),
        'history': history.map((entry) => entry.toJson()).toList(growable: false),
      };

  factory CustomThemeSettings.fromJson(Map<String, dynamic> json) {
    final modeRaw = json['mode'];
    final mode = modeRaw is String
        ? CustomThemeMode.values.firstWhere(
            (e) => e.name == modeRaw,
            orElse: () => CustomThemeSettings.defaults.mode,
          )
        : CustomThemeSettings.defaults.mode;
    final autoLight = _colorFromStorage(json['autoLight']) ?? CustomThemeSettings.defaults.autoLight;
    final manualLight = _colorFromStorage(json['manualLight']) ?? CustomThemeSettings.defaults.manualLight;
    final manualDark = _colorFromStorage(json['manualDark']) ?? CustomThemeSettings.defaults.manualDark;
    final manualSurfacesLight = () {
      final raw = json['manualSurfacesLight'];
      if (raw is Map) {
        final parsed = CustomThemeSurfaces.tryParse(raw.cast<String, dynamic>());
        if (parsed != null) return parsed;
      }
      return deriveThemeSurfaces(seed: manualLight, brightness: Brightness.light);
    }();
    final manualSurfacesDark = () {
      final raw = json['manualSurfacesDark'];
      if (raw is Map) {
        final parsed = CustomThemeSurfaces.tryParse(raw.cast<String, dynamic>());
        if (parsed != null) return parsed;
      }
      return deriveThemeSurfaces(seed: manualDark, brightness: Brightness.dark);
    }();
    final history = <CustomThemeColorPair>[];
    final rawHistory = json['history'];
    if (rawHistory is List) {
      for (final entry in rawHistory) {
        if (entry is Map) {
          final pair = CustomThemeColorPair.tryParse(entry.cast<String, dynamic>());
          if (pair != null) {
            history.add(pair);
          }
        }
      }
    }
    if (history.length > 4) {
      history.removeRange(4, history.length);
    }
    return CustomThemeSettings(
      mode: mode,
      autoLight: autoLight,
      manualLight: manualLight,
      manualDark: manualDark,
      manualSurfacesLight: manualSurfacesLight,
      manualSurfacesDark: manualSurfacesDark,
      history: history,
    );
  }
}

Color deriveAutoDarkColor(Color light) {
  final hsl = HSLColor.fromColor(light);
  final nextLightness = (hsl.lightness + 0.08).clamp(0.0, 1.0);
  final nextSaturation = (hsl.saturation + 0.05).clamp(0.0, 1.0);
  return hsl.withLightness(nextLightness).withSaturation(nextSaturation).toColor();
}

int _colorToStorage(Color color) => color.toARGB32();

Color? _colorFromStorage(dynamic raw) {
  if (raw is int) {
    final value = raw;
    if (value < 0) return null;
    if (value <= 0xFFFFFF) {
      return Color(0xFF000000 | value);
    }
    return Color(value);
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    if (hex.length != 6 && hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    if (hex.length == 6) {
      return Color(0xFF000000 | parsed);
    }
    return Color(parsed);
  }
  return null;
}
