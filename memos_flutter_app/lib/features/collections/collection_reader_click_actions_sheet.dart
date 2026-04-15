import 'package:flutter/material.dart';

import '../../data/models/collection_reader.dart';
import '../../i18n/strings.g.dart';
import 'collection_reader_panel.dart';

class CollectionReaderClickActionsSheet extends StatefulWidget {
  const CollectionReaderClickActionsSheet({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final CollectionReaderTapRegionConfig config;
  final ValueChanged<CollectionReaderTapRegionConfig> onChanged;

  @override
  State<CollectionReaderClickActionsSheet> createState() =>
      _CollectionReaderClickActionsSheetState();
}

class _CollectionReaderClickActionsSheetState
    extends State<CollectionReaderClickActionsSheet> {
  late CollectionReaderTapRegionConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    final readerStrings = context.t.strings.collections.reader;
    final cells = <_TapCell>[
      _TapCell(readerStrings.tapRegionTopLeft, _config.topLeft, (value) {
        _update(_config.copyWith(topLeft: value));
      }),
      _TapCell(readerStrings.tapRegionTopCenter, _config.topCenter, (value) {
        _update(_config.copyWith(topCenter: value));
      }),
      _TapCell(readerStrings.tapRegionTopRight, _config.topRight, (value) {
        _update(_config.copyWith(topRight: value));
      }),
      _TapCell(readerStrings.tapRegionMiddleLeft, _config.middleLeft, (value) {
        _update(_config.copyWith(middleLeft: value));
      }),
      _TapCell(readerStrings.tapRegionMiddleCenter, _config.middleCenter, (
        value,
      ) {
        _update(_config.copyWith(middleCenter: value));
      }),
      _TapCell(readerStrings.tapRegionMiddleRight, _config.middleRight, (
        value,
      ) {
        _update(_config.copyWith(middleRight: value));
      }),
      _TapCell(readerStrings.tapRegionBottomLeft, _config.bottomLeft, (value) {
        _update(_config.copyWith(bottomLeft: value));
      }),
      _TapCell(readerStrings.tapRegionBottomCenter, _config.bottomCenter, (
        value,
      ) {
        _update(_config.copyWith(bottomCenter: value));
      }),
      _TapCell(readerStrings.tapRegionBottomRight, _config.bottomRight, (
        value,
      ) {
        _update(_config.copyWith(bottomRight: value));
      }),
    ];
    return CollectionReaderSheetFrame(
      title: readerStrings.clickActionsTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            readerStrings.clickActionsSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 380;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isCompact ? 0.82 : 0.94,
                ),
                itemBuilder: (context, index) {
                  final cell = cells[index];
                  return CollectionReaderPanelCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cell.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Spacer(),
                        DropdownButton<CollectionReaderTapAction>(
                          isExpanded: true,
                          value: cell.action,
                          items: CollectionReaderTapAction.values
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    _actionLabel(context, item),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (next) {
                            if (next != null) {
                              cell.onChanged(next);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _update(CollectionReaderTapRegionConfig next) {
    setState(() => _config = next);
    widget.onChanged(next);
  }

  String _actionLabel(BuildContext context, CollectionReaderTapAction action) {
    final readerStrings = context.t.strings.collections.reader;
    return switch (action) {
      CollectionReaderTapAction.none => readerStrings.tapActionNone,
      CollectionReaderTapAction.menu => readerStrings.tapActionMenu,
      CollectionReaderTapAction.nextPage => readerStrings.tapActionNextPage,
      CollectionReaderTapAction.prevPage => readerStrings.tapActionPrevPage,
      CollectionReaderTapAction.nextChapter =>
        readerStrings.tapActionNextChapter,
      CollectionReaderTapAction.prevChapter =>
        readerStrings.tapActionPrevChapter,
      CollectionReaderTapAction.toc => readerStrings.tapActionToc,
      CollectionReaderTapAction.search => readerStrings.tapActionSearch,
    };
  }
}

class _TapCell {
  const _TapCell(this.label, this.action, this.onChanged);

  final String label;
  final CollectionReaderTapAction action;
  final ValueChanged<CollectionReaderTapAction> onChanged;
}
