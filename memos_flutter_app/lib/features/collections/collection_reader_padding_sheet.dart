import 'package:flutter/material.dart';

import '../../data/models/collection_reader.dart';
import '../../i18n/strings.g.dart';
import 'collection_reader_panel.dart';

class CollectionReaderPaddingSheet extends StatefulWidget {
  const CollectionReaderPaddingSheet({
    super.key,
    required this.preferences,
    required this.onPagePaddingChanged,
    required this.onHeaderPaddingChanged,
    required this.onFooterPaddingChanged,
    required this.onShowHeaderLineChanged,
    required this.onShowFooterLineChanged,
  });

  final CollectionReaderPreferences preferences;
  final ValueChanged<EdgeInsets> onPagePaddingChanged;
  final ValueChanged<EdgeInsets> onHeaderPaddingChanged;
  final ValueChanged<EdgeInsets> onFooterPaddingChanged;
  final ValueChanged<bool> onShowHeaderLineChanged;
  final ValueChanged<bool> onShowFooterLineChanged;

  @override
  State<CollectionReaderPaddingSheet> createState() =>
      _CollectionReaderPaddingSheetState();
}

class _CollectionReaderPaddingSheetState
    extends State<CollectionReaderPaddingSheet> {
  late EdgeInsets _pagePadding;
  late EdgeInsets _headerPadding;
  late EdgeInsets _footerPadding;
  late bool _showHeaderLine;
  late bool _showFooterLine;

  @override
  void initState() {
    super.initState();
    final preferences = widget.preferences;
    _pagePadding = preferences.pagePadding;
    _headerPadding = preferences.headerPadding;
    _footerPadding = preferences.footerPadding;
    _showHeaderLine = preferences.showHeaderLine;
    _showFooterLine = preferences.showFooterLine;
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
            readerStrings.paddingTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _SectionTitle(readerStrings.paddingBody),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingTop,
                  value: _pagePadding.top,
                  onChanged: (value) {
                    final next = _pagePadding.copyWith(top: value);
                    setState(() => _pagePadding = next);
                    widget.onPagePaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingBottom,
                  value: _pagePadding.bottom,
                  onChanged: (value) {
                    final next = _pagePadding.copyWith(bottom: value);
                    setState(() => _pagePadding = next);
                    widget.onPagePaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingLeft,
                  value: _pagePadding.left,
                  onChanged: (value) {
                    final next = _pagePadding.copyWith(left: value);
                    setState(() => _pagePadding = next);
                    widget.onPagePaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingRight,
                  value: _pagePadding.right,
                  onChanged: (value) {
                    final next = _pagePadding.copyWith(right: value);
                    setState(() => _pagePadding = next);
                    widget.onPagePaddingChanged(next);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(readerStrings.paddingHeader),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readerStrings.showHeaderDivider),
                  value: _showHeaderLine,
                  onChanged: (value) {
                    setState(() => _showHeaderLine = value);
                    widget.onShowHeaderLineChanged(value);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingTop,
                  value: _headerPadding.top,
                  onChanged: (value) {
                    final next = _headerPadding.copyWith(top: value);
                    setState(() => _headerPadding = next);
                    widget.onHeaderPaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingBottom,
                  value: _headerPadding.bottom,
                  onChanged: (value) {
                    final next = _headerPadding.copyWith(bottom: value);
                    setState(() => _headerPadding = next);
                    widget.onHeaderPaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingLeft,
                  value: _headerPadding.left,
                  onChanged: (value) {
                    final next = _headerPadding.copyWith(left: value);
                    setState(() => _headerPadding = next);
                    widget.onHeaderPaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingRight,
                  value: _headerPadding.right,
                  onChanged: (value) {
                    final next = _headerPadding.copyWith(right: value);
                    setState(() => _headerPadding = next);
                    widget.onHeaderPaddingChanged(next);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(readerStrings.paddingFooter),
          CollectionReaderPanelCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readerStrings.showFooterDivider),
                  value: _showFooterLine,
                  onChanged: (value) {
                    setState(() => _showFooterLine = value);
                    widget.onShowFooterLineChanged(value);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingTop,
                  value: _footerPadding.top,
                  onChanged: (value) {
                    final next = _footerPadding.copyWith(top: value);
                    setState(() => _footerPadding = next);
                    widget.onFooterPaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingBottom,
                  value: _footerPadding.bottom,
                  onChanged: (value) {
                    final next = _footerPadding.copyWith(bottom: value);
                    setState(() => _footerPadding = next);
                    widget.onFooterPaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingLeft,
                  value: _footerPadding.left,
                  onChanged: (value) {
                    final next = _footerPadding.copyWith(left: value);
                    setState(() => _footerPadding = next);
                    widget.onFooterPaddingChanged(next);
                  },
                ),
                _edgeInsetsSlider(
                  context,
                  label: readerStrings.paddingRight,
                  value: _footerPadding.right,
                  onChanged: (value) {
                    final next = _footerPadding.copyWith(right: value);
                    setState(() => _footerPadding = next);
                    widget.onFooterPaddingChanged(next);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _edgeInsetsSlider(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return CollectionReaderLabeledSlider(
      label: label,
      valueText: value.toStringAsFixed(0),
      value: value,
      min: 0,
      max: 48,
      divisions: 48,
      onChanged: onChanged,
    );
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
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return CollectionReaderSectionTitle(label);
  }
}
