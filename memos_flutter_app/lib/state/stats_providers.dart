import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

class LocalStats {
  const LocalStats({
    required this.totalMemos,
    required this.archivedMemos,
    required this.activeDays,
    required this.daysSinceFirstMemo,
    required this.totalChars,
    required this.dailyCounts,
  });

  final int totalMemos;
  final int archivedMemos;
  final int activeDays;
  final int daysSinceFirstMemo;
  final int totalChars;

  /// Map keyed by local-midnight DateTime.
  final Map<DateTime, int> dailyCounts;
}

typedef MonthKey = ({int year, int month});

class MonthlyStats {
  const MonthlyStats({
    required this.year,
    required this.month,
    required this.totalMemos,
    required this.totalChars,
    required this.maxMemosPerDay,
    required this.maxCharsPerDay,
    required this.activeDays,
    required this.dailyCounts,
  });

  final int year;
  final int month;
  final int totalMemos;
  final int totalChars;
  final int maxMemosPerDay;
  final int maxCharsPerDay;
  final int activeDays;

  /// Map keyed by local-midnight DateTime.
  final Map<DateTime, int> dailyCounts;
}

class MonthlyChars {
  const MonthlyChars({required this.month, required this.totalChars});

  final DateTime month;
  final int totalChars;
}

class TagDistribution {
  const TagDistribution({
    required this.tag,
    required this.count,
    required this.isUntagged,
    this.colorHex,
    this.latestMemoAt,
  });

  final String tag;
  final int count;
  final bool isUntagged;

  /// Reserved for future user-defined tag colors, e.g. "#FF6B6B".
  final String? colorHex;
  final DateTime? latestMemoAt;
}

class AnnualInsights {
  const AnnualInsights({
    required this.monthlyChars,
    required this.tagDistribution,
  });

  final List<MonthlyChars> monthlyChars;
  final List<TagDistribution> tagDistribution;
}

class WritingHourSummary {
  const WritingHourSummary({required this.peakHour, required this.peakCount});

  /// Local-time hour in [0, 23]. Null means no memo data.
  final int? peakHour;
  final int peakCount;
}

