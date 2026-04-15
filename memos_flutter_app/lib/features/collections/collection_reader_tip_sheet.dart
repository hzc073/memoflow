import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';

import '../../data/models/collection_reader.dart';
import '../../i18n/strings.g.dart';
import 'collection_reader_panel.dart';

class CollectionReaderTipSheet extends StatefulWidget {
  const CollectionReaderTipSheet({
    super.key,
    required this.preferences,
    required this.onTitleModeChanged,
    required this.onTitleScaleChanged,
    required this.onTitleTopSpacingChanged,
    required this.onTitleBottomSpacingChanged,
    required this.onTipLayoutChanged,
  });

  final CollectionReaderPreferences preferences;
  final ValueChanged<CollectionReaderTitleMode> onTitleModeChanged;
  final ValueChanged<double> onTitleScaleChanged;
  final ValueChanged<double> onTitleTopSpacingChanged;
  final ValueChanged<double> onTitleBottomSpacingChanged;
  final ValueChanged<CollectionReaderTipLayout> onTipLayoutChanged;

  @override
  State<CollectionReaderTipSheet> createState() =>
      _CollectionReaderTipSheetState();
}

class _CollectionReaderTipSheetState extends State<CollectionReaderTipSheet> {
  late CollectionReaderTipLayout _tipLayout;
  late CollectionReaderTitleMode _titleMode;
  late double _titleScale;
  late double _titleTopSpacing;
  late double _titleBottomSpacing;

  @override
  void initState() {
    super.initState();
    _tipLayout = widget.preferences.tipLayout;
    _titleMode = widget.preferences.titleMode;
    _titleScale = widget.preferences.titleScale;
    _titleTopSpacing = widget.preferences.titleTopSpacing;
    _titleBottomSpacing = widget.preferences.titleBottomSpacing;
  }

