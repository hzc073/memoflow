import 'package:flutter/widgets.dart';

enum CollectionReaderMode { vertical, paged }

enum CollectionReaderPageAnimation { none, slide, simulation }

enum CollectionReaderBrightnessMode { system, manual }

enum CollectionReaderThemePreset { paper, eyeCare, dark, gray }

enum CollectionReaderFontWeightMode { normal, medium, bold }

enum CollectionReaderTitleMode { left, center, hidden }

enum CollectionReaderTipSlot {
  none,
  collectionTitle,
  chapterTitle,
  time,
  battery,
  batteryPercentage,
  page,
  totalProgress,
  pageAndTotal,
  timeBattery,
  timeBatteryPercentage,
}

enum CollectionReaderTipDisplayMode { hidden, inline, reserved }

enum CollectionReaderBackgroundType {
  preset,
  solidColor,
  imageAsset,
  imageFile,
}

enum CollectionReaderTapAction {
  none,
  menu,
  nextPage,
  prevPage,
  nextChapter,
  prevChapter,
  toc,
  search,
}

const Object _unset = Object();

class CollectionReaderTipLayout {
  const CollectionReaderTipLayout({
    required this.headerMode,
    required this.footerMode,
    required this.headerLeft,
    required this.headerCenter,
    required this.headerRight,
    required this.footerLeft,
    required this.footerCenter,
    required this.footerRight,
    this.tipColorOverride,
    this.tipDividerColorOverride,
  });

  static const defaults = CollectionReaderTipLayout(
    headerMode: CollectionReaderTipDisplayMode.reserved,
    footerMode: CollectionReaderTipDisplayMode.reserved,
    headerLeft: CollectionReaderTipSlot.time,
    headerCenter: CollectionReaderTipSlot.none,
    headerRight: CollectionReaderTipSlot.battery,
    footerLeft: CollectionReaderTipSlot.chapterTitle,
    footerCenter: CollectionReaderTipSlot.none,
    footerRight: CollectionReaderTipSlot.pageAndTotal,
  );

  final CollectionReaderTipDisplayMode headerMode;
  final CollectionReaderTipDisplayMode footerMode;
  final CollectionReaderTipSlot headerLeft;
  final CollectionReaderTipSlot headerCenter;
  final CollectionReaderTipSlot headerRight;
  final CollectionReaderTipSlot footerLeft;
  final CollectionReaderTipSlot footerCenter;
  final CollectionReaderTipSlot footerRight;
  final Color? tipColorOverride;
  final Color? tipDividerColorOverride;

  Map<String, Object?> toJson() => <String, Object?>{
    'headerMode': headerMode.name,
    'footerMode': footerMode.name,
    'headerLeft': headerLeft.name,
    'headerCenter': headerCenter.name,
    'headerRight': headerRight.name,
    'footerLeft': footerLeft.name,
    'footerCenter': footerCenter.name,
    'footerRight': footerRight.name,
    'tipColorOverride': _colorToJson(tipColorOverride),
    'tipDividerColorOverride': _colorToJson(tipDividerColorOverride),
  };

  factory CollectionReaderTipLayout.fromJson(Map<String, dynamic> json) {
    return CollectionReaderTipLayout(
      headerMode: _readEnum(
        json['headerMode'],
        CollectionReaderTipDisplayMode.values,
        defaults.headerMode,
      ),
      footerMode: _readEnum(
        json['footerMode'],
        CollectionReaderTipDisplayMode.values,
        defaults.footerMode,
      ),
      headerLeft: _readEnum(
        json['headerLeft'],
        CollectionReaderTipSlot.values,
        defaults.headerLeft,
      ),
      headerCenter: _readEnum(
        json['headerCenter'],
        CollectionReaderTipSlot.values,
        defaults.headerCenter,
      ),
      headerRight: _readEnum(
        json['headerRight'],
        CollectionReaderTipSlot.values,
        defaults.headerRight,
      ),
      footerLeft: _readEnum(
        json['footerLeft'],
        CollectionReaderTipSlot.values,
        defaults.footerLeft,
      ),
      footerCenter: _readEnum(
        json['footerCenter'],
        CollectionReaderTipSlot.values,
        defaults.footerCenter,
      ),
      footerRight: _readEnum(
        json['footerRight'],
        CollectionReaderTipSlot.values,
        defaults.footerRight,
      ),
      tipColorOverride: _readColor(json['tipColorOverride']),
      tipDividerColorOverride: _readColor(json['tipDividerColorOverride']),
    );
  }

  CollectionReaderTipLayout copyWith({
    CollectionReaderTipDisplayMode? headerMode,
    CollectionReaderTipDisplayMode? footerMode,
    CollectionReaderTipSlot? headerLeft,
    CollectionReaderTipSlot? headerCenter,
    CollectionReaderTipSlot? headerRight,
    CollectionReaderTipSlot? footerLeft,
    CollectionReaderTipSlot? footerCenter,
    CollectionReaderTipSlot? footerRight,
    Object? tipColorOverride = _unset,
    Object? tipDividerColorOverride = _unset,
  }) {
    return CollectionReaderTipLayout(
      headerMode: headerMode ?? this.headerMode,
      footerMode: footerMode ?? this.footerMode,
      headerLeft: headerLeft ?? this.headerLeft,
      headerCenter: headerCenter ?? this.headerCenter,
      headerRight: headerRight ?? this.headerRight,
      footerLeft: footerLeft ?? this.footerLeft,
      footerCenter: footerCenter ?? this.footerCenter,
      footerRight: footerRight ?? this.footerRight,
      tipColorOverride: identical(tipColorOverride, _unset)
          ? this.tipColorOverride
          : tipColorOverride as Color?,
      tipDividerColorOverride: identical(tipDividerColorOverride, _unset)
          ? this.tipDividerColorOverride
          : tipDividerColorOverride as Color?,
    );
  }
}

