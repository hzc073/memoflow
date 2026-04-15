import 'package:flutter/material.dart';

import '../../data/models/collection_reader.dart';
import '../../i18n/strings.g.dart';
import 'collection_reader_panel.dart';
import 'reader_platform_capabilities.dart';

class CollectionReaderMoreSettingsSheet extends StatefulWidget {
  const CollectionReaderMoreSettingsSheet({
    super.key,
    required this.displayConfig,
    required this.inputConfig,
    required this.capabilities,
    required this.onDisplayConfigChanged,
    required this.onInputConfigChanged,
    required this.onOpenClickActions,
  });

  final CollectionReaderDisplayConfig displayConfig;
  final CollectionReaderInputConfig inputConfig;
  final ReaderPlatformCapabilities capabilities;
  final ValueChanged<CollectionReaderDisplayConfig> onDisplayConfigChanged;
  final ValueChanged<CollectionReaderInputConfig> onInputConfigChanged;
  final VoidCallback onOpenClickActions;

  @override
  State<CollectionReaderMoreSettingsSheet> createState() =>
      _CollectionReaderMoreSettingsSheetState();
}

class _CollectionReaderMoreSettingsSheetState
    extends State<CollectionReaderMoreSettingsSheet> {
  late CollectionReaderDisplayConfig _displayConfig;
  late CollectionReaderInputConfig _inputConfig;

  @override
  void initState() {
    super.initState();
    _displayConfig = widget.displayConfig;
    _inputConfig = widget.inputConfig;
  }

  @override
  Widget build(BuildContext context) {
    final caps = widget.capabilities;
    final readerStrings = context.t.strings.collections.reader;
    return CollectionReaderSheetFrame(
      title: readerStrings.moreSettingsTitle,
      expandChild: true,
      child: ListView(
        children: [
          CollectionReaderSectionTitle(readerStrings.moreDisplay),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                _switchTile(
                  context,
                  title: readerStrings.hideStatusBar,
                  value: _displayConfig.hideStatusBar,
                  enabled: caps.canControlSystemBars,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(hideStatusBar: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.hideNavigationBar,
                  value: _displayConfig.hideNavigationBar,
                  enabled: caps.canControlSystemBars,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(hideNavigationBar: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.padDisplayCutouts,
                  value: _displayConfig.padDisplayCutouts,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(padDisplayCutouts: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.keepScreenAwake,
                  value: _displayConfig.keepScreenAwakeInReader,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(keepScreenAwakeInReader: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.barsFollowPageStyle,
                  value: _displayConfig.followPageStyleForBars,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(followPageStyleForBars: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.showReadTitleAddition,
                  value: _displayConfig.showReadTitleAddition,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(showReadTitleAddition: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.showBrightnessOverlay,
                  value: _displayConfig.showBrightnessOverlay,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(showBrightnessOverlay: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CollectionReaderSectionTitle(readerStrings.moreInput),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                _switchTile(
                  context,
                  title: readerStrings.mouseWheelPageTurn,
                  value: _inputConfig.mouseWheelPageTurn,
                  enabled: caps.canUseMouseWheelPaging,
                  onChanged: (value) => _updateInput(
                    _inputConfig.copyWith(mouseWheelPageTurn: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.volumeKeyPageTurn,
                  value: _inputConfig.volumeKeyPageTurn,
                  enabled: caps.canHandleHardwareVolumePaging,
                  onChanged: (value) => _updateInput(
                    _inputConfig.copyWith(volumeKeyPageTurn: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.longPressKeyPageTurn,
                  value: _inputConfig.longPressKeyPageTurn,
                  enabled: caps.canHandleHardwareVolumePaging,
                  onChanged: (value) => _updateInput(
                    _inputConfig.copyWith(longPressKeyPageTurn: value),
                  ),
                ),
                CollectionReaderLabeledSlider(
                  label: readerStrings.touchSlop,
                  valueText: '${_inputConfig.pageTouchSlop}px',
                  value: _inputConfig.pageTouchSlop.toDouble(),
                  min: 8,
                  max: 36,
                  divisions: 28,
                  onChanged: (value) => _updateInput(
                    _inputConfig.copyWith(pageTouchSlop: value.round()),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readerStrings.clickActionsTitle),
                  subtitle: Text(readerStrings.clickActionsSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onOpenClickActions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CollectionReaderSectionTitle(readerStrings.moreContent),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                _switchTile(
                  context,
                  title: readerStrings.allowTextSelection,
                  value: _displayConfig.allowTextSelection,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(allowTextSelection: value),
                  ),
                ),
                _switchTile(
                  context,
                  title: readerStrings.previewImageOnTap,
                  value: _displayConfig.previewImageOnTap,
                  onChanged: (value) => _updateDisplay(
                    _displayConfig.copyWith(previewImageOnTap: value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: enabled
          ? null
          : Text(context.t.strings.collections.reader.platformUnavailable),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  void _updateDisplay(CollectionReaderDisplayConfig next) {
    setState(() => _displayConfig = next);
    widget.onDisplayConfigChanged(next);
  }

  void _updateInput(CollectionReaderInputConfig next) {
    setState(() => _inputConfig = next);
    widget.onInputConfigChanged(next);
  }
}
