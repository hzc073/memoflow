import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/collection_reader.dart';
import '../../i18n/strings.g.dart';
import 'collection_reader_tokens.dart';

class CollectionReaderHeaderData {
  const CollectionReaderHeaderData({
    required this.collectionTitle,
    required this.currentItemTitle,
    required this.currentItemMeta,
    required this.positionLabel,
    required this.showTitleAddition,
  });

  final String collectionTitle;
  final String currentItemTitle;
  final String currentItemMeta;
  final String positionLabel;
  final bool showTitleAddition;
}

enum CollectionReaderMoreAction {
  editCollection,
  manageCollectionItems,
  currentMemoActions,
}

class CollectionReaderOverlay extends StatelessWidget {
  const CollectionReaderOverlay({
    super.key,
    required this.visible,
    required this.headerData,
    required this.readerMode,
    required this.pageAnimation,
    required this.themePreset,
    required this.currentProgressText,
    required this.sliderValue,
    required this.sliderMax,
    required this.autoPaging,
    required this.canPrevChapter,
    required this.canNextChapter,
    required this.showBrightnessControl,
    required this.brightnessMode,
    required this.brightness,
    required this.followPageStyle,
    required this.pageBackgroundColor,
    required this.pageForegroundColor,
    required this.accentColor,
    required this.hostBrightness,
    required this.onBack,
    required this.onSearch,
    required this.onMoreSelected,
    required this.onProgressTap,
    required this.onToggleThemePreset,
    required this.onModeChanged,
    required this.onAnimationChanged,
    required this.onShowToc,
    required this.onShowAutoPage,
    required this.onShowStyle,
    required this.onShowMoreSettings,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onBrightnessModeChanged,
    required this.onBrightnessChanged,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.onOverlayInteraction,
  });

  final bool visible;
  final CollectionReaderHeaderData headerData;
  final CollectionReaderMode readerMode;
  final CollectionReaderPageAnimation pageAnimation;
  final CollectionReaderThemePreset themePreset;
  final String currentProgressText;
  final double sliderValue;
  final double sliderMax;
  final bool autoPaging;
  final bool canPrevChapter;
  final bool canNextChapter;
  final bool showBrightnessControl;
  final CollectionReaderBrightnessMode brightnessMode;
  final double brightness;
  final bool followPageStyle;
  final Color pageBackgroundColor;
  final Color pageForegroundColor;
  final Color accentColor;
  final Brightness hostBrightness;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final ValueChanged<CollectionReaderMoreAction> onMoreSelected;
  final VoidCallback onProgressTap;
  final VoidCallback onToggleThemePreset;
  final ValueChanged<CollectionReaderMode> onModeChanged;
  final ValueChanged<CollectionReaderPageAnimation> onAnimationChanged;
  final VoidCallback onShowToc;
  final VoidCallback onShowAutoPage;
  final VoidCallback onShowStyle;
  final VoidCallback onShowMoreSettings;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<CollectionReaderBrightnessMode> onBrightnessModeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderChangeEnd;
  final VoidCallback onOverlayInteraction;