class CollectionReaderBackgroundConfig {
  const CollectionReaderBackgroundConfig({
    required this.type,
    required this.preset,
    required this.solidColor,
    required this.imagePath,
    required this.alpha,
  });

  static const defaults = CollectionReaderBackgroundConfig(
    type: CollectionReaderBackgroundType.preset,
    preset: CollectionReaderThemePreset.paper,
    solidColor: null,
    imagePath: null,
    alpha: 1,
  );

  final CollectionReaderBackgroundType type;
  final CollectionReaderThemePreset? preset;
  final Color? solidColor;
  final String? imagePath;
  final double alpha;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'preset': preset?.name,
    'solidColor': _colorToJson(solidColor),
    'imagePath': imagePath,
    'alpha': alpha,
  };

  factory CollectionReaderBackgroundConfig.fromJson(Map<String, dynamic> json) {
    return CollectionReaderBackgroundConfig(
      type: _readEnum(
        json['type'],
        CollectionReaderBackgroundType.values,
        defaults.type,
      ),
      preset: _readNullableEnum(
        json['preset'],
        CollectionReaderThemePreset.values,
      ),
      solidColor: _readColor(json['solidColor']),
      imagePath: _readTrimmedString(json['imagePath']),
      alpha: _normalizeBackgroundAlpha(
        _readDouble(json['alpha'], defaults.alpha),
      ),
    );
  }

  CollectionReaderBackgroundConfig copyWith({
    CollectionReaderBackgroundType? type,
    Object? preset = _unset,
    Object? solidColor = _unset,
    Object? imagePath = _unset,
    double? alpha,
  }) {
    return CollectionReaderBackgroundConfig(
      type: type ?? this.type,
      preset: identical(preset, _unset)
          ? this.preset
          : preset as CollectionReaderThemePreset?,
      solidColor: identical(solidColor, _unset)
          ? this.solidColor
          : solidColor as Color?,
      imagePath: identical(imagePath, _unset)
          ? this.imagePath
          : imagePath as String?,
      alpha: _normalizeBackgroundAlpha(alpha ?? this.alpha),
    );
  }
}

class CollectionReaderStyleCard {
  const CollectionReaderStyleCard({
    required this.id,
    required this.name,
    required this.themePreset,
    required this.backgroundConfig,
  });

  final String id;
  final String name;
  final CollectionReaderThemePreset themePreset;
  final CollectionReaderBackgroundConfig backgroundConfig;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'themePreset': themePreset.name,
    'backgroundConfig': backgroundConfig.toJson(),
  };

  factory CollectionReaderStyleCard.fromJson(Map<String, dynamic> json) {
    final backgroundRaw = json['backgroundConfig'];
    return CollectionReaderStyleCard(
      id: _readTrimmedString(json['id']) ?? '',
      name: _readTrimmedString(json['name']) ?? '',
      themePreset: _readEnum(
        json['themePreset'],
        CollectionReaderThemePreset.values,
        CollectionReaderThemePreset.paper,
      ),
      backgroundConfig:
          _readNestedObject(
            backgroundRaw,
            CollectionReaderBackgroundConfig.fromJson,
          ) ??
          CollectionReaderBackgroundConfig.defaults,
    );
  }

  CollectionReaderStyleCard copyWith({
    String? id,
    String? name,
    CollectionReaderThemePreset? themePreset,
    CollectionReaderBackgroundConfig? backgroundConfig,
  }) {
    return CollectionReaderStyleCard(
      id: id ?? this.id,
      name: name ?? this.name,
      themePreset: themePreset ?? this.themePreset,
      backgroundConfig: backgroundConfig ?? this.backgroundConfig,
    );
  }
}

class CollectionReaderTapRegionConfig {
  const CollectionReaderTapRegionConfig({
    required this.topLeft,
    required this.topCenter,
    required this.topRight,
    required this.middleLeft,
    required this.middleCenter,
    required this.middleRight,
    required this.bottomLeft,
    required this.bottomCenter,
    required this.bottomRight,
  });

  static const defaults = CollectionReaderTapRegionConfig(
    topLeft: CollectionReaderTapAction.prevPage,
    topCenter: CollectionReaderTapAction.menu,
    topRight: CollectionReaderTapAction.nextPage,
    middleLeft: CollectionReaderTapAction.prevPage,
    middleCenter: CollectionReaderTapAction.menu,
    middleRight: CollectionReaderTapAction.nextPage,
    bottomLeft: CollectionReaderTapAction.prevPage,
    bottomCenter: CollectionReaderTapAction.menu,
    bottomRight: CollectionReaderTapAction.nextPage,
  );

