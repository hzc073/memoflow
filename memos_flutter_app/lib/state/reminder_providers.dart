import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/memo_reminder.dart';
import 'database_provider.dart';

final memoRemindersProvider = StreamProvider<List<MemoReminder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchMemoReminders().map(
        (rows) => rows.map(MemoReminder.fromDb).toList(growable: false),
      );
});

final memoReminderMapProvider = Provider<Map<String, MemoReminder>>((ref) {
  final asyncReminders = ref.watch(memoRemindersProvider);
  return asyncReminders.maybeWhen(
    data: (reminders) => {
      for (final reminder in reminders) reminder.memoUid: reminder,
    },
    orElse: () => <String, MemoReminder>{},
  );
});

final memoReminderByUidProvider = Provider.family<MemoReminder?, String>((ref, memoUid) {
  final map = ref.watch(memoReminderMapProvider);
  return map[memoUid];
});
