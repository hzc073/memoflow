import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/top_toast.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_reminder.dart';
import '../../platform/platform_route.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_list_section.dart';
import '../../state/system/database_provider.dart';
import '../../state/system/reminder_mutation_service.dart';
import '../../state/system/reminder_scheduler.dart';
import '../../state/settings/reminder_settings_provider.dart';
import '../settings/settings_ui.dart';
import 'reminder_settings_screen.dart';
import '../../i18n/strings.g.dart';

class MemoReminderEditorScreen extends ConsumerStatefulWidget {
  const MemoReminderEditorScreen({super.key, required this.memo});

  final LocalMemo memo;

  @override
  ConsumerState<MemoReminderEditorScreen> createState() =>
      _MemoReminderEditorScreenState();
}

class _MemoReminderEditorScreenState
    extends ConsumerState<MemoReminderEditorScreen> {
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  bool _loading = true;
  ReminderMode _mode = ReminderMode.single;
  List<DateTime> _times = [];
  bool _hasExisting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReminder());
  }

  Future<void> _loadReminder() async {
    final db = ref.read(databaseProvider);
    final row = await db.getMemoReminderByUid(widget.memo.uid);
    if (!mounted) return;
    if (row != null) {
      final reminder = MemoReminder.fromDb(row);
      _mode = reminder.mode;
      _times = reminder.times.toList();
      _hasExisting = _times.isNotEmpty;
    }
    setState(() => _loading = false);
  }

  void _setMode(ReminderMode mode) {
    setState(() {
      _mode = mode;
      if (_mode == ReminderMode.single && _times.length > 1) {
        _times.sort();
        _times = [_times.first];
      }
    });
  }

  Future<void> _addOrEditTime({DateTime? current}) async {
    if (current == null && _mode == ReminderMode.repeat && _times.length >= 9) {
      if (mounted) {
        showTopToast(context, context.t.strings.legacy.msg_v_9_times_allowed);
      }
      return;
    }
    final picked = await _pickDateTime(current ?? _times.firstOrNull);
    if (picked == null) return;
    setState(() {
      if (_mode == ReminderMode.single) {
        _times = [picked];
      } else {
        final next = [..._times];
        if (current != null) {
          next.removeWhere((t) => t.isAtSameMomentAs(current));
        }
        if (next.any((t) => t.isAtSameMomentAs(picked))) return;
        next.add(picked);
        _times = next;
        _times.sort();
      }
    });
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final initialDate = initial ?? now;
    final picked = await showSettingsDateTimePicker(
      context: context,
      initialDateTime: initialDate.isBefore(now) ? now : initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted) return null;
    if (picked == null) return null;
    if (picked.isBefore(now)) {
      if (mounted) {
        showTopToast(context, context.t.strings.legacy.msg_pick_future_time);
      }
      return null;
    }
    return picked;
  }

  Future<void> _save() async {
    if (_times.isEmpty) {
      showTopToast(context, context.t.strings.legacy.msg_select_reminder_time);
      return;
    }
    if (_mode == ReminderMode.repeat && _times.length > 9) {
      showTopToast(context, context.t.strings.legacy.msg_v_9_times_allowed);
      return;
    }

    await ref
        .read(reminderMutationServiceProvider)
        .saveReminder(memoUid: widget.memo.uid, mode: _mode, times: _times);
    await ref.read(reminderSchedulerProvider).rescheduleAll();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteReminder() async {
    final confirmed =
        await showPlatformAlertDialog<bool>(
          context: context,
          title: context.t.strings.legacy.msg_delete_reminder,
          message: context.t.strings.legacy.msg_remove_all_reminder_times_memo,
          actions: [
            PlatformDialogAction<bool>(
              value: false,
              label: context.t.strings.legacy.msg_cancel_2,
            ),
            PlatformDialogAction<bool>(
              value: true,
              label: context.t.strings.legacy.msg_delete,
              isDestructive: true,
            ),
          ],
        ) ??
        false;
    if (!confirmed) return;
    await ref
        .read(reminderMutationServiceProvider)
        .deleteReminder(widget.memo.uid);
    await ref.read(reminderSchedulerProvider).rescheduleAll();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_reminder_2),
      actions: [
        TextButton(
          onPressed: _loading ? null : _save,
          child: Text(context.t.strings.legacy.msg_save_2),
        ),
      ],
      children: _loading
          ? [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ]
          : [
              if (!settings.enabled)
                _DisabledBanner(
                  onOpenSettings: () => Navigator.of(context).push(
                    buildPlatformPageRoute<void>(
                      context: context,
                      builder: (_) => const ReminderSettingsScreen(),
                    ),
                  ),
                ),
              if (!settings.enabled) const SizedBox(height: 12),
              _Group(
                children: [
                  _ModeRow(
                    label: context.t.strings.legacy.msg_mode,
                    mode: _mode,
                    onModeChanged: _setMode,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Group(
                children: [
                  _TimesHeader(
                    label: context.t.strings.legacy.msg_times,
                    onAdd: () => _addOrEditTime(),
                    canAdd: _mode == ReminderMode.single
                        ? true
                        : _times.length < 9,
                    addLabel: _mode == ReminderMode.single
                        ? context.t.strings.legacy.msg_set_time
                        : context.t.strings.legacy.msg_add_2,
                  ),
                  if (_times.isEmpty)
                    _EmptyRow(text: context.t.strings.legacy.msg_no_times_set)
                  else
                    for (final time in _times)
                      _TimeRow(
                        timeLabel: _dateFmt.format(time),
                        onTap: () => _addOrEditTime(current: time),
                        onRemove: () => setState(() => _times.remove(time)),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              if (_hasExisting)
                SettingsActionPill(
                  icon: Icons.delete_outline,
                  label: context.t.strings.legacy.msg_delete_reminder,
                  onPressed: _deleteReminder,
                ),
            ],
    );
  }
}

class _DisabledBanner extends StatelessWidget {
  const _DisabledBanner({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return SettingsSection(
      children: [
        PlatformListSectionRow(
          leading: Icon(
            Icons.notifications_off_outlined,
            color: tokens.textMuted,
          ),
          title: SettingsRowTitle(
            context.t.strings.legacy.msg_reminders_disabled,
          ),
          trailing: SettingsActionPill(
            label: context.t.strings.legacy.msg_enable,
            onPressed: onOpenSettings,
          ),
          denseOnDesktop: false,
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(children: children);
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.label,
    required this.mode,
    required this.onModeChanged,
  });

  final String label;
  final ReminderMode mode;
  final ValueChanged<ReminderMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return PlatformListSectionRow(
      title: SettingsRowTitle(label),
      trailing: SettingsOptionChipGroup<ReminderMode>(
        value: mode,
        options: [
          SettingsChoiceOption<ReminderMode>(
            value: ReminderMode.single,
            label: context.t.strings.legacy.msg_single,
          ),
          SettingsChoiceOption<ReminderMode>(
            value: ReminderMode.repeat,
            label: context.t.strings.legacy.msg_repeat,
          ),
        ],
        onChanged: onModeChanged,
      ),
    );
  }
}

class _TimesHeader extends StatelessWidget {
  const _TimesHeader({
    required this.label,
    required this.onAdd,
    required this.canAdd,
    required this.addLabel,
  });

  final String label;
  final VoidCallback onAdd;
  final bool canAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return PlatformListSectionRow(
      title: SettingsRowTitle(label),
      trailing: SettingsActionPill(
        icon: Icons.add,
        label: addLabel,
        enabled: canAdd,
        onPressed: canAdd ? onAdd : null,
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.timeLabel,
    required this.onTap,
    required this.onRemove,
  });

  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    return PlatformListSectionRow(
      title: SettingsRowTitle(timeLabel),
      trailing: IconButton(
        onPressed: onRemove,
        icon: Icon(Icons.close, size: 18, color: tokens.textMuted),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      ),
      onTap: onTap,
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return PlatformListSectionRow(title: SettingsRowDescription(text));
  }
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