  final CollectionReaderTapAction topLeft;
  final CollectionReaderTapAction topCenter;
  final CollectionReaderTapAction topRight;
  final CollectionReaderTapAction middleLeft;
  final CollectionReaderTapAction middleCenter;
  final CollectionReaderTapAction middleRight;
  final CollectionReaderTapAction bottomLeft;
  final CollectionReaderTapAction bottomCenter;
  final CollectionReaderTapAction bottomRight;

  Map<String, Object?> toJson() => <String, Object?>{
    'topLeft': topLeft.name,
    'topCenter': topCenter.name,
    'topRight': topRight.name,
    'middleLeft': middleLeft.name,
    'middleCenter': middleCenter.name,
    'middleRight': middleRight.name,
    'bottomLeft': bottomLeft.name,
    'bottomCenter': bottomCenter.name,
    'bottomRight': bottomRight.name,
  };

  factory CollectionReaderTapRegionConfig.fromJson(Map<String, dynamic> json) {
    return CollectionReaderTapRegionConfig(
      topLeft: _readEnum(
        json['topLeft'],
        CollectionReaderTapAction.values,
        defaults.topLeft,
      ),
      topCenter: _readEnum(
        json['topCenter'],
        CollectionReaderTapAction.values,
        defaults.topCenter,
      ),
      topRight: _readEnum(
        json['topRight'],
        CollectionReaderTapAction.values,
        defaults.topRight,
      ),
      middleLeft: _readEnum(
        json['middleLeft'],
        CollectionReaderTapAction.values,
        defaults.middleLeft,
      ),
      middleCenter: _readEnum(
        json['middleCenter'],
        CollectionReaderTapAction.values,
        defaults.middleCenter,
      ),
      middleRight: _readEnum(
        json['middleRight'],
        CollectionReaderTapAction.values,
        defaults.middleRight,
      ),
      bottomLeft: _readEnum(
        json['bottomLeft'],
        CollectionReaderTapAction.values,
        defaults.bottomLeft,
      ),
      bottomCenter: _readEnum(
        json['bottomCenter'],
        CollectionReaderTapAction.values,
        defaults.bottomCenter,
      ),
      bottomRight: _readEnum(
        json['bottomRight'],
        CollectionReaderTapAction.values,
        defaults.bottomRight,
      ),
    );
  }

  CollectionReaderTapRegionConfig copyWith({
    CollectionReaderTapAction? topLeft,
    CollectionReaderTapAction? topCenter,
    CollectionReaderTapAction? topRight,
    CollectionReaderTapAction? middleLeft,
    CollectionReaderTapAction? middleCenter,
    CollectionReaderTapAction? middleRight,
    CollectionReaderTapAction? bottomLeft,
    CollectionReaderTapAction? bottomCenter,
    CollectionReaderTapAction? bottomRight,
  }) {
    return CollectionReaderTapRegionConfig(
      topLeft: topLeft ?? this.topLeft,
      topCenter: topCenter ?? this.topCenter,
      topRight: topRight ?? this.topRight,
      middleLeft: middleLeft ?? this.middleLeft,
      middleCenter: middleCenter ?? this.middleCenter,
      middleRight: middleRight ?? this.middleRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      bottomCenter: bottomCenter ?? this.bottomCenter,
      bottomRight: bottomRight ?? this.bottomRight,
    );
  }
}

class CollectionReaderDisplayConfig {
  const CollectionReaderDisplayConfig({
    required this.hideStatusBar,
    required this.hideNavigationBar,
    required this.padDisplayCutouts,
    required this.showBrightnessOverlay,
    required this.followPageStyleForBars,
    required this.showReadTitleAddition,
    required this.keepScreenAwakeInReader,
    required this.allowTextSelection,
    required this.previewImageOnTap,
  });

  static const defaults = CollectionReaderDisplayConfig(
    hideStatusBar: false,
    hideNavigationBar: false,
    padDisplayCutouts: false,
    showBrightnessOverlay: true,
    followPageStyleForBars: false,
    showReadTitleAddition: true,
    keepScreenAwakeInReader: false,
    allowTextSelection: false,
    previewImageOnTap: true,
  );

  final bool hideStatusBar;
  final bool hideNavigationBar;
  final bool padDisplayCutouts;
  final bool showBrightnessOverlay;
  final bool followPageStyleForBars;
  final bool showReadTitleAddition;
  final bool keepScreenAwakeInReader;
  final bool allowTextSelection;
  final bool previewImageOnTap;

  Map<String, Object?> toJson() => <String, Object?>{
    'hideStatusBar': hideStatusBar,
    'hideNavigationBar': hideNavigationBar,
    'padDisplayCutouts': padDisplayCutouts,
    'showBrightnessOverlay': showBrightnessOverlay,
    'followPageStyleForBars': followPageStyleForBars,
    'showReadTitleAddition': showReadTitleAddition,
    'keepScreenAwakeInReader': keepScreenAwakeInReader,
    'allowTextSelection': allowTextSelection,
    'previewImageOnTap': previewImageOnTap,
  };

