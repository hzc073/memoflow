import 'dart:convert';

enum ReminderMode { single, repeat }

class MemoReminder {
  const MemoReminder({
    required this.memoUid,
    required this.mode,
    required this.times,
    this.id,
    this.createdTime,
    this.updatedTime,
  });

  final int? id;
  final String memoUid;
  final ReminderMode mode;
  final List<DateTime> times;
  final DateTime? createdTime;
  final DateTime? updatedTime;

  factory MemoReminder.fromDb(Map<String, dynamic> row) {
    final id = row['id'] as int?;
    final memoUid = (row['memo_uid'] as String?) ?? '';
    final rawMode = (row['mode'] as String?) ?? 'single';
    final mode = _parseMode(rawMode);
    final rawTimes = (row['times_json'] as String?) ?? '[]';
    final times = parseTimes(rawTimes);
    final createdMs = row['created_time'] as int?;
    final updatedMs = row['updated_time'] as int?;

    return MemoReminder(
      id: id,
      memoUid: memoUid,
      mode: mode,
      times: times,
      createdTime: createdMs == null ? null : DateTime.fromMillisecondsSinceEpoch(createdMs, isUtc: true).toLocal(),
      updatedTime: updatedMs == null ? null : DateTime.fromMillisecondsSinceEpoch(updatedMs, isUtc: true).toLocal(),
    );
  }

  MemoReminder copyWith({
    int? id,
    String? memoUid,
    ReminderMode? mode,
    List<DateTime>? times,
    DateTime? createdTime,
    DateTime? updatedTime,
  }) {
    return MemoReminder(
      id: id ?? this.id,
      memoUid: memoUid ?? this.memoUid,
      mode: mode ?? this.mode,
      times: times ?? this.times,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
    );
  }

  List<DateTime> sortedTimes() {
    final list = [...times];
    list.sort();
    return list;
  }

  DateTime? nextTimeAfter(DateTime now) {
    final list = sortedTimes();
    for (final time in list) {
      if (!time.isBefore(now)) {
        return time;
      }
    }
    return null;
  }

  static ReminderMode _parseMode(String raw) {
    return ReminderMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ReminderMode.single,
    );
  }

  static List<DateTime> parseTimes(String raw) {
    final list = <DateTime>[];
    if (raw.trim().isEmpty) return list;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! String) continue;
          final parsed = DateTime.tryParse(item);
          if (parsed == null) continue;
          list.add(parsed.toLocal());
        }
      }
    } catch (_) {}
    list.sort();
    return list;
  }

  static String encodeTimes(List<DateTime> times) {
    final sorted = [...times]..sort();
    final values = sorted.map((t) => t.toLocal().toIso8601String()).toList(growable: false);
    return jsonEncode(values);
  }
}
