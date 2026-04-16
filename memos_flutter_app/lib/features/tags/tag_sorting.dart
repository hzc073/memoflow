import 'package:flutter/material.dart';

import '../../core/tag_list_mode.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';
import 'tag_tree.dart';

List<TagStat> applyTagListMode(List<TagStat> tags, TagListMode mode) {
  final items = List<TagStat>.of(tags, growable: false);
  switch (mode) {
    case TagListMode.all:
      return items;
    case TagListMode.frequent:
      final sorted = items.toList(growable: false);
      sorted.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final byRecent = (b.lastUsedTimeSec ?? 0).compareTo(
          a.lastUsedTimeSec ?? 0,
        );
        if (byRecent != 0) return byRecent;
        return a.tag.compareTo(b.tag);
      });
      return sorted;
    case TagListMode.recent:
      final sorted = items.toList(growable: false);
      sorted.sort((a, b) {
        final byRecent = (b.lastUsedTimeSec ?? 0).compareTo(
          a.lastUsedTimeSec ?? 0,
        );
        if (byRecent != 0) return byRecent;
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return a.tag.compareTo(b.tag);
      });
      return sorted;
    case TagListMode.pinned:
      return items.where((tag) => tag.pinned).toList(growable: false);
  }
}

int compareTagTreeNodesByMode(TagTreeNode a, TagTreeNode b, TagListMode mode) {
  switch (mode) {
    case TagListMode.all:
    case TagListMode.pinned:
      return 0;
    case TagListMode.frequent:
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      final byRecent = (b.lastUsedTimeSec ?? 0).compareTo(
        a.lastUsedTimeSec ?? 0,
      );
      if (byRecent != 0) return byRecent;
      return 0;
    case TagListMode.recent:
      final byRecent = (b.lastUsedTimeSec ?? 0).compareTo(
        a.lastUsedTimeSec ?? 0,
      );
      if (byRecent != 0) return byRecent;
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return 0;
  }
}

TagTreeFilterResult buildTagTreeForMode(
  List<TagStat> tags, {
  required TagListMode mode,
}) {
  final filteredTags = applyTagListMode(tags, mode);
  final fullTagTree = buildTagTree(
    tags,
    comparator: (a, b) => compareTagTreeNodesByMode(a, b, mode),
  );
  final filteredPaths = filteredTags.map((tag) => tag.path).toSet();
  final shouldFilterTree = filteredPaths.length < tags.length;
  if (!shouldFilterTree) {
    return TagTreeFilterResult(
      nodes: fullTagTree,
      autoExpandedPaths: const <String>{},
    );
  }
  return filterTagTree(
    fullTagTree,
    (node) => filteredPaths.contains(node.path),
  );
}

String tagListModeLabel(BuildContext context, TagListMode mode) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return switch (mode) {
    TagListMode.all => context.t.strings.legacy.msg_all_tags,
    TagListMode.frequent => switch (languageCode) {
      'de' => 'H\u00E4ufig',
      'ja' => '\u3088\u304F\u4F7F\u3046',
      'zh' => '\u5E38\u7528',
      _ => 'Frequent',
    },
    TagListMode.recent => switch (languageCode) {
      'de' => 'Zuletzt',
      'ja' => '\u6700\u8FD1',
      'zh' => '\u6700\u8FD1',
      _ => 'Recent',
    },
    TagListMode.pinned => context.t.strings.legacy.msg_pinned,
  };
}

IconData tagListModeIcon(TagListMode mode) {
  return switch (mode) {
    TagListMode.all => Icons.tune,
    TagListMode.frequent => Icons.local_fire_department_outlined,
    TagListMode.recent => Icons.schedule_outlined,
    TagListMode.pinned => Icons.push_pin_outlined,
  };
}

class TagListModeMenuButton extends StatelessWidget {
  const TagListModeMenuButton({
    super.key,
    required this.mode,
    required this.onSelected,
    required this.iconColor,
    this.iconSize = 20,
  });

  final TagListMode mode;
  final ValueChanged<TagListMode> onSelected;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TagListMode>(
      tooltip: context.t.strings.legacy.msg_sort,
      initialValue: mode,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in TagListMode.values)
          CheckedPopupMenuItem<TagListMode>(
            value: value,
            checked: mode == value,
            child: Text(tagListModeLabel(context, value)),
          ),
      ],
      icon: Icon(tagListModeIcon(mode), color: iconColor, size: iconSize),
    );
  }
}