final writingHourSummaryProvider = StreamProvider<WritingHourSummary>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);

  Future<WritingHourSummary> load() async {
    final sqlite = await db.db;

    int readInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    final rows = await sqlite.rawQuery('''
      SELECT
        CAST(strftime('%H', create_time, 'unixepoch', 'localtime') AS INTEGER) AS hour,
        COUNT(*) AS memo_count
      FROM memos
      WHERE state = 'NORMAL'
      GROUP BY hour
    ''');

    var bestHour = -1;
    var bestCount = 0;
    for (final row in rows) {
      final hour = readInt(row['hour']);
      final count = readInt(row['memo_count']);
      if (hour < 0 || hour > 23 || count <= 0) continue;
      if (count > bestCount || (count == bestCount && hour < bestHour)) {
        bestHour = hour;
        bestCount = count;
      }
    }

    if (bestCount <= 0 || bestHour < 0) {
      return const WritingHourSummary(peakHour: null, peakCount: 0);
    }
    return WritingHourSummary(peakHour: bestHour, peakCount: bestCount);
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final monthlyStatsProvider = StreamProvider.family<MonthlyStats, MonthKey>((
  ref,
  monthKey,
) async* {
  final db = ref.watch(databaseProvider);

  Future<MonthlyStats> load() async {
    final sqlite = await db.db;

    // Use local month boundaries (users expect month stats in their timezone).
    final startLocal = DateTime(monthKey.year, monthKey.month, 1);
    final endLocal = monthKey.month == 12
        ? DateTime(monthKey.year + 1, 1, 1)
        : DateTime(monthKey.year, monthKey.month + 1, 1);
    final startSec = startLocal.toUtc().millisecondsSinceEpoch ~/ 1000;
    final endSec = endLocal.toUtc().millisecondsSinceEpoch ~/ 1000;

    final rows = await sqlite.query(
      'memos',
      columns: const ['create_time', 'content'],
      where: "state = 'NORMAL' AND create_time >= ? AND create_time < ?",
      whereArgs: [startSec, endSec],
    );

    final dailyCounts = <DateTime, int>{};
    final dailyChars = <DateTime, int>{};
    var totalChars = 0;

    for (final row in rows) {
      final sec = row['create_time'] as int?;
      if (sec == null) continue;
      final content = (row['content'] as String?) ?? '';
      final dtLocal = DateTime.fromMillisecondsSinceEpoch(
        sec * 1000,
        isUtc: true,
      ).toLocal();
      final day = DateTime(dtLocal.year, dtLocal.month, dtLocal.day);

      final c = _countChars(content);
      totalChars += c;

      dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
      dailyChars[day] = (dailyChars[day] ?? 0) + c;
    }

    var maxMemosPerDay = 0;
    for (final v in dailyCounts.values) {
      if (v > maxMemosPerDay) maxMemosPerDay = v;
    }

    var maxCharsPerDay = 0;
    for (final v in dailyChars.values) {
      if (v > maxCharsPerDay) maxCharsPerDay = v;
    }

    return MonthlyStats(
      year: monthKey.year,
      month: monthKey.month,
      totalMemos: rows.length,
      totalChars: totalChars,
      maxMemosPerDay: maxMemosPerDay,
      maxCharsPerDay: maxCharsPerDay,
      activeDays: dailyCounts.length,
      dailyCounts: dailyCounts,
    );
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final annualInsightsProvider = StreamProvider.family<AnnualInsights, MonthKey>((
  ref,
  monthKey,
) async* {
  final db = ref.watch(databaseProvider);

  Future<AnnualInsights> load() async {
    final sqlite = await db.db;
    final endMonth = DateTime(monthKey.year, monthKey.month, 1);
    final startMonth = DateTime(endMonth.year, endMonth.month - 11, 1);
    final endExclusive = DateTime(endMonth.year, endMonth.month + 1, 1);
    final startSec = startMonth.toUtc().millisecondsSinceEpoch ~/ 1000;
    final endSec = endExclusive.toUtc().millisecondsSinceEpoch ~/ 1000;

    final rows = await sqlite.query(
      'memos',
      columns: const ['create_time', 'content', 'tags'],
      where: "state = 'NORMAL' AND create_time >= ? AND create_time < ?",
      whereArgs: [startSec, endSec],
    );

    final monthTotals = <DateTime, int>{
      for (var i = 0; i < 12; i++)
        DateTime(startMonth.year, startMonth.month + i, 1): 0,
    };
    final tagCounts = <String, int>{};
    final tagLatest = <String, DateTime>{};
    var untaggedCount = 0;
    DateTime? untaggedLatest;

    for (final row in rows) {
      final sec = row['create_time'] as int?;
      if (sec == null) continue;

      final content = (row['content'] as String?) ?? '';
      final tagsText = (row['tags'] as String?) ?? '';
      final dtLocal = DateTime.fromMillisecondsSinceEpoch(
        sec * 1000,
        isUtc: true,
      ).toLocal();
      final month = DateTime(dtLocal.year, dtLocal.month, 1);
      if (monthTotals.containsKey(month)) {
        monthTotals[month] = (monthTotals[month] ?? 0) + _countChars(content);
      }

      final tags = _splitTagsText(tagsText);
      if (tags.isEmpty) {
        untaggedCount += 1;
        if (untaggedLatest == null || dtLocal.isAfter(untaggedLatest)) {
          untaggedLatest = dtLocal;
        }
        continue;
      }
      for (final tag in tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        final latest = tagLatest[tag];
        if (latest == null || dtLocal.isAfter(latest)) {
          tagLatest[tag] = dtLocal;
        }
      }
    }

    final monthlyChars =
        monthTotals.entries
            .map(
              (entry) =>
                  MonthlyChars(month: entry.key, totalChars: entry.value),
            )
            .toList(growable: false)
          ..sort((a, b) => a.month.compareTo(b.month));

    final tagDistribution =
        <TagDistribution>[
          if (untaggedCount > 0)
            TagDistribution(
              tag: '',
              count: untaggedCount,
              isUntagged: true,
              colorHex: null,
              latestMemoAt: untaggedLatest,
            ),
          ...tagCounts.entries.map(
            (entry) => TagDistribution(
              tag: entry.key,
              count: entry.value,
              isUntagged: false,
              colorHex: null,
              latestMemoAt: tagLatest[entry.key],
            ),
          ),
        ]..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          return a.tag.compareTo(b.tag);
        });

    return AnnualInsights(
      monthlyChars: monthlyChars,
      tagDistribution: tagDistribution,
    );
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

final localStatsProvider = StreamProvider<LocalStats>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<LocalStats> load() async {
    final sqlite = await db.db;

    int readInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    DateTime? parseDayKey(String raw) {
      final parts = raw.split('-');
      if (parts.length != 3) return null;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return null;
      return DateTime(y, m, d);
    }

    var statsRows = await sqlite.query(
      'stats_cache',
      columns: const [
        'total_memos',
        'archived_memos',
        'total_chars',
        'min_create_time',
      ],
      where: 'id = 1',
      limit: 1,
    );
    if (statsRows.isEmpty) {
      await db.rebuildStatsCache();
      statsRows = await sqlite.query(
        'stats_cache',
        columns: const [
          'total_memos',
          'archived_memos',
          'total_chars',
          'min_create_time',
        ],
        where: 'id = 1',
        limit: 1,
      );
    }
    final statsRow = statsRows.firstOrNull;
    final totalMemos = readInt(statsRow?['total_memos']);
    final archivedMemos = readInt(statsRow?['archived_memos']);
    final totalChars = readInt(statsRow?['total_chars']);
    final minTimeSec = readInt(statsRow?['min_create_time']);
    var daysSinceFirstMemo = 0;
    if (minTimeSec > 0) {
      final first = DateTime.fromMillisecondsSinceEpoch(
        minTimeSec * 1000,
        isUtc: true,
      ).toLocal();
      final firstDay = DateTime(first.year, first.month, first.day);
      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);
      daysSinceFirstMemo = todayDay.difference(firstDay).inDays + 1;
    }

    final dailyCounts = <DateTime, int>{};
    final dailyRows = await sqlite.query(
      'daily_counts_cache',
      columns: const ['day', 'memo_count'],
    );
    for (final row in dailyRows) {
      final dayRaw = row['day'];
      if (dayRaw is! String || dayRaw.trim().isEmpty) continue;
      final day = parseDayKey(dayRaw.trim());
      if (day == null) continue;
      final count = readInt(row['memo_count']);
      if (count <= 0) continue;
      dailyCounts[day] = count;
    }

    return LocalStats(
      totalMemos: totalMemos,
      archivedMemos: archivedMemos,
      activeDays: dailyCounts.length,
      daysSinceFirstMemo: daysSinceFirstMemo,
      totalChars: totalChars,
      dailyCounts: dailyCounts,
    );
  }

  yield await load();
  await for (final _ in db.changes) {
    yield await load();
  }
});

int _countChars(String content) {
  return content.replaceAll(RegExp(r'\s+'), '').runes.length;
}

List<String> _splitTagsText(String tagsText) {
  if (tagsText.trim().isEmpty) return const [];
  return tagsText
      .split(' ')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
