import '../../core/tag_colors.dart';
import '../../core/tags.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_collection.dart';

typedef CanonicalTagPathResolver = String Function(String path);
typedef TagColorHexResolver = String? Function(String path);

class MemoCollectionPreview {
  const MemoCollectionPreview({
    required this.itemCount,
    required this.imageItemCount,
    required this.latestUpdateTime,
    required this.sampleItems,
    required this.coverAttachment,
    required this.effectiveAccentColorHex,
    required this.ruleSummary,
  });

  final int itemCount;
  final int imageItemCount;
  final DateTime? latestUpdateTime;
  final List<LocalMemo> sampleItems;
  final Attachment? coverAttachment;
  final String? effectiveAccentColorHex;
  final String ruleSummary;

  bool get isEmpty => itemCount == 0;
}

class MemoCollectionDashboardItem {
  const MemoCollectionDashboardItem({
    required this.collection,
    required this.preview,
    required this.items,
  });

  final MemoCollection collection;
  final MemoCollectionPreview preview;
  final List<LocalMemo> items;
}

List<LocalMemo> resolveCollectionItems(
  MemoCollection collection,
  List<LocalMemo> candidates, {
  List<String> manualMemoUids = const <String>[],
  CanonicalTagPathResolver resolveCanonicalTagPath = _identityCanonicalPath,
}) {
  switch (collection.type) {
    case MemoCollectionType.smart:
      final items = candidates
          .where((memo) {
            return _matchesSmartCollection(
              memo,
              collection.rules,
              resolveCanonicalTagPath: resolveCanonicalTagPath,
            );
          })
          .toList(growable: true);
      sortCollectionItems(items, collection.view.sortMode);
      return items;
    case MemoCollectionType.manual:
      return _resolveManualCollectionItems(
        candidates,
        manualMemoUids,
        collection.view.sortMode,
      );
  }
}

void sortCollectionItems(List<LocalMemo> items, CollectionSortMode sortMode) {
  if (sortMode == CollectionSortMode.manualOrder) {
    return;
  }
  items.sort((a, b) {
    final result = switch (sortMode) {
      CollectionSortMode.displayTimeDesc => b.effectiveDisplayTime.compareTo(
        a.effectiveDisplayTime,
      ),
      CollectionSortMode.displayTimeAsc => a.effectiveDisplayTime.compareTo(
        b.effectiveDisplayTime,
      ),
      CollectionSortMode.updateTimeDesc => b.updateTime.compareTo(a.updateTime),
      CollectionSortMode.updateTimeAsc => a.updateTime.compareTo(b.updateTime),
      CollectionSortMode.manualOrder => 0,
    };
    if (result != 0) return result;
    return a.uid.compareTo(b.uid);
  });
}

List<LocalMemo> _resolveManualCollectionItems(
  List<LocalMemo> candidates,
  List<String> manualMemoUids,
  CollectionSortMode sortMode,
) {
  final items = resolveManualCollectionItemsInStoredOrder(
    candidates,
    manualMemoUids,
  ).toList(growable: true);
  if (sortMode != CollectionSortMode.manualOrder) {
    sortCollectionItems(items, sortMode);
  }
  return items;
}

List<LocalMemo> resolveManualCollectionItemsInStoredOrder(
  List<LocalMemo> candidates,
  List<String> manualMemoUids,
) {
  final normalizedOrder = manualMemoUids
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (normalizedOrder.isEmpty) {
    return const <LocalMemo>[];
  }

  final memoByUid = <String, LocalMemo>{};
  for (final memo in candidates) {
    final uid = memo.uid.trim();
    if (uid.isEmpty) continue;
    memoByUid[uid] = memo;
  }

  final items = <LocalMemo>[];
  for (final uid in normalizedOrder) {
    final memo = memoByUid[uid];
    if (memo == null) continue;
    items.add(memo);
  }
  return items;
}

MemoCollectionPreview buildCollectionPreview(
  MemoCollection collection,
  List<LocalMemo> items, {
  TagColorHexResolver? resolveTagColorHexByPath,
}) {
  final latestUpdateTime = items.isEmpty
      ? null
      : items
            .map((item) => item.updateTime)
            .reduce(
              (value, element) => value.isAfter(element) ? value : element,
            );
  final imageItemCount = items.where(_memoHasImage).length;
  final coverAttachment = resolveCollectionCoverAttachment(collection, items);
  final effectiveAccentColorHex =
      normalizeTagColorHex(collection.accentColorHex) ??
      _resolveFallbackAccentColorHex(
        collection,
        resolveTagColorHexByPath: resolveTagColorHexByPath,
      );
  return MemoCollectionPreview(
    itemCount: items.length,
    imageItemCount: imageItemCount,
    latestUpdateTime: latestUpdateTime,
    sampleItems: items.take(3).toList(growable: false),
    coverAttachment: coverAttachment,
    effectiveAccentColorHex: effectiveAccentColorHex,
    ruleSummary: buildCollectionRuleSummary(collection),
  );
}

Attachment? resolveCollectionCoverAttachment(
  MemoCollection collection,
  List<LocalMemo> items,
) {
  if (collection.cover.mode == CollectionCoverMode.icon) {
    return null;
  }

  if (collection.cover.mode == CollectionCoverMode.attachment) {
    final memoUid = collection.cover.memoUid?.trim();
    final attachmentUid = collection.cover.attachmentUid?.trim();
    if (memoUid != null && memoUid.isNotEmpty && attachmentUid != null) {
      for (final memo in items) {
        if (memo.uid != memoUid) continue;
        for (final attachment in memo.attachments) {
          if (attachment.uid == attachmentUid && attachment.isImage) {
            return attachment;
          }
        }
      }
    }
  }

  for (final memo in items.take(12)) {
    for (final attachment in memo.attachments) {
      if (attachment.isImage) {
        return attachment;
      }
    }
  }
  return null;
}