  factory CollectionReaderDisplayConfig.fromJson(Map<String, dynamic> json) {
    return CollectionReaderDisplayConfig(
      hideStatusBar: _readBool(json['hideStatusBar'], defaults.hideStatusBar),
      hideNavigationBar: _readBool(
        json['hideNavigationBar'],
        defaults.hideNavigationBar,
      ),
      padDisplayCutouts: _readBool(
        json['padDisplayCutouts'],
        defaults.padDisplayCutouts,
      ),
      showBrightnessOverlay: _readBool(
        json['showBrightnessOverlay'],
        defaults.showBrightnessOverlay,
      ),
      followPageStyleForBars: _readBool(
        json['followPageStyleForBars'],
        defaults.followPageStyleForBars,
      ),
      showReadTitleAddition: _readBool(
        json['showReadTitleAddition'],
        defaults.showReadTitleAddition,
      ),
      keepScreenAwakeInReader: _readBool(
        json['keepScreenAwakeInReader'],
        defaults.keepScreenAwakeInReader,
      ),
      allowTextSelection: _readBool(
        json['allowTextSelection'],
        defaults.allowTextSelection,
      ),
      previewImageOnTap: _readBool(
        json['previewImageOnTap'],
        defaults.previewImageOnTap,
      ),
    );
  }

  CollectionReaderDisplayConfig copyWith({
    bool? hideStatusBar,
    bool? hideNavigationBar,
    bool? padDisplayCutouts,
    bool? showBrightnessOverlay,
    bool? followPageStyleForBars,
    bool? showReadTitleAddition,
    bool? keepScreenAwakeInReader,
    bool? allowTextSelection,
    bool? previewImageOnTap,
  }) {
    return CollectionReaderDisplayConfig(
      hideStatusBar: hideStatusBar ?? this.hideStatusBar,
      hideNavigationBar: hideNavigationBar ?? this.hideNavigationBar,
      padDisplayCutouts: padDisplayCutouts ?? this.padDisplayCutouts,
      showBrightnessOverlay:
          showBrightnessOverlay ?? this.showBrightnessOverlay,
      followPageStyleForBars:
          followPageStyleForBars ?? this.followPageStyleForBars,
      showReadTitleAddition:
          showReadTitleAddition ?? this.showReadTitleAddition,
      keepScreenAwakeInReader:
          keepScreenAwakeInReader ?? this.keepScreenAwakeInReader,
      allowTextSelection: allowTextSelection ?? this.allowTextSelection,
      previewImageOnTap: previewImageOnTap ?? this.previewImageOnTap,
    );
  }
}

class CollectionReaderInputConfig {
  const CollectionReaderInputConfig({
    required this.mouseWheelPageTurn,
    required this.volumeKeyPageTurn,
    required this.longPressKeyPageTurn,
    required this.pageTouchSlop,
  });

  static const defaults = CollectionReaderInputConfig(
    mouseWheelPageTurn: true,
    volumeKeyPageTurn: true,
    longPressKeyPageTurn: false,
    pageTouchSlop: 18,
  );

  final bool mouseWheelPageTurn;
  final bool volumeKeyPageTurn;
  final bool longPressKeyPageTurn;
  final int pageTouchSlop;

  Map<String, Object?> toJson() => <String, Object?>{
    'mouseWheelPageTurn': mouseWheelPageTurn,
    'volumeKeyPageTurn': volumeKeyPageTurn,
    'longPressKeyPageTurn': longPressKeyPageTurn,
    'pageTouchSlop': pageTouchSlop,
  };

  factory CollectionReaderInputConfig.fromJson(Map<String, dynamic> json) {
    return CollectionReaderInputConfig(
      mouseWheelPageTurn: _readBool(
        json['mouseWheelPageTurn'],
        defaults.mouseWheelPageTurn,
      ),
      volumeKeyPageTurn: _readBool(
        json['volumeKeyPageTurn'],
        defaults.volumeKeyPageTurn,
      ),
      longPressKeyPageTurn: _readBool(
        json['longPressKeyPageTurn'],
        defaults.longPressKeyPageTurn,
      ),
      pageTouchSlop: _normalizePageTouchSlop(
        _readInt(json['pageTouchSlop'], defaults.pageTouchSlop),
      ),
    );
  }

  CollectionReaderInputConfig copyWith({
    bool? mouseWheelPageTurn,
    bool? volumeKeyPageTurn,
    bool? longPressKeyPageTurn,
    int? pageTouchSlop,
  }) {
    return CollectionReaderInputConfig(
      mouseWheelPageTurn: mouseWheelPageTurn ?? this.mouseWheelPageTurn,
      volumeKeyPageTurn: volumeKeyPageTurn ?? this.volumeKeyPageTurn,
      longPressKeyPageTurn: longPressKeyPageTurn ?? this.longPressKeyPageTurn,
      pageTouchSlop: _normalizePageTouchSlop(
        pageTouchSlop ?? this.pageTouchSlop,
      ),
    );
  }
}

