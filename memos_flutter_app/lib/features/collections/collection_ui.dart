import 'package:flutter/material.dart';

import '../../core/tag_colors.dart';
import '../../data/models/memo_collection.dart';
import '../../i18n/strings.g.dart';

const List<String> kCollectionIconKeys = <String>[
  MemoCollection.defaultIconKey,
  'bookmark',
  'book',
  'favorite',
  'travel',
  'lightbulb',
  'work',
  'photo_library',
];

const Map<String, IconData> kCollectionIcons = <String, IconData>{
  MemoCollection.defaultIconKey: Icons.auto_stories_rounded,
  'bookmark': Icons.bookmark_rounded,
  'book': Icons.menu_book_rounded,
  'favorite': Icons.favorite_rounded,
  'travel': Icons.travel_explore_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'work': Icons.work_rounded,
  'photo_library': Icons.photo_library_rounded,
};

const List<String> kCollectionAccentPalette = <String>[
  '#5B8DEF',
  '#4CB782',
  '#F4B400',
  '#E56B6F',
  '#9B72CF',
  '#00A7C4',
  '#7F8C8D',
];

IconData resolveCollectionIcon(String? iconKey) {
  final trimmed = iconKey?.trim();
  if (trimmed != null && kCollectionIcons.containsKey(trimmed)) {
    return kCollectionIcons[trimmed]!;
  }
  return kCollectionIcons[MemoCollection.defaultIconKey]!;
}

Color resolveCollectionAccentColor(
  String? accentColorHex, {
  required bool isDark,
}) {
  final parsed = parseTagColor(accentColorHex);
  if (parsed != null) return parsed;
  return isDark ? const Color(0xFF7CA8FF) : const Color(0xFF4F7FEF);
}

String collectionTypeLabel(BuildContext context, MemoCollectionType type) {
  return switch (type) {
    MemoCollectionType.smart => context.t.strings.collections.smart,
    MemoCollectionType.manual => context.t.strings.collections.manual,
  };
}

String collectionLayoutLabel(BuildContext context, CollectionLayoutMode mode) {
  return switch (mode) {
    CollectionLayoutMode.shelf => context.t.strings.collections.shelf,
    CollectionLayoutMode.timeline => context.t.strings.collections.timeline,
    CollectionLayoutMode.list => context.t.strings.collections.list,
  };
}

String collectionSectionLabel(
  BuildContext context,
  CollectionSectionMode mode,
) {
  return switch (mode) {
    CollectionSectionMode.none => context.t.strings.collections.noGroups,
    CollectionSectionMode.month => context.t.strings.collections.month,
    CollectionSectionMode.quarter => context.t.strings.collections.quarter,
    CollectionSectionMode.year => context.t.strings.collections.year,
  };
}

String collectionSortLabel(BuildContext context, CollectionSortMode mode) {
  return switch (mode) {
    CollectionSortMode.displayTimeDesc =>
      context.t.strings.collections.displayTimeDesc,
    CollectionSortMode.displayTimeAsc =>
      context.t.strings.collections.displayTimeAsc,
    CollectionSortMode.updateTimeDesc =>
      context.t.strings.collections.updatedTimeDesc,
    CollectionSortMode.updateTimeAsc =>
      context.t.strings.collections.updatedTimeAsc,
    CollectionSortMode.manualOrder => context.t.strings.collections.manualOrder,
  };
}

String collectionAttachmentRuleLabel(
  BuildContext context,
  CollectionAttachmentRule rule,
) {
  return switch (rule) {
    CollectionAttachmentRule.any => context.t.strings.collections.attachmentAny,
    CollectionAttachmentRule.required =>
      context.t.strings.collections.attachmentRequired,
    CollectionAttachmentRule.excluded =>
      context.t.strings.collections.attachmentNone,
    CollectionAttachmentRule.imagesOnly =>
      context.t.strings.collections.attachmentImagesOnly,
  };
}

