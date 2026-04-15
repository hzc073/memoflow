import 'package:flutter/material.dart';

import '../../data/models/collection_reader.dart';
import 'reader_file_image_provider.dart';

class ReaderBackgroundPalette {
  const ReaderBackgroundPalette({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.brightness,
    this.imageProvider,
  });

  final Color background;
  final Color foreground;
  final Color accent;
  final Brightness brightness;
  final ImageProvider<Object>? imageProvider;
}

ReaderBackgroundPalette resolveReaderBackgroundPalette(
  CollectionReaderPreferences preferences,
) {
  final fallback = _presetPalette(preferences.themePreset);
  final backgroundConfig = preferences.backgroundConfig;
  final imageProvider = switch (backgroundConfig.type) {
    CollectionReaderBackgroundType.imageAsset =>
      backgroundConfig.imagePath == null
      ? null
      : AssetImage(backgroundConfig.imagePath!),
    CollectionReaderBackgroundType.imageFile => buildReaderFileImageProvider(
      backgroundConfig.imagePath,
    ),
    _ => null,
  };
  switch (backgroundConfig.type) {
    case CollectionReaderBackgroundType.preset:
      return _presetPalette(backgroundConfig.preset ?? preferences.themePreset);
    case CollectionReaderBackgroundType.solidColor:
      final background = backgroundConfig.solidColor ?? fallback.background;
      final brightness = ThemeData.estimateBrightnessForColor(background);
      return ReaderBackgroundPalette(
        background: background.withValues(alpha: backgroundConfig.alpha),
        foreground: brightness == Brightness.dark
            ? const Color(0xFFF3F4F6)
            : const Color(0xFF1F2937),
        accent: fallback.accent,
        brightness: brightness,
      );
    case CollectionReaderBackgroundType.imageAsset:
    case CollectionReaderBackgroundType.imageFile:
      return ReaderBackgroundPalette(
        background: fallback.background.withValues(alpha: backgroundConfig.alpha),
        foreground: fallback.foreground,
        accent: fallback.accent,
        brightness: fallback.brightness,
        imageProvider: imageProvider,
      );
  }
}

ReaderBackgroundPalette _presetPalette(CollectionReaderThemePreset preset) {
  return switch (preset) {
    CollectionReaderThemePreset.paper => const ReaderBackgroundPalette(
      background: Color(0xFFF6F0E4),
      foreground: Color(0xFF2D2217),
      accent: Color(0xFF8C5A2D),
      brightness: Brightness.light,
    ),
    CollectionReaderThemePreset.eyeCare => const ReaderBackgroundPalette(
      background: Color(0xFFE7F1DF),
      foreground: Color(0xFF243024),
      accent: Color(0xFF4E7A4A),
      brightness: Brightness.light,
    ),
    CollectionReaderThemePreset.dark => const ReaderBackgroundPalette(
      background: Color(0xFF111318),
      foreground: Color(0xFFE7E8EC),
      accent: Color(0xFF8AB4F8),
      brightness: Brightness.dark,
    ),
    CollectionReaderThemePreset.gray => const ReaderBackgroundPalette(
      background: Color(0xFFF0F1F3),
      foreground: Color(0xFF1F2328),
      accent: Color(0xFF5D6B7A),
      brightness: Brightness.light,
    ),
  };
}