class CollectionReaderPreferences {
  const CollectionReaderPreferences({
    required this.mode,
    required this.pageAnimation,
    required this.themePreset,
    required this.brightnessMode,
    required this.brightness,
    required this.textScale,
    required this.lineSpacing,
    required this.pagePadding,
    required this.autoPageSeconds,
    required this.readerFontFamily,
    required this.readerFontFile,
    required this.fontWeightMode,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.paragraphIndentChars,
    required this.titleMode,
    required this.titleScale,
    required this.titleTopSpacing,
    required this.titleBottomSpacing,
    required this.headerPadding,
    required this.footerPadding,
    required this.showHeaderLine,
    required this.showFooterLine,
    required this.tipLayout,
    required this.backgroundConfig,
    required this.displayConfig,
    required this.inputConfig,
    required this.tapRegionConfig,
    required this.savedStyleCards,
  });

  static const CollectionReaderPreferences defaults =
      CollectionReaderPreferences(
        mode: CollectionReaderMode.vertical,
        pageAnimation: CollectionReaderPageAnimation.simulation,
        themePreset: CollectionReaderThemePreset.paper,
        brightnessMode: CollectionReaderBrightnessMode.system,
        brightness: 1,
        textScale: 1,
        lineSpacing: 1.55,
        pagePadding: EdgeInsets.fromLTRB(20, 24, 20, 28),
        autoPageSeconds: 10,
        readerFontFamily: null,
        readerFontFile: null,
        fontWeightMode: CollectionReaderFontWeightMode.normal,
        letterSpacing: 0,
        paragraphSpacing: 8,
        paragraphIndentChars: 2,
        titleMode: CollectionReaderTitleMode.left,
        titleScale: 1,
        titleTopSpacing: 0,
        titleBottomSpacing: 0,
        headerPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
        footerPadding: EdgeInsets.fromLTRB(16, 6, 16, 6),
        showHeaderLine: false,
        showFooterLine: true,
        tipLayout: CollectionReaderTipLayout.defaults,
        backgroundConfig: CollectionReaderBackgroundConfig.defaults,
        displayConfig: CollectionReaderDisplayConfig.defaults,
        inputConfig: CollectionReaderInputConfig.defaults,
        tapRegionConfig: CollectionReaderTapRegionConfig.defaults,
        savedStyleCards: <CollectionReaderStyleCard>[],
      );

  final CollectionReaderMode mode;
  final CollectionReaderPageAnimation pageAnimation;
  final CollectionReaderThemePreset themePreset;
  final CollectionReaderBrightnessMode brightnessMode;
  final double brightness;
  final double textScale;
  final double lineSpacing;
  final EdgeInsets pagePadding;
  final int autoPageSeconds;

  final String? readerFontFamily;
  final String? readerFontFile;
  final CollectionReaderFontWeightMode fontWeightMode;
  final double letterSpacing;
  final double paragraphSpacing;
  final int paragraphIndentChars;

  final CollectionReaderTitleMode titleMode;
  final double titleScale;
  final double titleTopSpacing;
  final double titleBottomSpacing;

  final EdgeInsets headerPadding;
  final EdgeInsets footerPadding;
  final bool showHeaderLine;
  final bool showFooterLine;

