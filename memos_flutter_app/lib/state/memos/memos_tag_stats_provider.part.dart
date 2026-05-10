part of 'memos_providers.dart';

class TagStat {
  const TagStat({
    required this.tag,
    required this.count,
    this.tagId,
    this.parentId,
    this.pinned = false,
    this.colorHex,
    this.lastUsedTimeSec,
    String? path,
  }) : path = path ?? tag;

  final String tag;
  final int count;
  final int? tagId;
  final int? parentId;
  final bool pinned;
  final String? colorHex;
  final int? lastUsedTimeSec;
  final String path;
}

final tagStatsProvider = StreamProvider<List<TagStat>>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<List<TagStat>> load() async {
    int readInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    final list = <TagStat>[];
    final rows = await db.listTagStatsRows();
    for (final row in rows) {
      final path = row['path'];
      if (path is String && path.trim().isNotEmpty) {
        final count = readInt(row['memo_count']);
        final lastUsedTimeSec = readInt(row['last_used_time']);
        final tagId = readInt(row['id']);
        final parentId = readInt(row['parent_id']);
        final pinned = readInt(row['pinned']) == 1;
        final colorHex = row['color_hex'] as String?;
        final trimmedPath = path.trim();
        list.add(
          TagStat(
            tag: trimmedPath,
            path: trimmedPath,
            count: count,
            tagId: tagId == 0 ? null : tagId,
            parentId: parentId == 0 ? null : parentId,
            pinned: pinned,
            colorHex: colorHex,
            lastUsedTimeSec: lastUsedTimeSec == 0 ? null : lastUsedTimeSec,
          ),
        );
        continue;
      }

      final tag = row['tag'];
      if (tag is! String || tag.trim().isEmpty) continue;
      final trimmed = tag.trim();
      final count = readInt(row['memo_count']);
      list.add(TagStat(tag: trimmed, count: count, path: trimmed));
    }

    list.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.tag.compareTo(b.tag);
    });
    return list;
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});
