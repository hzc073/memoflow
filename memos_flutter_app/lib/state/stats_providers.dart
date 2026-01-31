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

final monthlyStatsProvider = StreamProvider.family<MonthlyStats, MonthKey>((ref, monthKey) async* {
  final db = ref.watch(databaseProvider);

  Future<MonthlyStats> load() async {
    final sqlite = await db.db;

    // Use local month boundaries (users expect month stats in their timezone).
    final startLocal = DateTime(monthKey.year, monthKey.month, 1);
    final endLocal = monthKey.month == 12 ? DateTime(monthKey.year + 1, 1, 1) : DateTime(monthKey.year, monthKey.month + 1, 1);
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
      final dtLocal = DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true).toLocal();
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

final localStatsProvider = StreamProvider<LocalStats>((ref) async* {
  final db = ref.watch(databaseProvider);

  Future<LocalStats> load() async {
    final sqlite = await db.db;

    final totalRows = await sqlite.rawQuery("SELECT COUNT(*) as c FROM memos WHERE state = 'NORMAL';");
    final archivedRows = await sqlite.rawQuery("SELECT COUNT(*) as c FROM memos WHERE state = 'ARCHIVED';");
    final totalMemos = (totalRows.firstOrNull?['c'] as int?) ?? 0;
    final archivedMemos = (archivedRows.firstOrNull?['c'] as int?) ?? 0;

    final minRows = await sqlite.rawQuery('SELECT MIN(create_time) AS min_time FROM memos;');
    final minTimeSec = minRows.firstOrNull?['min_time'] as int?;
    var daysSinceFirstMemo = 0;
    if (minTimeSec != null && minTimeSec > 0) {
      final first = DateTime.fromMillisecondsSinceEpoch(minTimeSec * 1000, isUtc: true).toLocal();
      final firstDay = DateTime(first.year, first.month, first.day);
      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);
      daysSinceFirstMemo = todayDay.difference(firstDay).inDays + 1;
    }

    final dailyRows = await sqlite.query(
      'memos',
      columns: const ['create_time'],
      where: "state = 'NORMAL'",
    );
    final dailyCounts = <DateTime, int>{};
    final activeDays = <DateTime>{};
    for (final row in dailyRows) {
      final sec = row['create_time'] as int?;
      if (sec == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true).toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      activeDays.add(day);
      dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
    }

    final contentRows = await sqlite.query(
      'memos',
      columns: const ['content'],
      where: "state = 'NORMAL'",
    );
    var totalChars = 0;
    for (final row in contentRows) {
      final c = row['content'] as String?;
      if (c == null || c.isEmpty) continue;
      totalChars += c.replaceAll(RegExp(r'\s+'), '').runes.length;
    }

    return LocalStats(
      totalMemos: totalMemos,
      archivedMemos: archivedMemos,
      activeDays: activeDays.length,
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

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