  final CollectionReaderTipLayout tipLayout;
  final CollectionReaderBackgroundConfig backgroundConfig;
  final CollectionReaderDisplayConfig displayConfig;
  final CollectionReaderInputConfig inputConfig;
  final CollectionReaderTapRegionConfig tapRegionConfig;
  final List<CollectionReaderStyleCard> savedStyleCards;

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    'pageAnimation': pageAnimation.name,
    'themePreset': themePreset.name,
    'brightnessMode': brightnessMode.name,
    'brightness': brightness,
    'textScale': textScale,
    'lineSpacing': lineSpacing,
    'pagePadding': _edgeInsetsToJson(pagePadding),
    'autoPageSeconds': autoPageSeconds,
    'readerFontFamily': readerFontFamily,
    'readerFontFile': readerFontFile,
    'fontWeightMode': fontWeightMode.name,
    'letterSpacing': letterSpacing,
    'paragraphSpacing': paragraphSpacing,
    'paragraphIndentChars': paragraphIndentChars,
    'titleMode': titleMode.name,
    'titleScale': titleScale,
    'titleTopSpacing': titleTopSpacing,
    'titleBottomSpacing': titleBottomSpacing,
    'headerPadding': _edgeInsetsToJson(headerPadding),
    'footerPadding': _edgeInsetsToJson(footerPadding),
    'showHeaderLine': showHeaderLine,
    'showFooterLine': showFooterLine,
    'tipLayout': tipLayout.toJson(),
    'backgroundConfig': backgroundConfig.toJson(),
    'displayConfig': displayConfig.toJson(),
    'inputConfig': inputConfig.toJson(),
    'tapRegionConfig': tapRegionConfig.toJson(),
    'savedStyleCards': savedStyleCards
        .map((card) => card.toJson())
        .toList(growable: false),
  };

  factory CollectionReaderPreferences.fromJson(Map<String, dynamic> json) {
    final pagePadding = _readPagePadding(json['pagePadding']);
    final themePreset = _readEnum(
      json['themePreset'],
      CollectionReaderThemePreset.values,
      defaults.themePreset,
    );
    final backgroundRaw = json['backgroundConfig'];
    final backgroundConfig = backgroundRaw is Map<String, dynamic>
        ? CollectionReaderBackgroundConfig.fromJson(backgroundRaw)
        : backgroundRaw is Map
        ? CollectionReaderBackgroundConfig.fromJson(
            backgroundRaw.cast<String, dynamic>(),
          )
        : defaults.backgroundConfig.copyWith(preset: themePreset);
    return CollectionReaderPreferences(
      mode: _readEnum(json['mode'], CollectionReaderMode.values, defaults.mode),
      pageAnimation: _readEnum(
        json['pageAnimation'],
        CollectionReaderPageAnimation.values,
        defaults.pageAnimation,
      ),
      themePreset: themePreset,
      brightnessMode: _readEnum(
        json['brightnessMode'],
        CollectionReaderBrightnessMode.values,
        defaults.brightnessMode,
      ),
      brightness: _normalizeBrightness(_readDouble(json['brightness'], 1)),
      textScale: _normalizeTextScale(_readDouble(json['textScale'], 1)),
      lineSpacing: _normalizeLineSpacing(
        _readDouble(json['lineSpacing'], defaults.lineSpacing),
      ),
      pagePadding: pagePadding,
      autoPageSeconds: _normalizeAutoPageSeconds(
        _readInt(json['autoPageSeconds'], defaults.autoPageSeconds),
      ),
      readerFontFamily: _readTrimmedString(json['readerFontFamily']),
      readerFontFile: _readTrimmedString(json['readerFontFile']),
      fontWeightMode: _readEnum(
        json['fontWeightMode'],
        CollectionReaderFontWeightMode.values,
        defaults.fontWeightMode,
      ),
      letterSpacing: _normalizeLetterSpacing(
        _readDouble(json['letterSpacing'], defaults.letterSpacing),
      ),
      paragraphSpacing: _normalizeParagraphSpacing(
        _readDouble(json['paragraphSpacing'], defaults.paragraphSpacing),
      ),
      paragraphIndentChars: _normalizeParagraphIndentChars(
        _readInt(json['paragraphIndentChars'], defaults.paragraphIndentChars),
      ),
      titleMode: _readEnum(
        json['titleMode'],
        CollectionReaderTitleMode.values,
        defaults.titleMode,
      ),
      titleScale: _normalizeTitleScale(
        _readDouble(json['titleScale'], defaults.titleScale),
      ),
      titleTopSpacing: _normalizeSpacing(
        _readDouble(json['titleTopSpacing'], defaults.titleTopSpacing),
      ),
      titleBottomSpacing: _normalizeSpacing(
        _readDouble(json['titleBottomSpacing'], defaults.titleBottomSpacing),
      ),
      headerPadding: _readEdgeInsets(
        json['headerPadding'],
        defaults.headerPadding,
      ),
      footerPadding: _readEdgeInsets(
        json['footerPadding'],
        defaults.footerPadding,
      ),
      showHeaderLine: _readBool(
        json['showHeaderLine'],
        defaults.showHeaderLine,
      ),
      showFooterLine: _readBool(
        json['showFooterLine'],
        defaults.showFooterLine,
      ),
      tipLayout:
          _readNestedObject(
            json['tipLayout'],
            CollectionReaderTipLayout.fromJson,
          ) ??
          defaults.tipLayout,
      backgroundConfig: backgroundConfig.copyWith(
        preset: backgroundConfig.preset ?? themePreset,
      ),
      displayConfig:
          _readNestedObject(
            json['displayConfig'],
            CollectionReaderDisplayConfig.fromJson,
          ) ??
          defaults.displayConfig,
      inputConfig:
          _readNestedObject(
            json['inputConfig'],
            CollectionReaderInputConfig.fromJson,
          ) ??
          defaults.inputConfig,
      tapRegionConfig:
          _readNestedObject(
            json['tapRegionConfig'],
            CollectionReaderTapRegionConfig.fromJson,
          ) ??
          defaults.tapRegionConfig,
      savedStyleCards: _readStyleCards(json['savedStyleCards']),
    );
  }

  CollectionReaderPreferences copyWith({
    CollectionReaderMode? mode,
    CollectionReaderPageAnimation? pageAnimation,
    CollectionReaderThemePreset? themePreset,
    CollectionReaderBrightnessMode? brightnessMode,
    double? brightness,
    double? textScale,
    double? lineSpacing,
    EdgeInsets? pagePadding,
    int? autoPageSeconds,
    Object? readerFontFamily = _unset,
    Object? readerFontFile = _unset,
    CollectionReaderFontWeightMode? fontWeightMode,
    double? letterSpacing,
    double? paragraphSpacing,
    int? paragraphIndentChars,
    CollectionReaderTitleMode? titleMode,
    double? titleScale,
    double? titleTopSpacing,
    double? titleBottomSpacing,
    EdgeInsets? headerPadding,
    EdgeInsets? footerPadding,
    bool? showHeaderLine,
    bool? showFooterLine,
    CollectionReaderTipLayout? tipLayout,
    CollectionReaderBackgroundConfig? backgroundConfig,
    CollectionReaderDisplayConfig? displayConfig,
    CollectionReaderInputConfig? inputConfig,
    CollectionReaderTapRegionConfig? tapRegionConfig,
    List<CollectionReaderStyleCard>? savedStyleCards,
  }) {
    final nextThemePreset = themePreset ?? this.themePreset;
    final nextBackgroundConfig =
        backgroundConfig ??
        (themePreset == null
            ? this.backgroundConfig
            : this.backgroundConfig.type ==
                  CollectionReaderBackgroundType.preset
            ? this.backgroundConfig.copyWith(preset: nextThemePreset)
            : this.backgroundConfig);
    return CollectionReaderPreferences(
      mode: mode ?? this.mode,
      pageAnimation: pageAnimation ?? this.pageAnimation,
      themePreset: nextThemePreset,
      brightnessMode: brightnessMode ?? this.brightnessMode,
      brightness: _normalizeBrightness(brightness ?? this.brightness),
      textScale: _normalizeTextScale(textScale ?? this.textScale),
      lineSpacing: _normalizeLineSpacing(lineSpacing ?? this.lineSpacing),
      pagePadding: pagePadding ?? this.pagePadding,
      autoPageSeconds: _normalizeAutoPageSeconds(
        autoPageSeconds ?? this.autoPageSeconds,
      ),
      readerFontFamily: identical(readerFontFamily, _unset)
          ? this.readerFontFamily
          : readerFontFamily as String?,
      readerFontFile: identical(readerFontFile, _unset)
          ? this.readerFontFile
          : readerFontFile as String?,
      fontWeightMode: fontWeightMode ?? this.fontWeightMode,
      letterSpacing: _normalizeLetterSpacing(
        letterSpacing ?? this.letterSpacing,
      ),
      paragraphSpacing: _normalizeParagraphSpacing(
        paragraphSpacing ?? this.paragraphSpacing,
      ),
      paragraphIndentChars: _normalizeParagraphIndentChars(
        paragraphIndentChars ?? this.paragraphIndentChars,
      ),
      titleMode: titleMode ?? this.titleMode,
      titleScale: _normalizeTitleScale(titleScale ?? this.titleScale),
      titleTopSpacing: _normalizeSpacing(
        titleTopSpacing ?? this.titleTopSpacing,
      ),
      titleBottomSpacing: _normalizeSpacing(
        titleBottomSpacing ?? this.titleBottomSpacing,
      ),
      headerPadding: headerPadding ?? this.headerPadding,
      footerPadding: footerPadding ?? this.footerPadding,
      showHeaderLine: showHeaderLine ?? this.showHeaderLine,
      showFooterLine: showFooterLine ?? this.showFooterLine,
      tipLayout: tipLayout ?? this.tipLayout,
      backgroundConfig: nextBackgroundConfig,
      displayConfig: displayConfig ?? this.displayConfig,
      inputConfig: inputConfig ?? this.inputConfig,
      tapRegionConfig: tapRegionConfig ?? this.tapRegionConfig,
      savedStyleCards: savedStyleCards ?? this.savedStyleCards,
    );
  }
}

