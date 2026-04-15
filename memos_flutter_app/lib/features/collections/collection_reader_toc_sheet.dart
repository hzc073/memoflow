import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import 'collection_reader_utils.dart';
import 'collection_reader_panel.dart';

typedef CollectionReaderTocSelect =
    FutureOr<void> Function(CollectionReaderTocEntry entry);

class CollectionReaderTocSheet extends StatelessWidget {
  const CollectionReaderTocSheet({
    super.key,
    required this.entries,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<CollectionReaderTocEntry> entries;
  final int currentIndex;
  final CollectionReaderTocSelect onSelect;

  @override
  Widget build(BuildContext context) {
    return CollectionReaderSheetFrame(
      title: context.t.strings.collections.collection,
      expandChild: true,
      trailing: Text(
        '${currentIndex + 1}/${entries.length}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: CollectionReaderPanelCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final selected = entry.memoIndex == currentIndex;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                child: Text('${entry.memoIndex + 1}'),
              ),
              title: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: selected
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      )
                    : null,
              ),
              subtitle: Text(entry.subtitle),
              onTap: () async {
                await onSelect(entry);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        ),
      ),
    );
  }
}