String collectionCoverModeLabel(
  BuildContext context,
  CollectionCoverMode mode,
) {
  return switch (mode) {
    CollectionCoverMode.auto => context.t.strings.common.auto,
    CollectionCoverMode.attachment =>
      context.t.strings.collections.coverAttachment,
    CollectionCoverMode.icon => context.t.strings.legacy.msg_icon,
  };
}

String buildLocalizedCollectionRuleSummary(
  BuildContext context,
  MemoCollection collection,
) {
  if (collection.type == MemoCollectionType.manual) {
    return context.t.strings.collections.manualCollectionSummary;
  }
  final rules = collection.rules;
  final segments = <String>[];
  final tags = rules.normalizedTagPaths;
  if (tags.isNotEmpty) {
    final preview = tags.take(2).map((tag) => '#$tag').join(' / ');
    final suffix = switch (rules.tagMatchMode) {
      CollectionTagMatchMode.any => context.t.strings.collections.anyTag,
      CollectionTagMatchMode.all => context.t.strings.collections.allTags,
    };
    segments.add('$preview · $suffix');
  }
  switch (rules.visibility) {
    case CollectionVisibilityScope.all:
      break;
    case CollectionVisibilityScope.privateOnly:
      segments.add(context.t.strings.collections.privateOnly);
    case CollectionVisibilityScope.publicOnly:
      segments.add(context.t.strings.collections.publicOnly);
  }
  switch (rules.attachmentRule) {
    case CollectionAttachmentRule.any:
      break;
    case CollectionAttachmentRule.required:
      segments.add(context.t.strings.collections.hasAttachments);
    case CollectionAttachmentRule.excluded:
      segments.add(context.t.strings.collections.noAttachments);
    case CollectionAttachmentRule.imagesOnly:
      segments.add(context.t.strings.collections.imagesOnly);
  }
  if (rules.pinnedOnly) {
    segments.add(context.t.strings.collections.pinnedOnlySummary);
  }
  switch (rules.dateRule.type) {
    case CollectionDateRuleType.all:
      break;
    case CollectionDateRuleType.lastDays:
      final days = rules.dateRule.lastDays ?? 0;
      if (days > 0) {
        segments.add(context.t.strings.collections.lastDays(days: days));
      }
    case CollectionDateRuleType.customRange:
      segments.add(context.t.strings.collections.customRangeSummary);
  }
  if (segments.isEmpty) {
    return context.t.strings.collections.smartCollectionSummary;
  }
  return segments.join(' · ');
}

class CollectionLoadingView extends StatelessWidget {
  const CollectionLoadingView({
    super.key,
    this.label,
    this.centered = true,
    this.compact = false,
  });

  final String? label;
  final bool centered;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? context.t.strings.legacy.msg_loading;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 24,
        vertical: compact ? 20 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: compact ? 20 : 28,
            height: compact ? 20 : 28,
            child: const CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            effectiveLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );

    if (!centered) return content;
    return Center(child: content);
  }
}

class CollectionStatusView extends StatelessWidget {
  const CollectionStatusView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.centered = true,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final bool centered;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white70 : Colors.black54;
    final content = Padding(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 36 : 46, color: muted),
          SizedBox(height: compact ? 10 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 17 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 6 : 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 360 : 420),
              child: Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.45),
              ),
            ),
          ],
          if (action != null) ...[SizedBox(height: compact ? 14 : 18), action!],
        ],
      ),
    );

    if (!centered) return content;
    return Center(child: content);
  }
}

class CollectionErrorView extends StatelessWidget {
  const CollectionErrorView({
    super.key,
    required this.title,
    required this.message,
    this.centered = true,
    this.compact = false,
    this.action,
  });

  final String title;
  final String message;
  final bool centered;
  final bool compact;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return CollectionStatusView(
      icon: Icons.error_outline_rounded,
      title: title,
      description: message,
      centered: centered,
      compact: compact,
      action: action,
    );
  }
}
