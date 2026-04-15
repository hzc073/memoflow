import 'package:flutter/material.dart';

class CollectionReaderTokens {
  const CollectionReaderTokens._();

  static const double topBarVerticalPadding = 8;
  static const double topBarHorizontalPadding = 10;
  static const double topBarIconSize = 22;
  static const double topBarActionSize = 40;
  static const double floatingButtonSize = 46;
  static const double floatingIconSize = 22;
  static const double bottomActionIconSize = 22;
  static const double chapterButtonWidth = 76;
  static const double progressChipHeight = 30;
  static const double brightnessStripWidth = 46;
  static const double overlayScrimAlpha = 0.08;
  static const double cardRadius = 18;
  static const double panelRadius = 20;
  static const double compactRadius = 14;

  static const EdgeInsets bottomPanelPadding = EdgeInsets.fromLTRB(
    12,
    8,
    12,
    10,
  );
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);
  static const EdgeInsets heroPadding = EdgeInsets.fromLTRB(20, 18, 20, 20);
  static const EdgeInsets toolBarPadding = EdgeInsets.fromLTRB(20, 0, 20, 16);
  static const EdgeInsets shelfListPadding = EdgeInsets.fromLTRB(20, 0, 20, 28);

  static Color resolveOverlayPanelColor(
    Color pageBackground, {
    required Brightness pageBrightness,
    required bool followPageStyle,
    required Brightness hostBrightness,
  }) {
    final effectiveBrightness = followPageStyle
        ? pageBrightness
        : hostBrightness;
    final baseBackground = followPageStyle
        ? pageBackground
        : (effectiveBrightness == Brightness.dark
              ? const Color(0xFF181A1F)
              : const Color(0xFFF8F4EE));
    final blendColor = effectiveBrightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    final alpha = effectiveBrightness == Brightness.dark ? 0.30 : 0.78;
    return Color.alphaBlend(
      blendColor.withValues(alpha: alpha),
      baseBackground,
    );
  }

  static Color resolveFloatingButtonColor(
    Color panelColor,
    Color foreground, {
    required Brightness brightness,
  }) {
    return Color.alphaBlend(
      foreground.withValues(alpha: brightness == Brightness.dark ? 0.08 : 0.04),
      panelColor,
    );
  }

  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(panelRadius));
}