  @override
  Widget build(BuildContext context) {
    final readerStrings = context.t.strings.collections.reader;
    final pageBrightness = ThemeData.estimateBrightnessForColor(
      pageBackgroundColor,
    );
    final menuBackground = CollectionReaderTokens.resolveOverlayPanelColor(
      pageBackgroundColor,
      pageBrightness: pageBrightness,
      followPageStyle: followPageStyle,
      hostBrightness: hostBrightness,
    );
    final topBackground = menuBackground.withValues(alpha: 0.98);
    final bottomBackground = menuBackground.withValues(alpha: 0.985);
    final fabBackground = CollectionReaderTokens.resolveFloatingButtonColor(
      menuBackground,
      pageForegroundColor,
      brightness: followPageStyle ? pageBrightness : hostBrightness,
    );
    final mutedForeground = pageForegroundColor.withValues(alpha: 0.74);
    final topOffset = visible ? 0.0 : -140.0;
    final floatingOffset = visible ? 124.0 : -104.0;
    final bottomOffset = visible ? 0.0 : -220.0;

    return IgnorePointer(
      ignoring: !visible,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            top: topOffset,
            child: SafeArea(
              bottom: false,
              child: _OverlayTopBar(
                backgroundColor: topBackground,
                foregroundColor: pageForegroundColor,
                mutedForegroundColor: mutedForeground,
                accentColor: accentColor,
                headerData: headerData,
                onBack: () {
                  onOverlayInteraction();
                  onBack();
                },
                onProgressTap: () {
                  onOverlayInteraction();
                  onProgressTap();
                },
                onMoreSelected: (value) {
                  onOverlayInteraction();
                  onMoreSelected(value);
                },
              ),
            ),
          ),
          if (showBrightnessControl)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: 132,
              bottom: 196,
              right: visible ? 12 : -80,
              child: SafeArea(
                child: _OverlayBrightnessStrip(
                  backgroundColor: bottomBackground.withValues(alpha: 0.9),
                  foregroundColor: pageForegroundColor,
                  accentColor: accentColor,
                  brightnessMode: brightnessMode,
                  brightness: brightness,
                  onBrightnessModeChanged: (value) {
                    onOverlayInteraction();
                    onBrightnessModeChanged(value);
                  },
                  onBrightnessChanged: (value) {
                    onOverlayInteraction();
                    if (brightnessMode !=
                        CollectionReaderBrightnessMode.manual) {
                      onBrightnessModeChanged(
                        CollectionReaderBrightnessMode.manual,
                      );
                    }
                    onBrightnessChanged(value);
                  },
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: floatingOffset,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OverlayFloatingButton(
                          icon: Icons.search_rounded,
                          tooltip: readerStrings.tapActionSearch,
                          backgroundColor: fabBackground,
                          foregroundColor: pageForegroundColor,
                          onTap: () {
                            onOverlayInteraction();
                            onSearch();
                          },
                        ),
                        _OverlayFloatingButton(
                          icon: autoPaging
                              ? Icons.pause_circle_filled_rounded
                              : Icons.auto_awesome_rounded,
                          tooltip: readerStrings.autoPageTitle,
                          backgroundColor: fabBackground,
                          foregroundColor: pageForegroundColor,
                          accentColor: accentColor,
                          selected: autoPaging,
                          onTap: () {
                            onOverlayInteraction();
                            onShowAutoPage();
                          },
                        ),
                        PopupMenuButton<CollectionReaderPageAnimation>(
                          tooltip: readerStrings.pageAnimationTooltip,
                          onSelected: (value) {
                            onOverlayInteraction();
                            onAnimationChanged(value);
                          },
                          itemBuilder: (context) =>
                              CollectionReaderPageAnimation.values
                                  .map(
                                    (value) => PopupMenuItem(
                                      value: value,
                                      child: Text(
                                        _pageAnimationLabel(context, value),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                          child: IgnorePointer(
                            child: _OverlayFloatingButton(
                              icon: switch (pageAnimation) {
                                CollectionReaderPageAnimation.none =>
                                  Icons.flash_off_rounded,
                                CollectionReaderPageAnimation.slide =>
                                  Icons.swap_horiz_rounded,
                                CollectionReaderPageAnimation.simulation =>
                                  Icons.auto_awesome_motion_rounded,
                              },
                              tooltip: readerStrings.pageAnimationTooltip,
                              backgroundColor: fabBackground,
                              foregroundColor: pageForegroundColor,
                              onTap: () {},
                            ),
                          ),
                        ),
                        _OverlayFloatingButton(
                          icon: themePreset == CollectionReaderThemePreset.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          tooltip: readerStrings.backgroundStyle,
                          backgroundColor: fabBackground,
                          foregroundColor: pageForegroundColor,
                          accentColor: accentColor,
                          selected:
                              themePreset == CollectionReaderThemePreset.dark,
                          onTap: () {
                            onOverlayInteraction();
                            onToggleThemePreset();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: bottomOffset,
            child: SafeArea(
              top: false,
              child: _OverlayBottomPanel(
                backgroundColor: bottomBackground,
                foregroundColor: pageForegroundColor,
                mutedForegroundColor: mutedForeground,
                accentColor: accentColor,
                currentProgressText: currentProgressText,
                sliderValue: sliderValue,
                sliderMax: sliderMax,
                canPrevChapter: canPrevChapter,
                canNextChapter: canNextChapter,
                onPrevChapter: () {
                  onOverlayInteraction();
                  onPrevChapter();
                },
                onNextChapter: () {
                  onOverlayInteraction();
                  onNextChapter();
                },
                onSliderChanged: (value) {
                  onOverlayInteraction();
                  onSliderChanged(value);
                },
                onSliderChangeEnd: (value) {
                  onOverlayInteraction();
                  onSliderChangeEnd(value);
                },
                bottomActions: [
                  _OverlayBottomActionData(
                    icon: Icons.format_list_bulleted_rounded,
                    label: readerStrings.tapActionToc,
                    onTap: () {
                      onOverlayInteraction();
                      onShowToc();
                    },
                  ),
                  _OverlayBottomActionData(
                    icon: readerMode == CollectionReaderMode.paged
                        ? Icons.chrome_reader_mode_rounded
                        : Icons.view_agenda_rounded,
                    label: context.t.strings.legacy.msg_mode,
                    selected: readerMode == CollectionReaderMode.paged,
                    onTap: () {
                      onOverlayInteraction();
                      onModeChanged(
                        readerMode == CollectionReaderMode.paged
                            ? CollectionReaderMode.vertical
                            : CollectionReaderMode.paged,
                      );
                    },
                  ),
                  _OverlayBottomActionData(
                    icon: Icons.text_fields_rounded,
                    label: readerStrings.styleTitle,
                    onTap: () {
                      onOverlayInteraction();
                      onShowStyle();
                    },
                  ),
                  _OverlayBottomActionData(
                    icon: Icons.settings_outlined,
                    label: context.t.strings.legacy.msg_settings,
                    onTap: () {
                      onOverlayInteraction();
                      onShowMoreSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayTopBar extends StatelessWidget {
  const _OverlayTopBar({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.mutedForegroundColor,
    required this.accentColor,
    required this.headerData,
    required this.onBack,
    required this.onProgressTap,
    required this.onMoreSelected,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color mutedForegroundColor;
  final Color accentColor;
  final CollectionReaderHeaderData headerData;
  final VoidCallback onBack;
  final VoidCallback onProgressTap;
  final ValueChanged<CollectionReaderMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    final collectionsStrings = context.t.strings.collections;
    final showAddition = headerData.showTitleAddition;
    final collectionLabel = headerData.collectionTitle.trim();
    final itemTitle = headerData.currentItemTitle.trim();
    final primaryTitle = showAddition ? itemTitle : collectionLabel;
    final resolvedPrimaryTitle = primaryTitle.isEmpty
        ? collectionLabel
        : primaryTitle;
    final itemMeta = headerData.currentItemMeta.trim();
    return Material(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: onBack,
              iconSize: CollectionReaderTokens.topBarIconSize,
              constraints: const BoxConstraints.tightFor(
                width: CollectionReaderTokens.topBarActionSize,
                height: CollectionReaderTokens.topBarActionSize,
              ),
              padding: EdgeInsets.zero,
              color: foregroundColor,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6, right: 10, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showAddition && collectionLabel.isNotEmpty)
                      Text(
                        collectionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: mutedForegroundColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                      ),
                    Text(
                      resolvedPrimaryTitle,
                      maxLines: showAddition ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                      ),
                    ),
                    if (showAddition && itemMeta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          itemMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: mutedForegroundColor,
                                fontSize: 12.5,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (headerData.positionLabel.trim().isNotEmpty)
              _OverlayProgressChip(
                label: headerData.positionLabel.trim(),
                accentColor: accentColor,
                foregroundColor: foregroundColor,
                onTap: onProgressTap,
              ),
            PopupMenuButton<CollectionReaderMoreAction>(
              color: backgroundColor,
              tooltip: collectionsStrings.collectionActions,
              onSelected: onMoreSelected,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: CollectionReaderMoreAction.editCollection,
                  child: Text(collectionsStrings.editCollection),
                ),
                PopupMenuItem(
                  value: CollectionReaderMoreAction.manageCollectionItems,
                  child: Text(collectionsStrings.reader.manageCollectionItems),
                ),
                PopupMenuItem(
                  value: CollectionReaderMoreAction.currentMemoActions,
                  child: Text(collectionsStrings.reader.currentMemoActions),
                ),
              ],
              icon: Icon(
                Icons.more_horiz_rounded,
                color: foregroundColor,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayProgressChip extends StatelessWidget {
  const _OverlayProgressChip({
    required this.label,
    required this.accentColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final Color accentColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Material(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 58),
            height: CollectionReaderTokens.progressChipHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayBrightnessStrip extends StatelessWidget {
  const _OverlayBrightnessStrip({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.accentColor,
    required this.brightnessMode,
    required this.brightness,
    required this.onBrightnessModeChanged,
    required this.onBrightnessChanged,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color accentColor;
  final CollectionReaderBrightnessMode brightnessMode;
  final double brightness;
  final ValueChanged<CollectionReaderBrightnessMode> onBrightnessModeChanged;
  final ValueChanged<double> onBrightnessChanged;

  @override
  Widget build(BuildContext context) {
    final manual = brightnessMode == CollectionReaderBrightnessMode.manual;
    return Container(
      width: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              onBrightnessModeChanged(
                manual
                    ? CollectionReaderBrightnessMode.system
                    : CollectionReaderBrightnessMode.manual,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: manual
                    ? accentColor.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: manual
                  ? Icon(Icons.light_mode_rounded, size: 18, color: accentColor)
                  : Text(
                      'A',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: accentColor,
                  inactiveTrackColor: foregroundColor.withValues(alpha: 0.28),
                  thumbColor: accentColor,
                  overlayColor: accentColor.withValues(alpha: 0.18),
                ),
                child: Slider(
                  min: 0.1,
                  max: 1,
                  value: brightness.clamp(0.1, 1).toDouble(),
                  onChanged: onBrightnessChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _OverlayBottomPanel extends StatelessWidget {
  const _OverlayBottomPanel({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.mutedForegroundColor,
    required this.accentColor,
    required this.currentProgressText,
    required this.sliderValue,
    required this.sliderMax,
    required this.canPrevChapter,
    required this.canNextChapter,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.bottomActions,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color mutedForegroundColor;
  final Color accentColor;
  final String currentProgressText;
  final double sliderValue;
  final double sliderMax;
  final bool canPrevChapter;
  final bool canNextChapter;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderChangeEnd;
  final List<_OverlayBottomActionData> bottomActions;

  @override
  Widget build(BuildContext context) {
    final readerStrings = context.t.strings.collections.reader;
    return Material(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentProgressText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedForegroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _OverlayChapterButton(
                  label: readerStrings.tapActionPrevChapter,
                  enabled: canPrevChapter,
                  color: foregroundColor,
                  disabledColor: mutedForegroundColor.withValues(alpha: 0.55),
                  onTap: onPrevChapter,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 13,
                      ),
                      activeTrackColor: accentColor,
                      inactiveTrackColor: foregroundColor.withValues(
                        alpha: 0.28,
                      ),
                      thumbColor: accentColor,
                      overlayColor: accentColor.withValues(alpha: 0.18),
                    ),
                    child: Slider(
                      value: sliderValue.clamp(0, math.max(0, sliderMax)),
                      min: 0,
                      max: math.max(0, sliderMax),
                      divisions: sliderMax <= 0
                          ? null
                          : math.max(1, sliderMax.round()),
                      onChanged: onSliderChanged,
                      onChangeEnd: onSliderChangeEnd,
                    ),
                  ),
                ),
                _OverlayChapterButton(
                  label: readerStrings.tapActionNextChapter,
                  enabled: canNextChapter,
                  color: foregroundColor,
                  disabledColor: mutedForegroundColor.withValues(alpha: 0.55),
                  onTap: onNextChapter,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bottomActions
                  .map(
                    (action) => Expanded(
                      child: _OverlayBottomAction(
                        icon: action.icon,
                        label: action.label,
                        selected: action.selected,
                        foregroundColor: foregroundColor,
                        accentColor: accentColor,
                        onTap: action.onTap,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayChapterButton extends StatelessWidget {
  const _OverlayChapterButton({
    required this.label,
    required this.enabled,
    required this.color,
    required this.disabledColor,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final Color color;
  final Color disabledColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: disabledColor,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _OverlayFloatingButton extends StatelessWidget {
  const _OverlayFloatingButton({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.accentColor,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? accentColor;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? foregroundColor;
    return Material(
      color: selected ? activeColor.withValues(alpha: 0.2) : backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              color: selected ? activeColor : foregroundColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayBottomActionData {
  const _OverlayBottomActionData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

class _OverlayBottomAction extends StatelessWidget {
  const _OverlayBottomAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.foregroundColor,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color foregroundColor;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accentColor : foregroundColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _pageAnimationLabel(
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
