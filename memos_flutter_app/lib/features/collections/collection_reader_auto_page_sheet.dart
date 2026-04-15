import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import 'collection_reader_panel.dart';

class CollectionReaderAutoPageSheet extends StatefulWidget {
  const CollectionReaderAutoPageSheet({
    super.key,
    required this.isRunning,
    required this.secondsPerPage,
    required this.onToggle,
    required this.onSecondsChanged,
  });

  final bool isRunning;
  final int secondsPerPage;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onSecondsChanged;

  @override
  State<CollectionReaderAutoPageSheet> createState() =>
      _CollectionReaderAutoPageSheetState();
}

class _CollectionReaderAutoPageSheetState
    extends State<CollectionReaderAutoPageSheet> {
  late bool _isRunning;
  late double _seconds;

  @override
  void initState() {
    super.initState();
    _isRunning = widget.isRunning;
    _seconds = widget.secondsPerPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final readerStrings = context.t.strings.collections.reader;
    return CollectionReaderSheetFrame(
      title: readerStrings.autoPageTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollectionReaderPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    final next = !_isRunning;
                    setState(() => _isRunning = next);
                    widget.onToggle(next);
                  },
                  icon: Icon(
                    _isRunning
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                  ),
                  label: Text(
                    _isRunning
                        ? readerStrings.autoPageStop
                        : readerStrings.autoPageStart,
                  ),
                ),
                const SizedBox(height: 14),
                CollectionReaderLabeledSlider(
                  label: readerStrings.autoPageSecondsPerPage,
                  valueText: '${_seconds.round()} s',
                  value: _seconds,
                  min: 1,
                  max: 60,
                  divisions: 59,
                  onChanged: (value) {
                    setState(() => _seconds = value);
                    widget.onSecondsChanged(value.round());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
