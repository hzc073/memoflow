import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_reminder.dart';
import '../../platform/platform_icons.dart';
import '../../platform/platform_route.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_page.dart';
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
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted) return null;
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (!mounted) return null;
    if (time == null) return null;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return PlatformPage(
      backgroundColor: bg,
      title: Text(context.t.strings.legacy.msg_reminder_2),
      leading: IconButton(
        tooltip: context.t.strings.legacy.msg_back,
        icon: Icon(PlatformIcons.back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _save,
          child: Text(context.t.strings.legacy.msg_save_2),
        ),
      ],
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (!settings.enabled)
                  _DisabledBanner(
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    onOpenSettings: () => Navigator.of(context).push(
                      buildPlatformPageRoute<void>(
                        context: context,
                        builder: (_) => const ReminderSettingsScreen(),
                      ),
                    ),
                  ),
                if (!settings.enabled) const SizedBox(height: 12),
                _Group(
                  card: card,
                  divider: divider,
                  children: [
                    _ModeRow(
                      label: context.t.strings.legacy.msg_mode,
                      textMain: textMain,
                      textMuted: textMuted,
                      mode: _mode,
                      onModeChanged: _setMode,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Group(
                  card: card,
                  divider: divider,
                  children: [
                    _TimesHeader(
                      label: context.t.strings.legacy.msg_times,
                      textMain: textMain,
                      textMuted: textMuted,
                      onAdd: () => _addOrEditTime(),
                      canAdd: _mode == ReminderMode.single
                          ? true
                          : _times.length < 9,
                      addLabel: _mode == ReminderMode.single
                          ? context.t.strings.legacy.msg_set_time
                          : context.t.strings.legacy.msg_add_2,
                    ),
                    if (_times.isEmpty)
                      _EmptyRow(
                        textMuted: textMuted,
                        text: context.t.strings.legacy.msg_no_times_set,
                      )
                    else
                      for (final time in _times)
                        _TimeRow(
                          timeLabel: _dateFmt.format(time),
                          textMain: textMain,
                          textMuted: textMuted,
                          onTap: () => _addOrEditTime(current: time),
                          onRemove: () => setState(() => _times.remove(time)),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_hasExisting)
                  TextButton.icon(
                    onPressed: _deleteReminder,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.t.strings.legacy.msg_delete_reminder),
                    style: TextButton.styleFrom(
                      foregroundColor: MemoFlowPalette.primary,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DisabledBanner extends StatelessWidget {
  const _DisabledBanner({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.onOpenSettings,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, color: textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t.strings.legacy.msg_reminders_disabled,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: Text(context.t.strings.legacy.msg_enable),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.mode,
    required this.onModeChanged,
  });

  final String label;
  final Color textMain;
  final Color textMuted;
  final ReminderMode mode;
  final ValueChanged<ReminderMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          SettingsOptionChipGroup<ReminderMode>(
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
        ],
      ),
    );
  }
}

class _TimesHeader extends StatelessWidget {
  const _TimesHeader({
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.onAdd,
    required this.canAdd,
    required this.addLabel,
  });

  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onAdd;
  final bool canAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          TextButton.icon(
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.timeLabel,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
    required this.onRemove,
  });

  final String timeLabel;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close, size: 18, color: textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.textMuted, required this.text});

  final Color textMuted;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(text, style: TextStyle(fontSize: 12, color: textMuted)),
    );
  }
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
