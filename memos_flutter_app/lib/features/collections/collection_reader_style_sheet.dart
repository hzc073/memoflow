import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/system_fonts.dart';
import '../../data/models/collection_reader.dart';
import '../../i18n/strings.g.dart';
import '../../state/system/system_fonts_provider.dart';
import 'collection_reader_panel.dart';

class CollectionReaderStyleSheet extends ConsumerStatefulWidget {
  const CollectionReaderStyleSheet({
    super.key,
    required this.preferences,
    required this.onThemePresetChanged,
    required this.onBackgroundConfigChanged,
    required this.onBrightnessModeChanged,
    required this.onBrightnessChanged,
    required this.onPageAnimationChanged,
    required this.onTextScaleChanged,
    required this.onLineSpacingChanged,
    required this.onFontFamilyChanged,
    required this.onFontWeightModeChanged,
    required this.onLetterSpacingChanged,
    required this.onParagraphSpacingChanged,
    required this.onParagraphIndentCharsChanged,
    required this.onSavedStyleCardsChanged,
    required this.onOpenTipSettings,
    required this.onOpenPaddingSettings,
  });

  final CollectionReaderPreferences preferences;
  final ValueChanged<CollectionReaderThemePreset> onThemePresetChanged;
  final ValueChanged<CollectionReaderBackgroundConfig>
  onBackgroundConfigChanged;
  final ValueChanged<CollectionReaderBrightnessMode> onBrightnessModeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<CollectionReaderPageAnimation> onPageAnimationChanged;
  final ValueChanged<double> onTextScaleChanged;
  final ValueChanged<double> onLineSpacingChanged;
  final void Function({String? family, String? filePath}) onFontFamilyChanged;
  final ValueChanged<CollectionReaderFontWeightMode> onFontWeightModeChanged;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<double> onParagraphSpacingChanged;
  final ValueChanged<int> onParagraphIndentCharsChanged;
  final ValueChanged<List<CollectionReaderStyleCard>> onSavedStyleCardsChanged;
  final VoidCallback onOpenTipSettings;
  final VoidCallback onOpenPaddingSettings;

  @override
  ConsumerState<CollectionReaderStyleSheet> createState() =>
      _CollectionReaderStyleSheetState();
}

