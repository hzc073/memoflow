import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../state/reminder_scheduler.dart';
import '../../state/reminder_settings_provider.dart';
import 'custom_notification_screen.dart';
import 'ringtone_picker.dart';
import 'reminder_utils.dart';
import 'system_settings_launcher.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  var _saving = false;
  var _testing = false;
  int? _androidSdkInt;

  Future<void> _toggleEnabled(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(reminderSettingsProvider.notifier);
      if (!value) {
        notifier.setEnabled(false);
        await ref.read(reminderSchedulerProvider).cancelAll();
        return;
      }
      final granted = await _requestPermissions();
      if (!granted) return;
      notifier.setEnabled(true);
      await ref.read(reminderSchedulerProvider).rescheduleAll();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _sendTestNotification() async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      final result = await ref.read(reminderSchedulerProvider).scheduleTestReminder(
            delay: const Duration(minutes: 1),
          );
      if (!mounted) return;
      final scheduledAt = result.scheduledAt;
      final timeLabel = scheduledAt == null
          ? '--:--'
          : _formatTime(TimeOfDay.fromDateTime(scheduledAt));
      final suffix = result.ok && !result.exactUsed
          ? context.tr(zh: '（可能延迟）', en: ' (may be delayed)')
          : '';
      final pendingLabel = result.ok
          ? context.tr(zh: '（待发送 ${result.pendingCount}）', en: ' (pending ${result.pendingCount})')
          : '';
      final message = result.ok
          ? context.tr(
              zh: '已安排测试提醒：$timeLabel$suffix$pendingLabel',
              en: 'Test scheduled at $timeLabel$suffix$pendingLabel',
            )
          : context.tr(zh: '权限未授予', en: 'Permissions denied');
      if (result.ok) {
        showTopToast(context, message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '发送失败：$e', en: 'Send failed: $e'))),
      );
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  
  Future<void> _openSystemSetting(SystemSettingsTarget target, {String? channelId}) async {
    final ok = await SystemSettingsLauncher.open(target, channelId: channelId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '无法打开系统设置', en: 'Failed to open system settings'))),
      );
    }
  }

  Future<void> _requestBatteryWhitelist() async {
    final ignoring = await SystemSettingsLauncher.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    if (ignoring) {
      showTopToast(
        context,
        context.tr(zh: '已在电池白名单', en: 'Already whitelisted'),
      );
      return;
    }
    final ok = await SystemSettingsLauncher.requestIgnoreBatteryOptimizations();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '无法申请电池白名单', en: 'Failed to request whitelist'))),
      );
    }
  }

  Future<bool> _requestPermissions() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr(zh: '开启提醒权限', en: 'Enable reminder permissions')),
            content: Text(
              context.tr(
                zh: '需要通知权限与精确闹钟权限，才能在指定时间发送提醒。',
                en: 'Notification and exact alarm permissions are required to send reminders on time.',
              ),
            ),
            actions: [
              TextButton(onPressed: () => context.safePop(false), child: Text(context.tr(zh: '取消', en: 'Cancel'))),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.tr(zh: '去授权', en: 'Grant')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return false;

    final sdkInt = await _getAndroidSdkInt();
    var notificationStatus = PermissionStatus.granted;
    if (Platform.isAndroid && sdkInt >= 33) {
      notificationStatus = await Permission.notification.request();
    }

    var exactAlarmGranted = true;
    if (Platform.isAndroid && sdkInt >= 31) {
      exactAlarmGranted = await SystemSettingsLauncher.canScheduleExactAlarms();
      if (!exactAlarmGranted && mounted) {
        final go = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.tr(zh: '需要闹钟与提醒权限', en: 'Exact alarm permission required')),
                content: Text(
                  context.tr(
                    zh: '未开启闹钟与提醒权限，定时提醒可能无法触发。是否前往开启？',
                    en: 'Exact alarm permission is off. Reminders may not fire on time. Open settings now?',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => context.safePop(false),
                    child: Text(context.tr(zh: '取消', en: 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => context.safePop(true),
                    child: Text(context.tr(zh: '去开启', en: 'Open')),
                  ),
                ],
              ),
            ) ??
            false;
        if (go) {
          await SystemSettingsLauncher.requestExactAlarmsPermission();
          exactAlarmGranted = await SystemSettingsLauncher.canScheduleExactAlarms();
        }
      }
    }

    final granted = notificationStatus.isGranted && exactAlarmGranted;
    if (!mounted) return granted;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '权限未授予，提醒未开启', en: 'Permissions denied. Reminders disabled.'))),
      );
    }
    return granted;
  }


  Future<int> _getAndroidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    final cached = _androidSdkInt;
    if (cached != null) return cached;
    final info = await DeviceInfoPlugin().androidInfo;
    _androidSdkInt = info.version.sdkInt;
    return info.version.sdkInt;
  }

  Future<void> _openNotificationTemplate(ReminderSettings settings) async {
    final result = await Navigator.of(context).push<(String, String)>(
      MaterialPageRoute<(String, String)>(
        builder: (_) => CustomNotificationScreen(
          initialTitle: settings.notificationTitle,
          initialBody: settings.notificationBody,
        ),
      ),
    );
    if (result == null) return;
    final (title, body) = result;
    final notifier = ref.read(reminderSettingsProvider.notifier);
    notifier.setNotificationTitle(title);
    notifier.setNotificationBody(body);
    await ref.read(reminderSchedulerProvider).rescheduleAll();
  }

  Future<void> _pickRingtone(ReminderSettings settings) async {
    final info = await RingtonePicker.pick(currentUri: settings.soundUri);
    if (info == null) return;
    final notifier = ref.read(reminderSettingsProvider.notifier);
    if (info.isSilent) {
      notifier.setSound(mode: ReminderSoundMode.silent, uri: null, title: null);
    } else if (info.isDefault || (info.uri == null || info.uri!.trim().isEmpty)) {
      notifier.setSound(mode: ReminderSoundMode.system, uri: null, title: info.title);
    } else {
      notifier.setSound(mode: ReminderSoundMode.custom, uri: info.uri, title: info.title);
    }
    await ref.read(reminderSchedulerProvider).rescheduleAll();
  }

  Future<void> _pickDndTime({
    required bool isStart,
    required ReminderSettings settings,
  }) async {
    final initial = isStart ? settings.dndStartTime : settings.dndEndTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final minutes = minutesFromTimeOfDay(picked);
    final notifier = ref.read(reminderSettingsProvider.notifier);
    if (isStart) {
      notifier.setDndStartMinutes(minutes);
    } else {
      notifier.setDndEndMinutes(minutes);
    }
    await ref.read(reminderSchedulerProvider).rescheduleAll();
  }

  String _soundLabel(ReminderSettings settings) {
    if (settings.soundMode == ReminderSoundMode.silent) {
      return context.tr(zh: '静音', en: 'Silent');
    }
    final title = settings.soundTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return context.tr(zh: '系统默认', en: 'System default');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '提醒设置', en: 'Reminder Settings')),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _ToggleCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                label: context.tr(zh: '开启提醒', en: 'Enable reminders'),
                description: context.tr(
                  zh: '开启后将按计划发送笔记提醒通知。',
                  en: 'Enable scheduled reminder notifications.',
                ),
                value: settings.enabled,
                onChanged: _toggleEnabled,
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: context.tr(zh: '权限与系统设置', en: 'Permissions & system settings'), textMuted: textMuted),
              const SizedBox(height: 8),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _ActionRow(
                    label: context.tr(zh: '通知设置', en: 'Notification settings'),
                    actionLabel: context.tr(zh: '打开', en: 'Open'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onPressed: () => _openSystemSetting(SystemSettingsTarget.notifications),
                  ),
                  _ActionRow(
                    label: context.tr(zh: '提醒通知渠道', en: 'Reminder channel'),
                    actionLabel: context.tr(zh: '打开', en: 'Open'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onPressed: () {
                      final channelId =
                          ref.read(reminderSchedulerProvider).channelIdFor(settings);
                      _openSystemSetting(
                        SystemSettingsTarget.notificationChannel,
                        channelId: channelId,
                      );
                    },
                  ),
                  _ActionRow(
                    label: context.tr(zh: '闹钟与提醒', en: 'Exact alarms'),
                    actionLabel: context.tr(zh: '打开', en: 'Open'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onPressed: () => _openSystemSetting(SystemSettingsTarget.exactAlarm),
                  ),
                  _ActionRow(
                    label: context.tr(zh: '电池优化', en: 'Battery optimization'),
                    actionLabel: context.tr(zh: '打开', en: 'Open'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onPressed: () => _openSystemSetting(SystemSettingsTarget.batteryOptimization),
                  ),
                  _ActionRow(
                    label: context.tr(zh: '电池白名单', en: 'Battery whitelist'),
                    actionLabel: context.tr(zh: '申请', en: 'Request'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onPressed: _requestBatteryWhitelist,
                  ),
                  _ActionRow(
                    label: context.tr(zh: '应用设置', en: 'App settings'),
                    actionLabel: context.tr(zh: '打开', en: 'Open'),
                    textMain: textMain,
                    textMuted: textMuted,
                    onPressed: () => _openSystemSetting(SystemSettingsTarget.app),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: context.tr(zh: '通知内容', en: 'Notification content'), textMuted: textMuted),
              const SizedBox(height: 8),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    label: context.tr(zh: '通知标题', en: 'Title'),
                    value: settings.notificationTitle,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _openNotificationTemplate(settings),
                  ),
                  _SelectRow(
                    label: context.tr(zh: '通知正文', en: 'Body'),
                    value: settings.notificationBody,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _openNotificationTemplate(settings),
                  ),
                  _ActionRow(
                    label: context.tr(zh: '测试提醒', en: 'Test reminder'),
                    actionLabel: context.tr(zh: '发送', en: 'Send'),
                    textMain: textMain,
                    textMuted: textMuted,
                    enabled: !_testing,
                    onPressed: _sendTestNotification,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: context.tr(zh: '声音与反馈', en: 'Sound & feedback'), textMuted: textMuted),
              const SizedBox(height: 8),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _SelectRow(
                    label: context.tr(zh: '提醒铃声', en: 'Ringtone'),
                    value: _soundLabel(settings),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _pickRingtone(settings),
                  ),
                  _ToggleRow(
                    label: context.tr(zh: '震动', en: 'Vibration'),
                    value: settings.vibrationEnabled,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (value) async {
                      ref.read(reminderSettingsProvider.notifier).setVibrationEnabled(value);
                      await ref.read(reminderSchedulerProvider).rescheduleAll();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: context.tr(zh: '休息时间', en: 'Quiet hours'), textMuted: textMuted),
              const SizedBox(height: 8),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _ToggleRow(
                    label: context.tr(zh: '免打扰模式', en: 'Do not disturb'),
                    value: settings.dndEnabled,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (value) async {
                      ref.read(reminderSettingsProvider.notifier).setDndEnabled(value);
                      await ref.read(reminderSchedulerProvider).rescheduleAll();
                    },
                  ),
                  _SelectRow(
                    label: context.tr(zh: '开始时间', en: 'Start time'),
                    value: _formatTime(settings.dndStartTime),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _pickDndTime(isStart: true, settings: settings),
                  ),
                  _SelectRow(
                    label: context.tr(zh: '结束时间', en: 'End time'),
                    value: _formatTime(settings.dndEndTime),
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () => _pickDndTime(isStart: false, settings: settings),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  zh: '在免打扰期间，应用将保持静默，不会弹出任何提醒。',
                  en: 'During quiet hours, reminders will be silenced.',
                ),
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
          if (description.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 44),
              child: Text(
                description,
                style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.textMuted});

  final String label;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted));
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

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    this.onTap,
  });

  final String label;
  final String value;
  final Color textMain;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.actionLabel,
    required this.textMain,
    required this.textMuted,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final String actionLabel;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final actionColor = enabled ? MemoFlowPalette.primary : textMuted.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: actionColor,
              side: BorderSide(color: actionColor.withValues(alpha: 0.7)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