List<CollectionReaderStyleCard> _readStyleCards(Object? raw) {
  if (raw is List) {
    return raw
        .map((entry) {
          if (entry is Map<String, dynamic>) {
            return CollectionReaderStyleCard.fromJson(entry);
          }
          if (entry is Map) {
            return CollectionReaderStyleCard.fromJson(
              entry.cast<String, dynamic>(),
            );
          }
          return null;
        })
        .whereType<CollectionReaderStyleCard>()
        .where((card) => card.id.isNotEmpty && card.name.isNotEmpty)
        .toList(growable: false);
  }
  return const <CollectionReaderStyleCard>[];
}

class CollectionReaderProgress {
  const CollectionReaderProgress({
    required this.collectionId,
    required this.readerMode,
    required this.pageAnimation,
    required this.currentMemoUid,
    required this.currentMemoIndex,
    required this.currentChapterPageIndex,
    required this.listScrollOffset,
    required this.currentMatchCharOffset,
    required this.updatedAt,
  });

  final String collectionId;
  final CollectionReaderMode readerMode;
  final CollectionReaderPageAnimation pageAnimation;
  final String? currentMemoUid;
  final int currentMemoIndex;
  final int currentChapterPageIndex;
  final double listScrollOffset;
  final int? currentMatchCharOffset;
  final DateTime updatedAt;

  Map<String, Object?> toRow() => <String, Object?>{
    'collection_id': collectionId.trim(),
    'reader_mode': readerMode.name,
    'page_animation': pageAnimation.name,
    'current_memo_uid': currentMemoUid?.trim(),
    'current_memo_index': currentMemoIndex,
    'current_chapter_page_index': currentChapterPageIndex,
    'list_scroll_offset': listScrollOffset,
    'current_match_char_offset': currentMatchCharOffset,
    'updated_time': updatedAt.toUtc().millisecondsSinceEpoch,
  };

  factory CollectionReaderProgress.fromRow(Map<String, dynamic> row) {
    return CollectionReaderProgress(
      collectionId: (row['collection_id'] as String? ?? '').trim(),
      readerMode: _readEnum(
        row['reader_mode'],
        CollectionReaderMode.values,
        CollectionReaderMode.vertical,
      ),
      pageAnimation: _readEnum(
        row['page_animation'],
        CollectionReaderPageAnimation.values,
        CollectionReaderPreferences.defaults.pageAnimation,
      ),
      currentMemoUid: (row['current_memo_uid'] as String?)?.trim(),
      currentMemoIndex: _readInt(row['current_memo_index']),
      currentChapterPageIndex: _readInt(row['current_chapter_page_index']),
      listScrollOffset: _readDouble(row['list_scroll_offset']),
      currentMatchCharOffset: _readNullableInt(
        row['current_match_char_offset'],
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        _readInt(row['updated_time']),
        isUtc: true,
      ).toLocal(),
    );
  }