String buildCollectionRuleSummary(MemoCollection collection) {
  if (collection.type == MemoCollectionType.manual) {
    return 'Manual collection';
  }
  final rules = collection.rules;
  final segments = <String>[];
  final tags = rules.normalizedTagPaths;
  if (tags.isNotEmpty) {
    final preview = tags.take(2).map((tag) => '#$tag').join(' / ');
    final suffix = switch (rules.tagMatchMode) {
      CollectionTagMatchMode.any => 'Any tag',
      CollectionTagMatchMode.all => 'All tags',
    };
    segments.add('$preview · $suffix');
  }
  switch (rules.visibility) {
    case CollectionVisibilityScope.all:
      break;
    case CollectionVisibilityScope.privateOnly:
      segments.add('Private only');
    case CollectionVisibilityScope.publicOnly:
      segments.add('Public only');
  }
  switch (rules.attachmentRule) {
    case CollectionAttachmentRule.any:
      break;
    case CollectionAttachmentRule.required:
      segments.add('Has attachments');
    case CollectionAttachmentRule.excluded:
      segments.add('No attachments');
    case CollectionAttachmentRule.imagesOnly:
      segments.add('Images only');
  }
  if (rules.pinnedOnly) {
    segments.add('Pinned only');
  }
  switch (rules.dateRule.type) {
    case CollectionDateRuleType.all:
      break;
    case CollectionDateRuleType.lastDays:
      final days = rules.dateRule.lastDays ?? 0;
      if (days > 0) {
        segments.add('Last $days days');
      }
    case CollectionDateRuleType.customRange:
      segments.add('Custom range');
  }
  if (segments.isEmpty) {
    return 'Smart collection';
  }
  return segments.join(' · ');
}

bool _matchesSmartCollection(
  LocalMemo memo,
  CollectionRuleSet rules, {
  required CanonicalTagPathResolver resolveCanonicalTagPath,
}) {
  if (memo.state.trim().toUpperCase() != 'NORMAL') {
    return false;
  }

  final normalizedVisibility = memo.visibility.trim().toUpperCase();
  switch (rules.visibility) {
    case CollectionVisibilityScope.all:
      break;
    case CollectionVisibilityScope.privateOnly:
      if (normalizedVisibility != 'PRIVATE') return false;
    case CollectionVisibilityScope.publicOnly:
      if (normalizedVisibility != 'PUBLIC') return false;
  }

  if (rules.pinnedOnly && !memo.pinned) {
    return false;
  }

  switch (rules.attachmentRule) {
    case CollectionAttachmentRule.any:
      break;
    case CollectionAttachmentRule.required:
      if (memo.attachments.isEmpty) return false;
    case CollectionAttachmentRule.excluded:
      if (memo.attachments.isNotEmpty) return false;
    case CollectionAttachmentRule.imagesOnly:
      if (!_memoHasImage(memo)) return false;
  }

  if (!_matchesDateRule(memo, rules.dateRule)) {
    return false;
  }

  final normalizedRuleTags = rules.normalizedTagPaths
      .map(resolveCanonicalTagPath)
      .where((path) => path.isNotEmpty)
      .toList(growable: false);
  if (normalizedRuleTags.isEmpty) {
    return true;
  }

  final memoTags = <String>{};
  for (final raw in memo.tags) {
    final normalized = normalizeTagPath(raw);
    if (normalized.isEmpty) continue;
    memoTags.add(resolveCanonicalTagPath(normalized));
  }

  if (memoTags.isEmpty) {
    return false;
  }

  bool matchesTag(String tagPath) {
    for (final memoTag in memoTags) {
      if (memoTag == tagPath) return true;
      if (rules.includeDescendants && memoTag.startsWith('$tagPath/')) {
        return true;
      }
    }
    return false;
  }

  return switch (rules.tagMatchMode) {
    CollectionTagMatchMode.any => normalizedRuleTags.any(matchesTag),
    CollectionTagMatchMode.all => normalizedRuleTags.every(matchesTag),
  };
}

bool _matchesDateRule(LocalMemo memo, CollectionDateRule rule) {
  switch (rule.type) {
    case CollectionDateRuleType.all:
      return true;
    case CollectionDateRuleType.lastDays:
      final days = rule.lastDays ?? 0;
      if (days <= 0) return true;
      final start = DateTime.now().subtract(Duration(days: days));
      return !memo.createTime.isBefore(start);
    case CollectionDateRuleType.customRange:
      final createdSec = memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000;
      final start = rule.startTimeSec;
      if (start != null && createdSec < start) {
        return false;
      }
      final end = rule.endTimeSecExclusive;
      if (end != null && createdSec >= end) {
        return false;
      }
      return true;
  }
}

bool _memoHasImage(LocalMemo memo) {
  for (final attachment in memo.attachments) {
    if (attachment.isImage) {
      return true;
    }
  }
  return false;
}

String? _resolveFallbackAccentColorHex(
  MemoCollection collection, {
  required TagColorHexResolver? resolveTagColorHexByPath,
}) {
  final resolver = resolveTagColorHexByPath;
  if (resolver == null) return null;
  for (final tag in collection.rules.normalizedTagPaths) {
    final resolved = normalizeTagColorHex(resolver(tag));
    if (resolved != null) return resolved;
  }
  return null;
}

String _identityCanonicalPath(String path) => normalizeTagPath(path);