  @override
  Widget build(BuildContext context) {
    final readerStrings = context.t.strings.collections.reader;
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
          Text(
            readerStrings.tipSettingsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          CollectionReaderSectionTitle(readerStrings.titleSection),
          CollectionReaderPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CollectionReaderHorizontalScroller(
                  child: SegmentedButton<CollectionReaderTitleMode>(
                    segments: [
                      ButtonSegment(
                        value: CollectionReaderTitleMode.left,
                        label: Text(readerStrings.titleModeLeft),
                      ),
                      ButtonSegment(
                        value: CollectionReaderTitleMode.center,
                        label: Text(readerStrings.titleModeCenter),
                      ),
                      ButtonSegment(
                        value: CollectionReaderTitleMode.hidden,
                        label: Text(readerStrings.titleModeHidden),
                      ),
                    ],
                    selected: <CollectionReaderTitleMode>{_titleMode},
                    onSelectionChanged: (selection) {
                      final value = selection.first;
                      setState(() => _titleMode = value);
                      widget.onTitleModeChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _LabeledSlider(
                  label: readerStrings.titleScale,
                  valueText: _titleScale.toStringAsFixed(2),
                  value: _titleScale,
                  min: 0.8,
                  max: 1.6,
                  onChanged: (value) {
                    setState(() => _titleScale = value);
                    widget.onTitleScaleChanged(value);
                  },
                ),
                _LabeledSlider(
                  label: readerStrings.titleTopSpacing,
                  valueText: _titleTopSpacing.toStringAsFixed(0),
                  value: _titleTopSpacing,
                  min: 0,
                  max: 48,
                  onChanged: (value) {
                    setState(() => _titleTopSpacing = value);
                    widget.onTitleTopSpacingChanged(value);
                  },
                ),
                _LabeledSlider(
                  label: readerStrings.titleBottomSpacing,
                  valueText: _titleBottomSpacing.toStringAsFixed(0),
                  value: _titleBottomSpacing,
                  min: 0,
                  max: 48,
                  onChanged: (value) {
                    setState(() => _titleBottomSpacing = value);
                    widget.onTitleBottomSpacingChanged(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CollectionReaderSectionTitle(readerStrings.headerFooterSection),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                _buildDisplayModeRow(
                  context,
                  label: readerStrings.headerMode,
                  value: _tipLayout.headerMode,
                  onChanged: (value) =>
                      _updateTipLayout(_tipLayout.copyWith(headerMode: value)),
                ),
                _buildDisplayModeRow(
                  context,
                  label: readerStrings.footerMode,
                  value: _tipLayout.footerMode,
                  onChanged: (value) =>
                      _updateTipLayout(_tipLayout.copyWith(footerMode: value)),
                ),
                const Divider(height: 24),
                _buildSlotPicker(
                  context,
                  label: readerStrings.headerLeft,
                  value: _tipLayout.headerLeft,
                  onChanged: (value) =>
                      _updateTipLayout(_tipLayout.copyWith(headerLeft: value)),
                ),
                _buildSlotPicker(
                  context,
                  label: readerStrings.headerCenter,
                  value: _tipLayout.headerCenter,
                  onChanged: (value) => _updateTipLayout(
                    _tipLayout.copyWith(headerCenter: value),
                  ),
                ),
                _buildSlotPicker(
                  context,
                  label: readerStrings.headerRight,
                  value: _tipLayout.headerRight,
                  onChanged: (value) =>
                      _updateTipLayout(_tipLayout.copyWith(headerRight: value)),
                ),
                const Divider(height: 24),
                _buildSlotPicker(
                  context,
                  label: readerStrings.footerLeft,
                  value: _tipLayout.footerLeft,
                  onChanged: (value) =>
                      _updateTipLayout(_tipLayout.copyWith(footerLeft: value)),
                ),
                _buildSlotPicker(
                  context,
                  label: readerStrings.footerCenter,
                  value: _tipLayout.footerCenter,
                  onChanged: (value) => _updateTipLayout(
                    _tipLayout.copyWith(footerCenter: value),
                  ),
                ),
                _buildSlotPicker(
                  context,
                  label: readerStrings.footerRight,
                  value: _tipLayout.footerRight,
                  onChanged: (value) =>
                      _updateTipLayout(_tipLayout.copyWith(footerRight: value)),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readerStrings.tipTextColor),
                  subtitle: Text(
                    _colorLabel(context, _tipLayout.tipColorOverride),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showColorPicker(
                    context,
                    title: readerStrings.tipTextColor,
                    currentColor:
                        _tipLayout.tipColorOverride ??
                        Theme.of(context).hintColor,
                    onSelected: (color) => _updateTipLayout(
                      _tipLayout.copyWith(tipColorOverride: color),
                    ),
                  ),
                  onLongPress: () => _updateTipLayout(
                    _tipLayout.copyWith(tipColorOverride: null),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readerStrings.dividerColor),
                  subtitle: Text(
                    _colorLabel(context, _tipLayout.tipDividerColorOverride),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showColorPicker(
                    context,
                    title: readerStrings.dividerColor,
                    currentColor:
                        _tipLayout.tipDividerColorOverride ??
                        Theme.of(context).dividerColor,
                    onSelected: (color) => _updateTipLayout(
                      _tipLayout.copyWith(tipDividerColorOverride: color),
                    ),
                  ),
                  onLongPress: () => _updateTipLayout(
                    _tipLayout.copyWith(tipDividerColorOverride: null),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayModeRow(
    BuildContext context, {
    required String label,
    required CollectionReaderTipDisplayMode value,
    required ValueChanged<CollectionReaderTipDisplayMode> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<CollectionReaderTipDisplayMode>(
            value: value,
            items: CollectionReaderTipDisplayMode.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(_displayModeLabel(context, item)),
                  ),
                )
                .toList(growable: false),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlotPicker(
    BuildContext context, {
    required String label,
    required CollectionReaderTipSlot value,
    required ValueChanged<CollectionReaderTipSlot> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_slotLabel(context, value)),
      trailing: PopupMenuButton<CollectionReaderTipSlot>(
        initialValue: value,
        onSelected: onChanged,
        itemBuilder: (context) {
          return CollectionReaderTipSlot.values
              .map(
                (slot) => PopupMenuItem(
                  value: slot,
                  child: Text(_slotLabel(context, slot)),
                ),
              )
              .toList(growable: false);
        },
      ),
    );
  }

  void _updateTipLayout(CollectionReaderTipLayout next) {
    setState(() => _tipLayout = next);
    widget.onTipLayoutChanged(next);
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

  String _colorLabel(BuildContext context, Color? color) {
    if (color == null) {
      return context.t.strings.collections.reader.useDefaultLongPressReset;
    }
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  String _slotLabel(BuildContext context, CollectionReaderTipSlot slot) {
    final readerStrings = context.t.strings.collections.reader;
    return switch (slot) {
      CollectionReaderTipSlot.none => readerStrings.tipSlotNone,
      CollectionReaderTipSlot.collectionTitle =>
        readerStrings.tipSlotCollectionTitle,
      CollectionReaderTipSlot.chapterTitle => readerStrings.tipSlotChapterTitle,
      CollectionReaderTipSlot.time => readerStrings.tipSlotTime,
      CollectionReaderTipSlot.battery => readerStrings.tipSlotBattery,
      CollectionReaderTipSlot.batteryPercentage =>
        readerStrings.tipSlotBatteryPercentage,
      CollectionReaderTipSlot.page => readerStrings.tipSlotPage,
      CollectionReaderTipSlot.totalProgress =>
        readerStrings.tipSlotTotalProgress,
      CollectionReaderTipSlot.pageAndTotal => readerStrings.tipSlotPageAndTotal,
      CollectionReaderTipSlot.timeBattery => readerStrings.tipSlotTimeBattery,
      CollectionReaderTipSlot.timeBatteryPercentage =>
        readerStrings.tipSlotTimeBatteryPercentage,
    };
  }

  String _displayModeLabel(
    BuildContext context,
    CollectionReaderTipDisplayMode mode,
  ) {
    final readerStrings = context.t.strings.collections.reader;
    return switch (mode) {
      CollectionReaderTipDisplayMode.hidden => readerStrings.tipDisplayHidden,
      CollectionReaderTipDisplayMode.inline => readerStrings.tipDisplayInline,
      CollectionReaderTipDisplayMode.reserved =>
        readerStrings.tipDisplayReserved,
    };
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return const CollectionReaderSheetHandle();
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return CollectionReaderLabeledSlider(
      label: label,
      valueText: valueText,
      value: value,
      min: min,
      max: max,
      onChanged: onChanged,
    );
  }
}