  CollectionReaderProgress copyWith({
    String? collectionId,
    CollectionReaderMode? readerMode,
    CollectionReaderPageAnimation? pageAnimation,
    Object? currentMemoUid = _unset,
    int? currentMemoIndex,
    int? currentChapterPageIndex,
    double? listScrollOffset,
    Object? currentMatchCharOffset = _unset,
    DateTime? updatedAt,
  }) {
    return CollectionReaderProgress(
      collectionId: collectionId ?? this.collectionId,
      readerMode: readerMode ?? this.readerMode,
      pageAnimation: pageAnimation ?? this.pageAnimation,
      currentMemoUid: identical(currentMemoUid, _unset)
          ? this.currentMemoUid
          : currentMemoUid as String?,
      currentMemoIndex: currentMemoIndex ?? this.currentMemoIndex,
      currentChapterPageIndex:
          currentChapterPageIndex ?? this.currentChapterPageIndex,
      listScrollOffset: listScrollOffset ?? this.listScrollOffset,
      currentMatchCharOffset: identical(currentMatchCharOffset, _unset)
          ? this.currentMatchCharOffset
          : currentMatchCharOffset as int?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

T _readEnum<T>(Object? raw, List<T> values, T fallback) {
  final name = (raw as String? ?? '').trim();
  for (final value in values) {
    if (value is Enum && value.name == name) {
      return value;
    }
  }
  return fallback;
}

T? _readNullableEnum<T>(Object? raw, List<T> values) {
  final name = (raw as String? ?? '').trim();
  if (name.isEmpty) {
    return null;
  }
  for (final value in values) {
    if (value is Enum && value.name == name) {
      return value;
    }
  }
  return null;
}

R? _readNestedObject<R>(
  Object? raw,
  R Function(Map<String, dynamic> json) fromJson,
) {
  if (raw is Map<String, dynamic>) {
    return fromJson(raw);
  }
  if (raw is Map) {
    return fromJson(raw.cast<String, dynamic>());
  }
  return null;
}

Map<String, double> _edgeInsetsToJson(EdgeInsets value) => <String, double>{
  'left': value.left,
  'top': value.top,
  'right': value.right,
  'bottom': value.bottom,
};

EdgeInsets _readPagePadding(Object? raw) {
  return _readEdgeInsets(raw, CollectionReaderPreferences.defaults.pagePadding);
}

EdgeInsets _readEdgeInsets(Object? raw, EdgeInsets fallback) {
  if (raw is! Map) {
    return fallback;
  }
  final map = raw.cast<Object?, Object?>();
  return EdgeInsets.fromLTRB(
    _readDouble(map['left'], fallback.left),
    _readDouble(map['top'], fallback.top),
    _readDouble(map['right'], fallback.right),
    _readDouble(map['bottom'], fallback.bottom),
  );
}

String? _readTrimmedString(Object? raw) {
  final value = (raw as String?)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

bool _readBool(Object? raw, [bool fallback = false]) {
  if (raw is bool) return raw;
  if (raw is String) {
    switch (raw.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
    }
  }
  if (raw is num) return raw != 0;
  return fallback;
}

int _readInt(Object? raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

int? _readNullableInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

double _readDouble(Object? raw, [double fallback = 0]) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

Object? _colorToJson(Color? color) => color?.toARGB32();

Color? _readColor(Object? raw) {
  if (raw == null) return null;
  if (raw is Color) return raw;
  if (raw is int) return Color(raw);
  if (raw is num) return Color(raw.toInt());
  if (raw is String) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('#')) {
      final parsed = int.tryParse(value.substring(1), radix: 16);
      if (parsed == null) {
        return null;
      }
      if (value.length <= 7) {
        return Color(0xFF000000 | parsed);
      }
      return Color(parsed);
    }
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return Color(parsed);
    }
  }
  return null;
}

double _normalizeBrightness(double value) {
  return value.clamp(0.2, 1.0).toDouble();
}

double _normalizeTextScale(double value) {
  return value.clamp(0.8, 1.8).toDouble();
}

double _normalizeLineSpacing(double value) {
  return value.clamp(1.15, 2.4).toDouble();
}

double _normalizeLetterSpacing(double value) {
  return value.clamp(-0.05, 0.25).toDouble();
}

double _normalizeParagraphSpacing(double value) {
  return value.clamp(0, 32).toDouble();
}

int _normalizeParagraphIndentChars(int value) {
  return value.clamp(0, 6);
}

double _normalizeTitleScale(double value) {
  return value.clamp(0.8, 1.6).toDouble();
}

double _normalizeSpacing(double value) {
  return value.clamp(0, 48).toDouble();
}

double _normalizeBackgroundAlpha(double value) {
  return value.clamp(0.2, 1.0).toDouble();
}

int _normalizePageTouchSlop(int value) {
  return value.clamp(0, 9999);
}

int _normalizeAutoPageSeconds(int value) {
  return value.clamp(1, 60);
}