class _CollectionReaderStyleSheetState
    extends ConsumerState<CollectionReaderStyleSheet> {
  late CollectionReaderThemePreset _themePreset;
  late CollectionReaderBrightnessMode _brightnessMode;
  late double _brightness;
  late double _textScale;
  late double _lineSpacing;
  late double _letterSpacing;
  late double _paragraphSpacing;
  late int _paragraphIndentChars;
  late CollectionReaderFontWeightMode _fontWeightMode;
  late CollectionReaderPageAnimation _pageAnimation;
  late CollectionReaderBackgroundConfig _backgroundConfig;
  late String? _selectedFontFamily;
  late List<CollectionReaderStyleCard> _savedStyleCards;

  @override
  void initState() {
    super.initState();
    final preferences = widget.preferences;
    _themePreset = preferences.themePreset;
    _brightnessMode = preferences.brightnessMode;
    _brightness = preferences.brightness;
    _textScale = preferences.textScale;
    _lineSpacing = preferences.lineSpacing;
    _letterSpacing = preferences.letterSpacing;
    _paragraphSpacing = preferences.paragraphSpacing;
    _paragraphIndentChars = preferences.paragraphIndentChars;
    _fontWeightMode = preferences.fontWeightMode;
    _pageAnimation = preferences.pageAnimation;
    _backgroundConfig = preferences.backgroundConfig;
    _selectedFontFamily = preferences.readerFontFamily;
    _savedStyleCards = List<CollectionReaderStyleCard>.from(
      preferences.savedStyleCards,
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerStrings = context.t.strings.collections.reader;
    final fontsAsync = ref.watch(systemFontsProvider);
    return SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        shrinkWrap: true,
        children: [
          const _SheetHandle(),
          _SectionTitle(readerStrings.styleTitle),
          const SizedBox(height: 12),
          _buildStyleCardsSection(context),
          const SizedBox(height: 16),
          CollectionReaderSectionTitle(readerStrings.backgroundStyle),
          CollectionReaderPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CollectionReaderHorizontalScroller(
                  child: SegmentedButton<CollectionReaderBackgroundType>(
                    segments: [
                      ButtonSegment(
                        value: CollectionReaderBackgroundType.preset,
                        label: Text(readerStrings.backgroundTypePreset),
                      ),
                      ButtonSegment(
                        value: CollectionReaderBackgroundType.solidColor,
                        label: Text(readerStrings.backgroundTypeSolid),
                      ),
                      ButtonSegment(
                        value: CollectionReaderBackgroundType.imageFile,
                        label: Text(readerStrings.backgroundTypeImage),
                      ),
                    ],
                    selected: <CollectionReaderBackgroundType>{
                      _backgroundConfig.type,
                    },
                    onSelectionChanged: (selection) {
                      final type = selection.first;
                      setState(() {
                        _backgroundConfig = switch (type) {
                          CollectionReaderBackgroundType.preset =>
                            _backgroundConfig.copyWith(
                              type: type,
                              preset: _backgroundConfig.preset ?? _themePreset,
                            ),
                          CollectionReaderBackgroundType.solidColor =>
                            _backgroundConfig.copyWith(
                              type: type,
                              solidColor:
                                  _backgroundConfig.solidColor ??
                                  const Color(0xFFF6F0E4),
                            ),
                          CollectionReaderBackgroundType.imageFile =>
                            _backgroundConfig.copyWith(type: type),
                          CollectionReaderBackgroundType.imageAsset =>
                            _backgroundConfig.copyWith(type: type),
                        };
                      });
                      _emitBackgroundConfig();
                    },
                  ),
                ),
                const SizedBox(height: 10),
                if (_backgroundConfig.type ==
                    CollectionReaderBackgroundType.preset)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CollectionReaderThemePreset.values
                        .map((preset) {
                          return ChoiceChip(
                            label: Text(_themeLabel(context, preset)),
                            selected:
                                (_backgroundConfig.preset ?? _themePreset) ==
                                preset,
                            onSelected: (_) {
                              setState(() {
                                _themePreset = preset;
                                _backgroundConfig = _backgroundConfig.copyWith(
                                  type: CollectionReaderBackgroundType.preset,
                                  preset: preset,
                                );
                              });
                              widget.onThemePresetChanged(preset);
                              _emitBackgroundConfig();
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                if (_backgroundConfig.type ==
                    CollectionReaderBackgroundType.solidColor)
                  _buildSolidColorSection(context),
                if (_backgroundConfig.type ==
                    CollectionReaderBackgroundType.imageFile)
                  _buildImageFileSection(context),
                const SizedBox(height: 10),
                _LabeledSlider(
                  label: readerStrings.backgroundAlpha,
                  value: _backgroundConfig.alpha,
                  valueText: '${(_backgroundConfig.alpha * 100).round()}%',
                  min: 0.2,
                  max: 1,
                  onChanged: (value) {
                    setState(() {
                      _backgroundConfig = _backgroundConfig.copyWith(
                        alpha: value,
                      );
                    });
                    _emitBackgroundConfig();
                  },
                ),
                const SizedBox(height: 8),
                CollectionReaderHorizontalScroller(
                  child: SegmentedButton<CollectionReaderPageAnimation>(
                    segments: CollectionReaderPageAnimation.values
                        .map(
                          (value) => ButtonSegment(
                            value: value,
                            label: Text(_animationLabel(context, value)),
                          ),
                        )
                        .toList(growable: false),
                    selected: <CollectionReaderPageAnimation>{_pageAnimation},
                    onSelectionChanged: (selection) {
                      final value = selection.first;
                      setState(() => _pageAnimation = value);
                      widget.onPageAnimationChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildFontSection(context, fontsAsync),
          CollectionReaderSectionTitle(readerStrings.typography),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                _LabeledSlider(
                  label: readerStrings.textScale,
                  value: _textScale,
                  valueText: _textScale.toStringAsFixed(2),
                  min: 0.8,
                  max: 1.8,
                  onChanged: (value) {
                    setState(() => _textScale = value);
                    widget.onTextScaleChanged(value);
                  },
                ),
                _LabeledSlider(
                  label: readerStrings.lineSpacing,
                  value: _lineSpacing,
                  valueText: _lineSpacing.toStringAsFixed(2),
                  min: 1.15,
                  max: 2.4,
                  onChanged: (value) {
                    setState(() => _lineSpacing = value);
                    widget.onLineSpacingChanged(value);
                  },
                ),
                _LabeledSlider(
                  label: readerStrings.letterSpacing,
                  value: _letterSpacing,
                  valueText: _letterSpacing.toStringAsFixed(2),
                  min: -0.05,
                  max: 0.25,
                  onChanged: (value) {
                    setState(() => _letterSpacing = value);
                    widget.onLetterSpacingChanged(value);
                  },
                ),
                _LabeledSlider(
                  label: readerStrings.paragraphSpacing,
                  value: _paragraphSpacing,
                  valueText: _paragraphSpacing.toStringAsFixed(0),
                  min: 0,
                  max: 32,
                  onChanged: (value) {
                    setState(() => _paragraphSpacing = value);
                    widget.onParagraphSpacingChanged(value);
                  },
                ),
                _LabeledSlider(
                  label: readerStrings.firstLineIndent,
                  value: _paragraphIndentChars.toDouble(),
                  valueText: '$_paragraphIndentChars',
                  min: 0,
                  max: 6,
                  divisions: 6,
                  onChanged: (value) {
                    final next = value.round();
                    setState(() => _paragraphIndentChars = next);
                    widget.onParagraphIndentCharsChanged(next);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CollectionReaderSectionTitle(readerStrings.paddingSettingsTitle),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readerStrings.paddingSettingsTitle),
                  subtitle: Text(readerStrings.paddingSettingsSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onOpenPaddingSettings,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readerStrings.tipSettingsTitle),
                  subtitle: Text(readerStrings.tipSettingsSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onOpenTipSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CollectionReaderSectionTitle(readerStrings.brightness),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                CollectionReaderHorizontalScroller(
                  child: SegmentedButton<CollectionReaderBrightnessMode>(
                    segments: [
                      ButtonSegment(
                        value: CollectionReaderBrightnessMode.system,
                        label: Text(readerStrings.brightnessSystem),
                      ),
                      ButtonSegment(
                        value: CollectionReaderBrightnessMode.manual,
                        label: Text(readerStrings.brightnessManual),
                      ),
                    ],
                    selected: <CollectionReaderBrightnessMode>{_brightnessMode},
                    onSelectionChanged: (selection) {
                      final value = selection.first;
                      setState(() => _brightnessMode = value);
                      widget.onBrightnessModeChanged(value);
                    },
                  ),
                ),
                _LabeledSlider(
                  label: readerStrings.readerBrightness,
                  value: _brightness,
                  valueText: '${(_brightness * 100).round()}%',
                  min: 0.2,
                  max: 1,
                  onChanged: (value) {
                    setState(() => _brightness = value);
                    widget.onBrightnessChanged(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleCardsSection(BuildContext context) {
    final readerStrings = context.t.strings.collections.reader;
    final builtInCards = CollectionReaderThemePreset.values
        .map(
          (preset) => _StyleCardData(
            id: 'builtin:${preset.name}',
            name: _themeLabel(context, preset),
            themePreset: preset,
            backgroundConfig: CollectionReaderBackgroundConfig.defaults
                .copyWith(
                  type: CollectionReaderBackgroundType.preset,
                  preset: preset,
                  alpha: 1,
                ),
            builtIn: true,
          ),
        )
        .toList(growable: false);
    final customCards = _savedStyleCards
        .map(
          (card) => _StyleCardData(
            id: card.id,
            name: card.name,
            themePreset: card.themePreset,
            backgroundConfig: card.backgroundConfig,
          ),
        )
        .toList(growable: false);
    final selectedCustomCard = _resolveCurrentCustomCard();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          readerStrings.styleCardsTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _createStyleCard(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(readerStrings.styleCardNew),
            ),
            TextButton.icon(
              onPressed: selectedCustomCard == null
                  ? null
                  : () => _editStyleCard(context, selectedCustomCard),
              icon: const Icon(Icons.edit_rounded),
              label: Text(readerStrings.styleCardEditCurrent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 124,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final card in [...builtInCards, ...customCards])
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _StyleCardTile(
                    card: card,
                    selected: _matchesStyleCard(card),
                    preview: _resolveCardPreview(card),
                    onTap: () => _applyStyleCard(card),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  _StyleCardData? _resolveCurrentCustomCard() {
    for (final card in _savedStyleCards) {
      final candidate = _StyleCardData(
        id: card.id,
        name: card.name,
        themePreset: card.themePreset,
        backgroundConfig: card.backgroundConfig,
      );
      if (_matchesStyleCard(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  bool _matchesStyleCard(_StyleCardData card) {
    return card.themePreset == _themePreset &&
        _backgroundConfigsEqual(card.backgroundConfig, _backgroundConfig);
  }

  _StyleCardPreview _resolveCardPreview(_StyleCardData card) {
    final fallback = _presetPreviewPalette(card.themePreset);
    final backgroundConfig = card.backgroundConfig;
    return switch (backgroundConfig.type) {
      CollectionReaderBackgroundType.preset => _presetPreviewPalette(
        backgroundConfig.preset ?? card.themePreset,
      ),
      CollectionReaderBackgroundType.solidColor => _StyleCardPreview(
        background: (backgroundConfig.solidColor ?? const Color(0xFFF6F0E4))
            .withValues(alpha: backgroundConfig.alpha),
        foreground: fallback.foreground,
        accent: fallback.accent,
      ),
      CollectionReaderBackgroundType.imageFile ||
      CollectionReaderBackgroundType.imageAsset => _StyleCardPreview(
        background: fallback.background.withValues(
          alpha: backgroundConfig.alpha,
        ),
        foreground: fallback.foreground,
        accent: fallback.accent,
        imageLike: true,
      ),
    };
  }

  Future<void> _createStyleCard(BuildContext context) async {
    final name = await _showStyleCardEditor(
      context,
      initialValue: '',
      title: context.t.strings.collections.reader.styleCardCreateTitle,
      confirmLabel: context.t.strings.collections.reader.styleCardSave,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final trimmedName = name.trim();
    final id =
        'style-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final nextCard = CollectionReaderStyleCard(
      id: id,
      name: trimmedName,
      themePreset: _themePreset,
      backgroundConfig: _backgroundConfig,
    );
    setState(() {
      _savedStyleCards = [..._savedStyleCards, nextCard];
    });
    widget.onSavedStyleCardsChanged(_savedStyleCards);
  }

  Future<void> _editStyleCard(
    BuildContext context,
    _StyleCardData currentCard,
  ) async {
    final result = await _showStyleCardEditor(
      context,
      initialValue: currentCard.name,
      title: context.t.strings.collections.reader.styleCardEditTitle,
      confirmLabel: context.t.strings.collections.reader.styleCardSave,
      allowDelete: true,
    );
    if (result == null) {
      return;
    }
    if (result == _styleCardDeleteSentinel) {
      setState(() {
        _savedStyleCards = _savedStyleCards
            .where((card) => card.id != currentCard.id)
            .toList(growable: false);
      });
      widget.onSavedStyleCardsChanged(_savedStyleCards);
      return;
    }
    final trimmedName = result.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    setState(() {
      _savedStyleCards = _savedStyleCards
          .map(
            (card) => card.id == currentCard.id
                ? card.copyWith(
                    name: trimmedName,
                    themePreset: _themePreset,
                    backgroundConfig: _backgroundConfig,
                  )
                : card,
          )
          .toList(growable: false);
    });
    widget.onSavedStyleCardsChanged(_savedStyleCards);
  }

  Future<String?> _showStyleCardEditor(
    BuildContext context, {
    required String initialValue,
    required String title,
    required String confirmLabel,
    bool allowDelete = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText:
                  context.t.strings.collections.reader.styleCardNameLabel,
            ),
          ),
          actions: [
            if (allowDelete)
              TextButton(
                onPressed: () {
                  result = _styleCardDeleteSentinel;
                  Navigator.of(context).pop();
                },
                child: Text(
                  context.t.strings.collections.reader.styleCardDelete,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.strings.collections.reader.cancel),
            ),
            FilledButton(
              onPressed: () {
                result = controller.text;
                Navigator.of(context).pop();
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _applyStyleCard(_StyleCardData card) {
    setState(() {
      _themePreset = card.themePreset;
      _backgroundConfig = card.backgroundConfig;
    });
    widget.onThemePresetChanged(card.themePreset);
    _emitBackgroundConfig();
  }

  bool _backgroundConfigsEqual(
    CollectionReaderBackgroundConfig left,
    CollectionReaderBackgroundConfig right,
  ) {
    return left.type == right.type &&
        left.preset == right.preset &&
        left.solidColor?.toARGB32() == right.solidColor?.toARGB32() &&
        left.imagePath == right.imagePath &&
        (left.alpha - right.alpha).abs() < 0.0001;
  }

  _StyleCardPreview _presetPreviewPalette(CollectionReaderThemePreset preset) {
    return switch (preset) {
      CollectionReaderThemePreset.paper => const _StyleCardPreview(
        background: Color(0xFFF6F0E4),
        foreground: Color(0xFF3A2F24),
        accent: Color(0xFFD8CDBB),
      ),
      CollectionReaderThemePreset.eyeCare => const _StyleCardPreview(
        background: Color(0xFFE7F1DF),
        foreground: Color(0xFF30442F),
        accent: Color(0xFFC5D7BF),
      ),
      CollectionReaderThemePreset.dark => const _StyleCardPreview(
        background: Color(0xFF121417),
        foreground: Color(0xFFECE7DB),
        accent: Color(0xFF2D3138),
      ),
      CollectionReaderThemePreset.gray => const _StyleCardPreview(
        background: Color(0xFFF0F1F3),
        foreground: Color(0xFF30343A),
        accent: Color(0xFFD4D7DD),
      ),
    };
  }

  Widget _buildFontSection(
    BuildContext context,
    AsyncValue<List<SystemFontInfo>> fontsAsync,
  ) {
    final readerStrings = context.t.strings.collections.reader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollectionReaderSectionTitle(readerStrings.readerFont),
        CollectionReaderPanelCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(readerStrings.readerFont),
                subtitle: Text(
                  _selectedFontLabel(
                    context,
                    fontsAsync.valueOrNull ?? const [],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: fontsAsync.maybeWhen(
                  data: (fonts) =>
                      () => _showFontPicker(context, fonts),
                  orElse: () => null,
                ),
              ),
              CollectionReaderHorizontalScroller(
                child: SegmentedButton<CollectionReaderFontWeightMode>(
                  segments: [
                    ButtonSegment(
                      value: CollectionReaderFontWeightMode.normal,
                      label: Text(readerStrings.fontWeightNormal),
                    ),
                    ButtonSegment(
                      value: CollectionReaderFontWeightMode.medium,
                      label: Text(readerStrings.fontWeightMedium),
                    ),
                    ButtonSegment(
                      value: CollectionReaderFontWeightMode.bold,
                      label: Text(readerStrings.fontWeightBold),
                    ),
                  ],
                  selected: <CollectionReaderFontWeightMode>{_fontWeightMode},
                  onSelectionChanged: (selection) {
                    final value = selection.first;
                    setState(() => _fontWeightMode = value);
                    widget.onFontWeightModeChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showFontPicker(
    BuildContext context,
    List<SystemFontInfo> fonts,
  ) async {
    final systemDefault = SystemFontInfo(
      family: '',
      displayName: context.t.strings.collections.reader.fontSystemDefault,
    );
    final selectedFamily = _selectedFontFamily?.trim() ?? '';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              for (final font in [systemDefault, ...fonts])
                ListTile(
                  leading: Icon(
                    font.family == selectedFamily
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(font.displayName),
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (font.isSystemDefault) {
                      setState(() {
                        _selectedFontFamily = null;
                      });
                      widget.onFontFamilyChanged(family: null, filePath: null);
                      return;
                    }
                    await SystemFonts.ensureLoaded(font);
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _selectedFontFamily = font.family;
                    });
                    widget.onFontFamilyChanged(
                      family: font.family,
                      filePath: font.filePath,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _selectedFontLabel(BuildContext context, List<SystemFontInfo> fonts) {
    final family = _selectedFontFamily?.trim() ?? '';
    if (family.isEmpty) {
      return context.t.strings.collections.reader.fontSystemDefault;
    }
    for (final font in fonts) {
      if (font.family == family) {
        return font.displayName;
      }
    }
    return family;
  }

  String _themeLabel(BuildContext context, CollectionReaderThemePreset preset) {
    final readerStrings = context.t.strings.collections.reader;
    return switch (preset) {
      CollectionReaderThemePreset.paper => readerStrings.themePaper,
      CollectionReaderThemePreset.eyeCare => readerStrings.themeEyeCare,
      CollectionReaderThemePreset.dark => readerStrings.themeDark,
      CollectionReaderThemePreset.gray => readerStrings.themeGray,
    };
  }

  String _animationLabel(
    BuildContext context,
    CollectionReaderPageAnimation value,
  ) {
    final readerStrings = context.t.strings.collections.reader;
    return switch (value) {
      CollectionReaderPageAnimation.none => readerStrings.pageAnimationNone,
      CollectionReaderPageAnimation.slide => readerStrings.pageAnimationSlide,
      CollectionReaderPageAnimation.simulation =>
        readerStrings.pageAnimationSimulation,
    };
  }

  Widget _buildSolidColorSection(BuildContext context) {
    final colors = <Color>[
      const Color(0xFFF6F0E4),
      const Color(0xFFE7F1DF),
      const Color(0xFFF0F1F3),
      const Color(0xFF111318),
      const Color(0xFFF9E7D6),
      const Color(0xFFDDE8F6),
    ];
    final selected = _backgroundConfig.solidColor ?? const Color(0xFFF6F0E4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in colors)
              InkWell(
                onTap: () {
                  setState(() {
                    _backgroundConfig = _backgroundConfig.copyWith(
                      type: CollectionReaderBackgroundType.solidColor,
                      solidColor: color,
                    );
                  });
                  _emitBackgroundConfig();
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == color
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: selected == color ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t.strings.collections.reader.customSolidColor),
          subtitle: Text(
            '#${selected.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _showColorPicker(
            context,
            title: context.t.strings.collections.reader.backgroundColor,
            currentColor: selected,
            onSelected: (color) {
              setState(() {
                _backgroundConfig = _backgroundConfig.copyWith(
                  type: CollectionReaderBackgroundType.solidColor,
                  solidColor: color,
                );
              });
              _emitBackgroundConfig();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageFileSection(BuildContext context) {
    final imagePath = _backgroundConfig.imagePath?.trim() ?? '';
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t.strings.collections.reader.backgroundImage),
          subtitle: Text(
            imagePath.isEmpty
                ? (kIsWeb
                      ? context
                            .t
                            .strings
                            .collections
                            .reader
                            .backgroundImageUnavailableWeb
                      : context
                            .t
                            .strings
                            .collections
                            .reader
                            .backgroundImagePickHint)
                : imagePath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.image_outlined),
          onTap: kIsWeb ? null : _pickBackgroundImageFile,
        ),
        if (imagePath.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _backgroundConfig = _backgroundConfig.copyWith(
                    type: CollectionReaderBackgroundType.preset,
                    imagePath: null,
                    preset: _backgroundConfig.preset ?? _themePreset,
                  );
                });
                _emitBackgroundConfig();
              },
              icon: const Icon(Icons.clear_rounded),
              label: Text(
                context.t.strings.collections.reader.clearImageBackground,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickBackgroundImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.singleOrNull?.path;
    if (path == null || path.trim().isEmpty || !mounted) {
      return;
    }
    setState(() {
      _backgroundConfig = _backgroundConfig.copyWith(
        type: CollectionReaderBackgroundType.imageFile,
        imagePath: path,
      );
    });
    _emitBackgroundConfig();
  }

  Future<void> _showColorPicker(
    BuildContext context, {
    required String title,
    required Color currentColor,
    required ValueChanged<Color> onSelected,
  }) async {
    var tempColor = currentColor;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: tempColor,
              onColorChanged: (color) => tempColor = color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.strings.collections.reader.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSelected(tempColor);
              },
              child: Text(context.t.strings.collections.reader.apply),
            ),
          ],
        );
      },
    );
  }

  void _emitBackgroundConfig() {
    widget.onBackgroundConfigChanged(_backgroundConfig);
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return const CollectionReaderSheetHandle();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return CollectionReaderSectionTitle(title);
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return CollectionReaderLabeledSlider(
      label: label,
      valueText: valueText,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
    );
  }
}

const String _styleCardDeleteSentinel = '__delete__';

class _StyleCardData {
  const _StyleCardData({
    required this.id,
    required this.name,
    required this.themePreset,
    required this.backgroundConfig,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final CollectionReaderThemePreset themePreset;
  final CollectionReaderBackgroundConfig backgroundConfig;
  final bool builtIn;
}

class _StyleCardPreview {
  const _StyleCardPreview({
    required this.background,
    required this.foreground,
    required this.accent,
    this.imageLike = false,
  });

  final Color background;
  final Color foreground;
  final Color accent;
  final bool imageLike;
}

class _StyleCardTile extends StatelessWidget {
  const _StyleCardTile({
    required this.card,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final _StyleCardData card;
  final bool selected;
  final _StyleCardPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: preview.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    if (preview.imageLike)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                preview.accent.withValues(alpha: 0.18),
                                preview.background,
                                preview.foreground.withValues(alpha: 0.12),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 10,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: preview.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: preview.foreground.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 4,
                            width: 42,
                            decoration: BoxDecoration(
                              color: preview.foreground.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              card.builtIn
                  ? context.t.strings.collections.reader.styleCardBuiltIn
                  : context.t.strings.collections.reader.styleCardCustom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
