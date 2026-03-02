import 'package:flutter/material.dart';

import 'reminder_settings_provider.dart';

int minutesFromTimeOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

TimeOfDay timeOfDayFromMinutes(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

bool isInDnd(DateTime time, ReminderSettings settings) {
  if (!settings.dndEnabled) return false;
  final start = settings.dndStartMinutes;
  final end = settings.dndEndMinutes;
  if (start == end) return false;
  final minutes = time.hour * 60 + time.minute;
  if (start < end) {
    return minutes >= start && minutes < end;
  }
  return minutes >= start || minutes < end;
}

DateTime? dndEndFor(DateTime time, ReminderSettings settings) {
  if (!isInDnd(time, settings)) return null;
  final endMinutes = settings.dndEndMinutes;
  final end = DateTime(time.year, time.month, time.day, endMinutes ~/ 60, endMinutes % 60);
  final start = settings.dndStartMinutes;
  if (start < endMinutes) {
    return end;
  }
  final minutes = time.hour * 60 + time.minute;
  if (minutes >= start) {
    return end.add(const Duration(days: 1));
  }
  return end;
}

DateTime? nextEffectiveReminderTime({
  required DateTime now,
  required List<DateTime> times,
  required ReminderSettings settings,
}) {
  DateTime? best;
  for (final time in times) {
    final normalized = DateTime(time.year, time.month, time.day, time.hour, time.minute);
    DateTime? candidate;
    final dndEnd = dndEndFor(normalized, settings);
    if (dndEnd != null && dndEnd.isAfter(now)) {
      candidate = dndEnd;
    } else if (!normalized.isBefore(now)) {
      candidate = normalized;
    }
    if (candidate == null) continue;
    if (best == null || candidate.isBefore(best)) {
      best = candidate;
    }
  }
  return best;
}
